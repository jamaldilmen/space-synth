#!/usr/bin/env python3
"""Locate the depletion lanes precisely: per-axis fine histogram, find dips,
report center/width/spacing and phase vs the integer cell grid."""
import sys
import numpy as np

a = np.fromfile(sys.argv[1], dtype=np.float32).reshape(-1, 3)
core = a[(np.abs(a) <= 24.0).all(axis=1)]
print(f"core |xyz|<=24: {len(core)}")
BW = 0.02
for ax, name in [(0, "x"), (1, "y"), (2, "z")]:
    v = core[:, ax]
    h, edges = np.histogram(v, bins=int(48 / BW), range=(-24, 24))
    c = 0.5 * (edges[:-1] + edges[1:])
    # smooth background over ±1.5 sim
    k = int(3.0 / BW) | 1
    bg = np.convolve(h, np.ones(k) / k, mode="same")
    good = bg > 200
    ratio = np.where(good, h / np.maximum(bg, 1), 1.0)
    sig = np.sqrt(np.maximum(bg, 1))
    zscore = np.where(good, (h - bg) / sig, 0.0)
    dips = np.where((zscore < -6) & good)[0]
    if len(dips) == 0:
        print(f"axis {name}: no dips < -6 sigma")
        continue
    # group consecutive bins
    groups = np.split(dips, np.where(np.diff(dips) > 3)[0] + 1)
    print(f"axis {name}: {len(groups)} dip group(s)")
    for g in groups[:20]:
        cen = c[g].mean()
        depth = ratio[g].min()
        width = (g[-1] - g[0] + 1) * BW
        print(f"   center={cen:+.3f}  width~{width:.2f}  depth(min h/bg)={depth:.2f}  "
              f"frac_vs_int={np.mod(cen,1.0):.3f}")
