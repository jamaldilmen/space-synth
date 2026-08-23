# SPACE SYNTH TUBE — handoff 2026-08-23 13:54:37

> **His verdict on this state:** *"window is great.. sometimes its so funny with u like u get it entirely wrong then u get it entirely right a second later. amazing."* (two-window mode) · *"yoooo it looks fucking amazing hahah… es läuft halt 1 zu 1 so wie vorher"* (2026-08-23 12:08:16, native res + the 2.5:1 pin) · ⛔ **NOT seen yet:** the letterbox fix and the UI-scale fix.
> **Cold start:** read `docs/TODO.md` — NOT this file, NOT older handoffs. `docs/BOARD.md` is the reference of truth; `docs/BOARD_BLACKHOLE.md` is the BH reference.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube` branch `kill-the-tube-2026-08-11` @ `a44de13` **+ 9 uncommitted paths (docs + the built binary only), 0 unpushed**
**Build + launch:** `bash package_macos.sh` then `pkill -x SpaceSynth; open -n SpaceSynth.app --env SS_WIDTH=3840 --env SS_HEIGHT=1536 --env SS_FULLSCREEN=1`
🎪 **13 days to Cologne** (2026-09-05) — ⚠️ **the venue is a THREE-WALL ROOM, see §2.2. Every older "2.5:1" row is now only the FRONT wall.**

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| **A2-1** | stdio on the CoreAudio thread | `fprintf(stderr)` **inside** `audioOutputCallback` every 100th callback — unbuffered `write(2)` + a FILE lock | deleted, headstone left | `audio_engine.mm:65` | **[READ]** + `strings` on the bundle → **0** hits |
| **A2-2** | allocator on the CoreAudio thread | `std::vector<float> windowed(fftSize_)` = 8 KB new/delete **per FFT call** | preallocated into `Impl` beside `window`/`inputBuffer_` | `fft.cpp:14,34,63` | **[READ]** call graph traced out from the IOProc |
| **A2-3** | blocking lock, with a malloc under it | `getVJBands()` took `lock_guard(vjMutex_)` and **copy-constructed its return inside that lock**; `audioInputCallback:149` blocked on the same mutex | **seqlock**; `vjBands_` is RT-private; returns `std::array<VJBand,16>` by value (stack aggregate, no malloc, both call sites unchanged) | `audio_engine.mm:334` | **[READ]** `grep` for `lock_guard` / `unique_lock` in `src/audio/audio_engine.mm` → one comment, no code |
| **A2-4** | allocator inside the mix loop | `voices_` was an `unordered_map`; `erase()` reachable **once per sample**, `operator[]` = malloc + possible rehash | fixed **64-slot pool**; retiring a voice is a flag flip | `synth.h:127` | **[READ]** all 17 use sites converted. ⚠️ Deliberate change: a note is now DROPPED when the pool is full and every voice is in Attack — the map grew past MAX_VOICES instead |
| **L1** | MIDI length never reached the screen | `relDur = clamp(sustainHeld, params.release, 1.5f)` — the Release knob was the **LOWER** bound, so every note got a tail of at least 400 ms | the knob is the **CEILING**; the tail is the note, with a 12 ms anti-click floor | `envelope.cpp:79` | **[MEASURED]** 10 ms → **12 ms** (was 400), 50 → 50, 250 → 250, 2 s → 400 (the knob). Voice overlap at a 10 ms arp **41 → 3**. Knob re-checked across its whole 1 ms–2 s range |
| **C6/G10** | scanlines were aliasing, not an effect | `0.5+0.5*sin(uv.y*resolution.y*pi)`; `resolution` is BACKING PIXELS, so at a fragment centre the argument is exactly `pi*(row+0.5)` and `sin` returns `(-1)^row` | **deleted**, all 8 sites | `postfx.metal:500` | **[MEASURED n=5]** H = 1080/1440/2160/2234/1537 → **0 of H** rows land in (0.01,0.99). 0.5000 cyc/px, f/f_N = **1.0000** |
| **C12/G14** | the CPU/GPU struct mirror was broken | `PostFXUniforms`: MSL sizeof **240** with matrices at **112**, C++ **236** at **108** — 4 bytes apart. The guarding comment claimed "28 (=112 B)"; the truth was 27 (=108 B) | one `float postPad1` in both mirrors + the `static_assert` guard it never had, in the existing `CameraUniforms` style | `renderer.h` · `postfx.metal` | **[MEASURED]** compiler in both directions: the real asserts compile, the old 236/108 values **fail** the Metal compile |
| **C4b** | board said motion vectors were "genuinely not started" | wrong — they shipped 2026-08-20 | row corrected; the real gap narrowed to *only the star pass writes velocity* (4 writeMasks) | `render.metal:2687-2689` · `renderer.mm:695-696,3702-3705` | **[READ]** `ParticleFragOut.velocity [[color(1)]]`, RG16Float target, blending OFF |
| **G12** | the "cheaper win" did not exist | board claimed ~1120 lines run per corpse because the discard sits at `:1889` | **refuted** — a full discard already fires at `:839`, 71 lines after the mass read, at function-body scope | `render.metal:839` | **[READ]** brace depth checked; `mass`/`in.posW.w` never reassigned between `:768` and `:1889`; `:1889` is reachable only by a mass of **exactly** 0.001f |
| **UI-1** | the settings overlaid the outgoing feed | one window — *"i cant have the settings in the same window im sending out"* | **two-window mode on `I`** — lazy create, toggles back, red button hides instead of quitting | `window.mm` · `main.cpp` | **[HIS WORDS]** *"window is great"* |
| **S0b** | UI microscopic at native resolution | font size and style metrics both hung off `backingScaleFactor`, which is **1.0 in every 1x mode** whatever the ppi | derived from **physical DPI** (`CGDisplayScreenSize`); `SS_UI_SCALE` overrides | `window.mm getUIScale()` | **[MEASURED]** 255 ppi → **2.32x** |
| **UI-2** | *"its an egg"* | CALayer's default `kCAGravityResize` scales each axis independently: a pinned 3840x1536 drawable in a 3024x1964 fullscreen window is x·0.788, y·1.279 | `kCAGravityResizeAspect` — letterbox, never stretch | `window.mm` layer setup | **[MEASURED]** predicted **1.62x** vertical stretch; his screenshot at 2026-08-23 12:14 matches. ⚠️ **NOT SEEN YET** |
| **F5 / A4 / E5** | three rows parked on "awaiting his eyes" for **12, 12 and 14 days** while he used the app daily | fake blockers inflating the board | closed as **shipped, no complaint recorded** — explicitly NOT measured-correct, and labelled so | `BOARD.md` | **[HIS WORDS]** *"uve been going mad over 2 3 points on the board that dont even require it"* |

**Committed and pushed on his explicit order (2026-08-23):** `856410d` audio · `f739161` envelope · `ea3888a` render+UI · `a44de13` boards. Nothing unpushed.

## 2. 🚨 OPEN — his list, verbatim

1. **"how do we tackle this sub 1 px shit. how does nasa tackle it… how did christopher nolan do it"** — and he set the order: **"design doc erst, dann prototyp"**.
   `MEASURE:` `[KPROBE-RAW]` meanRaw / FLOORED%.
   State: **[MEASURED n=25533]** meanRaw **1.079 px**, **52.5 % floored**, 0 % capped. ⭐ **THE FINDING THAT REFRAMES THIS ROW — [READ] `render.metal:2692-2810`: the PSF ALREADY EXISTS.** `particle_fragment` carries an anisotropic Gaussian, a radial anti-corner window, a crisp core term **and diffraction spikes gated by luminance**. All of it is being squeezed into a quad that is **1 px wide for half the field**. So the move is not "build a PSF" — it is **decouple the footprint from the geometric size law and drive it from FLUX**. ⛔ The design doc is **not yet written**; this was interrupted by the venue news.

2. **"the projection is gonna be 3 walls in a room, 2 at 4m x 15m and one / front that's a bit smaller lets say 10 m… i need to think in three slices"** (2026-08-23).
   State: **[HIS WORDS]** + arithmetic. Sides **15x4 m = 3.75:1**, front **10x4 m = 2.5:1**, unwrapped **40x4 m = 10:1**, **160 m²**. 🚨 **ONE CAMERA CANNOT RENDER THIS** — three walls wrap ~270° around a viewer inside, and a flat perspective needs image width proportional to tan(fov/2): 11.43 at 170°, **infinite at 180°**. One wide image cut into three is WRONG. Correct construction is **one camera POSITION, three OFF-AXIS FRUSTUMS**. Working: `docs/DESIGN_2026-08-23_THREE_WALL_ROOM.md`, board row **S00**.
   ❓ **BLOCKED ON THE VENUE TECH, 2026-08-24: 4K PER WALL or 4K TOTAL?** 256 px/m versus **96 px/m** — a factor of 3, and 4K-total is visibly chunky.

3. **"brauchen min 4k"** — ⭐ **[MEASURED + HIS WORDS 2026-08-23 12:08:16]** *"es läuft halt 1 zu 1 so wie vorher"* at **5.9 MP** (3840x1536): **2.5x the previous fill for no measurable cost.** Fill rate is probably not the wall. 🚨 **The untested cost is GEOMETRY — three frustums means `particle_vertex` runs 30 M times per frame.** Nothing has ever been measured under that load. Promotes per-wall frustum culling and G12 index compaction.

4. **`synth.cpp` — the last audio fault on a LIVE path.** **[READ]** a blocking `lock_guard(queueMutex_)` at `:91` while the MIDI thread (`main.cpp:199`, CoreMIDI) holds the same mutex across a `std::sort` and a reallocating `push_back` (`:161-171`); the requeue at `:138-142` both locks **and** allocates, on the RT thread. Needs a lock-free SPSC ring — `AudioRingBuffer` is already in the repo to copy. ⛔ Do NOT naive-`try_lock` the exit requeue: it breaks the swap invariant and drops notes.

5. **The TRUEFX suite** — *"not two effects chained together. the same data drives the effect for sound and visuals."* Reverb = the fluidity mechanism · delay = neither half exists · chorus = per-pixel proper CA · **ladder LPF = our opacity** (⚠️ "opacity-like" describes the CONTROL, not the implementation — the image must lose **spatial high frequencies**; a cheap `alpha *= x` is exactly the "just on off" he ruled out). Plus **disco** — *"not nasa. we make a movie now."* `docs/DESIGN_2026-08-23_TRUEFX_AND_THE_SHOW.md`.

6. **Show infrastructure, he marked it URGENT** — Ableton Link · MPE (named in both messages) · recording/render route · **every parameter a macro reachable by MIDI CC**. ⭐ The macro row **gates** the others: an un-addressable knob cannot be in the set. Same underlying fix as *stars are undialable*.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **The G12 corpse hoist — REJECTED 2026-08-23 13:54:37.** There is nothing to hoist. The discard already fires at `render.metal:839`, and the 71 lines between it and the mass read are two culls **both gated on `mass > 0.001f`**, so a corpse pays two failed compares. A whole session had been budgeted for this.
- **`SS_NO_DEADSKIP` as the A/B for it — BROKEN AT THE PREMISE.** It gates `particles.metal:1220`, the **COMPUTE** kernel, not the vertex shader. Two different shaders had been conflated inside one row. (It is also parsed once into a static and cannot alternate within a run.)
- **Prefiltering the scanlines — IMPOSSIBLE, not merely hard.** At exactly Nyquist the exact per-pixel area-average still retains **0.6366** of the amplitude. Only lowering the frequency works (period 4 px keeps 0.900). No softness dial was ever possible: only two values existed.
- **`BGRA8Unorm` + the default colourspace for the settings window — REJECTED by his eyes** (*"that second window looked like shit"*). The theme's colours are authored for the main window's `RGBA16Float` + extended-sRGB layer; a plain UNORM target skips that mapping and lands every colour at the wrong gamma. Mirror the main layer exactly.
- **One wide 10:1 image sliced into three for the room — REJECTED 2026-08-23 13:54:37 by arithmetic**, see §2.2. This is not a quality argument.
- **Judging star size from `[KPROBE-SCALE]` — still REJECTED.** It bins post-clamp; bin 3 merges floored stars with natural 1.0–1.4 ones. Use `[KPROBE-RAW]`.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-08-23 13:51:39  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube

1. git
  ok    branch kill-the-tube-2026-08-11, HEAD a44de13
  WARN  9 uncommitted path(s)
  ok    pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at a44de13
  WARN  docs/BOARD_BLACKHOLE.md is 87445B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  ok    docs/BOARD.md current at a44de13
  WARN  docs/BOARD.md is 102994B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    31 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:546:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:733:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1347:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1646:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1649:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2711:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  7 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: no failures.
```

