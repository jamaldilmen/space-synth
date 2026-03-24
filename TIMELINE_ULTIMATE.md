# The Ultimate Timeline: From Mic-Reactive HTML to Relativistic Particle Universe

## 18 Days. 2 Repos. 89 Commits. 1 Idea That Wouldn't Stop Escalating.

```
Feb 23        Feb 26        Feb 28     Mar 1      Mar 4       Mar 7       Mar 10      Mar 12
  │             │             │          │          │           │           │           │
  ▼             ▼             ▼          ▼          ▼           ▼           ▼           ▼
 2D MIC      3D SPHERE     METAL      PHYSICS    COSMOS     STABILITY   VJ MODE     PRODUCTION
 REACTIVE    POLYPHONIC    PORT       ENGINE     ENGINE     & AUDIT     5M PARTS    v1-STABLE
 HTML/JS     still HTML    C++/MSL    v2+Audio   Relativity  Bug sweep   Loopback    Ship it
 15k pts     60k pts       100k pts   800k pts   1M pts     1M pts      5M pts      5M pts
```

---

## CHAPTER 1: THE BROWSER ERA (Feb 23-27)

### Day 1: Feb 23 — Genesis

Single HTML file. Zero dependencies. Mic goes in, Chladni patterns come out.

| Commit | What |
|--------|------|
| `c8679b1` | Mic-reactive 2D Chladni simulator. Bessel J_n power series (25 terms), 28 modes, gradient LUT, ~15k particles on WebGL canvas. |
| `b4bccc7` | Audio device selector (BlackHole/Loopback routing), pitch display, voice/music modes. |
| `12d3ea1` | Fix pitch detection, match HTML physics to reference, Resolume-style envelope follower (instant attack, controlled fall). |

**Result:** Working 2D cymatics visualizer. Mic input drives particle positions through Bessel function nodal lines. ~1000 lines, one file.

---

### Days 2-3: Feb 24-25 — Silence

No commits. The idea incubating.

---

### Day 4: Feb 26 — The 3D Leap

Still HTML. Still one file. But everything changes.

| Commit | What |
|--------|------|
| `de64cda` | **Paradigm shift.** Complete rewrite: 3D volumetric Chladni with helical wave function `cos(m*theta - k*z)`. Three.js replaces raw canvas. Depth axis. Sphere geometry. |
| `959549a` | True 3D helical wave function formalized mathematically |
| `3e64a40` | Remove dead heatmap code (density grid, blur pass, textured disc) |
| `a6ec605` | Continuous freq-to-mode mapping: every semitone gets a unique visual pattern |
| `96d2180` | **True polyphony.** Per-voice mode/LUT, superposed force fields. Play a chord = see the interference. |
| `16e7e2c` | Orthographic camera for accurate wave visualization |
| `72dafce` | 30k default, 60k max. Smooth sphere meshes (16x12 segments). |
| `31dc087` | Web MIDI input for hardware synth/controller support |

**Result:** Full 3D polyphonic Chladni synth with MIDI. Running in a browser tab. 8 commits in 10 hours.

---

### Day 5: Feb 27 — Ship It

| Commit | What |
|--------|------|
| `c069d93` | GitHub Pages deployment |
| `9edc56b` | Pages rebuild trigger |
| `3a45114` | Final visual mapping tuned for all 28 Bessel modes |

**Browser era total:** 14 commits, 5 days, 1 HTML file (~5500 lines at peak), 60k particles max, ~30fps.

---

## CHAPTER 2: THE METAL PORT (Feb 28 - Mar 1)

### Day 6: Feb 28 — Native or Nothing

The browser ceiling hit. 60k particles, no compute shaders, no real audio engine. Time to go native.

| Commit | What |
|--------|------|
| `ea23882` | **New repo: space-synth.** C++/Metal skeleton. CMake, NSWindow, ImGui, CoreAudio stubs. The port begins. |
| `2b4d73c` | **100k particles at 60fps.** Metal compute + render pipeline. Raw CAMetalLayer, CVDisplayLink, triple-buffered. Already 1.7x the HTML particle cap. |

---

### Day 7: Mar 1 — The Marathon (24 commits in one day)

The day the project crossed from "visualizer" to "physics engine with a built-in synthesizer."

