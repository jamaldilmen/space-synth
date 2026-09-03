# NIGHT BRIEFING — 2026-09-03

**Written by BRAIN. Covers 05:33:08 → 06:1x while he slept. Cologne in 2 days (2026-09-05).**

Tree: `true-physics` @ `6530c45`, **19 commits unpushed, no push order given.**
**Nothing committed tonight.** Three source files modified, all separable by file. Two untracked design docs.

---

## 1. READ THIS FIRST — WHAT NEEDS YOUR EYES

One bundle is built and carries **three** changes. Launch it fullscreen:

```
cd "/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS" && SS_FULLSCREEN=1 SS_LENS_RENDER=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth
```

| # | Look at | Expect |
|---|---|---|
| 1 | Straight Chladni bar at an angle | Continuous, no periodic gaps |
| 2 | After a chord, once a hole has formed | Return pull stays OFF — `[RETURN] hold=1` in the log |
| 3 | Bars vs field brightness | **Still expected wrong** — not fixed, but now explained: §5b |

**The single biggest thing to read is §5b.** "Chladni too dark" and "used to be so goated in tube" are one measured cause, dated to a commit whose own message predicted it.

If a change looks absent: **stale binary first**, and check the path — that command is the WORK tree, not the SHOW tree.

---

## 2. YOUR RULINGS, AND WHAT HAPPENED TO EACH

| Your ruling | State |
|---|---|
| MIDI parser: land the fix | ✅ **DONE, verified on the built binary** |
| Chladni: code floor + show pin | ✅ **BUILT**, awaiting your eyes |
| Return pull must go once the BH is there | ✅ **BUILT** as a formation hold — see §4 |
| Mergers: both classes, one stall | 🔬 Investigated. **Structural cause found** — §5 |
| Tempo = modulation only, never time | ✅ Designed in, enforced structurally |
| MIDI clock now, Link after the show | ✅ Designed in, nothing vendored |
| Controller: both / undecided | ✅ Takeover built-and-bypassed, default JUMP |
| Chladni too dark, field fine | 🔬 Open — measurement running |
| Chladni weird colour | ✅ **MECHANISM FOUND** — §6 |
| Offline rendering: how do we implement it | ✅ **ANSWERED** — §7 |

---

## 3. WHAT I DECIDED WITHOUT YOU (overturn any of these)

1. **HELD the MTC/System Common MIDI fix.** Three more status bytes (`0xF1`, `0xF3`, `0xF6`) still eat notes the same way the clock bytes did. I did not land it: you ruled **MIDI clock** for Cologne, and clock never emits those bytes, so the configuration you chose is fully closed by what shipped. Landing unrequested changes on the stage branch two days out is the risk. **It is written up and ready — one word from you and it goes in.**

2. **Return pull: built option (B), a formation hold.** My first instruction to FABLE was wrong and FABLE refused it with arithmetic — see §4. (B) is your sentence taken literally using the codebase's own two laws.

3. **Authorised one TEMP-DIAG line** (`SS_PHASE_AMOUNT`) so the colour mechanism could be measured tonight instead of waiting for your hand on a slider. Unset ⇒ byte-identical behaviour. Strip it whenever.

4. **Split the Chladni work** so no two windows measured the same screen: colour mechanism → OPUS (code only), brightness + pixely → FABLE (app).

---

## 4. RETURN PULL — YOUR RULING, AND THE TRAP IN IT

Your words: *"Soon ss the bh is there retun pull must go cause bh has its own gravity taking over."*

Today it was a **proportional fade** (`ramp *= 1 - bhStrength`), so at `bhStrength` 0.3 the pull still ran at **70%**. That is the behaviour you ruled against.

**My first instruction was wrong.** I said gate on `lastHorizonR > 0`. FABLE refused to build it and was right: `bhSeedMassMono = gMaxMass` only when `gMaxMass >= 50` (`renderer.mm:3758-3761`), so `lastHorizonR > 0` ⟺ *a ≥50 M☉ body exists* — which is exactly the set the pull acts on (`particles.metal:1471`). That gate would have made the pull **dead code by construction**, and by your own fader law a zero-consumer gets deleted, not shipped.

