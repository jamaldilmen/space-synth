# FULL CODEBASE AUDIT — SPACE SYNTH TUBE

**Written:** 2026-08-02 19:47:42
**Requested by Jamal:** *"run a deep audit of the entire codebase … act as a software veteran.
find hindrances, stupid things, loose ends and straight up errors and mistakes. don't let
anything out. … we need to get this working on stage and in heat and rn my mac is fuming when i
just run it. it hurts on my lap."*

**Hard deadline: Berlin New Media Week, first show 2026-09-02 — one month from today.**

**Method:** static read of all 22,522 lines + a clean build for warnings. The app was NOT
running, so every thermal number below is derived from code (buffer sizes, counts, per-frame
dispatch inventory), not from a profiler. Items needing a live measurement are marked ⏱.

**Status: DIAGNOSIS ONLY. No code changed by this audit.**

---

## 0. THE SHORT VERSION

The heat is not a mystery and it is not mainly the physics. **It is fill rate.** ~2M particles
drawn as ~13-pixel soft sprites with additive blending and no depth test is on the order of
**338 million fragments per frame**; vsync-locked to a 120 Hz panel that is ~40 billion blended
fragments per second. Everything else — the 32 MiB/frame of buffer zeroing, the always-on
spatial hash, the dead passes — is real but secondary.

Three findings are stage-critical and independent of the heat:
1. **The real-time audio callback takes a blocking mutex** → dropouts under load. (§2.1)
2. **Pause does not reduce GPU load at all.** (§1.4)
3. **CVDisplayLink is deprecated as of macOS 15** and the whole frame driver rests on it. (§2.9)

---

## 1. THERMAL — why the machine is fuming

### 1.1 ⭐ FILL RATE IS THE DOMINANT COST
`render.metal:1139` — `rawSize = particleSize · heatSizeBoost · massSize · sizeScale`.
At default zoom for a 1 M☉ particle in the play state:

| factor | value |
|---|---|
| `cam.particleSize` | 2.0 |
| `heatSizeBoost` | 2.5 (`1 + clamp(temp,0,1)·1.5`, saturated at play temps) |
| `massSize` | 1.3 |
| `sizeScale` | 2.0 |
| **rawSize** | **≈ 13 px** |

| sprite | fragments/frame @2M | @120 fps |
|---|---|---|
| 13 px | 338 M | **40.6 G frag/s** |
| 6 px | 72 M | 8.6 G frag/s |

Every one of those fragments runs the full `particle_fragment` (two `exp()`, a `pow()`, two
spike terms) **and** an additive blend with no depth rejection — nothing is ever occluded, so
there is no early-out anywhere in the pipeline. Cost scales with the **square** of sprite size:
halving the sprite quarters the heat.

⏱ Confirm with a GPU capture, but the arithmetic is not close to borderline.

### 1.2 VSYNC LOCKS TO THE PANEL, WITH NO CAP OPTION
`window.mm:297-298` — `maximumDrawableCount = 3`, `displaySyncEnabled = YES`. On a 120 Hz
ProMotion display that is 120 full frames/s. There is **no frame-rate cap, no adaptive quality,
and no LOD** anywhere in the codebase. The app always does maximum work.

### 1.3 THE SPATIAL HASH REBUILDS EVERY FRAME — the gate is a tautology
`renderer.mm:1866`:
```cpp
bool needSpatialHash = collisionsEnabled ||
    envelopePhase < 0.5f  || envelopePhase > 3.5f ||
    (envelopePhase >= 1.5f && envelopePhase < 3.5f);
```
Phases are 0=silence, 1=attack, 2=decay, 3=sustain, 4=release. The clauses cover 0, 2, 3, 4 —
**everything except attack**, and `collisionsEnabled` ORs even that away. It reads like a
condition and is effectively `true`. That's 4 hash phases + a full snapshot blit of 2M particles
every frame, unconditionally.

### 1.4 ⭐ PAUSE DOES NOT REDUCE LOAD
`simPaused` appears in `renderer.mm` **only** inside `emergentPoseDt` (:1459, :1707). It never
gates `runComputePass`, the hash build, or any dispatch. Pausing freezes the *simulation* while
the GPU keeps doing 100% of the work. On stage — and on a lap — pause looks like a rest and
isn't one.

