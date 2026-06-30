# SPH REACTION ENGINE — Full Build Plan (cold-start spec for a new window)
_Written 2026-07-01 00:10:00 · branch `session-2026-06-30-honest-spacetime-friction` @ `aaea1b4`_
_Author of this spec: the session that fixed self-gravity (variable-dt energy pump) and built PM gravity._

> This document is **exhaustive on purpose** (Jamal: "utmost detail, peak detailism, no skips or
> shortcuts"). Read it top to bottom before writing any code. It assumes ZERO prior context.

---

## 0. WORKING PROTOCOL (non-negotiable — applies to every step here)

1. **VERIFY, never assume.** A change is not done until confirmed LIVE. "It compiled" ≠ "it works".
   If a change appears to do nothing, suspect a STALE BINARY FIRST.
2. **ONE verifiable change → confirm it landed → say exactly what to look at → STOP for Jamal's verdict.**
   Never batch. Never stack on unverified work. Each slice below is ONE such change.
3. **GROUND, don't invent.** Use what exists; measure with real logs; no guessing.
4. **TIMESTAMP every STATUS/memory update to the second** (`YYYY-MM-DD HH:MM:SS`).
5. **NO HYPE.** State what is literally true. Jamal owns the visual verdict; you own the running.

### Build / run / verify — DO NOT use bare `make`
```bash
cd "/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE"
bash package_macos.sh                         # builds AND deploys into SpaceSynth.app
# VERIFY the deploy landed (bundle artifacts must be >= source). If you edited a .metal shader,
# default.metallib MUST be newer than the .metal, or you are testing a STALE shader:
stat -f "%Sm %N" SpaceSynth.app/Contents/MacOS/SpaceSynth \
                 SpaceSynth.app/Contents/Resources/default.metallib \
                 src/render/particles.metal src/render/spatial_hash.metal src/render/renderer.mm
# Interactive (Jamal owns the verdict):
pkill -f SpaceSynth; open -n SpaceSynth.app
# Headless measurement (you own this):
rm -f /tmp/ss.log; ./SpaceSynth.app/Contents/MacOS/SpaceSynth >/tmp/ss.log 2>&1 &
#   ... wait via a background `until grep -c ...` loop (foreground sleep is blocked), then grep stderr.
#   Kill with: pkill -f "MacOS/SpaceSynth"
```
`make` alone only writes `build/` — it does NOT update the launchable bundle. Bare make + relaunch =
testing a stale binary (this burned a full day on 2026-06-14).

---

## 1. WHERE WE ARE (state at the time of writing)

- **Branch** `session-2026-06-30-honest-spacetime-friction`, last commit **`aaea1b4`**.
- **Just shipped (this session):**
  - Found the multi-session root cause of "cluster disperses at rest / no black hole": it was **NOT**
    diffuseness/weak gravity/accretion. It was the **VARIABLE TIMESTEP**. `dt` is frame-rate-tied and
    swings ~4× (0.0086–0.033); the Störmer-Verlet velocity carry-over `(pos−prev)·tcv`,
    `tcv=clamp(dt/dtPrev,0.5,2.5)`, is only first-order, so any dt variation **injects energy** whenever
    a force is present. It coupled through ANY gravity. "No forces" was always stable; "any force" blew up.
  - Built **real PM gravity**: Poisson `∇²Φ=4πGρ` (red-black SOR, ω=1.9, warm-started, monopole Dirichlet
    BC) on the 128³ grid; force = −∇Φ. Energy-conserving. Replaces the per-frame centroid/COM attractors.
  - **Interim dt fix**: pinned `dt = 0.0165` (fixed step) in `renderer.mm`. With it + PM gravity, the cold
    cluster **HOLDS** (speed 0.022→0.011, meanR flat 47→47.9 over 70s). Jamal's verdict: "first time it
    behaves like real stars, stable even at 4× speed."
- **State now:** stable cold cluster, NOT yet collapsing (friction bleeds the weak infall → quasi-static).
  This is fine — collapse is deferred; the reaction engine is next.
- **Memory files (read these):** `space_synth_reaction_engine_sprint.md` (this sprint's summary),
  `space_synth_gravity_pump_2026-06-30.md` (the dt fix), `space_synth_bh_scale_research_2026-06-30.md`
  (BH scale facts), `working_protocol.md`.

---

## 2. THE GOAL & PRIORITIES (Jamal's words)

Build the **reaction engine**. Priority order, do them IN THIS ORDER:
1. **Energy lifecycle + collisions + timing** ← the keystone (this whole doc, §3–§6 slices 0–6).
2. **Volumetric / true-3D substrate** (the sculpt is a hollow 2.5D shell — §6 slice 7).
3. **Held-supernova → supermassive black hole** (deferred; needs the radiation sink from slice 4).

### The principle: EMERGE, not scripted
States (star / gas / plasma / black hole) must NOT be switched by phase flags. They must **fall out of
the physics**. The current code SCRIPTS them with gates (`playGate`, `notPlaying`, `envelopePhase`
windows) — those get removed (carefully, see slice 5).

### THE CORE MODELING INSIGHT (read twice)
Our particles (each ~1 M☉ from the Kroupa IMF) are **SPH mass parcels**. SPH unifies the two behaviors
Jamal wants from ONE model, with the transition **emergent via temperature/density**:
- **Diffuse + cold** (rest starmap): internal energy `u`≈0 → pressure≈0 → only gravity acts →
  **collisionless N-body** → stars orbit. (This is what we just got working with PM gravity.)
- **Dense and/or hot** (play, supernova, collapsing core): `u` high → pressure + shocks dominate →
  **collisional fluid** → gas/plasma.
SPH smoothly interpolates between these. The PM gravity we built IS the gravity term of SPH. Adding the
**pressure + artificial-viscosity** terms (driven by an honest `u`) completes the engine, and the
collisionless↔fluid transition is automatic. **This is why SPH is the right answer and not a hack.**

### Why SPH (researched, sourced 2026-06-30)
Stellar collisions/mergers/supernovae are simulated with SPH — the canonical code is **StarSmasher**.
Each particle carries mass, position, velocity, **specific internal energy**. Shocks via **artificial
viscosity** (Von Neumann–Richtmyer 1950) → KE→heat, enforcing **Rankine–Hugoniot**. EOS = ideal gas +
radiation pressure. Merge/disrupt/plasma EMERGE from mass + relative velocity + impact parameter.
The project once explored MLS-MPM — MPM is for solids/multi-material; **for stars/gas/plasma/SN the
astrophysics standard is SPH. Use SPH.** Sources in §10.

### Composition — do particles need to know what they're made of?
- **To collide (SPH pressure+shock): NO.** The EOS needs a mean molecular weight μ; fix it (μ≈0.62,
  ionized solar). Composition is a constant at this layer.
- **For the lifecycle (what fuses, when it goes SN, NS vs BH fate, ejecta color): YES** — but a single
  **burning-stage scalar** (H→He→C→O→Si→Fe) suffices, not a full reaction network.
- **At SN energy: derivable.** Nuclear Statistical Equilibrium sets composition from T, ρ, proton
  fraction — you compute it, you don't track every isotope.
So: slices 0–5 need NO composition. Composition is slice 6 (one scalar), for the lifecycle.

---

## 2A. PERFORMANCE & SCALE (a hard design constraint — read before writing any kernel)

**Particle envelope (Jamal, 2026-07-01): launch = 2,000,000; typical = up to ~5,000,000; PEAK = 7,000,000.**
(Design for 2M baseline, must stay usable at 5M, survive 7M. NOT 10M.) The existing sim already runs **2M
at ~104 fps** (measured this session: `FPS: 104 | Particles: 2000k`).

**Non-negotiable performance rules for the SPH passes:**
- **O(N), grid-based, NEVER a pairwise O(N²) scan.** Every SPH neighbor loop (density, pressure force,
  viscosity) uses the SAME structure as the existing kernels: per particle (or per cell), scan the **27
  neighbor cells**, read the **≤32 scattered samples per cell** from `sortedParticles`. That `≤32`/cell
  cap (`scatter` writes ≤32/cell; `cellCounts` is `min(.,32)` in the consumers) is what bounds work per
  particle to O(1) → total O(N). **SPH MUST honor the same ≤32 cap.** It is an approximation (a dense cell
  with >32 neighbors only samples 32) — accept it for real-time; it rate-limits accuracy, not correctness.
- **Pass count discipline.** SPH adds neighbor passes: density (1), then force+energy (1, can be fused).
  That's ~2 extra 27-cell passes on top of the existing centroid/merge passes. At 2M each ≈ the cost of the
  existing centroid pass (cheap). At 7M it is 3.5× heavier → keep passes minimal, fuse force+viscosity+energy
  into ONE kernel, and do density in one. Do NOT add a separate kernel per term.
- **Buffers scale linearly:** per-particle float buffer = 7M × 4 B = **28 MB** at peak (ρ, P each) — trivial
  on the M5 Max unified memory. Per-cell buffers are particle-count-independent (128³ = 2.1M cells).
- **The Poisson SOR (PM gravity) is grid-based → cost is independent of particle count** (80 sweeps ×
  2.1M cells). Unaffected by 2M→7M. Good.
- **Budget check each slice headless:** log `FPS` (already printed) at 2M AND at 5M. If a slice drops 2M
  below ~60 fps, it's too heavy — reduce passes / tighten the ≤32 cap / fuse kernels before proceeding.
  Report the FPS delta to Jamal with each slice.
- **Threadgroup sizing:** match the existing kernels (`std::min(tgSize, pipeline.maxTotalThreadsPerThreadgroup)`;
  per-cell passes dispatch `kTotalCells`, per-particle passes dispatch `particleCount`).

---

## 3. THE SPH MATH (exact, to implement; all in SIM UNITS)

Notation: particle `i`, neighbors `j`. `r_ij = r_i − r_j`, `v_ij = v_i − v_j`. `h` = smoothing length.

### 3.1 Smoothing kernel (cubic spline, 3D)
`W(r,h) = (1/(π h³)) · f(q)`, `q = r/h`:
- `f = 1 − 1.5q² + 0.75q³`         for `0 ≤ q < 1`
- `f = 0.25(2−q)³`                 for `1 ≤ q < 2`
- `f = 0`                          for `q ≥ 2`
Gradient: `∇_i W = (dW/dr)(r_ij/|r_ij|)`, with
`dW/dr = (1/(π h⁴))·g(q)`: `g = −3q + 2.25q²` (0≤q<1); `g = −0.75(2−q)²` (1≤q<2); `0` else.
Support radius = `2h`. **Pick `h ≈ cellSize`** (rest cellSize=1.0) initially → support 2.0 sim → reaches
the ±1 neighbor cells already scanned. (Adaptive `h` is a later refinement; fixed `h` first.)
NOTE: support 2h = 2 cells means the 27-cell (±1) scan covers most of it; if `h` grows you must widen the
scan (cost). Keep `h ≤ cellSize` to stay inside the ±1 (27-cell) O(N) budget.

### 3.2 Density
`ρ_i = Σ_j m_j W(|r_ij|, h)`  — sum over the 27 neighbor cells, ≤32 samples/cell. Units: M☉/sim³.

### 3.3 Equation of State → pressure
`P_i = (γ−1)·ρ_i·u_i  +  (a_rad/3)·T_i⁴`
- `γ = 5/3` (monatomic ideal gas).
- `u_i` = specific internal energy. We already carry **temperature in `prevW.w`**. Relation:
  `u = (1/(γ−1))·(k_B/(μ m_H))·T`. Fold the constant: define `K_uT` so `u = K_uT·T` in sim units
  (derive once from spacetime.h + μ; §5). For slice 2 you may evolve `u` directly and use `T = u/K_uT`.
- `a_rad` = radiation constant in sim units (derive once, §5). Dominates in shock-heated regions (correct).
  If it destabilizes early slices, start ideal-gas only; add radiation in slice 4.
- Sound speed: `c_s,i = sqrt(γ P_i / ρ_i)`.

### 3.4 Momentum equation (the pressure + viscosity force)
`dv_i/dt = − Σ_j m_j ( P_i/ρ_i² + P_j/ρ_j² + Π_ij ) ∇_i W_ij   +   g_i`
- `g_i` = gravity = **−∇Φ from the PM solver we already built** (reuse `phiBuffer`, bit10 path).
- `Π_ij` = **artificial viscosity** (Monaghan 1992), the shock-capture / KE→heat term:
  - if `v_ij·r_ij < 0` (approaching): `Π_ij = (−α·c̄_ij·μ_ij + β·μ_ij²) / ρ̄_ij`,
    `μ_ij = h·(v_ij·r_ij)/(|r_ij|² + 0.01h²)`, `c̄ = ½(c_s,i+c_s,j)`, `ρ̄ = ½(ρ_i+ρ_j)`.
  - else `Π_ij = 0`. Coefficients `α ≈ 1`, `β ≈ 2`. (Balsara shear switch = later refinement.)

### 3.5 Energy equation (heat: pressure work + viscous shock heating − cooling)
`du_i/dt = Σ_j m_j ( P_i/ρ_i² + ½Π_ij ) (v_ij · ∇_i W_ij)   −   Λ_cool(ρ_i, T_i)`
- The `½Π_ij` term IS the irreversible shock heating (Rankine-Hugoniot entropy production).
- `Λ_cool` = radiative cooling (slice 4). Simplest honest sink: optically-thin `Λ ∝ ρ·T⁴` (or reuse the
  existing T⁴ cooling). Required for held-SN→BH and for gas to settle. Tunable; convert to real seconds.

### 3.6 Time integration — CRITICAL
- Use the **existing Störmer-Verlet** with **FIXED dt** (the interim fix; do NOT reintroduce variable dt
  — it is the proven energy pump). Gravity is applied as `gacc·dt²` (per-frame displacement); match that
  convention for the SPH accelerations and the `du` increment.
- **CFL stability:** SPH needs `dt ≲ C·h/(c_s + |v|)`. With fixed dt and a hot gas (`c_s` large), this can
  break → instability. Either (a) cap heating/`c_s` per step, or (b) move to the **fixed-dt accumulator**
  (N sub-steps/frame) — also the "proper dt fix". If the gas blows up when hot, CFL is why.

---

## 4. GROUNDED CODE MAP (every relevant location — verified this session)

### 4.1 Particle struct (`src/render/particles.metal:16`, 80 bytes, mirrors C++ `GPUParticle`)
```
struct Particle {
    float4 posW;        // x, y, z, MASS(w)            mass in M_sun (0 = dead/wall)
    float4 velW;        // vx, vy, vz, PHASE(w)        (velW is NOT read by compute_physics)
    float4 prevW;       // prevX, prevY, prevZ, TEMPERATURE(w)   ← internal-energy proxy lives here
    float4 spinW;       // spinX, spinY, spinZ, CHARGE(w)        spinW.x = r_home (rest radius)
    uint4  entanglement;// x: entangledIndex/bond, y/z/w: OVERLOADED (see below)
};
```
- **Velocity is derived from `(posW − prevW)` (Verlet), not `velW`.** `particles.metal:295`:
  `tcv=clamp(dt/dtPrev,0.5,2.5); vpx=(px−prevX)*tcv`. `velW.w` is phase.
- **Field overloads (NO clean free slot):** `scatter_particles` (`spatial_hash.metal:325`) writes
  `entanglement.y=id` (origin) **in the sorted snapshot**, but the LIVE buffer uses `entanglement.y` as
  **hardness float bits** (`particles.metal:1681,1696`). `entanglement.z`=home `theta` (`277,610`) AND a
  bond id (`1671`). `entanglement.w`=home `phi` (`278,611`) AND a bond id (`1648`).
  → SPH-derived quantities (ρ, P) go in **NEW per-particle MTLBuffers** (like `phiBuffer`). Persistent
  composition (slice 6) needs a real field → **widen the struct** (add a `float4` → 96 B; update C++
  `GPUParticle`, `particles.cpp packForGPU`, all `sizeof`/stride) OR repurpose `velW.w`(phase)/`spinW.w`
  (charge) only after auditing they're unused in the target states.

### 4.2 STALE CONSTANT TO FIX (high priority — part of "nothing merges")
`particles.metal:141  constant float MERGE_RSUN_SIM = 0.0549f;` — comment: `6.96e8 m / 1.269e10 m`, the
**OLD Sgr A* anchor**. Honest anchor is `kUnitMeters=1.755e9 m` → **1 R☉ = 6.957e8/1.755e9 = 0.397 sim**,
i.e. ~**7.2× too small**. Stars modeled 7× tinier → almost never touch → "nothing merges". Re-derive to
`≈0.397`. `v_esc(Sun)=√(2GM/R)` lands on 615 km/s=0.002c only with R=0.397 (with 0.0549 it reads 1650 km/s).

### 4.3 Buffers (`renderer.mm struct Impl`, allocated in `uploadParticles`/`resize`, `StorageModeShared`)
Particles: `particleBuffer`, `particleBufferRead`, `sortedParticlesBuffer`. Grid: `cellIndicesBuffer`,
`cellCountsBuffer`, `cellStartsBuffer`, `cellOffsetsBuffer`, `blockSumsBuffer`. Per-cell: `cellMassBuffer`
(Σ M☉×64, uint), `cellCentroidsBuffer` (float4 centroid.xyz,count.w), `cellVelocitiesBuffer` (float4 mean
vel.xyz, **σ in .w**), `cellMaxPartialsBuffer`. PM gravity: **`phiBuffer`** (float/cell, 128³, warm-started,
`phiInitialized` flag). Seeds (mostly off): `seedCountBuffer`,`seedIdsBuffer`,`cellSeedMapBuffer`,
`seedAccumBuffer`. Diag: `accDiagBuffer`. Stats: `partialSumsBuffer`,`radialMassBuffer`. Uniforms:
`spatialHashUniformBuffer`,`uniformBuffer[frameIdx]`. **Grid:** `kGridSize=128`, `kTotalCells=128³`.
Rest: `halfExtent=64`, `cellSize=1.0`. Play (envelopePhase 1.5–3.5): `halfExtent=3`, `cellSize≈0.047`.

### 4.4 Dispatch sequence (`renderer.mm Renderer::Impl::runComputePass`, members BARE not `impl_->`)
`assign_cells` → `count_cells` (counts + `cellMass` + seeds) → prefix sum (→`cellStarts`) →
`scatter_particles` (→`sortedParticles`, sets `entanglement.y`=origin) → `compute_cell_centroids` (REST
only `totalAmplitude<0.02`) → **`poisson_sor`** (PM gravity, REST + `pmGravityOn`, 80 sweeps, warm-start) →
`reduce_cell_max` → `merge_stars` (REST only `notPlaying`+`countStable`) → `seed_mark` → `density_heatmap`
→ **`compute_physics`** (big per-particle kernel) → `seed_apply` → `reduce_stats`.
**→ Insert `sph_density` after scatter (needs neighbors). SPH force+energy goes into `compute_physics` OR a
fused `sph_force` kernel just before it.**

### 4.5 `compute_physics` bindings (`renderer.mm:~1370`, kernel `particles.metal:229`)
0 particles, 1 voices, 2 PhysicsUniforms, 3 prevParticles(read), 4 sortedParticles, 5 cellStarts,
6 cellCounts, 7 SpatialHashUniforms, 8 cellCentroids, 9 cellVelocities, 10 cellMass, 11 cellSeedMap,
12 seedIds, 13 seedAccum, 14 accDiag, **15 phi**. → New SPH buffers bind at **16+**.

### 4.6 PhysicsUniforms (`particles.metal:39+`)
`dt`, `speedCap`(=3.515 = the warp → cap is **3.5c not c**), `frameCounter`, `massTotal`, `comX/Y/Z`,
`gravGM`(=G_sim·M_tot), `dtPrev`, `centerGM`, `bhToggles`, `envelopePhase`, `totalAmplitude`, `time`,
`plateRadius`, `voiceCount`, `collisionsOn`, `debugFlags`, `jitterFactor`. **G_sim/M☉ = gravGM/massTotal.**

### 4.7 SpatialHashUniforms: `int gridSize; int particleCount; float cellSize; float invCellSize;
int gridSizeZ; float halfExtent;`

### 4.8 bhToggles bits (`app_state.h` + `main.cpp` packer ~1804): 0 field-grav, 1 central-SMBH, 2 seed-cap,
3 seed-merge, 4 origin-pin, 5 relaxation, 6 resurrection, 7 seed-render, 8 lens, 9 adaptive-substep,
**10 PM-gravity (default on)**. → **Free bits 11+** for new SPH toggles (bit11 pressure, bit12 viscosity…).

### 4.9 WHAT TO REPLACE / REMOVE
- `particles.metal:1494` — old **Coulomb-like "collision"** (`collisionsOn>0 && playGate<0.5`). Jamal:
  "the optional one was kinda fucked." Ad-hoc, NOT hydro. **Replace with SPH pressure+viscosity.**
- `merge_stars` (`particles.metal:2135`, rest-only) — keep as the *emergent low-velocity merge outcome*
  (`v_rel<v_esc`), NOT always-on-contact, fed the REAL thermalized energy (currently heuristic `+2+6q`).
- The **gates** (`playGate`,`notPlaying`,`envelopePhase`) — remove so SPH runs in ALL states (slice 5),
  carefully preserving the cymatics sculpt (§7).

### 4.10 The sculpt (priority 2 — slice 7)
`particles.metal:1336` — note force `Y=cos(m·θ)·sin(n·φ)`, gradient in θ̂/φ̂ ONLY (1343–1353). **No radial
term → hollow 2.5D shell.** True 3D = restore a radial eigenfunction (spherical Bessel `j_l(k·r)`;
`besselJ` exists in `src/core/bessel.cpp`) × the angular harmonic.

---

## 5. UNIT ANCHORS & REAL NUMBERS (derive constants ONCE, in sim units; show derivation in comments)

From `src/spacetime/spacetime.h`: `kUnitMeters=1.755e9 m`; `kSimSeconds=5.855 s`; **1 sim velocity = c**;
`kGMsunSim=8.413e-7` sim³/simt² per M☉; `r_s/M☉=1.6826e-6` sim; field `5.94276e5 M☉`, `r_s(field)=1.0`.
- **R☉=0.397 sim** (fix MERGE_RSUN_SIM). **v_esc(Sun)=0.00205 sim=615 km/s=0.002c** (merge↔disrupt threshold).
- Rest v_rel≈v_esc (merge). SN/play v_rel~0.03–1c=15–500× v_esc (plasma).
- Derive for the EOS: `K_uT` (`u=K_uT·T`, from `u=(1/(γ−1))k_B T/(μ m_H)`, μ≈0.62), and `a_rad` (sim units).
  AUDIT the existing "temperature" scale first (`[CLUSTER] temp avg ~1e10` — likely not Kelvin); define ONE
  honest temperature unit shared by EOS, cooling, and render color.

---

## 6. IMPLEMENTATION SLICES (one verifiable change each — DO NOT batch; A/B each behind a bhToggles bit)

### Slice 0 — Field allocation & the stale-radius fix (foundation, low risk)
- **Fix `MERGE_RSUN_SIM`→0.397** (comment the derivation). Rebuild, headless: stars ~7× bigger, merges
  happen more readily; check meanR/Mmax + FPS at 2M. Jamal: zoom in, stars have real size. Get verdict.
- **Allocate** `densityBuffer`, `pressureBuffer` (float/particle, shared, sized to MAX particle count =
  7M → 28 MB each), bind to `compute_physics` at 16,17. (Internal energy: reuse `prevW.w` temperature via
  `u=K_uT·T` first; add `uBuffer` only if temperature semantics conflict.) Verify: builds, bound, zeroed,
  no behavior change (toggles off), FPS unchanged.

### Slice 1 — SPH DENSITY (new kernel `sph_density`, O(N))
- New kernel in `spatial_hash.metal`: per particle, scan 27 neighbor cells, ≤32 samples/cell from
  `sortedParticles`, `ρ_i=Σ_j m_j W(|r_ij|,h)`, h=cellSize. Write `densityBuffer[origin]`. Dispatch after
  scatter. **O(N), ≤32 cap — honor §2A.**
- **Verify (headless):** `[SPH]` log of ρ at center vs edge (like the `[PM]` Φ-row). ρ smooth, positive,
  ~`cellMass/cellSize³`. Log FPS @2M and @5M. No motion change yet. STOP.

### Slice 2 — EOS PRESSURE + PRESSURE FORCE (the gas holds itself up; inside no longer hollow)
- `P_i` from ρ+u (ideal gas first `P=(γ−1)ρu`). Add pressure accel `−Σ_j m_j(P_i/ρ_i²+P_j/ρ_j²)∇W_ij` to
  `gacc` (with PM −∇Φ). Gate bit11. **Fuse into one neighbor pass.**
- **Verify:** a gas blob with nonzero `u` reaches **hydrostatic balance** (holds finite size vs gravity)
  instead of point-collapsing; raise `u`→bigger blob. Headless: test-blob meanR stabilizes finite. FPS check.
  Jamal: the inside fills a volume. STOP.

### Slice 3 — ARTIFICIAL VISCOSITY + SHOCK HEATING (collisions become real — the keystone)
- Add `Π_ij` (§3.4) to the force and `½Π_ij` heating to `du_i/dt` (§3.5) → write heat to `u`/temperature.
  Needs `c_s=√(γP/ρ)`. Gate bit12. **Fuse with the slice-2 force pass (one kernel).**
- **Verify:** two clumps approaching fast → **shock** (sharp ρ+T jump at contact, KE→heat, pressure
  resists interpenetration → plasma); slow → gentle settle/merge. Headless: contact-front T spikes ∝ v_rel²;
  momentum + (KE+u) conserved. FPS @2M/5M. Jamal: clash at speed → hot gas; slow → gentle. STOP.

### Slice 4 — ENERGY LIFECYCLE: radiative cooling (the sink)
- Add `Λ_cool(ρ,T)` to `du/dt` (`∝ρT⁴` or reuse existing T⁴ cooling); rate in real seconds. Lets hot gas
  radiate, lose pressure, recollapse if bound.
- **Verify:** hot blob cools over a tunable real timescale; bound cooling cloud contracts. Headless: T(t)
  decay curve; cooling-blob meanR shrinks. STOP.

### Slice 5 — UNGATE to all states (reactions everywhere, cymatics preserved)
- Relax `playGate`/`notPlaying`/`envelopePhase` gates so SPH runs during PLAY. **CAREFUL:** the sculpt
  still drives the pattern; SPH is the *response* layered on top, not a replacement. Play stays cymatics.
- **Verify:** play a note — pattern still forms AND colliding particles react (heat/merge/plasma) instead
  of passing through. Feel-sensitive — get Jamal's explicit verdict. STOP.

### Slice 6 — COMPOSITION / burning-stage scalar (star lifecycle)
- Add ONE composition/burning-stage scalar/particle (H→He→C→O→Si→Fe; needs a real field → widen struct or
  repurpose). Stage transitions by T/ρ ignition thresholds; at SN energy derive via NSE. Couples to color
  (nucleosynthesis tint) + EOS μ.
- **Verify:** a compressed heating star advances stages by T/ρ (not scripted); color/state tracks stage. STOP.

### Slice 7 — VOLUMETRIC sculpt (priority 2 — true 3D)
- Restore a radial eigenfunction in the sculpt (`particles.metal:1336`): multiply the angular harmonic by
  spherical Bessel `j_l(k·r)` (or `besselJ`) → nodal shells × angular cells = 3D volumetric nodes. Tune `k`
  per mode/frequency.
- **Verify:** held note fills a 3D volume (not a hollow shell); camera rotation shows depth. STOP.

---

## 7. INVARIANTS & GOTCHAS (do not violate)

- **FIXED dt.** Never reintroduce frame-rate-tied dt (the proven pump). Hot-gas CFL → fixed-dt accumulator,
  not variable dt.
- **Stale binary/shader.** After any `.metal` edit, confirm `default.metallib` newer than the `.metal`.
  "Did nothing" → suspect stale FIRST.
- **O(N) only.** §2A. ≤32/cell cap, 27-cell scan, fuse passes. Log FPS @2M and @5M every slice; if 2M drops
  below ~60 fps, lighten before proceeding.
- **Conservation watchdog.** Mass, momentum, (no-cooling) energy conserved. Add `[SPH]` total-momentum +
  (KE+u) logs. A violating slice is wrong — find the mechanism, no convenient excuses.
- **Race-free GPU writes.** Read immutable `sortedParticles`; write only your own particle by origin id;
  merges use the compare-and-write guard (`merge_stars:2255`).
- **Speed cap = 3.5c** (`speedCap=3.515`, the warp), not c.
- **Grid resolution:** rest cellSize=1.0; SPH `h≈1.0` can't resolve sub-cell; the horizon/BH (r_s≈1e-4 sim)
  is a SEPARATE later problem (ISCO capture + sub-grid horizon — see BH scale memo). SPH need not resolve it.
- **Cymatics coexistence.** Play stays cymatics; SPH layers on top — verify with Jamal at slice 5.
- **PM gravity is the gravity term.** Reuse `phiBuffer`/bit10 `−∇Φ`; don't add a second gravity.

---

## 8. VERIFICATION METHODOLOGY (you own the running)

- Headless: `./SpaceSynth.app/Contents/MacOS/SpaceSynth >/tmp/ss.log 2>&1 &`; wait via background
  `until grep -c ...` loop (foreground sleep blocked); grep; kill `pkill -f "MacOS/SpaceSynth"`.
- Existing logs: `[GRAV]` (240-frame: live, Mlive/Mtot, Mmax, meanR, maxR, com), `[CLUSTER]` (speed, temp,
  spin), `FPS:` line. Add temporary `[SPH]` logs (ρ row, P, momentum, KE+u, FPS@count); REMOVE once verified.
- Standard reads: (1) cold cluster still HOLDS (regression). (2) gas blob hydrostatic (s2). (3) two-stream
  shock ∝ v_rel² (s3). (4) cooling decay (s4). (5) conservation (momentum/mass/energy). (6) FPS @2M & @5M.
- Jamal owns the visual verdict: build, deploy, `open -n SpaceSynth.app`, say exactly what to look at, STOP.

---

## 9. OPEN DECISIONS / TUNABLES (surface to Jamal, don't silently pick)
Proper dt fix (accumulator vs pinned vs velocity-Verlet); `γ` (5/3 vs 4/3); `α/β` viscosity; cooling rate
& law; smoothing length (fixed `h=cellSize` vs adaptive `h∝(m/ρ)^⅓`); composition fidelity (one scalar vs
small α-chain); the "SPH parcel, collisionless when cold" framing — confirm it reads right.

---

## 10. SOURCES (researched 2026-06-30)
- StarSmasher SPH stellar collisions: https://arxiv.org/pdf/2602.10191 ; high-res SPH:
  https://arxiv.org/pdf/astro-ph/0112284
- Artificial viscosity / shock capture / Rankine-Hugoniot: https://arxiv.org/pdf/2407.10176 ;
  https://arxiv.org/pdf/2202.11084
- Core-collapse SN equation of state + NSE: https://arxiv.org/pdf/1707.06410
- BH scale facts (ISCO=3r_s, "BHs don't suck"): memory `space_synth_bh_scale_research_2026-06-30.md`.

---

## 11. FIRST ACTIONS FOR THE NEW WINDOW (in order)
1. Read this doc fully + the §1 memory files. `git status`/confirm branch `@ aaea1b4` (or later).
2. `bash package_macos.sh`; verify deploy; `open -n SpaceSynth.app`; confirm the cold cluster still HOLDS
   at 2M (regression baseline — dt fix + PM gravity must work before adding SPH).
3. **Slice 0** (fix `MERGE_RSUN_SIM`, allocate SPH buffers) → verify → STOP for Jamal.
4. Proceed slice by slice, ONE verifiable change at a time, Jamal's verdict between each.

Particle envelope: **2M launch / ~5M typical / 7M peak.** Ground every step in real measurement.
Jamal: "science before feel." EMERGE, don't script.
