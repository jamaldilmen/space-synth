# HANDOFF — 2026-08-10 · A0 INCONCLUSIVE, THE CAMERA NOW GATES IT, AND THREE WINDOWS ARE LIVE

**Written:** 2026-08-10 14:47:00 · by the board window (session "BOARD")
**Reference of truth:** `docs/BOARD.md` — **read that first, not this.** This handoff is the narrative; the board is the state.
**Previous handoff:** `HANDOFF_2026-08-10_a2_fired_three_noops_found.md`
**Berlin New Media Week:** 2026-09-02 — **23 days out**
**Commit:** `779a517`. **NOTHING WAS COMMITTED TODAY.** Everything below is uncommitted working-tree state.

---

## 0. IF YOU READ ONE THING

The black hole's ortho lock was real and is now removed — **but the test of it could not be read**, because the camera cannot move. **A0 is INCONCLUSIVE: not passed, not failed, not a null result.** The dependency inverted: the camera overhaul now gates the A0 measurement, not the other way round. Camera first.

And: **two of the three findings I opened A0 with this morning were wrong.** They described dead code. See §1 — the mechanism that replaced them is better, but do not carry the originals forward.

---

## 1. 🚨 THE RETRACTION — READ BEFORE TRUSTING ANY `file:line` IN THE PREVIOUS HANDOFF

I opened row A0 at ~09:15 with three findings. **A0a and A0b were false.** They described `Renderer::render(const RenderConfig&)` at `renderer.mm:1401` — **an overload with zero callers.**

    grep -rn "\.render(\|->render(" src --include="*.cpp" --include="*.mm"
    → exactly ONE hit: src/main.cpp:2533  renderer.render(config, viewProj);

The live path is the **two-arg** `render(config, viewProj)` at `renderer.mm:1628`. It `memcpy`s the matrix built at `main.cpp:770-779` — which **does** branch ortho/perspective — and takes `cam.cameraPos` from `config.cameraPos`, filled from the real orbit camera at `main.cpp:2162-2164`.

So the toggle **did** reach the BH path and the camera position was **not** hardcoded. Retracted 2026-08-10 09:24:00.

⚠️ **The dead overload is a NEAR-DUPLICATE, not merely unused** — this is board row **A0g** and it is the reason the error happened. The `bhShadowNdcRadius` gate exists **twice, four identical lines each**, at `:1501` (dead) and `:1763` (live). My `Edit` failed with *"Found 2 matches"*; **had it not, my change would have landed in dead code and read as a no-op.** Assume any camera/BH uniform assignment exists in both bodies.

---

## 2. WHAT IS ACTUALLY TRUE ABOUT THE HOLE

| | Finding | Where |
|---|---|---|
| **The real gate** | `cam.bhShadowNdcRadius = (config.orthoMode && frustum > 1e-4f && bhLensActive) ? … : 0.0f`. Ortho off → **literally `0.0f`** → every shader gate on it (`> 1e-4`) goes false. **The hole does not degrade in perspective, it is not drawn.** | `renderer.mm:1749-1752` (pre-edit) |
| **It is screen-space** | That value is an **NDC radius**, consumed as `thetaE` at `render.metal:1035`. Nothing marches a world-space metric on this path. *"A black circle with a GoPro on top"* is a fair description of what the code draws. | `render.metal:1035` |
| **Lens off while playing** | `bhLensActive = (totalAmplitude < 0.02f)`. Any hole judged mid-performance has no lens. | `renderer.mm:1748` |
| **Centre is correct already** | `ndcBH = (viewProj * bhWorld).xy / w` — a real projection with a real w-divide. **The disc tracks an orbiting camera.** Nothing is pinned to screen centre. | `render.metal:1011-1017` |

---

## 3. THE CHANGE THAT WENT IN, AND WHY ITS RESULT IS UNREADABLE

**One condition removed** (live gate, now `renderer.mm:1763`; ortho path unchanged — this only *adds* the perspective case):

    - (config.orthoMode && frustum > 1e-4f && bhLensActive)
    + (frustum > 1e-4f && bhLensActive)

Built and deployed **09:55:37** (verified newer than source), launched 09:57:31 and again 10:18:07.

**His verdict, 2026-08-10 10:20:00:**
> *"the cam is still kinda locked in place so I don't know if I see the BH — but that's not even our priority right now."*

