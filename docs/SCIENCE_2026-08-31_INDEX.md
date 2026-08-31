<!-- SCIENCE TRACK INDEX — Claude Science project SPACE SYNTH X · 2026-08-31
     Lands per SCIENCE_PROMPTS_2026-08-31.md. Every row below is a CLAIM to check, not a result.
     Nothing here is fitted to SPACE SYNTH output. No source changes proposed.
-->

# SCIENCE 2026-08-31 — INDEX, AND TWO FINDINGS THAT CONTRADICT THE BOARD

**Run:** P1, P2, P3. **Not run:** P0. See §4 — this matters more than it looks.

| doc | prompt | feeds |
|---|---|---|
| `SCIENCE_2026-08-31_blackhole_appearance.md` | P1 what a black hole should look like | FABLE F1 |
| `SCIENCE_2026-08-31_merger_signatures.md` | P2 the three merger signatures | FABLE F3 |
| `SCIENCE_2026-08-31_neighbour_finding.md` | P3 neighbour finding in production codes | FABLE F2 |
| `science-2026-08-31/` | 11 CSV tables + 3 figures | all three |

Citation verification: **328 of 350 identifiers across the three docs were retrieved from
literature tools, not recalled.** The remainder are marked `(identifier not verified)` in place.
Two draft attributions were corrected by those checks.

---

## 1. ✅ CORROBORATION — A HOLE AT `r_s = 0.1717` SIM IS 1.02e5 M☉, BY A SECOND ROUTE
> ⛔ **HEADER CORRECTED 2026-08-31 17:05 — was "THE FORMED HOLE IS 1.02e5 M☉".** That mass was
> `F_BH_CLUSTER`, **deleted at 16:10:25**; hole mass is now unbounded, so this is one sample and
> not "the" formed hole. The `r_s -> M` conversion itself is unaffected and still checks out.
> See `ADDENDUM_04` §2 for what re-scales. `[reasoned from src state reported 15:23; concluded 17:05]`
> ⛔ **CORRECTED 2026-08-31 15:10 — see `SCIENCE_2026-08-31_ADDENDUM_01.md`.** This section
> originally called this a finding the board was missing. **It is not.** The mass **was** in
> the code as `F_BH_CLUSTER = 0.17188f` with the arithmetic written out
> (594,276 x 0.1719 = 102,144 M☉), from 2026-08-11 until it was deleted at 16:10:25.
> ⛔ **ANCHOR DECAYED — CORRECTED 2026-08-31 20:04:11.** This line cited `particles.metal:277` in the
> PRESENT TENSE. `[MEASURED]` the constant no longer exists: `grep -rn F_BH_CLUSTER src/` returns
> **two comment lines only**, `particles.metal:266-267`, which narrate the deleted history. `:277` is
> now an unrelated comment. **No live definition remains.** What follows is an independent confirmation
> by a different route, which is worth having but is not new. **The genuinely new part is the
> consequence: `tau_220` = ⛔ **VOID — see the retraction below. No ceiling exists; the honest
> value is UNKNOWN pending a played-run measurement.**

`SCIENCE_PROMPTS_2026-08-31.md` carries **horizon 0.1717 sim** for a typical formed hole, and
**1 sim length = r_s(field)** with **M_field = 5.94276e5 M☉**. Those two facts together fix the
hole's mass:

    r_s(hole) / r_s(field) = M_hole / M_field       (r_s is linear in M)
    M_hole = 0.1717 x 5.94276e5 M☉ = 1.02e5 M☉

**The hole at horizon 0.1717 is 1.02 x 10^5 M☉ — 2041x the 50 M☉ seed.** That is an
intermediate-mass black hole. ⭐ **And 0.1717 is not primarily a radius — it is an observed MASS
FRACTION** (`F_BH_CLUSTER`, Sgr A* / MW NSC). It reads as both because `1 sim = r_s(M_field)`
makes `r_s(M)/r_s(M_field) = M/M_field` identically. Same number, two meanings, consistent. Every number in P1 and P2 was computed at 50 M☉ because the prompt
said 50 M☉, and the seed genuinely is. **The hole that dominates the frame is not.**

What changes at 1.02e5 M☉ (all scalings from the relations in the two docs, arithmetic mine):

