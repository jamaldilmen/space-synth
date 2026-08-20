# PROCESS AUDIT — how we work, measured against our own record

**Written:** 2026-08-17 15:21:35
**Corpus read:** 242 markdown docs across the `SPACE SYNTH` trees, `docs/BOARD.md` (216,691 B),
`docs/BOARD_BLACKHOLE.md`, every `HANDOFF_*` 2026-06-30 → 2026-08-16,
`REPORT_2026-07-28_failures_and_fixes.md`, and 139 memory files.
**Method:** counted, not recalled. Every number below is reproducible with the command shown.

---

## 0. THE ONE SENTENCE

Our diagnosis quality is high and our *retention* is low: the same faults recur with a
counter attached to them ("5th sighting"), which proves the problem is not that we fail to
learn — it is that **everything we learn is stored as prose, and prose does not execute.**

---

## 1. WHAT THE RECORD ACTUALLY SHOWS

### 1.1 Retractions are frequent and their cause is ONE cause

`grep -oih "retract[a-z]*" docs/*.md | wc -l` → **41** in the killtube tree alone.
`REPORT_2026-07-28` scores one session at **2 wins, 6 misses, 4 retractions.**

Every retraction the docs bothered to explain names the same mechanism:

| Retracted claim | Stated cause (verbatim from the docs) |
|---|---|
| "merge starves capture through the shared plate word" | *"a mechanism inferred from a curve instead of counted at the gate"* |
| "the bound never engages" / "capture delivers ~0.1 M☉/frame" / "the hole is out of fuel" | *"all three came from reading `feed=` in the log — a ONE-FRAME sample of a buffer that is cleared every frame"* |
| "SOR is not the monster" | *"written off 9 samples"* |
| "pose clock keyed to seed mass, 2,150× too light" | wrong branch — `bhPosed` was false; the cited code never ran |
| "the honest r_h is flickering to zero" | read an old log, live log showed monotone growth |
| "capture cull is inconsistent with the sheared frame" | reasoned from a principle, never measured |

**The class is singular: asserting a mechanism from an inference (a curve, a log line, a
code read) instead of from a count taken at the site.** `space_synth_comment_is_not_a_mechanism`
already names it and it happened again after that memory was written.

The claims that **held** — the hardcoded orange at `render.metal:2474`, the second instanced
image, S7's missing luminosity term — were all direct reads *with the numbers checked at the
site*. The success pattern is already known. It just isn't enforced.

### 1.2 Known faults recur with a counter on them

```
grep -rhoi "\(2nd\|3rd\|4th\|5th\|second\|third\|fourth\|fifth\) sighting" docs/*.md
```
→ 3rd ×6, 4th ×2, **5th ×2**.

- **90°-off orbital plane** — 5 sightings. Cost, by our own accounting: ~2 months of a working
  feature sitting behind `if (false)`, plus two features condemned as "fake overlay" when the
  plane was the fault.
- **Comment is not a mechanism** — 3 sightings.
- **Size-slider denominator** — 3 sightings.
- **Stale bundle** — burned a full day on 2026-06-14, still the standing first suspect.

Each already has a dedicated memory file. **The memory did not prevent the repeat.** That is
the central finding of this audit.

### 1.3 There is almost no automated verification, but excellent measurement parts

- Test files in the whole repo: **1** (`tools/measure/bessel_test.cpp`).
- Yet we have **40+ `SS_*` env gates** (`SS_NO_DEPTH_PREPASS`, `SS_SPH_AB`, `SS_NO_DEADSKIP`, …),
  `tools/lanes.py`, `zprobe.py`, `analyze_dump.py`, `ladder.sh`, `a1_watch.sh`, `a2_watch.sh`,
  `measure_n/`.

We built the instruments and never built the panel. Every one of those gates is run by hand,
remembered from a doc, and forgotten between sessions.

### 1.4 The "reference of truth" is losing to the handoff stream — measurably

`BOARD.md` header: *"Last verified against the code: 2026-08-13 … Commit at last verification:
`13ac249`"*.
`git log --oneline 13ac249..HEAD | wc -l` → **3 commits behind.**

Worse, on the doc it names as the BH cold start:
- `docs/BOARD_BLACKHOLE.md` mtime **2026-08-14 12:40:58**
- commit `e853e18` message: *"…**BH board step 1**: the colour of the gas"*
- files that commit touched: `docs/HANDOFF_2026-08-16_STARS_STAY_STARS.md`, `src/render/render.metal`
- **`BOARD_BLACKHOLE.md` is not in it.**

So a decision explicitly labelled "step 1 for the BH board" exists only in a handoff, while the
board it belongs to still reads as the cold start. This is exactly the drift the board was
created to stop.

### 1.5 The cold start costs more context than it should

- `BOARD.md` — 216,691 B ≈ **55k tokens**, roughly a third of a context window to read once.
- Its composition: **65 ✅ rows vs 13 🔴/❌ rows.** The board is ~80% history by row count.
- `docs/*.md` across trees: **242 files**, 40+ of them handoffs, each superseding the last,
  none retired.
- Three worktrees (`TUBE`, `TUBE-camera`, `TUBE-killtube`) each carry a **full copy** of `docs/`.
  `BOARD.md` exists three times, diverged: 173,799 B vs 216,691 B. The memory
  `feedback_parallel_windows_build_token` already bans parallel *builds*; the *docs* still fork.

### 1.6 The priority channel is saturated

