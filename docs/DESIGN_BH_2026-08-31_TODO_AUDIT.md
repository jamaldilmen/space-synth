# BH1–BH10 AUDIT — `docs/TODO.md` lines 46–55 vs the tree, tonight

**Written:** 2026-08-31 22:59:30 · **By:** FABLE (report-only lane, BRAIN's order 2026-08-31 ~22:4x)
**Verified against:** working tree at HEAD `84c1314` **plus OPUS's uncommitted `renderer.mm`** (the
live file, dirty at audit time). `render.metal` is **3270 lines** (was 3106 at the 08-30 citation
audit — 164 lines added since, mostly the B2a lens-debug pass; every cite below :1400 has drifted
+19 or more). **Every `file:line` in this doc was grepped or read tonight**, not carried forward.

**Scope guard:** this doc contains **no lens-cost measurement, no fifth instrument, no proposal to
restart that track** — his order 2026-08-31 22:29 killed it. This is the TODO bucket audit only.

---

## THE HEADLINE THE ROWS DON'T SAY

Two deletions on 2026-08-27 gutted this bucket's subject matter, and half the rows still talk as if
the deleted code exists:

1. **The march is dead** — `bhmarch_fragment` + the whole 08-17 emission law (Shakura-Sunyaev
   `T(r)`, the `g` factor, radiative transfer, bit19, its three dials), ~410 lines, 20:49:10, his
   order. Banner: `render.metal:3090-3119`, `renderer.mm:4521-4528`.
