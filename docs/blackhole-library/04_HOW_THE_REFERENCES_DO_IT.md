# 04 — HOW NASA AND INTERSTELLAR ACTUALLY DO IT

**Written 2026-08-29 01:48:42.** His question, verbatim: *"also what are we planning on ding
with the visual side of th ebh how does nasa do it ? how did ineterstellar do it ? dont guess
research our references there sltitle room for interpretation"*

**Read only. No code proposed here that needs a build.** Sources are cited per claim; where a
number came from our own tree or our own measurement it says so.

---

## 0. THE ANSWER IN FIVE LINES

1. **Everyone does the same thing: BACKWARD, PER-PIXEL, along real null geodesics.** Interstellar,
   NASA, Luminet in 1979, and every EHT-comparison simulation. Nobody who succeeded went forward
   or per-object.
2. **They differ in exactly three places**, and those three are the only choices we get.
3. **R5 and R6 are not two features. They are one mechanism** — the n=0 and n=1 images of the same
   disk — and any honest backward integrator produces both for free.
4. **The Kerr-caustic defect that killed GARGANTY is a Kerr + infinitely-thin-disk problem.** We are
   a = 0 and our emitters are real particles with finite extent. That specific failure is not
   automatically ours. ⚠️ This does NOT reopen his rejection of the raytracer — FPS was the other
   reason and it stands — but the reasoning needs correcting.
5. **We run THREE DIFFERENT SPINS in one renderer** — kinematics a = 0.5, geometry a = 0,
   Gargantua a = 0.999. See §5.6. That is the biggest single honest gap, and it is not tuning.

---

## 1. INTERSTELLAR — DNGR, mechanism by mechanism

Source: James, von Tunzelmann, Franklin & Thorne, *CQG* **32** (2015) 065001, read from
`/Users/airy/GARGANTY/1502.03808_text.txt` (full extracted text, in our possession).

### 1.1 The ray tracing (§2.1)
- Boyer–Lindquist `(t, r, θ, φ)` on Kerr. At each event a **FIDO** (locally non-rotating fiducial
  observer) with orthonormal basis `{ê_r, ê_θ, ê_φ}`.
- Camera specified by position `(r_c, θ_c, φ_c)`, a unit direction of motion `B` relative to the
  FIDO, and a **speed β relative to the FIDO**. Camera basis is built with `e_y ≡ B`.
- **"We integrate the null geodesic equation to propagate the ray FROM THE CAMERA to the celestial
  sphere."** Backward. Per pixel.
- **Disk case (§2.1 vi):** *"we integrate the null geodesic equation backward from the camera until
  it hits the disk's surface."* The disk is a **termination surface**, not a volume integral.
- (vii) Doppler + gravitational shift computed as **one net frequency shift** along the ray, and the
  corresponding intensity change.

### 1.2 The ray BUNDLE — what DNGR added, and why (§2.2)
Not one ray per pixel: a **circular bundle with a small opening angle**, propagated backward via the
**equation of geodesic deviation** (equivalent to the optical scalar equations). It arrives at the
celestial sphere as an **ellipse** described by three numbers: major axis angle `μ`, and angular
diameters `δ₊`, `δ₋`. The pixel then integrates all light **from within that ellipse**.

⭐ **This is anti-aliasing, and it is the entire reason DNGR looks smooth.** *"Our ray-bundle
techniques were crucial for achieving IMAX-quality smoothness without flickering."* Plus spatial
filtering between beams and **temporal** filtering so motion looks filmed rather than computed.

### 1.3 The disk they actually used (§4.1.1, §4.3.2)
- **An artist's disk, not a solved one.** *"created for Interstellar by Double Negative artists
  rather than created by solving astrophysical equations."*
- Physically thin, marginally optically thick, equatorial, **not accreting**, cooled to a
  **position-independent T = 4500 K blackbody**. Deliberately anemic *"so the humans who travel near
  it will not get fried by X-rays and gamma-rays."*
- Three model types: infinitely thin planar, a 3D voxel model, and a textured close-up variant.

### 1.4 The four effects, isolated (§4.1) — this is the pedagogical core
| Fig | What is on | Result |
|---|---|---|
| 13 | lensing only, paint swatches | **three images** of the disk resolve |
| 14 | lensing only, artist disk | the familiar wrap |
| 15a | spin slowed to a/M = 0.6 | **the movie's geometry** |
| 15b | + colour shift | blue left, red right |
| 15c | + intensity shift `I_ν ∝ ν³` | *"what the disk would truly look like"* |
| 16 | 15a + veiling flare | **the movie's actual disk** |

