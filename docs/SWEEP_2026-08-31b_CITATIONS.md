# 🔎 CITATION SWEEP 2026-08-31b — TODO.md + BOARD_BLACKHOLE.md rot

**Job from BRAIN, 2026-08-31 ~22:29-22:53, report-only.** Find and report rotted
`file:line` citations in `docs/TODO.md` and both boards; do NOT apply, do NOT edit
TODO.md/boards/src, do NOT commit. This file is the report.

**Verified against the live working tree** (includes the uncommitted `renderer.mm`
changes) at **2026-08-31 22:58:59**, repo `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS`
@ `true-physics`, HEAD `c793e4a` + uncommitted `renderer.mm` (+216/-3 lines,
instrument work). `render.metal` is **3270 lines** now — every doc that says
"file is 3106 lines" is itself a stale fact, not just a stale line number.

🚨 **RACE CONDITION OBSERVED:** at least one other window is live-editing these
same docs right now. `TODO.md` BH4 and BH5, and `BOARD_BLACKHOLE.md` §Z8, and
the `renderer.mm:5165` source comment were ALL corrected between BRAIN's message
and this sweep (timestamps 22:50–22:52:54, i.e. minutes before I read them). Two
of BRAIN's "already verified, don't re-derive" items are therefore **already
fixed** — reported below as RESOLVED, not as open findings, so the count isn't
inflated with stale asks.

Ran `tools/verify_citations.py`: exit 0, zero DEAD (range) hits on the four core
docs. Its anchor-miss (±18 line window) list did **not** catch most of what
follows — several of these drifts are 60-215 lines, which should trip the
window, and didn't. **Do not trust its silence on TODO.md's BH rows; every one
below was found by hand-checking the actual grep, per BRAIN's method note #2.**
Recommend telling BRAIN separately that the tool may be mis-parsing compound
citations in bolded/backticked prose cells (worth a follow-up, not blocking this
report).

---

## Already resolved — no action needed (found already-fixed during this sweep)

### R1. `docs/TODO.md` BH4 (line 62)
Already struck 2026-08-31 22:52:54. BRAIN's finding was correct and has been
applied by someone else in the interim. Nothing to do.

### R2. `docs/BOARD_BLACKHOLE.md` §Z8, `bhLensActive` cite (line 1136)
Already corrected 2026-08-31 22:52:54: now reads
`` [READ renderer.mm:1957 — CORRECTED 2026-08-31 22:52:54, this said :1907] ``.
Matches the verified truth (`renderer.mm:1957`). Nothing to do.

