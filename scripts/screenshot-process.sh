#!/bin/bash
# Screenshot-to-Action: Processing phase
# Called by the batch timer in screenshot-capture.sh after 60s of inactivity.
# Collects all pending screenshots, sends them to Claude for classification,
# and shows a notification with the result.

# Source user environment (Hammerspoon launches with minimal PATH)
if [ -f "$HOME/.zprofile" ]; then source "$HOME/.zprofile" 2>/dev/null; fi
if [ -f "$HOME/.zshrc" ]; then source "$HOME/.zshrc" 2>/dev/null; fi
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

CAPTURE_DIR="/tmp/claude-screenshot-capture"
LOCK_FILE="$CAPTURE_DIR/.batch-timer-pid"
PROMPT_FILE="{{INSTALL_DIR}}/screenshot-agent-prompt.md"
RESULT_FILE="/tmp/claude-screenshot-result.txt"
CLAUDE_BIN="{{CLAUDE_BIN}}"
MCP_CONFIG="{{INSTALL_DIR}}/mcp.json"

# Clean up lock file
rm -f "$LOCK_FILE"

# Collect all pending screenshots
IMAGES=($(ls -1t "$CAPTURE_DIR"/img-*.png 2>/dev/null))

if [ ${#IMAGES[@]} -eq 0 ]; then
    exit 0
fi

IMAGE_COUNT=${#IMAGES[@]}

# Read the agent prompt
AGENT_PROMPT=$(cat "$PROMPT_FILE")

# Build the user message with image paths embedded so Claude's Read tool
# can open them.
if [ $IMAGE_COUNT -eq 1 ]; then
    USER_MSG="Process this screenshot and take the appropriate action.

Screenshot: ${IMAGES[0]}"
else
    USER_MSG="Process these $IMAGE_COUNT screenshots. They were captured within the last few minutes. Assess whether any are related and act accordingly.

Screenshots:"
    for img in "${IMAGES[@]}"; do
        USER_MSG="$USER_MSG
- $img"
    done
fi

# Add explicit instruction to read the images
USER_MSG="$USER_MSG

IMPORTANT: Start by using the Read tool to view each screenshot image file above, then decide what action to take."

# Invoke Claude CLI in non-interactive mode.
"$CLAUDE_BIN" -p "$USER_MSG" \
    --system-prompt "$AGENT_PROMPT" \
    --dangerously-skip-permissions \
    --mcp-config "$MCP_CONFIG" \
    --output-format text \
    > "$RESULT_FILE" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    # Extract the summary lines
    SUMMARY=$(grep -E "^(CALENDAR|TRELLO):" "$RESULT_FILE" | head -5)
    ACTION_COUNT=$(echo "$SUMMARY" | grep -c ".")

    if [ -n "$SUMMARY" ]; then
        SHORT_SUMMARY=$(echo "$SUMMARY" | head -3 | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')
        osascript -e "display notification \"$SHORT_SUMMARY\" with title \"Created $ACTION_COUNT item(s)\""
    else
        osascript -e 'display notification "Processed but no actions taken" with title "Screenshot Agent"'
    fi
else
    # Processing failed — create a fallback Trello card with the screenshots.
    FALLBACK_IMG_LIST=""
    for img in "${IMAGES[@]}"; do
        FALLBACK_IMG_LIST="$FALLBACK_IMG_LIST
- $img"
    done
    FALLBACK_MSG="First call set_active_board with '{{TRELLO_BOARD_NAME}}', then get_lists to find the {{TRELLO_TARGET_LIST}} list, then create a Trello card titled 'Failed to process screenshot' with description 'Automated screenshot processing failed. Review attached images.' Then read each image file below and attach it to the card using attach_image_to_card.

Images:$FALLBACK_IMG_LIST"

    "$CLAUDE_BIN" -p "$FALLBACK_MSG" \
        --dangerously-skip-permissions \
        --mcp-config "$MCP_CONFIG" \
        --output-format text \
        > /dev/null 2>&1

    osascript -e 'display notification "Created fallback Trello card with screenshots" with title "Screenshot Processing Failed"'
fi

# Clean up processed screenshots
rm -f "$CAPTURE_DIR"/img-*.png

exit 0