**Built instead — option (B), the formation hold:**
```cpp
static bool holeSeen = false;
if (impl_->lastHorizonR <= 0.0f)     holeSeen = false;   // the hole un-forms — the ONLY clear
else if (impl_->bhStrength >= 1.0f)  holeSeen = true;    // your 100% law: it is there
if (holeSeen) ramp = 0.0f;
else          ramp *= std::clamp(1.0f - impl_->bhStrength, 0.0f, 1.0f);
```
It has a **real consumer** (the ramp) and is **visible** — `[RETURN]` now prints `r_h=` and `hold=`. The last latch in this codebase (`bhFormedLatch`) had two reads, both `printf`, and gated nothing; that is why your AD.7 question was unanswerable. This one is not that.

⭐ **The more useful finding underneath it:** "the BH is there" means **two different things** to the code and to your eyes.
- The **lens** — what you see as the hole — gates on `lastHorizonR > 0 && bhStrength >= 1.0` (`renderer.mm:2181`).
- The **body/shadow** draw on `lastHorizonR > 0` alone, at a size that is **sub-pixel** for a 5,000 M☉ seed.

Your 0.3–0.7 complaint sits exactly in that gap: the seed survives, so the code says a hole exists; the lens is off, so your eyes say it does not.

**Stacked, n=3, identical shape in all three runs:** hold engages at the first `bhStrength ≥ 1`, pull reads 0.00 for as long as it is held, hold clears **only** at `r_h = 0`, and the pull then ramps back for the next formation.

**Your case has now been reached, and the hold held (1 run, runs 3–4 stacking).** It took a 2-second chord — an 8-second one kills any seed we can grow. In that run: a **1,900 M☉ seed alive**, `r_h > 0`, and `bhStrength` sitting at **0.01** for a 60-second watch. `[RETURN]` showed no hold transition and no ramp change: **hold stayed 1, pull stayed 0.00.**

Under the old proportional fade, that same state would have handed the pull back at **99%**. That is exactly your *"even with bh formed pull inwards remains."*

⚠️ Honest limit: the 2 s chord was chosen so the seed would live. If you don't play short chords, you may never see this regime. The claim is *"(B) holds correctly in the regime where a seed survives play"* — not *"(B) fixes what you saw."*

### 🚨 AND THE SAME RUN EXPOSED SOMETHING BIGGER

**A 1,900 M☉ black hole was alive, with a real horizon — and `bhStrength` read 0.01.**

The lens gates on `lastHorizonR > 0 && bhStrength >= 1.0`. At 0.01, **the lens is off.** So after play, you have a black hole the engine fully believes in and the renderer draws almost nothing for. `[BH-POP]` printed `bhStrength=0.01 LATCH` — the sticky label still saying LATCH while the formation signal reads 1%.

That is the gap in §4 above, now measured rather than argued: the engine's "a hole exists" and your eyes' "I can see the hole" are two different tests, and after play they disagree completely. Your original complaint said 0.3; this build showed 0.01 with a much bigger seed.

**This is probably the real AD.7 finding.** The return-pull hold is a correct fix for a symptom; the formation signal collapsing to 1% while a 1,900 M☉ hole sits there is the thing underneath it. Not touched — it needs your ruling on what "formed" should mean once the hole has been fed by play.

⭐ **Your mutual-exclusion law, observed live with a number on it:** in 3/3 runs, 8 s of play pumped `Mmax` down to **exactly 50** — the floor of the seed class — and the seed population died. Play empties the ≥50 population to its boundary every time.

---

## 5. THE MERGER STAND-OFF — YOUR NAMED PROBLEM

You said: *"problem is that merger stsndoff."* Nobody was on it, so I took it.

### ⭐ There is no seed↔seed merger path in the engine.

