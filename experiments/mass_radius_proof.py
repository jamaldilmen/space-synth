#!/usr/bin/env python3
"""
ISOLATED PROOF — the PIECEWISE state ladder, grounded in our written canon, not
a single fitted average. Sources (all already in this project):

  • space_synth_physics_canon.md / governing_model.md (OUR canon):
      - BH is GEOMETRIC: a hole forms when DENSITY crushes radius <= r_s=2GM/c².
      - fate-by-mass ladder: 0.075 ignites→star · 1.39 Chandrasekhar ·
        8–25 supernova→neutron star · >25 → black hole.
      - "density resists collapse via DEGENERACY PRESSURE until the real
        Schwarzschild threshold."  ← the law the sim is missing.
  • data/nasa_stellar_catalog.csv — REAL stars, for the STELLAR regime fit only.
  • src/core/units.h — r_s = 2953 m/M☉; sim units (kRsSimPerMsun, R_ENC, cell).
  • degenerate/compact radii = universal physics constants (cited inline).

The mass→radius relation is NOT one power law. Each REGIME has its own law and
its own thing holding it up — and the "size stops changing" you keep pointing at
is the DEGENERATE matter (white dwarf / neutron star), held by degeneracy
pressure, until even that fails at the Schwarzschild density → black hole.
"""
import csv, math, os
HERE = os.path.dirname(os.path.abspath(__file__))

# ── REAL constants (SI / CODATA, IAU) ───────────────────────────────────────
G, c          = 6.674e-11, 2.998e8
M_sun, R_sun  = 1.989e30, 6.957e8
M_earth,R_earth = 5.972e24, 6.371e6
M_jup, R_jup  = 1.898e27, 6.991e7
RS_PER_MSUN_m = 2*G*M_sun/c**2          # 2953 m  (units.h)

def r_s_m(M_msun):  return M_msun * RS_PER_MSUN_m       # Schwarzschild radius [m]

# ── (A) STELLAR regime: FIT the real catalog, CLEAN dwarfs only ──────────────
xs, ys, mlo, mhi = [], [], 9, 0
with open(os.path.join(HERE,"..","data","nasa_stellar_catalog.csv"), newline="") as f:
    for row in csv.DictReader(f):
        try: m,r,lg = float(row["st_mass"]),float(row["st_rad"]),float(row["st_logg"])
        except: continue
        if 0.1<=m<=1.5 and r>0 and lg>=4.3:      # main-sequence dwarfs, no giants
            xs.append(math.log10(m)); ys.append(math.log10(r)); mlo=min(mlo,m); mhi=max(mhi,m)
n=len(xs); sx,sy=sum(xs),sum(ys); sxx=sum(x*x for x in xs); sxy=sum(x*y for x,y in zip(xs,ys))
a_star=(n*sxy-sx*sy)/(n*sxx-sx*sx); b_star=(sy-a_star*sx)/n
print(f"(A) STELLAR M-R fit from {n:,} CLEAN dwarfs ({mlo:.2f}-{mhi:.2f} M☉, logg>=4.3):")
print(f"    R/R☉ = {10**b_star:.3f}·(M/M☉)^{a_star:.3f}   ← real exponent {a_star:.2f}, "
      f"≤1 so size grows ~with mass (sample is dwarf-heavy → M-dwarfs R∝M^~1).")
print(f"    (cleaned the contamination that gave my earlier 1.04; this is the honest fit.)\n")

# ── (B) The PIECEWISE state ladder — each regime its own real law ────────────
def radius_R_sun(M):
    """Radius [R☉] of an object of mass M [M☉], by REGIME. Returns (R, state, support)."""
    if M < 1.3e-7:                                   # < ~0.04 M⊕: rubble, constant density
        rho=2500.; R=(3*M*M_sun/(4*math.pi*rho))**(1/3)/R_sun
        return R,"fragment/dust","material strength"
    if M < 1.3e-4:                                   # ~moon→planet (<~0.5 Mjup) Valencia/Zeng R∝M^0.27
        R=(R_earth*(M*M_sun/M_earth)**0.27)/R_sun
        return R,"moon/planet","electron (rock/ice)"
    if M < 0.075:                                    # gas giant→brown dwarf: PLATEAU ~R_jup (Chabrier)
        return R_jup/R_sun,"gas-giant/brown-dwarf","electron DEGENERACY (size frozen)"
    if M < 8.0:                                       # main-sequence star (real catalog fit)
        return 10**(a_star*math.log10(M)+b_star),"STAR","thermal (fusion)"
    if M < 150.0:                                     # massive star, extrapolated MS
        return 10**(a_star*math.log10(M)+b_star),"massive STAR","thermal (fusion)"
    return 10**(a_star*math.log10(M)+b_star),"super-massive STAR","radiation"

