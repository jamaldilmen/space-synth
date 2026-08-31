#!/bin/bash
# measure_lens_cost.sh — B2a lens cost probe, with the guards that were missed by hand.
#
# WHY THIS EXISTS AS A SCRIPT AND NOT AS A HABIT. On 2026-08-31 three separate
# measurement attempts were voided, each by something a human happened to notice:
#   1. A run on BATTERY AT 12%. fps read 41.7 -> 51.1 -> 84.0 — a rising sequence,
#      published with a caveat. A caveat travels less far than the number does.
#   2. An A/B where the lens-ON arm's hole was 3.2x larger, i.e. ~10x the covered
#      pixels. It measured "bigger region", not "lens on". No run length fixes that.
#   3. A run that STARTED believing it was on AC and had the adapter pulled at
#      20:10. Interleaving does NOT save this: a drifting power envelope puts a
#      monotonic trend underneath the arms and hands you a difference that looks
#      like the lens.
# Every one of those was caught by a person. tools/measure_frustum_cost.sh already
# refuses to run on battery by design; this one does the same AND re-asserts at exit.
#
# THE FOUR GATES, all measured, none assumed:
#   G1 POWER AT START — `pmset -g ac` must report an adapter AND `pmset -g batt`
#      must say "AC Power". BOTH, because they can disagree while a plug is loose.
#   G2 POWER AT END — re-checked and compared. An arm set that started on AC and
#      ended on battery is VOID and says so; nothing else in the harness notices.
#   G3 LOGGING — a short probe must actually produce a non-empty log with fps lines
#      before the real arms start. A previous pinned run completed with exit 0 and
#      wrote NO logs at all; the failure was silent and cost the whole run.
#   G5 PLAY DURING AN ARM — [MEASURED 2026-08-31 20:20] he played one note ~2 min
#      into a lens-ON arm. PLAY TERMINATES THE FORMED HOLE (his law 16:33:00), so the
#      arm changed REGIME, it did not merely get noisier: Mmax ran 150,578 -> 21,710
#      -> 692 and then regrew to 57,116 inside one arm. Discarding a settling window
#      does NOT save it — the note lands inside the window you KEEP. Any arm whose log
#      contains a noteOn, or any envelope phase other than 0, is VOID.
#   G4 HOLE MASS ACROSS ARMS — SS_LENS_PIN_RS pins the drawn REGION, but the
#      physics still forks. Two runs at an IDENTICAL SS_SPAWN_SEED reached Mmax
#      14,532 vs 55,390 in 50 s, because the 32-of-334,576 neighbour sample is
#      picked by GPU SCHEDULING ORDER, not by the RNG. So mass is REPORTED per arm
#      and a large spread is flagged — the baseline frame cost still depends on it.
#
# 🚨🚨 READ THIS BEFORE TRUSTING ANY NUMBER THIS SCRIPT PRODUCES.
# THERE IS NO STEADY STATE TO SETTLE INTO. His observation 2026-08-31: "as more
# time passes fewer particles are rendered." [MEASURED] from four 240 s arms,
# `[PROBE-1000] live=` fell 999 -> 199 / 41 / 43 / 53, i.e. 80-96% of visible
# particles GONE inside one arm, with hole 0.00 -> 1.00L in every arm and CORE
# 14,813 -> 160,727 M☉. At rest the hole grows unopposed and eats the field.
# ⛔ SO "LET IT SETTLE AND DISCARD THE OPENING WINDOW" IS NOT A VALID METHOD HERE.
# A longer run is a MORE EATEN sim, not a calmer one. Compute avg fell 10.45 ->
# 6.99 -> 5.54 -> 2.12 ms across the arms for exactly this reason. Any A/B that
# compares two separate RUNS inherits that collapse as its dominant variable.
# ⭐ THE MEASUREMENT THIS SCRIPT ATTEMPTS IS THEREFORE UNSOUND BY DESIGN, and the
# fix is not in this file: compare two ENCODES OF THE SAME FRAME (a GPU timestamp
# around the draw, or an SS_LENS_ONLY toggle mirroring SS_NO_STARPASS at
# renderer.mm:4363), not two runs. Design handed to FABLE 2026-08-31.
# The gates below are still worth keeping — every one of them caught a real fault.
#
# Usage:  bash tools/measure_lens_cost.sh [arm_seconds] [discard_seconds]
#   defaults: 240 s per arm, first 150 s of each discarded.
set -uo pipefail

APP="./SpaceSynth.app/Contents/MacOS/SpaceSynth"
ARM_SEC="${1:-240}"
DISCARD_SEC="${2:-150}"
PIN_RS="${SS_LENS_PIN_RS:-0.12}"
OUT="$(mktemp -d /tmp/lenscost.XXXXXX)"

