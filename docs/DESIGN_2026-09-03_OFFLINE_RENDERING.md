# DESIGN — OFFLINE RENDERING: HOW TO IMPLEMENT IT
**Written:** 2026-09-03 06:04:45 · SONNET window · **DESIGN ONLY — zero source lines written, no build run, nothing launched.**

> **HIS WORDS, VERBATIM (relayed by BRAIN):** *"answer the rendering question. Offline rendering. How can we implement it."*
> A HOW question, not a feasibility one. This is an implementation design at the level of files, functions and call sites, not a strategy memo.

> **Cold start:** this is a design, not state. State is `docs/BOARD_BLACKHOLE.md` §AD → §AC.12.
> Every claim below is tagged `[READ file:line]` (re-grepped) or `[DESIGN]` (my reasoning over the read facts). Four parallel research passes fed this; none of their line numbers were inherited from memory.
>
> ⚠️ **CITATION-VALIDITY STATE, re-verified 2026-09-03 06:15:26 — read this before trusting a line number below.** HEAD `6530c45`, working tree with FOUR uncommitted changes in place at verification time: `src/core/midi_input.mm` (mine, the Real-Time MIDI fix, unrelated to this doc), `src/main.cpp` (+11, FABLE's `SS_PHASE_AMOUNT` diag hook at `:386-396`), `src/render/renderer.mm` (+28/-6, net +22, FABLE's return-pull v4 hole-seen latch landing around `:1834`), `src/render/render.metal` (FABLE's, not read for this doc). **The first research pass read the tree BEFORE FABLE's `main.cpp`/`renderer.mm` edits landed; every citation below `renderer.mm:1834` and `main.cpp:396` in the original write was consequently off by a constant +22 or +11 — not invented, drifted.** All citations in this version were re-grepped against the tree AT THE TIMESTAMP ABOVE. If the tree changes again (FABLE holds the build/edit token and is actively working it), re-grep before trusting any line number here — do not re-derive by arithmetic, per the board's standing rule.

**Relationship to my prior research (`docs/HANDOFF_2026-09-03_SONNET_HOLD.md` §2.4):** that was two subagents' external/generic research, untested against this tree. This doc supersedes it with this-codebase-specific facts. Kept: the two-track shape (safe real-time MVP now vs. a fuller decoupled pipeline later) and ProRes+IOSurface+AVAssetWriter as the capture technology. Revised: "swap the wall clock for a virtual clock" — grounded now as at least two separate clock systems plus 6 more independent timestamp reads, not one swap. Withdrawn/softened: §2.4 never addressed determinism; the honest answer here is bit-exact replay is not achievable without a risky core-logic change, which changes what "record/replay" can promise. New, not in §2.4 at all: the audio→physics coupling risk, the Syphon pass as the exact existing capture tap point, and the `sizeResScale` resolution trap tied to an unused existing hook.

---

## 1. THE CLOCK

**There is no single clock to decouple — there are at least three, and one of them is undocumented as a physics input.**

**1a. The physics step-count clock — the one everyone means by "the clock":**
`[READ renderer.mm:1713]` `dt = 0.0165f * timeWarpVal` — the fixed step **size**, unconditionally pinned, confirmed correct design (this is §AD.13's closed finding, not reopened here).
`[READ renderer.mm:1775-1816]` Step **count** comes from a true-time accumulator: `kStepWall = 0.0165` (`:1775`), `nowTT = CACurrentMediaTime()` (`:1779`), `wall = nowTT - trueTimeLast` clamped to ≤0.25s (`:1783`), `trueTimeAcc += wall` (`:1787`), `n = floor(trueTimeAcc / kStepWall)` (`:1788`), clamped to `sMaxSteps` (default 4, `SS_MAX_STEPS` env override, `:1770-1773`), carry capped at one step's worth, never dropped silently (`:1808,1813`). Output: `pendingSteps` (`:1814`).

**1b. The substep structure — two nested loops, not one, and the "22 of 23" quote describes only the inner one:**
`[READ renderer.mm:2520-3645]` Outer **"true sub-step" (`tsub`) loop**: `nTrue = pendingSteps` on the shipped default path (`:2517`). This loop **recomputes the entire pipeline every iteration** — spatial hash, phi/gravity, SPH density/pressure/force, Poisson+AMR, `reduceCellMax`, `mergeStars`, `seedMark`, density, integrate, `seedApply` — 24 dispatch sites counted directly between `:2520` and `:3645`.
`[READ renderer.mm:3583-3620]` Inner **"physics substep" (`ssub`) loop**: `nSub = physicsSubsteps` (the UI slider, `main.cpp:1563`). This loop re-dispatches **only** the integrate kernel against forces frozen before it started.
`[READ renderer.mm:2498-2499]`, verbatim: *"22 of the 23 compute passes run ONCE per frame and only the physics integrate re-runs per substep, so N substeps advance N steps against a FROZEN force field."* — **this describes the inner `ssub` loop.** The outer `tsub` loop is not frozen; it recomputes forces fresh every `pendingStep`. `[SUBSTEPS FREEZE THE FORCES]` in memory is about the inner loop specifically, not the whole engine.
⚠️ Unresolved tension found, not chased: a comment at `renderer.mm:3581` claims the stable substep path "runs drain/merge N× too," but `mergeStars` (`:3510-3535`) sits before the `ssub` loop starts (`:3583`) — by direct read it runs once per `tsub`, not once per `ssub`. Flagging for whoever next touches this loop; not blocking this design.

**1c. Warp:** `[READ renderer.mm:1713, 1729-1734]` confirmed — warp scales step **size**, never count. *"warp makes each step BIGGER, never more frequent."* Not touched by this design.

**1d. The clock source is not one hook — `CACurrentMediaTime()` is called independently at 8 sites in `renderer.mm`:** `:387` (`bhPoseClock`), `:1779` (the accumulator above), `:2175`, `:2357`, `:4502`, `:4749`, `:5038`, `:5128`. **I did not audit each of these individually** — that audit is the first implementation task (§6), not something to skip. `bhPoseClock` at `:387` is the one that worries me most by name: if BH rotation pose reads wall time directly rather than through the accumulated sim clock, that's a physics-relevant quantity still tied to real time even after the accumulator itself is virtualized — exactly "a frame is not a unit of time" in a new dress, on the one subsystem (BH rotation) this whole project is built around.

**1e. A second, independent real-time clock exists at the window level, and it feeds the render, not just the physics:** `[READ window.mm:69-83, 737-749]` `CVDisplayLink`-driven, `dt` from `mach_absolute_time()`, clamped 0.25s max (the 30fps ceiling was removed 2026-08-30 per inline comment). This `dt` drives `main.cpp:655`'s `seqTime += dt` (the sequencer), VJ band release/crossfade, camera spin integration, and `smoothedAmp` — **separately from** the physics true-time accumulator. **Decoupling only 1a and ignoring this one reintroduces wall-clock coupling one layer up** — the sequencer and camera would still run at real speed while physics runs virtualized, desyncing them.

**[DESIGN] What an offline mode does to each of these:**
- **1a (physics step count):** replace `CACurrentMediaTime()` at `:1779` with a virtual clock that advances by exactly `kStepWall × stepsPerOutputFrame` every offline frame — a chosen constant, not measured wall time. Remove the `0.25s` stall guard and `sMaxSteps` clamp in offline mode (they exist to survive real hitches; offline has none — it can take as long as it needs per frame). This is `pendingSteps` becoming a **design parameter**, not a measurement. `stepsPerOutputFrame` can now be set higher than anything 120fps-live could afford — this is the actual "quality" leverage point (§5).
- **1b (substeps):** leave the outer `tsub` loop's per-pendingStep force recompute as-is — it's correct physics, not a limitation. For the inner `ssub`/`physicsSubsteps` loop, offline should default it to 1 (forces recomputed every real step rather than frozen across several integrate-only substeps) — trading GPU cost the live path can't afford for physical accuracy the offline path can.
- **1d:** audit all 8 sites (task, not done here) and classify each as physics-relevant (must virtualize) or cosmetic/diagnostic (leave on wall clock, harmless). `bhPoseClock` is the priority one to check first.
- **1e (window clock):** in offline mode, drive the window-level `dt` from the same virtual per-output-frame clock as 1a, not from `mach_absolute_time()` — sequencer, camera spin, and VJ crossfade must advance in the same virtual time as physics, or the recorded take desyncs from its own camera moves.
- **Motion blur:** `[READ postfx.metal:478-517]` the in-shader analytical motion blur is **dead code** — `if (false && ...)` at `:507`. There is no working screen-space alternative to fall back on. Real motion blur therefore requires temporal supersampling: multiple physics/render sub-frames per output frame, accumulated. This is now buildable in principle (1a makes extra sub-frames free of wall-clock cost) but the accumulation/averaging pass itself is unbuilt — **marking this POST-COLOGNE** (§6); pre-Cologne scope is "more real steps at finer granularity," not blur.

---

## 2. AUDIO

**The safe MVP touches nothing on the RT thread. The full offline pipeline requires decoupling audio too, and that part is a real, unverified risk — named honestly, not attempted before Cologne.**

`[READ]` MIDI → synth path, re-traced: `midi_input.mm`'s callback (CoreMIDI thread) → `main.cpp:213`'s lambda → `synth.noteOn`/`noteOff` **directly, synchronously, on the MIDI thread** — no intermediate queue between the MIDI thread and `Synth`. Inside `Synth`, `noteOn`/`noteOff` (`synth.cpp:164,177`) push into `commandQueue_` under `queueMutex_`, sorted by sample offset.

⚠️ **Correcting a gap in what was previously known, not something this design needs to fix, but relevant to what "touching the RT thread" means:** `queueMutex_` is not just "still a blocking lock_guard as a fallback" — it is a **blocking lock on the RT audio thread's hot path, unconditionally, every single audio block.** `[READ synth.cpp:91]`: `{ std::lock_guard<std::mutex> lock(queueMutex_); swapBuffer_.swap(commandQueue_); }` runs inside `processBlock` every call, contending with the MIDI thread (`:164,177`) and the main thread (`:150`, via `activeVoiceCount()`). `mutex_`'s half of this (`:99`, `try_to_lock`) is closed; this half is not, and it is worse than "an edge case" — it is unconditional. **This design does not propose fixing it** — it is pre-existing, out of scope, and BRAIN's constraint stands: the offline design must not touch the RT thread at all.

`[READ]` No existing recording/export code anywhere in `src/` — no MIDI logging, no `AVAudioFile`/`ExtAudioFile`/`AVAssetWriter`, no offline audio render path. Confirmed by grep, not assumed absent.

`[READ synth.h:121]` `MAX_VOICES = 64`, fixed array, voice-stealing prefers Release > Sustain > Decay, never steals Attack; a new note is dropped if all 64 are in Attack (`synth.cpp:253-258`, a documented deliberate change from an earlier unlimited version).

🚨 **The coupling that makes this harder than §2.4 assumed:** `[READ]` `synth.totalAmplitude()` and `synth.getDominantEnvelope()` (phase/progress/intensity) cross into `physicsUniforms.totalAmplitude` (`renderer.mm:1818-1819`) via `renderer.setEnvelopeState(...)` (`main.cpp:2661`). `totalAmplitude < 0.02f` alone gates **12 distinct branches** in `renderer.mm` — re-grepped directly, not inherited: `:1834` (inverse form, `>= 0.02f`), `:2111` (`bhLensActive`, lens on/off), `:2744, 2770, 2810, 2847, 2867, 2885, 2908, 3003, 3056` (LATCH-adjacent checks), `:3522` (`notPlaying`). **This value is not cosmetic — it changes which physics code paths execute.** Any offline path that wants visual fidelity to a real performance must reproduce this scalar's evolution exactly, not approximately.

**[DESIGN] Two tiers, matching §6's before/after-Cologne split:**

**Tier 1 — pre-Cologne MVP, zero RT-thread changes, audio stays live/real-time always:**
Tap `main.cpp:213`'s existing lambda — the same point that already calls `synth.noteOn`/`noteOff` — and in addition, append `{tick, note, velocity, isNoteOn}` to a recording buffer. This is a pure addition at a point that is **already on the MIDI thread, already calling into `Synth`'s existing thread-safe API** — no new contention, no RT-thread code touched. Replay: read the log back and re-issue the same `synth.noteOn`/`noteOff` calls at the same relative ticks, into the **same live app, audio running live in real time as always.** `totalAmplitude`/envelope evolve exactly as they would for a live take, because the audio engine genuinely is running live — this sidesteps the coupling problem entirely, at the cost of not being able to run physics/render slower or heavier than real-time during replay (audio would fall out of sync with a slowed-down visual pass).
This is "redo a take" — genuinely useful, low risk, and it is what §2.4's original MVP meant, now grounded in the exact tap point (`main.cpp:213`) instead of a generic description.

**Tier 2 — post-Cologne, the full quality pipeline, requires decoupling audio too:**
To render slower-than-real-time (the actual point of "offline buys quality" — §5), the audio engine cannot stay pinned to CoreAudio's real callback cadence while physics/render take longer per frame than real time allows, or the two desync. This requires calling `Synth::processBlock()` **in a manual offline loop** instead of from CoreAudio's real-time callback — computing the same sample-accurate output deterministically, paced by the offline virtual clock instead of a live audio device. `[DESIGN]` Nothing in `processBlock`'s RT-safety mechanism (`try_to_lock`, `queueMutex_`) implies it *requires* real wall-clock pacing — the RT-safety concern is about being called *from* a thread that must never block, not about *when* it's called. But **this is unverified**: whether the sample-accurate scheduling logic (`commandQueue_` sorted by `sampleOffset`) behaves correctly when driven by a tight offline loop rather than real audio-block timing has not been tested. **Named as the key open engineering risk for the full pipeline. Not attempted before Cologne.**

---

## 3. DETERMINISM

**Bit-exact replay is not achievable without a real, risky change to core merge/seed logic. The honest design target is visual/statistical reproducibility — "a similar take," not a guaranteed replica.**

`[READ particles.metal]` Two classes of atomics:
- **Order-independent (safe):** scaled-integer `atomic_fetch_add`/`atomic_fetch_max` accumulators (`:1660,1668,1670,1672,1678,3732,2067,2445`) — sum and max are commutative; GPU thread order doesn't change the result.
- **Order-dependent (the real nondeterminism source):** CAS-based "claim" protocols — seed-slot claim (`:1650, 1791`), merge-pair claim (`:3931-3938`, comment at `:3925`: *"own both participants atomically before writing"*), victim-capture claim (`:4303,4312`, *"atomically swap the victim's mass word with 0"*). **Each of these picks a winner based on which GPU thread's compare-exchange lands first — Metal gives no guarantee this is identical across dispatches, runs, or hardware.**

`[READ renderer.mm:3713,3737,3758-3761]` `gMaxMass` is a per-frame CPU-side max-reduce over GPU partials — itself order-independent. Its documented "non-monotonic" behavior (*"a shrinking gMaxMass now shrinks the hole too"*) is a deliberate semantic property (a live current-max, not a running historical one), not a race — but it inherits nondeterminism indirectly if the claim races above change which particle ends up heaviest.

🚨 **The strongest evidence in this section, and it's measured, not inferred — the sample cap in the densest cell is a live, resampled-every-frame nondeterminism source.** Two separate, unrelated facts, both verified against current code, do not contradict each other: `[READ renderer.mm:140,148-149]` `kGridSize=128`, `kTotalCells=128³=2,097,152` — the total number of grid cells. Separately, `[READ renderer.mm:404,4407]` `bhPeakCount`, documented *"densest single cell, true count, uncapped"*, is the actual particle count inside the single densest cell — measured at **334,576 particles in one cell**. `[READ particles.metal:195]` `SCATTER_PER_CELL=32` caps how many of those particles `scatter_particles` (`spatial_hash.metal`, first-come `atomic_fetch_add`) actually stores per cell — so in the core, where a hole forms, the physics considers roughly 0.01% of the matter present, and **which 32 particles survive the cap is decided by GPU scheduling order, resampled every frame.** This is not a hypothesis: `[[space_synth_grid_samples_32_of_334k_2026-08-30]]`, measured n=4 stacked runs per arm, identical input — cap 32 forks **11.1×** on `Mmax` and produces 1-2 seeds; cap 64 forks **3.4×** and produces 7-8 seeds. Doubling the sample cut the fork 3× and quadrupled seed formation. **This is direct, measured proof that identical input does not produce identical black-hole formation today** — a stronger basis for the verdict below than the claim-protocol argument alone.

`[READ particles.metal:121-127]` `noise(id, frame)` is a pure deterministic integer hash — not a nondeterminism source.

**Verdict, stated at its actual limit:** bit-exact determinism (same input → byte-identical frames) is not currently plausible — both the per-cell sample cap above (measured, 11.1× fork) and the claim-protocol races in merge/seed/capture logic (§ above) are load-bearing parts of core physics, and fixing either (raising `SCATTER_PER_CELL` is an explicitly-flagged physics-and-performance decision per `particles.metal`'s own comment, not a tunable; fixing the claim races means a canonical tie-break like lowest particle ID replacing "first CAS wins") is a real change to core physics logic, high-risk two days out, not proposed for Cologne. **Visual/statistical reproducibility is the realistic and sufficient target**: same aggregate trajectories and overall behavior, but specific outcomes — including how many black holes seed and where — can differ between two runs of identical input.

**[DESIGN] What this means for the feature, stated plainly so it isn't oversold:** a replayed take is **not** guaranteed to reproduce a specific past live take pixel-for-pixel or merge-for-merge — it is a new, similar performance driven by the same input. For Cologne, the honest framing is: **an offline pre-recorded segment is its own good take, made in advance at full quality — not a guaranteed reproduction of a specific past live moment.** This costs nothing against memory's own framing (`[COLOGNE PARTLY/WHOLLY PRE-RECORDED]` — *"offline time buys quality, never shortcuts"*) since the offline pass doesn't need to reproduce anything; it only needs to be good.

---

## 4. THE OUTPUT PATH

**The exact tap point already exists and already produces the right pixel. The gap is entirely in getting it off the GPU and onto disk, plus one resolution trap to handle deliberately.**

`[READ postfx.metal:117-573]` The colour pipeline is one fragment shader, sequential stages in order: chromatic-aberration sample → coverage resolve → motion smear → bloom composite → global exposure → auto-exposure → max-channel tonemap + Lupton/SDSS asinh stretch → sensor bleach (dial, default off) → display grade LUT (33³ RGBA16F) → neon grade → VJ colour effects → analytical motion blur (dead code) → vignette → strobe → dither → final return (`:566-573`): **the fully graded, display-ready pixel.**

`[READ renderer.mm:555 (init), 5391-5433 (render+publish)]` **`SyphonMetalServer` already runs a dedicated second full-postfx render pass** producing exactly this final graded, alpha-keyed, no-UI frame into `syphonTexture` (RGBA16Float, `MTLStorageModePrivate`), with `edrHeadroom` forced to 1.0 for SDR compression, gated behind `hasClients` (`bool syphonLive = ... && syphonServer.hasClients;`, `:5402`) so it costs nothing when unused; publish call at `:5433`. **This is the tap point** — for capture, force this pass to always run during a capture session regardless of client connection.

`[READ renderer.mm:5664-5665]` The final drawables and every offscreen target (including `syphonTexture`) are `MTLStorageModePrivate` — GPU-only, no CPU readback without an explicit blit. `[READ renderer.mm:5425-5427]` a same-shaped precedent already exists — a blit from `drawable.texture` into `prevFrameTexture`. **[DESIGN]** Replicate this pattern: blit `syphonTexture` into a new IOSurface-backed, Shared/Managed texture, which becomes the zero-copy source for an `AVAssetWriterInput` pixel-buffer adaptor writing ProRes 4444 — matching §2.4's original capture-format recommendation, now grounded in an exact source texture and an exact existing blit precedent to copy. `[READ]` confirmed zero existing AVFoundation code anywhere in `src/` — this is new, from scratch.

🚨 **The resolution trap, found this session, not in §2.4:** `[READ renderer.mm:1434]` render resolution is not independently configurable by default — `resize()` tracks `metalLayer.drawableSize` directly. `[READ renderer.mm:2156]` `cam.sizeResScale = height / 2260.0f` ties the physics/lens scale calibration to the **live render height** (2260 = his fullscreen reference). This is the same trap FABLE is already fighting on Chladni resolution-dependence. **A decoupling hook already exists, unused:** `[READ window.mm:519-521, 393-396]` `Window::pinDrawableSize(pixelW, pixelH)` forces `layer.drawableSize` to an exact pixel size regardless of window/screen — nothing currently calls it.
**[DESIGN] Two options, my recommendation is the second but it needs coordination, not solo action:**
1. Capture at height 2260 always (matching the existing calibration), let any final upscale happen downstream in the edit. Zero physics-scale risk, simplest, no new trap.
2. Use `pinDrawableSize` to render natively at a higher resolution for real quality, but **decouple `sizeResScale`'s reference from the live pixel height** in offline/pinned mode (hold it at the constant `2260.0f` regardless of actual output size) so physics/lens calibration doesn't drift with capture resolution. This is what "offline buys quality" should mean for resolution — but it touches the exact scale-dependence trap FABLE is mid-fight with; **do not implement this without coordinating through BRAIN first.**

Colour: capture after the full postfx chain (already what Syphon produces) — display-referred, exactly what's seen live. A pre-grade linear/HDR intermediate capture (for a proper downstream color-grade pass) is a real, larger alternative design — **flagging as a possible post-Cologne upgrade, not proposed now.**

---

## 5. WHAT IT IS FOR

Per `[COLOGNE PARTLY/WHOLLY PRE-RECORDED]`: offline time buys quality, never shortcuts. Concretely, in this codebase, "quality" means:

1. **More sim steps per output frame** (§1's virtual clock) — smoother, more physically resolved motion during fast events (mergers, collapse) that are limited today by what's affordable at 120fps live.
2. **`physicsSubsteps` effectively unconstrained** — the frozen-force approximation (§1b's inner loop) becomes unnecessary when frame budget isn't a constraint; forces can be recomputed near-continuously.
3. **Real higher native resolution** (§4, once `sizeResScale` is handled correctly) — actual detail increase, not upscaling.
4. **Temporal-supersampled motion blur** — a real visual capability that doesn't exist today (the in-shader path is dead code), made possible once extra sub-frames are free of wall-clock cost.
5. **Possibly** relaxing the `SCATTER_PER_CELL=32` per-cell cap for denser scenes — flagged as a research question, not verified whether it's a hard buffer-size constraint or a tunable performance dial. Not committed as buildable before Cologne.

What it must not be: the same real-time run, just recorded. That is decoration, not quality, and is explicitly not what this design proposes as the deliverable — it's what Tier 1's MVP alone would produce if nothing further is built.

---

## 6. SCOPE AND SEQUENCE

**Buildable before Cologne (2026-09-05), none touching the live stage branch's real-time path:**

| # | Step | Verifiable by | Touches RT thread? |
|---|---|---|---|
| A | MIDI event + feature (`totalAmplitude`/envelope-phase) logger, tapping the existing `main.cpp:213` lambda | log file contains a recognizable note-on/off + feature stream matching a live session | No — MIDI thread only, existing API |
| B | Real-time replay of a logged take through the same live app, same `synth.noteOn`/`noteOff` calls, audio genuinely live | replaying a captured take produces a recognizable, audibly/visually similar performance | No |
| C | Downstream crossfade between live and replayed takes in the existing Syphon-receiving VJ mixer | mixer can cut between two Syphon sources | No — not in-app, existing architecture |

**Steps A+B alone deliver "redo a take" — genuinely useful, low risk, ships before Cologne if authorized.**

**Explicitly AFTER Cologne — do not attempt now:**
- Decoupling the physics true-time accumulator (§1a) from wall clock — real change to `renderer.mm`'s core step-count logic on the stage branch, plus auditing the 7 other `CACurrentMediaTime()` sites individually.
- Decoupling the window-level `CVDisplayLink` clock (§1e) similarly.
- Running the synth in offline/batch mode (§2 Tier 2) — unverified integration risk, needed only for slower-than-real-time rendering with synced audio.
- The AVAssetWriter/ProRes/IOSurface capture pipeline itself (§4) — new code from scratch, needs the Syphon-tap-and-blit and resolution decision first.
- Any fix to the GPU claim-protocol races for determinism (§3) — real risk to core merge/seed logic; may never be necessary if the "own take, not exact reproduction" framing (§3) is accepted.
- The `sizeResScale`/`pinDrawableSize` resolution decoupling (§4 option 2) — coordinate with FABLE's Chladni resolution work before touching this; it is the same trap.
- Motion blur via temporal supersampling (§1) — depends on the virtual clock work above.

**Droppable pieces, named now, not discovered Thursday:** the VJ-mixer crossfade (C) can be dropped and the log/replay (A+B) still stands alone as a useful safety net. The higher-resolution capture (§4 option 2) can be dropped in favor of the fixed-2260 capture (option 1) with zero loss of the rest of the pipeline.

---

**Last Updated:** 2026-09-03 06:04:45
**Status:** DESIGN, UNAPPROVED, UNCOMMITTED. No source code written. No build run. Build token is FABLE's.
