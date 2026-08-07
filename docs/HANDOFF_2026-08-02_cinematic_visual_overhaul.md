# HANDOFF — THE CINEMATIC TURN: visual suite to IMAX / planetarium class

**Written:** 2026-08-02 20:16:42
**Baseline:** `b047744` + uncommitted (see §8).
**Hard deadline:** Berlin New Media Week — **first show 2026-09-02**, one month out.

---

## 0. THE DIRECTIVE — read this first, it reorders everything

Jamal, 2026-08-02:

> *"the most important thing for now is that we get it to look amazing on a huge screen in real
> time. so framerate etc can wait. we need sexi cinematic optics. … our entire fx range is super
> shit and hasn't been touched in weeks. … our bloom is shit. our fluidity is shit. and cheap.
> our chromatic aberration is shit. scanlines i don't even know what it does. glitch is ok. but
> kinda shit. we ought to get this into IMAX territory. planetarium visuals with dolby grade
> daft punk class 96k feel sound. meaning. HIGH CLASS. that's not always better at the core but
> it looks better. and that's the only thing we care about from now on."*

> *"collisions … the black hole … the chladni shapes … the star map … everything needs a class
> update to cinematic state of the art art institution lvl"*

**Benchmark named by him: NASA imagery, Cyberpunk 2077, Crimson Desert.** *"we're great. not
insane yet."*

**Consequences for the next session:**
1. **PERFORMANCE WORK IS EXPLICITLY DEFERRED.** The full thermal/perf audit is done and written
   (`docs/AUDIT_2026-08-02_full_codebase.md`) — do NOT act on it yet. Frame rate can wait.
2. **NO UPSCALING. EVER.** He restated it; it is already canon
   (`feedback_never_downscale_resolution`). MetalFX is on the table ONLY for what it does at
   NATIVE resolution (§3.6).
3. "High class" ≠ physically better. His words: *"that's not always better at the core but it
   looks better."* On this track, **the look wins ties against physical purity** — a reversal of
   the usual rule here, and he said it deliberately.

---

## 1. WHERE THE VISUAL SUITE ACTUALLY STANDS — grounded, per effect

Read from `src/render/postfx.metal` and `renderer.mm` on 2026-08-02. His verdicts, with the
mechanism behind each.

### 1.1 BLOOM — *"shit"*. Correct, and here is why.
`renderer.mm:3517-3562`. The chain is: bright-pass (soft-knee, Jimenez-style, with a
`1/(1+luma)` firefly weight — **this part is good**) → **one half-resolution texture** →
**3 iterations of a 9-tap separable Gaussian at radius 2.5**.

**The defect is structural: it is a SINGLE-SCALE blur.** Three passes of a small Gaussian at one
resolution produce a glow with exactly **one characteristic radius** — a modest halo hugging
each bright thing. That is what reads as cheap.

Every modern reference bloom (Jimenez/CoD "Next Generation Post Processing", Unreal, Frostbite)
is a **mip pyramid**: downsample 6–8 times, blur at each level, then progressively upsample and
accumulate. The result is **scale-invariant** — a bright star throws a tight core glow AND a
soft wash across a quarter of the screen, simultaneously. That is the "IMAX" quality he is
describing, and it is *cheaper* than what we do now, not more expensive.

**This is the single highest-value visual change available.** Same bright-pass, replace the
ping-pong with a pyramid.

### 1.2 CHROMATIC ABERRATION — *"shit"*. Correct.
`postfx.metal:160-170`. One radial offset `d * dist * chromaticAmount`, then R/G/B sampled at
three shifted UVs.

That is **2-tap fringing** — the "3D glasses" look. Real lens dispersion is spectral: the offset
varies continuously with wavelength, and cinema lenses show **transverse** CA (grows with
radius, roughly r²) distinct from **longitudinal** CA (defocus varies with wavelength, visible
on out-of-focus highlights). Sampling 3 fixed channels at one offset can only ever look like a
filter.

He also asked earlier (2026-07-29) for CA **per-pixel, "not as an overlay… like sexy"** — i.e.
it should read as an optical property of the whole image, coupled to the lens model, not a
post-hoc smear.

