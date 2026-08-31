<!-- SCIENCE TRACK ADDENDUM 04 — Claude Science project SPACE SYNTH X · 2026-08-31 17:05
     VOID NOTICE. Records the deletion of F_BH_CLUSTER at 16:10:25 and voids every claim that
     rested on it. Adopts a provenance convention for all future claims. NO NEW PHYSICS IS
     DERIVED HERE — the ringdown input does not exist yet and is deliberately left unmeasured.
     [reasoned from src state reported by the build/brain windows 15:23-17:00; concluded 17:05]
-->

# ADDENDUM 04 — VOID NOTICE, AND A PROVENANCE RULE I SHOULD HAVE HAD FROM THE START

**`F_BH_CLUSTER` and `FB_TAPER_FROM` were DELETED from `particles.metal` at 16:10:25** on Jamal's
order. The merge guard is now a bare `float headM = 6.0e7f` (`:1638`) and **nothing binds a merge.**
My last two rounds refined a mechanism that no longer existed when I wrote about them.

---

## 1. VOID LIST — DO NOT REFINE THESE, THEY HAVE NO SUBJECT

| voided claim | where it was | status |
|---|---|---|
| the `102,144 M☉` ceiling | INDEX §1, ADDENDUM_03 §3 | ⛔ no ceiling exists |
| `tau_220 = 6.19 s`, `f_220 = 0.167 Hz` as maxima | INDEX §1 table + prose, ADDENDUM_03 §3 | ⛔ void as maxima |
| the `5.89 s` row-9 conditional | ADDENDUM_03 §3 | ⛔ subject deleted |
| "`1.944e5 M☉` is unreachable in this code" | ADDENDUM_03 §3 | ⛔ reachable again |
| the sum-vs-remnant guard distinction | ADDENDUM_03 §3 | ⛔ moot — no guard |
| every `particles.metal:277` / `:289` / `:1647-1649` citation | INDEX, ADDENDUM_01 §2-3, ADDENDUM_03 §3 | ⛔ **DEAD ANCHORS** |
| `F_BH_CLUSTER` as a mislabelled convention | ADDENDUM_01 §3 | ⛔ as code criticism; ✅ literature content stands (§3) |

🚨 **The dead-anchor problem deserves its own line.** Those line numbers **still resolve**. A
citation checker that verifies `file:line` exists cannot detect this class of failure, and neither
can a grep for the constant — the constant is gone, so the grep comes back clean and the citation
looks fine. **The only detector is reading the line.** Every `file:line` I have ever written should
be treated as unverified unless it was read at a stated time.

⛔ **I am NOT adopting `Mmax = 161,690 M☉` as a replacement ceiling.** It is one idle sample, and by
Jamal's own ruling an idle run is the wrong instrument for a merger question. Its `tau_220 ≈ 9.8 s`
arithmetic is right for that mass and means nothing as a bound. **The honest state of the ringdown
number is UNKNOWN, pending a played-run maximum remnant measurement.** I have not re-derived it and
will not until that input exists — a missing input is a result, not a gap to fill with the nearest
available number.

---

## 2. DOWNSTREAM — WHAT ELSE RESTED ON `1.02e5 M☉` BEING CHARACTERISTIC

This is the part the void list does not cover, and it is wider than the ringdown. **Every headline
number in INDEX §1 was computed at `M_hole = 1.02e5 M☉`** — a mass that was simultaneously the
board's `0.1717` sample *and* the cap. With the cap gone the two meanings come apart: it is now a
sample, full stop.

**The rows are still arithmetically correct at that mass. What is void is reading them as
characteristic.** The durable content is the scaling column, which re-maps everything once a
played-run mass exists:

| quantity | exponent | direction as the hole grows |
|---|---|---|
| `r_s`, photon sphere, ISCO, `b_c`, and all `eps`-ratios | `∝ M` | **better resolved** |
| peak disc temperature | `∝ M^(-1/4)` | **cooler** — moves further from X-ray |
| `f_220` and all QNM frequencies | `∝ M^(-1)` | lower |
| `tau_220` | `∝ M` | **longer** — the ringdown gets more showable |
| GR apsidal precession per orbit at `r_t` | `∝ M^(2/3)` | stronger |
| `r_t / r_s` for a solar-type star | `∝ M^(-2/3)` | **shrinks toward the horizon** |