`MEMORY.md` — 21,677 B, loaded into **every** session before a word is exchanged.
- Entries marked `⭐⭐⭐`: **45**.
- Distinct entries claiming "READ FIRST" / "READ THIS FIRST" / "read before" / "NEWEST": **9**.
- Memory files total: **139**, of which **76** are `space_synth_*`.

45 top-priority items is zero top-priority items. Nine documents each claiming to be the one
read first is a coin flip, and a new window resolves it wrong.

---

## 2. WHAT TO CHANGE

Ordered by evidence weight. Each is small, each is checkable, none requires a rewrite.

### P1. Turn the repeat offenders into a script — `tools/preflight.sh`
**Why:** §1.2. Five sightings of one fault with a memory file already written is proof that
prose is the wrong storage medium for a rule that must fire every time.

Mechanical checks, all of which we already do by hand and sometimes forget:
1. **Stale bundle** — `SpaceSynth.app/Contents/MacOS/SpaceSynth` and
   `Contents/Resources/default.metallib` mtime ≥ newest `src/**` mtime. Fail loud.
2. **Board freshness** — parse `Commit at last verification:` out of `BOARD.md`;
   fail if `git rev-list <sha>..HEAD` is non-empty. (Today: 3.)
3. **Plane convention** — grep new/changed code for `length(pos.xy)`, `(-y, x, 0)`, bare `+Z`
   assumptions in any orbital context; print the sites for a human read. Cheap, and it is
   the fault with the highest recorded cost.
4. **Dead-code cite guard** — a `check_caller <symbol>` helper that greps for callers before a
   `file:line` goes into a board row. Two retractions came from citing code that never ran.

**Acceptance:** running it on today's tree must report the 3-commit board drift found in §1.4.
If it doesn't, the script is wrong.

### P2. No mechanism claim without a count — make it the board's format
**Why:** §1.1. One cause, six retractions.

Rule: to state "X causes Y", there must be a counter **at X's site** whose value is printed.
Anything short of that is written as `HYPOTHESIS:` and cannot close a row. This is not new
discipline — it is the discipline that produced every claim that survived. It just needs to be
the default shape of a sentence rather than an act of virtue.

Corollary already learned the hard way and worth stating in the format:
**a single-frame read of a per-frame-cleared buffer is not a measurement.** Nor are 9 samples.

### P3. Every board row carries its deciding command
Add one line per open row: `MEASURE:` — the exact command/env-gate that settles it.
A row without one cannot be worked; writing it is the first step of working it.

**Why:** it converts the 40+ `SS_*` gates from tribal knowledge into the board's own contents,
and it makes the away-from-keyboard measurement work he already asked for self-serve —
`grep "^MEASURE:" BOARD.md` becomes the queue.

### P4. Split the board — open rows only
`BOARD.md` = the 13 open rows + priority + standing rules. Target **< 20 KB**.
`BOARD_CLOSED.md` = the 65 closed rows, verbatim, append-only, never read at cold start.
Dead roads stay in the open board — a rejected approach is load-bearing, a shipped one is not.

**Why:** §1.5. A cold start that costs 55k tokens gets skipped, and when it gets skipped the
session works from a handoff instead, which is exactly how §1.4 happened.

### P5. Close the session on the board, not on the handoff
The handoff is a dated diff of one session. The board is state. Today the diff is winning.

Rule: a session cannot end until its findings are folded into the board and the header's
`Commit at last verification:` is updated. The handoff then shrinks to what it should be —
what changed, what he said, what's next — and stops being a second board.

**Immediate instance:** the BH gas-colour decision and S7's implication for it are in the
08-16 handoff and belong in `BOARD_BLACKHOLE.md`.

### P6. One docs root
`docs/` lives in the live tree only. Other worktrees carry a one-line stub pointing at it.
**Why:** §1.5 — three diverged copies of the reference of truth is a contradiction in terms.

### P7. Triage `MEMORY.md`
- Cap `⭐⭐⭐` at **7**. Everything else demotes.
- Exactly **one** entry may say "READ FIRST", and it says which project it is first for.
- Retire the `space_synth_*` memories the board now owns — a per-session finding that has been
  folded into `BOARD.md` should leave a pointer, not a copy.

**Why:** §1.6. The index is the first thing every session reads and it currently transmits no
ranking at all.

---

## 3. WHAT IS ALREADY WORKING — do not "improve" these

- **His verdict as the gate.** Every real win in the corpus closes on his words. Keep it.
- **The measurement tooling.** The gates and probes are good; only the harness is missing.
- **Dead-road records.** `⛔ DEAD ROAD, recorded so it is not retried` (e.g. `L̂ = r × v`) is the
  single highest-value doc pattern we have. More of these, not fewer.
- **The retraction ledger.** Writing down what we withdrew, with its cause, is what made this
  audit possible at all. It is the only reason §1.1 could be written from evidence.
- **Timestamps to the second.** They let this audit order events without guessing.

---

## 4. SCOPE BEYOND SPACE SYNTH

P2 (count, don't infer), P5 (state beats diary), P6 (one root) and P7 (rank the index) are not
graphics-specific. They apply to the AC Shadows work, the VIDEO-RACK contract, SANDBOX, and any
Purple task with a running document. P1's *form* generalises even where its checks do not:
**any rule that has been broken twice belongs in a script, not a memory file.**

---

**Last Updated:** 2026-08-17 15:21:35
**Status:** analysis only — zero code changed, zero docs rewritten. Awaiting his pick.
