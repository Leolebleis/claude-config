---
name: google-tasks
description: Manage Google Tasks -- list, create, complete, update, and search tasks. Use when the user mentions tasks, todos, reminders, or asks to check/add/complete tasks.
---

# Google Tasks

Manage the user's Google Tasks via the google_workspace_tasks MCP server (taylorwilsdon/google_workspace_mcp).

## Available Tools

| Tool | Tier | Purpose |
|------|------|---------|
| `list_tasks` | Core | List tasks with filtering |
| `get_task` | Core | Retrieve task details |
| `manage_task` | Core | Create, update, delete, or move tasks |
| `list_task_lists` | Complete | List all task lists |
| `get_task_list` | Complete | Get task list details |
| `manage_task_list` | Complete | Create, update, delete task lists, or clear completed |

## Workflow

1. **Always start with `list_task_lists`** to get list IDs
2. Then use `list_tasks` with the list ID to fetch tasks
3. Present tasks in a clean table: title, due date, status, notes

## When Creating Tasks

- Use `manage_task` with action "create"
- Ask for a title at minimum
- Set due date if mentioned or implied
- Add notes for any extra context
- Assign to the default list unless user specifies otherwise

## When Listing Tasks

- Show overdue tasks first, highlighted
- Group by list if multiple lists exist
- Include notes/descriptions when present
- Omit completed tasks unless explicitly asked

## Proactive Use

If during a conversation you discover something that should be tracked as a task (e.g., "I need to book that appointment", "remind me to check X"), offer to create a Google Task for it.

## Setup (per machine)

The MCP server is configured locally in `~/.claude/settings.json`, not in the plugin. To set up on a new machine:

1. Install: `uv tool install workspace-mcp` (or use `uvx`)
2. GCP project with Tasks API enabled + OAuth Desktop client
3. Add to `~/.claude/settings.json`:

```json
"mcpServers": {
  "google_workspace_tasks": {
    "command": "uvx",
    "args": ["workspace-mcp", "--tools", "tasks"],
    "env": {
      "GOOGLE_OAUTH_CLIENT_ID": "<client-id>",
      "GOOGLE_OAUTH_CLIENT_SECRET": "<client-secret>"
    }
  }
}
```

4. First run opens browser for Google OAuth consent, then caches token automatically.
