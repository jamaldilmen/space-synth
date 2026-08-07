# BOARD — THE REFERENCE OF TRUTH

**This is a LIVE document, not a handoff.** Handoffs are dated snapshots of a session.
This file is the single running list of what is open, what is done, and what each thing costs.
Update it in place. Never fork it into a second board.

**Last verified against the code:** 2026-08-07 12:02:31
**Commit at last verification:** `3a36438`
**Berlin New Media Week:** 2026-09-02 — **26 days out**

---

## HOW TO READ THIS

| Column | Meaning |
|---|---|
| **State** | ⬜ open · 🔨 built but UNVERIFIED · ✅ done and verdicted by Jamal · 🚫 blocked |
| **Evidence** | The `file:line` I actually read to confirm the state. If this column says "not re-verified", treat the row as hearsay. |
| **Cost** | Estimated sessions of work. `S` ≈ under one session · `M` ≈ one session · `L` ≈ multiple sessions · `?` ≈ unknown until measured |

A row is only ✅ when Jamal has SEEN it and said so. "It compiles" and "it deployed" are both 🔨.

**Verification standard:** every row below marked with an evidence line was re-read in the source
on 2026-08-07 12:02:31. Rows marked "not re-verified" carry their claim from an older doc and
should be re-measured before anyone acts on them.

---

## 🚨 A. BLOCKERS — nothing downstream is trustworthy until these settle

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| ~~A1~~ | ~~**Accretion is dead.**~~ ❌ **REFUTED 2026-08-08 00:05:09 — MEASURED, 3 RUNS.** Accretion is not dead. **It runs away.** See **A1′** below. The old claim came from a **64× run**, where §7's tunnelling arithmetic is correct and merging genuinely cannot happen. Nobody had run **1× silent** long enough. | ✅ closed | 3 stacked runs, `logs/A1_*` | — |
| **A1′** | 🚨 **RUNAWAY ACCRETION — THE SIM EATS ITSELF.** At 1×, silent, no input, a body crosses 50 M☉ and then consumes the entire field. **3/3 runs, 2 independent realizations.** Mass is conserved throughout, so this is real mass eaten, not minted. **The show-relevant part: the field's lifespan is unpredictable — between 30 s and 10 min.** Same spawn seed gave 10 min once and 30 s the next, so the *evolution* is nondeterministic even though the spawn is not (very likely GPU atomic ordering in the hash/merge path — **stated as the likely cause, not proven**). ⭐ **This re-reads his old screenshot:** the "almost empty field, disk gone, handful of bright points" was recorded in §7 as *nothing accreted*. It is the opposite — **everything accreted.** That frame is the end state of runaway. | ⬜ **NEW** | see the run table below | **M** |
| **A2** | **The refund / sustain rebirth is UNTESTED** — third handoff running. Code is present and deployed; `[REBIRTH]` has printed 0 times because there were never corpses to give back. | 🔨 | `particles.metal:689` `mass = imfMassOfId(id)`; `:694` atomic add into `seedAccum[6]`; `:3445` `seed_apply` drains it; `renderer.mm:3094` the `[REBIRTH]` log line | **S** (the test) 🚫 blocked on A1 |
| **A3①** | **Fake hole — the `/0.5` denominator.** `seedTarget = kRsSimPerMsun · bhSeedMass / kREnc` with `kREnc` **hardcoded to 0.5**, and `bhStrength = max(seedTarget, …)`. The hole reads formed until the seed drains below ~297k M☉. **This is what stops the reversal from ever reaching zero.** | ⬜ | `renderer.mm:2994`; `units.h:86` `kREnc = 0.5` | **M** |
| **A3②** | **Fake hole — the profile is centred on the origin.** Root cause found this pass and it is blunter than the older docs said: the COM refinement is wrapped in **`if (false)`** with the comment `ORIGIN LOCK: refinement disabled`. So `bhPosX/Y/Z` never leave their `0.0f` initialisers, and the radial profile — which bins around `u.bhX/Y/Z` — measures around the origin while the seed wanders off it. | ⬜ | `renderer.mm:2959` `if (false) { // ORIGIN LOCK`; `:196` the initialisers; `particles.metal:3808` bins around `u.bhX/Y/Z` | **S** to unlock, **?** to make honest |
| **A3③** | **Fake hole — the spawn-time latch.** `if (honestTarget >= 1.0f) bhFormedLatch = true`. In the first seconds the 594k M☉ field is packed tightly enough that the innermost shell satisfies `r_s/r ≥ 1`; the latch catches that instant and holds `FORMED` with `seeds=0`. Means **`hole=1.00L` in any log before 2026-08-07 may be this artifact, not a hole.** | ⬜ | `renderer.mm:3064` the latch; `:3029` `honestTarget = min(lastHorizonRatio, 1.0f)` | **S** |

