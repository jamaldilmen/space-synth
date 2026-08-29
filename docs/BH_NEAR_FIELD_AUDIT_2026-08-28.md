# THE NEAR FIELD IS DECIDED BY GRID ARITHMETIC, NOT GRAVITY
**2026-08-28 14:22:07** · audit only, **no code changed, nothing built** · BH window

> His brief: *"WE NEED TO GET THE PHYSICS CORRECT our black hole is still a toilet
> drain. stuff behaves differently near a blackhole i want this executed just as
> well as kill the tube."*

---

## 0. THE ONE-LINE ANSWER

**Nothing behaves differently near the hole because there is no near field.**
Every characteristic radius of the black hole is smaller than the length over
which gravity is smoothed. The hole is one sixth of one grid cell.

| quantity | sim | in units of r_h |
|---|---|---|
| **r_h (drawn, measured today)** | **0.1717** | 1.00 |
| photon sphere, 1.5 r_s | 0.2576 | 1.5 |
| ISCO, 3 r_s | 0.5151 | 3.0 |
| **gravity softening ε (= coarse cellSize)** | **1.0000** | **5.82** |
| **capture clamp (1.4 × cellSize)** | **1.4000** | **8.15** |

The horizon, the photon sphere and the ISCO **all fit inside one softening
length.** There is no orbit to decay, no plunge, no shear. Matter drifts in a
flat potential until it crosses a fixed 1.4-sim radius and is deleted.
**That is the toilet drain, stated as a number.**

---

## 1. INVENTORY — physics decided by a grid constant

Sorted by how much it damages the near field. `src/render/particles.metal`
unless noted.

### 🔴 N1 — Gravity is softened at the CELL scale · `:1803`
```
float cellSoftFloor = 1.0f * su.cellSize * su.cellSize;   // ε² ≈ cell²
```
ε = 1.0 sim = **5.8 r_h**. Inside that radius the 1/r² is flattened to nothing.
**Should be keyed to:** the hole's own scale (r_s of the seed mass), not the mesh.
**Deletable?** No — some softening is required. But it must not be a *grid*
constant. ⭐ The code already says so, at `:1797-1800`: *"the true limiter to real
geometric formation is grid RESOLUTION — cellSize 1.0 (±64 grid) cannot resolve
r_s≈0.04 sim; that needs near-core mesh refinement (AMR), an architectural
change, not a constant."* **It was diagnosed and then not fixed.**

### 🔴 N2 — The AMR fine grid, which exists to fix N1, HAS NO MASS IN IT
The nested patch (bit21, ±4 sim, fine cell 0.0625 = **0.36 r_h** — adequate)
replaces coarse gravity inside r < 3. It would solve N1. Live `[AMR]` says it is
not doing so:
```
finePhi  r0=-0.2491  r.25=-0.2425  r.5=-0.2357  r1=-0.2225      M<Rfine=8.164
coarsePhi r0=-0.2306                            r1=-0.2180
```
**Φ(0.25)/Φ(1) = 1.09. A point mass gives 4.00.** The well is FLAT — that ratio is
independent of units, so it cannot be a units error. And the fine box reports
**8.16 M_sun** inside it.

🚨 **Two instruments in the SAME frame disagree by four orders of magnitude
about the mass at the origin:** `[AMR] M<Rfine = 8.16` (r < 2) against `[GRAV]
Menc = 158,483` (r < 0.5). M(<2) cannot be smaller than M(<0.5). **One of them is
wrong and it must be settled before anything is tuned.**
Related: `renderer.mm:3286` feeds the fine grid's boundary monopole from `m20`
= M(< **2**) while `kAmrFineExtent` is **4.0** (`renderer.mm:132`) — the comment on
that line still says "±2 sim = kAmrFineExtent". Stale pair, and it is the BC of
the patch that is supposed to carry the near field.

### 🔴 N3 — The hole's reach is a grid constant · `:1429-1430`
```
float reach = 1.4f * su.cellSize;
rt2 = min(rt2, reach * reach);
```
The tidal radius is computed honestly from mass and relative velocity — and then
discarded. **A 100,000 M_sun hole and a 1,000 M_sun hole have the same reach.**
Capture is therefore a fixed geometric sphere: everything inside 1.4 sim is
taken, nothing outside it is touched. **This is the drain, mechanically.**
**Should be keyed to:** the tidal/capture radius already computed one line above.
**Deletable?** ⭐ **Yes — delete the clamp.** It exists to bound the neighbour
scan, and the scan bound is a separate concern from the physical radius.

