#!/bin/bash
# SHOW LAUNCH — 2026-07-13 15:02:00
# Jamal's call (2026-07-13 ~15:00): "we will not perform with a masked fake
# thing." NO masks. This launches the HONEST DEFAULT — the exact configuration
# he viewed and verdicted at 14:56–14:59 on 2026-07-13 (no blob, no lines;
# one open artifact: a small geometric cluster near the center star).
#
# The old 13:15 mask config (SS_PLAY_SKIP=dynfric + SS_SPH_SKIP=...) is GONE:
# dynfric was reworked honestly (`a178295`) and now CLEANS the field; the SPH
# stack runs with the density floor. docs/BUG_lines_2026-07-12.md has history.
#
# `open SpaceSynth.app` works too now (no env vars needed), but this script
# guarantees a clean single instance.
cd "$(dirname "$0")"
pkill -x SpaceSynth 2>/dev/null
sleep 1
./SpaceSynth.app/Contents/MacOS/SpaceSynth "$@"
