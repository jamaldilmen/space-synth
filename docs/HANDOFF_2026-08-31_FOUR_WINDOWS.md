# HANDOFF — THREE WINDOWS, FIVE DAYS · 2026-08-31 12:43:01

> **His order 2026-08-31 12:43:01:** *"i will open three windows now. fable, opus and sonnet and name them as such.
> … your job in the handoff as the brain window is to dictate to the rest what they need to do in a
> way that makes the most efficient sense for the model used respectively."*

## 0. FOUR WINDOWS — corrected 2026-08-31 12:47:17

⛔ **My first version of this file said "three windows". WRONG — there are FOUR tabs, and the BRAIN
window RUNS OPUS TOO.** His correction: *"this window (BRAIN) is opus too yeah butt look at the
windows in screenshot thats how i meant it."*

| tab | model | job |
|---|---|---|
| **BRAIN** | **Opus** | Plans, handoffs, folds session rows into the boards. Gets cleared often — **never park long work here.** |
| **FABLE** | Fable 5 | BH + the genuinely hard. Three tasks only. |
| **OPUS** | Opus | Everything that changes code. **Holds the build token.** |
| **SONNET** | Sonnet | Mechanical, report-only. Never edits a load-bearing doc. |

⭐ **BRAIN and OPUS are the same model.** The split is by ROLE, not capability: BRAIN thinks and
records, OPUS builds and measures. When work is Opus-class but long-running it goes to **OPUS**,
because BRAIN's context gets cleared.

---

## ⚡ STEP 1 — BEFORE ANYTHING ELSE

🔌 **HE IS WIRING CLAUDE CODE INTO CLAUDE SCIENCE OVER MCP.** His order 2026-08-31 14:26:24:
*"imma add u to mcp for claude science first step in handoff."*

**Until that connection is live, the science track is manual copy-paste** — he runs the prompts in
the Claude Science app and pastes results back. **Once it is live, verify it before trusting it:**
check the `/mcp` panel or list the MCP resources, and confirm the server actually responds. ⛔ **Do
not assume a connector is connected because it is configured** — this session already has four that
are not (`notebooklm-mcp` failed to spawn; Google Calendar, Drive and Hugging Face are unauthorised).
**A failed connector is a connection failure, not a missing capability — say so and let him fix it.**

⭐ **What it changes when it lands:** windows can pull Claude Science artifacts directly instead of
him ferrying text. **It does not change the review rule** — see §5, science output is a claim until
it is cited and checked.

---

