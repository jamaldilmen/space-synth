# RESEARCH — How NASA sonifies, and what it means for SPACE SYNTH
**Written:** 2026-07-26 20:26:46
**Question asked:** "research how NASA would do that" — re: the field→sound engine (design B, "universe as oscillator").
**Status:** research only. No code changed. Feeds `DESIGN` for the sonification spine.

---

## 0. One-line answer

NASA's published method for making a black hole audible is **radial extraction + exact
octave transposition**. That is, line for line, the law we derived independently from
`spacetime.h` before looking. The difference is scale: they transpose 57–58 octaves,
we need 16.

---

## 1. The direct precedent — Perseus galaxy cluster (NASA/CXC, May 2022)

The closest published work to what we are building.

| item | Perseus (NASA) | SPACE SYNTH |
|---|---|---|
| source | observed pressure waves in cluster gas, Chandra X-ray data | orbital frequencies of the particle field |
| extraction direction | **"extracted in radial directions, that is, outwards from the center"** | 256-shell radial mass profile (`radialMassStableBuffer`) |
| transform | **transposed up exactly 57 and 58 octaves** | transpose up exactly 16 octaves (S = 2¹⁶) |
| factor | 144 quadrillion × / 288 quadrillion × (2⁵⁷ / 2⁵⁸) | 65,536 × (2¹⁶) |
| original pitch | B♭, ~57 octaves below middle C | ISCO 0.00449 Hz → 294 Hz (≈D4) |

Two independent confirmations of our approach:

1. **Radial is the right axis.** NASA chose radial-outward extraction for a black hole
   for the same reason we did: a spherically/axially symmetric gravitating system's
   structure *is* its radial profile. Cassiopeia A also used radial-from-center.
2. **Exact octaves, not arbitrary scaling.** They did not pick a convenient multiplier.
   They used whole octaves so every frequency ratio in the source survives untouched
   and pitch class is preserved. This is the entire justification for our
   "one declared constant S, and it is a power of two" rule.

