#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GRAVE_GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p build/web
"$GRAVE_GODOT_BIN" --headless --path . --editor --import --quit
"$GRAVE_GODOT_BIN" --headless --path . --export-release Web build/web/index.html
cp web/server.json build/web/server.json
