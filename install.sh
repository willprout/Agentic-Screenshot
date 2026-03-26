#!/bin/bash
set -e

# ─── Colors ──────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="$HOME/.screenshot-to-action"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo -e "${BOLD}Screenshot-to-Action Installer${NC}"
echo -e "${DIM}Ctrl+Opt+Z → screenshot → Trello card or Calendar event${NC}"
echo ""

# ─── Prerequisites ───────────────────────────────────────
echo -e "${BOLD}Checking prerequisites...${NC}"

# macOS check
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This tool only works on macOS.${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} macOS"

# Claude CLI check
CLAUDE_BIN=$(which claude 2>/dev/null || true)
if [ -z "$CLAUDE_BIN" ]; then
    echo -e "  ${RED}✗${NC} Claude CLI not found"
    echo ""
    echo "  Install Claude Code: https://docs.anthropic.com/en/docs/claude-code/overview"
    echo "  Then re-run this installer."
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Claude CLI ($CLAUDE_BIN)"

# Hammerspoon check
if ! command -v hs &>/dev/null && [ ! -d "/Applications/Hammerspoon.app" ]; then
    echo -e "  ${YELLOW}!${NC} Hammerspoon not found"
    read -p "  Install Hammerspoon via Homebrew? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        brew install --cask hammerspoon
        echo -e "  ${GREEN}✓${NC} Hammerspoon installed"
        echo ""
        echo -e "  ${YELLOW}Important:${NC} Open Hammerspoon.app and grant Accessibility permissions"
        echo "  (System Settings → Privacy & Security → Accessibility → Hammerspoon)"
        read -p "  Press Enter when done..."
    else
        echo -e "${RED}Hammerspoon is required for the global hotkey. Exiting.${NC}"
        exit 1
    fi
else
    echo -e "  ${GREEN}✓${NC} Hammerspoon"
fi

echo ""

# ─── Trello Setup ────────────────────────────────────────
echo -e "${BOLD}Trello Configuration${NC}"
echo ""
echo "  You need a Trello API key and token to connect your board."
echo ""
echo "  Step 1: Go to https://trello.com/power-ups/admin"
echo "          Click 'New' to create a Power-Up (name it anything)."
echo "          Copy the API Key from the Power-Up's API Key section."
echo ""
read -p "  Trello API Key: " TRELLO_API_KEY

echo ""
echo "  Step 2: Visit this URL to generate a token:"
echo "  https://trello.com/1/authorize?expiration=never&scope=read,write&response_type=token&key=${TRELLO_API_KEY}"
echo ""
read -p "  Trello Token: " TRELLO_TOKEN

echo ""
read -p "  Trello board name (exact): " TRELLO_BOARD_NAME
TRELLO_BOARD_NAME="${TRELLO_BOARD_NAME:-My To Do List}"

read -p "  List for new cards (default: Proposed): " TRELLO_TARGET_LIST
TRELLO_TARGET_LIST="${TRELLO_TARGET_LIST:-Proposed}"

echo ""

# ─── Calendar Setup ──────────────────────────────────────
echo -e "${BOLD}Google Calendar Configuration${NC}"
echo ""
echo "  The agent routes events to different calendars based on context."
echo "  You need Claude's Google Calendar MCP connector enabled."
echo "  (Enable at: https://claude.ai/settings/integrations)"
echo ""

read -p "  Work calendar ID (e.g. you@company.com): " WORK_CALENDAR_ID

read -p "  Personal calendar ID (or 'skip' for work-only): " PERSONAL_CALENDAR_ID
if [ "$PERSONAL_CALENDAR_ID" = "skip" ] || [ -z "$PERSONAL_CALENDAR_ID" ]; then
    PERSONAL_CALENDAR_ID="$WORK_CALENDAR_ID"
    echo -e "  ${DIM}Using work calendar for all events.${NC}"
fi

echo ""

