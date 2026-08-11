# HANDOFF — KILL THE TUBE. Priority realignment, 2026-08-11 15:47:12

**His order:** *"align these to dos as priority HANDOFF KILL THE TUBE"*
**Commit:** `6218972`, pushed. Bundle `15:16:49`. Board: `docs/BOARD.md` (1,015 lines) is the reference of truth; this doc is the ordering on top of it.
**Berlin:** 2026-09-02 — **22 days.**

---

## 0. READ THIS FIRST — THE TUBE MAY NOT BE THE CAUSE, AND THERE IS A FREE TEST

His verdict that opened this: *"still unchanged feel in chladni mode but im sure our tube limitation is to blame for that."*

**The observation is not in dispute.** A measured, working depth cue landed today (§H10), the star map reads it, and the Chladni play state does not. **What is not yet established is WHY**, and B7 is an `L` — multiple sessions and a foundational rewrite. **Spending it on the wrong cause is the expensive mistake available here.**

Reading the code for this handoff turned up **three candidate causes. The tube is one. Another is free to test and needs no code at all.**

### ⭐ C1 — THE CAMERA LOOKS STRAIGHT DOWN THE CAVITY'S OWN AXIS. TEST THIS FIRST.

| Fact | Evidence |
|---|---|
| Default camera is `theta = π/2, phi = 0` → position `(0, 0, rho)` — **on the +Z axis**, looking down −Z. | `src/core/camera.h:31-32`, `:74-76` |
| The cavity eigenmode's axial structure is **along Z**: `kZ = pAx·π/EIGEN_L`, `pAx = 2 + ((mm+nn)%3)` = **2, 3 or 4 nodal planes stacked along Z**. | `particles.metal:2272-2273` |
| The star pass is additive with **no occlusion** (P1: nothing writes depth into the colour pass). | `renderer.mm:1033`, board §H1 |

**So the 2–4 nodal planes are stacked along the line of sight and additively superimposed into one image.** A structure whose entire depth extent points at the camera projects to a flat picture **by geometry**, no matter how good the depth cue is.

🚨 **THE TEST, AND IT COSTS NOTHING: hold a chord and orbit the camera ~90°.** If the pattern gains obvious layering side-on, the flatness is **viewing geometry + additive superposition, not the tube**, and B7 is not the fix. If it still reads flat from every angle, C1 is eliminated and the tube hypothesis strengthens considerably.
**Do this before writing a line of B7 code.** It is the highest information-per-minute item on the board.

### C2 — THE TUBE (his hypothesis)

⚠️ **State the geometry honestly, because it complicates the hypothesis:** the play cavity is radius `ORBIT_R_CHLADNI = 6` **and** `|z| ≤ EIGEN_L/2 = 6`. That is a can **12 wide by 12 tall — roughly isotropic. It is not a geometrically flat volume.** Both caps also yield `+8` while spinning.
So "the tube makes it flat" is **not self-evident from the clamp dimensions** and needs the measurement in §1 before it is acted on. What the clamp demonstrably does do is **kill outward velocity at the wall** (`particles.metal:3057-3066` radial, `:3080-3084` axial), which piles matter onto the boundary — the file's own comment records this producing *"STRAIGHT LINES; nothing in nature is straight"*.

### C3 — ADDITIVE SUPERPOSITION

Even with correct per-particle depth, stacked nodal planes blend into a single lump because nothing occludes anything. **The depth buffer now EXISTS (§H8) and nothing consumes it.** This is the cheapest structural improvement available and it is independent of B7.

---

## 1. THE MEASUREMENT GATE — do this before the rewrite

**Question:** does the play state actually occupy z, or is it flat?
**The instrument already exists.** `[DISKZ]` computes `H = sqrt(<z²>)` per radial bin with an `H/R` aspect (→0 = flat sheet), and it prints today. In **silence** it reads `H/R = 0.31…0.84` — genuinely thick.
**Nobody has ever read it during PLAY.** That single number discriminates C2 from C1/C3:

- `H/R` during play **comparable to silence** → the field is NOT flat → **B7 is not the cause**, look at C1/C3.
- `H/R` during play **collapsed** → the field IS flat → **B7 confirmed**, and the `L` is justified.

**Cost: `S`.** It may be a gating change only — the `[DISKZ]` block needs checking for a phase gate, since much of this telemetry is silence-only.

---

## 2. PRIORITY ORDER — realigned on his call

