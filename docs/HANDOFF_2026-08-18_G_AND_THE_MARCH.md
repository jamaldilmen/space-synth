# SPACE SYNTH TUBE — handoff 2026-08-18 18:29:41

> **His verdict on this state:** *"dtill the same in every way lol"* (2026-08-18, on the wide star-map frame) — and earlier, on the emission at −6.0: *"the emission is this bs why are u even turning it on that was not what we're on"* (2026-08-17 16:26).
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` **§M** — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube` branch `kill-the-tube-2026-08-11` @ `e853e18`
**Build + launch:** `bash package_macos.sh` then `pkill -x SpaceSynth; SS_FULLSCREEN=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth > /tmp/ss.log 2>&1 &`
⚠️ **8 uncommitted paths.** Everything below is in the working tree and the built bundle, **not** in `e853e18`. Nothing committed — he never gave the order.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| **M1a** | March extent was a CONSTANT in r_s while r_s *and* the field move independently — so it tracked the hole and lost the disc | `bCull = 7.0`, `rMarchStart = 60.0` | `bCull = meanR/r_s`, `rMarchStart = maxR/r_s`, from the reduce `[GRAV]` already prints; dial kept as multiplier (7.0 ≡ 1.0×) | `renderer.mm` grep `bDerived`, `measuredMaxR` | `[MEASURED n=210]` adapted **4.87 → 198.19** in one run |
| **M1b** | Scale of the miss | meanR 43.91 sim, r_s 0.2344 ⟹ field = **187 r_s**, bCull **7** | march saw **3.7%** of disc radius; slider max 40 reaches only **21%** — no setting could show it | `app_state.h:65` predicted it verbatim | `[MEASURED n=3]` `[MARCH]`+`[GRAV]` 17:43 |
| **M1c** | Hardcoded orange — the reason bit19 was banned 2026-07-28 | `float3(1.0,0.55,0.25)` | `blackbodyRGB(g·T(r))`, SS profile `(r/r_in)^(−3/4)[1−√(r_in/r)]^(1/4)`, r_in = ISCO = 3 r_s, anchored 6500 K = DNGR white balance. 6500 K @4.08 r_s → 1322 K @60 r_s | `render.metal` grep `T_ANCHOR_K` | `[HIS WORDS]` *"must leave asap"* 07-28 09:32:18 |
| **M1d** | No `g` in the march at all | no Doppler, no gravitational shift | `g = 1/[u^t(1−Ω·b)]` — **one factor**, exact, off the photon's conserved `b`. Bounded by `√((1±β)/(1∓β))`, the emitter's own limits | `render.metal` grep `gShift` | `[READ]` Ω·r at ISCO **0.4082** vs measured orbV max **0.4092c** (`particles.metal:246`), 0.25% |
| **M1e** | Emission with no absorption → the brown fill | `emit +=`, unbounded ∫ρ ds over 60 r_s | `dTau`/`trans` transfer. **No new constant** — LTE, so the same κρ ds is emissivity *and* optical depth (Kirchhoff). Saturates at B(T) | `render.metal` grep `dTau` | `[HIS WORDS]` 16:26 → cause = missing extinction, not gain |
| **M1f** | Phase Viz dead in the star map (board item 4) | — | `render.metal:2282` `mix(out.color, starColor, starMix)`, `starMix = 1` at silence, never checks `cam.phaseViz`. Written `:1743`, overwritten 540 lines later | `:1743`, `:1866`, `:1898`, `:2282` | `[READ]` 4 sites, live callers |
| **—** | bit19 default | OFF since 2026-07-28 | **ON** | `app_state.h:57` | `[HIS WORDS]` *"open it with the switch on dont give me such tasks"* |

## 2. 🚨 OPEN — his list, verbatim

1. **"dtill the same in every way lol"** (2026-08-18)
   `MEASURE:` get the field to the **expanded disc** (meanR ≈ 44 sim, r_s ≈ 0.23 — his 17:39 frame), then read `[MARCH] bCull` ≥ ~150.
   State: `[MEASURED n=210]` every state in the probe run was a **collapsed ball** (meanR 4.6–11.6, r_s→0.84), where the derived extent reproduces ~7 = the old constant. **M1c/M1d/M1e have never run where they can be seen.** Not "no effect" — untested.

2. **"theres a weird smear when i move cam … like uhrzeiger straight lines that create blurr"** + **"it didnt matter it was in oth mods"** (2026-08-17)
   `MEASURE:` A/B (a) vs (c) behind an env bit, one arm per run.
   State: `[READ]` **candidate (b) is DEAD** — `emergentPoseDt` returns 0.0 when `paused && !holdTimelapse`, but the *posed* branch has no pause gate at all; a mechanism gated off in one mode cannot smear in both. Leaves **(a) postfx frame-feedback**, **(c) `spinAngle*tDilate` shear**.

