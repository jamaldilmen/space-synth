# HANDOFF 2026-07-19 (session 2) — deep physics dive, toilet NOT solved, measured a lot

_Written 2026-07-19 ~13:26:00 CEST. Branch `session-2026-06-30-honest-spacetime-friction`.
Supersedes `HANDOFF_2026-07-19.md` (session 1). Read `memory/space_synth_angular_momentum_is_the_wall_2026-07-19.md` FIRST._

## One-line state
The honest rotating cloud **still drains to the "toilet" / two blobs** (Jamal's eyes, ground truth,
end of session). This session did NOT fix it — but it MEASURED the mechanism cold and ruled out
several roads. Nothing committed. Only uncommitted code = the read-only `[BALANCE]` probe (main.cpp).

## THE PIVOT (Jamal, ~13:15): "the disk was just to TEST params. FOLLOW THE PHYSICS."
All the hand-built-disk work (two-population, spatial separation, delayed injection) was scaffolding
to probe parameters — NOT the goal. The goal is the honest single rotating cloud following real
physics. All disk scaffolding was reverted (`git checkout src/core/particles.cpp`).
**Do not rebuild a hand-crafted disk.** The BH + disk must EMERGE (canon: [[space-synth-bh-core-directive]]).

## PROVEN this session (measured, keep these)
1. **Angular momentum is THE wall.** `SS_TEST_RADIAL` (spawn support=0, kill all L): horizon fires
   `r_h 0→0.94`, whole field to r≈0.06, HELD stable 4 min. Rotating default: stalls at the
   centrifugal barrier r≈0.645, hollow shell, `r_h=0` forever. Remove L → hole forms. Airtight.
2. **The honest cloud DOES accrete — but as a fast RADIAL DRAIN, not a spiraling disk.** LTRANS
   (α-disc L-transport, bit25) is DEFAULT ON and WORKS: at the r≈8 barrier over 3 min, `L 0.034→0.012`
   (L shed) and `r_h` grows 0.12→0.20. BUT `sup 0.67→0.22` → matter goes radial and plunges = the
   toilet. The spawn header (particles.cpp ~110) already said it: "L removed too fast → matter plunges
   to core... Fix is the L-transport RATE."
3. **⚠️ KEY NEGATIVE RESULT: lowering the drain rate moved the metric but NOT the visual.**
   `F_LTRANS 100→10` (particles.metal ~1462): `sup` held 0.65–0.80 (vs 0.22), still accreted
   (`r_h`→0.156). Metric much better. **Jamal's eyes: "still the exact same toilet."** So the
   L-transport RATE is NOT the whole cause. Reverted to 100. **The sup≈1 target is necessary but not
   sufficient — chasing F_LTRANS alone is a dead road (Jamal: "we tried all these roads before").**
4. **Two-pop scaffolding (abandoned) proved the hole CAN hold:** dominant low-L core (F_NUC 0.75,
   support 0.10) + light disk → `r_h=0.90` forms and HOLDS ~2 min (entropy/area-monotonic). But the
   hand-built disk gets PUMPED OUT (r~4→19, sup>1) by **violent relaxation** during the core's collapse
   — a cold disk spawned into a live collapse always gets heated/flung. Moot now (no hand-built disk).
5. **compute↔render lie:** the HUD "BLACK HOLE FORMED" = a density latch (`hole=1.00`), DECOUPLED
   from the honest geometric `r_h`. The render can claim a hole that `r_h=0` says isn't there. This is
   the phase-gate Jamal wants gone.
6. **The 90% `[ACC]` integ-clamp is ENTIRELY the collapsed core** (`clamp=5.5` at r=0.05, `≈0.00` at
   every disk/outer radius). It's inside the horizon (membrane freezes it). Sub-stepping the PM path
   would clean the core but does NOT touch the outer/disk matter — not the ring/toilet fix.