**Speeds and factors, quoted:** disk material ≈ **0.55c**; blueshift factor ≈ **1.5** left,
redshift ≈ **0.4** right, *"when one combines the Doppler shift with a ~20 percent gravitational
redshift."*

### 1.5 ⭐ THE THREE IMAGES IN FIG 13 — this is R5 and R6, in the paper's own words
- **Upper image:** *"swings around the front of the black hole's shadow and then… swings UP OVER
  the shadow and back down to close on itself… This entire image comes from light rays emitted by
  the disk's TOP FACE"* — rays from the top face **behind** the hole, bent over the top. → **R5.**
- **Lower image:** *"wraps UNDER the black hole's shadow… This entire image comes from light rays
  emitted by the disk's BOTTOM FACE"* — wide part from behind and under; **narrow part from the
  front underside, under the hole, up the back, over the top and down — one full loop.** → **R6.**
- **Third image:** *"barely visible near the shadow's edge… travels around the hole ONCE for the
  visible bottom part, and ONE AND A HALF TIMES for the unresolved top part."* → **R2, n ≥ 1.**

🚨 **So R5, R6 and R2 are one continuous family indexed by winding number.** They are not three
features to be built three times. Anything that integrates rays properly past the photon sphere
gets all three; anything that cannot, gets none of them.

### 1.6 Lens flare — the deliberate un-physics (§4.2, §4.3.1)
**Measured, not invented.** They HDR-photograph a point source through the actual 35 mm and 65 mm
IMAX lenses to get the point spread function, then **convolve the image with it**. Nolan asked for
it so CGI would cut against real photography.

### 1.7 The two decisions that make the movie WRONG on purpose
- **Spin slowed a/M = 0.999 → 0.6.** The flattened left shadow edge and the multiple images beside
  it were *"too confusing for a mass audience."*
- **Frequency shifts turned OFF.** The truthful frame (15c) is *"exceedingly lopsided, with the
  hole's shadow barely discernible"* — *"obviously unacceptable"*. The film ships **15a + flare**.

⭐ **CONSEQUENCE, already in `02_LIGHT` and worth repeating: if we ever match the movie exactly, we
did it wrong.** The movie is Fig 15a. The truth is Fig 15c.

---

## 2. NASA — Schnittman & Powell, mechanism by mechanism

### 2.1 Method
**The same method.** *"a technique called ray tracing… a virtual camera that tracked every photon
back to its source."* Backward, per-pixel, general-relativistic. Scale: **over 500 billion photons**
for the disk work; the 2024 plunge produced **10 TB** in **5 days on 0.3% of Discover's 129,000
processors**; the binary-hole visualization used 2% of Discover for about a day.

**Difference from DNGR: single rays, brute-forced at supercomputer scale, rather than ray bundles.**
NASA buys its smoothness with photon count; DNGR bought it with beam footprints and filtering
because a render farm could not brute-force IMAX.

### 2.2 What NASA CHOOSES to render — and this is where they differ from Interstellar most
- **A thin, hot accretion disk**, with the geometry distorted by lensing.
- ⭐ **Bright KNOTS that form and dissipate**, from magnetic fields winding through churning gas —
  then **sheared into light and dark lanes** because the inner disk orbits near c and the outer disk
  much slower. **Interstellar has no equivalent: its disk is a static artist's texture at uniform
  4500 K.**
- **Photon rings**, explicitly: *"structures called photon rings that form closer to the black hole
  from light that has orbited it one or more times."* NASA renders R2 as a named feature.
- **Doppler beaming, left/right, kept ON.** *"Gas on the left side appears brighter than gas on the
  right, because light waves emitted by quickly approaching gas pile up."*
- The 2024 ride: two shots — a near-miss that slingshots out (6-hour round trip, traveller returns
  36 minutes younger) and a plunge (12.8 s from horizon to spaghettification). ~3 h fall, **almost
  two complete 30-minute orbits** on the way in. Camera is **released on a geodesic, not keyframed.**

### 2.3 ⭐ THE ONE PLACE NASA IS CLOSER TO US THAN INTERSTELLAR IS
NASA's disk is **structured, moving, sheared and lumpy**. Ours is made of **real particles with real
velocities and real shear**. Interstellar's is a painted texture. **On the one axis where we have a
native advantage, NASA is the reference and Interstellar is not.**

---

## 3. EHT — what a MEASUREMENT says, and one conflation to stop making