3. **"i think its how now thousand s fo stars creat ehair thins sprites that like overlay adn create a flicker … i thinkth epixels are too small for the sim"** (2026-08-17)
   `MEASURE:` `grep -rn sampleCount src/render/` → zero hits, confirmed no MSAA.
   State: `[READ renderer.mm:3971]` `MTLPrimitiveTypeLine`, 1.5M × 22 verts. A Metal line is **exactly one device pixel**, binary coverage, no width state. His read is the mechanism. DNGR's answer (doc §6) is an **elliptical beam footprint + mip-filtered source** — *"no flicker/aliasing and no supersampling"*; we have neither. ⭐ Also a conservation gap: no width term, so a sub-pixel ribbon deposits full-pixel energy — same class as the S7 missing-luminosity term.

4. **"when i hold space the neitre thing runs at 120 fpps"** (2026-08-18)
   State: `[HIS WORDS]` **the arc pass is NOT the bottleneck** — same 33M line-verts draw while paused. **Board item 1 blames the line-vertex count and is contradicted by this.** The compute is the cost. Running median `[MEASURED n=776]` **39.9 fps** (min 14.1, max 108.5) with the derived extent live — unchanged.

5. **NEW — two laws for one quantity, found in §5 of preflight.** `render.metal:1611` sprite Doppler uses a **global +Z tangent** and `Ω = 1/(r^1.5+KERR_A)`; the march at `:3716` uses **`poseAxis`** and `Ω = √(M/r³)`. U6/U7 closed this split for the arcs and the playback but never reached the sprite Doppler. `[READ]` both sites, live.

6. **The RIAF fork — still his.** `particles.metal:245` measures **h/r = 0.746** at two radii agreeing to 3%: a thick RIAF at ~4e10 K, emitting in X-ray, with **no true RGB**. M1c is a **declared transfer**, not a claim about our gas. The open question is whether to **cool the gas** so the thin disc becomes true rather than represented.

7. **128³ box-average, UNADDRESSED** (`app_state.h:57`). March samples NEAREST from a 128³ grid while sprites draw sub-pixel, additively overlaid. Trilinear tried and pulled 2026-07-26.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Raising the emission gain to make the pass visible — 2026-08-17 16:02:41, reverted 16:29:05.** −7.5→−6.0 gave a screen-filling brown blob. The gain was never the fault: `emit +=` had no extinction (M1e). Lowering it *hides* the fill. **Brightness is his** (2026-08-14 12:26). It sits at −6.0 again only because the transfer now bounds it and at −7.5 the transfer is a numerical no-op (`dTau ≈ 3e-8`).
- **Reading the marched region's size off a screenshot — twice, opposite directions.** Apparent size is `bCull × r_s` against camera zoom: at 16:26 (zoomed) a 1.6-sim region filled the frame; at 17:39 (wide) it was a dot. **Read it off `[MARCH]`, never off the image.**
- **Quoting DNGR's 2015 CPU wall-clock (30 min–hours/frame) as our ceiling.** His correction: *"the method will translate. its 2026."* That number is the cost of their formulation on their hardware, not a property of the method. Their §7 is explicitly a Metal-compute reduction.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-08-18 18:27:16  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube

1. git
  ok    branch kill-the-tube-2026-08-11, HEAD e853e18
  WARN  8 uncommitted path(s)
  ok    pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at e853e18
  WARN  docs/BOARD_BLACKHOLE.md is 42467B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD.md current at e853e18
  WARN  docs/BOARD.md is 217051B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    24 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:533:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1309:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1608:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1611:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2617:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/postfx.metal:43:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  6 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: no failures.
```

**§5 forced look, done:** `:533` poseAxis +Z fallback on the polar axis — correct, the spawn zeroes v there. `:1611` — **divergent, see §2.5.** `:3716` (mine, new) uses poseAxis, the unified law. `:1309`, `:1608`, `:2617` untouched this session, not re-verified.

**Four FAILs cleared before this handoff:** `BOARD.md` was 3 commits behind (now `e853e18`); `CLAUDE.md`, `BOARD.md` ×2 cited `src/core/lut.cpp`/`lut.h`, deleted 2026-08-11 — the prose mentions were unlinked and one **live citation list at `BOARD.md:393` still named `lut.h` as a domain file, contradicting the row directly above it that closes that domain.**

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The marched region is a small central disc, the ring is outside it" (17:43) | Computed from a *wide* frame and applied to a *zoomed* one. Apparent size is `bCull × r_s` vs camera zoom — it had filled his screen an hour earlier. |
| "~700× cost blowup from deriving bCull" | `bCull × r_s = meanR` **by construction** — both sides move. Extent in sim units is always meanR. `[MEASURED n=776]` fps median 39.9, unchanged. |
| DNGR's 30-min-to-hours-per-frame as our ceiling | His correction, accepted: that is their formulation on 2015 CPUs, not the method. |
| `F_PEAK = 0.49146` | Correct value **0.487871**. Self-caught by computing it before the build; also caught `T = 0 K` at the ISCO, which would have painted the innermost gas deep red at full brightness. |
| Raising the emission default (−7.5 → −6.0) at 16:02 | Never asked for. Brightness is his. It produced the blob he rejected on sight. |

---

**Last Updated:** 2026-08-18 18:29:41
**Folded into board:** `docs/BOARD_BLACKHOLE.md` §M @ 2026-08-18 18:26:03
