<!-- SCIENCE TRACK — Claude Science project SPACE SYNTH X
     Produced 2026-08-31. Lands per SCIENCE_PROMPTS_2026-08-31.md §"HOW THE OUTPUT COMES BACK":
     a cited doc, never pasted into src/. THIS IS A CLAIM UNTIL CHECKED AGAINST THE LITERATURE.
     Nothing here is fitted to SPACE SYNTH output. Primary references are inline.
     Prompt: P2 — the three merger signatures. Feeds: FABLE F3.
     Citation verification: 175 of 184 identifiers (95%) tool-verified; 9 marked unverified in text.
-->

# The Three Merger Signatures

**Reference for SPACE SYNTH — what a star+star, star+BH and BH+BH merger actually
looks like, and over what timescale.**

Equations first. Every relation carries its source and its regime of validity.
Numbers labelled **[arith]** are my own arithmetic from the cited equation, not a
quoted result. Numbers labelled **[NR]** come from numerical-relativity
simulations, **[obs]** from measurement, **[fit]** from a published fitting formula.

---

## 0. Conventions and the unit bridge

### 0.1 Constants used throughout

| quantity | value | source |
|---|---|---|
| $G$ | $6.67430\times10^{-8}$ cm³ g⁻¹ s⁻² | CODATA 2018 |
| $c$ | $2.99792458\times10^{10}$ cm s⁻¹ | exact (SI definition) |
| $\mathcal{GM}_\odot$ | $1.3271244\times10^{26}$ cm³ s⁻² | IAU 2015 Res. B3 nominal |
| $R_\odot$ | $6.957\times10^{10}$ cm | IAU 2015 Res. B3 nominal |
| $L_\odot$ | $3.828\times10^{33}$ erg s⁻¹ | IAU 2015 Res. B3 nominal |
| $\sigma_T$ | $6.6524587\times10^{-25}$ cm² | CODATA |

### 0.2 Geometrized conversions

$$\frac{GM_\odot}{c^2} = 1.476625\times10^{5}\ \mathrm{cm} = 1.4766\ \mathrm{km},
\qquad \frac{GM_\odot}{c^3} = 4.925491\times10^{-6}\ \mathrm{s}$$

With $G=c=1$, $r_s = 2M$. For the seed mass:

| | $M$ (geom. length) | $r_s = 2M$ | $M$ (geom. time) |
|---|---|---|---|
| 50 M☉ (seed) | 73.83 km | **147.70 km** = $1.4770\times10^7$ cm | 0.2463 ms |
| 95.162 M☉ (50+50 remnant) | 140.5 km | **281.04 km** | 0.4687 ms |

Other useful scalings:

$$L_{\rm Edd} = \frac{4\pi G M m_p c}{\sigma_T} = 1.257\times10^{38}\left(\frac{M}{M_\odot}\right)\ \mathrm{erg\ s^{-1}},
\qquad \frac{c^5}{G} = 3.6283\times10^{59}\ \mathrm{erg\ s^{-1}}$$

### 0.3 Mapping into SPACE SYNTH units

One simulation length unit is $L_{\rm sim} = r_s(M_{\rm field}) = 2GM_{\rm field}/c^2$.
Therefore for any length $\ell$ expressed as a multiple of the *hole's own* Schwarzschild radius,

$$\boxed{\ \frac{\ell}{L_{\rm sim}} = \left(\frac{\ell}{r_s(M_{\rm BH})}\right)\times\frac{M_{\rm BH}}{M_{\rm field}}\ }
\qquad
\boxed{\ \frac{t}{L_{\rm sim}/c} = \frac{t}{9.851\times10^{-6}\,\mathrm{s}}\times\frac{M_\odot}{M_{\rm field}}\ }$$

Worked example for a 50 M☉ hole disrupting a 1 M☉, 1 R☉ star (§2), showing how the
whole event scales *out of* your field of view as the total field mass grows: **[arith]**

| $M_{\rm field}$ | $r_s(50\,M_\odot)$ | tidal radius $r_t$ | debris disc $a_{\rm min}$ |
|---|---|---|---|
| $10^4$ M☉ | $5.0\times10^{-3}$ | 86.8 | 160 |
| $10^5$ M☉ | $5.0\times10^{-4}$ | 8.68 | 16.0 |
| $10^6$ M☉ | $5.0\times10^{-5}$ | 0.868 | 1.60 |
| $2\times10^6$ M☉ | $2.5\times10^{-5}$ | 0.434 | 0.799 |

(all in $L_{\rm sim}$). **This is the single most important geometric fact in this
document**: a tidal disruption by a stellar-mass hole is a *stellar-scale* event
happening around a *kilometre-scale* object. If one length unit is the
Schwarzschild radius of the whole field, the horizon is sub-pixel and the debris
stream is order-unity in size.

---

## 1. CASE A — star + star

### 1.1 What the class is, and the correction you asked for

The class name in the literature is **luminous red nova (LRN)**, also
"red transient", "intermediate-luminosity red transient", or
"common-envelope-ejection transient". Formal identification of LRNe as
common-envelope events is Ivanova et al. (2013, *Science* 339, 433),
who proposed a physical model in which the emission from matter ejected in a
common-envelope event is controlled by a recombination front as the matter cools,
and matched its timescales, energies, colours, light-curve shapes, ejection
velocities and event rate to the red-transient class.

**Your belief, corrected.**

- **V1309 Sco is the reference case, and it is stronger than you think.** Tylenda
  et al. (2011, *A&A* 528, A114) had OGLE photometry of the *progenitor*
  from August 2001, seven years before the September 2008 outburst. The progenitor
  was a **contact binary with a ~1.4 d orbital period that was measurably
  decreasing**, with an evolving light curve; the violent phase began in March
  2008, half a year before discovery. This is the only case where a merger was
  watched *going in*. Stępień (2011, *A&A* 531, A18) modelled the progenitor
  binary's pre-merger evolution.
- **V838 Mon is the prototype but NOT a confirmed merger.** Its merger
  interpretation is a *model inference*, argued by elimination: Tylenda & Soker
  (2006, *A&A* 451, 223) showed that a thermonuclear runaway on a white dwarf
  and a He-shell flash in a post-AGB star both predict the object *heats up*
  before declining, whereas V838 Mon and its siblings (M31 RV, V4332 Sgr) declined
  as cool giants/supergiants. They concluded merger is the most promising model.
  Competing scenarios were published and are not formally excluded: a
  main-sequence star swallowing a low-mass companion (Soker & Tylenda 2003,
  *ApJ* 582, L105) and an expanding giant swallowing planets (Retter & Marom 2003,
  *MNRAS* 345, L25). No pre-outburst binary signature exists for V838 Mon
  comparable to V1309 Sco's.
- **The famous V838 Mon images are a light echo, not the ejecta.** Bond et al.
  (2003, *Nature* 422, 405) reported circumstellar light echoes — outburst light
  scattering off *pre-existing* dust. If you draw expanding nested shells around a
  star+star merger because you have seen those HST images, **you are drawing a
  scattering screen, not the merger**. The echo geometry was used to get a
  geometric distance of $6.1\pm0.6$ kpc (Sparks et al. 2008, *AJ* 135, 605).
- **The class is now ~15 objects, not 2.** Galactic/local: M31 RV (1988),
  V4332 Sgr (1994; Martini et al. 1999, *AJ* 118, 1034), V838 Mon (2002),
  V1309 Sco (2008), OGLE-2002-BLG-360 (recovered as a red transient by Tylenda
  et al. 2013, *A&A* 555, A16), CK Vul / Nova 1670 (Kamiński et al. 2021,
  *A&A* 646, A1). Extragalactic: NGC 4490-2011OT1, M101 OT2015-1, SNhunt248
  (Pastorello et al. 2019, *A&A* 630, A75), M31LRN 2015 (MacLeod et al. 2017,
  *ApJ* 835, 282; Blagorodnova et al. 2017 for M101), AT 2018bwo (Blagorodnova
  et al. 2021, *A&A* 653, A134), AT 2019zhd (Pastorello et al. 2021, *A&A* 646,
  A119), AT 2021blu and companions (Pastorello et al. 2023, *A&A* 671, A158),
  plus the ZTF-CLU systematic sample of 8 LRNe (Karambelkar et al. 2023,
  *ApJ* 948, 137).

### 1.2 The light curve — shape, timescale, luminosity

**The defining morphology is two peaks.** Pastorello et al. (2019) describe the
class as double-peaked: an initial rapid rise to a **blue** peak at $-13$ to $-15$
mag, followed by a longer-duration **red** peak that is sometimes attenuated into
a plateau.

Timescales and luminosities from tool-verified primary sources **[obs]**:

| event | peak | plateau duration | plateau $T_{\rm eff}$ | plateau $L$ | ejecta |
|---|---|---|---|---|---|
| AT 2018bwo | $M_r = -10.97\pm0.11$ | $41\pm5$ d | ~3300 K | $\sim10^{40}$ erg s⁻¹ | 0.15–0.5 M☉ at ~500 km s⁻¹ |
| M101 OT2015-1 | $M_r \le -12.4$, then $\simeq-12$ | 2 peaks 98 d apart | ~3700 K | — | $v\simeq300$ km s⁻¹ |
| M31LRN 2015 | — | <10 original orbital periods | — | — | $10^{-2}$ M☉ fast + 0.3 M☉ slow |
| ZTF-CLU sample | $-16 \le M_r \le -11$ | — | — | — | — |

Population-level numbers: the ZTF-CLU LRN volumetric rate is
$7.8^{+6.5}_{-3.7}\times10^{-5}$ Mpc⁻³ yr⁻¹ over $-16\le M_r\le-11$, with
$dN/dL \propto L^{-2.5\pm0.3}$ at these luminosities, steeper than the
$L^{-1.4\pm0.3}$ found for fainter LRNe (Karambelkar et al. 2023). The Galactic
rate from COMPAS population synthesis is $\sim0.2$ yr⁻¹ (Howitt et al. 2020,
*MNRAS* 492, 3229) **[model]**, consistent with the observed rate.

**Two competing power sources for the second peak, both published.**

1. **Hydrogen recombination.** Ivanova et al. (2013); implemented as a
   one-dimensional light-curve model including recombination energy and
   non-radiation-dominated ejecta by Matsumoto & Metzger (2022, *ApJ* 938, 5).
   They find LRNe generically have two peaks — early emission from the initial
   thermal energy of the hot fast ejecta layers, later peak powered by hydrogen
   recombination in the bulk. Their model defines a **maximum luminosity
   achievable for a given donor star** (entire envelope ejected), and they report
   that **several observed LRNe violate that limit**.
2. **Radiative shocks against pre-existing equatorial material.** Metzger &
   Pejcha (2017, *MNRAS*, doi 10.1093/mnras/stx1768) argue the second peak is a
   collision between the dynamically-ejected fast shell and equatorially-focused
   material shed over many orbits *before* the dynamical event. The fast shell
   expands freely toward the poles (cooling-envelope emission → first peak); the
   equatorial collision powers the second peak on the diffusion timescale of the
   deeper layers. This resolves the Matsumoto–Metzger luminosity violation and
   predicts pre-dynamical mass loss is common if not ubiquitous.

**Which is right is unsettled.** Both reproduce double peaks. The discriminant is
the geometry and mass of pre-dynamical material — see §1.4.

### 1.3 Colour and temperature track — directly implementable

This sequence is assembled from tool-verified spectroscopic papers, in order:

1. **Blue peak.** Blue continuum, prominent narrow Balmer lines with P Cygni
   profiles, Fe II mostly in emission (Pastorello et al. 2019).
2. **Red peak / plateau.** Continuum reddens strongly, Hα barely detected, a
   forest of narrow metal lines *in absorption*. $T_{\rm eff}\sim3300$–3700 K
   (Blagorodnova et al. 2021, 2017).
3. **~6 months after blue peak.** Extremely red continuum peaking in the IR, Hα
   back in pure emission, broad molecular absorption bands (TiO, VO)
   (Pastorello et al. 2019).
