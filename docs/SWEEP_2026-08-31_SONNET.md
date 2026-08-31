# SWEEP — SONNET window, 2026-08-31

**Role, per `HANDOFF_2026-08-31_FOUR_WINDOWS.md` §4 and §1a:** mechanical, report-only. This file is
the only one I own. Everything below is a FIND with exact `file:line` and exact replacement text —
**I have not applied any of it.** Never built, launched, or measured. Never touched `src/**` or any
pre-existing doc.

---

## HANDOFF SUMMARY — 2026-08-31, his order "handoff across the board all windows now" (relayed by BRAIN)

**Tags used below: `[MEASURED n=]` / `[READ file:line]` / `[HIS WORDS]` / `[HYPOTHESIS]` — a
`[HYPOTHESIS]` never closes a row.**

### ✅ CLOSED — 6 finds, all applied by OPUS or BRAIN, all `[READ]`-verified after the fact
1. `BOARD_BLACKHOLE.md` §Y1 (lines 20-57 as they stood) — asserted the 102,144 M☉ cap as live, stamped
   `[VERIFIED 15:36:34]`, 34 min before the 16:10:25 kill order. **Applied:** retraction banner + "Y1
   (historical)" split. `[READ BOARD_BLACKHOLE.md:20-40]` confirms it stands.
2. `TODO.md:134` (U1) — "uncommitted" claim contradicted its own clean-git evidence column. **Applied.**
   `[READ TODO.md:134]` confirms.
3. `BOARD.md:797` (E4) — "indigo hover = orphan bundle" is false; indigo is the live theme accent.
   **Applied — retracted.**
4. `DESIGN_2026-08-23_THREE_WALL_ROOM.md:57` — said "~270°" two lines below where line 55 corrected it
   to 291.67°, same-file self-contradiction. **Applied — now reads 291.67°.**
