# HANDOFF 2026-08-04 — MASS CONSERVATION RESTORED; THE HORIZON IS MEASURED IN THE WRONG PLACE

**Written:** 2026-08-04 21:34:05
**Session:** 2026-08-03 06:25:00 → 2026-08-04 21:34:05
**Baseline:** `b047744` — **NOTHING IS COMMITTED.** Everything below is uncommitted working-tree
state plus untracked docs and `src/render/grade_lut.h`. Do not commit without an explicit order.
**App:** not running at write time. Bundle binary + metallib = **2026-08-04 00:07:45**, newer than
every source. Launch it, do not rebuild first.

Cold start for the previous session: `HANDOFF_2026-08-03_bh_lifecycle.md`. That doc is still correct
except where §5 below corrects it. The cinematic/optics track still lives in
`HANDOFF_2026-08-02_cinematic_visual_overhaul.md`.

---

## 0. WHAT HE VERDICTED, IN HIS WORDS

| Thing | Verdict | Timestamp |
|---|---|---|
| Sustain rebirth (§3 of the 08-03 doc) | **STILL NEVER SEEN. NO VERDICT.** | — |
| Formation ramp | **STILL NO VERDICT** — live, measured, never judged by eye | — |
| The snap-back after release | ❌ *"it kinda snaps back after play right into black hole mode"* | 2026-08-03 ~19:40 |
| The collapse look | ❌ *"collapses into these weird 2d lines of light not actual seeds and merges"* | 2026-08-03 21:31 |
| Multi-BH | ❓ *"PLS CHECK IF WERE CURRENTLY STILL UP FOR MULTIPLE BLACK HOLES TO FORM"* — answered §4 | 2026-08-03 21:31 |
| The fake pull | ❌ must not exist at start; *"only ... once multiple bodies of a lot of mass have already formed"* | 2026-08-04 ~00:00 |
| Gate design | ✅ chose **both conditions, exposed as dials** | 2026-08-04 ~00:02 |
| Order of work | ✅ *"1 then 2"* — conservation first, then the horizon | 2026-08-04 ~00:06 |

---

## 1. ✅ FIXED — MASS WAS BEING CREATED FROM NOTHING

Two stages, because the first fix was real but incomplete.

**Stage 1 (2026-08-03 19:42:59) — the `1.0f` mint.** `particles.metal`, the rest-recycle branch
revived a dead particle at `mass = 1.0f` against an IMF field whose mean spawn mass is 0.29 M☉. With
`REST_RECYCLE = 0.005`/frame over a dead pile of ~920k that is ~4,600 M☉ created **per frame**. It
was a closed pump: revive at 1.0 → eaten by the seed → parked at mass 0 → revived at 1.0. Harmless
for as long as bit6 defaulted OFF; it went live the moment bit6 flipped default-ON for sustain
rebirth (08-03 §4). Measured before the fix: `Mlive` 594,268 → **2,494,898**, with **1,441,070 M☉ in
one body** — 2.4× the entire original field. Changed to `REBIRTH_MASS` (0.01), the constant already
derived for the sustain path. That cut the rate 100× and his HUD confirmed the field back at
`5.94e+05`.

**Stage 2 (2026-08-04 00:07:15) — the path itself.** A 5.5-minute rest soak showed the leak was
slowed, not closed: `Mlive` 594,563 → **664,608, +11.8%** (~12.7k M☉/min) with nothing touched.
`streamNow` cannot fire outside sustain (`envelopePhase ∈ [2.5, 3.5)`) and the soak ran at
`phase=0.0` throughout, so **100% of that came through `trickleRest`**.

The deeper point: **reviving a corpse always creates mass.** Its mass was handed to the seed that ate
it and is deliberately never refunded (the 2026-06-22 lesson — refunding destroys the accretion
engine). So any revive mass is new mass, and no constant makes that false. `trickleRest` also had
**no envelope gate at all** despite its own comment calling it the at-rest path, and it had never
been default-on before bit6 flipped — it rode in as collateral. He asked for sustain rebirth, not
this. **Cut from the bit6 condition entirely; the rest branch is deleted.** Sustain rebirth is
untouched. `REST_RECYCLE` is kept as the record of the old rate and is deliberately unreferenced.

**Verified, same 5.5-min untouched soak, like for like:**

```
before:  594,563 → 664,608   +11.8%   (+70,045 Msun)
after:   594,273 → 593,993   -0.047%  (-280 Msun)
```

The residual −280 M☉ is mass *leaving* (wall/park exclusion), four orders of magnitude below what it
replaced. Called conserved. Chasing the −280 is its own thread.

⚠️ **Why this mattered beyond itself:** `share`, `encFrac` and `seedTarget` are all ratios against
`Mlive`. While it inflated 11.8% per five minutes, every one of those was measured against a moving
denominator. No threshold derived before 00:07:15 is trustworthy.

---

## 2. ✅ BUILT — THE PULL-GATE MEASUREMENT (step 1 of 2; step 2 is BLOCKED)

He specified the fake pull must switch on only "once multiple bodies of a lot of mass have already
formed and a lot of all particles is about to collapse", and chose **both conditions as dials**.

