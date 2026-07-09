#!/usr/bin/env python3
import re, glob, os, math

SP = "/private/tmp/claude-501/-Users-airy/3aa821de-1142-4ebe-8c51-69c232546d20/scratchpad"
CFGS = ["NONE","sculpt","breathing","swirl","impulse","web","jitter"]

sh_re = re.compile(r"\[SHAPE\] mean=\(([-\d. ]+)\)\s+sigma=\(([-\d. ]+)\)")
ve_re = re.compile(r"\[VEL\] mean v=\(([-\d. ]+)\) sim/frame\s+voices=(\d+)")

def parse(cfg):
    path = os.path.join(SP, f"run_{cfg}.log")
    rows = []  # (kind, shape_mean(3), sigma(3), v(3), voices)
    lines = open(path).read().splitlines() if os.path.exists(path) else []
    pending = None
    for ln in lines:
        m = sh_re.search(ln)
        if m:
            pending = ([float(x) for x in m.group(1).split()],
                       [float(x) for x in m.group(2).split()])
            continue
        m = ve_re.search(ln)
        if m and pending:
            v = [float(x) for x in m.group(1).split()]
            vc = int(m.group(2))
            rows.append((pending[0], pending[1], v, vc))
            pending = None
    return rows

def mag(v): return math.sqrt(sum(x*x for x in v))

def summarize(rows, want_voices, after_chord=None):
    # after_chord: None=any; else pick voices==1 rows before(False)/after(True) first voices>=3
    sel = []
    seen_chord = False
    for (mean,sig,v,vc) in rows:
        if vc >= 3: seen_chord = True
        if vc != want_voices: continue
        if after_chord is not None and (seen_chord != after_chord): continue
        sel.append((mean,sig,v))
    if not sel: return None
    n = len(sel)
    szz = sum(s[1][2] for s in sel)/n
    sxy = sum((s[1][0]+s[1][1])/2 for s in sel)/n
    dpos = max(mag(s[0]) for s in sel)          # max cluster off-center
    dv  = sum(mag(s[2]) for s in sel)/n         # mean drift magnitude
    return dict(n=n, sxy=round(sxy,1), szz=round(szz,1), offc=round(dpos,1), drift=round(dv,4))

print(f"{'config':10} | {'SINGLE (v=1 pre)':30} | {'CHORD (v=3)':30} | {'ARP (v=1 post)':30}")
print("-"*110)
base = {}
for cfg in CFGS:
    rows = parse(cfg)
    single = summarize(rows, 1, after_chord=False)
    chord   = summarize(rows, 3)
    arp     = summarize(rows, 1, after_chord=True)
    def fmt(d):
        if not d: return f"{'-- no data --':30}"
        return f"sxy{d['sxy']:>4} sz{d['szz']:>5} off{d['offc']:>4} drift{d['drift']:.3f} n{d['n']}"
    print(f"{cfg:10} | {fmt(single):30} | {fmt(chord):30} | {fmt(arp):30}")
