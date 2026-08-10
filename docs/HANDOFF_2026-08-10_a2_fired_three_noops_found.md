# HANDOFF — 2026-08-10 08:59:15

**Commit:** `779a517` · **Berlin New Media Week: 2026-09-02 — 23 DAYS OUT**
**Read `docs/BOARD.md` first.** It is the reference of truth and it is current as of this handoff.

---

## 0a. 🚨 READ THIS FIRST — EVERYTHING ELSE IN THIS HANDOFF IS SUBORDINATE TO IT

**Jamal, 2026-08-10 09:13:00, screenshot attached, lens OFF:**
> *"when i turn off lens it's still just a weird spinning circle... **flat 2D rings with fake depth**. It's not a true black hole. This issue has been standing for **months**. A lot of our issues fall back to the fact that **it's not a black hole but a black circle with a GoPro on top**. Our black hole eventually needs to **survive non-ortho mode**. It's **crumbling under its own hotfixes**."*

**And on the work in this handoff:** *"whatever tests you've been running here are total ass. Stuck from start at 49.97 as I've said all the fucking time."*

**He is right on the facts. Board row A0 is new and outranks everything.**

🚨 **RETRACTION, 2026-08-10 09:24:00 — the first two findings I wrote here were wrong.** They described `render(const RenderConfig&)` at `renderer.mm:1401`, an overload with **zero callers**. Dead code. `grep` for `.render(`/`->render(` across `src` returns one call site — `main.cpp:2533` — and it is the **two-arg** form. Corrected list:

1. ~~Two camera systems~~ **WITHDRAWN.** The live path is `render(config, viewProj)` (`renderer.mm:1628`); it `memcpy`s (`:1696`) the matrix built at `main.cpp:770-779`, which **does** branch ortho/perspective. The toggle reaches the BH/particle path.
2. ~~`cameraPos` hardcoded `{0,R,0}`~~ **WITHDRAWN.** Live path takes `config.cameraPos` (`:1700-1702`), filled from the real orbit camera at `main.cpp:2162-2164`. A comment at `:1697-1699` records this was already fixed once.
3. **Orthographic projection cannot produce the look he wants.** A tilted ring projects to an exact ellipse; near and far sides render at identical scale. **"Flat 2D rings with fake depth" is the correct description of an ortho projection of a ring.** No post-FX fixes it. **Stands — geometry, not a code claim.**
4. ⭐ **THE REAL MECHANISM — the hole is hard-gated to ortho, one line.** `renderer.mm:1749-1752`: `cam.bhShadowNdcRadius = (config.orthoMode && frustum > 1e-4 && bhLensActive) ? bSim*plateRadius/frustum : 0.0f`. Ortho off → **literally `0.0f`** → every shader gate on it (`render.metal:771`, `:879`) goes false. The hole doesn't degrade in perspective, **it isn't drawn.** That is "cannot survive non-ortho mode", in code.
5. **It's a screen-space circle, not a marched object.** That value is an **NDC radius**; `render.metal:1035` uses it as `thetaE`, a screen-space deflection. Nothing marches a world-space metric here. **"A black circle with a GoPro on top" is a fair description of what the code draws.**
6. **Second gate:** `bhLensActive = (totalAmplitude < 0.02f)` (`:1748`) — the lens is **off whenever he is playing.**

**Consequence for how you read the rest of this document:** A1′, A2 and A3①②③ are arithmetic beneath a hole that is not a world-space object. **A2 "passing" means a number went down.** Do not let the ✅s below imply a black hole exists. C3, C7 and the months of "it reads as two circles" reports are all plausibly downstream of A0.

**And the process lesson, since it cost the reference of truth its accuracy:** verify **which overload is live** before writing a `file:line` into BOARD.md.

---

## 0. READ THIS BEFORE YOU TOUCH ANYTHING

