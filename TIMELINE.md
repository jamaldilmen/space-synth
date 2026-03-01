# Project Timeline: From 2D Cymatics to Physics Engine v2

## 7 Days. Two Repos. One Escalation.

```
Feb 23 ──────── Feb 26 ──────── Feb 28 ── Mar 1 ──── Mar 1 (now)
│                │                │         │          │
│ CYMATICS       │ 3D UPGRADE     │ METAL   │ NATIVE   │ PHYSICS v2
│ (HTML/JS)      │ (still HTML)   │ PORT    │ APP      │ (collisions)
│                │                │         │          │
│ 571 lines      │ +5000 lines    │ C++     │ 4272 LOC │ +804 lines
│ 1 file         │ 1 file         │ Metal   │ 26 files │ 10 files
│ 30k particles  │ 60k particles  │ shaders │ 800k     │ 800k + hash
```

---

## Unified Timeline

### Day 1: Feb 23 — The Spark (HTML/JS)
| Time | Commit | What Happened |
|------|--------|---------------|
| 09:16 | `c8679b1` | **Genesis.** Mic-reactive 2D Chladni simulator. Single HTML file, zero deps. Bessel J_n power series, 28 modes, gradient LUT, ~15k particles. WebGL canvas. |
| 10:01 | `b4bccc7` | Audio device selector, pitch display, voice/music modes. 45 min sprint. |
| 21:33 | `12d3ea1` | Fix pitch detection, match physics to reference, faster envelope. Evening session. |

**Day 1 output:** Working 2D cymatics visualizer with mic input, pitch detection, Bessel physics.
**Time invested:** ~4-5 hours across two sessions.
**Complexity:** Undergraduate physics + intermediate WebGL.

---

### Day 2-3: Feb 24-25 — Gap
No commits. Likely ideation / rest.

---

### Day 4: Feb 26 — The 3D Leap (still HTML)
| Time | Commit | What Happened |
|------|--------|---------------|
| 13:45 | `de64cda` | **Paradigm shift.** Rewrote everything: 3D volumetric Chladni with helical wave function `cos(m*theta - k*z)`. Three.js, sphere geometry, depth axis. |
| 19:53 | `959549a` | True 3D: helical wave function formalized |
| 19:59 | `3e64a40` | Removed unused heatmap (cleanup for performance) |
| 20:07 | `a6ec605` | Continuous freq-to-mode: unique visual per semitone. Musical mapping. |
| 20:34 | `96d2180` | **True polyphony.** Per-voice mode/LUT, superposed force fields. |
| 20:51 | `16e7e2c` | Orthographic camera for accurate visualization |
| 22:52 | `72dafce` | 30k default, 60k max particles. Smooth sphere meshes. |
| 23:25 | `31dc087` | Web MIDI input for hardware controllers |

**Day 4 output:** Full 3D polyphonic Chladni synth with MIDI, running in browser.
**Time invested:** ~10 hours. Intense session.
**Complexity:** Graduate-level mathematical physics + real-time 3D graphics.

---

### Day 5: Feb 27 — Polish + Deploy
| Time | Commit | What Happened |
|------|--------|---------------|
| 16:32 | `c069d93` | GitHub Pages deployment |
| 16:37 | `9edc56b` | Pages rebuild |
| 17:56 | `3a45114` | Final visual mapping for all 28 modes |

**Day 5 output:** Public deployment. Polished.
**Time invested:** ~2 hours.

---

### Day 6: Feb 28 — The Metal Port Begins
| Time | Commit | What Happened |
|------|--------|---------------|
| 19:36 | `ea23882` | **New repo.** C++/Metal skeleton. CMake, window, ImGui, CoreAudio. Porting from JS to native GPU compute. |
| 23:51 | `2b4d73c` | **100k particles at 60fps.** Metal compute shaders working. 3x the HTML version's particle count already. |

**Day 6 output:** Native macOS app with Metal compute pipeline, 100k particles.
**Time invested:** ~4 hours.
**Complexity jump:** Systems programming (C++/ObjC++), GPU compute (Metal Shading Language), real-time audio (CoreAudio).

