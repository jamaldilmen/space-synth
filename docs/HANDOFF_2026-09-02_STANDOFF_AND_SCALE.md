# SPACE SYNTH — handoff 2026-09-02 19:52:00 (BRAIN)

> **His verdict on this state:** on the thinning + dynfric pair, eyes on the built bundle 17:0x — *"i could cry. its so good. its looking real. matetr actually behaves arpound the bh as it should its lokey frozen and turns into strails.. amazing amazing commit this rn"*. On the lens, 17:28 — *"the lense is like locked to the cente and it doesnt really bend anything its just a mseary circle lol"*. On the scale question, 19:1x — *"all of these vbalues need to be unified do u udnerstand its not a guess. the answer should be cleear."*
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` §AB — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `2a0d804`
**Build + launch:** `bash package_macos.sh` then `pkill -x SpaceSynth; SS_FULLSCREEN=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth`

> 🪟 **FOUR WINDOWS.** BRAIN routed; OPUS traced the stand-off; FABLE owns the lens; SONNET on the MIDI parser. Allocation is HIS (handoff `HANDOFF_2026-09-02_RING_SNAP_TIMELAPSE.md` §6). FABLE's three lens commits are NOT boarded — FABLE's rows to write.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | Chladni figure churns at the play speed cap | whole field at \|d\|=1.1969/frame, freeze overpowered | cap ramps out past the figure's edge, falls back to c | `particles.metal:377-378`, cap site `:3295-3304` (`5d98b7f`) | `[MEASURED]` field median r=24.5 ⇒ gate 0.639 predicted, \|d\| ratio **0.656** observed (0.785 vs 1.1969) |
| 2 | Merged bodies frozen in place, BH stalls | drag read the body's OWN mass as background; coef ∝ M², **9-12 orders over its 0.1 cap** | body cannot drag against itself | `particles.metal` dynfric block (`66faa37`) | `[MEASURED]` `[DENSPROBE]` TOP CELL held `(69,63,62)` for **70 consecutive prints ≥70 s** vs 36 sim of predicted travel · `[HIS WORDS 17:0x]` *"the smalel rbodies started moving again"* |
| 3 | Field eaten to 24% by t=300 | fast-collapse 1.92M→846k between t30 and t60 | field survives; that phase is GONE | `particles.metal:250` h/r 0.746→0.1 + `render.metal:2805` sync (`c30c3a8`) | `[MEASURED n=4 stacked, FABLE]` t=300 live **1.0-1.47M (50-74%)** vs n=1 baseline 488k (24%); ring band holds 1.15-1.46M |
| 4 | Which scale value is fabricated — unanswered | assumed the lens was at fault | **the lens is the honest half; `R_DISK` is the fabrication** | `units.h:39,:85` vs `particles.cpp:107` | `[READ]` its own comment: *"SIZED TO THE CAMERA"* · `[MEASURED]` kRs × M_field = **1.0011 sim** |
| 5 | Multi-window setup forgotten "for days" | no record | team + ownership boarded, memory pinned in HARD RULES | `HANDOFF_…RING_SNAP_TIMELAPSE.md` §6 (`8921b0a`) | `[HIS WORDS]` *"werte doing multi window and u keep forgetting it for days"* |

## 2. 🚨 OPEN — his list, verbatim

1. **"all of these vbalues need to be unified do u udnerstand its not a guess. the answer should be cleear."** (~19:1x)
   `MEASURE:` audit every placement constant against the derived anchor — `R_NUC=3`, `A_NUC=1` (`particles.cpp:105-106`), `STAR_MAP_CAP=100` (`particles.metal:336`), `R_ENC=0.5` (`renderer.mm:260`), lens `hitRadius 0.02`. Any chosen number in a physics slot is the same disease as `R_DISK`.
   State: `[MEASURED]` matter at **150 r_s**, region 20 r_s, bend **0.76°** — board §AB.8 carries the formula. FABLE shipped the lens half (`24c91ab`, influence law); **the `R_DISK` half is untouched** and BRAIN's flag stands: infl ≈ 20-40 does NOT close a 150 r_s gap alone.
2. **"mergers are too bright... they overshoot"** (~17:10) — and **"even at lumen ceiling 0 it looks like this"**, which refutes the obvious fix.
   `MEASURE:` find the remaining glow source. `[MEASURED]` the rail saturates at **5.54 M☉**; `[READ]` bit7 seed-blob is default OFF, `uiExposure` is a fixed manual iris at 1.0 — neither explains it. **UNFOUND.**
3. **"STAR CAPTURE MAIN ISSUE OVER EVERYTHING ... tackle that asap"** (~16:50) — OPUS owns it.
   `MEASURE:` `particles.metal:1588` `if (!reserved) continue;` is a SILENT refusal with no counter — `mrg=reached/landed/refused` covers only seed↔seed. Star capture has **never been measured at all**.
   State: his frame for it — *"theyre also alive during play. no excuses. wwe have 120 there too"* — same particle count renders at 120 in play, so the cost is what REST runs that play does not.
4. **"we need the outer wall to have some form of. dont have me stuck here situation"** — `[READ particles.metal:3479-3487]` `capR` is a hard wall: teleport onto the sphere + delete outward velocity. Its constant's comment says *"silence: NO cap"* (15th name-is-not-a-mechanism). His framing: nested spheres, the shell submits to what is inside.
5. **MIDI System-Real-Time 1-byte misparse** — SONNET owns it. **Cologne is 2026-09-05, three days.** Unverdicted.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **A "Merger Glow" fader — KILLED BY HIM 2026-09-02 ~17:2x.** Fully wired (6 sites, spare `horizonRPad2` slot, identity at 1.0) and reverted on his word: *"wellt hen fuck a fader and fix the math lol"*. A dial is not a fix for a broken law.
- **Flux-conserving star luminance — RETRACTED BY BRAIN BEFORE BUILDING.** Dividing luminance by sprite area is real physics, but it happens after `L·gain ≈ 7e9` against a ceiling of 1000 — the clip still bites and the merger does not move. Correct principle, zero effect here.
- **Lowering `Lum Ceiling` — REFUTED BY HIS EYES.** *"even at lumen ceiling 0 it looks like this"*. The rail is real; it is not the whole glow.
- **Camera position as the explanation for the missing lens — REJECTED BY HIM, twice, and he was right.** *"I PLAY THE ISNTRUMENT i spin it always. stop epxlaining this to me like im stupid."* The geometry claim (§AA3, beaming ≡ 0 on-axis) is still true and still irrelevant: the region mask discards his matter long before camera angle matters. **Do not raise camera position again unless he does.**
- **`R_DISK = 8` (2026-07-18) — reverted then, but its objection is now suspect.** It was killed by feeding the core faster; `c30c3a8` cut the eat rate ×55.7. Untested since. Do not re-reject it on the old note alone.

## 4. 🔬 PREFLIGHT (2026-09-02 19:44:17, before this session's commits)

```
1. git
  ok    branch true-physics, HEAD 1ff86d4
  FAIL  3 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M imgui.ini
           M src/render/render.metal
           M src/render/renderer.mm
  WARN  6 commit(s) not pushed
