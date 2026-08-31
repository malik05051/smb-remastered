#!/usr/bin/env bash
# Launch the game (or a test scene) and grab a screenshot.
#
#   run.sh                       -> main scene, one shot after 12s
#   run.sh res://test_foo.tscn   -> run a test scene instead
#   WAIT=20 SHOT=late.png run.sh -> control the delay and output name
#
# Startup takes ~10s under software GL, so WAIT below ~10 screenshots a black
# window rather than the game.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCENE="${1:-}"
WAIT="${WAIT:-12}"
SHOT="${SHOT:-shot.png}"

start_display
start_game "$SCENE"
sleep "$WAIT"

if game_is_running; then
    shot "$SHOT"
    echo "RUNNING - screenshot: $OUT_DIR/$SHOT"
else
    echo "GAME EXITED EARLY - see $OUT_DIR/game.log"
fi

show_errors
stop_all