### 🟠 N4 — One seed per cell, last writer wins · `:3812`
```
cellSeedMap[cell] = tid + 1u;    // plain write, no atomic, no contest
```
Both capture (`:1382`) and merge (`:1541`) read only this map. Two seeds in one
1.0-sim cell ⇒ one is **invisible**, chosen by a race. Seeds are quantised to an
axis-aligned lattice for every interaction that matters.
**Deletable?** Not directly; needs a per-cell list or an ordered reduction.

### 🟠 N5 — The domain is a CUBE, and the field is outside it · `:1373-1374`, `:1530-1531`, `:1786-1788`
`fabs(px) < su.halfExtent && fabs(py) < … && fabs(pz) < …` is a **per-axis**
test, so the domain is a cube of half-side 64, not a sphere of radius 64. With
`maxR = 100` live, matter sits outside the faces but inside the corners
(64√3 = 110.9). Self-gravity, capture, merge and dynamical friction all switch
off at that boundary — **for some directions and not others.**

### 🟡 N6 — Density is a cell average · `:2039`
`mass / max(cellSize³, 1e-6)`. At cellSize 1.0 the density that feeds the SPH /
dynamical-friction terms is averaged over 197 horizon volumes.

### 🟡 N7 — The era-frozen extents (the class CAMERA and I converged on)
Four known, all calibrated when the field sat at meanR ≈ 4 and never re-derived:
`RADIAL_MAX_R = 5.0` (`:405`), the march step rule (deleted with the march),
`halfExtent = 64` vs `maxR = 100` (`renderer.mm:2065`), `kAmrFineExtent = 4.0`
(`renderer.mm:132`). **Rule for the sweep: any constant whose comment cites a
radius or measurement from the meanR≈4 period is suspect until re-derived.**

---

## 2. WHAT I WOULD DO, IN ORDER — one change each, his verdict between

1. **Settle N2 first — it is a contradiction, not a tuning question.** If the
   fine patch really is empty, N1 has no fix and everything below is wasted. If
   it is an instrument bug, the near field may already be better than it looks.
   **Cost: one probe line, no physics touched.**
2. **Delete the N3 clamp.** Smallest possible diff, and it is the drain itself.
   Let the computed tidal radius stand; bound the *scan* separately.
3. **Re-key N1's softening** to the hole's r_s rather than the mesh — only once
   N2 says whether the fine patch can carry it.
4. N4, N5, N6 after, individually.

⛔ **Not proposed: tuning any of these constants.** The kill-the-tube standard is
to remove what is fake, and N3 is fake in the same way the lens was — an honest
quantity computed and then thrown away for a cosmetic one.

---

## 3. WHAT MOVES WHEN IT WORKS — so his eyes are not the only instrument

Already printing, no new code needed:

| instrument | now | if the near field becomes real |
|---|---|---|
| `[AMR] finePhi r0…r1` | ratio **1.09** (flat) | → **4.0** at r=0.25 vs r=1 (1/r well) |
| `[AMR] M<Rfine` | **8.16 M_sun** | → comparable to `Menc`, or the contradiction is resolved |
| `[CELLPROBE] clump` | **14,827×** | falls — matter stops piling into one cell |
| `[CELLPROBE] maxCell` | **196,523** | falls |
| `[GRAV] meanR` | 13.15 → 28.69, climbing | stops inflating |
| `[HORIZON] DRAWN r_h` | 0.1717, grows only by eating | should grow **faster** once capture is mass-scaled |

⭐ **The N3 test is falsifiable in one run:** with the clamp gone, capture radius
must scale with seed mass. Two runs at different seed masses should show
different reach. Today they cannot.

---

## 4. HONEST LIMITS OF THIS AUDIT

- Every line above is read from source at the quoted `file:line` and every number
  from a live log — but **I have changed nothing and verified nothing by running.**
- The N2 contradiction is the weakest link: I have **not** traced how the fine
  grid is deposited, so I cannot yet say whether `M<Rfine` or `Menc` is the liar.
- r_h = 0.1717 is from my own 233-sample soak; brain's run showed 0.1417. The
  ratios in §0 shift by ~20% between runs. They do not shift by enough to matter.
