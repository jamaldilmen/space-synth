# SPACE SYNTH — handoff 2026-09-01 (OPUS window) · written 2026-09-02 09:42:11

> **His verdict on this state:** *"the bh is still ass what ar eueven saying thter sno stable rings no .. dont make me send these two nasa pcitures gaian. we are spinnin gin circles. where are we at brief me. check in with windows report no sugarcoating."* — 2026-09-01 15:24:00
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` **§AA** — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `06982a0`
**Build + launch:** `bash package_macos.sh` then `SS_FULLSCREEN=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth` — ⛔ never bare `make`
**Scope of this window:** investigation only. **I wrote zero source lines.** Every source change in the tree on this date is FABLE's, committed under FABLE's own handoff.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | Plane split: physics vs renderer disagreed | "physics is XZ about +Y, renderer XY about +Z" | **Matter is in XY, normal +Z, tilt ≤ 7.9°.** Renderer is right; SPAWN is +Z too | `main.cpp:3057-3062`, `particles.cpp:151-165,:258-262` | `[MEASURED n=15 probes]` `[DISKZ]` H/R 0.10–0.25 in disk shells, 0.69 in halo |
| 2 | Which sites are the orphans | "four +Y sites in particles.metal" | **Three executable mechanisms**; `:2371`/`:1210` are comments. Only `:2380` is convicted; `:3294` play-only and UNTESTED; `:1217` plausibly never fires | `particles.metal:2380`, `:1217-1219`, `:3294-3296` | `[READ]` gates re-read at each site |
| 3 | Doppler beaming believed tunable | "tune the beaming constants" | **Identically zero at the default camera** — `vOrbit·toCam ∝ xy − xy = 0`, exact for every particle | `render.metal:1444-1454`, `camera.h:126,192-194` | `[READ]` + closed-form algebra |
| 4 | `reduceCellMax` cost shape unknown | "dispatches every frame" | **Once per SUBSTEP** — 60.6 ± 0.3 steps/s pinned to the wall clock, fps-independent; 1.27e8 cell reads/s; ~99.6% discarded | `renderer.mm:2436`, `:3413`, `:4137` | `[MEASURED n=300 windows]` from `[PERF] n=240 steps=NNN` |
| 5 | `bestCid` / `bhPeakCount` liveness | unknown | `bestCid` **dead** (no reader tree-wide); `bhPeakCount` **live**, reader 240-gated. Pass is **pure** — no other consumer of `cellMaxPartialsBuffer` | `renderer.mm:4142-4146`, `:3995`, `spatial_hash.metal:1139` | `[READ]` tree-wide grep incl. docs/, shaders/, tools/ |
| 6 | What flattens the disk | assumed to be the relaxation block | **Chandrasekhar dynamical friction** — isotropic drag on `vpec`, no directional exemption. Relaxation `:2380` does the OPPOSITE of its comment | `particles.metal:2118-2136` | `[MEASURED n=15]` selection ruled out at r≈8 + `[READ]` elimination of all other `shiftV` sites |
| 7 | "There are no rings" | taken as absence | **A ring FORMS and does not PERSIST** — 18× radial rise at t≈3 min, gone by t=300 s; annulus at r≈8 holds n≈195 for 15 probes | — | `[MEASURED]` BRAIN's radial profile + `[DISKZ]` |

## 2. 🚨 OPEN — his list, verbatim

1. **"the bh is still ass ... thter sno stable rings"** — 2026-09-01 15:24:00
   `MEASURE:` orbit the camera to `phi ≈ 80-85°` (theta stays π/2) and look. Zero build.
   State: `[READ]` the NASA reference look is EDGE-ON and our camera sits **on the disk axis** — a face-on thin disk cannot make that picture at any physics quality. `[READ particles.cpp:146-150]` the 2026-07-16 plate alignment moved the disk to XY on purpose and **paid the Gargantua look and the beaming for it; that cost is written nowhere.** `[HYPOTHESIS]` — **no inclined frame has been looked at by anyone.** Expect it SIDEWAYS (vertical band): `refUp` is world +Y, disk normal is +Z.

2. **The ring drains.** Formation is fine; persistence is not.
   `MEASURE:` re-run the t≈3 min radial profile after any change to the two-era compression.
   State: `[READ]` the drain levers are `fRelax` ×0.1 disk-era (`particles.metal:2133`) and `lam` ×0.02 (`:2219`). `[MEASURED]` inner shells drain (r≈2: n 84→26) while r≈8 holds — so it is radius-dependent, not global.

3. **Disk thickness has a dial nobody has named.**
   `MEASURE:` `bhToggles` A/B on the friction term — needs a build.
   State: `[READ]` `coef` at `particles.metal:2124-2131` + disk-era ×0.1 at `:2133`. `[HYPOTHESIS on magnitude]` observed e-fold ≈100 s, NOT measured per-star. ⚠️ Its gate is `gravSupport < 0.999f`, so it **runs during play too**.

4. **`particles.metal:3294` is UNTESTED, not innocent.** Play-only; every measurement to date is REST-only.
   `MEASURE:` he plays a sustained passage for ~2 min, `[DISKZ]` runs on its own cadence. Needs him at the keys.

5. **`reduceCellMax` fix is RULED and QUEUED, not built.** `[HIS WORDS 2026-09-01 14:31]` *"2 and 3 after fable's change lands."* Options 2+3 = match the reader's cadence + delete dead `bestCid`. Option 1 rejected.

6. **The −0.181 outer-field limb asymmetry is UNATTRIBUTED.** Proven NOT beaming; grows with aperture (−0.055 → −0.187) so it lives outside the disk. Unclaimed.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Second-moment `sx/sy` on a full-screen grab — REJECTED 2026-09-01 13:50:00.** A distribution that fills a W×H frame measures the **frame's** aspect ratio (3024×1964 = 1.540), not the structure's. It produced a fabricated "52.2° inclination, a third plane". Centroid-centred square boxes then produced a fabricated "6.55, very band-like". **Both were the box, not the physics.** What replaced it: circular apertures (a circle imposes aspect 1.000) and radial/azimuthal profiles about the centroid. Its honest limit: projection cannot see through the pose rotation at all — only the world-space `[DISKZ]` instrument settled it.
- **Tuning the Doppler beaming constants against a face-on frame — REJECTED 2026-09-01 14:05:00.** The term is *identically* zero on-axis; there is nothing to tune. The crescent is a **camera position**. (Also on the record: the 2026-08-14 `g³` attempts, both reverted — a 41× intra-frame range cannot be carried by an additive point cloud with no opacity floor.)
- **Amplitude-gating `reduceCellMax` (option 1) — REJECTED 2026-09-01 14:31:00** on the `seed_apply` precedent at `renderer.mm:3540-3547`: that exact gate was reverted 2026-08-04 22:46:41 because the pass was needed during play. The nine rest-gated siblings feed BH physics; this one feeds a log line, so it does not inherit their justification.
- **A fifth GPU timing bracket — NOT ATTEMPTED, per §Z7.** Four instruments returned impossible negatives. This session reports dispatch **volume** as measured and per-dispatch **cost as UNMEASURED**, and did not estimate.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT_PLACEHOLDER
```

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "15 probes from the live run", stated to FABLE and BRAIN as if that were the whole log | The log holds **2312** `[DISKZ]` blocks; I had read the first 15. The trend I quoted is real **but is that window only** — later probes show the field drained to n=1–3 per shell. The flattening conclusion stands for probes 1–15 at r≈8; it is not a whole-run claim, and I did not say so at the time. |
| — | No other claim from this window was retracted. BRAIN's `sx/sy = 1.586` / "52.2° third plane" and the "central crop 6.55" were **BRAIN's, and BRAIN retracted them** before I acted on either; I had independently reached the same frame-aspect diagnosis from `measure.py` and did not repeat them onward. |

---

**Last Updated:** 2026-09-02 09:42:11
**Folded into board:** `docs/BOARD_BLACKHOLE.md` §AA @ 2026-09-02 09:40:33
