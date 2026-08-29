# STATUS — for Jamal
**2026-08-28 21:36:10** · one page · replaces scattered reports

---

## ✅ LIVE RIGHT NOW (pid 17335, fullscreen, unbuilt changes in the tree)

| what | state | how to check it yourself |
|---|---|---|
| **Camera feel** | DONE, your verdict: *"i love the feel the snappiness"* | zoom eases in/out, zero overshoot |
| **`c` = cinematic** | DONE | press `c`, log prints `[CINE]` |
| **45° taps, 8 per turn** | DONE, your order | tap an arrow |
| **M fix (hole stops vanishing)** | DONE but ⚠️ **HAS A REGRESSION, see below** | log: `DRAWN r_h=… from seed M=…` |

**Nothing is committed.** The tree has 3 modified source files.

---

## ⚠️ CORRECTION I OWE YOU — the M fix draws the hole far too SMALL early on

I told you the hole would be "half to two-thirds" its old size. **That was measured on one
mature run and it does not generalise.** Fresh run 21:23, 20 samples:

```
profile r_h=0.1562  M(<r_h)=93,040 M_sun   |   DRAWN r_h=0.0014  from seed M=857
```
**137 samples, and BOTH halves matter:**

| | old (profile) | new (seed) |
|---|---|---|
| hole present | 7% of samples | **57%** ← the fix wins here |
| size when both present | 1.00 | **0.018** ← and loses badly here |

⚠️ The size ratio rests on **n = 10** — the same thinness that made my earlier "0.627"
fail to generalise. Neither number is *the* ratio. **The fix trades size for persistence.**

Why: the seed measures ONE merged body; the old profile measured CONCENTRATION. Early in a
run the stars are concentrated but barely merged (`seeds=2`, `mrg=0/0/0`), so the drawn hole
reports *how much the broken capture managed to eat* — not the hole.

⭐ **Which makes it the SAME bug as the toilet drain.** The `:1429` clamp starves capture →
seed stays tiny → hole draws at 1%. **One deletion should fix both.**

---

## 🔴 THE MAIN JOB — your words, 2026-08-28

> *"WE NEED TO GET THE PHYSICS CORRECT our black hole is still a toilet drain.
> stuff behaves differently near a blackhole i want this executed just as well
> as kill the tube."*

Not started. Everything below is subordinate to it.

---

## 📋 QUEUED — decided, not built

1. **6-point JWST star spikes** — you chose it 14:03. Today `render.metal:2652` draws
   `spikeX`/`spikeY` = a 4-point cross. Needs 3 bars at 60°.
2. **The cubes / grid** — you said: *"just aside info, not our main issue rn, but what
   u figured out is valuable so try that route. write it down for later."* Written down:
   `space_synth_the_grid_is_in_the_physics_2026-08-28`. **It is a BH-physics lead**, see below.
3. **Camera rides** — multi-waypoint + bounce. Design done in `docs/CAMERA_STEP2_DESIGN.md` §9.
   Blocked on ONE answer from you (below).
4. **`lastHorizonMass`** — radius now comes from the seed, mass still from the profile. Two Ms.

---

## ⭐ WHY THE GRID FINDING IS ACTUALLY THE BH JOB

Verified at `file:line`, `src/render/particles.metal`:

- `:1429` — the hole's tidal capture radius is computed honestly from mass and
  relative velocity, then **thrown away**: `rt2 = min(rt2, (1.4*cellSize)^2)`.
  **At cellSize 1.0 the hole can never reach past 1.4 sim regardless of its mass.**
- `:3812` — one seed per cell, plain write, no atomic. Two seeds in a cell, one is invisible.
- `:3807` — rejection is per-axis, so the domain is a **CUBE of half-side 64**.
  Live field: `meanR=28.69 maxR=100.0`. Matter is outside the faces.

⇒ **"Toilet drain" and "cubes" may be one bug.** The drain sucks uniformly because the
capture radius is a grid constant, not physics.

---

## ❓ BLOCKED ON YOU — one question

**Camera rides:** at each waypoint the camera stops. Either it **holds ~0.4 s then departs**
(passes exactly through every framing you flew), or it **advances early** (continuous, but
rounds corners and passes *near* your points). Recommendation: hold.

---

## 🚫 DEAD — do not re-pitch

- **BPM sync** — rejected 2026-08-28. Was the brain's wording, not the camera window's.
- **Cinematic mode owning time warp** — rejected. Warp spins the object, not the camera.
- **ζ → 1.00 on orbit** — you praised the snappiness; the overshoot stays.
