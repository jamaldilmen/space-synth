# SPACE SYNTH — handoff 2026-09-05 15:28:30

> **His verdict on this state:** *"i see that the take i shsaking right now"* (~13:0x, take 6 at rho 5800,
> on the ALREADY-FIXED bundle) · *"8 and 9 look amazing no shakies all good"* (~13:0x) ·
> *"can we now safely re do th ebroken ones .. nonbhr0okenly ?"* (~12:4x) ·
> *"make the songs five minutes each not song slol the runs lol"* (~12:5x) ·
> *"the caveat must be written down in the bible why must i tell u this lol. your brain. u can handle
> some things bro i trust in u"* (12:47).
> **Cold start:** read `docs/SPACE_SYNTH_LIVE.md` then `docs/BOARD.md` §AA30 — NOT this file.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `641aa8f`
**Build + launch:**
```
bash package_macos.sh                        # never bare make
SS_REF_HEIGHT=420 SS_LUM_CEIL=520 \
  bash logs/run_shot.sh <name> <a|b> <SS_CAM_RHO> 9000 0 19644 "7152,5340,7152"
# take 6 = mode a, SS_CAM_RHO=1488   ·   take 7 = mode b, SS_CAM_RHO=50
# gate the driver on "[MIDI] Listening on" (log line ~46), NEVER "[CAPTURE] ARMED" (~21)
```

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | Why POV still shook after the near-plane fix | assumed fixed | **THE FIX IS A FACTOR, NOT IMMUNITY.** Depth step = `ulp·z²/near`: **59.6** units at near 0.001/z 1000, **0.51** at near 1.0/z 2925, **2.00** at near 1.0/z 5800. Past ~2 units apart in depth, stars share a value and the `Less` test flips by thread order — same mechanism, 4× further out | `src/main.cpp` perspective branch, `renderer.mm:851` | `[HIS WORDS ~13:0x]` + `[READ]` |
| 2 | Was it a stale bundle? | unchecked | **NO.** Bundle 11:57:55 built from source carrying `1.0f, 20000.0f`; process started 13:02:06 from it. Checked BEFORE re-diagnosing | protocol rule 1 | `[MEASURED]` |
| 3 | The zoom-out range for modes a/b | ran to `kMaxRho` 5800 | **CAPPED at zUnit 0.5 = rho 2925** (`kOutCap`), exactly where takes 8/9 live. ⚠️ A CAP, not a fix — the real fix is reversed-Z depth, not built | `logs/midi_ride_shot.mm` | `[HIS WORDS ~13:1x]` *"2 yeah for that"* |
| 4 | Takes 6 and 7 | shaking, 4 min, superseded | **REDONE AT 5 MINUTES AND DELIVERED.** take6 9000 f/545.5 s (notes f0, f3600); take7 9000 f/505.3 s (notes on the quarters). Both land rho 2925 + theta 90° | `~/Desktop/sweep/` | `[MEASURED]` 6 slices ffprobe 9000 f; 75 profile windows each, **0** `Compute avg 0.00` |
| 5 | Driver fault A | modes a/b hardcoded `maxFrames=7200` **and** legs as literal frames 2700/5400 | Legs derive from `rideFrames`; changing take length no longer desyncs them | `logs/midi_ride_shot.mm` | `[READ]` + synthetic 9000-frame dry run |
| 6 | Driver fault B | `take complete` printed `rho=2000` from a stale kMaxRho span while the camera landed at **5800** | Span corrected to 5750. **A log line that lies about where the camera went is worse than no line** | same | `[READ]` |
| 7 | Takes 6/7 undeliverable | ProRes only | **DXV3 on the drive.** Full set now 18 files / six takes / **33 minutes**, every one `DXD3` at 7152/5340/7152 with exact counts | `/Volumes/LOSTINSPACE/JAMAL/` | `[MEASURED n=18 ffprobe]` |
| 8 | `kMinRho` is what makes `near = 1.0` safe | written nowhere | Bible §6.17. Drop `kMinRho` below ~1 in POV and particles inside 1 unit of the eye vanish silently | `docs/SPACE_SYNTH_LIVE.md` §6.17 | `[READ camera.h:113]` |

