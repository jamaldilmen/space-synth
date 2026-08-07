# DEEP AUDIT — "THE CHLADNI SHAPES ARE NOT CORRECT IN OUR 3D SPACE"

**Written:** 2026-07-29 17:57:49
**Requested by Jamal**, after a session of one-at-a-time guess-fixes that produced nothing:
> *"over all across the board our pixels aren't sharp enough and blurry. the black hole barely
> functions and doesn't feed fast enough either. we have a pseudo unified system and you don't
> seem to have any sense of overview over sessions. what we need is a thorough and deep
> understanding of our codebase .. and i've been calling it the chladni shapes are not correct
> in our 3d space. deeeeep audit."*

**Scope:** the full play-regime chain, from MIDI note to lit pixel. Every claim below is read
from code or measured from a probe run today. Nothing inferred from memory or from handoffs.

**Status: DIAGNOSIS ONLY. No code changed. No fix proposed for approval yet.**

---

## 0. THE HEADLINE — HE IS RIGHT, AND IT IS A MATH ERROR, NOT A TUNING ERROR

**A single note can NEVER produce sharp shapes in 3D with the current formula.** Not with
better dissipation, not with a finer grid, not with smaller sprites. The reason is geometric
and it is decisive:

> **A Chladni plate's nodal set is CURVES in a 2D domain. You look at it face-on, and there is
> nothing behind it. Our 3D field's nodal set is SURFACES in a 3D volume, and we render it
> additively with no depth test — so you look THROUGH every surface at once.**

Codimension 1 in 2D is a line drawing. Codimension 1 in 3D, projected, is a **filled region**.
That is the blur. It is not an artifact sitting on top of a correct pattern; it is what the
current formula's zero set actually looks like when drawn.

**Everything else in this audit is real, and none of it is the root.**

---

## 1. THE FIELD, EXACTLY AS IMPLEMENTED

`particles.metal:2038`, inside `if (u.debugFlags & (1u << 23))` (bit23, the play default since
2026-07-19) and `if (rho < EIGEN_R)`:

```c
float psi = JJ.x * cA * cZ;        // Ψ = J_m(k_ρ·ρ) · cos(mθ) · cos(k_z·ζ)
```

with (`particles.metal:1999-2037`)

| symbol | value | source |
|---|---|---|
| `k_ρ` | `α_{m,n} / EIGEN_R` | `BESSEL_ZEROS[mm*9 + (nn-1)]`, 12×9 table |
| `k_z` | `pAx·π / EIGEN_L` | `pAx = 2 + ((m + n) % 3)` |
| `EIGEN_R` | **3.0 sim** | `= ORBIT_R_CHLADNI` |
| `EIGEN_L` | **6.0 sim** | `2·EIGEN_R` |
| `ζ` | `z + L/2` | wall-referenced, correct for a rigid can |

The force is Gor'kov, `F = −contrast·Ψ·∇Ψ` (`:2063`), which is `−½·contrast·∇(Ψ²)`. Matter with
`contrast > 0` seeks **Ψ = 0**; matter with `contrast < 0` seeks **|Ψ| maximal**.

### 1.1 The zero set is a UNION of three surface families

`Ψ = 0` whenever **any one** factor vanishes:

| factor | vanishes on | count | shape |
|---|---|---|---|
| `J_m(k_ρ ρ)` | `ρ = α_{m,j}/k_ρ`, j = 1..n | **n** | nested **cylinders** |
| `cos(mθ)` | `θ = (2i+1)π/2m` | **2m** | **half-plane sheets** through the axis |
| `cos(k_z ζ)` | `ζ = (2i+1)π/2k_z` | **pAx** | horizontal **planes** |

For a mid-keyboard note (say m=7, n=4, pAx=2) that is **4 cylinders + 14 sheets + 2 planes =
20 intersecting surfaces** packed into a can of radius 3. Their total area is enormous relative
to the volume. Two million particles distributed across all of it, summed along every view ray,
is a haze — **and it is a haze made of perfectly sharp surfaces.** Sharpening the surfaces
cannot help, because the problem is that there are twenty of them and you see them all at once.

### 1.2 Why a real Chladni plate looks sharp and this cannot

| | real plate | our field |
|---|---|---|
| domain | 2D membrane | 3D volume |
| nodal set | **curves** (1D) | **surfaces** (2D) |
| codimension | 1 | 1 |
| what you see | the curve, against bare plate | **all surfaces, superimposed** |
| occlusion | sand is opaque, one layer | **additive, no depth test** (§4) |

**To get curve-like structure in 3D you need codimension 2 — the INTERSECTION of two
independent zero conditions, not the union of many.**

The codebase already knows this. `particles.metal:2011-2015`, written for chords:

> *"a surface common to every voice survives in ΣΨᵢ² (the sum can't erase a common zero) →
> sheets. p now differs per chord tone … no nodal surface is shared by all voices → the summed
> potential's minima are **INTERSECTIONS (curves/points) = the volumetric lattice**."*

That is the correct instinct, and it is the whole answer — but it was only ever applied to make
**chord** tones differ from each other. **For a single note nothing produces an intersection,
so a mono note can only ever draw the union.** This is exactly why he reports *"a chord is also
broken"* and *"shapes not correct in 3D"* as one complaint: the single-note case has no
mechanism to make curves at all, and the chord case has one that was never verified.

---

## 2. THE DOMAIN MISMATCH — MOST OF THE FIELD FEELS NO FORCE

`particles.metal:1995`:
```c
if (rho < EIGEN_R) {   // EIGEN_R = 3.0
```
There is **no `else`**. Outside a cylinder of radius 3, a particle receives **zero** eigenmode
force. It is not repelled, not held, not shaped — it free-floats under gravity and drag.

**Measured today** (`[GRIDPROBE]`, 46 samples during held notes, cellSize 1.0 sim):

```
pattern spans 12x12x12 CELLS (12.0x12.0x12.0 sim)   ← matter occupies ±6 sim
cavity is EIGEN_R=3 / EIGEN_L=6                      ← force exists only within ±3
```

**The matter distribution is roughly twice the diameter of the region that shapes it.** Whatever
fraction of the field sits outside ρ=3 is unshaped cloud rendered in the same frame, at the same
brightness, as the pattern. That is a permanent haze floor no physics change inside the cavity
can remove.

⚠️ **Not yet measured: the exact particle count inside vs outside ρ=3.** That is one number and
it should be the first thing any fix measures. It is the difference between "a minor halo" and
"the majority of what you're looking at is not part of the pattern."

---

## 3. THE CONTRAST SPLIT — HALF THE MATTER DRAWS THE INVERSE PATTERN

`particles.metal:2060-2062`:
```c
uint hc = id * 747796405u + 2891336453u; ... 
float contrast = ((float)(hc & 0xFFFFu) / 32767.5f) - 1.0f;   // UNIFORM in [−1, +1]
```

Consequences, by construction:

- **~50% of particles have `contrast < 0`** → they seek **antinodes**, i.e. the surfaces exactly
  *between* the nodal surfaces. They draw the **complement** of the pattern.
- **Particles near `contrast ≈ 0` feel almost no force at all** → they stay wherever gravity and
  drag leave them.

Node-seekers and antinode-seekers together **tile the entire volume**. This was deliberate
(2026-07-19, "INTERIOR FILL", to escape a hollow-shell look), and its own comment says so:
*"structure through the VOLUME instead of one skin."*

**It is working exactly as designed, and the design is in direct opposition to sharpness.**