> A3①②③ are three independent bugs that all present as "BH FORMED when it isn't". Fixing one does not touch the others.

### 📊 A1′ — THE MEASUREMENT, 3 STACKED RUNS (2026-08-08 00:05:09)

He called the first result shaky and was right — one run, and this project **bans single-run claims**.
Stacked. All runs: **1× time warp, silent, zero input**, deployed binary (bundle `2026-08-06 15:28:21`,
no source newer, nothing rebuilt).

| Run | Seed | Crossed 50 M☉ | Peak `Mmax` | `seeds` | `live` at stop | `Mlive` | `feed`/`scan` |
|---|---|---|---|---|---|---|---|
| Soak | 42 | ~10 min | **331,425.6** | 2 | 2,000,000 → **19** | 594,276 → 593,975 (−301) | 0 / 0 |
| Re-test | **7** | ~4.5 min | **12,329.6** | 2 | → 1,949,108 (early stop) | 594,276 → 594,270 (−6) | 0 / 0 |
| Re-test | 42 | **~30 s** | **557,451.0** | 1 | → 123,007 (94% eaten in 2 min) | 594,276 → 593,973 (−303) | 0 / 0 |

**What is established:**

1. **Runaway is the physics, not one realization.** Seed 7 is an independent spawn and does the same thing.
2. **Timing is wildly nondeterministic** — the same seed 42 took 10 min once and 30 s the next. The
   spawn RNG is fixed (`particles.cpp:23`, `spawnSeed = 42`), so the divergence is downstream, in the
   evolution.
3. **Mass is conserved under runaway** — −301, −6, −303 M☉, all consistent with the known −280
   residual (B5). The 08-04 conservation fix holds. The hole is eating real mass, not minting it.
4. **`feed=0/0.0 scan=0` in every run ever logged.** All growth comes through `merge_stars`; the
   seed-feed path has **never scanned once**. That half of §7 survives and is now better evidenced.
5. **A2's precondition is finally met** — seeds exist and there are ~1.9M corpses to refund. The test
   that has been blocked for three handoffs is runnable. **It needs him to hold a note.**

**Method notes, for whoever repeats this:**
- ⚠️ **Two instances cannot coexist.** A parallel attempt had its second instance die silently at
  ~90 s with no crash message. Run serially. `tools/a1_watch.sh <seed> NEW` does one run with early
  exit and aborts as INVALID if the instance dies, so a starved run cannot masquerade as a negative.
- ⚠️ **`dt` is per-frame, not wall-clock** (`renderer.mm:1339`), so anything that costs FPS costs sim
  progress. The logs carry `FPS:` — check it before trusting a null result.
- 🚨 **Never test this above 1×.** §7's tunnelling arithmetic is correct: at 64× a star moves ~127
  contact radii per frame and the merge test can never fire.

**Free confirmation, from instrumentation that already exists:** `[KPROBE-SCALE] size px:
0.92:99.3%` — **C3's "99.2% of stars pinned to one pixel" is real and now measured at 99.3%.**

---

