# Black Hole Spacetime — State of the Art & Implementable Model

**What:** Current (July 2026) scientific understanding of what a black hole does to spacetime — the metric, the key radii, the accretion disk, what the Event Horizon Telescope actually imaged, the effect on light and time — translated into a concrete, real-time, particle-based simulation model for SPACE SYNTH TUBE.

**When:** 2026-07-24 (research pass). Sim conventions assumed: geometric units in physics (G = c = 1), engine field units r_s(field) = 1.0, r_s(mass) = 2·gmSim(M), ~2M particles on Metal GPU deposited to a CIC spatial-hash density grid, emergent horizon from enclosed mass M(<r).

**Primary sources (URLs):**
- EHT M87* 2019 (mass/shadow): First M87 EHT Results VI — https://arxiv.org/pdf/1906.11243 ; astrobites summary https://astrobites.org/2019/04/11/the-first-image-of-a-black-hole/
- EHT M87* one year later (persistent shadow): https://eventhorizontelescope.org/M87-one-year-later-proof-of-a-persistent-black-hole-shadow
- EHT Sgr A* 2022 (shadow, imaging): ApJL 930 L12 https://ui.adsabs.harvard.edu/abs/2022ApJ...930L..12E/abstract ; L14 https://ui.adsabs.harvard.edu/abs/2022ApJ...930L..14E/abstract ; arXiv https://arxiv.org/pdf/2311.08680
- EHT M87* polarization / MAD fields: https://scitechdaily.com/astronomers-polarized-image-shows-magnetic-fields-at-the-edge-of-m87s-black-hole/ ; Circular polarization (Paper IX) https://arxiv.org/pdf/2311.10976
- Photon ring subrings (n=1, n=2): "Universal interferometric signatures of a black hole's photon ring," Science Advances https://www.science.org/doi/10.1126/sciadv.aaz1310 ; BHEX n=1 inference https://arxiv.org/pdf/2411.01060
- Shadow size vs spin (weak dependence): "Spins of SMBHs M87*/SgrA* from dark-spot size" https://arxiv.org/pdf/2307.14714 ; Kerr shadow with astrometric observables https://arxiv.org/pdf/2001.05175
- Shakura–Sunyaev disk (T ∝ r^-3/4): "Accretion Disc Theory since Shakura & Sunyaev" https://arxiv.org/pdf/1201.2060 ; lecture notes https://arxiv.org/pdf/2201.07262
- Relativistic beaming / g-factor: Müller & Camenzind, "Relativistic emission lines from accreting black holes" https://arxiv.org/pdf/astro-ph/0309832
- Latest M87* spin/accretion (2025) and ring-asymmetry spin (2026): https://arxiv.org/pdf/2505.17035 ; "Ring Asymmetry and Spin in M87*" https://arxiv.org/pdf/2601.00394
- GRMHD polarization signatures (2026): https://arxiv.org/pdf/2605.15166
- Formula reference: Fabio Pacucci Black Hole Calculator https://www.fabiopacucci.com/resources/black-hole-calculator/formulas-black-hole-calculator/

Units note: below, "M" in a formula means the geometric mass GM/c². In those units r_s = 2M. Numeric radii are given both as multiples of M and of r_s.

---

## 1. The metric is the fundamental object

A black hole is not a "thing" sitting in space that pulls — it *is* a shape of spacetime. Everything (orbits, the shadow, redshift, time dilation) is read off the metric. Two matter.

### 1.1 Schwarzschild (non-spinning, the minimal correct model)

Line element in Schwarzschild coordinates (G = c = 1):

```
ds² = −(1 − r_s/r) dt²  +  (1 − r_s/r)⁻¹ dr²  +  r²(dθ² + sin²θ dφ²)
```

with r_s = 2M the Schwarzschild radius. Physical meaning of each piece:

