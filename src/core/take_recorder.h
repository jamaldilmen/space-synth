#pragma once
// ── TAKE RECORDER (S2 of the show renderer, 2026-09-03) ────────────────────
// His ruling: play the Ableton timeline into the app ONCE, log every note and
// every CC with a timestamp, render that log offline at exactly 30 fps.
//
// THREADS — the only RT-safety question in this file:
//   push()   : CoreMIDI thread. Writes ONE slot of a preallocated ring and
//              bumps an atomic. No malloc, no lock, no file. Ever.
//   drain()  : main thread, once per frame. Moves ring → growable vector.
//   frame()  : main thread, once per frame. Appends the envelope ground truth.
//   finish() : main thread, at exit. Writes the file. The ONLY fopen/fwrite.
// Ring overflow is COUNTED, never silent: a take with a hole renders wrong
// forever and nobody would know why. The count is printed at take end.
//
// TAKE START — his ruling: a MARKER CC at bar 1 beat 1 of the arrangement.
// Default CC 119 (undefined block 102-119, no mode/bank/mod/volume/pan/
// expression/sustain meaning, no Ableton default); SS_TAKE_MARKER_CC overrides.
// The FIRST marker event's t is t=0. No marker ⇒ the take has no t=0: the
// file is written with "marker NONE" and absolute times, loudly, and replay
// (S4) must refuse it. Never a silent fall-back to the first event — that
// looks fine and renders shifted.
#include "midi_input.h"
#include <atomic>
#include <cstdint>
#include <string>
#include <vector>

namespace space {

class TakeRecorder {
public:
  // Reads SS_RECORD (path; unset = disarmed, every call is a no-op) and
  // SS_TAKE_MARKER_CC. Prints the marker CC it will use — he must never guess.
  TakeRecorder();
  ~TakeRecorder();

  bool armed() const { return armed_; }
  int  markerCC() const { return markerCC_; }

  // CoreMIDI thread. Lock-free, allocation-free.
  void push(const MidiEvent &ev);

  // Main thread, once per frame: ring → vector. Returns events moved.
  int drain();

  // Main thread, once per frame: the envelope ground truth S9 is verified
  // against. tSeconds in the CACurrentMediaTime timebase (same as MidiEvent.t).
  void frame(double tSeconds, float envelopePhase, float envelopeProgress,
             float totalAmplitude);

  // Main thread, at exit: write the take. Prints the summary, loudly.
  void finish();

  // seconds-in-timebase for "now" (mach ticks × timebase). Main thread use.
  static double nowSeconds();

private:
  struct FrameRow { double t; float phase, progress, amp; };

  static constexpr uint32_t kRing = 1u << 16;   // 65536 slots, ~1.6 MB, fixed
  MidiEvent ring_[kRing];
  std::atomic<uint32_t> head_{0};   // producer (MIDI thread) writes
  std::atomic<uint32_t> tail_{0};   // consumer (main thread) reads
  std::atomic<uint32_t> dropped_{0};
  std::atomic<uint32_t> unstamped_{0};

  std::vector<MidiEvent> events_;   // main-thread only
  std::vector<FrameRow>  frames_;   // main-thread only

  bool        armed_ = false;
  int         markerCC_ = 119;
  std::string path_;
  bool        finished_ = false;
};

} // namespace space
