# HANDOFF 2026-08-03 — THE BLACK-HOLE LIFECYCLE: DESTRUCTION, FORMATION, REBIRTH

**Written:** 2026-08-03 06:23:45
**Session:** 2026-08-03 04:29:24 → 06:23:45
**Baseline:** `b047744` — **NOTHING IS COMMITTED.** Everything below is uncommitted working-tree
state plus two untracked files (`src/render/grade_lut.h`, this doc). Do not commit without an
explicit order.
**App:** not running at write time. Bundle binary + metallib = **2026-08-03 05:14:04**, newer than
every source. Launch it, do not rebuild first.

Supersedes nothing. Read alongside `HANDOFF_2026-08-02_cinematic_visual_overhaul.md`, which owns the
cinematic/optics track and is still the cold start for that work.

---

## 0. WHAT HE VERDICTED, IN HIS WORDS

| Thing | Verdict | Timestamp |
|---|---|---|
| Grade LUT (built 08-02 night, unseen until now) | ✅ "this is really nice actually i like it a lot" | 2026-08-03 04:34:56 |
| Reset no longer leaves a phantom hole | ✅ "yeah that works" | ~2026-08-03 04:50 |
| bit2 seed capture + bit3 seed-seed merge, A/B'd live by him | ✅ "the other two levers gave it a better look though so thats nice" | ~2026-08-03 05:05 |
| My claim that bit20 differential rotation causes the stripes | ❌ **"the stripes take is shit"** | ~2026-08-03 05:05 |
| Formation ramp (transition no longer steps) | **NO VERDICT** — built and live, he moved on before judging | — |
| SUSTAIN REBIRTH | **NO VERDICT — NEVER SEEN** | — |

---

## 1. ✅ FIXED — "BH FORMED" SURVIVED THE HOLE BEING DESTROYED

His report: the formed state persisted after the black hole was destroyed, and *"it breaks all
physics"*, explicitly **not** a HUD-only bug. He was right on both counts.

**Two links, both required:**

**1. Reset never destroyed anything but positions.** `triggerReset()` sets debugFlags bit 8; that
block (`particles.metal`, the Snap-Back re-seed) wrote **only position and velocity**. Mass lives in
`posW.w` and was untouched, so the accreted seed — one body holding 3–5×10⁵ M☉ of swallowed stars —
survived every reset, and every eaten particle stayed parked at mass 0. The sim was then *correct*
to keep reporting a hole: `r_h = kRsSimPerMsun · M_seed ≈ 0.82` stayed > 0. That is the physics
breakage — `physicsUniforms.horizonR` keeps the ONE-WAY MEMBRANE alive
(`spatial_hash.metal:842-846`, SPH causally dead inside r_h) and a phantom half-million-solar-mass
point dominates the re-scattered field.

**2. The un-form condition was unreachable by construction** (`renderer.mm`, the old
`bhMassEnc < 0.01·massTotal && gMaxMass < 50`). `gMaxMass` is **monotone** — mass is conserved into
the seed and the seed only eats — so once a merger product passes 50 M☉ it never returns below it.
And `bhMassEnc` is the mass within R_ENC=0.5 of the origin, a few percent for *any* centrally
concentrated cluster (~2% even at a perfect respawn), never under 1%. **The latch could only ever be
set, never cleared.**

**Fix:**
- `imfMassOfId(id)` — an exact MSL mirror of `core/imf.h::massOfId`, added to `particles.metal`. The
  spawn (`core/particles.cpp packForGPU`) writes `massOfId(i)` at buffer index i and particles never
  change slots (a merger parks the loser at its own index), so the thread id **is** the id that drew
  that mass. The spawn mass field is therefore recoverable at any time. Bit-8 reset now restores it:
  the seed drops to its own star's mass and every corpse comes back alive.
  ⚠️ **Change this hash and you must change `core/imf.h` identically** (see `physics_constants.h`).
- The latch is now the honest horizon: set when the criterion reaches 1, cleared when `lastHorizonR`
  returns to 0.

**Offline-verified before shipping** (`scratchpad/imf_check.cpp`): max spawn mass over 2M ids =
**49.9571 M☉**, under the 50 M☉ `M_BH_SEED` threshold, so after a reset nothing in the field reads
as a seed. Field total 594,268 M☉ — matches the sim's own `Mlive=594276`.

**Correct behaviour that is NOT a bug:** scatter the field by playing *without* resetting and it
still says FORMED. The seed body is still there, so the horizon is still there.

---

## 2. ✅ BUILT, NO VERDICT — THE FORMATION TRANSITION NO LONGER STEPS

His report: *"post bh naturally forming bhs are weird the transition has a super weird bug where it
just jumps to a weird stage"*.

