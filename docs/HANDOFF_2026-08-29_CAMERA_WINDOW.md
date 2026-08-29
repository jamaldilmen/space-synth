# HANDOFF — THE CAMERA WINDOW, 2026-08-29 02:08:33

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-POST-TUBE` @ `post-tube`
**This window's lane:** the CAMERA. Not the substrate, not BH physics, not BH optics.
**Build token:** NOT held here. The BH window has it. ⛔ **One tree now — writing a file in `src/`
IS staging someone else's build.** That is the rule this session learned the hard way (§5).

---

## 1. WHAT SHIPPED AND HAS HIS VERDICT ✅

**The camera is no longer impulse-driven. Input writes a TARGET; a second-order spring chases it.**

| | |
|---|---|
| **Files** | `src/core/camera.h` (rewritten, 248 → 345 lines), `src/main.cpp` (3 call sites + one key handler) |
| **His verdict** | *"i love the feel the snappiness"* · *"tap is fine"* |
| **Built & live** | bundle 13:24:51 vs sources 13:23:55, launched fullscreen, pid 17236 @ 13:25:09 |

**What he can press:**
- **`c`** — cinematic mode. Logs `[CINE] cinematic camera ON/OFF`. 4.36× slower, zero overshoot.
- **arrow tap** — one exact 45° step. **8 taps = a full revolution**, both axes. His order.
- **arrow hold / shift+arrow** — unchanged. They move the OBJECT, not the camera (see §2).

**The law:** `a + 2ζω·v + ω²x = 0`, Ryan Juckett closed form, exact for any dt.
- `ω = 5.83 / T_settle`; `kSettleNormal = 0.50 s`, `kSettleCine = 1.50 s`
- `kZetaOrbit = 0.70` (the ~5% overshoot IS the "snappiness" he praised — **do not raise it**),
  `kZetaZoom = 1.00`
- ⛔ **NO BPM, NO BEAT, NO ABLETON LINK.** An earlier draft derived ω from tempo. **He rejected it:**
  *"we dont want a bpm sync its not needed for now u got that wrong."* Do not reintroduce it through
  the "Link so params are BPM-syncable" line in [[space_synth_camera_overhaul_2026-08-10]].

**Deleted with the rewrite, all previously zero-caller:** `driveSpin`, `armSnap`, `setAngles`,
`softLockToQuarter`, `snapNextSettle`, `TAP_STEP`.

**Reproduce the verification with no build and no token:**
```
clang++ -std=c++17 -O2 -Wall -Wextra -I src <harness>.cpp -o /tmp/cam && /tmp/cam
```
7 checks: ease-in (frame 0 is 19.4% of peak, peak at frame 5) · exact landing (err 0) ·
frame-rate independence across 18.7–120.2 fps (spread 0.0001°) · cinematic 4.36× with zero
overshoot · wrap safety over 12.7 revolutions · zoom rails · zero drift at rest.
Plus: 8 taps = 360.0000° / 359.9997°, default `theta` exactly on the grid, and the view basis
orthonormal and finite at **both** poles (θ = 0 and θ = π).

---

## 2. ⭐ THE STRUCTURAL FACT THE NEXT WINDOW MUST KNOW

**THERE ARE THREE INDEPENDENT MOTION SYSTEMS. THE CAMERA IS ONLY ONE OF THEM.**

| # | what | site | still impulse-driven? |
|---|---|---|---|
| 1 | camera orbit / tilt / zoom | `camera.h` | ❌ **fixed** — spring |
| 2 | **body spin (arrow HOLD)** | `main.cpp:780-826` | ✅ still `accel·dt` + `max(0, 1 − dt·rate)` |
| 3 | **time warp (shift+arrow)** | `main.cpp:392` | ✅ still `timeWarp *= 1.3`, a discrete jump |

**Arrow-HOLD does not move the camera. It rotates the scene under a stationary camera.**
Anyone reasoning about "camera feel" from `camera.h` alone is reading the wrong file for most of
what he does with the arrow keys.

⛔ **CINEMATIC MODE DELIBERATELY DOES NOT TOUCH 2 OR 3.** His ruling: *"at warp we spin the object
not the camera u know so the question doesnt make sens."* Do not couple them. Do not re-raise it.

---

## 3. PARKED, AWAITING HIS ONE ANSWER 🅿️

**Rides.** Design is complete in `docs/CAMERA_STEP2_DESIGN.md` §9. His ask: *"multiple points would
be cool and also back and forth like bounce back to start once destiantion ahs been reched"*

**The one open question — he has NOT ruled:**
> at each waypoint, **hold ~0.4 s and depart** (passes exactly through every framing he chose), or
> **advance the target early** (continuous motion, but rounds the corners and travels NEAR the
> points, not through them)?

**Recommendation: hold.** A cinema camera resting on a composition is a shot, not a stall.

**Three things from that design worth not re-deriving:**
1. **The ride is a target scheduler and nothing else** — a list, an index, a direction, one line
   writing the target. **The bounce falls out of one sign flip. No splines, no path code.**
2. ⭐ **A linear spring settles in the same time regardless of distance**, so equal-ω legs make a
   long leg race and a short leg crawl. Fix is arithmetic: `ω_leg = 5.83 / (T_base · d_leg/d_ref)`.
   **That is the arc-length problem solved without any spline machinery.**
3. ⚠️ **Setting a target must take the short way round:** `tgtPhi = phi + wrapPi(wpPhi − phi)`.
   `coWrap` protects an in-flight error; this is the separate case of choosing the representation at
   the moment the target is set. **Both are needed and they are not the same fix.**

---

## 4. THE BH REFERENCE STUDY 📚

`docs/blackhole-library/04_HOW_THE_REFERENCES_DO_IT.md` — his order: *"how does nasa do it? how did
ineterstellar do it? dont guess research our references."* Read from the DNGR paper itself
(**there is a full extracted text at `/Users/airy/GARGANTY/1502.03808_text.txt`** — use it, not the
2 MB PDF) and from his own Kerr raytracer note.

**The five findings, so they are not re-derived:**
1. **R5, R6 and R2 are ONE mechanism, not three features** — the n=0/n=1/n≥1 images of the same
   disk, indexed by winding number. Build the integrator and all three appear, or none do.
2. **The "polar caustic" reason for rejecting the raytracer is not a correct sentence.** That defect
   was **Kerr + an infinitely-thin analytic disk + one unfiltered ray per pixel**. Our emitters are
   particles with finite extent. ⛔ **FPS is an independent and sufficient reason and his rejection
   stands** — but do not carry the wrong reason forward, it will block the right architecture.
3. **On disk STRUCTURE, NASA is our reference and Interstellar is not.** NASA renders knots forming
   and shearing into lanes; Interstellar's disk is a static artist texture at uniform 4500 K.
   **Ours is real particles with real shear** — the one axis where our architecture is an advantage.
4. **The EHT ring is NOT the photon ring** — it is lensed near-horizon emission shaped into a
   crescent near it. Our own `BH_REFERENCE.md` R2 labels the theorist's object. **n = 1 is reachable
   at 4K; n = 2 needs ~535× finer and never will be. Say "n = 1 only" out loud.**
5. 🚨 **THREE DIFFERENT SPINS IN ONE RENDERER** — kinematics **a = 0.5** (`render.metal:308`
   `KERR_A`, used at `:1409`), geometry **a = 0** (`:991` hardcodes `2.5980762` = 3√3/2, the
   Schwarzschild capture value), target **a = 0.999** (Gargantua). **Nobody should read the shadow
   as evidence about spin, or Doppler asymmetry as evidence about geometry, while the two disagree.**

**The sentence that should change what we do next (A8):** *neither DNGR nor NASA ever shipped one
unfiltered ray per pixel.* DNGR spent ray bundles on it; NASA spent 500 billion photons. **We never
have.** And the genuinely open problem: **every reference terminates rays on an ANALYTIC surface.
Nobody has solved ray-vs-particle-cloud, because nobody else had the particles.**

---

## 5. ⚠️ THE PROCESS LESSON — the most expensive thing this session learned

**2026-08-28 13:14 I wrote `camera.h`. 13:15:23 the BH window built. 13:15:37 the app launched.
My untested rewrite went in front of him inside a build made to test something else.**

Proof at the time: `strings SpaceSynth.app/Contents/MacOS/SpaceSynth | grep "cinematic camera"`.

**THE RULE, adopted by all three windows: the token holder owns the WHOLE TREE, not just their own
files. No window writes source while someone else holds the token — draft to `docs/` or scratchpad
and apply on handover.** Since the tree collapse, writing a file IS staging a build.

🚨 **And `SpaceSynth.app/Contents/MacOS/SpaceSynth` is TRACKED.** It is built from the whole tree,
so committing it alongside one source file silently ships everyone else's dirty work inside the
executable, invisible as `Bin … → … bytes`. Same treatment as `imgui.ini`: **leave it out until the
source is settled, then build once and commit it deliberately.**

---

## 6. TRAPS THIS SESSION HIT, WITH THE GENERAL FORM

- 🧪 **A TEST THAT ASSERTS A CONSTANT IT SHOULD BE MEASURING.** My 7-check harness went red when the
  tap grid changed 90° → 45° — the harness had hardcoded 90. **Same trap as a comment asserting a
  mechanism.** It now derives the grid from the code under test.
- 📏 **A MEASUREMENT AT ONE FRAME RATE IS NOT A CONSTANT.** "One tap = 30.94°" was banked as a fact.
  Measured across the range: **7.28° / 13.75° / 30.94° / 48.13° / 65.43°** at 18.7 / 30 / 60 / 90 /
  120.2 fps. **A 9× spread — and he switches the display 60↔120 mid-session.** State the fps or do
  not bank the number.
- 🎯 **TRAVEL IS NOT LANDING.** "3 taps = exactly 90.00°" was never a property of `TAP_STEP`: three
  taps *travelled* 92.82° at 60 fps and the detent hard-assigned the rest. At 120 Hz they reach
  196.30°. **The trick only ever worked at one frame rate.**
- 🔍 **GREP FOR THE CONCEPT, NOT FOR THE NAME YOU GUESSED.** I searched `spinA|kerrA|bhSpin` and
  concluded "no Kerr spin exists". It is called `KERR_A`. **The miss inverted a finding.**
- 💬 **9th and 10th comment-is-not-a-mechanism sightings.** Pre-fix `main.cpp` carried two
  *contradictory* comments about tap behaviour (`:415` vs `:783`). And `render.metal:994` still says
  *"With the lens on, the lens + membrane are the ONLY transport"* — the lens was deleted 2026-08-27
  and the straight-line cull below it is now the live path.
- 🗣️ **RELAY THE QUESTION, NOT YOUR WORDING OF IT.** The BPM idea was raised here as an open
  question with a derivation attached, relayed twice as a proposal, and rejected on the framing.
  **Quote the question.**

---

## 7. STATE AT HANDOFF

- ✅ Camera shipped, built, live, and has his verdict. ζ stays 0.70.
- 🅿️ Rides parked on one unanswered question (§3).
- 📚 BH reference study written and corrected (§4). **Reference study only — the BH physics and
  optics are NOT this window's lane.**
- ⛔ No build token here. `src/` untouched since the BH window took it.
- 📄 Docs owned by this window: `docs/CAMERA_STEP2_DESIGN.md` (§9 = rides, §10 = the tap table),
  `docs/blackhole-library/04_HOW_THE_REFERENCES_DO_IT.md`, this file.
- 🗄️ `/Users/airy/SPACE SYNTH/CAMERA_OVERHAUL_2026-08-10_uncommitted.patch` — **step 1 only, DO NOT
  APPLY.** Its `sizeof(CameraUniforms)` assert says 272; live is 288. Two of its hunks patch deleted
  code.

**Last Updated:** 2026-08-29 02:08:33
