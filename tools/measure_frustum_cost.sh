#!/bin/bash
# measure_frustum_cost.sh — what does a SECOND and THIRD wall actually cost?
# 2026-08-31. Answers the question that gates the three-frustum build.
#
# METHOD — nothing new is built. The gate already exists and was written for
# this exact question (renderer.mm:4199): SS_NO_STARPASS=1 skips encoding the
# star pass entirely, so
#     (Render+PostFX WITH) - (WITHOUT) = the whole star pass, vertex + raster.
# Three frustums re-run that pass three times; physics runs ONCE regardless.
# So  frame_cost(3 walls) ~= base + 3 x starpass  is measurable TODAY, without
# writing the frustum path first.
#
# RESOLUTIONS are the venue's real numbers (tech, 2026-08-29 01:20), not a
# convenient smaller stand-in:
#     front wall 5340 x 1680   side wall 7152 x 1680  (x2)
# SS_WIDTH/SS_HEIGHT pin the DRAWABLE, not the window (board row S1), so these
# are exact pixel counts.
# NOTE: his 2026-08-30 order rejected SHRINKING the window to buy frame rate.
# This grows it to the real target. Opposite direction, same rule respected.
#
# DISCIPLINE (his rules, enforced below, not just documented):
#   - power state PINNED first: refuses to run on battery      [pin_the_power_state]
#   - arms INTERLEAVED and pair order ALTERNATED, never all-of-one-then-other
#   - >=4 runs per arm stacked                                  [stack_4_runs]
#   - warm-up frames discarded; the AVERAGE is the evidence     [trust_the_average]
#   - ONE live app: every arm kills the previous instance first [one_live_app]

set -u
APP="$(cd "$(dirname "$0")/.." && pwd)/SpaceSynth.app"
OUT="${OUT_DIR:-/tmp}/frustum_cost_$(date +%Y%m%d_%H%M%S)"
RUNS="${RUNS:-4}"          # runs per arm
SECS="${SECS:-25}"         # seconds per run (>= 2 PROFILE windows after warmup)
WARM="${WARM:-3}"          # leading [PROFILE/120f] lines discarded

mkdir -p "$OUT"

# ── POWER GATE — his rule: pin the power state before measuring ─────────────
pw=$(pmset -g ps | head -1)
batt=$(pmset -g batt | grep -o '[0-9]*%' | head -1 | tr -d '%')
if ! echo "$pw" | grep -qi "AC Power"; then
  echo "⛔ REFUSING TO MEASURE: on battery ($pw, ${batt}%)."
  echo "   Low Power Mode / discharge moves fps ~3x. Plug in, then re-run."
  echo "   Override only if you know why:  FORCE=1 $0"
  [ "${FORCE:-0}" = "1" ] || exit 2
fi
echo "power: $pw  battery ${batt}%  powermode $(pmset -g | awk '/powermode/{print $2}')"

run_arm () {                        # $1=label $2=W $3=H $4=starpass(on|off)
  local label="$1" W="$2" H="$3" sp="$4"
  pkill -x SpaceSynth 2>/dev/null; sleep 1     # ONE LIVE APP
  local log="$OUT/${label}.log"
  if [ "$sp" = "off" ]; then
    open -n "$APP" --env SS_WIDTH="$W" --env SS_HEIGHT="$H" --env SS_NO_STARPASS=1 \
      --stdout "$log" --stderr "$log.err"
  else
    open -n "$APP" --env SS_WIDTH="$W" --env SS_HEIGHT="$H" \
      --stdout "$log" --stderr "$log.err"
  fi
  sleep "$SECS"
  pkill -x SpaceSynth 2>/dev/null; sleep 1
  # Render+PostFX avg is field 9 of [PROFILE/120f]; drop the warm-up windows.
  awk -v w="$WARM" '/PROFILE\/120f/{n++; if(n>w){ for(i=1;i<=NF;i++) if($i=="Render+PostFX"){print $(i+2); break} }}' \
      "$log" > "$OUT/${label}.rend"
  local n avg
  n=$(wc -l < "$OUT/${label}.rend" | tr -d ' ')
  avg=$(awk '{s+=$1} END{if(NR)printf "%.3f", s/NR; else print "NaN"}' "$OUT/${label}.rend")
  echo "  $label  W=${W}x${H} starpass=$sp  windows=$n  Render+PostFX avg=${avg} ms"
  echo "$label $W $H $sp $n $avg" >> "$OUT/summary.txt"
}

echo "=== INTERLEAVED, $RUNS runs per arm, ${SECS}s each, warmup ${WARM} windows ==="
for i in $(seq 1 "$RUNS"); do
  echo "-- round $i --"
  # alternate the within-pair order each round so thermal drift cannot
  # systematically favour one arm
  if [ $((i % 2)) -eq 1 ]; then
    run_arm "front_on_r$i"  5340 1680 on
    run_arm "front_off_r$i" 5340 1680 off
    run_arm "side_on_r$i"   7152 1680 on
    run_arm "side_off_r$i"  7152 1680 off
  else
    run_arm "front_off_r$i" 5340 1680 off
    run_arm "front_on_r$i"  5340 1680 on
    run_arm "side_off_r$i"  7152 1680 off
    run_arm "side_on_r$i"   7152 1680 on
  fi
done

echo
echo "=== RESULT ==="
awk '{split($1,a,"_"); key=a[1]"_"a[2]; s[key]+=$6; c[key]++}
     END{for(k in s) printf "  %-12s mean %.3f ms  (n=%d)\n", k, s[k]/c[k], c[k]}' \
    "$OUT/summary.txt" | sort
echo
awk '{split($1,a,"_"); key=a[1]"_"a[2]; s[key]+=$6; c[key]++}
     END{
       fo=s["front_on"]/c["front_on"]; ff=s["front_off"]/c["front_off"];
       so=s["side_on"]/c["side_on"];   sf=s["side_off"]/c["side_off"];
       printf "  star pass, FRONT wall (5340x1680): %.3f ms\n", fo-ff;
       printf "  star pass, SIDE  wall (7152x1680): %.3f ms\n", so-sf;
       printf "\n  THREE WALLS = base + front + 2*side star passes\n";
       printf "  extra over ONE front wall today: %.3f ms/frame\n", (so-sf)*2;
       printf "  budget: 16.67 ms at 60 fps, 33.3 ms at 30 fps\n";
     }' "$OUT/summary.txt"
echo
echo "raw logs: $OUT"