5. **§4a — the science-track dead-cap find, REAL and APPLIED, not a false positive.**
   `SCIENCE_2026-08-31_INDEX.md`/`ADDENDUM_03.md` stamped the 102,144 M☉ cap "✅ SETTLED 16:30" — 20 min
   AFTER the 16:10:25 kill order, so never true at the moment it was written. BRAIN initially called this
   a false positive (thought I'd read a stale/pre-fix copy); I checked rather than accepted the
   correction — the retraction banner's own closing line reads *"Found by SONNET,
   `docs/SWEEP_2026-08-31_SONNET.md` §4"* (`SCIENCE_2026-08-31_INDEX.md:89`, `ADDENDUM_03.md:108`) and
   its commit `05fc97c` (19:41:48) sits chronologically AFTER my report went out, not before. BRAIN
   `[READ]`-verified this independently and retracted the correction in full.
6. `particles.metal:277` citation inside `INDEX.md` — cited as where `F_BH_CLUSTER` is live-defined; the
   constant is deleted, only comments remain at `:266-267`. **BRAIN fixed 20:04:11**, synced to the
   science workspace copy.

### 🔴 OPEN — not fixed, both structural/his calls, both with him now via BRAIN
1. **`TODO.md` vs the boards, contradictory cold-start claims — my best find this session, per BRAIN.**
   `[READ TODO.md:3]` *"This file is the cold start. Read this, not the boards."* `[READ TODO.md:194]`
   footer stamp `Last Updated: 2026-08-26 10:34:14` — 5 days before every 08-31 ruling (cap, ratchet,
   mutual-exclusion law, tonight's 4-fix session), none of which appear in it. Meanwhile
   `BOARD_BLACKHOLE.md` §Z and tonight's evening handoff both claim the board IS the cold start. **Two
   docs claim the entry point and disagree — a new window follows whichever it opens first.** Not fixed
   by design — BRAIN: *"it is HIS, not mine and not yours."* **STILL NOT RULED ON.**
2. **`~/Downloads/SCIENCE_2026-08-31_INDEX.md`** — `[READ]` mtime 14:50:30, zero retraction banners, a
   pre-correction snapshot outside the repo. Live transport hazard if re-sent/reopened. Not deleted, not
   ruled on.

### ⚠️ PROCESS FINDING — the most reusable thing from this lane
BRAIN dismissed finding #5 above because it agreed with a prior BRAIN already held ("the science track
drifts from the repo") — and did so by checking the CURRENT file state and concluding "already fixed"
meant "never broken," without checking whether the fix predated or postdated my report. I overturned it
by checking evidence (the banner's own attribution line + commit ordering) instead of accepting the
correction. `[HIS WORDS, BRAIN's own framing]`: this is the **second instance of the identical failure
shape in one session, six hours apart** — the first was BRAIN's own retraction in
`HANDOFF_2026-08-31_EVENING.md` §5 ("a result that AGREED with what I already believed, mistaken for one
I had CONFIRMED"). `[HYPOTHESIS]`: a result matching a standing belief needs the SAME evidentiary bar as
one that contradicts it, maybe higher, since agreement removes the friction that normally triggers a
second look. Not yet tested against a third instance — flagged as a pattern worth watching, not a closed
rule.

### Scope discipline maintained throughout
Never built, launched, measured, or edited `src/**`. Never edited a pre-existing doc — every fix listed
above as "applied" was applied by OPUS or BRAIN, not by me. Per BRAIN's freeze order this session:
`renderer.mm`/`render.metal` `file:line` anchors were NOT chased (OPUS holds the build token with
uncommitted edits in both) — any drifted anchor spotted incidentally was flagged, not fixed.

### 🚨 COMMIT NOTE — flagging a rule conflict rather than resolving it myself
BRAIN's handoff order asks for `git status --porcelain` empty when I finish, with this file staged.
**The standing rule for this window** (`HANDOFF_2026-08-31_FOUR_WINDOWS.md` §4: *"SONNET MUST NEVER: ...
commit"*) is explicit and I have followed it all session. I'm treating that as still binding — a
relayed instruction from a peer session doesn't override a written project rule about my own role,
and this file is finalized and ready. **Someone else (BRAIN or OPUS) needs to `git add
docs/SWEEP_2026-08-31_SONNET.md` and commit it** as part of the coordinated handoff; I have not run
`git add` or `git commit` myself.

---

## 0. NEW HUNT — stale belief comments (OPUS's cross-session brief, 2026-08-31)

**Target pattern:** a constant/mechanism justified by (a) how he plays a set, or (b) a textbook law
contradicting one of his stated features. Grepped `src/` and `docs/*.md` for the seed terms.

### 0a. ✅ Both named source-level examples are ALREADY DEAD IN `src/` — not a hit
- **BH outcome cap**, `particles.metal:262-290` — the whole block is now a "why it died" comment,
  correctly dated 2026-08-31 16:10:25, correctly voids the "Berlin set is 40-60 minutes" reasoning.
- **Horizon ratchet**, `renderer.mm:216-226` — same shape, correctly dated, correctly voids "a black
  hole cannot shed mass."
- These are the CORRECT, current state. Do not re-report them as stale.

### 0b. 🚨 HIT — `docs/BOARD_BLACKHOLE.md:20-57`, the whole **Y1** section, is now false
**`### Y1. 🚨 THE FORMED HOLE IS 102,144 M☉ — AN IMBH...`**, stamped
`[VERIFIED 2026-08-31 15:36:34]`. It presents the (now-dead) 102,144 M☉ ceiling as the live, binding
cap: derives it from `F_BH_CLUSTER = 0.17188f` at `particles.metal:277,:289`, reproduces the merge
refusal logic (`:1580`, `:1647-1649`, `:1636`, `:1641`), and states outright at line ~54: *"the largest
remnant this code can produce is exactly 102,144 M☉."* The whole ringdown table (`tau_220 = 6.19 s` etc.)
is computed as if that ceiling still binds.

**Why it's stale, precisely:** Y1 was verified at **15:36:34**. His kill order for the cap landed at
**16:10:25** (`particles.metal:262` comment) and is independently confirmed shipped in the SAME file at
`### Z4. ⛔ THE BH OUTCOME CAP IS DEAD` (`BOARD_BLACKHOLE.md:838-849`) and in `STATUS.md:13` (T1: "idle
reached Mmax 161,690 M☉ against the old 102,144 ceiling"). **Z4 and Y1 directly contradict each other
inside the same file — Z4 is correct, Y1 is not.** This is exactly the "honest when written, wrong by
a later ruling" trap: Y1 is not a bad-faith error, it's a science-track section folded in ~34 minutes
before the order that killed its premise, and nobody went back to flag it.

**Scope of the stale block:** `docs/BOARD_BLACKHOLE.md` lines **20–57** (`### Y1. ...` through the line
immediately before `### Y2.` at line 58). The corroboration note about `0.1717` in the second paragraph
(the unit-system observation) is NOT about the cap and may be worth keeping; everything about the
102,144 ceiling being live, the merge-refusal mechanism, and the ringdown table computed against it is
false as of 16:10:25.

**Proposed correction (not applied):** prepend a dated retraction banner to Y1, e.g.:
```
⛔ **Y1 IS STALE — the 102,144 M☉ ceiling it describes was killed 2026-08-31 16:10:25, 25 minutes
after this section was verified. See §Z4 for the current state.** The mass/derivation arithmetic
(F_BH_CLUSTER, the 0.1717 unit-system note) is still correct history; the "largest remnant this code
can produce is 102,144 M☉" claim and the ringdown table computed against it are not — there is no
cap any more, and Mmax has already been measured past it (161,690 M☉, §Z4).
```
Whether to also strike the ringdown table or just banner it is a §BRAIN/§OPUS call, not mine.

### 0c. Nothing else matched the seed grep
`grep -rn -i "cannot shed\|horizon.*ratchet\|running max\|bhSeedMassMono\|monotonic\|monotone\|never drops\|does not leave"` across `src/` and `docs/*.md` returned only the two already-dead source
comments (0a), their correct board corrections (Z1/Z4/Z5, `STATUS.md`), and unrelated uses of
"monotonic" describing `stepTick`/clock counters (`BOARD.md:78`, `:356`) — those describe a counter that
IS supposed to be monotonic (frame/step counting), not a physical-law belief. Not a hit.

---

## 1. S2 — stale-row sweep

### U1 (`docs/TODO.md:134`) — settled, the "uncommitted" half is FALSE
Row says *"E5 is built, uncommitted and UNSEEN... `src/ui/` is clean in git, so the live panel is not
there."* Re-verified now: `git status --short src/ui/` → **empty output, clean**, same as when this row
was written. The row's own logic is backwards: it treats "clean" as evidence the built panel is
*missing from git*, but clean means there is **nothing new to commit** — E5 either was never started in
`src/ui/`, or it isn't in `src/ui/` at all. Either way "built, uncommitted" cannot both be true while the
directory is clean.
**Proposed replacement text for `docs/TODO.md:134`:**
```
| **U1** | **E5's status is UNKNOWN, not "built, uncommitted."** `src/ui/` is clean in git (verified
2026-08-31), which rules out "built and uncommitted in src/ui/" specifically — it does not confirm E5
exists anywhere. Needs one look at the screen to settle what E5 actually is before this bucket moves. |
`git status --short src/ui/` clean, 2026-08-31 | One pass at the screen |
```

### U5 (`docs/TODO.md:138`) — the row IS the correct caution; the thing it's cautioning about is `docs/BOARD.md:797`
`TODO.md:138` already flags itself "MAY BE WRONG — CHECK BEFORE TRUSTING." I checked: the actual false
claim lives at **`docs/BOARD.md:797`**, row **E4**: *"Stale-bundle trap: indigo hover states in a
running app mean you are looking at an orphan bundle, not the code."* This is false — `ui_theme.h:48`
`ImVec4(0.40f, 0.50f, 1.00f, 1.00f)` "Electric Indigo" drives `SliderGrab`/`SliderGrabActive`/
`ButtonActive` in the **live** theme, confirmed by direct read just now.
**Proposed correction:** delete or strike `docs/BOARD.md:797` (E4) entirely — indigo is not a staleness
signal, it's the live accent on three widget states. Once E4 is gone, `TODO.md:138` (U5) can drop its
"may be wrong" hedge and just state the fact: indigo is live theme, not a staleness signal, settled
2026-08-31.

---

## 2. S3 — the 8 dead UI panels

All 8 line numbers re-verified against current `src/main.cpp` (unshifted today, confirmed by OPUS's
own note and by direct read): all still `if (false && ImGui::CollapsingHeader(...))`, all commented
`// removed 2026-06-26`.

| panel | line | what it gates | note |
|---|---|---|---|
| PRESETS | `main.cpp:1427` | preset combo box | commented "(non-functional)" |
| NEW SCIENCE (Phase 9) | `main.cpp:1866` | — | |
| INDUSTRY DEBUGGING (Phase 7) | `main.cpp:1876` | — | |
| VJ MODE & AUDIO INPUT | `main.cpp:1929` | Live Spectrum, Input Gain, mic/system-in enable | 🚨 confirmed live consumer: `audio_engine.mm:181` runs per-band onset detection on the audio thread **every frame regardless** — the panel is the only way to turn mic/system-in on, and it is unreachable by any other route (no keybind, no env var, no preset default — `app_state.h:118` `uiVJMode` defaults false, nothing else in `src/` sets it) |
| DYNAMICS | `main.cpp:2031` | Jitter, Wave Depth | commented "(jitter unlinked, wave depth dead)" |
| VJ FX (Resolume-style) | `main.cpp:2157` | — | |
| PHYSICS STATS | `main.cpp:2206` | `renderer.getPhysicsStats()` readout | |
| DEBUG GPU | `main.cpp:2282` | — | |

This already substantially duplicates `docs/TODO.md:126` (A7) and `docs/STATUS.md` item 5, both of
which I did **not** write and did not edit. Since the handoff (§4, S3) asks for "one decision each,"
here is the one thing those two rows don't do — split the single bundled question into 8 explicit
per-panel yes/no's, so a decision on one doesn't get read as a decision on all eight:

1. **PRESETS** — bring back, or delete the dead branch + its now-orphaned combo-box code?
2. **NEW SCIENCE (Phase 9)** — what was this? (no other doc names it) — needs him to say if it's worth archaeology or just deletion.
3. **INDUSTRY DEBUGGING (Phase 7)** — same: unnamed elsewhere, needs a delete-or-revive call.
4. **VJ MODE & AUDIO INPUT** — the one with a live, running, wasted consumer (onset detection every frame). Highest-cost dead panel of the 8. His call already framed in `TODO.md` A7: wanted back for Cologne, or deliberately buried?
5. **DYNAMICS** — Jitter/Wave Depth already flagged dead by the comment itself; likely a clean delete, not a revive.
6. **VJ FX (Resolume-style)** — delete-or-revive, unnamed elsewhere.
7. **PHYSICS STATS** — a readout panel; cheapest to revive (just flip `false`) if he wants a debug HUD back.
8. **DEBUG GPU** — same, cheapest to revive if wanted.

**Not touched, not flipped, not deleted** — per §1a, this file only.

---

## 3. S4 — board hygiene

### 🚨 HIT — `docs/DESIGN_2026-08-23_THREE_WALL_ROOM.md:57`, self-contradicts the line directly above it
Line 55 (already correct): *"✅ COMPUTED 2026-08-31 00:47:15, not estimated: 291.67°... ⛔ The ~270° this
line carried was a guess and it UNDERSTATED the problem by 22°."*
Line 57 (two lines later, same section): *"Three walls of a rectangular room wrap roughly **270°**
around a viewer standing inside."* — the exact number line 55 just retracted.

**Proposed replacement for `docs/DESIGN_2026-08-23_THREE_WALL_ROOM.md:57`:**
```
Three walls of a rectangular room wrap **291.67°** around a viewer standing inside (§ above). A single
flat perspective projection **cannot** cover that, and this is not a quality argument — it is
arithmetic. A flat image plane needs width ∝ tan(fov/2):
```
(only the number and its rounding change; the rest of the sentence and the table below it are
unaffected and still correct as the general structural argument.)

### Checked, NOT stale — do not re-report
- `docs/BOARD_BLACKHOLE.md` §Z (Z1/Z2/Z3/Z4/Z5) and `docs/BOARD.md` §W — OPUS's own sections, written
  today, code-verified. Left alone per the cross-session note.
- `particles.cpp:242`'s "uniform 1/5 id-subsample" comment — loose about mechanism (it's an id prefix,
  not a stride) but true and load-bearing per `BOARD_BLACKHOLE.md` Z5. Left alone.
- `docs/SHOW_2026-09-05_COLOGNE.md:5` and `docs/HANDOFF_2026-08-23_AUDIO_UI_AND_THE_ROOM.md:39` still
  carry the old 160 m²/~270° numbers, but both are **explicitly self-marked SUPERSEDED** with a pointer
  to the corrected source (`DESIGN_2026-08-23_THREE_WALL_ROOM.md` / `TODO.md` S00e) right next to the
  old numbers. Not a hit — that's the documented provenance pattern, working as intended.
- `docs/TODO.md:72` (S00) — same pattern, explicitly superseded-with-pointer. Not a hit.
- `"killtube"` / `kill-the-tube` references outside `BOARD_BLACKHOLE.md`'s footer (already corrected by
  OPUS): all remaining hits are in `docs/BOARD_CLOSED.md` (closed/history, provenance-only) or in dated
  `HANDOFF_*.md` files describing what was true on their own date. None asserts killtube as the CURRENT
  live tree. Not a hit.
- 402/434-citation anchor-miss rows from `tools/verify_citations.py` — that's O0, OPUS's lane, not
  mine; not re-triaged here.

---

## 4. FOLLOW-UP PASS — OPUS's widened hunt (2026-08-31, after the 4 finds were applied)

Confirmed OPUS applied all 4 finds correctly (re-read each file myself after the message, all 4 hold).
Widened per OPUS's brief: **a claim that was true when [VERIFIED]-stamped and was invalidated by a
later order — the stamp is a date, not protection.** Checked against all 5 named rulings.

### 4a. 🚨 NEW HIT — the whole SCIENCE_2026-08-31 track inherited the dead ceiling, worse than Y1
Y1 (now fixed) was **sourced from** this track. Its siblings carry the same premise and were never
corrected, because Claude Science has no access to the repo and can't know the cap died. Grepped all
7 `docs/SCIENCE_2026-08-31_*.md` for `102,144 | 102144 | 17.2% | 0.17188 | F_BH_CLUSTER`.

**Worst one — `docs/SCIENCE_2026-08-31_INDEX.md:55-60`:**
> ✅ **SETTLED 2026-08-31 16:30 — the `F_BH_CLUSTER` cap applies post-merger and is a REFUSAL, not a
> clamp**... a merge that would carry the remnant over `102,144 M☉` is declined... **So `102,144 M☉`
> is the hard ceiling and `tau_220 = 6.19 s`, `f_220 = 0.167 Hz`.**

This is stamped **16:30 — 20 minutes AFTER** the cap died (16:10:25). It isn't a stamp that aged badly;
it was already wrong the moment it was written, because the science track's clock and the repo's clock
never sync. Marked "✅ SETTLED" is the most confident possible framing for the least true claim in the
whole set.

**Also stale, weaker severity (describe/derive from the same dead constant, not all equally load-bearing):**
- `docs/SCIENCE_2026-08-31_ADDENDUM_03.md:88-124` — a full table computing `tau_220`/`f_220` at
  "maximum reachable remnant | **102,144 M☉** | 17.2% (the cap)" and a second table `today (mass
  conserved) | 102,144 M☉ | **102,144 M☉**...`. Same dead premise as Y1, independently derived.
- `docs/SCIENCE_2026-08-31_INDEX.md:25-28` — cites `particles.metal:277` `F_BH_CLUSTER = 0.17188f` as
  a currently-live line; the constant is now **deleted** (confirmed by OPUS's Y1 fix), so this isn't
  just conceptually stale, the citation itself is a dead anchor `verify_citations.py` cannot catch
  (same "anchors resolve but the code moved on" shape OPUS flagged for Y1 — here the constant is
  gone outright, not shifted).
- `docs/SCIENCE_2026-08-31_ADDENDUM_01.md:66-68,83-118` — discusses `F_BH_CLUSTER` as a live scaling
  law/convention "carried since 2026-08-11." More hedged language ("as a *convention*..."), lower
  severity, but still presents the mechanism as currently enforced.
- `docs/SCIENCE_2026-08-31_ADDENDUM_02.md:147-149` — one-line reference back to Addendum 01's framing.
- `docs/SCIENCE_2026-08-31_blackhole_appearance.md:37-39` — states 0.1717/17.2% as the "typical formed
  hole" mass fraction; same unit-system observation Y1's surviving paragraph makes (not obviously false
  on its own, but built on the same dead constant as its source).

**Not proposing edits to the science docs themselves** — per the handoff §5, they're supposed to be
amended via addenda from the Claude Science track, not hand-edited, and I don't know if a future
addendum will re-derive these once the track is told the cap is dead. Flagging so BRAIN/OPUS can decide
whether to (a) hand-edit a banner the same way Y1 got one, or (b) feed this back as a correction prompt
to the science track (§5's "corrections 6/7/8" pattern in ADDENDUM_03 shows that channel exists).

### 4b. Checked — the render.metal:828 cull-margin claim ("absorbs the aspect")
`grep -rn -i "absorbs the aspect\|cull margin" docs/*.md` → **zero hits.** Not repeated anywhere. Not a hit.

### 4c. Checked, NOT hits — the 5 rulings, swept across `BOARD.md` (877 lines) and `BOARD_BLACKHOLE.md` (912 lines)
- **Cap killed 16:10:25** (`102,144 | 17.2% | F_BH_CLUSTER | FB_TAPER_FROM`): only hits outside the
  already-fixed Y1/Z sections are `BOARD.md:867` (W2, correct) and the Y1(historical) section itself,
  which is now properly banner-retracted. Nothing else in either board.
- **Mutual-exclusion law 16:33:00** (BH persists through play / BH+Chladni coexist): only hits are the
  correct W1 row (`BOARD.md:866`) and §Z's own law statement. Nothing stale.
- **Horizon ratchet killed** (cannot shrink / only rises): only hits are the correct W3 row
  (`BOARD.md:868`) and §Z1's own history. Nothing stale.
- **`gMaxMass` not monotone (2026-08-28)**: only hits are the correct A2 row (historical, describes
  the ORIGINAL discovery correctly) and §Z1's retraction reference. Nothing stale.
- **Both BH renderers deleted 2026-08-27** (photon ring/arch/underside arc "is drawn"): `BOARD_BLACKHOLE.md`
  §1a/§1b/§2/§5/§6 (the lens + march inventory, incl. the "S1✅ S2✅ T1✅ T2✅ S3❌" table at old-line-620
  and "it is still the only thing in the codebase that can produce S3" at old-line-441) describe code
  that reads as present-tense but is now gone — **confirmed BOTH the lens (~320 lines, `bit8`, the
  angle-space thin-lens solve) and the march (~410 lines) were deleted together in commit `00741f2`**
  (`git show 00741f2 --stat`: *"Kill the lens and the ray-march... 852 deletions across both BH
  renderers"*). **This looked like a hit and isn't one** — the file's own header (top of
  `BOARD_BLACKHOLE.md`, the `01f1048` re-stamp note) already says explicitly: *"BOTH BH RENDERERS WERE
  DELETED THIS SESSION — every row below that describes the lens or the march is now HISTORY, not
  state. §1a, §1b, §2, §5 and §6 in particular describe code that no longer exists."* So the
  present-tense language in §1a/§5 is already blanket-disclaimed at the document level. Not re-reporting it — flagging here only so nobody re-verifies the same non-issue.

## 5. Not yet swept
- `docs/BOARD.md` and `docs/BOARD_BLACKHOLE.md` — read in full now (both files, all sections) against
  the 5 rulings above; not yet read line-by-line for anything OUTSIDE that specific pattern.
- `docs/SCIENCE_2026-08-31_merger_signatures.md` and `docs/SCIENCE_2026-08-31_neighbour_finding.md` —
  grepped for the cap terms (no hits), not read in full.
- `docs/BOARD_CLOSED.md` — intentionally not swept, it's closed/history per its own role.
- `docs/TODO.md` — only the U1/U5/A7/S00/S00e rows were checked; not a full pass.

**Confirmed applied 2026-08-31 (BRAIN):** the §4a science-track find (INDEX.md:55-60, ADDENDUM_03.md:88-124,
INDEX.md:25-28) is accepted and being corrected by BRAIN. Not re-reporting once fixed.

## 6. SCOPE RESTRICTION — BRAIN's order, 2026-08-31 evening
⛔ **Do not sweep `renderer.mm` or `render.metal` `file:line` anchors right now.** FABLE reports §Z's
anchors have already drifted (`:3452→~:3501`, `:3481→~:3530`) because OPUS holds the build token with
uncommitted edits in both files (B2a/B2b, cost-probe work). Any anchor I verify against the current
file decays the moment OPUS commits. **That sweep happens AFTER OPUS's commit lands.** I may still note
a drifted anchor if I trip over one incidentally, but I am not chasing `renderer.mm`/`render.metal`
citations as a task right now — doc-only and other-file citations are still fair game.

## 7. TODO.md full read, and the two remaining science docs

### 7a. Science docs — clean
`docs/SCIENCE_2026-08-31_merger_signatures.md` and `docs/SCIENCE_2026-08-31_neighbour_finding.md`
grepped for the cap terms plus `cannot shrink|monotonic|coexist`: one hit, `merger_signatures.md:966`
("A spans months and reddens **monotonically** into an infrared dust cocoon") — that's a luminous-red-nova
lightcurve description, unrelated to `gMaxMass`. Not a hit. Both files otherwise clean of the pattern.

### 7b. 🚨 FINDING — `docs/TODO.md` as a WHOLE FILE is 5 days behind its own claimed role
`TODO.md:3` states *"This file is the cold start. Read this, not the boards."* Its own footer:
**`Last Updated: 2026-08-26 10:34:14`** — before the 2026-08-27 lens+march deletion was folded in
anywhere in this file, before the 2026-08-30 clock unification, and before every one of today's
2026-08-31 rulings (cap kill 16:10:25, mutual-exclusion law 16:33:00, ratchet kill, the evening
session's four cannot-go-down-rule kills). None of that appears in `TODO.md` at all — not wrong
detail, just **absent**, while the file still asserts cold-start authority over the boards that DO
carry it.

**Not a single-line fix** — this is a whole-file currency gap, and I'm not proposing replacement text
for a 194-line file. Concretely, the rows most affected (I did NOT chase their internal `render.metal`/
`renderer.mm` anchors, per §6's restriction — flagging the SHAPE, not the line numbers):
- **BH1, BH5, BH8** read as if the march/lens machinery they describe (bit19 gate, `bhLensActive`,
  the shader constants) is still live rendering geometry. It may just be describing dead code the same
  way `BOARD_BLACKHOLE.md`'s own header now blanket-disclaims (§4c above) — but `TODO.md` carries no
  such disclaimer anywhere, so a reader hits these cold with no warning.
- The whole BH bucket (BH1–BH10) predates the cap/ratchet/mutual-exclusion-law work entirely — none of
  today's biggest decisions are represented.
- The four-buckets structure itself (BH / GRAPHICS / AUDIO / UI) may just need a header banner pointing
  at `STATUS.md` and `HANDOFF_2026-08-31_EVENING.md` for anything after 08-26, the same pattern already
  used elsewhere in this project (`SHOW_2026-09-05_COLOGNE.md`'s "SUPERSEDED ON GEOMETRY" banner is the
  working precedent) — rather than a full re-cut of 194 lines.

**Not proposing to touch it myself** — this is a scope/structure call (re-cut vs. banner vs. leave as
historical BH detail and point cold-start elsewhere), not a fact I can just correct in place.
**2026-08-31: BRAIN confirmed this and it is with him now.**

## 8. Correction exchange with BRAIN — resolved, recorded for the record
BRAIN initially flagged §4a (the science-track find) as a false positive, reasoning the retraction
banner already in `SCIENCE_2026-08-31_INDEX.md`/`ADDENDUM_03.md` predated my report. Checked before
accepting: the banner's own closing line reads *"Found by SONNET, `docs/SWEEP_2026-08-31_SONNET.md`
§4"* — it cites my finding as its source — and the commit that added it (`05fc97c`, 19:41:48) sits
between the four-window-plan commit and the 19:43:26 evening handoff, i.e. **after** my report went
out. BRAIN re-verified independently and retracted the correction in full. No action needed here;
noted only so the finding isn't second-guessed again from a stale premise.

## 9. Checked, not a hit — `DESIGN_BH_2026-08-31_F1_RENDERER.md:239`
Cites `M = 102,144 M☉ ⇒ r_s = 0.1717 sim` as "the formed-hole scale" for a worked resolution example
(deflection angle vs pixel budget). The arithmetic is mass-agnostic — it's a representative number for
a geometry calc, not a claim that 102,144 is still a ceiling. Mildly ambiguous phrasing ("the
formed-hole scale" could read as "the mass a hole always reaches") but this is FABLE's own active
in-progress doc (mtime 18:37, same day), not stale relative to any ruling, and not proposing a change
to another window's live draft over phrasing. Flagging only so it isn't re-checked.