- **g_tt = −(1 − r_s/r)** — the *time* term. As r → r_s it → 0: clocks freeze relative to a distant observer. This is gravitational time dilation (Section 6). It is the term that makes matter *appear* to slow and pile up at the horizon.
- **g_rr = (1 − r_s/r)⁻¹** — the *radial space* term. It diverges at r_s: radial proper distance is stretched. This is the spatial curvature — a radial ruler near the hole is longer than flat-space Δr suggests. (It's a coordinate divergence, not a physical singularity; the horizon is smooth for an infalling frame.)
- **r²(dθ² + sin²θ dφ²)** — ordinary angular part; the area of a sphere at radius r is still 4πr² (r is the *areal* radius).

The horizon at r = r_s is where g_tt flips sign: the r-direction becomes timelike, so "falling in" becomes as inevitable as "going forward in time."

### 1.2 Kerr (spinning — what real astrophysical black holes are)

Boyer–Lindquist coordinates, spin parameter a = J/M (0 ≤ a ≤ M):

```
ds² = −(1 − r_s r / Σ) dt²  −  (2 r_s r a sin²θ / Σ) dt dφ
      +  (Σ/Δ) dr²  +  Σ dθ²
      +  ( r² + a² + r_s r a² sin²θ / Σ ) sin²θ dφ²

with   Σ = r² + a² cos²θ,   Δ = r² − r_s r + a²   (= r² − 2Mr + a²)
```

New physics relative to Schwarzschild:

- **The cross term g_tφ dt dφ** — this is *frame dragging* (the Lense–Thirring effect). Spacetime itself is twisted around the spin axis; a particle with zero angular momentum still gets swept into co-rotation. There is no static (non-rotating) observer possible inside the ergosphere.
- **Two horizons** from Δ = 0: r± = M ± √(M² − a²). Outer horizon r+ is *the* event horizon. For a = M (extremal), r+ = M = r_s/2 (the horizon shrinks with spin).
- **The ergosphere** — the surface where g_tt = 0, i.e. r_ergo(θ) = M + √(M² − a²cos²θ). It lies *outside* the horizon (touching it at the poles, bulging to r = 2M = r_s at the equator). Between the ergosphere and horizon, everything must co-rotate; energy can be extracted (Penrose / Blandford–Znajek — the mechanism EHT invokes for M87's jet).

**Modeling takeaway:** Schwarzschild captures ~90% of the *look* (shadow, ring, disk, redshift). Kerr adds (a) a spin axis, (b) frame dragging that makes the approaching side brighter/asymmetric beyond pure Doppler, (c) a spin-dependent inner disk edge (ISCO). The **shadow size is famously almost spin-independent** (Section 2), so for a real-time renderer Kerr's main visible payoff is *asymmetry and inner-edge radius*, not shadow shape.

---

## 2. Key radii — why the image looks the way it does

For Schwarzschild (a = 0), in units of M and of r_s = 2M:

| Feature | Radius | in r_s | What it is / why it matters for the IMAGE |
|---|---|---|---|
| Event horizon | 2M | 1.0 r_s | Point of no return; nothing inside emits outward. |
| Photon sphere | 3M | 1.5 r_s | Radius of the unstable circular *light* orbit. Photons here can loop the hole. Source of the bright photon ring. |
| ISCO | 6M | 3.0 r_s | Innermost Stable Circular Orbit — inner edge of the thin disk. Inside it, matter plunges. Sets the disk's bright inner rim. |
| Shadow (photon capture) radius | b_c = 3√3 M ≈ 5.196M | ≈ 2.598 r_s | The critical impact parameter. Any light aimed inside b_c is captured → the dark disk on the sky. |
| Shadow *diameter* on sky | 2b_c = 6√3 M ≈ 10.39M | ≈ 5.196 r_s | What EHT measures as the dark central region. |

**Critical, often-confused point (get this right in the render):** The dark "shadow" the observer sees is **larger** than the event horizon and even larger than the photon sphere. Gravitational lensing magnifies the horizon: the shadow angular radius is set by the **photon capture radius b_c = 3√3 M ≈ 2.6 r_s**, i.e. shadow radius ≈ 2.6× the horizon radius. The bright ring the eye reads as "the edge" sits at b_c (the lensed photon sphere), while the horizon itself is buried well inside. So the proportion to bake in:

- Shadow radius on sky ≈ **2.6 r_s** (photon capture).
- Bright photon ring peaks at essentially the same radius (the photon sphere lensed out to ~b_c).
- Thin-disk inner bright edge (ISCO) at **3 r_s** projects to just *outside* the ring; the disk brightness then falls off outward as T(r) drops (Section 3).

**Kerr / spin dependence.** Two effects diverge with spin:

- **Shadow size:** nearly spin-invariant. A "coincidental cancellation of frame-dragging and the quadrupole" keeps the shadow *radius* ≈ 2.6 r_s for all a; spin mainly **displaces** the shadow off-center and slightly **flattens (D-shapes)** one side for high a viewed near the equator (https://arxiv.org/pdf/2001.05175, https://arxiv.org/pdf/2307.14714). This is why EHT cannot read spin from shadow size alone.
- **ISCO (inner disk edge) is strongly spin-dependent** — the visible one. Bardeen–Press–Teukolsky:

```
r_isco = M { 3 + Z₂ ∓ √[(3 − Z₁)(3 + Z₁ + 2Z₂)] }
  Z₁ = 1 + (1 − a*²)^{1/3} [ (1+a*)^{1/3} + (1−a*)^{1/3} ]
  Z₂ = √(3 a*² + Z₁²),        a* = a/M
```

Sign: − for prograde (co-rotating), + for retrograde. Limits: a*=0 → 6M (3 r_s); a*=+1 prograde → 1M (0.5 r_s, disk reaches nearly to the horizon → hotter, brighter, more redshifted inner edge); a*=−1 retrograde → 9M. **So spin's main image signature is how close the bright disk creeps toward the hole.**

---

## 3. Accretion disk physics — the emitting matter

The luminous part of the image is the disk, not the hole. Standard model: **Shakura–Sunyaev (1973) geometrically-thin, optically-thick disk** (https://arxiv.org/pdf/1201.2060, https://arxiv.org/pdf/2201.07262).

### 3.1 Orbital (Keplerian) velocity — differential rotation

Matter on near-circular orbits (Newtonian form, excellent outside a few r_s):

```
v(r) = √(GM/r) = √(M/r)   (G=1)       [orbital speed]
Ω(r) = √(GM/r³) = √(M/r³)             [angular velocity]
```

This is **differential rotation**: the inner disk orbits *fast*, the outer disk *slow* (v ∝ r^-1/2). Shear between annuli is what viscously heats the disk. At ISCO (6M) the speed is v = √(1/6) c ≈ 0.41c — relativistic, hence strong Doppler beaming (Section 5). Relativistic correction near the hole: v_φ = √(M/r)·(1 − 3M/r)^{-1/2} rises further, formally diverging at the photon sphere.

### 3.2 Temperature profile — why the inside is bluest

Balancing locally released gravitational energy against blackbody radiation gives the effective temperature:

```
T_eff(r) = [ 3 G M Ṁ / (8 π σ_SB r³) · ( 1 − √(r_in/r) ) ]^{1/4}
```

with Ṁ the accretion rate, σ_SB the Stefan–Boltzmann constant, r_in the inner edge (≈ ISCO). Key consequences:

- **Far from the inner edge (r ≫ r_in): T(r) ∝ r^{-3/4}.** This is the canonical profile — inner disk hot, outer disk cool.
- The bracket `(1 − √(r_in/r))` forces T → 0 exactly at r_in (zero-torque inner boundary), so T actually **peaks slightly outside r_in** (at r ≈ (49/36) r_in ≈ 1.36 r_in), then falls as r^-3/4.
- **Hot → blue, cool → red** via blackbody: the inner annulus is the hottest and bluest; the bright rim sits just outside ISCO and reddens outward. For SMBHs (M87*, Sgr A*) peak T is only ~10⁴–10⁵ K (peaks in UV/optical for the disk, but the *imaged* mm emission is synchrotron from a hot, magnetized, near-horizon flow — a RIAF/MAD, not a classic thin disk). For a stellar-mass hole the same profile peaks in soft X-ray.

**Rendering takeaway:** color = f(T(r)) with T ∝ r^-3/4 rolled off to zero at the inner edge. That single scaling reproduces the "white-hot inner ring bleeding to orange/red outer disk" everyone recognizes. Do NOT paint a uniform color disk.

---

## 4. What EHT actually showed (2019 → 2026)

- **M87* (2019).** Bright asymmetric ring, angular diameter **42 ± 3 μas**, central brightness depressed by **> 10×** (the shadow). Implied mass **≈ 6.5 × 10⁹ M☉**. Ring diameter matches ~ the lensed photon-capture size (≈ 2.6 r_s radius) at M87's distance. The crescent is **brighter on the south** — Doppler beaming from the approaching (clockwise-projected) side of the rotating flow. (https://arxiv.org/pdf/1906.11243)
- **Persistence (2018 vs 2017).** A second epoch confirmed a **persistent ring of the same diameter** with the bright spot *rotating* in position — the diameter is fixed by gravity (the metric), the brightness location by the fluid. Confirms the ring is a spacetime feature, not a transient blob. (https://eventhorizontelescope.org/M87-one-year-later-proof-of-a-persistent-black-hole-shadow)
- **Sgr A* (2022).** Ring diameter **51.8 ± 2.3 μas**, a **thick ring with modest azimuthal asymmetry and a dim interior**, mass **≈ 4 × 10⁶ M☉**, consistent with a Kerr hole viewed nearly face-on. Much faster variability than M87* (minutes vs days) because it's ~1500× less massive. (https://ui.adsabs.harvard.edu/abs/2022ApJ...930L..12E/abstract)
- **Polarization (M87*, 2021).** Resolved, **ordered, azimuthal (spiral) linear polarization** at a few gravitational radii → strong, dynamically important magnetic fields → **Magnetically Arrested Disk (MAD)** state. Later circular-polarization detection (Paper IX, 2023, https://arxiv.org/pdf/2311.10976) reinforces MAD + supports a spin-powered (Blandford–Znajek) jet.
- **The photon ring & subrings (theory, being targeted by BHEX / ngEHT 2024–2026).** The observed thick ring is really the emission ring plus a stack of **self-similar photon subrings n = 0, 1, 2, …**, each n counting extra half-orbits around the hole. Successive subrings are exponentially thinner and demagnified by ~ e^π ≈ 23 (Schwarzschild), converging onto the critical curve at b_c. The **n = 1 ring is nearly astrophysics-independent** — a clean GR ruler — and is the prime future-observable. (https://www.science.org/doi/10.1126/sciadv.aaz1310, https://arxiv.org/pdf/2411.01060)
- **Spin, latest (2025–2026).** No direct spin image yet, but: MAD polarimetric + ring-asymmetry modeling now **marginally disfavors |a*| ≲ 0.2** for M87* (i.e. it spins appreciably), consistent with a spin-driven jet (https://arxiv.org/pdf/2601.00394, https://arxiv.org/pdf/2505.17035). GRMHD + polarized ray-tracing remains the standard forward-model bridge (https://arxiv.org/pdf/2605.15166).

**Two independent sources of the ring asymmetry** to reproduce: (1) **Doppler beaming** — approaching side brighter (dominant); (2) **frame dragging** (Kerr) — twists and shifts the bright arc and, for high spin, offsets/flattens the shadow. The dark center is the shadow; the disk's near/far sides are lensed into a warped ring where the far side appears "lifted" above and below the hole.

---

## 5. Gravitational effects on light

### 5.1 Deflection (lensing)

Weak-field bending angle for impact parameter b:

```
α ≈ 4GM / (c² b) = 2 r_s / b        (weak field, b ≫ r_s)
```

This is *twice* the Newtonian value — the extra factor of 2 is pure GR (space curvature). It fails near the hole; the exact deflection **diverges logarithmically** as b → b_c = 3√3 M, which is *why* photons can loop and form the photon ring. For a renderer, the practical need is a deflection map α(b) that → the weak-field 2r_s/b at large b and blows up at b_c.

### 5.2 Redshift and the g-factor

Total frequency ratio observed/emitted, **g ≡ ν_obs / ν_emit**, combines three effects for a disk element:

```
g = ν_obs/ν_emit = [ √(g_tt-piece) ]_grav  ×  [ Doppler ]_motion
```

Explicitly, for an emitter with 4-velocity u^μ and photon 4-momentum p_μ, g = (p_μ u^μ)_obs / (p_μ u^μ)_emit. In words: **gravitational redshift** (photon climbs out of the well) times **relativistic Doppler** (transverse + longitudinal from orbital motion). Gravitational part alone (static emitter at r):

```
1 + z_grav = 1 / √(1 − r_s/r)   →   diverges at horizon.
```

Doppler part for orbital speed β at angle θ to line of sight uses the Doppler factor:

```
δ = 1 / [ γ (1 − β cosθ) ],    γ = 1/√(1−β²)
```

Approaching side (cosθ > 0): δ > 1, **blueshift**. Receding side: δ < 1, **redshift**. Inner disk near the hole is doubly redshifted by gravity even where Doppler blueshifts.

### 5.3 Relativistic beaming (the brightness asymmetry)

Specific intensity is **not** frame-invariant; the combination **I_ν / ν³ is** (Liouville's theorem). Therefore the observed brightness of a disk patch is:

```
I_ν,obs(ν_obs) = g³ · I_ν,emit(ν_emit),      with ν_emit = ν_obs / g
```

- **Monochromatic imaging** (fixed observed band): intensity ∝ **g³** — the standard for ray-traced BH images.
- **Bolometric** (integrated over all frequencies): intensity ∝ **g⁴** (one extra power from band-shifting).
- For a thermal source you can also shift the blackbody: T_obs = g · T_emit, so a beamed patch looks both **brighter and bluer**.

Net effect on the image: the approaching (large-δ, large-g) side of the disk is dramatically brighter and bluer; the receding side dim and red. With g³–g⁴ scaling even a modestly relativistic disk (β ~ 0.4 at ISCO) produces the strong crescent EHT sees. **This g³ multiplier is the single most important line of code for realism.**

---

## 6. Time near a black hole (the render clock)

Gravitational time dilation, distant-observer time t vs local proper time τ (Schwarzschild):

```
dτ/dt = √(1 − r_s/r)
```

- At r = 2 r_s: dτ/dt ≈ 0.71 (local clock runs at 71%).
- At r = 1.05 r_s: ≈ 0.22.
- At r → r_s: → 0 — from far away, matter *appears* to freeze and pile up on the horizon, its light stretching to infinite redshift and fading out. Infalling matter never *seen* to cross; it dims and reddens away.

Kerr generalization near the equator includes frame dragging; the zero-angular-momentum-observer (ZAMO) clock rate is √(−g_tt + g_tφ²/g_φφ). For our purposes the Schwarzschild √(1 − r_s/r) is the workhorse.

**Render use — the "time-lapse" clock (this project's declared BH visual):** drive each particle's *displayed* orbital phase / trail-advance by a local clock scaled by √(1 − r_s/r). Outer disk animates near real-time; inner annuli visibly slow; matter at the horizon asymptotically stalls and reddens (couple to g-factor color from §5). This is physically honest — it's literally the metric — and it is the mechanism that makes "the hole" read as a hole *through the particles themselves*, not a shader overlay.

---

## 7. IMPLEMENTATION RECOMMENDATION FOR OUR ENGINE

Design target: ~2M real particles on Metal, CIC-deposited to a density grid, **emergent** horizon from enclosed mass, running in real time. The BH is the particles — no second-layer shader disk. Below is the minimal correct model.

### 7.1 Unit anchor (already in the engine's grain)

- Keep **G = c = 1**, **r_s(field) = 1.0**, **r_s(M) = 2·gmSim(M)** → M_geom = gmSim(M) = r_s/2. Everything below is in these units, so `M = 0.5` when `r_s = 1`.
- Derived radii fall straight out and should be computed once per frame from the *live* emergent M(<r):
  - photon sphere `r_ph = 3M = 1.5 r_s`
  - ISCO `r_isco = 6M = 3 r_s` (Schwarzschild) — or the Kerr formula (§2) if you carry a spin `a*`
  - shadow/photon-capture `b_c = 3√3 M = 2.598 r_s` — this is the radius the dark disk must render to, NOT r_s.

### 7.2 Emergent horizon from enclosed mass (keep this — it's the honest core)

Bin particle mass into radial shells → cumulative M(<r). Define the honest horizon as the largest r where **2·M(<r) ≥ r** (i.e. r ≤ r_s(local) ⇔ enclosed mass has crossed its own Schwarzschild radius). This is the existing `r_h` probe and is the correct GR-flavored condition (a shell's own r_s). Feed r_h → the radii in §7.1 by using M_enc(r_h) as the hole mass for that frame. Keep reporting it honestly (per the project's "believe his eyes / a toggle is not a fix" rules): the disk look must *emerge* from this, not be latched.

### 7.3 Build a real 3D Keplerian disk (the emitter)

Spawn/maintain the luminous population as a thin, inclined, differentially-rotating disk of **real particles** (not a texture):

1. **Radial range:** r ∈ [r_isco, R_out]. Surface density Σ(r) ∝ r^(-3/4…-1) (any decreasing law; density falloff drives the brightness falloff).
2. **Thickness (geometrically thin):** half-thickness h(r) = (H/R)·r with H/R ≈ 0.05–0.1. Sample z ~ Gaussian(0, h(r)). (A puffier torus H/R ~ 0.3 reproduces the Sgr A*/M87 RIAF look better than a razor disk.)
3. **Velocity — differential/Keplerian:** each particle gets tangential speed `v_φ = √(M/r)`, direction = spin axis × r̂. Optionally the relativistic boost `v_φ = √(M/r)·(1−3M/r)^{-1/2}` inside ~10M. Add small random ε for line-width. This is the honest inner-fast/outer-slow shear.
4. **Inclination / spin axis:** one unit vector `n̂`. Tilt it for the classic ¾ view (i ≈ 60–70°) where beaming asymmetry and the lifted far-side ring are most visible. Face-on (Sgr A*) hides the asymmetry.
5. **Temperature/color:** `T(r) = T0 · (r/r_isco)^(-3/4) · (1 − √(r_isco/r))^{1/4}` → blackbody RGB (reuse the existing Lupton/asinh + blackbody path). Inner rim white-hot, outer red.

### 7.4 The render: backward geodesic ray-march sampling the live particle field

Per screen pixel, shoot a ray *from the camera*, bend it in the hole's field, and accumulate emission from the CIC density/temperature grid it passes through. Minimal correct recipe, in priority order:

1. **Choose Schwarzschild first.** The shadow is ~spin-independent (§2), so a non-rotating deflection model already yields a correct-size shadow, a correct photon ring, and (via §5.3) the disk crescent. Add Kerr only when you specifically want (a) a visibly off-center/D-shaped shadow at high spin, or (b) frame-dragging asymmetry beyond Doppler. **Recommendation: ship Schwarzschild; treat Kerr as a later toggle.**

2. **Analytic deflection over numerical geodesics — for most of the frame.** Full 2nd-order geodesic integration per pixel for 2M-particle-scale scenes at 60–120 fps is the FPS killer. Instead:
   - Precompute a 1-D **deflection LUT α(b)** (the project already built a Schwarzschild deflection LUT on 07-17). For each ray, the impact parameter b relative to the hole gives a total bend angle; rotate the ray in the plane containing camera–hole–ray. This is exact for light that stays outside ~the photon sphere and is *far* cheaper than stepping the geodesic.
   - **Capture test:** if b < b_c = 3√3 M → the ray is swallowed → output shadow (black). This one comparison *is* the shadow, at the correct 2.6 r_s radius.
   - The LUT's divergence as b → b_c naturally produces the bright photon ring (rays pile up in angle there). You get n=0 and a hint of n=1 for free; don't chase n≥2 subrings (sub-pixel, exponentially demagnified — invisible at this resolution).

3. **Numerical geodesic only near the hole.** For the small screen region where b ≲ (2–3) b_c, the analytic single-bend breaks down (multi-loop photons, the lifted far-side disk). Switch those rays to a short **adaptive-step** geodesic integrator (RK4/embedded-RK with error control; step ∝ distance to horizon). This is the existing "adaptive dt" idea applied to rays. Everything outside that region uses the cheap LUT rotation.

4. **Screen-bbox limiting (essential for real time).** Project the hole + b_c disk to screen, expand by a margin (~3×), and only ray-march inside that bounding box. Outside it, render the disk particles with ordinary (unbent) splatting — deflection there is negligible. This confines the expensive path to a few % of pixels.

5. **Sampling the emitter along the ray.** March the (bent) ray through the **CIC density grid**; at each step add `dI += g³ · j(ρ, T) · exp(−τ) ds`, where `j` is emissivity from local density/temperature and `g` is the per-sample redshift factor (§5.2: gravitational √(1−r_s/r) × orbital Doppler from the grid's mean velocity field). Accumulate optical depth τ for the thin-disk case (front occludes back). The **g³** weight *is* the beaming crescent; the √(1−r_s/r) *is* the inner darkening; do not fake either.

6. **The time-lapse clock (§6).** Advance each particle's orbital phase/trail by `dτ = dt·√(1 − r_s/r)`. Outer disk flows, inner disk visibly lags, horizon matter stalls and reddens — the hole emerges from particle behavior, matching the project's declared "time-compression + trails = the target look."

### 7.5 What to skip (real-time honesty)

- **n ≥ 2 photon subrings** — exponentially demagnified, sub-pixel. Not worth a geodesic.
- **Full Kerr ray-tracing** at first — shadow gain is ~nil; cost is high.
- **Classic thin-disk UV colors for the "mm image" look** — if you want the *EHT* aesthetic (thick fuzzy ring, MAD), use a puffier torus (H/R ~ 0.3) and let synchrotron-ish emissivity ∝ ρ·B track density; if you want the *Interstellar/thin-disk* aesthetic, use H/R ~ 0.05 and the T ∝ r^-3/4 blackbody. Both are correct for different systems — pick per look.
- **A second-layer glow/overlay disk** — forbidden by project canon; all light must come from the marched particle field.

### 7.6 One-line summary of the minimal model

> Emergent horizon from M(<r) → radii (r_ph, r_isco, b_c) from that mass → a real inclined thin/thick disk of particles on Keplerian v=√(M/r) with T ∝ r^-3/4 color → camera rays bent by an analytic Schwarzschild deflection LUT (capture inside b_c = 2.6 r_s = the shadow), upgraded to short adaptive geodesics only in a screen bounding box near the hole → accumulate emission with a **g³** Doppler+gravitational weight → advance particle time by √(1−r_s/r). Ship Schwarzschild; Kerr later.

---

*End of research pass 2026-07-24. Formulas in G=c=1; convert to engine units via r_s(field)=1.0, M=r_s/2=gmSim(M).*