#### 00:00-02:00 — Feature Parity
| Commit | What |
|--------|------|
| `a294d11` | Full Bessel physics ported to Metal compute kernel |
| `0a88079` | Physics refinement, audio thread safety, camera sensitivity matching HTML reference |
| `067177d` | Complete ImGui mod menu: tooltips, TAB toggle, soft particles, presets |

#### 10:00-11:30 — v2 Physics Engine
| Commit | What |
|--------|------|
| `2d9a642` | **800,000 particles.** Macro zoom, ImGui state fixes, sharp rendering. |
| `785107f` | **v2: THE ENGINE.** Spatial hash grid (256x256, 4-phase GPU build, Blelloch prefix sum). Elastic collisions (9-cell neighbor scan, momentum exchange). Feynman phase arrows (action integral, HSV mapping). Heisenberg uncertainty (position-momentum noise coupling). Noether symmetry breaking (voice hash impulse injection). HDR + ACES tonemapping. Conservation law tracking (parallel reduction, threadgroup memory, CPU readback). |

#### 12:00-18:00 — Debug Gauntlet
| Commit | What |
|--------|------|
| `b1e01be` | Fix frozen physics: kernel name mismatch `particle_physics` vs `compute_physics` |
| `fac8284` | Fix collision bugs: inverted push direction, wrong impulse condition |
| `87cebeb` | Gate collisions on voiceCount>0 to prevent asymmetric drift at rest |
| `a8e9b90` | Fix zoom: ortho frustum, face-on camera, point size cap |
| `c75734e` | **The critical fix.** Line-by-line HTML-vs-Metal diff found 2 compounding bugs: friction 53x too weak (UI slider vs base friction), integration 60x too slow (removed velocity unit conversion). Combined = patterns 3000x wrong. |
| `c54c22c` | Progress log |

#### 18:00-21:00 — Polyphony + Full Audio Engine
| Commit | What |
|--------|------|
| `3a436d2` | Additive polyphony: unclamped amplitudes, test sequencer (C Major, Cm7, 5ths, Chromatic) |
| `d7d4454` | Fix broken sphere: revert center-collapse, fix sequencer re-trigger |
| `35b6097` | Match HTML physics exactly: 3 force application bugs found and fixed |
| `9c0a91e` | Match HTML retraction: always target 0.35, remove sphere-mode branching |
| `f609831` | Restore Chladni patterns: maxWaveDepth was divided by 400 in renderer (flattened sphere 400x) |
| `0cc6a96` | Fix ImGui crash on HUD toggle, remove boundary potential |
| `8283c93` | **CoreMIDI input.** Auto-connects to all sources. Detected Launchpad Mini MK3. |
| `8d8c534` | **Audio Phases 1 & 2.** SVF filter (Moog-style resonant lowpass), envelope-modulated cutoff sweep 200Hz-6kHz, analog noise layer, tanh soft-clipper master bus. |
| `3b62158` | Filter keytracking + Diva analog saturation. Base cutoff tracks pitch. Pre-filter tanh drive. |
| `866e1bd` | Engine research doc: analog modeling strategies (Diva/Juno) for Phase 3 |
| `1477264` | **Audio-Visual 1:1 Integration.** Moog drive parameter wired to visual forces. Exponential envelope curves. |
| `15caef2` | Heisenberg phase drift + 2D physics fix |
| `4da0220` | Fix spatial hash collision drift (Gauss-Seidel to Gauss-Jacobi) |
| `3860dcf` | Scale 3D analytical gradients to match HTML LUT intensity |

**Day 7 result:** 24 commits. Physics engine with spatial hashing, elastic collisions, quantum mechanics, conservation laws, polyphonic synth with SVF filter, MIDI input, and 800k particles. In one day.

---

## CHAPTER 3: THE COSMOS ENGINE (Mar 2-5)

### Day 8: Mar 2 — Stereo Space

| Commit | What |
|--------|------|
| `85fc72d` | **BBD Chorus** (Juno-style bucket-brigade delay with quadrature LFO). **Supernova Macro** (single slider drives 15+ audio+visual parameters simultaneously). Split stereo output. Fixed 2D Chladni collapse bug (symmetric Gauss-Jacobi accumulation). |

---

### Day 9: Mar 3 — Störmer-Verlet

