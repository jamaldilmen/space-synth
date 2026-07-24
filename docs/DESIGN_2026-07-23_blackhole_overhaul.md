# DESIGN — THE BLACK HOLE OVERHAUL (prep, as ordered)
**Written:** 2026-07-23 14:52:00. Status: PREPARATION — nothing built from this yet.
**Jamal's order (14:38):** "prepare everything for the black hole overhaul, cause you're
right it's not just a tweak. but it's the next step."
**Context verdict same message:** zoomed-out field = "basically what we've been fighting
for for 4 months — the colors are there; it's just resolution scaling and details now."

## 0. What HE sees (verbatim inventory, 2026-07-23 14:27–14:38 screenshots)
1. "Stuff on the horizon looks super blurry."
2. "It doesn't flow as one unified body — like a bunch of circles stacked on each other."
   (Zoomed-in shot: 3–5 distinct concentric bright rings around the shadow, gaps between.)
3. "The angles are broken and don't read as one body" (rings at inconsistent orientations).
4. FPS 14–29 at the settled hole; 15 fps zoomed out on the full field.
5. Zoomed out "looks like 144p" — resolution/detail scaling of the sprites.
6. (Color pass, parked with the all-blue tuning): the gas blue "morphs out really weirdly"
   and reads like an overlay that rotates with the camera.

## 1. MEASURED facts to build on (this session + ledger)
- **B-bypass split (his tap, 14:38):** postfx OFF = dimmer, FPS ~unchanged → the COST IS
  IN THE SCENE PASSES + compute, NOT the postfx chain. (Trilinear cuts also measured ~nil.)
- At settled hole (93% in): Compute ~18–20 ms; hole-state render runs the heavy vertex
  pass ×2 (secondary lens instance gated on bhStrength>0.5), + hole occluder pass.
- Settled ring is SPARSE — a thin ring of individual dots (density-gate measured DEAD on
  it, 07-23). Any "make it gaseous" approach keyed to density cannot fire there.
- Kill angular momentum → r_h 0→0.94; rotating = stall/drain (07-19 session2). The wall:
  matter with L parks in rings instead of flowing in — **the stacked circles are the
  angular-momentum wall made visible.**
- Collisionless softened mean-field, ε = cellSize ≈ horizon scale (FULL-CODEBASE MODEL):
  sub-horizon dynamics are UNRESOLVABLE by honest physics at current resolution.
- PLAY-created holes = the reference look (07-19: lensed hole, bent streams, giant ring —
  his 14:50–16:06 shots). Hot injection onto a live hole works; REST-collapse is the
  broken path that makes onion rings.
- TIME IS THE BH VISUAL (07-15, his breakthrough): declared time-compression — posed
  Keplerian playback keyed to the honest hole + trails = the target motion. Exists
  (bhPoseTime/bhDiskGM chain) but inner-spin is INVISIBLE on screen (open since 07-19).
- BH CORE DIRECTIVE (canon): the BH IS the particles. No overlay disks, no billboard,
  no second layer. The 07-19 honest-lens chain (μ₊, double-booking fix, lens-coherent
  streaks, smooth r_h) is KEPT — the overhaul builds on it, not around it.

## 2. Diagnosis — why it looks like stacked circles, not one body
Three stacked causes, in order of leverage:
1. **PHYSICS — the ring is real.** Rest-collapse conserves each shell's angular momentum;
   without an L-transport mechanism strong enough at the centre, matter settles into
   quantized rings at whatever radius its L supports (the drain/toilet war). The render
   faithfully draws rings because rings are what exist. No render fix can hide this
   (density-gate proved it).
2. **POPULATION — 2M samples, ~10⁵ M☉ visible in the disk region** → the ring occupancy
   is a few thousand dots: sparse popcorn. A real disk image is a CONTINUUM (10¹² × more
   emitters than we can simulate). The missing concept: each particle must render as a
   SAMPLE of a continuous annulus (its full orbit), not as a single glowing point.
