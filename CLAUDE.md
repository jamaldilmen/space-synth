# SPACE Synth — Project Instructions

## What This Is
C++/Metal real-time Chladni pattern particle synthesizer. Millions of particles driven by Bessel function physics, responsive to keyboard/MIDI/voice input, with mod menu and Syphon output.

## Build
```bash
mkdir build && cd build
cmake .. && make -j$(sysctl -n hw.ncpu)
./SpaceSynth
```

Requires macOS 13+, Xcode command line tools (for Metal compiler).

## Project Structure
- `src/core/` — Physics: Bessel functions, gradient LUT, mode table, particles, envelope
- `src/audio/` — CoreAudio input, FFT pitch detection, built-in synth
- `src/render/` — Metal renderer, compute shaders, post-fx
- `src/ui/` — NSWindow, ImGui mod menu
- `third_party/imgui/` — ImGui (add as git submodule)
- `third_party/syphon/` — Syphon.framework
- `presets/` — JSON preset files

## Physics Basis
Ported from `SOUND ARCHITECT.html` (cymatics repo). The proven system:
- Bessel J_n power series (25 terms)
- 28 modes (7 orders x 4 zeros), sorted by alpha complexity
- Gradient LUT: 128x128 grid, central differencing, normalized
- Polyphonic voice normalizer: `1/sqrt(voiceCount)`
- Boundary repulsion: cubic ramp r>0.85, hard wall r>0.98
- Node braking: friction scales with distance-to-nodal-line
- Speed cap: 1.2 (normalized)

## Conventions
- Namespace: `space::`
- Headers: `#pragma once`
- ObjC++ files: `.mm` extension (for Metal/Cocoa interop)
- Metal shaders: `.metal` in `src/render/`
- GPU structs: `alignas(16)` for Metal buffer alignment
- No exceptions — use return codes / optional
- Lock-free only between audio and render threads

## Phase Plan
1. Window + particles on screen (100k @ 60fps)
2. Full physics (1M particles, accurate Chladni patterns)
3. Audio (CoreAudio input, FFT, built-in synth)
4. Mod menu + polish (ImGui, presets, post-fx, Syphon)
5. Wild features (custom meshes, density viz, ProRes recording)

## Key Files to Understand First
1. `src/core/bessel.cpp` — The math foundation
2. `src/core/lut.cpp` — Gradient field computation
3. `src/render/particles.metal` — GPU physics kernel
4. `src/main.cpp` — App entry and run loop
