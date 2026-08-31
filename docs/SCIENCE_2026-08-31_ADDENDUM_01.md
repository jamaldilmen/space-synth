<!-- SCIENCE TRACK ADDENDUM 01 — Claude Science project SPACE SYNTH X · 2026-08-31 15:10
     Answers two corrections from the repo (BRAIN window, 2026-08-31 12:57). Both accepted.
     Amends SCIENCE_2026-08-31_INDEX.md §1, §1b, §3 in place. Nothing here is fitted to SPACE SYNTH output.
-->

# ADDENDUM 01 — TWO CORRECTIONS ACCEPTED, AND ONE NEW REGIME PROBLEM

Both corrections are right. I re-derived every affected number; the repo's arithmetic checks out
exactly. **Neither correction touches the P0 recommendation or the 22 code rows in INDEX §2.**

---

## 1. CORRECTION 1 ACCEPTED — `eps = 0.0625`, and there are TWO of them

`eps = 0.031` came from the prompt pack, which took it from `particles.metal:2211` — a comment the
DAM test invalidated. Live value is `2 * kAmrFineExtent / N = 2*4/128 = 0.0625`. **Every
eps-relative figure I published was 2x too large.** Confirmed independently:

| feature (formed hole, `r_s = 0.1717` sim) | sim | fine `eps=0.0625` | coarse `eps=1.0` |
|---|---|---|---|
| horizon `r_s` | 0.1717 | **2.747** | 0.1717 |
| photon sphere `3M` | 0.2576 | **4.122** | 0.2576 |
| `b_c = 3sqrt(3)M` | 0.44609 | **7.137** | 0.4461 |
| ISCO `6M` | 0.5151 | **8.242** | 0.5151 |
| `n=2` lensing ring width `1.153M` | 0.09899 | **1.584** | 0.0990 |
| `n=3` photon ring width `1.4e-3 M` | 1.20e-4 | **0.00192** | 1.2e-4 |
| seed 50 M☉, `r_s` | 8.414e-5 | **0.001346** | 8.41e-5 |
| **M where `r_s` = one eps** | — | **3.714e4 M☉** | **5.943e5 M☉** |

⭐ **And the reframing is yours, correctly: this was never a contradiction.** The board's *"all
inside ONE softening length"* is the **coarse** eps of 1.0 sim, and against that it is **true** —
horizon, photon sphere and ISCO are all well inside it. My §1b called it wrong in both directions
because I had one eps, not two. **INDEX §1b is withdrawn** and restated as a units mismatch.

`resolution-verdict-table.csv` is reissued at **both** eps, 9 mass rows from 1e-5 to 1.0 of field
mass, so the branch can be read off directly.

### 1a. WHAT ELSE MOVES — three consequences beyond the ratios

**(i) The `n=2` lensing ring goes from comfortable to marginal.** I had it at 3.2 softening lengths
and called it "resolved on screen". At the live fine eps it is **1.58** — about one and a half
softening lengths. It is still the one ring worth drawing (it carries a few per cent of the flux,
`n>=3` a fraction of a per cent), but it should be drawn as *marginally* resolved, and it will not
survive any further coarsening. **INDEX §3 amended.**

**(ii) My "draw nothing inside ~3 softening lengths" rule is unusable at fine eps, and I withdraw
it.** `3 x 0.0625 = 0.1875 sim`, which **exceeds the horizon at 0.1717**. Applied literally it
would exclude the hole itself. The rule was written against `eps = 0.031`, where `3 eps = 0.093`
sat comfortably inside the horizon. **Restated: the exclusion is `r < r_s`, plus one fine softening
length as the honesty margin (`0.1717 + 0.0625 = 0.234 sim`), not a fixed multiple of eps.**

**(iii) 🚨 This is the one I would not have found without the correction: outside the AMR box, the
hole's entire strong-field region is sub-softening.** The coarse softening is **1.0 sim, which is
`r_s(M_field)` exactly** — by the unit convention, gravity outside the fine box is softened on the
scale of the whole field's Schwarzschild radius. Against that, the formed hole's `b_c` is **0.446
coarse eps**: the shadow, photon sphere and ISCO all fit inside a *single coarse softening length*
with room to spare. **So the honest statement is conditional on position, not on mass:** a hole
inside `+-4.0` sim is marginally resolved (horizon 2.7 fine eps); the same hole outside the box is
not resolved at all. **Whether a formed hole can ever leave the fine box is a question for the code,
not for me** — if it can, the resolution verdict changes discontinuously as it crosses, and that is
worth an assert.

