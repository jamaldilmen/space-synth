# 🎯 TODO — THE WHOLE OPEN LIST, IN FOUR BUCKETS

**This file is the cold start. Read this, not the boards.**
`BOARD.md` (94 KB) and `BOARD_BLACKHOLE.md` (84 KB) are the DETAIL — open one only for the row you are working.
`BOARD_CLOSED.md` is history and is never read at cold start.

**Written:** 2026-08-20 14:08:59 · **Commit:** `e853e18` · **Bundle:** killtube `2026-08-17 17:45:51` (newer than every `src/` file — not stale)

⭐ **Every `file:line` below was re-read in the source on 2026-08-20.** Line numbers are stamped, not permanent.
Rows that could NOT be checked without a run or a rebuild are listed at the bottom under **NOT VERIFIED TODAY** — do not treat those as facts.

**Four buckets, his call.** Physics rows are filed under the symptom he SEES, not under "physics".

**Three standing gates:** build with `bash package_macos.sh`, never bare `make` · launch `--env SS_FULLSCREEN=1` · never test the hole above **1×** time warp.

---

## 🕳️ BH — the priority (his order 2026-08-14: *"BH LENSE THEN TUBE / SPHERE BEFREIUNG"*)

| # | What is open | Verified today | Deciding move |
|---|---|---|---|
| **BH1** | **The whole 08-17 emission law is UNTESTED.** blackbody `T(r)`, `g`, and the absorption/transfer all landed; his verdict was *"dtill the same in every way lol"* — because the march only ever saw 3.7% of the disc. | `app_state.h:57` bit19 default ON | Get the field to the expanded-disc state (meanR ≈ 44 sim, r_s ≈ 0.23), then read **`[MARCH] bCull`** — never off a screenshot |
| **BH2** | 🚨 **TWO Ω LAWS FOR ONE DISC.** Sprite Doppler uses `1/(r^1.5 + KERR_A)` and a hardcoded global **+Z** tangent; the march uses `√(M/r³)` and `poseAxis`. U6/U7 unified the arcs and playback and never reached the sprite. | `render.metal:1610`, `:1611` vs `:3716`, `:3721` | One law, one axis. This is the unified-physics goal, in one function |
| **BH3** | **Lens size divisor is known-wrong and the code says so** — ortho map used under perspective, ~**2.897×** too small, and `d` is camera→origin not camera→hole. | `renderer.mm:1670-1679` | Fix the divisor. Next single change on the BH track |
| **BH4** | ✅ **NOT OPEN — the board is wrong.** `BOARD_BLACKHOLE.md` §2 and §6 row 1 still list the parity pinch ring and the tuneLens-blind secondary as open. **Both were fixed 2026-08-14** (17:30:54 and 17:53:52) and the code says so at length. ⚠️ Consequence worth keeping: a lens A/B done with the **SLIDER** before that date is still void. | `render.metal:1164` (placed by the lens equation, no `mix`), `:1184` (`imageWeight = cam.tuneLens * lensRamp * …`) | Correct the BH board, do not re-do the work |
| **BH5** | **The lens is OFF whenever he plays.** `bhLensActive = totalAmplitude < 0.02f` — the hole only lenses at silence. Deliberate, but it means the show never sees it. | `renderer.mm:1662` | His call, not a bug |
| **BH6** | **bit15 is double-booked** — "metric shadow" in the render AND "AMR fine force" in physics. Every AMR A/B ever run is invalid. | `app_state.h:53` vs `particles.metal:2153` | Give AMR its own bit |
| **BH7** | **The 128³ box-average objection is unaddressed** — the march samples NEAREST from a 128³ grid, so it can never resolve sub-cell structure. | `app_state.h:57` | Structural (L4). Decide, don't drift |
| **BH8** | **Gravitational redshift** — the `√(1−2M/r)` half of `g`, deliberately not batched with beaming. And **re-derive `b_c`**: `bc_validate.cpp` **does not exist in the tree** (confirmed by `find` today) though the shader banner cites it. | absent | 40-line offline integrator vs `3√3·M = 2.598076` |
| **BH9** | **The accretion rows** (moved into `BOARD_BLACKHOLE.md` §N2): **A2** reversibility now runnable · **A3①** `/0.5` denominator real but not binding · **A3②** hole profile centred on the ORIGIN, not the mass · **A5** the fuse is a 3–16 min stochastic wait (a show risk) · **A6** refund-floor leak · **A8** `feed` returned nonzero for the first time · **MERGER-FACE** a merger has no visual. | §N2 | Each is its own row |
| **BH10** | **His 12:13-run complaints, unactioned:** *"still a fake visual not physical overlay"* (⚠️ the §2 parity proof says the optics ARE real — so it is the BLEND that reads fake) and *"usually a black hole is reddish blueish, not just blue grey"*. | §4d | Screen time, one at a time |

