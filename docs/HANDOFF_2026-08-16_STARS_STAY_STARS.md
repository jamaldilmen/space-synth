# ⭐ STARS STAY STARS — handoff 2026-08-16 16:42:00

> **His verdict on this state: "NOW WE ARE TALKING BABY".**
> Previous handoff: `HANDOFF_2026-08-15_UNIFIED_PHYSICS.md`. Read that one first
> for the principle; this one is what closed on top of it.
> **Cold start for the hole is still `docs/BOARD_BLACKHOLE.md`.**

**Tree:** `SPACE-SYNTH-TUBE-killtube`, branch `kill-the-tube-2026-08-11`.
Build `bash package_macos.sh`, launch `--env SS_FULLSCREEN=1`, always.

---

## 0. THE PRINCIPLE, UNCHANGED

One quantity, one law. A second copy of a law is a second universe laid over the
first, and the screen shows the seam. Everything below is one more face of that.

**The new lesson this session, and it is the reusable one:**

> **The same wrong geometry has WILDLY different tolerances in different passes.**
> An arc sweeps ≤ `tuneArcWrap` (2.2 rad), so a bad axis only *bends a ribbon*.
> The playback rotates by the accumulated phase, which wraps the full 2π, so the
> *same* bad axis **teleports the star anywhere on its circle**. Never move a
> geometry from the trail to the motion without re-checking the tolerance.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where |
|---|---|---|---|---|
| **S3a** | **The trail had no clock** | `TRAIL_EXPOSURE·(1+4·osc+gain·bh)` — a bare constant, no time term, in no unit. Full length on the first frame | Shutter = `0.35 × T_ISCO` (from `r_isco = 3r_s` and `bhDiskGM`), then `min(shutter, bhPoseTime)` — it cannot expose longer than the hole has existed, so the ribbon grows in | `render.metal` trail shutter block |
| **S3b** | **The trail was not attached to its star** | `particle_vertex` moves every sprite by `posePhase` (:612-618); the arc pass bound only particles+camera, so it drew from the RAW physics position. Sprite and trail were in two frames **separated by a phase that wraps the full circle** | Arc binds the same `posePhaseBuffer` (`renderer.mm`, index 2) and applies the same rotation. His *"straight lines disattached flowing around"* — literally true | `render.metal`, `renderer.mm` |
| **U6** | **Ω had a THIRD law** | sprites+ray-march used `poseOmegaEff` (physical GM); Doppler+arcs used `1/(r^1.5+KERR_A)`. U1 unified arcs↔Doppler but never reached the **playback**, which is the law the star is actually MOVED by | Arc uses `poseOmegaEff` when the playback drives; geometric law kept only for the no-hole osc branch | `render.metal` |
| **U7** | **The playback spun the whole field about global +Z** | Right for the 75% disk, wrong for the rest — the 5th sighting of the 90°-off-plane fault | Every star turns about its own orbit normal, `poseAxis` | `render.metal` `poseCentre`/`poseAxis`/`rotAboutAxis` |
| **U8** | **Membrane test compared a CYLINDER to a SPHERE** | `rxy <= horizonR` with cylindrical `rxy` | Spherical `|r − c|`. Matter merely *beside* the hole was being frozen | `pose_phase_advance` |
| **S6** | **The track was a RAIL, not a spiral** | Rodrigues preserves `\|r\|` exactly ⟹ `dr/dt ≡ 0`. A closed circle **by construction** — no colour/exposure/plane change could ever read as accretion because nothing fell in | α-disc drift `v_r = α(h/r)²v_φ` ⟹ time cancels ⟹ `r(φ) = r₀·exp(−α(h/r)²φ)`, a log spiral, pitch **0.05565** | `SPIRAL_PITCH` |
| **S7** | **THE BIG ONE — the trail had NO luminosity term** | `intensity = fade·innerFade·expNorm·tuneTrailGain`. The arc took the star's COLOUR but **not its BRIGHTNESS**, so all 1.5M particles drew an EQUALLY BRIGHT ribbon | Ribbon carries the star's own `L = M^tuneStarLumExp` (sprite law `:1906`, `:2197`), referenced to 1 L☉ | `render.metal` trail intensity |

