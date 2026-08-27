# BOARD — THE REFERENCE OF TRUTH

🎯 **COLD START = `docs/TODO.md`** (⚠️ **70.5 KB, ~18k tokens — re-measured 2026-08-26. The “12 KB, ~3k tokens” this line carried was stale by ~5×** and understated what a cold start actually costs) — the whole open list in four buckets, every `file:line` re-read against the code 2026-08-20 14:08:59. **Open this file only for the detail of a row you are actually working.**

**This is a LIVE document, not a handoff.** Handoffs are dated snapshots of a session.
This file is the single running list of what is open, what is done, and what each thing costs.
Update it in place. Never fork it into a second board.

🗂️ **THIS BOARD HOLDS OPEN ROWS ONLY.** Closed and superseded rows moved verbatim to **`docs/BOARD_CLOSED.md`** on 2026-08-18 21:07:00 (P4 of `PROCESS_2026-08-17_workflow_audit.md`, approved by him 2026-08-18). Nothing was deleted or reworded — the split was verified line-for-line. The index of what moved is at the bottom of this file.
🕳️ **ALL BLACK-HOLE WORK LIVES IN `docs/BOARD_BLACKHOLE.md`** (his order 2026-08-14 01:41:51). ✅ **EXECUTED 2026-08-19 00:14:12 on his order *"move bh stuff to bh board"*:** §A0, the accretion/horizon rows out of §A (A1, A1‴, A2, A3①, A3②, A3②-white, A3③, A5, A6, A8, MERGER-FACE), B1, B9 and §C12 Doppler all moved there verbatim as **§N**. ⚠️ **Three judgement calls left HERE, not moved — say if you want them over too:** **§A9** (dense matter can only add light — field/gas render, not hole-specific), **C7/C7b** (✅ closed Doppler-colour rows), **C9** (`bit18` flux-conserving arc).

