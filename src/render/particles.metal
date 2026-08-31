#include <metal_stdlib>
using namespace metal;

// Decode the packed phase out of velW.w (band ID lives in the upper 3 bits).
// velW.w holds as_type<float>((bandBits<<29)|phaseBits) — a reinterpreted int,
// NOT a usable float. Reading it directly as a float is garbage. This is the
// inverse of the pack at the end of compute_physics and mirrors
// render.metal::decodePhaseAndBand so producer and consumer stay in sync.
static inline float decodePhase(float packed) {
    uint bits = as_type<uint>(packed);
    uint phaseBits = bits & 0x1FFFFFFFu;
    return ((float)phaseBits / (float)0x1FFFFFFFu) * (2.0f * M_PI_F) - M_PI_F;
}

// GPU particle state — matches GPUParticle struct in C++ (80 bytes)
struct Particle {
    float4 posW;   // x, y, z, mass
    float4 velW;   // vx, vy, vz, phase
    float4 prevW;  // prevX, prevY, prevZ, temperature
    float4 spinW;  // spinX, spinY, spinZ, charge
    uint4 entanglement; // x: entangledIndex, y: pad1, z: pad2, w: pad3
};

// HOT SORTED RECORD — must match spatial_hash.metal (scatter writes it).
struct SortedHot {
    float4 posW;
    float4 prevW;
    uint4  entanglement; // .y = origin id
};

struct VoiceData {
    int m;
    int n;
    float alpha;
    float amplitude;
    float emitterX;
    float emitterY;
    float emitterZ;
    float frequency;
    float deltaAmp;
    float phase;
    int bandGroup;
    float padding;
};

struct PhysicsUniforms {
    float dt;                   // 0
    float totalAmplitude;       // 4
    int voiceCount;             // 8
    int particleCount;          // 12
    float maxWaveDepth;         // 16
    float plateRadius;          // 20
    float jitterFactor;         // 24
    float speedCap;             // 28
    uint frameCounter;          // 32
    float symmetryBreakImpulse; // 36
    float collisionRadius;      // 40
    int collisionsOn;           // 44
    float uncertaintyStrength;  // 48
    float eFieldStiffness;      // 52
    float bFieldCirculation;    // 56
    float time;                 // 60
    float gravityConstant;      // 64
    float stringStiffness;      // 68
    float restLength;           // 72
    uint debugFlags;            // 76

    // ═══ BLACK HOLE LIFECYCLE (Phase 17) ═══
    float envelopePhase;         // 80: 0=silence, 1=attack, 2=decay, 3=sustain, 4=release
    float envelopeProgress;      // 84: 0.0→1.0 within current phase
    float lifecycleIntensity;    // 88: master intensity multiplier
    float massTotal;             // 92: Σ stellar mass of the field, M_sun
    float diskThickness;         // 96: accretion-disk vertical thickness (UI)
    float spinX;                 // 100: user spin torque around X axis (rad/s)
    float spinY;                 // 104: user spin torque around Y axis (rad/s)
    float bondNetworkOn;         // 108: >0.5 = bond-find nearest neighbour in sustain

    // ═══ SELF-GRAVITY (emergent BH, Step 1) ═══
    float comX;                  // 112: live-mass centre of mass (reduce_stats, 1-frame lag)
    float comY;                  // 116
    float comZ;                  // 120
    float gravGM;                // 124: G_sim·M_total — 0 disables self-gravity

    // ═══ EMERGENT-BH SIGNAL (Step 2) ═══
    float bhX;                   // 128: densest-region position (1-frame lag)
    float bhY;                   // 132
    float bhZ;                   // 136
    float bhMass;                // 140: stars enclosed within R_ENC of bh pos
    float horizonR;              // 144: honest geometric horizon r_h (0 = no hole)
    float dtPrev;                // 148: previous frame's dt → time-corrected Verlet (framerate-independent orbits)
    float centerGM;              // 152: GM of the hard-coded central SMBH (Sgr A*) the cluster orbits
    uint bhToggles;              // 156: BH-mechanism on/off bitmask (UI). Bits:
                                 //  0 field self-gravity, 1 central SMBH,
                                 //  2 seed capture, 3 seed↔seed merge,
                                 //  4 origin-pin, 5 relaxation, 6 resurrection
    float uAmbient;              // 160: live substrate mean u → display ambient
    float fieldMassMsun;         // 164: Σ stellar mass, UNSCALED M_sun. massTotal
                                 //  above is the GRAVITY anchor (×massScale from
                                 //  the Size slider) — never use it as the books.
};

struct SpatialHashUniforms {
    int gridSize;
    int particleCount;
    float cellSize;
    float invCellSize;
    int gridSizeZ;
    float halfExtent;   // particle field half-extent in sim coords
};

// (Removed Bessel functions - no longer used)

// Physical Constants
#ifndef TWO_PI
#define TWO_PI 6.283185307f
#endif

// Temporal noise — hash uses frame counter for proper Brownian motion
static float noise(uint id, uint frame) {
    uint x = (id * 1103515245u + 12345u) ^ (frame * 2654435761u);
    x ^= x >> 16;
    x *= 0x45d9f3bu;
    x ^= x >> 16;
    return (float(x & 0x7FFFu) / 32767.0f) - 0.5f;
}

// EXACT MSL MIRROR of core/imf.h::massOfId — same hash, same inverse-CDF, same
// float math. The spawn (core/particles.cpp packForGPU) writes massOfId(i) into
// posW.w at buffer index i, and particles NEVER change slots (a merger parks the
// loser at its own index), so the thread id IS the id that drew this mass. That
// makes the spawn mass field RECOVERABLE at any time — which is what lets a
// reset actually destroy an accreted black hole instead of only moving it.
// 🚨 Change this and you MUST change core/imf.h identically (physics_constants.h).
static inline float imfMassOfId(uint id) {
    uint h = id * 2654435761u;
    h ^= h >> 15;
    h *= 0x2c1b3c6du;
    h ^= h >> 12;
    float u01 = (float)(h & 0xFFFFFFu) / (float)0xFFFFFF;
    const float aI = pow(0.08f, -1.3f);
    const float bI = pow(50.0f, -1.3f);
    return pow(aI + u01 * (bI - aI), 1.0f / -1.3f);
}

// Bit-level non-finite test (exponent all-ones ⇒ inf or NaN). Metal compiles
// with fast-math, which makes isnan()/isinf() unreliable — integer bits don't
// lie and can't be optimized away.
static bool notFinite3(float3 v) {
    uint3 b = as_type<uint3>(v);
    return any(((b >> 23) & 0x000000FFu) == 0x000000FFu);
}
static bool notFinite1(float v) {
    uint b = as_type<uint>(v);
    return ((b >> 23) & 0x000000FFu) == 0x000000FFu;
}

// Collision constants
constant int MAX_PER_CELL = 128; // Read-site SCAN clamp only: bounds the
                                  // neighbor-loop iteration count so a hot
                                  // cell can't stall the GPU. cellCounts
                                  // itself is UNCAPPED (count_cells in
                                  // spatial_hash.metal) — it is the cell MASS
                                  // for self-gravity and must stay honest.
                                  // ⚠️ NOT an index bound — see SCATTER_PER_CELL.
                                  // Still correct for the COUNT-based uses
                                  // (:1206 eruption stress, :1236 flare colour),
                                  // which clamp a number, not a slot, and were
                                  // tuned against a capped count.

// ── HOW DEEP sortedParticles IS ACTUALLY FILLED ─────────────────────────────
// MEASURED 2026-08-13 14:52:18, [CELLPROBE], at rest 30 s from launch:
// **73.9% of the collision scan's reads were slots nothing wrote that frame.**
// 87.4% of the field sat in cells holding more than 32, one cell held 408,198
// particles (20.4% of the whole field), and the scan read 128 of them.
//
// THE MISMATCH: the scatter (spatial_hash.metal:351-356) refuses to write past
// **32 per cell** — "Only scatter if we haven't hit the 32 particle limit" —
// while cellStarts is the prefix sum of the UNCAPPED live counts (its own
// comment explains why: capping it would overflow a cell's range into the next
// cell's and let mergers eat a star twice). So a cell with n particles reserves
// n slots, has 32 filled, and anything reading deeper lands on an EARLIER
// FRAME's record at a position that particle has since left —
// sortedParticlesBuffer is allocated once and never cleared (the clear blit
// covers cellCounts, cellMass, seedCount, cellSeedMap, seedAccum, accDiag —
// not this one).
//
// The engine already had the right number in one place: the tiled kernel uses
// `min(cellCounts[...], 32u)` at spatial_hash.metal:669 and :714. This constant
// gives that convention a name so the two halves cannot drift apart again.
// ⚠️ IT IS NOT A TUNABLE. It must equal the scatter's limit. Raising the scan
// without raising the scatter re-creates the ghosts; raising the scatter costs
// real bandwidth and is a separate, measured decision.
constant uint SCATTER_PER_CELL = 32u;

// Phase 11.3: Planck-length softening (regularizes point-particle infinities)
constant float PLANCK_LENGTH_SQ = 0.0001f; // Minimum interaction distance²

// ── Stellar scale + FATE LADDER constants (used by physics, merge, seeds) ───
// 1 R_sun in sim units. Honest anchor: kUnitMeters = 1.755e9 m (spacetime.h),
// so 1 R_sun = 6.957e8 m / 1.755e9 m = 0.397 sim (v_esc(Sun)=615 km/s ✓).
// BUT (2026-07-08): the cluster is drawn ~1e5× DENSER than a real one — 2M
// stars inside ~300 R☉ of space (a real cluster this populous spans ~1e8 R☉).
// Honest radii × fake density = every heavy star permanently in CONTACT with
// dozens of neighbours (10 M☉ ⇒ contact 2.6 sim vs 0.5 spawn gap): the launch
// merge storm, 36 merges/frame, the blinking field. Jamal's verdict: "open it.
// star map. period. slow progression on mergers." Two individually-honest
// anchors are mutually impossible; the domain can't grow 1e5×, so the radius
// carries the compression: scaled down so the merger RATE is the physical-
// looking quantity (zero at launch, slow visible events from real dynamics).
// Calibration pass 1: 0.397 → 0.01 (cross-section ↓~1600×). Note v_esc at
// contact rises ×6.3 — watch the v_rel/v_esc reaction-ladder split.
constant float MERGE_RSUN_SIM = 0.01f;
// The Kroupa draw tops out at 50 M_sun, so any body ABOVE it can only be a
// merger product — and a merger remnant that heavy collapses: it IS a black
// hole (single-scalar mass→fate, physics canon). Seeds are dark (render
// culls them except while flaring) and grow ONLY via victim-initiated
// feeding. Must match the 50.0f in render.metal's dark-cull.
constant float M_BH_SEED = 50.0f;

// ── VISCOUS ACCRETION RATE LIMIT (2026-08-08) ───────────────────────────────
// WHY: the FORMED regime's capture radius is 3·r_s, which is LINEAR in mass, so
// cross-section ∝ M² and dM/dt ∝ M² — a finite-time blow-up. Measured: Mmax
// jumped 475 → 322,919 M☉ between two consecutive log samples, with ZERO
// samples in between (docs/MEASURED_2026-08-08_A1_runaway_cause.md). The field
// was eaten down to live=19.
//
// The cause is that nothing limits the RATE. Matter touching the capture radius
// falls straight in, i.e. the sim accretes at the free-fall ceiling. Real discs
// are limited by VISCOSITY — how fast matter sheds angular momentum — which is
// slower by 1/(α·(h/r)²).
//
// EVERY NUMBER BELOW IS DERIVED FROM THIS SIM'S OWN MEASURED TELEMETRY.
// Nothing here was picked to feel right.
//
//   h/r = c_s/v_φ, evaluated at two independent places in our own disc:
//     inner: T=3.65e11 K → c_s=0.3052c ; v_φ=0.4092c → h/r = 0.746
//     mean : T=2.95e10 K → c_s=0.0868c ; v_φ=0.1125c → h/r = 0.771
//   Temperatures 12× apart, velocities 3.6× apart, answers agree to 3% — the
//   disc genuinely has a uniform aspect ratio ≈0.75. That is thick, which is
//   correct: our anchor Sgr A* is a RIAF, not a thin disc.
//
//   SCALE CHECK, independent: measured orbV max = 0.4092c vs the theoretical
//   ISCO speed √(1/6) = 0.4082c — 0.23%. We are exactly at scale.
constant float SS_ALPHA      = 0.1f;      // Shakura–Sunyaev viscosity parameter
constant float DISK_H_OVER_R = 0.746f;    // MEASURED (above), not chosen
constant float V_ISCO_C      = 0.40825f;  // √(1/6), c ≡ 1 in sim units
constant float KRS_SIM_PER_MSUN = 1.6825e-6f; // KEEP IN SYNC with units.h
constant float KTLAPSE_SIM_PER_WALLSEC = 3.51513f; // units.h kTLapse
//   T_isco[sim] = 2π·(3·r_s)/v_isco = 6π·kRs·M/v_isco   →  LINEAR in M
//   t_visc      = T_isco/(α·(h/r)²)
//   dM/dt       = M/t_visc = α·(h/r)²·v_isco/(6π·kRs)
// ⭐ The M cancels. The ceiling is MASS-INDEPENDENT, so the hole grows LINEARLY
//   and the M² divergence is gone BY CONSTRUCTION — not by a clamp.
constant float MDOT_MSUN_PER_SIMTIME =
    SS_ALPHA * DISK_H_OVER_R * DISK_H_OVER_R * V_ISCO_C /
    (6.0f * 3.14159265f * KRS_SIM_PER_MSUN);          // ≈ 716 M☉ / sim-time
// dt reaches this kernel in WALL seconds, so convert: ≈ 2517 M☉ / wall-second.
// At that rate 50 M☉ → the whole 594,276 M☉ field takes ≈ 3.9 minutes.
constant float MDOT_MSUN_PER_WALLSEC =
    MDOT_MSUN_PER_SIMTIME * KTLAPSE_SIM_PER_WALLSEC;

// ── THE OUTCOME BOUND IS DEAD (killed 2026-08-31 16:10:25, his order) ───────
// "kill the cap. its so 2014. we can do it."
//
// It lived here 2026-08-11 → 2026-08-31 as a feedback taper: a hole's growth
// was tapered to zero as it approached F_BH_CLUSTER × fieldMass, with
// F_BH_CLUSTER = 0.17188 taken from Sgr A* (4.297e6 M☉, GRAVITY 2022) over the
// Milky Way nuclear star cluster (2.5e7 M☉, Schodel et al. 2014). On our
// 594,276 M☉ field that ceiling was 102,144 M☉.
//
// WHY IT DIES, so nobody re-derives it: its written justification was a model
// of how long he plays — "a Berlin set is 40-60 minutes", i.e. the bound was
// there to keep the hole from eating the field inside a show. He ruled that
// reasoning out on 2026-08-31: "you must keep from thinking about how i play
// the show... thats 0 concern to the sim." The rationale is VOID, not merely
// overruled. The observed M/M_cluster ratio is still a real number about the
// real universe; it was never a law forbidding this hole from growing.
//
// WHAT SURVIVES: MDOT_MSUN_PER_WALLSEC above. That is a RATE limit — it bounds
// dM/dt out of the disc, a different mechanism, and it is not what he killed.
// Growth is linear and unbounded in time again, by design.
//
// KNOWN CONSEQUENCE, traced not fixed: BOARD_BLACKHOLE.md:713-715 — above
// ~356,475 M☉ the pre-horizon seed BLOB draws as a ~220-pixel blackbody sprite,
// because it is gated on horizonR rather than on mass (render.metal:1941).
// Killing the bound makes that mass reachable again.

// ── Unified BH constants ────────────────────────────────────────────────────
// All BH-related sizes derive from BH_M (the visual Schwarzschild radius in
// sim coords). Must match `M` in blackhole.metal:5.
//   BH_M       = mass / Schwarzschild radius (sim coords)
//   BH_HORIZON = Kerr outer horizon = M + sqrt(M² − a²) for a=0.99M ≈ 1.14·M
// All gates that previously used the stale `SCHWARZSCHILD_RS = 0.40` constant
// now derive from these so the particle physics' notion of "near horizon"
// matches what the raytracer actually draws as the horizon.
//
// NOTE: gravity strength is a SEPARATE physical parameter (not derived from
// BH_M) because using M_visual=0.025 as the gravitational mass would give
// orbital periods of ~40s — too slow to be visually interesting. Real BHs
// have decoupled "apparent shadow size" from "orbital timescale" anyway
// (the shadow scales with M, orbital periods scale with M but also with r³,
// so picking a usable r where M is visible is a separate tuning).
constant float BH_M       = 0.5f;
constant float BH_HORIZON = 0.57f;          // ≈ M + sqrt(M² − a²), a = 0.99M
constant float SCHWARZSCHILD_RS = BH_HORIZON; // legacy alias (existing gates)
// Outer cap is now DYNAMIC — see compute_physics for the per-frame
// blend. The values below are the two endpoints:
//   ORBIT_R_BH      = silence/BH state, tight ring just past horizon.
//                     Disk reads as a thin Saturn-ring around the BH.
//   ORBIT_R_CHLADNI = play state, the godlike-creating cap. Bessel
//                     voice forces fill this radius with structured
//                     pattern.
// totalAmplitude drives the blend: 0 → BH cap, > ~0.5 → CHLADNI cap.
// Result: "explodes out of the BH on note attack, sucked back in on
// release."
constant float ORBIT_R_BH      = 2.0f; // widened from 1.0: the rest disk now has
                                       // RADIAL WIDTH [0.75→2.0] instead of a thin
                                       // 1-radius ring, so the Shakura–Sunyaev
                                       // temperature gradient (hot inner → cool
                                       // outer) is visible. Still breathes out to
                                       // ORBIT_R_CHLADNI on play.
// SCALE UNIFICATION (2026-07-19 23:48, Jamal's diagnosis: "old 5-months code
// pre-unified system... a scale issue" — CONFIRMED): 3.0 was the play cap of
// the OLD ±3 tube world (set 2026-07-10); the unified ±64 domain (83756a6,
// 07-18) never rescaled it, so ALL of play — cavity, wall, matter — squeezed
// into a radius-3 needle inside a ±64 room. That needle IS the eternal "tube
// skin" at its outermost scale. Now 12: at default zoom (±4.8) the camera is
// INSIDE the medium; at max zoom-out (±24) the cavity fills the window.
// EIGEN_R/EIGEN_L (=π²R) and every per-mode force gain self-scale from this.
// R 12 → 6 (2026-07-20 00:40, Jamal: "the scale change kinda broke their
// dimension — lowest C used to read as two rings, now it's like an eye"):
// at 12 the Bessel table (α ≤ 20.32) can't texture the room — pattern
// fineness ∝ α/R fell 4×, low modes blew into one giant ring. 6 = twice the
// old room, ring structure back within the math's range.
constant float ORBIT_R_CHLADNI = 6.0f;
constant float STAR_MAP_CAP    = 100.0f; // silence: NO cap (the star map has no tube limit)

// CYMATICS VELOCITY CAP (play regime). The relativistic c-cap (u.speedCap·dt)
// governs GRAVITATIONAL INFALL — rest/collapse, where matter falls at up to c.
// But high-amplitude PLAY is a different physical regime: particles driven by an
// acoustic STANDING WAVE (Chladni cymatics), non-relativistic, ordinary speeds.
// The c-cap doesn't apply there — it just throttled the sculpt force (strength
// 25, tuned against this cap) ~41× and shook the pattern apart (2026-06-13
// regression). This is the ORIGINAL pre-c-cap sculpt-scale cap (1.2 sim/frame),
// restored ONLY in the play regime; the c-cap stays intact for rest/infall.
// ⏱️ 2026-08-29 — WAS 1.2 sim/FRAME. A frame is not a unit of time, so that
// made the play-regime speed limit depend on the warp dial: 20.69c at x1,
// 10.35c at x2, 1.29c at x16, 0.32c at x64. MEASURED in his own run.log:
// `speed max 20.690 c` in 862 of 1496 play samples — the field SATURATED
// against it, avg 15.7-16.5c, while at rest the c-cap is respected (max 1.000).
// That is his "stuff shoots out violently after 2x": the speed of light moved
// when he turned the dial. Now expressed as a real VELOCITY in sim/s, applied
// as v*dt below, so it is warp- and frame-rate invariant.
// IDENTITY AT WARP 1 BY CONSTRUCTION: 72.7273 * 0.0165 = 1.2 sim/frame exactly,
// so his tuned sculpt magnitude is preserved and the 2026-06-13 ~41x Chladni
// throttle regression is NOT reintroduced.
// NOTE (his call, not mine): 72.7273 sim/s = 20.69c is deliberately superluminal
// — the "cymatics standing-wave regime" the comment below describes. This fix
// makes it a HONEST constant, it does not decide whether it should be that big.
constant float CHLADNI_VCAP_PER_SEC = 72.7273f; // sim/SECOND (= the old 1.2/frame at dt=0.0165)

// NOTE (2026-07-22): a "play-collapse" experiment (keep a fraction of self-gravity
// during play to fill the cavity) was tried and REVERTED — gravity is directional
// (toward COM), so it warped every shape to one side ("one-sided distortion, doesn't
// close"). The correct fill mechanism is ISOTROPIC thermal pressure (warm trap),
// not a directional pull. See the gkick block below (kept at gravity-OFF in play).

// ── ERUPTIONS in the hardened areas (magnetic-reconnection / solar-flare) ──
// Where the Chladni pattern hardens (dense nodes), stress builds; past a
// threshold the node ERUPTS — a sudden outward plasma burst + heat flash. See
// [[space-synth-tube-supernova-vision]].
constant uint  ERUPT_DENSITY   = 20u;   // cell particle count = a "hardened" node
constant float ERUPT_THRESHOLD = 0.80f; // intermittency gate (per-cell flare clock)
constant float ERUPT_FORCE     = 80.0f; // outward burst velocity scale
constant float ERUPT_TEMP      = 4.0f;  // flash temperature (hot plasma)

// REST-STATE GAS RECYCLE (2026-07-23, Jamal's lifecycle loop: eaten matter must
// return as gas, not pile forever). The BH eats matter to mass≈0 at rest; the
// resurrection below only pukes it back on PLAY, so at rest the dead pile grows
// unbounded → the dense core whites out (additive blend of a few ultra-dense
// cells) and FPS dies and "never recovers". A slow per-frame trickle returns
// dead matter to its star-map home at rest too, so the core reaches EQUILIBRIUM
// (a BH still forms — the heavy accretion seeds keep growing, only the dead
// walls recycle) instead of a runaway pile-up. Tune to taste.
// ⚠️ PER-FRAME AND STILL WRITTEN THAT WAY — deliberately left alone 2026-08-30.
// It is DELIBERATELY UNREFERENCED (see the bit6 cut at the use site below), so
// it is a record of an old rate, not a live clock leak. If it is ever switched
// back on it must become a per-SECOND rate first, like SUSTAIN_REBIRTH_PER_SEC.
constant float REST_RECYCLE    = 0.005f; // fraction of dead matter recycled per frame at rest

// ── SUSTAIN REBIRTH RATE (2026-08-03) ───────────────────────────────────────
// Fraction of the dead pile returned per frame while a note is HELD. 1/180:
// 180 frames = 1.5 s at 120 fps, so a normal hold keeps feeding the shape for
// its whole length instead of dumping the pile in a single frame — the gesture
// is tied to how long the note is held, which is the point of putting it on
// sustain. A short stab gives some matter back, a long drone gives all of it.
// ⏱️ 2026-08-30 — WAS 0.0056 "per frame". The comment above states the intent
// in SECONDS ("180 frames = 1.5 s at 120 fps"), which is the tell: the gesture
// is meant to last as long as he HOLDS the note, and a per-frame fraction makes
// its length a function of frame rate instead. 0.0056/frame is 0.667/s at the
// 120 fps it was authored at, but only 0.224/s at the 40 fps he actually runs —
// so a hold that was designed to feed the shape over 1.5 s took 4.5 s, and the
// pile emptied at a different speed on every machine.
// Now a per-SECOND rate, converted at the use site with u.dt. IDENTITY AT THE
// 120 fps IT WAS TUNED AT BY CONSTRUCTION: 0.666667 * (1/120) = 0.005556.
// 🚨 VERDICT ITEM: at his frame rate this makes sustain rebirth ~3x faster than
// it has been, which is the authored intent, but it is a visible change.
constant float SUSTAIN_REBIRTH_PER_SEC = 0.666667f; // 1/1.5 s
// Newborns appear beside a living particle, offset by this much. 5x the contact
// radius MERGE_RSUN_SIM (0.01): any closer and merge_stars eats the newborn on
// the frame it appears, which would make the rebirth invisible AND feed the
// seed it just escaped. Far enough to survive, close enough to read as "in the
// shape" at any zoom where the pattern itself is resolved.
constant float REBIRTH_JITTER  = 0.05f;
// Mass a returning particle carries. The abyss gives back LIGHT, not stars: the
// eaten mass is conserved inside the seed that ate it and is NOT refunded here
// (refunding it would destroy the accretion engine — the 2026-06-22 lesson at
// the resurrection block). 0.01 M_sun is 10x the >0.001 alive gate so the
// particle renders and moves, and below the IMF floor 0.08 so returned light
// can never masquerade as a star. Whole pile (~46% of 2M) adds ~1.5% to field
// mass — the conservation watchdog [GRAV] Mlive will drift up by that much on
// a long hold, and that is expected, not a leak.
constant float REBIRTH_MASS    = 0.01f;

// ── RADIAL ENCLOSED-MASS PROFILE (honest geometric horizon — full_physics_todo B2) ──
// Bin live mass into fine radial shells around the BH candidate (u.bh*) so the
// CPU can find the largest r where r_s(M(<r)) ≥ r = the REAL horizon radius —
// resolving r_s far below the coarse 3D cell (1.0 sim at rest). OBSERVE-ONLY.
constant uint  RADIAL_SHELLS     = 256u;
constant float RADIAL_MAX_R      = 5.0f;                              // sim units
constant float RADIAL_INV_DR     = float(RADIAL_SHELLS) / RADIAL_MAX_R; // shells per sim
constant float RADIAL_MASS_SCALE = 256.0f;                            // M_sun → fixed-point uint

// Chandrasekhar velocity factor G(X) = erf(X) − (2X/√π)·e^(−X²), X ≥ 0.
// Used by dynamical friction. erf via Abramowitz-Stegun 7.1.26 (err < 1.5e-7)
// so we don't depend on a Metal erf(); the small-X limit G→(4/3√π)X³ falls out,
// which cancels the 1/v³ in the friction (self-regularizing as v→0).
inline float chandraG(float X) {
    float t   = 1.0f / (1.0f + 0.3275911f * X);
    float ex  = exp(-X * X);
    float erf = 1.0f - (((((1.061405429f * t - 1.453152027f) * t) +
                          1.421413741f) * t - 0.284496736f) * t + 0.254829592f)
                       * t * ex;
    return max(erf - (2.0f * X / 1.7724538509f) * ex, 0.0f);
}

// ── Bessel J_m(x) — cylindrical eigenmode primitive (play-stack re-land) ─────
// Power series J_m(x) = Σ_k (-1)^k (x/2)^(2k+n) / (k!(k+n)!), evaluated as a
// running-product recurrence (no pow, no big factorials): T_k = T_{k-1}·
// (-hx²)/(k(k+n)). Faithful float32 port of src/core/bessel.cpp — verified vs
// known values (err <1e-5 for x≤10, ~0.05% by x=13; keep k_ρρ in low zeros).
// Small-x branch. FIXED 20-iteration loop (no data-dependent break):
// deterministic → the Metal compiler unrolls it cleanly. A variable-length
// break inlined 7× hung PSO creation (2026-07-09).
inline float besselSeries(int n, float x) {
    float hx = x * 0.5f;
    float term = 1.0f;
    for (int i = 1; i <= n; i++) term *= hx / float(i); // hx^n / n!
    float sum = term;
    float hx2 = hx * hx;
    for (int k = 1; k <= 24; k++) {   // 24 = the count validated 2026-07-29
        term *= -hx2 / (float(k) * float(k + n));
        sum += term;
    }
    return sum;
}

// REMOVED 2026-07-29: the Hankel asymptotic large-x branch (A&S 9.2.1). Its own
// note below was right that the power series dies past x≈14 — but the asymptotic
// replacement only holds while x >> m², so it was silently valid ONLY for the old
// m≤6 table and failed at 8.9e-1 abs error on the extended one. Miller's
// recurrence (in besselJm) covers the whole domain at 2.6e-7 and is what serves
// large x now. Kept in git history; do not reintroduce without re-measuring.
// The original note, preserved because the DIAGNOSIS in it is still correct:
//   "past x≈14 the power series loses ALL precision to float32 cancellation —
//    its max term reaches ~1e7 while the true |J| ≤ 1, so no term count can
//    recover it (measured: J_6(20.32) returned 0.186 instead of 0, i.e. the
//    nodal shell at the cavity wall dissolved)."

// ── REPLACED 2026-07-29: series+asymptotic → series+MILLER RECURRENCE ────────
// WHY. The old split was series below x=14, Hankel asymptotic above. That is
// correct ONLY while x >> m², so it held for the old m≤6 / x≤20.4 table and
// nothing more. Measured against 80-digit ground truth (scratchpad/
// bessel_truth.py, 5889 samples):
//     m≤6,  x≤20.4  (old table)      worst abs err 1.5e-3   ← matches its own comment
//     m≤11, x≤43.4  (extended table) worst abs err 8.9e-1   ← TOTAL FAILURE
// |J| ≤ 1 everywhere, so 0.89 is garbage — the asymptotic P/Q terms carry
// (mu-1)(mu-9)(mu-25)(mu-49) ≈ 4.6e10 at m=11 and diverge at moderate x. No
// crossover value rescues it (swept 14/16/20/24). So extending the zeros table
// REQUIRED replacing the evaluator; doing only the table would have shipped a
// broken field.
//
// NOW: power series below x=4, Miller downward recurrence above.
//   J_{k-1} = (2k/x)·J_k − J_{k+1} is stable DOWNWARD. Seed at order M with a
//   tiny value, recur down, normalise with J_0 + 2·(J_2+J_4+…) = 1.
// Measured worst abs err 2.6e-7 over m=0..12, x∈[1e-4, 43.4] — 5700× better
// than the old code inside its OWN range, over twice the range.
//
// TWO CONSTRAINTS BAKED IN, both learned the hard way:
//  1. NO DATA-DEPENDENT BREAK. Fixed iteration count — a variable-length break
//     inlined 7× hung PSO creation (2026-07-09).
//  2. NO 1/x NEAR THE AXIS. Miller divides by x, which is exactly what produced
//     Inf/NaN on the cylinder axis and zeroed the whole sim (2026-07-09). The
//     series branch owns x < 4, so the recurrence never sees a small x.
//     Verified: J_0(1e-4)=1.00000000, J_1(1e-4)=5.0e-5, J_11(1e-4)=0, and zero
//     non-finite results across all 5889 samples.
// M=64 is the measured knee: 2.6e-7 at M=64 and M=96 alike, degrading to
// 3.8e-5 at M=56 and 9.9e-3 at M=48. Sweep in scratchpad/msweep.cpp.
constant float BESSEL_SERIES_X = 4.0f;   // series below, Miller above
constant int   BESSEL_MILLER_M = 64;     // recurrence start order

inline float besselJm(int n, float x) {
    float ax = fabs(x);
    if (ax < 1e-6f) return (n == 0) ? 1.0f : 0.0f;
    float J;
    if (ax < BESSEL_SERIES_X) {
        J = besselSeries(n, ax);
    } else {
        float jkp1 = 0.0f, jk = 1.0e-20f, norm = 0.0f, res = 0.0f;
        for (int k = BESSEL_MILLER_M; k >= 1; k--) {
            float jkm1 = (2.0f * float(k) / ax) * jk - jkp1;
            jkp1 = jk;
            jk   = jkm1;
            if (k - 1 == n) res = jk;
            if (((k - 1) & 1) == 0) norm += (k - 1 == 0) ? jk : 2.0f * jk;
            if (fabs(jk) > 1e18f) {          // rescale, no branch on data length
                jk *= 1e-18f; jkp1 *= 1e-18f; norm *= 1e-18f; res *= 1e-18f;
            }
        }
        J = res / norm;
    }
    // J_n(-x) = (-1)^n J_n(x); call sites pass x ≥ 0, kept for correctness.
    return (x < 0.0f && (n & 1)) ? -J : J;
}

