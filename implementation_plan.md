# Black Hole and Collision Fixes

This plan addresses the two main issues preventing the black hole from rendering correctly and stopping mass from growing through collisions.

## User Review Required

> [!WARNING]
> We are making changes to the core collision logic (`particles.metal`) which might alter how the particle simulation behaves. The hard-sphere elastic bounce will be removed in favor of true inelastic merging. 

## Open Questions

> [!IMPORTANT]
> Currently, the system intentionally prevents stars from merging (mass growth) while music is actively playing ("No building during play" - Jamal, 2026-06-14). Should I enable mass growth / merging *during* music playback as well, or keep the original rule where mass only grows during silence?

## Proposed Changes

### Black Hole Geodesic Render (`bh_geodesic.metal`)

The black hole appears overscaled/blown-white because the new geodesic shader (`bh_geodesic.metal`) is hardcoded for an orthographic projection. When the camera is in perspective mode, `u.orthoFrustum` evaluates to `0`, resulting in the rays having no spread, effectively putting the camera inside the disk with infinite zoom.

#### [MODIFY] [bh_geodesic.metal](file:///Users/airy/SPACE%20SYNTH/SPACE-SYNTH-TUBE/src/render/bh_geodesic.metal)
- Extract the `fovY` from the `CameraUniforms` (or pass it in) and calculate a proper perspective ray bundle when not in orthographic mode.
- Decrease or tune the `DENS` scalar so the accretion disk doesn't blow out to white immediately.

#### [MODIFY] [renderer.mm](file:///Users/airy/SPACE%20SYNTH/SPACE-SYNTH-TUBE/src/render/renderer.mm)
- Update `GeoUniforms` in `renderer.mm` to pass the camera's FOV so `bh_geodesic.metal` can generate correct perspective rays.

---

### Mass Growth and Collisions

Turning on "Collisions" currently enables a "Hard-sphere Elastic Collision" in `compute_physics`. This acts as a repulsion force that pushes stars apart before they can physically overlap. However, the inelastic merger (`merge_stars`) only triggers when stars physically overlap. Because the elastic bounce prevents them from overlapping, mass never grows!

#### [MODIFY] [particles.metal](file:///Users/airy/SPACE%20SYNTH/SPACE-SYNTH-TUBE/src/render/particles.metal)
- **Remove** or **disable** the Hard-sphere Elastic Collision logic in `compute_physics` that artificially pushes stars apart. 
- Allow `u.collisionsOn` to instead govern or interact with the `merge_stars` kernel, ensuring that real inelastic collisions (which build mass and lead to black hole collapse) happen when stars get close.

#### [MODIFY] [renderer.mm](file:///Users/airy/SPACE%20SYNTH/SPACE-SYNTH-TUBE/src/render/renderer.mm)
- (Pending User Answer) If requested, we can remove the `notPlaying` condition from the `merge_stars` dispatch so mass can grow during active play.

## Verification Plan

### Manual Verification
- Click **"RENDER BLACK HOLE (analytic)"** and verify that the black hole shadow, photon ring, and accretion disk appear correctly scaled in perspective mode.
- Turn on **"Collisions"** in the UI and observe the star field. Allow stars to clump and verify that they merge into heavier stars, growing their mass and causing the physics engine to eventually form a geometric black hole.
