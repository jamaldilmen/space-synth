# HANDOFF — 2026-07-25 — Metric ray-march hole + clean time-lapse; the UNSOLVED "stars, not trails" physics problem

**Written:** 2026-07-25 20:24:10. Branch: `session-2026-06-30-honest-spacetime-friction`.
**Verdict at handoff (Jamal):** "it looks sooooo bad… nothing near the black hole reads as
trails, it all reads as stars… we got a major physics problem hidden somewhere and I'm
done chasing it here." → This doc + a fresh window.

---

## 0. THE ONE PROBLEM THAT MATTERS (read this first)

**Near-hole matter renders as a ring of DISCRETE STARS (dots), never as the fast gaseous
TRAILS we want (like the sharp lines a Chladni note makes).** Everything else this session
(ray-march hole, colour, shadow, time-lapse) is downstream cosmetics. The disk is a
**quantized ring of slow discrete particles**, not a fast continuous accretion flow. Two
photos at handoff: an inclined pink/orange **ring of dots** with a dark centre + a tiny
orange arc (the ray-march). It reads as a static dotted torus, not flowing matter.

### The chain of evidence (grounded, this session)
1. The Chladni patterns make sharp fast lines because matter moves at **CHLADNI_VCAP = 1.2
   sim/frame** (`particles.metal:227`) under the standing-wave sculpt.
2. The BH orbital matter moves at **v_circ·dt ≈ 0.04–0.07 sim/frame** at the inner disk —
   ~16–30× slower per frame. A trail is just a sprite moving far enough per frame to smear;
   at this speed each sprite barely moves → renders as a **dot**.
3. The real orbital period at our mass/scale is **~38 wall-seconds per ISCO orbit**
   (`tIsco = kIscoPeriodPerGM · gmSim(M)`, computed live). That is the honest physics and it
   is *slow*.
4. The matter also **parks in quantized angular-momentum rings** (the "L-wall" — see memory
   `space_synth_angular_momentum_is_the_wall_2026-07-19`). Rest-collapse conserves each
   shell's L, so matter settles into discrete rings instead of a continuous inflowing disk.
   **This is very likely the hidden physics problem**: there is no real accretion *flow*,
   just concentric parked rings of near-static particles.

### Why every speed fix failed (all tried today, all real dead-ends)
- **Scale dt up (time-warp ×64):** detonates. Big dt overshoots the integrator's stability
  limit → the field explodes into a neutron-star spray (v→0.33c, COLLAPSE 0%). Gorgeous, but
  it's the blow-up, not motion.
- **Full-kernel substeps (N× compute_physics):** stable + correct, but ~N× FPS and N× drain.
  Unusable past N≈2–4.
- **Cheap light substep (central gravity only, N-1×):** EXPLODES. Strips the field's
  self-gravity/pressure/boundary balance, so matter flies off its constrained paths. The
  balance is what holds the cluster together; you can't cheaply substep only part of it.
- **Analytic render playback (the "fake" spin):** cheap + fast but (a) jittered (wall-clock
  dt × ~10 compression amplified framerate jitter) and (b) the ray-march sampled the SLOW
  physics field while sprites showed the FAST playback → "a low-res copy of something slower,
  sped up weirdly" (Jamal's exact, correct diagnosis).