⭐ **The removal of the cap improves three of the four things the science track flagged as problems**
— resolution, ringdown duration, and shadow/ring angular size all scale favourably with mass — and
worsens one: the disc temperature falls further below the soft-X-ray band that made the emission
argument work at 50 M☉.

### 2a. ✅ CLOSED — THE TDE THRESHOLD NEEDS NO MEASUREMENT, BUT THE ANSWER SPLITS BY STELLAR TYPE

`[reasoned from the field-mass ceiling, which is a definition not a code read; concluded 17:30]`

I queued this as needing a played-run mass range. **It does not — the field mass bounds it**, and
the credit for spotting that is the build window's: **a hole cannot outweigh the field it eats
from**, so `M_BH <= M_field = 5.94276e5 M☉` and `r_t/r_s` has a *floor*, not a threshold. Their
three values reproduce (mine, from `r_t = R_*(M_BH/M_*)^(1/3)` and `r_s = 2GM/c^2`, agree within
2% on constant choices): `107.8` at `1.02e5`, `79.4` at `1.61e5`, **`33.3` at the whole field**.
Since `33.3 >> 1`, **a solar-type star is always disrupted, at every reachable hole mass.** Bound
recorded, threshold withdrawn. The bound is stronger than it looks: as `M_BH -> M_field` there is
no field left to supply a star.

⛔ **BUT `r_t/r_s` depends on `R_*`, not only on `M_BH`, and for compact objects the conclusion
INVERTS.** Same arithmetic, run across the stellar types a real population contains:

| stellar type | `r_t/r_s` @1.02e5 | @1.61e5 | @field | swallow-whole `M_BH` | verdict |
|---|---|---|---|---|---|
| red giant (1 M☉, 100 R☉) | 1.08e4 | 7.9e3 | 3332 | 1.1e11 M☉ | always disrupted |
| B star (10 M☉, 4 R☉) | 200 | 147 | 61.9 | 2.9e8 M☉ | always disrupted |
| solar-type MS | 108 | 79.4 | 33.3 | 1.1e8 M☉ | always disrupted |
| M dwarf (0.2 M☉, 0.21 R☉) | 38.7 | 28.5 | 12.0 | 2.5e7 M☉ | always disrupted |
| **white dwarf** (0.6 M☉, 0.013 R☉) | **1.66** | **1.22** | **0.51** | **2.19e5 M☉** | 🚨 **REACHABLE — swallowed whole above it** |
| **neutron star** (1.4 M☉, 13.0 km) | **1.7e-3** | **1.2e-3** | **5.1e-4** | — | 🚨 **ALWAYS swallowed whole** |

⭐ **Two draw-relevant results.** A **white dwarf** crosses `r_t = r_s` at `2.19e5 M☉`, which is
**below the field-mass ceiling of `5.94e5 M☉`** — that bound alone makes it reachable, and it is
the only warrant used here.

> ⚠️ **RECONCILED 2026-08-31 17:45 — an earlier draft of this sentence called `2.19e5 M☉` "only
> 1.35x above the already-measured `1.61e5 M☉`", which contradicted §1 of this same document,
> where I refuse to adopt `161,690 M☉` for anything.** The refusal stands and the proximity claim
> is withdrawn — it added nothing the field-mass bound does not already give.
>
> **The asymmetry I should have stated instead:** a single idle sample is a valid **lower bound on
> what the system can reach** and is never a **ceiling**. So `161,690 M☉` legitimately establishes
> "masses at least this large occur", and illegitimately establishes "masses no larger occur" —
> which is exactly the claim the ringdown needs and cannot have. **But that asymmetry does not
> rescue a distance-to-threshold claim**, because `1.35x` is a statement about where the maximum
> *is*, not about what has been reached. Using the number that way was adopting it as a ceiling
> under another name. The TDE result needs no measurement at all, which was the whole point. A **neutron star** is swallowed whole at every hole mass in this simulation; `r_t/r_s ~ 1e-3`
means it crosses the horizon intact, with **no disruption, no debris stream and no flare** — only a
plunge. Higher-mass white dwarfs are *smaller* (Chandrasekhar), so the WD row is conservative in
the swallow-whole direction.

