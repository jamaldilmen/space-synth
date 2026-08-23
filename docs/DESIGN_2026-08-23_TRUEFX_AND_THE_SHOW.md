# TRUEFX + THE SHOW — his brief, 2026-08-23 10:16:23

> **Captured verbatim-in-substance from his two messages on 2026-08-23.** Nothing here is my idea
> unless it says `[MINE]`. **13 days to Cologne** (2026-09-05).
> His framing, and it governs everything below:
> ***"in audio they say every effect is either eq or delay. and i wanna use that analogy to create our
> TRUEFX (audio + visual fx) not two effects chained together. the same data drives the effect for
> sound and visuals."***
> And the aesthetic turn: ***"i want more disco. disco vibes… shiny like disco ball surfaces… not nasa.
> we make a movie now. a show."***

---

## 0. THE ONE RULE

**A TRUEFX is ONE effect with two outputs.** Not an audio effect plus a visual effect that happen to
share a knob. The *same data* drives both. If a proposal has an audio DSP block and a separate shader
block that merely read the same float, **it is not a TRUEFX and he will reject it.**

His EQ-or-delay analogy is the design axis:
- **EQ family** = it removes/shapes what is already there → visually, it *removes/shapes light*.
- **DELAY family** = it repeats something in time → visually, it *repeats an image in time*.

---

## 1. THE FOUR TRUEFX

| # | Effect | Audio side | Visual side — **his mapping, not mine** | State |
|---|---|---|---|---|
| **T1** | **REVERB** | room / tail | **The FLUIDITY mechanism IS the reverb.** Screen persistence = the tail. Already exists as `trailDecay` ("Fluidity") | Visual half EXISTS, audio half does not |
| **T2** | **DELAY** | delay line | repeat the IMAGE in time — the visual half of the same delay line | ⛔ **Neither half exists.** His words: *"delay we dont have yet"* |
| **T3** | **CHORUS** | detune/voices | **per-pixel PROPER chromatic aberration.** Not the current flat radial offset — that is the row already open as a mixed-space bug | Audio half exists (`chorus_`), visual half is wrong |
| **T4** | **LOWPASS FILTER — LADDER** | ladder-style LPF | **IT IS OUR OPACITY.** ⭐ *"playing with the filter makes it darker. but not just darker like proper darker… it filters it. not just on off. but the effect will be an opacity-like fader. to automate."* So: cutoff sweeps down → the image loses its high-frequency content the way the sound does — **detail, sparkle and edges go first**, and it reads as a progressive veil, NOT a brightness multiply and NOT an alpha fade | ⛔ Not built as a TRUEFX. `SVF` exists per-voice |

⚠️ **T4 is the one to get conceptually right.** "Opacity-like fader" is how it *behaves as a control*
(one automatable knob, smooth, full range). It is **not** an opacity implementation. A cheap
`alpha *= x` would be exactly the "just on off" he is ruling out. The visual must lose *spatial* high
frequencies as the cutoff drops — the image equivalent of what a ladder filter does to a spectrum.

---

## 2. DISCO — the aesthetic turn

- ***"i want more disco. disco vibes."***
- ***"i want shiny like disco ball surfaces to appear at one point in the sim. like sparkly shiny.. effect."***
- ***"not nasa. we make a movie now. a show."***

⚠️ This is a **direction change** on the project's whole visual thesis, which until now has been
physical honesty (NASA-accurate blackbody, real optics). It does not cancel the physics — the standing
rule is still that the physics must be real — but the *presentation* is now cinematic, not documentary.
**Treat "not nasa" as being about the LOOK, not permission to fake the simulation.**

"At one point in the sim" = it is an EVENT, something that appears and passes, not a permanent surface.

---

## 3. CONTROL + SHOW INFRASTRUCTURE — he marked this **URGENT**

He intends to **sequence the entire 30-minute set in Ableton** and *"automate every single fucking thing."*

| # | Item | Why it is urgent |
|---|---|---|
| **S1** | **ABLETON LINK** | tempo/transport sync — the spine of a sequenced show |
| **S2** | **MPE** | named twice, both messages. Per-note expression |
| **S3** | **RECORDING / RENDER ROUTE** | *"the recording route / render route set up"* — he will pre-render parts of the show |
| **S4** | **EVERY PARAMETER = A MACRO, reachable via MIDI CC** | ***"every parameter needs to be a makro / reachable via MIDI CC"*** — this is the precondition for S1–S3 being worth anything. If a knob is not CC-addressable it cannot be in the set |