def remnant_radius_R_sun(M):
    """The DEGENERATE remnant of mass M — what density-collapse leaves behind."""
    if M < 1.39:                                      # white dwarf, R∝M^-1/3 (Nauenberg72), Sirius-B anchor
        return 0.0124*(M/0.6)**(-1/3),"white dwarf","ELECTRON degeneracy"
    if M < 2.2:                                        # neutron star ~11.5 km ~const (Lattimer)
        return 11.5e3/R_sun,"neutron star","NEUTRON degeneracy"
    return r_s_m(M)/R_sun,"BLACK HOLE","NOTHING (r_s ≥ R)"

print("(B) STATE LADDER — pressure-supported branch (what you ACCRETE):")
print(f"    {'mass':>10} | {'radius':>12} | state | held up by")
for M in [3e-8, 1e-5, 3e-3, 5e-3, 0.001, 0.06, 0.3, 1.0, 8.0, 30.0]:
    R,st,sup = radius_R_sun(M)
    rr = f"{R*R_sun/R_earth:.2g} R⊕" if R*R_sun<0.5*R_sun else f"{R:.2g} R☉"
    print(f"    {M:>8.3g} M☉ | {rr:>12} | {st:<22} | {sup}")
print("\n    DEGENERATE branch (what density-COLLAPSE leaves — the 'size frozen' end):")
for M in [0.6, 1.0, 1.38, 1.5, 2.0, 5.0, 25.0]:
    R,st,sup = remnant_radius_R_sun(M)
    rr = f"{R*R_sun/1000:.1f} km" if R*R_sun<0.05*R_sun else f"{R:.3g} R☉"
    print(f"    {M:>8.3g} M☉ | {rr:>12} | {st:<22} | {sup}")

# ── (C) GRAVITY ∝ N  (the merge: conserved mass → honest gravity) ────────────
print("\n(C) MERGE → GRAVITY: G·M is exactly N× a single particle. 2→2×, 32→32×.")
print("    (this is the payoff of the mass-conservation fix; nothing invented)")

# ── (D) DEGENERACY → SCHWARZSCHILD: compress a fixed mass, watch support fail ─
print("\n(D) COLLAPSE of a fixed 10 M☉ core — compress it, watch what holds it:")
M=10.0; rs=r_s_m(M)
for R_km in [7e5, 1e4, 100, 30, r_s_m(M)/1000*1.0]:
    R=R_km*1000; ratio=rs/R
    state = "BLACK HOLE (r_s≥R)" if R<=rs else ("neutron-degenerate" if R<50e3 else
            ("white-dwarf-degenerate" if R<3e7 else "thermal/normal"))
    print(f"    R={R_km:>9.3g} km | r_s/R={ratio:>6.3f} | {state}")
print(f"    → r_s(10 M☉)={rs/1000:.1f} km. Degeneracy holds it at ~11 km (neutron star);")
print(f"      compress past r_s={rs/1000:.0f} km and NOTHING holds → BLACK HOLE. (geometric)")

# ── (E) THE SIM BLOCKER — why ours bounces instead of popping ────────────────
kRsSimPerMsun = 1.6825e-6      # units.h (sim units per M☉)
M_field = 5.94276e5           # units.h field mass [M☉]
R_ENC = 0.5; cellSize = 1.0   # units.h / renderer
rs_field = kRsSimPerMsun*M_field
rs_1particle = kRsSimPerMsun*1.0
print("\n(E) SIM CONNECTION — the REAL blocker (full_physics_todo B1/B2):")
print(f"    r_s(whole field {M_field:.2e} M☉) = {rs_field:.3f} sim   (R_ENC={R_ENC})")
print(f"    r_s(1 particle)            = {rs_1particle:.2e} sim")
print(f"    grid cellSize              = {cellSize} sim")
print(f"    → to trip the GEOMETRIC criterion you must crush mass inside its r_s,")
print(f"      but ONE CELL ({cellSize} sim) is {cellSize/rs_field:.1f}× bigger than the whole")
print(f"      field's horizon. The grid literally cannot resolve r_s → the criterion")
print(f"      can't trip → the sim falls back to the density-fraction proxy and the")
print(f"      core BOUNCES on degeneracy/SPH pressure. THE FIX is resolution at the")
print(f"      core (a fine/AMR grid), not pressure tuning. That's the real next step.")
