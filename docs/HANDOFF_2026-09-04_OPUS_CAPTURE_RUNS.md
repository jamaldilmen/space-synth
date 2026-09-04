# SPACE SYNTH — handoff 2026-09-04 15:20:11 (OPUS, capture-run window)

> **His verdict on this state:** take 2 — *"isnane but the zoom is jumpy and not one steady
> right u get me .. its liek back and forth zoomies not one consistent ride"* (~12:30, via BRAIN).
> Take 3 — *"this footage will replace the last bh run so delet that cuz its broken"* (~15:09).
> **Cold start:** read `docs/BOARD.md` §AA and `docs/BOARD_BLACKHOLE.md` §AD/§AF — NOT this file.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `85b4aa3`
**Build + launch:** `bash package_macos.sh` — never bare `make`. Capture:
`SS_RENDER_FPS=30 SS_WIDTH=19644 SS_HEIGHT=1680 SS_CAPTURE=<base> SS_CAPTURE_SLICES=7152,5340,7152 SS_CAPTURE_FRAMES=<n> SS_LENS_RENDER=1 SS_CAM_RHO=50 ./SpaceSynth.app/Contents/MacOS/SpaceSynth`
**My tooling (scratchpad, NOT in the repo):** `capture_run.sh` (tree gate + provenance header +
stall watchdog), `capture_analyze.sh`, `capture_stills.sh`, `take_report.py`, `msb_check.py`,
`take4_check.py`. `/private/tmp` is not durable — copy before relying on them again.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | Does frame time hold over 10 min? | UNKNOWN, longest run 300 frames | **YES.** Post-formation deciles settle monotonically; second half **217.06 → 216.21 ms = −0.39%** | `r3_600s.log` | `[MEASURED n=600 blocks]` |
| 2 | 60-second tests are enough | assumed | **NO** — R1 (1800 f) read *"+121%, degrades severely"*; that was the FORMATION TRANSIENT filling the window | `r1_60s.log` vs `r3_600s.log` | `[MEASURED n=2 runs]` |
| 3 | Writer sustains 300 MB/s? | untested | **Not what the run tests.** 216.2 GB / 3,788 s = **57.1 MB/s**, never stressed; at 4.6 fps the writer idles | `r3_600s.log` | `[MEASURED n=1 take]` |
| 4 | `[PROFILE/120f]` apportions cost | assumed usable | **Half of it is.** Compute = own queue, no GPU wait ⇒ trustworthy. Render WAITS on the compute event ⇒ UPPER BOUND. `Total` double-counts ⇒ never a share, `1000/Total` is not fps | `renderer.mm:2048` signal `:2021`, wait `:2059` | `[READ renderer.mm:2059]` |
| 5 | Zoom "back and forth zoomies" | cause unknown | **7-bit quantisation beating the spring.** 128 CC levels ⇒ gap p50 **30.0 output frames** (Q1 median 59.3, max 247.5) against a **15-frame** settle ⇒ **129/133 gaps over settle** | `take1_3min.log` | `[MEASURED n=133 gaps]` |
| 6 | Would removing the 4 post-FX faders fix it? | his theory | **NO.** They never touch `tgtRho`. Take 2 (faders removed) still needed 14-bit to fix the motion | `take1` vs `take2` | `[MEASURED n=2 takes]` |
| 7 | 14-bit zoom | never run | **WORKS.** gap median **0.00** frames, 2/5,693 over settle (take 1: 129/133), density **1.08 updates/frame** vs 0.025 = **43×** | `take2_3min.log` | `[MEASURED n=5693]` |
| 8 | Stale-LSB lurch at MSB crossings | predicted by me | **REAL BUT INVISIBLE** in take 2: 23 lurches, 15.24–16.43 rho, lifetime **max 1.000 ms** vs 250–500 ms frames. **Zero** after BRAIN's receiver-side LSB latch | `take2` vs `take3` logs | `[MEASURED n=23 / n=4952]` |
| 9 | Receiver-side LSB latch | proposed, unbuilt | **SHIPPED AND CONFIRMED AT SCALE** — take 3 full log: **0** stale-LSB lurches across 4,952 zoom applications | `main.cpp:349-367` | `[MEASURED n=4952]` |
| 10 | Sim-pause fps gain (§AA20 "must not be estimated") | UNMEASURED | **≈2.9–3.0× at matched hole=100%** — 15/15/14 fps before the pause, 43/44/44/43/45/45 after, same run, seconds apart | `2026-09-04_0220_venue.log:466` | `[MEASURED n=3 vs n=6]` |
| 11 | Pause during a CAPTURE — safe? | never done | **Cannot stall or disarm the writer.** `if (!simPaused)` skips only compute; `renderer.render()` is OUTSIDE that block (brace depth 0) and the capture blit/append live inside it | `main.cpp:2967` / `:3005`, `renderer.mm:5571`/`:5816` | `[READ main.cpp:3005]` |
| 12 | Pause gain during a capture | assumed ~3× | **≈+15% max.** Compute is only **26.93 of 210.20 ms (13%)** at venue size with the hole up | `r3_600s.prof` | `[MEASURED n=150 windows]` |
| 13 | φ could not land on exactly 90° | 7-bit scaled | **FIXED** — `case 30` is now an exact selector: raw 0 ⇒ φ=0, nonzero ⇒ φ=π/2 exactly. Log reads `1.57080`, one value | `main.cpp` case 30 | `[MEASURED n=1 take + READ]` |
| 14 | APFS delete accounting | "rm returned 0 GB" | **Reclaim is PROGRESSIVE**: 216.2 GB read +0 same-second, **+77.7 GB at 6 s**, full **+216.2 GB at ~70 s**. Poll to STABILITY, never to first movement | measured at 04:31:18 | `[MEASURED n=2 deletes]` |
| 15 | Freshness = cleanliness | conflated | **NO.** Bundle 03:04:04 was **1 s** newer than newest source — passes every staleness test — while carrying two other windows' uncommitted work. Only `git status` sees it | 03:06:49 | `[MEASURED n=1]` |

