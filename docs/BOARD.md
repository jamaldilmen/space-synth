# BOARD — THE REFERENCE OF TRUTH

**This is a LIVE document, not a handoff.** Handoffs are dated snapshots of a session.
This file is the single running list of what is open, what is done, and what each thing costs.
Update it in place. Never fork it into a second board.

**Last verified against the code:** 2026-08-10 14:49:44
**Commit at last verification:** `779a517` (unchanged — **nothing committed today, in either tree**)
**Last correction:** **A0a/A0b RETRACTED — they described dead code.** 2026-08-10 09:24:00
**Newest:** **F5 IS BUILT** in the camera worktree (2026-08-10 10:44:03) — layout guard proven live by the metallib stamp. **Unseen.** See §F.
Before that: A0 test **DEPLOYED AND INCONCLUSIVE** (2026-08-10 10:20:00, his verdict) — see §A0 VERDICT
**Berlin New Media Week:** 2026-09-02 — **23 days out**
⭐ **NEW, AND IT OUTRANKS THE A4 PATCH ROWS:** `docs/AUDIT_2026-08-10_note_lifecycle_chain.md` — **the full key-down → hold → key-up → star-map chain**, at his direct request 16:22:00. Verdict: **attack is an authored explosion, sustain holds matter with a velocity DAMPER we label crystallization, release switches the authored forces off and hands back to real gravity with no transition function.** The two ends of the chain are physical; the middle is stagecraft. §4 proposes the scientifically true version (sound = pressure SUPPORT against self-gravity; release = support decaying to zero, so nothing switches and no branch is crossed) — **his call, not started.** §5 is the discontinuity ledger; §1 retracts my own 400 ms claim.
**Latest handoff:** `HANDOFF_2026-08-10_a0_inconclusive_camera_gates.md` — 2026-08-10 14:47:00 (previous: `HANDOFF_2026-08-10_a2_fired_three_noops_found.md`, whose §0a findings 1 and 2 are **RETRACTED**)

> 🚨 **TWO BUNDLES NOW EXIST. KNOW WHICH ONE YOU ARE LAUNCHING.** (re-verified 2026-08-10 15:55:20)
>
> | Tree | Bundle stamp | Contains |
> |---|---|---|
> | `SPACE-SYNTH-TUBE` (main) | **2026-08-10 15:12:02** | live-UI panel, A1′ fix, A0 gate drop, **+ the A4 release-ramp fix** |
> | `SPACE-SYNTH-TUBE-camera` (worktree) | **2026-08-10 10:44:03** | commit `779a517` + **F5 only** — **no A0 gate drop, no live-UI panel, no A4 fix** |
>
> **Launch, do not rebuild.** Running now: **pid 6857, main bundle, launched 15:53:32.**
>
> 🪤 **METHOD FIX — THE RELAUNCH RECIPE DISCARDS THE ONE BIT YOU LATER NEED (2026-08-10 16:05:00).**
> `CLAUDE.md` says `pkill -f SpaceSynth; open -n SpaceSynth.app`. `pkill` is **silent on success** and the `;`
> **discards its exit status**, so nothing records whether a kill matched. When an instance later turns up
> missing you cannot tell "I killed it" from "it was already gone" — which is exactly what happened today:
> pid 6225 vanished somewhere in **15:51:57 → 15:53:23**, and my `pkill` did not run until ~15:53:31, so it
> was **not** the cause. Cause **UNDECIDABLE** — he may have closed the window, it may have died silently
> (documented hazard: a prior parallel run lost an instance at ~90 s with no crash message), or the peer's
> check raced a teardown. `log show` over the window returns nothing for exit/terminate/crash. **Use instead:**
>
>     pkill -x SpaceSynth && echo "KILL: matched" || echo "KILL: no match"
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
> ✅ **VERIFIED DISCRIMINATOR — `comm=` prints the full path, so it names the TREE:**
>
>     pkill -x SpaceSynth && echo "KILL: matched" || echo "KILL: no match"
>     open -n "<explicit .app path>"
>     sleep 2
>     for p in $(pgrep -x SpaceSynth); do ps -p $p -o pid=,lstart=,comm=; done
>
> Confirmed here at 16:01:47 — one line gives pid, age, **and which tree**. Use this, not a bare `pgrep`.
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

---

## 👀 WATCH LIST — THREE THINGS BUILT AND UNSEEN, do them in ONE pass at the screen
**Opened 2026-08-10 15:18:00 at his request** (*"put on to watch list once im on screen"*).
Nothing here is ✅ until he has looked. **Rebuilding the main tree destroys W2 and W3 — see the rule below.**

| # | What | Where | What to DO | What to WATCH | Passes if |
|---|---|---|---|---|---|
| **W1** | **F5 — `viewForward` plumbing** | **camera** bundle: `open -n "…/SPACE-SYNTH-TUBE-camera/SpaceSynth.app"` | Just look at it. Normal ortho view. | The whole picture. | **NOTHING changes.** F5 is a visual no-op by construction — while the camera still points at the origin, `viewForward` *is* `normalize(-cameraPos)`. **Any visible difference means the plumbing is wrong.** Unblocks F6. |
| **W2** | **A4 — release discontinuity** | **main** bundle — **pid 6857, launched 15:53:32** (pid 6225 was killed, see below) | Hold a chord until the pattern visibly SETS (the crystal forming, ~10–15 s), then release. **Do this in the first few minutes of the run.** | The instant of release. | Matter **eases** into motion over the release tail instead of lurching the moment you let go. The inspiral itself should be unchanged. |
| **W3** | **live-UI panel** | **main** bundle, same run | Open it. | — | Your call on whether it is what you wanted. Built 09:55:37, carried into the 15:12:02 build, never seen. |

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

## 🗓️ STATE OF PLAY — 2026-08-10 10:23:45

**THREE WINDOWS ARE LIVE ON THIS REPO.** Coordination rules are not optional; see §STANDING RULES.

🚨🚨 **HIS ORDER, 2026-08-10 16:01:00 — ONE LIVE APP, NO PARALLEL BUILDS. THIS SUPERSEDES THE WORKTREE ARRANGEMENT.**
> *"we said we only have 1 live app at any given time which is ours. make the camera window understand that NO 2 BUILDS PARALLEL"*

**Effective immediately: only the MAIN tree builds and only the MAIN tree runs.** The camera worktree stays on disk, **unbuilt and unlaunched**, at `10:44:03`. Relayed to the camera window 16:07:00; it has stood down. **This supersedes his own 10:37:00 "do the worktree"** — newest signal wins, and nobody is to quote the older approval back at him.
⚠️ **W1 IS SUSPENDED AS WRITTEN** — it asked him to launch the camera bundle, which is precisely what he has ruled out. **Do not ask him to run it.**
⭐ **This also dissolves the two-bundle hazard below** (same process name in two trees) by removing the second bundle rather than by working around it.
📌 **OPEN CONSEQUENCE, HIS CALL, NOT STARTED:** F5 exists only in the camera worktree and can no longer be verified where it lives. The obvious resolution is F5 moves into the main tree and is verified in the one live app. **Nobody is to begin that cross-tree move without his word.**

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

## 🕳️🚨 A0. THE STANDING STRUCTURAL FAULT — "IT IS NOT A BLACK HOLE, IT IS A BLACK CIRCLE WITH A GOPRO ON TOP"

**His verdict, 2026-08-10 09:13:00, with a screenshot, lens OFF:**
> *"when i turn off lens it's still just a weird spinning circle... like not a thick ring like Sonic the Hedgehog coins but **flat 2D rings with fake depth**. It's not a true black hole. This issue has been standing for **months**. I believe that a lot of our issues fall back to the fact that **it's not a black hole but a black circle with a GoPro on top**. Our black hole eventually needs to **survive non-ortho mode**. It's **crumbling under its own hotfixes**."*

🚨 **THIS ROW OUTRANKS EVERYTHING BELOW IT.** A1′, A2, A3①②③ are all bookkeeping inside a renderer whose camera cannot express depth. **A2 "passing" means a number went down — it does not mean a black hole exists.** Treat every ✅ below as scoped to arithmetic until this row moves.

**MEASURED THE SAME MINUTE — his verdict holds. My first two findings did NOT.**

