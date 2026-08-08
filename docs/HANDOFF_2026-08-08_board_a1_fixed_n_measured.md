# HANDOFF 2026-08-08 — THE BOARD EXISTS; A1 WAS BACKWARDS AND IS NOW FIXED; N MEASURED

**Written:** 2026-08-08 15:37:02
**Session:** 2026-08-07 11:57 → 2026-08-08 03:52 (work), doc written 15:37
**Baseline:** `b047744` → **`4816056`. 12 commits.** Three weeks of uncommitted work is now committed.
**Uncommitted:** `src/main.cpp`, `src/render/renderer.h`, `src/render/renderer.mm` — **the live-UI
panel. Deliberately held: he has not seen it.** Plus the tracked bundle binary.
**App:** NOT running. Bundle binary + metallib **2026-08-08 02:24:49**, and `find src -newer`
returns empty — **the bundle contains everything, including the uncommitted UI work. Launch, do not
rebuild.**

**Cold start:** read `docs/BOARD.md` first, not this file and not the older handoffs. The board is
the live reference of truth; handoffs are dated snapshots.

---

## 0. WHAT HE VERDICTED, IN HIS WORDS

| Thing | Verdict | When |
|---|---|---|
| The board | ⭐ *"turn this into a trace and trackable live doc thats our reference of truth"* | 08-07 12:02 |
| Priority | ⭐ *"A B C these are the most important for the show"* — D and E post-Berlin | 08-07 12:24 |
| Motion vectors | 🚨 *"we starte dmotion vectors didnt we"* — **he was right, my board was wrong** | 08-07 12:31 |
| The disabled sweep | ⭐ *"thats what i kinda wanted you to do beforrew e did the handoff"* | 08-07 12:41 |
| The A1 result | 🚨 *"re test for certanity this is too shakey for me"* — **he was right to distrust one run** | 08-07 23:5x |
| The 50 M☉ readout | 🚨 *"it is always 50. my eyes.. rmemeber"* — **he was right, three times over** | 08-08 00:2x |
| Static UI | ⭐ *"Static info in a ui is stupid… this is groundwork everything else builds on"* | 08-08 00:36 |
| Limits | ⭐⭐⭐ *"we get infinite voices as well as infinite particles once the science stands correctly. It will be a hard limit of what is pleasurable… not what our tech stack allows"* | 08-08 01:20 |
| The rate law | ⭐ *"our orbit speed also gives away the answer. We're at scale here"* — **and it did** | 08-08 01:5x |

---

## 1. 🚨 THE HEADLINE — A1 WAS BACKWARDS FOR THREE HANDOFFS

**Old claim:** *"Accretion is dead. Zero mergers ever."*
**Truth:** accretion **runs away and eats the entire field.**

The old conclusion came from a **64× run**, where §7 of the 08-07 handoff is correct and merging
genuinely cannot happen (a star moves ~127 contact radii per frame and tunnels past every test).
**Nobody had ever run 1× silent long enough.** Three stacked runs, two independent spawn seeds:

| Run | Seed | Crossed 50 M☉ | Peak `Mmax` | `live` at stop | `Mlive` |
|---|---|---|---|---|---|
| soak | 42 | ~10 min | 331,425 | 2,000,000 → **19** | −301 |
| re-test | **7** | ~4.5 min | 12,329 | → 1,949,108 | −6 |
| re-test | 42 | ~30 s | 557,451 | → 123,007 | −303 |

⭐ **This re-reads his old screenshot.** The "almost empty field, disk gone, handful of bright
points" was recorded in the 08-07 handoff as evidence that *nothing accreted*. It is the exact
opposite — **that frame is the end state of everything accreting.**

**He called the single-run version shaky and was right to.** This project bans single-run claims and
I made one. The stack is what settled it.

---

## 2. ✅ A1′ — CAUSE FOUND AND FIXED, VERIFIED BY LOG

### The cause
`particles.metal`, bit2 seed capture, has two regimes and **only one is capped**:

