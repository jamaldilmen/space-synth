# SPACE SYNTH — HUD Design Brief (STRICT)
_Last Updated: 2026-06-27 12:05:00_
_Layout chosen 2026-06-27: Stellaris top-bar + left rail + section panels._

## 0. What this renders on
The HUD is drawn **every frame by Dear ImGui's `ImDrawList` over a live Metal 3D
simulation**. It is NOT a web page — no DOM, no CSS engine, no browser compositor.
Design in HTML/CSS for the *look*, but **every element must map to an ImGui draw
primitive** (§1). If it can't be expressed as one of those, it can't be built.

## 1. Buildable vs forbidden (HARD RULES)

**ALLOWED (maps 1:1):**
- Filled rectangles, optional corner rounding
- Rectangle outlines / lines / dividers (any color, any alpha, thickness ≥1px)
- Linear gradients — 2-color, horizontal or vertical only (4-corner interpolation)
- Translucent fills (alpha) — this is how we fake "frosted glass": a dark
  semi-transparent panel, NOT real backdrop blur
- Text — single typeface, color + size + opacity for hierarchy
- Glow — approximated as 2–4 stacked lines/rects with decreasing alpha (cheap bloom)
- Meters / bars — a proportion-filled rect
- Simple geometric icons drawn by hand: circle, ring, triangle, square, plus, chevron, dot

**FORBIDDEN (cannot reproduce — do not use):**
- Real gaussian/backdrop blur of the scene behind
- Radial / multi-stop / conic gradients
- `box-shadow` as a real soft shadow (only the layered-glow approximation)
- Drop shadows on text
- Background images, raster textures, PNG/JPG fills
- SVG icon sets, icon fonts, emoji
- Font weights — assume ONE weight. Hierarchy = size + color + opacity ONLY
- Animations/transitions (HUD redraws per frame; state changes are instant)

## 2. Layout (LOCKED — Stellaris top-bar + left rail)
Design at reference resolution **1920×1080**, transparent background.
- **Top status bar** — full width, top edge, height **34–40px**. Horizontal telemetry
  strip, glowing accent underline.
- **Left rail** — left edge, vertical section buttons (icon + short label), width **64–180px**.
- **Section panel** — opens right of the rail when a section is selected. ONE open at a
  time. Width **~300–340px**, anchored top-left under the bar.
- Whole HUD hides on TAB. Center stays empty for the sim.

## 3. Exact data the HUD must display
**Top bar (left→right):**
`UNIVERSE <clock> <unit>` · `<warp>x` (or `PAUSED`) │ `COLLAPSE <%>` │ `BH <%>`
(or `FORMED`) │ `v <0.00 c>` │ `T <1e7 K>` │ right-aligned `<fps>`.
Also available: field mass (`M☉`), biggest body (`M☉`).

**Left-rail sections (control groups that exist in the app):**
`SIM` · `BLACK HOLE` · `COLOUR` · `GEOMETRY` · `FX` · `AUDIO` · `SEQUENCER`.
Design the panel chrome (header, slider track/grab, toggle, button states); the
actual controls get filled in code.

## 4. Palette (STRICT — existing app theme)
- Background panel fill: `#08090E` @ alpha **0.70–0.75** (deep frosted)
- Accent (primary glow / active): electric indigo `#6696FF` → `#7F99FF`
- Telemetry value colors: collapse `#64DCFF`, black-hole/heat `#FFA03C`,
  velocity `#82B4FF`, temp `#FFB450`
- Warning / paused: amber `#FFC83C`
- Text: primary white @ 0.95 · dim labels white @ 0.40 · disabled white @ 0.35
- Dividers / borders: white @ 0.10–0.18

Dark, high-contrast, minimal. Cockpit, not dashboard.

## 5. Deliverable
For each element (top bar, rail, rail button states, panel header, slider, toggle,
button), give: (1) HTML/CSS component at 1920×1080 on a dark/transparent bg;
(2) exact px dims, paddings, edge offsets; (3) exact hex + alpha for every
fill/line/text; (4) font size px + opacity per text tier; (5) for any glow, the
color and px bleed. **Numbers, not adjectives.** No "subtle / soft / vibes."

---

# Appendix A — NASA Open MCT patterns to steal (extracted 2026-06-27)
Source: `nasa/openmct` (open-source mission-control telemetry framework). Their
literal grays don't apply (they render on a mid-gray `#2c2c2c` bg, we render dark
over a sim), but the **system** is proven cockpit UX. Take the discipline, not the colors.

**Concrete tokens (Espresso theme):**
- ONE accent "key" color used for ALL interactive/active state: `$colorKey #03ace4`,
  `$colorKeyBg #007fad`. → Our equivalent is the single indigo. Don't rainbow the chrome.
- Text tiers by opacity: emphasis `#fff`, normal `#acacac` (~0.67), subtle `#9c9c9c`.
- Selection = accent at low alpha: `rgba(key, 0.3)`. Menu hover = `rgba(key, 0.5)`.
  Border = `rgba(fg, 0.2)`. → Hover/active should be **accent-alpha**, not white-alpha.
- Status semantics: ok `#1f851f` (green), caution/alert `#ff8a0d` (orange,
  `statusAlert #ffb66c`), critical/error `#ff3c00` (`statusError #da0004`), info `#60ba7b`.
- Shadows are dark, not glow: btns `rgba(black,0.2) 0 1px 2px`, menu `rgba(black,0.8) 0 2px 10px`.

**Spacing / dimension scale (dense by design):**
- Interior margins: small `3px`, standard `5px`, large `10px`.
- Input text padding: `2px` top/bottom, `5px` left/right. Border radius (tags) `3px`.
- Tabular: header height `22px`, cell padding `5px` LR / `2px` TB.
- Meters/plot: progress bar **min height 4px** (thin!), legend swatch `12px`,
  control bar `25px`, plot y-axis bar `60px`.

**Lessons applied to our HUD:**
1. **One accent, reserved.** Color belongs to data values + the single indigo accent;
   chrome stays monochrome. (Open MCT uses exactly one key color.)
2. **Hover/active = accent at low alpha**, not white. Update our ImGui hover/active
   from white-alpha to indigo-alpha for cohesion.
3. **Three text tiers via opacity** (0.95 / ~0.67 / ~0.40) — matches §4.
4. **Tighten density.** Our current ImGui `FramePadding 10×8` is too fat for a cockpit;
   Open MCT runs `2px` vertical padding. Rail/panels should be tight.
5. **Thin meters read as instruments.** Our 14px ProgressBars are chunky; 4–6px bars
   look more like flight telemetry. Consider a tiny rolling sparkline behind COLLAPSE/BH.
6. **Status thresholds.** Use ok-green / caution-orange / critical-red semantics for the
   COLLAPSE→BH→FORMED progression (e.g. BH `FORMED` flips its value to a status color).
7. Their depth is dark drop-shadow restraint; we chose glow for the sim overlay — keep the
   glow but stay restrained (their whole UI proves restraint reads as "pro," clutter doesn't).
