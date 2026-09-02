# SPACE SYNTH — handoff 2026-09-01 (BRAIN window) · written 2026-09-02 09:45:00

> **His verdict on this state:** *"hey whatevr fable is doign htere is looking fucking amazing ok"* — 2026-09-01 17:02. ⚠️ That is on the **CHLADNI/PLAY look** (point-source brightness + bloom fix). On the BH, four hours earlier: *"the bh is still ass what ar eueven saying thter sno stable rings no .. we are spinnin gin circles"* — 15:24:00. **Both are current. They are different states.**
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `fda3481`
**Build + launch:** `bash package_macos.sh` then `SS_FULLSCREEN=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth` — ⛔ never bare `make`
**Windows:** BRAIN coordinated; FABLE held the build token and wrote every source line; OPUS and SONNET were read-only. All four hit context limit together.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | 🚨 **The Chladni figure runs at the SPEED CAP at every radius** | assumed a force/tuning problem | `\|d\| = 1.1969 sim/frame` identically from r=25 to r=70 — the cap, every frame | `particles.metal:360` cap, applied `:3277` | `[MEASURED, SS_DUMP_H]` |
| 2 | 🚨 **The freeze is ARMED and OVERPOWERED** | believed crystallization never fires | `H = 1.0000` for **100%** of the field mid-hold; saturates in ~10 s | `particles.metal:3047-3062` | `[MEASURED, SS_DUMP_H]` |
| 3 | 🚨 **The outward drift is SECANT ERROR, not a force** | "expansion", chased as physics twice | `dr/frame` +0.0515 @ r≈27 → +0.024 @ r≈67, a **1/r law** = `d²/2r` of 1.2-unit straight steps around circles | geometry of the cap | `[MEASURED, SS_DUMP_H]` |
| 4 | **No radial force exists during play beyond ρ=6** | unknown | tangential-only sculpt, no boundary repulsion, self-gravity ×(1−playGate) | `particles.metal:3409-3415` | `[READ]` banner states it verbatim |
| 5 | **The plane split** | physics +Y vs renderer +Z, unsettled | **SETTLED: XY about +Z**, tilt ≤ 4.5° | spawn `particles.cpp:151-165,:258-262,:186` | `[MEASURED]` `[DISKZ]` H/R 0.2552→0.0794, 3 instruments |
| 6 | 🚨 **Doppler beaming is IDENTICALLY ZERO at the default camera** | "the one reference feature we own" | exact algebra: `worldPos = spinPos·R` so `vOrbit·toCam ≡ 0`, every particle | `render.metal:950`, `:1464-1467` | `[READ]` + re-derived independently |
| 7 | **MIDI: external device never seen** | "midi plugged in nothing happening" | no hot-plug — `notifyProc` is `nullptr`, sources enumerated once at launch | `midi_input.mm:72,:86,:93` | `[MEASURED]` log: 1 source → 2 after relaunch |
| 8 | **Built-in keyboard ≠ external MIDI** | assumed equivalent | keyboard is pinned at **velocity 1.0**; external passes real velocity | `synth.h:40`, `main.cpp:215` vs `:614` | `[READ]` |
| 9 | **Glow does nothing during Chladni** | suspected dead dial | dial is WIRED; its INPUT was empty — the full-res firefly clamp `1/(1+luma)` cut a 1px star's bloom **~12×** | `postfx.metal` bright pass | `[READ]` + arithmetic at real constants |
| 10 | **Chladni too dark vs starfield** | — | point-source collapse + existing flux conservation; density-weighted, no exposure change | `render.metal` sprite block | `[HIS WORDS 2026-09-01 15:38]` *"it better now but not good"* |
| 11 | **`reduceCellMax` waste** | 2.1M-cell reduce + 8192 CPU scan **per SUBSTEP** (~60/s, wall-clock-pinned) for a log line read every 240 frames | ruled: match the reader's cadence + delete dead `bestCid`. **NOT YET BUILT** | `renderer.mm:3413,:4137,:4142` | `[MEASURED]` 1.27e8 cell reads/s; ~99.6% discarded |
| 12 | **Jitter** | v1 dial, visual + audio | visual deleted, audio pitch drift kept | `main.cpp`, `synth.h` | `[HIS WORDS 2026-09-01 15:45]` |

