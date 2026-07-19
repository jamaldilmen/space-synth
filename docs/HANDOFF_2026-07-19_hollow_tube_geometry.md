# HANDOFF — The hollow-tube / no-depth loophole + non-Euclidean framing
**Written:** 2026-07-19 17:38:41
**Repo:** /Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE
**Baseline:** `0edde58` (current HEAD)

## Why this window opened
Jamal asked how the Veritasium video "How One Line in the Oldest Math Text
Hinted at Hidden Universes" (`/Users/airy/ARCHIVER/`, non-Euclidean geometry)
could help fix two loopholes in the TUBE:
1. The tube renders as a **hollow 2D shell on the thin inside walls** — no volume.
2. **No interconnectivity or depth WITHIN the tube**, but there should be.

This was a RESEARCH request, NOT a build request. **Nothing was changed.** No
build, no commit. This handoff is the analysis + the one experiment to run next.

## The mechanism of the hollow shell (grounded, file:line)
The play kernel has THREE competing shape-organizers in
`src/render/particles.metal`, and the wrong one runs by default:

1. **"Atom Model" spherical-harmonic sculpt** — `:1757`, `Y = cos(m·θ)·sin(n·φ)`.
   Sculpts particles onto a **sphere surface**. A surface has no interior → this
   is the hollow shell. **ON by default.** (Disable via SS_PLAY_SKIP bit16.)
2. **Cylindrical cavity eigenmode + Gor'kov** — `:1778`,
   `Ψ = J_m(k_ρρ)·cos(mθ)·cos(k_z·z)`. The physically-correct 3D standing wave
   and the **only organizer with an axial `z` term = the only one with depth.**
   Gated behind `SS_EIGENMODE` (bit23); **OFF unless env var set**
   (`src/main.cpp:2014`). NOTE: Gor'kov F=−Ψ∇Ψ pushes particles ONTO the nodal
   surface Ψ=0 (`:1809`), which is measure-zero → collects on thin shells too.
   The DEPTH here comes from the axial nodal planes cos(k_z·z), not the shell.
3. **Chord webbing** — `:1868`, ad-hoc `60×` cross-gradient for inter-voice
   connectivity. Not geometric — a fudge factor.

Code's own comment already knew this: `:340` — "k_z=0 ⇒ the pattern is a 2D
cross-section extruded along the tube (flat), which is what 'it's still just a
tube' was." Depth = the axial term. EIGEN_L=π²R (Jeans length, `:349-358`).

## The video → tube mapping (the useful part)
Euclid's 5th postulate is a switch picking WHICH geometry you're in:
- **No parallels → spherical geometry** = everything on a 2D surface = our
  default `sin(n·φ)` sculpt = the hollow shell.
- **One parallel → flat geometry** = real 3D interior with depth = the
  cylindrical cavity eigenmode (has the `z` axis).
- **Many parallels → hyperbolic (Poincaré disk)** = a finite disk PACKED with
  graded structure everywhere, denser toward the rim = the inverse of our bug.

Three actionable ideas:
1. **We're in the wrong geometry.** Sphere-surface sculpt = surface-only by
   construction. The cavity eigenmode is the flat-geometry version WITH depth,
   already wired.
2. **Geodesics = the "interconnectivity" Jamal wants.** Video defines straight
   lines as geodesics threading ACROSS the space connecting points. Our webbing
   (`:1878`) is trying to be that with an arbitrary constant. Principled version:
   draw nodal structure as geodesics of the cavity metric — curves through the
   interior, not dots on a shell.
3. **The tube should be a METRIC, not a hard wall.** Tube = hard clamp
   `rho < EIGEN_R` (`:1787`). Hard wall is WHY particles pile on the wall.
   "Relationships not objects": define the tube by radius-varying curvature
   (soft potential) → interior gains intrinsic depth (Poincaré-disk picture).

## NEXT ACTION — the one experiment (free, already wired)
Before building anything geodesic/hyperbolic, run the already-wired A/B that
tests idea #1 directly:

```bash
cd "/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE"
bash package_macos.sh                       # NEVER bare make — see CLAUDE.md
# verify bundle >= source BEFORE launching:
stat -f "%Sm %N" SpaceSynth.app/Contents/MacOS/SpaceSynth \
                 SpaceSynth.app/Contents/Resources/default.metallib \
                 src/render/particles.metal
pkill -f SpaceSynth
SS_EIGENMODE=1 open -n SpaceSynth.app       # env var must reach the app
```
⚠️ `open -n` may not pass the env var into the bundle — if EIGENMODE doesn't
print "[EIGENMODE] ON (bit23)", launch the binary directly:
`SS_EIGENMODE=1 SpaceSynth.app/Contents/MacOS/SpaceSynth` (verify this path runs
with bundle resources; check main.cpp:2014-2016 for the confirmation printf).

**What to look for:** does the hollow shell fill in with axial nodal planes —
structure at different DEPTHS inside the tube?
- YES → video's diagnosis confirmed. Path: make the eigenmode the default, then
  layer geodesic webbing on top.
- STILL HOLLOW → loophole is the Gor'kov-to-surface collapse (`:1809`); go after
  that next (particles trap on the Ψ=0 surface regardless of k_z).

Let Jamal's eyes call it. Let the sim run FULL (minutes, not a 25-50s capture) —
see [[feedback_let_the_sim_run_full]]. I change, HE plays — build + open, then
STOP; never drive synthetic MIDI for a verdict — [[feedback_i_change_he_plays]].

## Protocol reminders for this work
- ONE verifiable change → confirm it landed → say what to look at → STOP.
- Stale-binary FIRST if a change "does nothing" (bundle vs source timestamps).
- Commit ONLY on explicit order — [[feedback_commit_only_on_explicit_order]].
- A toggle is not a fix — [[feedback_a_toggle_is_not_a_fix]]. SS_EIGENMODE is a
  DIAGNOSTIC A/B, not a solution; name the mechanism it reveals.
