#!/bin/bash
# Isolation ladder -- launch the app under a chosen env bed, wait for the
# SS_DUMP position dump BY FILE EXISTENCE (never wall-clock: sleeps stretch
# by hours on this Mac), kill, probe with tools/zprobe.py.
# Ported from the 2026-07-14 carver-#0 scratchpad ladder.
#
# Usage:
#   tools/ladder.sh                          # default rung set (tick 2)
#   tools/ladder.sh NAME ENV=V [ENV=V ...]   # one custom rung
# Env:
#   SS_LADDER_DIR   where dumps go (required if TMPDIR-less; keep off-repo)
#   SS_LADDER_TICK  dump tick (default 2; tick 12 = the pancake epoch)
#   SS_LADDER_PROBE extra args for zprobe.py, e.g. "--centers 1.2,3.4"
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
S="${SS_LADDER_DIR:-${TMPDIR:-/tmp}/ss-ladder}"
TICK="${SS_LADDER_TICK:-2}"
mkdir -p "$S"
cd "$REPO"

probe() {
  # shellcheck disable=SC2086
  python3 "$REPO/tools/zprobe.py" "$1" ${SS_LADDER_PROBE:-}
}

rung() {
  local name="$1"; shift
  local dump="$S/ladder_${name}_t${TICK}.bin"
  rm -f "$dump"
  pkill -x SpaceSynth 2>/dev/null; sleep 1
  # caffeinate: display sleep killed unattended runs before (07-12 postmortem)
  env "$@" SS_DUMP="$dump" SS_DUMP_TICK="$TICK" \
    caffeinate -di ./SpaceSynth.app/Contents/MacOS/SpaceSynth >/dev/null 2>&1 &
  local n=0
  until [ -s "$dump" ] || [ $n -ge 200 ]; do sleep 3; n=$((n+1)); done
  pkill -x SpaceSynth 2>/dev/null
  if [ -s "$dump" ]; then echo "RUNG $name (tick $TICK):"; probe "$dump"
  else echo "RUNG $name: NO DUMP (timeout)"; fi
}

if [ $# -gt 0 ]; then
  name="$1"; shift
  rung "$name" "$@"
else
  rung inert        SS_INERT=1
  rung pm_only      SS_INERT=1 SS_INERT_KEEP=pm
  rung fieldgrav    SS_INERT=1 SS_INERT_KEEP=fieldgrav
  rung grav_stack   SS_INERT=1 SS_INERT_KEEP=pm,fieldgrav,substep,relax
  rung default_bed  SS_NOOP=1
fi
echo "LADDER DONE"