`merge_stars` (`particles.metal:3836`):
```c
if (ma <= 0.001f || ma >= M_BH_SEED) continue; // dead / seed / wall
```
Any body **≥50 M☉ is refused at the input**, winner and loser both.

And the other intake refuses them too. The seed-capture victim gate, `particles.metal:1519`:
```c
mass > 0.001f && mass < M_BH_SEED
```
with its own comment: *"Seeds themselves and walls don't get eaten."*

⇒ **A ≥50 M☉ body cannot be consumed by any path in this engine.** There is no third intake. **Two of your mergers sitting on top of each other can never combine — at any separation, at any speed.**

That is the whole of your *"a handful of mergers that outcancel each others further merging"* from 2026-09-02. They cannot merge, by construction, through any channel that exists. It needs no measurement to be true: it is a missing code path, not a tuning problem.

Seeds *are* created here — two sub-50 stars fusing to a ≥50 result, via a direct unmetered mass write at `:3983`. So the engine can **make** a seed and can **feed** a seed, but cannot **merge** two.

### Two theories I killed rather than reported

- ❌ **Return pull braking infall.** `:1508` is `dv = max(0.0f, vIn - vRadIn)` — genuinely one-sided, never brakes. The v5 gain change did not break it.
- ❌ **Merge-gate unit mismatch.** I suspected `vrel2` (uses `1/dt`) and `vesc2` used different time bases, because the comment at `:3907` claims a "×120 convention". `units.h:48-53` settles it: `gmSim` is multiplied by `kTLapse²` *precisely because* the integrator steps in wall seconds, so both sides are (sim/wall-s)². **The comparison is consistent. The comment is stale prose.**

### Refusal is definitively NOT the blocker — and that was already known

`[GRAV] mrg=reached/landed/refused` → **refused = 0 on 27/27 samples** tonight. That is only 9 fusion events, so on its own it proves little — **but it corroborates a much better measurement already on record**: your own play run measured **174/174/0**, and a rest soak **22/22/0**. Nothing has ever been refused, at any denominator.

⇒ **The bound-pair gate is not what is stopping your mergers.** Every numerical theory about that gate — including the units question I chased and closed tonight — is irrelevant. What remains is the missing seed↔seed path above, and supply.

⚠️ **And the runs were measuring the wrong population.** `mrg` counts only fusions *below* 50 M☉ (`merge_stars` refuses ≥50 at the input), while `seeds=` counts only ≥50. They are disjoint — so waiting for the seed count to climb would never populate the merge counter. The regime that matters is a **dense settled sub-50 field**, which is exactly where your stuck ring was measured (board AD.6: `[5.54,30)` M☉, n=7190, 58–110 of them exactly stationary, with `[50,+)` at n=0 in the same run).

Worse for the protocol: since play pumps `Mmax` to exactly 50 every time, **the chord destroys the population the stand-off is about.** The soak runs have to rebuild the field *after* the chord. That correction is in; results pending.

### Already on the board and still the honest answer (AD.8)

The cooling at `particles.metal:2088` is documented as *"dense regions RADIATE orbital energy"* — a **deletion**. Real dynamical friction is a **transfer**. The code deletes energy uniformly and exempts only what already orbits fast enough, so a parked body freezes instead of sinking. And the drag exemption (`:3358-3372`) is **mass-blind** — the gate is `mass > 0.001f`, no mass term anywhere in it — and rewards **only tangential speed**. A stopped body scores 0 and gets full cooling and full friction: **stopped by construction.**

That is consistent with your ruling that both populations are one stall, and it is the thing that would make the cinematic return pull unnecessary.

---

## 5b. ⭐ "TOO DARK" AND "GOATED IN TUBE" ARE ONE THING, AND IT IS DATED

**The bulk field is not rendered dark. It leaves.**

FABLE's captures (5 runs, 26 s chord, show window only):

