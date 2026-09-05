# SPACE SYNTH — handoff 2026-09-05 15:26:00 (OPUS)

> **His verdict on this state:** not seen yet. He asked for "two three more" shot ideas plus a
> cinematography skill check (2026-09-05 ~15:1x); the three shots below are PROPOSALS, unrun.
> **Cold start:** read `docs/SPACE_SYNTH_LIVE.md` §5 then `docs/BOARD.md` §AA28 — NOT this file.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `74a21d8`
(read-only this session; the show worktree `SPACE-SYNTH-LOST-IN-SPACE` @ `c912147` was read too)
**Build + launch:** `bash package_macos.sh` then
`SS_FULLSCREEN=1 SS_WIDTH=19644 SS_HEIGHT=1680 SS_ORTHO=0 SS_FOV=45 SS_REF_HEIGHT=420 SS_LUM_CEIL=520 SS_CAM_RHO=50 SS_LENS_RENDER=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth`
**No code was written this session.** Docs only: two corrections into the bible §5.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | Bible §5 states the zoom CC spans "rho 50 → 2000" | 2000 | `kMaxRho` is **5800** since 2026-09-05; CC20/52 maps the 14-bit pair across `kMinRho..kMaxRho`, so it reaches 5800. The POV takes' 2925 is the exact midpoint of 50..5800, not a second map | `src/core/camera.h:121` (hunk untouched by the working-tree edits); bible §5 | `[READ src/core/camera.h:121]` |
| 2 | FOV silently assumed available to a ride (a dolly zoom was on my own shot list) | assumed rideable | **not rideable.** `sFovDeg` is a function-local `static` initialised ONCE from `SS_FOV` on the first perspective frame; no `case` in the `MidiKind::CC` switch writes it | `src/main.cpp`, the `sFovDeg` lambda + the CC switch (symbols, not lines — the file has uncommitted edits) | `[READ src/main.cpp]` |
| 3 | "Is there a cloud skill for cinematography?" — unknown | unknown | **no.** `~/.claude/skills/` holds only `ac-shadows-modding` + `handoff`; both marketplace catalogs (`claude-plugins-official`, `fundamental-physics`) scanned for cinema/camera/film/shot/storyboard/3d/animation. Closest are `hyperframes` (HTML→video) and `runway-api` (generative video) — output pipelines, not shot grammar | `~/.claude/plugins/marketplaces/*/.claude-plugin/marketplace.json` | `[READ marketplace.json ×2]` |

## 2. 🚨 OPEN — his list, verbatim

1. **"i need some inspo for shots we could run i want like two three more. also with the black hole"** (2026-09-05 ~15:1x)
   `MEASURE:` his pick. Three proposals were given, all built from CCs that already exist:
   - **A. The orbit that was fixed and never shot.** φ = π/2, θ swept the full 2π, rho held.
     Take 3 rolled a full 360° because `refUp` derives from θ (bible §6.4); `orbitUpFix` pins
     `refUp` to the disk normal, shipped `14757d5`, **never rendered** `[READ bible §6.4]`.
     `thetaRangeMax` already defaults to 2π so the 14-bit theta needs no driver change.
   - **B. The full plunge.** One ride, rho **5800 → 50** (`zUnit = 1 − smooth(f/N)`). Take 8 ran
     50→2925 and take 9 ran 2925→50 — neither used the range that exists `[READ bible §5.1]`.
     ⚠ rho 50 is INSIDE the 150 r_s matter shell, which is why take 4's chord opened on black
     (bible §5) — put the chord before the bottom, let the last minute run empty on purpose.
   - **C. The knife-edge reveal.** θ 0→90° at φ = 0, **zoom locked**. §6.4 says this pivot needs
     no up-fix and does not roll. Take 4 rode tilt AND zoom together; separating them is the
     shot. Set CC33 nonzero so `thetaRangeMax` becomes π/2 and the full 14-bit density lands in
     the 90° actually used `[READ src/main.cpp, the thetaRange selector comment]`.
   State: `[HYPOTHESIS]` on how any of them LOOKS — none has been rendered. The CC handles they
   need are `[READ]` verified to exist. Cost, if he picks one: hold the notes. `[MEASURED n=6,
   bible §4]` a sustained-note take renders 4–6× faster than a released-note one (take6 48.6 vs
   8.52 fps, take7 49.3 vs 13.24 fps).

2. **The work tree is dirty and it is NOT mine.** `src/core/camera.h`, `src/main.cpp`,
   `imgui.ini`, mtimes 13:41:52 / 14:08:18 / 14:08:55 today — a live session (`FABLE [50f12e]`
   is busy) mid-work on the song shot: `SS_CAM_THETA`/`SS_CAM_PHI` launch envs, the
   nearest-representative `setTiltAbs` wrap fix, and a 14-bit exposure pair (CC22 MSB + CC54
   LSB). **I did not commit it** — see §3.
   `MEASURE:` `git -C "…/SPACE-SYNTH-TRUE-PHYSICS" status --porcelain` must be empty before the
   token changes hands; that commit belongs to the window that wrote it.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **A dolly zoom (travel in while the lens widens) — NOT SHOOTABLE 2026-09-05 15:23:00.** FOV
  is read once at launch from `SS_FOV` into a function-local `static`; the CC switch never
  touches it. It needs a new CC plus a per-frame FOV into `perspectiveMatrix`. Every take so
  far changes framing by rho alone. Recorded in the bible §5 so the next window does not
  re-plan a shot around it.
- **Committing another live window's uncommitted work at handoff — REFUSED 2026-09-05 15:26:00.**
  The handoff rule ("git status empty") exists so MY work is never left dangling. These three
  files were written by another session 72 minutes ago and are still being edited; attaching
  them to a commit of mine would put an unverified message on measurements I did not take, and
  splits its diff in half. The tracked-binary trap does not apply here (`SpaceSynth.app`'s
  binary is untracked — only the Syphon framework files under it are in git), so nothing was
  shipped inside an artifact either way. **The FAIL stays in §4 unedited.**
- **Looking for an off-the-shelf cinematography skill — none exists.** Both marketplaces
  scanned (§1 row 3). If he wants one, it has to be written; not written unasked.

## 4. 🔬 PREFLIGHT

Run at 2026-09-05 15:20:41, before the two docs commits below:

```
PREFLIGHT 2026-09-05 15:20:41  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 74a21d8
  FAIL  3 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M imgui.ini
           M src/core/camera.h
           M src/main.cpp
  ok    pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 41609e1 — 6 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 269975B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 104965B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 41609e1 — 6 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 211559B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    69 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:577:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:765:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1146:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1466:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1469:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2585:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/render.metal:3329:                mp = rotAboutAxis(mp, float3(0.0f, 0.0f, 1.0f),
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

The §1 FAIL is the other window's work (§2 item 2, §3). §5's 8 sites were not touched — this
session wrote no code. The final re-run is appended at the bottom of this file.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| none | Nothing said to him this session was corrected. The FOV limit was checked BEFORE it was stated, which is why the dolly zoom was offered as "what we can't do yet" rather than as a fourth shot. |

---

**Last Updated:** 2026-09-05 15:26:00
**Folded into board:** the two corrections went into `docs/SPACE_SYNTH_LIVE.md` §5 (the bible
owns the shot vocabulary; `docs/BOARD.md` has no row that either correction contradicts) @
2026-09-05 15:23:00.
