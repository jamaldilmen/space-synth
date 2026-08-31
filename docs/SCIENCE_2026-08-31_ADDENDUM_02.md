<!-- SCIENCE TRACK ADDENDUM 02 — Claude Science project SPACE SYNTH X · 2026-08-31 15:40
     Answers correction 3 (N = 1e7) from the repo. Reissues the F2 cost answer and
     cost-accuracy-budget.csv / gravity-cost-budget.png at the live particle count.
     Supersedes INDEX §6 in full. Nothing here is fitted to SPACE SYNTH output.
-->

# ADDENDUM 02 — F2 REISSUED AT N = 1e7, AND A P0 NUMBER THAT IS NOW COMPUTABLE

**Correction 3 accepted.** `PARTICLE_COUNT = 10000000` (`main.cpp:177`) is the live count; the
`2000000` in the prompt pack is `app_state.h:13 uiParticleCount`, a dial that never reaches the
renderer. **Every throughput and timing number in P3 was at one fifth of the real load.**

**Your Power+2003 arithmetic checks out exactly.** At `N = 1e7`, `eps_opt = 4R/sqrt(N) = R/790.6`,
and I reproduce all four rows (`R = 11.70 -> 0.0148`, fine eps `4.2x`, coarse `68x`; `R = 60 ->
0.0759`, fine eps `0.82x`, coarse `13x`).

⛔ **My "softening is ~5x too large" verdict is WITHDRAWN — INDEX §2 row 19 is superseded.** It was
computed at `N = 2e6` against a guessed `R = 4.0`. Corrected: **the fine eps is roughly right** —
between `1x` and `4x` of eq.-15 optimum depending on which radius stands in for `r200`, and
*finer* than optimum against the outer edge. **The over-softening lives in the coarse eps, at
`13-68x`.** Your caveat and mine agree: eq. 15 is fitted to dissipationless CDM halo convergence,
and this field is truncated, disc-dominated and collisional, so these are order-of-magnitude.

---

## 1. THE REISSUED F2 ANSWER — SUPERSEDES INDEX §6 IN FULL

| method | ms @ 2e6 | **ms @ 1e7** | basis |
|---|---|---|---|
| Direct summation, all pairs | 5,700 | **142,500** | my arithmetic, `O(N^2)` |
| Barnes-Hut, published rate (1 GTX480, 2012) | 714 | **3,968** | Bedorf+2012, 2.8e6 p/s, N-scaled x logN |
| Abacus near/far split (1 V100, `1e-5` error) | 167 | **833** | Garrison+, ~1.2e7 updates/s/GPU |
| Barnes-Hut scaled to 14 TFLOPS, all particles | 68.6 | **381** | my arithmetic, flop ratio — **upper bound on speedup** |
| + opening angle `0.75 -> 1.0` | 45.5 | **253** | my arithmetic, exponent 1.43 from Bedorf+2012 |
| + block timesteps (17% updated) | 11.8 | **65** | my arithmetic, Ahmad-Cohen 1973 / McMillan 1986 |
| + both levers | 7.74 | **43** | my arithmetic |
| Cell-list rebuild: radix sort of 10M keys | 0.32 | **1.6** ✅ | my arithmetic, memory traffic, linear in `N` |
| Particle-mesh far field: `256^3` FFT + deposit | 0.29 | **0.9** ✅ | my arithmetic, FFT fixed + deposit linear |

**The verdict changed, and it changed in the direction you predicted.** At `2e6` the
`theta=0.75` + block-timestep configuration came in at `11.8 ms` and fit. At `1e7` the same
configuration is **65 ms — 4.0x over budget.** Pulling both levers gives `43 ms`, still **2.7x
over**. There is no configuration in the literature that puts full tree gravity for `1e7`
particles inside 16 ms on one GPU, and I am not going to invent one.

### 1a. ⭐ BUT THE FIX TO YOUR ACTUAL BUG IS STILL CHEAP

