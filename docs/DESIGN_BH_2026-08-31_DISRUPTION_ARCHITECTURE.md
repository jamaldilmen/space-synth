# TORN, NOT SWALLOWED — the disruption architecture
**Written:** 2026-08-31 18:35:11 · FABLE window · his order via BRAIN: *"no i just want
stuff to behave correct around the bh. like the science stuff said suns near the bh are
like torn into gas the sprites the gartgantua look."*
**Builds on, does not re-derive:** `SEED_CONTINUUM_DESIGN_2026-08-29.md` (the (M, R)
continuum and the grid-constant deletions) · `BH_NEAR_FIELD_AUDIT_2026-08-28.md` (N1–N7
inventory; N2's mass contradiction is a PREREQUISITE here) ·
`SCIENCE_2026-08-31_merger_signatures.md` §2 (the behaviour spec; claims used are cited).
**Relation to the lens:** the lens (`DESIGN_BH_2026-08-31_F1_LENS_IMPLEMENTATION.md`)
bends the light; THIS puts the matter there for it to bend. Lens without this = correctly
bent emptiness. This without the lens = a flat donut. Gargantua is both.
**Every `file:line` re-grepped 2026-08-31 18:35:11.** Design only; OPUS builds, sequenced
by him — nothing here jumps the lens.

---

## 0. THE BEHAVIOUR SPEC, reduced to OUR regime — from the science, checked

1. **There is no gulp case, ever.** `r_t/r_s ∝ M_BH^(−2/3)` and at our reachable masses
   it is 33–106 (science §2.2; the Hills mass for a sun-like star is ~1.14e8 M☉ — five
   decades above anything this sim forms). **Every star+hole contact is a disruption.**
   Capture-as-instant-deletion is wrong in ALL cases, not most.
2. **Two streams.** The star stretches into a bound stream (returns, feeds the disc) and
   an unbound stream (escapes at Δv ≈ √(2Δε); 1186 km/s = 3.96e-3 c for the reference
   case — velocities carry straight into sim units since c = 1). The half/half split is
   the parabolic frozen-in result; hyperbolic encounters (our cluster-dynamics regime)
   unbind MORE than half — **f_bound is a stated model dial with default 0.5, not a fact.**
3. **The hole does not gain the star's mass at contact.** It gains at most the bound
   fraction, later, at the fallback rate — and the fallback law `dM/dt ∝ t^(−5/3)` is not
   to be scripted: it FOLLOWS from a uniform dM/dε plus Kepler (science §3.1). Give the
   debris the right energy spread and the exponent emerges or the design is wrong — that
   is test D3, and it is the same ethos as the sandbox's unnamed life.
4. **The disc forms geometrically at our masses, not relativistically.** Apsidal advance
   is 56 arcsec/orbit — five orders too small to matter; self-collision is unavoidable
   because the whole debris structure is a few stellar radii across (science §2.4).
   **Honest status carried verbatim: disc-formation EFFICIENCY at these masses is a model
   input, not a measurement** (Kremer 2019/2023 is hydro-plus-semi-analytic, the state of
   the art). Our dissipation stand-in is a dial and says so.
5. **The look:** a fast UV/blue flare from the wind photosphere (10⁵–10⁶ K — blue-white
   in `blackbodyRGB` terms, NOT a red fade), then a compact bright disc. That disc is
   what the lens wraps over and under the shadow. This is "the gartgantua look" as a
   causal chain, not a texture.

## 1. THE ROOT CAUSE, restated in one line each — all verified in tree today

- **A body has a mass but no radius.** No `R` field exists anywhere in `src/`; the
  comment at `particles.metal:3747` names `R_star` in a formula the code cannot evaluate.
  Nothing can be TORN — torn means one side pulled harder than the other, and our stars
  have no sides.
- **The honest tidal radius is computed and thrown away**: `particles.metal:1490`
  computes `rt2` from mass and relative velocity; `:1479` clamps it to
  `1.4·cellSize` — and the SAME pattern repeats at `:4153`–`:4155`. 🚨 **Both sites must
  move together** (the audit's clamp-and-scan warning, plus this second clamp the earlier
  docs did not list).
- **Contact adds the whole star to the hole and deletes the victim**
  ([[space_synth_hole_has_no_intake_2026-08-22]] — the teleport-delete). Wrong mass
  bookkeeping AND it deletes the visible event.

## 2. THE ARCHITECTURE — one entity, four states, one ledger

A body is `(M, R, state)`. The states are phases of the SAME matter — no second layer,
no spawned object:

```
STAR ──(pericentre < r_t(R))──► DEBRIS ──(bound, returns)──► DISC ──(falls in)──► HOLE MASS
                                  └─(unbound, Δv > v_esc)──► FIELD (ejecta rejoins the Chladni states)
```

### 2.1 Carrying R — the cost table for HIS call (not chosen here)
`entanglement`'s pads are a lie (all three carry live data — SEED_CONTINUUM §6, still
true at `particles.metal:21`). The options, priced at the 10M pool:

