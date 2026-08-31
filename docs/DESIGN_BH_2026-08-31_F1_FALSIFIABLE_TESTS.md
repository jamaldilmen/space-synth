# F1 — FIVE TESTS THAT CAN FAIL ON A CAPTURED FRAME
**Written:** 2026-08-31 17:08:54 · FABLE window · feeds BRAIN's P4 (the bending science prompt)
**His complaint, verbatim:** *"our space time bending is fucked lol."*
**Standing diagnosis:** [[space_synth_lens_is_a_plate_2026-08-13]] — we bend the IMAGE the way
a glossy plate bends a reflection; a real lens bends the LIGHT.

**The rule these are written under:** every test must be able to FAIL on a captured frame.
A test a design satisfies by construction is worthless. Each predicate below names its
measurement, its pass value, its fail value, and — the part that makes the set honest —
**which architecture CLASS fails it and which class can FAKE it.** No single test below is
sufficient; the SET is. The current tree fails all five trivially (nothing draws a lensed
image at all — both renderers deleted `00741f2`), so every one of these is a real gate,
not a formality.

**Measurement substrate, all tests:** captured frames analysed offline — `screencapture -x`
→ ffmpeg → raw RGB, centroid/histogram extraction ([[feedback_take_your_own_screenshots]]).
Where a test needs one identifiable emitter, the probe is a debug tint on one particle id —
a measurement aid, not a render feature. FABLE does not capture; OPUS runs these.

---

## T1 — THE SEAM: integrator and sprites must agree where physics says they are identical