**§5 sites:** no orbital or rotational code was touched this session — the work was audio, the envelope, post-FX and the window layer — so these carry their 2026-08-22 readings unchanged. `postfx.metal:66` shifted from `:43` because of this session's struct-guard insertion and is still the HSV helper: **false positive**. ⚠️ Both boards remain oversized; splitting closed rows into `BOARD_CLOSED.md` is still owed.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| **"`getVJBands` is the real dropout risk… the change most likely to have removed a dropout you've heard"** | **Both callers are unreachable.** `main.cpp:1802` is `if (false && ImGui::CollapsingHeader("VJ MODE & AUDIO INPUT"` (*"removed 2026-06-26"*), the only checkbox that sets `uiVJMode` lives **inside that dead block**, and nothing else in `src/` sets it. The main thread never took that mutex, so the RT side never contended it. The fix is correct but is **insurance, not a live fix**. Now board row **A7**. |
| **"Only 1 window — the settings window didn't create"** | It had created. **He had closed it**, and my own `windowShouldClose` hides rather than quits. I read a symptom of my own code and diagnosed it as a failure. |
| **The C++ layout probe numbers I first read back** | The compile had **failed** and I read the **stale binary's** output — the exact trap Rule 1 names. Caught before it reached a decision, but it was reported first. `rm` the probe before re-running it. |
| **"14 lock sites in `src/audio`"** (older board figure, which I repeated into the published artifact) | Never verified at function granularity. The real shape is four faults, of which one (`synth.cpp`) is still open — and `audio_engine.mm` now holds **zero** locks. |

---

**Last Updated:** 2026-08-23 13:54:37
**Folded into board:** `docs/TODO.md` (cold start) + `docs/BOARD.md` + `docs/BOARD_BLACKHOLE.md` @ 2026-08-23 13:54:37
