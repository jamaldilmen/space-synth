#include <metal_stdlib>
using namespace metal;

// ── Spatial Hash Grid for particle-particle interactions ────────────────────
// 256x256 grid over [-1,1]^2 domain. Power-of-2 for fast indexing.
// Three-phase approach: assign cells → count/prefix-sum → scatter to sorted order

struct Particle {
    float4 posW;   // x, y, z, mass
    float4 velW;   // vx, vy, vz, phase
};

struct SpatialHashUniforms {
    int gridSize;       // 256
    int particleCount;
    float cellSize;     // 2.0 / gridSize
    float invCellSize;  // gridSize / 2.0
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

    // Map [-1,1] → [0, gridSize-1]
    int cellX = clamp(int((px + 1.0f) * u.invCellSize), 0, u.gridSize - 1);
    int cellY = clamp(int((py + 1.0f) * u.invCellSize), 0, u.gridSize - 1);

    cellIndices[id] = uint(cellY * u.gridSize + cellX);
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

// ── Phase 3: Prefix sum on cell counts → cell start offsets ─────────────────
// Optimized: Threadgroup parallel prefix sum using SIMD primitives.

kernel void prefix_sum_cells(
    device uint* cellCounts [[buffer(0)]],
    device uint* cellStarts [[buffer(1)]],
    constant SpatialHashUniforms& u [[buffer(2)]],
    uint thread_position_in_grid [[thread_position_in_grid]],
    uint thread_position_in_threadgroup [[thread_position_in_threadgroup]],
    uint threadgroups_per_grid [[threadgroups_per_grid]])
{
    // A single threadgroup handles the entire 65536 cell array 
    // by having each thread iterate over a chunk. 
    // This is vastly faster than a single thread doing 65k operations.
    
    int totalCells = u.gridSize * u.gridSize;
    uint numThreads = 1024; // We will dispatch exactly 1 threadgroup of 1024 threads
    int cellsPerThread = (totalCells + numThreads - 1) / numThreads;
    
    uint tid = thread_position_in_threadgroup;
    int startIdx = tid * cellsPerThread;
    int endIdx = min(startIdx + cellsPerThread, totalCells);
    
    // Step 1: Compute local thread sum
    uint localSum = 0;
    for (int i = startIdx; i < endIdx; i++) {
        localSum += cellCounts[i];
    }
    
    // Step 2: Threadgroup prefix sum of localSums using threadgroup memory
    threadgroup uint sharedSums[1024];
    sharedSums[tid] = localSum;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Naive prefix sum in shared memory (fast enough for 1024 elements)
    uint offset = 0;
    for (uint offset_step = 1; offset_step < numThreads; offset_step *= 2) {
        uint val = 0;
        if (tid >= offset_step) val = sharedSums[tid - offset_step];
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (tid >= offset_step) sharedSums[tid] += val;
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // The exclusive offset for this thread is the sum built up strictly BEFORE this thread
    uint threadBaseOffset = (tid == 0) ? 0 : sharedSums[tid - 1];
    
    // Step 3: Write out final prefix sums
    uint currentOffset = threadBaseOffset;
    for (int i = startIdx; i < endIdx; i++) {
        cellStarts[i] = currentOffset;
        currentOffset += cellCounts[i];
    }
}

// ── Density heatmap: write cell counts to a texture ─────────────────

kernel void density_heatmap(
    device const uint* cellCounts [[buffer(0)]],
    texture2d<float, access::write> densityTex [[texture(0)]],
    constant SpatialHashUniforms& u [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (int(gid.x) >= u.gridSize || int(gid.y) >= u.gridSize) return;

    int cellID = int(gid.y) * u.gridSize + int(gid.x);
    float count = float(cellCounts[cellID]);

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
        sortedParticles[writePos] = particlesInput[id];
    }
}
