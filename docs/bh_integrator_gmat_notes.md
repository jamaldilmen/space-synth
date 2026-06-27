# Black-Hole Engine — Adaptive Integrator notes (from NASA GMAT)
_Last Updated: 2026-06-27 12:05:00_
_Source: NASA General Mission Analysis Tool (GMAT), open source. Step-control formula
read verbatim from `src/base/propagator/RungeKutta.cpp::AdaptStep` and
`RungeKuttaNystrom.cpp` clamping; defaults from GMAT Propagator docs/tests._

## Why this matters to us
Our black hole is stuck on the **resolution↔stability trilemma**: coarse cells can't
resolve the horizon; fine cells eject bodies via the c-cap because **fixed dt × huge
near-horizon acceleration = huge Δv**. GMAT solves exactly this class of problem with an
**embedded Runge-Kutta + error-controlled adaptive step**. The error estimate spikes
where the acceleration spikes → the integrator automatically sub-steps through close
encounters and grows the step again far away. That kills the c-cap ejection *at the
source* instead of masking it with ε-softening.

## GMAT integrator menu (embedded RK pairs, all variable-step)
- **RungeKutta89** — order 8(9). GMAT default workhorse; Accuracy `1e-12` in tests.
- **PrinceDormand78** — order 7(8). Most accurate in GMAT's V&V; tied 89 on speed (LEO).
- **PrinceDormand45** — order 4(5). Cheaper; classic Dormand–Prince (same family as RK45/ode45).
- **RungeKutta68**, **RungeKutta56** — mid orders.
- **AdamsBashforthMoulton** — multistep predictor-corrector (not our case; needs history).

For a real-time GPU sim, the cheap **PrinceDormand45 (order 4/5)** is the right starting
point — it gives a free embedded error estimate per step at low order.

## The step-size control algorithm (the part we copy)
Constants (from the RungeKutta constructor):
```
sigma    = 0.9            // safety factor
incPower = 1.0 / order    // growth exponent on an ACCEPTED step
decPower = 1.0 / (order-1)// shrink exponent on a REJECTED step
```
Per attempted step:
```
maxerror = EstimateError()              // from the embedded high/low order pair
accept if (maxerror <= tolerance)       // tolerance := Accuracy setting

// on REJECT (error too high) — shrink and retry:
stepSize = sigma * stepSize * pow(tolerance / maxerror, decPower)

// on ACCEPT — set the NEXT step (grow toward tolerance):
stepSize = sigma * stepSize * pow(tolerance / maxerror, incPower)

// always clamp:
if (|stepSize| < minStep) stepSize = ±minStep
if (|stepSize| > maxStep) stepSize = ±maxStep

// retry up to maxStepAttempts; if still failing AT minStep, accept the "bad step"
// (with warning) or throw, per stopIfAccuracyIsViolated. GMAT calls this a "kludge"
// for genuine discontinuities (e.g. SRP shadow edges).
```

## Key parameters + GMAT defaults / guidance
- **Accuracy (tolerance):** `1e-12` for orbit precision. For a real-time visual sim this
  is far tighter than we need — tune up (looser) until the BH is stable but cheap.
- **ErrorControl:** default **RSSStep** (root-sum-square of the relative error over the
  step). Options: RSSState, LargestStep, None. RSSStep is the sane default for us.
- **MinStep:** recommend **0** so the adaptive algorithm fully owns the floor; non-zero
  min steps are flagged as dangerous (they force acceptance of inaccurate steps).
- **MaxStep / MaxStepAttempts:** cap the grow side and the retry count.
- **StopIfAccuracyIsViolated:** whether to hard-fail or warn when stuck at minStep.

## How to apply it to SPACE SYNTH (next physics task)
1. Keep the per-frame **render dt fixed**; sub-step the **physics** internally with an
   adaptive count driven by the formula above (a render frame = N adaptive physics steps).
2. Use an embedded pair for the free error estimate. Start with **PrinceDormand45**
   (order 4/5) — if we don't want a full embedded scheme yet, **step-doubling**
   (one full step vs two half steps) gives the same error estimate at ~2x cost.
3. Map "Accuracy" to a tolerance on per-step position/velocity error in sim units;
   expose it as a single HUD knob (the cockpit's "integration accuracy").
4. Result we expect: near the horizon the estimated error explodes → step auto-shrinks →
   the body is resolved instead of c-cap-ejected; far out the step grows → cheap. This is
   the path off the fixed-dt + ε-softening crutch (see `space_synth_us2_engine_plan.md`).

## Sources
- GMAT `RungeKutta.cpp` / `RungeKuttaNystrom.cpp` (github: ddj116/gmat mirror)
- GMAT Propagator reference + V&V test configs (Accuracy 1e-12, ErrorControl RSSStep)