watts() { pmset -g ac 2>/dev/null | grep -i 'wattage' | grep -o '[0-9]\+' | head -1; }
batt_pct() { pmset -g batt 2>/dev/null | sed -n '2p' | grep -o '[0-9]\+%' | tr -d '%'; }
batt_line() { pmset -g batt 2>/dev/null | sed -n '2p' | sed 's/^[[:space:]]*//'; }
charge_state() {  # "charging" | "not-charging" | "discharging"
  local b; b=$(batt_line)
  if echo "$b" | grep -qi 'discharging';     then echo "discharging";  return; fi
  if echo "$b" | grep -qi 'not charging';    then echo "not-charging"; return; fi
  if echo "$b" | grep -qi 'charging';        then echo "charging";     return; fi
  echo "unknown"
}

power_ok() {   # echoes "ok" only if BOTH checks agree
  local ac batt
  ac=$(pmset -g ac 2>/dev/null)
  batt=$(pmset -g batt 2>/dev/null | head -1)
  if echo "$ac" | grep -qi 'no adapter'; then echo "no-adapter"; return; fi
  if ! echo "$ac" | grep -qi 'wattage'; then echo "no-adapter"; return; fi
  if ! echo "$batt" | grep -qi "AC Power"; then echo "on-battery"; return; fi
  echo "ok"
}

echo "=== B2a LENS COST PROBE ==="
echo "arm=${ARM_SEC}s  discard=${DISCARD_SEC}s  SS_LENS_PIN_RS=${PIN_RS}  logs=$OUT"

# ── G1 POWER AT START ───────────────────────────────────────────────────────
P_START=$(power_ok)
C_START=$(charge_state)
B_START=$(batt_line)
W_START=$(watts); PCT_START=$(batt_pct)
echo "G1 power at start: $P_START | charge=$C_START | adapter ${W_START}W | batt ${PCT_START}%"
echo "   batt line: $B_START"
# ⛔ WATTAGE AND CHARGE ARE PART OF THE GATE, NOT COLOUR. [MEASURED 2026-08-31]
# A partially-seated cable read 80W / 3990mA / "AC attached; NOT charging" while a
# healthy one read 100W / 4990mA / "charging". BOTH say "AC Power". A naive
# am-I-on-AC check PASSES on the broken one and lets a contaminated 16-minute
# sequence run to completion. I saw the 80W myself at 20:29:37 and wrote it off as
# "still comfortably AC" — observing an anomaly is not the same as gating on it.
# TWO CHECKS, because they catch different faults:
#   (a) not charging while the battery is well under full => weak/partial connection
#   (b) wattage must not CHANGE across the run => the envelope moved underneath it
if [ "${C_START}" = "not-charging" ] && [ -n "$PCT_START" ] && [ "$PCT_START" -lt 95 ]; then
  echo "⛔ REFUSING TO RUN — adapter attached but NOT CHARGING at ${PCT_START}%."
  echo "   A healthy adapter charges at that level. This is the signature of a"
  echo "   partially-seated cable (measured: 80W/3990mA vs a healthy 100W/4990mA)."
  echo "   Re-seat the cable and confirm it reads 'charging' before re-running."
  exit 2
fi
# ⚠️ "AC attached; NOT CHARGING" is a THIRD state, not the same as charging and not
# the same as battery. It can flip to charging at any moment, and a charge cycle
# beginning mid-sequence moves the thermal envelope underneath the arms exactly the
# way an unplug would. So the charge state is recorded and compared, not just AC-ness.
if [ "$P_START" != "ok" ]; then
  echo "⛔ REFUSING TO RUN — not on AC ($P_START)."
  echo "   Power state moves fps ~3x on this machine. A number taken now is not a"
  echo "   slow number, it is NOT A MEASUREMENT. Plug in and re-run."
  exit 2
fi

# ── G3 LOGGING PRE-CHECK ────────────────────────────────────────────────────
pkill -x SpaceSynth 2>/dev/null; sleep 2
SS_FULLSCREEN=1 SS_LENS_PIN_RS="$PIN_RS" nohup "$APP" >"$OUT/probe_o.log" 2>"$OUT/probe_e.log" &
sleep 20
PROBE_LINES=$(grep -ac 'fps=' "$OUT/probe_e.log" 2>/dev/null || echo 0)
pkill -x SpaceSynth 2>/dev/null; sleep 2
echo "G3 logging pre-check: $PROBE_LINES fps lines in 20 s"
if [ "$PROBE_LINES" -lt 1 ]; then
  echo "⛔ REFUSING TO RUN — the app produced no fps lines. A previous run finished"
  echo "   with exit 0 and wrote no logs at all; do not repeat that silently."
  exit 3
