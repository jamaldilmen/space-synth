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
| **A1** | **Accretion is dead.** Zero mergers ever. `Mmax` only ever reads 0.0 or 50.0 (= 49.957 M☉, the heaviest IMF star, rounded); `M_BH_SEED` is exactly 50.0 so `seeds=0` and nothing ever registers. At 64× warp a star moves ~127 contact radii/frame and **tunnels past every merge test**. Merges are additionally gated on `notPlaying`. | ⬜ | `particles.metal:179` `MERGE_RSUN_SIM=0.01f`; `:185` `M_BH_SEED=50.0f`; `renderer.mm:1339` `dt = 0.0165f * timeWarpVal`; `:538` `gkmax = u.speedCap * dt`; `renderer.mm:2683` `notPlaying = totalAmplitude < 0.02f` gates `mergeStarsPipeline` at `:2684` | **M** |
| **A2** | **The refund / sustain rebirth is UNTESTED** — third handoff running. Code is present and deployed; `[REBIRTH]` has printed 0 times because there were never corpses to give back. | 🔨 | `particles.metal:689` `mass = imfMassOfId(id)`; `:694` atomic add into `seedAccum[6]`; `:3445` `seed_apply` drains it; `renderer.mm:3094` the `[REBIRTH]` log line | **S** (the test) 🚫 blocked on A1 |
| **A3①** | **Fake hole — the `/0.5` denominator.** `seedTarget = kRsSimPerMsun · bhSeedMass / kREnc` with `kREnc` **hardcoded to 0.5**, and `bhStrength = max(seedTarget, …)`. The hole reads formed until the seed drains below ~297k M☉. **This is what stops the reversal from ever reaching zero.** | ⬜ | `renderer.mm:2994`; `units.h:86` `kREnc = 0.5` | **M** |
| **A3②** | **Fake hole — the profile is centred on the origin.** Root cause found this pass and it is blunter than the older docs said: the COM refinement is wrapped in **`if (false)`** with the comment `ORIGIN LOCK: refinement disabled`. So `bhPosX/Y/Z` never leave their `0.0f` initialisers, and the radial profile — which bins around `u.bhX/Y/Z` — measures around the origin while the seed wanders off it. | ⬜ | `renderer.mm:2959` `if (false) { // ORIGIN LOCK`; `:196` the initialisers; `particles.metal:3808` bins around `u.bhX/Y/Z` | **S** to unlock, **?** to make honest |
| **A3③** | **Fake hole — the spawn-time latch.** `if (honestTarget >= 1.0f) bhFormedLatch = true`. In the first seconds the 594k M☉ field is packed tightly enough that the innermost shell satisfies `r_s/r ≥ 1`; the latch catches that instant and holds `FORMED` with `seeds=0`. Means **`hole=1.00L` in any log before 2026-08-07 may be this artifact, not a hole.** | ⬜ | `renderer.mm:3064` the latch; `:3029` `honestTarget = min(lastHorizonRatio, 1.0f)` | **S** |

> A3①②③ are three independent bugs that all present as "BH FORMED when it isn't". Fixing one does not touch the others.

---

## B. PHYSICS — measured, not acted on

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| B1 | Centre the horizon test on the mass, not the origin | ⬜ | Same as A3② — **these are the same fix.** Folded. | — |
| B2 | `RADIAL_MAX_R = 5.0` hard cutoff — the seed wanders outside the measuring window entirely | ⬜ | `particles.metal:300`; guard at `:3814` | **S** |
| B3 | **bit4 origin-pin** — a bounded spring dragging any body ≥ 50 M☉ toward `(0,0,0)`, off only during play. Blocks multi-BH *and* makes the fake-pull gate circular. | ⬜ | `particles.metal:1170` | **M** |
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
| **C3** | **Star size floor** — 99.2% of stars pinned to one pixel. Nothing pre-FX can look cinematic until this moves. | ⬜ | `render.metal:1246` `out.pointSize = drawn`; `:1916` the clamp. 🚨 **BUILD THE DIALS FIRST** — 4 attempts, 0 progress, all reverted | **M** |
| C8 | **Chladni sharpness** — *"almoooost."* Standing physics finding: `ridgePull` uses the SCULPT gradient, not the eigenmode ∇Ψ, and there is no node dissipation. This is a physics fix, not a postfx one. | ⬜ | `space_synth_chladni_alpha_is_hz_2026-07-28` | **M** — 🚨 **ask what "sharp" means numerically first** |
| C4 | **Motion vectors** — prerequisite for real motion blur AND TAA. The real blocker is a design decision, not plumbing: additive blending with depth-write off means **nothing decides which particle OWNS a pixel's vector.** | ⬜ | 08-02 doc | **L** |
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
| 2026-08-07 12:02:31 | Created. Every A/B/C row re-verified against source at commit `3a36438`; D and E verified as zero-code. Two corrections to the inherited docs recorded: A3② is an `if (false)` ORIGIN LOCK (blunter than "the profile is centred on origin"), and B1 is not a separate item — it IS A3②. C7's half-space lead is explicitly downgraded to undiagnosed: the only surviving `half-space` mention in the renderer is a *removed* gate. |
