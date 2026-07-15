#!/usr/bin/env python3
# Sub-sigma z-lane probe at known centers. Ported from the 2026-07-14
# isolation-ladder scratchpad (carver-#0 hunt). Reads an SS_DUMP position
# dump (float32 xyz triplets), histograms z in the |xyz|<=24 core, subtracts
# a 3-unit boxcar background, and reports the minimum z-score in a +/-0.4
# window around each requested center plus the worst bin anywhere.
# Noise floor for 480 bins is about -3.5 sigma; single runs fluctuate
# +/-1 sigma run-to-run -- stack 4+ runs for weak seeds.
#
# Usage: zprobe.py dump.bin [dump2.bin ...] [--centers -7.17,-4.4,...]
# Multiple dumps are STACKED (histograms summed) before scoring.
import sys
import numpy as np

TICK2_SEED_CENTERS = [-7.17, -4.4, -1.38, 1.44, 2.5, 7.3]

def main(argv):
    files, centers = [], TICK2_SEED_CENTERS
    it = iter(argv)
    for a in it:
        if a == "--centers":
            centers = [float(x) for x in next(it).split(",")]
        else:
            files.append(a)
    if not files:
        print("usage: zprobe.py dump.bin [...] [--centers z1,z2,...]")
        return 1

    BW = 0.1
    bins = int(48 / BW)
    h = np.zeros(bins)
    for f in files:
        a = np.fromfile(f, dtype=np.float32).reshape(-1, 3)
        core = a[(np.abs(a) <= 24).all(axis=1)]
        hf, edges = np.histogram(core[:, 2], bins=bins, range=(-24, 24))
        h += hf
    c = 0.5 * (edges[:-1] + edges[1:])

    k = int(3.0 / BW) | 1
    bg = np.convolve(h, np.ones(k) / k, mode="same")
    z = (h - bg) / np.sqrt(np.maximum(bg, 1))

    out = []
    for zc in centers:
        i = int(np.argmin(np.abs(c - zc)))
        w = int(0.4 / BW)
        out.append(f"{zc:+.2f}:{z[max(0, i - w):i + w + 1].min():+.1f}")
    stacked = f" [{len(files)} dumps stacked]" if len(files) > 1 else ""
    print("  seedZ  " + "  ".join(out)
          + f"   worst_anywhere={z.min():+.1f} @z={c[int(np.argmin(z))]:+.2f}"
          + stacked)
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
