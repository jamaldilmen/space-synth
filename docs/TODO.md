# 🎯 TODO — THE WHOLE OPEN LIST, IN FOUR BUCKETS

**This file is the cold start. Read this, not the boards.**
`BOARD.md` (94 KB) and `BOARD_BLACKHOLE.md` (84 KB) are the DETAIL — open one only for the row you are working.
`BOARD_CLOSED.md` is history and is never read at cold start.

**Written:** 2026-08-20 14:08:59 · **Commit:** `6b923fe` (2026-08-21 22:38:30 — S1/S2 + the whole 08-20 body landed here; previously verified at `5bd9133`)  *(rows verified against `e853e18`; the two commits since are the march work and this board split — neither changes what a row says)* · **Bundle:** killtube `2026-08-17 17:45:51` (newer than every `src/` file — not stale)

⭐ **Every `file:line` below was re-read in the source on 2026-08-20.** Line numbers are stamped, not permanent.
Rows that could NOT be checked without a run or a rebuild are listed at the bottom under **NOT VERIFIED TODAY** — do not treat those as facts.

**Four buckets, his call.** Physics rows are filed under the symptom he SEES, not under "physics".

**Three standing gates:** build with `bash package_macos.sh`, never bare `make` · launch `--env SS_FULLSCREEN=1` · never test the hole above **1×** time warp.

🎪 **THE SHOW MOVED — 2026-09-05, COLOGNE, 10 × 4 m (2.5:1) via 6 beamers.** Not Berlin. See **`docs/SHOW_2026-09-05_COLOGNE.md`** for the show-driven rows (S1–S6) and for what an agent may and may not do. ⛔ **Set length, arrangement and the live/pre-rendered mix are HIS**, not ours.

## 🎪 SHOW ROWS CLOSED 2026-08-21

| # | What landed | Verified | Note |
|---|---|---|---|
| ~~**S1**~~ | ✅ **THE RENDER BUFFER IS PINNED TO EXACT PIXELS.** `SS_WIDTH`/`SS_HEIGHT` set the drawable itself, not the window. The window became a scaled preview. Projection aspect now reads the DRAWABLE (`main.cpp:791`, `:797`); `width()/height()` stay POINTS for ImGui — a deliberate, documented split. | `[DEPTHPREPASS] target 3840x1536` at 2.5000:1 with a 1656×662 pt preview, 2026-08-21 22:11:47 | 🚨 The first version was WRONG: it sized the WINDOW, so macOS clamped 2560×1024 to a **3600×2048** drawable — the wrong aspect, silently. His screenshot caught it |
| ~~**S2**~~ | ✅ **STAR SIZE IS RESOLUTION-NORMALISED, AS ONE LAW.** Every pixel quantity in `particle_vertex` is in REFERENCE pixels (a 2260-tall drawable, his fullscreen height, measured); ONE multiply at the tail converts to device pixels. | `render.metal:2614` · fullscreen no-op confirmed: meanPx 1.02 / maxPx 25.71 vs 25.73 before | 🚨 The first version scaled `rawSize` + `zoomCap` and left FIVE pixel laws unscaled. His order: *"we dont want two values for a single thing ever"* |
| **S6** | 🔴 **OPEN — NO CAPTURE PATH EXISTS.** `grep` for prores/AVAssetWriter/recordFrame/exportFrame over `src/` → **zero hits**. He plays a MIXED set (live + pre-rendered), so recordings are real deliverables. | verified 2026-08-21 | His fork: record the Syphon feed externally, or build an in-app export. **S1+S2 were the prerequisites and are now done** |

⚠️ **G2 is now the lever, not S2.** MEASURED 2026-08-21: **96–99% of stars sit in the bottom size bin at every resolution** — the size law emits sub-pixel values and `clamp(rawSize, 1.0f, …)` (`render.metal:1552`) is doing all the work. The picture is a floor, not a law. That is the number under *"star size is still stars, not smear of stretched light"*.

⛔ **A retraction, logged:** the first S2 A/B ("8× the pixels → meanPx 1.02 vs 1.26") was **time-confounded** — the two runs were sampled at 12 s and 25 s. At a matched first sample both read **1.02**, which confirms the device-pixel diagnosis harder than the wrong numbers did. Compare KPROBE at matched elapsed points, never `tail`.

---

## 🕳️ BH — the priority (his order 2026-08-14: *"BH LENSE THEN TUBE / SPHERE BEFREIUNG"*)

