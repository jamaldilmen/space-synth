# 🕳️ THE BLACK HOLE BOARD — dedicated, 2026-08-14

> **His order, 2026-08-14 01:41:51:** *"create dedicated board for BH. with all knowledge every hard limit and inspo we know of and track this shit down properly. I want my proper bh with the time / space mindfuck look. Nothing below that."*

**This file is the reference of truth for the hole.** `docs/BOARD.md` stays the whole-project board; everything BH moves here. Every row carries a **verified `file:line`** checked on **2026-08-14 01:41:51** against `SPACE-SYNTH-TUBE-killtube`, branch `kill-the-tube-2026-08-11`, bundle `01:28:44`. A row with no citation is a claim, not a fact, and is labelled as such.

**Source of record for the physics:** `docs/RESEARCH_2026-07-24_interstellar_dngr.md` — the DNGR extraction (James, von Tunzelmann, Franklin & Thorne, CQG 32 (2015) 065001 = arXiv:1502.03808v2). Section numbers below in the form *(DNGR §7.1)* refer to that doc.

---

## 0. THE TARGET, DECOMPOSED — what "the time / space mindfuck look" is actually made of

The Gargantua look is not one effect. It is **five** separable features, and they fail independently. Naming them is what makes this trackable.

| # | Feature | What it looks like | What produces it |
|---|---|---|---|
| **S1** | **The shadow** | A hard black disc at **b_c = 2.598 r_s**, edge crisp, ~2.6× the horizon | Ray fate: photons with b < b_c spiral in *(DNGR §5)* |
| **S2** | **The wrap** | The far side of the disk bent **over the top and under the bottom** of the shadow — the signature horseshoe | Secondary images: rays making ~½–1 loop *(DNGR §4, §5)* |
| **S3** | **The photon ring** | An infinite stack of exponentially thinner, fainter rings **hugging the shadow edge** | n ≥ 2 windings near the photon sphere r = 1.5 r_s *(DNGR §4)* |
| **T1** | **Doppler beaming** | One side **blazing**, the other nearly gone | g³ specific-intensity transform on the disk's orbital velocity *(DNGR §3, §5)*. Intensity only — the **colour** half is vetoed, see §1c |
| **T2** | **Time dilation shear** | The inner disk **winds and nearly freezes** relative to the outer | dτ/dt = √(1 − 1.5 r_s/r); inner clocks run slow |

⭐ **THE KEY STRATEGIC FACT: WE ALREADY HAVE THE "TIME" HALF. THE GAP IS THE "SPACE" HALF.**
**T2 is built, live, and he loves it** — it is his *"time warp traces… beautiful time warpeyssss"* (2026-07-26 21:00). `render.metal:782-784`: `tDilate = sqrt(max(0.4, 1 − BH_R_IN_SIM/r))` applied per-particle to the spin angle, making the view rotation a **radius-dependent shear**. 🚨 **It was removed once as a "correctness fix" and killed the effect on sight (9-minute regression, 2026-07-26 20:58 → 21:06:52). NEVER remove it.**
**T1, S1, S2, S3 are all partial or absent.** That is the whole job.

> ⚠️ **Nolan's cheat, and our deliberate departure** *(DNGR §3, "Movie cheat")*: the film **turned OFF** the g³ Doppler asymmetry because the true lopsidedness was *"too confusing for a mass audience"*, and slowed spin to a/M = 0.6. **Their Fig. 15c is what the disk truly looks like. We want the true version.** So our reference is *not* the movie frame — it is Fig. 15c. This matters: if we ever match the movie exactly, we did it wrong.

---

## 1. WHAT WE ACTUALLY HAVE — verified inventory

### 1a. ✅ REAL, LIVE, AND PHYSICAL

| Thing | Where | Status |
|---|---|---|
| **Exact Schwarzschild deflection LUT** — α(b) = 2∫₀^{u₀} du/√(1/b² − u²(1−u)) − π, 256 entries, log-spaced b/r_s ∈ [2.60, 200], turning point by Newton, endpoint singularity killed by u = u₀(1−t²), 1024-point midpoint quadrature | `renderer.mm:799-836` | **Real.** Genuinely log-divergent at the photon sphere. |
| **Angle-space thin-lens solve** β = θ − α(θ)·D, weak-field seed + 3 Newton steps on the LUT, each particle's **true depth D** behind the hole, re-projected through `viewProjection` | `render.metal:970-1046` | **Real.** Moves particles, not pixels. |
| **A genuine second image** — instance 1 solves the opposite root, dimmed by real relative magnification | `render.metal:1043-1062`, instanced at `renderer.mm:3643` | **Real, and parity-flipped** — see §2. |
| **T2 dilation shear** | `render.metal:782-784` | **Real, live, his favourite thing.** |
| **Horizon-interior cull** — matter inside r_h emits nothing | `render.metal:821-838` | Real. Reach = **1.0 r_s only.** |
| **Photon-capture cull** at the exact b_c = 2.5980762 r_s | `render.metal:840-874` | Real but **gated off whenever the lens is on** (`!lensWillImage`, `:857`) = off by default. |
| **Capture test on the IMAGE** (2026-08-14, this session) | `render.metal:1019` | **SHIPPED, UNVERIFIED — his verdict pending.** See §4. |
| **Emergent horizon r_h** from the honest mass profile, eased for render (~0.7 s e-fold), raw value kept for physics | `renderer.mm:1608-1616`; raw at `cam.horizonRRaw` | Real. Two values on purpose — **use raw for physics facts, smooth for drawn size.** |