| | mean luminance | pixels ≥8 | HDR frame avg |
|---|---|---|---|
| Rest | 11.4/255 | 38% | 0.05–0.10 |
| +1 s into chord | — | 3.2% | — |
| +8 s and after | **0.35/255** | **0.2%** | **0.000** |

What is left at +8 s is ~15 bright bodies with thin radial trails. The remaining 5.2% speckle at luminance 1–2 is the postfx output dither (`postfx.metal:557`), uniform in every block — **not matter.**

`[GRAV]`, identical to 2 decimals across all 5 runs: **meanR 11.2 → 27.2 plateau; maxR 60 → 90, still climbing at 26 s.** The 2M particles spread over a shell ~2.5× the rest radius ⇒ **~6× lower projected density.** Surface brightness collapses. The "shapes" you see are the dense parts of outbound streams while they last.

Ruled out by relaunch A/B: `SS_NO_COVERAGE=1`, `SS_NO_DEPTH_PREPASS=1`, camera rho 800 vs 2000, far plane. None changed it.

### It dates to `912e4bf` (2026-08-27 17:21:29, "Kill the tube") — and that commit confesses it

That commit deleted the play-regime cavity — a cylinder r≤6 with flat ends at |z|≤6 — on your verdict *"great the tube is gone."* It measured the cost the same day, n=16 over a 64 s held note:

```
 ~4s  meanR 12.0   ~24s  meanR 41.7   ~44s  meanR 61.5   ~64s  meanR 71.4
```

and wrote, in its own words:

> *"Monotonic, still climbing at the end. There is no converged shape extent. … The field has no shape of its own yet. **The wall was doing the shaping.**"*

Tonight's 27.2 plateau (vs 41.7 at 24 s then) is the 2026-09-02 buffer `5d98b7f` doing half the wall's job — but it is a **speed cap, not a boundary**, so maxR still runs to 90.

**"It used to be so goated in tube" is literal. The tube was the confinement.**

### Your "hardening" hypothesis — checked and ruled out as a changed mechanism

I diffed the hardening path between the tube-era tree and HEAD myself: `ridgePull` lines **identical**, hardness integrator **identical**, producer and all three consumers the same. Nothing about hardening changed.

But you were pointing at the right symptom: **hardening cannot act on matter that leaves at cap speed.** The filament never gets a chance to set. That is the 09-01 cap-churn finding re-observed from a new angle.

### 🚨 THE STAGE NUMBER: THE SHAPE HAS ABOUT TWO SECONDS OF LIFE

`[LUMPROBE]` HDR frame-average, 1 Hz, already in the app. Rest average ≈0.036 in every run. Time from note-on until the frame falls below a fraction of rest brightness:

| run | below 50% | below 10% | below 1% |
|---|---|---|---|
| A (rho 800, default) | 1 s | **2 s** | 3 s |
| no-coverage (rho 800) | 0 s | 1 s | 4 s |
| no-depth-prepass (rho 800) | 1 s | 2 s | 4 s |
| Z (**rho 2000, your max zoom-out**) | 0 s | **0 s** | 3 s |

**At the default camera the figure is above 10% of rest brightness for about two seconds and at the floor by 3–4.** At your maximum zoom-out it is below 10% within the first second — the frame is already inside the expanding shell.

The onset flash (2.6 at the first sample) is the attack. Nothing was tuned to these; they are reported as measured.

**This is a show number, not a physics number.** Two days out, it says a held chord stops being a visible shape long before it stops being a note.

### Related, and it may or may not be what you want: play kills the hole fast

Soak run: a seed grown for 60 s to **2,452 M☉** was pumped back to exactly 50 by an **8-second chord** (2452 → 2037 → 484 → 173 → 50). Your mutual-exclusion law is working — force pumps out of the hole into the shapes — but the rate is worth knowing: **no seed we have grown survives 8 seconds of play, at any mass reached so far.**

### Two honest directions — your call, nothing built

1. **A boundary in play** — the 09-02 buffer made into an actual boundary at the figure's edge, rather than a speed cap.
2. **Accept the shell and make surface brightness follow density honestly.**