| quantity | at 50 M☉ | at 1.02e5 M☉ | scaling |
|---|---|---|---|
| peak disc T (Page-Thorne, a_*=0, Eddington) | 4.08e6 K | **6.07e5 K** | `M^(-1/4)` |
| ringdown `f_220` | 178.8 Hz | **0.0876 Hz** | `1/M` |
| ringdown `tau_220` | 5.77 ms | ⛔ **VOID as a maximum** — 6.19 s is the value AT 1.02e5 M☉, which is no longer a ceiling | `M` |
| GR apsidal precession per orbit (TDE) | 56 arcsec | **2.5 deg** | `M^(2/3)` |
| `r_t / r_s` for a solar-type star | 1.7e4 | **108** | `M^(-2/3)` |

⛔ **VOID AS CHARACTERISTIC VALUES 2026-08-31 17:05.** Every second-column entry above was
computed at `M_hole = 1.02e5 M☉`, which was the board's `0.1717` sample AND — until 16:10:25 —
the cap. **With `F_BH_CLUSTER` deleted, hole mass is unbounded and `1.02e5 M☉` is one sample, not
a characteristic or maximum mass.** The rows remain arithmetically correct *at that mass*. The
**scaling column is the durable part** — it re-maps every row to whatever mass a played run
actually reaches. Larger holes are *better* resolved, radiate *cooler*, precess *faster* per
orbit and ring *longer*. Do not read this column as a prediction until a played-run maximum is
measured. `[reasoned from src excerpts pasted 12:41-15:23; concluded 17:05]`

⭐ **The third row is the useful one.** At 50 M☉ a BH–BH ringdown is a 5.8 ms blip — unshowable.
At the maximum reachable remnant it lasts **6.19 s = 1.06 sim-time units**. The money shot has a
duration. 
> ⛔⛔ **RETRACTED 2026-08-31 16:50:07 — THIS "SETTLED" VERDICT WAS ALREADY FALSE WHEN IT WAS STAMPED.**
> Jamal ordered the cap KILLED at **16:10:25**; this is stamped **16:30**. `F_BH_CLUSTER` and
> `FB_TAPER_FROM` are **DELETED** from `particles.metal` — the only surviving mentions are inside the
> retraction comment at `:266-267`, and the merge guard is now a bare `float headM = 6.0e7f` (`:1638`).
> 🚨 **Every `particles.metal:277` / `:289` / `:1647-1649` citation below is a DEAD ANCHOR** — the line
> numbers still resolve, so an automated citation check cannot catch them.
>
> ⭐ **The correction is GOOD NEWS: no ceiling means a BIGGER remnant, so a LONGER ringdown.** The
> 11.8 s this doc called "unreachable in this code" is reachable again. The honest number is **UNKNOWN
> until re-measured** — an idle run has already reached `Mmax = 161,690 M☉` (OPUS, post-kill), which
> would be `tau_220 ≈ 9.8 s`, but that is a measured maximum so far, **not a ceiling**.
>
> ⚠️ **ROOT CAUSE, and it is not staleness: a science stamp dates the REASONING, not the CODE.** This
> was reasoned from a `src/` excerpt pasted before the kill and stamped with the wall-clock time of the
> conclusion. Those are two different events. Found by SONNET, `docs/SWEEP_2026-08-31_SONNET.md` §4.

⛔ **VOID — TEXT BELOW PRESERVED FOR THE RECORD ONLY. It was stamped `✅ SETTLED 16:30` and was
already false; the `✅` marker is demoted here so no reader finds a confidence marker standing on
retracted text.** ~~SETTLED 2026-08-31 16:30 — the `F_BH_CLUSTER` cap applies post-merger and is a
REFUSAL, not a clamp** (`particles.metal:1580,:1647-1649`): a merge that would carry the remnant
over `102,144 M☉` is declined, both holes stay alive and orbiting, and mass is conserved exactly.
So `102,144 M☉` is the hard ceiling and `tau_220 = 6.19 s`, `f_220 = 0.167 Hz`. My earlier 11.8 s
assumed two cap-mass holes merging to `1.94e5 M☉` — **unreachable in this code**; it would need
the cap removed or the field mass roughly doubled. Still ~3 decades above the 5.77 ms at seed
mass, so the showable-vs-unshowable conclusion is unaffected. ⚠️ **The guard binds on the SUM OF
THE PARENTS, not the remnant** (`:1636`, `:1648`) — the two coincide only because mass is
conserved through the merge today. Once §2 row 9 (the 4.84% deficit) lands, the remnant becomes
`97,202 M☉` and **`tau_220` drops to 5.89 s**, unless the guard is deliberately moved to bind on
the post-deficit remnant. See `ADDENDUM_03` §3.~~ **END OF VOIDED TEXT.**

