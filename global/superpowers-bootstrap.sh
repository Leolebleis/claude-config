#!/usr/bin/env bash
# Wrapper to run the superpowers session-start hook synchronously.
# Lives outside the plugin cache so it survives plugin updates.
# Finds the latest installed superpowers version dynamically.

set -euo pipefail

PLUGIN_BASE="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"

# Find the latest version directory (sort by version number)
SUPERPOWERS_ROOT=$(ls -d "$PLUGIN_BASE"/*/ 2>/dev/null | while read -r dir; do
  basename "$dir"
done | grep -E '^[0-9]+\.' | sort -V | tail -1)

if [ -z "$SUPERPOWERS_ROOT" ]; then
  exit 0
fi

exec bash "$PLUGIN_BASE/$SUPERPOWERS_ROOT/hooks/session-start.sh"