| option | what | cost | risk |
|---|---|---|---|
| A | widen `Particle` by one `float4` (R-factor, state, heat-clock, spare) | +16 B/particle = **+160 MB** | touches the hot struct; every kernel signature; `PhysicsUniforms` untouched but the struct-sync discipline applies |
| B | side buffer `float2` (R-factor, state) indexed by id | **+80 MB**, zero struct change | one extra fetch in the kernels that need it; can land incrementally |
| C | side buffer `float` (R-factor; state packed in sign/exponent bits) | **+40 MB** | bit-packing cleverness — the kind that decays into a trap |

✅ **RULED BY HIM 2026-08-31 (relayed via BRAIN 18:40:49): OPTION B, the float2 side
buffer.** The framing that carried it: B is the reversible choice against two traps — A's
field-order mistake compiles, runs and silently corrupts (the `PhysicsUniforms` class of
trap), C makes one field mean two things (the pattern that has bitten repeatedly).
**S3 designs against B.** Foldable into A later only if it earns it.
⚠️ **Allocation note that surprised the brain and will surprise the builder:** buffers
size to the full 10M SPAWN, not the 2M live — `setActiveParticleCount` clamps the count
without shrinking the allocation. So B really costs 80 MB, not 16 MB.

R's default is the stellar relation (Eker 2018 MLR family —
[[reference_stellar_render_sources]], already the project's verified source); the stored
value is a FACTOR on it, default 1. **R is state that can shrink** — stripping and
collapse move the factor; mass alone never moves compactness (SEED_CONTINUUM §2.1's
table: χ barely moves over five mass decades). This answers BRAIN's kill-the-cheap-fix
constraint by construction.

### 2.2 The disruption event — replaces capture-delete inside r_t
At pericentre passage inside `r_t = R·(M_BH/M_star)^(1/3)` (the formula the comment at
`particles.metal:3747` already states and the code now gets the R to evaluate):

1. The victim CONVERTS, it does not die. Its id becomes the most-bound debris element
   (state = DEBRIS, mass × f_bound / N_b share).
2. **N_debris elements are recruited from the dead pool** via the existing rebirth
   machinery (`imfMassOfId` at `particles.metal:134` / the recycle path) — the same
   mechanism his reversibility feature already uses, pointed at a new purpose. They are
   placed along the two tidal arms with the frozen-in energy spread: bound tail
   ε ∈ (−Δε, 0), unbound tail ε ∈ (0, +Δε), Δε = G·M_BH·R / r_t². Masses sum EXACTLY to
   M_star — conservation is a ledger equality, not a tendency.
3. **The hole gains nothing at this instant.** Bound elements return on their own Kepler
   orbits; each is eaten only when it actually falls back in — so `t^(−5/3)` is emergent
   (test D3). Unbound elements carry escape velocity and REJOIN THE FIELD — the ejecta IS
   field matter again; clause 3's pump-out direction, satisfied by matter as well as
   force.
4. Debris renders hot and stretched: a kelvin boost decaying on a heat clock (the flare —
   blue-white per §0.5, never a red fade) and the existing streak machinery
   (`STREAK_EXPOSURE`, `render.metal:320`, applied at `:1140`) already draws
   motion-stretched sprites along velocity — debris state raises the streak length it already has. No new
   render object. One entity.

