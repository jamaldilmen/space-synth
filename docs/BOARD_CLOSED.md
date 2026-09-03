# 🗄️ BOARD — CLOSED AND SUPERSEDED ROWS

**Split out of `docs/BOARD.md` on 2026-08-18 21:07:00.** Append-only. **Not read at cold start.**

This file exists because the board had grown to 217,051 B — roughly a third of a context
window to read once — and ~80% of it by row count was already closed. P4 of
`docs/PROCESS_2026-08-17_workflow_audit.md`, approved by him 2026-08-18.

**Nothing here was reworded or summarised.** Every block is verbatim, in its original order,
with the line range it occupied in the pre-split file. The split was verified line-for-line:
every non-blank line of the original appears exactly once across `BOARD.md` and this file.

**If a row here disagrees with `BOARD.md`, `BOARD.md` wins.** This is history, not state.

---

<!-- ——— archived from BOARD.md lines 11–20 ——— -->

⭐ **NEWEST — 2026-08-13 15:05:00: B7 ANSWERED, THE GHOST READ FOUND AND FIXED, THE CLUMP RUNAWAY STILL UNEXPLAINED.** **① B7-measure is DONE, first read ever during play:** `H/R` = **0.0047–0.071** (inner bins 0.010–0.033) against **0.31–0.84 at silence** — a 10–30× collapse, which is the board's own criterion for *B7 confirmed*. ⭐ `H` is `sqrt(<z²>)` in WORLD space, so the C1 orbit test cannot overturn it: the field genuinely is a sheet during play. **② `[CELLPROBE]` BUILT** (`renderer.mm`, full 128³, every phase, 1.05 ms/120 frames): at rest 30 s from launch, one cell held **408,198 particles = 20.4% of the field**, clump factor **5,351× and climbing**, 87% of matter in cells over 32. **③ THE GHOST READ — real, measured, fixed:** the scan clamped at `MAX_PER_CELL=128` while the scatter writes only **32/cell** (`spatial_hash.metal:351`) into ranges sized by the UNCAPPED prefix sum — so **73.9% of the collision scan's reads were slots nothing wrote that frame**, in a buffer that is never cleared. Both index-based sites now use `SCATTER_PER_CELL = 32u`, matching the convention the tiled kernel already used at `:669`/`:714`. 🚨 **④ AND THE FIX CHANGED NOTHING:** the collapse reproduces to within **0.2%** (maxCell 407,660 vs 408,198; clump 5,338× vs 5,351×) and fps is inside noise. **The ghost reads were not driving the runaway.** Keep the clamp as a correctness fix; the collapse is driven by an uncapped path (self-gravity reads `cellMass`, deliberately honest) — that is the open question. ⚠️ The probe's `ghostReads` figure is computed against the OLD 128 depth: it measures the MISMATCH, not the live scan. **⑤ A3②-white: I called it a no-op at rest and that was the wrong state** — his play run gave `r_h = 0.0000` with `seeds` 3→10, `Mmax` 102,102 and `com` 3.1 units off origin, so the billboard IS drawing. Row 5 stands.

**PREVIOUS — 2026-08-13 13:46:00: DEAD-COMPUTE SHIPPED, ITS A/B FAILED TO ATTRIBUTE, PARKED ON HIS CALL.** The corpse early-out is live at `particles.metal:1156` (bundle `13:29:29`) and is output-equivalent by construction — write-back already mass-gated, every atomic below it inside a mass-gated block. **Two board claims corrected by the code:** a corpse never walked the *whole* kernel (capture/merge/self-gravity/relaxation all refuse it on mass — what it did run is the three scans that are NOT mass-gated: collisions `:2685`, bond `:2842`, SPH `:2932`), and the eaten pile is NOT parked at 4000+ — ESCAPER RECYCLE `:1131` drags every corpse to its star-map home the frame after it dies and freezes it there. **The A/B (`SS_NO_DEADSKIP`, bit28, built and verified) did not resolve the fps question:** sequential 6-min soaks are dominated by a ~15 fps order/thermal effect — control started cool at 55.7 and fell to 41.2, skip arm started hot at 37.8 and rose to 45.5. 🚨 **Suspected but NOT measured: SIMD divergence** — corpse ids are scattered, so at 23% dead almost no 32-lane group is fully dead and a per-lane branch skips nothing; if true, his order needs COMPACTION, not an early-out. Settling it is now ONE soak (alternate bit28 within a run), parked because it blocks nothing.

**PREVIOUS — 2026-08-13 02:48: SESSION END. A1″ BOUNDED (done), PERF TELEMETRY SHIPPED (done), GRID-IMPRINT DEFERRED BY HIM AFTER MY DIAGNOSIS FAILED TWICE.** **A1″:** the fit test (budget = headroom, claim must fit whole) holds `Mmax` to a worst **100.1% of ceiling** across 115 samples of HIS play run, against 137% on the entry test — and merges still fire (`mrg=17575/22/17553`, 22 landed, incl. a legal ×2.68 jump under the ceiling). **PERF:** `[PERF]` line live, first hard baseline in the project's history — **~31–36 fps idle @2M, worst frame 50–99 ms** — and the warning that `dt` is a FIXED step, never frame time. **GRID-IMPRINT:** both nearest-cell ∇Φ reads (coarse `:1610`, AMR fine `:2101`) made CIC-trilinear and KEPT as genuine kernel-mismatch fixes, but his verdict was *"unchanged"* then *"still there"* — **the boxes are not the potential reads.** Next move is the ORBIT TEST (five seconds, no code) to split world-space physics from screen-space render. 🚨 **The temp `mrg=` gate counters are STILL in the tree — strip before shipping.**

⭐ **2026-08-12 22:09:01: A1′-endgame IS BOUNDED.** An idle run parks at **101,800 M☉ = 17.1% of the field**, flat, after eating 457,421 stars, with `Mlive` held to −71. The field survives an idle passage for the first time.
**Newest:** ⭐ **§H — THE PSEUDO-3D REGISTER, 2026-08-11.** Ten ranked sites where the render fakes 3D, at his direct order. **The physics is 3D; the render is not — and CHLADNI IS NOT THE PROBLEM (§H2, it is a real 3D cavity mode).** Also: five dead ends cut and one refused (§H3), and the frame cost model (§H4) — **the star pass he named is 2.4–3.3 ms; the Poisson solver is ~6 ms.**
Before that: **§G — THE GRID/SCALE AUDIT, 2026-08-11.** Six answers at his direct request, one shipped fix (capture cull on raw r_h), one disproven hypothesis, and **two live unit systems found**.
Before that: A0 test **DEPLOYED AND INCONCLUSIVE** (2026-08-10 10:20:00, his verdict) — see §A0 VERDICT

<!-- ——— archived from BOARD.md lines 22–23 ——— -->

⭐ **NEW, AND IT OUTRANKS THE A4 PATCH ROWS:** `docs/AUDIT_2026-08-10_note_lifecycle_chain.md` — **the full key-down → hold → key-up → star-map chain**, at his direct request 16:22:00. Verdict: **attack is an authored explosion, sustain holds matter with a velocity DAMPER we label crystallization, release switches the authored forces off and hands back to real gravity with no transition function.** The two ends of the chain are physical; the middle is stagecraft. §4 proposes the scientifically true version (sound = pressure SUPPORT against self-gravity; release = support decaying to zero, so nothing switches and no branch is crossed) — **his call, not started.** §5 is the discontinuity ledger; §1 retracts my own 400 ms claim.
**Latest handoff:** ⭐ **`HANDOFF_2026-08-13_bound_closed_grid_open.md` — 2026-08-13 02:52:00, NEWEST.** A1″ bounded by the fit test and verified on HIS play run (100.1% of ceiling vs 137% on the entry test, 22 merges still landing); `[PERF]` telemetry shipped with the first hard baseline (~31–36 fps idle @2M, worst frame 50–99 ms) and the warning that `dt` is a fixed step not frame time; GRID-IMPRINT deferred after two trilinear fixes left the symptom unchanged, with the orbit test as the next move; five method notes including **"run it" means LAUNCH it, he plays** and **grep every read of a field before declaring a class of bug fixed**. Previous: ⭐ **`HANDOFF_2026-08-12_bound_fixed_and_measured.md` — 2026-08-12 22:26:00, NEWEST.** The accretion bound works (101,800 = 17.1% of the field, flat, 457,421 stars eaten), the `massTotal`-vs-`fieldMassMsun` mistake that shipped first and stalled it at 32,384, the gate-counter measurement that found it, three retracted claims of mine, and A1″ (the seed↔seed merge still bypassing the bound). Previous: **`HANDOFF_2026-08-11_scale_and_bound.md`** — the units/scale audit and the UI truth fix; ⚠️ its §1 "the one test owed" is now ANSWERED and its 84,592 figure is SUPERSEDED. Previous: **`HANDOFF_2026-08-11_pseudo3d_register.md` — 2026-08-11 11:48:24.** The ten-site pseudo-3D register, the Chladni answer (it is genuinely 3D), the five dead ends cut and the one refused, and the measured frame cost model. Previous: **`HANDOFF_2026-08-11_grid_scale_audit.md` — 2026-08-11 03:40:00.** The six-question grid/scale audit, the capture-cull fix, the disproven AMR hypothesis, and the vertex-cost item he named as the real problem. Previous: **`HANDOFF_2026-08-10_extinction_and_note_lifecycle.md` — 2026-08-10 23:15:00.** Covers A4 shipped (`ea2cfba`), A9 extinction through three measured versions, A1′-endgame, A7 refuted, A3②-white, and seven method rules. Previous: `HANDOFF_2026-08-10_a0_inconclusive_camera_gates.md` — 2026-08-10 14:47:00 (previous: `HANDOFF_2026-08-10_a2_fired_three_noops_found.md`, whose §0a findings 1 and 2 are **RETRACTED**)

<!-- ——— archived from BOARD.md lines 35–43 ——— -->

> 🪤 **METHOD FIX — THE RELAUNCH RECIPE DISCARDS THE ONE BIT YOU LATER NEED (2026-08-10 16:05:00).**
> `CLAUDE.md` says `pkill -f SpaceSynth; open -n SpaceSynth.app`. `pkill` is **silent on success** and the `;`
> **discards its exit status**, so nothing records whether a kill matched. When an instance later turns up
> missing you cannot tell "I killed it" from "it was already gone" — which is exactly what happened today:
> pid 6225 vanished somewhere in **15:51:57 → 15:53:23**, and my `pkill` did not run until ~15:53:31, so it
> was **not** the cause. Cause **UNDECIDABLE** — he may have closed the window, it may have died silently
> (documented hazard: a prior parallel run lost an instance at ~90 s with no crash message), or the peer's
> check raced a teardown. `log show` over the window returns nothing for exit/terminate/crash. **Use instead:**
>

<!-- ——— archived from BOARD.md lines 45–56 ——— -->

>
> ✅ **`pgrep -x` itself is HEALTHY and the standing rule is unchanged** — re-tested 15:57:54 against live pid
> 6857: both `-x` and `-f` see it, one pid, no truncation. Do not let this incident put that check in doubt.
>
> 🚨 **BIGGER HAZARD, FOUND BY THE CAMERA WINDOW AND CONFIRMED HERE 2026-08-10 16:01:47 — THE PROCESS NAME
> NO LONGER IDENTIFIES THE BUILD.** Both trees produce a process named exactly `SpaceSynth`. So since the
> worktree existed (10:39:38): **`pkill -x SpaceSynth` kills BOTH trees' instances**, and `pgrep -x` returning
> a pid proves *something* is running, **not whose**. W1 (camera bundle) and W2 (main bundle) are two different
> binaries with the same process name — the standing recipe cannot tell them apart, and a relaunch for one
> test silently destroys the other. **This is a second way an instance "goes missing": it was never the
> instance you thought.**
>

<!-- ——— archived from BOARD.md lines 65–87 ——— -->

> ⚖️ **REPORTED BUT NOT REPRODUCED:** the camera window saw `pgrep -f SpaceSynth` return a phantom pid (its
> own shell, matched on its command line) at 16:00:33. **My run at 16:01:47 did not reproduce it** — `-f` and
> `-x` both returned only 6857. Invocation-dependent, so treat it as a real reason to prefer `-x` but **not**
> as a measured property. The `-x`-not-`-f` rule was already standing and does not rest on this.
>
> 📋 **PROPOSED EDIT TO `CLAUDE.md`, HIS CALL — NOT MADE.** The repo-root build recipe says
> `pkill -f SpaceSynth; open -n SpaceSynth.app`. That is now wrong on two counts: `-f` is the form we avoid,
> and an unqualified kill crosses trees. **Neither window has touched it** — it is his file, a peer request is
> not his approval, and the tree is under a build freeze. Raised, not actioned.
> ⚠️ **A0 cannot be re-measured from the camera bundle** — the gate drop is not in it.
>
> 🚨 **THE 09:55:37 BINARY NO LONGER EXISTS — corrected 2026-08-10 15:55:20, caught by the camera window.**
> This table said `09:55:37` until now. I overwrote that binary with the A4 build at **15:12:02** and left the
> table describing a file I had just destroyed — the §A0 rows still cite 09:55:37 as their deploy evidence.
> **Those rows keep their claim but LOSE their timestamp check:** anyone who stats the main bundle tomorrow
> gets 15:12:02 and cannot independently confirm the A0 deploy. The A0 gate drop is still in the source and
> still in this binary; only the *artifact-level proof* is gone. ⭐ **RULE THIS PROVES: a bundle timestamp is
> evidence for exactly one build. The moment you rebuild, every row citing the old stamp is hearsay — update
> them in the same action as the build, not later.**
>
> ⚠️ **UNCOMMITTED, main tree:** `src/main.cpp`, `renderer.h`, `renderer.mm`, `package_macos.sh`, `docs/*`, `tools/a2_watch.sh`.
> ⚠️ **UNCOMMITTED, camera worktree:** `camera.h`, `main.cpp`, `render.metal`, `renderer.h`, `renderer.mm` (the F5 change).
> The live-UI panel and F5 are both still **UNSEEN** — he has looked at neither.

