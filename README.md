# Screenshot-to-Action

A macOS hotkey that captures a region screenshot and routes it to an AI agent that automatically creates Trello cards or Google Calendar events based on what it sees.

**Press a hotkey → select a region → go back to work.** A notification tells you what was created.

## How It Works

1. **Capture** — Hotkey triggers macOS screen capture (crosshair region selector)
2. **Batch** — Multiple captures within 60 seconds are grouped together
3. **Classify** — Claude vision analyzes the screenshot(s) and decides:
   - **Event/meeting/date** → Google Calendar event (work or personal calendar)
   - **Task/request** → Trello card with appropriate label
   - **Informational** → Trello card for reference
4. **Act** — Creates the item automatically, shows a macOS notification with the result

If multiple screenshots are captured in a batch, the agent uses judgment to determine if they're related (combining into one action) or independent (separate actions).

## Prerequisites

- **macOS** (uses native `screencapture`)
- **[Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code/overview)** with an active Claude plan
- **Claude MCP connectors** enabled for:
  - [Google Calendar](https://claude.ai/settings/integrations) — for creating events
  - Trello — configured during install (API key + token)
- **[Hammerspoon](https://www.hammerspoon.org/)** — for global hotkey binding (installed automatically if you have Homebrew)

## Install

```bash
git clone https://github.com/willprout/Agentic-Screenshot.git
cd Agentic-Screenshot
./install.sh
```

The installer will walk you through:
1. Checking prerequisites (installs Hammerspoon if needed)
2. Setting up Trello API access (step-by-step walkthrough)
3. Configuring your Google Calendar IDs
4. Choosing your hotkey (default: Ctrl+Opt+Z)

## Usage

Press your hotkey (default **Ctrl+Opt+Z**). A crosshair appears — drag to select a region. You'll see:

- Immediately: **"Screenshot Captured"** notification
- After 60 seconds: **"Created N item(s)"** notification with details

### Batching

Take multiple screenshots within 60 seconds and they'll be processed together. The agent determines if they're related (e.g., a Slack message and the calendar it references → one calendar event with context) or independent (separate actions for each).

### Error Handling

If processing fails, a Trello card titled "Failed to process screenshot" is created with the screenshot attached — nothing is ever silently lost.

## Customization

After install, edit `~/.screenshot-to-action/screenshot-agent-prompt.md` to:

- Add new action types (see [examples/custom-actions.md](examples/custom-actions.md))
- Change Trello label names or add new ones
- Adjust calendar routing rules
- Modify the agent's classification behavior

## Uninstall

```bash
cd Agentic-Screenshot
./uninstall.sh
```

Removes all scripts and the Hammerspoon hotkey. Leaves Hammerspoon and Claude CLI installed.

## How It's Built

Three scripts + a Hammerspoon hotkey:

| File | Purpose |
|------|---------|
| `screenshot-capture.sh` | Hotkey target. Takes screenshot, manages 60s batch timer |
| `screenshot-process.sh` | Invokes Claude CLI with all pending screenshots |
| `screenshot-agent-prompt.md` | Classification rules for the vision agent |
| `mcp.json` | Trello MCP server config (generated during install) |

The processing script calls `claude -p` (non-interactive mode) with the agent prompt as system prompt and screenshot file paths in the user message. Claude reads the images, classifies them, and calls MCP tools (Trello, Google Calendar) to take action.

## License

MIT
