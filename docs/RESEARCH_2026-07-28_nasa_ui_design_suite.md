# RESEARCH — How NASA Builds Interfaces: Full Design Suite (History → Today → What We Legally Take)

**Written:** 2026-07-28 11:26:52
**Question asked:** "full on design suite on how nasa develops ui, historically and today. our UI must be legal. no copyright bs. but everything that's for us to take we gotta learn."
**Status:** research only. No code changed. Supersedes and absorbs `docs/hud_design_brief.md` Appendix A (extracted 2026-06-27).
**Scope:** operational/flight interfaces (the cockpit + mission-control lineage), not nasa.gov marketing — except where the marketing system carries reusable rules.

---

## 0. One-line answer

NASA has never had a "look." It has a **written display standard with numbers in it**
(NASA-STD-3001 Vol 2, Appendix F), a **60-year habit of stripping decoration until only
meaning is left**, and **one shipped open-source implementation of that standard you can
legally copy line for line** (Open MCT, Apache 2.0). The logo is the only thing you can't
touch. Everything else is either public domain by statute or permissively licensed.

---

# PART I — THE HISTORY, AND WHAT EACH ERA ACTUALLY TEACHES

## 1. Apollo DSKY (1966–1972) — the constrained vocabulary

The Display and Keyboard was the entire astronaut↔computer interface: **19 buttons**, a
numeric keypad, a row of status lights, and three numeric registers. Built by Raytheon to
MIT Instrumentation Lab's design.

The whole interaction model was **VERB + NOUN**: verb = the action, noun = the data set
acted on. **99 verbs, 99 nouns**, both entered as two-digit codes. `VERB 16 NOUN 68` is not
a menu path — it's a sentence in a language with a 198-word dictionary.

**What it teaches us:**
- **A tiny orthogonal vocabulary beats a large menu.** Two axes (action × object) generate
  the whole command space combinatorially. Our HUD has the same shape available: a
  **section** (what am I looking at) × a **parameter** (what am I changing).
- **Always show the current mode.** The DSKY permanently displayed PROG / VERB / NOUN — the
  operator never had to remember what state the machine was in. Our HUD currently does not
  persistently show which regime the sim is in (play vs collapse vs BH-formed) in one fixed
  slot.
- **Status lights are separate from data.** Alarms had dedicated physical real estate. They
  never competed with the numbers for the same pixels.

## 2. Mission Control / MOCR (1965–1972) — role views + one shared truth

The Apollo Mission Control Center ran **140 consoles**, most with two high-resolution CRTs,
backed by **~350 group-display CRTs**, **7 Eidophor projectors**, and **5 seven-projector
Xenon plotting displays**. The centrepiece was the **"ten by twenty"** — a 10ft × 20ft
screen showing vehicle position and status via physical slides overlaid on plots.

Each flight controller had a **discipline-specific console**: FIDO saw trajectory, EECOM
saw environmental/consumables, GUIDANCE saw the computer. Nobody saw everything.

**What it teaches us:**
- **One shared "big board" + private detail views.** The big board is the sim itself; the
  panels are the consoles. The big board never gets cluttered with console-level detail —
  that's the whole architecture.
- **Group by discipline, not by widget type.** Our left rail (`SIM · BLACK HOLE · COLOUR ·
  GEOMETRY · FX · AUDIO · SEQUENCER`) is already a MOCR console split. Keep it.
- **One panel open at a time** is the console model, not a limitation.

## 3. Space Shuttle: round dials → MEDS (1981 → 2000) — the transition discipline

The Orbiter flew round-dial electromechanical gauges plus monochrome CRTs for two decades.
**MEDS** (Multifunction Electronic Display System, Honeywell) replaced them with **11 AMLCD
multifunction display units**, each with an R3000 processor and a graphics accelerator doing
**anti-aliased 2D/3D at 30 Hz**, interconnected over **four redundant MIL-STD-1553 buses**.
First flew on *Atlantis*, **May 2000**.

