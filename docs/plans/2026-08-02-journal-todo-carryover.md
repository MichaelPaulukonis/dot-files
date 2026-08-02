# Journal TODO Carryover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Note on scope:** this plan edits a markdown *skill instructions* file (a prompt for an LLM), not application code. There is no unit-test suite to run, so "tests" here are a live smoke test against the real Wiki.js instance using disposable scratch pages, not pytest. Keep the change small - this is a gentle enhancement, not a hardened feature.

**Goal:** Teach the `journal-entry` skill to carry open (`- [ ] `) checkbox TODOs forward from the past 7 calendar days into a newly-created journal entry, removing them from the source day (migrate, not copy) so they never duplicate.

**Architecture:** New "Step 4.5" inserted into `journal-entry/SKILL.md` between entry creation (Step 4) and month-index linking (Step 5). Only fires when scaffolding a brand-new entry (Step 2's existing-page early-return is unchanged, so re-running on an existing day never re-triggers carryover). Looks back 7 calendar days (not "last 7 entries"), skips days with no page, collects unchecked checkbox lines only (`- [ ] ` literal), dedupes by exact text, appends them under a `## Carried over` heading on the new entry, and strips them from every source page they came from.

**Tech Stack:** Bash (macOS `date -v-Nd`), `wj` (the `wikijs` skill's CLI wrapper), Wiki.js 2.x GraphQL backend.

---

### Task 1: Add carryover step to `journal-entry` skill

**Files:**
- Modify: `/Users/michaelpaulukonis/projects/dot-files/claude/skills/journal-entry/SKILL.md`

- [ ] **Step 1: Bump version and insert the new step**

Edit the frontmatter version from `2.0.0` to `2.1.0`, and insert a new `### Step 4.5` section immediately after the existing `### Step 4: Create the entry page` section (before `### Step 5: Add entry link to month page`):

```markdown
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
Leave everything else alone:
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

**7. Migrate, don't copy.** For every source page a carried item came from: `wj get`
its current content, remove that exact line, `wj update <source-path> --replace
"<content with the line removed>"`. The item now exists exactly once, on today's
page. If this were to strip a source page down to empty (shouldn't happen -
checkbox lines live inside real entry content), fall back to the `<!-- -->`
placeholder rule rather than sending an empty update.

**Known tradeoff:** items older than 7 calendar days simply expire unflagged -
accepted per the 2026-08-02 decision to keep this lightweight rather than
bullet-proof.
```

- [ ] **Step 2: Read back the edited file and confirm structure**

Read `/Users/michaelpaulukonis/projects/dot-files/claude/skills/journal-entry/SKILL.md`
top to bottom. Confirm: version bumped, new Step 4.5 sits between Step 4 and Step 5,
no other section accidentally altered.

- [ ] **Step 3: Commit**

```bash
cd /Users/michaelpaulukonis/projects/dot-files
git add claude/skills/journal-entry/SKILL.md
git commit -m "feat(journal-entry): carry over open TODOs from past 7 days"
```

---

### Task 2: Live smoke test against the real wiki (scratch pages, deleted after)

**Files:** none (no source changes - this is a manual verification pass)

- [ ] **Step 1: Sanity-check the date loop**

```bash
for i in 1 2 3 4 5 6 7; do
  echo "journal/$(date -v-${i}d '+%Y/%m/%d-%A' | tr '[:upper:]' '[:lower:]')"
done
```

Expected: 7 lines, paths matching the real convention (e.g.
`journal/2026/07/26-sunday`), each one day further back than the last, all lowercase.

- [ ] **Step 2: Create 3 disposable scratch source pages**

Use an obviously-fake year (`2099`) so these never collide with real entries.
Wiki.js pages don't require an existing parent page (path-based hierarchy), so no
parent scaffolding is needed for this test.

```bash
set -a; source ~/.config/wikijs.env; set +a
wj() { python3 ~/.claude/plugins/marketplaces/claude-wikijs-skill/skills/wikijs/scripts/wikijs.py "$@"; }

wj create journal/2099/01/01-thursday "01 Thursday" --content "$(cat <<'EOF'
- [ ] test dup item
- [ ] test unique item one
- [x] test already done
plain prose todo, not checkbox syntax
EOF
)"

wj create journal/2099/01/02-friday "02 Friday" --content "$(cat <<'EOF'
- [ ] test dup item
- [ ] test unique item two
EOF
)"

wj create journal/2099/01/03-saturday "03 Saturday" --content "$(cat <<'EOF'
- [X] test also done, capital X
EOF
)"

wj create journal/2099/01/04-sunday "04 Sunday" --content "<!-- -->"
```

- [ ] **Step 3: Run steps 3-7 of the new procedure by hand against these 4 pages**

Treat `journal/2099/01/01-thursday`, `.../02-friday`, `.../03-saturday` as the
"past 7 days" source set and `journal/2099/01/04-sunday` as "today's entry."
Follow Step 4.5's own instructions (extract unchecked-only, dedupe, write, migrate).

- [ ] **Step 4: Verify results**

```bash
wj get journal/2099/01/04-sunday
wj get journal/2099/01/01-thursday
wj get journal/2099/01/02-friday
wj get journal/2099/01/03-saturday
```

Expected:
- `04-sunday` has a `## Carried over` section with exactly 3 lines: `- [ ] test dup item`,
  `- [ ] test unique item one`, `- [ ] test unique item two` (deduped, no repeats,
  checkbox marker preserved so they stay actionable).
- `01-thursday` no longer has either `- [ ]` line, but still has `- [x] test already
  done` and the plain-prose line, untouched.
- `02-friday` no longer has its `- [ ]` line.
- `03-saturday` is completely untouched (`- [X]` was never a candidate).

- [ ] **Step 5: Clean up scratch pages**

```bash
wj delete journal/2099/01/01-thursday --yes
wj delete journal/2099/01/02-friday --yes
wj delete journal/2099/01/03-saturday --yes
wj delete journal/2099/01/04-sunday --yes
```

- [ ] **Step 6: Report result**

If Step 4's expectations all held: smoke test passed, feature is ready for real use
next time a journal entry gets scaffolded. If anything diverged, fix Task 1's
SKILL.md wording (the instructions were ambiguous or wrong somewhere) and re-run
this task before considering it done.