Source: [chandra.harvard.edu/sound/perseus.html](https://chandra.harvard.edu/sound/perseus.html)

---

## 2. The resonance→interval precedent — SYSTEM Sounds / TRAPPIST-1

Matt Russo & Andrew Santaguida (the same team NASA partnered with for the Chandra
program). TRAPPIST-1's seven planets sit in a resonant chain:

    8:5,  5:3,  3:2,  3:2,  4:3,  3:2

Those are minor sixth, major sixth, perfect fifth, perfect fifth, perfect fourth,
perfect fifth. The harmony was not composed — it is the orbital mechanics. Frequencies
were scaled up ~212 million × to reach hearing range.

**This is exactly the result we derived from Kepler:** a 2:1 resonant ring pair is
exactly one octave, 3:2 is exactly a perfect fifth (radius ratio 1.3104). Where the
disk forms resonant rings, the chord is Keplerian and requires no tuning.

They also added **discrete events over the continuous layer** — piano notes on planet
transits, drums on conjunctions. That is the published answer to "what is an arp, in
physics": it is a *recurrence event*, not a note pattern.

Source: [system-sounds.com/trappist-sounds](https://www.system-sounds.com/trappist-sounds/)

---

## 3. Where NASA's method does NOT apply to us — and it's in our favour

Every Chandra sonification must declare a **scan direction**: left-to-right (Galactic
Center), radial-from-center (Cassiopeia A), bottom-to-top (Chandra Deep Field South).

They need one because **their data is a static image. There is no time axis, so they
invent one.** The scan is the single arbitrary, indefensible choice in the whole NASA
method, and it is different for every image.

**We do not have that problem.** Our field evolves in real time under real physics.
Time in our sonification is physical, not chosen. We skip the one decision NASA cannot
justify — and we should never add a scan, because adding one would be *importing* their
weakness.

Source: [Frontiers in Communication 2024 — "A Universe of Sound: processing NASA data into sonifications"](https://www.frontiersin.org/journals/communication/articles/10.3389/fcomm.2024.1288896/full)

---

## 4. The anti-mush findings (tested, not opinion)

This is the part that answers "a mapping that doesn't collapse into noise mush."

- **Listeners reliably track ~3 simultaneous auditory streams.** Practical guidance in
  the literature: reduce to 10–15 dimensions, of which only **2–5 are prominent** at
  any moment.
  → **256 shells must NOT become 256 partials.** That is ~50× past the perceptual limit
  and is a guaranteed hiss generator.
  → Map the **peaks** of the radial profile (the rings), not the bins. The codebase
  already has this exact reduction: the `[CORE]` probe in renderer.mm finds `peakShell`
  / `mPeak`. Same logic, N peaks instead of 1.

- **NASA decimates on purpose.** Chandra Deep Field South: image resolution was
  *"reduced by a factor of four before being sonified to produce more audible,
  consistent tones."* Reduction is standard practice, not a compromise.

- **Perceptual dimensions are not orthogonal.** Pitch, loudness and timbre interact —
  a change in one is misread as a change in another. So a mapping that drives all three
  from different physical quantities will read as mud even if each is individually
  correct. Pick one primary carrier (pitch = radius) and let the others be secondary.

- **Instrumental timbres outperformed synthetic tones** in NASA's own participant study
  (glockenspiel/strings/piano beat synth tones). ⚠️ Caveat: that was measured for
  *comprehension in outreach*, not for a musical instrument. Do not treat it as a
  directive — but do treat "pure sine partials will sound sterile" as a warning we were
  given for free.

- **The trust finding.** Participants rated sonification *accuracy* lower than they
  rated enjoyment or learning, and many mistook sonifications for literal recordings of
  space. NASA's conclusion: the process must be explained, prominently.
  → For us this is structural, not cosmetic: the HUD can show provenance live
  (*this ring is at r = X sim, real orbital period Y s, you are hearing it 2¹⁶ up*).
  Our claim is stronger than NASA's here and should be shown, not asserted.

Sources: [Frontiers 2024](https://www.frontiersin.org/journals/communication/articles/10.3389/fcomm.2024.1288896/full),
[ICAD Sonification Report](https://www.icad.org/websiteV2.0/References/nsf.html),
[Audio Mostly — multiple data streams](https://dl.acm.org/doi/10.1145/2544114.2544121)

---

## 5. LIGO — the honest limit of audification

LIGO's chirps sit just below/within the audio band already, so they **frequency-shift
by +400 Hz** (a linear shift, not a transposition) and also play higher-shifted repeats
purely for audibility.

⚠️ **Do not copy this.** A linear frequency shift *destroys every ratio* — a fifth is
no longer a fifth after +400 Hz. LIGO can do it because they have one signal and no
harmony to preserve. We have a whole disk of ratios, which is the entire point.
**Octave transposition only.**

Source: [gwosc.org/audio](https://gwosc.org/audio/), [LIGO Caltech](https://www.ligo.caltech.edu/page/gw-sources)

---

## 6. The claim we are actually entitled to make

Stated precisely so it is never overclaimed:

- NASA's Perseus is **observed** data — real pressure waves from a real cluster.
- Ours are the orbital frequencies of a **simulation** whose GM, r_s and ISCO derive
  from measured SI constants (`spacetime.h`: kCSI, kGMsunSI, M_field = 5.94276e5 M☉).

So the honest sentence is: *these are the frequencies a real 5.9×10⁵ M☉ system would
produce, transposed by exactly 16 octaves.* Scale-accurate to the physics, from a model
rather than an observation. That is a strong claim. It does not need inflating.

---

## 7. What this changes in the design

1. **KEEP** — S = 2¹⁶ exact octave transposition. Confirmed as NASA's own method.
2. **KEEP** — radial profile as the source axis. Confirmed as NASA's own choice for
   black holes.
3. **CHANGE** — do not drive one partial per shell. Detect **rings (profile peaks)** and
   voice those. Target 3–5 prominent voices, not 256. This is the single most important
   research finding.
4. **ADD** — discrete events layered over the continuous drone (SYSTEM Sounds' transits/
   conjunctions). Physically, our equivalents are ISCO crossings and resonance
   coincidences. This is the honest form of the "arp" from the original question.
5. **REJECT** — linear frequency shift (LIGO-style). Breaks every ratio.
6. **REJECT** — any scan direction. We have real time; a scan would import NASA's one
   arbitrary choice.
7. **NOTE** — pitch carries radius. Loudness and timbre are secondary and must not be
   driven by independent physical quantities, or the dimensions will interfere.

---

## 8. Sources

- [Chandra — Perseus sonification](https://chandra.harvard.edu/sound/perseus.html)
- [Chandra — A Universe of Sound](https://chandra.si.edu/sound/)
- [Frontiers in Communication 2024 — A Universe of Sound: processing NASA data into sonifications](https://www.frontiersin.org/journals/communication/articles/10.3389/fcomm.2024.1288896/full)
- [NASA — Listen to the Universe](https://www.nasa.gov/missions/chandra/listen-to-the-universe-new-nasa-sonifications-and-documentary/)
- [NASA Science — Data Sonifications: Black Holes](https://science.nasa.gov/science-research/astrophysics/data-sonifications/)
- [SYSTEM Sounds — TRAPPIST-1](https://www.system-sounds.com/trappist-sounds/)
- [ICAD — The Sonification Report](https://www.icad.org/websiteV2.0/References/nsf.html)
- [Audio Mostly — Measuring comprehension in sonification tasks with multiple data streams](https://dl.acm.org/doi/10.1145/2544114.2544121)
- [GWOSC — audio](https://gwosc.org/audio/)
- [AJ 2024 — Evaluation of the effectiveness of sonification for time-series data exploration](https://iopscience.iop.org/article/10.3847/1538-3881/ad2943)
