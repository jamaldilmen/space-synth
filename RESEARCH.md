# Research Roadmap

Space‑synth is evolving from a Web‑style audio visualizer into a physically grounded, GPU‑accelerated field simulator where audio and visuals share the same mathematics. This document tracks the research tasks needed to ship a performant, musically expressive, and “biblically accurate” vortex‑based simulation.

---

## I. Creative Audio–Visual Mappings

### 1. Visual compression (audio compressor → spatial compression)
Goal: Use audio compressor settings to physically compress or expand the visual domain.

### 2. Reverb tails → particle glow
Goal: Let reverberation decay control particle emission/glow, so space “fills” with lingering light.

### 3. Delay → visual trails
Goal: Use audio delay lines as literal trajectory memory for particles.

### 4. Magnetism: amplitude/frequency → attraction/repulsion
Goal: Implement a mode where sound parameters directly modulate magnetic‑like forces between particles.

### 5. Interactive 3D typography
Goal: Let users type text that appears as 3D volumes or fields which particles populate, orbit, or erode.

### 6. Micro‑navigation (click‑to‑zoom on a single particle)
Goal: Allow the user to click a particle and smoothly zoom into its micro‑physics context.

---

## II. Advanced Physics & Simulation (“Biblically Accurate” Mode)

### 1. Maxwell‑style vortex medium
Goal: Base the visual physics on a Maxwell‑inspired vortex medium where electromagnetic effects propagate via coupled vortices and “ball bearing” charges.

### 2. Toroidal / vortex‑ring particles
Goal: Treat “particles” not as points but as toroidal vortex rings whose self‑sustained rotation mimics mass and inertia.

### 3. Mass as motion (99% mass = energy in motion)
Goal: Visualize particles as localized patterns of motion and field energy rather than solid dots.

### 4. Wave speed vs. stiffness and inertia
Goal: Tie the propagation speed of disturbances in the field to stiffness (electrostatic‑like repulsion) and inertia (vortex momentum).

### 5. Vortex collisions and cascades
Goal: Implement collisions where vortices attract/repel, reconnect, and break into smaller rings while approximately conserving energy.

---

## III. Visual & UI Enhancements

### 1. Density heatmaps and nodal line visualization
Goal: Visualize where particles congregate and how that relates to Chladni/Bessel nodal structures.

### 2. Frequency response modes (Classic vs Biblically Accurate)
Goal: Maintain a “Classic” Chladni mode while offering a Maxwell/Oersted‑inspired vortex mode.

### 3. Dynamic scaling: 100k → millions of particles
Goal: Scale from the Phase 1 milestone (~100k particles) to target multi‑million particle counts.

### 4. High‑end rendering (“trapped light” look)
Goal: Move beyond pure amplitude‑driven blobs towards particles that feel like trapped, refracted light in a living field.