// J_m(x) AND its derivative J_m'(x) in one shot (analytic Gor'kov gradient).
// J_m' = (J_{m-1} − J_{m+1})/2. J_{m-1} comes from the DIRECT power series, not
// the recurrence (2m/x)J_m−J_{m+1}: that 1/x blows to Inf/NaN on the cylinder
// axis (x→0, m≥1) and a NaN force zeroes the whole sim (found 2026-07-09).
// J_{-1} = −J_1. Three stable besselJm evals.
inline float2 besselJmD(int m, float x) {
    float Jm  = besselJm(m, x);
    float Jp1 = besselJm(m + 1, x);
    float Jm1 = (m == 0) ? -Jp1 : besselJm(m - 1, x); // J_{m-1}, with J_{-1}=−J_1
    return float2(Jm, 0.5f * (Jm1 - Jp1));            // (J_m, J_m')
}

// ── Cylindrical cavity eigenmode Ψ(ρ,θ,z) = J_m(k_ρρ)·cos(mθ)·cos(k_z z) ─────
// The physically-correct 3D acoustic standing wave (play-stack re-land). Sand
// collects on the Ψ=0 nodal shells via the Gor'kov force F=−Ψ∇Ψ. k_ρ is
// quantized by the cavity (k_ρ=alpha/R, alpha=the mode's Bessel zero) so k_ρρ
// stays in besselJm's accurate range; k_z comes from dispersion downstream.
// Play-stack re-land tuning (increment 1 — visual A/B, values to be refined).
// Zeros of J_m: ZEROS[m][k] = (k+1)-th zero. Verbatim from src/core/bessel.cpp
// (Abramowitz & Stegun). Flat [m*4 + (n-1)]. THE cavity quantization: k_ρ =
// α_{m,n}/R, so at the wall k_ρR = α ⇒ J_m = 0 ⇒ Ψ = 0. Max is 20.3208.
// NOTE: VoiceData.alpha is NOT a Bessel zero — modes.cpp fills it with the
// note's FREQUENCY IN HZ ("mostly vestigial"), despite modes.h claiming
// "Bessel zero value". Using it as k_ρ·R drove x=k_ρρ into the hundreds and
// the power series to ±1e17 → Inf force → the finite-guard froze the field
// (root cause of the 2026-07-09 eigenmode freeze).
// ── EXTENDED 2026-07-29: 7x4 (m≤6, n≤4) → 12x9 (m≤11, n≤9). Flat [m*9 + (n-1)].
// WHY. modes.cpp produces m = pitchClass = 0..11 and n = octave = 1..9, but this
// table only reached m=6, n=4 — and the lookup below CLAMPED to fit. So F#, G,
// G#, A, A# and B all collapsed onto m=6 (six of twelve semitones drawing the
// IDENTICAL shape) and every octave from 4 up collapsed onto n=4. That is the
// live cause of "the chladni shapes look wrong its only rings now on almost all
// notes" (Jamal 2026-07-28). The whole keyboard now maps to a distinct mode.
// Generated in 80-digit Decimal (scratchpad/bessel_truth.py) and cross-checked
// against published values to 12 digits; the original 7x4 block above is
// reproduced EXACTLY, so this is a strict extension, not a re-derivation.
// Max is now 43.3684 (J_11 9th zero), up from 20.3208 — which is precisely why
// besselJm had to be replaced first (see the note above it).
constant float BESSEL_ZEROS[108] = {
     2.4048f,  5.5201f,  8.6537f, 11.7915f, 14.9309f, 18.0711f, 21.2116f, 24.3525f, 27.4935f, // J_0
     3.8317f,  7.0156f, 10.1735f, 13.3237f, 16.4706f, 19.6159f, 22.7601f, 25.9037f, 29.0468f, // J_1
     5.1356f,  8.4172f, 11.6198f, 14.7960f, 17.9598f, 21.1170f, 24.2701f, 27.4206f, 30.5692f, // J_2
     6.3802f,  9.7610f, 13.0152f, 16.2235f, 19.4094f, 22.5827f, 25.7482f, 28.9084f, 32.0649f, // J_3
     7.5883f, 11.0647f, 14.3725f, 17.6160f, 20.8269f, 24.0190f, 27.1991f, 30.3710f, 33.5371f, // J_4
     8.7715f, 12.3386f, 15.7002f, 18.9801f, 22.2178f, 25.4303f, 28.6266f, 31.8117f, 34.9888f, // J_5
     9.9361f, 13.5893f, 17.0038f, 20.3208f, 23.5861f, 26.8202f, 30.0337f, 33.2330f, 36.4220f, // J_6
    11.0864f, 14.8213f, 18.2876f, 21.6415f, 24.9349f, 28.1912f, 31.4228f, 34.6371f, 37.8387f, // J_7
    12.2251f, 16.0378f, 19.5545f, 22.9452f, 26.2668f, 29.5457f, 32.7958f, 36.0256f, 39.2404f, // J_8
    13.3543f, 17.2412f, 20.8070f, 24.2339f, 27.5837f, 30.8854f, 34.1544f, 37.4001f, 40.6286f, // J_9
    14.4755f, 18.4335f, 22.0470f, 25.5095f, 28.8874f, 32.2119f, 35.4999f, 38.7618f, 42.0042f, // J_10
    15.5898f, 19.6160f, 23.2759f, 26.7733f, 30.1791f, 33.5264f, 36.8336f, 40.1118f, 43.3684f, // J_11
};

// Cavity wall = the play cap itself: the radius clamp at the bottom of this
// kernel is cylindrical (rXY vs ORBIT_R_CHLADNI), which is what makes the play
// world a TUBE about world Z. So the acoustic cavity IS that tube.
// ⚠ COMMENT CORRECTED 2026-08-11 12:31:44. This read "// 3.0 sim units" and was
// wrong by 2x: ORBIT_R_CHLADNI is 6.0f (:276), so EIGEN_R = 6.0 and
// EIGEN_L = 2*EIGEN_R = 12.0, not 6.0. This stale comment is not harmless — it
// mis-sized the [GRIDPROBE] scan radius in renderer.mm, which was written to
// "see the pattern AND its surroundings" and instead scanned exactly the cavity
// and none of its surroundings. Fixed there in the same pass.
constant float EIGEN_R        = ORBIT_R_CHLADNI; // 6.0 sim units (= ORBIT_R_CHLADNI)

// AXIAL STRUCTURE — this is the depth. Ψ ∝ cos(k_z·z); k_z=0 ⇒ the pattern is a
// 2D cross-section extruded along the tube (flat), which is what "it's still
// just a tube" was. k_z needs a tube LENGTH, and that length is DERIVED, not chosen.
//
// THE JEANS LENGTH sets it. For a self-gravitating cloud, λ_J is how far a sound
// wave travels before gravity closes the region: below λ_J pressure waves stand,
// above it the region collapses. Demand the tube be exactly as long as sound can
// cross it (L = λ_J), with the cloud virialised at the cavity radius
// (σ_v² = GM/R) and its density set by the cavity it fills (ρ = M/πR²L):
//     λ_J² = σ_v²·π/(Gρ) = (GM/R)·π·(πR²L/GM) = π²·R·L
//     L = λ_J   ⟹   L = π²·R          ← the MASS CANCELS
// Verified against the repo's own SI anchor (spacetime.h: kMfieldMsun=5.94276e5,
// 1 sim length = 2·r_g = 1.75504e9 m): closed form and an independent numeric
// fixed point on L = λ_J(ρ(L)) both give L = 29.6088 sim = 0.347 AU. 2026-07-10.
//
// The old EIGEN_C=5000 dispersion (k_z=√(K²−k_ρ²), K=2πf/c) is DEAD: it clamped
// to 0 for every voice, and any c that frees the low notes drives k_z ∝ f, giving
// 240 nodal planes at C5 — sub-particle-spacing haze, not depth. Don't retry it.
// DEPTH OVERRIDE (2026-07-21 13:27, Jamal: "the depth is wrong"). Measured on
// screen: face-on the cavity is a vertical NEEDLE (we view the tube edge-on),
// and any tilt stretches the ring/iris cross-section into a tall 2:1 eye —
// because the Jeans depth π²R ≈ 9.87R makes a ~5:1 needle (L≈59 vs diameter 12
// at R=6). The axial extent dwarfs the radial pattern from every angle except
// perfect down-barrel. Overriding the canonical Jeans length with a
// PROPORTIONATE cavity (depth ≈ diameter = 2R) so the 3D pattern reads as a
// rounded volume, not a needle, from all view angles. The Jeans derivation
// above is kept intact — revert this line to `M_PI_F*M_PI_F*EIGEN_R` for canon.
constant float EIGEN_L = 2.0f * EIGEN_R;  // proportionate cavity: depth = diameter
// FORCE GAIN IS NOT FREE — the integrator dictates it.
// nextPos = pos + finalV (no dt), so the time unit is ONE FRAME. Linearising the
// Gor'kov force about a nodal surface gives a discrete damped oscillator
//     x⁺ = x + v⁺,   v⁺ = f·v − K·x,   K = S·k²   (k = the mode's wavenumber)
// which is stable only for K < 2(1+f). Hence S is FIXED by k, and since k varies
// per mode (k_ρ = α_mn/R spans 0.80→6.77), the gain must be per-voice:
//     S_v = EIGEN_KAPPA / (k_ρ² + k_z²)
// EIGEN_KAPPA is the dimensionless per-frame trap stiffness — the only number,
// and it is bounded, not tuned. The old S=30 gave K = 30·6.77² = 1376, i.e. 344×
// past the stability limit: particles were flung across their nodal sheet every
// frame. That was the drift, the heating, and the blur (measured 2026-07-09).
constant float EIGEN_KAPPA = 0.25f;      // K ≤ 0.25 ⇒ well inside K < 2(1+f)

// ── Compute kernel: Störmer-Verlet particle physics ─────────────────────────

// ── LIGHT ORBIT SUBSTEP (2026-07-25, Jamal) ───────────────────────────────
// Cheap orbit advance for physics sub-stepping. Runs (N-1)× per frame between
// full compute_physics passes, doing ONLY the central SMBH gravity (analytic —
// the force that sets the orbits) + position-Verlet integrate. No field self-
// gravity loop, no collisions, no SPH, no drain — so N substeps cost ~1 full +
// (N-1) cheap instead of N full. The orbit advances N× per frame → the fast
// sweep that makes real trails ("fast by physics, not faked"), WITHOUT the dt-
// blowup of scaling the step (each step is the stable dt). Matches the full
// kernel's Verlet scheme (pos + (pos-prev)·fric + a·dt², c·dt-capped) so the
// orbit does not drift from the full step, which still runs once per frame.
kernel void orbit_substep(device Particle* particles [[buffer(0)]],
                          constant PhysicsUniforms& u [[buffer(2)]],
                          uint id [[thread_position_in_grid]]) {
    if (id >= (uint)u.particleCount) return;
    Particle p = particles[id];
    float mass = p.posW.w;
    if (mass < 0.001f) return;                 // walls / dead matter: don't move
    float dt = u.dt;
    float3 pos  = p.posW.xyz;
    float3 prev = p.prevW.xyz;
    // Central SMBH gravity — identical form to compute_physics (central kick,
    // :1203). Only in the BH/rest regime (bit1 on, not playing).
    float3 gacc = float3(0.0f);
    if ((u.bhToggles & 0x2u) && u.totalAmplitude < 0.02f) {
        float dc2 = dot(pos, pos) + 0.05f;
        gacc = (-pos) * (u.centerGM * rsqrt(dc2) / dc2);
    }
    // Position-Verlet with rest friction; gravity kick capped at c·dt.
    float3 vel = (pos - prev) * pow(0.99f, dt);
    float3 gkick = gacc * (dt * dt);
    float gkmag = length(gkick);
    float gkmax = u.speedCap * dt;
    if (gkmag > gkmax && gkmag > 1e-12f) gkick *= (gkmax / gkmag);
    vel += gkick;
    float3 newPos = pos + vel;
    p.prevW.xyz = pos;                          // .w (temperature) preserved
    p.posW.xyz  = newPos;                       // .w (mass) preserved
    p.velW.xyz  = vel;                          // .w (phase) preserved → trails
    particles[id] = p;
}

