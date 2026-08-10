# AUDIT — THE FULL CHAIN OF EVENTS: KEY DOWN → HOLD → KEY UP → STAR MAP

**Written:** 2026-08-10 16:28:00
**Asked for by Jamal, 2026-08-10 16:22:00:**
> *"i mean that the shape it has after letting go slowly fades into the starmap and its own gravity again but it needs to make sense scientifically not just cosmetically .. NASA (our dream collaborator) dropped new pics of galaxies forming and stars dying and they reallllly look a lot like what this almost looks like. it's just the motion.. check the entire process / road / chain of events that happen when i press a chord / key and let it go."*

**Every claim below carries a `file:line` I read today.** Nothing here is inherited from an older doc.
**Bundle at time of writing:** `2026-08-10 16:09:36`. **Nothing was built for this audit — it is a read-only pass.**

---

## 0. THE ONE-LINE ANSWER

**The release does not "make sense scientifically" because none of the three stages before it are physics either.**
Attack is an **authored explosion**. Sustain holds matter with a **velocity damper that we label crystallization**.
Release **switches those authored forces off** and lets real self-gravity take over.

So the moment of release is not a physical evolution — it is a **handover between two different regimes of
authorship**, and that is exactly what the eye reads as a snap. **Nothing is conserved across it, because
nothing was ever stored.**

---

## 1. ⚠️ FIRST, A CORRECTION TO WHAT I TOLD HIM EARLIER TODAY

At 16:05 I said the release is a fixed **400 ms** and called that "an audio time constant doing a physics job."
**That was wrong, and the code is better than I described it.** `envelope.cpp`, `EnvPhase::Release`:

    float relDur = std::clamp(sustainHeld, params.release, 1.5f);

`params.release = 0.400f` (`envelope.h:20`) is the **FLOOR, not the value**. The actual release duration is
**`sustainHeld`, clamped to [0.400, 1.5] seconds** — where `sustainHeld` is the time the note was held, captured
at `noteOff()`. The comment says it plainly: *"a quick tap releases fast, a long hold takes up to ~1.5 s to fall
back into the BH."*

**So the release ALREADY scales with hold length.** The mechanism he keeps hitting with long holds is therefore
**not** "a fixed short release" — that theory is dead. It is something that scales the *wrong way* or not at all
against a release that is already stretching. **This correction is why the settle-hold I built at 16:07 was the
wrong fix, and it is the single most useful thing in this audit.**

---

## 2. THE CHAIN, STAGE BY STAGE

`envelopePhase`: `0` silence · `1` attack · `2` decay · `3` sustain · `4` release (`particles.metal:69`).
It is branched on at **27 sites** in `particles.metal`, all hard thresholds, **none blended**.

### STAGE 1 — KEY DOWN → ATTACK (0.020 s)

| | |
|---|---|
| **Envelope** | `phase = Attack`, `envTime = 0`, `envStart = amplitude` (retrigger-smoothed). Exponential approach, `k = 5/attack` → 99.3% in 0.020 s. `envelope.cpp` `noteOn()` |
| **What the matter is told to do** | 🚨 **A SCRIPTED EXPLOSION.** `explosionPower = (1.0 - t) * 80.0 * min(lcI, 3.0)`, pushed **radially outward** along `dir`, `particles.metal:978`. Plus a **shockwave ripple**: `sin(r*20 - t*50)` inside a moving front `abs(r - t*2) < 0.3`, `:995-1000`. Plus a blast-wave temperature ramp `mix(8.0, 2.0, t)`, `:991`. |
| **Physics content** | **None.** This is an authored gesture: a radial impulse whose magnitude is a function of envelope progress, and a hand-written sine ripple. No energy budget, no mass dependence, no conservation. |

### STAGE 2 — DECAY (0.100 s) AND SUSTAIN (held)

| | |
|---|---|
| **Envelope** | Decay: exponential to `targetAmp × 0.700`. Sustain: **`amplitude` is pinned constant** at `targetAmp × 0.700`. `envelope.cpp` |
| **The organizer** | ✅ **The cavity EIGENMODE, and this part is honest.** `main.cpp:2360-2363`: bit23 is **ON by default** (`SS_NO_EIGENMODE` disables it), so the cylindrical cavity eigenmode + Gor'kov force own the shape. |
| ⚠️ **NOT active by default** | The **"SUN — radiating sphere"** shell at `particles.metal:1018-1035` — an 80·lcI spring onto one target radius plus a hard outward brake — is gated `sunShellOn = !(u.debugFlags & (1u<<23))`, and bit23 **is** the default. **So the shell stands down.** Its own comment calls it *"a CONSTRUCTED hollow shell that overpowers the eigenmode… ~2 orders weaker"*. **It is off. Do not blame it, and do not turn it on.** |
| 🚨 **CRYSTALLIZATION — the important one** | `hardness` integrates over sustain: `rate = mix(1/15, 1/10, density)` per second → **10–15 s to full**, stored in `entanglement.y`, `particles.metal:2645-2659`. Then `lock = mix(1.0, 0.05, hardness)` applied as `vp *= lock` at **`:2794-2797`** — at full hardness a **95%-per-frame velocity kill**. |

