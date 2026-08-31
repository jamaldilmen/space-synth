# SPACE SYNTH — handoff 2026-08-31 21:45:00 (OPUS window: B2a + the lens cost instrument)

**Cold start is the board, not this file.** `docs/BOARD_BLACKHOLE.md` **§Z** (§Z7–Z9 are this session)
and `docs/BOARD.md` **§W**. This is a **diff of one session**; where it disagrees with the board, the
board wins and this file is wrong.

**Tree:** `SPACE-SYNTH-TRUE-PHYSICS` @ `true-physics`. **Token:** held by OPUS at write time.
**Scope of this file:** the B2a lens instrument and five voided measurement attempts. The cap kill, the
four cannot-go-down kills and his 18:55:07 verdict are in `HANDOFF_2026-08-31_EVENING.md` — not repeated.

---

## 1. ✅ CLOSED THIS SESSION

- **B1 PASSED** — the geodesic marcher reproduces Schwarzschild deflection. `[MEASURED n=256 b-samples]`
  at `dphi = pi/512` against FABLE's corrected three-leg gate: strong-field rel **2.166e-04** (bound 1e-3,
  margin 4.6×), far-field abs **1.942e-05 rad** (bound 1e-4, margin 5.1×), capture `b_c` rel **3.365e-04**
  (margin 3.0×). Exit code 0. `tools/lens_march_validate.cpp`, already tracked at `5854a4a`.
  ⭐ Two independent methods sharing no code path: RK2 march vs quadrature mirror of the live LUT. RK2
  confirmed **second order** — error falls ~4× per halving across seven step sizes.
  ⛔ **`pi/64` is 32× too coarse for its own gate** (12% rel error at b=200). `pi/512` is 8× FABLE's
  original assumption and that cost is carried forward, not pre-shrunk to fit a budget.
- **B2a BUILT** — region mask + per-pixel march + termination classes. `SS_LENS_DEBUG=1` class colours,
  `=2` step heat. `[READ render.metal:3173]`. Default off.
- **THE COST BRACKET BUILT** — lens pass in its own command buffer, direct `GPUEndTime − GPUStartTime`,
  `SS_LENS_COST=1`. `[MEASURED n=3313 frames]`. Commit `c793e4a`.
- **A REAL CORRECTNESS FIX** — per-frame counters were accumulating (`steps` **1.95e9 → 2.42e9**
  monotonically). A CPU-side clear at encode time races the previous frame's still-executing command
  buffer; it is now a GPU `fillBuffer` blit inside the same buffer. Board **§Z8**.
- **`tools/measure_lens_cost.sh`** — six gates, each added because a human caught the fault it now
  catches. Commit `3672d89`. Its header states its own method is unsound by design.
- **THE VERIFIER WIDENED** — it swept only 4 files, so `blackhole-library/`, `DESIGN_*`, `SCIENCE_*` and
  `SWEEP_*` were invisible. Now **709 LIVE citations, DEAD 0**. Added a **MISMATCH** class that catches a
  symbol surviving near its cited line **only inside a comment** — the normal shape of a decayed citation,
  because a deletion almost always leaves an obituary that keeps the citation looking healthy. LIVE docs
  are the fatal gate; FROZEN handoffs are reported, never fatal.

## 2. 🚨 OPEN — his list, verbatim

- `[HIS WORDS 2026-08-31]` *"no shortcuts no fake lense"* — B2b (particle + opaque-cell termination) is
  **NOT STARTED**. T4 tests that, not B2a; a passing B2a says nothing about T4.
- `[HIS WORDS 2026-08-31]` *"I will not play it live all the time we will will pre record skit of it if
  not everything."* — parts of Cologne, possibly all, are **PRE-RECORDED**. A pre-recorded segment does
  not need realtime. **Recorded, not designed around.** ⛔ Do not re-scope a measurement on this and do
  not reason about how he arranges a set.
- **THE LENS COST IS STILL UNKNOWN.** Board **§Z7**. `[HYPOTHESIS — does not close the row]` a Metal
  counter sample buffer (timestamps at encoder boundaries inside ONE command buffer) would measure the
  encoder without the scheduling envelope. The §3 double-encode fallback inherits the SAME contention.
