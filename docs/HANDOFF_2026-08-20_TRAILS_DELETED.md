# SPACE SYNTH TUBE — handoff 2026-08-20 18:27:12

> **His verdict on this state:** *"soemwhat thius is even worse than the other approach"* (15:32:18, on the smear).
> The L1 lens fix that followed it is **NOT SEEN YET**.
> **Cold start:** read `docs/TODO.md` (12 KB) — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube` branch `kill-the-tube-2026-08-11` @ `5ee213d`
**Build + launch:** `bash package_macos.sh` && `open -n "<tree>/SpaceSynth.app" --env SS_FULLSCREEN=1`
🚨 **Everything below is UNCOMMITTED — 10 paths. He gave no commit order.**

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| **L1** | The lens shadow was sized with the ORTHO screen map in BOTH projections | `bSim·plateRadius / frustum`, `frustum = cameraRho·1.2` | `/ (dHole·0.414214)` in perspective, `frustum` in ortho. 0.414214 = tan(45°/2); 45° is the fov `main.cpp:776` passes | `renderer.mm:1661-1690` | `[READ renderer.mm:1661]` — **2.897× too small**, the factor the code's own comment predicted. 🔨 **UNVERIFIED, he has not looked.** |
| **RIBBONS** | A stroke per star can never be a body | 1.5M ribbons: `TrajOut`, `trajectory_vertex`, `trajectory_fragment`, pipeline, draw, 2 UI controls | **DELETED, ~370 lines.** Headstone at the site | `render.metal` @ old site | `[HIS WORDS]` 2026-08-20 15:06 *"delete the fucking code and put it 6 feet under lol"* |
| **MOTION** | No pass could ask how the matter moves on screen | nothing existed | Star pass writes attachment 1: `velReal + spin` through the **current** viewProjection at both ends ⇒ camera cancels | `render.metal` `ParticleFragOut`; `renderer.mm` 6 pipelines declare it, 5 masked | `[READ render.metal:2605]` — blending OFF; a velocity is a value, not light |

## 2. 🚨 OPEN — his list, verbatim

1. **"soemwhat thius is even worse than the other approach"** (2026-08-20 15:32:18)
   `MEASURE:` count the tap spacing — band length in px ÷ 48 taps. At Smear length 24 that is **5–8 px**, so each
   star repeats as separate beads and MORE length makes it WORSE.
   State: `[READ postfx.metal, smear block]` the sampling is naive — 48 fixed taps. **The fix is a multi-pass
   doubling smear (~6 passes), not more taps.** `[HYPOTHESIS]` that a continuous band then reads as his reference.

2. **"this needs to be a unified body not individual hairs no matter the size"** (2026-08-20 14:37)
   `MEASURE:` his own eyes on a continuous band; nothing else settles it.
   State: the ribbon road is closed by his order. The smear is the only remaining candidate.

3. **"color distirubution at start is wrong"** (2026-08-20 14:37) — **NOT INVESTIGATED, not asked about since.**
   `MEASURE:` read the spawn colour law before proposing anything.

4. **BH2 — two Ω laws for one disc, STILL LIVE.** `render.metal:1610-1611` (spin-softened, hardcoded +Z) vs
   `:3716`/`:3721` (poseAxis, √(M/r³)). Preflight §5 flags both, 18:27:12.
   `MEASURE:` β at the disc drops ≈3× (r/(r^1.5+0.5) → √(r_s/2r) at meanR≈44, r_s≈0.23).
   State: **a fix was written and reverted 14:22:25 on a MISREAD verdict — never rejected on its merits.**

5. **The field is dark with the ribbons gone.** `[READ render.metal:1552]` sprite size is floored at 1 px and
   brightness is compensated only when a sprite is too BIG, never too small. `[HYPOTHESIS]` the smear cannot look
   like the reference until the dots carry real light.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **A stroke per star, in any form — REJECTED 2026-08-20 15:02:51.** 1 px lines read as hair; real triangle
  strips with a thickness slider read as slabs. Four fixes tried in one session — width conservation, the S7
  luminosity term, the orbital plane, real thickness — and the look survived none. **A million separate strokes
  with gaps between them is what hair IS.** Deleted, not disabled.
- **The playback / time-lapse rate as a speed for anything physical — REJECTED 2026-08-20 14:48.** It is ~150
  rad/s of DISPLAY speed. Driving the smear with it produced a screen-filling spirograph. It had already blown up
  the Doppler once, and that was written down before I did it again.
- **Dimming individual strokes to fix a mat of strokes — REJECTED 2026-08-20 14:31.** His words: *"your apporach
  is wrong."* It treats each hair as the thing to fix instead of asking why hairs are being drawn.
- **The screen-centre tangential stretch (the old `pixelStretch`) — REPLACED 2026-08-20.** It rotated samples
  about the middle of the SCREEN by an angle from the SPIN DIAL: the camera-driven version of what he asked for.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-08-20 18:27:12  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube

1. git
  ok    branch kill-the-tube-2026-08-11, HEAD 5ee213d
  WARN  8 uncommitted path(s)
  ok    pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 5bd9133 — 1 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 84035B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 5bd9133 — 1 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 94009B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    30 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:533:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1309:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1608:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1611:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2629:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/postfx.metal:43:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  6 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: no failures.
```

⚠️ §5 read: `:1608`/`:1611` are **BH2 itself** — the hardcoded +Z Doppler tangent, still live because the fix was
reverted. `:533` is `poseAxis`'s documented polar fallback. `:1309`, `:2629` and the postfx line are unrelated.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| *"The first step either way is: the star pass has to write depth"* (14:39) | A screen-space smear needs no depth ordering. I corrected it myself an hour later — but it was stated as a blocker and it was not one. |
| The width-conservation fix — dim each ribbon by how thin it truly is (14:27) | Right arithmetic, wrong target. Fixing individual hairs cannot produce a body. His verdict: *"your apporach is wrong."* |
| The orbit smear's speed from `poseOmegaEff` (14:48) | That is the playback/time-lapse rate. I had written, two messages earlier, that this rate must never feed a physical shift — then fed it to the smear. Second sighting of one mistake in one hour. |
| *"48 taps ... should look like a stretch, not a smudge"* (15:28) | 48 taps over a several-hundred-pixel band leaves 5–8 px gaps. It produces beads. Diagnosed only after his screenshot. |
| *"β drops ~3×"* on BH2 | Still unmeasured — the change was reverted before it ran. Carried forward as a prediction, not a result. |

---

**Last Updated:** 2026-08-20 18:27:12
**Folded into board:** `docs/BOARD.md` + `docs/BOARD_BLACKHOLE.md` + `docs/TODO.md` @ 2026-08-20 18:27:12