Two decisions matter:
1. **NASA first rendered the new glass displays as the OLD round dials** — deliberately
   familiar — so crews could transition without retraining. Only *afterwards* did the Shuttle
   operations community fully redesign the formats.
2. The redesigned formats **used colour specifically to manage attention** — off-nominal
   readings turn red — and moved from monochrome to graphics that matched the operators'
   mental models.

**What it teaches us:**
- **Ship the familiar thing first, redesign second.** Do not change the layout and the
  visual language in the same commit. (This is our own one-change-at-a-time rule with a
  20-year NASA precedent behind it.)
- **Colour is an attention allocator, not decoration.** A value that changes colour is a
  interrupt. If everything is coloured, nothing interrupts.
- **30 Hz was enough for a spacecraft cockpit.** Our HUD does not need to cost us frames.

## 4. The 1975 Graphics Standards Manual — Swiss systems thinking

In 1974 NASA commissioned Danne & Blackburn (NY) to build a unified identity. Delivered 1975,
in force **1975–1992**, revived 2020 for Demo-2. The system:

- a **rational grid** governing all layout
- **strict typographic hierarchy**
- **Helvetica as the single typeface**
- **consistent spacing and alignment rules**
- **removal of decorative or illustrative elements**

Administrator Truly's foreword: *"a feeling of unity, technological precision, thrust and
orientation toward the future."*

**What it teaches us:**
- **One typeface. Hierarchy from size/weight/colour only.** Our HUD brief already locks this
  (§4 of `hud_design_brief.md`), and ImGui effectively forces it.
- **Grid before pixels.** Every element position should be a multiple of one base unit, not a
  hand-nudged number.
- **"Removal of decorative elements" is the actual method.** Not "add a sci-fi look" — *remove
  until only meaning remains.* This is the direct antidote to our recurring "overlay feel"
  failure: the overlay feel is decoration that isn't carrying data.

---

# PART II — TODAY: THE WRITTEN STANDARD

## 5. NASA-STD-3001 Vol 2 + the HIDH

`NASA-STD-3001` (Space Flight Human-System Standard) **Vol 1** = crew health, **Vol 2** =
Human Factors, Habitability and Environmental Health. Together with the **Human Integration
Design Handbook (HIDH)** they replaced the old `NASA-STD-3000` Man-Systems Integration
Standards.