## 2. 🚨 OPEN — his list, verbatim

1. **"Just optimzie the rendering process"** (~02:5x, via BRAIN)
   `MEASURE:` a controlled pair at matched framing — `SS_LENS_RENDER=0` vs `=1`, then
   `smearShutter → 0` vs not, then both off.
   State: **the driver is SCREEN COVERAGE of the lensed region, not `r_infl` and not seed mass.**
   `[MEASURED]` over take 3's flat second half `r_infl` swings **1118→2029→1446→951→2173**
   (2.3×, non-monotonic) and seed mass grows 2.2× while Render moves **+1.1%**. Over take 1
   and take 2, render **halves as the camera pulls out** (−56.5% / −53.3%) with compute flat —
   the same shape with four post-FX faders on and off, so those four are ruled out as the cause.
   ⚠️ `[HYPOTHESIS]` coverage itself — framing and elapsed time still move together; n=1 each.
   ⛔ Does NOT discriminate lens from smear: both gate on `bhStrength`, which caps ~4 s in.
   **A null on the lens pair alone must NOT be read as "not the render."**

2. **"i want a nother one like this but this time spin it"** → take 4 (chord + tilt + zoom landing together)
   `MEASURE:` 900-frame smoke, then `take4_check.py <log> 600 900`.
   State: 🚩 **PRE-LAUNCH RISK, MEASURED.** θ 0→90° over 4,800 frames uses only **4,096 of
   16,383 counts** ⇒ **32 MSB crossings, one per 150 frames** against a 15-frame settle.
   Take 3's orbit was one per **43** frames `[MEASURED n=244 targets, gap p50 42.0, step p50 2.790°]`
   and read as continuous only because ζ=0.70's tail carries 42 frames — **it will not carry 150.**
   Fix ordered: map the θ pair over **[0, π/2]**, parameterised. Falsifiable: gaps must return
   **~38** frames; **~150 means the fix did not land, and we stop.**
   🚩 A 300-frame smoke is **structurally blind** to this — the chord holds the camera static
   through frame 600. Smoke extended to 900 on that basis.

3. **THE SHOW BUDGET — his three 10-minute parts**
   State: `[MEASURED]` **6.3× realtime** at pull-back framing (63 min/part) but **12.0×** when
   the take opens zoomed in (take 1) and **9.0×** with the post-FX faders off (take 2).
   **216–247 GB per part.** Three parts = 648–741 GB against ~380 GB free ⇒ **they cannot
   coexist**; each must be offloaded before the next. He is getting an external drive.
   ⚠️ A realtime-30fps version of this content would demand **~360 MB/s** — above his old 300
   figure and **UNTESTED**.

4. **THE FIELD LEAVES — his *"until the entire field is gone"***
   State: `[MEASURED n=2 instruments]` `[GRAV] live` 1,997,311 → **551,609** and `[CELLPROBE] N`
   1,999,830 → **547,016** (agree to 0.2%) = **−72% over ten minutes**, while `CORE % in` goes
   2.4 → 26.9. Composition fact; **his eyes, his call** — not characterised here.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **`r_infl` as the render-cost driver — REJECTED 2026-09-04 03:23:00.** Fitted `Render ~ r_infl^0.72`
  (ρ=0.890, n=15) on R1, but the segment test kills it: where r_infl is FLAT, Render still rises
  **+58%**; where r_infl rises, seed mass barely moves. On R3 the exponent collapses to **^0.16**
  over a 640× range — not stable across scales. Two quantities riding one clock.
- **Seed mass as the driver — REJECTED same test, opposite segment.** Each explains only the
  stretch the other cannot.
- **`speed max` as the smear proxy — UNUSABLE 2026-09-04 03:25:00.** Saturates at exactly **1.000
  for 440 of 446 samples**, before the first PROFILE window lands, while Render rose 15.9×. A
  saturated proxy is blind in both directions. The tap count itself is never logged ⇒ the smear
  cannot be accused or cleared without **two** new counters: mean/max TAP COUNT **and** a
  COVERAGE fraction. One without the other cannot separate a deeper smear from a wider one.
