# HANDOFF — 2026-08-12 22:26:00 · the accretion bound works, and it shipped broken first

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube` · branch `kill-the-tube-2026-08-11` · base `13ac249`
**Bundle:** `SpaceSynth.app` @ **2026-08-12 21:59:34**, newer than every source. **Nothing is committed, anywhere.**
**Reference of truth is `docs/BOARD.md`** — rows A1′-endgame, A1″, A1‴ carry all of this with `file:line`.
**He has not looked at any of it.** Every result below is log-verified only.

---

## 1. THE HEADLINE

**An idle run now parks at `Biggest body` = 101,799.9 M☉ and stays there.**

| | |
|---|---|
| bound | `F_BH_CLUSTER (0.17188) × 594,276` = **102,144.2** |
| reached | **101,799.9 = 99.66%**, flat over the last 5 samples |
| stars eaten | `live` 1,999,988 → 1,542,567 = **457,421** |
| mass drift | `Mlive` 594,276 → 594,205 = **−71 M☉ (−0.012%)** |
| run | 22:00:57 → 22:09:01, clean: **0 amplitude bursts, 0 key events** |
| log | `/tmp/killtube_bound2fix.log` |

The growth curve is smooth across the whole range — **no doubling steps**, so this is genuine
accretion, not merges. The field survives an idle passage for the first time. A 40–60 minute set
no longer ends on an empty screen.

---

## 2. IT SHIPPED BROKEN FIRST, AND THAT IS THE USEFUL PART

The 2026-08-11 version computed the ceiling as `F_BH_CLUSTER * u.massTotal`.

**`u.massTotal` is the GRAVITY anchor, not the mass books.** It carries the Size slider's
`massScale` (`renderer.mm`, `massScale = (Size/2)^1.25`), and at the default Size = 2 it reads
**189,044 against a real field of 594,276 — a 3.14× under-read.**

- effective ceiling was **32,495**
- a 16.5-minute idle run **stalled dead at 32,383.8 = 99.66% of it**, flat for 10.6 minutes
- `live` moved 60 particles in those ten minutes

**Fix:** a new uniform `fieldMassMsun` (unscaled Σ stellar mass) appended at offset 164 to both
struct mirrors per **A0h**, assigned in `renderer.mm` beside `massTotal`, consumed at
`particles.metal:1387`.

⭐ **RULE: `massTotal` is the gravity anchor. Anything that is a mass BUDGET reads
`fieldMassMsun`.** Both call sites now carry that sentence in a comment.

---

## 3. HOW IT WAS FOUND — AND WHY MY FIRST THREE DIAGNOSES WERE ALL WRONG

A temporary per-frame counter on the capture gate (**removed again**, it existed only for this)
gave the answer in one line, at the stall:

```
inBlock=1,754,040  sawSeed=932,724  seedOK=932,724  inRad=916,781  noBudg=916,781  eaten=0
```

**916,781 stars inside the capture radius, every frame. All 916,781 refused by the budget CAS.**
The hole was starving inside a full larder and the thing starving it was my own bound.

🚨 **THREE CLAIMS OF MINE ARE RETRACTED. Do not quote them back:**

| I said | Truth |
|---|---|
| "the bound never engages, it's dead weight" | it was **the** binding constraint all evening |
| "capture delivers ~0.1 M☉/frame, 200× less than growth" | **20–88 stars/frame** during growth |
| "the hole is out of fuel / the matter is out of reach" | the larder was **916,781 stars** deep |

**All three came from reading `feed=` in `[GRAV]`.** That field is a **one-frame sample of a buffer
cleared every frame** — it reports the rare frames where a meal happened to land and says nothing
about the others. I had warned about exactly this trap two messages before walking into it.
⭐ **A per-frame-cleared buffer sampled every 6 s is not a measurement. Count the funnel instead.**

**Also superseded: the 84,592 endpoint** from 2026-08-11. That number came from two seed↔seed jumps
(+33,849, +13,581), each landing exactly on a `seeds` N→1 collapse. **The honest bound-limited
endpoint is ~101,800.**

---

## 4. STILL OPEN, IN ORDER

### 4.1 🚨 A1″ — the seed↔seed merge walks through the bound. **Measured, unfixed.**
`particles.metal:1481` adds to the budget plate with a plain `atomic_fetch_add` — no CAS, no taper —
while the star path claims via compare-exchange at `:1398`. **Caught live:** one frame after a million
stars were refused, `Mmax` went **32,383.6 → 64,767.2, exactly 2×**. Two equal seeds merging, straight
past the ceiling.
Second-order effect nobody costed: it writes the same word the capture CAS reads, so **a merge starves
the budgeted path for the rest of that frame.**
**Fix is the same shape as the capture path** — route `:1481` through the CAS. Refusing the merge leaves
the victim alive and orbiting, so mass stays conserved exactly and it merges later.

### 4.2 A1‴ — the orphan-deposit sweep is shipped and **unproven**
`seed_apply` no longer discards a dead slot's plate; the lowest-index live slot sweeps it (mass +
momentum + KE). **No run since has reproduced the 26-seed cascade** — the clean runs held `seeds` at
1–3, so the chain path was never exercised. `Mlive` −71 over 457,421 eaten is consistent, not proof.
🚨 The first version swept to the *biggest* live seed, which is a **mass-creation race** (every thread
scans while every thread writes `posW.w`). Aliveness is stable under those writes; a mass **ordering**
is not. Do not reintroduce a max-scan there.

### 4.3 The automatic transmission — untouched, both halves still exist
Gear stick `uiPhysicsSubsteps` 1–32 at `renderer.mm:2811`; tachometer computing the required substeps
at `particles.metal:1962-1968` and throwing the number away. Nothing joins them.

---

## 5. METHOD NOTES EARNED TODAY

1. **A per-frame-cleared buffer sampled periodically is not evidence** (§3). It cost three wrong
   diagnoses in one evening.
2. **`&&` chains silently skip the build.** `grep -c` returning 0 exits non-zero, so
   `grep … && package_macos.sh` left the OLD bundle in place while reporting nothing wrong.
   Caught only by the timestamp check. **Always stat the bundle after building.**
3. **Do not touch system audio.** I muted the system mic input to keep a run silent, on the
   assumption that live input was driving the amplitude bursts. It wasn't — `[MIDI] IAC Driver Bus 1`
   and 387 `[KEY]` events were. Wrong input, and I told him after starting rather than before.
   His instruction: **no mic touching.** Restored to 100, verified.
4. **The tick counter in these logs is not seconds.** The FPS line prints twice per tick (~2/s), so
   `t=` in any awk over `biggest body` runs at 2× real time unless divided.
5. **Instrumentation added to chase a mistake gets removed with the mistake.** His call, and right —
   the gate counter is gone, verified absent from both the source and the log.

---

## 6. WHAT TO DO FIRST WHEN HE IS BACK

**Look at it.** 101,800 is log-verified and nobody has seen the screen. A hole holding 17.1% of the
field over a living 1.5M-star field is a different picture from four objects on black, and the whole
point of the bound was what it looks like during a set.

Then **A1″** (§4.1) — one change, same shape as a CAS that already exists, and it closes the last path
that can still eat the field without asking.