- **Growth (`mS ≤ 5000` M☉)** — `rt2 = min(rt2, reach²)`, `reach = 1.4·cellSize ≈ 0.066`. **Capped.**
- **Formed (`mS > 5000` M☉)** — `rc = max(3·r_s, 0.02)`. **No `min()`. Nothing.**

`r_s` is linear in M ⟹ cross-section ∝ M² ⟹ `dM/dt ∝ M²` ⟹ **divergence in finite time.**

⭐ **The proof was already in logs we had:** in the seed-42 soak there are **ZERO** samples with
`Mmax` between 480 and 320,000. It sat at 475 for 95 samples then the next distinct value was
322,919 — five orders of magnitude between two consecutive samples. Ordinary fast accretion sweeps
through intermediates; a finite-time blow-up does not.

**This also re-frames the "unpredictable lifespan":** it is a slow stochastic **fuse** (50→5000,
capped, highly variable) followed by a **detonation** of fixed and very short duration.

### The fix — every number derived, nothing chosen
Real discs are limited by **viscosity**, slower than free-fall by `1/(α·(h/r)²)`. And `h/r` is not a
free parameter — **his insight**: `h/r = c_s/v_φ`, and we measure both.

| where | T (measured) | c_s | v_φ (measured) | **h/r** |
|---|---|---|---|---|
| inner | 3.65e11 K | 0.3052 c | 0.4092 c | **0.746** |
| mean | 2.95e10 K | 0.0868 c | 0.1125 c | **0.771** |

Temperatures **12× apart**, velocities **3.6× apart**, answers agree to **3%**. The disc genuinely
has a uniform aspect ratio ≈0.75 — thick, which is correct, because our anchor Sgr A* is a RIAF.

**Independent scale check:** measured `orbV max = 0.4092 c` vs theoretical ISCO `√(1/6) = 0.4082 c`
— **0.23%.** We are exactly at scale. *(He said the orbit speed would give away the answer. It did.)*

⭐ **Because `T_isco ∝ M`, the M cancels in `dM/dt = M/t_visc`.** The ceiling is **mass-independent**,
growth is **linear**, and the M² divergence is gone **by construction, not by a clamp.**

### Verified result
| | |
|---|---|
| measured rate | **2,451** M☉/wall-s |
| derived cap | **2,517** M☉/wall-s |
| ratio | **0.97×** |

Consecutive `Mmax` deltas in the formed regime:
`10349 · 10451 · 10525 · 10385 · 10421 · 10552 · 10549 · 10438 · 10260 · 10503 · 10463 · 10253`
— dead constant, 3% spread. **Linear.**

**Field survives: `live = 1,273,268` (64%) at `Mmax = 215,829`, `Mlive` conserved to −107.**
Pre-fix at the same stage: `live = 19`.

⭐⭐ **AND IT DELIVERED C7'S PRECONDITION:** `r_h = 0.3516` **with 1.27M stars still orbiting.** First
time a horizon and a living field have coexisted. See §4.

### Two deliberate implementation choices — do not "simplify" either
1. **The budget is checked BEFORE the victim dies.** Clamping later, at the credit step in
   `seed_apply`, would **destroy** the excess — the victim is already dead by then and its mass
   would vanish from the books. Refusing the meal leaves the star alive and orbiting.
2. **Reservation is a compare-exchange loop, not load-then-add.** The first version used a plain
   load then add, which is **not atomic as a pair** — every thread observed "budget free" in the
   same instant and all added. That measured **1.90× over** (4,780 vs 2,517). A thread must now
   *claim* the budget. Residual overshoot ≤ one victim (≤50 M☉).

### ⚠️ STILL OPEN on this fix
**Did the limit lengthen the pre-formation fuse?** Post-fix crossings: 16+ min (never crossed) and
8 min. Pre-fix: 30 s, 4.5 min, 10 min. **8 min is inside the pre-fix range**, so at n=2 there is no
strong evidence either way and the process is high-variance. **If it does prove longer, the fix is
one line:** apply the limit only above 5000 M☉ where the divergence lives — the growth phase is
already capped by geometry and never needed it.