### 1.5 32 MiB OF ZEROING PER FRAME
`kTotalCells = 128³ = 2,097,152`; each cell buffer is **8.0 MiB**. Cleared every frame
(`renderer.mm:1934-1967`): `cellCounts`, `cellMass`, `cellSeedMap`, `cellOffsets` — plus
`seedCount`, `seedAccum`, `accDiag`, `mergeClaim`, `radialMass`, and conditionally
`sphClosure`, `sphForce`.

| | 60 fps | 120 fps |
|---|---|---|
| 4 cell-sized clears | 1.88 GiB/s | **3.75 GiB/s** |

The 128³ grid spans ±64 sim units while the Chladni cavity is radius 6 — so the overwhelming
majority of those 2.1M cells are permanently empty and are being zeroed 120×/second.

### 1.6 AMR ADDS A SECOND 128³ GRID, DEFAULT ON
`renderer.mm:1843` — `amrOn = getenv("SS_NO_AMR") ? 0 : 1`. Fine-grid uniforms are refreshed
every frame; the fine Poisson solve runs 4 sweeps. **Note the memory note claiming AMR is
default-OFF is wrong** — it is ON.

### 1.7 DEBUG PROBES SHIP ENABLED
69 `printf`/`fprintf`/`NSLog` sites in `renderer.mm`. `[KPROBE]` alone was ~4,115 lines in one
short capture. Several read `.contents` of GPU buffers on the CPU each interval. Individually
cheap; collectively they are console I/O and CPU-side buffer walks in the frame path, and on
stage they are pure waste.

---

## 2. CORRECTNESS — real errors and stage risks

### 2.1 ⭐⭐ THE AUDIO RT THREAD TAKES A BLOCKING LOCK — `synth.cpp:91`
```cpp
void Synth::processBlock(float sampleRate, float *outL, float *outR, int numFrames) {
  {
    std::lock_guard<std::mutex> lock(queueMutex_);   // ← BLOCKING, on the RT thread
    swapBuffer_.swap(commandQueue_);
  }
  // "Lock mutex_ with try_lock: never blocks the RT thread."
  std::unique_lock<std::mutex> voiceLock(mutex_, std::try_to_lock);   // ← correct
```
The author understood the rule for `mutex_` and applied `try_to_lock` — then used a **blocking
`lock_guard` on `queueMutex_` four lines earlier, in the same function.** If the main thread
holds `queueMutex_` (note-on/off enqueue, `synth.cpp:138,148,162,175`) when the audio callback
fires, the RT thread blocks → buffer underrun → **audible dropout**. This is classic priority
inversion and it is the single most likely thing to embarrass the show.

### 2.2 A 227-LINE DEAD RENDER PATH — `renderer.mm:1300`
`void Renderer::render(const RenderConfig &config)` is declared (`renderer.h:340`), defined
(1300–1526, including its own `nextDrawable` and full pass sequence), and **never called from
anywhere**. `main.cpp:2462` calls only the two-argument overload. Two render paths, one dead and
silently drifting.

### 2.3 A COMPILED PIPELINE THAT IS NEVER DISPATCHED — and it gates the hash
`assign_cells` is compiled (`renderer.mm:414`), its pipeline created, and it is **null-checked
as a precondition** at :1884 — but `setComputePipelineState:` is never called with it. Its own
shader comment (`spatial_hash.metal:64`) says the pass is *"redundant"*. So a dead pipeline is
load-bearing: if its creation ever failed, the entire spatial hash would silently stop building.

### 2.4 ANOTHER ORPHAN PIPELINE
`orbitSubstepPipeline` — created at `renderer.mm:406`, never bound. The `orbit_substep` kernel
(`particles.metal:476`) is compiled into the metallib for nothing.

### 2.5 `bit18` — AN UNINITIALISED READ, KNOWN AND DELIBERATELY LEFT
`render.metal:1135` — the gate reads `out.pointSize` before assignment, so `sL ≡ 1.0` for every
particle in the app and bit18 has never executed since 2026-07-24. Documented as *"KNOWN DEFECT,
DELIBERATELY LEFT IN PLACE"*. Reading uninitialised memory is undefined behaviour, not a stable
`false` — it happens to be benign today.