| # | Item | Why here | Cost |
|---|---|---|---|
| **1** | **C1 free test** — orbit the camera 90° during a chord | Costs one minute, can eliminate an `L` | **0** |
| **2** | **B7-measure** — `[DISKZ]` H/R during play | The gate. Confirms or kills the tube hypothesis with a number | **S** |
| **3** | **B7 — KILL THE TUBE** *(only if 1+2 confirm it)* | His stated priority. The cylindrical clamp is the symptom; the Bessel `J_m` basis is the real work. Prior design exists: 3D scalar ψ, damped wave PDE | **L** |
| **4** | **C3 — consume the depth buffer for occlusion** | Independent of B7, and §H8 already paid for the buffer. Makes stacked planes read as layers instead of one lump | **M** |
| **5** | **A3②-white** — gate the merger billboard on MASS, not `horizonR` | His repeated complaint (*"explosive feel, not white noise"*). **One line, written, unbuilt.** Show-visible | **S** |
| **6** | **A4 / W2** — release→silence snap | On screen every single play. Mechanism found: the crystal lock resists SPEED, not FORCE | **M** |
| **7** | **D6** — RT audio blocking lock | **The only item that can take down a live show.** Spec written, zero code | **S** |
| **8** | **A1′-endgame** — accretion unbounded in time | ~4 min of accretion consumes the field; a set is 40–60 min | **M** |

**Deferred by this realignment:** C12 (Doppler — studied, needs his call on the temperature-range limit first), F6 (camera, still gates A0), C3-star-size, C7.

---

## 3. IF B7 IS CONFIRMED — what the rewrite actually is

**Not "remove the clamp".** Removing it reproduces the failure its own comment records: unbounded along z, density smears along the free axis, no centre for a hole to form at, and grid cells with enormous counts that decayed fps (`particles.metal:3038-3047`).

**The real work is the BASIS.** Today's cavity is a cylindrical Bessel eigenmode `Ψ(ρ,θ,z) = J_m(k_ρρ)·cos(mθ)·cos(k_z z)` — a *can*, and the clamp exists to enforce the can's walls. His own stated goal is *"figure out what the actual truest form of soundwaves in 3d space is"*, and his prior design is on record: **a 3D scalar field ψ with a damped wave PDE** (`space_synth_neo_architecture`), where boundaries emerge from the PDE instead of being imposed by a clamp.

⚠️ **Two constraints the rewrite must respect, both already paid for in blood:**
1. **`imfMassOfId(id)` requires particles never change slots** — the A2 refund depends on recovering spawn mass from the slot index. Any re-indexing breaks it (this is also why B6 corpse compaction is deferred).
2. **`EIGEN_R` was tuned to the Bessel table's range**: at R=12 the table (`α ≤ 20.32`) could not texture the room and pattern fineness `∝ α/R` fell 4×. Whatever replaces it needs its own resolution argument, not an inherited constant (`particles.metal:270-276`).

---

## 4. WHAT IS SETTLED — do not re-litigate

- ✅ **The eigenmode is NOT faking 3D.** `pAx = 2 + ((mm+nn)%3)` is never 0, so `k_z > 0` always and Ψ genuinely varies along z; the force uses the full 3D gradient including `dPdz`; the axial phase references the cavity **wall** so nodal planes sit inside the can. **§H2. The flatness is downstream of the physics.**
- ✅ **The depth cue works and is measured** — 2.414× span, normalised by the measured `meanR`. The star map reads it. §H10.
- ✅ **Density can remove light** — coverage resolve, his verdict *"looking good"*. §H9.
- ✅ **The project writes depth** — §H8, and **nothing consumes it yet**.
- ❌ **P6 is a no-op** — `cam.bhX/Y/Z` are hard-zeroed by the ORIGIN LOCK. Do not "fix" it.
- ❌ **Doppler-as-a-tint is dead**, but **Doppler is REOPENED** by his order: colour must shift **TEMPERATURE**, not multiply a colour. §C12.

---

## 5. STANDING RULES EARNED TODAY — they cost three verdict cycles

1. 🧨 **Feeding a real value into a long-constant variable ACTIVATES EVERY DORMANT CONSUMER OF IT.** Two regressions from one change: a per-frame ZOOM number turned per-particle, and a near-clip fade that had been unable to fire since it was written. **A consumer written against a constant is not evidence the consumer works.** Enumerate the readers first.
2. 📏 **Compute the span before claiming a mechanism works.** A cue with a 3.7% spread was reported as working. Third sighting of this failure.
3. 🔄 **A "never again" rule must name whether the MECHANISM, the NUMBER, or the GOAL was rejected.** Only the first two can be permanent — the Doppler rule locked out a correct implementation for seven weeks.
4. ✅ **A provably pixel-neutral pass may batch**; anything that can move a pixel stays one at a time.

---

**Nothing is uncommitted. `6218972` is pushed. No commit without his explicit order.**