**NOT VERIFIED BY EYE. All of the above is from logs.**

---

## 3. ✅ D3 — N MEASURED. 2M IS NOT FEASIBLE

> **N ≈ 250,000 voices** at a safe 10% GPU share · **500,000** at 25% · **2,000,000 costs 63–67% of
> the audio block.**

Full data in `docs/MEASURED_2026-08-08_N_voices.md`; tool in `tools/measure_n/` (standalone, does
not touch the app). §8's fork resolves to its **second branch**: group into shape-preserving cells.
§0.3 still holds as the definition, and **solo still works because solo is N = 1.**

**Three findings that change the architecture:**
1. **Contention barely matters** — re-ran the whole sweep with the 2M sim running at 68 fps on the
   same GPU; every figure moved **<10%**. Budget audio against the **audio block**, not the frame.
   This is the opposite of the design's assumption.
2. **Hard ~0.5–1.0 ms floor independent of N.** 1,000 voices cost the same as 250,000. So anything
   under ~100k leaves the budget unspent for nothing. If headroom is ever needed the lever is
   **batching blocks per dispatch**, not fewer voices.
3. **250k lands on 256 radial × 1024 angular = 262,144** — a natural grid satisfying §0.2's demand
   that cells be radius × angle, never radius alone. *Proposed, not designed.*

⚠️ **Ceiling, not a plan:** GPU execution only (excludes the CPU round trip — real audio needs the
block ready *before* the callback, via the existing SPSC `AudioRingBuffer`); bare oscillator sum, no
pan/envelope/resonator/emission weighting.

🚨 **HIS STANCE ON THIS NUMBER — read `feedback_limits_are_perceptual_not_technical`:**
> *"we get infinite voices as well as infinite particles once the science stands correctly. It will
> be a hard limit of what is pleasurable to look at or listen to, not what our tech stack allows."*

Report ceilings as **the cost of the current formulation**, never as the design constraint. Do not
architect down to a measured number. The time-lapse is his receipt for this.

---

## 4. ✅ C7 — DIAGNOSED, AND IT IS NOT A COLOUR BUG

> **The radial Cartwheel law already exists and is correct. It is switched off whenever there is no
> measured horizon. C7 is downstream of A1′.**

`render.metal:1667` — Shakura–Sunyaev `T ∝ r^(−3/4)`, written 2026-07-23, white-hot inner edge
cooling continuously outward. **Exactly the JWST palette law.** Gated on `cam.horizonR > 0`, and
`r_h` read **`0.0000` for the entire pre-runaway life of every run** — it only went positive once
the blow-up was already consuming the field.

**So the window where the Cartwheel look was possible was exactly the window where the field was
being destroyed.** §2's fix breaks that deadlock — `r_h = 0.3516` now coexists with 1.27M live stars.

**Remaining work is small:** widen `dzone`'s extent (currently `1.6·r_h` … `8–16·r_h`) so the
coloured region covers a galaxy-scale disc rather than a small zone around the hole.

**Two leads killed, permanently:**
- The 08-07 handoff's lens-half-space guess: the only surviving `half-space` mention
  (`render.metal:1001`) describes a gate **removed** in July.
- 🚨 **Doppler-as-hue was removed 2026-06-26 on his own verdict** — it made the field *"a
  screen-space red/blue gradient that ROTATED with the camera"*, his *"linear filter, not colour the
  particles own"*. **NEVER RE-PROPOSE IT.**

**What remains is one half-space term and it is in LUMINANCE, not hue** — relativistic beaming,
`render.metal:1307`, `K_BEAM 0.8`. ⚠️ **Hypothesis, unverified:** the bright half blooms toward
white/blue while the dim half stays saturated orange, which would read as a colour split with no hue
term existing. **One-line test: `DOPPLER_K_BEAM = 0`. Needs his eyes.**

🐛 **New row C7b:** `dopplerColor` is declared, computed, and **never read**. The comment at `:1440`
claims *"Doppler shift is already applied above via dopplerColor"* — **false.**

---

## 5. 🔎 THE DISABLED-CODE SWEEP — what he asked for before the handoff

