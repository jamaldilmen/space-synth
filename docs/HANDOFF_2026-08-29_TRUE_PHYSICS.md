# SPACE SYNTH — handoff 2026-08-29 17:38:00 — **TRUE PHYSICS**

> **His verdict 2026-08-29 17:20:00:** *"we just had the biggest breakthrough in physics since we started this project lol. Amazing."*
> **His verdict on the build 2026-08-29 15:43:00:** *"at non rest the entire thing is still very broken. stuff shoots out violently after 2x basically. mergers dont make sense on the high speeds yet... during rest its ok. but this is not a wallpaper but an instrument."*
> **Cold start:** read **`docs/BOARD.md` §X** (the law + every measurement) and **`docs/BOARD_BLACKHOLE.md` §W** (the BH half) — NOT this file, NOT older handoffs.
> 📅 **7 DAYS TO REVEAL** (his count, 2026-08-29). Show: Cologne 2026-09-05.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-POST-TUBE` branch `post-tube` @ `d0db70b` (sources) — bundle commit is the last one.
**Build + launch:** `bash package_macos.sh` (**never bare `make`**) then `SS_FULLSCREEN=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth 2>&1 | tee run.log`
**New measurement gates:** `SS_SUBSTEPS=N` · `SS_TIME_WARP=X` · `SS_TRUE_SUBSTEPS=1` · `SS_SEQ=transitions|staccato|held`

---

## 0. ⏱️ THE LAW — his frame, verbatim 2026-08-29 17:05:00

Origin: an LED ventilator at Radio eins soundcheck, spinning fast enough to read as a screen.

> *"Our frames are just a window. The universe does a lot in between a single frame. The renderer is just the readout of the physics. Our shutter. Our engine runs based off of the clock of the computer it runs on. That's the core anchor. Cause our universe and the one we're in are the same time. A second is a second. Speed of light can't go further than speed of light. No matter how much 8x or 2x we do. Unified system."*
>
> *"Frames per second are not real. It's just an abstract concept so I can see it. But the physics don't give a shit about that. The apple is falling at its rate that it's falling at. I'm only seeing it at the rate I'm seeing it fall at because I'm a human being. The apple doesn't give a shit."*

⭐ **NOTHING PHYSICAL MAY BE EXPRESSED PER FRAME.** The renderer is the shutter; the wall clock is the anchor. One rule; it replaces every separate "bug" below.

🚨 **We are currently WORSE than the fan: the fan spins at its own rate and the eye samples it — our engine makes the blade spin FASTER when the eye blinks faster.**

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | Substeps were counterfeit | 22 of 23 passes ran once/frame; only the integrate re-ran, so N steps advanced against a FROZEN force field | Proven, and a probe exists that un-freezes it | `renderer.mm:3070` (loop) vs `:2138–3034` (passes) | `[MEASURED n=3 seeds × 3 checkpoints]` frozen **0.25×** the N=1 reference, true **0.99×** |
| 2 | "The fix already exists, substeps are stable" | Believed from the last handoff | **RETRACTED** — his eyes, then measured | — | `[HIS WORDS 2026-08-29]` *"it becomes straight chaos after 4x already"* |
| 3 | Mergers died under warp | The "×120 seed-capture convention": `v = displacement × 120` assumed dt=1/120 s ⇒ `vrel²` off by **3.92 × warp²**; `:3704` then refuses fusion | `v = displacement / u.dt`, warp-invariant | `particles.metal:1425`, `:3704`, `:4059` | `[MEASURED n=2, matched sim time]` warp 16 went from `Mmax=50.0`/0 seeds/0 merges (**dead**) to 11426 & 8734 with seeds forming |
| 4 | The speed of light moved with the warp dial | `mix(c*dt, CHLADNI_VCAP, playGate)` mixed a per-second term with a per-FRAME constant ⇒ 20.69c @×1, 10.35 @×2, 5.17 @×4, 1.29 @×16 | Both terms are velocities; `* dt` at the end | `particles.metal:3209` | `[MEASURED]` his log `speed max 20.690 c` vs predicted **20.691**; peak now warp-invariant **22.4/21.6/21.1** at ×1/×2/×4 |
| 5 | Cadences gated on frames | SPH and the Poisson solve refreshed once per FRAME however much sim time it advanced | Both count sub-steps (`stepTick`) | `renderer.mm:2359`, `:2522` | `[MEASURED n=3]` N=1 reference unchanged (identity on the shipped path) |
| 6 | Nothing could drive the instrument | Every measurement ran at REST — the regime he says is FINE | `SS_SEQ` drives short notes / chords / pauses; probe at 0.05 s | `main.cpp` | `[HIS WORDS]` *"play short notes, chords.. pauses, what happens in between"* |

## 2. 🚨 OPEN — his list, verbatim

1. 🚨 **THE ROOT — the universe's clock rate is proportional to frame rate.**
   `MEASURE:` `[READ renderer.mm:1466]` `dt = 0.0165f * timeWarpVal`, ONE step per frame, NO accumulator ⇒ sim-s per wall-s = `0.0165 × fps`. Only **60.61 fps** is honest.
   State: `[MEASURED n=5]` 119.5 fps → **1.97× real time**; 70.4 → 1.16×; 53.7 → **0.89×**. **2.2× spread in one session.** 🚨 And the sequencer advances `seqTime += dt` in WALL seconds while physics advances in SIM seconds — **his rhythm and his universe run on two clocks whose ratio is the frame rate.**
   ⭐ **FIX SHAPE:** the pinned dt was HALF right (it killed the variable-FPS energy pump). The missing half is a **wall-clock accumulator** — carry leftover real time, take as many fixed steps as the clock demands. Then **warp = MORE STEPS, never a bigger step**, capped by an accuracy governor. ⚠️ A true step costs **23.65 ms** vs **1.77 ms** for the integrate, so this REQUIRES reducing the required step, not buying more.

2. **"stuff shoots out violently after 2x... this is not a wallpaper but an instrument"** (2026-08-29 15:43:00)
   `MEASURE:` `SS_SEQ=staccato|transitions|held` + `[SEQPROBE]`.
   State: `[MEASURED]` rest = 0.14c. Between-note silence: **held 0.037c (settles) · transitions 2.65c (67% > c) · staccato 5.39c (91% > c)**. Relaxation e-folds at **τ=0.512 s** (n=11) ⇒ shedding the cap needs **2.60 s**; his staccato gap is **0.85 s**. `[READ particles.metal:854]` damping is keyed to the ENVELOPE, not the field, and is **inverted** — `fricPlay=pow(0.9,dt)` is HEAVIER than `fricRest=pow(0.99,dt)`, so leaving play gives LESS damping when the field is fastest.

3. ⛔ **c IS c — 20.69c is a violation, not a knob.** `CHLADNI_VCAP_PER_SEC = 72.7273` sim/s **is 20.69c**, superluminal by design. His law settles it: it must come down to c and the Chladni reach earned by force/coupling/time. ⚠️ Dropping it caused a ~41× pattern throttle in June — solve that honestly, do not re-raise the cap.

4. **The focusing fix is mostly thrown away.** `[READ particles.metal:1429, :4063]` `reach = 1.4f*su.cellSize` clamps `rt2` straight back. **Clamp + the 3×3×3 scan + ×120 all had to move; one is done.**

5. 📋 **HIS NEXT-SESSION LIST — verbatim 2026-08-29 17:25:00**
   - **RENDERING/camera:** *"as of now i can only screen record. A screen recording video looks like absolute shit. We have the expected resolution now. How are we gonna tackle a +16k reso in total."*
   - **OFFLINE RENDER:** *"Getting true physics right will enable ableton like offline rendering. More complex simulations rendered instead of real time. Beyond our machines capacity. Or, as in this case, pre-recording a set with automations in Ableton. Camera rides as macro. Camera shifts. Ortho cam. POV cam. All that needs to be tackled before the show day."*
   - **BH window:** *"how will true physics enable a true kerr 1:1 black hole to scale? How will it help fix mergers. And black hole mergers."* ⭐ ***"I want the money shot to be two black holes merging."***
   - **SCALE:** *"I want a single particle to look like the sun when I zoom onto it. How does distance work right now? When zoomed out stuff over saturates. It doesn't look right."*

6. **The remaining dresses — located, NOT fixed.** `BOARD.md` §X5: Φ never re-solved while playing (`renderer.mm:2522`) · `universeClockSec` ignores substeps (`main.cpp:2713`) · pose clock is wall-time, never warp-scaled (`renderer.mm:1792`) · capture/merge once per frame on the SHIPPED path · rebirth RNG uses `frameCounter` (`particles.metal:735`) · `REST_RECYCLE`/`SUSTAIN_REBIRTH` "per frame".

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Brute-force substepping — MEASURED UNAFFORDABLE 2026-08-29.** A true substep re-runs the whole force pipeline: **23.65 ms** vs **1.77 ms** for the integrate (13.4×). Predicted 94.6 ms at N=4, measured 93.3 — ~9 fps. The fix must REDUCE the required step, not buy more of them.
- **Copying Universe Sandbox directly — NOT APPLICABLE.** Their `IntegratorSubstepSystemGroup` re-runs the whole force+integrate group N times (verified in his own v36.3 install: `FindMinSafeTimestepJob` → `WriteLowestSafeTimestepJob` → `EstimateRequiredSubstepsJob`, plus `TimeStepBlockSort` and `BuildAttractorTree`; his `Player.log` says *"Using Hermite adaptive True"*). That works for ~10²–10³ bodies. We have 2×10⁶.
- **`SS_NO_CIC_MOMENTS` as a cost A/B — INVALID.** Disabling CIC makes compute *slower* (34.4 vs 23.7 ms); it is an optimisation with an expensive fallback, not an additive pass.
- **Single-run comparisons in this sim — BANNED, re-proven twice today.** `[MEASURED n=4 repeats, one build]` spread is **0.88–1.05×**, and seed formation bifurcates (the seed write at `particles.metal:3812` is a plain write, no atomic). A 0.99×→0.47× "regression" was one outlier run.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-08-29 17:30:16  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-POST-TUBE

1. git
  ok    branch post-tube, HEAD 081de6d
  FAIL  7 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M SpaceSynth.app/Contents/MacOS/SpaceSynth
           M imgui.ini
           M src/main.cpp
           M src/render/particles.metal
           M src/render/renderer.mm
          ?? run.log
          ?? run_HIS_SESSION_2026-08-29_1543.log
  WARN  build artifact is TRACKED — commit sources separately FIRST, then it alone:
          SpaceSynth.app/Contents/MacOS/SpaceSynth
  WARN  no upstream set for post-tube

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 01f1048 — 1 docs-only commit(s) since, no source change
  ok    docs/BOARD_BLACKHOLE.md size 106014B
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 01f1048 — 1 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 128909B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    39 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:566:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:753:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1109:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1407:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1410:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2501:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  7 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

**The FAIL was REAL and is now CLEARED.** Sources committed one concern per commit (`61562fc` probe, `0d68201` cadences, `93603f6` measurement gates, `052ec8a` ×120, `3e96a7b` play cap, `d0db70b` smoother), then docs, then the **tracked binary alone and last**. `run*.log` added to `.gitignore` — session artifacts, never state. `imgui.ini` restored at commit time. Re-run output is in the final commit message.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "`uiPhysicsSubsteps` is the fixed-dt accumulator — built, stable, a solved problem wired to the wrong control" (carried in from the last handoff and repeated by me) | 🚨 **It freezes the forces.** `[READ]` 22 of 23 passes run once/frame. Verlet under a CONSTANT acceleration is exact at any step count, so substeps ≈ raw dt-scaling. `[HIS WORDS]` *"it becomes straight chaos after 4x already."* |
| Every performance and physics number I gave before 15:43 | **All measured at REST** (`phase=0.0 amp=0.000`) — the regime he says is FINE. The relative comparisons hold (matched on step counts); **anything I said in *seconds* was measured against a rubber ruler** — see §2.1. |
| "The cadence fix made convergence worse (0.99× → 0.47×)" | `[MEASURED n=4 repeats]` the spread on one build is **0.88–1.05×**. It was ONE outlier run. I read noise as signal — the exact thing this board bans. |
| "Lower the 20.69c cap **or** make damping state-based — your call on feel" | A false choice. Under *"speed of light can't go further than speed of light"* the cap is not a tuning knob. **His law settles it; I should not have offered it as a preference.** |
| "avgSpeed/maxSpeed come from a coarse cached readback, read them as a step function" | `[READ renderer.mm:3199]` the readback is gated only by `if (numThreadgroups > 0)` — **no cadence, 1-frame latency.** The probe data was fresh; my own caution was wrong. |
| Warp-sweep and seed-sweep runs matched on **log-line count** | Matched runs must be compared at equal **sim time**, not equal line counts. Cost two full re-runs. At warp W one frame advances `0.0165·W`; at N substeps, `240·k·N`. |
| Three runs of one seed set (`s12345`) | **Contaminated** — a killed runner was still launching its own instances, the exact stray-instance failure `pass_cost` already warned about. Voided and re-run. |

---

**Last Updated:** 2026-08-29 17:38:00
**Folded into board:** `docs/BOARD.md` §X + `docs/BOARD_BLACKHOLE.md` §W @ 2026-08-29 17:36:00, both re-stamped at `4847e92` (the bundle; sources end at `d0db70b`).
