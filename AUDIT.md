# SPACE SYNTH TUBE — Architecture Audit (2026-06-05)

Read-only analysis. No code changed. Branch: `optimize-stable`. 9,081 LOC across src/.

## Executive summary
The app **works and the physics/render core is strong**, but the architecture has three structural problems that make it hard to optimize and extend safely:
1. **`main.cpp` is a 1,400-line god-function** — one `main()` holding window loop, ALL ImGui UI, audio wiring, sequencer, MIDI, FPS, and per-frame state (64 `static` UI vars).
2. **`particles.metal` is a 1,086-line monolithic kernel** — ~30 distinct concerns (BH lifecycle, forces, collisions, phase, temp, entanglement, orbits, caps) in one `compute_physics`, branched by a `debugFlags` god-switch.
3. **`renderer.mm` (1,406 lines) mixes 6+ responsibilities** — Metal init, compute dispatch, spatial-hash orchestration, rendering, post-FX, stats readback, matrix math.

None are bugs; all are maintainability/optimization debt. The good news: the module *boundaries that exist* (audio/, core/) are mostly clean, so refactoring is additive, not a rewrite.

---

## Findings by category

### A. Misplaced logic / god-objects
- **`main.cpp:63` — `int main()` runs ~1,340 lines.** The window frame-callback lambda contains the entire UI tree, the physics step call, audio param wiring, the sequencer engine, and the FPS counter. There is **no application/state layer** — `main()` *is* the app.
- **64 `static` UI variables** live as locals in `main()` (`main.cpp:176-269`). State, view, and control are fused.
- **Sequencer logic** (`seqNotes`, `seqNoteOn`, `seqTime`, advance loop) lives inline in `main.cpp` — it's a self-contained subsystem that belongs in its own unit (`core/sequencer`).
- **`renderer.mm`** owns both *physics orchestration* (`computeStep`, `runComputePass`, spatial-hash build, stats reduction) and *rendering* (`renderWithCamera` ~300 lines, post-FX, ImGui). Physics-compute scheduling is a separable concern from drawing.
- **Matrix math** (`orthoMatrix`, `perspectiveMatrix`, `invertMatrix4x4` at `renderer.mm:1335+`) is generic utility code sitting in the renderer — belongs in `core/math`.

### B. Separation of concerns
- **No data/UI/state split.** UI controls write directly into `static` locals, which are read directly into a `RenderConfig` rebuilt **every frame** and into direct synth mutations. There's no single source of truth for app state.
- **Duplicated wiring.** Envelope params are pushed into the synth in multiple places (`synth.envelopeParams().attack = uiAttack/1000` appears at ~`main.cpp:995, 1002, 1015, 1313, 1339`). Same value, several sites → drift risk.
- **Audio module is the clean counter-example.** `audio/` (synth, audio_engine, fft, chorus, svf, envelope) is reasonably modular and cohesive — use it as the template for the rest.

### C. Overly coupled / complex
- **`particles.metal` `compute_physics`** is the biggest complexity hotspot: one kernel, ~30 sections, gated by `debugFlags` bitmask branches (`1<<0`..`1<<9`). Every particle evaluates every feature's branch each frame — **this is also where the perf lives** (see optimization note). Hard to reason about, hard to optimize selectively.
- **`debugFlags` is a god-switch** shared CPU↔GPU; bits mean different things in different blocks. After the UI cull, several flag-driven paths are no longer reachable from the UI but still execute on the GPU (dead compute = wasted cycles, ties into the overdraw/compute perf story).

### D. Dead code & inconsistencies
- **`src/ui/mod_menu.cpp/.h` is compiled (`CMakeLists.txt:28,46`) but never referenced** anywhere — the real menu is hand-rolled in `main.cpp`. Dead module.
- **Stale struct-size comment:** Metal `Particle` is documented "matches GPUParticle … (64 bytes)" (`particles.metal`, `render.metal`, `blackhole.metal`) but the C++ struct is **80 bytes** (`core/particles.h:45`). The layout is correct; the comment is wrong and misleading.
- **Newly-orphaned UI vars** after the dead-end cull (uiEField, uiRotationX/Y/Z, solo flags, etc.) still exist and are still passed into `computeStep`/`debugFlags` at defaults — harmless but should be reconciled with the GPU paths they feed.

---

## Recommended steps — most critical → optional

1. **(Critical, low-risk) Delete dead code.** Remove `ui/mod_menu.*` from the build + tree; fix the "64 bytes"→80 comment. Pure subtraction, zero behavior change, shrinks the surface before any refactor.
2. **(Critical) Extract app state into one struct.** Move the 64 `static` UI vars in `main()` into a single `AppState`/`UiState` struct (one source of truth). Mechanical, unblocks everything below.
3. **(High) Split the UI out of `main.cpp`.** Move the ImGui panel tree into a `ui/control_panel` unit that takes `AppState&` + the subsystems. Targets the #1 god-file; makes `main()` a thin loop.
4. **(High) Centralize subsystem wiring.** One `applyState(AppState&, synth, renderer, …)` per frame instead of scattered direct mutations — kills the duplicated envelope-param writes.
5. **(High, optimization-adjacent) Carve the monolithic kernel.** Split `compute_physics` into phase-scoped functions (lifecycle / forces / collisions / integrate / pack) — even within one kernel, as `static inline` helpers. Prereq for selectively cutting dead GPU paths (the real perf win) without fear.
6. **(Medium) Separate physics-compute from rendering in `renderer.mm`.** Pull compute dispatch + spatial-hash + stats into a `ComputeEngine`; leave `Renderer` for drawing. Clarifies the profiler story (compute vs render+postfx).
7. **(Medium) Extract the sequencer** from `main.cpp` into `core/sequencer`.
8. **(Low) Move matrix helpers** (`ortho/perspective/invert`) to `core/math`.
9. **(Optional) Reconcile `debugFlags`** with the post-cull UI: remove GPU branches no longer reachable, or re-expose them deliberately. Folds into step 5.
10. **(Optional) Document the module map** in CLAUDE.md once the boundaries above exist.

### Sequencing note
Steps 1–4 are CPU-side, low-risk, and make the codebase navigable. Steps 5–6 are where architecture meets the **optimization mission** (dead GPU paths + compute/render split). Do 1–4 first to get a clean base, then 5–6 with the honest profiler as the measuring stick.
