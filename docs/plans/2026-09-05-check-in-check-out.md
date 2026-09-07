# Check-in / Check-out Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Note on scope:** this plan creates two markdown *skill instructions* files (prompts for an LLM) plus their `eval.md`/`memory.md` companions and symlinks - not application code. There is no unit-test suite to run. Verification steps are read-backs against the spec, not pytest. A live end-to-end run (real Wiki.js/Calendar/Tasks/NornicDB calls) is called out at the end as a manual step for the user to trigger themselves, not an automated task - it writes to shared state (wiki pages, NornicDB) that shouldn't happen without him watching.

**Goal:** Replace the work-only `workday-start`/`workday-end` pattern with two personal, ad hoc skills - `check-in` and `check-out` - per the approved design at `docs/specs/2026-09-05-check-in-check-out-design.md`.

**Architecture:** Two new skill directories under `dot-files/claude/skills/`, each symlinked into `~/.claude/skills/`, following the exact pattern already used by every other skill in this repo (see `blog-workflow` for a recent example with the same `eval.md`/`memory.md` scaffolding). `check-in` reads calendar/tasks/beads/journal/NornicDB and writes only to the journal. `check-out` writes to the journal, a wiki highlights page, and NornicDB.

**Tech Stack:** Markdown skill files, `wikijs` CLI skill (`wj`), `gtasks-cli` skill, `mcp__claude_ai_Google_Calendar__*`, `mcp__nornicdb__*`, `bd` (beads), the existing `~/.claude/scripts/daily-checkin-hook.sh`.

---

### Task 1: Create the `check-in` skill

**Files:**

- Create: `/Users/michaelpaulukonis/projects/dot-files/claude/skills/check-in/SKILL.md`
- Create: `/Users/michaelpaulukonis/projects/dot-files/claude/skills/check-in/memory.md`

- [ ] **Step 1: Write `SKILL.md`**

```markdown
---
name: check-in
description: Ad hoc personal work-session briefing. Use when he says "what's on my plate," "let's start," "check in," or wants an orientation before starting a work session (personal project, job hunt, freelance work). Not tied to a fixed daily schedule - can run multiple times a day or be skipped entirely.
---

# Check-in

Ad hoc briefing at the start of a work session: pull calendar/tasks/carryovers, confirm priorities, ensure today's journal exists.

## Step 1: Verify date

\```bash
date +%Y-%m-%d
date +%A | tr '[:upper:]' '[:lower:]'
\```

No fixed-workday script needed here - "yesterday" is just yesterday, weekends included, no Jira-calendar concept of a "workday."

## Step 2: Fetch context (parallel)

Run all of these in parallel:

**Today's journal:** Use the `journal-entry` skill's path convention, `journal/{year}/{month}/{day}-{weekday}`, to check today's page. May not exist yet - that's fine, Step 5 handles it.

**Yesterday's journal:** Fetch yesterday's page at the same path convention. Extract:
- The most-important-thing-for-tomorrow line from its `## Reflection` section, if present.
- Unchecked `- [ ]` checkbox items anywhere on the page.
- Whether `## Reflection` exists at all - its absence means `check-out` never ran yesterday (used in Step 7 below).

If yesterday's page doesn't exist at all, treat all three as empty/false and move on - not an error.

**Google Calendar:** Use `mcp__claude_ai_Google_Calendar__list_events` (or `search_events`) for today's date.

**Google Tasks:** Use the `gtasks-cli` skill to list open tasks.

**beads:** If a `.beads` directory exists in the current working directory, run `bd list`. If it doesn't exist, skip silently - not every session happens inside a beads-tracked project.

**NornicDB:** Call `mcp__nornicdb__discover` (or `mcp__nornicdb__recall`) for recent nodes tagged `check-out` or typed `Reflection`/`Highlight` - this surfaces context older than yesterday's journal. Treat an empty result or a tool error as non-fatal; this step is supplementary, never the source of truth for the briefing.

## Step 3: Present the briefing

\```
## Today's Focus — {Day}, {Month} {DD}

### Priority (from yesterday)
- [Most important thing for tomorrow, from yesterday's reflection - or "None recorded"]

### Carryovers
- [Unchecked items from yesterday's journal]

### Tasks / Beads
- [Open Google Tasks]
- [Open beads issues, if any - omit this sub-list entirely if no .beads dir was found]

### Today's Calendar
- [Time] [Event] — [organizer, if not him]
\```

Keep it scannable. Don't pad empty sections with "None" clutter beyond the Priority line - just omit a heading if it has nothing under it, except Priority which always gets a line (even if "None recorded"). Flag back-to-back calendar events if any exist.

## Step 4: Confirm and update

Ask: "Does this look right? Anything to add or shift?" Incorporate any changes he gives before moving on.

## Step 5: Ensure today's journal exists

If missing, create it via the `journal-entry` skill's conventions (path `journal/{year}/{month}/{day}-{weekday}`, title `{day} {Weekday}`, creating parent placeholders as needed).

## Step 6: Write today's plan

Add a `## Today's Plan` section to today's journal with the confirmed priorities and calendar items from Step 4.