### The likely real fix (NOT attempted — for the fresh window)
The physics needs to *produce a genuine fast accretion disk* — a thin annulus of matter on
fast near-circular orbits with real inflow — instead of a slow quantized ring cluster. That
means confronting the **L-wall** (angular-momentum transport / viscous inflow so matter
spirals in and orbits fast) and/or **re-scaling the unit system** so the disk's orbital
speed lands in the same visual regime as the Chladni sculpt (Jamal explicitly OK'd this:
"if we have to scale Chladni & supernovas down to match the black hole science, so be it —
the intensity should be the same"). The trails he wants = matter genuinely moving fast, one
consistent speed/intensity across the whole engine. **Do not chase this with more render
tricks; it is a physics/units problem.**

---

## 1. WHAT SHIPPED THIS SESSION (the good groundwork)

All on branch `session-2026-06-30-honest-spacetime-friction`, committed at handoff.

### A. Metric-native ray-march black hole — DRAWN and working (bit19)
- `bhmarch_fragment` (`render.metal`) now integrates the null geodesic backward through the
  honest metric and **ADDS emission sampled from the REAL particle field** (CIC hash grid)
  along each ray. Additive blend → no black paint, no overlay regression.
- Consequences fall out of the geodesics: dark **shadow** (captured rays stop gathering),
  the disk's far side bends over the top, a warm ring. Verified on screen: a real dark hole
  with a bright ring, "that's a real black hole now" — the ORANGE-YOLK → real-hole arc.
- Encoded in the scene pass (`renderer.mm`, after particles), additive pipeline, per-frame
  `BHMarchUniforms` (inverseViewProj + params), buffers: cam(0) march(1) cellCounts(2) su(3).
- `applyInverseSpin` added to map ray points (spun-world) back to physics coords for the grid.
- **Live dials** (all in the BH mod menu):
  - **BH emission (log10 gain)** `uiRayEmitLog`, default **−7.5** (−6 was a solid orange
    "yolk"; the bCull box fills bright → lower until structure appears).
  - **BH extent (b/r_s)** `uiRayBcull`, default **16** — the impact-parameter cull. 2.6 (the
    old shadow-only value) discarded EVERY disk ray → the filled core bug; 16 renders the disk.
  - **BH shadow radius (r_s)** `uiRayInnerR`, default **2.6** — inner no-emit radius → dark
    centre. Raise toward 3 (ISCO) for a bigger hole; 0 fills the core.
  - Cost knobs (in `renderer.mm`): `rMarchStart=60`, `stepScale=0.05` (was 0.03; coarsened
    for FPS), `maxSteps=256` (was 512). The ray-march is the main FPS cost (~10 fps).
- **"orange box/cube"** = the emission filling the bCull march region; lower emission or extent.

### B. Clean time-lapse (bit20 "Time-lapse orbit playback", default ON)
Replaced the jittery render-clock with a coherent one. Three coupled changes:
1. **Fixed-rate clock** (`renderer.mm`, both main + Syphon emergent branches): the pose clock
   now advances by a **FIXED 1/60 per frame** (× the ISCO compression), NOT the wall-clock
   delta. Kills the jitter (which was wall-delta × ~10 amplifying framerate swings). Speed is
   now tied to frame COUNT (steady, but fps-dependent in real-time).
2. **Orbit playback re-enabled** (`render.metal:355`, gated by bit20): sprites swept at the
   real Keplerian Ω(r)=√(GM/r³)·tdil about the hole. This was the old "analytic spin"; the
   fake part was only the jitter + the sampling mismatch, both now fixed.
3. **Coherent ray-march sampling** (`render.metal` bhmarch sample block): before the hash
   lookup, the ray back-rotates `pp.xy` about the hole by the SAME Ω·tdil·bhPoseTime, so the
   emission rotates WITH the sprites instead of lagging at the slow physics rate.
- **Dial:** "ISCO orbit (screen seconds)" `uiIscoSeconds`, default **1.0** (was 3.8; lower =
  faster). LOWER = faster sweep. Still not fast enough to trail (see §0).
- **STILL FLAT face-on** — sprites rotate in x–y about z (the disk plane). Under the ortho
  camera it reads as a flat spinning disk; the 3D lensed read needs the camera tilted
  (Option+←/→). Geometric disk-tilt was tried and is INVISIBLE under ortho (only a squish).

### C. Physics substep dial (bit-less, `uiPhysicsSubsteps`, default 1)
- "Physics substeps (fast, stable)" 1..32 → N× the FULL physics per frame. STABLE but ~N×
  FPS + N× drain. The cheap light-kernel version (`orbit_substep` in `particles.metal`, still
  compiled but **NOT dispatched** — reverted) EXPLODED. Keep N small or leave at 1.

### D. Default changes baked this session
- `uiTogAccretionGas` (bit17) → **DEFAULT OFF** (it was the blur: size×3, lum/9, soft falloff).
- `uiIscoSeconds` → **1.0** (faster).
- `uiTogAnalyticSpin` (bit20) → **DEFAULT ON** (now the clean time-lapse).
- `uiRayEmitLog` → **−7.5**. `uiTogRayMarch` (bit19) ON. `uiTogFluidStreak` (bit18) ON.

### E. Also this session (pre-existing, verified)
- Two DNGR-doc errors fixed earlier (factor-of-2 `775e103`, g double-count `2dc9f55`).
- Spectral starmap increments 1–4 (`0f6a091`).
- `spacetime.h`: `kIscoPeriodPerGM = 92.34358777165421` (2π·6^1.5).

---

## 2. TOGGLE / BIT MAP (bhToggles bitmask, `main.cpp` ~line 1995)
- bit15 `uiTogMetricShadow` — metric shadow=absence (ON)
- bit16 `uiTogSpectralColour` — Planck-band colour (ON)
- bit17 `uiTogAccretionGas` — near-hole softening (**now OFF** — the blur)
- bit18 `uiTogFluidStreak` — flux-conserving streak arc (ON)
- bit19 `uiTogRayMarch` — metric ray-march emission (ON)
- bit20 `uiTogAnalyticSpin` — time-lapse orbit playback (**now ON** — clean)

---

## 3. FILES TOUCHED
- `src/render/render.metal` — bhmarch emission fragment (+coherent sampling, +emitInnerR,
  +bCull dial), `applyInverseSpin`, bit20 gate on the playback blocks (355/395).
- `src/render/renderer.mm` — ray-march pipeline (additive) + per-frame uniforms + encode;
  fixed-rate time-lapse clock (both branches); physics substep loop (full-kernel, stable);
  `orbitSubstepPipeline` created (unused). BHMarchUniforms struct (88 B).
- `src/render/renderer.h` — RenderConfig: `bhRayEmitScale/Bcull/InnerR`, `physicsSubsteps`.
- `src/core/app_state.h` — new ui fields + default flips (see §1D).
- `src/main.cpp` — bit19/bit20 packing, 3 ray-march dials, substep slider, time-lapse toggle.
- `src/render/particles.metal` — `orbit_substep` light kernel (compiled, NOT dispatched).
- `src/spacetime/spacetime.h` — kIscoPeriodPerGM.

## 4. UNPUSHED COMMITS
`origin` is at `a041600`. Local ahead by: `2dc9f55`, `0f6a091`, + this session's commit.
Push when ready.

## 5. FIRST MOVES FOR THE FRESH WINDOW
1. **Confirm the L-wall diagnosis.** Add a probe: for near-hole matter, print the
   distribution of orbital radius + tangential speed. Is it discrete rings (L-wall) or a
   continuous disk? The `[BALANCE]` probe in `main.cpp` already prints per-shell L/vcirc.
2. **Decide the fix class:** (a) real angular-momentum transport / viscous inflow so matter
   spirals in and forms a fast continuous disk, or (b) re-scale the unit system so orbital
   speed matches the Chladni visual regime (Jamal OK'd scaling everything to one intensity).
3. **Only then** revisit the render (trails will follow real fast motion for free).
4. Read memory: `space_synth_angular_momentum_is_the_wall_2026-07-19`,
   `space_synth_shadow_is_absence_2026-07-24`, `space_synth_full_codebase_model`.
