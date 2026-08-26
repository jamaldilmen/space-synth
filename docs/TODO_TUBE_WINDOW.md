# 🌀 TUBE WINDOW — TODO

**Worktree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-RESONATOR` · branch `tube-resonator-2026-08-26`
**Scope:** the SUBSTRATE — field, wave equation, domain, how particles ride it. **NOT** black-hole optics.
**Physics brief (read first):** `docs/reference/SPACE_NOT_ROOM_2026-08-26.md`
**Last Updated:** 2026-08-26 14:05:00 — ⭐ **ALL BLOCKERS CLEARED, HIS ANSWERS ARE IN. THIS IS BUILDABLE.**

> 🚨 **NOTHING BUILDS AND NO TOKEN MOVES WITHOUT ASKING HIM FIRST.** His order 2026-08-26: *"before anybody builds anything or moves tokens ask me. this is going too fast."*
> ⛔ **THE VENUE IS OUT OF SCOPE.** *"do not concern yourself with the room."* Cologne's dimensions are NOT the resonator.
> ⛔ **NEO IS NOT A BASIS.** *"NEO was a fatal error dont use it as a basis."*

---

## HIS GOAL, IN HIS WORDS
*"kill the tube. the field becomes the resonator not a fake tube."* · *"WE ARE SIMULATING WAVES NOT PARTICLES. the particles are the carrier."* · *"i want full screen shapes and patterns not a tube thats the whole point."* · *"when we play we insert pressure into the space. its space synth not rooms synth."* · *"the camera never sees the rim. it can be a sphere u know."*

## ⭐ HIS RULING 2026-08-26: **THE ACOUSTIC CUTOFF IS THE MECHANISM**
Below cutoff → **trapped**, discrete standing modes, structure that holds. Above cutoff → **untrapped**, continuous spectrum, radiates outward and leaves. **The frequency itself decides whether it stands or escapes**, so "resonator" vs "open space" is not a choice we make — one medium does both. Full working in §2d of the brief.

---

## ⭐ HIS ANSWERS 2026-08-26 — every Q1–Q4 blocker is now RESOLVED

| Q | His ruling |
|---|---|
| **Q1 cutoff** | **MEASURED FROM THE FIELD.** *"both want to be measured by the field right its obvious to me."* Not a stated constant. |
| **Q2 trap** | **MEASURED FROM THE FIELD**, same answer. ⭐ And it falls out for free: for a polytrope `c_s ∝ ρ^((γ−1)/2)`, so sound speed RISES where density rises → waves heading into the dense core speed up, bend, and refract back. **That IS the helioseismology trap, straight out of `cellMass[]`.** ⚠️ `particles.metal:991`'s `pressure = log2(count/24)*12` is a crowd-repulsion heuristic, NOT thermodynamic — do not mistake it for an EOS. |
| **Q3 basis** | 🔵 **SPHERE.** `Y_lm × j_l`. ⇒ **T-8 (G9) dissolves as a side effect.** |
| **Q4 domain** | 🚨 **IT IS ALL ONE DOMAIN NOW.** *"q4 is the domain thats the whole point its all 1 now."* The R=100 sphere IS the space. Play does NOT shrink it. **This does not fix T-1 — it DELETES the concept T-1 was fighting.** |
| **Q10 γ** | **5/3 — "sharper structure."** Ordinary matter, springy, sharp sound-speed change with depth ⇒ waves turn back sharply ⇒ crisper shells. (4/3 was the softer/deeper alternative; rejected.) |

⭐ **ON SCALE, his ruling:** *"we can still tune how the shapes scale within the sphere to taste eventually we just need a physically grounded starting point."* → **Derive it honestly first. Add the taste dial after. Do not pre-tune.**

⚠️ **HEADS-UP HE HAS ALREADY ACCEPTED:** one domain at R=100 spreads the same 2M particles over ~4,600× the volume of the old tube — mean spacing **0.077 → 1.28**, 16.7× coarser in absolute terms. If the camera frames the whole sphere the apparent fineness is unchanged. **A coarse-looking first frame is expected, not a bug.**

---

## THE ROWS

| # | Row | State |
|---|---|---|
| **T-1** | 🚨 **KILL THE PLAY CLAMP — THIS IS THE CORE.** `particles.metal:3325` mixes `STAR_MAP_CAP=100` down to `ORBIT_R_CHLADNI=6` the moment he plays: **16.7× linear, ~4,600× volume.** The tube exists ONLY while playing, which is exactly backwards from *"visualize the frequency im playing"*. Line 340's own comment admits the star map has *"no tube limit"*. | 🟢 **UNBLOCKED — and the framing changed.** Q4 makes it ONE domain, so this is not "replace the play cap with a bigger one", it is **DELETE THE REGIME SPLIT**. Still moves together with the basis (T-3). |
| **T-2** | 🎯 **BUILD THE CUTOFF.** Must be **DERIVED AND NAMED**, never a magic number. It is the single most important dial in the system: it decides which notes stand and which escape. In the Sun it falls out of density scale height and sound speed (≈5.3 mHz; at 6 mHz ~2% reflects, by 7 mHz <0.3%). | 🟢 **UNBLOCKED** — derive from `cellMass[]`, γ=5/3 |
| **T-3** | **THE MODE BASIS.** Spherical `Y_lm × j_l` vs cube `cos·cos·cos`. ⛔ The NASA mesh argument (Cartesian imprints a fake ℓ=4) **does NOT decide this for us — our field has no mesh**, Ψ is evaluated analytically per particle. See brief §2b. | 🟢 **RESOLVED — SPHERE.** `Y_lm × j_l` |
| **T-4** | **THE TRAP PROFILE.** Helioseismology traps by a *sound-speed gradient*, not a wall — the Sun rings with no boundary. Derive ours from the existing gravity/density field (his *"physical link to orbits and gravity"*), or state a profile explicitly. | 🟢 **UNBLOCKED** — from the density field, γ=5/3 |
| **T-5** | **THE REST-STATE SPHERE (R=100).** Deliberately untouched so the first A/B stays judgeable. | 🟢 **RESOLVED — it IS the domain.** One space, R=100, never shrinks |
| **T-6** | **FIX THE MISLABEL, KEEP THE VALUE.** `modes.h:11` calls the field a Bessel zero; `modes.cpp:24` assigns `440·2^((midi−69)/12)` — Hz. Under the cutoff model that Hz value becomes the **actual drive frequency**, so the long-standing defect becomes the input. Relabel, do not delete. | ⬜ ready, low risk, no blocker |
| **T-7** | **DORMANT Hz GAIN BUG.** `particles.metal:2479` `sculptStrength = visualAmp * voices[vi].alpha * 25.0f * …` multiplies a force gain by a frequency in Hz — C5 pushes ~8× harder than C2. **DEFAULT OFF** (bit16 skip; `SS_SCULPT=1` re-enables). | ⬜ not urgent, record it |
| **T-8** | ⭐ **G9 DISSOLVES IF THE BASIS GOES SPHERICAL.** Crystallization (`ridgePull`) is built from the **spherical-harmonic** gradient (`:2470`) while shapes are drawn by the **cylindrical** eigenmode — so holding a note drags matter OFF the pattern. One basis ⇒ one field ⇒ the bug stops existing rather than needing a fix. | ⬜ falls out of Q3 |

---

## ⛔ CONSTRAINTS — verified in source, do not relearn the hard way

- **THE GOR'KOV FORCE IS ALREADY CORRECT. DO NOT TOUCH IT.** `:2584` `F = −contrast·Ψ·∇Ψ`; `:2575` already has dense matter seeking pressure NODES. His *"they inject force into the field. into nodes"* is built.
- ⚠️ **`contrast` IS BIPOLAR** — `:2583` spans **[−1,+1]**. Dense seeks nodes, light seeks ANTINODES. Any "where matter goes" claim must say WHICH HALF. *(The brain got this wrong once; TUBE caught it.)*
- ⚠️ **`j_l` (spherical Bessel) DOES NOT EXIST HERE.** Only cylindrical `besselJm` (`:487`). 🚨 **This project has been burned TWICE by Bessel evaluators** — an asymptotic form gave 8.9e-1 garbage at m≤11 and needed Miller downward recurrence to reach 2.6e-7; a data-dependent loop break once HUNG PSO creation. **Measure any new evaluator against known values before it ships.**
- **Chords:** his ruling — *"a unified face of each harmonic weighted equally."* True superposition, no special-casing.
- **Camera stays as it is.** *"so the scale of collapses and explosions etc remains."*
- **The domain shape must not be visible** — *"so it doesnt become visible whether its a sphere or a cube now."*
- **ONE verifiable change → confirm it landed → say what to look at → STOP.** Never batch.

---

## ✅ NO OPEN QUESTIONS. 
🚨 **But the build token is still HIS to grant, every single time — ASK BEFORE BUILDING OR LAUNCHING.**