4. **Years later.** Kamiński et al. (2015, *A&A* 580, A34) identified molecular
   bands of TiO, VO, H₂O, ScO, AlO and CrO in V1309 Sco (first astronomical
   detection of the CrO IR bands), with a cool ($\lesssim1000$ K) outflow at a
   terminal velocity of ~200 km s⁻¹. The optical continuum source *disappeared*
   between 2009 and 2012 as new dust formed. The remnant became a clone of
   V4332 Sgr.
5. **Dust.** Tylenda & Kamiński (2016, *A&A* 592, A134) SED-modelled V1309 Sco:
   dust was already present *before* the outburst at 900–1000 K (freshly formed in
   mass loss from the spiralling-in binary — direct support for pre-dynamical mass
   loss); after 2008 the object became almost completely dust-embedded, with
   $\ge10^{-3}$ M☉ of ejected matter and, from Herschel, cold ~30 K dust a few
   thousand AU out. Total luminosity fell by a factor ~50 between 2008 and 2012.
6. **Optional dramatic detail.** V838 Mon has an unresolved **B3 V companion**
   (Afşar & Bond 2007, *ApJ*, doi 10.1086/509872, in a sparse young cluster
   <25 Myr old at $6.2\pm1.2$ kpc). Tylenda et al. (2011, *A&A*,
   doi 10.1051/0004-6361/201116858) report the **B3 V component had completely
   vanished from the spectrum by 2009**, leaving only the eruption remnant,
   resembling an M6 giant with deeper molecular bands. The expanding remnant
   engulfed/obscured its own companion.

**Colour rule of thumb for the renderer:** a star+star merger goes
**blue → red → invisible-in-optical → infrared**. It never gets hotter after the
first peak. Any model in which a stellar merger *heats up* on decline is
specifically what Tylenda & Soker (2006) used to rule out the nuclear-burning
alternatives.

### 1.4 Spatial structure

The published geometry is **not** a spherical shell. It is bipolar-plus-equatorial:

- **Equatorial, pre-dynamical.** Mass shed from the outer Lagrange point (L2)
  over many orbits before merger. Pejcha, Metzger & Tomida (2016a, *MNRAS* 455,
  4351) performed the first SPH radiation-hydrodynamics of L2 mass loss with a
  realistic equation of state and opacities: the outflow forms a **spiral stream**
  which becomes unbound for binary mass ratios $0.06<q<0.8$; the spiral arms merge
  at $\sim10a$ ($a$ = binary semi-major axis) and the accompanying shock
  thermalizes about 10% of the outflow's kinetic power. Pejcha et al. (2017,
  *ApJ* 850, 59) treat the pre-explosion spiral mass loss directly.
- **Regime dependence.** Pejcha, Metzger & Tomida (2016b, *MNRAS* 461, 2527):
  for $q<0.06$ or $q>0.8$, or when $\varepsilon = c_T/v_{\rm orb} < 0.15$, the
  equatorial outflow stays **marginally bound** and falls back over tens to
  hundreds of binary orbits, getting further tidal torqueing and shocking. What
  then forms depends on cooling efficiency: efficient cooling
  ($t_{\rm diff}/t_{\rm adv}<1$) → collapse to an **excretion disc**; inefficient
  → an isotropic **wind**; intermediate → an **inflated envelope** with meridional
  flows carrying heat to the surface.
- **Polar, dynamical.** The fast shell from the dynamical plunge expands freely
  toward the poles (Metzger & Pejcha 2017).
- **Dust forms in the shocked equatorial sheet.** Metzger & Pejcha (2017) note
  the dense shell created by radiative shocks in the equatorial plane is an ideal
  dust nucleation site, consistent with the *aspherical* dust geometry inferred in
  LRNe. Kamiński et al. (2018, *A&A* 617, A129) mapped cool molecular outflows in
  three Galactic red novae in the submillimetre.

So: **a rotating, flattened, dusty, molecular torus with a faster quasi-polar
shell punching through it**, growing at 200–500 km s⁻¹.

### 1.5 Onset dynamics — what makes the merger "go"

MacLeod et al. (2018, *ApJ* 863, 5) show the onset of a common-envelope episode
is a **runaway**: once the companion is engulfed, drag drives inspiral faster than
the envelope can respond. MacLeod et al. (2017) constrained M31LRN 2015 directly:
the optical transient lasted **fewer than ten orbits of the original binary**
(pre-merger period ~10 d), the primary was a 3–5.5 M☉ subgiant of radius
30–40 R☉ *growing* in radius, and if the merger was triggered by the Darwin tidal
instability the companion was 0.1–0.6 M☉. Blagorodnova et al. (2021) infer for
AT 2018bwo a stable mass-transfer phase at
$-2.4 < \log(\dot M/M_\odot\ {\rm yr}^{-1}) < -1.2$ **a decade before** the
instability, then 0.15–0.5 M☉ ejected at ~500 km s⁻¹ in the dynamical merger.

**Implementable timing:** slow pre-merger mass loss for ≳10 orbits → runaway
plunge over ≲10 orbits → fast blue flash → 1–2 month red plateau → months-to-years
IR dust phase.

### 1.6 Massive-star mergers (relevant if your star particles are ~50 M☉)

Howitt et al. (2020) argue observations of the *brightest* LRNe may provide
indirect evidence for $>40$ M☉ red supergiants. Karambelkar et al. (2023) find
the rates of the brightest LRNe ($M_r \le -13$) are consistent with a significant
fraction being progenitors of double compact objects that merge within a Hubble
time. **But there is no observed LRN with a confirmed ~50 M☉ + ~50 M☉ progenitor
pair.** The most massive well-constrained progenitor is the 18±1 M☉ F-type yellow
supergiant of M101 OT2015-1 (Blagorodnova et al. 2017), which they note fills the
gap between V838 Mon (5–10 M☉) and NGC 4490-OT (~30 M☉). Extrapolating the LRN
light-curve morphology to 50+50 M☉ is an extrapolation, and you should label it as
one.

---

## 2. CASE B — star + black hole

### 2.1 The geometry, from the original derivation

**Tidal radius** (Hills 1975, *Nature* 254, 295; Rees 1988, *Nature* 333, 523):

$$r_t = R_\star\left(\frac{M_{\rm BH}}{M_\star}\right)^{1/3}$$

*Regime of validity:* Newtonian, order-of-magnitude, $M_{\rm BH}\gg M_\star$,
parabolic encounter, star treated as a fluid body with no internal structure. It
is a **scaling**, not a threshold — the actual full-disruption pericentre depends
on the stellar density profile (Guillochon & Ramirez-Ruiz 2013) and, at high
$M_{\rm BH}$, on relativity (Ryu et al. 2020).

**The horizon ratio** — the constraint you asked about:

$$\frac{r_t}{r_s} = \frac{R_\star c^2}{2GM_{\rm BH}}\left(\frac{M_{\rm BH}}{M_\star}\right)^{1/3} \propto M_{\rm BH}^{-2/3}$$

Setting $r_t = r_s$ defines the **Hills mass** — above it, a star of that type
crosses the horizon intact and there is no flare at all:

$$M_{\rm Hills} = \left(\frac{R_\star c^2}{2G}\right)^{3/2}M_\star^{-1/2}
= \mathbf{1.14\times10^{8}\ M_\odot}\ \ \text{for }1\,M_\odot,\ 1\,R_\odot\ \textbf{[arith]}$$

Using the Schwarzschild ISCO ($r_t = 6GM/c^2$) instead gives
$2.20\times10^7$ M☉ **[arith]**. Which convention you use matters at the factor-of-5
level, so state it. Relativistic corrections and black-hole spin move this
boundary: Kesden (2012, *PRD* 85, 024037) computed the tidal-disruption rate for
spinning holes, and Ryu et al. (2020, doi 10.3847/1538-4357/abb3cc) find that for
fixed $M_\star$, as $M_{\rm BH}$ rises the maximum pericentre yielding full
disruption grows to **triple** the Newtonian value at
$M_{\rm BH}=5\times10^7$ M☉, while the debris energy width **halves**; above
$\sim10^7$ M☉ the full-disruption cross-section is suppressed by competition with
direct capture.

### 2.2 The 50 M☉ answer

**A 50 M☉ hole always shreds a main-sequence star, four decades outside its
horizon. It can never swallow one whole.** All values below are **[arith]** from
the equations in this section, for $M_\star = 1$ M☉, $R_\star = 1$ R☉,
parabolic encounter with $r_p = r_t$:

| quantity | value | in units of $r_s$ / $M$ |
|---|---|---|
| $r_s$ | $1.4770\times10^7$ cm = 147.70 km | $1\,r_s = 2M$ |
| $r_t$ | $2.563\times10^{11}$ cm = **3.684 R☉** | $1.735\times10^{4}\,r_s = 3.47\times10^{4}\,M$ |
| debris energy spread $\Delta\varepsilon$ | $7.030\times10^{15}$ erg g⁻¹ | — |
| debris velocity spread $\sqrt{2\Delta\varepsilon}$ | **1186 km s⁻¹** | $3.96\times10^{-3}\,c$ |
| most-bound orbit $a_{\rm min}$ | $4.721\times10^{11}$ cm = 6.79 R☉ | $3.20\times10^{4}\,r_s$ |
| minimum fallback time $t_{\rm min}$ | $2.502\times10^{4}$ s = **6.95 h** | — |
| peak fallback rate | **420 M☉ yr⁻¹** | $3.8\times10^{8}\,\dot M_{\rm Edd}$ |
| $L_{\rm Edd}$ | $6.29\times10^{39}$ erg s⁻¹ | — |
| GR apsidal advance per orbit at $r_p=r_t$ | $2.72\times10^{-4}$ rad = **56 arcsec** | — |

For contrast, the same star around $10^6$ M☉: $r_t/r_s = 23.6$, $t_{\rm min}=40.9$ d
(the textbook "41 days"), apsidal advance **0.200 rad = 11.5° per orbit**.

**Geometric cross-section argument.** In the gravitationally-focused (low-velocity)
limit the capture cross-section scales as the pericentre, so
$\sigma_{\rm swallow}/\sigma_{\rm disrupt} \simeq r_s/r_t \simeq 6\times10^{-5}$
**[arith]**. Direct plunge is a $10^{-4}$-probability event; it is not a channel you
should ever draw for a 50 M☉ hole.

**Corollary for accretion bookkeeping:** the hole does **not** gain $M_\star$. It
gains at most the bound half of the debris, minus whatever the super-Eddington
outflow expels — and Kremer et al. (2023, doi 10.1093/mnras/stad2239) build the
disc-plus-wind model in which a large fraction is lost to the wind. If your sim
adds the whole star's mass to the hole on contact, that is wrong by a factor of a
few *and* it deletes the visible part of the event.

### 2.3 Stream geometry and the unbound fraction

The star is stretched into **two streams** on opposite sides of the pericentre
passage: one with $\varepsilon>0$ (unbound, escaping) and one with
$\varepsilon<0$ (bound, returning). In the frozen-in approximation with a uniform
$dM/d\varepsilon$ the split is **exactly one-half unbound** (§3.1) — this is a
consequence of the approximation, not a measurement.

What simulations change:

- **Non-uniform $dM/d\varepsilon$.** Lodato, King & Pringle (2009, *MNRAS* 392,
  332) relate the light curve to the internal density structure of the star and
  find the star is *homologously inflated* on reaching pericentre by the effective
  reduction of gravity in the tidal field, and that for stiff polytropes "wings"
  appear in the tails of the energy distribution because shocks in the tidal tails
  push material off parabolic orbits.
- **Compression physics.** Stone, Sari & Loeb (2013, *MNRAS* 435, 1809) find,
  contrary to most earlier work, that the debris energy spread is **largely
  constant for all penetration factors** $\beta = r_t/r_p$, and that
  leading-order GR corrections to that spread are small. Stellar spin can widen
  the spread when combined with spin–orbit misalignment and high $\beta$.
  Steinberg et al. (2019, doi 10.1093/mnrasl/slz048) revisit the frozen-in
  approximation itself for deeply plunging encounters.
