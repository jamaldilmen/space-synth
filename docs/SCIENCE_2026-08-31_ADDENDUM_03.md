<!-- SCIENCE TRACK ADDENDUM 03 — Claude Science project SPACE SYNTH X · 2026-08-31 16:10
     Answers corrections 6, 7, 8 from the repo. All three accepted. Amends the P1 document in
     place (§3.1, §4.1, §4.2, §4.3), the INDEX (§1), ADDENDUM_01 (§4), and banners the P3 document.
-->

# ADDENDUM 03 — THREE CORRECTIONS, ONE OF THEM AN INVERTED SIGN

All three accepted, all three verified in-kernel before editing. **Correction 7 is the serious
one: a physical claim was backwards, in the direction that matters for what gets drawn.**

---

## 1. CORRECTION 6 — THE `eps` ERROR WAS NOT INDEX-ONLY. I WAS WRONG TO SAY IT WAS.

`SCIENCE_2026-08-31_blackhole_appearance.md` §4 carried `ε = 0.031` throughout, including the
entire §4.1 resolution-budget table. **§4 is the draw / do-not-draw section — the part F1
consumes** — so this was the worst place for it to be. Corrected in place, with the two-eps
structure now stated in the section header:

| feature | sim | fine `ε = 0.0625` | was (at 0.031) | coarse `ε = 1.0` |
|---|---|---|---|---|
| horizon `2M` | 0.1717 | **2.75** | 5.5 | 0.17 |
| photon sphere `3M` | 0.2576 | **4.12** | 8.3 | 0.26 |
| critical curve `3√3 M` | 0.4461 | **7.14** | 14.4 | 0.45 |
| ISCO `6M` | 0.5151 | **8.24** | 16.6 | 0.52 |
| `n=2` lensing ring width | 0.0990 | **1.58** | 3.2 | 0.10 |
| `n=3` photon ring width | 0.00344 | **0.055** | 0.11 | 0.003 |

Also corrected in §4.1: the hole whose horizon equals one fine `ε` has geometrized `M = ε/2 =
0.03125` sim and a physical mass of **`37,142 M☉ = 6.25%` of the field**, 36.4% of the formed
hole; and a 50 M☉ seed needs `M_field < 800 M☉` for `r_s > ε`, not `1613 M☉` — which at
`N = 1e7` is `8×10⁻⁵ M☉` per particle.

⛔ **CORRECTED 2026-08-31 16:30 — this paragraph first said `18,571 M☉`, contradicting the
`6.25%` in the same sentence.** `M/M_field = r_s/r_s(M_field) = ε/1 = 0.0625`, so
`M = 0.0625 × 594,276 = 37,142 M☉`. The factor 2 is already spent turning `r_s` into `M`;
multiplying the geometrized `ε/2` by `M_field` spends it twice and halves the answer.
`37,142 M☉` is the same threshold as the branch point on `2·M_hole/ε`.

⛔ **§4.2's brightness cutoff is also corrected, and it was a real trap.** It read *"brightness
from the particle field, at `≳ 2–3 ε`"*. At the live `ε` that is `0.1875 sim = 2.18 M`, which
**exceeds the horizon at `0.1717`** — applied literally it would have excluded the hole itself.
Restated as **`r > r_s +` one fine `ε` = `0.234` sim** for the formed hole: the exclusion belongs
relative to `r_s`, never as a multiple of `ε`.

**P3 is clean of `eps` but carried `N = 2e6`** — a banner now points its cost sections at
ADDENDUM_02 §1. **P2 is clean of both.** ADDENDUM_01's "INDEX-only" row is withdrawn.

---

## 2. 🚨 CORRECTION 7 — THE `Ω` ERROR DIRECTION WAS INVERTED