🚨 **COLOGNE IS 2026-09-05 (a SATURDAY). FIVE WORKING DAYS: Aug 31 · Sep 1 · 2 · 3 · 4.**
⏰ **The +50% weekly Claude Code boost ends TODAY (2026-08-31).** Extended three times, never made
permanent; if it lapses, Sep 1–4 run at ~⅓ less weekly capacity. **Front-load today.**

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` @ `true-physics`, HEAD `b7e6c19`.
**The tree is DIRTY and that is expected** — 5 modified docs + 5 untracked (see §5). **Nobody commits.**

---

## 1. THE RULES THAT DO NOT BEND — all four windows

1. 🪟 **ONE LIVE APP. ONE BUILD TOKEN. → OPUS HOLDS IT.**
   **Only the OPUS window may run `bash package_macos.sh`, launch `SpaceSynth.app`, or run a
   measurement.** Fable and Sonnet **never** build, never launch, never measure. A worktree does not
   buy a second bundle. ⚖️ *This is my call, not his — overrule it if you want the token elsewhere.*
2. 🧾 **COMMIT ONLY ON HIS EXPLICIT ORDER.** `/handoff` counts as that order; nothing else does.
   🚨 **The compiled binary is TRACKED in git** and is built from the WHOLE tree — committing it beside
   one source file silently ships every other dirty change inside the executable, invisible in the diff.
3. 🚫 **NEVER `make`.** `bash package_macos.sh` only. *"The change did nothing"* → suspect a **STALE
   BINARY** first, always.
4. 🖥️ **Launch fullscreen** (`--env SS_FULLSCREEN=1`) whenever he will look at it.
5. 💬 **A COMMENT IS NOT A MECHANISM. A NAME IS NOT A MECHANISM.** 12 sightings. Do not add one.
6. 📄 **HIS LAW, 2026-08-31 12:43:01: every doc claim must be code-verified when written.**
   Run `python3 tools/verify_citations.py` before you hand anything back. **DEAD is fatal.**
7. ⛔ **Do not reshape `PhysicsUniforms` or `PostFXUniforms`.** Both are hand-synced across C++/MSL;
   `PhysicsUniforms` has **ZERO static_asserts** (~40 fields — add one scalar and ~38 shift, and it
   still compiles and still runs). `PostFXUniforms` is already 4 bytes out of sync.

### 1a. FILE OWNERSHIP — disjoint on purpose, so three windows never collide

⛔ **REVISED 2026-08-31 12:47:17 — the first split gave Sonnet the boards. That is now WRONG**, because the
citation sweep moved to OPUS (§3, O0), and whoever does that owns the boards.

| window | owns (may edit) | must NOT edit |
|---|---|---|
| **BRAIN** | `docs/HANDOFF_*.md`, `docs/PLAN_*.md`, memory, **and folding SESSION ROWS into the boards** | `src/**` |
| **FABLE** | `docs/DESIGN_BH_2026-08-31_*.md` (new files it creates) | `src/**`, all boards, `TODO.md` |
| **OPUS** | `src/**`, `tools/**`, `docs/STATUS.md`, **and board CORRECTIONS from the O0 citation sweep** | `docs/HANDOFF_*.md` |
| **SONNET** | **ONLY new files it creates: `docs/SWEEP_2026-08-31_*.md`** | 🚨 **every pre-existing doc, and `src/**`** |

🚨 **SONNET PROPOSES, IT DOES NOT APPLY.** It writes findings into its own `SWEEP_*.md` with the exact
`file:line` and the exact replacement text; **OPUS or BRAIN applies them.** That removes every
collision, and it matches the tier: verifying a claim against code is Opus-class, transcribing is not.

⛔ **BOARD SPLIT RESOLVED 2026-08-31 16:08:27, his ruling: "brain folds session rows, opus owns the sweep corrections."** The table above said OPUS owned *all three boards* while this line said BRAIN folds the rows — a straight contradiction inside one section, live since 12:47:17. **The split is by KIND of edit, not by file:**

- **BRAIN** writes NEW session sections (§Y and the like) and cross-links them. Folding happens as the session runs, not only at handoff time.
- **OPUS** rewrites EXISTING rows when the O0 citation sweep finds a `file:line` that has decayed or a claim that is false.

⭐ Neither waits on the other: a new section never edits an old row, and a sweep correction never adds a section.

### 1b. MEMORY — the one lane a worker window may enter, agreed 2026-08-31 16:53:38

⚠️ **A REAL CONFLICT, settled rather than papered over.** Every window's own operating instructions tell it
to maintain the persistent memory at `~/.claude/projects/-Users-airy/memory/`. This handoff assigns memory
to BRAIN. Neither can override the other — BRAIN cannot switch off a worker's instructions, and a worker
should not curate in parallel. It already produced ONE duplicate: his mutual-exclusion law was written twice,
16:39 by OPUS and 16:51 by BRAIN, under two different filenames. Merged into
`space_synth_bh_chladni_mutual_exclusion_2026-08-31.md`.

**The agreement (OPUS proposed, BRAIN accepted — HIS to overrule):**

1. A worker window writes a memory **ONLY for a durable RULING OF HIS that would otherwise die with that
   window.** Not session rows, not project state, not anything derivable from the boards.
2. It **names the filename to BRAIN in the same turn it writes**, so BRAIN merges or overrules immediately
   instead of finding it later.
3. Everything else stays BRAIN's, untouched.

⭐ **The thing this protects:** a verdict of his that exists only in a worker's transcript dies when that
window closes. That is worse than a duplicate. ⛔ **Going silent on his rulings is not an option for any
window** — if BRAIN wants it stricter, the fallback is the worker relaying the ruling as TEXT for BRAIN to
file, never dropping it.

🚨 **Search widely before writing one.** Both halves of the duplicate above were missed by a too-narrow
`grep`/`ls` pattern — the same failure that produced the retracted 5× field-mass claim the same afternoon.
**Grep the description line and the `[[wikilinks]]`, not just a guessed filename.**
If you need to record something outside your lane, write it in your own file and say so.

---

## 2. 🟣 FABLE WINDOW — BH and the genuinely hard. Nothing else.

> 🔬 **SCIENCE IS BEING SOURCED FOR YOU IN PARALLEL** (§5). **P1** answers what a black hole should
> actually look like → **F1**. **P2** the three merger signatures → **F3**. **P3** production
> neighbour finding → **F2**. ⏳ **Do not wait on them** — start from what is verified below. When a
> science artifact lands, it arrives as a cited doc; **treat it as a claim to check, not a result.**

**Effort: `xhigh`. Thinking is always on — do not configure it.**
⭐ **Prompting note, and it matters: do NOT over-prescribe to this window.** Give it the goal, the
constraints and the verified facts, then let it work. Step-by-step instructions written for older
models measurably *reduce* Fable's output quality. The three briefs below are deliberately stated as
problems, not procedures.

⚖️ **Fable is capped at 50% of weekly limits on Max, burns limits FASTER than other models, and has
NO automatic fallback.** When the slice is gone he switches by hand or buys credits. **Three tasks
only. Do not let it drift onto doc work, sweeps, or babysitting a build.**

### F1 — THE BLACK HOLE HAS NO RENDERER
**Verified 2026-08-31 12:43:01:** both BH renderers were **deleted** 2026-08-27 (`00741f2`, 852 deletions).
`bhmarch_fragment` now exists **only in comments** (`render.metal:908`, `:1047`, `:3031`, `:3079`,
`renderer.mm:4132`). What survives: sprites, shadow-by-absence at `b_c`, the depth-only body
(`bhbody_fragment` at `render.metal:3015`, `bc = 2.5980762f * rsW` at `:3028`), and the T2 dilation shear.
🚨 **Nothing produces the photon ring, the far-side arch, or the underside arc.**

**His direction, standing:** per-pixel backward geodesics that **TERMINATE ON THE REAL PARTICLES** —
never a grid fog integral. **Read `docs/blackhole-library/` first.**
⛔ **Hard limit to design against, not around:** horizon 0.1717, photon sphere 0.2576 and ISCO 0.5151
**all fit inside ONE softening length of 1.0.** A 1:1 Kerr hole has no resolution to live in yet.
⛔ **NO SECOND LAYER** means one ENTITY, not one representation. It does **not** ban a per-pixel
integrator for the collapsed state. It does ban a bolted-on second object.

### F2 — "HOW DOES NASA DO THIS?" — his question, carried forward
**Verified 2026-08-31 12:43:01:** `spatial_hash.metal:352` `if (currentOffset < 32)`, first-come atomic; and
`min(cellCounts[...], 32u)` at `:391, :669, :714, :823, :920` plus `particles.metal:3654, :3711, :4102`.
Densest cell logs **334,576**. **The physics sees 0.01% of the core, resampled by GPU scheduling order.**
`Mmax` forks **11.1×** run-to-run at cap 32; **3.4×** at cap 64, where **4× as many seeds form.**
🚨 **This invalidates every single-run comparison in the project's history, mine included.**
**The question is how real N-body/SPH codes do neighbour finding without a fixed per-cell sample.**
⚖️ This will not be solved in five days and **does not block the show.** It is the long game.

### F3 — A MERGER HAS NO VISUAL FACE
His words: *"a merger doesnt have a visual face yet. its just millions of dots"*, *"it has 0 aura"*.
⭐ **He asked the right question first and it is still the row: what does a stellar merger ACTUALLY
look like, science-wise?** Three physically different events, currently drawn identically:
① star↔star → luminous red nova (V1309 Sco, V838 Mon) — **red, slow, expanding; not a white flash**
② star↔BH → tidal disruption, t^(−5/3) fallback — **the KE is already booked in `seedAccum` word 5 and
nothing draws it** ③ BH↔BH → **no light at all**, the visual is the field ringdown.
🚨 **BH–BH is his money shot** (*"I want the money shot to be two black holes merging"*) and is **not started**.
🚨 **Separate, undiagnosed:** the merged body renders as a **squarish slab with a hard straight edge**.
A straight edge in a particle cloud is a BOX — **suspect the AMR fine-grid box before the sprite**
(precedent: `r≈2.66 DAM was the AMR box face`).

---

## 3. 🟠 OPUS WINDOW — everything that changes code. **Holds the build token.**

**Effort: `xhigh`. Full task spec up front. ONE verifiable change → confirm it landed → say exactly
what to look at → STOP.** Never batch, never stack on unverified work.

### O0 — 🚨 THE 129 ANCHOR-MISSES. **His order 2026-08-31 12:47:17: OPUS, not Sonnet.**
*"if something is in the way of the entire thing working, the 117 anchor misses, not sonnet should
take care of it but opus."* ⭐ **He is right, and it corrects my own split.** I had already written
that every window must re-grep before trusting a board citation — which makes this a **correctness
gate on all four windows**, not tidying. **Tier follows consequence, not effort.**

⏱️ **DO THIS NOW, WHILE O2 IS BLOCKED ON THE CHARGER.** It is the only load-bearing work that needs no
hardware. **The moment the charger lands, drop it and go O2 → O1.** It resumes cleanly.

`python3 tools/verify_citations.py` → **402 citations, 0 DEAD, 129 anchor-miss.**
An anchor-miss = the line still resolves, but the code the row NAMES is not within ±18 lines.
**6/6 hand-checked were genuinely stale — treat the rate as real, not as false positives.**
**Per row:** `grep -n "<the symbol the row names>" <file>` → correct the number → tag ⛔ + date.
**If the code is GONE, mark the row HISTORY — never invent a replacement line.**
Re-run the tool after every batch; **DEAD must stay 0.**
🚨 **Cause, so you recognise the pattern:** `bhmarch_fragment` (~410 lines) was deleted 2026-08-27 and
the clock commits shifted `main.cpp`/`renderer.mm`. Everything below a deletion still *resolves* —
which is exactly why nothing flagged it.

### O1 — 🚨 THREE OFF-AXIS FRUSTUMS. The only item that can break the show.
**The math is already proven — do not re-derive it.** `tools/frustum_validate.cpp`, **24/24 pass**:
- The off-axis matrix **reduces to the shipped `perspectiveMatrix` at delta `0.000e+00`** for a
  symmetric window. That is what proves the convention: **column-major, column-vector, LEFT-handed,
  +Z forward, `[0,1]` depth.** A right-handed OpenGL formula would pass the corner tests and fail here.
- **The seam holds:** the shared corner edge maps to ±1 in both frustums **and `ndc.y` agrees to 1e-9**
  across walls at 7.375 m vs 5.005 m eye distance. That agreement is the real proof, not the ±1.
- Coverage is **291.67°** (computed; front 68.33 + sides 111.67×2, closing to 360 with the beamer-less
  back wall). ⛔ The "~270°" on the board and in memory was an estimate and understated it by 22°.

**Room, measured** (he walked it 2026-08-24; Polycam 256,532 verts): **sides 14.75 × 3.50 m ×2, front
10.01 × 3.50 m**, 138.25 m². ⭐ **The SIDES are the wide walls.** Venue feed: front **5340×1680**,
sides **7152×1680** each ⇒ **19,644×1680 = 33.00 MP**.
**Today:** ONE camera, ONE projection (`main.cpp:934` ortho / `:937` perspective), ONE Syphon server
`"Main"` (`renderer.mm:471`). ⭐ The eye is a **placeholder at room centre, 1.60 m** — the sweet spot
is **his** call and he has not made it.
⛔ **Do not render one wide image and slice it.** Past 180° a flat perspective needs unbounded width.

### O2 — THE COST MEASUREMENT. Do this BEFORE O1.
`tools/measure_frustum_cost.sh`. **It refuses to run on battery — that gate is deliberate, do not
remove it.** Uses the EXISTING `SS_NO_STARPASS` gate (`renderer.mm:4206`), which `renderer.mm:4199`
says was built for exactly this: **(Render+PostFX with) − (without) = the whole star pass, vertex +
raster.** Physics runs once regardless, so three frustums ≈ base + 3× star pass.
⚠️ **Fill is 33.00 MP — 5.56× his 5.94 MP panel, and 2.39× MORE than the 13.8 MP the old plan assumed.**
🚨 **Discipline:** interleave arms, alternate pair order, ≥4 runs, discard warm-up, trust the average.
A single-run result here is worth nothing. **If it does not fit, the honest fallback is fewer particles
on the side walls — say so, do not quietly downscale resolution.**

### O3 — OFF SYPHON (his: *"syphon is ass"*). **Last, not first.**
`docs/DESIGN_2026-08-31_HOW_THE_INDUSTRY_RENDERS_THIS.md` has the research.
⛔ **RenderStream is Windows-only** (64-bit DLL) — dead for a macOS Metal app. Route is **NDI** or
**SDI via Blackmagic DeckLink/UltraStudio** over Thunderbolt.
⭐ **A cable change fixes nothing while we cannot produce three correct images. O1 first.**

### O4–O6 — only if O1 lands early
**O4** TRUEFX: T4 ladder LPF = opacity; T1 reverb = fluidity (visual half exists as `trailDecay`, audio
half does not). 🚨 **A TRUEFX is ONE effect with TWO OUTPUTS** — an audio block and a shader block
sharing a knob is not one, and he will reject it.
**O5** Camera rides A→B. ✅ **Smoothness is DONE** (`camera.h:154` `setCinematic`, critical damping `:162`;
his verdict *"i love the feel the snappiness"*). Only the automated ride is missing. ⛔ **NO BPM sync** — he rejected it.
**O6** Clock residuals: 0.69% sequencer drift; `u.frameCounter` seeds the RNG per FRAME (off the shipped path).

---

## 4. 🟢 SONNET WINDOW — mechanical, high-volume, runs continuously

**Effort: `medium`. Explicit checklists. Verify each item, do not reason past the checklist.**
⭐ **This lane exists because he said it: *"id just let sonnet agents at least run 24/7."***
**None of these needs the app, the build token, or him. Never stop to wait.**

⛔ **SONNET MUST NEVER:** build · launch the app · run a measurement · edit `src/**` · edit
`PhysicsUniforms`/`PostFXUniforms` · commit.

> ⛔ **S1 (the citation sweep) MOVED TO OPUS as O0 on his order 2026-08-31 12:47:17.** It gates correctness for
> every window, so it is not basic-tier work. **Do not start it here.**

### S1 — *(moved to OPUS §3 O0 — nothing to do in this window)*

### S2 — STALE-ROW SWEEP (claims that outlived the code)
**Two already found — REPORT the exact replacement text, do not apply it:**
- **U1** says E5 is *"built, uncommitted and UNSEEN"* — `git status --short src/ui/` is **CLEAN**, so
  the "uncommitted" half is **FALSE**. `src/ui/` holds only `ui_theme.h`, `window.h`, `window.mm`.
- **U5** says indigo hover = an ORPHAN bundle — but indigo is in the **LIVE** theme
  (`ui_theme.h:48`, `ImVec4(0.40f, 0.50f, 1.00f, 1.00f)`, drives SliderGrab/ButtonActive). **Settle or delete.**

### S3 — THE 8 DEAD UI PANELS
All `if (false && …)`, all stamped *"removed 2026-06-26"*: `main.cpp:1427` PRESETS · `:1866` NEW
SCIENCE · `:1876` INDUSTRY DEBUGGING · `:1929` VJ MODE · `:2031` DYNAMICS · `:2157` VJ FX · `:2206`
PHYSICS STATS · `:2282` DEBUG GPU. **Inventory them into your `SWEEP_*.md` and put ONE decision each to him. Do not flip any, do not touch `main.cpp`.**
🚨 VJ MODE matters: the FFT + onset analysis runs every frame and is **thrown away** — a VJ instrument
that cannot take audio in.

### S4 — BOARD HYGIENE
Countdown, stamps, superseded numbers — **you FIND and REPORT, OPUS applies.** **Three were wrong today alone** — 160 m² → **138.25**,
~270° → **291.67**, 13.8 MP → **33.00 MP**. **Assume there are more and hunt them.**

---

## 5. 🔬 THE SCIENCE TRACK — Claude Science project `SPACE SYNTH X`

📄 **Full setup, the verified numbers they carry, and the prompt queue: `docs/SCIENCE_PROMPTS_2026-08-31.md`.**

**Why it exists, his words:** *"this is for us to get better data for star maps, black holes… the
state of the art knowledge we need to advance our project and make it more efficient and NASA collab
ready."* ⛔ **It is NOT a place to describe our build, our show, or our sprint.** He rejected a first
draft that did exactly that: *"being built towards a show is stupid… youre really just bashing in our
current shit into the description."* **Keep it science-facing.**

⚠️ `[VERIFIED 2026-08-31 14:26:24]` **Claude Science advertises LIFE SCIENCES only** — no physics or astronomy
on the product page. What transfers: 60+ databases, literature search (**ADS, arXiv, INSPIRE, GWOSC,
Zenodo**), reproducible artifacts, and a **reviewer agent that flags incorrect citations, untraceable
numbers, and figures that do not match their code.** ⭐ **Design prompts around that reviewer:** ask
for relations, numbers and named sources — things that can be checked. It has **no access to our
simulation**; never ask it to run ours.

| prompt | feeds which window | value by Saturday |
|---|---|---|
| **P0** reference universe + IMF audit — *what object are we actually simulating?* | the star map, and the regime every BH forms in | ✅ **run first, alone** |
| **P1** what a black hole should actually look like | 🟣 **FABLE F1** | ✅ **highest** |
| **P2** the three merger signatures | 🟣 **FABLE F3** | 🟡 maybe |
| **P3** neighbour finding in production N-body/SPH codes | 🟣 **FABLE F2** | ⛔ long game — run it anyway |

🚨 **P0 FIRST AND ALONE.** Its answer is the input to P1 and P2: **if our reference universe is
unphysical, FABLE must know that before it designs a renderer for it.** Our own numbers say ~594,276
M☉ sits inside roughly an AU, and nobody has ever checked that against the literature.

### 🚨 HOW SCIENCE OUTPUT COMES BACK — the rule that keeps this honest
**A Claude Science answer is a CLAIM until it is cited and checked. It is not a result.** The reviewer
checks numbers *inside* Claude Science; **nothing checks them on the way into this repo.**
1. It lands as `docs/SCIENCE_2026-XX-XX_<topic>.md` **with primary references inline — never pasted
   straight into `src/`.**
2. **Every number that reaches `src/` carries a citation beside it**, like every other claim here.
3. ⛔ **Never fit anything to our own simulation output and call it physics.** Published relations
   only. (Precedent: Eker 2018 MLR, Lupton 2004 asinh — **never fit the NASA CSV**.)
4. **"The literature does not settle this" is a RESULT.** Record it as one. That is what
   NASA-collab-ready actually means.
5. **A contradiction with our board is a FINDING, not something to smooth over.** If the science says
   our universe is unphysical, that goes on the board as a row, loudly.

---

## 6. STATE OF THE TREE — dirty, expected, uncommitted

**Modified:** `docs/BOARD.md`, `docs/BOARD_BLACKHOLE.md`, `docs/DESIGN_2026-08-23_THREE_WALL_ROOM.md`,
`docs/STATUS.md`, `docs/TODO.md`
**Untracked:** `docs/DESIGN_2026-08-31_HOW_THE_INDUSTRY_RENDERS_THIS.md`,
`docs/PLAN_2026-08-31_FIVE_DAYS_THREE_MODELS.md`, `docs/HANDOFF_2026-08-31_FOUR_WINDOWS.md`,
`docs/SCIENCE_PROMPTS_2026-08-31.md`,
`tools/frustum_validate.cpp`, `tools/measure_frustum_cost.sh`, `tools/verify_citations.py`

**What landed today (2026-08-30/31), all verified:** the citation audit + its tool · the BH board's
dead "verified against killtube" basis corrected · 4 dead citations fixed · the venue geometry
corrected in doc, board and memory · `STATUS.md` re-cut · the industry-rendering research · the
off-axis frustum math proven · the cost harness written.

---

## 7. 🔴 BLOCKED ON HIM — no model can move these

1. **THE CHARGER.** O2 will not run on battery (was 17%, discharging, *"No adapter attached"*).
2. **Three verdicts from the clock work, unjudged:** posed spin **20–45% slower**; sustain rebirth
   **~3× faster**; **warp may look WORSE** — honestly so.
   ⏸️ **Warp-as-more-steps is DEFERRED by his order 2026-08-31 12:43:01** (*"yeah warp defo needs more steps but thats
   not for now"*). **Agreed and parked — do not re-argue it, do not re-measure it to prove it.**
3. **The venue's two questions, still unanswered: 60 fps? external SSD?**
4. **The eye position** for O1 — sweet spot is his call; centre @1.60 m is a placeholder.
5. **Sonification is ZERO lines** (`grep -rl "sonif\|perParticleVoice\|fieldVoice" src/` → nothing).
   Design complete. **Not a five-day item. Do not start it.**
