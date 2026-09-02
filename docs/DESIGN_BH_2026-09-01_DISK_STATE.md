# THE DISK — matter FORMS it, HOLDS it, ORBITS
**His order 2026-09-01 01:37:** *"fable designs the disk. matter forms it, holds it, orbits"* —
the three verbs are the acceptance criteria and this doc's structure.
**Written:** 2026-09-01 01:42:30 · **Reworked to the ordered deliverable:** 2026-09-01 01:52:40 ·
**Citations re-anchored after the session's code landed:** 2026-09-02 09:41:00 (line drift from the six built changes; OPUS's catch) · previous re-verify 2026-09-01 13:26:40 (three drifts corrected: V_ISCO_C :248→:246, cooling :2355→:896/:1192, withdrawal :3781→:3543) · FABLE ·
**DESIGN ONLY — his ruling gates every line of code.**
Companions: `BOARD_BLACKHOLE.md` §Z12/§Z12b/§Z12c. Every `file:line` verified in tonight's tree.

## 0. THE REFRAME THAT GOVERNS EVERYTHING

His correction (01:33): **the reference image has a BLACK background.** Nothing sits behind
the hole. Far-side arch, underside ring, photon ring, Doppler crescent — all of it is THE
DISK, lensed. Tonight's transport machinery was never short of physics; it was short of a
subject. Of the six reference features (§Z12c) we ship the shadow alone; features 1–5 all
need the disk to exist first.

**The two constants that ARE his complaint, both live in the tree:**
- `MDOT_MSUN_PER_WALLSEC` (`particles.metal:244-260`): the viscous eat ceiling, consumed as
  a per-frame CAS budget in the seed-merge path (`:1497-1544`). ≈2517 M☉/wall-s; its own
  comment predicts "whole field in ≈3.9 minutes" — §Z8 measured 95% in 4 idle minutes. The
  measurement confirms the constant. **His clause 3 IS this number.** ⭐ Its design property
  that must survive: M cancels — growth is linear, no M² runaway, no clamp. None is reintroduced below.
- `DISK_H_OVER_R = 0.746` (`:245`, "MEASURED, not chosen"): **our disc is a geometrically
  thick torus, not the reference's thin ring** (real thin discs: h/r ≈ 0.01–0.1). h/r = c_s/v_φ —
  the disc is thick because the matter is HOT (c_s ≈ 0.31c inner). The source's own words:
  "our anchor Sgr A* is a RIAF, not a thin disc." The reference image is the other kind.
  **His clause 2 — "nothing turns into that state of matter" — is largely THIS.**

## 1. FORMS — how matter gets into the disk

**Mechanism.** A live particle crossing the disk-capture radius transitions to DISK-BOUND —
the SAME particle, a state flag, nothing bolted on (his one-entity law). ⛔ **STORAGE
CORRECTED 2026-09-01 (build-time find): `entanglement`'s "pads" all carry live data**
(.y hardness bits, .z star-map theta + bond id, .w aphi — DISRUPTION §2.1 was right, this
paragraph was wrong). **AS BUILT the flag lives in `spinW.y`** — spawn zeroes it
(`particles.cpp:342`), its only other reader is the off-by-default bit-1 Biot-Savart
debug; zero struct reshape, `PhysicsUniforms` untouched.

The settling physics already exists and already works: density-gated, spin-preserving
circularization (`:2384-2441`) damps radial infall at the free-fall timescale — *"the disk
circularizes and BINDS at the core instead of bouncing… a settling DISK, not a ball"* — and
Chandrasekhar friction sinks heavy bodies to the core. FORMS is not new physics; it is
making the state the settling produces EXPLICIT and PROTECTED instead of immediately edible.

**The capture-radius law is his decision #1** (candidates, each one line): the radius where
the existing relaxation wins (self-consistent, my recommendation), a fixed multiple of r_s,
or the tidal radius. ⚠️ A BODY HAS A MASS BUT NO RADIUS — this is a new size-like constant
and is named as such, not borrowed silently.

**How he SEES it:** infalling streams stop vanishing at the capture radius and visibly pile
into a ring; the "toilet drain into nothing" becomes a drain into something that shines.

## 2. HOLDS — why the disk persists instead of being eaten

**The defect today is not the rate — it is the invisible queue.** Consumption evacuates:
a victim goes to mass 0, parks at slot 4000+id%1024 (r≈6928), and ESCAPER RECYCLE
(`:1216`, banner `:1248-1262`) teleports it home at mass 0 the next frame. Matter waits
its turn OFF-SCREEN. Our hole consumes; a real one accretes.

