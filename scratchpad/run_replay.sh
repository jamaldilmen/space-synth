#!/bin/bash
# $1 = base name, $2 = take file (SS_REPLAY), $3 = SS_CAM_RHO, $4 = frames, $5 = SS_ORTHO (1|0), $6 = SS_WIDTH, $7 = SS_CAPTURE_SLICES ("" = single)
# No MIDI driver: the take file is applied by the app at frame = ceil(t*30). SS_FOV/SS_REF_HEIGHT/SS_LUM_CEIL from the environment.
cd "/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS" || exit 1
NAME=$1; TAKE=$2; RHO=$3; FRAMES=$4; ORTHO=$5; W=${6:-19644}; SLICES=${7-7152,5340,7152}
BASE=/Users/airy/Desktop/sweep/$NAME
rm -f "$BASE".log "$BASE"_*.mov "$BASE".mov 2>/dev/null
export SS_FOV=${SS_FOV:-45} SS_RENDER_FPS=30 SS_WIDTH=$W SS_HEIGHT=1680 SS_CAPTURE="$BASE" \
       SS_CAPTURE_FRAMES=$FRAMES SS_LENS_RENDER=1 SS_CAM_RHO=$RHO SS_ORTHO=$ORTHO SS_REPLAY="$TAKE"
[ -n "$SLICES" ] && export SS_CAPTURE_SLICES="$SLICES" || unset SS_CAPTURE_SLICES
T0=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
./SpaceSynth.app/Contents/MacOS/SpaceSynth 2>&1 \
  | perl -ne 'BEGIN{$|=1; use Time::HiRes qw(time)} printf "%.3f %s", time, $_' > "$BASE".log
T1=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
echo "WALL=$(echo "$T1 - $T0" | bc)s"
echo "replay: $(grep '\[REPLAY\] ARMED' "$BASE".log | cut -c1-200)"
echo "last: $(grep '\[CAPTURE\] frame' "$BASE".log | tail -1)"
