# HANDOFF — 2026-08-11 18:02:00 · scale audit, UI truth fix, accretion bound

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube` · branch `kill-the-tube-2026-08-11` · base `13ac249`
**Main tree** `SPACE-SYNTH-TUBE` is clean at `13ac249`. **Nothing is committed anywhere.**
**He stopped here:** on the go, low battery. Resuming later.

---

## 1. THE ONE TEST OWED — do this first when he is back

**Launch, leave it idle 15–20 min, read `Biggest body`.**

An unattended 13.8-min run already happened (`/tmp/killtube_bound.log`, 828 FPS ticks) and ended at
**84,592 M☉, flat**, against a pre-bound 356,475 M☉. That is 60% of the field → **14.2%**.

🚨 **NOT VERIFIED.** Two reasons, both in the data:
- The growth trace **jumps**: `36,085 → 69,934 → 71,011 → 84,592`. Smooth tapered capture would not
  step like that. Prime suspect is the **unbudgeted seed↔seed merge path** (§4.1) — so 84,592 may be
  a pause, not the ceiling.
- `Mlive` drifted **588,891 vs 594,276 = −5,385 (−0.91%)**, an order above the board's known −280/−301.
  Unexplained. Check whether it tracks the merge jumps.

The bound is **102,144 M☉**; the taper starts at 70% = **71,501**. 84,592 sits inside the taper band.

---

## 2. WHAT SHIPPED TODAY (uncommitted, in this tree)

### 2a. UI truth fix — `main.cpp`, `physics_constants.h`
The GALAXY panel was lying. Verified and corrected:

| line | was | now |
|---|---|---|
| `main.cpp:1057` | `1 sim = 0.0849 AU` (Sgr A* anchor) | **0.011732 AU** (field anchor, `spacetime.h:43`) |
| `main.cpp:1060` | field = N × 1.00 M☉ = 2.0e6 | **live `fieldMassMsun`** = 5.94e5 |
| `main.cpp:1125` | hardcoded `Particle: 1.00 M_sun` | **live mean ≈ 0.297** |
| `main.cpp:1126` | `(Kroupa IMF)` | **`(Salpeter a=2.3)`** — it is a single α=2.3 law, `particles.metal:131` |
| `physics_constants.h:114` | conservation check ÷ 0.5 | corrected; file's own `:95` says 0.30 |

**The scale line was 7.236× too large** — exactly the mass ratio 4.297e6/5.94276e5, because r_g ∝ M.
Two anchors were live at once and the panel published the wrong one under a `[FIXED CAL]` label.

### 2b. Accretion outcome bound — `particles.metal`
`F_BH_CLUSTER = 0.17188` (Sgr A* / Milky Way NSC, **observed**), applied as a feedback taper on the
capture budget at `:1352`:
```
mBound = F_BH_CLUSTER * u.massTotal
fFb    = 1 - smoothstep(0.70*mBound, mBound, mS)
budget = MDOT * dt * fFb
```
Flat below 70% of the bound, so the verified 2,451 M☉/wall-s linear regime is untouched.

---

## 3. THE AUDIT — `docs/STATE_2026-08-11_units_scale_real_numbers.md`

Every figure computed from the code's own constants and cross-checked against SI Kepler
(**agreement 1.00003** — the unit system is correct and must not be rewritten).

- Field mass **594,276 M☉** = 13.8% of Sgr A*, and it is the IMF sum over the live particle set —
  **the mass of the universe is downstream of the GPU budget.**
- 1 sim unit = **1,755,046 km = 0.011732 AU**. The whole sim fits inside Mercury's orbit.
- Density **2.4e5 kg/m³ = 172× solar mean**; mean separation **0.51× a stellar radius** — *the stars overlap.*
- **Too compact by 1,179,564× linear** vs the real NSC at the same mass fraction.
- 1 wall second = **20.578 real seconds**. One field rotation = 2.67 hr. Nothing here takes years.
- BH should top out at **17.2%** of cluster mass → **102,144 M☉** for our field.

---

## 4. NEXT, IN ORDER (his sequence: mine 2 → automatic)

**Mine 2 is already defused — do not spend a change on it.** Verified: `REST_RECYCLE` is dead code;
`SUSTAIN_REBIRTH` cannot fire twice per frame because `frameCounter` is written once per frame
(`renderer.mm:1411`) so every substep draws the same lottery, and `:737` sets `mass = imfMassOfId(id)`
so the `mass <= 0.001f` guard at `:687` blocks re-entry. **The warning in `app_state.h:68` is stale** —
written 2026-07-25, the hazard was removed 2026-08-04.

### 4.1 🚨 Seed↔seed merge is unbudgeted — likely the cause of the jumps above
`particles.metal` ~`:1481` uses a plain `atomic_fetch_add` on the plate: **no CAS, no budget check.**
It bypassed the 2026-08-08 rate limit as well as today's bound. Nobody had noticed.

### 4.2 The automatic transmission (his "Differential")
**Both halves already exist and are not connected:**
- **Gear stick:** `uiPhysicsSubsteps` 1–32, real loop at `renderer.mm:2811`. `app_state.h:68` states his
  own point verbatim: *"does NOT detonate like dt×64 … Leave time-warp at ×1 and dial THIS for speed."*
- **Tachometer:** `particles.metal:1962-1968` computes *"Required accurate sub-steps ≈ ceil(4·ratio)"*
  and says *"This does NOT change motion."* The number is computed and thrown away.
- **Missing:** anything joining them. That is the "accuracy-governed cap" `units.h:19-22` defers as Step 2.

⚠️ Raising gears buys sim-time per wall-second, so it reaches the accretion endgame sooner — which is
why the bound (§2b) had to land first.

### 4.3 Space gear — not built at all
float32 carries ~7 decades; the ladder needs **11.87**. Needs camera-relative float64 positions.
His words: *"die richtigen Nachkommastellen bei der richtigen Skala."*

---

## 5. KNOWN LIMITATIONS OF WHAT SHIPPED

1. **The bound rides the Size slider.** `u.massTotal = Σmass × massScale`, `massScale=(Size/2)^1.25`,
   but `mS` is raw. Exact at the default **Size = 2.0** (massScale = 1.0). Size 0.8 → ceiling ~32,500.
   Fixing properly needs a new unscaled-total uniform.
2. **Seed↔seed merges can still exceed the bound** (§4.1).
3. The `[FIXED CAL]` UI path is verified by arithmetic and code path, **not by watching the pixel.**

---

## 6. THE ONE-KNOB DESIGN (agreed, not built)

The knob is a **period**, log-spaced, 127 notches: bottom 1 ms (a note), top 161,269 yr (the cluster orbit).
**15.707 decades → ×1.3295 per step = a perfect fourth (4/3) to 0.29%; eight steps = one decade to 0.11%.**
Space is *derived*, not a second knob: wavelength `c_s·T` below the crossover, Kepler radius above.
The sound/gravity crossover sits at **MIDI 34.04**.
⚠️ "Today sits at MIDI 37" was **partly an artifact of my arbitrary 2-second bar** — across a 16× tempo
range it lands 32–42. What survives: the instrument occupies **one notch** of 127 and ~90 above are unbuilt.

---

## 7. STANDING FACTS EARNED TODAY

- **B7's premise was wrong.** The Chladni play state is **not flat** — `H/R = 0.529` vs 0.176–0.240 at
  silence. It is a **hollow shell welded to the wall** with an evacuated interior: `[SHELLV]` reads
  `r<1:0  1-2:0  2-3:0` under a chord.
- **The cause is not the clamp.** Reflecting the wall instead of projecting (`cap²/rXY`) moved the pile
  (1000/1000 → a 460/540 split) and his verdict was still *"looks just the same"*. **Reverted.**
- **The cause is angular momentum:** `vt = 1.17` against `0.006` at silence, ~200×, pinned at
  `CHLADNI_VCAP = 1.2`. Nothing in the code sheds L — no MRI, no transport. Matter can only be captured
  by a radius test, never accrete. Same wall as `angular_momentum_is_the_wall`.
- **Gravity is OFF during play** (`gravSupport` saturates at amp ≥ 0.5, `:1240`, `:1976`), so `sup = 149`
  divides by a force that is not applied. My earlier framing of that number was wrong.
- **Integration accuracy degrades over a run:** `[ACC] clamped` 0.0% at launch → **37.4% at 4 minutes**,
  worst 1.64 c·dt. A Berlin set is 40–60 min.
- **The ball was rejected on sight.** He wants *"true 3d representation of soundwaves in 3d space"* —
  not a sphere, not a can. Both are imposed containers.

---

**Reference of truth is still `docs/BOARD.md`; this doc + `STATE_2026-08-11_units_scale_real_numbers.md`
are the ordering and the numbers on top of it. No commit without his explicit order.**
