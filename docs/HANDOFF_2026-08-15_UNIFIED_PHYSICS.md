# ⚛️ UNIFIED PHYSICS — handoff 2026-08-15 02:08:03

> **HIS NAME FOR THIS WORK, AND THE MAIN GOAL: UNIFIED LAWS OF REALITY.**

**The through-line of the whole session, found five separate times:** this renderer computes the
same physical quantity with **two different laws in two different places**, and every artefact he
rejected today was one of those splits showing on screen. Not tuning. Not taste. **One quantity,
one law, everywhere.** That is the goal and the acceptance test.

**Tree:** `SPACE-SYNTH-TUBE-killtube`, branch `kill-the-tube-2026-08-11`, HEAD `38b72f1`.
**Nothing committed.** Build `bash package_macos.sh`, launch `--env SS_FULLSCREEN=1`, always.
**Cold start for the hole is `docs/BOARD_BLACKHOLE.md`, not this file.**

---

## 0. THE PRINCIPLE, STATED ONCE

If a number describes something real — a temperature, an orbit, a mass, a colour, a plane —
there must be exactly **one** function in the codebase that produces it, and every consumer must
call that function. A second copy is not a shortcut; it is a **second universe** laid over the
first, and the screen shows the seam.

**Every fault below has the same shape.** Read them as one bug with five faces.

---

## 1. ✅ UNIFIED TODAY — five splits closed

| # | Quantity | Was TWO laws | Now | Where |
|---|---|---|---|---|
| U1 | **Orbital rate Ω(r)** | Doppler used `1/(r^1.5+a)` (real Kepler); the arcs used `r^0.9` (hand-compressed in June) | One Kepler law. The ribbon is now the path the Doppler shift is measured along | `render.metal:2793` vs `:1487` |
| U2 | **Star colour** | Sprites: `unifiedKelvin` → `blackbodyRGB`. Arcs: a **private 4-stop palette** on `temp/5` | One law. Arcs call the same `unifiedKelvin`/`blackbodyRGB`/`thT` as `:1691-1695` | `render.metal:2845-2868` |
| U3 | **Orbital plane** | Global **+Z** for every particle — true only for the 75% disk | Per-particle **L̂ = normalize(r × v)**, Rodrigues. Disk stars unchanged (L̂ ≈ +Z); the isotropic halo gets its true inclination | `render.metal:2841-2872` |
| U4 | **Orbital radius** | Ω fed cylindrical `\|xy\|`; the sweep preserves `\|pos\|` | One radius: `\|pos\|`. For the disk (z≈0) it is the same number | `render.metal:2783-2789` |
| U5 | **Lens blend** | Primary blended by `tuneLens·lensRamp·depthMix`; secondary by **bare `lensRamp`** | Position: full deflection, no mix (kills the parity pinch ring). Brightness: `tuneLens·lensRamp·…` | `render.metal:1055-1079`, `:1084-1099` |

**U2's colour ramp is why the field went brown.** Mean particle 0.297 M☉ → `unifiedKelvin` ≈ 2960 K
→ deep orange. The stars read white only because they are bright enough to saturate the additive
blend. Same law, different exposure. **The brown was never a palette bug; it is 2M dim red dwarfs
correctly coloured** — which is a spawn/IMF question, not a render one.

**U3 is the fourth sighting of the plane fault** (Doppler №2, arcs №3, this №4) and the first where
**no single global plane can be right**: `particles.cpp` spawns 75% disk in x–y, 10% flattened
nucleus, **15% isotropic halo to r=60**, and gives every star `v ⊥ r`, so the halo's orbit normal is
`r × v ∝ (−zx, −zy, x²+y²)` ⟹ **inclination = atan(|z|/|xy|)**. A halo star at 45° latitude orbits
at 45° inclination. ⚠️ Its visible consequence is §4's open question.

---

## 2. 🚨 SPLITS STILL OPEN — the actual backlog, all verified

| # | Quantity | Law A | Law B | Evidence |
|---|---|---|---|---|
| **S1** | **Temperature** | HUD prints **4.06e+10 K** mean, 2.18e+12 K inner, labelled *"real virial temperature [K]"* | Colour uses `unifiedKelvin`, **clamped to [1000, 40000] K**, and its heat term is `clamp(temp,0,5)·heatGain` — blind to anything above sim-temp 5 | `main.cpp:1171-1172` vs `render.metal:448-460`; a third scale `SIM_TEMP_REF=20 → 30000 K` in `physics_constants.h` |
| **S2** | **The hole's mass** | `Hole mass: 49.97 M☉` = `hstat.maxBodyMsun`, the biggest single **particle** (capped near 50) | `M(<r_h): 1.177e+05 M☉` = mass actually inside the horizon | `main.cpp:1090` vs `:1129`. **2354× apart, both labelled [LIVE], same panel** |
| **S3** | **Exposure / time** | The arc's exposure is `TRAIL_EXPOSURE·(1 + 4·oscAmount + tuneArcGain·bhStrength)` — **no clock in it at all** | A long exposure is ∫ over elapsed time | `render.metal:2815`. **His proof: it appears seconds after launch, before anything has orbited.** *"NOT a result of rotation and orbit but sum fake shit"* — correct, and confirmed in the file |
| **S4** | **Depth / visibility** | The BH body writes depth (`depthWriteState`, Less + write **ON**) | Stars **and** arcs bind `depthState`, Less + write **OFF** | `renderer.mm:3811-3817` vs `:1108`. ⟹ arc-vs-hole is ordered; **arc-vs-star and arc-vs-arc have no ordering at all**. N additive lines are mathematically a screen-space smear — his *"just like the fluidity effect but with a bit more glow"* is exactly right, and no arc tuning can fix it |
| **S5** | **What a preset is** | `struct Preset` = particleSize, jitter, damping, retraction, waveDepth, speedCap, field/string params, count, bloom, trailDecay, chromatic | The look he actually dials: Size Gain/Exp/Floor/Ceil, Sharpness, Grain, Exposure, Fluidity, + the 4 BH dials | `preset_manager.h:8-34`. **Not one of them is in the struct.** Quit = look lost. **His order: presets come AFTER the hole works** |