fi

# ── THE ARMS — ABBA, NOT ABAB ───────────────────────────────────────────────
# ⛔ WAS A1 B1 A2 B2 AND THAT IS BIASED BY CONSTRUCTION. Under ABAB every B runs
# AFTER an A, so lens state is perfectly correlated with time order. If cost drifts
# monotonically — and here it FALLS, hard, see the banner below — B is cheaper for
# free. [MEASURED 2026-08-31] the two paired deltas agreed to 0.03 ms (-0.326 and
# -0.295) instead of scattering, which is the signature of a systematic offset
# rather than of a real effect. ABBA cancels a LINEAR drift; ABAB cannot.
for arm in A1 B1 B2 A2; do
  pkill -x SpaceSynth 2>/dev/null; sleep 3
  case "$arm" in
    A*) SS_FULLSCREEN=1 SS_LENS_PIN_RS="$PIN_RS" \
          nohup "$APP" >"$OUT/o_$arm.log" 2>"$OUT/e_$arm.log" & ;;
    B*) SS_FULLSCREEN=1 SS_LENS_PIN_RS="$PIN_RS" SS_LENS_DEBUG=1 \
          nohup "$APP" >"$OUT/o_$arm.log" 2>"$OUT/e_$arm.log" & ;;
  esac
  echo "  arm $arm running ${ARM_SEC}s ..."
  sleep "$ARM_SEC"
  # G2 mid-flight: a pull partway through is the case interleaving cannot survive
  if [ "$(power_ok)" != "ok" ]; then
    pkill -x SpaceSynth 2>/dev/null
    echo "⛔ VOID — power state changed during arm $arm. Discarding the whole set."
    exit 4
  fi
done
pkill -x SpaceSynth 2>/dev/null; sleep 1

# ── G2 POWER AT END ─────────────────────────────────────────────────────────
P_END=$(power_ok)
C_END=$(charge_state)
B_END=$(batt_line)
W_END=$(watts); PCT_END=$(batt_pct)
echo "G2 power at end:   $P_END | charge=$C_END | adapter ${W_END}W | batt ${PCT_END}%"
echo "   batt line: $B_END"
if [ "$W_START" != "$W_END" ]; then
  echo "⛔ VOID — adapter wattage changed ${W_START}W -> ${W_END}W during the run."
  echo "   Two readings that both say 'AC Power' are not necessarily the same machine."
  exit 4
fi
if [ "$P_END" != "ok" ]; then
  echo "⛔ VOID — started on AC, ended $P_END. Report nothing from this set."
  exit 4
fi
CHARGE_FLIPPED=0
if [ "$C_START" != "$C_END" ]; then
  CHARGE_FLIPPED=1
  echo "⚠️  CHARGE STATE FLIPPED: $C_START -> $C_END"
  echo "    A charge cycle starting or ending mid-run moves the thermal envelope."
  echo "    Treat the result as SUSPECT and say so; do not report it as clean."
fi

python3 - "$OUT" "$ARM_SEC" "$DISCARD_SEC" "$CHARGE_FLIPPED" "$B_START" "$B_END" <<'PY'
import re, sys, statistics as st
out, arm_sec, disc_sec = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
flipped = sys.argv[4] == "1"
b_start, b_end = sys.argv[5], sys.argv[6]
frac = disc_sec / arm_sec
rows = {}
for arm in ("A1", "B1", "A2", "B2"):
    try:
        txt = open(f"{out}/e_{arm}.log", errors="replace").read()
    except FileNotFoundError:
        print(f"⛔ VOID — {arm} log missing."); sys.exit(5)
    fps   = [float(x) for x in re.findall(r'fps=([0-9.]+)', txt)]
    worst = [float(x) for x in re.findall(r'worst=([0-9.]+)ms', txt)]
    mmax  = [float(x) for x in re.findall(r'Mmax=([0-9.]+)', txt)]
    # ── G5: did he play during this arm? ──
    try:
        oth = open(f"{out}/o_{arm}.log", errors="replace").read()
    except FileNotFoundError:
        oth = ""
    notes  = len(re.findall(r'noteOn', txt)) + len(re.findall(r'noteOn', oth))
    phases = set(re.findall(r'phase=([0-9.]+)', txt))
    played = notes > 0 or any(float(p) != 0.0 for p in phases)
    if played:
        print(f"⛔ VOID — arm {arm} has PLAY in it: {notes} noteOn, phases {sorted(phases)}.")
        print("   Play terminates the formed hole (his law 2026-08-31 16:33:00), so this")
        print("   arm changed regime. A settling discard cannot rescue it — the note")
        print("   lands inside the kept window. Re-run this arm set on an idle machine.")
        sys.exit(6)
    k = int(len(fps) * frac)
    rows[arm] = (len(fps), k, fps[k:], worst[k:], max(mmax) if mmax else 0.0)

