#!/bin/bash
# A1 RE-TEST v3 — SERIAL, EARLY EXIT. Two instances cannot coexist (v2's second
# instance died silently ~90s in), so this runs one at a time and stops each the
# moment it answers the question.
#
# Usage: a1_watch.sh <seed> <existing-log-or-NEW>
#   Pass an existing log to adopt an already-running instance instead of
#   restarting it and throwing away its progress.
cd "/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE" || exit 1

SEED="$1"
LOG="$2"
CAP=1500   # 25 min hard cap

peak() { awk 'match($0, /Mmax=[0-9.]+/) { v = substr($0, RSTART+5, RLENGTH-5) + 0; if (v > m) m = v } END { printf "%.1f", m }' "$1" 2>/dev/null; }

if [ "$LOG" = "NEW" ]; then
  pkill -x SpaceSynth 2>/dev/null; sleep 3
  LOG="logs/A1_retest_seed${SEED}_$(date +%Y%m%d_%H%M%S).log"
  SS_SPAWN_SEED="$SEED" open -n --stdout "$LOG" --stderr "$LOG" SpaceSynth.app
  echo "launched seed $SEED -> $LOG"
fi

echo "=== WATCH seed=$SEED log=$LOG start $(date '+%Y-%m-%d %H:%M:%S') ==="
el=0
while [ "$el" -lt "$CAP" ]; do
  sleep 30; el=$((el + 30))
  p=$(peak "$LOG")
  alive=$(pgrep -x SpaceSynth >/dev/null && echo up || echo DOWN)
  echo "[$(date '+%H:%M:%S')] +${el}s peak=$p app=$alive"
  [ "$alive" = "DOWN" ] && { echo "!!! instance died at +${el}s — run INVALID"; exit 2; }
  # >50.5 means a body crossed M_BH_SEED (50.0); heaviest IMF star is 49.957
  if awk -v v="$p" 'BEGIN{exit !(v>50.5)}'; then
    echo "=== CROSSED at +${el}s (peak=$p) — letting it run 90s to show direction ==="
    sleep 90
    break
  fi
done

echo ""
echo "=== RESULT seed=$SEED $(date '+%Y-%m-%d %H:%M:%S') ==="
echo "peak Mmax : $(peak "$LOG")"
echo "last GRAV : $(grep '^\[GRAV\] live=' "$LOG" | tail -1)"
echo "FPS range : $(grep -o 'FPS: [0-9]*' "$LOG" | awk '{print $2}' | sort -n | head -1) .. $(grep -o 'FPS: [0-9]*' "$LOG" | awk '{print $2}' | sort -n | tail -1)  (solo baseline ~69)"
pkill -x SpaceSynth 2>/dev/null
echo "=== END seed=$SEED ==="
