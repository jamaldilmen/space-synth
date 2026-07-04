# SPACE SYNTH — Claude Science brief

**Created:** 2026-07-01 (grounded against repo HEAD `992dd8f`)
**Purpose:** What Anthropic dropped today, an honest read of how science-rooted Space Synth already is, and what of the new tooling we can actually use.

---

## 1. What dropped today (2026-07-01)

**Claude Science** — an AI research workbench, positioned as "Claude Code for scientists."

Facts (from Anthropic + press, sourced below):
- **Not a new model.** Runs on existing models (Opus 4.8). No special biology access or gating. It's tooling + orchestration, not more raw capability.
- A **coordinating agent** with access to **60+ curated skills and connectors** pre-wired to scientific databases.
- Domains named: genomics, single-cell, proteomics, structural biology, cheminformatics — pharma/drug-discovery is the commercial target.
- Renders **scientific artifacts** (3D protein structures, genome tracks, chemistry drawings) and refines figures/manuscripts to publication.
- **Beta, included** in Claude Pro/Max/Team/Enterprise. Grant program: up to 50 projects, up to $30k, apps through 2026-07-15.

**The part that matters for us:** the same release ships a set of **physics/astro skills that are live in this environment right now** — they are the Space-Synth-relevant half of that "60+ skills" library:

| Skill | What it does | Space Synth use |
|---|---|---|
| `astro-ph.CO:astrophysics` | general astro workflows / FITS / cosmo sims | reference for our lifecycle + scale math |
| `astro-ph.CO:jax-bandflux` | supernova light-curve modeling — SALT3, TimeSeriesSource, real SN photometry | **supernova colour + brightness curve**, grounded not eyeballed |
| `astro-ph.CO:bayesian-anomaly-detection` | robust fits / outlier flagging | data cleaning if we ingest more catalogs |
| `gr-qc:gwosc` | LIGO/Virgo gravitational-wave events + strain data | **real BH merger parameters** (masses, final spin) for the held-SN→BH endstate |
| `core:arxiv` | fetch arXiv source/LaTeX by ID/topic | pull the exact SPH papers we already cite (StarSmasher, artificial-viscosity) |
| `core:ads` | NASA ADS literature + citations | source stellar/BH physics claims properly |
| `core:hepdata` / `core:inspire` | HEP data + particle-physics literature | **QGP / near-c collision thresholds** (the ~2×10¹² K plasma regime) |
| `core:zenodo` | datasets with DOIs | more real stellar/SN datasets on disk |
| `core:anesthetic` | posterior/corner-plot viz | analysis-side, low priority |

This is why the release is directly relevant: Space Synth's physics domain (stellar collisions, supernovae, black holes, plasma) is **exactly** one of the domains Claude Science just wired up with real databases and skills.

---

## 2. How rooted in science is Space Synth already? (honest read)

Space Synth is not a shader that "looks like" space. The current architecture is genuinely physics-derived. Verified against the repo/memory:

**Already grounded (real units, sourced):**
- **Unit anchor is a real black hole.** Sim→SI locked off M87\* / Sgr A\* (EHT-imaged, 4.3×10⁶–6.5×10⁹ M☉). 1 sim velocity = c exactly (`spacetime.h`). Length/time/gravity all map to SI.
- **Black hole is geometric, not a mass cutoff.** Collapse when radius ≤ r_s = 2GM/c² — the physically correct rule, matching the Universe Sandbox 2 decompile.
- **Render uses the real Schwarzschild factor** √(1 − r_s/r) for the per-radius spin-spiral winding. Not decorative — it's the time-dilation term.
- **Stellar colour/brightness from a real catalog.** 27,184 NASA Exoplanet-Archive stars on disk; mass→T→L→RGB via blackbody + Stefan-Boltzmann. L∝M^3.5. Real IMF sampling.
- **PM gravity is real** (Poisson −∇Φ solve), and the multi-session blowup was traced to a real numerical cause (variable-timestep energy pump), not fudged away.
- **The reaction engine is being built on the actual astrophysics standard: SPH** (StarSmasher-class), with EOS pressure, artificial viscosity as the shock-capture, and Rankine-Hugoniot jump conditions. Merge-vs-disrupt is designed to **emerge** from v_rel/v_esc, not be scripted.

