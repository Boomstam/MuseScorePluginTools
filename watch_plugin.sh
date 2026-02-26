#!/bin/bash

PLUGIN_DIR="$(dirname "$0")"
RELOAD_SCRIPT="$PLUGIN_DIR/reload_musescore_plugin.sh"

echo "👀 Watching for changes in $PLUGIN_DIR..."

fswatch -e ".*" -i "\.qml$" "$PLUGIN_DIR" | while read -r event; do
    echo "🔄 Change detected: $event"
    bash "$RELOAD_SCRIPT"
done