Not a render. VLBI interferometry.

- **M87\* (2019):** an asymmetric bright emission ring, **42 ± 3 μas** across, with a central
  brightness depression at a **flux ratio ~10:1**.
- **The asymmetry is Doppler beaming**, and it is **weak because M87\* is viewed at ~17° inclination**
  — a near-face-on view suppresses beaming.
- 🚨 **THE CONFLATION TO STOP MAKING: the bright EHT ring is NOT the photon ring.** It is lensed
  emission from near the horizon, shaped into a crescent *near* the photon ring. The true photon ring
  is a thin feature made of an infinite sequence of self-similar subrings indexed by orbit number,
  exponentially narrower and fainter with n. **EHT does not resolve it**; detecting the n = 1 subring
  is the stated goal of proposed successors (ngEHT, BHEX).

⚠️ **This lands directly on R2.** Our reference JPEG labels a thin bright ring "photon ring", which
is the theorist's feature. The EHT photograph's bright ring is the astrophysicist's emission ring.
**Both are in our reference set and they are not the same object.** Anything we build should be clear
about which one it is producing.

- ⭐ **And it independently confirms our own measurement:** face-on suppresses beaming. We measured
  `vLos` **exactly zero** at our default camera on 2026-08-27. M87\* at 17° is the same physics.
  **His default view is the one view where R4 cannot appear.**

---

## 4. WHERE THEY AGREE — this is the spec, not a menu

He said *"there's little room for interpretation."* He is right, and here is the agreed set:

| # | Agreed by | The claim |
|---|---|---|
| A1 | DNGR, NASA, Luminet, EHT-sims | **Backward, per-pixel, along null geodesics.** No exceptions in the entire literature. |
| A2 | DNGR §2.1(vi), NASA | **The ray TERMINATES on the emitter.** A surface hit, not a fog integral. |
| A3 | DNGR §4.1.1, NASA, our optics panel | **The disk wraps over AND under the shadow**, from the top and bottom faces respectively. |
| A4 | DNGR Fig 13, NASA, EHT theory | **Higher-order images exist and stack on the shadow edge**, thinner and fainter with each winding. |
| A5 | DNGR §2.1(vii), NASA, EHT | **ONE net frequency shift `g`**, Doppler and gravitational combined, never applied twice. |
| A6 | DNGR §4.1.2, NASA, EHT | **`I_ν ∝ ν³`** — beaming is a brightness effect, not a tint. |
| A7 | DNGR, our `b_c` validator | **The shadow is the capture cross-section**, `b_c = 3√3 M = 2.598 r_s`, ~2.6× the horizon. |
| A8 | DNGR ray bundles, NASA 500 bn photons | **The caustic structure MUST be filtered or oversampled.** Both spent their budget here. Neither shipped one ray per pixel unfiltered. |

**A8 is the one we have never respected, and it is what produced his "pebbles".**

### Where they DISAGREE — our only real choices
| Choice | Interstellar | NASA | Ours |
|---|---|---|---|
| **Spin a/M** | 0.999 truth, **0.6 shipped** | varies, often high | ⚠️ **BOTH 0.5 AND 0 AT ONCE** — see §5.6 |
| **Doppler asymmetry** | **OFF** (audience) | **ON** | undecided; invisible face-on regardless |
| **Disk structure** | static artist texture, uniform 4500 K | **turbulent, knotty, sheared** | **real particles** — closer to NASA |
| **Anti-aliasing** | ray bundles + spatial + temporal filter | brute force, 500 bn photons | **neither, and that is the gap** |
| **Camera flare** | measured PSF convolution | none | ours is a separate look decision |

---

## 5. WHAT WE CAN AND CANNOT DO — honestly

### 5.1 The two standing constraints (his, not mine)
- ⛔ **The Kerr geodesic raytracer is REJECTED as the engine** — FPS, plus the polar caustic.
- ⛔ **No grid fog integral.** His direction: **per-pixel backward geodesics that TERMINATE ON THE
  REAL PARTICLES.** Both BH renderers were deleted 2026-08-27, 852 lines, committed. **Nothing here
  proposes rebuilding either.**

### 5.2 ⚠️ A CORRECTION TO THE REASONING BEHIND THE FIRST CONSTRAINT
Read from his own working note
(`~/Downloads/almost got the interstellar look right but not yet.md`), the diagnosis of the
"pebbles" was: *"Real Kerr caustic structure + infinitely thin disk"* combined with *"one geodesic
per pixel with no ray-bundle filtering"* — families of nearly-trapped geodesics that hit a
zero-thickness disk many times, collapsing into a 1-px over-bright line. The note is explicit that
**tweaking the metric was the wrong place** and that the 3D cone kill *"cuts a real hole in the disk."*

