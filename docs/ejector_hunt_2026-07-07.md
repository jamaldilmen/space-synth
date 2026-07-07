# EJECTOR HUNT — the ~2.4c hot-pair escaper fountain (2026-07-07)

**Status: "1 then 2" COMPLETE — cross-cell merging + sub-step accumulator both
live and verified. Energy books read for the first time (clamp=0, counters off
the int32 pin); lowest fountain of any run (nOut 692@f6720). Pump reduced, not
dead (Etot 55→392/6720f). OPEN: residual bomb tail (per-sub-step dudt unbounded,
poison 26–108k, occasional pinned window), fps cost unmeasured, Jamal's
on-screen verdict, commit decision.**
**Last Updated: 2026-07-07 12:50:00**

## 12:50 — SUB-STEP ACCUMULATOR (option 2, plan §3.6b) — LIVE
Design: sph_force sub-cycles the pair exchange with FROZEN tile geometry
(neighbour pos/vel/ρ/P Jacobi-frozen at window start; positions move ≤3% of h
per frame — geometry is resolved, the u↔v exchange is the stiff part). Per-cell
adaptive N = clamp(⌈4·(c_s+|v|)·dtU/h⌉, 1, 8) via simd_max (threadgroup-uniform
→ barriers safe); own velocity + u advanced per sub-step, P re-derived from the
local EOS each sub-step (u→P→force feedback resolved); u clamped per sub-step
(kills the floor↔cap slam); provisional kick capped Δv≤c per sub-step and
|viCur|≤4c (without it viCur→inf, poison 9.7M/window — measured); forceOut =
window-mean force, compute_physics unchanged.
Verified (substep2.log): closure W~1.5e4/dyn~5e3/cool−2.6e4/clamp=0 — honest
flux scale at last; nOut 692@f6720 (best); U 64→141 ≈ cross-cell band.
⚠️ MEASUREMENT VARIANCE: two identical cross-cell builds gave U 130 vs 207
@f5760 (seed-cascade chaos) — single-run A/B is valid for nOut/poison/closure
magnitudes only, NOT the U slope.

## 12:36 UPDATE — option 1 built + verified; seeds-not-gas tried + REVERTED
- **Cross-cell merging (KEPT, verified)**: merge_stars now scans own cell + 13
  forward neighbour cells, per-particle atomic claims replace used[] (one
  initiator per pair, first claimant wins, no double-eat; compare-and-write
  guard retained). Result @f5760 vs same-cell baseline: **nOut 722 vs 1048
  (−31%), poison 1.2k–9k vs 14k–50k (−80%)**, mass books exact (Mlive
  constant), meanR 49.7 no cascade, backlog drain decays. SIDE EFFECT Jamal
  must see on screen: merger rate way up — Mmax 233 M☉, ~200 seeds by f5760
  (registry cap 256 — watch), many more nova flashes at rest.
- **Seeds-not-gas (REVERTED, measured worse ×3)**: excluding ≥50 M☉ bodies from
  SPH (both sides) → U 98→257, Etot 526→1437, nOut +28%, poison ×10. The
  gas–seed coupling is load-bearing: seed mass in ρ keeps core P/ρ² sane, and
  gas pressure is the only brake on ~200 massive bodies plunging through the
  core. Honest decoupling needs the accretion channel first — not in scope.
- Remaining pump @cross-cell state: Etot 204→411/5760f, dyn/clamp closure
  fluxes still int32-pinned → the fixed-dt energy-equation stiffness stands.
  **NEXT: sub-step accumulator (plan §3.6b).**

## The symptom
At rest, plain defaults (bit11+12+13+14, commit `9dfca4e`), the reaction engine
continuously ejects particles at up to ~2.4c (nOut grows ~+40 sampled/240f
forever), and interior U climbs monotonically (~77→140 per 8640f). Previously
believed to be honest evaporation; this session PROVED it is a numerical pump.

## Measured facts (headless rest runs, 2M live, [SPH]+[CLOSURE]+[PM] watchdogs)

1. **PE-instrumented ledger** (watchdog now samples the Poisson Φ → PE = ½Σm·Φ,
   same units as KE): over 8640f, U 77→140, escaper KE 26→452, **PE FLAT
   (−198→−175, shallowing)**. Total KE+U+PE more than doubles. Gravity does not
   pay for it → energy is CREATED. The "eruptions" (e.g. KEin ×10 at f5040 run 1)
   are episodes of the same pump (the f4800 Φ_ctr step ×1.64 = a merged heavy
   sinking into the centre cell — mass segregation, honest, but not the funding).
2. **Cadence-independent**: SS_SPH_CADENCE=1 vs 2 → nOut 689 vs 674 @f3600.
   Kills the stale-persisted-force-window theory.
