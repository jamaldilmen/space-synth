<!-- SCIENCE TRACK — Claude Science project SPACE SYNTH X
     Produced 2026-08-31. Lands per SCIENCE_PROMPTS_2026-08-31.md §"HOW THE OUTPUT COMES BACK":
     a cited doc, never pasted into src/. THIS IS A CLAIM UNTIL CHECKED AGAINST THE LITERATURE.
     Nothing here is fitted to SPACE SYNTH output. Primary references are inline.
     Prompt: P3 — neighbour finding in production N-body/SPH codes. Feeds: FABLE F2.
     Citation verification: 92 of 98 identifiers tool-verified; 2 marked unverified. Tool checks corrected two draft attributions (arXiv:astro-ph/0504573 is Rodionov & Sotnikova 2005; HACC is Habib et al. 2015).
-->

> ⛔ **CORRECTED 2026-08-31 16:10 — THIS DOCUMENT WAS WRITTEN FOR `N = 2×10⁶`. THE LIVE COUNT IS
> `N = 1×10⁷`** (`main.cpp:177 PARTICLE_COUNT`); the `2000000` it was given is
> `app_state.h:13 uiParticleCount`, a dial that never reaches the renderer. **Every throughput,
> timing and cost figure below is at one fifth of the real load.** The reissued cost answer —
> nothing fits 16 ms, cheapest defensible is 65 ms, but the exact cell list still costs only
> 1.6 ms — is in `SCIENCE_2026-08-31_ADDENDUM_02.md` §1, which supersedes the cost sections
> here. The structural conclusions (tree/FMM choices, the density argument, the softening
> literature, the failure-mode decomposition) are `N`-independent and stand.

# Neighbour finding and gravity in production N-body codes

**A reference for SPACE SYNTH — 2×10⁶ particles, one GPU, ~16 ms frames.**

Scope: this document covers data structures for neighbour finding and gravity, the
handling of unbounded density contrast, GPU cost at 2×10⁶ particles, and whether the
reported failure mode is characterised in the literature. It is method, not
observational data. Every algorithm is attributed to the paper that introduced it and
to the code paper that adopted it.

Three labels are used throughout and are never mixed:

- **MEASUREMENT** — a number published by the cited authors, with their hardware named.
- **MODEL / CONVENTION** — a definition, a fitted relation, or a community default.
- **MY ARITHMETIC** — a number I computed here from a cited relation. The arithmetic is
  shown. It is not a measurement and must not be quoted as one.

---

## 0. Unit conversion into the project convention

Convention: geometrized units, G = c = 1, r_s = 2M, M = r_s/2, and **one simulation
length unit L ≡ r_s of the total field mass M_tot**.

Definition (CONVENTION, exact given G, c, M_☉):

    r_s(M) = 2GM/c²
    r_s(1 M_☉) = 2.9540 km      [MY ARITHMETIC from G = 6.67430e-11 m³ kg⁻¹ s⁻², c = 2.99792458e8 m/s, M_☉ = 1.98892e30 kg]

Hence, for a field of N = 2×10⁶ particles:

| M_tot | 1 L = | in pc | 1 pc = |
|---|---|---|---|
| 2×10⁶ M_☉ (1 M_☉ per particle) | 5.908×10⁶ km | 1.915×10⁻⁷ pc | 5.223×10⁶ L |
| 2×10¹⁰ M_☉ (10⁴ M_☉ per particle) | 5.908×10¹⁰ km | 1.915×10⁻³ pc | 522.3 L |
| 4×10¹⁰ M_☉ | 1.182×10¹¹ km | 3.829×10⁻³ pc | 261.1 L |

All MY ARITHMETIC. Two consequences worth stating plainly:

1. With M_tot = 2×10⁶ M_☉ the simulation length unit is 2×10⁻⁷ pc, so a 10 pc star
   cluster is ~5×10⁷ L across. Any softening length you set in L is, in physical terms,
   astronomically small unless the field mass is large. **The length unit is set by the
   total mass, so changing the particle mass rescales the entire spatial grid.** If the
   field mass grows as black holes accrete external material, L is not constant.
2. A 50 M_☉ seed black hole has r_s = 147.70 km. In sim units, for M_tot = 2×10⁶ M_☉,
   that is r_s = 2.5×10⁻⁵ L and M_BH = 1.25×10⁻⁵ (since M_tot = 0.5 by construction).
   The seed horizon is therefore ~10⁻⁵ of the box scale — five orders of magnitude below
   any plausible grid cell. No neighbour structure discussed below resolves it; the
   horizon must be handled analytically or as a sink particle, not by the grid.

---

## 1. How this is actually solved in production codes

### 1.1 The four families

Every production code at 10⁶–10⁹ particles uses one of four gravity strategies, and in
almost all of them **the same hierarchical structure serves both gravity and neighbour
finding**. That dual use is not an accident — it is the reason the tree wins.

**(a) Hierarchical tree, monopole/low-order (Barnes–Hut).** Introduced by Appel (1985,
SIAM J. Sci. Stat. Comput. 6, 85, doi:10.1137/0906008) as an O(N log N) many-body
scheme on a binary tree, and given its canonical oct-tree form by Barnes & Hut (1986,
Nature 324, 446, doi:10.1038/324446a0). Cost O(N log N). Force error controlled by a
multipole acceptance criterion (MAC).

**(b) Fast multipole method (FMM).** Greengard & Rokhlin (1987, J. Comput. Phys. 73,
325, doi:10.1016/0021-9991(87)90140-9). Cell–cell expansions give O(N) and, critically,
**manifest momentum conservation**, which a one-sided tree walk does not have. Dehnen
(2000, MNRAS, arXiv:astro-ph/0003209; 2002, arXiv:astro-ph/0202512) brought the O(N)
momentum-conserving formulation into astrophysics.

**(c) Particle-mesh and its hybrids (PM, P³M, TreePM).** PM and P³M are due to Hockney
& Eastwood (*Computer Simulation Using Particles*, 1981/1988,
doi:10.1201/9780367806934), with the adaptive refinement of P³M by Couchman (1991, ApJ
368, L23, doi:10.1086/185939) and the cosmological implementation of Efstathiou et al.
(1985, ApJS 57, 241, doi:10.1086/191003). The tree/mesh split — long-range force from an
FFT on a mesh, short-range from a tree — was introduced as TPM by Xu (1995,
arXiv:astro-ph/9409021), developed by Bode, Ostriker & Xu (2000, ApJS 128, 561,
doi:10.1086/313398), and independently as TreePM by Bagla (2002, JApA 23, 185,
arXiv:astro-ph/9911025).

**(d) Direct summation with hardware assist.** Exact pairwise forces. Only viable when
the physics is genuinely collisional (binaries, mass segregation, close encounters).
Makino (1991, PASJ 43, 621, doi:10.1093/pasj/43.4.621) put a treecode on GRAPE
special-purpose hardware; the GPU era begins with Belleman, Bédorf & Portegies Zwart
(2008, New Astron. 13, 103, arXiv:0707.0438) and the SAPPORO GRAPE-emulation library
(Gaburov, Harfst & Portegies Zwart 2009, arXiv:0902.4463).

### 1.2 Code-by-code, with the authors' stated reasons

The full table is in **code-comparison.csv**. The load-bearing choices:

**GADGET-2** (Springel 2005, MNRAS 364, 1105, doi:10.1111/j.1365-2966.2005.09655.x)
uses a Barnes–Hut **oct-tree** with **monopole moments only**, plus PM for the long
range. Springel's stated reasons, quoted in substance: the oct-tree is shallower than a
binary k-d tree — for a near-homogeneous distribution only ≈0.3 N internal nodes are
needed (rising to ≈0.65 N for clustered configurations) against ≈N for a binary tree;
the oct-tree avoids large node aspect ratios, which keeps higher-order multipoles small;
and its clean geometry makes it usable as a **range-searching tool for SPH neighbour
finding**, i.e. one structure for both jobs. Monopoles were chosen over GADGET-1's
octopoles specifically for memory efficiency and cheap dynamic updates. This is a
deliberate regression in multipole order justified by implementation economics — worth
noting, because it shows the "obvious" accuracy choice is not always the production one.

**GADGET-4** (Springel et al. 2021, MNRAS 506, 2871, doi:10.1093/mnras/stab1855) adds a
**manifestly momentum-conserving FMM** as an alternative to the one-sided TreePM walk,
motivated explicitly by high-dynamic-range zoom calculations with extreme variability of
particle number density.

**PKDGRAV3** (Potter, Stadel & Teyssier 2017, Comput. Astrophys. Cosmol. 4, 2,
doi:10.1186/s40668-017-0021-1) uses a **balanced binary k-d tree** with FMM. The
concrete structural parameters, from the paper: leaf cells hold up to **b ≈ 16**
particles ("bucket size", stated optimum); traversal stops at a **group size g = 64**,
"or more generally four times the bucket size". Multipoles are stored to **4th order**
because "for the needed force accuracy of better than 0.1% RMS, going to 4th order
moments is more than twice as efficient" than quadrupoles; the local expansion about the
sink centre of mass is carried to **5th order** but not stored. Interactions are
computed in single precision and accumulated in double, giving force errors "around
10⁻⁵%". A deliberate asymmetry factor of 1.5 in the opening criterion controls the
*spatial correlation* of force errors — the paper's point being that Barnes–Hut errors
add up coherently and correlate with local density, whereas FMM errors do not.