2. board vs HEAD
  FAIL  docs/BOARD_BLACKHOLE.md is 4 code commit(s) behind HEAD (verified at 4fd2b6f)
  WARN  docs/BOARD_BLACKHOLE.md is 189462B — split closed rows into BOARD_CLOSED.md
  WARN  docs/BOARD.md has no 'Commit at last verification: `<sha>`' line — add one
  WARN  docs/BOARD.md is 165275B — split closed rows into BOARD_CLOSED.md
3. deployed artifact
  FAIL  STALE: SpaceSynth predates src/render/render.metal — run the packaging script
  FAIL  STALE: default.metallib predates src/render/render.metal — run the packaging script
4. referenced paths (live docs only)
  ok    46 referenced path(s) in live docs all resolve
5. orbital-plane convention — READ THESE, do not skip
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere
```
Resolved after the run: the 3 uncommitted paths were FABLE's, committed by FABLE as `24c91ab`/`1ff86d4`/`2a0d804` while preflight was being read; board re-stamped `4fd2b6f` → `2a0d804` with §AB.8/§AB.9 folded in. ⚠️ **The artifact FAILs were real at 19:44 and FABLE rebuilt after** — re-verify timestamps before trusting any run. Board size WARNs remain, declared not fixed.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The one-way membrane is the ring-snap suspect" | `u.horizonR` never exceeded 0.045 sim in any logged run; rings sat at r 5-16, ~300× larger. Killed by OPUS. |
| "fps correlates with the ring snap" | Confounded — the real variable was whether the merge cascade had fired. |
| "`refused = 0`, nothing rejects anything" | True for seed↔seed ONLY. `particles.metal:1588` is a silent star-capture refusal counted nowhere. FABLE caught it. |
| "The field spreads out during the stall" | Mostly SELECTION: live fell 308,956→261,132 (−15.5%) while Mlive stayed flat. §AA6's own trap. |
| "Mass-proportional softening is the merger-gravity mechanism" | Does NOT bite — mass term 0.0073 vs `cellSoftFloor` 1.0 at 234,805 M☉; needs >3.2e7 M☉. Corrected by OPUS. |
| "Flux conservation will dim the mergers" | The clip bites first (L·gain ≈ 7e9 vs ceiling 1000). Retracted before building. |
| "Lower the Lum Ceiling" | Refuted by his eyes at minimum ceiling. |
| "It's a scale problem" (framing the lens as at fault) | Backwards, and he caught it: the lens is the derived half, `R_DISK` is the fabricated one. |
| "§6.4 is unbuilt in practice" | It shipped as `ba5265f` that morning and its instrument passed. Caught by FABLE. |
| Handing FABLE the token over OPUS's uncommitted work | Broke his rule before he had stated it. Nothing lost, and only because git refused the pop. |

---

**Last Updated:** 2026-09-02 19:52:00
**Folded into board:** `docs/BOARD_BLACKHOLE.md` §AB.8 + §AB.9 @ 2026-09-02 19:50:00, re-stamped `4fd2b6f` → `2a0d804`