---

## 🎨 GRAPHICS

| # | What is open | Verified today | Deciding move |
|---|---|---|---|
| **G1** | 🚨 **NO PER-PARTICLE DEPTH IN THE STAR PASS.** The depth **pre-pass** writes depth (`depthWriteEnabled = YES`), but the additive particle pass is still write-OFF, so nothing orders or shades by distance. This is the one fact under "it doesn't read as 3D", and it blocks correct camera blur and per-particle motion vectors outright. | `renderer.mm:1112` (NO) vs `:1125` (YES) | Design first — turning writes on is not one line (store action, buffer, blend order) |
| **G2** | **Star size — his biggest remaining look complaint:** *"star size is still stars, not smear of stretched light"*. | `render.metal:1558` `out.pointSize = drawn` | Size + streak law together, not a floor |
| **G3** | **"Diamondy"** — every particle draws a full-strength 4-point diffraction cross because **bit18 has never executed**: `sL ≡ 1.0` for every particle since 2026-07-24. | `render.metal:2636`, notes `:2716`, `:2729` | Either make bit18 live or delete the cross |
| **G4** | **The tube and the sphere** — his standing complaint, restated 2026-08-13: *"two things still piss me off. THE TUBE + THE SPHERE THAT IS OUR SPACE."* B7 is now MEASURED, not hypothesised: `H/R` collapses 0.31–0.84 at silence → 0.0047–0.071 during play. The field genuinely becomes a sheet. | B7 row | The cylindrical clamp is the symptom, not the cause |
| **G5** | **Extinction FAILED and the reason is physics, not render** (his eyes: *"still a rick and morty eye"*). The absorption is live and at full strength, but the clump is ~1 cell across while the march steps 1.5 cells — the first sample is already outside it. | `render.metal:2590-2591` | Density must resolve better than 1.0 sim. A render fix cannot land this |
| **G6** | **Camera motion blur built but wrong** — `prevViewProj` is fully plumbed, but the depth is a hardcoded `z = 0.99` far-plane proxy. Per-particle motion vectors are not started. Both gated behind **G1**. | `postfx.metal:37`, `:452` | After G1 |
| **G7** | **Smear + flicker when the camera moves** — *"uhrzeiger straight lines that create blurr"*, and thousands of hair-thin sprites flickering. ⭐ A line has no width, so a ribbon a tenth of a pixel thick deposits the same energy as a full-pixel one — a conservation gap, not just aliasing. | M2.3, M2.4 | Width-aware energy, then look |
| **G8** | **Poisson SOR ≈ 6 ms — double the whole star pass.** 80 sweeps × 2 colours = 160 compute encoders per frame, with a live knob. | `renderer.mm:2433-2438`, `SS_SOR_SWEEPS` | Needs an **accuracy** verdict, not a perf one |
| **G9** | **Chladni sharpness** — *"almoooost."* `ridgePull` uses the SCULPT gradient, not the eigenmode ∇Ψ, and there is no node dissipation. **The eigenmode itself is genuinely 3D — do not re-litigate that.** | C8 / H2 | Swap the gradient source |
| **G10** | **Chromatic aberration is a flat radial RGB offset** (no spectral/lens model); **scanlines are a Nyquist-rate sine with no filtering** — that is aliasing, not an effect. | `postfx.metal:167-170`, `:491` | Rebuild or remove |
| **G11** | **Rick-and-morty eyes** — start from his name for it. ⛔ My bit20 theory is dead. Do not re-pitch it. | C11 | — |
| **G12** | **Corpse compute** — his order: dead particles must not be computed. Early-out shipped, its A/B failed to attribute, suspected SIMD divergence (scattered corpse ids ⇒ almost no fully-dead 32-lane group). If true the answer is **compaction**, not an early-out. | DEAD-COMPUTE row | One soak, alternating bit28 **within** a run |

---

## 🔊 AUDIO

