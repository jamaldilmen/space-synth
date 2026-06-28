# SPACE Synth — Session wrap-up + deep codebase analysis
_2026-06-28 21:55:00 · branch STARS_

## 1. What happened today
**HUD (committed, `466375e`→`ef5e5ce`):** stripped dead controls; Universe-time control +
running cosmic clock; light-time distance units; glowing top status bar (ImDrawList).
Layout still "step 1" — the full Stellaris cockpit (top-bar + rail + section panels) is
designed (`docs/hud_design_brief.md`, Open MCT patterns) but not built.

**Black hole (uncommitted — the bulk of the day):**
- Built the **analytic BH pose** — "RENDER BLACK HOLE" button poses particles into a thin
  Keplerian disk (r_in=3·r_s, r_out=12), mass-graded, real units (r_s=1.0 sim). Real
  Keplerian Ω(r)=√(GM/r³) + √(1−r_s/r) disk spin in the vertex shader.
- **Deleted the old `blackhole.metal` raytracer** entirely (Jamal: it's a 2D-circle cheat).
- **Verified the real Schwarzschild geodesic** physics: deflection α(b), b_crit = 2.598 r_s
  — matches the DNGR/Interstellar docs to the digit. Validated the full lensed image in a
  Python prototype (scratchpad `bh_proto2.png`): front disk + far side wrapped over/under a
  round shadow + photon ring.
- Built a **per-pixel geodesic BH shader** (`bh_geodesic.metal`), pose-only. Iterated:
  analytic disk (rejected, "looks like shit") → **option 1 chosen: volumetric geodesic
  render of the REAL particle density** (`cellMass`) with Doppler from the real orbital
  speed. It renders (image #11) — light bent through the actual particles — but **framing
  is overscaled** (camera inside the disk → blown white) and **brightness (`DENS`) +
  colour are untuned**.

## 2. Current state (READ FIRST next session)
- **Uncommitted sprawl** — nothing committed since `ef5e5ce`:
  `M main.cpp, renderer.mm, renderer.h, particles.metal, render.metal, app_state.h,
  CMakeLists.txt; D blackhole.metal; ?? bh_geodesic.metal, docs/*`. **Commit this as a
  checkpoint first thing — risk of loss.**
- BH render path is **pose-only** (`bhPosed`): physics frozen, spatial hash kept building,
  `bhStrength`/`bhSeedMass` re-pinned each frame, forward particles hidden, geodesic pass
  drawn as the sole BH renderer sampling `cellMass`.
- Live (non-pose) sim is unchanged: the per-particle 2D-NDC lensing still exists for it.

## 3. Deep codebase analysis
**Stack:** C++/Metal, ~12.9k LOC. `src/core` (physics/units/audio-less core), `src/audio`,
`src/render` (Metal), `src/ui`, `src/main.cpp`.

**Hot files (size = complexity risk):**
- `particles.metal` **2568** — the GPU monolith: `compute_physics` (~1800-line single
  kernel: Störmer-Verlet + self-gravity (near 27-cell + far monopole + central SMBH) +
  collision/relaxation + BH lifecycle + sculpt + my uncommitted adaptive-substep). Plus
  `merge_stars`, `seed_mark/apply/feed`, `reduce_stats`. **The hardest file to reason about.**
- `renderer.mm` **2256** — Metal setup + `runComputePass` (hash build + physics dispatch)
  + two `render()` overloads + the pose machinery. Pose state threaded through many spots.
- `main.cpp` **2117** — app + the entire ImGui HUD inline (one giant `if(showHUD)` block).
- `render.metal` **1014** — particle vertex (lensing/Doppler/blackbody/streak) + star-map /
  supernova / thermal colour paths + blackbodyRGB (Tanner-Helland) + ssDiskTempShape.
- `bh_geodesic.metal` **139** — NEW geodesic BH render.

**Tech debt / risks (ranked):**
1. **The emergent engine is still broken** (the original goal): particles collapse to a
   spasming blob, no mass growth without the seed toggles. The fix (adaptive sub-stepping,
   GMAT notes `docs/bh_integrator_gmat_notes.md`) is *designed, not implemented*. Today's
   work was the BH *render*, not the *formation*.
2. **`compute_physics` monolith** — one ~1800-line kernel mixing gravity/collision/
   lifecycle/sculpt; every BH-engine edit risks regressions here (history confirms it).
3. **Coordinate-scale tangle** — sim units (r_s=1, disk 3–12) vs world (×`plateRadius`) vs
   hash `halfExtent` (64 rest / 3 play). The recurring bug source (old raytracer black,
   today's framing overscale). Needs one documented mapping.
4. **`bhStrength`/`bhSeedMass`/formed-latch** logic is fragile — had to re-pin it for the
   pose because the emergent computation clobbers it.
5. **Dead code**: 15 `if(false)` blocks (presets/VJ/debug-GPU/trajectory/ORIGIN-LOCK);
   `bgDepthState` now unused after the raytracer deletion. ~27 debt markers
   (HACK/KLUDGE/cheat/regression).
6. **Tracked build artifact** — `SpaceSynth.app/Contents/MacOS/SpaceSynth` is committed,
   bloating every commit. Should `.gitignore` build output.

## 4. Path forward (proposed order)
1. **Commit the BH-pose + geodesic checkpoint** (don't lose today).
2. **BH render polish (option 1):** auto-frame the camera on pose (fix overscale) → tune
   `DENS` brightness → colour (blackbody temp + gravitational redshift √(1−r_s/r) +
   Doppler hue) → verify the over/under wrap + photon ring read clean.
3. **Cleanup commit:** delete the 15 `if(false)` blocks + `bgDepthState`; `.gitignore` the
   app binary.
4. **HUD:** build the real Stellaris cockpit from `docs/hud_design_brief.md`.
5. **Long arc — emergent formation:** implement the GMAT adaptive sub-stepping in
   `compute_physics` so stars actually collapse→grow→pop into a BH (Option 3 from today).

## 5. Pointers
- Memory: `space_synth_blackhole_render_research` (BH render STATUS + decisions),
  `space_synth_gmat_adaptive_integrator` (the engine cure).
- Docs: `bh_integrator_gmat_notes.md`, `blackhole_render_research_notes.md`,
  `hud_design_brief.md`.
- Verified physics: α(b) table + b_crit=2.598 r_s; Python protos in scratchpad.