| # | What is open | Verified today | Deciding move |
|---|---|---|---|
| **BH1** | **The whole 08-17 emission law is UNTESTED.** blackbody `T(r)`, `g`, and the absorption/transfer all landed; his verdict was *"dtill the same in every way lol"* — because the march only ever saw 3.7% of the disc. | `app_state.h:57` bit19 default ON | Get the field to the expanded-disc state (meanR ≈ 44 sim, r_s ≈ 0.23), then read **`[MARCH] bCull`** — never off a screenshot |
| **BH2** | 🚨 **TWO Ω LAWS FOR ONE DISC.** Sprite Doppler uses `1/(r^1.5 + KERR_A)` and a hardcoded global **+Z** tangent; the march uses `√(M/r³)` and `poseAxis`. U6/U7 unified the arcs and playback and never reached the sprite. | `render.metal:1610`, `:1611` vs `:3716`, `:3721` | One law, one axis. This is the unified-physics goal, in one function  ⚠️ **A fix was written and reverted 2026-08-20 14:22:25 on a misread verdict — it was never rejected on its merits. Re-applying is cheap.** |
| ~~**BH3**~~ | 🔨 Perspective divisor fixed 2026-08-20 (`renderer.mm`), still unverified by eye. 🆕 **METRIC SHADOW DEFAULT FLIPPED OFF 2026-08-22 06:56** — his words: *"turn the shadow off btw its fake and annoying"*. `app_state.h` `uiTogMetricShadow = false`. 🚨 **AND IT DID NOT REMOVE THE DARK CIRCLE.** The perfect black disc is a SEPARATE object: a depth-only analytic sphere at `b_c = 2.598 r_s`, `render.metal:3164` + `renderer.mm:3852`, gated ONLY on `lastHorizonR > 0` — **not on bit15**. It writes depth with colour masked off, which is what made the hole OCCLUDE (the 2026-08-14 "the hole is a body" fix). His words for it: *"the ring that still is the black hole without the lense"*. ⚖️ Killing it takes the body away again — **his call, not ours**. | verified in source 2026-08-22 07:35 | Decide the sphere before touching the lens further |
| **BH4** | ✅ **NOT OPEN — the board is wrong.** `BOARD_BLACKHOLE.md` §2 and §6 row 1 still list the parity pinch ring and the tuneLens-blind secondary as open. **Both were fixed 2026-08-14** (17:30:54 and 17:53:52) and the code says so at length. ⚠️ Consequence worth keeping: a lens A/B done with the **SLIDER** before that date is still void. | `render.metal:1164` (placed by the lens equation, no `mix`), `:1184` (`imageWeight = cam.tuneLens * lensRamp * …`) | Correct the BH board, do not re-do the work |
| **BH5** | **The lens is OFF whenever he plays.** `bhLensActive = totalAmplitude < 0.02f` — the hole only lenses at silence. Deliberate, but it means the show never sees it. | `renderer.mm:1662` | His call, not a bug |
| ~~**BH6**~~ | ✅ **FIXED 2026-08-22 04:53 — AMR MOVED TO bit21.** `renderer.mm:1962` + `particles.metal:2164`. **The bug was worse than the board said: `SS_NO_AMR` WAS A NO-OP.** bit15 was already set by `uiTogMetricShadow` (default ON), so `bhToggles | (amrOn ? …)` never changed anything — every A/B run with that flag compared two IDENTICAL configurations. bit21 is free (bhToggles packs 0..20; bits 21+ elsewhere belong to `debugFlags`, a different word); no preset serializes bhToggles, so no migration. | A/B at matched resolution 2026-08-22 05:05: core M(<0.5) 2.935e4 (AMR off) vs 5.283e4 (on) at sample 4 — the flag now changes physics. ⚠️ n=1 per side | ⛔ **Every AMR conclusion in this project's history is VOID** — the switch never worked |
| **BH7** | **The 128³ box-average objection is unaddressed** — the march samples NEAREST from a 128³ grid, so it can never resolve sub-cell structure. | `app_state.h:57` | Structural (L4). Decide, don't drift |
| **BH8** | ✅ **b_c IS CORRECT — independently derived, not re-quoted.** `tools/bc_validate.cpp` now EXISTS (it did not) and I compiled and ran it: bisection on an independent null-geodesic integration gives **b_c = 5.196152422707 M** vs analytic `3√3·M` = 5.196152422707 — rel err **8.2e-15**; the escaping ray skims r_min = 3.0025 M against a photon sphere at 3M. The shipped shader constant **2.5980762** (`render.metal:3177`, `:937`, `:1104`) is correct to **4.4e-09**. ⚠️ Worth keeping: the shipped integrator's own step size is load-bearing — at its real step 0.03 it lands 2.59803855 (rel err 1.5e-05), but at step 0.10 that degrades to 1.1e-03. **Do not loosen the step.** 🔴 **STILL OPEN: gravitational redshift**, the `√(1−2M/r)` half of `g`. | run by me 2026-08-22 01:42 | Redshift only; b_c is settled |
| **BH9** | **The accretion rows** (moved into `BOARD_BLACKHOLE.md` §N2): **A2** reversibility now runnable · **A3①** `/0.5` denominator real but not binding · **A3②** hole profile centred on the ORIGIN, not the mass · **A5** the fuse is a 3–16 min stochastic wait (a show risk) · **A6** refund-floor leak · **A8** `feed` returned nonzero for the first time · **MERGER-FACE** a merger has no visual. | §N2 | Each is its own row |
| **BH10** | **His 12:13-run complaints, unactioned:** *"still a fake visual not physical overlay"* (⚠️ the §2 parity proof says the optics ARE real — so it is the BLEND that reads fake) and *"usually a black hole is reddish blueish, not just blue grey"*. | §4d | Screen time, one at a time |