**This is the part worth separating.** The capped hash is a *neighbour-finding* failure, and
replacing it with an exact radix-sort + prefix-sum cell list costs **1.6 ms at `N = 1e7`** — it
still fits trivially, it removes the capacity parameter entirely, it is deterministic, and it needs
no atomics. **That fix is affordable at the live count and should be done regardless of what
happens to gravity.** The `1.6 ms` and the `65 ms` are separate problems with separate answers;
the F2 framing conflated them, and the reissue separates them.

### 1b. WHAT ACTUALLY FITS — three honest routes, no invention

1. ⭐ **Decouple physics cadence from display cadence.** At `65 ms` per gravity update that is
   **~15 physics steps/s** while the renderer runs at 60 fps and interpolates positions. This is
   standard practice and costs no accuracy — it costs *temporal resolution of the dynamics*, which
   is a different thing and is honest to state.
2. **Reduce `N`.** `16 ms` is reached at **2.47e+06 particles** at `theta=0.75` + block
   steps, or **3.73e+06** at `theta=1.0`. ⛔ **No historical inference attaches to that number** — corrected 2026-08-31 15:55. The live
   count was never `2e6` (`main.cpp:177` went `1e5 -> 8e5 -> 1e6 -> 5e6 -> 1e7` between
   2026-02-28 and 2026-03-12 and has been `1e7` since), and `uiParticleCount` was introduced
   2026-06-07, three months later. The dial cannot have informed the count and the count was not
   tuned to the dial. **The `16 ms` arithmetic stands on its own; the coincidence I read into it
   does not exist.**
3. **TreePM.** A `256^3` PM far field costs `0.9 ms` and bounds tree depth, which is what GADGET-2,
   GreeM and HACC use it for. It reduces the tree work but does not close a 4x gap on its own.

⛔ **What does not work:** raising the opening angle further (the measured cost exponent is only
1.43, so `theta` is a weak lever and it buys error, not time) · a deeper timestep hierarchy than
17% occupancy without a measurement to justify it · and any claim that Apple-class hardware closes
the gap, because **the 381 ms flop-scaled figure is already an upper bound on the speedup** —
traversal is memory-bound, not flop-bound.

⚠️ **The largest uncertainty is unchanged and now matters five times more: there is no published
astrophysical N-body benchmark on Apple Silicon or Metal.** Every number above descends from
CUDA-on-NVIDIA measurements. **A direct-summation benchmark at `1e7` on your hardware would anchor
this entire table and is an afternoon's work.** Until it exists, treat every "my arithmetic" row as
an order-of-magnitude bracket, not a prediction.

---

## 2. 🚨 P0 PREVIEW — THE FIELD IS NOT A STELLAR SYSTEM, AND THAT MAY BE THE POINT

The geometry you supplied makes the P0 question partly computable. **This is a preview from three
numbers, not the P0 run.**

Half-mass radius `11.70` sim `= 0.137 AU`; outer edge `60.0` sim `= 0.70 AU`; `M_field =
5.94276e5 M☉`.

**Surface density within the half-mass radius:**

    Sigma(<R_half) = 0.5 M_field / (pi R_half^2) = 2.1e17 M☉/pc^2

**The observed maximum stellar surface density is `Sigma_max ~ 3e5 M☉/pc^2`** — Hopkins, Murray,
Quataert & Thompson 2010, *MNRAS* **401**, L19, `doi:10.1111/j.1745-3933.2009.00777.x`
(arXiv:0908.4088), compiled across globular clusters, massive star clusters in starbursts, nuclear
star clusters, ultra-compact dwarfs and galaxy spheroids; confirmed by Grudić et al. 2019,
`doi:10.1093/mnras/sty3386` (arXiv:1804.04137) as holding **across ~8 orders of magnitude in mass**.

⛔ **The field sits 11.9 dex — nearly twelve orders of magnitude — above the observed maximum.**
As a star cluster, a nuclear star cluster, or any observed class of dense stellar system, this
object does not exist and cannot.