**S7 is the one that produced "NOW WE ARE TALKING".** The mean particle is
0.297 M☉ — invisible as a point — and it was drawing the same strength streak as
a giant. Millions summed additively into the orange curtain. **The curtain was
the field's INVISIBLE stars made bright**: the stars you could see stayed sparse
points while the stars you could not see became the picture. That is exactly what
he named — *"NOT STARS EXCHANGED FOR ORANGE TRAILS"*.
A long exposure does not create light, it redistributes light a body already
emits. Cost, as predicted and accepted: **~70× less trail light**, so
`tuneTrailGain` (Trail Brightness) is now a real exposure control.

### ⛔ DEAD ROAD, recorded so it is not retried
**`L̂ = r × v` as the playback axis — REJECTED ON SIGHT 2026-08-15 03:28:47.**
The disk was destroyed; the field scattered onto a few bright great circles.
`r × v` is the orbit normal **only for a clean circular orbit**, and this field
never has one — not because of the collapse, but because it is contaminated **at
spawn**: `particles.cpp:268-270` adds `sig*gauss` to `vx, vy, vz`, and `:272-273`
scales `vx,vy` by `(1+ecc)`.
**The axis the spawn actually hands us needs no velocity at all.**
`particles.cpp:260-262` sets `vx = −vmag·y/|xy|, vy = +vmag·x/|xy|, vz = 0`,
i.e. `v ∝ ẑ × r`, so the launch orbit normal is a pure function of POSITION:
`r × (ẑ × r) = ẑ|r|² − r·z ∝ (−zx, −zy, x²+y²)` — smooth, noise-free, coherent
between neighbours, and exactly `+Z` at `z = 0` so the disk is untouched.
⚠️ **Honest limit:** that is the normal of the orbit a star was *launched* on, not
the one an evolved star is on. It is a coherent field, **not a conserved
quantity**. A conserved axis means carrying spawn L̂ per particle in the buffer —
a spawn + buffer change, not a render one. **If the rings drift or shear over
minutes, this limit is what is showing.**

---

## 1b. ⭐ STEP 1 FOR THE BH BOARD — THE COLOUR OF THE GAS (his order, 2026-08-16)

**His question, and he was right to forbid assuming:** *"around a bh is super hot
gas correct. what color does it have. dont assume, look at the nasa ref."*

**THE REFERENCE, read directly:** `~/Downloads/BH_labeled.jpg` — NASA/Goddard
(Schnittman), the labelled one. Also on disk: `BH_optics_explained.jpg`,
`Black_Hole_Desktop_&_Phone_Wallpapers_(SVS14146_-_BH_accretion_disk_viz_desktop).png`,
`Black_hole's_accretion_disk.jpg`. **Look at the file, do not recall this from
memory.**

**What it actually shows:**
- Disk is **deep red at the outer edge → orange through the body → yellow-white
  at the inner edge**, brightest on the Doppler-boosted approaching side.
- **Black hole shadow: "roughly TWICE the size of the event horizon."**
- **Photon ring**: a thin bright ring at the shadow's edge, made of light that
  orbited 2–3+ times; *"thinner and fainter closer to the black hole."*
- Named features it labels, i.e. the acceptance list: accretion disk, Doppler
  beaming, photon ring, shadow, **image of the disk's far side**, **image of the
  disk's underside**.

**WHY OURS IS BLUE-GREY, AND IT IS NOT A PALETTE BUG.** Our field is **STARS**.
S7 correctly weighted trails by `L = M^3.5`, which selects hot massive stars, and
hot stars are blue-white. A real black hole is wrapped in hot **GAS**, and the gas
is what carries the orange. So *"only white giants create trails → blue-grey
ring, not colourful"* is not a bug in S7 — **it is the render telling us the
scene is made of the wrong material.** Do not fix this with a palette; that is
the banned second layer, and it is what the "orange hair" private ramp already
was (deleted 2026-08-14 18:02:17).

⚠️ **The honest tension to resolve, not paper over:** our own HUD reads
`Plasma T (mean) 5.37e+10 K`, `inner 2.04e+12 K`. A blackbody at 5e10 K does not
emit visible orange — it is deep X-ray. So the NASA image's colour is a *transfer*
of the disk's thermal structure into the visible, not a literal blackbody at the
gas temperature. **Any colour we adopt must therefore carry a STATED derivation
and a stated mapping** — his standing rule that every number on screen has a
derivation — and it ties straight to open item **S1 (Temperature)**, where three
different temperature scales already disagree.

**So step 1 is not "make it orange". It is: decide what emits.** Either the gas
becomes a real emitting component with its own derived transfer, or the stars stay
the only emitters and the scene keeps telling the truth that it is a star field.

