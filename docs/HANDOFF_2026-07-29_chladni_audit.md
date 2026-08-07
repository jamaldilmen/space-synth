# HANDOFF — 2026-07-29 — The Chladni audit: why it's blurry, not sharp

**Written:** 2026-07-29 14:26:33. Branch `session-2026-06-30-honest-spacetime-friction`, on `b047744` + uncommitted.
**Supersedes:** `HANDOFF_2026-07-28_evening_chladni_speed_stars.md` §0 — **that §0 is WRONG**, see §1 below. Everything else in that document still stands.
**Companions:** `HANDOFF_2026-07-28_stars_lens_and_todos.md` (star measurements + dials) · `RESEARCH_2026-07-28_spaceengine_scale.md`.

His report, 2026-07-29: *"shape resolution. its blurry not sharp. not crystalized after holding it. not matter from light / plasma feel."*

---

## 0. THE ANSWER, IN TWO SENTENCES

**The shapes are drawn by the cylindrical eigenmode (Gor'kov force on Ψ = J_m(k_ρρ)·cos(mθ)·cos(k_zζ)).
When you hold a note, crystallization replaces every particle's velocity with `ridgePull` — which is
the gradient of a COMPLETELY DIFFERENT field, the spherical-harmonic Y_lm sculpt whose own force is
disabled by default.** So holding a note condenses matter onto the ridges of a field that isn't the
one making the picture.

**And nothing removes energy AT the nodal surface.** Gor'kov is a conservative potential force and
play friction e-folds in ~9.5 s, so particles oscillate straight through the node forever. The band
you see is the oscillation amplitude, not the node. That is the blur.

Neither of these is a tuning problem. Both are structural.

---

## 1. ⚠️ RETRACTION — yesterday's §0 was wrong

`HANDOFF_2026-07-28_evening_chladni_speed_stars.md` §0 claimed the ring problem was
`modes.cpp:24` feeding the note's frequency in Hz into the Bessel argument.

**That code is dead.** Verified 2026-07-28:
- `makeLUT`, `sampleLUT`, `LUTCache` — **no callers** outside `src/core/lut.cpp`.
- The CPU `ZEROS` table (`bessel.cpp:7`) — **no readers at all**.
- `VoiceData.alpha` IS filled with Hz, but the GPU deliberately ignores it and uses its own
  `BESSEL_ZEROS` — documented at `particles.metal:349`, found 2026-07-09.

The Hz alpha is a real trap for whoever wires that path up next, but it was never on screen.
**Lesson repeated for the third time this session: confirm the code is LIVE before diagnosing it.**

---

## 2. THE LIVE CHLADNI CHAIN — full audit

| # | Stage | File | State |
|---|---|---|---|
| 1 | note → (m, n) | `modes.cpp:17-20` | `m = midi % 12`, `n = max(1, octave)` |
| 2 | (m, n) → GPU voice | `main.cpp:692` | `vd.m = v.mode->m` — clean |
| 3 | (m,n) → α | `particles.metal` `BESSEL_ZEROS` | ✅ **FIXED 2026-07-29**, see §3 |
| 4 | α → Ψ, ∇Ψ | `particles.metal:~2029` `besselJmD` | ✅ **FIXED 2026-07-29**, see §3 |
| 5 | Gor'kov force | `particles.metal:~2063` | conservative — ⚠️ §5 |
| 6 | damping | `particles.metal:611` | ~9.5 s e-fold — ⚠️ §5 |
| 7 | crystallization | `particles.metal:2432, 2618` | ❌ **BROKEN**, see §4 |
| 8 | render | `render.metal` sprite kernel | "little cubes", still open |

---

## 3. ✅ FIXED TODAY — the mode table and the Bessel evaluator

**Was:** `BESSEL_ZEROS` was 7×4 (m≤6, n≤4) and the lookup **clamped to fit** —
```cpp
int mm = clamp(int(voices[vi].m), 0, 6);   // modes.cpp makes 0..11
int nn = clamp(int(voices[vi].n), 1, 4);   // modes.cpp makes 1..9
```
So **F♯, G, G♯, A, A♯ and B all drew the identical shape (m=6)**, and every octave ≥4 drew n=4.
Half the keyboard was one mode.

**Now:** 12×9 table, clamps widened to (0..11, 1..9). His verdict: *"way better tho."*

**The table could not be extended alone.** Measured against 80-digit ground truth
(`scratchpad/bessel_truth.py`, 5889 samples):

| evaluator | range | worst abs err |
|---|---|---|
| shipped (series + Hankel asymptotic) | m≤6, x≤20.4 | 1.5e-3 ✅ |
| shipped | m≤11, x≤43.4 | **8.9e-1** ❌ |
| **new (series + Miller recurrence)** | m≤12, x≤43.4 | **2.6e-7** ✅ |

|J| ≤ 1 everywhere, so 0.89 is garbage — the asymptotic P/Q terms carry
(mu−1)(mu−9)(mu−25)(mu−49) ≈ 4.6e10 at m=11 and diverge. No crossover value rescues it (swept 4).
**Extending only the table would have shipped a broken field.**

Two constraints deliberately honoured, both from 2026-07-09:
- **Fixed iteration count** (M=64, the measured knee) — a data-dependent break hung PSO creation.
- **No 1/x near the axis** — the power series owns x < 4, so Miller never sees a small x. Verified
  `J_0(1e-4)=1.00000000`, `J_11(1e-4)=0`, zero non-finite results across all samples.

---

## 4. ❌ THE CRYSTALLIZATION IS WIRED TO THE WRONG FIELD — ⭐ ROOT CAUSE

`particles.metal:2618`
```cpp
float soften = 1.0f - hardness;
float3 finalV = (v * dynamicFric * coolMul + shift) * soften
              + ridgePull * (hardness * 8.0f);
```
At full hardness `soften = 0`, so **`finalV = ridgePull * 8` and nothing else.**

And `ridgePull` (`:2138`) is:
```cpp
ridgePull = (sum_dYdth * thetaDirG + sum_dYdphi * phiDirG) * polyNorm;
```
`sum_dYdth` / `sum_dYdphi` (`:2118`) accumulate **`dYdth`, `dYdphi` — the SPHERICAL HARMONIC Y_lm
sculpt gradient**, originally accumulated for Chord Webbing.

**The shapes come from the cylindrical eigenmode. The condense direction comes from the spherical
sculpt.** Two different fields. So a held note drags matter off the Chladni structure and onto Y_lm
ridges as it hardens.

The block's own comment (`:2583`) states the design intent exactly, and it is not being met:
> *"Freezing motion in place blurs (it locks a loose cloud mid-swim). Instead, as a grain hardens we
> fade OUT its momentum … and fade IN a pure RIDGE-PULL — overdamped gradient ascent that drives it
> onto the exact node line and self-terminates there (∇Y→0) → sharp threads, not frozen dust."*

**Why it broke:** this was written when the Y_lm sculpt WAS the shape-maker. On **2026-07-19**
eigenmode-only became the default (`main.cpp:2275`, bit23 on / bit16 sculpt skipped) after his A/B
— *"looks a loooot better"* — and the crystallization was never re-pointed at the new field. It has
been a stale coupling for ten days.

**The fix (NOT applied — needs his word):** `ridgePull` must be built from the SAME field that draws
the shape, i.e. the eigenmode's own Gor'kov direction `−contrast·Ψ·∇Ψ` accumulated in the bit23
block, not the Y_lm gradient. Then `∇Ψ→0` on the nodal surface and the self-termination the comment
describes actually happens.

### 4b. Secondary: the freeze is applied twice
`:2566` multiplies velocity by `lock = mix(1.0, 0.05, hardness)` during sustain, and `:2618`
multiplies it again by `soften = 1 − hardness`. Two independent hardness-driven velocity kills
stacked. With ridgePull ≈ useless, the net effect is exactly the "frozen loose cloud" the comment
warns against.

### 4c. Timing worth knowing
Crystallization only runs when `u.envelopePhase > 2.5` (sustain/release) and integrates at
`1/15 … 1/10` per second — **10 to 15 seconds of holding to reach full hardness.** If he holds for
3 s he is seeing hardness ≈ 0.2–0.3. Whether that matches his expectation is his call; it is not
currently a dial.

---

## 5. ⭐ WHY IT IS BLURRY EVEN BEFORE CRYSTALLIZATION — no dissipation at the node

The Gor'kov force `F = −Ψ∇Ψ = −½∇(Ψ²)` is a **conservative potential force**. A particle falling
toward the nodal surface arrives with kinetic energy and passes straight through, rises up the other
side, and comes back — a harmonic oscillator about the node. It only settles when something removes
that energy.

The only damping in play is `fricPlay = pow(0.9, dt)` (`:611`) — **an e-fold of ~9.5 seconds**. The
oscillation period about a node is far shorter than that, so particles cross the nodal surface many
times before losing meaningful energy.

**The visible band width is therefore the oscillation amplitude, not the node width.** That is the
blur, and it is independent of particle count — more particles would give a denser blur, not a
sharper line.

⚠️ **The project's own founding spec already had the fix.** `CLAUDE.md`, "The proven system" ported
from `SOUND ARCHITECT.html`:
> **"Node braking: friction scales with distance-to-nodal-line"**

That is dissipation localised at the node — exactly what makes real Chladni sand snap onto a line
instead of shimmering across it. **It does not exist anywhere in the eigenmode path.** Grepped:
the only brakes in `particles.metal` are the shell brake (`:852`) and the seed damper (`:1048`).

**Proposed (NOT applied):** friction that scales with |Ψ| — strong damping away from the node, near
zero on it. That is one multiply on a value (`psi`) already computed at `:2038`, it is the documented
canon, and it is the mechanism that makes the pattern crisp.

---

## 6. C ALWAYS DRAWS PURE CIRCLES — by construction

`m = midi % 12`, so pitch class 0 → m = 0, and then:
```cpp
float mth = 0;  →  cA = 1, sA = 0
float dPdth = JJ.x * (-0 * sA) * cZ / rho;   // ≡ 0
```
Zero angular force. Radial rings and axial planes only — **concentric circles, on every C, in every
octave, always.** Anyone testing on C sees circles regardless of every fix above.

Whether pitch class 0 SHOULD map to the structureless mode is a design question, not a bug. Options:
offset the mapping (`m = 1 + midi % 11`), or map pitch class to m by circle-of-fifths so C lands
somewhere with lobes. **His call.**

---

## 7. "NOT MATTER FROM LIGHT / PLASMA FEEL" — not yet investigated

Flagged, not audited. This is the render side, not the physics: at rest particles render as stars
(mass-blackbody); during play colour is blackbody-of-temperature. The emission-line palette
(`supernovaRamp`, `render.metal:183`) — the thing that actually reads as *plasma* rather than *hot
dust* — is currently reserved for the supernova state. Needs its own pass.

---

## 8. TO DO — ordered, with what each unblocks

1. ⭐ **Re-point `ridgePull` at the eigenmode gradient** (§4). The single highest-value change:
   it is what makes a held note crystallize into the shape instead of away from it.
2. ⭐ **Node braking: friction ∝ |Ψ|** (§5). This is the sharpness fix, and it is the documented
   canon from the original proven system.
3. **Decide the m=0 mapping** (§6) — his call, one line either way.
4. **Sprite kernel / "little cubes"** — a point sprite is a square quad; evaluate the fragment
   kernel at the corner (|pc| = 0.707). Unblocks bit18.
5. **Revive bit18** (flux-conserving arc) — dead code, `sL ≡ 1` from an uninitialised read. Its own
   tooltip is his "time-shifting stretched light" aesthetic verbatim.
6. **Fold the hole pass into the main particle pass** — see the 07-28 handoff §2; kills the
   "two black holes" layering by construction.
7. **`[WPROBE]` ω-histogram → block/hierarchical timesteps** — his approved answer to the ×64 wall.
8. **Plasma colour** (§7).

---

## 9. RULES EARNED — do not re-litigate

- **POSTFX IS RULED OUT** for star colour. He ran the N/B keys. Never suggest that test again.
- **The sprite lens (bit8) is the hero**, not the march.
- **The dilation shear** (`render.metal:624`) is his *"beautiful time warpeyssss"* — a feature.
- **Do not raise the luminance ceiling to chase colour** — that was the 07-26 asinh failure.
- **Contrast floor was tried and REMOVED 2026-07-29 14:19** — his verdict: *"its also as i said a
  sharpness resolution issue not a contrast issue."* The mechanism (uniform |contrast| leaves ~20%
  of the field weakly forced) is real but is NOT what he is seeing. Fully reverted, no residue.
