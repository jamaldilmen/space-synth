# SPACE Synth — Research Notes

Research areas for building the C++/Metal real-time Chladni pattern particle synthesizer.

---

## 1. Metal Compute Shaders for Particle Systems

**What's needed:** GPU kernels that process millions of particles in parallel. Each thread updates one particle's position/velocity based on Bessel potential field gradients.

**Technically:** Metal compute pipelines dispatch thread groups. Need to understand threadgroup size tuning (usually 256 threads/group on Apple GPU), buffer binding for particle state (position, velocity as float4 arrays), and how to read from LUT textures in compute kernels.

**Research:** Apple's "Metal Best Practices Guide" → Compute Processing section. Sample code: "Simulating Particles with Metal" from Apple Developer.

---

## 2. Spatial Hashing on GPU

**What's needed:** To detect when particles collide or cluster, need a spatial data structure that runs entirely on GPU. Uniform grid spatial hash is the standard approach.

**Technically:** Divide space into grid cells. Each particle hashes its position to a cell index. Use atomic operations to build a count array, then prefix-sum to build a sorted particle index. Neighbor queries scan adjacent 27 cells (3D) or 9 cells (2D).

**Research:** GPU Gems 3, Chapter 32: "Broad-Phase Collision Detection with CUDA" (concepts transfer to Metal). Also: "Fast Fixed-Radius Nearest Neighbors" by Hoetzlein.

---

## 3. CoreAudio Low-Latency Input

**What's needed:** Real-time mic/audio input on macOS with device selection (including virtual devices like BlackHole/Loopback).

**Technically:** Use AudioUnit API (RemoteIO on iOS, AUHAL on macOS). Set up an input callback that fires per-buffer (typically 128-512 samples at 44.1/48kHz). The callback runs on a real-time thread — cannot allocate memory, cannot lock mutexes, cannot call Objective-C. Pass audio data to render thread via lock-free SPSC ring buffer.

**Research:** Apple's "Audio Unit Hosting Guide". Core Audio mailing list archives. "The Audio Programming Book" by Boulanger & Lazzarini (Chapter 1).

---

## 4. FFT → Pitch Detection

**What's needed:** Extract fundamental frequency from audio input in real-time. The existing JS version uses Web Audio's AnalyserNode. Need a C++ equivalent.

**Technically:** Use vDSP (Apple's Accelerate framework) for FFT. Apply window function (Hann), compute magnitude spectrum, find peak bin, apply parabolic interpolation for sub-bin accuracy. For polyphonic pitch detection (multiple notes), need harmonic product spectrum or autocorrelation. Latency target: <20ms (1024 samples at 48kHz).

**Research:** vDSP reference in Apple's Accelerate framework docs. "A Smarter Way to Find Pitch" by Philip McLeod (MPM algorithm). YIN algorithm paper by de Cheveigné & Kawahara.

---

## 5. Metal Instanced Rendering

**What's needed:** Draw 1M+ spheres efficiently. Each particle = same mesh, different position/color/size.

**Technically:** Use instanced draw calls (`drawIndexedPrimitives:indexCount:instanceCount:`). Pass per-instance data via a Metal buffer (position, color, scale packed as float4s). Vertex shader reads instance_id to index into this buffer. For 1M instances, the buffer is ~48MB (3x float4 per instance). Use low-poly sphere (8-12 segments) to keep vertex count manageable.

**Research:** Apple's "Rendering Terrain Dynamically with Argument Buffers" sample (demonstrates instancing). Metal Shading Language spec § 5.2.3 (vertex function attributes).

---

## 6. Syphon Metal Server

**What's needed:** Share Metal textures with other apps (Resolume, TouchDesigner, MadMapper, OBS) via Syphon protocol.

**Technically:** SyphonMetalServer publishes a named server. Each frame, call `publishFrameTexture:` with the MTLTexture from your render pass. Consumer apps see your server in their Syphon source list. The texture is shared via IOSurface (zero-copy on macOS).

**Research:** Syphon-Framework GitHub repo. SyphonMetalServer.h header (it's the API). Test with "Syphon Simple Client" app to verify output.

---

## 7. ImGui Metal Backend

**What's needed:** Debug/mod overlay rendered directly with Metal. No separate rendering context.

**Technically:** ImGui's Metal backend (`imgui_impl_metal.mm`) hooks into your existing render pass. You create a render command encoder, call ImGui render, it draws the UI on top of your scene. Needs: ImGui context init, Metal device/queue references, input forwarding (mouse/keyboard events).

**Research:** `imgui/examples/example_apple_metal/` in the ImGui repo. One-file example that shows the complete setup.

---

## 8. Chladni Pattern Validation Data

**What's needed:** To claim "physically accurate," need reference data from real experiments. Known Chladni patterns for circular plates with free/clamped edges at specific frequencies.

**Technically:** The math uses Bessel functions of the first kind J_m(α_{mn} r) cos(mθ) for circular plates. The zeros α_{mn} determine nodal patterns. Need to verify that simulation nodal lines match analytical predictions for modes (0,1) through (6,4). Real plates also have damping, plate thickness effects, and nonlinear behavior at high amplitude that Bessel theory ignores.

**Research:** "Vibration of Plates" by Arthur Leissa (NASA SP-160) — the definitive reference. Chladni pattern photography databases. Mary D. Waller's experimental photographs (1930s-1960s).

---

## 9. ProRes / H.264 Hardware Encoding from Metal

**What's needed:** Record the visualization to video file without dropping frames.

**Technically:** Use VideoToolbox (VTCompressionSession) to hardware-encode Metal textures. The M-series media engine does ProRes encoding in silicon. Pipeline: render to MTLTexture → create CVPixelBuffer from texture (or use IOSurface backing) → feed to VTCompressionSession → write to AVAssetWriter. Target: 4K ProRes 422 at 60fps.

**Research:** Apple's VideoToolbox framework reference. "AVFoundation Programming Guide" → "Exporting" section. WWDC sessions on ProRes and hardware encoding.
