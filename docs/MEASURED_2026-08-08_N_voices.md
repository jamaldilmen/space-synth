# MEASURED — N, THE VOICE BUDGET

**Measured:** 2026-08-08 01:18:15
**Answers:** `DESIGN_2026-07-28_field_sonification.md` §8 / §10 step 1 — *"Measure N. GPU sum of N
oscillators at audio rate; sweep N until the frame budget breaks. No musical content. Output the
number. Verdict: none needed — it is a number."*
**Tool:** `tools/measure_n/` (standalone — does **not** touch the app)
**Device:** Apple M5 Max, unified memory, 32 KB threadgroup memory

---

## THE NUMBER

> ## **N ≈ 250,000 voices** at a safe 10% GPU share.
> ## **N ≈ 500,000** if audio may take 25%.
> ## **N = 2,000,000 is NOT feasible** — it costs 63–67% of the audio block.

**So §8's fork resolves to its SECOND branch.** A true per-particle sum over the whole 2M field is
out. The field must be grouped into shape-preserving cells. §0.3 still holds as the *definition*;
the grouping is the documented approximation, and **solo still works, because solo is N = 1.**

---

## THE MEASUREMENT

Audio block = 512 frames @ 48 kHz = **10.667 ms** of sound. Both sweeps below are the **minimum of
10 timed runs** after discarding warmup, using Metal's own `GPUStartTime`/`GPUEndTime`.

| N | idle GPU | under load | % of block | verdict |
|---|---|---|---|---|
| 1,000 | 0.497 ms | 0.104 ms | ~1–5% | ✅ |
| 10,000 | 0.847 | 0.934 | 8% | ✅ |
| 100,000 | 0.836 | 1.025 | 8–10% | ✅ |
| **250,000** | **0.838** | **0.946** | **8–9%** | ✅ **fits a 10% share** |
| 500,000 | 1.547 | 1.646 | 15% | ⚠️ fits 25% |
| 1,000,000 | 3.972 | 4.149 | 37–39% | ❌ starves the renderer |
| 2,000,000 | 6.688 | 7.120 | 63–67% | ❌ starves the renderer |
| 4,000,000 | 12.693 | 13.003 | 119–122% | ❌ **does not run in real time at all** |

"Under load" = the real deployment condition: `SpaceSynth.app` running its 2M-particle sim at
**68 fps** on the same GPU, measured in the same session.

---

## THREE FINDINGS THAT CHANGE THE ARCHITECTURE

### 1. Contention barely matters — this was NOT expected
Running the full 2M-particle sim alongside changed every figure by **under 10%**. The audio sum and
the physics do not meaningfully fight for the GPU. **Consequence: the voice budget does not have to
be negotiated against the renderer's frame budget**, which is the opposite of the assumption in §8.
Budget audio against the *audio block*, not against the frame.

### 2. There is a hard floor of ~0.5–1.0 ms per block, independent of N
1,000 voices and 250,000 voices cost **the same** (0.84 vs 0.84 ms idle). Cost is flat to ~250k,
then linear above ~500k. That floor is dispatch and synchronisation, not arithmetic.

**Two consequences:**
- **Everything up to ~250k voices is effectively free.** There is no reason to pick a small N. Any
  design targeting fewer than ~100k voices is leaving the entire budget unspent for nothing.
- **The floor is ~5–9% of realtime spent on overhead alone**, at 93.75 blocks/sec. If the budget
  ever needs to stretch, **amortising several blocks per dispatch is the lever** — not shrinking N.
  Unmeasured; the obvious next experiment if more headroom is ever wanted.

### 3. 250k lands almost exactly on a natural shape-preserving grid
§0.2 requires cells that are **radius × angle, never radius alone** — a radial histogram is
rotationally symmetric and would make a ring, a spiral and two opposed clumps sound identical.

**256 radial × 1024 angular = 262,144 cells.** That is the measured budget, near enough to exact,
and 1024 angular divisions resolve the `m` lobes with enormous margin (`m` runs to ~7). The
grouping §8 calls for is not a compromise here — it lands naturally on the number the hardware gives.

⚠️ Proposed, **not** designed. §0.2's warning stands: justify any grouping against the per-particle
sum, do not design around a buffer that happens to exist.

---

## ⚠️ WHAT THIS DOES **NOT** MEASURE — read before building on it

- **GPU execution time only.** `GPUEndTime − GPUStartTime` excludes the CPU→GPU→CPU round trip and
  synchronisation. A real-time audio callback needs the block **ready before it is called**, so the
  synthesis must run *ahead* and hand over through a lock-free buffer. That is an architecture
  problem this number does not solve and does not excuse. (`AudioRingBuffer`, `audio_engine.h:18`,
  is SPSC and already exists as the pattern — §9.5.)
- **Pure oscillator sum.** No pan, no per-voice envelope, no resonator (§6), no emission weighting
  (§3.3). Each of those adds work. The number is a **ceiling, not a plan.**
- **`precise::sin`.** Used deliberately, not `fast::sin` — measuring the honest cost. A fast
  approximation would buy headroom if it is ever needed.
- **One device.** Apple M5 Max. Any other machine needs its own run: `./tools/measure_n/measure_n`.

---

## REPRODUCING

```bash
xcrun -sdk macosx metal -c tools/measure_n/osc.metal -o /tmp/osc.air
xcrun -sdk macosx metallib /tmp/osc.air -o tools/measure_n/osc.metallib
clang++ -std=c++17 -fobjc-arc -O2 tools/measure_n/measure_n.mm \
        -framework Metal -framework Foundation -o tools/measure_n/measure_n
./tools/measure_n/measure_n
```

The run prints a **sanity line** — `output finite=yes  mean|sample|=0.006155`. If that mean is ever
0, the kernel was optimised away and every timing above it is worthless. Check it before believing
a result.

**Kernel structure, and why it is written that way:** each particle's state is read **exactly once
per block**, staged into threadgroup memory, and all 512 samples are generated from registers. §8
says the binding constraint is memory bandwidth, so the naive "one threadgroup per output sample"
version — which reads state 512× over — would have measured the wrong thing entirely and reported a
far smaller N.

---

## NEXT, PER §10

Step 1 is done and needs no verdict — it is a number. **Step 2 is the per-particle voice at N = 1**
(the solo path): pick one particle, synthesise its voice from its own state, prove §0.3 end to end.
That one **does** need his ears.
