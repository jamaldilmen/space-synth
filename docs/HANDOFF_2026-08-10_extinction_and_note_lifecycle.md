# HANDOFF — 2026-08-10 23:15:00

**Session:** BOARD window (the main session; the other two are CAMERA and AUDIO).
**Berlin New Media Week:** 2026-09-02 — **23 days out.**
**Reference of truth is still `docs/BOARD.md`.** This file is a dated snapshot; the board is live.

---

## 0. READ THIS FIRST — THE STATE IN SEVEN LINES

1. **Committed and pushed:** `ea2cfba` on `session-2026-06-30-honest-spacetime-friction`. Verified on the remote.
2. **UNCOMMITTED and in the deployed bundle:** F5 (camera), the fullscreen launch toggle, and **A9 extinction v3**. Nothing after `ea2cfba` is committed.
3. **Deployed bundle: `2026-08-10 21:07:00`** (binary + metallib). It contains `ea2cfba` + F5 + fullscreen + extinction v3.
4. **Nothing is running.** The app exited on its own — **the 4th silent disappearance today.**
5. **Three things are built and have NEVER been seen by Jamal:** F5, extinction v3, and the live-UI panel.
6. 🚨 **ALWAYS LAUNCH FULLSCREEN NOW** — his standing order. `open -n SpaceSynth.app --env SS_FULLSCREEN=1`.
7. 🚨 **ONE LIVE APP, NO PARALLEL BUILDS** — his order, 16:01:00. The camera worktree is frozen and unbuilt.

---

## 1. WHAT SHIPPED — `ea2cfba`, pushed

**A4, the frozen→star-map handover.** His words on the result: *"the fix is good enough. its not 1/10 yet."*
**The row stays OPEN.** He asked explicitly for "not 1/10 yet" to be on the board.

**Root cause, and it was a GATE, not a damper.** Self-gravity is scaled by `(1 - playGate)` and `playGate = smoothstep(0.0, 0.025, totalAmplitude)` (`particles.metal:1200`). Amplitude sits above 2.5% for the whole hold **and nearly the whole release**, so self-gravity was fully OFF the entire time and snapped fully ON in the last few milliseconds when the tail dived through the threshold. **That snap was the transition he had been complaining about for the whole session.**

**Fix:** a separate `gravSupport = smoothstep(0.0, 0.5, totalAmplitude)`, applied at the gravity scale (`gkick *= (1.0f - gravSupport)`) and at the near-field skip gate. Gravity now returns in proportion to how far the sound has faded. Nothing switches, no branch is crossed.
**Kept separate from `playGate` on purpose** — `playGate` also gates collisions, the seed sink, accretion relaxation, mass-inertia and the velocity cap, none of which should move.
**The held shape is deliberately unchanged:** sustain sits at 0.700 amplitude, above the 0.5 band, so support is saturated exactly as before. ⚠️ He noted separately: *"the held shape has never been perfect"* — **still open, untouched.**

---

## 2. WHAT IS BUILT AND UNCOMMITTED

| Change | Files | State |
|---|---|---|
| **F5** — `viewForward` into `CameraUniforms` | `camera.h`, `main.cpp`, `render.metal`, `renderer.h`, `renderer.mm` | 🔨 built, **UNSEEN** |
| **Fullscreen launch** | `src/ui/window.mm` | ✅ working, verified live |
| **A9 extinction v3** | `render.metal` (end of `particle_vertex`) | 🔨 built, **UNSEEN**, partially measured |
| Board | `docs/BOARD.md` | — |

---

## 3. 🚨 A9 EXTINCTION — THE MAIN EVENT, AND IT WENT THROUGH THREE VERSIONS

**His question, which reframed the whole afternoon:**
> *"the true question is why does matter at high concentrations look like ass. it's supposed to look amazing."*

**ANSWER: density could only ever ADD light.** The particle pass blends `One + One` (`renderer.mm:658-663`). N particles in a pixel is N× the light, unbounded — so every dense region climbs to saturation and flattens into a white lump with no interior structure. In real astronomy images essentially all structure in a dense region comes from what **blocks** light. Emission alone cannot make those shapes.

🚩 **AND THE ABSORPTION PASS ALREADY EXISTED, COMPLETE, BEHIND `if (false)`** at `renderer.mm:3504`. Disabled on his own field verdict 2026-07-23 16:34 (*"a low-res shadow thingy / yellow underbelly"*) because it **composites un-depth-sorted splats** — a flat wash instead of a silhouette. Its own comment preserves the concept pending depth ordering.

**A9 does the same physics without compositing:** each particle marches the hash grid toward the camera, accumulates optical depth τ, and scales **its own** emission. Multiplying a particle's own output is **order-independent by construction**, so the v1 failure mode cannot recur. Reuses `applyInverseSpin` (written 2026-07-25 for the metric ray) and `physPosW`. **First real consumer of F5** — the march direction is `cam.viewForward`, not `normalize(-cameraPos)`.

