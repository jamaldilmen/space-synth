# HOW THE INDUSTRY ACTUALLY RENDERS THIS — 2026-08-31 00:40:19

> **His question, 2026-08-31:** *"syphon is ass. this is not about practical its baut industry
> stadnard. its abut movie poroudciton. pixar and live tv. how do they tackle stuff like this how
> do we render that ? how does stuff liek that actually work where people make money doing that"*

**Every claim below carries a source. Nothing here is inferred.** Researched 2026-08-31 00:40:19.

---

## 0. THE SHORT ANSWER

He named three industries. **They have three different answers and only one of them is ours.**

| industry | what they actually do | applies to us? |
|---|---|---|
| **Pixar / film** | Offline. Buy quality with TIME. | ⛔ **No** — except colour/format discipline |
| **Live TV** | Frames leave the machine on a **broadcast transport**, locked to a shared clock | ✅ **The transport half** |
| **Live events / LED volume** | Render from a **model of the real venue**, one frustum per surface, driven by a **media server** | ✅ **This is us** |

🚨 **THE ONE IDEA WE ARE MISSING, AND IT IS ARCHITECTURAL:**
**Nobody in this business renders a wide image and slices it.** They build a digital replica of the
real room and render **one camera per physical surface**. The slicing, warping, blending and
playback are a **separate machine's job**. Our renderer's job is to answer the question *"what does
the world look like through THIS rectangle?"* — three times.

⭐ **That means the frustum work is OURS and no transport, protocol or product removes it.**
Syphon vs NDI vs SDI is a downstream argument about a cable. It is not this problem.

---

## 1. PIXAR — WHY IT DOES NOT APPLY, AND THE ONE PART THAT DOES

**They are not solving our problem.** *Luca* ran **~50 hours per frame** on an early scene — 576
frames took a collective **20 days** for under half a minute of film. *Toy Story 4* had frames over
**60 hours** each. The farm is **2,000 machines / 24,000 CPU cores**, dispatched by Tractor at 500+
tasks/second. ⛔ **They buy their look with time we do not have.** We have 16 ms.

✅ **What DOES transfer — and it is real, not a consolation prize: their FORMAT and COLOUR discipline.**
RenderMan 27 aligns to the **VFX Reference Platform 2024** — OpenEXR, OpenImageIO, USD — and Pixar
replaced their proprietary texture format **with OpenEXR**. **ACES** colour management is the
industry standard they build against.

⭐ **We already have the beginning of this and did not know it was the industry road:** the colour
work (`stellar-bvr`, the Planck band integral, the spectral LUT) is a physically-derived linear
pipeline. **The missing piece is the OUTPUT half — we have no defined colour space on the way out.**
For a projected show that is not cosmetic: three projectors will not agree without one.
🔴 **NOT a 6-day item. Logged so it stops being invisible.**

---

## 2. LIVE TV — THE TRANSPORT ANSWER

**`SMPTE ST 2110` (2017) is the current standard**, and it replaced SDI. It carries video, audio and
ancillary data as **separate synchronised elementary streams over IP**, timestamped against a common
clock via **PTP (IEEE 1588, adapted for broadcast as SMPTE ST 2059-2)**. SDI is the older
point-to-point baseband route; **NDI is the cheaper IP tier below 2110**.

⭐ **The transferable idea is not the cable, it is the CLOCK.** Broadcast's non-negotiable is that
everything is locked to one reference — genlock, then PTP. **We just spent a whole session proving
our own clock was lying to us in nine places.** That is the same discipline arriving from the other
direction, and it is a good sign we were on the right problem.

🚨 **Relevance to Cologne is real but LIMITED:** if all three walls leave this machine as **ONE
surface**, they are frame-locked by construction and there is nothing to sync. **Sync only becomes a
problem the moment we split across outputs or machines.** That is an argument for one wide output.

---

## 3. LIVE EVENTS — THIS ONE IS US

### 3a. `nDisplay` (Unreal) — our exact problem, already a product
It renders one scene **to a cluster of nodes and displays**, synchronises every instance so they
**render the same frame at the same time**, and **"ensures each display device renders the correct
frustum of the game world."** That sentence is the three-wall problem, named and solved.

### 3b. The venue is a MODEL, not a guess
**disguise Designer** builds *"a digital replica of your production environment."* **OmniCal**
calibrates it against reality: structured-light patterns from the projectors are camera-captured
into a **point cloud of the actual surface**, then meshed to match the creative model.
⭐ **We have already done the hard half of this and did not connect it: the Polycam scan (256,532
verts, walls confirmed 3.50 m).** That scan is not documentation — **it is the input the industry
pipeline runs on.**

### 3c. ICVFX / LED volumes — inner and outer frustum
In-camera VFX uses **off-axis projection** with camera tracking; the **inner frustum** (what the
camera sees) can be rendered **on a separate GPU** from the **outer frustum** (everything else, which
exists for lighting and reflections). ⭐ **The transferable idea: not every surface deserves equal
cost.** Our own room measurement says the readable focus band is **12.66%** of the surface. That is
the same insight — **spend the pixels where they are looked at.**

