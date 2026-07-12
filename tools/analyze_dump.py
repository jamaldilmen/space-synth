#!/usr/bin/env python3
"""BUG_lines_2026-07-12: is the grid pattern IN THE PARTICLE DATA?
Reads float32 x,y,z triplets, tests each axis histogram for periodicity at
the spatial-hash cell size (1.0 sim), and writes a 2D projection PNG."""
import sys, struct
import numpy as np

path = sys.argv[1]
a = np.fromfile(path, dtype=np.float32).reshape(-1, 3)
print(f"particles: {len(a)}")
r = np.linalg.norm(a, axis=1)
print(f"radius: mean={r.mean():.2f} p50={np.median(r):.2f} p99={np.percentile(r,99):.2f} max={r.max():.2f}")

# Focus on the core where lines are seen (|coord| <= 20)
core = a[(np.abs(a) <= 20.0).all(axis=1)]
print(f"core (|xyz|<=20): {len(core)}")

for ax, name in [(0, "x"), (1, "y"), (2, "z")]:
    v = core[:, ax]
    # 0.05-sim bins over [-20,20] -> 800 bins; cell period 1.0 = 20 bins
    h, _ = np.histogram(v, bins=800, range=(-20, 20))
    h = h.astype(np.float64)
    h -= h.mean()
    f = np.abs(np.fft.rfft(h))
    freqs = np.fft.rfftfreq(len(h), d=0.05)  # cycles per sim unit
    # power at exactly 1 cycle/sim (cell size) vs the local background
    i1 = np.argmin(np.abs(freqs - 1.0))
    band = f[max(1, i1 - 8):i1 + 9]
    bg = np.median(np.concatenate([f[max(1,i1-40):max(1,i1-10)], f[i1+10:i1+40]]))
    peak_i = np.argmax(f[1:]) + 1
    print(f"axis {name}: FFT peak @ {freqs[peak_i]:.3f} cyc/sim (amp {f[peak_i]:.0f}); "
          f"amp@1.0 cyc/sim = {f[i1]:.0f}, local bg = {bg:.0f}, ratio = {f[i1]/max(bg,1e-9):.1f}")

# fractional part test: positions quantized/attracted to cell boundaries or centres?
for ax, name in [(0, "x"), (1, "y"), (2, "z")]:
    frac = np.mod(core[:, ax], 1.0)
    hf, _ = np.histogram(frac, bins=20, range=(0, 1))
    dev = (hf.max() - hf.min()) / hf.mean()
    print(f"axis {name}: frac-part histogram min={hf.min()} max={hf.max()} "
          f"spread/mean={dev:.3f} (uniform ~ {np.sqrt(20/len(core))*3:.3f} at 3 sigma)")
    if dev > np.sqrt(20 / len(core)) * 6:
        print(f"   -> NON-UNIFORM: bins={list(hf)}")

# 2D projection image (x-y), log scale, 1024px, |coord|<=20
try:
    import zlib
    N = 1024
    img, _, _ = np.histogram2d(core[:, 0], core[:, 1], bins=N, range=[[-20, 20], [-20, 20]])
    img = np.log1p(img)
    img = (img / img.max() * 255).astype(np.uint8)
    # write minimal grayscale PNG
    def png_write(fn, m):
        h, w = m.shape
        raw = b"".join(b"\x00" + m[i].tobytes() for i in range(h))
        def chunk(t, d):
            c = t + d
            return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c))
        ihdr = struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0)
        with open(fn, "wb") as fo:
            fo.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
                     + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
    png_write(path.replace(".bin", "_xy.png"), img.T[::-1])
    imgxz, _, _ = np.histogram2d(core[:, 0], core[:, 2], bins=N, range=[[-20, 20], [-20, 20]])
    imgxz = np.log1p(imgxz); imgxz = (imgxz / imgxz.max() * 255).astype(np.uint8)
    png_write(path.replace(".bin", "_xz.png"), imgxz.T[::-1])
    print("wrote projection PNGs (_xy, _xz)")
except Exception as e:
    print("png fail:", e)
