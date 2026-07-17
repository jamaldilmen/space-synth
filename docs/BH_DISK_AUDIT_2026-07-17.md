# Deep Audit — why it doesn't render as a black-hole + accretion-disk combo
_2026-07-17 21:15:00 — grounded in code + live probes, not theory. Supersedes the
one-line-fix attempts (support 0.95→0.99, warp kill) which the probes proved were
misses on this problem._

## The target (NASA SVS14146 / Gargantua)
A THIN bright disk whose INNER edge sits right at the photon sphere (~1.5–3·r_s),
wrapping a dark shadow of radius 2.6·r_s, with the back of the disk lensed OVER
and UNDER the shadow. The load-bearing fact: **the disk's inner edge and the
shadow are the SAME SCALE, nearly touching.**

## What we render instead
A bright ring far out + a tiny sparse black blob near the middle, disconnected,
no wrap. "Rick and morty eyes / two rings / black blob with fuzz."

## The measured mechanism — 3 symptoms, 1 architectural root

### ROOT: nothing dwells in the accretion region (r ≈ 1–4 sim = the ISCO/photon-sphere scale)
Live BAND probe (rerun/support runs): `r<0.4 : ~410 particles | 0.4–2.0 : EMPTY | r>2 : ~555`.
The radial mass distribution is **bimodal with a hollow gap exactly where the
accretion disk must live.** Cause is the two-component design pulling apart:
- **Nucleus** (F_NUC, support 0.55, sub-circular): plunges from r~3 straight
  through r~1–3 into the hole and is eaten — no dwell time, never populates the
  ISCO region. It just feeds the hole and vanishes.
- **Disk** (F_DISK 0.75, support ~0.95–0.99): rotationally parked at r≈5–6 sim
  (collapsed from R_DISK=18). Viscous inflow is far slower than the run, so it
  never migrates down to the ISCO. This is the visible ring — too far out.
- The gap between them (r~1–4) has no component that both REACHES it and STAYS.
  The bounce (inner core vr=+0.015…+0.019 OUTWARD, measured, persists at 0.99
  support) actively evacuates it.

### Scale numbers (from units.h + the runs)
- `kRsSimPerMsun ≈ 1.6827e-6` → r_s = 1.68e-6 · M_sun.
- Honest horizon r_h ≈ 0.4–1.0 sim (M(<r_h) ≈ 2.4–6e5 M☉). ✔ consistent.
- ISCO = 3·r_s ≈ 1.2–2.0 sim.  Shadow (photon capture) = 2.6·r_s ≈ 1.0–1.7 sim.
- **Disk settles at r≈5–6 sim ≈ 3× the ISCO.** So even a perfect thin disk shows
  as a ring at 3× the shadow radius — a ring around a dot, NOT a disk hugging a
  shadow. This is the geometry, independent of any render polish.

### SYMPTOM 1 — no bright disk near the shadow
The only bright ring is the r≈5–6 disk. The r≈1–4 region where the accretion
disk belongs is empty (ROOT). Nothing to hug the shadow.

### SYMPTOM 2 — the shadow is a tiny sparse black blob
`hole_vertex` (render.metal) draws particles with `r < cam.horizonR` as black
occluder splats. Two problems, both real:
1. **Cull radius = r_h = r_s, but the visible shadow should be 2.6·r_s** (Bardeen
   photon capture). The black region is ~2.6× too small by construction.
2. It's the **sparse splats of whatever particles happen to be inside r_s**, not
   a solid disc. Inside r_s the pile is small (tiny volume) → a few black dots,
   not a filled shadow. That IS the "small black blob / rick-and-morty eye."

### SYMPTOM 3 — no lens wrap
The deflection map (added today) is correct (α table matches published GR:
α(200)=0.0101, α(10)=0.237, α(2.60)=6.81 rad). But it bends light by α(b) where
b = impact parameter. The disk sits at b≈5–6 sim ≫ r_s≈0.5 → α ≈ 2r_s/b ≈ 0.2 rad,
a barely-visible bend. The DRAMATIC wrap needs sources at b ≈ 1–3·r_s (r≈1–3 sim)
— which is empty (ROOT). The lens has nothing at small b to wrap.

## Contributing (secondary) issues found in the audit
- **Two mismatched "black holes."** Gravity has a hardcoded central anchor
  `centerGM = gmSim(4.297e6 M☉)` (renderer.mm:1457, gated bit1) whose r_s would
  be 7.2 sim, while the honest rendered horizon is r_h≈0.5 sim — a ~14× mismatch
  between the mass the stars orbit and the hole we draw. (Bit1 may be off in the
  self-bound default; needs confirming — but the anchor exists and is uploaded.)
- **PM grid extent.** Coarse gravity grid is 128³ over **±3 sim** (cellSize
  ≈0.047; the "cellSize 1.0" comment in particles.metal is stale). The disk at
  r≈5–6 is OUTSIDE the resolved grid — it feels only the far-field monopole, no
  fine structure. Gravity is well-resolved in r<3 (the empty region), so the
  gap is NOT a resolution wall — it's the distribution (ROOT).

## The fork — a DESIGN decision (Jamal's call; not a one-liner)
All three symptoms collapse to: **put bright matter in the r≈1–4 accretion region
and render the shadow at 2.6·r_s as a real disc.** Three honest ways:

**A — Render-scale match (fast, keeps the physics as-is).** Accept the disk lives
at r≈5–6. Draw the shadow at 2.6·r_s as a SOLID disc (not sparse splats), and set
the hole's rendered scale so the shadow's inner edge meets the disk's inner edge
(i.e. the disk at r≈5 becomes the ISCO by render definition). The lens Einstein
radius already keys off the shadow radius, so the wrap follows. Cost: the "honest
r_s from mass" and the "rendered shadow size" become two numbers, decoupled.

**B — Physics: make matter dwell at the ISCO (most honest, hardest).** Give the
nucleus enough angular momentum to CIRCULARIZE at the ISCO instead of plunging
(raise its support so it settles at r≈2 and forms a fed annulus), OR crank
viscosity/L-transport so the r≈5 disk migrates inward and fills r≈1–5 continuously.
Either populates the accretion region for real. Cost: this is the weeks-long
accretion-physics work; needs its own careful loop.

**C — Scale the hole up to the disk (units change).** Grow r_s (raise
kRsSimPerMsun ~3× or the accreted mass) so r_s≈2, ISCO≈6 — then the disk at r≈5–6
naturally sits at the ISCO and hugs the shadow. Cost: trades the physical
mass→r_s anchor (which you've said must stay correct) for the visual.

## Recommendation to put to him (not executed)
A is the fastest path to the reference look and is reversible; B is the "for real"
physics; they're compatible (do A now for the visual, B over time for honesty).
The shadow-render fix (2.6·r_s solid disc instead of r_s sparse splats) is common
to all three and is the single highest-leverage render change.
