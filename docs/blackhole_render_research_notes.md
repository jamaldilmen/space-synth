# Black Hole — render & formation research notes (what we can use)
_Last Updated: 2026-06-28 19:18:00_
_Sources read with Jamal: ScienceClick "Visualizing the formation of a black hole";
Veritasium "What if a star explodes near Earth?"; DNGR (Thorne / Double Negative,
Interstellar) technical dossier + the Interstellar VFX supervisor's own comment._

## 0. THE conclusion (why image #6 still saucers)
Our lensing is a **2D screen-space NDC displacement** of particle positions
(`render.metal` vertex: point-mass lens `θ=½(β+√(β²+4θ_E²))` + secondary `θ₋`,
applied in NDC). It can fake a ring but **cannot bend light "over and under" the
hole** — so primary + secondary images collide in screen space → the saucer/pinch.
DNGR's own engineering verdict for the real look: replace 2D-NDC with either
- a **world-space gravitational-lensing LUT** (map camera ray dir → deflected dir
  through the metric, precomputed once per spin/mass), or
- **per-pixel adaptive RK geodesic integration** of null geodesics (full DNGR).
This is the architectural pivot from "picture of a disc" to "the maths rendered."

## 1. Rendering spec (DNGR / Interstellar — the bible)
- **Metric:** Kerr in Boyer–Lindquist. Geodesics via a **super-Hamiltonian** form
  (robust at turning points). Conserved per ray: energy `p_t=−1`, axial angular
  momentum `b`, and the **Carter constant `q`** — these decide horizon-capture vs
  sky-escape.
- **Ray BUNDLES, not single rays:** integrate a circular bundle that deforms into an
  **ellipse on the sky**; sum light inside the ellipse. This is the anti-aliasing
  that kills our "pebble chain"/grain artifacts. (Sachs optical-scalar deviation.)
- **Integrator:** Runge–Kutta–**Fehlberg, adaptive step** — small near horizon &
  poles (strong curvature), large in flat space `r>15`. → DIRECTLY the same
  adaptive-step idea as [[space_synth_gmat_adaptive_integrator]] (docs/bh_integrator_gmat_notes.md).
- **Effects:** relativistic aberration (Eq A.9); net frequency shift (Doppler×grav)
  `f_c/f' = (√(1−β²)/(1−βN_y))·(1−bω/α)`; disk = blackbody, temperature adjusted by
  the shift → RGB.
- **Artifact fixes:** 5× **micro-supersampling** in a 2–3px vertical strip at the
  spin axis (kills caustic "pebble" artifacts at the poles).
- **Shadow size:** Schwarzschild apparent shadow `b_crit ≈ 5.2M = 2.6·r_s`.
  ✅ **Our pose already uses 2.6·r_s — the shadow scale is correct.**
- **MetalFX:** dossier suggests 3/4 internal res + MetalFX temporal upscaling for
  60fps IMAX. ⚠️ **CONFLICTS with Jamal's hard rule "never downscale resolution"
  ([[feedback_never_downscale_resolution]]).** Use native res; get perf from the
  LUT (precompute) + adaptive step instead. Do NOT adopt the 3/4-res suggestion.

## 2. Disk appearance — the artistic choice (VFX supervisor, first-hand)
- Gargantua = **200M M☉, spin 0.75c** (paper said 0.6; supervisor says 0.75). Spin
  reduced from 0.9999 → 0.75 for the **classic round shadow** (aesthetic).
- The film's disk is **old, thin, stable, "anaemic"** — temperature ≈ the **surface
  of our Sun (~5800K, yellow-white)**, NOT hot. Doppler beaming **omitted by choice**
  (not Nolan's request) to avoid the lopsided look.
- BUT the supervisor explicitly praised **"hot blue accretion disc"** renders.
  → DECISION for us (Jamal's call): realistic-anaemic ~5800K yellow-white, or
  dramatic hot-blue. Our blackbody path does both — it's one temperature scale.
- **Gravitational redshift:** near `r_in` the disk light is stretched → dimmer +
  redder. We currently color by mass only; add a `√(1−r_s/r)` redshift on disk
  color/brightness for honesty (ScienceClick: "the star reddens" near the horizon).

## 3. Formation / transition model (for starmap → supernova → BH, LATER)
ScienceClick (Oppenheimer–Snyder 1939):
- Homogeneous **pressureless ball collapses in freefall** → singularity.
- The **horizon forms at the CENTER first**, before the surface arrives, then grows
  outward — "the horizon is made of trapped light-ray trajectories."
- What you SEE collapsing: image **unfolds (reveals poles, then the rear)** →
  surface falls at increasing fraction of c → **reddens** (Doppler+grav) → **slows
  and freezes** → only a sliver of light → fades to the **shadow**. ~1 ms real.
- **Accretion/frozen images:** infalling matter appears to **freeze and darken on
  the shadow**, growing it. "Nothing ever crosses the horizon, seen from outside —
  everything is frozen on the shadow." → our capture visual = freeze + redden onto
  the shadow, shadow grows with captured mass.

Veritasium (the numbers for the lifecycle/supernova trigger):
- Supernova needs **≥8 M☉**; range **8–30 M☉**; **≥20 M☉ → black hole**;
  **≥30 M☉ → hypernova/GRB**.
- Fusion ladder + timescales (could drive star color/temp ladder): H→He = 90% of
  life; He→C at 200M K; C→Ne ~1000 yr; Ne→O; O→Si months; Si→Ni→Fe at 2.5B K.
- Iron core hits **Chandrasekhar 1.4 M☉** → collapses at **25% c**; 3000 km iron
  ball → **30 km neutron star** in milliseconds.
- Energy budget: **99% neutrinos, ~1% kinetic, 0.01% light.** (Our supernova is the
  emission-line spectrum already — see render.metal supernovaRamp.)
- These give honest thresholds/timescales for the eventual emergent transition.

## 4. What already matches our engine (don't rebuild)
- Shadow = 2.6·r_s ✅ (units.h anchor, pose uses it).
- Disk inner edge ISCO = 3·r_s ✅ (pose r_in=3.0).
- Real Keplerian Ω(r)=√(GM/r³) spin + relativistic √(1−r_s/r) dilation ✅ (just
  added to the posed disk; numbers in docs / this session).
- Adaptive-step integrator plan ✅ ([[space_synth_gmat_adaptive_integrator]]) — the
  SAME RK-Fehlberg adaptive idea DNGR uses; reuse it for the geodesic LUT.

## 5. Recommended next architecture step (the real fix)
Build a **world-space gravitational-lensing LUT** (or per-pixel RK geodesic) so light
bends over/under the hole for real, retiring the 2D-NDC displacement. Precompute the
deflection map once for the chosen mass/spin (cheap at runtime) → native-res, 60fps,
no downscaling. Start Schwarzschild (spin 0), add Kerr/Carter-q after it reads right.
This replaces the saucer artifact with true wrap. Disk stays the posed particle
source; the LUT does the bending.
