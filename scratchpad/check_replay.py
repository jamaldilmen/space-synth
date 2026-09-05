#!/usr/bin/env python3
"""Diff the [REPLAY] stream an app log actually applied against the take file it was given.
Usage: check_replay.py <take file> <app log> [maxFrame]"""
import sys, re, math
take, log = sys.argv[1], sys.argv[2]; maxf = int(sys.argv[3]) if len(sys.argv) > 3 else 10**9
want = []
for l in open(take):
    if not l.startswith('E'): continue
    _, t, k, ch, a, b, st = l.split(); f = math.ceil(float(t)*30 - 1e-9)
    if f <= maxf: want.append((f, int(k), int(a), int(b)))
got = []
for l in open(log, errors='ignore'):
    m = re.search(r"\[REPLAY\] frame=(\d+) t=[\d.]+ kind=(\d) ch=\d+ a=(\d+) b=(\d+)", l)
    if m: got.append(tuple(int(v) for v in m.groups()))
print(f"take: {len(want)} events <= frame {maxf} | log applied: {len(got)}")
n = min(len(want), len(got)); mism = [(i, want[i], got[i]) for i in range(n) if want[i] != got[i]]
print(f"first {n} compared: {len(mism)} mismatches; extra in take: {len(want)-n}; extra in log: {len(got)-n}")
for i, w, g in mism[:10]: print("  #%d take %s log %s" % (i, w, g))
late = [(w, g) for w, g in zip(want, got) if w[0] != g[0]]
print("frame-late events:", len(late), "(first 5:", late[:5], ")")
