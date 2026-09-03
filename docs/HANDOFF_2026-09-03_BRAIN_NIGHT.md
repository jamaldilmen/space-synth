# SPACE SYNTH — handoff 2026-09-03 15:37:53 (BRAIN, night session + routing)

> **His verdict on this state:** the built changes have NOT been seen yet. What he did rule, verbatim:
> *"No chladni weird different Color profile clearly. Field is fine. Chladni too dsrk. And pixely. Also not fine filament at sustain but lowkey buggy. Maybe it's the hardening thing. It used to be so goated in tube."* (2026-09-03, before sleeping)
> *"Return pull. i that doesn't matter problem is that merger stsndoff. Soon ss the bh is there retun pull must go cause bh has its own gravity taking over"*
> *"No ffs. We have rebirth. Before the shape of chladni occupied less space because of the the tube. Kow no tube. Not shsrp inage what the jelly dont u understand"* (2026-09-03 ~15:2x — his correction to BRAIN)
>
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` **§AE → §AD → §AC.12** — NOT this file, NOT `docs/BRIEFING_2026-09-03_NIGHT.md`, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics`
**Citation provenance:** every `file:line` in this document was read against the tree at **last code commit `74bee76`** (2026-09-03 15:4x), with `src/main.cpp` **already stripped** of the `SS_PHASE_AMOUNT` diag. Verified against `git show HEAD:src/main.cpp`, not renumbered by arithmetic. If any source commit lands after `74bee76`, **re-grep — do not subtract** (§AE.7).
**Build + launch:** `bash package_macos.sh` then `SS_FULLSCREEN=1 SS_LENS_RENDER=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth`

⚠️ **The bundle on disk (06:08:22) was built WITH a TEMP-DIAG that has since been stripped. It no longer matches source. Rebuild before any verdict run.**

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | MIDI Real-Time bytes ate live notes AND note-offs | `[F8][90 3C 64]` in one packet → silence; `[F8][80 3C 00]` → note never stops | `status >= 0xF8` consumed as 1 byte before the type mask | `midi_input.mm:28` | `[MEASURED n=3]` 7/7 vectors + live on the built binary |
| 2 | Merger stand-off had no mechanism | "unowned, no cause traced" since 2026-09-02 | **No seed↔seed path exists. Both intakes refuse ≥50 M☉** | `particles.metal:3836` + `:1519` | `[READ]` both gates, comment *"Seeds themselves and walls don't get eaten"* |
| 3 | Return pull returned after formation | proportional fade — 70% of pull at `bhStrength` 0.3 | formation hold, latched at first 100%, clears only at `r_h ≤ 0` | `renderer.mm:1854-1857` | `[MEASURED n=3+n=3]` pull 0.00 on 15/15 unconditional samples |
| 4 | Chladni "weird colour" unexplained | candidate only (phase tint, wrong reason) | **the tint IS it — `phase` is wrapped cumulative PATH LENGTH, not oscillation phase** | `particles.metal:3566-3567`; tint `render.metal:2334` | `[MEASURED n=3]` 11–21° → 3° per-pixel hue Δ with tint off |
| 5 | Chladni dashed lines at an angle | sprites at 0.84 device px; Metal drops ~30% | 1-px floor applied AFTER the resolution scale | `render.metal:2537` | `[MEASURED]` 0.84 → 137/200 lit; 1.00 → 200/200; 68% → 99.7–100% neighbour-lit |
| 6 | "Chladni too dark" attributed to render | assumed exposure/bloom/floor | **the bulk LEAVES; not rendered dark.** Dated to `912e4bf` | `particles.metal:3395-3404` | `[MEASURED 5/5]` meanR 11→27, maxR→90; lum 11.4→0.35/255 |
| 7 | Offline rendering "how do we implement it" | unanswered | design delivered, Tier 1 buildable, RT thread untouched | `docs/DESIGN_2026-09-03_OFFLINE_RENDERING.md` | `[READ]` tap at `main.cpp:213`, output at `renderer.mm:5391-5433` |
| 8 | MIDI mapping design would die on stage | mapping applied inside the slider helpers | register in helper, **apply outside `if (showHUD)`** | `main.cpp:1108`→`:2257` | `[READ]` verified by brace depth; 16 CollapsingHeaders |

