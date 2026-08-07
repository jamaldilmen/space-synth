# MEASURED — C7, THE CARTWHEEL COLOUR DELTA

**Measured:** 2026-08-08 01:30:58 — code reading only, nothing changed, nothing run.
**Answers:** BOARD C7, which was the only row in the Berlin cut with no cost estimate at all.
**Supersedes:** the "it's probably a lens half-space gate" lead from `HANDOFF_2026-08-07` §4. That
lead is **wrong** — see §3.

---

## THE FINDING, IN ONE LINE

> **The radial colour law he wants already exists, is correct, and is switched OFF whenever there is
> no measured horizon. C7 is not a colour bug. C7 is downstream of A1′.**

---

## 1. THE RADIAL LAW EXISTS AND IS THE RIGHT ONE

`render.metal:1667`, written 2026-07-23 in response to his *"two halves, green and yellow, cut with
a knife — the culprit of the colours around the black hole"*:

```
if (cam.horizonR > 0.0f) {
    ...
    float Tdisk = 26000.0f * pow(rIn / max(rD, rIn), 0.75f);   // Shakura–Sunyaev T ∝ r^(−3/4)
    starColor = mix(starColor, blackbodyRGB(clamp(Tdisk, 1500, 26000)), dzone);
}
```

That is **exactly** the JWST Cartwheel palette law: white-hot inner edge cooling continuously to
deep orange-red outward, no bands. The source comment says so and says the reference image's palette
*is* this law. **Nothing needs to be invented.**

## 2. IT IS GATED ON A HORIZON EXISTING — AND THAT GATE IS USUALLY FALSE

`cam.horizonR = lastHorizonRSmooth` (`renderer.mm:1601`, `:1849`). Measured across every run logged
tonight:

| Run | `r_h` values seen |
|---|---|
| soak, seed 42 | `0.0000` … then 0.1172 → 0.4102 **only after runaway began** |
| re-test, seed 7 | `0.0000` … then 0.0977 → 0.3711 **only after runaway began** |
| re-test, seed 42 | `0.0000` … then 0.8984 → 0.9375 **only after runaway began** |

`r_h` is **0.0000 for the entire pre-runaway life of every run.** So for the whole period the field
actually looks like a galaxy, the radial law is off and colour falls back to `unifiedKelvin(mass,
play-heat, kinetic)` — which has **no radial term whatsoever**. It cannot organise by radius because
nothing in it depends on radius.

**And once `r_h` does go positive, the runaway is already eating the field** (A1′). By the time the
Cartwheel law switches on there is nothing left to colour — `live` was down to 19 in the worst case.

> **The window in which the Cartwheel look is possible is exactly the window in which the field is
> being destroyed.** That is the whole of C7.

## 3. THE HALF-SPACE — AND WHY THE OLD LEAD WAS WRONG

The 08-07 handoff guessed a lens half-space gate, citing the old "two circles" bug. **Ruled out:**
the only surviving `half-space` mention in the renderer (`render.metal:1001`) describes a gate that
was **removed** in 2026-07-26.

**Doppler as a hue term is also ruled out — deliberately.** It was removed 2026-06-26 with the
reason recorded at `render.metal:1368`: folding line-of-sight terms into colour made the field *"a
screen-space red/blue gradient that ROTATED with the camera"* — his *"linear filter, not colour the
particles own"*. Colour now comes from the particle's own state only. **Do not re-propose Doppler
hue; it has already been tried and rejected on his verdict.**

**What actually remains is ONE half-space term, and it is in LUMINANCE, not hue:**

```
render.metal:1307   out.luminance *= pow(beam, DOPPLER_EXP);   // K_BEAM 0.8, exp 1.4
```

Relativistic beaming off the real orbital velocity — approaching side brighter, receding side
dimmer. It is the **only line-of-sight half-space left anywhere in the colour/lighting path.**

⚠️ **Hypothesis, NOT verified:** a luminance half-space can read as a *colour* half-space downstream,
because the bright half blooms and compresses toward white/blue while the dim half stays saturated
orange. That matches the observation ("orange one side, blue-white the other") without any hue term
existing. **Testable in one step:** set `DOPPLER_K_BEAM = 0` and look. **Needs his eyes — do not
claim it.**

## 4. 🐛 A DEAD VARIABLE AND A COMMENT THAT LIES

`dopplerColor` is declared (`:1273`), computed (`:1305`) — and **never read anywhere.** The only
other mention is a comment at `:1440`:

> *"Doppler shift is already applied above via dopplerColor. Colour is now…"*

**That comment is false.** It asserts an application that does not happen. It is worse than dead
code, because anyone reading it concludes Doppler is in the hue path when it was removed on purpose.

This is the **fourth** instance of the pattern from the 08-07 disabled-code sweep: built → changed
course → left in place → the leftover now misinforms. Delete the variable and fix the comment.

---

## WHAT THIS MEANS FOR THE BERLIN PLAN

**C7 cannot be worked on independently, and the board was wrong to list it as a separate visual
item.** The order is forced:

1. **A1′ first** — make a hole that forms and *persists* without consuming the field. Until a
   horizon can exist over a field that still has matter in it, the radial law has no conditions
   under which to run.
2. **Then C7 is mostly free** — the law is already written and already correct. The remaining work
   is tuning `dzone`'s extent (currently `1.6·r_h` … `8–16·r_h`) so the coloured region covers a
   galaxy-scale disk rather than a small zone around the hole.
3. **Independently, and cheap:** kill `dopplerColor` + the false comment, and A/B `DOPPLER_K_BEAM =
   0` to settle whether beaming is what he is reading as the half-space.

**Revised cost:** C7's `?` becomes **S**, but *strictly gated behind A1′*. The good news is that the
single most valuable visual item and the single hardest physics blocker are now known to be the
same piece of work, so effort there counts twice.