## B. PHYSICS — measured, not acted on

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| B1 | Centre the horizon test on the mass, not the origin | ⬜ | Same as A3② — **these are the same fix.** Folded. | — |
| B2 | `RADIAL_MAX_R = 5.0` hard cutoff — the seed wanders outside the measuring window entirely | ⬜ | `particles.metal:300`; guard at `:3814` | **S** |
| B3 | **bit4 origin-pin — PREMISE RE-OPENED 2026-08-07 12:41:25.** The spring exists (a bounded pull on any body ≥ 50 M☉ toward `(0,0,0)`, gated off during play) — but **it ships OFF** and only the UI checkbox or the `SS_INERT_KEEP` ladder can enable it. So in the default launch config it is **not** what blocks multi-BH; the unconditional ORIGIN LOCK (A3②) is. Inherited from 08-04 §4 and not re-derivable from the code as written. **Re-establish what this row is for, or fold it into A3② and close it.** | ⬜ premise unverified | `particles.metal:1170` the spring; `app_state.h:48` `= false`; `main.cpp:2135` the pack, `:1260` the checkbox, `:270` the ladder | **S** to settle, then **?** |
| B10 | **DENSITY PRESSURE — an unfinished TODO, not a decision.** Disabled with *"TEMP DISABLED for Step 1 verification… **Re-enable in a later step** after we have orbital dynamics holding particles in place."* That later step never came. It was overpowering gravity (pressure scale 12 vs gravity scale 1) and blowing the Gaussian spawn outward. ⚠️ **Do NOT simply switch it on: it OPPOSES collapse, and A1 needs collapse.** Settle A1 first, then decide whether this is revived at a sane scale or deleted. | ⬜ **NEW** | `particles.metal:863` `if (false /* su.gridSize > 0 */)` | **M** |
| B4 | Pull-gate step 2 | 🚫 | blocked on B3 | **M** |
| B5 | The −280 M☉ residual drift (wall/park exclusion) | ⬜ | not re-verified — from 08-04 §1 | **S** |
| B6 | **Corpse compaction.** 64% of the buffer was corpses; every compute dispatch is 2,000,000 threads regardless. In **direct tension** with `imfMassOfId(id)` requiring that particles never change slots — the refund depends on that property. Needs its own session. | ⬜ | `particles.metal:131` `imfMassOfId`; measurement from 08-07 §3 | **L** |
| B7 | **Kill the tube** — *"figure out what the actual truest form of soundwaves in 3d space is."* The cylindrical clamp is the symptom; the Bessel `J_m` basis is the real work. His own prior design (3D scalar ψ, damped wave PDE) is the starting point. | ⬜ | 08-04 §6.8 · `space_synth_neo_architecture` | **L** |
| B8 | **"Start sequence / launch grid"** — he named these as needing fixing and never said what he meant. | ⬜ | 🚨 **ASK BEFORE TOUCHING** | **?** |
| B9 | Merger flash is invisible — temp baseline 5.29e11 makes a `+2.0` flash a 1e-11 relative change | ⬜ | not re-verified — from 08-03 | **S** |

---

