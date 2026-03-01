#include "midi_input.h"
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <cstdio>
#include <string>
#include <vector>

namespace space {

struct MidiInput::Impl {
  MIDIClientRef client = 0;
  MIDIPortRef port = 0;
  MidiCallback callback;
  std::vector<std::string> deviceNames;
};

// CoreMIDI read callback — called on MIDI thread
static void midiReadCallback(const MIDIPacketList *list, void *refCon, void *) {
  auto *impl = static_cast<MidiInput::Impl *>(refCon);
  if (!impl->callback)
    return;

  const MIDIPacket *packet = &list->packet[0];
  for (UInt32 i = 0; i < list->numPackets; i++) {
    // Parse MIDI bytes
    for (UInt16 j = 0; j < packet->length;) {
      uint8_t status = packet->data[j];
      uint8_t type = status & 0xF0;

      if (type == 0x90 && j + 2 < packet->length) {
        // Note On
        int note = packet->data[j + 1];
        int vel = packet->data[j + 2];
        if (vel > 0) {
          impl->callback(note, vel / 127.0f, true);
        } else {
          // velocity 0 = note off
          impl->callback(note, 0.0f, false);
        }
        j += 3;
      } else if (type == 0x80 && j + 2 < packet->length) {
        // Note Off
        int note = packet->data[j + 1];
        impl->callback(note, 0.0f, false);
        j += 3;
      } else if (type >= 0xC0 && type <= 0xDF) {
        j += 2; // 2-byte messages (program change, channel pressure)
      } else if (type >= 0x80) {
        j += 3; // 3-byte messages (CC, pitch bend, etc)
      } else {
        j++; // skip unknown
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
