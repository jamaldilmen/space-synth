# MEASURING THE LENS IN A UNIVERSE THAT WON'T HOLD STILL
**Written:** 2026-08-31 21:02:58 · FABLE window · his order via BRAIN: *"Hand the problem
to fable."* Design only — the code changes named here are NOT ordered; OPUS builds
nothing from this without his go.
**Inputs:** OPUS's five voided attempts and the `/tmp/lenscost.4YMUj7` logs (read by me),
BRAIN's drift measurement and ABAB finding (recomputed by BRAIN from raw logs), the B2a
instruments verified in tree 21:02:58 (`renderer.mm:1790` PROFILE, `:4284` debug block,
`SS_LENS_DEBUG=2` step heat — already labelled "THE COST PROBE" — `SS_LENS_PIN_RS`,
`SS_LENS_DPHI_DIV`).

---

## 0. WHY EVERY BETWEEN-RUNS DESIGN WAS STRUCTURALLY VOID — not badly run, WRONG SHAPED

⛔ **SCOPE CORRECTION 2026-08-31 21:10:23 — HIS, verbatim:** *"Also all this is once more
still only at rest which you don't seem to understand. I play it. Particles return. New
stuff forms."* **He is right.** `[MEASURED by BRAIN]` all four arms were 100% silent
(470/470-class `[CLUSTER] SILENCE`), so every number in this section describes REST ONLY
— an UNDRIVEN system. The sim is DRIVEN and he is the drive: `[READ renderer.mm:3411]`
sustain rebirth WITHDRAWS mass from the hole and returns matter, only while playing.
Every "no steady state" claim below is scoped to rest accordingly.

Three stacked facts about the REST regime, each sufficient alone:

1. **At rest there is no steady state.** `[MEASURED by BRAIN from the arm logs]` the
   idle hole eats ~95% of the tracer field in ~4 minutes; Compute fell 10.45 → 2.12 ms
   across arms. "Run longer to settle" DRAINS a rest measurement — a longer run is a
   more eaten sim, not a calmer one. (Under play the opposing process runs; nothing
   tonight measured that regime.)
2. **The background is up to ~80× the signal and not even monotone.** `[MEASURED by me,
   read-only, from o_*.log 21:02:58]` Render+PostFX within single arms: A1 14.17 → 6.93
   ms, B2 13.61 → 27.21 → 11.96 ms mid-run. ⭐ **BRAIN's independent full-series check
   (21:07:17) strengthens this:** within-arm swings 3.0× / 3.3× / 4.9× / 5.0×, full
   range 5.48–29.08 ms, non-monotone in all four arms — my sub-sampled series
   UNDERSTATED it. The sought signal was then believed ~0.3 ms (⛔ retired in §2 — the
   direct bracket later measured ≤5.15 ms at one work level; the conclusion here only
   strengthens). No mean over that background resolves a small pass; differencing two
   such series is subtracting two large drifting numbers to find a small one.
3. **ABAB correlates arm with time order** `[BRAIN's find]` — under monotone falling
   cost, B is cheaper by construction; the paired deltas agreeing to 0.03 ms was the
   drift being measured twice, not cancelled. ABBA fixes the linear term only; fact 2
   says the drift is not linear, so even ABBA is not enough at 0.3 ms resolution.

⭐ **Conclusion: at this signal-to-background, the lens cost cannot be measured BETWEEN
runs at all. It must be measured WITHIN the frame.** The negative delta was the
experiment announcing this; OPUS reporting it as void instead of shipping a number was
exactly right.

## 1. THE REFRAME — the drift is not the enemy, it is the sweep

The lens cost is not one number. It is a FUNCTION: `ms(work)`, where work = covered
pixels × steps per ray. The go/no-go question ("is it affordable at the show config?")
is a question about that function evaluated at the 33 MP wall feed — a point no
laptop-screen measurement visits anyway. So the deliverable is a fitted COST MODEL:

```
ms_lens ≈ k · S + c        S = total geodesic steps in the frame
```

And here the rest-collapse inverts into an asset: **the free-running hole sweeps r_s
over a 5× range in one run, sweeping S for free.** One un-pinned run with per-frame
(ms_lens, S) pairs traces the whole curve; the pinned runs become fixed-S validation
points on it. Extrapolation to the wall feed is then stated with the fit's own
residuals, not hand-waved.

### 1a. THE MODEL'S DOMAIN — stated so the curve is never silently extrapolated

**What ms(S) is valid for:** the B2a march terminates on horizon / escape / winding-cap
— **none of which involve particles.** Its per-frame cost is a function of (r_s, camera,
resolution) THROUGH S, and the field's fullness never enters. So the fit is valid for
ANY regime — rest, play, transition — whose S falls inside the swept range
[S_min, S_max]; the collapsing field biases only WHICH S values the sweep visits, not
the ms↔S relation. The 33 MP extrapolation beyond S_max was already flagged; it remains
the one extrapolation, stated with residuals.