⚠️ **Honest limits, stated:** N_debris (8–32) discretizes a stream — the arms are dotted,
not fluid; true circularisation needs dissipation we do not resolve, so DISC state is
entered at a stated efficiency dial per pericentre passage (science §2.4's model-input
status, carried). Neither is hidden behind a physical-sounding name.

### 2.3 The law (§Z), applied to matter
The disc and the hole are ONE budget. Play pumps force out of the hole into the shapes —
under the play-amplitude drain (clause-3 work, OPUS, in progress) the disc population
drains WITH the hole: debris/disc elements revert to FIELD state as the hole un-forms,
by the same withdrawal ledger that revives corpses today. **A disc outliving its hole
violates clause 1 exactly as a lagging shadow did.** At M = 0 every element is field
matter and the frame is the Chladni state — same zero-area limit as the lens region.

## 3. WHAT DIES

| what | where | why |
|---|---|---|
| the grid clamp on reach | `particles.metal:1491` AND `:4155`, with the scan width derived per body | the drain, mechanically (audit N3); both sites or the change plateaus |

🚨 **DO-NOT-FOLD GUARD (BRAIN's find, verified here 18:40:49):** there is a THIRD use of
the same constant — `particles.metal:1620`, `mergeReach = 1.4f * su.cellSize` — and it is
NOT this design's. That one bounds the seed-seed BH MERGE scan, a different mechanism.
Whether it too should derive from something physical is a separate finding for whoever
owns the merge path. **Anyone who greps the constant and "fixes" all three has broken the
merge path in an S3 commit.**
| whole-mass-on-contact accrual | the capture path the clamp feeds | wrong by a factor of a few AND deletes the visible event (science §2.2) |
| the tearing that never renders | comment block at `particles.metal:3747` | its formula becomes real code with a real R; the comment stops being fiction |

## 4. THE KILL TABLE — a real disruption vs. a sprite that fades and respawns

Each can FAIL on a captured frame or a single log. "Current" = today's tree.

| # | Test | Measure | PASS | FAIL | Current |
|---|---|---|---|---|---|
| D1 | **Ledger at contact** | `[GRAV] Mmax` across a disruption event | flat at the event; rises only later as debris returns | step of ≈M_star at contact | **FAIL** (whole-star jump) |
| D2 | **Two arms** | frame at event+Δ: debris point set's major/minor axis ratio; arm directions | ratio ≥ 3; two arms antiparallel within 30°; outbound tip speed > v_esc in the log | isotropic puff, or nothing | **FAIL** (victim vanishes in one frame) |
| D3 | **Emergent −5/3** | log debris-return events, binned; log-log slope over ≥1 decade of t | −5/3 ± 0.3, UNSCRIPTED | flat, exponential, or a coded curve | **FAIL** (no fallback exists) |
| D4 | **Mass-scaled reach** | two runs, different hole masses: disruption radius | ∝ M^(1/3) between runs | identical 1.4-sim reach | **FAIL** (grid constant) |
| D5 | **No teleport** | per-frame ledger: mass leaving STAR state = mass entering DEBRIS state, same frame | equality every frame | any mass skips the debris phase | **FAIL** (defines today) |
| D6 | **A disc, not a shell** | after K disruptions: flattening of near-hole matter about the debris angular-momentum plane | flattening ratio rises with K | isotropic shell | untestable today (no debris) |

D2 and D6 are frame tests on captured screenshots (ffmpeg pipeline, the standing
measurement method); D1/D3/D4/D5 are log tests. **D3 is the deepest: the exponent is not
in the code anywhere — it can only appear if the energy spread and the orbits are real.**

## 5. BUILD ORDER — one verifiable change each, his verdict between. Does NOT jump the lens.

| # | Change | Verified by | Prerequisite |
|---|---|---|---|
| S1 | Ledger probes only — star-out / debris-in / hole-gain per frame, no behaviour change | D5 baseline shows today FAILING, in one log | none — can land any time |
| S2 | Settle the audit's N2 (AMR mass contradiction, 8.16 vs 158,483 M☉) | one probe line; the near field has no fix while two instruments disagree by 4 decades | none |
| S3 | **HIS CALL: the R carrier** (§2.1 table) — then land carrier + its FIRST consumer in ONE change: honest `r_t(R)` with both clamps deleted and scan width derived | D4 across two runs — reach finally scales with mass | his ruling on A/B/C |
| S4 | The disruption event (§2.2): convert + recruit + exact ledger | D1, D2, D5 | S1, S3 |
| S5 | Fallback accrual — the hole eats returning debris only | D3's emergent slope | S4 |
| S6 | Debris render state: heat clock + streak length | his eyes + D2's frame form | S4 |
| S7 | Disc dial + clause-3 drain integration (with OPUS's play-amplitude work) | D6, and the hole+disc dying together under play | S5, OPUS's clause-3 |

**S3 carries the comment-is-not-a-mechanism guard explicitly:** an R buffer with zero
consumers would be the 13-times trap — that is why the carrier and its first consumer are
ONE change, never two.

## 6. OPEN — his rulings and honest unknowns

1. ✅ **The R carrier — RULED: option B** (§2.1, 2026-08-31 via BRAIN).
2. ✅ **f_bound = 0.5 ACCEPTED as default** (BRAIN took the default rather than spending a
   ruling; he was told). Labelled the parabolic assumption — and since hyperbolic
   encounters unbind MORE and are the realistic cluster-dynamics channel, **treat 0.5 as
   an UPPER BOUND on what returns**, never as the expected value.
3. **N_debris** (8–32) — pool pressure vs. stream visibility; interacts with the rebirth
   population his reversibility feature feeds on.
4. ✅ **Disc-entry efficiency ACCEPTED as an explicit dial** carrying the science's status
   verbatim: model input, not measurement. The dial IS the honesty.
   *(Sequencing note on S2/N2, per BRAIN: it is a MEASUREMENT and OPUS holds the token
   mid-lens — the prerequisite stands in the doc, blocks no design work, and BRAIN raises
   it with him after the lens has a first verdict. Nothing here interrupts the lens.)*
5. **Multi-hole**: simultaneous disruptions by two holes share the recycle pool;
   first-come allocation is fine until it visibly is not. Recorded, unruled.
6. **What shrinks R** (collapse law) stays SEED_CONTINUUM's open item — this design
   needs R to EXIST and to be strippable; the collapse continuum is the next tenant of
   the same field, not this job.
7. 🚨 **NEW 2026-09-01 14:02:48 — §2.2 is now REQUIRED, and the r_t compression is the
   open trade.** His disk ruling (*"join the ring as stars and then get torn into gas"*,
   2026-09-01 14:03 via BRAIN) makes the disruption event a requirement of the disk
   design, not a parallel track. AND a correction to §1's first line: a mass-FORMULA
   radius DOES exist and is live (`MERGE_RSUN_SIM·M^0.8`, five sites) — compressed
   39.7× from honest (0.01 vs 0.397 sim/R☉, the 2026-07-08 merge-storm calibration);
   what §1 correctly names as missing is CARRIED, strippable R (the ruled option-B
   buffer). Whether the TEAR uses honest R while star-star merge keeps the calibrated
   compression is put to him in `DESIGN_BH_2026-09-01_DISK_STATE.md` §6.2
   (recommendation there: honest r_t for DISK-BOUND matter only — drift-fed, no
   stochastic rate to storm). Unruled.

---
**Last Updated:** 2026-09-01 14:02:48 — §6.7 added: his disk ruling makes §2.2 REQUIRED;
§1's "no radius" line corrected (mass-formula radius exists, carried R does not); the
r_t compression trade recorded as unruled, put to him in DISK_STATE §6.2.
Previous: 2026-08-31 18:40:49 — folded his ruling (R carrier = option B) and
BRAIN's confirmations: f_bound 0.5 accepted as an UPPER BOUND, disc dial accepted, the
THIRD 1.4·cellSize site (`:1575` mergeReach, NOT this design's) guarded, the 10M-spawn
allocation note added, S2 sequencing recorded (prerequisite stands; nothing interrupts
the lens). First cut 2026-08-31 18:35:11. FABLE owns this file.
