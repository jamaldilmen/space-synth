# HANDOFF — SONIFICATION: EVERY PARTICLE IS A VOICE
**Written:** 2026-07-29 15:05:01
**Session:** 2026-07-26 → 2026-07-29, design + research only.
**Code written: NONE. Nothing built, nothing committed.**

**Cold start order:**
1. this file
2. `docs/DESIGN_2026-07-28_field_sonification.md` (v2 — the spec)
3. `docs/RESEARCH_2026-07-26_nasa_sonification.md` (how NASA does it)

**Tree state at writing:** `b047744` + uncommitted work from parallel sessions (stars, Chladni
audit). The sonification touched no source files.

---

## 0. WHAT THIS SESSION WAS

Jamal opened a new direction: the sound of the universe in SPACE SYNTH.

> "attack decay release are already kinda linked to the universe. but what about lfos. arps.
> how the real time location of the particles reflects to the sound the engine makes. and
> how were gonna pull that off."

It became a full architecture. No code — the whole session is design, research, and
measurement of numbers that already exist.

---

## 1. THE DECISION, IN HIS WORDS

Three architectures were offered. He chose **B — the field IS the sound source.**

> "The sim sounds whether you play or not... this truth is what i want. i want it to be like
> a meditation tool if u dont play it. like an everplaying song. and you know how we roll it
> needs to be scale accurate to reality."

> "the field must be the oscillator and the resonance too. it must have an eerie sound at
> rest.. like the silver surfer would listen to it while he cooks"

> "what do 2 mio stars sound like yknow. like. every particle is a part of the oscillator you
> get me as in the actual universe"

> "the shape is the sound... more to the shape than just size... position phase temperature.
> all of it needs to be part of the sound. so 2 mio oscillators / voices with their own
> property. pausable. i want to eventually pause the simulation and click on a star. solo it.
> see stats about it."

Also decided: **you play THE FIELD, not over it.** MIDI/MPE injects energy into the sim; the
only voice is ever the field's own. A synth layered over the drone is the audio form of the
painted disc killed on 2026-07-24 (`feedback_no_second_layer`).

Two hard constraints from him: **it never stops** (silence at rest is the bug), and
**scale accurate** (every frequency traceable to the metric).

---

## 2. THE GOVERNING PRINCIPLE

> **Define the per-particle voice FIRST. The ensemble sound is the SUM of those voices.
> Any binning or grouping is an OPTIMISATION of that sum, justified against it.**

Consequences, free:
- **Solo = the same law with N=1.** Pause, click a star, hear its own voice. Not bolted on.
- **Every property can participate** — position, mass, temperature, velocity, phase.
- **Pausable by construction.** Frequency comes from GEOMETRY (where a particle is), not from
  motion. Paused, a particle holds its note. Same principle as the time-lapse: "it's the
  maths, runs even when paused."

Inverting this order (histogram first) makes solo impossible without a rewrite. **Do not invert it.**

---

## 3. ⚠️ THE BIG RETRACTION — v1 WAS WITHDRAWN

**v1 of the design made the existing 256-shell RADIAL mass profile
(`radialMassStableBuffer`) the representation.** It was attractive because it already runs
over every particle every frame, flicker-free, shared storage, zero new GPU work.

**It is wrong, fatally, for this instrument.**

A radial histogram is **rotationally symmetric**. It bins by distance from centre only, so it
cannot distinguish a ring from a spiral from two clumps on opposite sides — all three give an
identical profile and would sound identical.

**Chladni structure is ANGULAR.** The m lobes are the entire point. Radius-only binning
discards exactly the geometry this instrument exists to express. It also has no particle
identity, so solo is impossible.

**Root cause of my error: I designed around the buffer that happened to exist instead of
around what the sound requires.** Jamal caught it with "the shape is the sound."