⚠️ The disc temperature drop is the cost: 6.07e5 K is EUV, not soft X-ray. And the precession row
partially re-opens circularisation — 2.5 deg/orbit is no longer negligible the way 56 arcsec was,
though still far from the 11.5 deg of a 1e6 M☉ hole where the standard mechanism is established.

## 1b. ⛔ WITHDRAWN — IT WAS A UNITS MISMATCH, NOT A CONTRADICTION
> **CORRECTED 2026-08-31 15:10 — see `SCIENCE_2026-08-31_ADDENDUM_01.md`.** Two errors here:
> (a) `eps = 0.031` is stale — the live fine cell is **0.0625** (`renderer.mm:2824`,
> `2*kAmrFineExtent/N = 2*4/128`; AMR default ON at `:2137`). Every eps-relative number below was
> **2x too large.** (b) There are **TWO** live softening lengths — coarse **1.0 sim** outside the
> AMR box, fine **0.0625 sim** inside +-4.0 sim where the hole sits. The board's *"all inside ONE
> softening length"* is the **COARSE** eps, and against that it is **TRUE**. Corrected numbers and
> what else moves: the addendum. **The reissued `resolution-verdict-table.csv` carries both eps.**

Superseded text, kept for the record. With `eps = 0.031`:

| hole | r_s (sim) | in units of eps |
|---|---|---|
| rebirth, 0.01 M☉ | 1.68e-8 | **5.4e-7** |
| seed, 50 M☉ | 8.41e-5 | **0.0027** |
| horizon spans exactly one eps | 0.031 | 1.0 — requires **1.84e4 M☉** |
| board's formed hole, 1.02e5 M☉ | 0.1717 | **5.54** |

- For the **seed**, the claim understates the problem by **368x** — the horizon is not "inside one
  softening length", it is nearly three orders of magnitude below it.
- For the **formed hole**, the claim is simply false: horizon 5.5 eps, photon sphere 8.3 eps,
  `b_c` 14.4 eps, ISCO 16.6 eps. **It is marginally resolved.**
- **A hole must reach ~1.84e4 M☉ before its horizon spans one softening length.** That is the
  number the renderer should branch on, not a fixed verdict. Full branch table:
  `science-2026-08-31/resolution-verdict-table.csv`.

✅ **Unit convention independently checked.** `r_s(5.94276e5 M☉)` computed from `2GM/c^2` is
**1.7555e9 m** against the stated **1.7552e9 m** — agreement to 0.017%. `L/c = 5.855 s` against
the stated 5.85 s. `spacetime.h` is self-consistent.

⚠️ One consequence of the convention worth an assert: the length unit is `r_s` of the **total field
mass**, so if the field mass ever changes, the length unit is not constant and the entire spatial
grid rescales.

---

## 2. CORRECTIONS TO CODE — ranked. Each is argued with sources in the named doc.

Rows are stated against the `file:line` in `SCIENCE_PROMPTS_2026-08-31.md`; **re-grep before
trusting any of them** (129 anchor-misses are open, per O0).

1. 🚨 **`render.metal:308,:1409` — the Omega law is dimensionally wrong, not conceptually wrong.**
   `Omega = 1/(r^1.5 + a)` is **exactly** Bardeen, Press & Teukolsky 1972 eq. (2.16) for prograde
   circular equatorial Kerr geodesics — in units where `M = 1`. Fed sim-unit `r`, the constant
   `a = 0.5` implies `a_* = 0.5/M^(3/2) = 19.9` — **twenty times over-extremal**. Correct form:
   `Omega = M^(1/2) / (r^(3/2) + a_* M^(3/2))`. Then `a = 0.5` means `a_* = 0.5`, which is what it
   looks like it means. *(P1 §3)*
2. **The same law must not be applied inside the ISCO** — there are no circular orbits there.
   Plunging matter carries its ISCO `E~`, `L~`; `Omega -> Omega_H = a/(r_+^2 + a^2)`. *(P1 §3)*
