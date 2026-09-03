#pragma once
#include <cstdint>
#include <functional>

namespace space {

// ── THE EVENT (S1, 2026-09-03 — OPUS design §10.0a, his record-then-render
// ruling). ONE callback, ONE time-ordered stream, so the take log (S2) appends
// and never merges. A new message class arrives as a new MidiKind with no
// change to MidiCallback and no change to the consumer.
enum class MidiKind : uint8_t { NoteOn, NoteOff, CC };

struct MidiEvent {
  MidiKind kind;
  uint8_t  channel;  // 0-15 from status & 0x0F — always extracted (§10.0b)
  uint8_t  a;        // NoteOn/NoteOff: note        CC: controller number
  uint8_t  b;        // NoteOn: velocity 1-127      NoteOff: 0    CC: value 0-127
  bool     stamped;  // true: t is the PACKET's own stamp. false: the sender
                     // passed 0 ("send now") and t was taken at callback entry —
                     // carries scheduling jitter; S2 records this per take (§10.0c)
  double   t;        // SECONDS in the CACurrentMediaTime timebase (mach ticks ×
                     // timebase, NOT ÷1e9: one tick is 41.67 ns here). Absolute;
                     // the take start (his marker CC) is subtracted by S2.
};
using MidiCallback = std::function<void(const MidiEvent &)>;

class MidiInput {
public:
  MidiInput();
  ~MidiInput();

  // Start listening to all MIDI sources
  bool start(MidiCallback callback);
  void stop();

  // Get connected device count
  int deviceCount() const;

  // Get name of connected device at index
  const char *deviceName(int index) const;

  bool isRunning() const { return running_; }

  struct Impl; // Public for .mm access

private:
  Impl *impl_ = nullptr;
  bool running_ = false;
};

} // namespace space