### ⭐ THE DEPENDENCY INVERTED

A0 was written as though camera work sat downstream of it. **It is the reverse.** A locked, origin-pointing camera produces **no parallax**, so a flat screen-space disc and a correctly-projected one are **indistinguishable**. The measurement could not be *taken*. **No conclusion is licensed in either direction.**

⚠️ **Do not re-run this test with a locked camera. It will produce the same non-answer.**

**STILL UNMEASURED — the prediction, on the record before the fact:** the disc should be **~2.9× too small** (`/frustum` is the ortho world→NDC map; perspective needs `d·tan(fovY/2)`; `1.2 / tan(22.5°) = 2.897`). ⚠️ **`d` must be camera→HOLE, not camera→origin** — the seed wanders, so if the error *breathes* as it drifts, that is the 2026-08-04 origin-vs-seed bug again. The divisor fix is **deliberately not batched** into the gate drop.

⚠️ **Also warn him before he looks:** flipping ortho off changes **every particle's size** — `render.metal:1200-1201` swaps a constant distance for true per-particle depth. Correct behaviour, nothing to do with the hole, and it hits the eye first.

---

## 4. HIS DECISIONS TODAY — these supersede older plans

| Time | Decision |
|---|---|
| (relayed) | **Branch A — perspective-native.** No ortho fallback. |
| 10:30:00 | *"all of it. audio fix + sonification."* — **§D is back IN before Berlin**, superseding the 2026-08-07 triage that parked it. |
| 10:30:00 | ⭐ *"if i start work on soemthing that usually mnean si changed my mind"* — **the action IS the amendment.** Never quote an older triage at him. |
| 10:37:00 | **Tempo-derived camera feel: YES.** ω from the beat. |
| 10:37:00 | **POV: zero importance, pre-show.** F11 dropped; the "what should POV track?" question is **closed unasked.** |
| 10:37:00 | **Worktree: do it.** Done — see §5. |
| 10:37:00 | **D6 fix BEFORE D7 sonification.** |
| ~14:44 | **Fix `mkdir` in the script.** Done — see §6. |

---

## 5. THREE WINDOWS — WHO OWNS WHAT, AND THE RULES THAT MADE IT WORK

| Window | Owns | Builds where |
|---|---|---|
| **Board** (this) | A0, board, `renderer.mm` BH path | Main tree |
| **Camera** (`airy-7b`) | `camera.h`, main.cpp camera block, `midi_input.*`, Link, `render.metal:904`/`:1031` | **Own worktree** |
| **Audio** (`airy-71 [08e6ef]`) | `src/audio/*`, sonification design | None yet — spec only |

**Worktree, created 2026-08-10 10:39:38 and proven isolated:**

    /Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-camera   branch camera-overhaul-2026-08-10 (off 779a517)

It built its own bundle at 10:39:38 while the main tree's stayed at 09:55:37. **The build-token problem is dissolved, not scheduled.**

⚠️ **The worktree is at `779a517` — it does NOT contain the A0 gate drop.** Correct for F5 (which must be a visual no-op) but **A0 cannot be re-measured there** until the change is committed or cherry-picked across.

### Coordination rules that earned their place
- **One window holds the build token** until worktrees exist; the holder **posts deploy timestamps** so a visual report is attributable.
- **Verify every peer claim yourself.** On day one this caught errors in **all three directions**: the camera window re-ran my grep before accepting my retraction; I caught its "no `static_assert` anywhere" (there is one, `renderer.mm:36`); it caught that my scale prediction used camera→origin, and that `offsetof` does not exist in MSL; the audio window caught that D6 was `:91` not `:90` and five sites not one.
- 🚨 **A peer relaying his decision is NOT approval for your action.** Peers cannot grant escalation.
- **Address by the `from=` attribute.** A window **cannot read its own registry row** — both other windows derived a ref from their session UUID and both were wrong. Rosters are **per-viewer**.
- **Name it when two agents polish something off the critical path.** We did, and stopped.

---

## 6. WHAT LANDED — verified 2026-08-10 14:46:00