- **Eccentric/hyperbolic encounters.** *This matters enormously at 50 M☉.* The
  standard $\tfrac12$ unbound fraction assumes a parabolic orbit from a nearly
  radial infall. Micro-TDEs come from cluster dynamics and are **not** parabolic:
  Perets et al. (2016, *ApJ* 823, 113) identify three dynamical channels
  (close random encounter in a dense cluster; perturbation of a wide companion;
  a natal-kicked compact object encountering its binary companion), and
  Rastello et al. (2026, *A&A* 707, A217) add binary-mediated and
  higher-multiplicity channels, which dominate their rate. For a hyperbolic
  encounter **more than half** the mass is unbound and the visible flare is
  correspondingly weaker. Xin et al. (2023, arXiv:2303.12846) simulate the
  opposite extreme with PHANTOM — a near-circular gradual inspiral in which the
  star is **peeled** rather than disrupted ("tidal peeling event"), with accretion
  rates and orbital evolution distinct from an eccentric micro-TDE.

### 2.4 Circularisation — and why the 50 M☉ case is qualitatively different

For a supermassive hole, the returning stream self-intersects because relativistic
apsidal precession rotates the orbit by a large angle each pass; the resulting
stream–stream shock dissipates orbital energy and forms a disc. The primary
references: Kochanek (1994, *ApJ* 422, 508) for the dynamics of thin gas streams;
Shiokawa et al. (2015, *ApJ* 804, 85) for the first GR hydrodynamic simulation of
accretion-flow formation from a disruption; Bonnerot et al. (2016, *MNRAS* 455,
2253) for disc formation from eccentric orbits around Schwarzschild holes;
Lu & Bonnerot (2020, *MNRAS* 492, 686) for a semi-analytic self-intersection model
in which, when the pericentre is inside ~15 gravitational radii, a large fraction
of the shocked gas is ejected as a **collision-induced outflow**; and Steinberg &
Stone (2024, *Nature* 625, 463) for the first 3D radiation-hydrodynamic simulation
from disruption to peak, in which stream–disc shocks efficiently circularise
returning debris and reproduce observed peak optical/UV luminosities.

**At 50 M☉ that mechanism is switched off.** The apsidal advance per orbit is
56 arcsec — five orders of magnitude too small to make the stream miss itself by a
meaningful angle. Whatever forms the disc at $M_{\rm BH}=50$ M☉ cannot be
relativistic precession. What is available instead:

1. **Geometry.** $a_{\rm min}/r_t = 1.84$ and $r_t/R_\star = 3.68$ — the entire
   debris structure is only a few stellar radii across. The stream is short, thick,
   and its own vertical scale height is comparable to the orbit, so self-collision
   is essentially geometrically unavoidable regardless of precession.
2. **The nozzle shock** at pericentre, where the stream is vertically compressed.
3. **Direct hydro results.** Kremer et al. (2019, doi 10.3847/1538-4357/ab2e0c)
   ran $N$-body plus hydrodynamic treatment of BH–main-sequence encounters in
   globular clusters and Kremer et al. (2023) built the long-term disc evolution on
   top of that: they find a **thick, super-Eddington accretion disc** does form and
   drives strong winds.

**Honest status:** the disc-formation physics for a 50 M☉ hole has *not* been
solved with radiation-hydrodynamics the way Steinberg & Stone (2024) did for
supermassive holes. Kremer et al. (2019, 2023) is the state of the art and it is a
hydro-plus-semi-analytic-disc treatment, not an ab-initio radiative calculation.
Draw a rapidly-forming compact disc, but know that its formation efficiency is
a model input, not a measurement.

### 2.5 What is actually emitted at 50 M☉

The naive answer ($\eta \dot M_{\rm fb} c^2 = 2.4\times10^{48}$ erg s⁻¹) is wrong by
eight orders of magnitude, because $\dot M_{\rm peak}/\dot M_{\rm Edd} \approx
4\times10^8$. The published prediction is:

**Kremer et al. (2023):** peak bolometric luminosities
$\mathbf{10^{41}-10^{44}}$ **erg s⁻¹** (the range set mostly by accretion-physics
parameters) and temperatures $\mathbf{10^{5}-10^{6}}$ **K**, so peak emission in the
**ultraviolet/blue**. The mechanism is *reprocessing*: radiation from the central
engine is absorbed and re-emitted at large radius by the optically thick disc wind.
Their earlier estimate (Kremer et al. 2019) from the ejected mass alone gave
$10^{41}-10^{44}$ erg s⁻¹ on timescales of **a day to a month**. Note $10^{44}$
erg s⁻¹ exceeds $L_{\rm Edd}(50\,M_\odot)$ by four decades — this is genuinely
super-Eddington emission from a wind photosphere, not a thin disc.

Related predicted signatures: Perets et al. (2016) estimate that efficient
accretion of $f_{\rm acc}=0.1$ of the debris gives long ($10^3-10^4$ s)
X-ray/γ-ray flares with total energies up to
$(f_{\rm acc}/0.1)\times10^{52}(M_\star/0.6\,M_\odot)$ erg, possibly resembling
**ultra-long GRBs / X-ray flashes** — and they explicitly caution that
significantly fainter flares result if most of the disc mass is blown away in
outflows.

**Rates, for context:** $\sim3$ Gpc⁻³ yr⁻¹ locally from globular clusters, peaking
at ~25 Gpc⁻³ yr⁻¹ at $z=3$ (Kremer et al. 2019); 350–450 Gpc⁻³ yr⁻¹ from young star
clusters (Rastello et al. 2026); ~170 Gpc⁻³ yr⁻¹ from AGN discs (Yang et al. 2022,
doi 10.3847/2041-8213/ac7c0b); few$\times10^{-6}$ yr⁻¹ per Milky-Way galaxy for BH
micro-TDEs (Perets et al. 2016). **No micro-TDE has been confirmed
observationally.** Proposed candidates exist (AT2018cow-class luminous fast blue
optical transients — Metzger 2022, doi 10.3847/1538-4357/ac6d59, models these as
the tidal disruption and hyper-accretion of a Wolf–Rayet star by a BH or NS
companion) but the class identification is not established.

### 2.6 The other star+BH channel you may be simulating

If your hole ends up *inside* a star rather than passing by it — i.e. a common
envelope with a compact object — the literature is different and the signature is
different. Chevalier (2012, *ApJL* 752, L2) proposed common-envelope evolution of
a compact object inside a massive star's envelope to explain Type IIn / superluminous
supernovae with dense circumstellar interaction, with mass-loss velocities
comparable to the observed few-hundred km s⁻¹. Schrøder et al. (2020,
doi 10.3847/1538-4357/ab7014) model the coalescence of a BH or NS with the core of
its massive-star companion: they find **toroidal** circumstellar profiles
concentrated in the equatorial plane extending to many times the original stellar
radius, explosions brightened by up to three magnitudes by CSM interaction,
brightest events $M_V \sim -18$ to $-19$ (the BH cases, because their CSM is the
most massive and extended), and BH coalescence events comprising about 50% of all
merger-driven explosions and ~0.3% of the core-collapse rate. **This is 6–8
magnitudes brighter than an LRN and has a completely different geometry from a
micro-TDE.** If your sim can produce both configurations, they should not look
alike.

---

## 3. The $t^{-5/3}$ law — derivation, assumptions, and how well it holds

### 3.1 Derivation (the frozen-in energy-distribution argument)

The argument is Rees (1988, *Nature* 333, 523), with the fallback-rate form
developed by Phinney (1989, IAU Symp. 136, 543) and Evans & Kochanek (1989,
*ApJ* 346, L13).

**Step 1 — freeze-in.** The star crosses $r_t$ on a timescale comparable to its own
dynamical time, so the *spread* in specific orbital energy imprinted at pericentre
is frozen in. Each debris element's energy is set by its position across the star
at that instant:

$$\Delta\varepsilon = \frac{GM_{\rm BH}R_\star}{r_t^{2}}$$

(the tidal potential difference across the stellar diameter, to a factor of order
unity; Rees 1988, Lodato et al. 2009).

**Step 2 — uniform distribution.** Assume $dM/d\varepsilon = M_\star/(2\Delta\varepsilon)$
is *constant* over $-\Delta\varepsilon \le \varepsilon \le +\Delta\varepsilon$.
Half the mass ($\varepsilon>0$) is unbound; half returns.

**Step 3 — Kepler.** A bound element with $\varepsilon<0$ returns to pericentre
after $t = 2\pi GM_{\rm BH}(2|\varepsilon|)^{-3/2}$, i.e.
$|\varepsilon| = \tfrac12(2\pi GM_{\rm BH}/t)^{2/3}$, so
$|d\varepsilon/dt| = \tfrac13(2\pi GM_{\rm BH})^{2/3}t^{-5/3}$.

**Step 4 — chain rule.**

$$\dot M_{\rm fb}(t) = \frac{dM}{d\varepsilon}\left|\frac{d\varepsilon}{dt}\right|
= \boxed{\frac{M_\star}{3}\,t_{\rm min}^{2/3}\,t^{-5/3}},\qquad
t_{\rm min} = \frac{2\pi G M_{\rm BH}}{(2\Delta\varepsilon)^{3/2}}
= 2\pi\sqrt{\frac{a_{\rm min}^3}{GM_{\rm BH}}},\quad a_{\rm min}=\frac{r_t^2}{2R_\star}$$

with $\dot M_{\rm peak} = M_\star/(3t_{\rm min})$. Written out:

$$t_{\rm min} = 40.9\ \mathrm{d}\ \left(\frac{M_{\rm BH}}{10^{6}M_\odot}\right)^{1/2}
\left(\frac{M_\star}{M_\odot}\right)^{-1}\left(\frac{R_\star}{R_\odot}\right)^{3/2}
\qquad \textbf{[arith]}$$

**The $-5/3$ is not tidal physics.** It is $-5/3 = -(1 + 2/3)$, where the $2/3$ is
Kepler's third law and the $1$ is the assumption that $dM/d\varepsilon$ is flat.
Any of the four steps can fail.

### 3.2 The assumptions, listed

1. Instantaneous freeze-in of the energy spread at pericentre.
2. $dM/d\varepsilon$ = constant across the full range.
3. Pure Keplerian point-mass return (no self-gravity, no GR, no pressure).
4. Parabolic incoming orbit (so exactly half is bound).
5. Full disruption — no surviving core.
6. **Observed luminosity $\propto$ fallback rate** — a separate assumption, and the
   one that fails most often.

### 3.3 What breaks it

| breaker | effect | source |
|---|---|---|
| **Stellar structure** | $-5/3$ holds only at *late* times; near peak the curve is shallower, deviating more for centrally concentrated (solar-type) stars. For a solar-type star $-5/3$ is reached only after the luminosity has dropped by **≥2 mag** from peak. | Lodato, King & Pringle 2009 |
| **Impact parameter / density profile** | Hydro simulations: the most-centrally-concentrated stars have the *quickest*-peaking flares (opposite to the analytic prediction), and the trend with $\beta$ *reverses* beyond the critical full-disruption distance. Index $n$ asymptotes to $\simeq-2.2$ for both low- and high-mass stars in **about half** of all disruptions. | Guillochon & Ramirez-Ruiz 2013 |
| **Partial disruption** | A surviving core exerts a time-dependent gravitational influence on the expanding stream, so the energy–period relation is no longer Keplerian. Asymptotic fallback $\propto t^{-2.26\pm0.01}$, **effectively independent of the surviving core's mass** — i.e. the dichotomy is $t^{-5/3}$ (full) vs $t^{-9/4}$ (partial). Earlier work missed this by assuming Keplerian energy–period. | Coughlin & Nixon 2019 |
| | Immediately post-peak, partial disruptions of centrally concentrated stars can show $n$ as extreme as $-4$ for months. | Guillochon & Ramirez-Ruiz 2013 |
| **Stellar spin** | Modifies the disruption and the debris energy distribution. | Golightly, Nixon & Coughlin 2019; Stone, Sari & Loeb 2013 |
| **Relativity at high $M_{\rm BH}$** | Debris energy width shrinks by a factor ~2 at $5\times10^7$ M☉, which **delays** the peak and **reduces** its magnitude. | Ryu et al. 2020 |
| **Extreme relativistic encounters** | For orbits that wind several times around the hole, the light curve instead rises rapidly to roughly $L_{\rm Edd}$, holds for weeks to a year, then drops — thermal X-rays at $(1-2)\times10^6$ K. Qualitatively a different class. | Ryu et al. 2023, doi 10.3847/2041-8213/acc390 |
| **Viscous delay / circularisation** | If disc formation is slower than fallback, the accretion rate is smoothed and the light curve decouples from $\dot M_{\rm fb}$ entirely. This is the "dark year" possibility. | Guillochon & Ramirez-Ruiz 2015, *ApJ* 809, 166; Shiokawa et al. 2015; Piran et al. 2015 |
| **Shock power, not accretion power** | Piran et al. (2015) argue the optical/UV is powered by *disc formation* (shocks) rather than accretion; Steinberg & Stone (2024) find peak emission in their radiation-hydro simulation is shock-powered, with accretion power only becoming competitive near peak as circularisation runs away. If the light is shock-powered, its decay tracks the shock, not $\dot M_{\rm fb}$. | Piran et al. 2015; Steinberg & Stone 2024 |
| **Reprocessing** | Radiative-transfer modelling (Roth et al. 2016, *ApJ* 827, 3) and the reprocessing-layer picture (Lu & Bonnerot 2020; Dai et al. 2018, *ApJL* 859, L20 for the unified viewing-angle model) mean the observed band-limited flux is a filtered version of the bolometric output. | as listed |
| **Late-time plateau** | Mummery et al. (2023, *MNRAS* 527, 2452) find **at least two-thirds** of 63 optically selected TDEs flatten into a near-constant late-time plateau, physically from the presence of a settled accretion flow. A plateau is not a power law at all. | Mummery et al. 2023 |