3. **One fixed Doppler axis fails as soon as there are two holes.** Each carries its own spin
   vector, which sets shadow flattening, Doppler axis and frame-dragging sense; a remnant's spin is
   neither parent's. *(P1 §3)*
4. **0.1717 / 0.2576 / 0.5151 are the `a_* = 0` values `2M/3M/6M`** — inconsistent with running any
   nonzero spin in the Doppler law. At `a_* = 0.5` the ISCO is `4.233M`, photon orbit `2.347M`.
   Spin must move the radii and the Doppler law together. *(P1 §3, `kerr-spin-table.csv`)*
5. 🚨 **Do not paint a bright ring at `b_c`** (`render.metal:3028`, `bc = 2.5980762f * rsW`). The
   brightness divergence at the critical curve is only **logarithmic**; the `n=2` lensing ring
   carries a few per cent of the flux and `n>=3` a fraction of a per cent (Gralla, Holz & Wald
   2019). The bright thin arc in a correct thin-disc image is **the lensed far side of the disc**,
   not multiply-orbiting photons. A ring at `b_c` is brighter than the real thing. *(P1 §1, §4)*
6. **The dark region is not the interior of the critical curve.** Four curves get called "the
   shadow": critical curve `5.196M`, backlit edge `6.168M`, lensed horizon `2.848M`, and the actual
   dark-region edge — which is an **emission-model** property, `~2.8M` to `>7M`. *(P1 §1)*
7. **A Novikov-Thorne disc is DARK at its inner edge.** Zero torque forces `F(r_ISCO) = 0`; flux
   peaks at `1.587 r_ISCO`. A bright inner edge is a departure from the model — defensible via
   nonzero ISCO stress (Krolik & Hawley 2002; Zhu et al. 2012) but it must be labelled. *(P1 §2)*
8. 🚨 **A collisionless particle field cannot produce a luminous disc.** No dissipation, no
   radiative mechanism. What it produces is **geodesic capture** of particles with `L < 4GM/c`,
   cross-section `sigma = 16 pi (GM/c^2)^2 (c/v_inf)^2`, which radiates nothing. Rendering a
   glowing disc fed by the field is a fabrication unless a gas component is explicitly posited.
   *(P1 §2)*
9. **`particles.metal:218` — a BBH merger must LOSE mass.** Equal-mass non-spinning:
   `M_f/M = 0.95162 +- 0.00002`, `chi_f = 0.68646 +- 0.00004` (Scheel et al. 2009). Conserving mass
   through a merger is unphysical at the **4.84%** level, and loses the shocks that deficit drives
   in surrounding material. Every bound orbit then expands 5.36% and acquires `e = 0.051` (exact,
   angular momentum conserved). *(P2 Case C)*
10. **An equal-mass non-spinning merger receives EXACTLY ZERO recoil**, by symmetry. A random kick
    there is wrong. Kicks need unequal mass (`<=175 km/s`) or spin (superkick `~4000 km/s`).
    *(P2 Case C)*
11. **Nothing flashes at the instant of coalescence.** Every proposed EM counterpart mechanism is
    delayed by a viscous or shock-crossing time. Both claimed real counterparts are contested.
    *(P2 Case C)*
12. 🚨 **A 50 M☉ hole ALWAYS disrupts a main-sequence star — it can never swallow one whole.**
    `r_t/r_s = 1.7e4`; plunge cross-section is `6e-5` of the disruption cross-section. Swallowing
    needs `M > 1.14e8 M☉`. Star+BH must always render as a disruption, at both seed and formed
    mass. And the hole does not gain the star's mass: half the debris is unbound at `~1200 km/s`
    and much of the bound half leaves in a super-Eddington wind. *(P2 Case B)*
13. 🚨 **Do not drive the TDE light curve from `seedAccum` word 5 as `0.1 Mdot c^2`.** At 50 M☉ the
    fallback peak is `3.8e8` Eddington, so that gives `2.4e48 erg/s` — **eight decades** above the
    published prediction of `1e41-1e44 erg/s` at `1e5-1e6 K` (Kremer et al. 2023). The KE->light
    mapping is defensible **only for star+star**, where Pejcha et al. 2016b give radiated
    `L = 0.01-0.1` of `Mdot v_orb^2 / 2`. It is a fudge for star+BH and unphysical for BH+BH, where
    the energy goes to gravitational waves, not heat. *(P2, all three cases)*
