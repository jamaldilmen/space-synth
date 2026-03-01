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
    device uint* particleIndices [[buffer(2)]],    // output: identity mapping (will be sorted)
    constant SpatialHashUniforms& u [[buffer(3)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;

    float px = particles[id].posW.x;
    float py = particles[id].posW.y;

    // Map [-1,1] → [0, gridSize-1]
    int cellX = clamp(int((px + 1.0f) * u.invCellSize), 0, u.gridSize - 1);
    int cellY = clamp(int((py + 1.0f) * u.invCellSize), 0, u.gridSize - 1);

    cellIndices[id] = uint(cellY * u.gridSize + cellX);
    particleIndices[id] = id;
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
// Simple serial scan — runs on 1 threadgroup for 65536 cells (fast enough)

kernel void prefix_sum_cells(
    device uint* cellCounts [[buffer(0)]],
    device uint* cellStarts [[buffer(1)]],
    constant SpatialHashUniforms& u [[buffer(2)]],
    uint id [[thread_position_in_grid]])
{
    int totalCells = u.gridSize * u.gridSize;

    // Single-thread serial scan for 65536 cells (fast enough at ~0.1ms)
    if (id == 0) {
        uint running = 0;
        for (int i = 0; i < totalCells; i++) {
            uint count = cellCounts[i];
            cellStarts[i] = running;
            running += count;
        }
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

// ── Phase 4: Scatter particles into sorted order ────────────────────────────

kernel void scatter_particles(
    device const uint* cellIndices [[buffer(0)]],
    device const uint* particleIndices [[buffer(1)]],
    device uint* cellStarts [[buffer(2)]],         // read (prefix sums)
    device atomic_uint* cellOffsets [[buffer(3)]],  // atomic per-cell write offset
    device uint* sortedIndices [[buffer(4)]],       // output: particle IDs in cell order
    constant SpatialHashUniforms& u [[buffer(5)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;

    uint cellID = cellIndices[id];
    uint offset = atomic_fetch_add_explicit(&cellOffsets[cellID], 1u, memory_order_relaxed);
    uint writePos = cellStarts[cellID] + offset;

    if (int(writePos) < u.particleCount) {
        sortedIndices[writePos] = particleIndices[id];
    }
}
