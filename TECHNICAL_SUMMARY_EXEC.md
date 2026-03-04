# Space Synth: Executive Technical Brief

## System Overview
Space Synth is a high-performance, real-time Particle-In-Cell (PIC) simulator and synthesizer. It operates as a mechanical simulation of an elastic medium where audio frequencies act as physical stressors to a 3D particle cloud.

## Engineering Stack
- **Architecture**: C++20 / Objective-C++ / Metal Shading Language.
- **Compute**: O(N) Spatial Hashing on a $32^3$ voxel grid. Parallel Prefix Sum (Blelloch) for offset scatter.
- **Synchronization**: Triple-buffered GPU command queues with semaphore-gated host-device sync.
- **Audio**: Low-latency CoreAudio HAL with a State Variable Filter (ZDF) and BBD Stereo Chorus.

## Mathematical Core
- **Analytical Basis**: Bessel eigenfunctions of the Laplacian on a disk, helical 3D phase projection.
- **Emergent Physics**: Unified Force Model combining Coulomb (repulsion), Biot-Savart (spin), Hooke (tension), and Newtonian (gravity) analogs.
- **Entropic Injection**: Heisenberg and Noether noise models for behavioral realism.

## Performance
- **Capacity**: Synchronous rendering and physics for 800,000 particles.
- **Visuals**: Filmic HDR pipeline with ACES tonemapping and real-time bloom/chromatic aberration.

**Proprietary $10,000,000 Milestone Build.**
