# DESIGN — D6: A REAL-TIME-SAFE COMMAND PATH

**Written:** 2026-08-10 10:41:02 · by the audio window
**Status:** SPEC. **No code written. Nothing built. Nothing deployed.**
**Implements:** board row **D6** — *"the only item on the whole board that can take down a live show"*
**Build:** the board window holds the token. This document is written to be built FROM, not by me.
**Scope order (his call, 2026-08-10 10:37:00):** D6 goes in BEFORE D7 sonification.

---

## 0. THE STANDARD THIS VIOLATES

Repo-root `CLAUDE.md`, Conventions:

> **Lock-free only between audio and render threads.**

That rule is already stated and already broken. D6 is not new policy — it is enforcement of policy
that predates it.

---

## 1. THE MEASURED FACTS

Every line below was read in source on **2026-08-10 10:20–10:45**. Nothing from memory, nothing
from another window's summary. The live path was proven before anything was cited:
`audio_engine.mm:59` `audioOutputCallback` → `:80` → `Synth::processBlock`. It is the CoreAudio
render callback, not a dead overload.

### 1.1 The five lock sites

| # | Thread | Site | Work done under `queueMutex_` |
|---|---|---|---|
| 1 | **RT (CoreAudio)** | `synth.cpp:91` | `swapBuffer_.swap(commandQueue_)` — cheap, O(1) |
| 2 | **RT (CoreAudio)** | `synth.cpp:138` | **front insert**, see §1.2 |
| 3 | MIDI / main | `synth.cpp:162` `noteOn` | `push_back` + **`std::sort`** |
| 4 | MIDI / main | `synth.cpp:175` `noteOff` | `push_back` + **`std::sort`** |
| 5 | MIDI / main / render | `synth.cpp:148` `processCommands` | `commands.swap(commandQueue_)` |

Site 1 is unconditional — **every** callback, no `try_lock`, no timeout. Nine lines below it, the
voice mutex is taken correctly: `synth.cpp:99`, `std::unique_lock(mutex_, std::try_to_lock)`, with
the comment *"never blocks the RT thread."* **The rule was known, written down, and applied to one
of the two mutexes.**

### 1.2 Site 2 is the worst one, and it can allocate

```cpp
// synth.cpp:137-141
if (!voiceLock.owns_lock() && !swapBuffer_.empty()) {
  std::lock_guard<std::mutex> lock(queueMutex_);
  commandQueue_.insert(commandQueue_.begin(), swapBuffer_.begin(),
                       swapBuffer_.end());
}
```

Three defects stacked in one statement, on the audio thread:

1. **Front insert into a `std::vector`** — O(n) shift of every existing element.
2. **No size guard.** The 256 cap exists *only* at `synth.cpp:163` and `:176`
   (`if (commandQueue_.size() < 256)`). This site has none, so it can push the queue past 256.
3. **It can therefore reallocate → `malloc`/`free` inside the CoreAudio callback, while holding a
   mutex.**

And there is no reservation anywhere establishing a capacity floor:

```
grep -n "reserve" src/audio/synth.cpp src/audio/synth.h   →   NO MATCHES
```

