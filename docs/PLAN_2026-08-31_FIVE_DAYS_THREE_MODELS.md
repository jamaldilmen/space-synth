# THE 5-DAY PLAN — THREE MODELS, ONE SHOW · 2026-08-31 12:21:15

> **His order, 2026-08-31:** *"bh + the other fable stuff only handled by it. opus on the rest.
> sonnet on the most basic todos. give me the plan and check it against the live base and our board."*
> **His correction, same message:** *"the reason it does speed it up is cuz i keep hitting my limits
> lol. thats why we take pauses otherwise id just let sonnet agents at least run 24/7."*
> ⭐ **He is right and my earlier framing was wrong.** The pauses were LIMIT-driven, not build-token
> driven. The token only ever blocks BUILD and MEASURE — a small slice, not the bottleneck.

🚨 **COLOGNE IS 2026-09-05. FIVE WORKING DAYS: Aug 31 · Sep 1 · 2 · 3 · 4.**
⏰ **The +50% weekly Claude Code boost runs "through August 31, 2026" — TODAY IS THE LAST DAY.**
Extended three times, never made permanent. If it lapses, weekly capacity drops ~⅓ for Sep 1–4.
**Front-load the expensive work into today.**

---

## 0. THE TWO REAL CONSTRAINTS

| constraint | what it blocks | what it does NOT block |
|---|---|---|
| **Usage limits** (the actual bottleneck) | everything, when hit | — |
| **ONE LIVE APP / build token** | BUILD, MEASURE, VISUAL VERDICT — strictly serial | every read-only lane below |

⚖️ **Fable is capped at 50% of weekly limits on Max, burns limits FASTER than other models, and has
NO automatic fallback** — when the slice is gone you switch by hand or buy credits. So Fable is
rationed here on purpose. It is not the default.

🔴 **BLOCKED ON HIM, not on any model:** the charger (the frustum-cost measurement refuses to run on
battery), the spin/rebirth verdicts, and the venue's two unanswered questions (**60 fps? external SSD?**).

---

## 1. 🟣 FABLE — his order: BH + the genuinely hard. NOTHING ELSE.

Long-horizon, architectural, one-shot quality matters, and a wrong answer costs days.

| # | Task | Board row | Verified state 2026-08-31 12:21:15 |
|---|---|---|---|
| **F1** | **The BH renderer.** Per-pixel backward geodesics that TERMINATE ON REAL PARTICLES — never a grid fog integral. | `BOARD_BLACKHOLE` §U, §X | ✅ **Confirmed: both renderers DELETED** 2026-08-27 `00741f2`. `bhmarch_fragment` exists only in comments (`render.metal:908,:1047,:3031,:3079`). **Nothing makes the photon ring, far-side arch or underside arc.** |
| **F2** | **The sampling architecture — "how does NASA do this?"** Neighbour finding without a fixed per-cell sample. | `BOARD` §Y1/§Y2.1 | ✅ Confirmed in source: `spatial_hash.metal:352` `if (currentOffset < 32)`; `min(cellCounts[...], 32u)` at `:391,:669,:714,:823,:920` and `particles.metal:3654,:3711,:4102`. Peak cell **334,576**. |
| **F3** | **The merger visual.** Three physically different cases drawn identically today. | `BOARD_BLACKHOLE` MERGER-FACE | ⬜ Science sketched (red nova / TDE t^−5/3 / ringdown), **nothing built**. 🚨 **BH–BH is his money shot and is not started.** |

⛔ **DO NOT spend Fable on:** doc work, citation sweeps, log parsing, re-stamps, build babysitting.
⛔ **F2 is research-first.** It is the one question he explicitly carried into this window.

---

## 2. 🟠 OPUS — everything else that changes code

