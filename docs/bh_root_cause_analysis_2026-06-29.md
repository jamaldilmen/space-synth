# Black Hole — Root-Cause Analysis (4-agent deep review)
_2026-06-29 03:00:00 · branch STARS · synthesis of 4 parallel audits: physics-engine code, formation-science (NASA/arXiv), units/scale, renderer._

## TL;DR — why there is no black hole
The BH cannot form for **architectural** reasons, not tunable ones. Three root hindrances, all confirmed independently by multiple agents:

1. **The gravity is a collisionless, softened MEAN-FIELD → it physically cannot collapse.**
   Every particle feels the *smoothed* cell-centroid potential with Plummer softening ε = cellSize = 1.0 sim (`particles.metal:878-932,896`; grid `halfExtent=64, cellSize=1.0` `renderer.mm:1107-1114`). No star ever feels another star, so the source term for **two-body relaxation / gravothermal core collapse / dynamical friction / mass segregation is erased by construction.** A collisionless system phase-mixes to virial equilibrium and **stays there forever** — exactly the observed "binds but won't collapse." Core collapse is a *collisional* instability this representation does not contain. **This is the keystone.**

2. **Resolution clash: the softening length = the horizon scale.** ε = 1.0 sim *equals* the full-field r_s (1.0 sim) and is 6–60× larger than any realistic accreted-core r_s (10⁴ M☉→0.017 sim, 10⁵→0.17 sim). Below ~1 sim the softened force flattens to a linear spring (a∝r) → there is no concentrating gravity, collapse **stalls one cell short of every horizon**, and the geometric test is checked at R_enc=0.5 sim *inside* the dead zone. The horizon is **sub-cell → cannot form or be resolved/rendered.** The code admits this verbatim (`particles.metal:890-893`). Compounding: the merge contact radius (≈0.11 sim, `:141,:2107`) is **9× smaller than the gravity softening (1.0 sim)** and `merge_stars` only samples 32 stars/cell (`:2066`) → mass growth can't trigger even if matter piled up. Re-scaling units does NOT help (the cluster/r_s ratio is physical); this needs a **resolution change** (near-core AMR / collapse-time grid contraction so cellSize ≪ r_s).

