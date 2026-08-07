# HANDOFF — UI TRACK, RUNNING IN PARALLEL WITH THE PHYSICS WINDOW

**Written:** 2026-07-29 15:58:04
**Written by:** the physics window, for the UI window.
**Baseline commit:** `b047744` + uncommitted work from both tracks.
**Purpose:** let the UI track run at the same time as the Chladni/grid work without the two
windows stepping on each other.

**Cold start order for the UI window:**
1. this file (§1 is the only part that is urgent)
2. `docs/HANDOFF_2026-07-29_nasa_ui_design.md` — the UI track's own state, still accurate
3. `docs/RESEARCH_2026-07-28_nasa_ui_design_suite.md` — the reference

---

## 0. THE ANSWER TO "IS IT EASY, WE'RE NOT TOUCHING THE SAME THINGS"

**Source files: yes, effectively disjoint. Measured, 2026-07-29 15:58:04.**

**The build is NOT disjoint, and that is the whole risk.** One `package_macos.sh`, one
`SpaceSynth.app`, one `pkill`. Two windows building or launching at once produce a binary
neither of them can reason about — which has already happened once today (§3).

So: work freely in parallel. **Coordinate on the build only.**

---

## 1. 🚦 THE SHARED-RESOURCE PROTOCOL — the only hard rule

| resource | shared? | rule |
|---|---|---|
| `bash package_macos.sh` | **YES — one bundle** | **Ask Jamal before building. Never build because a change "is ready".** |
| `pkill -x SpaceSynth` | **YES — kills the other window's app** | **Never.** Ask him to close it, or leave it running. |
| `open -n SpaceSynth.app` | **YES** | Only right after a build he approved. |
| `git checkout <file>` / `git stash` | **YES — file granularity** | **Never on a file the other track has changed.** See §2. |
| `git commit` | **YES** | Only on his explicit order (`feedback_commit_only_on_explicit_order`), and name the files. |
| source edits in your own files | no | free |

**Why this is rule #1:** `git status` currently shows **586 uncommitted insertions across 6
files** from the physics/star tracks. A `git checkout src/main.cpp` from the UI window
destroys 74 lines of another session's unverified work with no warning and no undo.

**The narration rule applies to both windows** (`feedback_report_before_acting`, reinforced
in the NASA handoff §7.1): announce → **end the turn** → wait. Writing "announcing before I
act" and then acting in the same turn is not a checkpoint. The physics window did this twice
today before catching it.

---

## 2. THE MEASURED OVERLAP

`git diff --stat -- src/`, 2026-07-29 15:58:04:

| file | uncommitted | owner |
|---|---|---|
| `src/render/particles.metal` | 162 | **physics** |
| `src/render/render.metal` | 263 | **stars** (parallel) |
| `src/render/renderer.mm` | 87 | **physics/stars** |
| `src/main.cpp` | 74 | **stars** |
| `src/render/renderer.h` | 26 | stars |
| `src/core/app_state.h` | 30 | stars |
| `src/ui/ui_theme.h` | **0 — clean** | **UI (yours, uncontested)** |

### `src/main.cpp` is the one shared file — but the regions are disjoint

Verified with `git diff -U0`:

| region | lines | track |
|---|---|---|
| star dials | **1490–1553** | physics/stars |
| (second hunk) | **2092–2101** | physics/stars |
| `##topbar` | 841 | **UI** |
| `ProgressBar` call sites | 969, 1167, 1666, 2018 | **UI** |

**No collision.** Both tracks can edit `main.cpp` at the same time.

⚠️ **But line numbers drift.** Any UI edit above line 1490 shifts the physics hunks, and vice
versa. **Anchor on symbols, not line numbers** — grep `##topbar`, `ProgressBar(`,
`ApplyPremiumTheme` — and treat every line number in every handoff (including this one) as a
hint that needs re-grepping.

### Read-only crossings are safe, with one caveat
The accent derivation (NASA handoff §6) needs the blackbody→RGB implementation in
`src/render/render.metal`. **Reading it is fine.** Know that it has **263 uncommitted lines**
of star-dial work in it right now, so what you read is mid-flight, not `b047744`. The Planck
locus itself is a law and is not affected by that work.

---

## 3. ✅ RESOLVED — the stale-bundle trap from the NASA handoff §0

That handoff flagged: `SpaceSynth.app/Contents/MacOS/SpaceSynth` built **15:04:41** contained
the reverted B1 accent change (indigo hover states) while the source did not.

**Cleared.** The physics window rebuilt at **2026-07-29 15:05:37** — verified newer than all
sources, metallib byte-identical to the fresh build. The orphaned B1 binary is gone.

⚠️ **This is exactly the accident §1 exists to prevent.** That rebuild was for a physics
change; it silently overwrote another track's binary. It happened to be the desired outcome.
Next time it won't be.

Also worth knowing, because it cost the physics window a diagnosis: the first
`package_macos.sh` run **failed at the `strip` step** (`can't move temporary file ... (No such
file or directory)`) and the script exits there, **before** the metallib/presets/fonts copies
on lines 28–39. It succeeded after `rm -f` on the bundle binary. If you ever build: read the
script's output to the end, and check bundle timestamps ≥ source.

---

## 4. WHAT THE PHYSICS WINDOW IS DOING NEXT — so you can predict the collisions

