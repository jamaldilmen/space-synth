# Synthesizer Architecture Research: Chasing Analog Warmth

To achieve the "Diva / Moog / Juno" aesthetic within Space Synth, we must transition from pristine digital mathematics to non-linear physical modeling. This document outlines the roadmap for tackling authentic analog tones.

## 1. The Oscillator: Instability and Beating (Juno/Jupiter)
Currently, `std::sin(phase)` is perfectly stable. Analog oscillators, however, drift.
- **Phase Drift:** The frequency of early DCOs/VCOs fluctuates slightly due to voltage and temperature changes. 
    - *Implementation:* Apply a slow, randomized Low-Frequency Oscillator (LFO) using Perlin noise to the pitch of each voice (e.g., ±5 cents of drift).
- **Free-Running Phase:** When hitting a chord on a digital synth, phases often start at `0.0`. In an analog synth, the circuits are always running; thus, phase should be randomized `[0, 2π)` on `noteOn`.
- **Waveform Shaping:** Pure digital saws/squares are harsh. Analog waves are band-limited (to prevent aliasing) and have slight AC-coupling high-pass curves that scoop the extreme lows, preventing muddiness.

## 2. The Filter: Drive and Keytracking (Moog/Diva)
The Moog Ladder Filter and Roland IR3109 (Juno) filters are famous for their non-linearities.
- **Keytracking (Implemented Today):** The filter cutoff must mathematically follow the pitch. A C2 (65Hz) should have a resting cutoff around 100Hz, while a C5 (523Hz) should rest around 800Hz. This ensures high notes retain "air" while low notes stay deep.
- **Filter Drive (Diva Vibes):** When hitting an analog filter hard, the resonance doesn't just whistle; the circuit saturates. 
    - *Implementation:* Inside the SVF recursive loop, wrap the feedback path (`band_`) in a `tanh()` function. This prevents the resonance from self-oscillating to infinity and clips it musically, creating "brassiness."
- **Resonance Loss:** True Moog filters lose low-end bass when resonance is turned up. We can emulate this by slightly attenuating the final output based on the `Q` factor.

## 3. The Envelopes: Snappiness
Analog envelopes (especially Roland ones) are not strictly linear.
- **Exponential Decay/Release:** The voltage drop follows a logarithmic curve. A truly "snappy" bass or brass pluck requires the amplitude to drop rapidly at first, then tail off slowly. 
    - *Implementation:* Change `envelope.cpp` to use exponential tension curves rather than linear `t` interpolation.

## 4. The Chorus: Spatial Width (Juno 106)
The Juno is defined by its analog Bucket-Brigade Device (BBD) Chorus.
- **Implementation:** A stereo delay line with very short times (e.g., 2ms left, 3ms right) modulated by a slow LFO (e.g., 0.5Hz). This creates the ultimate "swimming in space" 80s pad sound.

## Summary of Action Plan
1. **Immediate (Today):** Add Filter Keytracking so pitch drives cutoff and noise. Wrap the SVF output in a soft-clipper for brassy drive.
2. **Next Steps:**
    - Rewrite `envelope.cpp` for exponential curves (snappier brass).
    - Add a global BBD Stereo Chorus.
    - Add Unison detuning (Phase drift).
