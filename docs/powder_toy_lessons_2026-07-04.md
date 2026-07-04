# What Space Synth Tube can learn from The Powder Toy
**Logged:** 2026-07-04 13:45:00
**Source:** teardown of `/Applications/The Powder Toy.app` (GPL open-source falling-sand reference sim; binary strings match published source) cross-read against Tube's own GPU physics path (`src/render/spatial_hash.metal`, `src/render/particles.metal`, `src/render/renderer.mm`) via a read-only study agent, 2026-07-04.
**Purpose:** TPT has solved the exact class of problem Tube keeps fighting — an emergent matter lifecycle with no scripted phases. This note maps TPT's techniques onto Tube's OPEN problems. No code/IP copied; technique only.

---

## Framing: this is the reverse direction
We first tore down TPT to help the 2D sandbox (`/Users/airy/SANDBOX`). Turning it around: TPT is a mature cellular sim whose update model directly answers Tube's longest-running gaps. TPT is NOT teaching Tube its performance spine — Tube already has that (see "What NOT to learn"). It teaches Tube its **state model**.

---

## Lesson 1 (biggest) — KILL THE GLOBAL PHASE GATE
**Tube's open problem (from memory `space_synth_gas_and_starmap`, `space_synth_tube_play_vs_bh_regime`):** the BH / gravity / lifecycle are keyed to the audio *release phase* — a global switch deciding "now we're in BH mode." Repeatedly flagged as the core cheat: *"BH must be the EMERGENT end-state of stars colliding/mass piling up, NOT a phase-gated switch."*

**What TPT does:** there is **no global phase anywhere** in TPT. Every element always runs its own local rules every tick. Ice→Water→Steam happens only when a *cell's own local* temperature crosses that cell's threshold. The entire simulation is one loop of local threshold rules.

**Lesson:** TPT is the proof-of-existence that a full matter lifecycle can be 100% emergent from per-particle *local* threshold rules with ZERO global phase gating. Remove the release-phase gate; let each particle decide its own state from its own local temp/pressure/density every tick. This is the single highest-value change.

## Lesson 2 — the stellar lifecycle IS TPT's transition table, as data
**What TPT does:** every element is one row in a table with four transition slots:
`LowTemperature→id`, `HighTemperature→id`, `LowPressure→id`, `HighPressure→id`.
Crossing a threshold **replaces the particle's element id** with the next state. Ice/Water/Steam are three separate elements pointing at each other; Iron melts → LAVA; that's it — a data table, not code branches.

**Map onto Tube's gas→star→red giant→supernova→neutron star/BH:** make each matter type a row, transitions point at the next state:
- Hydrogen gas: `HighPressure(> fusion threshold) → fusing star`
- Star: `LowTemp(fuel exhausted) → collapsing core`; `HighPressure → supernova`
- Degenerate core: `HighPressure(> Chandrasekhar-analog) → black hole`

**You already have the primitive:** `merge_stars` (`particles.metal:2139–2270`) already does id-replacement — the eaten particle's id is retired (`mass=0`, parked off-domain), everything downstream gates on `mass>0`. TPT's lesson is to make the *transitions themselves* a data table instead of constants scattered across shaders.

## Lesson 3 — the "POP" = TPT pressure-sensitive detonation
**Tube's open requirement (memory `space_synth_tube_agenda`):** *"collisions must POP into a BH… it needs to pop"*, and supernova bursts; current release is a scripted radial-to-origin move (flagged as a cheat).

**What TPT does:** explosives (NITRO etc.) cross a pressure/heat threshold → convert to a burst state **AND write pressure into the coarse air field** → the shockwave *emerges from the field* propagating to neighbors. The blast is not a scripted radial force; it's the field solver carrying the injected pressure outward.

**Map onto Tube:** you already solve a coarse pressure field (`poisson_sor` `spatial_hash.metal:548–597`, driven `renderer.mm:1399–1427`). The supernova / BH-pop should **inject energy into that existing field** and let the blast propagate through it, replacing the scripted radial release. Same field you already compute.

## Lesson 4 — per-type property struct instead of scattered constants
**What TPT does:** one struct per element: `Weight, HeatConduct, State, Flammable, Explosive, Meltable, Hardness, Diffusion, HotAir, + 4 transitions`. All tuning lives in a table.

**Map onto Tube:** give each matter type (hydrogen, plasma, degenerate matter, iron core, ejecta gas) a property row — mass scale, conduction, radiative-cooling rate, the transition thresholds — instead of hardcoded magic numbers in `particles.metal`. Makes the lifecycle tunable and readable, and is where the transition slots (Lesson 2) live.

## Lesson 5 — pressure/density as a first-class TRANSITION trigger
**What TPT does:** LowPressure/HighPressure transitions are as fundamental as temperature ones (gas condenses under pressure; nitro detonates).

**Map onto Tube:** collapse→BH is fundamentally a *density/pressure threshold crossing*, not a mass cutoff (consistent with our verified physics canon: BH is GEOMETRIC — density, not mass). You already compute per-cell density (`cellCounts`) and the Poisson field. Trigger the state flip off the local density/pressure field crossing a threshold.

---

## Ranked
| Lesson from TPT | Tube open problem it fixes | Effort |
|---|---|---|
| 1. No global phase gate — all transitions local | BH/lifecycle keyed to audio release phase (the core cheat) | design shift, medium |
| 2. Transition table (threshold → new id) | scripted phase switches; scattered lifecycle constants | medium (have `merge_stars` primitive) |
| 3. Detonation = threshold → inject into pressure field | "must POP"; scripted radial supernova | medium (have Poisson field) |
| 4. Per-type property struct | hardcoded constants in shaders | low–medium |
| 5. Density/pressure as first-class transition trigger | collapse→BH really a density threshold | low (density field exists) |

## What NOT to learn from TPT (Tube already has it — convergent, not a gap)
- Two grids at two resolutions → Tube has counting-sort spatial hash (`spatial_hash.metal:27–330`) + coarse Poisson field.
- Coarse field relaxation → Tube uses **red-black SOR** (ω=1.9), warm-started — already better than TPT's plain Jacobi air grid.
- Fixed timestep → already pinned (`renderer.mm:763`), and that pin was the root-cause fix for the energy-pump blow-up.
- Active/sleeping cells → Tube gates dispatch (`renderer.mm:1147`, slow-clock `:1431`, `playGate`).

## Bottom line
TPT's gift to Tube is its **STATE MODEL**, not its engine: represent every matter type as a table row with local temp/pressure/density threshold transitions, delete the global phase gate, and let the whole stellar lifecycle — including the BH pop — emerge from local rules feeding the pressure field you already solve.
