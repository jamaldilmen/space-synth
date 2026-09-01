# INSTRUMENT #4 — STAGE-BOUNDARY GPU COUNTERS — SPEC FOR OPUS

**Written:** 2026-08-31 22:06:16 by BRAIN. **Builder: OPUS** (holds the build token, owns `src/**`).
**His order 2026-08-31:** *"build the counter sample buffer instrument"*, then *"spec it and hand it to opus"*.
**Supersedes** the `SS_LENS_ONLY` double-encode fallback as second choice — see §1.3.

> ⛔ **BRAIN did not touch `src/**`.** Everything below was verified against the SDK headers and against
> **two standalone Metal probes** run outside the app (`scratchpad/probe.m`, `scratchpad/stage.m`), never
> by building SpaceSynth. The probe sources are reproduced in §6 so OPUS can re-run them independently.

---

## 0. WHAT THIS INSTRUMENT IS FOR, IN ONE LINE

`[BOARD §Z7]` Three instruments have failed to price the B2a lens march, **all three returning an impossible
negative sign**, because they all timed something larger than the pass. Instrument #4 times the **lens
encoder's own GPU stage span**, inside the main command buffer, with no subtraction anywhere.

---

## 1. THE THREE HARDWARE FACTS THAT SHAPE THE DESIGN — MEASURED, NOT ASSUMED

### 1.1 Only stage-boundary sampling exists on this GPU
`[MEASURED 2026-08-31 22:0x, scratchpad/probe.m, Apple M5 Max]`
```
supportsCounterSampling(AtStageBoundary       ) = YES
supportsCounterSampling(AtDrawBoundary        ) = no
supportsCounterSampling(AtDispatchBoundary    ) = no
supportsCounterSampling(AtTileDispatchBoundary) = no
supportsCounterSampling(AtBlitBoundary        ) = no
counterSets: timestamp (1 counter)
```
⭐ **THE CONSEQUENCE, AND IT IS THE WHOLE DESIGN:** a timestamp can be taken at an **encoder** boundary and
**nowhere finer**. Draw-boundary sampling is NOT available, so the lens draw **cannot** be timed where it
currently sits — inside the shared main encoder at `renderer.mm:4326`, alongside particles, dust and the
rest. **To be timed, the lens draw must be its own render encoder.** That is not a preference; it is the
only shape the hardware permits.

### 1.2 GPU ticks are CPU nanoseconds, 1:1 — but assert it, do not hardcode it
`[MEASURED]` `sampleTimestamps:gpuTimestamp:` twice, 200 ms apart:
`cpu delta = 205,018,625`, `gpu delta = 205,018,625`, **ratio 1.000000**.
⛔ **Do not bake `1e6` in as a constant with a comment.** `[HARD RULE: a comment is not a mechanism, 12
sightings]` Sample the pair once at init, compute the ratio, and **assert it is within 1% of 1.0**; if a
future device disagrees the instrument must say so, not silently report nanoseconds as if they were ticks.

### 1.3 `SS_LENS_ONLY` is no longer the fallback
FABLE ranked the double-encode fallback second **because it assumed no encoder-level timing was available**.
§1.1 shows it is. The fallback inherits the same scheduling contention `[BOARD §Z7]` and should not be built.

---

## 2. 🚨 THE FINDING THAT MATTERS MOST — A 4.0× WARM-UP TRANSIENT

`[MEASURED, scratchpad/stage.m→ramp.m, 40 consecutive identical dispatches, constant work, idle machine,
`waitUntilCompleted` between every run]`

| run | enc_ms | | run | enc_ms |
|---|---|---|---|---|
| 0 | **9.6492** | | 3 | 2.4060 |
| 1 | **4.2612** | | 4–39 | **2.4039 – 2.5310** |
| 2 | **2.6508** | | | |

⭐ **Runs 0–2 are a 4.0× warm-up ramp. From run 3 onward the instrument is steady to ±2.6% at constant
work** (36 further runs, range 2.4039–2.5310).

🚨 **THIS IS ALMOST CERTAINLY WHAT KILLED THE §Z7 BRACKET.** Its four readings at constant work were
**6.13 / 16.99 / 5.15 / 10.79 ms** — a 3.3× swing of the same order and the same direction as this ramp.
§Z7 attributed the whole swing to GPU occupancy. **Occupancy may still be present, but a DVFS clock ramp is
now measured, is 4.0×, and was never controlled for.**

⛔ **THEREFORE — and this is the part a builder skips at his peril:** the warm-up discard is not hygiene
here, it is **the difference between 9.65 and 2.41 on the same work**. It must be enforced *in the
instrument*, not left to the analysis script.

