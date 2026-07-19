# RESEARCH — How NASA makes nebulae look like that (for the volumetric medium)
**Written:** 2026-07-19 23:14:00. Sources at bottom. Feeds `DESIGN_2026-07-19_volumetric_medium.md`.

## 1. THE PALETTE — what the colors actually are
**Hubble palette (SHO), the Pillars look:** three NARROWBAND emission lines mapped
to RGB channels — **SII→Red, Hα→Green, OIII→Blue** (Hα and SII are both red in
reality; the remap separates them). The iconic gold/rust = SII = cooler, denser,
shocked gas at **boundaries and edges**; teal/blue = OIII = hotter, energetic gas
near the ionizing stars. The famous look is a STATE→CHANNEL mapping, not natural
color. → For us: excitation state (temp/density) drives the channel — our
`supernovaRamp` is the right kind of object; the research validates keying it to
LOCAL state and putting SII-gold at shock/boundary zones (we can tag shocks via
deltaAmp / velocity divergence).

**Chandra supernova remnants (Cas A / Kepler):** colors = ELEMENTS — Si red,
S yellow, Ca green, Fe purple, blast-wave/high-energy continuum blue. → For us:
we carry a REAL per-particle element proxy already — the IMF mass. Play/supernova
bursts can map mass-bins → element colors (heavy = Fe purple / Si red) = the
remnant variety with zero fake data.

**JWST Pillars (NIRCam/MIRI):** densest dust = **deep indigo / DARK** (extinction
blocks background light); pillar EDGES carry glowing red "lava" rims (jets +
shocked gas where stars form); gas is semi-transparent. → the pillar body is a
SILHOUETTE, not a glow.

## 2. THE PHYSICS NUMBERS (grounds the warm trap)
- HII-region gas: **T ≈ 8,000–10,000 K** (5–20 kK range), density 10–10⁵ cm⁻³.
  Warm, not hot: thermal σ ≈ 10 km/s vs photoevaporation flows 20–40 km/s
  (mildly supersonic). → the jitter scale for the warm trap: **thermal σ ≈
  0.3–0.5× the organizing-flow speed** — enough to puff volume, not enough to
  erase structure.
- Pillars = **photoevaporation**: UV from OB stars erodes the molecular cloud;
  the ionization front on the pillar SURFACE is the bright rim; the interior
  stays cold/dusty/dark; pillars point at the ionizing stars; dense cores get
  radiatively compressed. Structure = illuminated erosion, not sculpted force.

## 3. ⚠️ THE FINDING THAT CHANGES THE DESIGN — EXTINCTION
The Pillars' look decomposes into FOUR layers: (a) luminous colored ambient (the
HII glow), (b) **DARK dense silhouette bodies** (dust extinction), (c) thin
bright rims where (b) meets (a) (the ionization front), (d) red jets at tips.
**(b) is ABSORPTION.** Our pipeline is additive-only — additive light can NEVER
make a dark pillar in front of glow, no palette or tonemap can fix that. The
pros (Splotch, SPH volume rendering) composite **emission AND absorption** along
the ray. → the design needs a DUST STATE rendered as an absorbing splat
(destination × (1−α), a per-pass Metal blend-state change), drawn before/with
the emissive passes. Rim brightening then EMERGES free: the rim is where the
absorbing body cuts into the emissive ambient.

## 4. What this maps to in OUR engine (no new data invented)
| Reference thing            | Our existing state                     | Render state |
|----------------------------|----------------------------------------|--------------|
| OIII teal (hot, energetic) | high currentTemp / near excitation     | emissive ramp high band |
| Hα red/green channel (bulk ionized) | mid temp, mid density         | emissive ramp mid band |
| SII gold (shocked edges)   | deltaAmp spike / velocity divergence   | emissive ramp low band, boundary-tagged |
| SNR element colors         | IMF mass bins (heavy = Si/Fe)          | play-burst palette |
| Dust indigo silhouettes    | cold + dense (low temp, high cellMass) | **ABSORBING splat (new blend state)** |
| Ionization-front rims      | absorber adjacent to emitter           | emerges from extinction — free |
| Star points                | massive/compact                        | blackbody sprite (unchanged) |

## 5. THE WAVE SCIENCE (added 2026-07-19 23:26 — Jamal's order: research the
## wave itself, not the gas)

**a) Single mode → skins is a THEOREM, not a bug.** The Gor'kov potential of one
mode, U ∝ Ψ², has its minima on Ψ's zero set — and for any single product-form
mode (ours: J_m(k_ρρ)·cos(mθ)·cos(k_z z)) that zero set is a UNION OF SURFACES
(nodal cylinders + planes). 3D-cavity experiments confirm: single-frequency bulk
acoustic waves arrange particles onto 3D nodal-surface Chladni patterns. Every
fix we threw at a single held note (contrast, thermal kicks, killing the sculpt
and sun-shell) was fighting this mathematics. A lone note CANNOT fill volume.

