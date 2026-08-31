# STATUS — for Jamal
**2026-08-31 16:35:00** · one page · **COLOGNE IS IN 5 DAYS (2026-09-05)**

Previous stamp was 2026-08-30 23:51:49. Re-cut after the OPUS session of 2026-08-31.
🚨 **Three source changes are UNCOMMITTED and LIVE in the app you are playing.** Nobody commits without your order.

---

## 🆕 TODAY — 2026-08-31, OPUS window. Three changes, all built and running.

| # | What you asked for | State |
|---|---|---|
| **T1** | *"kill the cap. its so 2014. we can do it."* — the BH outcome cap | ✅ **DEAD.** Both call sites gone, both constants deleted. **Measured:** idle reached **Mmax 161,690 M☉** against the old 102,144 ceiling that used to stall dead at 99.66%. |
| **T2** | *"play is end of bh formed"* — the hole that would not shrink | ✅ **RATCHET DEAD.** The drawn hole was keyed to a running **max** of the seed mass, so it could never fall. Now keyed to the live mass. **You said: "looking good to me."** |
| **T4** | *"fix this freaking SHADOW the EGG"* — the hard egg-shaped edge over the disc | ✅ **GONE.** The second-image cull was testing a circle in NDC on a 3024×1964 screen, so it drew a **1.54× ellipse**. One line. **You said: "looking good to me with the egg."** |
| **T3** | A peer window's claim that our field mass is **5× wrong** | ✅ **REFUTED BY MEASUREMENT** before it reached a board. The anchor is right to 1.3e−5. Only 2M of the 10M particles gravitate — that is by design and load-bearing. |

⭐ **The pattern in T1 and T2:** both ceilings were justified by a written belief — *"a Berlin set is 40-60
minutes"* and *"a black hole cannot shed mass"*. **You had already ruled both dead.** The code just hadn't heard.

---

## ✅ YOUR VERDICT — 2026-08-31 18:55:07: ***"app behaving great :)"***

Four "cannot go down" rules were killed today. **All four accepted, fullscreen, on one build.** Each had
been added to cure a flicker and justified as cosmetic; together they were the reason the hole outlived
the physics.

| # | rule | kind | `file:line` |
|---|---|---|---|
| 1 | `bhSeedMassMono` running **max** on the drawn radius | ratchet | `renderer.mm:3452` |
| 2 | `lastHorizonRSmooth` ×0.03/frame chase (~3 s) | lag | `renderer.mm:1849` |
| 3 | `bhStrength` **floored at full** while the latch held | ratchet | `renderer.mm:3686` |
| 4 | `bhStrengthEma` ×0.04/frame chase (~2 s) + the rotation ease | lag | `renderer.mm:3646` |

⭐ **The one that ADDED something passed too:** the emergent disk rotation was gated on a radial-profile
mass measured at **zero on 667 of 670 samples**, so it had essentially never run. It runs now.
📊 **`fps=120.0, worst=10.7 ms, realtime=1.007x` at 2,000,000 particles** — pinned at the display rate.
⛔ That retires the earlier half-second-frame worry; it came from an older build carrying all four lags.

---

## ⚖️ NEW LAW ON THE BOOKS — 2026-08-31 16:33:00

> *"play is end of bh formed... force pumps out of bh into the chladni shapes. bh and chladni cant
> coexist, max in transition to one another."*

Recorded as **`BOARD_BLACKHOLE.md` §Z** and every future formation change is measured against it.
**T2 is the first step toward it, not the whole of it.** What still fights the law, none of it touched:
a **3 s** render ease (`renderer.mm:1829`), a **25-frame** formation ease (`renderer.mm:3623`), and a
**REBIRTH drain that is exponential** so it never fully finishes. ⭐ **Your bigger fix — drive the pump-out
from play amplitude instead of from rebirth — is named and NOT started.** It needs your go.

---

## 🔴 THE HONEST LIMIT ON ALL OF THE ABOVE

**You said it: *"hard to see cause the bh is still no lens no nothing."*** That is correct and it is not new —
both BH renderers were deleted 2026-08-27 (852 lines). **T2 is verified in the LOG, not on screen**, because
nothing currently draws a photon ring, a far-side arch or an underside arc. **The BH renderer (F1, Fable's
window) gates your eyes-on verdict for everything in §Z.**

---


---

## 🔴 BLOCKED ON YOU — nothing moves until you look