17 hard-disabled blocks. **10 are ImGui panels removed 2026-06-26** (deliberate). **7 in the
physics/render path**, and they are three different kinds of thing:

| Kind | Where |
|---|---|
| 🔨 **built, recoverable** | `postfx.metal:421` camera motion blur (**C4a**) |
| 🐛 **bug** | `renderer.mm:2959` ORIGIN LOCK (**A3②**) |
| ⏳ **unfinished TODO** | `particles.metal:863` DENSITY PRESSURE (**B10**) |
| ✅ **his own correct verdicts — DO NOT TOUCH** | dust extinction `renderer.mm:3470`; arc trail ribbons `:3533`; two cymatics blocks `particles.metal:2293`, `:2856` |

**4 of the 7 are already right**, each with its reason and a restore path written next to it.

**Also newly recorded:** `render.metal:589` is **unreachable in every configuration** —
`bhDiskAxisY` is `0.0f` at every assignment site. If revived, port the integrated phase in FIRST or
it reintroduces the counter-rotation drift.

⚠️ **The sweep contradicted a board row:** B3 claims the bit4 origin-pin blocks multi-BH, but **bit4
ships OFF** (`app_state.h:48`). In the default launch config that spring does not run, so it cannot
be what pins the hole. **B3's premise is re-opened, not confirmed** — that may need his memory
rather than my archaeology.

---

## 6. ✅ C4 — HE WAS RIGHT, MOTION VECTORS WERE STARTED

I marked C4 ⬜ with "08-02 doc" in the evidence column — **the one row I never read the code for, and
the one row that was wrong.**

- **C4a — BUILT AND RUNNING.** `prevViewProj` fully plumbed; a screen-space velocity computed every
  frame (`postfx.metal:401-414`). Consumer disabled behind `if (false && velLen > 0.002)`.
  **Bug diagnosed:** the block sits *after* the tonemap, grade LUT and neon/VJ grades, so the base
  pixel is display-referred — while `:430` samples the **raw HDR** input through **`acesTonemap`**,
  which is not this pipeline's tonemap. Two mismatches, then a divide by N. Hence the glow dimming
  on camera movement. ⚠️ **Do NOT fix by reintroducing `acesTonemap` — the live tonemap is
  deliberately not ACES.** Cost **S**, pulled into the Berlin cut.
- **C4b — genuinely not started.** The velocity is camera-only (`ndcPos` hardcodes `z = 0.99`), so
  the which-particle-owns-the-pixel decision is untouched. `L`, deferred.

**LESSON, now with four data points: a row without a `file:line` is a rumour, not a status.**

---

## 7. 🖥️ THE UI — HIS "GROUNDWORK" CALL. ⚠️ UNCOMMITTED, UNVERIFIED

He was right three times in a row here and I talked past him twice.

1. He said `biggest body` is always 50. **First answer (rounding):** `%.0f` on the heaviest IMF star
   (49.957 M☉) prints **"50"**, and `M_BH_SEED` is exactly 50.0 — so the readout sat *exactly on the
   seed threshold* from frame one while the real value was *below* it. Fixed to `%.2f` + a
   `(< 50 seed)` / `[SEED]` marker.
2. **His real point, which I missed twice:** *"everything in this frame except universe time is just
   fucking text… it's not only biggest body."* Correct. The whole **GALAXY / REAL SCALE** block was
   `BH_ANCHOR` — Sgr A*'s textbook constants — and **could never move no matter what the sim did.**

**What changed (uncommitted):**

| Line | Before | Now |
|---|---|---|
| Hole mass | `4.297e+06` (Sgr A*) | **live** `maxBodyMsun` |
| r_g | `0.0424 AU` (Sgr A*) | **live**, `G·M/c²` from that mass |
| Horizon | `0.0847 AU` (Sgr A*) | **measured** `r_h` |
| M(<r_h) | did not exist | **live** |
| ISCO period | `32.6 min` (Sgr A*) | **live**, scales with mass |
| Scale | constant, unlabelled | constant, marked `[FIXED CAL]`, dimmed |
| Spin a* | looked live | marked *"not simulated — Schwarzschild"* |
| ISCO v | looked live | marked `[mass-independent]` |