kernel void compute_physics(
    device Particle* particles [[buffer(0)]],
    device const VoiceData* voices [[buffer(1)]],
    constant PhysicsUniforms& u [[buffer(2)]],
    device const Particle* prevParticles [[buffer(3)]],
    device const SortedHot* sortedParticles [[buffer(4)]],
    device const uint* cellStarts [[buffer(5)]],
    device const uint* cellCounts [[buffer(6)]],
    constant SpatialHashUniforms& su [[buffer(7)]],
    device const float4* cellCentroids [[buffer(8)]],
    device const float4* cellVelocities [[buffer(9)]],
    device const uint* cellMass [[buffer(10)]],   // Σ M_sun ×64 per cell (count_cells)
    device const uint* cellSeedMap [[buffer(11)]],   // 0=none, else seed slot+1
    device const uint* seedIds [[buffer(12)]],       // registry (count_cells)
    device atomic_uint* seedAccum [[buffer(13)]],    // per-slot meal accumulator
    device atomic_uint* accDiag [[buffer(14)]],      // [0]=max accuracy ratio ×1000 (measurement slice, diagnostic-only)
    device const float* phi [[buffer(15)]],          // PM gravity potential Φ on the 128³ grid (poisson_sor); force = −∇Φ
    device const float4* sphForce [[buffer(16)]],    // SPH pressure acceleration (sph_force, slice 2b); added to gacc under bit11
    device atomic_int* sphClosure [[buffer(17)]],    // TEMP-CLOSURE ledger ×1e6: [0]=W done by the SPH force (F·Δx)
    device const float* sphU [[buffer(18)]],         // SPH specific internal energy u_i (id-indexed, persistent)
    device const float* finePhi [[buffer(19)]],      // AMR fine PM potential Φ (bit15; nested grid ±fsu.halfExtent)
    constant SpatialHashUniforms& fsu [[buffer(20)]],// AMR fine-grid uniforms (halfExtent=kAmrFineExtent)
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;

    device Particle& p = particles[id];
    float px = p.posW.x;
    float py = p.posW.y;
    float pz = p.posW.z;
    float mass = p.posW.w;
    // TEMP-CLOSURE: entry position (px/py/pz get mutated mid-kernel).
    float3 posEntry = float3(px, py, pz);

    // ── ONE-WAY MEMBRANE flag (2026-07-16, BH deep scan) — see the membrane
    // note at the dynfric gate. Declared at kernel scope: the force gates
    // (dynfric/LTRANS/SPH) AND the final-kick damping both read it.
    bool insideHorizon = false;
    if (u.horizonR > 0.0f && mass > 0.001f) {
        float3 relBH0 = float3(px - u.bhX, py - u.bhY, pz - u.bhZ);
        insideHorizon = dot(relBH0, relBH0) < u.horizonR * u.horizonR;
    }

    // ── Störmer-Verlet: derive velocity from position history ────────
    float prevX = p.prevW.x;
    float prevY = p.prevW.y;
    float prevZ = p.prevW.z;

    // ── RESURRECTION — PLAY PUKES THE EATEN FIELD BACK OUT ───────────────────
    // The BH eats particles to mass≈0 ("dead walls") at REST. The godray-vs-
    // current log diff showed ~46% of the current field is dead (godray: 0%) —
    // THAT is why play gives sparse spokes instead of the dense honeycomb: half
    // the instrument is corpses. A note REVIVES the whole field: every dead
    // particle returns at its star-map home as a weightless tracer and rejoins
    // the cymatics. (Jamal: "particles need to PUKE each other out when I play.")
    // Rest eats (the hole grows); play pukes the field back out, alive.
    // NOTE (2026-06-22): reverted my mass-conservation edit here — dissolving the
    // heavy SEED bodies on play also destroyed the seed accumulation that DRIVES
    // the stars→BH collapse (the working months-old process). Only the dead walls
    // revive; the seed keeps growing (the accretion engine). The 5.9e9 runaway is
    // a separate concern to address WITHOUT breaking accretion.
    // PLAY pukes the whole dead field back at once; REST trickles it back slowly
    // (the lifecycle recycle) so the eaten pile can't run away into a whiteout.
    // ── SUSTAIN REBIRTH — THE ABYSS GIVES ITS LIGHT BACK (2026-08-03) ────────
    // Jamal: "when i sustain a note the particles from within the black hole
    // respawn into the shape. this way we also finally solve the fucking
    // invisible abyss of light where all particles perpetually land in once
    // eaten by a black hole." Eaten matter is parked at 4000+ with mass 0 by
    // merge_stars and NEVER comes back — that pile (measured ~46% of the field)
    // is the abyss. Holding a note now streams it back INTO the Chladni figure.
    // The note-driven revive is SUSTAIN-ONLY now (was any amplitude > 0.02) and
    // its destination is the shape, not the star-map home. The slow rest
    // trickle keeps its old home destination, unchanged.
    // envelopePhase: 0 silence, 1 attack, 2 decay, 3 sustain, 4 release.
    bool sustainHeld = (u.envelopePhase >= 2.5f && u.envelopePhase < 3.5f);
    bool streamNow   = sustainHeld &&
                       ((noise(id, u.frameCounter + 977u) + 0.5f) <
                        (SUSTAIN_REBIRTH_PER_SEC * u.dt));
    // ── REST TRICKLE CUT FROM bit6 (2026-08-04 00:07:15) ─────────────────────
    // MEASURED, 5.5 min rest soak, nothing touched, envelopePhase 0.0 throughout:
    // Mlive 594563 -> 664608, +11.8% (~12.7k M_sun/min). streamNow cannot fire
    // outside sustain (phase 2.5-3.5), so 100% of that minted mass came through
    // this path. Reviving a corpse ALWAYS creates mass: its own mass was handed
    // to the seed that ate it and is deliberately never refunded (2026-06-22),
    // so any revive mass is new mass. Lowering 1.0 -> REBIRTH_MASS slowed the
    // pump 100x but did not close it, and a drifting Mlive makes every mass
    // fraction (share, encFrac, seedTarget) a ratio against a moving denominator.
    // The rest trickle was NEVER default-on before bit6 flipped for sustain
    // rebirth — it rode in as collateral, and Jamal asked for the sustain
    // feature, not this. Cutting it restores mass conservation at rest and
    // leaves the requested feature intact. REST_RECYCLE is kept as the record of
    // the old rate; it is deliberately unreferenced now.
    if ((u.bhToggles & 0x40u) && mass <= 0.001f && streamNow) {
        bool born = false;
        if (streamNow) {
            // INTO THE SHAPE, without evaluating the eigenmode here: the pattern
            // IS wherever the living matter currently is, so being born beside a
            // random live particle lands in the correct Chladni figure for ANY
            // mode, chord or sculpt state, and stays correct if the mode changes
            // mid-hold. Read from prevParticles (the previous-frame snapshot) so
            // this never races the writes happening around it this frame.
            uint n = uint(max(u.particleCount, 1));
            for (uint t = 0u; t < 4u && !born; ++t) {
                float rnd = noise(id, u.frameCounter + 31u * (t + 1u)) + 0.5f;
                uint  j   = uint(rnd * float(n)) % n;
                float4 hp = prevParticles[j].posW;
                // Reject the dead and the parked: a host must be a living
                // particle inside the domain, else we would seed the newborn
                // into the abyss it is escaping (park sits at 4000+, domain
                // is +-64 and the measured field maxR is 100).
                if (hp.w > 0.001f && !notFinite3(hp.xyz) && length(hp.xyz) < 200.0f) {
                    float3 hv = hp.xyz - prevParticles[j].prevW.xyz; // host's per-frame step
                    float3 off = float3(noise(id, u.frameCounter + 7u),
                                        noise(id, u.frameCounter + 13u),
                                        noise(id, u.frameCounter + 19u)) *
                                 (2.0f * REBIRTH_JITTER);
                    float3 pos = hp.xyz + off;
                    px = pos.x; py = pos.y; pz = pos.z;
                    // Born MOVING WITH the shape. At v=0 the pattern's own
                    // motion would read as the newborn being flung, and the
                    // Verlet step would book that jump as a real velocity.
                    prevX = pos.x - hv.x; prevY = pos.y - hv.y; prevZ = pos.z - hv.z;
                    // ── THE HOLE PAYS FOR THE REBIRTH (2026-08-04 22:46:41) ──
                    // Jamal: "BH IS NOT A PERPETUAL STATE it can be reversed
                    // through play... what if mass could get sucked OUT of a
                    // black hole." Was REBIRTH_MASS (0.01) — minted from
                    // nothing, measured live: live 713711→1351715 in one
                    // 120-frame sustain window, Mlive +6382 = 638004 × 0.01
                    // exactly. Ghosts: too light to see, and the seed kept all
                    // 578934 M_sun, so bhStrength (= seedTarget = r_s(gMaxMass)
                    // /0.5, monotone) could never fall and the hole never
                    // un-formed. Now the corpse comes back at its OWN SPAWN
                    // MASS and that mass is WITHDRAWN from the hole, so the
                    // shape strengthens with real matter and gMaxMass becomes
                    // NON-MONOTONE for the first time — the only way the hole
                    // can shrink under play.
                    // This reverses the 2026-06-22 "never refund" rule, which
                    // existed to protect the accretion engine. Explicit call by
                    // Jamal, 2026-08-04: reversibility wins. Rest still eats.
                    // 🚨 imfMassOfId(id) is the EXACT spawn mass of this slot
                    // (particles never change slots), so this returns precisely
                    // what was taken — no more, no less.
                    mass = imfMassOfId(id);
                    // Global withdrawal ledger, mass ×64 (same fixed point as
                    // the meal accumulator [0]). Charged to the single most
                    // massive body in seed_apply — which IS the hole, exactly
                    // as renderer.mm defines it (bhSeedMass = gMaxMass).
                    atomic_fetch_add_explicit(&seedAccum[6],
                                              uint(mass * 64.0f + 0.5f),
                                              memory_order_relaxed);
                    born = true;
                }
            }
        }
    }

    // Velocity proxy: displacement from previous frame
    // TIME-CORRECTED VERLET (2026-06-22): the per-frame velocity (pos-prev) is a
    // displacement over the LAST frame's dt; rescale it by dt/dtPrev so the
    // velocity↔gravity balance is FRAMERATE-INDEPENDENT (orbits hold at 53fps or
    // 120fps alike, instead of infalling whenever FPS≠120). dtPrev is init to the
    // spawn's 1/120, so frame 1 also corrects the spawn-bake↔runtime-dt mismatch
    // that was making everything plunge radially to the centre. Clamped so a
    // stall frame can't fling the velocity. At steady FPS the factor is ~1.
    float tcv = clamp((u.dtPrev > 1e-6f) ? (u.dt / u.dtPrev) : 1.0f, 0.5f, 2.5f);
    float vpx = (px - prevX) * tcv;
    float vpy = (py - prevY) * tcv;
    float vpz = (pz - prevZ) * tcv;

    // ── THE STEP. ONE CLOCK. ───────────────────────────────────────
    // ⏱️ 2026-08-30 — WAS: `(u.debugFlags & (1<<6)) ? (1.0f/60.0f) : u.dt`,
    // labelled "Phase 7: Deterministic Debug Mode".
    // 🚨 BIT 6 STOPPED MEANING "DEBUG" ON 2026-08-03. It was repurposed as the
    // SUSTAIN-REBIRTH gate (app_state.h:50, `uiTogResurrection = true`, DEFAULT
    // ON), and this consumer was never updated. So the branch was taken on every
    // shipped run and this kernel integrated on a hardcoded 1/60 s.
    // The scale of it: `dt` is used 95 times in this kernel; `u.dt` twice. The
    // 95 were frozen at 1/60 while the 2 scaled with the time warp — two clocks
    // inside one kernel, diverging by exactly the warp factor (1.01x at x1,
    // 4x at x4, 16x at x16). That is his "one bug in a million dresses" wearing
    // the oldest dress in the codebase.
    // ⚠️ EXPECTED CONSEQUENCE, stated BEFORE measuring: at warp 1 this is a 1%
    // step change and should be near-invisible. Above warp 1 it makes the step
    // GENUINELY bigger for the first time, so warp may look WORSE than it did
    // while 95 of 97 uses were accidentally warp-immune. That is honest: warp as
    // a bigger step is wrong, and the cure is warp as MORE STEPS, not a frozen
    // constant hiding it.
    float dt = u.dt;
    
    // Base friction. Was pow(0.02, dt) ≈ 0.968/frame (heavy damping) which
    // killed orbital stability — Kepler orbits need energy conservation,
    // friction makes them spiral in. pow(0.9, dt) ≈ 0.9991/frame still
    // e-folds velocity in ~9.5 s — fine for play (voice forces dominate,
    // damping prevents runaway), but at REST it kills orbits long before one
    // period completes, reducing self-gravity to terminal-velocity creep.
    // Rest friction is therefore near-conservative: pow(0.997, dt) e-folds in
    // ~5.5 min, so stars complete orbits and the gentle drag IS the accretion
    // mechanism (slow inspiral toward the mass centre — the dynamical-friction
    // analog). Blend by amplitude: rest → conservative, play → damped.
    float fricPlay = pow(0.9f, dt);
    float fricRest = pow(0.99f, dt);  // reverted from 0.9995 — see note below
    float baseFric = mix(fricRest, fricPlay,
                         clamp(u.totalAmplitude * 4.0f, 0.0f, 1.0f));
    // RELEASE = heavy-drag inspiral. Physically: the post-supernova gas is
    // shocked and dissipative — orbital energy bleeds off fast while the
    // orbital DIRECTION (angular momentum) is untouched, so matter visibly
    // spirals onto the hole over ~tens of seconds and settles into the disk.
    // This drag (e-fold ~20 s) replaces the deleted scripted collapse.
    if (u.envelopePhase > 3.5f) baseFric = pow(0.95f, dt);

    float dynamicFric = baseFric;
    // CORE-COLLAPSE COOLING factor (set in the self-gravity block once local
    // density is known; applied at finalV). 1 = no cooling.
    float coolMul = 1.0f;

    float currentTemp = p.prevW.w; // ODS-03: Thermal state

    // ── Snap Back: Pulse re-seed/Reset logic ──
    if (u.debugFlags & (1 << 8)) {
        uint seed = (uint)id + u.frameCounter;
        float r_new = sqrt(-2.0 * log(max(1e-7f, noise(id, seed)))) * 0.5f;
        float th_new = noise(id, seed + 1) * TWO_PI;
        float ph_new = noise(id, seed + 2) * M_PI_F;
        
        px = r_new * sin(ph_new) * cos(th_new);
        py = r_new * sin(ph_new) * sin(th_new);
        pz = r_new * cos(ph_new);
        vpx = 0.0f; vpy = 0.0f; vpz = 0.0f;
        // ── RESET MUST DESTROY THE HOLE (2026-08-03) ─────────────────────────
        // This block used to move ONLY position and velocity. Mass lives in
        // posW.w and was left untouched, so the accreted seed — a single body
        // holding 3-5e5 M_sun of swallowed stars — SURVIVED every reset, and
        // every eaten star stayed dead (parked at mass 0). The sim was then
        // right to keep reporting a black hole: r_h = kRsSimPerMsun * M_seed
        // ~= 0.82 stayed > 0, which keeps the one-way membrane alive in
        // spatial_hash.metal and lets a phantom half-million-solar-mass point
        // dominate the re-scattered field. "Reset" was a lie about the state.
        // Restoring the deterministic spawn draw un-eats the field in one
        // step: the seed drops back to its own star's mass and every corpse
        // comes back alive at its spawn mass. THIS is the destruction.
        mass = imfMassOfId(id);
    }

    // Accumulate velocity pulses and position corrections globally
    float shiftX = 0.0f, shiftY = 0.0f, shiftZ = 0.0f;
    float shiftVx = 0.0f, shiftVy = 0.0f, shiftVz = 0.0f;

    // ══════════════════════════════════════════════════════════════════════
    // ═══ BLACK HOLE LIFECYCLE (ADSR-Synced Cosmic Evolution) ═══
    // ══════════════════════════════════════════════════════════════════════
    float3 pvec = float3(px, py, pz);
    float r_curr = length(pvec);
    float t = u.envelopeProgress; // Progress within current phase [0→1]
    float lcI = max(u.lifecycleIntensity, 0.001f); // Prevent division by zero
    bool collapsed = false; // Tracks if particle has been force-collapsed into singularity
    bool isSilence = (u.envelopePhase < 0.5f); // Gate for force immunity
    // While the user is spinning the body, the BH lifecycle pulls (gravity,
    // z-damping) yield so the spin is the dominant, clean force — otherwise the
    // competing pulls make it feel like a tug-of-war.
    float spinSuppress = 1.0f - clamp((abs(u.spinX) + abs(u.spinY)) * 0.3f, 0.0f, 1.0f);

    float globalTargetRadius = 0.75f;
    if (u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f) {
        globalTargetRadius = 0.75f * t;
    } else if (u.envelopePhase >= 1.5f && u.envelopePhase < 3.5f) {
        // Linear limit bumped up "a notch" (2.0x instead of 0.9x) to give chords breathing room 
        globalTargetRadius = max(0.75f, lcI * 2.0f);
    } else if (u.envelopePhase >= 3.5f) {
        // Release: ease the target radius DOWN to the silence REST radius
        // (0.75) — NOT to 0. Collapsing to ~0 then snapping back to the rest
        // radius at the silence switch was the "disk → ring" pop. Easing to the
        // rest value makes release land exactly on the existing rest state →
        // one continuous draw-in. Rest state itself is unchanged.
        float sustainR = max(0.75f, lcI * 2.0f);
        globalTargetRadius = mix(sustainR, 0.75f, t);
    }

    // ─── PHASE 0: SILENCE → BLACK HOLE WITH ACCRETION DISK ───────────────
    if (u.envelopePhase < 0.5f) {
        float rLen = r_curr;
        if (rLen > 0.001f) {
            float3 dir = pvec / rLen;

            // ═══ ACCRETION DISK GEOMETRY ═══
            float diskRadius = 0.45f;      // Disk inner-to-outer span
            float diskThickness = u.diskThickness; // Vertical thickness (UI)

            // Project position onto disk plane
            float rXY = sqrt(px * px + py * py);  // Radial in disk plane
            float diskHeight = abs(pz);           // Height above/below disk

            // Distance from ideal disk torus
            float diskRadialDist = abs(rXY - diskRadius);
            float distFromDisk = sqrt(diskRadialDist * diskRadialDist + diskHeight * diskHeight);

            // ═══ MULTI-LAYER FORCES (fixed strength — no amplitude scaling) ═══

            // 1. GRAVITY — DISABLED AT REST. There is NO black-hole gravity before
            // a note is played. The rest state is the full STAR MAP (the box spawn,
            // particles.cpp L=42), held only by the gentle particle↔particle
            // cohesion + SPH pressure later in this kernel (which run every phase).
            // A central pull-to-origin here (the old G=100) instantly balled the
            // whole galaxy into a hole — exactly what we DON'T want at rest. The
            // hole must EMERGE from mass clumping (cohesion) over time, or from the
            // release collapse, never from a hardcoded central attractor.

            // 1b. Z-PLANE DAMPING — DISABLED. It flattened the star map into a thin
            // disk (the accretion-disk look). The rest state is a 3D star map, not
            // a disk; no z-confinement.

            // 2. DISK CONFINEMENT — TEMP DISABLED.
            // Was a hardcoded spring force pulling every particle to a
            // fixed orbital target on a thin xy-plane ring. That ring IS
            // the "2D hardcoded BH" — the shape was defined by code, not
            // emergent from physics. Disabling to see what particles do
            // without an imposed shape.

            // 3. KERR FRAME-DRAGGING — DISABLED.
            // Added a `15/sqrt(rXY)` tangential force ON TOP of the orbital
            // velocity the particles already have from spawn + gravity.
            // At r=1.5 that's ~12 units/s of extra spin vs the ~3.5
            // orbital velocity → particles got over-sped and flung
            // outward, breaking the orbit. The orbital velocity alone
            // (v² = G·r/(r²+r0²), set at spawn, maintained by gravity)
            // already makes particles spin around the BH cleanly.
            // The vertical-shear z-damping it also did is handled by the
            // thin spawn (z σ=0.05) instead.

            // 3b. DENSITY PRESSURE — TEMP DISABLED for Step 1 verification.
            // Was overpowering gravity (pressure scale 12 vs gravity scale 1)
            // and pushing all particles outward → blowing up the Gaussian
            // spawn instead of collapsing it. Re-enable in a later step
            // after we have orbital dynamics holding particles in place.
            if (false /* su.gridSize > 0 */) {
                int cx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
                int cy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
                int cz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
                uint cID = uint((cz * su.gridSize + cy) * su.gridSize + cx);
                uint count = cellCounts[cID];
                if (count > 24u) {
                    // World-space cell-center position
                    float ccx = (float(cx) + 0.5f) * su.cellSize - 1.0f;
                    float ccy = (float(cy) + 0.5f) * su.cellSize - 1.0f;
                    float ccz = (float(cz) + 0.5f) * su.cellSize - 1.0f;
                    float3 outward = float3(px - ccx, py - ccy, pz - ccz);
                    float outLen = length(outward) + 1e-6f;
                    // log2(count/24) gives a smooth ramp from 1 (count=48) up
                    // to ~2.4 (count=128 cap). Pressure scale 12 chosen so
                    // disk confinement (max ~5 vel/frame at target) and
                    // pressure share the same dynamic range.
                    float pressure = log2(float(count) * (1.0f / 24.0f)) * 12.0f;
                    float3 push = (outward / outLen) * pressure;
                    shiftVx += push.x * dt;
                    shiftVy += push.y * dt;
                    shiftVz += push.z * dt;
                    // Heat the particle — dense regions are hot plasma.
                    currentTemp = mix(currentTemp,
                                      1.0f + log2(float(count) * (1.0f / 24.0f)) * 0.8f,
                                      0.15f);
                }
            }

            // 4. GRAVITATIONAL LENSING — removed from particle physics.
            // This force pushed particles perpendicular to the disk plane,
            // creating orbital "yoyo" rings. Lensing is a LIGHT effect handled
            // by the Kerr raytracer in blackhole.metal, not a matter force.

            // 5. HAWKING RADIATION — DISABLED AT REST. In the emergent model
            // there is NO black hole at rest, so nothing radiates: this block
            // was per-frame velocity noise on every particle inside r<2.3,
            // a random walk that (now that rest is undamped for orbits)
            // evaporates exactly the central region where infalling mass must
            // settle to build the hole. Re-introduce later keyed to the
            // EMERGENT bhStrength (Step 3), not to the rest phase.

            // 6. EVENT HORIZON FREEZE — DISABLED.
            // Was a trapdoor: any particle that crossed r < RS got both its
            // velocity AND accumulated shift forces zeroed, then `collapsed`
            // flag set. Disk confinement (block 2) is gated `if (rLen > RS)`
            // so it couldn't rescue trapped particles. Result: particles
            // drifted into RS over time, accumulated there, became invisible
            // via RS_CULL in render.metal. The visible field decayed away.
            // Removing the freeze lets particles pass through RS freely;
            // RS_CULL still hides them while inside but they re-emerge on
            // the other side or get pulled back out by disk confinement.

            // ═══ OPTICAL EFFECTS — DELETED (2026-07-07, Jamal: "constant
            // flashing of phase-changing stars — stars must never change
            // state for no reason"). Two scripted heaters from the 0.45-unit
            // posed-disk era ran here EVERY frame AT REST in the ±64 field:
            // (a) diskTemp 5/(rXY+0.2) glow near an origin torus that no
            // longer exists; (b) currentTemp *= (1+approachingVel·0.3) —
            // MULTIPLICATIVE per-frame heating for ~half the field (one
            // xy-angular-momentum sign), exponential until it balanced T⁴
            // cooling at temp≈7 — far above the 2.5 nova threshold. Half the
            // stars slowly ignited and flickered over minutes for no reason.
            // Temperature now comes ONLY from real channels: merge novae,
            // TDE flares, SPH shock heating (uBuffer), T⁴/radiative cooling.
        } else {
            // Particle at exact origin: freeze
            vpx = 0.0f; vpy = 0.0f; vpz = 0.0f;
            collapsed = true;
        }
    }
    // ─── PHASE 1: ATTACK → BIG BANG EXPLOSION ────────────────────────────
    else if (u.envelopePhase < 1.5f) {
        // Cap explosion power
        float explosionPower = (1.0f - t) * 80.0f * min(lcI, 3.0f);

        if (r_curr < 0.001f) {
            // Particle at singularity: initialize random direction
            float theta = noise(id * 3u, u.frameCounter) * M_PI_F * 2.0f;
            float phi = noise(id * 5u, u.frameCounter) * M_PI_F;
            pvec = float3(sin(phi)*cos(theta), sin(phi)*sin(theta), cos(phi));
            r_curr = 1.0f;
        }
        float3 dir = pvec / max(r_curr, 0.001f);
        shiftVx += dir.x * explosionPower * dt;
        shiftVy += dir.y * explosionPower * dt;
        shiftVz += dir.z * explosionPower * dt;

        // Blast wave temperature spike
        currentTemp = mix(8.0f, 2.0f, t);

        // Shockwave ripples
        float waveFront = abs(r_curr - t * 2.0f);
        if (waveFront < 0.3f) {
            float ripple = (0.3f - waveFront) * 20.0f * sin(r_curr * 20.0f - t * 50.0f);
            shiftVx += dir.x * ripple * dt;
            shiftVy += dir.y * ripple * dt;
            shiftVz += dir.z * ripple * dt;
        }
    }
    // ─── PHASE 2/3: DECAY/SUSTAIN → SUN (Radiating Sphere / Plasma) ──────────────
    else if (u.envelopePhase < 3.5f) {
        float targetRadius = globalTargetRadius;
        // ── THE SKIN-MAKER, FOUND (2026-07-19 23:18) ─────────────────────────
        // This "SUN — radiating sphere" stage SPRINGS every particle onto ONE
        // target-radius sphere (×80·lcI) and hard-brakes outward motion — a
        // CONSTRUCTED hollow shell that overpowers the eigenmode, the contrast
        // field and any thermal kick (they're ~2 orders weaker). It is the
        // same 2D-surface-construct class as the retired sphere sculpt. When
        // the cavity EIGENMODE is the organizer (bit23, the default), the
        // shell stands down and the 3D mode + warm trap own the shape.
        // Legacy shell behaviour: SS_NO_EIGENMODE=1.
        bool sunShellOn = !(u.debugFlags & (1u << 23));
        if (r_curr > 0.001f && sunShellOn) {
            float3 dir = pvec / r_curr;
            float displacement = (r_curr - targetRadius);

            // Hard velocity brake: kill outward momentum so particles snap to shell
            // The further past targetRadius, the harder the brake
            float overshoot = max(0.0f, displacement) / (targetRadius + 0.1f);
            float brakeFactor = max(0.05f, 1.0f - overshoot * 3.0f);
            vpx *= brakeFactor;
            vpy *= brakeFactor;
            vpz *= brakeFactor;

            // Strong spring toward shell surface (matched to explosion force)
            float springForce = displacement * 80.0f * lcI;
            shiftVx -= dir.x * springForce * dt;
            shiftVy -= dir.y * springForce * dt;
            shiftVz -= dir.z * springForce * dt;

            // Solar wind: tangential circulation
            float3 galacticUp = normalize(float3(0.3f, 1.0f, 0.2f));
            float3 tangent = cross(galacticUp, dir);
            float circulationSpeed = 8.0f * lcI / (abs(displacement) + 0.5f);
            shiftVx += tangent.x * circulationSpeed * dt;
            shiftVy += tangent.y * circulationSpeed * dt;
            shiftVz += tangent.z * circulationSpeed * dt;

            // Photosphere temperature
            currentTemp = mix(currentTemp, 1.5f, 0.1f * dt);

            // ── Self-Oscillation Feature (Empty Space Resonance) ──
            // When lcI > 1.25 (filter/LFO resonance), standing wave plasma filaments emerge
            if (lcI > 1.25f) {
                // Cap resonance force to prevent string webbing logic tears
                float resonance = min(lcI - 1.25f, 5.0f);
                float ribs = sin(r_curr * 15.0f - u.time * 25.0f) * cos(atan2(py, px) * 8.0f);
                float waveForce = ribs * 150.0f * resonance;
                shiftVx += dir.x * waveForce * dt;
                shiftVy += dir.y * waveForce * dt;
                shiftVz += dir.z * waveForce * dt;
                
                float filament = sin(pz * 20.0f) * 100.0f * resonance;
                shiftVx += tangent.x * filament * dt;
                shiftVy += tangent.y * filament * dt;
                
                currentTemp += 5.0f * resonance * dt;
            }
        }
    }
    // ─── PHASE 4: RELEASE → EMERGENT GRAVITATIONAL COLLAPSE ──────────────
    // The scripted collapse is GONE (2026-06-13 audit, step 2, Jamal's call).
    // The old block applied a hardcoded G=100 pull straight to the ORIGIN +
    // z-plane flattening + a Kerr spiral, all ramped by release progress t.
    // A fixed central attractor erases angular momentum → matter arrives with
    // L≈0 and can only form a dead BALL, never a disk — and it contradicted
    // the emergent-BH model (the hole is the SUM of the mass falling in, not a
    // scripted point). Release is now the SAME physics as every other phase:
    // the always-on self-gravity (below, toward the real COM) pulls matter in,
    // and the heavy release drag (baseFric = pow(0.95,dt), set above) bleeds
    // orbital energy so the field spirals onto the hole over ~tens of seconds
    // while KEEPING its angular momentum → a real inspiral into the disk.
    else {
        if (r_curr > 0.001f) {
            // Gentle radiative cooling as the field collapses (kept — it is a
            // temperature readout, not a force, so it can't kill orbits).
            currentTemp *= (1.0f - t * 0.05f);
        }
    }

    // ESCAPER RECYCLE — closes the energy budget. The old "snapback"
    // (pos ×0.5, outward velocity KEPT) made runaways ping-pong in shells
    // at r≈500-1000: the glowing line/wall on screen. Now an escaper
    // re-enters the simulation as fresh COLD infall at its star-map home —
    // mass conserved, the note's escape energy is removed (radiated), and
    // the recycled star becomes food for the hole.
    if (r_curr > 1000.0f) {
        float r_home = p.spinW.x;
        float theta  = as_type<float>(p.entanglement.z);
        float aphi   = as_type<float>(p.entanglement.w);
        float st = sin(theta);
        float3 home = r_home * float3(st * cos(aphi), st * sin(aphi), cos(theta));
        // Re-enter ON ORBIT (Kepler about +Y, same as spawn) — the cold
        // (v=0) respawn was the unnormalized variable behind the polar
        // "pebbles": a star with no angular momentum free-falls STRAIGHT
        // at the hole, and polar homes rained down the axis into the
        // top/bottom pebble clouds (the old Garganty classic).
        float GM1 = u.gravGM;
        float vmag = sqrt(GM1 / max(r_home, 0.5f)) * dt;
        float lxz = length(home.xz);
        float3 vK = (lxz > 1e-4f)
                        ? float3(home.z, 0.0f, -home.x) / lxz * vmag
                        : float3(0.0f);
        p.prevW = float4(home - vK, 0.0f);
        p.posW  = float4(home, mass);
        p.velW  = float4(0.0f);
        return;
    }
    pvec = float3(px, py, pz);
    r_curr = length(pvec);

    // ── DEAD-COMPUTE — A CORPSE STOPS HERE (his order 2026-08-13 01:02:00) ───
    // Jamal: "PARTICLES THAT ARE DEAD MUST NOT BE COMPUTED. if a particle is in
    // the bh its gone. no need to compute it and we still do."
    // This is placed HERE, not at the top of the kernel, and the placement is
    // the whole design — three things above this line must still run for a dead
    // particle and every one of them is a live feature:
    //   • SUSTAIN REBIRTH (:704) fires ONLY on mass<=0.001 — the abyss gives its
    //     light back. An early-out above it kills the feature outright.
    //   • RESET (:829, debugFlags bit8) re-draws position AND restores
    //     mass = imfMassOfId(id) — that is what destroys the hole. Skipping it
    //     would make "reset" a lie about the state again (2026-08-03).
    //   • ESCAPER RECYCLE (:1131) is what actually empties the park site: a
    //     corpse is parked at 4000+id%1024 (r~6928) and r_curr here is still the
    //     ENTRY radius from :862, so the frame AFTER it dies it is teleported to
    //     its star-map home at mass 0. Leaving corpses at 4000 would collapse
    //     them all into one clamped corner cell of the spatial hash.
    // BELOW this line a dead particle produces NOTHING, verified three ways:
    //   • the write-back (:3427) is gated `if (mass > 0.0f)` — every px/py/pz it
    //     computes from here down is already discarded;
    //   • every atomic in :1156-3425 (seedAccum, accDiag, sphClosure) sits
    //     inside a mass-gated block — capture :1299, seed-merge :1448,
    //     self-gravity :1606, collisional relaxation :2211;
    //   • it writes to no other particle's slot.
    // So this return is OUTPUT-EQUIVALENT by construction and removes only work.
    // What it removes is not scalar math: the three neighbour scans below are
    // NOT mass-gated and a corpse runs all of them — particle-particle
    // collisions (:2685, 27 cells), the bond network (:2842), and the SPH
    // pressure scan (:2932, O(N*27)). Two of the three are gated on
    // playGate<0.5, i.e. they run AT REST — which is exactly the regime where
    // the kernel's own count says ~46% of the field is corpses (:678).
    // ⚠️ CORRECTS THE BOARD: the DEAD-COMPUTE row says a corpse "walks the
    // entire kernel". It does not — capture, seed-merge, self-gravity and
    // collisional relaxation already refuse it on mass. The row's other claim,
    // that the eaten pile sits at 4000+, is true for exactly one frame.
    if (mass <= 0.001f && !(u.debugFlags & (1u << 28))) return; // TEMP-DIAG SS_NO_DEADSKIP = A/B control

    // ── ERUPTIONS in the hardened areas (magnetic-reconnection / solar-flare) ──
    // Where the Chladni pattern HARDENS (dense nodes), stress builds; past a
    // threshold the node ERUPTS — a sudden outward plasma burst + heat flash,
    // bursting from the dense NODE centre (local splash). A slow per-cell noise
    // clock makes flares INTERMITTENT (pop at different nodes over time, like the
    // sun), not all at once. Only during play (decay/sustain), where it hardens.
    if (su.gridSize > 0 && u.envelopePhase >= 1.5f && u.envelopePhase < 3.5f) {
        int ecx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int ecy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int ecz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        uint ecID = uint((ecz * su.gridSize + ecy) * su.gridSize + ecx);
        // Clamp to the old 128 cap: cellCounts is uncapped now, and the flare
        // stress/temp tuning (log2 ramp 0..~2.7) was built against capped
        // counts — an uncapped 50k cell would flash 11× the intended burst.
        uint ecount = min(cellCounts[ecID], uint(MAX_PER_CELL));
        // ── COLOUR PATH DE-BLOCKED (2026-07-19, Jamal ×2: "colors are low
        // res / on the grid / jump don't fade") — the temp flash used the
        // particle's OWN cell count (one stress per cell = square hue
        // patches) and an instant max() (teleporting hue). The TEMP stress
        // now comes from a TRILINEAR density read (the alias-free pattern of
        // the moments read, :1346) so hue varies continuously across cell
        // faces, and the flash RISES eased (~0.3 s) so colours fade in and
        // decay out. The burst FORCE below keeps the raw per-cell stress +
        // intermittent flare clock — that is motion character, not colour.
        {
            float3 egc = (float3(px, py, pz) + su.halfExtent) * su.invCellSize - 0.5f;
            int3 eb0 = int3(floor(egc));
            float3 efw = clamp(egc - float3(eb0), 0.0f, 1.0f);
            // TRILINEAR FLARE FIELD (2026-07-20 00:24, Jamal: "it's a
            // resolution error obviously" — CORRECT): the flare CLOCK still
            // fired per hash-cell — a whole cell erupted in unison and left
            // its own RECTANGULAR evacuated void (the dark blocks). Density,
            // stress AND the intermittent clock are now all blended across
            // the 8 neighbour cells: eruptions are soft blobs straddling
            // cells; grid-shaped voids are geometrically impossible.
            float eTri = 0.0f, eFlare = 0.0f;
            for (int edz = 0; edz <= 1; edz++)
            for (int edy = 0; edy <= 1; edy++)
            for (int edx = 0; edx <= 1; edx++) {
                int3 ccl = clamp(eb0 + int3(edx, edy, edz), int3(0), int3(su.gridSize - 1));
                uint eID2 = uint((ccl.z * su.gridSize + ccl.y) * su.gridSize + ccl.x);
                float ewt = (edx ? efw.x : 1.0f - efw.x) *
                            (edy ? efw.y : 1.0f - efw.y) *
                            (edz ? efw.z : 1.0f - efw.z);
                float cnt = float(min(cellCounts[eID2], uint(MAX_PER_CELL)));
                eTri += cnt * ewt;
                if (cnt > float(ERUPT_DENSITY)) {
                    float sI = log2(cnt / float(ERUPT_DENSITY));   // 0..~3
                    float fI = noise(eID2 * 2654435761u + 7u,      // per-cell clock,
                                     uint(u.time * 2.0f));         // zero-mean
                    eFlare += max(fI * sI, 0.0f) * ewt;            // smooth field
                }
            }
            if (eTri > float(ERUPT_DENSITY)) {
                float stressT = log2(eTri / float(ERUPT_DENSITY));
                currentTemp = mix(currentTemp,
                                  max(currentTemp, ERUPT_TEMP * stressT), 0.05f);
            }
            if (eFlare > ERUPT_THRESHOLD) {
                // Per-particle direction + magnitude jitter (noise() is
                // already zero-mean [−0.5,0.5]; the ×2−1 remap was the
                // all-negative drift bug, fixed 00:19).
                float3 outward = float3(noise(id,           u.frameCounter + 71u),
                                        noise(id + 7919u,   u.frameCounter + 83u),
                                        noise(id + 104729u, u.frameCounter + 97u));
                outward = outward / (length(outward) + 1e-4f);
                float burst = ERUPT_FORCE * eFlare * 2.0f *
                              (0.5f + noise(id + 31u, u.frameCounter));
                shiftVx += outward.x * burst * dt;
                shiftVy += outward.y * burst * dt;
                shiftVz += outward.z * burst * dt;
            }
        }
    }

    // playGate: 0 at rest → 1 in play. HARD regime (PLAY OVER EVERYTHING): the
    // instant any note sounds, this snaps to 1 — so the entire BH simulation
    // (self-gravity, seed-sink, capture, relaxation, mass-inertia) switches OFF
    // and the velocity cap jumps to full cymatics speed. The old soft ramp
    // (·4, saturating at amp 0.25) left play in a half-gated limbo: cap
    // throttled below full speed ("too slow") + residual center pull. This
    // restores the godray-stable play path (sculpt → cap, every particle an
    // equal tracer, no BH). saturates at amp≈0.025 = any audible note.
    float playGate = smoothstep(0.0f, 0.025f, u.totalAmplitude);

    // ── GRAVITY SUPPORT — the frozen→star-map fix (2026-08-10 16:41:00) ──────
    // His report: the ONE spot that feels off is the handover from the held
    // shape to the star map. Cause, found by reading the chain end to end:
    // self-gravity is scaled by (1 - playGate), and playGate is
    // smoothstep(0, 0.025, amp) — a THRESHOLD, not a ramp. Amplitude sits above
    // 0.025 for the whole hold AND for nearly the whole release (which itself
    // lasts 0.4-1.5 s, scaled by hold length). So gravity is fully OFF the
    // entire time and snaps fully ON in the last few milliseconds, when the
    // amplitude tail finally dives through 2.5%. That snap IS the transition he
    // sees. It is a gate, not a damper.
    //
    // The physical reading, and the reason this is a fix rather than a tweak:
    // while a note sounds, the acoustic field HOLDS THE MATTER UP against the
    // field's own gravity — it is a support term. Support is not a switch; it is
    // proportional to how loud the note still is. So gravity should return in
    // proportion to how much the sound has faded, which is exactly what a real
    // cloud does when its pressure support decays and it collapses under its own
    // weight. Nothing switches, no branch is crossed, one coefficient moves.
    //
    // Separate from playGate ON PURPOSE: playGate also gates collisions, the
    // seed sink, accretion relaxation, mass-inertia and the velocity cap, and
    // this change has no business touching those. Gravity only.
    //
    // ⚖️ The 0.5 band is a FIRST VALUE, not derived — said plainly. Sustain sits
    // at targetAmp × 0.700 (envelope.h:19), so a normal held note is above 0.5
    // and support saturates: THE HELD SHAPE IS UNCHANGED BY THIS. The ramp lives
    // entirely in the release, below half amplitude. Widen it to start the
    // collapse earlier in the release, narrow it to start later.
    // ⭐ Falls out for free: a QUIET note now supports less than a loud one, so
    // it collapses sooner. That is the correct behaviour and nobody asked for it.
    float gravSupport = smoothstep(0.0f, 0.5f, u.totalAmplitude);

    // ── SEED SINK — mass segregation, the express lane ───────────────────────
    // A body 100-1000× the field-star mass sinks to the potential minimum on
    // a dynamical time (Chandrasekhar friction ∝ M — far beyond the resolved
    // drag's stability cap). The minimum is the PINNED ORIGIN by design, so
    // seeds get a bounded spring + velocity damping straight to the centre —
    // measured failure without it: seeds orbited just off the knot, their
    // capture sphere grazed its edge, Mmax froze at ~105 while thousands of
    // stars piled at origin. The seed parks at the centre; the disk spins
    // around it. OFF during play (×(1-playGate)) — this origin spring was the
    // ball pinned dead-center while playing.
    if ((u.bhToggles & 0x10u) && mass >= M_BH_SEED && mass < 1e8f) {  // bit4: origin-pin
        float3 toO = -float3(px, py, pz);
        float3 kick = toO * (0.3f * dt);
        float kl = length(kick);
        if (kl > 0.01f) kick *= 0.01f / kl;          // bounded spring
        // HARD damping: a fast seed overshot the bounded spring and
        // slingshotted — a bright accretion point + trail ribbon roaming
        // the screen as a dotted beam (measured/screenshot). The hole
        // parks; it does not zip across the galaxy.
        float vdamp = min(2.5f * dt, 0.2f);
        float seedGate = 1.0f - playGate;            // OFF while playing
        shiftVx += (kick.x - vpx * vdamp) * seedGate;
        shiftVy += (kick.y - vpy * vdamp) * seedGate;
        shiftVz += (kick.z - vpz * vdamp) * seedGate;
    }

    // ── BLACK-HOLE CAPTURE — victim-initiated accretion (step 3 v2) ──────────
    // If a registered seed is marked in one of my 27 neighbour cells and I'm
    // inside its capture radius (tidal + gravitational focusing), I am eaten:
    // I add my exact mass to the seed's accumulator and die, this thread, no
    // races. Seeds themselves and walls don't get eaten.
    if ((u.bhToggles & 0x4u) && su.gridSize > 0 && mass > 0.001f && mass < M_BH_SEED &&  // bit2: seed capture
        playGate < 0.5f &&                              // no BH accretion while playing
        !(u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f) &&
        fabs(px) < su.halfExtent && fabs(py) < su.halfExtent &&
        fabs(pz) < su.halfExtent) {
        int kcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int kcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int kcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        for (int z = max(0, kcz - 1); z <= min(su.gridSize - 1, kcz + 1); z++) {
            for (int y = max(0, kcy - 1); y <= min(su.gridSize - 1, kcy + 1); y++) {
                for (int x = max(0, kcx - 1); x <= min(su.gridSize - 1, kcx + 1); x++) {
                    uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                    uint slot = cellSeedMap[cID];
                    if (slot == 0u) continue;
                    uint sid2 = seedIds[slot - 1u];
                    if (sid2 == id || sid2 >= uint(u.particleCount)) continue;
                    float mS = particles[sid2].posW.w;
                    if (mS < M_BH_SEED || mS >= 1e8f) continue;
                    float3 sp = particles[sid2].posW.xyz;
                    if (notFinite3(sp)) continue;
                    float3 dS = float3(px, py, pz) - sp;
                    float dS2 = dot(dS, dS);
                    float rt2;
                    if (mS > 5000.0f) {
                        // FORMED-HOLE REGIME: only the PLUNGE ZONE (~3 r_s)
                        // swallows instantly. Matter in the tidal zone gets
                        // DISRUPTED, not eaten — the debris keeps its angular
                        // momentum and ORBITS: that is the accretion disk.
                        // With tidal capture all the way up (capped 1.4 sim),
                        // the hole vacuumed its own disk region — "no disk,
                        // just a few particles around a black screen".
                        //
                        // PROPORTION LOCK (2026-06-13 audit, step 1): the
                        // on-screen shadow and the disk's inner edge must come
                        // from ONE mass or they read as two layered bodies.
                        // The lens shadow radius is 2.6·r_s(u.bhMass) — the
                        // enclosure mass (renderer.mm). Drive the plunge r_s
                        // off that SAME u.bhMass (not the seed's own mass mS),
                        // so disk inner edge (3·r_s) and shadow (2.6·r_s) hug
                        // at the fixed Gargantua ratio and track together as
                        // the hole eats. Falls back to mS if the enclosure
                        // readback hasn't caught the core yet.
                        float mHole = max(u.bhMass, mS);
                        // kRsSimPerMsun — KEEP IN SYNC with units.h (conservation
                        // anchor 2026-06-13). Shaders can't include the header.
                        float rs = mHole * 1.6825e-6f;  // Schwarzschild, sim units
                        float rc = max(3.0f * rs, 0.02f);
                        rt2 = rc * rc;
                    } else {
                        // GROWTH REGIME (small seed): tidal radius + grav
                        // focusing — slow passers-by captured from far beyond
                        // contact; this is what powers the runaway to forming.
                        float rt = 1.5f * MERGE_RSUN_SIM * pow(mass, 0.8f) *
                                   pow(mS / mass, 1.0f / 3.0f);
                        // ⏱️ v = displacement / dt. Was x120, i.e. it assumed
                        // dt = 1/120 s. The real step is 0.0165 (60.6/s), and
                        // under warp dt = 0.0165*warp — so the old constant made
                        // vrel^2 wrong by 3.92*warp^2 and CRUSHED the focusing
                        // term below (it divides by vrel2). 1/dt is warp-invariant.
                        float invDtS = 1.0f / max(u.dt, 1e-6f);
                        float3 dvS = (float3(vpx, vpy, vpz) -
                                      (sp - particles[sid2].prevW.xyz)) * invDtS;
                        float vrel2 = max(dot(dvS, dvS), 1e-4f);
                        float G1s = u.gravGM / max(u.massTotal, 1.0f);
                        rt2 = rt * rt + rt * (2.0f * G1s * mS) / vrel2;
                        float reach = 1.4f * su.cellSize;
                        rt2 = min(rt2, reach * reach);
                    }
                    if (dS2 >= rt2) continue;
                    // ── VISCOUS RATE LIMIT (2026-08-08) ─────────────────────
                    // The hole cannot swallow faster than its own viscous
                    // timescale allows. Budget = MDOT · dt for THIS frame.
                    // 🚨 CHECKED HERE, BEFORE THE VICTIM DIES — deliberately.
                    // Clamping later, at the credit step in seed_apply, would
                    // DESTROY the excess: the victim is already dead by then
                    // and its mass would vanish from the books. Refusing the
                    // meal instead leaves the star alive and orbiting, so mass
                    // is conserved exactly and it simply gets eaten later.
                    // ⚠️ HARD limit, via compare-exchange. The first version of
                    // this used a plain load-then-add, which is NOT atomic as a
                    // pair: every thread could observe "budget free" in the same
                    // instant and all of them would then add. MEASURED overshoot
                    // was 1.90× (4,780 M☉/wall-s against the derived 2,517).
                    // A thread must now CLAIM the budget, not merely observe it
                    // free — the add only lands if the plate is still what we
                    // read. Residual overshoot is at most ONE victim (≤50 M☉),
                    // because the last meal that fits may cross the line.
                    // ⛔ OUTCOME BOUND KILLED 2026-08-31 16:10:25, his order —
                    // see the block at the top of this file. The feedback taper
                    // fFb died with it, so the budget is the raw rate limit.
                    // MDOT stays: it bounds dM/dt, never M. The CAS above is
                    // UNCHANGED — it is what makes the rate limit hard.
                    uint  budgetFx = uint(max(MDOT_MSUN_PER_WALLSEC * dt, 0.0f) * 64.0f);
                    uint  myFx     = uint(mass * 64.0f + 0.5f);
                    device atomic_uint *plate = &seedAccum[(slot - 1u) * 8u + 0u];
                    uint cur = atomic_load_explicit(plate, memory_order_relaxed);
                    bool reserved = false;
                    while (cur < budgetFx) {
                        // On failure Metal writes the observed value back into
                        // `cur`, so the loop retries against fresh state.
                        if (atomic_compare_exchange_weak_explicit(
                                plate, &cur, cur + myFx,
                                memory_order_relaxed, memory_order_relaxed)) {
                            reserved = true;
                            break;
                        }
                    }
                    if (!reserved) continue;   // hole is full this frame
                    // EATEN: mass already claimed on the plate by the CAS above
                    // (do NOT fetch_add word 0 again — that would double-count).
                    atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 8u + 1u],
                                              1u, memory_order_relaxed);
                    // MOMENTUM LEDGER (2026-07-07): my m·v goes with my mass —
                    // seed_apply re-derives the seed's velocity from the sum,
                    // so eating no longer creates momentum from nothing. Raw
                    // per-frame displacement (pos−prev), the same velocity
                    // definition seed_apply uses; signed fixed-point ×65536
                    // via two's-complement wrapping atomic adds.
                    atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 8u + 2u],
                        uint(int(mass * (px - prevX) * 65536.0f)), memory_order_relaxed);
                    atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 8u + 3u],
                        uint(int(mass * (py - prevY) * 65536.0f)), memory_order_relaxed);
                    atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 8u + 4u],
                        uint(int(mass * (pz - prevZ) * 65536.0f)), memory_order_relaxed);
                    // KE rides along: seed_apply books the exact inelastic loss
                    // (thermalized energy) → drives the TDE flare.
                    {
                        float3 dvv = float3(px - prevX, py - prevY, pz - prevZ);
                        atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 8u + 5u],
                            uint(0.5f * mass * dot(dvv, dvv) * 65536.0f + 0.5f),
                            memory_order_relaxed);
                    }
                    float park = 4000.0f + float(id % 1024);
                    p.posW = float4(park, park, park, 0.0f);
                    p.prevW = float4(park, park, park, p.prevW.w);
                    return;
                }
            }
        }
    }

    // ── SEED ↔ SEED MERGE — runaway to ONE dominant central mass ─────────────
    // Seeds (M≥M_BH_SEED) eat STARS above, but until now NEVER each other (the
    // capture gated victims to mass<M_BH_SEED). So heavy mass fragmented into
    // many separate seeds that PILE into a central "blob" and never ran away to
    // a single giant → no geometric BH ever formed (Jamal 2026-06-25 diagnosis:
    // seeds=866, biggest body crawling because it only ate small stars). US2
    // rule: when two bodies overlap the SMALLER is absorbed by the LARGER
    // (larger keeps identity). Strict ordering (mS>mass, ties broken by id) →
    // exactly ONE victim per pair, no mutual death, no race. Merge radius ≈ 1
    // grid cell: below the grid resolution two seeds are unresolvable as
    // distinct bodies, so they coalesce — this is what produces the runaway to
    // one giant and, with it, the geometric BH pop. Same phase/domain guards,
    // atomic accumulator and park-on-death as the star capture above.
    if ((u.bhToggles & 0x8u) && su.gridSize > 0 && mass >= M_BH_SEED && mass < 1e8f &&  // bit3: seed-seed merge
        playGate < 0.5f &&
        !(u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f) &&
        fabs(px) < su.halfExtent && fabs(py) < su.halfExtent &&
        fabs(pz) < su.halfExtent) {
        int scx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int scy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int scz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        float mergeReach = 1.4f * su.cellSize;
        float mergeR2 = mergeReach * mergeReach;
        for (int z = max(0, scz - 1); z <= min(su.gridSize - 1, scz + 1); z++) {
            for (int y = max(0, scy - 1); y <= min(su.gridSize - 1, scy + 1); y++) {
                for (int x = max(0, scx - 1); x <= min(su.gridSize - 1, scx + 1); x++) {
                    uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                    uint slot = cellSeedMap[cID];
                    if (slot == 0u) continue;
                    uint sid2 = seedIds[slot - 1u];
                    if (sid2 == id || sid2 >= uint(u.particleCount)) continue;
                    float mS = particles[sid2].posW.w;
                    if (mS < M_BH_SEED || mS >= 1e8f) continue;
                    // larger-wins identity rule (strict, id tiebreak): I survive
                    // only if I'm the bigger one — else I'm the victim.
                    bool iAmVictim = (mS > mass) || (mS == mass && sid2 < id);
                    if (!iAmVictim) continue;
                    float3 sp = particles[sid2].posW.xyz;
                    if (notFinite3(sp)) continue;
                    float3 dS = float3(px, py, pz) - sp;
                    if (dot(dS, dS) >= mergeR2) continue;
                    // ── THE MERGE MUST FIT UNDER THE CEILING (A1″, 2026-08-13) ──
                    // History, because both earlier versions were wrong in ways
                    // that are easy to re-introduce:
                    //   v1 — a plain fetch_add: no budget, no CAS, no taper. Both
                    //        the 2026-08-08 rate limit and the 2026-08-11 outcome
                    //        bound were invisible to it. MEASURED: Mmax 32,383.6 →
                    //        64,767.2, exactly 2×, in one frame.
                    //   v2 — the capture path's CAS copied verbatim: budget
                    //        MDOT·dt·fFb, ENTRY test `mcur < budgetMx`. MEASURED on
                    //        his play run 2026-08-13 00:59: mrg=1902/10/1892 — 99.5%
                    //        refused, and the 10 that landed still put Mmax at
                    //        185,710.7 against a 135,113 bound = 137%.
                    // ⭐ WHY v2 FAILED, and it is a property not an accident: an
                    // ENTRY test asks "is the plate under budget?" and then adds
                    // whatever it likes. The capture path can live with that — its
                    // overshoot is one star, ≤50 M☉. Here the victim is a SEED, so
                    // the overshoot is the whole bug: a merge starting at half the
                    // ceiling lands at the ceiling, and the next one doubles past it.
                    // A 99.5% refusal rate is not a bound, it is a lottery.
                    // ⭐ THE FIT TEST. Two changes, both deliberate:
                    //   1. BUDGET IS HEADROOM, NOT MDOT. A BH↔BH merger is
                    //      DYNAMICAL — there is no disc to drain, so the viscous
                    //      rate has no physical claim on it. The budget was this
                    //      seed's remaining room to the outcome bound, mBound − mS;
                    //      since 2026-08-31 that bound is DEAD and the budget is the
                    //      fixed-point ceiling instead. (MDOT·dt is ~21–73 M☉/frame
                    //      depending on frame rate, below M_BH_SEED = 50, so keeping
                    //      it here would ban merges outright and with them the
                    //      runaway to one giant.)
                    //   2. THE CLAIM MUST FIT WHOLE: `mcur + myMx <= budgetMx`.
                    //      Overshoot is then exactly zero, by construction, and
                    //      several victims converging on one seed in the same frame
                    //      are bounded TOGETHER on the shared plate rather than each
                    //      against a stale posW.w.
                    // Merges are FREE — the taper was deliberately absent here even
                    // before the bound was killed, because a merge is a discrete
                    // event and a smoothstep on a discrete event is just a slower
                    // lottery. The only refusal left is a claim that does not fit
                    // the fixed point; mass is still conserved exactly.
                    // ⛔ CAP KILLED 2026-08-31 16:10:25, his order. There is no
                    // ceiling to have headroom against any more, so headroom is
                    // simply the largest value the ×64 fixed point can carry.
                    // The refusal is what died; the FIT TEST below is untouched.
                    float headM = 6.0e7f;
                    // min() keeps the ×64 fixed-point inside uint; mass < 1e8 above.
                    uint  budgetMx = uint(min(headM, 6.0e7f) * 64.0f);
                    uint  myMx     = uint(mass * 64.0f + 0.5f);
                    atomic_fetch_add_explicit(&accDiag[2], 1u, memory_order_relaxed); // TEMP A1″: reached the CAS
                    if (myMx > budgetMx) {            // never fits — also guards the
                        atomic_fetch_add_explicit(&accDiag[4], 1u, memory_order_relaxed);
                        continue;                     // unsigned subtraction below
                    }
                    device atomic_uint *mplate = &seedAccum[(slot - 1u) * 8u + 0u];
                    uint mcur = atomic_load_explicit(mplate, memory_order_relaxed);
                    bool mReserved = false;
                    while (mcur <= budgetMx - myMx) {
                        // On failure Metal writes the observed value back into
                        // `mcur`, so the loop retries against fresh state.
                        if (atomic_compare_exchange_weak_explicit(
                                mplate, &mcur, mcur + myMx,
                                memory_order_relaxed, memory_order_relaxed)) {
                            mReserved = true;
                            break;
                        }
                    }
                    if (mReserved == false) {         // would cross the ceiling
                        atomic_fetch_add_explicit(&accDiag[4], 1u, memory_order_relaxed); // TEMP A1″: refused
                        continue;
                    }
                    atomic_fetch_add_explicit(&accDiag[3], 1u, memory_order_relaxed);     // TEMP A1″: landed
                    // MERGED: mass already claimed on the plate by the CAS above
                    // (do NOT fetch_add word 0 again — that would double-count).
                    atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 8u + 1u],
                                              1u, memory_order_relaxed);
                    // Momentum travels with the mass (same ledger as star capture).
                    atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 8u + 2u],
                        uint(int(mass * (px - prevX) * 65536.0f)), memory_order_relaxed);
                    atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 8u + 3u],
                        uint(int(mass * (py - prevY) * 65536.0f)), memory_order_relaxed);
                    atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 8u + 4u],
                        uint(int(mass * (pz - prevZ) * 65536.0f)), memory_order_relaxed);
                    // KE rides along: seed_apply books the exact inelastic loss
                    // (thermalized energy) → drives the TDE flare.
                    {
                        float3 dvv = float3(px - prevX, py - prevY, pz - prevZ);
                        atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 8u + 5u],
                            uint(0.5f * mass * dot(dvv, dvv) * 65536.0f + 0.5f),
                            memory_order_relaxed);
                    }
                    float park = 4000.0f + float(id % 1024);
                    p.posW = float4(park, park, park, 0.0f);
                    p.prevW = float4(park, park, park, p.prevW.w);
                    return;
                }
            }
        }
    }

    // ── SELF-GRAVITY (always-on, EVERY phase — the emergent-BH engine) ───────
    // Real Newtonian gravity replaces the old cohesion spring: every star falls
    // toward the rest of the mass, so the galaxy accretes on its own — no note
    // required, no phase gate, no scripted central attractor. Stars collide,
    // clump, and the centre piles up until the density itself births the hole.
    // Barnes-Hut style split on the existing O(N) grid (no pairwise scan):
    //   NEAR = the 3×3×3 neighbour cells, each a point mass at its sampled
    //          centroid (local clumping — star↔star attraction). Cell mass is
    //          cellMass — the UNCAPPED Σ of REAL per-star IMF masses in M_sun
    //          (count_cells, fixed-point ×64), so piled-up mass really pulls
    //          harder and a heavy star counts for what it weighs (the
    //          centroid's .w still caps at 32 samples; only the POSITION is
    //          sampled, the mass is exact).
    //   FAR  = the rest of the galaxy as ONE monopole at the global COM
    //          (mass-weighted, from reduce_stats, 1-frame lag), near cells
    //          subtracted so mass isn't counted twice.
    // Stars carry their REAL Kroupa-IMF mass in posW.w (mean ≈ 0.30 M_sun);
    // u.massTotal = Σ masses and gravGM = gmSim(massTotal), both derived from
    // the Sgr A* anchor (units.h). Plummer ε² softening for numerics only.
    // MUST run BEFORE the lifecycle capture below — the silence-immunity
    // restore wipes everything after it, and gravity must act at rest.
    if (mass > 0.001f && mass < 1e8f && u.gravGM > 0.0f &&
        gravSupport < 0.999f) {  // incl. BH seeds. Was `playGate < 0.5f`: skip the
                            // near-field scan while playing (running + zeroing the
                            // result = wasted compute). Now keyed to gravSupport so
                            // the scan RESUMES as support fades through the release
                            // instead of staying skipped until the amplitude tail.
                            // Full support (held note) still skips exactly as before,
                            // so the play-path cost is unchanged.
        float Mtot = max(u.massTotal, 1.0f);
        float G1   = u.gravGM / Mtot;            // GM of ONE solar mass
        float3 gpos = float3(px, py, pz);
        float3 gacc = float3(0.0f);
        // Hoisted (shared by the PM branch below, the legacy near loop, and friction).
        float nearM = 0.0f;
        float3 nearMP = float3(0.0f);
        bool hashFresh = !(u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f);

        // ── PM GRAVITY (bit10): gacc = −∇Φ from the Poisson solve (poisson_sor) ─
        // The honest energy-conserving self-gravity. Replaces the per-frame
        // near-centroid + far-COM attractors — a TIME-VARYING potential that
        // injected energy every frame and pumped the cold cluster to the speed
        // cap (proven by 3-way isolation 2026-06-30). Φ is a real field on the
        // 128³ grid; central differences give a conservative force.
        if (u.bhToggles & 0x400u) {
            if (hashFresh && su.gridSize > 0 &&
                fabs(px) < su.halfExtent && fabs(py) < su.halfExtent &&
                fabs(pz) < su.halfExtent) {
                // ── TRILINEAR (CIC) FORCE INTERPOLATION — board item 13 ─────
                // 🚨 THIS READ USED TO BE NEAREST-CELL, AND HE COULD SEE IT.
                // His sighting 2026-08-13 01:21:36, at 64× holding a low C:
                // "you see the grid, the boxes" — sharp axis-aligned blocks
                // across the whole field. That was this line: the particle's
                // cell came from a truncating int cast and ∇Φ was evaluated on
                // THAT ONE CELL, so every particle inside a 128³ cell received
                // the IDENTICAL acceleration vector and a cell's worth of matter
                // translated as a rigid block. The grid, drawn in stars.
                // ⭐ AND IT WAS A KERNEL MISMATCH, the classic particle-mesh
                // blunder: mass is deposited CIC (the moments deposit) but the
                // force was read back NGP. Deposit and interpolation kernels
                // must MATCH in a PM code or you get exactly this — grid
                // imprinting, self-forces, momentum error. The codebase already
                // knew the pattern: the density and flare fields are read
                // trilinear at :1175 and :1184 and the comment there calls
                // trilinear "the alias-free pattern". Gravity was the one site
                // that skipped it.
                // ⚠️ WHY HIS TWO CONDITIONS REVEALED IT and normal play does not:
                // the Poisson solve is gated REST-ONLY (renderer.mm:2349,
                // totalAmplitude < 0.02) with Φ warm-started, so holding a note
                // means gravity reads a FROZEN Φ; and at 64× the per-frame
                // displacement is enormous, so an identical-per-cell force
                // integrated over that step moves whole cells coherently instead
                // of averaging out. Neither condition creates the flaw. They
                // stop hiding it.
                // ── The fix: sample ∇Φ at the 8 surrounding CELL CENTRES and
                // trilinearly weight them with the same weights CIC uses to lay
                // the mass down. Cell i's centre is at (i + 0.5) in grid units,
                // hence the −0.5 shift before the floor.
                // COST, stated honestly: 8 cells × 6 taps = 48 Φ reads per
                // particle, against 6 before. [PERF] (board item 12, added
                // minutes earlier for exactly this) is the instrument — baseline
                // idle before this change was ~31–36 fps, worst frame 54–99 ms.
                int Ng = su.gridSize;
                float gx = (px + su.halfExtent) * su.invCellSize - 0.5f;
                float gy = (py + su.halfExtent) * su.invCellSize - 0.5f;
                float gz = (pz + su.halfExtent) * su.invCellSize - 0.5f;
                // i0+1 must still leave room for the ±1 stencil → clamp to Ng-3.
                int i0 = clamp(int(floor(gx)), 1, Ng - 3);
                int j0 = clamp(int(floor(gy)), 1, Ng - 3);
                int k0 = clamp(int(floor(gz)), 1, Ng - 3);
                float fx = clamp(gx - float(i0), 0.0f, 1.0f);
                float fy = clamp(gy - float(j0), 0.0f, 1.0f);
                float fz = clamp(gz - float(k0), 0.0f, 1.0f);
                float inv2h = 0.5f * su.invCellSize;          // 1/(2h)
                float3 gsum = float3(0.0f);
                for (int dz = 0; dz < 2; dz++) {
                    float wz = dz ? fz : (1.0f - fz);
                    for (int dy = 0; dy < 2; dy++) {
                        float wy = dy ? fy : (1.0f - fy);
                        for (int dx = 0; dx < 2; dx++) {
                            float w = wz * wy * (dx ? fx : (1.0f - fx));
                            uint c = uint((((k0 + dz) * Ng) + (j0 + dy)) * Ng
                                          + (i0 + dx));
                            gsum += w * float3(
                                phi[c + 1u]            - phi[c - 1u],
                                phi[c + uint(Ng)]      - phi[c - uint(Ng)],
                                phi[c + uint(Ng * Ng)] - phi[c - uint(Ng * Ng)]);
                        }
                    }
                }
                gacc = -gsum * inv2h;                         // a = −∇Φ (attractive)
            }
        } else {

        // ── HARD-CODED CENTRAL SMBH (Sgr A*) at the origin (2026-06-22) ──────────
        // The dominant mass the whole cluster ORBITS → fast clean Keplerian orbits
        // around a real, pinned centre (replaces the diffuse 32-min self-collapse
        // that read as "everything sucked to the middle"). centerGM = gmSim(4.297e6
        // M☉) ≫ the field's GM, so it sets the orbits; the field self-gravity below
        // is the secondary star↔star clumping. Small ε (point mass); the c·dt gkick
        // cap below keeps deep infall relativistically bounded.
        // Central SMBH single-kick path (origin). When adaptive sub-step (bit9) is
        // ON, the central + far monopoles are integrated together below instead, so
        // skip adding central to gacc here.
        if ((u.bhToggles & 0x2u) && !(u.bhToggles & 0x200u)) { // bit1, non-adaptive
            float3 toCen = -gpos;
            float dc2 = dot(gpos, gpos) + 0.05f;
            gacc += toCen * (u.centerGM * rsqrt(dc2) / dc2);
        }

        // NEAR field. Skip during attack (hash not rebuilt there → stale
        // centroids) and outside the hash extent (binning clamps to edge
        // cells, meaningless for this particle → monopole only).
        // (nearM / nearMP / hashFresh hoisted above the PM branch.)
        if ((u.bhToggles & 0x1u) && su.gridSize > 0 && hashFresh &&  // bit0: field self-gravity
            fabs(px) < su.halfExtent && fabs(py) < su.halfExtent &&
            fabs(px) < su.halfExtent && fabs(py) < su.halfExtent &&
            fabs(pz) < su.halfExtent) {
            int gcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
            int gcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
            int gcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
            // Plummer softening ε ≈ ONE cell (was 2·cell = over-softened,
            // 2026-06-13 audit). ε²=(2cell)² heavily flattened gravity within
            // ~2 sim of the core at rest extent (cellSize 1.0) → matter could
            // not concentrate below ~2 sim, far above any r_s scale. ε≈cell is
            // the standard N-body choice and lets the core densify tighter
            // (denser disk, the science gets closer). NOTE: the true limiter to
            // real geometric formation is grid RESOLUTION — cellSize 1.0 (±64
            // grid) cannot resolve r_s≈0.04 sim; that needs near-core mesh
            // refinement (AMR), an architectural change, not a constant. The
            // GKICK_MAX cap below stays (it's needed in play extent where cells
            // are tiny; at rest it doesn't bite).
            float cellSoftFloor = 1.0f * su.cellSize * su.cellSize;  // ε² ≈ cell²
            for (int z = max(0, gcz - 1); z <= min(su.gridSize - 1, gcz + 1); z++) {
                for (int y = max(0, gcy - 1); y <= min(su.gridSize - 1, gcy + 1); y++) {
                    for (int x = max(0, gcx - 1); x <= min(su.gridSize - 1, gcx + 1); x++) {
                        uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                        // True cell mass in M_sun (fixed-point ×64 → float)
                        float cm = float(cellMass[cID]) * (1.0f / 64.0f);
                        if (cm < 0.04f) continue;            // < half a red dwarf
                        float3 cpos = cellCentroids[cID].xyz;
                        if (notFinite3(cpos)) continue;      // poisoned cell: don't ingest
                        nearM  += cm;
                        nearMP += cpos * cm;
                        float3 toC = cpos - gpos;
                        // MASS-ADAPTIVE Plummer softening (2026-06-25). A heavy
                        // cell's kick must not SATURATE the c·dt gkick cap below,
                        // or stars passing the cell get LAUNCHED at c instead of
                        // deflecting → the field evaporates (meanR 65→187 once
                        // seed-merge built a 140k M giant; the documented
                        // "slingshot heating"). Peak kick = G1·cm/ε²·dt²; bound
                        // it to ≤¼·c·dt by ε² ≥ 4·G1·cm·dt/c. Floored at the cell
                        // scale so light cells (the star field) are UNCHANGED;
                        // only massive bodies soften. Physical: gravity is
                        // resolution-limited — a body can't deliver a kick
                        // sharper than the per-step light limit can resolve.
                        float softN = max(cellSoftFloor,
                                          4.0f * G1 * cm * dt / max(u.speedCap, 1e-6f));
                        float  d2  = dot(toC, toC) + softN;
                        // Single-kick near gravity ONLY when NOT adaptive-substepping.
                        // When bit9 is on, the near clump is integrated in the sub-step
                        // below (via near-COM) so a star curves around it instead of
                        // taking one saturated c·dt kick → ejection.
                        if (!(u.bhToggles & 0x200u))
                            gacc += toC * (G1 * cm * rsqrt(d2) / d2); // GM_c/(d²+ε²)^1.5
                    }
                }
            }
        }

        // FAR field: everything not in the near cells, as one monopole.
        float farM = max(Mtot - nearM, 0.0f);
        bool  farOn = (u.bhToggles & 0x1u) && farM > 0.5f;     // bit0: field self-gravity
        float3 farCom = (float3(u.comX, u.comY, u.comZ) * Mtot - nearMP) / max(farM, 1e-6f);
        if (!(u.bhToggles & 0x200u)) {
            // Default single-kick far monopole.
            if (farOn) {
                float3 toC = farCom - gpos;
                float  d2  = dot(toC, toC) + 0.25f;            // ε² far (horizon scale)
                gacc += toC * (G1 * farM * rsqrt(d2) / d2);
            }
        } else {
            // ── ADAPTIVE SUB-STEP (bit9) of the LONG-RANGE attractors ────────────
            // The off-centre collapse blob is the cluster draining radially into its
            // center-of-mass: the fixed-dt monopole kick saturates the c·dt clamp, so
            // velocity becomes pure-radial → no orbit → pile-up. Here the body is
            // mini-integrated through N sub-steps of dt/N against the analytic
            // long-range field = central SMBH (origin, bit1) + far-field COM monopole
            // (bit0), so the pull TURNS the velocity into an orbit around the COM
            // instead of a straight plunge. N grows only when the single-step kick
            // would saturate (else N=1 → no cost). The near-field 27-cell sum stays a
            // single kick in gacc (the unresolved short range — the core blob is the
            // grid-resolution/softening wall, a separate problem). Δv added directly
            // (bypasses the per-kick c·dt clamp; the final c-cap still bounds |v|).
            float GMc = (u.bhToggles & 0x2u) ? u.centerGM : 0.0f;  // central, if on
            float GMf = farOn ? (G1 * farM) : 0.0f;                // far COM monopole
            // NEAR clump as an attractor: the local 27-cell mass at its COM. This is
            // the force that ejects under a single fixed-dt kick; integrated in the
            // sub-step a star CURVES around it (orbits/spirals in) instead of
            // slingshotting out — the real fix for dense collapse without ejection.
            float3 nearCom = nearMP / max(nearM, 1e-6f);
            float  GMn = (nearM > 0.5f && (u.bhToggles & 0x1u)) ? (G1 * nearM) : 0.0f;
            if (GMc > 0.0f || GMf > 0.0f || GMn > 0.0f) {
                float3 a_now = float3(0.0f);
                if (GMc > 0.0f) { float d2 = dot(gpos, gpos) + 0.05f; a_now += (-gpos) * (GMc * rsqrt(d2) / d2); }
                if (GMf > 0.0f) { float3 t = farCom - gpos; float d2 = dot(t, t) + 0.25f; a_now += t * (GMf * rsqrt(d2) / d2); }
                if (GMn > 0.0f) { float3 t = nearCom - gpos; float d2 = dot(t, t) + 0.10f; a_now += t * (GMn * rsqrt(d2) / d2); }
                float k0    = length(a_now) * dt * dt;
                float gkmax = u.speedCap * dt;
                // ── ACCURACY MEASUREMENT (Step 2 slice, the ACTIVE bit9 path) ──
                // k0/gkmax = fraction of a light-step the full-frame kick wants;
                // the N below caps the sub-steps at 32, so k0/gkmax > 8 means
                // accuracy is being lost (the cap is the "runs inaccurate" gap).
                if (gkmax > 1e-12f) {
                    uint rm = uint(min((k0 / gkmax) * 1.0e6f, 4.0e9f)); // ×1e6 fixed-point
                    atomic_fetch_max_explicit(&accDiag[0], rm, memory_order_relaxed);
                }
                int   N     = clamp((int)ceil(k0 / (0.25f * gkmax + 1e-12f)), 1, 32);
                float dts   = dt / (float)N;
                float3 xs = gpos;
                float3 v0 = float3(vpx, vpy, vpz) / dt;            // disp/frame → sim/s
                float3 vs = v0;
                for (int s = 0; s < N; ++s) {
                    float3 acc = float3(0.0f);
                    if (GMc > 0.0f) { float d2 = dot(xs, xs) + 0.05f; acc += (-xs) * (GMc * rsqrt(d2) / d2); }
                    if (GMf > 0.0f) { float3 t = farCom - xs; float d2 = dot(t, t) + 0.25f; acc += t * (GMf * rsqrt(d2) / d2); }
                    if (GMn > 0.0f) { float3 t = nearCom - xs; float d2 = dot(t, t) + 0.10f; acc += t * (GMn * rsqrt(d2) / d2); }
                    vs += acc * dts;                              // semi-implicit (symplectic)
                    xs += vs * dts;
                }
                float3 dv = (vs - v0) * dt;                        // sim/s → disp/frame
                shiftVx += dv.x; shiftVy += dv.y; shiftVz += dv.z;
            }
        }
        }   // ── end else: legacy (non-PM) near/far/substep force ──

        // ── CORE-COLLAPSE COOLING (gravothermal contraction) — bit5 ──────────
        // Real core collapse: dense regions RADIATE orbital energy (collisional
        // / radiative cooling) → lose kinetic support → CONTRACT → density rises
        // → runaway → the crushed core reaches r_s ≥ radius = a real horizon.
        // This is the honest "gravity does its thing → core collapse → black
        // hole" (Jamal), replacing the fake relaxation/seed machinery. Energy
        // changes STATE (kinetic → radiated), it is not deleted. Cooling rate
        // scales with LOCAL density (nearM, mass in the 27 neighbour cells) so
        // only the dense core collapses fast; the diffuse halo orbits free. Bled
        // off the Verlet velocity at finalV via coolMul. Rest-only.
        if (u.bhToggles & 0x20u) {
            // [TEST 2026-06-26] GLOBAL strong cooling (not density-gated): the
            // density-gated version never triggered (diffuse cluster never got
            // dense → chicken-and-egg). Bleed energy everywhere so the cluster
            // loses kinetic support and COLLAPSES → does it reach a horizon
            // (collapse→BH works) or hit the softening/resolution wall? Plus a
            // density boost so the core dissipates hardest.
            float dens = clamp(nearM / 40.0f, 0.0f, 1.0f);
            coolMul = 1.0f - (2.0f + 6.0f * dens) * dt * (1.0f - playGate);
        }

        // dt² — NOT the usual force convention here. shiftV is a PER-FRAME
        // displacement, so a real acceleration [sim/s²] adds a·dt² per frame.
        // The other forces' `a·dt` makes their labels ~1/dt (120×) stronger
        // than written; gravity must be in REAL units so gravGM calibrates
        // physically (and so the Step-5 Sgr A* anchor lands on honest maths).
        // Measured failure without this: GM=3 acted like GM≈360 → radial
        // plunge at ~38 sim/s through the soft core → slingshot heating →
        // the whole star map inflated 4× within seconds.
        //
        // PHYSICAL ACCELERATION BOUND (Phase A2, 2026-06-13 — fully physical).
        // The old flat 0.005/frame clamp was a non-physical throttle on core
        // gravity (it was there to stop the integrator exploding to NaN at
        // extreme density). Now that finalV is capped at the speed of LIGHT,
        // gravity is bounded by real physics instead: a single kick cannot push
        // a particle past c in one step. Cap |gkick| at c·dt (the same physical
        // limit), so strong core gravity drives a real RELATIVISTIC INFALL
        // (matter falls at up to c) rather than creeping at a magic number.
        // Plummer softening keeps gacc finite (d²+ε² > 0), so this can't make
        // inf; the norm-scale is guarded by the finite check.
        // ── ONE-WAY MEMBRANE (2026-07-16, BH deep scan) — THE defining law the
        // sim never had: inside the horizon, time ends for the outside
        // universe. No pressure, no heat, no signal crosses OUTWARD. Until
        // now u.horizonR was uploaded and NEVER READ (deep-scan finding) —
        // matter inside r_h lived as ordinary cap-hot SPH gas, formed a
        // pressure-supported ball at the centre (its surface poking past the
        // black splats = Jamal's crescent), and its fountain pushed matter
        // back OUT of the hole. Inside r < r_h matter is now CAUSALLY DEAD:
        // no dynfric / LTRANS / SPH kicks (gated with !insideHorizon, flag
        // declared at kernel entry), strong damping + inward-only motion
        // (final-kick site), temperature → 0 (dark by physics). Its MASS
        // still counts in the radial profile — the particles ARE the hole
        // (core directive) and r_h stays honest. Centre = u.bh* (the radial
        // profile's own candidate, origin-locked today).

        // ── CHANDRASEKHAR DYNAMICAL FRICTION (RANK-1, the collapse keystone) ──
        // Each star drags against the local stellar background: a_df =
        // −4πG²ρ·lnΛ·m·G(X)·v̂/v², X=|v_pec|/(√2σ). Reinstates two-body
        // relaxation (mass segregation → gravothermal core collapse) that the
        // softened mean field erased. ρ from cellMass, σ from cellVelocities.w
        // (A.1), v_pec = star velocity − local mean. f_relax compresses the real
        // relaxation time (t_cc≈78 Myr ⇒ ~1000 sim-time units watchable) — a
        // time-lapse choice, not a force cheat (per root-cause doc).
        if (!insideHorizon &&
            su.gridSize > 0 && hashFresh && !(u.debugFlags & (1u << 24)) && // TEMP-DIAG SS_PLAY_SKIP=dynfric
            fabs(px) < su.halfExtent && fabs(py) < su.halfExtent &&
            fabs(pz) < su.halfExtent) {
            // HONEST DYNFRIC (2026-07-12 rework — docs/BUG_lines_2026-07-12.md).
            // The old form was the deepest carver of the ruler-straight rest
            // lanes: it dragged every star toward its cell's mean velocity read
            // NEAREST-CELL (a field piecewise-constant at grid granularity) at
            // up to 0.5/frame. Fixes, in order of guilt:
            //  1. TRILINEAR, count-weighted sampling of the mean flow + σ over
            //     the 8 surrounding cell centres → the drag target is smooth in
            //     space, no per-cell discontinuity to condense onto (same class
            //     of fix as the AMR prolongation staircase). ρ plain-trilinear.
            //  2. Rate cap 0.5 → 0.1/frame: e-fold ≥ ~0.08 s ≈ half the core
            //     free-fall time — still binds the collapse (its actual job,
            //     and what the AMR slice-2 BOUNCE needs), integrator-safe.
            //  3. ≥8 effective samples required: a 1–2 star "σ" is noise, not
            //     a background to drag against.
            // The ≤32/cell moments are an effectively RANDOM subsample (scatter
            // keeps atomic-race winners in id order; ids are spatially random),
            // so the estimators are unbiased; 8-cell blending cuts their noise
            // to ~6%, ×0.1 rate → ≤0.6%/frame velocity noise. Fine.
            // ── SAMPLE-POINT DITHER (2026-07-14) — carver #0 NAMED & KILLED ──
            // Ladder-measured (scratchpad ladder_*.bin, seed-42 deterministic):
            // with ALL bhToggles forces off this block alone lays a coherent
            // z-plane seed (−4.6/−4.9/−5.3σ at z≈−7.2/−4.4/−1.4 by ~20 s);
            // bit24-off drops the field to the noise floor and it STAYS there
            // through tick 12. PM gravity then amplifies the seed (−8.4σ), and
            // the dissipative collapse turns it into −40…−48σ Zel'dovich-style
            // pancakes = the 2026-07-14 00:10 "super lines" on Jamal's screen.
            // Mechanism: the trilinear count-weighted moments are still
            // PIECEWISE-SMOOTH ON THE GRID — neighbouring stars sample nearly
            // the SAME biased mean and get kicked in unison → coherent density
            // waves. Cure (textbook PM anti-aliasing / CIC interlacing): dither
            // the SAMPLE POINT ±0.5 cell per particle per frame — the bias
            // decorrelates into incoherent noise the 0.1/frame cap keeps
            // microscopic, while the mean drag (the physics) is unchanged.
            // DITHER RETIRED 2026-07-15: the ±0.5-cell per-particle sample-point
            // dither treated the SYMPTOM (read-side aliasing) and only cut the
            // carver ×1.7→×1.3 (stacked ×4 probes). The real fix is upstream:
            // cic_deposit_moments (spatial_hash.metal) makes the moment field
            // continuous at the SOURCE, so the plain trilinear read is now
            // alias-free. Ladder re-verified on removal (inert ×4 stack at the
            // realization floor, full bed t12 clean).
            float3 gcc = (float3(px, py, pz) + su.halfExtent) * su.invCellSize - 0.5f;
            int3 b0 = int3(floor(gcc));
            float3 fw = clamp(gcc - float3(b0), 0.0f, 1.0f);
            float wSum = 0.0f, sigSum = 0.0f, rhoSum = 0.0f;
            float3 vSum3 = float3(0.0f);
            for (int dz2 = 0; dz2 <= 1; dz2++)
            for (int dy2 = 0; dy2 <= 1; dy2++)
            for (int dx2 = 0; dx2 <= 1; dx2++) {
                int3 cc = clamp(b0 + int3(dx2, dy2, dz2), int3(0), int3(su.gridSize - 1));
                uint cID2 = uint((cc.z * su.gridSize + cc.y) * su.gridSize + cc.x);
                float wt = (dx2 ? fw.x : 1.0f - fw.x) *
                           (dy2 ? fw.y : 1.0f - fw.y) *
                           (dz2 ? fw.z : 1.0f - fw.z);
                rhoSum += float(cellMass[cID2]) * wt;             // mass field: plain trilinear
                float cw = float(min(cellCounts[cID2], 32u));      // moments: weight by sample size
                if (cw < 0.5f) continue;
                float4 cv2 = cellVelocities[cID2];
                vSum3  += cv2.xyz * (wt * cw);
                sigSum += cv2.w   * (wt * cw);
                wSum   += wt * cw;
            }
            if (wSum >= 8.0f) {
                float3 vmeanT = vSum3 / wSum;
                float  sigma  = sigSum / wSum;                    // per-frame dispersion (A.1)
                float  rho    = (rhoSum * (1.0f / 64.0f)) /
                                max(su.cellSize * su.cellSize * su.cellSize, 1e-6f); // M_sun/sim³
                float3 vpec = float3(vpx, vpy, vpz) - vmeanT;      // peculiar velocity (per-frame)
                float  speed = length(vpec);
                if (rho > 1e-4f && sigma > 1e-5f && speed > 1e-6f) {
                    float X    = speed / (1.4142136f * sigma);
                    float Gx   = chandraG(X);
                    const float lnLambda = 13.6f;                     // ln(0.4N), N≈2e6
                    const float fRelax   = 4.0e11f;                   // derived time-compression
                    float speed3 = speed * speed * speed;
                    // Δ(per-frame displ) = a_df·dt²·f_relax; a_df∝dt²/speed³ (v=speed/dt)
                    float coef = (4.0f * 3.14159265f) * G1 * G1 * rho * lnLambda *
                                 mass * Gx * fRelax * (dt * dt * dt * dt) / speed3;
                    coef = min(coef, 0.1f);            // e-fold ≥ ~0.08 s (was 0.5 = the lane hammer)
                    // TWO-ERA TIME AXIS (2026-07-16, see the LTRANS note
                    // below): fRelax=4e11 makes FORMATION watchable; after
                    // the horizon exists the same compression evaporates the
                    // formed disk in minutes ("black nothing"). Disk era =
                    // ×0.1: matter keeps orbiting, feeds as a trickle.
                    if (u.horizonR > 0.0f) coef *= 0.1f;
                    shiftVx -= coef * vpec.x;
                    shiftVy -= coef * vpec.y;
                    shiftVz -= coef * vpec.z;
                }
            }
        }

        // ── α-DISC ANGULAR-MOMENTUM TRANSPORT (bit25, SS_LTRANS) — slice 3 ───
        // THE missing link (state-of-the-union 2026-07-13 §1 link 5): collapse
        // parks in a ROTATION-SUPPORTED ring at r≈2.2–2.8 (measured [SHELLV]
        // vt:vr = 10:1) because nothing moves angular momentum OUTWARD — bit5
        // relaxation is deliberately spin-preserving, dynfric drags toward the
        // rotating mean itself. Real discs accrete because VISCOSITY diffuses
        // momentum between adjacent annuli (Shakura–Sunyaev α-disc): inner
        // matter hands its L to outer matter and sinks. Here: viscous momentum
        // diffusion on the RESOLVED mean flow — Δv̄ = ν·∇²v̄ with the 6-face-
        // neighbour Laplacian of cellVelocities.xyz (same stencil + same
        // empty-neighbour rule as cell_balsara), ν = α·σ·h (σ = local
        // dispersion cellVelocities.w, h = cellSize, α = 0.1 the standard disc
        // value). F_LTRANS compresses the viscous time exactly like fRelax
        // compresses the relaxation time — a time-lapse choice, not a force
        // cheat. Per-frame units: λ = ν/h² = α·σ/h [1/frame], Δ(shiftV) =
        // λ·(Σ₆v̄ₙ − 6v̄c) — the particle's peculiar velocity is untouched;
        // only the shared mean flow diffuses. Symmetric stencil → momentum-
        // conserving to first order. Gates: rest-only, interior cell, all 6
        // face neighbours populated (edge gradients are cloud-edge artifacts),
        // ≥8 stars in the home cell (a 1–2 star mean is noise). Explicit
        // diffusion is stable for 6λ ≤ 1; cap λ at 1/12 (6λ ≤ 0.5).
        if (!insideHorizon &&                     // one-way membrane: no L-drain inside
            (u.debugFlags & (1u << 25)) && su.gridSize > 0 && hashFresh &&
            playGate < 0.5f &&
            fabs(px) < su.halfExtent && fabs(py) < su.halfExtent &&
            fabs(pz) < su.halfExtent) {
            int Nc = su.gridSize;
            int ci = clamp(int((px + su.halfExtent) * su.invCellSize), 0, Nc - 1);
            int cj = clamp(int((py + su.halfExtent) * su.invCellSize), 0, Nc - 1);
            int ck = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, Nc - 1);
            if (ci > 0 && cj > 0 && ck > 0 &&
                ci < Nc - 1 && cj < Nc - 1 && ck < Nc - 1) {
                uint cc  = uint((ck * Nc + cj) * Nc + ci);
                uint lxp = cc + 1u,              lxm = cc - 1u;
                uint lyp = cc + uint(Nc),        lym = cc - uint(Nc);
                uint lzp = cc + uint(Nc * Nc),   lzm = cc - uint(Nc * Nc);
                if (cellCounts[cc] >= 8u &&
                    cellCounts[lxp] != 0u && cellCounts[lxm] != 0u &&
                    cellCounts[lyp] != 0u && cellCounts[lym] != 0u &&
                    cellCounts[lzp] != 0u && cellCounts[lzm] != 0u) {
                    float4 cvc = cellVelocities[cc];
                    // MASS-WEIGHTED, MOMENTUM-CONSERVING exchange (2026-07-15).
                    // The plain Laplacian kicked every particle equally per
                    // CELL, so it only conserved momentum for equal-mass
                    // neighbours — in the condensed field (counts differ
                    // 100×+) the dense fast-rotating disk was dragged toward
                    // its sparse neighbours' slow means far more per unit
                    // mass than the reverse: L was DESTROYED, not
                    // transported, and the infall read as a straight-line
                    // drain (Jamal 2026-07-15: "no orbit spin pull"). Pairwise
                    // weight 2·mₙ/(m_c+mₙ): equal masses → exactly the old
                    // ∇²v̄; near-empty neighbour → ~0 (no L bleed into
                    // vacuum); heavy neighbour → ≤2 (light cells get dragged
                    // along). m_c·Δv_c = −mₙ·Δv_n per face by construction.
                    float mc = max(float(cellMass[cc]), 1.0f);
                    float3 flux = float3(0.0f);
                    for (int f = 0; f < 6; f++) {
                        uint lf = (f == 0) ? lxp : (f == 1) ? lxm :
                                  (f == 2) ? lyp : (f == 3) ? lym :
                                  (f == 4) ? lzp : lzm;
                        float mn = float(cellMass[lf]);
                        float w  = 2.0f * mn / max(mc + mn, 1.0f);
                        flux += w * (cellVelocities[lf].xyz - cvc.xyz);
                    }
                    const float ALPHA_SS = 0.1f;    // Shakura–Sunyaev α
                    const float F_LTRANS = 100.0f;  // time compression (cf. fRelax)
                    float lam = ALPHA_SS * F_LTRANS * cvc.w * su.invCellSize;
                    lam = min(lam, 1.0f / 12.0f);   // explicit-diffusion stability
                    // ── TWO-ERA TIME AXIS (2026-07-16, Jamal's reference:
                    // the NASA SVS disk looks ETERNAL because real accretion
                    // is a TRICKLE — the viscous drain takes ~1e5–1e6 orbital
                    // periods. F_LTRANS=100 was tuned to make FORMATION
                    // watchable in minutes; the same compression drained the
                    // FORMED disk to "black nothing" in minutes too (his
                    // 02:08 screen). Once the horizon EXISTS, drop to
                    // disk-era compression: the queue persists and glows for
                    // the whole session, still feeding as a trickle.
                    // Formation era (r_h = 0) unchanged.
                    if (u.horizonR > 0.0f) lam *= 0.02f;
                    if (!notFinite3(flux)) {
                        shiftVx += lam * flux.x;
                        shiftVy += lam * flux.y;
                        shiftVz += lam * flux.z;
                    }
                }
            }
        }

        // ── AMR FINE FORCE (bit21) — the resolution unlock ───────────────────
        // 🚨 WAS bit15 until 2026-08-22, SHARED with uiTogMetricShadow. The
        // shadow ships default-ON, so this gate was effectively hardwired open
        // and SS_NO_AMR was a lie. See the BH6 note at renderer.mm:1949.
        // Inside the fine box, REPLACE coarse gravity with −∇Φ from the fine
        // 128³ grid (cellSize ~0.031 sim → softening ~0.031, not the coarse
        // 1.0). Blended back to coarse near the boundary so there's no force
        // discontinuity. This is what lets the core concentrate BELOW one coarse
        // cell — the whole point of the nested mesh. Fine Φ is solved (renderer,
        // Slice 1) before this kernel runs. comShift pins the core to the origin
        // where the fine patch sits.
        if (u.bhToggles & 0x200000u) {
            float rrF = length(gpos);
            if (rrF < fsu.halfExtent &&
                fabs(px) < fsu.halfExtent && fabs(py) < fsu.halfExtent &&
                fabs(pz) < fsu.halfExtent) {
                // ── TRILINEAR (CIC) — THE SECOND HALF OF board item 13 ──────
                // 🚨 THE COARSE FIX ALONE DID NOTHING, AND THIS IS WHY. His
                // verdict 2026-08-13 02:40:56 after the coarse grid was made
                // trilinear: "unchanged", boxes still there. This read is the
                // same nearest-cell mistake, and the `mix()` eight lines below
                // makes it AUTHORITATIVE in the core: w = 1 inside 75% of the
                // fine box, so wherever the fine patch covers — which is exactly
                // where the core is and where he sees the blocks — the coarse
                // gradient is discarded entirely. Fixing the coarse grid while
                // the fine grid overrode it fixed nothing he could see.
                // ⭐ AMR IS ON BY DEFAULT (`amrOn = 1` unless SS_NO_AMR,
                // renderer.mm:1896), so this is the live path, not an option.
                // ⭐ RULE THIS PROVES: there were TWO nearest-cell reads of a
                // potential, not one. Before declaring a class of bug fixed,
                // grep for every read of the field — `phi[` AND `finePhi[`.
                int Nf = fsu.gridSize;
                float fgx = (px + fsu.halfExtent) * fsu.invCellSize - 0.5f;
                float fgy = (py + fsu.halfExtent) * fsu.invCellSize - 0.5f;
                float fgz = (pz + fsu.halfExtent) * fsu.invCellSize - 0.5f;
                int fi0 = clamp(int(floor(fgx)), 1, Nf - 3);
                int fj0 = clamp(int(floor(fgy)), 1, Nf - 3);
                int fk0 = clamp(int(floor(fgz)), 1, Nf - 3);
                float ffx = clamp(fgx - float(fi0), 0.0f, 1.0f);
                float ffy = clamp(fgy - float(fj0), 0.0f, 1.0f);
                float ffz = clamp(fgz - float(fk0), 0.0f, 1.0f);
                float finv2h = 0.5f * fsu.invCellSize;      // 1/(2h_fine)
                float3 fsum = float3(0.0f);
                for (int dz = 0; dz < 2; dz++) {
                    float wz = dz ? ffz : (1.0f - ffz);
                    for (int dy = 0; dy < 2; dy++) {
                        float wy = dy ? ffy : (1.0f - ffy);
                        for (int dx = 0; dx < 2; dx++) {
                            float w8 = wz * wy * (dx ? ffx : (1.0f - ffx));
                            uint fc = uint((((fk0 + dz) * Nf) + (fj0 + dy)) * Nf
                                           + (fi0 + dx));
                            fsum += w8 * float3(
                                finePhi[fc + 1u]            - finePhi[fc - 1u],
                                finePhi[fc + uint(Nf)]      - finePhi[fc - uint(Nf)],
                                finePhi[fc + uint(Nf * Nf)] - finePhi[fc - uint(Nf * Nf)]);
                        }
                    }
                }
                float3 gaccFine = -fsum * finv2h;
                float wInner = fsu.halfExtent * 0.75f;      // full fine inside 75% of the box
                float w = clamp((fsu.halfExtent - rrF) /
                                max(fsu.halfExtent - wInner, 1e-4f), 0.0f, 1.0f);
                gacc = mix(gacc, gaccFine, w);
            }
        }

        // ── SPH PRESSURE FORCE (bit11): add the pre-computed pressure accel to
        // gravity so it's applied as a·dt² in the same Verlet kick. At rest with
        // u at the cold floor this is ≈0 (collisionless unchanged); it matters
        // once shocks/heating raise u. sphForce is written by the sph_force pass.
        if ((u.bhToggles & 0x800u) && !insideHorizon) { // membrane: pressure cannot act inside
            gacc += sphForce[id].xyz;
        }

        float3 gkick = gacc * (dt * dt);
        float gkmag = length(gkick);
        float gkmax = u.speedCap * dt;       // c·dt — the physical per-step limit
        // ── ACCURACY MEASUREMENT (Step 2 slice, DIAGNOSTIC ONLY) ─────────────
        // gkmag/gkmax = the fraction of a light-step this single gravity kick
        // WANTS to be before the clamp below truncates it. >0.25 means the
        // existing N-substep threshold is exceeded; >1.0 means the clamp on the
        // next line is firing (the "runs inaccurately" gap). Required accurate
        // sub-steps ≈ ceil(4·ratio). Atomic-max the field-wide worst case ×1000.
        // This does NOT change motion — the clamp below is unchanged.
        if (gkmax > 1e-12f) {
            uint ratioMilli = uint(min((gkmag / gkmax) * 1.0e6f, 4.0e9f)); // ×1e6 fixed-point
            atomic_fetch_max_explicit(&accDiag[0], ratioMilli, memory_order_relaxed);
            if (ratioMilli > 1000000u)   // ratio > 1 → the c·dt clamp fires
                atomic_fetch_add_explicit(&accDiag[1], 1u, memory_order_relaxed);
        }
        if (gkmag > gkmax && gkmag > 1e-12f) gkick *= (gkmax / gkmag);
        gkick *= (1.0f - gravSupport);       // was (1 - playGate): a threshold that
                                             // snapped gravity on at the very end of
                                             // the release. Now gravity returns in
                                             // proportion to how far the sound has
                                             // faded — the support term, see the
                                             // gravSupport comment above.
        // ── SS_TEST_NOPULL (bit26, 2026-07-19 probe) — once the honest hole
        // exists (r_h>0), strip the INWARD radial component of the gravity
        // kick toward it: pure rotation, nothing pulls in. Observe-only
        // experiment; default OFF.
        if ((u.debugFlags & (1u << 26)) && u.horizonR > 0.0f) {
            float3 relBH = float3(px - u.bhX, py - u.bhY, pz - u.bhZ);
            float rb2 = dot(relBH, relBH);
            if (rb2 > 1e-12f) {
                float3 rhat = relBH * rsqrt(rb2);
                float gr = dot(gkick, rhat);
                if (gr < 0.0f) gkick -= gr * rhat;   // remove the inward part only
            }
        }
        shiftVx += gkick.x;
        shiftVy += gkick.y;
        shiftVz += gkick.z;
    }

    // ── COLLISIONAL RELAXATION (always-on — the ACCRETION-DISK force) ────────
    // Dense matter is collisional: stars/gas in a crowded cell exchange
    // momentum until their RANDOM motions thermalize away, while the bulk
    // flow (net rotation = angular momentum) survives. Numerically: relax
    // each star's velocity toward its cell's MEAN velocity, rate ∝ density.
    // Per-cell momentum is conserved exactly (every member relaxes toward
    // the shared mean by the same fraction), so rotation is untouched —
    // dispersion dies, and the gathered ball around the hole settles into a
    // thin rotating DISK in the plane ⊥ its angular momentum. This is how a
    // real accretion disk forms (energy dissipates, L conserved) — physics,
    // not a render aesthetic. Sparse regions (< ~16/cell) feel nothing.
    // Must sit BEFORE the lifecycle capture so it acts at rest.
    if (mass > 0.001f && mass < 1e8f && su.gridSize > 0 &&  // incl. BH seeds
        playGate < 0.5f &&  // SKIP the accretion-relaxation cell scan while playing
        !(u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f) && // attack: hash stale
        fabs(px) < su.halfExtent && fabs(py) < su.halfExtent &&
        fabs(pz) < su.halfExtent) {
        int rcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int rcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int rcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        uint rcID = uint((rcz * su.gridSize + rcy) * su.gridSize + rcx);
        float cnt = float(cellCounts[rcID]);
        if (cnt >= 2.0f) {
            float3 vMean = cellVelocities[rcID].xyz;
            if (!notFinite3(vMean)) {
                // CONTINUOUS in density — no activation cliff. The old
                // smoothstep(16,128) floor was why the post-release remnant
                // wobbled forever: at 1-2 stars/cell dissipation was exactly
                // zero, bound orbits never shrank, and the density needed to
                // wake the sink could never build (chicken-and-egg). Real
                // two-body relaxation has no threshold — its RATE just scales
                // with density (∝ n·σ·v). rate = (cnt/128)·2/s, capped at
                // 2/s: ~0.03/s e-fold in the diffuse remnant (visible sinking
                // within a minute) → runaway as density grows → core collapse
                // → contact mergers → the hole. Needs ≥2 stars (a cell's own
                // mean is a no-op for its only member). Per-cell momentum
                // conserved exactly, as before — rotation survives, random
                // motion thermalizes into the disk.
                // Rate raised 2→6 /s (2026-06-13 RETENTION fix): the radial
                // infall free-falls into the core in ~0.14 s, but a 2/s rate
                // e-folds in 0.5 s — so matter bounced back out before it was
                // damped ("BH forms then vanishes"). 6/s (e-fold ~0.17 s ≈ the
                // free-fall time) damps the radial infall AS it arrives, so the
                // disk circularizes and BINDS at the core instead of bouncing.
                // Still spin-preserving (tangential untouched) → a settling
                // DISK, not a ball; still density-gated (cnt/128) → only the
                // dense core dissipates fast, the diffuse halo orbits free.
                float relax = min(cnt * (1.0f / 128.0f), 1.0f) * (6.0f * dt) * (1.0f - playGate)
                              * ((u.bhToggles & 0x20u) ? 1.0f : 0.0f); // bit5: relaxation damping toggle
                // DYNAMICAL FRICTION / MASS SEGREGATION — the accretion
                // accelerator. Chandrasekhar drag scales LINEARLY with the
                // body's mass: a heavy body dumps its orbital energy into
                // the light background and SINKS to the core — how real
                // massive black holes reach their food. (Measured failure
                // without it: seeds born in the knot coasted off and
                // starved alone — probe read cnt=1, no candidates in
                // reach.) Normalized at the IMF mean (dwarfs unchanged),
                // capped ×8 to stay integrator-safe.
                relax *= clamp(mass * (1.0f / 0.3f), 1.0f, 8.0f);
                float3 dvR = vMean - float3(vpx, vpy, vpz);
                // SPIN-PRESERVING: damp only the RADIAL + VERTICAL parts of
                // the deviation — the TANGENTIAL (orbital, about +Y at the
                // origin-pinned hole) flow survives. Infalling stars keep
                // their angular momentum and spin UP as r shrinks (skater
                // effect) → matter SPIRALS into a fast rotating DISK instead
                // of plunging straight ("spinning pull, not square straight
                // gravity"). Jamal proved the look: fast spin = shadow +
                // rim + streams (2026-06-12 screenshot).
                float rXYt = sqrt(px * px + pz * pz);
                if (rXYt > 1e-4f) {
                    float3 tdir = float3(-pz, 0.0f, px) / rXYt; // orbit about +Y
                    dvR -= tdir * dot(dvR, tdir);   // orbital part untouched (disk, not ball)
                    // (2026-06-13) An α-drag that DESTROYED angular momentum was
                    // tried here and REVERTED (both 0.10 and 0.02): real
                    // viscosity TRANSPORTS L (inner→outer), it doesn't delete it.
                    // Deleting L drops matter below its centrifugal support →
                    // radial plunge → bounce → "BH forms to ~30% then vanishes,
                    // meanR explodes". The correct retention lever is faster
                    // RADIAL dissipation (the rate below): the infall is damped
                    // before it bounces, the disk circularizes and BINDS — no
                    // plunge, no ball. True L-transport accretion is a future
                    // step (cross-cell momentum exchange, not per-particle drag).
                }
                shiftVx += dvR.x * relax;
                shiftVy += dvR.y * relax;
                shiftVz += dvR.z * relax;
            }
        }
    }

    // Save lifecycle-only shifts before the force pipeline contaminates them
    float3 lifecycleShiftV = float3(shiftVx, shiftVy, shiftVz);
    float3 lifecycleShiftP = float3(shiftX, shiftY, shiftZ);

    // Emitter Interactions (Macro forces)
    // PLAY OVER EVERYTHING: while a note sounds, EVERY particle is a weightless
    // cymatics tracer — heavy seeds (the eaten/merged bodies) become mass-1 so
    // they pass the sculpt guard below, feel the note's outward "puke" impulse
    // AND the standing-wave sculpt like every other grain. No body is too heavy
    // to be moved by the keys. At rest they keep their real mass → BH physics
    // (gravity collides them into bodies only off-key). Jamal 2026-06-14.
    float baseMass = (mass > 1000.0f && playGate < 0.5f) ? mass : 1.0f;
    float dynamicMass = baseMass;

    // Safety: Clamp voiceCount to prevent reading beyond buffer or into uninitialized memory
    int numVoices = min((int)u.voiceCount, 16);

    // Track which band exerts strongest force (for per-band color) — declared outside voice block
    int bestBand = 0;
    float bestForce = 0.0f;

    // INERTIA snapshot: the note's sculpt is a FORCE, and F = ma — a star
    // that has eaten its way to 30 M_sun must NOT dance like a red dwarf.
    // The voice block's velocity contribution gets scaled by 1/m below
    // (normalized to the IMF mean 0.3 → the average star feels the old
    // tuning exactly; monsters resist the crush and HOLD THE MIDDLE).
    float3 preVoiceV = float3(shiftVx, shiftVy, shiftVz);

    // CRYSTALLIZE ridge-pull: the PURE up-gradient sculpt direction at this
    // particle (no swirl/breathing/impulse mixed in), set after the voice loop.
    // As hardness→1 below, this REPLACES the grain's dynamics so it condenses
    // onto the exact node ridge (where ∇Y→0 → it stops) → sharp filaments.
    float3 ridgePull = float3(0.0f);

    if (numVoices > 0 && baseMass < 1000.0f) {
        // Polyphony normalizer (the proven 1/sqrt(voiceCount)). Without it a
        // chord stacks every voice's sculpt force N× → particles over-cluster
        // onto the shared nodal lines and blow out to white. This makes total
        // shape force grow as sqrt(N), not N. Single notes (N=1) → 1.0, no change.
        float polyNorm = rsqrt(float(numVoices));
        float massAdd = 0.0f;
        float jitterTotal = 0.0f;
        float Y_total = 0.0f;
        float dynamicMass = baseMass;

        // Accumulators for Phase 18 Chord Webbing
        float sum_Y = 0.0f;
        float sum_dYdth = 0.0f;
        float sum_dYdphi = 0.0f;
        float sum_Y2 = 0.0f;
        float sum_YdYdth = 0.0f;
        float sum_YdYdphi = 0.0f;

        for (int vi = 0; vi < numVoices; vi++) {
            float amp = voices[vi].amplitude;
            if (amp < 0.001f) continue;

            // Global attractive/repulsive forces from the emitter
            float dx = px - voices[vi].emitterX;
            float dy = py - voices[vi].emitterY;
            float dz = pz - voices[vi].emitterZ;
            float r2 = dx * dx + dy * dy + dz * dz + PLANCK_LENGTH_SQ;
            float r = sqrt(r2);
            float th = atan2(dy, dx);
            float phi = acos(clamp(dz / r, -1.0f, 1.0f)); // Polar angle [0, pi]
            
            float m_f = float(voices[vi].m);
            float n_f = float(voices[vi].n);

            // Phase 4: Dynamic Heaviness (E=mc^2)
            float localEnergy = (voices[vi].frequency * amp) / (r2 * 0.5f + 1.0f);
            massAdd += localEnergy * 0.005f; 

            // ── Biot-Savart swirl REMOVED 2026-07-09: the play-stack
            // rationalization sweep (SS_PLAY_SKIP) proved it contributed nothing
            // to the sculpted shape — chord σ and the on-screen pattern were
            // identical with it off. An arbitrary induced-velocity patch, not a
            // law. See NOTES.md (play-stack rationalization).

            // Phase 4 & 12: Mechanical Point Source Impulse + Shockwaves
            // Base impulse uses deltaAmp (transient-only), not raw amp.
            // This prevents continuous outward push during sustain.
            float pushRadius = 2.0f;
            if (r < pushRadius && !(u.debugFlags & (1u << 18))) { // TEMP-DIAG SS_PLAY_SKIP=impulse
                float3 radialDir = float3(dx / r, dy / r, dz / r);
                float impulseForce = voices[vi].deltaAmp * 80.0f * (1.0f - r / pushRadius);

                float densityScale = 1.0f / max(0.1f, u.plateRadius / 400.0f);
                float shockwave = voices[vi].deltaAmp * 400.0f * (1.0f - r / pushRadius) * densityScale;
                impulseForce += shockwave;
                // ── ACOUSTIC-LIMIT CLAMP (2026-07-08 19:20 — CONVICTED BY THE
                // DRIFT HUNT: SS_PLAY_SKIP sweep, baseline mean drifted to
                // (0,-10,-8) while impulse-off stayed centered/spherical). At
                // default Space Scale, deltaAmp*400*densityScale(=4) = kicks up
                // to ~1600*deltaAmp/frame: any sustained audio ROCKETS the
                // cluster core to the walls -> the persistent crescent. The
                // onset thump stays; it obeys the same speed limit as every
                // other play force.
                impulseForce = min(impulseForce, 1.0f);
                
                shiftVx += radialDir.x * impulseForce;
                shiftVy += radialDir.y * impulseForce;
                shiftVz += radialDir.z * impulseForce;
                
                currentTemp += voices[vi].deltaAmp * 2.0f;
            }

            // ── The Atom Model (Gradient-Driven Harmonic Sculpting) ────────
            float Y_here  = cos(m_f * th) * sin(n_f * phi);
            float Y_dth   = cos(m_f * (th + 0.02f)) * sin(n_f * phi);
            float Y_dphi  = cos(m_f * th) * sin(n_f * (phi + 0.02f));
            
            float dYdth  = (Y_dth - Y_here) / 0.02f;
            float dYdphi = (Y_dphi - Y_here) / 0.02f;
            
            float3 thetaDir = float3(-sin(th), cos(th), 0.0f);
            float sinPhi = sin(phi);
            float3 phiDir = float3(cos(th)*cos(phi), sin(th)*cos(phi), -sinPhi);
            
            float acMod = 1.0f + 0.3f * sin(voices[vi].frequency * u.time * 0.1f + voices[vi].phase);
            float visualAmp = pow(amp, 0.4f); 
            float sculptStrength = visualAmp * voices[vi].alpha * 25.0f * acMod * polyNorm;
            
            if (!(u.debugFlags & (1u << 16))) { // TEMP-DIAG SS_PLAY_SKIP=sculpt
                shiftVx += (dYdth * thetaDir.x + dYdphi * phiDir.x) * sculptStrength;
                shiftVy += (dYdth * thetaDir.y + dYdphi * phiDir.y) * sculptStrength;
                shiftVz += (dYdth * thetaDir.z + dYdphi * phiDir.z) * sculptStrength;
            }

            // ── CYLINDRICAL EIGENMODE + GOR'KOV (play-stack re-land, increment 1)
            // The physically-correct 3D standing wave: particles collect onto
            // the Ψ=0 nodal shells via the acoustic radiation force F=−Ψ∇Ψ.
            // Single-voice, world-frame cavity (axis = world Z), ∇Ψ by central
            // difference. Gated behind SS_EIGENMODE (bit23) to A/B vs sculpt.
            // ── VOICE-OWNED MATTER (2026-07-20 00:33, Jamal: "CHORDS DON'T
            // FEEL LIKE THREE+ FORCES INJECTED INTO A UNIVERSE — they make
            // the shapes thinner over time"): summing every voice's Gor'kov
            // onto every particle drives matter to the INTERSECTION of all
            // nodal sets — sheets→curves→points, thinner with each note (the
            // codimension math doing exactly the wrong thing aesthetically).
            // Now the population is PARTITIONED: each particle answers to ONE
            // voice's mode (id mod voices) → a chord is N coexisting
            // interleaved bodies stabilizing in one space — thicker with more
            // notes. Also ×N cheaper: one mode per particle, not all N.
            // COUPLING (2026-07-20 00:38, Jamal: "I don't see the forces
            // pulling on EACH OTHER"): pure partition made the voice-bodies
            // independent ghosts. Now: OWNER voice = full force (the body
            // keeps its identity), other voices = ×EIGEN_COUPLE (the bodies
            // tug/shear each other — coupled oscillators). γ=0 ghosts,
            // γ=1 the old thinning intersection; 0.35 = visible tension.
            if (u.debugFlags & (1u << 23)) {
                const float EIGEN_COUPLE = 0.35f;
                float ownW = (int(id % uint(max(numVoices, 1))) == vi)
                                 ? 1.0f : EIGEN_COUPLE;
                float rho = sqrt(px * px + py * py);
                // Outside the cavity wall there is NO mode → no radiation force.
                // This also bounds k_ρρ ≤ α ≤ 43.3684 (2026-07-29: was 20.3208
                // on the 7x4 table), inside besselJm's validated range.
                if (rho < EIGEN_R) {
                    rho = max(rho, 1e-4f);                              // axis guard
                    // CLAMPS WIDENED 2026-07-29 to the full keyboard: m was
                    // pinned to 0..6 (F#..B all drew m=6) and n to 1..4.
                    int   mm   = clamp(int(voices[vi].m), 0, 11);
                    int   nn   = clamp(int(voices[vi].n), 1, 9);
                    float alphaZero = BESSEL_ZEROS[mm * 9 + (nn - 1)];  // J_m(α)=0
                    float kRho = alphaZero / EIGEN_R;                   // cavity-quantized
                    // Axial mode number p: an integer, so the standing wave FITS
                    // the tube (k_z = pπ/L). p is a musical mapping — same status
                    // as pitchClass→m and octave→n in modes.cpp — NOT a physical
                    // constant. Tied to n so structure thickens with pitch.
                    // CHORD-VOLUME FIX (2026-07-19 23:32, research §5b +
                    // Jamal: "I've always tried chords" yet chords stayed
                    // skins): p was tied to n (octave), so same-octave chord
                    // tones SHARED their axial nodal planes — and a surface
                    // common to every voice survives in ΣΨᵢ² (the sum can't
                    // erase a common zero) → sheets. p now differs per chord
                    // tone (from m+n), no nodal surface is shared by all
                    // voices → the summed potential's minima are
                    // INTERSECTIONS (curves/points) = the volumetric lattice.
                    // FLAT-DISK / LOW-C-EYE FIX (2026-07-22 02:0x, Jamal: "only
                    // low C turns to an eye... doesn't make sense"). The old
                    // 1+((m+n)%3) gave pAx=1 whenever (m+n)%3==0 — which is
                    // EXACTLY low C (m=0,n=3). pAx=1 = a SINGLE axial node = a
                    // flat disk = a thin line (the eye) edge-on. 2+((m+n)%3) is
                    // never 1: low C now gets pAx=2 = TWO axial planes = two
                    // equal rings side by side (his reference look), and no note
                    // collapses to a flat disk. Per-tone variation (chord desync)
                    // is preserved by the %3 term.
                    int   pAx  = 2 + ((mm + nn) % 3);
                    float kZ   = float(pAx) * M_PI_F / EIGEN_L;         // p·π/L, real by construction
                    float cth  = px / rho, sth = py / rho;              // cosθ, sinθ
                    float mth  = float(mm) * atan2(py, px);
                    float2 JJ  = besselJmD(mm, kRho * rho);             // (J_m, J_m')
                    float cA = cos(mth), sA = sin(mth);
                    // Axial phase is referenced to the cavity WALL, not the origin.
                    // cos(k_z·z) puts its p=1 zeros at z=±L/2 — i.e. ON the two end
                    // faces, so the rings collected on the faces instead of inside
                    // (Jamal, 2026-07-10 01:00). A rigid-wall cavity on [−L/2, L/2]
                    // has modes cos(pπ(z+L/2)/L): p nodal planes strictly INSIDE.
                    float zeta = pz + 0.5f * EIGEN_L;
                    float cZ = cos(kZ * zeta), sZ = sin(kZ * zeta);
                    float psi = JJ.x * cA * cZ;                         // Ψ
                    // ∇Ψ (cylindrical → Cartesian): ρ̂·∂ρ + θ̂·(1/ρ)∂θ + ẑ·∂z
                    // The 1/ρ term is finite as ρ→0: J_m ~ ρ^m kills it for m≥1,
                    // and the sinθ factor carries m=0 to zero.
                    float dPdrho = kRho * JJ.y * cA * cZ;
                    float dPdth  = JJ.x * (-float(mm) * sA) * cZ / rho;
                    float dPdz   = JJ.x * cA * (-kZ * sZ);
                    float3 grad  = float3(cth * dPdrho - sth * dPdth,
                                          sth * dPdrho + cth * dPdth,
                                          dPdz);
                    // Gain dictated by the mode's own wavenumbers (see EIGEN_KAPPA).
                    float Sv = EIGEN_KAPPA / (kRho * kRho + kZ * kZ);
                    // ── ACOUSTIC CONTRAST → INTERIOR FILL (2026-07-19) ──────
                    // F = −Ψ∇Ψ = −½∇(Ψ²) drives EVERY particle onto the same
                    // Ψ=0 skins (the potential's minima) — that IS the hollow
                    // tube. The real radiation force scales with the particle's
                    // acoustic contrast: dense/stiff matter seeks pressure
                    // NODES (φ>0), light/compressible matter seeks ANTINODES
                    // (φ<0). φ is drawn per-id, deterministic (same status as
                    // the per-id IMF mass): the population spreads across
                    // nodes, antinodes and the gradient between them —
                    // structure through the VOLUME instead of one skin.
                    uint hc = id * 747796405u + 2891336453u;
                    hc ^= hc >> 16; hc *= 0x9E3779B1u; hc ^= hc >> 13;
                    float contrast = ((float)(hc & 0xFFFFu) / 32767.5f) - 1.0f;
                    float3 gork = -contrast * psi * grad *
                                  (Sv * visualAmp * polyNorm * ownW);
                    shiftVx += gork.x;
                    shiftVy += gork.y;
                    shiftVz += gork.z;
                    // ── WARM TRAP (increment 1, 2026-07-19 23:2x — design doc
                    // §1, Jamal's 3D-wave framing). A cold trap collapses onto
                    // the wave's zero-surfaces (sand-on-a-plate transplanted
                    // to 3D — the skin bug); a WARM trap fills volume:
                    // ρ ∝ exp(−U/kT) = the |Ψ|²-shaded orbital cloud. Thermal
                    // kicks keyed to the particle's OWN temperature, σ tied to
                    // the mode's CHARACTERISTIC drive (Sv·amp·poly·k_ρ), NOT
                    // the local force — the force is zero exactly ON the nodal
                    // surface, where escape matters most. Ratio 0.4× from the
                    // HII-region numbers (research doc §2: σ_th ≈ 0.3–0.5×
                    // flow) — puffs shells into lobes without erasing them.
                    if (!(u.debugFlags & (1u << 27))) { // SS_NO_WARM bisect gate
                        // noise() is already zero-mean [−0.5,0.5] — no remap
                        // (the ×2−1 here was the [−2,0] all-negative bug).
                        float3 thKick = float3(noise(id,           u.frameCounter + 41u),
                                               noise(id + 7919u,   u.frameCounter + 53u),
                                               noise(id + 104729u, u.frameCounter + 67u));
                        float tNorm   = clamp(currentTemp, 0.0f, 10.0f) * (1.0f / 5.0f);
                        // CALIBRATION step 1 (2026-07-19 23:12): 0.4 (the raw
                        // HII ratio) produced NO visible spread — fricPlay
                        // damping eats white-noise kicks (stationary width ∝
                        // σ/√damping), so the ratio must be set against the
                        // DAMPED equilibrium. Sweeping empirically; bake the
                        // measured value when Jamal's eyes see lobes.
                        float sigmaTh = 4.0f * (Sv * visualAmp * polyNorm)
                                        * (0.3f * kRho) * sqrt(tNorm);
                        shiftVx += thKick.x * sigmaTh;
                        shiftVy += thKick.y * sigmaTh;
                        shiftVz += thKick.z * sigmaTh;
                    }
                }
            }

            // Track dominant band for per-band coloring
            float fMag = abs(dYdth) + abs(dYdphi);
            if (fMag * amp > bestForce) {
                bestForce = fMag * amp;
                bestBand = voices[vi].bandGroup;
            }

            // ── Radial breathing REMOVED 2026-07-09: rationalization sweep
            // showed no shape contribution (visual + σ identical with it off).
            // Y_here is retained below — the webbing accumulation needs it.

            Y_total += visualAmp * Y_here;
            jitterTotal += visualAmp;
            
            // Phase 18: Accumulate for Chord Webbing
            float Y_w = Y_here * visualAmp;
            sum_Y += Y_w;
            sum_dYdth += dYdth * visualAmp;
            sum_dYdphi += dYdphi * visualAmp;
            sum_Y2 += Y_w * Y_w;
            sum_YdYdth += Y_w * dYdth * visualAmp;
            sum_YdYdphi += Y_w * dYdphi * visualAmp;
        } // end of voice loop

        // Phase 11: String Theory
        dynamicMass += massAdd;

        // Build the ridge-pull from the SUMMED sculpt gradient (same up-gradient
        // direction the per-voice sculpt uses, isolated from swirl/breathing).
        // Used at the velocity-freeze below to condense hardened grains onto the
        // node line. Global thetaDir/phiDir at this particle (like webbing does).
        {
            float thAng = atan2(py, px);
            float3 thetaDirG = float3(-sin(thAng), cos(thAng), 0.0f);
            float r_c = sqrt(px*px + py*py + pz*pz);
            float phiG = acos(clamp(pz / max(r_c, 0.0001f), -1.0f, 1.0f));
            float3 phiDirG = float3(cos(thAng)*cos(phiG), sin(thAng)*cos(phiG), -sin(phiG));
            ridgePull = (sum_dYdth * thetaDirG + sum_dYdphi * phiDirG) * polyNorm;
        }

        // ── Phase 18: Chord Webbing (Inter-Harmonic Connectivity) ────────
        if (numVoices > 1 && !(u.debugFlags & (1u << 20))) { // TEMP-DIAG SS_PLAY_SKIP=web
            float cross_dYdth = sum_Y * sum_dYdth - sum_YdYdth;
            float cross_dYdphi = sum_Y * sum_dYdphi - sum_YdYdphi;
            
            float3 thetaDir = float3(-sin(atan2(py, px)), cos(atan2(py, px)), 0.0f);
            float r_center = sqrt(px*px + py*py + pz*pz);
            float phi_global = acos(clamp(pz / max(r_center, 0.0001f), -1.0f, 1.0f));
            float3 phiDir = float3(cos(atan2(py, px))*cos(phi_global), sin(atan2(py, px))*cos(phi_global), -sin(phi_global));
            
            float webStrength = 60.0f * polyNorm; 
            shiftVx += (cross_dYdth * thetaDir.x + cross_dYdphi * phiDir.x) * webStrength;
            shiftVy += (cross_dYdth * thetaDir.y + cross_dYdphi * phiDir.y) * webStrength;
            shiftVz += (cross_dYdth * thetaDir.z + cross_dYdphi * phiDir.z) * webStrength;
        }

        // ── Phase 19: Elastic Shell Restoring Force (Staccato Bounce-Back) ──
        // DISABLED — was preventing particles from extending through the sphere.
        // HTML cymatics reference has no shell; shapes flow continuously across
        // the volume, connecting across both sides. Restore by changing `false`
        // back to `!isSilence` if needed.
        if (false) {
            float restingRadius = globalTargetRadius;
            float currentR = sqrt(px*px + py*py + pz*pz);
            if (currentR > 0.001f) {
                float displacement = currentR - restingRadius;
                float3 dir = float3(px, py, pz) / currentR;
                float springStiffness = 50.0f;
                shiftVx -= dir.x * displacement * springStiffness * dt;
                shiftVy -= dir.y * displacement * springStiffness * dt;
                shiftVz -= dir.z * displacement * springStiffness * dt;

                // ── VJ Azimuthal Restoring Force ──────────────────────────────
                // Only during play — prevents lobe sticking when voices drop.
                float3 n = dir;
                int N = u.particleCount;
                float offset_f = 2.0f / (float)N;
                float increment = M_PI_F * (3.0f - sqrt(5.0f));
                float yHome = 1.0f - (2.0f * (float)id + 1.0f) * offset_f * 0.5f;
                float r_xy = sqrt(max(0.0f, 1.0f - yHome * yHome));
                float phiHome = (float)id * increment;
                float3 h = float3(cos(phiHome) * r_xy, yHome, sin(phiHome) * r_xy);
                float3 h_tan = h - dot(h, n) * n;
                float hLen = length(h_tan);
                if (hLen > 0.001f) {
                    h_tan /= hLen;
                    float amp = clamp(u.totalAmplitude, 0.0f, 1.0f);
                    float spreadStrength = (1.0f - amp) * 0.4f;
                    shiftVx += h_tan.x * spreadStrength;
                    shiftVy += h_tan.y * spreadStrength;
                    shiftVz += h_tan.z * spreadStrength;
                }
            }
        }

        // ODS-03: Thermal Energy Evolution
        float targetTemp = clamp(pow(jitterTotal, 0.6f) * 0.8f, 0.0f, 1.5f);
        currentTemp = mix(currentTemp, targetTemp, 0.02f);
    }

    // INERTIA: scale the voice block's velocity contribution by the real
    // mass (see snapshot above). invInertia = 1 for the IMF mean star;
    // a 30 M_sun monster feels ~1% — it stays put at the centre, keeps
    // eating through the note, and the Chladni pattern forms around it.
    if (mass > 0.001f && mass < 1e8f) {
        float invInertia = clamp(0.3f / max(mass, 0.05f), 0.0005f, 1.0f);
        // PLAY OVER EVERYTHING: while playing, the keys hit EVERY particle at
        // full strength regardless of mass (cymatics sand = massless tracers).
        // The mass-resistance (heavy stars drifting free = stragglers) is BH
        // physics; it belongs to rest, not play. → invInertia = 1 in play.
        invInertia = mix(invInertia, 1.0f, playGate);
        shiftVx = preVoiceV.x + (shiftVx - preVoiceV.x) * invInertia;
        shiftVy = preVoiceV.y + (shiftVy - preVoiceV.y) * invInertia;
        shiftVz = preVoiceV.z + (shiftVz - preVoiceV.z) * invInertia;
    }

    // ── Noether Symmetry Breaking ─────────────────────────────────────
    // Constantly adds a subtle ambient swirl to prevent perfect dead-center grid-lock if needed
    if (u.symmetryBreakImpulse > 0.0f && !(u.debugFlags & (1u << 22))) { // TEMP-DIAG SS_PLAY_SKIP=symbreak
        float angle = noise(id * 3u, u.time) * M_PI_F;
        float strength = u.symmetryBreakImpulse * (0.1f + noise(id * 7u, u.time) * 0.1f);
        shiftVx += cos(angle) * strength;
        shiftVy += sin(angle) * strength;
    }

    // (Second jitter block removed — temperature-driven jitter above is sufficient)

    // (Schwarzschild gravity replaced by ADSR lifecycle above)

    // ── Particle-Particle Collisions (spatial hash neighbor scan) ─────
    // SKIP during play: play is pure cymatics (keys only), and this 27-cell scan
    // explodes on the dense Chladni pattern — wasted compute. Off-key only.
    if (u.collisionsOn > 0 && su.gridSize > 0 && playGate < 0.5f) {
        int cellX = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int cellY = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int cellZ = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);

        float colRad = u.collisionRadius;
        float colRad2 = colRad * colRad;

        int startCellX = max(0, cellX - 1);
        int endCellX = min(su.gridSize - 1, cellX + 1);
        int startCellY = max(0, cellY - 1);
        int endCellY = min(su.gridSize - 1, cellY + 1);
        int startCellZ = max(0, cellZ - 1);
        int endCellZ = min(su.gridSize - 1, cellZ + 1);

        float orig_px = px;
        float orig_py = py;
        float selfCharge = p.spinW.w;
        
        uint closest_id = p.entanglement.x;
        float min_dist2 = colRad2 * colRad2; // track closest neighbor

        for (int z = startCellZ; z <= endCellZ; z++) {
            for (int y = startCellY; y <= endCellY; y++) {
                for (int x = startCellX; x <= endCellX; x++) {
                    uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                    // GHOST FIX 2026-08-13: was MAX_PER_CELL (128) — 73.9% of
                    // this loop's reads were unwritten slots. The scatter fills
                    // 32. See SCATTER_PER_CELL.
                    uint count = min(cellCounts[cID], SCATTER_PER_CELL);
                    if (count == 0) continue;
                    uint startIdx = cellStarts[cID];

                    for (uint i = 0; i < count; i++) {
                        // SELECTIVE NEIGHBOUR LOADS (2026-07-07 fps sprint): the
                        // full 80-byte struct copy here was the engine's hottest
                        // traffic (27 cells x 32 x 2M = the measured ~170ms @2M).
                        // This loop touches ONLY posW + spinW + entanglement.y
                        // (36B) - load exactly those, like the SPH tiles do.
                        device const SortedHot* npp = &sortedParticles[startIdx + i];
                        float4 npPos  = npp->posW;
                        uint   npOrig = npp->entanglement.y;
                        // spinW lives in the COLD (live) buffer — lazy fetch by
                        // origin id; only this loop wants it.
                        float4 npSpin = (npOrig < uint(u.particleCount))
                                            ? prevParticles[npOrig].spinW
                                            : float4(0.0f);

                        float ddx = orig_px - npPos.x;
                        float ddy = orig_py - npPos.y;
                        float ddz = pz - npPos.z;
                        float dist2 = ddx * ddx + ddy * ddy + ddz * ddz;

                        // ODS-06: Schwarzschild Singularity (Black Hole)
                        // If local density hits critical mass, space collapses.
                        bool isBlackHole = (count >= uint(MAX_PER_CELL) - 1);

                        if (dist2 > colRad2 || dist2 < 1e-12f) continue;

                        float dist = sqrt(dist2);
                        
                        // Phase 14: Collision Optimization
                        // Early exit if we have too many interactions in this frame
                        if (i > 24 && dist > colRad * 0.5f) continue;

                        // Particles heat up significantly on collision
                        currentTemp += 0.03f; 
                        
                        // 1. The Inverse-Square Law (E-Field)
                        // float r2_clamped = max(dist2, 1e-7f); // This line is now part of the new block
                        float q1q2 = selfCharge * npSpin.w;
                        // float eForce = (u.eFieldStiffness * q1q2) / r2_clamped; // This line is now part of the new block
                        float3 r_vec = float3(ddx, ddy, ddz);
                        float r2 = dist2; // Use dist2 directly
                        uint p2_orig_id = npOrig;

                        if (r2 > 1e-12f && r2 < min_dist2 && p2_orig_id != id) {
                            min_dist2 = r2;
                            closest_id = p2_orig_id;
                        }

                        if (r2 > 0.00001f) {
                            float r2_clamped = max(r2, 0.0001f);
                            float r = sqrt(r2_clamped);

                            // Coulomb-like electrostatic repulsion analog
                            if (u.debugFlags & (1 << 0)) {
                                float eForce = (u.eFieldStiffness * q1q2) / r2_clamped;
                                
                                // ODS-06: Invert repulsion to infinite attraction at singularity
                                if (isBlackHole) {
                                    eForce = -15.0f / r2_clamped; // Intense collapse
                                    currentTemp *= 0.5f; // Hawking radiation / freezing
                                }
                                
                                float3 fE = normalize(r_vec) * eForce * dt;
                                shiftVx += fE.x; shiftVy += fE.y; shiftVz += fE.z;
                            }

                            // Biot-Savart circulation analog (B-Field)
                            if (u.debugFlags & (1 << 1)) {
                                float3 spin1 = p.spinW.xyz;
                                float3 spin2 = npSpin.xyz;
                                float r3 = r2_clamped * r;
                                float3 bForceVec = cross(spin1 + spin2, normalize(r_vec)) * u.bFieldCirculation / r3 * dt;
                                shiftVx += bForceVec.x; shiftVy += bForceVec.y; shiftVz += bForceVec.z;
                            }

                            // Tensegrity Strings (Hooke's Law)
                            if (u.debugFlags & (1 << 3)) {
                                float strain = r - u.restLength;
                                // Negate r_vec: stretched → pull inward, compressed → push outward
                                float3 stringF = normalize(-r_vec) * strain * u.stringStiffness * dt;
                                shiftVx += stringF.x; shiftVy += stringF.y; shiftVz += stringF.z;
                            }

                            // Newtonian Self-Gravity (1/r^2)
                            if (u.debugFlags & (1 << 2)) {
                                float massProd = dynamicMass * npPos.w;
                                if (massProd != 0.0f) { // Skip gravity for zero-mass particles (walls)
                                    float gravForce = u.gravityConstant * massProd / r2_clamped;
                                    float3 fG = normalize(-r_vec) * gravForce * dt;
                                    shiftVx += fG.x; shiftVy += fG.y; shiftVz += fG.z;
                                }
                            }

                            // Hard-sphere Elastic Collision
                            if ((u.debugFlags & (1 << 5)) && (u.collisionsOn > 0)) {
                                float minDist = u.collisionRadius * 2.0f;
                                if (r < minDist) {
                                    float overlap = minDist - r;
                                    float3 resolve = normalize(r_vec) * (overlap * 0.5f);
                                    shiftX += resolve.x; shiftY += resolve.y; shiftZ += resolve.z;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Update entanglement to point to closest neighbor
        p.entanglement.x = closest_id;

        // Position correction applied directly
        px += shiftX;
        py += shiftY;
        pz += shiftZ;
        vpx += shiftVx;
        vpy += shiftVy;
        vpz += shiftVz;
    }

    // ── Bond-Network: nearest-neighbour link ("nervous system of light") ──
    // Independent of the collisions toggle. In the hardened (sustain) state each
    // particle finds its single closest physical neighbour via the same spatial
    // hash and records that neighbour's ORIGINAL index (carried in .w) into
    // entanglement.z. The render pass draws a 1px light-line self→bond so
    // adjacent particles fuse into continuous matter, closing the micro-gaps.
    // PURE DATA here — no force applied; quantum entanglement (.x) is untouched.
    if (u.bondNetworkOn > 0.5f && su.gridSize > 0 && u.envelopePhase > 2.5f) {
        int bcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int bcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int bcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);

        // Adjacency scale: ~one cell → only truly touching neighbours bond.
        float best2 = su.cellSize * su.cellSize;
        uint bestOrig = 0xFFFFFFFFu;
        uint selfOrig = p.entanglement.w;

        for (int z = max(0, bcz - 1); z <= min(su.gridSize - 1, bcz + 1); z++) {
            for (int y = max(0, bcy - 1); y <= min(su.gridSize - 1, bcy + 1); y++) {
                for (int x = max(0, bcx - 1); x <= min(su.gridSize - 1, bcx + 1); x++) {
                    uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                    // GHOST FIX 2026-08-13 — same mismatch as the collision
                    // scan: indexes sortedParticles, so it must use the WRITE
                    // depth. See SCATTER_PER_CELL.
                    uint count = min(cellCounts[cID], SCATTER_PER_CELL);
                    uint startIdx = cellStarts[cID];
                    for (uint i = 0; i < count; i++) {
                        // SELECTIVE LOADS (2026-07-07): this loop runs every
                        // frame once a note has entered SUSTAIN — the full
                        // 80-byte copy was the "same 5fps after playing"
                        // (compute 175ms @2M measured in Jamal's live session
                        // while rest-only runs showed 27ms). posW + one
                        // entanglement word is all it reads.
                        device const SortedHot* npp = &sortedParticles[startIdx + i];
                        float4 npPos = npp->posW;
                        uint npBond = npp->entanglement.w;
                        if (npBond == selfOrig) continue; // skip self
                        float dx = px - npPos.x;
                        float dy = py - npPos.y;
                        float dz = pz - npPos.z;
                        float d2 = dx * dx + dy * dy + dz * dz;
                        if (d2 < best2 && d2 > 1e-12f) {
                            best2 = d2;
                            bestOrig = npBond;
                        }
                    }
                }
            }
        }
        p.entanglement.z = bestOrig;
    }

    // ── CRYSTALLIZATION: density-driven continuous hardness (US2 transition) ──
    // Local density (cellCounts) + dwell (slow ramp) → per-particle hardness H,
    // stored as float bits in entanglement.y. As H→1 a particle freezes its
    // degrees of freedom (velocity locks below; jitter dies) so a dense region
    // held over TIME crystallizes into a still solid instead of shimmering;
    // sparse (gas) stays free. The continuous gas→solid rung below our
    // critical-density black hole. See [[space-synth-tube-crystallization]].
    float hardness = as_type<float>(p.entanglement.y);
    if (su.gridSize > 0 && u.envelopePhase > 2.5f) {
        int hcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int hcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int hcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        uint hcID = uint((hcz * su.gridSize + hcy) * su.gridSize + hcx);
        // Density is a WEIGHT on the freeze RATE, not a gate: even the sparse
        // spread crystallizes, just slower. Bright nodes (dense) set first,
        // the gas sets last → the pattern solidifies INWARD over sustain time.
        float dens = smoothstep(2.0f, 48.0f, float(cellCounts[hcID]));
        float rate = mix(1.0f / 15.0f, 1.0f / 10.0f, dens); // dense ~10s, sparse ~15s to full solid
        hardness = min(1.0f, hardness + rate * dt);          // INTEGRATE over sustain time (hold longer = harder)
    } else {
        hardness += (0.0f - hardness) * min(1.0f, 3.0f * dt);    // relax to gas
    }
    p.entanglement.y = as_type<uint>(hardness);

    // ── COHESION SPRING — REPLACED by real SELF-GRAVITY ──────────────────────
    // The grid cohesion spring (pull toward the 3×3×3 centroid) clumped locally
    // but never accumulated mass to a centre — and it was wiped at rest by the
    // silence-immunity restore anyway. Its job (local clumping) is now done by
    // the NEAR field of the always-on Newtonian self-gravity block above the
    // lifecycle capture, which also survives silence. Same grid, same O(N·27).

    // ── PRESSURE (grid-based SPH, O(N·27), ALWAYS-ON) — the gas force ────────
    // Push each particle DOWN the local density gradient: away from neighbouring
    // cells that are DENSER than its own → toward sparser space. This is the SPH
    // pressure law (density → pressure → −∇P), the real astrophysical gas force.
    // It prevents collapse and makes matter spread/expand/shock like gas, and
    // pairs with cohesion (pull toward centre) → a real fluid whose equilibrium
    // density IS the state. Grid-based (reads precomputed cell centroids, no
    // pairwise loop) → bounded, can't hit the collision wall → safe to be
    // always-on (the replacement for optional pairwise collisions).
    // SKIP during play: it fights the Chladni pattern (pushes particles OUT of
    // the dense nodes) and the O(N·27) scan is expensive on the packed pattern.
    // bit14 (TEMP A/B, substrate-noise hunt 2026-07-07): disable entirely. This
    // force is COUNT-DIFFERENCE repulsion (not an EOS — no temperature, no ρu):
    // cell-count Poisson noise (±4 of ~15) → random ~0.1c/frame kicks in the
    // bulk, and the real edge gradient → coherent ~0.5c/frame outward push.
    // Prime suspect for the baseline 1c noise floor + escaper fountain. The
    // real replacement is the slice-2/3 SPH pressure (bit11/12).
    if (su.gridSize > 0 && playGate < 0.5f && (u.bhToggles & 0x4000u) == 0u) {
        int pcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int pcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int pcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        float selfDensity = cellCentroids[uint((pcz * su.gridSize + pcy) * su.gridSize + pcx)].w;

        float3 pForce = float3(0.0f);
        for (int z = max(0, pcz - 1); z <= min(su.gridSize - 1, pcz + 1); z++) {
            for (int y = max(0, pcy - 1); y <= min(su.gridSize - 1, pcy + 1); y++) {
                for (int x = max(0, pcx - 1); x <= min(su.gridSize - 1, pcx + 1); x++) {
                    uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                    float4 c = cellCentroids[cID];      // xyz = centre, w = count
                    if (c.w < 0.5f) continue;           // skip empty
                    float dP = c.w - selfDensity;        // neighbour denser?
                    if (dP <= 0.0f) continue;            // only repel from DENSER cells
                    float3 toNb = c.xyz - float3(px, py, pz);
                    float d = length(toNb);
                    if (d > 1e-5f) pForce -= (toNb / d) * dP;  // push away (down-gradient)
                }
            }
        }
        float pStiff = 2.0f;
        shiftVx += pForce.x * pStiff * dt;
        shiftVy += pForce.y * pStiff * dt;
        shiftVz += pForce.z * pStiff * dt;
    }

    // ── COLLAPSE INTO THE BLACK HOLE (release / held-BH state) ───────────────
    // Once a note is let go, the star map falls into the hole under real central
    // gravity (Plummer-softened), SLOWLY — scaled by envelopeProgress, the
    // collapse ramp held by the CPU lifecycle. "Let go → slow collapse into a
    // black hole." Gated to the release/BH phase (>3.5), so rest/play untouched.
    // ALWAYS-ON central gravity → the galaxy self-collapses over time (the BH
    // is the EMERGENT physical sum of the mass falling in, no note required).
    // Release accelerates the collapse. Plummer-softened, gated only by mass>0.
    // Central "black hole" gravity does NOT exist at rest — only after a note is
    // released does the hole pull matter in (the collapse gesture). At rest the
    // ONLY attraction is particle↔particle (the grid cohesion above), which lets
    // mass slowly clump from where it is, NOT pull toward a fake origin/ball.
    // Legacy release-collapse REMOVED (Gstr=8 pull to the ORIGIN, ~120×
    // stronger than labeled in this integrator's units). It was the "whole
    // box falls down" yank and the second L-killer: a pure radial force
    // toward a fixed point erases orbital structure. The always-on
    // self-gravity (above, toward the real centre of mass) is the only
    // attractor now; release just turns the drag up (see baseFric) so the
    // same gravity reads as a watchable spiral-in.

    // ── Störmer-Verlet integration (damped) ──────────────────────────
    // Restored natural damping without extra cosmic over-drag.
    // Jitter and collision forces are now visible again.

    // ── Silence force immunity: restore lifecycle-only shifts ──────────────
    if (isSilence) {
        shiftVx = lifecycleShiftV.x; shiftVy = lifecycleShiftV.y; shiftVz = lifecycleShiftV.z;
        shiftX = lifecycleShiftP.x; shiftY = lifecycleShiftP.y; shiftZ = lifecycleShiftP.z;
        if (collapsed) {
            shiftVx = 0.0f; shiftVy = 0.0f; shiftVz = 0.0f;
            vpx = 0.0f; vpy = 0.0f; vpz = 0.0f;
        }
        // ── 3B "Ambient Idle State" — REMOVED (it was THE rest-state cheat) ──
        // The old block ran ONLY here (rest), AFTER the force wipe: a scripted
        // Y-rotation applied straight to position, a ±5% "breathing" radius,
        // and per-particle turbulence kicks of ±0.01/frame (no dt, re-rolled
        // every 8 frames). With the rest damper gone the turbulence was a free
        // deterministic velocity random walk — measured: the whole star map
        // ballooned outward at ~30 sim/s, identical curve every run, even with
        // gravity disabled. Rest motion is now REAL: Kepler spawn velocities +
        // always-on self-gravity make the map orbit, clump and accrete.
    }

    // ── Envelope-Coupled Velocity Damping ──────────────────────────────
    // Release: kill momentum so collapse tracks the envelope fade
    // Sustain: let it breathe — no damping
    if (u.envelopePhase > 3.5f) {
        // Release momentum-kill REMOVED (was vp ×= 0.15). It destroyed the
        // angular momentum of everything falling toward the hole, so matter
        // arrived with L≈0 and could only form a dead BALL — never a disk.
        // Release is now a drag-driven gravitational inspiral (see baseFric):
        // |v| decays, the ORBITAL DIRECTION survives, matter spirals in and
        // settles into the accretion disk. Dissipation, not amputation.
        //
        // A4 FIX, 2026-08-10 15:13:00 — THE CRYSTAL LOCK IS RELAXED, NOT DROPPED.
        // His report: "after play when i release it kinda jumps into the next
        // phase... like another thing was at work. post play for a split sec."
        // Cause: the sustain branch below multiplies velocity by `lock`, which
        // reaches 0.05 at full hardness — a 95%-per-frame velocity kill. At the
        // 3.5 boundary that multiply STOPPED IN ONE FRAME, so matter that was
        // being scrubbed to a standstill every frame was abruptly free and the
        // standing forces (self-gravity, spin, voice residue) expressed at full
        // strength over the next few frames. That ramp-up from frozen to moving
        // IS the "split sec" jump.
        // Worse: `hardness` KEEPS INTEGRATING UP through release — the gate at
        // the crystallization block is `envelopePhase > 2.5`, true here too — so
        // the state kept hardening while its only consumer was disconnected.
        // Fix is a RAMP ACROSS the boundary, not a fifth branch: carry the same
        // lock and ease it out over the release with envelopeProgress.
        //   t=0 (release starts) -> lock == the sustain lock exactly  -> continuous
        //   t=1 (release ends)   -> lock == 1.0, matching silence      -> continuous
        // Continuous at BOTH ends, so nothing pops at either edge.
        float lock = mix(mix(1.0f, 0.05f, hardness), 1.0f, t);
        vpx *= lock;
        vpy *= lock;
        vpz *= lock;
    } else if (u.envelopePhase > 2.5f) {
        // Sustain: CRYSTALLIZE by LOCAL hardness (density + dwell), not a global
        // envelope ramp. A dense region held over time has H→1 and locks its
        // velocity hard → it freezes into a still solid; sparse stays mobile
        // (gas). lock = 0.05 at full hardness (loses ~95%/frame). The render
        // spin is a rotation now, so this freezes matter WITHOUT killing trails.
        float lock = mix(1.0f, 0.05f, hardness);
        vpx *= lock;
        vpy *= lock;
        vpz *= lock;
    }


    // ── VJ Silence Damping ──────────────────────────────────────────────
    // When amplitude drops, apply extra friction so particles return to sphere
    // ── Extra silence damping — DISABLED for emergent gravity ───────────────
    // The old ×0.90/frame rest damper froze the map (kills velocity ~10⁻⁶/s),
    // which turned the always-on self-gravity into invisible terminal-velocity
    // creep (measured: ~0.02 sim units of infall in 2 min). Rest must be LIVE:
    // baseFric (pow(0.9, dt) ≈ 0.9991/frame, tuned above for Kepler orbits)
    // is the only damping, so the spawn rotation orbits and the core accretes.

    // Combine proxy with force pulses, then CROSS-FADE to ridge-condense by
    // hardness. Freezing motion in place blurs (it locks a loose cloud mid-swim).
    // Instead, as a grain hardens we fade OUT its momentum + swirl/breathing
    // (the overshoot that smears the filament) and fade IN a pure RIDGE-PULL —
    // overdamped gradient ascent that drives it onto the exact node line and
    // self-terminates there (∇Y→0) → sharp threads, not frozen dust. At full
    // hardness only ridgePull acts; on the ridge it's ~0 → still AND sharp. The
    // speed cap below bounds it; the rigid spin folds in later (~1715) → trails live.
    // ── B2 ORBIT-SUPPORT DRAG EXEMPTION (BH OVERHAUL front B, 2026-07-23
    // 17:55). Measured drain ([BALANCE] at 17:46): with a formed hole the
    // field ends as sup=0.25 plunge at r=0.05 plus 43 survivors at r=88 —
    // NO shell can PARK, because drag+cooling bleed tangential velocity
    // indiscriminately → support decays → inspiral → eaten → black screen.
    // Physics: a circular orbit in vacuum does not decay; disk dissipation
    // acts on radial/shear motion. So: as a particle's orbital support
    // vt/vcirc → 1 (vcirc from the core's GM — it owns ~97% of the mass
    // once the hole exists), its drag fades toward conservative. Plunging
    // matter (sup≪1) keeps full drag — the hole still feeds; supported
    // matter PARKS — the disk persists. Gated to the formed hole; collapse
    // and play dynamics untouched.
    if (u.horizonR > 0.0f && u.bhMass > 1.0f && mass > 0.001f) {
        float3 relBH = float3(px - u.bhX, py - u.bhY, pz - u.bhZ);
        float rBH = length(relBH);
        if (rBH > u.horizonR) {
            float3 rhat = relBH / max(rBH, 1e-5f);
            float3 v3   = float3(vpx, vpy, vpz);
            float3 vt3  = v3 - dot(v3, rhat) * rhat;
            float G1s   = u.gravGM / max(u.massTotal, 1.0f);
            // In-kernel velocities are per-FRAME (see r_home kick: vcirc·dt)
            float vcircF = sqrt(G1s * u.bhMass / max(rBH, u.horizonR)) * dt;
            float sup    = length(vt3) / max(vcircF, 1e-6f);
            float keep   = smoothstep(0.5f, 0.95f, clamp(sup, 0.0f, 1.2f));
            dynamicFric  = mix(dynamicFric, 1.0f, keep * 0.95f);
            coolMul      = mix(coolMul, 1.0f, keep);
        }
    }
    float soften = 1.0f - hardness;
    float3 finalV = (float3(vpx, vpy, vpz) * dynamicFric * coolMul + float3(shiftVx, shiftVy, shiftVz)) * soften
                  + ridgePull * (hardness * 8.0f); // 8.0 = condense strength (lever)

    // PHYSICAL LIGHT-SPEED CAP (Phase A1, 2026-06-13 — fully physical). Nothing
    // moves faster than c. u.speedCap is now c in sim/(on-screen s); finalV is a
    // per-frame DISPLACEMENT, so the per-frame limit is c·dt → the cap is
    // frame-rate-correct (the old fixed 1.2/frame was ≈41c in honest units, the
    // superluminal core the HUD exposed). Orbital motion (ISCO ≈0.41c) is below
    // this and untouched; only the radial-plunge/play transients get clamped to c.
    // REGIME-AWARE: at rest/infall the cap is c·dt (relativistic, correct). During
    // high-amplitude PLAY the system is in the CYMATICS standing-wave regime
    // (non-relativistic acoustic driving) — blend the cap up to CHLADNI_VCAP so
    // the sculpt force reaches its tuned magnitude (fixes the 2026-06-13 c-cap
    // regression that throttled the Chladni pattern ~41×). Same play gate the
    // friction/jitter blends use (totalAmplitude·4, saturating at amp≈0.25).
    // playGate declared once at the gravity-regime switch above; reused here.
    // Both terms are now VELOCITIES (sim/s); dt converts to this step's
    // displacement. Previously this mixed c*dt (per-second, dt-scaled) with a
    // bare per-FRAME constant — mixing units, which is why the play cap moved
    // with the warp dial while the rest cap did not.
    float vCapFrame = mix(u.speedCap, CHLADNI_VCAP_PER_SEC, playGate) * dt;
    float speed = length(finalV);
    if (speed > vCapFrame) {
        finalV = (finalV / max(speed, 0.0001f)) * vCapFrame;
    }

    // ── ONE-WAY MEMBRANE, kick site (2026-07-16): inside the horizon nothing
    // moves OUTWARD and everything settles. Remove any outward radial
    // component (the one-way surface), damp hard (no orbits inside — the
    // interior advects to the centre and stays), and go DARK (temperature →
    // 0: no emission escapes; the black is physics, the splats just agree).
    if (insideHorizon) {
        float3 relBH = float3(px - u.bhX, py - u.bhY, pz - u.bhZ);
        float  rB = length(relBH);
        if (rB > 1e-5f) {
            float3 rhat = relBH / rB;
            float vOut = dot(finalV, rhat);
            if (vOut > 0.0f) finalV -= vOut * rhat;   // nothing exits
        }
        finalV *= 0.90f;                              // settle, don't orbit
        currentTemp = 0.0f;                           // dark: the final commit
                                                      // writes currentTemp → prevW.w
    }

    // Jitter (UI slider — now wired). Per-particle Brownian shimmer added as a
    // small position delta. u.jitterFactor was uploaded all along but never read.
    if (u.jitterFactor > 0.0001f && !(u.debugFlags & (1u << 21))) { // TEMP-DIAG SS_PLAY_SKIP=jitter
        float3 jit = float3(noise(id, u.frameCounter + 11u),
                            noise(id + 7919u, u.frameCounter + 23u),
                            noise(id + 104729u, u.frameCounter + 37u));
        // Amplitude-gated: jitter feeds finalV, which IS next frame's Verlet
        // velocity — at rest (no damping since the rest state went
        // conservative for orbits) it was a free velocity random walk that
        // blew the star map up to 4× its radius within seconds (measured).
        // Shimmer belongs to play, where fricPlay contains it.
        float jitterGate = clamp(u.totalAmplitude * 4.0f, 0.0f, 1.0f);
        finalV += jit * (u.jitterFactor * 0.02f * jitterGate) * (1.0f - hardness); // crystallized matter stops shimmering
    }

    // Final position integration
    float3 nextPos = float3(px, py, pz) + finalV;

    // ── STAR-MAP HOME (fixed 3D point + slow rigid rotation) ─────────────
    // Each star holds a FIXED isotropic 3D home (r_home, theta, phi) set at
    // spawn — a filled cluster, NOT a flat disk orbit. The whole map rotates
    // slowly as a rigid body (calm star-cluster motion). At REST (no voice)
    // position eases fully onto home → no drift, no pulse, the star map.
    // During PLAY: nextPos comes from the integrator (voice forces win) +
    // a small pull back toward home so particles don't fully escape.
    // AT REST: the home-pin is OFF — real gravity governs, so the galaxy
    // self-collapses over time (emergent BH, not a scripted snap). Gated by
    // amplitude: the pin only helps recover the shape while a note sounds.
    if (u.totalAmplitude > 0.005f) {
        float r_home = p.spinW.x;
        if (r_home > 0.001f) {
            float theta = as_type<float>(p.entanglement.z);
            float aphi  = as_type<float>(p.entanglement.w);
            float st = sin(theta), ct = cos(theta);
            float3 home = r_home * float3(st * cos(aphi), st * sin(aphi), ct);
            // Slow rigid rotation of the whole star map about +Y (0.08 rad/s,
            // matches the spawn velocity in particles.cpp).
            float ang = 0.08f * u.time;
            float ca = cos(ang), sa = sin(ang);
            float3 target = float3(home.x * ca + home.z * sa,
                                   home.y,
                                  -home.x * sa + home.z * ca);

            float voiceMute = clamp(u.totalAmplitude, 0.0f, 1.0f);
            // Blend toward the analytic home orbit as a RATE, never a teleport.
            // A `conv = smoothstep(0.6,1,toHome)` term used to force alpha→1
            // below amp 0.4, to land particles exactly on the analytic rest
            // orbits. Those rest orbits no longer exist — the pin is off at
            // rest and gravity governs (see above) — and amp<0.4 is BOTH the
            // start of the attack and the tail of the release, so it pinned
            // particles at onset and released them mid-flight as amp crossed
            // 0.4. That handoff was the "jumps unnaturally further in".
            float toHome = 1.0f - voiceMute;
            float alpha = 0.5f * toHome * dt;
            // Spin yields the home-orbit pull: ~0 while spinning, ramping back as
            // the spin coasts down → smooth re-engage (no snap from spin to rest).
            alpha *= spinSuppress;
            nextPos = mix(nextPos, target, alpha);
        }
    }

    // ── DIRECT ENVELOPE→RADIUS COUPLING ──────────────────────────────
    // DISABLED — every-frame radial blend toward globalTargetRadius was
    // preventing particles from extending through the sphere. HTML cymatics
    // lets particles flow freely. Restore by changing `false` to
    // `!collapsed && !isSilence` if needed.
    if (false) {
        float nextR = length(nextPos);
        if (nextR > 0.001f) {
            float3 dir = nextPos / nextR;

            if (u.envelopePhase < 1.5f) {
                // Attack: blend toward expanding target
                float blendedR = mix(nextR, globalTargetRadius, 0.25f);
                nextPos = dir * blendedR;
                finalV *= 0.75f;
            } else if (u.envelopePhase < 3.5f) {
                // Decay/Sustain: soft attractor proportional to amplitude
                // Gentle blend — allows expansion past target but always pulls back
                float blendedR = mix(nextR, globalTargetRadius, 0.05f);
                nextPos = dir * blendedR;
            } else {
                // Release: pull inward, tracking envelope fade
                float blendedR = mix(nextR, globalTargetRadius, 0.25f);
                nextPos = dir * blendedR;
                finalV *= 0.75f;
            }
        }
    }

    // ── OUTER RADIUS CAP — ONE SPHERE, ALL PHASES ───────────────────────
    // ⚠️ THIS HEADER USED TO DESCRIBE A BREATHING CAP that tightened during
    // silence and expanded on play, "envelopePhase-driven so it tracks the
    // synth ADSR". THAT IS NO LONGER WHAT THIS BLOCK DOES — it was left stale
    // by the 2026-08-27 one-domain change below and is rewritten here rather
    // than left to be quoted as evidence later. The cap no longer reads
    // envelopePhase at all; there is one radius and it never breathes.
    {
        // ── ONE DOMAIN (2026-08-27 14:1x, his order: "kill the tube. the field
        // becomes the resonator not a fake tube" / "its space synth not rooms
        // synth"). THE REGIME SPLIT IS GONE. There is no play branch and no rest
        // branch any more: the R=100 sphere IS the space in every envelope
        // phase, and playing a note no longer shrinks it.
        //
        // WHAT WAS HERE, in words, because the SHAPE mattered and not just the
        // radius: `bool playCap = (ph >= 0.5f && ph < 3.5f)` chose between
        //   PLAY — a CYLINDER. XY clamped to ORBIT_R_CHLADNI = 6, plus a
        //          SEPARATE axial clamp |z| <= EIGEN_L*0.5 = 6. A closed can.
        //   REST — a SPHERE. True 3D |r| clamped to STAR_MAP_CAP = 100.
        // Two different SHAPES, not two radii. The can is what drew the tube
        // silhouette; its wall is what the straight lines were made of.
        //
        // ⚠️ THIS DOES NOT TOUCH THE MODES, and that is why it ships alone. The
        // Gor'kov force self-gates at :2516 `if (rho < EIGEN_R)`, independently
        // of any clamp — so kRho and kZ still quantize on rho < 6 and the
        // pattern INSIDE the cavity is unchanged by this edit. What changes is
        // only what happens to matter OUTSIDE rho = 6: it is no longer snapped
        // back onto a cylinder wall.
        //
        // THE HONEST CONSEQUENCE, stated so nobody has to rediscover it: outside
        // the cavity the sculpt force is TANGENTIAL-ONLY (:2482 — theta-hat and
        // phi-hat components, no r-hat term at all), and this shader has no
        // boundary-repulsion force (CLAUDE.md's "cubic ramp r>0.85" describes
        // the ported HTML original, not this code). So SELF-GRAVITY is now the
        // only radial force beyond rho = 6. Whether that holds the escapers or
        // they disperse is a magnitude question, and it is the thing to judge.
        //
        // ⚠️ KNOWN, NOT FIXED HERE: the hash covers +/-64 (renderer.mm:2089)
        // while this cap is 100 (+8 spin yield). spatial_hash.metal:49-51 CLAMPS
        // anything outside into the outermost cells, so matter past r=64 gets no
        // cell of its own and the density there is fiction — on the faces of a
        // CUBE, not a sphere. Straight edges after this change are that box, not
        // the physics. Separate change; his call.
        //
        // ⚠️ ALSO KNOWN, ALSO NEXT: EIGEN_R/EIGEN_L still key the mode
        // quantizer to a wall that is no longer a boundary. Real, deliberate,
        // and NOT bundled in here.
        float capR = STAR_MAP_CAP + (1.0f - spinSuppress) * 8.0f;
        float r2 = dot(nextPos, nextPos);
        if (r2 > capR * capR) {
            float r = sqrt(r2);
            float3 rdir = nextPos / r;
            nextPos = rdir * capR;
            float vRad = dot(finalV, rdir);
            if (vRad > 0.0f) finalV -= vRad * rdir;   // no escape past the sphere
        }
    }

    // Phase accumulation — decode prior phase first; p.velW.w is packed bits.
    speed = length(finalV);
    float newPhase = decodePhase(p.velW.w) + speed * dt;

    // ── ODS-04: Dimming My Light (Stealth / ANC) ───────────────────────────
    if (u.debugFlags & (1 << 9)) {
        // Define the "User" cluster (~5% of particles)
        if ((id % 20) == 0) {
            // Active Noise Cancelling: Destructive interference by phase inversion
            newPhase = decodePhase(p.velW.w) + M_PI_F; // +π = inverted; wrapped at pack
            
            // Absolute Energy Damping: Absorb incoming force without moving
            finalV = float3(0.0f);
            
            // Optical Stealth: Negative temperature kills HDR emission, rendering them black
            currentTemp = -5.0f;
        }
    }

    // ── ODS-01: Quantum Entanglement (Telepathy) ──────────────────────────────────
    if (u.debugFlags & (1 << 7)) { // Reserved bit 7 for ODS-01
        uint partnerID = p.entanglement.x;
        if (partnerID < (uint)u.particleCount) {
            float partnerTemp = prevParticles[partnerID].prevW.w;
            // Telepathic state transfer (instant action at a distance)
            if (partnerTemp > currentTemp) {
                currentTemp = mix(currentTemp, partnerTemp, 0.2f * dt); // Absorb heat
                newPhase = mix(newPhase, decodePhase(prevParticles[partnerID].velW.w), 0.1f * dt); // Phase sync
            }
        }
    }

    // ── USER SPIN: rotate the whole body by the spin torque (radius-preserving
    // so it stays a solid shape at any RPM). prevW stays the pre-spin position,
    // so the velocity proxy carries the rotation → light trails show the spin.
    {
        float3 preRot = nextPos;
        float aY = u.spinY * dt;            // around Y (left/right)
        if (aY != 0.0f) {
            float c = cos(aY), s = sin(aY);
            float nx =  nextPos.x * c + nextPos.z * s;
            float nz = -nextPos.x * s + nextPos.z * c;
            nextPos.x = nx; nextPos.z = nz;
        }
        float aX = u.spinX * dt;            // around X (up/down)
        if (aX != 0.0f) {
            float c = cos(aX), s = sin(aX);
            float ny = nextPos.y * c - nextPos.z * s;
            float nz = nextPos.y * s + nextPos.z * c;
            nextPos.y = ny; nextPos.z = nz;
        }
        // Fold the rotational displacement into the stored velocity so the
        // per-particle light trails (velDir2D) show the SPIN — otherwise it's a
        // rigid rotation with no trails and reads like a stuck camera.
        finalV += (nextPos - preRot);

        // RADIUS-SHELL LOCK while spinning. The fold above is re-integrated as
        // translation next frame, which pushes each particle off its circle
        // onto a slightly larger radius every frame → an outward tangent-drift
        // spiral that piles up against the cap (~11) → the "square brick wall"
        // clipped by the viewport at high RPM. Locking each particle back to
        // its own radius (the pre-integration distance) makes the whole body
        // rotate as a RIGID geometric shape — consistent at any speed.
        // Gated on spin: 0 at rest (no change), full at high RPM.
        float spinLock = 1.0f - spinSuppress;
        if (spinLock > 0.001f) {
            float r0 = length(float3(px, py, pz));
            float rN = length(nextPos);
            if (rN > 1e-4f) {
                float3 locked = nextPos * (r0 / rN);
                nextPos = mix(nextPos, locked, spinLock);
            }
        }
    }

    // ── RADIATIVE COOLING (Stefan-Boltzmann, dE/dt ∝ T⁴) ────────────────────
    // Hot matter radiates its energy away as light → it COOLS, fast when hot,
    // slow when cool (the real T⁴ law). Because it's T⁴ this targets the HOT
    // played/supernova matter (fading blue→red over time = the Crab's evolution)
    // and barely touches the cool ambient disk. Only positive temps cool;
    // stealth's negative temp is left alone. Floored at 0.
    // ── TEMPERATURE UNIFICATION slice A (2026-07-07, spec §8: one honest
    // temp unit). The SPH energy ledger u (c² sim units, ceiling 0.3 ↔
    // T≈1.35e12 K) is THE temperature; the display channel shows its
    // RADIANCE temperature: displayT = 12·(u/u_cap)^¼ — Stefan-Boltzmann
    // flux compression, because honest gas temps here span 1e6–1e12 K and
    // a linear Kelvin map would pin the whole field blue-white. Anchors:
    // substrate u~4e-5 → 1.3 (warm, below the 2.5 nova threshold); real
    // shock u~0.01 → 5.1 (glowing plasma); cap → 12 = SN_TEMP_PEAK. The
    // glow follows the real energy: slice-4 cooling decays u, display
    // follows; novae/TDE flashes ride on top via max(). Shock-heated
    // fly-through gas (reaction ladder) is finally VISIBLE — no scripts.
    if ((u.bhToggles & 0x1000u) && mass > 0.001f && mass < 1e8f) {  // bit12: SPH heat live
        float ui = sphU[id];
        if (ui > 0.0f && !notFinite1(ui)) {
            // AMBIENT-SUBTRACTED exposure (2026-07-07 3rd pass — MEASURED):
            // the [SPH] ledger samples ~19.7k particles at U≈100 → substrate
            // u_avg ≈ 5.1e-3 (2nd pass used 5e-5: divided by the full 2M
            // instead of the ledger's sample → 100× under → whole field
            // golden, then white-hot as heat concentrated). Ambient set just
            // ABOVE the measured average: the bulk field renders dark in its
            // mass-blackbody colours; only genuinely above-ambient pockets
            // (shocked gas, feeding cores, umax=0.3 bombs) glow. DEBT: this
            // ambient (T~2e10 K!) is the substrate-noise pump, not honest
            // cluster physics — the dissipation thread owns the real cure.
            // SELF-CALIBRATING ambient (2026-07-12): 1.2× the live mass-
            // weighted mean u — bulk field dark, above-ambient pockets glow.
            // The old hardcoded 6e-3 was measured against dead-ρ gas; the
            // density floor moved the substrate and everything lit up.
            // SELF-CALIBRATING ambient: 1.2× the live mass-weighted mean u.
            // The hardcoded 6e-3 was measured against dead-ρ gas; the density
            // floor moved the substrate and the whole field lit up (the blob).
            float U_AMBIENT = max(u.uAmbient * 1.2f, 1e-4f);
            float uEx = max(ui - U_AMBIENT, 0.0f);
            float bridgeT = 12.0f * pow(min(uEx, 0.3f) * (1.0f / 0.3f), 0.25f);
            currentTemp = max(currentTemp, bridgeT);
        }
    }
    if (currentTemp > 0.0f) {
        float T = currentTemp;
        currentTemp -= dt * 0.0005f * (T * T * T * T);
        currentTemp = max(currentTemp, 0.0f);
    }

    // ── Write back ───────────────────────────────────────────────────
    if (mass > 0.0f) {
        // NaN/INF TRIPWIRE — self-healing field. The play pipeline can emit
        // occasional non-finite particles (float-edge cases at star-map radii);
        // harmless when particles were independent, but the self-gravity
        // near-field READS neighbour centroids, so one bad star infects its
        // 27 cells and the whole field dies in seconds (measured: every
        // play→NaN blackout today). Containment: a star whose state goes
        // non-finite is respawned at its stored star-map home, at rest, cold —
        // same frame, before it can poison a centroid. Source rate of the
        // play-pipeline NaNs still TODO (the r≤3-domain voice-math audit).
        if (notFinite3(nextPos) || notFinite3(finalV)) {
            float r_home = p.spinW.x;
            float theta  = as_type<float>(p.entanglement.z);
            float aphi   = as_type<float>(p.entanglement.w);
            float st = sin(theta);
            float3 home = r_home * float3(st * cos(aphi), st * sin(aphi), cos(theta));
            p.prevW = float4(home, 0.0f);   // zero velocity, cold
            p.posW  = float4(home, mass);
            p.velW  = float4(0.0f);
            return;
        }
        if (notFinite1(currentTemp)) currentTemp = 0.0f; // T⁴ overflow → inf−inf
        // CENTER OF GRAVITY PINNED AT 0/0/0 (Jamal): drift the field gently
        // toward the origin by a SMALL, CLAMPED fraction of the measured COM
        // per frame. Full-gain subtraction destroyed the field (the COM
        // readback tears; one garbage value teleported everything, feedback
        // ran away, 99% of stars died — measured). Gain 2%/frame, max
        // 0.02 units/frame: converges in ~1 s, noise-immune, velocities
        // untouched (pos and prev shift equally).
        float3 comShift = float3(u.comX, u.comY, u.comZ) * 0.02f;
        comShift = clamp(comShift, -0.02f, 0.02f);
        if (notFinite3(comShift)) comShift = float3(0.0f);
        // TEMP-CLOSURE: work done BY the SPH pressure force this frame — exact
        // F·Δx for a force held constant over the frame (comShift excluded: it
        // moves pos and prev equally, no velocity change). Honest books demand
        // Σ W_sph = −Σ m·du(dynamics); the [CLOSURE] watchdog line prints both.
        if (u.bhToggles & 0x800u) {
            float3 dxW = nextPos - posEntry;
            float wSph = mass * dot(sphForce[id].xyz, dxW);
            if (!isfinite(wSph)) wSph = 0.0f;  // NaN guard — else int(NaN) slams the counter
            float wSum = simd_sum(wSph);
            if (simd_is_first())
                atomic_fetch_add_explicit(&sphClosure[0], int(wSum),  // ×1.0: ×1e2 saturated at honest ρ
                                          memory_order_relaxed);
        }
        p.prevW = float4(float3(px, py, pz) - comShift, currentTemp);
        p.posW = float4(nextPos - comShift, mass);
        // Wrap phase into [0, 2π) before packing — a clamp here saturated every
        // particle to phaseBits=max → identical hue. fmod can return negative,
        // so add a turn to land in [0, 2π).
        float wrapped = fmod(newPhase + M_PI_F, 2.0f * M_PI_F);
        if (wrapped < 0.0f) wrapped += 2.0f * M_PI_F;
        // Pack band ID (3 bits) into upper bits of phase float
        uint phaseBits = (uint)((wrapped / (2.0f * M_PI_F)) * (float)0x1FFFFFFFu);
        uint bandBits = (uint)(bestBand & 0x7);
        uint packed = (bandBits << 29) | phaseBits;
        p.velW = float4(finalV, as_type<float>(packed));
    }
}

// ── STELLAR MERGERS — the US2 "eating" (emergent-BH arc, step 2) ─────────────
// Real collisions are INELASTIC: two touching stars MERGE — the heavier eats
// the lighter, mass adds, momentum is conserved, the relative kinetic energy
// thermalizes (this is THE dissipation sink that lets piled mass STAY piled
// instead of bouncing back out — gravity alone is conservative).
// Scale honesty: at the Sgr A* anchor 1 R_sun = 0.0549 sim units, so stars in
// a crushed core (spacing ~0.008) physically OVERLAP — contact merging is the
// real outcome (runaway collisions in nuclear clusters are real astrophysics).
//
// Race-free GPU scheme: pair = MUTUAL nearest contact partner, decided by both
// threads independently from the SAME immutable snapshot (sortedParticles,
// built this frame before this kernel). Each thread writes ONLY its own
// particle: the winner (heavier; tie → lower id) absorbs, the loser dies
// (mass→0, parked outside the domain, frozen). At most one merge per star per
// frame. Resolution limits: partners come from the ≤32 scattered samples/cell,
// and contact reach is capped at 1.45·cellSize (the 27-cell scan); both only
// RATE-limit merging, never break conservation.


// ONE THREAD PER CELL (the centroid pass's architecture — the per-STAR version
// cost 120fps→37: 2M threads × random 80B struct reads; per-cell reads are
// contiguous and only dense cells do real work). Each cell-thread greedily
// pairs its own ≤32 scattered entries by nearest contact, sequentially —
// deterministic, no mutuality double-scan needed, and RACE-FREE because every
// particle belongs to exactly one cell: only its own cell's thread may write
// it. Cross-cell contact pairs are missed (rate-limit only, conservation safe).
kernel void merge_stars(
    device Particle* particles [[buffer(0)]],          // written by ORIGINAL id
    device const SortedHot* sorted [[buffer(1)]],      // immutable HOT snapshot (48B)
    device const uint* cellStarts [[buffer(2)]],
    device const uint* cellCounts [[buffer(3)]],
    constant SpatialHashUniforms& su [[buffer(4)]],
    constant PhysicsUniforms& u [[buffer(5)]],
    device atomic_uint* claimed [[buffer(6)]],         // per-particle merge claim (zeroed each frame)
    uint cid [[thread_position_in_grid]])
{
    uint totalCells = uint(su.gridSize) * uint(su.gridSize) * uint(su.gridSizeZ);
    if (cid >= totalCells) return;
    // Attack: hash is stale (not rebuilt during attack) — no merging.
    if (u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f) return;

    // BOUNDARY SHELL EXCLUDED (same rule as reduce_cell_max): assign_cells
    // clamps every escaper outside ±halfExtent into the outermost cells, and
    // the r≈1000 position wall physically piles them up until they touch —
    // ARTIFICIAL contact. Mergers there are clamp artifacts, and they were
    // BIRTHING SEEDS AT THE WALL (measured: registry led by out-of-domain
    // seeds, exit=304). Only interior cells merge.
    {
        int g = su.gridSize;
        int bx = int(cid) % g;
        int by = (int(cid) / g) % g;
        int bz = int(cid) / (g * g);
        if (bx == 0 || by == 0 || bz == 0 ||
            bx == g - 1 || by == g - 1 || bz == g - 1) return;
    }
    uint count = min(cellCounts[cid], 32u);            // scatter writes ≤32
    if (count < 1u) return;   // cross-cell: a lone star can touch a neighbour-cell partner
    uint start = cellStarts[cid];

    // CROSS-CELL MERGING (2026-07-07): the old same-cell-only pairing left
    // every contact pair straddling a cell boundary INVISIBLE — at contact
    // radius ~0.3–0.6 and cellSize 1 that is roughly HALF of all touching
    // pairs. They ground at r≪h in the SPH kernel forever, booking du of
    // order the whole thermal budget per step — the measured escaper-fountain
    // pump (docs/ejector_hunt_2026-07-07.md). Pairing now scans the own cell
    // (later slots) + the 13 FORWARD neighbour cells, so every pair has
    // exactly ONE initiator; per-particle atomic claims replace used[] so no
    // participant can merge twice in a frame (cross-cell pairs are contested
    // by other initiator cells).
    int g = su.gridSize;
    int bxh = int(cid) % g;
    int byh = (int(cid) / g) % g;
    int bzh = int(cid) / (g * g);
    const int3 fwd[13] = {
        int3(1, 0, 0),
        int3(-1, 1, 0), int3(0, 1, 0), int3(1, 1, 0),
        int3(-1, -1, 1), int3(0, -1, 1), int3(1, -1, 1),
        int3(-1, 0, 1),  int3(0, 0, 1),  int3(1, 0, 1),
        int3(-1, 1, 1),  int3(0, 1, 1),  int3(1, 1, 1)
    };

    for (uint i = 0; i < count; i++) {
        SortedHot a = sorted[start + i];
        float ma = a.posW.w;
        // Seeds neither merge nor get merged here — they grow ONLY via the
        // victim-initiated feeding path (seed_mark/seed_apply), which keeps
        // them immortal: a dead seed would leak its in-flight accumulator.
        if (ma <= 0.001f || ma >= M_BH_SEED) continue; // dead / seed / wall
        if (notFinite3(a.posW.xyz)) continue;
        uint aOrig = a.entanglement.y;                 // original id (scatter)
        if (aOrig >= uint(u.particleCount)) continue;  // stale id (count switch)
        float aR = MERGE_RSUN_SIM * pow(ma, 0.8f);     // main-sequence R ∝ M^0.8

        // Nearest contact partner: own cell's LATER entries (scan 0) + the 13
        // forward neighbour cells (scans 1..13).
        uint bestRef = 0xFFFFFFFFu;
        float bestD2 = 1e30f;
        for (uint s = 0u; s <= 13u; s++) {
            uint scanStart, scanFrom, scanCount;
            if (s == 0u) {
                scanStart = start; scanFrom = i + 1u; scanCount = count;
            } else {
                int nx = bxh + fwd[s - 1u].x;
                int ny = byh + fwd[s - 1u].y;
                int nz = bzh + fwd[s - 1u].z;
                if (nx < 0 || ny < 0 || nz < 0 ||
                    nx >= g || ny >= g || nz >= su.gridSizeZ) continue;
                // Boundary shell excluded — same rule as the home cell.
                if (nx == 0 || ny == 0 || nz == 0 || nx == g - 1 ||
                    ny == g - 1 || nz == su.gridSizeZ - 1) continue;
                uint ncID = uint((nz * g + ny) * g + nx);
                scanStart = cellStarts[ncID]; scanFrom = 0u;
                scanCount = min(cellCounts[ncID], 32u);
            }
            for (uint j = scanFrom; j < scanCount; j++) {
                SortedHot cand = sorted[scanStart + j];
                float mb = cand.posW.w;
                if (mb <= 0.001f || mb >= 1e8f) continue;
                float3 d = cand.posW.xyz - a.posW.xyz;
                float d2 = dot(d, d);
                float rc;
                if (ma >= M_BH_SEED || mb >= M_BH_SEED) {
                    // BH-SEED CAPTURE: tidal-disruption radius — the hole
                    // shreds and swallows anything inside
                    // R_t = R_star·(M_BH/m_star)^(1/3), far beyond stellar
                    // contact; ×1.5 for gravitational focusing. Grows with
                    // every meal → THE runaway breaker: the first seed
                    // out-eats every competing cluster.
                    float mBig = max(ma, mb), mSmall = min(ma, mb);
                    float rStar = MERGE_RSUN_SIM * pow(mSmall, 0.8f);
                    rc = 1.5f * rStar * pow(mBig / mSmall, 1.0f / 3.0f);
                } else {
                    // Stellar contact: separation < R_a + R_b — real radii.
                    rc = aR + MERGE_RSUN_SIM * pow(mb, 0.8f);
                }
                if (d2 < rc * rc && d2 < bestD2) {
                    bestD2 = d2;
                    bestRef = scanStart + j;
                }
            }
        }
        if (bestRef == 0xFFFFFFFFu) continue;

        SortedHot b = sorted[bestRef];
        float mb = b.posW.w;
        uint bOrig = b.entanglement.y;
        if (bOrig >= uint(u.particleCount)) continue;  // stale id

        // ── REACTION LADDER rung 1 — the BOUND-PAIR gate (2026-07-07) ────────
        // Contact fuses ONLY if the pair is gravitationally bound at contact:
        // v_rel < v_esc = √(2G(mₐ+m_b)/(Rₐ+R_b)). The gate-less rule merged
        // every geometric touch (~36/frame at rest; the disk-IC experiment
        // showed the cascade devouring all structure before shear could draw
        // arms). An unbound pair flies THROUGH — and the SPH viscosity+shock
        // rungs (slices 3+4, live) book that encounter honestly as heat.
        // Disrupt/plasma rungs come later (reaction-engine spec). Seed tidal
        // capture (either mass ≥ M_BH_SEED) stays ungated — separate channel.
        // Units: per-second² via the ×120 seed-capture convention (G1s·M/r
        // and |dv·120|² match — same expression as the focusing term above).
        float mergeViolence = 0.0f;            // (v_rel/v_esc)² ∈ [0,1) for the flash below
        if (ma < M_BH_SEED && mb < M_BH_SEED) {
            float3 vrel = (a.posW.xyz - a.prevW.xyz) - (b.posW.xyz - b.prevW.xyz);
            // ⏱️ v = displacement / dt (was the x120 frame assumption). This
            // one is NOT clamped by reach, so it gates fusion outright at the
            // `vrel2 >= vesc2 -> continue` below: an inflated vrel2 declares
            // BOUND pairs unbound and refuses the merge. Error scaled as warp^2,
            // which is why mergers died under time warp.
            float invDtM = 1.0f / max(u.dt, 1e-6f);
            float vrel2 = dot(vrel, vrel) * (invDtM * invDtM);
            float rcAB  = MERGE_RSUN_SIM * (pow(ma, 0.8f) + pow(mb, 0.8f));
            float G1s   = u.gravGM / max(u.massTotal, 1.0f);
            float vesc2 = 2.0f * G1s * (ma + mb) / max(rcAB, 1e-4f);
            if (vrel2 >= vesc2) continue;      // unbound: fly-through, no fusion
            mergeViolence = vrel2 / max(vesc2, 1e-20f);
        }
        // CLAIM PROTOCOL: own both participants atomically before writing.
        // Each pair has one initiator, but a PARTICLE can appear in pairs
        // from several initiator cells — first claimant wins, losers retry
        // next frame. Release a if b is contested (no deadlock: CAS never
        // blocks; no double-eat: claims are never released after a merge).
        uint expected = 0u;
        if (!atomic_compare_exchange_weak_explicit(
                &claimed[aOrig], &expected, 1u,
                memory_order_relaxed, memory_order_relaxed)) continue;
        expected = 0u;
        if (!atomic_compare_exchange_weak_explicit(
                &claimed[bOrig], &expected, 1u,
                memory_order_relaxed, memory_order_relaxed)) {
            atomic_store_explicit(&claimed[aOrig], 0u, memory_order_relaxed);
            continue;
        }
        // The heavier eats (tie → lower id).
        bool aWins = (ma > mb) || (ma == mb && aOrig < bOrig);
        uint wOrig = aWins ? aOrig : bOrig;
        uint lOrig = aWins ? bOrig : aOrig;
        SortedHot w = aWins ? a : b;
        SortedHot l = aWins ? b : a;

        // INELASTIC MERGE: barycentre, momentum conserved, relative KE
        // thermalizes → temperature bump (full Rankine-Hugoniot shock heating
        // comes with the supernova rung).
        float mW = w.posW.w, mL = l.posW.w;
        float3 vw = w.posW.xyz - w.prevW.xyz;          // per-frame displacement
        float3 vl = l.posW.xyz - l.prevW.xyz;
        float mNew = mW + mL;
        float3 posNew = (w.posW.xyz * mW + l.posW.xyz * mL) / mNew;
        float3 vNew = (vw * mW + vl * mL) / mNew;
        // NOVA FLASH from MEASURED dynamics (2026-07-07, rung 2 — replaces
        // the +2+6q mass-ratio heuristic, the spec's named debt §4.9): base
        // 2.0 = the binding-energy release every real merger radiates (the
        // luminous-red-nova transient, present even for the gentlest bound
        // capture); + 4·(v_rel/v_esc)² = exactly how violently the pair hit,
        // straight from the bound-pair gate's own numbers, ∈ [0,4). The T⁴
        // cooling decays it over seconds. Base clears the render threshold
        // (2.5 vs post-play residual ~1-2) so every true merger is visible.
        float tNew = max(w.prevW.w, l.prevW.w) + 2.0f + 4.0f * mergeViolence;
        // Stale ids can exceed the current buffer (count switched 5M→2M).
        if (wOrig >= uint(u.particleCount) || lOrig >= uint(u.particleCount))
            continue;

        // COMPARE-AND-WRITE GUARD — conservation insurance. The merge was
        // decided from the snapshot; if the LIVE buffer no longer matches
        // (stale sorted slot, wrong id, respawn transient — measured: stale
        // winner ids CREATED mass, Mlive 594k→2.8M), the data this merge is
        // based on is wrong: abort the pair. Valid merges (the vast
        // majority) see exact equality — posW.w is untouched between the
        // snapshot blit and this kernel.
        if (particles[wOrig].posW.w != mW || particles[lOrig].posW.w != mL)
            continue;

        particles[wOrig].posW = float4(posNew, mNew);
        particles[wOrig].prevW = float4(posNew - vNew, tNew);

        // EATEN: die. Mass → 0 (gravity/stats/render all gate on it), parked
        // far outside the domain and frozen so no force path resurrects it.
        float park = 4000.0f + float(lOrig % 1024);
        particles[lOrig].posW = float4(park, park, park, 0.0f);
        particles[lOrig].prevW = float4(park, park, park, l.prevW.w);
    }
}

// ── SEED MARK + VICTIM-INITIATED FEEDING (step 3's heart, v2) ────────────────
// The sample-based per-seed scan starved (sorted-slot desyncs measured for
// six straight probe cycles). INVERTED architecture: a tiny pass marks each
// seed's CELL in cellSeedMap; every star checks its 27 neighbour cells in
// compute_physics and, if inside a marked seed's capture radius, SACRIFICES
// ITSELF — parks, dies, and atomically adds its exact mass to the seed's
// accumulator. Each victim is its own thread: double-eating is structurally
// impossible. seed_apply then credits the seeds. No sampling, no sorted
// buffer, conservation exact by construction.

kernel void seed_mark(
    device const Particle* particles [[buffer(0)]],
    device uint* seedMeta [[buffer(1)]],               // [0]=count [4]=stable mirror
    device const uint* seedIds [[buffer(2)]],
    device uint* cellSeedMap [[buffer(3)]],            // 0 = none, else slot+1
    constant SpatialHashUniforms& su [[buffer(4)]],
    constant PhysicsUniforms& u [[buffer(5)]],
    uint tid [[thread_position_in_grid]])
{
    // Mirror the final registry count into the uncleared half of the buffer
    // so the CPU's log read can never land mid-clear and report a false 0.
    if (tid == 0u) seedMeta[4] = seedMeta[0];
    if (tid >= min(seedMeta[0], 1024u)) return;
    if (su.gridSize <= 0) return;
    uint sid = seedIds[tid];
    if (sid >= uint(u.particleCount)) return;
    float m = particles[sid].posW.w;
    if (m < M_BH_SEED || m >= 1e8f) return;
    float3 pos = particles[sid].posW.xyz;
    if (notFinite3(pos)) return;
    if (fabs(pos.x) >= su.halfExtent || fabs(pos.y) >= su.halfExtent ||
        fabs(pos.z) >= su.halfExtent) return;
    int cx = clamp(int((pos.x + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
    int cy = clamp(int((pos.y + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
    int cz = clamp(int((pos.z + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
    cellSeedMap[uint((cz * su.gridSize + cy) * su.gridSize + cx)] = tid + 1u;
}

// seedAccum layout per slot (8 uints): [0] mass ×64, [1] meals,
// [2,3,4] momentum ×65536 (signed, two's-complement wrap), [5] KE ×65536,
// [7] reserved.
// ⚠️ [6] IS NOT PER-SLOT. Slot 0's word 6 is a GLOBAL ledger: Σ mass ×64
// withdrawn from the hole by sustain rebirth this frame (2026-08-04 22:46:41).
// The whole 1024×8 buffer is cleared every frame (renderer.mm), so it is a
// per-frame total like the rest. Only slot 0's [6] is used; slots 1.. keep
// [6] unused.
kernel void seed_apply(
    device Particle* particles [[buffer(0)]],
    device const uint* seedMeta [[buffer(1)]],
    device const uint* seedIds [[buffer(2)]],
    device const atomic_uint* seedAccum [[buffer(3)]],
    constant PhysicsUniforms& u [[buffer(4)]],
    uint tid [[thread_position_in_grid]])
{
    uint nS = min(seedMeta[0], 1024u);

    // ── WITHDRAWAL: THE HOLE PAYS FOR SUSTAIN REBIRTH (2026-08-04 22:46:41) ──
    // THREAD 0 ONLY, and it is the sole writer of a mass in this block — the
    // scan below reads every seed's mass, so any other thread writing
    // concurrently would race the max-determination. One writer removes that
    // by construction.
    // No overlap with meal-crediting: withdrawal is non-zero only during
    // sustain (amplitude high), crediting runs only at rest (amplitude < 0.02),
    // so the two paths are mutually exclusive in practice.
    // Charged to the MOST MASSIVE body, which is the definition of the hole
    // used everywhere else (renderer.mm: bhSeedMass = gMaxMass).
    if (tid == 0u) {
        float wTot = float(atomic_load_explicit(&seedAccum[6],
                                                memory_order_relaxed)) * (1.0f / 64.0f);
        if (wTot > 0.0f && nS > 0u) {
            uint  bestSlot = 0xFFFFFFFFu;
            float bestM    = 0.0f;
            for (uint k = 0u; k < nS; ++k) {
                uint kid = seedIds[k];
                if (kid >= uint(u.particleCount)) continue;
                float mk = particles[kid].posW.w;
                if (mk > bestM) { bestM = mk; bestSlot = k; }
            }
            // Clamp at 0: the corpses' total spawn mass cannot exceed what the
            // hole ate, so this should never bind. If it ever does, the excess
            // WAS minted — renderer.mm logs the shortfall rather than hiding it.
            if (bestSlot != 0xFFFFFFFFu) {
                float drain = min(wTot, bestM);
                particles[seedIds[bestSlot]].posW.w = bestM - drain;
            }
        }
    }

    // ── MEAL CREDITING ───────────────────────────────────────────────────────
    // Gate moved here from the renderer's dispatch condition (2026-08-04
    // 22:46:41): the CPU-side `totalAmplitude < 0.02` meant this kernel did not
    // run AT ALL while playing, so the withdrawal above — which only ever
    // happens while playing — would never have been applied. Crediting keeps
    // exactly its old behaviour; only the place the test lives changed.
    if (u.totalAmplitude >= 0.02f) return;    // no meal-crediting while playing
    if (tid >= nS) return;
    uint sid = seedIds[tid];
    if (sid >= uint(u.particleCount)) return;
    float m = particles[sid].posW.w;
    // ── ORPHANED DEPOSITS (2026-08-11 21:19:07) ──────────────────────────────
    // This guard used to `return` and DESTROY the slot's gain. A seed that was
    // itself eaten this frame parks with posW.w = 0 (the seed↔seed merge above),
    // so `m` reads 0 here — and every meal deposited into its plate by OTHER
    // threads in the same dispatch (stars it captured, smaller seeds that merged
    // into it) vanished from the books. The merge comment's "one victim per pair,
    // no mutual death" is true for a PAIR but says nothing about a CHAIN: A→B and
    // B→C in one frame makes B exactly this case. MEASURED signature: Mlive fell
    // 594,046 → 589,683 (−4,363) across the seeds 26→8 cascade at t=210–274s,
    // 81% of a 13.8-min run's entire −5,385 drift, then stayed flat for 9 min.
    // Nothing is dropped now: a dead slot's deposit is swept by ONE live slot.
    // Momentum and KE ride along with the mass so the swallow stays
    // momentum-conserving. One writer per particle is preserved: a slot only
    // ever writes its OWN seed.
    // ⚠️ THE SINK IS THE LOWEST-INDEX LIVE SLOT, NOT THE BIGGEST BODY (fixed
    // 2026-08-12 20:57:30). The first version picked the biggest, copying the
    // withdrawal block's "charge it to the most massive body" convention — but
    // that block runs on thread 0 alone precisely BECAUSE a mass scan races
    // concurrent writers, and its own comment says so. In the crediting phase
    // every thread writes `posW.w = m + gain`, so a max-scan can be read
    // differently by two threads, BOTH conclude they are the sink, and the
    // orphan is credited TWICE — mass created, the exact opposite of the point.
    // Aliveness is stable under those writes (crediting only ever GROWS a mass,
    // and neither the 50 nor the 1e8 bound can be crossed by a meal), so an
    // index comparison over live slots is race-free by construction.
    // Attribution is arbitrary either way — the true owner is whoever ate the
    // dead seed, a link the plate does not carry. The BOOKS ARE EXACT, which is
    // the property that was broken.
    bool alive = (m >= M_BH_SEED && m < 1e8f);
    if (!alive) return;                       // swept below by the sink, not lost
    // Single pass: am I the lowest-index live slot, and what did dead slots hold?
    uint  firstLive = tid;
    float oGain  = 0.0f;
    float oKe    = 0.0f;
    float3 oP    = float3(0.0f);
    for (uint k = 0u; k < nS; ++k) {
        uint  kid = seedIds[k];
        bool  inRange = (kid < uint(u.particleCount));
        float mk  = inRange ? particles[kid].posW.w : 0.0f;
        if (inRange && mk >= M_BH_SEED && mk < 1e8f) {
            // live: index only — never an ordering on the concurrently-written mass
            if (k < firstLive) firstLive = k;
            continue;
        }
        // dead or stale slot — its plate would otherwise be discarded
        oGain += float(atomic_load_explicit(&seedAccum[k * 8u + 0u],
                                            memory_order_relaxed)) * (1.0f / 64.0f);
        oP += float3(
            float(int(atomic_load_explicit(&seedAccum[k * 8u + 2u], memory_order_relaxed))),
            float(int(atomic_load_explicit(&seedAccum[k * 8u + 3u], memory_order_relaxed))),
            float(int(atomic_load_explicit(&seedAccum[k * 8u + 4u], memory_order_relaxed))))
            * (1.0f / 65536.0f);
        oKe += float(atomic_load_explicit(&seedAccum[k * 8u + 5u],
                                          memory_order_relaxed)) * (1.0f / 65536.0f);
    }
    bool iAmSink = (firstLive == tid);
    float gain = float(atomic_load_explicit(&seedAccum[tid * 8u + 0u],
                                            memory_order_relaxed)) * (1.0f / 64.0f);
    if (iAmSink) gain += oGain;
    if (gain <= 0.0f) return;
    // MOMENTUM-CONSERVING SWALLOW (2026-07-07): the victims' summed m·v rides
    // in with their mass. New velocity = total momentum / total mass — same
    // inelastic-merge rule as merge_stars, so eating no longer manufactures
    // momentum (old path: mass grew, velocity untouched ⇒ p appeared from
    // nothing). Velocity = per-frame displacement; applied via prevW.
    float3 pEat = float3(
        float(int(atomic_load_explicit(&seedAccum[tid * 8u + 2u], memory_order_relaxed))),
        float(int(atomic_load_explicit(&seedAccum[tid * 8u + 3u], memory_order_relaxed))),
        float(int(atomic_load_explicit(&seedAccum[tid * 8u + 4u], memory_order_relaxed))))
        * (1.0f / 65536.0f);
    if (iAmSink) pEat += oP;   // swept mass carries its momentum (see above)
    float3 vSeed = particles[sid].posW.xyz - particles[sid].prevW.xyz;
    float3 vNew = (vSeed * m + pEat) / (m + gain);
    if (notFinite3(vNew)) vNew = vSeed;        // poisoned deposit: keep mass books, skip kick
    particles[sid].posW.w = m + gain;
    particles[sid].prevW.xyz = particles[sid].posW.xyz - vNew;
    // TDE FLARE from the EXACT thermalized energy of the inelastic swallow:
    // ΔE = (KE_seed + ΣKE_victims) − KE_after ≥ 0 (momentum-conserving merge
    // always loses KE; clamp guards fixed-point rounding). The flare scales
    // with the meal's SPECIFIC energy against the engine's relativistic u-cap
    // (0.3 sim — keep in sync with spatial_hash.metal): a violent plunge
    // flares to the top of the range, a gentle drift-in glows just above the
    // render threshold (2.5). Replaces the old mass-ratio heuristic (gain/m).
    // T⁴ cooling fades it back to dark.
    float keDep = float(atomic_load_explicit(&seedAccum[tid * 8u + 5u],
                                             memory_order_relaxed)) * (1.0f / 65536.0f);
    if (iAmSink) keDep += oKe;
    float dE = max(0.0f, (0.5f * m * dot(vSeed, vSeed) + keDep) -
                         0.5f * (m + gain) * dot(vNew, vNew));
    float uMeal = dE / gain;                   // specific energy of the meal
    float t = particles[sid].prevW.w;
    particles[sid].prevW.w = max(t, 3.0f + 5.0f * min(1.0f, uMeal / 0.3f));
}

// ── (v1 sample-based seed_feed below: NOT dispatched — kept for reference) ───
// The per-cell merge pass samples ≤32 stars/cell, so a seed inside a 15k-star
// core cell got a merge chance ~0.2% of frames and STARVED (measured). Here
// every registered seed (count_cells appends ids of bodies ≥ M_BH_SEED) gets
// a dedicated thread that scans its 27-cell neighbourhood and EATS everything
// inside its tidal radius. Victims are CLAIMED by an atomic exchange on the
// mass word (posW.w): exactly one claimer receives the old bits — duplication
// is impossible by construction, so conservation is hardware-enforced even
// against the concurrent merge pass (whose compare-and-write guard then sees
// the mismatch and aborts its own attempt on the same star).
kernel void seed_feed(
    device Particle* particles [[buffer(0)]],          // live state
    device atomic_uint* particlesA [[buffer(1)]],      // SAME buffer, atomic view
    device const SortedHot* sorted [[buffer(2)]],      // immutable HOT snapshot (48B)
    device const uint* cellStarts [[buffer(3)]],
    device const uint* cellCounts [[buffer(4)]],
    device atomic_uint* seedMeta [[buffer(5)]],        // [0]=count [1]=meals [2]=eaten×64
    device const uint* seedIds [[buffer(6)]],
    constant SpatialHashUniforms& su [[buffer(7)]],
    constant PhysicsUniforms& u [[buffer(8)]],
    uint tid [[thread_position_in_grid]])
{
    uint nSeeds = atomic_load_explicit(&seedMeta[0], memory_order_relaxed);
    // Staged exit-code probe (thread 0 always launches in the 256 dispatch):
    // 100+n = entry (n = nSeeds GPU-side), 200 = past count/grid, 300 = past
    // phase, then 301..304 = sid/mass/nan/extent rejects, 305 = scanning.
    if (tid == 0u)
        atomic_store_explicit(&seedMeta[7], 100u + min(nSeeds, 99u),
                              memory_order_relaxed);
    if (tid >= min(nSeeds, 1024u)) return;
    if (su.gridSize <= 0) return;
    if (tid == 0u) atomic_store_explicit(&seedMeta[7], 200u, memory_order_relaxed);
    if (u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f) return; // stale hash
    if (tid == 0u) atomic_store_explicit(&seedMeta[7], 300u, memory_order_relaxed);

    uint sid = seedIds[tid];
    // Exit-code probe (thread 0): which gate rejects the seed?
    #define SEED_EXIT(code) { if (tid == 0u) atomic_store_explicit(&seedMeta[7], (code), memory_order_relaxed); return; }
    if (sid >= uint(u.particleCount)) SEED_EXIT(301u);
    float mSeed = particles[sid].posW.w;               // LIVE (post-merge-pass)
    if (mSeed < M_BH_SEED || mSeed >= 1e8f) SEED_EXIT(302u);
    float3 pos = particles[sid].posW.xyz;
    if (notFinite3(pos)) SEED_EXIT(303u);
    if (fabs(pos.x) >= su.halfExtent || fabs(pos.y) >= su.halfExtent ||
        fabs(pos.z) >= su.halfExtent) SEED_EXIT(304u);
    if (tid == 0u) atomic_store_explicit(&seedMeta[7], 305u, memory_order_relaxed);

    float3 vSeed = pos - particles[sid].prevW.xyz;
    float tSeed = particles[sid].prevW.w;

    int cx = clamp(int((pos.x + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
    int cy = clamp(int((pos.y + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
    int cz = clamp(int((pos.z + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);

    // BISECT meter: this seed thread passed every early-out and is scanning.
    atomic_fetch_add_explicit(&seedMeta[3], 1u, memory_order_relaxed);

    float bestD2 = 1e30f;   // nearest candidate, probe only

    float eaten = 0.0f;
    float3 eatenP = vSeed * mSeed;                     // momentum budget
    float3 posM = pos * mSeed;                         // barycentre budget
    int meals = 0;
    const int MAX_MEALS = 32;                          // bounded work per frame

    for (int z = max(0, cz - 1); z <= min(su.gridSize - 1, cz + 1) && meals < MAX_MEALS; z++) {
        for (int y = max(0, cy - 1); y <= min(su.gridSize - 1, cy + 1) && meals < MAX_MEALS; y++) {
            for (int x = max(0, cx - 1); x <= min(su.gridSize - 1, cx + 1) && meals < MAX_MEALS; x++) {
                uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                uint count = min(cellCounts[cID], 32u);
                uint start = cellStarts[cID];
                for (uint i = 0; i < count && meals < MAX_MEALS; i++) {
                    SortedHot v = sorted[start + i];
                    float mv = v.posW.w;
                    if (mv <= 0.001f || mv >= M_BH_SEED) continue;  // seeds don't eat seeds here
                    uint vOrig = v.entanglement.y;
                    if (vOrig == sid || vOrig >= uint(u.particleCount)) continue;
                    float3 d = v.posW.xyz - pos;
                    float d2 = dot(d, d);
                    bestD2 = min(bestD2, d2);
                    // Tidal disruption radius (the bare cross-section)…
                    float mNow = mSeed + eaten;
                    float rt = 1.5f * MERGE_RSUN_SIM * pow(mv, 0.8f) *
                               pow(mNow / mv, 1.0f / 3.0f);
                    // …boosted by GRAVITATIONAL FOCUSING — the accelerator.
                    // σ = πR_t²(1 + 2GM/(R_t·v_rel²)): a slow passer-by is
                    // captured from far beyond R_t, and the boost grows with
                    // the hole's mass → accretion self-accelerates as it
                    // eats. v_rel in sim/s = per-step displacement / u.dt.
                    // (Was "velW are per-frame, ×120" — a frame-rate
                    //  assumption dressed as a unit convention, which is why
                    //  it survived so long. Corrected 2026-08-29.)
                    // ⏱️ v = displacement / dt (was the x120 frame assumption).
                    float invDtA = 1.0f / max(u.dt, 1e-6f);
                    float3 dv = ((v.posW.xyz - v.prevW.xyz) - vSeed) * invDtA;
                    float vrel2 = max(dot(dv, dv), 1e-4f);
                    float G1 = u.gravGM / max(u.massTotal, 1.0f);
                    float rt2 = rt * rt + rt * (2.0f * G1 * mNow) / vrel2;
                    float reach = 1.4f * su.cellSize;
                    rt2 = min(rt2, reach * reach);
                    if (d2 >= rt2) continue;
                    // CLAIM: atomically swap the victim's mass word with 0.
                    // Particle = 80B = 20 uints; posW.w is uint index id·20+3.
                    uint old = atomic_exchange_explicit(&particlesA[vOrig * 20u + 3u],
                                                        0u, memory_order_relaxed);
                    float mClaim = as_type<float>(old);
                    uint ob = old;
                    bool claimFinite = ((ob >> 23) & 0xFFu) != 0xFFu;
                    if (!claimFinite || mClaim <= 0.001f || mClaim >= M_BH_SEED) {
                        // lost the race / already dead / not a valid snack —
                        // if it was a real body we must NOT destroy it: restore.
                        if (claimFinite && mClaim > 0.001f)
                            atomic_exchange_explicit(&particlesA[vOrig * 20u + 3u],
                                                     old, memory_order_relaxed);
                        continue;
                    }
                    // OWNED: exact claimed mass, momentum from the snapshot.
                    eaten  += mClaim;
                    eatenP += (v.posW.xyz - v.prevW.xyz) * mClaim;
                    posM   += v.posW.xyz * mClaim;
                    // Victim: freeze in place, dead (mass word already 0).
                    particles[vOrig].prevW = float4(v.posW.xyz, v.prevW.w);
                    meals++;
                }
            }
        }
    }

    // PROBE (thread for the first seed): my cell's population, nearest
    // candidate distance ×1000, my mass — decodes the starvation.
    if (tid == 0u) {
        uint myCell = uint((cz * su.gridSize + cy) * su.gridSize + cx);
        atomic_store_explicit(&seedMeta[4], cellCounts[myCell], memory_order_relaxed);
        // Raw first sorted entry of my cell: its mass ×1000 and its orig id —
        // decodes WHY every candidate fails the gates.
        SortedHot p0 = sorted[cellStarts[myCell]];
        atomic_store_explicit(&seedMeta[5],
                              uint(clamp(p0.posW.w, 0.0f, 4000000.0f) * 1000.0f),
                              memory_order_relaxed);
        atomic_store_explicit(&seedMeta[6], p0.entanglement.y, memory_order_relaxed);
    }
    if (meals > 0) {
        // Meal meter (telemetry): meals + eaten mass this frame, all seeds.
        atomic_fetch_add_explicit(&seedMeta[1], uint(meals), memory_order_relaxed);
        atomic_fetch_add_explicit(&seedMeta[2], uint(eaten * 64.0f + 0.5f),
                                  memory_order_relaxed);
    }
    if (eaten > 0.0f) {
        float mNew = mSeed + eaten;
        float3 posNew = posM / mNew;
        float3 vNew = eatenP / mNew;
        // TDE FLARE: a feeding hole flares (the darkSeed render exception
        // shows it while temp > 2.5); T⁴ cooling fades it back to dark.
        float tNew = max(tSeed, 3.0f + 2.0f * min(1.0f, eaten / mSeed));
        particles[sid].posW = float4(posNew, mNew);
        particles[sid].prevW = float4(posNew - vNew, tNew);
    }
}

// ── Conservation law reduction kernel ───────────────────────────────────────

struct PartialStats {
    float kineticEnergy;
    float momentumX;
    float momentumY;
    float sumMass;   // Σ stellar mass (M_sun) of live stars (was pad)
    float sumTemp;   // Σ temperature (→ avg)
    float maxTemp;   // max temperature
    float sumSpeed;  // Σ |v| (→ avg)
    float maxSpeed;  // max |v|
    float sumPx;     // Σ mass·position of live stars (→ mass-weighted COM)
    float sumPy;
    float sumPz;
    float sumCount;  // live star count
    float sumR;      // Σ |r| of live stars (→ mean radius)
    float maxR;      // farthest live star
    float maxMass;   // heaviest body (M_sun) — watches the seed grow
    // Σ mass held by SEED-CLASS bodies (m ≥ M_BH_SEED), i.e. how much of the
    // field has already organised into heavy bodies rather than loose stars.
    // Added 2026-08-03 into the old pad3 slot (no new buffer, no new dispatch)
    // to measure the fake-pull gate BEFORE choosing its thresholds. maxMass
    // only ever reports the single biggest body; this reports the population.
    float sumSeedMass;
    float sumEncX;   // Σ mass·position of stars within R_ENC of the candidate
    float sumEncY;   //   → enclosed MASS (M_sun) + refined core COM
    float sumEncZ;
    float sumEncMass;
};

kernel void reduce_stats(
    device const Particle* particles [[buffer(0)]],
    device PartialStats* partialSums [[buffer(1)]],
    constant PhysicsUniforms& u [[buffer(2)]],
    device atomic_uint* radialMass [[buffer(3)]],
    uint id [[thread_position_in_grid]],
    uint tid [[thread_position_in_threadgroup]],
    uint tgSize [[threads_per_threadgroup]],
    uint tgId [[threadgroup_position_in_grid]])
{
    threadgroup float sharedKE[256];
    threadgroup float sharedMX[256];
    threadgroup float sharedMY[256];
    threadgroup float sharedST[256];  // sum temp
    threadgroup float sharedMT[256];  // max temp
    threadgroup float sharedSS[256];  // sum speed
    threadgroup float sharedMS[256];  // max speed
    threadgroup float sharedPX[256];  // Σ live position → COM (self-gravity)
    threadgroup float sharedPY[256];
    threadgroup float sharedPZ[256];
    threadgroup float sharedCT[256];  // live star count
    threadgroup float sharedSM[256];  // Σ stellar mass (M_sun)
    threadgroup float sharedMM[256];  // max stellar mass (the seed watch)
    threadgroup float sharedSD[256];  // Σ mass of seed-class bodies (m ≥ M_BH_SEED)
    threadgroup float sharedSR[256];  // Σ radius
    threadgroup float sharedMR[256];  // max radius
    threadgroup float sharedEX[256];  // Σ m·pos within R_ENC of BH candidate
    threadgroup float sharedEY[256];
    threadgroup float sharedEZ[256];
    threadgroup float sharedEC[256];  // Σ mass (M_sun) within R_ENC

    float ke = 0.0f, mx = 0.0f, my = 0.0f;
    float temp = 0.0f, speed = 0.0f;
    float3 lpos = float3(0.0f);
    float pmass = 0.0f;
    bool real = false;

    if (int(id) < u.particleCount) {
        float mass = particles[id].posW.w;
        pmass = mass;
        float vx = particles[id].velW.x;
        float vy = particles[id].velW.y;
        float vz = particles[id].velW.z;
        ke = 0.5f * mass * (vx * vx + vy * vy + vz * vz);
        mx = mass * vx;
        my = mass * vy;
        if (mass > 0.001f) {                 // skip wall particles
            float px = particles[id].posW.x;
            float py = particles[id].posW.y;
            float pz = particles[id].posW.z;
            // MEASURED state (2026-06-13 audit — Jamal: "keep it real"). The
            // old speed/temp were analytic functions of RADIUS (√(0.5/r),
            // 1.089e12/r) — the IDEAL Keplerian value at that radius, NOT the
            // star's actual motion. A star flung outward fast read as cold &
            // slow. Now both derive from the star's REAL simulated velocity
            // (velW = per-frame displacement; ×120 = sim/s on screen):
            //   v/c : sim/s · kUnitMeters / (K_timelapse · c). Constant =
            //         120·1.269e10/(400·2.998e8) ≈ 12.70 per per-frame unit.
            //   T   : thermalized kT = μ·m_p·v²/(3·k_B), v in m/s, μ=0.6
            //         ionized plasma → T[K] ≈ 3.51e14·|v_perframe|².
            // NOTE: |v| can exceed c here — the sim does NOT yet cap velocity
            // at c (speedCap=1.2/frame ≈ 15c). The superluminal readout is
            // HONEST: it exposes the missing relativistic bound, whose real
            // fix couples to the K=400 time-lapse (architectural — see audit).
            float3 vlin = particles[id].velW.xyz;       // per-frame displacement
            float vmag  = length(vlin);
            // FRAME-RATE-CORRECT v/c (Phase A1): velW is displacement per FRAME
            // (per u.dt, not a fixed 1/120), and the light cap is |v| ≤ u.speedCap
            // (c in sim/s). So v/c = |velW| / (c·dt) = |velW|/(u.speedCap·u.dt) —
            // uses the REAL dt, correct at any FPS, reads exactly 1.0 at the cap
            // (the old 120-based ×34.14 over-reported as 40c at low FPS).
            float cFrame = u.speedCap * max(u.dt, 1e-6f);   // c as a per-frame step
            float vc     = vmag / max(cFrame, 1e-9f);       // v/c
            speed = vc;
            // Real thermalized plasma T: kT = μ·m_p·v²/3 → T[K] = (μ m_p c²/3k_B)·
            // (v/c)² = 2.178e12·(v/c)² (μ=0.6 ionized H/He).
            temp  = 2.178e12f * vc * vc;
            lpos  = float3(px, py, pz);
            real  = true;
        }
    }

    sharedKE[tid] = ke;
    sharedMX[tid] = mx;
    sharedMY[tid] = my;
    sharedST[tid] = real ? temp : 0.0f;
    sharedMT[tid] = real ? temp : -1e9f;
    sharedSS[tid] = real ? speed : 0.0f;
    sharedMS[tid] = real ? speed : -1e9f;
    // Mass-weighted: COM must be where the MASS is (stars carry real IMF
    // masses now), else a lucky cluster of O-stars pulls toward the wrong
    // point. Readback divides by sumMass.
    float lm = (real && pmass < 1e8f) ? pmass : 0.0f;  // incl. BH seeds
    sharedPX[tid] = lpos.x * lm;
    sharedPY[tid] = lpos.y * lm;
    sharedPZ[tid] = lpos.z * lm;
    sharedCT[tid] = real ? 1.0f : 0.0f;
    sharedSM[tid] = lm;
    sharedMM[tid] = lm;
    // lm already excludes walls (pmass < 1e8) and the dead, so the seed test is
    // just the mass threshold — the SAME M_BH_SEED the origin-pin and the
    // capture paths gate on, so this measures exactly the population that fake
    // pull acts upon.
    sharedSD[tid] = (lm >= M_BH_SEED) ? lm : 0.0f;
    float lr = length(lpos);
    sharedSR[tid] = real ? lr : 0.0f;
    sharedMR[tid] = real ? lr : -1e9f;
    // Emergent-BH enclosure (Step 2): R_ENC = 0.5 sim units around the
    // densest region (u.bh*, 1-frame lag). Enclosed Σmass is the REAL
    // stellar mass in M_sun; the geometric BH criterion (Step 3) compares
    // it against M_crit(R_ENC) = R_ENC·unit/r_s(M_sun).
    float3 encD = lpos - float3(u.bhX, u.bhY, u.bhZ);
    bool enc = real && (dot(encD, encD) < 0.25f);   // R_ENC² = 0.25
    // RADIAL PROFILE: bin this star's mass into its shell around the candidate,
    // so the CPU can find the honest horizon r_h (largest r with r_s(M(<r))≥r).
    if (real && lm > 0.0f) {
        float encDist = length(encD);
        if (encDist < RADIAL_MAX_R) {
            uint shell = min(uint(encDist * RADIAL_INV_DR), RADIAL_SHELLS - 1u);
            atomic_fetch_add_explicit(&radialMass[shell],
                                      uint(lm * RADIAL_MASS_SCALE), memory_order_relaxed);
        }
    }
    sharedEX[tid] = enc ? lpos.x * lm : 0.0f;
    sharedEY[tid] = enc ? lpos.y * lm : 0.0f;
    sharedEZ[tid] = enc ? lpos.z * lm : 0.0f;
    sharedEC[tid] = enc ? lm : 0.0f;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tgSize / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            sharedKE[tid] += sharedKE[tid + stride];
            sharedMX[tid] += sharedMX[tid + stride];
            sharedMY[tid] += sharedMY[tid + stride];
            sharedST[tid] += sharedST[tid + stride];
            sharedSS[tid] += sharedSS[tid + stride];
            sharedPX[tid] += sharedPX[tid + stride];
            sharedPY[tid] += sharedPY[tid + stride];
            sharedPZ[tid] += sharedPZ[tid + stride];
            sharedCT[tid] += sharedCT[tid + stride];
            sharedSM[tid] += sharedSM[tid + stride];
            sharedMM[tid]  = max(sharedMM[tid], sharedMM[tid + stride]);
            sharedSD[tid] += sharedSD[tid + stride];
            sharedSR[tid] += sharedSR[tid + stride];
            sharedEX[tid] += sharedEX[tid + stride];
            sharedEY[tid] += sharedEY[tid + stride];
            sharedEZ[tid] += sharedEZ[tid + stride];
            sharedEC[tid] += sharedEC[tid + stride];
            sharedMR[tid]  = max(sharedMR[tid], sharedMR[tid + stride]);
            sharedMT[tid]  = max(sharedMT[tid], sharedMT[tid + stride]);
            sharedMS[tid]  = max(sharedMS[tid], sharedMS[tid + stride]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        partialSums[tgId].kineticEnergy = sharedKE[0];
        partialSums[tgId].momentumX = sharedMX[0];
        partialSums[tgId].momentumY = sharedMY[0];
        partialSums[tgId].sumMass  = sharedSM[0];
        partialSums[tgId].maxMass  = sharedMM[0];
        partialSums[tgId].sumSeedMass = sharedSD[0];
        partialSums[tgId].sumTemp  = sharedST[0];
        partialSums[tgId].maxTemp  = sharedMT[0];
        partialSums[tgId].sumSpeed = sharedSS[0];
        partialSums[tgId].maxSpeed = sharedMS[0];
        partialSums[tgId].sumPx    = sharedPX[0];
        partialSums[tgId].sumPy    = sharedPY[0];
        partialSums[tgId].sumPz    = sharedPZ[0];
        partialSums[tgId].sumCount = sharedCT[0];
        partialSums[tgId].sumR     = sharedSR[0];
        partialSums[tgId].maxR     = sharedMR[0];
        partialSums[tgId].sumEncX  = sharedEX[0];
        partialSums[tgId].sumEncY  = sharedEY[0];
        partialSums[tgId].sumEncZ  = sharedEZ[0];
        partialSums[tgId].sumEncMass = sharedEC[0];
    }
}
