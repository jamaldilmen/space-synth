#include "midi_input.h"
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <mach/mach_time.h>
#include <cstdio>
#include <string>
#include <vector>

namespace space {

struct MidiInput::Impl {
  MIDIClientRef client = 0;
  MIDIPortRef port = 0;
  MidiCallback callback;
  std::vector<std::string> deviceNames;
  // mach timebase, read ONCE at start(): ticks × numer / denom = ns. On this
  // machine numer=125 denom=3 (41.67 ns/tick) — ÷1e9 alone is 41.67× wrong.
  double tbNumer = 1.0;
  double tbDenom = 1.0;
};

// CoreMIDI read callback — called on MIDI thread
static void midiReadCallback(const MIDIPacketList *list, void *refCon, void *) {
  auto *impl = static_cast<MidiInput::Impl *>(refCon);
  if (!impl->callback)
    return;

  const MIDIPacket *packet = &list->packet[0];
  for (UInt32 i = 0; i < list->numPackets; i++) {
    // ── TIMESTAMP (S1, OPUS §10.0c, MEASURED 3/3): the PACKET's stamp, never
    // callback entry — entry inherits scheduling jitter and jitter in the log
    // is jitter in every render made from it. A sender passing 0 ("send now")
    // is delivered AS 0, not rewritten to arrival; converted naively that is
    // ~5 days before the take. Guard it, fall back, and say which was used.
    uint64_t raw = packet->timeStamp;
    const bool stamped = (raw != 0);
    if (!stamped) raw = mach_absolute_time();
    const double t = (double)raw * impl->tbNumer / impl->tbDenom / 1.0e9;

    // Parse MIDI bytes. Sizes are the MIDI 1.0 spec's own table, not guesses:
    //   0x80-0xEF channel voice: 3 bytes except 0xC0/0xD0 (2)
    //   0xF0 SysEx: scan to 0xF7   0xF1 2   0xF2 3   0xF3 2   0xF6 1
    //   0xF8-0xFF System Real-Time: 1 (the 9fbe0ba guarantee — unchanged)
    // A DAW driving the record pass emits MTC (0xF1) and Song Position (0xF2);
    // sized wrong they swallowed the note that shared their packet (F2).
    for (UInt16 j = 0; j < packet->length;) {
      uint8_t status = packet->data[j];
      if (status >= 0xF8) {
        // System Real-Time: always 1 byte, no channel nibble to mask
        j++;
        continue;
      }
      if (status == 0xF0) {
        // SysEx: skip to the 0xF7 terminator (or the end of this packet)
        j++;
        while (j < packet->length && packet->data[j] != 0xF7) j++;
        if (j < packet->length) j++;   // consume the 0xF7
        continue;
      }
      if (status >= 0xF0) {
        // System Common: 0xF1 (MTC quarter-frame) 2, 0xF2 (song position) 3,
        // 0xF3 (song select) 2, 0xF4/0xF5 undefined 1, 0xF6 (tune request) 1,
        // 0xF7 (stray end-of-SysEx) 1. No channel nibble.
        j += (status == 0xF2) ? 3 : (status == 0xF1 || status == 0xF3) ? 2 : 1;
        continue;
      }
      uint8_t type = status & 0xF0;
      uint8_t channel = status & 0x0F;   // §10.0b: always extracted, never assumed

      if (type == 0x90 && j + 2 < packet->length) {
        // Note On — velocity 0 IS a Note Off (MIDI 1.0 running-status idiom,
        // verified correct 2026-09-01; do not "clean it up" into NoteOn b=0)
        uint8_t note = packet->data[j + 1] & 0x7F;
        uint8_t vel  = packet->data[j + 2] & 0x7F;
        MidiEvent ev{vel > 0 ? MidiKind::NoteOn : MidiKind::NoteOff, channel,
                     note, vel > 0 ? vel : (uint8_t)0, stamped, t};
        impl->callback(ev);
        j += 3;
      } else if (type == 0x80 && j + 2 < packet->length) {
        // Note Off
        MidiEvent ev{MidiKind::NoteOff, channel, (uint8_t)(packet->data[j + 1] & 0x7F),
                     0, stamped, t};
        impl->callback(ev);
        j += 3;
      } else if (type == 0xB0 && j + 2 < packet->length) {
        // Control Change — the automation lane (his order: rides and fades)
        MidiEvent ev{MidiKind::CC, channel, (uint8_t)(packet->data[j + 1] & 0x7F),
                     (uint8_t)(packet->data[j + 2] & 0x7F), stamped, t};
        impl->callback(ev);
        j += 3;
      } else if (type >= 0xC0 && type <= 0xDF) {
        j += 2; // 2-byte messages (program change, channel pressure)
      } else if (type >= 0x80) {
        j += 3; // 3-byte messages (poly aftertouch, pitch bend)
      } else {
        j++; // data byte with no status in this packet (running status, out of scope)
      }
    }
    packet = MIDIPacketNext(packet);
  }
}

MidiInput::MidiInput() { impl_ = new Impl(); }

MidiInput::~MidiInput() {
  stop();
  delete impl_;
}

bool MidiInput::start(MidiCallback callback) {
  if (running_)
    stop();

  impl_->callback = callback;
  {
    mach_timebase_info_data_t tb;
    mach_timebase_info(&tb);
    impl_->tbNumer = (double)tb.numer;
    impl_->tbDenom = (double)tb.denom;
    printf("[MIDI] timebase numer=%u denom=%u (%.4f ns/tick); event t = seconds, CACurrentMediaTime timebase\n",
           tb.numer, tb.denom, (double)tb.numer / (double)tb.denom);
  }

  OSStatus err =
      MIDIClientCreate(CFSTR("SpaceSynth"), nullptr, nullptr, &impl_->client);
  if (err != noErr) {
    printf("[MIDI] Failed to create client: %d\n", (int)err);
    return false;
  }

  err = MIDIInputPortCreate(impl_->client, CFSTR("SpaceSynth Input"),
                            midiReadCallback, impl_, &impl_->port);
  if (err != noErr) {
    printf("[MIDI] Failed to create input port: %d\n", (int)err);
    return false;
  }

  // Connect to ALL available MIDI sources
  ItemCount sourceCount = MIDIGetNumberOfSources();
  impl_->deviceNames.clear();

  printf("[MIDI] Found %lu MIDI source(s)\n", (unsigned long)sourceCount);

  for (ItemCount i = 0; i < sourceCount; i++) {
    MIDIEndpointRef source = MIDIGetSource(i);
    err = MIDIPortConnectSource(impl_->port, source, nullptr);

    // Get device name
    CFStringRef name = nullptr;
    MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name);
    if (name) {
      char buf[256];
      CFStringGetCString(name, buf, sizeof(buf), kCFStringEncodingUTF8);
      impl_->deviceNames.push_back(buf);
      printf("[MIDI] Connected: %s\n", buf);
      CFRelease(name);
    } else {
      impl_->deviceNames.push_back("Unknown");
      printf("[MIDI] Connected: Unknown device %lu\n", (unsigned long)i);
    }
  }

  running_ = true;
  printf("[MIDI] Listening on %lu source(s)\n", (unsigned long)sourceCount);
  return true;
}

void MidiInput::stop() {
  if (impl_->port) {
    MIDIPortDispose(impl_->port);
    impl_->port = 0;
  }
  if (impl_->client) {
    MIDIClientDispose(impl_->client);
    impl_->client = 0;
  }
  impl_->deviceNames.clear();
  running_ = false;
}

int MidiInput::deviceCount() const { return (int)impl_->deviceNames.size(); }

const char *MidiInput::deviceName(int index) const {
  if (index >= 0 && index < (int)impl_->deviceNames.size())
    return impl_->deviceNames[index].c_str();
  return "N/A";
}

} // namespace space
