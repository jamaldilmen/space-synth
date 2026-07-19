# DESIGN — The Volumetric Medium (Chladni/supernova rethink from scratch)
**Written:** 2026-07-19 23:02:00. Status: PROPOSAL — nothing built. Jamal's order:
"totally rethink the Chladni supernova volumetric issue from scratch."

## The one-sentence diagnosis
Every shape organizer we have is a potential-seeker (F = −∇U), and the minima of
every U we've built are **surfaces** (sphere shells, Ψ=0 nodal sets, antinodes) —
so no matter which force wins, matter collapses onto 2D skins and the interior is
vacuum. The acoustic-contrast split (2026-07-19) proved it: two families of
surfaces is still zero volume.

## Jamal's framing (2026-07-19 23:2x) — THE 3D WAVE, not the 2D readout
The Chladni plate is a 2D READOUT of a 3D wave: sand seeks nodes only because
gravity pins it to the membrane and antinodes kick it off — a plate-specific
mechanism. The wave itself, Ψ(x,y,z), FILLS the volume; its nodal surfaces are
internal zeros of a filled field. The true 3D Chladni figure is an ELECTRON
ORBITAL: matter ∝ |Ψ|² — graded lobes and shells occupying volume. Our Gor'kov
force (drive everything to Ψ=0) is the sand-on-a-plate special case wrongly
transplanted to 3D. The warm-trap equilibrium ρ ∝ exp(−U/kT) IS the |Ψ|²-shaded
filled cloud — increment 1's pass/fail: density visibly tracks the wavefunction
through the volume (orbital lobes/shells), not its zero-surfaces.

## What real volume is (the physics, not a trick)
A real nebula is not force-balance on a surface — it is **temperature vs.
potential**: ρ(x) ∝ exp(−U(x)/kT). Warm matter in a trap fills the trap, dense
at the potential floor, graded outward, occupying VOLUME with structure. The
Pillars of Creation are exactly this: gas held puffed by pressure inside a
sculpting field. Cold trap → skins (what we have). Warm trap → volume.

We already own every ingredient:
- U — the cavity eigenmode Ψ (Gor'kov U = ½φΨ², per-id contrast φ shipped today)
- per-particle temperature — `currentTemp` / prevW.w, live and evolving
- per-particle mass — IMF, deterministic
- a Brownian jitter force — bit21, currently a flat global constant
- an emission-line ramp — `supernovaRamp` (Hα→[OIII]→Hβ→X-ray), play-gated
- soft sprites + asinh tonemap — the gaseous light path (shipped today)

## The design — three increments, one verifiable change each

### 1. THE WARM TRAP (fills the volume)
Langevin dynamics: keep F = −φΨ∇Ψ, add per-particle thermal agitation scaled by
the particle's OWN temperature — re-key the existing bit21 jitter from its flat
constant to σ ∝ √(currentTemp). Hot matter rides high above the nodal floors,
cool matter hugs them → the tube interior fills with a graded, breathing medium;
structure survives because density still peaks at the nodal surfaces.
- One change: jitter amplitude = f(currentTemp) inside the play stack.
- Verify: new read-only [VOLUME] probe — occupancy histogram over |Ψ| bands
  (skin = bimodal spike at Ψ≈0; volume = broad occupancy). Then his eyes.
- Risk: too hot = mush. The temp scale is physical (heat comes from the real
  flare/compression path), not a new knob.

### 2. THE GAS STATE (the Pillars palette)
"Stars / SN-gas / photon ring = the same light in different states"
([[space_synth_supernova_gas_vision]] — this IS that canon item). One population,
two render states by the particle's own state, no second layer:
- **Star state** (massive / cool / compact): blackbody-of-mass, point sprite —
  unchanged, physically correct.
- **Gas state** (light / hot / diffuse — e.g. low IMF mass OR temp above
  threshold): the emission-line ramp keyed to LOCAL density+temp (the trilinear
  read shipped today), drawn as the soft/low-alpha sprite (grainAlpha/sharpness
  path). Gas glows Hα red → [OIII] teal → Hβ cyan exactly where the medium is
  excited — the Pillars variety, at rest too, from real state.
- Verify: rest field shows colored diffuse structure BETWEEN white/orange stars.

### 2b. THE DUST STATE — EXTINCTION (added 2026-07-19 23:16 from the research
hunt, `RESEARCH_2026-07-19_nebula_gas_reference.md` §3). The Pillars' bodies are
DARK — dust silhouettes absorbing background glow — and additive light can never
render dark-in-front-of-bright. The cold+dense population must draw as an
ABSORBING splat (destination × (1−α); a per-pass Metal blend-state change),
alongside the emissive passes — the Splotch/SPH-volume-rendering approach. The
iconic bright RIMS then emerge free: a rim is where an absorbing body cuts into
the emissive ambient. Without this increment there are no pillars, only glow.
Verify: a dense cold clump in front of the glowing field reads as a dark
silhouette with a lit edge.

### 3. GEODESIC WEBBING (the interconnectivity — LAST)
Replace the 60× ad-hoc chord webbing with curves that follow the cavity's own
gradient field between nodal regions (the non-Euclidean-video idea: straight
lines of the medium's geometry). Only after 1+2 stand — it decorates structure
that must exist first.

## Non-goals (locked)
- No second render layer, no overlays — [[feedback_no_second_layer]], BH canon.
- Stars keep blackbody truth; the BH stays the particles; play feel + the new
  eigenmode default + FPS gains stay untouched.
- No global phase gates — states flip per-particle on local thresholds
  ([[space_synth_powder_toy_lessons]]).

## Order of work
1 → verdict → 2 → verdict → 3. Each is one buildable change with its own probe.
