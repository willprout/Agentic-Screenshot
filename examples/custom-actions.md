# Adding Custom Action Types

The agent prompt (`~/.screenshot-to-action/screenshot-agent-prompt.md`) controls what the agent does with your screenshots. You can add new action types by editing that file.

## Example: Moving / Logistics Label

If you're tracking a move or logistics project on Trello, add this section to the agent prompt under `## Action Types`:

### Moving / Logistics / Shipping
Create a Trello card with a dedicated label (e.g., "Moving" with sky color).
- Attach the screenshot
- Extract any dates, addresses, tracking numbers, or action items into the description
- Set a due date if one is apparent

## Example: Expense Tracking

### Receipt / Expense
If the screenshot contains a receipt, invoice, or price:
- Create a Trello card with title: "[Expense] Vendor — $Amount"
- Apply a custom "Expenses" label
- Include the date, vendor, amount, and line items in the description
- Attach the screenshot

## Tips

- Keep each action type specific — the agent performs better with clear rules than vague ones.
- Test new action types by screenshotting an example and checking the result.
- The agent decides which action to take based on the image content, so make your descriptions distinct enough that the right one triggers.