The shape of the play domain is your law (sphere only, 2026-08-27), so neither gets built without your word.

---

## 6. THE CHLADNI COLOUR — MECHANISM FOUND

**Yes, Chladni genuinely has a different colour profile, and it is not in the colour law.**

The colour law was ruled out first: `spectrumToBands` runs at `render.metal:1685` (play) **and** `:1918` (star-map) — same function, same LUT, same bit16. It cannot produce a play-vs-field difference.

The cause is the **phase tint**, and the reason is not what we thought:

1. **`phase` is not an oscillation phase.** `particles.metal:3566-3567`:
   ```c
   speed = length(finalV);
   float newPhase = decodePhase(p.velW.w) + speed * dt;
   ```
   It is **wrapped cumulative path length** — ∫|v|dt. **Hue is rotated by distance travelled.** So it is a *speed* gate, not a play-state gate, and it acts on both populations in the same frame — which is why field and Chladni differ while sharing one code path.

2. **The speed split is explicit and warp-independent.** `:3404` mixes `u.speedCap` → `CHLADNI_VCAP_PER_SEC`. 72.7273 / 3.5151 = **20.69×**.
   At dt 0.0165: rest advances ≤0.058 rad/frame (**full wheel ≈108 frames**); Chladni ≤1.20 rad/frame (**full wheel in 5.2 frames**).

3. **Magnitude: ±63° of hue** (`render.metal:2334`, `dh × 0.35`). On by default, consumer chain verified live to the shader.

### Measured, 3/3 — causation settled, and it has a fader

Per-pixel hue change over 0.5 s, rho 2000, 26 s chord, 3 runs per arm:

| arm | hue \|Δ\| per bar pixel (mean) | bar saturation |
|---|---|---|
| **tint 0.35** (current) | 20.9° / 11.3° / 11.2° | 0.55 0.50 0.57 |
| **tint 0** | **2.9° / 3.2° / 3.0°** | 0.62 0.62 0.61 |

**A 4–7× drop, and the bars re-saturate with it.** The phase tint *is* the frame-to-frame colour churn you're seeing. Your 5-second test tomorrow will show you the same thing: **Phase Amount → 0.**

### ⚠️ But "pixely" is NOT the tint

Isolated-pixel fraction and partial-intensity fraction came out **identical between arms** (4.7% vs 4.8–6.6%; 93.4% vs 94.2%). The colour-noise component goes when the tint goes; **the geometric component stays.**

So the 1-px floor is neither exonerated nor convicted. What it definitely did fix is the **gaps** — 99.7–100% of lit pixels now have a lit neighbour, against 68% under sub-pixel rasterisation. Whether "pixely" means the colour noise, the hard 1-px point, or both is **your eyes tomorrow**, with Phase Amount as the discriminator.

❌ **One thing we could not measure:** the predicted 20.69× play/rest phase rate. At rest the probe reads 3.7–12.5° per pixel, but that is *different matter moving under the pixel*, not the phase rate — the probe measures pixels, not particles. The A/B settles **causation**; the rate stays predicted, not measured. Reported rather than dressed up as a ratio.

📋 **New trap, verified twice tonight:** `particles.metal:3397` says the rest cap is "~41x slower". The constants give **20.69×**. 41 only reconciles at dt = 0.00833 (120 fps) — the exact per-frame/per-second mixing the comment three lines above says was **fixed**. `20.69 × (0.0165/0.00833) = 41.0` exactly. The code got corrected; the prose did not. Second stale number found in this file tonight. **Recompute every number in a comment in `particles.metal` before trusting it.**

---

## 7. OFFLINE RENDERING — YOUR QUESTION, ANSWERED

`docs/DESIGN_2026-09-03_OFFLINE_RENDERING.md` (147 lines, uncommitted).

**Buildable before Cologne, touches the RT thread not at all:**
- **Step A** — log MIDI + features at the existing `main.cpp:213` tap.
- **Step B** — replay through the live app in real time.