- **Sending LSB-before-MSB to shrink the 14-bit intermediate — REJECTED 2026-09-04 13:05:00.**
  My proposal, wrong. At v14 255→256: MSB-first gives (2,127)=383, **+127 counts**; LSB-first
  gives (1,0)=128, **−128 counts**. Symmetric — reordering moves the error, it does not shrink it.
  Only the receiver-side latch removes it, which is what shipped.
- **Cinematic settle (`C`) as the zoom-jumpiness fix — SUPERSEDED, not wrong.** 1.5 s = 45 output
  frames would exceed the 30-frame median gap and keep the spring moving, but 14-bit removed the
  need and cinematic would have changed the camera feel he had already accepted.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-04 15:16:04  —  .

1. git
  ok    branch true-physics, HEAD 85b4aa3
  FAIL  5 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M imgui.ini
           M src/core/camera.h
           M src/main.cpp
          ?? docs/SPACE_SYNTH_LIVE.md
          ?? scratchpad/s6_cc_wip_2026-09-04.patch
  WARN  68 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at e750a73 — 6 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 258746B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 104965B — exempt (not read at cold start)
  ok    docs/BOARD.md current at e750a73 — 6 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 196584B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    62 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:577 · :765 · :1146 · :1466 · :1469 · :2585 · :3329
  ?     src/render/postfx.metal:66
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

🚨 **THE `FAIL` IS NOT MINE TO CLEAR AND I HAVE NOT CLEARED IT.** All five paths belong to other
windows and two were being written *as preflight ran*: `src/main.cpp` mtime **15:13:34** (SONNET's
π/2 mapping rebuild for take 4), `docs/SPACE_SYNTH_LIVE.md` **15:15:19** (created "on his order
2026-09-04 15:12:04" by another window). `imgui.ini` is the app's own auto-save. **This window made
zero source changes all session** — every tool I built lives in `/private/tmp`, outside the repo.
Committing would bundle three concerns and capture SONNET's half-finished build mid-edit, which the
skill's own *one concern per commit* rule forbids. ✅ The tracked-binary trap does **not** apply:
`git ls-files` confirms `SpaceSynth.app/Contents/MacOS/SpaceSynth` is untracked since `0c51e58`.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "Compute is 55–72% of GPU time" | Derived from `Total = C + R`, which **double-counts** — the render buffer waits on the compute event (`renderer.mm:2059`). `space_synth_lens_cost_unmeasured_2026-08-31` had already recorded this instrument as unreliable for apportioning; I did not look it up before leading with it. |
| "At high bhStrength the compute pass owns the whole frame" | True only for a **STALLED** scene (biggest body pinned at 50 M). On a scene that forms, compute is **13%**. Must be stated conditionally or not at all. |
| "The lens costs ~5.7× at venue size" | The comparison run had `Compute avg 0.00` in **350 of 352** windows — `[SIM] PAUSED`, line 466. It was never a lens-off control. |
| "89% of the field died" | That was `[PROBE-1000]`, a **tracer** of the first 1000 buffer ids — the heaviest stars, which the seed eats first. Field instruments read **−6.3% / −6.5%**. `BOARD_BLACKHOLE.md:27` §AC.5(a) already said *"a tracer null is not a field null"*. |
| "LSB-first sending shrinks the intermediate to 0.119 rho" | Symmetric error, ±127 counts either way. BRAIN caught it before SONNET built it. |
| "Outlier at frame 4021, held 1082 ms" | False positive from my own >1 rho threshold. `cc=20 raw=70` throughout — the MSB never moved; it was a monotone 17-count advance as p² steepens. |
| "43 stale-LSB lurches in take 3" | Same threshold fault. Magnitudes 1.0–4.5 rho, not the ~15.1 a stale byte gives. They are the **ride's** frame-rate extrapolation correcting backwards when a marker lands. Retuned to >10 rho: take 3 has **0**. |
| Holding take 3's launch on coarse θ targets | Targets are coarse (2.81°, 7-bit) — but the camera **never stops**: longest frozen stretch **0.0 frames**, **0 of 64** intervals below 10% of mean speed. Defect real, impact absent. The hold cost him 16 minutes and he saw a 10-second smoke clip believing his take had failed. |
| "ETA 14:36" for take 3 | Projected a whole take from a rate sampled in the first 60 s. Actual ~14:54. |

---

**Last Updated:** 2026-09-04 15:20:11
**Folded into board:** NOT YET — `docs/BOARD.md` and `docs/SPACE_SYNTH_LIVE.md` are being written
by another window this minute (15:15:19). Rows 1–15 and §2/§3 above are offered to BRAIN to fold;
folding them from here would repeat the independent-double-fold recorded at 2026-09-04 02:38:15.
