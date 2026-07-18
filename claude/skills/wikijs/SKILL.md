---
name: wikijs
description: Use when working with the personal Wiki.js instance - journaling ("journal this", "add to my wiki"), creating or editing wiki pages, uploading images or files to the wiki, or searching/reading wiki content ("what did I write about X").
---

# Wiki.js CLI

Thin wrapper for the local Wiki.js 2.x instance. All operations go through
`scripts/wikijs.py`. No MCP server needed.

## Setup

Every invocation needs env vars sourced first:

```bash
set -a; source ~/.config/wikijs.env; set +a
python3 ~/.claude/skills/wikijs/scripts/wikijs.py <command> ...
```

Fails fast with a clear message if `WIKIJS_TOKEN` is missing or the wiki is down.

## Commands

```
create <path> <title> [--content S | --content-file F] [--tags a,b] [--description S]
update <path|id> [--append S | --append-file F | --replace S | --replace-file F]
get <path|id>          # content on stdout, metadata JSON on stderr
search <query>         # id, path, title per line
list [--limit N]       # most recently updated first
delete <path|id> --yes # refuses without --yes
upload <file> [--folder <slug|id>]   # prints embed path, e.g. /test-verify/img.png
folders                # asset folders: id, slug, name
assets [--folder <slug|id>]          # assets in folder: id, filename, size, updated
delete-asset <id> --yes
rename-asset <id> <new-filename>     # filename only
```

## Journal convention (matches live wiki - do not deviate)

- Entry path: `journal/{year}/{month}/{day}-{weekday}` - month/day zero-padded,
  weekday lowercase full name. Example: `journal/2026/07/18-saturday`
- Entry title: `{day} {Weekday}` - e.g. `18 Saturday`
- Entry body starts empty; append plain lines under the title, promote anything
  longer than a couple of lines to its own `## Section`
- Parent pages: `journal` has `## Years`, `journal/{year}` has `## Months`,
  `journal/{year}/{month}` has `## Entries` with day links sorted by day
- Journaling flow: `get` today's page; if missing, `create` it (and any missing
  parents top-down, adding the link to each parent's list section); then
  `update --append`
- When linking a wiki page in a response, prefix with `http://localhost/`
  (not https, not a bare path)

## Upload → embed example

```bash
path=$(python3 ~/.claude/skills/wikijs/scripts/wikijs.py upload diagram.png --folder journal)
python3 ~/.claude/skills/wikijs/scripts/wikijs.py update journal/2026/07/18-saturday \
  --append "![diagram]($path)"
```

Max upload 5 MB (server default); script pre-checks and errors readably.

## Quirks

- Search result ids can be stale - trust the `path` column, never the id.
- A failed `update` may still have written content (Wiki.js applies content
  before some validations). `get` to check state before retrying.
- No folder delete exists in the Wiki.js 2.x API - don't look for one.
  Asset folders can only be created (`folders` lists them).
- No asset move-between-folders or metadata edit either (verified by schema
  introspection: only createFolder, renameAsset, deleteAsset, flushTempUploads).
  To "move": download the asset, `upload` to the target folder, `delete-asset`
  the original, update any pages embedding the old path.
- Page create/update rejects empty or whitespace-only content ("Page content
  cannot be empty"). For an intentionally blank page use `--content "<!-- -->"`.
- The API token is full admin. Delete is guarded by `--yes`; keep it that way.