**Nothing was rebuilt this session. No source file was modified.** Every change was to `docs/`.
The deployed bundle (`2026-08-08 02:24:49`) is newer than every source file — **launch it, do not rebuild.**

**Still uncommitted and still unseen by Jamal:** `src/main.cpp`, `src/render/renderer.h`, `src/render/renderer.mm` — the live-UI panel. Held deliberately across three handoffs now. Anything you write in `main.cpp` stacks on work he has not verdicted.

---

## 1. THE HEADLINE — A2 FIRED

`[REBIRTH]` had **0 occurrences in every log in this project's history.** It fired 40 times.

`gMaxMass` — monotone by construction since the project began — **fell**:

```
177,218 → 90,294 → 45,653 → 22,751 → 10,798 → 4,809 → 1,820 → 737 → 319 → 147 → 50.0
```

23 falling steps, halving every 120 frames, `SHORTFALL(minted)` = **0**, and the field came back from `live` 1,227,500 to **1,999,950**. Full write-up: **`docs/MEASURED_2026-08-08_A2_refund_fired.md`**.

🚨 **It is n=1 at 2M and this project bans single-run claims.** Run 2 reproduced the effect but with the active field raised to **10M** mid-run — a different configuration that cannot stack. **A clean 2M repeat is the first job of the next window.** Use `tools/a2_watch.sh NEW` (written this session; it launches, waits for the crossing, announces READY, then reads the refund and checks non-monotonicity automatically).

🚨 **HOW TO VERIFY THE FIELD SIZE — this cost me a false alarm.** `[SPAWN] galaxy-disk: 7,498,578 / …` is the **buffer allocation** (`main.cpp:139` `PARTICLE_COUNT = 10000000`) and prints **identically in every run, 2M ones included.** The active field is `app.uiParticleCount` (`app_state.h:13`, default 2,000,000; slider `main.cpp:1455`). **Read `live=` on the first full `[GRAV]` line.** A clean run opens `live=2000000 Mlive=594276`.

🔨 **Jamal has never given a visual verdict.** He ran the notes and said "DONE!", but never said what it *looked* like. Per the board's own standard the row cannot go ✅ until he does. **Ask him.**

---

## 2. THREE "FIXES" THAT WOULD HAVE DONE NOTHING

The pattern of this session. All three were on the board as real work; all three are no-ops for the same structural reason — `target = max(seedTarget, densTarget, honestTarget)`, and **`honestTarget` saturates at 1.0 and stays there** (`r_s/r`, median 3.4 across runs).

| Row | Was | Is |
|---|---|---|
| **A3③** the spawn latch | "one-line fix" | ✅ **CLOSED — never a bug.** Not a transient: `r_s/r ≥ 1` for 91.8–99.7% of 4 of 6 runs. And the latch pins nothing — downstream gates are at **0.5**, and `bhStrength` was already **0.95 before the latch ever set**. Jamal's call, and the source backs him: the inward drag is **authored** (`particles.metal:775`, `:780` — *"replaces the deleted scripted collapse"*). `hole=1.00L seeds=0` is authored behaviour reported honestly. |
| **A3①** the `/0.5` denominator | "what stops the reversal" | ⬜ **REAL BUT NOT BINDING.** `seedTarget ≥ 1` occurs **0 times in all four healthy runs** (max reached 0.726). ⚠️ It engages at **297,177 M☉** and run 2 peaked at 227,915 — **~33 s of further growth**. On a Berlin-length set it *will* bite. |
| **A2 "masked by A3①"** | my own warning | ❌ **WITHDRAWN.** The test watches `gMaxMass`, a HUD number with no dependence on `bhStrength`. |

**Lesson for whoever is next: on this board, verify that a proposed fix changes an output before spending a session on it.** Three in a row did not.

---

## 3. FOUR NEW ROWS — A4 to A8 (all on the board with evidence lines)