### 1.3 SCANLINES — *"i don't even know what it does"*. There is a real reason for that.
`postfx.metal:412-415`:
```c
float line = 0.5 + 0.5 * sin(in.uv.y * u.resolution.y * 3.14159265);
color.rgb *= 1.0 - u.scanlineAmount * 0.6 * (1.0 - line);
```
`uv.y * resolution.y * π` is **one full sine cycle every 2 pixels — exactly the Nyquist limit,
with no filtering.** On any real display that is not a scanline, it is **aliasing**: it beats
against the pixel grid and produces moiré that changes with window size and resolution. On a
huge screen it will read as noise or as nothing.

**It is not a broken parameter, it is the wrong construction.** A real CRT/anamorphic look needs
a filtered line profile at a *chosen physical scale* (independent of output resolution) with
correct falloff — plus, honestly, phosphor bleed and a slight bloom coupling, or it never sells.

### 1.4 GLITCH — *"ok. but kinda shit"*
`postfx.metal:142-158`. Discrete 14 Hz "glitch frames", banded horizontal RGB displacement,
audio-widened. Structurally reasonable — it is the one effect with a real time base and an audio
coupling. It reads cheap because the displacement is **purely horizontal and purely uniform per
band**; real digital corruption has block structure, quantisation artifacts, and per-channel
timing skew.

### 1.5 "FLUIDITY" — *"shit and cheap"*
This is the trails/motion system, and it is the **worst-documented area with the most dead
code**:
- `trailDecay` — a full-screen feedback fade in postfx.
- **`bit18` (flux-conserving arc) has NEVER EXECUTED** — `sL ≡ 1` for every particle from an
  uninitialised read (`render.metal:1135`, documented, deliberately left).
- The along-motion stretch was **removed** for bit18 and **restored 2026-07-30** (§8).
- `render.metal:1150-1160` carries an explicit REJECTED verdict on the whole mechanism:
  > *"the way that the sprites look now we never ever want them to move — the entire mechanix is
  > broken and is a relict from very early days … screen-space velocity-stretching of a point
  > sprite is the wrong mechanism for trails, full stop. Do not re-land this by fixing details.
  > It needs replacing, not repairing."*

**That verdict is still binding.** Fluidity needs a NEW mechanism, not a tuned one. (Real motion
blur from per-particle motion vectors, or geometry/line-strip trails, are the honest candidates.)

### 1.6 TONEMAP / GRADE — not yet criticised by him, but it is the ceiling on everything

🚨 **CORRECTED 2026-08-03 03:23:43 — this section was WRONG, and acting on it as written would
have destroyed working code.** The original text said the tonemap is "ACES via the Narkowicz
curve fit" at `postfx.metal:67`, and concluded "AgX or a proper ACES pipeline" should replace it.

**`acesTonemap()` at `postfx.metal:67` is not the display transform.** Its only call site is
`postfx.metal:398`, inside the **DISABLED** analytical motion-blur block. It is dead code.

**The LIVE transform is `postfx.metal:296-325`** and it is neither ACES nor a stock curve:
- a **hue-preserving MAX-CHANNEL asinh tonemap** — `tonedMax = hdrPeak · asinh(Q·x)/asinh(Q·R)`
  with `ASINH_Q = 8`, `ASINH_RANGE = 32`, scaling all three channels by `tonedMax/maxc` so the
  hue ratio is exact and the brightest channel never clips;
- plus a **SENSOR BLEACH**, `smoothstep(3,8, log2(over))`, so only truly nuclear cores burn to
  white.

Both were built directly from his verdicts over several sessions — *"the ugly white"*, *"still
the ugly ass yellow"*, *"only white or orange / a supernova has so much more variety"* — and the
asinh log tail exists specifically because **ACES's hard shoulder crushed every internal
gradation together** (that was the "flat blur"). Ripping this out for AgX would be a rewrite that
throws away hard-won, verdict-backed work (`feedback_dont_pitch_rewrites`).

**What is ACTUALLY missing is still true and still the ceiling:** there is **no grade/LUT stage
and no white-point control** (the only grade is the hardcoded `neonGrade` synth-palette remap at
`:332`). The honest item 2 is therefore **ADD a 3D LUT grade stage after the existing tonemap**,
following the `spectral_lut.h` shared-bake pattern (§1.7) — **not** replace the transform.

