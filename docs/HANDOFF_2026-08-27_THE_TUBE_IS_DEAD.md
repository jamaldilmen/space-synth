# SPACE SYNTH — handoff 2026-08-27 17:14:30

> **His verdict on this state:** *"so yeah tube is gone relaunch pls"* (~14:13) · *"the shapes themselves are isanen now. great the tube is gone."* (15:25) · *"keys fix good"* (13:52)
> **Cold start:** read `docs/BOARD.md` — NOT this file, NOT older handoffs. This session is **§T1–T8** at the top of it.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-RESONATOR` branch `tube-resonator-2026-08-26` @ `5f9e0f0`
⚠️ **THE WORK IS UNCOMMITTED ON TOP OF THAT SHA.** `M src/render/particles.metal` (the tube kill) and `M src/ui/window.mm` (SS_SCREEN selector) are two SEPARATE changes — commit them separately, and **only on his order.**
**Second tree:** `SPACE-SYNTH-BH` branch `bh-gargantua-2026-08-26` @ `3dc3be2` — clean, keys fix committed, not pushed.
**Build + launch:** `bash package_macos.sh` then `open -n SpaceSynth.app --env SS_FULLSCREEN=1` (add `--env SS_SCREEN=1` for a second display, `--env SS_CAM_RHO=150` to match the BH baseline)

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| T1 | Play squeezed matter into a CAN | cylinder r≤6, \|z\|≤6 vs sphere r=100 — two SHAPES, not two radii | one domain, the sphere | `particles.metal:3323` (`:3325`/`:3354` deleted) | `[HIS WORDS 2026-08-27 ~14:13]` |
| T5 | A tap leaked spin into the body | tap put ~1.6 rad/s on the body → drag integrated **~37° of real rotation after key-up**; camera snapped, BODY turned under it | tap and hold share one `kTapHoldSec`; tap contributes zero spin; **ramp unchanged** | `main.cpp:783-800` | `[HIS WORDS 2026-08-27 13:52]` |
| T3 | "Grid resolution wrong" — his bug of weeks | comment claims `cellSize 0.047` (assumes halfExtent 3); live halfExtent **64** ⇒ **1.000, 21× coarser**. And `kAmrFineExtent 4.0` **never covered the r=6 cavity** | LOCATED + costed, **not fixed** — he rejected the cheap fix | `renderer.mm:2089`, `:132`, `particles.metal:2166` | `[READ renderer.mm:2089]` |
| T4 | "None of my faders apply to the chladni particles" | colour was unified 2026-08-02; **luminance and size never were** | CAUSE FOUND, cleanup **deferred by him** | `render.metal:1925`, `:2340-2342` | `[READ render.metal:1925]` |
| T6 | "Why don't they turn into a unibody photon ring" | **nothing is trying to** — no near-hole regime, no motion blur, lens is a plate | ANSWERED, not fixed | `particles.metal:3196`, `main.cpp:2401`, `render.metal:1085` | `[READ particles.metal:3196]` |

## 2. 🚨 OPEN — his list, verbatim

1. **"the entire thing needs to be ont he fine gird"** (2026-08-27, rejecting ±4→±8)
   `MEASURE:` the fine box cannot be sized until §T2 settles — fine `cellSize = 2·extent/128`, so **±64 = 1.000 = the coarse grid, zero gain**, and ±100 is *worse*. `[MEASURED]`
   State: `[MEASURED n=16]` the field never converges, so there is no extent to cover — **this row is blocked by T2, not by arithmetic.**

2. **"the shapes are way bigter than theh used to"** → the inflation itself
   `MEASURE:` hold one note, log `meanR` every 240 frames. Settled = two consecutive samples within 5%.
   State: `[MEASURED n=16]` meanR 12.0 → 71.4 over 64 s, monotonic, `maxR` pinned at the 100 cap by 44 s. MECHANISM `[READ particles.metal:2482]`: mode force self-gates to `rho<6`, sculpt is purely tangential (θ̂/φ̂, **no r̂**), no boundary force exists ⇒ **outside r=6 the only radial force is self-gravity, and it is too weak.**
   ⭐ **The fix he already approved is the j_l/Y_lm core** — *"i approve the core"* (2026-08-27). It is `src/core/sph_special.h`, UNTRACKED, validated 5.337e-06 worst / 0 non-finite / 1,990,185 samples, and **included by nothing.** It exists to put the modes in the whole sphere instead of only inside the dead can.

3. **"The hole doesn't stay. It just vanishes instantly"** + **"no the bh doesnt shrink through play it goes straight to the shapes lol"**
   `MEASURE:` log the seed mass AND the drawn `horizonR` on the same frames through a form→play cycle; if they diverge, they are not the same quantity.
   State: `[HYPOTHESIS]` — three candidates, none tested. **Does not close.**

4. **The ramp: *"waaaaaaaaaaaaaay longer"*, anchored to a physical reference not taste**
   `MEASURE:` `[MEASURED]` `kSpinMax = 436.80 rad/s = 69.519 rev/s`, reached in ~3.7 s via `accel = 8 + spinHold²·25` (`main.cpp:785`). `2.08e-5 rad/s` (c at M87*'s photon sphere) is REAL; the `2.1e7` time-lapse is the ONLY taste number. Hole's own rate: **1.000 rev/s at ISCO** = 4.1774 s physical = 4.18× real, wall-clock locked (`renderer.mm:263-273`). Arrow-hold cap is **69.5× the hole's own rotation.**
   State: proposal on the table — the ramp as *falling inward through the disk*, each moment matching the real Keplerian rate at a radius. Not built, not approved.

5. **Cleanup — DEFERRED BY HIM: *"okay f the cleanup for now"***
   State: fully scoped. Trail brightness = 8 sites; Wave Depth = **three unrelated dead things sharing one name** (slider→GPU never read · orphan `CameraUniforms.waveDepth` never assigned AND never read · dead `ParticleSystem` CPU path with a zero-caller getter).
   🚨 `MEASURE:` **`PhysicsUniforms` has ZERO `static_assert` on either side** (`particles.metal` 0; `renderer.h` guards PostFX 5 + Camera 5, PhysicsUniforms none). Removing `maxWaveDepth` at offset 16 shifts ~38 fields by 4 bytes **and still compiles and runs.** Add the asserts as their OWN change first, or leave a named pad. CameraUniforms is guarded by 10 asserts and cannot fail silently. `[MEASURED n=1 grep]`

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Fine box ±4 → ±8 — REJECTED 2026-08-27 by him.** Free and 8× better in the cavity, but he wants the whole shape covered, not a bigger box: *"well the dont widen the box."*
- **Shrink `halfExtent` — PROVABLY WRONG, measured not asserted.** `maxR` already pins at 100 against a 64 box, so shrinking clamps strictly more matter into boundary cells.
- **`kGridSize` 128→256 — costed, not chosen.** +1.26 GB, 335M→**2.7 B** Poisson invocations/frame, and `hSph = cellSize` so **CFL `uMax ∝ h²` drops 4×** — a physics regression. Buys only 1.0→0.5. Becomes the *requirement* only if the shape genuinely exceeds ±64.
- **B-4 beaming (all three forms) — do not schedule as an independent win.** Attempt 1 (raw g³) washed blue-white; attempt 2 (÷⟨g³⟩) = *"its just black mush over half the screen"*; the untried transverse form inherits attempt 1's saturation, worse. Root cause is §T6b, not the law.
- **"We cap the spin BELOW ring closure and fake the gap" — WRONG FRAMING, do not reuse.** The cap is 57.9% of closure at 120 fps but 115.9% at 60 and 371.8% at 18.7. **Undersampling is the defect, not the cap.**

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-08-27 17:13:0x  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-RESONATOR

1. git
  ok    branch tube-resonator-2026-08-26, HEAD 5f9e0f0
  WARN  7 uncommitted path(s)
  WARN  no upstream set for tube-resonator-2026-08-26

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at fb01f80 — 2 docs-only commit(s) since, no source change
  ok    docs/BOARD_BLACKHOLE.md size 88568B
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 5f9e0f0
  ok    docs/BOARD.md size 117081B

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    33 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:565 / :752 / :1366 / :1665 / :1668 / :2759
  ?     src/render/postfx.metal:66
  WARN  7 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: no failures.
```
🚨 **COMMIT-TIME TRAP — READ BEFORE COMMITTING EITHER CHANGE.** `SpaceSynth.app/Contents/MacOS/SpaceSynth` **is TRACKED in git** (`default.metallib` is NOT — `.gitignore:6` `*.metallib`), so every `package_macos.sh` dirties a 1.4 MB tracked artifact. **That one binary was built from BOTH uncommitted source changes.** Commit `particles.metal` + the binary and you silently ship `window.mm`'s SS_SCREEN change *inside the executable* while its source stays uncommitted — the two concerns get welded together in exactly the way separate commits exist to prevent, and the diff cannot show it (`Bin 1388040 -> 1388040 bytes`).
**Do this instead:** `git restore SpaceSynth.app/Contents/MacOS/SpaceSynth` and commit **sources only**, then rebuild — same treatment as `imgui.ini`. `[MEASURED: git ls-files --error-unmatch, 2026-08-27 17:21:00]`
*(The keys-fix commit `3dc3be2` in `SPACE-SYNTH-BH` is NOT affected — that tree held only the one change, so its binary matches its source.)*

