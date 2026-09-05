---
name: check-in
description: Ad hoc personal work-session briefing. Use when he says "what's on my plate," "let's start," "check in," or wants an orientation before starting a work session (personal project, job hunt, freelance work). Not tied to a fixed daily schedule - can run multiple times a day or be skipped entirely.
---

# Check-in

Ad hoc briefing at the start of a work session: pull calendar/tasks/carryovers, confirm priorities, ensure today's journal exists.

## Step 1: Verify date

```bash
date +%Y-%m-%d
date +%A | tr '[:upper:]' '[:lower:]'
```

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

```
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
```

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

After an answer (or an explicit decline), store the answer to nornicdb and mempalace under wing "personal", room = that category (same convention the hook itself uses), then run:

```bash
~/.claude/scripts/daily-checkin-hook.sh --mark
```

Never backfill more than one day - two or more missed days still means exactly one question, about the most recent.

## Step 8: memory.md log

If anything about this check-in *routine itself* needs improving (not session content - that belongs in the journal), log a 2-3 sentence entry to `memory.md`, reverse-chronological, same format as every other skill's memory.md in this repo.

---

## Notes

- No `eval.md` for this skill - it's fetch/present/confirm with no judgment calls worth a pass/fail gate. (Compare `check-out`, which has one.)
- Ad hoc trigger - can run multiple times a day, or be skipped entirely on days nothing happens. Never assume it ran just because `check-out` did, or vice versa.
- Task-source note: pulls from Google Tasks + beads + wiki `- [ ]` TODOs. Google Tasks is known to be cluttered and slated for future pruning - that's a separate concern, not this skill's job to fix.