### 2.6 UNREACHABLE BLOCK — `render.metal:561`
Needs `bhDiskAxisY > 0.5`; `renderer.mm` assigns `bhDiskAxisY = 0.0f` at **all seven** assignment
sites plus the header default. Verified dead 2026-07-26 and still present, still carrying an
obsolete absolute-angle formulation.

### 2.7 THE COLOUR LAW HAD SILENTLY FORKED (fixed today, but note the pattern)
Play (`:1317`) and star (`:1462`) had drifted into two different Kelvin expressions — different
mass coefficients (hardcoded vs dialed), different mass bounds, and a heat pedestal removed from
one path on 2026-07-10 and left live in the other. Consequence: the A/p dials added 2026-07-28
**did nothing while a note sounded**. Unified 2026-08-02. **The lesson is structural** — this is
the third instance of the same failure mode (see §2.8).

### 2.8 ⭐ COMMENTS DESCRIBE INTENT, NOT BEHAVIOUR — systemic
Each of these cost real diagnostic time this week:

| location | claims | actually |
|---|---|---|
| `particles.metal:2590` (B2) | *"play dynamics untouched"* | no envelope gate — fires during play |
| `renderer.mm:2247` | *"at play h≈0.047"* | play runs h = 1.0 since the 07-18 unification |
| `renderer.mm:1904` | AMR *"carries the resolution the cymatics needs"* | AMR feeds gravity only |
| `render.metal:1443` | *"the SAME kelvin law the play path uses"* | two different laws until today |
| `particles.metal:2583` | ridge-pull *"drives it onto the node line"* | pointed at a disabled field |

**Rule for this codebase: a comment is a historical record of an intention. Verify the consuming
code before believing any of it.**

### 2.9 ⭐ CVDisplayLink IS DEPRECATED — the frame driver is on borrowed time
Six deprecation warnings; `window.mm` drives *every frame* through
`CVDisplayLinkCreateWithActiveCGDisplays` + `CVDisplayLinkSetOutputCallback`, deprecated in
**macOS 15** in favour of `NSView.displayLink(target:selector:)`. This machine is already on a
newer OS. If the laptop takes an OS update before 2026-09-02 and the API is removed rather than
merely deprecated, **the app stops producing frames.** Freeze OS updates before the show
regardless.

### 2.10 THE PROJECT BUILDS WITHOUT ARC, AND VENDORS AN ARC-EXPECTING FILE
No `-fobjc-arc` anywhere in `CMakeLists.txt`. `third_party/imgui/backends/imgui_impl_metal.mm`
uses `__bridge_retained`/`__bridge_transfer` (lines 341, 384) which are **no-ops without ARC** →
the ImGui texture object is leaked. Bounded and small (font atlas, created once), so low
severity — but it is a real leak and the warning is telling the truth.

⏱ **Not claimed:** I did **not** find evidence of a per-frame autorelease leak. There is no
`@autoreleasepool` in the frame handler (`window.mm:374`), but that block runs on the main
dispatch queue, which drains a pool per work item. Needs a memory profile over a long run to
settle — worth doing before a multi-hour show.

### 2.11 MINOR COMPILER WARNINGS
- `renderer.mm:3110` — `bestCid` set but never used (the densest-cell reduce computes a cell id
  and throws it away; either the consumer was dropped or the diagnostic is incomplete).
- `renderer.mm:1066` — signed/unsigned comparison (`size_t` vs `int`).
- 7 unused-variable warnings in `particles.metal` (`distFromDisk`, `ecount`, `BH_M`,
  `SCHWARZSCHILD_RS`, `ORBIT_R_BH`, …) — dead locals and dead constants.

---

## 3. STRUCTURE — the hindrances

### 3.1 GOD FILES
| file | lines |
|---|---|
| `renderer.mm` | 3,924 |
| `particles.metal` | 3,684 |
| `render.metal` | 2,855 |
| `main.cpp` | 2,792 |
| `spatial_hash.metal` | 1,347 |

`particle_vertex` alone spans roughly 1,100 lines. This is *why* the colour law could fork
without anyone noticing: nobody can hold the function in their head, so a second copy of a rule
is invisible.

