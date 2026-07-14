# HANDOFF + EXECUTION PLAN — 2026-07-14 16:53:04

**Read this FIRST in a new window** (supersedes the next-window order in
HANDOFF_2026-07-13_state_of_the_union.md; that file remains the background).
Repo: `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE`, branch
`session-2026-06-30-honest-spacetime-friction`, HEAD `5a08ff9` (everything
committed, tree clean, NOT pushed). Jamal's rules in force: one verifiable
change at a time; his eyes are ground truth; commit only on his explicit order;
no hype.

---

## 0. WHERE THE PHYSICS STANDS (all measured, log-referenced)

The honest-BH chain after 07-13/14:

| Link | Status |
|---|---|
| Cold spawn collapses under PM | ✅ |
| Resolution below r_s (AMR fine box) | ✅, extent now 4.0 (was the DAM, §1.3) |
| No slingshot bounce | ✅ in visc bed (Balsara+gate); ❌ bounce RETURNS in visc-less bed (dam test: M(<0.5) 9.3e3→44) — dissipation is mandatory |
| Gas thermo doesn't blow up | ✅ density floor (poison 0) + density gate v2 (diffuse cloud stays cold: umax 2.6e-12) |
| Matter crosses the ring | ✅ L-TRANSPORT WORKS: vt:vr 13:1→2.5:1, infall dominant in shell 3–4 |
| Mass budget reached | ❌ best M(<0.5)=9.28e3 vs 2.97e5 needed. Best Mtot(<5)=3.83e5 (budget-scale mass EXISTS, parked at r≈1.8–2.7) |
| Geometric criterion fires | waiting (code live, observe-only) |
| Render the hole | untested (r_h never > 0) |

**THE blocker is no longer one physics term. It is ARTIFACT CLEANLINESS:**
the collapse now works well enough to amplify any grid anisotropy into
z-pancakes (his 00:10 "super lines"), and the cheat stack ate the one fully
successful core. Both are half-fixed (§1.4, §1.5).

## 1. WHAT WAS PROVEN / SHIPPED THIS SESSION (commit `5a08ff9`)

1. **Dead-launch 07-12 = display sleep.** A/B settled it; Jamal was right;
   audio change struck (stash dropped). Never claim a fix verified while an
   environmental variable changed simultaneously.
2. **Show 07-13:** `run_show.sh` rewritten to the unmasked honest default per
   his order. His verdicts: p90 = NO BLOB; "not lines but a geometric cluster
   next to the center star" (still open, minor). The gig was played WITHOUT
   SpaceSynth.
3. **The FINE-BOX DAM.** The week's "rotation ring at r≈2.5" was matter
   stacked on the cubic AMR box face (extent was 2.0; his screenshot showed a
   literal cube). Extent→4.0: collapse reached r50=1.035, M(<0.5)=9.28e3
   (×450). Lesson: the box must always swallow the collapse region.
4. **Deathblob root-caused + fixed (gate v2).** Π/ρ̄ is largest where ρ̄ is
   smallest → the SPH_VISC bed cooked the DIFFUSE cloud to the uMax CFL cap in
   seconds and pressure-inflated it (zero collapse in 40 min). Gate v1 (Π
   only) killed the heat but left a KINETIC pump (KEin 59→242/720f, CoM drift
   16 sim). Gate v2 = whole pair term fades in with density (200→1000
   M☉/sim³); below it the gas is exactly collisionless. Diffuse phase now
   matches the honest cold bed; core keeps its dissipation. `!viscOn` bed
   untouched.
5. **Carver #0 NAMED AND KILLED (the lines bug, seed #1).** The honest
   dynfric (even trilinear) lays a coherent z-plane seed −5σ within 20 s —
   measured with ALL toggles off (SS_INERT does NOT gate dynfric; only bit24
   does — remember this ladder hole). PM deepens it (−8.4σ); the dissipative
   collapse amplifies to −40…−48σ Zel'dovich pancakes = the super-lines.
   FIX: ±0.5-cell per-particle/frame sample-point dither on the dynfric
   trilinear read (CIC anti-aliasing). VERIFIED: dithered-dynfric-ON inert
   field = noise floor = dynfric-OFF, through tick 12.