**Honest gaps (where "rooted in science" is still aspirational):**
- SPH is at **slice 1 of ~7** — density is proven/tiled (120fps @ 5–7M), but pressure, viscosity/shock, and the emergent merge/disrupt outcomes are not built yet. Today the collision path is still crude merge-on-contact + a Coulomb stand-in.
- **Temperature → state** is derived (virial + classifier), but **shock heating** (Rankine-Hugoniot ΔT above virial) and **state→render** (plasma = synchrotron blue, not the current orange) are not wired.
- **Composition / lifecycle** (burning-stage scalar, NSE at SN energy) is planned, not present.
- BH lensing render is mid-rebuild (geodesic deflection LUT), old 2D-circle raytracer deleted.

**Verdict:** the *foundations* are real physics with real units and real anchors — well above "space-themed visualizer." The *reaction/lifecycle layer* that turns those foundations into emergent behavior is genuinely under construction. So: rooted, but the roots are deeper than the trunk right now.

---

## 3. What we could actually use from Claude Science

Ranked by leverage, mapped to the current sprint. Nothing here changes the engine's design — it feeds it grounded numbers instead of guesses.

**High leverage (use now, feeds the active SPH sprint):**
1. **`core:arxiv` → pull the SPH papers we already cite** (StarSmasher arXiv 2602.10191 / astro-ph/0112284; artificial viscosity 2407.10176, 2202.11084; core-collapse EOS+NSE 1707.06410). Get the *exact* artificial-viscosity form and EOS constants from source instead of paraphrase → slices 2–3 (pressure force, shock heating) built from the real equations. **This directly de-risks the keystone sprint.**
2. **`astro-ph.CO:jax-bandflux` → supernova colour/brightness, grounded.** Backlog item B ("supernova colour — more than orange→white") is currently eyeballed. SALT3/TimeSeriesSource give real SN spectral-energy-distribution over time → a physically honest colour+luminosity curve for the nova flash and decay, matching how the T⁴ cooling already decays it.
3. **`core:hepdata` / `core:inspire` → the near-c / QGP thresholds.** The governing model claims ~2×10¹² K (~150 MeV) quark-gluon plasma at relativistic collisions (RHIC/LHC). Pull the real cross-over temperature and energy so the high-v disrupt path (slice 3) caps at true physics instead of NaN.

**Medium leverage (endstate + validation):**
4. **`gr-qc:gwosc` → real BH merger parameters** for priority-3 (held-SN → supermassive BH). Final mass/spin from actual LIGO events give a real target for what a merger produces, if we ever want the collapse endstate to hit measured numbers.
5. **`core:ads` → source every physics claim** in the canon/governing-model memories with a real citation + citation count. Cheap credibility pass; also catches anything stale.
6. **`core:zenodo` → more real stellar/remnant datasets** if we outgrow the single NASA catalog (e.g. a less planet-host-biased population for the IMF render).

**Low leverage / skip for now:**
- `anesthetic`, `bayesian-anomaly-detection` — analysis-side, no engine hook yet.
- The biology/pharma/protein/cheminformatics half of Claude Science — not our domain.

**One thing NOT to do:** don't treat Claude Science as a new engine or a reason to rewrite. It's a **data + literature source**. The design (SPH on the 128³ grid, emergent merge/disrupt, real-unit anchor) stands. This just replaces the remaining guessed constants with sourced ones — which is exactly the project's own thesis ("follow the science → insane results").

---

## 4. Suggested next concrete step (one change, verifiable)

Before writing slice 2 (EOS pressure + pressure force), use `core:arxiv` to pull StarSmasher + the artificial-viscosity papers and extract the **exact** pressure-force and Von Neumann–Richtmyer viscosity terms + γ / μ constants. Drop them into `docs/sph_reaction_engine_plan.md` §5 as the sourced reference, then implement slice 2 against those equations. Verifiable: a gas blob with u>0 reaches hydrostatic balance (holds finite size vs gravity) instead of point-collapsing.

---

## Sources
- [Anthropic — Claude Science, an AI workbench for scientists](https://www.anthropic.com/news/claude-science-ai-workbench)
- [Claude Science beta — product page](https://claude.com/product/claude-science)
- [MIT Technology Review — Claude Science is Anthropic's newest flagship product](https://www.technologyreview.com/2026/06/30/1139987/claude-science-is-anthropics-newest-flagship-product/)
- [CNBC — Anthropic launches AI drug discovery program, Claude Science](https://www.cnbc.com/2026/06/30/anthropic-launches-ai-drug-discovery-program-claude-science.html)
- [Dataconomy — Anthropic Launches Claude Science Workbench For Researchers](https://dataconomy.com/2026/07/01/anthropic-claude-science-ai-research-launch/)
- Internal: `docs/sph_reaction_engine_plan.md`, memories `space-synth-governing-model`, `space-synth-physics-canon`, `space_synth_reaction_engine_sprint`