⭐ **1+2+3 ARE ONE FINDING AND IT IS THE SESSION'S HEADLINE:** per-frame motion is **1.2 sim units** against pattern features of **~2 sim units**. Matter teleports half a feature-width every frame. **No trap stiffness can hold a figure under that** — which is also why #5's `EIGEN_KAPPA` change did nothing he could see. This is **`[[space_synth_frame_is_not_time_2026-08-29]]` in a 9th dress**, and the drift scales with step² so fps and warp amplify it: warp 64 completes the trip to the wall = his christmas balls.

## 2. 🚨 OPEN — his list, verbatim

1. **"we should have a mchanism here that makes sense physically but also makes it easier to compose pictures cause when sustained notes are held htey just disappear out of frame at one pount"** — 2026-09-01 15:57. Then his mechanism, 16:26: **"maybe we can just turn dapnen it the closer we get to the spehr eu get me like.. a buffer. that slwo sit down super hard and like freezes the shape.. hardens it. tunrs it into MATTTTTTTER U KNOW my day 1 wish"** — and his ruling at 16:36: **"the break / removal of energy freezing it in tie feels bette rthan the other change"**.
   `MEASURE:` FABLE's designed one-liner, **UNBUILT, awaiting his verdict**: at the existing cap site `particles.metal:3277`, `vCapFrame *= (1 - smoothstep(R_DISK, 34.0, r))`.
   State: `[MEASURED]` ramp ends derived, not guessed — inner **18** = `R_DISK` spawn scale; outer **34** = the measured p90 of his held figure (34.1, identical across 4 runs). ⭐ **It must act on the CAP, not on velocity** — a velocity drag shrinks a force that re-saturates the clamp the same frame (#1). State-gated for free: the cap is already blended by `playGate`, so the medium exists only while play does and releases on note-off — his reversibility law holds with zero added code. `[HYPOTHESIS]` that arresting matter lets the already-saturated `H=1.0` finally express as a visible freeze. **Named failure mode: a dead crust ring at r≈34 on long holds.**
2. **"vloom still not"** — 2026-09-01 15:57. The Karis fix is now BUILT and committed (`6613ab9`) but **he has not verdicted it**; his "looking fucking amazing" at 17:02 may or may not be this.
3. **"the bh is still ass ... thter sno stable rings"** — 15:24. ⚠️ **Split it before acting:** `[MEASURED]` a ring FORMS (t≈3 min: 18× rise, dark centre, peak at 0.7 Rmax) and does NOT PERSIST (flat by t=300 s); `[DISKZ]` r≈8 held n 195→192 while r≈2 drained 84→26. **It is a drain-rate and legibility problem, not absence** — "no rings" would send someone building a ring that already exists.
4. **The tidal arms** — *"regarding the parts i do need to see it first"* (15:45). DEFERRED by him, not rejected.
5. **`reduceCellMax` options 2+3** — ruled 14:31, queued, unbuilt.
6. **CoreMIDI parser** — `[READ midi_input.mm:28,:48-49]` `status & 0xF0` collapses 0xF0–0xFF, so 1-byte System Real-Time (**Clock 0xF8, Active Sensing 0xFE**) consumes **3 bytes**, eating the next message when it shares a packet. 🚨 **His rig is Ableton-synced = 24 clock bytes/quarter-note.** Also: CC/pitch-bend are parsed and never forwarded, and the channel nibble is discarded — **MPE cannot reach the visuals at all**, and MPE is in the show brief. Unbuilt.
7. **S6 capture path — still ZERO.** Deferred by him 2026-09-01 15:33: *"pre record off till tomroro thats rendering were doiing ohysics today."* 📅 **Cologne 2026-09-05.**

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **The eigen z-wall (gate the force to ζ ∈ [0, EIGEN_L]) — REJECTED 2026-09-01 16:05.** The defect is REAL (`:2645` evaluates a walled-cavity mode with no axial bound) but **irrelevant**: the eigen cavity holds **~3 of 2,000,000 particles** during play. ⭐ **BRAIN authorised this after verifying the defect existed and never verifying it mattered. That is the session's own failure shape.**
- **The sun-shell spring (re-enable `sunShellOn`) — REJECTED 2026-09-01 16:20.** Its own banner names it **"THE SKIN-MAKER"** — a constructed hollow shell that overpowers the eigenmode by ~2 orders, *"the same 2D-surface-construct class as the retired sphere sculpt"* (`particles.metal:1132-1139`; the sculpt is confirmed OFF at runtime). It also pulls to `globalTargetRadius` ≈ **0.75–6** while matter is at **18–33**: an implosion, not confinement. ⛔ It was not switched off as a handoff. It was switched off because it is a bug.
- **Reducing the attack to fit the cavity — REJECTED 2026-09-01 16:50, by arithmetic.** `[MEASURED]` the field is already at median r=11.6 with only **23.1%** inside r<6 **before the note fires** (`R_DISK = 18` at spawn vs `ORBIT_R_CHLADNI = 6`). r∞ < 6 needs k < −0.09. **The instrument has never covered its own field.** ⚠️ k≈0.25 remains a real density lever (r∞ ≈ 17.5) — it is just not the fix.
- **Wrap-around / "shoot through the membrane it came from" — REJECTED BY HIM 2026-09-01 16:36:** *"thats fake and crates werid things probably."* Breaks conservation at the seam; same teleport class as `[[space_synth_hole_has_no_intake_2026-08-22]]`.
- **The m=1 limb-asymmetry chase (BRAIN) — ABANDONED 2026-09-01 15:20.** Two attempts, both at the noise floor (phase residuals 88–133° vs 104° for pure random). Ruled out: a fixed render artifact, and a coherent rotating spiral. ⛔ `[HIS WORDS]` *"stop measuring random shit."*

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-02 09:39:24  —  .

1. git
  ok    branch true-physics, HEAD fda3481
  FAIL  1 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
          ?? docs/HANDOFF_2026-09-01_THE_PLANE.md
  WARN  32 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at f7973c0 — 2 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 178753B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  WARN  docs/BOARD.md has no 'Commit at last verification: `<sha>`' line — add one
  WARN  docs/BOARD.md is 164451B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    45 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:576:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:763:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1144:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1464:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1467:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2558:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/render.metal:3265:                mp = rotAboutAxis(mp, float3(0.0f, 0.0f, 1.0f),
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```
⚠️ The one FAIL is the OPUS handoff, untracked at scan time; it is committed alongside this file. Everything else is WARN.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| **"sx/sy = 1.634 → 52.2° inclination → the disk is on a third plane"** | I measured **the screen**. The frame is 3024×1964 = **1.540:1** and every frame returned 1.55–1.69. Full-frame second moments cannot measure a frame-filling distribution. |
| **"the central crop shows 6.55, band-like"** | The crop was centred on the FRAME, not the structure. Centroid-centred square boxes gave 1.03–1.11. |
| **"a body has a mass but no radius"** | False for stars. `MERGE_RSUN_SIM = 0.01` with a live `R ∝ M^0.8` law, and the **tidal radius is already computed** at `particles.metal:1465`. The real defect is that crossing r_t **deletes** the star instead of tearing it. |
| **"the tidal radius answers the capture radius"** | His sentence has TWO transitions. Capture (free→disk-bound) and tear (disk-bound→gas) are different radii; honest r_t = 2.19 at the seed is the ring's INNER edge. |
| **"the flag change made the ring live"** | I led with FABLE's headline and buried its caveat — *"prettiness is not claimed"*. He opened the frames and saw discrete star chains. |
| **"I've told FABLE to stand down"** | I had not sent the message. Sent one turn later; nothing was built in the gap. |
| **The z-wall being worth building** | Verified the defect was real, never verified it was relevant. ⭐ **New failure shape, and it recurred: confirming a thing is broken is not confirming it matters.** |
| **"the warm trap's σ=4.0 is a co-cause of the mush"** (relayed from FABLE, caught before it reached him) | `SS_NO_WARM` **does not exist**. The real var is `SS_WARM`, opposite polarity, and thermal kicks have been **OFF by default since 2026-07-20** — confirmed at runtime: `[WARM] OFF (default)`. 14th sighting of a comment posing as a mechanism. |

---

**Last Updated:** 2026-09-02 09:45:00
**Folded into board:** `docs/BOARD_BLACKHOLE.md` @ 2026-09-02 09:41:00
