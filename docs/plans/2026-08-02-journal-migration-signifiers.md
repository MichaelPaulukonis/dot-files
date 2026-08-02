# Journal Migration Signifiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Note on scope:** this plan edits a markdown *skill instructions* file (a prompt for an LLM), not application code. There is no unit-test suite to run - "tests" here are a live smoke test against the real Wiki.js instance using disposable scratch pages, same as the carryover feature this plan modifies. Keep the change small.
>
> **Repo workflow note:** dot-files is a personal single-user repo. No PR, no worktree - plain feature branch, merge locally, delete branch. (See prior carryover work on this same file for the established pattern.)

**Goal:** Replace the `journal-entry` skill's current delete-based migration (Step 4.5, Step 7) with a signifier-based one: instead of removing a carried-forward TODO line from its source page, mark it done and leave a visible trace pointing at where it went - closer to real bullet-journal migration signifiers, and it structurally eliminates the empty-page/dangling-heading edge cases the delete-based version needed extra logic to handle.

**Architecture:** Only Step 7 of the existing Step 4.5 section in `journal-entry/SKILL.md` changes. Steps 1-6 (candidate paths, fetch, extract, dedupe, skip-if-empty, write to today) are unaffected - the only thing changing is what happens to the *source* page's line once an item has been carried. Since a checked `- [x]` line never matches Step 3's `- [ ] ` filter, marked items are automatically excluded from all future carryover runs without any extra bookkeeping.

**Tech Stack:** Bash (ANSI-C `$'...'` quoting, already established in Step 6), `wj` CLI, Wiki.js 2.x.

---

### Task 1: Replace delete-based migration with signifier-based migration

**Files:**
- Modify: `/Users/michaelpaulukonis/projects/dot-files/claude/skills/journal-entry/SKILL.md`

- [ ] **Step 1: Bump version and replace Step 7**

Edit the frontmatter version from `2.1.0` to `2.2.0`.

Replace the entire current point **7** of Step 4.5 (the paragraph starting "**7. Migrate, don't copy.** For every source page..." through "...The item now exists exactly once, on today's page.") with:

```markdown
**7. Migrate, don't copy - mark it, don't delete it.** For every source page a carried
item came from: `wj get` its current content. Replace each carried line *in place*
with a marked trace, rather than removing it:

`- [x] ~~<description>~~ → migrated to [{day} {Weekday}](/journal/{year}/{month}/{day}-{weekday})`

Here `<description>` is the item's original text with its `- [ ] ` prefix stripped
(e.g. `- [ ] buy milk` becomes `- [x] ~~buy milk~~ → migrated to [...]`), and the
link points at today's entry - the page Step 4 just created. The replacement line is
checked (`[x]`), so Step 3's `- [ ] ` filter will never match it again on a future
run: it's inert, won't be re-carried, and the source page keeps a permanent, visible
record of where the item went instead of silently losing content.

Write it back with the same ANSI-C quoting as Step 6 (plain `"..."` won't expand
`\n`):

`wj update <source-path> --replace $'<content with each carried line replaced in place>'`

Because a line is always *replaced* by another line - never deleted outright - the
source page can never end up empty or reduced to a dangling heading. There is no
emptiness check needed here (unlike the delete-based approach this replaces).
```

Leave the "**Known tradeoff**" paragraph immediately after (about items older than 7
days expiring) exactly as-is - it's unrelated to this change and still accurate.

- [ ] **Step 2: Read back the edited file and confirm structure**

Read `/Users/michaelpaulukonis/projects/dot-files/claude/skills/journal-entry/SKILL.md`
top to bottom. Confirm: version bumped to `2.2.0`, Step 7 now describes mark-in-place
instead of delete-and-check-empty, Steps 1-6 and the "Known tradeoff" paragraph are
unchanged, nothing else in the file was altered.

- [ ] **Step 3: Commit**

```bash
cd /Users/michaelpaulukonis/projects/dot-files
git add claude/skills/journal-entry/SKILL.md
git commit -m "feat(journal-entry): migration signifiers - mark carried TODOs instead of deleting them"
```

---

### Task 2: Live smoke test against the real wiki (scratch pages, deleted after)

**Files:** none (no source changes - this is a manual verification pass)

- [ ] **Step 1: Create scratch pages exercising the two cases that matter**

```bash
set -a; source ~/.config/wikijs.env; set +a
wj() { python3 ~/.claude/plugins/marketplaces/claude-wikijs-skill/skills/wikijs/scripts/wikijs.py "$@"; }

wj create journal/2099/04/01-wednesday "01 Wednesday" --content $'- [ ] test dup item\n- [ ] test unique item one\n- [x] test already done\nplain prose todo, not checkbox syntax'

wj create journal/2099/04/02-thursday "02 Thursday" --content $'- [ ] test dup item\n- [ ] test unique item two'

wj create journal/2099/04/03-friday "03 Friday" --content "<!-- -->"
```

`01-wednesday` and `02-thursday` are "past days" sources (with `test dup item`
duplicated across both, to check both get marked). `03-friday` is "today."

- [ ] **Step 2: Execute Step 4.5 (with the new Step 7) by hand against these 3 pages**

Read the current Step 4.5 text in
`/Users/michaelpaulukonis/projects/dot-files/claude/skills/journal-entry/SKILL.md`
and follow it literally: extract unchecked items from `01-wednesday` and
`02-thursday`, dedupe (`test dup item` collapses to one), write the 3 surviving
items to `03-friday` under `## Carried over` (ANSI-C quoting), then mark each
carried line on its source page(s) in place per the new Step 7 - `test dup item`
must get marked on *both* `01-wednesday` and `02-thursday`, since it came from both.

- [ ] **Step 3: Verify results**

```bash
wj get journal/2099/04/03-friday
wj get journal/2099/04/01-wednesday
wj get journal/2099/04/02-thursday
```

Expected:
- `03-friday`: `## Carried over` section with exactly 3 lines (`test dup item`,
  `test unique item one`, `test unique item two`), checkbox markers intact.
- `01-wednesday`: its `- [ ] test dup item` and `- [ ] test unique item one` lines
  are now `- [x] ~~...~~ → migrated to [03 Friday](/journal/2099/04/03-friday)`
  lines - NOT deleted, still present but checked/struck/linked. `- [x] test already
  done` and the prose line are completely untouched.
- `02-thursday`: its `- [ ] test dup item` line is now marked the same way (checked,
  struck, linked to `03-friday`). Its `- [ ] test unique item two` line is also
  marked. Confirm no error occurred writing this page back (no accidental empty
  string sent).

- [ ] **Step 4: Confirm marked lines are inert going forward**

Simulate a second carryover run reading `01-wednesday` and `02-thursday` again:
confirm the now-`- [x] ~~...~~ → migrated to [...]` lines do NOT match the
`- [ ] ` filter from Step 3 (they're checked, not unchecked) - so a future
carryover run would correctly skip them rather than re-carrying an already-migrated
item forward again.

- [ ] **Step 5: Clean up scratch pages**

```bash
wj delete journal/2099/04/01-wednesday --yes
wj delete journal/2099/04/02-thursday --yes
wj delete journal/2099/04/03-friday --yes
```

Confirm all 3 gone via re-`wj get` (expect not-found errors).

- [ ] **Step 6: Report result**

If Step 3's and Step 4's expectations all held: smoke test passed. If anything
diverged, that's a finding about Task 1's SKILL.md wording to report and fix before
considering this done - re-run this task after any fix.