print(f"\n{'arm':<4} {'lens':<5} {'n':>4} {'drop':>5} {'kept':>5} "
      f"{'mean':>7} {'med':>7} {'min':>7} {'max':>7} {'sd':>6} {'ms':>7} {'worstms':>8} {'Mmax':>10}")
for arm, (n, k, s, w, mm) in rows.items():
    if not s:
        print(f"⛔ VOID — {arm} had no samples after the discard window."); sys.exit(5)
    lens = "OFF" if arm[0] == "A" else "ON"
    print(f"{arm:<4} {lens:<5} {n:>4} {k:>5} {len(s):>5} "
          f"{st.mean(s):>7.2f} {st.median(s):>7.2f} {min(s):>7.2f} {max(s):>7.2f} "
          f"{(st.stdev(s) if len(s) > 1 else 0):>6.2f} {1000/st.mean(s):>7.2f} "
          f"{(max(w) if w else 0):>8.1f} {mm:>10.0f}")

A = rows["A1"][2] + rows["A2"][2]
B = rows["B1"][2] + rows["B2"][2]
ma, mb = st.mean(A), st.mean(B)
print(f"\nPOOLED OFF n={len(A)}  {ma:.2f} fps  {1000/ma:.2f} ms  sd {st.stdev(A):.2f}")
print(f"POOLED ON  n={len(B)}  {mb:.2f} fps  {1000/mb:.2f} ms  sd {st.stdev(B):.2f}")
print(f"DELTA      {1000/mb - 1000/ma:+.2f} ms/frame   ({(ma-mb)/ma*100:+.1f}% fps)")

# ── G6 NEGATIVE COST — the gate physics provides, and the only one that fired ──
# Adding a fullscreen fragment pass CANNOT reduce frame time. A negative delta is
# proof the experiment is broken, not evidence the pass is free. [MEASURED
# 2026-08-31] a fully gate-green run reported -2.51 ms/frame by fps and -0.356 ms
# by GPU time. Both instruments agreed on an impossible sign; that agreement is
# what proved the DESIGN was at fault rather than the metric.
if mb > ma:
    print("\n⛔ VOID — LENS-ON MEASURED FASTER THAN LENS-OFF. That is impossible.")
    print("   A fullscreen pass cannot make a frame cheaper. Report NO NUMBER from")
    print("   this run. The fault is in the experiment: run-to-run variance here is")
    print("   an order of magnitude larger than the ~0.3 ms being measured.")

# ⚠️ fps IS NOT A VALID INSTRUMENT NEAR THE REFRESH CAP. [MEASURED] one arm sat on
# 120.0 exactly, repeatedly — frame time is FLOORED at vsync and fps stops
# reporting capacity. Prefer [PROFILE/120f] "Render+PostFX avg" (renderer.mm:1790),
# which is GPUEndTime-GPUStartTime and vsync-independent. 🚨 IT PRINTS TO STDOUT,
# not stderr — that is why it was missed for a whole evening of measuring.
capped = [x for x in A + B if x >= 119.5]
if capped:
    print(f"\n⚠️  {len(capped)} samples at/above 119.5 fps — at or near the refresh cap.")
    print("    fps is floored there. Use the PROFILE render times, not these.")

# ── G4 HOLE MASS ACROSS ARMS ──
masses = [rows[a][4] for a in rows]
lo, hi = min(masses), max(masses)
spread = (hi / lo) if lo > 0 else float('inf')
print(f"\nG4 hole mass across arms: min {lo:.0f}  max {hi:.0f}  spread {spread:.1f}x")
if spread > 2.0:
    print("⚠️  MASS SPREAD > 2x — the region is pinned so the LENS cost is unaffected,")
    print("    but the BASELINE frame cost is not: more mass means more merges and more")
    print("    work in the physics. Treat the delta as indicative, not settled, and say so.")
else:
    print("    within 2x — baseline comparable across arms.")
print(f"\nPOWER, verbatim — start: {b_start}")
print(f"                  end:   {b_end}")
if flipped:
    print("⚠️  CHARGE STATE FLIPPED MID-RUN — result is SUSPECT, not clean.")
print("\n⭐ Annotate any row taken from this with the FULL battery line above, not")
print("   just 'on AC'. Forward only; never back-fill a power state onto a")
print("   historical row whose state is unknown.")
PY
echo "logs kept at $OUT"