`synth.h:110-111` comments `swapBuffer_` as *"Pre-allocated swap buffer (avoids RT heap alloc)"* —
but nothing pre-allocates it. "Pre-allocated" describes only capacity reuse through the swap
idiom at `:92`, and **the swap makes the two capacities ping-pong between the two vectors every
block** (`:142`'s `clear()` keeps capacity but the objects have already traded buffers). So
`commandQueue_`'s capacity on any given block is whatever `swapBuffer_` happened to be carrying.
A reallocation at site 2 does not require the pathological 256+256 case.

⚠️ **HONEST BOUND, and it belongs in the row:** site 2 fires only when the voice `try_lock` was
**missed** AND `swapBuffer_` is non-empty. That is worst case, not typical. **Worst case is the
entire point of D6** — a dropout on stage is not recoverable the way a visual flaw is.

### 1.3 The sort sorts a constant

`noteOn`/`noteOff` sort the queue by `sampleOffset` while holding the lock. **`sampleOffset` is `0`
at every call site in the program.** All seven:

| Site | Call |
|---|---|
| `main.cpp:177` | `synth.noteOn(note, velocity)` |
| `main.cpp:181` | `synth.noteOff(note)` |
| `main.cpp:477` | `synth.noteOn(midi)` |
| `main.cpp:481` | `synth.noteOff(midi)` |
| `main.cpp:509` | `synth.noteOn(n.midi)` |
| `main.cpp:514` | `synth.noteOff(n.midi)` |
| `main.cpp:2046` | `synth.noteOff(seqNotes[i].midi)` |

None passes the third argument; the default is `0` (`synth.h:40-41`). **So the `std::sort` under
the lock is ordering an all-equal key — it is pure cost with zero behavioural effect today.**
Removing it changes nothing observable. This is the cheapest real win in the row.

---

## 2. 🚨 THE FINDING THAT CHANGES THE FIX

**The obvious fix is wrong.** The design doc §9.5 and the board both point at `AudioRingBuffer`
(`audio_engine.h:18`) as the pattern to reuse. It is explicitly *"Lock-free **SPSC**"* — one
`readPos_`, one `writePos_`, single producer assumed.

**This queue is neither single-producer nor single-consumer.**

### 2.1 Two producers

| Producer | Path | Thread |
|---|---|---|
| MIDI keyboard | `main.cpp:177`, `:181` | **CoreMIDI's own thread.** `midi_input.mm:17` says so in the source comment; `:78` uses `MIDIInputPortCreate`, whose read proc Apple runs on a separate high-priority thread. |
| Computer keyboard | `main.cpp:477`, `:481` | main / UI |
| Sequencer | `main.cpp:509`, `:514` | main / render (frame callback, `main.cpp:498`) |
| ImGui Stop | `main.cpp:2046` | main / UI |

Rows 2–4 are the same thread. Row 1 is not. **Two writers.**

### 2.2 Two consumers — and the second one steals from the first

```cpp
// synth.cpp:265-269
int Synth::activeVoiceCount() const {
  // Process any pending commands so the count is immediate
  const_cast<Synth *>(this)->processCommands();
  ...
}
```

`processCommands` (`:145`) **drains `commandQueue_` and applies every command to `voices_`** via
`handleNoteOn`/`handleNoteOff`. And `activeVoiceCount()` is called at `main.cpp:179`, `:479`,
`:527`, `:2546`.

Look at what that means at `main.cpp:177-179`:

```cpp
synth.noteOn(note, velocity);                    // :177  push onto the queue
printf("[MIDI] noteOn ... voices=%d\n", ...,
       synth.activeVoiceCount());                // :179  DRAINS the queue and applies it
```

**A diagnostic `printf` consumes the command two lines after it was queued, on the MIDI thread,
before the audio thread has any chance to see it.** Same shape at `main.cpp:477-479` for the
computer keyboard.

**Consequences, all of them real today:**

- The sample-accurate walk in `processBlock` (`synth.cpp:104-114`) is bypassed for MIDI and
  keyboard notes in the common case. The machinery exists and is mostly not used.
- Combined with §1.3 — `sampleOffset` is always `0` *and* the commands are usually drained by a
  printf — **the entire sort/offset subsystem is doing no work for anybody.**
- The MIDI thread calls `handleNoteOn` (`synth.cpp:185`), which takes `mutex_` **blocking**. The
  audio thread takes the same `mutex_` with `try_to_lock`. Correct, but it means MIDI-thread note
  handling and audio-thread voice reads contend on the voice map directly.

⚠️ **This is a behavioural entanglement, not just a performance one.** Any fix that makes the
queue single-consumer *changes what `activeVoiceCount()` reports*. That must be a deliberate
decision, not a side effect. See §6.1.

### 2.3 A second, independent RT allocation

Separate from the queue entirely: `processBlock` calls `handleNoteOnInternal` (`synth.cpp:110`,
defined `:190`), which does `voices_[midi] = v;` and `voices_.erase(...)` on a
`std::unordered_map`. **Node insert and erase are heap allocation and deallocation, on the audio
thread.**

This is out of D6's stated scope and is **not** specified here. It is recorded so the next person
does not "fix D6" and believe the callback is allocation-free afterwards. **It will not be.**
Recommend a new board row.

---

## 3. WHAT THE FIX MUST PROVIDE

The current mutex, for all its sins, does three real jobs. A replacement must do all three or it is
a regression, not a fix.

| # | Job the mutex does today | Must survive |
|---|---|---|
| R1 | Serialises **two producer threads** against each other | ✅ |
| R2 | Serialises producers against the **RT consumer** | ✅ |
| R3 | Bounds the queue at 256 (partially — §1.2 escapes it) | ✅ and make it total |
| R4 | — | **NEW: the RT thread must never block, never allocate, never do O(n) work under contention** |

**Non-negotiable:** the RT thread does bounded, wait-free work, or the row is not closed.

---

## 4. RECOMMENDED DESIGN

**A fixed-capacity MPSC ring buffer, producers serialised by a spinlock they own, consumer
wait-free.**

Rationale for each choice, because an untraceable design decision is the same bug as an
untraceable constant:

### 4.1 Fixed capacity, allocated once

```
static constexpr int kCommandQueueCapacity = 256;   // matches today's cap, synth.cpp:163
MidiCommand ring_[kCommandQueueCapacity];           // plain array, no vector, no heap
```

A raw array in the object. **No `std::vector`, so no `insert`, no growth, no `malloc` — the entire
§1.2 failure mode ceases to exist by construction, not by guard.** 256 × 16 bytes = 4 KB, static.

**Overflow policy: drop the oldest, and count it.** Today `noteOn` silently discards the *newest*
when full (`if (size < 256)`). Dropping the oldest is better for an instrument — a stuck note is
worse than a missed one — but it is a **behaviour change and his call**, see §6.2. Either way the
drop must be counted and surfaced, because a silent drop is how a stage failure becomes
unexplainable.

### 4.2 Consumer side — wait-free, zero locks

The RT thread advances a read cursor and copies out. No mutex, no `try_lock`, no branch that can
block:

- read `writeIdx_` (`std::atomic<uint32_t>`, `memory_order_acquire`)
- copy `[readIdx_, writeIdx_)` into the existing `swapBuffer_` — which **must be `reserve()`d to
  capacity once at construction**, closing the §1.2 gap for good
- store `readIdx_` (`memory_order_release`)

**Site 2 disappears entirely.** There is nothing to re-queue: commands are not removed from the
ring until the consumer has actually taken them, so a missed voice lock simply means the read
cursor does not advance this block. The command stays where it is and is picked up next block.
**The re-queue path existed only because the swap destroyed the queue before the work was done.**

### 4.3 Producer side — a spinlock the producers own, and the RT thread never touches

Two producer threads need mutual exclusion against each other (R1). They do **not** need it against
the consumer — the atomic cursors handle that (R2).

```
std::atomic_flag producerLock_;   // held ONLY by MIDI/main threads, NEVER by the audio thread
```

A producer holds it for a bounded, tiny critical section: write one element, bump `writeIdx_`.
**Because the audio thread never acquires it, priority inversion is impossible** — the pathology
the current design has, where the RT thread waits on a UI thread that is mid-`std::sort`.

⚠️ **If a true multi-producer lock-free CAS ring is preferred over a producer spinlock, that is a
legitimate alternative** — it removes the last lock entirely. It is more code and more subtle. I
recommend the spinlock: it is small, it is obviously correct, and the property that matters (the
RT thread never blocks) is fully achieved by it. **Do not add a CAS loop for elegance.**

### 4.4 Delete the sort

Per §1.3 it orders an all-equal key. A ring buffer preserves insertion order, which is what
"sorted by `sampleOffset`" degenerates to when every offset is `0`.

⚠️ **If `sampleOffset` is ever made non-zero** (real sample-accurate MIDI timing — a genuine future
want, and the reason the field exists), insertion order stops being sufficient. **Then** the
consumer sorts its own local copy in `swapBuffer_`, on the RT thread, over ≤256 elements it already
owns exclusively — no lock involved. **Record this; do not build it now.** It is not needed while
every call site passes `0`.

### 4.5 ⭐ THE FIRST VERIFIABLE INCREMENT — do this one alone, then stop

Added 2026-08-10 15:53:14, at the board window's request. §4.1–§4.4 is **one atomic swap** — you
cannot half-replace a queue — so it is not a first increment, it is the whole fix. There **is** a
smaller change that stands on its own:

> **Increment 1: `reserve()` both vectors in the constructor (`synth.cpp:75`). One line. Nothing
> else.**
>
>     Synth::Synth() {
>       chorus_.init(48000.0f);
>       commandQueue_.reserve(kCommandQueueBound);   // 512 — see derivation
>       swapBuffer_.reserve(kCommandQueueBound);
>     }

**Why this and not something else:** D6's genuinely dangerous element is not the lock, it is the
`malloc` *inside* the lock on the RT thread (§1.2). A `reserve()` removes the allocation **without
touching structure, ordering, or behaviour** — the lock stays, D6 stays open, and the worst case
stops being unbounded. If nothing else lands before Berlin (23 days), this alone is worth having.

**⚠️ The bound is 512, not 256, and the 256 in §4.1 is wrong for *this* increment.** Derivation:

1. `:91` swaps — `commandQueue_` becomes last block's cleared `swapBuffer_`, i.e. empty.
2. During the block, producers may push up to **256** (`:163`, `:176` cap).
3. `:139` then front-inserts up to `swapBuffer_.size()` more, which is itself ≤ 256, **with no cap**.

→ **512 is the true high-water mark of `commandQueue_`.** Because the two vectors ping-pong through
`swap` at `:92`, both must be reserved to the same bound or the capacity migrates and the guarantee
is lost after the first swap. **Reserving only 256 does not close the hole.** (§4.1's `256` is the
ring's capacity in the final design, where the front-insert path does not exist — both numbers are
correct in their own context. Do not copy one into the other.)

**🚨 WHY THIS SURVIVED FOR MONTHS — and it is not "nobody looked".** `synth.h:111` comments
`swapBuffer_` as *"Pre-allocated swap buffer (avoids RT heap alloc)"*. **It is never `reserve()`d
anywhere.** The comment asserts exactly the guarantee the code does not provide, so every reader
after the author had a written reason not to check. **A comment is not a mechanism.**

This is the **third sighting of that pattern on this project**, per the board: **A0h** (a comment
standing in for what is now a compiler-enforced layout guard) and **A3②** (`if (false)` sitting
under a comment describing working behaviour). Identified independently by the board window,
2026-08-10 16:03:00. **Put this in the commit message when Increment 1 lands** — the one-line diff
is not the interesting part; the reason it was invisible is.

**How to verify it landed — statically, no ears, no verdict from him:**

    grep -n "reserve" src/audio/synth.cpp     # must now hit; before this change: zero hits

plus a debug-build assert on entry to `processBlock` that `swapBuffer_.capacity() >= 512`, and a
log of both `capacity()` values captured at **two** points:

1. at construction, and
2. **after the first `swap` at `:92`** — added at the board window's instruction, 16:03:00, and it
   is the more important of the two. ⚠️ **A construction-only log reads green even when the fix is
   wrong**, because the swap is precisely where a one-sided `reserve()` migrates capacity and the
   guarantee dies. Logging only the state before the failure mode can occur is not evidence.

**If that assert ever fires, the increment did not hold** — which is exactly the thing being
claimed fixed.

**What it explicitly does NOT do:** it does not remove a single lock, does not touch the sort, does
not close D6, and must not be reported as closing it. It converts an unbounded-latency hazard into
a bounded-latency one. **Increment 2** is deleting the two sorts (§4.4); **Increment 3** is the ring
itself (§4.1–§4.3), which is the only one that closes the row.

---

## 5. HOW TO PROVE IT FIXED RATHER THAN MOVED

A fix that cannot be shown to have worked is a 🔨, not a ✅. Three checks, in order:

1. **Static — the RT path holds no lock.** `grep -n "queueMutex_\|lock_guard\|unique_lock"
   src/audio/synth.cpp` must show **zero** hits inside `processBlock` (`:81`–`:143`). The `mutex_`
   `try_to_lock` at `:99` stays; it is correct and is not part of D6.
2. **Static — no allocation on the RT path.** No `std::vector` growth operation reachable from
   `processBlock`. `swapBuffer_` reserved once at construction; assert its `capacity()` ≥ 256 on
   entry in a debug build.
3. **Dynamic — the stress that reproduces the hazard.** Hold a chord on the MIDI keyboard while the
   sequencer runs (`main.cpp:498`) so **both** producer threads write concurrently, with the sim at
   2M particles so the render thread is loaded. Watch for `[AUDIO] Output Callback pulse` gaps in
   the existing instrumentation (`audio_engine.mm:64-68` prints every 100 callbacks) and for the
   new dropped-command counter from §4.1.

⚠️ **Test hygiene, from the board's standing rules:** `pgrep -x`, not `-f`. A "dead launch" is
usually display sleep. **And this must be built in a worktree, not the main tree** — the main tree
carries his uncommitted A0/E5 work and one shared `SpaceSynth.app` that three windows launch.

⚠️ **This change cannot be verdicted by ear.** A correct fix sounds *identical*. What it changes is
the worst case, which by definition is not on screen when things are going well. **Do not ask him
"does it sound better".** The verdict is the static checks plus a clean stress run.

---

## 6. DECISIONS — ✅ SETTLED BY HIM, 2026-08-10 11:07:44

**6.2 Overflow: drop oldest or drop newest? → ✅ DROP THE OLDEST.**
His call, verbatim: *"yes, the oldest"*. Today the code drops the **newest**
(`if (commandQueue_.size() < 256)` at `synth.cpp:163`, `:176`). **Change it.** The reasoning that
decided it: a stale `NoteOff` stuck behind 255 other commands is how a note hangs, and a hanging
note through a PA is the worst available outcome. **Drops must be COUNTED and surfaced** — a
silent drop is how a stage failure becomes unexplainable afterwards.

**6.3 Is §2.3 (the `unordered_map` allocation on the RT thread) in scope? → ✅ OUT. OWN ROW, AFTER D6.**
His call, verbatim: *"own row, after D6."* Folding it in would turn an `S` into an `M` and put
regression risk on the one row that protects the stage. **See §6.4 for what that row says.**

**6.1 Should `activeVoiceCount()` stop draining the queue (§2.2)? → ⚠️ ASSUMED YES. NOT EXPLICITLY ANSWERED.**
📌 **Status 2026-08-10 16:03:00: the board window is putting this to him and will relay his exact
words. It does NOT block Increment 1** — a `reserve()` changes no ordering and no consumer — so
nothing waits on it until Increment 3. **Do not build Increment 3 on this assumption.**
🚨 **Flagged honestly: he answered 6.2 and 6.3 and did not answer this one.** I am proceeding on
**yes** because the recommended design in §4 makes it *structurally* forced — a single-consumer
lock-free ring cannot also be drained by a UI-thread getter without reintroducing exactly the
multi-consumer problem the fix exists to remove. So the only real question is whether the
consequence is acceptable, and the consequence is small: **the `voices=%d` figure in the log lines
at `main.cpp:179`, `:479`, `:527`, `:2546` becomes stale by up to one audio block (~10.7 ms).**
Nothing audible, nothing on screen. In exchange, note handling becomes genuinely sample-accurate
for the first time, instead of being triggered by a diagnostic `printf`.
**If he says no, the fix has to change shape — raise it before building, not after.**

### 6.4 THE NEW ROW HIS 6.3 CALL CREATES — proposed text for `BOARD.md`

> **D8 — THE RT THREAD ALLOCATES MEMORY EVERY NOTE-ON.** Separate from D6 and **not fixed by it.**
> `processBlock` → `handleNoteOnInternal` (`synth.cpp:110` → `:190`) does `voices_.erase(...)`
> (`:193`, `:225`) and `voices_[midi] = v` (`:237`) on a `std::unordered_map` (`synth.h:123`).
> Node insert and erase are heap allocation and free, **on the audio thread**, in the callback —
> the same class of unbounded-latency operation as D6's `malloc`, in a different place.
> **The fix is a fixed voice pool**, and the size is already declared:
> `MAX_VOICES = 64` (`synth.h:133`). Build all 64 slots once at construction, mark in-use/free,
> never touch the allocator during a block. ⚠️ Touches how voices are stored, found AND stolen
> (the steal loop at `:196-227`), so it carries real regression risk that D6 does not.
> 🚨 **Do not close D6 and declare the callback allocation-free — it will not be.**
> **Size: `M`. After D6, by his call 2026-08-10 11:07:44.**

### 6.5 ADJACENT FIND — hardcoded sample rate, NOT part of D6 or D8

`synth.cpp:235` calls `v.init(48000.0f)` with a **literal**, inside a function reached from
`processBlock`, which is *handed the real sample rate as a parameter* (`synth.cpp:81`). Today
`main.cpp:166` requests 48000 so it matches and nothing is wrong. ⚠️ **I have NOT verified whether
CoreAudio can hand back a different rate than requested** — so this is "worth checking", not
"broken". If it can, every voice's filter would be initialised for the wrong rate and it would
sound subtly off in a way that is miserable to trace. One-line fix if confirmed.

---

## 7. WHAT THIS SPEC DOES NOT DO

- **Does not touch `mutex_` or the voice `try_to_lock` at `synth.cpp:99`.** That code is correct.
- **Does not touch `src/core/midi_input.*`.** The camera window owns those files. This spec reads
  them and cites them; it changes nothing in them.
- **Does not change any audible behaviour.** If it does, it is wrong.
- **Does not fix §2.3.** Stated explicitly so nobody believes the callback is allocation-free
  afterwards.
- **Does not add a toggle.** A switch between "safe queue" and "old queue" would be a second code
  path in the exact place that must be simple. [[feedback_a_toggle_is_not_a_fix]]

---

## 8. SIZING

**`S` stands** — one file pair, `synth.h` + `synth.cpp`, no API change visible to `main.cpp`.
⚠️ **But it is not one line**, and the board row should keep that caveat. The design decision in
§2 (MPSC, two consumers) is the real work; the code after that decision is small.

---

## 9. LEDGER — every claim in this document, with its source

**Every `synth.cpp` / `synth.h` line below re-verified 2026-08-10 15:53:14 by grep anchor, not by
memory.** Both files are unmodified since **2026-08-02 20:43:59** and clean in `git status`, so
these numbers cannot have decayed under me — **six of them were nonetheless wrong in the first
draft** (`:109→:110`, `:224→:225`, `:235→:237` for `voices_[midi]`, `:236→:235` for `v.init`,
`:165-168→:167-170` for the first sort, `:185/:240→:186/:241` for the `mutex_` locks). They were my
own off-by-N reads, not drift. Anchors are given below so the next reader can re-derive them:

    grep -n "queueMutex_\|std::sort\|voices_.erase\|voices_\[midi\]\|v.init(" src/audio/synth.cpp
    grep -n "lock_guard<std::mutex> lock(mutex_)\|commandQueue_.size() < 256" src/audio/synth.cpp

| fact | source (anchor) |
|---|---|
| live RT path is `audioOutputCallback` → `processBlock` | audio_engine.mm:59, :80 |
| unconditional blocking lock on the RT thread | synth.cpp:91 |
| second RT lock, front insert, no size guard | synth.cpp:137-141 |
| voice mutex is correctly `try_to_lock` | synth.cpp:99 |
| the 256 cap exists only in the two producers | synth.cpp:163, :176 |
| `std::sort` held under the lock | synth.cpp:167-170, :178-181 (`grep -n "std::sort"`) |
| no `reserve()` anywhere in either file | `grep -n "reserve" src/audio/synth.cpp src/audio/synth.h` → zero hits, 2026-08-10 10:33; **independently re-run by the board window in its own tree, 16:03:00, same result** |
| `synth.h:111` claims the pre-allocation that does not exist | synth.h:110-111 vs the zero-hit grep above |
| capacities ping-pong via the swap | synth.cpp:92, :142 |
| `sampleOffset` is `0` at all 7 call sites | main.cpp:177, 181, 477, 481, 509, 514, 2046; defaults synth.h:40-41 |
| MIDI callback runs on CoreMIDI's own thread | midi_input.mm:17 (comment), :78 (`MIDIInputPortCreate`) |
| `activeVoiceCount()` drains the queue | synth.cpp:265-269 → :145 |
| …and is called from the MIDI callback's printf | main.cpp:179 (also :479, :527, :2546) |
| `handleNoteOn`/`handleNoteOff` take `mutex_` blocking | synth.cpp:186, :241 (decls at :185, :240) |
| RT thread inserts/erases an `unordered_map` | synth.cpp:110 → :190; `voices_[midi] = v` at :237, erases at :193, :225 |
| the convention this breaks | repo-root `CLAUDE.md`, Conventions |
| queue internals are touched nowhere outside `synth.*` | `grep`, 2026-08-10 10:36 — no external hits |

**Aside, not D6 scope:** `synth.h` has **no `#pragma once`** (line 1 is an `#include`), against the
repo convention in `CLAUDE.md`. Harmless today because nothing includes it twice. Worth a one-line
fix whenever that file is next open.

---

**Last Updated:** 2026-08-10 16:01:34 — §4.5 added (**Increment 1**, the `reserve()`, bound **512**
not 256, with the after-first-`swap` capacity capture and the *"a comment is not a mechanism"*
finding); six of my own `file:line` cites corrected and stamped (§9); §6.1 marked as being put to
him by the board window.

**Previously, 2026-08-10 11:07:44** — §6 settled. 6.2 = drop the OLDEST (his call). 6.3 = the
voice-pool allocation is OUT, own row **D8**, after D6 (his call). 6.1 assumed YES and flagged as
assumed, not answered.

**Reviewed by the board window 2026-08-10 16:03:00** — every §4.5 claim re-verified in its own
tree before acceptance (the zero-hit `reserve` grep, the unguarded front insert, the 512
arithmetic, the ping-pong). **Increment 1 accepted as the right first move.**

**Next:** ✅ **BUILDABLE.** The board window builds it **in a worktree, not the main tree** — the
main tree carries his uncommitted A0/E5 work and the one shared `SpaceSynth.app` that three
windows launch. Worktree traps to expect, learned by the camera window and recorded on the board:
`third_party/imgui` is a submodule and arrives empty; `third_party/syphon` is **gitignored** and
must be copied by hand; `package_macos.sh:18` does `cd build` with no `mkdir`, and because
`SpaceSynth.app` is tracked in git a failed build still leaves a plausible-looking bundle sitting
there. **Verify the bundle timestamp is newer than the source before believing any test.**