### 1.7 WHAT IS ALREADY GOOD — do not "fix" these
- **The bright-pass** (soft knee + firefly weight) is correct and modern.
- **The blur is separable** and ping-pongs correctly — the right primitive, wrong topology.
- **HDR RGBA16Float throughout** the offscreen chain.
- **The blackbody/Planck colour law** is now unified and physically real (§8) — the colour
  *source* is good; what is missing is the *optics* on top of it.
- **`spectral_lut.h` is shared by the shipped bake and the offline verifier** so they cannot
  drift. Copy that pattern for any new LUT (a grade LUT, a lens LUT).

---

## 2. THE OTHER HALF — the things that are not postfx

He was explicit that this is not only a post pass: *"that includes how our stars look before fx
yes. but also what post does."* Four subjects named:

### 2.1 STARS (pre-FX)
The known blocker is measured and severe: **99.2% of all stars land in the 0.92–1.41 px bin, and
they are not spread across it — they are PINNED to `STAR_MIN_PX` by a `max()`**
(`render.metal:1705-1715`, `[KPROBE-SCALE]` 2026-07-28). The comment records the irony: the
previous saturation-PSF law was removed *because* it put "99.9% of stars at exactly 1px" and
Jamal said *"all stars weirdly the same size"* — **the floor reintroduced the identical
condition through a different door.**
A 1 px sprite cannot carry hue and cannot show a core. **Star rendering cannot look cinematic
until this is fixed.** See `docs/HANDOFF_2026-07-28_stars_lens_and_todos.md` and the memory
`STARS ARE UNDIALABLE` — 4 attempts, 0 progress, all reverted; **build the dials first**.
🚫 **POSTFX IS RULED OUT for star colour** — he ran the N/B keys. Never propose that test again.

### 2.2 THE BLACK HOLE
His verdict 2026-08-02: *"the black hole barely functions and doesn't feed fast enough."*
Not investigated. Canon that constrains any work here:
- **The BH IS the particles, never a shader** (`space_synth_bh_core_directive`).
- **Shadow = ABSENCE, never paint** (2026-07-24) — remove light at the source.
- **No second layer** — no overlay disks/glow/starfield (`feedback_no_second_layer`).
- **The sprite lens (bit8) is the hero, not the march** (2026-07-26).
- Open blocker from 07-26: matter collapses torus meanR 33 → ball 3.9.

### 2.3 THE CHLADNI SHAPES
Two render regressions found and fixed 2026-07-30 (§8); his verdict then was *"sort of.
kindaaaa"* — improved, not yet the reference. **The reference is the 2026-07-18 build
(`0edde58`)**: *"DO U SEE THE LVL OF DETAIL IN THIS … harry potter vs voldemort wand flashes,
which was the reference."*
⚠️ **`docs/AUDIT_2026-07-29_chladni_3d_correctness.md` IS WRONG AT ITS ROOT** and should be
deleted or prefixed with a retraction — it argues the blur is structural/geometric, which the
07-30 session disproved by building the old commit. **Do not let it mislead a future session.**

### 2.4 COLLISIONS
Named by him for a class update; not investigated. `MASTER BACKLOG` has "collisions POP into BH"
as a long-standing item.

---

## 3. THE METAL / macOS QUESTION

**Verified 2026-08-02:** this machine runs **macOS 27.0 (build 26A5388g)**, and
**`MetalFX.framework` is present** in `/System/Library/Frameworks/`.

### 3.1 What MetalFX offers, against his "no upscaling" rule
- **Spatial / Temporal upscaling — REJECTED by standing rule.** Not negotiable, do not propose.
- **Temporal AA at native scale (1:1)** — this is the part worth considering. A temporal scaler
  configured with input = output resolution is, in effect, a high-quality TAA. On a huge screen,
  **2M sub-pixel particles alias and shimmer**, and that shimmer is a large part of what reads as
  "not cinematic". This is the one MetalFX feature that fits both his rule and his goal.
- **Frame interpolation** — irrelevant while perf is deferred, and risky for a live instrument
  (latency).

