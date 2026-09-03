# DESIGN — MIDI CC MAPPING, MACROS, ABLETON LINK
**Written:** 2026-09-03 05:38:07 · OPUS window · **DESIGN ONLY — zero source lines written, no build run, nothing launched.**

> **HIS CONSTRAINT, VERBATIM (2026-09-03, relayed by BRAIN):**
> *"this include sveery parameter in the ui. i dont want ay faders moved from this. they should just be mappable."*
> ⇒ **Every UI parameter mappable. NOTHING in the UI moves, is renamed, regrouped or re-scaled.**

> ## ✅ HIS RULINGS — 2026-09-03 ~05:50, relayed by BRAIN
> 1. **TEMPO = MODULATION ONLY.** Tempo may drive modulation of the mapped dials. It **NEVER touches
>    `uiIscoSeconds` or any physics clock.** ⛔ The 2026-08-28 camera ruling stands untouched — **no
>    tempo term goes into `camera.h`.** (§6's open question is CLOSED.)
> 2. **MIDI CLOCK FOR COLOGNE. ABLETON LINK AFTER THE SHOW.** My §6.3 recommendation, taken as given.
>    ⛔ **Vendor nothing.** BRAIN re-verified zero Link hits in `src/` (the only "Ableton" string is a
>    meter-styling comment, `main.cpp:1411`).
> 3. **CONTROLLER: "both / not decided yet."** ⇒ **design for BOTH.** Pickup/takeover logic is
>    **BUILT but BYPASSED** for relative encoders. The hardware is not fixed, so **the design must not
>    assume it.** (§8 q2 is CLOSED as "assume neither".)
>
> **Parser allocation, his call:** SONNET writes the fix, FABLE builds it. **Not mine, not blocked on me.**
> **This doc stays UNTRACKED — no commit order given.**

> ## 📍 TREE STATE THESE CITATIONS WERE VERIFIED AGAINST — read before trusting any `file:line`
> **Verified 2026-09-03 06:15:18 against the WORKING TREE at `6530c45` PLUS four uncommitted changes:**
> `src/main.cpp` (+11, FABLE's `SS_PHASE_AMOUNT` TEMP-DIAG at `:386-396`), `src/core/midi_input.mm`
> (SONNET's Real-Time guard), `src/render/render.metal` + `src/render/renderer.mm` (FABLE, +22).
> 🚨 **THE TREE MOVED UNDER FOUR WINDOWS WHILE ALL FOUR WERE WORKING IN IT.** Tonight `main.cpp`
> gained +11 and `renderer.mm` +22 **mid-session**. Every `main.cpp` number below `:396` in an earlier
> version of this file was **correct when written and is +11 stale** — that is **DRIFT, NOT ERROR**,
> and the two must not be confused: ⚠️ a constant offset across many citations is the **signature of
> drift**; invention does not produce a uniform offset. The failure mode this line exists to prevent
> is **a careful window concluding its own evidence was fabricated** — which nearly happened tonight
> to twelve `renderer.mm` citations that were all off by exactly +22.
> ⇒ **A `file:line` is only true against a stated tree state. Re-grep, never re-derive, never renumber by arithmetic alone.**

> ## 🚨🚨 SCOPE CHANGED 2026-09-03 16:14:13 — THIS IS NOW THE HIGHEST-PRIORITY BUILD, AND THE REQUIREMENT MOVED
> **His order, verbatim, relayed by BRAIN:**
> *"The midi cc mist work so well that i can compose rides and fades accurately"*
> *"Set both melodies and chords and the midi cc as automations in ableton. Have the app 'read' the midi and render accordingly."*
> *"This is the most improtant build of the project. Highest prio."*
>
> ⚠️ **THIS IS A DIFFERENT PROBLEM FROM THE ONE §1-§8 SOLVE, AND THE DIFFERENCE IS NOT SIZE — IT IS THE CLOCK.**
> §1-§8 solve *"every UI parameter is mappable from a controller"*: a message arrives, you apply it, **his hand
> is the clock** and frame-accuracy is meaningless. His order needs *"CC automation authored on a timeline,
> applied accurately against that timeline"* — **each event belongs at a known OUTPUT FRAME.**
> ⭐ **The structure below SURVIVES: `Mapping`, the three target kinds (§1.2), apply-outside-`showHUD` (§1.5),
> the registry (§3.3). What changes is the SOURCE and the CLOCK — see §10.**

> **Cold start:** this file is a design, not state. State is `docs/BOARD_BLACKHOLE.md` §AD → §AC.12.
> Every claim below is tagged `[READ file:line]`, `[MEASURED]` or `[HYPOTHESIS]`. Untagged = my reasoning over tagged facts.

---

## 0. THE HEADLINE — THE CONSTRAINT IS ALREADY SATISFIED BY THE EXISTING CODE

`[READ main.cpp:31-36]` The codebase already contains a **universal choke point for every fader**:

```
// Drop-in replacements for ImGui::SliderFloat/Int that turn into a text input
// box on DOUBLE-CLICK (ImGui natively only allows Ctrl+Click). Same signature
// + defaults as the ImGui versions, so call sites are unchanged.
static bool UiSliderFloat(...)   // main.cpp:37
static bool UiSliderInt(...)     // main.cpp:56
```

`[READ, counted]` **56 call sites** route through `UiSliderFloat`, **5** through `UiSliderInt`.
Each one already hands the wrapper the exact tuple a MIDI mapping needs: **`label` (identity), `v` (target), `v_min`/`v_max` (range), `flags` (curve).**

**This is the whole answer to his constraint.** Mapping is added *inside* those two functions.
**Zero call-site edits. Zero layout change. Zero pixel moves. No fader touched.**
And the precedent is already shipped and proven: `UiSliderFloat` *already* intercepts its own
widget (double-click → `InputFloat`) without any call site knowing.

⭐ This is not a plan to make the UI mappable. It is the observation that **the UI was built
mappable and nobody has read the choke point yet.**

---

## 1. THE MAPPABLE SURFACE — A CENSUS, NOT AN ESTIMATE

`[READ, grep-counted at HEAD 6530c45]`

| Widget class | Sites | Routes through a helper? | Work to make mappable |
|---|---|---|---|
| `UiSliderFloat` | **56** | ✅ yes (`main.cpp:37`) | **none at the call site** |
| `UiSliderInt` | **5** | ✅ yes (`main.cpp:56`) | **none at the call site** |
| `ImGui::SliderInt` **raw** | **1** — `main.cpp:1563` *"Physics substeps"*, target `&app.uiPhysicsSubsteps` | ❌ **BYPASSES the helper** | one word: `ImGui::SliderInt` → `UiSliderInt` |
| `ImGui::SliderFloat2` **raw** | **1** — `main.cpp:1885` *"E%d XY"* (emitter position) | ❌ **BYPASSES, and no `UiSliderFloat2` exists** | **not a rename — a wrapper that does not exist yet.** See §1.2 |
| `ImGui::Checkbox` | **24** | ❌ no wrapper exists | add `UiCheckbox`, rename 24 sites |
| `ImGui::Combo` | **2** — `main.cpp:1948` "Wave", `main.cpp:2133` "Mirror" | ❌ no wrapper | add `UiCombo`, rename 2 sites |
| `ImGui::Button` | **17** | ❌ no wrapper | add `UiButton`, rename 17 sites — **Note-On class, not CC** |

**Total continuous widgets: 63** (61 wrapped + 2 raw), yielding **64 mappable values** — `:1885` is
one widget carrying two. Binary: 24. Enum: 2. Momentary: 17.

↩️ **CENSUS CORRECTED 2026-09-03 05:52:04 — I had one bypass too few, and the miss was my grep's
fault, not a judgement call.** I searched `ImGui::SliderFloat(` **with the open paren**, which
excludes `ImGui::SliderFloat2(` **by construction**. BRAIN caught `:1885`. I then re-ran the census
**without any paren filter** across every value-writing ImGui widget — `Slider|Drag|Input|VSlider|Color|Checkbox|Combo|Radio|ListBox|Selectable` — and **`:1885` is the only thing either of us missed.** The rest verified exactly. **Lesson worth keeping: a grep pattern that ends in `(` silently hides every numbered variant of a widget.**

⚠️ **A rename is not a move.** `ImGui::Checkbox("Phase Viz", &x)` → `UiCheckbox("Phase Viz", &x)`
changes no label, no position, no order, no range, and renders identical pixels — the same way
`UiSliderFloat` already does. If he reads "rename" as "moved", **the checkboxes are droppable and
the 61 faders still all map.** That is his call, not mine.

⚠️ `[READ app_state.h]` AppState holds **56 float / 37 bool / 6 int** `ui*` fields, but the
mappable surface is defined by **widgets, not fields**. Several bools have no widget at all — the
9-symbol rotation subsystem is the proven case (`[READ, verified at 9fa4191]`, board §AD). **Do not
size this job off the field census.**

### 1.2 THREE TARGET KINDS — `[MEASURED by grep, at HEAD]` — and only one is easy

Not every wrapped slider writes a stable pointer. Classified all 61 wrapped call sites by target:

| Kind | Count | Target | Consequence for mapping |
|---|---|---|---|
| **A — stable `&app.ui*`** | **57** | a field of the static `AppState` | ✅ pointer is valid forever; the easy case |
| **B — temp + setter** | **4** | `##MasterVol` `:1102` → `synth.setMasterVolume()`; `LFO Rate##Chorus` `:1965`, `LFO Depth##Chorus` `:1969`, `Chorus Mix` `:1973` → `synth.chorus().setX()` | ⚠️ value is a **stack temporary** read from a getter each frame and pushed back through a **setter**. **A stored pointer is a dangling pointer.** Apply must call the setter. |
| **C — dynamic identity** | **1 widget / 2 values** | `:1885` `E%d XY` — inside `for (i < numVoices)`, `numVoices = activeVoices.size()`, `PushID(i)`, label **generated by `snprintf`**, target a `float pos[2]` temporary copied into `emitters[i]` | 🚨 label, count **and** target all vary at runtime |

⚠️ **The 3 Chorus sliders are also inside `if (app.uiChorus)` (`:1962`)** — they are not drawn at all
when Chorus is off. That is the same class of problem as §3.0 below, arriving from a second direction.

---

## 1.5 🚨 A FLAW IN MY OWN §3 — FOUND 2026-09-03 05:52:04, MINE, AND IT IS THE MOST IMPORTANT LINE IN THIS DOC

**"Mapping goes inside the helper" is right about WHERE TO REGISTER and WRONG ABOUT WHERE TO APPLY.**

`[READ main.cpp:1119 … :2257]` The entire mod menu is wrapped in **`if (showHUD) { … }`**, and
`[READ :1097-1099]` the **"HIDE ARCHITECT"** button sets `showHUD = false`. `[READ, counted]` there are
**16 `ImGui::CollapsingHeader`s**, each of which skips its whole body when collapsed, plus
conditional gates like `if (app.uiChorus)` (`:1962`).

**A helper only runs when its widget is drawn. So an apply-inside-the-helper design means:**
- 🚨 **Hide the HUD — the performance case — and EVERY MAPPING GOES DEAD.**
- Collapse a header, and those params go dead.
- Turn Chorus off, and its three dials go dead.
- Drop a voice, and that emitter's mapping goes dead.

**This would have shipped as "my controller does nothing once I hide the menu."** It is exactly the
failure the *[A COMMENT IS NOT A MECHANISM]* family keeps producing — I verified the helper was a
**choke point for drawing** and asserted it was therefore a choke point for **control**. Those are
different claims and I did not check the second one. **The choke-point thesis survives; my apply site does not.**

### The correction — REGISTER in the helper, APPLY in the frame loop

```
UiSliderFloat(label, v, min, max, flags)          // unchanged signature, unchanged pixels
   └── registry.publish(label, v, min, max, flags)  // ← the ONLY new line at the choke point
       (Kind B additionally publishes its setter; Kind C publishes per-index)

frame loop, OUTSIDE and BEFORE the `if (showHUD)` block:
   drain the MIDI inbox → for each mapping → write through the registry entry
```
**Apply then runs whether or not anything is drawn.** Still zero call-site edits for the 57.

⚠️ **The residual hole, stated rather than papered over:** a registry populated *by drawing* cannot
contain a widget that has **never been drawn** (HUD hidden since launch, header never opened).
**Recommendation:** seed the registry with **one UI build pass at startup with all headers forced
open and rendering suppressed** — costs one frame at launch, touches no call site, moves no fader,
and needs no hand-maintained table. ⛔ I am explicitly **not** proposing a static
`{label, &field, min, max}` table: that is hand-synced, and this repo has been bitten by exactly that
twice (`PhysicsUniforms` ~40 unguarded fields, `PostFXUniforms` 4 bytes out of sync).
🔴 **HIS QUESTION, QUEUED — and the design is written so EITHER answer drops in without a rewrite.**
It is the one place where *"no fader moved"* and *"every param mappable with the HUD hidden"* pull
against each other. The registry (§3.3) is identical either way; **only how it gets populated differs:**

| If he says… | What changes | What he gets |
|---|---|---|
| ✅ **YES to a seeding pass** | one extra UI build at startup — all headers forced open, rendering suppressed, `showHUD` ignored. **~10 lines in the frame loop, still zero call sites.** | **every mapping live from launch**, HUD never opened |
| ⛔ **NO** | nothing added. The registry fills as widgets are drawn, and `Mapping`s to unseen targets are **inert but preserved** (`registry.find` misses → skip, §3.4) | mappings go live **per panel, the first time he opens it** — one pass through the menu at soundcheck arms everything for the night |

⭐ **The NO branch is not a broken design — it is a soundcheck step**, and it is worth saying plainly
that it costs him one menu sweep before the show rather than a feature. **Neither branch changes a
struct, the apply loop, or a single call site.** ⇒ **this question does not block building anything;
it only decides whether a startup pass is added at the end.**

---

## 2. 🚨 THE HARD DEPENDENCY — THE PARSER. RULED HERE.

**Everything in §1 is inert until `src/core/midi_input.mm` can see a CC.** It cannot. Ruling:

### 2.1 F1 — System Real-Time over-consumes 2 bytes `[READ :46-49]` — SONNET's find, CONFIRMED

```c
uint8_t type = status & 0xF0;                     // :28
...
} else if (type >= 0xC0 && type <= 0xDF) { j += 2; // :46-47
} else if (type >= 0x80)                 { j += 3; // :48-49
```
For **any** status byte `0xF8`–`0xFF`, `status & 0xF0 == 0xF0`. `0xF0 <= 0xDF` is **false**, so it
falls to `type >= 0x80` → **`j += 3`**. Real-Time messages are **1 byte**. Over-consumption = 2.

Affected: `0xF8` clock, `0xFA` start, `0xFB` continue, `0xFC` stop, `0xFE` active sensing, `0xFF` reset.

**Consequence — this is the part that matters and it is not "a clock byte gets dropped":** if a
Real-Time byte precedes another message **inside the same `MIDIPacket`**, the parser skips past the
next message's *status* byte, and its data bytes (`< 0x80`) then fall to `j++` at `:51`. **The
following message is silently swallowed.** A packet `[F8, B0, 0A, 40]` yields **no CC at all**.

🚨 **SEVERITY MEASURED 2026-09-03 05:43:54 — IT IS WORSE THAN A CC PROBLEM, AND IT IS LIVE TODAY.**
`[MEASURED n=3 runs, 6 vectors + 6 controls, 3/3 identical]` Two standalone CoreMIDI probes over
**IAC Driver Bus 1** (scratchpad only — no build token, no tree change, app never launched), plus a
byte-exact replica of `midi_input.mm:26-53`:

| Sent | Delivered as | **Shipped parser sees** |
|---|---|---|
| `[90 3C 64]` alone — **control** | 1 packet, len 3 | ✅ `noteOn(60)` |
| `[F8]` + `[90 3C 64]` — **two adds, same timestamp** | **1 packet, len 4** | 🚨 **NOTHING** |
| `[FE]` + `[90 3C 64]` — active sensing | 1 packet, len 4 | 🚨 **NOTHING** |
| `[90 3C 64]` + `[F8]` — note FIRST | 1 packet, len 4 | ✅ `noteOn(60)` |
| `[F8]` + `[90 3C 64]` + `[90 3E 64]` | 1 packet, len 7 | ⚠️ `noteOn(62)` only — **first note dies** |
| `[90 3C 64]` + `[90 3E 64]` — control | 1 packet, len 6 | ✅ both |

**Three facts, all `[MEASURED]`, none inferred:**
1. **CoreMIDI COALESCES.** Two separate `MIDIPacketListAdd` calls at the same timestamp — *exactly
   what a DAW or clock source emits* — arrive as **ONE packet**, 3/3. Coalescing is not a maybe;
   it is the default. **This is what closes the open severity question.**
2. 🚨 **THE FAULT EATS NOTES, NOT JUST CC — SO IT IS A LIVE BUG IN SHIPPED FUNCTIONALITY.**
   `[READ main.cpp:212-222]` the synth is note-driven **today**. A clock or active-sensing byte
   sharing a packet with a Note On **destroys that note**. This is not a blocker for an unbuilt
   feature; **it is broken now, on the branch that goes on stage**, for anyone who sends
   SpaceSynth clock — which is what asking for Link means.
3. **The damage is BOUNDED and DETERMINISTIC: exactly one message per Real-Time byte, then the
   parse realigns.** Proof is the `[F8][note][note]` row — the first note dies, the second
   survives. And order matters: a Real-Time byte only harms what **follows** it in the packet.
   `[READ :24-26]` `j` is declared in the inner `for`-init, so **it resets to 0 on every packet —
   desync cannot cross a packet boundary.**

↩️ **This corrects a stronger claim in circulation** (SONNET → OPUS, 05:41): *"desyncs the stream
continuously … until the parser luckily resyncs."* It is neither continuous nor luck. It is
**1 message lost per Real-Time byte, self-recovering within the packet.** The root cause SONNET
identified is right and its fix is right; only the severity model was overstated. Keeping the
distinction matters for diagnosis: the stage symptom is **notes and CCs going missing
intermittently**, not MIDI dying.

⛔ **TWO THINGS NOT MEASURED, stated so the result is not quoted harder than it earns:**
1. **The collision *rate* against a real clock source.** It depends entirely on how the sender
   batches, so any rate I generated with my own probe would be **a rate I made up.**
2. **His specific USB controller.** The probe ran over **IAC Driver Bus 1**, which proves CoreMIDI
   *preserves* same-timestamp coalescing end-to-end — **that is the DAW→IAC→SpaceSynth path, and it
   is the likely Cologne configuration.** It does **not** prove a USB-MIDI driver batches the same
   way; USB-MIDI builds packets from 4-byte events and may differ.
   ⇒ **"a clock source into SpaceSynth eats notes" is `[MEASURED]`. "His controller eats notes" is
   NOT, and is not claimed here.** Both need his rig to close.

### 2.1b ✅ **FIX LANDED AND VALIDATED 2026-09-03 05:55:57 — F1 IS CLOSED**

`[READ git diff src/core/midi_input.mm]` SONNET's guard is in, 5 lines, before the dispatch chain:
```c
if (status >= 0xF8) { j++; continue; }   // System Real-Time: 1 byte, no channel nibble
```
`[VERIFIED]` **the build is not stale** — binary `05:53:27` is newer than the source `05:50:18`.

`[MEASURED n=3 runs, 3/3 identical]` I re-ran **the exact vectors that failed before**, against a
replica of the **fixed** function. **Every Real-Time case now passes:**

| vector | before | after |
|---|---|---|
| `[90 3C 64]` control | ✅ | ✅ |
| `[F8 clock][note]` | 🚨 NOTHING | ✅ **`noteOn(60)`** |
| `[FE sensing][note]` | 🚨 NOTHING | ✅ **`noteOn(60)`** |
| `[FA start][note]` | — | ✅ `noteOn(60)` |
| `[FF reset][note]` | — | ✅ `noteOn(60)` |
| `[F8][note][note]` | ⚠️ second only | ✅ **both** |

**F1 is closed. The live note-loss bug is gone for the ruled configuration (MIDI clock).**

### 2.1c ⚠️ **RESIDUAL — F2 SURVIVES THE FIX, AND IT STILL EATS NOTES**

The guard is `status >= 0xF8`, so **System Common `0xF0`–`0xF7` is deliberately not covered.**
`[MEASURED n=3, 3/3]` against the fixed replica:

| vector | result |
|---|---|
| `[F1 MTC quarter-frame, 2B][note]` | 🚨 **NOTHING — note destroyed** |
| `[F3 Song Select, 2B][note]` | 🚨 **NOTHING — note destroyed** |
| `[F6 Tune Request, 1B][note]` | 🚨 **NOTHING — note destroyed** |
| `[F2 Song Position, 3B][note]` | ✅ survives — **correct by accident** |

**Honest severity, neither inflated nor buried:** MIDI clock alone **never** emits these, so the
configuration he ruled for Cologne is **fully closed** by the guard. The residual fires only if
something in the chain sends **MTC** (`0xF1` — ~96-120 B/s when active, *denser than clock*, and each
one eats a note) or **transport locate** (`0xF2`/`0xF3` on stop/locate — sparse, and `0xF3` eats a note).
⇒ **Not a Cologne blocker under the ruling. It becomes one the moment anything speaks MTC.**
**Fix is the System Common size table in §2.7 step 2 — a few lines in the same function.**
**SONNET's file, SONNET's call. Reported, not taken.**

### 2.2 F2 — System Common mis-sized `[READ :46-49]`
`0xF1` MTC quarter-frame (2 bytes) and `0xF3` Song Select (2 bytes) → `j += 3`, over by 1.
`0xF6` Tune Request (1 byte) → over by 2. `0xF2` Song Position (3 bytes) → **correct by accident.**

### 2.3 F3 — 🚨 **CC IS NOT PARSED AT ALL, AND THE CALLBACK CANNOT CARRY IT** `[READ :48-49, midi_input.h:7-8]`
`0xB0` falls into the generic 3-byte skip. And the interface itself is note-only:
```c
using MidiCallback = std::function<void(int note, float velocity, bool isNoteOn)>;
```
**There is no CC number and no channel in the signature.** This is not a bug — it is the missing
feature, and it is the entire dependency. **The interface must change**, which makes this
architectural rather than a patch.
`[READ main.cpp:212-222]` **There is exactly ONE consumer** — the lambda feeding `synth.noteOn/noteOff`.
**One call site to update. The interface change is cheap because nothing else uses it.**

### 2.4 F4 — channel is never extracted `[READ :27-28]`
`status & 0x0F` is never read; all 16 channels collapse. Two controllers both sending CC#1 on
different channels would collide in a learn table. Real limitation, low stage risk with one controller.

### 2.5 F5 — running status unhandled `[READ :50-52]`
A data byte with no preceding status hits `j++` and is discarded. Most controllers send full status
per message; a device using running status for a fader sweep loses the sweep.

### 2.6 ✅ NOT faults — recorded so nobody "fixes" them into hazards
- **`j + 2 < packet->length` is CORRECT.** `j+2` must be a valid index ⇒ `j+2 <= length-1` ⇒ `j+2 < length`. Not off-by-one.
- **SysEx is benign.** `0xF0` → `j+=3`; payload bytes are all `< 0x80` → `j++` each; `0xF7` → `j+=3`. No callback can fire from SysEx data. A controller's startup handshake is noise-free.
- **Velocity-0-as-note-off (`:34-39`) is CORRECT** per the MIDI spec. `[SONNET, verified]` Leave it.

### 2.7 THE FIX SHAPE — the MIDI spec's own table, not an invention
`[LOOK IT UP BEFORE ITERATING]` The canonical byte-stream parser tests in this order:
1. **`status >= 0xF8`** → Real-Time. **Always 1 byte. May interleave anywhere, including between a status byte and its data.** Handle and `j += 1`. **This test must come FIRST** — that single reordering is what fixes F1.
2. **`status >= 0xF0`** → System Common, size from a table (`F1`:2, `F2`:3, `F3`:2, `F6`:1, `F0`:scan to `F7`).
3. **`status >= 0x80`** → channel voice. Size table: `0x80/0x90/0xA0/0xB0/0xE0` = 3; `0xC0/0xD0` = 2. Latch as running status.
4. **`status < 0x80`** → running-status data byte; re-use the latched status.

**Scope of the fix: one file, one function (`midi_input.mm:18-56`), plus the interface and its one consumer.**

✅ **STEP 1 IS DONE — the Real-Time half landed 05:50:18 and is validated in §2.1b.** ⚠️ Step 2 (the
System Common size table) is **still open and still eats notes under MTC** — see §2.1c. Steps 3-4
(running status, channel) remain open and are **not** stage risks under the ruling.

---

## 3. ARCHITECTURE — FOUR UNITS, EACH TESTABLE ALONE

```
CoreMIDI thread                      main thread (once per frame)
───────────────                      ────────────────────────────
[1] parser  ──(cc,ch,val)──▶ [2] lock-free inbox ──drain──▶ [3] map table ──▶ registry ──▶ *v / setter
    midi_input.mm                    atomics                  label → target    APPLIED IN THE FRAME
                                                              [4] Ui* helpers   LOOP, OUTSIDE showHUD
                                                              only REGISTER
```

**[1] Parser** — §2.7. Knows nothing about mapping. Testable with a byte-array fixture, no app, no audio.
**[2] Inbox** — 🚨 **the MIDI callback runs on the CoreMIDI thread** `[READ :17-18: "called on MIDI thread"]`.
Writing `AppState` floats from it is a data race with the UI. Fix: MIDI thread writes
`std::atomic<uint16_t>` slots indexed by `(channel<<7)|cc` — 2048 slots, ~4 KB, wait-free, no
allocation, no queue overflow. Main thread drains once per frame **before** the UI is built.
Coalescing is *correct* here: a fader sweep only needs its latest value.
**[3] Map table** — `label → {cc, channel, curve, min, max, takeover}`. Owns learn mode and persistence.
**[4] `Ui*` helpers** — 🚨 **REGISTER only** (see §1.5). They publish `{label, v, min, max, flags, setter?}` to the registry; **they do NOT apply.** Apply runs in the frame loop, outside `if (showHUD)`, so mappings live with the menu hidden. **Still no call site touched.**

### 3.1 Three properties this shape gets for free

1. **The curve is already there.** `[READ :37-38, :56-57]` the helpers already receive `ImGuiSliderFlags`,
   and `[READ, 8 sites]` **8 sliders carry `ImGuiSliderFlags_Logarithmic`** — including
   `uiIscoSeconds` (`main.cpp:1542`, log 0.02..30). A linear CC map on a log dial is unusable: a
   7-bit step near the bottom is worthless and near the top is a cliff. **Mapping inside the helper
   can honour the widget's own curve because the flag is already in hand.** Mapping anywhere else
   would have to re-derive it, and would get it wrong.
2. **7-bit stair-stepping is bounded and visible.** 128 steps. `[READ app_state.h:73]` the
   `uiIscoSeconds` range is a documented **1500× span** — 128 linear steps across it is unusable,
   which is the concrete proof point for (1), not a general worry.
3. **`v_min`/`v_max` are the mapping range by construction.** No second range table to drift out of
   sync — the drift trap that `PhysicsUniforms` (~40 hand-synced fields, no static_asserts) and
   `PostFXUniforms` (4 bytes out of sync) both demonstrate in this repo.

### 3.2 ⚠️ THE IDENTITY TRAP — read before choosing a key
`[READ :39, :58]` The helpers already compute `ImGui::GetID(label)`. **Do not persist that.**
`ImGuiID` hashes the label **plus the ID stack** (window + open tree nodes), so a mapping keyed on
it **silently breaks if a widget moves into a different header** — and two labels are already
`##`-prefixed (`"##MasterVol"`, `main.cpp:1102`). **Persist the label string.** It is stable, it is
human-readable in the file, and it makes a broken mapping legible instead of mysterious.
⚠️ Corollary: **renaming a label breaks its mapping.** Which is another reason nothing gets renamed.
⚠️ `:1885`'s label is **generated** (`snprintf("E%d XY", i)`) — so its key is `"E0 XY"`, `"E1 XY"`…
and a mapping to `"E3 XY"` is simply **inactive** while fewer than 4 voices are live. That is the
correct behaviour, not a bug, but it must be **stated in the file** so a dead mapping reads as
"that emitter isn't there" rather than "mapping is broken."

### 3.3 THE BUILDABLE DATA MODEL — three structs, and where each one lives

```
// 1. What a widget publishes about itself, EVERY frame it is drawn.
struct Target {                 // built by the Ui* helpers, §3[4]
  const char* label;            // the KEY (§3.2). Stable, human-readable.
  Kind        kind;             // A_POINTER | B_SETTER | C_INDEXED   (§1.2)
  float*      ptr;              // Kind A only — valid forever (&app.ui*)
  std::function<void(float)> set;  // Kind B only — a stored ptr would DANGLE
  float       vmin, vmax;       // the mapping range, straight from the call site
  ImGuiSliderFlags flags;       // carries Logarithmic — §3.1(1)
  uint8_t     component;        // 0 for scalars; 0/1 for :1874's X/Y
  bool        seenThisFrame;    // false ⇒ widget not drawn ⇒ see §1.5
};

// 2. What the user's file holds. Gitignored. §4.
struct Mapping {
  std::string target;           // matches Target::label (+ ":x"/":y" for :1874)
  uint8_t     cc, channel;      // channel 0 = omni until F4 lands (§2.4)
  float       lo, hi;           // sub-range; defaults to the widget's vmin/vmax
  Curve       curve;            // LINEAR | LOG — defaults FROM Target::flags
  Takeover    takeover;         // JUMP | PICKUP | RELATIVE          (§3.5)
};

// 3. What the MIDI thread writes. Wait-free. §3[2].
std::atomic<uint16_t> inbox[2048];   // (channel<<7)|cc → value|SEEN, ~4 KB
```

**Ownership is clean:** the helpers own `Target` (and touch nothing else), the file owns `Mapping`,
the MIDI thread owns `inbox` and reads nothing back. **Each of the three is testable without the
other two.**

### 3.4 THE APPLY LOOP — the whole of §1.5, in order, once per frame

Placed in the frame loop **BEFORE and OUTSIDE `if (showHUD)`** (`main.cpp:1119`):
```
for each Mapping m:
    v = inbox[(m.channel<<7)|m.cc];  if unchanged since last frame → skip
    t = registry.find(m.target);     if absent → skip          (§1.5 residual)
    x = v / 127.0                                              (7-bit, §3.1(2))
    x = applyCurve(x, m.curve)       // LOG uses the widget's OWN flag
    x = m.lo + x * (m.hi - m.lo)
    x = takeover(x, currentValue(t), m.takeover)               (§3.5)
    switch (t.kind):
      A_POINTER → *t.ptr = x
      B_SETTER  → t.set(x)                                     // never a stored ptr
      C_INDEXED → t.set(x)  // writes emitters[i].x or .y
```
### 3.4b 🚨 THE ORDERING CONSTRAINT — THE ONE IN THIS DESIGN, AND IT IS INVISIBLE UNTIL IT IS WRONG

**APPLY RUNS BEFORE THE UI IS BUILT. NOT AFTER.**

Both orders compile. Both look correct in review. Only one is right:
- ✅ **apply → build UI:** a slider drawn later in the same frame renders the value the CC just
  wrote. **The knob tracks the controller under his hand.**
- ❌ **build UI → apply:** every mapped widget renders the value from **last** frame. The knob lags
  the controller by one frame, permanently. **It does not read as a one-frame delay — it reads as
  broken hardware**, and the first instinct at the desk is to blame the controller or the cable.

⚠️ There is no test that fails and no warning that fires; the wrong order is only visible as a feel.
**Written here rather than left inside the pseudocode above, because this is the line that gets lost
when someone reimplements §3.4 from memory.**

### 3.5 TAKEOVER — **BUILT AND BYPASSED** (his ruling 3: controller undecided)

He has not chosen absolute faders vs endless encoders, so **the design must work for either without
being rebuilt.** Three modes, one enum, chosen per mapping:
- **`JUMP`** — write immediately. Correct for **endless encoders** and for anything where a jump is
  wanted. **This is the bypass**: with `JUMP`, the takeover step is a pass-through.
- **`PICKUP`** — ignore the CC until it crosses the parameter's current value, then track. Correct
  for **absolute faders**, and the answer to *"a preset load jumps every dial"*.
- **`RELATIVE`** — treat the CC as a signed delta (±1 around 64 / two's complement). Correct for
  **encoders that send relative**, which some do and some don't.

**Default `JUMP`**, because it is the mode that is never *wrong*, only sometimes abrupt — and it is
the one that needs no knowledge of the hardware. ⇒ **nothing in this design assumes his controller,
and picking it later changes one field in a file, not a line of code.**

## 4. PERSISTENCE — WHERE MAPPINGS LIVE, AND ONE TRAP

**Mappings must NOT go in `struct Preset`.** `[READ preset_manager.h:8-33]` a Preset is **15 fields**
against 62+ live dials — a known, already-boarded gap. More importantly a mapping is
**controller-hardware state, not a look**: loading a preset must never re-wire the desk.

**They must NOT go in `imgui.ini` either.** 🚨 `[READ .gitignore + git ls-files]` **`imgui.ini` is
TRACKED**, and the running app rewrites it — which is exactly why it appears as `M` in every
preflight, including this window's at 05:06:44. **A mapping file placed beside it repeats that trap
and makes the tree dirty on every launch**, two days before a show governed by
*commit-or-revert-before-the-token-changes-hands*.

**Recommendation:** `midi_map.json`, **gitignored**, written by the same **dependency-free
hand-rolled JSON** already in `preset_manager.cpp:12-36`. No new dependency.

---

## 5. MACROS — a layer, not a change

His word "macros" = **one CC drives N parameters**, each with its own sub-range and curve. That is
a table *above* §3.3 and changes nothing below it:

```
macro "COLLAPSE" ← CC#20 ch1
   ├── "Wave Depth"     0.20 → 0.95   linear
   ├── "ISCO seconds"   3.00 → 0.08   log      (honours the widget's own flag)
   └── "Bloom"          0.00 → 0.60   linear
```
**YAGNI ruthlessly:** no macro *editor* UI in v1 — macros are rows in the same gitignored file,
edited in a text editor. He gets the control; nobody builds a second UI two days out. **A macro
editor is the droppable piece, and I am saying so now, not in week three.**

---

## 6. ABLETON LINK — ✅ **RULED 2026-09-03: MODULATION ONLY, AND NOT BEFORE COLOGNE**

> **His ruling closes this section's open question.** Tempo may modulate mapped dials; it **never**
> touches `uiIscoSeconds` or any physics clock, and **no tempo term enters `camera.h`**. MIDI clock
> for Cologne, Link after the show, **vendor nothing.** The analysis below is why — kept because the
> ⛔ boundary it draws is now a live constraint, not a question.

🚨 **His ruling 2026-08-28, verbatim** `[READ camera.h:100-103, BOARD.md:320, CAMERA_STEP2_DESIGN.md:146-149]`:
> *"we dont want a bpm sync its not needed for now u got that wrong. its just about smoothness in camer amotion. automated camera rdies from point a to b."*

`[READ]` **Four separate documents escalated that ruling to a blanket "⛔ NO BPM. NO BEAT. NO
ABLETON LINK. NO TEMPO TERM"** (`camera.h:100`, `CAMERA_STEP2_DESIGN.md:146`,
`HANDOFF_2026-08-29_CAMERA_WINDOW.md:29-31`, memory `space_synth_camera_overhaul_2026-08-10:17-21`),
and three of them **explicitly forbid reintroducing Link through the params door.**

**His 2026-09-03 order asks for Ableton Link.** Per *[STARTED WORK = HE CHANGED HIS MIND]* — never
quote an older plan back, **correct the doc.** But the two are narrower than they look and the
distinction is the whole design:

- **What he rejected was tempo as a source of FEEL CONSTANTS** — deriving the camera's spring ω from
  BPM. His own words scope it: *"its just about smoothness in camer amotion."*
- **What the 2026-08-10 note asked for is different** `[READ memory :30-31]`: *"Ableton Link so params
  are BPM-syncable 'as in Resolume'."* — tempo as a **modulation source for mapped params**.

**These are not the same feature and they were never ruled on together.** ⛔ **The 08-28 ruling stands
for the camera regardless of what he decides here** — nothing in this design may put a tempo term
back into `camera.h`.

### 6.1 ⭐ PRIOR ART EXISTS — this is not a from-scratch design
`[READ memory space_synth_camera_overhaul_2026-08-10:92-110]` a threading analysis and the Resolume
model were already written on 2026-08-10 and are **not** among the two things that file marks dead:
- `captureAppSessionState()` — render thread, thread-safe ⇒ **render-side Link adds nothing to D6.**
- `captureAudioSessionState()` — audio thread ⇒ tempo-locking the **synth** lands squarely in D6.
  *"Different question, different answer — never remember this as 'Link is safe'."*
- `phaseAtTime(now, quantum=4)` → bar progress 0→1 = the master animation clock.
- **Resolume's model, two uses of one clock:** (1) **quantized launch** — a discrete event waits for a
  bar boundary; (2) **continuous phase drive** — a param *is* a function of phase.
  Copy outright: **Resolume disables hard resync under Link** — mid-show, a param that snaps to
  re-align is worse than one slightly off.

### 6.2 ↩️ CORRECTION TO THAT PRIOR ART — D6 has narrowed since
`[READ synth.cpp:95-99]` `mutex_` is now taken with **`std::try_to_lock`** and commented
*"never blocks the RT thread."* **That half of D6 is fixed.** But `[READ synth.cpp:91]`
`queueMutex_` is still a **blocking `lock_guard` on the RT thread** (again at `:140`, `:150`).
**D6 is narrowed, not closed** — the 08-10 note's framing is stale and should not be quoted as-is.
This does not change the recommendation; it changes what is true.

### 6.3 ✅ **ACCEPTED AS RULED — MIDI CLOCK FOR COLOGNE, LINK AFTER**

Not a menu. One recommendation — **taken as given 2026-09-03:**

**Do not add Ableton Link before 2026-09-05.** Reasons, in order of weight:
1. `[READ, grep]` **Link is not in the tree.** Zero hits across `src/`. It is a **new third-party
   dependency** requiring a vendor drop, a build-system change in `package_macos.sh`, and a network
   discovery layer — **two days out, on the one branch that goes on stage.**
2. **MIDI clock is already arriving at the parser and costs nothing extra.** `0xF8` at 24 ppqn gives
   tempo and phase from **the same one-file fix §2.7 already requires.** If his DAW is the tempo
   master — and it is, if he is asking for Link — **MIDI clock gets him the same clock through a door
   that has to be opened anyway.**
3. It keeps tempo **entirely out of the audio thread**, so §6.2's blocking `queueMutex_` never becomes
   a stage question.

**Link is the right answer for the *next* show** — it is genuinely better than MIDI clock (drift-free,
peer-to-peer, no cable, phase-accurate) and the 08-10 threading analysis is still the design for it.
**It is the wrong answer for this Tuesday.**

---

### 6.4 TEMPO AS A MODULATION SOURCE — the concrete shape, per his ruling 1

MIDI clock (`0xF8`) is **24 ppqn**. Counting clocks gives phase without a tempo estimate at all:
```
onClock():  ++clk;  phase01 = (clk % (24*quantum)) / (24.0*quantum)   // quantum = bars
0xFA start / 0xFB continue → clk = 0 (downbeat)   0xFC stop → hold phase, do not reset
```
`phase01` is then just **another source a `Mapping` can name instead of a CC** — same range, same
curve, same takeover, same apply loop. **No new subsystem; one extra source enum.**
⛔ **HARD LIMITS, his ruling 1 and the 2026-08-28 camera ban, both standing:**
- `phase01` may drive **mapped dials only**. ⛔ It must **NEVER** reach `uiIscoSeconds`, the substep
  count, `dt`, the warp, or any other physics clock. **A tempo term inside the physics clock is the
  frame≠time bug wearing a new dress** — the design's own §3.4 never writes anything but a `Target`.
- ⛔ **NOTHING goes into `camera.h`.** The 2026-08-28 ruling (*"we dont want a bpm sync … its just
  about smoothness in camer amotion"*) **stands untouched**; ω stays a settle-time constant.
- ⭐ Copy Resolume: **no hard resync.** On a tempo jump, let phase drift back rather than snapping —
  mid-show a snap is worse than being slightly off (§6.1).
⚠️ `0xFA`/`0xFB`/`0xFC` are **System Real-Time**, so they ride on §2.1b's guard — **which is already
in and validated.** This costs nothing extra at the parser.

## 7. SEQUENCE — riskiest last, and every step verifiable alone

| # | Step | Verifiable by | Droppable? |
|---|---|---|---|
| 1 | ✅ **DONE — parser Real-Time guard**, SONNET's, landed 05:50:18, built 05:53:27, **validated §2.1b `[MEASURED n=3]`** | 7/7 Real-Time vectors pass | — |
| 1b | ⚠️ **System Common size table** §2.1c — `F1`/`F3`/`F6` **still destroy a note** | the 4 vectors in §2.1c | ✅ yes **under the MIDI-clock ruling only** — ⛔ no if anything speaks MTC |
| 2 | Interface + inbox §3 [1][2]; **one consumer** `main.cpp:213` | note input still works exactly as before | ⛔ no |
| 3 | `UiSliderFloat`/`UiSliderInt` mapping + learn — **62 params, zero call sites** | **nothing on screen changes until a CC arrives** | ⛔ no — this IS the ask |
| 3b | **Registry seeding pass** §1.5 — ⛔ **without it, mappings die when he hides the menu** | map a dial, hide the HUD, move the fader | ⛔ **NO — this is what makes step 3 true on stage** |
| 4 | `main.cpp:1563` → `UiSliderInt` (one word) | that one slider now maps | ✅ yes, costs 1 param |
| 4b | Kind-B setter targets §1.2 (4 sliders: master vol + 3 chorus) | move a mapped chorus dial | ✅ yes, costs 4 params |
| 4c | `UiSliderFloat2` for `main.cpp:1885` — **wrapper does not exist**, 2 values, dynamic label/count | an emitter XY moves from 2 CCs | ✅ **yes — the most work for the least surface** |
| 4d | **Takeover: pickup built, bypassed for relative** (his ruling 3) | a preset load does not jump the dial | ⛔ no if he brings absolute faders |
| 5 | `UiCheckbox` ×24, `UiCombo` ×2 | pixels identical | ✅ **yes** |
| 6 | Macros §5 (file-only, no editor) | a CC moves 3 dials | ✅ yes |
| 7 | MIDI clock §6.3 | phase drive | ✅ yes |
| 8 | **Ableton Link** | — | ⛔ **NOT BEFORE COLOGNE** |

**Steps 1–3 alone = every fader on the app playable from his controller, nothing moved.**
Saying which are droppable **now, not on Thursday.**

---

## 8. ✅ THE THREE QUESTIONS — ANSWERED 2026-09-03, AND WHAT REPLACED THEM

| Was open | His ruling |
|---|---|
| Does tempo drive TIME or only MODULATION? | ✅ **MODULATION ONLY.** Never `uiIscoSeconds`, never a physics clock. **My read was right — and it was still right not to assume it.** |
| Which controller — absolute or endless? | ✅ **"Both / not decided yet"** ⇒ **build pickup/takeover, BYPASS it for relative encoders.** The design must not assume the hardware. |
| Is the parser fix authorized, and whose? | ✅ **Authorized. SONNET writes it, FABLE builds it.** Not mine, not blocked on me. |

🔴 **ONE NEW QUESTION, and it is the only thing in this design that is not free:** §1.5's registry
seeding. *"Every param mappable **with the HUD hidden**"* and *"nothing moves"* pull against each
other exactly once — a widget that has never been drawn has never registered. **My recommendation is
a startup UI pass with headers forced open and rendering suppressed.** It moves no fader and costs
one frame. **If that reads to him as moving something, it needs his word.**

⚠️ And one that is **BRAIN's**, unchanged: literal *"every parameter"* still needs **24 checkbox +
2 combo renames**. The 61 wrapped faders need none.

---

## 10. 🚨 TIMELINE-ACCURATE AUTOMATION — the revision his order forces

### 10.1 ↩️ CORRECTING THE INBOX — and correcting the REASON, because the reason decides the fix

§3.3's `std::atomic<uint16_t> inbox[2048]` is a **latest-value slot per CC**. The note that reached me says a
slot *"cannot express a fade, only its endpoint."* **That is too strong, and the precise version is what tells
you when you need something else:**

- ⭕ **Rendering in REAL TIME, a latest-value slot traces a fade correctly.** It is re-sampled every frame, so
  60 samples/second of a moving CC **is** the fade. Coalescing intermediate values is not a loss — for a
  continuous parameter, *"the newest value at frame time"* is exactly the right sample.
- 🚨 **The moment the render clock is DECOUPLED from the wall clock, the slot is wrong — and that is precisely
  the case his order asks for.** A slot has **no timestamp**: it can only answer *"what is the value NOW"*,
  never *"what was the value at output frame N"*. Consequences, worst first:
  1. **A heavy frame silently speeds the fade UP.** The slot advances at wall rate while the render falls
     behind, so an authored 4-second fade completes in fewer frames and reads FASTER than composed. Invisible
     on one frame; across five minutes it is a ride ending in the wrong musical place.
  2. **The render cannot be repeated.** Two renders of one timeline give different frames. *"Accurately"*
     implies reproducibly and a slot cannot supply it.
  3. **The render can never run slower or faster than real time** — which forecloses the offline tier entirely.

⇒ **THE FIX: the source becomes a TIME-ORDERED EVENT LIST consumed against the render clock.**
```
struct CcEvent { double t;               // seconds on the TIMELINE, not arrival time
                 uint8_t cc, ch, value; };
// live   : t = arrival wall-clock, appended by the MIDI thread (still wait-free, a ring)
// render : t = tick -> seconds via the file's tempo map; the whole list is known BEFORE frame 0
```
Per output frame, advance a cursor to `t <= frameTime` and take the last value per `(ch,cc)` — **the slot's
behaviour, evaluated at the FRAME's time instead of at now.** ⭐ **That is the entire change.** `Mapping`, the
curve, the range, the three target kinds (§1.2) and §3.4's apply order are untouched, and the live path
degenerates to exactly today's behaviour when `frameTime == now`.

### 10.2 🔴 THE FORK HIS WORDS DO NOT SETTLE — *"have the app 'read' the midi"*

**Two architectures, not one build. I am not guessing which he means.**

| | **A — LIVE STREAM** | **B — FILE READ** |
|---|---|---|
| Source | Ableton plays; CC arrives over IAC | the app parses a `.mid` **file** (notes + CC at ticks) |
| Clock master | **Ableton** | **the app** |
| Accuracy | ±1 frame + CoreMIDI jitter | **exact and reproducible** |
| Render speed | real time only | **any speed — this unlocks the offline tier** |
| New code | **none beyond §10.1** — rides the parser shipped as `9fbe0ba` | a Standard-MIDI-File reader + tempo map |
| Cologne-ready | **yes** | not without his word on scope |

**RECOMMENDATION, one not a menu: BUILD A, DESIGN B, SHARE EVERYTHING BELOW `Mapping`.** A is reachable now
on the parser already in, and is what he can rehearse with. B is the only thing that makes *"accurately"*
literally true and is the natural partner to the pre-recorded show and to SONNET's offline design. **They
differ ONLY in how `CcEvent.t` is produced** — so A costs nothing toward B and forecloses nothing.
🔴 **HIS CALL: does "read the midi" mean the live stream, or a file the app opens?**

### 10.3 ✅ THE CLOCK — HIS RULING SOLVES THIS EXACTLY, AND I HAD IT BOARDED AS AN OPEN RISK

**What I was going to flag, and it was real:** `[READ renderer.mm:1775]` `kStepWall = 0.0165` demands
**60.606 steps/s**, while `[READ renderer.mm:1809-1813]` the carry is bounded to one step — its own comment
says *"steps == frames"* below 60.61 fps. At a 60 fps render that feeds 60 steps against 60.606 demanded ⇒
**sim time 1.0% slow, 3.0 s over a five-minute piece**, with the excess discarded rather than carried.

✅ **HIS RULING 2026-09-03 REMOVES IT: offline `dt = 1/60`, TWO steps per output frame ⇒ one frame = exactly
1/30 s = 30.000 fps, ZERO drift.** *(Live `dt` stays `0.0165`.)* His words: *"I def wanna deliver straight 30 or
60 fps. I guess it's gonna be 30 fps."*
⭐ **This is the number the timeline design needed, and it is now FIXED, not assumed.** A CC event's tick maps
to an output frame with **no accumulator and no rounding** — `frameIndex = round(t * 30)` is exact, and §10.1's
cursor walk becomes trivially correct. **Every accuracy claim in this section rests on that ruling.**
✅ **AND WARP IS RULED OUT OF THE RENDER — so the timing is EXACT, unconditionally.** His words
2026-09-03: *"Warp won't be during rendering no worries."* ⇒ no caveat: **one output frame = exactly 1/30 s =
exactly 2 sim steps, full stop.** `frameIndex = round(t * 30)` is exact, no accumulator, no rounding, no drift.
⚠️ **BUT THE EXACTNESS IS ENFORCED BY A PIN, NOT BY HOPE — and this is the one line to keep.**
`[READ renderer.mm:1713]` `dt = 0.0165f * impl_->timeWarpVal` is the **only** thing between the render and
silent length drift. A stale dial from a previous session, or a preset, arrives as whatever it was — and
`[READ renderer.mm:2333]` `setTimeWarp` clamps only to `1.0e-3f`, so **warp can be BELOW 1 as well as above**:
a leftover 0.5 yields a half-length video **with nothing on screen to indicate it**. ⇒ offline mode must
**FORCE `timeWarpVal` to 1 and log it before frame 0** if it arrives as anything else. **The timing is exact
BECAUSE of that pin; without it every claim in this section is only probably true.** (BRAIN has relayed the
pin requirement to FABLE; it is FABLE's to build, not mine.)

🚨 **A CONSEQUENCE OF HIS OWN RULING THAT NOBODY HAS FLAGGED — offline will not be bit-identical to live, and
the reason is in MY §1 lane.** `[READ particles.metal:362]` *"IDENTITY AT WARP 1 BY CONSTRUCTION:
72.7273 * 0.0165 = 1.2 sim/frame exactly"*. With offline `dt = 1/60`:
`72.7273 × 0.0166667 = 1.21212` — **the Chladni speed cap per frame rises 1.01%.**
Per §1's finding the cap sets the hue-scatter rate (phase advances `speed*dt`), so **the offline render's
Chladni colour and cap-limited motion are ~1% different from live.** Small, and I am not calling it a
blocker — but it means (a) an offline A/B against a live capture is **not** an exact comparison, and (b) the
`[PERF]` real-time ratio that memory earmarks as the offline regression check will read a **different
constant**, not a broken one. **Say it now rather than discover it in a verdict run.** ⛔ FABLE's lane and his
ruling; recorded here because it is a consequence of the clock this section depends on.
⭐ **One camera, one timeline** (his ruling: *"it's one image as it already is"*, 19644×1680 cropped into
7152/5340/7152) ⇒ **no per-slice automation state to keep in sync.** One `CcEvent` list serves the whole wall.

### 10.4 ⛔ PICKUP MUST BE STRUCTURALLY REFUSED FOR A TIMELINE SOURCE, not merely defaulted away

§3.5's three modes were designed for a hand on hardware. **On a timeline there is no hand:**
- **`JUMP` is the only correct mode** — automation is an absolute value at a time.
- 🚨 **`PICKUP` does not merely misbehave, it produces SILENCE.** It waits for the incoming value to cross the
  parameter's current value, and nothing will ever move that parameter to be crossed. The dial sits still
  through an entire authored ride **with no error, no warning and no log line.**
- **`RELATIVE`** is meaningless — an automation lane has no deltas.
⇒ **Make it impossible, not improbable:** a `Mapping` whose source is a timeline **rejects** `PICKUP` and
`RELATIVE` at load with a named error rather than accepting them and going quiet. **A silent no-op is the
failure mode this design has been avoiding since §1.5**, and it would be indistinguishable from "the mapping
didn't load".

### 10.5 ⭐ WHAT *"ACCURATELY"* COSTS — 7 bits is not enough for a slow ride, and the answer already exists

**A ride is a slow continuous move, which is the worst case for 7-bit CC.** 128 steps is all a CC has.
`[READ memory space_synth_camera_overhaul_2026-08-10:112-119]` the prior art already measured it against the
camera: *"across rho 50→2000 that's ~15 units/step = visible stair-stepping on a slow zoom."* A 30-second zoom
ride crosses a step every ~0.23 s — **that reads as broken, not as a ride.** At 30 fps it is worse per frame,
not better: one step every ~7 output frames, held flat in between.

**The answer is already written down and it is the right one:** *"CC writes the TARGET, the spring outputs the
smooth value."* A slew / critically-damped filter between the event stream and the parameter turns 128 discrete
steps into a continuous curve, **needs nothing from Ableton, no file format and no controller support**, and it
is the same second-order form `camera.h` already ships (`kSettleConst`, `camera.h:104`).
⚠️ **One conflict to state rather than discover:** a slew filter is **state that persists across frames**, so
in a deterministic render it must be advanced by the same frame-indexed clock as everything else (§10.3) — or
**the smoothing itself becomes the thing that differs between two renders.**
⚠️ **14-bit CC (MSB/LSB on `cc` and `cc+32`) is the textbook alternative and I am NOT recommending it:** it is
real in the MIDI spec, but **whether Ableton emits 14-bit for an automation lane is `[UNVERIFIED]`** and I will
not design around a host feature I have not confirmed. **The slew answer needs nothing from the host**, so it
is the one to build first regardless of how that check comes out.

## 9. ✅ WHAT THIS WINDOW VERIFIED ITSELF (vs. inherited)

`[READ at HEAD 6530c45]`, all re-grepped this session, none inherited:
`main.cpp:31-73` helpers · widget census ×6 classes · `main.cpp:1563` bypass ·
`midi_input.mm:18-56` full parser · `midi_input.h:7-8` callback signature ·
`main.cpp:212-222` sole consumer · `camera.h:100-103` BPM ruling · `synth.cpp:91,95-99` D6 state ·
`preset_manager.h:8-33` · `.gitignore` + `git ls-files imgui.ini` · zero Link hits in `src/`.

**Producer/consumer check run** (board §AD, the trap that claimed three victims in one night):
`UiSliderFloat`'s 56 call sites are **consumers**, confirmed by count, not inferred from a definition.

**MEASURED THIS SESSION** `[n=3 runs, 3/3 identical]`: CoreMIDI coalescing over IAC Driver Bus 1,
and the shipped parser's behaviour on 6 vectors + 6 controls (§2.1). Probes live in the scratchpad
only — **no build token used, no tree change, app never launched.**

**STILL NOT MEASURED, tagged as such:** the collision *rate* against a real clock source — it is
sender-dependent, so generating it with my own probe would be fabricating it. Needs his rig.

---

**Last Updated:** 2026-09-03 06:15:18 — all `main.cpp` citations renumbered +11 for FABLE's TEMP-DIAG insertion (DRIFT, not error — every number was correct when written); tree-state provenance header added. Earlier: 06:06:34 — §3.4b: the apply-order constraint promoted out of the pseudocode (BRAIN's note: it would have been found on stage, not in review). Earlier: 06:04:33 — §3.3 data model, §3.4 apply loop, §3.5 takeover built-and-bypassed, §6.4 tempo-as-modulation, §1.5 seeding written for BOTH answers. Earlier: 05:55:57 — §2.1b parser fix VALIDATED (F1 closed, n=3); §2.1c residual MEASURED (System Common still eats notes under MTC). Earlier: 05:52:04 — his rulings 1-3 folded (§8); census corrected for `:1885` (BRAIN's catch, §1); target kinds classified (§1.2); **§1.5 added: a flaw in my own apply site, mine, found by checking what `showHUD` gates.** Earlier: 05:43:54 (§2.1 [HYPOTHESIS]→[MEASURED]), 05:38:07 (original).
**Status:** DESIGN, UNAPPROVED, UNCOMMITTED. **No source code written. No build run. Build token is FABLE's.**
