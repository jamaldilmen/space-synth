# THE VENUE IS A ROOM, NOT A WALL — 2026-08-23 12:25:30

> **His message:** *"the projection is gonna be 3 walls in a room, 2 at 4m x 15m and one / front
> that's a bit smaller let's say 10 m … it's a fucking like house in square meters lol … bro said
> as long as it's at least 4k we good and that i need to think in three slices."*
> **6 days out (2026-08-30).** This supersedes the single 10×4 m / 2.5:1 assumption every board row was
> written against.
>
> 🚨 **THIS DOC WAS BUILT ON HIS ESTIMATE AND THE ESTIMATE WAS WRONG. CORRECTED 2026-08-30 23:49:52.**
> He walked the venue 2026-08-24 and a Polycam scan (256,532 verts) confirmed it independently:
> **the walls are 3.50 m, not 4**, and the sides are the WIDE pair. Until this edit every number in
> §1 below was the superseded guess — **area was overstated 15.7%, height 14.3%** — while the board
> pointed here as "the working" for the show. Fixed against
> `memory/space_synth_three_wall_room_2026-08-23.md`.

---

## 1. THE GEOMETRY

**✅ MEASURED — he walked it 2026-08-24, Polycam scan confirms (floor plane y −1.50, wall tops y +2.00):**

| surface | size | aspect | area | pixels (venue tech, 2026-08-29 01:20) | px/m |
|---|---|---|---|---|---|
| side wall ×2 | **14.75 × 3.50 m** | **4.214:1** | 51.6 m² each | **7152 × 1680** each | **485** |
| front wall | **10.01 × 3.50 m** | **2.857:1** | 35.0 m² | **5340 × 1680** | **533** |
| **total** | unwrapped **39.5 × 3.50 m** | **11.286:1** | **138.25 m²** | **19,644 × 1680** | — |

⛔ ~~side ×2 15 × 4 m / front 10 × 4 m / unwrapped 40 × 4 m = 160 m², 10:1~~ — **his pre-walk estimate,
superseded 2026-08-24.** Kept struck through, not deleted, because board rows written before that date
were reasoned against it.

⭐ **THE SIDES ARE THE WIDE WALLS (14.75 m), THE FRONT IS THE NARROW ONE (10.01 m).** His original
message says it — *"2 at … 15 m and one / front that's a bit smaller … 10 m"*. `BOARD.md` §W9 had this
**backwards** until 2026-08-30 23:49:52; see the correction there.

📐 **Pixel density is very nearly uniform: 485 px/m on the sides vs 533 on the front, a 10% spread.**
The sides carry 34% more pixels because they are 47% wider — pixel budget IS roughly proportional to
physical width, within 10%. ⚠️ Their two open questions, unanswered: **60 fps?** and **external SSD?**

🧍 **THE ROOM HAS PEOPLE IN IT.** A packed standing crowd kills the bottom **1.0 m**, leaving 2.5 m —
71% of height. Usable front 4.000:1, usable side 5.900:1. 🎯 **The focus band is the top half of the
front wall, 10 × 1.75 m, and it is only 12.66% of the room's surface.** Anything that must be READ
goes there, and vertical framing must bias UP. The other 87.5% is peripheral vision by construction.

Room is therefore ~**10 m wide × 15 m deep × 3.50 m high**, audience **inside**. He is right about the
square metres: 138 m² of projected surface is a family house's floor area.

⚠️ **Every "2.5:1" on the board is now only the FRONT wall.** The pinned 3840×1536 we tested today is
the front slice, not the show.

---

## 2. 🚨 THE ONE STRUCTURAL FACT — ONE CAMERA CANNOT RENDER THIS

✅ **COMPUTED 2026-08-31 00:47:15, not estimated: 291.67°** (`tools/frustum_validate.cpp` test 6, checked against a 360° closure). Front wall **68.33°**, each side **111.67°**, the beamer-less back wall **68.33°**. ⛔ The **~270°** this line carried was a guess and it UNDERSTATED the problem by 22°.

Three walls of a rectangular room wrap **291.67°** around a viewer standing inside (⛔ this line said
"roughly 270°" until 2026-08-31 16:45:00 — two lines below the correction that replaced it). A single flat
perspective projection **cannot** cover that, and this is not a quality argument — it is arithmetic. A
flat image plane needs width ∝ tan(fov/2):

| coverage | required width ∝ |
|---|---|
| 120° | 1.73 |
| 150° | 3.73 |
| 170° | 11.43 |
| 179° | 114.59 |
| 180° | **∞** |

