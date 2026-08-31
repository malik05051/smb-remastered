#!/usr/bin/env bash
# Shared setup for every playtest script. Source this, don't run it.

set -uo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.3-stable}"
TOOLS_DIR="${TOOLS_DIR:-/tmp/godot-playtest}"
GODOT="${GODOT:-$TOOLS_DIR/Godot_v${GODOT_VERSION}_linux.x86_64}"
OUT_DIR="${OUT_DIR:-$TOOLS_DIR/out}"
DISPLAY_NUM="${DISPLAY_NUM:-99}"
WINDOW="${WINDOW:-1280x720}"

# Repo root: this file lives at <repo>/.claude/skills/playtest/scripts/lib.sh
PROJECT="${PROJECT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"

mkdir -p "$OUT_DIR"

# Vulkan is not available under Xvfb, and llvmpipe gives us software GL.
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

_XVFB_PID=""
_GODOT_PID=""

start_display() {
    # pkill -f Xvfb would also match this script's own command line and kill the
    # calling shell, so match the executable name exactly instead.
    pkill -x Xvfb 2>/dev/null
    sleep 1
    Xvfb ":$DISPLAY_NUM" -screen 0 "${WINDOW}x24" >/dev/null 2>&1 &
    _XVFB_PID=$!
    export DISPLAY=":$DISPLAY_NUM"
    sleep 3
}

# start_game [scene]  -- omit the scene to run the project's main scene.
start_game() {
    local scene="${1:-}"
    # opengl3 is required: the default Vulkan driver cannot initialise under
    # Xvfb and Godot exits immediately.
    "$GODOT" --path "$PROJECT" --rendering-driver opengl3 $scene \
        > "$OUT_DIR/game.log" 2>&1 &
    _GODOT_PID=$!
}

game_is_running() { kill -0 "$_GODOT_PID" 2>/dev/null; }

focus_game_window() {
    local wid
    wid=$(xdotool search --name "." 2>/dev/null | tail -1)
    [ -n "$wid" ] && { xdotool windowfocus "$wid" 2>/dev/null; xdotool windowactivate "$wid" 2>/dev/null; }
}

shot() { import -window root "$OUT_DIR/$1" 2>/dev/null; }

stop_all() {
    [ -n "$_GODOT_PID" ] && kill "$_GODOT_PID" 2>/dev/null
    sleep 1
    pkill -x Xvfb 2>/dev/null
}

# Surface real problems; the ALSA/pulse noise is just the container having no
# sound card and is never the cause of a failure.
show_errors() {
    echo "--- script errors ---"
    grep -iE "SCRIPT ERROR|Parse Error|Nonexistent|Invalid (access|call|assignment)" \
        "$OUT_DIR/game.log" | head -20
    echo "--- (nothing above means the run was clean) ---"
}