⚠️ A **contrast floor** was tried 2026-07-29 14:19 and reverted on his verdict (*"it's a
sharpness resolution issue not a contrast issue"*). Note what a floor does and does not do: it
raises `|contrast|` for the near-zero particles but **preserves the ± sign split**, so it never
addressed the antinode population. **The floor test does not exonerate the sign split.** These
are two different mechanisms and only one has been tested.

---

## 4. THE RENDER SUMS EVERYTHING ALONG EVERY RAY

`renderer.mm:637-639`:
```objc
blendingEnabled = YES;
sourceRGBBlendFactor      = MTLBlendFactorOne;
destinationRGBBlendFactor = MTLBlendFactorOne;   // pure ADDITIVE
```
No depth test, no depth write on the particle pass. **Every particle along a view ray adds.**

This is the correct choice for luminous matter and should not casually change — but it means the
20 nodal surfaces of §1.1 are not merely *visible* through one another, they are **summed**. Ten
surfaces at 10% brightness are indistinguishable from one surface at 100%. Structure information
is destroyed at the blend stage, after the physics did everything right.

### 4.1 The sprite footprint makes it worse, and worst exactly in the Chladni state
`render.metal:2032`:
```c
float sL      = max(in.streakLen, 1.0f);   // ≡ 1 ALWAYS — bit18 dead, see §6
float elong   = clamp(speed * 1.4f, 0.0f, 1.0f);
float widthY  = (sL > 1.001f) ? (1.0f/sL) : mix(1.0f, 0.12f, elong);
float lengthX = 1.0f;
```
Shape on screen is set **entirely by screen speed**:
- **fast** (rest, orbiting) → `widthY = 0.12` → thin ribbon → reads sharp
- **slow** (Chladni, matter parked) → `widthY = 1.0` → **full-width round Gaussian**

And `heatSizeBoost = 1 + clamp(temp,0,1)·1.5` = **2.5×** at play temperatures (HUD reads
T = 1.6e9 K). Computed footprint at default zoom for a 1 M☉ particle:

```
rawSize = particleSize(2.0) · heatSizeBoost(2.5) · massSize(1.3) · sizeScale(2.0) ≈ 13 px
```

**Hot and slow is the worst case, and the Chladni state is exactly hot and slow.** The better
the physics parks matter on a node, the fatter that matter renders.

⚠️ **He tested the particle-size dial and reported no improvement.** So footprint alone is not
the dominant term — consistent with §1: shrinking the dots does not reduce the *number of
surfaces* being summed.

---

## 5. WHAT THE MATTER IS ACTUALLY DOING — MEASURED, NOT ASSUMED

`[GRIDPROBE]`, 46 samples, held notes, coarse hash (cellSize 1.0 sim):

| quantity | measured | a smooth pattern would give |
|---|---|---|
| peak cell occupancy | **442,295 particles** (21% of the whole 2.1M field in one 1-sim³ cell) | ~mean |
| mean occupancy | ~950 | — |
| peak : mean | **~460×** | ~1× |
| coefficient of variation | **4.1 – 14.0** | < 1 |
| cells below 10% of mean, inside the pattern's own bounding box | **75 – 94%** | few |

**The field is not distributed on surfaces. It is collapsed into a few hyperdense knots
surrounded by real, measured voids.** His long-standing "holes" report is confirmed
quantitatively — they are mass voids, not a render artifact.

⚠️ **PM gravity was toggled OFF and he reports no visible change.** So gravity is not the
collapse driver, and the cause of this clumping is **unidentified**. That is the single largest
unexplained measurement in this document and it should not be guessed at.

---

## 6. CONFIRMED-DEAD AND CONFIRMED-INERT CODE IN THIS PATH

Verified today by reading the consuming code, not by memory:

| item | state | evidence |
|---|---|---|
| `bit18` fluid streak | **DEAD** — `lenFac ≡ 1.0` for every particle in the app | uninitialised read of `out.pointSize`; measured `[STREAKPROBE] ptSize=0.0 streakLen=1.00`, deliberately left in place |
| Warm-trap thermal kicks | **OFF by default** | `main.cpp:2290`, `SS_WARM=1` to enable |
| SPH viscous diffusion | **rest-only**, never runs during play | `particles.metal:1602` |
| `VoiceData.alpha` (note in Hz) | not used for geometry — **gain only** | `particles.metal:386, 1962` |
| Sphere sculpt (bit16) | **skipped by default** since 2026-07-19 | `main.cpp:2280` |
| Crystallization density weight | **saturated to 1.0 everywhere** — carries zero spatial information | `smoothstep(2,48,·)` on ~11,700 particles/cell, `particles.metal:2471` |
| `cellCounts` grid vs cavity | **cavity spans ~6 cells** | cellSize 1.0 (`renderer.mm:1908`) vs EIGEN_R 3 |

**Six of the seven things touched in this session were already inert.** That is the "pseudo
unified system" he named: a stack of layers where the ones you'd reach for first do nothing, and
the comments describe intent rather than behaviour (§7).

---

## 7. COMMENTS THAT DESCRIBE INTENT, NOT BEHAVIOUR — a systemic hazard

Found today, each one cost real diagnostic time:

| location | comment claims | code does |
|---|---|---|
| `particles.metal:2590` (B2) | *"collapse and play dynamics untouched"* | **no envelope gate** — fires during play |
| `renderer.mm:2247` | *"at play h≈0.047 CFL binds"* | play runs at **h = 1.0** since the 2026-07-18 domain unification |
| `renderer.mm:1904` | AMR fine box *"carries the near-core resolution the cymatics needs"* | AMR feeds **gravity only**; never re-grids SPH or `cellCounts` |
| `particles.metal:2583` (crystallization) | *"drives it onto the exact node line … ∇Y→0 → sharp threads"* | `ridgePull` is the **Y_lm sculpt gradient**, a field whose force is disabled by default |

**Rule earned: in this codebase a comment is a historical record of an intention, not a
description of current behaviour. Verify the consuming code before believing any of them.**

---

## 8. THE MUSICAL MAPPING IS LOSSY AND HAS A DEGENERATE CASE

`modes.cpp:9-27`:
```cpp
int m = midi % 12;              // pitch class → azimuthal lobes
int n = std::max(1, midi/12-1); // octave      → radial rings
```
plus `pAx = 2 + ((m+n) % 3)` (`particles.metal:2025`).

| issue | consequence |
|---|---|
| **C → m = 0** | `dPdth ≡ 0`. **No angular force, ever.** Every C in every octave draws concentric rings — by construction, not by bug. He has reported this repeatedly as *"only circles"* and *"a donut, not two rings."* |
| m is **octave-invariant** | C3 and C6 share the same angular structure |
| `pAx` takes **only 3 values** (2,3,4) | the axial vocabulary is almost constant across the keyboard |
| the mapping is **arbitrary** | it is a design choice, never derived — same status as any tuned constant |

⚠️ **Anyone testing on C is testing the one note that cannot produce angular structure.** This
has silently invalidated an unknown number of past A/B verdicts, including several of mine today.

---

## 9. WHAT IS ACTUALLY ESTABLISHED vs WHAT IS OPEN

### Established by measurement or by reading the consuming code (today)
1. The single-note zero set is a **union of ~20 surfaces**, not curves. §1
2. Matter spans **±6 sim**; the shaping force exists only within **ρ < 3**. §2
3. ~50% of particles seek **antinodes** by design. §3
4. Rendering is **purely additive, no depth** — surfaces sum. §4
5. Sprites are ~13 px and **fattest exactly in the Chladni state**. §4.1
6. Matter is **collapsed into knots**: peak:mean ≈ 460×, CV 4–14, 75–94% voids. §5
7. Six inert/dead systems in this path. §6
8. **C = m = 0 = no angular force**, structurally. §8

### Open, and NOT to be guessed at
1. **What is clumping the matter?** PM gravity off changed nothing. Unexplained. §5
2. **What fraction of particles is outside ρ = 3?** One number, unmeasured. §2
3. **The post-BH ring issue.** He has proven it is conditional on a hole existing, and pointed
   at *"the transition from that state back to the play state."* Not investigated.
4. **"The black hole barely functions and doesn't feed fast enough."** Not investigated today.
5. **Does the chord intersection mechanism (§1.1) actually fire?** Never verified.

---

## 10. WHAT THIS AUDIT IMPLIES — direction only, nothing proposed for approval

The blur has **four independent contributors**, and they are not competing hypotheses — they are
all real and they stack:

```
  ~20 summed nodal surfaces (§1)   ← ROOT. geometric. no tuning reaches it.
+ unshaped matter outside ρ=3 (§2)
+ antinode-seekers drawing the inverse pattern (§3)
+ additive blending × 13px hot slow sprites (§4)
= what is on screen
```

**This is why every single-lever fix today produced "unchanged".** Any one of these alone caps
the achievable sharpness, so removing any one alone changes almost nothing visible. **That is
the structural reason this session failed, and it was predictable from the architecture — which
is precisely what he asked for and did not have.**

The honest implication: **there is no one-line fix, and the next session should not look for
one.** The first question to settle is a design question, not a code question:

> **What should a single note's nodal set BE in 3D — a union of surfaces (what we have) or an
> intersection giving curves (what a Chladni plate looks like)?**

That is his call, it is the fork everything else hangs off, and no measurement can decide it.

---

## 11. HOW THIS SESSION WENT WRONG — for the next window

Seven changes/tests proposed today. **Zero improvements.** Root cause: *mechanism-first, not
measurement-first.* Each was a plausible story about one term, tested on him, with no model of
how many other terms were also capping the result.

| # | proposed | outcome |
|---|---|---|
| 1 | `ridgePull` → eigenmode gradient | reverted, no verdict |
| 2 | node braking ∝ \|Ψ\| | reverted, no verdict |
| 3 | condense gain 8→1 | "unchanged" — only bites after 10-15 s of hold; wrong lever by construction |
| 4 | B2 rest gate | reverted, no verdict |
| 5 | SPH smoothing length | **aimed at code that does not run during play** |
| 6 | jitter off (A/B) | no improvement — exonerated |
| 7 | PM gravity off (A/B) | no improvement — exonerated |

**What actually produced knowledge:** the two A/Bs (6, 7) and `[GRIDPROBE]` (§5) — all
measurements, none of them changes. **And his own observations were the highest-value input all
day**: *"post BH formed"* was a gate nobody had considered, and *"the stars look blurry in
chladni state"* located §4.1 exactly.

**Rules earned:**
- **Measure the whole chain before changing one link.** With four independent caps, single-lever
  A/Bs return "unchanged" even when the mechanism is real.
- **Never test on C.** §8.
- **A comment is intent, not behaviour.** §7.
- **His verdict is the ground truth; do not re-derive it from logs.** When he says a toggle did
  nothing, that is the datum — going to the log to check whether he really flipped it wastes his
  time and insults the report.

---

**Last Updated:** 2026-07-29 17:57:49
**Code state:** `b047744` + the parallel session's 12×9 Bessel/Miller work. **All seven of this
session's changes are reverted**; `[GRIDPROBE]` (read-only, `renderer.mm`) is the only addition.
**NEXT:** §10's design question is his. Everything else waits on it.