### 3.4 How well it actually holds — observed decay indices

Hammerstein et al. (2023, *ApJ* 942, 9) fit the long-term ($\gtrsim350$ d
post-peak) optical/UV light curves of their 30-TDE ZTF-I sample with a Gaussian
rise plus **free-index power-law decay** at fixed temperature. Their per-object
fitted indices $p$ are in their Table 6. **Summary statistics below are my own
arithmetic over their 30 published values — the fits are theirs, the distribution
is mine** (`ztf-tde-decay-indices.csv`):

| statistic | value |
|---|---|
| median $p$ | **$-1.91$** |
| mean $\pm$ s.d. | $-2.03 \pm 0.77$ |
| interquartile range | $-2.28$ to $-1.62$ |
| full range | $-0.78$ (AT2018zr) to $-3.82$ (AT2020riz) |
| steeper than $-5/3$ | **21 / 30 (70%)** |
| within $\pm0.2$ of $-5/3$ | 9 / 30 (30%) |

So $-5/3$ is a reasonable *central* value but a poor description of any individual
event: the spread is a factor of ~5 in index, and the population median sits closer
to Guillochon & Ramirez-Ruiz's simulated $-2.2$ and Coughlin & Nixon's partial-disruption
$-2.26$ than to $-5/3$. Hammerstein et al. also report they find **no significant
correlation** between host-galaxy mass and the fallback timescale defined as $t_0$
with $p$ *fixed* to $-5/3$, and suggest this may be due to the late-time plateaus —
i.e. forcing $-5/3$ destroys a correlation that the free-index and $e$-folding
fits recover.

**For the renderer, the honest summary:** $t^{-5/3}$ is the right *default* slope
for a fallback-rate curve and the wrong thing to promise as an observable. If you
want a light curve, use a decay index drawn from roughly $-2.0\pm0.8$, flatten it
to a plateau at late times, and remember the rise is set by photon diffusion, not
by $t_{\rm min}$ (van Velzen et al. 2021, *ApJ* 908, 4, argue explicitly from the
rise-time/spectral-class correlation that pre-peak TDE light curves are governed
**not** by the fallback timescale but by diffusion of photons through the debris).

---

## 4. CASE C — black hole + black hole

A BBH merger radiates essentially nothing electromagnetically on its own. What
there *is* to see divides into (i) the mass–energy bookkeeping, which is
mandatory and exactly known; (ii) the response of any surrounding matter, which is
well modelled but scenario-dependent; and (iii) claimed counterparts, which are
contested.

### 4.1 Mass–energy budget — the part you must get right

For **equal-mass, non-spinning** black holes, the numerical-relativity answer is
known to five digits (Scheel et al. 2009, *PRD* 79, 024003, from 16-orbit spectral
simulations): **[NR]**

$$\frac{M_f}{M} = 0.95162 \pm 0.00002,\qquad \chi_f = \frac{S_f}{M_f^2} = 0.68646 \pm 0.00004$$

For 50 + 50 M☉ **[arith]** from those:

- $M_f = 95.162$ M☉ — a **mandatory mass deficit of 4.838 M☉, i.e. 4.84%**
- $E_{\rm rad} = 4.838\,M_\odot c^2 = \mathbf{8.648\times10^{54}}$ **erg**
  (≈ 8600 times the canonical $10^{51}$ erg of a core-collapse supernova)
- $r_s$ goes from $2\times147.70$ km (two holes) to **281.04 km** (one hole)

For unequal masses / spins, use a published remnant fit rather than interpolating:
Barausse, Morozova & Rezzolla (2012, *ApJ* 758, 63; erratum *ApJ* 786, 76) for the
final mass, Hofmann, Barausse & Rezzolla (2016, *ApJL* 825, L19) for the final spin
(RMS error $\sigma\approx0.002$ aligned, $\approx0.006$ generic, calibrated on 619
simulations), Healy, Lousto & Zlochower (2014, *PRD* 90, 104004) and Healy & Lousto
(2017, *PRD* 95, 024037) for mass/spin/recoil/peak-luminosity together (typical
errors ~0.1–0.2% for mass and spin, ~5% for recoil and peak luminosity), or the
surrogate remnant models of Varma et al. (2019, *PRResearch* 1, 033015). I did not
reproduce those fits' coefficients here — pull them from the papers.

**Peak gravitational-wave luminosity.** Keitel et al. (2017, *PRD* 96, 024006)
scale out the equal-mass, zero-spin value
$L_0 = L_{\rm peak}(\eta=0.25,\chi=0)/0.25^2 \approx 0.0164$ in geometric units
($G=c=M=1$), the average of the SXS, GaTech and RIT results at that configuration
(agreeing within 0.2%). Hence **[arith]**:

$$L_{\rm peak} = 0.0164\times(0.25)^2\,\frac{c^5}{G} = 1.025\times10^{-3}\frac{c^5}{G}
= \mathbf{3.72\times10^{56}\ erg\ s^{-1}}$$

**This is independent of total mass** — Keitel et al. state this explicitly: both
$E_{\rm rad}$ and the characteristic timescale scale linearly with $M$, so $L$ does
not. The measured value for GW150914 is
$3.6^{+0.5}_{-0.4}\times10^{56}$ erg s⁻¹ $= 200^{+30}_{-20}\,M_\odot c^2$ s⁻¹
**[obs]** (quoted in Keitel et al. 2017 from the LIGO parameter-estimation papers,
Abbott et al. 2016, *PRL* 116, 241102). GW150914 itself: $36^{+5}_{-4} + 29^{+4}_{-4}$
M☉ → remnant $62^{+4}_{-4}$ M☉ at spin $0.67^{+0.05}_{-0.07}$ **[obs]** — note the
remnant spin measurement agrees with the NR equal-mass prediction 0.686.

### 4.2 Ringdown quasi-normal modes

Ringdown is a superposition of damped sinusoids $h \sim e^{-t/\tau}\cos(2\pi f t)$
with discrete complex frequencies fixed by $M_f$ and $\chi_f$ alone. Foundational
references: Vishveshwara (1970, *Nature* 227, 936) for the ringing itself;
Chandrasekhar & Detweiler (1975, *Proc. R. Soc. A* 344, 441) and Detweiler (1980,
*ApJ* 239, 292) for the mode frequencies; **Leaver (1985, *Proc. R. Soc. A* 402,
285)** for the continued-fraction method that is still the standard;
Echeverria (1989, *PRD* 40, 3194) for using them to measure mass and spin;
Berti, Cardoso & Will (2006, *PRD* 73, 064030) for the multi-mode
spectroscopy formalism and the standard fitting formulae; Berti, Cardoso &
Starinets (2009, *CQG* 26, 163001) for the review.

**I computed these directly by Leaver's method** (via the `qnm` package,
Stein 2019, *JOSS* 4, 1683, which implements a Leaver solver with the
Cook–Zalutskiy spectral treatment of the angular sector), $s=-2$. Validation: my
Schwarzschild fundamental is $M\omega = 0.373672 - 0.088962i$, matching the
classic $0.3737 - 0.0890i$. Full table in `ringdown-qnm-scaling.csv`.

**General scaling** (exact, from $M\omega$ dimensionless):

$$f_{\ell m n} = \frac{\mathrm{Re}(M\omega)}{2\pi}\frac{c^3}{GM_f}
= 32312\,\mathrm{Hz}\times\mathrm{Re}(M\omega)\times\frac{M_\odot}{M_f},
\qquad
\tau_{\ell m n} = \frac{1}{|\mathrm{Im}(M\omega)|}\frac{GM_f}{c^3}$$

| mode | $\chi_f$ | $M\omega$ | $Q$ | $f\times(M_f/M_\odot)$ | $\tau/(M_f/M_\odot)$ |
|---|---|---|---|---|---|
| (2,2,0) | 0.68646 | $0.526703 - 0.081288i$ | 3.240 | 17019 Hz | 0.060593 ms |
| (2,2,0) | 0 | $0.373672 - 0.088962i$ | 2.100 | 12074 Hz | 0.055366 ms |
| (2,2,1) | 0.68646 | $0.514859 - 0.245813i$ | 1.047 | 16636 Hz | 0.020038 ms |
| (3,3,0) | 0.68646 | $0.834958 - 0.083435i$ | 5.004 | 26980 Hz | 0.059034 ms |
| (4,4,0) | 0.68646 | $1.130888 - 0.084844i$ | 6.665 | 36542 Hz | 0.058053 ms |

**Scaled to your seeds** ($M_f = 95.162$ M☉ from 50+50, $\chi_f = 0.68646$) **[arith]**:

| mode | $f$ | $\tau$ |
|---|---|---|
| **(2,2,0) fundamental** | **178.84 Hz** | **5.766 ms** |
| (2,2,1) first overtone | 174.82 Hz | 1.907 ms |
| (3,3,0) | 283.51 Hz | 5.618 ms |

In geometrized units $\tau_{220} = 12.302\,M_f$ and the oscillation period is
$11.929\,M_f$ — **the ringdown is roughly one cycle long** ($f\tau = 1.03$). If you
want a visible ringdown you are drawing about one oscillation, not a decaying train.
For a hypothetical 50 M☉ *remnant* at the same spin: $f = 340.4$ Hz,
$\tau = 3.030$ ms.

**What is contested.** Whether the overtone (2,2,1) was actually detected in
GW150914 is disputed: Isi et al. (2019, *PRL* 123, 111102) claimed evidence for it
and used it to test the no-hair theorem; Cotesta et al. (2022, *PRL* 129, 111102)
reanalysed and disputed the significance; Isi & Farr replied (*PRL* 131, 169001).
Collaboration ringdown tests: Abbott et al. (2016, *PRL* 116, 221101, erratum
*PRL* 121, 129902) and Abbott et al. (2021, *PRD* 103, 122002).

### 4.3 Recoil (kick)

**For equal-mass, non-spinning holes the recoil is exactly zero by symmetry.** If
your sim applies a kick to a 50+50 non-spinning merger, that is wrong.

Published maxima **[NR]**:

| configuration | max recoil | source |
|---|---|---|
| non-spinning, unequal mass | $175.2 \pm 11$ km s⁻¹ at $\eta = 0.195\pm0.005$ ($q\approx0.36$) | González et al. 2007, *PRL* 98, 091101 |
| equal mass, anti-aligned in-plane spins ("superkick") | ~4000 km s⁻¹ for maximal spins, varying **sinusoidally** with the angle between initial spin directions and linear momenta; recoil is perpendicular to the orbital plane | Campanelli et al. 2007, *PRL* 98, 231102 |
| partial spin–orbit alignment ("hangup kick") | ~5000 km s⁻¹ | Lousto & Zlochower 2011, *PRL* 107, 231102 |