| # | Task | Why Opus, not Fable | Verified state 2026-08-31 12:21:15 |
|---|---|---|---|
| **O1** | 🚨 **THREE OFF-AXIS FRUSTUMS — the show-critical build.** | ⭐ **De-risked out of Fable tier today:** the math is proven, so this is careful implementation, not architectural unknown. | ✅ `tools/frustum_validate.cpp` — **24/24 pass.** Symmetric case reduces to the shipped `perspectiveMatrix` with delta **0.000e+00**; seam `ndc.y` agrees to **1e-9** across walls at 7.375 m vs 5.005 m. Coverage **291.67°** (computed, not the old "~270"). ⛔ Today: ONE camera, ONE projection (`main.cpp:934/937`), ONE Syphon server `"Main"` (`renderer.mm:471`). |
| **O2** | **The frustum COST measurement** → decides whether O1 ships at all. | Needs judgement on a noisy signal. | ✅ Harness written, `tools/measure_frustum_cost.sh`, uses the EXISTING `SS_NO_STARPASS` gate (`renderer.mm:4206`) + `[PROFILE/120f]`. 🔴 **REFUSES TO RUN — on battery.** Fill is **33.00 MP** (5.56× his panel), **2.39× more than the 13.8 MP the plan assumed.** |
| **O3** | **Transport off Syphon** — his *"syphon is ass"*. NDI or SDI (DeckLink/Thunderbolt). | Bounded, but it is output plumbing for a live show. | 📄 `DESIGN_2026-08-31_HOW_THE_INDUSTRY_RENDERS_THIS.md`. ⛔ RenderStream is **Windows-only** — dead for us. ⭐ **Do O1 first: a cable change fixes nothing while we cannot make three correct images.** |
| **O4** | **TRUEFX T4 (ladder LPF = opacity), T1 (reverb = fluidity)** | His show brief; one effect, two outputs. | T1 visual half exists (`trailDecay`); audio half does not. T4 not started. |
| **O5** | **R1 camera rides A→B** | Half done already. | ✅ Verified: `camera.h:154` `setCinematic`, critical damping at `:162`. **Smoothness is DONE** (his *"i love the feel the snappiness"*). **Only the automated A→B ride is missing.** |
| **O6** | **Clock residuals** — 0.69% sequencer drift; `u.frameCounter` seeds RNG per FRAME | Small, off the shipped path. | `BOARD` §Y2.2/.3. ⚠️ `PhysicsUniforms` has **no static_asserts** — do not reshape it casually. |

---

## 3. 🟢 SONNET — run these continuously, they never touch the bundle

🚨 **REPORT-ONLY as of 2026-08-31 12:47:43.** Sonnet writes findings into its own `docs/SWEEP_2026-08-31_*.md` with exact `file:line` + exact replacement text; **OPUS or BRAIN applies them.** It edits no pre-existing doc.

⭐ **This is the lane his correction unlocks: *"id just let sonnet agents at least run 24/7."***
Every row here is read-only or doc-only. **None of them needs the app, the build token, or him.**

| # | Task | Size | Verified state 2026-08-31 12:21:15 |
|---|---|---|---|
| ~~**S1**~~ | ⛔ **MOVED TO OPUS as O0, his order 2026-08-31 12:47:43** — *"if something is in the way of the entire thing working... not sonnet should take care of it but opus."* It gates correctness for all four windows. | — | ✅ `tools/verify_citations.py` — **402 cites, 0 DEAD, 129 anchor-miss.** Hand-checked 6/6 stale, so the rate is real. |
| **S2** | **Stale-row sweep.** Rows whose claim outlived the code. | medium | 🚩 **Two already caught today:** **U1** says E5 is *"built, uncommitted"* — `src/ui/` is **CLEAN**, so the uncommitted half is FALSE. **U5** says indigo = orphan bundle; `ui_theme.h:48` has indigo in the LIVE theme. Both need settling or deleting. |
| **S3** | **The 8 dead UI panels.** All stamped *"removed 2026-06-26"*. Inventory + one decision each. | small | ✅ Verified: `main.cpp:1427,:1866,:1876,:1929,:2031,:2157,:2206,:2282`. |
| **S4** | **Board hygiene** — countdown, stamps, superseded numbers. | ongoing | ⚠️ Three stale numbers already corrected today (160 m²→138.25, ~270°→291.67°, 13.8 MP→33.0 MP). **Assume more.** |
| **S5** | **Log collation** for O2 once it runs. | small | `[PROFILE/120f]` + `[PERF]` parsing. |

⛔ **Sonnet must NEVER:** build, launch the app, run a measurement, or edit `PhysicsUniforms` /
`PostFXUniforms` (both are hand-synced, and `PostFXUniforms` is 4 bytes out of sync already).

---

## 4. THE ORDER, IF NOTHING CHANGES

1. **TODAY (boost expires):** OPUS starts **O0** (the anchor-misses) immediately — it needs no hardware. He plugs in → OPUS drops O0 → **O2** runs → its number decides **O1** → O0 resumes in the gaps.
2. **O1** the moment O2 says it fits. It is the only thing that can break the show.
3. **F1/F3** in whatever Fable slice remains — the BH and the merger are what he actually wants to look at.
4. **O3** last. A cable is worthless before three correct images exist.
5. **F2** is the long game and does not belong in these five days unless O1 lands early.

---

## 5. WHAT I WILL NOT PRETEND
- **Sonification (A1) is ZERO lines** — `grep -rl "sonif\|perParticleVoice\|fieldVoice" src/` returns nothing. **Not a 5-day item.** Design only.
- **F2 will not be solved this week.** It is architectural and it invalidates old measurements; it does not block the show.
- **O1 may not fit in budget.** That is what O2 is for, and the honest answer might be a lower particle count on the side walls.
