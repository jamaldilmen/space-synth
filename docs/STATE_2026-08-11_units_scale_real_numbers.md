# STATE OF AFFAIRS — UNITS, SCALE, AND THE REAL NUMBERS
**Written 2026-08-11 16:46:49 · tree `SPACE-SYNTH-TUBE-killtube` · branch `kill-the-tube-2026-08-11` · base `13ac249`**

**His ask:** *"i dont live in sim units. ima person. i want a second is a second, a light year is a light year… how much mass do we have? how much does time move when i warp it? how much time passes in one rotation? how many years is that… double check every claim currently existent and that you're about to make before writing anything down."*

Every number below is either read from a named `file:line`, computed from those constants, or measured in this session's own logs. Where a claim was already on the board or on screen and is **wrong**, it is marked ❌ and corrected. Where I did not verify something, it is listed in §9 as unverified rather than stated.

---

## 1. THE HEADLINE

**The unit system is correct. What is broken is that three different masses and two different length scales are live in the app at the same time, and the UI shows you the wrong one of each.**

The physics core (`spacetime.h`) is a genuinely derived, self-consistent SI system with no tuned constants. I checked it against independent Kepler arithmetic in SI and it agrees to **1.00003** (§4). That part is sound and should not be touched.

But:

| what | value | where |
|---|---|---|
| mass the **physics** integrates | **594,276 M☉** | `spacetime.h:36` `kMfieldMsun = 5.94276e5` |
| mass the **UI prints** | **2,000,000 M☉** | `main.cpp:1060` `N × PARTICLE_MASS_UNIT` |
| mass the **anchor** declares | **4,297,000 M☉** | `physics_constants.h:112` `BH_SGRA` |

| what | value | where |
|---|---|---|
| length the **physics** uses | 1 sim = **0.011732 AU** | `spacetime.h:43`, derived |
| length the **UI prints** | 1 sim = **0.084894 AU** | `main.cpp:1057` via `BH_SGRA.m_per_sim` |

**The UI's scale line is 7.236× too large.** That ratio is exactly `4.297e6 / 5.94276e5 = 7.231` — the mass ratio, because r_g ∝ M. Two independent routes to the same number, so this is confirmed, not coincidence.

**Every distance you have read off that panel is 7.2× too big.**

---

## 2. HOW MUCH MASS DO WE ACTUALLY HAVE

**594,276 M☉.** Not 4 million.