**ChaNGa** (Menon et al. 2015, Comput. Astrophys. Cosmol. 2, 1,
doi:10.1186/s40668-015-0007-9; original Jetley et al. 2008, doi:10.1109/ipdps.2008.4536319)
uses a tree over space-filling-curve keys with Charm++ over-decomposition. The choice is
driven by clustering: load is balanced by migrating tree pieces, not by geometric
bisection. Demonstrated to 512k cores at 12–24×10⁹ particles.

**Bonsai** (Bédorf, Gaburov & Portegies Zwart 2012, J. Comput. Phys. 231, 2825,
doi:10.1016/j.jcp.2011.12.024, arXiv:1106.1900) is the reference GPU tree code: a
**sparse oct-tree built and traversed entirely on the GPU** using parallel scan and sort
primitives, with monopole + quadrupole moments and Barnes-style group traversal. The
authors' reason for full GPU residency is to remove the host round-trip that dominated
earlier GPU tree codes, and their reason for using only scan/sort primitives is
portability — the paper states the algorithms are portable to OpenCL and to many-core
devices from other manufacturers. **This is the most directly relevant code paper for
your project.**

**Abacus** (Garrison et al. 2021, MNRAS 508, 575, doi:10.1093/mnras/stab2482) is the
most interesting counter-example for you, because it keeps a **uniform static cell
grid** and still gets exact gravity. It splits near and far field *analytically*: near
field reduces to direct 1/r² summation within a small integer number of cells, far field
to a **discrete convolution over multipoles on a static mesh**. Median fractional force
error 10⁻⁵. The lesson: a uniform grid is fine as long as the far field is a
convolution, never a truncated sample.

**SWIFT** (Schaller et al. 2024, MNRAS 530, 2378, doi:10.1093/mnras/stae922) uses FMM at
**default order p = 4** (compile-time selectable; p = 5 costs 56 numbers per cell per
expansion), over a hierarchical cell grid with **large leaf cells holding many
particles** so the multipole storage is amortised and the leaf–leaf P2P kernels
vectorise. Its MAC is built on the Salmon & Warren (1994) error analysis, not on a bare
opening angle.

**Phantom** (Price et al. 2018, PASA 35, e031, doi:10.1017/pasa.2018.25) is the SPH code
whose structure most resembles what you need, and its design contains the specific
answer to your bug. It builds a **k-d tree by recursive bisection of the longest axis**,
refining until a cell holds fewer than **N_min = 10** particles (default). Then:
*the neighbour search is performed once per leaf node*, and the long-range gravitational
interaction is evaluated **once per leaf node** using Cartesian multipoles (Dehnen 2000
formulation) and Taylor-expanded to second order onto the individual particles. Phantom
does maintain a fixed-size **cache** of neighbour positions — but read the pseudo-code:
`if (n <= cache size) get j position from cache else get j position from memory`. The
cache bounds *memory locality*, never the neighbour list. Nothing is discarded. That is
the distinction your implementation is missing.

**RAMSES** (Teyssier 2002, A&A 385, 337, doi:10.1051/0004-6361:20011817) and **Enzo**
(Bryan et al. 2014, ApJS 211, 19, doi:10.1088/0067-0049/211/2/19) refine the *mesh* on
density and solve Poisson on the refined hierarchy. This is the direct structural answer
to unbounded density contrast: the grid follows the matter instead of the matter
overflowing the grid.

**NBODY6 / NBODY6++GPU** (Nitadori & Aarseth 2012, arXiv:1205.1222; Wang et al. 2015,
MNRAS 450, 4070, arXiv:1504.03687; lineage reviewed in Aarseth 1999, PASP 111, 1333,
doi:10.1086/316455) is the gold standard for *collisional* stellar dynamics — which is
what black-hole seed dynamics in a dense core actually is. It uses **exact direct
summation** split by the Ahmad & Cohen (1973, J. Comput. Phys. 12, 389,
doi:10.1016/0021-9991(73)90160-5) neighbour scheme: a per-particle neighbour list with
an *adaptive radius* separates the "irregular" (near) force from the "regular" (far)
force. The regular force involves ~99% of the particles but is updated up to ~20× less
often. No multipoles, no capacity parameter, exact forces.

**2HOT** (Warren 2013, arXiv:1310.4502; original Warren & Salmon 1993,
doi:10.1145/169627.169640) deserves special mention because it *is* a spatial hash — but
it hashes **tree cells** keyed on a Morton/Hilbert index that encodes the level, not
fixed-size regions of space. Capacity is therefore never fixed. This is the correct way
to build a hash-based particle code.

### 1.3 The multipole acceptance criterion is not optional

The one thing every code paper agrees on and that a naive Barnes–Hut implementation gets
wrong: **the bare opening angle θ does not bound the force error.** Salmon & Warren
(1994, "Skeletons from the treecode closet", J. Comput. Phys. 111, 136,
doi:10.1006/jcph.1994.1050) showed that the standard BH criterion admits unbounded
worst-case errors, and constructed the pathological configurations. Every subsequent
production code uses either a mass- or multipole-magnitude-based criterion (GADGET-2's
relative criterion; SWIFT's, explicitly derived from Salmon & Warren; PKDGRAV3's
asymmetric opening radii) or accepts documented error tails. If you implement a tree,
implement the MAC from Salmon & Warren, not from the 1986 Nature paper.

---

## 2. The density problem

### 2.1 What is actually wrong with a fixed-capacity uniform cell

Your densest cell holds 334,576 particles with a cap of 32.

    fraction of the densest cell sampled = 32 / 334,576 = 9.564×10⁻⁵  (0.0096%)
    that cell holds 334,576 / 2,000,000 = 16.7% of the total field mass
    maximum samples per neighbour query = 32 × 27 = 864
                                                        [MY ARITHMETIC]

Two distinct errors are superposed, and they have different fixes. **Which one dominates
depends on a detail of your implementation that I do not have:** whether the 32 retained
particles are re-weighted by n_true/32.

- **If they are not re-weighted**, the near-field force from the core cell is too small
  by a factor ≈10⁴. This is not noise, it is a systematic mass deficit: the core of your
  field is gravitationally almost absent. That alone would explain a run-to-run fork in
  black-hole growth, because whether a seed grows at all then depends on which 32
  particles it happens to see.
- **If they are re-weighted**, the estimator is unbiased but the per-cell force carries
  fractional noise 1/√32 = 17.7% (13% at a cap of 64), **resampled independently every
  frame**. That is white noise injected into the acceleration field.

Either way there is a third, structural problem: **a hard 27-cell stencil is not
gravity.** If the gravitational force is summed only over the 3×3×3 neighbourhood, the
interaction is truncated at ~1.5 cell widths. A truncated 1/r² force has no long-range
attraction, so global collapse, orbital dynamics, and the virial relation are all
governed by the cutoff rather than by Newton's law. This is a larger error than the
sampling cap and it is not fixed by raising the cap. Every code in §1 either walks a tree
to the top of the hierarchy or adds a mesh/convolution far field precisely to avoid this.
If SPACE SYNTH already has a separate long-range solve, ignore this paragraph — but the
brief as written describes gravity computed from the 27-cell scan.

### 2.2 How real codes handle a cell that wants 300,000 particles

Four mechanisms, in order of how directly they apply:

1. **Tree depth instead of cell capacity.** An oct-tree or k-d tree subdivides until the
   leaf occupancy falls below a target (Phantom N_min = 10; PKDGRAV3 b ≈ 16; SWIFT
   deliberately larger). Depth grows as log of the local density contrast, so a
   334,576-particle region becomes ~15 extra levels, not an overflow. **There is no
   capacity parameter anywhere in a tree code.** This is the answer.
2. **Mesh refinement.** RAMSES and Enzo refine the grid where the particle count per
   cell exceeds a threshold. Structurally identical to (1) with a different solver.
3. **Per-particle adaptive smoothing lengths.** In SPH, h_i is set by requiring a fixed
   *number* of neighbours (or, in the modern formulation, by an implicit density–h
   relation). h ∝ n^(-1/3) locally (Price & Monaghan 2007, MNRAS 374, 1347,
   arXiv:astro-ph/0610872, citing Nelson & Papaloizou 1994, MNRAS 270, 1,
   doi:10.1093/mnras/270.1). This automatically shrinks the search radius where the
   density is high, so the neighbour count stays bounded *because the physics adapts*,
   not because the container is capped.
4. **Bounding the neighbour list by adapting the support radius, not by discarding
   neighbours.** This is the one paper I found that is directly about your problem:
   Winchenbach, Hochstetter & Kolb (2016), "Constrained neighbor lists for SPH-based
   fluid simulations", Symposium on Computer Animation, doi:10.5555/2982818.2982826.
   Their constraint is enforced by modifying the support radius so the true neighbour
   count meets the bound — the physics stays consistent. Discarding is never an option
   in that literature either.

