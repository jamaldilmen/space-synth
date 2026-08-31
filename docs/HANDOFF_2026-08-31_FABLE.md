# FABLE HANDOFF — 2026-08-31 21:39:45 — the F1 design lane

> **Window:** FABLE (Fable 5) · design/analysis only, zero `src/` or `tools/` edits, no
> build, no launch, no measurement — the token stayed with OPUS all day.
> **Cold start for the next FABLE:** `docs/BOARD_BLACKHOLE.md` §Z first, then the five
> FABLE docs below. This file is the day's record, not the reference of truth.

## 0. THE FIVE DOCS — all in the citation sweep, all DEAD 0 at close

| doc | what it is |
|---|---|
| `DESIGN_BH_2026-08-31_F1_RENDERER.md` | the transition-native geodesic renderer: region ∝ r_s(M)², mass-scaled transport, §Z satisfied by geometry not state machine |
| `DESIGN_BH_2026-08-31_F1_FALSIFIABLE_TESTS.md` | T1–T5 + the kill table — the answer to `[HIS WORDS]` *"how are u going to verify its not a fak elens"* |
| `DESIGN_BH_2026-08-31_F1_LENS_IMPLEMENTATION.md` | the buildable lens: in-shader planar RK2, B1–B6 order, B1 RULING + B2 SPLIT + per-half gates |
| `DESIGN_BH_2026-08-31_DISRUPTION_ARCHITECTURE.md` | torn-not-swallowed: (M,R,state), S1–S7, D1–D6 kill table; his R-carrier ruling = option B folded |
| `DESIGN_BH_2026-08-31_LENS_COST_MEASUREMENT.md` | measuring a ~5 ms pass in a 5–29 ms swinging frame: direct bracket, `ms(S)` fit, domain stated |

## 1. RULINGS ISSUED FROM THIS WINDOW (each recorded in-doc with its WHY)

1. **B1 gate replaced, not relaxed** (lens doc §5, 18:50:14). Old gate was wrong twice:
   relative-α in the far field where the observable is ABSOLUTE screen displacement, and
   it gated a regime the bounded march never enters. New: rel < 1e-3 (b ≤ 20) ∪ abs
   < 1e-4 rad (b ∈ 20–200) ∪ b_c rel < 1e-3. **Step baseline π/512** (≥4.6× margins);
   π/256 rejected at 1.1× margin; adaptive schemes legal if re-gated.
   `[MEASURED by OPUS]` B1 passes 3 legs: rel 2.166e-04 / abs 1.942e-05 / b_c 3.365e-04.
2. **B2 split accepted** with per-half gates (20:04:29) — gating B2a on B2b machinery
   would have repeated the B1 mistake. B2a's sharpest gate: with no particles, the
   termination class must be a function of b ALONE; any azimuthal structure is a bug.
3. **§7.2 aggregate termination**: his "1. yes" recorded WITH scope — ONE termination on
   ONE cell; accumulation along a ray needs re-asking. Cube-watch is report-don't-tune.

## 2. CORRECTIONS — mine given, mine taken. The taken ones matter more.