14. **V838 Mon is NOT a confirmed merger, and its famous images are a LIGHT ECHO** scattering off
    pre-existing circumstellar dust (Bond et al. 2003). Drawing expanding nested shells from those
    images draws a scattering screen, not the event. **V1309 Sco is the genuine reference case** —
    OGLE caught the contact-binary progenitor with a decaying 1.4 d period seven years before
    outburst (Tylenda et al. 2011). The class is **~15 objects**, not 2. *(P2 Case A)*
15. **`t^(-5/3)` holds poorly.** Observed decay indices (Hammerstein et al. 2023, Table 6): median
    **-1.91**, IQR -2.28 to -1.62, range -0.78 to -3.82, **21/30 steeper than -5/3**. *(P2 §3)*
16. 🚨 **`spatial_hash.metal:352` / `:589` — the per-cell capacity is buying nothing.** The standard
    GPU method — radix-sort `(cell key, particle id)` then per-cell begin/end offsets from a prefix
    sum — gives the **exact** occupancy with no cap, estimated `~0.3 ms` at 2e6 particles. **No
    production N-body or SPH code has a per-cell capacity parameter**, because tree depth grows as
    the log of the local density contrast. *(P3 §2, §3)*
17. 🚨 **If gravity is summed only over the 3x3x3 stencil, it is not gravity** — it is a force
    truncated at ~1.5 cell widths with no long-range attraction. **That is a larger error than the
    sampling cap, and raising the cap does not touch it.** Every production code either walks the
    tree to the root or adds a mesh/convolution far field. *(P3 §2)*
18. **`particles.metal:1845` — Plummer is the wrong kernel, not a suboptimal parameter.** Dehnen
    2001 shows compact finite-extent kernels give significantly smaller force errors; Plummer's
    tail modifies every pair interaction at all separations. Every production code that softens uses
    a compact spline, exactly Newtonian outside its support. *(P3 §2)*
19. **The softening length is ~5x too large.** Power et al. 2003 eq. 15 gives
    `eps_opt ~ 4 r200/sqrt(N200) = R/354` at `N = 2e6`; a 128^3 cell is `R/64`. Over-softening
    suppresses exactly the small-scale structure the holes are supposed to emerge from. *(Caveat:
    eq. 15 is fitted to dissipationless CDM halo convergence, not collisional cluster dynamics.)*
    *(P3 §2)*
20. 🚨 **The cap 32 -> 64 result is a FAILED CONVERGENCE TEST, not a tuning result.** A convergent
    scheme does not change its answer by 4x when a structural parameter doubles. The
    `11.1x -> 3.4x` reduction in the `Mmax` fork is consistent with a `1/sqrt(n)` sampling-noise
    origin feeding a threshold-crossing response. *(P3 §4)*
21. **The nondeterminism is NOT the floating-point non-associativity problem**, and reproducible-
    summation methods will not fix it. Non-associativity changes the **rounding** of a sum over a
    fixed set of terms; first-come atomic selection changes **which terms are in the sum**. It is a
    different physical system each frame. *(P3 §4)*
22. **Exact time reversibility is incompatible with naive adaptive timestepping.** Leapfrog is
    exactly reversible only at fixed step; adaptive steps break symplecticity and reversibility
    unless the criterion is itself time-symmetric (Hut, Makino & McMillan 1995). Separately,
    accretion and merger are dissipative and not physically reversible at all. *(P3 §3)*

---

## 3. THE STRUCTURAL POINT FOR F1, AND THE DRAW LIST

⭐ **Null transport is independent of the dynamics grid.** Geodesics are integrated in the analytic
metric on the screen's own grid — which is exactly why `tools/bc_validate.cpp` returns `b_c` to
`8.2e-15` on a 128^3 field. **Every production imaging code separates the dynamics stage from the
imaging stage for this reason** (ipole, grtrans, RAPTOR, GRay, Odyssey). The softening bounds the
**matter distribution**, not the light. Per-pixel backward geodesics terminating on the real
particles is the correct architecture, and the resolution objection does not apply to it.

