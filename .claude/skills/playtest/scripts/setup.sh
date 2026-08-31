#!/usr/bin/env bash
# Installs the playtest toolchain and imports the project. Idempotent: safe to
# re-run, skips whatever is already in place. Takes a few minutes on a cold
# container (~50 MB Godot download), seconds afterwards.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "== packages =="
missing=""
for pkg_bin in "xvfb:Xvfb" "imagemagick:import" "xdotool:xdotool" "unzip:unzip"; do
    pkg="${pkg_bin%%:*}"; bin="${pkg_bin##*:}"
    command -v "$bin" >/dev/null 2>&1 || missing="$missing $pkg"
done
if [ -n "$missing" ]; then
    echo "installing:$missing"
    apt-get install -y $missing >/dev/null 2>&1 || {
        apt-get update >/dev/null 2>&1 && apt-get install -y $missing >/dev/null 2>&1
    }
fi
for bin in Xvfb import xdotool unzip; do
    command -v "$bin" >/dev/null 2>&1 && echo "  ok: $bin" || echo "  MISSING: $bin"
done

echo "== godot $GODOT_VERSION =="
if [ ! -x "$GODOT" ]; then
    mkdir -p "$TOOLS_DIR"
    # Download the release ASSET, not the releases page. The HTML page is
    # blocked by the egress proxy (403) while the asset URL redirects to
    # release-assets.githubusercontent.com and works fine.
    url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    echo "downloading $url"
    curl -sL --max-time 600 -o "$TOOLS_DIR/godot.zip" "$url" || { echo "DOWNLOAD FAILED"; exit 1; }
    unzip -o -q "$TOOLS_DIR/godot.zip" -d "$TOOLS_DIR"
    chmod +x "$GODOT"
fi
"$GODOT" --version || { echo "GODOT NOT RUNNABLE"; exit 1; }

echo "== importing project at $PROJECT =="
# A cold clone has no .godot/ cache, and the first pass reports missing .ctex
# files while it builds them. A second pass then completes silently.
for attempt in 1 2; do
    timeout 300 xvfb-run -a "$GODOT" --headless --path "$PROJECT" --import \
        > "$OUT_DIR/import.log" 2>&1
    echo "  pass $attempt exit=$?"
done
grep -iE "^ERROR" "$OUT_DIR/import.log" | head -5
echo "== ready =="
