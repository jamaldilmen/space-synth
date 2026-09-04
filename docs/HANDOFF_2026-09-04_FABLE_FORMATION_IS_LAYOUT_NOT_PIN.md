# SPACE SYNTH TRUE-PHYSICS — handoff 2026-09-04 15:24:55 (FABLE)

> **His verdict on this state:** "not seen yet" — he woke, saw the stills, ordered the 3-minute venue capture and the show bible; the inversion result (§AG) has reached him only as BRAIN's headline.
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` §AG, then §AF (pile mechanics) — NOT this file, NOT older handoffs. Show work cold-starts from `docs/SPACE_SYNTH_LIVE.md`.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `5eae334`
**Build + launch:** `bash package_macos.sh` then unpinned `open -n "$PWD/SpaceSynth.app" --stdout <log> --stderr <log> --env SS_FULLSCREEN=1` · pinned `… --env SS_FULLSCREEN=1 --env SS_WIDTH=19644 --env SS_HEIGHT=1680`. Six-run tally script (guards on bundle stamp + no running app): scratchpad only, not in the repo; its logic is three lines of `open`/`sleep 92`/`pkill -x SpaceSynth` per run.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | §AF.1 "the pinned path NEVER forms the hole at launch" | pin path = the cause, by elimination `[HYPOTHESIS]` | formation is a deterministic function of render path × BINARY: clean `85b4aa3` PINNED 0/17 vs UNPINNED 16/16 (live clock, same spawn); one extra 704-byte diagnostic buffer INVERTS it to PINNED 3/3 (sample 1) vs UNPINNED 0/3. The pin is one of two layouts, not the cause. | `docs/BOARD_BLACKHOLE.md` §AG.1; tallies `logs/2026-09-04_043405_six_run_tally.txt`, `…_050019_…_s6arm.txt`, `…_051245_…_diagarm.txt` | `[MEASURED n=3 per cell, 4 bundles, every run Compute avg 0.00 = 0 windows]` |
| 2 | §AF.5 road (1): "is the merge kernel where the paths diverge?" | untested | NO. Inside `merge_stars` both paths read dt 0.01650 / gravGM 1.9653 / massTotal 189044 / n 2M; refused-pair rcAB and vesc² distributions identical; 98–99% of found pairs die on partner-already-claimed on both paths. Same kernel + same field ⇒ same behaviour. | `src/render/particles.metal` merge_stars (kernel at :3776 at HEAD); instrument `docs/patches/fable_merge_diag_2026-09-04.patch` | `[MEASURED n=2 pairs + 6 runs, TEMP-DIAG counters, reverted]` |
| 3 | "Uninitialised / out-of-bounds memory is the mechanism class" | leading candidate after the inversion | DEAD. Static audit at `85b4aa3`: every small-buffer index in bounds, every kernel buffer bound (compute_physics 0–20, count_cells 0–6, merge_stars 0–6), PhysicsUniforms `= {}` per step + `static_assert 172`, Metal `newBufferWithLength` zero-fills (Apple doc, fetched). Never-written seedMeta[3,5,6,7] feed the host log only. | `src/render/renderer.mm:23`, `:1714`, `:3661–3689`; `spatial_hash.metal:120`; `particles.metal:4013`, `:4523` | `[READ file:line — every symbol has live callers; seed_feed has none, stated]` |
| 4 | "Stars at the speed cap in the first seconds on the pinned path" (my 02:58 claim) | reported to BRAIN as a discriminator | RETRACTED 03:04 — probe is 1/s; cap star at ~5 s on BOTH paths; 1-s dumps identical (r50 11.692, mean step 0.00655, max 0.010/0.027 vs cap 0.058). | §AG.4 | `[MEASURED 2 dumps + 4 logs]` |

## 2. 🚨 OPEN — his list, verbatim

1. **"for fable to keep on figuring out why he lense doesnt show up in the room aspect ration"** (his words ~02:3x, relayed by BRAIN 02:41:41)
   `MEASURE:` the Tier-A discriminator — a TEMP-DIAG that logs merge_stars (winner, loser) id pairs for frames 1–60 on both paths, clean bundle, same spawn; two 30 s runs. Differing SETS on the identical 1-s fields ⇒ thread-arrival-order confirmed. **Prediction on record: the runtime uniform hexdump will read IDENTICAL on both paths — it is no longer the discriminating instrument.**
   State: the mechanism CLASS is identified `[READ + MEASURED]` — the only configuration-dependent inputs to physics are thread-ARRIVAL-ORDER atomics: merge claim CAS `particles.metal:3931/:3935`, seed-budget CAS `:1650/:1791`, registry slot order `spatial_hash.metal:119`. That a different first winner is what flips formation is `[HYPOTHESIS]` until the pair-set log runs. Fix class if confirmed = make the two CAS sites order-independent (deterministic tie-break) — DESIGN, his call. Not built.
2. **"press play … watch it render. I need a real time preview"** (2026-09-03, on the board §AA15) — S6 shipped by SONNET today (`14757d5`, `ff1fdc0`); not mine; see BRAIN's/SONNET's handoffs and §AA26.
3. **Show blocker, restated:** on the CLEAN binary the pinned render path never forms the hole at launch (0/17). Under the offline CAPTURE clock (OPUS, dt 1/60, 2 steps/frame) pinned formed 2/2 — a third condition, never pooled. Whether the delivered renders form is therefore a per-configuration fact to be MEASURED on the delivery bundle, not assumed from either arm.
4. **Unpinned formation time shifted 5 s → 2 s in 2 of 3 launches on the S6 bundle** (`[MEASURED n=3 vs n=3]`, own row, unstrengthened — the diag arm's unpinned never formed and cannot speak to it). The S6 CC consumers never executed in a silent run ⇒ presence, not behaviour.
5. **Counter survival** — recommendation on record: the 3-slot `smrg` counter (3 relaxed atomics per contact pair) stays; the board never had a star-star merge rate. His decision.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **"The pin CODE PATH is the cause, by elimination" (§AF.3) — REJECTED 2026-09-04 05:24.** Inverted by a change with no physics content (704 bytes in `accDiagBuffer` + one buffer binding on merge_stars). The pin is a layout, one of two.
- **"The merge gate refuses because pinned pairs are found at larger separation" (denominator) — REJECTED 03:08.** rcAB and vesc² distributions identical on both paths over refused pairs.
- **"dt / uniform mirror differs GPU-side" — REJECTED 03:08.** Echoed inside the kernel: identical on every sample.
- **"S6 control code moved the lottery" — REJECTED 05:11.** 85b4aa3 + S6: PINNED 0/3, UNPINNED 3/3, same as clean.
- **"Formation is a lottery whose odds the pin shifts" (BRAIN 03:12) — REJECTED 04:45.** Deterministic per (path × binary) at n=3 in every arm.
- **Uninitialised / OOB memory as the class — REJECTED 12:01** (static audit, §AG.5).
- **`logs/2026-09-04_0220_venue.log` as 17-minute corroboration — STRUCK 03:07 (BRAIN).** A paused sim: `Compute avg 0.00` in 350/352 PROFILE windows.
- **`[PROBE-1000] live` as a population number — DO NOT USE.** 1000-slot tracer; read −97.4% where `[GRAV] live` read −72%. Name the tag on every population number.
- **Frame rate / sim-time-per-wall-second — REJECTED 04:45.** Median fps 10 vs 12 on identical 86-sample runs, opposite outcomes.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-04 15:22:06  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 65d6317
  FAIL  2 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
          ?? docs/HANDOFF_2026-09-04_SONNET_CC_RIDE_AND_CAMERA_FIX.md
          ?? docs/patches/
  WARN  75 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 0efe13d — 1 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 268659B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 104965B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 0efe13d — 1 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 197412B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  FAIL  docs/BOARD_BLACKHOLE.md references missing path: docs/HANDOFF_2026-09-04_FABLE_FORMATION_IS_LAYOUT_NOT_PIN.md

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:577:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:765:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1146:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1466:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1469:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2585:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/render.metal:3329:                mp = rotAboutAxis(mp, float3(0.0f, 0.0f, 1.0f),
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```
(Run at 15:22:06 after the board restamp, before this file and `docs/patches/` were committed. The "missing path" FAIL is this file, which did not yet exist; the untracked SONNET handoff has since been committed by SONNET as `9cbd993`.)

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "Stars at the speed cap in the first seconds on the PINNED path" (02:58) | I read a 1/s probe as 10/s. The cap star appears at ~5 s on BOTH paths; 1-s dumps of both fields are the same spawn. |
| "The pinned FIELD is faster/hotter" (02:58, as a pin signature) | Mean displacement per step is identical (0.00655). What is real is a HEAT gap that tracks seedless-vs-seeded state, and one seedless pinned run 30× hotter than a seedless unpinned run — a field-state observation, not a pin signature. |
| "The 03:0x flip was the S6 edit or a lottery" (05:11, offered as two readings) | It was the DIAG bundle's deterministic behaviour: 85b4aa3 + diag alone gives PINNED 3/3 / UNPINNED 0/3. |
| Header time "12:09" on my audit message; "the ONLY source commit since 85b4aa3 is ff1fdc0" in the 15:22 board restamp | Typed, not read: clock was 12:01. Two source commits existed (`14757d5`, `ff1fdc0`); corrected in `7ff0e9f`. |
| "nReg 1 vs 9–10 is a second observable" (BRAIN's elevation, which I let stand for one message) | nReg tracks formation time inside the S6 arm itself; the observable is formation TIME (5→2 s), one row, own n. |

---

**Last Updated:** 2026-09-04 15:24:55
**Folded into board:** `docs/BOARD_BLACKHOLE.md` §AG @ 2026-09-04 15:19:48 (commit `0efe13d`), restamped `65d6317`, header corrected `7ff0e9f`; `docs/BOARD.md` §AA25 pointer @ 15:19:48.