So **rendering one wide 10:1 image and cutting it into three is wrong.** It would look acceptable in
the middle of the front wall and smear catastrophically toward the corners, because a single frustum
stretched that wide puts enormous angular magnification at its edges.

**The correct construction is what CAVEs, planetariums and Disney do: ONE camera POSITION, THREE
OFF-AXIS FRUSTUMS.** Each wall is a rectangle in world space; for each you build an asymmetric
(off-axis) projection matrix from the shared eye point to that rectangle's four corners. The three
images then agree at the corners with no seam and no distortion, because each is the true perspective
of that physical surface from the viewer's eye.

⭐ This is also exactly what his *"feel of driving a little space ship through our universe"* needs —
the room becomes the cockpit. It only reads that way if the frustums are geometrically honest.

---

## 3. PIXEL DENSITY — THE QUESTION FOR THE TECH TOMORROW

*"at least 4k"* is ambiguous and the difference is a factor of 3.

| reading | density | verdict |
|---|---|---|
| **4K per wall** (3840 on the long side) | side **256 px/m** (0.39 mm/px) · front **384 px/m** (0.26 mm/px) | fine |
| **4K total** across all 40 m | **96 px/m** (1.04 mm/px) | ⛔ visibly chunky at any sane viewing distance |

**Ask: is it 4K per projector/wall, or 4K total?** Also ask how many projectors per wall, whether they
edge-blend, and what the actual native panel resolution of each projector is.

---

## 4. RENDER BUDGET

At 4K per wall:

| | resolution | pixels |
|---|---|---|
| side ×2 | 3840 × 1024 | 3.93 MP each |
| front | 3840 × 1536 | 5.90 MP |
| **total** | | **13.8 MP/frame** |

⛔ **SUPERSEDED 2026-08-31 00:53:55 — THAT WAS A 4K-PER-WALL GUESS, THE VENUE SPEC IS BIGGER.** Actual: front 5340×1680 = **8.97 MP** + sides 7152×1680 = **12.02 MP each** ⇒ **33.00 MP/frame** (== 19,644×1680 exactly). That is **5.56× the fill** of his 5.94 MP panel, and **2.39× MORE than this 13.8 MP plan assumed.** The line below is kept as the superseded estimate.

~~That is **2.33× the fill** of the 5.9 MP he ran today~~ — and today's measurement was *"es läuft halt
1 zu 1 so wie vorher"*, i.e. **no measurable cost at 2.5× the previous fill**. So fill rate is
probably not the wall.

🚨 **The real cost is not fill, it is GEOMETRY.** Three frustums means the 10 M particle vertex shader
runs **three times per frame — 30 M invocations**. `particle_vertex` is the most expensive shader in
the app. Nothing on the board has ever been measured under that load.

**Mitigations that already exist as board rows, and which this promotes in priority:**
- **Per-wall frustum culling** — each wall sees maybe a third of the field, so most particles should
  be rejected early per view.
- **G12 index compaction** — build the live list once, dispatch three views over it.
- ⭐ The **corpse discard at `render.metal:839`** already fires 71 lines in, so dead matter is
  already cheap. That work is done.

---

## 5. WHAT THIS CHANGES ON THE BOARD

- **S0 / the pin** — 3840×1536 is the FRONT slice only. We need a three-slice pin.
- **Syphon** — currently ONE server named "Main" (`renderer.mm:418`). Three walls need **three feeds**
  (or one wide feed the media server splits — ask the tech which they want; most media servers prefer
  separate inputs per projector).
- **Star size** — it is in DEVICE PIXELS and never normalised to the drawable. With three different
  slice resolutions, **the same star will be a different physical size on the side walls than on the
  front wall** unless this is fixed. This turns the star-size row from a look problem into a
  **correctness** problem for the show.
- **Camera rides (R1)** — the ride is now a path for ONE eye point, with three frustums hanging off it.
  That is simpler, not harder: still one camera to author.

---

## 6. OPEN QUESTIONS FOR HIM / THE TECH

1. 4K **per wall** or 4K **total**? (§3 — factor of 3)
2. Are the two 15 m walls opposite each other (a corridor) or adjacent? Assumed opposite, front closing one end.
3. Where does the audience stand — is there one design eye point, or is it a walk-through?
4. Three separate video feeds, or one wide feed the media server slices?
5. Projector native resolution and edge-blend overlap, if any.