## C. VISUAL ENGINE — his stated priority (*"we follow paragraph 9"*, 2026-08-02)

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| C1 | Bloom → mip pyramid | ✅ | `postfx.metal:547` — *"this bloom is looking a lot better"* | done |
| C2 | Grade LUT stage, 33³ RGBA16F after the live tonemap | ✅ built + approved, now committed | `postfx.metal:361` samples it; `renderer.mm:811` uploads it; `:3884` binds it; `:3919` same grade on the Syphon feed. ⚠️ **ADDED stage — the live tonemap is NOT ACES, never replace it** | done |
| **C7** | **The Cartwheel delta.** Our colour organisation is a **half-space** split (orange one side, blue-white the other, down the middle); JWST's is **radial** (orange dust ring outside, blue population inside). Their ring closes; ours is a crescent. Biggest single visual delta. | ⬜ | 🚨 **UNDIAGNOSED.** Grepped this pass: only one `half-space` mention survives in the renderer and it is a *removed* gate (`render.metal:1001`). The old "two circles" half-space bug is a **lead, not a finding.** Measure before changing anything. | **?** — measure first (**S**), fix unknown |
| **C3** | **Star size floor** — 99.2% of stars pinned to one pixel. Nothing pre-FX can look cinematic until this moves. | ⬜ | `render.metal:1246` `out.pointSize = drawn`; `:1916` the clamp. 🚨 **BUILD THE DIALS FIRST** — 4 attempts, 0 progress, all reverted | **L** (was `M`; corrected on the 4-attempt record) |
| C8 | **Chladni sharpness** — *"almoooost."* Standing physics finding: `ridgePull` uses the SCULPT gradient, not the eigenmode ∇Ψ, and there is no node dissipation. This is a physics fix, not a postfx one. | ⬜ | `space_synth_chladni_alpha_is_hz_2026-07-28` | **M** — 🚨 **ask what "sharp" means numerically first** |
| **C4a** | **Camera motion blur — BUILT, DISABLED, bug diagnosed.** `prevViewProj` is fully plumbed and a screen-space velocity is computed **every frame**: unproject through `inverseViewProj`, reproject through `prevViewProj`, difference the UVs. The consumer is switched off behind **`if (false && velLen > 0.002)`** — the **second `if (false)`** on this board. **Why:** it dimmed the glow when the camera moved (his *"FX bug out / glow turns off when I move the camera"*). Reading the stage order, the cause is sharper than the source comment says: the block sits **after** the tonemap (`:285`), the grade LUT (`:338`) and the neon/VJ grades, so `color` is fully display-referred — but `:430` samples the **raw HDR** input and runs it through **`acesTonemap`**, which is *not* this pipeline's tonemap. **Two mismatches — graded-vs-ungraded, and ACES-vs-the-real-tonemap — then a divide by N.** Fix = make the samples match the base, do not reintroduce ACES. | 🔨 | `renderer.h:162`; `renderer.mm:343`, `:3866`, `:3871`; `postfx.metal:401-414` (live), `:420` (the `if (false)`), `:432` (the wrong tonemap) | **S** |
| C4b | **Per-particle motion vectors** — genuinely not started. C4a's velocity is **camera-only**: `ndcPos` hardcodes `z = 0.99`, so everything is assumed at the far plane and nothing about particle motion is captured. This is where the real blocker lives — additive blending with depth-write off means **nothing decides which particle OWNS a pixel's vector.** Prerequisite for TAA. | ⬜ | `postfx.metal:401` the hardcoded `0.99` | **L** |
| C5 | Chromatic aberration → proper spectral/lens model (currently a flat radial RGB offset) | ⬜ | `postfx.metal:170` | **M** |
| C6 | Scanlines — rebuild or remove. Currently a Nyquist-rate sine with no filtering: that is aliasing, not an effect. | ⬜ | `postfx.metal:446` | **S** |
| C9 | `bit18` flux-conserving arc **has never executed** — `sL ≡ 1.0` for every particle since it was written 2026-07-24 | ⬜ | `render.metal:1158` says so in the source comment; `:2233` confirms the downstream branch is a no-op | **S** to delete, **M** to revive |
| C10 | 32 build warnings → zero. `render.metal:485` is the one real one. | ⬜ | not re-counted this session (would require a rebuild). 🚨 **never delete `ssDiskTempShape`** | **S** |
| C11 | Rick-and-morty eyes — start from his name for it | ⬜ | my bit20 theory is dead, **do not re-pitch it** | **?** |

---

## D. AUDIO — design complete, **zero code written**

Confirmed this pass: `grep -rln "sonif\|perParticleVoice\|fieldVoice" src/` returns **nothing**. The track is genuinely at zero.

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| **D6** | 🚨 **The RT audio path takes a BLOCKING lock.** `Synth::processBlock` — the render callback — opens with an unconditional `std::lock_guard<std::mutex> lock(queueMutex_)`. The voice mutex right below it is correctly `try_to_lock` with a comment saying *"never blocks the RT thread"*; `queueMutex_` has no such protection. **This is the only item on the whole board that can take down a live show.** | ⬜ | `synth.cpp:90` (blocking) vs `synth.cpp:99` (try_lock, correct) | **S** |
| **D3** | **NEXT CONCRETE STEP: MEASURE N** — how many simultaneous voices are actually affordable. Every other audio item is blocked on that number. | ⬜ | design doc §NEXT | **S** |
| D1 | **Field sonification: every particle is a voice.** pan = θ, amplitude = EMISSION, frequency from GEOMETRY so it is **pausable by construction**; solo = the same law with N=1. | ⬜ **DESIGN ONLY** | `DESIGN_2026-07-28_field_sonification.md` | **L** |
| D2 | ⚠️ v1 binning scheme was **WITHDRAWN.** Read §0.2 of the design doc before anyone re-proposes it. | — | — | — |
| D4 | The law: physics constants must DERIVE from `spacetime.h`. Listener constants (20 Hz pitch floor, 120 Hz localisation limit) are legitimate and separate. **An untraceable number is a bug.** | — | — | — |
| D5 | Measured and ready to use: the disk spans **3.9–4.3 octaves natively**; the 20 Hz rhythm→pitch line falls at r ≈ 14.85, inside `R_DISK = 18`; **2:1 rings = exactly an octave, 3:2 = exactly a perfect fifth.** | — | — | — |