### 🚨 STAGE 2's STRUCTURAL DEFECT — WE CALL IT A SOLID, WE BUILT A DAMPER

The lock is applied at `:2795`. `finalV` is built at `:2847`:

    float3 finalV = (float3(vpx,vpy,vpz) * dynamicFric * coolMul
                     + float3(shiftVx,shiftVy,shiftVz)) * soften;

**The lock scales `vp` — the CARRIED velocity. `shiftV` — this frame's FORCE IMPULSE — is added AFTER it,
untouched.** So during a hold:

- the crystal **bleeds off speed** every frame,
- but **every force is still applied at full strength**, every frame,
- and **nothing is stored in tension.**

⭐ **A real solid resists FORCE. This one resists SPEED.** That is the whole bug in one sentence, and it is
the mechanism behind his report *"it continues from before it actually stopped"*: the matter looks stopped
because its speed is being scrubbed, but the force vector pushing it never changed. Remove the scrubbing and
motion resumes **in the same direction, at the same rate** — as if the hold had never happened. **Because,
dynamically, it hadn't.**

🔎 **And this is why LONGER HOLDS ARE WORSE**, even though the release duration already stretches (§1):
`hardness` keeps integrating for 10–15 s, so a longer hold means a *harder* damper masking an *unchanged*
force. The visual discrepancy at release grows with hold time while the release itself only stretches to a
1.5 s cap. **The two do not scale together.**

### STAGE 3 — KEY UP → RELEASE (0.400 … 1.5 s, scaled by hold)

| | |
|---|---|
| **Envelope** | `noteOff()` captures `sustainHeld = envTime`, sets `phase = Release`, `envStart = amplitude`. Amplitude decays exponentially over `relDur`. `envelope.cpp` |
| **Friction** | Hard-set: `if (phase > 3.5) baseFric = pow(0.95, dt)`, `particles.metal:780`. Note this is **LIGHTER** damping than loud play (`pow(0.9, dt)`) — at the boundary, damping *drops*. Measured magnitude: **0.09% per frame.** Real, but small. |
| **Target radius** | Eases `sustainR → 0.75` across `t`, `:846`. Continuous at `t=0` by construction. |
| **Crystal lock** | ✅ **The A4 fix (mine, 15:12:02, live):** the lock is now ramped out across the release instead of stopping in one frame, `:2784`. **He confirmed this improved things** ("better but not gone"). |
| **Rebirth stream** | 🚨 **CUTS DEAD.** `sustainHeld = (phase >= 2.5 && phase < 3.5)`, `:664` → `streamNow` false. Particle births stop **in one frame** at note-off. |
| **Node flares** | 🚨 **CUT DEAD.** The eruption/heat-flash system is gated `phase >= 1.5 && phase < 3.5`, `:1123`. Bright emissive events vanish **in one frame** at note-off. |

### STAGE 4 — RELEASE ENDS → OFF / STAR MAP

`phase = Off` when `envTime >= relDur` or `amplitude < 0.0001`. Then `isSilence = (phase < 0.5)`, `:827`, and the
silence branch at `:850` takes over with its own **accretion-disk geometry** (disk radius 0.45, `u.diskThickness`).

⏸️ **THIS BOUNDARY IS EXPERIMENTALLY RULED OUT AS THE SNAP.** I built a 2 s hold of the release regime at
16:07:41 specifically to delay this switch. His verdict at 16:12: *"noo because now the stuck moment is before
the pause u just introduced. thats where the snap is at."* **The hold did not hide the snap — it isolated it.**
Reverted 16:09:36. **Do not retry a settle-hold here.**

---

## 3. WHAT IS AUTHORED vs WHAT IS PHYSICS