---

## 🎨 GRAPHICS

| # | What is open | Verified today | Deciding move |
|---|---|---|---|
| **G1** | 🚨 **NO PER-PARTICLE DEPTH IN THE STAR PASS.** The depth **pre-pass** writes depth (`depthWriteEnabled = YES`), but the additive particle pass is still write-OFF, so nothing orders or shades by distance. This is the one fact under "it doesn't read as 3D", and it blocks correct camera blur and per-particle motion vectors outright. | `renderer.mm:1103` (NO, particle pass) vs `:1116` (YES, pre-pass) — **re-stamped 2026-08-20 19:03:44**, the L1 lens fix pushed both down 9 lines from the `:1112`/`:1125` printed at 14:08:59 | Design first — turning writes on is not one line (store action, buffer, blend order) |
| **G2** | **Star size — his biggest remaining look complaint:** *"star size is still stars, not smear of stretched light"*. | `render.metal:1558` `out.pointSize = drawn` | Size + streak law together, not a floor |
| **G3** | **⛔ THE RIBBON PASS IS DELETED — 2026-08-20.** `TrajOut`, `trajectory_vertex`, `trajectory_fragment`, its pipeline and its draw call, ~370 lines. His verdict on the thickness test: *"this provers the trail theory dead ... its the wrong approach"*, then *"delete the fucking code and put it 6 feet under"*. **Do not rebuild it.** The diffraction-cross/"diamondy" complaint outlives it and belongs to the sprite. | `render.metal` headstone at the old site; code in git at `5ee213d` | — |
| **G4** | 🆕 **THE GYROSCOPE IS SOLVED — 2026-08-22.** His words: *"the axis is lose its turnign wihtin itself"*, then the correct recall: *"the thing with the rings came when we unified the orbits ... we had two systems at work made it 1 since then its fucked."* **He was right and he named the commit's intent from memory.** `render.metal` playback read `float3 axis = poseAxis(rel)` from **2026-08-15** ("EVERY STAR ON ITS OWN ORBITAL PLANE", his order then) — a DIFFERENT axis per star, tilted by that star's own `atan(|z|/ρ)`, so stars at different heights sheared the field into nested tilted rings. **Fixed 2026-08-22 08:20: one axis for the field.** +Z is DERIVED, not magic — the launch law `v = ẑ × r` (`particles.cpp:256`) puts total L along +Z by construction. ⭐ The 08-15 order no longer binds: it existed to match the ARC RIBBONS, which were deleted 08-20. | his verdict 2026-08-22 08:40:10: **"looking better"** | ⚠️ Two things this did NOT fix, below (G4a/G4b) |
| **G5** | **Extinction FAILED and the reason is physics, not render** (his eyes: *"still a rick and morty eye"*). The absorption is live and at full strength, but the clump is ~1 cell across while the march steps 1.5 cells — the first sample is already outside it. | `render.metal:2590-2591` | Density must resolve better than 1.0 sim. A render fix cannot land this |
| **G6** | **Camera motion blur built but wrong** — `prevViewProj` is fully plumbed, but the depth is a hardcoded `z = 0.99` far-plane proxy. Per-particle motion vectors are not started. Both gated behind **G1**. | `postfx.metal:37`, `:452` | After G1 |
| **G7** | **THE SMEAR — four attempts, all rejected 2026-08-20.** Screen-space motion smear now exists and is wired to REAL motion (star pass writes a velocity target; camera cancels because both ends use one matrix). Dials: Smear length, Smear hold. 🚨 **KNOWN BUG, DIAGNOSED NOT FIXED:** 48 taps over a several-hundred-pixel band puts samples 5–8 px apart, so each star repeats as separate beads and MORE length makes it WORSE. The fix is a multi-pass doubling smear, not more taps. | `postfx.metal`, the smear block | Build the multi-pass version, or park it |
| **G8** | **Poisson SOR ≈ 6 ms — double the whole star pass.** 80 sweeps × 2 colours = 160 compute encoders per frame, with a live knob. | `renderer.mm:2433-2438`, `SS_SOR_SWEEPS` | Needs an **accuracy** verdict, not a perf one |
| **G9** | **Chladni sharpness** — *"almoooost."* `ridgePull` uses the SCULPT gradient, not the eigenmode ∇Ψ, and there is no node dissipation. **The eigenmode itself is genuinely 3D — do not re-litigate that.** 🆕 **Second, separate defect on the same feature — verified in source 2026-08-20 19:03:44:** `modes.h:11` declares `alpha` as "Bessel zero value J_m(alpha)=0", but `modes.cpp:24` assigns `440.0 * pow(2.0, (midi-69)/12.0)` — the note's frequency **in Hz** — under a comment calling it "mostly vestigial in Phase 9". It is **not** vestigial: `main.cpp:694` copies it into voice data and `bessel.cpp:42` evaluates `besselJ(m, alpha * r)`. ~~A 440 Hz note therefore evaluates J_m at argument 440·r instead of at a Bessel zero.~~ 🚨 **THAT CONSEQUENCE IS REFUTED — agent-verified 2026-08-22.** `bessel.cpp`'s `Z2()` and `potential()` have **ZERO callers** repo-wide; the file compiles but is dead, so the Hz value never reaches a Bessel evaluation. The ONE live reader is `particles.metal:2476`, which uses `alpha` as a **scalar gain** in a `cos(mθ)sin(nφ)` sculpt (no Bessel call), gated behind bit16 — which `main.cpp:2468` leaves OFF by default. **In the default config `alpha` affects nothing.** The GPU already documents the bug at `particles.metal:532-536` and looks the true zero up itself at `:2519`. ⚠️ `main.cpp:694` is a STALE citation — the real copy is `:716`, plus two unlisted producers at `:665` and `:683`. ⛔ **Do not book this as a visual fix**: the live path never read the broken value, so it cannot touch the *"almoooost"* complaint. It is a data-truthfulness fix (3 files — the CPU zero table is 7×4 but `modes.cpp` emits m=0..11, n=1..9, so it must be extended to 12×9 to match the live GPU table). 🆕 Live inconsistency found on the way: under `SS_SCULPT=1`, VJ-mode sculpt is ~100× weaker than MIDI-mode, because `main.cpp:585-600` already feeds real Bessel zeros into the same expression MIDI feeds Hz into. ⚠️ Do not conflate with the `ridgePull` half above. | `modes.cpp:24` · `modes.h:11` · `main.cpp:694` · `bessel.cpp:42` | Swap the gradient source |
| **G10** | **Chromatic aberration is a flat radial RGB offset** (no spectral/lens model); **scanlines are a Nyquist-rate sine with no filtering** — that is aliasing, not an effect. | `postfx.metal:167-170`, `:491` | Rebuild or remove |
| **G11** | **Rick-and-morty eyes** — start from his name for it. ⛔ My bit20 theory is dead. Do not re-pitch it. | C11 | — |
| **G12** | **Corpse compute** — his order: dead particles must not be computed. Early-out shipped, its A/B failed to attribute, suspected SIMD divergence (scattered corpse ids ⇒ almost no fully-dead 32-lane group). If true the answer is **compaction**, not an early-out. | DEAD-COMPUTE row | One soak, alternating bit28 **within** a run |

