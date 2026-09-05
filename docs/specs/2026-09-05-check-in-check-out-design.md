# check-in / check-out design

Status: approved, ready for implementation plan
Date: 2026-09-05
Related beads: research-36e.4 (workday-end eval), research-36e.5 (workday-start eval), research-0qy (unified life-log, deferred)

## Why

Beads research-36e.4/.5 evaluated the work skills `workday-start`/`workday-end` (Jira, Confluence-adjacent, tied to a fixed 9-5 shape) for personal use. They don't map cleanly: no fixed workday, no Jira, no team standup context. But the underlying pattern — morning briefing pulling calendar/tasks/carryovers, evening wrap-up capturing notes/reflection/tomorrow-prep — is worth keeping for personal life and freelance/job-hunt work.

## Naming

**check-in** / **check-out**. Chosen over `session-start`/`session-end` (collides with Claude Code's own "session" terminology - SessionStart hooks etc.) and `clock-in`/`clock-out` (too job-shaped given the point is decoupling from a fixed job). "Check-in/out" is inherently ad hoc - you check in and out of a gym multiple times a day, no fixed schedule implied - matching the trigger model below.

## Trigger model

Ad hoc, per session - invoked whenever starting or wrapping up a focused block of work (personal project, job hunt, freelance work, or just "what's on my plate"), not a fixed daily habit tied to a clock.

## Scope boundaries (explicitly NOT this design)

- **No Jira / Confluence** - non-starter for personal use, dropped entirely.
- **No unified cross-environment life-log** - the bigger "second-brain" idea (one structured store spanning tech/home/career/family, readable by both Claude Code and Claude Cowork) is real but bigger scope. Tracked separately at research-0qy. check-in/check-out's `memory.md` files are a tier-"now" instance of that idea, not a redesign of it.
- **No Google-Tasks pruning/consolidation work** - Tasks is currently "very full, needs to be pruned." check-in reads from it as-is alongside beads and wiki TODOs; consolidating onto Tasks alone is a future cleanup, not blocking this design.

## check-in

Trigger: user says "what's on my plate," "let's start," or similar - starting a work session.

1. **Verify date.** Use `date` directly (no work-specific `workday-dates.js` script - that handled prevWorkday/nextWorkday skipping weekends for a fixed job calendar; personal use has no such calendar, just "yesterday").
2. **Fetch context, in parallel:**
   - Today's journal (`journal-entry` skill conventions: `journal/{year}/{month}/{day}-{weekday}`) - may not exist yet.
   - Yesterday's journal - extract: most-important-thing-for-tomorrow from `## Reflection` (if present), unchecked `- [ ]` items, whether `## Reflection` exists at all (marks whether check-out ran).
   - Google Calendar - today's events (`mcp__claude_ai_Google_Calendar__list_events` or `search_events`).
   - Google Tasks - via the `gtasks-cli` skill.
   - beads - `bd list` if a `.beads` db exists in the current working directory (project-specific backlog; skip silently if none).
   - NornicDB - `discover`/`recall` recent relevant nodes (type `Reflection`/`Highlight`, tagged with personal categories - see NornicDB integration below) to surface anything relevant that predates yesterday's journal.
3. **Present briefing** - scannable, no padding:

   ```
   ## Today's Focus - {Day}, {Month} {DD}

   ### Priority (from yesterday)
   ### Carryovers
   ### Tasks / Beads
   ### Today's Calendar
   ```

4. **Confirm and update** - ask "does this look right? anything to add or shift?", incorporate response.
5. **Ensure today's journal exists** - create via `journal-entry` skill conventions if missing.
6. **Write `## Today's Plan`** to today's journal with confirmed priorities/calendar.
7. **Catch-up fold-in:** if yesterday's journal has no `## Reflection` (check-out didn't run), ask ONE question from the daily personal check-in rotation (the existing `~/.claude/scripts/daily-checkin-hook.sh` categories: family/career/personality/background), using the category for the *missed* day. Skip entirely if yesterday was already closed out or if today's rotation already resolved.
8. **memory.md log** - if anything about the check-in routine itself needs improving (not session content - that's the journal's job).