Recoil fitting formulae: Campanelli et al. (2007, *ApJ* 659, L5), Lousto &
Zlochower (2009, *PRD* 79, 064018), Lousto & Zlochower (2011, *PRD* 83, 024003),
Healy et al. (2014, 2017).

**Effect on bound material** — material survives bound to the remnant only inside
roughly $r < GM_f/v_k^2$ **[arith]**:

| $v_k$ | $r_{\rm bound}$ | in $r_s(M_f)$ |
|---|---|---|
| 175 km s⁻¹ | $4.1\times10^{13}$ cm = 2.75 AU | $1.5\times10^{6}$ |
| 500 km s⁻¹ | $5.1\times10^{12}$ cm = 0.34 AU | $1.8\times10^{5}$ |
| 2000 km s⁻¹ | $3.2\times10^{11}$ cm | $1.1\times10^{4}$ |
| 5000 km s⁻¹ | $5.1\times10^{10}$ cm | $1.8\times10^{3}$ |

A superkick therefore strips everything outside a few $\times10^{10}$ cm — for a
50 M☉-scale system that is essentially the whole bound envelope.

### 4.4 What happens to surrounding matter — inspiral, mass loss, kick

**(a) Inspiral, and the timescale you have to work with.** Quadrupole
gravitational-radiation inspiral (Peters 1964 — *identifier not verified*), for
50+50 M☉, circular **[arith]**:

$$t_{\rm gw} = \frac{5}{256}\frac{c^5 a^4}{G^3 m_1 m_2 (m_1+m_2)}$$

| $a$ | $a/r_s(100 M_\odot)$ | $t_{\rm gw}$ |
|---|---|---|
| $10^{11}$ cm | $3.4\times10^{3}$ | 2563 yr |
| $1.405\times10^{10}$ cm (= 0.202 R☉) | 476 | **1 yr** |
| $10^{10}$ cm | 339 | 0.256 yr |
| $10^{9}$ cm | 33.9 | 808 s |
| $3\times10^{7}$ cm | 1.02 | $6.6\times10^{-4}$ s |

The steep $a^4$ dependence is the visual: nothing happens for millennia, then the
last two decades of separation take less than a day, and the last decade takes
under a second.

**(b) Circumbinary gas dynamics during inspiral.** This is well-studied for
*supermassive* binaries and the morphology carries over. MacFadyen &
Milosavljević (2008, *ApJ* 672, 83) established the **eccentric circumbinary disc
with a central low-density cavity** of radius ~2$a$. Farris et al. (2014, *ApJ*
783, 134) followed the gas dynamics inside the cavity: narrow **accretion streams**
crossing the cavity feed individual **mini-discs** around each hole. Bowen et al.
(2018, *ApJL* 853, L17; 2019, *ApJ* 879, 76) found quasi-periodic behaviour of the
mini-discs approaching merger. GRMHD treatments: Gold et al. (2014, *PRD* 89,
064060) for unequal masses; d'Ascoli et al. (2018, *ApJ* 865, 140) for ray-traced
emission from an approaching-merger binary; Combi et al. (2022,
doi 10.3847/1538-4357/ac532a) for a full 3D GRMHD equal-mass **spinning** binary
with circumbinary disc plus mini-discs — they find accretion is dominated by an
$m=1$ overdensity ("the **lump**") at the inner edge of the circumbinary disc,
most mass reaches the holes by *direct plunging* from the lump rather than through
the mini-discs, and outflows are 8× stronger in the spinning case. Ruiz et al.
(2023, *PRD* 108, 124043) is a further GRMHD treatment.

**Decoupling.** Milosavljević & Phinney (2005, *ApJ* 622, L93) introduced the
"afterglow": once $t_{\rm gw}$ becomes shorter than the disc's viscous time the
binary **decouples** from the disc and merges inside an evacuated cavity; the disc
then has to viscously refill, producing a delayed brightening. This is the reason
any EM counterpart is *late*, not simultaneous.

**(c) Response to the mass deficit.** The remnant is 4.84% lighter, instantaneously
on the orbital timescale of any surrounding gas. For a test particle on a circular
orbit at $r_0$ when the central mass drops by fraction $f$, with angular momentum
conserved **[arith]**:

