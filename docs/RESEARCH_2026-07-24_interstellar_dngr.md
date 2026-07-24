# Interstellar / DNGR Black-Hole Rendering — Implementable Spec

**What:** Extraction of the exact metric, geodesic ODE system, backward ray-trace algorithm, disk-emitter model, and frequency-shift physics from the DNGR (Double Negative Gravitational Renderer) paper, distilled into something we can implement as a per-pixel/per-tile backward geodesic ray-march in a Metal compute shader that samples our REAL particle field as the emitter.

**When:** 2026-07-24 12:15:00

**Primary source (authoritative, all equation numbers below refer to it):**
- O. James, E. von Tunzelmann, P. Franklin, K. S. Thorne, *"Gravitational Lensing by Spinning Black Holes in Astrophysics, and in the Movie Interstellar,"* Classical and Quantum Gravity **32** (2015) 065001. arXiv:1502.03808v2 [gr-qc].
  - PDF: https://arxiv.org/pdf/1502.03808 · abstract: https://arxiv.org/abs/1502.03808 · DOI: https://doi.org/10.1088/0264-9381/32/6/065001
- Companion (CGI-facing) paper: O. James et al., *"Building Interstellar's black hole: the gravitational renderer,"* SIGGRAPH 2015 talk. https://authors.library.caltech.edu/records/awp8p-s4d82
- DNeg summary: https://www.dneg.com/news/gravitational-lensing-by-spinning-black-holes
- K. S. Thorne, *The Science of Interstellar* (2014), ch. 8–9 (popular-level companion; equations are in the CQG paper, not the book).

**Standard-textbook facts used where the paper cites them rather than re-derives:** Bardeen 1972 shadow shape; Schwarzschild critical impact parameter b_c = 3√3 M (photon sphere r = 3M); Liouville's theorem I_ν ∝ ν³. These are flagged inline.

> **Units note for OUR engine (used throughout the "TIE TO ENGINE" boxes):** The paper sets **M = 1** (geometric units G = c = 1), so r_s = 2M = 2 and the horizon (Schwarzschild) is at r = 2. **Our sim** sets **c = 1** and **r_s(field) = 1.0 exactly**, with **r_s(M) = 2·gmSim(M)** ⇒ gmSim = GM = M and **M_field = r_s/2 = 0.5** in field units. So a paper radius r_paper (in units of M) maps to our field units as **r_field = r_paper · (r_s^field / 2) = r_paper · 0.5**, i.e. paper-r = 2 (horizon) ↔ field-r = 1.0 (our r_s). Everywhere the paper writes "2" for the horizon, we write "r_s = 1.0". Keep M as a live quantity: we have emergent **M(<r)** and horizon **r_h**.

---

## 1. Metric and the reduced geodesic ODE system they actually integrated

### 1.1 Kerr metric, Boyer–Lindquist coordinates (their Eq. A.1–A.2)

They adopt Boyer–Lindquist coordinates (t, r, θ, φ) tied to the black hole (chosen because they prevent the camera from falling through the horizon):

```
ds² = −α² dt² + (ρ²/Δ) dr² + ρ² dθ² + ϖ² (dφ − ω dt)²            (A.1)
```

with (M = 1, spin parameter a = J/M):

```
ρ = √(r² + a² cos²θ)
Δ = r² − 2r + a²                                    ( = r² − 2Mr + a² for general M )
Σ = √( (r² + a²)² − a² Δ sin²θ )
α = ρ√Δ / Σ          (lapse)                        (A.2)
ω = 2 a r / Σ²       (frame-dragging angular velocity of FIDOs)
ϖ = Σ sinθ / ρ       (cylindrical radius)
```

**FIDO (fiducial observer) orthonormal spatial basis** (A.3) — the local "static-ish" frame the camera is boosted relative to:

```
e_r̂ = (√Δ / ρ) ∂_r ,   e_θ̂ = (1/ρ) ∂_θ ,   e_φ̂ = (1/ϖ) ∂_φ
```

### 1.2 Conserved quantities

A null geodesic in Kerr has **three** conserved quantities plus the null condition:

- **E = −p_t** — energy. They fix the gauge **p_t = −1** (A.11), i.e. E ≡ 1.
- **b = p_φ** — axial (z) angular momentum (A.12). (If p_t were not −1, b = −p_φ/p_t.)
- **q = Carter constant** (A.12):
  ```
  b = p_φ ,     q = p_θ² + cos²θ ( b²/sin²θ − a² )            (A.12)
  ```
  (If p_t ≠ −1, q = Carter/p_t².)

Three auxiliary functions of r (and of b, q) appear in the equations of motion (A.4):

```
P = r² + a² − a b
R(r) = P² − Δ[ (b − a)² + q ]
Θ(θ) = q − cos²θ ( b²/sin²θ − a² )                              (A.4)
```

`R(r)` is the radial "potential" — its largest real root `r_up` is the outer radial turning point, central to the capture/escape test (§2).

### 1.3 The reduced ODE system actually integrated (their Eq. A.15 — the "super-Hamiltonian" form)

Because t is ignorable (p_t = −1 conserved) and φ is cyclic (p_φ = b conserved), the integrated system is **5 first-order ODEs** in the affine parameter ζ. They deliberately use the super-Hamiltonian form (Hamilton's equations for H = ½ g^{αβ} p_α p_β) because it is **robust at turning points**, unlike the more common `ρ² dr/dζ = ±√R` form (their footnote: cf. MTW Eq. 33.32, which changes sign at turning points and is numerically fragile).

```
dr/dζ  = (Δ/ρ²) p_r                                             (A.15a)
dθ/dζ  = (1/ρ²) p_θ                                             (A.15b)
dφ/dζ  = − ∂/∂b [ (R + ΔΘ) / (2 Δ ρ²) ]                         (A.15c)
dp_r/dζ = − ∂/∂r [ −(Δ/2ρ²) p_r² − (1/2ρ²) p_θ² + (R + ΔΘ)/(2Δρ²) ]   (A.15d)
dp_θ/dζ = − ∂/∂θ [ −(Δ/2ρ²) p_r² − (1/2ρ²) p_θ² + (R + ΔΘ)/(2Δρ²) ]   (A.15e)
```

(p_t = −1 and p_φ = b are constants of the motion, not integrated. φ is integrated only because we need the source direction, not for the capture test.)

The bracket `H_eff = −(Δ/2ρ²)p_r² − (1/2ρ²)p_θ² + (R+ΔΘ)/(2Δρ²)` is (up to sign convention) the super-Hamiltonian; A.15d/e are `dp_i/dζ = −∂H/∂x^i` and A.15a/b are `dx^i/dζ = ∂H/∂p_i`. The partials in A.15c–e must be taken **analytically** (they used automatic differentiation, A.4) or the closed forms below.

**Explicit partials for implementation** (M = 1; ' denotes ∂):
```
Δ' = ∂Δ/∂r = 2r − 2
R  = (r²+a²−ab)² − Δ[(b−a)²+q]
R' = ∂R/∂r = 2(r²+a²−ab)(2r) − Δ'[(b−a)²+q]
Θ  = q − cos²θ ( b²/sin²θ − a² )
∂Θ/∂θ = 2 sinθ cosθ ( b²/sin²θ − a² ) + cos²θ · ( 2 b² cosθ / sin³θ )
∂(ρ²)/∂r = 2r ,   ∂(ρ²)/∂θ = −2 a² cosθ sinθ
∂/∂b of (R+ΔΘ)/(2Δρ²):  R depends on b via P and via q-bracket; Θ via b²/sin²θ term.
    ∂R/∂b = 2(r²+a²−ab)(−a) − Δ·2(b−a)
    ∂Θ/∂b = − cos²θ · 2b/sin²θ
    dφ/dζ = − [ (∂R/∂b + Δ ∂Θ/∂b) / (2Δρ²) ]           (ρ,Δ independent of b)
```

> **Kerr-specific pieces that VANISH for Schwarzschild (a = 0):** ω = 0 (no frame-dragging), ϖ = r sinθ, ρ = r, Δ = r² − 2r, Σ = r², α = √(1−2/r). The Carter constant collapses to `q = p_θ² + b²cot²θ` and `q + b² = L²` (total angular momentum squared) is conserved — so for a non-spinning hole **every geodesic is planar** and you can drop to a 2-ODE orbit equation (see §7). No off-center shadow, no flattened edge, no Doppler asymmetry from spin — only the disk's orbital motion drives asymmetry.

---

## 2. Backward ray-tracing algorithm (their Appendix A.1, steps i–vii)

Ray-tracing runs **backward in time**: from the camera pixel out to the celestial sphere (r → ∞) or to a disk crossing or into the horizon. Map produced: local-sky direction (θ_cs, φ_cs) → celestial-sphere point (θ₀, φ₀), plus the blueshift factor.

**(i) Camera state.** Location (r_c, θ_c, φ_c); speed β and unit direction of motion (B_r̂, B_θ̂, B_φ̂) relative to the local FIDO; pixel's incoming direction (θ_cs, φ_cs) on the camera's local sky.
   - For a circular equatorial geodesic orbit: `B_r̂ = 0, B_θ̂ = 0, B_φ̂ = 1, β = (ϖ/α)(Ω − ω)`, with `Ω = 1/(a + r_c^{3/2})` (A.7).

**(ii) Incoming ray unit vector in camera Cartesian frame** (A.8):
```
N_x = sinθ_cs cosφ_cs ,  N_y = sinθ_cs sinφ_cs ,  N_z = cosθ_cs
```

**(iii) Relativistic aberration → FIDO frame** (A.9), then project onto FIDO spherical basis (A.10):
```
n_Fy = (−N_y + β)/(1 − βN_y)
n_Fx = −√(1−β²) N_x /(1 − βN_y)
n_Fz = −√(1−β²) N_z /(1 − βN_y)
```
then (with κ = √(1 − B_θ̂²)):
```
n_Fr̂ = (B_φ̂/κ) n_Fx + B_r̂ n_Fy + (B_r̂B_θ̂/κ) n_Fz
n_Fθ̂ = B_θ̂ n_Fy − κ n_Fz
n_Fφ̂ = −(B_r̂/κ) n_Fx + B_φ̂ n_Fy + (B_θ̂B_φ̂/κ) n_Fz
```

**(iv) Canonical momenta / initial conditions** (A.11), with FIDO-measured energy E_F:
```
E_F = 1 / (α + ω ϖ n_Fφ̂)
p_t = −1
p_r = E_F (ρ/√Δ) n_Fr̂
p_θ = E_F ρ n_Fθ̂
p_φ = E_F ϖ n_Fφ̂
```
then b = p_φ, q = p_θ² + cos²θ(b²/sin²θ − a²)  (A.12). **These are the ODE initial conditions.**

**(v) Capture vs escape test — done ANALYTICALLY before integrating** (A.13–A.14), using the unstable-photon-orbit functions b_o(r_o), q_o(r_o) (A.5) and the trapped-orbit radial range [r₁, r₂] (A.6):
```
r₁ = 2{1 + cos[(2/3) arccos(−a)]} ,  r₂ = 2{1 + cos[(2/3) arccos(+a)]}
b_o(r_o) = −(r_o³ − 3r_o² + a²r_o + a²) / (a(r_o − 1))
q_o(r_o) = −r_o³(r_o³ − 6r_o² + 9r_o − 4a²) / (a²(r_o − 1)²)
```
Algorithm:
  - (a) If `b₁ < b < b₂` (with b₁=b_o(r₂), b₂=b_o(r₁)) AND `q < q_o(b)` → **no radial turning point**: ray plunges. Then if p_r > 0 at camera → came from horizon (captured); if p_r < 0 → from celestial sphere.
  - (b) Else there are two turning points; if `r_c ≥ r_up` (r_up = largest real root of R(r)=0) → from celestial sphere; else → from horizon.

**(vi) Integrate** (A.15) backward from ζ = 0 to ζ_f (−∞ or a large negative cutoff) **only for rays that escape**. Source point on celestial sphere: `θ₀ = θ(ζ_f), φ₀ = φ(ζ_f)`. For a disk-crossing ray, integrate backward until the beam intersects the disk surface (A.6) and sample there.

**(vii) Blueshift** for a source at rest on the celestial sphere (A.16):
```
f_c/f₀ = ( √(1−β²) / (1 − βN_y) ) · ( (1 − b ω) / α )
```
(first factor = special-relativistic Doppler from camera motion; second = gravitational + frame-dragging shift.)

**Integrator (A.4, A.5):** custom **Runge–Kutta–Fehlberg (RKF45)** — embedded 4th/5th-order pair giving a per-step truncation-error estimate used for **adaptive step size**: small steps where the ray bends sharply in BL coordinates (near the hole/shadow edge), large steps where it bends least; empirically tuned tolerances. Position tolerance is tighter than beam-shape tolerance (position errors are more visible). Regions near the shadow are by far the slowest. Runtime: 30 min–several hours per 23 Mpixel IMAX frame on 10 CPU cores; 40k lines of C++.

> **Schwarzschild simplification of §2:** With a = 0, step (v) collapses to a single scalar test — the ray escapes iff its impact parameter **b_⊥ = L/E > b_c = 3√3 M** (standard result, photon sphere r = 3M), OR b_⊥ < b_c but the camera is outside the turning point. No b_o/q_o machinery, no Carter constant. The blueshift second factor becomes `(1 − 2M/r) ^ {1/2}` gravitational only (ω = 0). See §7 for the minimal form.

---

## 3. Accretion disk as an emitter (their Appendix A.6, §4)

They implemented **three** disk models; the physically-relevant one for us is the **volumetric** disk.

**Geometry.** The Interstellar disk is deliberately **anemic**: physically thin, marginally optically thick, lying in the equatorial plane, **not currently accreting**, cooled to a **position-independent temperature T = 4500 K** blackbody (the movie disk; a real Shakura–Sunyaev disk would be lopsided/hot and is discussed only as reference). Inner edge is at/near the ISCO; they do not publish an analytic T(r) because the movie disk is isothermal by choice. The **volumetric** disk was authored in Houdini as ~17 million voxels, each carrying **optical density + colour**; sampled via **Extinction-Based Sampling** into a mipmap volume, marched in voxel-length steps, two mip levels selected by the beam's major-axis width and interpolated (this is their built-in level-of-detail / anti-alias).

**Emission along a beam.** For each piecewise-linear beam segment through the voxels: accumulate colour, attenuate by optical thickness (`exp(−∫ κ ds)`); a beam either extincts in the disk or continues attenuated to pick up background light.

**Frequency shifts applied to colour AND intensity** (this is the physics we must copy):
- Compute the **net shift factor** `g ≡ f_c/f₀` from A.16 (Doppler from disk-material orbital velocity + gravitational redshift). On Gargantua the left side approaches at ~0.55c → g ~ 1.5 (blueshift); right side recedes → g ~ 0.4 (redshift), after folding in a ~20% gravitational redshift.
- **Colour:** the emitted blackbody at temperature T is received as a blackbody at **T_obs = g · T** (a blueshift raises apparent temperature → bluer; redshift → redder). They convolve the shifted blackbody spectrum with motion-picture-film RGB sensitivity curves to get (R,G,B). White balance set so 6500 K → equal RGB.
- **Intensity (brightness):** by **Liouville's theorem the specific intensity transforms as `I_ν ∝ ν³`** — i.e. observed specific intensity = **g³ × emitted** (bolometric I ∝ g⁴ if integrated, g³ per-frequency). This is what makes the approaching side blindingly bright and the receding side nearly vanish — the famous "relativistic beaming." (Their Fig. 15c caption: "specific intensity shifted in accord with Liouville's theorem, I_ν ∝ ν³.")

**The g-factor, explicitly (Schwarzschild, disk material on circular geodesic in equatorial plane, our practical case):**
```
g = f_obs/f_emit = 1 / [ γ (1 + β_los) ] · √(1 − 2M/r_emit) / √(1 − 3M/r_emit) ... 
```
Practically, compute g directly from the 4-velocity dot products:
```
g = (p_α u_obs^α)_camera / (p_α u_emit^α)_disk
```
where p_α is the photon momentum at each end (already integrated) and u^α are the emitter/observer 4-velocities. Then:
```
color_received  = blackbody( g · T_emit )   (or shift the emitted spectrum by g)
I_received      = g³ · I_emit               (per-frequency; use g⁴ for a grey bolometric emitter)
```

> **Movie cheat we should know about:** Nolan/Franklin **turned OFF the Doppler intensity/colour asymmetry** for the final film (kept the disk near-symmetric) because the true g³ lopsidedness (Fig. 15c) was "too confusing for a mass audience," and slowed spin to a/M = 0.6. Fig. 15c is "what the disk would truly look like." **We want the true version** (g³ beaming ON) since realism is the project's whole point.

---

## 4. Primary, secondary, and higher-order (photon-ring) images — where they emerge

There is **no separate code path** for the different images — they all fall out of the single backward integration (A.15). The order of an image = **how many times the backward ray loops around the hole** before reaching the source:

- **Primary image:** ray bends but makes < ½ loop. Direct view of the disk/star.
- **Secondary image:** ray makes ~½–1 loop around the hole. For the disk: light from the disk's **far/underside** passes **over the top (or under the bottom)** of the hole and down to the camera — this is the arc that appears **wrapped over and under the shadow** (§4.1.1, their Fig. 13). Upper wrap = disk **top face** behind the hole; lower wrap = disk **bottom face**.
- **Higher-order / photon-ring images (n ≥ 2):** rays that make one or more full loops near the **photon sphere** (r = 3M Schwarzschild; the unstable trapped-orbit band [r₁, r₂] for Kerr, A.6). These pile up into an infinite sequence of exponentially thinner, fainter rings hugging the shadow edge — the "photon ring." In the algorithm they appear as pixels whose (b, q) sit **just outside** the capture boundary of step (v): the closer to the critical curve, the more windings, the more the adaptive stepper subdivides (hence "regions near the shadow are much slower").

Mechanistically: the **critical curves** on the camera sky are the images of the caustics; each successive critical curve corresponds to one more half-loop and lies closer to the shadow edge. Crossing a critical curve creates/annihilates a pair of images.

---

## 5. The asymmetry, the wrap, and the shadow size

**Why one side is brighter (Doppler beaming):** the disk orbits; material on the side moving **toward** the camera has g > 1, and observed intensity ∝ g³ (§3), so it is dramatically brighter and bluer; the receding side (g < 1) is dim and red. This is intrinsic to the disk's orbital velocity and exists even for a non-spinning hole. (For a spinning hole, frame-dragging additionally flattens the **shadow's** left edge — the side whose horizon rotates toward the camera — per Bardeen 1972; that flattening is a Kerr-only effect and disappears at a = 0.)

**Why the disk wraps over/under the shadow:** gravitational light-bending. Light from the part of the disk **behind** the hole is deflected up over the top of the hole (and symmetrically under the bottom) into the camera, so the far disk appears as arcs above and below the black shadow rather than being occulted (§4.1.1). Top-face light → upper wrap; bottom-face light → lower wrap; a full extra loop gives the faint third image at the shadow edge.

**Shadow angular size (Schwarzschild, standard result the paper builds on):**
- Critical impact parameter `b_c = 3√3 M ≈ 5.196 M = 2.598 r_s` (r_s = 2M). Photon sphere at r = 3M.
- For a camera at radius r_c, the shadow's **angular radius** θ_sh satisfies:
  ```
  sin²θ_sh = b_c² (1 − 2M/r_c) / r_c²        (exact)
  θ_sh ≈ b_c / r_c = 3√3 M / r_c             (r_c ≫ M)
  ```
  So the shadow subtends `~ 5.196 M / r_c` radians — e.g. at r_c = 30M it's ~0.17 rad ≈ 10°. As the camera approaches, aberration + the exact formula make it grow to fill the sky. **In our field units** (r_s = 1, M = 0.5): b_c = 2.598·r_s = 2.598 field units; θ_sh ≈ 2.598 / r_c^field.
- Kerr: the shadow is no longer a circle — it is offset and flattened on the co-rotating side; angular area still ~ (a few M / r_c)². Use the Bardeen contour if we ever spin the hole.

---

## 6. Real-time / approximation techniques (from the paper and the derived literature)

From DNGR itself (A.2–A.5):
- **Ray bundles instead of single rays.** They integrate a central ray PLUS the **equation of geodesic deviation** (A.23, a variant of the Sachs optical-scalar / Pineault–Roeder equations) to get an **elliptical footprint** (major/minor angular diameters δ₊, δ₋, orientation μ) of each pixel-beam on the celestial sphere. This ellipse is used to **filter (pre-integrate/mip)** the source texture — giving IMAX smoothness with **no flicker/aliasing** and no supersampling. Cost: ~3× per-step vs the central ray alone.
- **Analytic capture test before integration** (A.13–14): skip integrating captured rays entirely.
- **Adaptive RKF45 stepping** keyed to local bending; tighter tolerance on position than on beam shape.
- **Mipmapped volume** (Extinction-Based Sampling) with LOD chosen by beam width — the volumetric analog of texture mipmapping.
- **Flat-space shortcut for near-camera layers:** disk layers so close that curvature/redshift are negligible were rendered in flat spacetime.

Derived real-time techniques (community, post-paper, relevant to a GPU shader):
- **Cartesian Schwarzschild reduction** (Riccardo Antonelli, "starless"/"Physics of a black hole rendering"): integrate the photon as a 3-vector with the compact planar acceleration (see §7) — no coordinate singularities, camera anywhere, trivially GPU-parallel. This is the standard basis for real-time WebGL/shader black holes.
- **Precomputed deflection LUT:** for a static observer radius, the map (impact parameter b → total deflection angle / exit direction) can be baked to a 1-D or 2-D texture and sampled per pixel — no integration at render time. (We already built a Schwarzschild deflection LUT on 07-17 per project memory; this is exactly the DNGR-consistent shortcut.)
- **Screen bounding box:** only ray-march pixels inside the hole's projected bounding disk (θ_sh from §5); composite over an untouched starfield elsewhere.

---

## 7. MINIMAL IMPLEMENTABLE VERSION (Schwarzschild, correct shadow + photon ring + primary/secondary images)

Goal: the simplest **correct** per-pixel backward geodesic ray-march for a Metal compute shader. Schwarzschild (a = 0) is fine — it gives a true shadow, photon ring, and primary/secondary images. The only thing it omits vs Kerr is the frame-dragging flattening/offset of the shadow and spin-Doppler; the disk's own orbital Doppler beaming is fully present.

### 7.1 The ODE — Cartesian "flat-space-vector" form (equivalent to A.15 at a = 0)

For a non-spinning hole every null geodesic is planar, so we can integrate the photon as a 3-vector **x** with velocity **v = dx/dλ** in ordinary Cartesian coordinates centered on the hole. Let `r = |x|`, and the conserved specific angular momentum `h = |x × v|` (constant along the ray). Then the exact Schwarzschild null geodesic obeys the compact acceleration (equivalent to the orbit equation `d²u/dφ² + u = 3M u²`, u = 1/r):

```
d²x/dλ² = − (3/2) · r_s · h² · x / r⁵   ( = −3·M·h²·x/r⁵ )   with h² = |x × v|² , r = |x|
```

(Set M in field units: **M = r_s/2 = 0.5**, so r_s = 1.0. Newtonian term is absent for light; the entire bending is the (3/2)·r_s·h²·r⁻⁵ term — this is what produces b_c = 3√3 M, the photon ring, and the wraps.)

> **⚠ CORRECTED 2026-07-24 13:56:40 — this line originally read −(3/2)·M·h²·x/r⁵, which is HALF the
> correct value and does NOT reproduce the shadow.** Derivation: the null geodesic gives
> `r'' = h²/r³ − (3/2)·h²·r_s/r⁴`, and the flat-space polar decomposition gives
> `r'' = a_r + h²/r³`, so `a_r = −(3/2)·h²·r_s/r⁴`. Note the equivalence check two lines
> below (`d²u/dφ² + u = 3Mu²`) is and always was CORRECT — it is what the wrong Cartesian
> form contradicted. Caught by validating the integrator offline before it shipped
> (`bc_validate.cpp`): the wrong coefficient measures b_c = √2 (the r = r_s turning point of a
> half-strength field, which has no photon sphere at all); the corrected one measures
> b_c = 2.598071 against the exact 3√3·M = 2.598076 (rel err 1.4e-6), with rays just outside
> b_c skimming rmin = 1.518 → the photon sphere at 1.5 r_s, and |Δh²|/h² < 5e-10.

This is a 6-D first-order system (x, v). It has **no coordinate singularity** (unlike BL r, θ), so the camera can sit anywhere and rays can pass over the poles freely — ideal for a shader.

> Equivalence check: for a planar ray this reduces exactly to `d²u/dφ² + u = 3Mu²`, the standard Schwarzschild light-bending equation, whose circular photon-orbit solution is r = 3M and whose escape/capture separatrix is b_c = 3√3 M. It is the a → 0 limit of the paper's A.15.

### 7.2 Integration scheme

- **Integrator:** classic **RK4** with adaptive step (or RKF45 as in DNGR). A cheap, robust adaptive rule: `dλ = k · r^(3/2)` (Keplerian-like) or `dλ = k · (r − r_s) / |v|` so steps shrink near the horizon/photon sphere. Start with k ≈ 0.1–0.3 and tighten near the shadow (that's where all the visible structure is).
- **Direction:** integrate **backward** (from camera outward). Initial **v** = the pixel's world-space ray direction (unit); initial **x** = camera position. (For a moving camera, first aberrate the pixel direction as in A.9; for a static camera skip it.)

### 7.3 Per-pixel algorithm (Metal compute pseudo-code)

```
// Runs only for pixels inside the hole's screen bounding box (θ_sh, §5).
// Field units: r_s = 1.0, M = 0.5, c = 1.

kernel void bh_march(pixel p):
    // 1. Camera ray in world space (hole at origin)
    x = cameraPos                      // float3
    v = normalize(pixelWorldDir(p))    // float3, backward ray
    // (optional) relativistic aberration of v for moving camera  [A.9]

    h2 = dot(cross(x,v), cross(x,v))   // conserved |x×v|^2
    color = 0;  transmittance = 1

    for step in 0..MAX_STEPS:
        r = length(x)

        // 2. Termination: horizon capture
        if r < r_s * 1.001:            // r_s = 1.0
            return blackHoleColor(0)   // shadow: pure black (or CMB-tiny)

        // 3. Termination: escaped to starfield
        if r > R_ESCAPE and dot(x,v) > 0:   // moving outward, far away
            color += transmittance * sampleStarfield(v)   // UNTOUCHED starfield
            return color

        // 4. Disk crossing test (equatorial plane y=0, r in [r_isco, r_out])
        if crossedEquator(x_prev, x) and (r_in < r_disk < r_out):
            xd = intersectPlane(x_prev, x)          // exact crossing point
            (Iem, Tem, kappa) = sampleParticleField(xd)   // OUR density grid, §TIE
            g  = gFactor(xd, v, cameraFrame)        // §3 : photon·u_emit vs photon·u_obs
            // Doppler+grav shift applied to colour AND intensity:
            col = blackbodyRGB(g * Tem) * (g*g*g)   // I_ν ∝ ν³  (Liouville)
            a   = 1 - exp(-kappa * segLen)          // opacity from optical depth
            color        += transmittance * a * col * Iem
            transmittance *= (1 - a)
            if transmittance < 0.003: return color  // fully extincted

        // 5. Geodesic step (RK4 on the 6-vector [x,v])
        dλ = STEP_SCALE * pow(r, 1.5)               // adaptive
        (x, v) = rk4_step(x, v, dλ):
            accel(x) = -1.5 * r_s * h2 * x / pow(length(x),5)   // = -3*M*h2*x/r^5

    // ran out of steps near shadow → treat as captured
    return blackHoleColor(0)
```

Notes:
- **h2 is recomputed-free**: it's conserved, so compute once. (Numerically it drifts slightly; recompute each step from x,v if you see the ring breathing.)
- **Photon ring + secondary images are automatic:** pixels near the critical impact parameter loop many times inside the `for` loop, so raise MAX_STEPS (≈ few thousand) and shrink STEP_SCALE near the shadow, exactly as DNGR does adaptively.
- **Primary vs secondary disk image** emerge naturally: a ray may cross the equatorial plane **twice** (once in front, once after wrapping over the hole) — handle by NOT returning on the first disk hit if the disk is optically thin (accumulate, keep marching), which reproduces the over/under wrap of §4.1.1.
- **Composite:** everywhere outside the bounding box, and for escaped rays, sample the **untouched starfield** with the (lensed) exit direction v — that gives the Einstein-ring distortion of background stars for free.

### 7.4 Upgrade path to Kerr (only if we spin the hole)
Swap §7.1 for the full BL Hamiltonian system A.15 (5 ODEs in r, θ, φ, p_r, p_θ with b, q conserved), use the analytic capture test A.13–14, and add frame-dragging to g (A.16 second factor with ω ≠ 0). Everything else (disk sampling, g³ beaming, compositing) is unchanged.

---

## TIE TO OUR ENGINE — explicit mappings

1. **Units.** Paper M = 1, horizon r = 2. Ours: r_s = 1.0, **M = 0.5**, so **r_field = 0.5·r_paper**. Photon sphere (Schwarzschild) at r = 3M = 1.5 r_s = **1.5 field units**; critical impact parameter b_c = 3√3 M = 2.598 r_s = **2.598 field units**. Use **live M(<r)** in the acceleration term (§7.1) instead of a constant M when the mass is extended — i.e. `accel = −3·M(<r)·h²·x/r⁵` (= −(3/2)·r_s(<r)·h²·x/r⁵) with M(<r) read from the enclosed-mass profile. Outside all the particles M(<r) → total M and it reduces to point-mass Schwarzschild; that's the correct behavior and it ties the shadow size directly to our **emergent horizon r_h**.

2. **Disk = the REAL particle field, not an analytic disk.** In step 4/`sampleParticleField(xd)`, sample **our CIC density grid / spatial hash** at the ray's crossing/segment point to get local emissivity I_em, temperature/colour T_em (from particle blackbody / speed), and opacity κ (∝ local density). This replaces DNGR's Houdini voxel volume with our live 2M-particle field — same math (extinction-based accumulation, §3), our data. March the geodesic in **short linear segments** (DNGR A.6) and at each segment do one grid lookup + `transmittance *= exp(−κ·segLen)`.

3. **g-factor from the actual field.** The emitter 4-velocity `u_emit` at xd is the **local bulk velocity of the particles** in that grid cell (we already deposit momentum → bulk v via CIC moments — see the "lines bug" CIC-moments fix in memory). Compute g = (p·u_obs)/(p·u_emit); apply colour shift `T→gT` and intensity `×g³`. This makes the Doppler beaming asymmetry emerge from the real orbital motion of our particles — no faked bright side.

4. **Screen bounding box + untouched starfield.** Only dispatch the compute kernel over the hole's projected bounding disk (radius from θ_sh, §5, using live r_h and camera distance). Every pixel outside, and every escaped ray inside, composites against the **existing starfield render untouched** — satisfying the "no second layer for the BH" rule: the hole is the particles + the geodesic bending of the one starfield, not an overlaid sprite.

5. **Precompute option.** For a fixed camera radius we can bake the deflection map (impact parameter → exit direction) to a texture (the 07-17 Schwarzschild LUT) and skip integration for star-only pixels, integrating fully only where the ray crosses the particle disk. That is the DNGR-consistent real-time shortcut.

---

## Key equations to keep on one card
```
Schwarzschild field units: r_s = 1, M = 0.5, photon sphere r = 1.5, b_c = 2.598
Geodesic (a=0, Cartesian):  d²x/dλ² = −3·M(<r)·|x×v|²·x/|x|⁵   ( = −(3/2)·r_s·h²·x/r⁵ )
Capture:                    r < r_s  → black (shadow)
Doppler+grav g-factor:      g = (p·u_obs)/(p·u_emit)
Colour shift:               T_obs = g · T_emit
Intensity (Liouville):      I_obs = g³ · I_emit
Shadow angular radius:      sinθ_sh = b_c √(1−2M/r_c) / r_c  ≈ b_c/r_c
```

*Source of record: James, von Tunzelmann, Franklin & Thorne, CQG 32 (2015) 065001 = arXiv:1502.03808v2. Equation numbers (A.1)–(A.16) are theirs. Schwarzschild reductions and the Cartesian planar form are the a→0 limit of their A.15, standard in the GR-ray-tracing literature.*