| **G4a** | 🔴 **THE SPAWN GIVES A SPHERE A PLANAR VELOCITY LAW.** `particles.cpp:256-262` gives EVERY particle `v = ẑ × r` — purely azimuthal about +Z, `vz = 0` — while the HALO (15% of the field, Plummer a=15) is spawned ISOTROPICALLY on a sphere (`:189-199`). Speed is `v_circ(r3)` from the 3D radius but the lever arm is `lxy`. Off-plane particles are therefore NOT on circular orbits; each sits on an inclined great circle set by its birth `z`. ⚠️ **LATENT SINCE 2026-07-20 (`1bb9c70`) — a month old, NOT the recent regression.** He was right that the visible break was new; this is the older condition underneath it. Also: particles within 1e-4 of the Z axis fail the `if` and get **zero** velocity — they fall radially through the centre. | `git blame` 2026-08-22 08:12 | Velocity perpendicular to its OWN radius, not to Z — changes the whole initial condition, **his call** |
| **G4b** | 🔴 **THE HOLE HAS NO INTAKE — IT HAS A DELETE KEY.** A merge does not move matter inward: `particles.metal:3792` sets mass→0 and teleports the corpse to `park = 4000 + id%1024` (r ≈ 6928) — **108× outside the ±64 domain**, frozen, unreachable by any force. Nothing falls in, so there is no accretion flow to render. Revival fires ONLY during sustain (`envelopePhase` 2.5–3.5); the rest-trickle was cut 2026-08-04 to stop a mass pump. **MEASURED this run: `live=999 → live=2` of 1000, `insideRS=0`** — the field ate itself to 0.2% and the centre held no live matter. What survives is what the hole could never reach. His words: *"the merger to bh state is broken. only works at launch with the fake drag."* | `[PROBE-1000]` progression, 2026-08-22 07:15 | This is the row under "the flow of the bh doesnt make sense" |
| **G4c** | ⚠️ **THE VISIBLE MOTION IS PLAYBACK, NOT PHYSICS — and it stops when he plays.** The rotation is gated `envelopePhase < 0.5` (silence only) and `rxy > horizonR`. Raw physics is **~38 s/orbit** by the block's own comment. So a played note switches the time-lapse OFF and the field looks frozen. His words: *"the mergers jsut sit there. its so weird. physics dead here."* — correct observation, inverted cause: the life was the time-lapse. | `render.metal:674` gate | Not a bug yet. Decide whether play should keep turning |