---

## 2. 🚨 HIS OPEN LIST — verbatim, 2026-08-16 16:39

0. **🆕 SMEAR WHEN THE CAMERA MOVES (2026-08-16 17:13:47).** His words: *"theres
   a weird smear when i move cam, can even see it in picture, like uhrzeiger
   straight lines that create blurr."* Visible as clockwise/tangential straight
   streaks over the whole field **in a PAUSED frame**, which is the clue: the
   physics is frozen, so whatever draws them is on the RENDER clock, not the sim.
   **Undiagnosed. Do not guess between these — measure.** Candidates, in order:
   (a) the post-fx frame-feedback / `trailDecay` accumulation buffer, which is
   screen-space and will smear anything when the camera moves; (b) the arcs
   themselves, drawn from a world-space `posePhase` that keeps advancing while
   paused (`emergentPoseDt` has a `pauseHoldTimelapse` argument — check whether
   the pose clock is still running); (c) the `spinAngle*tDilate` shear in
   `particle_vertex`. **⚠️ 95 fps was read off this PAUSED frame — it is NOT a
   measurement of the light cull's benefit. Re-measure while running.**
1. **FPS DUMPING HARD.** 14 fps in the screenshot. Known and documented at the
   `rXY > 8` cull removal: 1.5M particles × 22 line-vertices = **33M line-verts**
   per frame. The standing instruction there is *cap `arcParticles`, do NOT
   reinstate a radius cull and do NOT shorten the ribbons.*
   ⭐ **S7 opens a better door: a ribbon whose `Ltrail` is negligible emits
   nothing and can be skipped. That is a LIGHT cull, not a radius cull — free,
   and physically justified rather than a budget.**
2. **"only white giants create trails → blue-grey ring, not colourful."**
   Correct, and it is S7's own selection bias: `L = M^3.5` means only hot massive
   stars survive the luminosity weighting, and hot = blue-white. The field's
   colour range is real but it lives in the dim red population that now
   (correctly) does not streak. **This is the trade S7 made; it is his call
   whether the exponent or the reference should move.**
3. **`[accuracy] clamped kicks: 2216 (0.11%)` in hard red.** Untouched,
   undiagnosed this session.
4. **Phase Viz does nothing once the BH exists — "but it should".** Untouched.
   Suspect a gate mirroring the `envelopePhase`/bit20 play-gate stack.
5. **"still faking it with the lens… like Saturn rings, not like a BH."**
   THE standing goal. Ties directly to `BOARD_BLACKHOLE.md` and to the older
   `space_synth_lens_is_a_plate_2026-08-13` insight (we bend the IMAGE like a
   glossy plate; a real lens bends the LIGHT).

---

## 3. ⏳ STILL OPEN FROM THE PREVIOUS HANDOFF

- **S1 Temperature** — HUD prints 4.06e10 K "real virial temperature"; colour
  uses `unifiedKelvin` clamped to 40,000 K; a third scale in `physics_constants.h`.
- **S2 The hole's mass** — `49.97 M☉` (biggest particle) vs `1.177e5 M☉` (mass
  inside the horizon), **both [LIVE], same panel**. Screenshot now reads
  53.76 vs 1.841e5 — same split, still 3400× apart.
- **S4 The trail has no depth** — only the hole writes depth; arcs and stars are
  orderless additive. **Not closed.** S7 reduced the symptom by removing light
  that was never earned, but the ordering is still absent.
- **S5 Presets cannot save the look** — `struct Preset` carries none of the dials
  he tunes. His order: presets AFTER the hole works.
- **A or B, the halo arcs** — he answered *"neither yet — S3/S4 first"*. Still
  unanswered as a question; U7 changed its terms since the playback no longer
  spins the halo flat.

### Also still true
- Trail length is normalised by **angle** (`expNorm` uses `totalPhi`), not by path
  length `r·φ`, so an outer star's long streak is under-normalised.
- **Doppler is applied to the sprites but not to the arcs** — the ribbon colours
  by a per-particle `unifiedKelvin` that is constant along its whole length, so a
  strand has no variation ALONG it. This is what would give the strands
  definition, and it is the 6th face of the same split.

---

**Last Updated:** 2026-08-16 16:42:00
**Live tree:** `SPACE-SYNTH-TUBE-killtube`, branch `kill-the-tube-2026-08-11`