Also worth knowing, and cheap: the standard GPU way to bin particles into a uniform grid
does **not** use a fixed capacity at all. You sort (cell key, particle index) pairs by
key with a radix sort and store per-cell begin/end offsets from the prefix sum. Capacity
is then exactly the true occupancy. This is the method in NVIDIA's *Particle Simulation
using CUDA* whitepaper (Green 2010 — grey literature, record located, no DOI) and, in
peer-reviewed form, Ihmsen et al. (2011), "A parallel SPH implementation on multi-core
CPUs", Computer Graphics Forum 30, 99, doi:10.1111/j.1467-8659.2010.01832.x, which also
introduces compact hashing for sparse domains. Cost estimate below (§3.3): **~0.3 ms at
2×10⁶ particles.** The cap is buying you nothing.

For completeness, the molecular-dynamics community solves the same problem two ways: a
**detect-and-reallocate** neighbour list (HOOMD-blue: Anderson et al. 2013,
arXiv:1308.5587; Glaser et al. 2015, arXiv:1412.3387 — the list is sized from a measured maximum and
rebuilt larger on overflow, never truncated), and **fixed-size particle clusters** rather
than fixed-capacity cells (Páll & Hess 2013, arXiv:1306.1737 — the GROMACS
cluster-pair-list algorithm, where 4×4 or 8×8 *particle* clusters are padded with dummy
particles to fill a SIMD width). Note the direction of that trick: the fixed size is
imposed on the *interaction tile*, and the deficit is filled with zero-mass dummies, so
no real particle is ever dropped. That is the SIMD-friendly version of what you were
trying to do, and it is exact.

### 2.3 Softening–smoothing consistency, and what breaks when they disagree

**The requirement.** For self-gravitating SPH, using a gravitational softening length
that differs from the SPH smoothing length produces unphysical results. This was
established by **Bate & Burkert (1997), MNRAS 288, 1060, doi:10.1093/mnras/288.4.1060**,
in the context of resolution requirements for self-gravitating SPH — the canonical
citation, and Price et al. (2018) and Price & Monaghan (2007) both cite it for exactly
this point. The physical reason: if ε < h, the gravitational force at small separations
is resolved on a scale where the pressure force is not, so a clump can collapse
gravitationally below the scale at which its own pressure support is computed —
artificial fragmentation. If ε > h, the converse: pressure is resolved where gravity is
smoothed, suppressing real collapse.

**The optimal-softening choice.** Two independent lines:

- *Force-error minimisation.* **Dehnen (2001), MNRAS 324, 273, arXiv:astro-ph/0011568**,
  "Towards optimal softening in 3D N-body codes: I. Minimizing the force error". Result,
  in the paper's own terms: **Plummer softening yields significantly larger force errors
  than replacing bodies with density kernels of finite extent.** Dehnen also gives
  special compensating kernels that exceed the Newtonian force near r ~ ε to offset the
  deficit at r < ε. **This is a direct finding against your current choice.** Plummer
  softening has an infinite tail — every pair interaction is modified at all separations
  — whereas a compact spline kernel (Monaghan & Lattanzio 1985, A&A 149, 135; record
  located, no DOI) is exactly Newtonian beyond its support. Every code in §1 that softens
  uses a compact kernel, not Plummer. Related: Athanassoula et al. (2000),
  arXiv:astro-ph/9912467, and Merritt (1996), arXiv:astro-ph/9511146, on optimal
  smoothing; Barnes (2012), arXiv:1205.2729, on softening as a smoothing operation.
- *Convergence in the mean field.* **Power et al. (2003), MNRAS 338, 14,
  arXiv:astro-ph/0201544**, eq. 15:

        ε_opt ≈ 4 ε_acc = 4 r₂₀₀ / √N₂₀₀

  i.e. optimal softening is 4× the scale at which pairwise accelerations become
  comparable to the mean-field acceleration. Regime of validity: fitted to
  dissipationless cold-dark-matter halo simulations at 32³–128³ particles, for
  *converged inner density profiles*. It is a MODEL for that problem, not a universal
  law, and it should not be quoted for a collisional star cluster.

Evaluating eq. 15 for your N (MY ARITHMETIC — the relation is Power et al.'s, the
numbers are mine; full table in **softening-relaxation-table.csv**):

| N inside the system | ε_opt / R | ε_opt as 1/x of R | t_relax/t_cross at that N |
|---|---|---|---|
| 10⁵ | 0.0126 | R/79 | 869 |
| 10⁶ | 0.0040 | R/250 | 7,238 |
| **2×10⁶** | **0.00283** | **R/354** | **13,785** |
| 10⁷ | 0.00127 | R/791 | 62,042 |

So at 2×10⁶ particles the Power-optimal softening is ~0.3% of the system radius. **Your
softening is one cell width.** If the hash grid is 128³ over the field, one cell is
R/64 ≈ 1.6% of R — about 5.5× larger than ε_opt, and that is *before* the sampling cap.
A softening 5× too large suppresses exactly the small-scale structure from which black
holes are supposed to emerge.

**Conservation problems from spatially varying softening.** This is the part that is
usually got wrong. If you simply let ε vary from particle to particle:

- The pair interaction becomes **asymmetric** (particle a feels ε_a, particle b feels
  ε_b), so Newton's third law is violated and **linear and angular momentum are not
  conserved**. Symmetrising (e.g. ε_ab = max(ε_a, ε_b), or the arithmetic/geometric mean)
  restores momentum conservation — Phantom uses ε_ib = max(ε, ε_b) for sink–gas pairs.
- Even with a symmetric pair force, **energy is not conserved**, because the potential
  now depends explicitly on ε and hence on the local density, and the ∂/∂ε terms are
  missing from the equations of motion. Price & Monaghan (2007, MNRAS 374, 1347,
  arXiv:astro-ph/0610872) note this produces *secular increases in total energy*,
  destroying the phase-space conservation that N-body accuracy rests on, and cite
  Hernquist & Barnes (1990), Dehnen (2001) and Rodionov & Sotnikova (2005) for the
  effect.

**The fix, and the paper that established it: Price & Monaghan (2007).** They derive the
equations of motion from a Lagrangian in which both the softening of the force and the
variation of h are built in. The resulting extra "∇h"-type terms make **energy and
momentum conservation exact** (to time-integration accuracy) at essentially zero extra
cost, and they compute ε in the same way h is computed in SPH. Iannuzzi & Dolag (2011,
arXiv:1107.2942) implemented this in GADGET and found adaptive softening enhances
small-scale clustering — visible in the correlation-function amplitude and in the inner
profiles of massive objects — "thereby anticipating the results expected from much
higher resolution". Merlin et al. (2010) reported good energy conservation with the same
formalism, including on the Bate & Burkert (1997) isothermal-collapse test.

**Recommendation for SPACE SYNTH:** if you want adaptive softening — and you should,
given 10⁴ density contrast — implement the Price & Monaghan (2007) Lagrangian
formulation, with a compact spline kernel rather than Plummer, and set ε_i from the local
particle density exactly as an SPH h is set. Do not hand-roll a per-particle ε: you will
get a secular energy drift that looks like physics.

---

## 3. What is affordable on a GPU in real time

### 3.1 Published throughput, hardware named

All MEASUREMENTS, with the authors' hardware. Older numbers are on older hardware and
are marked.