**Root cause:** `honestTarget` was a **boolean** — `(lastHorizonR > 0) ? 1 : 0`. The frame the
innermost shell crossed the criterion it went 0 → 1, the latch pinned `bhStrength` to 1, and
everything keyed to it switched on in the same frame: the lens ramp (`smoothstep(0.2, 0.9, …)`), the
raytracer gate (>0.5), and the doubled particle instancing (>0.5). The sim was not entering a wrong
state — it was entering the *right* state instantly.

**Fix:** the criterion `r_s(M(<r))/r` is a continuous quantity; only the thresholding made it
binary. `lastHorizonRatio` = **sup over the 256-shell radial profile of `kRsSimPerMsun·M(<r)/r`**,
computed in the loop that already scans for the horizon, and it equals exactly 1 where the horizon
appears. This is not an invention: the 2026-06-13 canon already specified
`strength = r_s(M_enc)/R_ENC`; it was unusable only because it was pinned to the single fixed shell
at R_ENC=0.5, which needs 2.97e5 M☉ sitting there. Measured where it is actually largest, the same
formula is live and reachable.

**Measured live, ramping instead of snapping:**
```
[BH-POP] rs/r=0.139 encFrac=0.04 densTarget=0.00 -> bhStrength=0.08
[BH-POP] rs/r=0.553 encFrac=0.06 densTarget=0.00 -> bhStrength=0.49
[BH-POP] rs/r=0.706 encFrac=0.08 densTarget=0.00 -> bhStrength=0.66
[BH-POP] rs/r=4.681 encFrac=0.40 densTarget=0.00 -> bhStrength=1.00 LATCH
```
`[BH-POP]` now prints `rs/r` first — that is the new signal.

### 2b. The pre-BH readout was lying by 3.14×

`encFrac` divided by `physicsUniforms.massTotal` — the **Size-slider-scaled gravity anchor**
(`sMassTotal × massScale`, `massScale = (Size/2)^1.25`) — while its numerator `bhMassEnc` is a sum of
real `posW.w` masses. Measured live at Size 0.80 (`massScale = 0.318`): `105096 / 189044 = 56%`
"gathered", when the honest figure against Σ posW.w (594276) is **17.7%**. That 3.14× inflation fed
`densTarget` and the on-screen hole %.

**This is the same bug, on the same denominator, that was caught on 2026-07-18 02:38:40 for
`fieldMassMsun` and left behind here.** Now on `totalSM`. Everywhere else `massTotal` appears it is
the denominator of `gravGM/massTotal`, which cancels — this was the one place the absolute value
mattered. ⚠️ **If you find a third site using `massTotal` as an absolute mass, it is wrong.**

---

## 3. ✅ BUILT, NEVER SEEN — SUSTAIN REBIRTH (the newest thing; show him this first)

His ask, verbatim: *"i want that when i sustain a note the particles from within the black hole
respawn into the shape. this way we also finally solve the fucking invisible abyss of light here all
partile perpetually land in once eaten by a black hole"*.

He chose, from a two-option A/B:
- **Where:** straight into the shape (not pouring out of the hole).
- **Rate:** stream while held (not all at once).