**Claim under test:** at the region boundary `B_geo` the geodesic and the straight ray are
the same ray to sub-pixel, so the handover is invisible **by calibration being right**, not
by blending.
**Setup:** identical field state rendered twice — integrator-on and sprites-only (frozen
state A/B, or a split-frame with the seam through the annulus; OPUS's choice).
**Measure:** matched star centroids in the annulus `b ∈ [B_geo, 1.1·B_geo]`; per-pixel RGB
difference against a NULL measured from two consecutive same-mode frames (the temporal
jitter floor).
**PASS:** median matched-centroid displacement < 0.5 px, max < 1 px; mean |ΔRGB| within
2× the null.
**FAIL:** any matched centroid ≥ 1 px, or |ΔRGB| structure visible above the null in the
annulus.
**What a failure means (diagnostic, not just a verdict):** displacement scaling with `r_s`
⇒ the LUT mass-scale factor is wrong; displacement independent of `r_s` ⇒ the `B_geo`
handover criterion is wrong; RGB-only mismatch with centroids clean ⇒ the emission or g
path diverges, not the transport.
**Who fails / who fakes:** this one is a CALIBRATION gate on the F1 design itself — it does
not discriminate architectures. It is first because it can fail first.

## T2 — PARITY: the >180° image arrives left-right swapped

**Claim under test (his own test):** rays from the far side that travel more than 180°
CROSS, so their image is mirror-reversed. A single-valued image-space displacement is
orientation-preserving everywhere it does not fold — it cannot produce a mirrored image.
**Setup:** three tinted particle ids A, B, C behind the hole (or one asymmetric cluster),
positioned so both a direct and a secondary image exist.
**Measure:** signed area of triangle A→B→C (vertex order fixed by particle id) in the
direct image, `S₁`, and in the secondary image, `S₂`. Require |S| > 9 px² in both so the
sign survives the PSF.
**PASS:** `sign(S₂) = −sign(S₁)`.
**FAIL:** same sign, or no secondary image exists (the current tree's state).
**Exact or approximate — the answer, stated:** at `a = 0` in the METRIC the flip is
**EXACT at every inclination, every hole mass, every camera position** — spherical symmetry
makes every ray planar, and the >180° family's mirror is a theorem, not a tendency. It
degrades ONLY if the metric gains spin: frame dragging twists the ray planes, the flip
stays clean for equatorial rays but off-equator the secondary is sheared as well as
mirrored, with the image-rotation exponent τ varying around the ring (Gralla–Lupsasca
2020a, via P1 §1.4). Our geometry is `a = 0` (`render.metal:337` is the Schwarzschild
capture parameter), so for us: exact, no conditions. **The degradation onset with spin is
itself a P4-worthy observable.**
**Who fails / who fakes:** every single-valued warp fails — the plate class. 🚨 **Necessary
but NOT sufficient, and our own history proves it:** the deleted forward lens PASSED parity
by explicitly solving a second root (`det J < 0` on record, `BOARD_BLACKHOLE.md` §2) and
still had to die. A k-root forward map fakes T2. That is why T3 exists.

## T3 — RING CLOSURE: alignment must smear a point into an arc, never into k dots

**Claim under test:** as a source approaches exact alignment behind the hole, genuine
transport stretches its image azimuthally, closing into an Einstein ring at exact
alignment. A forward map with k coded roots produces exactly k point images at ANY
alignment — the image count is a property of the CODE, not of the geometry. This is the
structural test no root-solver can pass, at any k.
**Setup:** one tinted emitter whose angular misalignment `θ_src` behind the hole passes
through small values (orbital motion provides this for free; capture the closest-approach
frames).
**Measure:** azimuthal extent `Δφ` of the emitter's connected image at `b ≈ b_E` (the
Einstein radius of its distance configuration), at the frame of minimum misalignment.
**PASS:** `Δφ ≥ 180°` when `θ_src < 0.1·θ_E`, and `Δφ` observed GROWING as `θ_src`
shrinks across neighbouring frames.
**FAIL:** discrete dots (`Δφ` at the PSF floor) regardless of alignment — the k-root
signature.
**Who fails / who fakes:** the plate fails; every finite-root forward map fails —
**including the deleted lens, which is the point.** A fog march along real geodesics
passes (see the scope note at the end).

## T4 — RESURRECTION: light from behind the capture sphere must arrive bent around it

**Claim under test:** an emitter whose STRAIGHT line to the camera is blocked
(`b_straight < b_c`) is still visible — its light arrives on curved paths landing at
`b ≳ b_c`. A post-render image warp cannot show it: the straight-path cull
(`render.metal:990`) killed those pixels before any warp ran; there is nothing to move.
Bending the LIGHT resurrects it; bending the IMAGE cannot.
**Setup:** one tinted emitter at `b_straight < 0.8·b_c` (geometric occultation confirmed
from the logged positions).
**Measure:** presence and location of that emitter's image.
**PASS:** image present at `b ∈ (b_c, 3·b_c)`, on at least one side of the shadow.
**FAIL:** emitter absent from the frame.
**Who fails / who fakes:** the plate class fails by construction — this is the cleanest
single-frame refutation of "we bend the image." ⚠️ A per-sprite FORWARD displacement
applied before the cull (the old lens's ordering, §U1) can fake T4 — so T4 kills the
post-render warp class specifically, and leans on T3 to kill the forward-map class.

## T5 — THE LAW ITSELF: measured deflection must follow α(b), including the divergence

**Claim under test:** the deflection is not just qualitatively "bendy" — it is
`α ≈ 2 r_s/b` in the weak field and diverges as `−ln(b/b_c − 1)` approaching `b_c`
(library 02 §2). A plate has a finite maximum bend; the real law does not.
**Setup:** ≥10 emitters at logged world positions spanning `b` from `1.01·b_c` to
`~20·b_c`, images captured in one frame.
**Measure:** invert each (source position, image position) pair to a measured `α(b)`;
compare against `tools/bc_validate.cpp`'s integrator, which reproduces `b_c` to 8.2e-15 on
this machine and is the local ground truth.
**PASS:** relative error < 1% for `b > 2·b_c`; and `α` measured at `b/b_c = 1.10, 1.05,
1.01` strictly increasing with spacing consistent with the log law (each step DOWN in
`b/b_c − 1` by half adds ≈ ln 2 ≈ 0.69 rad).
**FAIL:** > 5% anywhere in range, or `α` PLATEAUS as `b → b_c` — **a bounded bend near
`b_c` is the plate signature in one number.**
**Who fails / who fakes:** any warp tuned by eye fails the numbers; a wrong-metric
integrator (e.g. the (1/2)-coefficient error that has no photon sphere at all, 02's one
card) fails the divergence spacing while passing the weak field. This is the test that
catches "right features, wrong spacetime."

---

## THE KILL TABLE — which class dies on which test

| Architecture class | T1 | T2 parity | T3 closure | T4 resurrection | T5 law |
|---|---|---|---|---|---|
| Current tree (no BH renderer) | n/a | **FAIL** (no 2nd image) | **FAIL** | **FAIL** | **FAIL** |
| Post-render image warp ("the plate") | n/a | **FAIL** | **FAIL** | **FAIL** | FAIL near `b_c` |
| Forward per-sprite, k coded roots (the deleted lens) | n/a | passes (faked) | **FAIL** | passes (faked) | passes if LUT-driven |
| Fog march on real backward geodesics (deleted) | n/a | passes | passes | passes | passes |
| F1 geodesic-termination design | gate | must pass | must pass | must pass | must pass |

**Scope, stated for P4:** T2–T5 discriminate TRANSPORT honesty only. The deleted fog march
passes all four — its defect was what it GATHERED, not how it bent (§U2). No frame-level
observable in this set enforces the no-fog ban; that ban is enforced by the termination
architecture and his standing order. If P4 wants an emission-honesty observable too, it is
a different family (shear/knot structure vs. featureless blob — NASA's axis, library 04
§2.3) and belongs to F3's lane more than F1's.

**Order of operations when the prototype exists:** T1 first (calibration; cheapest, fails
earliest), then T4 (single frame, binary), then T2, then T3 (needs an alignment pass),
then T5 (needs the multi-emitter inversion). A T5 failure with T1–T4 passing means the
LUT, not the architecture.

---
**Last Updated:** 2026-08-31 17:08:54 — first cut, drafted for BRAIN's P4 on his order.
FABLE owns this file.
