# SPACE SYNTH — handoff 2026-09-02 19:47:00 (OPUS window: merger stand-off + star capture)

> **His verdict on this state:** *"i actually think it makes sense now.. the smalel rbodies started moving again"* (2026-09-02 15:50, on the dynfric fix) — and on the biggest one still sitting: *"why would it.. nothing is pulling at it u know."* Star capture not yet seen by his eyes.
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` §AB.10 → §AB.4b → §AC — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `9f61c66`
**Build + launch:** `bash package_macos.sh` then `pkill -f SpaceSynth; open -n SpaceSynth.app --env SS_FULLSCREEN=1`

⚠️ **This window built exactly one thing (`66faa37`) and did not launch the app once.** Everything else below was measured offline from BRAIN's existing dumps and his own logs. FABLE's lens commits (`24c91ab`, `1ff86d4`, `2a0d804`, `9f61c66`) were **not read** by me — they are FABLE's rows.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | Merged bodies frozen in place; *"they dont freaking mov eonowhere"* | Chandrasekhar dynfric read the body's OWN deposited mass as the background it plows through — `rho` from `cellMass` includes the body, `vmeanT` is COUNT-weighted (`cw = min(cellCounts,32)`) so a 236k M☉ seed contributes ≤1/32 to the mean it is dragged toward ⇒ `coef ∝ M²`, **9–12 orders over its own 0.1 cap**, permanently saturated | Subtract the body's own deposit from the density it drags against, using the same index formula `count_cells` deposits with | `particles.metal:2126-2160` (fix), `spatial_hash.metal:79-101` (the NGP deposit that makes the subtraction exact) | `[MEASURED, his play.log]` `[DENSPROBE] TOP CELL` held `(69,63,62)` for **70 consecutive prints ≥70 s** where free gravity predicts 36 sim of travel · `[HIS WORDS 15:50]` |
| 2 | BRAIN's claim that mass-proportional softening was the stand-off mechanism | Believed to bite | **Does not bite**: mass term **0.0073** vs `cellSoftFloor` **1.0** at 234,805 M☉; needs >3.2e7 M☉ | `particles.metal:1933-1934` | `[READ]` + arithmetic on his run's own constants (`gm=1.965`, `massTotal=595,768`) |
| 3 | *"the orbital force of hte mergers throws more particle sout hen it pulls in"* — no instrument read it | Unmeasured | **Confirmed as an outcome, refuted as a mechanism.** Growth state NET INWARD (0/15 pairs separating, 3 dumps); merger state NET OUTWARD +17,591…+17,838 M☉·sim/s (5/6 pairs separating). **NOT centrifugal** — clumps carry only **9–21% of circular velocity** | offline, `late_t90.bin` + `stack_1/2`, `rest_t30` | `[MEASURED n=3 dumps]` for the inward arm; `[MEASURED n=1 dump]` for the outward arm — **hypothesis-grade until stacked** |

## 2. 🚨 OPEN — his list, verbatim

1. **"STAR CAPTURE MAIN ISSUE OVER EVERYTHING ... tackle that asap"** (2026-09-02 ~16:30)
   `MEASURE:` `cap=reached/landed/refused` on `accDiag[5..7]` — at the tidal-test pass, after `reserved`, and at the silent `continue` (`particles.metal:1588`). ⚠️ `accDiagBuffer` is cleared over its **first 2 words only** (`renderer.mm:2546`), so the existing `mrg=` triple is **cumulative-since-launch, not per-frame**; a new counter inherits that unless the clear range grows.
   State: `[MEASURED n=1 dump]` **1,697,357 particles = 85% of the field are inside a seed's capture radius every rest frame; ~280 admitted at 120 fps ⇒ 99.984% refusal.** `[READ :1588]` the refusal is a silent `continue` with no counter — it has never appeared in any log. `[READ :255-266]` the shipped `h/r=0.1` cuts the budget ×55.7 to **1.26 stars/seed/frame ⇒ 99.9997%**. **NOT** measured: whether the refusal is what he is actually seeing on screen, and whether any of this survived `66faa37`.

2. **"theyre also alive during play. no excuses. wwe have 120 there too."** (his fps control, ~16:30)
   `MEASURE:` A/B the rest path with `SS_INERT_KEEP` — the same particle count at rest with capture off vs on.
   State: `[READ, all gated OFF during play]` capture `:1451`, field gravity `:1785` (`gravSupport<0.999`), legacy grid pressure `:3144`, relaxation `:2418`, collisions `:2891`, seed↔seed merge `:1637`. **Three FULL 27-cell scans per particle minimum ≈ 162M cell lookups/frame at rest, ZERO during play**, plus 1.7M threads on 4 atomic words. **`[HYPOTHESIS]`: that the atomic contention costs the milliseconds — not profiled.** He is right that it is not the particle count; which of those blocks dominates is unmeasured.

3. **"even the nearness of a merge doesnt mean that stuff gets merged itno it. its liek the htbox of the megrers is way smaller than the visual"** (16:03)
   `MEASURE:` none possible without a wider struct.
   State: `[READ]` drawn radius follows FLUX (`render.metal:1251`), capture radius is `3·r_s` (`particles.metal:1489-1491`) — unrelated quantities. Fix is architectural, **HIS call, not started**. Design: `docs/SEED_CONTINUUM_DESIGN_2026-08-29.md`.

4. **"we need the outer wall to have some form of. dont have me stuck here situation."**
   State: unchanged this session. `[READ particles.metal:3479-3487]` hard wall, outward radial velocity deleted at `capR`. See §AB.4b.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **bit5 relaxation as the stand-off cause — CLEARED 2026-09-02 15:30:00.** `app_state.h:48` `uiTogRelaxation = false`, and `main.cpp:327` `kept()` only fires under `SS_INERT`. It never ran in any of his sessions. The "pin bit5 in your runs" suggestion is moot, and `ba5265f`'s relaxation-bound capture immunity **cannot fire** for the same reason (`relaxRate` × bit5 = 0, so `relaxRate² >= om2` is never true).
- **The ≤32-sample cell-centroid self-force — FAILED FALSIFICATION 2026-09-02 15:35:00.** It was my own first hypothesis for the freeze and it is real code, but **42 of the 70 frozen prints had cell count ≤2**, where that term is exactly zero, and the body stayed frozen. Dynfric survived both windows; this did not. Recorded because it is the better-looking wrong answer.
- **Reading the eat rate off the comments — 2026-09-02 16:45:00.** `particles.metal:262-264` states `≈716 M☉/sim-time`, `≈2517 M☉/wall-second`, *"≈3.9 minutes"*. All three describe `h/r = 0.746` and are wrong by **55.7×** since `c30c3a8`. True at 0.1: ≈13, ≈45, **≈3.6 hours**. I used 2517 and was off by that factor until I read the derivation instead. A stale NUMBER is worse than a stale name.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-02 19:44:18  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 1ff86d4
  FAIL  3 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M imgui.ini
           M src/render/render.metal
           M src/render/renderer.mm
  WARN  6 commit(s) not pushed

2. board vs HEAD
  FAIL  docs/BOARD_BLACKHOLE.md is 4 code commit(s) behind HEAD (verified at 4fd2b6f)
  WARN  docs/BOARD_BLACKHOLE.md is 189462B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  WARN  docs/BOARD.md has no 'Commit at last verification: `<sha>`' line — add one
  WARN  docs/BOARD.md is 165275B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  FAIL  STALE: SpaceSynth predates src/render/render.metal — run the packaging script, do not test this
  FAIL  STALE: default.metallib predates src/render/render.metal — run the packaging script, do not test this

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

**Disposition of every FAIL, 2026-09-02 19:47:00 — this ran mid-flight while FABLE was committing:**
- **§1 uncommitted ×3** — NOT MINE. `render.metal`/`renderer.mm` were FABLE's in-flight lens work and FABLE committed them itself minutes later (`2a0d804`, `9f61c66`); I deliberately did not touch them (one concern per commit, and they were unverdicted). `imgui.ini` is rewritten live by the **running app** and is reverted at commit time, not before. My own source change was already committed at `66faa37`.
- **§1 6 unpushed** — correct and intended. Commit ≠ push; he has not given a push order.
- **§2 board 4 behind** — FIXED: board re-stamped to `9f61c66`, my rows folded as §AB.10 + §AB.4b orbital row + §AB.6 correction.
- **§3 stale artifact ×2** — expected and correct: the app was RUNNING and owned by him via FABLE, and this window is forbidden to build. **Do not test the bundle against §AC's lens rows until it is rebuilt.**
- **§5 plane sites ×8** — all 8 are in `render.metal`/`postfx.metal`, i.e. FABLE's files, none touched by me. My one edit (`particles.metal` dynfric ρ) carries no plane assumption.

**RE-RUN after the board fold + commit, 2026-09-02 19:50:04 @ `25fdf85`:**
```
1. git
  ok    branch true-physics, HEAD 25fdf85
  ok    working tree clean — committed
  WARN  1 commit(s) not pushed
