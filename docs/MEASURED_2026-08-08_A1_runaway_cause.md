# MEASURED — A1′, WHY THE SIM EATS ITSELF

**Measured:** 2026-08-08 01:37:02 — code reading + the three logs already captured. Nothing changed.
**Answers:** BOARD A1′, and by extension C7 (which is gated behind it).

---

## THE CAUSE, IN ONE LINE

> **At `mS > 5000` M☉ the capture radius stops being capped and becomes `3·r_s`, which grows
> linearly with mass. Cross-section then grows as M², so dM/dt ∝ M² — a hyperbolic blow-up that
> reaches infinity in finite time. There is no supply limit and no feedback term anywhere.**

---

## 1. THERE ARE TWO REGIMES, AND ONLY ONE OF THEM IS CAPPED

`particles.metal:1213-1252`, the bit2 seed-capture block. It is **victim-initiated**: a small
particle (`mass < M_BH_SEED`) searches for a seed neighbour (`mS >= M_BH_SEED`) and is eaten by it.

**GROWTH regime — `mS ≤ 5000` M☉ — CAPPED ✅**
```
rt  = 1.5 · MERGE_RSUN_SIM · mass^0.8 · (mS/mass)^(1/3)
rt2 = rt² + rt·(2·G1s·mS)/vrel²              ← tidal + gravitational focusing
rt2 = min(rt2, reach²)   where reach = 1.4·cellSize ≈ 0.066 sim   ← ⭐ THE CAP
```
The focusing term alone would give σ ∝ M^(4/3) — already superlinear, already a blow-up. **The cap
is what holds it.** Someone put that `min()` there on purpose and it works.

**FORMED regime — `mS > 5000` M☉ — NOT CAPPED 🚨**
```
mHole = max(u.bhMass, mS)
rs    = mHole · 1.6825e-6          ← Schwarzschild radius, LINEAR in mass
rc    = max(3.0·rs, 0.02)
rt2   = rc · rc                    ← ⭐ NO min(). NO reach. NOTHING.
```
`rc ∝ M` ⟹ σ ∝ M². `dM/dt ∝ ρ·σ·v ∝ M²`. **Any dM/dt ∝ M^p with p > 1 diverges in finite time.**
That is the runaway, and it is arithmetic, not a tuning accident.

### How fast the cross-section actually grows

| Hole mass | `r_s` | capture radius `rc` | capture **area** | vs the growth-regime cap |
|---|---|---|---|---|
| 5,000 (threshold) | 0.0084 | 0.0252 | 0.00064 | 0.15× |
| 20,000 | 0.0336 | 0.1009 | 0.0102 | 2.4× |
| 100,000 | 0.1683 | 0.5048 | 0.255 | 59× |
| 330,000 | 0.5552 | 1.666 | 2.77 | **640×** |
| 557,451 (measured peak) | 0.9379 | **2.814** | 7.92 | **1,830×** |

At the measured peak the hole's capture radius is **2.8 sim units** against `R_DISK = 18`. It is
swallowing a large fraction of the disk per step. The growth-regime cap it escaped was 0.066.

## 2. THE LOGS SHOW THE FINITE-TIME BLOW-UP DIRECTLY

If this were ordinary fast accretion, `Mmax` would sweep through intermediate values. It does not —
it **jumps across five orders of magnitude between two consecutive log samples.**

**Soak, seed 42 — samples with `480 < Mmax < 320,000`:**

```
count: 0
```

**Zero.** It sat at 446 → 475 for 95 samples (growth regime, capped, slow), then the very next
distinct value was **322,919**. Nothing in between, ever.

**Re-test, seed 42 — caught mid-blow-up:** `6,406.8 → 8,100.1 → 73,356.4 → 87,183.9`. Once past the
5000 threshold it goes 8k → 73k in one sample interval.

That gap **is** the signature of `dM/dt ∝ M²`. It is the clearest confirmation available and it was
sitting in logs we already had.

## 3. THIS ALSO EXPLAINS THE 30 s vs 10 min VARIANCE

The run-to-run timing spread is **entirely in the capped phase.** Climbing 50 → 5000 M☉ under the
`reach` cap is a slow stochastic process — it depends on chance encounters, and GPU atomic ordering
makes it nondeterministic even at a fixed spawn seed. Once 5000 is crossed, the blow-up is
effectively instantaneous and identical every time.

**So "the lifespan is unpredictable" was the wrong framing.** There is a slow random fuse of highly
variable length, followed by a detonation of fixed and very short duration.

## 4. WHY THE UNCAPPED RADIUS IS THERE — IT IS A *RENDER* NUMBER DOING A *PHYSICS* JOB

The source comment is explicit that `3·r_s` was chosen for **visual coherence**, not accretion:

> *"the PLUNGE ZONE (~3 r_s) from ONE mass or they read as two layered bodies. The lens shadow
> radius is 2.6·r_s… so disk inner edge (3·r_s) and shadow (2.6·r_s) hug at the fixed Gargantua
> ratio and track together as the hole eats."*

`3·r_s` is the right radius for *"where does matter visually disappear."* It is the wrong radius for
*"what does this body capture,"* because as a capture cross-section with no supply limit it is an
unbounded mass sink. **The two roles were merged and only one of them was thought about.**

⚠️ **This is why the fix is not simply "add a cap."** Capping the capture radius while leaving the
render radius at `3·r_s` will split them apart again and bring back the two-layered-bodies artifact
the comment was written to prevent. **The capture radius and the shadow radius need to become two
separate numbers.** That is the actual work.

## 5. WHAT IS MISSING PHYSICALLY

There is **no feedback term of any kind** — no Eddington-like limit, no radiation pressure, nothing
that makes accretion harder as the hole grows. Real black holes are supply-limited and
feedback-limited; this one is limited only by how much matter is left. Which is why it stops at
`live = 19`: it runs out of food, not out of appetite.

---

## THE FIX — OPTIONS, NOT A DECISION

**None of these is chosen. This is his call, and it is a design question, not a bug fix.**

| # | Approach | Effect | Cost |
|---|---|---|---|
| **A** | **Split capture radius from shadow radius.** Keep `3·r_s` for the render; cap the *capture* radius (e.g. keep `reach`, or a generous multiple). | Kills the blow-up, keeps the visual. **Most conservative.** | **S** |
| **B** | **Eddington-like accretion limit** — cap dM/dt as a fraction of M rather than capping geometry. Physically principled; gives exponential rather than hyperbolic growth, so it never diverges. | The hole grows forever but never in finite time. Real physics. | **M** |
| **C** | **Both.** B is the honest law; A protects the render contract. | | **M** |

⭐ **The reason this matters beyond A1′:** per `MEASURED_2026-08-08_C7`, the Cartwheel radial colour
law only runs when a horizon exists, and right now a horizon only exists *during* the blow-up. **A
hole that forms and persists over a field that still has matter in it is simultaneously the fix for
A1′ and the precondition for C7.** One piece of work, two of his priorities.

**⚠️ Do not "fix" this by lowering time warp or by reducing particle count.** The cause is a
cross-section exponent, not a step size and not a scale. See `feedback_limits_are_perceptual_not_technical`.
