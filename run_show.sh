#!/bin/bash
# SHOW LAUNCH — 2026-07-12 13:20:48
# Reproduces the configuration Jamal called "good enough for now" (2026-07-12
# ~13:15): the straight-line/slice artifact is at its shallowest and the field
# collapses cleanly at rest. `open SpaceSynth.app` does NOT pass env vars —
# always launch through this script for the show.
#
# What the flags do (docs/BUG_lines_2026-07-12.md has the full story):
#   SS_PLAY_SKIP=dynfric  — gates the UNGATED Chandrasekhar dynamical-friction
#                           block (the deepest lane-carver found 2026-07-12)
#   SS_SPH_SKIP=density,pressure,force,merge — SPH kernels + merge_stars off
#                           (diagnostic mask kept for the show; NOT a fix)
cd "$(dirname "$0")"
pkill -f SpaceSynth.app/Contents/MacOS/SpaceSynth 2>/dev/null
sleep 1
SS_PLAY_SKIP=dynfric SS_SPH_SKIP=density,pressure,force,merge \
  ./SpaceSynth.app/Contents/MacOS/SpaceSynth "$@"