- **A4 — the release discontinuity.** *His eyes:* "after play when I release it kinda jumps... like another thing was at work." **Confirmed:** `envelopePhase` is branched on at **27 sites**, none blended; crossing 3.5 flips friction (`:780`), kills the rebirth stream (`:664`), plus `:839` and `:2758` — all in one frame. **On screen every single play.** Fix is a ramp, not a fifth branch.
- **A5 — the fuse.** His ask: *"can we make the fuse faster."* `M_BH_SEED = 50.0` sits **exactly on the IMF ceiling** (0.08…50.0), so `Biggest body` reads flat at ~49.9 until a rare heavy–heavy merger. Only **687 of 2,000,000 stars exceed 25 M☉**. Crossings measured at 3.5 / ~8 / 10+ / 16 min. **Proposed: mass segregation** — placement is currently independent of mass, so heavyweights scatter; real clusters segregate. Keeps `imfMassOfId` byte-identical, which the refund requires.
- **A6 — the refund floor leak.** 17 samples pay a withdrawal at `hole=50.0`; the guard `(wdraw > gMaxMass)` cannot see it. Candidate cause of the +1,543 M☉ drift, **not reconciled**.
- **A7 — FPS degrades over a run.** 57 → 38 fps in 10 minutes, unexplained. Matters because `dt` is per-frame: a sagging frame rate silently slows the physics mid-set.
- **A8 — `feed` returned nonzero for the first time ever** (`seeds=6 feed=2/0.3` at 10M). The "feed has never scanned" fact is no longer safe to quote.

---

## 4. WHAT I GOT WRONG THIS SESSION

- **Claimed A3③ off a single log** in a project that bans exactly that. Caught it myself on his "check again" and stacked to 6.
- **Invented three fixes for a non-problem** (compactness test / `R_DISK` ratio / accept) before establishing there was a problem.
- **Nearly reported the soak run as evidence.** It was **starved — median 24 FPS, 93% of samples under 30.** His call ("more likely my screen was locked") was right and the data backed it. Saved as memory: **check the FPS distribution before believing any null result.**
- **Two bad regexes** — `live=` matched inside `Mlive=`, and `[0-9.]*` matched zero digits and injected phantom 0s. Both produced numbers I nearly reported.
- **Hung mid-task**, which is why he asked for a recheck.

---

## 5. THE ORDER FROM HERE — REWRITTEN 2026-08-10 09:13:00 ON HIS VERDICT, 23 DAYS OUT

**0. A0 — MAKE IT AN OBJECT INSTEAD OF A CIRCLE.** His standing months-old complaint, now with a named mechanism (§0a, corrected). The first move is narrow and cheap: **drop the `config.orthoMode &&` term at `renderer.mm:1750`, build, launch in perspective, look.** Hole appears (wrong size/shape but present) → the work is real geometry. Nothing appears → the gate hides a second dependency, and that is the actual A0. One condition, one build, one verdict. Everything visual is gated behind this. Do not start anywhere else.

Then, and only then:

1. **A4, the release discontinuity** — on screen every play, and a show defect. 27 unblended `envelopePhase` branches, four flip at once on release.
2. **A5, the fuse** — mass segregation. This is also what made the last two test sessions unusable: he sat watching 49.9 for ten minutes, twice, and said so from the start.
3. **A3②, the ORIGIN LOCK** (`renderer.mm:2959`, a literal `if (false)`) — the reversal is real in the numbers and does not reach the screen.
4. **Re-run A2 clean at 2M** for the stack — but note it validates bookkeeping, not the hole. Lower priority than it looked yesterday.
5. **A3①** as follow-up (engages ~33 s past run 2's peak).

⚠️ **A standing instruction from this session: stop proposing work that cannot change what he sees.** Three "fixes" this session were no-ops (§2), and two test sessions were spent watching a counter that could not move (A5). Before opening any row, state which pixel changes.

**Do not touch the merge cross-section.** An uncapped capture radius is what caused the A1′ runaway.