## 2. 🚨 OPEN — his list, verbatim

1. **"can we move more stuff to the drive?"** (~14:2x)
   `MEASURE:` `df -h /Users/airy` — 123 GB local at 15:0x.
   State: masters of takes 4/8/9 (**271 GB ProRes**) are COPIED to `MASTERS_PRORES/` and byte-size
   verified; **nothing deleted locally, and deleting them is UNRULED.** Takes 6/7 ProRes (221 GB)
   have DXV3 now, so they are also reclaimable. `[HYPOTHESIS]` nothing else is safe to remove.

2. **The 271 GB local ProRes for takes 4, 8, 9.**
   `MEASURE:` nothing — this needs his word, not a run.

3. **13 commits unpushed** (9 source+tools, the rest docs) — measure with
   `git rev-list --count origin/true-physics..HEAD`, do not quote arithmetic. **Commit and push are
   different orders** and only /handoff was given.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Chasing the POV shake in the CAMERA — REJECTED 2026-09-05 ~13:4x.** Not the spring
  (`kZetaZoom` is 1.00, critically damped), not the ride (2 reversals in 2289 samples), not the
  receiver latch (per rendered frame the applied track is monotonic), not sprite size (the 4× run
  still shook). The only live mechanism is depth precision. **When a defect is POV-only, read the
  projection before measuring pixels.**
- **Phase correlation as a shake instrument — REJECTED.** It locks onto the static core of a star
  field and under-reports; it read 0.042 px/frame where per-star tracking read 0.54. Use per-star
  tracking on this content.
- **A 150-frame smoke as evidence that a take is black — REJECTED.** It measures a field that has
  barely formed. The finished POV takes read YAVG **169** at f900 against video black 64.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-05 15:29:33  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 641aa8f
  FAIL  4 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M docs/BOARD.md
           M docs/BOARD_BLACKHOLE.md
           M docs/SPACE_SYNTH_LIVE.md
          ?? docs/HANDOFF_2026-09-05_BRAIN_POV_TAKES_AND_DEPTH_BOUND.md
  WARN  8 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 641aa8f
  WARN  docs/BOARD_BLACKHOLE.md is 270937B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 104965B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 641aa8f
  WARN  docs/BOARD.md is 223683B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    69 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:577:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:765:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1146:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1466:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1469:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2585:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/render.metal:3329:                mp = rotAboutAxis(mp, float3(0.0f, 0.0f, 1.0f),
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.

[The single FAIL is the four paths of THIS handoff itself — the two boards' restamp, the
 bible §5.1a, and this file, uncommitted at the moment preflight ran. They are committed in
 the same breath. Both boards read `current at 641aa8f` and the artifact is no longer STALE:
 the bundle was rebuilt 15:28:18 against newest source 15:21:23, and that 15:21:23 was git
 STAGING rewriting mtimes, not an edit — see board §AA30.6.]
```

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The shake is the camera spring / perspective parallax" | I quoted `kZetaOrbit` **0.70** at a zoom spring that is `kZetaZoom` **1.00** (`camera.h:110-111`) — the orbit constant applied to the wrong spring — and measured it with an instrument that cannot see this content. |
| "The 1-px sprite floor is the root" | His eyes killed it: the 4×-sprite run at full width still shook, *"crazy shake is back"*. The real point-spread floor is a Chladni dashed-lines item, unrelated to this. |
| "POV renders black" | A 150-frame smoke on an unformed field. Corrected the same session by measuring the finished take. |
| "It's 11 unpushed, not 10" — and later counts | Right that time, but the count was wrong THREE times today across two windows. **Measure with `git rev-list --count`, never arithmetic.** |

---

**Last Updated:** 2026-09-05 15:28:30
**Folded into board:** `docs/BOARD.md` §AA30 + `docs/SPACE_SYNTH_LIVE.md` §5.1a @ 2026-09-05 15:28:30
