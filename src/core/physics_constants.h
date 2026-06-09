#pragma once
// ─────────────────────────────────────────────────────────────────────────────
// SPACE SYNTH — REAL-PHYSICS CONSTANT BACKBONE
// The instrument runs on LAWS + a few measured anchors, not a streamed dataset.
// Every value here is SOURCED — no guesses (the PURPLE way). See the memory:
// space_synth_governing_model / space_synth_physics_canon.
//
// The model: 3 real scalars — MASS (kg), TEMPERATURE (K), DENSITY (kg/m³) —
// drive the states of matter + the stellar lifecycle + collapse; the visual is
// the readout. Follow the science → insane results; cheat → crashes.
// ─────────────────────────────────────────────────────────────────────────────
namespace space {
namespace phys {

// ── Universal physical constants (SI, CODATA 2018) ──────────────────────────
constexpr double G      = 6.67430e-11;   // gravitational constant   [m³ kg⁻¹ s⁻²]
constexpr double C      = 2.99792458e8;  // speed of light           [m s⁻¹]   HARD CAP: nothing exceeds this
constexpr double C2     = C * C;         // c²                       [m² s⁻²]
constexpr double SIGMA  = 5.670374419e-8;// Stefan-Boltzmann         [W m⁻² K⁻⁴]
constexpr double K_B    = 1.380649e-23;  // Boltzmann                [J K⁻¹]
constexpr double H_PL   = 6.62607015e-34;// Planck                   [J s]

// ── Solar / stellar reference units ─────────────────────────────────────────
constexpr double M_SUN  = 1.98892e30;    // solar mass               [kg]
constexpr double R_SUN  = 6.957e8;       // solar radius             [m]
constexpr double L_SUN  = 3.828e26;      // solar luminosity         [W]   (IAU)
constexpr double T_SUN  = 5772.0;        // solar effective temp     [K]   (IAU)
constexpr double AU     = 1.495978707e11;// astronomical unit        [m]

// ── STATE-OF-MATTER temperature thresholds [K] ──────────────────────────────
// Temperature sets the state (density sets the exotic/collapsed ones).
constexpr double T_PLASMA_LO   = 1.0e4;  // atoms begin to ionize → plasma (the nebula glow)
constexpr double T_PLASMA_HI   = 1.0e7;  // fully ionized plasma
constexpr double T_FUSION_H    = 1.0e7;  // hydrogen fusion ignites (~1.3 keV, ρ≈150 g/cm³) → a STAR
constexpr double T_FUSION_HE   = 1.0e8;  // helium fusion
constexpr double T_IRON_CORE   = 1.0e10; // iron core (~1 MeV) → can't fuse → collapse
constexpr double T_QGP         = 2.0e12; // quark-gluon plasma (~150 MeV) — atoms dissolve into quarks
// ↑ "8 particles at c": collision KE thermalizes, kT≈(γ-1)mc²; v→c crosses T_QGP.

// ── STELLAR-LIFECYCLE mass thresholds [M☉] (fate is set by mass) ────────────
constexpr double M_DEUTERIUM   = 0.013;  // 13 M_Jup — deuterium burning floor (brown-dwarf)
constexpr double M_IGNITE_H    = 0.075;  // 0.075 M☉ (78 M_Jup) — hydrogen fusion ignites → STAR
constexpr double M_CHANDRA     = 1.39;   // Chandrasekhar limit — white-dwarf / collapse limit
constexpr double M_SUPERNOVA   = 8.0;    // ≥8 M☉ → iron-core collapse → core-collapse SUPERNOVA → neutron star
constexpr double M_BLACKHOLE   = 25.0;   // ≳25 M☉ (core too heavy) → BLACK HOLE
constexpr double M_STAR_MAX    = 150.0;  // ~upper stellar mass limit (Eddington)

// ── MAIN-SEQUENCE stellar lookup: mass → temperature → luminosity ───────────
// Color is NOT stored — derive it from t_eff via blackbody (Tanner-Helland,
// render.metal). luminosity ∝ M^3.5 → the rare hot stars carry ~all the light.
// SOURCE per row:
//   F,G,K,M = MEDIANS of the real NASA Exoplanet Archive stellar-host catalog
//             (data/nasa_stellar_catalog.csv, 27,184 stars; L via Stefan-Boltzmann
//             from measured R,T). Large samples, clean main sequence.
//   O,B,A   = canonical main-sequence values (Pecaut & Mamajek 2013 / textbook).
//             The exoplanet-host sample's high-mass bins are CONTAMINATED by
//             evolved giants (cool, bloated) → its O/B/A medians are unusable.
struct StellarClass {
    char   cls;        // spectral class letter
    double mass_lo;    // bin lower mass    [M☉]
    double mass_hi;    // bin upper mass    [M☉]
    double t_eff;      // representative effective temperature [K]
    double lum;        // representative luminosity            [L☉]
    double frac_imf;   // fraction of a real (IMF) stellar population
};
constexpr StellarClass MAIN_SEQUENCE[7] = {
    // cls  mass_lo  mass_hi   t_eff      lum        frac_imf      source
    { 'O',  16.0,   150.0,   40000.0,  100000.0,   0.0000003 }, // canonical MS
    { 'B',   2.1,    16.0,   15000.0,     500.0,   0.0013    }, // canonical MS
    { 'A',   1.4,     2.1,    8500.0,      15.0,   0.006     }, // canonical MS
    { 'F',   1.04,    1.4,    6078.0,       1.97,  0.03      }, // NASA catalog median
    { 'G',   0.8,     1.04,   5597.0,       0.77,  0.076     }, // NASA catalog median (Sun-like)
    { 'K',   0.45,    0.8,    4558.0,       0.17,  0.12      }, // NASA catalog median
    { 'M',   0.08,    0.45,   3383.0,       0.0135,0.76      }, // NASA catalog median (red dwarfs dominate)
};

// ── INITIAL MASS FUNCTION (Kroupa 2001) — the REAL birth distribution ───────
// dN/dM ∝ M^(-alpha). The unbiased population source (the catalog above is
// planet-host biased → inverted, ~46% G vs reality ~8%; use IT for relations,
// use THIS for how many of each). ~76% of stars end up M-dwarfs.
struct ImfSegment { double m_lo, m_hi, alpha; };
constexpr ImfSegment IMF_KROUPA[3] = {
    { 0.08, 0.50, 1.3 },   // low-mass
    { 0.50, 1.00, 2.3 },   // mid
    { 1.00, 150.0, 2.3 },  // high-mass (Salpeter slope)
};
constexpr double IMF_MEAN_MASS = 0.5;   // ≈ mass-weighted mean star [M☉] (for the conservation count)

// ── UNIT ANCHOR + conservation coupling ─────────────────────────────────────
// Conservation: M_black_hole = N_particles × mean_star_mass. Pick any two.
// One particle = one STAR (~1 M☉ unit; real mass sampled from IMF_KROUPA).
constexpr double PARTICLE_MASS_UNIT = M_SUN;   // 1 particle ≡ 1 M☉ reference [kg]

// Two candidate black-hole anchors (DECISION PENDING — see governing model):
//   gravitational radius r_g = G·M/c²  [m];  sim maps 1 unit = 2·r_g.
struct BlackHoleAnchor {
    const char* name;
    double mass_Msun;   // [M☉]
    double spin_a;      // dimensionless Kerr spin a*
    double r_g_m;       // gravitational radius [m]
    double m_per_sim;   // meters per sim unit (= 2·r_g)
};
constexpr BlackHoleAnchor BH_M87   = { "M87*",   6.5e9,  0.90, 9.60e12, 1.92e13 }; // EHT 2019; supermassive (alt)
constexpr BlackHoleAnchor BH_SGRA  = { "Sgr A*", 4.297e6,0.10, 6.35e9,  1.27e10 }; // GRAVITY 2022 — OUR galaxy's center
constexpr BlackHoleAnchor BH_ANCHOR = BH_SGRA;   // ★ LOCKED: the Milky Way (ours)
// Conservation check: Sgr A* (4.297e6 M☉) ÷ IMF_MEAN_MASS(0.5) ≈ 8.6e6 stars → renderable as real stars. ✓
//                     M87* (6.5e9 M☉) ÷ 5e6 particles ⇒ 1300 M☉/particle (NOT a star).

// ── OUR GALAXY — the MILKY WAY (anchor LOCKED 2026-06-09) ────────────────────
// The instrument lives in OUR universe: central BH = Sgr A*, the particle field
// IS the real nuclear star cluster orbiting it. Every value measured.
constexpr double GC_DISTANCE_M    = 2.55e20;  // ~8.3 kpc / 26,700 ly to galactic center (GRAVITY)
constexpr double NSC_MASS_MSUN    = 3.0e7;    // nuclear star cluster (3±1.5)×10⁷ M☉ — the particle field
constexpr double NSC_RADIUS_PC    = 4.0;      // half-light radius 3–5 pc
constexpr double NSC_STARS        = 1.0e7;    // ~10⁷ stars (6000+ proper motions measured within 1 pc)
constexpr double MW_STELLAR_MASS  = 5.0e10;   // Milky Way total stellar mass ~5×10¹⁰ M☉ (±10%)
constexpr double MW_STAR_COUNT    = 2.0e11;   // 100–400 billion stars (M-dwarf census = the uncertainty)
// Reference calibration orbit — S2, the most-measured star around Sgr A* (the real GR test):
constexpr double S2_PERIOD_YR     = 16.0518;  // orbital period [yr]
constexpr double S2_PERICENTER_AU = 120.0;    // closest approach [AU] (17 light-hours)
constexpr double S2_VMAX_FRAC_C   = 0.027;    // ~2.7% c at pericenter — validate our orbital speeds against this

} // namespace phys
} // namespace space