| # | What is open | Verified today | Deciding move |
|---|---|---|---|
| **A1** | **Sonification is at ZERO lines.** `grep -rl "sonif\|perParticleVoice\|fieldVoice" src/` → **no files**. The design is complete; nothing is built. | verified 2026-08-20 | D7: the per-particle voice at **N = 1**, the solo path |
| **A2** | **The RT audio path takes blocking locks.** **14 lock sites in `src/audio`** today; `audio_engine.mm:149` takes a `lock_guard` inside the input callback; `synth.cpp:99` is the one non-blocking `try_to_lock`. ⚠️ The board's "five sites" figure was **not** re-verified at function granularity — read the call graph before acting. | `audio_engine.mm:149`, `synth.cpp:91-287` | D6 first, then D7 — his order |
| **A3** | **Ceiling already measured:** N ≈ **250,000** voices at a safe 10% GPU share, 500k at 25%, **2M is not feasible**. Disk spans 3.9–4.3 octaves natively. | D3 / D5 | Design to 250k, not to 2M |
| **A4** | **The release still jumps.** *"when i hold longer it still kinda jumps to 0 gravity / star mode before the actual shape settled"* — the A4 ramp fixed the boundary it targeted; this is a different one. Structural: sound = stagecraft in the middle of the note, real physics at both ends. | note-lifecycle audit §2 | Support decaying to zero, so no branch is crossed |
| **A5** | **"The held shape has never been perfect"** — named by him, never actioned. | — | His to define |
| **A6** | **ETERNAL-ECHO** — *"an infinite echo of our self-oscillation"*. His ask, **explicitly low priority**. | — | Park until he raises it |

---

## 🖥️ UI

| # | What is open | Verified today | Deciding move |
|---|---|---|---|
| **U1** | **E5 is built, uncommitted and UNSEEN** — his "groundwork" call (*"static info in a ui is stupid"*). `src/ui/` is **clean** in git, so the live panel is not there; it needs one look before anything else in this bucket. | `git status src/ui` clean | One pass at the screen |
| **U2** | **Accent colour must be DERIVED from the blackbody locus**, not picked. Every number on screen needs a stated derivation. 🚨 **Sample and flip, never lift** — matching the NASA source exactly means we did it wrong. | E1 / E2 | — |
| **U3** | **4-level limit ladder** (yellow→orange→red→purple), numeric typeface as its own role: tabular fixed-width for numbers, proportional for prose. | E3 | — |
| **U4** | **The accuracy meter is shaky when the black hole is there** — his words, uninvestigated. | 4d.3 | — |
| **U5** | ⚠️ **Stale-bundle trap:** indigo hover states in a running app mean you are looking at an ORPHAN bundle, not the code. | E4 | Check the bundle stamp first, always |

---

## ⚠️ NOT VERIFIED TODAY — needs a run or a rebuild, do not quote as fact

- **32 build warnings → zero** (C10). Not re-counted; requires a rebuild. `render.metal:485` is the one real one. 🚨 Never delete `ssDiskTempShape` (still live, `render.metal:257`).
- **fps figures.** The last measured baseline is ~31–36 fps idle @2M, worst frame 50–99 ms, and march-live median 39.9 (n=776). Both are old bundles. **A starved run is not evidence — check the distribution before believing any null result.**
- **B2 / B3 / B5 / B10** (radial cutoff, bit4 origin-pin, the −280 M☉ residual, density pressure "TEMP DISABLED") — carried from 08-07/08-04 docs, not re-read today.
- **⛔ Stale citation found:** the dead-road note pointing at `renderer.mm:3894` for the `if (false)` arc ribbons no longer matches — that line is now inside a draw call. The dead road stands; the line number has decayed.

---

## ⛔ DEAD ROADS — do not retry (the short list)

- **postfx as the cause of anything** — ruled out on fps and on star appearance. Never suggest again.
- **Raising the march emission gain** to make the pass visible — screen-filling brown blob, reverted the same day.
- **Reading the marched region's size off a screenshot** — wrong twice, in both directions. Read `[MARCH]`.
- **The march as the hole's renderer** · **the fullscreen geodesic paint** · **the seed billboard** · **re-centring the lens on `cam.bhX/Y/Z`** (4 no-ops logged).
- **`L̂ = r × v` for the orbit normal** — use `poseAxis`, from position.
- **The 32-per-cell scatter cap is NOT dead code** — it is load-bearing. Writing past it creates mass.

---

**Last Updated:** 2026-08-20 14:08:59
