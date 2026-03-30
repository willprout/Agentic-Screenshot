# Agentic Screenshot

A macOS tool that turns screenshots into actions. Press a hotkey (or share from your iPhone), and an AI agent automatically creates Trello cards or Google Calendar events based on what it sees.

**Press a hotkey. Select a region. Go back to work.** A notification tells you what was created.

## How It Works

```
                    +------------------+
                    |   Mac: Hotkey    |     iPhone: Share Sheet
                    |  (Ctrl+Opt+Z)   |     via iOS Shortcut
                    +--------+---------+          |
                             |                    |
                      screencapture -i      iCloud Drive sync
                             |                    |
                             v                    v
                    /tmp/claude-screenshot-capture/
                    (images accumulate here)
                             |
                      60-second batch window
                      (groups rapid captures)
                             |
                             v
                    +------------------+
                    |   Claude Vision  |
                    |   (claude -p)    |
                    +--------+---------+
                             |
              +--------------+--------------+
              |              |              |
        Event/Meeting   Task/Request   Informational
              |              |              |
              v              v              v
        Google Calendar  Trello Card   Trello Card
        (work or personal) (with label)  (reference)
```

1. **Capture** -- Hotkey triggers macOS screen capture (crosshair region selector), or iPhone shares via iCloud Drive
2. **Batch** -- Multiple captures within 60 seconds are grouped together
3. **Classify** -- Claude vision analyzes the screenshot(s) and decides the action type
4. **Act** -- Creates the item via MCP tools, shows a macOS notification with the result

If multiple screenshots are captured in a batch, the agent uses judgment to determine if they're related (combining into one action) or independent (separate actions).

## Prerequisites

- **macOS** (uses native `screencapture` and `launchd`)
- **[Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code/overview)** with an active Claude plan
- **Claude MCP connectors** enabled for:
  - [Google Calendar](https://claude.ai/settings/integrations) -- for creating events
  - Trello -- configured during install (API key + token)
- **[Hammerspoon](https://www.hammerspoon.org/)** -- for global hotkey binding (installed automatically if needed)
- **Node.js / npm** -- for the Trello MCP server (`npx`)

## Install

```bash
git clone https://github.com/willprout/Agentic-Screenshot.git
cd Agentic-Screenshot
./install.sh
```

The installer walks you through everything interactively:

1. **Prerequisites** -- checks for Claude CLI, installs Hammerspoon if needed
2. **Trello API** -- step-by-step walkthrough to get your API key and token
3. **Google Calendar** -- configure work and personal calendar IDs
4. **Hotkey** -- choose your hotkey (default: Ctrl+Opt+Z)
5. **iOS Bridge** (optional) -- sets up iCloud folder watcher for iPhone screenshots

All scripts are installed to `~/.screenshot-to-action/`.

## Usage

### Mac: Hotkey

Press your hotkey (default **Ctrl+Opt+Z**). A crosshair appears -- drag to select a region.

- Immediately: **"Screenshot Captured"** notification
- After 60 seconds of inactivity: **"Created N item(s)"** notification with details

### iPhone: Share Sheet

> Requires enabling the iOS bridge during install.

1. **One-time setup** -- Create an iOS Shortcut on your iPhone:
   - **Receive:** Share Sheet input (Images)
   - **Action:** Save File to `iCloud Drive/Agentic-screenshots/` (disable "Ask Where to Save")
   - **Optional:** Play Haptic feedback (Success)
   - Name it "Screenshot to Action" and enable "Show in Share Sheet"

2. **Usage** -- Take a screenshot on your phone, open Share Sheet, tap "Screenshot to Action"
   - The image syncs to your Mac via iCloud Drive
   - A `launchd` watcher detects the new file and feeds it into the same pipeline
   - You get the same macOS notification when processing completes

iPhone and Mac screenshots share the same batch window, so screenshots from both sources taken within 60 seconds are processed together.

### Batching

Take multiple screenshots within 60 seconds and they'll be processed together. The agent determines if they're related (e.g., a Slack message and the calendar it references -> one calendar event with context) or independent (separate actions for each).

### Error Handling

If processing fails, a Trello card titled "Failed to process screenshot" is created with the screenshot(s) attached. Nothing is ever silently lost.

## What the Agent Creates

| Screenshot contains | Action | Destination |
|---|---|---|
| Meeting invite, date, event | Google Calendar event | Work or personal calendar |
| Task, request, action item | Trello card with label | Work (blue), Personal (green), or Errands (orange) |
| Receipt, confirmation, reference | Trello card (no due date) | Informational reference |

The agent extracts titles, dates, times, descriptions, and context from the screenshot content. For multi-image batches, it synthesizes related screenshots into single, richer actions.

## Customization

After install, edit `~/.screenshot-to-action/screenshot-agent-prompt.md` to:

- Add new action types (see [examples/custom-actions.md](examples/custom-actions.md))
- Change Trello label names or add new ones
- Adjust calendar routing rules
- Modify the agent's classification behavior

## Architecture

```
~/.screenshot-to-action/
  screenshot-capture.sh        # Hotkey target: takes screenshot, manages batch timer
  screenshot-process.sh        # Invokes Claude with pending screenshots
  screenshot-agent-prompt.md   # Vision agent classification rules
  icloud-screenshot-watcher.sh # iOS bridge: moves iCloud images into pipeline
  mcp.json                     # Trello MCP server config (generated at install)

~/.hammerspoon/init.lua        # Global hotkey binding (appended by installer)

~/Library/LaunchAgents/
  com.user.screenshot-watcher.plist  # launchd watcher for iCloud folder (iOS bridge)
```

The processing script calls `claude -p` (non-interactive mode) with the agent prompt as system prompt and screenshot file paths in the user message. Claude reads the images, classifies them, and calls MCP tools to take action. The `--dangerously-skip-permissions` flag is used so the agent can act without human confirmation.

## Uninstall

```bash
cd Agentic-Screenshot
./uninstall.sh
```

Removes all scripts, the Hammerspoon hotkey block, and the launchd watcher. Leaves Hammerspoon, Claude CLI, and the iCloud Drive folder in place.

## License

MIT
