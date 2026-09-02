# SPACE SYNTH — handoff 2026-09-03 00:30:09

> **His verdict on this state:** not seen yet — read-only session, no ruling requested or given.
> **Cold start:** read `docs/BOARD.md` — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `9a62447`
**Also verified against:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-LOST-IN-SPACE` branch `lost-in-space` @ `c912147` (the new show tree) — `midi_input.mm` is byte-identical in both, so every claim below covers what ships Cologne.
**Build + launch:** not run this session — read-only constraint (BRAIN's order: no builds, no launches, fix ships on his order only; FABLE holds the build token with a soak running elsewhere).

---

## 1. ✅ CLOSED THIS SESSION

None. This was a read-only re-verification, not a fix — nothing was applied, built, or shipped.

## 2. 🚨 OPEN — routed by BRAIN, not yet his own words

1. **MIDI System Real-Time parser bug — routed by BRAIN 2026-09-02 ~15:2x, restated by him to Jamal via CoreMIDI: *"lense lowkey explodes..."* is an unrelated BH item; no direct quote from Jamal exists on THIS item yet.** Original board framing (`docs/BOARD.md` UNFOLDED banner, 2026-09-02 09:55:00): *"his rig is Ableton-synced, 24 clock bytes/quarter-note."*
   `MEASURE:` none possible from source alone — whether this actually fires on his rig depends on whether his specific MIDI interface/driver coalesces Real-Time bytes into the same `MIDIPacket` as note/CC data. Cannot be settled without either (a) his eyes/ears at a real soundcheck with the fix built, or (b) a CoreMIDI packet-boundary logging build (not built, would need his order).
   State: `[READ src/core/midi_input.mm:26-53, both trees, re-read 2026-09-03]` — the misparse is REAL in current source: `type = status & 0xF0` (`:28`) collapses 0xF0–0xFF to `0xF0`, landing in the `type >= 0x80 → j += 3` branch (`:48-49`). Every 1-byte System Real-Time message (`0xF8` Clock, `0xFA-FC` Start/Continue/Stop, `0xFE` Active Sensing, `0xFF` Reset) is misread as 3 bytes and eats the next two bytes of the same packet. Damage is scoped per-`MIDIPacket` (loop resets `j` at `:26`), so it fires only when the driver coalesces a Real-Time byte with channel bytes in one packet — common under continuous clock, not deterministic per byte. `[READ, grepped both trees]` no `lastStatus`/running-status state exists anywhere in the file, so "does a Real-Time byte clear running status" does not apply yet — that hazard is dormant until running status itself gets built (separate, larger gap: causes dropped messages under continuous CC/pitch-bend, not corruption). **What is NOT known:** whether it has actually fired audibly/visibly on his hardware this rehearsal cycle — `[HYPOTHESIS]` only, per the 09-01 memory note, unchanged.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

None this session — no approach was tried and rejected, this was verification only.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-03 00:30:09  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 9a62447
  FAIL  4 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M docs/BOARD.md
           M docs/BOARD_BLACKHOLE.md
          ?? docs/HANDOFF_2026-09-03_LENS_REGION_UNBOUNDED.md
          ?? docs/HANDOFF_2026-09-03_OPUS_VERIFY_AND_HOLD.md
  ok    pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 9f61c66 — 3 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 217255B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  WARN  docs/BOARD.md has no 'Commit at last verification: `<sha>`' line — add one
  WARN  docs/BOARD.md is 166995B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    46 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:576:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:763:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1144:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1464:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1467:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2558:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/render.metal:3284:                mp = rotAboutAxis(mp, float3(0.0f, 0.0f, 1.0f),
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

⚠️ **The `FAIL` above is NOT this session's.** `docs/BOARD_BLACKHOLE.md` and the two `HANDOFF_2026-09-03_*` docs are a live concurrent session's (BRAIN/OPUS, black-hole influence-region work) in-progress, uncommitted edit — caught mid-write during this session (a diff appeared on `BOARD_BLACKHOLE.md` between two consecutive `git status` calls seconds apart). Per "one concern per commit," I am not bundling someone else's unfinished edit into my commit. **This session commits only `docs/BOARD.md` (the MIDI fold) and this handoff file** — see commit below. The tree will NOT show fully clean after this commit; the remainder is BRAIN/OPUS's concern to commit.

§5 orbital-plane WARN is boilerplate, unrelated to this session — no orbital/rotational code was touched.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| | |

None. The 2026-09-01 finding held up under re-read; this session only added precision (per-packet scoping, running-status dormancy) on top of it, not a correction.

---

**Last Updated:** 2026-09-03 00:30:09
**Folded into board:** `docs/BOARD.md` @ 2026-09-03 00:29:32