3. **Not neighbour-list truncation**: densest interior cell holds 18–25 < 32 cap.
4. **Free-expansion bound (3c̄) on the pressure impulse** (shipped, kept): caps
   the worst tail but pump persists (U 100→144/9360f).
5. **Midpoint (KDK) energy eq** (tested, reverted): correction ~4% of du at
   measured kick sizes — no effect. Confirms the pump is not the O(dt²) work
   mismatch.
6. **[CLOSURE] instrument** (W=F·Δx in compute_physics vs booked m·du splits in
   sph_force, 240f windows, int32 ×1e2 fixed point): raw |du| flux ≥1e8 units
   per window vs true ΔU ~1e2 — **u at hot close pairs is a floor↔cap telegraph;
   >99.99% of booked heat is clamp-slam noise**. The pump is its residue. The
   FORCE side W is sane (~1e4) — force clamps (c·dt, brake, 3c̄ bound) work; the
   ENERGY equation is the unresolvable one. This is plan §3.6's CFL warning,
   measured.
7. **Endemic NaN particles**: poison counter (lanes with non-finite du) = 351 to
   50k/window; ÷~864 lanes-per-poisoned-particle ≈ **0.2–0.5 NaN particles per
   frame**, each poisoning up to 864 pair computations. The compute_physics NaN
   respawn path (particles.metal ~2091) catches them AFTER they've poisoned
   neighbours (and teleports them home). NaN guards now stop them writing NaN
   into u/force (shipped, kept).
8. **Exact exponential PdV integration** (u·e^{k·dtU}, stiff-term split — tested,
   reverted): stable and honest per se, but U climbed ~2× FASTER (109→201 vs
   99→125 per 5760f) — the explicit form's cap-overshoot discard was acting as an
   accidental sink for the pumped heat. Not the cure; masking removed ≠ pump fixed.
9. **Shell-neighbour exclusion** (shipped, kept): boundary-shell residents'
   ρ/P/u are never computed (stale/zero) yet were read as neighbours by
   shell-adjacent interior cells — P/ρ² = (γ−1)u/ρ singular. Principled fix
   (nothing couples across the shell) but measured no change to the fountain —
   the bombs are interior.

## The cornered culprit
The bomb population is **contact pairs the merge pass cannot see**:
- SPH couples pairs to 2h = 2 cells; stars physically overlap at r < R_a+R_b
  (MERGE_RSUN_SIM = 0.397, already honest — contact ≈ 0.3–0.6 sim for typical
  masses, more for merged heavies up to 75 M☉ whose mj multiplies every term).
- `merge_stars` pairs particles **within one cell only** (same-cell j-loop).
  A contact pair straddling a cell boundary is INVISIBLE to it — at contact
  radius ~0.3 and cellSize 1, that is roughly half of all contact pairs.
- Such a pair grinds at r ≪ h with c-scale relative speed and up to 250:1 mass
  ratio, every SPH frame, booking |du| of order the whole thermal budget per
  step (unresolvable at fixed dt) and taking maximum-strength (clamped) kicks —
  until one member is ejected. The escaper fountain is these pairs draining.

## Decision brief (Jamal's call)
Ranked options, not exclusive:
1. **Cross-cell merging** — extend merge_stars pairing to the 27-neighbourhood
   (needs an ordering rule to avoid double-eat races). Eats the unresolvable
   pairs at their source; physically mandatory anyway (touching stars ARE one
   star regardless of grid lines). Medium effort, no per-frame cost growth.
2. **Sub-step accumulator** (plan §3.6b, the named debt) — N sub-steps for the
   SPH passes. The fully honest integrator cure; costs ~N× SPH time (13ms → N×)
   against the 100fps gate.
3. Accept + gate — blunt per-pair du budget cap. Cheap, but it is another
   clamp, and clamps are what the books are currently made of.

## Working-tree state (all uncommitted, on top of 9dfca4e)
KEPT: 3c̄ free-expansion pressure bound; shell-neighbour exclusion; NaN guards
(u ledger, force write, closure counters); PE term in [SPH] watchdog; [CLOSURE]
instrument + poison counter (TEMP — remove with the harness).
REVERTED: midpoint du; exact exponential PdV (both documented in-code).
Logs: scratchpad baseline_head/pe_ledger/cadence1/expansion_bound/midpoint/
closure*/shellfix/nanfix/exactpdv/reverted_check.log.
⚠️ One cadence-1 run was contaminated at f3840 by PLAY MODE — the app's mic
heard something. Unattended measurement runs must expect this; check
KEin~1e7/nOut→0 as the signature and discard.
