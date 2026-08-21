# 🎪 SHOW — 2026-09-05, COLOGNE, OPENING EVENT

**Written:** 2026-08-21 · **Days out: 15** (2026-08-21 → 2026-09-05)

| Fact | Value | Source |
|---|---|---|
| Date | 2026-09-05 | his message 2026-08-21 |
| City / slot | Cologne, opening event | his message |
| Screen | ~40 m², **10 × 4 m** | his message |
| Projection | **6 beamers** | his message |
| **Aspect** | **2.5 : 1** | derived from 10 × 4 |
| Output path | SpaceSynth → Syphon "Main" → media server → 6 outputs | `renderer.mm:418`, `:4406` |

⚠️ **This replaces Berlin New Media Week as the target.** The board still names Berlin.

🚩 **SCOPE — his words 2026-08-21:** *"the duration of the set is not you concern. i will have live moments in my ret and moment where ill laly pre rendererd stuff ill mix it. arrangement and all associated to that is my cocnern"*
**He mixes LIVE and PRE-RENDERED material.** Set length, arrangement, and what plays when are **HIS**.
Mine is only: what the engine can output, at what aspect, at what scale, and whether a recording of it is correct.

---

## 🆕 SHOW-DRIVEN ITEMS — not on TODO.md, found 2026-08-21

| # | What | Verified | Why it is a show risk |
|---|---|---|---|
| **S1** | **The Syphon feed has NO independent resolution — it is allocated at the window's drawable size** and published as `imageRegion(0,0,width,height)`. So the feed's aspect ratio IS the window's aspect ratio. | `renderer.mm:4515-4523` (same `hdrDesc` as the screen), `:4409` | A 16:9 or 16:10 window into a **2.5:1** wall = letterbox or crop, decided by the media server, not by us. Needs a 2.5:1 output mode |
| **S2** | **Star size is in DEVICE PIXELS and is never normalised to the drawable.** `out.pointSize = drawn`, clamped 1…150 px. | `render.metal:1558` | At wall resolution the stars get relatively SMALLER than on his laptop. What he tunes at home is not what the wall shows. Compounds **G2** |
| **S3** | **The lens is gated OFF above amplitude 0.02** (`bhLensActive = totalAmplitude < 0.02f`). | `renderer.mm:1662` | Stated as a fact, not as advice. ⛔ **Arrangement is HIS, not mine** |
| **S4** | **The BH fuse is a 3–16 min stochastic wait.** | BOARD_BLACKHOLE §N2 / A5 | Same. A fact to arrange around |
| **S5** | **6-beamer edge blend is the media server's job, not ours.** | — | Not code |
| **S6** | 🚨 **THERE IS NO CAPTURE PATH IN OUR CODE.** `grep -rniE "prores\|AVAssetWriter\|recordFrame\|captureFrame\|offlineRender\|exportFrame\|writeFrame"` over `src/` → **zero hits** (2026-08-21). Pre-rendered material is recorded from the Syphon feed by an external tool. | verified 2026-08-21 | **This promotes S1 and S2.** A recorded file bakes in the window's aspect ratio AND the laptop's star scale permanently. Live output can be re-pointed; a file cannot |

---

## 🤖 WHAT AN AGENT CAN AND CANNOT DO

🚨 **The ONE LIVE APP rule stands** (his order 2026-08-10 16:01:00): one window holds the build token.
**Agents must never run `package_macos.sh` and never launch the app.** So:

- ✅ **Agent-able:** source reading, call-graph audits, offline math, standalone test programs, doc/board correction, writing a patch.
- ❌ **NOT agent-able:** anything whose answer needs a build, a run, an fps number, or his eyes.

Computer-use / browser-use from the 2026 platform announcement does **not** change this: those are Claude API
products for apps you build, not tools available in this session, and they cannot drive a native macOS app here.
The one real angle in that announcement is a **separate project**: an autonomous tuner that drives SpaceSynth by
screenshot and clicks. That is the direct answer to "STARS ARE UNDIALABLE" — but it is a build, not a switch.

---

**Last Updated:** 2026-08-21
