# 🕳️ THE STRICT PLAN — GET THE BH TO THE REFERENCE

**Written 2026-08-27 20:44:12** on his order: *"we need to get th elense right its not a
corrct balck hoel yet i will not keep on rpepeating myself we have stuf fon the to do list
a stirct plan to get the bH as per reference"* `[HIS WORDS]`

**The verdict is `docs/reference/BH_REFERENCE_labeled.jpg` + `_optics.jpg`.** Not "the physics
is defensible", not "it compiles". A row closes when the SCREEN moves toward those frames and
he says so.

---

## 0. WHAT TODAY PROVED — read before picking a row

Two changes shipped and BOTH came back *"looks the same to me"* `[HIS WORDS 2026-08-27 20:31]`.
That is data, not a failure to be explained away:

| Change | Status | What the null tells us |
|---|---|---|
| **P1** step-rule ceiling `dl = stepScale·min(r,60)^1.5` (`render.metal:3425`) | in tree, **UNVERIFIED** | correct by measurement (rmin 16.05 → 1.51 r_s, turn 0.997π → 3.82π) but invisible |
| **P1b** visible-band Planck amplitude `visBandWeight()` (`:255`, applied `:3757`) | in tree, **UNVERIFIED** | correct by measurement (emissivity 4e-6 at r=50 r_s, 6e-44 at r=750) but invisible |

⛔ **CONCLUSION: THE MARCH IS NOT THE PICTURE HE IS LOOKING AT.** Two correct march fixes
changed nothing on his screen. The thing on screen is the SPRITE path — the lens.
**PARK THE MARCH. THE PLAN IS LENS-FIRST.** This agrees with the 2026-07-26 21:20 A/B
(*"ITS FINALLY THE CORRECT FEEL"* = lens on, march off) and with L4.

🚨 P1 and P1b stay in the tree because both are backed by measurement and neither can hurt —
but **neither may be cited as "done"** until he has seen a difference.

---

## 1. THE ROWS — ordered by dependency, one verifiable change each

Each row states the CHANGE, the MEASUREMENT that decides it, and the reference row it owes.

### 🔴 B0 — THE LENS AXIS IS THE CAMERA'S LOOK DIRECTION. **THIS IS "FAKE".**
**Owes:** R5, R6, and every *"weird depending on which side you look at it"* he has ever said.
**Where:** `render.metal:1115`.
```c
float3 dHat = float3(cam.viewForwardX, cam.viewForwardY, cam.viewForwardZ);
float along = dot(worldPos - bhWorld, dHat);
```
The whole lens geometry — what is "behind the hole", the depth `D`, the transverse axis —
hangs off **where the camera is POINTING**. Real lensing depends on where the observer **IS**.
F5 (2026-08-10) changed this from `normalize(-cam.cameraPos.xyz)` to `viewForward` and called
the old form wrong; **that reasoning is backwards.** The axis must be observer→**HOLE**:
`normalize(bhWorld - cam.cameraPos.xyz)` — which also survives a displaced hole, the thing F5
was actually worried about.
🚩 The code's own comment at `:1123` already lists his symptoms and names this cause. It was
written, and never acted on. `[READ render.metal:1115]`
**CHANGE:** one line. **MEASURE:** freeze the field, orbit the camera 360° around the hole.
The lensed structure must stay **locked to the hole**. Today it rotates with the camera.
**PASS:** structure is camera-independent. **FAIL:** it swims — then the axis is not the cause.

### 🔴 B1 — THE LENS IS SWITCHED OFF WHENEVER HE PLAYS
**Owes:** all of R1–R6, during the only time that matters on stage.
**Where:** `renderer.mm:1716` — `bhLensActive = (totalAmplitude < 0.02f)`.
The mindfuck look is a REST-STATE look and **cannot appear while he plays a note.** This is
deliberate (star-map regime) and it is a REGIME DECISION, **his call, not a bug to fix quietly.**
**MEASURE:** play and hold — does the hole keep lensing? **PASS:** he says which regime he wants.

### 🟠 B2 — R1: IS THE SHADOW ACTUALLY 2× THE HORIZON?
**Owes:** R1 (*"roughly twice the size of the event horizon"*).
L1's divisor fix **shipped 2026-08-20 15:36:28 and was NEVER LOOKED AT** (`renderer.mm:1661-1690`;
perspective was 2.897× too small).
**MEASURE:** my own `screencapture -x` → ffmpeg raw RGB → radial luminance profile; dark-disc
radius ÷ drawn horizon radius. **PASS:** ≈ 2.6. **FAIL:** ≈ 1.0 → the shadow is the horizon,
not the capture radius, and R1 is unbuilt.

### 🟠 B3 — R5: THE FAR SIDE MUST ARCH **OVER** THE SHADOW
**Owes:** R5. **Blocked by B0.**
**MEASURE:** at 10–20° inclination the disk must not stop at the shadow edge — it continues up
and over. **PASS:** a visible arch. **FAIL:** disk terminates at the edge.

### 🟠 B4 — R6: THE UNDERSIDE ARC, LEFT-RIGHT MIRRORED
**Owes:** R6. **Blocked by B0.** ⛔ **Parity is ALREADY ANSWERED** — `BOARD_BLACKHOLE.md` §2
proves det J < 0 from the code. **Do not re-derive it.** The open question is whether the arc
is VISIBLE and separate, not whether it swaps.
**MEASURE:** a distinct arc BELOW the shadow, its own image, not a mirror of the top.

### 🟡 B5 — R4: DOPPLER ASYMMETRY, VERDICT NEVER GIVEN
**Owes:** R4. T1 shipped **2026-08-14 12:01:52** and has sat unverified for 13 days.
**MEASURE:** mean luminance of the approaching half ÷ receding half, from my own screenshot.
**PASS:** strongly asymmetric. ⛔ **Do NOT retry the three dead beaming forms (§3 dead roads).**

### 🟡 B6 — R2: THE PHOTON RING
**Owes:** R2. **Blocked by B0–B4** — a ring on a camera-frame lens is decoration.
L3 stands: two sprite instances cannot make n≥2 windings; this needs the per-pixel integrator
on the thin annulus b ∈ [2.598, ~2.7] r_s (§5 option C). **P1 is the prerequisite that makes
that integrator actually wind** — 3.82π measured. That is the ONLY reason P1 stays in the tree.

### 🟢 B7 — R3: THE DISK IS NOT THIN
**Owes:** R3 (*"hot, thin"*). `DISK_H_OVER_R = 0.746` (`particles.metal:245`), MEASURED not
chosen. Ring CONTRAST needs a thin emitter. This is **physics in the field**, not a renderer
change, and it is the difference between "a ring is present" and "it reads like the reference".

---

## 2. ⛔ RULES FOR THIS PLAN

- **One row at a time. Verdict before the next.** Two stacked unverified changes is how today went.
- **Never cite a march change as progress** until B0–B4 are closed and he has seen the lens.
- **I take my own screenshots and measure them.** R1 and R4 are measurements, not opinions.
- **A comment is not a mechanism** — 8 sightings. B0 exists because a correct comment sat
  unacted-on for 17 days.
- ⛔ Dead roads stay dead: the march as the hole's renderer (L4) · the fullscreen black-disc
  overlay · the screen-space raytracer shadow · the slab cull · the seed billboard ·
  re-centring on `cam.bhX/Y/Z` (L5, 4 no-ops logged) · postfx as a cause of anything.

---

**Last Updated:** 2026-08-27 20:44:12
**Next:** B0 — one line, `render.metal:1115`. Awaiting his go.