**DRAW:** the dark region and critical-curve position (pure transport) · the spin-dependent shadow
shape — edge-on vertical extent is exactly `6*sqrt(3)*M` at **all** spins, only the horizontal width
shrinks and the centroid shifts · the Doppler asymmetry, which is the dominant visual asymmetry and
is exact: **81:1** approaching/receding bolometric ratio at the Schwarzschild ISCO · and, if a gas
disc is explicitly posited, the `n=2` lensing ring (width `1.153M` = **1.58 fine softening
lengths** at `eps = 0.0625`, revised down from 3.2 — see addendum; it is marginal, not comfortable).

**DO NOT DRAW:** `n>=3` photon subrings (`n=3` is ~1 screen pixel at a 20 `r_s` field of view) · the
underside arc unless the disc is optically thick · any disc at all for a seed-mass hole. ⛔ **The
"nothing inside ~3 softening lengths" rule cannot be used at fine eps** — `3 x 0.0625 = 0.1875 sim`
exceeds the horizon at 0.1717, so it would exclude the hole itself. See addendum.

**The three observer effects factorize exactly**, so they can be applied individually as asked:
`g = sqrt(1-2M/r) * 1/[Gamma(1 - v.n)]`, checked against the covariant
`g = 1/[u^t(1 - Omega*lambda)]` at the ISCO. Light bending is **not** a multiplier — it is the map
from screen pixel to emission event. Invariant: `I_nu/nu^3`, so `I_obs = g^3 I_em` monochromatic,
`g^4` bolometric.

---

## 4. ⛔ P0 WAS NOT RUN, AND IT SHOULD HAVE BEEN

`SCIENCE_PROMPTS_2026-08-31.md` says **"P0 FIRST AND ALONE — its answer is the input to P1 and P2."**
P1, P2 and P3 were run; **P0 was not.** The consequence is concrete, not procedural:

- Every P1/P2 number was computed at **50 M☉** because the prompt specified it. §1 shows the hole
  that actually forms is **1.02e5 M☉**, and five of the headline quantities move by orders of
  magnitude.
- The board's own open question — **~594,276 M☉ inside roughly an AU, never checked against the
  literature** — is exactly what P0 would settle, and it determines whether an IMBH forming there is
  physical at all or an artefact of §1b/§2 rows 16-20.
- ⭐ **Recommendation: run P0 next, and re-scale §1 rather than re-running P1/P2.** The relations in
  the three docs are mass-parametrised; the scalings in §1 are the whole re-derivation.

---

## 5. WHAT THE LITERATURE DOES NOT SETTLE — recorded as results, per rule 4

1. **Disc formation in a micro-TDE (10-100 M☉) has never been simulated with radiation
   hydrodynamics.** At 50 M☉ apsidal precession is 56 arcsec/orbit vs 11.5 deg at 1e6 M☉, so stream
   self-intersection — the standard circularisation mechanism — is switched off. *Settled by:* a 3D
   radiation-hydro run of a `beta ~ 1` encounter at 10-100 M☉ from disruption to peak.
2. **No micro-TDE has ever been observationally confirmed.** Every star+BH luminosity, colour and
   timescale at seed mass is a prediction with a three-decade spread. *Settled by:* a Rubin/ULTRASAT
   fast blue UV transient in a dense cluster at the predicted `1e5-1e6 K`.
3. **Whether any BH+BH merger has ever produced light.** The Fermi-GBM GW150914 transient was
   contradicted by INTEGRAL limits and a GBM reanalysis; the ZTF19abanrhr/GW190521 association has
   odds of only 1-12 depending on waveform model. *Settled by:* a repeat flare from ZTF19abanrhr on
   the predicted `~1.6 yr` timescale, or a second better-localised coincidence.
4. **The thin-disc inner boundary condition** — zero-torque or not, how much the plunging region
   radiates, how sharp the edge is. Krolik & Hawley 2002 argue the question is ill-posed as usually
   asked.
5. **Whether the photon ring has been detected, and whether ring diameter tests GR or only measures
   mass.** The area-equivalent shadow radius varies only **5.8-7.1%** across all spins and
   inclinations — it is a mass measurement, not a spin measurement.