- **Closure gate must be redefined before it can pass.** `[READ renderer.mm:4947]` `restMs =
  lastRenderMs` (render only) vs `[READ renderer.mm:1786,:1797]` `PROFILE Total` = Compute + Render.
- **NOT DONE:** the mode-1 vs mode-2 A/B quantifying atomics inflation. Currently below a 3.3× noise floor.
- **`bhFormedLatch` is now LOG-ONLY** — after the strength floor died it affects no drawn value. A name
  with no mechanism should be deleted; **not ordered.**
- **The 220 px blob** is still gated on `horizonR` alone, not mass. Traced since 2026-08-10, **not ordered.**

## 3. ⛔ DEAD ROADS — recorded so they are not retried

**Five voided measurement attempts in one evening, each for a different reason. Board §Z9 has the table.**
The transferable finding: **three independent instruments — fps, `PROFILE` render time, and a direct GPU
bracket — all returned the same impossible sign** (lens ON measured *faster*). The lens cost is small
compared to everything else moving in the frame, and **no between-runs design can resolve it.**

- ⛔ **Never measure on battery, and never trust the word "AC Power".** `[MEASURED]` a partially-seated
  cable reads **80W/3990mA "not charging"**; a healthy one reads **100W/4990mA "charging"**. Both report
  "AC Power". ⭐ I saw 80W myself and wrote it off as "still comfortably AC" — **observing an anomaly is
  not gating on it.**
- ⛔ **`SS_SPAWN_SEED` does NOT make runs reproducible.** `[MEASURED]` identical seed, Mmax **14,532 vs
  55,390**. The fork is GPU **scheduling order**, not the RNG.
- ⛔ **ABBA does not rescue a differential design.** `Render+PostFX` swings 3.0–5.0× *within* an arm and
  is **non-monotone**; ABBA cancels a LINEAR drift only.
- ⛔ **fps is invalid near the refresh cap** — floored at vsync. Use `[PROFILE/120f]`, `renderer.mm:1790`
  — **it prints to STDOUT**, which is why it was missed all evening.
- ⛔ **A rising sequence is not a measurement.** Publishing 41.7 → 51.1 → 84.0 with a caveat was the
  error; **a caveat travels less far than the number does.**

## 4. 🔬 PREFLIGHT

Run 2026-08-31 21:39:24. `1. git` FAILed on 9 uncommitted paths — **that FAIL is what this handoff
cleared**; sources at `c793e4a`, tools at `3672d89`, docs in the commit carrying this file.
`2. board vs HEAD` ok (both boards current, docs-only commits since). `3. deployed artifact` ok — bundle
newer than newest source. `4. referenced paths` ok, 42/42 resolve. `5. orbital plane` — 7 sites carry a
plane assumption, **unchanged this session; none were touched.**
WARNs left standing: both boards are oversized (142 KB / 154 KB) and want closed rows split into
`BOARD_CLOSED.md`; 11 commits unpushed — **push is a separate order and was not given.**

## 5. ↩️ RETRACTED THIS SESSION

- **THE EGG FIX WAS NOT A FIX.** I reported `dNdc.x *= cam.aspect` as closing his egg; `[READ
  render.metal:1070]` `if (isSecondary) cullThis = true;` is unconditional and `:1533` zeroes pointSize,
  so **every secondary particle is invisible and the cull I corrected cannot change a pixel.** His
  *"looking good to me with the egg"* most likely reflects a run where no hole had formed
  (`[READ renderer.mm:4272]` the instance is gated on `bhStrength > 0.5f`). **The egg is OPEN.** Board §Z6.
  ⭐ I flagged the doubt when shipping and let a verdict stand on it anyway — that is how a false SETTLED
  is born, the same failure as §Y1 the same day.
- **"The latch was not the bug" was incomplete.** `[MEASURED]` **three** cannot-go-down rules held the
  hole up; killing the mass ratchet alone would not have let it die. Board §Z1.
- **My claim that the preflight's stale-artifact check was broken.** It was correct; the handoff prose
  contradicted it. `[MEASURED]` binary 4 s newer than newest source. **Uncommitted ≠ stale.**
