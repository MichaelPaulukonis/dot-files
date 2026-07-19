# claude-sync design

Date: 2026-07-18
Status: approved

## Goal

Back up custom Claude Code configuration (skills, commands, instructions, memory, settings) into version control, without capturing non-custom content (marketplace plugins, caches) or leaking sensitive data to a public repo. Replaces the ad-hoc "symlink things into dot-files by hand" workflow with a discover-prompt-adopt tool, modeled on the work `sync-config` tool but using symlink adoption instead of copying where possible.

## Destinations

Two repos:

- **Public: `~/projects/dot-files`** (github.com/MichaelPaulukonis/dot-files) - shareable config
- **Private: `~/projects/claude-private`** (new private GitHub repo) - personal-context and permission data

| Item | Repo | Method |
|------|------|--------|
| `~/.claude/skills/*` | public | symlink-adopt |
| `~/.claude/commands/*` | public | symlink-adopt |
| `~/.claude/agents/*` | public | symlink-adopt |
| `~/.claude/scripts/*` | public | symlink-adopt |
| `~/.claude/local-plugins/*` | public | symlink-adopt |
| `~/.agents/skills/*` | public | symlink-adopt |
| `~/.claude/CLAUDE.md`, `~/.claude/RTK.md` | public | symlink-adopt |
| `~/.claude/plugins/claude-hud/config.json` | public | copy-sync |
| `~/.claude/plugins/installed_plugins.json` | public | copy-sync |
| `~/.claude/projects/*/memory/` (whole dir per project) | private | symlink-adopt |
| `~/.claude/settings.json` | private | copy-sync |
| `~/.claude/settings.local.json` | private | copy-sync |
| `~/.claude.json` → `mcpServers` key only (jq extract) | private | copy-sync |

Repo layout mirrors source paths, e.g. `dot-files/claude/skills/<name>/`, `dot-files/agents/skills/<name>/`, `claude-private/claude/projects/<encoded>/memory/`.

### Method rationale

- **symlink-adopt**: move item into repo, symlink back to original location. Edits (including Claude's auto-written memory files) land in the repo working tree immediately; `git status` shows drift; no sync step to forget. Already the established pattern (wikijs, journal-entry skills).
- **copy-sync**: for files Claude Code or plugins rewrite via temp-file + atomic rename, which would replace a symlink with a regular file (observed: `settings.json.bak`, `.tmp` siblings). Script copies current file into repo and shows a diff when it changed.

## The tool

`claude-sync`: bash script + skill wrapper, self-hosted in the public repo:

```
dot-files/claude/skills/claude-sync/
  SKILL.md          # skill: triggers, usage, doc-of-record for locations
  scripts/sync.sh   # the script
```

Symlinked into `~/.claude/skills/claude-sync` by its own adopt mechanism. SKILL.md triggers: "backup claude files", "sync claude config", "adopt this skill into dot-files".

### Script flow

1. **Scan** each watched path (table above).
2. **Classify** each top-level item:
   - symlink resolving into either repo → already adopted; skip
   - symlink resolving elsewhere (plugin cache, marketplace) → non-custom; skip
   - path listed in ignore manifest → skip
   - otherwise → new; **prompt**: `[a]dopt / [i]gnore forever / [s]kip this run`
3. **Adopt** (symlink-adopt items): secret scan (below), move into repo mirror path, symlink back, `git add`.
4. **Copy-sync items**: no prompt needed after first adoption; copy when source differs from repo copy, show diff.
5. **Finish**: show `git status` for both repos; offer commit (and push) per repo.

### Ignore manifest

`.sync-ignore` at each repo root: one relative path per line. "Ignore forever" answers append here so the item is never re-prompted. Committed with the repo.

### Secret scanning

Three layers:

1. **Adopt-time grep** in the script: pattern set for AWS keys, generic `token|secret|password|api[_-]?key` assignments, PEM headers, long high-entropy strings. On hit: show matching lines, require explicit `yes` to proceed.
2. **Pre-commit hook: `gitleaks`** (brew install) in both repos - the durable guard. Catches future edits and auto-written memory files flowing through symlinks, not just the adopt moment. Same approach as the existing `specstory-guard` skill.
3. **Preview at adopt**: prompt shows head of file (or file listing for dirs) so approval is informed.

Known gap: auto-written memory sits unscanned in the private repo working tree until commit; the gitleaks pre-commit hook is the checkpoint. Acceptable - repo is private.

### Edge cases

- **New project memory dirs** appear over time; each next run discovers and prompts them.
- **Memory dir symlinks**: Claude Code writes memory files through the directory symlink (plain writes, not dir replacement) - safe. If a future harness version replaces the dir, `git status` in claude-private goes quiet and the symlink breaks; script warns when a previously-adopted symlink no longer resolves.
- **`~/.claude.json` extract**: `jq .mcpServers` output only; the rest of the file (per-project state, account info) is never copied.
- **Broken/dangling symlinks** in watched dirs: report, don't prompt to adopt.
- **Empty watched dirs** (`commands/`, `scripts/` today): no-op, no error.

## Out of scope (future)

- **Restore mode** (`claude-sync --restore`): on a new machine, clone repos and recreate symlinks/copies in the opposite direction. Designed-for (repo layout mirrors source paths) but not built now.
- Scheduled/automated runs. Manual invocation via skill is enough.
- Work-machine variant.

## Testing

- Dry-run flag (`--dry-run`): full scan + classification report, no changes.
- Manual verification per class: adopt a throwaway skill, confirm move + symlink + git add; touch settings.json, confirm diff + copy; plant a fake AWS key in a test file, confirm scan blocks adoption.