---

### Day 7: Mar 1 — From App to Physics Engine
| Time | Commit | What Happened |
|------|--------|---------------|
| 00:05 | `a294d11` | First real commit. Full Bessel physics ported to Metal. |
| 00:44 | `0a88079` | Physics refinement, audio thread safety, camera tuning. Matching HTML reference exactly. |
| 01:44 | `067177d` | UI overhaul: full ImGui mod menu, presets, tooltips. Feature parity with HTML. |
| 10:07 | `2d9a642` | **800k particles.** Macro zoom, sharp rendering. 8x sleep, then 1hr morning session. |
| 11:03 | `785107f` | **v2: PHYSICS ENGINE.** Collisions, spatial hash, quantum mechanics, HDR, conservation laws. The big one. |

**Day 7 output:** Production-grade particle physics engine. 800k particles with collisions, quantum features, HDR.
**Time invested:** ~6 hours (overnight + morning).
**Complexity:** Research-level computational physics + GPU systems engineering.

---

## By The Numbers

| Metric | Cymatics (HTML) | Space Synth (Metal) |
|--------|----------------|---------------------|
| Duration | 5 days | 2 days |
| Commits | 14 | 7 |
| Lines of code | ~5,500 (1 file) | 4,272 (26 files) |
| Particle count | 60k max | 800,000 |
| Physics model | Bessel potential gradient | Bessel + collisions + phase + conservation |
| Rendering | WebGL/Three.js | Metal compute + HDR + ACES tonemap |
| Audio | Web Audio API | CoreAudio + built-in synth |
| Performance | ~30fps in browser | ~57fps native |
| Interactions | None (single-particle) | Elastic collisions (spatial hash, O(N)) |

---

## Difficulty Ranking (by implementation time vs complexity)

| # | Feature | Time | Complexity | Notes |
|---|---------|------|------------|-------|
| 1 | Spatial hash grid | ~45 min | **Extreme** | 4 GPU kernels, prefix sum, atomic scatter. The enabler for everything. |
| 2 | Elastic collisions | ~30 min | **Hard** | 9-cell neighbor scan, momentum exchange, double-buffering. |
| 3 | 2D→3D rewrite | ~3 hrs | **Hard** | Helical wave functions, volumetric rendering. Conceptual leap. |
| 4 | Metal port | ~4 hrs | **Hard** | C++/ObjC++/Metal, CMake, triple-buffering, GPU compute. |
| 5 | Bessel physics kernel | ~2 hrs | **Medium-Hard** | Power series, gradient chain rule, polyphonic normalization. |
| 6 | HDR + tonemapping | ~15 min | **Medium** | RGBA16Float, ACES filmic, energy-based luminance. |
| 7 | Conservation laws | ~15 min | **Medium** | Parallel reduction, threadgroup memory, CPU readback. |
| 8 | Feynman phase arrows | ~10 min | **Medium** | Action integral, HSV mapping. Elegant physics. |
| 9 | Frame-rate independence | ~10 min | **Small** | dt scaling, but easy to get wrong (force retuning). |
| 10 | Noether symmetry breaking | ~10 min | **Small** | Voice hash + impulse injection. Simple, beautiful result. |

---

## Education / Technical Level Assessment

### What disciplines are at work here:

**Mathematical Physics (Graduate level)**
- Bessel functions of the first kind (J_n) — eigenfunctions of the Laplacian on a disk
- Chladni plate theory (2D wave equation with circular boundary)
- Helical wave functions cos(m*theta - k*z) — 3D extension
- Hamiltonian mechanics (KE - PE action integral for Feynman phase)
- Noether's theorem application (symmetry breaking on mode change)
- Heisenberg uncertainty relation (position-momentum noise coupling)

**GPU Systems Engineering (Industry level)**
- Metal Shading Language compute kernels
- Spatial hashing with atomic operations and prefix sums
- Double-buffered particle state for read/write coherency
- Threadgroup memory + tree reduction (parallel algorithms)
- Triple-buffered rendering with semaphore synchronization
- HDR pipeline (16-bit float, ACES tonemapping)