---

## 🔊 AUDIO

| # | What is open | Verified today | Deciding move |
|---|---|---|---|
| **A1** | **Sonification is at ZERO lines.** `grep -rl "sonif\|perParticleVoice\|fieldVoice" src/` → **no files**. The design is complete; nothing is built. | verified 2026-08-20 | D7: the per-particle voice at **N = 1**, the solo path |
| **A2** | **4 of 14 lock sites are on the CoreAudio realtime thread; 3 BLOCK.** The other 10 are main/render/CoreMIDI. ⛔ Strike the old "five sites" figure. 🚨 **THE BIGGEST DROPOUT RISK IS NOT A LOCK:** `fprintf(stderr, …)` runs **inside `audioOutputCallback`** every 100th callback (`audio_engine.mm:66-69`) and `std::vector<float> windowed(fftSize_)` heap-allocates per FFT call on the same thread (`fft.cpp:59`). I confirmed both sit in the IOProc. Neither was ever on the board. | verified by me 2026-08-22 01:48 | **Kill the fprintf and the allocation FIRST** — cheaper and higher-value than the lock refactor. Show-relevant: this protects the LIVE half of the set |
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

## ⚠️ NOT VERIFIED — needs a run or a rebuild, do not quote as fact

*(Shrunk 2026-08-22 by source-read verification. Everything settled below has left this block.)*

- **fps figures.** Last baseline ~31–36 fps idle @2M, worst frame 50–99 ms, march-live median 39.9 (n=776) — old bundles. **A starved run is not evidence.** 🆕 One fresh single sample: **30 fps at 2M at 3840×1536** (2026-08-21 22:11), a just-started run — a sample, not a verdict.
- **B5 — the −280 M☉ residual.** ⚠️ **Split verdict:** the MECHANISM is source-confirmed and still true; the MAGNITUDE needs a run and is contested. Do not quote the number.
- **32 build warnings → zero** (C10). The count still needs a rebuild. But the source half is settled below.

