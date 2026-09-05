#!/usr/bin/env bash
# Acceptance test 1: Mario must survive standing still.
#
# Why this one matters: a previous change made the first Goomba active from
# level load, so it walked into Mario's spawn and killed him on a loop. Unit
# tests all passed and static screenshots looked fine -- only actually sitting
# in the level caught it.
#
# The HUD timer is the tell. It must decrease monotonically; if a sample reads
# HIGHER than the previous one the level reloaded, which means Mario died.
#
# Reads out a montage of the TIME digits for you to eyeball, since OCR here is
# more trouble than it is worth.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SAMPLES="${SAMPLES:-5}"
INTERVAL="${INTERVAL:-4}"

start_display
start_game "res://main.tscn"
sleep 11

if ! game_is_running; then
    echo "GAME EXITED EARLY - see $OUT_DIR/game.log"; show_errors; stop_all; exit 1
fi

# Deliberately send no input at all: this tests the level while idle.
for i in $(seq 1 "$SAMPLES"); do
    shot "idle$i.png"
    sleep "$INTERVAL"
done

stop_all

# Crop the TIME readout (top-right of a 1280x720 window) and stack the samples.
for i in $(seq 1 "$SAMPLES"); do
    convert "$OUT_DIR/idle$i.png" -crop 170x80+1080+40 +repage \
        -filter point -resize 170% "$OUT_DIR/t$i.png" 2>/dev/null
done
montage $(for i in $(seq 1 "$SAMPLES"); do echo "$OUT_DIR/t$i.png"; done) \
    -tile "${SAMPLES}x1" -geometry +4+4 -background gray20 "$OUT_DIR/times.png" 2>/dev/null

echo "TIME samples: $OUT_DIR/times.png"
echo "PASS if the numbers only ever go DOWN. Any jump UP means Mario died and"
echo "the stage reloaded -- that is a real gameplay regression, not a blip."
