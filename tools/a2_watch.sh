#!/bin/bash
# A2 — REFUND TEST WATCHER (2026-08-08 17:22:11)
# Built on a1_watch.sh (same launch method: `open -n --stdout/--stderr`, which is
# the ONLY way stderr survives — a Finder launch discards printf entirely).
#
# The test needs HIS HANDS. This script does the waiting and the reading:
#   phase 1  launch silent at 1x, wait for a body to cross M_BH_SEED (50.0)
#   phase 2  announce READY — he holds a sustained note
#   phase 3  report every [REBIRTH] line and whether gMaxMass went NON-MONOTONE
#
# Trigger conditions, read from the source (not guessed):
#   particles.metal:665  sustainHeld = envelopePhase in [2.5, 3.5)  -> SUSTAIN only.
#                        Attack/decay/release do NOT fire it. The note must be HELD.
#   particles.metal:320  SUSTAIN_REBIRTH = 0.0056/frame/corpse (1/180)
#   particles.metal:737  mass = imfMassOfId(id), withdrawn via seedAccum[6]
#   renderer.mm:3094     [REBIRTH] prints ONLY inside the %120-frame block and
#                        ONLY when wdraw > 0 -> hold for >= 1 s to land on a sample.
#
# Usage: a2_watch.sh [existing-log-or-NEW]
cd "/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE" || exit 1

LOG="${1:-NEW}"
CAP=1800   # 30 min hard cap on phase 1 (post-fix crossings seen at ~8-16 min)

peak() { awk 'match($0, /Mmax=[0-9.]+/) { v = substr($0, RSTART+5, RLENGTH-5) + 0; if (v > m) m = v } END { printf "%.1f", m }' "$1" 2>/dev/null; }
last() { awk 'match($0, /Mmax=[0-9.]+/) { v = substr($0, RSTART+5, RLENGTH-5) + 0 } END { printf "%.1f", v }' "$1" 2>/dev/null; }
fps()  { grep -oE "FPS: +[0-9]+" "$1" 2>/dev/null | grep -oE "[0-9]+$" | sort -g | awk '{a[NR]=$1+0} END {if(NR==0){print "n/a"; exit} print a[int(NR/2)]}'; }

if [ "$LOG" = "NEW" ]; then
  pkill -x SpaceSynth 2>/dev/null; sleep 3
  LOG="logs/A2_refund_$(date +%Y%m%d_%H%M%S).log"
  open -n --stdout "$LOG" --stderr "$LOG" SpaceSynth.app
  echo "launched -> $LOG"
fi

echo "=== A2 WATCH  log=$LOG  start $(date '+%Y-%m-%d %H:%M:%S') ==="
echo "PHASE 1: silent at 1x, waiting for Biggest body to cross 50.0. DO NOT PLAY YET."

el=0; crossed=0
while [ "$el" -lt "$CAP" ]; do
  sleep 30; el=$((el + 30))
  p=$(peak "$LOG")
  alive=$(pgrep -x SpaceSynth >/dev/null && echo up || echo DOWN)
  f=$(fps "$LOG")
  echo "[$(date '+%H:%M:%S')] +${el}s peak=$p medianFPS=$f app=$alive"
  [ "$alive" = "DOWN" ] && { echo "!!! instance died at +${el}s — run INVALID (see the two-instances note in a1_watch.sh)"; exit 2; }
  # A starved run is not evidence: dt is per-frame, so low FPS = the sim barely ran.
  if [ "$f" != "n/a" ] && [ "$f" -lt 30 ] 2>/dev/null; then
    echo "    ⚠️  medianFPS=$f (<30) — display may be asleep. This run will not progress."
  fi
  # >50.5: the heaviest IMF star is 49.957, so anything above 50.5 is a merger product.
  if awk -v v="$p" 'BEGIN{exit !(v>50.5)}'; then crossed=1; break; fi
done

if [ "$crossed" != "1" ]; then
  echo "=== phase 1 timed out at ${CAP}s, peak=$(peak "$LOG") — no seed, A2 not runnable on this run ==="
  exit 3
fi

echo ""
echo "############################################################"
echo "### READY at +${el}s — Biggest body = $(peak "$LOG")"
echo "### HOLD A SUSTAINED NOTE NOW. Hold it >= 2 s, several times."
echo "### Sustain phase ONLY — a short stab may miss the sample window."
echo "############################################################"
echo ""

# PHASE 3: watch for the refund. Report the withdrawal and the non-monotone check.
base=$(peak "$LOG")
w=0
while [ "$w" -lt 900 ]; do
  sleep 20; w=$((w + 20))
  pgrep -x SpaceSynth >/dev/null || { echo "!!! instance died during phase 3 at +${w}s"; exit 2; }
  n=$(grep -c "\[REBIRTH\]" "$LOG" 2>/dev/null)
  echo "[$(date '+%H:%M:%S')] +${w}s  REBIRTH lines=$n  peak=$(peak "$LOG")  now=$(last "$LOG")"
  if [ "$n" -gt 0 ]; then
    echo "  --- last 3 [REBIRTH] ---"
    grep "\[REBIRTH\]" "$LOG" | tail -3
    if grep -q "SHORTFALL(minted)" "$LOG"; then
      echo "  🚨 SHORTFALL(minted) PRESENT — the drain clamped at 0 and mass was CREATED."
    fi
    # THE claim under test: has gMaxMass ever fallen?
    awk 'match($0,/hole=[0-9.]+/){v=substr($0,RSTART+5,RLENGTH-5)+0; if(prev>0 && v<prev-0.05){d++; if(d==1) printf "  ⭐ NON-MONOTONE: hole fell %.1f -> %.1f\n", prev, v} prev=v} END{ if(d>0) printf "  ⭐ %d falling steps in [REBIRTH] hole= — gMaxMass IS non-monotone.\n", d; else print "  hole= never fell across [REBIRTH] samples yet." }' <(grep "\[REBIRTH\]" "$LOG")
  fi
done
echo "=== phase 3 window closed $(date '+%Y-%m-%d %H:%M:%S') ==="
