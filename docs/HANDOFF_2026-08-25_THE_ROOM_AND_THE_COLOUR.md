# SPACE SYNTH TUBE — handoff 2026-08-25 13:46:11

> **His verdict on this state:** *"its oakly witht he colors but nt 0 perfect yet"* (2026-08-24) · *"looking ok dont see the slider tho"* (2026-08-25) · on the room: *"u were right at this pov it stops becoming a screne. it is the room"* (2026-08-24)
> **Cold start:** read `docs/TODO.md` — NOT this file, NOT older handoffs. Row **S00e** settles the venue; **G16** is the live colour defect.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube` branch `kill-the-tube-2026-08-11` @ `0cf85b4`
**Build + launch:** `bash package_macos.sh` then `open -n SpaceSynth.app --env SS_FULLSCREEN=1`
**Priority he set 2026-08-24:** *"we will spend the rest of thus week on gettiung the visuals right and then we try and fit it itno the venue... cinema vibes first. then techy nerdy stats for the room."* — venue maths is BANKED, visuals lead.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| S00e | Venue geometry guessed from a text message | 15×4 / 10×4 m, 160 m², 10:1 | **14.75 / 10.01 / 3.50 m, 138.25 m², 11.286:1** | Polycam OBJ, 256,532 verts | `[MEASURED n=1 scan]` floor plane y −1.50, wall tops y +2.00 |
| S00e | Unknown whether anything blocks the walls | unknown | **3 walls clean (98/98/96%), focus band 100% intact, ZERO pillars** | 0.25 m occupancy grid | `[MEASURED n=1 scan]` |
| S00e | Object in front of the front wall | possible obstruction | **a person, room mid-setup** | — | `[HIS WORDS]` 2026-08-24 |
| S00d | Back wall assumed projectable | 4 surfaces | **3 — the door wall gets no beamer** | — | `[HIS WORDS]` 2026-08-24 |
| G15 | Hubble/NIRCam band sets existed, nothing ever selected them | `const BandSet &bs = kBandVisible;` | **`SS_BANDS`, default `stellar-bvr`** | `renderer.mm:974`, `spectral_lut.h` | `[READ renderer.mm:974]` + `[MEASURED]` 4-temp sweep |
| G15 | Band edges could not do continuum AND lines at once | hubble: R had NO line | **B .360–.495 / G .495–.600 / R .600–.720** beats both sets on every axis | `spectral_lut.h` `kBandStellar` | `[MEASURED]` 10000 K 0.636, 30000 K 0.810, lines 1/band |
| G15 | Self-test `expect` hardcoded for one band set | printed FAIL when nothing was wrong | **`expectedLineBands()` derives it from the live set** | `spectral_lut.h`, `renderer.mm:1035` | `[MEASURED]` both self-tests pass at launch 22:01:32 |
| G17 | Phase Viz REPLACED all colour | `if/else` → spectral path dead code | **blends, hue only, one late site** | `render.metal:1775`, tint before `:2489` | `[READ render.metal:1775]` |
| G17 | Chladni and starfield coloured differently | two paths, no shared site | **one tint site after BOTH regimes** | `render.metal` after `:2322` | `[READ]` — his ask, structurally answered |
| G16 | "The whole field is orange" was unlocated | vague | **located to the dense-gas region; field r>200 is 37.6% cool and CORRECT** | screenshot histogram | `[MEASURED n=1 frame, 45,748 lit px]` |
| G16 | S–S disk override suspected of flattening colour | prime suspect | **CLEARED — never runs, `horizonR=0.0000`** | `render.metal:2103` + live log | `[MEASURED]` log line |
| — | I could not see the app myself | asked him to describe it | **`screencapture` + ffmpeg + histogram, working** | `feedback_take_your_own_screenshots.md` | `[HIS WORDS]` 2026-08-24 + verified pipeline |

## 2. 🚨 OPEN — his list, verbatim

1. **"its oakly witht he colors but nt 0 perfect yet ... pls check whatever has an influence on the color pipeline"** (2026-08-24)
   `MEASURE:` build with `lineStrength` env-gated to 0 → relaunch → `screencapture` → radial histogram. If the ring's 96.9% warm drops, the gas-line cause is proven.
   State: audit done, 7 stages mapped `[READ]`. Defect LOCATED to dense gas `[MEASURED]`. Cause is `[HYPOTHESIS]` — **must not be closed until counted.** The two Kelvin knobs he calls "weird temp toggles" are already **0.0** and inert `[READ app_state.h:166,187]`.

2. **"the ... corsses in the stars that u said are correct we dont have that, that will give us ore of a dico vib too"** (2026-08-24) — diffraction spikes. NOT STARTED.
   `MEASURE:` — feasibility only so far: stars are point sprites and `particle_fragment` already takes `point_coord` (`render.metal:2692`), so spikes are a fragment-shader change, no new pass. `[READ render.metal:2692]`
   State: **blocked on his answer — 4-point (Hubble spider vanes) or 6-point (JWST hex segments)?**

3. **"looking ok dont see the slider tho"** (2026-08-25) — see **G18**.
   `MEASURE:` screenshot the APP WINDOW specifically (get its bounds first), find the SIMULATION header, look.
   State: label IS in the binary and the header is live and `DefaultOpen` `[READ main.cpp:1364,1377]`. **On-screen presence NEVER VERIFIED** — my capture caught my own terminal.

4. **"chladni colors are so diffeent to starfield colors pls unify it"** (2026-08-24) — PARTLY DONE.
   State: the phase tint now applies at one shared site `[READ]`. But the two `spectrumToBands` calls still differ in **what drives line strength**: play uses `lsPlay = temp/5` (`:1862`), star-map uses gas density (`:2078`). Two different physical quantities, one function. Full unification is a design call he has not made.

5. **The room, banked by his order.** Three off-axis frustums from one eye position remain the only correct construction for 270°. Geometry is settled (S00–S00e); nothing else on it until the visuals land.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **RGB `mix` toward a fixed-saturation phase colour — REJECTED 2026-08-24 22:47:00.** Mixing in RGB desaturates whenever the two hues oppose: measured **24.8% of lit pixels washed to white/grey**, mean saturation 0.636 → 0.420. Replaced by a true hue rotation in HSV carrying S and V through untouched → grey back to 3.1%. **Never "blend" two colours in RGB when the intent is a hue shift.**
- **`kBandNircam` as a drop-in for stars — REJECTED 2026-08-23 20:12:26.** In 0.8–5 µm everything above ~3000 K sits on the Rayleigh–Jeans tail, so the shortest band always wins: B 1.000 / G 0.10–0.20 / R 0.02–0.04 for **every** star from the Sun up. A pure NIRCam continuum is one blue field. JWST images are colourful from lines and dust — NIRCam is the gas story, not the stars.
- **Comparing colour across two launches — INVALID, learned 2026-08-24 22:50.** Each launch reaches a different sim state (one had already collapsed to `BH FORMED`, hole 2.64e+04 M☉, camera zoomed in). Hue percentages across launches prove nothing. Only same-session slider A/B, or saturation/grey fractions, are comparable.
- **Reverting to `visible` to get the gas red back — NOT NEEDED.** The line-straddling edges recover Hα→R *and* keep the hot-end continuum. Reverting would have traded one defect for another.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-08-25 13:45:06  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE-killtube

1. git
  ok    branch kill-the-tube-2026-08-11, HEAD 0cf85b4
  WARN  13 uncommitted path(s)
  ok    pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 0cf85b4
  WARN  docs/BOARD_BLACKHOLE.md is 87708B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 0cf85b4
  WARN  docs/BOARD.md is 104151B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    33 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:565:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:752:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1366:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1665:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1668:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2759:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  7 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: no failures.
```
**Entry state, for the record:** both boards FAILed at `a44de13` while HEAD was `0cf85b4`, and `BOARD.md` cited an unresolvable path string (`src/ui/window.{h,mm}` — brace shorthand I wrote myself; the preflight path check cannot expand it). All three fixed before this handoff was written. ⚠️ **CORRECTED 2026-08-25 14:2x: the FILES are real.** `src/ui/window.h` (4,267 B) and `src/ui/window.mm` (26,908 B) both exist, both modified 2026-08-23 20:10, both in the uncommitted set. Only the brace-shorthand *string* was invalid — nothing was fabricated but the notation, and the original wording overstated the fault.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The play path bypasses the spectral LUT, so the band set only governs half the app" | There is a third bit16 gate at `render.metal:1861` I had not seen. Play goes through `spectrumToBands` too. Checked before saying it out loud. |
| "The Shakura–Sunyaev disk override is repainting the galaxy orange" | Gated on `cam.horizonR > 0.0f`; the live log reads `horizonR raw=0.0000`. The block never runs. |
| "93.6% grey, mean saturation 0.124 — the hue rotation made it far worse" | I captured a **blank window one second after launch** and my crop was reading the desktop wallpaper. Both the frame and the crop were wrong. Real figures: grey 3.1%, saturation 0.561. |
| The three-way BEFORE/MIX/ROTATE hue table | Three different launches = three different sim states. Not an A/B. Only the grey/saturation fractions survive. |
| "253 ppi panel" (in three source comments) | The panel is **255.0 ppi** (3024 px / 301.21 mm). And the quantity computed is **points-per-inch**, not dpi — they coincide only in a 1× mode. |
| "The sides are 15 m" (carried from his message into S00) | Scan says **14.75 m**. 1.7% short; matters once it becomes pixels. |

---

**Last Updated:** 2026-08-25 13:46:11
**Folded into board:** `docs/TODO.md` (S00–S00e, G15–G18) @ 2026-08-25 13:46:11 · both board headers re-stamped to `0cf85b4`