**Implementation** (`particles.metal`, replacing the old bit6 resurrection block): the note-driven
revive is now **sustain-only** (`envelopePhase ∈ [2.5, 3.5)`) and its destination is the shape, not
the star-map home. A reborn particle samples a random **living** particle from `prevParticles` (the
previous-frame snapshot, so it never races this frame's writes), rejects the dead and the parked
(`mass > 0.001`, finite, `|pos| < 200` — park sits at 4000+), and is born beside it carrying the
host's per-frame velocity.

Why sampling a live particle rather than evaluating the mode: **the pattern is wherever the living
matter currently is.** This lands in the correct Chladni figure for any mode, chord or sculpt state,
and stays correct if the mode changes mid-hold, with no eigenmode evaluation in that block.

Three constants, each with a derivation (his standing test):
- **`SUSTAIN_REBIRTH = 0.0056`** (1/180) — 180 frames = 1.5 s at 120fps, so a normal hold feeds the
  shape for its whole length instead of dumping the pile in one frame. Short stab returns some, long
  drone returns all.
- **`REBIRTH_JITTER = 0.05`** — 5× the contact radius `MERGE_RSUN_SIM`. Any closer and `merge_stars`
  eats the newborn on the frame it appears, which would make the rebirth invisible *and* feed the
  seed it just escaped.
- **`REBIRTH_MASS = 0.01`** — 10× the `>0.001` alive gate so it renders and moves, below the IMF
  floor 0.08 so returned light can never pass as a star. **The eaten mass is NOT refunded** — it
  stays conserved in the seed that ate it, because refunding it destroys the accretion engine
  (the 2026-06-22 lesson recorded in that exact block).

**Expected side effects, both stated to him in advance:**
1. `[GRAV] Mlive` drifts up ~1.5% on a long hold (the returned light). Expected, not a leak.
2. bit6 also enables the pre-existing `REST_RECYCLE` trickle (dead matter drifting back to its
   star-map home at rest). That path is unchanged but had never been on by default. **If rest starts
   behaving differently, this is the suspect.**

**What to look at:** hold a note over a formed hole; the pattern should visibly thicken over ~1.5 s.
The dead pile was measured at ~46% of the field, so it should be obvious, not subtle.

---

## 4. DEFAULTS CHANGED THIS SESSION (`src/core/app_state.h`)

| bit | flag | was | now | why |
|---|---|---|---|---|
| 2 | `uiTogSeedCapture` | false | **true** | his live A/B, "better look". Its own comment already said bit2-off is **THE reason `feed=0` in every window** — `seedAccum` is written only by the bit2/bit3 paths. |
| 3 | `uiTogSeedMerge` | false | **true** | same A/B. Without it separately-grown seeds can never combine — measured **40 bodies over the 50 M☉ threshold at once**, unable to resolve into one hole or into a few real ones. |
| 6 | `uiTogResurrection` | false | **true** | required for §3; the feature cannot run without it. |

---

## 5. ❌ MY DIAGNOSIS HE REJECTED — DO NOT RE-PITCH IT

I claimed the "thousands of big stripes" during the merger era were bit20 (`uiTogAnalyticSpin`,
"Time-lapse orbit playback"): differential Keplerian rotation √(GM/r³) about a single origin-locked
centre, gated on `bhDiskGM > 0` which never returns to 0, therefore shearing every clump into
concentric arcs from the first hole onward, forever, at rest.

**His verdict: "the stripes take is shit. i called it rick and morty eyes back in the day".**

So the stripes are **"rick and morty eyes"** — an older, separately-named artifact with an unknown
mechanism, and it is **still open**. The bit20 mechanism above is real and correctly described, but
it is *not* what he is looking at. **Do not re-run that theory at him.** Start from the name: find
what "rick and morty eyes" referred to historically before proposing anything.

---

## 6. OPEN, MEASURED, NOT ACTED ON

### 6a. ⭐ The merger flash is arithmetically invisible — this is why there is no "iconic reaction"
His words: *"not like light imploding into a mighty powerful iconic reaction of cosmical appeal"*.

A merge sets `tNew = max(w.prevW.w, l.prevW.w) + 2.0 + 4·mergeViolence` — the NOVA FLASH. Measured
live field temperature: **avg 5.29e11, max 2.178e12** in the same units (the HUD's own ×3000 makes
that ~1.6e15 K, and the max is pinned identically across samples = saturated). A `+2.0` on a
baseline of `5.29e11` is a relative change of **1e-11**. The flash cannot be seen because the
baseline it is added to is eleven orders of magnitude too high.

This has its own root cause (why is the field at 5e11?) and deserves its own session. Note the
standing context: the 2026-06-13 physics audit already recorded temp/v as decorative.

### 6b. The field is inflating
`meanR` 49.61 → 54.45 over one soak, `maxR` pinned at exactly **100.0** (a clamp), and 82% of the
mass sits outside r=5 (`[CORE] Mtot(<5)=1.04e5` of 594k). Related to the known escaper fountain.

### 6c. Untouched from the previous handoff
Star size floor (§9 item 3) and the §10.3 warning sweep (32 warnings, 1 real at `render.metal:485`).
Performance work stays deferred until he lifts it.

---

## 7. STATE AT WRITE TIME

- **Not committed.** `b047744` + 10 modified files + untracked `src/render/grade_lut.h` and the docs.
- Bundle binary + metallib **2026-08-03 05:14:04** ≥ all sources. `bash package_macos.sh`, never
  bare `make`.
- App not running. Logs from this session are in the session scratchpad
  (`bh_reset_*.log`, `bh_ramp_*.log`, `rebirth_*.log`) — they will not survive; re-capture with
  `nohup ./SpaceSynth.app/Contents/MacOS/SpaceSynth > LOG 2>&1 &` if you need `[BH-POP]`/`[GRAV]`.

## 8. NEXT, IN ORDER

1. **Show him SUSTAIN REBIRTH (§3).** Built, never seen, no verdict. Hold a note over a formed hole.
2. Then his call: "rick and morty eyes" (§5 — start from the name, not from my rejected theory), or
   the temperature baseline (§6a, which is what kills the merger flash).
3. The formation ramp (§2) also has no verdict yet — it is live and measured, but he has not judged
   it by eye.

**Last Updated:** 2026-08-03 06:23:45
