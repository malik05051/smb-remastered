#!/usr/bin/env bash
# Acceptance test 2: Mario must make progress when actually played.
#
# Holds run+right and jumps periodically, grabbing a frame each time, then
# tiles them so you can see whether he advances through the level or is stuck
# dying near the spawn. Read the TIME in each frame as well: a value that jumps
# back UP means a death and stage reload.
#
# Input mapping (see project.godot): arrows move, S runs, Space jumps, E throws
# a fireball as Fire Mario.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FRAMES="${FRAMES:-6}"

start_display
start_game "res://main.tscn"
sleep 11

if ! game_is_running; then
    echo "GAME EXITED EARLY - see $OUT_DIR/game.log"; show_errors; stop_all; exit 1
fi

focus_game_window
sleep 1

xdotool keydown s
xdotool keydown Right
for i in $(seq 1 "$FRAMES"); do
    xdotool keydown space; sleep 0.35; xdotool keyup space
    sleep 1.4
    shot "pt$i.png"
done
xdotool keyup Right
xdotool keyup s

game_is_running && echo "STILL RUNNING (no crash)" || echo "CRASHED MID-PLAY"
show_errors
stop_all

for i in $(seq 1 "$FRAMES"); do
    convert "$OUT_DIR/pt$i.png" -resize 46% "$OUT_DIR/s$i.png" 2>/dev/null
done
montage $(for i in $(seq 1 "$FRAMES"); do echo "$OUT_DIR/s$i.png"; done) \
    -tile 2x -geometry +3+3 -background gray20 "$OUT_DIR/playthrough.png" 2>/dev/null
echo "frames: $OUT_DIR/playthrough.png"