⚠️ **Conditional, and I cannot check it:** this matters only if the population contains compact
objects, or if stars are allowed to evolve into them. `imf::massOfId` assigns mass per id and
whether any ids carry compact-object radii is a `src/` question outside my `docs/` grant. **If the
population is main-sequence-only, the build window's "always a disruption" is correct without
qualification.** If it is not, star+BH has *two* visual outcomes, not one, and they are opposites.
⚠️ **The `@1.61e5` column is an evaluation point, not a bound** — `r_t/r_s` is a function of
`M_BH` and I have tabulated it at three masses for reference. The only column that carries a
*claim* is `@field`, because `M_BH <= M_field` is a consequence of the unit convention rather than
a measurement. Neutron-star radius from Miller et al. 2019, *ApJL* **887**, L24,
`doi:10.3847/2041-8213/ab50c5` (NICER, PSR J0030+0451); the verdict is insensitive to the EOS
uncertainty since `r_t/r_s ~ 1e-3` either way. Full table: `science-2026-08-31/tde-swallow-bound.csv`.

`resolution-verdict-table.csv` was already mass-parametrised across 9 mass rows and **needs no
reissue** — it is the one deliverable this correction does not touch.

---

## 3. WHAT SURVIVES FROM THE `F_BH_CLUSTER` FINDING

The code criticism is void — there is no constant left to relabel. **The literature content is
unaffected and is the reusable part:** the observed `M_BH/M_NSC` ratio spans three regimes over more
than two decades (Neumayer & Walcher 2012, `doi:10.1155/2012/709038`), depends on host galaxy mass
with a channel transition at `~1e9 M☉` (Neumayer, Seth & Böker 2020,
`doi:10.1007/s00159-020-00125-0`), and has an aperture-dependent denominator.

⭐ **Any future constant that fixes black-hole mass as a fraction of field mass inherits every one of
those objections.** If a ceiling returns in another form, it is a convention calibrated to one
galaxy, not a scaling law, and it must be labelled that way. Worth keeping precisely because the
constant was deleted rather than corrected — the objection outlived its target.

---

## 4. PROVENANCE CONVENTION — ADOPTED

The root cause is exactly as diagnosed: **a science stamp dates the REASONING, not the CODE.** I
reasoned from `src/` excerpts pasted at one time and stamped the conclusion with the wall clock of a
later time, so `SETTLED 16:30` certified a mechanism deleted at `16:10:25` — false at the moment of
stamping, wearing the strongest confidence marker I have, with a timestamp that looked *newer* than
the truth. That is worse than staleness: staleness degrades visibly, this inverted the freshness
signal.

**From now on, every claim about the code carries both times:**

    [reasoned from src @ <sha or paste-time>, concluded <time>]

**And where I do not know when an excerpt was taken, I say so — that is a result too.**

Retro-labelling what is knowable for the existing documents:

| document | source provenance | conclusion time |
|---|---|---|
| P1, P2, P3 (the three big references) | no `src/` access; written from the brief only | 2026-08-31 ~11:00-12:00 |
| INDEX | `src` excerpts via `SCIENCE_PROMPTS_2026-08-31.md`, **self-dated verified 14:25:53** | 12:30 |
| ADDENDUM_01 | excerpts pasted 12:57 | 15:10 |
| ADDENDUM_02 | excerpts pasted 13:13 | 15:40 |
| ADDENDUM_03 | excerpts pasted 13:27 and 13:44 | 16:10, amended 16:30 and 16:50 |
| ADDENDUM_03 §3 "CLOSED" | excerpts pasted 13:44 — **already 26 min stale when stamped** | ⛔ void |
| ADDENDUM_04 (this) | `src` state reported 15:23-17:00, **not read by me** | 17:05 |

⛔ **I have never read `src/` directly. My grant is `docs/` only.** Every code claim I have made is
second-hand from a paste, and the paste time is the real provenance — never the conclusion time.
**That limitation should have been stated in the INDEX on the first pass and was not.**

---

## 5. WHAT I GOT WRONG THIS ROUND

1. **Stamped `✅ SETTLED` on a mechanism deleted 20 minutes earlier**, then refined it twice more.
   Three messages spent on a subject that did not exist.
2. **Used the conclusion time as the claim's timestamp**, which inverted the freshness signal — the
   stamp made the claim look more current than the code it described.
3. **Treated a traced `file:line` as durable.** It is a pointer into a moving tree; without a read
   time it certifies nothing.
4. **Did not flag that I have no `src/` access.** Every code claim in these documents is second-hand
   and I should have said so once, at the top, on the first pass.

The `✅` and `⛔` markers in the affected sections have been demoted in place, so no confidence
marker is left standing on retracted text.
