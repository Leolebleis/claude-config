# MD Hygiene Skills

Skills for maintaining CLAUDE.md quality and managing project documentation.

## When to Use What

| Trigger | Skill | Command |
|---------|-------|---------|
| Session produced learnings worth preserving | `claude-md-management:revise-claude-md` | `/revise-claude-md` |
| Entering a repo for the first time, or CLAUDE.md feels stale | `claude-md-management:claude-md-improver` | `/claude-md-improver` |
| Creating, editing, or benchmarking skills | `skill-creator:skill-creator` | `/skill-creator` |
| Setting up Claude Code for a new project | `claude-code-setup:claude-automation-recommender` | `/claude-automation-recommender` |
| Before compaction (manual only -- never auto-invoke) | `claude-config:precompact` | `/precompact` |

## Auto-Trigger Rules

At natural checkpoints, consider invoking the appropriate skill:

- **End of a productive session** (new patterns discovered, conventions established, gotchas hit): suggest `/revise-claude-md`
- **First time working in a repo** or when CLAUDE.md hasn't been audited recently: suggest `/claude-md-improver`
- **After creating or modifying a skill**: suggest `/skill-creator` for quality checks
- **Setting up Claude Code in a new codebase**: suggest `/claude-automation-recommender`

Do NOT auto-invoke `/precompact`. Only run it when the user explicitly requests it.

## What Each Skill Does

### revise-claude-md
Captures session learnings into CLAUDE.md. Adds conventions, gotchas, and patterns discovered during work so future sessions start with that knowledge.

### claude-md-improver
Full audit of all CLAUDE.md files in a repo. Grades quality against templates, identifies gaps, and makes targeted improvements.

### skill-creator
Creates new skills, modifies existing ones, and runs evals to benchmark skill performance. The practical tool for skill development.

### claude-automation-recommender
Analyzes a codebase and recommends Claude Code features to add: hooks, skills, CLAUDE.md improvements, MCP servers.

### precompact
Preserves valuable conversation context before compaction. Writes key findings to memory and/or CLAUDE.md so they survive context compression.