### 3.2 ⚠️ THE HONEST BLOCKER ON TAA
MetalFX temporal needs **per-pixel motion vectors and depth**. We have **neither**:
- Nothing writes depth anywhere (`depthWriteEnabled = NO` at both states, `renderer.mm:931,940`).
- There is no motion-vector target at all.
Worse, TAA on a field of independently-moving points is exactly the case TAA handles *badly* —
it smears or ghosts unless the vectors are right. **Motion vectors would have to be built first**
(we do have per-particle velocity, so it is feasible), and **they are ALSO what a real motion
blur needs (§1.5).** That makes a motion-vector pass the shared prerequisite for the two biggest
"cinematic" wins. **Measure and prototype before committing.**

### 3.3 Other native options worth evaluating
- **MPS / MetalPerformanceShaders** ships optimised Gaussian and image kernels — a legitimate,
  well-tested foundation for the bloom pyramid.
- **`MetalPerformancePrimitives.framework`** is present (newer); unassessed.
- **Order-independent transparency** is a non-issue for us — additive blending is
  order-independent by construction. Do not "fix" it.

---

## 4. THE UI TRACK — parked, unchanged

Full state: `docs/HANDOFF_2026-07-29_nasa_ui_design.md` and
`docs/HANDOFF_2026-07-29_ui_parallel_track.md`. Jamal deferred it 2026-07-29: *"okay fuck that
mechanics first then ui."* **Net code change from that track: ZERO.**

- **The ethic outranks everything:** *"A GRATEFUL NOD TO THE GREATS … I LOVE SAMPLING. and even
  more .. flipping samples."* THE TEST: **for every number on screen, name why it is that
  number.** Unjustified defaults are simultaneously the AI tell and the theft tell.
- **A1 — `THIRD_PARTY_LICENSES.md` is still owed** (ImGui MIT, Roboto + Cousine Apache 2.0,
  Syphon). Vendored fonts ship without upstream licence text. Zero pixels, no verdict needed.
- **The accent must be DERIVED** from the blackbody locus in `render.metal` — green and violet
  are provably unoccupied by the Planck locus. *"we have all the answers to that in the code u
  don't need to see what's on screen it's all science bro."*
- **B1** (accent-alpha interaction states) written and fully reverted; never evaluated.
- The known AI-looking artifact is named: `ui_theme.h` `ApplyPremiumTheme`, *"Ultra-Premium
  Design Colors"*, 14px rounding, white-alpha everything.
- ⚠️ **NASA insignia/worm/seal — 14 CFR 1221, never use.** Everything else is §105 public domain
  or Apache/OFL.

**Note the collision with this handoff:** a cinematic visual pass and a HUD redesign both change
what is on screen. **MEDS rule (from the NASA research): never change layout and visual language
in the same build.**

---

## 5. THE SOUND TRACK — designed in full, ZERO code written

Full spec: `docs/DESIGN_2026-07-28_field_sonification.md` (v2) and
`docs/HANDOFF_2026-07-29_sonification.md`. His framing is the same "high class" bar — *"dolby
grade daft punk class 96k feel sound."*

**The architecture he chose (B): the field IS the sound source.**
> *"The sim sounds whether you play or not… like a meditation tool if u dont play it. like an
> everplaying song."* · *"the shape is the sound"* · *"2 mio oscillators / voices with their own
> property. pausable. i want to eventually pause the simulation and click on a star. solo it."*

**The governing principle — do not invert it:**
> **Define the per-particle voice FIRST. The ensemble sound is the SUM of those voices. Any
> binning or grouping is an OPTIMISATION of that sum, justified against it.**
Solo = the same law at N=1, free. Inverting (histogram first) makes solo impossible.

**Settled numbers:**
- `f_audible(r) = 2^16 · √(GM/r³) / (2π · 5.854202 s)` — uniform transposition, every ratio
  preserved. This is NASA's actual published method (Perseus, 57–58 octaves).
- Disk spans **3.9–4.3 octaves natively**; ISCO ≈ 294 Hz; 20 Hz rhythm/pitch line at r ≈ 14.85.
- **pan = θ → shape IS the stereo image**; mono bass EMERGES below ~120 Hz (r ≈ 4.4).
- **amplitude = EMISSION, not mass** — `ssDiskTempShape` already exists at `render.metal:213`.
  The mix balance is thermodynamics.
