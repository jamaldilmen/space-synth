# MEASURED — A2: THE REFUND FIRED. `gMaxMass` IS NON-MONOTONE.

**Written:** 2026-08-10 08:59:15
**Binary:** deployed bundle `2026-08-08 02:24:49` — no source newer, **nothing rebuilt** (stale-binary rule checked first)
**Watcher:** `tools/a2_watch.sh`, launch method inherited from `a1_watch.sh` (`open -n --stdout/--stderr` — the only way stderr survives; a Finder launch discards `printf` entirely)

---

## 1. THE RESULT

`[REBIRTH]` had **never appeared in any log in this project** — 0 occurrences across every file in `logs/` before 2026-08-08. It fired.

**RUN 1** — `logs/A2_refund_20260808_181210.log`, 2026-08-08 18:12:10 → 18:31, **2M particles**, 1× warp, silent until the cue, then Jamal held sustained notes.

`Biggest body` (`gMaxMass`) fell for the first time ever:

```
177,218 → 90,294 → 45,653 → 22,751 → 10,798 → 4,809
        → 1,820 →   737 →    319 →    147 →     50.0
```

Roughly **halving every 120 frames** (the print cadence) — clean geometric decay, consistent with a per-frame withdrawal proportional to the surviving pile.

| Quantity | Run 1 |
|---|---|
| `[REBIRTH]` lines | **40** (project total before: **0**) |
| Falling steps in `hole=` | **23** (rising: 3) |
| Peak `Mmax` → final | **227,915.5 → 50.0** (the `M_BH_SEED` floor) |
| `SHORTFALL(minted)` | **0** |
| `live` (spawn / min / final) | 2,000,000 / **1,227,500** / **1,999,950** |
| `Mlive` drift | 594,276 → 595,819 = **+1,543 M☉ (+0.260%)** |
| FPS | median **48**, 3.3% under 30 — healthy, not starved |

**The field came back.** 772,450 particles returned from the dead pile — the *"invisible abyss of light where all particles perpetually land in once eaten"* (`particles.metal:655`) now gives its light back, which is what the feature was asked for.

## 2. RUN 2 — REPRODUCED, BUT NOT A STACK

**RUN 2** — `logs/A2_refund_20260809_202105.log`, **active field raised to 10M mid-run.**

🚨 **HOW TO TELL THE FIELD SIZE — corrected 2026-08-10 09:12:03.** Do **not** read `[SPAWN] galaxy-disk: 7,498,578 / 1,000,645 / 1,500,777`. That line reports the **buffer allocation** (`main.cpp:139` `PARTICLE_COUNT = 10000000`) and is **identical in every run, including the 2M ones.** The active field is `app.uiParticleCount` (`app_state.h:13`, default **2,000,000**, slider `main.cpp:1455` "Amount", 0…10M). **Read `live=` on the first full `[GRAV]` line instead.** Run 1 and the 2026-08-10 repeat both open at `live=2000000 Mlive=594276`; run 2 climbed to `live=9,999,457 Mlive=2,966,283` because the Amount slider was moved during the run.

- **7** `[REBIRTH]` lines, `SHORTFALL` **0**
- `hole` fell **548.6 → 248.8 → 76.5 → 50.0**
- `seeds=6`, and **`feed=2/0.3` — the seed-feed path returned NONZERO for the first time in this project's logs** (every prior run: `feed=0/0.0 scan=0`). Worth its own look.
- FPS median **31**, 35.8% under 30 — noticeably starved compared to run 1.

⚠️ **This is a different configuration, so it CANNOT stack with run 1.** It is independent evidence that the refund works at 5× field size, which is worth something — but **A2 at 2M remains n=1, and this project bans single-run claims.** A clean 2M repeat is still owed.

⚠️ **Do not quote a "mass drift" for run 2.** The field was re-spawned at a different count mid-log; the apparent +22.6% is a configuration change, not drift.

**Third run** — `logs/A2_refund_20260809_110828.log` — Jamal quit it at +630 s before any crossing. Correctly flagged INVALID by the watcher. Zero crash markers; it did not fall over.

## 3. A REAL LEAK THE GUARD CANNOT SEE

`SHORTFALL(minted)` never fired, so the drain never clamped *within a frame*. But:

> **17 `[REBIRTH]` samples in run 1 charge a withdrawal while the hole is ALREADY at the 50.0 floor** — e.g. `withdraw=0.1 Msun/frame  hole=50.0`.

The guard at `renderer.mm:3096` is `(wdraw > gMaxMass)`. With `wdraw = 0.1` and `gMaxMass = 50.0` that is false, so these never flag. **Refunds continue after the hole has nothing left to pay** — mass is created.

⚠️ Direction matches run 1's +1,543 M☉ drift; **magnitude NOT reconciled**. Stated as a candidate cause, not a conclusion. Distinct from **B5** (the known −280 M☉ residual): this drift is **positive and 5× larger**.

## 4. THE NUMBER REVERSED. THE PICTURE DID NOT.

Final line of run 1:

```
[GRAV] live=1999950 Mlive=595819/189044 Mmax=50.0 hole=1.00L seeds=0 …
```

`Mmax` at the floor — the seed is drained — and `hole=1.00L` regardless. **`bhStrength` stayed pinned at 1.**

Exactly what the A3① measurement predicted the same day: `target = max(seedTarget, densTarget, honestTarget)`, and `honestTarget` (`r_s/r`, median 3.4 across runs) holds it at 1 no matter what the seed does. `seedTarget` peaked at 0.596 in the `[REBIRTH]` lines and ended at 0.000.

**Reversibility is real in the physics and does not yet reach the screen.** The gate is **A3② — the ORIGIN LOCK** (`renderer.mm:2959`, a literal `if (false)`).

## 5. STATUS

🔨 **LOG-VERIFIED. VISUAL VERDICT NEVER GIVEN.** Jamal ran the notes and said "DONE!", but has not said what it *looked* like — whether matter visibly streamed back into the figure, and whether the hole read as shrinking. **Per the board's own standard a row is only ✅ when he has SEEN it and said so.** Everything above is from the logs.