# ─── Hotkey Setup ────────────────────────────────────────
echo -e "${BOLD}Hotkey Configuration${NC}"
echo ""
echo "  Default: Ctrl+Opt+Z"
read -p "  Use default? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "  Enter modifiers separated by commas (options: ctrl, alt, cmd, shift)"
    read -p "  Modifiers: " HOTKEY_MODS_RAW
    read -p "  Key: " HOTKEY_KEY
    # Format for Hammerspoon: {"ctrl", "alt"} etc
    HOTKEY_MODS=$(echo "$HOTKEY_MODS_RAW" | sed 's/[, ]*/", "/g; s/^/{"/' | sed 's/$/"}/; s/""/"/g')
    HOTKEY_DESC="$HOTKEY_MODS_RAW+$HOTKEY_KEY"
else
    HOTKEY_MODS='{"ctrl", "alt"}'
    HOTKEY_KEY="z"
    HOTKEY_DESC="Ctrl+Opt+Z"
fi

echo ""

# ─── Install ─────────────────────────────────────────────
echo -e "${BOLD}Installing to $INSTALL_DIR ...${NC}"

mkdir -p "$INSTALL_DIR"

# Write mcp.json for Trello
cat > "$INSTALL_DIR/mcp.json" << MCPEOF
{
  "mcpServers": {
    "trello": {
      "command": "npx",
      "args": ["-y", "@delorenj/mcp-server-trello"],
      "env": {
        "TRELLO_API_KEY": "$TRELLO_API_KEY",
        "TRELLO_TOKEN": "$TRELLO_TOKEN"
      }
    }
  }
}
MCPEOF

# Copy and templatize scripts
for file in screenshot-capture.sh screenshot-process.sh screenshot-agent-prompt.md; do
    sed \
        -e "s|{{INSTALL_DIR}}|$INSTALL_DIR|g" \
        -e "s|{{CLAUDE_BIN}}|$CLAUDE_BIN|g" \
        -e "s|{{WORK_CALENDAR_ID}}|$WORK_CALENDAR_ID|g" \
        -e "s|{{PERSONAL_CALENDAR_ID}}|$PERSONAL_CALENDAR_ID|g" \
        -e "s|{{TRELLO_BOARD_NAME}}|$TRELLO_BOARD_NAME|g" \
        -e "s|{{TRELLO_TARGET_LIST}}|$TRELLO_TARGET_LIST|g" \
        "$SCRIPT_DIR/scripts/$file" > "$INSTALL_DIR/$file"
done

chmod +x "$INSTALL_DIR/screenshot-capture.sh"
chmod +x "$INSTALL_DIR/screenshot-process.sh"

# Set up Hammerspoon hotkey
HAMMERSPOON_DIR="$HOME/.hammerspoon"
HAMMERSPOON_INIT="$HAMMERSPOON_DIR/init.lua"
mkdir -p "$HAMMERSPOON_DIR"

# Remove old screenshot-to-action block if present
if [ -f "$HAMMERSPOON_INIT" ]; then
    sed -i '' '/-- BEGIN screenshot-to-action/,/-- END screenshot-to-action/d' "$HAMMERSPOON_INIT"
fi

# Append new hotkey binding
cat >> "$HAMMERSPOON_INIT" << HSEOF

-- BEGIN screenshot-to-action
-- Screenshot-to-Action: $HOTKEY_DESC triggers region screenshot capture
hs.hotkey.bind($HOTKEY_MODS, "$HOTKEY_KEY", function()
    hs.task.new("/bin/bash", nil, {"$INSTALL_DIR/screenshot-capture.sh"}):start()
end)
-- END screenshot-to-action
HSEOF

# Reload Hammerspoon
if command -v hs &>/dev/null; then
    hs -c "hs.reload()" 2>/dev/null || true
elif [ -d "/Applications/Hammerspoon.app" ]; then
    open -g "hammerspoon://hs.reload" 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo "  Hotkey:    $HOTKEY_DESC"
echo "  Scripts:   $INSTALL_DIR/"
echo "  Board:     $TRELLO_BOARD_NAME → $TRELLO_TARGET_LIST list"
echo "  Work cal:  $WORK_CALENDAR_ID"
echo "  Personal:  $PERSONAL_CALENDAR_ID"
echo ""
echo -e "  ${BOLD}Try it now:${NC} Press $HOTKEY_DESC to capture a screenshot."
echo ""
echo "  To customize actions, edit: $INSTALL_DIR/screenshot-agent-prompt.md"
echo "  To uninstall: $(dirname "$0")/uninstall.sh"
echo ""
