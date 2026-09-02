# SPACE SYNTH — handoff 2026-09-02 09:52:00 — DEAD-CODE SWEEP (PARTIAL) + MIDI PARSER AUDIT

> **His verdict on this state:** not seen directly yet — this session worked under BRAIN, relaying to him via BRAIN. One item (reduceCellMax) already reached him and is RULED, see §2.
> **Cold start:** `docs/BOARD_BLACKHOLE.md` / `docs/BOARD.md` — **NOT this file.** This session did **not** fold these findings into either board — see the note at the end of §1.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` @ `true-physics` @ `06982a0`
**Build + launch:** **NONE THIS SESSION.** Read-only throughout — his order relayed by BRAIN: no build (FABLE holds the token, mid the DISK-BOUND flag change), no launch (BRAIN running the app live for the plane measurement). Everything below is a source-read + `grep` audit only.
**Session origin:** dispatched by BRAIN on his order 2026-09-01 13:41 (*"sure we have a ton of dead ends that are costing us proper"*), then redirected to a live MIDI question 2026-09-01 15:35.

---

## 1. ✅ CLOSED THIS SESSION — verified findings, not yet acted on

| # | Finding | Where | Proof |
|---|---|---|---|
| 1 | `CameraUniforms.waveDepth` — never written from CPU, zero shader consumers. Same dial family as the 4 he already deleted in `06982a0`. | `renderer.h:210`, `render.metal:30` | `[READ]` grep: zero hits in `renderer.mm`; 1 hit in `render.metal` (the declaration only) |
| 2 | `CameraUniforms.envelopeProgress` — written every frame, zero shader consumers | `renderer.h:212`/`render.metal:32`, write `renderer.mm:1985` | `[READ]` same grep pattern, count=1 |
| 3 | `CameraUniforms.oscAmount` — written every frame, zero shader consumers | `renderer.h:218`/`render.metal:38`, write `renderer.mm:2088` | `[READ]` count=1 |
| 4 | `CameraUniforms.bhStrength` — written every frame, zero shader consumers (distinct from the live `PhysicsStats.bhStrength`, different struct) | `renderer.h:223`/`render.metal:43`, write `renderer.mm:2096` | `[READ]` count=1 |
| 5 | `CameraUniforms.viewportH` — written every frame, zero shader consumers; comment claims it drives "the streak arc" — it does not | `renderer.h:238`/`render.metal:57`, write `renderer.mm:2092` | `[READ]` count=1 |
| 6 | `PhysicsUniforms.maxWaveDepth` — written every frame, zero shader consumers | `renderer.h:384`/`particles.metal:51`, write `renderer.mm:1806` | `[READ]` count=1 across all 4 `.metal` files |
| 7 | `PhysicsUniforms.uncertaintyStrength` — hardcoded `1.0f` every frame (not even a variable), zero shader consumers | `renderer.h:392`/`particles.metal:59`, write `renderer.mm:1835` | `[READ]` count=1 |
| 8 | `PhysicsUniforms.fieldMassMsun` (GPU-uniform copy — distinct from the live `PhysicsStats.fieldMassMsun` readback) — zero shader consumers | `renderer.h:427`/`particles.metal:97`, write `renderer.mm:2368` | `[READ]` count=1 |
| 9 | `lensAlphaSample` — dead function, the Schwarzschild-deflection LUT sampler for the deleted lens path | `render.metal:350` | `[READ]` `grep -n "lensAlphaSample("` → 1 hit total (the definition) |
| 10 | `lensAlphaLUT` — dead `particle_vertex` parameter; the CPU still builds the 256-entry table and binds it every frame for nothing | decl `render.metal:663`; CPU build `renderer.mm:1064`; binds `renderer.mm:4371`, `renderer.mm:4513` | `[READ]` zero uses inside the 1846-line `particle_vertex` body (`render.metal:657`–`:2503`) |
| 11 | `PhysicsUniforms`/`CameraUniforms`/`PostFXUniforms` layout sanity | `renderer.h:379`/`renderer.h:347`/`renderer.h:192` | `[READ]` `PhysicsUniforms` still carries **zero** `static_assert`s either side — confirms `[[space_synth_physicsuniforms_unguarded_2026-08-27]]` is still true. `CameraUniforms` sizeof=272, `PostFXUniforms` sizeof=240, both guarded both sides — the 2026-08-22 4-byte drift is closed. |
| 12 | MIDI note-on velocity 0 → correctly treated as note-off. **Corrects the standing hypothesis** — this was NOT the stuck-voice risk. | `src/core/midi_input.mm:34-38` | `[READ]` explicit `if (vel > 0)` branch |
| 13 | MIDI parser has no running-status support — no persisted status byte across the inner loop; under running status, messages are silently dropped one byte at a time via the `else j++` fallback, not corrupted into wrong notes | `src/core/midi_input.mm:26-52`, fallback `:51` | `[READ]` grepped `lastStatus`/`runningStatus` — zero hits in the file |
| 14 | MIDI parser misclassifies System Real-Time/SysEx (0xF0–0xFF) as generic 3-byte messages — desyncs the rest of the packet. New finding, not on BRAIN's original checklist. | `src/core/midi_input.mm:28`, `:48-49` | `[READ]` `status & 0xF0` collapses 0xF0–0xFF to `0xF0`, which falls into `else if (type >= 0x80) j += 3` — wrong for 1-byte real-time (incl. Active Sensing 0xFE, commonly sent every ~300ms by hardware) and variable-length SysEx |
| 15 | MIDI velocity scaling confirmed exactly as suspected: `vel/127.0f`, no curve; built-in keyboard (`main.cpp:614`) and sequencer (`main.cpp:646`) both call `noteOn` with no velocity arg, defaulting to `1.0f` (`synth.h:40`) always | `midi_input.mm:35`, `main.cpp:614`, `main.cpp:646`, `synth.h:40` | `[READ]` all 4 sites re-grepped live |
| 16 | MIDI thread safety is NOT a naive race — `Synth::noteOn`/`noteOff` take `queueMutex_` for a bounded (≤256) push+sort; the audio RT thread only briefly re-takes the same mutex for an O(1) swap, then processes commands under a separate `mutex_` via `try_lock` so it never blocks on voice state | `synth.cpp:81-145`, `:163`, `:176` | `[READ]` traced the full command-queue path |

**Not folded into `BOARD.md` / `BOARD_BLACKHOLE.md` this session.** `BOARD_BLACKHOLE.md` was committed **2026-09-02 09:38:22** — 14 minutes before this handoff was started — by someone else in this same tree while this session was writing up. Both boards are 150–170KB, house-style-heavy, and actively owned by BRAIN's coordination with him. Hand-editing them here risked clobbering a concurrent edit on disk (this is one shared working tree, not per-session worktrees). Findings #1–8 and #12–16 were relayed to BRAIN directly via `SendMessage` as they were confirmed (see BRAIN's transcript); #9–11 are new in this document. **Whoever folds this in: re-run every grep above first — the last board re-stamp already shows drift within a single night on this project.**

## 2. 🚨 OPEN

1. **Findings #1–11 above (dead uniforms + dead lens plumbing) — no ruling yet.** Same class of cleanup as the 4 fields he already killed in `06982a0` (`sizeof(CameraUniforms)` 288→272). `PhysicsUniforms` fields (#6–8) carry the known risk: no `static_assert`s either side, so any removal must edit `renderer.h` and `particles.metal` together in one change, ideally adding the missing asserts first as its own change.
2. **`reduceCellMaxPipeline` — RULED by him 2026-09-01 14:31, relayed by BRAIN, queued behind FABLE's build.** *"2 and 3 after fable's change lands"* — (2) gate the dispatch to the reader's cadence (every 240 frames, not every substep), (3) delete the dead `bestCid` half (`renderer.mm:4142`/`:4144`, read nowhere — `bhPosX/Y/Z` are hardcoded to origin right below it). **Do not start it — not this session's to build, and not yet FABLE's turn.**
3. **Per-particle/per-pixel GPU-waste + per-frame-CPU-allocation sweep — INCOMPLETE.** Dispatched as a nested sub-fork, confirmed still running as of this handoff (checked directly, no notification received, nothing sent to BRAIN from it). Whoever picks this up next: the task brief is recoverable from this session's transcript if needed, or just re-run it fresh.
4. **Render-side dead-pass sweep never started.** The passes-hunt fork covered only the physics/SPH/PM-gravity chain in `renderer.mm` (~15 of ~30 encoded passes) and found nothing dead there. The depth prepass, offscreen pass, bloom/mip chain, lens/DOF, and UI passes (`renderer.mm:4360`–`:5430` roughly, re-grep before trusting) were never swept.
5. **MIDI findings #13–14 have no ruling on whether to fix.** Whether running-status or System Real-Time bytes actually appear on the wire depends on his hardware — this session did not and cannot determine that from source alone.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **`reduceCellMaxPipeline` rest-gate (option 1) — REJECTED by him 2026-09-01, relayed by BRAIN.** `seed_apply` in the same file had the identical `totalAmplitude < 0.02f` gate and it was reverted 2026-08-04 22:46:41 because the pass was needed during play (`renderer.mm:3540-3547`). A rest gate here would also make `[GRAV] bhPeakCount` — the instrument behind the "334,576-vs-32-cap" board finding — report a stale rest value throughout play. Use cadence-gating (option 2) instead, already ruled.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-02 09:36:01  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 06982a0
  FAIL  11 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M docs/DESIGN_BH_2026-08-31_DISRUPTION_ARCHITECTURE.md
           M docs/DESIGN_BH_2026-09-01_DISK_STATE.md
           M src/audio/synth.h
           M src/core/app_state.h
           M src/main.cpp
           M src/render/particles.metal
           M src/render/postfx.metal
           M src/render/render.metal
           M src/render/renderer.h
           M src/render/renderer.mm
           M src/render/spatial_hash.metal
  WARN  24 commit(s) not pushed

2. board vs HEAD
  FAIL  docs/BOARD_BLACKHOLE.md is 1 code commit(s) behind HEAD (verified at 3672d89)
  WARN  docs/BOARD_BLACKHOLE.md is 168817B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  WARN  docs/BOARD.md has no 'Commit at last verification: `<sha>`' line — add one
  WARN  docs/BOARD.md is 164451B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    45 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     (8 sites flagged, unchanged by this session — this session touched no plane-relevant code)
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

**The 11-uncommitted-path FAIL is not this session's.** Zero files were edited this session (pure `grep`/`Read` audit + message relays to BRAIN). Those 11 paths match what BRAIN described as FABLE's in-progress DISK-BOUND-flag work — committing them here, unreviewed, under this handoff's authorship would misattribute FABLE's mid-flight code and violate one-concern-per-commit (11 unrelated files, one bundled commit). **Left uncommitted, on purpose.** The `BOARD_BLACKHOLE.md`-behind-HEAD FAIL also predates this session (HEAD `06982a0` is his own commit from 2026-09-01 13:33, before this session started) and this session made no board edits to fix or worsen it.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| (none) | This was pure investigation — every claim above was verified by `grep`/`Read` at write time before being sent. Nothing sent to BRAIN was walked back. |

---

**Last Updated:** 2026-09-02 09:52:00
**Folded into board:** NOT this session — see §1 note. `git status --porcelain` still shows the 11 FABLE-owned paths above; this handoff file itself is the only thing this session commits.