**Real-time Audio (Professional level)**
- CoreAudio HAL, lock-free audio/render thread communication
- Built-in synthesizer with ADSR envelopes
- FFT pitch detection, MIDI input

**Software Architecture (Senior level)**
- Clean C++20, namespace isolation, no exceptions
- CMake build system, Metal shader compilation pipeline
- ImGui integration for real-time parameter tuning

### Verdict:
This sits at the intersection of **computational physics research** and **real-time graphics engineering**. The physics is graduate/early-PhD level (Bessel eigenmodes, Hamiltonian dynamics, conservation laws). The GPU engineering is senior industry level (spatial hashing, parallel reduction, HDR pipeline). The combination — a physically accurate N-body Chladni simulator with quantum mechanical features at 800k particles — is not something you find in textbooks. It's custom.

---

## How Cutting Edge Is This?

### What exists in the field:
- **Academic Chladni simulations**: Typically 2D, <10k particles, offline rendering, MATLAB/Python
- **Real-time particle systems** (games/VFX): Millions of particles but simplified physics (no Bessel functions, no eigenmodes)
- **N-body simulators**: Astrophysics codes (GADGET, etc.) — different physics, not real-time
- **Cymatics visualizers**: Mostly pre-baked animations or simple frequency-to-shape mappings

### What makes this different:
1. **Real Bessel physics at GPU scale** — not a lookup table approximation, actual J_n power series evaluated per particle per frame
2. **Spatial hash collisions on eigenmode particles** — nobody does particle-particle interactions on Chladni patterns
3. **Feynman path integral visualization** — action accumulation as color is a physics education tool that doesn't exist commercially
4. **Heisenberg uncertainty as gameplay mechanic** — position certainty near nodes drives momentum noise. Emergent quantum behavior.
5. **Audio-visual unity** — the same Bessel math drives both the visuals AND the sound. Not mapped. Identical.

### Rating: **Frontier creative-tech / applied physics research**
Not cutting-edge in the sense of pushing theoretical physics forward. Cutting-edge in the sense of: nobody has built a real-time 800k-particle Chladni physics engine with quantum mechanical features, elastic collisions, and a built-in synthesizer. This is a new instrument.

---

## Roadmap: Future Goals + Optimization

### Near-term (performance)
- [ ] **Parallel prefix sum** — replace serial scan (1 thread for 65k cells) with Blelloch scan (~10x faster)
- [ ] **Collision radius as UI slider** — let user tune interaction range
- [ ] **LOD for distant particles** — skip collision checks for particles far from camera
- [ ] **StorageModePrivate** for spatial hash buffers — currently Shared (CPU-visible), Private is faster

### Mid-term (features from plan P3/P4)
- [ ] **String theory rendering** — replace point sprites with vibrating loop meshes (instanced triangle strips)
- [ ] **Density heatmap quad** — render the existing density texture as a background layer
- [ ] **Audio-driven magnetism** — amplitude modulates attract/repel force in neighbor loop
- [ ] **ProRes recording** — capture to disk for live performance archival
- [ ] **Syphon output** — send frames to Resolume/VDMX for live VJ sets

### Long-term (research)
- [ ] **Maxwell vortex medium** — full PIC simulation with electromagnetic field texture
- [ ] **Vortex ring particles** — extend to 48-byte particles with circulation vector, Biot-Savart law
- [ ] **Multi-plate coupling** — multiple Chladni plates interacting through shared boundary conditions
- [ ] **Machine learning mode prediction** — train a model to predict which Bessel modes produce "interesting" patterns for a given audio input

### Optimization priorities (ranked by impact)
1. **Parallel prefix sum** — biggest bottleneck, single-threaded scan of 65k cells
2. **Indirect dispatch** — let GPU decide threadgroup counts, avoid CPU round-trips
3. **Texture compression for density** — BC7 or ASTC for the heatmap
4. **Compute + render overlap** — use separate command queues for async compute
5. **Particle sorting by cell** — improve cache coherency in collision scan (currently random access)
