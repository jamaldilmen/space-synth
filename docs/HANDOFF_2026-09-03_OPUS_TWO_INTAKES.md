# SPACE SYNTH — handoff 2026-09-03 05:12:00 (OPUS window: two intakes, one meter)

> **His verdict on this state:** none — no verdict was taken on this window's work. His only orders reaching me, both relayed by BRAIN: *"yeah stamp from the real clock from now on"* (01:56:36) and the two-job activation below (*"opus will collect the report that sonnet makes"* / *"i dont want ay faders moved from this. they should just be mappable."*).
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` **§AC.12 → §AC.10 → §AC** — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `619be71`
**Build + launch:** `bash package_macos.sh` then `pkill -x SpaceSynth; open -n SpaceSynth.app --env SS_FULLSCREEN=1`
⚠️ **Do NOT trust that as current.** FABLE's 8 source commits (`9a04ab0`..`dbda8e8`) landed at ~05:12 and its handoff at `619be71`; the bundle on disk predates or postdates them depending on when its last build ran. Re-`stat` before believing any freshness claim, including this line.

⚠️ **This window wrote ZERO source code, ran no build, and launched nothing.** Everything below is source reading first done at `41e06eb` and **RE-GREPPED at `619be71`** after FABLE's 8 source commits moved `particles.metal` +69 lines below `:1461` and `renderer.mm` +38/+40 — the numbers here are the NEW ones, and the brace-depth conclusion was re-run rather than arithmetic-shifted. Measurements are FABLE's and credited to FABLE. My output was the board rows, a dossier, and four corrections.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | Whether the MDOT rate limit exempts the plunge zone | Unread; assumed to gate only disk matter | **It gates EVERY captured star, both regimes.** Verified by brace depth: regime split closes `:1586`; radius test `:1587` and MDOT `continue` `:1657` are both at the SAME depth; DISK-BOUND `:1606-1618` opens to d4 and closes. No exemption between them ⇒ a star inside `max(3·r_s,0.02)` is refused by a **viscous disk rate** whose own derivation (`:257-268`) prices angular-momentum shedding a plunging star does not need | `particles.metal:1657`, `:1587`, `:1606-1618`, `:1564-1565` | `[READ]` all sites, live callers checked |
| 2 | *"the hitbox of the megrers is way smaller than the visual"* — assumed ONE seed intake | One metered path | **There are TWO, and only one is metered.** `merge_stars`: scanner `a` < 50 (`:3837`), candidate `b` CAN be a seed (`:3871`), bound-pair gate SKIPPED (`:3910`), heavier wins (`:3942`) ⇒ direct mass write **`:3980`**. Kernel `3776-3989` grepped for `accDiag\|seedAccum\|fetch_add`: **zero hits** — no plate, no MDOT, no counter | `particles.metal:3980` | `[READ]` — FABLE's find; I tried to falsify it and could not |
| 3 | Five `[GRAV]` diagnostic fields believed live | `scan= e0m= e0id= exit=` read as data; `s0[cnt=` read as a distinct probe | **`seed_feed` is NEVER DISPATCHED** (`:4184` says so; no `seedFeedPipeline` exists). It is the only writer of `seedMeta[3]/[5]/[6]/[7]`; buffer cleared every frame (`renderer.mm:2586`) ⇒ four fields always **0**, and `s0[cnt=` **duplicates `seeds=`** | `particles.metal:4184`, `:4194-4388`; `renderer.mm:133/134/2586/3524/3612` | `[MEASURED n=4 runs, 50+ samples — FABLE]` + `[READ]` |
| 4 | Board `file:line` citations for the capture/merge area | §V4/§N4 numbers, cited by two windows | **All five drifted.** clamp `:1429`→`:1584-1585` · seedmap write `:3812`→`:4026` · capture read `:1382`→`:1531` · merge read `:1541`→`:1719` · `3·r_s` `:1489-1491`→`:1564-1565`. The file lives under `src/render/`, not under a `sim` directory | board §V4, `BH_NEAR_FIELD_AUDIT_2026-08-28.md` §N4 | `[READ at 41e06eb, re-grepped at 619be71]` |

## 2. 🚨 OPEN — his list, verbatim

1. **"STAR CAPTURE MAIN ISSUE OVER EVERYTHING ... tackle that asap"** (2026-09-02 ~16:30)
   `MEASURE:` `cap=reached/landed/refused` on `accDiag[5..7]` at the tidal test, after `reserved`, and at the silent `continue`.
   State: **still not built, still unallocated.** ⭐ **NEW this session:** the instrument for it already exists, written and complete, in the undispatched `seed_feed` — `[READ :4328-4329]` *"my cell's population, nearest candidate distance ×1000, my mass — decodes the starvation"*, plus the exit-code ladder `:4211-4229`. **Reviving it is cheaper than writing it. HIS call and BRAIN's — not proposed, not commissioned.**

2. **"i dont want ay faders moved from this. they should just be mappable."** (2026-09-03, via BRAIN)
   `MEASURE:` none — this is a design job, no code ordered.
   State: **JOB 2, activated this session, NOT STARTED.** Every UI parameter mappable; nothing in the existing UI moves, is renamed, regrouped or re-scaled. Ableton **Link** (clock/tempo) and **MIDI CC** (parameter control) are two separate problems and must be answered separately. ⚠️ Any CC design rides on `src/core/midi_input.mm`, where SONNET has an **unruled** parser fault (System Real-Time 0xF8-0xFF misclassified, over-consuming 2 bytes each). Coordinate with SONNET; **do not duplicate and do not apply its fix.**

3. **"opus will collect the report that sonnet makes and deliver it to you"** (2026-09-03, via BRAIN)
   `MEASURE:` hold every incoming report to the tag bar — `[MEASURED n≥3]` / `[READ file:line]` with live callers / `[HYPOTHESIS]`.
   State: **JOB 1, activated this session, NOT STARTED.** SONNET's imgui loose-ends hunt, its time-derived-from-fps sweep, and two subagent reports on offline rendering. Deliver conclusions and contradictions to BRAIN, not four raw dumps.

4. **The merger stand-off's ≥50 M☉ holder** — **UNIDENTIFIED, 9 candidates eliminated.**
   State: he said **NO GO** on the force-decomposition probe (relayed by BRAIN; that probe is not from this window's context, recorded as relayed). Open, unowned.

5. **The `:1590-1595` vs `:1657` contradiction** — UNRULED.
   `MEASURE:` none needed; it is a control-flow fact.
   State: `[READ]` The DISK-BOUND block states it *"deliberately does NOT exempt"* the plunge zone; `:1657` then overrides the plunge zone anyway. **Both are shipped.** This is the sharpest form of the disk-vs-plunge question and it depends on no run. His call.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **"The `1.4·cellSize` clamp exists at two sites, delete both" — REJECTED 2026-09-03 05:04:00, MINE.** `:4282-4283` is inside `seed_feed`, which nothing dispatches. Deleting it changes nothing, and rule 1 would then have sent whoever did it hunting a stale binary. **Only `:1584-1585` is live.** Found by grep without checking dispatch — **a code site is not a mechanism if nothing dispatches it**, the same trap as "a comment is not a mechanism", new surface.
- **"`feed=` is a clean null" and "`feed=` can only ever read cleared" — BOTH REJECTED 2026-09-03 02:00:00.** Mine was too strong (`seed_apply` is `device const` and never clears, so a *synchronised* read would see the last substep's deposits); BRAIN's was too strong the other way. The correct record is FABLE's: the CPU `.contents` read is **not synchronised** against GPU completion and samples one substep in four every 240 frames ⇒ **"undetermined by read, sub-sampled"**. Consequence: do not board it as a dead instrument, or nobody reads the plate again.
- **"`pEat += oP` fed the seed" — REJECTED 2026-09-03 01:53:00 (FABLE's, withdrawn on my read).** `oP` is words [2][3][4] = **momentum**, consumed only by `vNew`. Mass is `m + gain`, `gain` = word [0] + dead slots' word [0] — both the metered plate. The sink path does **not** bypass MDOT.
- **"Growth exceeded the summed plate ceiling ⇒ a third path exists" — WITHDRAWN 2026-09-03 02:00:07, MINE.** The ceiling I compared against understated the file's own documented bound: `[READ :1635-1636]` *"Residual overshoot is at most ONE victim (≤50 M☉)"*, and both channels draw victims from a distribution whose mean is 0.30 M☉ but whose tail runs to 50. FABLE's 1.06–2.56 M☉/substep sits far inside it. **Two-channel accounting remains NOT CLOSED** — victim-mass distribution untested, third path not excluded, just no longer indicated.
- **"`cellSeedMap` collision is dead post-fix" — WITHDRAWN 2026-09-03 02:02:00, MINE.** I demoted it on FABLE's `seeds = 9/1/1` latched runs; the plateau sustains **seeds 8–15**, which is the regime where it can act. It is a **LIVE CANDIDATE, untested**. Its precondition (≥2 seeds in one 1.0-sim cell) is unanswerable from existing logs. It suppresses `reached`, never `refused` — so `mrg=31/31/0` is consistent with it and does not discriminate it.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-03 05:06:44  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 41e06eb
  FAIL  6 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M imgui.ini
           M src/render/particles.metal
           M src/render/postfx.metal
           M src/render/render.metal
           M src/render/renderer.h
           M src/render/renderer.mm
  ok    pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 9f61c66 — 10 docs-only commit(s) since, no source change
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

**Disposition, 2026-09-03 05:12:00:**
- **§1 six uncommitted paths — NOT MINE, and I am ordered not to touch them.** All six are FABLE's in-flight work; the app was live (PID 31353, started 04:55:07) building from them at preflight time. BRAIN relayed his order at 05:09: *"FABLE commits the WORK tree source first — do not run git there until I say it is clear."* I wrote no source this session.
- **§1 `imgui.ini`** — rewritten live by the running app. Reverted at commit time by whoever commits, **not before**; the app was running at 05:06:44.
- **§2 board at `9f61c66`, 10 docs-only commits since** — correct and left alone. **The stamp is NOT re-stamped to HEAD**: this session changed no source, so claiming a verification at HEAD would be a lie. Same call as this window made on 2026-09-03 00:28:05, and BRAIN agreed then.
- **§2 WARNs (board size ×2, missing stamp on `BOARD.md`)** — pre-existing, not this session's. Splitting a 217 KB board two days before Cologne is not a change to make unasked.
- **§3 both artifacts `ok`** — but the FAIL will return the moment FABLE's six paths land. Re-`stat`, do not quote this.
- **§5 plane sites ×8** — all in `render.metal`/`postfx.metal`, FABLE's files. I edited no source at all.

✅ **RESOLVED — THIS HANDOFF ENDS WITH `git status` EMPTY.** The §1 FAIL above was a fact about 05:06:44 and did not survive the hour. Sequencing was his, relayed by BRAIN at 05:09: *"FABLE commits the WORK tree source first — do not run git there until I say it is clear."* FABLE landed 8 source commits (`9a04ab0`..`dbda8e8`) plus its own handoff (`619be71`), staging only its own paths and leaving my board hunk untouched; BRAIN then cleared the tree for me at 05:12. **I committed my two paths myself, as two commits, one concern each** — the board row, then this file — and BRAIN appends §AD and the re-stamp as a separate commit after mine, so that we never both hold `BOARD_BLACKHOLE.md` at once. **Nothing pushed** — no push order was given. ⭐ Each window committed its own work; nobody swept another's into their commit to make a check go green.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The `1.4·cellSize` clamp exists at TWO sites — delete both or you get a half-change that looks like it did nothing" (sent to FABLE **and** to BRAIN as "a NEW fact nothing has recorded") | `:4282-4283` is inside `seed_feed`, which `:4184` states is **NOT dispatched** and for which no pipeline exists. Found by grep without checking dispatch. Corrected to both windows within the hour; FABLE confirmed it had not acted on it. |
| "`feed=0/0.0` is a REAL READING, not an artifact" | Too strong. `seed_apply` genuinely never clears the plate, but the CPU `.contents` read is **unsynchronised** against GPU completion, so the value is racy. Correct record is **"undetermined by read, sub-sampled"**. |
| "FABLE's 1.06–2.56 M☉/substep exceeds the summed ceiling ⇒ possible third path" | The ceiling I used omitted the file's own documented ≤50 M☉ overshoot bound (`:1566-1567`). Withdrawn as a third-path signal; the accounting stays open for other reasons. |
| "The `cellSeedMap` collision is not the nucleus blocker post-fix" | Demoted on `seeds = 9/1/1` runs that were `hole=1.00` **latched** — the wrong regime. In the plateau (`seeds 8–15`) it can act. Reinstated as a LIVE CANDIDATE, untested. |
| "The dead `s0[cnt=` probe would answer the `cellSeedMap` precondition" (implied to FABLE) | It stores `cellCounts[myCell]` (`:4332`) — the **particle** population of a seed's cell, per its own comment *"decodes the starvation"*. That is star-capture starvation, **not** how many *seeds* share a cell. Two separate unanswered questions; corrected before it became load-bearing. |

---

**Last Updated:** 2026-09-03 05:12:00
**Folded into board:** `docs/BOARD_BLACKHOLE.md` **§AC.12** @ 2026-09-03 05:10:00 (stamp deliberately left at `9f61c66` — no source changed by this window)