6. **The cheat stack destroys honest success.** First working collapse
   (Mtot(<5)=2.26e5) was converted by DEFAULT-ON bit2 seed-capture into 6
   fake seeds (biggest 2.2e5 M☉, 780k particles eaten, "hole 74%").
   `SS_NO_CAPTURE=1` added (registry still fills cosmetically from mergers —
   harmless, feed=0, hole=0%).
7. **L-transport (SS_LTRANS, bit25)** built + A/B-verified (numbers in §0).
   It also AMPLIFIES z-lanes (11 vs 8 dip groups) — an amplifier, not a
   seeder.
8. **Instrument built:** sub-σ z-probe at known centers + the SS_INERT ladder
   (`scratchpad ladder.sh` — PORT IT INTO tools/, §2.6). Detects seeds ~−3σ,
   far below lanes.py's −6σ.

## 2. THE PLAN — definite, ordered, one change per step

**Step 1 — Find the SECOND z-seeder/amplifier. (THE blocker.)**
Fact: dithered full bed still pancakes at tick 12 (−24.8/−34.7/−18.3, 5 dip
groups, centers SHIFTED vs before) while x/y stay clean. An isotropic
amplifier cannot pick z out of isotropic noise → something z-ANISOTROPIC acts
in the full bed. Suspects, in order:
  a. **Legacy grid pressure** — bit14 kill was measured as "THE noise pump"
     on 07-08 and NEVER SHIPPED; it is ON by default. Count-difference
     repulsion on ≤32-capped cell counts. Test: full bed + bit14 set
     (SS_INERT_KEEP token `legacy` logic inverted — easiest is a tiny
     SS_NO_LEGACY env or flip the default) → tick-12 lanes.py A/B.
  b. **PM/SOR sweep order** — z-ordered relaxation sweeps can propagate
     z-correlated error. Test after (a): if lanes survive, alternate sweep
     parity/axis order per iteration (cheap change), A/B tick-12.
  c. **Visc gate cell-granularity** (mine): the density floor makes ρ
     per-cell-constant → the smoothstep is a per-cell switch. Test: full bed
     minus SS_SPH_VISC at tick 12 (no gate in play) vs with. If visc-off is
     clean, dither the gate's ρ read (same trick as dynfric) or use the
     particle's own smoothed pre-floor ρ.
  d. **AMR delta-prolongation** (trilinear is per-axis separable): full bed
     minus SS_AMR A/B.
Method for every rung: `SS_DUMP=<f> SS_DUMP_TICK=12`, then `tools/lanes.py`
+ the center probe. Noise floor for 480 bins ≈ −3.5σ; single tick-2 runs
fluctuate ±1σ run-to-run — for weak seeds STACK 4+ runs (different noise
draws average out; the seed is deterministic).

**Step 2 — Re-verify the clean collapse end-to-end.**
Full bed (`SS_AMR=1 SS_AMR_SWEEPS=4 SS_SPH_VISC=1 SS_LTRANS=1
SS_NO_CAPTURE=1`) soak PAST tick 12 into deep collapse. Success criteria, in
order: (i) no pancakes (lanes.py quiet), (ii) diffuse phase cold (umax at
floor), (iii) M(<0.5) exceeds 9.28e3 AND HOLDS (the gate's core dissipation
must bind what the dam test lost), (iv) Mtot(<5) ≥ 3e5 again.

**Step 3 — Watch `[HORIZON]` fire.** r_h > 0 needs 2.97e5 within r<0.5. If
step 2 stalls short: first check the fine box swallows the whole collapse
(extent 4 enough? r50 must be ≪ 3.0 blend start), then α/F_LTRANS (currently
0.1/100, λ-capped 1/12) — one knob at a time, [SHELLV]/[CORE] decide. Then
link 8: the render path (particles inside r_h ARE the hole — bh core
directive, never a shader overlay).

**Step 4 — Retire the cheats** (bit1–4, 6, 7 + re-key "BH %"/bhStrength HUD
to real r_h). Only AFTER the honest horizon has fired on screen and Jamal has
called it. SS_NO_CAPTURE already proves the bed works without bit2.