Required plumbing the horizon through `PhysicsStats` for the first time (`horizonR`,
`horizonMassMsun`, `horizonRatio`) — they existed in the renderer since the geometric-criterion work
but were **never published**, which is *why* the panel had nothing live to fall back on.

⭐ **Pre-horizon the panel now shows `sup r_s/r = 0.xxx`** — a continuous approach signal recomputed
every frame that was being calculated all along and never shown. **It should move constantly. That
is the first thing to look at.**

---

## 8. WHAT I GOT WRONG THIS SESSION

- **Claimed a major result off ONE run.** He caught it. This project bans single-run claims and I
  broke my own rule in the exciting direction.
- **Talked past him twice on the UI.** He said "it's always 50" three times; I answered a narrower
  question each time (first the pause state, then the rounding) before hearing the actual point,
  which was that the whole panel is static.
- **C4 was ⬜ because I trusted a doc instead of reading code** — the only row I did that for, and
  the only row that was wrong.
- **Gave him a 55-minute serial test plan for a yes/no question**, then a parallel version that
  cannot work (two instances of a 2M-particle Metal app do not coexist; the second dies silently at
  ~90 s). The version that survived is `tools/a1_watch.sh` — one seed, early exit, declares a run
  INVALID if the instance dies so a starved run cannot look like a negative.
- **Ran the disabled-code sweep after the handoff instead of before**, which is what he wanted.
- **Made him the camera.** I can `screencapture` the window myself — technique verified. Do that.

---

## 9. STATE AT WRITE TIME

- **`4816056`.** 12 commits from `b047744`. Working tree clean **except** `src/main.cpp`,
  `renderer.h`, `renderer.mm` (the live-UI panel — **held deliberately, he has not seen it**) and the
  tracked bundle binary. One stray untracked Apple PDF, left alone.
- **Bundle 2026-08-08 02:24:49, no source newer.** It contains **everything**, including the
  uncommitted UI. **Launch, do not rebuild.** `bash package_macos.sh` if you must; never bare `make`.
- App **not running**. `open -n --stdout "$LOG" --stderr "$LOG" SpaceSynth.app` — never the raw
  binary.
- **Logs survive now:** `logs/` is gitignored but on disk. Tools are tracked in `tools/`.
- 🚨 **Never test accretion above 1×** — the tunnelling arithmetic is real.
- 🚨 **A pause freezes the very thing being observed.** He pauses to read numbers; merges only happen
  while running *and* silent. Say so before handing him any accretion test.

## 10. NEXT, IN ORDER

1. **HIS EYES, in this order** — all three are unverified and two are uncommitted:
   a. **The live-UI panel** (§7). Watch `sup r_s/r` move before a hole exists.
   b. **A1′'s fix on screen** — does a persisting hole over a living field *look* right.
   c. **A2, the refund test** — finally runnable: a hole now persists over ~1.27M live stars.
      Hold a sustained note, watch `Biggest body` **fall**. First non-monotone `gMaxMass` ever.
      ⚠️ momentum is knowingly not conserved on rebirth — flagged, not a bug.
2. **A3③ — the spawn latch** (`renderer.mm:3064`). One line. `hole=1.00L` with `seeds=0` fired again
   in last night's runs; now that **real** holes form, this fake path actively poisons the signal.
   Log-verifiable, no eyes.
3. **A3① — the `/0.5` denominator** (`units.h:86`, `renderer.mm:2994`). **This is what unblocks A2
   actually showing anything** — the hole reads formed until the seed drains below ~297k M☉.
4. **C7's `dzone` widening** (§4) — now unblocked, small.
5. **D6 — the RT audio blocking lock** (`synth.cpp:90`). The only board item that can take down a
   live show.
6. Everything else: **`docs/BOARD.md` §9 is the full board.**

**Berlin New Media Week: 2026-09-02 — 25 days out.**
