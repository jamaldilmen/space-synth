#include "take_recorder.h"
#include <cstdio>
#include <cstdlib>
#include <mach/mach_time.h>

namespace space {

static double sTbNumer = 1.0, sTbDenom = 1.0;
// Two exit paths write the take: the window close button ([NSApp run] returns
// and main calls finish()), and Cmd+Q / the Quit menu (terminate: → exit(),
// which never returns to main) — covered by atexit below. A SIGTERM/SIGKILL
// writes NOTHING; the arm message says so.
static TakeRecorder *sInstance = nullptr;
static void takeRecorderAtExit() { if (sInstance) sInstance->finish(); }

double TakeRecorder::nowSeconds() {
  return (double)mach_absolute_time() * sTbNumer / sTbDenom / 1.0e9;
}

TakeRecorder::TakeRecorder() {
  mach_timebase_info_data_t tb;
  mach_timebase_info(&tb);
  sTbNumer = (double)tb.numer;
  sTbDenom = (double)tb.denom;

  if (const char *m = getenv("SS_TAKE_MARKER_CC")) {
    int v = atoi(m);
    if (v >= 0 && v <= 127) markerCC_ = v;
    else fprintf(stderr, "[RECORD] SS_TAKE_MARKER_CC=%s out of range 0..127, keeping %d\n", m, markerCC_);
  }
  // Printed unconditionally: the marker is a fact about THIS build he has to
  // place in his arrangement, armed or not.
  printf("[RECORD] take marker = CC %d (SS_TAKE_MARKER_CC overrides); the mapping registry must refuse this number\n",
         markerCC_);

  if (const char *p = getenv("SS_RECORD")) {
    path_ = p;
    armed_ = true;
    events_.reserve(1u << 18);
    frames_.reserve(1u << 16);
    sInstance = this;
    atexit(takeRecorderAtExit);
    printf("[RECORD] ARMED -> %s  (ring %u slots; drops are counted and printed at take end). "
           "Quit with the close button or Cmd+Q — a kill writes NOTHING.\n",
           path_.c_str(), kRing);
  }
}

TakeRecorder::~TakeRecorder() {
  if (armed_ && !finished_) finish();
  if (sInstance == this) sInstance = nullptr;
}

void TakeRecorder::push(const MidiEvent &ev) {
  if (!armed_) return;
  uint32_t h = head_.load(std::memory_order_relaxed);
  uint32_t t = tail_.load(std::memory_order_acquire);
  if (h - t >= kRing) {                       // full: count, never block, never lose silently
    dropped_.fetch_add(1, std::memory_order_relaxed);
    return;
  }
  ring_[h & (kRing - 1)] = ev;
  head_.store(h + 1, std::memory_order_release);
  if (!ev.stamped) unstamped_.fetch_add(1, std::memory_order_relaxed);
}

int TakeRecorder::drain() {
  if (!armed_) return 0;
  uint32_t t = tail_.load(std::memory_order_relaxed);
  uint32_t h = head_.load(std::memory_order_acquire);
  int n = 0;
  while (t != h) {
    events_.push_back(ring_[t & (kRing - 1)]);
    ++t; ++n;
  }
  tail_.store(t, std::memory_order_release);
  return n;
}

void TakeRecorder::frame(double tSeconds, float phase, float progress, float amp) {
  if (!armed_) return;
  frames_.push_back({tSeconds, phase, progress, amp});
}

void TakeRecorder::finish() {
  if (!armed_ || finished_) return;
  finished_ = true;
  drain();

  // t=0 is the FIRST marker event. Anything before it is pre-roll and is kept
  // with negative t so nothing is thrown away; replay starts at t=0.
  bool   haveMarker = false;
  double t0 = 0.0;
  for (const MidiEvent &e : events_) {
    if (e.kind == MidiKind::CC && e.a == (uint8_t)markerCC_) { haveMarker = true; t0 = e.t; break; }
  }
  const uint32_t dropped = dropped_.load(), unstamped = unstamped_.load();

  FILE *f = fopen(path_.c_str(), "w");
  if (!f) {
    fprintf(stderr, "[RECORD] FAILED to open %s — take NOT written (%zu events, %zu frames)\n",
            path_.c_str(), events_.size(), frames_.size());
    return;
  }
  fprintf(f, "# SPACE SYNTH take v1\n");
  fprintf(f, "# marker CC %d ; t0 %s ; times SECONDS relative to t0 (CACurrentMediaTime timebase)\n",
          markerCC_, haveMarker ? "MARKER" : "NONE");
  fprintf(f, "# stamps %s ; unstamped %u ; dropped %u ; events %zu ; frames %zu\n",
          unstamped == 0 ? "packet" : (unstamped == events_.size() ? "callback" : "mixed"),
          unstamped, dropped, events_.size(), frames_.size());
  fprintf(f, "# E t kind(0=on,1=off,2=cc) ch a b stamped\n");
  fprintf(f, "# F t envelopePhase envelopeProgress totalAmplitude\n");
  for (const MidiEvent &e : events_)
    fprintf(f, "E %.6f %d %d %d %d %d\n", e.t - t0, (int)e.kind, e.channel, e.a, e.b, e.stamped ? 1 : 0);
  for (const FrameRow &r : frames_)
    fprintf(f, "F %.6f %.2f %.4f %.5f\n", r.t - t0, r.phase, r.progress, r.amp);
  fclose(f);

  printf("[RECORD] WROTE %s : %zu events, %zu frames, stamps=%s, unstamped=%u, dropped=%u\n",
         path_.c_str(), events_.size(), frames_.size(),
         unstamped == 0 ? "packet" : "callback/mixed", unstamped, dropped);
  if (!haveMarker)
    fprintf(stderr, "[RECORD] 🚨 NO MARKER SEEN (CC %d) — this take has NO t=0. Times are ABSOLUTE. "
                    "Replay must refuse it. Put CC %d at bar 1 beat 1 and record again.\n",
            markerCC_, markerCC_);
  if (dropped)
    fprintf(stderr, "[RECORD] 🚨 %u EVENTS DROPPED (ring full) — this take has holes. Record again.\n", dropped);
}

} // namespace space