- **The resonator is κ(r) = ω√(1 − 6GM/r)**, which vanishes exactly at ISCO — *that* is the
  eerie, and it is exact GR. κ peaks at r = 8GM where ω:κ = 2 (an octave); 3:2 at r = 4.453 —
  **observed in real black holes** (GRO J1655−40 et al.).
- **Phase already exists**: `posePhase[]` = ∫ω dt (`render.metal:383`). ⚠️ do NOT confuse with
  `velW.w` (= ∫|v|dt, path length, WRONG for audio).
- **The BH is SUBTRACTIVE — it eats the treble first.** Accretion is a low-pass closing over time.

**NEXT STEP IS UNCHANGED: §14 step 1 — MEASURE N.** 2M oscillators at 48 kHz ≈ 10¹¹ ops/s,
bandwidth-bound, **unmeasured**. It is a number, not a verdict. Everything downstream depends on it.

**REJECTED, do not revive:** a second sound layer; radius-only binning (cannot hear shape); mass
as amplitude (mud); linear frequency shift (breaks every ratio); a scan direction; hardcoding κ
as a tone (that is painting the resonance).

---

## 6. THE AUDIT — done today, DEFERRED by his instruction

Full document: **`docs/AUDIT_2026-08-02_full_codebase.md`**. Static read of all 22,522 lines plus
a clean build for warnings. **Do not act on the performance items yet.** The three that are NOT
performance and are stage-critical:

1. ⭐⭐ **The real-time audio callback takes a BLOCKING mutex.** `synth.cpp:91` —
   `lock_guard(queueMutex_)` on the RT thread, four lines above a comment correctly explaining
   why `mutex_` uses `try_to_lock`. Main-thread note-on/off contention → underrun → **audible
   dropout on stage.** One-word fix. **This is the highest-risk item for the show.**
2. **Pause does not reduce GPU load at all** — `simPaused` never gates any dispatch.
3. **CVDisplayLink is deprecated as of macOS 15** and drives every frame. This machine is on
   macOS 27. **Freeze OS updates on the show machine** — zero code, pure risk removal.

Also found (detail in the audit): fill rate is ~338 M fragments/frame (~40 G frag/s at 120 Hz) —
**that is the heat, and it is quadratic in sprite size**; a 227-line dead `render()` overload;
`assign_cells` compiled + null-checked but never dispatched; an orphan `orbit_substep` pipeline;
an unreachable block gated on `bhDiskAxisY > 0.5` (assigned 0.0 at all seven sites); 32 MiB/frame
of buffer zeroing over a 128³ grid that is mostly empty.

⚠️ **Correction recorded:** the audit first said "no depth test". **Wrong** — there IS a depth
buffer and a `Less` test; what is disabled is depth *write*, at every state, so nothing ever
occludes anything. That is CORRECT for additive emissive particles (`renderer.mm:930`) and must
not be "fixed" — but it is why fill rate is unavoidable: we have deliberately opted out of the
one mechanism that makes rendering sublinear in overdraw.

---

## 7. RULES EARNED — do not re-litigate

- 🚫 **DO NOT SECOND-GUESS HIS CLAIMS. AT ALL.** His report is the datum; build on it, never test
  it. Two failures on 2026-07-29/08-02 (checking logs after he said PM gravity did nothing;
  hypothesising uniform temperature right after he sent a screenshot proving colour variety).
  Now in the protocol and in memory.
- **When something "used to be" better, BUILD THE OLD COMMIT AND LOOK.** This is the only method
  that produced results on 2026-07-30 — two real regressions found in ~15 minutes after hours of
  theorising. `git worktree add <path> <sha>`, symlink `third_party`, `mkdir build`,
  `bash package_macos.sh`.
- **Never test on C** — `m = midi % 12`, so C is m=0, **zero angular force, concentric rings by
  construction, in every octave.** This has silently invalidated an unknown number of past A/Bs.
- **A comment in this codebase is a historical record of an INTENTION, not a description of
  behaviour.** Five confirmed instances (audit §2.8). Verify the consuming code.
