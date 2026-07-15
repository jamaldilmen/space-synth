#include <metal_stdlib>
using namespace metal;

// ── Spatial Hash Grid for particle-particle interactions ────────────────────
// 256x256 grid over [-1,1]^2 domain. Power-of-2 for fast indexing.
// Three-phase approach: assign cells → count/prefix-sum → scatter to sorted order

struct Particle {
    float4 posW;   // x, y, z, mass
    float4 velW;   // vx, vy, vz, phase
    float4 prevW;  // prevX, prevY, prevZ, temperature
    float4 spinW;  // spinX, spinY, spinZ, charge
    uint4 entanglement; // x: entangledIndex, y: pad1, z: pad2, w: pad3
};

// HOT SORTED RECORD (fps sprint 2026-07-07): every neighbour consumer reads
// ONLY posW + prevW + entanglement — 48B vs the 80B Particle. velW/spinW stay
// in the live buffer (read via entanglement.y when a path truly needs them).
struct SortedHot {
    float4 posW;        // x, y, z, mass
    float4 prevW;       // prev pos + temperature
    uint4  entanglement;// .y = ORIGIN ID (written by scatter)
};

struct SpatialHashUniforms {
    int gridSize;       // 64 (kGridSize)
    int particleCount;
    float cellSize;     // 2*halfExtent / gridSize
    float invCellSize;  // gridSize / (2*halfExtent)
    int gridSizeZ;      // 64
    float halfExtent;   // particle field half-extent in sim coords (e.g. 3.0)
};

// ── Phase 1: Assign each particle to a cell ID ─────────────────────────────

