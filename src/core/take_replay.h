#pragma once
// ── TAKE REPLAY (S4 of the show renderer, 2026-09-03) ──────────────────────
// Consumes an S2 take (SS_RECORD) by OUTPUT FRAME INDEX, never by wall time:
//   frame(event) = startFrame + ceil(t · fps)
// applied at the START of that frame, before the physics step — the first
// frame whose start is >= t, so NEVER EARLY and at most one frame (1/fps)
// late, exact for every t. (floor would be up to one frame early — measured
// 11–31 ms against the live take, S9.) Two replays of one take are the same
// schedule by construction.
//
// Requires the offline clock (SS_RENDER_FPS): without it a frame is not a
// unit of time and the schedule would drift against the take. REFUSED loudly.
// Refused loudly too: a take with "t0 NONE" (no marker) or "dropped > 0"
// (holes) — a replay of either looks fine and is wrong.
//
// SS_REPLAY=<take>  SS_REPLAY_START_FRAME=<n> (default 0): output frame n is
// t=0 (his marker at bar 1 beat 1). Pre-roll events (t<0) are replayed if
// they land at frame >= 0, otherwise counted and skipped.
#include "midi_input.h"
#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace space {

class TakeReplay {
public:
  // Reads SS_REPLAY / SS_REPLAY_START_FRAME, parses the take, prints the
  // verdict. `fps` is the offline clock's fps (0 = clock off => refuse).
  explicit TakeReplay(int fps);

  bool active() const { return active_; }
  int  startFrame() const { return startFrame_; }
  size_t total() const { return events_.size(); }
  bool complete() const { return active_ && next_ >= events_.size(); }

  // Main thread, at the top of every output frame, BEFORE the physics step.
  // Applies every event whose frame <= frameIndex through `apply` (the same
  // callable live MIDI uses). Returns events applied this frame.
  int tick(uint32_t frameIndex, const std::function<void(const MidiEvent &)> &apply);

private:
  struct Scheduled { int64_t frame; MidiEvent ev; };
  std::vector<Scheduled> events_;
  size_t next_ = 0;
  bool   active_ = false;
  bool   completeAnnounced_ = false;
  int    fps_ = 0;
  int    startFrame_ = 0;
  std::string path_;
};

} // namespace space