**Where the domain HARD-STOPS: B2b.** The moment rays terminate on particles and
opaque cells, cost gains a genuine field dependence — a fuller field terminates rays
EARLIER (fewer steps) but pays a per-step particle-test cost. `ms(S)` becomes
`ms(S, field)`, and the rest-collapsed field is then the CHEAP corner: few particles to
test AND no early-termination savings to mismeasure. ⛔ **The B2b-era cost must be
re-swept with the same bracket instrument across field states including the
transition (lens on, field refilling) — this doc's fit does not price it and must not
be quoted for it.**

**The transition, specifically:** `[READ renderer.mm:1907]` `bhLensActive =
(totalAmplitude < 0.02f)` — the lens is gated OFF during play by a hard amplitude
threshold, so today the lens never sees a full field except in the instants around
that switch. ⭐ **The F1 design supersedes this gate by physics:** its region area is
∝ r_s(M)², and play DRAINS M — so under F1 the lens leaves the frame continuously
because the hole leaves, no amplitude switch needed. The binary `:1907` gate is a
pre-law mechanism; whether it survives F1 is a design question flagged in §6, not
resolved here.

## 2. PRIMARY DESIGN — direct per-frame bracketing. No subtraction anywhere.

**Isolate the lens pass in its own command buffer** (measurement flag only). Metal gives
`GPUEndTime − GPUStartTime` per command buffer — the exact instrument `[PROFILE/120f]`
already trusts at `renderer.mm:1790` — so the lens pass gets its own per-frame GPU time
DIRECTLY. Nothing is differenced; facts 1–3 above simply stop applying, because the
drifting rest-of-frame is never part of the number.

Per frame, log one line: `[LENSCOST] ms=<bracket> steps=<S> px=<covered>` where:
- `S` = total geodesic steps — the reduction the `SS_LENS_DEBUG=2` heat target already
  computes per pixel; summing it is the one new wrinkle (an atomic add or a small
  reduction pass over the heat target — measurement path only).
- `px` = covered pixels (region area) — cheap analytic count from `B_geo·r_s` and the
  camera, no readback.

**Why direct beats the same-frame subtraction:** resolving a small pass by subtracting
two ~7 ms encodes needs both stable to a few %; bracketing it directly needs only
timestamp sanity. A subtraction design is a fallback (§3), not the primary.
⛔ **THE 0.3 ms PREMISE IS RETIRED — 2026-08-31 21:39:45.** This doc was shaped around
~0.3 ms inferred from the voided differential arms. The direct bracket's first real
reading: `[MEASURED by OPUS]` **89,368,329 geodesic steps over 165,880 px (538.8
steps/px), lowest reading at constant work 5.15 ms** — so, `[HYPOTHESIS: scheduling
envelope additive and non-negative]`, true cost ≤ 5.15 ms at that work level: **~15×
the premise.** The direct-beats-differential argument STRENGTHENS (a 5 ms pass is even
easier to bracket and even more hopeless to difference out of a 5–29 ms swinging
background); what changes is the affordability picture, which the sweep + fit must now
settle honestly — 5 ms at 0.166 Mpx covered says the live budget at large coverage is
in real question, and the answer is the fitted curve, not this one bound.

**Overheads, stated:** a second command buffer costs scheduling latency (order tens of
µs) and a possible pipeline bubble. Both are INSIDE the bracket and therefore
conservative — the measured number errs high, which is the safe direction for a
go/no-go. If the bubble is suspected material, the closure check (§4) exposes it.

**The runs** (all AC, `caffeinate -dimsu`, no notes played, per standing discipline):
1. **Sweep run, pin OFF:** free-running hole, ~4 min, `[LENSCOST]` every frame. Yields
   the (S, ms) cloud across the natural 5× range. Fit `k` and `c`.
2. **Pinned validation runs:** `SS_LENS_PIN_RS` at two values (e.g. 0.12 and 0.24 —
   4× area apart). Each yields a fixed-S cluster; both must sit on the sweep's fitted
   line (§4 gate).
3. **Extrapolate** to the show config: steps at 33 MP with the region at the largest
   mass he wants shown, from the same model — reported WITH residual bounds, never as
   a bare number.

## 3. FALLBACK — same-frame double encode (OPUS's `SS_LENS_ONLY` direction)

If command-buffer granularity proves too coarse for a ~0.3 ms pass, encode the lens
pass TWICE in one frame under the measurement flag and take the delta of the two
otherwise-identical command buffers — same state guaranteed by construction, drift
excluded within one frame. Costs a doubled lens pass (fine — measurement only) and
inherits subtraction fragility, which is why it is the fallback. The
`SS_NO_STARPASS`-style whole-pass toggle (`renderer.mm:4192` block) remains the
coarsest cross-check, valid ONLY frame-paired, never run-paired (§0).

## 4. THE GATES ON THE MEASUREMENT ITSELF — a measurement can fail too

