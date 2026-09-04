#!/usr/bin/env python3
"""take4_check.py <app.log> [startFrame] [endFrame]

Rebuilt 2026-09-04 after the original was lost with /private/tmp.
Calibrated against take3_3min.log: reproduces gap p50 42.0 frames over
128 MSB crossings exactly (16383 counts / 128 = 128 crossings; 5400
frames / 128 = 42.2). Step p50 is read off cc=29 (2.790 deg), which is
where the recorded 2.790 came from.

The gate is MSB CROSSINGS, not applied-value updates -- the 14-bit
applied value moves nearly every frame (n=5247, p50 0.0) and is blind
to the fault. A crossing is a change in the cc=28 raw byte; the spring
must carry the camera across the gap between them.
  time -> output frame  from  '[CAPTURE] frame N written'
  crossings             from  '[MIDI-MAP] thetaSpin cc=28 raw=<r>'
Take 4: theta over [0,pi/2) using all 16383 counts = 128 crossings over
4800 frames = ~38 frames. Unfixed it is 4096 counts = 32 crossings =
~150 frames, against a 15-frame settle. ~150 means we STOP.
"""
import re, sys, bisect, math

LOG = sys.argv[1]
F0 = int(sys.argv[2]) if len(sys.argv) > 2 else 0
F1 = int(sys.argv[3]) if len(sys.argv) > 3 else 10**9

cap_t, cap_f = [], []
ev_t, ev_v, ev_cc, ev_raw = [], [], [], []
re_cap = re.compile(r'^(?:(\d+\.\d+) )?\[CAPTURE\] frame (\d+) written')
re_th  = re.compile(r'^(?:(\d+\.\d+) )?\[MIDI-MAP\] thetaSpin cc=\s*(\d+) raw=\s*(-?\d+) -> (-?\d+\.\d+)')
MSB_CC, LSB_CC = 28, 29

# Two clocks. A log written through the old capture_run.sh wrapper carries a
# unix timestamp per line; a log from a bare app launch does NOT. Fall back to
# LOG LINE INDEX, which is monotonic in both and needs no wrapper.
USE_TS = None
with open(LOG, 'r', errors='replace') as fh:
    for i, ln in enumerate(fh):
        m = re_cap.match(ln)
        if m:
            if USE_TS is None: USE_TS = m.group(1) is not None
            cap_t.append(float(m.group(1)) if USE_TS else float(i))
            cap_f.append(int(m.group(2))); continue
        m = re_th.match(ln)
        if m:
            ev_t.append(float(m.group(1)) if (USE_TS and m.group(1)) else float(i))
            ev_v.append(float(m.group(4)))
            ev_cc.append(int(m.group(2))); ev_raw.append(int(m.group(3)))
CLOCK = "wrapper timestamps" if USE_TS else "log line index (no wrapper timestamps)" 

if len(cap_t) < 2:
    sys.exit("no [CAPTURE] frame lines -- cannot map time to frames")

def t2f(t):
    """wall time -> output frame, linear between capture checkpoints"""
    i = bisect.bisect_left(cap_t, t)
    if i <= 0: return float(cap_f[0])
    if i >= len(cap_t): 
        i = len(cap_t) - 1
    t0, t1 = cap_t[i-1], cap_t[i]
    f0, f1 = cap_f[i-1], cap_f[i]
    if t1 == t0: return float(f1)
    return f0 + (f1 - f0) * (t - t0) / (t1 - t0)

# a target = an MSB CROSSING: a change in the cc=28 raw byte
tgt, last = [], None
for t, v, cc, raw in zip(ev_t, ev_v, ev_cc, ev_raw):
    if cc != MSB_CC: continue
    if last is None or raw != last:
        tgt.append((t2f(t), v)); last = raw
# step size is read off the LSB stream, where the recorded 2.790 lives
lsb, lastl = [], None
for t, v, cc, raw in zip(ev_t, ev_v, ev_cc, ev_raw):
    if cc != LSB_CC: continue
    if lastl is None or raw != lastl:
        lsb.append((t2f(t), v)); lastl = raw

win = [(f, v) for (f, v) in tgt if F0 <= f <= F1]

def pct(xs, p):
    if not xs: return float('nan')
    s = sorted(xs); k = (len(s)-1) * p
    lo, hi = math.floor(k), math.ceil(k)
    return s[lo] if lo == hi else s[lo] + (s[hi]-s[lo])*(k-lo)

gaps  = [win[i+1][0] - win[i][0] for i in range(len(win)-1)]
wl = [(f, v) for (f, v) in lsb if F0 <= f <= F1]
steps = [abs(wl[i+1][1] - wl[i][1]) * 180.0/math.pi for i in range(len(wl)-1)]
SETTLE = 15.0
over = [g for g in gaps if g > SETTLE]

print(f"log            : {LOG}")
print(f"clock          : {CLOCK}")
print(f"frame window   : {F0}..{F1}   (capture frames {cap_f[0]}..{cap_f[-1]})")
print(f"MSB crossings  : n={len(win)}  (whole log n={len(tgt)})   LSB targets n={len(wl)}")
if gaps:
    print(f"gap frames     : p50 {pct(gaps,.5):.1f}  p25 {pct(gaps,.25):.1f}  p75 {pct(gaps,.75):.1f}  max {max(gaps):.1f}")
    print(f"step deg (LSB) : p50 {pct(steps,.5):.3f}  max {max(steps):.3f}" if steps else "step deg (LSB) : n/a")
    print(f"over settle    : {len(over)}/{len(gaps)} gaps exceed the {SETTLE:.0f}-frame settle")
    span = win[-1][0] - win[0][0]
    agg = span / len(gaps) if gaps else float('nan')
    print(f"aggregate      : {len(win)} crossings over {span:.0f} frames = {agg:.1f} frames/crossing")
    g = pct(gaps,.5)
    print()
    print(f"VERDICT        : gap p50 = {g:.1f} frames")
    if g <= 60:      print("                 ~38 band -> the [0,pi/2] mapping LANDED")
    elif g >= 110:   print("                 ~150 band -> THE FIX DID NOT LAND. STOP.")
    else:            print("                 BETWEEN the 38 and 150 bands -- not a clean read, do not launch")
else:
    print("no theta target changes in window")