- **Vol 2 = requirements**, written as `shall` statements (e.g. *"Displays and controls shall
  be grouped according to purpose or function"*).
- **HIDH = rationale**, explicitly *not* a standard and *not* a requirement — it's the
  compendium of spaceflight history and lessons learned explaining *why* each `shall` exists.
  It follows the same section order as Vol 2.

**The split is worth stealing on its own:** a short list of hard rules, plus a separate
document that explains the reasoning and can be argued with. That is exactly what
`hud_design_brief.md` (rules) + this file (rationale) should be.

## 6. Appendix F — the actual NASA Display Standard (the goldmine)

This is the concrete, numeric display standard. Verbatim/near-verbatim extract:

### 6.1 Colour (F.5)
| Level | Colour | Meaning |
|---|---|---|
| Emergency (E) | **Red** | immediate threat, urgent action |
| Warning (W) | **Red** | serious condition, prompt attention |
| Caution (C) | **Yellow** | non-critical, awareness required |
| Advisory (A) | **Blue** | informational |
| — | **Green** | normal / safe |

- *"Color must be used to convey meaning, and not for decoration or aesthetic purposes."*
- Contrast **≥ 6:1, 10:1 preferred**.
- *"Reverse video must be reserved for events that require immediate crew attention."*

### 6.2 Text & fonts (F.5.1)
- ASCII character set; **sans-serif required**.
- Character height **≥ 0.25° of visual angle, ≥ 0.4° preferred**.
- **Numeric/tabular data → fixed-width font. Narrative → proportional font.**
- Non-acronym text **must be mixed case** (not ALL CAPS).

### 6.3 Labelling (F.5.2)
- Labels **left of** the data, or **above** in columnar layouts.
- Wording and grammatical structure consistent across displays.
- Horizontal preferred; vertical labels rotated **counter-clockwise**.
- Every data field label appears with its value.

### 6.4 Numeric formatting (F.5.6)
- Same parameter → identical units everywhere.
- Units shown per value or per value group.
- **Leading zero mandatory** for |x| < 1 → `0.42`, never `.42`.
- **Minus sign always displayed** for negatives.
- **Comma at ≥ 5 digits** → `XX,XXX.YY`.

### 6.5 Layout (F.4.2)
- *"Layout of information on a display must support task flow."*
- Recurring fields in **consistent relative positions** across displays.
- Related items grouped in close proximity.
- Navigation menu at **top or bottom**.
- Every display has a **unique title in a consistent location**.

### 6.6 Telemetry integrity indicators (F.4.3.1) — the part almost nobody implements
- Threshold violation → **yellow or red up/down arrow following the value**.
- Data overflow → **every character of the field replaced by yellow asterisks**.
- **Stale data must be indicated.**
- Off-scale values indicated when needed to address a malfunction.

### 6.7 Command safeguards (F.4.3.2)
- Critical/safety ops require **≥ 2 independent commands**.
- Irreversible actions → confirmation dialog or equivalent.
- Hazardous commands → **black and yellow diagonally striped border**.
- Positive indication of control activation (feedback on every press).

### 6.8 Time (F.6.1)
- Format **`label dddd/hh:mm:ss`** → e.g. `MET 57/14:08:33`.
- **24-hour clock mandatory.** Leading zeros suppressed in the day field.
- **Every time must be labelled with its system** (GPS, PET, MET…).

### 6.9 Flashing (F.5.11)
- Low priority: **0.8 Hz, 70% duty on**.
- High priority: **3 Hz, 50% duty on**.
- **Synchronised across all display units.**
- Crew-terminable after **10 s**.

## 7. Orion — the current flight practice

Orion's glass cockpit carries **60+ GUI display formats** plus interactive electronic
procedures — a first in spacecraft history — with fully redundant crew controls and displays.
NASA wrote a program-specific standard on top of 3001: **Orion Program Display Format
Standards (CxP 72242)**. Formats were built in **DiSTI GL Studio**.

The Human Factors process behind it (Ames Intelligent Spacecraft Interface Systems Lab) is
measurement-driven: **eye-movement analysis** plus **switch throws, key presses, hand-control
inputs, latencies, error rates, and subjective workload ratings (NASA-TLX)**, run against
off-nominal scenarios during dynamic flight phases.

**What it teaches us:** they don't argue about the design — they instrument the operator and
count errors and latencies. Our equivalent is cheap: how long does it take Jamal to find the
control he wants, and how often does he grab the wrong slider.

## 8. Open MCT — the shipped, copyable implementation

`nasa/openmct` — web mission-control framework from **NASA Ames**, used for real spacecraft
data analysis and rover ops. **Apache License 2.0**, *"Copyright (c) 2014-2024, United States
Government as represented by the Administrator of the National Aeronautics and Space
Administration."*

This is Appendix F rendered as actual CSS. Tokens pulled from source **2026-07-28** (this is
newer than our 2026-06-27 extraction — there are now **four** themes, and two we'd never seen):

### 8.1 Themes
`espresso` (mid-grey), `snow` (light), `maelstrom`, **`darkmatter`** ← the dark one, and the
one closest to our problem.

### 8.2 Key colour — one accent, per theme
| token | espresso | darkmatter |
|---|---|---|
| `$colorKey` | `#03ace4` | `#1c67e3` |
| `$colorKeyBg` | `#007fad` | `#015fca` |
| `$colorBodyBg` | `#2c2c2c` | **`#17171b`** |
| `$colorBodyFg` | `#acacac` | `#aaaaaa` |
| `$colorBodyFgSubtle` | `#9c9c9c` | `#9c9c9c` |
| `$colorBodyFgEm` | `#fff` | `#fff` |

**One key colour drives every interactive/active state in the entire application.**

### 8.3 Interaction states are accent-alpha, never white-alpha
```
$colorSelectedBg:      rgba($colorKey, 0.3)
$colorInteriorBorder:  rgba($colorBodyFg, 0.2)
$colorTabCurrentBg:    rgba($colorKey, 0.71)     // darkmatter
$filterHov:            brightness(1.3) contrast(1.5)
$filterHovSubtle:      brightness(1.2) contrast(1.2)
```

### 8.4 Status semantics (identical across both themes)
```
$colorStatusInfo:   #60ba7b     $colorStatusFg:      #888
$colorStatusAlert:  #ffb66c     $colorStatusDefault: #ccc
$colorStatusError:  #da0004
$colorAlert:        #ff8a0d     $colorError:  #ff3c00
$colorOk:           #1f851f (espresso) / #33cc33 (darkmatter)
$colorStatusPartialBg:  #3f5e8b     $colorStatusCompleteBg: #457638
```

### 8.5 The limit ladder — 4 levels, not 3 (darkmatter)
This is Appendix F's threshold system as real tokens. Each level has **bg / fg / icon**:
```
yellow   bg #b18b05   fg #feeeb5   ic #fdc707
orange   bg #b36b00   fg #ffe0b2   ic #ff9900
red      bg #b60109   fg #ffa489   ic #ff4222
purple   bg #891bb3   fg #edbeff   ic (violation beyond red)
stale    $colorTelemStale: cyan     $colorTelemStaleFg: #002a2a
```
**Stale data gets its own colour that is in no other semantic slot.** That's the F.4.3.1
"stale data must be indicated" requirement made concrete.

### 8.6 Dimensions — the density scale
```
$interiorMarginSm:  3px      $interiorMargin: 5px      $interiorMarginLg: 10px
$inputTextPTopBtm:  2px      $inputTextPLeftRight: 5px
$smallCr: 2px   $controlCr: 3px   $basicCr: 4px        // corner radii — TINY
$shellMainBrowseBarH: 22px   $shellTimeConductorH: 25px  $shellToolBarH: 29px
$tabularHeaderH: 22px        $tabularTdPadTB: 2px        $itemPadLR: 5px
$progressBarMinH: 4px        $plotSwatchD: 12px          $controlBarH: 25px
$plotYBarW: 60px  $plotXBarH: 32px  $plotLegendH: 20px   $plotMinH: 95px
$formLabelMinW: 120px        $tagBorderRadius: 3px       $bubbleMaxW: 300px
```

### 8.7 Depth is dark shadow, not glow
```
$shdwBtns:        rgba(black, 0.2) 0 1px 2px
$shdwBtnsOverlay: rgba(black, 0.5) 0 1px 5px
$shdwMenu:        rgba(black, 0.8) 0 2px 10px
$shdwMenuInner:   inset 0 0 0 1px rgba(white, 0.2)
$shdwSelect:      rgba(black, 0.5) 0 0.5px 3px
$shdwBtnHov:      inset rgba(white, 10%) 0 0 0 100px
```

### 8.8 Darkmatter's typography — four roles, one of them numeric
```
$heroFont:    'Teko', sans-serif
$headerFont:  'Cabin Condensed', sans-serif
$bodyFont:    'Exo', sans-serif
$numericFont: 'Chakra Petch', sans-serif      // "temporary numeric font"
```
**A dedicated numeric typeface is a separate role from body text.** That is Appendix F
§F.5.1 ("numeric/tabular → fixed-width") taken seriously. Our HUD is ~80% numbers and
currently renders all of them in the same proportional Roboto-Medium as the labels.

## 9. NASA's public-facing systems (secondary, but two rules are reusable)

- **NASA Web Design System** — a NASA skin over the **U.S. Web Design System**. Its stated
  principles: *"Make the best thing the easiest thing" · "Offer accessibility out of the box"
  · "Design for flexibility" · "Showcase benefits" · "Reuse, reuse, reuse."*
- **Horizon Design System (HDS)** — the current nasa.gov system. Three families: **Inter**
  (display/headings), **Public Sans** (body), **DM Mono**. Palette explicitly built to meet
  **Section 508 contrast**.
- **Eyes on the Solar System / DSN Now** (JPL) — the closest public precedent to what we're
  building: **a real-time 3D scene with telemetry chrome on top**, 126 spacecraft rendered,
  DSN Now refreshing every **5 s**. Worth studying purely as "how much chrome can sit over a
  live 3D scene before it stops being the scene."

---

# PART III — LEGAL CLEARANCE MATRIX

**The rule of thumb:** the *ideas, rules and numbers* are free; the *code* is Apache-2.0 with
attribution; the *logo* is untouchable.

| Asset | Status | Can we use it? | Obligation |
|---|---|---|---|
| **NASA-STD-3001, HIDH, Appendix F** — rules, numbers, tables | US Gov work, **17 U.S.C. §105: no copyright** | ✅ **Yes, freely** | none (cite anyway, it's good practice) |
| **Design principles, layout logic, colour semantics** (red=warning etc.) | ideas/facts — not copyrightable in any jurisdiction | ✅ **Yes** | none |
| **Open MCT source, SCSS token values, component logic** | **Apache License 2.0** | ✅ **Yes, incl. commercial & closed-source** | retain copyright notice + license text, state changes, ship a `NOTICE`/`THIRD_PARTY_LICENSES` |
| **USWDS code/assets** | **CC0 1.0 public domain dedication** (a few parts excepted, see their `LICENSE.md`) | ✅ **Yes** | none for the CC0 parts; check the exceptions |
| **NASA imagery/photos** | released under **NASA Media Usage Guidelines** | ⚠️ **Generally yes** | must not imply NASA endorsement |
| **NASA insignia ("meatball"), worm logotype, wordmark, program identifiers, seal, flags** | **14 CFR Part 1221 — explicitly NOT public domain, protected by law** | ❌ **NO** | merchandise/other use requires written approval from NASA Office for Communications; **no approval is ever granted where use could be construed as endorsement** |
| **The name "NASA" as a product descriptor** | trademark-adjacent; Apache 2.0 **§6 grants no trademark rights** | ❌ Don't brand with it | never say "NASA-powered/NASA-approved". "Built to NASA-STD-3001 display conventions" is a factual statement and fine |
| **NOSA-licensed NASA code** (NASA Open Source Agreement 1.3/2.0) | OSI-approved but idiosyncratic, poorly accepted, awkward compatibility | ⚠️ **Avoid** | prefer the Apache-2.0 NASA projects; Open MCT is Apache 2.0 so we're clear |
| **Helvetica** (the 1975 manual's typeface) | commercial licence, Monotype/Linotype | ❌ **Do not ship** | use Inter / Public Sans / Roboto instead |
| **Inter, Public Sans, DM Mono, Exo, Teko, Chakra Petch, Cabin Condensed** | **SIL OFL 1.1** | ✅ **Yes — bundle/embed in a commercial app** | ship the OFL text; don't sell the font alone; don't reuse Reserved Font Names on modified versions |
| **Roboto-Medium** (already in `third_party/imgui/misc/fonts/`) | **Apache 2.0** | ✅ already fine | keep the notice |

### The three traps, stated plainly
1. **The logo is the trap.** Everything else about NASA is essentially free; the meatball and
   the worm are the exceptions carved out by federal regulation. Never put either in the app,
   the splash, the icon, or a screenshot.
2. **Apache 2.0 is not "public domain."** If we lift Open MCT's literal token values or port a
   component, we owe attribution. Cost: one text file. Do it and stop thinking about it.
3. **"Looks like mission control" is not infringement. "Looks like it IS mission control" is
   the risk.** Never imply affiliation or endorsement.

### Concrete compliance action (when we ship anything derived)
Create `THIRD_PARTY_LICENSES.md` at repo root containing: Dear ImGui (MIT), Roboto (Apache
2.0), and — if we port any Open MCT values/components — the Open MCT copyright line + Apache
2.0 text + a "changes made" note. That's the whole obligation.

---

# PART IV — WHAT WE TAKE, AS RULES

Ranked by how much they'd change what's on screen today.

### RULE 1 — One accent colour, reserved for interaction. Data owns the rest.
Open MCT drives an entire mission-control application off a single `$colorKey`. Our indigo
`#6696FF` is that key. **Chrome stays monochrome; colour on a value means the value is
saying something.** (Appendix F: *"Color must be used to convey meaning, and not for
decoration."*)
→ *Current state:* our accent is already single, but `ImGuiCol_ButtonActive` is the only
place it's used; hover/active states are **white-alpha** (`ui_theme.h:39-45,51-52`).

### RULE 2 — Hover/active = accent at low alpha, not white at low alpha.
`$colorSelectedBg: rgba($colorKey, 0.3)`. Our `FrameBgHovered/Active` and
`HeaderHovered/Active` are all `ImVec4(1,1,1,α)`. Swapping those to indigo-alpha is a
~6-line change in `ui_theme.h` and is the single highest-ratio visual fix in this document.

### RULE 3 — Adopt the 4-level limit ladder + stale.
Not "ok/bad". **yellow → orange → red → purple**, each with bg/fg/icon, plus **cyan = stale**.
Our COLLAPSE → BH → FORMED progression is exactly a limit ladder and currently renders as
flat coloured text.

### RULE 4 — Numbers get their own typeface, and it is fixed-width.
Appendix F F.5.1 (*fixed-width for tabular*) + darkmatter's `$numericFont`. Every telemetry
value in the top bar is currently proportional Roboto-Medium, so digits jitter horizontally
as they update — the classic tell. `third_party/imgui/misc/fonts/` already ships
**Cousine-Regular.ttf**, a metric-compatible monospace (Steve Matteson / Google, Apache 2.0
per upstream Dear ImGui's `misc/fonts/README.txt`). **Zero new dependencies, zero licence
risk.** ⚠️ Verified 2026-07-28: our vendored copy of that directory ships the `.ttf` files
**without** the upstream README/licence text — that needs adding to
`THIRD_PARTY_LICENSES.md` whether or not we switch fonts.

### RULE 5 — Density. Our padding is 3–5× mission control's.
| | ours (`ui_theme.h`) | Open MCT | delta |
|---|---|---|---|
| Frame padding | `10 × 8 px` | `5 × 2 px` | **~4× too fat** |
| Item spacing | `12 × 10 px` | `5 px` (`$interiorMargin`) | **~2–2.5× too fat** |
| Window padding | `16 px` | `10 px` (`$interiorMarginLg`) | 1.6× |
| Frame rounding | `5 px` | `3 px` (`$controlCr`) | 1.7× |
| Window rounding | **`14 px`** | `4 px` (`$basicCr`) | **3.5×** |
| Progress bar height | ImGui default ~`14 px` | **`4 px` min** | **3.5× too chunky** |
| Bar/header heights | ad-hoc | `22 / 25 / 29 px` | we have no scale |

That 14px window rounding is the single most "consumer app" number in our theme. Mission
control rounds at 2–4px.

### RULE 6 — Adopt a spacing scale and never type a raw pixel again.
`3 / 5 / 10` interior margins, `2 / 3 / 4` corner radii, `22 / 25 / 29` bar heights.
Three numbers per axis. This is the 1975 manual's grid discipline in modern form.

### RULE 7 — Depth = dark shadow, not glow. (Adapted, not adopted.)
Open MCT: `rgba(black, 0.2) 0 1px 2px`. **But** they composite on an opaque background and we
composite over a luminous sim — a dark shadow over black particles is invisible. We keep the
layered-glow approximation from `hud_design_brief.md` §1, and we take the *restraint*: their
whole UI proves restraint reads as professional. **This is the one rule we consciously
diverge from, and the reason is physical, not aesthetic.**

### RULE 8 — Label every time value with its system, and format it `dddd/hh:mm:ss`.
Our top bar reads `UNIVERSE <clock> <unit>`. Appendix F would write it as a labelled,
zero-padded, 24-hour, fixed-field clock. Given our clock has been **wrong twice** (the c³
error, the framerate-dependent time-lapse), a rigid unambiguous format is a debugging tool,
not just polish.

### RULE 9 — Numeric formatting rules, applied everywhere.
Leading zero below 1 (`0.42`). Minus sign always shown. Comma at ≥5 digits. Units per value
or per group, never mixed for the same parameter. **`M☉` must mean `M☉` on every panel.**

### RULE 10 — Consistent relative position beats compact layout.
F.4.2: recurring fields sit in the same place on every display. If FPS is top-right in one
panel it is top-right in all of them. Never reflow to save space.

### RULE 11 — Ship familiar first, redesign second. (The MEDS transition.)
When we restyle the HUD: **change the visual language OR the layout, never both in one
build.** Otherwise no verdict is attributable. This is our one-change-at-a-time rule with
NASA's own 20-year precedent.

### RULE 12 — "Removal of decorative elements" is the method.
Danne & Blackburn's actual instruction. Every HUD element must answer *what data am I
carrying?* If the answer is "it looks good," delete it. This is the same failure mode as the
painted BH disc — **decoration that isn't carrying information reads as an overlay.**

### RULE 13 — Instrument the operator, don't argue about the design.
NASA measures switch throws, key presses, latencies, error rates, NASA-TLX. Our version:
count how often Jamal opens the wrong panel or grabs the wrong slider. Cheap, and it settles
arguments.

### RULE 14 — Two axes, not a menu tree. (DSKY.)
Section × parameter. And **always show the current mode in a fixed slot** — the DSKY never
made the crew guess what state the computer was in. Our HUD has no permanent regime
indicator.

---

# PART V — OPEN QUESTIONS FOR JAMAL

1. **Theme direction:** darkmatter's `#17171b` body + `#1c67e3` key is close to our
   `#08090E` + `#6696FF`. Do we converge onto mission-control blue, or keep our indigo?
   *(Recommendation: keep indigo. It's ours, it's already coherent, and it reads better over
   an orange/white accretion disc than a blue key does.)*
2. **Density pass:** RULE 5 is a single-file change to `ui_theme.h` with no behaviour risk.
   Do you want it as the first verifiable increment?
3. **Numeric font:** switch telemetry values to Cousine (already vendored, Apache 2.0)?
   It stops the digit-jitter on every updating number.
4. **Limit ladder:** is COLLAPSE→BH→FORMED worth rendering as a real 4-level ladder, or is
   that HUD work we're deferring until the BH render settles?

**Nothing in this document has been implemented. No code changed.**

---

## Sources

- [Smithsonian NASM — Keyboard, Display (DSKY), Apollo Guidance Computer](https://airandspace.si.edu/collection-objects/keyboard-display-dsky-apollo-guidance-computer/nasm_A19760744000)
- [Discover — How Verbs and Nouns Got Apollo to the Moon](https://www.discovermagazine.com/how-verbs-and-nouns-got-apollo-to-the-moon-963)
- [Hack the Moon — The Amazing DSKY](https://wehackthemoon.com/tech/amazing-dsky-leapfrog-computer-science)
- [Hendrickson 1967 — The display/control complex of the Manned Space Mission Control Center (SID, Information Display)](https://sid.onlinelibrary.wiley.com/doi/full/10.1002/j.2637-496X.1967.tb01263.x)
- [NASA — Apollo Mission Control Center Restoration](https://www.nasa.gov/johnson/history/apollo-mcc-restoration/)
- [NASA Langley — Glass Cockpit Fact Sheet](https://www.nasa.gov/centers/langley/news/factsheets/Glasscockpit_prt.htm)
- [Aviation Today — The Space Shuttle, Modernized (MEDS)](https://www.aviationtoday.com/1999/11/01/the-space-shuttle-modernized/)
- [IEEE — High-performance AMLCD-based "smart" display for the Space Shuttle glass cockpit](https://ieeexplore.ieee.org/document/369469/)
- [NASA — NASA-STD-3001 and the Human Integration Design Handbook (NTRS 20130000738)](https://ntrs.nasa.gov/api/citations/20130000738/downloads/20130000738.pdf)
- [NASA-STD-3001 Vol 2 Rev E (standards.nasa.gov)](https://standards.nasa.gov/system/files/tmp/NASA-STD-3001%20Vol%202%20Rev%20E_1.pdf)
- [NASA — Appendix F: Display Standard (Vol 2)](https://www.nasa.gov/reference/appendix-f-vol-2/)
- [NASA Human Systems Integration Division — Cockpit Display Design / Intelligent Spacecraft Interface Systems](https://www.nasa.gov/human-systems-integration-division/cockpit-display-design-intelligent-spacecraft-interface-systems/)
- [DiSTI — NASA Orion cockpit display case study (60+ GUI formats, CxP 72242)](https://www.disti.com/case-study/nasa-orion)
- [GitHub — nasa/openmct](https://github.com/nasa/openmct)
- [Open MCT LICENSE.md (Apache 2.0)](https://github.com/nasa/openmct/blob/master/LICENSE.md)
- [Open MCT `_constants-darkmatter.scss`](https://github.com/nasa/openmct/blob/master/src/styles/_constants-darkmatter.scss)
- [Open MCT `_constants-espresso.scss`](https://github.com/nasa/openmct/blob/master/src/styles/_constants-espresso.scss)
- [Open MCT `_constants.scss`](https://github.com/nasa/openmct/blob/master/src/styles/_constants.scss)
- [NASA Web Design System — Design Principles](https://nasa.github.io/nasawds-site/design-principles/)
- [U.S. Web Design System (CC0)](https://github.com/uswds/uswds)
- [BLINK UX — Reimagining NASA.gov / Horizon Design System](https://blinkux.com/work/nasa-case-study)
- [NASA/JPL — Eyes on the Solar System](https://eyes.nasa.gov/apps/solar-system/)
- [JPL — Explore the Solar System With NASA's New-and-Improved 3D 'Eyes'](https://www.jpl.nasa.gov/news/explore-the-solar-system-with-nasas-new-and-improved-3d-eyes/)
- [eCFR — 14 CFR Part 1221.1, NASA Seal, Insignia, Logotype](https://www.ecfr.gov/current/title-14/chapter-V/part-1221/subpart-1221.1)
- [eCFR — 14 CFR 1221.110, Use of the NASA Insignia](https://www.ecfr.gov/current/title-14/chapter-V/part-1221/subpart-1221.1/section-1221.110)
- [NASA Brand Center — Brand Guidelines](https://www.nasa.gov/nasa-brand-center/brand-guidelines/)
- [Standards Manual — 1975 NASA Graphics Standards Manual](https://standardsmanual.com/products/nasa-graphics-standards-manual)
- [We Are The Mutants — "Unity, Precision, Thrust": The NASA Graphics Standards Manual, 1975](https://wearethemutants.com/2020/01/09/unity-precision-thrust-the-nasa-graphics-standards-manual-1975/)
- [Wikipedia — NASA Open Source Agreement](https://en.wikipedia.org/wiki/NASA_Open_Source_Agreement)
- [SIL Open Font License](https://en.wikipedia.org/wiki/SIL_Open_Font_License)
- [Inter LICENSE.txt (OFL 1.1)](https://github.com/rsms/inter/blob/master/LICENSE.txt)