| gate | pass | fail means |
|---|---|---|
| **Closure** | lens bracket + rest-of-RENDER bracket = PROFILE **Render+PostFX** within 5%, per frame — ⛔ **SCOPE CORRECTED 2026-08-31 21:39:45: as first written this said "whole-frame PROFILE total", but Total = Compute + Render (`renderer.mm:1786`) while the rest bracket is `lastRenderMs`, RENDER ONLY — the gate compared two different scopes and could never pass. MY defect, not the build's; OPUS's failing run diagnosed it.** The rule the correction teaches: a closure gate must NAME the scope both sides share | the bracket is leaking or double-counting; numbers untrustworthy |
| **Model fit** | pinned clusters sit on the sweep fit within 2× its residual spread | `ms(S)` is not the right model — something besides steps drives cost (divergence, occupancy); report as a FINDING, do not force the line |
| **Sanity sign** | every per-frame `ms_lens` > 0 | instrument broken (the current design's failure mode, made impossible by construction here) |
| **Step accounting** | S at pinned r_s stable to a few % frame-to-frame | the winding-cap annulus is unstable or the reduction is racy |

## 5. IF A BETWEEN-RUNS DESIGN IS EVER NEEDED AGAIN — the rules this one taught

Recorded for the next measurement, not for this one:
1. **Mirror the order** (ABBA at minimum; randomised arms if >2 runs) — ABAB under
   monotone drift measures the drift.
2. **Pair frames by STATE, not by index** — match on covered pixels / live count, the
   actual cost drivers, never on wall-clock position in the run.
3. **Regress, don't average** — with a 5× within-run drift, arms can only share a
   fitted model (`ms` on S and live count); comparing means compares how eaten each
   sim was.
4. **Pin what can be pinned, log what cannot.** `SS_LENS_PIN_RS` for area;
   `[PROBE-1000] live=` for the field.

## 6. FLAGS OUT OF SCOPE FOR THIS DOC — named so they are not lost

- 🎬 **A constraint that may LIFT, not a design input (his words 2026-08-31, via BRAIN):**
  *"I will not play it live all the time we will will pre record skit of it if not
  everything."* Parts of Cologne — possibly all — may be pre-recorded. Consequence for
  §1's extrapolation: its ROLE may shift from a pass/fail gate to a LIVE-vs-RECORDED
  split — the same fitted `ms(S)` curve answers both budgets, which is exactly why the
  deliverable is a curve and not a number. A recorded segment lifts the FRAME budget
  only: the honesty rules (no downscale, no fakes) do not lift with it — offline time
  buys π/1024, wider winding caps and A8 supersampling, not shortcuts. ⛔ Nothing here
  is re-scoped on this; how he arranges the set is zero concern to the sim, and this
  note exists only so the extrapolation is not later misread as a hard gate.

- 🔴 **The rest-rate itself is a SHOW question for him, not a measurement artefact:**
  idle eats ~95% of the field in ~4 minutes. §Z says rest grows the hole — but whether
  THIS RATE is the show he wants between songs is his verdict to give, once he can see
  it (which needs the lens…). One line, his call, not mine.
- The `tools/measure_lens_cost.sh` five-gate harness is worth keeping and re-pointing
  at the §2 design — its gates (power state, hole-mass spread) remain valid
  preconditions even for within-frame measurement.
- 🔴 **The `:1907` amplitude gate vs the F1 design** — today "lens OFF during play" is a
  hard threshold at `totalAmplitude 0.02`; F1 makes the same behaviour emerge
  continuously from the draining mass (region ∝ r_s(M)² → 0 under play). When F1 lands,
  the binary gate is either redundant or fighting the law's continuous transition —
  a design decision for that step, flagged now so it is not discovered mid-build.
- ⛔ **Everything in §2–§3 is a code change and is NOT ordered.** This doc is the
  design he asked to exist. OPUS builds it only on his go, as ONE verifiable change
  (the bracket + the `[LENSCOST]` line), then the sweep run, then STOP.

---
**Last Updated:** 2026-08-31 21:39:45 — two absorptions from OPUS's first bracket run:
§4 CLOSURE scope corrected (MY defect — it compared render-only against compute+render
and could never pass; the rule: a closure gate must NAME the shared scope) and the
0.3 ms premise RETIRED (first real reading: ≤5.15 ms at 89.4M steps / 0.166 Mpx —
~15× the premise; direct-beats-differential strengthens, affordability now rides on the
sweep + fit).
Previous stamp 21:10:23 — HIS scope correction folded (§0 is REST ONLY —
"I play it. Particles return. New stuff forms."); §1a added: the model's domain — valid
for any regime through S while B2a has no particle term, HARD-STOPS at B2b which must be
re-swept across field states; the `:1907` lens play-gate recorded and its F1 supersession
flagged in §6.
Previous stamp 21:07:17 — APPROVED, OPUS building ("Go on the build");
§0 fact 2 strengthened by BRAIN's full-series check (my sub-sample understated the
swing); §6 gains the pre-record note as a constraint that may lift.
First cut 2026-08-31 21:02:58, on his order via BRAIN. FABLE owns this file.