### 1b. 🌑 BUILT, CORRECT, AND SWITCHED OFF — the geodesic ray-march

**`bhmarch_fragment`, `render.metal:2951-3140+`, pipeline built at `renderer.mm:3924`, gated on bit19.**
This is a real implementation of DNGR §7: unprojects each pixel to a world ray (ortho *and* perspective, `:2971-2974`), culls by impact parameter (`:2980`), back-extends to r = 60 r_s, **marches in units of r_s so the step rule is scale-free** (`:2989-2992`), integrates with `dl = stepScale·r^1.5` (`:3005`), **breaks on `r < 1.0` = captured = shadow by absence** (`:3002`), and gathers emission from the **real particle field** via the CIC hash grid.

**It is DEFAULT OFF** (`app_state.h:57`, `uiTogRayMarch = false`) since **2026-07-28 09:32:18**, on his order: *"this orange shadow of the blackhole is super old and must leave asap."*

**Why it was killed — both reasons are structural, not tuning:**
1. 🎨 **It can only ever be orange.** Its single colour is a hardcoded `float3(1.0f, 0.55f, 0.25f)` scaled by density (`render.metal:3129`). **There is no temperature input and no temperature grid exists anywhere in the renderer.** It physically cannot be anything but orange at some brightness.
2. 🧱 **It can never carry Chladni structure.** Its output is a box-average of a **128³ density grid**; the sprites draw **2M+ bodies at sub-pixel precision**. Two pictures of one disk ~100× apart in resolution, **additively overlaid** — that is his *"it doesn't connect to the rings"*.
   ⭐ **The 2026-07-26 21:20 A/B settled it: lens bit8 ON, march OFF → *"ITS FINALLY THE CORRECT FEEL"*.**

🚨 **DO NOT re-pitch the march as the hole's renderer.** See [[space_synth_lens_is_the_hero_2026-07-26]]. **It is still the only thing in the codebase that can produce S3 (the photon ring) and true multi-loop S2.** That tension is the central design problem of this board — §5.

### 1c. ❌ ABSENT

- ⚠️ **T1 was listed here as ABSENT on the first draft of this board. THAT WAS WRONG — corrected 2026-08-14 12:01:52.** Beaming exists and always did, at `render.metal:1469+`. See §4b for what was actually wrong with it and what shipped. The **colour** half is a different matter: `dopplerColor` was deleted 2026-08-11 (declared, assigned, never read), and `:1467` records that **Doppler-as-hue was removed 2026-06-26 on his verdict — do NOT re-propose it.**
- **S3 photon ring.** The lens produces **exactly two images** (instances 0 and 1). n ≥ 2 windings are not representable by a two-instance sprite scheme, full stop.
- **Kerr / spin.** Everything is Schwarzschild (a = 0). No frame-dragging, no shadow flattening, no off-centre shadow. *(DNGR §1.3, §7.4 — the upgrade path is written if we ever want it.)*

---

## 2. ✅ ANSWERED — DOES OUR SECOND IMAGE SWAP HANDEDNESS?

**The test** *(DNGR §4, and his own NASA top-view panel)*: light from beneath the far side travels **>180°, so paths cross and that image arrives left-right SWAPPED.** No image-space warp can flip parity. So parity is the yes/no that decides whether the lens is real optics or decoration.

**✅ YES — IT IS REAL OPTICS.** Answered from the code 2026-08-14 01:12:00, no screen needed.

Secondary placement (`render.metal:1055`): `target = bhWorld + along·dHat − pHat·th`. Signed transverse coordinate θ_r = −th(β):
- **tangential** eigenvalue = θ_r/β = −th/β **< 0**
- **radial** eigenvalue = −dth/dβ **> 0** — from β = α(θ)·D − θ, dβ/dth = α′D − 1 < 0 since α is decreasing