---

## 2. CORRECTION 2 ACCEPTED — corroboration, not a finding

`F_BH_CLUSTER = 0.17188f` at `particles.metal:277` has carried the mass since 2026-08-11, with the
arithmetic written out. My derivation reached `1.02e5 M☉` by a different route — from `r_s` linearity
and the unit convention rather than from the mass fraction — and the two agree. **That is
corroboration and I have restated it as such. INDEX §1 amended.**

You are also right about why one number reads as two things: `1 sim = r_s(M_field)` makes
`r_s(M)/r_s(M_field) = M/M_field` identically, so a mass fraction and a horizon radius in sim units
are the same number. Consistent, and worth stating in the docs precisely because it looks like a
coincidence.

**What survives as genuinely new: `tau_220` = 11.8 s = 2.0 sim-time at 1.02e5 M☉**, against 5.77 ms
at the 50 M☉ seed. A BH–BH ringdown is showable at the mass that actually forms and is not at seed
mass. Kept.

---

## 3. ⛔ PARTLY VOID — `F_BH_CLUSTER` IS A SINGLE-SYSTEM RATIO USED AS A SCALING LAW

> ⛔ **VOID AS A CODE CRITICISM 2026-08-31 17:05.** `F_BH_CLUSTER` and `FB_TAPER_FROM` were
> **DELETED** from `particles.metal` at **16:10:25** (surviving mentions are the retraction comment
> at `:266-267` only). There is no constant left to relabel, so the suggested wording below is
> moot and the `particles.metal:277` citation is a **dead anchor** — the line still resolves.
>
> ✅ **THE LITERATURE CONTENT BELOW STANDS AND IS THE REUSABLE PART.** The observed `M_BH/M_NSC`
> ratio spans three regimes over more than two decades (Neumayer & Walcher 2012), depends on host
> galaxy mass (Neumayer, Seth & Böker 2020), and has an aperture-dependent denominator. **Any
> future constant that fixes a black-hole mass as a fraction of field mass inherits every one of
> those objections** and must be labelled a convention, not a scaling law.
> `[reasoned from src state reported 15:23; concluded 17:05]`

Chasing correction 2 into the literature turned up a regime-of-validity problem. This is not a
correction to the code's arithmetic — the arithmetic is right — it is a question about what the
number means.

**Provenance verified.** `M_BH = 4.297e6 M☉` for Sgr A* is GRAVITY Collaboration (Abuter et al.)
2019, *A&A* **625**, L10, `doi:10.1051/0004-6361/201935656` (arXiv:1904.05721) — a 0.16% precise,
0.27% accurate geometric determination from the S2 orbit. **That is a measurement, and a good one.**
`M_NSC = 2.5e7 M☉` for the Milky Way nuclear star cluster is in the Schödel et al. line of work
(e.g. arXiv:0902.3892, `doi:10.1051/0004-6361/200810922`). Both numbers are sound.

**The ratio of them is not a law.** Three problems, in increasing severity:

1. **`M_BH/M_NSC` is not a constant — it spans regimes.** Neumayer & Walcher 2012
   (`doi:10.1155/2012/709038`, arXiv:1201.4950) find **three distinct regimes** in `M_BH` vs
   `M_NSC`: cluster-dominated nuclei, a transition region, and black-hole-dominated nuclei. Their
   picture is that black holes form inside nuclear clusters *at a very low mass fraction* and then
   grow much faster than the cluster, **destroying it once `M_BH/M_NSC` exceeds ~100**. The Milky
   Way's 0.17 is one point in the transition region — not a universal fraction, and the observed
   range covers more than two decades.
