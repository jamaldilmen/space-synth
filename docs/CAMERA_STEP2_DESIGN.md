# CAMERA STEP 2 — TARGET/ACTUAL SPLIT + CINEMATIC MODE
**Written:** 2026-08-27 21:14:52
**Lane:** CAMERA window
**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-POST-TUBE` @ `post-tube` (ONE TREE since 2026-08-27 21:30 on his order *"collapse to one tree . commit"*; SPACE-SYNTH-RESONATOR removed, all six of its commits verified as ancestors of the live branch)
**Status:** DESIGN ONLY. Zero lines written. No build token. Awaiting Jamal's verdict.
**Revised:** 2026-08-28 12:56:33 — ⛔ BEAT-SYNC STRUCK on his ruling (§4.2), and automated A-to-B rides promoted from deferred to the second half of the brief (§4.5). Previously revised 22:26:14 for the POST-TUBE rename (dir + branch; same worktree, same HEAD 9751d9a). Previously revised 21:39:11 after reading the saved 2026-08-10 camera patch (§8) and re-verifying every line reference against the collapsed tree.

---

## 0. WHAT IS ALREADY TRUE (verified 2026-08-27, not assumed)

- Step 1 of the 2026-08-10 sequence is **DONE AND COMMITTED**. `viewForward` ships:
  `camera.h:198 getForward()` -> `main.cpp:2291` -> `renderer.mm:1643-1645`, consumed at
  TWO surviving shader consumers in the collapsed tree — `render.metal:1221` (ortho depth for
  PSF size falloff) and `:2388` (dust absorption direction). Layout-guarded by
  `__builtin_offsetof(CameraUniforms, viewForwardZ) == 268` plus `sizeof(CameraUniforms) == 288`
  in BOTH `renderer.h` and `render.metal`. Zero surviving `normalize(-cam.cameraPos.xyz)`.
  ⚠️ It had FOUR consumers before 2026-08-27; the other two (`dHat` front/behind, `viewDir`
  `behindBH`) died with the lens and the march. See §8.
- The arrow-key detent was **NEVER BROKEN**. `3dc3be2` ("Keys: a TAP no longer leaks spin
  into the body") states it: the camera snapped correctly the whole time, the BODY had
  turned under it. That commit is NOT in this tree (see §5).
- Perspective FOV is still hardcoded `45.0f` at `main.cpp:842`.

---

## 1. THE ROOT DEFECT, RESTATED WITHOUT THE CLOSED BUG

`camera.h` has **no goal state**. Every entry point writes a VELOCITY:

| entry point | line | writes | callers |
|---|---|---|---|
| `rotate(dPhi,dTheta)` | :80 | `velPhi += `, `velTheta += ` | `main.cpp:192` (mouse drag) |
| `rotateKey(dPhi,dTheta)` | :89 | same + arms snap | `main.cpp:423-426` (arrow TAP) |
| `zoom(dRho)` | :95 | `velRho -= ` | `main.cpp:197` (scroll) |
| `driveSpin(vPhi,vTheta)` | :101 | sets velocity | **ZERO** |
| `armSnap()` | :107 | sets flag | **ZERO** |
| `setAngles(phi,theta)` | :111 | sets angle | **ZERO** |

`update(dt)` at :36-45 then bleeds those velocities off:
```cpp
float friction = std::max(0.0f, 1.0f - dt * 6.0f);
```

An impulse is instantaneous acceleration. **Ease-IN is unobtainable at any setting**, because
the motion is already at peak speed on frame one. Everything decays from maximum. That is the
whole reason nothing reads as cinematic, and it needs no help from any bug.

Second defect in the same line: `1 - dt*6` only approximates `e^(-6·dt)`, and they diverge as
`dt` grows. Measured fps on this project spans **18.7 to 120.2**. The camera feel therefore
changes with particle load, which is the opposite of an operator's hand.

---

## 2. ⭐ THE FINDING THAT CHANGES THE SHAPE OF CINEMATIC MODE

**Arrow-HOLD does not move the camera at all. It spins the BODY.**

`main.cpp:780-826` is a SECOND, INDEPENDENT impulse-and-friction system:
```cpp
if (spinHold >= kTapHoldSec) {                          // :797, added by 3dc3be2
  float accel = 8.0f + spinHold * spinHold * 25.0f;     // :798, ramp UNCHANGED by the fix
  spinVelY += dirY * accel * dt;                        // impulse
}
float spinDrag = std::max(0.0f, 1.0f - dt * dragRate);  // :809, same broken form as camera.h:38
```
The keys fix added only the `kTapHoldSec` gate. The ramp and the drag are untouched, so this
system is still impulse-driven with the same frame-rate-dependent discretisation.
It accumulates `spinAngle*` and applies a RIGID rotation in the render (`renderer.setSpin(0,0)`
keeps physics spin-free, :812). So what reads on screen as "turning the view" is the scene
rotating under a stationary camera.

And time warp is a **THIRD** system, with no smoothing whatsoever:
```cpp
timeWarp *= (e.keyCode == 124) ? 1.3f : (1.0f / 1.3f);   // main.cpp:392, discrete jump
```

His brief names all three: *"zoom and tilts and time warp become super slowed down."*

> **A cinematic mode that only slows the camera is a fader that does one thing.** Under
> FADERS ARE UNIVERSAL LAW it has to reach the orbit, the zoom, the body spin AND the time
> warp, or it is tuning, not a fader.

---

## 3. HOW REAL SYSTEMS DO IT (the answer to "how do cameras in sims like that work?")

**DJI cine mode is not a second camera.** It changes the responsiveness of the one control law:
acceleration, braking and rotation all slowed; brake sensitivity reduced so the aircraft
*drifts* to a stop instead of stopping. One mode, one law, every axis.
=> Cinematic mode should be ONE SCALAR into an existing law, not a separate code path.

**Cinemachine (Unity)** separates *where the camera is* from *what it looks at*, and every Body
component exposes DAMPING per axis. Zero damping means the camera teleports to the target every
frame and mirrors micro-movement as visible shake. The damping IS the camera feel.
=> Confirms the target/actual inversion is the industry-standard shape, not an invention.

**NASA Goddard (Schnittman & Powell, 2024-05-06)** is the most useful reference and the least
like an animation package. Numbers:
- start **400 million miles (640 Mkm)** out, black hole **4.3 million M_sun**, horizon
  **16 million miles (25 Mkm)** across
- the fall to the horizon takes **~3 hours**, during which the camera completes
  **almost two full 30-minute orbits**
- shot A: near-miss, loops the hole and slingshots back out, **6-hour round trip**, the
  traveller returns **36 minutes younger**
- shot B: straight in on the most direct path; **12.8 seconds** from horizon to
  spaghettification, **79,500 miles (128,000 km)** to the singularity
- 10 TB of data, 5 days on 0.3% of Discover's 129,000 processors

**The shot-design lesson is one sentence: the camera is not keyframed, it is RELEASED.**
It is a test particle on a geodesic. That is where the smoothness comes from. A physical body
under a force law has ease-in and ease-out for free, and it can never produce a jerk, because
acceleration is bounded by the field. NASA got a cinematic ride by not animating one.

---

## 4. THE DESIGN

### 4.1 Invert the class: input writes a TARGET, the camera chases it

```
tgtPhi, tgtTheta, tgtRho        <- what input writes
phi, theta, rho                 <- what the renderer reads
velPhi, velTheta, velRho        <- internal, no longer written from outside
```

Every entry point becomes `tgt* += delta` (or `=` for `setAngles`). Nothing outside the class
touches a velocity again.

### 4.2 Chase with the second-order closed form (already banked 2026-08-10)

`a + 2ζω·v + ω²x = 0`, Ryan Juckett's exact solution, four coefficients precomputed per
(ζ, ω, dt). Same math as Unity SmoothDamp / Game Programming Gems 4.

**It solves the ODE analytically, so frame-rate independence is FREE** and defect #2 above
(the `1 - dt*6` approximation) dies with it. That matters here specifically because our fps
range is 18.7-120.2.

- **ζ** = 1.0 for zoom (an overshooting zoom reads as a mistake); ~0.7 for orbit (the ~5%
  overshoot is what reads as an operator rather than a script).
- **ω** = `5.83 / T_settle`, where 5.83 is the critically-damped 2% settle constant (ωt ≈ 5.83)
  and `T_settle` is **a plain number in seconds that he tunes**. First value: T_settle = 0.5 s
  -> ω = 11.7 rad/s. One dial, one unit, and the unit is the one he can actually feel — "how
  long until the camera has arrived."

⛔ **NO BPM. NO BEAT. NO ABLETON LINK. NO TEMPO TERM ANYWHERE IN THE CAMERA.**
His ruling 2026-08-28: *"we dont want a bpm sync its not needed for now u got that wrong. its
just about smoothness in camer amotion. automated camera rdies from point a to b."*
An earlier draft sourced ω from the beat (5.83/T_beat = 12.4 rad/s at 128 BPM). **Struck.**
Only the SOURCE of ω changed — a number instead of a tempo. The second-order form, the closed
solution and the frame-rate independence are all untouched, and the design got smaller.
⚠️ The 2026-08-10 memory mentions Ableton Link "so params are BPM-syncable as in Resolume."
That is about PARAMS in general and it is NOT this lane. Do not reintroduce tempo through that
door.

### 4.3 Cinematic mode = ONE scalar, applied to all four

```
kCine  (1.0 = normal, ~0.25 = cinematic)
```
- orbit / tilt: `ω *= kCine`, `ζ -> lerp(ζ, 1.0, 1-kCine)`  (slower AND less overshoot)
- zoom:         `ω *= kCine`
- body spin:    `accel *= kCine`, and the ramp `8 + spinHold²·25` stretches by `1/kCine`
- time warp:    step ratio `1.3` -> `1 + (0.3 · kCine)`, i.e. 1.075 at kCine=0.25, and the
                jump itself gets sprung so it GLIDES between values instead of snapping

One number, four systems, active in every state. That satisfies FADERS ARE UNIVERSAL LAW by
construction rather than by inspection.

### 4.4 Deletions in the same change

`driveSpin()` :101, `armSnap()` :107, `setAngles()` :111 — zero callers each, grep-verified
across all of `src/`. `driveSpin`'s comment cites "light-trail territory"; the ribbon pass was
deleted 2026-08-20. Capability with no consumer gets removed, not carried across.

### 4.5 ⭐ AUTOMATED A-TO-B RIDES — PROMOTED, AND THE FIRST VERSION IS FREE

**His brief is exactly two things, in his words 2026-08-28:**
> (a) *"smoothness in camera motion"*  (b) *"automated camera rides from point a to b"*

(b) was scoped here as steps 5-6 and deferred. He has now named it as the POINT of the work,
so it is not distant. It still cannot land before (a) — you cannot drive a camera along a path
while input writes velocity into the camera body.

**But the useful half of (b) falls out of (a) for nothing.** Once input writes a TARGET and a
second-order spring chases it, a ride from A to B is:

```
tgtPhi/tgtTheta/tgtRho = B      // and let the spring run
```

The camera departs from rest, accelerates, decelerates and arrives at rest, with real ease-in
AND ease-out, frame-rate independent, at a duration set by T_settle. That IS a smooth automated
A-to-B ride. It needs no spline, no arc-length reparameterisation and no path code at all.

Spline machinery is only required for a ride through MULTIPLE waypoints where speed must stay
even across segments (the naive `t` gives uneven speed and reads as broken). That is real work,
and it is the honest second half.

**Recommendation, his call:** design covers both halves; the BUILD stays sequential.
1. (a) target/actual split + spring + kCine. A-to-B between two points works the day this lands.
2. His verdict on how it FEELS, with real ease-in in his hands, before anything else is written.
3. (b) multi-waypoint paths with arc-length parameterisation, only if he wants rides that
   pass THROUGH points rather than travel BETWEEN them.

Designing (a) without (b) in view risks building the wrong (a). Building them together breaks
ONE CHANGE AT A TIME and makes a regression unattributable.

⛔ **Rides will be designed on the FIELD, not on BH optics.** As of 2026-08-27 both BH
renderers are deleted (lens ~320 lines, geodesic march ~410 lines, 852 deletions). There is no
photon ring, no far-side arch, no underside arc to fly around.

---

## 5. ✅ PRECONDITION SOLVED BY THE TREE COLLAPSE (2026-08-27 21:30)

Previously: this lane's branch lacked `3dc3be2` (the keys fix), so a build from it would have
shipped a binary where a tap leaks spin into the body again.

**Closed.** In the live tree `git merge-base --is-ancestor 3dc3be2 HEAD` returns TRUE, verified
2026-08-27 21:33. All six of the old branch's commits are ancestors of the live branch, verified
individually. No cherry-pick was needed. A build from the live tree ships the keys fix.

---

## 6. VERIFICATION PLAN (how we know it landed)

1. **Ease-in is the whole point, so measure it.** Log `phi` per frame across a single tap.
   Pre-change the first frame carries peak angular speed. Post-change frame one is ~zero and
   speed peaks mid-move. That is a number, not an opinion.
2. **Frame-rate independence:** drive the same input at 120 fps and at ~20 fps (load the
   field). Total angle travelled must match within a couple of percent. Today it will not.
3. **kCine reaches all four:** with kCine at 0.25, confirm orbit, zoom, body spin and time
   warp all slow. A fader that misses one is the bug this rule exists to catch.
4. Stack 4+ runs before any stability claim.

---

## 7. SOURCES

- NASA Goddard / SVS, "New NASA Black Hole Visualization Takes Viewers Beyond the Brink",
  2024-05-06 — https://science.nasa.gov/universe/black-holes/supermassive-black-holes/new-nasa-black-hole-visualization-takes-viewers-beyond-the-brink/
- NASA SVS, "Plunge: Behind the Scenes" — https://svs.gsfc.nasa.gov/14818
- Unity Cinemachine Transposer docs (damping model) — https://docs.unity3d.com/Packages/com.unity.cinemachine@2.4/manual/CinemachineBodyTransposer.html
- DJI Cine mode behaviour — https://www.droneblog.com/dji-cine-mode/


---

## 8. THE SAVED 2026-08-10 PATCH — READ, AND IT DOES NOT CHANGE THE DESIGN

`/Users/airy/SPACE SYNTH/CAMERA_OVERHAUL_2026-08-10_uncommitted.patch` (13,129 B, 143
insertions across 5 files), rescued from the `SPACE-SYNTH-TUBE-camera` worktree before removal.

**Verdict: it is step 1 and ONLY step 1. Zero step-2 content. Do not apply it.**

Every hunk is the `viewForward` plumbing that later shipped: `getForward()`,
`RenderConfig::cameraForward[3]`, the three `viewForward*` scalars appended to both copies of
`CameraUniforms`, the layout guards, and the `renderer.mm` assignment. It is not a rejected
attempt at the target/actual split — there is no target, no spring, no damping, no cinematic
mode anywhere in it. It contains no goal state of any kind.

**Do not apply it. It is stale in three specific ways** (all verified in the live tree
2026-08-27 21:38):

1. **Its `sizeof` assert says 272. The live struct is 288.** Applying it would fail the guard
   it installed. `CameraUniforms` grew after the patch was written.
2. **Its two shader hunks target code that no longer exists.** The patch substitutes
   `viewForward` into `dHat` (the lens front/behind test) and `viewDir` (the `behindBH`
   occlusion). Both died with the lens (~320 lines) and the geodesic march (~410 lines) on
   2026-08-27.
3. **Its `renderer.mm` dead-overload hunk has no home.** It sets `viewForwardY = -1.0f` inside
   `Renderer::render(config)`, which was DELETED 2026-08-11 04:11:00 (`renderer.mm:1518` is now
   the tombstone). Zero hits for that line in the live tree.

⭐ **THE USEFUL THING THAT FELL OUT OF READING IT.** F5's original justification was BH optics,
and that justification is now gone — but `viewForward` SURVIVED the deletion, and its two live
consumers are not BH optics at all:

| site | what it does |
|---|---|
| `render.metal:1221` | ortho depth for the PSF size falloff (F6) |
| `render.metal:2388` | direction for the per-cell dust absorption |

So the F5 plumbing is load-bearing **for the field**, not for the hole. That is good news for
this lane and it is worth stating plainly: when step 2 points the camera somewhere other than
the origin, both surviving consumers become correct immediately, and there is no lens or march
code left that could silently break behind them. The trap F5 was written to prevent has been
deleted out from under it, and the plumbing kept its value anyway.

⚠️ **If step 2 adds a field to `CameraUniforms`** (a target, an FOV, a roll), it is APPEND-ONLY
at the end of BOTH copies, and the `sizeof` number changes in BOTH files. That struct has real
guards — `sizeof == 288` plus three offset anchors at 108 / 200 / 268, mirrored in
`renderer.h` and `render.metal`. Unlike `PhysicsUniforms`, which has none.

---

## 9. AUTOMATED RIDES — WAYPOINTS + BOUNCE (design, 2026-08-28 13:34:02)

**His ask, verbatim:** *"i think multiple points would be cool and also back and forth like
bounce back to start once destiantion ahs been reched"*

⛔ **DESIGN ONLY. Not written. No source in `src/` for this.** The `c`-key smoothness change
(§4) is finished and is the precondition; this sits on top of it and gets its own build and its
own verdict.

### 9.1 The ride is a TARGET SCHEDULER. That is the whole thing.

Because input now writes a target and a spring chases it, a ride does not need a camera at all.
It needs a list, an index, a direction, and one line that writes the target. The motion, the
ease-in, the ease-out and the frame-rate independence are already solved by §4 and are not
re-solved here.

```
waypoints[]   (phi, theta, rho)   — the same triple the camera already is
idx           which one we are heading for
dir           +1 outbound, -1 on the way back
```
Per frame, while riding: `target = waypoints[idx]`. On arrival: advance `idx` by `dir`; at
either end, flip `dir`. That is the bounce — it falls out of one sign.

**No splines. No arc-length reparameterisation. No path code.** The spline machinery scoped in
the 2026-08-10 sequence as steps 5–6 was only ever needed because the camera could not be
told where to go.

### 9.2 ⭐ EVERY LEG TAKES THE SAME TIME — and that is a decision, not a bug

A linear second-order system settles in `t = 5.83/ω` **regardless of how far it travels**. So a
2° leg and a 170° leg take exactly the same wall-clock time. That means:

- **Equal-time legs** (ω fixed): a long leg moves fast, a short leg crawls. Reads as uneven.
- **Even-speed legs** (ω per leg): derive it — `T_leg = T_base · (d_leg / d_ref)`, then
  `ω_leg = 5.83 / T_leg`. Long legs take proportionally longer and the apparent speed is
  constant across the whole ride.

`d_leg` is the angular distance of the leg, with rho folded in at some scale. **This is the
arc-length problem, solved by arithmetic instead of by splines**, because we are chaining
straight legs rather than sampling a curve.

**Recommendation: even-speed, ω derived per leg.** Uneven speed is the specific thing that
makes an automated move read as broken.

### 9.3 The corner: arrive at rest, or carry speed through?

At a waypoint the spring's velocity goes to zero. Chained naively, a multi-point ride therefore
**stops at every waypoint**. Two honest options:

| | behaviour | cost |
|---|---|---|
| **(a) Arrive, dwell, depart** | passes EXACTLY through every point, brief hold at each | the motion stops at each corner |
| **(b) Advance the target early** | continuous motion, never stops | rounds the corners — travels NEAR the points, not through them |

**Recommendation: (a), with `dwell` as a dial (first value 0.4 s).** A cinema camera holding on
a composition is a shot, not a stall — and this is for a live show where each waypoint is a
framing he chose. (b) stays available later as a lookahead and needs no new machinery: advance
`idx` when the error drops below a threshold instead of when it reaches zero.

### 9.4 Authoring: he flies it, he does not type it

The cheapest and most useful capture is a key that **records the camera's current position as
the next waypoint**. He flies somewhere he likes, presses it, that is a point. Repeat. Then one
key to run and stop the ride.

No UI work, no coordinate entry, and the waypoints are by construction reachable framings he
picked with his own hands. Suggested keys, all verified free in the same way `c` was:
- record current position as a waypoint
- clear the list
- run / stop the ride

⚠️ **ANY manual input during a ride CANCELS it** — mouse drag, arrow tap, scroll. Non-negotiable
for a live show: touching the controls must take back the camera instantly, with no mode to
exit first. Cheap to implement: the same three entry points that write the target also clear
the riding flag.

### 9.5 The one real trap: angular wrap when SETTING a target

A waypoint stored at +170° with the camera at −170° is **20° away, not 340°**. Setting the
target naively sends the camera the long way round the entire field.

```
tgtPhi = phi + wrapPi(waypointPhi - phi);     // always the short way
```
Same for theta. `§4`'s `coWrap` keeps an in-flight error intact; this is the separate case of
choosing the representation at the moment the target is set. Both are needed and they are not
the same fix.

### 9.6 Interaction with cinematic mode

The ride uses the same ω as everything else, so **pressing `c` slows the rides too** — one law,
one dial, exactly as §4.3 intends. Nothing extra to build, and nothing to keep in sync.

### 9.7 Verification plan

1. **Bounce is exact:** run a 3-point ride for several cycles, log the camera state at each
   arrival. Point 1 on cycle 5 must equal point 1 on cycle 1 to float precision. A drifting
   ride is the classic failure and it is trivially detectable.
2. **Even speed:** log angular speed per frame across legs of very different lengths. With ω
   derived per leg the plateau speeds must match within a few percent; with fixed ω they will
   differ by the length ratio, which is the thing being avoided.
3. **Cancel is instant:** touch the mouse mid-leg and confirm the ride flag clears in the same
   frame and the camera does not snap.
4. **Short way round:** place waypoints at +170° and −170° and confirm the traverse is 20°.
5. Stack 4+ runs before any claim.

---

## 10. ⚠️ WHAT CHANGED UNDER HIS FINGERS — MEASURED, 2026-08-28 13:44:19

He said this morning *"arrows are working fine."* §4 changed what a tap does, so this is the
one thing that most needs to reach him accurately. I measured the OLD camera directly by
compiling the pre-change `camera.h` and running one tap to settle at each frame rate:

| frame rate | OLD travel per tap | NEW travel per tap |
|---|---|---|
| 18.7 fps | **7.28°** | 90.00° |
| 30 fps | 13.75° | 90.00° |
| 60 fps | **30.94°** | 90.00° |
| 90 fps | 48.13° | 90.00° |
| 120.2 fps | **65.43°** | 90.00° |

The 30.94° at 60 fps reproduces the BH window's independent 2026-08-27 measurement exactly,
which validates the model.

**The headline is not "3× bigger". It is that the old tap had a 9× SPREAD and the new one has
none.** One tap used to travel anywhere from 7° to 65° depending on how loaded the field was —
and he switches the display between 60 Hz and 120 Hz mid-session, so his own tap distance was
doubling when he changed screens.

That also explains the detent that was never quite right: at 60 fps three taps came to 92.8°,
close enough for the magnetic snap to grab. At 120 Hz three taps came to 196° — nowhere near a
quadrant. **The "3 taps = one quadrant" trick only ever worked at exactly one frame rate.**

Honest statement of what is and is not verified:
- ✅ **Numerically verified**: ease-in, exact landing, frame-rate independence, zero-overshoot
  cinematic, wrap safety, zoom rails, no drift at rest. 7/7.
- ❓ **NOT verified, and it is a different axis rather than a weaker one**: whether 90° per tap
  FEELS right to him. No harness can answer that, and it is the property most likely to be
  wrong. If a tap should move less, the change is the multiplier in `rotateKey`; if it should
  not overshoot, it is `kZetaOrbit` 0.70 → 1.00. Both are one constant, and both are his call.