Sgr A* is **4.297 × 10⁶ M☉** ([GRAVITY Collaboration 2022](https://arxiv.org/pdf/2503.20081)) and it *is* in the codebase — but only as a **display anchor**, `BH_ANCHOR = BH_SGRA`, read at `main.cpp:1054` for the scale line. The gravity the integrator actually computes uses `kMfieldMsun = 594,276`.

**We are at 13.8% of Sgr A*.**

### Where 594,276 comes from — and this is your point, verified

It is not a physical choice. It is the IMF sum over the live particle set:

- The spawn writes 10M particles; **the GPU runs only the first 2,000,000** and kills the rest (`renderer.mm:1157-1161`, `kLiveSet = 2000000`).
- Each particle's mass is `imfMassOfId(id)` — a single power law, exponent −1.3 on the inverse CDF over **0.08 … 50 M☉** (`particles.metal:131-140`).
- Board §A5 verified by porting that IMF exactly: it reproduces the field total to 0.03% (594,084 vs the logged 594,276).
- Mean particle mass therefore = 594,276 / 2,000,000 = **0.2971 M☉**, matching `physics_constants.h:95` `IMF_MEAN_MASS = 0.30`.

**So: "2 million is bound to my GPU" is literally true, and worse than you thought.** `kMfieldMsun` is a `constexpr` — a compile-time constant. `kUnitMeters` is derived *from it* (`spacetime.h:42`). And the particle count is a **runtime slider, 0 to 10,000,000** (`main.cpp:1455`).

**Move that slider and the mass the physics believes in does not follow.** The summed live mass changes; the anchor doesn't. Gravity keeps using 594,276 M☉ no matter what is actually on screen. The GPU budget is silently the mass of the universe, and the one place it's written down can't hear the slider.

---

## 3. HOW BIG IS THE WORLD, IN HUMAN UNITS

1 sim length = 2·r_g(field) = **1,755,046 km = 0.011732 AU = 2.523 solar radii = 5.854 light-seconds**.

| | sim | AU | human |
|---|---|---|---|
| Schwarzschild radius of the whole field | 1.0 | 0.0117 | 1.76 mio km |
| Chladni cavity wall | 6 | **0.0704** | 10.5 mio km |
| star map, typical | 14.66 | 0.172 | 25.7 mio km |
| outermost matter | 32 | **0.375** | 56.2 mio km |
| rest cap `STAR_MAP_CAP` | 100 | 1.173 | 175 mio km |

**Mercury orbits at 0.387 AU. Essentially the entire simulation fits inside Mercury's orbit.**

### The consequence nobody has written down: these cannot be stars

594,276 M☉ inside a sphere of radius 0.0704 AU gives a mean density of **2.4 × 10⁵ kg/m³ — 172× the mean density of the Sun.**

Mean separation between 2M particles in that cavity: **1.35 × 10⁸ m**. Radius of a 0.30 M☉ main-sequence star: **~2.6 × 10⁸ m**.

**Separation / stellar radius = 0.51. The stars overlap.** (The exact mass-radius exponent doesn't matter here — linear or ^0.8, the ratio stays below 1.)

This is the real brick wall. At the current anchor the field is not a star cluster; it is matter at 18 Schwarzschild radii of its own total mass. Board §A3③ reached the same conclusion from the other direction and its wording is exact: *"the initial condition is already nearly a black hole."*

---

## 4. HOW MUCH TIME PASSES — VERIFIED AGAINST KEPLER

- 1 sim time = 1 sim length / c = **5.854 real seconds** (`spacetime.h:47`).
- Warp knob `kTLapse = 3.51513` sim-time per wall-second (`units.h:46`).
- **Base rate: 1 wall second = 20.578 real seconds.** (`units.h:62`, and the board's 15:12 run independently confirms it: 41 wall-min → universe clock 13.62 h.)

**Cross-check:** for the measured shell r=14.66 sim, M_enc = 4.15e5 M☉, the code's `Texact` law gives **169.8 wall-s**. Converting with the warp: 169.8 × 20.578 = **3494.2 real s**. Independent SI Kepler on the same shell: `T = 2π√(r³/GM)` = **3494.1 real s**.

**Ratio 1.000030.** The unit system reproduces textbook Kepler. It is right.

### One rotation, per shell (measured shells from this session's silence log)

| r sim | r AU | M_enc | one orbit, real time | wall-s at 1× | orbits per 10 wall-min |
|---|---|---|---|---|---|
| 0.29 | 0.0034 | 4.0e4 | **0.52 min** | 1.5 | 396 |
| 1.77 | 0.0208 | 8.1e4 | **5.52 min** | 16.1 | 37 |
| 4.58 | 0.0537 | 1.2e5 | **18.6 min** | 54.2 | 11 |
| 8.21 | 0.0963 | 2.2e5 | **33.8 min** | 98.4 | 6.1 |
| 14.66 | 0.172 | 4.2e5 | **58.2 min** | 169.8 | 3.5 |
| 32.14 | 0.377 | 5.8e5 | **2.67 hr** | 467.8 | 1.3 |

**Direction:** one dominant rotation, about **+Z, counter-clockwise** — set at spawn as `v = ω(−y, x, 0)` (`particles.cpp:258-261`), with 4% velocity dispersion and ±8% eccentricity on the disk component, and the nucleus given 0.55× circular support (`:254`, `:266-273`).

### "How many years is that"

**It isn't years. Nothing here takes years.** One orbit of the entire field = **2.7 hours** of real physics time = 1.1 × 10⁻⁴ years. For contrast, at these same radii around a normal 1 M☉ star: 0.0704 AU → 0.019 yr; 1 AU → 1 yr; Neptune at 30 AU → 165 yr.

Our orbits are minutes-to-hours because 594,276 M☉ is crammed into less than half an AU. That is why the warp only needs 20×.

### What the warp buys

| multiplier | real s per wall s | per wall hour |
|---|---|---|
| 1× | 20.6 | 2.3 × 10⁻³ yr |
| 8× | 164.6 | 1.9 × 10⁻² yr |
| 64× | 1,317 (21.9 min/s) | 0.15 yr |
| 512× | 10,536 (2.9 hr/s) | 1.2 yr |

**Even at 512× a full wall-clock hour buys 1.2 years.** Stellar evolution is 10⁶–10¹⁰ years away. We are not simulating the life and death of stars; we are simulating **hours** in a hyperdense cluster. Any language on the board or on screen about stellar birth/death timescales is aspiration, not what the clock does.

---

## 5. ❌ WHAT THE UI HAS BEEN TELLING YOU THAT IS FALSE

| line | prints | truth | error |
|---|---|---|---|
| `main.cpp:1125` | `Particle: 1.00 M_sun (1 star)` | mean is **0.2971 M☉** | hardcoded string; 3.37× |
| `main.cpp:1060` → `:1129` | field = N × 1.00 M☉ = 2.0e6 M☉ → **6.67% of NSC** | 594,276 M☉ → **1.98%** | 3.365× |
| `main.cpp:1107` | `1 sim unit = 0.0849 AU [FIXED CAL]` | **0.011732 AU** | **7.236×** |
| `main.cpp:1126` | `(Kroupa IMF)` | single α=2.3 power law = **Salpeter** | wrong name |
| `physics_constants.h:114` | conservation check divides by `IMF_MEAN_MASS(0.5)` | the file's own `:95` says **0.30** | self-inconsistent |

Note `main.cpp:1126` does read the **live** `fieldMassMsun` for the mass value — that one is honest. The star *count* and the percentage beside it are not.

The `[FIXED CAL]` label is doing real damage: it presents the 7.2×-wrong number as a *calibration*, which reads as "this one is trustworthy."

---

## 6. WHAT THIS MEANS FOR THE ψ REWRITE

The acoustic framing from today stands and it gives derivable constants — sound speed `c_s = c/√(3(1+R))`, the sound horizon as the pattern's characteristic scale, Silk damping as the physically-correct scale-dependent loss term ([Planck 2018](https://arxiv.org/pdf/1807.06209), [Hu & White](https://arxiv.org/pdf/astro-ph/9602019)).

**But none of it can be anchored while the length unit is defined as "2 r_g of whatever mass the GPU happens to be running."** A wave speed in a medium is meaningless without a fixed length and time. Right now both move when the particle slider moves.

**The unit re-anchor is a prerequisite for ψ, not a parallel task.**

---

## 7. WHAT HAS TO CHANGE TO GET WHERE HE WANTS

1. **Decouple mass from particle count.** Mass is a physical choice; particle count is a resolution choice. `M_field` becomes a declared constant and per-particle mass becomes `M_field / N_live`, so moving the slider changes *resolution*, not the universe. This directly conflicts with `imfMassOfId` being a pure function of slot id — which the A2 refund and B6 both depend on. **That conflict is real and has to be designed around, not ignored.**
2. **One length anchor, stated in AU or metres, not in r_g of the field.** Then r_g becomes a *derived readout* instead of the definition, and it stops moving when mass changes.
3. **Delete the second scale.** `BH_ANCHOR` should be a labelled comparison ("Sgr A* for reference"), never a source of on-screen scale.
4. **Fix the five UI lines in §5.** Cheap, and it stops the instrument from lying to its player.
5. **Pick the density regime honestly.** At 594,276 M☉ in 0.07 AU these are not stars. Either the volume grows by orders of magnitude (→ a real cluster, and orbits become years) or we call the particles what they are (mass elements in a relativistic flow). Both are defensible; the current mix is not.
6. **For entering star systems:** 1 light-year = **5,390,589 sim units**, and float32 carries ~7 significant digits, so absolute positions lose metre-scale precision long before that — ULP at 1 ly is ~0.6 sim units ≈ 1 million km. This is exactly the problem `space_synth_spaceengine_scale_research` documented: camera-relative rendering, 64/128-bit positions, and representation switched by **angular size**. Multi-scale is an architecture, not a constant.

---

## 8. BOARD CORRECTIONS FROM THIS AUDIT

- Board line 392-393 already recorded both anchors side by side. **It did not record that they disagree by 7.236× and that the UI publishes the wrong one.** Now recorded.
- `particles.cpp:241-244` says the live set is *"a uniform 1/5 id-subsample"*. `renderer.mm:1157-1158` says it is *"the FIRST 2M indices of the packed 10M buffer"*. **These are different mechanisms and both cannot be true** — third sighting of the project's "a comment is not a mechanism" failure.
  **✅ RESOLVED 2026-08-11 16:52 — the discrepancy is real but statistically harmless, so nothing built on it is unsound.** The concern was that taking the *first* fifth would bias the sample if any property were assigned in id-order blocks. It is not: the component is an independent per-star draw (`particles.cpp:130-134`, `sel = u01(rng)`), positions are iid draws in the same loop, and mass is a hash of the id. Verified against the spawn's own log line — `7498578 disk / 1000645 nucleus / 1500777 halo` = 10,000,000 at **74.99 / 10.01 / 15.01%**, matching the intended 75/10/15. Mass check: all 10M sum to 2.9663e6 M☉ (mean **0.29663**), the live 2M sum to 594,276 M☉ (mean **0.29714**) — **0.17% apart**. The front fifth is the same population as the whole. Also confirms the 1/5 relation: 2.9663e6 / 5 = 593,260 vs the anchor's 594,276.
  ⚠️ Still worth fixing the wrong comment, because the next person to read it will re-open this.
- Board §A3③'s scale conclusion (*"the initial condition is already nearly a black hole"*) is **confirmed independently** by this audit's density number: 172× solar mean density, stellar separations below stellar radii.

---

## 9. WHAT I DID NOT VERIFY

Stated plainly so nothing here is taken for more than it is.

- **I did not re-verify all 1,015 lines of `BOARD.md`.** I checked the claims bearing on mass, length, time and scale. The physics/render rows (A1′, A3②, D6, B7 etc.) are untouched by this audit.
- **`NSC_MASS_MSUN = 3.0e7`** (`physics_constants.h:121`) is taken as cited in the file; I did not chase the source paper.
- **The `[FIXED CAL]` UI path** was read but not run — I have not watched the panel print 0.0849 AU on screen. The arithmetic and the code path are verified; the pixel is not.
- **Silk damping as an implementable term** is verified as real physics, not as something with a chosen discretisation. No numbers picked yet.
- **The 0.30 M☉ mean-radius figure** uses an approximate main-sequence mass-radius relation, not the Eker 2018 MLR in our references. The overlap conclusion holds under either.

---

## 10. THE ONE-LINE ANSWER TO WHAT HE ASKED

**We have 594,276 M☉ — 13.8% of Sgr A* — packed inside 0.4 AU, so it is 172× denser than the Sun, its stars physically overlap, one full rotation of the field takes 2.7 hours of real time, one wall-second buys 20.6 seconds of it, and the panel on screen has been reporting the size of all of it 7.2× too large.**

The unit *system* is honest. The unit *anchor* is an accident of the GPU budget. That is the thing to fix before anything else gets built on top of it.