🚨 **RETRACTION, 2026-08-10 09:24:00.** The rows I wrote as A0a and A0b described **`renderer.mm:1401`, the one-argument `render(const RenderConfig&)` overload, which has ZERO callers.** It is dead code. Verified: `grep` for `.render(`/`->render(` across `src` returns exactly one call site, `main.cpp:2533`, and it is the **two-argument** form. Both claims are withdrawn. The row itself survives on his eyes and on A0d below.

| # | Finding | Evidence |
|---|---|---|
| ~~**A0a**~~ | ~~two camera systems, BH uses the wrong one~~ **WITHDRAWN.** The live path is `render(config, viewProj)` and it `memcpy`s the matrix built in `main.cpp:770-779` — which **does** branch `orthoMatrix` / `perspectiveMatrix(45°)`. The toggle reaches the particle/BH path. | `renderer.mm:1628`, `:1696`; `main.cpp:2533`, `:770-779` |
| ~~**A0b**~~ | ~~`cameraPos` hardcoded `{0,R,0}`~~ **WITHDRAWN.** That literal is in the dead overload. The live path sets `cam.cameraPos` from `config.cameraPos`, which `main.cpp` fills from the real orbit camera (`camera.getX/Y/Z()`). A comment at `:1697-1699` records that this was already fixed once. | `renderer.mm:1700-1702`; `main.cpp:2162-2164` |
| **A0c** | **AN ORTHOGRAPHIC PROJECTION CANNOT PRODUCE THE LOOK HE IS ASKING FOR.** Under ortho a tilted ring projects to an *exact ellipse* — near and far sides render at identical scale, so there is no foreshortening and no volume. **"Flat 2D rings with fake depth" is the literal, correct description of an orthographic projection of a ring.** The "thick Sonic-coin ring" he wants requires perspective plus real vertical structure; no post-FX can add it. **Still stands — this is geometry, not a code claim.** | `main.cpp:773` (the live ortho matrix); his screenshot 2026-08-10 09:13:00 |
| **A0d** ⭐ | **THE HOLE IS HARD-GATED TO ORTHO — this is the real mechanism, and it is one line.** `cam.bhShadowNdcRadius = (config.orthoMode && frustum > 1e-4 && bhLensActive) ? bSim*plateRadius/frustum : 0.0f`. **Turn ortho off → the radius is literally `0.0f`** → every shader gate on it (`> 1e-4`) goes false → no shadow, no lens. The hole does not degrade in perspective, it **ceases to be drawn**. That is "cannot survive non-ortho mode", stated in code. | `renderer.mm:1749-1752`; gates at `render.metal:771`, `:879`, cull at `:671` |
| **A0e** | **AND IT IS A SCREEN-SPACE CIRCLE, NOT A MARCHED OBJECT.** The quantity passed to the shader is an **NDC radius** — `render.metal:1035` consumes it as `thetaE`, a screen-space deflection angle. Nothing is marched through a world-space metric on this path. **"A black circle with a GoPro on top" is a fair description of what the code draws.** | `renderer.h:177`; `renderer.mm:1749`; `render.metal:1035` |
| **A0f** | **SECOND GATE: the lens is OFF whenever he is playing.** `bhLensActive = (totalAmplitude < 0.02f)`. Any judgement of the hole made while notes are sounding is a judgement of a hole with no lens. | `renderer.mm:1748` |
| **A0g** 🪤 | **THE DEAD OVERLOAD IS A NEAR-DUPLICATE, NOT JUST UNUSED — IT IS A STANDING TRAP.** `Renderer::render(const RenderConfig&)` has **zero callers** (verified 2026-08-10 09:55:00: one `.render(`/`->render(` hit in all of `src`). It is not inert: it *near-duplicates the live path*. The `cam.bhShadowNdcRadius` gate exists **twice, identically, four lines each** — the two copies differ only in the trailing comment on the preceding line. An `Edit` on the live gate failed with *"Found 2 matches"*; had it not, the change would have landed in dead code and read as a no-op. **This duplication is the direct cause of the A0a/A0b retraction above**, and it silently shadows the live path in every grep. **Rule: assume any camera/BH uniform assignment exists in BOTH bodies; confirm which one you are editing before you edit it.** The same both-bodies check is owed to the CPU-side feeders for `render.metal:904` and `:1031`. ⚖️ *Camera window's recommendation, and I agree: the dead overload should eventually be **deleted**, not maintained — but that is a deletion during show prep, so it is **Jamal's call and post-BNMW**. Flag it, do not action it.* | `renderer.mm:1401` (dead body), `:1501` (dead gate) vs `:1763` (live gate) — **all three verified 2026-08-10 10:01:00** |
| **A0h** ⚠️ | **`CameraUniforms` IS HAND-MIRRORED ACROSS CPU/GPU WITH NO LAYOUT GUARD — AND THE GUARD PATTERN ALREADY EXISTS IN THE SAME FILE.** `renderer.h:166-222` and `render.metal:24-74` are mirrored **positionally**, ~40 float fields, kept in sync by nothing but a comment (`renderer.h:166`: *"matches the struct in render.metal"*). **But `renderer.mm:36` already does this correctly for a different struct:** `static_assert(sizeof(BHMarchUniforms) == 88, "BHMarchUniforms layout")`. So the project knows the technique and `CameraUniforms` was simply left out. A mid-struct insert on one side shifts **every field after it** — `bhShadowNdcRadius`, `horizonR`, `bhX/Y/Z`, the whole `tune*` block — and would present as a *physics* bug, chased in the wrong file for a day. **Agreed working rule (both sessions): new fields are APPENDED AT THE END of both structs, never inserted.** Appending degrades a mismatch from "everything after the insert is garbage" to "the one new field is garbage" — local and obvious instead of global and misleading. ⚠️ Note when the assert is added: `sizeof` catches drift but **not transposition** — two structs can agree on size and disagree on layout. `offsetof` anchors bind only the fields anchored; a swap strictly between two anchors still slips through. A green build is an improvement, not a proof. | `renderer.h:166-222` vs `render.metal:24-74`; precedent at `renderer.mm:36` — **verified 2026-08-10 10:01:00** |
| **A0h′** ✅ | **THE GUARD FOR A0h IS FULLY SPECIFIED AND TESTED — not designed, tested.** Both sessions compiled standalone `.metal` files (scratchpad only, nothing in the repo). Compiler: *Apple metal version 32023.850, target air64-apple-darwin27.0.0*. Results: **(1)** MSL supports `static_assert` + `sizeof` and **it fires** — wrong value → `error: static_assert failed … 1 error generated`; the *failing* case was checked deliberately, since a clean compile alone only proves the assert was ignored. **(2)** `offsetof` **does NOT exist in MSL** (no `<cstddef>`) — writing the anchors the obvious way would have broken the shader build and looked like a struct bug. **(3)** `__builtin_offsetof` **works** in MSL and fires. **(4)** ⭐ **It catches TRANSPOSITION**: two adjacent floats swapped, `sizeof` unchanged, anchor caught it — the exact gap `sizeof` alone leaves, reproduced rather than argued. **Final shape:** same shared numbers in both files — `sizeof` + `__builtin_offsetof` anchors on `bhShadowNdcRadius`, `bhX`, and the tail field (the three that exist under the same name in BOTH files; `cameraPos`/`cameraPad` does **not** qualify — Metal declares `float4 cameraPos` and has no `cameraPad`). Use `__builtin_offsetof` on the C++ side too, so both blocks read identically and nobody "fixes" the Metal one back. Since the Metal compile runs as the `MetalShaders` target inside `package_macos.sh`, **the guard breaks the normal build loop** — it has teeth. ⚠️ **Honest limit, to be stated in the code comment:** three anchors across ~40 fields catch size drift, tail-append mismatch, and transposition *across* an anchor. A transposition strictly *between* two anchors still slips through. **Better than the comment that guards it today; not a proof.** | verified **2026-08-10 10:06:00** (sizeof, this window) and **2026-08-10 ~10:10** (offsetof/transposition, camera window); precedent `renderer.mm:36` |
| **A0j** 🚧 | **HOW TO READ A CLEAN A0 RESULT — DO NOT OVER-READ IT.** If a disc appears in perspective, that proves the hole draws **for a camera that still points at the origin**. It does **not** prove perspective is solved. Two sites hardcode that assumption: `render.metal:1031` `viewDir = normalize(-cam.cameraPos.xyz)` (feeds `behindBH`, which decides what is lensed vs what occludes the hole — the thing that puts the hole *in the room* rather than on a flat layer, per the 2026-06-13 comment) and `render.metal:904` `dHat = normalize(-cam.cameraPos.xyz)`, whose own comment reads *"(ortho: parallel rays)"* — self-documenting that it is ortho-only, and it guards the **seam fix of 2026-07-26 13:56:00**. Both are safe *today* only because `camera.h:123` hardcodes the same thing (`forward = {-posX,-posY,-posZ}`) — the whole camera is look-at-origin. **The moment dolly rides or POV-follow land, both misclassify silently: the lens bends the wrong half of the field, the occlusion inverts, and the old seam artefact returns.** No error, just wrong. Both sites need the real forward vector, not just the view matrix. ⚖️ Owned by the camera window (`airy-7b`), not this row — recorded here so a green A0 is never mistaken for "perspective works". | `render.metal:904`, `:1031`; `camera.h:123` — verified **2026-08-10 10:04:00** |
| **A0i** 📅 | **`file:line` IN THIS DOCUMENT DECAYS, AND NOTHING MARKS IT STALE.** The live gate moved `:1749 → :1763` at **2026-08-10 09:55:29** — mid-session, from a comment block added directly above it. Every A0 reference written before that timestamp was correct when written and wrong an hour later, with nothing in the file to say so. **Rule: cite a grep pattern or quote the surrounding line; where a bare number is unavoidable, stamp it with the time it was verified.** A `file:line` without a verification timestamp is a claim with no expiry date. | this row, and the `:1750`→`:1763` drift throughout §A0 |