| Code / method | Rate | Hardware | Accuracy stated | Source |
|---|---|---|---|---|
| Bonsai, BH tree traverse | **2.8×10⁶ particles/s** at θ = 0.75, N = 10⁶ | 1× GTX480 (**2010 hardware**, 1.345 TFLOPS peak FP32) | acceleration error nearly independent of N; comparable to CPU tree codes with quadrupole corrections | Bédorf et al. 2012 |
| Bonsai, same | 2.1×10⁶ particles/s | 1× Tesla C2050 (**2010**) | as above | Bédorf et al. 2012 |
| Bonsai, memory | ~1 GB device memory per 5×10⁶ particles | GTX480 | — | Bédorf et al. 2012 |
| Bonsai, accuracy/cost pair | galaxy merger, 240,002 bodies, dt = 1/64: **max energy error 2.8×10⁻⁴ at θ = 0.75 in 7,102 s** vs **1.3×10⁻⁴ at θ = 0.50 in 12,687 s** | 1× GTX480 (**2010**) | — | Bédorf et al. 2012, Table 2 |
| Bonsai at scale | 24.77 Pflops sustained (33.49 Pflops GPU), 242×10⁹ particles | 18,600 GPUs, Titan (**2014**) | — | Bédorf et al. 2014 |
| PKDGRAV3, FMM | **3.8×10⁶ particles/s/node** at N = 10¹² | Titan, 1× K20X per node (**2013**) | ~10⁻⁵ relative force error | Potter et al. 2017 |
| HACC | 1.7×10⁶ particles/s/node, same problem | as quoted by Potter et al. 2017 | — | Potter et al. 2017 |
| 2HOT | 1.2×10⁶ particles/s/node, same problem | as quoted by Potter et al. 2017 | — | Potter et al. 2017 |
| Abacus | **70×10⁶ particle updates/s/node** | Summit node = 6× V100 (**2018**) | median fractional force error 10⁻⁵ | Garrison et al. 2021 |
| GreeM, TreePM | 5×10⁴ particles/s/**CPU core** at θ = 0.5 | Cray XT4 (**2008**), >10⁶ particles/core | — | Ishiyama et al. 2009 |
| NBODY6++GPU, direct | 10⁶-body globular cluster with 5% binaries: **~1 h per half-mass crossing time** | 320 CPU cores + 32× K20X (**2013**) | exact forces | Wang et al. 2015 |

Two caveats that matter for interpreting these:

- PKDGRAV3's 3.8×10⁶/s/node is a **science rate** — it already includes the saving from
  individual adaptive timesteps. It is *not* a full-force-evaluation rate and must not be
  compared directly to Bonsai's traverse rate.
- Abacus quotes per *node*; a Summit node has 6 V100 GPUs. Dividing gives ~1.17×10⁷
  particle-updates/s/GPU (MY ARITHMETIC).

### 3.2 The honest answer: nothing meets 16 ms at full accuracy on one GPU

MY ARITHMETIC throughout this subsection. Assumptions stated; recompute if you disagree.

**Direct summation.** 2×10⁶ squared = 4×10¹² pairs. At the conventional 20 flop per
pairwise interaction:

    8×10¹³ flop / step
    ÷ 14×10¹² flop/s  →  5.7 s per step

356× over a 16 ms budget. Not a candidate; included as a reference point.

**Tree, scaled from Bonsai's measured rate.** Scaling Bédorf et al.'s 2.8×10⁶
particles/s by the peak-FP32 ratio to a modern Apple-class GPU:

    Apple GPU peak FP32 ~ 10–18 TFLOPS   [VENDOR-QUOTED SPECIFICATION for M1 Max
      through M4 Max, not a measurement, not peer-reviewed; treat as order-of-magnitude]
    ratio = 14×10¹² / 1.345×10¹² = 10.4
    scaled rate = 2.9×10⁷ particles/s
    2×10⁶ / 2.9×10⁷ = 69 ms per full force evaluation      (53 ms at 18 TF, 96 ms at 10 TF)

**This scaling is an upper bound on the achievable speedup, and I want to be explicit
about why.** Tree traversal is dominated by irregular memory access and divergent
control flow, not by arithmetic. Peak-FLOPS ratios overstate the gain for exactly this
kind of kernel. The true number is likely worse than 69 ms, not better.

**Abacus at its published per-GPU rate:** 2×10⁶ / 1.17×10⁷ = **171 ms** on one V100, at
10⁻⁵ force error.

So: **at full accuracy, a single-GPU gravity solve for 2×10⁶ particles costs 50–200 ms,
i.e. 3–12× the 16 ms frame budget. There is no published method that does it in 16 ms.
Anyone who tells you otherwise is either sampling the matter (which is your current bug)
or truncating the interaction range.**

### 3.3 Where the savings can honestly come from

**Raising the opening angle — smaller effect than you would hope.** From Bonsai's own
Table 2, the measured total wall time ratio for θ = 0.50 → 0.75 is 12,687/7,102 = 1.79
over a factor 1.5 in θ, implying an effective cost exponent of **1.43** (MY ARITHMETIC;
note this is total wall time including tree build and integration, so the traverse-only
exponent is steeper — the naive geometric expectation is 3). Projecting from 69 ms at
θ = 0.75:

| θ | conservative (exponent 1.43, from Bonsai's measured pair) | optimistic (exponent 3) |
|---|---|---|
| 1.0 | 45.5 ms | 28.9 ms |
| 1.2 | 35.0 ms | 16.8 ms |

Even at θ = 1.2 — where Salmon & Warren's error tails are severe and the force is no
longer trustworthy in dense regions — you are at best marginally inside budget. **The
opening angle is not the lever.**

**Hierarchical block timesteps — this is the lever.** The insight is old and universal:
you do not have to update every particle every step. Individual timesteps go back to
Aarseth's NBODY series (reviewed in Aarseth 1999, doi:10.1086/316455); the block/
power-of-two hierarchy that makes them vectorisable is McMillan (1986), "The
vectorization of small-N integrators", Lecture Notes in Physics, doi:10.1007/bfb0116406;
the near/far force split with different cadences is Ahmad & Cohen (1973,
doi:10.1016/0021-9991(73)90160-5); the adoption into tree-SPH is Hernquist & Katz (1989,
ApJS 70, 419, doi:10.1086/191344); and it is standard in GADGET-2, PKDGRAV3 (where the
paper credits it, jointly with FMM, for the fastest time-to-solution) and every code in
§1.

With rung k carrying fraction f_k of particles at step 2^k·dt_min, the mean fraction
updated per finest step is Σ f_k 2^(−k). For an **illustrative** (not measured)
distribution f = (0.02, 0.08, 0.20, 0.30, 0.40) over five rungs:

    Σ f_k 2^(−k) = 0.02 + 0.04 + 0.05 + 0.0375 + 0.025 = 0.1725      [MY ARITHMETIC]

**Cost at θ = 0.75 — Bonsai's tested, quadrupole-accurate setting — with 17% occupancy:
69 ms × 0.1725 = 11.8 ms.** Inside a 16 ms frame, at published force accuracy.

That is the whole result. You do not need to degrade the force calculation. You need to
stop recomputing forces you do not need.

**Two further free-ish savings:**

- **Exact prefix-sum cell list** (replacing the capped hash). Memory-traffic estimate: 4
  radix passes over 32-bit keys, 2×10⁶ × 8 B, read + write each pass = 128 MB of traffic;
  at 400 GB/s that is **0.32 ms** (0.64 ms at 200 GB/s, 0.23 ms at 546 GB/s). MY
  ARITHMETIC.
- **Particle-mesh far field.** A 256³ real transform pair at 5·M³·log₂(M³) flop each:
  4.0×10⁹ flop → **0.29 ms** at 14 TFLOPS; 512³ → 3.6×10¹⁰ flop → **2.6 ms**. MY
  ARITHMETIC, ignoring the (bandwidth-bound) mass assignment and force interpolation,
  which in practice dominate — so treat these as lower bounds.
- **Decouple physics steps from display frames.** Nothing requires one force evaluation
  per 16 ms frame. Render at 60 Hz by interpolating/extrapolating positions from the last
  physics state; run the physics at whatever cadence the integrator needs. This is
  standard real-time practice and it is honest, because the *physics* timestep is then set
  by the dynamical time rather than by the monitor.

![Wall time per gravity update at 2 million particles on one GPU, against a 16 ms frame budget]({{artifact:art_4789a30e-23ca-4e79-b6df-d316e7f7c56c}})

### 3.4 Apple Silicon specifics that change the calculus

These come from Apple's Metal developer documentation and the Metal Feature Set Tables —
**vendor documentation, not peer-reviewed literature.** I am flagging them as such
because no peer-reviewed astrophysical N-body paper I found benchmarks Apple Silicon.
That absence is itself a finding: **there is no published astrophysical N-body
performance measurement on Apple Silicon / Metal.** Any number you produce is new.

- **Unified memory is a genuine structural advantage.** The single largest cost in early
  GPU tree codes was the host↔device round trip for tree construction; Bonsai's stated
  contribution was eliminating it by keeping everything on the GPU. On Apple Silicon
  that round trip does not exist — CPU and GPU share physical memory with no copy. A
  hybrid design (tree build or rung assignment on CPU, force kernels on GPU) that would
  be a disaster on discrete hardware is cheap here. **This is worth exploiting and it is
  unexplored in the literature.**
- **SIMD group width is 32 on Apple GPUs.** Apple exposes SIMD-group functions
  (`simd_shuffle`, `simd_ballot`, `simd_prefix_exclusive_sum`, `simd_sum`, and the
  quad-group variants) in the Metal Shading Language, so the warp-shuffle-equivalent
  primitives that Bonsai's scan/sort algorithms need **do exist**. The specific list and
  availability by GPU family is in the Metal Shading Language Specification and Metal
  Feature Set Tables; check the tables for your target family rather than assuming.
  Bonsai's algorithms were chosen to depend only on parallel scan and sort — the paper
  says explicitly that this makes them portable to non-CUDA devices — which is exactly
  what makes it the right code to port.
- **Atomics.** Device-memory atomics on Apple GPUs are supported but relatively
  expensive; threadgroup (tile-local) atomics are much cheaper. The design implication is
  the same one the MD community reached: **avoid atomics in the inner loop.** A radix
  sort + prefix sum needs no per-particle atomic contention at all, and it is
  deterministic, which atomics are not (see §4).
- **Tile memory / threadgroup memory** is the right place for a group's shared
  interaction list — this is the Apple analogue of the shared-memory tiling that Bonsai's
  group traversal relies on (and that the GPU Gems 3 CUDA N-body chapter of Nyland,
  Harris & Prins popularised — **identifier not verified**).
- I have **no measured Apple-GPU numbers** for any of these. The 10–18 TFLOPS figures
  I used in §3.2 are vendor marketing specifications, and tree traversal will not achieve
  a large fraction of peak. **The first thing to do is measure a direct-summation kernel
  on your actual hardware** — it is trivial to write, it is pure arithmetic, and it gives
  you the machine's real achievable FP32 rate to anchor everything else.

---

## 4. Is their result a known failure mode?

### 4.1 The direct answer

**No. "Fixed-capacity per-cell binning with first-come selection" is not a named
pathology with its own literature in computational astrophysics.** I searched arXiv for
neighbour-list overflow, fixed-capacity binning, bucket overflow, non-deterministic
atomics with reproducibility in N-body and GPU particle codes, and bitwise
reproducibility in simulation — and got no hits describing this failure. I am not going
to invent a name for it.

The reason it is unnamed is that **in production codes the situation cannot arise.** In
the astrophysics codes of §1 the neighbour structure is hierarchical, so occupancy is
bounded by construction. In the MD and graphics codes that *do* use uniform cells, the
overflow case is handled — detect-and-reallocate (HOOMD-blue; Glaser et al. 2015,
arXiv:1412.3387), exact prefix-sum cell lists (Green 2010; Ihmsen et al. 2011,
doi:10.1111/j.1467-8659.2010.01832.x), padding with dummy particles rather than dropping
real ones (Páll & Hess 2013, arXiv:1306.1737), or constraining the support radius so the
true count meets the bound (Winchenbach et al. 2016, doi:10.5555/2982818.2982826).
Silently discarding real neighbours is not a design anyone published, so nobody
characterised its consequences.

### 4.2 What your symptoms *do* decompose into — all four with literature

**(a) Artificial two-body relaxation from undersampling.** This is the dominant effect
and it is very well characterised. The mechanism: a mean-field (collisionless) code
approximates a smooth potential; with too few effective particles, the granularity of
the mass distribution scatters orbits, transferring energy on the relaxation timescale.
Original physics: Chandrasekhar (1943), ApJ 97, 255, doi:10.1086/144517. The standard
scaling (CONVENTION, textbook form as in Binney & Tremaine, *Galactic Dynamics*, and
used in this form by Power et al. 2003 eq. 3):

    t_relax / t_cross ≈ 0.1 N / ln N

MY ARITHMETIC for your case:

    true core:           N = 334,576  →  t_relax/t_cross ≈ 2,630
    as sampled (32×27):  N = 864      →  t_relax/t_cross ≈ 12.8
    per-cell only:       N = 32       →  t_relax/t_cross ≈ 0.92

    artificial acceleration of relaxation ≈ 2,630 / 12.8 ≈ 206×

**Your core relaxes in about 13 crossing times instead of 2,600.** That is a factor
~200 of spurious collisional evolution — mass segregation, core collapse, energy
equipartition, ejection of light particles, and *sinking of heavy objects such as black
hole seeds*. It is not a subtle effect; on a real-time display it is the dominant
dynamics of the core.

Literature that measures this class of effect directly:
- Binney & Knebe (2002), MNRAS 333, 378, arXiv:astro-ph/0105183 — two-species tests
  detect two-body relaxation in both halo density profiles and the halo mass function;
  effects are *more pronounced with a fixed softening length* than with adaptive
  softening. (Note: this is Binney & Knebe, not Diemand et al.)
- Diemand et al. (2004), MNRAS 348, 977, arXiv:astro-ph/0304549 — two-body relaxation in
  CDM simulations.
- Power et al. (2003), arXiv:astro-ph/0201544 — makes "collisional relaxation timescale
  longer than the age of the universe" an explicit convergence criterion.
- Ludlow et al. (2019, arXiv:1812.05777; 2021, arXiv:2105.03561; 2023, arXiv:2306.05753)
  — spurious heating of stellar motions by dark-matter particles, i.e. exactly the
  cross-species energy transfer that afflicts a mixed field with seeds in it.
- Moore, Katz & Lake (1996), arXiv:astro-ph/9503088 — "overmerging": insufficient force
  and mass resolution *destroys* substructure. The complement of your problem.

**(b) A systematic near-field mass deficit** (if the 32 are not re-weighted). Not a named
effect — it is a straightforward discretisation error with no literature because nobody
builds it deliberately. The magnitude is the 9.6×10⁻⁵ figure in §2.1.

**(c) Truncation of the gravitational interaction range** at the 27-cell stencil. Well
understood in the sense that the entire TreePM/P³M literature exists to avoid it
(Hockney & Eastwood 1981; Xu 1995; Bagla 2002; Bode et al. 2000). Not a "failure mode" so
much as a different force law.

**(d) Non-determinism.** Here I want to draw a sharp distinction, because the standard
literature on this does **not** cover your case.

The known, documented problem is **floating-point non-associativity under
non-deterministic reduction order**: when parallel threads accumulate into a shared sum
in a scheduling-dependent order, the *rounding* differs run to run. Characterised in
Villa et al. (2009), "Effects of floating-point non-associativity on numerical
computations on massively multithreaded systems" (record located, no DOI) and solved by
reproducible summation algorithms — Demmel & Nguyen (2014), "Parallel Reproducible
Summation", IEEE Trans. Comput. 64, 2060, doi:10.1109/tc.2014.2345391. The GPU MD codes
document the same issue: GROMACS (Páll et al. 2020, J. Chem. Phys. 153, 134110,
doi:10.1063/5.0018516), OpenMM (Eastman et al. 2017, doi:10.1371/journal.pcbi.1005659),
HOOMD-blue (Glaser et al. 2015).

**Your non-determinism is categorically worse than that, and I have not found it
characterised anywhere.** Non-associativity changes the *rounding* of a sum over a fixed
set of terms — an error at the 10⁻⁷ level in FP32, which then amplifies through the
Lyapunov instability of the N-body problem. First-come atomic selection changes **which
terms are in the sum at all**. It is not a rounding difference; it is a different
physical system every frame. An 11× fork in maximum black-hole mass is entirely
consistent with that, and no reproducible-summation technique will fix it, because the
problem is not in the summation.

**And the smoking gun is the cap experiment itself.** Raising the cap from 32 to 64
reduced the fork from 11× to 3.4× *and quadrupled the number of black holes that form*.
A convergent numerical scheme does not change its answer by 4× when a purely structural
parameter doubles. **This is a demonstration that the result is not yet resolution-
converged in the sampling parameter — the standard test that a numerical result must
pass, and the one Power et al. (2003) formalised for exactly this class of question.**
The scaling of the fork with cap (11× → 3.4× as n → 2n) is consistent with a 1/√n
sampling-noise origin: √2 ≈ 1.41 reduction in noise amplitude, and a strongly non-linear
(threshold-crossing) response of seed growth to that noise.

For context on how genuinely sensitive black-hole seed dynamics is to numerical
resolution — an established result, not speculation — see Pfister et al. (2019), "The
erratic dynamical life of black hole seeds in high-redshift galaxies", arXiv:1902.01297.
That paper is about physical resolution, not about your bug, but it establishes that seed
dynamics is a regime where resolution changes the answer, so you should expect no
robustness there for free.

### 4.3 Time reversibility — a requirement you have that none of these codes has

SPACE SYNTH runs black holes backwards. That is a much stronger requirement than
accuracy, and it constrains the design:

- **The integrator must be time-symmetric.** Leapfrog/kick-drift-kick is exactly
  reversible **at fixed timestep**. Adaptive timesteps break both symplecticity and
  reversibility unless the step-selection rule is itself made time-symmetric — Hut,
  Makino & McMillan (1995), "Building a better leapfrog", ApJ 443, L93,
  doi:10.1086/187844, is the paper on this, and Dehnen & Read (2011), Eur. Phys. J. Plus
  126, 55, arXiv:1105.1082, review the trade-off. **This is in direct tension with the
  block-timestep recommendation in §3.3**, and you have to choose: reversible at fixed
  step, or affordable at adaptive step. A defensible compromise is to run reversible
  fixed-step during a "rewind-eligible" window and adaptive otherwise, and to say so.
- **The force must be bit-reproducible.** A fixed summation order (which requires
  eliminating scheduling-dependent atomics from the force accumulation, or using a
  reproducible-summation scheme à la Demmel & Nguyen 2014) is necessary. Your current
  design cannot be reversed even in principle.
- **Accretion and merger are dissipative and irreversible.** Running them backwards is a
  narrative choice, not a physical one. Say so rather than implying the code time-reverses
  a dissipative process.

---

## 5. Recommendation for 2×10⁶ particles, one GPU, real time

In priority order. Steps 1–2 are unambiguous corrections; steps 3–5 are the design.

1. **Replace the fixed-capacity hash with an exact prefix-sum cell list.** Radix-sort
   (cell key, particle id) pairs; store per-cell begin/end offsets from the prefix sum.
   Cost ~0.3 ms (MY ARITHMETIC, §3.3). Capacity becomes exactly the true occupancy; the
   cap disappears as a concept. Sort keyed on (cell, id) with a stable sort and the frame
   becomes deterministic. Method: Green (2010, NVIDIA whitepaper — grey literature);
   peer-reviewed form and compact hashing for sparse domains: Ihmsen et al. (2011),
   doi:10.1111/j.1467-8659.2010.01832.x. **Do this first. It is cheap, it is standard, and
   it removes the parameter that is currently deciding your astrophysics.**
2. **Replace Plummer softening with a compact spline kernel** (Monaghan & Lattanzio 1985
   cubic spline, as used by GADGET-2, Phantom and essentially every SPH/N-body code), on
   the authority of Dehnen (2001, arXiv:astro-ph/0011568): finite-extent density kernels
   give significantly smaller force errors than Plummer, and are exactly Newtonian
   outside their support. Set the scale from Power et al. (2003) eq. 15 as a starting
   point (ε ≈ 0.003 R at N = 2×10⁶), and state that this is a collisionless-halo
   prescription being applied outside its fitted regime.
3. **Build a GPU-resident sparse oct-tree on the same Morton keys and use it for
   gravity.** Follow Bonsai (Bédorf et al. 2012, doi:10.1016/j.jcp.2011.12.024): keys →
   sort → parallel-scan tree build → group traversal with a shared interaction list per
   leaf group. Use monopole + quadrupole. Modern GPU octree construction is documented in
   Keller et al. (2023), "Cornerstone: Octree Construction Algorithms for Scalable
   Particle Simulations", doi:10.1145/3592979.3593417 (which builds on Karras 2012, High
   Performance Graphics — **identifier not verified**). Adopt group sizes in the
   PKDGRAV3 range: leaf/bucket ~16, traversal group ~64 (Potter et al. 2017). Use a
   mass-based MAC per Salmon & Warren (1994), **not** a bare opening angle.
   *This is what makes the density contrast a non-issue: tree depth grows logarithmically
   where a uniform cell overflows.*
4. **Add hierarchical (power-of-two block) timesteps with force prediction.** This is
   where the frame budget actually comes from: §3.3 gives 11.8 ms at θ = 0.75 with 17%
   occupancy. Timestep criterion dt ∝ √(ε/|a|) (Power et al. 2003); block hierarchy per
   McMillan (1986); the near/far cadence split per Ahmad & Cohen (1973). Optionally
   **decouple physics steps from display frames** and interpolate for rendering.
5. **Optional: add a PM far field** on a 256³ mesh (~0.3 ms of FFT, MY ARITHMETIC; the
   bandwidth-bound assignment/interpolation will dominate) to bound tree depth and remove
   the need to walk to the root. This is the TreePM design of Xu (1995), Bode et al.
   (2000), Bagla (2002), and it is why GreeM, GADGET-2 and HACC all use it. Only worth it
   if you measure the traverse to be the bottleneck.

**If you want per-particle adaptive softening on top of this** (justified at 10⁴ density
contrast), implement it via the Price & Monaghan (2007) Lagrangian formulation
(arXiv:astro-ph/0610872), not by hand. Otherwise you will get secular energy growth.

### 5.1 What this recommendation gives up — stated honestly

- **Force accuracy.** At θ = 0.75 with quadrupoles you are at Bonsai's tested accuracy:
  max energy error 2.8×10⁻⁴ over their galaxy-merger test, acceleration errors
  comparable to CPU tree codes with quadrupole corrections. That is **1.5 orders of
  magnitude worse than PKDGRAV3 or Abacus** (10⁻⁵ relative force error). Consequence:
  you should not claim quantitative accretion rates or merger timescales.
- **Worst-case force error is not bounded by θ.** Salmon & Warren (1994) is the reason a
  mass-based MAC is in the recommendation, but even so the error *distribution* has a
  tail. Report median and 1st-percentile errors, as Bonsai does, not a single number.
- **Exact time reversibility, if you take the block timesteps.** See §4.3. You cannot
  have both adaptive stepping and exact reversal without a time-symmetric step criterion
  (Hut, Makino & McMillan 1995), and even then the force must be bit-reproducible.
- **Symplecticity.** Timestep changes break the symplectic property of leapfrog;
  long-term energy behaviour becomes drift rather than bounded oscillation.
- **The collisional regime.** At 2×10⁶ particles, t_relax/t_cross ≈ 1.4×10⁴ globally (MY
  ARITHMETIC, §2.3 table) but far less in the core, and softening sets a floor below
  which two-body encounters are suppressed rather than resolved. Genuine
  black-hole-in-a-dense-cluster dynamics — binary hardening, three-body ejections, mass
  segregation timescales — is *not* accessible; that requires NBODY6/7-class direct
  integration with regularisation of close pairs. Say so.
- **The horizon.** r_s of a 50 M_☉ seed is 2.5×10⁻⁵ L (§0). Nothing here resolves it. The
  black hole is a sink particle with an analytic horizon, not a resolved object.
- **The 27-cell truncation must go.** No compromise available: either walk the tree to
  the root or add a mesh far field. A truncated force is a different force law.

---

## 6. Model-dependent, and what the literature does not settle

**Model- or convention-dependent (name of the model, and what changes under an
alternative):**

- **Optimal softening.** Power et al. (2003) ε_opt = 4 r₂₀₀/√N₂₀₀ is a fit to
  dissipationless CDM halo convergence at 32³–128³ particles, judged on inner density
  profiles. Dehnen (2001) minimises the *mean-square force error* instead and reaches a
  different optimum with a different kernel-dependence. Merritt (1996) and Athanassoula
  et al. (2000) optimise other error measures again. **These give different numbers.**
  There is no single "correct" softening; the answer depends on which error you choose to
  minimise. State your choice.
- **Multipole order.** GADGET-2 chose monopoles for memory efficiency; Wadsley et al.
  (2004, Gasoline, doi:10.1016/j.newast.2003.08.004) advocate hexadecapole; PKDGRAV3 and
  SWIFT use 4th order. Springel (2005) says explicitly that performance versus multipole
  order forms a **broad maximum** whose location "may depend sensitively on fine details
  of the software implementation". This is an implementation-dependent optimum, not a
  physical constant. Measure it on your hardware.
- **The MAC.** The opening criterion is a convention with an error analysis attached
  (Salmon & Warren 1994). Different codes use different criteria and get different error
  *distributions* at the same nominal θ. Bonsai reports that the minimum-distance MAC
  gives 10–50% smaller acceleration error at the same θ but costs ~3× more time.
- **Adaptive vs fixed softening.** Binney & Knebe (2002) find two-body relaxation effects
  are *less* pronounced with adaptive softening; Iannuzzi & Dolag (2011) find adaptive
  softening enhances small-scale clustering. Whether that enhancement is convergence
  toward the truth or an artefact of the ε-h coupling is a modelling judgement.
- **Timestep criterion.** dt ∝ √(ε/|a|) is one of several in use (others: dt ∝ h/c_s,
  dt from the local dynamical time, Rodionov & Sotnikova 2005, arXiv:astro-ph/0504573). They give
  different rung populations and therefore different frame costs.
- **My 10–18 TFLOPS Apple GPU figures** are vendor specifications, not measurements, and
  the flop-ratio scaling of Bonsai's rate is a modelling assumption that is optimistic
  for a memory-bound kernel.

**What the literature does not settle:**

1. **There is no published astrophysical N-body performance measurement on Apple Silicon
   or Metal.** Every throughput number in §3 is CUDA-on-NVIDIA. Whether the unified
   memory architecture helps tree construction as much as it should, and what the real
   achievable fraction of peak is for a divergent traversal kernel on an Apple GPU, is
   unmeasured. **This is the single largest uncertainty in my cost estimates, and you can
   settle it in an afternoon** by benchmarking a direct-summation kernel (to get real
   achievable FP32) and a Bonsai-style traverse (to get the real traversal efficiency) on
   your actual hardware.
2. **No characterisation of fixed-capacity neighbour truncation exists** (§4.1). The
   quantitative relationship between a per-cell sampling cap n, the induced artificial
   relaxation rate, and the divergence of a derived quantity like maximum black-hole mass
   has not, as far as I can find, been published. Your cap-32-vs-64 experiment is
   original data. If you extended it — caps of 16/32/64/128/256/exact, with the fork in
   max BH mass and BH count measured at each — that would be a publishable convergence
   study, and it is the calculation that would settle the question for your system.
3. **What the optimal accuracy/cost operating point is for a real-time
   collisionless-plus-sink-particle system** is not addressed anywhere. All the code
   papers optimise time-to-solution for an offline run of fixed total accuracy. Nobody has
   asked what force accuracy is *sufficient* for a system whose output is a display at
   60 Hz and whose scientific claim is qualitative. That is a genuinely open question and
   the honest answer is that it depends on which claims you want to make.
4. **Whether adaptive-softening formulations converge to the same answer as
   fixed-softening at higher resolution** is not settled — Iannuzzi & Dolag (2011)
   present the enhanced clustering as anticipating higher resolution, which is a
   plausible interpretation rather than a demonstration.
5. **Time-reversible adaptive timestepping at scale.** Time-symmetric criteria exist
   (Hut, Makino & McMillan 1995) but I found no production code at 10⁶+ particles that
   uses them, and no measurement of what they cost. If SPACE SYNTH needs exact reversal
   with adaptive steps, you are in unmeasured territory.

---

## 7. References

**Count: 92 of 98 identifiers below were retrieved with a literature tool in this session (arXiv API / OpenAlex). 4 more are records the tool located but for which no DOI exists in the index. 2 are unverified and marked as such. First-author attributions for the arXiv entries were checked against the API, which corrected one of my own draft attributions (astro-ph/0504573 is Rodionov & Sotnikova, not Zemp et al.).**

Verification status is marked for every entry. **✓** = identifier retrieved with a
literature tool in this session (arXiv API or OpenAlex). **○** = record located by tool
but no DOI exists in the index (volume/page confirmed where shown). **✗** = identifier
not verified; cited by author, year and venue only.

### Algorithms — foundational

1. ✓ Appel, A. W. 1985, "An Efficient Program for Many-Body Simulation", SIAM J. Sci. Stat. Comput. 6, 85. doi:10.1137/0906008
2. ✓ Barnes, J. & Hut, P. 1986, "A hierarchical O(N log N) force-calculation algorithm", Nature 324, 446. doi:10.1038/324446a0
3. ✓ Greengard, L. & Rokhlin, V. 1987, "A fast algorithm for particle simulations", J. Comput. Phys. 73, 325. doi:10.1016/0021-9991(87)90140-9
4. ✓ Barnes, J. E. 1990, "A modified tree code: Don't laugh; It runs", J. Comput. Phys. 87, 161. doi:10.1016/0021-9991(90)90232-p
5. ✓ Warren, M. S. & Salmon, J. K. 1993, "A parallel hashed Oct-Tree N-body algorithm", Proc. Supercomputing '93, 12. doi:10.1145/169627.169640
6. ✓ Salmon, J. K. & Warren, M. S. 1994, "Skeletons from the Treecode Closet", J. Comput. Phys. 111, 136. doi:10.1006/jcph.1994.1050
7. ✓ Dehnen, W. 2000, "A Very Fast and Momentum-Conserving Tree Code", arXiv:astro-ph/0003209
8. ✓ Dehnen, W. 2002, "A Hierarchical O(N) Force Calculation Algorithm", arXiv:astro-ph/0202512
9. ✓ Hockney, R. W. & Eastwood, J. W. 1988, *Computer Simulation Using Particles*. doi:10.1201/9780367806934
10. ✓ Efstathiou, G. et al. 1985, "Numerical techniques for large cosmological N-body simulations", ApJS 57, 241. doi:10.1086/191003
11. ✓ Couchman, H. M. P. 1991, "Mesh-refined P³M: A fast adaptive N-body algorithm", ApJ 368, L23. doi:10.1086/185939
12. ✓ Xu, G. 1995, "A New Parallel N-body Gravity Solver: TPM", arXiv:astro-ph/9409021
13. ✓ Bode, P., Ostriker, J. P. & Xu, G. 2000, "The Tree Particle-Mesh N-Body Gravity Solver", ApJS 128, 561. doi:10.1086/313398
14. ✓ Bagla, J. S. 2002, "TreePM: A code for Cosmological N-Body Simulations", JApA 23, 185. arXiv:astro-ph/9911025
15. ✓ Yokota, R. & Barba, L. A. 2011, "A Tuned and Scalable Fast Multipole Method as a Preeminent Algorithm for Exascale Systems", arXiv:1106.2176
16. ✗ Karras, T. 2012, "Maximizing Parallelism in the Construction of BVHs, Octrees, and k-d Trees", High Performance Graphics. *(identifier not verified)*
17. ✓ Keller, S. et al. 2023, "Cornerstone: Octree Construction Algorithms for Scalable Particle Simulations", PASC '23. doi:10.1145/3592979.3593417

### Time integration

18. ✓ Ahmad, A. & Cohen, L. 1973, "A numerical integration scheme for the N-body gravitational problem", J. Comput. Phys. 12, 389. doi:10.1016/0021-9991(73)90160-5
19. ✓ McMillan, S. L. W. 1986, "The vectorization of small-N integrators", Lecture Notes in Physics. doi:10.1007/bfb0116406
20. ✓ Makino, J. & Aarseth, S. J. 1992, "On a Hermite Integrator with Ahmad-Cohen Scheme", PASJ 44, 141. doi:10.1093/pasj/44.2.141
21. ✓ Hut, P., Makino, J. & McMillan, S. 1995, "Building a better leapfrog", ApJ 443, L93. doi:10.1086/187844
22. ✓ Aarseth, S. J. 1999, "From NBODY1 to NBODY6: The Growth of an Industry", PASP 111, 1333. doi:10.1086/316455
23. ✓ Nitadori, K. & Makino, J. 2008, "Sixth- and eighth-order Hermite integrator for N-body simulations", New Astron. 13, 498. doi:10.1016/j.newast.2008.01.010
24. ✓ Rodionov, S. A. & Sotnikova, N. Ya. 2005, "Optimal Choice of the Softening Length and Time-Step in N-body Simulations", arXiv:astro-ph/0504573
25. ✓ Dehnen, W. & Read, J. I. 2011, "N-body simulations of gravitational dynamics", Eur. Phys. J. Plus 126, 55. arXiv:1105.1082

### Code papers

26. ✓ Springel, V. et al. 2001, "GADGET: A code for collisionless and gasdynamical cosmological simulations", New Astron. 6, 79. arXiv:astro-ph/0003162
27. ✓ Springel, V. 2005, "The cosmological simulation code GADGET-2", MNRAS 364, 1105. doi:10.1111/j.1365-2966.2005.09655.x, arXiv:astro-ph/0505010
28. ✓ Springel, V. et al. 2021, "Simulating cosmic structure formation with the GADGET-4 code", MNRAS 506, 2871. doi:10.1093/mnras/stab1855, arXiv:2010.03567
29. ✓ Springel, V. 2010, "E pur si muove: Galilean-invariant cosmological hydrodynamical simulations on a moving mesh" (AREPO), MNRAS 401, 791. doi:10.1111/j.1365-2966.2009.15715.x, arXiv:0901.4107
30. ✓ Weinberger, R., Springel, V. & Pakmor, R. 2020, "The Arepo public code release", arXiv:1909.04667
31. ✓ Potter, D., Stadel, J. & Teyssier, R. 2017, "PKDGRAV3: Beyond Trillion Particle Cosmological Simulations", Comput. Astrophys. Cosmol. 4, 2. doi:10.1186/s40668-017-0021-1, arXiv:1609.08621
32. ○ Stadel, J. 2001, PhD thesis, University of Washington (PKDGRAV) *(record located, no DOI)*
33. ✓ Jetley, P. et al. 2008, "Massively parallel cosmological simulations with ChaNGa", IPDPS. doi:10.1109/ipdps.2008.4536319
34. ✓ Menon, H. et al. 2015, "Adaptive Techniques for Clustered N-Body Cosmological Simulations" (ChaNGa), Comput. Astrophys. Cosmol. 2, 1. doi:10.1186/s40668-015-0007-9, arXiv:1409.1929
35. ✓ Bédorf, J., Gaburov, E. & Portegies Zwart, S. 2012, "A sparse octree gravitational N-body code that runs entirely on the GPU processor" (Bonsai), J. Comput. Phys. 231, 2825. doi:10.1016/j.jcp.2011.12.024, arXiv:1106.1900
36. ✓ Bédorf, J. et al. 2014, "24.77 Pflops on a Gravitational Tree-Code to Simulate the Milky Way Galaxy with 18600 GPUs", arXiv:1412.0659
37. ✓ Hopkins, P. F. 2015, "A new class of accurate, mesh-free hydrodynamic simulation methods" (GIZMO), MNRAS 450, 53. doi:10.1093/mnras/stv195, arXiv:1409.7395
38. ✓ Hopkins, P. F. 2013, "A General Class of Lagrangian Smoothed Particle Hydrodynamics Methods", arXiv:1206.5006
39. ✓ Garrison, L. H. et al. 2021, "The Abacus Cosmological N-body Code", MNRAS 508, 575. doi:10.1093/mnras/stab2482, arXiv:2110.11392
40. ✓ Ishiyama, T., Fukushige, T. & Makino, J. 2009, "GreeM: Massively Parallel TreePM Code", PASJ 61, 1319. arXiv:0910.0121
41. ✓ Habib, S. et al. 2015, "HACC: Simulating sky surveys on state-of-the-art supercomputing architectures", New Astron. 42, 49. doi:10.1016/j.newast.2015.06.003, arXiv:1410.2805
42. ✓ Warren, M. S. 2013, "2HOT: An Improved Parallel Hashed Oct-Tree N-Body Algorithm", arXiv:1310.4502
43. ✓ Teyssier, R. 2002, "Cosmological hydrodynamics with adaptive mesh refinement" (RAMSES), A&A 385, 337. doi:10.1051/0004-6361:20011817, arXiv:astro-ph/0111367
44. ✓ Bryan, G. L. et al. 2014, "Enzo: An Adaptive Mesh Refinement Code for Astrophysics", ApJS 211, 19. doi:10.1088/0067-0049/211/2/19, arXiv:1307.2265
45. ✓ Price, D. J. et al. 2018, "Phantom: A SPH and MHD Code for Astrophysics", PASA 35, e031. doi:10.1017/pasa.2018.25, arXiv:1702.03930
46. ✓ Schaller, M. et al. 2024, "Swift: a modern highly parallel gravity and SPH solver", MNRAS 530, 2378. doi:10.1093/mnras/stae922, arXiv:2305.13380
47. ✓ Gonnet, P. et al. 2013, "SWIFT: Fast algorithms for multi-resolution SPH on multi-core architectures", arXiv:1309.3783
48. ✓ Wadsley, J. W., Stadel, J. & Quinn, T. 2004, "Gasoline: a flexible, parallel implementation of TreeSPH", New Astron. 9, 137. doi:10.1016/j.newast.2003.08.004
49. ✓ Wadsley, J. W., Keller, B. W. & Quinn, T. R. 2017, "Gasoline2: a modern SPH code", MNRAS 471, 2357. doi:10.1093/mnras/stx1643
50. ✓ Hernquist, L. & Katz, N. 1989, "TREESPH: A unification of SPH with the hierarchical tree method", ApJS 70, 419. doi:10.1086/191344
51. ✓ Nitadori, K. & Aarseth, S. J. 2012, "Accelerating NBODY6 with Graphics Processing Units", arXiv:1205.1222
52. ✓ Wang, L. et al. 2015, "NBODY6++GPU: Ready for the gravitational million-body problem", MNRAS 450, 4070. arXiv:1504.03687
53. ✓ Belleman, R. G., Bédorf, J. & Portegies Zwart, S. F. 2008, "High Performance Direct Gravitational N-body Simulations on GPUs II", New Astron. 13, 103. arXiv:0707.0438
54. ✓ Gaburov, E., Harfst, S. & Portegies Zwart, S. 2009, "SAPPORO: A way to turn your graphics cards into a GRAPE-6", arXiv:0902.4463
55. ✓ Makino, J. 1991, "Treecode with a Special-Purpose Processor", PASJ 43, 621. doi:10.1093/pasj/43.4.621
56. ✓ Hubber, D. A. et al. 2011, "SEREN — a new SPH code for star and planet formation simulations", A&A 529, A27. doi:10.1051/0004-6361/201014949

### Softening, smoothing, conservation

57. ○ Monaghan, J. J. & Lattanzio, J. C. 1985, "A refined particle method for astrophysical problems", A&A 149, 135 *(record located, no DOI)*
58. ✓ Gingold, R. A. & Monaghan, J. J. 1977, MNRAS 181, 375. doi:10.1093/mnras/181.3.375
59. ✓ Lucy, L. B. 1977, AJ 82, 1013. doi:10.1086/112164
60. ✓ Nelson, R. P. & Papaloizou, J. C. B. 1994, "Variable smoothing lengths and energy conservation in SPH", MNRAS 270, 1. doi:10.1093/mnras/270.1
61. ✓ Bate, M. R. & Burkert, A. 1997, "Resolution requirements for SPH calculations with self-gravity", MNRAS 288, 1060. doi:10.1093/mnras/288.4.1060
62. ✓ Merritt, D. 1996, "Optimal Smoothing for N-Body Codes", arXiv:astro-ph/9511146
63. ✓ Athanassoula, E. et al. 2000, "Optimal softening for force calculations in collisionless N-body simulations", arXiv:astro-ph/9912467
64. ✓ Dehnen, W. 2001, "Towards optimal softening in 3D N-body codes: I. Minimizing the force error", MNRAS 324, 273. arXiv:astro-ph/0011568
65. ✓ Springel, V. & Hernquist, L. 2002, "Cosmological SPH simulations: the entropy equation", MNRAS 333, 649. arXiv:astro-ph/0111016
66. ✓ Price, D. J. & Monaghan, J. J. 2007, "An energy-conserving formalism for adaptive gravitational force softening", MNRAS 374, 1347. arXiv:astro-ph/0610872
67. ✓ Iannuzzi, F. & Dolag, K. 2011, "Adaptive gravitational softening in GADGET", arXiv:1107.2942
68. ✓ Barnes, J. E. 2012, "Gravitational softening as a smoothing operation", arXiv:1205.2729
69. ✓ Dehnen, W. & Aly, H. 2012, "Improving convergence in SPH simulations without pairing instability", arXiv:1204.2471
70. ✓ Zhu, Q., Hernquist, L. & Li, Y. 2015, "Numerical Convergence in Smoothed Particle Hydrodynamics", arXiv:1410.4222
71. ✓ Price, D. J. 2012, "Smoothed Particle Hydrodynamics and Magnetohydrodynamics", arXiv:1012.1885
72. ✓ Springel, V. 2010, "Smoothed Particle Hydrodynamics in Astrophysics", ARA&A 48, 391. arXiv:1109.2219

### Discreteness, relaxation, convergence

73. ✓ Chandrasekhar, S. 1943, "Dynamical Friction. I.", ApJ 97, 255. doi:10.1086/144517
74. ✓ Moore, B., Katz, N. & Lake, G. 1996, "On the Destruction and Over-Merging of Dark Halos in Dissipationless N-body Simulations", arXiv:astro-ph/9503088
75. ✓ Binney, J. & Knebe, A. 2002, "Two-Body Relaxation in Cosmological Simulations", MNRAS 333, 378. arXiv:astro-ph/0105183
76. ✓ Power, C. et al. 2003, "The Inner Structure of ΛCDM Halos I: A Numerical Convergence Study", MNRAS 338, 14. arXiv:astro-ph/0201544
77. ✓ Diemand, J. et al. 2004, "Two body relaxation in CDM simulations", MNRAS 348, 977. arXiv:astro-ph/0304549
78. ✓ Joyce, M. et al. 2007, "Quantification of discreteness effects in cosmological N-body simulations II", arXiv:0704.3697
79. ✓ Ludlow, A. D. et al. 2019, "Numerical convergence of simulations of galaxy formation", arXiv:1812.05777
80. ✓ Ludlow, A. D. et al. 2021, "Spurious heating of stellar motions in simulated galactic disks by dark matter particles", arXiv:2105.03561
81. ✓ Ludlow, A. D. et al. 2023, "Spurious heating of stellar motions by dark matter particles in cosmological simulations", arXiv:2306.05753
82. ✓ Pfister, H. et al. 2019, "The erratic dynamical life of black hole seeds in high-redshift galaxies", arXiv:1902.01297

### Neighbour lists, GPU binning, determinism (MD and graphics)

83. ✓ Verlet, L. 1967, "Computer 'Experiments' on Classical Fluids I", Phys. Rev. 159, 98. doi:10.1103/physrev.159.98
84. ✓ Quentrec, B. & Brot, C. 1973, "New method for searching for neighbors in molecular dynamics computations", J. Comput. Phys. 13, 430. doi:10.1016/0021-9991(73)90046-6
85. ○ Green, S. 2010, "Particle Simulation using CUDA", NVIDIA technical whitepaper *(grey literature; record located, no DOI)*
86. ✓ Ihmsen, M. et al. 2011, "A Parallel SPH Implementation on Multi-Core CPUs", Computer Graphics Forum 30, 99. doi:10.1111/j.1467-8659.2010.01832.x
87. ✓ Winchenbach, R., Hochstetter, H. & Kolb, A. 2016, "Constrained neighbor lists for SPH-based fluid simulations", Symposium on Computer Animation, 49. doi:10.5555/2982818.2982826
88. ✓ Howard, M. P. et al. 2016, "Efficient neighbor list calculation for molecular simulation of colloidal systems using GPUs", Comput. Phys. Commun. 203, 45. doi:10.1016/j.cpc.2016.02.003
89. ✓ Páll, S. & Hess, B. 2013, "A flexible algorithm for calculating pair interactions on SIMD architectures", arXiv:1306.1737
90. ✓ Glaser, J. et al. 2015, "Strong scaling of general-purpose molecular dynamics simulations on GPUs" (HOOMD-blue), arXiv:1412.3387
91. ✓ Anderson, J. A. et al. 2013, "HOOMD-blue: A Python package for high-performance molecular dynamics", arXiv:1308.5587
92. ✓ Páll, S. et al. 2020, "Heterogeneous parallelization and acceleration of molecular dynamics simulations in GROMACS", J. Chem. Phys. 153, 134110. doi:10.1063/5.0018516
93. ✓ Eastman, P. et al. 2017, "OpenMM 7", PLoS Comput. Biol. 13, e1005659. doi:10.1371/journal.pcbi.1005659
94. ✓ Burtscher, M. & Pingali, K. 2011, "An Efficient CUDA Implementation of the Tree-Based Barnes Hut n-Body Algorithm", GPU Computing Gems. doi:10.1016/b978-0-12-384988-5.00006-1
95. ○ Villa, O. et al. 2009, "Effects of floating-point non-associativity on numerical computations on massively multithreaded systems" *(record located, no DOI)*
96. ✓ Demmel, J. & Nguyen, H. D. 2014, "Parallel Reproducible Summation", IEEE Trans. Comput. 64, 2060. doi:10.1109/tc.2014.2345391
97. ✓ Hu, Y. et al. 2019, "Taichi: a language for high-performance computation on spatially sparse data structures", ACM TOG 38, 1. doi:10.1145/3355089.3356506

### Vendor documentation (not peer-reviewed)

98. ✗ Apple Inc., *Metal Shading Language Specification* and *Metal Feature Set Tables*, developer.apple.com — source for SIMD-group width and the availability of `simd_shuffle`/`simd_ballot`/`simd_prefix_exclusive_sum` by GPU family. Consulted from knowledge, not retrieved in this session; **verify against the current tables for your target family.**

---

## 8. Companion files

- `code-comparison.csv` — 16 production codes: gravity solver, neighbour structure,
  multipole order, leaf/bucket size, GPU status, published performance with hardware
  named, the authors' stated reason for the choice, and the reference.
- `cost-accuracy-budget.csv` — 9 methods with cost at 2×10⁶ particles, the basis of each
  number (published measurement vs my arithmetic, with the arithmetic shown), force
  accuracy, whether it handles unbounded density contrast, and whether it is
  deterministic.
- `softening-relaxation-table.csv` — Power et al. (2003) eq. 15 optimal softening and the
  relaxation-time ratio, evaluated at N = 10⁵ to 10⁷.
- `gravity-cost-budget.png` — the cost figure from §3.
