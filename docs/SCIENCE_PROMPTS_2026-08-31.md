# CLAUDE SCIENCE — PROJECT SETUP + THE PROMPT QUEUE
2026-08-31 14:25:53

> **His order 2026-08-31:** the Claude Science project is **`SPACE SYNTH X`**. It exists to source the
> science the simulator runs on — *"better data for star maps, black holes… the state of the art
> knowledge we need to advance our project and make it more efficient and NASA collab ready."*

## ⚠️ WHAT CLAUDE SCIENCE ACTUALLY IS — researched, not assumed
`[VERIFIED 2026-08-31 14:25:53]` The official product page describes it as **life sciences only** —
genomics, single-cell, proteomics, structural biology, cheminformatics. **It does not advertise
physics or astronomy.** What transfers to us, and it is the valuable part:
- **60+ scientific databases** + literature search. The astro/physics skills exist: **ADS, arXiv,
  INSPIRE-HEP, GWOSC, Zenodo**.
- **Reproducible artifacts** — figures, tables and notebooks carry the exact code, environment and
  conversation that produced them, so they can be defended months later.
- 🚨 **A background REVIEWER agent that flags incorrect citations, untraceable numbers, and figures
  that do not match their underlying code.** ⭐ **This is the feature to design prompts around.**

⭐ **So prompt it as a LITERATURE-AND-DERIVATION workbench, not an astro pipeline.** Ask for
relations, numbers and named sources — things the reviewer can actually check. Do not ask it to run
our simulation; it has no access to it.

---

## THE QUEUE — P0 first, then 1→3 by value for the show

| # | Prompt | Feeds | Lands by Sat? |
|---|---|---|---|
| **P0** | **What object are we actually simulating?** reference universe + IMF audit | the star map, and the regime every BH forms in | 📤 **SENT 2026-08-31 17:36:36** — full text in §P0 below |
| **P1** | **What a black hole should actually look like** | 🟣 **FABLE F1** — the empty renderer | ✅ **highest value for Saturday** |
| **P2** | **The three merger signatures** | 🟣 **FABLE F3** — his money shot | 🟡 maybe |
| **P3** | **Neighbour finding in production codes** | 🟣 **FABLE F2** — *"how does NASA do this"* | ⛔ no — long game, run it anyway |

🚨 **P0 first and alone.** Its output is the input to P1 and P2: if our universe is unphysical,
Fable must know that **before** designing a renderer for it.

---

## THE NUMBERS THESE PROMPTS CARRY — all verified from source 2026-08-31 14:25:53
**🚨 RE-VERIFIED AGAINST `src/` 2026-08-31 15:32:35 — 4 rows were WRONG and had already broken P1–P3.**
The originals were read from COMMENTS and a UI default, not from the live code path. Every row below
was re-grepped in `src/` at that timestamp. Corrections: ~~particles 2e6→1e7~~ **RETRACTED, it is 2e6** · ε 0.031→0.0625 fine /
1.0 coarse · the softening verdict is position-conditional · `spacetime.h:52`→`:95`.

