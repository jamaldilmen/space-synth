# SPACE SYNTH — handoff 2026-09-01 13:28:00 — **THE DISK IS THE SUBJECT**

> 🚨 **THE ONE THING TO KNOW:** his reference image has a **BLACK BACKGROUND**. We are not lensing a
> backdrop — **the thing being lensed IS THE ACCRETION DISK.** Of the six features in that image we ship
> exactly one (the shadow), and the other five all require a disk that **does not exist as a held state.**
> **Cold start:** `docs/BOARD_BLACKHOLE.md` **§Z12b, §Z12c, §Z14, §Z15** — in that order.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` @ `true-physics`
**Build:** `bash package_macos.sh` — never bare `make`. Launch `--env SS_FULLSCREEN=1`, always.
**Build token:** **FABLE**, on his order 2026-08-31 23:21. OPUS stood down 23:22.
📅 **COLOGNE 2026-09-05 — 4 DAYS.** Partly or wholly PRE-RECORDED, his call.

---

## 1. 🎯 HIS DIRECTION, AND IT CHANGED TWICE IN ONE NIGHT

| when | his words | what it killed |
|---|---|---|
| 22:29 | *"STOP everythign here these past 5 hours was ass. the neitre day burned."* | **The lens COST track. Four instruments, four void results.** Dead, do not restart. |
| 23:21 | *"build the black hole renderrer. we need to try it to see it. LET FABLE DO IT"* | Moved the build token to FABLE. |
| 01:26 | *"even the firts version of th ebh lense we had mooooonths ago looked better than this"* | **The v4 lens transport.** ✅ Only credit: *"i mean it kidna does warp chill.. it deos"* |
| 01:33 | *"do u see it. do you see the black background... its not that tehres nothing behind the bh ok"* | 🚨 **MY WHOLE DIAGNOSIS.** See §5. |
| 01:37 | *"fable designs the disk. matter forms it, holds it, orbits"* | The current task. **Design done, UNRULED.** |

## 2. 🔴 THE ONE DECISION EVERYTHING WAITS ON

⛔ **NOTHING SHOULD BE BUILT UNTIL THE PLANE IS SETTLED.** `[BOARD_BLACKHOLE §Z14]`

**The physics and the renderer orbit on different axes, and it is a whole-file split, not one site:**

| file | axis | sites |
|---|---|---|
| `particles.metal` — **PHYSICS** | **+Y** (XZ plane) | `:2380`, `:1210`, `:2371`, `:3290` |
| `render.metal` — **RENDERER** | **+Z** (XY plane) | `:1445`, `:3203`, `:761` |
| the march | **`poseAxis()`** — a THIRD convention | defined `render.metal:570`, stated at `:755-762` |

🚨 **WHY IT DECIDES THE PICTURE:** circularization settles matter into a disk in the **XZ** plane. The Kerr Ω
Doppler (`render.metal:1428`) uses the **XY** tangent. **Doppler beaming is the ONE reference feature we
already own** — applied 90° off the real motion it does not merely fail, **it makes real physics look fake.**
⭐ **4th sighting of the plane trap**, and the only one spanning whole files. `[[space_synth_plane_bug_makes_real_physics_look_fake]]`

✅ **HOW TO SETTLE IT — FABLE's protocol, and it needs NO BUILD:** a source read **cannot** settle it (the
comments disagree — that IS the finding). It needs a **run + measured screen evidence on the current
binary**: run at rest until a hole forms and the core settles → screenshot → measure the settled disc's
plane by raw RGB histogram by axis and radius → note which limb the beaming brightens. **The convention that
matches the VISIBLE orbital motion wins.** ⭐ **A window WITHOUT the build token can do this**, or he can.
⛔ It cannot be done from a chair with `grep`.

## 3. ⚖️ HIS FIVE DECISIONS — `docs/DESIGN_BH_2026-09-01_DISK_STATE.md`

| # | Decision | yes / no |
|---|---|---|
| 1 | **Disk-capture radius law** | FABLE recommends the **relaxation-bind radius** — self-consistent entry, no new tuned constant. A fixed `r_s` multiple or the tidal radius is one line either way; it moves where the ring's outer edge sits. |
| 2 | **Silence lifetime / `SS_ALPHA`** | The thin-disc default puts field lifetime at **~3.7 h**; keeping today's ~4 min means fattening α. ⭐ **This IS his open rest-rate verdict from §Z8, now with ONE honest physical dial and no cap.** |
| 3 | **In-disk star-star merging** | **OFF** (FABLE's rec) = a stable shining queue. ON = occasional bright events, but re-opens the runaway class the viscous budget exists to prevent. |
| 4 | **PLANE VERIFICATION FIRST** | ⛔ **Gates 1, 2, 3 and 5.** See §2. |
| 5 | **Disk-state cooling rate** | 🚨 **The ONE piece of new physics in the design** — everything else stages existing machinery. Sets how fast the torus visibly flattens into the thin ring. **FABLE has NO measured basis for its value and says so** (§4 of the design). |

## 4. ✅ WHAT LANDED — verified, not reported

| # | Thing | Proof |
|---|---|---|
| 1 | 🚨 **THE TRUE CLOCK WAS CAPPED AT ONE STEP.** `sMaxSteps` default **1 → 4** (`renderer.mm:1760`). Below 60.61 fps the sim ran at `fps/60.6` of real time. | `[MEASURED]` realtime **0.32× → 0.946×**. ⭐ BRAIN re-derived it independently: 778 × 0.0165 = 12.84 sim-s over 13.56 wall-s = **0.947**. His *"this is huge on the board"*. `BOARD.md` §Z1 |
| 2 | **Four dead UI dials DELETED** — `tuneLens`, `tuneArcWrap`, `tuneArcGain`, `tuneTrailGain`: written every frame, tooltipped, **read by no shader.** His 08-27 law. | `sizeof(CameraUniforms)` **288 → 272**, static_asserts in BOTH structs, build clean. `tuneStreakLen` (1 real read) kept |
| 3 | **B2b landed** — all 5 ray classes fire, `pFarOut` nonzero = T4-in-debug | FABLE, verified |
| 4 | 🐛 **Per-frame counters were accumulating across frames** — a CPU clear raced the previous frame's still-executing buffer | ⭐ **General rule: clear on the GPU, in the buffer that consumes it.** `BOARD_BLACKHOLE` §Z10 |
| 5 | **The cold start was lying** — `TODO.md` named commit `0cf85b4` (08-23) and a bundle from **`killtube`, a tree dead since 08-27.** 8 days stale on the first file every window opens | Fixed, plus the fork where two docs both claimed to be the entry point |
| 6 | **29 citations corrected across the boards** | See §6 |

## 5. ↩️ RETRACTED — and the shape is the same one as last session

| Claim | Why it was wrong |
|---|---|
| 🚨 **"The field gets eaten so the lens has nothing to bend" (the §Z12 "triple bind")** | **HIS CORRECTION.** The reference has a **BLACK BACKGROUND.** I diagnosed a missing backdrop when the subject of the lensing is **the disk itself**. All three legs were individually true and **jointly beside the point.** ⛔ This also retired B3's *"additive far-side STARLIGHT"* survivor cut — the far-side image is the far side of **the disk**, not stars. |
| **"Nothing has moved in `src/**` since 01:22:26"** — said to SONNET | **FALSE, and SONNET caught it by re-verifying instead of trusting me.** Its last check was 23:20; `render.metal` (01:21:35) and `renderer.mm` (01:22:23) both moved AFTER. Batch 2 did **not** hold. |
| **"SONNET's batch 2 is unreliable"** — my first read of 8/8 mismatches | **WRONG.** The offset was **uniformly +4** — a tree edit, not sloppy work. ⭐ Had it been 3 findings not 8 I would have discarded good work. |

⭐ **THE COMMON SHAPE, third session running: a result that AGREED with what I already believed, mistaken
for one I had CONFIRMED.** ⛔ **Every correction above came from OUTSIDE the belief** — twice from him, once
from SONNET refusing to accept my premise. That is the argument for the multi-window split, not against it.

## 6. 🧾 THE CITATION ROT — 29 applied, **27 STILL UNAPPLIED**

🚨 **`docs/SWEEP_2026-08-31b_CITATIONS.md` (49 KB) HOLDS 27 LIVE, UNAPPLIED CORRECTIONS.** It is committed
as of this handoff — **before that it was untracked and a `git clean` would have destroyed it.**

| batch | state |
|---|---|
| Batch 1 (F1–F10) | ✅ **APPLIED** |
| Batch 2 re-verified 13:24 (T1–T13) | ✅ **APPLIED 13:28** — BRAIN re-grepped all 13 first; all 13 held |
| T14–T22 (render.metal sample) | 🔴 **UNAPPLIED, two tree-moves stale — DO NOT TRUST AS PRINTED** |
| T24–T29 (batch 3) | 🔴 **UNAPPLIED, same caveat** |
| "everything else" tier | ⬜ never swept: `main.cpp`, `particles.metal`, `postfx.metal` |

⛔ **T19/T22 IS NOT A CITATION FIX — IT IS A FALSE CLAIM.** `BOARD.md` **C4b** argues from `bhmarch_fragment`
(cited `render.metal:3342`) as a live function. **It was deleted 2026-08-27 (`00741f2`); the marker is
`render.metal:3114`.** So C4b's count is wrong — **TWO** live passes, not three. Row **P1** asserts *"the
2026-07-24 metric march is live"* — **false by the same deletion.** Both now carry re-scope banners; **neither
is fixed.**

### 🚨 THE PROCESS FINDING, and it is worth more than the 29 fixes
**A citation sweep has the SAME staleness problem as the thing it sweeps.** Three windows on one tree means
every sweep measures a moving target. Batch 2 went stale **twice in one night** — first uniformly (+4), then
**NON-UNIFORMLY** (+7/+20 in `render.metal`, +50/+86/+124 in `renderer.mm`).
⛔ **NEVER APPLY A WRITTEN LINE NUMBER BY ARITHMETIC. RE-GREP EVERY SYMBOL AT APPLY TIME.** A uniform offset
once is luck, not a rule.
⚠️ **`rDil` IS NO LONGER A UNIQUE SYMBOL** — a second unrelated local exists at `render.metal:3246`.
⭐ **WHY THE TOOL MISSES ALL OF THIS:** `verify_citations.py` reports DEAD only past end-of-file. **Every
rotted cite resolved to a real line.** SONNET's fix, recorded not built: **anchor on a content hash of the
±3-line window**, not an identifier within ±18 lines.

## 7. ⛔ DEAD ROADS FROM THIS SESSION

- **The lens COST track — four instruments, four void.** #4 (stage-boundary GPU counters) was the first to
  carry an **internal control that could falsify it in one run**: 1,518 post-warm-up frames with `steps=0`
  read **18.48 ms** against **12.92 ms** for frames doing **6,785× the work**. `corr(enc_ms, steps) = +0.018`.
  ⭐ **The common cause is structural: every one timed a span of wall-clock while the GPU was shared.**
  ⛔ **A fifth bracket is not the move.**
- **A 4.0× GPU clock warm-up ramp is REAL** (9.65 → 4.26 → 2.65 → steady 2.41 at constant work, 40 runs).
  It is a second candidate cause for §Z7's negative slope, never separated from occupancy.
- **B3's four cuts** — repaint-with-suppression, repaint-from-fates, far-side thick-cell emission
  (**WHITE CUBES**, cube-watch fired as written), v4 replace-composite. ⭐ **All four died on ONE axis:
  screen-space compositing reads as an OVERLAY against a 3D point cloud.** One property, not four bugs.
- ⚖️ **UNRULED, HIS CALL:** FABLE proposes **geodesic-derived per-sprite displacement** — real α(b) from the
  validated marcher moving sprites in world space. 🚨 **There is a standing in-source prohibition**
  (`render.metal:1090`): *"DO NOT REBUILD THIS... The forward sprite displacement does not come back."*
  The banner's objection was that it was **not real physics**; the proposal keeps the **form** and replaces
  the fake. **Whether that counts as the banned thing returning is HIS ruling and nobody builds it first.**

## 8. 📌 STILL OPEN, NOT STARTED

- 🔴 **S6 — NO CAPTURE PATH EXISTS.** `grep` for ProRes/AVAssetWriter/recordFrame → **zero**. **Cologne is
  pre-recorded and there is nothing to record with.** Small, well-understood, no research risk. **Single
  point of failure for the show.**
- 🔴 **O1 — three off-axis frustums.** One camera cannot render 270°. Fill **33.00 MP**, 5.56× his panel.
- 🟡 **OPUS's lane, confirmed and unstarted:** 3 `tuneArcWrap` comments describing a deleted uniform
  (~`:527`, `:2724`, `:2750`); its own `:5165` comment citing `:1907` for `bhLensActive` — ⚠️ **now at
  `renderer.mm:2039`**, it moved 1907→1957→2039 in one night; 3 origin-lock cites in `render.metal` comments;
  `particles.metal:2198` citing `renderer.mm:1949` (real marker `:2293`). **Citations rot inside SOURCE
  COMMENTS and nothing sweeps those.**
- 🟡 **`PhysicsUniforms` has ZERO static_asserts** — ~40 hand-synced fields; add one scalar and ~38 shift,
  **and it still compiles and still runs.** ⛔ Blocks the per-step-uniforms fix for the `frameCounter` RNG
  repeat (`BOARD.md` §Z3 item 1). **Guard it FIRST.**
- **Env dials, all documented in-source:** `SS_LENS_DEBUG` · `SS_LENS_RENDER` · `SS_LENS_HITR` ·
  `SS_LENS_EMIT` · `SS_LENS_BGEO` · `SS_LENS_PIN_RS` · `SS_MAX_STEPS`

## 9. 🔬 STATE AT HANDOFF

- ✅ **Everything committed on his order 13:28.** 🚨 **CORRECTION TO A STANDING RULE — THE COMPILED BINARY IS NO LONGER TRACKED.** It was untracked and gitignored **2026-08-31, commit `0c51e58`** (*"build: untrack the compiled binary, ignore it and python bytecode"*); the rule is now at `.gitignore:36` with its reasoning inline. ⛔ **The old "the compiled binary is TRACKED in git" warning — repeated in memory, in `HANDOFF_2026-08-31_FOUR_WINDOWS.md` §1 rule 2, and by me all session — IS STALE.** `*.metallib` is ignored too (`.gitignore:6`). ⚠️ **The rest of `SpaceSynth.app` STAYS tracked** — `Info.plist`, the font and the preset are inputs, and `Contents/Frameworks/Syphon.framework` may be the repo's only copy of Syphon (`third_party/syphon/` is ignored). **Do not extend the rule to the .app as a whole.** ⭐ **The v4 lens is
  `SS_LENS_RENDER`-gated OFF by default: the shipping path is byte-identical.** ⛔ Reverting the lens files
  wholesale would also revert **B2b's verified instrument** and **four in-source dead-road banners** — which
  exist precisely so nobody re-walks them. **Do not.**
- **Bundle `2026-09-01 01:22:26`** = the **v4 build he REJECTED**. The clock fix (00:48:25) is in it.
- ⚠️ **`renderer.mm`, `render.metal`, `renderer.h` are the drift-prone files.** Anything citing them from
  before 01:22:26 is suspect.

**Last Updated:** 2026-09-01 13:28:00
