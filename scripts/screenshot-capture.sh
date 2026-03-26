#!/bin/bash
# Screenshot-to-Action: Capture phase
# Called by hotkey via Hammerspoon.
# Takes an interactive region screenshot, manages a 60s batching window,
# then hands off to the processing script.

# Source user environment (Hammerspoon launches with minimal PATH)
if [ -f "$HOME/.zprofile" ]; then source "$HOME/.zprofile" 2>/dev/null; fi
if [ -f "$HOME/.zshrc" ]; then source "$HOME/.zshrc" 2>/dev/null; fi
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

CAPTURE_DIR="/tmp/claude-screenshot-capture"
LOCK_FILE="$CAPTURE_DIR/.batch-timer-pid"

mkdir -p "$CAPTURE_DIR"

# Generate timestamped filename
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
FILEPATH="$CAPTURE_DIR/img-$TIMESTAMP.png"

# Take interactive region screenshot (crosshair selector)
screencapture -i "$FILEPATH"

# If user cancelled (pressed Escape), the file won't exist
if [ ! -f "$FILEPATH" ]; then
    exit 0
fi

# Notify user
osascript -e 'display notification "Processing in background..." with title "Screenshot Captured"'

# Kill any existing batch timer so we can reset the 60s window
if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE")
    kill "$OLD_PID" 2>/dev/null
fi

# Start a new 60-second timer in the background.
# When it fires, it runs the processing script.
# Note: sh -c 'echo $PPID' gets the subshell PID (macOS bash 3.2 lacks $BASHPID).
(
    sh -c 'echo $PPID' > "$LOCK_FILE"
    sleep 60
    {{INSTALL_DIR}}/screenshot-process.sh
) &

exit 0
