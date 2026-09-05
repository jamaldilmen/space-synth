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
   - **A. ⛔ WITHDRAWN — it was already shot, 36 minutes before I proposed it.** I offered the
     orbit (φ = π/2, θ swept 2π, `orbitUpFix`) as never rendered. **`take10_orbit_wide` was
     rendered and DELIVERED 2026-09-05 14:39** (DXV3 on LOSTINSPACE/JAMAL, ORTHO, 5400 f,
     rho 50 → 5800) `[READ bible §5.2, board §AA29]`. My read was against a tree where §5.2 did
     not yet exist on disk (it landed in `7ea7ba1` at ~15:27, after I answered), but the take
     existed at 14:39 and the claim was false when I made it. See §5.
   - **B. The full plunge — RE-SCOPED after take 10.** One ride, rho **5800 → 50**
     (`zUnit = 1 − smooth(f/N)`), **PERSPECTIVE, no orbit, θ fixed.** The full 50..5800 span is
     no longer unused — take 10 swept it, but ORTHO, upward, and combined with a 360° orbit
     `[READ bible §5.2]`. What is still unrun is the span travelled DOWNWARD in perspective with
     the camera pointed at one thing: takes 8/9 only reached 2925 `[READ bible §5.1]`.
     ⚠ rho 50 is INSIDE the 150 r_s matter shell, which is why take 4's chord opened on black
     (bible §5) — put the chord before the bottom, let the last minute run empty on purpose.
     🚨 **AND IT CANNOT START AT 5800 IN PERSPECTIVE.** BRAIN, cross-session 2026-09-05 15:25:
     the near-plane fix `38170d5` is a factor, not immunity — depth step = ulp·z²/near is 0.51
     units at rho 2925 and **2.00 at rho 5800**; he watched a 5-min POV take at 5800 on the
     FIXED bundle and called it shaking, and his order is to cap the zoom-out. Ortho is exempt
     (linear depth over ±5000). ⇒ **B ships either ORTHO at full range, or PERSPECTIVE capped at
     ~2925** — which is take 9's start, so the perspective version is only a direction-and-pose
     variation, not new ground. `[reported by BRAIN, to be board §AA30 — not verified by me]`
   - **C. The knife-edge reveal.** θ 0→90° at φ = 0, **zoom locked**. §6.4 says this pivot needs
     no up-fix and does not roll. Take 4 rode tilt AND zoom together; separating them is the
     shot. Set CC33 nonzero so `thetaRangeMax` becomes π/2 and the full 14-bit density lands in
     the 90° actually used `[READ src/main.cpp, the thetaRange selector comment]`.
   State: `[HYPOTHESIS]` on how B and C LOOK — neither has been rendered; A is withdrawn. The CC handles they
   need are `[READ]` verified to exist. Cost, if he picks one: hold the notes. `[MEASURED n=6,
   bible §4]` a sustained-note take renders 4–6× faster than a released-note one (take6 48.6 vs
   8.52 fps, take7 49.3 vs 13.24 fps).

2. **✅ RESOLVED WHILE THIS FILE WAS BEING WRITTEN — the dirty tree was FABLE's and FABLE
   committed it itself**, split exactly one concern per commit: `8182846` (the `setTiltAbs`
   wrap fix), `7ea4fe8` (`SS_CAM_THETA`/`SS_CAM_PHI`), `acda80f` (14-bit exposure), `23222fc`
   (the replay tools). `git status --porcelain` is **empty** at the final preflight below.
   What remains open is **the board header**: `docs/BOARD.md` and `docs/BOARD_BLACKHOLE.md`
   still say `Commit at last verification: 41609e1`, 4 code commits behind, while §AA29 (the
   fold itself) is already written and names those four shas. That restamp is FABLE's — it
   verified them; I did not. **Original record of the dirty tree, kept:** `src/core/camera.h`, `src/main.cpp`,
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
session wrote no code.

**Final re-run, 2026-09-05 15:24:45, after both docs commits (§5 omitted, unchanged):**

```
1. git
  ok    branch true-physics, HEAD 2467d82
  ok    working tree clean — committed
  WARN  7 commit(s) not pushed

2. board vs HEAD
  FAIL  docs/BOARD_BLACKHOLE.md is 4 code commit(s) behind HEAD (verified at 41609e1)
  FAIL  docs/BOARD.md is 4 code commit(s) behind HEAD (verified at 41609e1)
  WARN  both boards >200 KB — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  FAIL  STALE: SpaceSynth predates src/core/camera.h — run the packaging script
  FAIL  STALE: default.metallib predates src/core/camera.h — run the packaging script

4. referenced paths (live docs only)
  ok    69 referenced path(s) in live docs all resolve
```

**Both remaining FAILs are the other windows' and are already owned:** the board restamp is
FABLE's fold (§AA29 is written, the header line is not moved) and BRAIN said at 15:25 it takes
both boards' stamps plus a rebuild before its own final preflight. The tree is CLEAN — no work
of mine is uncommitted. **BRAIN holds the tree from 15:25 (cross-session, this window replied
"off the tree").**

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| **"the orbit with `orbitUpFix` has never been rendered"** — said to him ~15:15 as shot proposal A | **False since 14:39 that same day.** `take10_orbit_wide` was rendered and delivered by FABLE at 14:39; I read the bible at 15:20, and §5.2 documenting it was not committed until `7ea7ba1` ~15:27. The memory file `space_synth_orbit_upvector_roll_2026-09-04.md` still said "shipped, never rendered" and I trusted it over asking the window that owns the renders. **Lesson: with four windows live, a "never done" claim about the SHOW needs the other window's state, not a memory file written yesterday.** |
| "neither take 8 nor 9 used the rho range that exists" — the premise under proposal B | Take 10 used all of 50..5800 at 14:39. B survives only re-scoped (perspective, downward, no orbit); see §2. |
| none other | The FOV limit was checked BEFORE it was stated, which is why the dolly zoom was offered as "what we can't do yet" rather than as a fourth shot. |

---

**Last Updated:** 2026-09-05 15:36:00 *(corrected: proposal A withdrawn, B re-scoped twice — once for take 10, once for BRAIN's POV depth bound — retractions written, final preflight appended. Previous 15:26:00.)*
**Folded into board:** the two corrections went into `docs/SPACE_SYNTH_LIVE.md` §5 (the bible
owns the shot vocabulary; `docs/BOARD.md` has no row that either correction contradicts) @
2026-09-05 15:23:00.