- **Announce → END THE TURN → wait.** Narration is not a checkpoint.
- **Assume a second window.** Never `pkill` / build without asking; one bundle, shared.
- **Build with `bash package_macos.sh`, never bare `make`**; verify bundle timestamps ≥ source.
  "Change did nothing" → suspect a STALE BINARY FIRST.
- **POSTFX IS RULED OUT for star colour.** Never propose that test again.
- **No upscaling, ever. No second layer. Shadow = absence. The BH is the particles.**

---

## 8. LIVE STATE — 2026-08-03 04:29:24

Still on `b047744`, **nothing committed this session** (`feedback_commit_only_on_explicit_order` —
past permission is not standing permission; he has not asked).

Modified: `src/core/app_state.h`, `src/main.cpp`, `src/render/particles.metal`,
`src/render/postfx.metal`, `src/render/render.metal`, `src/render/renderer.h`,
`src/render/renderer.mm`, `src/render/spectral_lut.h`.
**New and untracked: `src/render/grade_lut.h`** (plus every `docs/` file from 07-28 onward).

Build/deploy verified this session: bundle `04:25:31` ≥ every source. Build is clean of new
warnings; the 32 pre-existing ones are inventoried in §10.

**Landed and verified on screen this session (2026-07-30 → 08-02):**
| change | file | verdict |
|---|---|---|
| Play-phase **gas splat disabled** (was ×3 size, ÷9 luminance, falloff 5.0→1.2 on ~90% of particles) | `render.metal` | *"sort of yeah kindaaaa"* |
| **Along-motion stretch restored** `lengthX = mix(1,5,elong)` (removed for the never-executing bit18) | `render.metal` | with the above |
| **Case B line strengths** Hα 2.86 / [OIII] 3.00 / Hβ 1.00 (were 1,1,1 = spectrally flat = grey) | `spectral_lut.h` | verified by `[SPEC-LUT]` |
| **`LINE_FRAC_MAX = 0.5`** — lines may equal but never replace the continuum (at s=1 every mass returned ONE hue) | `render.metal` | colour variety returned |
| **UNIFIED KELVIN LAW** — one `unifiedKelvin()`, both consumers (they had forked: hardcoded vs dialed A/p, different mass bounds, heat pedestal in one only) | `render.metal` | — |
| **`uiHeatGain` 3000 → 0** — `clamp(temp,0,5)` saturates at play = flat **+15,000 K** on every particle = white | `app_state.h` | fixed *"white f"* |
| **`uiColorTempK` 27000 → 0** — `\|v\|²` is kinetic energy, a heat term in velocity clothing | `app_state.h` | — |
| **Logarithmic faders** on Colour Spectrum + Plasma Heat (Kelvin↔colour is log; the LUT is log-spaced) | `main.cpp` | pending his values |
| `[GRIDPROBE]` read-only occupancy probe | `renderer.mm` | measurement only |

**Landed and verified on screen 2026-08-03:**
| change | file | verdict |
|---|---|---|
| **BLOOM → MIP PYRAMID** (§9 item 1). Bright-pass unchanged; the 3×(H,V) single-scale ping-pong replaced by a derived-depth pyramid (halve while min dim ≥ 8 px; 6 levels at 640×400), 13-tap partial-box down, 3×3 tent up, additively accumulated | `postfx.metal`, `renderer.mm` | *"this bloom is looking a lot better"* — still noisy from the small stars, **deferred by him** (that is §2.1, stars pinned to 1 px) |
| **RINGS BUG SOLVED** — `cam.envelopePhase < 0.5f` added to both BH pose gates (`render.metal:473` advance + `:523` apply) | `render.metal` | *"yes rings fixed"* |

