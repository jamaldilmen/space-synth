# SPACE SYNTH — BRAIN handoff 2026-09-03 05:20:00

> **His verdict on this state:** *"ok. this is better its also really good for fps"* (gate 15, 04:22) · *"damn yo. bh formed after seconds"* (gate 5, 04:29) · *"we have two more days. you didi amazing today"*
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` **§AD then §AC.12** — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `dbda8e8`+
**Build + launch:** `bash package_macos.sh` · `./SpaceSynth.app/Contents/MacOS/SpaceSynth --env SS_FULLSCREEN=1 SS_LENS_RENDER=1`
**Windows:** BRAIN routes · **FABLE is the ONLY window that builds** (his order) · OPUS collates + Ableton · SONNET imgui/time + 2 subagents

⚠️ **ALL LINE NUMBERS BELOW RE-GREPPED AT `dbda8e8` (2026-09-03 05:18).** The RETURN PULL inserted a block at `particles.metal:~1461-1520`; **every citation past that point moved by ~69 lines.** Anything written earlier tonight, including §AC.12's, is stale below `:1461`. Never re-derive a line by arithmetic.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | σ split unpinned — the cap could not be derived | "~13×", unmeasured | **units half = coded/honest = ×1/cFrame² = 297.12–297.36 on 31/31 samples**; weighting **W = 1.075–1.587** ⇒ the 13× was the UNIT factor; weighting is ~1.2 | `renderer.mm:4976`, `particles.metal:4363/4391` | `[MEASURED n=3, 31 samples]` BRAIN re-derived from raw logs, independent of FABLE's script |
| 2 | `[CLUSTER] speed avg` under-reported | Σ(v/c over LIVE) ÷ `particleCount` (whole buffer, dead+wall) | ÷ `totalCT`, the kernel's own live count | `renderer.mm:4294` | `[MEASURED]` N/live reached **1.094** at 180 s; grows as matter is eaten |
| 3 | "The lens is a law" | believed derived | **the visible lens is the honest law × 1/cFrame² — A SCALE KNOB**, now labelled as one in code. Honest region = **5.2 r_s = 0.08 sim**; matter meanR **5.8 sim ≈ 360 r_s** | `renderer.mm:4976` | `[HIS WORDS]` *"theres no lense at all now lol u overdid it"* 01:2x → reverted, kept knowingly |
| 4 | What holds the general population still | unknown | **THE REST-STATE VELOCITY SINK CHAIN.** `finalV = (v·dynamicFric·coolMul + shiftV)·soften` — existing velocity multiplied by three sub-unit factors EVERY step; e-folds <1 s. **The exemption is earned only by TANGENTIAL speed ⇒ a stopped body is stopped BY CONSTRUCTION** | `particles.metal:3375`; lock `:3369`; cooling `:2088`; dynfric cap `:2257` | `[MEASURED]` v4 gain 0.05 → seed flat r 4.1–4.2; v5 gain 1.0 → seed **r 12.213 → 0.178**, others \|d\| 0.02–0.058 vs frozen 0.001–0.002 |
| 5 | §N4 one-seed-per-cell blamed for the stand-off | boarded 2026-08-28 as the blocker | **DEAD in his regime** | `particles.metal:4026` | `[MEASURED n=3]` `cellsWith2+` = **0 in 39/39** samples |
| 6 | His "merger" read as our "seed" | every instrument gated at `M_BH_SEED = 50` | **his visual class is 5–50 M☉** — counted by nothing, and skipped by the fix until v6 | `particles.metal:220`, `:1470` | `[MEASURED]` census: `[5.54,30)` n=7190 with **58–110 bodies exactly still**; `[50,+)` **n=0** in that run |
| 7 | Parked mergers never reach the hole | stand-off, minutes | **RETURN PULL shipped** — cinematic one-sided inward drift, mass-gated, ramps after silence, fades × (1−bhStrength) | `particles.metal:1461-1520`, `renderer.h:437` | `[HIS WORDS]` *"ok. this is better its also really good for fps"* 2026-09-03 04:22 |
| 8 | Whitening when light stacks | sensor BLEACH stage AFTER the asinh stretch | **bleach is a dial, default 0 = OFF** (`SS_BLEACH`); honest Lupton/SDSS stretch stands. JWST spikes added (`SS_SPIKES=jwst`), Hubble default bit-identical | `postfx.metal:418`, `render.metal:2727` | `[READ]` `postPad0` (`postfx.metal:13`) and `horizonRPad2` (`renderer.h:321`) both documented-FREE pads — no scalar added or removed |
| 9 | `PhysicsUniforms` had **no** size guard across ~40 hand-synced fields | a mismatch compiled and ran silently | **`static_assert(sizeof(PhysicsUniforms)==172)`** — the first this struct has ever had | `renderer.mm:21` | `[READ]` `returnPull` at offset 168 on both sides; only one `.metal` defines the struct |

## 2. 🚨 OPEN — his list, verbatim

1. ***"chladni used to be super mega hi res ansd razor sharp"*** — a **REGRESSION by his eyes**. `MEASURE:` find the commit that changed Chladni resolution / sample count; date the code, do not diff today. FABLE.
2. ***"its so thin that straigh tlines read as unterbrochene liniern wegen dem angle liek glitchy"*** — aliasing/sampling at an angle, **not** brightness. FABLE.
3. ***"brightness from fiedl vs brightnes sNOT EXPOSURE BUT BRIHGTNESS from chaldni is ass"*** — 🚨 **he has PRE-RULED OUT the exposure/tonemap path.** Field vs Chladni brightness mismatch. FABLE.
4. ***"chaldni different color werid color . only in chladni"*** — isolated to the Chladni branch, not the shared pipeline (bit16 sits at three sites; never RGB-mix a hue shift). FABLE.
5. ***"the black hole should never exceed a certain size. it cant fill up the enitre screen. and the siete must be insync. of the hwole the lense and the force it errupts"*** — **his cap order from 00:38 is NOW DERIVABLE: σ is pinned (row 1).** Derive it; **never a clamp constant.** Sync across THREE: hole, lens, erupted force. FABLE.
6. **THE ≥50 M☉ HOLDER IS UNIDENTIFIED.** Under a gain-1 radial steer, <50 bodies move and ≥50 do not — *"the largest are unaffected not the smallest like the gate was reversed"* (04:29). `MEASURE:` force-decomposition probe (per seed: per-block dv, `finalV`, post-write radius). **HE SAID NO GO** 04:55. Nine candidates eliminated — §3.
7. **MIDI System Real-Time parser — UNRULED, STAGE RISK.** `src/core/midi_input.mm:26-53`: `type = status & 0xF0` collapses 0xF8–0xFF into the `>=0x80` branch, over-consuming 2 bytes per Real-Time byte. Fix written, **NOT applied**. Cologne 2026-09-05. SONNET.
8. **Return pull persists after formation** — the fade keys on `bhStrength`, which fell to 0.3–0.4 after his play **despite LATCH**, so the pull returns. **His ruling needed:** should the latch hold it off?
9. **BH→play transition "looks weird"** (04:29) — parked, undescribed by him.
10. **OPUS:** Ableton **Link** + **MIDI CC** + macros → arrangeable movements, **every UI parameter mappable**. 🚨 *"i dont want ay faders moved from this. they should just be mappable."* Design only, no code.
11. **SONNET:** imgui loose ends (e.g. wavelength) · every site deriving time from **fps not seconds** · then 2 subagents on **offline rendering**; reports → OPUS → BRAIN.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Return pull v1 — REJECTED 2026-09-03 03:12 by his eyes.** It capped the per-step KICK, not the speed; inward velocity integrated to the light cap and ate the field in ~10 sim-s (meanR 14.5 → 0.93). **AN ACCELERATION CAP IS NOT A SPEED CAP.** The bit4 pin survives that shape only because it damps ALL velocity. v2's fix: relax toward a target radial SPEED.
- **"Make dynfric sink the seeds" — REFUTED 2026-06-30, re-confirmed tonight.** `docs/handoff_2026-06-30.md:47-52`, under *"Two hypotheses REFUTED this session (do NOT re-try them)"*: *"friction makes it collapse — WRONG; meanR expands."* Measured 47→78 off, 47→68 on. **The same document ships Chandrasekhar friction as RANK-1 and records it failing at this exact job.** Cite both halves or neither.
- **R-per-body as the STAND-OFF fix — STRUCK 2026-09-03 02:57 by measurement.** Seeds sit **1.8–37 sim apart and stationary**; a contact radius is irrelevant when they never approach. R-per-body remains right for **binding/tearing** and **lens scale** — shipping it as the stand-off fix would have been the session's most expensive wrong turn.
- **NINE HOLDER CANDIDATES ELIMINATED — do not re-walk:** hardness/`soften` (`meanH`=0.000 at rest, every bin) · COM shift `:3722-3723`-era, now `:3728`-era (pos and prev shifted equally, velocity preserved) · **bit4 origin-pin** `particles.metal:1431` (`app_state.h:47` default false, not persisted, no preset carries it, ~10 relaunches) · **star-map home pin** `:3435` (gated `amplitude > 0.005`; `[GRAV] amp = 0.000` on 62/62 rest samples) · `collapsed` flag (exact origin only) · envelope→radius blend (compiled off, `if (false)`) · NaN respawn (would zero \|d\|) · **`seed_apply:4165` dilution — SIZED: the sink gained ~7,236–7,767 M☉ per 240-frame window ≈ 8 M☉/step on m≈110k ⇒ `m/(m+gain)` = 0.99993 ⇒ 7e-5 velocity loss/step. NOT a brake** · the sink chain as a ≥50-*specific* cause.
- **`[GRAV] feed=` as an instrument — 0 on 22/22 samples across five runs while the field demonstrably fed.** NOT "dead by construction" (see §5) but **undetermined by read and sub-sampled**: unsynchronised `.contents` read, one substep in four, once per 240 frames. Fix pattern exists (`radialMassStableBuffer`). **Not commissioned.**
- **Five `[GRAV]` fields are inert** — `scan=`, `e0m=`, `e0id=`, `exit=` always 0; `s0[cnt=` duplicates `seeds=`. Their only writer `seed_feed` is **never dispatched** (`particles.metal:4184`; no `seedFeedPipeline`). 🚨 The `merge_stars` boundary-shell rule cites *"exit=304"* as its evidence — **unreproducible today.**
- **16× warp is NOT 16× more time.** `renderer.mm:1713`: `dt = 0.0165 × warp` — warp multiplies the STEP. His *"even at 16 x speed the mergers dont merge"* proves warp does not fix it; it does **not** prove more sim time would fail.
- **The `1.4·cellSize` constant is at TWO LIVE sites** — `particles.metal:1584` (capture clamp) and `:1713` (merge reach). `:4282` is inside undispatched `seed_feed`. ⛔ Boarded warning stands: *"Clamp + scan width must move together. Do NOT predict 'reach scales with mass'."*

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-03 05:08:06  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 1f6b20a
  FAIL  6 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M imgui.ini / M src/render/particles.metal / M src/render/postfx.metal
           M src/render/render.metal / M src/render/renderer.h / M src/render/renderer.mm
  WARN  1 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 9f61c66 — 11 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 217255B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  WARN  docs/BOARD.md has no 'Commit at last verification: `<sha>`' line — add one
  WARN  docs/BOARD.md is 166995B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    46 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:577 / :765 / :1146 / :1466 / :1469 / :2571 / :3315
  ?     src/render/postfx.metal:66
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

PREFLIGHT: FAILURES ABOVE — fix before handing off.
```
**The FAIL was FABLE's 6 paths / 8 concerns. CLEARED under this same `/handoff` order:** `9a04ab0` σ probe · `5b7b1d4` avg live-count · `e93b3fd` law comment · `459bd55` SEEDPROBE · `6a632d7` RETURN PULL + size guard · `516c6a8` MASSCENSUS · `25de68f` bleach dial · `dbda8e8` JWST spikes. One concern each, staged by hunk; binary and metallib confirmed **untracked** before committing; `imgui.ini` reverted after quitting the app. **Not pushed — no push order.**
⚠️ Two WARNs are real debt for the next window: **both boards need their closed rows split out**, and `docs/BOARD.md` still has no machine-readable `Commit at last verification:` sha.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The launch drain is a scripted radius pull — **verified in code**" | **I read a HEADER and reported a MECHANISM.** Every force inside `particles.metal:999`'s PHASE 0 block is DISABLED, each with its own note (*"never from a hardcoded central attractor"*); bit1 and bit4 default off. **The launch collapse is FREE-FALL under the field's own gravity.** His observation of an inward rush stands; my attribution did not. **There is nothing fake to reuse.** |
| "The `feed=` plate can only ever be read cleared" | Too strong — it would have stopped anyone reading a readable buffer. `seed_apply` takes it `device const atomic_uint*`, load-only, never clears. Correct: **unsynchronised and sub-sampled**. (OPUS's catch.) |
| "The one-seed-per-cell collision is the nucleus blocker" | Relayed as a fresh hypothesis; it was **boarded 2026-08-28** (§N4). Then measured **dead** in his regime (0/39). Wrong twice — as novel, then as true. |
| "`seed_apply` dilution is the mass-selective brake" | **Pushed twice, wrong twice** — first with the trickle rate, then assuming a sink sweep would be large enough. Sized at **7e-5/step**. Exactly what `verify_relevance_not_just_existence` exists for. |
| "`1.4·cellSize` is at THREE sites" | Relayed from OPUS, which retracted it: `:4282` is in `seed_feed`, which **nothing dispatches**. **A code site is not a mechanism either.** |
| "'Early chord never forms' — n=2" | Now **1 of 3**: runs 2 and 3 latched to 1.00 via the pile despite the early chord. |
| "The stand-off's control arm was REST" | It was the **LAUNCH DRAIN**. **We have zero runs where a hole formed by matter merging.** |
| "14 sightings of *a comment is not a mechanism*" | Index said 14, the file said 12. Resynced to **14** after two real sightings tonight (the dead instrument; the false comment at `particles.metal:3834-3836`). Trust the FILE. |
| Memory timestamps 01:10–02:30 | Taken from FABLE's reported times, which ran **~30 min ahead** of the machine clock. Findings verified; **times are not.** His order since: *"stamp from the real clock from now on."* |


## 6. 🔄 AFTER THE HANDOFF COMMIT — post-`9fa4191` work, boarded as §AD.13-16

Everything below landed AFTER §1-5 were written. **Board rows are §AD.13-16; this is the diff.**

- **`docs/BOARD.md` still has NO machine-readable `Commit at last verification:` sha, and BOTH boards need their closed rows split into `BOARD_CLOSED.md`** (239KB / 167KB). Preflight WARNs on all three. **Real debt, not commissioned.**
- **AD.13 — my frame≠time retraction was nearly an over-correction.** Two true statements about DIFFERENT code: the **engine clock is healthy** (step COUNT from wall seconds, `renderer.mm:1787-1814`, clamp 4 — the cure), while **§AC.11's 1/dt² is in the LENS INFLUENCE LAW's units and is still true — it is the basis of the σ pin.** Discarding both would have lost the pin. A relay of mine merged them; neither window was wrong.
- **AD.15 — THE ROTATION SUBSYSTEM IS DEAD: 9 symbols, and NO rotation widget exists anywhere in the UI.** `RenderConfig` is passed by const reference and never blitted, so a named read is the only possible consumer and there is none. `uiAutoRotateBlackHole` defaults **true**, so two `ImGui::GetTime()` terms are evaluated **every frame and discarded** — a consumer was removed and left its supply chain standing. ✅ **NO STAGE RISK** — nothing at the desk is wired to it. **Cleanup; must NOT compete with the MIDI parser.** HIS CALL, not built. (SONNET found it, OPUS scoped it, BRAIN widened it to three fields, OPUS widened it to the subsystem.)
- **AD.16 — 🚨 POLICY GAP: AN ELABORATE PRODUCER IS NOT EVIDENCE OF A CONSUMER.** Three victims in one night — SONNET (a slider that does not exist), OPUS twice (a clamp in an undispatched kernel; then `rotationX` held up as live by describing what WRITES it), and me (a header read as a mechanism). **The check is one line — grep for a READ — and nobody ran it unprompted. It belongs in `preflight.sh`, not another memory file.** `[MEASURED n=3 in one session]`
- **`struct Preset` saves 15 fields against 60+ live dials** — Kelvin, star size, smear, ISCO, SPH cooling, mirror mode all silently dropped. Known gap, wider than boarded.
- **OFFLINE RENDERING — a real two-tier choice, and NEITHER window recommended a tier.** OPUS verified the premise rather than trusting it: the fixed-dt debt accumulator **already exists**, so tier 1 is a bolt-on, not a re-architecture. **MVP `[HYPOTHESIS — no estimate verified]`:** MIDI+tick logger, audio feature logger, **real-time** replay through the live app captured by an off-the-shelf Syphon recorder, live/pre-rendered crossfade **downstream in the existing VJ mixer** — zero new in-app code, and it buys redoing a take without him replaying it. ⛔ **DO NOT ATTEMPT before Cologne:** decoupled-clock non-realtime renderer, temporal-sample motion blur, ProRes/AVAssetWriter capture, Alembic/VDB, in-app crossfade, sim checkpointing. ⭐ The existing `[PERF]` real-time ratio is a **free regression check** for offline mode — it should read FIXED, not fluctuate.
- 🚨 **THE MIDI PARSER IS ON THE CRITICAL PATH FOR ABLETON CC.** `src/core/midi_input.mm:26-53` is still **unruled**, and OPUS's Ableton/MIDI-CC design names it as its stated dependency. **If he wants CC control at Cologne, that parser must be ruled on first.** Cologne 2026-09-05.
- **Window state at this stamp:** OPUS on Job 2 (Ableton Link / MIDI CC / macros — design only, every UI param mappable, **no fader moved**); SONNET's offline subagents delivered; FABLE holds the build token and is the ONLY window that builds.

⚠️ **BRAIN's own process fault this session:** I boarded AD.13-16 and reported them to him as if the handoff were finished — *"stop this is not post handoff yet chill"* (2026-09-03 05:21). The work is sound; the timing was mine, not his.

---

**Last Updated:** 2026-09-03 05:23:00
**Folded into board:** `docs/BOARD_BLACKHOLE.md` §AD @ 2026-09-03 05:20:00