| Commit | What |
|--------|------|
| `1573833` | **Störmer-Verlet integration.** Position-history-based velocity. Dual emitter UI. Post-FX Supernova macro logic fix. |
| `6f6f7ee` | **PIC Maxwell-Vortex refactor.** E-Field analog (inverse-square repulsion) and B-Field analog (Biot-Savart circulation) with dedicated tuning sliders. |

---

### Day 10: Mar 4 — The Day It Became a Universe

27 commits. The biggest day in the project.

| Commit | What |
|--------|------|
| `f7c648f` | **[PHASE 5] 3D Physics Restoration.** Volumetric spatial hash (32x32x32 voxels), unified force model, harmonic snapback calibration. |
| `ab21056` | Technical review: "1,000,000 Milestone" document |
| `4285248` | Fix PhysicsUniforms/SpatialHashUniforms struct alignment for UI-GPU sync |
| `5aeba10` | **[PHASE 7] Industry-Level Debugging Suite.** Deterministic mode, force isolation (solo/mute per force), physical asserts. |
| `2dd8665` | **Self-Healing Auto-Mode.** Dynamic stability control, hardware reset. |
| `0fd12f3` | **[ODS-03] Thermal Plasma.** Brownian heat model, HDR emission from temperature. |
| `7011039` | **[ODS-01] Quantum Entanglement.** ID-based particle telepathy, 80-byte struct alignment (posW+velW+prevW+spinW+entanglement). |
| `a3d7b32` | **[ODS-06] Schwarzschild Singularities.** Black hole collapse dynamics. |
| `f1dd329` | **[ODS-04] Stealth & Active Noise Cancelling.** |
| `7949f77` | Tone down thermal luminance to prevent additive blowout |
| `e72dadd` | **Upgrade to 3D Spherical Harmonics.** Y_l^m functions replace 2D Bessel modes. The Atom Model. |
| `371dfec` | True 3D volumetric expansion forces from spherical harmonics |
| `8ae7736` | **Semantic mode matrix.** Pitch class maps directly to azimuthal lobes (l). Octave maps to polar rings (m). Each note = a unique atomic orbital. |
| `4c3202f` | Switch from dense planet to universe-wide void distribution (Gaussian) |
| `7bf9172` | **Phase 10: Universe Simulator.** Gaussian void initial state, Coriolis spin, time dilation. |
| `bcaee35` | Decouple gravity/spin from key presses for continuous accretion |
| `ccbabad` | Gradient-driven harmonic sculpting, Reset Particles button |
| `da9b791` | VJ sustain visuals: particle size + alpha driven by thermal energy |
| `8b32378` | Cap pointSize to 32px to prevent GPU overdraw |
| `e7e7b70` | **Event horizon.** Dark core with orange-white accretion corona. |
| `6c92e43` | Tone down luminance/alpha: elegant glow, not white-out blobs |
| `0a4a3d1` | **Phase 11: General Relativity & String Theory.** Schwarzschild metric curvature, Noether energy redshift, 1D string rendering (velocity-aligned point sprite elongation), particle scale-up to 1M. |
| `8f52970` | **Phase 12: Auditory-Visual Kinetic Fusion.** 10ms transient shockwaves via `deltaAmp` detection, audio-rate force modulation. |

---

### Day 11: Mar 5 — ADSR Black Hole Lifecycle

| Commit | What |
|--------|------|
| `223a08b` | **Phase 12.7/12.8.** Audio restored with block-level locking. Visuals sharpened with speed-dependent elongation and high-contrast alpha. |
| `5de83d5` | Update definitive timeline |
| `6a6a270` | **Phase 17: ADSR Black Hole Lifecycle.** Silence = black hole (Gargantua). Attack = explosion. Decay/Sustain = sun. Release = collapse. The ADSR envelope IS the universe lifecycle. |
| `a928da1` | Visual accretion disk + force immunity during silence |
| `6756489` | Volumetric black hole rendering: fix depth-buffer occlusion, thin accretion disk geometry |
| `4c1d554` | WIP: Interstellar Gargantua permanent accretion disk |

---

## CHAPTER 4: PRODUCTION (Mar 7-12)

### Day 13: Mar 7 — Stability Audit