<!-- ——— archived from BOARD.md lines 102–136 ——— -->

## 🗄️ PREVIOUS PRIORITY — 2026-08-11 15:47:12: **KILL THE TUBE**

> *"align these to dos as priority HANDOFF KILL THE TUBE"*

**Full ordering + the rewrite's constraints: `docs/HANDOFF_2026-08-11_kill_the_tube.md`.** Berlin is **20 days** out (as of 2026-08-13).

🚨 **BUT THERE IS A FREE TEST THAT MAY ELIMINATE THE `L` BEFORE IT STARTS — DO IT FIRST.**
**The default camera sits at `(0,0,rho)` — ON the +Z axis** (`camera.h:31-32`) — and the Chladni cavity's axial structure runs **along Z** (`pAx` = 2–4 nodal planes, `particles.metal:2272`). **So the camera looks straight down the axis of the structure whose depth we are trying to see, and with no occlusion those planes additively superimpose into one flat image — by geometry, however good the depth cue is.**
⭐ **Hold a chord and orbit ~90°.** Layering appears side-on → the cause is viewing geometry + additive superposition, **not the tube**. Still flat from every angle → that candidate is eliminated and the tube hypothesis strengthens. **One minute, no code.**

| # | Item | Cost |
|---|---|---|
| **1** | **C1 free test** — orbit 90° during a chord | **0** |
| **2** | **B7-measure** — `[DISKZ]` `H/R` during PLAY (never read; silence reads 0.31–0.84). Collapsed ⟹ B7 confirmed; comparable ⟹ look elsewhere | **S** |
| **3** | **B7 — KILL THE TUBE**, *only if 1+2 confirm it* | **L** |
| **4** | **Consume the depth buffer for occlusion** — §H8 already paid for it, nothing reads it, independent of B7 | **M** |
| **5** | **A3②-white** — gate the merger billboard on MASS not `horizonR`. His repeated ask (*"explosive feel, not white noise"*). One line, written, unbuilt | **S** |
| **6** | **A4/W2** — release→silence snap. On screen every play | **M** |
| **7** | **D6** — the only item that can take down a live show | **S** |
| **8** | ✅ **A1′-endgame — BOUNDED AND MEASURED 2026-08-12 22:09:01.** Was: ~4 min of accretion eats the field. Now parks at **101,800 M☉ = 17.1% of the field**, flat. See the A1′-endgame row. | **done** |
| **9** | ✅ **A1″ — FIT TEST SHIPPED AND VERIFIED ON HIS PLAY RUN 2026-08-13 02:25:56.** Worst `Mmax` across 115 samples = **100.1% of ceiling** (+68 M☉, inside the capture path's own ≤50 M☉ slack) vs **137%** on the entry test. 22 merges landed, 17,553 refused. `particles.metal:1481` | **done** |
| **10** | 🚨 **HIS ORDER 2026-08-13 01:02:00 — DEAD PARTICLES MUST NOT BE COMPUTED.** *"if a particle is in the bh its gone. no need to compute it and we still do."* ~46% of the field is corpses and they run the full kernel. ⚠️ NOT a plain early-out — the sustain-rebirth path needs them visited. See the DEAD-COMPUTE row. `particles.metal:677`, `:720` — ⏸️ **SHIPPED + PARKED, see the status line below.** | **M** |
| **10⁺** | ⚠️ **STATUS: SHIPPED 2026-08-13 12:56:01 — A/B RUN 2026-08-13 13:42:48 DID NOT RESOLVE IT.** Corpse return at `particles.metal:1156` (below revive + reset + recycle, output-equivalent). Two 6-min rest soaks, same binary, `SS_NO_DEADSKIP=1` as control: **absolute fps is NOT comparable** — the control started on a cooled machine at 55.7 and fell to 41.2; the skip arm started 20 s later on a hot one at 37.8 and ROSE to 45.5. Order/thermal ≈ 15 fps, larger than the effect. Only the **trends** inform, and they point opposite (control decays as corpses accrue, skip climbs). 🚨 **SUSPECTED MECHANISM, NOT MEASURED: SIMD divergence.** Corpse ids are scattered, so at 23% dead ~no 32-lane group is fully dead and a per-lane branch skips nothing — the group still runs for its live lanes. If that holds, his order needs **compaction**, not an early-out. Next: alternate bit28 WITHIN one run. ⏸️ **PARKED ON HIS CALL 2026-08-13 13:46:00: *"is it an active blocker rn if not move on and do it later"* — it is not.** The skip is live and output-equivalent (it cannot break a show), perf is deferred by his own order, and the A/B instrument (`SS_NO_DEADSKIP`, bit28) is already built and verified — so finishing this is ONE soak whenever it is wanted, not a rebuild. | **M**, parked |
| **11** | 🎨 **A MERGER HAS NO VISUAL FACE — his call 2026-08-13 01:02:00.** *"a merger doesnt have a visual face yet. its just millions of dots."* Renders as a blown-out **squarish 2D white slab**, no volume, no aura. Needs the science answered first. See the MERGER-FACE row. | **M** |
| **12** | ✅ **PERF TELEMETRY SHIPPED 2026-08-13 02:30:43.** `[PERF] fps=… worst=…ms ortho=… warp=… particles=… n=240` on the existing cadence. Baseline idle @2M, ortho, 1×: **~31–36 fps, worst frame 50–99 ms.** ⚠️ `physicsUniforms.dt` is NOT frame time — it is a fixed `0.0165×warp` step; never derive fps from it. | **done** |
| **13** | ⏸️ **GRID-IMPRINT — DEMOTED TO LOW PRIORITY ON HIS CALL 2026-08-13 02:48 (*"fuck it low prio"*).** Two trilinear fixes shipped, **his verdict both times: "unchanged" / "still there".** Diagnosis failed. Next step is ONE observation, not code — orbit the camera and see if the boxes rotate with the field or stay locked to the screen. | **deferred** |
| **14** | 🚨 **TUBE-AND-SPHERE — his restated complaint 2026-08-13.** Both are literal clamps: tube `ORBIT_R_CHLADNI = 6.0f` (cylindrical XY during play), sphere `STAR_MAP_CAP = 100.0f` (3D wall at rest), and the attack `mix()`es between them. **B7 that ignores `:3141` will not kill the tube.** | **L** |
| **16** | 🍽️🚨 **THE LENS IS A PLATE — his insight 2026-08-13 15:0x, EXPLICITLY MOVED TO LATER.** *"the bend we have is like the one on a plate — see the bending of the pavilion above the plate. that's exactly what our fakeish black hole lens looks like. it is never physically bending anything."* **He is describing the difference exactly:** a glossy plate bends the *reflected image* of the pavilion because the SURFACE is curved — the light was never deflected, the picture was. Our lens does the same thing: it warps an already-rendered image in screen space. A real one deflects the light *before* the image exists. ⭐ **AND IT EXPLAINS THE SYMPTOM HE'S BEEN NAMING FOR WEEKS:** *"sometimes two rings stack on top of each other like rings, not like a black hole."* A surface warp can only ever push existing pixels around a circle → concentric rings. The NASA reference he attached shows what the real thing is made of, and **none of it can come from warping a picture:** the image of the disk's FAR SIDE (light from behind, bent over the top), the image of the disk's UNDERSIDE (light from beneath the far side, bent under), and the PHOTON RING (light that orbited 2–3× before escaping). Those are separate light PATHS, not one picture bent — which is why the second NASA panel shows rays *crossing* and the far-side image arriving left-right SWAPPED. ⚠️ **NOTHING MEASURED, NOTHING BUILT — captured only.** Relates to A0 ("a black circle with a GoPro on top"), LENS-IS-THE-HERO, and the camera row. | **later, his call** |
| **15** | 🔊 **ETERNAL-ECHO — infinite resampled echo through the stars.** His ask, **explicitly low priority**. Delay times DERIVED from the field (orbital period, α in Hz, viscous time). 🚨 Gated on **D6** — feedback on the audio thread behind a mutex is a stage dropout. | **L**, deferred |

⚠️ **The cavity is r≤6 AND |z|≤6 — a can 12 wide by 12 tall, roughly ISOTROPIC.** "The tube makes it flat" is **not self-evident from the clamp dimensions**, which is exactly why step 2 gates step 3.
**Deferred by this realignment:** C12 (Doppler, needs his call on the temperature-range limit), F6 (still gates A0), C3, C7.

---


<!-- ——— archived from BOARD.md lines 188–191 ——— -->

## 🗓️ STATE OF PLAY — 2026-08-10 10:23:45

**THREE WINDOWS ARE LIVE ON THIS REPO.** Coordination rules are not optional; see §STANDING RULES.


<!-- ——— archived from BOARD.md lines 199–244 ——— -->


| Window | Owns | May build? | Status |
|---|---|---|---|
| ⭐ **Board — THE MAIN SESSION** (this one) | **His words, 2026-08-10 14:52:00: *"This is our main session here."*** Drives the work and owns this board. A0 + board rows, `renderer.mm` BH render path, the main tree's bundle. | ✅ **HOLDS THE BUILD TOKEN** for the main tree | Main bundle deployed 09:55:37. Awaiting his direction. **Direction is taken HERE; the other two windows are specialists reporting in.** |
| **Camera** (`CAMERA`, ref `[1012d2]`) | `camera.h`, `main.cpp` camera block, `midi_input.*`, Link clock, `render.metal:904`/`:1031`. | ✅ **builds its OWN bundle** (worktree, since 10:39:38) | **F5 LANDED 2026-08-10 10:44:03** — `getForward()` + `viewForward` + the layout guard, built into its own bundle. See F5 row. **F6 not started** (no `posPosCoef` in `camera.h`, verified 14:49:00). |
| **Audio** (`Audio`, ref `[7c9582]`) | §D audio. `src/audio/*`, `DESIGN_2026-07-28_field_sonification.md`. | ❌ docs-only | **SCOPE RESOLVED 2026-08-10 09:56:38 — AUDIO** (his words: *"truly my error… I did mean audio"*). Design-doc correction pass: +82/−5, three corrections; **found D6 was under-stated — row corrected.** Then wrote the **D6 spec** — `docs/DESIGN_2026-08-10_d6_rt_safe_command_path.md`, 20 KB, **10:41:02**, spec only, no code, as instructed. Zero source, zero builds. |

**🚨 HIS PRIORITY CALL, 2026-08-10 10:20:00 — read this before picking anything up:**
> *"the cam is still kinda locked in place so I don't know if I see the BH — but that's not even our priority right now."*

**🔄 HIS TRIAGE CHANGED, 2026-08-10 10:30:00 — SECTION D IS BACK IN, BEFORE BERLIN.**
> *"all of it. audio fix + sonification. it's already looking really good you know. **if I start work on something that usually means I changed my mind** lol"*

**This SUPERSEDES the 2026-08-07 12:24:09 triage for section D**, which parked D post-Berlin with D6 "parked, not dismissed". Both **D6 (the RT audio fix)** and **D7 (field sonification, step 2 = the per-particle voice at N=1)** are now in scope before 2026-09-02. The triage section below is kept for its reasoning but is **no longer current for section D** — do not plan from it.

⭐ **STANDING SIGNAL, in his own words:** *if he starts work on something, he has changed his mind about it.* An old triage decision does not survive him opening a window on the thing it deferred. **Check the newest signal before quoting an older plan at him.**

**✅ HIS DECISIONS, 2026-08-10 10:37:00:**
> *"tempo cam yes but pov 0 importance rn. pre show. do the worktree. audio window should get the fix in before we do sonification"*

| Decision | Effect |
|---|---|
| **Tempo-derived camera feel: YES** | **F6 is approved.** Spring ω derived from the beat. This was the one everything hung off. |
| **POV: zero importance right now — pre-show** | **F11 DROPPED for now.** The open "what should POV track?" question is **closed, unasked.** Do not spend a session on it before Berlin. |
| **Worktree: DO IT** | ✅ **DONE 2026-08-10 10:39:38** — see below. The camera window now builds its own bundle. |
| **Audio: the FIX before sonification** | **D6 first, then D7.** Sonification does not start until the RT audio fix is in. |

**🔨 WORKTREE — LIVE AND PROVEN, 2026-08-10 10:39:38**

    /Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-camera     branch: camera-overhaul-2026-08-10 (off 779a517)

Isolation verified end-to-end: the worktree built its own bundle at **10:39:38** while the main tree's stayed at **09:55:37**, untouched. **The build-token problem is now dissolved rather than scheduled** — two trees, two bundles, no sharing.

🪤 **THREE TRAPS A FRESH WORKTREE HITS — all found and fixed while setting this one up:**
1. **`third_party/imgui` is a git submodule** and arrives EMPTY. Needs `git submodule update --init third_party/imgui`.
2. 🚨 **`third_party/syphon` is GITIGNORED** (`.gitignore:13`) — it exists only in the main working tree and **will never arrive via git.** Must be copied by hand. Nothing in the build tells you this until it fails.
3. 🚨 **`package_macos.sh` did `cd build` without creating it**, so it failed on any fresh checkout — **and `SpaceSynth.app` is TRACKED IN GIT**, so the worktree already contains the *committed* binary. **The build fails and an app bundle is still sitting there looking valid.** That is the stale-binary trap with a new cause: a failed build in a tree that appears to have an app. ✅ **FIXED 2026-08-10 10:44:00 on his order** — `mkdir -p build` added before the `cd`, with the reason recorded in the script itself. **Verified by reproducing the original failure and its absence**: run in an empty dir with no `build/`, the old script died at `cd: build: No such file or directory`; the new one creates `build/` and reaches `cmake`. No-op in any tree that already has `build/`. ⚠️ **Uncommitted** — a NEW worktree still checks out the OLD script until this is committed.

⚠️ **The worktree is at commit `779a517` — it does NOT contain today's uncommitted work** (the A0 gate drop, the E5 live-UI panel). Correct for **F5**, which must be a visual no-op. **But A0 cannot be re-measured in the camera worktree** until the gate drop is committed or cherry-picked there.

**THE DEPENDENCY INVERTED TODAY.** We assumed the camera work was downstream of A0. It is the other way round: **A0's result cannot be READ until the camera can move.** A locked, origin-pointing camera cannot produce the parallax that distinguishes "a disc is drawn in perspective" from "a disc is drawn". So the camera overhaul now gates the A0 measurement, not the reverse — and it is also what the show needs. **Branch A (perspective-native) was his call, relayed 2026-08-10.**

---

---


<!-- ——— archived from BOARD.md lines 382–402 ——— -->

### G1. THE INVENTORY

| Grid | Dims | Domain | Peak res | Centre | Fires when |
|---|---|---|---|---|---|
| Coarse spatial hash | 128³ | **±64 sim** (hardcoded) | **1.0 sim** | **ORIGIN** (structural) | every frame |
| AMR fine grid | 128³ | **±4.0 sim** | **0.0625 sim** | **ORIGIN** (structural) | gravity only, bit15 default ON |
| Radial horizon profile | 256 shells | 0→**5.0 sim** | **0.0195 sim** | **`u.bhX/Y/Z` — FOLLOWS THE MASS ✅** | BH readout |
| Density heatmap texture | 256×256 2D | [−1,1]² | — | ORIGIN | collisions/heatmap |
| Chladni eigenmode | **analytic** | cylinder r<6.0, \|z\|<6.0 | unlimited | ORIGIN | play phases |
| ~~Chladni gradient LUT~~ | ~~128×128~~ | — | — | — | ✅ **DELETED 2026-08-11 04:11:00** — files gone, out of `CMakeLists.txt`, `CLAUDE.md` no longer points new readers at it. Verified 12:31:44: `ls src/core/lut.*` → no matches. **Row closed; five live domains remain, not six.** |

`renderer.mm:2043` (±64), `renderer.mm:131` (±4.0), `particles.metal:342` (RADIAL_MAX_R), `particles.metal:276,504,533` (EIGEN) — *lut.h removed from this list 2026-08-18 18:24:11: the row above closes that domain, so citing it here contradicted its own board row*

**Density, pressure, SPH and extinction resolve 1.0 sim and have NO fine path at all.** Only gravity and the BH readout get better.

### G2. THREE MISALIGNMENTS THAT FALL STRAIGHT OUT

1. **The Chladni cavity does not fit the fine grid.** Cavity r = **6.0 sim**; fine box is **±4.0 sim**.
2. **The star map does not fit the coarse grid.** Stars reach **100–108 sim** (`STAR_MAP_CAP`, `particles.metal:277,3085`); the hash ends at **±64**. `render.metal:2212` already says *"outside the hash extent the border cells are garbage."*
3. **Structural root:** `SpatialHashUniforms` (`renderer.h:341`) has **no centre field** — only `halfExtent`. Every grid on it is `[−halfExtent,+halfExtent]` about the origin **by construction**. That is one missing field, not N mistakes.


<!-- ——— archived from BOARD.md lines 427–436 ——— -->

### G5. FIXED RATIOS STILL COPIED FROM REAL BLACK HOLES — **three contradictory spins**

| Value | Where | Claims |
|---|---|---|
| `a = 0.99M` → `BH_HORIZON = 0.57f` | `particles.metal:245` | Kerr outer horizon |
| `KERR_A = 0.5f` | `render.metal:274` | spin in Ω(r)=1/(r^1.5+a) |
| `spin_a = 0.10` | `physics_constants.h:113` | Sgr A*, GRAVITY 2022 |

**The field's own angular momentum is never measured to derive any of them.** `BH_R_IN_SIM = 0.57f` (`render.metal:250`) repeats the same literal in a second file with no shared definition. This is the direct answer to *"where are we still chasing fixed ratios."* It also bears on the **rotating BH**: `render.metal:782` computes time dilation as `rDil = length(in.posW.xyz)` — **from the ORIGIN** — while the hole sits at r=3.8–5.9 sim. The shear pivots around a point the hole is not at. *(Code reading, no A/B run.)*


<!-- ——— archived from BOARD.md lines 443–458 ——— -->

### G7. LEFTOVER BS FOUND ON THE WAY

- ~~💀 **The Chladni gradient LUT is dead code that still compiles.**~~ ✅ **CLOSED 2026-08-11 04:11:00 — deleted, out of `CMakeLists.txt`, and `CLAUDE.md` no longer lists it as "Key File #2".** ⚠️ **This row and the G1 table both went stale the moment it was deleted and still read as open at 12:31:44** — the same decay this section exists to catch, on this section itself. Corrected.
- ~~⚠️ **`EIGEN_R`'s comment is wrong by 2×**~~ ✅ **FIXED 2026-08-11 12:31:44.** It said `// 3.0 sim units`; the value is **6.0** (`ORBIT_R_CHLADNI`, `particles.metal:276`) and `EIGEN_L` is **12.0**. Corrected in place, with a pointer to the probe it broke.
- ~~🚩 **…and that stale comment already corrupted a measurement.**~~ ✅ **FIXED 2026-08-11 12:31:44.** `[GRIDPROBE]` sized its scan `ceil(6.0f/cs)` "so we see the pattern AND its surroundings" — against a real cavity radius of 6.0 that scanned **exactly the cavity and none of its surroundings**, so the probe could never have seen the void/edge behaviour it was built for. Now `ceil(9.0f/cs)` = 1.5× the cavity radius. ⚠️ **Read-only instrumentation: this changes logged numbers only.** **It remains the first case on this project where a stale comment silently broke a probe rather than just a claim — that lesson stands even though the bug is fixed.**

### G8. ✅ SHIPPED TODAY — capture cull now uses the RAW horizon

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| **G8** | **Star-pass capture cull moved off the EASED horizon onto the raw one.** Measured at formation: `raw=0.0781` vs `smooth=0.0130` — the eased value is up to **6× short** and takes ~2 s (×0.03/frame, `renderer.mm:1494`) to converge, so shells inside the real horizon were still drawn every time a hole formed. New appended field `horizonRRaw` carries the raw value; **`cam.horizonR` is untouched** so the hole pass / membrane / pose / lens radius keep their easing (which exists because the hole "visibly JUMPED size", `renderer.h:211`). Cull now agrees with the physics, which already used raw (`renderer.mm:1980`). ⚠️ **The layout guard fired and caught a real hazard:** appending one float gave `sizeof` 276 in C++ but **288 in Metal** (MSL rounds to 16). Tail padded to 288 — same pattern `PostFXUniforms` uses with `gradePad0/1/2`. **Verified: 0 frames with a real hole and the cull off, across 79 samples, max ratio 5.371.** ⚠️ Honest limit: the formation-frame gap was **1.6×** in the verification run, not 6× — the probe samples every ~2 s and lands at different points on the easing curve. **Fixes correctness, NOT the cost — see §G6.** | ✅ **BUILT + VERIFIED, bundle 03:36:33** | `render.metal` cull (grep `horizonRRaw`), `renderer.h:341+`, `renderer.mm` ×2 sites | **S** |
| **G6-cost** | **§G6 IS NOW BOUNDED — 2.4–3.3 ms, not the frame's cost centre.** `SS_NO_STARPASS=1` skips *encoding* the star draw (default off = byte-for-byte the shipping path). A vs B, hole latched so `instanceCount=2` = **4M invocations**: Render+PostFX **7.31 ms → 4.02 ms**, ranges non-overlapping (A min 6.00 > B max 4.77). Compute unchanged (22.92 vs 21.87) — that 1 ms **is the noise floor**, since compute should have been identical. **No cull or compaction scheme can win more than this, because deleting the pass entirely IS this.** Compute is 76% of the frame. | ✅ **MEASURED 2026-08-11** | `renderer.mm` star draw (grep `SS_NO_STARPASS`) | **S** |
| **G-probe** | **`[DENSPROBE]` + `[HORIZONBOX]` — read-only instrumentation, ungated on phase.** First physical density this engine has ever printed. Reports top-cell mass/count/ρ in kg/m³ via the engine's own `kUnitMeters`, the extinction gate value, `r_s` derived from the cell's own mass, AMR box membership, and all three horizon values. ⚠️ **Its `regime` label is by DENSITY ALONE and is therefore MISLEADING** — it called a 294,518 M☉ clump a "WHITE DWARF" when that mass is **2.1×10⁵ × the Chandrasekhar limit** and the object is at **0.51× the black-hole density for its own mass**. Fix the label before trusting it. | ✅ live | `renderer.mm` (grep `DENSPROBE`) | **S** |

---


<!-- ——— archived from BOARD.md lines 578–664 ——— -->

### H7. ✅ SHIPPED 2026-08-11 12:31:44 — THE TRUTH PASS. Bundle `12:06:17`.

**His order:** *"double check if the claims from the doc are true. then fix the errors listed there… work on all tasks from the to-do that can be done freely."*
**Every change below is provably pixel-neutral by construction** — comments, and one dead variable with no reader. **The one exception is stated as such.** Build clean, bundle `12:06:17` newer than all four touched sources.

| # | Change | Why it is free | File |
|---|---|---|---|
| 1 | **P5 — the "DEFAULT OFF" comment corrected.** Now states the block is the LIVE path, cites `app_state.h:56` and the 19:15 decision that superseded it. | comment | `render.metal` (grep `COMMENT CORRECTED`) |
| 2 | **Two "off-origin after PLAY" comments corrected — both were FALSE.** `cam.bhX/Y/Z` are always (0,0,0). Fixed in both the shader and the CPU feeder so the next reader cannot be misled from either side. | comment | `render.metal` c2; `renderer.mm` `cam.bhX =` |
| 3 | **P6's refutation written at the code site**, so nobody re-derives the no-op fix from the board. | comment | `render.metal` at `rDil` |
| 4 | **C7b — `dopplerColor` DELETED** (decl + assign) **and `DOPPLER_K_COLOR` with it** (its only consumer). The comment claiming the Doppler shift *"is already applied above via dopplerColor"* corrected to say what is actually applied: **beaming on luminance, no colour shift anywhere.** Per the H3 method rule, grepped for the SURVIVORS: `DOPPLER_K_BEAM` and `out.luminance *= pow(beam, …)` both intact. Remaining `dopplerColor` hits are comments only. | dead variable, zero readers, verified by grep | `render.metal` |
| 5 | **P7 — the heatmap audited in place, four facts written into the kernel header**, incl. the newly *proven* "nothing samples it". **Deliberately NOT deleted** — free while gated off, and deleting a collisions-path kernel is a physics call. | comment | `spatial_hash.metal` |
| 6 | **G7 — `EIGEN_R`'s comment was wrong by 2×** (`// 3.0 sim units`; the value is 6.0, and `EIGEN_L` is 12.0). Corrected, with a pointer to the probe it broke. | comment | `particles.metal` |
| 7 | ⚠️ **G7 — `[GRIDPROBE]`'s scan radius fixed: ±6 → ±9 sim.** The stale `EIGEN_R` comment had it scanning **exactly the cavity and none of its surroundings**, defeating its own stated purpose. ±9 = 1.5× cavity radius, well inside the hash's ±64. **THE ONE BEHAVIOUR CHANGE IN THIS PASS — it is read-only instrumentation, so it changes LOGGED NUMBERS ONLY, never a pixel.** | probe only | `renderer.mm` |

**What was deliberately NOT done, and why:** P1/P2 (no design, and it is his call), P3 (changes the image), P4 (changes disk motion), P8/P9/P10 (all image changes). **A9's failed extinction and the SOR sweeps were left alone** — both need a verdict, not a cleanup.
🚨 **Nothing here has been seen on screen.** The claim to falsify: **this build should be visually identical to `04:15:06`.** Any visible difference means one of the seven was not as free as stated.

### H8. ✅ P1 STEP 1 SHIPPED AND VERDICTED — THE PROJECT WRITES DEPTH FOR THE FIRST TIME. 2026-08-11, bundle `12:34:15`

**His verdict, on screen, fullscreen: *"looking identical"*** — which is the pass condition. This step was built to change nothing.

**What exists now that never has before: a populated, stored, readable depth buffer for the particle cloud.**

| Fact | Detail |
|---|---|
| **Proven live, not assumed** | `[DEPTHPREPASS] ENCODING — 2000000 particles x 1 instance(s), target 1920x1200, storeAction=Store`, printed once per process. **Added deliberately**: a successful pipeline creation only proves the pipeline exists — the encode guard could still have skipped every frame on a nil texture and failed silently. That is the "change did nothing" trap the protocol says to suspect first, so it was closed rather than assumed. |
| **Why it cannot change a pixel** | The pre-pass has **no colour attachment, no fragment stage, and its own depth texture**. The main colour pass keeps its own cleared-and-discarded attachment, byte-for-byte. 🚨 **The two depth buffers must NOT be merged:** sharing one would force the colour pass's `Less` test to start REJECTING fragments the moment depth became non-empty — a large, silent image change. The reason is written at the declaration. |
| **The probe trap that was avoided** | `particle_vertex`'s only write target is the `[KPROBE]` atomic histogram (buffer 9). Running the shader twice per frame against the real buffer would have **doubled every bin** and quietly corrupted the readback. The pre-pass binds a private scratch buffer at index 9 instead. |
| **What it unblocks** | **P1** (occlusion becomes possible at all) · **C4a** (the camera blur unprojects every pixel at a hardcoded far-plane `z=0.99` *because nothing was readable*) · **C4b** (per-particle motion vectors → TAA, blocked outright). ⭐ **His own observation is what raised this from one row to three — see §H1b.** |
| **Nothing consumes it yet** | Deliberate. Wiring depth into post-FX **changes the image** and is a separate, verdicted step. |

**⚠️ COST — NO CLEAN NUMBER, AND I AM NOT CLAIMING ONE.**

| | Render+PostFX | Compute — **the control; a render pass cannot touch it** |
|---|---|---|
| ON (n=32) | 23.53 ms | 27.16 ms |
| OFF (n=47) | 18.44 ms | 30.86 ms |
| Δ | **+5.09 ms** | **−3.70 ms** ⚠️ |

**The control moved 3.70 ms**, so the two runs sat at different sim states and the effect is only 1.4× that floor, with overlapping ranges. **Provisional upper bound ~5 ms. Not a verdict.**
🚩 **METHOD, LOGGED AGAINST MYSELF: the last 8 samples of each run looked cleanly disjoint** (ON min 24.49 > OFF max 24.14) **and I nearly reported "~3.7 ms, ranges do not overlap" using this board's own standard. The full 32/47 sets kill that.** This is §H5.2 landing from the opposite direction — there the tail hid a real effect, here it manufactured one. **Rule reinforced: read the whole run, and state the control channel every time.**
⚠️ **It roughly DOUBLES once a hole forms** — the log reads `1 instance` because no hole existed; with one it is 2 instances = **4M invocations**.
⭐ **A clean number needs a PAIRED within-run measurement** (alternate ON/OFF every N frames in one process). Two separate runs cannot be state-matched while A1′ makes evolution nondeterministic.
⭐ **The obvious mitigation, not yet built:** the pre-pass reuses the full `particle_vertex`, which does extinction marching, lensing, Doppler, blackbody and a random-access partner fetch — **all discarded, since there is no fragment stage.** 🚨 **Do NOT fix this by writing a second copy of the position pipeline** — that is precisely the near-duplicate trap that caused the A0a/A0b retraction (§A0g). **Use a Metal `function_constant` specialisation of the SAME shader** so the position math keeps one source of truth and only the shading is skipped.

**Knob:** `SS_NO_DEPTH_PREPASS=1` skips encoding it entirely; unset = the shipping path.

### H9. ✅ COVERAGE RESOLVE — DENSITY CAN REMOVE LIGHT. His verdict: *"yeah its.. looking good"*. 2026-08-11, bundle `14:32:22`

🚨 **THE FINDING: the star pass has been computing a correct per-pixel COVERAGE term for months and throwing it away.**
Its colour blend is `One/One` — pure additive, unbounded, which is exactly A9's failed verdict (*"density can only ever make the image BRIGHTER"*). But its **alpha** blend is `One/OneMinusSourceAlpha` (`renderer.mm:683-685`), which evaluates to `C = 1 − Π(1−aᵢ)` — the standard over-blend coverage. The fragment already returned a real alpha: `float4(emission·alpha·fade, alpha·fade)`. **Nothing downstream ever read it** — `postfx.metal` hardcoded `alpha = 1.0` and discarded it.
⭐ **So A9's verdict was true of the RGB CHANNEL ONLY.** The information needed to make density remove light was already being accumulated correctly, one channel over.

**THE RESOLVE — derived, zero free parameters.** RGB holds `S = Σ(cᵢaᵢ)`. The bounded result is average colour × coverage, `(S/Σaᵢ)·C`. We lack `Σaᵢ`, but for many small alphas `C ≈ 1 − e^(−Σaᵢ)` ⟹ **`Σaᵢ = −ln(1−C)`** — the same Beer-Lambert relation the extinction work used. Hence `resolved = S·C / (−ln(1−C))`.
⭐ **As `C → 0` the factor → 1**, so the sparse field — most of the screen — is mathematically UNCHANGED. The correction engages only where matter piles up, which is exactly where it clipped white.
⚠️ **Ceiling, stated before he looked:** RGBA16Float saturates `C` at 1.0 and can no longer tell `Σa=10` from `Σa=1000`. Clamped at 2⁻¹¹ (half-float resolution near 1.0, a precision limit, not a taste knob) ⟹ **attenuation bounded at ~7.6×.**
**Knob:** `SS_NO_COVERAGE=1` restores the pure-additive image byte for byte.
🔑 **Wiring note:** repurposed the existing `gradePad0` rather than appending — same offset, same size, **no layout drift possible**. Appending is what produced G8's 276-vs-288 mismatch.

⭐ **AND IT ACTED AS A DIAGNOSTIC — his screenshot proves A3②-white.** The mergers did **not** change under the resolve. If they were dense particle piles, coverage would have divided them down like everything else. **They are single flat billboard sprites** (`render.metal:1941`, `blackbodyRGB(20000K)`, clamped at the 220 px ceiling) — one fragment layer, so there is no overdraw to resolve. **His *"we had them blackish once and that looked so much better… I wanna explosive feel there not just white noise"* is A3②-white, reconfirmed by an independent mechanism.** Fix remains the one-liner: gate the billboard on MASS, not `horizonR`. ⬜ **NOT BUILT — he parked it deliberately to stay on depth.**

### H10. 🔬 P2 SHIPPED IN FOUR STEPS, TWO OF THEM MY OWN REGRESSIONS. Bundle `15:16:49`

**His verdicts in order:** *"depth looking insane but still buggy with the sizes"* → *"stars near camera are too buggy and big"* → *"depth sense way better but stuff disappears when i zoom in"* → *"exact same look. unchanged"* (Chladni) → **final: *"still unchanged feel in chladni mode"***.

| Step | Change | Outcome |
|---|---|---|
| **1** | `dist` in ortho was `cameraRho` — the camera's distance from the ORIGIN, ONE SCALAR for all 2M particles. Replaced with true depth along the view axis, `dot(worldPos − cameraPos, viewForward)`. ⭐ **Must be `dot`, not `length`** — ortho rays are parallel, so depth is the projection onto the view direction; Euclidean distance would bend the size falloff into a fisheye at the screen edges. ⭐ **Second consumer of F5's `viewForward`** (A9 was first), so it stays correct once F6 moves the camera off-origin. | 🐛 **caused steps 2 and 3** |
| **2** | 🚩 **MY REGRESSION.** `distRatio` was a **per-FRAME ZOOM** number; step 1 made it **per-PARTICLE**, and every downstream consumer was written against the zoom reading — `zoomCap` says *"Cap sprite size by ZOOM"* in its own comment. Near the camera plane the old `max(dist,1e-3)` floor allowed `distRatio ≈ 8e5`, and `pow(8e5, 0.65)` is a sprite thousands of px wide. **That was his "buggy and big".** Fixed by splitting `zoomRatio` (per frame) from `depthCue` (per particle, bounded at ¼ the camera distance ⟹ saturates at `pow(4,0.65)=2.46×`). | ✅ fixed |
| **3** | 🚩 **MY REGRESSION #2, same root.** The fragment's `fadeAmount = smoothstep(0.1, 6.0, dist)` is a **perspective near-clip fade**. It was **INERT in ortho forever** — `dist` was `cameraRho`, clamped ≥ 50, so it returned 1 for every particle always. Feeding it true depth switched a dormant near-clip live: matter within 6 sim of the camera plane faded to zero, and zooming in dragged more of the field across that line. **That was his "stuff disappears weirdly when i zoom in".** Fixed by restoring `out.dist` to its pre-P2 value; depth now travels by exactly ONE route, `depthCue`. | ✅ fixed |
| **4** | The cue normalised against **absolute** camera distance ⟹ spread = `field half-depth / cameraRho`: **Chladni R=6 at rho=800 → 0.75%**, star map **R=100 → 12.5%**. Rewritten scale-invariant: `d_eff = R/tan(22.5°) = 2.41421·R` (**45° is this project's own FOV**), `cue = d_eff/(d_eff+δ)` ⟹ near face `1+1/√2`, far face `1/√2`, a **2.414× span for any field size**. | ⚠️ **first version wrong — see below** |

🚨 **STEP 4's FIRST VERSION NORMALISED BY THE CAP AND WAS WRONG BY ~15×. HIS "exact same look, unchanged" IS WHAT CAUGHT IT.**
I used `STAR_MAP_CAP`(100)/`ORBIT_R_CHLADNI`(6) — **what matter is ALLOWED to occupy.** The engine's own telemetry says where it *is*: **`meanR` 6.4–9.3 sim, `r50` 3.2–4.8** (`[GRAV]`, `[DISKZ]`). Against R=100 the real `δ≈±7` gives `cue = 241.4/(241.4±7) = 1.030…0.972` → `pow(·,0.65)` → **a 3.7% size spread. Invisible — exactly his verdict.**
✅ **Now driven by the MEASURED `meanR`** (kept from the reduce that already computed it for the `[GRAV]` print). At `meanR≈7.9`: `d_eff=19.1`, cue spans the full **1.707…0.707**, ~47× more separation than the rejected build. **Self-tracking** — it follows the field as it collapses or disperses, and needs no knowledge of which state it is in. ⭐ **It also DELETED the cross-file constant duplication** the cap version had to declare (the `BH_R_IN_SIM` sin). **The measurement is the single source of truth.**
🔑 Consumed `horizonRPad0` exactly as that block's comment instructs — `sizeof` stays 288, all four offset anchors unchanged, **and the layout guard passed on both the C++ and Metal sides**, certifying it.

❌ **STILL FAILING IN CHLADNI — HIS VERDICT, AND HIS HYPOTHESIS.**
> *"still unchanged feel in chladni mode but im sure our tube limitation is to blame for that"*

**The star map reads depth; the play state does not.** ⭐ **This promotes B7 ("kill the tube") from a deferred `L` to the live suspect for Chladni depth** — see that row. The eigenmode itself is NOT the problem and that is settled: §H2 proved `pAx = 2 + ((mm+nn)%3)` is never 0, `k_z > 0` always, and the force uses the full 3D gradient including `dPdz`.

⚠️ **A CORRECTION TO MY OWN REPORTING, LOGGED.** When he said *"depth sense way better"* after step 3, I took it as the cue working. Running the numbers afterwards, that build had a **~1.2% spread — no meaningful depth cue at all.** What improved was the REMOVAL of the step-2 blowup artifact. **The cue was effectively invisible in every build until step 4's fix.** I should have computed the span before claiming the mechanism worked. Same failure as §H5.2 and §H8: a verdict written ahead of the arithmetic.

---


<!-- ——— archived from BOARD.md lines 670–670 ——— -->

| **A1′-endgame** | ✅ **BOUNDED — SHIPPED AND MEASURED 2026-08-12 22:09:01, uncommitted in `SPACE-SYNTH-TUBE-killtube`.** An 8-minute idle run (clean: 0 amplitude bursts, 0 key events) grew smoothly through the whole range and **parked at `Mmax` = 101,799.9 M☉, flat over the last 5 samples, against a bound of 102,144.2 = 99.66%** — the taper asymptote, exactly where a smoothstep closing at the bound puts it. `live` fell 1,999,988 → 1,542,567, so **457,421 stars were genuinely eaten** — no seed↔seed doubling steps anywhere in the curve. `Mlive` held to **−71 M☉ (−0.012%)** across all of it. **The field now survives an idle passage; a 40–60 min set no longer ends on an empty screen.** ⭐ **The bound is `F_BH_CLUSTER = 0.17188` (Sgr A* / Milky Way NSC, observed) × the field mass**, tapered from 70% via smoothstep, applied to the capture budget at `particles.metal:1387`. 🚨 **AND IT SHIPPED BROKEN FIRST — the failure is the lesson.** The first version multiplied `u.massTotal`, which is the GRAVITY anchor and carries the Size slider's `massScale`: at the default Size=2 it reads **189,044 against a real field of 594,276, a 3.14× under-read.** Effective ceiling was 32,495 and an idle run **stalled dead at 32,383.8 = 99.66% of it** for 10.6 minutes. Diagnosed with a temporary per-frame gate counter (since removed): **916,781 stars sat inside the capture radius every frame and all 916,781 were refused by the budget CAS, `eaten=0`** — the hole was starving inside a full larder, and the thing starving it was my own bound. ⭐ **RULE THIS PROVES: `massTotal` is the gravity anchor, NEVER the mass books. Anything that is a mass BUDGET reads the new `fieldMassMsun` uniform** (`renderer.mm` next to the `massTotal` assignment; `renderer.h` + `particles.metal` structs, appended at offset 164 per **A0h**). ⚠️ **Three of my own claims from that evening are RETRACTED and must not be quoted back:** "the bound never engages" (it was the binding constraint all along), "capture delivers ~0.1 M☉/frame" (it was 20–88 stars/frame during growth — that number came from `feed=`, a one-frame sample of a per-frame-cleared buffer), and "the hole is out of fuel / out of reach" (the larder was 916,781 stars deep). ⚠️ **Also supersedes the 84,592 endpoint** from the 2026-08-11 run: that number was reached by two seed↔seed jumps (+33,849, +13,581), not by accretion. **The honest bound-limited endpoint is ~101,800.** — ORIGINAL ROW BELOW, kept for its reasoning: 🚨 **THE FIX BOUGHT TIME; IT DID NOT BOUND THE OUTCOME. OBSERVED 2026-08-10 15:52:00, HIS SCREENSHOT, ON THE 15:12:02 BUNDLE.** A 41-minute idle run (launched 15:12:17, universe clock 13.62 h at 20.58 s/real-s = 39.7 min — the clock checks out) ended with **`Biggest body` = 356,475.19 M☉ against a field of 594,276 M☉ — 60.0% of everything in ONE body**, and roughly four visible objects left on screen. ⭐ **This is not a regression and not a refutation of A1′ — it is the fix behaving exactly as measured, run longer than anyone had run it.** The rate limit made growth **linear** (verified: consecutive `Mmax` deltas dead constant), but **linear is unbounded in time**: at the measured **2,451 M☉/wall-s**, the entire field is consumable in **~4 minutes** of active accretion. The A1′ row's surviving-field evidence (`live` = 1,273,268 at `Mmax` = 215,829) is a **MID-RUN SNAPSHOT, NOT AN ENDPOINT** — and it was read as though it were a steady state. 🚨 **BERLIN RELEVANCE, direct:** a set is 40–60 minutes. Any idle passage of a few minutes consumes the field, and the show ends on an empty screen. **A bound (feedback / Eddington-like term / a cap tied to field mass) is a different fix from the rate limit and does not exist anywhere in the code.** ⚠️ **Also invalidates any long-idle test:** A4's first attempt died this way (see WATCH LIST). | ✅ **log-verified 2026-08-12 22:09:01 · 🔨 UNSEEN by him** | `particles.metal:1387` (`mBound`, now on `u.fieldMassMsun`), `:256` (`F_BH_CLUSTER`); `/tmp/killtube_bound2fix.log`. Original evidence: his screenshot 2026-08-10 15:52; rate from `docs/MEASURED_2026-08-08_A1_runaway_cause.md` | **done** |

<!-- ——— archived from BOARD.md lines 676–679 ——— -->

| **PERF-TELEMETRY** ✅ | ✅ **SHIPPED AND LIVE 2026-08-13 02:30:43** (`renderer.mm`, top of `runComputePass` + the `lastOrtho` member). Prints on the existing 240-frame cadence: `[PERF] fps=%.1f worst=%.1fms ortho=%d warp=%.2f particles=%d n=%u` — mean fps over the window, **the WORST single frame in it** (the spike is what he feels as a stutter and a mean hides it), and the state it was measured in so no future run has to guess. ⭐ **MEASURED BASELINE, idle, 2M particles, ortho, warp 1×: ~31–36 fps, worst frame 50–99 ms.** First hard perf numbers this project has ever had. 🚨 **THE TRAP THIS EXISTS TO PREVENT, and it nearly caught me: `physicsUniforms.dt` IS NOT FRAME TIME.** It is a FIXED step, `0.0165 × timeWarp` (`renderer.mm:1402`), pinned on purpose to kill the variable-FPS energy pump. Anyone computing fps from `dt` reads the TIME WARP, not the frame rate. This reads `CACurrentMediaTime()` instead. ⚠️ **His ortho claim is now measurable but STILL UNMEASURED** — the `ortho=` field records which mode each window was taken in, so toggling ortho mid-run yields both populations from one session. Nobody has done that run yet. | ✅ **shipped, baseline captured** | `renderer.mm` `runComputePass` head; `lastOrtho` set next to `cam.orthoMode`; `/tmp/killtube_perf.log` | **done** |
| **A1″** ⭐ | ✅ **BOUNDED. THE FIT TEST WORKS — VERIFIED ON HIS PLAY RUN, 2026-08-13 02:25:56, `/tmp/killtube_fit.log`, 115 samples, 181 noteOns, bundle 01:46:07.** **Worst excursion in the whole run: `Mmax` = 102,168.8 against a 102,100.5 ceiling = 100.1%** — 68 M☉ over, 0.07%, which is **inside the star-capture path's own documented slack** ("residual overshoot is at most ONE victim, ≤50 M☉") plus the basis difference between the log's `Mlive` and the shader's `u.fieldMassMsun`. **Not a merge breach.** The 31 samples that read "over" all sit at 100.0–100.1% — that is the taper asymptote, the same place A1′-endgame parks. **Against 137% on the entry test, measured the same night.** ⭐ **AND MERGES STILL HAPPEN — that is the half that could have been broken and wasn't.** `mrg=17575/22/17553`: **22 landed.** The proof the design is right rather than merely safe: **`Mmax` jumped 141,948.9 → 380,561.8 in one sample, ×2.68 — and it was ALLOWED, because the ceiling at that moment was 469,402.** Free below the ceiling, hard stop at it, exactly as specified. **He also grew the field to `Mlive` = 2.97M and the bound tracked it** — peak `Mmax` 489,919.6 against a 509,993 ceiling = 96%. **THE TWO CHANGES THAT MADE THE DIFFERENCE, both against the row below:** budget is **headroom (`mBound − mS`), not `MDOT·dt`** — a BH↔BH merger is dynamical, there is no disc to drain, and keeping the viscous rate would have banned merges outright (21–73 M☉/frame against a ≥50 M☉ victim); and the claim must **FIT WHOLE** (`mcur + myMx <= budgetMx`) instead of merely entering under budget, which makes the overshoot exactly zero by construction and bounds several victims converging on one seed TOGETHER on the shared plate. No taper here on purpose: a merge is a discrete event, and a smoothstep on a discrete event is just a slower lottery. ⚠️ **STILL LIVE IN THE TREE: the temporary `mrg=` gate counters** (`accDiag[2..4]`, three sites in `particles.metal` + the readout in `renderer.mm`). They are the instrument that proved this — strip them before shipping, not before the next verification. | ✅ **fit test log-verified 2026-08-13 02:25:56 on HIS play run · 🔨 the number is verified, the SCREEN verdict is his** | `particles.metal:1481` (headroom + fit test); `/tmp/killtube_fit.log`; prior failure `/tmp/killtube_play.log` at 137% | **done** |
| **A1″** ⭐ | 🚨 **THE GATE FINALLY FIRED ON HIS PLAY RUN — AND THE CAS DOES NOT BOUND THE MERGE. MEASURED 2026-08-13 00:59, `/tmp/killtube_play.log`.** ⭐ **He predicted the conditions and he was right:** *"mergers never really happen through random launch mode, rather after play."* The code agrees — the merge is gated `playGate < 0.5` and blocked through attack, so it can only fire **at rest, on seeds that play piled into one place**. A cold idle launch never gets two seeds within 1.4 cells, which is why every unattended run logged `mrg=0/0/0`. **First firing ever, at rest after his passage:** `Mmax` 5,012.4 → **15,152.0 in one sample** as `seeds` 3 → 2 and `meanR` 5.63 → 3.93 — the ring contracting and jumping, exactly the flip he described. 🚨 **THE VERDICT: `mrg=1902/10/1892`.** 1,892 refused, **10 landed — and those 10 put `Mmax` at 185,710.7 against a bound of 135,113 (0.17188 × the 786,065 field he had grown) = 137% of the ceiling.** The budget is doing plenty of work and still fails, because **`while (mcur < budgetMx)` is an ENTRY test: it checks the plate is under budget BEFORE adding, so one victim of ANY size gets through on a fresh plate.** A ~10,000 M☉ seed clears a ~73 M☉/frame budget without the budget ever being consulted about its size. Refusal rate 99.5% is not a bound; it is a lottery with a 0.5% ticket. ⭐ **THE FIX IS ONE CHARACTER OF SEMANTICS, NOT A NEW MECHANISM: make it a FIT test.** Budget on **headroom to the ceiling** (`mBound − mS`), claim only if it fits whole (`mcur + myMx <= budgetMx`), and the overshoot is exactly zero — merges stay free below the ceiling so the runaway to one giant is untouched, and a refused merge leaves the victim alive and orbiting with mass conserved. A BH↔BH merger is DYNAMICAL, not viscous; `MDOT` has no physical claim on it. **This was written, then removed on his order to route through the CAS verbatim — the CAS route has now been given its run and measured at 137%.** ⚠️ Also visible in the same run and NOT yet explained: his *"the mass doesnt add up — two huge mergers colliding and bh size is still the same"*. `hole=0.62` while `Mmax` grew 15,152 → 185,710, so the **visual** hole is not tracking the mass. Do not conflate with the bound; it is a render question (see NOT-A-HOLE). | 🚨 **CAS route MEASURED AT 137% OF THE CEILING — needs the fit test** | `particles.metal:1481` entry test; `/tmp/killtube_play.log` `mrg=1902/10/1892`, `Mmax=185710.7`, `Mlive=786065` | **S** |
| **A1″** ⭐ | 🔨 **ROUTED THROUGH THE CAS — SHIPPED 2026-08-13 00:13:41, AND THE GATE HAS NEVER ONCE FIRED.** `particles.metal:1481` now claims its meal with the same compare-exchange, the same `MDOT·dt·fFb` budget and the same `F_BH_CLUSTER` taper as the star capture at `:1398`; the plain `atomic_fetch_add` on word 0 is gone, so a refused merge leaves the victim alive and orbiting and mass stays conserved. **VERIFIED LIVE 2026-08-13 00:41:58** (`/tmp/killtube_a1pp2.log`, bundle 00:32:17): an idle run parked at **`Mmax` = 101,800.1 against the 102,144.2 bound = 99.66%**, flat, 691,137 stars eaten (`live` 1,999,989 → 1,308,852), `Mlive` drift **−105 (−0.018%)**, **zero doubling steps** — the same endpoint as the pre-change reference (101,799.9), reached by accretion alone. 🚨 **BUT THE FIX ITSELF IS UNPROVEN: a temporary gate counter read `mrg=0/0/0` for the whole run — not one merge attempt reached the CAS.** The path needs a run that actually attempts a merge before this can be called done. ⚠️ **TWO OF MY OWN CLAIMS FROM THAT NIGHT ARE RETRACTED, both killed by the same counter:** (1) *"thousands of 50 M☉ stars enter the merge CAS every frame and starve the capture path through the shared plate word"* — measured false, `mrg=0/0/0` and `cap=195/0` (zero capture refusals) early in the run; the plate was never poisoned. The likely reason no ordinary star qualifies is that the IMF cap PRINTS as `Mmax=50.0` at `%.1f` but sits just under `M_BH_SEED = 50`. (2) *"the CAS route stalls the hole at 1,772 M☉"* — a real measurement of a real run (`/tmp/killtube_a1pp.log`), but NOT caused by this change, which never executed; that run bootstrapped **8 minutes late** into an already-diffuse field (`maxR` at the 100 cap) and the seed had no fuel near it. **RULE: bootstrap timing is stochastic — the first star to cross `M_BH_SEED` took ~40 s, ~90 s and ~8 min across three runs of identical code. One run is never evidence about the endpoint.** ⚠️ Also: the refused-capture counter WRAPPED uint32 inside 8 minutes (read 4,166,952,052 then 3,526,022,258) — refusal at the ceiling is constant, so never read that kind of counter as an absolute. — ORIGINAL ROW BELOW, kept for its evidence: 🚨 **THE SEED↔SEED MERGE IS UNBUDGETED AND WALKS STRAIGHT THROUGH THE BOUND — CAUGHT IN THE ACT 2026-08-12.** The star-capture path claims its meal with a compare-exchange against `budgetFx` (the viscous rate limit × the `F_BH_CLUSTER` taper) at `particles.metal:1398`. The seed↔seed path at **`:1481` adds to the SAME plate word with a plain `atomic_fetch_add` — no budget read, no CAS, no taper.** Both the 2026-08-08 rate limit and the 2026-08-11 bound are invisible to it. **MEASURED:** in the 21:46 run, one frame after a million stars had been refused by the budget, `Mmax` went **32,383.6 → 64,767.2, exactly 2×** — two equal seeds merging, straight past the ceiling. Also the mechanism behind the old 84,592 endpoint (+33,849 then +13,581, each landing exactly on a `seeds` N→1 collapse in `/tmp/killtube_bound.log`). ⚠️ **Second-order effect nobody costed:** it writes the same word the capture CAS reads as its budget, so a merge **starves the budgeted path for the rest of that frame**. **Fix is the same shape as the capture path: route `:1481` through the CAS.** Refusing the merge leaves the victim alive and orbiting, so mass stays conserved exactly and it merges later. | 🚨 **shipped 2026-08-13 00:13:41 · GATE NOW EXERCISED AND IT DOES NOT BOUND: `mrg=1902/10/1892`, `Mmax` 137% of the ceiling** | `particles.metal:1481` vs the CAS at `:1398`; `/tmp/killtube_a1pp2.log` (bounded, `mrg=0/0/0`); `/tmp/killtube_a1pp.log` (the 1,772 run); `/tmp/killtube_gate.log` t=355s; `/tmp/killtube_bound.log` | **S** |

<!-- ——— archived from BOARD.md lines 681–683 ——— -->

| **A1′** | ✅ **FIXED 2026-08-08 03:52, VERIFIED BY LOG (not by eye).** ⚠️ **Read with A1′-endgame directly above — "field survives" was a snapshot, not a steady state.** Viscous accretion rate limit shipped in `4816056`. **Measured 2,451 M☉/wall-s against a derived cap of 2,517 → 0.97×**, with consecutive `Mmax` deltas `10349·10451·10525·10385·10421·10552·…` — **dead constant, i.e. LINEAR.** The M² divergence is gone **by construction**: `T_isco ∝ M` makes the ceiling mass-independent. **Field survives: `live = 1,273,268` (64%) at `Mmax = 215,829`**, `Mlive` conserved to −107 — pre-fix was `live = 19` at the same stage. ⭐ **Every number derived from our own telemetry:** `h/r = c_s/v_φ` gave **0.746** (inner) and **0.771** (mean) from temperatures 12× apart — agreeing to 3%. Scale check: measured `orbV 0.4092c` vs ISCO theory `0.4082c`, **0.23%**. ⚠️ **OPEN:** did it lengthen the pre-formation fuse? Post-fix 16+ min and 8 min vs pre-fix 30 s / 4.5 min / 10 min — 8 min is *inside* the old range, so no evidence either way at n=2. If it did, apply the limit only above 5000 M☉. | ✅ log-verified 🔨 unseen | `docs/MEASURED_2026-08-08_A1_runaway_cause.md`; `particles.metal` rate-limit block | done |
| ~~A1′-cause~~ | ✅ **CAUSE FOUND 2026-08-08 01:37:02.** At **`mS > 5000` M☉ the capture radius stops being capped** and becomes `rc = 3·r_s`, which is **linear in mass** — so cross-section ∝ M² and **dM/dt ∝ M², a finite-time blow-up.** The growth regime below 5000 **is** capped (`min(rt2, reach²)`, `reach = 1.4·cellSize ≈ 0.066`); the formed regime has **no `min()` at all**. At the measured peak the capture radius is **2.8 sim units vs `R_DISK = 18`** — 1,830× the capped area. ⭐ **Proof in the logs we already had: ZERO samples between `Mmax` 480 and 320,000.** It sat at 475 for 95 samples then jumped straight to 322,919 — five orders of magnitude between two samples, which is exactly the `M²` signature. **Also explains the 30 s vs 10 min variance:** a slow stochastic fuse (50→5000, capped) then a detonation of fixed duration. 🚨 **The uncapped radius is a RENDER number doing a PHYSICS job** — `3·r_s` was chosen so the disk inner edge and the lens shadow track together, so capping it naively will bring back the two-layered-bodies artifact. **Capture radius and shadow radius must become two separate numbers.** No feedback/Eddington term exists anywhere. | ⬜ fix not chosen | `docs/MEASURED_2026-08-08_A1_runaway_cause.md`; `particles.metal:1225-1252` | **S**–**M** |
| ~~A1′-old~~ | ~~**RUNAWAY ACCRETION — THE SIM EATS ITSELF.**~~ At 1×, silent, no input, a body crosses 50 M☉ and then consumes the entire field. **3/3 runs, 2 independent realizations.** Mass is conserved throughout, so this is real mass eaten, not minted. **The show-relevant part: the field's lifespan is unpredictable — between 30 s and 10 min.** Same spawn seed gave 10 min once and 30 s the next, so the *evolution* is nondeterministic even though the spawn is not (very likely GPU atomic ordering in the hash/merge path — **stated as the likely cause, not proven**). ⭐ **This re-reads his old screenshot:** the "almost empty field, disk gone, handful of bright points" was recorded in §7 as *nothing accreted*. It is the opposite — **everything accreted.** That frame is the end state of runaway. | ⬜ **NEW** | see the run table below | **M** |

<!-- ——— archived from BOARD.md lines 699–699 ——— -->

| ~~A4-orig~~ | 🐛 **RELEASE IS A ONE-FRAME DISCONTINUITY — HIS EYES, 2026-08-09.** *"after play when i release it kinda jumps into the next phase, it's not a smooth transition, like another thing was at work. post play for a split sec."* **Confirmed in source and it is literally several things at once.** `envelopePhase` is branched on at **27 sites** in `particles.metal`, all hard thresholds, **none blended**. Crossing 3.5 flips at minimum: `:780` friction hard-sets `pow(0.95,dt)` (normally `mix(pow(0.99,dt), pow(0.9,dt), amp×4)` — so coming out of a loud sustain, damping *drops* and everything suddenly moves more freely); `:664` `sustainHeld` goes false and the rebirth stream cuts dead mid-flow; plus branches at `:839` and `:2758`. **The fix is a ramp across the boundary, not another branch.** ⚠️ Do not "fix" it by adding a fifth branch — [[feedback_a_toggle_is_not_a_fix]]. | ⬜ **NEW — on screen every single play** | `particles.metal:780`, `:664`, `:839`, `:2758`; 27 sites total via `grep -n envelopePhase` | **S**–**M** |

<!-- ——— archived from BOARD.md lines 703–703 ——— -->

| ~~A7-orig~~ | 📉 **FPS DEGRADES OVER A RUN — UNEXPLAINED.** One run walked **57 → 38 fps over 10 minutes** with no input and a field that was barely merging (`live` 2,000,000 → 1,999,993). Run 2 at 10M sat at median 31 with 35.8% of samples under 30. 🚨 **Matters directly for Berlin: `dt` is per-frame (`renderer.mm:1339`), so a sagging frame rate silently slows the physics mid-set** — and it is how a null result gets manufactured ([[feedback_trust_the_average_not_transients]]). Not diagnosed. | ⬜ **NEW** | `logs/A2_refund_20260809_110828.log` (the 57→38 walk); `A2_refund_20260809_202105.log` (median 31) | **?** |

<!-- ——— archived from BOARD.md lines 706–744 ——— -->

### 📊 A1′ — THE MEASUREMENT, 3 STACKED RUNS (2026-08-08 00:05:09)

He called the first result shaky and was right — one run, and this project **bans single-run claims**.
Stacked. All runs: **1× time warp, silent, zero input**, deployed binary (bundle `2026-08-06 15:28:21`,
no source newer, nothing rebuilt).

| Run | Seed | Crossed 50 M☉ | Peak `Mmax` | `seeds` | `live` at stop | `Mlive` | `feed`/`scan` |
|---|---|---|---|---|---|---|---|
| Soak | 42 | ~10 min | **331,425.6** | 2 | 2,000,000 → **19** | 594,276 → 593,975 (−301) | 0 / 0 |
| Re-test | **7** | ~4.5 min | **12,329.6** | 2 | → 1,949,108 (early stop) | 594,276 → 594,270 (−6) | 0 / 0 |
| Re-test | 42 | **~30 s** | **557,451.0** | 1 | → 123,007 (94% eaten in 2 min) | 594,276 → 593,973 (−303) | 0 / 0 |

**What is established:**

1. **Runaway is the physics, not one realization.** Seed 7 is an independent spawn and does the same thing.
2. **Timing is wildly nondeterministic** — the same seed 42 took 10 min once and 30 s the next. The
   spawn RNG is fixed (`particles.cpp:23`, `spawnSeed = 42`), so the divergence is downstream, in the
   evolution.
3. **Mass is conserved under runaway** — −301, −6, −303 M☉, all consistent with the known −280
   residual (B5). The 08-04 conservation fix holds. The hole is eating real mass, not minting it.
4. **`feed=0/0.0 scan=0` in every run ever logged.** All growth comes through `merge_stars`; the
   seed-feed path has **never scanned once**. That half of §7 survives and is now better evidenced.
5. **A2's precondition is finally met** — seeds exist and there are ~1.9M corpses to refund. The test
   that has been blocked for three handoffs is runnable. **It needs him to hold a note.**

**Method notes, for whoever repeats this:**
- ⚠️ **Two instances cannot coexist.** A parallel attempt had its second instance die silently at
  ~90 s with no crash message. Run serially. `tools/a1_watch.sh <seed> NEW` does one run with early
  exit and aborts as INVALID if the instance dies, so a starved run cannot masquerade as a negative.
- ⚠️ **`dt` is per-frame, not wall-clock** (`renderer.mm:1339`), so anything that costs FPS costs sim
  progress. The logs carry `FPS:` — check it before trusting a null result.
- 🚨 **Never test this above 1×.** §7's tunnelling arithmetic is correct: at 64× a star moves ~127
  contact radii per frame and the merge test can never fire.

**Free confirmation, from instrumentation that already exists:** `[KPROBE-SCALE] size px:
0.92:99.3%` — **C3's "99.2% of stars pinned to one pixel" is real and now measured at 99.3%.**

---


<!-- ——— archived from BOARD.md lines 812–1000 ——— -->

## WORKLOAD PER SECTION

**These are estimates, not measurements.** Nothing below was derived from a log or a timing. The one
number that IS grounded in the record is C3 — see the note under section C. Treat the totals as a
shape, not a schedule.

**Unit:** one **session** = a block where I build and he verdicts. Roughly:
`S` = half a session, one change and one verdict · `M` = one session · `L` = 2–4 sessions, needs its
own dedicated block · `?` = cannot be estimated until something is measured or he answers a question.

| Section | Open rows | S | M | L | ? | **Est. sessions** |
|---|---|---|---|---|---|---|
| **A — Blockers** | 5 | 3 | 2 | 0 | 1 | **≈ 3.5** + 1 unknown |
| **B — Physics** | 8 | 3 | 2 | 2 | 1 | **≈ 9.5** + 1 unknown |
| **C — Visual** | 9 | 3 | 2 | 2 | 2 | **≈ 10** + 2 unknowns |
| **D — Audio** | 3 | 2 | 0 | 1 | 0 | **≈ 4** |
| **E — UI** | 4 | 2 | 1 | 1 | 0 | **≈ 5** |
| **TOTAL** | **29** | 13 | 7 | 6 | 4 | **≈ 32 sessions + 4 unknowns** |

### What each section's total is actually made of

- **A ≈ 3.5.** Cheap in isolation and it is the whole BH track's gate. A1 (M) is the only real work;
  A2 is a *test*, not a build; ~~A3③ is a one-line latch condition~~ — **corrected 2026-08-08 16:31:44:
  A3③ is NOT a one-line fix. The one line is a no-op (measured); the row is now a scale decision he
  has to make.** **A3② has a split cost** — the
  `if (false)` takes minutes to unlock, but nobody knows what the honest centring rule should be, and
  that is the unknown in this row. Best return per session on the board.
- **B ≈ 9.5, and two thirds of it is two rows.** B6 (corpse compaction) and B7 (kill the tube) are
  both `L` and both structural. B6 also *conflicts* with the refund — `imfMassOfId(id)` needs slots
  never to move. Everything else in B is small. **B8 is an unknown because he has not said what he
  means**, not because it is hard.
- **C ≈ 10, and it is the least trustworthy total here.** Two rows are `?` (C7's fix, C11) and one is
  evidence-corrected upward. This section is his stated priority and it is also the section where the
  estimates are weakest, because the two headline items are undiagnosed.
- **D ≈ 4, but it is 1 small + 1 small + 1 large.** D6 and D3 are both `S` and both unblock things.
  D1 is the whole feature and is `L`. The track is at literally zero code, so there is no partial
  credit banked anywhere.
- **E ≈ 5.** E5 alone is `S` and pays back into A1/A2 by making them visible. E1 is the `L`.

### ⚠️ The estimate I corrected

**C3 (star size floor) was `M` — it should be `L`.** The record says 4 attempts, 0 progress, all
reverted. An item that has already consumed four attempts is not a one-session item, and calling it
one again would be repeating the mistake that produced those four. The `L` in section C's row is
C3 and C4. The standing instruction on it — **build the dials first** — is the reason: the work is
not "change the size", it is "make size dialable so we can find the right one".

### ⚠️ What these totals do NOT say

**≈32 sessions does not fit in 26 days at any believable pace.** That is the useful finding here.
This board is not a list to finish before Berlin — it is a list to **triage**. Anything not on the
Berlin path below is post-Berlin work by default, and saying so now is cheaper than discovering it
on 2026-09-01.

---

## 🔎 DISABLED-CODE SWEEP — 2026-08-07 12:41:25

He asked for this **before** the handoff and I did it after, having been caught by C4. Full sweep for
`if (false)`, `&& false`, `#if 0`, and dead-by-comment markers across `src/`.

**17 hard-disabled blocks. 10 are ImGui panels removed 2026-06-26** — deliberate, documented, not
hidden work. **7 are in the physics/render path**, and they are not all the same kind of thing:

| # | Where | What | Kind |
|---|---|---|---|
| 1 | `postfx.metal:421` | Camera motion blur (**C4a**) | 🔨 **built, recoverable — bug** |
| 2 | `renderer.mm:2959` | ORIGIN LOCK — COM refinement (**A3②**) | 🐛 **bug** |
| 3 | `particles.metal:863` | **DENSITY PRESSURE** (**B10**, new) | ⏳ **unfinished TODO** |
| 4 | `renderer.mm:3470` | Dust extinction pass | ✅ his verdict, parked |
| 5 | `renderer.mm:3533` | Analytic arc trail ribbons | ✅ his verdict, correctly dead |
| 6 | `particles.metal:2293` | Elastic shell restoring force | ✅ deliberate, documented |
| 7 | `particles.metal:2856` | Direct envelope→radius coupling | ✅ deliberate, documented |

**Verdict: 4 of the 7 are correct.** They are his own calls, each with the reason and a restore path
written next to it — dust extinction (*"a low-res shadow thingy / yellow underbelly"*, 2026-07-23),
the arc ribbons (*"fake trails centered to a tube shape"*, 2026-06-25), and the two cymatics blocks
that were preventing particles from flowing through the sphere. **Do not "fix" any of these four.**
The dust-extinction *concept* is explicitly retained for the BH overhaul once depth ordering exists.

**Three were worth finding: one bug, one recoverable feature, one abandoned TODO.**

### Also confirmed dead, and NOT on the board before

- **`render.metal:589` is unreachable in every configuration.** It needs `cam.bhDiskAxisY > 0.5f`,
  and `renderer.mm` assigns `bhDiskAxisY = 0.0f` at **every** assignment site (`:1551`, `:1589`,
  `:1592`) plus the header default (`renderer.h:200`). Both the posed and emergent branches select
  the z-axis block at `:539` instead. It still carries the **old absolute-angle form** that was
  removed from its live twin. ⚠️ **If it is ever revived, port the integrated phase in FIRST** — as
  written it reintroduces the counter-rotation drift.

### ⚠️ A board row this sweep contradicts

**B3 says the bit4 origin-pin blocks multi-BH. bit4 ships OFF.** `app_state.h:48`
`uiTogOriginPin = false`, packed at `main.cpp:2135`, and the only things that can turn it on are the
UI checkbox (`main.cpp:1260`) and the `SS_INERT_KEEP` diagnostic ladder (`main.cpp:270`). **In the
default launch configuration that spring does not run**, so it cannot be what pins the hole to the
origin in normal use — the ORIGIN LOCK at `renderer.mm:2959` is, and that one is unconditional.
**B3's premise is re-opened, not confirmed.** See the row.

### The pattern

Two of the three findings were features that got **built → hit a bug → switched off → recorded as
"not started"**. That is how C4 ended up ⬜ on this board. The lesson from the change log holds and
now has a second and third data point: **a row without a `file:line` is a rumour.**

---

## 🎯 TRIAGE — HIS CALL, 2026-08-07 12:24:09

> *"A B C these are the most important for the show"*

**Sections D and E are post-Berlin by his decision.** Do not spend a session there without asking.

⚠️ **One exception flagged to him at the time of the call: D6.** It sits in section D but it is a
*show* item — `Synth::processBlock` takes a blocking `lock_guard` on the RT audio thread
(`synth.cpp:90`). If it stalls mid-set the audio drops on stage. It is an `S`. It is **parked, not
dismissed**, and it stays parked until he says otherwise.

### A/B/C alone is still too big

A + B + C = **≈23 sessions + 4 unknowns** against 26 days. Narrowing to three sections does not
close the gap on its own, because **6 of B's 9.5 sessions and 3 of C's 10 sit in rows that never
appear on screen.** The cut has to go one level deeper.

### The deeper cut — what actually serves a stage

**A — all of it. ≈3.5 sessions.** No cut. It is the gate on the entire BH track and it is the
cheapest section on the board.

| Keep in B | Why | Cost |
|---|---|---|
| B2 `RADIAL_MAX_R` cutoff | the seed leaves the measuring window — serves A3② | S |
| B3 bit4 origin-pin | unblocks B4 and the pull gate | M |
| B4 pull-gate step 2 | the interaction he specified | M |
| B5 −280 M☉ drift | small, and mass books should stay exact after the refund | S |
| B9 merger flash invisible | a merger you cannot SEE is not a show event | S |

**Deferred out of B: B6, B7, B8 — ≈6 sessions.** B6 (corpse compaction) is a perf/architecture job
that *fights* the refund. B7 (kill the tube) is a foundational rewrite. B8 is undefined. **None of
the three changes what the audience sees on 2026-09-02.**

| Keep in C | Why | Cost |
|---|---|---|
| C7 Cartwheel delta | the single biggest visual delta, and his own 02:55 call | ? — measure first (S) |
| C3 star size floor | 99.2% of stars are one pixel; nothing pre-FX looks cinematic until this moves | L |
| C8 Chladni sharpness | *"almoooost"* — ask what sharp means first | M |
| C5 chromatic aberration | currently a flat radial offset, not a lens | M |
| C6 scanlines | rebuild or remove — right now it is aliasing, not an effect | S |
| C9 bit18 dead arc | `sL ≡ 1`; **delete it** rather than revive it before a show | S |
| C10 build warnings | `render.metal:485` is real | S |

**Deferred out of C: C4b, C11 — ≈3 sessions.** C4b (per-particle motion vectors) is `L` and its real
blocker is an unmade design decision about which particle owns a pixel's vector. C11 has no defined
starting point.

**↩️ PULLED BACK IN — C4a, `S`, 2026-08-07 12:31:07.** He asked *"we started motion vectors didn't
we"* and he was right; my ⬜ came from the 08-02 doc, not from the code. The camera half is **built
and running** — only its consumer is switched off, behind a documented bug with a specific cause
(`postfx.metal:432` tonemaps blur samples with **ACES** while the base pixel is already through this
pipeline's own tonemap *and* the grade LUT). Re-enabling it is a matched-sampling fix, not a build.
⚠️ **Do NOT fix it by reintroducing `acesTonemap` anywhere** — the live tonemap is deliberately not
ACES. Berlin cut is now **≈14 sessions.**

### What the cut leaves

| | Sessions |
|---|---|
| A (all) | ≈3.5 |
| B (kept) | ≈3.5 |
| C (kept) | ≈6.5 + C7's unknown |
| **Berlin total** | **≈13.5 + 1 unknown** |

**≈13.5 sessions in 26 days is plausible.** ≈23 was not. The deferred ≈9 sessions are all still on
this board — they are post-Berlin, not cancelled.

---

## THE TWO PATHS

**Shortest path to a working black hole:** ~~A1 → A2 → A3①~~ → **corrected 2026-08-08 17:04:19: A1 ✅ → A2 (his hands, no code needed) → A3② the ORIGIN LOCK → A3① as follow-up.** A3① was measured non-binding; A3② is what actually controls whether the hole can un-form. Nothing else in the BH track is testable
before A1, because no body has ever crossed 50 M☉.

**Shortest path to Berlin (26 days):** C7 and C3 carry the most on-screen return. E5 is cheap and
makes the BH work verifiable by eye. **D6 is the only item that can take down a live show** and it
is an `S`.

---


<!-- ——— archived from BOARD.md lines 1060–1073 ——— -->

## CHANGE LOG FOR THIS FILE

| When | What |
|---|---|
| 2026-08-11 15:30:00 | **THE DEPTH SPRINT — P1 AND P2 BOTH SHIPPED, PLUS THE BLENDING OVERHAUL HE ORDERED.** ⭐ **§H8 — the project WRITES DEPTH for the first time** (own texture, `storeAction=Store`, proven encoding by a one-shot print rather than assumed). Verdict *"looking identical"* = pass, since it was built to change nothing. It unblocks P1, C4a (whose blur unprojects at a hardcoded `z=0.99` **because nothing was readable**) and C4b. ⭐ **§H9 — COVERAGE RESOLVE, his verdict "looking good".** The star pass had been computing a correct coverage term `C = 1−Π(1−aᵢ)` in its alpha channel **for months and discarding it**; A9's *"density can only add light"* was true of the RGB channel ONLY. Resolve `S·C/(−ln(1−C))` is derived, zero free parameters, and **identity in the sparse limit** so the look he likes is untouched. It also **proved A3②-white independently**: the mergers did not change under it, therefore they are single billboards, not dense piles. ⭐ **§H10 — P2, in four steps, TWO of them my own regressions** (a per-frame zoom number turned per-particle; a dormant near-clip fade resurrected into deleting matter). Step 4's first version **normalised by the CAP and was wrong by ~15×** — his *"exact same look, unchanged"* caught it; the fix uses the **MEASURED `meanR`** and deleted a constant duplication in the process. ❌ **Chladni still reads flat and he named the cause: the tube. B7 PROMOTED** from deferred `L` to the live suspect, with a measurement gate before any rewrite. **Also added: C12 (Doppler reopened by his order — four errors identified, colour must shift TEMPERATURE not tint), and three standing rules** — mechanism-vs-goal for "never again" verdicts, pixel-neutral batching, and **"feeding a real value into a long-constant variable activates every dormant consumer of it."** |
| 2026-08-11 12:31:44 | **§H VERIFIED AGAINST SOURCE, AND THE REGISTER DID NOT COME THROUGH CLEAN.** All ten rows re-read. **8 confirmed, 1 refuted (P6 — the fix is a NO-OP: `cam.bhX/Y/Z` are hard-zeroed by the ORIGIN LOCK, so "re-centre on the hole" re-centres on the origin; 4th no-op fix on this board), and EVERY line number downstream of the 04:11 deletions was WRONG** by exactly the deleted line count (`render.metal` −34, `renderer.mm` −227). The register was written at 11:48 from pre-deletion readings — **the A0i decay rule broken inside the session that caused the decay.** Two claims strengthened beyond what was written: **the depth buffer is allocated, cleared every frame, never written and thrown away unread** (`storeAction = DontCare`), and **`cameraPos.w` is `cameraRho`** — one scalar per frame for all 2M particles. ⭐ **HIS QUESTION ANSWERED AND IT RAISES P1's VALUE: the motion-vector work IS blocked on depth.** C4a hardcodes `z=0.99` *because* post-FX has no depth texture to read, and C4b is blocked outright — so P1 buys occlusion **plus** a correct camera blur **plus** the TAA precondition (§H1b). **SHIPPED (§H7):** P5's comment, two false "off-origin" comments, P6's refutation at the code site, **C7b deleted**, P7 audited in place, `EIGEN_R` fixed, and `[GRIDPROBE]`'s scan radius corrected ±6 → ±9. Bundle `12:06:17`. **All pixel-neutral by construction; the falsifiable claim is that the screen is identical to `04:15:06`.** |
| 2026-08-11 11:48:24 | **§H ADDED — THE PSEUDO-3D REGISTER**, at his direct order. Ten ranked sites where the render fakes 3D, with `file:line` on each. **The headline is a negative: CHLADNI IS NOT FAKING 3D** — `pAx = 2 + ((mm+nn)%3)` is never 0, so `k_z > 0` always and the field genuinely varies along z (§H2). The fakes are all in the render and cluster in the black hole; the two structural ones are **no depth write** (`renderer.mm:1033`) and **no per-particle depth in ortho** (`render.metal:1257`). Also logged: **five dead ends cut and ONE REFUSED** — the 32-per-cell scatter cap is a load-bearing design limit, not dead code, and changing it creates mass. And the **frame cost model**: the star pass he named as the real problem is **2.4–3.3 ms**, the Poisson solver is **~6 ms**. **Two of my own claims corrected in §H5** — the hole is no longer ortho-gated, and my "SOR is not the monster" was written off 9 samples and is wrong. Bundle 04:15:06, **his verdict: stable 60 FPS.** |
| 2026-08-08 15:37:02 | **SESSION CLOSE.** `b047744` → **`4816056`, 12 commits** — three weeks of uncommitted work committed, plus everything below. **A1′ FIXED and log-verified at 0.97× of a fully derived rate**; **N measured (250k, 2M infeasible)**; **C7 diagnosed** (not a colour bug — its law exists and was gated on a horizon that only appeared during the blow-up, which A1′ now breaks). Handoff: `HANDOFF_2026-08-08_board_a1_fixed_n_measured.md`. ⚠️ **Three things await his eyes: the live-UI panel (uncommitted), A1′ on screen, and A2's refund test — which is runnable for the first time in four handoffs.** New standing rule recorded: **report ceilings as the cost of the current formulation, never as the design constraint** (`feedback_limits_are_perceptual_not_technical`). |
| 2026-08-08 00:05:09 | **A1 REFUTED BY MEASUREMENT, 3 STACKED RUNS.** Accretion is not dead — it **runs away** and eats the whole field at 1× silent, in 2 independent realizations, with mass conserved. The old "zero mergers ever" came from a 64× run where tunnelling really does prevent merging; nobody had run 1× silent long enough. A1 closed, **A1′ opened**: the sim self-destructs on an unpredictable clock (30 s to 10 min, same seed). His old "empty field" screenshot was misread by §7 as *nothing accreted* — it is the **end state of everything accreting**. **A2 is finally unblocked.** He was right to call the single-run version shaky. |
| 2026-08-07 12:41:25 | **DISABLED-CODE SWEEP** — the thing he wanted done *before* the handoff. 17 hard-disabled blocks; 10 are removed ImGui panels, 7 are in the physics/render path. **4 of the 7 are his own correct verdicts with restore paths written next to them — do not touch.** 3 were worth finding: C4a (recoverable), A3② (bug), and **new row B10, DENSITY PRESSURE — an explicit "re-enable in a later step" TODO that was never done.** Also newly recorded: `render.metal:589` is unreachable in every configuration (`bhDiskAxisY` is `0.0f` at every assignment site). **And the sweep contradicted a board row: B3's bit4 origin-pin ships OFF, so it cannot be what pins the hole in normal use — premise re-opened.** |
| 2026-08-07 12:31:07 | **He was right and the board was wrong: motion vectors WERE started.** I had marked C4 ⬜ with "08-02 doc" in the evidence column — hearsay by this file's own standard, and the one row I did not read the code for. Split into **C4a** (camera half: BUILT and running, consumer disabled behind the board's *second* `if (false)`, bug diagnosed to mismatched tonemaps at `postfx.metal:432`) — `S`, **pulled back into the Berlin cut** — and **C4b** (per-particle, genuinely not started, still `L`, still deferred). **Lesson: a row without a `file:line` is not a status, it is a rumour.** |
| 2026-08-07 12:24:09 | **His triage: A, B, C are the show. D and E are post-Berlin.** Added the TRIAGE section. Because A+B+C is still ≈23 sessions vs 26 days, cut one level deeper: deferred B6/B7/B8 and C4/C11 (≈9 sessions, none of them visible on stage), leaving **≈13.5 sessions**. D6 flagged to him as a show-risk exception living in a deferred section — **parked, not dismissed.** |
| 2026-08-07 12:18:44 | Added **WORKLOAD PER SECTION** at his request. Totals ≈32 sessions + 4 unknowns against 26 days — recorded explicitly that this board is a triage list, not a finish list. One estimate corrected on evidence: **C3 `M` → `L`**, because an item with 4 reverted attempts on the record is not a one-session item. |
| 2026-08-07 12:02:31 | Created. Every A/B/C row re-verified against source at commit `3a36438`; D and E verified as zero-code. Two corrections to the inherited docs recorded: A3② is an `if (false)` ORIGIN LOCK (blunter than "the profile is centred on origin"), and B1 is not a separate item — it IS A3②. C7's half-space lead is explicitly downgraded to undiagnosed: the only surviving `half-space` mention in the renderer is a *removed* gate. |

---

## 🗄️ §BH-STAMPS — `docs/BOARD_BLACKHOLE.md` line 11, the 15 chained earlier re-stamps. Moved 2026-09-03 16:10:00.

**Verbatim, nothing reworded.** These were a single 12,801-byte line; the current `74bee76` stamp stayed on
the board and only the `Previously ...` chain (9,816 B) moved. Read only for provenance of when a finding was
folded in — every finding itself has its own row on the live board.

Previously `dbda8e8` ⭐ **RE-STAMPED 2026-09-03 05:16:00 — SESSION 2026-09-03 FOLDED IN AS §AD (read it FIRST, then §AC.12). ✅ **σ IS PINNED BY MEASUREMENT** — coded/honest = **297.12-297.36 = 1/cFrame² exactly** on 31/31 samples; weighting is only **W 1.075-1.587**, so §AC.2's ~13× was the UNIT factor and is CLOSED. **His cap is now derivable — derive it, never a clamp constant.** 🚨 **THE VISIBLE LENS IS A SCALE KNOB (×297), NOT A LAW** — the honest law draws NOTHING (region 5.2 r_s = 0.08 sim vs matter at 360 r_s); his verdict *"theres no lense at all now lol u overdid it"*; reverted and labelled. **Step 2 is SCALE work, not lens work.** 🏆 **THE STAND-OFF HOLDER IS NAMED** — the rest-state velocity sink chain (`particles.metal:3375`), whose exemption is earned only by TANGENTIAL speed, so **a stopped body is stopped BY CONSTRUCTION**. 🚨 **THE ≥50 M☉ HOLDER IS STILL UNIDENTIFIED** — 9 candidates eliminated, force probe **NO GO** from him. 👁️ **HIS "MERGER" IS 5-50 M☉, NOT `M_BH_SEED`** — every instrument counted a population he was not looking at. ⚠️ **8 SOURCE COMMITS THIS SESSION (`9a04ab0`..`dbda8e8`) — LINE NUMBERS BELOW `particles.metal:1461` ALL MOVED ~69 LINES. Re-grep; never re-derive by arithmetic.** ⛔ BRAIN retraction: the launch collapse is **FREE-FALL, not a scripted drain** — every force in the PHASE 0 block is disabled. Previously `9f61c66` ⭐ **RE-STAMPED 2026-09-03 00:36:00 — §AC.11 ADDED (FABLE): THE σ SPLIT IS HALF-PINNED BY READ. `[CLUSTER] speed avg` is **v/c, dimensionless** (`particles.metal:4391-4393`); the KE reduce is **mass-weighted ½m|velW|² in (sim/frame)²** (`:4363`); the law consumer `bInflLive = M/(4·KE)` (`renderer.mm:4759`) applies c²/(2σ²) **with c=1 in velW units, but c in velW units is `kCSimPerSec·dt` ≈ 0.0293 sim/frame at 120 fps** — so the coded region also scales as **1/dt²**: frame≠time dress candidate #12 is REAL at the units level. The same-frame probe (one particle's v² vs both aggregates) is still the required MEASURE before any cap is derived — the weighting half (count-mean-|v| vs mass-RMS) is unmeasured. NO SOURCE CHANGED — basis still `9f61c66`.** Previously ⭐ **RE-STAMPED 2026-09-03 00:27:00 — §AC.10 ADDED (BRAIN): THE INFLUENCE REGION HAS NO CEILING. His words: *"lense lowkey explodes until the entire field is gone it lokey needs a cap"*. Measured on two runs from a `9a62447` bundle: split on the REAL gate (`bhStrength >= 1.0f`, not the sticky LATCH label), r_infl reaches **193.59 while the lens is DRAWING** and 794.17 at any time, against a design region of ≈20 — and swings 7× run-to-run on identical code. `infl` hits 27406, so the §AC.2 σ split is wider than the boarded 3800–4960. HIS ORDER: *"fable pin the sigma split first then derive the cap"* — the σ pin is now the PREREQUISITE of the cap. ⚠️ §AC.6 (two-circles GEOMETRY) still carries NO verdict. NO SOURCE CHANGED THIS SESSION — the source basis is still `9f61c66`.** Previously ⭐ **RE-STAMPED 2026-09-02 19:58:00 — THE EVENING LENS SESSION IS §AC (read it FIRST; BRAIN's same-evening rows are §AB.4b/8/9; OPUS's are **§AB.10 star capture**, the §AB.4b orbital-force row, and the §AB.6 correction). 🚨 **STAR CAPTURE REFUSES ~99.98% OF EVERYTHING IN REACH — 1,697,357 particles (85% of the field) are inside a seed's capture radius every rest frame and ~280 are admitted at 120 fps; every refusal is a SILENT `continue` with no counter (`particles.metal:1588`). The shipped `h/r=0.1` takes that to 1.26 stars/seed/frame (99.9997%) — the thinning and the capture starvation are the SAME DIAL, and three MDOT numbers in the comments are now wrong by 55.7×. His fps control (*"we have 120 there too"*) is right: rest runs ~162M cell lookups/frame that play skips entirely.** 💚 THE RING LIVES (`c30c3a8`, "i could cry"), the LENS REGION IS DERIVED by the influence law (`24c91ab`, "absolutely insane"), the EMA is wall-time + world-anchored (`2a0d804`), his 100% law gates the lens (`1ff86d4`), the two-circles plate-lens fetch is cut (`9f61c66` — NOT yet under his verdict). 🚨 infl measured 3800–4960 vs predicted 20–40: a ~13× speed-unit split between `[CLUSTER] speed avg` and the KE reduce, UNPINNED (§AC.2). 🔴 Open by his priority (§AC.8): boxy grid post-play · sweep-influence bound ("should take longer") · the shining stage (§Z15) · σ-unit pin. Only the §AC rows were read at `9f61c66`.** Previously `2a0d804` ⭐ **RE-STAMPED 2026-09-02 19:50:00 — BRAIN's session folded in as §AB.4b / §AB.8 / §AB.9. 🎯 THE SCALE AUDIT ANSWERED HIS QUESTION: the LENS is the honest half (r_s and the sim length unit are both DERIVED, units.h:39/:85) and `R_DISK = 18` is the FABRICATED one — its own comment says "SIZED TO THE CAMERA". The lens indexes r_s(HOLE), the disk is placed in r_s(FIELD); they agree only when the hole has eaten the field, and at 2.8% they are off 35× — his matter sits at 150 r_s while the region is 20. 🔒 MERGER STAND-OFF cause #1 FIXED (`66faa37`, dynfric self-drag, his eyes). 💚 THINNING SHIPPED (`c30c3a8`) — his best verdict yet, *"i could cry"*. 🚨 THE STAR LUMINANCE RAIL saturates at 5.54 M☉ and his eyes refute the ceiling dial as the fix — remaining glow source UNFOUND. ⚠️ FABLE's three lens commits (`24c91ab`, `1ff86d4`, `2a0d804`) are NOT yet boarded — FABLE's rows to write.** Previously `4fd2b6f` ⭐ **RE-STAMPED 2026-09-02 15:05:00 — SESSION 2026-09-02 (FABLE) FOLDED IN AS §AB (read it FIRST). 💍 THE POST-PLAY RING SNAP WAS THE bit20 TIME-LAPSE sweeping the WHOLE rest field the frame the first ≥50 M☉ seed formed — A/B-confirmed with his eyes, FIXED by his 100% law (`bhStrength >= 1.0` gate, renderer.mm), verified at a real horizon, COMMITTED (`5d98b7f` BRAIN's cap buffer, `4fd2b6f` the gate) and PUSHED on his order. ⛔ The Rick-and-Morty-eyes REJECTION stands — that was a different artifact; this closure is measured, not the old theory re-pitched. 🔒 NEW OPEN: his merger stand-off soft-lock (§AB.4).** Previously `f7973c0` ⚠️ **COMMIT-MESSAGE ERRATA (2026-09-02 09:44:00, OPUS's catch):** `32c4ce6`'s MESSAGE says "tilt <= 4.5 deg" (wrong — the measured H/R 0.139 IS arctan'd to **7.9°**; 4.5° double-converted) and cites the +Y orphans at the COMMENT lines (`:1210`/`:3290`-adjacent) — the executables are `:2380`, `:1217-1219`, `:3294-3296` (pre-session numbering). **§AA's body is authoritative over that message.** The failure is transcription-between-documents — the exact rot this session proved fatal. ⭐ **RE-STAMPED 2026-09-02 09:41:00 — SESSION 2026-09-01 FOLDED IN. 🚨 THE CHLADNI FIGURE MOVES AT THE PLAY SPEED CAP AT EVERY RADIUS (|d| = 1.1969 sim/frame, r = 25→70): the crystallization freeze is ARMED (H = 1.0000 for 100% of the field) and OVERPOWERED, and the outward drift is SECANT ERROR of cap-speed circular churn, not a force. 🚨 Beyond rho = 6 during play there is NO RADIAL FORCE AT ALL (`particles.metal:3409` states it; self-gravity is ×(1−playGate)). ⛔ THREE mechanisms died this session BEFORE being built — the axial z-wall, the sun-shell spring, the attack reduction.** ⚠️ `06982a0` (the previous handoff commit) is BUNDLED — titled docs but carries 5 source files; do not trust its title, it is the one-concern rule's counterexample. Previously `3672d89` ⭐ **RE-STAMPED 2026-08-31 21:52:00 — sources end at `3672d89` (`c793e4a` the lens-cost instrument, `3672d89` the gated harness). Everything after is docs-only and carries NO source change.** Previously `c793e4a` ⭐ **RE-STAMPED 2026-08-31 21:50:00 — the bracket SOURCE is now committed (`c793e4a` instrument, `3672d89` harness). §Z10 added: the per-frame counters were accumulating across frames until the clear moved onto the GPU. ⛔ BRAIN and I independently wrote a §Z7–§Z9 for this session; the duplicates were removed and BRAIN's kept.** Previously `230e953` ⭐ **RE-STAMPED 2026-08-31 21:39:26 — THE MEASUREMENT SESSION IS FOLDED IN AS §Z7–§Z9 (read those FIRST). 🚨 THE LENS HAS NO COST NUMBER AFTER THREE INSTRUMENTS, all three returning an IMPOSSIBLE NEGATIVE SIGN; the bracket times GPU OCCUPANCY, not the pass. 🚨 EVERY 08-31 MEASUREMENT IS `REST` ONLY — his correction; play returns matter and the sim is DRIVEN. ⭐ ~95% of the field is eaten in 4 IDLE minutes and the rest-rate is HIS verdict, unt aken.** Previously `90e9b6c` — SESSION 2026-08-31 FOLDED IN AS §Z6. 🚨 The BH outcome cap and all FOUR cannot-go-down rules on the drawn hole are DEAD, and he has SEEN it: *"app behaving great :)"* — the first eyes-on verdict any of it has had.** Previously `5b65a97` ⭐ **RE-STAMPED 2026-08-30 23:45:00 — SESSION 2026-08-30 FOLDED IN AS §X (read it FIRST). 🚨 THE HOLE'S FORMATION IS DECIDED BY A 32-PER-CELL BUFFER SIZE — every single-run BH comparison on this board is unreliable. Engine-wide clock law + closures in `docs/BOARD.md` §Y.** Sources end at `d0697d8`; `5b65a97` is the bundle, which carries NO source change. 🌳 **TREE IS `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` @ `true-physics`.** Previously `4847e92` ⭐ **RE-STAMPED 2026-08-29 17:39:00 — SESSION 2026-08-29 FOLDED IN AS §W (read it FIRST). Engine-wide law + all measurements live in `docs/BOARD.md` §X.** Sources at `d0db70b`; `4847e92` is the bundle, which carries NO source change. Previously `01f1048` ⭐ **RE-STAMPED 2026-08-29 10:46:00 — SESSION 2026-08-28/29 FOLDED IN AS §V (read it first; §U is the session before).** Tree is now `/Users/airy/SPACE SYNTH/SPACE-SYNTH-POST-TUBE` @ **`post-tube`** (he named it 2026-08-28; was `SPACE-SYNTH-BH` @ `bh-gargantua-2026-08-26`). 🚨 **BOTH BH RENDERERS WERE DELETED THIS SESSION — every row below that describes the lens or the march is now HISTORY, not state.** §1a, §1b, §2, §5 and §6 in particular describe code that no longer exists. §U is the current state. ⚠️ Only the §U rows were read at this sha; every other row still carries its own older stamp, and many now describe deleted code. Previously `44d1798`.

---

## 🗄️ §BH-M1 — `docs/BOARD_BLACKHOLE.md` lines 522-532 (§M1, the ray-march's six closed rows). Moved 2026-09-03 16:10:00.

**Verbatim, nothing reworded.** Describes `bhmarch_fragment`, deleted in `00741f2` on 2026-08-27; 4 of the 5
symbols cited below (`T_ANCHOR_K`, `gShift`, `dTau`, `bDerived`) no longer exist in the tree. The march's
prohibition and dead roads stayed live on the board at §1b / §5 / §M3.

### M1. ✅ CLOSED

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| **M1a** | **The march extent was a CONSTANT in r_s while r_s AND the field move independently.** So the marched region tracked the shrinking hole and lost the disc. | `bCull = 7.0` (dial), `rMarchStart = 60.0` hardcoded | `bCull = meanR/r_s`, `rMarchStart = maxR/r_s`, both from the reduce the `[GRAV]` line already prints. Dial kept as a multiplier (old default 7.0 ≡ 1.0×). | `renderer.mm` (grep `bDerived`), `renderer.mm` `measuredMaxR` | `[MEASURED n=210]` probe lines, one run: adapted **4.87 → 198.19** as r_s went 0.059→0.840. Identity `bCull × r_s = meanR` holds by construction. |
| **M1b** | **The scale of the miss, measured.** | meanR 43.91 sim, maxR 100.0, r_s 0.2344 ⟹ field mean = **187 r_s**, bCull sat at **7** | march covered **3.7%** of the disc radius; slider max (40) could only reach **21%** — *no dial setting could ever show the disc* | `app_state.h:65` predicted this verbatim | `[MEASURED n=3]` `[MARCH]`+`[GRAV]` 2026-08-17 17:43 |
| **M1c** | **Hardcoded orange — the reason he banned bit19 on 2026-07-28.** | `float3(1.0f, 0.55f, 0.25f)`, no temperature input | `blackbodyRGB(g·T(r))`, `T(r) = 6500 K·(r/r_in)^(−3/4)·[1−√(r_in/r)]^(1/4)/f_peak`, `r_in` = ISCO = 3 r_s, anchor = DNGR's own white-balance point (doc §3). Sweep: 6500 K @4.08 r_s → 1322 K @60 r_s. | `render.metal` bhmarch_fragment (grep `T_ANCHOR_K`) | `[READ]` + `[HIS WORDS]` 2026-08-17 *"this orange shadow … must leave asap"* (07-28 09:32:18) |
| **M1d** | **No `g` at all in the march.** | emission had no Doppler and no gravitational shift | `g = 1/[u^t(1−Ω·b)]`, `u^t = 1/√(1−3M/r)`, `Ω = √(M/r³)` — **ONE factor**, exact, using the photon's conserved `b` the march already holds. Bounded by `√((1±β)/(1∓β))`, the emitter's own head-on/tail-on limits. | `render.metal` (grep `gShift`) | `[READ]` unit check: Ω·r at ISCO = **0.4082** vs `particles.metal:246` measured orbV max **0.4092c**, 0.25% |
| **M1e** | **Emission with no absorption — the brown fill.** | `emit +=`, unbounded ∫ρ ds over a 60 r_s path; the outer volume outweighs the inner disc at any gain | `dTau = dens·dl·emitScale; emit += trans·(1−e^−dTau)·col; trans *= …`. **No new constant** — in LTE the source function IS the Planck function, so the same κρ ds is both (Kirchhoff). Saturates at B(T); an unbounded fill is now structurally impossible. | `render.metal` (grep `dTau`) | `[HIS WORDS]` 2026-08-17 16:26 *"the emission is this bs"* → cause identified as missing extinction, not gain |
| **M1f** | **Phase Viz dead in the star map** (board item 4, and the handoff's guess had the polarity backwards). | — | `render.metal:2282` `out.color = mix(out.color, starColor, starMix)` with `starMix = 1−smoothstep(0,0.5,envelopePhase)` = **1 at silence**, and it never checks `cam.phaseViz`. Phase Viz writes at `:1743` and is overwritten 540 lines later. Chladni: starMix=0 → survives. Near hole: `:1898` drives starMix→0 → survives. | `render.metal:1743`, `:1866`, `:1898`, `:2282` | `[READ]` all four sites, live callers |