**THE RINGS ROOT CAUSE — the weeks-old bug, do not re-derive it.** `particle_vertex` rotates every
particle's **rendered** position about the hole by `posePhase[vid]` at `√(GM/r³)·t_dil` —
**radius-dependent, i.e. DIFFERENTIAL rotation**, which shears every m≠0 Chladni lobe into a
concentric ring and smears it. `bit20` is DEFAULT ON and `bhDiskGM` never returns to 0 once a hole
forms, so **from the first BH onward the render spun the field through every subsequent note.**
His trigger — *"after black hole first formed and i play again"* — was the discriminator that ruled
out every note/physics theory. **A render-only transform masqueraded as a physics bug for weeks:
check what the render does to the positions BEFORE touching the physics.**
⚠️ Not closed by this: the separate blur causes in `HANDOFF_2026-07-29_chladni_audit.md`
(`ridgePull` on the sculpt gradient; no node dissipation) — untouched, no verdict.
⚠️ Unverified: whether the gate SNAPS at note-on/release. Ready follow-up = use the eased
`renderPhaseSmooth` as a 1→0 **blend** on the applied phase instead of a threshold (no new uniform).

**BUILT 2026-08-03 04:25:31. ✅ APPROVED BY HIM 2026-08-03 04:34:56 — "this is really nice
actually i like it a lot" — §9 item 2, the DISPLAY GRADE LUT.**
New file `src/render/grade_lut.h` (bake) + a `texture3d` stage in `postfx.metal` between the
tonemap/bleach and `neonGrade`, 33³ RGBA32F bound at `texture(4)` on BOTH the screen pass and the
Syphon feed, dial `uiGradeAmount` → slider **"Grade LUT"** under Neon Grade in the FX panel.
**Default 0 = exact bypass**, so the stage ships proving it changes nothing until he dials it.
- Verified OFFLINE before shipping (`scratchpad/grade_check.cpp`, same header the app links):
  void → `(0.0150, 0, 0.0300)`; faint red star, faint blue star, [OIII] green, mid-grey and white
  **all exactly identity**. Only neutral pixels move.
- **✅ SEEN AND APPROVED 2026-08-03 04:34:56.** He dialled the slider up and liked it. The stage
  and its derivations are verdict-backed now — treat the violet-toe grade as APPROVED WORK and do
  not replace it; tune only on his order.