| Commit | What |
|--------|------|
| `9c3c374` | Fix: restore `invertMatrix4x4` decl, camStruct pointer, remove stray code from revert |
| `3b9b742` | **Production debug sweep.** 3 critical, 7 high, ~15 medium bugs fixed across GPU struct alignment, audio thread safety (mutex removal from RT callback, pre-allocated command buffers), and physics correctness (Hooke's law sign error, double friction, double jitter). |

---

### Day 16: Mar 10 — VJ Mode & 5 Million Particles

| Commit | What |
|--------|------|
| `4f93eb8` | **CoreAudio Loopback & High-Res FFT VJ Analysis Mode.** External audio in (Ableton, Spotify, anything) drives the particle universe. Band-split frequency injection. |
| `1cd806d` | Fix VoiceProcessingIO crash, add Master Volume UI |
| `6a78868` | Fix collision freezing: hard-cap spatial hash atomics |
| `cae12b0` | **Scale to 5 MILLION particles.** GPU allocation and dispatch sizing. |
| `df8d970` | Elastic shell restoring force for staccato bounce-back |
| `a17d2e9` | Restore FFT spectrum pipeline, fix 1M particle preset lock |
| `4d07069` | Replace VoiceProcessingIO with HALOutput, add VJ Input Gain slider |
| `7434ca8` | Bind HALOutput to default input device for Loopback |
| `418734b` | Backend GPU allocation natively supports 5M particles |
| `fd59c3c` | Disable VoiceProcessingIO ducking to restore synth playback |

---

### Day 18: Mar 12 — Ship Day

| Commit | What |
|--------|------|
| `0b941d6` | **Direct envelope-to-radius coupling.** Position interpolation (25% blend/frame) replaces force-based approach. Visual-audio sync goes from 1 second lag to <10ms. Kerr metric RK4 raytracer with procedural starfield for gravitational lensing. RT audio thread safety via `try_lock` pattern. |
| `00bcf99` | Fix dual ring artifact, restore soft z-mask in blackhole.metal |
| `cde82e0` | Infinite sustain scaling, self-oscillation plasma filaments |
| `cbb379e` | Fix active phase occlusion, scale density for higher particle counts |
| `4cd227e` | Restore stable black hole logic, update density math |
| `7c67d5a` | Restore Gaussian z-mask falloff for soft shadows |
| `b0ca32b` | Bound exponential scaling limits (Supernova macro particle escape) |
| `1c7427d` | Restore linear radius limit for Supernova/chord blowout |
| `94eebf8` | Bump static linear limit for Supernova/chord breathing room |
| `00758fc` | Fix final compiler warnings and undefined behaviors |
| `a752c82` | Fix ImGui duplicate ID warning, restore black hole visibility |
| `39b2778` | Fix unconditional culling during silence phase |
| `e836dc9` | Stability logger + macOS .app packaging |
| `fefc5e4` | Restore window.run() loop, update v1-stable branch |
| `42c071d` | High-DPI scaling + font bundling (fix tiny text) |
| `602c248` | Strip binary symbols for distribution |

---

## BY THE NUMBERS

| | Cymatics (HTML) | Space Synth (Metal) |
|---|---|---|
| **Duration** | 5 days (Feb 23-27) | 13 days (Feb 28 - Mar 12) |
| **Commits** | 14 | 75 |
| **Source files** | 1 | 41 |
| **Lines of code** | ~1,000 (final) | ~6,300 |
| **Total insertions** | — | 13,490 |
| **Particle count** | 60k max | 5,000,000 |
| **Physics** | Bessel gradient LUT | Bessel + Spherical Harmonics + Störmer-Verlet + Spatial Hash + E/B-Field + Gravity + Strings + Entanglement + Schwarzschild Metric + Kerr Geodesics |
| **Rendering** | WebGL/Three.js | Metal compute + HDR + ACES + Point sprite strings + Kerr raytracer + Procedural starfield + Gravitational lensing |
| **Audio** | Web Audio API (mic in) | CoreAudio HAL (synth + loopback VJ mode), SVF filter, BBD chorus, ADSR, keytracking, analog saturation |
| **MIDI** | Web MIDI | CoreMIDI (auto-detect all sources) |
| **Performance** | ~30fps browser | 60fps native (5M particles) |
| **Unique feature** | — | Black hole lifecycle: silence = Gargantua, attack = Big Bang, sustain = star, release = collapse |

---

## THE ARC

```
                                                                    5M particles
                                                                    Kerr raytracer
                                                                    VJ loopback
                                                                    .app bundle
                                                                        │
                                                         1M particles   │
                                                         Relativity     │
                                                         Black holes    │
                                                         String theory  │
                                                             │          │
                                              800k           │          │
                                              Collisions     │          │
                                              Quantum        │          │
                                              Synth+MIDI     │          │
                                                  │          │          │
                               60k                │          │          │
                               3D polyphonic      │          │          │
                               Web MIDI           │          │          │
                                   │              │          │          │
          15k                      │              │          │          │
          2D mic reactive          │              │          │          │
          Bessel patterns          │              │          │          │
              │                    │              │          │          │
──────────────┴────────────────────┴──────────────┴──────────┴──────────┴──────
          Feb 23              Feb 26          Mar 1       Mar 4      Mar 12
          HTML                HTML            C++/Metal   Cosmos     Production
```

---

## PHYSICS ESCALATION LADDER

1. **Bessel J_n** — Eigenfunctions of the Laplacian on a circular membrane (Feb 23)
2. **Helical waves** — `cos(m*theta - k*z)` extension to 3D (Feb 26)
3. **Gradient LUT** — 128x128 central differencing for force fields (Feb 28)
4. **Spatial hashing** — O(N) neighbor search via GPU atomic scatter (Mar 1)
5. **Elastic collisions** — Momentum-conserving impulse exchange (Mar 1)
6. **Feynman phase arrows** — Action integral S = KE - PE drives color (Mar 1)
7. **Heisenberg uncertainty** — Position-momentum noise coupling (Mar 1)
8. **Noether symmetry breaking** — Voice hash impulse on mode change (Mar 1)
9. **Störmer-Verlet** — Position-history integration for energy conservation (Mar 3)
10. **E-Field analog** — Inverse-square charge repulsion (Mar 3)
11. **B-Field analog** — Biot-Savart circulation from spin (Mar 3)
12. **Hooke's law strings** — Tensegrity lattice with rest length (Mar 4)
13. **Spherical harmonics** — Y_l^m replace Bessel for true 3D atomic orbitals (Mar 4)
14. **Schwarzschild metric** — Gravitational time dilation + event horizon (Mar 4)
15. **Quantum entanglement** — ID-based particle telepathy with chord connections (Mar 4)
16. **Thermal plasma** — Brownian heat model with HDR emission (Mar 4)
17. **ADSR lifecycle** — Envelope phase maps to cosmological epoch (Mar 5)
18. **Kerr metric geodesics** — RK4 raytracing through rotating black hole spacetime (Mar 12)
19. **Gravitational lensing** — Procedural starfield warped by Kerr metric (Mar 12)
20. **Direct envelope coupling** — Position interpolation eliminates force-based lag (Mar 12)

---

## DISCIPLINES

**Mathematical Physics** (Graduate/early-PhD)
- Bessel functions, spherical harmonics, Hamiltonian mechanics
- Schwarzschild + Kerr metrics, geodesic equations
- Noether's theorem, Heisenberg uncertainty, Feynman path integrals

**GPU Systems Engineering** (Senior industry)
- Metal compute kernels, spatial hashing, Blelloch prefix sum
- Störmer-Verlet integration, double-buffered particle state
- Kerr metric RK4 raytracer, HDR pipeline, ACES tonemapping

**Audio DSP** (Professional synth designer)
- CoreAudio HAL, lock-free RT thread communication
- SVF filter (Moog topology), BBD chorus (Juno), ADSR envelopes
- FFT analysis, CoreMIDI, VJ loopback mode

**Real-Time Architecture** (Production)
- try_lock RT thread safety, pre-allocated command buffers
- Triple-buffered rendering, CVDisplayLink sync
- 5M particle dispatch, macOS .app packaging

---

## ONE SENTENCE

A mic-reactive Chladni pattern visualizer in 1000 lines of HTML became a 5-million-particle relativistic universe simulator with a built-in synthesizer, Kerr-metric black hole raytracer, and gravitational lensing — in 18 days.