2. **NSC properties depend on the host galaxy.** Neumayer, Seth & Böker 2020, *A&A Review*
   (`doi:10.1007/s00159-020-00125-0`, arXiv:2001.03626) — the current review — state that NSC
   masses, densities and stellar populations **vary with host galaxy properties**, with a clear
   transition at a host mass of `~1e9 M☉` separating two different formation channels (inspiralling
   globular clusters below, in-situ nuclear star formation above). A ratio measured in one galaxy
   carries that galaxy's channel with it.
3. ⛔ **The denominator is aperture-dependent.** An NSC mass is a mass *within some radius* — the MW
   value is quoted within a few pc. The ratio therefore depends on an integration radius that has no
   analogue in SPACE SYNTH, where the entire field is `5.94276e5 M☉` inside **2.52 R☉ ≈ 0.0117 AU**.
   The MW NSC is `2.5e7 M☉` spread over parsecs. **The ratio is being transported across ~8 orders
   of magnitude in size and 1.6 decades in mass, into a regime where the relation it came from was
   never measured.**

**What this does and does not mean.** It does **not** mean 0.17188 is a bad choice of number — as a
*convention* fixing "how much of the field ends up in the hole", it is defensible, traceable, and
better than an arbitrary constant. It **does** mean the comment's framing as an observed ratio
imported from Sgr A*/MW NSC is a **measurement being used as a model**, and per the project's own
rule that measurement, model and convention be distinguished explicitly, it should be labelled as a
convention *calibrated to* the Milky Way, not as a physical scaling law. **Suggested label, and this
is the only textual change I would propose to anything outside my own files:** *"convention:
`M_BH/M_field` fixed to the Milky Way's observed `M_BH/M_NSC` (GRAVITY 2019 / Schödel 2009). Not a
scaling law — the observed ratio spans >2 decades across three regimes (Neumayer & Walcher 2012) and
depends on host mass (Neumayer, Seth & Böker 2020). Applied here far outside the measured regime."*

⭐ **This is P0 territory, and it sharpens the P0 question.** P0 asks whether `~594,276 M☉` inside
roughly an AU is physical. The answer partly determines whether an `M_BH/M_field` of 0.17 is
physical *for this object*, and there is no published relation that covers it — which by rule 4 is
itself the result.

---

## 4. WHAT IS UNCHANGED

- **All 22 code corrections in INDEX §2**, including the two highest: the `Omega` law implying
  `a_* = 19.9` (`render.metal:308`), and the neighbour-finding rows. None depended on `eps`.
- **The P0 recommendation** (INDEX §4) — unaffected, and §3 above strengthens it.
- **The F2 answer** (INDEX §6). One note: the recommended `eps` from Power et al. 2003 eq. 15 is
  `~R/354` where `R` is the field radius, which I do not have in sim units. **Give me `R` and I will
  state whether either live eps is over-softened, and by how much.** With the fine box at `+-4.0`
  sim as the only length I have, `eps_fine = 0.0625` is `R/64` if `R = 4.0` — still ~5x larger than
  eq. 15 wants, but that comparison is only as good as the `R` I guessed, so treat it as pending.
- ⛔ **WITHDRAWN 2026-08-31 16:10 — this row claimed the `eps` error was INDEX-only. It was not.**
  `SCIENCE_2026-08-31_blackhole_appearance.md` §4 carried `ε = 0.031` throughout, including the
  whole §4.1 resolution budget table — and §4 is the draw/do-not-draw section F1 actually
  consumes. Corrected in place. P2 is clean of `eps`; P3 is clean of `eps` but carried `N = 2e6`.
  See `SCIENCE_2026-08-31_ADDENDUM_03.md`.
- ⚠️ **Your caveat stands:** you have read the INDEX, not the three docs. More may surface.

## 5. WHAT I GOT WRONG, PLAINLY

1. Used a stale `eps` from the prompt pack without re-grepping it. Every derived ratio was 2x off.
2. Assumed one softening length where there are two, then built a "contradiction" on top of it.
3. Claimed the board did not state the hole's mass. It did, for eleven days.
4. Published a "draw nothing inside 3 eps" rule that, at the live eps, would have excluded the hole.

Items 1 and 3 were both checkable against `src/` and I did not check them — I worked from the
prompt pack, which is exactly the failure mode the 129 anchor-misses represent.