2. **The sprite lens is dead too** — the bit8 angle-space thin-lens solve, the second image, every
   `lensRamp`/`imageWeight`/`preLensNDC` consumer, ~320 lines, 21:02:15, his order (*"FUCK THE
   LENSE. this enitre approach is ass."*). Banner: `render.metal:1035-1080`. What survives of the
   secondary instance is permanently culled dead code (`render.metal:1077` `if (isSecondary)
   cullThis = true; // no second image without a lens`).

So of the ten rows: **four are about deleted code** (BH1, BH2-as-written, BH4, BH7), and the live
successor to all of it is **F1**, which is designed (`DESIGN_BH_2026-08-31_F1_*.md`) and not built.

---

## VERDICTS, ONE LINE EACH

| # | Verdict | In one sentence |
|---|---|---|
| BH1 | **WRONGLY SCOPED** | The emission law it wants tested was deleted 08-27; there is nothing to test. Strike. |
| BH2 | **STILL OPEN — re-scoped** | Still two Ω laws, but the pair is now playback-Keplerian vs Doppler-Kerr; one-line unification, previously written and reverted on a misread. |
| BH3 | **ALREADY CLOSED** | Struck in TODO; its residual "decide the sphere" is decided in the F1 design (keep `bhbody`, integrator supersedes inside the region). |
| BH4 | **ALREADY CLOSED — strike** | The board it corrects was corrected, and then the entire lens the fixes lived in was deleted 08-27. |
| BH5 | **WRONGLY SCOPED** | The "lens" the gate switches is dead; what `bhLensActive` really zeroes today is the SHADOW radius, and under the 16:33 law the binary gate fights the transition F1 exists to show. |
| BH6 | **ALREADY CLOSED** | Struck 08-22, AMR on bit21, verified then; nothing new. |
| BH7 | **WRONGLY SCOPED** | Its objection is now the epitaph carved on the march's grave and the standing constraint on B2b; the render row is closed by deletion, the physics half lives elsewhere. |
| BH8 | **STILL OPEN (redshift half)** | b_c settled; the full A.16 `g` still unbuilt — a deliberately diluted 0.3-blend redshift survives in the sprite path; the honest home for the full factor is F1's integrator. |
| BH9 | **STILL OPEN (pointer)** | Most sub-rows stand; A2 is stale (its ratchet was deleted §Z1/Z6); **A3②-white is promoted — the cap kill made it MORE likely.** |
| BH10 | **STILL OPEN — deciding move changed** | The five 12:13 complaints stand, but "screen time on the lens" is a dead road: nothing draws a ring (§Z3). F1 first, then re-judge #4/#5. |

---

## PER-ROW EVIDENCE

### BH1 — WRONGLY SCOPED. Strike.
The row asks to test "the whole 08-17 emission law: blackbody T(r), g, absorption/transfer". All of
it was deleted with `bhmarch_fragment` on 2026-08-27 20:49:10 — the banner names each piece
(`render.metal:3096-3103`: *"the Shakura-Sunyaev T(r), the g factor and its g³ beaming, the
radiative transfer… its bit19 toggle and its three dials go with it"*). The cite `app_state.h:57
bit19` is dead — bit19 exists only in the two deletion comments. The deciding move ("read `[MARCH]
bCull`") is impossible: no `[MARCH]` log exists (grep: one comment hit, `renderer.mm:4521`);
`bCull` survives only as a dead field of `BHMarchUniforms` (`renderer.mm:33`) whose sole remaining
consumer, `bhbody`, reads only `inverseViewProj`. Any successor emission belongs to F1/B2b under
the banner's constraint (`render.metal:3117-3119`): **rays terminate on the matter that is there,
at sprite resolution — never averaged from a grid.**

### BH2 — STILL OPEN, and BRAIN's re-scope is right but incomplete.
The march Ω is gone, but the disc still runs **two Ω laws**, just a different pair than the row
names:
- **The motion**: playback advances phase with real Keplerian + dilation —
  `poseOmegaEff(r, GM, horizonR)` (`render.metal:509`, applied at `:650` in `pose_phase_advance`
  and `:761` in the vertex path).
- **The shading**: Doppler vOrbit uses phenomenological Kerr —
  `omega = 1.0f/(pow(rXY,1.5f) + KERR_A)` (`render.metal:1428`, `KERR_A` at `:308`).

So the bright limb is computed from a velocity the visibly-turning disc does not have. The old
row's other half — "hardcoded global +Z tangent" — is **RESOLVED**, not open: both paths orbit Z
prograde since plane fix №2 (`render.metal:1419-1426`: *"Both disks orbit Z now — one plane, one
prograde sense (+z×r, the spawn sense), no branch"*).
⛔ **CORRECTED 2026-09-01 01:55:30 — that "RESOLVED" was RENDER-SIDE ONLY and is incomplete.**
BRAIN's §Z14 (verified in source): the PHYSICS orbits about **+Y** at four sites
(`particles.metal:2380`, `:1210`, `:2371`, `:3290`) and `poseAxis()` (`render.metal:570`) survives
as a third convention. BH2 is therefore not "two Ω laws" but **one axis-and-law agreement problem
across THREE conventions** — see `DESIGN_BH_2026-09-01_DISK_STATE.md` §3, where it gates the disk.

**Next concrete move:** replace the `:1428` omega with `poseOmegaEff` at the same radius. One line.
A version of this was written and reverted 2026-08-20 14:22:25 **on a misread verdict — never
rejected on its merits** (the row says so itself). This is the unified-physics goal ("one quantity,
one law") in a single function. Not ordered — his ratification, OPUS applies.

### BH3 — ALREADY CLOSED (struck), residual decision now designed.
The row is struck; its tail question — *"decide the sphere before touching the lens further"* —
has a designed answer: `DESIGN_BH_2026-08-31_F1_RENDERER.md:181-182` keeps `bhbody_fragment` (now
`render.metal:3034`, `bc = 2.5980762f * rsW` at `:3047`) as the depth-only body, with F1's
integrator superseding it inside the lensed region. Decision rides F1; no separate row needed.

### BH4 — ALREADY CLOSED. Strike the row.
Its only content was "the board is wrong", and the board no longer is: `BOARD_BLACKHOLE.md` §2
carries both blend sites as ✅ FIXED 2026-08-14 17:30:54 / 17:53:52, re-verified twice (board
:463-466), and §6 row 1 is struck ✅ DONE (:633). **And the question is now moot twice over: the
entire sprite lens those fixes lived in was deleted 2026-08-27 21:02:15** — `cam.tuneLens` survives
only as an unread struct field (`render.metal:44`), and the `imageWeight = cam.tuneLens * lensRamp
* …` site the row cites does not exist (grep: `imageWeight` is `= 1.0f` at `:792` and consumed by
the permanently-culled secondary at `:1535-1540`). The one thing worth keeping — **every
pre-08-14 slider A/B is void** — the board's §2 callout already carries.

### BH5 — WRONGLY SCOPED under the 16:33 law. The design answer, since BRAIN asked for it:
Verified live: `renderer.mm:1957` `bool bhLensActive = (impl_->physicsUniforms.totalAmplitude <
0.02f);` (BRAIN's corrected number confirmed; TODO's `:1827` and §Z8's original `:1907` were both
stale — §Z8 self-corrected at 22:52:54). But the row's premise — "the LENS is off during play" —
describes deleted code. What the flag actually zeroes today is **`cam.bhShadowNdcRadius`**
(`renderer.mm:1995-1998`): the shadow/photon-capture radius the shader gates key on. During play
the hole's shadow vanishes instantly at the first note, **while `rsEff` — the live horizon/mass
the radius is computed from four lines up (`:1951-1956`) — is still large.**

**Judgment:** under his 16:33 law (one entity, two exclusive states; *play RETURNS matter* — the
hole drains continuously via rebirth withdrawal, `renderer.mm:3781-3793` per §Z8), "no hole during
play" is an **outcome the physics already produces**: play drains M → r_s shrinks → `bSim` shrinks
→ the shadow leaves by itself, continuously. The binary amplitude gate is a pre-law proxy for that
outcome, and in the transition window it now **fights the law** — it snaps the picture to
"no hole" at the first note while the mass ledger says the hole is still there, hiding exactly the
pump-out transition the law makes the show's centerpiece. This is the same shape as Z6 #4 (his
cure: *"fix the underlying value, never smooth the render"* — a binary gate is a step-function
blanket like the ease was).

**Recommendation:** when F1 lands, delete the amplitude gate and let shadow/lens presence ride
`rsEff` alone (already live at `:1951`). Until F1 lands, leave it — it is his deliberate call and
removing it early changes what he sees with no lens to justify it. Needs his ratification either
way.

### BH6 — ALREADY CLOSED.
Struck 08-22 (AMR → bit21), A/B'd then. Nothing since touches it. The permanent consequence
("every pre-bit21 AMR conclusion is void") stands.

### BH7 — WRONGLY SCOPED. Close the render row; the objection lives on as a constraint.
"The march samples NEAREST from a 128³ grid" — that march is gone, and the deletion banner
enshrines BH7's own objection as the *reason* (`render.metal:3107-3113`: a fog integral over a box
can only ever be a soft blob) plus the standing ban (`:3117-3119`). The constraint is already
posted where F1 work will meet it: §Z8 notes the B2a march touches no particle data and that the
protection ends at B2b. **The physics half — capture/merge sampling the same 128³ hash — is real
and open but is a different finding** (the 2026-08-30 "grid samples 32 of 334,576" row), not BH7.

### BH8 — STILL OPEN: the redshift half only. Cites corrected, destination re-scoped.
b_c is settled (unchanged since the 08-22 derivation). Live cites tonight: `kLensBc`
`render.metal:344`, `bCapt` `:1009-1014`, `bhbody` bc `:3047` — TODO's `:337/:990/:3028` drifted
again (+7/+19/+19; third drift for this row).

Redshift status, read in source tonight:
- The march's `g` died with the march.
- The sprite path computes the full Doppler `gDop` (`render.metal:1497`) **and discards it** —
  `(void)gDop` at `:1521`; the live beaming law is the pre-08-14 baseline (`:1526-1528`).
- Gravitational redshift exists **only** as a deliberately diluted 0.3-blend on temperature:
  `gravShift = mix(1.0f, sqrt(max(0.05f, 1 − BH_R_IN_SIM/r)), 0.3f)` (`:1543-1548`) — and note it
  uses `BH_R_IN_SIM`, a fixed constant, not the live `horizonR` (the "a body has a mass but no
  radius" pattern again).
- The comment at `:1493-1494` states the √(1−2M/r) term is *"deliberately NOT folded in"*.

**Next concrete move:** do NOT re-attempt the full A.16 single-`g` on sprites — §4c's lesson stands
(a 41× intra-frame range cannot ride an additive point cloud; both 08-14 attempts died on
exposure, not physics). The honest home for the full factor is **F1's per-pixel integrator**, where
the collapsed state is a surface and the exposure problem does not exist. Fold BH8-redshift into
the F1 work list; keep the sprite path's mild blend as-is until then.

### BH9 — STILL OPEN as a pointer. One sub-row stale, one promoted.
Re-checked against `BOARD_BLACKHOLE.md` §N2/§N3 and the §Z session:
- **A2 (reversibility)** — **STALE.** Its remaining ask ("clean 2M repeat" of the 08-08 refund
  test) predates tonight: the ratchet it measured against is deleted (§Z1), all four cannot-go-down
  rules are dead (§Z6), rebirth withdrawal is structural, and he has SEEN the build (*"app behaving
  great :)"*, 19:39:56). Re-running an 08-08 test against a deleted mechanism proves nothing. Fold
  A2 into §Z as provenance.
- **A3② / A3②-white** — **STILL OPEN and PROMOTED.** §Z6's closing paragraph is explicit: the
  220 px blackbody blob is still gated only on `cam.horizonR <= 0.0f` (verified tonight:
  `render.metal:2130`, size `pow(Mbh, 0.8f)` at `:2137`), the horizon measurement reads zero with
  two massive bodies, **and the §Z4 cap kill raised reachable mass — the endgame it unlocks.**
  One-line fix (mass ceiling on the blob gate) traced 2026-08-10, never built, NOT ordered.
- **A3① (denominator)** — open, still not binding, engages on long runs. Unchanged.
- **A5 (3–16 min fuse)** — open. The pre-record decision (his 08-31 call) halves the *show* risk —
  an offline run can wait out or retry the fuse — but any live segment still carries it.
- **A6 (refund floor leak)** — open, S. **A8 (`feed` nonzero)** — open, re-measure, S.
- **MERGER-FACE** — open, M, research-first; nothing since 08-13 touched it.
- **B9 (merger flash invisible, §N3)** — open, S, un-re-verified since 08-03.

### BH10 — STILL OPEN; the deciding move is no longer "screen time".
The five 12:13 complaints (§4d) stand un-actioned. But the row's move — screen time on the lens,
one complaint at a time — is a dead road: **nothing currently draws the ring, arch or arc** (§Z3,
both renderers deleted). Complaint #4 (*"fake visual not physical overlay"*) is precisely the
complaint F1 answers — a backward per-pixel integrator instead of a per-particle costume — and #5
(*"reddish blueish, not just blue grey"*) moves with the full `g` (BH8) on F1's surface.
Complaints #1 (streaks) and #2 (diamondy) are blocked on the star-attribute dials by his own two
reverts, unchanged. **Re-point BH10: F1 first, then re-judge #4/#5 with his eyes.**

---

## BRAIN'S REAL QUESTION — the one visible thing

**A3②-white. The 220-pixel white billboard standing where the hole should be.**

Of everything genuinely open in this bucket, it is the only item that is all four of:
1. **A defect he has already seen and named** — *"they look cheap and sluggish compared to the
   rest"*, the blown-out squarish white slab (2026-08-10).
2. **More likely tonight than when it was filed** — §Z4 killed the outcome cap, so reachable mass
   went UP while the blob's `horizonR <= 0` gate (`render.metal:2130`) is unchanged; §Z6 flags
   exactly this as the still-open endgame.
3. **A one-line, already-traced change** — a mass ceiling on the gate, traced 2026-08-10, no
   instrument, no measurement, no new design. Exactly the register of "check our todos. fix them."
4. **Show-catastrophic if it fires at Cologne** — a flat blue-white 220 px sprite in the middle of
   a formed-hole scene, on a 10-metre wall, is the single cheapest-looking failure the app has.

It removes the ugliest wrong thing rather than adding a new right thing, and with 5 days left that
is the better trade. Runner-up: BH2's one-line Ω unification (also cheap, previously written,
reverted on a misread, never rejected on merits) — but its payoff is a correctness the eye may not
consciously catch, where A3②-white's payoff is the absence of something he already called cheap.

**Neither is ordered. His ratification, then BRAIN/OPUS applies. F1 remains the item that changes
the screen MOST — but it is not a row in this bucket, it is the lane everything here defers to.**

---

**Not done here, per his 22:29 order:** no lens-cost instrument, no measurement design, no restart
of that track in any form.

**Last Updated:** 2026-08-31 22:59:30