3. **MOTION — frozen posture.** The settled ring barely moves on screen (slow Ω at
   parked radii + timewarp broken until this session's fix). One body reads as one body
   because it FLOWS; the time-compression directive exists exactly for this and is
   currently invisible.

## 3. THE OVERHAUL — three fronts, each with one-change increments

### FRONT A — the disk must be a continuum (render: particle → orbit-sample)
The physically honest upgrade that fixes "popcorn" AND "circles" in one concept:
a bound particle near the hole represents its whole ORBIT (time-average of a Kepler
ellipse), not a point. Draw disk-region matter as ORBIT ARCS (the existing streak
machinery generalized: arc length ∝ Ω·exposure — inner matter draws long arcs, outer
matter short ones) with luminance conserved along the arc.
- A1. Arc-streak for BOUND disk matter keyed to the time-compression clock (reuse
  velDir2D/STREAK path + bhPoseTime; no new layer, still the particles). Verify: inner
  ring dots fuse into continuous bands; outer stay dots. ONE change: arc gate + length law.
- A2. Kill the "blurry" at the horizon: the current soft/wide splats near r_h (PSF halo +
  bloom at 40px sizes) replace with the arc's thin profile. Verify: crisp thin bands
  like the reference Gargantua look, not cotton.
- A3. Depth-order the arcs vs the shadow (front arcs over, back arcs lensed above/below —
  the fold-over already exists via the secondary instance).

### FRONT B — the disk must flow (physics/clock: one body = one shear field)
- B1. Make the time-compression VISIBLE: drive the render-side Keplerian playback with a
  compression factor that guarantees ≥ perceptible motion at the ISCO (necessary since
  physical Ω at our GM is minutes-slow). Single dial, honest label (declared time-lapse,
  NOT fake forces — 07-15 canon). Verify: his eyes on "does it flow".
- B2. Ring-merger physics (the drain war, resumed deliberately): gentle L-transport at
  small radii only (dynamical-friction analog already exists as the inspiral drag) so the
  parked rings SLOWLY shear into a filled disk instead of discrete annuli. A/B with the
  [BALANCE] probe; full-run soak per the let-it-run-minutes rule.
- B3. The angles: rings at broken orientations = each shell kept its own plane from the
  collapse. Candidate: the same weak transport aligns planes toward the total-L plane
  over minutes (physical: Bardeen-Petterson alignment). Measure per-shell L vector in
  [BALANCE] before coding anything.

### FRONT C — cost + resolution (the 15 fps / "144p" war; scene-side per the B-split)
- C1. Secondary lens instance: radius-cull — only particles within the lens influence
  radius get the second vertex pass (far field never folds over). Biggest single lever
  at hole state (halves the heavy pass for ~95% of particles).
- C2. Zoomed-out 15 fps: 2M vertex shader runs with the full lens/streak/webbing chain
  regardless of zoom. Add a zoom-scaled LOD gate: far-camera + tiny-sprite particles take
  an early cheap path (no webbing partner read, no chord math). No count reduction, no
  resolution downscale (canon: never downscale resolution).
- C3. "144p" sprite quality zoomed out: the 1px star points alias into blocky grid noise.
  Candidate: proper subpixel PSF (Gaussian splat with subpixel center, already
  flux-conserving) instead of the hard 1px min — sharpness without size.
- Verify each front-C increment on the SAME scoreboard: on-screen FPS at (a) settled
  hole, (b) fully zoomed-out rest field.

## 4. Order of work (proposed — HIS call)
C1 (fps, cheap, unblocks testing) → A1 (the continuum look) → B1 (the flow) → then
iterate A2/A3/B2/B3 by his eyes; C2/C3 interleaved when fps blocks judgment.
Each increment: one build, one verdict, ledger updated. No commits without order.

## 5. Explicit NON-goals (canon guards)
- No overlay/billboard/second layer — the BH stays the particles (core directive).
- No resolution downscale for fps.
- No un-declared fake physics: time-compression is a declared clock, forces stay honest.
- The 07-19 lens chain and eigenmode play defaults stay untouched.

## 5b. THE "YELLOW UNDERBELLY" (folded in 2026-07-23 16:45, his call)
A smooth low-res cream-yellow region attached to the hole, view-anchored
("tilts with the camera"). ELIMINATED by his eyes across three builds:
NOT the seed billboard blob (gated off at horizon, still there pre-horizon),
NOT the dust pass (disabled 16:42, still there), NOT the particle gas hue
(mottle didn't touch it). REMAINING PRIME SUSPECT: the LENS chain — μ₊
magnification (×6 clamp) + the bleach re-key blow the near-hole image out,
and overexposure bleaches hue → cream. View-anchored because lens effects
live around the hole's screen position. OWN IT IN FRONT A (the honest-lens
rework): magnification must brighten within the tonemap's headroom, not
bleach a zone flat. Verify by A/B-ing bit8 (lens toggle) at a formed hole.

## 6. Parked in this doc (owned elsewhere)
- Gas-blue tuning: all-blue balance, "overlay" rotation feel, weird morphing (color pass).
- Dust extinction thresholds (design §2b shipped 14:26, verdict pending in the field).
- Timewarp x2/x4/x8 on-screen confirmation (fix committed c511da9, unverified).
- Low-C eye; settle-whiteout iris; fullscreen gamma.
