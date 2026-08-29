# 🕳️ THE BLACK HOLE LIBRARY

**Opened 2026-08-27 21:05:40** on his order: *"reevaluate our entire behaviour of the black
hole. research everything there is to know. i'm talking anything we know as a species about
bhs. you need to know about how light travels near it, how gravity changes, how a star turns
into it. create a dedicated folder within docs that is our personal library for all things
black holes… like our own little board. this is the only blocker in the project."* `[HIS WORDS]`

**This folder is the BOARD for the hole.** Everything we know, in one place, with sources.
`docs/BOARD_BLACKHOLE.md` stays the running list of open engine rows; **this is the knowledge.**

---

## 📌 THE VISUAL BIBLE — unchanged, still the verdict

| File | What it is |
|---|---|
| **`../reference/BH_REFERENCE_labeled.jpg`** | NASA/Goddard labelled render — **names every feature we owe** |
| **`../reference/BH_REFERENCE_optics.jpg`** | NASA/Goddard ray diagram — **why** each feature appears |
| **`../reference/BH_REFERENCE.md`** | the six features as separately checkable rows **R1–R6** |
| **`03_THE_REFERENCE_FRAMES.md`** | ⭐ NEW — the above **plus Gargantua** and the 2024 plunge, and what each one is evidence *of* |

⛔ **A row closes when the SCREEN moves toward those frames and he says so.** Not when it
compiles, not when the physics is defensible.

---

## 📚 THE SHELF

| # | File | Covers | State |
|---|---|---|---|
| **01** | `01_FORMATION_how_a_star_becomes_one.md` | ⭐ NEW — stellar collapse, the mass ladder, TOV, what actually falls in | written 2026-08-27 |
| **02** | `02_LIGHT_how_it_travels_near_one.md` | ⭐ NEW — the one card: geodesics, deflection, photon sphere, shadow, the ring stack, g, beaming | written 2026-08-27 |
| **03** | `03_THE_REFERENCE_FRAMES.md` | ⭐ NEW — the visual bible incl. Gargantua + NASA 2024 | written 2026-08-27 |
| **04** | `04_HOW_THE_REFERENCES_DO_IT.md` | ⭐ NEW — **how NASA and Interstellar actually do it**, mechanism by mechanism; where they AGREE (= the spec) and the 5 places they differ (= our only choices); which reference explains R2/R5/R6 | written 2026-08-29 |
| — | `../RESEARCH_2026-07-24_blackhole_sota.md` | metric, key radii, accretion, EHT, light, the render clock | existing, 2026-07-24 |
| — | `../RESEARCH_2026-07-24_interstellar_dngr.md` | **the Interstellar/Gargantua paper as an implementable spec** — Kerr ODEs, backward ray-trace, disk emitter, image orders | existing, 379 lines, the deepest thing we have |
| — | `../DESIGN_2026-07-24_metric_native_blackhole.md` | the metric-native design | existing |
| — | `../BOARD_BLACKHOLE.md` | the running engine board: target decomposed S1/S2/S3/T1/T2, inventory, 10 hard limits, dead roads | live |
| — | `../PLAN_2026-08-27_BH_AGAINST_THE_REFERENCE.md` | ⚠️ its §0 is SUPERSEDED — written before he killed both renderers | stale in part |

---

## 🔪 WHERE THE ENGINE ACTUALLY STANDS — 2026-08-27 21:05:40

**Both black-hole renderers were deleted today, on his order.** 852 deletions, commit `00741f2`.

| Killed | Why, in one line |
|---|---|
| **The lens** (~320 lines) | *"a black hole is not a lense."* A lens is a SURFACE that refracts; a hole has no surface. Ours was a forward per-sprite screen displacement, so it could only ever make as many images as we coded roots for — **two** — while the photon ring is the n→∞ stack. |
| **The ray-march** (~410 lines) | *"its the oranghe blob."* The geodesics were **not** the defect — backward geodesic integration is exactly what NASA does. The defect was **what it gathered**: emission summed from a 128³ density grid, nearest-sampled, with no temperature of its own. A fog integral over a box can only ever be a soft blob. |

### What survives and still works
- **The shadow, by absence.** The straight-line photon-capture cull at `render.metal:1029`, at the exact `b_c = 2.5980762 r_s`. It was gated OFF whenever the lens was imaging; with the lens gone it applies to every ray again. **The shadow never depended on the lens.**
- **The hole as a body.** `bhbody_fragment` — a depth-only capture sphere, zero colour. Makes the hole occlude as geometry rather than by a hand-written cull. He PASSED it 2026-08-14.
- **T2 time-dilation shear.** `render.metal:782-784`, `tDilate = sqrt(max(0.4, 1 − r_s/r))` on the spin angle. **His favourite thing** — *"beautiful time warpeyssss"*. It was removed once as a "correctness fix" and killed the effect on sight. 🚨 **Never remove it.**
- **The exact Schwarzschild deflection LUT** (`renderer.mm`) — real physics, 1024-point quadrature, genuinely log-divergent at the photon sphere. Kept: it is not the lens, it is a table.
- **`tools/bc_validate.cpp`** — an independent null-geodesic integrator that re-derives `b_c` from scratch. **It exists** (board row L9 saying it never did was wrong — that row searched `src/`). Runs offline, no build, no token.

### 🚨 What NOTHING now produces
**R2 the photon ring · R5 the far-side arch · R6 the underside arc.**
That is the honest consequence of killing both, and it is where the next architecture has to start.

---

## 🧭 THE ONE THING THIS LIBRARY EXISTS TO SETTLE

Every failed approach on this project failed the same way: **it asked a per-particle question.**
A sprite gets displaced; a grid cell gets averaged. But *"what colour is this pixel"* near a
black hole is a question about **one ray's entire history** — where it came from, how many
times it wound, what it hit. Ours is the only project I know of that has a genuine advantage
here and has never used it: **the emitting matter is real, simulated, and already on the GPU.**

Read `02_LIGHT` before proposing anything.

---

**Last Updated:** 2026-08-29 01:52:11 — added shelf 04.
