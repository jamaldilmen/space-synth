# THE DISK — matter FORMS it, HOLDS it, ORBITS
**His order 2026-09-01 01:37:** *"fable designs the disk. matter forms it, holds it, orbits"* —
the three verbs are the acceptance criteria and this doc's structure.
**Written:** 2026-09-01 01:42:30 · **Reworked to the ordered deliverable:** 2026-09-01 01:52:40 ·
**Citations re-verified against the tree:** 2026-09-01 13:26:40 (three drifts corrected: V_ISCO_C :248→:246, cooling :2355→:896/:1192, withdrawal :3781→:3543) · FABLE ·
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
  a per-frame CAS budget in the seed-merge path (`:1484-1505`). ≈2517 M☉/wall-s; its own
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
the SAME particle, a state flag, nothing bolted on (his one-entity law). Flag storage with
zero layout risk: `entanglement.z` is a declared pad (`particles.metal:21`, uint4 .y/.z/.w
pads) — no struct reshape anywhere near the unguarded `PhysicsUniforms`.

The settling physics already exists and already works: density-gated, spin-preserving
circularization (`:2340-2397`) damps radial infall at the free-fall timescale — *"the disk
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
(`:1131`, banner `:1236-1250`) teleports it home at mass 0 the next frame. Matter waits
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
   dropping ~7.5×, T dropping ~55×. Radiative cooling exists in the kernel (`coolMul` at `:896-897`; the live "gentle
   radiative cooling as the field collapses" site at `:1192` — currently far too slow to
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
only, tangential untouched — the code's own rule at `:2371-2377`, which also records that an
L-destroying drag was tried and REVERTED). ⛔ No F_LTRANS. L-walls quantizing matter into
rings — the standing STARS-NOT-TRAILS root cause — points the right way here for once:
rings around the hole ARE disc structure; the design leaves L-walls untouched and says so.

**How he SEES it:** a persistent bright ring that survives minutes of silence, drains
visibly inward, and empties into the shapes when he plays.

## 3. ORBITS — why it moves like the picture

**Mechanism.** Disk-bound matter orbits at REAL circular velocity for its radius — not pose
playback, not a time-lapse: v_φ(r) up to 0.41c at the ISCO is fast enough to SEE. The
differential rotation is Keplerian by construction; the inner edge laps the outer visibly.

**Heat and colour are free:** `unifiedKelvin`'s ke term reads |v|² (`render.metal:1583`),
so the inner disc goes blue-white and the outer stays red by the shipped one-law — no new
colour path. **Doppler beaming is free:** the shipped beaming law acts on the drawn
velocities; BH2's one-line Ω unification (`render.metal:1428` → `poseOmegaEff`) stops being
cosmetic and becomes the disc's brightness asymmetry — reference feature 2, machinery
already in the tree, waiting for real orbits to act on.

🚨 **PLANE HAZARD — verify FIRST, before any disk code (his decision #4).**
⛔ **CONFIRMED AND WIDENED BY BRAIN 2026-09-01 01:40:15 (§Z14): it is a WHOLE-FILE
CONVENTION SPLIT with THREE axes, not one site.** The physics orbits about **+Y** at four
independent sites (`particles.metal:2380` `tdir=(-pz,0,px)`, `:1210` re-entry "Kepler about
+Y", `:2371`, `:3290` star-map rotation); the sprite/playback side orbits about **+Z** at
three (`render.metal:1445`, `:3203`, `:761`); and the deleted-march-era `poseAxis()`
(`render.metal:570`, kept by `:3463`'s consumer per `:755-762`'s own "STILL SPLIT" note) is
a THIRD convention. **The consequence that would fake the disk on arrival:** circularization
settles matter into the XZ plane, while the Kerr Ω Doppler (`render.metal:1428`) computes
its tangent in XY — the beaming asymmetry, the ONE reference feature we already own, would
be applied 90° away from the actual orbital motion. On the wrong axis real physics actively
looks wrong — the plane trap's signature, 4th sighting. **Settle which convention is
correct by what is ON SCREEN, not by which comment is better written** (BRAIN's gate,
adopted). This also corrects my own TODO audit: BH2's "tangent half RESOLVED — both orbit
Z" was true of the two RENDER laws only; the physics runs a third convention the audit missed.

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
3. **The +Y/+Z plane question** may invalidate my reading of which components the
   relaxation preserves — it is ordered first for exactly that reason.
4. **h/r after cooling is emergent, not set:** 0.1 is the target via the cooling rate, not
   a constant we write — so the MDOT coupling must read the LIVE h/r (currently a baked
   constant at `:245`) or the rate and the geometry drift apart. That is a real
   implementation seam and is named here so it is costed, not discovered.

## 5. HIS DECISIONS

1. Disk-capture radius law (recommend: the relaxation-bind radius).
2. Silence lifetime / α (thin-disc default lands at ~3.7 h; α is the honest dial).
3. In-disk star–star merging (recommend OFF).
4. Plane verification ordered before any code.
5. The cooling-rate law for the disk state (the one new physics — his taste, my derivation).

**No code was written for this design. Last Updated: 2026-09-01 01:52:40.**
