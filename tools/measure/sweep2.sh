#!/bin/bash
# Refined per-force sweep. Every config gets the IDENTICAL 3-part input:
#   1) single note (mono sculpt/breathing)   voices=1
#   2) chord (webbing, polyphony)             voices=3
#   3) accelerating arp (impulse/transients)  voices=1 rapid
# separated by silence so phases split on voices==0 boundaries. Full logs saved.
set -u
REPO="/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE"
SP="/private/tmp/claude-501/-Users-airy/3aa821de-1142-4ebe-8c51-69c232546d20/scratchpad"
BIN="$REPO/SpaceSynth.app/Contents/MacOS/SpaceSynth"
M="$SP/midinote"

cd "$REPO"
for cfg in NONE sculpt breathing swirl impulse web jitter; do
  pkill -9 -f SpaceSynth 2>/dev/null; sleep 1
  LOG="$SP/sweep2_${cfg}.log"; rm -f "$LOG"
  if [ "$cfg" = "NONE" ]; then "$BIN" > "$LOG" 2>&1 &
  else SS_PLAY_SKIP="$cfg" "$BIN" > "$LOG" 2>&1 & fi
  sleep 8
  echo "[$cfg] single..."; "$M" IAC hold 8 60 110 >/dev/null 2>&1;            sleep 2.5
  echo "[$cfg] chord...";  "$M" IAC hold 8 60,64,67 110 >/dev/null 2>&1;      sleep 2.5
  echo "[$cfg] arp...";    "$M" IAC arp 4 0.25 0.05 48,52,55,60,64,67,72,76,79,84 110 >/dev/null 2>&1
  sleep 1
done
pkill -9 -f SpaceSynth 2>/dev/null
echo "SWEEP2 DONE"