⚠️ **This also re-opens a §Z7 conclusion rather than confirming it.** §Z7 said the negative slope arises
because *"contention correlates with S: high-S frames are late-run frames on a collapsed, uncontended
field."* **A clock ramp produces that identical signature** — late-run frames are fast because the GPU
clocked up, not because the field collapsed. `[HYPOTHESIS — does NOT close §Z7]` The two are separable only
by breaking the correlation between S and time order. See §5.2.

---

## 3. THE BUILD — exact, against `HEAD 84c1314`

### 3.1 What is being replaced
`renderer.mm:4873–4980`, the whole `[LENSCOST]` block. It currently:
- lives in its **own command buffer**, committed after the main one (`renderer.mm:4931`),
- times `b.GPUEndTime − b.GPUStartTime` of that buffer,
- sets `restMs = lastRenderMs` (`:4947`).

⛔ **Do not delete it. Gate it.** `SS_LENS_COST=1` keeps the existing bracket, `SS_LENS_COST=2` selects
instrument #4. Two instruments that can be run back to back on one build is the only way the ~15× premise
error in §Z7 gets adjudicated rather than replaced by a new unverified number.

### 3.2 State to add (near `renderer.mm:274–277`)
```objc
id<MTLCounterSampleBuffer> lensCounterSB = nil;   // 4 samples * kMaxInFlightFrames
id<MTLCounterSet>          lensTimestampSet = nil;
double                     gpuTicksPerNs = 0.0;   // asserted ~1.0 at init, §1.2
uint32_t                   lensCostFrame = 0;     // ALREADY EXISTS at :277
```

### 3.3 Creation, once, beside `lensStatsBuffer` (`renderer.mm:1284`)
```objc
for (id<MTLCounterSet> cs in device.counterSets)
  if ([cs.name isEqualToString:MTLCommonCounterSetTimestamp]) impl_->lensTimestampSet = cs;

if (impl_->lensTimestampSet &&
    [device supportsCounterSampling:MTLCounterSamplingPointAtStageBoundary]) {
  MTLCounterSampleBufferDescriptor *sd = [MTLCounterSampleBufferDescriptor new];
  sd.counterSet  = impl_->lensTimestampSet;
  sd.storageMode = MTLStorageModeShared;        // REQUIRED: resolveCounterRange
  sd.sampleCount = 4 * kMaxInFlightFrames;      // ⛔ see §3.6
  sd.label       = @"lensStage";
  NSError *e = nil;
  impl_->lensCounterSB = [device newCounterSampleBufferWithDescriptor:sd error:&e];
  if (!impl_->lensCounterSB) NSLog(@"[LENSCOST] counter sample buffer: %@", e);
}
```
⛔ **If either the counter set or stage-boundary support is missing, `SS_LENS_COST=2` must print one line
saying the instrument is UNAVAILABLE and fall back to nothing.** It must never silently report zeros.
`[HARD RULE: a name is not a mechanism]`

### 3.4 The encoder — inside the MAIN command buffer
Insert **after the ImGui encoder ends (`renderer.mm:4865`) and BEFORE `presentDrawable` (`:4869`)**.

⭐ **WHY THAT EXACT SLOT, VERIFIED:** `offscreenTexture` is consumed earlier in the same command buffer —
mip generation at `:4487`, postfx sampling at `:4757` — and encoders within one command buffer execute in
submission order. `[READ renderer.mm:4082]` the main pass sets
`offscreenPass.colorAttachments[0].loadAction = MTLLoadActionClear`, so next frame clears it regardless.
**Writing into `offscreenTexture` at this slot therefore cannot reach the picture.** That preserves the
existing contract: *"the visual path is untouched"*.

`[READ renderer.mm:1244]` `depthState.depthWriteEnabled = NO`, and `[READ renderer.mm:906-908]`
`lensDebugPipeline` sets `colorAttachments[1].writeMask = MTLColorWriteMaskNone`. **So this pass writes
colour attachment 0 and nothing else** — no depth, no motion vectors.

Keep the pass descriptor, uniforms and `mode = 2` **byte-identical to `:4909–4929`** so #4 and #3 are
measuring the same work. Add only:
```objc
lp.sampleBufferAttachments[0].sampleBuffer              = lensCounterSB;
lp.sampleBufferAttachments[0].startOfVertexSampleIndex  = base + 0;
lp.sampleBufferAttachments[0].endOfVertexSampleIndex    = base + 1;
lp.sampleBufferAttachments[0].startOfFragmentSampleIndex= base + 2;
lp.sampleBufferAttachments[0].endOfFragmentSampleIndex  = base + 3;
```
with `const NSUInteger base = 4 * frameIdx;`