- Derivations (his test — every number must have one): **33** = 2⁵+1 so the grid hits 0.0/0.5/1.0
  exactly; **hue 280°** = the only arc neither the Planck locus NOR the supernova emission lines
  occupy (⚠️ see §1.6 — "green is unoccupied" is TRUE ONLY of the blackbody law, [OIII] green is
  the play state's physical tell); **lift 0.03** < sRGB's 0.04045 linear-segment threshold, so the
  tint cannot leave the display's defined toe; **chroma gate** because a faint star is dim but not
  neutral — luma alone is not a test for "is this matter", and a normal toe grade would tint every
  faint star off its true hue.

**Awaiting from him:** the Colour Spectrum / Plasma Heat values he wants baked as defaults.

**Reverted, no verdict, do not resurrect without measurement:** ridgePull→eigenmode gradient;
node braking ∝|Ψ|; condense gain 8→1; B2 rest gate. All four were mechanism-first guesses.
**Exonerated by A/B:** jitter, PM gravity.

---

## 9. THE ORDER — he approved it 2026-08-02: *"we follow paragraph 9"*

Progress marked as of 2026-08-03 04:29:24.

1. ✅ **Bloom → mip pyramid** (§1.1). **DONE, verdict *"this bloom is looking a lot better"***.
   Residual noise from the small stars is item 3 and he **deferred it explicitly**.
2. 🔨 **Grade stage** (§1.6) — **BUILT 04:25:31, NOT SEEN, no verdict.** Needs a relaunch. ⚠️ Read
   the §1.6 correction first: this is an ADDED LUT stage, **not** a replacement tonemap.
3. ⬜ **Star size floor** (§2.1) — nothing pre-FX can look cinematic while 99.2% of stars are
   pinned to one pixel, and it is the source of the bloom noise he accepted for now.
   **BUILD THE DIALS FIRST** — 4 previous attempts, 0 progress, all reverted.
4. ⬜ **Motion vectors** (§3.2) — the shared prerequisite for real motion blur AND any TAA. Do
   this before touching "fluidity", which he has already rejected as a mechanism.
   ⚠️ The real blocker is not the missing texture: additive blending with depth-write OFF means
   nothing decides which of the dozens of overlapping particles OWNS a pixel's vector. That needs
   a separate winner-take-all pass, and it is a design decision, not plumbing.
5. ⬜ **Chromatic aberration → spectral/lens model** (§1.2).
6. ⬜ **Scanlines — rebuild or remove.** Currently a Nyquist-rate sine with no filtering; on a huge
   screen it is aliasing, not an effect.

**Also open, outside the §9 order:**
- The **22-warning inert sweep** (§10.3). He asked for it, it is not started, and he wants the
  warning count at zero. `render.metal:485` (§10.1) is the one that needs real thought.
- Whether the rings fix **SNAPS** at note-on/release (§8). Ready one-line follow-up on file.

---

## 10. BUILD WARNINGS — 32, inventoried 2026-08-02 20:44:01

His bar: *"we shouldnt have any warnings u know lol"*. Measured by forcing a full recompile
(`find src third_party/imgui -type f \( -name "*.cpp" -o -name "*.mm" -o -name "*.metal" -o
-name "*.h" \) -exec touch {} +` then `bash package_macos.sh`).

⚠️ **An incremental build hides 30 of the 32** — it only recompiles the TUs you touched. The
2026-08-02 bloom build showed 2 warnings and looked clean. **Always force the full recompile
before claiming a warning count.**

### 10.1 🚨 THE ONE THAT IS NOT COSMETIC
`render.metal:485` — **"writable resources in non-void vertex function"**. `particle_vertex`
returns `VertexOut` *and* writes `device atomic_uint* kProbe [[buffer(9)]]`. Metal does not
guarantee buffer writes from a vertex function that returns data; invocations can be re-executed
or discarded.

**This is the construct that produced the `[KPROBE-SCALE]` "99.2% of stars in the 0.92–1.41 px
bin" figure quoted in §2.1.** His verdict — stars are pinned, all the same size — is his and
stands (§7, do not second-guess his claims). The *percentage* was collected through a flagged
construct. **Fix it properly** (move the probe to a compute pass, or a `void` vertex pass);
**never silence it.**

### 10.2 ⚠️ DO NOT DELETE `ssDiskTempShape` (`render.metal:213`)
It warns as an unused function. It is **not** dead code — §5 names it as the existing emission
shape that `amplitude = EMISSION, not mass` depends on. It is a hook whose consumer is not
written yet.

### 10.3 The inert sweep — 22 warnings, zero behaviour change
- `particles.metal` (7): `BH_M`, `SCHWARZSCHILD_RS`, `ORBIT_R_BH`, `dir`, `diskThickness`,
  `distFromDisk`, `ecount`
- `render.metal` (11): `kBandColors`, `DISK_T_STAR_K`, `HEAT_K_PER_T`, `PEAK_KELVIN`,
  `SN_TEMP_PEAK`, `SPIN_VEL_SCALE`, `heatRamp`, `gravShift`, `bClamped`, `rSim`
  (+ `ssDiskTempShape`, **excluded** per §10.2)
- `renderer.mm` (2): `:1111` sign-compare (`size_t` vs `int`); `:3155` `bestCid` set-but-unused —
  a leftover of the **ORIGIN LOCK**, which pinned `bhPos` to 0/0/0 and stopped consuming the peak
  cell id.

Doing this sweep takes the build from 32 → 10.

### 10.4 The remaining 9 are migrations, not warning fixes
- `src/ui/window.mm` (7): every `CVDisplayLink*` call, deprecated in macOS 15; this machine is on
  27. This is §6 risk item 3 — a migration to `NSView.displayLink`, **not** cleanup.
- `third_party/imgui` (3): `__bridge_retained` / `__bridge_transfer` are no-ops without ARC →
  the ImGui font-atlas texture leaks (once, bounded — audit §2.10). Fix = compile those two files
  with `-fobjc-arc`. **Never edit vendored code.**

---

**Last Updated:** 2026-08-03 04:34:56

**NEXT, IN ORDER:**
1. ~~Show him the "Grade LUT" slider~~ — **DONE, APPROVED 2026-08-03 04:34:56.**
2. §9 item 3 (star size floor) or the §10.3 warning sweep — his call.

Performance work stays deferred until he lifts it. **Nothing is committed; do not commit without an
explicit order.**
