// MEASURE N — step 1 of DESIGN_2026-07-28_field_sonification.md §10.
// Standalone: does NOT touch the app. Sweeps N and reports GPU time per audio
// block, so the architecture decision in §8 rests on a number rather than a
// guess.
//
// THE BUDGET, stated explicitly so the verdict is reproducible:
//   audio block = 512 frames @ 48 kHz = 10.667 ms of sound.
//   BUT the synthesis shares one GPU with the renderer. SPACE Synth runs
//   64-120 fps (measured in tonight's logs), so a frame is 8.3-15.6 ms and the
//   sim already owns most of it. Audio may take only a slice.
//   Reported against three budgets:
//     100%  of a block (10.667 ms) — audio alone, renderer starved. Upper bound.
//      25%  (2.667 ms) — aggressive but plausible share.
//      10%  (1.067 ms) — safe share alongside a 2M-particle sim.

#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include <cstdio>
#include <vector>
#include <cmath>
#include <algorithm>

static const uint32_t BLOCK = 512;
static const uint32_t CHUNK = 1024;
static const double   SR    = 48000.0;

struct OscState { float freq, amp, phase, pad; };

int main(int argc, const char **argv) {
  @autoreleasepool {
    id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
    if (!dev) { fprintf(stderr, "no Metal device\n"); return 1; }
    printf("device: %s\n", [[dev name] UTF8String]);
    printf("unified memory: %s\n", dev.hasUnifiedMemory ? "yes" : "no");
    printf("max threadgroup memory: %lu B\n",
           (unsigned long)dev.maxThreadgroupMemoryLength);

    NSError *err = nil;
    NSString *path = @"tools/measure_n/osc.metallib";
    id<MTLLibrary> lib = [dev newLibraryWithURL:[NSURL fileURLWithPath:path] error:&err];
    if (!lib) { fprintf(stderr, "lib load failed: %s\n",
                        [[err localizedDescription] UTF8String]); return 1; }

    id<MTLComputePipelineState> pSum =
        [dev newComputePipelineStateWithFunction:[lib newFunctionWithName:@"osc_sum"] error:&err];
    id<MTLComputePipelineState> pRed =
        [dev newComputePipelineStateWithFunction:[lib newFunctionWithName:@"osc_reduce"] error:&err];
    if (!pSum || !pRed) { fprintf(stderr, "pipeline failed: %s\n",
                                  [[err localizedDescription] UTF8String]); return 1; }

    id<MTLCommandQueue> q = [dev newCommandQueue];

    const uint32_t Ns[] = { 1000, 10000, 100000, 250000, 500000,
                            1000000, 2000000, 4000000 };
    const uint32_t maxN = 4000000;

    // Per-particle state, filled with plausible audible values so the sine unit
    // is doing real work (denormals/zeros can be optimised differently).
    id<MTLBuffer> bState = [dev newBufferWithLength:sizeof(OscState) * maxN
                                            options:MTLResourceStorageModeShared];
    OscState *st = (OscState *)bState.contents;
    for (uint32_t i = 0; i < maxN; ++i) {
      double hz = 40.0 + (double)(i % 8000) * 0.5;      // 40 Hz .. 4040 Hz
      st[i].freq  = (float)(2.0 * M_PI * hz / SR);
      st[i].amp   = 1.0f / 2048.0f;
      st[i].phase = (float)((i * 0.61803398875) * 2.0 * M_PI);
      st[i].pad   = 0.0f;
    }

    id<MTLBuffer> bOut = [dev newBufferWithLength:sizeof(float) * BLOCK
                                          options:MTLResourceStorageModeShared];

    printf("\n  audio block = %u frames @ %.0f Hz = %.3f ms\n",
           BLOCK, SR, 1000.0 * BLOCK / SR);
    printf("\n%10s %12s %12s %12s   %s\n",
           "N", "ms/block", "%of block", "Mosc/s", "verdict vs budgets");
    printf("%s\n", "--------------------------------------------------------------------------------");

    const double blockMs = 1000.0 * BLOCK / SR;

    for (uint32_t N : Ns) {
      uint32_t perGroup = CHUNK * 8;                       // particles per threadgroup
      uint32_t nGroups  = (N + perGroup - 1) / perGroup;
      if (nGroups < 1) nGroups = 1;

      id<MTLBuffer> bPart = [dev newBufferWithLength:sizeof(float) * BLOCK * nGroups
                                             options:MTLResourceStorageModePrivate];

      // warmup + timed runs; take the MINIMUM (least contended = the honest
      // best case for this structure, and the one an architecture decision
      // should be made against).
      double best = 1e9;
      for (int rep = 0; rep < 12; ++rep) {
        id<MTLCommandBuffer> cb = [q commandBuffer];
        id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
        [e setComputePipelineState:pSum];
        [e setBuffer:bState offset:0 atIndex:0];
        [e setBuffer:bPart  offset:0 atIndex:1];
        [e setBytes:&N        length:sizeof(uint32_t) atIndex:2];
        [e setBytes:&perGroup length:sizeof(uint32_t) atIndex:3];
        [e dispatchThreadgroups:MTLSizeMake(nGroups, 1, 1)
          threadsPerThreadgroup:MTLSizeMake(BLOCK, 1, 1)];
        [e setComputePipelineState:pRed];
        [e setBuffer:bPart offset:0 atIndex:0];
        [e setBuffer:bOut  offset:0 atIndex:1];
        [e setBytes:&nGroups length:sizeof(uint32_t) atIndex:2];
        [e dispatchThreadgroups:MTLSizeMake(1, 1, 1)
          threadsPerThreadgroup:MTLSizeMake(BLOCK, 1, 1)];
        [e endEncoding];
        [cb commit];
        [cb waitUntilCompleted];
        if (rep >= 2) {  // discard warmup
          double ms = (cb.GPUEndTime - cb.GPUStartTime) * 1000.0;
          best = std::min(best, ms);
        }
      }

      double pct    = 100.0 * best / blockMs;
      double moscps = (double)N * SR / 1e6;   // oscillator-samples per second, millions

      const char *verdict;
      if      (best <= 0.10 * blockMs) verdict = "fits 10% share  ✅";
      else if (best <= 0.25 * blockMs) verdict = "fits 25% share  ⚠️";
      else if (best <= blockMs)        verdict = "audio-only, starves renderer";
      else                             verdict = "DOES NOT REALTIME  ❌";

      printf("%10u %12.3f %11.1f%% %12.0f   %s\n", N, best, pct, moscps, verdict);
      fflush(stdout);
    }

    // sanity: output must be finite and non-trivial, else we timed nothing real
    const float *o = (const float *)bOut.contents;
    double sum = 0.0; bool finite = true;
    for (uint32_t i = 0; i < BLOCK; ++i) {
      sum += fabs(o[i]);
      if (!std::isfinite(o[i])) finite = false;
    }
    printf("\nsanity: output finite=%s  mean|sample|=%.6f  (must be >0, else the\n"
           "        kernel was optimised away and every number above is a lie)\n",
           finite ? "yes" : "NO", sum / BLOCK);
  }
  return 0;
}