**Both ingredients of that failure are things we do not have:**
- **Kerr.** We are a = 0. Frame dragging and the near-trapped Kerr families are absent.
- **An infinitely thin analytic disk.** Our emitters are **particles with finite extent**, which is a
  physical footprint — the same thing a ray bundle synthesises artificially.

🚨 **This does NOT reopen his rejection.** FPS is an independent and sufficient reason, and it stands.
But "the raytracer is impossible because of polar caustics" is not a correct sentence, and if it is
carried forward as one it will block the right architecture for the wrong reason. **The honest
sentence is: the caustic defect was Kerr-specific and sampling-specific, and A8 says nobody ships
without solving sampling.**

### 5.3 What produces each missing feature
`README.md` records that **nothing** currently produces R2, R5 or R6. Which reference explains each:

| Row | Explained by | What it actually requires |
|---|---|---|
| **R2 photon ring** | DNGR Fig 13 third image; NASA names it; EHT/ngEHT subring theory | Rays that wind **≥ 1 full orbit**. Resolution-bound: n = 1 needs the shadow a few hundred px wide (fine at 4K); **n = 2 needs ~535× finer and is unreachable, ever.** Be explicit that we are producing **n = 1 only**. |
| **R5 far-side arch** | DNGR §4.1.1 upper image, verbatim | Rays from the **top face behind the hole**, deflected over the top. Falls out of any correct backward integration. |
| **R6 underside arc** | DNGR §4.1.1 lower image, verbatim | Rays from the **bottom face**, travelling **> 180°** so paths cross → **left-right parity flip**. |

⭐ **R5 and R6 are the same integration.** Build the integrator and both appear, or neither does.
**Parity is the free honesty test** (`02_LIGHT` §3): a 2D image-space warp is orientation-preserving
by construction, so a genuinely mirrored second image proves real optics.

### 5.4 What we CANNOT have, and should stop implying we can
- ⛔ **The D-shaped flat-edged shadow.** That is Bardeen frame dragging at high a/M. **Our shadow
  geometry is a = 0, so it is exactly circular.** Gargantua's most recognisable silhouette detail is
  unreachable without real Kerr geometry — a physics change, not a render change. **He named
  "gargantua" as the target; this is the one part of it our a = 0 geometry forbids.**
- ⛔ **n ≥ 2 rings.** Spacing `e^(−2π) ≈ 1/535`. Not a budget problem, a pixel problem.
- ⛔ **Beaming at his default camera.** Measured zero. Any R4 verdict needs an edge-on A/B first.
- ⚠️ **Colour is not the target.** The reference JPEG is orange because NASA chose orange. Our colour
  law is a separate live defect (G16). Do not chase the JPEG.

### 5.5 The honest open problem, named
Every reference terminates rays on an **analytic surface** — a disk equation, or the celestial
sphere. His direction terminates them on **real particles**. **Nobody in the reference set has solved
ray-vs-particle-cloud intersection**, because nobody else had the particles. That is the actual
engineering question, it is unsolved here, and it should not be described as though a reference
answers it. What the references DO settle is everything around it: backward, per-pixel, terminate on
the emitter, one `g`, `I_ν ∝ ν³`, and **filter or oversample (A8)**.

⚠️ **Dependencies, stated rather than assumed** (the physics is the BH window's, not this one's):
any such renderer needs particle positions and velocities on the GPU — which we already have — and
does **not** depend on time-warp invariance or the merger work landing first.

---

### 5.6 🚨 THREE DIFFERENT SPINS IN ONE RENDERER — verified in our own tree 2026-08-29 02:04:11

⚠️ **CORRECTING MY OWN FIRST PASS.** An earlier draft of this file said *"no Kerr `a` anywhere in
`render.metal`."* **That was wrong — a grep miss, not a reasoning error.** I searched for names I
guessed (`spinA`, `kerrA`, `bhSpin`) instead of for the concept. There is a Kerr spin, and finding
it makes the point sharper rather than weaker:

| | value | site | what it drives |
|---|---|---|---|
| **KINEMATICS** | **a = 0.5** | `render.metal:308` `constant float KERR_A = 0.5f`, used at `:1409` | `Ω(r) = 1/(r^1.5 + a)` — the orbital speed law that feeds **Doppler** and the disk streaks |
| **GEOMETRY** | **a = 0** | `render.metal:991` hardcodes `2.5980762f`; `:337` `kLensBc` the same | the photon-capture cull. **`3√3/2 = 2.598076211353` is the SCHWARZSCHILD value** — verified: `python3 -c "3*sqrt(3)/2"` → 2.598076211353316 |
| **TARGET** | **a = 0.999** | Gargantua, DNGR §4 | what he asked for |

**So the disk orbits as if the hole spins at a = 0.5, while the shadow is sized as if it does not
spin at all.** At a = 0.5 the true capture parameter is not 3√3/2 and is not even circular — it is
the Bardeen shape, offset and flattened on the co-rotating side.

⭐ **This is a genuinely mixed model, and it is worth stating plainly because it decides what a
verdict on R1 or R4 can mean.** It is not necessarily wrong to ship — `KERR_A = 0.5` may simply be
a speed-law tuning knob wearing a physics name — but **nobody should read the shadow as evidence
about spin, or the Doppler asymmetry as evidence about geometry, while the two disagree.**
🚨 And per [[space_synth_comment_is_not_a_mechanism]]: `KERR_A`'s own comment calls it "BH spin",
which is exactly the kind of name-as-mechanism claim that has bitten this project 9 times.

### 5.7 Two live-code notes found while verifying the above

- **The Schwarzschild deflection LUT is kept but UNREAD.** `README.md` records it as surviving the
  2026-08-27 deletions, which is true — but `lensAlphaSample` (`render.metal:340`) has **zero
  callers in shader code**; the only other hits are three comments in `renderer.mm` (`:908`, `:924`,
  `:930`) ⛔ *(corrected 2026-08-31 16:52:00 — they were cited at `:854/:870/:876`; the file has since
  shifted. 14th sighting of a decayed anchor.)*. "Kept" should not be read as "in use". It is ready for a future integrator, not feeding
  the current picture.
- **A stale comment sits on the live capture cull.** `render.metal:994` still says *"With the lens
  on, the lens + membrane are the ONLY transport — no straight-line culls."* **The lens was deleted
  on 2026-08-27**, and the straight-line cull immediately below it is now the live path. The code is
  correct; the comment describes a world that no longer exists.

---

## 6. SOURCES

**Ours, on disk:**
- `/Users/airy/GARGANTY/1502.03808v2.pdf` + `1502.03808_text.txt` — James, von Tunzelmann, Franklin
  & Thorne, *CQG* **32** (2015) 065001. Read directly; all §2/§4 quotes above are from it.
- `~/Downloads/almost got the interstellar look right but not yet.md` — his own Kerr Metal
  raytracer and the polar-caustic diagnosis (§5.2).
- `docs/blackhole-library/02_LIGHT_how_it_travels_near_one.md`, `03_THE_REFERENCE_FRAMES.md`
- `docs/reference/BH_REFERENCE.md` — rows R1–R6
- `docs/blackhole_render_research_notes.md`, `docs/RESEARCH_2026-07-24_interstellar_dngr.md`
- `tools/bc_validate.cpp` — our own `b_c` = 2.598076211353 r_s, rel err 8.2e-15

**Fetched 2026-08-29:**
- NASA/Goddard accretion disk visualization — https://www.nasa.gov/image-article/accretion-disk-of-black-hole-glows-new-simulation/
- NASA SVS, black hole with accretion disk — https://svs.gsfc.nasa.gov/14619/
- NASA, binary black holes — https://www.nasa.gov/universe/new-nasa-visualization-probes-the-light-bending-dance-of-binary-black-holes/
- NASA SVS, "Plunge: Behind the Scenes" — https://svs.gsfc.nasa.gov/14818
- NASA@SC24 — https://www.nas.nasa.gov/SC24/research/project19.php
- EHT M87\* I. The Shadow — https://arxiv.org/abs/1906.11238
- EHT M87\* V. Physical Origin of the Asymmetric Ring — https://iopscience.iop.org/article/10.3847/2041-8213/ab0f43
- EHT, brightness asymmetry as a probe of inclination — https://eventhorizontelescope.org/publications/brightness-asymmetry-black-hole-images-probe-observer-inclination
- Johnson et al., universal interferometric signatures of the photon ring — https://www.science.org/doi/10.1126/sciadv.aaz1310
- Black Hole Explorer: photon ring science — https://arxiv.org/pdf/2406.09498

**Last Updated:** 2026-08-29 01:48:42
