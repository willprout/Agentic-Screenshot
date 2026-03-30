#!/bin/bash

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="$HOME/.screenshot-to-action"
HAMMERSPOON_INIT="$HOME/.hammerspoon/init.lua"

echo ""
echo -e "${BOLD}Uninstalling Screenshot-to-Action...${NC}"
echo ""

# Remove installed scripts
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo -e "  ${GREEN}✓${NC} Removed $INSTALL_DIR"
else
    echo "  No install directory found at $INSTALL_DIR"
fi

# Remove Hammerspoon hotkey block
if [ -f "$HAMMERSPOON_INIT" ]; then
    if grep -q "BEGIN screenshot-to-action" "$HAMMERSPOON_INIT"; then
        sed -i '' '/-- BEGIN screenshot-to-action/,/-- END screenshot-to-action/d' "$HAMMERSPOON_INIT"
        echo -e "  ${GREEN}✓${NC} Removed hotkey from Hammerspoon config"

        # Reload Hammerspoon
        if command -v hs &>/dev/null; then
            hs -c "hs.reload()" 2>/dev/null || true
        elif [ -d "/Applications/Hammerspoon.app" ]; then
            open -g "hammerspoon://hs.reload" 2>/dev/null || true
        fi
        echo -e "  ${GREEN}✓${NC} Reloaded Hammerspoon"
    else
        echo "  No hotkey block found in Hammerspoon config"
    fi
fi

# Remove iOS bridge (launchd plist)
PLIST_NAME="com.user.screenshot-watcher"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
if [ -f "$PLIST_PATH" ]; then
    launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    echo -e "  ${GREEN}✓${NC} Removed iOS bridge (launchd watcher)"
fi

# Clean up temp files
rm -rf /tmp/claude-screenshot-capture
rm -f /tmp/claude-screenshot-result.txt
rm -f /tmp/screenshot-watcher.log
echo -e "  ${GREEN}✓${NC} Cleaned up temp files"

echo ""
echo -e "${GREEN}${BOLD}Uninstalled.${NC} Hammerspoon and Claude CLI were left in place."
echo -e "  ${DIM}Note: The iCloud Drive/Agentic-screenshots/ folder was left in place.${NC}"
echo ""