Rather than pick two thresholds out of the air, step 1 measures both terms first. Added
`sumSeedMass` — Σ mass of bodies with `m ≥ M_BH_SEED` — into the reduce's old `pad3` slot
(`particles.metal` `PartialStats` + the mirror struct in `renderer.mm`; **these two must stay in
lockstep or every field after it misreads**). No new buffer, no new dispatch. Logged as `[PULLGATE]`
alongside `[BH-POP]`, every 120 frames.

Sanity-checked live: `biggest ≤ seedM ≤ Mlive`, and the printed share equals the hand division.
`nReg` and `nProbe` agree, which also resolves the standing ambiguity about whether the registry
count lives at index [0] or [4] — they return the same number.

**The measured curve (rest, untouched, post-conservation-fix):**

```
share=0.0254  biggest=13658   nReg=4
share=0.1507  biggest=86335   nReg=5
share=0.2168  biggest=123772  nReg=6
share=0.4620  biggest=267236  nReg=5
share=0.7594  biggest=445712  nReg=5
share=0.8960  biggest=531808  nReg=4
share=0.9207  biggest=546763  nReg=1   <- plateau
```

🚨 **`bigShare` shadows `share` at every single sample.** At share 0.15 the biggest body is 96.4% of
all seed mass; at 0.92 it is 99.98%. The peak `nReg=6` is one real lump plus five stragglers
averaging ~1,000 M☉ against a 123,772 M☉ body.

**"Multiple bodies of a lot of mass" is a state this sim never enters.** Step 2 cannot be built as
specified: condition (a) can never fire, because the origin-pin he wants to gate is precisely what
prevents multiple massive bodies from coexisting. The gate is circular. **Step 2 is blocked on §4.**

---

## 3. ⭐ THE SCIENCE — THE HOLE IS REAL; IT IS BEING MEASURED IN THE WRONG PLACE

`units.h` states the criterion: `r_s(M) = 2GM/c²`, and mass M inside radius R **is** a black hole
when `r_s(M) ≥ R`. `kRsSimPerMsun ≈ 1.6827e-6`.

