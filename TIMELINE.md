# Project Timeline: From 2D Cymatics to Chladni Physics Engine

## 9 Days. Two Repos. One Escalation.

```
Feb 23 ──────── Feb 26 ──────── Feb 28 ── Mar 1 AM ── Mar 1 PM ── Mar 1 EVE
│                │                │         │           │           │
│ CYMATICS       │ 3D UPGRADE     │ METAL   │ PHYSICS   │ DEBUG &   │ AUDIO
│ (HTML/JS)      │ (still HTML)   │ PORT    │ ENGINE v2 │ RESTORE   │ ENGINE
│                │                │         │           │           │
│ 571 lines      │ +5000 lines    │ C++     │ +spatial  │ math fix  │ SVF filter
│ 1 file         │ 1 file         │ Metal   │ +collide  │ friction  │ MIDI input
│ 30k particles  │ 60k particles  │ shaders │ +quantum  │ forms ok  │ analog sat
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
| 23:51 | `2b4d73c` | **100k particles at 60fps.** Metal compute shaders working. Raw CAMetalLayer + CVDisplayLink, triple-buffered. 3x the HTML particle count already. |

**Day 6 output:** Native macOS app with Metal compute pipeline, 100k particles.
**Time invested:** ~4 hours.
**Complexity jump:** Systems programming (C++/ObjC++), GPU compute (Metal Shading Language), real-time audio (CoreAudio).

---

### Day 7: Mar 1 — From App to Physics Engine

#### Morning Session (00:00 - 02:00): Feature Parity

| Time | Commit | What Happened |
|------|--------|---------------|
| 00:05 | `a294d11` | First real commit. Full Bessel physics ported to Metal. |
| 00:44 | `0a88079` | Physics refinement, audio thread safety, camera tuning. Matching HTML reference exactly. |
| 01:44 | `067177d` | **UI overhaul.** Full ImGui mod menu, presets, tooltips, TAB toggle, soft particles. Feature parity with HTML. |

#### Morning Session (10:00 - 11:30): v2 Physics Engine

| Time | Commit | What Happened |
|------|--------|---------------|
| 10:07 | `2d9a642` | **800k particles.** Macro zoom optimization, ImGui state fixes, sharp rendering. |
| 11:03 | `785107f` | **v2: PHYSICS ENGINE.** The big one. Spatial hash grid, elastic collisions, Feynman phase arrows, Heisenberg uncertainty, Noether symmetry breaking, HDR + ACES tonemapping, conservation law tracking. |
| 11:21 | `ef652ed` | Project timeline document. |

#### Afternoon Session (12:00 - 18:00): Debug + Restore

| Time | Commit | What Happened |
|------|--------|---------------|
| 12:59 | `b1e01be` | **Fix frozen physics.** Kernel name mismatch `particle_physics` vs `compute_physics`. Added GPU debug probe. |
| 13:18 | `fac8284` | **Fix collision bugs.** Inverted push direction, wrong impulse condition, Metal UB null-pointer check. |
| 13:23 | `87cebeb` | **Gate collisions on active voices.** Collisions caused asymmetric drift at rest. |
| 17:09 | `a8e9b90` | **Fix zoom.** Ortho frustum 960, face-on camera (theta=pi/2), point size cap 64px. |
| 18:00 | `c75734e` | **Fix form differentiation.** The session's critical fix. Deep HTML-vs-Metal line-by-line analysis found 2 compounding math bugs: |

**Bug 1: Friction 53x too weak.** Node braking used UI damping slider `pow(0.95, dt) = 0.999/frame` instead of base friction `pow(0.06, dt) = 0.954/frame`. All modes hit the speed cap uniformly, erasing pattern structure.

**Bug 2: Integration 60x too slow.** Removed `* 60` from position update thinking it was a framerate hack. It's the velocity unit conversion matching the force weight retuning (0.45 to 27.0). Patterns formed 60x slower.

Also reduced Heisenberg uncertainty noise coefficient (12 to 3) for cleaner settling.

#### Evening Session (18:30 - 21:00): Additive Polyphony + Audio Engine

| Time | Commit | What Happened |
|------|--------|---------------|
| 18:34 | `3a436d2` | **Additive polyphony.** Removed 1/sqrt(N) normalization, unclamped amplitudes, test sequencer with presets (C Major, Cm7, 5ths, Chromatic). |
| 18:45 | `d7d4454` | **Fix broken sphere.** Retraction collapse reverted, sequencer re-trigger bug fixed. |
| 19:05 | `35b6097` | **Match HTML physics exactly.** Force weight 20.0 back to 0.45*polyNorm, removed wrong `* dt * invMass` from force application (made forces 60x weaker AND non-uniform). |
| 19:10 | `9c0a91e` | **Match HTML retraction.** Always target 0.35, remove sphere-mode physics branching (HTML has no sphere mode in physics, sphere is purely visual). |
| 19:40 | `f609831` | **Restore Chladni patterns + 3D sphere.** Fixed maxWaveDepth being divided by 400 in renderer.mm (flattened the sphere 400x). Removed artificial boundary potential. |
| 19:56 | `0cc6a96` | **Fix ImGui crash.** HUD toggle wasn't wrapping all sections. Cleaned up boundary potential. |
| 20:09 | `8283c93` | **CoreMIDI input.** Auto-connects to all MIDI sources. Detected Launchpad Mini MK3. |
| 20:26 | `8d8c534` | **Audio Phase 1 & 2.** SVF filter (Moog-style resonant lowpass), envelope-modulated cutoff (200Hz to 6kHz sweep), analog noise layer, tanh soft-clipper on master bus. |
| 20:31 | `3b62158` | **Filter keytracking + analog saturation.** Base cutoff tracks pitch, envelope sweep scales with pitch, pre-filter tanh saturation (Moog/Diva style). |
| 20:38 | `866e1bd` | **Engine research doc.** Analog modeling strategies (Diva/Juno) for Synth Phase 3. |

---

## By The Numbers

| Metric | Cymatics (HTML) | Space Synth (Metal) |
|--------|----------------|---------------------|
| Duration | 5 days | 2 days |
| Commits | 14 | 24 |
| Source files | 1 | 34 |
| Lines of code | ~5,500 | 4,799 |
| Particle count | 60k max | 800,000 |
| Physics model | Bessel potential gradient | Bessel + collisions + quantum + conservation |
| Rendering | WebGL/Three.js | Metal compute + HDR + ACES tonemap |
| Audio | Web Audio API | CoreAudio + polyphonic synth + SVF filter |
| MIDI | Web MIDI | CoreMIDI (auto-detect all sources) |
| Performance | ~30fps in browser | ~57fps native |
| Interactions | None (single-particle) | Elastic collisions (spatial hash, O(N)) |

---

## Architecture (34 source files)

```
src/
├── audio/
│   ├── audio_engine.h/mm   CoreAudio HAL, device enumeration
│   ├── fft.h/cpp            vDSP FFT pitch detection
│   ├── svf.h                State Variable Filter (Moog-style)
│   └── synth.h/cpp          Polyphonic synth, ADSR, keytracking
├── core/
│   ├── bessel.h/cpp         J_n power series (25 terms)
│   ├── camera.h             Spherical orbit camera
│   ├── envelope.h/cpp       ADSR envelope generator
│   ├── lut.h/cpp            128x128 gradient LUT, central differencing
│   ├── midi_input.h/mm      CoreMIDI auto-connect
│   ├── modes.h/cpp          28 Bessel modes (7 orders x 4 zeros)
│   ├── particles.h/cpp      CPU-side particle management
│   └── preset_manager.h/cpp JSON preset I/O
├── render/
│   ├── particles.metal      GPU physics kernel (forces, collisions, uncertainty)
│   ├── render.metal          Point sprite vertex/fragment shaders
│   ├── postfx.metal          Bloom, trails, chromatic aberration, ACES tonemap
│   ├── spatial_hash.metal    256x256 spatial hash (4-phase GPU build)
│   ├── renderer.h/mm         Metal pipeline, buffers, HDR offscreen
│   └── (density heatmap)
├── ui/
│   ├── mod_menu.h/cpp        ImGui parameter panels
│   ├── ui_theme.h            Custom ImGui styling
│   └── window.h/mm           NSWindow, keyboard/mouse input
└── main.cpp                  App entry, run loop, ImGui integration
```

---

## Difficulty Ranking (by implementation time vs complexity)

| # | Feature | Time | Complexity | Notes |
|---|---------|------|------------|-------|
| 1 | Spatial hash grid | ~45 min | **Extreme** | 4 GPU kernels, prefix sum, atomic scatter. The enabler for everything. |
| 2 | Elastic collisions | ~30 min | **Hard** | 9-cell neighbor scan, momentum exchange, double-buffering. |
| 3 | 2D to 3D rewrite | ~3 hrs | **Hard** | Helical wave functions, volumetric rendering. Conceptual leap. |
| 4 | Metal port | ~4 hrs | **Hard** | C++/ObjC++/Metal, CMake, triple-buffering, GPU compute. |
| 5 | Form differentiation debug | ~4 hrs | **Hard** | Line-by-line HTML vs Metal comparison. 2 bugs compounding (53x friction, 60x integration). |
| 6 | Bessel physics kernel | ~2 hrs | **Medium-Hard** | Power series, gradient chain rule, polyphonic normalization. |
| 7 | SVF filter + analog saturation | ~30 min | **Medium** | Moog-style resonant LP, keytracking, pre-filter tanh drive. |
| 8 | HDR + tonemapping | ~15 min | **Medium** | RGBA16Float, ACES filmic, energy-based luminance. |
| 9 | Conservation laws | ~15 min | **Medium** | Parallel reduction, threadgroup memory, CPU readback. |
| 10 | CoreMIDI input | ~15 min | **Medium** | Auto-connect all sources, noteOn/noteOff routing. |
| 11 | Feynman phase arrows | ~10 min | **Medium** | Action integral, HSV mapping. Elegant physics. |
| 12 | Noether symmetry breaking | ~10 min | **Small** | Voice hash + impulse injection. Simple, beautiful result. |

---

## Education / Technical Level Assessment

### Disciplines at work:

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

**Audio DSP (Professional level)**
- CoreAudio HAL, lock-free audio/render thread communication
- Polyphonic synthesizer with ADSR envelopes
- State Variable Filter (resonant lowpass, Moog topology)
- Analog modeling: keytracking, pre-filter saturation, noise layer
- FFT pitch detection, CoreMIDI input

**Software Architecture (Senior level)**
- Clean C++20, namespace isolation, no exceptions
- CMake build system, Metal shader compilation pipeline
- ImGui integration for real-time parameter tuning

### Verdict:
This sits at the intersection of **computational physics research** and **real-time graphics/audio engineering**. The physics is graduate/early-PhD level (Bessel eigenmodes, Hamiltonian dynamics, conservation laws). The GPU engineering is senior industry level (spatial hashing, parallel reduction, HDR pipeline). The audio DSP is professional synth-designer level (SVF, analog modeling, keytracking). The combination — a physically accurate N-body Chladni simulator with quantum mechanical features, elastic collisions, and a built-in analog-modeled synthesizer at 800k particles — is custom. It doesn't exist elsewhere.

---

## Known Issues

- **Collision left-snap**: Enabling collisions shifts particle distribution slightly left. Cell-traversal-order bias in spatial hash.
- **Zoom feel**: Hard clamps on rho [50, 2000]. HTML had smooth THREE.js OrbitControls momentum. Soft-boundary attempt caused oscillation.

---

## Roadmap

### Near-term (performance)
- [ ] Parallel prefix sum — replace serial scan (1 thread for 65k cells) with Blelloch scan
- [ ] Collision radius as UI slider
- [ ] StorageModePrivate for spatial hash buffers

### Mid-term (features)
- [ ] Synth Phase 3: Diva/Juno analog modeling (oscillator drift, component variance, polyBLEP)
- [ ] String theory rendering — vibrating loop meshes (instanced triangle strips)
- [ ] Density heatmap background layer
- [ ] ProRes recording for live performance archival
- [ ] Syphon output for Resolume/VDMX

### Long-term (research)
- [ ] Maxwell vortex medium — full PIC simulation with electromagnetic field texture
- [ ] Multi-plate coupling — multiple Chladni plates interacting through shared boundary conditions
- [ ] Audio-visual unity — same Bessel math drives both visuals and sound simultaneously
