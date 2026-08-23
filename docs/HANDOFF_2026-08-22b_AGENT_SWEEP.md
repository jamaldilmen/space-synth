# SPACE SYNTH TUBE — handoff 2026-08-22 10:10:00 (block 2, the agent sweep)

> **His verdict on this state:** not seen yet — nothing visual changed in this block. The last look verdict stands: "looking better" (2026-08-22 08:40:10, on the unified playback axis).
> **Cold start:** read `docs/TODO.md` — NOT this file. Block 1 of today is `HANDOFF_2026-08-22_GYROSCOPE.md`; it is history, not a cold start.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube` branch `kill-the-tube-2026-08-11` @ `ae6ecdd` **+ 6 uncommitted paths, 7 commits unpushed**
**Build + launch:** `bash package_macos.sh` then `pkill -x SpaceSynth; open -n SpaceSynth.app --env SS_FULLSCREEN=1`
🎪 **14 days to Cologne** (2026-09-05, 10×4 m, 2.5:1, 6 beamers).

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| **G2-instr** | The size histogram could not say what drove the floor | Only `out.pointSize` was binned — POST-clamp, so every floored star reads 1.0 px and lands in bin 3 alongside naturally-1.0–1.4 stars | `[KPROBE-RAW]` bins **rawSize BEFORE the clamp**, same every-64th gate, same log2 ladder, slots 84–102 | `render.metal` probe block · `renderer.mm` readout | **[MEASURED n=25533]** meanRaw **1.079 px**, FLOORED **52.5%**, capped **0.0%** |
| **G2-figure** | "96–99% of stars sit in the bottom bin, the floor does all the work" | Board headline, repeated all session incl. the published artifact | **RETRACTED.** Real figure: **52.5% floored.** And `zoomCap` **never binds** — that branch and its `fluxComp` are dead here | board row G2 | **[MEASURED n=25533]** |
| **U2** | Accent had no derivation | picked | **`#306CFF`** from **2400 K**, 4.55:1 over void. The flip is the EXISTING (B,G,R)→(R,G,B) swizzle read one transpose apart | `render.metal:382` · `spectral_lut.h:37-55` | **[READ]** swizzle, WindowBg α=0.65, Electric Indigo all re-verified by me |
| **G12** | Board said compaction is blocked by `imfMassOfId(id)` slot stability | treated as a hard blocker | **Wrong for INDEX compaction** — `liveIds[]` + `id = liveIds[tid]` moves nothing and breaks none of the twelve id-holders. **MEDIUM, not a rewrite** | `BOARD.md:409` corrected | **[READ]** mechanism, recycle and write-back gate re-verified by me |

## 2. 🚨 OPEN — his list, verbatim

1. **"star size is still stars, not smear of stretched light"** — G2, now with a real number.
   `MEASURE:` `[KPROBE-RAW]` meanRaw / FLOORED%.
   State: **[MEASURED]** unclamped, the typical star is **1.079 px**. Removing the floor yields SUB-pixel dots, not smear. **A size dial cannot stretch a 1-px point** — that is the wall, and it is why every prior G2 attempt bounced. **[HYPOTHESIS]** the honest route is a PSF whose width is an instrument property rather than geometry, so apparent size follows FLUX. Not started, not pitched as a rewrite.

2. **"there sno lense in th euniverse right.. jsu tphysics"** (2026-08-22)
   State: **[HIS WORDS]** the LUT fix landed and he saw NO change ⇒ the rim is not deflection-limited. Next probe: does rim brightness track SPRITE COUNT rather than α? Count sprites landing in `[2.605, 2.65] r_s` per frame.

3. **The perfect black circle is NOT the metric shadow and NOT the lens.**
   State: **[READ `render.metal:3164` + `renderer.mm:3852`]** a depth-only analytic sphere at `b_c`, gated only on `lastHorizonR > 0`. It is ALSO what makes the hole occlude. ⚖️ **His call.**

4. **G12 next moves, in order.** **[READ]** hoist the corpse discard in `particle_vertex` from `:1889` up to the mass at `:768` — ~1120 lines currently run per corpse, ×2–3 passes. ⚠️ Copy the horizon-cull output block (`:783-799`), NOT the `:1889` block, which leaves 7 varyings uninitialised. Then index compaction. **A/B on `lastComputeMs`, never fps — vsync would blind it.**

