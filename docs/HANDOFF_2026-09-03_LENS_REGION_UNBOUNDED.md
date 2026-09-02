# SPACE SYNTH — handoff 2026-09-03 00:35:00 (BRAIN)

> **His verdict on this state:** *"lense lowkey explodes until the entire field is gone it lokey needs a cap the entire blakc hole.."* (2026-09-03 00:08:00)
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` **§AC.10 then §AC** — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `9a62447`
**Build + launch:** `bash package_macos.sh` · `SS_FULLSCREEN=1 SS_LENS_RENDER=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth`

🚨 **NO SOURCE CHANGED THIS SESSION.** This window ran, measured and routed. Every source line is still `9f61c66`; the three commits above it are docs. A reader looking for a code diff will find none, and that is correct.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | **His verdict was about to be taken on a pre-lens binary.** | PID 13310 launched **19:36:26**; the four lens commits `24c91ab..9f61c66` landed **19:43:47–19:44:38**, all after it. A running process keeps its loaded image, so the two-circles cut was not in the window he was looking at. | Relaunched. The frame he judged came from a process started **23:31:52**, after the **19:50:33** bundle. | `ps -Ao pid,lstart` + `git log` timestamps | `[MEASURED n=3 checks across 2 relaunches]` |
| 2 | **"Run `package_macos.sh` before testing anything against §AC"** — OPUS's handoff §4, and my own "rebuild rather than trust it". | Both of us called the bundle stale off its mtime alone. | **Relaunch, not rebuild.** Newest tracked source `src/render/render.metal` **19:44:30**; binary + `default.metallib` both **19:50:33**. The artifact postdates every source and every lens commit. Someone rebuilt at 19:50:33, 29 s after OPUS's preflight read STALE at 19:50:04. | `stat` over `git ls-files` vs `SpaceSynth.app` | `[MEASURED n=2, independently by OPUS and BRAIN]` |
| 3 | **`SS_LENS_RENDER` and the second gate were unstated in the relaunch plan.** | The plan named the flag with no default and no second condition; a frame taken below a formed hole shows no lens and reads as the cut failing. | `SS_LENS_RENDER` defaults to **0** and is read into a `static` — must be in the environment AT LAUNCH. The pass additionally needs `lastHorizonR > 0.0f && bhStrength >= 1.0f`. Both folded into the capture procedure before the shutter. | `renderer.mm:4694`, `renderer.mm:4705` | `[READ renderer.mm:4694]` |
| 4 | **The frame was captured with no recorded hole state.** | The 20:02:05 run produced a verdict request with no `[BH-POP]`/`[HORIZON]` pairing, so a gated-off lens and a failed cut were indistinguishable. | Frame **23:36:23** carries its hole condition and its provenance: **PID 18914, run 23:31:52–23:52:20**, `bhStrength=1.00 LATCH` since 23:32:44, nearest sample 35 s before the shutter and explicitly marked non-simultaneous. | scratchpad `two_circles_frame_2026-09-02_23-36-23.png`, `side_by_side_…png` | `[MEASURED n=1 frame, state-paired]` |

⭐ **The measured finding this session produced is OPEN, not closed — it is board row §AC.10, and it is item 1 below.**

## 2. 🚨 OPEN — his list, verbatim

1. **"lense lowkey explodes until the entire field is gone it lokey needs a cap the entire blakc hole.."** (2026-09-03 00:08:00) — **and his allocation:** *"fable pin the sigma split first then derive the cap"* (00:25:00)
   `MEASURE:` the σ pin FIRST — one probe's v² against both instruments **in the same frame** (§AC.2 / §AC.8 #4). Then derive the cap from the influence law.
   State: `[MEASURED n=2 runs, 359 paired samples]` split on the real gate (`bhStrength >= 1.0f`, **not** the sticky `LATCH` label): PID 18914 gate-open n=15, `r_infl` mean **88.30** max **193.59**, any-time max **794.17**; PID 19386 gate-open n=14, mean **14.18** max **26.14**, any-time max **422.41**. Design region ≈**20** → ~10× its own scale while drawing, 7× swing run-to-run on identical code. `infl` reaches **27406**, wider than the boarded 3800–4960. — **NOT known:** the σ units, and therefore any honest cap value. A constant chosen before the pin is a magic number. **FABLE owns both steps, in that order. FABLE also holds the running app from 00:25:00.**
2. **"the same boxy grid issue weve had for months"** (post-play re-formation, ~19:05)
   `MEASURE:` play→release cycle, screenshot the re-formation window; suspects on record: cubic-hash physics, AMR box, per-cell aggregates.
   State: PRE-EXISTING by his own dating — **UNOWNED, untouched this session.**
3. **"this shoiuld take longer shouldnt it?"** (whole field swept at strength-100, ~6–11 s, ~18:30)
   `MEASURE:` the sweep-influence bound — the SAME `r_infl` law limiting the time-lapse's reach.
   State: **the same law as item 1.** His cap verdict ordered what this row called "named, not ordered". One fix, two symptoms.
4. **The shining stage (§Z15)** — the centre torus is the DISK-BOUND ring with no emission law.
   `MEASURE:` n/a until built. State: ruled in the disk design (#5 cooling law derived), **unbuilt.**
5. **"theyre also alive during play. no excuses. wwe have 120 there too"** (fps)
   State: OPUS's thread. **OPUS is idle and unallocated as of this handoff.**

⚠️ **§AC.6 — the two-circles GEOMETRY itself (self-threading vs stacked circles) carries NO verdict.** He judged the region's growth, not the geometry. `9f61c66` remains unjudged on the question it was written to answer.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Grouping `r_infl` by the `LATCH` label — WRONG READING, caught 2026-09-03 00:20:00.** `LATCH` is sticky: it persists in `[BH-POP]` while `bhStrength` drains to 0.02, so grouping by it mixes drawing and non-drawing frames and reports gate-open mean 5.17 / max 26.14. The gate is `bhStrength >= 1.0f`. Split on the real condition or the numbers are meaningless.
- **Reading the region off a single run — REJECTED by its own data, 2026-09-03 00:22:00.** PID 19386 alone says the runaway happens only while the lens is gated OFF (gate-shut mean 92.70 vs gate-open 14.18), which would have pointed the cap at the wrong mechanism entirely. It is a **14-sample artifact**; PID 18914 shows mean 88.30 / max 193.59 with the gate OPEN. n=1 on this quantity is not evidence.
- **A clamp constant as the cap — ruled out before build by his standing rule.** The scale audit's law: derive it, never offer him a menu of numbers. Not tried, recorded so nobody tries it.
- **`pgrep -x` to decide the app is free — dead since two bundles exist on disk.** Use the `ps lstart` + path discriminator; both trees carry a `SpaceSynth` of the same name.

## 4. 🔬 PREFLIGHT

```
(run at 2026-09-03 00:27:21, pre-commit — the imgui.ini FAIL is cleared by this handoff's commit)
PREFLIGHT 2026-09-03 00:27:21  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 9a62447
  FAIL  1 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M imgui.ini
  ok    pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 9f61c66 — 3 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 210156B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  WARN  docs/BOARD.md has no 'Commit at last verification: `<sha>`' line — add one
  WARN  docs/BOARD.md is 165275B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    46 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:576:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:763:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1144:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1464:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1467:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2558:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/render.metal:3284:                mp = rotAboutAxis(mp, float3(0.0f, 0.0f, 1.0f),
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

⭐ **§5's 8 sites are the pre-existing list and NONE was touched — no source changed this session.** The §2 WARNs on file size and `BOARD.md`'s missing verification line are pre-existing and untouched.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "Rebuild rather than trust the 19:50:33 bundle — I only read its mtime." | I never compared it against the sources. Newest source is 19:44:30; the bundle postdates every source and every lens commit. It was a **relaunch**, seconds, not a build. OPUS pushed back with numbers and was right. |
| "The runaway happens only while the gate is SHUT." | A 14-sample artifact of PID 19386. PID 18914 shows `r_infl` mean 88.30 / max 193.59 **with the gate open**. Would have aimed the cap at the wrong mechanism. Caught by checking the second run before reporting. |
| Relaying FABLE's *"ran roughly 8 minutes"* shape without checking its derivation | It was read off `Tmeas=435s`, which is a per-shell **orbital period** in `[BALANCE]`, not elapsed wall time. Grounded runtime is 20:02:05 → 20:13:59 = **11 min 54 s**. The frame-is-not-time trap in another dress. |
| — | The `mrg=` cumulative-vs-per-window correction is **OPUS's**, re-verified line by line at `renderer.mm:1546` and `:2552-2553`; it is boarded in the stand-off memory, not re-claimed here. |

---

**Last Updated:** 2026-09-03 00:35:00
**Folded into board:** `docs/BOARD_BLACKHOLE.md` §AC.10 @ 2026-09-03 00:27:00
