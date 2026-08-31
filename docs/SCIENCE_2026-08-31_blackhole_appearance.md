<!-- SCIENCE TRACK — Claude Science project SPACE SYNTH X
     Produced 2026-08-31. Lands per SCIENCE_PROMPTS_2026-08-31.md §"HOW THE OUTPUT COMES BACK":
     a cited doc, never pasted into src/. THIS IS A CLAIM UNTIL CHECKED AGAINST THE LITERATURE.
     Nothing here is fitted to SPACE SYNTH output. Primary references are inline.
     Prompt: P1 — what a black hole should actually look like. Feeds: FABLE F1.
     Citation verification: 61 of 68 identifiers tool-verified; 3 marked unverified in text. Gralla, Holz & Wald 2019 read in full, ring boundaries independently reproduced by geodesic integration.
-->

# What a black hole should actually look like

An implementation reference for SPACE SYNTH. Equations first, in geometrized units
(G = c = 1), with the conversion to simulation length units and to SI stated for every
dimensional quantity. Each relation carries its source and its regime of validity.
Quantities computed here from a cited equation are labelled **[own arithmetic]**; nothing
below is fitted to data or to simulation output.

---

## 0. Conventions and the unit map

**Convention.** `M` is the hole's mass in geometrized units, so `M` has dimensions of
length and `r_s = 2M`. `a` is the Kerr rotation parameter (dimensions of length) and
`a_* = a/M = J/M²` is the dimensionless spin, `|a_*| ≤ 1`. Radii written `r` are
Boyer–Lindquist radial coordinates ([Boyer & Lindquist 1967](https://doi.org/10.1063/1.1705193)),
*not* proper distances and *not* isotropic/Cartesian radii. This matters: every formula
below is in Boyer–Lindquist `r`, and if the simulation's particle positions are Cartesian
distances from the hole, they are only equal to BL `r` at large radius.

**Your simulation length unit.** One sim length ≡ `r_s(M_field) = 2 M_field`, so

```
M_field = 0.5                      [sim length]
1 sim length = 2 G M_field / c²    = 2.9533 km × (M_field / M_sun)
1 sim time   = 1 sim length / c    = 9.8510e-6 s × (M_field / M_sun)
```

A hole with horizon radius 0.1717 sim has `M_hole = 0.08585` sim `= 0.1717 M_field`
— i.e. that "typical formed hole" carries 17.2% of the entire field mass. **[own arithmetic]**
⛔ **CORRECTED 2026-08-31 17:05 — the arithmetic stands, the word "typical" does not.** `0.1717`
coincided with `F_BH_CLUSTER`, which was **deleted at 16:10:25**; hole mass is now unbounded, so
this is one sample rather than a characteristic or maximum mass. Everything below computed at
`M = 0.08585` sim is correct *at that mass* and re-maps by the scaling exponents — see
`ADDENDUM_04` §2 and `resolution-verdict-table.csv`, which is already mass-parametrised.
Its quoted photon sphere 0.2576 = 3M and ISCO 0.5151 = 6M confirm those numbers are the
**Schwarzschild** (`a_* = 0`) values; the moment you give the hole spin, all three move
(§3).

**Conversion rule for every formula below.** Formulas are written in units of `M`.
To evaluate at a hole of mass `M_hole` in sim units, substitute `r → r_sim / M_hole`,
and multiply any returned length by `M_hole`, any returned angular frequency by
`1/M_hole`, any returned time by `M_hole`.

**Two independent physical scales.** The *geometry* of everything in §1 and §3 is set by
`M_hole` alone. The *brightness* of everything in §2 additionally requires an accretion
rate and a gas temperature, which a collisionless particle field does not supply (§2.4).
Keep these separate in the code; they are separate in the physics.

---

## 1. The observable structure

### 1.1 The critical curve — a property of the spacetime alone

Null geodesics that asymptote to the unstably-bound photon orbits define, on the
observer's sky, a closed curve called the **critical curve**. For Schwarzschild it is a
circle of angular radius

```
b_c = 3√3 M = 5.19615 M = 2.59808 r_s
```

([Synge 1966](https://doi.org/10.1093/mnras/131.3.463) first computed the escape cone that
this bounds; the strong-deflection expansion around it is
[Darwin 1959, Proc. R. Soc. A 249, 180](#) *(identifier not verified)*, sharpened by
[Bozza 2002](https://doi.org/10.1103/PhysRevD.66.103001) and
[Virbhadra & Ellis 2000](https://doi.org/10.1103/PhysRevD.62.084003)). Your re-derivation
agreeing with this to 8e-15 means your geodesic integrator is correct; the number is
exact, not fitted.

For Kerr the critical curve is not a circle. Parametrize it by the radius `r̃` of the
spherical photon orbit that a given critical ray asymptotes to, with `r̃` running between
the prograde and retrograde equatorial photon-orbit radii. The photon-shell conserved
quantities are ([Bardeen 1973, in *Black Holes*, Les Houches, p. 215](#) *(no DOI; volume
and page tool-verified)*; equivalently
[Teo 2003](https://doi.org/10.1023/A:1026286607562), building on
[Wilkins 1972](https://doi.org/10.1103/PhysRevD.5.814)):

```
λ(r̃) = -( r̃³ - 3M r̃² + a² r̃ + a² M ) / ( a (r̃ - M) )
η(r̃) = - r̃³ ( r̃³ - 6M r̃² + 9M² r̃ - 4 a² M ) / ( a² (r̃ - M)² )
```

with `λ = L/E` and `η = Q/E²` (Carter's constant). The screen coordinates for an observer
at inclination `i` from the spin axis are, in units of `M` at large observer distance
(Bardeen 1973):

```
α(r̃) = -λ(r̃) / sin i
β(r̃) = ± sqrt( η(r̃) + a² cos²i - λ(r̃)² cot²i )
```

`α` runs along the direction perpendicular to the projected spin axis; `β` runs parallel
to it. Sanity checks reproduced here: `λ² + η → 27M²` as `a → 0` at `r̃ = 3M`
(recovering `b_c = 3√3M`); and for `a_* → 1, i = 90°` the curve has a straight vertical
edge at `α = -2M` and reaches `α = +7M`, total width `9M`. **[own arithmetic]**

### 1.2 The critical curve is not the shadow edge — there are four different curves

This distinction is the central point of
[Gralla, Holz & Wald 2019](https://doi.org/10.1103/PhysRevD.100.024018), and getting it
wrong is exactly how renderers fake it. Four separate things are routinely called "the
shadow":

| Curve | Schwarzschild radius | Depends on |
|---|---|---|
| **Critical curve** | `b_c = 5.196 M` | spacetime only |
| **Backlit shadow edge** (distant screen behind the hole) | `6.168 M` **[own arithmetic]** | spacetime + illumination geometry |
| **Inner edge of the direct image** ("lensed horizon" / inner shadow) | `2.848 M` **[own arithmetic]** | spacetime, if emission reaches the horizon |
| **Edge of the dark region in an actual image** | anywhere from `≈2.8 M` to `≳7 M` | **emission model** |

The backlit value 6.168 M is the impact parameter at which the total bending angle reaches
`π/2`, computed here by integrating `dφ/dr = 1/(r² √(1/b² - 1/r² + 2M/r³))`; GHW quote
≈6.2 M. The 2.848 M value is the impact parameter for which the backward-traced ray
reaches `r = 2M` exactly as it accumulates `Δφ = π/2` from a face-on observer, i.e. the
gravitationally lensed image of the horizon; GHW quote ≈2.9 M, and this is the "inner
shadow" whose direct observability was argued by
[Chael, Johnson & Lupsasca 2021](https://doi.org/10.3847/1538-4357/ac09ee).

**Practical consequence.** The dark area in your frame should be produced by *not emitting*
where there is no matter, then transported by geodesics — never by stamping a disc of
radius `b_c`. For an optically thin flow that extends to the horizon, the dark region is
the lensed horizon (`≈2.8 M` face-on), which is *smaller* than the critical curve; for a
thin disc truncated at the ISCO seen face-on it is *larger*. Only in the artificial case of
an isotropically illuminated hole with no emission along the line of sight does the dark
region coincide with the critical curve
([Narayan, Johnson & Gammie 2019](https://doi.org/10.3847/2041-8213/ab518c);
[Bronzwaer & Falcke 2021](https://doi.org/10.3847/1538-4357/ac1738)).

### 1.3 Image order n and the transfer function

Index images by `n`, the number of times a backward-traced ray crosses the equatorial
plane. Define the transfer function `r_n(b)`: the emission radius of the `n`-th crossing as
a function of screen radius. For Schwarzschild, face-on, computed here by direct
integration of the null geodesic:

| Image | Name (GHW) | `b` range | Character |
|---|---|---|---|
| `n = 1` | direct | `2.848 M` – ∞ | `dr/db ≈ 1`, this is the image you actually see |
| `n = 2` | lensing ring | `5.015 M` – `6.168 M` | `dr/db ≈ 7` at the inner edge, → ∞ at the outer |
| `n = 3` | photon ring | `5.188 M` – `5.228 M` | width `0.040 M` |
| `n = 4` | — | `5.1962 M` – `5.1975 M` | width `1.4e-3 M` |

**[own arithmetic; GHW quote 5.02–6.17 M and 5.19–5.23 M for n = 2, 3]**
Full table in `schwarzschild-transfer-function.csv`.

The `n ≥ 2` images are *demagnified*, not merely thin: a thin annulus on the screen maps to
a huge range of emission radii, so the flux it collects is small. GHW's quantitative
result is the one to implement against: for an optically thin disc, the `n = 2` lensing
ring contributes a **few per cent** of the total flux and the `n ≥ 3` photon ring
contributes a fraction of a per cent. The brightness divergence at the critical curve is
only *logarithmic*, and the summed contribution of all `n ≥ 3` orders is `1/(1 - e^{-π})
≈ 1.045` times the `n = 3` order alone. **The photon ring is not the bright feature.** The
bright thin arc in a physically correct thin-disc image is the `n = 2` lensing ring, and
its brightness comes from the lensed far side of the disc, not from photons that orbited
many times.

### 1.4 Subring exponential structure and the Lyapunov scaling

Near the critical curve the `n`-th subring's offset from `b_c` shrinks geometrically. From
the strong-deflection expansion, `b_n - b_c ∝ e^{-γ n}`, with

```
γ = π        exactly, for Schwarzschild        e^{-γ} = e^{-π} = 0.04322
```

Measured on the computed ring edges: `(b_4-b_c)/(b_3-b_c) = 0.0426` and
`(b_3-b_c)/(b_2-b_c) = 0.0327`, converging on `e^{-π}` from below as `n` grows.
**[own arithmetic]**

`γ` is the **Lyapunov exponent** of the unstably bound photon orbit, measured per half
libration. Its origin: for a circular equatorial null geodesic with radial potential
`𝓡(r) ≡ (dr/dσ)²`, the instability rate in coordinate time is
`λ_L = sqrt(𝓡''(r_c)/2) / (dt/dσ)` ([Cardoso, Miranda, Berti, Witek & Zanchin
2009](https://doi.org/10.1103/PhysRevD.79.064016)); for Schwarzschild this evaluates to
`λ_L = 1/(3√3 M) = Ω_ph`, and multiplying by the half-orbit duration
`Δt = π/Ω_ph = 3√3 π M` returns `γ = π`. Reproduced here to 6 digits. **[own arithmetic]**

Three **critical exponents** govern successive subrings
([Gralla & Lupsasca 2020a](https://doi.org/10.1103/PhysRevD.101.044031);
[Johnson et al. 2020](https://doi.org/10.1126/sciadv.aaz1310)) — the demagnification `γ`,
the time delay `δ`, and the azimuthal rotation `τ`:

```
flux / width :  F_{n+1}/F_n  =  e^{-γ}
arrival time :  t_{n+1} - t_n = δ
image rotation: φ_{n+1} - φ_n = τ
```

For Schwarzschild these are exactly

```
γ = π
δ = π / Ω_ph = 3√3 π M = 16.3242 M      = 4.020 ms at M = 50 M_sun
                                        = 1.401 sim length at M_hole = 0.08585 sim
τ = π   (successive images appear on opposite sides; no net rotation, by spherical symmetry)
```

**[own arithmetic; the δ, γ, τ framework is Gralla & Lupsasca 2020a]**

For Kerr all three vary *around* the ring, because different points of the critical curve
asymptote to photon-shell orbits at different `r̃`. Gralla & Lupsasca 2020a give
`γ(r̃, a)`, `δ(r̃, a)`, `τ(r̃, a)` as elliptic integrals over the polar motion; the
closed-form Kerr null geodesics needed to evaluate them are in
[Gralla & Lupsasca 2020b](https://doi.org/10.1103/PhysRevD.101.044032). What is tabulated
here in `kerr-spin-table.csv` is the *equatorial specialization* — the Lyapunov exponent
per `Δφ = π` for the equatorial circular null geodesic, which equals Gralla–Lupsasca's `γ`
at `a = 0` and gives the value at the left and right extremities of the critical curve
under edge-on viewing. It is **not** their polar-libration `γ` for `a ≠ 0`:

| `a_*` | `γ` prograde | `e^{-γ}` prograde | `γ` retrograde | `e^{-γ}` retrograde |
|---|---|---|---|---|
| 0 | 3.1416 | 0.0432 | 3.1416 | 0.0432 |
| 0.5 | 2.3925 | 0.0914 | 3.6656 | 0.0256 |
| 0.9 | 1.2160 | 0.2964 | 4.0041 | 0.0182 |
| 0.998 | 0.1940 | 0.8236 | 4.0795 | 0.0169 |

**[own arithmetic from the Kerr geodesic equations + the Cardoso et al. 2009 Lyapunov
definition]** The physical content: spin makes the prograde side of the photon ring
*much* less demagnified (at `a_* = 0.998` successive prograde subrings are only 18% dimmer,
not 96% dimmer), so a rapidly spinning hole viewed edge-on genuinely has visible subring
structure on one side and none on the other. The interferometric signature of this
structure — a periodic ringing in visibility amplitude on long baselines with period set by
the ring diameter — is the observable proposed by Johnson et al. 2020 and refined for shape
measurement by [Gralla, Lupsasca & Marrone
2020](https://doi.org/10.1103/PhysRevD.102.124004) and
[Gralla & Lupsasca 2020c](https://doi.org/10.1103/PhysRevD.102.124003). The autocorrelation
of the time-variable photon ring encodes `γ`, `δ`, `τ` directly
([Hadar, Johnson, Lupsasca et al. 2021](https://doi.org/10.1103/PhysRevD.103.104038)); the
polarimetric version is [Himwich, Johnson, Lupsasca et al.
2020](https://doi.org/10.1103/PhysRevD.101.084020).

### 1.5 Shadow shape and size versus spin and inclination

Computed from the Bardeen 1973 critical-curve formulas above, all in units of `M`
(full table in `kerr-spin-table.csv`): **[own arithmetic]**

| `a_*` | areal radius `i=90°` | width (α) | height (β) | centroid shift `Δα` | areal radius `i=0` |
|---|---|---|---|---|---|
| 0 | 5.1962 | 10.3923 | 10.3923 | 0 | 5.1962 |
| 0.5 | 5.1555 | 10.2344 | 10.3923 | +1.021 | 5.1205 |
| 0.9 | 5.0319 | 9.6767 | 10.3923 | +1.994 | 4.9161 |
| 0.998 | 4.9380 | 9.1076 | 10.3923 | +2.443 | 4.8304 |

Three facts a renderer can use directly:

1. **The vertical extent at edge-on viewing is exactly `6√3 M = 10.3923 M` for every
   spin**, to machine precision across `0 ≤ a_* ≤ 0.9999`. Spin flattens the shadow only
   horizontally.
2. **The area-equivalent radius is nearly spin-independent**: it varies by 5.8% of
   `3√3 M` over the full spin range at `i = 90°`, and by 7.1% at `i = 0`. This is why the
   shadow diameter is a good mass measurement and a poor spin measurement — the argument
   behind the EHT mass estimates ([EHT Collaboration 2019, ApJL 875,
   L6](https://doi.org/10.3847/2041-8213/ab1141);
   [EHT Collaboration 2022, ApJL 930, L12](https://doi.org/10.3847/2041-8213/ac6674)) and
   quantified for a wide class of metrics by [Johannsen & Psaltis
   2010](https://doi.org/10.1088/0004-637X/718/1/446).
3. **The centroid displacement is `Δα ≈ 2 a_* M sin i`** to about 1% for `a_* ≲ 0.4`,
   degrading to 24% high at `a_* = 0.998`. Use the exact parametrization for high spin.

The shadow is *displaced*, not just deformed: the prograde (co-rotating) side of the
critical curve moves inward and is where the straight edge forms. Under a sign convention
`α = -λ/sin i` the flat edge appears at negative `α`, and the whole figure shifts to
positive `α`.

### 1.6 Spacetime versus emission model — the audit

| Feature | Observer-independent property of the spacetime? |
|---|---|
| Critical curve position and shape | **Yes** — depends only on `M`, `a_*`, `i` |
| `γ`, `δ`, `τ` critical exponents | **Yes** |
| Lensed-horizon (inner shadow) curve | **Yes**, given `M`, `a_*`, `i` |
| Backlit shadow edge | Yes, given the illumination is a uniform screen at infinity |
| Which subrings exist | Yes |
| **Brightness** of the photon ring, lensing ring, direct image | **No** — emission model |
| Size and shape of the *dark region in the image* | **No** — set by where emission stops |
| Asymmetry of the ring (bright side) | **No** — Doppler beaming of the emitting fluid, so it depends on the flow's velocity field |
| Existence of a sharp disc edge or an underside arc | **No** — requires a geometrically thin, optically thick disc |

The underside arc — the image of the *bottom* face of the far side of the disc, appearing
below the shadow — is the signature feature of
[Luminet 1979, A&A 75, 228](#) *(no DOI; year, volume and page tool-verified)*, the first
correct thin-disc black hole image. It exists **only** if the disc is optically thick with
two distinct faces. An optically thin flow (§2.4, the physically likely case here) has no
underside; you see through it, and what looks like an "arc" is instead the `n = 2` image of
the same emitting volume.

---

## 2. The disc

### 2.1 Shakura–Sunyaev: the Newtonian baseline

[Shakura & Sunyaev 1973, A&A 24, 337](#) *(bibcode 1973A&A....24..337S; no DOI)* give, for
a steady geometrically thin disc with a zero-torque inner boundary at `r_in`:

```
σ T_eff⁴(r) = F(r) = (3 G M Ṁ) / (8π r³) · [ 1 - sqrt(r_in/r) ]
```

`T_eff` peaks at `r = (49/36) r_in = 1.3611 r_in`. **Regime of validity:** Newtonian
gravity, `H/r ≪ 1`, gas-pressure dominated, radiatively efficient, locally
blackbody-emitting, `Ṁ` steady, viscous stress ∝ pressure with dimensionless `α`. It says
nothing about spin, contains no relativistic corrections, and its `r_in` is a free
parameter — not the ISCO.

### 2.2 Novikov–Thorne / Page–Thorne: the relativistic thin disc

The relativistic replacement is Novikov & Thorne 1973 (in *Black Holes*, Les Houches)
*(identifier not verified)*, with the flux worked out by
[Page & Thorne 1974](https://doi.org/10.1086/152990). Do not transcribe their closed-form
`Q(r,a)`; implement the general form, which is exact and needs only the equatorial
circular-orbit functions of §3:

```
                Ṁ        (-dΩ/dr)        r
F(r) = ————————————————— · ———————————— ·  ∫   ( Ẽ - Ω L̃ ) (dL̃/dr') dr'
              4π r        (Ẽ - Ω L̃)²    r_ISCO
```

with `√(-g) = r` for the vertically integrated equatorial problem, and `Ẽ(r)`, `L̃(r)`,
`Ω(r)` from Bardeen–Press–Teukolsky (§3.2). `F` is the flux from **one face**, measured in
the local comoving frame.

**Inner boundary condition.** The integral starts at `r_ISCO` and the torque vanishes
there. That is the model's defining assumption, and it forces `F(r_ISCO) = 0` — the disc
goes *dark* at its inner edge, not brightest. The energy budget closes exactly:

```
∫ 4π r F(r) Ẽ(r) dr  =  Ṁ ( 1 - Ẽ_ISCO )
```

verified here to six digits for `a_* = 0, 0.5, 0.9, 0.998`. **[own arithmetic]** Note the
`Ẽ(r)` weight — it is the redshift factor that converts locally measured flux into energy
delivered to infinity; omitting it overstates the luminosity by 2% at `a_* = 0` and 14% at
`a_* = 0.998`.

**The relativistic corrections are large where it matters.** Ratio of Page–Thorne flux to
the Newtonian Shakura–Sunyaev flux with the same `r_in = 6M`, at `a_* = 0`:
**[own arithmetic]**

| `r/M` | 6.5 | 8 | 10 | 20 | 50 | 200 |
|---|---|---|---|---|---|---|
| `F_PT / F_SS73` | 0.139 | 0.367 | 0.504 | 0.700 | 0.812 | 0.901 |

The peak also moves out: `r(T_max) = 1.587 r_ISCO` for Page–Thorne at `a_* = 0`, versus
`1.361 r_in` for Shakura–Sunyaev. Using the Newtonian profile inside `~20 M` overstates
the inner disc brightness by factors of 2–7.

Vertical structure and the pressure/gravity balance receive further relativistic
corrections that the flux formula above does not capture
([Riffert & Herold 1995](https://doi.org/10.1086/176161)). If you want the *image* rather
than the *spectrum*, the pseudo-Newtonian potential of
[Paczyński & Wiita 1980, A&A 88, 23](#) *(no DOI; volume and page tool-verified)* is the
standard cheap stand-in for the ISCO's existence — but it is a fitting device, not a
metric, and it must not be used for ray tracing.

**Temperature in physical units.** Evaluated from the Page–Thorne flux with
`Ṁ_Edd ≡ L_Edd/(0.1 c²)` (a *convention*, always state it):

```
M = 50 M_sun :  L_Edd = 6.285e39 erg/s,  Ṁ_Edd = 6.99e19 g/s = 1.11e-6 M_sun/yr
```

| `a_*` | `r(T_max)/M` | `T_max` at `Ṁ_Edd` | `kT_max` | `η = 1-Ẽ_ISCO` |
|---|---|---|---|---|
| 0 | 9.52 | 4.08e6 K | 0.352 keV | 0.0572 |
| 0.5 | 6.65 | 5.43e6 K | 0.468 keV | 0.0821 |
| 0.9 | 3.45 | 9.11e6 K | 0.785 keV | 0.1558 |
| 0.998 | 1.59 | 1.77e7 K | 1.522 keV | 0.3210 |

Scaling: `T_max ∝ M^{-1/4} (Ṁ/Ṁ_Edd)^{1/4}`. **[own arithmetic]** A radiatively efficient
50 `M_sun` disc peaks in the soft X-ray, not the optical — if you render it as visible
light you are rendering a colour convention, and should say so. Full radial profiles for
four spins are in `disc-emission-profile.csv`.

The emitted spectrum is then a multicolour blackbody, `F_ν = ∫ B_ν(T_eff(r)) 2π r dr / D²`,
before any relativistic transfer. The transfer functions that convert this to an observed
spectrum for a Kerr disc were first computed by
[Cunningham 1975](https://doi.org/10.1086/154033), following the point-source treatment of
[Cunningham & Bardeen 1973](https://doi.org/10.1086/152223) — this is the paper your
redshift/beaming code should reproduce.

### 2.3 Where each disc model stops being valid

| Model | Valid when | First thing that breaks |
|---|---|---|
| Shakura–Sunyaev 1973 | `Ṁ ≲ 0.1 Ṁ_Edd`, `r ≫ 10 M`, gas-pressure dominated | Newtonian gravity; then radiation pressure inside a few tens of `M` |
| Novikov–Thorne / Page–Thorne 1974 | `H/r ≪ 1`, radiatively efficient, `0.01 ≲ Ṁ/Ṁ_Edd ≲ 0.3` | zero-torque assumption; radiation pressure; thermal/viscous instability of the radiation-pressure-dominated inner region |
| Slim disc | `Ṁ ~ 0.3–10 Ṁ_Edd` | advection becomes non-negligible; `H/r → 0.1–0.3` |
| Thick disc / ion torus | `Ṁ ≳ Ṁ_Edd` or ion-supported | radial pressure gradients matter; the "disc" is a torus with a funnel |
| ADAF / RIAF | `Ṁ ≲ α² Ṁ_Edd` | optically thin, two-temperature, `H/r ~ 1`, sub-Keplerian |

The slim-disc solution — a thin disc with advective cooling retained — is
[Abramowicz, Czerny, Lasota & Szuszkiewicz 1988](https://doi.org/10.1086/166683); its
appearance was worked out in
[Szuszkiewicz, Malkan & Abramowicz 1996](https://doi.org/10.1086/176830), and the
relativistic version with vertical structure in
[Sądowski, Abramowicz, Bursa et al. 2011, A&A 527, A17](https://doi.org/10.1051/0004-6361/201015256). The advection-dominated
branch is [Narayan & Yi 1994](https://doi.org/10.1086/187381),
[Narayan & Yi 1995a](https://doi.org/10.1086/175599),
[Narayan & Yi 1995b](https://doi.org/10.1086/176343), anticipated by the two-temperature
solution of [Shapiro, Lightman & Eardley 1976](https://doi.org/10.1086/154162),
[Ichimaru 1977](https://doi.org/10.1086/155314) and the ion tori of
[Rees, Begelman, Blandford et al. 1982](https://doi.org/10.1038/295017a0). The modern
synthesis is [Yuan & Narayan 2014](https://doi.org/10.1146/annurev-astro-082812-141003)
(a review — cited here for the regime map, not for any originating result).

**The zero-torque inner edge is a model choice, not a fact.** GRMHD simulations find
non-zero stress at the ISCO and emission from the plunging region
([Krolik & Hawley 2002](https://doi.org/10.1086/340760);
[Zhu, Davis, Narayan et al. 2012](https://doi.org/10.1111/j.1365-2966.2012.21181.x)). If
you want the inner disc to be *bright* rather than dark, that is defensible — but it is a
departure from Novikov–Thorne and should be labelled as such.

**RIAF, not thin disc, is what a real low-rate stellar-mass hole shows.** In the RIAF
regime the flow is geometrically thick (`H/r ~ 1`), optically thin, two-temperature
(`T_e ~ 10^9–10^11 K`), sub-Keplerian, and emits synchrotron plus its Compton
up-scatterings — not a blackbody. Visually this is a different object: no sharp disc
surface, no underside arc, you see *through* the flow, and the `n ≥ 2` images are
relatively prominent because they are not blocked by an optically thick sheet. This is the
regime of every EHT image
([EHT Collaboration 2019, ApJL 875, L1](https://doi.org/10.3847/2041-8213/ab0ec7);
[ApJL 875, L5](https://doi.org/10.3847/2041-8213/ab0f43)) and of the thick-disc image
survey of [Vincent, Gralla et al. 2022](https://doi.org/10.1051/0004-6361/202244339).

### 2.4 The regime that actually applies to a hole fed by a collisionless particle field

State this plainly in the project: **a 50 `M_sun` hole accreting from a collisionless
N-body field has no accretion disc and emits nothing.** A disc requires a dissipative
fluid that can shed angular momentum and radiate; collisionless particles do neither. What
your field supplies is *geodesic capture*: particles whose angular momentum falls below the
marginally bound value plunge in on nearly radial orbits.

The capture threshold follows from the marginally bound circular orbit. For `a = 0`,
`r_mb = 4M` and `L̃_mb = 4M` ([Bardeen, Press & Teukolsky
1972](https://doi.org/10.1086/151796), eq. 2.19; reproduced here). For a particle with
speed `v_∞ ≪ c` at infinity, capture requires `L < 4GM/c`, so

```
b_capture = 4 G M / (c v_∞)
σ_capture = 16 π (GM/c²)² (c/v_∞)²          [non-relativistic v_∞]
σ_capture = 27 π (GM/c²)²                    [ultrarelativistic limit; = π b_c²]
Ṁ = ρ σ_capture v_∞                          (collisionless, no gas pressure)
```

**[own arithmetic from BPT 1972 eq. 2.19]** This is *not* Bondi accretion
([Bondi 1952](https://doi.org/10.1093/mnras/112.2.195)) or Bondi–Hoyle–Lyttleton accretion
([Hoyle & Lyttleton 1939](https://doi.org/10.1017/S0305004100021150);
[Bondi & Hoyle 1944](https://doi.org/10.1093/mnras/104.5.273)) — those assume a gas with a
sound speed and pressure gradients. For a collisionless field the geodesic cross-section
above is the correct one, and it is larger than Bondi for cold slow particles.

Two honest options for the renderer:

- **Draw no disc.** The hole is a lensing object: it distorts the star field behind it and
  produces a dark region. Everything in §1 still applies, exactly, with no free parameters.
  This is the "draw less and have it be real" option and it is fully defensible.
- **Posit a gas component explicitly.** Add a dissipative fluid with a stated `Ṁ` and
  regime (thin disc or RIAF), label it as an added physical assumption, and use §2.2 or the
  RIAF prescription. Do not pretend the particle field is the gas.

If you do add gas, the circularization radius of captured material is
`r_circ = L̃²/(GM)` from the captured specific angular momentum, which your simulation
already knows exactly — that is the physically correct way to set the disc's outer edge,
and it is a *measurement* from your own dynamics rather than a tunable.

### 2.5 The three observer effects, separated

The three transformations are independently applicable, and the invariant that ties them is
Liouville's theorem for photons — `I_ν/ν³` is conserved along a ray in vacuum. Everything
else follows.

**(i) Gravitational redshift** — a property of position only, no velocity:

```
g_grav(r) = sqrt(-g_tt) = sqrt(1 - 2M/r)                         [Schwarzschild, static emitter]
g_grav(r,θ) = sqrt(1 - 2Mr/Σ)  ,  Σ = r² + a² cos²θ              [Kerr, static emitter, outside ergosphere]
```

**(ii) Special-relativistic Doppler and beaming** — a property of the emitter's velocity
relative to the *local static observer* (or, inside the ergosphere where no static observer
exists, the local ZAMO):

```
𝒟 = 1 / [ Γ ( 1 - v·n̂ ) ]      Γ = 1/sqrt(1-v²)
```

where `v` is the emitter's 3-velocity and `n̂` the photon direction, both measured in the
local static/ZAMO frame. For a Schwarzschild circular orbit,
`v = sqrt(M/r) / sqrt(1 - 2M/r)`, which equals exactly `0.5 c` at the ISCO.

**(iii) Light bending** — this does not multiply anything. It is the *map* from screen
pixel `(α, β)` to emission event `(r, θ, φ, k^μ)`, obtained by integrating the null
geodesic. It determines which emitter each pixel sees and with which `n̂`.

**Composition.** The total frequency-shift factor is the product:

```
g ≡ ν_obs / ν_em = g_grav(r) × 𝒟
```

exact, verified numerically here against the covariant expression
`g = 1/[u^t (1 - Ω λ)]` at the Schwarzschild ISCO for both approaching and receding
tangential rays, agreeing to six digits. **[own arithmetic]** Worked numbers at `r = 6M`,
`a_* = 0`, edge-on:

| | `g_grav` | `𝒟` | `g` | bolometric `g⁴` |
|---|---|---|---|---|
| approaching limb | 0.8165 | 1.7321 | 1.4142 | 4.000 |
| receding limb | 0.8165 | 0.5774 | 0.4714 | 0.0494 |

The approaching/receding **bolometric brightness ratio at the ISCO is exactly 81** for
Schwarzschild (`= ((1+v)/(1-v))⁴` at `v = 1/2`). **[own arithmetic]** This is the single
biggest visual asymmetry in the image, and it is Doppler beaming, not lensing.

**The transfer rule.** Apply the invariant, not an ad-hoc scaling:

```
I_ν_obs(ν_obs) = g³ · I_ν_em(ν_obs / g)            monochromatic
I_obs          = g⁴ · I_em                          bolometric (integrated over frequency)
```

([Cunningham 1975](https://doi.org/10.1086/154033) uses exactly this; the
`I_ν/ν³` invariance is Liouville's theorem, standard in Misner, Thorne & Wheeler,
*Gravitation* §22.6 *(book, no identifier)*, and stated in this form in
[Gralla, Holz & Wald 2019](https://doi.org/10.1103/PhysRevD.100.024018)).

**Two things to get right in the implementation.** First, **lensing magnification needs no
extra Jacobian**: if you trace one ray backward per pixel and apply `I_obs = g³ I_em`, the
magnification is already in the geometry — multiplying by an extra magnification factor
double-counts. Second, for an optically thin flow the correct quantity is the integral
along the ray of the emissivity with the *local* `g` at each point,
`I_obs = ∫ g³ j_ν(ν_obs/g) ds_proper`, not a single surface value; a single `g` per pixel
is correct only for an optically thick surface.

A cheap and useful closed-form bending approximation exists if you cannot afford geodesics
everywhere: [Beloborodov 2002](https://doi.org/10.1086/339511) showed that for
Schwarzschild, `1 - cos α = (1 - cos ψ)(1 - r_s/r)`, relating the local emission angle `α`
to the angle `ψ` between the radius vector and the line of sight. It is exact in the
weak-field limit and remains a percent-level approximation down to a few `r_s`; it fails
entirely near `b_c`, so it cannot produce photon rings.

---

## 3. Spin

### 3.1 The verdict on `Ω(r) = 1/(r^1.5 + a)`, `a = 0.5`

**It is not a convenient fit. It is the exact Kerr law — but you are almost certainly
feeding it the wrong `r`.** Bardeen, Press & Teukolsky 1972, eq. (2.16), for circular
equatorial geodesics in Kerr:

```
Ω(r) = ± M^{1/2} / ( r^{3/2} ± a M^{1/2} )
```

With `M = 1` and `a` in units of `M`, this is *literally* `Ω = 1/(r^{3/2} + a_*)` for
prograde orbits. So the functional form is right and `a = 0.5` corresponds exactly to a
**prograde dimensionless spin `a_* = 0.5`** — a perfectly ordinary astrophysical value.

The problem is dimensional. Restoring the mass:

```
Ω(r) = M^{1/2} / ( r^{3/2} + a_* M^{3/2} )        prograde
Ω(r) = -M^{1/2} / ( r^{3/2} - a_* M^{3/2} )       retrograde
```

For your typical formed hole, `M = 0.08585` sim, so `M^{1/2} = 0.29300` and
`M^{3/2} = 0.025153`. **[own arithmetic]** Two consequences if `r` is in sim units and the
formula is used as written:

- The overall frequency is wrong by a factor `M^{1/2} ≈ 0.293` at large `r`. ⛔ **CORRECTED
  2026-08-31 16:10 — this bullet originally said "3.4× too slowly … asymmetry far too weak",
  which is inverted.** `Ω_correct = M^{1/2} Ω_code` at large `r`, so the coded law is
  **3.41× too FAST** and the Doppler asymmetry is far too **STRONG**. Measured ratio
  `Ω_code/Ω_correct`: **1.50** at the ISCO (`r = 0.5151`), **2.30** at `r = 1`, **3.37** at
  `r = 11.70` (the field's half-mass radius), tending to `1/M^{1/2} = 3.41`. **[own arithmetic]**
- 🚨 **Second-order problem, larger than the first:** the law is applied *per particle about a
  single fixed axis through the whole field*, not about a hole. Against the field's own circular
  speed at the half-mass radius it gives `β_code = 0.289 c` where the real value is
  `v_circ = 0.146 c` — **2.0× too fast** — so the whole field is beamed as if it rotated at twice
  its actual speed. Fixing the dimensional factor does not fix this; the law has to be evaluated
  per hole, about that hole's own spin axis, for `r ≥ r_ISCO` of that hole.
- The constant 0.5 implies `a_* M^{3/2} = 0.5`, i.e. `a_* = 0.5/0.025153 = 19.9`. That is
  twenty times over-extremal — a naked singularity, not a black hole. **[own arithmetic]**

Two further points:

- `Ω` here is the **Boyer–Lindquist coordinate angular velocity** `dφ/dt` of a *circular
  geodesic*. It is only valid for `r ≥ r_ISCO`. Inside the ISCO there are no circular
  orbits; matter plunges, and its `Ω` is set by the conserved `Ẽ`, `L̃` it carried through
  the ISCO, approaching the frame-dragging value `Ω_H = a/(r_+² + a²)` at the horizon. Using
  the circular-orbit law inside the ISCO is unphysical.
- **A single fixed spin axis is wrong** the moment you have more than one hole, or mergers.
  Each hole carries its own spin vector `J⃗`; the Doppler axis, the shadow's flattening
  direction, and the frame-dragging sense all follow *that* hole's `J⃗`. After a merger the
  remnant's spin is neither parent's.

### 3.2 The correct Kerr expressions (all from Bardeen, Press & Teukolsky 1972)

Units of `M`; upper sign prograde, lower retrograde; `a ≡ a_* M`.

```
horizon              r_+   = M ( 1 + sqrt(1 - a_*²) )
equatorial ergosphere r_E  = 2M                                    (independent of spin)
horizon angular velocity  Ω_H = a / (r_+² + a²)

photon circular orbit  r_ph = 2M { 1 + cos[ (2/3) arccos(∓ a_*) ] }        BPT (2.18)
marginally bound       r_mb = 2M ∓ a + 2 sqrt( M ) sqrt( M ∓ a )          BPT (2.19)

ISCO                   Z₁ = 1 + (1-a_*²)^{1/3} [ (1+a_*)^{1/3} + (1-a_*)^{1/3} ]
                       Z₂ = sqrt( 3 a_*² + Z₁² )
                       r_ISCO = M [ 3 + Z₂ ∓ sqrt( (3-Z₁)(3+Z₁+2Z₂) ) ]   BPT (2.21)

Ω(r)  = ± M^{1/2} / ( r^{3/2} ± a M^{1/2} )                                BPT (2.16)
Ẽ(r)  = ( 1 - 2M/r ± a M^{1/2} / r^{3/2} ) / sqrt( 1 - 3M/r ± 2 a M^{1/2}/r^{3/2} )
L̃(r)  = ± (M r)^{1/2} ( 1 ∓ 2 a M^{1/2}/r^{3/2} + a²/r² ) / sqrt( 1 - 3M/r ± 2 a M^{1/2}/r^{3/2} )

radiative efficiency  η = 1 - Ẽ(r_ISCO)
```

Checks reproduced here: `a_* = 0` gives `r_ISCO = 6M`, `r_ph = 3M`,
`Ẽ_ISCO = sqrt(8/9) = 0.942809`, `η = 0.05719`; `a_* → 1` prograde gives
`r_ISCO → M`, `r_ph → M`, `η → 1 - 1/√3 = 0.42265`; `a_* → 1` retrograde gives
`r_ISCO → 9M`, `r_ph → 4M`. **[own arithmetic]**

### 3.3 Spin table

Computed from the expressions above. Full version, with retrograde branches, shadow
geometry, critical exponents and physical frequencies for `M = 50 M_sun`, in
`kerr-spin-table.csv`. **[own arithmetic]**

| `a_*` | `r_+/M` | `r_ph/M` | `r_ISCO/M` | `Ω_ISCO M` | `f_ISCO` (50 M☉) | `η` | `b_c/M` pro | `b_c/M` retro |
|---|---|---|---|---|---|---|---|---|
| 0 | 2.0000 | 3.0000 | 6.0000 | 0.06804 | 43.97 Hz | 0.0572 | 5.1962 | 5.1962 |
| 0.1 | 1.9950 | 2.8822 | 5.6693 | 0.07354 | 47.52 Hz | 0.0606 | 4.9931 | 5.3934 |
| 0.2 | 1.9798 | 2.7592 | 5.3294 | 0.07998 | 51.69 Hz | 0.0646 | 4.7832 | 5.5857 |
| 0.3 | 1.9539 | 2.6300 | 4.9786 | 0.08765 | 56.65 Hz | 0.0694 | 4.5652 | 5.7735 |
| 0.4 | 1.9165 | 2.4934 | 4.6143 | 0.09697 | 62.67 Hz | 0.0751 | 4.3371 | 5.9576 |
| 0.5 | 1.8660 | 2.3473 | 4.2330 | 0.10859 | 70.18 Hz | 0.0821 | 4.0963 | 6.1382 |
| 0.6 | 1.8000 | 2.1889 | 3.8291 | 0.12357 | 79.86 Hz | 0.0912 | 3.8385 | 6.3156 |
| 0.7 | 1.7141 | 2.0133 | 3.3931 | 0.14388 | 92.98 Hz | 0.1036 | 3.5568 | 6.4903 |
| 0.8 | 1.6000 | 1.8111 | 2.9066 | 0.17375 | 112.28 Hz | 0.1221 | 3.2373 | 6.6625 |
| 0.9 | 1.4359 | 1.5579 | 2.3209 | 0.22544 | 145.69 Hz | 0.1558 | 2.8444 | 6.8323 |
| 0.95 | 1.3122 | 1.3863 | 1.9372 | 0.27425 | 177.23 Hz | 0.1901 | 2.5822 | 6.9164 |
| 0.98 | 1.1990 | 1.2395 | 1.6140 | 0.32997 | 213.25 Hz | 0.2339 | 2.3600 | 6.9666 |
| 0.998 | 1.0632 | 1.0739 | 1.2370 | 0.42127 | 272.25 Hz | 0.3210 | 2.1109 | 6.9967 |
| 0.9999 | 1.0141 | 1.0164 | 1.0785 | 0.47170 | 304.84 Hz | 0.3820 | 2.0246 | 6.9998 |

`f_ISCO = Ω_ISCO/(2π)` converted with `GM_sun/c³ = 4.925490947e-6 s` (IAU 2015 nominal
`GM_sun`). To get sim-unit frequencies instead, multiply the tabulated `Ω_ISCO M` by
`1/M_hole`.

The `η` column is the **Novikov–Thorne** efficiency: the fraction of rest mass radiated by
a zero-torque thin disc extending to the ISCO. It is not the fraction radiated by a RIAF
(much smaller, and rate-dependent) and it is not a property of the hole alone.
`a_* = 0.998` is singled out because [Thorne 1974](https://doi.org/10.1086/152991) showed
that photon capture from a radiating thin disc limits spin-up to that value — a limit that
applies to *radiatively efficient disc* accretion and **does not apply** to collisionless
capture.

### 3.4 If spin comes from the particle field, compute it, don't set it

Your simulation already knows the angular momentum of every captured particle. The
physically honest route is to accumulate it:

```
M_hole ← M_hole + Σ m_i (captured)          J⃗_hole ← J⃗_hole + Σ L⃗_i (captured)
a_*  =  |J⃗_hole| / M_hole²        (geometrized; clamp to |a_*| ≤ 1)
spin axis  =  Ĵ_hole
```

Then feed `a_*` into §3.2 and `Ĵ` into the shadow orientation and Doppler axis. Two caveats
to state in the code: (a) collisionless capture from an isotropic field has no Thorne limit
and can numerically drive `a_* > 1`, so the clamp is load-bearing and hitting it is a
signal that the capture prescription needs review; (b) the mass added should be the
particle's conserved energy `Ẽ_i m_i`, not `m_i`, if the accretion is to conserve energy in
the strong field — for slow particles from a cold field the difference is small, but for
a relativistic field it is not.

---

## 4. What is honest at your resolution

### 4.1 The resolution budget

⛔ **CORRECTED 2026-08-31 16:10 — this whole section originally used `ε = 0.031`, a stale value
from a code comment. The live fine cell is `ε = 0.0625` (`renderer.mm:2824`,
`2·kAmrFineExtent/N = 2·4/128`; AMR default ON). Every eps-relative figure below has been
recomputed. There are also TWO live softening lengths — coarse `1.0` sim outside the AMR box,
fine `0.0625` inside `±4.0` sim where the hole sits. Against the COARSE value the board's "all
inside one softening length" is TRUE. See `SCIENCE_2026-08-31_ADDENDUM_01.md`.**

With the fine cell size and Plummer softening `ε = 0.0625` sim
and a formed hole at `M_hole = 0.08585` sim, the characteristic radii are **not** all
inside one softening length: **[own arithmetic]**

| | sim units | fine `ε = 0.0625` | coarse `ε = 1.0` |
|---|---|---|---|
| horizon `2M` | 0.1717 | **2.75** | 0.17 |
| photon sphere `3M` | 0.2576 | **4.12** | 0.26 |
| critical curve `3√3 M` | 0.4461 | **7.14** | 0.45 |
| ISCO `6M` | 0.5151 | **8.24** | 0.52 |
| `n=2` lensing ring width `1.153 M` | 0.0990 | **1.58** | 0.10 |
| `n=3` photon ring width `0.040 M` | 0.00344 | **0.055** | 0.003 |

So a *grown* hole is marginally resolved against the fine cell — the horizon spans about two
and three quarter softening lengths, and against the coarse cell it is not resolved at all
(`0.17 ε`). The **seed** is a different story. A hole whose horizon equals one fine softening
length has geometrized `M = ε/2 = 0.03125` sim, which is a physical mass of
**`0.0625 × M_field = 37,142 M_sun`** `= 6.25%` of the field and 36.4% of the formed hole's mass.
⛔ **CORRECTED 2026-08-31 16:30 — first written as `18,571 M_sun`, which is wrong by a factor 2.**
The conversion is `M/M_field = r_s/r_s(M_field) = ε/1`, so the factor 2 is already spent turning
`r_s` into `M`; multiplying the geometrized `ε/2` by `M_field` spends it twice. `18,571 M_sun` is
`3.125%` of the field, which contradicts the `6.25%` in the same sentence. For a 50 `M_sun` seed to have `r_s > ε` you would need
`M_field < 800 M_sun` — with 10⁷ particles that is `8×10⁻⁵ M_sun` per particle.
**[own arithmetic]** For any astrophysically sensible field mass, **a newly seeded hole's
entire horizon is far inside a single softening length**, and it grows into marginal
resolution over its accretion history. The verdicts below therefore depend on the hole's
current mass, and the code should branch on `2M_hole/ε`.

Full table in `resolution-verdict-table.csv`.

### 4.2 The key structural point: dynamics resolution ≠ transport resolution

The particle field's softening limits the **matter distribution** you can trust. It does
not limit the **null geodesic transport**, because the geodesics are integrated in the
analytic Kerr (or Schwarzschild) metric of a point mass, on the screen's own angular grid.
The grid does not enter. Your own `b_c` result — 8e-15 agreement with `3√3M` — is proof of
exactly this: you already computed a horizon-scale quantity to machine precision on a
128³ grid, because the grid was not involved.

This is not a workaround; it is how every production black hole imaging code is built. GRMHD
codes evolve the fluid on a coarse grid and then hand the fluid state to a *separate*
ray-tracing/radiative-transfer stage that integrates geodesics analytically or with its own
step control: `ipole` ([Mościbrodzka & Gammie 2018, arXiv:1712.03057](https://arxiv.org/abs/1712.03057)),
`grtrans` ([Dexter 2016](https://doi.org/10.1093/mnras/stw1526)),
`RAPTOR` ([Bronzwaer, Davelaar, Younsi et al. 2018](https://doi.org/10.1051/0004-6361/201732149),
[2020](https://doi.org/10.1051/0004-6361/202038573)), and — most relevant to you, since it
is GPU-native — `GRay` ([Chan, Psaltis & Özel 2013](https://doi.org/10.1088/0004-637X/777/1/13))
and `Odyssey` ([Pu, Yun, Younsi et al. 2016](https://doi.org/10.3847/0004-637X/820/2/105)). The
convention that the imaging stage is decoupled from the dynamics stage is documented across
the whole EHT code comparison ([Porth, Chatterjee, Narayan et al. 2019](https://doi.org/10.3847/1538-4365/ab29fd)).

So the honest split is:

- **Geometry from the metric, at screen resolution.** Legitimate at any hole mass.
- **Brightness from the particle field, outside `r_s` + one fine `ε`** — i.e. `r > 0.234` sim for
  the formed hole. Not legitimate inside that. ⛔ **CORRECTED: this originally read "`≳ 2–3 ε`",
  which at the live `ε = 0.0625` gives `0.1875 sim = 2.18 M` and so would exclude the horizon
  itself.** The exclusion must be stated relative to `r_s`, not as a multiple of `ε`.

### 4.3 Feature-by-feature verdict

**Shadow / dark central region — DRAW IT.** It is a pure transport result: trace rays
backward, mark the ones that reach `r_+`. Resolution argument: no field sampling is
involved. At screen resolution `Δb`, the dark region's edge is resolved whenever
`b_c > few × Δb`, which for a formed hole (`b_c = 7.14` fine `ε`) is easy. Do *not* draw it as a
disc of radius `b_c` — draw it as "no emission reached this pixel" (§1.2).

**Critical curve position — DRAW IT (as geometry, not as a bright line).** Also pure
transport. But it is a mathematical locus, not a luminous object; it becomes visible only
because emission piles up near it, and how much it piles up is an emission question.

**Lensed far side of the disc (`n = 2` lensing ring) — DRAW IT if you have a disc.** Its
width is `1.153 M = 3.2 ε` for a formed hole, so the *geometry* is resolved on screen. What
you cannot claim is its brightness from the particle field, because the emitting material
sits at `r = 5–30 M`, i.e. 8–48 `ε` — comfortably outside the softening scale. If you
posit a gas disc (§2.4) with an analytic `T_eff(r)` from §2.2 and transport it with §2.5,
the lensing ring is honest, and it is the correct bright arc.

**Underside arc — DRAW IT only with an optically thick disc.** It is not a lensing artefact
you can add; it is the image of the far disc's lower face. If your emission model is
optically thin (which a particle field naturally is), there is no underside and drawing one
is a fabrication. Verdict: draw it if and only if you have committed to an optically thick
geometrically thin disc, and then it comes out of the transport for free.

**`n ≥ 3` photon subrings — DO NOT DRAW.** Two independent arguments, both decisive.
First, screen resolution: the `n = 3` ring is `0.040 M` wide. At a field of view of
`20 r_s = 40 M` across 1080 pixels, that is `0.037 M` per pixel — the entire `n = 3` ring
is **about one pixel**, and `n = 4` is `1.4e-3 M`, i.e. `0.04` pixel. **[own arithmetic]**
Second, and more important, flux: per GHW the `n ≥ 3` orders together carry a fraction of a
per cent of the image flux, and the divergence at `b_c` is only logarithmic. A visible
bright ring at `b_c` is therefore *anti-physical* — it is brighter than the real thing.
The honest treatment: let the transport produce whatever sub-pixel enhancement it produces,
integrate it into the pixel, and do not add a ring primitive. If you ever want them, the
correct statement is the analytic one: successive orders sit at
`b_n - b_c ∝ e^{-π n}` with flux ratio `e^{-π}`, delay `3√3 π M`, alternating sides.

**Spin-dependent shadow shape — DRAW IT.** Transport again, and the effect is large enough
to see: the horizontal width shrinks 12% and the centroid shifts `2.443 M`, which for a formed
hole is `0.210` sim `= 6.8 ε`, between `a_* = 0` and `a_* = 0.998`. Note the vertical extent does not change at all (§1.5) — if
your render shows the shadow shrinking in both directions with spin, it is wrong.

**Doppler asymmetry of the ring — DRAW IT, with the correct `Ω`.** The 81:1 bolometric
ratio at the ISCO (§2.5) is the dominant visual asymmetry and needs no field resolution: it
depends on the orbital velocity field, which is analytic (§3.2). This is where fixing the
`Ω(r)` scaling (§3.1) buys the most visible improvement.

**Emission structure inside `r ≲ 3 ε ≈ 0.093 sim ≈ 1.1 M`** — for a formed hole that is
inside the horizon, so nothing to draw. For a *seed* hole, `3ε` is many times the horizon
radius, and **any** structure you draw there is softening artefact. Verdict for seed-mass
holes: render them as a lensing point mass with a shadow computed from the metric, and no
emission structure at all.

**Accretion luminosity from captured particles — DO NOT DRAW as a disc.** The capture rate
is computable (§2.4) and physically meaningful; the *radiation* is not, because the
collisionless field has no emission mechanism. If you want a brightness cue tied to
accretion, tie it to the *capture rate* explicitly and label it as an indicator, not as
radiation.

---

## 5. Model-dependent, convention, and unsettled

### Measurement, model, and convention — the separations that matter here

- **Spacetime geometry** (`r_+`, `r_ph`, `r_ISCO`, `b_c`, the critical curve, `γ`, `δ`,
  `τ`): exact consequences of the Kerr metric. Not model-dependent. Verified against
  observation only at the ~10% level, by the EHT ring diameters
  ([EHT 2019 ApJL 875, L6](https://doi.org/10.3847/2041-8213/ab1141);
  [EHT 2022 ApJL 930, L12](https://doi.org/10.3847/2041-8213/ac6674)) and by
  black hole ringdown frequencies
  ([Berti, Cardoso & Will 2006](https://doi.org/10.1103/PhysRevD.73.064030) for the
  formalism).
- **The disc structure** (`F(r)`, `T_eff(r)`, `η`): model. Change the model, change the
  numbers. Named alternatives below.
- **`Ṁ_Edd = L_Edd/(0.1 c²)`**: convention. Some authors use `L_Edd/c²`, differing by 10×.
  Always state which.
- **`GM_sun/c³ = 4.925490947e-6 s`**: convention (IAU 2015 nominal solar mass parameter),
  not a measurement of any particular star.
- **`α` viscosity**: parametrization, not a theory. The underlying angular momentum
  transport is the magnetorotational instability, and `α` is a fit to its outcome.

### What is model-dependent, and what changes under the alternative

| Quantity | Model assumed | Alternative | What changes |
|---|---|---|---|
| `F(r)`, `T_eff(r)` | Novikov–Thorne zero-torque at ISCO | non-zero ISCO stress (Krolik & Hawley 2002; Zhu et al. 2012) | inner disc becomes bright rather than dark; `η` rises; the "dark gap" inside the lensing ring closes |
| `η = 1 - Ẽ_ISCO` | radiatively efficient thin disc | RIAF/ADAF | `η` drops by 1–3 orders of magnitude and becomes `Ṁ`-dependent |
| Disc emits a blackbody | optically thick, LTE | optically thin synchrotron (RIAF) | spectrum, image morphology, and the visibility of `n ≥ 2` images all change qualitatively |
| Sharp inner edge at `r_ISCO` | thin disc | slim/thick disc, `H/r ~ 0.1–1` | the "edge" becomes a smooth transition; the underside arc disappears |
| Underside arc exists | optically thick two-faced disc | optically thin flow | no underside; the arc is replaced by the `n=2` image of the same volume |
| Single spin axis | one isolated hole | multiple holes / post-merger | orientation of shadow flattening, Doppler axis, and frame dragging all differ per hole |
| `a_* ≤ 0.998` | radiation-limited disc accretion (Thorne 1974) | collisionless capture | no such limit; `a_*` must be clamped at 1 by hand |
| Kerr metric itself | general relativity, vacuum, no hair | alternative compact objects | shadow size/shape shifts; constrained at the few-tens-of-per-cent level (Johannsen & Psaltis 2010; [Kocherlakota, Rezzolla, Falcke et al. 2021](https://doi.org/10.1103/PhysRevD.103.104047); [Vincent, Wielgus et al. 2021](https://doi.org/10.1051/0004-6361/202037787)) |

### What the literature does not settle

- **The location and nature of the inner edge of a real accretion disc.** Whether the
  zero-torque condition holds, how much the plunging region radiates, and how sharp the
  transition is are all actively contested. Krolik & Hawley 2002 argued the question is
  ill-posed as usually asked; Zhu et al. 2012 found meaningful plunging-region emission.
  What would settle it: spatially resolved inner-disc imaging at horizon scale in a system
  known to be in the thin-disc regime — no current instrument can do this for a
  stellar-mass hole.
- **Whether the photon ring has been detected.** The `n = 2` and `n ≥ 3` structure is a
  clean prediction, and the interferometric signature is well specified (Johnson et al.
  2020), but whether the 2017 EHT data already constrain it, and whether the ring diameter
  can test general relativity rather than just measure mass, is disputed — see
  [Gralla 2021](https://doi.org/10.1103/PhysRevD.103.024023) for the sceptical case and
  Gralla, Lupsasca & Marrone 2020 for what a decisive measurement would require. What would
  settle it: a space-baseline VLBI measurement of the visibility ringing.
- **Whether stellar-mass black holes ever accrete in a state where the Novikov–Thorne
  profile is quantitatively right.** The thin-disc regime is narrow and the observed
  soft-state spectra are fitted with it routinely, but the inferred spins depend on the
  inner-edge assumption above.
- **What sets `α`, and whether a single `α` describes a disc at all.** Unsettled; the MRI
  saturation level depends on field topology and net flux.
- **The spin distribution and spin evolution of holes grown by collisionless capture.** I
  found no literature that treats this case for the purpose of image generation. The
  capture cross-section is standard; the resulting spin history is not a solved problem
  in the form your simulation poses it. Treat §3.4 as a defensible construction from
  first principles, not as a cited result.
- **Softening prescription for a point mass embedded in a softened particle field.** The
  softening literature ([Merritt 1996](https://doi.org/10.1086/117980);
  [Dehnen 2001](https://doi.org/10.1046/j.1365-8711.2001.04237.x);
  [Power, Navarro et al. 2003](https://doi.org/10.1046/j.1365-8711.2003.05925.x)) optimizes force
  accuracy for a *distribution*, not for a massive point sink inside it. The sink-particle
  approach used in star formation (Bate, Bonnell & Price 1995, MNRAS 277, 362 —
  *identifier not verified*) and the sub-grid black hole accretion of
  [Springel, Di Matteo & Hernquist 2005](https://doi.org/10.1111/j.1365-2966.2005.09238.x)
  are the nearest established practice, and both accept that everything inside the sink
  radius is unresolved by construction. Nothing in that literature justifies rendering
  structure inside the softening length.

---

## 6. Files

- `kerr-spin-table.csv` — 14 spins × 29 columns: horizon, ergosphere, photon orbits
  (both senses), marginally bound orbit, ISCO (both senses), `Ẽ`, `L̃`, `Ω`, `η`,
  critical impact parameters, equatorial Lyapunov exponents and demagnification factors,
  half-orbit delay in `M` and in ms at 50 `M_sun`, and shadow areal radius / width /
  height / centroid shift at `i = 90°, 60°, 30°, 0°`.
- `schwarzschild-transfer-function.csv` — `r_n(b)` for `n = 1, 2, 3` and `dr_n/db`,
  face-on Schwarzschild.
- `disc-emission-profile.csv` — Page–Thorne `F(r)` (dimensionless and as `T_eff` for
  50 `M_sun` at `0.1 Ṁ_Edd`), with `Ẽ`, `L̃`, `Ω`, local orbital speed, and the
  Shakura–Sunyaev comparison, for `a_* = 0, 0.5, 0.9, 0.998`.
- `resolution-verdict-table.csv` — characteristic radii and ring widths in units of the
  softening length, versus `M_hole/M_field`.
- `black-hole-appearance-figure.png` — Kerr critical curves versus spin and inclination;
  Schwarzschild transfer functions; Page–Thorne temperature profiles; radii and efficiency
  versus spin.