6. **Spin evolution of a hole grown by collisionless capture from an N-body field.** No literature
   treats this case. The accumulate-`J` prescription in P1 §3.4 is a construction from first
   principles, **explicitly not a cited result**. Note the Thorne 1974 `a_* <= 0.998` limit does
   **not** apply to collisionless capture — clamp `|a_*| <= 1` by hand and treat hitting the clamp
   as a signal to revisit the capture prescription.
7. **The correct softening prescription for a massive point sink embedded in a softened particle
   field.** The softening literature optimises force accuracy for a *distribution*, not for a point
   sink inside one. Nothing in it justifies rendering structure inside the softening length.
8. **There is no published astrophysical N-body benchmark on Apple Silicon or Metal.** Every
   throughput number in the literature is CUDA-on-NVIDIA. This is the **largest uncertainty** in
   every cost estimate in P3. *Settled by:* a direct-summation benchmark — an afternoon's work.
9. **Fixed-capacity neighbour truncation has never been characterised.** Searches returned nothing
   describing it; **no term was invented for it.** It decomposes into four effects that do have
   literature: artificial two-body relaxation from undersampling (**~206x too fast**, arithmetic in
   P3 §4), a near-field mass deficit, force truncation at the stencil, and selection
   nondeterminism. ⭐ *A cap sweep 16/32/64/128/256/exact with the `Mmax` fork measured at each
   would be original, publishable data* — and it is the direct answer to F2.
10. **What force accuracy is SUFFICIENT for a real-time system whose claims are qualitative** is not
    addressed anywhere. All code papers optimise time-to-solution at fixed accuracy for offline runs.

---

## 6. THE F2 ANSWER IN ONE PLACE

No method meets 16 ms at full accuracy on one GPU at 2e6 particles. Published: Bonsai **2.8e6
particles/s** (GTX480, `theta=0.75`) -> 714 ms; Abacus **~1.2e7/s/GPU** (V100, `1e-5` force error)
-> 171 ms. Scaling Bonsai to 14 TFLOPS gives ~69 ms — an **upper bound on the speedup**, since
traversal is memory-bound.

The configuration that fits, at **~11.8 ms**: exact radix-sort + prefix-sum cell list (`~0.3 ms`, no
cap, deterministic) · compact spline softening at `eps` from Power et al. 2003 eq. 15 · GPU-resident
sparse oct-tree on the same Morton keys, Bonsai-style group traversal, bucket `~16` / group `~64`,
monopole+quadrupole, mass-based MAC (Salmon & Warren 1994) · **hierarchical block timesteps**,
`dt ~ sqrt(eps/|a|)`, physics decoupled from display frames — this is the lever, ~17% occupancy ·
optional `256^3` PM far field to bound tree depth.

**What that gives up, stated honestly:** force accuracy `~1e-4` energy error rather than
PKDGRAV3/Abacus `1e-5` · unbounded worst-case force-error tails unless a mass-based MAC is used ·
symplecticity and exact time reversibility if block timesteps are taken · no access to genuine
collisional black-hole dynamics (that needs NBODY6/7-class direct integration with regularisation) ·
no resolution of the 50 M☉ seed horizon, which is `8.4e-5` sim length units.

**Apple Silicon specifics:** unified memory removes the host round trip that Bonsai's design existed
to eliminate, so a CPU-build / GPU-force hybrid is cheap here and unexplored · SIMD group width 32,
and Metal exposes `simd_shuffle` / `simd_ballot` / `simd_prefix_exclusive_sum`, so Bonsai's scan- and
sort-only algorithms port · device atomics are expensive, and a radix sort needs **none** and is
deterministic.

---

## 7. WHAT THIS SCIENCE TRACK DID NOT DO

- **Did not run P0.** §4.
- **Did not read `src/`.** Every `file:line` above is quoted from `SCIENCE_PROMPTS_2026-08-31.md`,
  which was verified 2026-08-31 14:25:53. **Re-grep before trusting any of them** — 129
  anchor-misses are open.
- **Did not propose source changes**, and did not touch `src/`, any board, `TODO.md`, or any
  pre-existing doc. Only the four `SCIENCE_2026-08-31_*` files and `science-2026-08-31/` are new.
- **Did not fit anything to SPACE SYNTH output.** Every relation is published; every number computed
  here from a published relation is labelled as arithmetic, not measurement.
- **Did not verify the `Mmax` fork, the 334,576 peak count, or any run-to-run number.** Those are
  yours; they are taken as given.
