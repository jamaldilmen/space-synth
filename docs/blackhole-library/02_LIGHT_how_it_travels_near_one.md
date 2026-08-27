# 02 — HOW LIGHT TRAVELS NEAR A BLACK HOLE

**Written 2026-08-27 21:09:40.** His question: *"how light travels near it, how gravity changes."*
This is the chapter to read **before proposing any renderer.** It is why both of ours died.

---

## 0. THE ONE SENTENCE

**A black hole does not bend light. It bends the space light travels straight through.**

Light always follows the straightest available path — a *null geodesic*. Near a hole the
straightest path is curved, because the geometry is. Nothing acts *on* the photon: there is no
force, no refraction, no medium, no surface.

🔪 **This is exactly why the lens had to die (2026-08-27).** A lens is a surface that refracts:
you place it, and it maps an image to another image. That is a *forward* operation on a thing
you already drew. The real question is **backward**: for this pixel, where did the ray come
from? Ask it forward and you can only ever produce as many images as you coded roots for.

---

## 1. THE RADII — everything in the picture is one of these

Units: `r_s = 2GM/c²` = 1, `M = 0.5`, `c = 1`. **This is our engine's convention too.**

| Radius | Value | What it is |
|---|---|---|
| **Event horizon** | `r_s` = 1 | escape velocity reaches c. Not a surface. |
| **Photon sphere** | `1.5 r_s` (= 3M) | where light can orbit — **unstably**. The ring lives here. |
| **ISCO** | `3 r_s` (= 6M) | innermost stable circular orbit; the disk's inner edge |
| **Capture / shadow** | **`b_c = 3√3·M = 2.5980762 r_s`** | ⭐ **the number everything keys on.** Aim closer than this and the ray is captured. |

🚨 **The shadow is ~2.6× the horizon, NOT 1×.** The reference frame says *"roughly twice the
size of the event horizon"* and it is right — you see the *capture cross-section*, not the
horizon. A shadow drawn at the horizon radius is wrong by a factor of 2.6.

**Verified in our own tree, not quoted:** `tools/bc_validate.cpp`, run 2026-08-27, bisects on
ray fate rather than printing a closed form —
```
Method A (exact orbit equation)     b_c = 2.598076211353 r_s   rel err 8.2e-15
shipped shader integrator, step 0.03  b_c = 2.59803855 r_s     rel err 1.45e-05
```

---

## 2. DEFLECTION, AND WHY THE RING IS A STACK

Weak field: `α ≈ 4GM/(c²b) = 2 r_s / b`. **Exactly twice the Newtonian value** — the factor of 2
is a real GR prediction and is what Eddington measured in 1919.

Strong field it diverges **logarithmically** as `b → b_c`:
```
α(b)  ~  −ln(b/b_c − 1)
```
That log divergence is the whole photon ring. As b creeps toward b_c the ray winds more and
more times before escaping, so:

- **α = π** → the ray came from directly behind: an **Einstein ring**
- **α ≈ 2π** → one full loop: the **n = 1** image
- **α ≈ 3π, 4π…** → n = 2, 3, … — each a complete, thinner, fainter copy of the whole sky

**Successive rings are spaced by `e^(−2π) ≈ 1/535` in impact parameter.** They pile up on the
shadow edge, exponentially thinner and exponentially fainter. That is the reference frame's
*"thinner and fainter closer to the black hole"* — literally, not stylistically.

⭐ **CONSEQUENCE FOR ANY RENDERER WE BUILD:** n = 1 needs the shadow to be a few hundred px
across to resolve. n = 2 needs ~535× finer. **You cannot get this from a fixed number of
sprite images** — that is a *representation ceiling*, not a bug (board row L3).

**Measured on our own integrator 2026-08-27** (`tools/bc_validate.cpp`, extended): a ray at
`b/b_c − 1 = 1e-4` grazes `rmin = 1.513 r_s` and sweeps **3.73π** of turning. The winding is
real and reachable. What we never had was a renderer that could *show* it.

---

## 3. WHY THE DISK WRAPS OVER THE TOP — R5 and R6

The reference's optics panel states it exactly, and it is testable:

- **Top-of-disk rays** (direct + bent) **do not cross** → their image is **not** left-right
  swapped. This is the far side arching **OVER** the shadow.
- **Rays from beneath the far side** travel **more than 180°**, so their paths **cross** →
  that image **IS left-right swapped**. This is the separate arc **BELOW** the shadow.

🚨 **Parity is the honesty test.** No image-space warp can flip parity — a 2D displacement is
orientation-preserving by construction. If a renderer produces a genuinely mirrored second
image, it is doing real optics. *(Our old lens did pass this: `det J < 0` fell out of solving
the opposite root — `BOARD_BLACKHOLE.md` §2. It passed the parity test and still had to die,
because passing one test does not make a forward map able to produce n≥2.)*

---

## 4. THE g-FACTOR — ONE number, never two

```
g  =  (p·u_obs) / (p·u_emit)          the ratio of received to emitted frequency
```
It folds **both** shifts into a single number:
- **Doppler**, from the disk material's orbital velocity (at ISCO, `v = √(1/6) = 0.408c`)
- **Gravitational redshift**, `√(1 − r_s/r)`