**Mechanism, three parts:**
1. **Exemption:** disk-bound particles are immune to capture and star–star merge. Their
   only inward path is the viscous drift; their only death is the ISCO (`V_ISCO_C = √(1/6)`,
   `:246`), where they are eaten against the SAME CAS budget as today. Consumption becomes
   accretion: every solar mass spends its wait on screen. In-disk merging OFF is my
   recommendation (his decision #3) — the disk is a light-emitting queue, and merging inside
   it re-opens the runaway class.
2. **The state of matter = the COOLED state.** To become the reference's thin ring, the
   disk-bound population must cool: h/r = c_s/v_φ, so h/r 0.746 → 0.1 means c_s (∝√T)
   dropping ~7.5×, T dropping ~55×. Radiative cooling exists in the kernel (`coolMul` at `:909-910`; the live "gentle
   radiative cooling as the field collapses" site at `:1206` — currently far too slow to
   ever thin anything; the old board figure ":2355, ~0.0025/s" is a STALE line number).
   The disk state gets an efficient cooling rate — which is not a cheat, it is the physical
   DEFINITION of a thin disc (radiatively efficient) vs a RIAF (inefficient). We are choosing
   to model the reference's kind of disc. Stated honestly: the real Sgr A* is the other kind.
3. **THE COUPLING, worked not hidden (BRAIN's warning):** h/r is SQUARED in MDOT. Thinning
   0.746 → 0.1 cuts the accretion ceiling ×55.7: field lifetime under silence goes ~4 min →
   **~3.7 hours**. ⭐ The trade cuts the RIGHT way — his clause 3 ("doesn't just eat
   everything up") falls out of the same change that makes the disc look right, with no cap
   and no ease; mass-independence survives (M still cancels). **But it is a real trade on
   the OTHER side:** hole growth slows ×55 too, so "BH FORMED → big hole" stretches from
   minutes toward hours unless the pre-disk (free-fall) phase feeds the seed first. The
   staging answers this: matter NOT yet disk-bound still merges/feeds as today, so early
   growth is unchanged; the slow-down applies only once a disc exists — which is exactly
   the reference's regime. If he wants faster, `SS_ALPHA` (0.1) is the one honest dial and
   his rest-rate verdict plugs in here (his decision #2).

**Reversibility / the 16:33 law (BH and Chladni exclusive; play pumps out of the hole):**
the disk DISSOLVES under play — rebirth withdrawal (`renderer.mm:3543-3545`, the seed_apply banner: "Sustain rebirth now
WITHDRAWS mass from the hole"; ledger print at `:3925`) draws
from the disk population FIRST, ledger second. Matter visibly leaves the ring into the
Chladni shapes and reforms when he stops. The disk is a REST structure inside the law, not
an object bolted on beside it. A shrinking hole under play stays his feature.

**Angular momentum:** entry keeps each particle's L (circularization damps radial/vertical
only, tangential untouched — the code's own rule at `:2415-2421`, which also records that an
L-destroying drag was tried and REVERTED). ⛔ No F_LTRANS. L-walls quantizing matter into
rings — the standing STARS-NOT-TRAILS root cause — points the right way here for once:
rings around the hole ARE disc structure; the design leaves L-walls untouched and says so.

**How he SEES it:** a persistent bright ring that survives minutes of silence, drains
visibly inward, and empties into the shapes when he plays.

## 3. ORBITS — why it moves like the picture

**Mechanism.** Disk-bound matter orbits at REAL circular velocity for its radius — not pose
playback, not a time-lapse: v_φ(r) up to 0.41c at the ISCO is fast enough to SEE. The
differential rotation is Keplerian by construction; the inner edge laps the outer visibly.

**Heat and colour are free:** `unifiedKelvin`'s ke term reads |v|² (`render.metal:1606`),
so the inner disc goes blue-white and the outer stays red by the shipped one-law — no new
colour path. **Doppler beaming is free:** the shipped beaming law acts on the drawn
velocities; BH2's one-line Ω unification (`render.metal:1450` → `poseOmegaEff`) stops being
cosmetic and becomes the disc's brightness asymmetry — reference feature 2, machinery
already in the tree, waiting for real orbits to act on.

✅ **PLANE VERDICT — MEASURED 2026-09-01 (OPUS), decision #4's verification is IN.
The matter is in the XY plane, normal +Z, tilt ≤ 7.9° — the RENDERER's convention is
the correct one. The disk is designed in XY about +Z.** Three independent paths agree:
world-space `[DISKZ]` (`main.cpp:3042-3048`, camera-free: collapsed shells r≈2–14 at
H/R 0.10–0.25 and flattening through the run, the r≈32 halo spherical at 0.69);
source (spawn writes XY-flat-in-Z at `particles.cpp:163-165`, orbit launched about +Z
at `:258-262`); and screen (circular-aperture sx/sy 1.03–1.34, principal angle
wandering — isotropic = face-on). Citations re-verified in this tree 2026-09-01 13:52:42.
**Consequence for the build:** entry circularization targets XY/+Z. The +Y side is
**THREE executable mechanisms, not four sites** (`:2371` and `:1210` are comments inside/
above them — corrected by OPUS 2026-09-01, gates verified in this tree 2026-09-01 13:55:23):
1. `particles.metal:2426` `tdir=(-pz,0,px)` — REST-ONLY (its relax term at `:2403`
   carries `×(1−playGate)`). **The only one live in any measurement taken**, and the only
   one measurement contradicts: matter flattens about +Z despite it.
2. `particles.metal:3329-3331` star-map rotation about +Y — PLAY-ONLY (inside
   `if (u.totalAmplitude > 0.005f)`, `:3353`). UNTESTED — never ran in the rest-only
   measurements; saying anything about it needs a play-mode measurement. ⛔ Its comment
   `:3326` "matches the spawn velocity in particles.cpp" is FALSE (spawn orbits +Z) —
   same false claim as `:1210`'s "same as spawn". A comment is not a mechanism.
3. `particles.metal:1228-1231` escaper re-entry Kepler about +Y — fires only at
   `r_curr > 1000` (`:1216`); [GRAV] shows maxR ≈ 60 all run, so it plausibly never fired.
Disk code must not inherit any of the three; their conversion is scoped with the entry
work, with #1 the only one evidence convicts today. `poseAxis()` (`render.metal:570`,
consumer at `:3463`) remains a separate convention to retire, not follow.

🚨 **BEAMING IS ZERO AT THE DEFAULT CAMERA — measured and exact (OPUS 2026-09-01), and it
amends this section's "Doppler beaming is free" claim.** The default camera sits ON the
+Z axis at world (0,0,800) (`camera.h:126,192-194`); for any particle orbiting in XY the
line-of-sight is radial in-plane, the orbit is tangential, and `vLos = dot(vOrbit, toCam)`
(`render.metal:1475-1476`) is IDENTICALLY zero — every particle, every radius, no constant
tunes it away. (Same geometry as the standing FACE-ON vLos IS ZERO finding, 2026-08-27.)
vLos ∝ (x·camY − y·camX) generally, so the asymmetry wakes only when the camera leaves the
Z axis. **Design consequence:** the beaming machinery stays as specified — it is correct
and free — but reference feature 2 (the bright approaching limb) appears only from an
INCLINED camera. The launch view shows a symmetric ring; the Doppler crescent is a camera
position, not a tuning target. Never tune beaming constants against a face-on frame.

**How he SEES it:** the ring turns — inner fast, outer slow — with the bright side the
Doppler law makes, and the far-side arch/underside/photon ring become reachable: tonight's
validated marcher terminates on THIS disc (the subject it lacked), winding light it finally
has. Six-feature scorecard after the disk: 1 (disk) this design; 2 (beaming) shipped law +
BH2 fix; 3-4 (far-side/underside) marcher + disc; 5 (photon ring) marcher winding, n≥2 cap
his call; 6 (shadow) already ships.

## 4. WHAT I AM UNSURE OF, stated plainly

1. **The cooling rate for the disk state is a NEW law** — the one genuinely new physics in
   this design. Everything else is staging of existing machinery. Its value sets how fast a
   torus visibly flattens into the ring; I have no measured basis for it yet and will not
   pretend one.
2. **The thin disc slows hole growth ×55** once the disc regime dominates (worked above).
   If his taste wants both the thin look AND fast growth, those are physically in tension in
   α-disc theory itself; the honest dial is α, not a cap.
3. ✅ **The +Y/+Z plane question is ANSWERED** (OPUS measurement 2026-09-01, §3): XY about
   +Z, tilt ≤ 7.9°. The residual unknown is NARROW (gates verified, §3): only the
   rest-only `:2426` is contradicted by measurement — WHY matter flattens about +Z
   despite it (weak path vs fought-and-lost) is unmeasured. The play-only `:3329` is
   UNTESTED (needs a play-mode measurement), and the escaper-only `:1229` plausibly
   never fired (maxR ≈ 60 all run vs its r > 1000 gate).
4. **h/r after cooling is emergent, not set:** 0.1 is the target via the cooling rate, not
   a constant we write — so the MDOT coupling must read the LIVE h/r (currently a baked
   constant at `:245`) or the rate and the geometry drift apart. That is a real
   implementation seam and is named here so it is costed, not discovered.

## 5. HIS DECISIONS — ✅ ALL FIVE RULED 2026-09-01 14:03 (relayed by BRAIN, his words quoted). §6 carries the reconciliation.

1. Disk-capture radius law (recommend: the relaxation-bind radius).
   **Ruled on the ROOT:** *"yeah if nothing has a radius we need to change that musnt
   we?!"* — bodies get radii (the option-B carrier, already ruled 2026-08-31,
   DISRUPTION_ARCHITECTURE §2.1). ⚠️ The capture LAW itself is the one choice still
   open — see §6.1: the existing tidal radius does NOT answer it; relaxation-bind
   recommendation stands.
2. Silence lifetime / α — **RULED: LONGER.** *"the ring lives bro. longer than now at
   least."* Take the thinning (h/r 0.746 → 0.1, ≈2.8 h window); α UNCHANGED at 0.1 —
   he did not ask for the dial, so it is not spent. The derived #5 cooling law rides
   the same α.
3. In-disk star–star merging — **RULED OFF, with the replacement named:** *"i want it
   to join the ring as stars and then get torn into gas. not stars eating stars
   orbiting the black hole thats not what we want."* ⭐ The star→gas TEAR is now a
   REQUIREMENT of this design, not an option — it is DISRUPTION_ARCHITECTURE §2.2,
   verbatim. See §6.
4. Plane verification ordered before any code — ✅ **measurement IN 2026-09-01 (OPUS): XY
   about +Z, ≤7.9° tilt, three independent instruments agree (§3).** His ruling still
   gates the code that acts on it.
5. The cooling-rate law for the disk state — **now DERIVED, no new tuned constant:**
   dT/dt = −α·Ω_K(r)·T (Shakura–Sunyaev thermal timescale t_th = 1/(α·Ω), the same α-disc
   framework MDOT's own derivation uses at `particles.metal:249-251`). All inputs live in
   the tree (`SS_ALPHA` :244, `KRS_SIM_PER_MSUN` :247, `u.bhMass` :88). **#5 collapses
   into #2: α is the one dial for both silence lifetime and cooling speed.** Flatten time
   ≈ 4·t_th(r) (T must drop 55.7× = 4 e-folds): ms at the ISCO, ~1.4 s at 100·r_s for the
   50 M☉ seed — inside-out, like a real disc. Stated caveats: M does NOT cancel here
   (t_th ∝ 1/√M at fixed r — a bigger hole cools its disc faster; physics, not a defect),
   and the law must be dt-based — the existing cooling site `:1206` is a per-frame
   multiply and is not a form to copy. Validation when built: SS_DUMP world positions →
   inertia tensor → minor principal axis as empirical disc normal (plane-agnostic) →
   h/r e-fold fit vs predicted 2/(α·Ω), 4+ stacked runs.

**Decision #2's anchor is now MEASURED (BRAIN 2026-09-01): the face-on ring exists at
t≈3 min of silence and is GONE by t=300 s — third consistent number against the same
constant (MDOT's own ≈3.9-min comment at `:258`; §Z8's 95%-in-4-min). The trade for his
ruling: today's thick disc gives a ≈3-minute ring window; thinning h/r 0.746→0.1 alone
(MDOT ∝ (h/r)²) stretches it to ≈2.8 hours at unchanged α; window ≈ 3 min × 55.7 ×
(0.1/α) maps every α to a silence-window length he can judge against the set.**

## 6. RECONCILIATION WITH DISRUPTION_ARCHITECTURE — after his rulings (2026-09-01 14:02:48)

**One entity, restated by him unprompted with the rulings:** *"it should live as the
entity as one black hole not in parts. u know."* Governs everything below.

### 6.1 The tidal radius does NOT answer the capture radius — his sentence has TWO transitions
*"join the ring as stars* **[transition 1: free star → DISK-BOUND star, the capture
radius — THIS doc's #1]** *and then get torn into gas"* **[transition 2: disk-bound star
→ gas, the tidal radius — DISRUPTION §2.2]**. The existing `r_t` (`particles.metal:
1478-1479`, textbook R·(M_bh/M_star)^(1/3), live but compressed and then clamped away at
`:1491-1492`) answers transition 2. It cannot be the capture radius: at the 50 M☉ seed,
even HONEST r_t is 2.19 sim — the inner edge of the measured ring (shells r≈2–14,
[DISKZ]) — and compressed r_t is 0.055; capture there would leave essentially nothing
disk-bound and no ring state at all. The tidal-radius CANDIDATE in #1's menu is hereby
reassigned to the tear; the capture law still needs one choice and the recommendation
stays relaxation-bind (the radius where the `:2403` relaxation already wins — self-
consistent, no new tuned constant). Correction absorbed from BRAIN: "a body has a mass
but no radius" was imprecise — a mass-FORMULA radius exists and is live at five sites
(`MERGE_RSUN_SIM·M^0.8`, exactly what the standing memory said: every size substitutes a
mass formula); what does not exist is carriable, strippable per-particle R — that is the
ruled option-B carrier.

### 6.2 The compression trade — HIS CALL, not decided here
`MERGE_RSUN_SIM = 0.01` vs honest 0.397 sim/R☉ = **39.7× compressed**, calibrated
2026-07-08 against the launch merge storm (his verdict in the banner `:201-211`: *"open
it. star map. period. slow progression on mergers"*). That compression compensates a
STOCHASTIC ENCOUNTER RATE in a cluster drawn ~1e5× denser than real. **The disk tear has
no such rate to compensate:** disk-bound stars reach r_t by orderly viscous drift — the
tear rate is set by MDOT, not by cross-section — so applying the compensation there
misplaces the tear ×40 with no offsetting benefit. What each choice looks like (1 M☉
star; ISCO = 3·r_s):

| r_t regime | 50 M☉ seed | 10⁵ M☉ grown (ISCO 0.505) | on screen |
|---|---|---|---|
| compressed (0.01) | 0.055 | 0.696 | gas band is a SLIVER (0.70→0.51); ring nearly all stars; tear almost invisible |
| honest (0.397) | 2.19 | 27.6 | broad gas disc between tear line and ISCO — the visible "torn into gas" band his ruling asks to SEE |

Options put to him: **(a) RECOMMENDED — honest r_t for DISK-BOUND stars only** (drift-fed,
no stochastic rate to storm), compressed capture unchanged for free-field plungers — the
state flag is exactly the gate, so it is a split by STATE, stated in code as two laws,
not a silent fudge; **(b) honest everywhere** — re-opens the ~1600× cross-section storm
risk on the free-field capture path the 2026-07-08 calibration exists to prevent;
**(c) compressed everywhere** — no rate risk, but the tear happens nearly at the ISCO
and the gas phase is barely visible. Honest framing: (a) REMOVES an inapplicable
correction rather than adding a new one — but it is his call.

### 6.3 Gas is a STATE, confirmed — with one seam named
The tear complies with the one-entity law by construction: the victim CONVERTS in place
(state change on the SAME particle — DISRUPTION §2.2 step 1; "no second layer, no
spawned object" is that doc's own §2 header). This doc's DISK-GAS is the same state
DISRUPTION calls DEBRIS/DISC — one ladder: FREE → DISK-BOUND (star) → GAS (torn) → eaten
at ISCO, flags in the option-B carrier + `entanglement.z` pad. **Seam stated plainly:**
§2.2 step 2 additionally recruits N_debris dead-pool particles to shape the two tidal
arms — existing particles changing state via the rebirth machinery his reversibility
already uses, mass ledgered exactly to M_star; no allocation, no new object class. Read
here as compliant with "not in parts" (states of existing matter), but NAMED so it can
be put to him if he meant it stricter — the fallback is victim-converts-alone: simpler,
one gas particle per star, dimmer arms.

### 6.4 Smallest first verifiable change (recommendation — NOTHING authorised)
**The DISK-BOUND flag + consumption exemption, alone.** No cooling, no tear, no
thinning yet: flag matter inside the capture radius, exempt it from the eat path. One
change; verified by re-running BRAIN's rest measurement — the ring that today is GONE by
t = 300 s (radial profile flat, azimuthal 1.79) is PRESENT (peaked profile) at t = 300 s.
His ruled outcome ("the ring lives") is the literal pass criterion, on an instrument
that already exists and already measured the failing baseline today. Everything else
(thinning, cooling, tear, drain-to-ISCO) stacks on that verdict one change at a time,
per the DISRUPTION §5 ladder (S1 ledger probes remain the smallest for the TEAR side).

**No code was written for this design. Last Updated: 2026-09-01 14:02:48.**