The `fillBuffer` zeroing of `lensStatsBuffer` (`:4931–4935`) **must be kept and must stay in the same
command buffer, ordered before this encoder.** `[BOARD §Z10]` that fix is what made the counters per-frame.

### 3.5 Resolve, in the main command buffer's completed handler
```objc
NSData *d = [sb resolveCounterRange:NSMakeRange(base, 4)];
const MTLCounterResultTimestamp *t = (const MTLCounterResultTimestamp *)d.bytes;
bool bad = !d;
for (int i = 0; i < 4 && !bad; i++) bad = (t[i].timestamp == MTLCounterErrorValue);
```
⛔ **`MTLCounterErrorValue` is `~0ULL`.** Subtracting two of those yields a plausible-looking small number.
**Check for it explicitly and print `ERRVAL`** — do not let it enter a fit.

`enc_ms = (t[3].timestamp - t[0].timestamp) / 1e6` (start-of-vertex → end-of-fragment).

### 3.6 🚨 THE RACE THIS DESIGN MUST NOT REPEAT
`[BOARD §Z10]` the previous instrument shipped with counters that **accumulated across frames** because a
CPU-side clear raced work still in flight. **The identical hazard exists here:** with `kMaxInFlightFrames = 3`
(`renderer.mm:391`), a single 4-sample buffer would be overwritten by frame N+1's encoder before frame N's
handler resolved it. **That is why `sampleCount = 4 * kMaxInFlightFrames` and the slot is `4 * frameIdx`.**
⭐ **Acceptance for this specifically:** `steps_per_px` must stay flat frame to frame, exactly as it did
after the §Z10 fix. A drifting value means the slotting is wrong.

### 3.7 The log line
```
[LENSCOST4] enc_ms=%.4f cb_ms=%.4f gap_ms=%.4f steps=%u px=%u steps_per_px=%.1f
            warm=%d amp=%.4f rs=%.4f mass=%.0f REST|PLAY
```
- `cb_ms` = the main buffer's `GPUEndTime − GPUStartTime`. **Already computed** — `[READ renderer.mm:1784]`
  `double gpuMs = (buffer.GPUEndTime - buffer.GPUStartTime) * 1000.0;`, stored as `lastRenderMs` at `:1785`.
  Reuse it; do not time the buffer a second time.
- `gap_ms = cb_ms − enc_ms`. **This is the occupancy discriminator — see §4.**
- `warm` = 1 while `lensCostFrame < 180`, else 0. **Print the row either way, flagged.**
  `[HARD RULE: report before acting]` — hiding warm-up rows would hide §2 from the next reader.
- Keep `amp` / `rs` / `mass` / `REST|PLAY` exactly as `:4967` has them. `[BOARD §Z8]` every row states its
  own regime, and **nothing has yet produced a `PLAY` row**.

---

## 4. THE CLOSURE INVARIANT — and the §Z7 scope defect it fixes

`[BOARD §Z7]` closure failed *"for a scope error, not a leak"*: `restMs = lastRenderMs` is render-only while
`PROFILE Total = Compute + Render`, so the ±5% gate was **mathematically incapable of passing** (measured
residual −23.7%).

With the pass inside the main buffer the closure becomes an identity that needs no matching of scopes:

> ### `enc_ms <= cb_ms`, every frame, no exceptions.

The lens encoder is *inside* that command buffer, so its span cannot exceed the buffer's. **A single frame
violating this falsifies the instrument** — different clock domains, wrong slot, or an error value that
slipped the check. It is free, it is per-frame, and it is not a tolerance to be tuned.

⭐ `[MEASURED, §6 probe]` under isolation `enc_ms` and `cb_ms` agree to **four decimal places**
(0.7531 / 0.7530). In the app they must NOT agree — the buffer holds every other encoder — so
**`gap_ms` is the amount of other GPU work the buffer carried**, per frame, for free.

---

## 5. THE RUN PROTOCOL — the half that instruments 1–3 got wrong

### 5.1 Non-negotiable gates
1. **AC power, and CHECK IT AT BOTH ENDS.** `[BOARD §Z9 #3]` `pmset` read `AC Power` while wattage fell
   100W → 80W and charging stopped. **Capture wattage and charge state at start and end and COMPARE them.**
   `[HARD RULE: pin the power state before measuring]`