P1 §3.1 said the coded law makes orbits turn **"3.4× too slowly, so the Doppler asymmetry is far
too weak."** **That is backwards.** `Ω_correct = M^{1/2} Ω_code` at large `r`, and `M^{1/2} =
0.293`, so the *correct* frequency is the *smaller* one: **the coded law is too FAST and the
Doppler asymmetry is too STRONG.** Reproduced in-kernel:

| `r` (sim) | `Ω_code = 1/(r^1.5+0.5)` | `Ω_correct` | ratio | `β_code = Ω_code · r` |
|---|---|---|---|---|
| 0.5151 (ISCO) | 1.1498 | 0.7665 | **1.50×** | 0.592 c |
| 1.0 | 0.6667 | 0.2894 | **2.30×** | 0.667 c |
| 11.70 (`R_half`) | 0.0247 | 0.0073 | **3.37×** | 0.289 c |

tending to `1/M^{1/2} = 3.41×`. **The fix in §3.1 was right; the predicted visual consequence was
inverted.** Corrected in §3.1, and the §4.3 verdict that repeated it.

**Why this matters for F1 and not just for the docs:** an asymmetry that is too strong looks like
a *feature* — a vivid, confident-looking beaming crescent — whereas one that is too weak looks
like a bug you would go and fix. The inverted claim pointed at the wrong symptom, and a reader
following it would have turned the asymmetry *up*.

### 2a. The second layer, which I did not have

The law is applied **per particle, about a single fixed axis through the whole field** — not about
a hole. Against the field's own circular speed at the half-mass radius:

    beta_code = 0.289 c     v_circ(R_half) = 0.146 c     ->  2.0x too fast

So the entire field is beamed as if it rotated at twice its actual speed, independent of any
hole. **Restoring the dimensional factor does not fix this.** The law has to be evaluated per
hole, about that hole's own spin axis, and only for `r ≥ r_ISCO` of that hole — which is the same
conclusion §3.1 already reached about the fixed axis, arrived at from a different direction.

---

## 3. CORRECTION 8 — `tau_220 = 11.8 s` ASSUMED A MERGER THE CODE FORBIDS

The single value assumed **both** parents already at `1.02e5 M☉`, giving `M_f = 0.95162 × 2 ×
1.02e5 = 1.94e5 M☉ = 32.7% of the field` — above the **17.2% cap** the code enforces
(`F_BH_CLUSTER`, `particles.metal:289`). If the cap is applied post-merger, the largest reachable
remnant is `1.02e5 M☉`:


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

⛔ **VOID — TEXT BELOW PRESERVED FOR THE RECORD ONLY; the `✅ CLOSED` marker is demoted. See
`SCIENCE_2026-08-31_ADDENDUM_04.md`.** ~~CLOSED 2026-08-31 16:30 — the cap DOES apply
post-merger, and it is a REFUSAL, not a clamp.~~
Traced in `particles.metal`: `:1580` the seed-seed merge path, `:1647`
`mBoundM = F_BH_CLUSTER * fieldMassMsun`, `:1648` `headM = mBoundM - mS`, `:1649`
`if (headM <= 0) continue` — the merge is **declined**. Per `:1636` the claim must fit whole, so
overshoot is exactly zero by construction, and `:1641` records that merges are deliberately free
below the ceiling because a merge is a discrete event. When it is refused, **both holes stay
alive and orbiting and mass is conserved exactly.**

**So there is no range. The live figure is:**

| | `M_f` | % of field | `f_220` | `tau_220` | sim-time |
|---|---|---|---|---|---|
| maximum reachable remnant | **102,144 M☉** | 17.2% (the cap) | **0.167 Hz** | **6.19 s** | **1.06** |
| two cap-mass holes | 1.94e5 M☉ | 32.7% | 0.088 Hz | 11.8 s | 2.01 |

⛔ **The second row is UNREACHABLE in this code** — it would require the cap removed or the field
mass roughly doubled. **Quote `tau_220 = 6.19 s` and say so if the 11.8 s figure is kept at all.**
⛔ **CORRECTED 2026-08-31 16:50 — I wrote that the cap binds on the *remnant* and that `6.19 s`
therefore survives INDEX §2 row 9. Both halves are wrong.** The guard binds on the **SUM OF THE
TWO PARENTS, before any merge happens**: `:1648 headM = mBound - mS` measures the survivor, and
`:1636` requires the victim to fit whole, so the constraint is `survivor + victim <= 102,144 M☉`.
Today mass is conserved through the merge, so `remnant == sum` and the two readings coincide —
which is why the distinction was invisible and why I should have taken it from the traced lines
rather than inferred it.

**Implement row 9 (the mandatory 4.84% GW mass deficit) and they separate:**

| | max parent sum | remnant | `f_220` | `tau_220` | sim-time |
|---|---|---|---|---|---|
| today (mass conserved) | 102,144 M☉ | **102,144 M☉** | 0.167 Hz | **6.19 s** | 1.06 |
| once row 9 lands | 102,144 M☉ | **97,202 M☉** | 0.175 Hz | **5.89 s** | 1.01 |

`tau_220` drops by exactly the 4.84% deficit. **Record it as `6.19 s` today and `5.89 s` once
row 9 is implemented, unless the guard is moved to bind on the post-deficit remnant** — which
would be a deliberate change, not a consequence of row 9. Either way it stays ~3 decades above
the `5.77 ms` at seed mass.
**The conclusion is unaffected either way** — both values are ~3 orders of magnitude longer than
the `5.77 ms` at seed mass, so a BH–BH ringdown is showable at formed mass and is not at seed
mass. Corrected in INDEX §1.

---

## 4. NOTED, NO CHANGE

**P3 §4.3 on reversibility.** The document advises against adaptive timestepping partly on the
grounds that accretion and merger are not physically reversible. Your position is that
reversibility is mandatory by the project owner's explicit call and is a narrative choice, not a
physics claim. **Agreed, and no change needed** — the physics statement (leapfrog is exactly
reversible only at fixed step; a time-symmetric criterion is needed otherwise, Hut, Makino &
McMillan 1995) stands on its own and is independent of whether you *want* reversibility. The doc
should not be read as arguing against the design decision.

---

## 5. WHAT I GOT WRONG THIS ROUND

1. **Stated a physical direction backwards** and repeated it in a second section. The arithmetic
   `Ω_correct = M^{1/2} Ω_code` was right in the same paragraph; I read the ratio the wrong way
   round when converting it to a sentence about what an observer sees.
2. **Claimed the `eps` error was confined to the INDEX** without grepping the three documents I
   had just written. It was in the one section F1 consumes.
3. **Published a resolution cutoff as a multiple of `ε`** rather than relative to `r_s`, so it
   inverted its own meaning when `ε` doubled.
4. **Quoted a ringdown timescale for a merger the code's own cap forbids**, without checking the
   remnant mass against `F_BH_CLUSTER` — a constant I had discussed two addenda earlier.

Items 2 and 4 were both checkable against material already in front of me.