kernel void assign_cells(
    device const Particle* particles [[buffer(0)]],
    device uint* cellIndices [[buffer(1)]],       // output: cell ID per particle
    constant SpatialHashUniforms& u [[buffer(2)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;

    float px = particles[id].posW.x;
    float py = particles[id].posW.y;
    float pz = particles[id].posW.z;

    // Map [-halfExtent, +halfExtent] → [0, gridSize-1]
    int cellX = clamp(int((px + u.halfExtent) * u.invCellSize), 0, u.gridSize - 1);
    int cellY = clamp(int((py + u.halfExtent) * u.invCellSize), 0, u.gridSize - 1);
    int cellZ = clamp(int((pz + u.halfExtent) * u.invCellSize), 0, u.gridSize - 1);

    cellIndices[id] = uint((cellZ * u.gridSize + cellY) * u.gridSize + cellX);
}

// ── Phase 2: Count particles per cell (atomic) ─────────────────────────────

// Per-cell MASS fixed-point scale: cellMass accumulates round(M_sun × 64).
// uint32 headroom: 10M stars × 0.30 M_sun mean × 64 ≈ 1.9e8 ≪ 4.3e9.
constant float MASS_FP = 64.0f;

// FUSED assign+count (fps sprint 2026-07-07): this kernel already read the
// particle for its mass — computing the cell id here too makes the separate
// assign_cells pass (a full extra read+write over 2M particles) redundant.
// Same buffer indices as before; cellIndices is now the OUTPUT.
kernel void count_cells(
    device uint* cellIndices [[buffer(0)]],        // OUT: cell id per particle
    device atomic_uint* cellCounts [[buffer(1)]],
    constant SpatialHashUniforms& u [[buffer(2)]],
    device atomic_uint* cellMass [[buffer(3)]],
    device const Particle* particles [[buffer(4)]],
    device atomic_uint* seedCount [[buffer(5)]],   // BH-seed registry (per frame)
    device uint* seedIds [[buffer(6)]],            // up to 256 seed particle ids
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;

    float4 pw4 = particles[id].posW;
    int cellX = clamp(int((pw4.x + u.halfExtent) * u.invCellSize), 0, u.gridSize - 1);
    int cellY = clamp(int((pw4.y + u.halfExtent) * u.invCellSize), 0, u.gridSize - 1);
    int cellZ = clamp(int((pw4.z + u.halfExtent) * u.invCellSize), 0, u.gridSize - 1);
    uint cellID = uint((cellZ * u.gridSize + cellY) * u.gridSize + cellX);
    cellIndices[id] = cellID;
    // UNCAPPED — cellCounts is the TRUE count, cellMass the TRUE stellar mass
    // (M_sun, fixed-point ×64) for self-gravity. The old `if (current < 128)`
    // guard silently clipped gravity: 50k stars piled in a cell read as mass
    // 128, so "mass piles up → gravity grows" broke above 128/cell and the
    // emergent-BH runaway could never happen. The GPU-stall fear the cap
    // addressed lives in the neighbour-SCAN loops, and those clamp at their
    // read sites (min(count, MAX_PER_CELL) in particles.metal); the signals
    // themselves must stay honest. (Verified: no stall, 120fps @ 3M.)
    // posW.w = stellar mass in M_sun. Dead stars (eaten by a merger, mass 0)
    // and walls are invisible to the grid: neither counted nor weighed. NaN-
    // poisoned stars must not poison the cell: integer test, fast-math-proof.
    float m = pw4.w;
    uint mb = as_type<uint>(m);
    bool finite = ((mb >> 23) & 0xFFu) != 0xFFu;
    if (!finite || m <= 0.001f) return;
    atomic_fetch_add_explicit(&cellCounts[cellID], 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(&cellMass[cellID],
                              uint(m * MASS_FP + 0.5f),
                              memory_order_relaxed);
    // BH-SEED REGISTRY: any body above the IMF ceiling (50 M_sun, must match
    // M_BH_SEED in particles.metal) is a collapsed object — register it so
    // seed_feed can run one dedicated thread per seed. The per-cell merge
    // pass only sees 32 sampled stars per cell; a seed in a 15k-star core
    // cell was sampled 0.2% of frames and STARVED (measured: Mmax froze).
    // Boundary-shell cells excluded: wall-clamped escapers merge artificially
    // out there (see merge_stars) — a wall-born "seed" can never feed and
    // hogs the registry. Interior seeds only.
    if (m >= 50.0f) {
        int g = u.gridSize;
        int bx = int(cellID) % g;
        int by = (int(cellID) / g) % g;
        int bz = int(cellID) / (g * g);
        bool shell = (bx == 0 || by == 0 || bz == 0 ||
                      bx == g - 1 || by == g - 1 || bz == g - 1);
        if (!shell) {
            uint slot = atomic_fetch_add_explicit(seedCount, 1u, memory_order_relaxed);
            if (slot < 1024u) seedIds[slot] = id;
        }
    }
}

// ── Phase 3: Multi-pass Blelloch Prefix Sum ──────────────────────────────────
// Pass 1: Local prefix sum within each threadgroup, outputs into 'cellStarts'.
// It also records the total sum of this block into 'blockSums'.
kernel void prefix_sum_local(
    device uint* cellCounts [[buffer(0)]],
    device uint* cellStarts [[buffer(1)]],
    device uint* blockSums [[buffer(2)]],
    constant SpatialHashUniforms& u [[buffer(3)]],
    uint thread_position_in_threadgroup [[thread_position_in_threadgroup]],
    uint threadgroup_position_in_grid [[threadgroup_position_in_grid]],
    uint threads_per_threadgroup [[threads_per_threadgroup]])
{
    uint tid = thread_position_in_threadgroup;
    uint blockIdx = threadgroup_position_in_grid;
    
    // Each thread processes 2 elements for the Blelloch scan
    uint globalIdx0 = blockIdx * (threads_per_threadgroup * 2) + (tid * 2);
    uint globalIdx1 = globalIdx0 + 1;
    
    threadgroup uint sharedData[2048]; // Max threads per threadgroup = 1024 -> 2048 elements
    
    uint totalCells = u.gridSize * u.gridSize * u.gridSize;
    
    // Load into shared memory
    sharedData[tid * 2]     = (globalIdx0 < totalCells) ? cellCounts[globalIdx0] : 0;
    sharedData[tid * 2 + 1] = (globalIdx1 < totalCells) ? cellCounts[globalIdx1] : 0;
    
    // Up-sweep (reduce) phase
    uint offset = 1;
    for (uint d = threads_per_threadgroup; d > 0; d >>= 1) {
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (tid < d) {
            uint ai = offset * (2 * tid + 1) - 1;
            uint bi = offset * (2 * tid + 2) - 1;
            sharedData[bi] += sharedData[ai];
        }
        offset *= 2;
    }
    
    // Clear the last element and save it to blockSums
    if (tid == 0) {
        if (blockIdx < (totalCells + threads_per_threadgroup * 2 - 1) / (threads_per_threadgroup * 2)) {
            blockSums[blockIdx] = sharedData[threads_per_threadgroup * 2 - 1];
        }
        sharedData[threads_per_threadgroup * 2 - 1] = 0;
    }
    
    // Down-sweep phase
    for (uint d = 1; d < threads_per_threadgroup * 2; d *= 2) {
        offset >>= 1;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (tid < d) {
            uint ai = offset * (2 * tid + 1) - 1;
            uint bi = offset * (2 * tid + 2) - 1;
            uint t = sharedData[ai];
            sharedData[ai] = sharedData[bi];
            sharedData[bi] += t;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Write out results (exclusive prefix sum)
    if (globalIdx0 < totalCells) cellStarts[globalIdx0] = sharedData[tid * 2];
    if (globalIdx1 < totalCells) cellStarts[globalIdx1] = sharedData[tid * 2 + 1];
}

// Pass 2: Prefix sum of the block sums.
// Assuming the number of blocks is small enough to fit within ONE threadgroup (<2048).
// For 65536 cells and 1024 threads, we have 32 blocks (32 < 2048), so one pass is sufficient.
kernel void prefix_sum_blocks(
    device uint* blockSums [[buffer(0)]],
    constant SpatialHashUniforms& u [[buffer(1)]],
    uint thread_position_in_threadgroup [[thread_position_in_threadgroup]],
    uint threads_per_threadgroup [[threads_per_threadgroup]])
{
    uint tid = thread_position_in_threadgroup;
    uint totalCells = u.gridSize * u.gridSize * u.gridSize;
    uint numBlocks = (totalCells + 2047) / 2048; // Max threads = 1024 -> 2048 elements/block
    
    // We only need one threadgroup to scan the block sums
    uint globalIdx0 = tid * 2;
    uint globalIdx1 = globalIdx0 + 1;
    
    threadgroup uint sharedData[2048];
    
    sharedData[tid * 2]     = (globalIdx0 < numBlocks) ? blockSums[globalIdx0] : 0;
    sharedData[tid * 2 + 1] = (globalIdx1 < numBlocks) ? blockSums[globalIdx1] : 0;
    
    uint offset = 1;
    for (uint d = threads_per_threadgroup; d > 0; d >>= 1) {
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (tid < d) {
            uint ai = offset * (2 * tid + 1) - 1;
            uint bi = offset * (2 * tid + 2) - 1;
            sharedData[bi] += sharedData[ai];
        }
        offset *= 2;
    }
    
    if (tid == 0) {
        sharedData[threads_per_threadgroup * 2 - 1] = 0;
    }
    
    for (uint d = 1; d < threads_per_threadgroup * 2; d *= 2) {
        offset >>= 1;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (tid < d) {
            uint ai = offset * (2 * tid + 1) - 1;
            uint bi = offset * (2 * tid + 2) - 1;
            uint t = sharedData[ai];
            sharedData[ai] = sharedData[bi];
            sharedData[bi] += t;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if (globalIdx0 < numBlocks) blockSums[globalIdx0] = sharedData[tid * 2];
    if (globalIdx1 < numBlocks) blockSums[globalIdx1] = sharedData[tid * 2 + 1];
}

// Pass 3: Add the scanned block sums back to the local prefix sums to get global offsets.
kernel void prefix_sum_add(
    device uint* cellStarts [[buffer(0)]],
    device const uint* blockSums [[buffer(1)]],
    constant SpatialHashUniforms& u [[buffer(2)]],
    uint id [[thread_position_in_grid]],
    uint threadgroup_position_in_grid [[threadgroup_position_in_grid]])
{
    uint totalCells = u.gridSize * u.gridSize * u.gridSize;
    if (id >= totalCells) return;
    
    // Add the sum of all preceding blocks to this element's local prefix sum
    cellStarts[id] += blockSums[threadgroup_position_in_grid];
}

// ── Density heatmap: write cell counts to a texture ─────────────────

kernel void density_heatmap(
    device const uint* cellCounts [[buffer(0)]],
    texture2d<float, access::write> densityTex [[texture(0)]],
    constant SpatialHashUniforms& u [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (int(gid.x) >= u.gridSize || int(gid.y) >= u.gridSize) return;

    // For the 2D heatmap, we sum or take a slice. Let's take the middle Z slice for now,
    // or sum them up. Summing provides a better "volumetric" look.
    float totalCount = 0.0f;
    for (int z = 0; z < u.gridSizeZ; z++) {
        int cellID = (z * u.gridSize + int(gid.y)) * u.gridSize + int(gid.x);
        totalCount += float(cellCounts[cellID]);
    }
    float count = totalCount / float(u.gridSizeZ); // Average density along Z

    // Normalize: typical max ~50 particles per cell for 800k in 256x256
    float density = clamp(count / 40.0f, 0.0f, 1.0f);

    // Heatmap colormap (black → blue → cyan → yellow → white)
    float3 color;
    if (density < 0.25f) {
        float t = density / 0.25f;
        color = mix(float3(0.0f), float3(0.0f, 0.0f, 0.5f), t);
    } else if (density < 0.5f) {
        float t = (density - 0.25f) / 0.25f;
        color = mix(float3(0.0f, 0.0f, 0.5f), float3(0.0f, 0.6f, 0.8f), t);
    } else if (density < 0.75f) {
        float t = (density - 0.5f) / 0.25f;
        color = mix(float3(0.0f, 0.6f, 0.8f), float3(0.9f, 0.8f, 0.2f), t);
    } else {
        float t = (density - 0.75f) / 0.25f;
        color = mix(float3(0.9f, 0.8f, 0.2f), float3(1.0f, 1.0f, 1.0f), t);
    }

    // Low opacity so particles show through
    float alpha = density * 0.3f;
    densityTex.write(float4(color * alpha, alpha), gid);
}

// ── Phase 4: Scatter particles into physically sorted order ─────────────────
// Memory optimization: instead of sorting indices which causes cache misses later,
// we physically copy the Particle structs so they are exactly contiguous in memory.

kernel void scatter_particles(
    device const Particle* particlesInput [[buffer(0)]],
    device const uint* cellIndices [[buffer(1)]],
    device uint* cellStarts [[buffer(2)]],         // read (prefix sums)
    device atomic_uint* cellOffsets [[buffer(3)]], // atomic per-cell write offset
    device SortedHot* sortedParticles [[buffer(4)]], // output: HOT sorted records (48B)
    constant SpatialHashUniforms& u [[buffer(5)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;

    // MUST mirror count_cells's skip EXACTLY: cellStarts is the prefix sum of
    // LIVE counts. Scattering a dead/parked star (mass ≤ 0.001 — eaten by a
    // merger) would overflow this cell's allocated range into the NEXT cell's
    // region → the same live star appears in multiple cells' lists → mergers
    // eat it twice → mass CREATION (measured: Mlive tripled at 50k dead).
    {
        float m = particlesInput[id].posW.w;
        uint mb = as_type<uint>(m);
        if (((mb >> 23) & 0xFFu) == 0xFFu || m <= 0.001f) return;
    }

    uint cellID = cellIndices[id];

    // Only scatter if we haven't hit the 32 particle limit for this cell
    uint currentOffset = atomic_load_explicit(&cellOffsets[cellID], memory_order_relaxed);
    if (currentOffset < 32) {
        uint offset = atomic_fetch_add_explicit(&cellOffsets[cellID], 1u, memory_order_relaxed);
        
        // Double check against race conditions
        if (offset < 32) {
            uint writePos = cellStarts[cellID] + offset;
            
            if (int(writePos) < u.particleCount) {
                // HOT copy only — posW/prevW/entanglement (48B, was 80B).
                device const Particle* src = &particlesInput[id];
                SortedHot h;
                h.posW = src->posW;
                h.prevW = src->prevW;
                h.entanglement = src->entanglement;
                h.entanglement.y = id; // original ID
                sortedParticles[writePos] = h;
            }
        }
    }
}

// ── Per-cell centroid (for O(N) grid-based cohesion) ────────────────────────
// One thread per cell: average the positions of the cell's particles from the
// sorted buffer. Total work = N (each particle visited once) → O(N), no
// per-particle neighbour loop. Cohesion then reads the 3×3×3 neighbouring
// centroids to find the local mass centre and pulls toward it — bounded cost,
// can't hit the collision wall. w = particle count (the weight). Scatter caps
// at 32 written per cell, so we only average those.
kernel void compute_cell_centroids(
    device const SortedHot* sortedParticles [[buffer(0)]],
    device const uint* cellStarts [[buffer(1)]],
    device const uint* cellCounts [[buffer(2)]],
    device float4* cellCentroids [[buffer(3)]],
    constant SpatialHashUniforms& u [[buffer(4)]],
    device float4* cellVelocities [[buffer(5)]],
    uint cid [[thread_position_in_grid]])
{
    uint totalCells = uint(u.gridSize) * uint(u.gridSize) * uint(u.gridSizeZ);
    if (cid >= totalCells) return;
    uint count = min(cellCounts[cid], 32u);   // scatter writes ≤32 per cell
    if (count == 0u) {
        cellCentroids[cid] = float4(0.0f);
        cellVelocities[cid] = float4(0.0f);
        return;
    }
    uint start = cellStarts[cid];
    float3 sum = float3(0.0f);
    // Mean LOCAL FLOW velocity (per-frame displacement units, pos − prev).
    // Collisional relaxation in compute_physics damps each star toward this
    // mean: random motions thermalize away, the bulk rotation survives
    // (per-cell momentum conserved) → dense matter settles into a DISK in
    // the plane ⊥ its net angular momentum. Real accretion-disk physics.
    float3 vsum = float3(0.0f);
    // Velocity dispersion σ (for dynamical friction) is built from CLAMPED
    // velocities, decoupled from the mean below. Reason: v = pos−prev is
    // corrupted for teleporting particles (a revived/parked star carries a stale
    // prevW ~4000 → a bogus ~4000/frame "velocity"). The mean averages that
    // away, but the variance is dominated by it. Real per-frame motion ≪ 1 sim,
    // so clamping to ±VCLAMP rejects the teleport spikes without touching real
    // dispersion. The mean (.xyz, used by relaxation) stays UNCLAMPED = identical.
    const float VCLAMP = 0.05f;    // sim/frame ≈ 1.7c (c·dt≈0.029); excludes superluminal
                                   // respawn/teleport artifacts, keeps all real sub-c stars
    float3 vrSum = float3(0.0f);   // Σ v of GENUINE-motion particles (teleports excluded)
    float  v2rSum = 0.0f;
    float  rCount = 0.0f;
    for (uint i = 0u; i < count; i++) {
        float3 pp = sortedParticles[start + i].posW.xyz;
        float3 vv = pp - sortedParticles[start + i].prevW.xyz;
        sum  += pp;
        vsum += vv;                                   // mean: ALL, unclamped (relaxation unchanged)
        if (all(abs(vv) < VCLAMP)) {                  // EXCLUDE teleport spikes from σ
            vrSum  += vv;
            v2rSum += dot(vv, vv);
            rCount += 1.0f;
        }
    }
    cellCentroids[cid] = float4(sum / float(count), float(count));
    // .w = velocity dispersion σ = sqrt(⟨|v|²⟩ − |⟨v⟩|²) over genuine-motion stars
    // only, per-frame units. Feeds Chandrasekhar dynamical friction (X=|v_pec|/(√2·σ)).
    // MEAN is now the CLAMPED mean too (2026-07-12 honest-dynfric rework): the
    // old unclamped mean let ONE teleporting respawn (stale prevW ~4000 sim)
    // poison a cell's flow target by ~100/count sim/frame — and the drag then
    // slammed every real star toward that phantom. Teleports are artifacts,
    // not flow; both moments now exclude them. (bit5 relaxation reads the same
    // mean — same argument.) vsum kept for the count==rCount fast path only.
    float sigma2 = 0.0f;
    float3 vmeanOut = float3(0.0f);
    if (rCount > 0.5f) {
        vmeanOut = vrSum / rCount;
        sigma2 = max(v2rSum / rCount - dot(vmeanOut, vmeanOut), 0.0f);
    } else if (count > 0u) {
        vmeanOut = vsum / float(count); // every member clamped-out: fall back
    }
    cellVelocities[cid] = float4(vmeanOut, sqrt(sigma2));
}

// ── CIC MOMENTS (2026-07-15) — deposit-side anti-aliasing of the velocity-
// moment field (dynfric drag target + Balsara input), env-gated SS_CIC_MOMENTS
// (host-side: these passes are simply not enqueued when the flag is off, so
// the default bed is byte-identical).
// WHY: compute_cell_centroids hard-bins ≤32 sorted members per cell → the
// moment field is CELL-QUANTIZED (a staircase in all three axes). The 07-14
// read-side ±0.5-cell dither only cut the dynfric carver's 20 s amplification
// ×1.7→×1.3 — stacked probes (tools/zprobe.py, 4 runs) showed the coherent
// residual surviving, and the 07-15 t12 build-up ladder proved the super-line
// pancakes need exactly dithered-dynfric + Monaghan viscosity on top of the
// spawn realization's own noise (docs/BUG_lines_2026-07-12.md). A read-side
// dither cannot fix a cell-quantized SOURCE. Cloud-in-cell deposit is the
// textbook source fix: every particle spreads its (teleport-clamped) velocity
// over its 8 surrounding cells with trilinear weights → the moment field is
// continuous piecewise-linear, and the ≤32 subsample bias disappears (ALL
// particles deposit — the sorted-list cap doesn't apply). cellMass, cellCounts
// and cellCentroids (PM gravity ρ, cohesion) are UNTOUCHED.
// Layout: 5 floats per cell — [Σw, Σw·vx, Σw·vy, Σw·vz, Σw·|v|²].

constant uint CIC_M_STRIDE = 5u;

kernel void cic_clear_moments(
    device float* moments [[buffer(0)]],
    constant SpatialHashUniforms& u [[buffer(1)]],
    uint id [[thread_position_in_grid]])
{
    uint total = uint(u.gridSize) * uint(u.gridSize) * uint(u.gridSizeZ)
               * CIC_M_STRIDE;
    if (id < total) moments[id] = 0.0f;
}

kernel void cic_deposit_moments(
    device const Particle* particles [[buffer(0)]],
    device atomic_float*   moments   [[buffer(1)]],
    constant SpatialHashUniforms& u  [[buffer(2)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;
    float4 posW = particles[id].posW;
    if (posW.w <= 0.0f) return;                 // static walls / eaten: not flow
    float3 vv = posW.xyz - particles[id].prevW.xyz;
    // Same teleport exclusion as compute_cell_centroids' VCLAMP: a revived or
    // parked star carries a stale prevW → a bogus ~4000 sim/frame "velocity".
    const float VCLAMP = 0.05f;
    if (!all(abs(vv) < VCLAMP)) return;
    float3 g = (posW.xyz + u.halfExtent) * u.invCellSize - 0.5f; // cell-center coords
    int3 b0 = int3(floor(g));
    float3 fw = clamp(g - float3(b0), 0.0f, 1.0f);
    float v2 = dot(vv, vv);
    for (int dz = 0; dz <= 1; dz++)
    for (int dy = 0; dy <= 1; dy++)
    for (int dx = 0; dx <= 1; dx++) {
        int3 cc = b0 + int3(dx, dy, dz);
        if (cc.x < 0 || cc.y < 0 || cc.z < 0 ||
            cc.x >= u.gridSize || cc.y >= u.gridSize || cc.z >= u.gridSizeZ)
            continue;                            // edge: weight dropped, finalize renormalizes by Σw
        float w = (dx ? fw.x : 1.0f - fw.x) *
                  (dy ? fw.y : 1.0f - fw.y) *
                  (dz ? fw.z : 1.0f - fw.z);
        if (w < 1e-7f) continue;
        uint base = uint((cc.z * u.gridSize + cc.y) * u.gridSize + cc.x)
                  * CIC_M_STRIDE;
        atomic_fetch_add_explicit(&moments[base + 0u], w,        memory_order_relaxed);
        atomic_fetch_add_explicit(&moments[base + 1u], w * vv.x, memory_order_relaxed);
        atomic_fetch_add_explicit(&moments[base + 2u], w * vv.y, memory_order_relaxed);
        atomic_fetch_add_explicit(&moments[base + 3u], w * vv.z, memory_order_relaxed);
        atomic_fetch_add_explicit(&moments[base + 4u], w * v2,   memory_order_relaxed);
    }
}

// Runs AFTER compute_cell_centroids and OVERWRITES cellVelocities with the CIC
// mean + dispersion. Cells with ~no CIC weight keep the centroid-pass value
// (the same fallback role as that kernel's rCount==0 branch).
kernel void cic_finalize_moments(
    device const float* moments   [[buffer(0)]],
    device float4* cellVelocities [[buffer(1)]],
    constant SpatialHashUniforms& u [[buffer(2)]],
    uint cid [[thread_position_in_grid]])
{
    uint total = uint(u.gridSize) * uint(u.gridSize) * uint(u.gridSizeZ);
    if (cid >= total) return;
    uint base = cid * CIC_M_STRIDE;
    float w = moments[base];
    if (w < 1e-3f) return;
    float3 vm = float3(moments[base + 1u],
                       moments[base + 2u],
                       moments[base + 3u]) / w;
    float sig2 = max(moments[base + 4u] / w - dot(vm, vm), 0.0f);
    cellVelocities[cid] = float4(vm, sqrt(sig2));
}

// ── BALSARA SWITCH, per cell (2026-07-12) — the owed bit12 re-enable gate ────
// f = compression / (compression + |∇×v| + eps), compression = max(−∇·v, 0).
// 1 in a compressive shock front, →0 in pure shear — so the Monaghan viscosity
// thermalizes the COLLAPSE (its job) but no longer heats the COLD ROTATING rest
// map into the over-exposed blob + slabs (the 61d3d40 failure). Central
// differences of the per-cell mean flow (cellVelocities.xyz, per-frame units —
// dt cancels in the ratio). Deviation from classic Balsara-1995 (|∇·v|):
// compression-only, since Π exists solely to capture compressive shocks.
// Cells at the domain shell or with any empty face-neighbour get f=0 —
// gradients across empty cells are cloud-edge artifacts, not shocks.
kernel void cell_balsara(
    device const float4* cellVelocities [[buffer(0)]],
    device const uint*   cellCounts     [[buffer(1)]],
    device float*        balsaraOut     [[buffer(2)]],
    constant SpatialHashUniforms& u     [[buffer(3)]],
    uint cid [[thread_position_in_grid]])
{
    int N = u.gridSize;
    uint total = uint(N) * uint(N) * uint(u.gridSizeZ);
    if (cid >= total) return;
    int i = int(cid) % N;
    int j = (int(cid) / N) % N;
    int k = int(cid) / (N * N);
    if (i == 0 || j == 0 || k == 0 || i == N - 1 || j == N - 1 || k == N - 1) {
        balsaraOut[cid] = 0.0f;
        return;
    }
    uint xp = cid + 1u,            xm = cid - 1u;
    uint yp = cid + uint(N),       ym = cid - uint(N);
    uint zp = cid + uint(N * N),   zm = cid - uint(N * N);
    if (cellCounts[xp] == 0u || cellCounts[xm] == 0u ||
        cellCounts[yp] == 0u || cellCounts[ym] == 0u ||
        cellCounts[zp] == 0u || cellCounts[zm] == 0u) {
        balsaraOut[cid] = 0.0f;
        return;
    }
    float3 vxp = cellVelocities[xp].xyz, vxm = cellVelocities[xm].xyz;
    float3 vyp = cellVelocities[yp].xyz, vym = cellVelocities[ym].xyz;
    float3 vzp = cellVelocities[zp].xyz, vzm = cellVelocities[zm].xyz;
    float inv2h = 0.5f * u.invCellSize;
    float divv = (vxp.x - vxm.x + vyp.y - vym.y + vzp.z - vzm.z) * inv2h;
    float3 curl = float3((vyp.z - vym.z) - (vzp.y - vzm.y),
                         (vzp.x - vzm.x) - (vxp.z - vxm.z),
                         (vxp.y - vxm.y) - (vyp.x - vym.x)) * inv2h;
    float comp = max(-divv, 0.0f);
    balsaraOut[cid] = comp / (comp + length(curl) + 1e-5f);
}

// ── SPH DENSITY (reaction engine, slice 1) ──────────────────────────────────
// Smoothed density ρ_i = Σ_j m_j W(|r_ij|, h), cubic-spline kernel (Monaghan
// 1992), h = cellSize. Per particle: scan the 27 neighbour cells, ≤32 samples/
// cell from the sorted buffer → O(N), same cap as every other neighbour pass.
// Includes the self term (j=i, r=0 → W max), which is correct SPH. ρ in
// M_sun / sim³. SLICE 1 = MEASUREMENT ONLY: nothing reads densityOut yet
// (pressure/force = slice 2). Support 2h ≈ 2 cells; the ±1 scan covers the bulk
// (h ≤ cellSize keeps us inside the 27-cell budget — see the plan §3.1).
static inline float sphW(float r, float h) {
    float q = r / h;
    float f;
    if (q < 1.0f)      f = 1.0f - 1.5f * q * q + 0.75f * q * q * q;
    else if (q < 2.0f) { float a = 2.0f - q; f = 0.25f * a * a * a; }
    else               return 0.0f;
    return f / (3.14159265f * h * h * h);
}

// Cubic-spline kernel radial derivative dW/dr (Monaghan 1992), 3D norm 1/(π h⁴).
// ∇_i W_ij = (dW/dr)·(r_ij/|r_ij|). Returns 0 at r=0 (self, no self-force).
static inline float sphGradW(float r, float h) {
    if (r < 1e-8f) return 0.0f;
    float q = r / h;
    float g;
    if (q < 1.0f)      g = -3.0f * q + 2.25f * q * q;
    else if (q < 2.0f) { float a = 2.0f - q; g = -0.75f * a * a; }
    else               return 0.0f;
    return g / (3.14159265f * h * h * h * h);
}

// TILED: one threadgroup per cell (32 threads = one per home-cell slot). Each of the
// 27 neighbour cells is loaded ONCE into threadgroup memory and reused by all home
// particles → 6× faster than the naive per-particle scattered gather (25.7ms vs
// 158ms, measured 2026-07-02). Home particle read from the SORTED buffer (origin id
// in .entanglement.y). Control flow is threadgroup-uniform → all threads hit every
// barrier. OOB write-guard: originId is a read value; a stale slot would fault the GPU.
// ── SPH DENSITY FLOOR (2026-07-12) — EVERY particle gets a physical ρ ───────
// Root fix for the P/ρ² singularity (poison=200k at ring density, [CLOSURE]
// W=−1.8e7): sph_density writes only the ≤32 scattered ids per cell, so an
// unscattered star kept a STALE ρ forever (or the alloc zero → the 1e-12 floor
// → P/ρ² = (γ−1)u/ρ ~ 1e10). Worse, the ≤32-sample kernel sum UNDERCOUNTS a
// 3000-star cell ~100×. This pass runs first, one thread per particle:
//   ρ_floor = max( cellMass(cell)/MASS_FP / h³  — the TRUE uncapped cell mean,
//                  m_self·W(0,h)                — the self-contribution )
// sph_density then only ever RAISES it (max) with the sampled local value.
// cellMass is the same uncapped atomic binning PM gravity trusts.
kernel void sph_density_floor(
    device const Particle* particles    [[buffer(0)]],
    device const uint*     cellMass     [[buffer(1)]],
    constant SpatialHashUniforms& u     [[buffer(2)]],
    device float*          densityOut   [[buffer(3)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;
    float4 pw = particles[id].posW;
    float m = pw.w;
    uint mb = as_type<uint>(m);
    bool finite = ((mb >> 23) & 0xFFu) != 0xFFu;
    float h = u.cellSize;
    if (!finite || m <= 0.001f) { densityOut[id] = 1e-12f; return; } // dead/wall
    int cx2 = clamp(int((pw.x + u.halfExtent) * u.invCellSize), 0, u.gridSize - 1);
    int cy2 = clamp(int((pw.y + u.halfExtent) * u.invCellSize), 0, u.gridSize - 1);
    int cz2 = clamp(int((pw.z + u.halfExtent) * u.invCellSize), 0, u.gridSize - 1);
    uint cID = uint((cz2 * u.gridSize + cy2) * u.gridSize + cx2);
    float rhoCell = (float(cellMass[cID]) * (1.0f / MASS_FP)) / max(h * h * h, 1e-6f);
    float rhoSelf = m * sphW(0.0f, h);
    densityOut[id] = max(rhoCell, rhoSelf);
}

kernel void sph_density(
    device const SortedHot* sortedParticles [[buffer(0)]],
    device const uint*     cellStarts      [[buffer(1)]],
    device const uint*     cellCounts      [[buffer(2)]],
    constant SpatialHashUniforms& u        [[buffer(3)]],
    device float*          densityOut      [[buffer(4)]],
    uint tgid [[threadgroup_position_in_grid]],
    uint tid  [[thread_position_in_threadgroup]])
{
    threadgroup float4 sh[32];   // one neighbour cell's pos+mass, reused per home particle

    uint totalCells = uint(u.gridSize) * uint(u.gridSize) * uint(u.gridSizeZ);
    if (tgid >= totalCells) return;

    uint homeCount = min(cellCounts[tgid], 32u);
    if (homeCount == 0u) return;   // skip empty cells (uniform → no barrier deadlock)
    int cx = int(tgid % uint(u.gridSize));
    int cy = int((tgid / uint(u.gridSize)) % uint(u.gridSize));
    int cz = int(tgid / (uint(u.gridSize) * uint(u.gridSize)));
    // BOUNDARY SHELL EXCLUDED (same rule as merge_stars/reduce_cell_max):
    // assign_cells clamps every escaper outside ±halfExtent into the outermost
    // cells — artificial pileups, not physical density. SPH there produced a
    // systematic momentum drift (measured 2026-07-07: p_z −500 by f≈5000 in
    // every viscosity-on run; none with SPH off).
    {
        int g = u.gridSize;
        if (cx == 0 || cy == 0 || cz == 0 ||
            cx == g - 1 || cy == g - 1 || cz == g - 1) return;
    }

    bool active = tid < homeCount;
    float3 ri = float3(0.0f);
    uint originId = 0u;
    if (active) {
        SortedHot self = sortedParticles[cellStarts[tgid] + tid];
        ri = self.posW.xyz;
        originId = self.entanglement.y;   // scatter stored the original particle id here
    }
    float h = u.cellSize;
    float rho = 0.0f;

    for (int dz = -1; dz <= 1; dz++) {
        int nz = cz + dz; if (nz < 0 || nz >= u.gridSizeZ) continue;
        for (int dy = -1; dy <= 1; dy++) {
            int ny = cy + dy; if (ny < 0 || ny >= u.gridSize) continue;
            for (int dx = -1; dx <= 1; dx++) {
                int nx = cx + dx; if (nx < 0 || nx >= u.gridSize) continue;
                // BOUNDARY-SHELL NEIGHBOURS EXCLUDED — the shell is outside the
                // physical domain for EVERY SPH pass (home cells return above),
                // so shell residents' ρ/P/u are never computed: stale-or-zero ρ
                // with frozen cap-hot u makes a neighbour's P/ρ² = (γ−1)u/ρ
                // singular (~1e10). Reading them as neighbours made every
                // fringe encounter a max-strength kick + a clamp-absorbed du
                // bomb (measured 2026-07-07, [CLOSURE]: dyn/clamp ±1.5e7,
                // anti-correlated — the escaper-fountain pump). Nothing may
                // couple across the shell. (Uniform condition → barrier-safe.)
                if (nx == 0 || ny == 0 || nz == 0 || nx == u.gridSize - 1 ||
                    ny == u.gridSize - 1 || nz == u.gridSizeZ - 1) continue;
                uint ncID    = uint((nz * u.gridSize + ny) * u.gridSize + nx);
                uint ncCount = min(cellCounts[ncID], 32u);
                if (ncCount == 0u) continue;   // empty tile: skip both barriers
                                               // (ncCount is threadgroup-uniform
                                               // → uniform control flow, safe)
                uint ncStart = cellStarts[ncID];
                threadgroup_barrier(mem_flags::mem_threadgroup); // prev cell's readers done
                if (tid < ncCount) sh[tid] = sortedParticles[ncStart + tid].posW;
                threadgroup_barrier(mem_flags::mem_threadgroup); // loads visible
                if (active) {
                    for (uint k = 0u; k < ncCount; k++) {
                        float3 d = ri - sh[k].xyz;
                        rho += sh[k].w * sphW(length(d), h);
                    }
                }
            }
        }
    }
    // Only ever RAISE the floor pass's value: in sparse cells the sampled sum
    // is the better (local) estimate; in dense cells the ≤32-sample sum is a
    // ~100× undercount and the uncapped cell mean must win. max() covers both.
    if (active && originId < uint(u.particleCount))
        densityOut[originId] = max(rho, densityOut[originId]);
}

// ── SPH EOS PRESSURE (reaction engine slice 2) ──────────────────────────────
// Ideal gas P_i = (γ−1)·ρ_i·u_i, γ=5/3. Per-particle, cheap (no neighbours). u =
// specific internal energy (sim units, persistent, cold floor seeded). ρ from
// sph_density. Radiation pressure (a_rad·T⁴/3) deferred to slice 4. Feeds the
// tiled pressure-force pass. SLICE 2 = measurement until the force pass applies it.
kernel void sph_pressure(
    device const float* densityIn   [[buffer(0)]],
    device const float* uIn         [[buffer(1)]],
    constant SpatialHashUniforms& u [[buffer(2)]],
    device float* pressureOut       [[buffer(3)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;
    const float gm1 = 2.0f / 3.0f;   // γ−1, γ = 5/3 monatomic ideal gas
    float rho = densityIn[id];
    float ui  = uIn[id];
    pressureOut[id] = gm1 * rho * max(ui, 0.0f);
}

// ── SPH FORCE + VISCOSITY + ENERGY (reaction engine slices 2b + 3, FUSED) ───
// Tiled (same structure as sph_density): one threadgroup per cell, 32 threads.
// Momentum (Monaghan 1992):
//   a_i = −Σ_j m_j (P_i/ρ_i² + P_j/ρ_j² + Π_ij) ∇_i W_ij
// Π_ij = artificial viscosity — the shock-capture term (slice 3, bit12):
//   approaching (v_ij·r_ij < 0): Π_ij = (−α c̄ μ_ij + β μ_ij²)/ρ̄,
//   μ_ij = h(v_ij·r_ij)/(|r_ij|²+0.01h²), else 0. α, β from params.
// Energy (slice 3, bit12): du_i/dt = Σ_j m_j (P_i/ρ_i² + ½Π_ij)(v_ij·∇_i W_ij)
//   — PdV work + irreversible shock heating (Rankine–Hugoniot entropy). Writes
//   uInOut[originId] directly (each origin id appears once in sorted → race-free).
//   u clamped to [uFloor, uMax]; uMax is the CFL guard (fixed dt can't take
//   arbitrary c_s — proper fix = sub-step accumulator, an owed debt).
// Velocities from the Verlet state: v = (pos − prev)/dt (dt fixed, tcv = 1).
// With params.viscOn == 0 this is EXACTLY the slice-2 kernel (u untouched).
// Output forceOut[originId] = total SPH accel; ADDED to gacc in compute_physics
// (gated bit11) and applied as a·dt² (Verlet).
struct SphForceParams {
    float dt;      // fixed timestep (simt); velocity reconstruction ONLY
    float dtU;     // du integration step = dt × SPH cadence (the passes run
                   // every Nth frame at rest; heat must integrate the skipped
                   // frames too, forces persist in the buffer between passes)
    float alpha;   // Monaghan bulk viscosity coefficient (≈1)
    float beta;    // Monaghan quadratic viscosity coefficient (≈2)
    float uFloor;  // cold floor for u (kUFloorSim)
    float uMax;    // u ceiling: min(relativistic c_s ≤ c/√3, CFL) — see renderer
    float viscOn;  // >0.5 → bit12: viscosity + energy equation active
    float muMax;   // viscous-stability clamp on |μ_ij|: fixed dt can only
                   // integrate v_sig = c̄+0.6(αc̄+βμ) up to ~0.25h/dt; beyond
                   // it the Verlet kick OVERSHOOTS the approach and ejects
                   // pairs (measured 2026-07-06: KE 5.7× baseline at rest).
                   // Clamping μ resolves faster shocks over 2+ frames instead.
    float coolOn;  // >0.5 → bit13 (slice 4): radiative cooling active
    float coolTau; // τ₀ [simt]: cooling e-fold time at T = T_cap and ρ = 1.
                   // Λ ∝ ρT⁴ (optically-thin, plan §3.5): τ(ρ,T) = τ₀/(ρ·(T/T_cap)³)
                   // so du/dt = −(u−floor)/τ ∝ ρT³·u ∝ ρT⁴. Integrated
                   // IMPLICITLY (decay factor) → unconditionally stable, never
                   // undershoots the floor. Replaces the u-cap discard as the
                   // honest energy sink; hot plasma radiates, cold gas untouched.
};

kernel void sph_force(
    device const SortedHot* sortedParticles [[buffer(0)]],
    device const uint*     cellStarts      [[buffer(1)]],
    device const uint*     cellCounts      [[buffer(2)]],
    constant SpatialHashUniforms& u        [[buffer(3)]],
    device const float*    densityIn       [[buffer(4)]],
    device const float*    pressureIn      [[buffer(5)]],
    device float4*         forceOut        [[buffer(6)]],
    constant SphForceParams& p             [[buffer(7)]],
    device float*          uInOut          [[buffer(8)]],
    device atomic_int*     closure         [[buffer(9)]],   // TEMP-CLOSURE ledger ×1e6: [1]=du dyn, [2]=du cool, [3]=du clamp
    device const float*    cellBalsara     [[buffer(10)]],  // per-cell shear/shock switch (cell_balsara)
    uint tgid [[threadgroup_position_in_grid]],
    uint tid  [[thread_position_in_threadgroup]])
{
    threadgroup float4 sh_posm[32];  // neighbour pos.xyz + mass
    threadgroup float3 sh_vel[32];   // neighbour velocity (pos − prev)/dt
    threadgroup float  sh_rho[32];   // neighbour ρ
    threadgroup float  sh_P[32];     // neighbour P
    threadgroup float  sh_c[32];     // neighbour sound speed c_s = √(γP/ρ)

    uint totalCells = uint(u.gridSize) * uint(u.gridSize) * uint(u.gridSizeZ);
    if (tgid >= totalCells) return;

    uint homeCount = min(cellCounts[tgid], 32u);
    if (homeCount == 0u) return;
    int cx = int(tgid % uint(u.gridSize));
    int cy = int((tgid / uint(u.gridSize)) % uint(u.gridSize));
    int cz = int(tgid / (uint(u.gridSize) * uint(u.gridSize)));
    // BOUNDARY SHELL EXCLUDED — same rule and reason as sph_density above.
    {
        int g = u.gridSize;
        if (cx == 0 || cy == 0 || cz == 0 ||
            cx == g - 1 || cy == g - 1 || cz == g - 1) return;
    }

    const float gamma = 5.0f / 3.0f;
    float invDt = 1.0f / max(p.dt, 1e-8f);
    bool viscOn = p.viscOn > 0.5f;

    bool active = tid < homeCount;
    float3 ri = float3(0.0f), vi = float3(0.0f);
    uint originId = 0u;
    float rhoI = 1.0f, Pi = 0.0f, ci = 0.0f, mi = 0.0f;
    if (active) {
        SortedHot self = sortedParticles[cellStarts[tgid] + tid];
        ri = self.posW.xyz;
        vi = (self.posW.xyz - self.prevW.xyz) * invDt;
        mi = self.posW.w;
        originId = self.entanglement.y;
        if (originId < uint(u.particleCount)) {
            rhoI = max(densityIn[originId], 1e-12f);
            Pi   = pressureIn[originId];
        }
        ci = sqrt(gamma * max(Pi, 0.0f) / rhoI);
    }
    float h = u.cellSize;
    // ── SUB-STEP ACCUMULATOR (plan §3.6b, 2026-07-07) ────────────────────────
    // The pair exchange is STIFF at hot close pairs: at fixed dtU the booked
    // |du| reaches the whole thermal budget per step (measured, [CLOSURE] —
    // u telegraphs floor↔cap; residue = the escaper-fountain pump). Positions
    // move ≤3% of h per frame even at c — geometry is resolved; the u↔v
    // exchange is what needs sub-cycling. So: N sub-steps with FROZEN tile
    // geometry (neighbour pos/vel/ρ/P Jacobi-frozen at window start), the
    // particle's OWN velocity and u advanced each sub-step, its P re-derived
    // from the local EOS so the u→P→force feedback is resolved. N is
    // per-cell adaptive from the CFL ratio (threadgroup-uniform via simd_max
    // over the cell's 32 lanes = one simdgroup → barriers stay uniform);
    // cold cells pay nothing (N=1).
    // SUB-STEP CRITERION — SOUND SPEED ONLY (fixed 2026-07-11).
    // This sub-step exists for the THERMAL (u↔v pressure) stiffness — see the
    // note above: "positions move ≤3% of h per frame even at c — geometry is
    // resolved; the u↔v exchange is what needs sub-cycling." Including the BULK
    // velocity |v_i| contradicted that: in a collapsing core the stars are FAST
    // but COLD (u at the floor ⇒ P≈0), so it ran the full 27-cell × 32-neighbour
    // loop up to 8× to compute a force that is essentially ZERO. Measured: it was
    // 100% of the density-dependent cost (compute 21→88 ms as the core densified;
    // flat 12 ms with the pass skipped). Keyed on c_s alone, cold-fast cores cost
    // N=1 and genuinely hot (stiff) regions still sub-cycle exactly as before.
    float myR = active ? ci * p.dtU / max(h, 1e-6f) : 0.0f;
    uint NSub = uint(clamp(ceil(simd_max(myR) * 4.0f), 1.0f, 8.0f));
    float dtSub = p.dtU / float(NSub);
    float u0 = (active && originId < uint(u.particleCount)) ? uInOut[originId]
                                                            : 0.0f;
    float3 viCur = vi;
    float uiCur = u0;
    float3 accSum = float3(0.0f);
    bool subPoison = false;

    for (uint nSub = 0u; nSub < NSub; nSub++) {
    float PiCur = (gamma - 1.0f) * rhoI * uiCur;   // local EOS refresh (= sph_pressure)
    float ciCur = sqrt(gamma * max(PiCur, 0.0f) / rhoI);
    float PiOverRhoI2 = PiCur / (rhoI * rhoI);
    float3 acc = float3(0.0f);
    float dudt = 0.0f;

    for (int dz = -1; dz <= 1; dz++) {
        int nz = cz + dz; if (nz < 0 || nz >= u.gridSizeZ) continue;
        for (int dy = -1; dy <= 1; dy++) {
            int ny = cy + dy; if (ny < 0 || ny >= u.gridSize) continue;
            for (int dx = -1; dx <= 1; dx++) {
                int nx = cx + dx; if (nx < 0 || nx >= u.gridSize) continue;
                // BOUNDARY-SHELL NEIGHBOURS EXCLUDED — same rule and reason as
                // sph_density above: shell residents' ρ/P/u are unmaintained,
                // their P/ρ² is singular, and coupling to them was the
                // fringe kick/du-bomb pump. Nothing crosses the shell.
                if (nx == 0 || ny == 0 || nz == 0 || nx == u.gridSize - 1 ||
                    ny == u.gridSize - 1 || nz == u.gridSizeZ - 1) continue;
                uint ncID    = uint((nz * u.gridSize + ny) * u.gridSize + nx);
                uint ncCount = min(cellCounts[ncID], 32u);
                if (ncCount == 0u) continue;   // empty tile: skip both barriers
                                               // (threadgroup-uniform → safe)
                // BALSARA gate for this pair-tile: mean of the two cells'
                // shear/shock factors. 1 in a compressive shock front, →0 in
                // the rotating rest map's pure shear — the owed bit12 re-enable
                // gate (see cell_balsara + app_state.h uiTogSphVisc note).
                float fBpair = 0.5f * (cellBalsara[tgid] + cellBalsara[ncID]);
                uint ncStart = cellStarts[ncID];
                threadgroup_barrier(mem_flags::mem_threadgroup);
                if (tid < ncCount) {
                    SortedHot nb = sortedParticles[ncStart + tid];
                    sh_posm[tid] = nb.posW;
                    sh_vel[tid]  = (nb.posW.xyz - nb.prevW.xyz) * invDt;
                    uint oj = nb.entanglement.y;
                    float rhoJ = 1e-12f, Pj = 0.0f;
                    if (oj < uint(u.particleCount)) {
                        rhoJ = max(densityIn[oj], 1e-12f);
                        Pj   = pressureIn[oj];
                    }
                    sh_rho[tid] = rhoJ;
                    sh_P[tid]   = Pj;
                    sh_c[tid]   = sqrt(gamma * max(Pj, 0.0f) / rhoJ);
                }
                threadgroup_barrier(mem_flags::mem_threadgroup);
                if (active) {
                    for (uint k = 0u; k < ncCount; k++) {
                        float3 rij = ri - sh_posm[k].xyz;
                        float  r   = length(rij);
                        if (r < 1e-8f) continue;                  // skip self
                        float mj   = sh_posm[k].w;
                        float rhoJ = sh_rho[k];
                        float Pij  = 0.0f;                        // Π_ij
                        float3 vij = viCur - sh_vel[k];
                        float vdotr = dot(vij, rij);
                        float dWdr = sphGradW(r, h);
                        // ── DENSITY GATE on the WHOLE pair term (2026-07-13, visc bed only) ──
                        // v1 of this gate (Π only, 20:03 build) killed the
                        // field-wide thermal blob ([COLOR-TEMP] 0.000 vs 3.1)
                        // but the pump survived as KINETIC energy + momentum:
                        // KEin 59→242/720f, Etot +180 created, the cloud's CoM
                        // drifted 16 sim and σ 14→40 (20:04 log) — with u cold,
                        // the remaining exchanger in the diffuse cloud is the
                        // pressure/viscous FORCE channel (floor-u pressure on
                        // floored ρ + cap-pinned contact grinders, the 07-07
                        // residual pump, now 4–5× hotter). Physics: below SPH-
                        // resolvable density the cloud is COLLISIONLESS — the
                        // bed that measurably collapsed to r50=1.03 today. So in
                        // the visc bed the ENTIRE pair interaction (P force, Π,
                        // du) fades in with pair density: 0 below 200 M☉/sim³
                        // (diffuse ~20), full above 1000 (shell/core 3.6e3–1.8e4).
                        // Force and its du debit scale TOGETHER → books stay
                        // closed. !viscOn (default/show bed) is UNTOUCHED.
                        const float RHO_SPH_LO = 200.0f;   // M_sun/sim³
                        const float RHO_SPH_HI = 1000.0f;
                        float gDensPair = 1.0f;
                        if (viscOn) {
                            gDensPair = smoothstep(RHO_SPH_LO, RHO_SPH_HI,
                                                   0.5f * (rhoI + rhoJ));
                            if (gDensPair < 1e-4f) continue;      // fully collisionless pair
                        }
                        if (viscOn && vdotr < 0.0f) {             // approaching → shock term
                            float mu   = h * vdotr / (r * r + 0.01f * h * h);
                            mu = max(mu, -p.muMax);               // viscous-stability clamp
                            float cbar = 0.5f * (ciCur + sh_c[k]);
                            float rbar = 0.5f * (rhoI + rhoJ);
                            Pij = fBpair * (-p.alpha * cbar * mu + p.beta * mu * mu) / rbar;
                            // PHYSICAL BRAKE BOUND: an explicit viscous impulse
                            // can at most STAGNATE the pair's approach this
                            // step (perfectly inelastic limit) — never reverse
                            // it. Each side may remove ≤ half the approach
                            // speed, so the pair's worst case is exact
                            // cancellation. Without this, fixed-dt overshoot
                            // turns dissipation into a thruster (measured
                            // 2026-07-06: rest cluster E +45%/960f, expanding;
                            // with it the ½Π heating ≤ the KE actually removed
                            // → energy books close by construction).
                            float absdW = max(fabs(dWdr), 1e-12f);
                            // dtU: the force persists for the whole cadence
                            // window, so bound the TOTAL impulse over it.
                            float PijBrake = 0.5f * (-vdotr) /
                                             (r * mj * absdW * dtSub);
                            Pij = min(Pij, PijBrake);
                        }
                        // FREE-EXPANSION BOUND on the PRESSURE impulse — mirror
                        // of the viscous brake above, for the other sign: a
                        // rarefaction cannot accelerate gas beyond the
                        // free-expansion terminal speed 2c̄/(γ−1) = 3c̄. Without
                        // it, a cap-pinned hot pair rides sustained P/ρ² pushes
                        // to ~2.4c escapers, and the start-of-step PdV debit
                        // underpays the work actually done during the kick —
                        // measured 2026-07-07 (PE-instrumented ledger): U climbs
                        // 77→140/8640f and escaper KE 26→452 with PE FLAT =
                        // energy created, cadence-independent (nOut 689 vs 674
                        // @f3600 at cadence 1 vs 2). Bound: this window's
                        // pressure Δv (per side ≤ half) may not push the pair's
                        // separation rate past 3c̄; the du debit uses the SAME
                        // scaled pressure so the books stay closed.
                        float sumP = PiOverRhoI2 + sh_P[k] / (rhoJ * rhoJ);
                        float scaleP = 1.0f;
                        {
                            float aP  = -sumP * mj * dWdr;        // ≥0, repulsive
                            float dvP = aP * dtSub;               // per-side Δv/sub-step
                            float cbar2 = 0.5f * (ciCur + sh_c[k]);
                            float head = max(0.0f, 3.0f * cbar2 - vdotr / r);
                            if (dvP > 0.5f * head)
                                scaleP = 0.5f * head / max(dvP, 1e-20f);
                        }
                        float term = gDensPair * mj * (scaleP * sumP + Pij);
                        acc += (-term * dWdr) * (rij / r);        // ∇_i W along r_ij
                        if (viscOn)                               // PdV + ½Π shock heating
                            dudt += gDensPair * mj * (scaleP * PiOverRhoI2 + 0.5f * Pij) * dWdr * vdotr / r;
                        // TESTED AND REVERTED (2026-07-07): (a) midpoint-velocity
                        // du (KDK-style) — correction is ~4% at measured kick
                        // sizes, no effect on the pump; (b) EXACT exponential
                        // PdV integration u·e^{k·dtU} — stable and honest but
                        // RETAINS the pumped heat the explicit form was
                        // discarding at the u-cap: U climbed ~2× faster
                        // (109→201 vs 99→125 per 5760f). The pump itself is
                        // upstream: cross-cell contact pairs merge_stars cannot
                        // see (same-cell pairing only) grind at r≪h forever —
                        // see docs/ejector_hunt_2026-07-07.md.
                    }
                }
            }
        }
    }
    // ── sub-step advance ──
    // NaN HYGIENE: a poisoned pair (NaN neighbour position/velocity) must not
    // poison viCur/uiCur — zero this sub-step's contribution and count it.
    if (!isfinite(acc.x + acc.y + acc.z)) { acc = float3(0.0f); subPoison = true; }
    if (!isfinite(dudt))                  { dudt = 0.0f;        subPoison = true; }
    accSum += acc;
    // PROVISIONAL KICK CAP — same physical limit the integrator applies
    // (compute_physics clamps real kicks at c·dt). Without it a hot pair adds
    // >c per sub-step and viCur runs away to inf across sub-steps (measured:
    // poison 8–9.7M/window). Δv ≤ c per sub-step; provisional speed ≤ 4c
    // (observed engine states ≤ 2.4c).
    float3 kick = acc * dtSub;
    float kmag = length(kick);
    if (kmag > 1.0f) kick *= 1.0f / kmag;
    viCur += kick;
    float vmag = length(viCur);
    if (vmag > 4.0f) viCur *= 4.0f / vmag;
    if (viscOn)
        uiCur = clamp(uiCur + dudt * dtSub, p.uFloor, p.uMax);
    }  // end sub-step loop

    // TEMP-CLOSURE instrumentation: m-weighted du splits for the energy-closure
    // ledger ([CLOSURE] watchdog line) — dynamics (PdV+Π), cooling, clamp.
    float cDyn = 0.0f, cCool = 0.0f, cClamp = 0.0f;
    bool poisoned = subPoison;
    if (active && originId < uint(u.particleCount)) {
        float3 accMean = accSum / float(NSub);   // mean force over the window
        if (!isfinite(accMean.x + accMean.y + accMean.z)) accMean = float3(0.0f);
        forceOut[originId] = float4(accMean, 0.0f);
        if (viscOn) {
            float uDynRaw = uiCur - u0;   // net dynamics over all sub-steps
            if (!isfinite(uDynRaw)) { poisoned = true; uDynRaw = 0.0f; }
            float ui = u0 + uDynRaw;
            float uc = ui;
            if (p.coolOn > 0.5f && p.coolTau > 1e-6f) {
                // Radiative cooling (slice 4): decay toward the cold floor with
                // τ = τ₀/(ρ·(T/T_cap)³); T/T_cap = u/uMax (same linear map).
                // Implicit: u ← floor + (u−floor)/(1 + dtU/τ). ∝ρT⁴ overall.
                float tRel = clamp(uc / p.uMax, 0.0f, 1.0f);
                float invTau = (rhoI * tRel * tRel * tRel) / p.coolTau;
                uc = p.uFloor + (uc - p.uFloor) / (1.0f + p.dtU * invTau);
            }
            float uf = clamp(uc, p.uFloor, p.uMax);
            uInOut[originId] = uf;
            cDyn   = mi * uDynRaw;
            cCool  = mi * (uc - ui);
            cClamp = mi * (uf - uc);
        }
    }
    // One atomic add per cell-threadgroup (32 lanes = one simdgroup).
    // NON-FINITE GUARD: a single NaN/inf lane turns simd_sum into NaN and
    // int(NaN) slams the counter to ±2^31 (measured: every scale choice
    // reported totals pinned at the int32 boundary). Poisoned lanes are
    // counted in closure[4] instead — the NaN rate is itself diagnostic.
    bool bad = poisoned || !isfinite(cDyn) || !isfinite(cCool) || !isfinite(cClamp);
    if (bad) { cDyn = 0.0f; cCool = 0.0f; cClamp = 0.0f; }
    float sDyn = simd_sum(cDyn), sCool = simd_sum(cCool), sClamp = simd_sum(cClamp);
    uint nBad = simd_sum(bad ? 1u : 0u);
    if (simd_is_first()) {
        atomic_fetch_add_explicit(&closure[1], int(sDyn), memory_order_relaxed);   // ×1.0: ×1e2 saturated at honest ρ
        atomic_fetch_add_explicit(&closure[2], int(sCool), memory_order_relaxed);
        atomic_fetch_add_explicit(&closure[3], int(sClamp), memory_order_relaxed);
        atomic_fetch_add_explicit(&closure[4], int(nBad), memory_order_relaxed);
    }
}

// ── Densest-cell reduce (the emergent-BH signal, Step 2) ────────────────────
// Finds the single densest grid cell (max particle count + its cell id).
// The CPU reads this back, sums the mass in the surrounding neighbourhood,
// and that enclosed mass IS the "has a black hole formed here?" signal —
// geometric criterion (physics canon): a hole exists when the mass inside a
// radius fits within its own Schwarzschild radius. No phase gates.
struct CellMaxPartial {
    uint count;
    uint cid;
};

kernel void reduce_cell_max(
    device const uint* cellCounts [[buffer(0)]],
    device CellMaxPartial* partials [[buffer(1)]],
    constant SpatialHashUniforms& u [[buffer(2)]],
    uint id [[thread_position_in_grid]],
    uint tid [[thread_position_in_threadgroup]],
    uint tgSize [[threads_per_threadgroup]],
    uint tgId [[threadgroup_position_in_grid]])
{
    threadgroup uint sC[256];
    threadgroup uint sI[256];
    uint totalCells = uint(u.gridSize) * uint(u.gridSize) * uint(u.gridSizeZ);
    uint c = (id < totalCells) ? cellCounts[id] : 0u;
    // EXCLUDE the boundary shell: assign_cells clamps every particle outside
    // ±halfExtent into the outermost cells, so those counts are a binning
    // artifact (the whole star map piles into them), not physical density.
    // The emergent core can only be detected in the interior.
    if (id < totalCells) {
        int g = u.gridSize;
        int cx = int(id) % g;
        int cy = (int(id) / g) % g;
        int cz = int(id) / (g * g);
        if (cx == 0 || cy == 0 || cz == 0 ||
            cx == g - 1 || cy == g - 1 || cz == g - 1) c = 0u;
    }
    sC[tid] = c;
    sI[tid] = id;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = tgSize / 2; stride > 0; stride >>= 1) {
        if (tid < stride && sC[tid + stride] > sC[tid]) {
            sC[tid] = sC[tid + stride];
            sI[tid] = sI[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (tid == 0) {
        partials[tgId].count = sC[0];
        partials[tgId].cid   = sI[0];
    }
}

// ── PM GRAVITY: red-black SOR sweep of the Poisson equation ∇²Φ = 4πG·ρ ──────
// The honest energy-conserving self-gravity (2026-06-30). The old per-frame
// centroid/COM attractors were a TIME-VARYING potential → energy was injected
// every frame → the cold cluster heated to the speed cap and dispersed (proven
// by 3-way isolation). Here Φ is a real potential FIELD on the 128³ grid; the
// force in compute_physics is −∇Φ, conservative by construction. One sweep of
// red-black successive-over-relaxation; the host dispatches K sweeps/frame,
// WARM-STARTED from last frame's Φ (the field bares moves per frame → only the
// small change re-converges → cheap and temporally smooth). ρ = cellMass (the
// uncapped Σ of real IMF masses already deposited by count_cells). Dirichlet
// monopole BC at the box edge: Φ = −G·M_tot/r (the field's far potential).
//   sp.x = 4πG_sim   sp.y = gravGM (= G_sim·M_tot, sim units)   color: 0=red 1=black
kernel void poisson_sor(
    device const uint*  cellMass [[buffer(0)]],   // Σ M_sun ×64 per cell (ρ source)
    device float*       phi      [[buffer(1)]],   // 128³ potential, updated IN PLACE
    constant SpatialHashUniforms& u [[buffer(2)]],
    constant float2&    sp       [[buffer(3)]],   // x=4πG_sim, y=gravGM(total)
    constant uint&      color    [[buffer(4)]],   // red-black checkerboard parity
    uint cid [[thread_position_in_grid]])
{
    int N = u.gridSize;
    uint total = uint(N) * uint(N) * uint(u.gridSizeZ);
    if (cid >= total) return;
    int i = int(cid) % N;
    int j = (int(cid) / N) % N;
    int k = int(cid) / (N * N);
    // Update only this pass's colour (red-black GS: disjoint, race-free in place).
    if (((i + j + k) & 1) != int(color)) return;

    float h = u.cellSize;
    // Dirichlet monopole boundary: Φ = −G·M_tot / r at the box edge.
    if (i == 0 || j == 0 || k == 0 || i == N - 1 || j == N - 1 || k == N - 1) {
        float3 p = (float3(i, j, k) + 0.5f) * h - u.halfExtent;
        float  r = max(length(p), h);
        phi[cid] = -sp.y / r;
        return;
    }
    // ρ in M_sun / sim³.
    float rho = (float(cellMass[cid]) * (1.0f / 64.0f)) / (h * h * h);
    // 7-point Laplacian: ∇²Φ = (Σ6 neighbours − 6Φ)/h² = 4πG·ρ
    //   ⇒ Gauss-Seidel target Φ* = (Σ6 − 4πG·ρ·h²)/6.
    float sum = phi[cid + 1u]            + phi[cid - 1u]
              + phi[cid + uint(N)]       + phi[cid - uint(N)]
              + phi[cid + uint(N * N)]   + phi[cid - uint(N * N)];
    float phiStar = (sum - sp.x * rho * h * h) / 6.0f;
    // SOR: over-relax toward the GS target (ω≈1.9, near-optimal for N=128 →
    // ~10× faster low-frequency convergence than plain GS, which is what binds).
    const float omega = 1.9f;
    phi[cid] = phi[cid] + omega * (phiStar - phi[cid]);
}

// ── AMR: PROLONGATION — seed the fine grid with the coarse solution ─────────
// Two-level multigrid, the standard move. SOR on a 128³ box cannot propagate
// boundary information 64 cells to the centre in a practical sweep count, so a
// fine solve started from a stale/zero field leaves the INTERIOR too flat: it
// never picks up the exterior galaxy's gradient, gravity in the patch comes out
// WEAKER than the coarse field, and the core spreads instead of collapsing
// (measured 2026-07-11, slice-2 attempts 1 and 2). Seeding every fine cell with
// the coarse Φ at its world position gives SOR a starting field that ALREADY
// carries the full large-scale gradient; the sweeps then only have to add the
// short-wavelength interior detail — which is exactly what SOR converges on fast.
kernel void prolongate_coarse_to_fine(
    device float*       finePhi   [[buffer(0)]],
    constant SpatialHashUniforms& fu [[buffer(1)]],   // FINE uniforms
    device const float* coarsePhi [[buffer(2)]],
    constant SpatialHashUniforms& cu [[buffer(3)]],   // COARSE uniforms
    device float*       coarsePhiPrev [[buffer(4)]],  // last prolongated coarse Φ (zero at launch)
    uint cid [[thread_position_in_grid]])
{
    // DELTA-PROLONGATION (2026-07-12, slice-2 "moat" fix). Cold-start-only
    // seeding went STALE: the coarse well keeps deepening as the galaxy
    // collapses, but a few SOR sweeps/frame cannot carry that large-scale
    // change into the fine interior — the patch became a relative potential
    // HILL and infall parked in a shell at the ±R_fine rim (measured: peakShell
    // r≈2.2, M<Rfine→0, M(<2) draining). Fix: every solve frame ADD the
    // trilinear CHANGE in coarse Φ since the last prolongation. Tracks the
    // evolving galaxy exactly, preserves the sweeps' accumulated fine detail,
    // stays smooth (no staircase), and cold-starts for free (prev = zeros →
    // first delta = the full seed).
    int N = fu.gridSize;
    uint total = uint(N) * uint(N) * uint(fu.gridSizeZ);
    if (cid >= total) return;
    int i = int(cid) % N;
    int j = (int(cid) / N) % N;
    int k = int(cid) / (N * N);
    float3 p = (float3(i, j, k) + 0.5f) * fu.cellSize - fu.halfExtent;  // world pos
    int Nc = cu.gridSize;
    // TRILINEAR prolongation (2026-07-12 slice-2 fix). The old NEAREST-cell
    // sample seeded a 32-fine-cell STAIRCASE every solve frame; 16 SOR sweeps
    // cannot smooth the step faces, so −∇Φ_fine was ~zero inside blocks with
    // spike-kicks at coarse-cell faces — measured: mass EJECTED from the fine
    // box (M<Rfine→0), core unbound. Standard multigrid prolongation is
    // (tri)linear: the seed then carries the coarse field's smooth gradient
    // everywhere and the sweeps only add interior detail.
    float3 g = (p + cu.halfExtent) * cu.invCellSize - 0.5f;   // coarse cell-center coords
    int3 c0 = int3(clamp(int(floor(g.x)), 0, Nc - 1),
                   clamp(int(floor(g.y)), 0, Nc - 1),
                   clamp(int(floor(g.z)), 0, Nc - 1));
    int3 c1 = min(c0 + 1, Nc - 1);
    float3 f = clamp(g - float3(c0), 0.0f, 1.0f);
    #define CPHI(ci, cj, ck) coarsePhi[uint(((ck) * Nc + (cj)) * Nc + (ci))]
    float p00 = mix(CPHI(c0.x, c0.y, c0.z), CPHI(c1.x, c0.y, c0.z), f.x);
    float p10 = mix(CPHI(c0.x, c1.y, c0.z), CPHI(c1.x, c1.y, c0.z), f.x);
    float p01 = mix(CPHI(c0.x, c0.y, c1.z), CPHI(c1.x, c0.y, c1.z), f.x);
    float p11 = mix(CPHI(c0.x, c1.y, c1.z), CPHI(c1.x, c1.y, c1.z), f.x);
    #undef CPHI
    float sampleNew = mix(mix(p00, p10, f.y), mix(p01, p11, f.y), f.z);
    finePhi[cid] += sampleNew - coarsePhiPrev[cid];  // add the coarse CHANGE only
    coarsePhiPrev[cid] = sampleNew;                  // remember what we've injected
}

// ── AMR: FINE POISSON with NESTED (coarse-Φ) BOUNDARY ───────────────────────
// The fine patch does NOT live in isolation — it sits INSIDE the galaxy. Its
// boundary must therefore carry the COARSE potential (which contains all the
// mass outside the patch), not a monopole of the patch's own tiny interior mass.
// Solving with an interior-only BC threw away ~590k M_sun of exterior gravity →
// gravity got WEAKER inside the patch and the core spread out (measured
// 2026-07-11, slice-2 first attempt). This is the standard nested-mesh /
// zoom-in BC: Φ_fine|boundary = Φ_coarse(x). Interior is then solved at fine
// resolution, so we get the full field AND sub-cell structure.
kernel void poisson_sor_fine(
    device const uint*  fineCellMass [[buffer(0)]],  // fine ρ source (Σ M_sun ×64)
    device float*       finePhi      [[buffer(1)]],  // fine Φ, updated in place
    constant SpatialHashUniforms& fu [[buffer(2)]],  // FINE uniforms (halfExtent = R_fine)
    constant float2&    sp           [[buffer(3)]],  // x = 4πG_sim (y unused here)
    constant uint&      color        [[buffer(4)]],  // red-black parity
    device const float* coarsePhi    [[buffer(5)]],  // COARSE Φ — supplies the boundary
    constant SpatialHashUniforms& cu [[buffer(6)]],  // COARSE uniforms
    uint cid [[thread_position_in_grid]])
{
    int N = fu.gridSize;
    uint total = uint(N) * uint(N) * uint(fu.gridSizeZ);
    if (cid >= total) return;
    int i = int(cid) % N;
    int j = (int(cid) / N) % N;
    int k = int(cid) / (N * N);
    if (((i + j + k) & 1) != int(color)) return;

    float h = fu.cellSize;
    // Boundary: sample the COARSE potential at this fine cell's world position
    // (nearest-cell; the coarse field is smooth at its own 1-sim scale).
    if (i == 0 || j == 0 || k == 0 || i == N - 1 || j == N - 1 || k == N - 1) {
        float3 p = (float3(i, j, k) + 0.5f) * h - fu.halfExtent;   // world pos
        int Nc = cu.gridSize;
        int ci = clamp(int((p.x + cu.halfExtent) * cu.invCellSize), 0, Nc - 1);
        int cj = clamp(int((p.y + cu.halfExtent) * cu.invCellSize), 0, Nc - 1);
        int ck = clamp(int((p.z + cu.halfExtent) * cu.invCellSize), 0, Nc - 1);
        finePhi[cid] = coarsePhi[uint((ck * Nc + cj) * Nc + ci)];
        return;
    }
    float rho = (float(fineCellMass[cid]) * (1.0f / 64.0f)) / (h * h * h);
    float sum = finePhi[cid + 1u]            + finePhi[cid - 1u]
              + finePhi[cid + uint(N)]       + finePhi[cid - uint(N)]
              + finePhi[cid + uint(N * N)]   + finePhi[cid - uint(N * N)];
    float phiStar = (sum - sp.x * rho * h * h) / 6.0f;
    const float omega = 1.9f;
    finePhi[cid] = finePhi[cid] + omega * (phiStar - finePhi[cid]);
}

// ── AMR SLICE 1 (2026-07-11): FINE-GRID MASS BINNING ────────────────────────
// Bins stellar mass into a SECOND, fine 128³ grid over ±halfExtent = R_fine at
// the origin (the core, pinned there by comShift). Unlike count_cells this does
// NOT edge-clamp: a particle OUTSIDE the fine box is SKIPPED, not folded onto
// the boundary — the fine source must be the true interior mass only. The fine
// Φ is then solved by the SAME poisson_sor with these fine uniforms; its BC
// monopole (sp.y) is gmSim(M within R_fine), computed CPU-side. Force wiring is
// Slice 2 — this pass is measurement-only (does the fine well resolve deeper?).
kernel void bin_fine_mass(
    device const Particle* particles [[buffer(0)]],
    device atomic_uint*    fineCellMass [[buffer(1)]],
    constant SpatialHashUniforms& fu [[buffer(2)]],   // FINE uniforms (halfExtent=R_fine)
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= fu.particleCount) return;
    float4 pw = particles[id].posW;
    float m = pw.w;
    uint mb = as_type<uint>(m);
    bool finite = ((mb >> 23) & 0xFFu) != 0xFFu;
    if (!finite || m <= 0.001f) return;                       // dead/wall/NaN
    if (fabs(pw.x) >= fu.halfExtent || fabs(pw.y) >= fu.halfExtent ||
        fabs(pw.z) >= fu.halfExtent) return;                  // OUTSIDE the fine box → skip (no clamp)
    int cx = clamp(int((pw.x + fu.halfExtent) * fu.invCellSize), 0, fu.gridSize - 1);
    int cy = clamp(int((pw.y + fu.halfExtent) * fu.invCellSize), 0, fu.gridSize - 1);
    int cz = clamp(int((pw.z + fu.halfExtent) * fu.invCellSize), 0, fu.gridSize - 1);
    uint cID = uint((cz * fu.gridSize + cy) * fu.gridSize + cx);
    atomic_fetch_add_explicit(&fineCellMass[cID], uint(m * MASS_FP + 0.5f), memory_order_relaxed);
}
