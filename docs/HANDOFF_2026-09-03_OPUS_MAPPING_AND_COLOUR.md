# SPACE SYNTH — handoff 2026-09-03 15:28:57 (OPUS: the UI was already mappable · Chladni colour is path length)

> **His verdict on this state:** none on this session's work. His inputs were three rulings and one colour verdict, all relayed by BRAIN, all quoted verbatim in §2.
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` **§AD → §AC.12** — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `1496dc4`
**Build + launch:** `bash package_macos.sh` then `pkill -x SpaceSynth; open -n SpaceSynth.app --env SS_FULLSCREEN=1`
⚠️ **This window wrote ZERO source, ran NO build and launched NOTHING.** The build token was FABLE's all session. Everything below is source reading plus two standalone CoreMIDI probes that ran in the scratchpad, never in the app.
⚠️ **`main.cpp` line numbers moved +11 mid-session** (FABLE's `SS_PHASE_AMOUNT` hook at `:386-396`). Every `main.cpp` number here was re-read at 15:26:45 and lands. **Re-grep, never re-derive.**

---

## 0. 🔄 UPDATE 2026-09-03 18:36:04 — WRITTEN BY BRAIN, NOT BY THIS WINDOW

**This window has been idle since 15:28:57.** §1–§5 below are still true *as of that stamp* and were not re-verified. What follows is what moved underneath them, verified by BRAIN against the tree at `52f6d68` (clean, 43 unpushed) unless a line says otherwise.

**⭐ THE HEADLINE: your design left the page. FABLE is BUILDING it.** His order ~16:00, via BRAIN: *"The midi cc must work so well that i can compose rides and fades accurately … This is the most important build of the project."* `[HIS WORDS]`. Seven commits landed 17:40–18:32 — `d4cf127` `7ff7158` `5fd6cbb` `7d2e0d8` `3e4ac40` `d6cbb7c` `52f6d68`. Cold start for the whole build: memory `space_synth_show_renderer_2026-09-03`.

### What CLOSED under you

| # | Row in this file | Now | Where | Proof |
|---|---|---|---|---|
| A | **§10.0 "PREREQUISITE ZERO: `MidiCallback` cannot represent a CC, capture is blocked BY CONSTRUCTION"** | **CLOSED.** The callback is now one POD event — `enum MidiKind{NoteOn,NoteOff,CC}` and `MidiEvent{kind,channel,a,b,stamped,t}`, `t` in seconds on the `CACurrentMediaTime` timebase. Your §10.0a/b/c are cited in the header comments verbatim | `src/core/midi_input.h:11-26` @ `d4cf127` | `[READ]` by BRAIN 18:31 |
| B | **§2.4 — the System Common (MTC) residual, the row BRAIN put on HOLD** | **CLOSED, and the HOLD is superseded — do not re-open it.** Sizes are now the spec's table: `0xF2`→3, `0xF1`/`0xF3`→2, everything else in System Common →1, SysEx scans to `0xF7`, `>=0xF8` still 1 (the `9fbe0ba` guarantee, unchanged) | `src/core/midi_input.mm:59-64` @ `d4cf127` | `[READ]` by BRAIN 18:31 |
| C | His **record-then-render** ruling had no recorder | **SHIPPED.** `SS_RECORD=<path>` logs every note+CC with the packet's own stamp; marker **CC 119** (`SS_TAKE_MARKER_CC` overrides) is t0; a take with no marker **fails loudly**, drops are counted | `src/core/take_recorder.{h,cpp}` @ `7ff7158` | `[MEASURED n=2 live takes]` FABLE, relayed |

### What is STILL YOURS, unbuilt

- **S6 — the CC→parameter registry, straight out of `docs/DESIGN_2026-09-03_MIDI_MAP_AND_LINK.md`.** Not started. FABLE's stated order is S8 capture → **S6** → S7 slew.
- ⛔ **Your own dead road still governs it:** register in the `Ui*` helper, **apply in the frame loop OUTSIDE `if (showHUD)`** — see §3. Add to it: the mapper must **refuse to map the marker CC** (119), or a take re-drives its own marker on replay.
- **S7 slew** — and note it now has a clock to live on: offline, one physics step is `1/60` sim seconds and the frame is exactly `1/fps`. Slew written per-frame is deterministic; slew written per-wall-second is not.
- ❓ **Your queued question is STILL UNANSWERED** — does a startup UI pass with headers forced open count as "moving something"? S6 hits it the moment it is written. It was not put to him tonight.

### ⚠️ Before you cite anything in this file

`main.cpp`, `renderer.mm`, `window.mm` and `window.h` all took source between 17:40 and 18:32 (S3 gates, S4 replay hook, S5 pin). **Every `main.cpp:` and `renderer.mm:` line number in §1, §3 and §5 below predates that and was last re-read at 15:26:45.** Re-grep against `52f6d68`; never renumber by arithmetic ([[feedback_file_line_is_only_true_against_a_tree_state]]).

### One retraction of FABLE's that you must not inherit

**"a replayed event is never early, at most one frame late"** was published to this team at 18:13 and is **WRONG for `floor(t·fps)`** — measured, the replay *led* the live take by 11–31 ms on every envelope transition, and video leading audio is the direction the eye catches. Fixed to `ceil(t·fps)` in `d6cbb7c`. The claim allowed today: **each event lands 0–33 ms AFTER its recorded time, never before, deterministic to the frame** — on a synthetic take. Ableton's own stamping is **unmeasured** until his first real take.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | *"every parameter in the UI mappable, no fader moved"* believed to need a new UI subsystem | Unscoped; no design existed | **The constraint is already satisfied by shipped code.** `UiSliderFloat`/`UiSliderInt` are drop-in wrappers added for double-click-to-type, and already receive `label`/`v`/`v_min`/`v_max`/`flags` — the exact tuple a mapping needs. **61 call sites route through them ⇒ mapping goes inside two function bodies, zero call-site edits, no fader moved** | `main.cpp:37`, `:56`, `:31-36` | `[READ]` + grep-counted call sites (consumers, not a definition) |
| 2 | Whether the System Real-Time parser fault actually fires | `[HYPOTHESIS]` — "cannot be determined from source alone" (09-01 + 09-03 00:29 notes) | **It fires, and it EATS NOTE-ONs — a live bug in shipped behaviour, not just a CC blocker.** CoreMIDI **coalesces** two same-timestamp `MIDIPacketListAdd` calls into ONE packet (what a DAW emits), and the old parser then destroyed the following note. That reframing is what got the fix authorized | `midi_input.mm:26-53`, `main.cpp:212-222` | `[MEASURED n=3, 3/3]` IAC Driver Bus 1 + byte-exact parser replica |
| 3 | Whether SONNET's guard actually closes it | Unvalidated relay | **Closed for the ruled configuration.** Guard read from `git diff`, build confirmed not stale (binary 05:53:27 > source 05:50:18), then the exact failing vectors re-run: `[F8][note]`, `[FE][note]`, `[FA][note]`, `[FF][note]` all → `noteOn(60)`; `[F8][note][note]` → **both** | committed `9fbe0ba` | `[MEASURED n=3, 3/3]` 7/7 RT vectors |
| 4 | *"No chladni weird different Color profile clearly"* — cause unknown, one candidate | Candidate: "per-particle phase varies in play" (FABLE's) | **Right SITE, wrong REASON. `phase` is NOT an oscillation phase — it is WRAPPED CUMULATIVE PATH LENGTH** (`+= speed*dt`). The tint rotates hue by **distance travelled**, so it is a **SPEED** gate acting on both populations in the SAME frame — which is why field and Chladni differ while sharing one code path | `particles.metal:3566-3567`; tint `render.metal:2322-2336` | `[READ]`, tint verified **UNBRANCHED BY BRACE DEPTH** from `render.metal:658` (tint depth 1; both colour writers depth 3) |
| 5 | Why the difference is visible at all | — | **Explicit speed-cap regime split, ratio 20.69×, WARP-INDEPENDENT** (both sides ×dt). Rest ≤0.058 rad/frame (full hue wheel ≈108 frames); Chladni ≤1.20 rad/frame (**full wheel in 5.2 frames**). Magnitude: max rotation **0.175 wheel = 63°** | `particles.metal:3404`, `:368`, `:321`; `renderer.mm:1857`; `units.h:58`; `render.metal:2334` | `[READ]` all sites; consumer chain `main.cpp:2359-2360` → `renderer.mm:2027` → shader verified live |
| 6 | The colour LAW suspected as the differentiator | Open suspicion on bit16 | **KILLED before proposing anything else.** `spectrumToBands` runs at `render.metal:1685` (play) **and** `:1918` (star-map) — same function, same LUT, same bit16. **It cannot produce a play-vs-field difference** | `render.metal:1685`, `:1918`, `app_state.h:62` | `[READ]` both sites |
| 7 | The mappable surface | "62 params, one bypass" | **63 continuous widgets / 64 mappable values**, and **three target kinds**: **57** stable `&app.ui*` · **4** temp+setter where a stored pointer **DANGLES** (`:1102`, `:1965`, `:1969`, `:1973`) · **1** two-value widget with runtime-varying label/count/target (`:1885`) | `main.cpp` as cited | `[READ]`, grep census re-run with **no paren filter** across every value-writing widget |

## 2. 🚨 OPEN — his list, verbatim

1. **"this include sveery parameter in the ui. i dont want ay faders moved from this. they should just be mappable."** `[HIS WORDS]` 2026-09-03, via BRAIN.
   `MEASURE:` none — design job. Buildability is the deliverable.
   State: ✅ **DESIGN COMPLETE AND BUILDABLE** — `docs/DESIGN_2026-09-03_MIDI_MAP_AND_LINK.md` @ `1496dc4`, 614 lines. ⛔ **NOT BUILT. Not one line of source.** §7 names every droppable step.

2. **"No chladni weird different Color profile clearly."** · **"Field is fine. Chladni too dsrk. And pixely."** `[HIS WORDS]` 2026-09-03, via BRAIN.
   `MEASURE:` **`SS_PHASE_AMOUNT=0` during a chord** (FABLE's hook, `main.cpp:386-396`), or set the existing **"Phase Amount"** fader (`main.cpp:1500`) to 0.
   State: **MECHANISM FOUND (§1.4-1.6), TEST NOT RUN.** Collapse onto the field's profile ⇒ confirmed; no change ⇒ I am wrong and it is downstream. ⚠️ **"too dark" and "pixely" are FABLE's lanes and were NOT investigated here.** Free pointer only, no measurement implied: `render.metal:1640` is a VALUE multiplier bottoming at 0.7.

3. **THE ONE QUESTION QUEUED FOR HIM (mine, not his words).** Does a **startup UI pass with headers forced open and rendering suppressed** count as "moving something"? It is the only place his two constraints pull against each other — a registry populated *by drawing* cannot hold a widget never drawn, and `if (showHUD)` (`main.cpp:1119`-`:2268`) plus 16 `CollapsingHeader`s mean the menu is usually closed.
   State: **NOT A BLOCKER.** Written so either answer drops in: **YES** = ~10 lines, mappings live from launch. **NO** = nothing added, mappings arm per panel ⇒ **one menu sweep at soundcheck.** Neither branch changes a struct, the apply loop or a call site.

4. **The System Common (MTC) parser residual.** `[MEASURED n=3, 3/3]` `[F1 MTC quarter-frame][note]`, `[F3 Song Select][note]`, `[F6 Tune Request][note]` **still destroy the note**; `[F2]` survives by accident.
   `MEASURE:` the four vectors in design §2.1c.
   State: **BRAIN RULED HOLD 2026-09-03** — clock never emits these, so the ruled Cologne configuration is fully closed; unrequested change to the stage branch two days out. 🚨 **"the MIDI bug is fixed" is TRUE FOR CLOCK AND FALSE FOR MTC** — and the symptom is intermittent either way, so a later *"notes still drop sometimes"* is this, **not** the fix having failed.

**His three rulings this session, all `[HIS WORDS]` via BRAIN, all folded into the design §8:**
① **TEMPO = MODULATION ONLY** — never `uiIscoSeconds`, never a physics clock; ⛔ the 2026-08-28 camera ban stands untouched. ② **MIDI CLOCK FOR COLOGNE, ABLETON LINK AFTER THE SHOW; vendor nothing.** ③ **CONTROLLER: "both / not decided yet"** ⇒ takeover **built and bypassed**.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **APPLY THE MAPPING INSIDE THE `Ui*` HELPER — REJECTED 2026-09-03 05:52:04, MINE, and it was my own design.** `[READ main.cpp:1119-2268]` the whole mod menu is inside `if (showHUD)`, `:1108-1109` "HIDE ARCHITECT" sets it false, there are **16 `CollapsingHeader`s** and gates like `if (app.uiChorus)` (`:1962`). A helper only runs when its widget is **drawn** ⇒ **hiding the HUD — the performance case — would have killed every mapping.** It would have shipped as *"my controller does nothing once I hide the menu"*, found on stage. **Replacement: register in the helper, apply in the frame loop outside `if (showHUD)`.** The choke-point thesis survives; only the apply site died.
- **A STATIC `{label, &field, min, max}` TABLE — REFUSED throughout, and BRAIN backed it.** It is hand-synced, and this repo has been bitten twice: `PhysicsUniforms` (~40 fields, **no static_asserts** — a removed scalar still compiles and runs) and `PostFXUniforms` (4 bytes out of sync). The registry is populated by the widgets themselves so it cannot drift.
- **ABLETON LINK BEFORE COLOGNE — RULED OUT 2026-09-03.** `[READ, grep]` zero Link hits in `src/`; the only "Ableton" string is a meter-styling comment (`main.cpp:1411`). New dependency + vendor drop + `package_macos.sh` change + network discovery, two days out, on the stage branch. **MIDI clock is already arriving at the parser and comes free from the fix that had to happen anyway.** Link remains right for the next show, and the 2026-08-10 threading analysis is still its design.
- **"A UNIFORM OFFSET ACROSS MANY CITATIONS = DRIFT" — TOO STRONG, CORRECTED 2026-09-03 ~06:2x, MINE.** I gave SONNET that discriminator; it implies the converse. SONNET then found `renderer.mm` cites at **+17** and **+8** among others at **+22**. Offsets are **piecewise per diff hunk**, cumulative above each citation ⇒ **mismatched offsets are NOT evidence of invention.** The check is `git diff` **hunk positions**, not one global delta. Had it taken my version literally it would have flagged two correct citations as fabricated — the exact failure I was trying to prevent.
- **⛔ NOT A DEAD ROAD, recorded so it is not "fixed" into one:** `midi_input.mm`'s `j + 2 < packet->length` is **CORRECT** (not off-by-one); **SysEx is benign** (payload bytes are all `<0x80`, no callback can fire); **velocity-0-as-note-off is CORRECT**.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-03 15:26:31  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 6530c45
  FAIL  7 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
          M  src/core/midi_input.mm
           M src/main.cpp
           M src/render/render.metal
           M src/render/renderer.mm
          ?? docs/BRIEFING_2026-09-03_NIGHT.md
          ?? docs/DESIGN_2026-09-03_MIDI_MAP_AND_LINK.md
          ?? docs/DESIGN_2026-09-03_OFFLINE_RENDERING.md
  WARN  19 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at dbda8e8 — 10 docs-only commit(s) since, no source change
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
  ?     src/render/render.metal:2585:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/render.metal:3329:                mp = rotAboutAxis(mp, float3(0.0f, 0.0f, 1.0f),
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

**Disposition, 2026-09-03 15:28:57 — the §1 FAIL is a fact about 15:26:31 and did not survive the minute:**
- **`docs/DESIGN_2026-09-03_MIDI_MAP_AND_LINK.md` was MINE and is COMMITTED — `1496dc4`, my path only, one concern.**
- **`src/core/midi_input.mm` was SONNET's and is COMMITTED — `9fbe0ba`.** `docs/DESIGN_2026-09-03_OFFLINE_RENDERING.md` was SONNET's and landed while I was committing.
- ⛔ **`src/main.cpp`, `src/render/render.metal`, `src/render/renderer.mm` are FABLE's in-flight work and `docs/BRIEFING_2026-09-03_NIGHT.md` is BRAIN's. NOT MINE, NOT COMMITTED BY ME.** ⭐ Each window commits its own; **nobody sweeps another's work into their commit to make a check go green** — that is the rule the tracked-binary trap exists to protect, and `main.cpp` alone carries a TEMP-DIAG block that is explicitly marked *strip after*.
- **§2 board at `dbda8e8` while HEAD carries a SOURCE commit (`9fbe0ba`)** ⇒ the board is now genuinely behind a source change. ⛔ **Not re-stamped by me: this window changed no source, so claiming a verification at HEAD would be a lie**, and `BOARD_BLACKHOLE.md` is BRAIN's — the standing convention is that we never both hold it at once. All of this session's findings were routed to BRAIN by `SendMessage` as they were made. **Same call as 2026-09-03 00:28:05 and 05:10:00; BRAIN agreed both times.**
- **§2 WARNs (board sizes ×2, `BOARD.md` missing a stamp line)** — pre-existing, not this session's. Splitting a 245 KB board two days before Cologne is not a change to make unasked.
- **§3 both artifacts `ok`** — but that was FABLE's build, not mine. **Re-`stat` before quoting it.**
- **§5 plane sites ×8** — all in FABLE's files. **I edited no source at all.**
- ⚠️ **`MEMORY.md`:** `⭐⭐⭐` is at **6**, under the cap of 7 — I demoted the MIDI row from `⭐⭐⭐` to `⭐⭐` because its live bug is **fixed and committed**, so it no longer meets the tier's own test. **No entry says READ FIRST**; the board row's suffix was removed by another window and I left that edit alone.

**PREFLIGHT ADDENDUM — re-run by BRAIN 2026-09-03 18:32:50, unedited:**

```
1. git
  ok    branch true-physics, HEAD 52f6d68
  ok    working tree clean — committed
  WARN  43 commit(s) not pushed
