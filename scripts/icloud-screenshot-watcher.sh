#!/bin/bash
# iCloud Screenshot Watcher: Bridge for iOS Screenshot-to-Action
# Called by launchd when files appear in iCloud Drive/Agentic-screenshots/
# Moves images into /tmp/claude-screenshot-capture/ and triggers the
# existing processing pipeline with 60s batching.

# Source user environment (launchd launches with minimal PATH)
if [ -f "$HOME/.zprofile" ]; then source "$HOME/.zprofile" 2>/dev/null; fi
if [ -f "$HOME/.zshrc" ]; then source "$HOME/.zshrc" 2>/dev/null; fi
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Agentic-screenshots"
CAPTURE_DIR="/tmp/claude-screenshot-capture"
LOCK_FILE="$CAPTURE_DIR/.batch-timer-pid"
PROCESS_SCRIPT="{{INSTALL_DIR}}/screenshot-process.sh"

mkdir -p "$CAPTURE_DIR"

# Wait a moment for iCloud sync to finish writing the file
sleep 2

# Find all image files in the iCloud folder
IMAGES=($(ls -1t "$ICLOUD_DIR"/*.{png,jpg,jpeg,heic,PNG,JPG,JPEG,HEIC} 2>/dev/null))

if [ ${#IMAGES[@]} -eq 0 ]; then
    exit 0
fi

# Move each image to the capture directory with a timestamped name
for img in "${IMAGES[@]}"; do
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)-$(( RANDOM % 1000 ))
    EXTENSION="${img##*.}"
    mv "$img" "$CAPTURE_DIR/img-$TIMESTAMP.$EXTENSION"
done

# Notify user that phone screenshots were received
IMAGE_COUNT=${#IMAGES[@]}
if [ $IMAGE_COUNT -eq 1 ]; then
    osascript -e 'display notification "Processing in background..." with title "iPhone Screenshot Received"'
else
    osascript -e "display notification \"Processing $IMAGE_COUNT screenshots...\" with title \"iPhone Screenshots Received\""
fi

# Use the same batching logic as the hotkey capture script:
# Kill any existing batch timer, start a new 60s timer.
# This means if the user sends multiple screenshots from their phone
# within 60 seconds, they all get batched together — and they also
# batch with any Mac screenshots taken in the same window.
if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE")
    kill "$OLD_PID" 2>/dev/null
fi

(
    sh -c 'echo $PPID' > "$LOCK_FILE"
    sleep 60
    "$PROCESS_SCRIPT"
) &

exit 0
