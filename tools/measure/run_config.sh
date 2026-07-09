#!/bin/bash
# run_config.sh <cfg>   — one config: launch, hide HUD, turn 90°, play the
# 3-part input (single 16s / chord 16s / accel arp), screenshot each phase at
# its evolved state, save full [SHAPE]/[VEL] log. cfg=NONE => no skip.
set -u
cfg="$1"
REPO="/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE"
SP="/private/tmp/claude-501/-Users-airy/3aa821de-1142-4ebe-8c51-69c232546d20/scratchpad"
BIN="$REPO/SpaceSynth.app/Contents/MacOS/SpaceSynth"; M="$SP/midinote"
cd "$REPO"
pkill -9 -f SpaceSynth 2>/dev/null; sleep 1
LOG="$SP/run_${cfg}.log"; rm -f "$LOG"
if [ "$cfg" = "NONE" ]; then "$BIN" > "$LOG" 2>&1 &
else SS_PLAY_SKIP="$cfg" "$BIN" > "$LOG" 2>&1 & fi
sleep 8
osascript -e 'tell application "System Events" to set frontmost of first process whose name contains "SpaceSynth" to true' >/dev/null 2>&1
sleep 0.5
osascript -e 'tell application "System Events" to key code 48'  >/dev/null 2>&1   # TAB HUD off
sleep 0.3
osascript -e 'tell application "System Events" to key code 124' >/dev/null 2>&1   # 90° right
sleep 0.3
shot(){ WID=$("$SP/winid" SpaceSynth); screencapture -x -o -l"$WID" "$SP/shot_${cfg}_$1.png" 2>/dev/null; echo "  shot $1 -> $?"; }

echo "[$cfg] single 16s"; "$M" IAC hold 16 60 110 >/dev/null 2>&1 & sleep 14; shot single; sleep 3
echo "[$cfg] chord 16s";  "$M" IAC hold 16 60,64,67 110 >/dev/null 2>&1 & sleep 14; shot chord; sleep 3
echo "[$cfg] arp";        "$M" IAC arp 5 0.28 0.05 48,52,55,60,64,67,72,76,79,84 110 >/dev/null 2>&1 & sleep 5; shot arp; sleep 4
pkill -9 -f SpaceSynth 2>/dev/null
echo "[$cfg] done. shots: $(ls -1 $SP/shot_${cfg}_*.png 2>/dev/null | wc -l | tr -d ' ')"
