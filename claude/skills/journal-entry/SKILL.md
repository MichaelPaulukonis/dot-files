---
name: journal-entry
description: Use when user wants to create a dated journal entry page in Wiki.js.
version: 2.1.0
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

### Step 4.5: Carry over open TODOs (past 7 calendar days)

Only runs when Step 4 just created a brand-new entry (never on an existing page -
Step 2 already stops early in that case, so this never re-triggers on a re-run).

**1. List candidate source paths** - past 7 calendar days, not "last 7 entries":

```bash
for i in 1 2 3 4 5 6 7; do
  echo "journal/$(date -v-${i}d '+%Y/%m/%d-%A' | tr '[:upper:]' '[:lower:]')"
done
```

**2. Fetch each candidate.** `wj get <path>` for each of the 7 paths above. If it
errors (page doesn't exist - skipped day, weekend, etc.), skip it silently. This
is expected, not a failure.

**3. Extract unchecked items only.** From each page that *does* exist, scan its raw
content for lines matching exactly `- [ ] ` (literal space between the brackets).
Each matching line, checkbox marker included, is the "item" - everywhere below that
says "item" means the full line (`- [ ] ` prefix plus its text), never just the
description text after the marker. Leave everything else alone:
- `- [x]` / `- [X]` (done) - not carried, not touched
- prose-style todos without checkbox syntax - out of scope, not carried

**4. Dedupe.** Across all collected lines from all source pages, dedupe by exact
trimmed text. Keep one copy.

**5. Nothing found -> skip.** If zero items survive steps 3-4, do not create a
`## Carried over` section at all. Leave the entry as-is from Step 4.

**6. Write to today's entry.** If items were found:
- If today's page still has the Step 4 placeholder `<!-- -->`, replace it (same
  rule as "Adding content later" below):
  `wj update <today-path> --replace "## Carried over\n\n<item 1>\n<item 2>..."`
- Otherwise append: `wj update <today-path> --append "## Carried over\n\n<item 1>\n<item 2>..."`
- `<item N>` here is the full original line, checkbox marker included - always
  unchecked `- [ ] ` since a checked item was never a candidate (Step 3). For
  example, carrying over `test dup item`, `test unique item one`, and
  `test unique item two` writes:
  `wj update <today-path> --replace "## Carried over\n\n- [ ] test dup item\n- [ ] test unique item one\n- [ ] test unique item two"`

**7. Migrate, don't copy.** For every source page a carried item came from: `wj get`
its current content, remove that exact line, `wj update <source-path> --replace
"<content with the line removed>"`. The item now exists exactly once, on today's
page. If this were to strip a source page down to empty (shouldn't happen -
checkbox lines live inside real entry content), fall back to the `<!-- -->`
placeholder rule rather than sending an empty update.

**Known tradeoff:** items older than 7 calendar days simply expire unflagged -
accepted per the 2026-08-02 decision to keep this lightweight rather than
bullet-proof.

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