**What this reframes:** ⭐ **C3 (99.3% of stars pinned to one pixel), C7 (the Cartwheel colour law), the "two rings" history, and the months of "it reads as two circles" reports are all plausibly downstream of A0.** Before spending another session on any of them, settle whether the BH path can render in perspective at all.

### ⏸️ A0 VERDICT — **INCONCLUSIVE, NOT PASSED AND NOT FAILED.** 2026-08-10 10:20:00

**Done:** the `config.orthoMode &&` term was removed (live gate, now `renderer.mm:1763`; the ortho path is unchanged, this only adds the perspective case). Built and deployed **09:55:37**, verified newer than source, launched twice (09:57:31, 10:18:07).

**His verdict:** *"the cam is still kinda locked in place so I don't know if I see the BH — but that's not even our priority right now."*

**Read that precisely — it is NOT a null result.** The measurement could not be TAKEN. The camera cannot be moved to a viewpoint where the answer would be visible, so no observation was made, and **no conclusion about the gate is licensed in either direction.** Anyone later reading "A0 test ran" must not read it as "perspective works" or as "the gate wasn't it."

**⭐ WHAT THIS CHANGES — THE DEPENDENCY IS THE REVERSE OF WHAT WE ASSUMED.** A0 was written as though the camera work sat downstream of it. It does not. **Reading A0's result REQUIRES a camera that can move**, because a locked, origin-pointing camera produces no parallax and therefore cannot distinguish a perspective-correct disc from a flat one. So: **the camera overhaul now gates the A0 measurement.** That is also the show work, so the two are no longer in tension — they are the same road, in the order camera → then re-read A0.

**STILL UNMEASURED, carried forward for when the camera moves:** the predicted **~2.9×** scale error (`/frustum` is the ortho world→NDC map; perspective needs `d·tan(fovY/2)`, and `d` must be camera→**hole**, not camera→origin, since the seed wanders). The divisor fix is deliberately **not** batched into the gate drop — it is the next change, and it needs the measurement first.

**⚠️ Do not re-run this test with a locked camera.** It will produce the same non-answer. Re-open it only after the camera window lands a movable, non-origin-pointing camera — and then read **A0j** before interpreting the result.