⭐ **S4 is the gate.** Sequencing is worthless if the parameters are not addressable. And it collides
with a standing open row: **the star dials do not exist at all** — every star experiment currently
costs a rebuild. Same underlying fix: expose parameters.

---

## 4. THE CAMERA RIDES — he capitalised it

- ***"THE CAMERA RIDES. we need super smooth cinematic rides and pans and get the feel of driving a
  little space ship through our universe. AUTOMATED. proper rides like automated manually and as in gta."***
- ***"how do cameras in sims like that work?"*** — an actual research question, answer it properly.
- **CINEMATIC MODE button:** *"i want a button so that my zoom and tilts and time warp become super
  slowed down.. like cinematic mode on my dji u get me. in my droney."*

So two distinct things:
1. **Authored camera moves** — rides/pans that can be sequenced and replayed (GTA-style scripted camera).
2. **A cinematic-mode toggle** — a global input-smoothing/slew mode that makes *live* zoom, tilt and
   time-warp gestures gentle and filmic. DJI cinematic mode is the reference: same control, slower
   response curve, heavier damping.

⭐ **There is already a designed answer to (2) sitting on the board awaiting his verdict:** the
second-order dynamics / `SmoothDamp` camera replacement, with damping derived from the beat. That row
is the cinematic-mode mechanism — it should be read as *this*, not as a maintenance refactor.

---

## 5. THE LIFECYCLE COMPLAINT — measured 2026-08-23, this is a REAL bug

***"midi length needs to dictate how long stuff is… i just want u to double check how our life cycle
actually still follows the audio / midi cause i feel it used to be better. not yesterday but weeks ago.
+ at 10 ms arp the sim kinda gets stuck obv. super fast arps need to look insane."***

**He is right, and the cause is one line.** `src/core/envelope.cpp`, Release phase:

```cpp
float relDur = std::clamp(sustainHeld, params.release, 1.5f);
```

`params.release` defaults to **0.400 s** (`envelope.h:22`) and is used as the **LOWER CLAMP**. So:

- **Every note gets a release of AT LEAST 400 ms, no matter how short it was.** A 10 ms note produces a
  ~400 ms visual tail — **40× longer than the note that caused it.** MIDI length does *not* dictate
  duration below 400 ms; the floor overrides it.
- At a 10 ms arp, ~40 voices are therefore alive simultaneously, all in Release.
- `getDominantEnvelope()` ranks Attack > Decay > Sustain > Release, so with 40 overlapping voices there
  is nearly always a fresh Attack voice → **the phase the GPU sees pins to Attack and never resolves.**
- `state.intensity` is the **SUM** of all voice amplitudes, so ~40 voices also saturate it.

**That is the "sim kinda gets stuck".** It is not the physics and not the renderer — the envelope that
drives the visual never gets to finish.

⚠️ Second, smaller defect found in the same read: `sustainHeld = envTime` is described as *"capture hold
time"*, but `envTime` is **reset to 0 on the Attack→Decay transition**, so it is measured from a moving
origin — it is "time since the last phase reset", not "how long the note was held". For long notes the
difference is small; for short ones it is the whole value.

**The quick route he asked for:** lower/scale the release floor so a short note gets a short tail, and
make `sustainHeld` measure from note-on. One line each, immediately audible AND visible, and it is the
most direct answer to *"it's A SYNTH"*.

---

## 6. ORDER HE GAVE

1. **Lifecycle / MIDI length + fast-arp responsiveness** ← §5, cause found, one line
2. **Star size** ← the standing 1.079 px wall
3. **Camera regression** — *"the camera changed from last week where it felt more in your face and had
   distance properly. i think that's kinda fucked rn since the resolution changes"* — ⚠️ he ties it to
   the resolution change. NOT YET CHECKED.
4. **FX SUITE + visual aesthetic** — §1 TRUEFX, §2 disco, and *"what our state of the art options are"*
5. **Show infrastructure** — §3, marked URGENT
6. **Camera rides** — §4

**His closing line:** *"the board is almost done and these things NEED TO BE DONE ASAP cause the show is
happening and its gonna be big."*
