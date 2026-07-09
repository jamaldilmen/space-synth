# HANDOFF 2026-07-09 17:10 — play-stack rationalization done, eigenmode WIP (BROKEN)

Branch `session-2026-06-30-honest-spacetime-friction`. Read this first.

## COMMITTED & clean (safe)
- `bc09973` Play-stack rationalization: measured every live play force under identical
  MIDI input, **deleted swirl (Biot-Savart) + breathing (radial Y·12)** — the sweep
  proved zero shape contribution (visual + σ identical off); post-deletion shape
  verified unchanged. Kept: sculpt (THE law), web (binds escapers), impulse (transient,
  clamped), jitter (low-stakes). SS_PLAY_SKIP gates for sculpt/impulse/web/jitter/symbreak
  remain as instruments (bits 16,18,20,21,22).
- `40e1cf7` agenda doc · `4bd414f` 2026-07-08 approved build (render overhaul + blue-noise
  calm launch + impulse clamp) · `833be93` temp-bridge WIP (SPH u→display, bit12).
- Binary + imgui.ini intentionally NOT committed (Jamal's ruling). SS_SPH/[CLOSURE] left in.

## UNCOMMITTED — eigenmode re-land, increment 0-1 (⚠️ BROKEN, gated behind SS_EIGENMODE)
Files: `src/render/particles.metal`, `src/main.cpp` (+ untracked `tools/measure/`, `NOTES.md`,
this doc). Default launch (no env) is UNAFFECTED and runs normally (~52fps) — the eigenmode
is opt-in via `SS_EIGENMODE=1`.

**What's in (particles.metal):**
- `besselJm(n,x)` — GPU Bessel primitive, fixed 20-iter loop (NO data-dependent break).
  VERIFIED vs known values + CPU bessel.cpp (err <1e-5 for x≤10). Test: `tools/measure/bessel_test.cpp`.
- `besselJmD(m,x)` → (J_m, J_m'), J_{m-1} from DIRECT series (not the 1/x recurrence — that
  blew to NaN on the axis).
- cylindrical eigenmode Gor'kov force F=−Ψ∇Ψ, Ψ=J_m(k_ρρ)cos(mθ)cos(k_z z), analytic ∇Ψ,
  gated `if (u.debugFlags & (1u<<23))` inside the voice loop after the sculpt block.
  Tuning consts: `EIGEN_R=30, EIGEN_C=5000 (coarsened from physical 880), EIGEN_STRENGTH=30`.
- main.cpp: `SS_EIGENMODE=1` → bit23 (prints `[EIGENMODE] ON`).

**THE BLOCKER (unresolved):** with SS_EIGENMODE=1 the play field FREEZES at the rest
star-map — [SHAPE] σ stays exactly (27.7,27.9,27.9), screen ~black. Happens whether sculpt
is on or off. A constant test-push (shiftVx+=3) in the same block ALSO didn't move the field.
Fixed one NaN (the recurrence) but the last eigenmode-alone test STILL froze.

**Leading hypotheses (pick up here):**
1. **NaN poison** still: an Inf/NaN from the eigenmode enters shiftV → a downstream finite-guard
   zeroes velocities → whole sim frozen (would explain why even sculpt froze in the augment test).
   NEXT: after the recurrence fix, RE-TEST augment (`SS_EIGENMODE=1`, no skip) — does sculpt
   collapse again? If yes, NaN was it and only the eigenmode-alone/home-pin remains.
2. **Home-pin** (particles.metal ~2048, `nextPos=mix(nextPos,target,alpha)` when
   totalAmplitude>0.005) dominates when the play force is weak — sculpt (alpha·25) overpowers it,
   eigenmode can't. May need to gate the home-pin off under SS_EIGENMODE, or make eigenmode strong.
3. **Scale/units unknown**: play radius caps (ORBIT_R_CHLADNI=3, STAR_MAP_CAP=100) don't
   reconcile with σ readings (~2–28). EIGEN_R=30 is a guess. Must understand the play position
   units before tuning k_ρ/k_z. c=880 physical gives ~35 axial layers over the cluster (too fine).

**Recommendation for next window:** either (A) `git checkout src/main.cpp src/render/particles.metal`
to drop the eigenmode WIP and restart it cleanly with the units understood first, or (B) debug the
freeze via hypothesis 1→2 above. The infra (Bessel, Gor'kov, PSO-hang fix) is sound and worth keeping;
the integration into the play state is the unsolved part.

## PSO-HANG LESSON (fixed, keep in mind)
Inlining a variable-length-loop `besselJm` 7× (6 finite-diff calls + 1) hung the METAL SHADER
COMPILER at pipeline-state creation → app stuck at startup (spawned, audio ran, but NO window,
0 frames, sleeping at 0% CPU after ~3s spawn). Not a GPU TDR, not the flaky launch bug. Fixed by:
fixed-count unrollable loop + analytic gradient (down to 3 Bessel calls). Lesson: heavy
variable-loop functions inlined many times = Metal PSO-creation hang.

## MEASUREMENT RIG (works, in `tools/measure/`) — the mic method does NOT work here
- App listens on **IAC Driver Bus 1**. Drive it with `midinote.swift` (swiftc CoreMIDI sender:
  `midinote IAC hold <s> <notes>` / `pat` / `arp`). NO mic, NO afplay (the built-in mic doesn't
  pick up afplay in this setup). Reproducible real input.
- Launch binary DIRECTLY with env: `SS_PLAY_SKIP=sculpt SS_EIGENMODE=1 SpaceSynth.app/Contents/MacOS/SpaceSynth > log 2>&1 &`
  (MIDI needs no mic/TCC perm, so direct launch is fine).
- Screenshot: `winid.swift` (CGWindowList → window id) then `screencapture -x -o -l<id> out.png`.
  Needs Terminal to have Accessibility (osascript keys) AND Screen Recording perms — both GRANTED,
  no restart needed.
- Clean shot: osascript `key code 48` (TAB = hide HUD) + `key code 124` (right arrow = turn 90°,
  to see the elongated shape's length). [SHAPE]/[VEL] probe prints every 240 frames (~4.4s) → use
  ≥14s holds to see the shape evolve.
- Scripts: `run_config.sh <cfg>` (one config: launch/HUD-off/turn/single+chord+arp/3 screenshots),
  `sweep2.sh`, `analyze.py`. Recompile senders: `swiftc -O tools/measure/midinote.swift -o /tmp/midinote`.

## BUILD RITUAL
`bash package_macos.sh` (NEVER bare make). Verify bundle timestamp ≥ source. Relaunch:
`pkill -9 -f SpaceSynth; open -n SpaceSynth.app` (or run the binary directly to capture stdout).
