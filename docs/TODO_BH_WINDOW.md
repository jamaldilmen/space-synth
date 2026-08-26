# 🕳️ BLACK HOLE WINDOW — TODO

**Worktree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-BH` · branch `bh-gargantua-2026-08-26`
**Scope:** **OPTICS** — lensing, photon ring, beaming, shadow, the far-side and underside images. **NOT** the field substrate.
**Bible:** `docs/reference/BH_REFERENCE.md` + the two JPEGs. **Ringdown physics:** `docs/reference/SPACE_NOT_ROOM_2026-08-26.md` §6.
**Last Updated:** 2026-08-26 14:05:00 — 🚨 **B-3 IS RETRACTED AND THE REAL DEFECT IS NAMED. READ §B-0 FIRST.**

> 🚨 **NOTHING BUILDS AND NO TOKEN MOVES WITHOUT ASKING HIM FIRST.** His order 2026-08-26.
> **His goal:** *"we need gargantua. were very close but were not there yet."*

---

## 🚨 B-0 — THE REAL DEFECT, IN HIS WORDS. EVERYTHING ELSE IS SECONDARY.

**His verdict 2026-08-26, and it overrides the framing this file previously had:**
> *"i always rotate the cam always poke around i see that its still fake lensing everything. the starting view is not the problem. **it is not a 3d body as per reference that is a fact.** your suggestion is evasive."*

⛔ **B-3 ("four features are invisible face-on") IS RETRACTED AS A FRAMING.** The measurement behind it was real, but the CONCLUSION — *"R4/R5/R6 are not broken, just structurally invisible"* — explained a real defect away as a viewing accident. **He has looked from every angle. It is still fake. His eyes are ground truth; do not re-derive this.**

⭐ **AND HE ALREADY DIAGNOSED IT ON 2026-08-13, WITH THESE SAME TWO REFERENCE IMAGES:**
> *"the bend we have is like the one on a plate — see the bending of the pavilion above the plate. that's exactly what our fakeish black hole lens looks like. **it is never physically bending anything.**"*

**THE MECHANISM:** our lens warps an ALREADY-RENDERED IMAGE in screen space, the way a glossy plate bends a reflection because its surface is curved. No light is deflected — the picture is. A real gravitational lens deflects light **before the image exists**. That is exactly "not a 3D body."

**THE CEILING, board row L3:** *"A two-instance sprite scheme cannot produce S3. n ≥ 2 windings need a per-pixel integrator. This is a representation ceiling, not a bug."*

⚠️ **THEREFORE B-2 (the R2 clamp fix) IS NECESSARY BUT NOT SUFFICIENT.** Dropping the clamp will spread the spike into a gradient — a real improvement, still worth doing. But the bible defines the photon ring as light that *"orbited two, three or even more times"*. Two sprite instances give two images; they cannot give n≥2 windings. **The clamp fix improves R2. It does not deliver it.**

### ⭐⭐ AND THE RULE THAT WAS BLOCKING THE FIX HAS BEEN CLARIFIED — 2026-08-26
> *"particles are the black hole just means its the same entity. it can be a different state okay. it remains the same thing which in reality also just behaves differently in different conditions."*

**NO SECOND LAYER IS ABOUT IDENTITY, NOT REPRESENTATION.** It bans a second bolted-on object. It does **NOT** ban the same matter being evaluated differently in a different STATE — water/ice/steam are one substance. 🟢 **So a per-pixel integrator for the collapsed state is NOT forbidden**, provided it is the same entity sharing the same state, mass, position and constants — not a second world drawn on top. **L3's ceiling is liftable.**

**The test:** shares the field's state and is the same matter → allowed. Separate visual with its own independent existence → still banned.

---

## THE SIX REFERENCE ROWS — measured state, 2026-08-26

| # | Feature | State |
|---|---|---|
| **R1** | **Shadow ≈2× the horizon** | ✅ **PASSES — MEASURED.** Shadow edge **2.612 r_s**, three settled frames at 430.04 / 430.44 / 430.71 px, repeatable to **0.7 px**. Interior **2.1× darker** than the 470–700 px annulus. Scale independently checked: the ISCO ring reads 3.06 r_s against a true 3.00, so ~2%. **R1 is not the gap.** |
| **R2** | **Photon ring, thinning and fading inward** | 🔴 **FAILS. Cause identified in one line.** ONE narrow spike — 424px:0.87 → 428:1.56 → **432:6.12** → 436:3.55 → 440:0.98, **FWHM ~6–7 px on a 433 px ring = 1.5% of radius.** A delta function. **Inward of it, NOTHING:** r=300..426 px (2.06→2.60 r_s) flat at the background floor, 0.201–0.228, no trend. The bible's exact failure text — *"One flat bright circle is not a photon ring"*. **Cause:** `th = max(th, 2.62f*rsW)` clamped INSIDE the Newton loop, every iteration. A photon ring is a gradient; a clamp is a spike. |
| **R3** | Thin disk | ⛔ **NOT THIS WINDOW'S** — substrate (h/r = 0.746, a thick RIAF). |
| **R4** | **Doppler beaming, visibly asymmetric** | 🟢 **OPEN — see B-4, he approved retrying the real law.** ⚠️ The 1.14× measured asymmetry was taken FACE-ON, where ~1× is expected, so **that number tests nothing** — it is not evidence the law is too weak. Re-measure off-axis alongside the new law. ⚠️ **The law IS still the old fudge** (`render.metal:1763-1764`, `beam = max(0.35, 1+0.8·vLos)`, `pow(beam,1.4)`) giving ~7.3× where the true law gives 41×. Both g³ attempts were reverted 2026-08-14. Board §4c called this block HIS via presets; **he has now opened it: *"i dont know why it was reverted try it again."*** |
| **R5** | **Far-side image arching OVER the shadow** | 🔴 **OPEN — B-0 governs.** Mechanism is LIVE and physical (primary at `+pHat·thEff`, `render.metal ~1155`). |
| **R6** | **Underside image, a distinct arc BELOW** | 🔴 **OPEN — B-0 governs.** Mechanism LIVE (secondary at `−pHat·th`, `~1222`); §2's parity proof holds; second instance only exists at `bhStrength > 0.5` (`renderer.mm:3916`). |

---

## ⛔ B-3 — RETRACTED 2026-08-26. KEPT ONLY AS PROVENANCE. **NOT THE BLOCKER.**

> 🚨 **Everything in this section is a TRUE MEASUREMENT with a WRONG CONCLUSION.** The camera really does open face-on — that is verified. But he rotates it routinely and reports the lensing is still fake, so face-on is NOT why it fails. **Read B-0. Do not act on this section.**

**THE CAMERA OPENS DEAD FACE-ON TO THE DISC.** Verified: `camera.h:31-32` sets `theta = π/2, phi = 0`; the eye formula (`:74-76`) then gives **eye = (0, 0, ρ)** — sitting on **+Z**, which is the disc's own angular-momentum axis (the disc is in X-Y; `render.metal:1668` confirms "prograde about Z").

**Line-of-sight velocity is ~0 everywhere by construction**, so beaming cannot appear; and the far-side arch and underside arc only exist off-axis. Every frame shows a perfect circle — the same fact stated visually.

⛔ **THE CLAIM THAT FOLLOWED — "four of six cannot appear in the opening view, this is why it is not there yet" — IS THE RETRACTED PART.** It is evasive: it blames the framing for a defect he sees from every angle.

**Synthetic input cannot fix it:** arrow taps are `TAP_STEP = 0.06 rad` against `SOFT_LOCK_RAD = 0.12 rad`, so a tap lands inside the soft-lock and is pulled back to π/2. Held arrows and posted mouse drags did not tilt theta either.

⛔ **The brain proposed an `SS_CAM_THETA` env var (precedent: `SS_CAM_RHO` already exists at `camera.h:27` for exactly this reason) and he pushed back: *"i never asked u to touch the camera wtf."* NOT to be raised again unless he opens it.** → **Q5.**

---

## THE ROWS

| # | Row | State |
|---|---|---|
| **B-1** | R1 shadow size | ✅ closed by measurement |
| **B-2** | **R2 fix — drop the in-loop clamp**, let the exact log-divergent `alpha(b)` LUT place the images so they pile toward `b_c` with a real density falloff. No new pass, no perf cost, sprite-native. The 2026-08-14 capture test (`along>0 && thEff < 2.598·rsW → cull`) already covers shadow-emptiness for the identical particle set, so the floor is redundant for that job. **Predicted:** the spike at 2.61 r_s spreads into a gradient and the empty 2.06–2.60 band stops being empty. Should also sharpen R5. ⚠️ **Risk:** the clamp may be doing numerical duty near the divergence; fallback is a clamp at 2.598 (the capture radius) so it stops being a pile-up 0.8% outside the cull. | ⬜ **ready, unbuilt — Q6** |
| **B-3** | ⛔ **RETRACTED — see B-0.** Off-axis viewing is NOT the blocker; he rotates the camera routinely and it is still fake. The blocker is image-space (plate) lensing. | ⛔ withdrawn |
| **B-4** | R4 beaming law | 🟢 **APPROVED 2026-08-26 — TRY THE REAL LAW AGAIN.** *"i dont know why it was reverted try it again."* Nobody knows why the two g³ attempts were reverted on 2026-08-14. Land it as ONE change, measured, and let him rule on the look. |
| **B-5** | 🔔 **QNM RINGDOWN — NEW.** The light ring IS the bell: in the eikonal limit the QNM's real part is the photon orbit's frequency and its imaginary part that orbit's Lyapunov exponent, both `1/(3√3 M)`. **So R2 and the audible ringdown are ONE structure.** Stellar-mass holes ring inside human hearing with no pitch-shift (1 M☉ ≈ 12.4 kHz, 10 M☉ ≈ 1.24 kHz, ~62 M☉ ≈ 200 Hz); **ours at 2.963e+04 M☉ ≈ 0.42 Hz**, needing one stated ratio (~×1000). ⚠️ Unverified: whether anything computes a QNM today, and whether our hole's mass is steady enough to hold a pitch. | 🟡 **DEFERRED BY HIM — LAST, AND IN THE BRAIN WINDOW.** *"when everything is done we do it in here."* Not this window's job now. |
| **B-6** | Board corrections carried by the brain | ✅ landed: **L6** (metric shadow defaults FALSE since 2026-08-22, so `SS_NO_AMR=1` DOES work by default; the double-booking hazard returns only if he ticks it on) and the **8th "comment is not a mechanism"** (`app_state.h:62` claims bit15 integrates null geodesics to `b_c = 2.598 r_s`; `0x8000` appears once, at `render.metal:963`, and culls at `rIn < horizonR` — a **1.0 r_s** cull) |

---

## ⛔ CONSTRAINTS
- **NO SECOND LAYER** — particles ARE the black hole; never a raytracer stacked on particles.
- **SHADOW = ABSENCE, NEVER PAINT** — remove light at the source.
- **ZERO mergers. NEVER test the hole above 1× warp.**
- **Colour is NOT the target** — the reference's orange is a NASA render choice; our colour defect is G16.
- **Check the RENDER before the physics** — a past "rings bug" was the BH time-lapse rotating the render.
- ⚠️ **A radius alone cannot separate the 2.62 clamp from the 2.598 capture radius** — 0.8% apart against ~2% systematic. BH stated this itself. Use SHAPE and SOURCE, not radius.

---

## ✅ NO OPEN QUESTIONS — his rulings are all in
**Q5** retracted (B-0) · **Q6** measure first, always · **Q7** approved, retry the real law · **Q8** deferred to the brain window, last.

🚨 **The build token is HIS to grant, EVERY TIME. Ask before building or launching — no exceptions.**