---

## E. UI OVERHAUL — research done, **zero code changed**

Confirmed this pass: `git status src/ui/` is clean and has been across the whole uncommitted period.

| # | Item | State | Cost |
|---|---|---|---|
| **E5** | **Mark the biggest body on screen** — *"i cant even see what the biggest body is."* Small, and it makes A1 and A2 **testable by eye** instead of by log. Best effort-to-value ratio on the board. | ⬜ | **S** |
| E1 | NASA / Open MCT-informed UI. 🚨 **SAMPLE AND FLIP, NEVER LIFT** — every number on screen must have a stated derivation. Matching the source exactly means we did it wrong. | ⬜ | **L** |
| E2 | Accent colour **derived from the blackbody locus**, not picked | ⬜ | **S** |
| E3 | 4-level limit ladder (yellow→orange→red→purple); numeric typeface as its own role; numeric/tabular → fixed-width, narrative → proportional; stale data must be indicated | ⬜ | **M** |
| E4 | ⚠️ **Stale-bundle trap:** indigo hover states in a running app mean you are looking at an orphan bundle, not the code | — | — |

---

## WORKLOAD PER SECTION

**These are estimates, not measurements.** Nothing below was derived from a log or a timing. The one
number that IS grounded in the record is C3 — see the note under section C. Treat the totals as a
shape, not a schedule.

**Unit:** one **session** = a block where I build and he verdicts. Roughly:
`S` = half a session, one change and one verdict · `M` = one session · `L` = 2–4 sessions, needs its
own dedicated block · `?` = cannot be estimated until something is measured or he answers a question.

| Section | Open rows | S | M | L | ? | **Est. sessions** |
|---|---|---|---|---|---|---|
| **A — Blockers** | 5 | 3 | 2 | 0 | 1 | **≈ 3.5** + 1 unknown |
| **B — Physics** | 8 | 3 | 2 | 2 | 1 | **≈ 9.5** + 1 unknown |
| **C — Visual** | 9 | 3 | 2 | 2 | 2 | **≈ 10** + 2 unknowns |
| **D — Audio** | 3 | 2 | 0 | 1 | 0 | **≈ 4** |
| **E — UI** | 4 | 2 | 1 | 1 | 0 | **≈ 5** |
| **TOTAL** | **29** | 13 | 7 | 6 | 4 | **≈ 32 sessions + 4 unknowns** |

### What each section's total is actually made of

- **A ≈ 3.5.** Cheap in isolation and it is the whole BH track's gate. A1 (M) is the only real work;
  A2 is a *test*, not a build; A3③ is a one-line latch condition. **A3② has a split cost** — the
  `if (false)` takes minutes to unlock, but nobody knows what the honest centring rule should be, and
  that is the unknown in this row. Best return per session on the board.
- **B ≈ 9.5, and two thirds of it is two rows.** B6 (corpse compaction) and B7 (kill the tube) are
  both `L` and both structural. B6 also *conflicts* with the refund — `imfMassOfId(id)` needs slots
  never to move. Everything else in B is small. **B8 is an unknown because he has not said what he
  means**, not because it is hard.
