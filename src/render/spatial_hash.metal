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
    int gridSize;       // 256
    int particleCount;
    float cellSize;     // 2.0 / gridSize
    float invCellSize;  // gridSize / 2.0
    int gridSizeZ;      // 32
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

    // Map [-1,1] → [0, gridSize-1]
    int cellX = clamp(int((px + 1.0f) * u.invCellSize), 0, u.gridSize - 1);
    int cellY = clamp(int((py + 1.0f) * u.invCellSize), 0, u.gridSize - 1);
    int cellZ = clamp(int((pz + 1.0f) * u.invCellSize), 0, u.gridSize - 1);

    cellIndices[id] = uint((cellZ * u.gridSize + cellY) * u.gridSize + cellX);
}

// ── Phase 2: Count particles per cell (atomic) ─────────────────────────────

kernel void count_cells(
    device const uint* cellIndices [[buffer(0)]],
    device atomic_uint* cellCounts [[buffer(1)]],
    constant SpatialHashUniforms& u [[buffer(2)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;
    atomic_fetch_add_explicit(&cellCounts[cellIndices[id]], 1u, memory_order_relaxed);
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

    uint cellID = cellIndices[id];
    uint offset = atomic_fetch_add_explicit(&cellOffsets[cellID], 1u, memory_order_relaxed);
    uint writePos = cellStarts[cellID] + offset;
    
    if (int(writePos) < u.particleCount) {
        // Physical memory copy to ensure contiguous access during collisions!
        Particle p = particlesInput[id];
        p.entanglement.y = id; // Store original ID for entanglement tracking
        sortedParticles[writePos] = p;
    }
}