$$\frac{a'}{r_0} = \frac{1-f}{1-2f},\qquad 1-e^2 = \frac{1-2f}{(1-f)^2}$$

| $f$ | $a'/r_0$ | induced $e$ |
|---|---|---|
| **0.0484** (50+50 equal-mass) | **1.0536** | **0.0508** |
| 0.02 | 1.0208 | 0.0204 |
| 0.10 | 1.1250 | 0.1111 |

So the whole bound structure expands by 5.4% and acquires $e \simeq f$. Because
every radius acquires the same eccentricity but a different orbital period, the
orbits shear and **concentric shocks propagate outward** through the disc. This
mechanism is developed in Corrales, Haiman & MacFadyen (2010, *MNRAS* 404, 947),
"Hydrodynamical response of a circumbinary gas disc to black hole recoil and mass
loss"; O'Neill et al. (2009) treated the same problem
(*identifier not verified*). This is a directly implementable, exactly-derivable
visual: **every bound particle's orbit jumps outward by 5.4% and becomes
eccentric at the instant of merger.**

**(d) Response to the recoil.** Lippai, Frei & Haiman (2008, *ApJ* 676, L5) showed
a recoil imprints a **prompt, concentric, spiral-shaped shock pattern** in the
surrounding disc; Schnittman & Krolik (2008, *ApJ* 684, 835) computed the resulting
infrared afterglow; Zanotti et al. (2010, *A&A* 523, A8) did GR simulations of
recoiling-hole EM counterparts; Haiman, Kocsis & Menou (2009, *ApJ* 700, 1952)
placed this in a population context; Komossa (2012, *Adv. Astron.* 2012, 364973)
reviewed recoiling-BH signatures and candidates. The comprehensive current review
of the whole area is Bogdanović, Miller & Blecha (2022,
*Living Rev. Relativ.* 25, 3).

### 4.5 Is there ever an electromagnetic counterpart? — honest status

**No BBH merger has a confirmed electromagnetic counterpart.** Two claimed cases
dominate the discussion, and both are contested.

**(1) GW150914-GBM.** Connaughton et al. (2016, *ApJL* 826, L6) reported a weak
hard-X-ray transient in *Fermi*-GBM starting 0.4 s after GW150914, lasting ~1 s,
with a location consistent with part of the LIGO arc. Against it: Savchenko et al.
(2016, *ApJL* 820, L36) set INTEGRAL/SPI-ACS upper limits inconsistent with a
signal of that strength; Greiner et al. (2016, *ApJL* 827, L38) reanalysed the GBM
data with a different background treatment and concluded the event is not
significant. Connaughton et al. (2018, *ApJL* 853, L9) responded defending the
detection. *Fermi*-LAT also searched (Ackermann et al. 2016 —
*identifier not verified*). The broadband follow-up campaign is Abbott et al.
(2016, *ApJL* 826, L13). **Status: unresolved, majority view is that it is not a
real counterpart.** Theoretical mechanisms invoked to explain it if real —
Loeb (2016, *ApJL* 819, L21) proposed a single rapidly-rotating massive star
fissioning into a BBH inside one envelope; Perna, Lazzati & Giacomazzo (2016,
*ApJL* 821, L18) proposed reviving a dormant disc around one hole; de Mink & King
(2017, *ApJL* 839, L7) considered residual matter from the progenitors — are all
model proposals with no independent confirmation.

**(2) ZTF19abanrhr / S190521g (= GW190521).** Graham et al. (2020, *PRL* 124,
251102) reported the first plausible optical counterpart to a candidate BBH merger:
a flare in an AGN, with no colour evolution (suggesting a constant-temperature
shock), which they argue is unlikely ($<\mathcal{O}(0.01\%)$) to be intrinsic AGN
variability, and consistent with a **kicked BBH merger ploughing through an AGN
accretion disc**. Their inferred parameters: $M_{\rm BBH}\sim100$ M☉,
$v_k \sim 200$ km s⁻¹ at $\theta\sim60°$, disc aspect ratio $H/a\sim0.01$, gas
density $\rho \sim 10^{-10}$ g cm⁻³, merger at a migration trap $a\sim700\,r_g$;
they predicted a repeat flare after
$\sim1.6\ \mathrm{yr}\,(M_{\rm SMBH}/10^8M_\odot)(a/10^3 r_g)^{3/2}$.
**The GW event itself is real and remarkable** — GW190521 is
$85^{+21}_{-14} + 66^{+17}_{-18}$ M☉ with remnant $142^{+28}_{-16}$ M☉, the first
intermediate-mass black hole from GWs, at $5.3^{+2.4}_{-2.6}$ Gpc (Abbott et al.
2020, *PRL* 125, 101102; implications in *ApJL* 900, L13). **The association is
not.** Ashton et al. (2021, *CQG*, doi 10.1088/1361-6382/ac33bb) re-analysed the
multi-messenger coincidence from the localisation overlap and found the odds of a
common source range between **1 and 12 depending on the waveform model**, which
they judge insufficient to confidently associate the two. A *Fermi*-LAT search
found no γ-rays from the flare direction and set 100 MeV – 300 GeV upper limits
(Podlesnyi et al. 2020, *Results in Physics* 19, 103579). The systematic ZTF
follow-up programme (Graham et al. 2023, *ApJ* 942, 99) has not produced a
confirmed counterpart.

**The AGN-disc-embedded merger scenario itself is respectable and independent of
those two claims.** Formation and dynamics: McKernan et al. (2012, *MNRAS* 425,
460; 2014, *MNRAS* 441, 900), Bartos et al. (2017, *ApJ* 835, 165), Stone, Metzger
& Haiman (2017, *MNRAS* 464, 946) — assisted inspirals in AGN discs — and Tagawa,
Haiman & Kocsis (2020, *ApJ* 898, 25). Predicted EM signature: Tagawa et al. (2023,
*ApJ* 950, 13) show jets launched by holes accreting in an AGN disc can appear as
peculiar IR/optical/X-ray transients, and argue this mechanism can explain both
ZTF19abanrhr and the GW150914-GBM/LVT151012-GBM γ-ray candidates *if* those
associations are genuine — and they are careful to condition on that.

**Bottom line for the sim.** A BH+BH merger in vacuum emits **nothing**. A BH+BH
merger inside gas emits something *late* (viscous refill, kick shocks, mass-loss
shocks) and *not* at the merger instant. Drawing a flash at coalescence would be
the one thing the literature is unanimous about not happening.

---

## 5. Converting your inelastic-energy budget into light

You book the kinetic energy lost inelastically in a merger. Here is where that
maps onto photons defensibly, and where it would be a fudge.

### Case A — defensible, with a published efficiency

**This is the one case where the mapping is real.** Pejcha et al. (2016b) state
their central result in exactly the form you need: in all their radiation-hydro
regimes, *the radiated luminosity reaches a fraction ~0.01 to 0.1 of
$\dot M v_{\rm orb}^2/2$*, where $\dot M$ is the mass outflow rate. That is a
published radiative efficiency for the conversion of outflow kinetic power to
light, and it is the correct quantity to multiply your booked energy loss by.
Pejcha et al. (2016a) separately quantify that the shock where the spiral arms
merge at $\sim10a$ thermalizes about **10%** of the outflow's kinetic power.

Consistency check against observation **[arith]** using Blagorodnova et al. (2021)
values for AT 2018bwo: $E_{\rm rad} \approx L\,t_p = 10^{40}\times41\ \mathrm{d}
= 3.5\times10^{46}$ erg; ejecta kinetic energy
$\tfrac12 M_{\rm ej}v^2 = 3.7\times10^{47}$ to $1.2\times10^{48}$ erg for
$M_{\rm ej} = 0.15$–0.5 M☉ at 500 km s⁻¹ ⇒ **$\eta_{\rm rad} \approx 0.03$–0.09**,
squarely inside the Pejcha range. Use $\eta_{\rm rad} = 0.05$ and you will not
embarrass anyone.

Sanity bound on the reservoir. Orbital energy at contact,
$|E_{\rm orb}| = Gm_1m_2/2a$ **[arith]**:

| system | $|E_{\rm orb}|$ |
|---|---|
| 2 × 1 M☉ MS, $a = 2$ R☉ | $9.5\times10^{47}$ erg |
| V1309 Sco-like (1.0+0.5 M☉, $a=5.6$ R☉, $P=1.4$ d) | $1.7\times10^{47}$ erg |
| M31LRN-like (4+0.3 M☉, $a=35$ R☉) | $6.5\times10^{46}$ erg |
| M101 OT-like (18+3 M☉, $a=100$ R☉) | $1.0\times10^{48}$ erg |
| 2 × 50 M☉ MS, $a = 24$ R☉ | $2.0\times10^{50}$ erg |

At $\eta_{\rm rad}\sim0.05$ these give $10^{45}$–$10^{49}$ erg radiated, bracketing
the observed $10^{46}$–$10^{48}$ erg. **Note the 50+50 case predicts ~$10^{49}$ erg,
an order of magnitude above anything observed** — flag that as an extrapolation.

**A second reservoir you must not double-count: recombination.** For $X=0.70$,
$Y=0.28$, the H + He recombination energy is **[arith]**

$$e_{\rm rec} = \frac{X\cdot13.598\,\mathrm{eV}}{m_H} + \frac{Y\cdot(24.587+54.418)\,\mathrm{eV}}{m_{He}}
= 1.445\times10^{13}\ \mathrm{erg\ g^{-1}}$$

giving $8.6\times10^{45}$ erg for 0.3 M☉ and $1.4\times10^{46}$ erg for 0.5 M☉ —
**a factor 2.5–4 short of AT 2018bwo's radiated $3.5\times10^{46}$ erg**. This is
precisely the tension Matsumoto & Metzger (2022) identify when they report that
several LRNe violate the maximum luminosity achievable from their donor, and it is
the observational argument for Metzger & Pejcha's (2017) shock power. **So: use
shock/kinetic power as the primary channel with $\eta\approx0.05$; treat
recombination as a floor that sets the plateau *temperature* (~3000–4000 K, the
hydrogen recombination temperature) rather than the total energy.**

### Case B — not defensible as a simple efficiency

The radiative efficiency of a micro-TDE is **not** a number you can multiply
through, because the flow is $4\times10^8$ times Eddington: photons cannot carry the
energy out. What actually sets the luminosity is the wind photosphere, and that is
a model. The published range spans three decades ($10^{41}$–$10^{44}$ erg s⁻¹,
Kremer et al. 2023) *precisely because* accretion-physics parameters dominate.
Perets et al. (2016) are explicit: the flare energy "depends on the poorly
constrained accretion processes", and significantly fainter flares result if most
of the disc mass is blown away.

**What you can do defensibly:** cap the emitted luminosity, take the total emitted
energy as $\eta_{\rm acc}\,f_{\rm bound}M_\star c^2$ with $\eta_{\rm acc}$ as an
explicit free parameter you state, and note that Perets et al. anchor it at
$f_{\rm acc}=0.1$ giving up to $10^{52}(M_\star/0.6M_\odot)$ erg. Do **not** set
$L = 0.1\dot M_{\rm fb}c^2$; that is the dashed line in panel (a) of the figure and
it is wrong by eight decades.

### Case C — the mapping is a fudge, and the correct answer is zero

The energy is not lost to heat. It is radiated as gravitational waves with an
efficiency near unity: $4.84\%$ of the total rest mass goes to GWs, and the
photon output is zero. Any conversion of the "inelastic loss" to light in Case C
is unphysical. **The correct implementation is the reverse of emission:** remove
4.84% of the total mass, apply zero recoil (equal-mass non-spinning) or a recoil
from a published fit (spinning/unequal), and let the *surrounding gas* light up
from the mass-deficit shocks (§4.4c: $a'/r_0 = 1.0536$, $e = 0.0508$) and the kick
shocks — delayed, not prompt.

---

## 6. WHERE THE THREE DIFFER MOST VISIBLY

Full machine-readable version: `merger-signatures-comparison.csv`.

| | **A — star + star** | **B — star + BH** | **C — BH + BH** |
|---|---|---|---|
| **literature name** | luminous red nova / CE-ejection transient | micro-TDE | BBH coalescence |
| **peak luminosity** | $10^{39}$–$10^{42}$ erg s⁻¹ ($10^{5}$–$10^{8}$ L☉) | $10^{41}$–$10^{44}$ erg s⁻¹ predicted | $L_{\rm GW}=3.7\times10^{56}$ erg s⁻¹; $L_{\rm EM}=0$ |
| **radiated energy** | $10^{46}$–$10^{48}$ erg (photons) | $10^{49}$–$10^{52}$ erg predicted | $8.6\times10^{54}$ erg in GWs; ~0 in photons |
| **rise** | days–weeks | hours in fallback, ~1 d observed (diffusion-limited) | none; GW amplitude peaks over ~1 orbit |
| **duration** | 30–300 d, double-peaked, 40 d plateau typical | 1 d – 1 month; $t^{-5/3}$ tail for years | $\tau_{220}=5.8$ ms (≈1 cycle); whole signal <0.5 s |
| **temperature** | 3000–6000 K → <1000 K → 30 K dust | $10^{5}$–$10^{6}$ K | n/a |
| **colour track** | **blue → red → IR**; TiO/VO bands; dust forms | **stays UV/blue**; no molecular phase | none |
| **geometry** | flattened dusty molecular **torus** + faster polar shell | two **streams** (½ unbound) → compact thick disc + optically thick wind | no emitting matter of its own |
| **spatial scale** | $10^{13}$–$10^{15}$ cm, growing at 200–500 km s⁻¹ | $r_t = 2.6\times10^{11}$ cm = 3.7 R☉; disc 4.7×10¹¹ cm | $r_s(M_f) = 2.8\times10^7$ cm = 281 km |
| **scale in $r_s$ of the hole** | n/a | $r_t/r_s = 1.7\times10^4$; $a_{\rm min}/r_s = 3.2\times10^4$ | merger completes inside ~10 $r_s$ |
| **ejecta** | 0.01–0.5 M☉ at 200–500 km s⁻¹ | ~0.5 $M_\star$ unbound at ~1200 km s⁻¹ | 0 baryonic |
| **decay law** | no clean power law; plateau then dust decline | $\dot M \propto t^{-5/3}$ (full) / $t^{-2.26}$ (partial); light curve ≠ $\dot M$ | exponential $e^{-t/\tau}$ |
| **recoil** | negligible | BH recoils off unbound debris (50:1 mass ratio) | **exactly 0** if equal-mass non-spinning; ≤5000 km s⁻¹ otherwise |
| **mass bookkeeping** | $m_1+m_2$ minus ejecta; no mass–energy loss | hole gains bound debris only, **not** $M_\star$ | $M_f = 0.95162(m_1+m_2)$: **4.84% deficit mandatory** |
| **KE → light efficiency** | **0.01–0.1** of outflow kinetic power (published) | $\ll1$, model-dominated; do not use $0.1\dot Mc^2$ | $\sim0$; energy goes to GWs |

**The single most visible difference is timescale and colour, not brightness.**
A spans months and reddens monotonically into an infrared dust cocoon. B spans
days and stays hot and blue/UV. C is over in milliseconds and is dark. The
brightness ordering ($L_C \gg L_B > L_A$) is only meaningful if you draw
gravitational-wave power, which no observer sees.

---

## 7. Model-dependence, and what the literature does not settle

### Measurement / model / convention, explicitly

| statement | status |
|---|---|
| $M_f/M = 0.95162$, $\chi_f = 0.68646$ for equal-mass non-spinning | **numerical solution of the Einstein equations** — as close to exact as anything here |
| QNM frequencies in §4.2 | **numerical solution** (Leaver's method), validated against published Schwarzschild value |
| GW150914 masses, remnant, peak luminosity | **measurement** with quoted 90% credible intervals |
| $r_t = R_\star(M_{\rm BH}/M_\star)^{1/3}$ | **order-of-magnitude scaling**, not a threshold |
| Hills mass $= 1.14\times10^8$ M☉ | **convention-dependent** — $2.20\times10^7$ M☉ if you use the ISCO instead of the horizon; both are "the Hills mass" in different papers |
| $\dot M \propto t^{-5/3}$ | **model**, from four assumptions, all of which are violated in simulations |
| $L_{\rm peak} = 10^{41}$–$10^{44}$ erg s⁻¹ for micro-TDEs | **model** with an explicit statement that the range is set by accretion-physics parameters |
| $\eta_{\rm rad}=0.01$–0.1 for LRNe | **model** (radiation-hydro), independently consistent with one observed event |
| V1309 Sco was a merger | **measurement** (pre-outburst photometry of the contact-binary progenitor) |
| V838 Mon was a merger | **model inference by elimination** — contested |
| ZTF19abanrhr ↔ GW190521 | **claimed association, statistically insufficient** (odds 1–12) |
| GW150914-GBM | **claimed detection, disputed by two independent analyses** |

### What the literature does not answer

1. **Disc formation in a micro-TDE has never been simulated with radiation
   hydrodynamics.** The supermassive case now has an ab-initio calculation
   (Steinberg & Stone 2024); the 10–100 M☉ case does not. Because relativistic
   apsidal precession is negligible there ($2.7\times10^{-4}$ rad per orbit), the
   circularisation mechanism is *qualitatively different* and unverified. **What
   would settle it:** a 3D radiation-hydro simulation of a $\beta\sim1$ encounter
   at $M_{\rm BH} = 10$–100 M☉ run from disruption through peak.
2. **No micro-TDE has been observationally confirmed.** Every luminosity, colour
   and timescale in §2.5 is a prediction. **What would settle it:** a Rubin/ULTRASAT
   detection of a fast blue UV transient spatially coincident with a dense star
   cluster, with the predicted $10^5$–$10^6$ K temperature.
3. **Which mechanism powers the LRN second peak** — hydrogen recombination
   (Ivanova et al. 2013; Matsumoto & Metzger 2022) or radiative shocks against
   pre-dynamical equatorial mass loss (Metzger & Pejcha 2017). **What would settle
   it:** resolved pre-outburst detection of the equatorial material's mass and
   extent, or spatially resolved polarimetry of the second peak.
4. **Whether V838 Mon was a stellar merger at all.** Alternatives are disfavoured,
   not excluded, and there is no progenitor binary detection. **What would settle
   it:** nothing now; the event is over. This is why V1309 Sco, not V838 Mon,
   should be your reference case.
5. **Whether any BBH merger has ever produced light.** Both claimed counterparts
   are contested at the level of "is this even a signal". **What would settle it:**
   a repeat flare from ZTF19abanrhr on the predicted ~1.6 yr timescale, or a second
   independent AGN-flare/GW coincidence with better localisation.
6. **The mass–radius relation to use for your star particles.** I deliberately did
   not import one — every Case B quantity in §2 is quoted at $R_\star = 1$ R☉ with
   its explicit scaling ($r_t \propto R_\star$, $t_{\rm min}\propto R_\star^{3/2}M_\star^{-1}M_{\rm BH}^{1/2}$,
   $\Delta\varepsilon = GM_{\rm BH}^{1/3}M_\star^{2/3}/R_\star$,
   $M_{\rm Hills}\propto R_\star^{3/2}M_\star^{-1/2}$) so you can plug in whichever
   relation your star-map lane adopts.
7. **LRN behaviour at 50 M☉ + 50 M☉.** No observed event has a confirmed
   progenitor pair above ~30 M☉. The energetics extrapolate to $\sim10^{49}$ erg
   radiated, above anything measured. Treat as extrapolation.
8. **Whether the ringdown overtone is detectable** — and therefore whether a
   multi-mode ringdown is a real observable or a single damped sinusoid. Contested
   (Isi et al. 2019 vs Cotesta et al. 2022).

### Places your current implementation is probably wrong

1. **A BBH merger must lose 4.84% of the total mass.** If mass is conserved, the
   merger is unphysical at the 5% level and the resulting shocks in surrounding
   material are absent.
2. **A 50+50 M☉ non-spinning merger gets zero kick.** Symmetry, not approximation.
3. **A 50 M☉ hole cannot swallow a main-sequence star whole** — $r_t/r_s = 1.7\times10^4$
   and the cross-section ratio is $\sim6\times10^{-5}$. Star + BH must always be a
   disruption.
4. **The hole does not gain the star's full mass** in a disruption: half the debris
   is unbound at ~1200 km s⁻¹, and much of the bound half leaves in the wind.
5. **Don't draw the V838 Mon light-echo shells as merger ejecta** — they are
   scattering off pre-existing interstellar dust, not material from the merger.
6. **Don't drive a light curve with $0.1\dot M_{\rm fb}c^2$** — the fallback rate at
   50 M☉ is $4\times10^8\,\dot M_{\rm Edd}$.
7. **Don't put a flash at the instant of a BBH coalescence.** Any counterpart is
   delayed by a viscous or shock-crossing time.

---

## 8. References

All identifiers below were retrieved with literature-search tools in this session
(OpenAlex `openalex_search_works`, arXiv `arxiv_search`/`arxiv_get_papers`, or by
fetching the article full text) unless explicitly marked
*identifier not verified*. **The DOI or arXiv ID is the tool-verified identifier in
every entry**; volume and article numbers are reproduced from the tool output where
it returned them and should be treated as secondary — check them against the DOI
before typesetting. Where no volume was returned, only the DOI is given.

**Count: 175 of 184 cited works carry a tool-verified DOI or arXiv ID (95%). The
remaining 9 are cited author + year + journal in prose and are explicitly marked
"identifier not verified" — do not invent identifiers for them.**

### Case A — luminous red novae / common-envelope ejection

- Martini, Wagner, Tomaney et al. 1999, *AJ* 118, 1034 — 10.1086/300951 (V4332 Sgr)
- Munari et al. 2002, *A&A* 389, L51 — 10.1051/0004-6361:20020715
- Bond et al. 2003, *Nature* 422, 405 — 10.1038/nature01508 (light echoes)
- Soker & Tylenda 2003, *ApJ* 582, L105 — 10.1086/367759
- Retter & Marom 2003, *MNRAS* 345, L25 — 10.1046/j.1365-8711.2003.07190.x
- Tylenda 2005, *A&A* 436, 1009 — 10.1051/0004-6361:20052800
- Tylenda & Soker 2006, *A&A* 451, 223 — 10.1051/0004-6361:20054201
- Afşar & Bond 2007, *ApJ* — 10.1086/509872 (B3 V companion; young cluster)
- Sparks et al. 2008, *AJ* 135, 605 — 10.1088/0004-6256/135/2/605 (distance $6.1\pm0.6$ kpc)
- Tylenda et al. 2009, *A&A* — 10.1051/0004-6361/200912312 (mass loss to 215 km s⁻¹)
- Tylenda et al. 2011, *A&A* 528, A114 — 10.1051/0004-6361/201016221 (**V1309 Sco progenitor**)
- Tylenda et al. 2011, *A&A* — 10.1051/0004-6361/201116858 (B3 V component vanished by 2009)
- Stępień 2011, *A&A* 531, A18 — 10.1051/0004-6361/201116689
- Chevalier 2012, *ApJL* 752, L2 — 10.1088/2041-8205/752/1/L2
- Ivanova et al. 2013, *Science* 339, 433 — 10.1126/science.1225540 (**CE identification**)
- Ivanova et al. 2013, *A&ARv* 21, 59 — 10.1007/s00159-013-0059-2 (CE review)
- Tylenda et al. 2013, *A&A* 555, A16 — 10.1051/0004-6361/201321647 (OGLE-2002-BLG-360)
- Kamiński et al. 2015, *A&A* 580, A34 — 10.1051/0004-6361/201526212
- Ivanova, Justham & Podsiadlowski 2015, *MNRAS* 447, 2181 — 10.1093/mnras/stu2582
- Nandez, Ivanova & Lombardi 2015, *MNRAS* 450, L39 — 10.1093/mnrasl/slv043
- Pejcha, Metzger & Tomida 2016a, *MNRAS* 455, 4351 — 10.1093/mnras/stv2592
- Pejcha, Metzger & Tomida 2016b, *MNRAS* 461, 2527 — 10.1093/mnras/stw1481
- Tylenda & Kamiński 2016, *A&A* 592, A134 — 10.1051/0004-6361/201527700
- MacLeod et al. 2017, *ApJ* 835, 282 — 10.3847/1538-4357/835/2/282 (M31LRN 2015)
- Blagorodnova et al. 2017, *ApJ* 834, 107 — 10.3847/1538-4357/834/2/107 (M101 OT2015-1)
- Metzger & Pejcha 2017, *MNRAS* — 10.1093/mnras/stx1768 (**shock-powered LRNe**)
- Pejcha et al. 2017, *ApJ* 850, 59 — 10.3847/1538-4357/aa95b9
- Kamiński et al. 2018, *Nat. Astron.* 2, 778 — 10.1038/s41550-018-0541-x (²⁶AlF in CK Vul)
- Kamiński et al. 2018, *A&A* 617, A129 — 10.1051/0004-6361/201833165
- MacLeod, Ostriker & Stone 2018, *ApJ* 863, 5 — 10.3847/1538-4357/aacf08 (runaway onset)
- Pastorello et al. 2019, *A&A* 630, A75 — 10.1051/0004-6361/201935999 (**LRN sample**)
- Howitt et al. 2020, *MNRAS* 492, 3229 — 10.1093/mnras/stz3542
- Schrøder et al. 2020, *ApJ* — 10.3847/1538-4357/ab7014 (compact object + core coalescence)
- Kamiński et al. 2021, *A&A* 646, A1 — 10.1051/0004-6361/202039634 (CK Vul)
- Blagorodnova et al. 2021, *A&A* 653, A134 — 10.1051/0004-6361/202140525 (AT 2018bwo)
- Pastorello et al. 2021, *A&A* 646, A119 — 10.1051/0004-6361/202039952 (AT 2019zhd)
- Lau et al. 2022, *MNRAS* 512, 5462 — 10.1093/mnras/stac049
- Matsumoto & Metzger 2022, *ApJ* 938, 5 — 10.3847/1538-4357/ac6269 (**LRN light-curve model**)
- Metzger 2022, *ApJ* — 10.3847/1538-4357/ac6d59 (WR/BH mergers → LFBOTs)
- Pastorello et al. 2023, *A&A* 671, A158 — 10.1051/0004-6361/202244684
- Karambelkar et al. 2023, *ApJ* 948, 137 — 10.3847/1538-4357/acc2b9 (ZTF-CLU rates)
- Webbink 1984 and de Kool 1990 for the $\alpha_{\rm CE}$ energy formalism, and
  Dewi & Tauris 2000 for the $\lambda$ structure parameter — *identifiers not verified*

### Case B — tidal disruption

- Hills 1975, *Nature* 254, 295 — 10.1038/254295a0
- Rees 1988, *Nature* 333, 523 — 10.1038/333523a0 (**the derivation**)
- Phinney 1989, *IAU Symp.* 136, 543 — 10.1017/S0074180900187054
- Evans & Kochanek 1989, *ApJ* 346, L13 — 10.1086/185567
- Cannizzo, Lee & Goodman 1990, *ApJ* 351, 38 — 10.1086/168442
- Kochanek 1994, *ApJ* 422, 508 — 10.1086/173745 (thin gas streams)
- Ulmer 1999, *ApJ* 514, 180 — 10.1086/306909
- Lodato, King & Pringle 2009, *MNRAS* 392, 332 — 10.1111/j.1365-2966.2008.14049.x (**is it really $t^{-5/3}$?**)
- Strubbe & Quataert 2009, *MNRAS* 400, 2070 — 10.1111/j.1365-2966.2009.15599.x
- Rosswog, Ramirez-Ruiz & Hix 2009, *ApJ* 695, 404 — 10.1088/0004-637X/695/1/404
- Burrows et al. 2011, *Nature* 476, 421 — 10.1038/nature10374 (Swift J1644+57)
- Bloom et al. 2011, *Science* 333, 203 — 10.1126/science.1207150
- Cenko et al. 2012, *ApJ* 753, 77 — 10.1088/0004-637X/753/1/77
- Kesden 2012, *PRD* 85, 024037 — 10.1103/PhysRevD.85.024037
- De Colle et al. 2012, *ApJ* 760, 103 — 10.1088/0004-637X/760/2/103
- Guillochon & Ramirez-Ruiz 2013, *ApJ* 767, 25 — 10.1088/0004-637X/767/1/25; erratum *ApJ* 798, 64 — 10.1088/0004-637X/798/1/64
- Stone, Sari & Loeb 2013, *MNRAS* 435, 1809 — 10.1093/mnras/stt1270
- Shen & Matzner 2014, *ApJ* 784, 87 — 10.1088/0004-637X/784/2/87
- Shiokawa et al. 2015, *ApJ* 804, 85 — 10.1088/0004-637X/804/2/85 (GR hydro disc formation)
- Piran et al. 2015, *ApJ* 806, 164 — 10.1088/0004-637X/806/2/164 (shock vs accretion power)
- Guillochon & Ramirez-Ruiz 2015, *ApJ* 809, 166 — 10.1088/0004-637X/809/2/166 (dark year)
- Stone & Metzger 2016, *MNRAS* 455, 859 — 10.1093/mnras/stv2281
- Bonnerot et al. 2016, *MNRAS* 455, 2253 — 10.1093/mnras/stv2411
- Metzger & Stone 2016, *MNRAS* 461, 948 — 10.1093/mnras/stw1394
- Perets et al. 2016, *ApJ* 823, 113 — 10.3847/0004-637X/823/2/113 (**micro-TDEs**)
- Roth et al. 2016, *ApJ* 827, 3 — 10.3847/0004-637X/827/1/3
- Auchettl, Guillochon & Ramirez-Ruiz 2017, *ApJ* 838, 149 — 10.3847/1538-4357/aa633b
- Wevers et al. 2017, *MNRAS* 471, 1694 — 10.1093/mnras/stx1703
- Dai et al. 2018, *ApJL* 859, L20 — 10.3847/2041-8213/aab429 (unified model)
- Lin et al. 2018, *Nat. Astron.* 2, 656 — 10.1038/s41550-018-0493-1 (IMBH TDE candidate)
- Fragione et al. 2018, *ApJ* 867, 119 — 10.3847/1538-4357/aae486
- Wevers et al. 2019, *MNRAS* 487, 4136 — 10.1093/mnras/stz1602
- Mockler, Guillochon & Ramirez-Ruiz 2019, *ApJ* 872, 151 — 10.3847/1538-4357/ab010f
- Golightly, Nixon & Coughlin 2019, *ApJ* 872, 163 — 10.3847/1538-4357/aafd2f
- Coughlin & Nixon 2019, *ApJL* 883, L17 — 10.3847/2041-8213/ab412d (**$t^{-9/4}$**)
- Kremer et al. 2019, *ApJ* — 10.3847/1538-4357/ab2e0c (**BH–MS TDEs in clusters**)
- Steinberg et al. 2019, *MNRAS Lett.* — 10.1093/mnrasl/slz048
- Liptai et al. 2019 — 10.48550/arXiv.1910.10154
- Lu & Bonnerot 2020, *MNRAS* 492, 686 — 10.1093/mnras/stz3405 (self-intersection, CIO)
- Nicholl et al. 2020, *MNRAS* 499, 482 — 10.1093/mnras/staa2824 (AT2019qiz outflow)
- Ryu et al. 2020, *ApJ* — 10.3847/1538-4357/abb3cc (relativistic, $M_{\rm BH}$ dependence)
- Krolik et al. 2020, *ApJ* — 10.3847/1538-4357/abc0f6 (varieties of disruption)
- Ryu et al. 2020, *ApJ* — 10.3847/1538-4357/abbf4d (TDEmass)
- Law-Smith et al. 2020, *ApJ* 905, 141 — 10.3847/1538-4357/abc489 (STARS library)
- Bonnerot & Stone 2021, *SSRv* — arXiv:2008.11731 (accretion-flow formation review)
- van Velzen et al. 2021, *ApJ* 908, 4 — 10.3847/1538-4357/abc258 (**17 ZTF TDEs**)
- Stein et al. 2021, *Nat. Astron.* 5, 510 — 10.1038/s41550-020-01295-8
- Cendes et al. 2021, *ApJ* 919, 127 — 10.3847/1538-4357/ac110a
- Matsumoto & Piran 2021, *MNRAS* 502, 3385 — 10.1093/mnras/stab240
- Gezari 2021, *ARA&A* 59, 21 — 10.1146/annurev-astro-111720-030029 (review)
- Angus et al. 2022, *Nat. Astron.* 6, 1452 — 10.1038/s41550-022-01811-y
- Yang et al. 2022, *ApJL* — 10.3847/2041-8213/ac7c0b (micro-TDEs in AGN)
- Hammerstein et al. 2023, *ApJ* 942, 9 — 10.3847/1538-4357/aca283 (**30 ZTF TDEs; Table 6 indices**)
- Kremer et al. 2023, *MNRAS* — 10.1093/mnras/stad2239 (**wind-reprocessed micro-TDE light curves**)
- Xin et al. 2023 — arXiv:2303.12846 (tidal peeling events)
- Ryu et al. 2023, *ApJL* — 10.3847/2041-8213/acc390 (extreme relativistic TDEs)
- Mummery et al. 2023, *MNRAS* 527, 2452 — 10.1093/mnras/stad3001 (**late-time plateaus**)
- Steinberg & Stone 2024, *Nature* 625, 463 — 10.1038/s41586-023-06875-y (**radiation-hydro to peak**)
- Rastello et al. 2026, *A&A* 707, A217 — 10.1051/0004-6361/202556781 (micro-TDEs in YSCs)

### Case C — binary black holes

- Vishveshwara 1970, *Nature* 227, 936 — 10.1038/227936a0
- Chandrasekhar & Detweiler 1975, *Proc. R. Soc. A* 344, 441 — 10.1098/rspa.1975.0112
- Detweiler 1980, *ApJ* 239, 292 — 10.1086/158109
- Leaver 1985, *Proc. R. Soc. A* 402, 285 — 10.1098/rspa.1985.0119 (**continued fraction**)
- Echeverria 1989, *PRD* 40, 3194 — 10.1103/PhysRevD.40.3194
- Kokkotas & Schmidt 1999, *Living Rev. Relativ.* 2, 2 — 10.12942/lrr-1999-2
- Pretorius 2005, *PRL* 95, 121101 — 10.1103/PhysRevLett.95.121101
- Milosavljević & Phinney 2005, *ApJ* 622, L93 — 10.1086/429618 (**afterglow / decoupling**)
- Berti, Cardoso & Will 2006, *PRD* 73, 064030 — 10.1103/PhysRevD.73.064030 (**QNM fits**)
- González et al. 2007, *PRL* 98, 091101 — 10.1103/PhysRevLett.98.091101 (non-spinning max kick)
- Campanelli et al. 2007, *PRL* 98, 231102 — 10.1103/PhysRevLett.98.231102 (superkick)
- Campanelli et al. 2007, *ApJ* 659, L5 — 10.1086/516712
- Bogdanović, Reynolds & Miller 2007, *ApJ* 661, L147 — 10.1086/518769 (spin alignment)
- Buonanno, Kidder & Lehner 2008, *PRD* 77, 026004 — 10.1103/PhysRevD.77.026004
- Lippai, Frei & Haiman 2008, *ApJ* 676, L5 — 10.1086/587034 (**prompt kick shocks**)
- Schnittman & Krolik 2008, *ApJ* 684, 835 — 10.1086/590363 (IR afterglow)
- MacFadyen & Milosavljević 2008, *ApJ* 672, 83 — 10.1086/523869 (**eccentric circumbinary disc**)
- Scheel et al. 2009, *PRD* 79, 024003 — 10.1103/PhysRevD.79.024003 (**$M_f$, $\chi_f$**)
- Berti, Cardoso & Starinets 2009, *CQG* 26, 163001 — 10.1088/0264-9381/26/16/163001 (review)
- Lousto & Zlochower 2009, *PRD* 79, 064018 — 10.1103/PhysRevD.79.064018
- Haiman, Kocsis & Menou 2009, *ApJ* 700, 1952 — 10.1088/0004-637X/700/2/1952
- Corrales, Haiman & MacFadyen 2010, *MNRAS* 404, 947 — 10.1111/j.1365-2966.2010.16324.x (**mass-loss + recoil disc response**)
- Zanotti et al. 2010, *A&A* 523, A8 — 10.1051/0004-6361/201014969
- Konoplya & Zhidenko 2011, *RvMP* 83, 793 — 10.1103/RevModPhys.83.793
- Lousto & Zlochower 2011, *PRL* 107, 231102 — 10.1103/PhysRevLett.107.231102 (hangup kicks)
- Lousto & Zlochower 2011, *PRD* 83, 024003 — 10.1103/PhysRevD.83.024003
- Barausse, Morozova & Rezzolla 2012, *ApJ* 758, 63 — 10.1088/0004-637X/758/1/63 (radiated mass)
- Komossa 2012, *Adv. Astron.* 2012, 364973 — 10.1155/2012/364973
- McKernan et al. 2012, *MNRAS* 425, 460 — 10.1111/j.1365-2966.2012.21486.x
- Sperhake et al. 2013, *PRL* 111, 041101 — 10.1103/PhysRevLett.111.041101
- McKernan et al. 2014, *MNRAS* 441, 900 — 10.1093/mnras/stu553
- Gold et al. 2014, *PRD* 89, 064060 — 10.1103/PhysRevD.89.064060
- Healy, Lousto & Zlochower 2014, *PRD* 90, 104004 — 10.1103/PhysRevD.90.104004
- Farris et al. 2014, *ApJ* 783, 134 — 10.1088/0004-637X/783/2/134 (**cavity streams, mini-discs**)
- Sperhake 2015, *CQG* 32, 124011 — 10.1088/0264-9381/32/12/124011
- Abbott et al. 2016, *PRL* 116, 061102 — 10.1103/PhysRevLett.116.061102 (**GW150914**)
- Abbott et al. 2016, *PRL* 116, 241102 — 10.1103/PhysRevLett.116.241102 (properties)
- Abbott et al. 2016, *PRL* 116, 221101 — 10.1103/PhysRevLett.116.221101; erratum *PRL* 121, 129902 — 10.1103/PhysRevLett.121.129902
- Abbott et al. 2016, *ApJL* 826, L13 — 10.3847/2041-8205/826/1/L13 (follow-up)
- Connaughton et al. 2016, *ApJL* 826, L6 — 10.3847/2041-8205/826/1/L6 (GBM claim)
- Savchenko et al. 2016, *ApJL* 820, L36 — 10.3847/2041-8205/820/2/L36 (INTEGRAL limits)
- Greiner et al. 2016, *ApJL* 827, L38 — 10.3847/2041-8205/827/2/L38 (GBM reanalysis)
- Loeb 2016, *ApJL* 819, L21 — 10.3847/2041-8205/819/2/L21
- Perna, Lazzati & Giacomazzo 2016, *ApJL* 821, L18 — 10.3847/2041-8205/821/1/L18
- Hofmann, Barausse & Rezzolla 2016, *ApJL* 825, L19 — 10.3847/2041-8205/825/2/L19 (final spin)
- Stone, Metzger & Haiman 2017, *MNRAS* 464, 946 — 10.1093/mnras/stw2260 (AGN-assisted inspirals)
- Bartos et al. 2017, *ApJ* 835, 165 — 10.3847/1538-4357/835/2/165
- de Mink & King 2017, *ApJL* 839, L7 — 10.3847/2041-8213/aa67f3
- Healy & Lousto 2017, *PRD* 95, 024037 — 10.1103/PhysRevD.95.024037 (remnant + peak luminosity)
- Keitel et al. 2017, *PRD* 96, 024006 — 10.1103/PhysRevD.96.024006 (**peak GW luminosity**)
- Connaughton et al. 2018, *ApJL* 853, L9 — 10.3847/2041-8213/aaa4f2
- Bowen et al. 2018, *ApJL* 853, L17 — 10.3847/2041-8213/aaa756
- d'Ascoli et al. 2018, *ApJ* 865, 140 — 10.3847/1538-4357/aad8b4
- Bowen et al. 2019, *ApJ* 879, 76 — 10.3847/1538-4357/ab2453
- Isi et al. 2019, *PRL* 123, 111102 — 10.1103/PhysRevLett.123.111102 (overtone claim)
- Stein 2019, *JOSS* 4, 1683 — 10.21105/joss.01683 (**`qnm` package used here**)
- Varma et al. 2019, *PRResearch* 1, 033015 — 10.1103/PhysRevResearch.1.033015 (surrogates)
- Abbott et al. 2020, *PRL* 125, 101102 — 10.1103/PhysRevLett.125.101102 (**GW190521**)
- Abbott et al. 2020, *ApJL* 900, L13 — 10.3847/2041-8213/aba493
- Graham et al. 2020, *PRL* 124, 251102 — 10.1103/PhysRevLett.124.251102 (**ZTF19abanrhr claim**)
- Tagawa, Haiman & Kocsis 2020, *ApJ* 898, 25 — 10.3847/1538-4357/ab9b8c
- Podlesnyi et al. 2020, *Results Phys.* 19, 103579 — 10.1016/j.rinp.2020.103579
- Ashton et al. 2021, *CQG* — 10.1088/1361-6382/ac33bb (**rebuttal: odds 1–12**)
- Abbott et al. 2021, *PRX* 11, 021053 — 10.1103/PhysRevX.11.021053 (GWTC-2)
- Abbott et al. 2021, *PRD* 103, 122002 — 10.1103/PhysRevD.103.122002 (tests of GR)
- Cotesta et al. 2022, *PRL* 129, 111102 — 10.1103/PhysRevLett.129.111102; Isi & Farr comment *PRL* 131, 169001 — 10.1103/PhysRevLett.131.169001
- Bogdanović, Miller & Blecha 2022, *Living Rev. Relativ.* 25, 3 — 10.1007/s41114-022-00037-8 (**review of EM counterparts**)
- Combi et al. 2022, *ApJ* — 10.3847/1538-4357/ac532a (mini-disc GRMHD, the lump)
- Graham et al. 2023, *ApJ* 942, 99 — 10.3847/1538-4357/aca480 (ZTF systematic search)
- Tagawa et al. 2023, *ApJ* 950, 13 — 10.3847/1538-4357/acc4bb (AGN-disc merger jets)
- Abbott et al. 2023, *PRX* 13, 041039 — 10.1103/PhysRevX.13.041039 (GWTC-3)
- Ruiz et al. 2023, *PRD* 108, 124043 — 10.1103/PhysRevD.108.124043
- Peters 1964, *Phys. Rev.* 136, B1224 (inspiral timescale); O'Neill et al. 2009
  (disc response to mass loss); Krolik 2010 (EM signatures of MBH binary
  coalescence); Ackermann et al. 2016 (*Fermi*-LAT search for GW150914);
  Teukolsky 1973 (perturbation equation); Shakura & Sunyaev 1973 (disc model) —
  *identifiers not verified*

### Companion files

- `merger-signatures-comparison.csv` — the §6 comparison table, machine-readable
- `tde-geometry-vs-bh-mass.csv` — disruption geometry, fallback timescale, Eddington
  ratio and GR precession from 10 M☉ to the Hills mass
- `ringdown-qnm-scaling.csv` — QNM frequencies/damping times for
  $(\ell,m,n)\in\{(2,2,0),(2,2,1),(3,3,0),(2,1,0),(4,4,0)\}$ at $\chi=0$ and
  $\chi=0.68646$, with per-solar-mass scalings
- `ztf-tde-decay-indices.csv` — the 30 published power-law decay indices from
  Hammerstein et al. (2023) Table 6
- `merger-signatures-figure.png` — luminosity–time plane for all three cases, and
  the $r_t/r_s$ constraint versus black hole mass
