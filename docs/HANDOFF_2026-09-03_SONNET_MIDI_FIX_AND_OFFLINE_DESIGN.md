# SPACE SYNTH — handoff 2026-09-03 15:28:27

> **His verdict on this state:** not seen yet — he ruled "land it" on the MIDI fix (relayed by BRAIN) and ordered the offline-rendering design before going to bed; no verdict yet on either the built fix or the finished design.
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` §AD → §AC.12 — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `f666aa5`
**Build + launch:** `bash package_macos.sh` then `pkill -f SpaceSynth; open -n SpaceSynth.app` — run by FABLE (build-token holder), not this window. Verified: bundle binary+metallib timestamped after source edit, not stale.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | MIDI System Real-Time bytes (Clock, Active Sensing, Start/Stop, Reset) desync the parser and eat the next message in the same packet | `status & 0xF0` collapses 0xF8-0xFF to `0xF0`, falls into the generic 3-byte branch, over-consumes 2 bytes it doesn't own | Early guard consumes a Real-Time byte alone (1 byte), before the type-masking logic runs | `src/core/midi_input.mm:27-31` (commit `9fbe0ba`) | `[MEASURED n=3 runs, OPUS]` regression vectors — clock+note, active-sensing+note, start+note, reset+note, clock+note+note all now produce correct note(s); previously produced nothing or dropped the first note |

**Also this session:** `docs/DESIGN_2026-09-03_OFFLINE_RENDERING.md` written (commit `f666aa5`, 149 lines) — his order, "how can we implement it," answered at file:line detail across clock, audio, determinism, output path, and scope. Not a fix, no source touched by it; listed here because it's finished deliverable work, not open investigation.

## 2. 🚨 OPEN — his list, verbatim

1. **"answer the rendering question. Offline rendering. How can we implement it."** (relayed by BRAIN) — ANSWERED, see §1 above and `docs/DESIGN_2026-09-03_OFFLINE_RENDERING.md`.
   `MEASURE:` his verdict on the design — not yet given, he went to bed right after ordering it.
   State: design complete, every citation re-verified against the tree at verification time (06:15:26, noted in the doc's own header) after live drift from concurrent FABLE edits was caught mid-session and corrected. Steps A (MIDI+feature logger) and B (real-time replay) are named as the pre-Cologne-buildable candidate if he authorizes; everything else (virtual clock, offline audio, capture pipeline, resolution decoupling, determinism fixes) is named explicitly post-Cologne. Nothing built.

2. **MIDI System Common residual — 0xF1 (MTC quarter-frame), 0xF3 (Song Select), 0xF6 (Tune Request) still eat a note the same way the Real-Time bug did.** BRAIN's explicit HOLD tonight, not his own words yet — his ruling was only ever asked and given for the Real-Time fix.
   `MEASURE:` none further needed — `[MEASURED n=3, OPUS]` already shows all three still fail post-fix, and 0xF2 (Song Position) survives by accident (its real 3-byte size happens to match the code's uniform catch-all).
   State: not touched, by design — MIDI clock alone (the configuration he actually ruled for Cologne) never emits these bytes, so the shipped fix fully closes what he asked for. Fix shape is known (a System Common size table, same function) and written up in messages to BRAIN, not yet a doc row — his yes/no is the only thing blocking it.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

None this session — no approach was tried and rejected; this was a fix (ruled, landed, verified) plus a design (researched, written, citation-audited), not exploratory failure.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-03 15:27:02  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD f666aa5
  FAIL  5 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M src/main.cpp
           M src/render/render.metal
           M src/render/renderer.mm
          ?? docs/BRIEFING_2026-09-03_NIGHT.md
          ?? docs/DESIGN_2026-09-03_MIDI_MAP_AND_LINK.md
  WARN  21 commit(s) not pushed

2. board vs HEAD
  FAIL  docs/BOARD_BLACKHOLE.md is 1 code commit(s) behind HEAD (verified at dbda8e8)
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
  ?     src/render/render.metal:577,765,1146,1466,1469,2585,3329; src/render/postfx.metal:66
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

⚠️ **Both FAILs above are only partly this session's, and neither is fully resolvable by this window alone.**
- **The 5 uncommitted paths are NOT this session's edits.** `src/main.cpp`, `src/render/renderer.mm`, `src/render/render.metal` are FABLE's in-progress build-token work (the return-pull v4 hole-seen latch, a `SS_PHASE_AMOUNT` diagnostic hook, and Chladni work respectively); `docs/BRIEFING_2026-09-03_NIGHT.md` is BRAIN's, `docs/DESIGN_2026-09-03_MIDI_MAP_AND_LINK.md` is OPUS's. Per "one concern per commit," this session committed only its own two concerns (`9fbe0ba` the MIDI fix, `f666aa5` the design doc) and left the rest — bundling another window's unfinished, unauthored-by-me work into a commit under this window's name is the wrong move, not a shortcut. **The tree will not show fully clean after this handoff; the remainder is each other window's own commit to make.**
- **The board-behind FAIL is this session's direct consequence** (my MIDI-fix commit advanced HEAD past the board's last-verified `dbda8e8`) and is NOT folded in below — per this session's established practice (BRAIN folds windows' findings into the board), this handoff is the source record and the fold is BRAIN's, flagged to him directly rather than attempted here against a large, actively-edited shared file.

§5 orbital-plane WARN is boilerplate, unrelated to this session — no orbital/rotational code was touched or read.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "This desyncs the stream continuously... until the parser luckily resyncs" | OPUS measured the built fix's *pre-fix* behavior directly: exactly one message lost per Real-Time byte, deterministic, self-recovering within the same `MIDIPacket` — `j` resets to 0 every packet (`midi_input.mm:26`). Not continuous, not luck. |
| "Memory's '32 of 334,576 cells' figure doesn't match current code — real grid is 2,097,152 cells" | Wrong. Two different, both-true quantities conflated: 334,576 is `bhPeakCount`, the particle count inside the single densest cell (`renderer.mm:404,4407`); 2,097,152 is the total cell count (`kGridSize³`, `renderer.mm:140,148-149`). BRAIN caught it, I verified independently before accepting. The 32-of-334,576 figure is correct and became stronger evidence for the design doc's determinism section (measured 11.1×/3.4× fork on identical input). |
| "OPUS's `main.cpp:1552` citation for the physics-substeps widget is wrong" | It was correct when OPUS wrote it. Live tree drift — FABLE landed an 11-line diagnostic hook (`SS_PHASE_AMOUNT`, `main.cpp:386-396`) between OPUS's read and mine, shifting the widget to `:1563`. Retracted directly to OPUS. |
| "I fabricated twelve `renderer.mm` line numbers for the `totalAmplitude` gate sites" | Wrong self-accusation. All twelve were off by a uniform +22 — the signature of concurrent-edit drift (FABLE's `renderer.mm` return-pull v4 commit, net +22 lines, landing above all twelve citations), not invention. Verified the arithmetic against `git diff --numstat` before accepting BRAIN's correction. Two other citations in the same doc (`:638→:655`, `:499→:507`) did NOT fit a clean offset and needed genuine re-derivation — the discriminator is a *uniform* offset across many citations relative to actual diff hunks, not "any offset at all." |

---

**Last Updated:** 2026-09-03 15:28:27
**Folded into board:** NOT YET — flagged to BRAIN. This session's MIDI-fix commit put `docs/BOARD_BLACKHOLE.md` one code commit behind HEAD (see PREFLIGHT FAIL above); per established practice this session, BRAIN folds windows' findings into the board rather than each window editing the shared file directly.