**Given:** T4 overclaim in the evening handoff — `[READ my kill table]` **T3 RING
CLOSURE is the ONLY individually uncheatable test** (image count is a property of the
CODE); T4 kills post-render warps only — a forward per-sprite displacement BEFORE the
cull (the deleted lens's ordering) passes it. **What cannot be cheated is THE SET.**
Load-bearing: it is the verification answer he asked for. BRAIN accepted and fixed.

**Taken:**
- `[HIS WORDS]` *"Also all this is once more still only at rest which you don't seem to
  understand. I play it. Particles return. New stuff forms."* → measurement doc §0 is
  now REST ONLY; the sim is DRIVEN and he is the drive. `[MEASURED by BRAIN]` all four
  arms 100% silent — one regime, never the other.
- **FOV-blind justification** (BRAIN): "sub-half-pixel everywhere" was false at narrow
  FOV — 1.02 px at 30°, the camera-ride regime. Corrected per-FOV; π/512's actual error
  is 0.20 px even there; escape hatch named (far leg → 5e-5 rad if a ride shows a seam).
- **CLOSURE scope defect** (OPUS's run found it, 21:39:45): my gate compared a
  RENDER-only bracket against PROFILE **Total = Compute + Render**
  (`renderer.mm:1786`) — it could never pass. Corrected: closure against Render+PostFX.
  **Rule: a closure gate must NAME the scope both sides share.**
- **My half-read of the verifier** — grep hit `DOCS = `, never read the `DOCS +=` glob
  below it; claimed my docs weren't swept when they already were. Same trap as the
  evening handoff's common shape: agreement mistaken for confirmation.

## 3. 🚨 THE COST PICTURE AT CLOSE — the number that reshapes tomorrow

`[MEASURED by OPUS, first direct bracket]` **89,368,329 geodesic steps / 165,880 px
(538.8 steps/px), lowest constant-work reading 5.15 ms** ⇒ `[HYPOTHESIS: additive
non-negative scheduling envelope]` true cost ≤ 5.15 ms at that work level.
⛔ **The ~0.3 ms premise is RETIRED — off by ~15×.** Direct-beats-differential
STRENGTHENS (a 5 ms pass is hopeless to difference out of a 5–29 ms swinging
background). Affordability now rides on the sweep + `ms(S)` fit — 5 ms at 0.166 Mpx
covered puts a full-coverage live lens in real question; the levers are adaptive
stepping, the winding cap, and `B_geo`, ALL re-gateable through the same validator.
⭐ And `[HIS WORDS]` *"I will not play it live all the time we will will pre record skit
of it if not everything"* — the extrapolation's role may shift from pass/fail to a
LIVE-vs-RECORDED split. A recorded segment lifts the FRAME budget only; honesty rules
do not lift. Constraint that may LIFT — nothing rescoped on it.

## 4. ⛔ DEAD ROADS FROM THIS LANE — with why, because the why is the value

| road | why it is dead |
|---|---|
| Between-runs lens-cost A/B, any order | at REST there is no steady state — the field collapses 95% in ~4 min, background swings 3–5× within arms (5.48–29.08 ms), and even ABBA only cancels a LINEAR term; the drift has humps |
| ABAB interleave under monotone drift | arm correlates with time order; the paired deltas agreeing to 0.03 ms were the drift measured twice `[BRAIN's find]` |
| Relative-α gate to b = 200 | absolute screen displacement is the observable; the march never enters b = 200 |
| "sub-half-pixel everywhere" as a gate justification | FOV-blind; pixel count alone cannot convert an angular error |
| A closure gate without a named scope | render-only vs compute+render can never close; my defect, OPUS's run exposed it |
| "Just build B2b and look at it" as the fallback | `[HIS WORDS]` *"thsi apporach feels lazy"* — it abandons the falsifiability standard the whole session built. NOT the fallback. |
| A 2D trajectory LUT for the march | the α table's own history: silent two-file schedule mismatch cost 23.6% once; the integrator has no encoding surface (lens doc §1) |

## 5. 🔴 OPEN AT CLOSE — in the order they unblock

1. **The sweep + `ms(S)` fit** (measurement doc §2) — bracket is built; CLOSURE now has
   a correct scope; sweep run + pinned validation next. OPUS's step, his verdict after.
2. **B2a gates (1)/(3) frame observations** — captured-frame checks, OPUS has them queued.
3. **B2b** (particle + opaque-cell termination) — NOT started; its cost re-sweep across
   field states INCLUDING the transition is mandatory (measurement doc §1a hard-stop).
4. **The `:1907` binary lens-off-during-play gate** — pre-law mechanism; F1 makes it
   redundant or contradictory (region ∝ r_s(M)² drains with the hole). Decide at F1
   build, not before.
5. **Disruption S1–S7** — designed, his R-carrier ruling folded (option B); awaiting his
   sequencing. Does not jump the lens.
6. **P0** (what object are we simulating) — lands upstream of the renderer if it moves
   the reference object.
7. **His §7 items on the renderer design** — unbounded M cost cliff, multi-hole regions,
   the 220 px blob — still open, silence is not approval.

## 6. STATE OF THE TREE FROM THIS WINDOW

My lane at close: 5 design docs + this handoff, all clean in the sweep. `src/**`,
`tools/**`, boards, TODO, STATUS untouched by me all day. OPUS holds the token with
uncommitted `render.metal`/`renderer.mm` (its live B2a/bracket work) — my commits are
docs-only and touch nothing of OPUS's; `tools/measure_lens_cost.sh` is OPUS's to commit.

---
**Last Updated:** 2026-08-31 21:39:45 · FABLE