## 2. 🚨 OPEN — his list, verbatim

1. **"Before the shape of chladni occupied less space because of the the tube. Kow no tube. Not shsrp inage what the jelly"** — and *"We have rebirth"*, i.e. population is NOT the problem.
   `MEASURE:` already done — `[MEASURED n=20 logs]` `live=` is 1,982,817–2,000,000 on every sample; rest baseline 1,999,997. The field is NOT depopulating.
   State: `[MEASURED 5/5]` tube-era can was `r ≤ 6`; matter now sits at `meanR ≈ 27` ⇒ ~20× fewer particles per projected pixel. ⛔ **BRAIN's proposed boundary at r≈34 is DEAD — the tube worked by making the figure SMALL, not by stopping escape.** — **NOT decided: whether to restore a play confinement at r≈6 as a SPHERE (his sphere-only law, 08-27). HIS WORD REQUIRED. Nothing built.**

2. **"Chladni too dsrk"** — field fine, bars too dark.
   `MEASURE:` `[LUMPROBE]` HDR frame-average, 1 Hz, already in the app; rest ≈0.036.
   State: `[MEASURED]` figure above 10% of rest brightness for ~**2 s** at rho 800, and **<1 s at rho 2000 — his own max zoom-out is the worst case.** Bar/field per-pixel ratio ≈1.0, same luminance law as read. ⚠️ He has **pre-ruled out** the exposure/tonemap path (AD.11c) — this is the same fault as item 1, not a separate brightness bug.

3. **"And pixely"**
   `MEASURE:` `SS_PHASE_AMOUNT=0` (⛔ **now stripped** — use the "Phase Amount" fader at `main.cpp:1489`).
   State: `[MEASURED n=3]` **NOT the tint** — isolated-pixel and partial-intensity fractions identical between arms. The colour-noise component goes with the tint; the geometric component stays. The 1-px floor is neither exonerated nor convicted. **HIS EYES, with that fader as the discriminator.**

4. **"Also not fine filament at sustain but lowkey buggy. Maybe it's the hardening thing."**
   State: ⛔ **hardening RULED OUT as a changed mechanism** — `[READ]` diffed vs tube-era `SPACE-SYNTH-TUBE @ 13ac249`: `ridgePull` lines identical, hardness integrator identical, same producer and 3 consumers. He is right about the symptom: hardening cannot act on matter leaving at cap speed. Same root as item 1.

5. **What does "formed" mean once the hole has been fed by play?** (§AE.2)
   State: `[MEASURED n=3]` `bhStrength = 0.01` while a 1,579→2,154 M☉ seed **grows**, `r_h > 0`, lens gated off the entire watch. **HIS RULING REQUIRED** — changing it wrongly breaks the 100% law shipped at `5d98b7f`/`4fd2b6f`.

6. **MTC/System Common MIDI fix — land it or not?** (§AE.8)
   State: `[MEASURED n=3]` `0xF1`/`0xF3`/`0xF6` still eat a following note. **Not in the Cologne config he ruled** (clock never emits them). BRAIN HELD IT. Five-second decision; size table `F1:2, F2:3, F3:2, F6:1, F0:scan-to-F7`.

7. **Startup UI seeding pass — does it read as "moving something"?**
   State: registry is identical either way; without it mappings arm per panel on first open, i.e. one sweep at soundcheck. **Does not block a build.**