Jamal's report today: *"shape resolution. its blurry not sharp... its also in perpetual motion
which by itself is nice and contradicts the hardening... we need them sharper than we had it
not coarser."* And his steer: *"somethings not aligning with the grid AS ALWAYS."*

**He was right, and it has a number.** `renderer.mm:1908` — `su.halfExtent = 64.0f`,
unconditional → `cellSize = 2·64/128 = 1.0 sim`. The Chladni cavity is `EIGEN_R = 3.0`,
`EIGEN_L = 6.0`, so **the whole pattern spans 6 grid cells.** Before 2026-07-18 that line was
`tubePhase ? 3.0 : 64.0` — play ran at ±3, `cellSize 0.047`, 128 cells across the cavity.
The ±64 unification fixed a real bug (the release re-grid = his *"gridy squarish shapes"*) by
**taking the coarse side for both regimes**: a 21× linear resolution loss, dated one day
before eigenmode-only became the default.

Two grid-mediated smears follow:
- **SPH smoothing length `h = cellSize = 1.0`** (`renderer.mm:2250`) = ⅓ the cavity radius.
- **Crystallization hardness reads `cellCounts`** on the same coarse grid
  (`particles.metal:2463`), so hardening has no sharp density signal to lock onto.

**Planned next change (not started, awaiting his go):** point the SPH smoothing length — and
later the hardness density — at the **AMR fine box that already runs** (±4, cell 0.0625,
default ON, verified `renderer.mm:1843`), keeping ONE ±64 domain so nothing re-grids at
release. **SPH `h` alone first**, so the verdict is attributable.

**Files that change:** `src/render/renderer.mm`, `src/render/particles.metal`. **Not `src/ui/`,
not the HUD regions of `main.cpp`.** No conflict with anything in §5.

---

## 5. UI TRACK — RECOMMENDED ORDER, revised for parallel running

The NASA handoff §8 order still stands. Re-ordered here by **conflict risk**, lowest first.

### A1 — `THIRD_PARTY_LICENSES.md` ← START HERE
Dear ImGui (MIT), Roboto + Cousine (Apache 2.0), Syphon. **New file, zero pixels, zero build,
zero conflict, no verdict needed.** Owed regardless of whether the UI track proceeds
(`third_party/imgui/misc/fonts/` ships `.ttf` files without upstream's licence text, verified
2026-07-28). **The only item here that is safe to just do.**

### §6 — DERIVE THE ACCENT before re-landing B1
Jamal's call, and the NASA handoff §6 already argues it: *"we have all the answers to that in
the code u dont need to see whats on screen its all science bro"*. Read the blackbody→RGB
implementation in `render.metal`, compute the Planck locus, pick the accent from what is
**provably unoccupied** — green and violet, which blackbody never produces.

**Analysis only. No edit, no build.** Output is a derivation Jamal can read. This is what makes
B1's indigo *earned* instead of inherited, and it satisfies his test: *for every number on
screen, name why it is that number.*

### B1 — accent-alpha interaction states, re-land with the derived hue
Written and fully reverted once, **never evaluated**. Five states in `ui_theme.h`, alphas
byte-identical so only hue varies → any verdict is attributable. `ui_theme.h` is **clean and
uncontested**, so this is a single-file change in a file no other track touches.
**Needs a build → §1 applies → ask him.**

### B3 / C1 / C2 — after B1 has a verdict
ProgressBar heights (4 values: 14/12/10/0) unified to one derived number; `Cousine-Regular.ttf`
as the numeric font; Appendix F number/time formatting. **These touch the HUD regions of
`main.cpp`** — disjoint from the physics hunks per §2, but re-grep the anchors first.

### D1 — left rail: still parked
Layout change. Gated behind B and C by the MEDS rule (*never change layout and visual language
in the same build*).

---

## 6. THE ETHIC — unchanged, and it outranks everything above

> *"i really really really want to prevent u from creating something that looks like AI. the ui
> design to me is the ethically most critical part. cause its art. and i hate the idea of
> stealing art to make my own. BUT I LOVE SAMPLING. and even more .. flipping samples. SO THIS
> IS OUR APPROACH HERE. A GRATEFUL NOD TO THE GREATS."*

**The test:** for every number on screen, name why it is that number. Derived from a stated
rule → keep. Derived from our own material → keep. *"It looked good"* → **delete it.**

**Flipping** = take the method, re-derive against our physics. **If we land on Open MCT's exact
hex, we did it wrong.**

⚠️ The known AI-looking artifact is named: `src/ui/ui_theme.h`, `ApplyPremiumTheme`, comments
reading *"Ultra-Premium Design Colors"* / *"Deep frosted glass"*, 14px window rounding,
white-alpha every state. **That is the thing to flip.**

---

## 7. OPEN DECISIONS FOR JAMAL (unchanged from the NASA handoff §8)

1. Re-land B1 as-is, or derive the accent first so the first visible change is already earned?
   *(This doc recommends: derive first. It costs one analysis turn and no build.)*
2. Colophon crediting NASA Appendix F / Open MCT / Danne & Blackburn — in-app, or repo-only?

---

**Last Updated:** 2026-07-29 15:58:04
**NEXT for the UI window:** §5 A1 (licences, no build, no verdict), then §6 accent derivation.
**NEXT for the physics window:** SPH smoothing length → AMR fine cell. Awaiting his go.
