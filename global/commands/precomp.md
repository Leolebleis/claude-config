# Pre-Compaction Context Preservation

Run this before compacting to persist all valuable conversation context to durable storage. Nothing in the conversation should be lost that could be useful in future sessions.

## Procedure

Work through each step. Skip steps that don't apply (e.g., no CLAUDE.md changes needed). Be thorough -- compaction is lossy and this is your only chance to save context.

### 1. Audit the conversation

Scan the full conversation for:
- **Decisions**: Architecture choices, tool selections, config changes, approach decisions and their rationale
- **Discoveries**: Bugs found, root causes identified, gotchas encountered, things that didn't work and why
- **New knowledge**: File paths, commands, API behaviors, version constraints, environment details
- **Patterns**: Reusable workflows, debugging techniques, deployment procedures
- **User preferences**: Communication style, workflow preferences, things the user explicitly asked to remember
- **In-progress work**: Unfinished tasks, next steps, blockers

Make a mental inventory before writing anything.

### 2. Update auto-memory (MEMORY.md)

**Location**: The `memory/MEMORY.md` file in the current project's `.claude/projects/` directory.

- Read current MEMORY.md first
- Add new entries under the appropriate section headers
- Update existing entries if new information supersedes them
- Remove entries that are now wrong or outdated
- **Stay under 200 lines** (lines after 200 are truncated from the system prompt)
- For detailed notes, create topic files (e.g., `debugging.md`, `patterns.md`) in the same directory and link from MEMORY.md

**What belongs in MEMORY.md**: Stable facts, confirmed patterns, key paths, user preferences, solutions to recurring problems.

**What does NOT belong**: Session-specific state, speculative conclusions, anything that duplicates CLAUDE.md.

### 3. Update CLAUDE.md files (if applicable)

If the conversation revealed new project conventions, server paths, config details, known issues, or deployment procedures:

- Identify the correct CLAUDE.md level:
  - `~/.claude/CLAUDE.md` -- user-global preferences
  - `<project>/CLAUDE.md` -- project-specific instructions
  - `<project>/.claude/CLAUDE.md` -- project workspace instructions
- Read the target file, add/update the relevant sections
- Keep entries factual and concise

### 4. Create or update skills (if applicable)

If a new reusable workflow was established (deploy procedure, debug technique, repeated task):

- **Global skills**: `~/.claude/commands/<name>.md`
- **Project skills**: `<project>/.claude/commands/<name>.md`
- Follow existing skill format (see other files in the same directory)

### 5. Document in-progress work (if applicable)

If there's unfinished work that a future session needs to continue:

- Write a brief state file to the project (e.g., `docs/plans/in-progress-<topic>.md` or similar)
- Include: what was done, what remains, key decisions already made, relevant file paths, any blockers
- Reference this file in the conversation summary

### 6. Report what was saved

Tell the user:
- Which files were updated/created
- A brief summary of what was persisted
- Any in-progress work documented
- Anything that could NOT be persisted (e.g., context too vague to capture)

## Guidelines

- **Be aggressive about saving** -- it's better to save something redundant than to lose something valuable
- **Deduplicate** -- don't add entries that already exist in MEMORY.md or CLAUDE.md
- **Prefer updating over appending** -- if an existing entry covers the same topic, update it rather than adding a new one
- **Verify before writing** -- always read the target file before editing to avoid conflicts or duplicates
- **Don't save session noise** -- temporary debugging output, exploration dead ends, and routine tool output are not worth persisting