| Stage | Driving term | Authored or physical? |
|---|---|---|
| Attack | radial `explosionPower`, sine shockwave | ❌ **authored gesture** |
| Decay / Sustain | cavity eigenmode + Gor'kov | ✅ **physical** (this is the good part) |
| Sustain hold | `vp *= lock` velocity damper | ❌ **authored, and mislabelled as a solid** |
| Release | damper removed, `pow(0.95,dt)` drag | ⚠️ **a switch, not an evolution** |
| Silence | self-gravity + `pow(0.99,dt)` drag | ✅ **physical** — the drag IS the accretion mechanism, `:772` |

**The two ends of the chain are real. The middle is stagecraft, and the release is where the stagecraft is
handed back to the physics with no transition function.**

---

## 4. ⭐ WHAT WOULD MAKE IT SCIENTIFICALLY TRUE — AND IT IS THE NASA PICTURE

His reference is right and it names the correct physics. **Galaxies forming and stars dying are both the same
story: a self-gravitating clump collapses when its SUPPORT is removed.** In real clouds the support is thermal
pressure and turbulence; when it decays, gravity wins and the cloud collapses — continuously, because the
support term falls off smoothly. That is the Jeans criterion, and it is the most photographed process in
astronomy.

**So the correct model is a change of TERM, not a change of REGIME:**

- **Sound = support.** While a note is held, the acoustic field supplies a **pressure-like support term** that
  opposes self-gravity. Not a damper on velocity — an **outward force** that enters the same force sum as
  gravity, at `shiftV`.
- **Release = support decaying.** `noteOff` does not switch anything off. It starts the support term decaying
  toward zero over `relDur` (which **already** scales with hold length, §1).
- **Collapse is then automatic and continuous.** Gravity was always in the sum; it simply stops being
  balanced. Nothing switches. There is no boundary to snap at, because **no branch is crossed** — one
  coefficient goes to zero.
- **"Fades into the star map and its own gravity"** is then literally what the equations do, rather than
  something we stage-manage on top of them.

⭐ **This also fixes "it continues from before it stopped" at the root**, because support-vs-gravity is a real
equilibrium: while held, the clump is genuinely balanced, not merely slowed. When support decays, matter
accelerates **from rest** under gravity — it does not resume a stored trajectory, because there is no stored
trajectory to resume.

⚠️ **Honest cost, stated now and not in week three:** this replaces the sustain damper and reshapes the
release. It touches `particles.metal`'s force sum, not just a boundary. It is **not** a one-line change, and it
is a physics change — the shape during a hold **will** look different, because it would be an equilibrium
instead of a frozen snapshot. **That is Jamal's call to make, not mine.**

---

## 5. THE DISCONTINUITY LEDGER — everything that changes in ONE FRAME at note-off

Ranked by how visible each should be. **Only the first has been fixed.**

| # | Site | What flips | Fixed? |
|---|---|---|---|
| 1 | `:2794` | crystal lock 0.05 → gone | ✅ ramped (A4, 15:12:02) — **he confirms improved** |
| 2 | `:664` | rebirth stream stops dead mid-flow | ❌ untouched |
| 3 | `:1123` | node flares / heat flashes stop dead | ❌ untouched |
| 4 | `:780` | friction `pow(0.9)` → `pow(0.95)` | ❌ untouched — **measured 0.09%/frame, smallest of the four** |
| 5 | `:846` | target radius begins easing | ✅ already continuous at `t=0` |

🚨 **#2 and #3 are the untested candidates.** Both are **creation/emission** events stopping instantly rather
than motion changing — which fits *"another thing was at work"* better than a damping change does, and neither
has been ruled out by any measurement.

---

## 6. WHAT I RECOMMEND, IN ORDER

1. ⭐ **Decide the big question first: damper or support term (§4).** Everything else is patching around it.
   If §4 is approved, items #2–#4 in the ledger get re-examined *inside* the new model rather than fixed twice.
2. **If §4 is too big before Berlin:** ramp #2 and #3 the way #1 was ramped — fade the birth-stream rate and the
   flare intensity out across the release rather than gating them on the phase. Cheap, same shape as the fix
   that already worked, and testable in one play each.
3. **Do not touch #4.** 0.09% per frame is not what he is seeing.

---

## 7. WHAT THIS AUDIT DID NOT ESTABLISH

- **Which of #2 or #3 dominates.** Both are untested. They are separable: #2 changes particle COUNT, #3 changes
  BRIGHTNESS, so one play with each ramped independently would tell them apart.
- **Whether the eigenmode shape itself is stable during a long hold** — I read the force terms, I did not
  measure the resulting shape over time.
- **Anything about the render path.** This audit is `particles.metal` + `envelope.cpp` + `synth.cpp` only.
  The "mergers look white and cheap, they used to be black" report is **not** covered here and remains open.