**But look at what it is instead.** In its own units the field's outer edge is at `R/r_s(M_field) =
60` and its half-mass radius at `11.7`. For scale, the Sun sits at `R/r_s = 2.4e5`. Characteristic
speeds follow directly: `v_circ(R_half) = 0.146 c`, escape speed `0.272 c` — the full-potential value, which
includes the mass outside `R_half` deepening the well.

🚨 **So the field is a mildly relativistic self-gravitating system, and the simulation integrates it
with Newtonian gravity.** The leading post-Newtonian correction is `(v/c)^2 = 0.021` —
a few per cent, everywhere, systematically.
⛔ **Corrected 2026-08-31 15:55:** I first quoted `v_esc = 0.292 c`, which uses the *total* field
mass at `R_half` and is **7% high**. The three defensible statements are `v_circ(R_half) =
0.1462 c`, `v_esc` from enclosed mass alone `= 0.2067 c = sqrt(2) v_circ`, and `v_esc` in the
full potential `= 0.2721 c`. **Use the last.** `(v/c)^2 = 0.021` and the mildly-relativistic
conclusion are unaffected.
 That is a statement about the *dynamics*, not the
renderer, and it is not fixed by any neighbour-finding change.

⭐ **And the hole it produces is exactly the right mass for that regime.** `1.02e5 M☉` sits squarely
in the **direct-collapse black hole seed** range — Begelman, Volonteri & Rees 2006, *MNRAS* **370**,
289, `doi:10.1111/j.1365-2966.2006.10467.x`; characteristic mass from direct collapse, Ferrara et
al., `doi:10.1093/mnras/stt1786`. A `1e4-1e6 M☉` hole forming from the monolithic collapse of a
compact, relativistic, self-gravitating mass **is a published formation channel**, not an artefact.

**So the honest P0 framing, offered as a hypothesis for the real P0 run to test:** the object is
indefensible as a star cluster and defensible as a **direct-collapse black hole progenitor**. That
is not a smaller claim — it is a different and more interesting one, and it happens to explain why
a `1e5 M☉` hole forms. It also means the star-map and the black-hole tracks are describing *two
different objects*, which is worth settling before either is drawn.

⛔ **What I could not verify:** I searched for a "relativistic star cluster" instability literature
(Zel'dovich-Podurets-type) through the same route and **found nothing via that query** — so I am
not citing it. The direct-collapse line above is verified; the relativistic-cluster framing is my
inference from the compactness, and should be checked properly in P0.

---

## 3. WHAT IS UNCHANGED, AND WHAT IS OPEN

- **INDEX §6 is superseded in full** by §1 above. **INDEX §2 row 19** (softening 5x too large) is
  **withdrawn**. Rows 16, 17, 20, 21 (the cell list, the 27-cell stencil, the failed convergence
  test, the nondeterminism) are **unaffected** — none depended on `N` or `eps`, and row 16 is now
  *better* supported, since the exact cell list costs 1.6 ms at the real count.
- **The `n=2` lensing ring and everything in Addendum 01 §1a stand** — those are geometry, not
  particle count. ⛔ **The `F_BH_CLUSTER` regime problem is VOID as a code criticism** — the
  constant was deleted 16:10:25. Its *literature* content (the observed `M_BH/M_NSC` ratio spans
  three regimes over >2 decades and depends on host mass) remains true and applies again to any
  future constant of that form. See `ADDENDUM_04` §3.
- ✅ **Your verification of coarse `eps = 1.0 = r_s(M_field)` exactly** (`renderer.mm:2255`,
  `halfExtent = 64.0`, `kGridSize = 128`) is recorded. The position-conditional resolution verdict
  is confirmed by both routes.
- ⚠️ **OPEN, per your note:** whether a formed hole can leave the `+-4.0` fine box. `comShift` pins
  the box to the core, but an off-core hole is untraced. **I have marked my discontinuity concern
  as open, not confirmed.**
- **P0 is still unrun.** §2 is a preview from three numbers.

## 4. WHAT I GOT WRONG THIS ROUND

1. Guessed `R = 4.0` from the AMR box when the field is a three-component distribution with no
   single `R`, and published a `5x` over-softening verdict on it. Withdrawn.
2. Carried `N = 2e6` from the prompt pack into every cost estimate in P3. Yours was the
   upstream error, but I had the chance to notice that a 128^3 grid with a 334,576-particle peak
   cell is hard to reconcile with 2e6 total, and I did not.
