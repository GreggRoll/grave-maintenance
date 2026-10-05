#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GRAVE_GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GRAVE_GODOT_BIN" ]; then
    GRAVE_GODOT_BIN="$(command -v godot || true)"
fi
if [ -z "$GRAVE_GODOT_BIN" ]; then
    for candidate in /Applications/Godot.app/Contents/MacOS/Godot /tmp/grave-godot/Godot.app/Contents/MacOS/Godot "$HOME/Library/Caches/GraveMaintenance/Godot.app/Contents/MacOS/Godot"; do
        if [ -x "$candidate" ]; then GRAVE_GODOT_BIN="$candidate"; break; fi
    done
fi
if [ -z "$GRAVE_GODOT_BIN" ]; then
    sh tools/setup_godot.sh
    GRAVE_GODOT_BIN="$HOME/Library/Caches/GraveMaintenance/Godot.app/Contents/MacOS/Godot"
fi
export GODOT_BIN="$GRAVE_GODOT_BIN"
if [ ! -f build/web/index.html ]; then sh tools/export_web.sh; fi
mkdir -p .runtime
GRAVE_CHILDREN=""
cleanup() {
    for grave_pid in $GRAVE_CHILDREN; do kill "$grave_pid" 2>/dev/null || true; done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
port_open() {
    python3 - "$1" <<'PY'
import socket,sys
try:
    with socket.create_connection(('127.0.0.1',int(sys.argv[1])),timeout=.3): pass
except OSError: sys.exit(1)
PY
}
if ! port_open 9080; then
    "$GRAVE_GODOT_BIN" --headless --path . -- --server > .runtime/server.log 2>&1 &
    GRAVE_CHILDREN="$GRAVE_CHILDREN $!"
fi
if ! port_open 8080; then
    python3 tools/serve.py > .runtime/web.log 2>&1 &
    GRAVE_CHILDREN="$GRAVE_CHILDREN $!"
fi
echo "Grave Maintenance: http://localhost:8080"
echo "Keep this terminal open while playing. Press Ctrl-C to stop services started here."
if [ "${GRAVE_NO_BROWSER:-0}" != "1" ]; then open http://localhost:8080; fi
while :; do sleep 30; done