⚠️ Working tree at handoff (verified, `git log 5f9e0f0..HEAD` = **0 commits**): `M` binary · `M docs/BOARD.md` · `M imgui.ini` · `M src/render/particles.metal` · `M src/ui/window.mm` · `??` this file · `?? scratchpad/` (keep — `sph_sweep.cpp` is the harness that reproduces the 5.337e-06 gate with no build) · `?? src/core/sph_special.h` (the approved core, still included by nothing).

⚠️ The uncommitted paths are expected: the two source changes above, `imgui.ini` (the running app rewrites it live — **revert at commit time, not before**), the rebuilt bundle, `docs/BOARD.md`, this file, and `scratchpad/`.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "#2 and the j_l core are one change — deleting the wall orphans `kRho`/`kZ`" | `particles.metal:2516` hard-gates the mode force independently of the clamp. Pattern inside r<6 is bit-identical after the delete. Conceptual debt, not a runtime break. I reasoned from a constant instead of checking the gate. |
| "We cap the spin below ring closure at 58% and fake the difference" | Built on `main.cpp:800`'s *"Smooth at 120fps"* **comment**, not a measurement. The figure is panel-dependent: 57.9% at 120 fps, **115.9% at 60**, 371.8% at 18.7. |
| "The display is 60.00 Hz, 120 fps is not achievable on this machine" (BH window) | It read a ProMotion panel **while he had 60 Hz mode on**, then he switched it. `CGDisplayModeGetRefreshRate` told the truth **both times** — the environment changed between readings. **Lesson is re-read the environment, NOT distrust the instrument.** |
| "A held note revives corpses at spawn mass and withdraws it from the hole, so sustain shrinks the hole" | `[HIS WORDS]` *"no the bh doesnt shrink through play it goes straight to the shapes lol"* and *"The hole doesn't stay. It just vanishes instantly."* His eyes beat a ledger read. Now open row §2.3. |
| "There are no star knobs in `app_state.h`" (standing memory since 2026-07-28) | **REFUTED.** Nine, wired end to end: `uiStarLumExp/Gain/Ceil`, `uiStarKelvinA/P`, `uiStarSizeGain/Exp/Floor/Ceil` — UI `main.cpp:1712-1750`, uploaded `renderer.mm:1879-1887`. The memory has been corrected. |
| `main.cpp:800` "Smooth at 120fps" logged as a 9th *comment-is-not-a-mechanism* sighting | Withdrawn. The comment is **correct** for the state it describes (held pause runs at 120). Count stays at **8**. |
| "`renderer.mm:2090` sets `halfExtent`" (and `particles.metal:487` for `BESSEL_MILLER_M`) | Off by one both times: the assignment is `:2089`, the constant is `:485`. Neither reached disk. |

---

**Last Updated:** 2026-08-27 17:14:30
**Folded into board:** `docs/BOARD.md` §T1–T8 @ 2026-08-27 17:12:00