## THE INSTRUMENT (keep, uncommitted in main.cpp ~2315) — Jamal's ENTROPY idea made measurable
`[BALANCE]` extends `[SHELLV]`, read-only, prints per radial shell:
- `L=r·vt` (spin / specific angular momentum — track over time: falling=transport, flat=stall)
- `vcirc=√(GMenc/r)·kDt` (gravity — from probe-estimated enclosed mass)
- `sup=vt/vcirc` (**the balance: <1 plunges, ≈1 stable orbit, >1 flies out — THE readout**)
- `clamp=gacc·dt/c` (>1 = integrator c·dt cap truncating the kick, localizes the [ACC] clamp)
- entropy/area law = watch `[HORIZON] r_h` monotonic (any decrease = illegal frame = a bug; caused
  once by Jamal playing a NOTE mid-run, which kicks the play/cymatics regime — never probe while he plays).
Shell edges are currently `{1,3,6,10,20}` (line ~2320) — widen/narrow per what you're chasing.

## DEAD ENDS — do NOT revive (all tried, all failed)
- Every SPAWN knob: R_DISK 18/8/3, annulus, nucleus support 0.55/0.80/0.95, disk support band-aid.
- Two-population core+disk; SPATIAL SEPARATION (compact core + gapped disk); DELAYED disk injection.
- Horizon-kick-gate (`!insideHorizon` around gkick) + HARD-FREEZE (finalV=0) — froze the core cleanly
  (clamp 5.5→0.43) but did NOT stop the disk pump (pump is pre-horizon). Reverted.
- `F_LTRANS` calibration (100→10) — metric moved, visual didn't. Reverted.
- A TOGGLE / knob is not a fix ([[feedback-a-toggle-is-not-a-fix]]). Believe his eyes over any probe
  ([[feedback-believe-his-eyes]]).

## THE OPEN PROBLEM (for the next window)
The honest rotating cloud drains to a toilet, and slowing the drain (F_LTRANS) did NOT visually fix it.
**Open question: WHY does sup≈0.7 still look like the exact same toilet?** Hypotheses, untested:
- It may be a *slower* toilet — F_LTRANS=10 wasn't run FULL (minutes). Real collapse fires over MINUTES
  ([[feedback-let-the-sim-run-full]]); a 4-min headless run may be mid-transient. RUN F_LTRANS=10 to
  completion and watch if it just ends in the same place slower.
- The visual "toilet" may be dominated by the OVER-SUPPORTED BULK at r≈15 (sup 1.5) violently relaxing
  and draining regardless of the inner L-transport rate — i.e. the toilet is violent relaxation of the
  whole cloud, not the α-drain. `[BALANCE]` at r>10 over full time would show this.
- The architectural wall ([[space-synth-full-codebase-model]]): collisionless softened mean-field,
  ε=cellSize≈horizon scale — the hole and disk live at the same resolution, so a clean thin accreting
  disk may be unresolvable without near-core mesh refinement (AMR) actually resolving r_s.
NEXT STEP IDEA (unvalidated): measure the WHOLE cloud's energy/entropy budget over a FULL run — is the
toilet L-drain (fixable via rate) or violent relaxation (needs the cloud to be born virialized/warm)?

## RITUALS (enforced)
- Build+deploy: `bash package_macos.sh` (NEVER bare make). Verify bundle binary/metallib ≥ source.
- Headless probe: run `./SpaceSynth.app/Contents/MacOS/SpaceSynth` (NOT `build/SpaceSynth` — dyld can't
  find Syphon there). stderr = `[HORIZON] [CORE] [GRAV] [ACC] [AMR]`; stdout = `[BALANCE] [SHELLV] [BAND] [MASS]`.
- LET IT RUN MINUTES. Never verdict off a 25–50s transient. `pkill -x SpaceSynth` before each launch.
- I change, HE plays. Build+open, STOP for his eyes. His eyes > any metric.
- Commit ONLY on his explicit order. Nothing committed this session.

## Uncommitted state
- `src/main.cpp` — the `[BALANCE]` probe (keep; useful). `imgui.ini` — his local, NEVER commit.
- `docs/HANDOFF_2026-07-19.md` (session 1) + this file — both untracked.
- Physics files (`particles.cpp`, `particles.metal`) = clean at committed HEAD `0edde58`.