- ⚠️ **VERIFY THE CODE IS LIVE BEFORE DIAGNOSING IT.** Cost three wrong diagnoses in two days: the
  Hz-alpha (dead path), the framebuffer clamp (RGBA16Float already), the uninitialised hardness
  (`pad1` is seeded to 0 at `particles.cpp:344`).
- **Validate numerics offline against ground truth before shipping.** Caught the 0.89-error Bessel
  before it reached him; the same discipline caught a factor-of-2 in the march accel on 07-24.

---

## 10. LIVE STATE

Uncommitted on `b047744`: `particles.metal` (12×9 zeros, Miller evaluator, widened clamps),
`render.metal` + `renderer.mm` + `renderer.h` + `app_state.h` + `main.cpp` (9 star dials,
`[KPROBE]` + `[KPROBE-SCALE]`, bit19 default off, `bCull` 16→7, restored dilation shear).

Deployed bundle **2026-07-29 14:19:39**, verified newer than all sources. Running.

**Build:** `bash package_macos.sh` (never bare `make`) → verify bundle timestamps ≥ source →
`pkill -x SpaceSynth; open -n SpaceSynth.app`.
**Probes (~1/s to stdout):** `[KPROBE]`, `[KPROBE-SCALE]`, `[MARCH]`, `[LUMPROBE]`, `[EIGENMODE]`.
Capture: `script -q <log> ./SpaceSynth.app/Contents/MacOS/SpaceSynth`.