**det J < 0 ⟹ negative parity ⟹ mirror-reversed.** Nobody painted it; it falls out of solving the opposite root. The Newton damping `min(da·D − 1.0f, −0.25f)` (`:1049`) clamps that denominator negative, so even the damped solve cannot lose the sign.

**⟹ The lens needs a FIX, not a replacement.** Bend, parity and second image are all physical. Two blend sites are what's wrong:

- ⚠️ **The flip is incomplete below full strength.** `:1057` places the image at `mix(worldPos, target, lensRamp)` — lerped from the **unlensed** position. So θ_r(β) = (1−L)β − L·th(β) and the tangential eigenvalue only goes negative where th/β > (1−L)/L. With u = β/θ_E the zero crossing is **u = 1/√(R(1+R))**, R = (1−L)/L: at bhStrength 0.50 (where instance 1 is born, `renderer.mm:3643`) L = 0.394 → flipped only inside 0.51 θ_E; at 0.55 → 0.71 θ_E; at 0.90 → L = 1, flipped everywhere. ⟹ **a zero-parity pinch ring inside the second image that expands outward as the hole strengthens.** Artefact of the `mix`, no counterpart in optics.
- ⚠️ **The Lens Bend slider cannot turn the second image off.** Primary blends by `cam.tuneLens · lensRamp · depthMix` (`:991`, `:1039`); secondary uses **bare `lensRamp`** (`:1057`, `:1062`). Default 0.85 (`app_state.h:135`). ✅ The **bit8 toggle (`0x100`) IS clean** — kills `lensActive`, culls the secondary at `:920`.
  🚨 **An A/B done with the TOGGLE is trustworthy; one done with the SLIDER is not.** Any past lens A/B needs to be re-read in that light.

---

## 3. 🚨 HARD LIMITS — structural, measured, or paid for in blood

| # | Limit | Evidence |
|---|---|---|
| **L1** | **The lens is gated and sized by a SCREEN-SPACE number, and it is documented-wrong.** Everything keys on `cam.bhShadowNdcRadius > 1e-4f`. Computed `renderer.mm:1642`. **The code's own comment says it is ~1.2/0.414214 = 2.897× TOO SMALL** in perspective, and uses camera→**origin** instead of camera→**hole**, so the error **grows as the seed wanders**. Marked *"the next change"* — **never made.** | `renderer.mm:1626-1636` |
| **L2** | **The lens is OFF during play.** `bhLensActive = (totalAmplitude < 0.02f)`. The hole only lenses at silence. Deliberate (star-map regime) but it means **the mindfuck look is a REST-STATE look** and cannot appear while he plays. | `renderer.mm:1618` |
| **L3** | **A two-instance sprite scheme cannot produce S3.** n ≥ 2 windings need a per-pixel integrator. This is a representation ceiling, not a bug. | `renderer.mm:3643` |
| **L4** | **The march can only be orange, and can only be 128³.** Both structural — no temperature input exists, and a box-averaged grid cannot resolve sub-pixel sprites. | `render.metal:3129`; `app_state.h:57` |
| **L5** | **Origin lock: the renderer's hole centre IS the origin.** `bhPosX/Y/Z` are hard-zeroed by design (the COM is pinned at 0/0/0 and the seed sinks there); the enclosure-COM refinement sits inside `if (false)`. So every "re-centre on the hole" fix is a **NO-OP** — 4 have been logged. Making it honest is real work (A3②), not a vector swap. ⚠️ `render.metal:774-775` cites this as `renderer.mm:3293-3295`; **that citation has drifted** — the live sites are below. | `renderer.mm:3555-3557` (the zeroing), `:3193` (`if (false)` refinement) |
| **L6** | **⚠️ NEW — bit15 IS DOUBLE-BOOKED and the AMR kill-switch is broken.** bit15 = "metric shadow" in the render *and* = "AMR fine force" in the physics. `physicsUniforms.bhToggles = bhToggles \| (amrOn ? 0x8000u : 0u)` — an **OR**, which can only ADD the bit, never clear it. `uiTogMetricShadow` defaults **true**, so bit15 is always set ⟹ **`SS_NO_AMR=1` does not disable AMR while metric shadow is on.** Any AMR A/B run to date is suspect. | `renderer.mm:1897`, `particles.metal:2161`, `render.metal:821` |
| **L7** | **Perf ceiling.** Baseline idle @2M, ortho, 1×: **~31–36 fps, worst frame 50–99 ms.** ~46% of the field is corpses running the full kernel. A per-pixel march on top of this is not free. 🚨 `physicsUniforms.dt` is a fixed `0.0165×warp` step — **never derive fps from it.** | `docs/BOARD.md` rows 10⁺, 12 |
| **L8** | **Never test the hole above 1× time warp.** At 64× a star moves 127 contact-radii per frame and tunnels past every merge test. Accretion/merger results at high warp are artifacts. | [[space_synth_bh_reversibility_2026-08-07]] |
| **L9** | **`bc_validate.cpp` DOES NOT EXIST IN THE TREE and never did** — `git log --all --diff-filter=A` finds no commit that ever added it. `render.metal:2990` and `app_state.h:53` both cite it as the integrator's validation (b_c to 1.4e-6). **That validation is currently an unverifiable claim.** Re-deriving it is cheap and should be done before the march is ever trusted again. | verified 2026-08-14 |
| **L10** | **Limits are PERCEPTUAL, not technical.** His standing rule: report ceilings as the cost of the *current formulation*, never architect down to a measured number. | [[feedback_limits_are_perceptual_not_technical]] |

