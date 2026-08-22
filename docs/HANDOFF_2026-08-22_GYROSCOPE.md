# SPACE SYNTH TUBE — handoff 2026-08-22 08:45:00

> **His verdict on this state:** "looking better" (2026-08-22 08:40:10, on the unified playback axis)
> **Cold start:** read `docs/TODO.md` — NOT this file, NOT older handoffs. `docs/BOARD.md` and `docs/BOARD_BLACKHOLE.md` are the detail; `docs/SHOW_2026-09-05_COLOGNE.md` is the show.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube` branch `kill-the-tube-2026-08-11` @ `d28a394` **+ 10 uncommitted paths**
**Build + launch:** `bash package_macos.sh` then `pkill -x SpaceSynth; open -n SpaceSynth.app --env SS_FULLSCREEN=1`
🎪 **14 days to Cologne** (2026-09-05, 10×4 m, 2.5:1, 6 beamers).

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| **G4** | **THE GYROSCOPE.** Field sheared into nested tilted rings | `axis = poseAxis(rel)` — a different rotation axis per star, tilted by its own `atan(\|z\|/ρ)` (set 2026-08-15) | ONE axis for the field, `float3(0,0,1)`, derived from the launch law `v = ẑ × r` | `render.metal:733` | **[HIS WORDS]** 2026-08-22 08:40:10 *"looking better"* |
| **BH6** | **`SS_NO_AMR` NEVER DISABLED ANYTHING** | bit15 shared: `bhToggles \| (amrOn ? 0x8000u : 0u)`, and bit15 was already set by `uiTogMetricShadow` (default ON) ⇒ the OR was a no-op | AMR owns bit21; bit15 is metric-shadow only | `renderer.mm:1962` · `particles.metal:2164` | **[MEASURED]** matched-resolution A/B 2026-08-22 05:05: core M(<0.5) 2.935e4 off vs 5.283e4 on. ⚠️ n=1/side |
| **BH-shadow** | Metric shadow "fake and annoying" | `uiTogMetricShadow = true` | `false` | `app_state.h` | **[HIS WORDS]** 2026-08-22 ~06:50 *"turn the shadow off btw its fake and annoying"* |
| **b_c** | `bc_validate.cpp` cited by the shader but ABSENT from the tree | no validator | Written, compiled, RUN | `tools/bc_validate.cpp` | **[MEASURED]** independent null-geodesic bisection = 5.196152422707 M vs analytic 3√3·M, rel err 8.2e-15; shipped shader constant correct to 4.4e-09 |
| **LUT** | Deflection sampled log-spaced in `b`, first interval 2.600→2.645 covering the whole divergent band | 18.2% / 23.6% max error in the ring / arc bands | log-spaced in `(b − b_c)`, same 256 entries | `renderer.mm` LUT build · `render.metal` `lensAlphaSample` | **[MEASURED]** vs the integral at 200k quadrature pts: ring 18.16%→0.000%, arc 23.58%→0.000%, far field 0.00%→0.053%. ⚠️ **[HIS WORDS]** no visible change — see §2.4 |

## 2. 🚨 OPEN — his list, verbatim

1. **"there sno lense in th euniverse right.. jsu tphysics .. and we ar ehitting a brick wall of ours right there"** (2026-08-22)
   `MEASURE:` the LUT fix landed and he saw NOTHING change ⇒ the rim is not deflection-limited. Next probe: does rim brightness track SPRITE COUNT rather than α? Count sprites landing in `[2.605, 2.65] r_s` per frame.
   State: **[READ]** the rim is the SECONDARY image, floored at 2.60/2.62 and culled ≤2.605 (`render.metal:1129-1136`) — **[HYPOTHESIS]** that the count, not the angle, sets its brightness.

2. **"the merger to bh state is broken. only works at laucnh with the fake drag"** (2026-08-22)
   `MEASURE:` `[PROBE-1000] live=` over a soak; `[PULLGATE] Mlive`.
   State: **[MEASURED]** `live=999 → live=2` of 1000, `insideRS=0` — the field ate itself to 0.2%. **[READ `particles.metal:3792`]** a merge sets mass→0 and teleports the corpse to r≈6928, 108× outside the ±64 domain, frozen. **There is no infall anywhere in the engine.** Revival only during sustain. → board row **G4b**.

3. **"the axis is lose"** — the deeper half is NOT fixed (2026-08-22)
   `MEASURE:` `[DISKZ] H/R` per shell.
   State: **[READ `particles.cpp:256-262`]** every particle gets `v = ẑ × r`, `vz = 0`, while the halo (15%, Plummer a=15) is spawned ISOTROPICALLY. Off-plane particles are on inclined great circles by construction. **[MEASURED via git blame]** latent since `1bb9c70` 2026-07-20 — **a month old, NOT the recent regression he correctly identified.** → board row **G4a**.

4. **The perfect black circle is NOT the metric shadow and NOT the lens.**
   `MEASURE:` toggle `lastHorizonR`, or comment the draw at `renderer.mm:3852`.
   State: **[READ `render.metal:3164` + `renderer.mm:3852`]** a depth-only analytic sphere at `b_c`, gated ONLY on `lastHorizonR > 0`, **not on bit15** — so flipping the metric shadow off did not remove it. It is ALSO what makes the hole occlude (the 2026-08-14 "the hole is a body" fix). ⚖️ **His call.**

5. **"star size is still stars, not smear of stretched light"** — G2, unchanged this session.
   State: **[MEASURED]** 96–99% of stars in the bottom size bin at every resolution; `clamp(rawSize, 1.0f, …)` does all the work.

6. **Audio, show-relevant and cheap.** **[READ]** `fprintf(stderr,…)` runs inside `audioOutputCallback` every 100th callback (`audio_engine.mm:66-69`) and `fft.cpp:59` heap-allocates per FFT call — both on the CoreAudio realtime thread. 4 of 14 lock sites are on that thread, 3 blocking. Protects the LIVE half of the set.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Per-star playback axes — REJECTED 2026-08-22 08:20:00.** `poseAxis(rel)` tilts by each star's own elevation, so stars at different heights rotate about different axes and the field shears into nested rings. It was added 2026-08-15 to match the ARC RIBBONS; **those were deleted 2026-08-20**, so the reason no longer exists. One field, one orbit normal.
- **"poseAxis is position-only, NOT r × v" — THE DISTINCTION IS FALSE.** Expand it for the launch law: `r × (ẑ × r) = (−zx, −zy, x²+y²)`, term for term identical to `poseAxis`. The rejection note claims a difference that is not there. **7th "a comment is not a mechanism" sighting.**
- **Improving deflection ACCURACY to fix the rim — did not work.** The LUT went from 23.6% error to exact in that band and he saw no change. Whatever paints the rim is not the bending angle.
- **Reading `sup = vt/vcirc` from `[BALANCE]` when the field is mostly corpses** — `Menc = encN/PROBE_N × Mfield` counts LIVE probe particles only, so it under-reads ~450× and `sup` inflates to nonsense. See §5.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-08-22 08:45:22  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube

1. git
  ok    branch kill-the-tube-2026-08-11, HEAD d28a394
  WARN  10 uncommitted path(s)
  WARN  2 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at d28a394
  WARN  docs/BOARD_BLACKHOLE.md is 87547B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  ok    docs/BOARD.md current at d28a394
  WARN  docs/BOARD.md is 97393B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    31 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:546:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:733:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1347:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1646:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1649:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2687:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/postfx.metal:43:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  7 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: no failures.
```

