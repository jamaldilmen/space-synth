#!/usr/bin/env python3
"""render_progress.py <capture.log> [totalFrames]

Live progress bar for a capture run. Watches the log the app is writing.

  python3 scratchpad/render_progress.py ~/Desktop/sweep/take4rev_full.log

Total frames are read from the log's own
    [CAPTURE]   stops after N frames (SS_CAPTURE_FRAMES)
line, so you normally pass nothing. Override with the 2nd argument if the
run was launched without SS_CAPTURE_FRAMES.

Rate and ETA use the LAST 30 checkpoints, not the whole run: a take that
opens wide and flies in gets slower as it goes, and a whole-run average
would promise an ETA it cannot keep. (Take 3's ETA was wrong by 18 min
for exactly this reason -- it projected the take from its first 60 s.)
Works with or without the per-line unix-timestamp prefix.
"""
import os, re, sys, time

LOG = sys.argv[1]
TOTAL = int(sys.argv[2]) if len(sys.argv) > 2 else None
RE_F = re.compile(r'^(?:(\d+\.\d+) )?\[CAPTURE\] frame (\d+) written')
RE_T = re.compile(r'\[CAPTURE\]\s+stops after (\d+) frames')
WINDOW = 30

def hms(s):
    if s is None or s != s or s < 0: return "--:--"
    s = int(s); return f"{s//3600}:{(s%3600)//60:02d}:{s%60:02d}" if s >= 3600 else f"{s//60}:{s%60:02d}"

def app_alive():
    return os.system("pgrep -f 'SpaceSynth.app/Contents/MacOS/SpaceSynth' >/dev/null 2>&1") == 0

pts, total, start = [], TOTAL, time.time()
while not os.path.exists(LOG):
    if time.time() - start > 60: sys.exit(f"no log at {LOG}")
    time.sleep(0.5)

last_size, done, seen_alive = 0, False, False
try:
    while True:
        try:
            with open(LOG, 'r', errors='replace') as fh:
                fh.seek(last_size)
                for ln in fh:
                    if total is None:
                        m = RE_T.search(ln)
                        if m: total = int(m.group(1))
                    m = RE_F.match(ln)
                    if m:
                        t = float(m.group(1)) if m.group(1) else time.time()
                        pts.append((t, int(m.group(2))))
                last_size = fh.tell()
        except FileNotFoundError:
            pass

        if pts:
            now_t, cur = pts[-1]
            w = pts[-WINDOW:] if len(pts) >= 2 else pts
            rate = ((w[-1][1] - w[0][1]) / (w[-1][0] - w[0][0])) if len(w) > 1 and w[-1][0] > w[0][0] else 0.0
            elapsed = pts[-1][0] - pts[0][0]
            if total:
                frac = min(1.0, (cur + 1) / total)
                eta = (total - 1 - cur) / rate if rate > 0 else None
                nb = 34; fill = int(nb * frac)
                bar = "█" * fill + "░" * (nb - fill)
                sys.stdout.write(
                    f"\r\033[K{bar} {frac*100:5.1f}%  {cur+1}/{total}  "
                    f"{rate:5.2f} fps  elapsed {hms(elapsed)}  eta {hms(eta)}  "
                    f"({(cur+1)/30:.0f}s of 30fps output)")
            else:
                sys.stdout.write(f"\r\033[Kframe {cur+1}  {rate:5.2f} fps  elapsed {hms(elapsed)}  (total unknown)")
            sys.stdout.flush()
            if total and cur >= total - 1:
                done = True
                sys.stdout.write("\n[CAPTURE] complete: "
                                 f"{total} frames in {hms(elapsed)} "
                                 f"({total/elapsed:.2f} fps avg, {(total/30)/elapsed:.2f}x realtime)\n")
                break
        # Only call it an exit once the app has actually been SEEN running.
        # Otherwise starting this a moment before the app appears -- or a
        # pgrep hiccup -- reports a failed run that never started.
        if app_alive():
            seen_alive = True
        elif seen_alive and pts:
            sys.stdout.write("\n[CAPTURE] app exited"
                             f"{'' if done else ' BEFORE the last frame -- run did not finish'}\n")
            break
        time.sleep(0.5)
except KeyboardInterrupt:
    sys.stdout.write("\n")
