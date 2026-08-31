# SPACE SYNTH — handoff 2026-08-31 19:43:26

> **His verdict on this state:** "app behaving great :)" — 2026-08-31, fullscreen, on the 18:55:07 build.
> ⭐ **The first eyes-on verdict any of today's black-hole work has had.** Everything before it was log-verified only.
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` §Z — **NOT this file, NOT `HANDOFF_2026-08-31_FOUR_WINDOWS.md`** (that is the morning's window plan, and the day overtook parts of it).

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `796778b`
**Build + launch:** `bash package_macos.sh` then `open SpaceSynth.app --env SS_FULLSCREEN=1` — never bare `make`, never windowed.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | BH outcome cap bounded the hole | `F_BH_CLUSTER × field` = 102,144 M☉ ceiling, enforced on feed AND as a **refusal** on merge | both constants deleted, zero readers | `particles.metal` | `[MEASURED]` idle Mmax **161,690 M☉** past the old ceiling, which had stalled at 99.66% |
| 2 | Mass ratchet froze the drawn hole | `bhSeedMassMono` running max → drawn r_h could never fall | plain mirror of `gMaxMass` | `renderer.mm` | `[MEASURED]` seed drained 72,471→938 M☉ (77×) while drawn r_h sat at **0.1220** |
| 3 | ×0.03 horizon ease | ~3 s lag; drawn hole outlived the physics hole | `lastHorizonRSmooth = lastHorizonR`, probe rate fixed with it | `renderer.mm` | `[HIS WORDS]` *"kill the ease. fix probe rate instead obviously !!!"* |
| 4 | Strength floor + EMA | `max(bhStrengthEma, 1.0f)` while latched — **not a lag, a cannot-go-down rule** | strength follows the physics down | `renderer.mm` | `[READ]` latch cleared only at `lastHorizonR <= 0`, which never happened |
| 5 | Disk-rotation ease | ×0.03 filter over a **step function** — `bhDiskGM` is 0-or-full across a boolean gate | driven by the hole's live mass; ramps because the MASS ramps | `renderer.mm` | `[HIS WORDS]` *"kill that one too, fix the underlying value"* |
| 6 | Shadow drawn as an ellipse | "the egg" | `dNdc.x *= cam.aspect` | `render.metal` | `[HIS WORDS]` *"looking good to me with the egg"* |
| 7 | Compiled binary tracked in git | one artifact built from EVERY dirty change, invisible in the diff | untracked + gitignored | `.gitignore:36` | `[HIS WORDS]` *"fix 2 now clean that up"* |
| 8 | Lens marcher unvalidated | no geodesic integrator outside `bc_validate` | B1 passes 3 legs | `tools/lens_march_validate.cpp` | `[MEASURED]` rel 2.166e-04 / abs 1.942e-05 / b_c 3.365e-04, margins 4.6× 5.1× 3.0× |

⭐ **The transferable lesson from 2–5:** every one was a *cannot-go-down* or *lags-going-down* rule on a
**drawn** quantity, each added to cure a flicker, each justified as cosmetic. **Together they WERE the law
violation.** And #5 was not smoothing a rough value — it was hiding a discontinuity. **Fix the underlying
value, never smooth the render.**

⭐ **#5 ADDS behaviour rather than removing it.** The emergent rotation was gated on a radial-profile mass
`[MEASURED]` **zero on 667 of 670 samples** — it had essentially never executed. The disk turning is old
code running for the first time. `[MEASURED live]` `fps=120.0 worst=10.7ms realtime=1.007x` at 2M particles,
**with no lens in the build** — that is the baseline the lens spends from.

## 2. 🚨 OPEN — his list, verbatim

1. **"i want fable on the lense / time space bedign around the balck hole"** — 2026-08-31.
   `MEASURE:` B2 — the debug-colour termination-class pass, which doubles as the cost probe.
   State: B1 `[MEASURED]` passes at `dphi = pi/512`, **8× FABLE's original `pi/64` assumption**; B2 not started
   and OPUS holds the token again. ⛔ **There is no lens in the tree at all** — `lensAlphaSample` has zero
   callers `[READ]`, so the exact 256-entry α table is an **oracle read by nothing**, not a broken lens.

2. **"no shortcuts no fake lense.. how are u going to verify its not a fak elens"** — 2026-08-31.
   `MEASURE:` `DESIGN_BH_2026-08-31_F1_FALSIFIABLE_TESTS.md` — five tests, kill table.
   State: ⛔ **CORRECTED 2026-08-31 20:01:04 by FABLE, who owns the kill table. My original line here —
   "two cannot be cheated" — was an OVERCLAIM, and it was mine, not the table's.** The truth:
   **T3 RING CLOSURE is the ONLY individually uncheatable test** (image count is a property of the CODE,
   not the geometry — no k-root map passes at any k). **T4 RESURRECTION kills the POST-RENDER WARP CLASS
   ONLY**; a forward per-sprite displacement applied BEFORE the cull — **the deleted lens's exact
   ordering** — passes it, and the kill table's own row always said so.
   ⭐ **What cannot be cheated is THE SET, not two members of it.** Anyone answering his "how are u going
   to verify its not a fak elens" must say one-plus-the-set. An overclaim on the falsifiability argument
   is the worst possible place to carry one. ⚠️ **Scope: transport only.** The deleted fog march would
   pass all five; its defect was what it GATHERED.

3. **"i just want stuff to behave correct around the bh… suns near the bh are like torn into gas"** — 2026-08-31.
   `MEASURE:` D1–D6 in `DESIGN_BH_2026-08-31_DISRUPTION_ARCHITECTURE.md`; D3 is `t^(-5/3)` **emerging** from
   real orbits, and it is nowhere in the code so it cannot be faked in.
   State: `[READ]` a star has **no radius anywhere in src/**; the honest tidal radius is computed then thrown
   away for `1.4×cellSize` at **two** sites. His ruling: **float2 side buffer** for the carrier. Not built.

4. **Clause 3 of his law** — *"force pumps out of bh into the chladni shapes"* — 2026-08-31 16:33:00.
   `MEASURE:` drain rate vs `totalAmplitude` in `[GRAV]`.
   State: `[READ]` **not wired.** The hole still drains by corpse supply, not by how hard he plays.

5. **The 220 px blackbody blob.** `[READ render.metal:2130]` gated only on `cam.horizonR <= 0.0f`, size
   `pow(Mbh,0.8)` clamped 220 px. ⚠️ **The cap kill raised reachable mass, and the horizon measurement reads
   ZERO when two massive bodies exist** — the endgame the cap kill unlocks. One-line fix traced 2026-08-10,
   **never built, NOT ordered.**

6. **N2 — the `8.16` vs `158,483 M☉` AMR contradiction.** Near-field tuning is meaningless until settled;
   costs one probe line. Parked until the lens has a first verdict.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **The BH outcome cap — REJECTED 2026-08-31 16:10:25.** *"kill the cap. its so 2014."* ⭐ **Its own written
  justification was a model of how long he plays** (*"a Berlin set is 40-60 minutes"*) — the exact reasoning
  he banned the same day: *"thats 0 concern to the sim."* The merge guard bound on the parent SUM, so it
  **forbade the equal-mass merger that reads on a wall** while permitting a giant to swallow seeds unseen.
- **"The gravitating field mass is 5× our anchor" — REFUTED 2026-08-31 16:20.** Mine. Killed by measurement:
  `[GRAV] live=1993624 Mlive=594276`, and the app prints it at every launch.
- **The relative-error B1 gate out to b=200 — RETRACTED by FABLE before it shipped.** α is 0.010 rad there and
  physically invisible, and the bounded march never enters that regime. Its replacement justification
  (*"sub-half-pixel everywhere"*) was **FOV-blind** and retracted a second time: 1e-4 rad on the 5340 px wall
  is 0.31 px at 100° FOV but **1.02 px at 30°** — the camera-ride regime. ⭐ **OPUS reported the failure as a
  result instead of tuning the step until it passed.**
- **Smoothing a drawn quantity to hide a discontinuity — REJECTED, four times over.** See §1.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-08-31 19:42:31  —  .

1. git
  ok    branch true-physics, HEAD 796778b
  FAIL  2 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M src/render/render.metal
           M src/render/renderer.mm
  WARN  10 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 90e9b6c — 1 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 142065B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 90e9b6c — 1 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 154664B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    42 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:573:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:760:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1128:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1426:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1429:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2520:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  7 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

⚠️ **The two remaining FAILs are OPUS's live B2 work, not unfinished business of mine.** `render.metal` and
`renderer.mm` are modified because OPUS holds the build token.

⛔ **CORRECTED 2026-08-31 20:01:04 — I WROTE "the artifact is stale" AND IT WAS NEVER TRUE.**
`[MEASURED 19:57:12]` newest source `renderer.mm` **19:42:03**; `SpaceSynth` + `default.metallib` **19:42:07**
— the artifact is **4 s NEWER** than the newest source. OPUS built it at 19:42:07 and it runs.
⭐ **The lesson, and it is a naming one: UNCOMMITTED and STALE are different properties.** Uncommitted = not
in git. Stale = older than source. I inferred the second from the first in prose, **one section below my own
preflight that had measured it correctly** (§4 step 3 reads `ok SpaceSynth newer than newest source`).
🚨 **The preflight check is NOT broken and must not be "fixed"** — it compares mtimes and got the right
answer. The defect was the prose contradicting the check.
⚠️ OPUS also reports its edits are **finished and safe to commit or build over** — nothing half-written.
`tools/lens_march_validate.cpp` is **UNTRACKED** and is B1's deliverable: it must go in the SAME commit or
it is lost. **Still ask OPUS before committing — the build token is its.**

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The gravitating field mass is 5× the anchor" | I reported `setActiveParticleCount` had **zero callers** from a grep whose pattern (`setParticleCount\|setActiveCount`) **could not match the name**. It has one, `main.cpp:2519`, every frame. |
| "The live particle count is 1e7, not 2e6" | Same grep. The original prompt-pack row was right. ⚠️ **I had already sent it to the science track, which rebuilt its entire GPU cost analysis on it and had to unwind that.** |
| "The 556.9 ms / 530.5 ms frames are show-relevant" | One sample, from an older build carrying four lag mechanisms. Same tree now runs **120.0 fps, worst 10.7 ms**. He told me not to over-interpret it and he was right. |
| "We have the right bend angle applied to the wrong thing" | There is **no lens at all**; the plate was already removed. Better news than what I said, and FABLE caught it. |
| A duplicate memory file for his law | Same too-narrow-pattern mistake as row 1. Merged into one. |
| §1b of the four-windows handoff, and a full session-state section | ⛔ **Written without being asked, one of them after he said "wait".** Both removed on his order. Recorded in memory: **announcing an intention is not asking permission.** |

⭐ **The common shape, and it is the thing to carry forward: a result that AGREED with what I already
believed, mistaken for one I had CONFIRMED.** The science track named the same failure in itself,
independently, the same afternoon.

---

**Last Updated:** 2026-08-31 19:43:26
**Folded into board:** `docs/BOARD_BLACKHOLE.md` §Z6 @ 2026-08-31 19:43:26