3. **The whole formation/assembly chain is crutches that decouple from real collapse.**
   - **External fixed 4.3e6 M☉ central SMBH** (`renderer.mm:1050`, default ON) is a frozen analytic point mass **7.2× the entire field**, dominating the dynamics (stable Kepler orbits forever), NOT counted in the formation metric, and violating the project's own conservation anchor ("field mass = BH mass", `units.h:6-19`). The field's own self-gravity is a ~14% perturbation on orbits around an indestructible external mass.
   - **Seed engine is a non-runaway scaffold:** seeds are only born from IMF-tail stars ≥50 M☉ at spawn; **no star can grow INTO a seed** (`merge_stars:2080` skips ≥50); mass fragments across hundreds of competitors (logged seeds=866 > 256-slot cap); they rarely meet (cluster doesn't contract); **`seed_feed` is dead code, never dispatched**; seeds starve at static equilibrium density.
   - **The just-added adaptive sub-step actively PREVENTS collapse:** it converts cold radial infall into stable symplectic orbits (`particles.metal:946-988`). That is *why* it binds (meanR~47) — it cures the ejection symptom by removing the collapse. Real win for stability, but it holds the cluster OUT of collapse.

Bonus (not physics): **COLLAPSE % > 100% is a metric bug** — numerator = real star masses, denominator = field mass × `massScale=(Size/2)^1.25` (`renderer.mm:1042`); Size slider <2 shrinks only the denominator (189044/594276=0.318 → Size≈0.80 → ~310%). No mass created. The documented stale-id merge mass-creation bug is separately fenced (`merge_stars:2158`).

## The fix (formation) — ranked, from the science agent (sourced)
The sim is nearly star-by-star (594k M☉ / 0.3 mean ≈ 2e6 ≈ particle count), so the physical relaxation is *there* at this N — only the softening kills it. Add back, in order; each is local, cheap, real, no scripting:

- **RANK 1 — Chandrasekhar dynamical friction (the keystone fix).** Per particle, using grid ρ(r), σ(r):
  `a_df = −4πG²ρ lnΛ · m · [erf(X) − (2X/√π)e^(−X²)] / v³ · v`, `X=|v|/(√2σ)`, `lnΛ=ln(0.4N)≈13.6`. Reinstates 2-body relaxation → mass segregation → gravothermal core collapse, with the correct ∝1/v² drag and ∝m sinking. **This alone breaks the stalemate** (vs the failed uniform drag, which only creeps to terminal velocity). A constant f_relax multiplier to recover the real-N relaxation rate / compress time is a unit/time choice, not a cheat.
- **RANK 2 — radius-driven merging w/ conservation** (US2 task #4): real per-particle radius (R∝M^0.8 stars, M^(1/3) compact; seed sink = max(r_t, 4GM/c²), r_t=R_*(M_seed/m_*)^(1/3)). Cross-section ∝ M^(2/3) → accelerating, self-feeding accretion (Portegies Zwart channel). Needs adaptive sub-stepping (US2 #5) for the fast core orbits.
- **RANK 3 — geometric pop:** fire when `2GM(<R)/c² ≥ R` on the densest core → sink of radius r_s. Needs near-core resolution (H2).
- **Remove the external SMBH crutch** so the field's own mass is the only gravity (conservation-honest).

Real numbers: relaxation t_rh≈390 Myr, but with a mass spectrum core-collapse is **≈0.2 t_rh ≈ 80 Myr** → use time-warp. Free-fall of the cluster ≈150–210 sim-s (≈2–3 s at 64×) — **timescale is NOT the blocker; the stall is.** Runaway seed ≈0.1% of cluster (~600 M☉). r_s(594k M☉)=1.754e6 km = 2.52 R☉; honest "particles ARE a BH" when M_enc≥297k M☉ inside 0.5 sim. Sources: Cohn 1980 (15.7 t_rh), Portegies Zwart 2004 (Nature, runaway→IMBH), Chandrasekhar 1943, Spitzer 1987, Binney & Tremaine.

## The fix (render) — what's wrong with how particles look
Render is particles-only (good; both fullscreen BH shaders deleted). Defects, ranked:
1. **Gravitational redshift computed then DISCARDED** (`render.metal:540-541`, never applied to `kelvin` at :587). View-independent — should redden/dim the inner core. **Dead code, re-enable.**
2. **Doppler colour shift computed then DISCARDED** (`render.metal:517`, only beaming survives). Approaching-side-blue cue missing. Re-enable, scaled by orbital speed (not field-wide).
3. **Shakura-Sunyaev radial disk gradient is dead code** (`ssDiskTempShape` defined `:165` never called); `diskK=5772·M^0.55` colours by mass not radius → no hot-inner→cool-outer signature.
4. **Mass→size is sub-linear & inconsistent → growth INVISIBLE** (this is the user's "no visible mass gain"): rest path R∝M^0.8 (correct), but play/seed path has an extra sqrt → M^0.4 (`render.metal:471,752`), and merges happen during play. Mass DOES grow in physics — the **render hides it.** Fix: unify to linear M^0.8 everywhere.
5. **Bloom re-blows the core to white** after the careful hue-preserving tonemap (`postfx.metal:227-231` adds un-tonemapped glow). Fix: build bloom from the tonemapped buffer / knee-clamp.
6. **Lensing is 2D-NDC → the "saucer"; cannot bend over/under** (`render.metal:340-392`). The photon ring + over/under wrap genuinely need a **world-space geodesic deflection LUT** — still particles-only (place each particle's sprite + its true secondary image where curved spacetime puts its light), NOT a fullscreen pass. Only multi-order rings of *background/occluded* light are the true per-particle floor.
7. Time-dilation uses wrong radius (0.57 not r_s=1.0; 3 inconsistent forms); streak hard-codes 120fps; spin is decorative time-lapse.

**Achievable per-particle today** (mostly dead code to re-enable): dark shadow (cull sightlines inside b_crit=2.6 r_s), beaming asymmetry, redshift, Doppler colour, radial disk gradient, visible mass→size. **Need the geodesic LUT:** photon ring + over/under wrap.

## What this means for the rebuild
Tuning ε / kColdFactor / merge radius / drag CANNOT escape any of this (proven tonight across many values). The honest path is a real **N-body-lite engine**: dynamical friction (reinstate relaxation) + radius-driven merging + near-core resolution + geometric pop, with the external SMBH removed — plus re-enabling the dead render science and adding the geodesic deflection LUT for the wrap/ring. The current adaptive-sub-step *binding* (committed `32be9a3`) is the correct stable base to build dynamical friction on top of.

## Agent evidence files (full reports in this session's transcript)
physics-engine audit (H1-H6, file:line) · formation-science (equations/sources) · units/scale (arithmetic, resolution paradox) · renderer (10 findings + per-particle-vs-transport limit).