5. **Audio, show-relevant and cheap, unchanged.** **[READ]** `fprintf` inside `audioOutputCallback` (`audio_engine.mm:66-69`) and a per-call heap allocation (`fft.cpp:59`), both on the CoreAudio realtime thread.

6. **G13 — `entanglement.z/.w` double-booked** as star-map θ/φ and bond-target. ESCAPER RECYCLE reads θ/φ from those words, so **bonding corrupts the recycle destination**. **[HYPOTHESIS]** on the second half (two incompatible write conventions) — agent-reported, not verified by me.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Judging the star-size law from `[KPROBE-SCALE]` — REJECTED 2026-08-22 09:52.** It bins POST-clamp. Bin 3 spans [0.92, 1.41), so floored stars (exactly 1.0) and natural 1.0–1.4 stars are ONE bar. Any conclusion drawn from it about the law is unsound. Use `[KPROBE-RAW]`.
- **DATA compaction for G12 — NOT RECOMMENDED.** Genuinely large: twelve id-holders, and `imfMassOfId(id)` requires slot stability. Index compaction gets the same prize for a fraction of the risk.
- **`SS_NO_DEADSKIP` as an A/B control — BROKEN AS SHIPPED.** Parsed once into a static (`main.cpp:2520`), so it cannot alternate within a run. It also gates one of twelve-plus corpse-paying passes. Any past null from it is uninterpretable.
- **Warm UI colours from the blackbody locus — REJECTED 2026-08-22 by measurement.** Two candidate tints landed 0.007 and 0.014 from the locus, i.e. they were lifts wearing a flip. The locus is asymmetric; red reaches 1:0.089 R:B while blue never passes Rayleigh-Jeans. **No warm UI colour is derivable here.**
- **Launching the G10 agent — 3 attempts, 3 distinct failure modes** (session limit, API error, 600 s watchdog stall). Two wrote nothing at all. Do it inline instead; it is two source reads and a Nyquist calculation.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-08-22 17:26:13  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube

1. git
  ok    branch kill-the-tube-2026-08-11, HEAD ae6ecdd
  WARN  6 uncommitted path(s)
  WARN  7 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at ae6ecdd
  WARN  docs/BOARD_BLACKHOLE.md is 87547B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  ok    docs/BOARD.md current at ae6ecdd
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
  ?     src/render/render.metal:2711:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/postfx.metal:43:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  7 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: no failures.
```

**§5 sites read this session, not skipped:** `render.metal:546` (poseAxis +Z fallback — correct, the polar degenerate case) · `:733` (**this session's fix**, derived from the launch law) · `:1347` and `:1649` (sprite tangent, hardcoded +Z — **board row BH2, still open**; the march at `:3463` still uses `poseAxis`, so playback and sprite now agree and the march does not) · `:1646` (`rXY` magnitude, no plane assumption) · `:2711` (2D perpendicular, screen space — shifted from `:2687` by this block's probe insertion) · `postfx.metal:43` (HSV helper — false positive).

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "96–99% of stars sit in the bottom size bin — the floor does all the work" | Read from the POST-clamp histogram, whose bin 3 merges floored stars with natural 1.0–1.4 ones. **[MEASURED]** truth: 52.5% floored, meanRaw 1.079 px. It is in the published artifact too and that is now stale. |
| "A merge teleports the corpse to r≈6928, 108× outside the domain, frozen, unreachable by any force path" | **The park is ONE FRAME.** `particles.metal:1161` ESCAPER RECYCLE re-enters it at its star-map home on a Kepler orbit the next frame. What holds it dead is the write-back gate `if (mass > 0.0f)` at `:3502`. The CONCLUSION (nothing falls in) survives; the mechanism did not. Corrected in the board and in memory. |
| My own arithmetic on the size law (`rawSize ≈ 7 px`) | Derived from an assumed camera distance instead of measured. Off by ~7×. I stopped deriving and instrumented it instead. |

---

**Last Updated:** 2026-08-22 10:10:00
**Folded into board:** `docs/TODO.md` (cold start) + `docs/BOARD.md` + `docs/BOARD_BLACKHOLE.md` @ 2026-08-22 10:10:00