### 3d. `RenderStream` — the right answer, and ⛔ **IT IS WINDOWS-ONLY**
This is the bridge a custom engine uses to become a render node. **Bidirectional**: the server sends
**camera position, orientation, focal length, sensor size, clipping planes**, frame timing and
sequenceable parameters *into* the renderer; the renderer returns frames. **It is BSD-3-Clause and
explicitly open for custom engines** — official plugins are Unreal, Unity, TouchDesigner, Notch.

🚨 **AND IT IS OUT FOR US, TODAY, AS A FACT NOT AN OPINION:** *"The RenderStream DLL is distributed
as a 64-bit Windows DLL"*, requiring **64-bit Windows 10+** and either a disguise licence or rx-range
hardware. **SPACE SYNTH is a macOS Metal app.** ⛔ Not a 6-day path, and not a path at all without a
Windows box or a port.

⭐ **BUT THE PROTOCOL IS STILL THE BLUEPRINT.** What it proves is the shape of the correct
architecture: **the renderer does not decide what it is looking at — it is TOLD, per frame, per
surface.** We can implement that shape natively without disguise, and if we ever want a real media
server, the renderer is already built the right way round.

---

## 4. WHAT THIS MEANS FOR US — three separable parts

| part | what it is | who owns it | 6 days? |
|---|---|---|---|
| **A. OFF-AXIS FRUSTUMS** | one asymmetric projection per wall from a shared eye point, driven by the measured room | 🚨 **US. Unavoidable. No product removes it.** | ✅ tractable |
| **B. TRANSPORT** | how frames leave the Mac | swap-able: **NDI** or **SDI via Blackmagic DeckLink/UltraStudio** (both macOS) instead of Syphon | ✅ a swap |
| **C. WARP / BLEND / SLICE / PLAYBACK** | matching output to the real surface | 🎪 **THE VENUE.** Their chain is already Resolume | ⚖️ theirs |

⭐ **A is the show. B is a cable. C is not ours.** Syphon being ass is a **B** complaint, and B is the
cheapest of the three to change — but changing it fixes nothing on its own, because **today we cannot
produce three correct images to send down ANY cable.**

## 5. ⛔ WHAT NOT TO DO
- ⛔ **Do not render one wide image and slice it.** Arithmetic, not taste: a flat perspective needs
  image width ∝ tan(fov/2) — 1.73 at 120°, 11.43 at 170°, **infinite at 180°**. Fine mid-front,
  catastrophic at the corners. Nobody in this industry does it.
- ⛔ **Do not adopt disguise/RenderStream for Cologne.** Windows-only, licensed, 6 days.
- ⛔ **Do not chase ST 2110.** It is a facility-infrastructure standard. Wrong scale for one room.
- ⛔ **Do not pre-render.** He PLAYS this instrument live; offline is Pixar's answer to a different question.

## 6. 🔴 OPEN QUESTIONS FOR HIM
1. **A first, or is something else ahead of it?**
2. **Transport: NDI or SDI?** SDI (DeckLink over Thunderbolt) is the genuinely broadcast-grade route
   off a Mac and answers the venue's *"external SSD?"* conversation properly. NDI is faster to reach.
3. **The venue's two questions are still unanswered — 60 fps? external SSD?** 5 days after Cologne minus one.

---

## SOURCES (all fetched 2026-08-31 00:40:19)
- nDisplay / ICVFX — Epic: <https://dev.epicgames.com/documentation/unreal-engine/ndisplay-overview-for-unreal-engine> · <https://dev.epicgames.com/documentation/en-us/unreal-engine/in-camera-vfx-overview-in-unreal-engine>
- disguise cluster rendering + Designer + OmniCal — <https://www.disguise.one/en/insights/blog/seven-reasons-why-cluster-rendering-is-a-game-changer-for-production> · <https://www.disguise.one/en/products/designer> · <https://www.disguise.one/en/solutions/projection-mapping>
- RenderStream (protocol, custom engines, **Windows-only**, BSD-3) — <https://github.com/disguise-one/RenderStream> · <https://www.disguise.one/en/products/renderstream> · <https://help.disguise.one/workflows/renderstream/renderstream-overview>
- SMPTE ST 2110 / PTP / SDI — <https://www.smpte.org/standards/st2110> · <https://www.smpte.org/smpte-st-2110-faq> · <https://onediversified.com/insights/blog/smpte-st-2110>
- Pixar RenderMan / farm / VFX Reference Platform / ACES — <https://renderman.pixar.com/about> · <https://renderman.pixar.com/tractor> · <https://renderman.pixar.com/fundamentals-color-management> · <https://sc24.supercomputing.org/2024/06/hpc-creates-cinematic-magic-pixars-technological-canvas/> · <https://nofilmschool.com/why-pixars-24000-core-supercomputer-still-takes-24-hours-render-each-frame>
- fxguide, virtual production rendering — <https://www.fxguide.com/fxfeatured/disgusing-virtual-production-rendering/>
