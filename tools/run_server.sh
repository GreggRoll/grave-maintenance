#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GRAVE_GODOT_BIN="${GODOT_BIN:-godot}"
exec "$GRAVE_GODOT_BIN" --headless --path . -- --server
