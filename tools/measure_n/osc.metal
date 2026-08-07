// MEASURE N — step 1 of DESIGN_2026-07-28_field_sonification.md §10.
//
// "GPU sum of N oscillators at audio rate; sweep N until the frame budget
//  breaks. No musical content. Output the number."
//
// §8 is explicit that the BINDING CONSTRAINT IS MEMORY BANDWIDTH, not
// arithmetic: the sum must read per-particle state every block. So the kernel
// below is written to read each particle's state EXACTLY ONCE per block and
// then generate all BLOCK samples from registers — which is both the fastest
// honest structure and the one that puts the measurement on the real
// constraint. A naive "one threadgroup per output sample" version would read
// state BLOCK times over (512·N reads) and would measure the wrong thing.
//
// Structure, per threadgroup:
//   1. cooperatively load CHUNK particles' state into threadgroup memory
//   2. each of the BLOCK threads owns ONE output sample and sums those CHUNK
//      oscillators into it
//   3. repeat for every chunk this group owns; write one BLOCK-sample partial
// A second kernel reduces the partials. Reads: N per block. Arithmetic:
// N·BLOCK per block. That is the real shape of the work.

#include <metal_stdlib>
using namespace metal;

constant uint BLOCK = 512;    // audio frames per callback (matches synth.cpp)
constant uint CHUNK = 1024;   // particles staged in threadgroup memory at once

struct OscState {
    float freq;    // radians per sample (phase increment)
    float amp;     // linear gain
    float phase;   // current phase [rad]
    float pad;     // 16B align — mirrors a realistic per-particle struct read
};

kernel void osc_sum(device const OscState *state    [[buffer(0)]],
                    device float         *partials  [[buffer(1)]],
                    constant uint        &N         [[buffer(2)]],
                    constant uint        &perGroup  [[buffer(3)]],
                    uint gid  [[threadgroup_position_in_grid]],
                    uint tid  [[thread_position_in_threadgroup]])
{
    threadgroup OscState sh[CHUNK];

    float acc = 0.0f;                 // this thread's output sample
    const uint sampleIdx = tid;       // one thread == one sample in the block

    const uint begin = gid * perGroup;
    const uint end   = min(begin + perGroup, N);

    for (uint base = begin; base < end; base += CHUNK) {
        const uint n = min(CHUNK, end - base);

        // 1. cooperative load — each particle's state read ONCE per block
        for (uint i = tid; i < n; i += BLOCK) {
            sh[i] = state[base + i];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        // 2. sum this chunk's oscillators into MY sample
        for (uint i = 0; i < n; ++i) {
            const OscState o = sh[i];
            acc += o.amp * precise::sin(o.phase + o.freq * float(sampleIdx));
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    partials[gid * BLOCK + sampleIdx] = acc;
}

// Reduce the per-group partials into the final BLOCK samples.
kernel void osc_reduce(device const float *partials [[buffer(0)]],
                       device float       *out      [[buffer(1)]],
                       constant uint      &nGroups  [[buffer(2)]],
                       uint tid [[thread_position_in_grid]])
{
    float s = 0.0f;
    for (uint g = 0; g < nGroups; ++g) s += partials[g * BLOCK + tid];
    out[tid] = s;
}
