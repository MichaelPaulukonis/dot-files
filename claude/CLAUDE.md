# User Preferences

## About Me

- macOS only - skip Linux/Windows instructions
- Use plain hyphens (`-`) not em-dashes (`—`) in responses
- Push back. Say "that's the wrong question" when it is. Skip routine affirmations - don't soften critiques or disagreements
- When reviewing a draft, ask about choices before giving feedback
- Assume basics known. Lead with answer. Don't pad responses to seem thorough

## Terminal Setup

- Running **iTerm2** directly (no tmux)
- Use iTerm2 native shortcuts for navigation:
  - `Cmd+[` / `Cmd+]` - cycle panes
  - `Cmd+Opt+↑/↓/←/→` - navigate panes by direction
  - `Cmd+Shift+[` / `Cmd+Shift+]` - cycle tabs
  - `Cmd+D` - split vertically - `Cmd+Shift+D` - split horizontally
- Do NOT suggest tmux commands or `Ctrl+b` bindings

## Homebrew Installations

When installing a homebrew package, update wiki page at `study/macos/homebrew` via wikijs MCP with:
- Package name
- Install date
- Why installed (ask if not mentioned)
- Link to official docs

## MCP Server Installations

When adding an MCP server, update wiki page at `study/ai-ml/claude-code/mcp-servers` via wikijs MCP with:
- Server name
- Install date
- Why installed (ask if not mentioned)
- Link to repo/docs

## Claude Code Skills & Plugin Installations

When installing, creating, or updating a Claude Code skill or plugin, update wiki page at `study/ai-ml/claude-code/skills-plugins` via wikijs MCP (create entry if not yet there, append to update log if it is) with:
- Name, type (skill/plugin), source
- Scope (global vs project)
- Install/update date and why (ask if not mentioned)
- Link to repo/docs
- Not a canonical taxonomy vs the MCP Servers page - if a plugin also provides an MCP server, pick one page for the full entry and cross-reference from the other rather than duplicating

## Wiki.js Journal Links

When linking to a journal/Wiki.js page in a response, prefix with `http://localhost/` (e.g. `http://localhost/journal/...`) - not `https`, not a bare path.
- Why: bare paths aren't clickable; no local TLS cert, so `https` fails.

## Wiki.js Journal Convention

This convention matches the live wiki - do not deviate:
- Entry path: `journal/{year}/{month}/{day}-{weekday}` - month/day zero-padded, weekday lowercase full name. Example: `journal/2026/07/18-saturday`
- Entry title: `{day} {Weekday}` - e.g. `18 Saturday`
- Entry body starts empty; append plain lines under the title, promote anything longer than a couple of lines to its own `## Section`
- Parent pages: `journal` has `## Years`, `journal/{year}` has `## Months`, `journal/{year}/{month}` has `## Entries` with day links sorted by day
- Journaling flow: `get` today's page; if missing, `create` it (and any missing parents top-down, adding the link to each parent's list section); then `update --append`

## Daily Personal Check-in

A `SessionStart` + `UserPromptSubmit` hook (`~/.claude/scripts/daily-checkin-hook.sh`) surfaces a personal-context question, gated to once per calendar day, rotating through: family, career, personality/likes, background. State: `~/.claude/daily-checkin/state.json`.

- **Reminder repeats every turn until resolved** - firing the reminder does NOT mark the day done; only running `~/.claude/scripts/daily-checkin-hook.sh --mark` does. This is deliberate: it used to mark the day "asked" the moment the hook fired, so one ignored reminder silently burned the whole day with no retry. Now it keeps resurfacing (SessionStart and every UserPromptSubmit) until actually resolved.
- **Automatic**: when the reminder appears (PENDING for today's category), work one low-friction question into the session naturally - check nornicdb + mempalace (wing `personal`, room = category) for what's already known, find a real gap, ask about it.
  - If they answer: store it to nornicdb AND mempalace (not Claude's own memory files) under wing `personal`, room = category, then run `~/.claude/scripts/daily-checkin-hook.sh --mark`.
  - If they decline ("not tonight", skip, etc.): respect it immediately, don't ask again this session, then still run `--mark` - this silences it for the rest of today only; it returns with the next category on a future day.
  - Do not run `--mark` until one of those two things has actually happened - a session that never asks should keep getting reminded, including in later sessions the same day.
- **On-demand**: if I explicitly ask you to ask me a check-in question (any category, or unspecified), do the same gap-fill lookup and ask - regardless of whether today's automatic one is pending or already resolved. This doesn't touch the daily-gate state file or the category rotation (don't run `--mark` for this path).

@RTK.md