No eval.md for check-in - it's fetch/present/confirm, no judgment calls worth a pass/fail gate.

## check-out

Trigger: user says "wrapping up," "done for now," "let's close out," or similar.

1. **Collect notes** - ask "what did you work on? paste any notes/accomplishments." If today's journal has content already, show it and ask what to add. Log under `##` headings (named topics get their own heading; misc stays under the `#` heading), no confirmation needed before writing.
2. **Scan for highlights** - shipped features, recognition, demos, decisions, notable outcomes. If found, ask "should *[item]* go into your highlights?" On yes: append to wiki page `writing/wins` (create with parent-hierarchy check if missing, same pattern as other wiki pages) under a `## {YYYY}` section: `- **{YYYY-MM-DD}:** {highlight text}`. Skip the question entirely if nothing found.
3. **Reflection** - four questions, answerable together:
   - Day in a few words
   - Any blockers
   - Most important accomplishment
   - Most important thing for tomorrow
   Log under `## Reflection` in today's journal. If today's daily-personal-checkin rotation hasn't been resolved yet today, fold its question in here as a fifth prompt rather than as a separate interruption later.
4. **Carryover TODOs** - scan notes/reflection for explicit carryovers or `TODO`s, ask which should seed tomorrow's journal. Create tomorrow's journal entry (via `journal-entry` conventions) seeded with confirmed carryovers.
5. **NornicDB store** - store the reflection and any confirmed highlights as nodes: `type: Reflection` or `type: Highlight`, `tags: [check-out, {date}, {personal category if the folded-in rotation question was answered}]`. Same convention the daily-checkin-hook already uses (wing "personal", room = category) - check-out becomes another writer into that store, not a new scheme.
6. **Eval loop** - light self-check against `eval.md` (checks below), inline, no sub-agent needed. Fix anything fixable now (vague journal entry, non-actionable TODO); note calibration observations (e.g. highlight-detection threshold) for `memory.md` instead of fixing in-session.
7. **memory.md log.**

### check-out/eval.md (planned checks, ~8, mirrors workday-end's but trimmed)

**Journal quality**

1. Logged items under concrete `##` headings, not a wall of bullets?
2. Every logged item names what was done specifically, not "worked on X"?
3. Reflection has all four questions answered, even if brief?

**Tomorrow prep**
4. Carryover TODOs are actionable, not vague intentions?
5. Tomorrow's journal seed contains only confirmed carryovers, nothing invented?

**Highlights**
6. Highlights flagged only for genuinely notable items, not routine work?
7. If none found, question was skipped (not asked and answered "nothing")?

**Process**
8. NornicDB store happened only after the wiki write succeeded (wiki is the durable record; NornicDB is supplementary).

## NornicDB integration

- **check-in reads** (`discover`/`recall`) - supplements the wiki-journal read, does not replace it. Surfaces older-than-yesterday context the journal alone wouldn't show.
- **check-out writes** (`store`) - reflection and highlights, tagged/typed to match the existing daily-checkin-hook convention (wing "personal", room = category, plus `check-out` and date tags). This makes check-out a second writer into the same personal-memory store the hook already uses, not a separate scheme.
- Wiki journal remains the durable, human-readable record either way; NornicDB is the queryable/semantic-search layer on top, per the tier-"now"/tier-"next" framing from the second-brain artifact (research-0qy) - this design deliberately takes a small first step in that direction without committing to the full unified-log rebuild.

## File layout

```
dot-files/claude/skills/check-in/
  SKILL.md
  memory.md
dot-files/claude/skills/check-out/
  SKILL.md
  eval.md
  memory.md
```

Symlinked into `~/.claude/skills/check-in` and `~/.claude/skills/check-out`, same pattern as every other skill in this repo. `workday-start`/`workday-end` are work-only skills living outside this repo (not touched by this design).

## Open items deliberately deferred

- Calendar-triggered check-ins (vs. only user-invoked) - noted in the second-brain artifact as a target, not built here.
- Google Tasks pruning/consolidation - separate cleanup effort.
- Unified cross-environment life-log - research-0qy.