---

## 4. ✅ THE NASA GAP — SHIPPED AND **PASSED**

### ✅ HIS VERDICT 2026-08-14 12:13:00 — ***"i think the core is blacker tho"***. S1 accepted. Keep it.

### THE NASA GAP: our shadow was hoped-for, not guaranteed

**The skill diff in one sentence:** NASA/DNGR trace a **geodesic per PIXEL**, so the shadow is a property of **RAY FATE** — a pixel is black iff its ray ends on the horizon, and light can never appear inside b_c. **We forward-map SPRITES and hope none land there.**

**The number:** our shadow was guaranteed black only out to **r_h = 1.0 r_s**, against a true shadow of **2.598 r_s** ⟹ **1 − (1/2.598)² = 85% of the shadow AREA had no reliable mechanism.**

Three culls, each partly off: horizon-interior (`:821`, only r < r_h); straight-line capture (`:857`, **off whenever the lens is on** = default); lens floor th ≥ 2.62 rsW (`:988`), **diluted** at `:991`.

**Two leaks filled the hole:**
1. **`tuneLens` dilution** — floor bottomed out at 0.85 × 2.62 = **2.227 r_s** ⟹ drawn shadow **14% too small** with a pile-up ring at the wrong radius.
2. ⭐ **The `depthMix` slab — the big one, and the actual "blurry mess".** `depthMix = smoothstep(0, rsW, D)` (`:974`) → 0 for matter within one r_s **behind** the hole, so that slab drew **UNLENSED straight through the middle of the shadow**, down to r_h. Un-lensed, centred on the hole, against what should be pure black.
   🚨 Nothing removed it: the slab cull was deleted (`:853-856`) while the comment at `:803-805` **still claims** it *"handles the thin slab at the hole's own depth"*. There is no slab term at `:857`.

**THE FILL — one change, `render.metal:1019`.** Judge the photon by where its **IMAGE** lands, not its source:

    if (along > 0.0f && thEff < 2.5980762f * rsW) cullThis = true;

- The **SECONDARY already did exactly this** (`:1052`, culls at th ≤ 2.605 rsW). The **PRIMARY** was the one missing it. That asymmetry was the bug.
- `along > 0` so foreground matter keeps crossing the disc — the front/behind asymmetry is what reads as a 3D body (`:793`).
- The arch is untouched: floored primaries sit at ≥ 2.62 r_s, outside b_c.

**LOOK FOR:** disc black not smeared; edge crisp and **~17% wider** (2.227 → 2.598 r_s); foreground matter still crossing it.
**FAILURE MODE:** if the arch dims, floor vs capture radius are fighting (2.62 vs 2.598 = 0.8% margin) → widen the floor, not the test.
**Bundle `01:28:44` > source `01:28:37` — deploy verified. NOT COMMITTED.**

### 4b. T1 — THE HONEST BEAMING LAW. SHIPPED 2026-08-14 12:01:52, UNVERIFIED.

**Correction to this board's own first draft: beaming was never missing.** It has been in `render.metal:1469-1503` all along, driven by the **analytic** Kerr orbital velocity Ω(r) = 1/(r^1.5 + a) (`:1487`) — computed analytically on purpose so it survives at rest where `velW ≈ 0`. That part is sound and is **untouched**.

**What was wrong were the two lines that turned β_los into brightness:**

| | was | should be | why |
|---|---|---|---|
| exponent | `DOPPLER_EXP = 1.4f` (`:297`) | **3** | Liouville: I_ν ∝ ν³ *(DNGR §3, Fig. 15c caption)* |
| gain | `DOPPLER_K_BEAM = 0.8f` (`:296`) in `1 + K·β` | **no free gain** | The real Doppler factor has none. `vOrbit = Ω(r)·r` runs **0.23–0.67**, which already *is* β at c = 1 — so K was fudge on top of a correct velocity |
| dark side | `max(0.35f, …)` (`:1500`) | **no floor** | It held the receding side at 23%. DNGR: it should nearly vanish. The floor guarded a hard-clamp SEAM that a smooth g cannot produce |