2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 9f61c66 — 3 docs-only commit(s) since, no source change
3. deployed artifact
  FAIL  STALE: SpaceSynth predates src/render/render.metal
  FAIL  STALE: default.metallib predates src/render/render.metal
```
Both git and board FAILs cleared. **The two §3 stale-artifact FAILs are NOT mine to clear and are left open deliberately:** the bundle predates FABLE's four lens commits, this window is forbidden to build, and rebuilding here would bake FABLE's unverified lens state into a bundle under my name. **Whoever next holds the token must run `bash package_macos.sh` before testing anything against §AC.**

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The ≤32-sample cell-centroid self-force is what freezes the mergers" (my first hypothesis, ~15:35) | Falsified against the same log: 42 of the 70 frozen prints had cell count ≤2, where that term is identically zero, and the body stayed frozen. Replaced by dynfric, which survives both windows. |
| "MDOT ≈ 2517 M☉/wall-second, ~70 stars/seed/frame" (first star-capture pass, ~16:45) | Read off the comment at `particles.metal:263`, which describes `h/r = 0.746`. `c30c3a8` shipped 0.1, so the true figure is **45.25** and ~1.26 stars/seed/frame. Corrected before reporting; the stale comment is now boarded in §AB.10. |
| (relayed, not mine) BRAIN's "refused=0, nothing rejects anything" | True only of the seed↔seed path. The star-capture path was never instrumented at all — FABLE's catch, and §AB.10 is its size. |

---

**Last Updated:** 2026-09-02 19:47:00
**Folded into board:** `docs/BOARD_BLACKHOLE.md` @ 2026-09-02 19:46:41 (stamped `9f61c66`)