🚨 **AND THE TESTS:** his words — *"whatever tests you've been running here are total ass. Stuck from start at 49.97 as I've said all the fucking time."* **He is right on the facts.** `Biggest body` sat at the IMF ceiling (~49.9) for the whole of two runs while we waited (see **A5**), and the runs that did cross validated a *number*, not a hole. **A2's result is real and also nearly beside the point until A0 moves.**

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
| **F5** ⭐ | **`viewForward` into `CameraUniforms`, consumed at the `dHat` and `viewDir` sites.** ⭐ **SELF-VERIFYING: while the camera still points at the origin, `viewForward` is IDENTICAL to `normalize(-cameraPos)`, so the refactor is a visual NO-OP. If anything changes on screen, it is wrong.** Verifiable before it is useful — **and it is what makes A0 measurable.** Shipped WITH the layout guard (**A0h′**): `sizeof == 272` plus `__builtin_offsetof` anchors at `bhShadowNdcRadius == 108`, `bhX == 200`, `viewForwardZ == 268`, **written identically into both files**. ⭐ **The guard is PROVEN LIVE, not assumed: `default.metallib` is stamped 10:44:03, newer than `render.metal` at 10:43:42 — the Metal compile ran after the asserts were in, so they passed.** The CPU/GPU mirror is now bound by the compiler instead of by a comment. 🚨 **BUILT, NOT SEEN — the no-op claim is unverified until he looks. The whole point of F5 is that the screen must not change; nobody has checked the screen.** | 🔨 **BUILT 2026-08-10 10:44:03 in the camera worktree — AWAITING HIS EYES** | `renderer.h:233-235`, `:270`; `render.metal:79-81`, `:103`, `:937`, `:1067`; `camera.h getForward()`; `main.cpp` feed — all verified **2026-08-10 14:49:00**. See **A0j** |
| **F6** | **Target/actual split + spring**, ω from beat. **This is where "locked in place" dies.** | ⬜ blocked on his verdict above | F1+F2+F3 all fall to this |
| **F7** | **MIDI CC path + learn.** `midi_input.mm` discards **all** CC: `else if (type >= 0x80) { j += 3; }`. Callback is note-only. Needs a `0xB0` parse, a `(cc, value, channel)` callback, a learn table. ⚠️ **7-bit CC = 128 steps; across `rho` 50→2000 that is ~15 units per step — visible stair-stepping on a slow zoom, which reads as broken on a large screen.** Fix falls out of F6 free: **CC writes the spring's TARGET**, the spring outputs the smooth value. **Second independent reason F6 must come first.** | ⬜ | `midi_input.mm` |
| **F8** | **Ableton Link, render-side.** Verified against `Link.hpp` (header-only C++): `captureAppSessionState()` = app/render thread, thread-safe, **not** realtime-safe; `captureAudioSessionState()` = audio thread, realtime-safe. **Camera sync uses the App form on the render thread and never touches audio → adds NOTHING to D6.** 🚨 **BOUNDARY — do not let this be remembered as "Link is safe":** tempo-locking the **SYNTH** uses the Audio form and lands squarely in D6. Different question, different answer. `phaseAtTime(now, quantum=4)` = bar-progress 0→1 = the master animation clock. | ⬜ | see **D6** |
| **F9** | **Two uses of one clock, conflated by most people** (from Resolume's model): **(1) quantised launch** — discrete events wait for a boundary (a dolly shot fires on the next bar, never mid-phrase); **(2) continuous phase drive** — a parameter *is* a function of phase (`phi = 2π·beat/16` = exactly one revolution per 4 bars). ⭐ **Copy outright: Resolume deliberately DISABLES hard resync while Link is on.** Mid-show, a camera that snaps to re-align is worse than one slightly off. Orbit speed stops being "0.2 rad/s" and becomes "one revolution per N bars" — a musical quantity. **Inspiration, not lifting** — our numbers derive from our own clock. | ⬜ | per [[feedback_ui_sample_dont_steal]] discipline |
| **F10** | **Dolly splines.** Separate WHERE THE CAMERA IS from WHAT IT LOOKS AT as two independently animated tracks (Cinemachine's one good idea). Position on Catmull-Rom; look-at on its own. ⚠️ **The caveat that bites everyone: naive spline `t` gives UNEVEN SPEED** — the camera accelerates between waypoints and decelerates at them. **Needs arc-length reparameterisation or the dolly reads as broken.** | ⬜ **droppable if the show gets tight — said now, not in week three** | |
| **F11** | **POV-follow.** Cheaper than feared: `particleBuffer` is `MTLResourceStorageModeShared` and `renderer.mm` already casts `.contents` to `GPUParticle*`. Unified memory → no blit, no stall. Real issue is a torn/1-frame-stale read, and **for a spring-smoothed target one frame is invisible.** Raw particle motion is chaotic, so the spring does the real work: low ω, target = particle, eye trails. ⬜ **OPEN QUESTION FOR HIM: what should POV track?** A clicked particle / a random one / a derived one ("fastest", "nearest the horizon"). **Materially different** — a chosen particle needs picking plus an ID stable across frames; "fastest right now" is a per-frame reduction that hops between particles. **Not guessing this.** | ⬜ droppable | depends on F5, F6, F10 |

**SEQUENCE (his to approve):** F5 → F6 → F7 → F8/F9 → F10 → F11. **F5–F7 alone give a camera that feels right and is playable.** F10 and F11 are the droppable ones if the show gets tight.

🔨 **BUILD TOKEN:** F5 needs it. Currently held by the board window. **Either hand it over, or ask him for a git worktree so the two windows stop sharing one bundle.** His call.

---

## 🚨 A. BLOCKERS — nothing downstream is trustworthy until these settle

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| ~~A1~~ | ~~**Accretion is dead.**~~ ❌ **REFUTED 2026-08-08 00:05:09 — MEASURED, 3 RUNS.** Accretion is not dead. **It runs away.** See **A1′** below. The old claim came from a **64× run**, where §7's tunnelling arithmetic is correct and merging genuinely cannot happen. Nobody had run **1× silent** long enough. | ✅ closed | 3 stacked runs, `logs/A1_*` | — |
| **A1′-endgame** | 🚨 **THE FIX BOUGHT TIME; IT DID NOT BOUND THE OUTCOME. OBSERVED 2026-08-10 15:52:00, HIS SCREENSHOT, ON THE 15:12:02 BUNDLE.** A 41-minute idle run (launched 15:12:17, universe clock 13.62 h at 20.58 s/real-s = 39.7 min — the clock checks out) ended with **`Biggest body` = 356,475.19 M☉ against a field of 594,276 M☉ — 60.0% of everything in ONE body**, and roughly four visible objects left on screen. ⭐ **This is not a regression and not a refutation of A1′ — it is the fix behaving exactly as measured, run longer than anyone had run it.** The rate limit made growth **linear** (verified: consecutive `Mmax` deltas dead constant), but **linear is unbounded in time**: at the measured **2,451 M☉/wall-s**, the entire field is consumable in **~4 minutes** of active accretion. The A1′ row's surviving-field evidence (`live` = 1,273,268 at `Mmax` = 215,829) is a **MID-RUN SNAPSHOT, NOT AN ENDPOINT** — and it was read as though it were a steady state. 🚨 **BERLIN RELEVANCE, direct:** a set is 40–60 minutes. Any idle passage of a few minutes consumes the field, and the show ends on an empty screen. **A bound (feedback / Eddington-like term / a cap tied to field mass) is a different fix from the rate limit and does not exist anywhere in the code.** ⚠️ **Also invalidates any long-idle test:** A4's first attempt died this way (see WATCH LIST). | ⬜ **NEW — measured, unfixed** | his screenshot 2026-08-10 15:52; rate from `docs/MEASURED_2026-08-08_A1_runaway_cause.md`; no feedback term exists (`grep -n "Eddington\|feedback" src/render/particles.metal` → 0 hits) | **M** |
| **A1′** | ✅ **FIXED 2026-08-08 03:52, VERIFIED BY LOG (not by eye).** ⚠️ **Read with A1′-endgame directly above — "field survives" was a snapshot, not a steady state.** Viscous accretion rate limit shipped in `4816056`. **Measured 2,451 M☉/wall-s against a derived cap of 2,517 → 0.97×**, with consecutive `Mmax` deltas `10349·10451·10525·10385·10421·10552·…` — **dead constant, i.e. LINEAR.** The M² divergence is gone **by construction**: `T_isco ∝ M` makes the ceiling mass-independent. **Field survives: `live = 1,273,268` (64%) at `Mmax = 215,829`**, `Mlive` conserved to −107 — pre-fix was `live = 19` at the same stage. ⭐ **Every number derived from our own telemetry:** `h/r = c_s/v_φ` gave **0.746** (inner) and **0.771** (mean) from temperatures 12× apart — agreeing to 3%. Scale check: measured `orbV 0.4092c` vs ISCO theory `0.4082c`, **0.23%**. ⚠️ **OPEN:** did it lengthen the pre-formation fuse? Post-fix 16+ min and 8 min vs pre-fix 30 s / 4.5 min / 10 min — 8 min is *inside* the old range, so no evidence either way at n=2. If it did, apply the limit only above 5000 M☉. | ✅ log-verified 🔨 unseen | `docs/MEASURED_2026-08-08_A1_runaway_cause.md`; `particles.metal` rate-limit block | done |
| ~~A1′-cause~~ | ✅ **CAUSE FOUND 2026-08-08 01:37:02.** At **`mS > 5000` M☉ the capture radius stops being capped** and becomes `rc = 3·r_s`, which is **linear in mass** — so cross-section ∝ M² and **dM/dt ∝ M², a finite-time blow-up.** The growth regime below 5000 **is** capped (`min(rt2, reach²)`, `reach = 1.4·cellSize ≈ 0.066`); the formed regime has **no `min()` at all**. At the measured peak the capture radius is **2.8 sim units vs `R_DISK = 18`** — 1,830× the capped area. ⭐ **Proof in the logs we already had: ZERO samples between `Mmax` 480 and 320,000.** It sat at 475 for 95 samples then jumped straight to 322,919 — five orders of magnitude between two samples, which is exactly the `M²` signature. **Also explains the 30 s vs 10 min variance:** a slow stochastic fuse (50→5000, capped) then a detonation of fixed duration. 🚨 **The uncapped radius is a RENDER number doing a PHYSICS job** — `3·r_s` was chosen so the disk inner edge and the lens shadow track together, so capping it naively will bring back the two-layered-bodies artifact. **Capture radius and shadow radius must become two separate numbers.** No feedback/Eddington term exists anywhere. | ⬜ fix not chosen | `docs/MEASURED_2026-08-08_A1_runaway_cause.md`; `particles.metal:1225-1252` | **S**–**M** |
| ~~A1′-old~~ | ~~**RUNAWAY ACCRETION — THE SIM EATS ITSELF.**~~ At 1×, silent, no input, a body crosses 50 M☉ and then consumes the entire field. **3/3 runs, 2 independent realizations.** Mass is conserved throughout, so this is real mass eaten, not minted. **The show-relevant part: the field's lifespan is unpredictable — between 30 s and 10 min.** Same spawn seed gave 10 min once and 30 s the next, so the *evolution* is nondeterministic even though the spawn is not (very likely GPU atomic ordering in the hash/merge path — **stated as the likely cause, not proven**). ⭐ **This re-reads his old screenshot:** the "almost empty field, disk gone, handful of bright points" was recorded in §7 as *nothing accreted*. It is the opposite — **everything accreted.** That frame is the end state of runaway. | ⬜ **NEW** | see the run table below | **M** |
| **A2** | ⭐ **UNBLOCKED 2026-08-08 — RUNNABLE FOR THE FIRST TIME IN FOUR HANDOFFS.** The A1′ fix makes a hole **persist over a living field** (`r_h = 0.3516` with 1.27M stars alive), so both preconditions finally hold at once: a real seed exists, and there are corpses to refund. **The test:** let it run silent at 1× until `Biggest body` clears 50, then **hold a sustained note** and watch that number **FALL** — the first non-monotone `gMaxMass` in the project's history. Watch for `[REBIRTH] withdraw=…`; `SHORTFALL(minted)` means the drain clamped at 0 and mass was created. 🚨 **NEEDS HIS EARS AND HANDS — he must play.** ⚠️ Momentum is knowingly not conserved on rebirth (a reborn particle takes its host's velocity); flagged as a choice, not an oversight. ✅ **NOT MASKED — warning withdrawn 2026-08-08 17:04:19.** The old note said A3① would hide the effect. Measured: `seedTarget` never reaches 1 in any healthy run (max 0.726), so it pins nothing — **and the test watches `Biggest body` = `gMaxMass`, a HUD number that does not depend on `bhStrength` at all.** ⭐ **A2 is observable right now, with no code change first.** ⚠️ Momentum is knowingly not conserved on rebirth (a reborn particle takes its host's velocity); flagged as a choice, not an oversight. — 🔥 **IT FIRED, 2026-08-08 18:12→18:31. `[REBIRTH]` had 0 occurrences in the whole project; run 1 logged 40.** `gMaxMass` fell `177,218 → 90,294 → 45,653 → 22,751 → 10,798 → 4,809 → 1,820 → 737 → 319 → 147 → 50.0` — **23 falling steps, halving every 120 frames, `SHORTFALL(minted)` = 0.** The field came back: `live` 2,000,000 → **1,227,500** → **1,999,950**. FPS median 48, 3.3% under 30 — healthy. 🚨 **BUT A2 AT 2M IS STILL n=1 AND THIS PROJECT BANS SINGLE-RUN CLAIMS.** Run 2 reproduced it (7 lines, hole `548.6 → 248.8 → 76.5 → 50.0`, 0 SHORTFALL) but at **10M particles** — a different configuration that cannot stack. **A clean 2M repeat is owed.** Full detail: `docs/MEASURED_2026-08-08_A2_refund_fired.md`. | 🔨 **log-verified ×1 at 2M · visual verdict NEVER GIVEN** | `particles.metal:689`, `:694`, `:3445`; `renderer.mm:3094` | **S** (the test) |
| **A3①** | **The `/0.5` denominator is REAL but NOT CURRENTLY BINDING — and it is NOT what stops the reversal. MEASURED, 5 LOGS STACKED, 2026-08-08 17:04:19.** The arithmetic checks out: `seedTarget = kRsSimPerMsun · bhSeedMass / kREnc` reaches 1 at `0.5 / 1.6825e-6 = ` **297,177 M☉** exactly as the row claimed. ❌ **But `seedTarget` is not what pins `bhStrength`.** Counting `[BH-POP]` samples: `seedTarget ≥ 1` occurs **0 times in all four healthy runs** (max `seedTarget` reached: **0.003 · 0.726 · 0.723 · 0.041**), while `r_s/r ≥ 1` occurs in **1,529 · 223 · 179 · 120** samples — **and `seedTarget < 1` in every single one of those.** Only the pre-fix 30-s runaway crossed it (`Mmax` 557,451 → `seedTarget` 1.879). 🚨 **So the thing holding `target ≥ 1` is `honestTarget` (`r_s/r`, median 3.4), not this denominator.** Since `target = max(seedTarget, densTarget, honestTarget)`, **fixing `kREnc` alone cannot make the hole un-form** — third no-op fix found on this board for the same structural reason. ⚠️ **It becomes binding soon, though:** post-fix growth is **2,451 M☉/wall-s** and run2 peaked at `Mmax` 215,829, i.e. **~33 s of further running crosses 297,177**. On a Berlin-length run it *will* engage. ⭐ **The row that actually controls reversal is A3② (the ORIGIN LOCK)** — `r_s/r` is computed from a profile binned around the origin while the seed wanders off it. **Fix A3② first; A3① is a follow-up, not a prerequisite.** | ⬜ real, not binding yet | Measured: `logs/A1fix_CAS*`, `A1fix_ratelimit`, `A1_retest_seed{7,42}`. Code: `renderer.mm:2994` `seedTarget`, `:3030` the `max()`; `units.h:86` `kREnc = 0.5` | **M** |
| **A3②** | **Fake hole — the profile is centred on the origin.** Root cause found this pass and it is blunter than the older docs said: the COM refinement is wrapped in **`if (false)`** with the comment `ORIGIN LOCK: refinement disabled`. So `bhPosX/Y/Z` never leave their `0.0f` initialisers, and the radial profile — which bins around `u.bhX/Y/Z` — measures around the origin while the seed wanders off it. | ⬜ | `renderer.mm:2959` `if (false) { // ORIGIN LOCK`; `:196` the initialisers; the binning is in **`kernel void reduce_stats`**, grep `// RADIAL PROFILE:` (**`particles.metal:3907`** as of 2026-08-10 15:17:00) — ⚠️ **this row previously cited `:3808`, which was stale by ~76 lines BEFORE today's edits. Re-verified by content, not by arithmetic.** | **S** to unlock, **?** to make honest |
| **A3③** | ❌ **PREMISE REFUTED 2026-08-08 16:31:44 — MEASURED. THE LATCH IS NOT THE BUG, AND FIXING IT IS A NO-OP.** The row said the latch "catches an instant" where the innermost shell transiently satisfies `r_s/r ≥ 1`. **It is not an instant.** ⚠️ **STACKED ACROSS ALL 6 LOGS (2026-08-08 16:44:07) — this project bans single-run claims and my first pass broke that rule.** Share of `[BH-POP]` samples with `r_s/r ≥ 1`: `A1fix_CAS` **1,529/1,534 = 99.7%** (median 3.431) · `A1fix_CAS_run2` **223/233 = 95.7%** (3.610) · `A1fix_ratelimit` **179/195 = 91.8%** (3.966) · `retest_seed7` **120/125 = 96.0%** (4.674) · `retest_seed42` **26/68 = 38.2%** (0.530) · `soak_1x_silent` **474/6,975 = 6.8%** (0.000). **So: sustained in 4 of 6 runs, mostly absent in 2** — and 🚨 **BOTH OUTLIERS ARE EXPLAINED, NEITHER CONTRADICTS THE AVERAGE (2026-08-08 16:52:31, his call: "trust the avg, not single transients"; "for weird runs it's more likely my screen was locked").** `soak_1x_silent` is a **STARVED RUN: median 24 FPS, 93.0% of 75,370 samples below 30 FPS, min 0** — and `dt` is per-frame, not wall-clock (`renderer.mm:1339`), so the field barely progressed. Its `r_h > 0` share (6.8%) is very nearly the complement of its healthy-frame share. Cross-check: `retest_seed42` **median 79 FPS, 0% under 30**, `A1fix_CAS` **median 40 FPS, 0% under 30** — the outlier is the only starved one. `retest_seed42`'s 38.2% has a different and known cause: it is the **30-second pre-fix runaway** (max `r_s/r` = **23.716**), so it destroyed its own field before accumulating samples. ⭐ **RULE FOR THIS PROJECT: check the FPS distribution before believing a null result — display sleep starves the sim, and a starved run is not evidence.** In `A1fix_CAS` the only 5 sub-1 samples are exactly the opening ramp `0.000 · 0.147 · 0.569 · 0.797 · 0.984`. 🚨 **Deleting the latch would change nothing, and this does NOT depend on the run variance above — it is an argument from the code.** `honestTarget = min(r_s/r, 1)` saturates at **1.0**, so `bhStrengthEma` converges to 1.0 on its own; the latch only replaces an asymptote with an exact 1.0. **Every downstream consumer gates at 0.5** — doubled particle instancing `renderer.mm:3460` `(bhStrength > 0.5f)`, raytracer `:3540` `(bhStrength > 0.5f || oscAmount > 0.01f)` — and the log shows **`bhStrength = 0.95` at `r_s/r = 0.984`, i.e. BEFORE the latch ever set.** All gates were already open. The latch rounds the last 5% up and switches nothing on. ⭐ **What actually declares the hole:** `r_h = 0.1172` sim encloses **73,770 M☉ (12.4% of the field)**, and `r_s(73,770) = 1.6825e-6 × 73,770 = 0.1241 > 0.1172` → ratio **1.059**. The criterion is being **genuinely satisfied by DIFFUSE mass** — **726 `[GRAV]` samples read `hole=1.00L` with `seeds=0` and `Mmax=50.0`**; the first `seeds=1` arrives only at `Mmax=91.7`. 🚨 **ROOT CAUSE IS SCALE, NOT LOGIC:** `r_s(594,276 M☉) = 0.9999 ≈ **1.0 sim**`, so the field spawns at `R_DISK = 18 sim` = **18 Schwarzschild radii of its own total mass**, with collapse unopposed (**B10**). A centrally-concentrated cluster that small *must* reach `r_s/r ≥ 1` within seconds — **the initial condition is already nearly a black hole.** ✅ **CLOSED BY HIS CALL 2026-08-08 16:52:31: "we still have the starting gravity pull so it makes sense that it's looking weird cause it's scripted, it's not that deep."** He is right and it is in the source: the inward drag is **authored**. `particles.metal:775` `fricRest = pow(0.99f, dt)` — *"the gentle drag IS the accretion mechanism (slow inspiral toward the mass centre)"* — and `:780` `pow(0.95f, dt)` on release, *"e-fold ~20 s, **replaces the deleted scripted collapse**"*. So an early central concentration is the drag doing exactly what it was written to do. **`hole=1.00L seeds=0` is authored behaviour reported honestly, not a fake hole. No fix. Row closed, "fake hole" framing retired.** ⚠️ **My three proposed "fixes" (compactness test / change `R_DISK` ratio / accept) were scope I invented for a non-problem.** | ✅ closed — not a bug | Measured: `logs/A1fix_CAS_20260808_022500.log`. Code: `renderer.mm:3064` the latch, `:3037` the EMA, `:3029` `honestTarget`, `:2905-2911` the shell loop; `units.h:85` `kRsSimPerMsun`; `particles.cpp:107` `R_DISK = 18` | **?** (was **S**) |

> ~~A3①②③ are three independent bugs that all present as "BH FORMED when it isn't".~~ **Corrected 2026-08-08 16:52:31 — A3③ is CLOSED and was never a bug** (authored drag, his call). **Two remain: A3① and A3②.** They are still independent of each other; fixing one does not touch the other.

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| **A4** | 🔨 **FIX BUILT AND DEPLOYED 2026-08-10 15:12:02 — AWAITING HIS VERDICT.** ⭐ **THE DOMINANT TERM WAS NOT THE FRICTION SITE.** This row led with `:780` (friction `pow(0.9,dt)`→`pow(0.95,dt)`); measured, that is a **0.09% per-frame** change in velocity decay. The real discontinuity is the **sustain crystal lock (grep `lock = mix(1.0f, 0.05f, hardness)`, `:2794` as of 15:17:00): a 95%-per-frame velocity kill that stopped dead in ONE FRAME at the 3.5 boundary.** Matter being scrubbed to a standstill every frame was abruptly free, and the standing forces expressed at full strength over the next few frames — **that ramp-up from frozen to moving is the "split sec" jump he described.** 🚨 **Compounding it: `hardness` KEEPS INTEGRATING UPWARD through release** — the crystallization gate at `:2645` is `envelopePhase > 2.5`, true in release too — so the state hardened while its only consumer was disconnected. **Fix = a ramp across the boundary, no new branch:** the release branch now carries the same lock, eased out by `envelopeProgress`. `t=0` → identical to the sustain lock; `t=1` → `1.0`, matching silence. **Continuous at BOTH edges.** Untouched: `:780`, `:664`, `:839` — if the jump survives, those are next, in that order. | 🔨 **built, UNSEEN** | fix at `particles.metal:2758-2785`; cause at `:2771`, `:2645`, `:2655` — verified **2026-08-10 15:11:00** | — |
| ~~A4-orig~~ | 🐛 **RELEASE IS A ONE-FRAME DISCONTINUITY — HIS EYES, 2026-08-09.** *"after play when i release it kinda jumps into the next phase, it's not a smooth transition, like another thing was at work. post play for a split sec."* **Confirmed in source and it is literally several things at once.** `envelopePhase` is branched on at **27 sites** in `particles.metal`, all hard thresholds, **none blended**. Crossing 3.5 flips at minimum: `:780` friction hard-sets `pow(0.95,dt)` (normally `mix(pow(0.99,dt), pow(0.9,dt), amp×4)` — so coming out of a loud sustain, damping *drops* and everything suddenly moves more freely); `:664` `sustainHeld` goes false and the rebirth stream cuts dead mid-flow; plus branches at `:839` and `:2758`. **The fix is a ramp across the boundary, not another branch.** ⚠️ Do not "fix" it by adding a fifth branch — [[feedback_a_toggle_is_not_a_fix]]. | ⬜ **NEW — on screen every single play** | `particles.metal:780`, `:664`, `:839`, `:2758`; 27 sites total via `grep -n envelopePhase` | **S**–**M** |
| **A5** | ⏱️ **THE FUSE IS A 3–16 MINUTE STOCHASTIC WAIT — A SHOW RISK, NOT A BUG.** Nothing visible happens until one body crosses `M_BH_SEED = 50.0` (`particles.metal:185`), and **that threshold sits exactly on the IMF ceiling**: `imfMassOfId` (`:131`) draws Salpeter −1.3 over **0.08…50.0**, so the heaviest star that can SPAWN is ~49.91 and `Biggest body` reads flat at ~49.9 until a **rare heavy–heavy merger**. Verified by porting the IMF exactly (reproduces the field total to 0.03%: 594,084 vs the log's 594,276): of 2,000,000 stars, **3,334 exceed 10 M☉ (0.167%) and only 687 exceed 25 M☉ (0.034%)**. Ordinary merging runs fine the whole time — one run logged **68 merges with `Mmax` never moving**, because all 68 were light pairs. Measured crossings: **3.5 min · ~8 min · 10+ min (quit) · 16 min (never)**. ⭐ **PROPOSED FIX — MASS SEGREGATION, and it is missing physics, not a cheat:** mass is `imf::massOfId(i)` (`particles.cpp:307`), a pure function of slot index, while placement is an INDEPENDENT component draw (disk 75% / nucleus 10% / halo 15%) — so the 687 heavyweights are scattered at random and only ~10% land in the nucleus. Real clusters are mass-segregated (massive stars sink by dynamical friction). Making *placement* mass-dependent concentrates them in the dense nucleus and the fuse shortens by itself. 🚨 **Leaves `imfMassOfId` byte-identical on the GPU — which is REQUIRED, because the A2 refund depends on recovering spawn mass from the slot id.** 🚨 **Do NOT instead widen the merge cross-section — an uncapped capture radius is exactly what caused the A1′ runaway.** | ⬜ **NEW — his ask, "can we make the fuse faster"** | `particles.metal:185` `M_BH_SEED`, `:131` `imfMassOfId`; `particles.cpp:307` mass, `:132-134` the component draw | **M** |
| **A6** | 💧 **REFUND FLOOR LEAK — THE GUARD CANNOT DETECT ITS OWN FAILURE MODE.** In run 1, **17 `[REBIRTH]` samples charge a withdrawal while the hole is ALREADY at the 50.0 floor** (`withdraw=0.1 … hole=50.0`). The guard is `(wdraw > gMaxMass)` at `renderer.mm:3096` — `0.1 > 50.0` is false, so it never flags. Refunds keep being paid after the hole has nothing left, i.e. **mass is created**. ⚠️ Direction matches run 1's **+1,543 M☉ (+0.260%)** drift; **magnitude NOT reconciled — candidate cause, not a conclusion.** Distinct from **B5** (−280 M☉): this one is positive and 5× larger. | ⬜ **NEW** | `renderer.mm:3096` the guard; `particles.metal:731` `mass = imfMassOfId(id)` | **S** |
| **A7** | ❌ **PREMISE NOT SUPPORTED — STACKED ACROSS 4 RUNS, 2026-08-10 15:45:00.** This row generalised from ONE run, which is the thing this project bans. Quarter-mean FPS, first quarter → last quarter: `A2_refund_20260809_110828` **56.2 → 35.1 (−38%)** · `A2_refund_20260809_202105` **38.6 → 44.0 (+14%, it got FASTER)** · `A2_refund_20260810_090652` **59.1 → 54.2 (−8%)** · `A2_refund_20260808_181210` **46.5 → 45.8 (−2%)**. **Three of four show no meaningful degradation and one improves.** ⭐ **Live confirmation the same day: pid 6225 ran 41 minutes and was sitting at 93 fps** when he screenshotted it — because the field had been consumed and there was almost nothing left to draw. **FPS tracks how much is ALIVE, not how long the run has been going.** ❌ **My overdraw hypothesis is REFUTED too** — I predicted drawn pixel size grows with heating. `[KPROBE-SCALE] meanPx` grows only in the −38% run (1.01 → 4.77); it is **flat at ~1.00–1.06 in the runs that stayed fast**, while plasma temperature climbs to ~5×10¹¹ K in **all four including the flat ones**. So heating is not the driver and pixel growth is not general. ⬜ **WHAT ACTUALLY REMAINS OPEN: why run 1 specifically.** It is the only run with both the decline and the `meanPx` spike, so those two are worth treating as one question rather than two. **Do not re-open this as "FPS degrades over a run" — that framing is now measured false.** 🚨 The row's one durable point survives untouched: **`dt` is per-frame (`renderer.mm:1339`), so whatever DOES cost FPS silently slows the physics** — see [[feedback_trust_the_average_not_transients]]. | ⬜ **narrowed, premise refuted** | 4 logs stacked, `logs/A2_refund_*`; his screenshot 15:52 (93 fps on a consumed field) | **S** (run 1 only) |
| ~~A7-orig~~ | 📉 **FPS DEGRADES OVER A RUN — UNEXPLAINED.** One run walked **57 → 38 fps over 10 minutes** with no input and a field that was barely merging (`live` 2,000,000 → 1,999,993). Run 2 at 10M sat at median 31 with 35.8% of samples under 30. 🚨 **Matters directly for Berlin: `dt` is per-frame (`renderer.mm:1339`), so a sagging frame rate silently slows the physics mid-set** — and it is how a null result gets manufactured ([[feedback_trust_the_average_not_transients]]). Not diagnosed. | ⬜ **NEW** | `logs/A2_refund_20260809_110828.log` (the 57→38 walk); `A2_refund_20260809_202105.log` (median 31) | **?** |
| **A8** | ❓ **`feed` RETURNED NONZERO FOR THE FIRST TIME EVER.** Every run ever logged showed `feed=0/0.0 scan=0` — the seed-feed path had never scanned once, and that was established as a standing fact. Run 2 (10M) logged **`seeds=6 feed=2/0.3`**. Either the path finally engages at higher particle counts, or something else changed. **Unexplained; re-measure before anyone relies on the old "feed never fires" claim.** | ⬜ **NEW** | `logs/A2_refund_20260809_202105.log`, final `[GRAV]` | **S** to settle |

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

## B. PHYSICS — measured, not acted on

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| B1 | Centre the horizon test on the mass, not the origin | ⬜ | Same as A3② — **these are the same fix.** Folded. | — |
| B2 | `RADIAL_MAX_R = 5.0` hard cutoff — the seed wanders outside the measuring window entirely | ⬜ | `particles.metal:300`; guard at `:3814` | **S** |
| B3 | **bit4 origin-pin — PREMISE RE-OPENED 2026-08-07 12:41:25.** The spring exists (a bounded pull on any body ≥ 50 M☉ toward `(0,0,0)`, gated off during play) — but **it ships OFF** and only the UI checkbox or the `SS_INERT_KEEP` ladder can enable it. So in the default launch config it is **not** what blocks multi-BH; the unconditional ORIGIN LOCK (A3②) is. Inherited from 08-04 §4 and not re-derivable from the code as written. **Re-establish what this row is for, or fold it into A3② and close it.** | ⬜ premise unverified | `particles.metal:1170` the spring; `app_state.h:48` `= false`; `main.cpp:2135` the pack, `:1260` the checkbox, `:270` the ladder | **S** to settle, then **?** |
| B10 | **DENSITY PRESSURE — an unfinished TODO, not a decision.** Disabled with *"TEMP DISABLED for Step 1 verification… **Re-enable in a later step** after we have orbital dynamics holding particles in place."* That later step never came. It was overpowering gravity (pressure scale 12 vs gravity scale 1) and blowing the Gaussian spawn outward. ⚠️ **Do NOT simply switch it on: it OPPOSES collapse, and A1 needs collapse.** Settle A1 first, then decide whether this is revived at a sane scale or deleted. | ⬜ **NEW** | `particles.metal:863` `if (false /* su.gridSize > 0 */)` | **M** |
| B4 | Pull-gate step 2 | 🚫 | blocked on B3 | **M** |
| B5 | The −280 M☉ residual drift (wall/park exclusion) | ⬜ | not re-verified — from 08-04 §1 | **S** |
| B6 | **Corpse compaction.** 64% of the buffer was corpses; every compute dispatch is 2,000,000 threads regardless. In **direct tension** with `imfMassOfId(id)` requiring that particles never change slots — the refund depends on that property. Needs its own session. | ⬜ | `particles.metal:131` `imfMassOfId`; measurement from 08-07 §3 | **L** |
| B7 | **Kill the tube** — *"figure out what the actual truest form of soundwaves in 3d space is."* The cylindrical clamp is the symptom; the Bessel `J_m` basis is the real work. His own prior design (3D scalar ψ, damped wave PDE) is the starting point. | ⬜ | 08-04 §6.8 · `space_synth_neo_architecture` | **L** |
| B8 | **"Start sequence / launch grid"** — he named these as needing fixing and never said what he meant. | ⬜ | 🚨 **ASK BEFORE TOUCHING** | **?** |
| B9 | Merger flash is invisible — temp baseline 5.29e11 makes a `+2.0` flash a 1e-11 relative change | ⬜ | not re-verified — from 08-03 | **S** |

---

## C. VISUAL ENGINE — his stated priority (*"we follow paragraph 9"*, 2026-08-02)

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| C1 | Bloom → mip pyramid | ✅ | `postfx.metal:547` — *"this bloom is looking a lot better"* | done |
| C2 | Grade LUT stage, 33³ RGBA16F after the live tonemap | ✅ built + approved, now committed | `postfx.metal:361` samples it; `renderer.mm:811` uploads it; `:3884` binds it; `:3919` same grade on the Syphon feed. ⚠️ **ADDED stage — the live tonemap is NOT ACES, never replace it** | done |
| **C7** | ✅ **DIAGNOSED 2026-08-08 01:30:58 — and it is not a colour bug.** The radial Cartwheel law **already exists and is correct**: Shakura–Sunyaev `T ∝ r^(−3/4)`, `render.metal:1667`, written 2026-07-23. It is **gated on `cam.horizonR > 0`** — and `r_h` measured **`0.0000` for the entire pre-runaway life of every run logged**. It only goes positive once A1′'s runaway is already eating the field. ⚠️ **"EVERY RUN" IS TOO STRONG — corrected 2026-08-08 16:31:44 while measuring A3③.** Share of `[HORIZON]` samples with `r_h > 0`: soak **474/6,975 = 6.8%** · seed 7 **120/125 = 96%** · `A1fix_CAS` **1,529/1,534 = 99.7%**. The soak is the outlier, not the rule — in two of three logs the gate is open within seconds of spawn and **stays** open. Since it is realization-dependent (seed 7 is pre-fix too, so this is the known nondeterminism, not the A1′ fix), **C7 may be workable now without waiting on anything.** Re-measure before treating this row as blocked. 🚨 **So the window where the Cartwheel look is possible is exactly the window where the field is being destroyed. C7 is downstream of A1′ and cannot be worked independently.** Pre-horizon, colour is `unifiedKelvin(mass, heat, kinetic)` — no radial term exists, so it *cannot* organise by radius. The surviving half-space is **beaming on LUMINANCE** (`:1307`, `K_BEAM=0.8`), the only line-of-sight term left; ⚠️ that it reads as *colour* via bloom is a hypothesis, testable with `DOPPLER_K_BEAM=0`, **needs his eyes**. Doppler-as-hue was removed 2026-06-26 on his verdict — **never re-propose it**. | ⬜ 🚫 gated on A1′ | `docs/MEASURED_2026-08-08_C7_cartwheel_colour.md` | **S** *(after A1′)* |
| C7b | 🐛 **`dopplerColor` is dead AND its comment lies.** Declared `:1273`, computed `:1305`, **never read**. The comment at `:1440` says *"Doppler shift is already applied above via dopplerColor"* — **false**. Fourth instance of built → changed course → leftover now misinforms. Delete both. | ⬜ **NEW** | `render.metal:1273`, `:1305`, `:1440` | **S** |
| **C3** | **Star size floor** — 99.2% of stars pinned to one pixel. Nothing pre-FX can look cinematic until this moves. | ⬜ | `render.metal:1246` `out.pointSize = drawn`; `:1916` the clamp. 🚨 **BUILD THE DIALS FIRST** — 4 attempts, 0 progress, all reverted | **L** (was `M`; corrected on the 4-attempt record) |
| C8 | **Chladni sharpness** — *"almoooost."* Standing physics finding: `ridgePull` uses the SCULPT gradient, not the eigenmode ∇Ψ, and there is no node dissipation. This is a physics fix, not a postfx one. | ⬜ | `space_synth_chladni_alpha_is_hz_2026-07-28` | **M** — 🚨 **ask what "sharp" means numerically first** |
| **C4a** | **Camera motion blur — BUILT, DISABLED, bug diagnosed.** `prevViewProj` is fully plumbed and a screen-space velocity is computed **every frame**: unproject through `inverseViewProj`, reproject through `prevViewProj`, difference the UVs. The consumer is switched off behind **`if (false && velLen > 0.002)`** — the **second `if (false)`** on this board. **Why:** it dimmed the glow when the camera moved (his *"FX bug out / glow turns off when I move the camera"*). Reading the stage order, the cause is sharper than the source comment says: the block sits **after** the tonemap (`:285`), the grade LUT (`:338`) and the neon/VJ grades, so `color` is fully display-referred — but `:430` samples the **raw HDR** input and runs it through **`acesTonemap`**, which is *not* this pipeline's tonemap. **Two mismatches — graded-vs-ungraded, and ACES-vs-the-real-tonemap — then a divide by N.** Fix = make the samples match the base, do not reintroduce ACES. | 🔨 | `renderer.h:162`; `renderer.mm:343`, `:3866`, `:3871`; `postfx.metal:401-414` (live), `:420` (the `if (false)`), `:432` (the wrong tonemap) | **S** |
| C4b | **Per-particle motion vectors** — genuinely not started. C4a's velocity is **camera-only**: `ndcPos` hardcodes `z = 0.99`, so everything is assumed at the far plane and nothing about particle motion is captured. This is where the real blocker lives — additive blending with depth-write off means **nothing decides which particle OWNS a pixel's vector.** Prerequisite for TAA. | ⬜ | `postfx.metal:401` the hardcoded `0.99` | **L** |
| C5 | Chromatic aberration → proper spectral/lens model (currently a flat radial RGB offset) | ⬜ | `postfx.metal:170` | **M** |
| C6 | Scanlines — rebuild or remove. Currently a Nyquist-rate sine with no filtering: that is aliasing, not an effect. | ⬜ | `postfx.metal:446` | **S** |
| C9 | `bit18` flux-conserving arc **has never executed** — `sL ≡ 1.0` for every particle since it was written 2026-07-24 | ⬜ | `render.metal:1158` says so in the source comment; `:2233` confirms the downstream branch is a no-op | **S** to delete, **M** to revive |
| C10 | 32 build warnings → zero. `render.metal:485` is the one real one. | ⬜ | not re-counted this session (would require a rebuild). 🚨 **never delete `ssDiskTempShape`** | **S** |
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
| **E5** | 🔨 **BUILT 2026-08-08, UNCOMMITTED, UNSEEN — his "groundwork" call.** *"Static info in a ui is stupid… this is groundwork everything else builds on."* The **GALAXY / REAL SCALE** block was entirely `BH_ANCHOR` (Sgr A* textbook constants) and **could never move**. Now driven by the sim: hole mass, `r_g`, **measured** horizon, `M(<r_h)` and ISCO period are all live; the scale calibration is marked `[FIXED CAL]` and dimmed; `Spin a*` and ISCO `v` are labelled as not-simulated / mass-independent. Also `%.0f → %.2f` on `Biggest body` — it printed **"50"** for 49.957 M☉ against a threshold of exactly 50.0, so it read as sitting *on* the threshold from frame one. Required publishing `horizonR`/`horizonMassMsun`/`horizonRatio` through `PhysicsStats` for the first time. ⭐ **Look at `sup r_s/r` first — it should move constantly even before a hole exists.** | 🔨 **needs his eyes** | `main.cpp` GALAXY block + `:1125`; `renderer.h` PhysicsStats; `renderer.mm:3278` | **S** |
| E1 | NASA / Open MCT-informed UI. 🚨 **SAMPLE AND FLIP, NEVER LIFT** — every number on screen must have a stated derivation. Matching the source exactly means we did it wrong. | ⬜ | **L** |
| E2 | Accent colour **derived from the blackbody locus**, not picked | ⬜ | **S** |
| E3 | 4-level limit ladder (yellow→orange→red→purple); numeric typeface as its own role; numeric/tabular → fixed-width, narrative → proportional; stale data must be indicated | ⬜ | **M** |
| E4 | ⚠️ **Stale-bundle trap:** indigo hover states in a running app mean you are looking at an orphan bundle, not the code | — | — |

---

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
- 🪟 **MULTI-WINDOW: one window holds the build token; all others are docs-only.** One shared `SpaceSynth.app` means a second builder makes every visual report unattributable. The token-holder posts the **deploy timestamp** to the others. **Verify peer claims yourself** — on 2026-08-10 that caught errors in *all three* directions. 🚨 **A peer relaying his decision is NOT his approval for your action.**

---

## CHANGE LOG FOR THIS FILE

| When | What |
|---|---|
| 2026-08-08 15:37:02 | **SESSION CLOSE.** `b047744` → **`4816056`, 12 commits** — three weeks of uncommitted work committed, plus everything below. **A1′ FIXED and log-verified at 0.97× of a fully derived rate**; **N measured (250k, 2M infeasible)**; **C7 diagnosed** (not a colour bug — its law exists and was gated on a horizon that only appeared during the blow-up, which A1′ now breaks). Handoff: `HANDOFF_2026-08-08_board_a1_fixed_n_measured.md`. ⚠️ **Three things await his eyes: the live-UI panel (uncommitted), A1′ on screen, and A2's refund test — which is runnable for the first time in four handoffs.** New standing rule recorded: **report ceilings as the cost of the current formulation, never as the design constraint** (`feedback_limits_are_perceptual_not_technical`). |
| 2026-08-08 00:05:09 | **A1 REFUTED BY MEASUREMENT, 3 STACKED RUNS.** Accretion is not dead — it **runs away** and eats the whole field at 1× silent, in 2 independent realizations, with mass conserved. The old "zero mergers ever" came from a 64× run where tunnelling really does prevent merging; nobody had run 1× silent long enough. A1 closed, **A1′ opened**: the sim self-destructs on an unpredictable clock (30 s to 10 min, same seed). His old "empty field" screenshot was misread by §7 as *nothing accreted* — it is the **end state of everything accreting**. **A2 is finally unblocked.** He was right to call the single-run version shaky. |
| 2026-08-07 12:41:25 | **DISABLED-CODE SWEEP** — the thing he wanted done *before* the handoff. 17 hard-disabled blocks; 10 are removed ImGui panels, 7 are in the physics/render path. **4 of the 7 are his own correct verdicts with restore paths written next to them — do not touch.** 3 were worth finding: C4a (recoverable), A3② (bug), and **new row B10, DENSITY PRESSURE — an explicit "re-enable in a later step" TODO that was never done.** Also newly recorded: `render.metal:589` is unreachable in every configuration (`bhDiskAxisY` is `0.0f` at every assignment site). **And the sweep contradicted a board row: B3's bit4 origin-pin ships OFF, so it cannot be what pins the hole in normal use — premise re-opened.** |
| 2026-08-07 12:31:07 | **He was right and the board was wrong: motion vectors WERE started.** I had marked C4 ⬜ with "08-02 doc" in the evidence column — hearsay by this file's own standard, and the one row I did not read the code for. Split into **C4a** (camera half: BUILT and running, consumer disabled behind the board's *second* `if (false)`, bug diagnosed to mismatched tonemaps at `postfx.metal:432`) — `S`, **pulled back into the Berlin cut** — and **C4b** (per-particle, genuinely not started, still `L`, still deferred). **Lesson: a row without a `file:line` is not a status, it is a rumour.** |
| 2026-08-07 12:24:09 | **His triage: A, B, C are the show. D and E are post-Berlin.** Added the TRIAGE section. Because A+B+C is still ≈23 sessions vs 26 days, cut one level deeper: deferred B6/B7/B8 and C4/C11 (≈9 sessions, none of them visible on stage), leaving **≈13.5 sessions**. D6 flagged to him as a show-risk exception living in a deferred section — **parked, not dismissed.** |
| 2026-08-07 12:18:44 | Added **WORKLOAD PER SECTION** at his request. Totals ≈32 sessions + 4 unknowns against 26 days — recorded explicitly that this board is a triage list, not a finish list. One estimate corrected on evidence: **C3 `M` → `L`**, because an item with 4 reverted attempts on the record is not a one-session item. |
| 2026-08-07 12:02:31 | Created. Every A/B/C row re-verified against source at commit `3a36438`; D and E verified as zero-code. Two corrections to the inherited docs recorded: A3② is an `if (false)` ORIGIN LOCK (blunter than "the profile is centred on origin"), and B1 is not a separate item — it IS A3②. C7's half-space lead is explicitly downgraded to undiagnosed: the only surviving `half-space` mention in the renderer is a *removed* gate. |
