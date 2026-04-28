---
name: solved-problem
description: "Use when about to build a custom solution after brainstorming, when wondering if a tool already exists, when researching prior art before implementing, or when the user invokes /solved-problem. Triggers on selfhosted/homelab tooling, dev workflow automation, infrastructure scripts, sysadmin chores, or any 'has someone already built X?' situation - even for small scripts."
---

# Solved Problem

Before building custom, check what exists. Returns ranked existing tools (with pros/cons), documented gotchas, and a recommendation: use, fork, or justify-custom.

## When to Use

**Triggers (any of these):**
- After brainstorming, before any implementation step - even for a "small script"
- Self-hosted, homelab, dev tooling, automation, infrastructure, sysadmin problems
- User asks "is there something for this?" or invokes `/solved-problem`
- The proposed solution feels like a category that probably exists

**Skip ONLY when:**
- Project-specific business logic (no one else has this exact shape)
- User has already explicitly chosen a tool and is asking how to use it
- Truly novel problem (rare - verify before assuming)

**Violating the letter of the rule is violating the spirit.** "It's small" is not a skip clause.

## The Iron Rule

**No "let's start writing" without prior-art research first.**

If the user has brainstormed a tool/script/automation and says some variant of "let's build it," "start writing it," or "let's design it," STOP. Run this skill before any implementation step, including clarifying questions about the custom design.

Clarifying questions are fine *to frame the research* (Step 1). They are not fine *to scope a custom build* before research is done.

## Workflow

### Step 1: Frame the Problem

Extract from conversation (or ask):
- **Goal:** one sentence
- **Constraints:** stack, host, OS, language, license, online/offline
- **Anti-goals:** what NOT to want
- **Already considered:** any tools mentioned in the brainstorm

Bad framing produces bad results. If anything is unclear, ask before dispatching searches - but only the minimum to make the search effective. Do NOT ask custom-design questions yet.

### Step 2: Dispatch Parallel Research Subagents

**REQUIRED:** Use superpowers:dispatching-parallel-agents - one general-purpose subagent per surface, all dispatched in a single message.

| Surface | Subagent task |
|---------|---------------|
| GitHub | Search GitHub for repos solving the framed problem. Return top 5-10 sorted by stars: stars, last commit date, license, language, 1-line description, link. Flag stale (>12mo no commits). |
| Reddit | Search r/selfhosted, r/homelab, r/devops, r/sysadmin + topic-specific subs (use google `site:reddit.com` queries). Return upvoted threads recommending tools or describing the same pain. |
| Hacker News | Search hn.algolia.com for the problem space. Return high-comment threads (50+ comments) with key tool mentions extracted. |
| Awesome lists | Find `awesome-<topic>` lists on GitHub. Return curated alternatives with the context the list gives them. |
| Blogs/docs | Search for implementation guides, "we built X then switched to Y" retrospectives, and official docs of close-fit tools. |

Pass each subagent the **exact framing** from Step 1. Tell them to return raw findings (not summaries) and to flag staleness, license mismatch, or platform-specific lock-in.

### Step 3: Synthesize

Discard irrelevant results. From what remains, build the report.

**Found tools** (always sort by stars unless fit/recency clearly trumps):

| Tool | Stars | Last commit | License | Pros | Cons |
|------|-------|-------------|---------|------|------|
| repo1 | 12k | 2026-04 | MIT | Active, plugin system, fits all constraints | Heavy JVM, requires Postgres |
| repo2 | 3.1k | 2026-03 | AGPL | Single binary, fast | Small community, AGPL blocks commercial |
| repo3 | 800 | 2025-09 | MIT | Closest semantic fit | **Likely stale** - 7mo no commits |

Pros/cons must be **specific to the user's framing**. Generic ("active development", "good docs") is a red flag - rewrite. Flag stale repos in Cons.

**Learnings** - 3-5 bullets of gotchas, design considerations, or common pitfalls surfaced by prior art. The most valuable output even if no tool fits.

**Recommendation** - exactly one of:
- **Use X** - why it fits, install/setup pointer
- **Fork/extend X** - what's missing, rough effort estimate
- **Build custom** - must cite specific reasons each top-3 candidate was rejected. "I prefer custom" is not a reason.

**Revised plan** - only include if recommendation changes direction. 3-5 bullets of the new approach.

### Step 4: Hand Off

Post the report in chat. STOP. Wait for user direction. Do NOT start implementing. Do NOT ask custom-design questions. The user picks the path.

## Rationalizations - STOP and Run the Skill

| Excuse | Reality |
|--------|---------|
| "It's just a small script" | Small scripts are the most likely to already exist. Run it. |
| "We already designed it together" | Sunk cost. The design might be wrong. Run it. |
| "User said let's start writing" | "Start writing" doesn't mean "skip research." Surface options first. |
| "Asking would feel like rambling" | A 30-second framing question is not rambling. A wasted day rebuilding is. |
| "I'll do a quick web search instead" | One search is not research. Parallel subagents per surface, every time. |
| "The user will get impatient" | The user explicitly built this skill BECAUSE they want this. They'll wait. |
| "I know this domain, nothing exists" | You don't. Verify. |
| "It's a niche problem" | Niche problems often have niche tools. Run the skill. |

## Red Flags - STOP

- About to write a clarifying question that scopes a custom design (Discord format? cron schedule? config file location?)
- Reasoning includes "this is too small for the skill"
- Reasoning includes "we already decided the approach"
- About to grep GitHub once and call it research
- Pros/cons all generic - rewrite with framing-specific lines
- Recommending "build custom" with fewer than 3 rejected candidates and specific reasons

All of these mean: STOP. Run Steps 1-4 properly.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| One web search + a summary | Parallel subagents per surface, every time |
| Recommending custom without rejecting candidates | Cite specific reasons each top-3 fails |
| Generic pros/cons | Tie every line to user's framing |
| Listing repos without flagging staleness | Mark anything >12mo in Cons |
| Implementing immediately after the report | Stop. Wait for direction. |
| Searching with the user's verbatim wording | Re-frame technically first |
| Asking design questions before research | Custom-design questions come AFTER the report, only if user picks "build custom" |
