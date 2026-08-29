# SPACE SYNTH — handoff 2026-08-29 10:50:00 (BRAIN window)

> **His verdict on this state:** *"i love the feel the snappiness"* (camera/zoom, 2026-08-28 13:55) · *"tap is fine"* · **the M fix and everything BH is UNJUDGED — he has not looked at the hole yet.**
> **Cold start:** read **`docs/BOARD.md` §W** and **`docs/BOARD_BLACKHOLE.md` §V** — NOT this file, NOT the two sibling handoffs.
> **For HIM, not for us:** `docs/STATUS.md` — one page, his to-dos, kept current. He asked for it: *"your reporting is inconcise ansd confusing af bro."*

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-POST-TUBE` branch `post-tube` @ `ea14dbc` (sources) — see §4 for the docs/binary SHAs.
**Build + launch:** `bash package_macos.sh` (**never bare `make`**) then `SS_FULLSCREEN=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth 2>&1 | tee run.log`

**Sibling handoffs, same session, both folded:** `docs/HANDOFF_BH_2026-08-29.md` · `docs/HANDOFF_2026-08-29_CAMERA_WINDOW.md`

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | Hole vanished in one frame | Drawn from a radial profile windowed at `RADIAL_MAX_R=5.0` sim, calibrated at meanR 3.92 | Drawn from `kRsSimPerMsun · bhSeedMassMono`; profile still logged | `renderer.mm:3226` | `[MEASURED n=233]` profile zero on 13, drawn on 2 (both pre-seed) |
| 2 | Hole stepped in visible jumps | Profile could only return multiples of **0.0195** (5.0/256) — the staircase the ×0.03 easing hid | Seed radius is continuous | `particles.metal:405` | `[MEASURED n=58]` 11 distinct values, spacing exactly 0.0195 |
| 3 | Camera feel changed with frame rate | `phi += velPhi` with **no `dt`** → one tap 7.28° @18.7fps, 30.94 @60, 65.43 @120 | Target + spring; 45°/tap at any rate | `camera.h:43` (was) | `[MEASURED]` 8 taps = 360.0000°, spread 0.0003° over 18.7–120.2 |
| 4 | No cinematic mode | — | `c` toggles; orbit/tilt/zoom only | `camera.h`, `main.cpp` | `[HIS WORDS 2026-08-28 13:55]` *"i love the feel the snappiness"* |
| 5 | "3 taps = one quadrant" believed a constant | A 60 Hz accident (196° at 120 Hz) | Retired with `TAP_STEP` | — | `[MEASURED]` three independent derivations agree |
| 6 | Two windows could build one tree | Writing source under another window's token compiled it into their build | Rule: **token holder owns the WHOLE tree** | `docs/BOARD.md` §W4 | `[MEASURED]` binary 13:15:23 postdates camera.h 13:14:13 |
| 7 | "The cubes/grids" unexplained for months | Blamed on the renderer | Located in the PHYSICS: capture+merge run on the 1.0-sim cubic hash | `particles.metal:1429`, `:3812`, `:3807` | `[HIS WORDS 2026-08-29]` *"its clearly in the physics"* |

## 2. 🚨 OPEN — his list, verbatim

1. **"WE NEED TO GET THE PHSSICS CORRECT our black hoel is still a toilet drain. stuff behvaes differntly near a balckhole"** (2026-08-28)
   `MEASURE:` the near-field table in `BOARD_BLACKHOLE.md` §V4 — **horizon (0.1717), photon sphere (0.2576) and ISCO (0.5151) all fit inside ONE softening length (1.0)**.
   State: `[READ particles.metal:1429]` the tidal radius is computed honestly then thrown away by `rt2 = min(rt2, (1.4·cellSize)²)` — reach is **1.4 sim regardless of mass**. ⚠️ Deleting it alone plateaus at 2.00–3.46 sim; the 3×3×3 scan bounds separation independently. **Clamp + scan must move together. Do NOT predict "reach scales with mass".**

2. **"its ampfliefied when i advanc time or uppen the x4 x8 x16… the only thing its uspposed to do is play it faster"** (2026-08-29) — 🚨 **THE TOP PHYSICS BUG**
   `MEASURE:` **the Physics-substeps slider sweep — 1 / 2 / 4 / 8 / 16, read `[PERF] fps` at each. ~30 s of his hands, NO code.** ⭐ **This is the ONLY thing blocked on him. Ask for it first. Never guess a row of the cost table.**
   State: `[READ main.cpp:2697]` `simDt = 0.0165f * timeWarp` then ONE `computeStep` — at ×64 the step is **1.056 in a single step**. ⭐ `[READ app_state.h:73]` **the fix already exists**: `uiPhysicsSubsteps` is the fixed-dt accumulator, stable, on a slider — *"Leave time-warp at ×1 and dial THIS for speed."* **A solved problem wired to the wrong control.** ⚠️ Do NOT naively wire warp→substeps: rate-based drain/recycle run **per substep**, so the hole would evaporate for a new reason.

3. **"the way that the mergers behave is broken"** (2026-08-29)
   `MEASURE:` `[GRAV] mrg=reached/landed/refused`, `feed=`, `seeds=`. **Retest AFTER (2)** — warp corrupts merge rates, so measuring now measures the wrong thing.
   State: `[MEASURED n=191]` seeds up to 11, capture bursts to 638 meals, **20 merges landed / 0 refused**, `Mmax` 0→101,800 then **→50 with seeds=0**, and it **cycles**; peak varies **6×** across three runs of one build.

4. **"the entire seed mechanism is kinda broken size and mass and color has no rperesantation… scaled up form single merger to a black hole itself"** (2026-08-29)
   `MEASURE:` crossing `M_BH_SEED=50` drops luminance **1000 → 10 (100×)**; `[READ render.metal:488]` mass is clamped to **500 M☉ before the kelvin law**, so colour saturates on the star path too.
   State: ⭐ **ROOT CAUSE — a body has a MASS but no RADIUS**, so every law needing a size substitutes a mass formula or a mesh constant (`space_synth_a_body_has_no_radius_2026-08-29`). Design: `docs/SEED_CONTINUUM_DESIGN_2026-08-29.md`. ⛔ **BLOCKED ON HIM: `Particle` has NO spare component** — all three `entanglement` "pads" carry live data. Carrying `R` needs a **wider struct**, his call.

5. **Camera rides — one answer outstanding.** Dwell ~0.4 s at each waypoint (passes exactly through his framings) **vs** advance early (continuous, rounds corners). Recommendation: **dwell.** Design ready in `docs/CAMERA_STEP2_DESIGN.md` §9.

6. **Queued, decided, not built:** 6-point JWST star spikes (`render.metal:2652` draws a 4-point cross today) · delete the `max()` latch (§5 below) · the era-frozen constant sweep (`BOARD.md` §W6) · `lastHorizonMass` is still profile mass under a seed radius.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **BPM-synced camera damping — REJECTED 2026-08-28.** *"we dont want a bpm sync… its just about smoothness in camer amotion."* 🚨 It was the **brain's wording**, not the camera window's: they asked a question, the brain relayed it as a proposal. **Quote a peer's question; do not re-word it.**
- **Cinematic mode owning time warp — REJECTED 2026-08-29.** *"at warp we spin the object not the camera u know so the question doesnt make sens."* Cinematic = `c`, camera speed only.
- **ζ→1.00 on orbit — NOT TAKEN.** He praised the snappiness; the ~4.13° overshoot is the thing he likes. Zoom is already 1.00.
- **Deleting the `:1429` clamp alone — INSUFFICIENT.** The 3×3×3 scan caps separation at 2.00–3.46 sim regardless.
- **Rebuilding either BH renderer — FORBIDDEN.** 852 lines deleted 2026-08-27, committed. ⚠️ The FPS rejection of the Kerr raytracer **stands**. But *"impossible because of polar caustics"* is **not a correct sentence** — that needed Kerr caustics AND an infinitely thin disk AND unfiltered single rays; our emitters have finite extent. Do not carry the wrong reason forward.
- **Treating a shrinking hole under play as a bug — FORBIDDEN.** It is his 2026-08-04 reversibility feature. See §5.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-08-29 10:38:41  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-POST-TUBE

1. git
  ok    branch post-tube, HEAD 68ee28c
  FAIL  11 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M SpaceSynth.app/Contents/MacOS/SpaceSynth
           M docs/CAMERA_STEP2_DESIGN.md
           M docs/blackhole-library/README.md
           M imgui.ini
           M src/core/camera.h
           M src/main.cpp
           M src/render/renderer.mm
          ?? docs/BH_NEAR_FIELD_AUDIT_2026-08-28.md
          ?? docs/SEED_CONTINUUM_DESIGN_2026-08-29.md
          ?? docs/STATUS.md
          ?? docs/blackhole-library/04_HOW_THE_REFERENCES_DO_IT.md
  WARN  build artifact is TRACKED — commit sources separately FIRST, then it alone:
          SpaceSynth.app/Contents/MacOS/SpaceSynth
  WARN  no upstream set for post-tube

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 9751d9a — 4 docs-only commit(s) since, no source change
  ok    docs/BOARD_BLACKHOLE.md size 94129B
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 9751d9a — 4 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 121403B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    35 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:566:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:753:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1109:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1407:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1410:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  7 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

**The FAIL above was REAL and is now CLEARED.** Three windows had work loose in one tree; the BH window correctly refused to commit unilaterally and asked which of us would. Sources committed one concern per commit (`d6a49f2` M fix, `ea14dbc` camera), then docs, then the **tracked binary alone and last**, `imgui.ini` restored at commit time. Re-run output is in §4b of the final commit message.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "Key the drawn hole off the **monotonic** seed mass" (the dispatch that started the day) | 🚨 **Non-monotonicity is HIS FEATURE**, not a bug. `[READ particles.metal:786]` a revived corpse returns at its exact spawn mass, **withdrawn from the hole** — *"the only way the hole can shrink under play… Explicit call by Jamal, 2026-08-04."* `[MEASURED]` **15 of 19 `Mmax` drops at phase=3.0.** ⛔ **`space_synth_bh_reversibility_2026-08-07` already said this and I did not read my own index.** The `max()` latch I asked for hides 8 of his 10 shrinks — **recommended for deletion.** |
| "The hole shrinks to half–two-thirds its old size" | `[MEASURED n=137]` it draws at **0.018** of the profile early in a run. 0.627 was one mature run; I relayed it as general. Honest statement: **persistence 7%→57%, size ×0.018 (n=10). It TRADES size for persistence.** |
| "A 34.1 × 33.0 px isotropic lattice in his screenshot" | Crop coordinates read off a ~2000px-wide **rendering** of a 3024×1964 file → wrong region, wrong scale. The re-measure (46/52 px) was **also** wrong: 1D FFT peaks on a sparse dot field are artefacts. Use a **high-passed 2D tile autocorrelation** (real lattice ≈0.1; clean frames gave ±0.001). |
| "One tap was ~31°, now 90° — 3× bigger" | True only at 60 Hz. The old tap ran **7.28°–65.43°**, a 9× spread. |
| "`nSub` is the cheap central-gravity substep" | `[READ renderer.mm:3064]` it is the **FULL** physics loop. The cheap one was tried, **EXPLODED**, and was replaced. |
| "The fix for time warp is unbuilt / TBD" | `[READ app_state.h:73]` it was **built 2026-07-25, is stable, and is already a slider**. It is wired to the wrong control, not missing. |
| "Deleting the `:1429` clamp makes reach scale with mass" | The 3×3×3 scan caps separation at 2.00–3.46 sim. Would have plateaued on his second run and burned a verdict. |
| The BH window's "two instruments disagree by 4 orders of magnitude" | **Cross-frame pairing** — `[AMR]` prints 417×, `[GRAV]` 418×, `[HORIZON]` 834×. Same frame, `[CORE] M(<2)` and `[AMR] M<Rfine` are **identical to the digit**. |
| The CAMERA window's "no Kerr `a` anywhere in `render.metal`" | `[READ render.metal:308]` `KERR_A = 0.5f`, used at `:1409`. ⭐ **The truth is sharper: kinematics a=0.5, shadow geometry a=0 (`2.5980762` = Schwarzschild), Gargantua a=0.999 — three spins in one renderer.** |

🪶 **The trap that produced three of these: a comment can be honest and still wrong, because the DESIGN moved under it.** `renderer.mm:209` and the 2026-06-13 note at `:3313` both predate his 08-04 call. **Check a comment's DATE against later decisions, not just the code beneath it.**

🚨 **And the rule that outranks every measurement above: five clean tests on two frames is evidence about THE FRAMES, never about his claim.** He was windowed; star size is in device pixels with no normalisation to the drawable. See `feedback_dont_second_guess_his_claims`.

---

**Last Updated:** 2026-08-29 10:50:00
**Folded into board:** `docs/BOARD.md` §W + `docs/BOARD_BLACKHOLE.md` §V @ 2026-08-29 10:45:00, both re-stamped at `01f1048`
