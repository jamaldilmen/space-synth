# SPACE SYNTH — handoff 2026-09-03 05:23:07

> **His verdict on this state:** not seen — he ordered this update then clears context; no ruling on the findings below yet.
> **Cold start:** read `docs/BOARD.md` (§AD.13-16 carries the detail below) — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `41e06eb` at session start, now ahead 17 of origin (FABLE's commits, not pushed — not this window's push to make)
**Build + launch:** not run this session — held idle throughout, no build/launch token. All work below is read-only research + two research subagents; nothing built, nothing edited in source.

---

## 1. ✅ CLOSED THIS SESSION

None (no fix landed — this was hunting + research, not a fix session).

## 2. 🚨 OPEN — his orders via BRAIN, findings below

1. **MIDI System Real-Time parser bug — STILL UNRULED, TOP STAGE RISK, now also a stated dependency of OPUS's Ableton CC design.** `src/core/midi_input.mm:26-53`: `type = status & 0xF0` collapses 0xF8-0xFF into the `>=0x80` branch, over-consuming 2 bytes per Real-Time byte. Fix PROPOSED, NOT applied. Cologne is 2026-09-05 — 2 days out.
   `MEASURE:` unchanged — needs his eyes/ears at a real soundcheck or a CoreMIDI packet-boundary logging build, neither built.
   State: do not touch `src/core/midi_input.mm` without his ruling or explicit allocation through BRAIN.

2. **ImGui loose-ends hunt (his order, "such as wave lenght") — DONE.** `[READ, verified myself, both my own re-checks and BRAIN's correction below]`:
   - "Wave Depth" (his named example) is WIRED correctly: `main.cpp:2022` → `renderer.mm:1850` `physicsUniforms.maxWaveDepth` → `particles.metal:51`, a live GPU uniform. A stale, unrelated comment next to a disabled `DYNAMICS` header (`main.cpp:1998`, "wave depth dead") is the false-flag source — recommend deleting that comment.
   - `config.rotationY`/`rotationZ` (`main.cpp:967-968` → `renderer.h:65-66`) are DEAD: fed from `uiRotationY`/`uiRotationZ` (`app_state.h:26-27`), which default `0.0f` and have no widget or any other producer anywhere in `src/` — confirmed by grep, zero other references.
   - **RETRACTED, see §5:** my first pass also called `rotationX` "live." It is not UI-driven either — see the correction below.
   - `struct Preset` (`preset_manager.h`) captures only 15 fields; 60+ live dials are absent and silently dropped on save (Kelvin, star size, smear, ISCO, SPH cooling, mirror mode, and more) — same known gap, wider scope than previously catalogued.
   - Toggle bitmask bit 19 (of `uiTogXxx`, bits 0-20) is unused/reserved — no code reads it. A gap, not a live bug.

3. **FPS-vs-seconds sweep (his order) — DONE, and BRAIN's "two fresh sightings" relay is RETRACTED by BRAIN as of this session.** Both handed-to-me sightings are the CURE, not an instance of the bug: `renderer.mm:1690-1734` pins `dt=0.0165f*timeWarpVal` deliberately (2026-06-30 energy-conservation fix) while the wall-clock step accumulator (`renderer.mm:1787-1814`ish, debt clamp 4) measures real elapsed time and decides step COUNT — this is the 2026-08-30 TRUE TIME fix, exactly the cure for "a frame is not a unit of time." Verified by my own direct read, not just the sub-agent's. No new FPS-derived-time sites found anywhere else in `src/audio`, `src/core`, or the physics kernel.
   ⭐ **Distinction OPUS drew, keep both — they are about different code:** §AC.11's `1/dt²` region-scaling is in the LENS INFLUENCE LAW's units and is still TRUE; it is not the same claim as the retracted "fresh sighting," and a future window should not discard it by association.

4. **Offline-rendering research (his order, task 3) — DONE, two subagents, external research, UNTESTED against this tree.** Conclusions only:
   - Determinism/capture angle: the existing fixed-dt debt-accumulator is already offline-friendly (Gaffer "Fix Your Timestep" shape) — swap the wall clock for a virtual clock, uncap the substep clamp so debt is never skipped, decouple output-frame cadence from the 60.6Hz substep rate. Motion blur via true substep-position accumulation (not screen-space blur). Capture via AVAssetWriter + ProRes 4444 on an IOSurface-backed pixel pool, zero-copy into Metal. No separate frame-server needed.
   - Record/replay workflow angle: log MIDI + audio features (not raw audio) tagged by physics tick index, replay through the live app at real-time speed via the existing input paths — buys "redo a take" without touching the physics clock. Live/pre-rendered switching belongs downstream in the existing Syphon-receiving VJ mixer, not in-app. MVP for 2 days out: MIDI+feature logger, real-time replay, downstream crossfade — buildable. Explicitly NOT for before Cologne: the non-realtime decoupled-clock render mode (depends on the other angle's clock work), Alembic/VDB export, in-app crossfade, sim-checkpoint caching.
   - The two converge: a safe two-day MVP (record + real-time replay + downstream mix) vs. a fuller quality pipeline (clock decoupling + temporal supersampling + ProRes capture) that should wait until after Cologne.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

None this session — no approach was tried and rejected (research + hunt only).

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-03 05:23:46  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 0a978c1
  FAIL  1 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M docs/HANDOFF_2026-09-03_SONNET_HOLD.md
  WARN  18 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at dbda8e8 — 9 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 244831B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  WARN  docs/BOARD.md has no 'Commit at last verification: `<sha>`' line — add one
  WARN  docs/BOARD.md is 166995B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    46 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:577:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:765:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1146:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1466:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1469:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2571:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/render.metal:3315:                mp = rotAboutAxis(mp, float3(0.0f, 0.0f, 1.0f),
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

⚠️ The one `FAIL` above IS this session's (this handoff amendment itself) — resolved by the commit below. The "18 not pushed" is FABLE's/the team's prior commits (this window pushed none, was told not to) — not this session's concern to fix.

§5 orbital-plane WARN is boilerplate, unrelated to this session — no orbital/rotational code was touched or read.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "Only `rotationX` is live (fed by a real slider + BH rotation + two auto-rotate toggles at `main.cpp:963-966`)" | **Wrong on both halves.** There is no rotation widget anywhere in the UI, and `uiAutoRotateBlackHole`/`uiAutoRotateScene`/`uiRotationX`/`uiBlackHoleRotationX` have no widgets either — I inferred liveness from an elaborate producer expression (`main.cpp:963-966`) instead of tracing back to an actual `ImGui::`/`UiSlider`/`UiCheckbox` call. `grep` confirms zero widget references to any of the four names, anywhere in `src/`. Correction is BRAIN's catch, verified by me independently before writing this row — the same trap took OPUS twice tonight and BRAIN once; boarded as §AD.16, a policy gap (check: grep for a READ, i.e. confirm a widget call exists, don't infer from a consumer expression), not an individual lapse. Net effect on the original finding: `rotationX` is not dead in the sense of "always zero" — `uiAutoRotateBlackHole` defaults hardcoded `true` in `app_state.h:114` with no way to toggle it off, so the BH auto-rotates unconditionally at a fixed rate with zero exposed control, which is arguably the more useful finding than "the slider is live." |

---

**Last Updated:** 2026-09-03 05:23:07
**Folded into board:** `docs/BOARD.md` / `docs/BOARD_BLACKHOLE.md` §AD.13-16 (BRAIN's fold, not this window's — this handoff is the source record, board is the reference of truth).