## Step 7: Catch-up fold-in (only if yesterday wasn't checked out)

Skip this step entirely if EITHER is true:
- Yesterday's journal already has a `## Reflection` section (`check-out` ran), or
- Today's daily personal check-in rotation is already resolved - check `~/.claude/daily-checkin/state.json` for today's date.

Otherwise: read `~/.claude/scripts/daily-checkin-hook.sh` to find the category rotation (family/career/personality/background), and ask ONE question using the category for the *missed* day (yesterday's weekday), not today's. Frame it as a catch-up, not a reprimand - take "nothing" for an answer.

After an answer (or an explicit decline), store the answer to nornicdb under tags "personal", that category (same convention the hook itself uses), then run:

\```bash
~/.claude/scripts/daily-checkin-hook.sh --mark
\```

Never backfill more than one day - two or more missed days still means exactly one question, about the most recent.

## Step 8: memory.md log

If anything about this check-in *routine itself* needs improving (not session content - that belongs in the journal), log a 2-3 sentence entry to `memory.md`, reverse-chronological, same format as every other skill's memory.md in this repo.

---

## Notes

- No `eval.md` for this skill - it's fetch/present/confirm with no judgment calls worth a pass/fail gate. (Compare `check-out`, which has one.)
- Ad hoc trigger - can run multiple times a day, or be skipped entirely on days nothing happens. Never assume it ran just because `check-out` did, or vice versa.
- Task-source note: pulls from Google Tasks + beads + wiki `- [ ]` TODOs. Google Tasks is known to be cluttered and slated for future pruning - that's a separate concern, not this skill's job to fix.
```

- [ ] **Step 2: Write `memory.md`**

```markdown
# check-in skill memory

Reverse-chronological. Skill-improvement observations only - not session content (that's the journal's job). Keep entries to 2-3 sentences per session.

## Log

2026-09-05: Skill created, replacing the work-only `workday-start` skill for personal use. No Jira, no fixed-workday date script - "yesterday" is just yesterday. Pulls tasks from three sources (Google Tasks, beads, wiki TODOs) rather than one, since Tasks is still cluttered and unconsolidated.
```

- [ ] **Step 3: Read back both files and confirm structure**

Read `/Users/michaelpaulukonis/projects/dot-files/claude/skills/check-in/SKILL.md` and `.../memory.md` top to bottom. Confirm: frontmatter is valid YAML (name/description present), all 8 steps are in order and none were truncated, no `TBD`/`TODO`/placeholder text anywhere.

- [ ] **Step 4: Commit**

```bash
cd /Users/michaelpaulukonis/projects/dot-files
git add claude/skills/check-in/
git commit -m "$(cat <<'EOF'
Add check-in skill (personal work-session briefing)

Replaces workday-start for personal use per docs/specs/2026-09-05-check-in-check-out-design.md.
No Jira/fixed-workday assumptions; pulls from Google Calendar, Google Tasks,
beads, wiki journal carryovers, and NornicDB.
EOF
)"
```

---

### Task 2: Create the `check-out` skill

**Files:**

- Create: `/Users/michaelpaulukonis/projects/dot-files/claude/skills/check-out/SKILL.md`
- Create: `/Users/michaelpaulukonis/projects/dot-files/claude/skills/check-out/eval.md`
- Create: `/Users/michaelpaulukonis/projects/dot-files/claude/skills/check-out/memory.md`

- [ ] **Step 1: Write `SKILL.md`**

```markdown
---
name: check-out
description: Ad hoc personal work-session wrap-up. Use when he says "wrapping up," "done for now," "let's close out," or wants to log notes and reflect at the end of a work session. Not tied to a fixed daily schedule.
---

# Check-out

Ad hoc wrap-up: capture the session, flag highlights, reflect, prep tomorrow.

## Step 1: Verify date

\```bash
date +%Y-%m-%d
date +%A | tr '[:upper:]' '[:lower:]'
\```

## Step 2: Fetch today's journal

Use the `journal-entry` skill's path convention (`journal/{year}/{month}/{day}-{weekday}`) to fetch today's page. If it doesn't exist yet, run the `journal-entry` skill's creation steps first.

## Step 3: Collect notes

Ask: "What did you work on? Paste any notes, accomplishments, or items to log." If today's journal already has content beyond the placeholder, show it first and ask what to add.

## Step 4: Update today's journal

Add the notes to today's journal:
- Named topics (project work, decisions, meetings-equivalent) get their own `##` heading.
- Miscellaneous items go as bullets directly under the `#` heading.

Do not ask for confirmation before writing this part - just transcribe what he gave you.

## Step 5: Scan for highlights

Review today's notes for: shipped features/projects, recognition or praise from others, demos or things shared publicly, key decisions made or unblocked, notable outcomes.

If found, ask: "Should _[specific item]_ go into your highlights?"

If yes → update wiki page `writing/wins`:
- Fetch the current page. If it doesn't exist, create it (title `Wins`, path `writing/wins`, initial content `## {current year}`) - same parent-hierarchy-check pattern as other wiki pages in this setup.
- Prepend the entry under the current year's `## {YYYY}` section:
  \```
  - **{YYYY-MM-DD}:** {highlight text}
  \```

If no highlights were found, skip the question entirely - don't ask and have him say "nothing."

## Step 6: Reflection

Ask these four questions together:

1. "Describe your day in a few words."
2. "Any blockers to note?"
3. "What was your most important accomplishment today?"
4. "What's the most important thing you need to do tomorrow?"

**Fold-in check:** before logging, check `~/.claude/daily-checkin/state.json` for today's date. If today's daily personal check-in rotation is NOT yet resolved, add its question as a fifth prompt in this same batch (using today's rotation category, not a separate interruption). After he answers, store that answer to nornicdb and mempalace under wing "personal", room = today's category, then run:

\```bash
~/.claude/scripts/daily-checkin-hook.sh --mark
\```

If the rotation is already resolved (by `check-in`'s catch-up step, or earlier this session), skip the fold-in - don't ask twice.

Log the four reflection responses under `## Reflection` in today's journal:

\```markdown
## Reflection

- Day in a few words: [response]
- Blockers: [response or "None"]
- Most important accomplishment: [response]
- Most important thing for tomorrow: [response]
\```

## Step 7: Carryover TODOs

Scan today's notes and reflection for explicit carryovers or `TODO` items. List them and ask which should carry into tomorrow's plan.

Create tomorrow's journal entry if it doesn't exist yet (via the `journal-entry` skill's conventions), seeded with the confirmed carryovers as bullets under the `#` heading.

## Step 8: NornicDB store

After the wiki writes in Steps 4-7 have succeeded, call `mcp__nornicdb__store`:

- For the reflection: `content` = the four reflection answers as one block, `type: "Reflection"`, `tags: ["check-out", "{YYYY-MM-DD}"]` (add the personal category as an extra tag if Step 6's fold-in ran).
- For each confirmed highlight: `content` = the highlight text, `type: "Highlight"`, `tags: ["check-out", "{YYYY-MM-DD}"]`.

Wiki is the durable, human-readable record; NornicDB is a supplementary, queryable layer on top - if the NornicDB call fails, note it in `memory.md` and move on. Never block or retry the routine over it.

## Step 9: Eval loop

Self-check this session against `eval.md`, inline - no sub-agent needed, this is a quick pass. If a check FAILs on something fixable right now (vague journal entry, non-actionable TODO), fix it before finishing. If it's an observation for next time (e.g. highlight-detection threshold felt off), note it in `memory.md` instead of trying to fix it retroactively.

## Step 10: memory.md log

Log a 2-3 sentence skill-improvement observation to `memory.md`, reverse-chronological. Skip if nothing about the routine itself stood out this session.

---

## Notes

- Ad hoc trigger, same as `check-in` - don't assume one ran just because the other did.
- No Jira, no Confluence, no performance-review framing. `writing/wins` is personal record-keeping (portfolio/job-hunt material), not a work artifact - keep the tone accordingly.
```

- [ ] **Step 2: Write `eval.md`**

```markdown
# check-out eval

Run as a self-check after completing the wrap-up routine (Step 9). Answer each check PASS or FAIL. If FAIL, note the issue - some are worth fixing now, others are just observations for `memory.md`.

## Journal quality

1. Are journal entries under concrete `##` headings - not dumped as a wall of bullets under the main heading?
2. Does every logged item name what was done specifically - not "worked on the project" or "continued yesterday's thing"?
3. Is the reflection section complete - all four questions answered, even if brief?

## Tomorrow prep

4. Are carryover TODOs actionable tasks, not vague intentions? ("Write the check-in eval.md" not "keep working on the skill")
5. Does tomorrow's journal seed contain only confirmed carryovers - nothing invented or assumed?

## Highlights

6. Were highlights flagged only for genuinely notable items (shipped work, recognition, decisions, notable outcomes) - not routine daily tasks?
7. If no highlights were found, was the question skipped entirely (not asked and answered "nothing")?

## Process

8. Was the NornicDB store attempted only after the wiki writes succeeded - never before, never in place of them?
9. Was the daily personal check-in rotation folded in only if it wasn't already resolved today - never asked twice?
```

- [ ] **Step 3: Write `memory.md`**

```markdown
# check-out skill memory

Reverse-chronological. Skill-improvement observations only - not individual session quality (that's eval.md's job). Keep entries to 2-3 sentences per session.

## Log

2026-09-05: Skill created, replacing the work-only `workday-end` skill for personal use. No Jira, no Confluence - highlights go to a personal `writing/wins` wiki page instead of a work performance-highlights page. Added a NornicDB store step (Step 8) alongside the wiki write, per the second-brain artifact discussion (research-0qy) - wiki stays the durable record, NornicDB is the queryable layer on top.
```

- [ ] **Step 4: Read back all three files and confirm structure**

Read all three files top to bottom. Confirm: frontmatter valid, all 10 `SKILL.md` steps present and in order, `eval.md` has exactly 9 checks across 4 sections, no placeholder text anywhere.

- [ ] **Step 5: Commit**

```bash
cd /Users/michaelpaulukonis/projects/dot-files
git add claude/skills/check-out/
git commit -m "$(cat <<'EOF'
Add check-out skill (personal work-session wrap-up)

Replaces workday-end for personal use per docs/specs/2026-09-05-check-in-check-out-design.md.
Highlights go to a personal writing/wins wiki page instead of a work
performance page. Adds a NornicDB store step alongside the wiki record.
EOF
)"
```

---

### Task 3: Symlink both skills into `~/.claude/skills`

**Files:**

- Create (symlink): `/Users/michaelpaulukonis/.claude/skills/check-in` → `/Users/michaelpaulukonis/projects/dot-files/claude/skills/check-in`
- Create (symlink): `/Users/michaelpaulukonis/.claude/skills/check-out` → `/Users/michaelpaulukonis/projects/dot-files/claude/skills/check-out`

- [ ] **Step 1: Create both symlinks**

```bash
ln -s /Users/michaelpaulukonis/projects/dot-files/claude/skills/check-in /Users/michaelpaulukonis/.claude/skills/check-in
ln -s /Users/michaelpaulukonis/projects/dot-files/claude/skills/check-out /Users/michaelpaulukonis/.claude/skills/check-out
```

- [ ] **Step 2: Verify both resolve correctly**

```bash
ls -la /Users/michaelpaulukonis/.claude/skills/check-in /Users/michaelpaulukonis/.claude/skills/check-out
cat /Users/michaelpaulukonis/.claude/skills/check-in/SKILL.md | head -5
cat /Users/michaelpaulukonis/.claude/skills/check-out/SKILL.md | head -5
```

Expected: both `ls -la` lines show `->` pointing at the dot-files paths, and both `head -5` calls print valid YAML frontmatter starting with `---`.

No commit needed for this task - symlinks live outside the git repo (in `~/.claude/skills`), only their targets are tracked.

---

### Task 4: Update research-36e.4 and research-36e.5

**Files:** none (bd CLI only)

- [ ] **Step 1: Close both beads**

```bash
cd /Users/michaelpaulukonis/projects/research
bd close research-36e.4 --reason "Reworked as personal check-out skill (dropped Jira/Confluence-adjacent bits, added Google Calendar/Tasks + beads + NornicDB). See docs/specs/2026-09-05-check-in-check-out-design.md in dot-files."
bd close research-36e.5 --reason "Reworked as personal check-in skill, same design doc as research-36e.4."
```

- [ ] **Step 2: Verify**

```bash
bd list
```

Expected: both issues show as closed (✓) under the `research-36e` epic.

---

## Manual step (not automated - do this yourself when ready)

Once Tasks 1-4 are done, run `check-in` for real in a normal session ("what's on my plate today?") to smoke-test it end to end - it will actually write to Wiki.js, and possibly to NornicDB and the daily-checkin state file. This is deliberately left out of the automated task list since it touches shared/durable state outside this repo. If anything about the flow feels off, that's exactly what `memory.md` is for - log it and adjust the skill directly rather than filing a new bead for a first-run wrinkle.
