# NOTES — Space Synth session lessons

One lesson per entry, newest on top. Corrections and confirmed approaches alike.

---

## Play-stack rationalization sweep — sculpt is the law; swirl+breathing were fakes (2026-07-09 14:33:20)
Measured each live play force's contribution by gating it (SS_PLAY_SKIP) under
identical MIDI input and comparing the sculpted shape (σ + screenshot).
Findings: **sculpt** (Atom-Model gradient) is the ONLY structural law — remove
it and the pattern fragments (chord σz 12→6.7, visual breaks). **swirl**
(Biot-Savart) and **breathing** (radial Y·12) had ZERO shape effect (visual +
σ identical off) → DELETED 2026-07-09, shape confirmed unchanged after removal.
**web** (chord webbing) genuinely binds escapers (σz 12→18, streaks when off) —
kept. **impulse** is transient/onset only (invisible in sustain) + already
clamped — a held-note test can't judge it. **jitter** ambiguous, low stakes.
Also learned: the brief's "~12 forces" was half dead already (elastic shell +
VJ azimuthal are `if(false)`; inertia-mix, SPH-pressure, self-gravity, home-pin
all inert during play via playGate). σ has ±5 run-to-run noise → the VISUAL is
the real tiebreaker, not the numbers.

## Measurement rig for the play stack — MIDI + window screenshot, NO mic (2026-07-09 14:33:20)
The brief's afplay→mic drift-hunt does NOT work in this setup (built-in mic
doesn't reliably pick up afplay; his keys work fine). The real reproducible rig:
(1) app listens on **IAC Driver Bus 1** — send MIDI note-ons there via a tiny
swiftc CoreMIDI sender (`scratchpad/midinote` — hold/pat/arp modes). No mic, no
replaying, real input path. (2) Launch the binary DIRECTLY with `SS_PLAY_SKIP=…`
env (MIDI needs no TCC/mic permission, unlike the app's mic). (3) Screenshot the
window: `winid` (CGWindowList) → `screencapture -x -o -l<id>`. Needs Terminal to
have BOTH Accessibility (for osascript keystrokes) AND Screen Recording perms —
screencapture picks up Screen Recording without a Terminal restart. (4) Hide the
TAB overlay + turn 90° right (to see the elongated shape's length) via osascript
`key code 48` then `key code 124`. [SHAPE]/[VEL] probe prints every 240 frames
(~4.4s) → use ≥14s holds to catch the shape evolving. Tools in scratchpad.

---

## Verify the tree against the brief — brief characterizations can be stale (2026-07-09 01:45:41)
The session brief said step-zero should strip `SS_SPH_*` and `[CLOSURE]` probes
alongside `SS_RENDER_*`. Grep proved `SS_SPH_*`/`[CLOSURE]` are *already-committed*
cross-file instrumentation (spatial_hash.metal buffer(9), particles.metal
buffer(17), renderer.mm ledger), not part of the dirty tree — spatial_hash.metal
had zero working-tree changes. Only `SS_RENDER_*` + `kTinyPoints/kMinimalVS` were
uncommitted. Likewise the brief said app_state.h held seed-feeding bit2 WIP; the
actual diff was a `uiExposure` field (bit2 was committed in `66639a4`).
**Lesson:** read the real diffs before acting on a brief's file-by-file claims.
Jamal ruled: leave SS_SPH/[CLOSURE] committed for now (separate, riskier removal).

## Metal function_constant: decl and all usages must be removed in ONE step (2026-07-09 01:45:41)
Removing the `constant bool kMinimalVS [[function_constant(1)]]` declaration before
removing the `if(kMinimalVS){…}` usage left render.metal in a non-compiling
intermediate state. Don't leave a shader mid-strip. Remove decl + every usage +
the host-side FunctionConstantValues plumbing (renderer.mm) together, then build.

## Isolate a WIP subset from a dirty file via `git apply --cached` hunk-select (2026-07-09 01:45:41)
To split one file's changes across commits without interactive `git add -p`
(blocked here), a small python hunk-selector (`git diff <file>` → keep hunks whose
body contains a marker string → emit patch with git's own headers) + `git apply
--cached --check` then apply is reliable. Used it to isolate the sphU temp-bridge
(parallel-session WIP) into its own commit `833be93`.