2. **Discard the first 180 frames.** §2 measures a 4.0× transient over the first 3 dispatches;
   180 frames at 120 fps is 1.5 s of margin on that.
3. **Fullscreen** (`--env SS_FULLSCREEN=1`) — `[HARD RULE]` star size is in device pixels.
4. `[HARD RULE: stack 4+ runs]` A single run is not a result.

### 5.2 🚨 BREAK THE CORRELATION BETWEEN S AND TIME ORDER
This is the one thing that neither the bracket nor `ABBA` did, and §2 shows why it is decisive: **both
occupancy and a clock ramp make late frames cheap**, so any design where S rises monotonically with time
produces a negative slope *by construction*.

`[BOARD §Z9]` *"ABBA cancels a LINEAR term; a hump has none."* — correct, and insufficient for the same
reason. **The fix is not a better interleave, it is to stop letting the sim choose S.**

⭐ **`SS_LENS_PIN_RS` already exists** (`renderer.mm:4915`, and the banner in `render.metal`) and pins the
horizon radius the march uses. **Sweep `SS_LENS_PIN_RS` in RANDOMISED order within one run**, so S is set by
the harness and is uncorrelated with both wall-clock and field state. That converts `ms(S)` from an
observational fit into a controlled one.
⛔ **Without this the fit is not worth running a fourth time.**

### 5.3 Acceptance — declared BEFORE the run, per `[BOARD §Z9]`
| # | test | pass | fail means |
|---|---|---|---|
| 1 | `enc_ms <= cb_ms` | **every** frame | instrument void, stop |
| 2 | `steps_per_px` frame to frame | flat | slot race, §3.6 |
| 3 | spread at constant work, post-warm-up | **within ±10%** | occupancy still inside the span |
| 4 | sign of `k` in `enc_ms = k·S + c` | **k > 0** | still measuring something larger than the pass |

⭐ Test 3's threshold comes from §2: the isolated instrument achieved **±2.6%**. Anything past ±10% in-app is
other work landing inside the encoder span.

### 5.4 ⛔ WHAT THIS INSTRUMENT STILL CANNOT DO — state it now, not after
On a TBDR GPU the vertex/tiling and fragment stages of **adjacent encoders can overlap**. If the lens
fragment stage overlaps a neighbouring encoder, `enc_ms` still contains wall-clock during which the GPU was
serving both. **Stage-boundary sampling strips the command-buffer SCHEDULING ENVELOPE; it does not prove
immunity to OCCUPANCY.** Test 3 above is what detects that, and `gap_ms` is what quantifies the
surrounding load. `[HARD RULE: don't second-guess a measurement into agreeing with you]` — instruments 1–3
each passed their own smoke test and were void.

---

## 6. THE PROBES — reproduce before trusting any of the above

`/private/tmp/claude-501/-Users-airy/6db1d260-9148-4bd4-a75a-e874b78ea3c5/scratchpad/`
- `probe.m` → §1.1, §1.2. Build: `clang -fobjc-arc -framework Metal -framework Foundation probe.m -o probe`
- `stage.m` → the end-to-end proof stage-boundary samples resolve and scale with work.
  Build: **`clang++`** `-fobjc-arc -std=c++17 -x objective-c++ -framework Metal -framework Foundation`
  (plain `clang` fails to link: `___gxx_personality_v0`).
- `ramp.m` → §2, the 40-run warm-up table.

⚠️ **These live in a session scratchpad and will not survive.** If OPUS wants them kept they belong in
`tools/` — **OPUS's lane, and only on his order.** `[HARD RULE: commit only on explicit order]`

---

## 7. WHAT IS NOT IN THIS SPEC

- **B2b** (particle + opaque-cell termination). `[BOARD §Z8]` the B2a fragment reads no particle data
  (`render.metal:3171-3173`), which is exactly why `ms(S)` is clean today. **That protection ends at B2b and
  tonight's fit must never be quoted for it.**
- **The `bhLensActive` play gate** (`renderer.mm:1907`, `totalAmplitude < 0.02f`). `[BOARD §Z8]` flagged,
  **not ordered**, and it is what stands between this instrument and its first `PLAY` row.
- **Any verdict on the rest rate.** `[BOARD §Z8]` ~95% of the field eaten in 4 idle minutes is **his** call
  and he cannot give it until a lens exists to see.

---

**Last Updated:** 2026-08-31 22:06:16
**Status:** SPEC ONLY. Nothing in `src/**` was touched. **OPUS builds; BRAIN did not.**