**Measured contrast at β ≈ 0.55 (Gargantua's inner disk):** old law **1.69 vs 0.23 = 7.3×**. Honest law **6.4 vs 0.157 = 41×** — the true ratio is ((1+β)/(1−β))³.
⚠️ **ARITHMETIC CORRECTED 2026-08-14 12:19:20.** This row first read *"11.4 vs 0.088 = 129×"*; γ = 1.197 was dropped from both ends. The real peak is **6.4×**, i.e. **3.8× hotter than the old law's peak** — which is exactly what saturated the additive blend. See 4c.

**Shipped:** `b2 = min(|β|², 0.9801)`, `γ = rsqrt(1−b2)`, `g = 1/(γ(1−β_los))`, `luminance *= g³`. No free parameters. `DOPPLER_K_BEAM` and `DOPPLER_EXP` now compile as **unused** — the compiler confirming the old law is fully gone. (Both constants left in place; deleting them is a separate change.)

🚨 **Gravitational redshift is NOT folded in** — that is the √(1−2M/r) factor of A.16 and is a separate change.
🚨 **The colour half stays dead.** `:1467`: *Doppler-as-hue was removed 2026-06-26 on Jamal's verdict — do NOT re-propose it.* This change is intensity only.

**LOOK FOR:** one limb of the disk clearly **blazing**, the opposite limb nearly gone, sweeping smoothly as the camera orbits. **FAILURE MODE:** the bright limb whites out — g³ peaks ~11×, and the additive blend has blown past white before (2026-06-25). If it does, the fix is the tonemap/luminance scale, **not** re-introducing the fudge exponent.

### ✅ 4e. THE HOLE IS A BODY — SHIPPED AND **PASSED**. 2026-08-14 12:27:34.

> **His verdict 12:30:57 — *"the hole looks holey finally."*** First time. Keep it.

**WHAT WAS FAKE, and it was never the lens.** Nothing in this renderer drew a black hole. The hole was the region where we chose not to stamp sprites — three culls and a gap. Mechanically:
- the particle pass is ADDITIVE with depth **write off** (`renderer.mm:1077`),
- the main pass **discards** its depth (`storeAction DontCare`, `renderer.mm:3618`),
- `depthPrepassTexture` is written every frame and **sampled by nothing** — there is not one `texture2d<>` declaration in `render.metal`.

⟹ **Nothing in the scene occluded anything.** No "in front", no "behind", only sums of light. A black hole is, before it is any optics, **a thing that blocks** — ours had no existence in the scene's visibility. That is also exactly why the 2026-07-24 fullscreen paint had to be withdrawn the day it shipped: no depth, so it blacked out matter in front of it.

**THE FIX (`render.metal` `bhbody_fragment`, pipeline `renderer.mm` + encode before the particle draw):** per-pixel ray-sphere against the photon-capture surface at b_c = 2.5980762 r_s, writing **depth only** with `writeMask = MTLColorWriteMaskNone`. It paints nothing; it removes light by being in the way — the literal reading of "SHADOW = ABSENCE, NEVER PAINT". The particle pass **already** depth-tested (`MTLCompareFunctionLess`, `:1074`) and had simply never had anything to test against, so this turns existing machinery on rather than adding a layer. The wrap survives: lensed images land at ≥2.62 r_s, outside the silhouette.

⚠️ **`bgDepthState` is created and never used** — no `CompareFunctionAlways` pass exists to punch through this.

### ⭐✅ 4f. SPAGHETTIFIED LIGHT — SHIPPED 2026-08-14 12:37:53. **HIS REACTION: *"WAIT what is that. that looks crazy."***

> His order 12:36: *"its just stars, u see it like streuselkuchen, viele kleine dotties. no time stretched lines of light bro LETS SPAGHETTIFI THE LIGHT"*

**THE CODE TO DO THIS HAS BEEN IN THE REPO SINCE JUNE. It was never the wrong idea — it had a plane bug.**

`trajectory_vertex` (`render.metal:2701`) draws each particle's **real orbital arc over an exposure window**: `totalPhi = min(Ω(r)·exposure + spin·0.05, tuneArcWrap)`, `Ω = 1/(r^0.9 + KERR_A)` (inner-fast), with `horizonExp = bhStrength·exp(−r·0.8)` so the exposure grows exponentially near the hole. **The arc LENGTH is the speed** — that is time-stretched light earned by the physics, not a screen-space smear.

**⛔ It was stripped 2026-06-25** as *"fake trails centered to a tube shape… NOT the particles' real paths."* **That verdict was earned by a BUG, not by the concept:** `:2767` swept the arc about **+Y** (`posW.xz`) while the disk orbits **+Z**. Every ribbon ran **90° ACROSS the real motion** — which is exactly what "a tube painted over the field" looks like. **Same class of fault as PLANE FIX №2 in the Doppler block** (`:1477`: *"the 90°-off tangent made vLos noise → azimuthally UNIFORM ring… fake overlay"*).

**PLANE FIX №3 (2026-08-14):** `rXY = length(posW.xy)`, sweep about +Z, `ang` negative so the ribbon trails BEHIND along the prograde sense (+z×r, matching the Doppler block's `tang = (−y, x, 0)`). Re-enabled at `renderer.mm` (was `if (false && trajectoryPipeline …)`), original gate kept: emergent hole **or** manual spin.

🚨 **THE LESSON, THIRD SIGHTING: a 90°-off orbital plane makes correct physics look like a fake overlay.** Doppler (№2), trajectory arcs (№3). **Before condemning any azimuthal effect as "fake", check its plane against `posW.xy`/+Z first.**

**Live dials on this look (all already wired):** `tuneArcGain` (exposure→ribbon length), `tuneArcWrap` (sweep cap, ≈2.2 rad — longer closes arcs into per-particle CIRCLES = concentric rings), `tuneTrailGain` (brightness).
**⚠️ Honest caveats, none yet judged:**
- `Ω = 1/(r^0.9 + a)` is a **COMPRESSED** differential, tuned down from 1.5 in June so the inner/outer ratio "no longer tears the disk into two populations". **It is therefore NOT the true Kepler law** — the funnel's winding is artistically compressed. A lever if he wants it more extreme.
- **`rXY > 8.0` cull at rest** (`:2756`) emits nothing outside the hole's neighbourhood — that is why the OUTER rings are still Streuselkuchen dots. Deliberate old tuning, not a bug. One line to lift.
- **fps NOT MEASURED.** 22 line-verts × up to 1.5M particles = **33M vertices**; baseline was ~31–36 fps (§L7). If it bites, cap the arc budget — do **not** shorten the ribbons.

### ⛔ 4c. BOTH BEAMING CHANGES REVERTED — 2026-08-14 12:35:26. Baseline restored bit-for-bit.

**His verdict 12:30:57: *"its just black mush over half the screen."*** ⚠️ **I first suspected the new depth body. MEASURED INSTEAD, and it was not:** live `horizonR` = **0.098 → 0.176 sim**, so b_c ≈ **0.44 sim against a disk radius of 18 — under 3% of the disk.** The body is the size of a dot and cannot darken anything. **The beaming was the culprit.**

| attempt | what | why it failed |
|---|---|---|
| 12:01:52 | raw g³ | peak 1.69 → 6.4; additive blend saturated → *"just blue grey ish"* |
| 12:19:20 | ÷ ⟨g³⟩ = (1+β²/2)/(1−β²) | **worse.** Normalising by the MEAN of a skewed distribution crushes the TYPICAL value |

**The arithmetic I owed before shipping it.** At the disk's peak β ≈ 0.6: ⟨g³⟩ = 1.84, but g³ for **transverse** matter = (1−β²)^{3/2} = 0.512 ⟹ typical particle drew **0.512/1.84 = 0.28, i.e. 3.6× dimmer.** Most of a ring moves transversely, so most of it went dark and one approaching arc survived. The ring mean was exactly 1.0 as designed — carried entirely by the crescent.

🚨 **THE LESSON — why this is a revert, not attempt 3.** g³ is correct physics, but a **41× intra-frame range cannot be carried by an additive point cloud with no opacity floor.** DNGR Fig 15c is a *thick disk rendered to film*; its dim side reads because it is a lit surface, not a sum of sparse sprites. **Beaming is downstream of the surface problem (§4d.1), not independent of it.**
🚨 **AND IT IS NOT MINE TO TUNE.** His order 12:26: *"i will create a new preset in the ui at a later point, it cant be constructed from the parameters in the engine rn."* **Brightness/colour is his via presets. Do not touch that block again unasked.** Dead code kept verbatim for whoever revisits it WITH the dials and an opacity floor.

### ~~4c-old. T1 flux normalisation~~ — superseded by the revert above

**His verdict 12:13:** *"why is it also just blue… its still just blue grey ish diamondy."* **This was the predicted failure mode landing.** Raw g³ peaks at 6.4 vs the old law's 1.69, and the absolute luminance scale was tuned for the old peak — so with ~2M sprites under ADDITIVE blending the bright limb saturates locally and washes to white/blue. **Changing the law without changing the exposure it was built for is a photographic error, not a physics one.**

**Cure = exposure, never the exponent.** The azimuthal mean of g³ around a ring is closed-form:
`g³ = (1−β²)^{3/2}/(1−β cosφ)³`, `⟨(1−β cosφ)^−3⟩_φ = (1+β²/2)/(1−β²)^{5/2}` ⟹ **`⟨g³⟩ = (1+β²/2)/(1−β²)`**.
Dividing by it holds the ring's **average** brightness exactly where it was; the full contrast ratio 41× is **redistributed, not rescaled**. Zero free parameters. Peak drops 6.4 → 3.87, trough 0.157 → 0.095.
⚠️ **Assumes edge-on** — the LOS modulation amplitude is |β|·sin(i), so a face-on view is slightly over-dimmed. Revisit only if face-on reads flat.
🚨 **Never restore `DOPPLER_EXP = 1.4`.** If the peak still saturates, the next lever is the tonemap.

### 4d. 🔴 HIS OPEN COMPLAINTS FROM THE 12:13 RUN — not yet actioned

1. ⭐ **"star size is still stars, not smear of stretched light"** + the light-streak reels he attached as reference. **This is the biggest remaining gap and it is BLOCKED, not unsolved:** the streak mechanism is hard-off at `render.metal:1249` and he rejected re-landing it **twice** (2026-07-25 22:26, 2026-07-26 12:35 — *"the entire mechanix is broken and is a relict from very early days… screen-space velocity-stretching of a point sprite is the wrong mechanism for trails, full stop"*). It needs **replacing**, not repairing. Candidate: draw the particle's REAL path segment (`prevW → posW`) as line geometry — that is a true long exposure, not a smeared dot, and it is what the reference photographs physically are. ⚠️ Distinct from the stripped 22-vertex ANALYTIC arc ribbons, which were fake by construction.
2. **"diamondy"** — every particle draws a full-strength 4-point diffraction cross. `starness = (1−elong)/sL`; `sL == 1` (bit18 dead) and `elong ≈ 0` at rest, so the gate that was *meant* to keep the orbiting disk clean (`:2521`) is inert. A brightness gate was added 2026-07-26 and **reverted 2026-07-28 09:31:05** — *"u need to undo more than u did. its still broken."* 🚨 **`:2583`: DO NOT re-add a gate here until the STAR ATTRIBUTE DIALS exist.** So the unblock is **build the dials**, not another gate.
3. **"the accuracy meter is still shaky when blackhole is there"** — HUD stability, uninvestigated.
4. **"still a fake visual not physical overlay"** (lens off `#3` vs on `#4`). ⚠️ Note the parity proof in §2 says the optics ARE real — so this complaint is most likely **1 and 2 wearing a lens costume**: discrete spiking dots on a ring can never read as the continuous surface of pics 10/11, however correct the bending is.
5. **Colour:** *"usually a black hole is reddish blueish, not just blue grey"*. His own `#3`/`#4` are already warm orange, so this is state-dependent, not global. Likely resolves with 4c; re-judge after.

**⭐ PICS 10 + 11 ARE THE TRUTH** (his words): `~/Downloads/BH_optics_explained.jpg` (the NASA warped-optics panel — the parity diagram of §2) and `~/Downloads/Black_hole's_accretion_disk.jpg` (the labelled NASA disk: shadow, photon ring, far-side image, underside image, Doppler beaming). **Those two images name S1/S2/S3/T1 exactly as §0 decomposes them.**

---

## 5. ⚔️ THE CENTRAL DESIGN TENSION — read this before proposing anything

**Sprites give us Chladni structure and 2M-body detail. Only a per-pixel integrator gives S3 and true multi-loop S2. We cannot have both from one renderer, and overlaying them was tried and failed** (two pictures ~100× apart in resolution — *"it doesn't connect to the rings"*).

Three ways out, honestly stated:

- **(A) Stay sprite-native, accept no photon ring.** Fix the lens's two blend sites (§2), fix L1's divisor, add T1 beaming. **Gets: S1 ✅, S2 ✅, T1 ✅, T2 ✅, S3 ❌.** Cheapest by far, and four of five features is already a different-looking hole.
- **(B) A third instance for n = 2.** Extends the sprite scheme by one winding. Cheap to try, gives a *hint* of S3, still not the infinite stack. Cost: +50% on the heaviest pass (L7).
- **(C) Hybrid — march ONLY the thin annulus at the shadow edge** where S3 lives (b ∈ [2.598, ~2.7] r_s), composited under the sprites. Sidesteps L4's resolution mismatch because that annulus has **no Chladni structure to lose** — it is pure lensed light. Needs L9 resolved first and a temperature input to escape the orange.

⭐ **Recommendation: (A) fully, then evaluate (C) with real eyes on it.** (A) is four of the five features and every step is one verifiable change. **Do not open by rewriting the lens** — two of the last three hypotheses on this project were refuted by their own fixes.

---

## 6. 🛤️ THE TRACK — ordered, one verifiable change each

| # | Item | Unlocks | Cost |
|---|---|---|---|
| **0** | ⏳ **His verdict on the §4 capture test.** Everything below stacks on it. | S1 | **0** |
| **1** | **Kill the parity pinch ring** — give the secondary the same `tuneLens · lensRamp · depthMix` factor the primary uses (`:1057`, `:1062`) | S2 clean + honest lens A/B | **S** |
| **2** | **Fix the documented `bhShadowNdcRadius` divisor** (L1). The code already states the correct form and the 2.897× factor. | Lens correct in perspective — **gates A0** | **S** |
| **3** | ✅ **T1 — HONEST BEAMING LAW. SHIPPED 2026-08-14 12:01:52, verdict pending.** See §4b. Was 1/18 of the true asymmetry. 🚨 If the g³ ceiling is ever revisited, the fix is the tonemap — never the fudge exponent. | **The effect Nolan turned off. Nobody has seen it in a movie.** | **done** |
| **3b** | **Gravitational redshift** — the √(1−2M/r) factor of A.16, the other half of g. Deliberately not batched with 3. ⚠️ Reference form is a SINGLE g combining both; do not apply two independent multipliers without checking against A.16. | T1 complete | **S** |
| **4** | **Re-derive L9** — a 40-line offline integrator measuring b_c against 3√3·M = 2.598076. | Makes the march trustworthy again; gates (C) | **S** |
| **5** | **Fix the bit15 double-booking** (L6) — give AMR its own bit. | Every AMR A/B becomes valid | **S** |
| **6** | Evaluate **(C)** — annulus-only march for S3 | S3 | **L** |

**Deferred, deliberately:** Kerr/spin *(DNGR §7.4 — the path is written, the look barely changes at our viewing geometry)*; L5 origin lock (real work, no visual payoff until the hole moves); L2 play-time lensing (regime decision, his call).

---

## 7. ☠️ DEAD ROADS — do not retry

- **The fullscreen geodesic paint / black-disc overlay.** Withdrawn the same day it shipped. A fullscreen multiply after the particles **blacked out matter clearly in FRONT of the hole** — and it cannot do otherwise, because depth WRITE is off for the particles (`renderer.mm:1077`) so no later pass has depth to order against. *"A black circle that overlays in front of everything."* `renderer.mm:3853-3863`
- **The screen-space raytracer shadow.** Deleted 2026-06-28 — a 2D circle sampling no useful disk. `renderer.mm:3911`
- **The march as the hole's renderer.** L4. Settled by A/B 2026-07-26 21:20.
- **The slab-cull exception.** Removed 2026-07-19 17:58 — it carved a straight-edged band across the shadow (*"it looks like a pokeball"*). `render.metal:853-856`
- **The seed billboard.** One ImGui-scale sprite pinned to the 220px cap = *"a yellow thing, unnatural, attached to the black hole, super low-res, tilting with the camera"*. Now stands down once an honest horizon exists. `render.metal:2103`
- **The analytic Ω(r) arc ribbons.** *"Fake trails centered to a tube shape."* Gated `if (false)`. `renderer.mm:3894`
- **`postfx` as the cause of anything.** Ruled out on fps and on star appearance. Never suggest again.
- **Re-centring dilation/lens on `cam.bhX/Y/Z`.** L5 — 4 no-ops logged.

---

## 8. 📐 THE ONE CARD — keep these numbers to hand

    Field units:  r_s = 1.0,  M = 0.5,  c = 1
    Photon sphere:        r = 3M = 1.5 r_s
    Capture / shadow:     b_c = 3√3·M = 2.5980762 r_s      ← the number everything keys on
    Geodesic (a=0, Cart): d²x/dλ² = −3·M(<r)·|x×v|²·x/|x|⁵  = −(3/2)·r_s·h²·x/r⁵
                          ⚠ the (3/2) is NOT (1/2) — the half-value has no photon sphere at all
    Doppler g-factor:     g = (p·u_obs)/(p·u_emit)
    Shifted blackbody:    B_ν(ν, g·T) ≡ g³·B_ν(ν/g, T)      — ONE operation, never both
    Shadow angular size:  sinθ_sh = b_c·√(1−2M/r_c)/r_c  ≈  b_c/r_c
    Time dilation:        dτ/dt = √(1 − 1.5·r_s/r)          — ours floors at 0.4, render.metal:783

---

**Last Updated:** 2026-08-14 01:41:51 (see §0 for the verification stamp)
**Live tree:** `SPACE-SYNTH-TUBE-killtube`, branch `kill-the-tube-2026-08-11`
**Build:** `bash package_macos.sh` — never bare `make`. Launch `--env SS_FULLSCREEN=1`, always.
