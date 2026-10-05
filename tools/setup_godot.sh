#!/bin/sh
set -eu
GRAVE_CACHE="$HOME/Library/Caches/GraveMaintenance"
mkdir -p "$GRAVE_CACHE"
if [ ! -x "$GRAVE_CACHE/Godot.app/Contents/MacOS/Godot" ]; then
    echo "Downloading official Godot 4.6.2 for macOS…"
    curl -L --fail -o "$GRAVE_CACHE/godot.zip" https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_macos.universal.zip
    unzip -q -o "$GRAVE_CACHE/godot.zip" -d "$GRAVE_CACHE"
    rm "$GRAVE_CACHE/godot.zip"
fi
echo "$GRAVE_CACHE/Godot.app/Contents/MacOS/Godot"
