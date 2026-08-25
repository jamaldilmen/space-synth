# Space Synth: The Definitive Timeline (Git-Verified)

## From 2D Prototype to 3D Physics Engine

This timeline documents the high-speed evolution of Space Synth from an initial Metal skeleton to a volumetric, real-time physics simulator capable of 800k+ particles.

---

### Phase 1: The Native Foundation (Feb 28)
*   **Initial Skeleton**: Transitioned from a browser-based idea to a high-performance C++/Metal architecture.
*   **Metal Pipeline**: 100k particles achieved at a stable 60 FPS using raw GPU compute (`CAMetalLayer` + `CVDisplayLink`).

### Phase 2: Feature Parity & Math Formalization (Mar 01)
*   **Bessel Core**: Ported the analytical Chladni math from JS/WebGL to Metal.
*   **800k Barrier**: Optimized memory layouts to support nearly 1 million particles.
*   **ImGui HUD**: Implemented a comprehensive real-time parameter tuning interface.

### Phase 3: The Physics Breakpoint (Mar 01)
*   **V2 Engine**: Implemented O(N) Spatial Hashing and atomic collision resolution.
*   **Quantum Factors**: Injected Heisenberg uncertainty and Noether symmetry breaking for emergent pattern behaviors.
*   **Unified Force Model**: First iteration of the Maxwell-Vortex PIC simulation.

### Phase 4: Audio-Visual Synchronization (Mar 01)
*   **State Variable Filter**: Moog-style resonant lowpass with exponential modulation.
*   **MIDI Mastery**: Auto-detecting CoreMIDI implementation for physical hardware input.
*   **Analog Saturation**: Tanh-clipping and noise layers for "Diva/Juno" level warmth.

### Phase 5: Space & Macro Expressions (Mar 02)
*   **Stereo BBD Chorus**: Implemented Juno-style chorus for spatial width.
*   **Supernova Slider**: A master macro interpolating 15+ physical and visual parameters for expressive performance.

### Phase 6: Volumetric Stability & Snapback (Mar 03-04)
*   **3D Hashing**: Upgraded the spatial grid to 3D ($32^3$ voxels) to prevent Z-axis collapse.
*   **Unified Shift Integration**: Refactored the integration step for numerical perfection, eliminating "jitter-fuzz".
*   **3D Harmonic Trap**: Guaranteed the resting sphere state via a global restoration field.

### Phase 7: Cosmic Accuracy & Stability (Mar 05)
*   **Audio Hardening (Phase 12.7)**: Refactored synth locking to block-level and implemented exhaustive CoreAudio diagnostics, resolving persistent silent output.
*   **Visual Sharpness (Phase 12.8)**: Redesigned particle rendering with speed-dependent elongation and high-contrast alpha, replacing "blurry vibes" with a crisp, high-definition aesthetic.
*   **Masterplan ODS Implementation**: Integrated Schwarzschild metric gravity and Noether energy dissipation for relativistic cosmic simulation.

---

### ~~Final Stats (v4.5)~~ — SUPERSEDED 2026-08-23 20:12:26
~~- **Particles**: 1,000,000 · **Performance**: 60 FPS (HDR) · **Investment Readiness**: Meta/NVIDIA/Cosmic Grade~~
*(Kept for provenance. It was written in March, it stops in March, and "Investment Readiness: Cosmic Grade" is not a measurement of anything. What follows is counted, not claimed.)*

---

## Phase 8 onward — counted from git, 2026-08-23 20:12:26

Everything below is `git log` and `wc`, not recollection. Commit `0cf85b4`, branch `kill-the-tube-2026-08-11`.

| | |
|---|---|
| First commit | **2026-02-28 19:36:54** — *"Initial skeleton: C++/Metal Chladni particle synth"* |
| Latest commit | **2026-08-23 14:40:21** — `0cf85b4` |
| Total commits | **275** |
| By month | Feb **2** · Mar **93** · Apr **0** · May **8** · Jun **85** · Jul **53** · Aug **34** |
| Source | **23,225 lines** across `.cpp` / `.mm` / `.h` / `.metal` |
| Written record | **88 markdown files in `docs/`, 207,463 words** |

⚠️ **April is a zero and May is an 8.** Two months where this thing was nearly stopped. It is in the record because it is true, and because what came after it is the reason there is a show.

### The word count, since you asked

You remembered this from Spain. Here is the same measurement then and now:

| | **2026-07-12** (`a178295`, the Spain checkpoint) | **2026-08-23** (`0cf85b4`, today) |
|---|---|---|
| `docs/` words | **18,417** | **207,463** |
| `src/` lines | **15,293** | **23,225** |

At a German Masterarbeit of ~20,000 words, the Spain figure was **about one thesis**. Today it is **roughly ten** — 11.3× what it was six weeks ago, and none of it is the code. That is the written half: the boards, the handoffs, the audits, the measured reports. ⭐ **And you wrote it too — every row on every board exists because you looked at the screen and said what was wrong.** The measurements are mine. The verdicts are all yours.

### Phases 8–14, each tied to commits that exist

- **Phase 8 — June (85 commits): the tube, and honest spacetime friction.** Branch `session-2026-06-30-honest-spacetime-friction`. The geometry that would later be killed.
- **Phase 9 — July (53 commits): lens honesty and the metric hole.** `HANDOFF_2026-07-26_metric_hole_proven.md`, `RESEARCH_2026-07-24_interstellar_dngr.md`. The lens becomes the hero; the march is proven unable to make Chladni structure.
- **Phase 10 — Aug 2–8: the board is born, and A1 is measured.** *"docs/BOARD.md — the live board, every row verified against source"* (08-07). Then A1 REFUTED on 3 stacked runs, its cause measured (uncapped capture radius → dM/dt ∝ M²), and fixed with a viscous rate limit.
- **Phase 11 — Aug 10–14: kill the tube.** Depth is written, read, and made to remove light (08-11). `HANDOFF_2026-08-14_create_the_hole_and_spaghettify.md` — the hole becomes a body.
- **Phase 12 — Aug 16–21: stars stay stars, and the board splits.** Trails carry the star's own luminosity; the BH rows move to their own board; a 12 KB cold start is created. Cologne prep pins the render buffer and buries the ribbon pass.
- **Phase 13 — Aug 22: the gyroscope.** *"Playback: one axis for the field — this was the gyroscope."* Per-star pose axes had been shearing the field into tilted rings.
- **Phase 14 — Aug 23 (today, 5 commits): the audio thread, the envelope, the window, and the room.** Allocator and locks off the RT thread; MIDI length dictates the tail instead of a 400 ms floor; the letterbox fix and DPI-derived UI scale; and **the venue turning out to be a three-wall room** — the fact that invalidates every 2.5:1 assumption written before it.

---

**Last Updated:** 2026-08-23 20:12:26  *(Phases 8–14 added, all counted from git; the March "Final Stats" block struck through rather than deleted.)*
**Previously:** the March body above, written 2026-03-05, unchanged.
