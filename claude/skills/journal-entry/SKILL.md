---
name: journal-entry
description: Use when user wants to create a dated journal entry page in Wiki.js.
version: 2.0.0
---

# Journal Entry Scaffolder

Create a new journal page in Wiki.js with the correct naming conventions, ensuring
all parent hierarchy pages exist.

Uses the `wikijs` skill's CLI (`~/.claude/skills/wikijs/scripts/wikijs.py`) - NOT
the wikijs MCP server. Every command needs env sourced first:

```bash
set -a; source ~/.config/wikijs.env; set +a
wj() { python3 ~/.claude/skills/wikijs/scripts/wikijs.py "$@"; }
```

## Conventions (verified against live wiki 2026-07-18)

| Variable | Format | Example |
|----------|--------|---------|
| `{year}` | 4-digit | `2026` |
| `{month}` | 2-digit zero-padded | `07` |
| `{day}` | 2-digit zero-padded | `18` |
| `{weekday}` | lowercase full name | `saturday` |
| `{Weekday}` | title-cased | `Saturday` |

- **Entry path**: `journal/{year}/{month}/{day}-{weekday}` (e.g. `journal/2026/07/18-saturday`)
- **Entry title**: `{day} {Weekday}` (e.g. `18 Saturday`)
- Pages are created by **path** - hierarchy comes from the path itself, no parent id.

## Process

### Step 1: Determine date

Today unless user specifies otherwise.

### Step 2: Check existing pages

```bash
wj get journal/{year}/{month}/{day}-{weekday}
```

If it exists: report `[{day} {Weekday}](http://localhost/journal/{year}/{month}/{day}-{weekday})` and stop.

Then check parents (each `wj get <path>`): `journal`, `journal/{year}`,
`journal/{year}/{month}`.

### Step 3: Create missing parents (top-down)

| Missing page | Title | Placeholder content |
|---|---|---|
| `journal` | `Journal` | `## Years\n` |
| `journal/{year}` | `{year}` | `## Months\n` |
| `journal/{year}/{month}` | `{month}` | `## Entries\n` |

```bash
wj create journal/{year}/{month} "{month}" --content "## Entries"
```

After creating a parent, add a link to it in ITS parent's list section
(`## Years` / `## Months`), keeping the list sorted:

```bash
wj get journal/{year}          # inspect current list
wj update journal/{year} --replace "<full content with new link inserted>"
```

Link formats: year page link `- [{year}](/journal/{year})`, month page link
`- [{month}](/journal/{year}/{month})`.

### Step 4: Create the entry page

The page title renders as the level-1 heading - no scaffolded sections. Wiki.js
rejects empty/whitespace-only content ("Page content cannot be empty"), so use an
invisible HTML comment as placeholder:

```bash
wj create journal/{year}/{month}/{day}-{weekday} "{day} {Weekday}" --content "<!-- -->"
```

When adding the first real content, use `--replace` to drop the placeholder;
subsequent additions use `--append`.

### Step 5: Add entry link to month page

Fetch month page, insert into `## Entries` sorted by day, write back:

```
- [{day} {Weekday}](/journal/{year}/{month}/{day}-{weekday})
```

Use `wj update <path> --replace "<full content>"` (append only if the new entry
is the latest day, which it usually is: `wj update journal/{year}/{month} --append "- [18 Saturday](/journal/2026/07/18-saturday)"`).

## Adding content later

- Brief notes: `wj update <entry-path> --append "note text"`
- Anything longer than a couple lines: promote to its own `## Section` in the append.

## After creation

Output clickable link with `http://localhost/` prefix:
`[{day} {Weekday}](http://localhost/journal/{year}/{month}/{day}-{weekday})`
