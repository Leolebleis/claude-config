# PR Workflow Skill

Use when committing changes to repositories that require pull requests to main (like disqt-discord-bot).

## Standard PR Flow

### 1. Create Branch and Commit

```bash
# Create descriptive branch name
git checkout -b <type>/<short-description>
# Examples: fix/bot-add-parsing, feat/workshop-command, refactor/remove-map-commands

# Stage specific files (prefer over git add -A)
git add path/to/file1 path/to/file2

# Commit with Co-Authored-By
git commit -m "$(cat <<'EOF'
<type>: <short description>

<optional body>

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### 2. Push and Create PR

```bash
# Push branch
git push -u origin <branch-name>

# Create PR with gh cli
gh pr create --title "<type>: <description>" --body "$(cat <<'EOF'
## Summary
- Bullet points of changes

## Test plan
- [ ] Test case 1
- [ ] Test case 2

Generated with [Claude Code](https://claude.ai/code)
EOF
)"
```

### 3. After Merge

```bash
# Switch back to main
git checkout main
git pull

# Delete local branch
git branch -d <branch-name>
```

## Commit Types

| Type | Use for |
|------|---------|
| `feat` | New features |
| `fix` | Bug fixes |
| `refactor` | Code changes that don't fix bugs or add features |
| `docs` | Documentation only |
| `style` | Formatting, missing semicolons, etc. |
| `test` | Adding tests |
| `chore` | Maintenance tasks |

## Branch Naming

```
<type>/<short-kebab-description>

Examples:
fix/bot-add-team-parsing
feat/workshop-maps
refactor/delegate-modes-to-gmm
docs/update-readme
```

## PR Title Format

Same as commit message first line:
```
fix: bot add command now accepts team without count
feat: add workshop map loading command
refactor: remove map commands, delegate to GameModeManager
```

## Quick Reference

```bash
# Full flow in one go (after staging files)
git checkout -b fix/my-fix && \
git add <files> && \
git commit -m "fix: description

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>" && \
git push -u origin fix/my-fix && \
gh pr create --title "fix: description" --body "## Summary
- Change 1

Generated with [Claude Code](https://claude.ai/code)"
```