**b) MULTIPLE FREQUENCIES → the potentials ADD → volume.** Different frequencies
don't interfere time-averaged: U_total = ΣᵢUᵢ. The minimum set of a SUM is the
INTERSECTION of the individual nodal surfaces — two modes → curves, three+ →
POINT LATTICES / cellular structure through the volume. This is exactly how
acoustic-hologram levitation builds 3D trap arrays, and "spectral holographic
trapping" (polyphonic waves → 3D force landscapes) is literally the published
name. **A CHORD IS THE VOLUMETRIC MECHANISM. Polyphony = geometry.** Our code
already sums per-voice Gor'kov forces (= ∇ΣΨᵢ²) — the physics is coded; a
single note is simply the degenerate case.

**c) ACOUSTIC (RAYLEIGH) STREAMING — the missing volumetric MOTION.** Real
standing-wave cavities drive a second-order mean flow: toroidal vortex cells
with half-wavelength periodicity filling the resonator core, circulating matter
node↔antinode continuously. The real medium never settles onto the nodal set —
it CYCLES through the volume. We have zero streaming; adding the analytic
Rayleigh cell field as a weak velocity bias = physical, perpetual volumetric
circulation (and Jamal's "interconnectivity").

**Implications, in order:**
0. FREE TEST, no build: hold a spread 3-NOTE CHORD → theory predicts the skin
   breaks into cellular/lattice structure. Validates (b) in-engine.
1. Single-note volume: spawn each voice's OVERTONES as 2–3 partials mapped to
   DIFFERENT (m,n,p) cavity modes (the synth's harmonic series → a mode ladder)
   → ΣΨᵢ² is cellular even for one key. Timbre becomes geometry.
2. Rayleigh streaming cells for living circulation. Warm trap stays as softener.

## Sources
- [The Astro Manual — narrowband/Hubble palette](https://theastromanual.com/narrowband-astrophotography-ha-oiii-sii/)
- [AAA — Pillars of Creation: Using the Hubble Palette](https://aaa.org/2020/06/23/pillars-of-creation-using-the-hubble-palette/)
- [SkyShare — Ha/OIII/SII explained](https://www.skyshare-astro.com/blog/narrowband-imaging-guide)
- [COSMOS (Swinburne) — Emission Nebula](https://astronomy.swin.edu.au/cosmos/E/emission+nebula)
- [Britannica — H II region](https://www.britannica.com/science/H-II-region)
- [arXiv — Formation of pillars at HII/molecular-cloud boundaries](https://arxiv.org/pdf/astro-ph/0604545)
- [arXiv — Photoevaporation flows in blister HII regions](https://arxiv.org/pdf/astro-ph/0504221)
- [Chandra — Investigating supernova remnants](https://www.chandra.si.edu/edu/formal/snr/bg5.html)
- [Chandra — Cassiopeia A photo album](https://chandra.harvard.edu/photo/2025/casa/)
- [NASA — Kepler supernova remnant](https://www.nasa.gov/universe/kepler-supernova-remnant/)
- [NASA Science — Pillars of Creation (NIRCam)](https://science.nasa.gov/asset/webb/pillars-of-creation-nircam-image/)
- [Webb — Pillars NIRCam+MIRI composite](https://webbtelescope.org/contents/media/images/01GK2KKTR81SGYF24YBGYG7TAP)
- [arXiv — JWST extinction mapping of the Pillars](https://arxiv.org/pdf/2406.03410)
- [arXiv — Splotch: visualizing cosmological simulations](https://arxiv.org/pdf/0807.1742)
- [arXiv — SPLASH SPH visualisation](https://arxiv.org/pdf/0709.0832)
- Wave science (§5):
- [Nature Comms — Holographic acoustic elements (3D trap arrays)](https://www.nature.com/articles/ncomms9661)
- [arXiv — Spectral holographic trapping: polyphonic waves](https://arxiv.org/pdf/2312.03794)
- [Sci Rep — Multitone acoustic radiation force (beat/time-averaged)](https://www.nature.com/articles/s41598-022-19077-9)
- [PRApplied — Particle-size effect: nodes vs antinodes](https://doi.org/10.1103/PhysRevApplied.18.034026)
- [ResearchGate — 3D Chladni via standing bulk acoustic waves in a cylindrical cavity](https://www.researchgate.net/publication/345988503_Dexterous_formation_of_unconventional_Chladni_patterns_using_standing_bulk_acoustic_waves)
- [ResearchGate — Rayleigh streaming source-term analysis](https://www.researchgate.net/publication/321089726_Acoustic_Rayleigh_streaming_Comprehensive_analysis_of_source_terms_and_their_evolution_with_acoustic_level)
- [PRE — Periodic Rayleigh streaming vortices](https://link.aps.org/doi/10.1103/PhysRevE.104.045104)
- [arXiv — Directed acoustic assembly in 3D](https://arxiv.org/pdf/2210.07153)