### R3. `src/render/renderer.mm:5165` (source comment, not a doc)
Already corrected: now reads `renderer.mm:1957 gates \`bhLensActive\`` (was
`:1907`). Out of my edit lane regardless (src/**), flagging only because BRAIN
named it explicitly — it's done.

### R4. `docs/TODO.md` BH5's own cross-reference text is now stale (line 63)
BH5 was corrected 22:50 to cite `renderer.mm:1957` (confirmed correct), but its
prose still says *"the same symbol is wrong in two other places — `BOARD_BLACKHOLE.md`
§Z8 and a source comment written tonight at `renderer.mm:5165` both say `:1907`"*.
**Both of those were fixed at 22:52:54+, after BH5's own 22:50 correction was
written.** BH5's claim about the other two docs is now false-by-timing, not
false-by-error. Low priority (it's a footnote, not a load-bearing cite), but
worth a one-line update so the next reader doesn't go chase two already-closed
citations. Suggested replacement for that clause: *"corrected here 2026-08-31
22:50; `BOARD_BLACKHOLE.md` §Z8 and `renderer.mm:5165` were also wrong and have
since been fixed (22:52:54)."*

---

## `docs/TODO.md` — BH1 through BH10 (highest priority, per BRAIN's order)

### F1. BH1 (line 59) — `app_state.h:57` "bit19 default ON" is citing a RETIRED bit, and the row's whole verification path is DEAD CODE
**Claim:** the 08-17 emission law (blackbody `T(r)`, `g`, absorption/transfer) landed and is
supported by `app_state.h:57` "bit19 default ON"; the fix column tells the next
reader to "read `[MARCH] bCull`" to verify coverage.
**Cite as written:** `` `app_state.h:57` bit19 default ON ``
**Verified now:**
- `bit19` does **not exist** in `app_state.h` — zero grep hits. `main.cpp:2553`
  says outright: *"bit17 (breathing) + bit19 (swirl) retired 2026-07-09"*.
  `app_state.h:57` is unrelated prose (a `uiTogMetricShadow` fallback comment).
- Worse: `bCull` and the `[MARCH]` telemetry this row tells the reader to go
  read **do not exist anywhere in the tree**. `bCull` is declared as a dead
  struct field (`render.metal:2975`, `renderer.mm:33`, comment only, never
  assigned) and there is no `[MARCH]` printf anywhere in `renderer.mm`. Grep
  confirms: the entire ray-march (`bhmarch_fragment`, its cull dial, its
  telemetry) was deleted in `00741f2` (2026-08-27, "Kill the lens and the
  ray-march: a black hole is not a lens") — the SAME deletion TODO.md's own
  header already warns about for BH2/BH3/BH5/BH6/BH8, but BH1 and BH7 were
  **missed** by that correction pass.
**Correct file:line:** none — there is no live equivalent of `bCull`/`[MARCH]`
to cite. This isn't a line-number drift, it's a load-bearing mechanism that no
longer exists.
**Exact replacement text (suggested, not applied):** strike the `app_state.h:57
bit19 default ON` cite entirely and replace the fix column with something like:
*"⛔ The march this row's verification depended on (`bCull`, `[MARCH]` telemetry)
was deleted 2026-08-27 `00741f2` along with `bhmarch_fragment`. There is currently
no way to read march coverage — this row needs re-scoping against whatever
replaced the march (if anything), not a line-number fix."*

### F2. BH2 (line 60) — Kerr Ω sprite formula drifted 19 lines
**Claim:** "Sprite Kerr Ω is now `render.metal:1409` (`1.0f/(pow(rXY,1.5f)+KERR_A)`)"
**Cite as written:** `render.metal:1409`
**Verified now:** the formula `float omega = 1.0f / (pow(rXY, 1.5f) + KERR_A);`
is at **`render.metal:1428`**, not `:1409`. `:1409` is inside an unrelated
"NEVER READ / Doppler-as-hue removed" comment block. `KERR_A` itself is still
correctly cited at `:308`.
**Correct file:line:** `render.metal:1428`
**Exact replacement text:** `` Sprite Kerr Ω is now `render.metal:1428` (`1.0f/(pow(rXY,1.5f)+KERR_A)`, `KERR_A` at `:308`) ``

### F3. BH3 (line 61, struck) — `bhbody_fragment` and its `bc=` line both drifted 19 lines; file-length fact is stale
**Claim:** "the sphere is `bhbody_fragment` at `render.metal:3015`, its `bc =
2.5980762f * rsW` at `:3028` (`render.metal` is 3106 lines...)"
**Cite as written:** `render.metal:3015`, `:3028`, "3106 lines"
**Verified now:** `fragment BHBodyOut bhbody_fragment(...)` is at
**`render.metal:3034`**; `float bc = 2.5980762f * rsW;` is at **`render.metal:3047`**
— both off by exactly 19 lines, same drift as F2 (one insertion of ~19 lines
happened above both, sometime after the 2026-08-30 23:50:35 re-read this row
cites). `render.metal` is now **3270 lines**, not 3106.
**Correct file:line:** `bhbody_fragment` → `render.metal:3034`; `bc =` → `render.metal:3047`
**Exact replacement text:** `` the sphere is `bhbody_fragment` at `render.metal:3034`, its `bc = 2.5980762f * rsW` at `:3047` (`render.metal` is 3270 lines; `renderer.mm:3852` is horizon-stats, not the draw) ``
*(`renderer.mm:3852` was not independently re-verified this pass — flagging only
the two `render.metal` sites that were checked.)*

### F4. BH6 (line 64, struck) — both AMR "fixed" citations are wrong; a different pair of lines is now live
**Claim:** "FIXED 2026-08-22 04:53 — AMR MOVED TO bit21. `renderer.mm:1962` +
`particles.metal:2124`."
**Cite as written:** `renderer.mm:1962`, `particles.metal:2124`
**Verified now:** `renderer.mm:1962` is an unrelated A0-test comment about ortho
radius. `particles.metal:2124` is inside an unrelated SPH relaxation-diffusion
comment block — nothing about AMR or bit21 there. The real bit21 AMR code:
`` if (amrOn < 0) amrOn = getenv("SS_NO_AMR") ? 0 : 1; `` at **`renderer.mm:2296`**,
and the actual pack `` physicsUniforms.bhToggles = bhToggles | (amrOn ? 0x200000u : 0u); // bit21 = AMR fine force `` at **`renderer.mm:2310`**. The `particles.metal`
side of the AMR gate now lives around **`particles.metal:2198-2221`** (comments
there explicitly reference "the BH6 note at renderer.mm:1949" and "AMR IS ON BY
DEFAULT").
**Correct file:line:** `renderer.mm:2310` (primary — the actual bit21 pack),
`particles.metal:2198` (AMR default-on comment/gate area)
**Exact replacement text:** `` FIXED 2026-08-22 04:53 — AMR MOVED TO bit21. `renderer.mm:2310` (bit21 pack) + `renderer.mm:2296` (SS_NO_AMR check) + `particles.metal:2198` ``

### F5. BH7 (line 65) — same dead `app_state.h:57` cite as BH1
**Claim:** the 128³ box-average objection, supported by `app_state.h:57`.
**Cite as written:** `app_state.h:57`
**Verified now:** same as F1 — `app_state.h:57` is unrelated prose, and there is
no live grid-sampling dial at that address. (128³-grid box-averaging as a
*concept* is still real and current — see memory's "THE GRID SAMPLES 32 OF
334,576" note — but this specific citation does not point at it.)
**Correct file:line:** not found in `app_state.h`; the 128³ grid lives in the
PM-gravity/spatial-hash path (`spatial_hash.metal`), not a UI toggle — needs a
fresh citation from whoever re-scopes this row, not a line-number swap.
**Exact replacement text:** strike `app_state.h:57` from this row; it does not
support the claim.

### F6. BH8 (line 66) — three "live sites" all drifted; file-length fact stale
**Claim:** "Live sites: `:337` (`kLensBc`), `:990` (`bCapt`), `:3028`
(`bhbody_fragment`), plus prose at `:327`, `:986`, `:1042`, `:2997`." (also
repeats "file is 3106 lines")
**Cite as written:** `render.metal:337`, `:990`, `:3028`
**Verified now:**
- `constant float kLensBc = 2.5980762f;` is at **`render.metal:344`** (off by 7)
- `float bCapt = 2.5980762f * cam.horizonR * R;` is at **`render.metal:1009`** (off by 19 — same 19-line drift family as F2/F3)
- `bhbody_fragment` is at **`render.metal:3034`** (this row cited `:3028`, which
  is close but is the `float bc = ...` region in the *other* function per F3 —
  the two rows (BH3 and BH8) actually point their `:3028` at two different
  things, neither of which is `bhbody_fragment`'s real line)
- File is 3270 lines, not 3106 (same stale fact as F3).
- The four "prose at" lines (`:327,:986,:1042,:2997`) were not individually
  re-verified this pass — lower priority, flag for a follow-up sweep.
**Correct file:line:** `kLensBc` → `:344`; `bCapt` → `:1009`; `bhbody_fragment` → `:3034`
**Exact replacement text:** `` Live sites: `:344` (`kLensBc`), `:1009` (`bCapt`), `:3034` (`bhbody_fragment`) `` (file-length note → "render.metal is 3270 lines")

---

## `docs/BOARD_BLACKHOLE.md` §Z6–§Z9 (tonight's rows, second priority)

### F7. §Z6 row 1 (line 1014) — `bhSeedMassMono` running-max site drifted 147 lines
**Claim:** the killed "running max" rule lived at `renderer.mm:3452`.
**Cite as written:** `renderer.mm:3452`
**Verified now:** `:3452` is unrelated GPU threadgroup-dispatch code. The live
(now "LIVE, not a running max") assignment is `` bhSeedMassMono = gMaxMass; //
LIVE, not a running max — see decl `` at **`renderer.mm:3599`**; the field is
declared at `renderer.mm:232`.
**Correct file:line:** `renderer.mm:3599` (assignment), `renderer.mm:232` (decl)
**Exact replacement text:** `` `bhSeedMassMono` running max | `renderer.mm:3599` (was a running max; now `LIVE, not a running max`, decl at `:232`) ``

### F8. §Z6 prose (line 1020) — `bhDiskGM` boolean-gate cite wrong on both line numbers
**Claim:** "`bhDiskGM` is 0-or-full across a boolean gate (`renderer.mm:1948` / `:1986`)"
**Cite as written:** `renderer.mm:1948`, `:1986`
**Verified now:** neither line contains `bhDiskGM` — zero hits at either address.
The real gate assignments are `cam.bhDiskGM = (float)gmNow;` at **`:2045`** and
**`:2096`**, with the zeroing branch `cam.bhDiskGM = 0.0f;` at **`:2105`**.
**Correct file:line:** `renderer.mm:2045`, `:2096`, `:2105`
**Exact replacement text:** `` `bhDiskGM` is 0-or-full across a boolean gate (`renderer.mm:2045` / `:2096`, zeroed at `:2105`) ``

*(Same row's `render.metal:2130` cite for the 220px blackbody blob was
hand-checked and is CORRECT — `cam.horizonR <= 0.0f` gate is exactly there, with
`pow(Mbh,0.8f)` at `:2137` right beside it. No finding.)*

### F9. §Z7 (line 1081) — `restMs` and `PROFILE Total` cites both wrong, by 213 and ~60 lines
**Claim:** "`[READ renderer.mm:4947]` `restMs = lastRenderMs` — render only.
`[READ renderer.mm:1786,:1797]` `PROFILE Total = Compute + Render`."
**Cite as written:** `renderer.mm:4947`; `renderer.mm:1786`, `:1797`
**Verified now:**
- `float restMs = lastRenderMs;   // the rest-of-frame bracket, same frame` is
  at **`renderer.mm:5160`**, not `:4947` (which is an unrelated `SS_LENS_COST`
  env-var check).
- The `[PROFILE/120f] ... Total avg` printf is at **`renderer.mm:1846`**.
  Neither `:1786` (start of `Renderer::render()`) nor `:1797` is it.
**Correct file:line:** `restMs` → `renderer.mm:5160`; `PROFILE Total` → `renderer.mm:1846`
**Exact replacement text:** `` `[READ renderer.mm:5160]` `restMs = lastRenderMs` — render only. `[READ renderer.mm:1846]` `[PROFILE/120f] ... Total` = Compute + Render ``

### F10. §Z8 (line 1110) — REBIRTH-withdraws citation wrong, real sites ~320-380 lines away
**Claim:** "`[READ renderer.mm:3781-3793, :3411]` REBIRTH withdraws mass from the
hole every frame while playing"
**Cite as written:** `renderer.mm:3781-3793`, `:3411`
**Verified now:** `:3781-3793` is an unrelated block about the old BH-formation
latch (proxy criteria history). `:3411` is unrelated physics-substepping
comment. The actual withdraw text — *"Sustain rebirth now WITHDRAWS mass from
the hole"* — is at **`renderer.mm:3461-3462`**, and the runtime printf `` "[REBIRTH]
withdraw=%.1f Msun/frame  hole=%.1f  seedTarget=%.3f%s\n" `` is at **`renderer.mm:3843`**.
**Correct file:line:** `renderer.mm:3461-3462` (comment), `renderer.mm:3843` (printf)
**Exact replacement text:** `` `[READ renderer.mm:3461-3462, :3843]` REBIRTH withdraws mass from the hole every frame while playing ``

*(Same row's `render.metal:3171-3173` cite for `lensdebug_fragment`'s parameter
list was hand-checked and is CORRECT — the function signature starts exactly
there. No finding.)*

---

## Not yet checked this pass (out of time/token budget, report to BRAIN for next batch)
- `docs/BOARD_BLACKHOLE.md` §Z9's `HANDOFF_2026-08-30_HOW_DOES_NASA_DO_THIS.md:47` cite — FROZEN-tier doc, low priority by the tool's own rules, not hand-checked.
- `docs/BOARD.md` — not started (third priority per BRAIN's order; `verify_citations.py`'s own anchor-miss list for it is 56 items, none hand-verified yet).
- BH8's four "prose at" lines (`:327,:986,:1042,:2997`).
- BH1/BH2/BH3/BH6/BH8's OTHER un-cited-here numbers inside their own paragraphs (only the bolded/backticked "live site" claims were checked, not every stray number in the prose).

## Count
**10 open findings (F1–F10)** + **4 already-resolved-by-someone-else items (R1–R4)**
reported for visibility per BRAIN's instruction not to re-derive known ones.
10 is under the 30-item batch cap — this is the full TODO.md BH1-10 + §Z6-9 sweep,
not a partial first batch. BOARD.md and "everything else" remain, per the
priority order, for a follow-up pass if wanted.

---
---

🚨 **BATCH 2 BELOW WAS STALE WITHIN MINUTES OF BEING WRITTEN — SUPERSEDED.**
OPUS deleted 4 dead uniform fields (`tuneLens`, `tuneArcWrap`, `tuneArcGain`,
`tuneTrailGain`) across `render.metal`/`renderer.h`/`renderer.mm`/`main.cpp`/
`app_state.h` at 23:07:47-23:07:55, on his order, while this batch was being
read against the pre-delete tree. Every `render.metal`/`renderer.mm` line
number in batch 2 below the deletion point drifted -4. **Do not apply batch 2
as written — see "BATCH 2 CORRECTED" after batch 3, re-verified fresh against
the post-delete tree.** Batch 1 and batch 3 were independently confirmed
unaffected (see the corrected section for why). Leaving the stale text below
in place rather than editing it in-line, so the record of what went wrong is
visible, not silently fixed.

# BATCH 2 — 2026-08-31 23:xx — `docs/BOARD.md`, priority tiers 1 (renderer.mm > 3000) and 2 (render.metal)

**Continuation order from BRAIN, 2026-08-31 23:04.** All 10 prior findings were
independently re-verified by BRAIN and applied. Two lessons carried forward into
this batch, per BRAIN's note:
- **Citations can rot at the PATH level, not just the line.** (`app_state.h`'s
  real path is `src/core/app_state.h` — BH1/BH7 were wrong about the directory,
  not only the line.)
- **Citations rot INSIDE source comments too**, and nothing sweeps those
  automatically — `particles.metal:2198`'s own "see the BH6 note at
  renderer.mm:19..." is an example found by BRAIN, not by this tool.
Applying that lesson below: several findings in this batch are **wrong-file**,
not just wrong-line, and are called out explicitly where found.

Re-verified against the live tree at **2026-08-31 23:2x** (same HEAD, renderer.mm
still has the same uncommitted instrument-4 diff as batch 1). `verify_citations.py`
is confirmed by BRAIN to catch none of this class of error (DEAD only fires past
EOF) — every citation below resolves to a real, wrong line, so the tool's clean
exit means nothing here. Not re-run this batch; hand-grep only, per BRAIN's
correction.

`docs/BOARD.md` is 878 lines with ~33 unique `render.metal:N` citations and
~20 unique `renderer.mm:N` citations above line 3000, several inside very
citation-dense rows (C4b alone carries a dozen). This batch covers: every
`renderer.mm` citation above 3000 (tier 1, complete), plus a priority sample of
`render.metal` citations weighted toward the rows most likely hit by the two
named deletions (tier 2, partial — flagged where a row has more uncovered
citations). Not yet touched: the ~25 `render.metal` citations below line 2500,
most `main.cpp`/`particles.metal`/`postfx.metal` citations, and the general
BOARD.md rows outside tiers 1-2.

## Tier 1 — `renderer.mm` above line 3000 (complete pass)

### T1-T3. BOARD.md line 502/514 — the A9/absorption-pass row, three renderer.mm-side citations wrong
**Claims + cites as written:**
- "`render.metal:2544-2620` (`dust_vertex`/`dust_fragment`), pipeline `renderer.mm:733-748`, draw disabled `renderer.mm:3504` `if (false && dustPipeline)`"
**Verified now:**
- `dust_vertex` is at **`render.metal:2869`**, `dust_fragment` at **`render.metal:2927`** (not `2544-2620` — that range is now unrelated post-fx code)
- the `dustPipeline` assignment is at **`renderer.mm:956`** (decl at `:289`), not `733-748`
- `if (false && dustPipeline) {` is at **`renderer.mm:4444`**, not `:3504` (`:3504` is now unrelated `radialMassBuffer` clear code)
**Correct file:line:** `render.metal:2869` / `:2927`; `renderer.mm:956` (decl `:289`); `renderer.mm:4444`

### T4. BOARD.md line 503 — "UN-DEPTH-SORTED" comment citation
**Claim + cite:** the field-verdict comment explaining why the dust draw is off — `renderer.mm:3494-3503`
**Verified now:** `:3494-3503` is now the `radialMassBuffer`-clear commit's code (unrelated). The real comment block (*"DISABLED 2026-07-23 16:34 — FIELD VERDICT... The CONCEPT (design §2b) stays..."*) is at **`renderer.mm:4434-4443`**, immediately above the `if (false && dustPipeline)` at `:4444`.
**Correct file:line:** `renderer.mm:4434-4443`

### T5. BOARD.md line 514 — A9's cause citation is the WRONG FILE, not just the wrong line
**Claim:** "cause at `renderer.mm:658-663`, `:3504`" for `applyInverseSpin` (written for the metric ray) and `physPosW` (the pre-pose position the density march samples).
**Cite as written:** `renderer.mm:658-663`
**Verified now:** `applyInverseSpin` and `physPosW` **do not exist in `renderer.mm` at all** (zero grep hits in the whole file). Both live in **`render.metal`**: `applyInverseSpin` defined at `render.metal:139`, `physPosW` defined at `render.metal:676`, and the `A9: EXTINCTION` marker comment is at `render.metal:2364`. `:658-663` in `renderer.mm` is unrelated AMR-pipeline setup code.
**Correct file:line:** `render.metal:2364` (A9 marker), `render.metal:139` (`applyInverseSpin`), `render.metal:676` (`physPosW`) — **wrong file, per BRAIN's path-level warning**, not a line drift within `renderer.mm`.

### T6-T8. BOARD.md line 590 — row **P6**, three citations wrong
**Claim + cites:** `render.metal:782` (`rDil = length(in.posW.xyz)`); `renderer.mm:3293-3295` (`bhPosX/Y/Z` hard-set to `0.0f`, the ORIGIN LOCK); `renderer.mm:2935` (the enclosure-COM refinement, disabled inside `if (false)`).
**Verified now:**
- `rDil` is declared at **`render.metal:944`**, not `:782` (`:782` is now an unrelated secondary-lensed-image comment)
- the actual zeroing `bhPosX = 0.0f; bhPosY = 0.0f; bhPosZ = 0.0f;` is at **`renderer.mm:4070-4072`** (decl at `:214`), not `:3293-3295` (that range is now the `bhPosX/Y/Z = totalEX/EY/EZ / totalEC` COM-refinement code itself — a different part of the same mechanism, but not what this cite claims)
- the `if (false)` around the COM refinement is at **`renderer.mm:3692`**, not `:2935` (`:2935` is now unrelated AMR-prolongation dispatch code)
**Correct file:line:** `render.metal:944`; `renderer.mm:4070-4072`; `renderer.mm:3692`

### T9. BOARD.md line 614 — postfx depth-DontCare citation
**Claim + cite:** "Post-FX has no depth texture bound... `storeAction = DontCare`" — `renderer.mm:3356`
**Verified now:** `:3356` is now the play-gate check on `mergeStarsPipeline` (unrelated). The real line is `` offscreenPass.depthAttachment.storeAction = MTLStoreActionDontCare; `` at **`renderer.mm:4139`**. Bonus: `renderer.mm:421` carries its OWN internal comment citing `(:3356)` for this same DontCare line — that source-comment citation is ALSO stale (confirms BRAIN's "citations rot inside comments too" pattern, this time in `renderer.mm` itself, out of my edit lane).
**Correct file:line:** `renderer.mm:4139`

### T10. BOARD.md line 641 — posePhase host-gate citation
**Claim + cite:** "posePhase host gate (`renderer.mm:3327`)"
**Verified now:** `:3327` is now horizon/cull-log printf code (unrelated). The real gate is `` const bool poseTimeLapseActive = ... `` declared at **`renderer.mm:4104`**, used in the guarding `if` at **`:4109`**.
**Correct file:line:** `renderer.mm:4104` (decl), `:4109` (use)

### T11. BOARD.md line 793 — row **E5**, PhysicsStats publishing citation
**Claim + cite:** "`renderer.h` PhysicsStats; `renderer.mm:3278`" for first-time publishing of `horizonR`/`horizonMassMsun`/`horizonRatio`.
**Verified now:** `:3278` is now an unrelated origin-lock explanatory comment. The real assignments are `latestStats.horizonR` at **`renderer.mm:4031`**, `.horizonMassMsun` / `.horizonRatio` at **`:4032`** / **`:4033`**.
**Correct file:line:** `renderer.mm:4031-4033`

### T12-T13. BOARD.md line 868 — row **W3**, two citations wrong
**Claim + cite:** "`renderer.mm:3452`, `:3481`" for the killed running-max ratchet and the `LATCH` printf.
**Verified now:** same `:3452` rot as TODO.md §Z6 (batch 1, F7) — real `bhSeedMassMono = gMaxMass; // LIVE, not a running max` is at **`renderer.mm:3599`**. The `LATCH` printf (`bhFormedLatch ? " LATCH" : ""`) is at **`renderer.mm:3830`**, not `:3481` (`:3481` is now an unrelated substep-loop-end comment).
**Correct file:line:** `renderer.mm:3599`; `renderer.mm:3830`
**Note — same underlying rot as batch-1 F7, different doc row.** `renderer.mm:3452` for `bhSeedMassMono`'s running-max is now wrong in at least two places (TODO §Z6 and here); worth a single fix that both rows can cite, not two separate patches.

## Tier 2 — `render.metal` (priority sample, not exhaustive)

### T14. BOARD.md line 285 — spike cross citation
**Claim + cite:** "`render.metal:2652` draws `spikeX`/`spikeY`"
**Verified now:** the assignments are at **`render.metal:2671-2673`** (19-21 line drift — same small-drift family as several batch-1 `render.metal` findings).
**Correct file:line:** `render.metal:2671-2673`

### T15-T16. BOARD.md lines 507-508 — dust-shader gate citations
**Claim + cites:** cellCounts grid read at `render.metal:2586`; `cold` gate at `:2579`.
**Verified now:** the `dust_fragment`-side `cellCounts` buffer declaration is at **`render.metal:2873`**; the actual `cold = 1.0f - clamp(...)` line is at **`render.metal:2887`**. Both are ~300 lines downstream of the cited numbers — consistent with the hole_fragment/dust_fragment shift found in T18/T20 below (same deletion).
**Correct file:line:** `render.metal:2873` (cellCounts); `render.metal:2887` (cold gate)

### T17-T21. BOARD.md line 761 — row **C4b**, the densest row checked this batch, five findings including one DEAD function
This row has its own internal correction history (2026-08-22, then 2026-08-26)
and is still stale after both.
- **T17** `ParticleFragOut` struct cited at `render.metal:2687-2689` → real **`:2496`**
- **T18** `hole_fragment` cited at `render.metal:3080` → real **`:2841`**
- **T19** 🚨 **`bhmarch_fragment` cited at `render.metal:3342` — THE FUNCTION IS DELETED, not moved.** `render.metal:3098` says outright: *"~410 lines removed: bhmarch_fragment in full"* (the 2026-08-27 `00741f2` deletion, one day after this row's 2026-08-26 correction). C4b's own text — *"`hole_fragment`, `bhmarch_fragment` and `dust_fragment` each return a plain `float4`... only `particle_fragment` returns `ParticleFragOut`"* — is now a claim about a function that does not exist. **This needs re-scoping (is there a replacement candidate pass, or is the count now two, not three?), not a line-number fix** — same class of finding as batch-1 F1.
- **T20** `dust_fragment` cited at `render.metal:3166` → real **`:2927`**
- **T21** the row's OWN 2026-08-26 self-correction — *"Mask line numbers are now `:752, :788, :828, :860`"* — has drifted AGAIN since that correction. Current `MTLColorWriteMaskNone` sites in `renderer.mm`: **`:853`, `:895`, `:919`, `:949`** (plus `:897`, a fifth site — `bd.colorAttachments[0]`, the DEPTH-ONLY `bhBodyPipeline` mask, a different attachment than the four `[1]`-index velocity masks the row is counting). The count of 4 relevant masks still holds; only the addresses moved a second time.
**Correct file:line:** see each above.

### T22. BOARD.md line 585 — row **P1**, a claim FALSIFIED by a later deletion (flagging distinctly, per BRAIN's ask — this is a §Z6-shaped finding, not just a bad address)
**Claim as written (2026-08-22 dated correction):** *"the original's... is NOT supported — the 2026-06-28 deletion was a fullscreen disk shader and the 2026-07-24 metric march is **live** (`renderer.mm:214`, `render.metal:2694`)."*
**What's actually true now:** the "2026-07-24 metric march" IS `bhmarch_fragment` — the same function T19 just found deleted in full on 2026-08-27. **The row's corrective claim that the metric march is "live" is no longer true; it was true when written (2026-08-22) and was falsified five days later by a deletion nobody folded back into this row.** This is not a line-number problem — `render.metal:2694` now just lands on unrelated particle-emission code — it's the row's central assertion being overtaken by later work, same shape as the §Z6 "running max" → "LIVE, not a running max" example BRAIN asked to flag separately.
**Recommended action (not applied):** P1's dropped-claim note needs a fresh correction pointing out the march no longer exists, not a re-cite.

---

## Count, batch 2
**22 findings (T1–T22)**, all hand-verified by direct grep against the live tree,
covering the complete tier-1 (`renderer.mm` > 3000) pass and a priority sample of
tier 2 (`render.metal`). One of them (T19, echoed by T22) is a dead-function /
falsified-claim finding, the most severe class per BRAIN's method note — not a
line drift, the code is gone.

**Remaining in BOARD.md, not yet covered:** most `render.metal` citations below
line 2500 (~25 of them), `main.cpp`/`particles.metal`/`postfx.metal` citations
generally, and every row outside tiers 1-2. Will continue into those next
unless redirected.

---
---

# BATCH 3 — 2026-08-31 23:3x — `docs/BOARD.md`, remaining tier-2 `render.metal` citations below line 2500

Continuing tier 2 (no new instruction, same lane: report-only, no edits/commits).

### T23. Line 373 — `render.metal:30`, `:47` (dead `waveDepth` field)
**Verified now:** `float waveDepth;` in `CameraUniforms` IS at **`render.metal:30`**, exact. ✅ CORRECT, no finding. (`:47` is a "read this" pointer inside the same struct region, not independently checked — low risk.)

### T24. Line 564 — `particle_vertex` function start and its "cull at :665" drifted; the row's larger claim is unaffected
**Cite as written:** `render.metal:541` (function start), `:665` (cull)
**Verified now:** `vertex VertexOut particle_vertex(` is at **`render.metal:650`**, not `:541` (109-line drift). The cull condition is harder to pin exactly — the file's own internal cross-reference (`render.metal:914`: *"the capture cull (:697) tests..."*) points at **`render.metal:697`**, which is also confirmed below (T25) to be the disk-rotation/capture gate block. `:665` itself is now mid-function setup code, not a cull. Treat `:697` as the likely correct site, not a certainty — did not trace the full cull logic line-by-line to confirm it's the SAME cull this row means.
**Correct file:line:** `particle_vertex` → `render.metal:650`; cull → **probably** `render.metal:697` (flagged as probable, not confirmed)

### T25. Line 588 — row **P4**, disk-rotation gate and rotation code both drifted; found the real block, and it independently confirms T7/T8
**Cite as written:** `render.metal:595`, `:530` (rotation code + gate)
**Verified now:** both cited lines are now unrelated prose (spawn-noise / integration-error commentary). The real gate — `` if ((cam.bhToggles & 0x100000u) && cam.bhDiskGM > 0.0f && cam.bhDiskAxisY < 0.5f && cam.envelopePhase < 0.5f) `` — matching P4's own quoted condition text almost verbatim, is at **`render.metal:697-698`**, with the `rxy = length(rel)` orbital-radius line right after it at **`render.metal:710`**.
⭐ **Bonus, unprompted:** the source comment immediately inside this block (`render.metal:701-703`) cites `` renderer.mm:3293-3295 `` and `` renderer.mm:2935 `` for the ORIGIN LOCK — **the exact same two wrong addresses found independently in T7/T8** (real: `renderer.mm:4070-4072` and `:3692`). The rot isn't just in the boards; it's baked into the shader's own comments, and it's the SAME wrong pair of numbers propagating into a second file. Worth fixing once, in the source, so both this shader comment and BOARD.md P6 stop pointing at dead code — but that's a src/** edit, outside my lane; flagging for whoever applies these.
**Correct file:line:** gate → `render.metal:697-698`; rotation math → `render.metal:710`+

### T26. Line 589 — row **P5**, DEFAULT ON/OFF contradiction citation drifted
**Cite as written:** `render.metal:527`
**Verified now:** `:527` is unrelated spawn-noise commentary. The two things this row is actually about — `` bit20 is DEFAULT ON (app_state.h:56) `` and the *"COMMENT CORRECTED 2026-08-11 12:31:44 (P5)"* marker — are at **`render.metal:627`** and **`render.metal:686`** respectively. (`app_state.h:56` itself not re-verified this pass — see the F1/F5 path-and-line caution already raised for `app_state.h` citations generally; worth a dedicated check given BRAIN's directory-level finding.)
**Correct file:line:** `render.metal:627` (DEFAULT ON note), `render.metal:686` (correction marker)

### T27. Line 592 — row **P8**, `render.metal:927`
**Verified now:** content matches almost verbatim — *"P6 CLAIM REFUTED HERE, 2026-08-11 12:31:44... measures dilation from the ORIGIN while the hole sits..."* sits right at this address. ✅ CORRECT, no finding.

### T28. Line 593 — row **P9**, two small drifts
**Cite as written:** `render.metal:157` (`velDir2D` decl), gate at `:1236`
**Verified now:** `velDir2D` is declared at **`render.metal:153`** (4-line drift — trivial, flagging for completeness only). The `screenDist < 0.15f && > 0.002f` gate is at **`render.metal:1202`**, not `:1236` (34-line drift).
**Correct file:line:** `render.metal:153`; `render.metal:1202`

### T29. Line 730 — row **DEAD-COMPUTE**, corpse-invisibility citation drifted 159 lines
**Cite as written:** `render.metal:715` ("corpses invisible" — mass-gated clip behind the near plane)
**Verified now:** the actual code — `` // Wall particles (mass=0) are invisible... if (mass < 0.001f) { out.position = float4(0,0,-2,1); ... out.pointSize = 0.0f; ``  — is at **`render.metal:873-874`**, not `:715`.
**Correct file:line:** `render.metal:873-874`

### Not independently confirmable this pass
- Line 765, row **C10** (`render.metal:485`, "the one real build warning") — could not verify without the original warning text to match against; `:485` currently lands inside `unifiedKelvin()`, plausible but not confirmed. Flagging as unchecked, not as a finding.

---

## Count, batch 3
**7 findings (T23slot-through-T29, excluding the two confirmed-correct T23/T27)** —
concretely: T24, T25, T26, T28, T29 are rot; T23 and T27 are verified CORRECT
(reported for completeness, not as findings); C10 is unchecked. Running total
across all three batches: **10 (batch 1) + 22 (batch 2) + 5 (batch 3) = 37 open
findings**, plus the 4 already-resolved items from batch 1 and 2 confirmed-correct
citations from batch 3.

**Still remaining, not yet swept:** `main.cpp`/`particles.metal`/`postfx.metal`
citations in `BOARD.md` (the DEAD-COMPUTE row alone has ~8 `particles.metal`
citations not yet checked), every `BOARD.md` row outside tiers 1-2, and all of
`docs/BOARD_BLACKHOLE.md` outside §Z6-Z9 (batch 1) and the P6/A9 cross-references
already swept incidentally in batch 2. Pausing here — three batches is 37 items,
past the 30-per-batch guidance, and a natural checkpoint before the much larger
"everything else" tier. Say if you want the sweep to continue into it.

---
---

# PROCESS FINDING — a citation sweep has the same staleness problem as the thing it sweeps

**BRAIN's finding, 2026-08-31 ~23:10, recorded here at his request.** Batch 2's
numbers were not read carelessly — they were read correctly, against a tree
that then changed under them (OPUS's 23:07:47-55 deletion) before BRAIN applied
them. BRAIN caught it because the error was a **uniform -4 offset** across
every affected symbol, which is the signature of the file moving, not the
reader being wrong — a real misread produces scattered, non-uniform errors.

**The lesson: a correction file is itself a claim about a moving tree, and it
rots exactly like the citations it's fixing — possibly faster, since a sweep
touches far more lines per minute than normal editing does.** A freshly-stamped
wrong line number is worse than an old one nobody re-checked recently, because
the fresh timestamp reads as verified. **Fix, going forward: every batch in
this file states the HEAD commit and the newest touched `src/` file mtime it
was verified against, not just a wall-clock timestamp for when I happened to
run the grep.** A wall-clock stamp says when I looked; a HEAD+mtime stamp says
what I looked AT — and it's the second one a reader needs to know whether the
correction is still trustworthy.

**Bonus finding, found while re-verifying:** three comments in `render.metal`
(`:531`, `:2728`, `:2754` pre-delete numbering — now `:527`, `:2724`, `:2750`
post-delete, confirmed by fresh grep) still describe `tuneArcWrap` as a live
cap bounding the arc's sweep angle. That uniform was deleted in the same
23:07:47-55 change — `grep -rn "tuneArcWrap" src/` now returns only these three
comments, zero declarations or uses. **These are stale comments describing a
now-deleted mechanism, not stale line numbers** — src/**, OPUS's lane, reporting
only.

---
---

# BATCH 2 — CORRECTED, re-verified post-delete — 2026-08-31 23:20:00

**Verified against:** HEAD `84c1314d64dca92b340d17bc96ba8568b0a1f385`, working
tree with the uncommitted diff unchanged in shape from batch 1 (same instrument
work) plus OPUS's now-landed 4-uniform deletion. Newest touched `src/` mtimes:
`render.metal` / `renderer.h` **2026-08-31 23:07:55**, `renderer.mm` /
`main.cpp` / `app_state.h` **2026-08-31 23:07:47**. Wall-clock of this
re-verification: **2026-08-31 23:20:00**. Every number below is a fresh `grep`/
`sed` read against that exact tree state just now — none are batch-2's numbers
minus 4 by arithmetic, per BRAIN's explicit instruction.

Corrected replacements for T1-T13 (T14-T22 not yet re-verified post-delete —
see note at the end):

| # | symbol | was cited (stale, batch 2) | CORRECT now (fresh grep, 23:20:00) |
|---|---|---|---|
| T1 | `dust_vertex` | `render.metal:2869` | **`render.metal:2865`** |
| T1 | `dust_fragment` | `render.metal:2927` | **`render.metal:2923`** |
| T2 | `dustPipeline` assignment | `renderer.mm:956` | **unchanged, `renderer.mm:956`** (upstream of the deletion point in this file — decl also unchanged at `:289`) |
| T3 | `if (false && dustPipeline)` | `renderer.mm:4444` | **`renderer.mm:4440`** |
| T4 | "DISABLED 2026-07-23..." comment block | `renderer.mm:4434-4443` | **`renderer.mm:4430-4439`** (header line `── DUST EXTINCTION PASS` at `:4430`, "DISABLED 2026-07-23 16:34" at `:4434`, last line "this v1 draw is off" at `:4439`) — this range was imprecisely eyeballed in batch 2, not just shifted; fixed to the exact span this pass |
| T5 | `applyInverseSpin` | `render.metal:139` | **`render.metal:135`** |
| T5 | `physPosW` (decl) | `render.metal:676` | **`render.metal:672`** |
| T5 | A9 EXTINCTION marker | `render.metal:2364` | **`render.metal:2360`** |
| T6 | `rDil` | `render.metal:944` | **`render.metal:940`** |
| T7 | `bhPosX/Y/Z` hardset | `renderer.mm:4070-4072` | **`renderer.mm:4066-4068`** |
| T8 | `if (false)` COM refinement | `renderer.mm:3692` | **`renderer.mm:3688`** |
| T9 | `offscreenPass...DontCare` | `renderer.mm:4139` | **`renderer.mm:4135`** |
| T10 | `poseTimeLapseActive` decl / use | `renderer.mm:4104` / `:4109` | **`renderer.mm:4100`** / **`:4105`** |
| T11 | `latestStats.horizonR/.horizonMassMsun/.horizonRatio` | `renderer.mm:4031-4033` | **`renderer.mm:4027-4029`** |
| T12 | `bhSeedMassMono = gMaxMass; // LIVE...` | `renderer.mm:3599` | **`renderer.mm:3595`** (decl unchanged, `renderer.mm:232`) |
| T13 | `LATCH` printf | `renderer.mm:3830` | **`renderer.mm:3826`** |

**Confirmed still standing exactly as found in batch 2, unaffected by the
deletion (checked fresh, not assumed):**
- T19/T22's central finding — `bhmarch_fragment` is still fully deleted; its
  "~410 lines removed" marker comment is now at `render.metal:3094` (was
  `:3098`, the expected -4).
- T9's bonus finding is now WORSE, not fixed by the shift: `renderer.mm:421`'s
  own comment still says `` storeAction=DontCare (:3356) `` — literal text, so
  the deletion didn't move the number it cites, only the number IT'S written
  at. It was wrong before the deletion and remains wrong now (real target
  `renderer.mm:4135` as of this check).

**New, found only during this re-verification — the "wrong pair of numbers
propagating" from T25 is worse than T25 said:** `render.metal` contains
**three** separate comments citing the stale `renderer.mm:3293-3295` /
`renderer.mm:2935` pair for the ORIGIN LOCK, not the one T25 flagged — at
`render.metal:557`, `:701`, and `:933` (all unaffected in position by the
4-line deletion, since they're upstream of render.metal's own deletion point;
their CONTENT — the renderer.mm addresses they cite — was already wrong before
the deletion and is unrelated to it). Real target, confirmed again this pass:
`renderer.mm:4066-4068` (hardset) and `renderer.mm:3688` (the `if (false)`).
Same for `particles.metal:2198`'s "see the BH6 note at `renderer.mm:1949`" —
confirmed this pass, `:1949` is unrelated horizon-smoothing code; the real BH6
FIX marker is at `renderer.mm:2293` (was `:2297` pre-delete, i.e. this ALSO
shifted, but was wrong at either address).

**Not yet re-verified post-delete:** T14-T22 (batch 2's `render.metal` tier-2
sample) and all of batch 3 (T23-T29). Batch 3 happens to have been read AFTER
23:07:55 by coincidence of when its tool calls ran (spot-checked `particle_vertex`
at `render.metal:650` and the P4 gate at `render.metal:697` just now — both
match exactly what batch 3 already reported, unchanged), so batch 3 is believed
current, but this was luck, not verified process, and BRAIN should treat it
with the same "re-grep before applying" caution as everything else in this
file rather than trusting my "batch 3 looks fine" claim on its own.

---
---

# SESSION RESUMED 2026-09-01 13:24:01 — usage-limit gap overnight, closing out on BRAIN's order

**Confirmed by BRAIN:** batch 1 (F1-F10) was applied before the gap. This
session picks up holding batch 2, with instructions to close the sweep out
for a handoff, NOT extend it into the "everything else" tier.

**First action: re-verified "BATCH 2 — CORRECTED" (above) against the tree AS
IT NOW STANDS, per BRAIN's warning not to assume it still holds.** Good thing —
**it did NOT hold.** The tree moved again after my 2026-08-31 23:20:00 check:
3 more commits landed (`84c1314`, `c64a7ce`, `5f38928` — board re-stamps and a
handoff, HEAD unchanged since since these were already the tip) plus further
UNCOMMITTED edits to `render.metal` (mtime now `2026-09-01 01:21:35`) and
`renderer.mm` (mtime `01:22:23`). BRAIN's own message said nothing has moved
since `01:22:26`, and my check just now (`13:24:01`) confirms that window —
but my LAST verification (`23:20:00` on 08-31) predates `01:21:35`/`01:22:23`,
so it needed re-doing, not trusting. This is the exact trap BRAIN named:
re-verified, did not assume.

## BATCH 2 — RE-CORRECTED, verified 2026-09-01 13:24:01

**Verified against:** HEAD `84c1314d64dca92b340d17bc96ba8568b0a1f385` (unchanged
since yesterday — these are uncommitted working-tree edits, not new commits).
`render.metal` mtime `2026-09-01 01:21:35`, `renderer.mm` mtime `01:22:23`.
Fresh `grep`, not arithmetic, run at `13:24:01`.

| # | symbol | 23:20:00 value (now ALSO stale) | CORRECT now (13:24:01) |
|---|---|---|---|
| T1 | `dust_vertex` | `render.metal:2865` | **`render.metal:2885`** |
| T1 | `dust_fragment` | `render.metal:2923` | **`render.metal:2943`** |
| T2 | `dustPipeline` assignment | `renderer.mm:956` | **`renderer.mm:1006`** |
| T3 | `if (false && dustPipeline)` | `renderer.mm:4440` | **`renderer.mm:4564`** |
| T4 | "DISABLED 2026-07-23..." comment | `renderer.mm:4430-4439` | **`renderer.mm:4554-4563`** (header at `:4554`, "DISABLED..." at `:4558`, last line at `:4563`) |
| T5 | `applyInverseSpin` | `render.metal:135` | **unchanged, `render.metal:135`** |
| T5 | `physPosW` (decl) | `render.metal:672` | **`render.metal:679`** |
| T5 | A9 EXTINCTION marker | `render.metal:2360` | **`render.metal:2380`** |
| T6 | `rDil` | `render.metal:940` | **`render.metal:947`** ⚠️ **NOT UNIQUE ANY MORE** — a second `rDil = length(mp)` now also exists at `render.metal:3246`, unrelated local variable, same name, different scope. Anyone grepping `rDil` blind now gets 2 hits; cite the declaring function too if this gets applied. |
| T7 | `bhPosX/Y/Z` hardset | `renderer.mm:4066-4068` | **`renderer.mm:4152-4154`** |
| T8 | `if (false)` COM refinement | `renderer.mm:3688` | **`renderer.mm:3774`** |
| T9 | `offscreenPass...DontCare` | `renderer.mm:4135` | **`renderer.mm:4221`** |
| T10 | `poseTimeLapseActive` decl / use | `renderer.mm:4100` / `:4105` | **`renderer.mm:4186`** / **`:4191`** |
| T11 | `latestStats.horizon*` (3 fields) | `renderer.mm:4027-4029` | **`renderer.mm:4113-4115`** |
| T12 | `bhSeedMassMono = gMaxMass; // LIVE` | `renderer.mm:3595` | **`renderer.mm:3681`** |
| T13 | `LATCH` printf | `renderer.mm:3826` | **`renderer.mm:3912`** |

**Shift pattern, for whoever applies this next:** NOT uniform this time (two
separate insertions landed between 23:20 and now) — `render.metal` sites split
into a +7 group (`physPosW`, `rDil`) and a +20 group (A9 marker, `dust_vertex`,
`dust_fragment`, the `bhmarch_fragment` marker at old `:3094`→now **`:3114`**);
`renderer.mm` sites split into a +50 (`dustPipeline`), a +86 group (everything
from `bhSeedMassMono` through the `DontCare` at old `:4135`), and a +124 group
(the dust-disable comment + `if(false)`). **Do not assume a single offset
applies to the whole file — this sweep already had to learn that lesson twice
in one evening.** Re-grep each symbol at apply time regardless of what table is
sitting in this file by then.

**T14-T22 and T23-T29 were NOT re-verified this pass** — out of scope for this
close-out per BRAIN's explicit "do not start the everything else tier," and
re-verifying 16 more citations was judged the same class of scope-creep. Given
the drift just measured in T1-T13, **treat every number in T14-T29 as probably
stale too** — they have not moved in the file, but the tree under them has,
twice, since they were written.

---

## CLOSING SUMMARY — for BRAIN's handoff

**File:** `docs/SWEEP_2026-08-31b_CITATIONS.md` (this file). Repo
`/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` @ `true-physics`.
**Untracked in git — confirmed by `git status` at 13:24:01, still showing `??`.**
It exists, holds real corrections, and will NOT survive a `git clean`, a reset,
or simply being forgotten. It needs either committing as-is (a report, not a
code change) or its still-open findings applied and the file retired.

**Total findings across the sweep: 37 open + 4 already-resolved-by-others (R1-R4,
batch 1) + 2 confirmed-correct citations that needed no fix (T23, T27, batch 3).**

- **Applied: 10** — batch 1, F1-F10 (`docs/TODO.md` BH1-BH10 + `BOARD_BLACKHOLE.md`
  §Z6-Z9). BRAIN re-verified each by grep before applying. Done, closed.
- **UNAPPLIED: 27**, all still sitting in this file as text only, none of it in
  `TODO.md` or either board:
  - **13** in "BATCH 2 — RE-CORRECTED" just above (`docs/BOARD.md`, the `renderer.mm`
    > line-3000 tier) — freshly re-verified at `2026-09-01 13:24:01`, safe to
    apply AS OF THAT TIMESTAMP, but re-grep at apply time if the tree has moved
    since (check `render.metal`/`renderer.mm` mtimes against `01:21:35`/`01:22:23`
    first — if they're newer, these numbers need a third pass).
  - **9** in original batch 2, T14-T22 (`render.metal` tier-2 sample,
    `docs/BOARD.md` rows 285/507-508/761) — last verified `2026-08-31 23:xx`,
    **two tree-moves stale, unverified against current state.** Re-grep before
    applying; do not trust the line numbers as printed.
  - **5** in batch 3, T24/T25/T26/T28/T29 (`docs/BOARD.md` rows 564/588/589/593/730)
    — same staleness caveat as the T14-T22 group.
  - Of the 27, **one (T19, echoed by T22) is not a line-number problem** —
    `render.metal`'s `bhmarch_fragment` is deleted outright (confirmed AGAIN
    this pass, marker now at `:3114`), and `BOARD.md` row C4b / row P1 both
    still assert it exists. That one needs re-scoping by a human/agent judgment
    call, not a citation swap, whenever it's picked up.
- Scope never reached: `main.cpp`/`particles.metal`/`postfx.metal` citations
  generally, every `BOARD.md` row outside the two tiers swept, and all of
  `BOARD_BLACKHOLE.md` outside §Z6-Z9. Not started, not claimed as findings,
  not part of the 37.

**Bottom line for the handoff:** the sweep is closed, not finished. 10 fixes
landed. 27 more are written down, correct as of specific timestamps stamped
next to each batch, and every single one of them needs a fresh `grep` — not
a trust of this file's numbers — before a future window applies them, because
this tree has proven it moves fast enough to outdate a sweep within the same
evening, twice.

---

## Suggestion for `verify_citations.py`, per BRAIN's ask (not built, just recorded)

The tool's blind spot, proven repeatedly tonight: it only fails a citation when
the line number runs past EOF (`DEAD`) or the cited *identifier* doesn't appear
within ±18 lines (`anchor-miss`) — and every rotted citation found by hand this
session **resolved to a real, in-range line**, so neither check fired. What
would have caught these: **anchor on the surrounding TEXT, not just the
identifier.** Concretely — at sweep time, snapshot a short content hash (or the
raw text) of a small window (say ±3 lines) around each cited line, keyed to the
citation. On a later run, if the cited line's content hash no longer matches
the stored one, flag it regardless of whether the identifier still appears
somewhere nearby — a hash catches "the code moved" even when the drift is
small enough that the identifier is still technically in the ±18 window (as
several tonight were: `render.metal:927`/T27 was checked BY HAND because the
tool's window happened to still cover it, but plenty of the +4/+7/+20/+86/+124
drifts tonight would have silently stayed "in range" too, just landing on the
wrong nearby code). This turns the tool from "does this symbol still exist
somewhere near here" into "is this EXACT claim still true" — the actual
question every one of tonight's findings was really asking. Cheap to add: hash
the cited line + N lines of context at write time, store it next to the
citation (or in a sidecar index keyed by doc+line), diff on each run. First
false-positive risk: a comment-only edit near a citation (e.g. a typo fix)
would trip it even though the citation is still true — acceptable, since a
human/agent re-reads and clears it in seconds, versus the alternative tonight
of a wrong number sitting silent for hours.
