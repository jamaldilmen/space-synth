# DESIGN — EVERY PARTICLE IS A VOICE
## Sonification of the particle field

**Written:** 2026-07-28 10:43:51
**REWRITTEN:** 2026-07-28 20:12:02 — v2. The v1 architecture (collapse the field to a
256-bin radial histogram) is **withdrawn**; see §0.2. Jamal's correction: *"the shape is the
sound... 2 mio oscillators / voices with their own property, pausable."*
**Status:** design. **No code written. Nothing built.**
**Companion research:** `docs/RESEARCH_2026-07-26_nasa_sonification.md`

---

## 0. THE DECISION

### 0.1 What this is
The particle field **is** the sound source. Not a modulator, not a layer over a synth.
It sounds whether or not you play.

> "The sim sounds whether you play or not... i want it to be like a meditation tool if u
> dont play it. like an everplaying song. and you know how we roll it needs to be scale
> accurate to reality."

> "the field must be the oscillator and the resonance too. it must have an eerie sound at
> rest.. like the silver surfer would listen to it while he cooks"

**You play the field**, not over it. MIDI/MPE injects energy into the sim; the only voice is
ever the field's own. A synth layered on the drone would be the audio form of the painted
disc killed on 2026-07-24 (`feedback_no_second_layer`).

### 0.2 ⚠️ WHY v1 WAS WITHDRAWN — read this before proposing any binning
v1 made the already-existing 256-shell radial mass profile (`radialMassStableBuffer`) the
representation. **A radial histogram is rotationally symmetric.** It bins by distance from
centre only, so it cannot distinguish a ring from a spiral from two clumps on opposite
sides — all three produce an identical profile and would sound identical.

**Chladni structure is angular.** The m lobes are the whole point. A radial profile discards
exactly the geometry this instrument exists to express. v1 was designed around the buffer
that happened to exist rather than around what the sound requires.

It also could never support **solo**: a histogram has no particle identity.

### 0.3 THE ARCHITECTURAL PRINCIPLE (this governs everything below)

> **Define the per-particle voice first. The ensemble sound is the SUM of those voices.
> Any binning or grouping is an OPTIMISATION of that sum and must be justified against it.**

Consequences, all of which follow for free:
- **Solo is the same law with N = 1.** Pause, click a star, hear exactly its own voice. Not
  a bolted-on feature — the definition already contains it.
- **Every property can participate.** Position, mass, temperature, velocity, phase.
- **Pausable by construction.** Frequency comes from *geometry*, not motion: ω depends on
  where a particle is, not on it moving. Paused, it holds its note. Same principle as the
  time-lapse — "it's the maths, runs even when paused."

The reverse order (histogram first, per-particle later) makes solo impossible without a
rewrite. Do not invert this.

---

## 1. THE PER-PARTICLE VOICE — the definition

Per-particle state available today, verified in `particles.metal:16`:

| field | contents |
|---|---|
| `posW` | x, y, z, **mass** |
| `velW` | vx, vy, vz, packed(path-phase + 3-bit VJ band id) |
| `prevW` | prev x, y, z, **temperature** |
| `spinW` | spin x, y, z, **charge** |
| `entanglement` | `.y` = **origin id** — particle identity, survives the sort |
| `posePhase[]` | ∫ω(r)dt — true orbital angle (render.metal:383) |

### The mapping — one physical quantity per audible dimension

| audible | from | law |
|---|---|---|
| **frequency** | radius r | `f = S·ω(r)/(2π·kSimSeconds)`, ω = √(GM/r³) |
| **amplitude** | **emission**, NOT mass | §3.3 — Shakura–Sunyaev |
| **phase** | `posePhase` | ∫ω dt, already integrated per particle |
| **pan** | angular position θ | §3.2 |
| **timbre / brightness** | temperature | hotter matter radiates broader — physical, not a knob |
| **pitch shift + level** | velocity | relativistic Doppler + beaming |
| **silence** | inside r_h | §4 — contributes nothing |

`spinW` (spin, charge) and `entanglement` are available and **unmapped**. Leave them unmapped
rather than inventing a use.

⚠️ **Orthogonality warning** (from the sonification literature, research doc §4): pitch,
loudness and timbre interact perceptually. Each audible dimension gets **one** physical
driver. Do not stack two quantities onto one dimension.

