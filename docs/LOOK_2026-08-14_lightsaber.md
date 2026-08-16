# 🗡️ THE LIGHTSABER LOOK — settings captured 2026-08-14 18:21:25

> **His verdict, 2026-08-14 ~18:19:** *"these settings kinda work with the grain and bloom. the small streaks turn into somewhat of what i want with the lightsaber interstellar look"*

**The first positive verdict on the trail look.** Captured off his screenshot immediately, because
**nothing in the app persists these values** — see §3. Quitting loses them.

---

## 1. THE NUMBERS — read off his screen, defaults for comparison

| Panel | Dial | HIS VALUE | default (`app_state.h`) |
|---|---|---|---|
| STAR SIZE | Size Gain | **1.18** | 1.0 (`:201`) |
| STAR SIZE | Size Exp | **0.829** | 0.8 (`:202`) |
| STAR SIZE | Size Floor | **2.78** | 1.0 (`:203`) |
| STAR SIZE | Size Ceil | **48** | 48.0 (`:204`) — unchanged |
| STAR SIZE | Sharpness | **5.0** | — |
| STAR SIZE | Grain | **0.436** | 0.08 (`uiGrainAlpha`, `:15`) |
| GEOMETRY | Space Scale | **100** | — |
| GEOMETRY | Wave Depth | **20.0** | 20.0 — unchanged |
| POST-FX | Exposure | **19.370** | 1.0 (`uiExposure`, `:81`) |
| POST-FX | (unlabelled, below Exposure) | **1.00** | — label truncated on screen |
| POST-FX | Fluidity | **0.23** | — |
| POST-FX | Chromatic | **0.000** | — |
| CYBERPUNK | Glitch / Scanlines / Neon | **0 / 0 / 0** | — |
| CYBERPUNK | Grade LUT | **1.00** | — |

**The two that moved hardest: Grain 0.08 → 0.436 (5.5×) and Exposure 1.0 → 19.37 (19×).**
Size Floor 1.0 → 2.78 is the third. Everything else is at or near default.

**Camera:** Azimuth φ +20.98°, Elevation θ −152.11°, Distance ρ 2000.0.
**Sim state at capture:** UNIVERSE 52.1 min, time **4×**, COLLAPSE 36%, BH FORMED, v 0.24 c,
T 3.8e+11 K, **22 fps**.
⚠️ 4× warp — fine for judging the LOOK, but see BOARD_BLACKHOLE §L8: never trust
accretion/merger results above 1×.

**Build this was seen on:** `render.metal` 18:04:04 → bundle 18:04:13, i.e. **with** the
arc-colour unification (trails take `unifiedKelvin`, the private orange ramp deleted).

---

## 2. WHAT HE SAID IS WORKING

- **"the small streaks"** — SHORT arcs, not the long sweeping ribbons. The huge arcs from
  earlier in the session (his "orange hair", "weird random shapes") are NOT the target.
- **grain + bloom** are doing real work here, not decoration.
- Target named: **"lightsaber interstellar look"**.

**Read against the earlier rejections in one line: length is not the lever, DENSITY of many
short bright streaks is.** Every attempt today that pushed arc length up was rejected; the
one that pushed grain/exposure with short arcs passed.

---

## 3. 🚨 THESE SETTINGS CANNOT BE SAVED — VERIFIED

`struct Preset` (`src/core/preset_manager.h:8-34`) holds exactly: particleSize, jitterScale,
damping, retraction, waveDepth, speedCap, eField, bField, gravity, stringStiffness,
restLength, particleCount, bloomIntensity, trailDecay, chromaticAberration.

**Not one of the dials in §1 is in it.** Size Gain/Exp/Floor/Ceil, Sharpness, Grain, Exposure,
Fluidity, and all four of the BH/arc dials live only in `AppState` in memory. The
"save preset" path (`main.cpp:1305-1306`) writes the struct above and nothing else.

⟹ **Quit the app and the lightsaber look is gone.** That is why this file exists.

This is the same gap he named on 2026-08-14 12:26: *"i will create a new preset in the ui at
a later point, it cant be constructed from the parameters in the engine rn."*

**Two ways to make it durable, neither done yet, his call:**
1. **Bake as defaults** — write §1 into `app_state.h`. One change, instant, no format work.
2. **Widen the preset format** — extend `Preset` to carry the look dials so multiple looks
   can coexist and be A/B'd. Bigger, and it is the thing he actually asked for in the 12:26
   order.

---

**Last Updated:** 2026-08-14 18:21:25
**Live tree:** `SPACE-SYNTH-TUBE-killtube`, branch `kill-the-tube-2026-08-11`