**§5 sites read this session, not skipped:** `render.metal:546` (poseAxis +Z fallback — correct, it is the polar degenerate case) · `:733` (**the change itself**, derived from the launch law) · `:1347` and `:1649` (sprite tangent, hardcoded +Z — **this is board row BH2, still open**; the march at `:3463` still uses `poseAxis`, so playback+sprite now agree and the march does not) · `:1646` (`rXY` magnitude, no plane assumption) · `:2687` (2D perpendicular, screen space) · `postfx.metal:43` (HSV helper — false positive).

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The rings are over-supported by 30–51×, they cannot fall in" | `sup` is built on `Menc = encN/PROBE_N × Mfield`, which counts only LIVE probe particles. With 98% of the probe dead, `Menc` under-read ~450× and inflated `sup`. Broken denominator, not physics. |
| "8× the pixels moved meanPx 1.02 → 1.26" (S2 A/B) | Time-confounded — the two runs were sampled at 12 s and 25 s. At a matched first sample both read **1.02**, which confirms the device-pixel diagnosis harder than the wrong numbers did. |
| "The `[AMR]` diagnostic count 0-vs-8 proves the BH6 fix works" | That print is gated on `amrOn` directly (`renderer.mm:2592`), not on the bit I moved. It proves only that `SS_NO_AMR` sets `amrOn=0`, which was always true. |
| "I turned the shadow off, the hole falls back to the particle silhouette" | The dark disc is a separate depth-only sphere not gated on bit15. Flipping `uiTogMetricShadow` did not remove what he was looking at. |
| "The clamp pins everything onto one radius, that IS the painted ring" | The secondary culls anything ≤2.605 rather than stacking it. The real defect was LUT *resolution*, not a floor. |
| I chased "the fake drag" as his point | **[HIS WORDS]** *"why the fuck would my point be about the drag it doesnt make sense. im clearly talking about the rings lol"* — I acted on a subordinate clause instead of the sentence. |

---

**Last Updated:** 2026-08-22 08:45:00
**Folded into board:** `docs/TODO.md` (cold start) + `docs/BOARD.md` + `docs/BOARD_BLACKHOLE.md` @ 2026-08-22 08:45:00