- **C ≈ 10, and it is the least trustworthy total here.** Two rows are `?` (C7's fix, C11) and one is
  evidence-corrected upward. This section is his stated priority and it is also the section where the
  estimates are weakest, because the two headline items are undiagnosed.
- **D ≈ 4, but it is 1 small + 1 small + 1 large.** D6 and D3 are both `S` and both unblock things.
  D1 is the whole feature and is `L`. The track is at literally zero code, so there is no partial
  credit banked anywhere.
- **E ≈ 5.** E5 alone is `S` and pays back into A1/A2 by making them visible. E1 is the `L`.

### ⚠️ The estimate I corrected

**C3 (star size floor) was `M` — it should be `L`.** The record says 4 attempts, 0 progress, all
reverted. An item that has already consumed four attempts is not a one-session item, and calling it
one again would be repeating the mistake that produced those four. The `L` in section C's row is
C3 and C4. The standing instruction on it — **build the dials first** — is the reason: the work is
not "change the size", it is "make size dialable so we can find the right one".

### ⚠️ What these totals do NOT say

**≈32 sessions does not fit in 26 days at any believable pace.** That is the useful finding here.
This board is not a list to finish before Berlin — it is a list to **triage**. Anything not on the
Berlin path below is post-Berlin work by default, and saying so now is cheaper than discovering it
on 2026-09-01.

---

## 🔎 DISABLED-CODE SWEEP — 2026-08-07 12:41:25

He asked for this **before** the handoff and I did it after, having been caught by C4. Full sweep for
`if (false)`, `&& false`, `#if 0`, and dead-by-comment markers across `src/`.

**17 hard-disabled blocks. 10 are ImGui panels removed 2026-06-26** — deliberate, documented, not
hidden work. **7 are in the physics/render path**, and they are not all the same kind of thing:

| # | Where | What | Kind |
|---|---|---|---|
| 1 | `postfx.metal:421` | Camera motion blur (**C4a**) | 🔨 **built, recoverable — bug** |
| 2 | `renderer.mm:2959` | ORIGIN LOCK — COM refinement (**A3②**) | 🐛 **bug** |
| 3 | `particles.metal:863` | **DENSITY PRESSURE** (**B10**, new) | ⏳ **unfinished TODO** |
| 4 | `renderer.mm:3470` | Dust extinction pass | ✅ his verdict, parked |
| 5 | `renderer.mm:3533` | Analytic arc trail ribbons | ✅ his verdict, correctly dead |
| 6 | `particles.metal:2293` | Elastic shell restoring force | ✅ deliberate, documented |
| 7 | `particles.metal:2856` | Direct envelope→radius coupling | ✅ deliberate, documented |

**Verdict: 4 of the 7 are correct.** They are his own calls, each with the reason and a restore path
written next to it — dust extinction (*"a low-res shadow thingy / yellow underbelly"*, 2026-07-23),
the arc ribbons (*"fake trails centered to a tube shape"*, 2026-06-25), and the two cymatics blocks
that were preventing particles from flowing through the sphere. **Do not "fix" any of these four.**
The dust-extinction *concept* is explicitly retained for the BH overhaul once depth ordering exists.

**Three were worth finding: one bug, one recoverable feature, one abandoned TODO.**

### Also confirmed dead, and NOT on the board before

- **`render.metal:589` is unreachable in every configuration.** It needs `cam.bhDiskAxisY > 0.5f`,
  and `renderer.mm` assigns `bhDiskAxisY = 0.0f` at **every** assignment site (`:1551`, `:1589`,
  `:1592`) plus the header default (`renderer.h:200`). Both the posed and emergent branches select
  the z-axis block at `:539` instead. It still carries the **old absolute-angle form** that was
  removed from its live twin. ⚠️ **If it is ever revived, port the integrated phase in FIRST** — as
  written it reintroduces the counter-rotation drift.

### ⚠️ A board row this sweep contradicts

**B3 says the bit4 origin-pin blocks multi-BH. bit4 ships OFF.** `app_state.h:48`
`uiTogOriginPin = false`, packed at `main.cpp:2135`, and the only things that can turn it on are the
UI checkbox (`main.cpp:1260`) and the `SS_INERT_KEEP` diagnostic ladder (`main.cpp:270`). **In the
default launch configuration that spring does not run**, so it cannot be what pins the hole to the
origin in normal use — the ORIGIN LOCK at `renderer.mm:2959` is, and that one is unconditional.
**B3's premise is re-opened, not confirmed.** See the row.

### The pattern

Two of the three findings were features that got **built → hit a bug → switched off → recorded as
"not started"**. That is how C4 ended up ⬜ on this board. The lesson from the change log holds and
now has a second and third data point: **a row without a `file:line` is a rumour.**

---

## 🎯 TRIAGE — HIS CALL, 2026-08-07 12:24:09

> *"A B C these are the most important for the show"*

**Sections D and E are post-Berlin by his decision.** Do not spend a session there without asking.

⚠️ **One exception flagged to him at the time of the call: D6.** It sits in section D but it is a
*show* item — `Synth::processBlock` takes a blocking `lock_guard` on the RT audio thread
(`synth.cpp:90`). If it stalls mid-set the audio drops on stage. It is an `S`. It is **parked, not
dismissed**, and it stays parked until he says otherwise.

### A/B/C alone is still too big

A + B + C = **≈23 sessions + 4 unknowns** against 26 days. Narrowing to three sections does not
close the gap on its own, because **6 of B's 9.5 sessions and 3 of C's 10 sit in rows that never
appear on screen.** The cut has to go one level deeper.

### The deeper cut — what actually serves a stage

**A — all of it. ≈3.5 sessions.** No cut. It is the gate on the entire BH track and it is the
cheapest section on the board.

| Keep in B | Why | Cost |
|---|---|---|
| B2 `RADIAL_MAX_R` cutoff | the seed leaves the measuring window — serves A3② | S |
| B3 bit4 origin-pin | unblocks B4 and the pull gate | M |
| B4 pull-gate step 2 | the interaction he specified | M |
| B5 −280 M☉ drift | small, and mass books should stay exact after the refund | S |
| B9 merger flash invisible | a merger you cannot SEE is not a show event | S |

**Deferred out of B: B6, B7, B8 — ≈6 sessions.** B6 (corpse compaction) is a perf/architecture job
that *fights* the refund. B7 (kill the tube) is a foundational rewrite. B8 is undefined. **None of
the three changes what the audience sees on 2026-09-02.**

| Keep in C | Why | Cost |
|---|---|---|
| C7 Cartwheel delta | the single biggest visual delta, and his own 02:55 call | ? — measure first (S) |
| C3 star size floor | 99.2% of stars are one pixel; nothing pre-FX looks cinematic until this moves | L |
| C8 Chladni sharpness | *"almoooost"* — ask what sharp means first | M |
| C5 chromatic aberration | currently a flat radial offset, not a lens | M |
| C6 scanlines | rebuild or remove — right now it is aliasing, not an effect | S |
| C9 bit18 dead arc | `sL ≡ 1`; **delete it** rather than revive it before a show | S |
| C10 build warnings | `render.metal:485` is real | S |

**Deferred out of C: C4b, C11 — ≈3 sessions.** C4b (per-particle motion vectors) is `L` and its real
blocker is an unmade design decision about which particle owns a pixel's vector. C11 has no defined
starting point.

**↩️ PULLED BACK IN — C4a, `S`, 2026-08-07 12:31:07.** He asked *"we started motion vectors didn't
we"* and he was right; my ⬜ came from the 08-02 doc, not from the code. The camera half is **built
and running** — only its consumer is switched off, behind a documented bug with a specific cause
(`postfx.metal:432` tonemaps blur samples with **ACES** while the base pixel is already through this
pipeline's own tonemap *and* the grade LUT). Re-enabling it is a matched-sampling fix, not a build.
⚠️ **Do NOT fix it by reintroducing `acesTonemap` anywhere** — the live tonemap is deliberately not
ACES. Berlin cut is now **≈14 sessions.**

### What the cut leaves

| | Sessions |
|---|---|
| A (all) | ≈3.5 |
| B (kept) | ≈3.5 |
| C (kept) | ≈6.5 + C7's unknown |
| **Berlin total** | **≈13.5 + 1 unknown** |

**≈13.5 sessions in 26 days is plausible.** ≈23 was not. The deferred ≈9 sessions are all still on
this board — they are post-Berlin, not cancelled.

---

## THE TWO PATHS

**Shortest path to a working black hole:** A1 → A2 → A3① . Nothing else in the BH track is testable
before A1, because no body has ever crossed 50 M☉.

**Shortest path to Berlin (26 days):** C7 and C3 carry the most on-screen return. E5 is cheap and
makes the BH work verifiable by eye. **D6 is the only item that can take down a live show** and it
is an `S`.

---

## STANDING RULES THAT OUTLIVE ANY ITEM

- **Build:** `bash package_macos.sh`. **Never bare `make`** — it writes `build/` and does not touch
  the bundle the app actually loads. "My change did nothing" → **suspect a stale binary FIRST.**
- **Launch:** `open -n SpaceSynth.app`, never the raw binary (no LaunchServices registration ⇒ no
  window; it looks alive to `pgrep` and he sees nothing).
- **Never hand him a test without first confirming its precondition holds.** This is what burned a
  night at 64× on 2026-08-06.
- **Time warp does not buy the sim more time to accrete.** It buys bigger jumps between the only
  moments accretion is ever tested.
- **Logs do not survive the scratchpad.** Capture to a real path.
- Commit only on his explicit order.

---

## CHANGE LOG FOR THIS FILE

| When | What |
|---|---|
| 2026-08-08 00:05:09 | **A1 REFUTED BY MEASUREMENT, 3 STACKED RUNS.** Accretion is not dead — it **runs away** and eats the whole field at 1× silent, in 2 independent realizations, with mass conserved. The old "zero mergers ever" came from a 64× run where tunnelling really does prevent merging; nobody had run 1× silent long enough. A1 closed, **A1′ opened**: the sim self-destructs on an unpredictable clock (30 s to 10 min, same seed). His old "empty field" screenshot was misread by §7 as *nothing accreted* — it is the **end state of everything accreting**. **A2 is finally unblocked.** He was right to call the single-run version shaky. |
| 2026-08-07 12:41:25 | **DISABLED-CODE SWEEP** — the thing he wanted done *before* the handoff. 17 hard-disabled blocks; 10 are removed ImGui panels, 7 are in the physics/render path. **4 of the 7 are his own correct verdicts with restore paths written next to them — do not touch.** 3 were worth finding: C4a (recoverable), A3② (bug), and **new row B10, DENSITY PRESSURE — an explicit "re-enable in a later step" TODO that was never done.** Also newly recorded: `render.metal:589` is unreachable in every configuration (`bhDiskAxisY` is `0.0f` at every assignment site). **And the sweep contradicted a board row: B3's bit4 origin-pin ships OFF, so it cannot be what pins the hole in normal use — premise re-opened.** |
| 2026-08-07 12:31:07 | **He was right and the board was wrong: motion vectors WERE started.** I had marked C4 ⬜ with "08-02 doc" in the evidence column — hearsay by this file's own standard, and the one row I did not read the code for. Split into **C4a** (camera half: BUILT and running, consumer disabled behind the board's *second* `if (false)`, bug diagnosed to mismatched tonemaps at `postfx.metal:432`) — `S`, **pulled back into the Berlin cut** — and **C4b** (per-particle, genuinely not started, still `L`, still deferred). **Lesson: a row without a `file:line` is not a status, it is a rumour.** |
| 2026-08-07 12:24:09 | **His triage: A, B, C are the show. D and E are post-Berlin.** Added the TRIAGE section. Because A+B+C is still ≈23 sessions vs 26 days, cut one level deeper: deferred B6/B7/B8 and C4/C11 (≈9 sessions, none of them visible on stage), leaving **≈13.5 sessions**. D6 flagged to him as a show-risk exception living in a deferred section — **parked, not dismissed.** |
| 2026-08-07 12:18:44 | Added **WORKLOAD PER SECTION** at his request. Totals ≈32 sessions + 4 unknowns against 26 days — recorded explicitly that this board is a triage list, not a finish list. One estimate corrected on evidence: **C3 `M` → `L`**, because an item with 4 reverted attempts on the record is not a one-session item. |
| 2026-08-07 12:02:31 | Created. Every A/B/C row re-verified against source at commit `3a36438`; D and E verified as zero-code. Two corrections to the inherited docs recorded: A3② is an `if (false)` ORIGIN LOCK (blunter than "the profile is centred on origin"), and B1 is not a separate item — it IS A3②. C7's half-space lead is explicitly downgraded to undiagnosed: the only surviving `half-space` mention in the renderer is a *removed* gate. |