### THE THREE VERSIONS, AND WHY THE FIRST TWO WERE WRONG

⭐ **All three were judged by MEASUREMENT, before Jamal ever looked.** The discriminator is `[LUMPROBE] avgRGB` and specifically the **B/R ratio**, because absolute scene brightness varies ~1.5× run to run while B/R is stable at **1.70** across every extinction-off run (0.456/0.292/0.435 for R across three baselines; B/R = 1.72 / 1.68 / 1.71).

| version | mechanism | avgRGB | **B/R** | verdict |
|---|---|---|---|---|
| OFF baseline ×3 | — | — | **1.72 / 1.68 / 1.71** | reference |
| **v1** 20:47:36 | `tau += 0.004·min(cnt,128)`, scaled scalar `luminance` | 0.184 0.265 0.315 | **1.71** | ❌ **greyed the whole scene 53%.** B/R unchanged — a scalar CANNOT redden. |
| **v2** 21:05:36 | `smoothstep(6,30)`, per-channel on `out.color` | 0.174 0.201 0.194 | **1.12** | ⚠️ **reddening works** — but still firing everywhere; inverting τ says the mean sightline was **3.0 of 6 samples fully dense**. |
| **v3** 21:07:00 | `smoothstep(150,1500)`, per-channel | 0.294 0.421 0.496 | **1.69** | ✅ **sparse field untouched** (B/R back at baseline; its 0.294 matches the 08-09 baseline's 0.292 — the apparent dimming was run variance, not extinction). |

**Why `smoothstep(6,30)` failed:** it is the dust shader's number, and it works there **only because that shader also gates on `cold` and gas-mass ≤ 3 M☉**, which rejects most particles before density matters. Lifted on its own into an ungated march, it catches everything. The grid's real dynamic range is wide — the flare code clamps to `MAX_PER_CELL = 128` and warns of ~50k cells.

**Per-channel is the thing that makes dust look like dust:** `kExt = float3(0.55, 0.78, 1.00) * kAbsorb`, blue absorbed hardest, applied to `out.color` because the fragment forms emission as `in.color * in.luminance` (`render.metal:2409`), so it lands exactly once.

### ⚠️ WHAT IS STILL UNPROVEN ABOUT A9

**Does v3 actually fire at high concentration?** Suggestive, **not clean**. In the 3,928-sample soak, B/R fell **1.72 → ~1.38** as the field concentrated — the predicted direction. 🚨 **But the same run consumed 96.9% of its field into one body (`biggest body 575,566 M☉` of 594,276), so the surviving population changed at the same time.** Brightness and colour both had another reason to move. **Treat as encouraging, not established. A clean test needs a dense field that has NOT been eaten.**

### 🚨 A9 PERFORMANCE — MEASURED, AND IT IS EXPENSIVE

| | mean fps |
|---|---|
| Extinction ON (v1 / v3) | **31.9 / 31.6** (soak overall 34.7, **27% under 30**) |
| Extinction OFF, same 2M | **54.9 / 42.0 / 57.4** |

**Roughly half the frame rate.** Six density-grid reads per particle per frame on 2M particles, ungated. **The cost is the march itself, not the absorption** — v1 and v3 cost the same despite wildly different τ.

🚩 **THE OBVIOUS OPTIMISATION IS WRONG — DO NOT DO IT.** Early-exiting the march after a couple of empty samples is nearly free but would **miss a dense region beyond a gap**, which is exactly the backlit case that produces a silhouette. It would silently delete the effect where it matters most.
**Two that are sound:** (1) fewer, longer steps — 3 steps × 3 cells, half the reads, slightly coarser lanes; (2) ⭐ **march a coarse 32³ mip of `cellCounts`**, built once per frame in a small compute pass — far more cache-friendly and fewer steps cover the same distance. **Neither is built.** Both change the picture, so **neither should be built before he judges the look.**

---

## 4. FINDINGS THAT OUTLIVE THIS SESSION

### 🚨 A1′-endgame — THE FIELD EATS ITSELF, AND THE FIX ONLY BOUGHT TIME
Observed twice today. A 41-minute idle put **60% of the field into one body**; tonight's ~2-hour soak reached **96.9% in one body**. **This is not a regression** — the A1′ rate limit made growth *linear*, exactly as measured, **but linear is unbounded in time**: at 2,451 M☉/wall-s the whole field is consumable in ~4 minutes of active accretion. The "field survives, 64% alive" evidence everyone relied on was a **mid-run snapshot read as a steady state.**
🚨 **Berlin: a set is 40–60 minutes and soundcheck-to-doors is longer. Any unattended stretch ends on an empty screen.** A bound (feedback / Eddington-like term) is a **different fix** from a rate limit and **does not exist anywhere in the code.**

### ❌ A7 — "FPS DEGRADES OVER A RUN" IS MEASURED FALSE
Stacked 4 runs, first-quarter → last-quarter: **−38% · +14% · −8% · −2%**. Three show no meaningful degradation and one got faster. The row generalised from one run. **My own overdraw hypothesis was refuted with it** — `meanPx` grows only in the −38% run and is flat in the fast ones, while plasma temperature climbs identically in all four.
⚠️ **And a later finding weakens my own analysis:** `[KPROBE-SCALE] meanPx` is in **device pixels**, so it means different things at different window sizes and **must not be compared across resolutions.** The four-run FPS result stands; the pixel-size correlation does not.

### ⭐ A3②-white — THE "WHITE MERGERS" ARE THE ORIGIN-LOCK BUG WEARING A COSTUME
His report: *"we had them black once, then some changes turned them white again… they look cheap and sluggish."*
`render.metal:1941` draws the bright seed billboard **only while `cam.horizonR <= 0`** — it is meant to stand down once an honest horizon exists (that stand-down is what killed the July "yellow thing"). It never stands down because `horizonR` reads 0.
⚠️ **SELF-CORRECTION: this is NOT "the seed wanders off the origin", and the origin lock is NOT a bug to undo.** `renderer.mm:3340-3347` records it as **his own call** (*"lensing and the hole drifted apart"*). **The real mechanism: the measurement assumes ONE hole and he has TWO.** The COM pin recentres the *field*, so with two lumps the origin sits **between** them and the profile measures the empty gap. His screenshot is the proof: *"Horizon: none yet, sup r_s/r = 0.000"* beside a 356,475 M☉ body. Tonight's soak shows the same pathology: `CORE 0 M (0.0% in)` while `biggest body 575,566 M`.
**Proposed fix (NOT built, and it touches neither the origin lock nor the physics):** gate the blob on **mass**, not on `horizonR`. At 356,000 M☉ evaluating a stellar mass–luminosity law is wrong on its own terms. The deeper problem — the horizon measurement cannot see a two-body configuration — stays open.

### 🚩 FOUR `if (false)` FEATURES FOUND ON THIS PROJECT
The dust pass (`renderer.mm:3504`), the origin-lock COM refinement (`renderer.mm:2987`), the envelope→radius coupling (`particles.metal`), and the A3② profile refinement. **A disabled-but-complete feature is invisible to every grep for "what is on", and its comments read like working behaviour.** Standing sweep: `grep -rn "if (false" src/`.

---

## 5. THE NOTE-LIFECYCLE AUDIT — `docs/AUDIT_2026-08-10_note_lifecycle_chain.md`

Written at his direct request. Full key-down → hold → key-up → star-map chain, every claim carrying a `file:line` read the same day.

**Verdict:** attack is an **authored explosion**; decay/sustain is the **cavity eigenmode — real physics, the good part**; the sustain hold is a **velocity damper we label crystallization**; release **switches the authored forces off**. The two ends of the chain are physical, the middle is stagecraft.

⭐ **The structural line worth keeping:** the crystal lock scales the *carried* velocity at `particles.metal:2795`, but `finalV` is built at `:2847` as `(vp·fric + shiftV)·soften` — **the force impulse is added AFTER the lock, untouched.** So a hold bleeds off speed while every force keeps pushing, and nothing is stored in tension. **A real solid resists FORCE; ours resists SPEED.** That is his *"it continues from before it actually stopped"*, exactly.

**§1 of the audit retracts my own claim** that release is a fixed 400 ms. `envelope.cpp` does `relDur = clamp(sustainHeld, params.release, 1.5f)` — **0.400 is the FLOOR**; release already scales with hold length.

**§4 proposes the scientifically true version** (sound = pressure **support** against self-gravity; release = support decaying, so nothing switches). **He approved a scoped version of exactly this and it shipped as the `gravSupport` fix.** The fuller version — replacing the sustain damper with a real support term — is **still open and is his call.**

---

## 6. ⏸️ EXPERIMENTS THAT FAILED — DO NOT REPEAT THEM

| What | Result |
|---|---|
| **A4 settle-hold** (hold the release regime 2 s after the envelope goes Off) | Built 16:07:41, **rejected on sight** and reverted 16:09:36. *"noo because now the stuck moment is before the pause u just introduced."* ⭐ **It did not hide the snap — it ISOLATED it**, proving the discontinuity sits at note-off, not at release→silence. **Recorded in `main.cpp` so it is not retried.** A rejected change that localises a fault is worth more than a pass. |
| **"Release is a fixed 400 ms"** | Wrong. See §5. |
| **A9 v1 / v2 thresholds** | Both measured wrong before he looked. See §3. |
| **My overdraw hypothesis for A7** | Refuted by run 3. |
| **"The seed wanders off the origin"** | Wrong mechanism. See §4. |

---

## 7. PEER WINDOWS

**CAMERA** (`[1012d2]`) — stood down, complying. Worktree at `779a517`, **unbuilt and unlaunched**. F5 was taken as a `git diff` and `git apply`-ed into main (clean, no 3-way) rather than copied, because `renderer.h`/`renderer.mm` both moved in `ea2cfba`. ⭐ **Its layout anchors survived the move and I checked rather than hoped:** main's `renderer.h` change was to `PhysicsStats`, not `CameraUniforms` (`git diff 779a517..HEAD -- renderer.h | grep -c CameraUniforms` → 0), so `sizeof == 272` and offsets 108/200/268 still hold, and **both the C++ and Metal asserts passed in the main tree** — a stronger result than the worktree build.
**F6 is blocked** until W1 gets a verdict. Design-on-paper only.

**AUDIO** (`[7c9582]`) — docs only, zero source, zero builds. D6 spec complete (~26 KB). ⭐ **Its finding worth carrying: the queue's true high-water mark is 512, not 256** — producers cap at 256 but the re-queue front-insert at `synth.cpp:139` has **no cap at all**, and because the two vectors ping-pong through `swap`, **both** must be reserved or capacity migrates after the first swap. **`synth.h:111` comments `swapBuffer_` as "Pre-allocated… avoids RT heap alloc" and it is never reserved anywhere** — the comment asserts the guarantee the code does not provide, which is why it survived for months.
**Increment 1 = `reserve()` both vectors.** ⚠️ **Cannot be judged by ear; a correct fix sounds identical.**
⬜ **OPEN QUESTION FOR JAMAL (§6.1):** should `activeVoiceCount()` stop draining the queue? Assumed YES; does not block Increment 1, **must be answered before Increment 3.**

---

## 8. METHOD RULES EARNED TODAY

1. 🚨 **A bundle timestamp is evidence for exactly ONE build.** I rebuilt the main bundle for A4 and left the board describing the binary I had just destroyed. **Update rows in the same action as the build.**
2. 🚨 **`pkill` silently discards whether it matched.** Use `pkill -x SpaceSynth && echo "KILL: matched" || echo "KILL: no match"`. This mattered: pid 6225 vanished in a window where my kill had not yet run.
3. 🚨 **`pgrep -x` cannot tell two trees apart** — both produce a process named `SpaceSynth`. Use `for p in $(pgrep -x SpaceSynth); do ps -p $p -o pid=,lstart=,comm=; done` — full path names the tree. (Moot now that he has ordered one live app, but keep it.)
4. **Line numbers decay silently.** My A4 edit shifted every `particles.metal` reference below 2758 by +23 **within three minutes of writing them**, and chasing it found A3②'s cite already stale by ~76 lines. **Cite a grep anchor, or stamp the number with a verification time.**
5. **Three distinct citation failure modes** (AUDIO's distinction, and it is right): *decay* (fixed by re-grepping), *misread* (fixed by re-reading), and ⭐ ***dead-code cite*** — correct file, correct line, a body nobody executes. **The last is the most dangerous because the cite verifies perfectly.** That was A0a/A0b.
6. ⭐ **Verify by measurement, not by build success.** A9 v1 and v2 both compiled, deployed and were **wrong**. `[LUMPROBE] avgRGB` caught both before they cost him a verdict. **B/R is the robust discriminator; absolute brightness varies ~1.5× run to run.**
7. 🚨 **Star size is in DEVICE PIXELS** (`out.pointSize`, never normalised to the drawable), so windowed and fullscreen genuinely differ and **`meanPx` must never be compared across resolutions.**

---

## 9. WHAT I WOULD DO NEXT — his call, nothing started

1. ⭐ **Get verdicts on the three unseen things** — extinction v3, F5, the live-UI panel. All in the 21:07:00 bundle, one fullscreen launch. **⚠️ F5 and extinction are stacked in this build; if something looks structurally wrong there are two suspects.** A clean F5-only build is a two-minute round trip if he wants it.
2. **Then decide extinction: keep, tune `kAbsorb`, or revert** — and only after that, optimise perf (mip march), since the optimisation changes the picture.
3. **A1′-endgame** is the biggest show risk on the board and nothing addresses it.
4. **A3②-white mass gate** — cheap, removes a visible artifact.
5. **F6** the moment W1 is verdicted; **D6 Increment 1** whenever he clears a build slot for AUDIO.

**Do not commit anything without his explicit order.** The last one was *"lets move on commit and push everything this far"* at 17:10 and it produced `ea2cfba`; everything since is deliberately uncommitted.
