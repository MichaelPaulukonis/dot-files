---
name: claude-sync
description: Back up custom Claude Code config (skills, commands, agents, scripts, instructions, memory, settings) into version control. Use when user says "backup claude files", "sync claude config", "adopt this skill into dot-files", or after creating a new custom skill/command.
---

# claude-sync

Discover-prompt-adopt backup for custom Claude Code configuration.
Spec: `docs/specs/2026-07-18-claude-sync-design.md` in the dot-files repo.

## Destinations

- **Public** `~/projects/dot-files`: skills, commands, agents, scripts, local-plugins (from `~/.claude` and `~/.agents`), CLAUDE.md, RTK.md, claude-hud config, installed_plugins.json
- **Private** `~/projects/claude-private`: per-project memory dirs, settings.json, settings.local.json, mcpServers extract from `~/.claude.json`

Symlink-adopted items live in the repo with a symlink at the original path - edits land in the repo working tree immediately. Copy-synced files (settings, plugin configs) are re-copied on each run because Claude Code rewrites them via atomic rename, which would break symlinks.

## Usage

Preview what would change (no prompts, no writes):

    bash ~/projects/dot-files/claude/skills/claude-sync/scripts/sync.sh --dry-run

Interactive run (prompts [a]dopt / [i]gnore forever / [s]kip per new item, offers commit+push per repo at the end):

    bash ~/projects/dot-files/claude/skills/claude-sync/scripts/sync.sh

Run the interactive version in the foreground and relay each prompt to the user - adoption decisions are theirs. Never answer the adopt/ignore prompts autonomously.

"Ignore forever" decisions are stored in `.sync-ignore` at each repo root; edit that file to un-ignore.

## Safety

- Adopt-time secret grep blocks adoption unless the user types `yes`
- Both repos have gitleaks pre-commit hooks - if a commit is rejected, show the gitleaks output to the user and do not bypass with --no-verify
- The public repo is PUBLIC on GitHub: anything personal belongs in claude-private

## Tests

    bash ~/projects/dot-files/claude/skills/claude-sync/tests/test-sync.sh

Sandbox-only (temp dir), safe to run anytime. Expect `FAIL: 0`.