**Step 5 — The rest of the list, unchanged order:**
  a. The "geometric cluster next to the center star" (his 14:59 verdict) —
     may already be dead with the dither; verify with him before hunting.
  b. Readback flicker: radialMass/[CORE]/lastHorizonR intermittent zeros
     (also: [CORE] cadence collapsed to 165 lines/2h in long runs) — it FEEDS
     the pressure-yield gate (renderer.mm 1314/2111). Diagnose the
     clear-vs-read phase around renderer.mm:1426.
  c. AMR perf at dense states; extent-4 resolution decision (fineCell 0.0625
     vs 256³ cost — measure, then Jamal decides).
  d. Star size render compression (M^0.4 debt), HUD temp units, p90 ambient
     his-eyes verdict on a dense state.

## 3. RITUALS + LAB FACTS (hard-earned; violating these burned hours)

- `bash package_macos.sh` then `stat -f "%Sm" bundle vs sources`. Never bare
  make. Stale binary FIRST when a change "does nothing".
- `pkill -x SpaceSynth` before every launch; `script -q <log> env SS_...=1
  ./SpaceSynth.app/Contents/MacOS/SpaceSynth`; `ps eww <pid> | grep SS_` to
  verify env actually landed.
- **Wall-clock sleeps STRETCH BY HOURS on this Mac** (8-min timer fired 2 h
  late; "145 s" of loop sleeps took 59 min; a 20:13 build completed 23:07).
  Pace ALL soaks by LOG PROGRESS (`until grep -c ...`) or dump-file
  existence, never `sleep N`. `caffeinate -di` on every soak.
- Spontaneous clean app exits (f=32400, f≈10500) — cause unknown, no crash
  lines. If a soak dies early, just relaunch and note it.
- The dump/probe toolkit: `SS_DUMP=<file> SS_DUMP_TICK=<n>` (tick 0 never
  fires; tick 2 ≈ 20 s, tick 12 ≈ the pancake epoch), `tools/lanes.py`
  (−6σ detector), sub-σ center probe + SS_INERT ladder in
  `scratchpad/ladder.sh` — **port ladder.sh + the center-probe python into
  tools/ first thing** (scratchpad is session-ephemeral).
- SS_INERT does NOT gate dynfric (bit24 does) nor lifecycle. Check what a
  "everything off" bed actually runs before trusting it.
- Runs are seed-42 deterministic in STRUCTURE (same lane centers) but
  noise-floor amplitudes vary run-to-run (GPU atomics) — stack runs.
- Play-mode contamination: an unattended run can hear the room (mic) —
  KEin~1e7/nOut→0 is the signature; discard the run.

## 4. STATE OF THE TREE

- HEAD `5a08ff9` (this session), parent `a178295`. Not pushed.
- All new physics env-gated, DEFAULT OFF: SS_LTRANS, SS_SPH_VISC(+gate),
  SS_NO_CAPTURE, SS_AMR(+extent 4.0 — note: extent is compile-time, now 4.0
  for everyone using SS_AMR). Default/rest bed = what Jamal verdicted 07-13
  14:59 plus the dynfric dither (rest-field improvement, needs his eyes for
  the "geometric cluster" §5a).
- `run_show.sh` = unmasked honest default.
- Memory (assistant): space_synth_lines_rootcause / space_synth_amr_plan /
  MEMORY.md all updated through 2026-07-14 16:05.

## 5. FAILURE LEDGER THIS SESSION (do not repeat)

1. Gate v1 shipped on a half-diagnosis (Π-only) — the KE pump was visible in
   the same log I quoted. Read the WHOLE ledger line before designing.
2. The isolation ladder ran 5 rungs before I noticed dynfric wasn't gated by
   SS_INERT — verify what a bed actually executes, not what its name says.
3. Wall-clock timers twice (2 h-late kill; a "10-min" loop that ran 59 min).
4. My LTRANS and my density gate are both grid-stencil forces — I introduced
   two new members of the artifact class we were hunting. Every new
   grid-coupled force must ship with its anti-aliasing story from day one.

**Timestamp: 2026-07-14 16:53:04. No hype: the collapse engine now works well
enough that its remaining enemies are a second grid artifact and a mass
budget. The horizon criterion is live and waiting.**