| # | What | Why it needs your eyes |
|---|---|---|
| **1** | **Posed spin now runs 20–45% slower** at your frame rate | The clock fix dropped it to the rate the matter is actually moving. Correct by construction, but it is a LOOK change. Reversible. |
| **2** | **Sustain rebirth is ~3× faster** | It was a per-frame fraction; it is now the per-second rate its own comment always claimed. Hold a note and judge. |
| ~~**3**~~ | ⏸️ **DECIDED 2026-08-31 00:31:01 — warp deferred.** *"yeah warp defo needs more steps but thats not for now."* | 95 of 97 `dt` uses were accidentally frozen at 1/60, so warp barely reached the integrator. Now it genuinely scales the step — honestly bigger, therefore honestly unstable. **The cure is warp = MORE STEPS, not a bigger one.** Not built. |
| **4** | **Cologne pixel specs — you said "note it, we discuss later."** Front 5340×1680, sides 7152×1680 each ⇒ 19,644×1680 | Venue asked two questions **still unanswered: 60 fps? external SSD?** 6 days. |
| **5** | **VJ mode is dead code** (`main.cpp:1929`, `if (false && …)` since 2026-06-26 — **8 panels are dead the same way**: PRESETS `:1427`, NEW SCIENCE `:1866`, INDUSTRY DEBUGGING `:1876`, VJ MODE `:1929`, DYNAMICS `:2031`, VJ FX `:2157`, PHYSICS STATS `:2206`, DEBUG GPU `:2282`) | Mic/system-in cannot drive the visuals by any route. Deliberate or forgotten? One decision. |

---

## ✅ LIVE IN THE TREE — committed, clean, `b7e6c19`

**The clock is unified.** Nine leaks closed, one concern per commit, sources end `d0697d8`.
Nothing physical is expressed per FRAME any more.

- `compute_physics` no longer integrates on a hardcoded 1/60 (it did on **every shipped run** — the debug bit that gated it was silently repurposed as the sustain gate on 2026-08-03)
- Step count comes off a wall-clock accumulator · `universeClockSec` ticks by steps executed
- Pose/time-lapse clock runs on SIM seconds · the wall clock no longer lies below 30 fps
- `radialMassBuffer` clear moved beside its consumer

**Camera feel** — done, your verdict *"i love the feel the snappiness"*. `c` = cinematic, 45° taps.
**Colour** — `stellar-bvr` band set default since 2026-08-24, your *"okay with the colors"*.

---

## 🚧 THE SIX FRONTS — where each actually stands

| Front | State | Honest read |
|---|---|---|
| **Clock / sim units vs fps** | ✅ **the engine-wide law is closed** | The endeavour landed. What is left is warp-as-more-steps, and forces cost 13.4× the integrate, so brute force is unaffordable. |
| **Black hole** | 🔴 **worse than the board implied** | Both renderers were DELETED 2026-08-27. Nothing makes the photon ring, far-side arch or underside arc. Horizon/photon sphere/ISCO all fit inside ONE softening length. |
| **Mergers** | 🔴 **no visual exists** | *"a merger doesnt have a visual face yet. its just millions of dots."* Science sketched (red nova / TDE / ringdown), nothing built. **BH–BH — your money shot — is not started.** |
| **Sonification** | ⬜ **ZERO LINES** | `grep -rl "sonif\|perParticleVoice\|fieldVoice" src/` → no files. Design complete, nothing built. Not a 6-day item. |
| **UI / "not nasa"** | 🟡 direction set, little built | Disco (T5) is direction only. Panel clipping is open — you said *"nvm its cool mov eon"*. |
| **Rendering / the room** | 🟡 **numbers just got fixed** | The show's own design doc had the SUPERSEDED estimate (160 m², 4 m walls) until tonight. Real: **138.25 m², 3.50 m**. |

---

## 🚨 THE THING THAT INVALIDATES MEASUREMENTS

**The grid samples 32 of 334,576.** `scatter_particles` stores only the first 32 per cell on a
first-come atomic; merge and capture both scan `min(cellCounts[cid], 32u)`. In the core — the only
place a hole can form — the physics considers **0.01% of the matter, resampled by GPU order.**

`Mmax` forks **11.1×** run-to-run at cap 32. At cap 64 the fork drops to 3.4× and **4× as many seeds
form.** Seed formation is currently decided by a buffer size, not by gravity.

⚠️ **Every single-run comparison in this project's history is unreliable, mine included.**
Your question stands as the next move: **how does NASA do this?**

---

## ⛔ DEAD — do not retry

Ribbon pass · scanlines · NEO as a basis · BPM sync · shrinking the window for frame rate
(*"yo u launched it in a tin y window lol"*) · `SS_ORTHO` default (*"this is not a fix lol"*) ·
sequential A/B arms · clamping the accumulator's debt to zero (measured worse than the bug).