8. **🚨 Conservation watchdog reads a constant** (§AE.6) — `Mlive=594276/189044` on every sample of all 20 runs, live mass 3.14× the total it must equal. **Unowned, not chased.**

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Gate the return pull on `lastHorizonR > 0` — REJECTED 2026-09-03 06:01.** BRAIN specified it; FABLE refused and disproved it before building. `bhSeedMassMono = gMaxMass` only when `gMaxMass >= 50` (`renderer.mm:3758-3761`), so `lastHorizonR > 0` ⟺ a ≥50 M☉ body exists — exactly the set the pull acts on. The gate makes the pull dead code by construction. Replaced by the formation hold; that hold is verified as mechanism and **only in the surviving-seed regime.**
- **A play boundary at the buffer edge r≈34 — REJECTED 2026-09-03 ~15:3x by his correction.** Even as a hard wall the figure stays ~20× sparser than the tube look. The confinement question is about the figure's SIZE (r≈6), not about escape.
- **Return pull braking merger infall — DISPROVED 2026-09-03 05:5x.** `particles.metal:1508` is `dv = max(0.0f, vIn - vRadIn)`, genuinely one-sided; v5's GAIN=1.0 did not break it.
- **Merge-gate unit mismatch — DISPROVED 2026-09-03 06:0x.** `units.h:48-53` multiplies `gmSim` by `kTLapse²` *because* the integrator steps in wall seconds, so `vrel2` and `vesc2` are both (sim/wall-s)². The comparison is consistent; the `:3907` "×120 convention" comment is stale prose.
- **Reading seed-count drops as re-merging — REJECTED 2026-09-03 06:4x.** No path fuses two ≥50 bodies (§AE.1). Run 4 printed `seeds=0` with `Mmax 2,154` alive, so the counter itself is suspect in that regime.
- **`SS_PHASE_AMOUNT` TEMP-DIAG — STRIPPED 2026-09-03 15:3x.** Authorised by BRAIN purely to measure the colour mechanism without his hand on a fader; measurement is done (n=3), the real fader exists at `main.cpp:1489`, and a diagnostic hook must not ship to the stage branch. Do not re-add it.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-03 15:34:44  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 03474e0
  FAIL  4 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M src/main.cpp
           M src/render/render.metal
           M src/render/renderer.mm
          ?? docs/BRIEFING_2026-09-03_NIGHT.md
  WARN  24 commit(s) not pushed

2. board vs HEAD
  FAIL  docs/BOARD_BLACKHOLE.md is 1 code commit(s) behind HEAD (verified at dbda8e8)
  WARN  docs/BOARD_BLACKHOLE.md is 244831B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  WARN  docs/BOARD.md has no 'Commit at last verification: `<sha>`' line — add one
  WARN  docs/BOARD.md is 166995B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    46 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:577 / :765 / :1146 / :1466 / :1469 / :2585 / :3329
  ?     src/render/postfx.metal:66
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

**Both FAILs resolved during this handoff, in this order:** `src/main.cpp` was **stripped** (§3), `src/render/render.metal` → `ae0449e`, `src/render/renderer.mm` → `74bee76`, then `BOARD_BLACKHOLE.md` re-stamped at `74bee76` with §AE folded in, then this file and the briefing committed. The board is no longer behind a code commit.
⚠️ **Two WARNs deliberately NOT fixed and left for his call:** the board is 245 KB and preflight wants closed rows split into `BOARD_CLOSED.md`, and `docs/BOARD.md` has no verification line at all. Both are restructuring of the reference-of-truth two days before Cologne — **not done unasked.**

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "Gate the return pull on `lastHorizonR > 0`" | Makes the pull dead code — that gate is true exactly when the pull has a body to act on. FABLE disproved it with arithmetic before building. |
| "The particles fly outward and nothing stops them — that's why it's dark" | His correction: the fault he sees is COARSENESS (density per pixel), not darkness, and rebirth already handles population. Confinement at r≈34 cannot fix it. |
| "Confirmed — the 32-of-334,576 figure is wrong" | I verified SONNET's `kGridSize` claim and asserted a second claim on its authority without checking. `bhPeakCount` (`renderer.mm:404`) is a PARTICLE count in the densest cell; the figure was always correct. Memory left untouched. |
| "SONNET's Syphon citation was drift" / "FABLE used the wrong reference tree" | The Syphon miss was genuine (−476, no edit explains it) but I first lumped it with drift; and FABLE had diffed against tube-era `13ac249`, using POST-TUBE only for a file inventory. I corrected the wrong half of its sentence. |
| "The return pull may be capping merger infall — a stand-off candidate" | Disproved on inspection before it reached him. `:1508` is one-sided. |
| "The merge gate's two sides may not share a time base" | Disproved by `units.h:48-53`. Comment stale, code correct. |

---

**Last Updated:** 2026-09-03 15:37:53
**Folded into board:** `docs/BOARD_BLACKHOLE.md` §AE @ 2026-09-03 15:37:53