### 3.2 THE `debugFlags` BIT SOUP
27+ bits, addressed by raw literals (`1u << 23`, `0x10000u`, `0x20000u`) at both ends with no
shared enum — the shader and the CPU agree by *convention only*. Several bits are dead (bit18),
several are permanently on, and one (bit15) is documented as silently killing a working feature.
A single mistyped shift is an undebuggable class of bug.

### 3.3 STARTUP COMPILES EVERYTHING, INCLUDING THE DEAD
26 compute pipelines built at launch, including `assign_cells` and `orbit_substep` which are
never dispatched. Adds launch time and metallib size for nothing.

### 3.4 THE SIM IS SIZED FOR A DESKTOP, RUN ON A LAPTOP
`uiParticleCount = 2,000,000` default, 128³ hash over ±64 units, AMR on, all probes on, no LOD,
no cap. Every default is the maximum-work default. **For a stage machine that is the wrong set
of defaults** even before any optimisation work.

---

## 4. WHAT IS ALREADY KNOWN-GOOD

Worth stating so it does not get "optimised" away:
- **No `waitUntilCompleted` anywhere** in the frame path — the CPU never stalls on the GPU; it
  uses completion handlers correctly. That is the single biggest thing this renderer gets right.
- Triple buffering (`maximumDrawableCount = 3`) and per-frame-index probe buffers are correct.
- `mutex_` in the synth uses `try_to_lock` — the right instinct, just not applied to both locks.
- `spectral_lut.h` is shared by the shipped bake **and** the offline verifier, so the verified
  table and the shipped table cannot drift. That pattern should be copied elsewhere.

---

## 5. PRIORITISED FOR THE SHOW — 2026-09-02

Ordered by (risk to the show) × (cheapness to fix). **Nothing here is applied.**

### Tier 1 — stage-critical, small, low-risk
1. **Blocking lock on the audio RT thread** (§2.1). `try_to_lock` on `queueMutex_`, same as the
   line below it already does. Prevents dropouts.
2. **Gate the compute pass on `simPaused`** (§1.4). Pause becomes a real thermal rest.
3. **A frame-rate cap** (§1.2). 60 fps on a 120 Hz panel is an instant ~50% cut in everything.
4. **Compile out / flag off the probes** for show builds (§1.7).
5. **Freeze OS updates on the show machine** (§2.9) — zero code, pure risk removal.

### Tier 2 — the actual heat
6. **Sprite footprint** (§1.1). Cost is quadratic in size; this is where the watts are. Needs
   his eye, since it trades directly against the look — and `heatSizeBoost` (2.5× at play
   temperature) is the specific term inflating it in the Chladni state.
7. **Shrink or bound the hash domain** (§1.5). ±64 with a radius-6 cavity means most of 2.1M
   cells are permanently empty and zeroed 120×/s.
8. **Particle count as a show preset** (§3.4).

### Tier 3 — hygiene, do after the show
9. Delete the dead render overload (§2.2), the orphan pipelines (§2.3, §2.4), the unreachable
   blocks (§2.5, §2.6), and the dead locals (§2.11).
10. A shared `debugFlags` enum (§3.2).
11. Split `renderer.mm` and `particle_vertex` (§3.1).
12. Sweep the stale comments (§2.8) — or at minimum date-stamp them as claims, not facts.

---

## 6. OPEN, NOT INVESTIGATED HERE

- **The post-BH ring bug.** He proved it is conditional on a hole existing and pointed at *"the
  transition from that state back to the play state"*. Untouched.
- **"The black hole barely functions and doesn't feed fast enough."** Untouched.
- **`docs/AUDIT_2026-07-29_chladni_3d_correctness.md` is WRONG at its root** and should be
  deleted or prefixed with a retraction. It argues the blur is structural/geometric; the
  2026-07-30 session disproved that by building `0edde58` and finding two real render
  regressions (the play-phase gas splat, and the removed along-motion stretch). Leaving it in
  `docs/` will mislead the next session.

---

**Last Updated:** 2026-08-02 19:47:42
**Code state:** `b047744` + uncommitted. Today's landed changes: gas-splat off, along-motion
stretch restored, Case B line weights, `LINE_FRAC_MAX` cap, unified Kelvin law, log faders,
`uiHeatGain`/`uiColorTempK` → 0. Plus the read-only `[GRIDPROBE]` in `renderer.mm`.