Also retracted from v1: a proposal to reduce the field to 3–5 ring "peaks", justified by the
sonification literature's ~3-simultaneous-stream limit. **Wrong** — that limit governs stream
*segregation* (a listener consciously tracking separate streams, NASA's analytic goal). We
want **fusion**: an orchestra is 80 players, a choir 100 voices, and they fuse into one
timbre. Fusion has no such limit. Jamal caught this too.

---

## 4. THE LAW — one constant, and it is a power of two

```
S = 2^16 = 65536
f_audible(r) = S · √(GM/r³) / (2π · 5.854202 s)
```

Uniform time scaling. Every ratio, interval and beat survives **exactly**. A power of two
makes it a transposition, which also preserves pitch class.

**This is NASA's actual published method.** Perseus (NASA/CXC 2022): sound waves *"extracted
in radial directions, that is, outwards from the center,"* transposed up **exactly 57 and 58
octaves**. We derived the same law from `spacetime.h` before looking it up.

**REJECTED: linear frequency shift** (LIGO's +400 Hz). It destroys every ratio — a fifth stops
being a fifth. LIGO can afford it with one signal and no harmony. We cannot.

### TWO CLASSES OF CONSTANT — the rule that prevents a future fight
1. **Physics constants must DERIVE from `spacetime.h`.** Untraceable = bug.
2. **Listener constants are LEGITIMATE.** The ~20 Hz pitch floor, the ~120 Hz localisation
   limit, critical bandwidth — these describe *the ear*, not the universe. The instrument is
   for a human. Using them is not cheating.

---

## 5. MEASURED NUMBERS (computed from `spacetime.h`, gmSim = 0.4123)

### Where the disk lands

| radius | real orbital period | ×2¹⁶ |
|---|---|---|
| horizon r_s 0.825 | 41 s | 1528 Hz |
| ISCO 2.474 | 223 s | **294 Hz** (≈D4) |
| r = 3 | 270 s | 220 Hz (A3) |
| r = 6 | 842 s | 78 Hz |
| r = 12 | 2382 s | 27.5 Hz |
| R_DISK 18 | 4375 s | 15 Hz |

Three things fall out that nobody designed:
- **The disk spans 3.9–4.3 octaves natively.** The instrument's range is Kepler's.
- **The 20 Hz line — rhythm becomes pitch — falls at r ≈ 14.85**, inside R_DISK = 18. The
  outer disk is literally the rhythm section, the inner disk the chord, and the boundary is a
  real radius.
- **2:1 rings = exactly an octave. 3:2 = exactly a perfect fifth** (radius ratio 1.3104).

### Ensemble thickness — the disk is its own chorus
Shell of width dr spans Δf/f = 1.5·dr/r. At the existing 256-shell resolution:

| radius | band width |
|---|---|
| 0.82 (horizon) | 61 cents |
| 1.5 | 34 cents |
| 2.47 (ISCO) | 20 cents |
| 5.0 | 10 cents |

A real string section spreads 10–30 cents; analog chorus detune is 5–25. **The ensemble
thickness falls out of the geometry.** And ~7,800 particles per shell at uncorrelated phase
inside a 20-cent band is, mathematically, **narrowband noise**. That is what a crowd of stars
is.

**Therefore noise and tone are the same object:** smeared mass = a wash (the honest sound of
smooth matter); mass collapsing into a ring = a pitch emerging from it. There is no anti-mush
mode to build. The quantized L-wall rings reported as a *visual bug* on 2026-07-25 are exactly
what gives the drone notes.

---

## 6. THE MIX — his engineering and the physics are the same rules

His brief:
> "a bass is one voice. a moog is the best bass synth cause its mono. so the bass oscillator /
> sub should be one voice still. then 300 ish we do a bit of width, most lives in the low mid
> to hi mid area. the challenge is gonna be summing all of that in a way that makes sense,
> dynamically figuring out pan and spread. which particle becomes the bass one. is it a
> position thing?"

### 6.1 Bass is centre, ALWAYS — unconditional, not a safety net
Below ~120 Hz humans cannot localise a source. Class-2 constant, legitimate.
In our field that lands at **r ≈ 4.4**:
- outside r ≈ 4.4 → **mono, always, playing or not**
- inside r ≈ 4.4 → θ-panning

So the stereo image is made entirely by the **inner disk**; the whole outer bulk is a mono
bed. Bass never wanders. (He pushed back asking for exactly this; the design already had it,
I had described it too weakly as a "safety net".)

**Honest flip side:** shape forming at large radius cannot be heard as *position* — no sound
down there can be. It must express itself as level and beating instead.

### 6.2 Pan = angular position. Spread = angular asymmetry. **SHAPE IS THE STEREO IMAGE.**
- axisymmetric field (rest) → contributions cancel → **centred, narrow**
- angular structure (m lobes, clumps, arms) → no cancellation → **the image opens**

Stereo width is a *direct measurement of how much shape exists*. Not a heuristic to tune.
**This is the strongest single argument for v2 over v1** — a radial histogram has no θ, so
under v1 the stereo image could not exist at all.

### 6.3 ⚠️ THE MUD PROBLEM AND ITS PHYSICAL FIX
**Amplitude must NOT be mass.** The disk spawns density ∝ r^-0.3 out to R_DISK = 18, so most
mass sits at large radius = low frequency. Mass-weighting piles nearly all energy below
100 Hz — everything in the sub, exactly the failure he warned about.

Real disks radiate by viscous dissipation, which **peaks just outside the inner edge**. That
is Shakura–Sunyaev, and **the function already exists** at `render.metal:213`:

```c
ssDiskTempShape(r, r_in) = (r_in/r)^0.75 · (1 − √(r_in/r))^0.25    // zero inside r_in
```

Weighting by **emission** moves the energy to the inner disk — the low-mid to hi-mid — leaving
the vast slow outer disk as quiet sub. Exactly the balance he described, arrived at by the
physically correct law. **The mix balance is thermodynamics.** No EQ tilt, no tuned constant.

### 6.4 Which particle is the bass one?
None — it is a *region*: the outer disk, summed, folded to mono. A soloed star plays at its
own ω wherever that lands; solo bypasses the mix entirely.

---

## 7. WHAT THE BLACK HOLE DOES — subtractive, always

**It adds no sound.** `shadow = absence, never paint` (2026-07-24) applied to audio. A black
hole you *add* is the overlay feel.

1. **Silence inside the horizon** — a real hole in the spectrum. Already gated
   (`render.metal:408`).
2. **It EATS THE TREBLE FIRST.** Small radius = high frequency; the growing r_h swallows the
   smallest radii first. **Accretion is a low-pass filter closing over time.** The instrument
   darkens as the hole feeds. Emergent, not scripted.
3. **Gravitational redshift** √(1−r_s/r) — pitch flattened near the hole. Already in
   `poseOmegaEff` (`render.metal:356`). ⚠️ floored at 0.4, not truthful at the horizon.
4. **Doppler** → pitch shift *and* level. Already split colour-vs-beaming for the visuals
   (`render.metal:245`). ⚠️ `DOPPLER_K_COLOR` 5.0 / `DOPPLER_K_BEAM` 0.8 are **visual tuning**;
   audio must use the true relativistic factor.
5. **κ → 0 at ISCO** — the resonance dies. §8.

---

## 8. THE RESONATOR — where the eerie comes from

Oscillator = ω(r), orbital. **Resonator = κ(r)**, the radial epicyclic frequency: displace
matter radially and it rings.

```
κ(r) = ω(r)·√(1 − 6GM/r)          (Schwarzschild)
```

It vanishes at r = 6GM, **which is ISCO**. Not a filter sweep — a resonance that detunes
downward and then **ceases to exist** at a fixed radius. That is the eerie, and it is exact GR.

### The exact theorem
```
dκ²/dr = GM·r⁻⁵·(24GM − 3r) = 0  →  r = 8GM
ω:κ = 2  →  1 − 6GM/r = ¼        →  r = 8GM
```
**The strongest radial resonance sits exactly where it stands in 2:1 with the orbit.** Both
analytic, confirmed numerically.

| | radius (sim) | ω | κ | ω:κ |
|---|---|---|---|---|
| ISCO | 2.474 | 294 Hz | **0 Hz** | resonance dies |
| κ peak | 3.298 | 191 Hz | 95.5 Hz | **2.0000 — octave** |
| 3:2 | 4.453 | 122 Hz | 81 Hz | **1.5000 — fifth** |

All inside the existing 0..5 radial profile.

**The 3:2 is OBSERVED in real black holes** — GRO J1655−40, XTE J1550−564, GRS 1915+105,
H1743−322 (Abramowicz & Kluźniak 2001 epicyclic resonance model). Real black holes ring at a
perfect fifth. We would reproduce a measurement, not invent a mapping.

**Newtonian check (and a sanity check on our own formula):** at large r, √(1−6GM/r) → 1 so
κ → ω. In Newtonian gravity κ = ω *everywhere* — ω:κ = 1:1, unison, no harmony at any radius
(closed ellipses). **The disk has harmony BECAUSE gravity is relativistic.** In a Newtonian
universe this instrument plays one note.

⚠️ **These are TEST-PARTICLE GEODESIC frequencies** — one weightless speck, alone, nothing
touching it. Our field is N-body with self-gravity *and* SPH pressure, both of which shift the
ringing. κ is the resonance **the geometry wants**, not a measured fact about our disk.
**DO NOT hardcode κ as a tone — that is painting the resonance**, the same error class as the
painted disc. Measure, then compare. Either outcome is a real result.

---

## 9. PHASE — already solved by the counter-rotation fix

The synthesis needs a phase per voice. `posePhase[]` (`render.metal:383`, landed `5d8fa5b`
2026-07-26) is exactly it:

```
posePhase[vid] += poseOmegaEff(r, GM, r_h) * bhPoseDt      // wrapped to [0, 2π)
```

∫ω(r)dt — the true orbital angle, per particle, on the GPU. **The fix built for the
counter-rotation bug is the sonification's phase source.**

⚠️ **TWO per-particle phases exist. Do not confuse them:**

| | what it is | where |
|---|---|---|
| `velW.w` low 29 bits | ∫\|v\|dt — path length, "Feynman arrow". **WRONG for audio.** | `particles.metal:2772`, packed 2945 |
| `posePhase[]` | ∫ω dt — **true orbital angle. This one.** | `render.metal:383` |

(`velW.w` upper 3 bits = which of the 6 VJ audio bands — the existing *input*-audio link.)

⚠️ `pose_phase_advance` is gated on bit20 + `bhDiskAxisY < 0.5` — **time-lapse mode only.**
Audio needs it unconditionally.

**Coherence.** Whether a group sounds like a tone or noise depends on whether its members move
together. Per group accumulate Σcos φ and Σsin φ → mean-phase vector length R. R≈1 = aligned =
tone; R≈0 = scattered = noise. Two accumulators, same pass. **Measured, not assumed.**

**Free visual monitor:** repoint the Phase Viz button (`main.cpp:1244` → `render.metal:1213`)
at `posePhase` instead of the path-length phase. Solid colour band = that region will sound
like a tone; rainbow hash = noise. **See what you hear, off the same number.**

---

## 10. WHAT ONE NOTE DOES — "all particles move, so all have to do something"

His question: *"what do they do when only one voice plays."*

**The note is a FORCE, not a sound.** Playing does not add a voice — it re-tunes all 2 million.
Particles pile onto the mode's nodal rings, which sit at specific radii, and radius *is* pitch.
**What you hear is the chord the ensemble settles into.**

The chord is computable from Bessel zeros alone and is **scale-free** (ω ∝ r^-3/2 depends only
on the *ratios* of nodal radii):

| mode | rings | chord (semitones) | ≈ |
|---|---|---|---|
| m=0 | 3 | 0, +11.7, +33.3 | C C A |
| m=0 | 4 | 0, +8.0, +19.7, +41.3 | C G♯ G♯ F |
| m=3 | 3 | 0, **+7.5, +18.5** | root, fifth, octave+fifth |
| m=3 | 4 | 0, +5.7, +13.2, +24.2 | C F♯ C♯ C |

Inharmonic, which is *correct* — it is a drum, not a string. m=3 comes out as essentially a
stacked fifth, straight from Bessel zeros.

**And the transition is the attack.** While particles slide to their new radii, every one of
them **glides in pitch**. The attack is not imposed by an envelope — it is the ensemble
re-tuning. Which closes his opening message: ADSR really is linked to the universe, just not
the way it is currently wired.

⚠️ The pattern is **3D**, not just radial rings: the eigenmode also has an axial mode number
`pAx` giving nodal planes in z (`particles.metal:2005+`). So mass concentrates on a 3D lattice.
The chord table above accounts only for the radial rings.

---

## 11. 🚨 RETRACTION — THE "ALPHA IN HZ BLOCKER" WAS WRONG

**Claimed in session, then disproved by reading the code. Do not act on the original claim.**

I told him the play-regime chord was **blocked** because `modes.cpp:24` sets
`alpha = 440·2^((midi−69)/12)` — the note's frequency in Hz — where a Bessel zero (2.40–43.37)
belongs, and that this would produce hundreds of nodal rings instead of n.

**The alpha value is real, but it is NOT used for the pattern geometry.** Verified:

- `particles.metal:386` — the codebase already documents it:
  `// NOTE: VoiceData.alpha is NOT a Bessel zero — modes.cpp fills it with the [note in Hz]`
- `particles.metal:1962` — `voices[vi].alpha` is used **only** to scale `sculptStrength`, a
  gain in the *sculpt* path (and eigenmode-only is the play default since 2026-07-19).
- `particles.metal:2005` — the eigenmode path takes its geometry from
  `BESSEL_ZEROS[mm*9 + (nn-1)]`, the correct **12×9** table (landed 2026-07-29).

**So the geometry is correct and the play chord is NOT blocked. Do not "fix" `modes.cpp`** —
it would silently change sculpt gain and fix nothing.

**Lesson:** I asserted a blocker from a memory note without reading the consuming code. A
parallel session had already fixed the real bug (a `clamp(m,0,6)`) hours earlier.

---

## 12. ⚠️ THE COST QUESTION — MEASURE, DO NOT GUESS

2 million independent oscillators at 48 kHz ≈ **10¹¹ operations/second**. Not obviously
impossible on this GPU, not obviously fine. **The binding constraint is memory bandwidth, not
arithmetic** — the sum must read per-particle state every block.

**Unmeasured. The answer decides the architecture:**
- **N = 2M feasible** → true per-particle sum; §2 holds literally.
- **N < 2M** → group into **shape-preserving cells (radius × ANGLE, never radius alone)** and
  sum representatives. §2 still holds as the *definition*; the grouping is a documented
  approximation, and **solo still works** because solo is N=1.

---

## 13. CROSS-LINK — the blur and the band are the same problem

From the parallel Chladni audit (2026-07-29): the patterns are still blurry, and one named
cause is that **there is no dissipation at the node** — Gor'kov is conservative and friction
e-folds over 9.5 s, so *"the band = oscillation amplitude."*

That is the same quantity as our **ensemble band width** (§5) and our **coherence R** (§9).
Particles oscillating about a node instead of settling on it are exactly particles with
scattered phase = noise instead of tone.

**So node dissipation would sharpen the picture AND make the sound more tonal — one fix, both
domains.** CLAUDE.md's founding spec already names it: *"node braking: friction scales with
distance-to-nodal-line"*, absent from the eigenmode path.

---

## 14. BUILD ORDER — one increment, then STOP

1. **MEASURE N.** GPU sum of N oscillators at audio rate; sweep N until the frame budget
   breaks. **No musical content.** *Verdict: none needed — it is a number.* ← **START HERE**
2. **Per-particle voice, one star.** Solo path at N=1. Proves §2 end to end.
   *Verdict: does one star sound like anything.*
3. **The ensemble sum** at the N from step 1; frequency + amplitude only, no pan.
   Expect a wash. *Verdict: does it sound like matter?* ← **first real gate**
4. **Emission weighting** (§6.3). *Verdict: does the mud clear, does the low-mid appear?*
5. **Pan from θ** (§6.2). *Verdict: does playing a shape open the image?*
6. **Orbital phase + coherence** (§9). *Verdict: does the rasp go, does it thicken?*
7. **The resonator κ** (§8). *Verdict: is it eerie?* ← the Silver Surfer test
8. **Phase Viz repoint** (§9). *Verdict: can you see what you hear?*
9. **The player's hand** — separate design (MPE/Ableton), after the above.

---

## 15. OPEN QUESTIONS

1. **N** — §12. Everything downstream depends on it.
2. **Does our disk actually ring at κ?** Test-particle prediction vs. self-gravitating SPH.
3. **`pose_phase_advance` gated to time-lapse mode** — audio needs it always.
4. **Redshift floor** — `poseOmegaEff` clamps dilation at 0.4; audio may need the honest form.
5. **Audio-thread safety** — snapshot must reach the callback lock-free. `AudioRingBuffer`
   (`audio_engine.h:18`) is SPSC and exists as a pattern.
6. **Rest-regime gating** — several BH paths gate on `totalAmplitude < 0.02f`
   (`renderer.mm:1384`). Audio must not inherit a gate that silences it on play.
7. **`fft.cpp` is forward-only** (analysis, vDSP). The inverse path is new code.
8. **The player's hand is NOT designed.** MPE dimensions → physical destinations; Ableton
   plumbing (`src/core/midi_input.h` is 34 lines, unassessed); **playability unmeasured** — if
   it plays like honey it is a meditation object, not an instrument, and only he can call that.
9. **The claim.** Perseus is *observed*; ours is a *simulation* anchored to measured SI
   constants. Honest sentence: *"the frequencies a real 5.9×10⁵ M☉ system would produce,
   transposed by exactly 16 octaves."* Do not inflate it.

---

## 16. WHAT THIS DESIGN REJECTS

- **A second sound layer.** No synth over the drone.
- **Radius-only binning.** Cannot represent shape. §3.
- **Mass as amplitude.** Physically wrong, makes mud. §6.3.
- **Linear frequency shift.** Breaks every ratio.
- **A scan direction.** Every NASA sonification declares one because their data is a static
  image with no time axis. Ours evolves in real time — a scan would import their single
  arbitrary choice.
- **Hardcoding κ as a tone.** Painting the resonance. §8.
- **Any added black-hole sound.** It is subtractive. §7.
- **Tuned physics constants.** Class-1 numbers derive from `spacetime.h` or they are bugs.

---

## 17. VERIFIED-FACTS LEDGER

Read from code or computed, 2026-07-26 → 29. Nothing from memory.

| fact | source |
|---|---|
| engine is silent at rest (voices only) | `synth.h:36`, `synth.cpp` |
| per-particle fields: mass, temperature, spin, charge, origin id | `particles.metal:16` |
| `posePhase` = ∫ω dt, wrapped, per particle | `render.metal:383` |
| `poseOmegaEff` = √(GM/r³)·√(1−r_s/r), floored 0.4 | `render.metal:356` |
| particles inside `horizonR` excluded | `render.metal:408` |
| Shakura–Sunyaev shape, zero inside r_in | `render.metal:213` |
| Doppler split colour-shift vs beaming-intensity | `render.metal:245` |
| `velW.w` = path-length phase + 3-bit band id | `particles.metal:2772`, `render.metal:110` |
| eigenmode geometry from `BESSEL_ZEROS[mm*9+(nn-1)]`, 12×9 | `particles.metal:403, 2005` |
| `VoiceData.alpha` (Hz) used ONLY for `sculptStrength` | `particles.metal:386, 1962` |
| 256-shell radial profile, every particle every frame, shared storage | `renderer.mm:2603, 1113, 1022` |
| `RADIAL_SHELLS` 256, `RADIAL_MAX_R` 5.0 sim | `particles.metal:258–260` |
| 1 sim time = 5.854202 s; c_sim ≡ 1; r_s(field) = 1.0 | `spacetime.h:47, 51, 98` |
| ISCO 223 s → 294 Hz at 2¹⁶; disk spans 3.9–4.3 octaves | computed |
| 20 Hz rhythm/pitch line at r ≈ 14.85; 120 Hz mono line at r ≈ 4.4 | computed |
| shell band width 10–61 cents | computed |
| κ peak and ω:κ = 2 both exactly at r = 8GM | derived + numeric |
| 3:2 at r = 54GM/5 = 4.453 sim | derived + numeric |
| `fft.cpp` forward-only, vDSP-based | `fft.h:8` |
| Phase Viz is a render colour mode | `main.cpp:1244`, `render.metal:1213` |
| decorative LFO drives size/radius/jitter | `main.cpp:2007–2018` |
| `fineCellMassBuffer` gated on SS_AMR (default OFF), rest-only, ±4 sim | `renderer.mm:2356, 119` |

**Corrections logged this session:**
1. **v1's radial-histogram architecture withdrawn entirely.** §3.
2. **"Reduce to 3–5 voices" withdrawn** — stream segregation vs fusion. §3.
3. **"Alpha-in-Hz blocks the play chord" RETRACTED** — alpha is not used for geometry. §11.
4. The memory note that `fineCellMassBuffer` is "already binned, just read it" is **wrong** —
   gated behind `SS_AMR`, default off, rest-only, ±4 sim.

---

**Last Updated:** 2026-07-29 15:05:01
**NEXT:** §14 step 1 — measure N. No musical content, no verdict needed. Awaiting his go.