These stand alone as a **"redo a take"** feature even if everything else is dropped. That is the part you can act on.

**The three things that make the rest post-show:**

1. **It is not one clock, it is at least three.** The physics true-time accumulator (`renderer.mm:1779`), a separate `CVDisplayLink` clock driving sequencer/camera/VJ-crossfade (`window.mm`), and `CACurrentMediaTime()` at six more sites (`bhPoseClock` flagged, not cleared). Decouple physics alone and it desyncs from a still-real-time camera.
2. **Determinism is not bit-exact and probably cannot be made so** without changing merge/seed claim logic — GPU thread-order races, plus the measured 32-of-334,576 per-cell sampling that forked identical inputs 11.1×. **Reframe: an offline segment is its own good take, not a reproduction of a specific live moment.** Costs nothing against "quality never shortcuts", because a take that never needed to reproduce anything loses nothing by not reproducing it.
3. **The output tap already exists.** The dedicated SDR Syphon pass (`renderer.mm:5391-5433`) already renders the full graded, no-UI frame whenever a client is connected. Capture is "force that pass always on, blit to a CPU-readable texture."

⚠️ **Resolution trap — the same one FABLE fought tonight.** `sizeResScale` is tied to live render height, and there is an unused `pinDrawableSize` hook. An offline render at a different height walks straight back into it. Must be coordinated, not solved twice.

---

## 8. MIDI MAPPING — DESIGN IS BUILDABLE

`docs/DESIGN_2026-09-03_MIDI_MAP_AND_LINK.md` (604 lines, uncommitted).

🚨 **The design had a flaw that would have bitten you on stage, and OPUS caught it in its own work.** The plan was to put mapping inside the two slider helpers — all 61 faders route through them. But the entire mod menu sits inside `if (showHUD)` (`main.cpp:1108` → `:2257`), and HIDE ARCHITECT sets it false. **A helper only runs when its widget is drawn — so hiding the UI to perform would have killed every mapping.** Collapse a header, those dials die. Chorus off, its 3 dials die.

Fixed: the helper **registers**, the apply loop runs **outside** the `showHUD` block. Zero call-site edits survives.

**Census (verified):** 63 continuous widgets, 64 mappable values.
- **57** — stable `&app.ui*` pointer. Easy.
- **4** — setter-only (`##MasterVol`, 3 chorus dials). A stored pointer here **dangles**.
- **1** — `main.cpp:1874`, emitter XY: a `SliderFloat2` inside a `for (i < numVoices)` loop with a `snprintf`'d label and a stack temporary. Label, count **and** target vary at runtime.

**One ordering constraint:** apply runs *before* the UI is built, so a slider drawn later the same frame shows what the CC just wrote. Apply after and it lags a frame and reads as broken hardware.

**Tempo:** counting 24 ppqn clocks gives phase with no BPM estimate at all. `phase01` is just another *source* a mapping can name — one enum, no new subsystem. It structurally cannot reach `dt`, substeps or the warp, because the apply loop only ever writes a mapped target. Your 08-28 camera ban stands untouched.

---

## 9. NEEDS YOUR WORD

1. **Land the MTC MIDI fix?** (`0xF1`/`0xF3`/`0xF6` still eat notes; not in your Cologne config; a few lines, same function.)
2. **Startup UI seeding pass — does it read as "moving something"?** A registry that fills *by drawing* cannot hold a widget never drawn. One extra hidden UI build at startup fixes it (~10 lines). **This does not block building anything** — without it, mappings simply arm per panel the first time you open it, i.e. one sweep through the menu at soundcheck. Your call on whether that counts as moving a fader.
3. **Commit order.** Three source changes and two design docs are sitting uncommitted.
4. **Board rows.** Tonight's findings are written up here but **not** added to `BOARD_BLACKHOLE.md` — I did not write board rows unasked. Say the word.

---

## 10. IN THE TREE

