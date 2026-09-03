#include "take_replay.h"
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace space {

TakeReplay::TakeReplay(int fps) : fps_(fps) {
  const char *p = getenv("SS_REPLAY");
  if (!p) return;
  path_ = p;
  if (const char *s = getenv("SS_REPLAY_START_FRAME")) {
    int v = atoi(s);
    if (v >= 0) startFrame_ = v;
    else fprintf(stderr, "[REPLAY] SS_REPLAY_START_FRAME=%s < 0 ignored, using 0\n", s);
  }
  if (fps_ <= 0) {
    fprintf(stderr, "[REPLAY] 🚨 REFUSED %s: the offline clock is OFF (set SS_RENDER_FPS=30|60). "
                    "A frame is not a unit of time without it; the schedule would drift.\n", path_.c_str());
    return;
  }
  FILE *f = fopen(path_.c_str(), "r");
  if (!f) {
    fprintf(stderr, "[REPLAY] 🚨 REFUSED: cannot open %s\n", path_.c_str());
    return;
  }
  bool markerOk = false, sawHeader = false;
  uint32_t dropped = 0;
  size_t preRollSkipped = 0, preRollKept = 0;
  char line[512];
  while (fgets(line, sizeof line, f)) {
    if (line[0] == '#') {
      if (strstr(line, "SPACE SYNTH take v1")) sawHeader = true;
      if (strstr(line, "t0 MARKER")) markerOk = true;
      if (const char *d = strstr(line, "dropped ")) dropped = (uint32_t)atoi(d + 8);
      continue;
    }
    if (line[0] != 'E') continue;   // F rows are S9's ground truth, not replay input
    double t; int kind, ch, a, b, stamped;
    if (sscanf(line, "E %lf %d %d %d %d %d", &t, &kind, &ch, &a, &b, &stamped) != 6) continue;
    if (kind < 0 || kind > 2 || a < 0 || a > 127 || b < 0 || b > 127) continue;
    int64_t frame = (int64_t)startFrame_ + (int64_t)std::floor(t * (double)fps_);
    if (frame < 0) { preRollSkipped++; continue; }
    if (t < 0.0) preRollKept++;
    MidiEvent ev{(MidiKind)kind, (uint8_t)ch, (uint8_t)a, (uint8_t)b, stamped != 0, t};
    events_.push_back({frame, ev});
  }
  fclose(f);

  if (!sawHeader) {
    fprintf(stderr, "[REPLAY] 🚨 REFUSED %s: not a SPACE SYNTH take v1 file\n", path_.c_str());
    events_.clear(); return;
  }
  if (!markerOk) {
    fprintf(stderr, "[REPLAY] 🚨 REFUSED %s: header says t0 NONE — the take has no marker (CC at bar 1 beat 1). "
                    "Record it again.\n", path_.c_str());
    events_.clear(); return;
  }
  if (dropped > 0) {
    fprintf(stderr, "[REPLAY] 🚨 REFUSED %s: header says dropped %u — the take has holes. Record it again.\n",
            path_.c_str(), dropped);
    events_.clear(); return;
  }
  // The file is written in arrival order; frames are monotonic in t, so no
  // sort — and no sort means the arrival order of same-frame events survives.
  active_ = true;
  int64_t lastFrame = events_.empty() ? 0 : events_.back().frame;
  printf("[REPLAY] ARMED %s: %zu events, fps=%d, t=0 at output frame %d, last event at frame %lld "
         "(%.3f s), pre-roll replayed %zu, pre-roll skipped %zu. Events apply at frame = %d + floor(t*%d).\n",
         path_.c_str(), events_.size(), fps_, startFrame_, (long long)lastFrame,
         (double)lastFrame / fps_, preRollKept, preRollSkipped, startFrame_, fps_);
}

int TakeReplay::tick(uint32_t frameIndex, const std::function<void(const MidiEvent &)> &apply) {
  if (!active_) return 0;
  int n = 0;
  while (next_ < events_.size() && events_[next_].frame <= (int64_t)frameIndex) {
    const Scheduled &s = events_[next_];
    printf("[REPLAY] frame=%u t=%.6f kind=%d ch=%d a=%d b=%d\n", frameIndex, s.ev.t,
           (int)s.ev.kind, s.ev.channel, s.ev.a, s.ev.b);
    // The applied event carries ITS FRAME's time: in a replay the frame is the
    // clock, so a re-recording of this replay (SS_RECORD during SS_REPLAY)
    // logs t = frame/fps, comparable row-for-row with the frame log.
    MidiEvent applied = s.ev;
    applied.t = (double)s.frame / (double)fps_;
    apply(applied);
    ++next_; ++n;
  }
  if (next_ >= events_.size() && !completeAnnounced_) {
    completeAnnounced_ = true;
    printf("[REPLAY] TAKE COMPLETE at frame %u (%zu events applied)\n", frameIndex, events_.size());
  }
  return n;
}

} // namespace space
