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

kernel void count_cells(
    device const uint* cellIndices [[buffer(0)]],
    device atomic_uint* cellCounts [[buffer(1)]],
    constant SpatialHashUniforms& u [[buffer(2)]],
    device atomic_uint* cellMass [[buffer(3)]],
    device const Particle* particles [[buffer(4)]],
    device atomic_uint* seedCount [[buffer(5)]],   // BH-seed registry (per frame)
    device uint* seedIds [[buffer(6)]],            // up to 256 seed particle ids
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;

    uint cellID = cellIndices[id];
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
    float m = particles[id].posW.w;
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
            if (slot < 256u) seedIds[slot] = id;
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
    device Particle* sortedParticles [[buffer(4)]], // output: physical sorted structs
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
                // Physical memory copy to ensure contiguous access during collisions!
                Particle p = particlesInput[id];
                p.entanglement.y = id; // Store original ID for entanglement tracking
                sortedParticles[writePos] = p;
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
    device const Particle* sortedParticles [[buffer(0)]],
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
    float3 vmean = vsum / float(count);
    cellCentroids[cid] = float4(sum / float(count), float(count));
    // .w = velocity dispersion σ = sqrt(⟨|v|²⟩ − |⟨v⟩|²) over genuine-motion stars
    // only, per-frame units. Feeds Chandrasekhar dynamical friction (X=|v_pec|/(√2·σ)).
    float sigma2 = 0.0f;
    if (rCount > 0.5f) {
        float3 vrMean = vrSum / rCount;
        sigma2 = max(v2rSum / rCount - dot(vrMean, vrMean), 0.0f);
    }
    cellVelocities[cid] = float4(vmean, sqrt(sigma2));
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
