# SPACE SYNTH — handoff 2026-09-04 02:32:33 (FABLE)

> **His verdict on this state:** bloom — *"OKAY IT LOOKS BETTER"* (2026-09-04 ~00:0x). Formation/collapse — *"o why does it collapse so fucking fast its super unnatural"* (~00:2x), *"the best possible starting point is the start of the app and it didnt fire"*, and on the room-view screenshot (02:2x): *"the scale is so off.. the mass in the middle should be so much like closer. right? ... i also played during the last show scale run"*. Smear — not seen yet.
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` §AF (the night's finding) then `docs/BOARD.md` §AA16–AA18 — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `e750a73` (sources) — docs commit follows.
**Build + launch:** `bash package_macos.sh` then room view `open -n SpaceSynth.app --stdout <log> --stderr <log> --env SS_WIDTH=19644 --env SS_HEIGHT=1680 --env SS_FULLSCREEN=1 --env SS_LENS_RENDER=1` · laptop `open -n SpaceSynth.app --env SS_FULLSCREEN=1 --env SS_LENS_RENDER=1`. The lens is env-gated, default OFF.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | Bloom lost its horizontal reach at 19,644 wide | pyramid depth governed by the SHORTER side + 8-slot cap ⇒ 7 levels, coarsest 153×13 (1/153 of the width) | halves while the LONGER side ≥ 8 px, 16 slots ⇒ 11 levels down to 9×1 | `src/render/renderer.mm` resize() bloom block, `kBloomMaxLevels` (`bea0b0d`) | `[MEASURED from the process]` `[BLOOM-PYRAMID] 11 levels from 9822x840 down to 9x1`; cost 18.4→18.5 fps (BRAIN) · `[HIS WORDS]` *"OKAY IT LOOKS BETTER"* |
| 2 | "Collapse compare to older logs" — the August tube-tree baseline | BRAIN's 00:26 table vs `A1_soak` | STRUCK; dated on this tree only | — | `[HIS WORDS 2026-09-04 ~00:3x]` *"why dafuuuq would I use a log from a different build lol"* |
| 3 | Formation at launch on the pinned path | unknown | **pinned 0/9, unpinned 8/8, same binary** | `docs/BOARD_BLACKHOLE.md` §AF.1 | `[MEASURED n=9 + n=8]` logs listed in §AF.1 |
| 4 | What the "unnatural" collapse is | assumed a physics regression | the nucleus falls into ONE hash cell on EVERY launch (18k→300k@15s→590k@40s); an early seed arrests it at ~30%, otherwise 1.85M stars in one cell, r50 0.078 | §AF.2, `[CELLPROBE] maxCell`, `[CORE]` | `[MEASURED n=13]` |
| 5 | Why formation never comes once piled | — | `merge_stars` scans 32 stars per cell ⇒ ~1 merge/s across 2M | `src/render/particles.metal` `count = min(cellCounts[cid], 32u)` | `[READ]` + `[MEASURED]` live −1/s |

## 2. 🚨 OPEN — his list, verbatim

1. **"o why does it collapse so fucking fast its super unnatural compare logs to older ones its bs. hand this to fable"** (~00:2x) and **"the scale is so off.. the mass in the middle should be so much like closer"** (02:2x, room view).
   `MEASURE:` the pile is measured (§AF.2). What decides the look is whether a seed registers before ~40 s. Mechanism linking the PIN to the missing first merge: UNFOUND by reading — needs a star-star merge counter at `merge_stars` (none exists), then pinned vs unpinned once each.
   State: `[MEASURED]` six hypotheses killed (§AF.3: steps/frame+per-frame RNG via `SS_MAX_STEPS=1`, fullscreen, width/aspect, spawn seed ×3, return pull, fps). `[READ]` kernels/uniforms/hash/toggles identical on both paths; no compute kernel reads the camera. `[HYPOTHESIS]` the pin code path (`pinRenderSize`→`resize` ×2, `setSizeReferenceHeight`, `pinnedFinal` passes, `window.pinDrawableSize`). **Show consequence: S8 renders pinned ⇒ the offline render cannot form the hole at launch on this code.** Three roads in §AF.5 — his call.
2. **"bloom and smear first"** (23:5x) — bloom done; smear `e750a73` written, compiled standalone, in the 02:31:16 bundle, **UNVERDICTED**.
   `MEASURE:` room view, hole up, a fast inner-orbit star: continuous band vs dots. Watch the fps line under play at hole 100% (256-tap bound, coverage-paid).
   State: 🚩 `renderer.mm` `post.pixelStretch = min(1, max(spin, bhStrength))` — spin fader cannot turn the smear off while the hole is up; his routing, flagged not changed. 📋 vignette/CA/kaleido/twirl are raw-UV radial ⇒ ellipses at 11.69:1, all default 0.
3. **"three parts each 10 mins…"** (~00:1x) — ruling recorded (BOARD.md §AA18). Nothing redesigned unasked.
4. **"how high our fps goes when we pause the sim mid render after a supernova"** — BRAIN's protocol: SPACE brackets the fps lines (`[SIM] PAUSED/RESUMED`). Not run tonight.
5. S6 (CC→parameter) and S7 (one slew law) — unchanged, behind his parameter list.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **August tube-tree logs as a collapse baseline — REJECTED 2026-09-04 ~00:3x (his words).** Different build. Same-tree evidence only.
- **Steps-per-frame / per-frame-seeded kicks as the pinned-path mechanism — REJECTED 2026-09-04 02:15:13.** `SS_MAX_STEPS=1` pinned: 240/240 one-step frames at 24–29 fps, no seed in 255 s.
- **Fullscreen as the variable — REJECTED 02:2x.** Unpinned windowed formed at 8 s.
- **19,644 width / 11.69:1 aspect — REJECTED 02:17.** Pinned 3024×800 formed nothing.
- **Spawn realization — REJECTED 01:43.** Seeds 42/7/1234 all fail pinned; same-seed pinned pairs match to a few % at every sample.
- **Return pull as the collapser — inert.** `pull=0.00` on every silent sample; armed only after the first note.
- **Counting `% in` lines as seconds — WRONG.** Each status line is written twice; count `^\[DEBUG\] FPS` only.
- **Not a lottery.** Two same-seed pinned runs reproduce; the outcome is a property of the path.

## 4. 🔬 PREFLIGHT

```
(pre-commit run 2026-09-04 02:32:33 — the two FAILs are the boards this commit carries)
1. git
  ok    branch true-physics, HEAD e750a73
  FAIL  2 uncommitted path(s) — COMMIT THEM.   M docs/BOARD.md   M docs/BOARD_BLACKHOLE.md
  WARN  62 commit(s) not pushed
2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at e750a73   (WARN 258746B — split)
  ok    docs/BOARD.md current at e750a73             (WARN 193466B — split)
3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source
4. referenced paths (live docs only)
  ok    61 referenced path(s) in live docs all resolve
5. orbital-plane convention
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE
```
Post-commit re-run: see the footer.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The infall rate is unchanged since August; only the ceiling changed" (00:3x, to him) | Built on the tube-tree log. Struck on his words. |
| Sample indices "s~N" in my first timelines (00:4x–01:2x) | Counted both copies of each status line; up to 2× inflated. Relative comparisons held. |
| "Frame rate is not the discriminator" as a closed statement | Still true as measured (laptop run at 12 fps formed), but the steps-per-frame variant needed its own run to kill. |
| "The pin changes physics" as a finding | It is by elimination, not by mechanism. Tagged `[HYPOTHESIS]` on the board. |

---

**Last Updated:** 2026-09-04 02:32:33
**Folded into board:** `docs/BOARD_BLACKHOLE.md` §AF + `docs/BOARD.md` §AA16–AA18 @ 2026-09-04 02:32:33

**Post-commit preflight 2026-09-04 02:33:04 @ 99defb7:** PREFLIGHT: no failures.