Then the *only* correct transformation of the emitted blackbody is:
```
B_ν(ν, g·T)  ≡  g³ · B_ν(ν/g, T)
```
🚨 **These are the SAME operation, written two ways. Applying both is a double count.** Our own
docs corrected this on 2026-07-24 and it is worth restating every time.

**Beaming is `g³` on specific intensity** (`g⁴` on bolometric flux). At `v = 0.55c` the
approaching limb runs `g ≈ 1.5` and the receding `g ≈ 0.4` — so the brightness ratio is
`(1.5/0.4)³ ≈ **53×**`. **That is the reference's *"brighter on the side moving toward us."*
It is not subtle and it is not a tint.**

⚠️ **The movie cheat, worth knowing:** Nolan/Franklin **turned the Doppler asymmetry OFF** for
Interstellar because the true lopsidedness was *"too confusing for a mass audience"*, and slowed
the spin to a/M = 0.6. **DNGR Fig. 15c is what the disk truly looks like.** ⭐ **If we ever match
the movie exactly, we did it wrong.**

⚠️ **And measured on OUR camera 2026-08-27: face-on `vLos` is exactly zero** (max 4.0e-18,
algebraically exact). His default view is face-on, so **beaming has never been visible to him.**
Any verdict on it needs an edge-on A/B first.

---

## 5. HOW GRAVITY "CHANGES" — the part that is not about light

- **Time dilation.** `dτ/dt = √(1 − r_s/r)`. At the horizon it goes to zero: an infalling
  object appears to freeze and redden forever, while *it* crosses in finite proper time and
  feels nothing. ⭐ **We already have this and he loves it** — `render.metal:782-784` applies it
  as a radius-dependent shear on the spin angle. His *"beautiful time warpeyssss"*. **Never remove it.**
- **Tides.** `~ 2GMh/r³`. The *difference* in pull across an object. **Worse for small holes.**
  NASA's 2024 plunge into a 4.3M M☉ hole: after crossing the horizon, spaghettification is
  **12.8 seconds** away, with 79,500 km left to the singularity.
- **Frame dragging (Kerr only).** A spinning hole drags spacetime with it. Flattens and offsets
  the shadow on the co-rotating side (Bardeen 1972). **Absent at a = 0, which is us.**
- **Orbits are not Keplerian close in.** Below ISCO there are no stable circular orbits at all —
  matter spirals in. This is *why* a disk has an inner edge.

---

## 6. HOW EVERYONE WHO GOT IT RIGHT DID IT

| Who | Method |
|---|---|
| **Luminet 1979** | first ever image of an accretion disk around a hole — computed by hand, on paper, plotted on a line printer |
| **DNGR / Interstellar 2015** | backward ray-tracing of *bundles* (ray + its cross-section) through Kerr, for anti-aliasing; volumetric disk in Houdini |
| **NASA / Schnittman & Powell 2024** | backward geodesic ray tracing on the Discover supercomputer — 10 TB, 5 days, 129,000 processors |
| **EHT 2019 / 2022** | not a render at all — VLBI interferometry. **Measured the shadow and confirmed the size prediction.** |

⭐ **Every single one is BACKWARD and PER-PIXEL.** Nobody who has succeeded did it forward, per
object. That is the pattern, and it is why our two attempts both failed in the same way.

---

## THE ONE CARD — keep these to hand

```
r_s = 2GM/c² = 1        M = 0.5        c = 1
photon sphere           1.5 r_s
ISCO                    3 r_s
capture / shadow  b_c = 3√3·M = 2.5980762 r_s     ← everything keys on this
weak-field bend         α = 2 r_s / b   (2× Newtonian)
strong field            α ~ −ln(b/b_c − 1),  rings spaced e^(−2π) ≈ 1/535
geodesic (a=0, Cart.)   d²x/dλ² = −(3/2)·r_s·h²·x/r⁵
                        ⚠ the (3/2) is NOT (1/2) — the half-value has no photon sphere at all
g-factor                g = (p·u_obs)/(p·u_emit)
shifted blackbody       B_ν(ν, g·T) ≡ g³·B_ν(ν/g, T)   — ONE operation, never both
beaming                 I ∝ g³   ⇒ ~53× limb-to-limb at v = 0.55c
time dilation           dτ/dt = √(1 − r_s/r)
ISCO speed              √(1/6) = 0.4082 c    (ours measures 0.4092 — 0.25%)
```

## SOURCES
- James, von Tunzelmann, Franklin & Thorne, CQG **32** (2015) 065001 — https://arxiv.org/abs/1502.03808
  (extracted in full at `../RESEARCH_2026-07-24_interstellar_dngr.md`)
- NASA — https://science.nasa.gov/universe/black-holes/supermassive-black-holes/new-nasa-black-hole-visualization-takes-viewers-beyond-the-brink/
- Our own: `tools/bc_validate.cpp`, `../RESEARCH_2026-07-24_blackhole_sota.md`

**Last Updated:** 2026-08-27 21:09:40