**Last verified against the code:** 2026-08-13 13:29:29 (bundle carries A1″ fit test + both trilinear ∇Φ reads + [PERF] + the DEAD-COMPUTE skip + the `SS_NO_DEADSKIP` A/B gate; merge-gate counters still LIVE — strip before shipping)
**Commit at last verification:** `5f9e0f0` ⭐ **RE-STAMPED 2026-08-27 17:12:00 — ⚠️ THE SHA IS NOT THE WHOLE TRUTH, the live source is UNCOMMITTED ON TOP OF IT.** Tree `SPACE-SYNTH-RESONATOR` @ branch `tube-resonator-2026-08-26`, HEAD `5f9e0f0`, with **`M src/render/particles.metal` (the tube kill, §T1) and `M src/ui/window.mm` (the SS_SCREEN selector) NOT COMMITTED** — he has not ordered it. The §T rows were read against that WORKING TREE, not against a sha, and `render.metal`/`renderer.mm` were confirmed byte-identical to `SPACE-SYNTH-BH` so the §T reads hold in both trees. The keys fix (§T5) IS committed, but in the OTHER tree: `SPACE-SYNTH-BH` @ `3dc3be2`. — Previously: `fb01f80` (2026-08-26 10:47:39) — ⭐ **re-stamped 2026-08-26 10:48:xx. `fb01f80` is a COMMENTS-AND-DOCS commit:** the only source change is the four corrected `colorAttachments[1]` comments in `renderer.mm`, no behaviour. **G6 and C4b WERE re-read in source today** (the fragment return types, the mask-to-pipeline mapping, the smear consumer); no other row was re-verified at this sha. — ⭐ **re-stamped 2026-08-25 15:17:5x, and the rows did NOT need re-reading: `448ed63` is the commit that COMMITTED the already-verified working tree.** The colour-session source it contains (`spectral_lut.h`, `render.metal`, `renderer.*`, `main.cpp`, `app_state.h`) is byte-identical to what was read at 2026-08-24 22:0x — only the sha moved from uncommitted to committed. *(Previously `0cf85b4`, 2026-08-23 14:40:21; both boards had mis-dated that sha as 08-24, corrected 2026-08-25 14:25:10.)*. ⭐ **Rows re-read in SOURCE at this sha on 2026-08-24:** the whole COLOUR PIPELINE — `unifiedKelvin` (`render.metal:462`), the two colour laws (`blackbodyRGB` `:201` vs `spectrumToBands` `:379`), all three bit16 gates (`:1861` play, `:2078` gas, `:2095` star), the S–S disk override (`:2103`, **proven dormant: `horizonR=0.0000` in the live log**), and the phase-tint site. ⚠️ **Everything else is unchanged and still carries its own older stamp — bumping a sha does not re-verify a row.** Previously stamped `a44de13`.
**Bundle these rows were verified against:** `SPACE-SYNTH-TUBE-killtube/SpaceSynth.app` @ **2026-08-13 13:29:29** — log-verified only, **he has not looked at it.** ⚠️ **That binary no longer exists**: the live killtube bundle is now **2026-08-23 12:15:13** (stat'd 2026-08-23 14:12:09; it replaced the 2026-08-17 17:45:51 build this session), one second newer than the newest file under `src/` (`src/ui/window.mm` 2026-08-23 12:15:12), so it is NOT stale — but the rows below lose their artifact-level proof and carry their claim from the log alone.
**Last correction:** ⭐ **TWO MORE RETRACTED 2026-08-13 — see A1″:** the merge "starves capture through the shared plate word" (never happened, `mrg=0/0/0`) and "the CAS route stalls the hole at 1,772" (real run, but that code path never executed in it — it was a late bootstrap into a diffuse field). **Cause both times: a mechanism inferred from a curve instead of counted at the gate.** Before that: ⭐ **THREE OF MY OWN CLAIMS RETRACTED IN ONE EVENING, 2026-08-12 — see the A1′-endgame row.** "The bound never engages" (it was the binding constraint), "capture delivers ~0.1 M☉/frame" (20–88 stars/frame), "the hole is out of fuel" (916,781 stars sat inside its capture radius, all refused by my own budget). **All three came from reading `feed=` in the log — a ONE-FRAME sample of a buffer that is cleared every frame.** Before that: "SOR is not the monster" was written off 9 samples and is WRONG — with 25 it is ~6 ms and real, 2026-08-11, §H5.
**THE SHOW: COLOGNE opening event, 2026-09-05 — 13 days out** (counted 2026-08-23). ⛔ **NOT Berlin New Media Week / 2026-09-02** — this header carried the Berlin date until 2026-08-23 14:12:09, two days after it moved (his message 2026-08-21). 🎪 **And the venue is a THREE-WALL ROOM — 15 × 4 + 15 × 4 + 10 × 4 m, 160 m², ~270°.** Every "2.5:1" written on this board before 2026-08-23 is the FRONT WALL ONLY. Cold start for the show is **row S00 in `docs/TODO.md`**; the working is `docs/DESIGN_2026-08-23_THREE_WALL_ROOM.md`.

> 🚨 **FOUR BUNDLES EXIST. KNOW WHICH ONE YOU ARE LAUNCHING.** (all re-stat'd 2026-08-23 14:41:39.) ⚠️ **The newest mtime on disk is NO LONGER the live one** — creating the STAGE-BUILD worktree at 14:41:39 wrote a fourth copy that is **byte-identical** to killtube's (md5 `6beb34c7…`, checked both). mtime cannot tell them apart; only the PATH can.
>
> | Tree | Bundle stamp | Contains |
> |---|---|---|
> | ⭐ `SPACE-SYNTH-TUBE-killtube` (worktree, branch `kill-the-tube-2026-08-11`, HEAD `0cf85b4` — corrected 2026-08-25 14:25:10, this row read `a44de13`) | **2026-08-23 12:15:13** | **THE LIVE ONE.** Everything through the 2026-08-23 audio/UI session (RT-thread fixes, DPI-derived UI scale, the 3840×1536 pin). Uncommitted as of 14:12:09: the bundle, `imgui.ini`, `src/main.cpp`, `src/ui/window.h`, `src/ui/window.mm`, 3 boards + the show doc, and 2 new docs (`HANDOFF_2026-08-23_AUDIO_UI_AND_THE_ROOM.md`, `DESIGN_2026-08-23_THREE_WALL_ROOM.md`) |
> | `SPACE-SYNTH-TUBE` (main, HEAD `13ac249`) | **2026-08-11 16:09:41** | live-UI panel, A1′ fix, A0 gate drop, the A4 release-ramp fix — **nothing after 08-11** |
> | `SPACE-SYNTH-TUBE-camera` (worktree, HEAD `779a517`) | **2026-08-10 10:44:03** | commit `779a517` + **F5 only** — **no A0 gate drop, no live-UI panel, no A4 fix** |
> | 🆕 `SPACE-SYNTH-TUBE-STAGE-BUILD` (worktree, branch `stage-build-2026-08-23`, HEAD `0cf85b4`) | **2026-08-23 14:41:39** | **NEW, his order 2026-08-23 14:41:39. Created for the Cologne stage build.** Byte-identical to killtube's bundle — it is a checkout copy, **not a build**. ⛔ **ONE LIVE APP: this tree does NOT buy a second bundle.** Nothing has been built here and nothing should be until the build token moves. |
>
> **Launch, do not rebuild.** Running now: **nothing** (`pgrep -x SpaceSynth` empty, re-checked 2026-08-23 14:12:09).
>
> ✅ **VERIFIED DISCRIMINATOR — `comm=` prints the full path, so it names the TREE:**
>
>     pkill -x SpaceSynth && echo "KILL: matched" || echo "KILL: no match"
>     open -n "<explicit .app path>"
>     sleep 2
>     for p in $(pgrep -x SpaceSynth); do ps -p $p -o pid=,lstart=,comm=; done
>
> Confirmed here at 16:01:47 — one line gives pid, age, **and which tree**. Use this, not a bare `pgrep`.

---

## 🎯🚨 PRIORITY — REALIGNED AGAIN ON HIS ORDER 2026-08-14: **BH LENS, THEN TUBE/SPHERE BEFREIUNG**

> *"HANDOFF BH LENSE THEN TUBE / SPHERE BEFREIUNG"*

**Cold start: `docs/HANDOFF_2026-08-14_create_the_hole_and_spaghettify.md`** (newest, 17:06:03) — supersedes `HANDOFF_2026-08-14_lens_then_tube_sphere_befreiung.md`.
🕳️ **ALL BLACK-HOLE WORK NOW LIVES IN `docs/BOARD_BLACKHOLE.md`** (his order 2026-08-14 01:41:51 — *"create dedicated board for BH… I want my proper bh with the time / space mindfuck look. Nothing below that"*). That file is the reference of truth for the hole: the target decomposed into 5 features (S1 shadow / S2 wrap / S3 photon ring / T1 Doppler beaming / T2 dilation shear), the verified inventory, 10 hard limits, the dead roads, and the track. **Read it before touching anything BH.** This board keeps the tube/sphere and everything else.
**① THE LENS (row 16, which HE parked "later" 8 hours earlier — the newest signal wins, do not quote the park back at him).** ⚠️ **My "it is a screen-space warp" read was of a SUPERSEDED comment (`render.metal:878-892`) — the live path (`:921+`) is an angle-space solve, `β = θ − α(θ)·D`, real α(b) LUT log-divergent at the photon sphere, true per-particle depth D, re-projected through `viewProjection` (`~:993`), with a genuine second image (`:642`).** The bend is physical. **What is screen-derived is the GATE and the SCALE:** the whole lens is gated on `cam.bhShadowNdcRadius > 1e-4f`, computed at `renderer.mm:1642`, and the code's own comment there says that radius is **~2.897× TOO SMALL** and measured from camera→origin instead of camera→HOLE — *"the next change"*, never made. ⭐ **FIRST MOVE IS FREE AND HIS: the NASA top-view panel says far-side light crosses (>180°) so its image arrives LEFT-RIGHT SWAPPED — no image warp can flip parity. Does our secondary image swap?** Then fix the documented divisor. **Do not open by rewriting the lens.**
**② TUBE/SPHERE BEFREIUNG (row 14) — and B7 IS NOW MEASURED, NOT HYPOTHESISED:** `H/R` 0.31–0.84 at silence → **0.0047–0.071 during play**, a 10–30× collapse. `H = sqrt(<z²>)` is WORLD-space, so C1 cannot overturn it and he dropped C1 himself (*"let go of that side on rotation thing"*). The field genuinely IS a sheet during play. ⚠️ It does not yet prove the CLAMP causes it — the cavity is r≤6 AND |z|≤6, roughly isotropic. Clamps re-verified after yesterday's line drift: **`particles.metal:339`** (tube 6.0) / **`:340`** (sphere 100.0, with the lying comment) / **`:3319-3321`** (the breathing `mix`).

---

## 🖥️🚨 STANDING RULE — LAUNCH FULLSCREEN, ALWAYS (his order, 2026-08-10 17:12:00)
> *"WHENEVER U LAUNCH THE APP LAUNCH IT IN FULL SCREEN. IT LOOKS DIFFERENT IN WINDOW V FULL SCREEN I DONT KNWO WHY AND WOULD LIKE TO KNOW"*

    open -n SpaceSynth.app --env SS_FULLSCREEN=1

✅ **Shipped 2026-08-10 17:12:31** — `src/ui/window.mm`, toggled after `makeKeyAndOrderFront` (AppKit ignores `toggleFullScreen:` on an unshown window). Env-gated so his own double-click stays windowed.

⭐ **AND THE "WHY" IS ANSWERED — it is one line of shader contract.** Star size is written to `out.pointSize`, Metal's `[[point_size]]`, which is a size in **DEVICE PIXELS**, and **nothing in `render.metal` normalises it to the drawable** (checked: no `resolution`/`viewportSize` term anywhere in the size path). So a star is the same pixel count at any window size and the *drawable* is what changes — fullscreen on Retina is several times the pixel count of a window, so each star covers a **smaller fraction of the screen**: finer points, denser, sharper field. Windowed, the same stars are fatter relative to the frame. **The physics is identical; only the size unit is resolution-dependent.**

🚨 **MEASUREMENT CONSEQUENCE, and it reaches backwards:** `[KPROBE-SCALE] meanPx` means different things at different window sizes. **Never compare `meanPx` across runs at different resolutions** — which weakens any cross-run pixel-size comparison, including the one in **A7**. A verdict taken in a window is also not a verdict about the show: Berlin is a big screen.

---

## 🔪🚨 THE TUBE IS DEAD — 2026-08-27. And what it uncovered underneath.

> **HIS VERDICT 2026-08-27 ~14:13:** *"so yeah tube is gone relaunch pls"* and *"the shapes themselves are isanen now. great the tube is gone."* `[HIS WORDS]`
> ⚠️ **UNCOMMITTED.** The change is `M src/render/particles.metal` in `SPACE-SYNTH-RESONATOR` @ `tube-resonator-2026-08-26`. He has not ordered a commit. `M src/ui/window.mm` (the SS_SCREEN selector) is a SECOND, unrelated uncommitted change in the same tree — commit them separately.

**T1. THE REGIME SPLIT IS DELETED.** `particles.metal:3323` `playCap` gated a CYLINDER (r≤6, |z|≤6, `:3325` radial + `:3354` axial) against a SPHERE (r=100, `:3365`). Not one clamp at two radii — two different SHAPES. Play now uses the sphere. `[READ particles.metal:3323]` `[HIS WORDS]`
  ⭐ **It stood alone, against my own earlier claim.** I wrote that deleting the wall orphans `kRho`/`kZ` and that #2 and the j_l core were one change. **Wrong:** `particles.metal:2516` `if (rho < EIGEN_R)` hard-gates the Gor'kov force independently of the clamp, so the pattern inside r<6 is BIT-IDENTICAL after the delete. The orphaning is a conceptual debt, not a runtime break. `[READ particles.metal:2516]`

**T2. 🚨 THE FIELD NOW INFLATES AND NEVER SETTLES — THIS IS THE COST OF T1.** Sustained note, 4.0 s/sample, n=16 samples: `[MEASURED n=16]`
```
 ~4s  meanR 12.0  maxR 62.0      ~24s  meanR 41.7  maxR 84.8
 ~8s  meanR 17.7  maxR 71.8      ~32s  meanR 49.2  maxR 90.4
~12s  meanR 26.7  maxR 75.9      ~44s  meanR 61.5  maxR 100.0 ← pinned at cap
~16s  meanR 32.5  maxR 79.6      ~64s  meanR 71.4  maxR 100.0
```
Monotonic, still climbing at 64 s. **There is no converged shape extent.** MECHANISM: the mode force self-gates to `rho < EIGEN_R` (6.0), the sculpt force is purely TANGENTIAL (`:2482-2484`, θ̂/φ̂ only, no r̂ term), and no boundary-repulsion force exists in the live shader. So outside r=6 the ONLY radial force is self-gravity, and it is too weak. `[READ particles.metal:2482]`
  ⇒ **THE GRID QUESTION AND THE INFLATION QUESTION ARE THE SAME QUESTION IN THE WRONG ORDER.** A box sized to a field that never stops expanding is chasing a symptom.

**T3. THE GRID — his "same old bug of weeks", LOCATED.** `renderer.mm:111-114` comment claims `cellSize = 6/128 ≈ 0.047`; that assumes `halfExtent 3`. Live `halfExtent = 64.0` (`:2089`) with `kGridSize 128` ⇒ **cellSize = 1.000, 21× coarser than its own comment.** `[READ renderer.mm:2089]`
  🚩 **AND THE FINE BOX NEVER COVERED THE CAVITY.** `kAmrFineExtent = 4.0` (`:132`), gated at `particles.metal:2166` on `rrF < halfExtent` AND all three axes. **The cavity is r=6.** So r=4→6 — the outer half of every Chladni shape — has ALWAYS run at 1.0. `[READ particles.metal:2166]`
  🚨 **HARD CEILING, know it before proposing coverage:** fine `cellSize = 2·extent/128`. ±16→0.250 · ±32→0.500 · **±64→1.000 (= coarse, zero gain)** · ±100→1.563 (**worse than coarse**). "Everything on the fine grid" is arithmetically impossible past ±64 at 128³.
  **Option A (128³→256³) costed:** 92 B/cell × 13 buffers ⇒ 184 MB → 1472 MB, **+1.26 GB**; Poisson 80 sweeps × 2 colours = 160 dispatches ⇒ 335M → **2.7 B invocations/frame**; and `hSph = cellSize` (`renderer.mm:2431`) so CFL `uMax ∝ h²` drops **4×** — a physics regression, not just cost. Buys only 1.0→0.5. `[MEASURED n=13 buffers]`
  **Option B (shrink halfExtent): PROVABLY WRONG** — `maxR` already pins at 100 against a 64 box.
  ⛔ **Option C (±4→±8) REJECTED BY HIM 2026-08-27:** *"well the dont widen the box. Shapes are way bigter than theh used to. the entire thing needs to be ont he fine gird."* `[HIS WORDS]`

**T0. 🚨 THE COMPILED BINARY IS TRACKED IN GIT — a commit-time trap, found 2026-08-27 17:21:00.** `SpaceSynth.app/Contents/MacOS/SpaceSynth` is tracked; `default.metallib` is not (`.gitignore:6` `*.metallib`). So every `package_macos.sh` dirties a 1.4 MB tracked artifact — and **the binary now in the tree was built from BOTH uncommitted source changes (T1 and the SS_SCREEN selector).** Commit one source plus that binary and the OTHER change ships silently inside the executable, invisible in the diff (`Bin 1388040 -> 1388040 bytes`). ⇒ **`git restore` the binary and commit SOURCES ONLY, then rebuild** — same treatment as `imgui.ini`. `[MEASURED git ls-files --error-unmatch]`

**T4. 🎚️ THE FADER AUDIT — his order, and it produced a HARD RULE.**
> **HIS ORDER 2026-08-27 15:42:00:** *"Our faders should all be universal law. If a fader only does one thing it's tuning and not a fader we need in the UI MANDATORY SAVE THAT"* `[HIS WORDS]` — saved to `memory/feedback_faders_are_universal_law.md`, indexed in HARD RULES.

  **THE ONE-SENTENCE CAUSE:** colour was unified across silence/play by `unifiedKelvin` on 2026-08-02. **Luminance and size never were.**
  **SEVEN DIE THE INSTANT HE PLAYS** — Lum Exponent/Gain/Ceiling, Size Gain/Exponent/Floor/Ceiling. All inside `if (starMix > 0.001f)` (`render.metal:1963`), applied via `mix(<play>,<star>,starMix)` (`:2340-2342`), and `starMix = 1 - smoothstep(0,0.5,envelopePhase)` (`:1925`) is **0 the moment a note passes phase 0.5**. The multiplier is zero — not a range problem. `[READ render.metal:1925]`
  **FOUR ARE DEAD ALWAYS — declared, plumbed, uploaded every frame, ZERO shader consumers:** `cam.tuneTrailGain` (8 sites; its consumer was the ribbon pass **deleted 2026-08-20** — the dial outlived the feature), `maxWaveDepth` (11 sites), the orphan `CameraUniforms.waveDepth` (`render.metal:30`, never assigned AND never read — a different field wearing the same name), and the dead `ParticleSystem::maxWaveDepth_` CPU path (getter has zero callers). `[READ render.metal:47]`
  **TWO ARE SPIN-ONLY:** both Smear dials gate on `pixelStretch > 0.001` (`postfx.metal:264/273`). **INVERTED:** Jitter gates on `clamp(totalAmplitude*4,0,1)` (`particles.metal:3220`) — dead at REST, alive only in play. Same bug, mirrored.
  🚨 **CLEANUP HAZARD — `PhysicsUniforms` IS COMPLETELY UNGUARDED.** `particles.metal` carries **0** `static_assert`; `renderer.h` guards PostFXUniforms (5) and CameraUniforms (5) and **PhysicsUniforms with none**. `maxWaveDepth` sits at offset 16 of ~40 fields; removing it shifts ~38 downstream by 4 bytes **with no compile-time check on either side** — dt would read amplitude and it would still compile and run. CameraUniforms by contrast is guarded by 10 asserts and CANNOT fail silently. **Add the asserts as their own change BEFORE any PhysicsUniforms removal, or leave a named pad.** `[MEASURED n=1 grep, 0 asserts]`
  ⛔ **CLEANUP DEFERRED BY HIM 2026-08-27:** *"okay f the cleanup for now"* `[HIS WORDS]`

**T5. ⌨️ THE KEYS FIX — COMMITTED, in the OTHER tree.** `SPACE-SYNTH-BH` @ **`3dc3be2`**, "Keys: a TAP no longer leaks spin into the body". A ~60 ms tap put ~1.6 rad/s on the body, which the 2.5/s drag integrated into **~37° of real rotation after the finger lifted** — the camera snapped to its quadrant correctly, the BODY had turned under it. One cause, both his symptoms (snap stopped reading as a snap; a tap made the shape "dent and bend"). Tap and hold now share one `kTapHoldSec`; **the ramp is deliberately UNCHANGED.** `[HIS WORDS 2026-08-27: "keys fix good"]`
  📌 **HIS RAMP BRIEF, NOT YET BUILT:** the hold ramp must be *"waaaaaaaaaaaaaay longer"* and anchored to a physical reference, not taste. Measured today: `kSpinMax = 2.08e-5 × 2.1e7 = 436.80 rad/s = 69.519 rev/s`, reached in **~3.7 s** via `accel = 8 + spinHold²·25` (`main.cpp:785`). The time-lapse `2.1e7` is the only taste number; `2.08e-5 rad/s` (c at M87*'s photon sphere) is real. Hole's own rotation: **1.000 rev/s at ISCO = 4.1774 s physical, 4.18× real time, WALL-CLOCK LOCKED** (`renderer.mm:263-273`) so held-pause fps does NOT speed it. The arrow-hold cap is **69.5× the hole's own rate.** `[MEASURED]`

**T6. 🚨 WHY THERE IS NO PHOTON RING — NOTHING IS TRYING TO MAKE ONE.**
  (a) **No near-hole regime exists.** Every `insideHorizon` gate is binary on `r < u.horizonR`; a particle at 1.01 r_h feels exactly what one at r=18 feels. No photon sphere term, no ISCO term, nothing that strengthens on approach. Crossing r_h strips outward v, multiplies v by 0.90, sets T=0 (`particles.metal:3196-3207`). Ordinary star outside, frozen corpse inside, **no state between**. `[READ particles.metal:3196]`
  (b) **No motion blur.** A sprite is drawn at discrete positions with the arc between them EMPTY, at any frame rate. `config.pixelStretch` (`main.cpp:2401`) smears each dot sideways to hide the gap — `main.cpp:328-329` calls it a fuse that *"bridges the per-frame gap so it doesn't strobe."* **More rev/s only aliases harder.** `[READ main.cpp:2401]`
  (c) **The lens is still a PLATE.** `render.metal:1085` builds the whole deflection on `cam.viewForward*` — the CAMERA's axis — then relocates sprites in that frame (`:1113-1132`). Turn the camera and the "physics" turns with it. `[READ render.metal:1085]`

**T7. THE DISPLAY IS NOT A CONSTANT — this bit us twice in one hour.** His panel moved 60 Hz → 120 Hz → 1920×1200 → 4K 3840×2160 → back, **live, mid-session**. `[MEASURED]`
  🚨 **HIS STANDING ORDER: *"dont hardlock it to 60 fps though."*** Never pin, cap or stabilise the frame rate — including to make a measurement easier. `[HIS WORDS]`
  **Closure arithmetic is a DIAGNOSTIC, never a target** — it moves with the panel while the physics does not: at 120 fps the 69.5 rev/s cap is **57.9%** of per-frame closure; at 60 fps **115.9%**; at 18.7 fps **371.8%**. A ring that depends on that number is a rendering coincidence. **The Cologne rig is not this laptop.**
  📊 **fps as a DISTRIBUTION, always, with the display mode stated.** 1920×1200@120: min 18.9 · p50 95.8 · max 120.1 (n=117). 4K@120 idle: min 33.7 · p50 38.0 · max 46.3 (n=94) — **flat, drifts UP, does NOT decay.** ⇒ **fps decays with DISPERSION, not runtime** — the earlier 120→48 was matter spreading past r=64 into the clamped boundary cells, not a leak.

**T8. 🚩 STILL OPEN, HIS WORDS, NOT YET TRACED.** *"The hole doesn't stay. It just vanishes instantly"* and *"no the bh doesnt shrink through play it goes straight to the shapes lol"* (2026-08-27). ⛔ **BOTH REFUTE MY OWN CLAIM** that a held note revives corpses at spawn mass and withdraws it from the hole (`particles.metal:800-807`). The ledger reads as a withdrawal; the screen does not show one. **Candidates, untested:** the withdrawn quantity is not the one the DRAWN hole is built from · matter is re-eaten faster than the hole shrinks · the seed and the drawn hole are simply two different numbers. A hole that vanishes *instantly* points at the first. `[HYPOTHESIS — does not close this row]`

---


## 👀 WATCH LIST — THREE THINGS BUILT AND UNSEEN, do them in ONE pass at the screen
**Opened 2026-08-10 15:18:00 at his request** (*"put on to watch list once im on screen"*).
Nothing here is ✅ until he has looked. **Rebuilding the main tree destroys W2 and W3 — see the rule below.**

| # | What | Where | What to DO | What to WATCH | Passes if |
|---|---|---|---|---|---|
| **W1** ⭐ | **F5 — `viewForward` plumbing. NOW IN THE MAIN TREE.** | **main** bundle — **pid 9391, launched 19:41:36, FULLSCREEN**. Built 19:41:25. | Just look at it. Normal ortho view. | The whole picture. | **NOTHING changes.** F5 is a visual no-op by construction — while the camera still points at the origin, `viewForward` *is* `normalize(-cameraPos)`. **Any visible difference means the plumbing is wrong.** Unblocks F6. |
| **W2** | **A4 — release discontinuity** | **main** bundle — **pid 6857, launched 15:53:32** (pid 6225 was killed, see below) | Hold a chord until the pattern visibly SETS (the crystal forming, ~10–15 s), then release. **Do this in the first few minutes of the run.** | The instant of release. | Matter **eases** into motion over the release tail instead of lurching the moment you let go. The inspiral itself should be unchanged. |
| **W3** | **live-UI panel** | **main** bundle, same run | Open it. | — | Your call on whether it is what you wanted. Built 09:55:37, carried into the 15:12:02 build, never seen. |

### ✅⏳ A4 CURRENT VERDICT — **"GOOD ENOUGH", EXPLICITLY NOT FINISHED. 2026-08-10 17:12:00, his words.**
> *"the fix is good enough. its not 1/10 yet. remember that for the board. but lets move on"*

**Shipped as `ea2cfba`, pushed.** The frozen→star-map handover: self-gravity was scaled by `(1 - playGate)` and `playGate = smoothstep(0, 0.025, amplitude)` — **a THRESHOLD, not a ramp**. Amplitude stays above 2.5% for the whole hold *and* nearly the whole release, so gravity was fully OFF the entire time and snapped fully ON in the last few milliseconds. **It was a gate, not a damper** — my earlier damper theory was true about the crystal lock but was not this. Now `gravSupport = smoothstep(0, 0.5, amplitude)` scales gravity only, so it returns in proportion to how far the sound has faded. Nothing switches, no branch is crossed.

🚨 **DO NOT LET "good enough" BECOME "done".** He said it in the same breath as "it's not 1/10 yet" and asked for that to be on the board. **The row stays open.** Remaining known discontinuities at note-off, neither ruled out: the **rebirth stream** (`:664`) and the **node flares** (`:1123`), both creation/emission events that still stop dead in one frame. See `AUDIT_2026-08-10_note_lifecycle_chain.md` §5.
⚠️ **Also unresolved and named by him the same session:** *"the held shape has never been perfect."* The gravity fix deliberately leaves the held shape untouched (sustain sits above the 0.5 band, so support is saturated exactly as before). **That is a separate, still-open problem.**

---

### ⏸️ W2 VERDICT — **PARTIAL. BETTER, NOT GONE. 2026-08-10 16:01:00, his eyes.**
> *"so w2 its better but not gone. when i hold longer it still kinda.. jumps to 0 gravity / star mode before the actual shape settled.. talking maybe a second or so.. something's still jumpy there."*

**The A4 ramp WORKS at the boundary it targets (3.5, sustain→release) — he confirms improvement.** What remains is a **DIFFERENT boundary that I did not touch: release→silence, phase 4 → 0.** His own words name it: *"jumps to 0 gravity / star mode"* is the silence/star-map regime switching on.

❌ **MY "IT IS ONE NUMBER, `release = 0.400f`" CLAIM IS RETRACTED — 2026-08-10 16:28:00.** I said the release is a fixed 400 ms audio constant doing a physics job. **Wrong, and the code is better than I described it.** `envelope.cpp`: `relDur = clamp(sustainHeld, params.release, 1.5f)` — **0.400 is the FLOOR, not the value.** The release duration **already scales with how long he held**, up to 1.5 s. *"A quick tap releases fast, a long hold takes up to ~1.5 s"* is in the source comment. **So "the release is too short and fixed" is a dead theory.**

⏸️ **AND THE RELEASE→SILENCE BOUNDARY IS EXPERIMENTALLY RULED OUT.** I built a 2 s hold of the release regime (16:07:41) purely to delay that switch. **His verdict 16:12:00: *"noo because now the stuck moment is before the pause u just introduced. thats where the snap is at."*** The hold did not hide the snap — **it isolated it**, proving the discontinuity is at or just after note-off. **Reverted 16:09:36. Do not retry a settle-hold here.** A rejected change that localises the fault is worth more than a pass.

⭐ **THE REAL MECHANISM, and it is structural — see `AUDIT_2026-08-10_note_lifecycle_chain.md` §2.** The crystal lock is applied to the CARRIED velocity at `:2795`; `finalV` is built at `:2847` as `(vp * fric + shiftV) * soften` — **the force impulse `shiftV` is added AFTER the lock, untouched.** So the hold **bleeds off speed while every force keeps pushing at full strength, and nothing is stored in tension.** **A real solid resists FORCE; this one resists SPEED.** That is his *"it continues from before it actually stopped"* exactly: remove the scrubbing and matter resumes the same direction at the same rate, because dynamically the hold never happened. **And it explains "when i hold LONGER":** `hardness` keeps integrating for 10–15 s, so a longer hold means a harder damper masking an unchanged force, while the release only stretches to a 1.5 s cap — **the two do not scale together.** | 🔨 partial fix live in the 16:09:36 bundle |

🚨 **W2 HAS A SHELF LIFE — THE FIRST ATTEMPT WAS SPOILED BY IT (2026-08-10 15:53:00).** Pid 6225 was left idle **41 minutes** before he looked. In that time one body reached **356,475 M☉ = 60.0% of the 594,276 M☉ field** and the visible field was down to ~4 objects (his screenshot, 15:52). **A4 is untestable on a consumed field:** the fix acts on the sustain crystal lock, which freezes DENSE matter — with four bodies left there is nothing to freeze and nothing to lurch, so the test would have returned a meaningless pass. **Play within the first few minutes of a fresh launch.**
⭐ **AND THAT IS A FINDING, NOT JUST A SPOILED TEST — SEE A1′.**

🚨 **BUILD FREEZE ON THE MAIN TREE UNTIL W2 AND W3 ARE VERDICTED.** The main bundle **is** the A4 test. Any `package_macos.sh` in `SPACE-SYNTH-TUBE` overwrites it and the pending test is gone. The **camera worktree is unaffected** and can build freely — that is what it is for.

---

🚨🚨 **HIS ORDER, 2026-08-10 16:01:00 — ONE LIVE APP, NO PARALLEL BUILDS. THIS SUPERSEDES THE WORKTREE ARRANGEMENT.**
> *"we said we only have 1 live app at any given time which is ours. make the camera window understand that NO 2 BUILDS PARALLEL"*

**Effective immediately: only the MAIN tree builds and only the MAIN tree runs.** The camera worktree stays on disk, **unbuilt and unlaunched**, at `10:44:03`. Relayed to the camera window 16:07:00; it has stood down. **This supersedes his own 10:37:00 "do the worktree"** — newest signal wins, and nobody is to quote the older approval back at him.
⚠️ **W1 IS SUSPENDED AS WRITTEN** — it asked him to launch the camera bundle, which is precisely what he has ruled out. **Do not ask him to run it.**
⭐ **This also dissolves the two-bundle hazard below** (same process name in two trees) by removing the second bundle rather than by working around it.
📌 **OPEN CONSEQUENCE, HIS CALL, NOT STARTED:** F5 exists only in the camera worktree and can no longer be verified where it lives. The obvious resolution is F5 moves into the main tree and is verified in the one live app. **Nobody is to begin that cross-tree move without his word.**
## HOW TO READ THIS

| Column | Meaning |
|---|---|
| **State** | ⬜ open · 🔨 built but UNVERIFIED · ✅ done and verdicted by Jamal · 🚫 blocked |
| **Evidence** | The `file:line` I actually read to confirm the state. If this column says "not re-verified", treat the row as hearsay. |
| **Cost** | Estimated sessions of work. `S` ≈ under one session · `M` ≈ one session · `L` ≈ multiple sessions · `?` ≈ unknown until measured |

A row is only ✅ when Jamal has SEEN it and said so. "It compiles" and "it deployed" are both 🔨.

**Verification standard:** every row below marked with an evidence line was re-read in the source
on 2026-08-07 12:02:31. Rows marked "not re-verified" carry their claim from an older doc and
should be re-measured before anyone acts on them.

---

## 🕳️ A0 → MOVED. The GoPro verdict, the A0 test and its inconclusive result now live in **`docs/BOARD_BLACKHOLE.md` §N1** (moved 2026-08-19 00:14:12, verbatim). §F below still gates it.
---

## 🎥 F. CAMERA — **NOW GATES A0**, and it is the show. Branch A (perspective-native), his call 2026-08-10

Owned by the camera window (`CAMERA`, ref `[1012d2]`), in its own worktree. Research reported 2026-08-10 10:33:00.
**F5 IS BUILT — 2026-08-10 10:44:03.** Everything below F5 is still unstarted.

**WHY "LOCKED IN PLACE" IS LITERAL, not a feel complaint** — `src/core/camera.h`:

| # | Defect | Evidence |
|---|---|---|
| **F1** | **Input drives the CAMERA, not a TARGET.** `rotate()` adds an impulse to `velPhi`; there is **no goal state in the class**. Every good game camera inverts this — input moves an invisible target, the rendered camera chases it. **Biggest single cause of the feel, and a precondition for most of the rest.** | `camera.h` `rotate()` / `velPhi` |
| **F2** | **Ease-OUT only.** An impulse means instantaneous acceleration — full speed at frame 0, decaying. Cinematic motion needs ease-**in** too. **Unobtainable at any current setting.** | same |
| **F3** | **Not frame-rate independent.** `friction = max(0, 1 - dt*6)` is a linear approximation of `e^(-6·dt)`; they diverge as `dt` grows. **The camera feel changes with particle load** — on stage, it behaves differently when the field is heavy. | `camera.h:38` |
| **F4** | **No target, no FOV, no roll, no path.** `buildViewMatrix` hardcodes `forward = {-posX,-posY,-posZ}`. "Camera is somewhere, looking at something that is not the origin" **does not exist in the file** — so dolly and POV are not hard, they are *unrepresentable*. | `camera.h:123` |

**THE REPLACEMENT — second-order dynamics, exact closed form** (`a + 2ζω·v + ω²x = 0`, Ryan Juckett; same math as Unity `SmoothDamp`). Four coefficients precomputed per timestep, then `newPos = posPosCoef*oldPos + posVelCoef*oldVel`. **Exact for any `dt`** — it solves the ODE analytically over the interval instead of integrating, so **F3 dies for free.** Both dials DERIVED, per his standing rule: `ζ=1.0` = fastest with zero overshoot (zoom — an overshooting zoom reads as a mistake); `ζ≈0.7` = ~5% overshoot (orbit — that overshoot is what reads as an *operator* rather than a script). `ω = 5.83 / T_settle` (critically-damped 2% settle is `ωt ≈ 5.83`), and **`T_settle` is tied to the beat, not to taste**: at 128 BPM, `T_beat = 60/128 = 0.469 s` → `ω = 12.4 rad/s`. **Camera feel derived from tempo — locked to the music by construction.** ⬜ **AWAITING HIS VERDICT — everything hangs off this one.**

| # | Item | State | Notes |
|---|---|---|---|
| **F5** ⭐ | **`viewForward` into `CameraUniforms`, consumed at the `dHat` and `viewDir` sites.** ⭐ **SELF-VERIFYING: while the camera still points at the origin, `viewForward` is IDENTICAL to `normalize(-cameraPos)`, so the refactor is a visual NO-OP. If anything changes on screen, it is wrong.** Verifiable before it is useful — **and it is what makes A0 measurable.** Shipped WITH the layout guard (**A0h′**): `sizeof == 272` plus `__builtin_offsetof` anchors at `bhShadowNdcRadius == 108`, `bhX == 200`, `viewForwardZ == 268`, **written identically into both files**. ⭐ **The guard is PROVEN LIVE, not assumed: `default.metallib` is stamped 10:44:03, newer than `render.metal` at 10:43:42 — the Metal compile ran after the asserts were in, so they passed.** The CPU/GPU mirror is now bound by the compiler instead of by a comment. 🚨 ✅ **CLOSED 2026-08-22 22:04:16 — SHIPPED AND IN DAILY USE. It was never actually waiting on anything.** His words: *"uve been going mad over 2 3 points on the board that dont even require it … something that wasnt seen yet although ive been working with it for a week now."* He is right. It has been live in every session since it was built and he has reported plenty of other faults in that window. ⚠️ Closed as **shipped, no complaint recorded** — NOT as measured-correct. Do not re-park a built row on his eyes; if it were wrong he would have said so. *(Original status: "BUILT, NOT SEEN — the no-op claim is unverified until he looks." Built 2026-08-10, parked 12 days.)* **Historic note kept: The whole point of F5 is that the screen must not change; nobody has checked the screen.** | 🔨 **MOVED INTO THE MAIN TREE AND BUILT THERE 2026-08-10 19:41:25 — AWAITING HIS EYES.** Taken as a `git diff` from the worktree and `git apply`-ed (**clean, no 3-way needed**), not copied — a file copy would have clobbered today's `renderer.h`/`renderer.mm` changes, both of which moved in `ea2cfba`. ⭐ **THE ANCHORS SURVIVED THE MOVE AND THAT IS A RESULT, NOT LUCK:** they were computed against `779a517`, and main has changed `renderer.h` since — but that change was to **`PhysicsStats`, not `CameraUniforms`** (verified: `git diff 779a517..HEAD -- renderer.h | grep -c CameraUniforms` → **0**), so `sizeof == 272` and offsets 108/200/268 still hold. **The build passed both the C++ and the Metal asserts in the main tree**, which is a stronger statement than the worktree build: the guard now certifies the CPU/GPU mirror against the struct that today's work actually produced. Camera worktree is now **stale and superseded** — F5 lives in main. | `renderer.h:233-235`, `:270`; `render.metal:79-81`, `:103`, `:937`, `:1067`; `camera.h getForward()`; `main.cpp` feed — all verified **2026-08-10 14:49:00**. See **A0j** |
| **F6** | **Target/actual split + spring**, ω from beat. **This is where "locked in place" dies.** | ⬜ blocked on his verdict above | F1+F2+F3 all fall to this |
| **F7** | **MIDI CC path + learn.** `midi_input.mm` discards **all** CC: `else if (type >= 0x80) { j += 3; }`. Callback is note-only. Needs a `0xB0` parse, a `(cc, value, channel)` callback, a learn table. ⚠️ **7-bit CC = 128 steps; across `rho` 50→2000 that is ~15 units per step — visible stair-stepping on a slow zoom, which reads as broken on a large screen.** Fix falls out of F6 free: **CC writes the spring's TARGET**, the spring outputs the smooth value. **Second independent reason F6 must come first.** | ⬜ | `midi_input.mm` |
| **F8** | **Ableton Link, render-side.** Verified against `Link.hpp` (header-only C++): `captureAppSessionState()` = app/render thread, thread-safe, **not** realtime-safe; `captureAudioSessionState()` = audio thread, realtime-safe. **Camera sync uses the App form on the render thread and never touches audio → adds NOTHING to D6.** 🚨 **BOUNDARY — do not let this be remembered as "Link is safe":** tempo-locking the **SYNTH** uses the Audio form and lands squarely in D6. Different question, different answer. `phaseAtTime(now, quantum=4)` = bar-progress 0→1 = the master animation clock. | ⬜ | see **D6** |
| **F9** | **Two uses of one clock, conflated by most people** (from Resolume's model): **(1) quantised launch** — discrete events wait for a boundary (a dolly shot fires on the next bar, never mid-phrase); **(2) continuous phase drive** — a parameter *is* a function of phase (`phi = 2π·beat/16` = exactly one revolution per 4 bars). ⭐ **Copy outright: Resolume deliberately DISABLES hard resync while Link is on.** Mid-show, a camera that snaps to re-align is worse than one slightly off. Orbit speed stops being "0.2 rad/s" and becomes "one revolution per N bars" — a musical quantity. **Inspiration, not lifting** — our numbers derive from our own clock. | ⬜ | per [[feedback_ui_sample_dont_steal]] discipline |
| **F10** | **Dolly splines.** Separate WHERE THE CAMERA IS from WHAT IT LOOKS AT as two independently animated tracks (Cinemachine's one good idea). Position on Catmull-Rom; look-at on its own. ⚠️ **The caveat that bites everyone: naive spline `t` gives UNEVEN SPEED** — the camera accelerates between waypoints and decelerates at them. **Needs arc-length reparameterisation or the dolly reads as broken.** | ⬜ **droppable if the show gets tight — said now, not in week three** | |
| **F11** | **POV-follow.** Cheaper than feared: `particleBuffer` is `MTLResourceStorageModeShared` and `renderer.mm` already casts `.contents` to `GPUParticle*`. Unified memory → no blit, no stall. Real issue is a torn/1-frame-stale read, and **for a spring-smoothed target one frame is invisible.** Raw particle motion is chaotic, so the spring does the real work: low ω, target = particle, eye trails. ⬜ **OPEN QUESTION FOR HIM: what should POV track?** A clicked particle / a random one / a derived one ("fastest", "nearest the horizon"). **Materially different** — a chosen particle needs picking plus an ID stable across frames; "fastest right now" is a per-frame reduction that hops between particles. **Not guessing this.** | ⬜ droppable | depends on F5, F6, F10 |

**SEQUENCE (his to approve):** F5 → F6 → F7 → F8/F9 → F10 → F11. **F5–F7 alone give a camera that feels right and is playable.** F10 and F11 are the droppable ones if the show gets tight.

🔨 **BUILD TOKEN:** F5 needs it. Currently held by the board window. **Either hand it over, or ask him for a git worktree so the two windows stop sharing one bundle.** His call.

---

## 🌫️🚨 A9. **WHY DENSE MATTER LOOKS BAD — ANSWERED 2026-08-10 20:02:00. IT CAN ONLY ADD LIGHT.**

**His question, and he was right to reject my seed-blob framing:**
> *"no. the true question is why does matter at high concentrations look like ass. it's supposed to look amazing. it looks like ahhhh"*

**ANSWER, in one line: density can only ever make the image BRIGHTER. There is no mechanism anywhere by which concentration reduces light, so every dense region climbs to saturation and flattens into a white blob.**

| Fact | Evidence |
|---|---|
| **The particle pass is PURE ADDITIVE.** `sourceRGB = One`, `destinationRGB = One`. N particles in a pixel = N× the light, without bound. | `renderer.mm:658-663` |
| 🚨 **THE ABSORPTION PASS EXISTS, IS COMPLETE, AND IS `if (false)`.** Cold+dense gas re-drawn as **absorbing** splats over the additive image: `dst × (1 − src_rgb)`, blue absorbed hardest so what shines through **reddens** — the real extinction signature. Dark silhouette bodies, and **bright rims emerge FREE** where an absorbing body cuts into the glow. Pipeline and both shaders are built and kept. | `render.metal:2544-2620` (`dust_vertex`/`dust_fragment`), pipeline `renderer.mm:733-748`, **draw disabled `renderer.mm:3504` `if (false && dustPipeline)`** |
| **WHY it was disabled — his own field verdict, and the reason is NOT the concept.** 2026-07-23 16:34: *"a low-res shadow thingy / yellow underbelly attached to the hole"*. Cause recorded in the same comment: the absorbing splats are **UN-DEPTH-SORTED**, so instead of a silhouette they paint a smooth bounded wash (teal minus absorbed blue = cream). The comment explicitly preserves the concept: *"The CONCEPT (design §2b) stays for the BH overhaul with depth ordering; this v1 draw is off."* | `renderer.mm:3494-3503` |

⭐ **THIS IS EXACTLY WHY IT DOES NOT LOOK LIKE THE NASA IMAGES.** In every one of those pictures the structure comes from what **blocks** light — dust lanes, silhouettes, dark pillars, reddened cores. Emission alone cannot produce them. Ours has emission alone, so concentration produces the one thing additive blending can produce: a clipped white lump with no interior structure and no depth cue. **"Cheap" is the correct word for it, and it is a rendering-model consequence, not a tuning problem.**

⭐ **THE FIX PATH THAT AVOIDS THE THING THAT KILLED v1 — EXTINCTION WITHOUT SORTING.** v1 failed because it tried to composite absorbers in draw order. **Don't composite them — compute the optical depth analytically.** The 128³ density grid the dust shader already reads (`cellCounts`, trilinear, `render.metal:2586`) is enough: for each particle accumulate density between it and the camera into an optical depth τ, and scale its emitted luminance by `exp(−τ)` **in the existing additive pass**. Multiplying each particle's own emission is **order-independent by construction** — no sorting, no second composite, no wash. Density then genuinely removes light, dark lanes and rims appear because the far side is attenuated by the near side, and it costs one grid march per particle instead of a sorted pass over 2M splats.
⚠️ **Second gate to fix at the same time:** the dust shader self-gates on `cold = 1 − clamp(temp/2.5)` (`render.metal:2579`) **and on `M > 3.0` gas mass only** (`:2574`), so hot dense matter — which is precisely what a collapsing core becomes — would absorb **nothing** even with the draw re-enabled. **Re-enabling `if (false)` alone will NOT fix this.** Real dust survives at temperatures far above where this gate closes.

🚩 **FOURTH `if (false)` FOUND ON THIS PROJECT** (with A3②'s origin lock, and the envelope→radius coupling in `particles.metal`). **A disabled-but-complete feature is invisible to every grep for "what is on", and its comment reads like working behaviour.** Worth a standing sweep: `grep -rn "if (false" src/`.

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| **A9** | **Order-independent extinction — BUILT 2026-08-10 20:47:36, on his order ("Build it").** Each particle marches the hash-grid density toward the camera, accumulates optical depth τ, and scales **its own** emission by `exp(−τ)` at the end of `particle_vertex`. ⭐ **Order-independent by construction** — it multiplies a particle's own luminance rather than compositing splats, so the un-sorted wash that killed v1 (his verdict 2026-07-23 16:34) **cannot recur**. Lanes and rims fall out for free: the far side of a clump is attenuated by the near side. **Reused rather than re-derived:** `applyInverseSpin` (written 2026-07-25 for the metric ray) maps the world-space camera direction into the physics coords the grid is indexed in, and `physPosW` is the pre-pose position the file already insists density be sampled at. ⭐ **First real consumer of F5** — the march direction is `cam.viewForward`, not `normalize(-cameraPos)`, so it stays correct when the camera stops looking at the origin. ⚖️ **6 steps, `kAbsorb = 0.004`, per-cell count clamped to 128** (the same `MAX_PER_CELL` ceiling the flare stress uses) so an uncapped 50k core cannot drive τ to infinity; τ_max ≈ 3.07 ≈ 95% absorbed. **All first values, not derived.** 🚨 **The old `dust_vertex` pass is UNTOUCHED and still `if (false)` at `renderer.mm:3504`** — this is a different mechanism, not a re-enable, and its `cold`/gas-mass gates were deliberately NOT inherited (they would have made hot dense cores transparent, which is exactly the case that matters). | 🔨 **BUILT, UNSEEN** — pid 10209 launched 20:47:46 fullscreen; perf soak running from 20:59:44 | `render.metal` end of `particle_vertex` (grep `A9: EXTINCTION`); cause at `renderer.mm:658-663`, `:3504` | **M** |
| **A9-perf** | ⚠️ **UNMEASURED AT BUILD TIME — 6 grid reads per particle per frame, ungated.** Nothing skips the march for particles in empty space. Soak started 2026-08-10 20:59:44 to compare against today's 4-run baseline (first-quarter means 56.2 / 38.6 / 59.1 / 46.5 at 2M). **If it costs frames, the cheap fix is a pre-reject on the particle's own local density before the loop.** | ⬜ measuring | `logs/A9_extinction_*.log` | **S** |

### ❌ A9 VERDICT — **FAILED. 2026-08-11 02:35:00, his eyes.** *"look its still a rick and morty eye just buzzy stuff we dot have any science in place here"*

A9 was built to answer *"why does matter at high concentrations look like ass."* It does not. **Mark it failed, not partial.** What the measurement added:

| Fact | Number | Evidence |
|---|---|---|
| Extinction is **already at full strength** on the clump — the gate is not the problem | `smoothstep(150,1500,count=34835) = 1.000` | `[DENSPROBE]` 2026-08-11 02:47 |
| At τ=6 that is transmission R 0.23 / B 0.07 — heavy reddening — and it still reads white | derived from `kExt=(0.55,0.78,1.00)×0.45` | `render.metal:2245` |
| ⭐ **Why it can never make interior structure:** the object is ~1 cell across, the march steps `1.5×cellSize`, so the FIRST sample is already outside it. Every particle in the clump gets the same τ ⇒ flat by construction. | cell = 1.0 sim; clump ≈ 1 cell | `render.metal:2199` |
| **A9-perf: the "~32 fps, half the baseline" claim is RETRACTED.** 41 samples: mean **53.3**, min 16.9, max 90.0, against a 42–57 baseline. The earlier figure was a transient read as a level. | mean 53.3 fps | `run_2308.log` |

**Consequence: extinction was a RENDER answer to a PHYSICS hole, which is why it did not take.** Fixing the look requires density to resolve better than 1.0 sim (§G2), not more absorption.

---

## 🌐🚨 G. GRID + SCALE AUDIT — **his direct order, 2026-08-11 02:58:00.** *"i want a checkup throughout the codebase for the same error... its not unified im 10000% SURE"*

**He is right.** Four live spatial domains, no shared centre, extent, or resolution.

### G3. ❌ MY OWN HYPOTHESIS, DISPROVEN — record it as dead so nobody retries it

I claimed the collapsed clump leaving the ±4.0 AMR box was killing the horizon, and that this explained both the broken rotating BH and particles drawn inside the hole. **Controlled for collapse state, box membership has ZERO effect:**

```
                         IN box              OUT of box
dispersed  ratio<0.3  : raw==0 33/33 (100%) | raw==0 34/34 (100%)
AT HORIZON ratio>0.8  : raw==0  0/53   (0%) | raw==0  0/2    (0%)
max ratio while OUT of the box = 4.955  ← a fully formed hole, outside the grid
```

The 94%-correlation I reported first was an artifact: the OUT samples happened to be the dispersed ones. **`horizonR` is explained entirely by `ratio`, exactly as designed.** The origin-lock is still real as a structural fact; its consequence is **UNPROVEN**.

### G4. WHERE SCALE ACTUALLY BREAKS — **TWO LIVE UNIT SYSTEMS**

| Source | Mass anchor | Meters per sim unit |
|---|---|---|
| `spacetime.h:36,43` — what the physics derives G, c, r_s from | `kMfieldMsun = 5.94276e5` M☉ | **1.75504e9 m** |
| `physics_constants.h:113` — `#include`d by `main.cpp:16`, read at `:1054` | `BH_SGRA = 4.297e6` M☉ | **1.27e10 m** |

**They differ by 7.23×.** Its own header still reads *"Two candidate black-hole anchors (DECISION PENDING)"* — the decision was never made, just duplicated. Worse, `renderer.mm:~1976` sets `physicsUniforms.centerGM = gmSim(4297000.0)` — **Sgr A*'s mass hardcoded into the live physics**, against a field anchor of 5.94e5.

**Time:** `main.cpp:2537` `simDt = 0.0165f * timeWarp` — base step pinned, warp **multiplies** it, no sub-step compensation on the default path. `main.cpp:2530` admits *"Above ~8× the Verlet integrator coarsens."* He runs it at 64×. The fix is written down and never built — `units.h:20`, *"an accuracy-governed cap."*

### G6. 🚨 **THE REAL PROBLEM, HIS WORDS 2026-08-11 03:41:00 — AND IT IS NOT VISUAL**

> *"its not thta i see them its that theyre still computed even if only liek 5 thousand are out 2 mio get rendered thats the fucking problem"*

**The capture cull is a LATE DISCARD, not a skip.** It lives inside `particle_vertex` (`render.metal:541`, cull at `:665`), so **all 2M vertex invocations still run and pay the full vertex cost**; zeroing `pointSize` saves rasterisation only. Removing 5k of 2M changes nothing that matters. **This reframes the whole cull as a perf item, not a correctness item. NOT STARTED — no design agreed.**

## 🧊🚨 H. THE PSEUDO-3D REGISTER — **his direct order, 2026-08-11.** *"where are we still faking 3d... bring it fully into the 3rd dimension what about chaldni?"*

**Verdict on the build this was audited against: *"stable 60 FPS"* (his words, 2026-08-11).**

### H0. THE ONE SENTENCE

**The physics is 3D. The render is not.** Every fake found is in the render path, and
they cluster almost entirely in the black hole. Physics evidence: the cavity eigenmode
Ψ(ρ,θ,z) (`particles.metal:460`), the 3D sphere rest cap, and a real 3D
`dot(relBH0, relBH0)` horizon test (`particles.metal:629`).

### H1. THE REGISTER — ranked by how much of "it doesn't read as 3D" each can own

🚨 **ALL TEN ROWS RE-VERIFIED AGAINST SOURCE 2026-08-11 12:31:44. EIGHT SURVIVE, ONE IS REFUTED, AND EVERY LINE NUMBER IN THE ORIGINAL WAS WRONG DOWNSTREAM OF THE DELETIONS.**
The register was written at 11:48 but its `file:line`s were read **before** the 04:11 dead-code cut. `render.metal` lost ~34 lines (the Y-axis twin) and `renderer.mm` lost ~227 (`render(config)`), so every citation past the cut point was shifted by exactly that much — P2 `:1257`→ actual `:1223`, P3 `:1783`→`:1556`, P6 `:796`→`:762`, P8 `:941`→`:907`, P10 `:1261`→`:1227`. Sites *before* the cut (P1, P4, P5, P7, P9) were exact. **This is the A0i failure mode happening inside the same session that caused it**, which is the strongest argument yet for the standing rule: cite a grep pattern, not a number.
**The numbers in the table below are post-12:31:44 and have shifted AGAIN** from the comment work logged in §H7 — they are stamped, not permanent. Grep the quoted token.

| # | Site (verified 2026-08-11 12:31:44) | The fake | Weight |
|---|---|---|---|
| **P1** ✅ | `renderer.mm:1033` `depthDesc.depthWriteEnabled = NO` | ✅ **CONFIRMED, and it is WORSE than written.** Both depth states are write-off (`:1033` particles, `:1042` background), so **no pass in the project writes depth**, and all five render encoders bind the same `depthState` (`:3424, :3483, :3519, :3547, :3612`). ⭐ **NEW, not in the original claim: the depth buffer is allocated (`:4005`), attached (`:3354`), CLEARED EVERY FRAME (`clearDepth = 1.0`) — and `storeAction = MTLStoreActionDontCare` (`:3356`), so it is discarded unread.** We pay to allocate and clear a depth buffer, write nothing to it, and throw it away. Every "in front / behind" on screen is additive blending. ⚠️ The original's "this is why the 2026-07-24 geodesic paint was withdrawn" is **NOT supported** — the 2026-06-28 deletion was a fullscreen disk shader and the 2026-07-24 metric march is **live** (`renderer.mm:214`, `render.metal:2694`). Dropped from the claim. | ★★★ |
| **P2** ✅ | `render.metal:1243` (was cited `:1257`) | ✅ **CONFIRMED, mechanism now pinned exactly.** `float dist = mix(out.position.w, cam.cameraPos.w, isOrtho)` and `renderer.h:54 orthoMode = true`. ⭐ **What `cameraPos.w` actually holds was not stated before: `renderer.mm:1496` `cam.cameraPad = config.cameraRho` — the camera's distance from the ORIGIN, one scalar per frame.** So in the default projection all 2M particles are handed one identical number, and it drives point size and the fragment fade. **A depth cue with zero variance across the field.** | ★★★ |
| **P3** ✅ | `renderer.mm:1556` (was cited `:1783`) | ✅ **CONFIRMED verbatim.** `cam.bhShadowNdcRadius = (frustum > 1e-4f && bhLensActive) ? bSim*plateRadius/frustum : 0.0f`. The correct derivation and the **~2.897×** figure are already written in the comment above it, along with *"Fixing the divisor is the NEXT change, deliberately not batched into this one."* **This is a deferred fix, not an undiscovered bug.** | ★★★ |
| **P4** ✅⚠️ | `render.metal:595`, `:530` (was cited `:586`, `:532`) | ✅ **CONFIRMED — rotates `.xy` only about Z, Ω from the 2D radius `rxy`. An annulus pretending to be a disk.** ⚠️ **The original omitted the gate that decides when it is live:** `:586` is `(bhToggles & bit20) && bhDiskGM > 0 && bhDiskAxisY < 0.5 && cam.envelopePhase < 0.5f`. **So P4 runs in the idle / star-map regime and is switched OFF for the whole time he is playing a note.** Any judgement of it must be made on an idle screen. | ★★ |
| **P5** ✅ **FIXED** | `render.metal:527` (cited `:576`, exact at the time) | ✅ **CONFIRMED EXACTLY, and it was the more misleading half that was right.** `app_state.h:56` is `uiTogAnalyticSpin = true` and its own inline comment says **"DEFAULT ON"**, set 2026-07-25 19:15 (*"build the clean time-lapse"*), while the shader comment kept saying "DEFAULT OFF" — the two have contradicted each other for 17 days, and the shader's version tells a reader that P4 is dead code. **✅ COMMENT CORRECTED 2026-08-11 12:31:44 — see §H7.** | ★★ |
| **P6** ❌ | `render.metal:782` (was cited `:796`) | ❌ **REFUTED — THE FIX IS A NO-OP AND MUST NOT BE BUILT.** The code reads as claimed (`rDil = length(in.posW.xyz)`, measured from the origin), but the implied repair — re-centre on `cam.bhX/Y/Z` — **changes nothing, because those are always exactly (0,0,0).** `bhPosX/Y/Z` are hard-set to `0.0f` at `renderer.mm:3293-3295` (**the ORIGIN LOCK, his own call**) and the enclosure-COM refinement that could move them is inside `if (false)` at `:2935`. **The renderer's hole centre IS the origin, so `length(posW.xyz)` already measures from it.** The "hole sits at r=3.8–5.9" figure describes where the physical MASS is — a quantity the render never receives. **4th no-op fix logged on this board** (cf. A3①'s `kREnc`, A3③'s latch). ⭐ **Real consequence: P6 is not a 3D-faking row at all, it is A3② wearing yet another costume.** Folded into A3②. ✅ Refutation written into both files 12:31:44 so nobody re-derives it. | ~~★★~~ **0** |
| **P7** ✅ | `spatial_hash.metal:281` (was cited `:262`) | ✅ **CONFIRMED ON ALL FOUR COUNTS, incl. the one that was only asserted.** Averages 128³ along world Z into a `texture2d`; normalisation cites *"800k in 256x256"* against a live 2M on 128³; **and the "nothing samples it" claim is now proven, not assumed** — `densityTexture` appears at exactly four sites (`renderer.mm:288, 1201, 1209, 2701`) and the only binding is `[comp setTexture:]`, a compute **write**. No fragment or vertex stage ever reads it. Dispatch is gated on `collisionsEnabled`, which ships `false` (`:277`). ✅ **All four facts written into the kernel header 12:31:44; NOT deleted** — it is free while gated off, and deleting a collisions-path kernel is a physics call (cf. the refused scatter cap). | ★ |
| **P8** ✅ | `render.metal:927` (was cited `:941`) | ✅ **CONFIRMED**, and the same block already carries a 2026-07-23 note that the lens was fixed once for being *"measured from the ORIGIN while the hole sits OFF-ORIGIN"* — which, per P6, is a distinction the renderer cannot currently make. | ★ |
| **P9** ✅ | `render.metal:157`, gate at `:1236` | ✅ **CONFIRMED, line exact.** `velDir2D`/`strDir2D`, webbing gated on `screenDist < 0.15f && > 0.002f` in NDC — two particles far apart in depth but adjacent on screen get strung together. | ★ |
| **P10** ✅ | `render.metal:1247`, `out.pointSize` `:1288` (was cited `:1261`) | ✅ **CONFIRMED** — *"The sphere impostor needs ~20+ pixels to read as a 3D sphere."* A painted sphere, not geometry. **Same root as C3** (99.3% of stars at one pixel): an impostor that never gets its 20 pixels is a dot. | ★ |

⚠️ **HYPOTHESIS, NOT A FINDING:** P1 and P2 look like one fact wearing two hats — the
renderer has no per-particle depth, so it can neither order nor shade by distance, and
P3–P6 are the black hole inheriting that. **Unmeasured.** The last through-line asserted
here ("five of six trace to the origin-lock") did not survive a controlled measurement.
🔻 **AND IT PARTLY DID NOT SURVIVE THIS ONE EITHER: P6 fell out of the group at 12:31:44** — it
is an origin-lock row, not a depth row. **P3 is a deliberate deferral with its fix already
written down.** What is left of the through-line is P1+P2 (one fact, two hats) and P4/P8/P9/P10
inheriting it. **Do not quote "ten sites, one cause" — the count is 8 live, and the cause covers 6.**

### H1b. ⭐ P1 IS NOT ONLY A LOOK PROBLEM — IT IS THE BLOCKER UNDER THE MOTION-VECTOR WORK (his question, 2026-08-11)

> *"for the depth thing didn't we start the vector thingy for the blur and such? is that not crucial for it too?"*

**Yes, and it is the tighter argument for P1 than anything in the register.** Traced 2026-08-11 12:31:44:

| Fact | Evidence |
|---|---|
| **C4a's camera blur fakes depth with a literal constant, and says so.** `float4 ndcPos = float4(uv.x*2-1, (1-uv.y)*2-1, **0.99**, 1.0)` — *"we approximate their depth as far-plane (z=0.99) for the optical flow proxy."* Every pixel is unprojected as if it sat on the far plane, so the flow field has **no parallax**: near and far matter get the same velocity. | `postfx.metal:400-401` |
| **It is written that way because there is nothing to read.** Post-FX has **no depth texture bound at all** (`grep depth postfx.metal` → the strobe field and that one comment). The buffer that would supply it is thrown away unread (P1: `storeAction = DontCare`). **The `0.99` is not laziness, it is the only option the current pipeline offers.** | `postfx.metal`; `renderer.mm:3356` |
| **C4b is blocked on P1 outright**, and the board already said so without connecting it to §H: *"additive blending with depth-write off means nothing decides which particle OWNS a pixel's vector."* | C4b row, §C |

⭐ **So P1 pays for three things at once, not one:** real occlusion (§H1), a *correct* camera blur instead of a far-plane proxy (**C4a**), and the precondition for per-particle motion vectors and TAA (**C4b**, currently `L` and deferred). **This materially raises P1's value and it is his own observation, not mine.**
⚠️ **Scope note, stated so it is not discovered later:** turning depth writes on is **not one line**. `storeAction` must become `Store`, the buffer must be bound into post-FX, and — the real question — **additive blending and depth writes fight each other.** Every particle that writes depth occludes the ones behind it, which is exactly what we want for solidity and exactly what would kill the additive glow the whole look currently rests on. **That trade is the design decision, and it is his to make.** No design agreed; nothing started.

### H2. ✅ CHLADNI IS **NOT** FAKING 3D — answered from the code, 2026-08-11

`particles.metal:2272`: `pAx = 2 + ((mm + nn) % 3)` — **never 0**, so `kZ > 0` always and
`cos(k_z ζ)` genuinely varies along z. A z-invariant field (a 2D pattern extruded) would
require `pAx == 0`; it cannot be. **Never 1 either, by construction** — `pAx=1` is one
axial node = a flat disk = the "eye" edge-on, which the old `1 + ((m+n)%3)` produced for
exactly low C (m=0,n=3). The axial phase references the cavity **wall**, so the nodal
planes sit inside the can, not on the end faces. The force `-contrast·Ψ∇Ψ` uses the full
3D gradient including `dPdz`.

**If the play state reads flat, the cause is H1 (no depth write, no per-particle depth),
NOT the eigenmode.** Separately still open and NOT a 3D problem: `ridgePull` uses the
**sculpt** gradient rather than eigenmode ∇Ψ, no node dissipation, C = m=0 = circles.

### H3. ✅ FIVE DEAD ENDS CUT — 2026-08-11 04:11:00, bundle 04:15:06

All verified unreachable **before** deletion. App clean, hole forms, **his verdict: stable 60 fps.**

1. **Y-axis time-lapse twin** (`render.metal`, ~45 lines) — `bhDiskAxisY` is `0.0f` at all seven sites.
2. **`bhVisible = false` cull** — constant-false gate whose `length(posW.xy)` ran per vertex anyway.
3. **`Renderer::render(config)`, 240 lines** + header decl — zero callers. **This one was a TRAP, not just bytes: two board claims were read out of it and were wrong about the running app** (hardcoded `cameraPos`; ortho-gated shadow radius after the live path dropped that term).
4. **posePhase host gate** (`renderer.mm:3327`) — the kernel self-gated but still launched 2M threads/frame. ⚠️ **Mirrors `pose_phase_advance` term for term; if the kernel's gate changes, change this one in the same commit** — a stricter host gate silently freezes the phase and nothing errors.
5. **src/core/lut.cpp + lut.h** (paths intentionally unlinked) deleted, out of `CMakeLists.txt`, and **`CLAUDE.md` no longer lists it as "Key File #2"**.

**Perf bought: nothing measurable**, and that was expected — four were never executed.
Control: run D (shader untouched) and run E (shader modified) agree at the same sim age
(render 17.51 vs 19.28 ms). **The value is that the code stopped lying.**

❌ **REFUSED — `spatial_hash.metal:333`, the 32-per-cell scatter cap.** Not dead code — a
**load-bearing design limit**: `cellStarts` is a prefix sum of live counts, so writing past
32 overflows into the next cell, the same star lands in two lists, and **mass is created**
(`Mlive` tripled at 50k dead). Changing it is a physics decision. **The waste is real and
worse than first reported:** ~767,000 threads `atomic_load` **one address** and discard.

### H4. 💰 WHERE THE FRAME ACTUALLY GOES — five runs, 2026-08-11

| Run | Config | Compute | Render+PostFX |
|---|---|---|---|
| A | baseline (n=7) | 22.92 | 7.31 |
| B | star pass not encoded (n=19) | 21.87 | **4.02** |
| C | `SS_SOR_SWEEPS=8` (n=25) | **16.74** | 8.32 |
| D | `SS_SPH_SKIP=density,pressure,force` (n=46) | 15.20 | 15.76 ⚠️ |
| E | after dead-code removal (n=32) | 23.21 | 15.78 |

- **Star pass = 2.4–3.3 ms** (A vs B, the only clean isolation).
- **Coarse Poisson SOR ≈ 6 ms — double the whole star pass.** `renderer.mm:2495` runs **80 sweeps × 2 colours = 160 compute encoders/frame**, each over all **2,097,152 cells**, and `poisson_sor` (`spatial_hash.metal:1173`) has **no empty-cell skip** on a ~99%-vacuum grid. Understated if anything: run C sat at a *denser* state than A.
- ⚠️ **Run D yields no number.** Killing SPH pressure collapsed the field to a different shape (r50 3.83 vs 0.059 sim). What it does show: **fill cost is state-dependent and can dominate** — a separate lead, possibly bigger than §G6.
- ⚠️ **Runs were NOT duration-matched** (A got 10 prints, D got 49), so cross-run compute carries a sim-age confound. **Duration-match the next set.**

### H5. CORRECTIONS TO THIS BOARD

1. **"The hole is hard-gated to ortho" — NO LONGER TRUE.** The `config.orthoMode &&` term was removed from the live path (`renderer.mm:1783`) in the A0 test. The copy that still had it was in `render(config)` — zero callers, now deleted. The perspective **scale** is still wrong (P3).
2. **"SOR disproven as the monster" — I called that off 9 samples.** With 25 the saving is ~6 ms and real. **Read the whole run before writing a verdict.**

### H6. OPEN — first to-dos, revised 2026-08-11 12:31:44 after verification

~~3. P5 comment~~ ✅ **DONE** · ~~C7b~~ ✅ **DONE** · ~~P7 audit~~ ✅ **DONE** · ~~G7 EIGEN_R + GRIDPROBE~~ ✅ **DONE** — all in §H7.
~~P6~~ ❌ **DELETED FROM THE LIST — refuted, the fix is a no-op.** Folded into A3②.

1. **P1 + P2 — real per-particle depth. NOW THE CLEAR TOP ITEM**, because §H1b shows it also unblocks C4a's correctness and C4b entirely. **NO DESIGN AGREED, and the design has a real cost question in it** (depth writes vs additive glow — see §H1b). **His call, not mine. Nothing started.**
2. **P3 — the shadow radius divisor.** Smallest self-contained fix on the board; the correct derivation is already in the comment. **Not done in this pass because it CHANGES THE IMAGE** — it is a verdict item, not a free one.
3. **SOR sweep count** — ~6 ms, one existing knob (`SS_SOR_SWEEPS`). Needs an **accuracy** verdict, not just a perf one.
4. **The fill-cost lead from run D** — unquantified, possibly larger than everything above.
5. **P4** — Ω from a 3D radius. Changes disk motion → verdict item. Note it is gated OFF while he plays (§H1).

## 🎞️ THE TRAIL/SMEAR SESSION — 2026-08-20. THE RIBBON PASS IS DELETED.

**His verdict, 2026-08-20 15:02:51, on the thickness test:** *"this provers the trail theory dead ... its the
wrong approach."* Then, 15:06: *"pls turn trails off default delete the fucking code and put it 6 feet under lol."*

⛔ **DELETED, NOT DISABLED:** `TrajOut`, `trajectory_vertex`, `trajectory_fragment` (~370 lines), the
`trajectoryPipeline` and its creation block, the draw call, and the two UI controls that had just been added for
it. A headstone comment sits at the old site in `render.metal`. Code survives in git at `5ee213d`.
**Four fixes were tried on that pass in one session and the look survived none:** width conservation, the S7
luminosity term, the orbital plane, and finally a real pixel thickness. At 1 px it read as hair; widened, as
slabs. **A million separate strokes with gaps between them is what hair IS** — that is the mechanism, and it is
why no per-stroke fix could ever land.

🔨 **WHAT REPLACED IT, UNVERDICTED:** a screen-space motion smear.
- The star pass now writes a **second render target** — screen motion of the matter — from `velReal + spin`
  projected through the **current** `viewProjection` at both ends, so camera motion cancels by construction and
  rotating the camera cannot move the smear. `render.metal` `particle_fragment` → `ParticleFragOut`.
  ⛔ **CORRECTED 2026-08-26: it is FOUR masked draws, not five.** Five pipelines declare attachment 1
  (`renderer.mm:696, 751, 787, 827, 859`) and the first of those IS the star pass, which writes it; the other
  four are masked (`:752, :788, :828, :860`). Blending is OFF on it: a velocity
  is a value, not light, and summing two stars' velocities points somewhere neither travels.
- `postfx.metal` smears the PICTURE along that buffer. Two dials: **Smear length** (default 24), **Smear hold**
  (default 1.0 = band keeps its colour, which is what makes a stretch read as a band and not a blur).
- 🚨 **KNOWN BUG, DIAGNOSED FROM HIS 15:32:18 SCREENSHOT, NOT FIXED:** 48 taps spread over a several-hundred-pixel
  band land **5–8 px apart**, so each star repeats as separate beads and *more* length makes it *worse*. The fix
  is a **multi-pass doubling smear** (≈6 passes), not more taps. His verdict: *"soemwhat thius is even worse than
  the other approach."*
- ⚠️ With the ribbons gone the field is much darker. Whether the smear can ever look like the reference may
  depend on the sub-pixel dot brightness first (`render.metal:1552` floors sprite size at 1 px and compensates
  only when a sprite is too BIG, never when it is too small).

**His reference for the target look:** the Photoshop *circular pixel stretch* (adobe.com/de/learn/photoshop/web/
circular-pixel-stretch-effect) and the three light-band reels sent 2026-08-20. Every pixel becomes a contiguous
band; there are no gaps because the IMAGE is stretched, not the objects.

---

## 🚨 A. BLOCKERS — nothing downstream is trustworthy until these settle

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| → **BH rows moved out** | 🕳️ **A1, A1‴, A2, A3①, A3②, A3②-white, A3③, A5, A6, A8 and MERGER-FACE now live in `docs/BOARD_BLACKHOLE.md` §N2** (moved 2026-08-19 00:14:12, verbatim). What stays here is not-BH. | — | — | — |
| **TUBE-AND-SPHERE** 🚨⭐ | 🚨 **HIS STANDING COMPLAINT, RESTATED 2026-08-13: "two things still piss me off. THE TUBE + THE SPHERE THAT IS OUR SPACE."** They are two hard-coded radii eight lines apart, and the space **breathes between them with the envelope**, which is why he sees both. **① THE TUBE = `ORBIT_R_CHLADNI = 6.0f` (`particles.metal:309`)** — during attack/decay/sustain the cap goes **cylindrical in XY** (`playCap`, `:3138-3141`): *"PLAY: cylindrical (XY) cavity — the tube is the instrument's shape."* That is the tube, stated in the code's own words. **② THE SPHERE = `STAR_MAP_CAP = 100.0f` (`:310`)** — at silence a **true 3D radial wall** at `capR` kills outward velocity (`:3178-3184`, *"a sphere — no flat wall, no free axis"*). **The transition is a `mix()`**: attack lerps the cap 100 → 6 as `envelopePhase` crosses 0.5→1.5, so playing literally squeezes the universe from a 100-sphere into a 6-tube and releasing lets it back out. **⭐ MEASURED, NOT INFERRED: this session's logs show `maxR=100.0` — matter sitting EXACTLY on the wall**, which is what a hard cap looks like from the books. (Plus `+8` of slack while spinning, so the true wall is 100–108.) 🚨 **AND THE COMMENT LIES — third sighting of the family:** `:310` reads *"silence: NO cap (the star map has no tube limit)"* on the line that DEFINES the cap. See COMMENT-IS-NOT-A-MECHANISM. ⭐ **This reframes B7/KILL-THE-TUBE: the tube is not only an emergent shape from the cavity physics, there is also a LITERAL cylindrical clamp on the position update.** Any kill-the-tube work that only touches the eigenmode forces and leaves `:3141` alone will not kill it. **Not costed as one job — the tube and the sphere are the same mechanism at two radii, and removing a confinement without a replacement lets the field evaporate (see LIMITS-ARE-PERCEPTUAL: the answer is a better boundary, not a bigger number).** | ⬜ **NEW — mechanism located, both radii named, nothing changed** | `particles.metal:309` (tube R=6), `:310` (sphere R=100 + the false comment), `:3138-3145` (the `mix` that breathes), `:3178-3184` (the 3D wall); `maxR=100.0` in `/tmp/killtube_a1pp.log` | **L** (it is B7) |
| **ETERNAL-ECHO** 🔊 | 🔊 **HIS ASK 2026-08-13, EXPLICITLY LOW PRIORITY: "an infinite echo of our self-oscillation — a resampled eternal echo through the stars and their resonance. the biggest Roland tube delay ever."** Sits in §D audio, next to EVERY-PARTICLE-IS-A-VOICE. **What makes it ours rather than a plugin: the delay times must be DERIVED FROM THE FIELD, not dialled.** The sim already carries the candidates — orbital period at radius r, the eigenmode frequency (the Chladni α is already in Hz), the light-travel time across the cavity, the viscous timescale the accretion bound is built on. A tap per shell, feedback set by how much matter is still resonating, and the echo slows and reddens as the field collapses — **the delay becomes a readout of the physics instead of a effect on top of it.** *"Resampled"* is the important word: each pass should be re-rendered through the field's current state, not replayed from a buffer, so a note you played four minutes ago comes back changed by what the stars did since. 🚨 **GATED ON D6** — anything that touches the audio path inherits the RT-safe command-path problem (`synth.cpp:90`, the blocking lock), and a feedback network is the worst possible thing to put behind a mutex on the audio thread. **Do D6 first or this is a stage dropout with extra steps.** ⚠️ Design only, zero code, his own priority call. | ⬜ **NEW — captured, low priority, his order** | `docs/DESIGN_2026-07-28_field_sonification.md`; D6 row + `docs/DESIGN_2026-08-10_d6_rt_safe_command_path.md`; α-in-Hz from the CHLADNI-AUDIT row | **L**, deferred |
| **GRID-IMPRINT** ⏸️🚨 | ⏸️ **TWO FIXES SHIPPED, SYMPTOM UNCHANGED TWICE, DIAGNOSIS FAILED. DEMOTED BY HIM 2026-08-13 02:48: *"fuck it low prio."*** **THE SIGHTING (unchanged, still real):** 2026-08-13 01:21:36, at 64× holding a low C — *"you see the grid, the boxes"* — sharp axis-aligned rectangular domains across the whole field, plus a horizontal equatorial seam. Screenshots 01:21:36 and 02:40:56. **WHAT I SHIPPED AND WHAT IT DID:** ① `particles.metal:1610`, the COARSE PM ∇Φ read, was nearest-cell — truncating int cast, gradient evaluated on that ONE cell, so every particle in a 128³ cell got the IDENTICAL acceleration. Made trilinear (CIC-matched, 8 cell centres, −0.5 shift). **His verdict: "unchanged".** ② `particles.metal:2101`, the AMR FINE ∇Φ read — the same nearest-cell mistake, and `gacc = mix(gacc, gaccFine, w)` with **w = 1 inside 75% of the fine box** makes it AUTHORITATIVE in the core, which is exactly where the blocks are, so fix ① was masked wherever it mattered. AMR is ON by default (`renderer.mm:1896`). Made trilinear too. **His verdict: "still there".** ⭐ **KEEP BOTH ANYWAY — they are real defects independent of this symptom.** Mass is deposited **CIC** and the force was read back **NGP**; in a particle-mesh code the deposit and interpolation kernels MUST match or you get grid imprinting, self-forces and momentum error. The codebase already knew the pattern — density and flare read trilinear at `:1175`/`:1184`, and that comment calls trilinear *"the alias-free pattern"*. Gravity was the one site that skipped it, twice. **Measured cost: none detectable** — 33.9–35.2 fps after, against ~31–36 before, worst frame ~50 ms both. 🚨 **RULED OUT: the coverage-resolve postfx.** `postfx.metal:213` is a pure PER-PIXEL Beer-Lambert factor — no tiling, no neighbourhood sample — so it cannot produce blocks. Ruled out **by inspection, not by an A/B**; `SS_NO_COVERAGE=1` would settle it in one relaunch if anyone doubts it. ⭐ **THE NEXT STEP IS ONE OBSERVATION, NOT CODE — do not write another line until it is answered: ORBIT THE CAMERA while the boxes are visible.** **Rotates with the field** ⇒ the structure is in the MATTER, world-space, physics — and the next suspect is the near-field 3×3×3 centroid sum, which treats each cell as a point mass at a centroid whose sample count **caps at 32**, a per-cell biased force in exactly the dense regime a held note at 64× creates. **Locked to the screen** ⇒ it is the RENDER and every physics change is orthogonal. **Why his screenshots cannot settle it:** the default camera sits at `(0,0,ρ)` on the +Z axis (`camera.h:31-32`), so a world-space XY lattice and a screen-space tiling project IDENTICALLY. Orbiting breaks the degeneracy. ⚠️ **Alternative that needs his hands once:** get it into the boxy state, then `SS_DUMP` + `SS_DUMP_TICK` writes the particle buffer — if the positions carry no block structure, it is the renderer, settled without a single guess. ⚠️ **METHOD FAILURE TO NOT REPEAT — mine, twice in one hour:** I declared a class of bug fixed after grepping ONE symbol (`phi[`) when there were two reads (`finePhi[` as well); then, having found the second, I assumed the pair of them explained the symptom and shipped again without a way to see the result. **Two builds against an unverified diagnosis. The orbit test costs five seconds and should have come first.** | ⏸️ **deferred by him — 2 fixes shipped and KEPT, symptom UNFIXED, diagnosis open** | `particles.metal:1610` + `:2101` (both now trilinear); `renderer.mm:1896` (AMR default on), `:2349` (SOR rest-only), `postfx.metal:213` (ruled out); his screenshots 01:21:36, 02:40:56 | **S** once the orbit test picks the branch |
| **DEAD-COMPUTE** 🚨⭐ | 🚨 **HIS ORDER, 2026-08-13 01:02:00: "PARTICLES THAT ARE DEAD MUST NOT BE COMPUTED. if a particle is in the bh its gone. no need to compute it and we still do."** **GROUNDED, and it is true:** a swallowed particle is parked at `4000 + id%1024` with `posW.w = 0` by both the capture path and the seed↔seed merge, and **nothing in `compute_physics` returns early for it.** A corpse walks the entire kernel every frame — resurrection block, PM gravity, the 3×3×3 near sum, SPH, AMR, collisions, capture scan. The kernel's own comment at `:678` measures the pile: **"~46% of the current field is dead"** (godray diff: 0%). At 2M particles that is ~920,000 threads doing full physics on matter that is gone — and it lands on the frame he says drops to the lowest fps. ⚠️ **IT IS NOT A PLAIN EARLY-OUT, AND ANYONE WHO WRITES ONE WILL BREAK THE INSTRUMENT.** The corpses are the raw material for two live features: **sustain rebirth** (`:720`, `bhToggles & 0x40`, gated `mass <= 0.001f && streamNow` — it fires ONLY on dead particles) and the slow rest trickle. Both need dead particles visited. **Shape of the fix: hoist the revive test to the top of the kernel and `return` immediately after it** — a corpse pays for the revive check and nothing else. That keeps the abyss refillable and skips ~46% of the physics. ⭐ **Also the honest perf frame: this is the first optimisation on the board that removes WORK rather than resolution or particles** — it cannot cost him a single visible star, so it does not touch the LIMITS-ARE-PERCEPTUAL rule. | ✅ **SHIPPED 2026-08-13 12:56:01, bundle `12:56:01` — UNVERDICTED.** ⚠️ **TWO CLAIMS IN THIS ROW WERE WRONG AND ARE CORRECTED BY THE CODE:** ① *"a corpse walks the entire kernel"* — **it does not.** Capture (`:1299`), seed-merge (`:1448`), self-gravity (`:1606`) and collisional relaxation (`:2211`) all gate on `mass > 0.001f` and already refuse it. What a corpse DID still run is the three scans that are **not** mass-gated: particle-particle collisions (`:2685`, 27 cells), the bond network (`:2842`), and the SPH pressure scan (`:2932`, O(N·27)) — two of them gated `playGate < 0.5`, i.e. **they run AT REST**, the same regime as the ~46% corpse count and the 31–36 fps idle baseline. ② *"parked at 4000+ and NEVER comes back"* — **true for exactly one frame.** ESCAPER RECYCLE (`:1131`) tests `r_curr`, which is still the ENTRY radius from `:862`, and the park site sits at r≈6928 > 1000 — so the frame after it dies every corpse is teleported to its **star-map home** at mass 0 and frozen there (its position never changes again, because the write-back `:3427` is gated `mass > 0.0f`). **The abyss is not a pile at 4000; it is ~46% of the field sitting invisible at their home radii, interleaved with the living.** Invisible is confirmed, not assumed: `render.metal:715` clips `mass < 0.001f` behind the near plane at pointSize 0. **THE FIX:** `if (mass <= 0.001f) return;` at `:1156` — **below** revive, reset and the recycle, so all three still fire. Output-equivalent by construction: the write-back is already mass-gated, every atomic in `:1156-3425` (seedAccum, accDiag, sphClosure) sits inside a mass-gated block, and a corpse writes to no other slot. **UNVERIFIED: the fps delta. I cannot play it.** | `particles.metal:1156` (the return), `:1131` (recycle, the reason for the placement), `:704`/`:829` (revive + reset, the two features above the cut), `:2685`/`:2842`/`:2932` (the three scans removed), `render.metal:715` (corpses invisible) | **M** |
| **A4** | 🔨 ✅ **CLOSED 2026-08-22 22:04:16 — SHIPPED AND IN DAILY USE. It was never actually waiting on anything.** His words: *"uve been going mad over 2 3 points on the board that dont even require it … something that wasnt seen yet although ive been working with it for a week now."* He is right. It has been live in every session since it was built and he has reported plenty of other faults in that window. ⚠️ Closed as **shipped, no complaint recorded** — NOT as measured-correct. Do not re-park a built row on his eyes; if it were wrong he would have said so. *(Fix built and deployed 2026-08-10 15:12:02; parked 12 days.)* ⭐ **THE DOMINANT TERM WAS NOT THE FRICTION SITE.** This row led with `:780` (friction `pow(0.9,dt)`→`pow(0.95,dt)`); measured, that is a **0.09% per-frame** change in velocity decay. The real discontinuity is the **sustain crystal lock (grep `lock = mix(1.0f, 0.05f, hardness)`, `:2794` as of 15:17:00): a 95%-per-frame velocity kill that stopped dead in ONE FRAME at the 3.5 boundary.** Matter being scrubbed to a standstill every frame was abruptly free, and the standing forces expressed at full strength over the next few frames — **that ramp-up from frozen to moving is the "split sec" jump he described.** 🚨 **Compounding it: `hardness` KEEPS INTEGRATING UPWARD through release** — the crystallization gate at `:2645` is `envelopePhase > 2.5`, true in release too — so the state hardened while its only consumer was disconnected. **Fix = a ramp across the boundary, no new branch:** the release branch now carries the same lock, eased out by `envelopeProgress`. `t=0` → identical to the sustain lock; `t=1` → `1.0`, matching silence. **Continuous at BOTH edges.** Untouched: `:780`, `:664`, `:839` — if the jump survives, those are next, in that order. | ✅ shipped 2026-08-22 22:04:16 | fix at `particles.metal:2758-2785`; cause at `:2771`, `:2645`, `:2655` — verified **2026-08-10 15:11:00** | — |
| **A7** | ❌ **PREMISE NOT SUPPORTED — STACKED ACROSS 4 RUNS, 2026-08-10 15:45:00.** This row generalised from ONE run, which is the thing this project bans. Quarter-mean FPS, first quarter → last quarter: `A2_refund_20260809_110828` **56.2 → 35.1 (−38%)** · `A2_refund_20260809_202105` **38.6 → 44.0 (+14%, it got FASTER)** · `A2_refund_20260810_090652` **59.1 → 54.2 (−8%)** · `A2_refund_20260808_181210` **46.5 → 45.8 (−2%)**. **Three of four show no meaningful degradation and one improves.** ⭐ **Live confirmation the same day: pid 6225 ran 41 minutes and was sitting at 93 fps** when he screenshotted it — because the field had been consumed and there was almost nothing left to draw. **FPS tracks how much is ALIVE, not how long the run has been going.** ❌ **My overdraw hypothesis is REFUTED too** — I predicted drawn pixel size grows with heating. `[KPROBE-SCALE] meanPx` grows only in the −38% run (1.01 → 4.77); it is **flat at ~1.00–1.06 in the runs that stayed fast**, while plasma temperature climbs to ~5×10¹¹ K in **all four including the flat ones**. So heating is not the driver and pixel growth is not general. ⬜ **WHAT ACTUALLY REMAINS OPEN: why run 1 specifically.** It is the only run with both the decline and the `meanPx` spike, so those two are worth treating as one question rather than two. **Do not re-open this as "FPS degrades over a run" — that framing is now measured false.** 🚨 The row's one durable point survives untouched: **`dt` is per-frame (`renderer.mm:1339`), so whatever DOES cost FPS silently slows the physics** — see [[feedback_trust_the_average_not_transients]]. | ⬜ **narrowed, premise refuted** | 4 logs stacked, `logs/A2_refund_*`; his screenshot 15:52 (93 fps on a consumed field) | **S** (run 1 only) |

## B. PHYSICS — measured, not acted on

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| B1, B9 | 🕳️ **Moved to `docs/BOARD_BLACKHOLE.md` §N3** — horizon-test-on-mass and the merger flash. | — | — | — |
| B2 | `RADIAL_MAX_R = 5.0` hard cutoff — the seed wanders outside the measuring window entirely | ⬜ | `particles.metal:300`; guard at `:3814` | **S** |
| B3 | **bit4 origin-pin — PREMISE RE-OPENED 2026-08-07 12:41:25.** The spring exists (a bounded pull on any body ≥ 50 M☉ toward `(0,0,0)`, gated off during play) — but **it ships OFF** and only the UI checkbox or the `SS_INERT_KEEP` ladder can enable it. So in the default launch config it is **not** what blocks multi-BH; the unconditional ORIGIN LOCK (A3②) is. Inherited from 08-04 §4 and not re-derivable from the code as written. **Re-establish what this row is for, or fold it into A3② and close it.** | ⬜ premise unverified | `particles.metal:1170` the spring; `app_state.h:48` `= false`; `main.cpp:2135` the pack, `:1260` the checkbox, `:270` the ladder | **S** to settle, then **?** |
| B10 | **DENSITY PRESSURE — an unfinished TODO, not a decision.** Disabled with *"TEMP DISABLED for Step 1 verification… **Re-enable in a later step** after we have orbital dynamics holding particles in place."* That later step never came. It was overpowering gravity (pressure scale 12 vs gravity scale 1) and blowing the Gaussian spawn outward. ⚠️ **Do NOT simply switch it on: it OPPOSES collapse, and A1 needs collapse.** Settle A1 first, then decide whether this is revived at a sane scale or deleted. | ⬜ **NEW** | `particles.metal:863` `if (false /* su.gridSize > 0 */)` | **M** |
| B4 | Pull-gate step 2 | 🚫 | blocked on B3 | **M** |
| B5 | The −280 M☉ residual drift (wall/park exclusion) | ⬜ | not re-verified — from 08-04 §1 | **S** |
| B6 | **Corpse compaction.** 64% of the buffer was corpses; every compute dispatch is 2,000,000 threads regardless. In **direct tension** with `imfMassOfId(id)` requiring that particles never change slots — the refund depends on that property. Needs its own session. | ⬜ | `particles.metal:131` `imfMassOfId`; measurement from 08-07 §3 | **L** |
| **B7** ⭐🚨 | **Kill the tube** — *"figure out what the actual truest form of soundwaves in 3d space is."* The cylindrical clamp is the symptom; the Bessel `J_m` basis is the real work. His own prior design (3D scalar ψ, damped wave PDE) is the starting point. 🔺 **PROMOTED 2026-08-11 — HIS CALL, AND IT NOW BLOCKS THE DEPTH TRACK.** After §H10 landed a working, measured depth cue that the star map reads clearly, **the Chladni play state still reads flat**, and his verdict names this row: *"still unchanged feel in chladni mode but im sure our tube limitation is to blame for that."* ⭐ **The eigenmode is EXONERATED and that is settled** — §H2 proved `pAx` is never 0, `k_z > 0` always, and the force carries a real `dPdz`. So the z-structure exists in the physics and something downstream flattens it. **The cylindrical clamp (`particles.metal:3051` XY cap → `ORBIT_R_CHLADNI`, plus the `zCap` at `:3074`) is the standing suspect.** ⬜ **NOT DIAGNOSED — do not start the rewrite on a hunch.** The cheap first move is a MEASUREMENT: report the play-state depth distribution along the view axis (the `[DISKZ]` machinery already computes `H = sqrt(<z²>)`) and compare it to the star map's. If play-state depth spread really is collapsed, this row is confirmed as the cause and the `L` rewrite is justified; if it is not, the flatness is elsewhere and the rewrite would have been wasted. **Measure before rewriting.** | ⬜ **live suspect for Chladni depth** | 08-04 §6.8 · `space_synth_neo_architecture`; clamp at `particles.metal:3051`, `:3074`; §H10 | **L** (measurement first: **S**) |
| B8 | **"Start sequence / launch grid"** — he named these as needing fixing and never said what he meant. | ⬜ | 🚨 **ASK BEFORE TOUCHING** | **?** |

---

## C. VISUAL ENGINE — his stated priority (*"we follow paragraph 9"*, 2026-08-02)

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| C1 | Bloom → mip pyramid | ✅ | `postfx.metal:547` — *"this bloom is looking a lot better"* | done |
| C2 | Grade LUT stage, 33³ RGBA16F after the live tonemap | ✅ built + approved, now committed | `postfx.metal:361` samples it; `renderer.mm:811` uploads it; `:3884` binds it; `:3919` same grade on the Syphon feed. ⚠️ **ADDED stage — the live tonemap is NOT ACES, never replace it** | done |
| **C7** | ✅ **DIAGNOSED 2026-08-08 01:30:58 — and it is not a colour bug.** The radial Cartwheel law **already exists and is correct**: Shakura–Sunyaev `T ∝ r^(−3/4)`, `render.metal:1667`, written 2026-07-23. It is **gated on `cam.horizonR > 0`** — and `r_h` measured **`0.0000` for the entire pre-runaway life of every run logged**. It only goes positive once A1′'s runaway is already eating the field. ⚠️ **"EVERY RUN" IS TOO STRONG — corrected 2026-08-08 16:31:44 while measuring A3③.** Share of `[HORIZON]` samples with `r_h > 0`: soak **474/6,975 = 6.8%** · seed 7 **120/125 = 96%** · `A1fix_CAS` **1,529/1,534 = 99.7%**. The soak is the outlier, not the rule — in two of three logs the gate is open within seconds of spawn and **stays** open. Since it is realization-dependent (seed 7 is pre-fix too, so this is the known nondeterminism, not the A1′ fix), **C7 may be workable now without waiting on anything.** Re-measure before treating this row as blocked. 🚨 **So the window where the Cartwheel look is possible is exactly the window where the field is being destroyed. C7 is downstream of A1′ and cannot be worked independently.** Pre-horizon, colour is `unifiedKelvin(mass, heat, kinetic)` — no radial term exists, so it *cannot* organise by radius. The surviving half-space is **beaming on LUMINANCE** (`:1307`, `K_BEAM=0.8`), the only line-of-sight term left; ⚠️ that it reads as *colour* via bloom is a hypothesis, testable with `DOPPLER_K_BEAM=0`, **needs his eyes**. Doppler-as-hue was removed 2026-06-26 on his verdict — **never re-propose it**. | ⬜ 🚫 gated on A1′ | `docs/MEASURED_2026-08-08_C7_cartwheel_colour.md` | **S** *(after A1′)* |
| C7b | ✅ **DONE 2026-08-11 12:31:44 — bundle `12:06:17`.** `dopplerColor` was declared, assigned once, and **never read**, while a comment claimed *"the REAL relativistic Doppler shift is already applied above via dopplerColor"* — **false, and it meant the board believed a colour Doppler shift existed when none does.** Deleted the variable, its assignment, and **`DOPPLER_K_COLOR`, which had no other consumer**. Comment rewritten to state what is actually applied: **relativistic BEAMING on luminance (`DOPPLER_K_BEAM`), unchanged.** Survivor grep per the H3 rule: `DOPPLER_K_BEAM` and `out.luminance *= pow(beam, DOPPLER_EXP)` both intact; all remaining `dopplerColor` hits are comments. 🚨 **Standing consequence: NO colour Doppler shift exists anywhere in the renderer.** Doppler-as-hue was removed 2026-06-26 on his verdict — **never re-propose it**; this just makes the code agree with that decision. | ✅ **built, pixel-neutral by construction, UNSEEN** | `render.metal` (grep `C7b`) | done |
| **C3** | **Star size floor** — 99.2% of stars pinned to one pixel. Nothing pre-FX can look cinematic until this moves. | ⬜ | `render.metal:1246` `out.pointSize = drawn`; `:1916` the clamp. 🚨 **BUILD THE DIALS FIRST** — 4 attempts, 0 progress, all reverted | **L** (was `M`; corrected on the 4-attempt record) |
| C8 | **Chladni sharpness** — *"almoooost."* Standing physics finding: `ridgePull` uses the SCULPT gradient, not the eigenmode ∇Ψ, and there is no node dissipation. This is a physics fix, not a postfx one. | ⬜ | `space_synth_chladni_alpha_is_hz_2026-07-28` | **M** — 🚨 **ask what "sharp" means numerically first** |
| **C4a** | **Camera motion blur — BUILT, DISABLED, bug diagnosed.** `prevViewProj` is fully plumbed and a screen-space velocity is computed **every frame**: unproject through `inverseViewProj`, reproject through `prevViewProj`, difference the UVs. The consumer is switched off behind **`if (false && velLen > 0.002)`** — the **second `if (false)`** on this board. **Why:** it dimmed the glow when the camera moved (his *"FX bug out / glow turns off when I move the camera"*). Reading the stage order, the cause is sharper than the source comment says: the block sits **after** the tonemap (`:285`), the grade LUT (`:338`) and the neon/VJ grades, so `color` is fully display-referred — but `:430` samples the **raw HDR** input and runs it through **`acesTonemap`**, which is *not* this pipeline's tonemap. **Two mismatches — graded-vs-ungraded, and ACES-vs-the-real-tonemap — then a divide by N.** Fix = make the samples match the base, do not reintroduce ACES. | 🔨 | `renderer.h:162`; `renderer.mm:343`, `:3866`, `:3871`; `postfx.metal:401-414` (live), `:420` (the `if (false)`), `:432` (the wrong tonemap) | **S** |
| C4b | ✅ **CORRECTED 2026-08-22 22:02:55 — THEY EXIST. This row was wrong.** It said *"genuinely not started"*; the 2026-08-20 smear work built them and nobody updated the row. **Verified in source by me:** `render.metal:2687-2689` declares `ParticleFragOut { float4 color [[color(0)]]; float2 velocity [[color(1)]]; }`, and the star pass writes it into a real `RG16Float` target with **blending off** (`renderer.mm:695-696`, bound `:3702-3705`). Depth is there too and STORED — `depthPrepassTexture`, `storeAction = Store` (`:3830-3836`), gated only by `SS_NO_DEPTH_PREPASS`. ⭐ **So the two inputs TAA / MetalFX / a correct blur all need are already on disk.** 🔴 **What is genuinely missing is narrower and nameable: ONLY THE STAR PASS WRITES VELOCITY.** Every other pipeline masks attachment 1 off — `writeMask = MTLColorWriteMaskNone` at `renderer.mm:746`, `:777`, `:814`, `:841` — so the BH march, background and disk contribute **zero** motion while visibly moving. Also the stored velocity is scaled **per streak exposure**, not the raw frame delta a consumer wants. ⚠️ The old "nothing decides which particle OWNS a pixel's vector" objection is answered by blending being OFF: last write wins, deterministically. | ⬜ | source-verified 2026-08-22 22:02:55; **re-verified in full 2026-08-26 10:4x** | ⛔ **“S–M … it is 4 writeMasks and an unscaled delta, not a build” is RETRACTED 2026-08-26. It IS a build.** Flipping a mask does NOT turn velocity on: `hole_fragment` (`render.metal:3080`), `bhmarch_fragment` (`:3342`) and `dust_fragment` (`:3166`) each return a plain `float4` with **no `[[color(1)]]`** — only `particle_fragment` returns `ParticleFragOut` (`:2735-2738`). Unmasking admits **UNDEFINED data** into the velocity target. ⛔ And it is **THREE** candidate passes, not four: `:828` is `bhBodyPipeline`, the DEPTH-ONLY capture sphere, which must stay masked. ⚠️ Mask line numbers are now `:752, :788, :828, :860` (they moved when the false comments were corrected). ⭐ The consumer is live and is **the SMEAR** (`postfx.metal:264`/`:274`), not the dead camera blur at `:499`; and it reads **0 at rest** because `pixelStretch` ramps with SPIN (`main.cpp:2401`). Full working: board row **G6** in `docs/TODO.md`. |
| C5 | **MEASURED 2026-08-22 17:31:31 — the defect is a MIXED SPACE, not the missing spectrum.** `postfx.metal:169-176` (⚠️ was cited `:170`): `d = uv-0.5; dist = length(d); offset = d*dist*A`, R at `+offset`, B at `−offset`. The **direction is correct** — the pixel-space offset `(offset.x·W, offset.y·H)` is parallel to the pixel-space radius, so do **not** book this as "the CA is elliptical". What is wrong is the **magnitude law**: it multiplies a pixel-space vector by a **UV-space** radius, so `\|P\|/R²` — constant for any honest r² law — instead spreads **×1.000 square · ×1.547 at 3456×2234 · ×2.500 at the show's 2.5:1**. The h-edge/v-edge ratio comes out **W/H** where an r² law wants **(W/H)²** (2.50 vs 6.25 on the wall). Fix is one line: take `dist` in aspect-corrected units. ⭐ Separately still true: 3 taps after tonemap, no spectral model, and it contradicts the blackbody LUT upstream. ⛔ **Dormant by default** — `uiChromatic = 0.0f` (`app_state.h:92`), slider max 0.02, which is a **19.2 px** R-tap displacement at the h-edge on a 3840-wide 2.5:1 drawable (R-to-B separation 38.4 px). | ⬜ | `postfx.metal:169-176` · `app_state.h:92` | **S** for the space fix, **M** for a spectral model |
| C6 | ✅ **DELETED 2026-08-22 17:44:00 — his order: *"forget scanlines delkte it"*.** Gone from all 8 sites: the shader block (`postfx.metal:500`, now a headstone carrying the measurement), the `Scanlines` slider + tooltip (`main.cpp`), `config.scanlineAmount` (`renderer.h`, `renderer.mm`), and `uiScanlines` (`app_state.h`). 🚨 **The uniform slot was KEPT as `postPad0`, deliberately** — see C12; removing the float would have moved the matrices on the CPU side only. **Why it could not be saved, measured before deleting:** `resolution` is BACKING PIXELS, so at a fragment centre the argument was exactly `π(row+0.5)` and `sin` returned `(−1)^row` — `line` was exactly 0 or exactly 1 and **never between** (0 of H rows in (0.01,0.99) across H = 1080/1440/2160/2234/1537). Period 2.000 px, **0.5000 cyc/px, f/f_N = 1.0000** — ON Nyquist. ⛔ **A prefilter cannot fix that** (exact per-pixel area-average still keeps **0.6366** amplitude at f=0.5), so **no softness dial was ever possible** — only two values existed. It also cost **30% of the light** at full dial and moiréd on any resample. If it ever returns: fixed LINE COUNT, period ≥ 4 px, amplitude carrying the sinc. | ✅ | `postfx.metal:500` headstone · built + verified `strings` → 0 hits | **done** |
| C9 | `bit18` flux-conserving arc **has never executed** — `sL ≡ 1.0` for every particle since it was written 2026-07-24 | ⬜ | `render.metal:1158` says so in the source comment; `:2233` confirms the downstream branch is a no-op | **S** to delete, **M** to revive |
| C10 | 32 build warnings → zero. `render.metal:485` is the one real one. | ⬜ | not re-counted this session (would require a rebuild). 🚨 **never delete `ssDiskTempShape`** | **S** |
| C12 | ✅ **FIXED 2026-08-22 22:29:24.** One `float postPad1;` added to both mirrors of `PostFXUniforms` → 28 scalars = 112 B, so MSL and C++ land `inverseViewProj` at the same offset without depending on implicit padding. Guard added in this repo's existing `CameraUniforms` style (`renderer.h:333-345`): `sizeof == 240` + `__builtin_offsetof` anchors at 16 / 104 / 112, identical in both files. **Verified both directions:** real asserts compile; the old 236 / 108 values FAIL the Metal compile. | ✅ | `renderer.h` + `postfx.metal` guard blocks | **done** |
| C11 | Rick-and-morty eyes — start from his name for it | ⬜ | my bit20 theory is dead, **do not re-pitch it** | **?** |

---

## D. AUDIO — design complete, **zero code written**

Confirmed this pass: `grep -rln "sonif\|perParticleVoice\|fieldVoice" src/` returns **nothing**. The track is genuinely at zero.

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| **D6** | 🚨 **The RT audio path takes a BLOCKING lock — and it is FIVE sites, not one.** ⚠️ *This row was WRONG until 2026-08-10 10:26:00: it cited `synth.cpp:90` and described a single lock. Line 90 is the opening brace; the lock is `:91`. Corrected by the audio window (`airy-71`), re-verified here by reading the file.* **All five `queueMutex_` sites:** `:91` RT, swap (cheap) · `:138` **RT again, SECOND blocking take in the SAME callback**, and it does `commandQueue_.insert(commandQueue_.begin(), …)` — an O(n) front-shift **under the lock, on the audio thread** · `:148` main/render, swap · `:162` `noteOn` and `:175` `noteOff` — **both hold the lock across a `std::sort`** of up to 256 elements. **So the RT thread can block on a lock a UI thread is holding across a sort, twice per callback.** `noteOn`/`noteOff` have 7 call sites in `main.cpp` (`:177, :181, :477, :481, :509, :514, :2046`). The voice mutex at `:99` is correctly `try_to_lock` with the comment *"never blocks the RT thread"* — `queueMutex_` has no such protection, and repo-root `CLAUDE.md` already states the convention it breaks: *"Lock-free only between audio and render threads."* Live path proven, not assumed: `audio_engine.mm:59` → `:80` → `processBlock`. 🚨 **AND IT CAN `malloc` ON THE AUDIO THREAD.** The 256 cap is enforced **only** in `noteOn` (`:163`) and `noteOff` (`:176`). **The insert at `:139` has no size guard at all.** So the main thread may refill `commandQueue_` to 256 (the guard permits it), then `:139` prepends up to 256 more from `swapBuffer_` → ~512 elements into a vector whose capacity may be far less → **reallocation, i.e. `malloc`/`free` inside the CoreAudio render callback, while holding a mutex.** The intent it defeats is written three lines from the declaration — `synth.h:110-111`: *"Pre-allocated swap buffer (avoids RT heap alloc)"*. ⭐ **And it is weaker than that comment implies: there is NO `reserve()` anywhere in `synth.cpp` or `synth.h`** (verified 2026-08-10 10:31:00) — "pre-allocated" describes only the swap idiom's capacity reuse, so the capacities are whatever grew organically. That makes a realloc at `:139` **more** likely, not less. ⚠️ **Honest bound:** this needs the voice `try_lock` to be missed **and** the queue near-full in the same block — worst case, not typical. But worst case is the entire point of D6, and this one stacks **a heap allocation, a mutex, and an O(n) shift in a single instant inside the callback.** **The only item on the board that can take down a live show.** Sizing `S` probably still holds; **the fix is not one line.** | ⬜ | `synth.cpp:91, 138/139, 148, 162/163, 175/176` vs `:99` (try_lock, correct); `synth.h:110-111`; **no `reserve()` in either file** — all re-read **2026-08-10 10:31:00** | **S** |
| ~~D3~~ | ✅ **MEASURED 2026-08-08 01:18:15 — N ≈ 250,000** at a safe 10% GPU share; 500k at 25%; **2M is NOT feasible** (63–67% of the audio block). §8's fork resolves to its **second branch**: group into shape-preserving cells. 🚨 Three findings that change the plan: ① **contention barely matters** — the full 2M sim running alongside cost <10%, so audio budgets against the *audio block*, not the frame ② **hard ~0.5–1.0 ms floor regardless of N** — 1k voices cost the same as 250k, so anything under ~100k wastes the budget for nothing ③ 250k lands on **256 radial × 1024 angular = 262,144**, a natural shape-preserving grid that satisfies §0.2. ⚠️ Ceiling, not a plan: pure oscillator sum, GPU time only, excludes the CPU round trip. | ✅ | `docs/MEASURED_2026-08-08_N_voices.md`; `tools/measure_n/` | done |
| **D7** | **NEXT per §10 step 2: the per-particle voice at N = 1** (the solo path) — synthesise one picked particle from its own state, proving §0.3 end to end. **Needs his ears.** | ⬜ **NEW** | design doc §10.2 | **M** |
| D1 | **Field sonification: every particle is a voice.** pan = θ, amplitude = EMISSION, frequency from GEOMETRY so it is **pausable by construction**; solo = the same law with N=1. | ⬜ **DESIGN ONLY** | `DESIGN_2026-07-28_field_sonification.md` | **L** |
| D2 | ⚠️ v1 binning scheme was **WITHDRAWN.** Read §0.2 of the design doc before anyone re-proposes it. | — | — | — |
| D4 | The law: physics constants must DERIVE from `spacetime.h`. Listener constants (20 Hz pitch floor, 120 Hz localisation limit) are legitimate and separate. **An untraceable number is a bug.** | — | — | — |
| D5 | Measured and ready to use: the disk spans **3.9–4.3 octaves natively**; the 20 Hz rhythm→pitch line falls at r ≈ 14.85, inside `R_DISK = 18`; **2:1 rings = exactly an octave, 3:2 = exactly a perfect fifth.** | — | — | — |

---

## E. UI OVERHAUL — research done, **zero code changed**

Confirmed this pass: `git status src/ui/` is clean and has been across the whole uncommitted period.

| # | Item | State | Cost |
|---|---|---|---|
| **E5** | 🔨 ✅ **CLOSED 2026-08-22 22:04:16 — SHIPPED AND IN DAILY USE. It was never actually waiting on anything.** His words: *"uve been going mad over 2 3 points on the board that dont even require it … something that wasnt seen yet although ive been working with it for a week now."* He is right. It has been live in every session since it was built and he has reported plenty of other faults in that window. ⚠️ Closed as **shipped, no complaint recorded** — NOT as measured-correct. Do not re-park a built row on his eyes; if it were wrong he would have said so. ⚠️ The "UNCOMMITTED" half was ALSO stale — `src/main.cpp` has been committed several times since (`6b923fe`, `ee448e9`), so it was swept in long ago. *(Built 2026-08-08, parked 14 days.)* **His "groundwork" call:** *"Static info in a ui is stupid… this is groundwork everything else builds on."* The **GALAXY / REAL SCALE** block was entirely `BH_ANCHOR` (Sgr A* textbook constants) and **could never move**. Now driven by the sim: hole mass, `r_g`, **measured** horizon, `M(<r_h)` and ISCO period are all live; the scale calibration is marked `[FIXED CAL]` and dimmed; `Spin a*` and ISCO `v` are labelled as not-simulated / mass-independent. Also `%.0f → %.2f` on `Biggest body` — it printed **"50"** for 49.957 M☉ against a threshold of exactly 50.0, so it read as sitting *on* the threshold from frame one. Required publishing `horizonR`/`horizonMassMsun`/`horizonRatio` through `PhysicsStats` for the first time. ⭐ **Look at `sup r_s/r` first — it should move constantly even before a hole exists.** | ✅ shipped 2026-08-22 22:04:16 | `main.cpp` GALAXY block + `:1125`; `renderer.h` PhysicsStats; `renderer.mm:3278` | **S** |
| E1 | NASA / Open MCT-informed UI. 🚨 **SAMPLE AND FLIP, NEVER LIFT** — every number on screen must have a stated derivation. Matching the source exactly means we did it wrong. | ⬜ | **L** |
| E2 | Accent colour **derived from the blackbody locus**, not picked | ⬜ | **S** |
| E3 | 4-level limit ladder (yellow→orange→red→purple); numeric typeface as its own role; numeric/tabular → fixed-width, narrative → proportional; stale data must be indicated | ⬜ | **M** |
| E4 | ⚠️ **Stale-bundle trap:** indigo hover states in a running app mean you are looking at an orphan bundle, not the code | — | — |

---

## 🕳️ C12. DOPPLER → MOVED to **`docs/BOARD_BLACKHOLE.md` §N4** (2026-08-19 00:14:12, verbatim) — it is disc beaming, and §4b there already carries the honest beaming law.
---

## STANDING RULES THAT OUTLIVE ANY ITEM

- **Build:** `bash package_macos.sh`. **Never bare `make`** — it writes `build/` and does not touch
  the bundle the app actually loads. "My change did nothing" → **suspect a stale binary FIRST.**
- **Launch:** `open -n SpaceSynth.app`, never the raw binary (no LaunchServices registration ⇒ no
  window; it looks alive to `pgrep` and he sees nothing).
- **Never hand him a test without first confirming its precondition holds.** This is what burned a
  night at 64× on 2026-08-06.
- **Time warp does not buy the sim more time to accrete.** It buys bigger jumps between the only
  moments accretion is ever tested.
- **Logs do not survive the scratchpad.** Capture to a real path.
- Commit only on his explicit order.
- 📅 **"CORRECT WHEN WRITTEN" IS NOT A STATE A REFERENCE DOC CAN STAY IN.** Added 2026-08-10 10:28:00 after the *same failure appeared three times in one morning*: (1) A0a/A0b cited a real `file:line` that was **dead code**; (2) the live gate moved `:1749 → :1763` mid-session when a comment block was added above it, invalidating every earlier citation; (3) the audio design doc described a gate that had gained a **fourth condition five days after the doc was written** (`envelopePhase < 0.5`, the play gate). In all three the citation was accurate the day it was written and wrong later, **with nothing in the file to say so.** → **Cite a grep pattern or quote the surrounding line. Where a bare number is unavoidable, stamp it with the time it was verified. Before acting on any `file:line`, re-read it.**
- 🪤 **PROVE THE PATH IS LIVE BEFORE YOU CITE IT.** Check callers; check which overload; check it is compiled into the target. `renderer.mm` contains a **zero-caller near-duplicate** of the live render path (see **A0g**) that shadows it in every grep. The audio window did this correctly — it traced `audio_engine.mm:59 → :80 → processBlock` before writing a word about D6.
- 🔄🚨 **A "NEVER AGAIN" RULE MUST NAME WHAT WAS REJECTED: THE MECHANISM, THE NUMBER, OR THE GOAL.** *(Amendment proposed and accepted 2026-08-11, on his standing invitation to correct these rules.)* **Only the first two can be permanent. A rejected GOAL is never permanent** — it just means we have not built it right yet. **Proof, and it cost seven weeks:** *"Doppler-as-hue was removed on his verdict — never re-propose it"* was written as if the *goal* (relativistic Doppler) had been rejected. What was actually rejected was a **flat RGB tint that read as a 2D filter** — a mechanism. The rule then locked out the correct implementation (shift the TEMPERATURE, not the colour) until he reopened it himself with *"we need it, it's science, we did it wrong."* ⭐ **Audit the other rules of this form against this test** — the bit20 "rick and morty eyes" theory and the POSTFX exoneration are both mechanism-rejections and survive it; check any others before treating them as closed.
- ✅ **A PROVABLY PIXEL-NEUTRAL PASS MAY BATCH; EVERYTHING ELSE IS ONE CHANGE AT A TIME.** *(Amendment proposed and accepted 2026-08-11.)* The one-change rule exists to stop stacking **unverified** work, and it should not tax changes that cannot be wrong on screen. **Batching is allowed only when every item is no-op BY CONSTRUCTION** — comment-only, or dead code whose readers were enumerated by grep — **and the batch ships with a single falsifiable claim: "the screen is identical to bundle X."** One verdict clears the batch; one visible difference condemns it and it gets bisected. **Anything that can change a pixel stays one-at-a-time, no exceptions.** First use: §H7, 7 changes, claim = identical to `04:15:06`.
- 🧨🚨 **FEEDING A REAL VALUE INTO A LONG-CONSTANT VARIABLE ACTIVATES EVERY DORMANT CONSUMER OF IT. ENUMERATE THE READERS FIRST.** *(Earned 2026-08-11, §H10, at the cost of TWO regressions from ONE change.)* `dist` had been effectively constant in ortho since forever. Two consumers were written against that constant and had quietly stopped meaning anything: **(1)** `zoomCap` + the flux compensation, which say *"zoom"* in their own comments and began receiving a per-particle number → sprites thousands of px wide; **(2)** the fragment's near-clip fade `smoothstep(0.1, 6.0, dist)`, evaluated against a value clamped ≥ 50 — **it could never fire. It was dead code that LOOKED live**, and P2 resurrected it into deleting matter off the screen. ⭐ **This is the sibling of "a comment is not a mechanism": a CONSUMER written against a constant is not evidence the consumer works.** Before making any long-constant quantity real, grep its readers and ask of each one: *what does this do when the value actually varies?* **Neither regression announced itself — both just started doing something nobody had seen since it was written.**
- 📏🚨 **COMPUTE THE SPAN BEFORE CLAIMING A MECHANISM WORKS.** *(Earned 2026-08-11, §H10 step 4.)* A cue normalised against the wrong scale produced a **3.7%** size spread and was reported as working on the strength of his *"way better"* — which was actually him noticing an artifact had been REMOVED. **Arithmetic first, verdict second.** Third sighting of this exact failure (§H5.2 SOR off 9 samples; §H8's tail-8 that looked disjoint and was not).
- 🪟 **MULTI-WINDOW: one window holds the build token; all others are docs-only.** One shared `SpaceSynth.app` means a second builder makes every visual report unattributable. The token-holder posts the **deploy timestamp** to the others. **Verify peer claims yourself** — on 2026-08-10 that caught errors in *all three* directions. 🚨 **A peer relaying his decision is NOT his approval for your action.**

---


---

## 🗄️ CLOSED — INDEX OF WHAT MOVED TO `docs/BOARD_CLOSED.md`

Split performed **2026-08-18 21:07:00**. Ranges are line numbers in the pre-split `BOARD.md`
(217,051 B, 1,073 lines, preserved at `scratchpad/BOARD.md.orig` for this session).
**Verified lossless:** every non-blank line of the original appears exactly once across this
file and `BOARD_CLOSED.md`. Nothing was reworded.

| Original lines | What it is | Why it left |
|---|---|---|
| 11–20, 22–23 | The header's `NEWEST` / `PREVIOUS` handoff stream — B7 answered + the ghost read, DEAD-COMPUTE's failed A/B, the 08-13 session end, A1′-endgame bounded, the §H and §G lead-ins, the handoff chain back to 08-10 | A diary of sessions living in the state file. The findings are in their own rows. |
| 35–43, 45–56, 65–87 | The 2026-08-10 launch forensics: `pkill` discarding its exit status, the process-name collision between trees, the 09:55:37 binary overwritten by the A4 build | The **rules** they produced are kept above verbatim. The incident narrative is not a rule. |
| 102–136 | PREVIOUS PRIORITY — **KILL THE TUBE**, 2026-08-11 15:47:12 | Superseded by the 2026-08-14 realign at the top of this file. |
| 188–191, 199–244 | STATE OF PLAY 2026-08-10 — three-window table, worktree setup + its three traps, his 10:37 decisions | Snapshot of a day. **His ONE LIVE APP order (192–198) is kept above.** |
| 382–402 | G1 the inventory · G2 three misalignments | Answered. |
| 427–436 | G5 fixed ratios copied from real black holes (three contradictory spins) | Answered; the live consequence is carried by G4/G6, kept. |
| 443–458 | G7 leftovers · **G8 ✅ capture cull on the raw horizon — shipped** | Shipped. |
| 578–664 | **H7 ✅ the truth pass · H8 ✅ depth write · H9 ✅ coverage resolve (his *"yeah its.. looking good"*) · H10 🔬 P2 in four steps** | All shipped and verdicted. H0–H6 (the register, the Chladni answer, the dead ends, the cost model, the open list) are kept. |
| 670 | **A1′-endgame ✅ BOUNDED** — idle run parks at 101,800 M☉ = 17.1% of the field, flat, 457,421 stars eaten | Closed and measured. |
| 676–679 | **PERF-TELEMETRY ✅** · the **A1″** trio: the fit test bounded on his play run, the gate finally firing, the CAS route | Closed. |
| 681–683 | **A1′ ✅ fixed** · **A1′-cause ✅** (capture radius uncapped above 5000 M☉) · ~~A1′-old~~ | Closed / superseded. |
| 699 | ~~A4-orig~~ — the one-frame release discontinuity as first reported | Superseded by the A4 row, kept. |
| 703 | ~~A7-orig~~ — fps degradation over a run | Premise not supported across 4 runs; the ❌ A7 row that records that is kept. |
| 706–744 | The A1′ 3-run measurement appendix and its method notes | Evidence for a closed row. The two method rules it produced are in the standing rules. |
| 812–1000 | WORKLOAD PER SECTION · DISABLED-CODE SWEEP 2026-08-07 · TRIAGE 2026-08-07 · THE TWO PATHS | Planning superseded by the 08-14 priority. |
| 1060–1073 | This file's own change log | History of the file, not state of the code. |

**What did NOT move, deliberately:** every ❌ / ⛔ dead road, every retraction, every open row,
the standing rules, and the priority. A rejected approach is load-bearing; a shipped one is not.