**S3 and S4 are the two that matter for the look.** S3 says the trail is not earned by time;
S4 says it has no volume. Together they are why the arcs read as an effect rather than as light.

---

## 3. ✅ VERIFIED SOUND — do not "fix" these

- **The spawn.** `particles.cpp`: 75% thin disk in **x–y about +Z** (`p.x=rr·cosφ, p.y=rr·sinφ,
  p.z=h·gauss`), 10% nucleus flattened ×0.30 in z, 15% isotropic halo (Plummer a=15, r_outer=60).
  Velocities: `v ⊥ r`, `|v| = √(G·M_enc(r)/r)` from the **measured** enclosed-mass profile of this
  realization — a genuine circular orbit for every star. **I suspected this was the fault and it
  was not. The header comment saying "x–z plane (L about +y)" is STALE** — the plate-plane
  alignment note (2026-07-16) moved it to Z. Comment ≠ mechanism, again.
- **bit18 "Fluid streak" is DEAD CODE.** `render.metal:1287` hard-assigns `out.streakLen = 1.0f`,
  so the checkbox does nothing. Do not chase sprite stretching through it. Documented at `:1267`,
  and it matches his two rejections of that mechanism (2026-07-25, 2026-07-26).
- **The lens optics.** Parity proof stands (BOARD_BLACKHOLE §2): the second image is genuinely
  mirror-reversed because it solves the opposite root. Real optics, not decoration.

---

## 4. ⏳ WAITING ON HIM

1. **A or B — the halo arcs.** U3 made every star sweep its own great circle; the isotropic halo's
   great circles stack into a **wireframe sphere** — his *"doctor strange had a seizure"*.
   The geometry is honest; the question is whether the **sky** should draw ribbons at all
   (`particles.cpp` calls the halo *"the sky backdrop that the shadow occludes and the lens bends"*).
   **A** = arcs on disk + nucleus only, sky stays points. **B** = arcs everywhere, kill the sphere
   another way.
2. **The rest of his list.** *"ALOT OF THINGS are wrong here"* — not yet enumerated. He also called
   the current state *"the right direction"*, *"almost there"*, and pointed at the long white
   lances as proof the look is reachable: *"its just straight lines disattached flowing around"*.

---

## 5. 🔴 OPEN, NOT TOUCHED THIS SESSION

- **The shapes snap weirdly to star-map mode after play.** His words, and *"we've been wanting to
  fix that for weeks"*. Uninvestigated. Not batched with the trail work.
- **BOARD_BLACKHOLE §4d** still open: star sprites are stars not stretched light; the diamond
  spikes (blocked on the star dials, his standing order); the shaky accuracy meter.

---

## 6. 📋 SESSION LEDGER — what shipped, what he said

| Change | File | Verdict |
|---|---|---|
| Parity pinch ring removed (U5a) | `render.metal:1055-1079` | unjudged |
| Lens slider reaches the 2nd image (U5b) | `render.metal:1084-1099` | unjudged |
| **The four dials given UI at last** — Lens bend / Arc gain / Arc wrap / Trail brightness. They had **no widget** since 2026-06-26 (`main.cpp:1555`) while still reaching the shader. BOARD_BLACKHOLE §4f's *"Live dials (all already wired)"* is **wrong**: wired, not dialable | `main.cpp:1416-1454` | ✅ answered *"where is that slider supposed to be"* |
| Arc colour law unified (U2) | `render.metal:2845-2868` | ❌ *"noo its wrong its orange hair"* — the law is right, the field is genuinely cool |
| Arc plane per-particle (U3, U4) | `render.metal:2783-2789`, `:2841-2872` | ⚠️ *"doctor strange had a seizure"* — honest geometry, wrong on the sky |
| Lightsaber settings captured before they could be lost | `docs/LOOK_2026-08-14_lightsaber.md` | ✅ *"kinda work with the grain and bloom"* — Grain 0.436, Exposure 19.37, Size Floor 2.78 are the three that moved |

**⭐ THE ONE LINE TO CARRY FORWARD:** *"the streaks create a unified body. we dont have one. so
something is wrong."* He is describing S3 + S4. The trail has no clock and no depth, so it can
only ever be a smear over the field instead of the field's own light in motion.

---

**Last Updated:** 2026-08-15 02:08:03
**Live tree:** `SPACE-SYNTH-TUBE-killtube`, branch `kill-the-tube-2026-08-11`