### ✅ LEFT THE BLOCK — settled by source read 2026-08-22, verified by me

| Row | Verdict | Re-stamped |
|---|---|---|
| **B2** radial cutoff | **STILL TRUE**, both halves — the window is origin-nailed | `particles.metal:405` (was `:300`, now a bare `//`), guard `:4288` (was `:3814`), centre `:4282` |
| **B3** bit4 origin-pin | **STILL TRUE** — spring live, ships OFF, only 3 enable paths | `particles.metal:1349`; `app_state.h:48`; `main.cpp:292`, `:1361`, `:2295` |
| **B10** density pressure | **STILL TRUE** verbatim — TODO comment and scale-12 literal both intact | `particles.metal:974`; comment `:969-973`; scale `:994` |
| **C10** source half | The warning is **REAL and PRESENT**; the `:485` citation is **DEAD** (that line is now `//`) | `render.metal:614` (`particle_vertex` decl) + `:626` (the `kProbe` param) |
| **`ssDiskTempShape`** | 🚨 **CORRECTION — it is NOT "still live".** It appears exactly ONCE in the whole tree: its own definition. **Zero call sites.** It is an *uncalled hook, deliberately retained.* The warning stands, but as **DO NOT SWEEP**, not "it is in use" | `render.metal:257` |
| **`renderer.mm:3894`** | **NOT FOUND — deleted outright 2026-08-20**, not relocated. Retire the citation; the dead road itself stands | headstones only: `renderer.mm:3961-3981`, `render.metal:2893-2899` |

### 🧭 A PATTERN, not a coincidence — **THE FACTS HOLD, THE ADDRESSES ROT**
Five independent checks on 2026-08-22 each found a decayed citation: `main.cpp:694→716` (G9), `render.metal:1621→1722` (BH4), `particles.metal:300→405` and `:3814→4288` (B2), `render.metal:485→614` (C10), `renderer.mm:3894→gone`. **Not one row was wrong about the code; nearly every row was wrong about where it lives.** ⭐ Re-read the line before citing it, always — and never trust a `file:line` older than the last refactor.

## ⛔ DEAD ROADS — do not retry (the short list)

- **A stroke per star, in any form** — 1 px lines (hair), then real triangle strips with a thickness slider
  (slabs). Four fixes were tried on it across 2026-08-20 (width conservation, luminosity, plane, thickness) and
  the look survived none. **Deleted 2026-08-20.** A million separate strokes with gaps between them IS hair.
- **The playback / time-lapse rate as a speed for anything physical.** It is ~150 rad/s of display speed. It
  blew up the Doppler once (logged), and driving the smear with it produced a screen-filling spirograph
  (2026-08-20 14:48). If a pass needs "how fast is this going", it needs the physics velocity or a geodesic law.
- **Dimming individual strokes to fix a mat of strokes.** Treats each hair as the thing to fix. His verdict:
  *"your apporach is wrong."*

- **postfx as the cause of anything** — ruled out on fps and on star appearance. Never suggest again.
- **Raising the march emission gain** to make the pass visible — screen-filling brown blob, reverted the same day.
- **Reading the marched region's size off a screenshot** — wrong twice, in both directions. Read `[MARCH]`.
- **The march as the hole's renderer** · **the fullscreen geodesic paint** · **the seed billboard** · **re-centring the lens on `cam.bhX/Y/Z`** (4 no-ops logged).
- **`L̂ = r × v` for the orbit normal** — use `poseAxis`, from position.
- **The 32-per-cell scatter cap is NOT dead code** — it is load-bearing. Writing past it creates mass.

---

**Last Updated:** 2026-08-22 08:45:00  *(gyroscope SOLVED and its two deeper rows opened; BH6 fixed; shadow default off; depth-sphere discovery)*
**Previously:** 2026-08-22 01:52:10  *(agent results folded in AFTER I re-verified each load-bearing claim in source; BH6 and G9 consequences CORRECTED, not transcribed)*
**Previously:** 2026-08-21 22:14:30  *(S1/S2 closed, show moved to Cologne; the 08-20 body is unchanged)*
**Previously:** 2026-08-20 19:03:44  *(body written 14:08:59; G1 line numbers re-stamped and the alpha-is-Hz defect added to G9 after a source re-read)*