2. board vs HEAD
  FAIL  docs/BOARD_BLACKHOLE.md is 7 code commit(s) behind HEAD (verified at 74bee76)
  FAIL  docs/BOARD.md is 7 code commit(s) behind HEAD (verified at 74bee76)
  WARN  BOARD_BLACKHOLE.md 250771B / BOARD.md 168191B — split closed rows out
  ok    docs/BOARD_CLOSED.md archive, 104965B — exempt
3. deployed artifact   ok  SpaceSynth + default.metallib newer than newest source
4. referenced paths    ok  49 referenced path(s) in live docs all resolve
5. orbital-plane       WARN 8 site(s) — unchanged boilerplate, no orbital code touched
```

**Disposition (BRAIN, 2026-09-03 18:32:50):** §1 is **clean** — the 15:2x FAIL in this window's own preflight above is gone; every window committed its own work. The two §2 FAILs are the **seven show-renderer commits** (`d4cf127`…`52f6d68`), and **the board is BRAIN's, not this window's** — the fold and re-stamp are owed by BRAIN and named as such by FABLE at 18:33. **Do not fold them from here.**

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| **"Mapping goes inside the helper"** — presented as the whole design | Right about **registration**, wrong about **APPLY**. I verified the helper was a choke point for **drawing** and asserted it was therefore one for **control**. Two claims, one checked — the producer/consumer family, my third this cycle. Caught by reading what `showHUD` gates, before anyone built it. |
| **"`main.cpp:1552` is the SINGLE fader that would silently refuse to map"** | One bypass too few. My grep was `ImGui::SliderFloat(` **with the open paren**, which excludes `ImGui::SliderFloat2(` **by construction**. BRAIN caught `:1874`→`:1885`. Re-ran with no paren filter across every value-writing widget: that was the only miss. **A grep pattern ending in `(` hides every numbered variant of a widget.** |
| **"A uniform offset across many citations = drift, not invention"** (given to SONNET as a discriminator) | Too strong, and it implies the dangerous converse. Offsets are **piecewise per diff hunk**; SONNET found +17 and +8 beside +22. Corrected in the record and sent back. |
| **Two invented timestamps** — 05:56:31 when `date` read 05:55:57; 06:09:11 when it read 06:06:34 | Both were written into a heredoc **in the same tool call that fetched `date`**, so the value was authored before the clock returned. Corrected within the minute both times and self-reported. **Rule recorded: run `date` alone, read it, then write.** |
| **"the parser is critical path if he wants CC on stage"** (to BRAIN) | Too narrow. Once measured it eats **Note-Ons**, so it was critical path **even if CC were dropped entirely**. |
| **"`:1874` is two params from one widget"** (adopting BRAIN's framing) | Undersold it. `[READ main.cpp:1877-1893]` it is inside `for (i < numVoices = activeVoices.size())` with `PushID(i)`, a label **generated by `snprintf("E%d XY")`**, and a `float pos[2]` **stack temporary** copied into `emitters[i]`. **Label, count AND target all vary at runtime.** |

---

**Last Updated:** 2026-09-03 15:28:57 · **§0 + §4 addendum by BRAIN 2026-09-03 18:36:04**
**Folded into board:** ⛔ **NOT by this window** — routed to BRAIN by `SendMessage` throughout; `BOARD_BLACKHOLE.md` is BRAIN's and no source changed here. See §4 disposition.