- Whole field, 594,280 M☉ → **r_s = 1.000 sim units** (the "1.0" in units.h's own comment)
- The seed, 546,750 M☉ → **r_s = 0.920 sim units**

That mass is held in **one particle** — a point. All of it is inside 0.92 by a mile. **The black hole
is real and has been real.** The horizon is 0.92 sim across, resolved by ~47 radial shells
(`dr = RADIAL_MAX_R/RADIAL_SHELLS = 5/256 = 0.0195`). Not marginal.

**Three independent measurement faults hide it:**

**3a. The profile is centred on the origin; the body is not there.** `reduce_stats` bins mass by
distance from `(u.bhX, u.bhY, u.bhZ)`, which reads `bh=(0.00 0.00 0.00)` on every frame of both
soaks — hard-locked. The seed meanwhile wanders: r ≈ 0.957 → 1.211 → 1.504 and climbing in one run,
r ≈ 4.9 in the other. Centre the test on the body and any radius below 0.92 gives a ratio above 1.
Centre it on the origin and you get 0.13.

**3b. `RADIAL_MAX_R = 5.0` is a hard cutoff, and the seed crosses it.** This is the actual cause of
`rs/r = 0.000`. From the pre-fix log, consecutive `[CORE]` samples:

```
Mtot(<5)=2.938e+01                              <- seed outside the window
Mtot(<5)=6.787e+05  peakShell r=4.902 m=6.78e5  <- seed at r=4.9, just inside
Mtot(<5)=4.164e+02                              <- outside again
```

Inside, the profile holds 678,000 M☉ in one shell. Outside, it is empty and the ratio is exactly
zero. Not a blind scan — a body drifting out of a fixed measuring window.

**3c. `seedTarget` divides by a fixed 0.5 regardless of where the mass is** (`renderer.mm`,
`kRsSimPerMsun * bhSeedMass / kREnc`). It asks "would this be a hole *if* it were inside 0.5?" At the
moment it claimed a horizon for 678k M☉, `[CORE] M(<0.5) = 0.28 M☉` — there was essentially nothing
inside 0.5. It is unclamped and monotone, so it pins `bhStrength` above every `>0.5` gate
(raytracer, doubled instancing, lens ramp) with no honest horizon behind it. **`rs/r` is the honest
number; `seedTarget` is the fiction.** Prime suspect for his "weird 2d lines of light" — the BH
render fully on with nothing real behind it — though the specific flat-sheet shape is NOT yet proven.

**On the origin-pin, physically:** it is unphysical. A black hole sits where the dynamics put it.
What is conserved is the system's centre of mass and total momentum, not a coordinate. Pinning a
546,750 M☉ body to (0,0,0) injects momentum from nowhere. The COM is already at `(0.01, 0.00, 0.10)`
— near the origin *naturally*, without being forced.

---

## 4. ❌ ANSWERED — MULTIPLE BLACK HOLES CANNOT FORM

Three structural blocks, all present in the current tree:

1. **`renderer.mm` — `bhSeedMass = gMaxMass`.** A single max reduction over the whole field. Only the
   one most massive body in existence is ever the hole. Every other seed is just a heavy particle.
2. **`particles.metal:1153` — bit4 is an origin-pin** gated on `mass >= M_BH_SEED` (50 M☉, a couple
   of merged stars). Everything heavy is dragged to (0,0,0). Two seeds cannot stay apart long enough
   to *be* two holes.
3. **One BH position in the renderer** — `bhPosX/bhPosY/bhPosZ`, singular. No per-seed horizon, no
   second lens.

bit3 "seed-seed merge" is **not** BH+BH merging — its own comment (`particles.metal:1273`) says seeds
ate stars but never each other until that change. It merges *mass bodies*. He is right that it is not
what he remembers from weeks ago; **what that was has NOT been investigated** (offered a git-history
dig, no answer).

The physics permits what he wants: real clusters form several seeds that sink by dynamical friction
and merge hierarchically. Our code forbids it. **bit4 is the blocker for multi-BH AND for his pull
gate.**

---

## 5. 🚨 CORRECTIONS TO MY OWN CLAIMS THIS SESSION — DO NOT CARRY THESE FORWARD

- **"The radial profile scan is not seeing the seed" — WRONG.** It sees it fine:
  `[CORE] peakShell r=1.504 m=1.117e5` against `biggest=111,296`, and `rs/r=0.130` matches hand
  arithmetic (`1.6825e-6 × 131,100 / 1.504 = 0.147`). The real mechanism is §3b, the 5.0 cutoff.
- **"The mass pump is dead" — premature.** True only of the `1.0f` path. The residual path still leaked
  11.8% per 5.5 min at rest until stage 2. Do not declare a leak closed off a HUD glance; soak it.
- **Any threshold derived before 2026-08-04 00:07:15 is against a drifting denominator.** Discard.

---

## 6. OPEN, MEASURED, NOT ACTED ON

1. **Centre the horizon test on the mass, not the origin** (§3a) — the one I would do next; it is the
   root of the flicker, the fake `bhStrength`, and probably the 2D sheets.
2. `seedTarget`'s fixed 0.5 denominator (§3c).
3. `RADIAL_MAX_R = 5.0` blind spot (§3b).
4. bit4 origin-pin (§4) — blocks multi-BH and the pull gate.
5. Pull-gate step 2 — blocked on 4.
6. The −280 M☉ residual drift.
7. **"Start sequence / launch grid"** — he named these as needing fixing; I asked what he meant and
   **he did not answer**. The spawn is a galaxy disk (`particles.cpp:107`, disk/nucleus/halo,
   `R_DISK=18`), not a grid. **Ask before touching.**
8. **The tube** — `particles.metal:2886`, a cylindrical XY clamp at `ORBIT_R_CHLADNI` during
   attack/decay/sustain. His ask: *"get rid of the tube once and for all and figure out what the
   actual truest form of soundwaves in 3d space is."* The clamp is a cylinder **because** the play
   kernel is built on Bessel `J_m` — deleting the clamp does not do it; the eigenmode basis is the
   real work. Own session. Note `space_synth_neo_architecture` (3D scalar ψ, damped wave PDE) is his
   own prior design for exactly this.
9. Carried from 08-03, untouched: rick-and-morty eyes (§5 there — start from the name, my bit20
   theory is dead), the merger flash (temp baseline 5.29e11 makes a `+2.0` flash a 1e-11 relative
   change), field inflation, star size floor, `render.metal:485`.

---

## 7. STATE AT WRITE TIME

- **Not committed.** `b047744` + 10 modified files. Untracked: `src/render/grade_lut.h`, the docs.
- Bundle binary + metallib **2026-08-04 00:07:45** ≥ all sources. `bash package_macos.sh`, never bare
  `make`.
- App not running.
- **Launch hygiene, learned the hard way:** launching the raw binary
  (`./SpaceSynth.app/Contents/MacOS/SpaceSynth`) runs it with **no LaunchServices registration — no
  Dock icon, no window brought forward.** It logs happily and looks alive to `pgrep` while he sees
  nothing ("its not running lol"). Use:
  `open -n --stdout "$LOG" --stderr "$LOG" SpaceSynth.app` — proper launch *and* captured logs.
- One unexplained event: an instance exited on its own ~4s after launch, healthy (fps 33.9, 201 audio
  callbacks), no crash report. Did not reproduce. Logged, not explained.

## 8. NEXT, IN ORDER

1. **Show him sustain rebirth.** Built 08-03, still never seen. Hold a note over a formed hole.
2. **Centre the horizon test on the mass** (§3a / §6.1).
3. His call after that: bit4 (§4, unblocks both multi-BH and the pull gate) or `seedTarget` (§3c).

🚨 **Berlin New Media Week is 2026-09-02 — 29 days from this writing.** His standing order from
2026-08-02 is that the ONLY goal is IMAX/planetarium optics, with perf work deferred. This entire
session was physics. That was the right call — the mass leak was corrupting every ratio downstream —
but **nothing on the cinematic track has moved in two days.** His call, not mine.

**Last Updated:** 2026-08-04 21:34:05