| quantity | value | where |
|---|---|---|
| particles | **2,000,000** — the ORIGINAL row was right | `app_state.h:13` → `main.cpp:2519` → `renderer.mm:4736` |
| ⛔ my 10,000,000 correction was **WRONG, retracted 2026-08-31 16:39:33** | 10M are spawned and uploaded (`main.cpp:177`), then `setActiveParticleCount(app.uiParticleCount)` clamps the live count to **2M every frame** (`main.cpp:2519`). Only ids `0..2e6-1` gravitate — an id PREFIX, not a stride. 🚨 I claimed that setter had zero callers; **my grep pattern (`setParticleCount\|setActiveCount`) could not match `setActiveParticleCount`.** Refuted by OPUS's measurement `[GRAV] live=1993624 Mlive=594276`. | `renderer.mm:3714` |
| ⭐ and this is why the anchor holds | Σ`imf::massOfId` over ids 0..2e6 = **5.94268e5** vs `kMfieldMsun` 5.94276e5 — 1.3e-5. Over ids 0..10e6 = 2.966e6. The PREFIX sum matching to 5 digits is the proof the subsample is a prefix. | `particles.cpp:241-248` |
| field mass | **5.94276e5 M☉** (mean **0.297 M☉**/particle) | `spacetime.h:36` |
| 1 sim length | **1.7552e9 m** = r_s(field) = 2·r_g(field) ≈ 2.52 R☉ ≈ 0.0117 AU | `spacetime.h:12` |
| 1 sim time | **≈ 5.85 s** = L/c | `spacetime.h:14` |
| units | **G = c = 1**, `kCSim ≡ 1` by static_assert; r_s = 2M | `spacetime.h:64,95,98` |
| b_c | **2.5980762 r_s** = 3√3·M, rel err 8.2e-15 | `tools/bc_validate.cpp` |
| horizon / photon sphere / ISCO | **0.1717 / 0.2576 / 0.5151** sim. 🚨 **In softening lengths this is POSITION-conditional, not a single verdict:** fine ε=0.0625 → **2.75 / 4.12 / 8.24** (marginally resolved); coarse ε=1.0 → **0.17 / 0.26 / 0.52** (all inside one, the board's claim, true only outside the AMR box). | `BOARD_BLACKHOLE` §V4 |
| formed-hole mass | **102,144 M☉** = 0.17188 × field. 0.1717 is an observed **mass fraction** (Sgr A*/MW NSC), which doubles as the horizon in sim units because 1 sim = r_s(M_field). | `particles.metal:277,:289` |
| grid — coarse | **128³** over ±64 → cellSize **1.0** sim = r_s(M_field) exactly | `renderer.mm:2255-2258` |
| grid — AMR fine | **128³** over ±`kAmrFineExtent`=4.0 → cellSize **0.0625** sim. **DEFAULT ON**; replaces coarse gravity inside the box. | `renderer.mm:132,:2137,:2824` |
| Plummer ε | **≈ one cell** — so ε=1.0 coarse, ε=0.0625 fine. ⛔ `particles.metal:2211` still says 0.031: **DECAYED**, invalidated by the DAM test 2026-07-13 (`renderer.mm:130`). | `particles.metal:1845` |
| field geometry | 75% disk edge **18.0** · 10% nucleus Plummer a=1 trunc **3.0** · 15% halo Plummer a=15 trunc **60.0**. R_half **11.702** sim, R90 **18.43**, R99 **44.72**. | `particles.cpp:50,104-107,120,151,176,190` |
| neighbour scan | **3×3×3 = 27 cells, ≤32 samples per cell** | `spatial_hash.metal:589` |
| 🚨 densest cell | **334,576** particles vs a cap of 32 | `bhPeakCount` |
| BH seed / rebirth mass | **50.0 / 0.01 M☉** | `particles.metal:218,:427` |
| Ω law (Doppler) | `1/(r^1.5 + a)`, **a = 0.5**, one fixed axis | `render.metal:308,:1409` |

⛔ **If any of these change in code, they are WRONG here too.** Re-verify before re-prompting.

---

## HOW THE OUTPUT COMES BACK — this is the part that goes wrong

🚨 **A Claude Science answer is a CLAIM until it is cited and checked. It is not a result.**
The reviewer flags untraceable numbers *inside* Claude Science; **nothing checks it on the way into
our repo.** So:

1. **Science output lands as a DOC with sources, never pasted into code.** File it as
   `docs/SCIENCE_2026-XX-XX_<topic>.md` with the primary references inline.
2. **Every number that reaches `src/` needs a citation next to it**, exactly like every other claim
   in this repo. His law: code-verified when written.
3. ⛔ **Never fit anything to our own simulation output and call it physics.** Use published
   relations. (Precedent: `reference_stellar_render_sources` — Eker 2018 MLR, Lupton 2004 asinh,
   **never fit the NASA CSV**.)
4. **If the literature does not settle something, that is a RESULT — record it as one.** A clean
   "unknown" is worth more than a plausible invention, and it is what NASA-collab-ready means.
5. **Contradictions with our board are findings, not errors to smooth over.** If the science says our
   reference universe is unphysical, that goes on the board as a row, loudly.
6. 🚨 **A SCIENCE STAMP DATES THE REASONING, NOT THE CODE.** Added 2026-08-31 16:50:29 after it bit us.
   The track reasons from `src/` excerpts **pasted at some earlier time**, then stamps the conclusion
   with the wall clock of the *conclusion*. Those are two different events, and nothing makes the gap
   visible. On 2026-08-31 it published **`✅ SETTLED 16:30`** on the `F_BH_CLUSTER` cap — a mechanism
   Jamal had ordered **deleted at 16:10:25**. Not decay: **false at the moment of stamping**, wearing
   our strongest confidence marker, with a timestamp that looked NEWER than the truth.
   ⭐ **So every science claim carries the provenance of its SOURCE, not just its conclusion:** the
   commit sha, or the time the excerpt was pasted. Format: `[reasoned from src @ <sha or paste-time>,
   concluded <time>]`. ⛔ **The line numbers are not a safety net** — `particles.metal:277` still
   resolves, it just no longer contains `F_BH_CLUSTER`, so `verify_citations.py` cannot flag it. A
   DEAD ANCHOR that still resolves is invisible to every automated check we have.
   🚨 **This gets WORSE, not better, when the track reads the repo directly** — its verdicts will look
   repo-grounded while still being a snapshot. Found by SONNET, `docs/SWEEP_2026-08-31_SONNET.md` §4.

---

## §P0 — THE PROMPT AS SENT, 2026-08-31 17:36:36

⭐ **It was never written until now.** The queue row existed from 14:25:53; the prompt did not, which
is the whole reason P0 "was not run". Sent on his order 2026-08-31. Every number in it is **measured
or derived from the spawn code**, not read from a comment — the failure that cost P1–P3 three
correction rounds today.

Provenance carried in the prompt itself: *reasoned from `src/` as of 2026-08-31 17:00, live tree,
after the outcome-cap removal.*

**Inputs it carries, and where each came from:**

| input | value | how it is known |
|---|---|---|
| live particles | **2,000,000** | `app_state.h:13` → `main.cpp:2519` → `renderer.mm:4736`; 10M spawned, ids `0..2e6-1` gravitate |
| field mass | **594,276 M☉** | 🚨 **MEASURED on the GPU**, `[GRAV] Mlive=594276` — not read |
| per particle | Kroupa, `M^-2.3`, [0.08, 50] M☉, mean 0.297 | `imf.h:9` |
| geometry | 75% disc edge 18.0 · 10% nucleus Plummer a=1 trunc 3.0 · 15% halo Plummer a=15 trunc 60.0 | `particles.cpp:50,104-107,120,151,176,190` |
| R_half / R90 / R99 / outer | **11.702 / 18.43 / 44.72 / 60.0** sim | my Monte-Carlo of the exact sampler |
| Σ(<R_half) | **2.14e17 M☉/pc²** | my arithmetic |
| v_circ / v_esc at R_half | **0.1462c / 0.2721c** | my arithmetic, full potential |

**The six questions:** ① what object is this, if any — confirm the 11.9-dex excess over the
Hopkins+2010 maximum observed stellar surface density at the corrected numbers · ② the **IMF audit**:
is Kroupa over [0.08, 50] defensible for whatever this is, given the star map and the black holes are
drawn from the SAME population · ③ **is it relativistic** — `v_esc = 0.27c` under a Newtonian
integrator, a systematic `(v/c)² = 2.1%`; push again on relativistic-cluster literature and record a
clean "none" if that is the answer · ④ test the **direct-collapse progenitor** frame, and if it holds,
say what that object's profile, velocity field and mass function should be · ⑤ ⭐ **if we wanted one
coherent object, what should the reference universe BE** — the target, not a critique · ⑥ what is not
settled.

🚨 **Question ⑤ is the one with teeth: a different answer means changing `particles.cpp`, which every
other window builds on top of.** Worth knowing before Fable finishes designing a renderer for the
current object.

⛔ **P4 (how light actually bends, and how we prove it) is DRAFTED AND HELD** — his ruling: *"questions
should name the real code"*, and the live bending path is unconfirmed after the 2026-08-27 renderer
deletions. Waiting on OPUS for it at `file:line`. Do not send P4 before that lands.