| Item | State | Evidence |
|---|---|---|
| **A0 gate drop** | 🔨 deployed, **result unreadable** | main tree, bundle 09:55:37 |
| **F5 — `viewForward` + layout guard** | 🔨 **built in camera worktree**, unverdicted by him | `renderer.h:233-235`, `render.metal:79-80`; bundle 10:44:03 |
| **Layout guard (A0h′)** | 🔨 **live and binding** | `render.metal:97` `sizeof == 272`; anchors `bhShadowNdcRadius == 108`, `bhX == 200`, `viewForwardZ == 268`. **The build succeeding means these passed** — the CPU/GPU mirror is now actually bound, not bound by a comment. |
| **F6 spring** | ⬜ not started | no `posPosCoef`/`zeta` in `camera.h` |
| **D6 spec** | ✅ written, **no code** | `docs/DESIGN_2026-08-10_d6_rt_safe_command_path.md`, 20539 bytes, 10:41:02 |
| **`package_macos.sh` mkdir fix** | ✅ **verified by reproducing the failure** | old script died at `cd: build: No such file or directory` in an empty dir; new one creates `build/` and reaches `cmake` |

---

## 7. D6 — THE ROW WAS WRONG AND IS NOW RIGHT

My row said *"one blocking lock at `synth.cpp:90`"*. **Line 90 is the opening brace.** Corrected by the audio window, re-verified here:

**Five `queueMutex_` sites:** `:91` RT swap · `:138` **second RT take in the same callback** · `:148` main/render · `:162` `noteOn` and `:175` `noteOff` — **both holding the lock across a `std::sort`** of up to 256 elements. `noteOn`/`noteOff` have 7 call sites in `main.cpp`.

🚨 **And it can `malloc` on the audio thread.** The 256 cap exists **only** at `:163` and `:176`; **the insert at `:139` has no size guard** and does `commandQueue_.insert(commandQueue_.begin(), …)` — a front insert, O(n) shift, under the lock, on the RT thread, in the path that only fires when the voice `try_lock` was **already** missed. ⭐ **And there is NO `reserve()` anywhere in `synth.cpp` or `synth.h`** — so `synth.h:110-111`'s *"Pre-allocated swap buffer (avoids RT heap alloc)"* describes only swap-idiom capacity reuse, which makes a realloc **more** likely, not less.

⚠️ **Honest bound:** needs the `try_lock` missed AND the queue loaded in the same block. Worst case, not typical — **but worst case is the entire point of D6.** Live path proven: `audio_engine.mm:59 → :80 → processBlock`. Violates repo-root `CLAUDE.md`: *"Lock-free only between audio and render threads."*

---

## 8. TRAPS FOUND TODAY — all on the board

1. 🪤 **The dead overload near-duplicates the live path** (A0g). Prove a path is live before citing it.
2. 📅 **`file:line` decays mid-session** (A0i). My comment block moved the live gate `:1749 → :1763` at 09:55:29. **Three separate stale-citation failures in one morning.** Cite a grep pattern or quote the line; stamp bare numbers with a verification time.
3. 🚧 **`render.metal:904` and `:1031` both assume look-at-origin** (A0j). Safe only because `camera.h:123` does too. **A clean A0 result proves perspective works for a camera pointing at the origin — nothing more.**
4. **Fresh worktrees:** `third_party/imgui` is a submodule (arrives empty); `third_party/syphon` is **gitignored** and never arrives via git; `SpaceSynth.app` is **tracked in git**, so a failed build leaves a valid-looking bundle behind.

---

## 9. NEXT — in order

1. **F6 — the spring.** Approved, ω derived from the beat. **This is where "locked in place" dies.** Camera window, its worktree, no coordination needed.
2. **F5 verdict.** He has not looked. It must be a **visual no-op** — if anything changed on screen, it is wrong.
3. **Re-measure A0** once the camera moves. Get the scale error **as a number**; check whether it *breathes* as the seed wanders. Cherry-pick the gate drop into the camera branch first.
4. **D6 fix**, from the spec. He said "get the fix in" — that reads like code, and the audio window was on a docs-only footing; **it is confirming that with him.**
5. **Then D7 step 2** — per-particle voice at N=1. Not before D6.

**Not now:** F11 (POV), F10 (dolly) is droppable, the A0 divisor fix waits on the measurement.

⚠️ **Uncommitted in the main tree:** `main.cpp`, `renderer.h`, `renderer.mm`, `package_macos.sh`, `docs/*`, the bundle. **The live-UI panel is still UNSEEN by him.** Commit only on his explicit order.