| Path | Change | State |
|---|---|---|
| `src/core/midi_input.mm` | +5 — Real-Time guard | Built, **verified live** |
| `src/render/render.metal` | +14 — device-pixel floor | Built, needs your eyes |
| `src/render/renderer.mm` | +34/−6 — return-pull formation hold | Built, verified n=3, soak pending |
| `src/main.cpp` | +11 — **TEMP-DIAG** `SS_PHASE_AMOUNT` | Strip whenever; unset = no change |
| `docs/DESIGN_..._MIDI_MAP_AND_LINK.md` | 604 lines | Untracked |
| `docs/DESIGN_..._OFFLINE_RENDERING.md` | 147 lines | Untracked |
| `docs/BRIEFING_2026-09-03_NIGHT.md` | this file | Untracked |

---

## 11. THE TREE MOVED UNDERNEATH FOUR WINDOWS

Worth your attention because it nearly cost you a good deliverable, and because it will happen again.

Tonight `renderer.mm` gained **+22** net lines (FABLE's return-pull hold at `:1854`) and `main.cpp` gained **+11** (the diag block at `:386-396`) while all four windows were reading and citing those files.

SONNET re-checked its own design doc afterwards, found twelve `totalAmplitude` citations pointing at unrelated lines, and **concluded it had fabricated them.** It had not. Every one was off by exactly +22:

```
2089+22=2111 ✓  2722+22=2744 ✓  2748+22=2770 ✓  2788+22=2810 ✓
2825+22=2847 ✓  2845+22=2867 ✓  2863+22=2885 ✓  2886+22=2908 ✓
2981+22=3003 ✓  3034+22=3056 ✓  3500+22=3522 ✓  5740+22=5762
```

Twelve for twelve under a constant offset is the signature of drift, not invention. It also flagged OPUS's `main.cpp:1552` as the same error — that one moved by exactly +11, and was correct when written. **Both windows were right; the tree moved.** Corrected to both.

A `file:line` is only true against a stated tree state. Both design docs are getting a header naming the state their citations were verified against. The board already carries this warning from the `particles.metal:1461` incident — this is the third time in two days, and the new failure mode is worse than a wrong number: **a careful window concluding its own evidence was invented, and nearly discarding correct work.**

---

## 12. CORRECTIONS I MADE TO MY OWN WORK

Recorded so none of it circulates as fact:

- **My `lastHorizonR > 0` gate for the return pull was wrong.** FABLE disproved it with arithmetic before building. Retracted.
- **I confirmed a "correction" to the 32-of-334,576 figure that was itself wrong.** SONNET read it as a cell count; it is a *particle* count in the densest single cell (`renderer.mm:404`). The original figure is correct. I verified one of SONNET's claims and asserted a second on its authority — the same trap the board logged three times last night. Retracted to SONNET, memory left untouched.
- **Two hypotheses of mine about the stand-off died on inspection** (return-pull braking; merge-gate units). Neither reached you as a finding.

---

## 13. NIGHT CLOSED

**2026-09-03 06:45:59 — all work stopped, app DOWN (0 `SpaceSynth` processes), build token idle.**

Bundle stamped **06:08:22**, newer than all four sources (latest 06:07:51) — **not stale**, it carries every change below.

| Path | Change | Verified |
|---|---|---|
| `src/core/midi_input.mm` | +5 Real-Time guard | ✅ live on the binary |
| `src/render/render.metal` | +14 device-pixel floor | built — your eyes |
| `src/render/renderer.mm` | +28/−6 return-pull hold (B) | ✅ 3/3 latch + 3/3 soak |
| `src/main.cpp` | +11 TEMP-DIAG `SS_PHASE_AMOUNT` | built |

**4 files, 58 insertions, 6 deletions. Separable by file. Nothing committed — no commit order given. 19 commits still unpushed, no push order given.**

Measurement runs tonight: 3 latch, 4 soak, 9 capture arms, all with the app closed between runs.