---

## 2. THE LAW, AND THE TWO CLASSES OF CONSTANT

```
S = 2^16 = 65536
f_audible(r) = S · √(GM/r³) / (2π · 5.854202 s)
```

Uniform time scaling — every ratio, interval and beat survives exactly. A power of two makes
it a transposition, preserving pitch class. **This is NASA's published Perseus method**
(radial extraction + exactly 57/58 octaves); we derived it from `spacetime.h` before looking.

**REJECTED: linear frequency shift** (LIGO's +400 Hz). Destroys every ratio.

### Two classes of constant — the rule that prevents a fight later
1. **Physics constants must be DERIVED** from `spacetime.h`. If a number describing the
   universe is not traceable to the metric, it is a bug.
2. **Listener constants are LEGITIMATE.** The ~20 Hz pitch floor, the ~120 Hz limit below
   which humans cannot localise a source, critical bandwidth — these describe *the ear*, not
   the universe. The instrument is for a human. Using them is not cheating.

The mono-bass rule in §3.1 is class 2. The Shakura–Sunyaev weighting in §3.3 is class 1.

### Where the disk lands (measured, gmSim = 0.4123)

| radius | real orbital period | ×2¹⁶ |
|---|---|---|
| horizon r_s 0.825 | 41 s | 1528 Hz |
| ISCO 2.474 | 223 s | 294 Hz (≈D4) |
| r = 6 | 842 s | 78 Hz |
| R_DISK 18 | 4375 s | 15 Hz |

- Disk spans **3.9–4.3 octaves natively.** The range is Kepler's.
- The **20 Hz line** (rhythm→pitch) falls at r ≈ 14.85, inside R_DISK = 18.
- **2:1 rings = an octave. 3:2 = a perfect fifth** (radius ratio 1.3104). Exactly.

---

## 3. THE MIX — where Jamal's engineering and the physics turn out to agree

His brief:
> "a bass is one voice. a moog is the best bass synth cause its mono. so the bass oscillator
> / sub should be one voice still. then 300 ish we do a bit of width, most lives in the low
> mid to hi mid area. and some for the top. the challenge is gonna be summing all of that in
> a way that makes sense, dynamically figuring out pan and spread."

### 3.1 Mono bass — and it happens by itself
Below roughly 120 Hz humans cannot localise a source: interaural level differences stop
working, and wavelengths exceed head spacing. Mono bass is a fact about ears, not a studio
superstition. **Class-2 constant, legitimate.**

In our field, low frequency = low ω = **large radius**. So the bass is the outer disk — the
big, slow, surrounding bulk. And an axisymmetric ring at large r has **no net angular
position**: its pan contributions cancel to centre.

**So mono bass is not a rule we impose — it falls out of §3.2 whenever the outer field is
symmetric, which at rest it is.** We add a mono fold below the localisation limit as a
safety net, not as the mechanism.

### 3.2 Pan = angular position. Spread = angular asymmetry. **Shape IS the stereo image.**
Pan comes from a particle's angular position θ (equivalently its x). Then:

- **axisymmetric field** (rest, smooth disk) → contributions cancel → **centred, narrow**
- **angular structure** (Chladni m lobes, clumps, spiral arms) → they do not cancel → **the
  image opens up**

The width of the stereo image is a *direct measurement of how much shape exists*. Play a
mode, the pattern forms, the sound gets wide. Stop, it settles, the sound narrows. This
answers "dynamically figuring out pan and spread" — it is not a heuristic to tune, it is a
measurement of the geometry.

**This is the single strongest argument for v2 over v1.** A radial histogram has no θ at
all, so under v1 the stereo image could not exist.

### 3.3 ⚠️ THE MUD PROBLEM, and the physical fix
**Amplitude must NOT be mass.** The disk spawns with density ∝ r^-0.3 out to R_DISK = 18, so
most mass sits at large radius = low frequency. Mass-weighting would pile nearly all energy
below 100 Hz — everything in the sub, which is precisely the mix failure he is warning about.

Real accretion disks do not radiate in proportion to mass. They radiate by viscous
dissipation, which **peaks just outside the inner edge**. That is the Shakura–Sunyaev thin
disk profile, and **it already exists in our code** (render.metal:213):

```
ssDiskTempShape(r, r_in) = (r_in/r)^0.75 · (1 − √(r_in/r))^0.25     // zero inside r_in
```

Weighting by emission rather than mass moves the energy to the inner disk — the low-mid to
hi-mid region — leaving the vast slow outer disk as quiet sub. **That is exactly the balance
he described, and it is the physically correct weighting.** No EQ curve, no tuned tilt.

The mix balance is not a mixing decision here. It is thermodynamics.

### 3.4 Which particle is "the bass one"?
None. It is a *region*, not a particle: the outer disk, summed, folded to mono below the
localisation limit. If a single star is soloed, it plays at its own ω wherever that lands —
solo bypasses the mix entirely (§0.3).

---

## 4. WHAT THE BLACK HOLE DOES — subtractive, always

**The hole adds no sound.** It only removes and bends. This is `shadow = absence, never
paint` (2026-07-24) applied to audio, and it is the same canon: a black hole you *add* is the
overlay feel.

1. **Silence inside the horizon.** Particles inside r_h contribute nothing — a real hole in
   the spectrum. Already gated in the render path (render.metal:408).
2. **It eats the treble first.** Small radius = high frequency. As the hole grows, r_h
   swallows the smallest radii first. **Accretion is a low-pass filter closing over time.**
   The instrument darkens as the hole feeds. Emergent, not scripted.
3. **Gravitational redshift.** √(1 − r_s/r) — matter near the hole is pitch-flattened.
   Already in `poseOmegaEff` (render.metal:356). ⚠️ floored at 0.4, so not truthful at the
   horizon; the audio path may need the honest form.
4. **Doppler.** Orbital motion → pitch shift *and* level (beaming). Already split exactly
   this way for the visuals (render.metal:245). ⚠️ Those constants (`DOPPLER_K_COLOR` 5.0,
   `DOPPLER_K_BEAM` 0.8) are **visual tuning**, class-2-for-pictures. Audio must use the true
   relativistic factor, not these.
5. **κ → 0 at ISCO.** The resonance dies. §6.

---

## 5. THE THREE STATES

His question: *"what does silence / non-play sound like opposed to shapes, opposed to black
holes after play."* All three are emergent from §1–§4 — none is a mode to author.

| state | geometry | sound |
|---|---|---|
| **Rest / silence** | smooth axisymmetric disk | wide inharmonic wash, **centred and narrow** (no angular structure), energy in the low-mid via §3.3, κ resonance at r≈3.3 and the fifth at r≈4.5. The eerie one. |
| **Shapes / play** | Chladni m lobes | **the image opens up** (§3.2), specific mode frequencies, hotter matter → brighter timbre (play heat is already in `prevW.w`) |
| **Black hole after play** | mass eaten, r_h grown | **darker** — treble eaten first (§4.2), redshifted, a literal hole in the spectrum, ISCO resonance dying. Narrower again as it re-symmetrises. |

The arc — wash → wide and bright → dark and narrow — is entirely a consequence of the
physics. Nothing sequences it.

---

## 6. THE RESONATOR — where the eerie comes from

Oscillator = ω(r), orbital. Resonator = **κ(r)**, the radial epicyclic frequency: displace
matter radially and it rings.

```
κ(r) = ω(r)·√(1 − 6GM/r)          (Schwarzschild)
```

That vanishes at r = 6GM, **which is ISCO**. Not a filter sweep — a resonance that detunes
downward and then **ceases to exist** at a fixed radius.

**Exact theorem:**
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

The 3:2 is **observed in real black holes** — GRO J1655−40, XTE J1550−564, GRS 1915+105,
H1743−322 (Abramowicz & Kluźniak 2001 epicyclic resonance model).

**Newtonian check:** at large r, √(1−6GM/r) → 1, so κ → ω. In Newtonian gravity κ = ω
everywhere — ω:κ = 1:1, unison, no harmony at any radius. **The disk has harmony because
gravity is relativistic.**

⚠️ **These are test-particle geodesic frequencies.** Our field has self-gravity and SPH
pressure, so κ is the resonance the *geometry wants*, not a measured fact about our disk.
**Do not hardcode κ as a tone — that is painting the resonance.** Measure, then compare.

---

## 7. PHASE AND COHERENCE

`posePhase[]` (render.metal:383, landed `5d8fa5b`) = ∫ω(r)dt per particle, wrapped. The fix
built for the counter-rotation bug is the sonification's phase source.

⚠️ **TWO per-particle phases — do not confuse:**

| | what | where |
|---|---|---|
| `velW.w` low 29 bits | ∫\|v\|dt — path length, "Feynman arrow". **Wrong for audio.** | particles.metal:2772 |
| `posePhase[]` | ∫ω dt — **true orbital angle. This one.** | render.metal:383 |

⚠️ `pose_phase_advance` is gated on bit20 + `bhDiskAxisY < 0.5` — it only runs in time-lapse
mode. Audio needs it always.

**Coherence.** Whether a group sounds like a tone or like noise depends on whether its
members move together. Per group: accumulate Σcos φ and Σsin φ → the mean-phase vector
length R. R≈1 = aligned = tone. R≈0 = scattered = noise. Two accumulators, same pass.

**Free visual monitor:** repoint the Phase Viz button (main.cpp:1244, render.metal:1213) at
`posePhase`. Solid colour band = that region will sound like a tone; rainbow hash = noise.
See what you hear, off the same number.

---

## 8. ⚠️ THE COST QUESTION — measure before architecting

2 million independent oscillators at 48 kHz is order **10¹¹ operations/second**. That is not
obviously impossible on this GPU and not obviously fine. **The binding constraint is memory
bandwidth, not arithmetic** — the sum must read per-particle state every block.

**This is unmeasured, and the answer decides the architecture:**
- **N = 2M feasible** → true per-particle sum. §0.3 holds literally.
- **N < 2M** → group into *shape-preserving* cells (radius × angle, never radius alone) and
  sum group representatives. §0.3 still holds as the definition; the grouping is the
  documented approximation, and **solo still works** because solo is N=1.

**Do not guess this number, and do not design around a guess.** It is step 1 (§10).

---

## 9. OPEN QUESTIONS

1. **N** — §8. Everything downstream depends on it.
2. **Does our disk actually ring at κ?** Test-particle prediction vs. a self-gravitating SPH
   field. Measurable, unmeasured.
3. **`pose_phase_advance` is gated to time-lapse mode.** Audio needs it unconditionally.
4. **Redshift floor.** `poseOmegaEff` clamps the dilation at 0.4. Audio may need the honest form.
5. **Audio-thread safety.** The field snapshot must reach the audio callback lock-free.
   `AudioRingBuffer` (audio_engine.h:18) is SPSC and exists as a pattern.
6. **Rest-regime gating.** Several BH paths gate on `totalAmplitude < 0.02f` (renderer.mm:1384).
   Audio must not inherit a gate that silences it on play.
7. **`fft.cpp` is forward-only** (analysis). vDSP does inverse; that path is new code.
8. **The claim.** Perseus is *observed*; ours is a *simulation* anchored to measured SI
   constants. Honest sentence: *"the frequencies a real 5.9×10⁵ M☉ system would produce,
   transposed by exactly 16 octaves."* Do not inflate it.
9. **§11 — the player's hand (MPE/Ableton) is NOT designed.**

---

## 10. BUILD ORDER — one verifiable increment, then stop

1. **Measure N.** GPU sum of N oscillators at audio rate; sweep N until the frame budget
   breaks. **No musical content.** Output the number. *Verdict: none needed — it is a number.*
2. **Per-particle voice, one star.** Solo path: pick a particle, synthesise its voice from
   its own state. Proves §0.3 end to end at N=1. *Verdict: does one star sound like anything.*
3. **The ensemble sum** at whatever N step 1 allows, frequency + amplitude only (no pan yet).
   Expect a wash. *Verdict: does it sound like matter?* ← **first real gate**
4. **Emission weighting** (§3.3). *Verdict: does the mud clear and the low-mid appear?*
5. **Pan from θ** (§3.2). *Verdict: does playing a shape open the image?*
6. **Orbital phase + coherence** (§7). *Verdict: does the rasp go, does it thicken?*
7. **The resonator, κ** (§6). *Verdict: is it eerie?* ← the Silver Surfer test
8. **Phase Viz repoint** (§7). *Verdict: can you see what you hear?*
9. **§11 the player's hand** — separate design, after the above.

---

## 11. THE PLAYER'S HAND — ⚠️ OPEN, NOT DESIGNED

Decided: you play the field. MIDI/MPE excites the sim; the only voice is the field's.
Not designed: what each MPE dimension does physically; Ableton/MPE plumbing
(`src/core/midi_input.h` is 34 lines, unassessed); whether the 128-mode Chladni table is the
excitation path; and **playability** — response is physics time, unmeasured. If it plays like
honey it is a meditation object, not an instrument, and only he can call that.

Note: the existing LFO (main.cpp:2007) is a free sine, 0.01–10 Hz knob, driving particle size
±20% / plate radius ±10% / jitter ±50%. Decorative, unconnected to the universe. Under this
design its rate stops being a knob and becomes ω(r).

---

## 12. WHAT THIS DESIGN REJECTS

- **A second sound layer.** No synth over the drone. Audio `feedback_no_second_layer`.
- **Radius-only binning.** It cannot represent shape. §0.2. This is why v1 was withdrawn.
- **Mass as amplitude.** Physically wrong and it makes mud. §3.3.
- **Linear frequency shift.** Breaks every ratio.
- **A scan direction.** Every NASA sonification declares one because their data is a static
  image with no time axis. Ours evolves in real time. A scan would import their one
  arbitrary choice.
- **Hardcoding κ as a tone.** That is painting the resonance. §6.
- **Any added black-hole sound.** It is subtractive. §4.
- **Tuned physics constants.** Class-1 numbers derive from `spacetime.h` or they are bugs. §2.

---

## 13. VERIFIED-FACTS LEDGER

Read from code or computed from `spacetime.h`, 2026-07-26/28. Nothing from memory.

| fact | source |
|---|---|
| engine is silent at rest (voices only) | synth.h:36, synth.cpp |
| per-particle fields incl. mass, temperature, spin, charge, origin id | particles.metal:16 |
| `posePhase` = ∫ω dt, wrapped, per particle | render.metal:383 |
| `poseOmegaEff` = √(GM/r³)·√(1−r_s/r), floored 0.4 | render.metal:356 |
| particles inside `horizonR` excluded | render.metal:408 |
| Shakura–Sunyaev shape `(r_in/r)^0.75·(1−√(r_in/r))^0.25`, zero inside r_in | render.metal:213 |
| Doppler already split colour-shift vs beaming-intensity | render.metal:245 |
| `velW.w` = path-length phase + 3-bit band id | particles.metal:2772, 2945; render.metal:110 |
| 256-shell radial profile exists, every particle every frame, shared storage | renderer.mm:2603, 1113, 1022 |
| `RADIAL_SHELLS` 256, `RADIAL_MAX_R` 5.0 sim | particles.metal:258–260 |
| 1 sim time = 5.854202 s; c_sim ≡ 1; r_s(field) = 1.0 | spacetime.h:47, 51, 98 |
| ISCO 223 s → 294 Hz at 2¹⁶; disk spans 3.9–4.3 octaves | computed |
| 20 Hz rhythm/pitch line at r ≈ 14.85 | computed |
| κ peak and ω:κ = 2 both exactly at r = 8GM | derived + numeric |
| 3:2 at r = 54GM/5 = 4.453 sim | derived + numeric |
| `fft.cpp` forward-only, vDSP-based | fft.h:8 |
| Phase Viz is a render colour mode | main.cpp:1244, render.metal:1213 |
| decorative LFO drives size/radius/jitter | main.cpp:2007–2018 |
| `fineCellMassBuffer` gated on SS_AMR (default OFF), rest-only, ±4 sim | renderer.mm:2356, 119 |

**Corrections logged:**
- The memory note that `fineCellMassBuffer` is "already binned, just read it" is **wrong** —
  gated behind `SS_AMR`, default off, rest-only, ±4 sim.
- **v1 of this document** proposed reducing the field to 3–5 ring "peaks" (from the
  sonification literature's ~3-stream limit). Wrong: that limit governs stream *segregation*;
  we want *fusion*. Jamal caught it — *"every particle is a part of the oscillator."*
- **v1's radial-histogram architecture is withdrawn entirely.** §0.2.

---

**Last Updated:** 2026-07-28 20:12:02
**Next:** §10 step 1 — measure N. No musical content, no verdict needed. Awaiting his go.
