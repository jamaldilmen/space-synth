# VJ Mode Roadmap

**Created:** 2026-03-12
**Status:** Research phase

---

## Current State (what we just fixed)

Three bugs prevented VJ from working at all:
1. Silence gate killed all VJ forces when no synth keys pressed (fixed: force sustain envelope)
2. `totalAmplitude` was zero in VJ-only mode (fixed: sum VJ band amplitudes)
3. All 16 bands hitting GPU tanked FPS to 14 (fixed: top 6 loudest bands only)

Particles now respond to external audio. But the visual result isn't good yet.

---

## Open Issues

### ISSUE 1: Particles get stuck in a corner and don't return
**Symptom:** When a loud band drives particles outward, they drift to one side and stay there even after the audio drops.

**Root cause:** The elastic shell pulls radially toward `globalTargetRadius`, but harmonic forces push particles *tangentially* (along theta/phi gradients). Once particles cluster in a harmonic lobe, the elastic shell only constrains their radius — it doesn't spread them back out azimuthally. There's no "return to uniform sphere" force.

Additionally, VJ has no release phase. Synth voices have ADSR — when you release a key, `envelopePhase` goes to 4.0 (release) which actively collapses particles inward. VJ voices just disappear when amplitude drops below 0.005. The elastic shell is the only restoring force, and at `springStiffness = 50.0` with `0.05` blend factor it's slow.

**What synth has that VJ doesn't:**
- ADSR release phase with 25% blend (fast collapse)
- Velocity damping during release (`finalV *= 0.75`)
- Explicit radius tracking during fade

### ISSUE 2: Everything looks the same — no instrument separation
**Symptom:** Kick, snare, hats, and melodic content all produce similar-looking blobs. No visual distinction between percussive transients and sustained tones.

**Root cause:** The 16 FFT bands are *frequency* bands, not *instrument* bands. A kick at 60Hz and a bass synth at 60Hz look identical. The mode assignment `(m = i%5+1, n = i/5+1)` is arbitrary — band 0 always maps to mode (1,1) regardless of what instrument is actually there.

**What's missing:**
- No onset/transient detection (kick vs sustained bass)
- No spectral shape analysis (percussive = broadband, tonal = narrowband)
- All bands use the same visual behavior (harmonic sculpting + radial breathing)
- `deltaAmp` exists for transients but only drives the impulse shockwave, not the visual character

### ISSUE 3: No "idle" visual — silence is just a frozen ball
**Symptom:** When no audio is playing, particles sit in a static sphere. No ambient life.

**What it should feel like:** Breathing, slow rotation, subtle noise — like a living thing waiting for input.

---

## Roadmap

### Phase 1: Snap-back and lifecycle (fix what we have)

**1A. VJ release envelope**
When a VJ band drops below threshold, don't just remove it — fade it out with a synthetic release. Track per-band "active" state and when amplitude drops, inject a release voice that pulls particles back.

Implementation sketch:
- Per-band state machine: `active → releasing → silent`
- When band goes below threshold: set `releasing`, keep voice alive with decaying amplitude
- When release amplitude < 0.01: remove voice, set `silent`
- Duration: ~200ms (fast but smooth)

**1B. Azimuthal restoring force**
Add a "return to uniform distribution" force that activates when harmonic forces are weak. Pushes particles back toward even angular spacing, not just radial.

Could be as simple as: when a particle's nearest-neighbor angle is too small (clustered), push apart. Or: blend position toward a "home position" on the sphere when voice amplitude is low.

**1C. Velocity damping on VJ voice removal**
When a VJ voice disappears, apply release-style velocity damping (`finalV *= 0.75`) for a few frames. Prevents particles from continuing to drift after the driving force stops.

### Phase 2: Instrument-aware visualization (rethink the mapping)

**2A. Onset detection — separate percussive from tonal**
Add a simple onset detector per band:
- Compare current frame energy to rolling average
- High ratio (>3x) = onset/transient = percussive
- Low ratio = sustained = tonal
- Tag each VoiceGPUData with `isTransient` flag

**Visual mapping:**
- Transients → explosive radial burst (use existing shockwave but bigger), fast decay
- Sustained → harmonic sculpting (current behavior), slow evolution

**2B. Spectral centroid bands instead of fixed FFT bands**
Instead of 16 fixed-frequency bands, cluster energy into perceptual groups:
- Sub bass (20-80 Hz): radial breathing, deep expansion
- Bass/kick (80-250 Hz): large-mode patterns, punchy
- Low mid (250-1k Hz): medium modes, warmth
- High mid (1-4k Hz): fine detail, texture
- Presence (4-8k Hz): sparkle, fast particles
- Air (8k+): noise/shimmer overlay

Fewer bands (6) = matches our GPU budget. Each band gets a *designed* visual behavior instead of arbitrary mode mapping.

**2C. Designed mode palettes per band**
Instead of `m = i%5+1`, curate which Bessel modes look best for each frequency range:
- Sub bass → (1,1) or (2,1): simple, massive patterns
- Kick → (3,1): three-lobed explosion
- Snare → (5,2) or (4,3): complex, scattered
- Hats → (7,4): fine, detailed, fast
- Melody → modes that match the actual pitch (map frequency to closest Bessel zero)

### Phase 3: Visual polish

**3A. Per-band color mapping**
Each frequency range gets a color temperature:
- Bass = warm (red/orange glow)
- Mids = neutral (white/blue)
- Highs = cool (cyan/violet)
- Transients = bright flash

Currently all particles are the same color regardless of which band is driving them.

**3B. Ambient idle state**
When no audio: slow Perlin noise displacement, gentle rotation, breathing radius. Not frozen. Parameters:
- Rotation: ~0.1 rad/s around Y
- Breathing: sinusoidal radius ±5% at 0.2 Hz
- Noise: low-frequency spatial perturbation

**3C. Smooth transitions between dominant modes**
When the loudest band changes (e.g., kick → snare), crossfade between harmonic patterns instead of hard-switching. Prevents jarring visual pops.

### Phase 4: Performance

**4A. LOD for VJ voices**
Not all 6 voices need full trig on every particle. Distant particles (from camera or emitter) could use simplified force model. Or: alternate voices across frames (voice 0,2,4 on even frames; 1,3,5 on odd).

**4B. Particle count adaptation**
Auto-reduce particle count when VJ voice count is high. 10M particles with 6 voices of trig each = 60M trig evaluations/frame. Could drop to 5M or even 2M for VJ and still look dense.

---

## Research Questions

- [ ] What onset detection algo is cheapest and good enough? (spectral flux? energy ratio?)
- [ ] Can we run onset detection in the audio callback or does it need its own thread?
- [ ] What Bessel modes actually look best for kick/snare/hats? Need visual testing
- [ ] Should VJ voices use different emitter positions than synth? (e.g., all at origin vs distributed)
- [ ] Is 6 voices the right cap? Test 4 vs 6 vs 8 for visual richness vs FPS
- [ ] Should VJ mode reduce particle count automatically?
- [ ] Can we use the phase field on particles to encode which band is driving them? (for per-band coloring)
- [ ] How to handle VJ + synth simultaneously without visual chaos?

---

## Priority Order

1. **1A + 1C** (release envelope + velocity damping) — fixes "stuck in corner"
2. **2B** (perceptual band grouping) — foundation for everything else
3. **2A** (onset detection) — separates kick from bass
4. **2C** (designed mode palettes) — makes each band visually distinct
5. **3B** (ambient idle) — polish
6. **3A** (per-band color) — polish
7. **4A/4B** (performance) — if FPS is still an issue
