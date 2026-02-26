#!/bin/bash

RECENT_FILES="$HOME/Library/Application Support/MuseScore/MuseScore4/recent_files.json"

# Parse the most recent file path from recent_files.json
LAST_FILE=$(python3 -c "
import json
with open('$RECENT_FILES') as f:
    data = json.load(f)
if isinstance(data, list) and len(data) > 0:
    print(data[0].replace('\\/', '/'))
" 2>/dev/null)

if pgrep -x "mscore" > /dev/null; then
    echo "🛑 Stopping MuseScore 4..."
    pkill -x "mscore"
    for i in {1..10}; do
        sleep 1
        if ! pgrep -x "mscore" > /dev/null; then break; fi
        if [ "$i" -eq 10 ]; then
            echo "⚠️  Force-killing..."
            pkill -9 -x "mscore"
            sleep 1
        fi
    done
    echo "✅ MuseScore stopped."
else
    echo "ℹ️  MuseScore was not running."
fi

echo "🚀 Launching MuseScore 4..."
if [ -n "$LAST_FILE" ] && [ -f "$LAST_FILE" ]; then
    echo "📄 Reopening: $LAST_FILE"
    open -a "/Applications/MuseScore 4.app" "$LAST_FILE"
else
    echo "ℹ️  No recent file found, opening normally."
    open -a "/Applications/MuseScore 4.app"
fi
echo "✅ Done!"
