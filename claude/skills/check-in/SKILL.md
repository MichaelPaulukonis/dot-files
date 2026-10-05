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

**Last journal:** Fetch yesterday's page at the same path convention; if it doesn't exist, walk backward one day at a time (up to 7 calendar days total) until one does. Extract:

- **Priority:** the most-important-thing-for-tomorrow line from `## Reflection` if present (bonus - check-out rarely runs), otherwise the `Priority:` line from `## Today's Plan` (check-in writes it itself in Step 6, so it exists whenever check-in ran).
- **Carryovers:** unchecked `- [ ]` items anywhere on the page, plus the other `## Today's Plan` bullets (status unknown until he says).

If nothing exists anywhere in that 7-day window, say so explicitly in the Step 3 briefing and ask him directly rather than silently presenting an empty Priority/Carryovers section.

**Google Calendar:** Use `mcp__claude_ai_Google_Calendar__list_events` (or `search_events`) for today's date.

**Gmail:** Use `mcp__claude_ai_Gmail__search_threads` (`THREAD_VIEW_MINIMAL`) with two queries:

- **Bills** (30-day window, inbox only - archiving a bill once it's handled is how it drops off; he tends to ignore bills, so they keep resurfacing until dealt with):
  `in:inbox newer_than:30d (subject:(bill OR billing OR invoice OR statement OR "payment due" OR "amount due" OR "past due" OR overdue OR autopay OR "payment failed" OR "on hold" OR "payment details" OR "payment method" OR declined) OR from:(billing OR invoice OR invoices OR payments))`
- **Inbox** (Gmail's own importance ranking does most of the filtering):
  `in:inbox newer_than:3d (is:important OR from:parentsquare.com) -from:substack.com -from:linkedin.com`
  ParentSquare school digests are included on purpose even when not marked important - they're being triaged for keep/drop (see Step 4).

Triage using subject + snippet only (fetch the full message only if a snippet is ambiguous about amount or due date):

- Bills: drop newsletters/news that merely mention "bill", promos ("20% off your invoice"), pay stubs, and receipts for things already paid. Tier the rest - **urgent** (payment failed, account on hold, overdue, due within 7 days), **due** (amount + due date known), **FYI** (statement ready, autopay scheduled; collapse into one line with a count).
- Inbox: drop streaming/account marketing and anything already under Bills. Keep people, GitHub review requests, school items. Cap at ~8.

If the connector is unavailable or errors, omit the Bills/Inbox sections silently.

**Google Tasks:** Use the `gtasks-cli` skill to list open tasks. Always exclude "walk (15 mins)" from the briefing - standing user call, it's recurring noise, not a real to-do. If it fails with `invalid_grant`, put one line at the top of the briefing: "gtasks token expired - run `! gtasks login`" (OAuth client may be in Testing mode, 7-day token life - research-6b2).

**beads:** If a `.beads` directory exists in the current working directory, run `bd list`. If it doesn't exist, skip silently - not every session happens inside a beads-tracked project.

Any single source failing or returning nothing is non-fatal for the whole step - present the briefing in Step 3 with whatever came back, don't block on a partial failure.

## Step 3: Present the briefing

```
## Today's Focus — {Day}, {Month} {DD}

### Bills
- 🔴 [Urgent: sender - what's wrong / amount - due date] (link)
- 🟡 [Due: sender - amount - due date] (link)
- ⚪ [N statements/autopay notices: sender, sender, ...]

### Priority (from {date of last journal})
- [Reflection's most-important-thing, else Today's Plan Priority line - or "None recorded"]

### Carryovers
- [Unchecked items + other Today's Plan bullets from the last journal]

### Tasks / Beads
- [Open Google Tasks]
- [Open beads issues, if any - omit this sub-list entirely if no .beads dir was found]

### Today's Calendar
- [Time] [Event] — [organizer, if not him]

### Inbox
- [Sender] - [subject, or one-line gist for ParentSquare digests] (link)
```

Bills goes first, above Priority, on purpose - it's the section he'd otherwise skip.

Keep it scannable. Don't pad empty sections with "None" clutter beyond the Priority line - just omit a heading if it has nothing under it, except Priority which always gets a line (even if "None recorded"). Flag back-to-back calendar events if any exist.

## Step 4: Confirm and update

Ask: "Does this look right? Anything to add or shift? What got done from the last plan?" Incorporate any changes he gives before moving on - the "what got done" answer is the stand-in for a check-out that didn't happen.

In the same question, ask which Bills/Inbox items actually mattered and which were noise (especially ParentSquare digests). Log his verdicts in Step 7 - these become the eval checks for the email triage once enough runs accumulate.

## Step 5: Ensure today's journal exists

If missing, create it via the `journal-entry` skill's conventions (path `journal/{year}/{month}/{day}-{weekday}`, title `{day} {Weekday}`, creating parent placeholders as needed).

## Step 6: Write today's plan

Add a `## Today's Plan` section to today's journal with the confirmed priorities and calendar items from Step 4. Its first bullet must be `- Priority: ...` - the next check-in reads that line as its Priority source. Write it using the `journal-entry` skill's append convention (never a full-page replace — that would wipe any other content already on the page).

Carryovers and Tasks/Beads stay in their own systems (yesterday's journal, Google Tasks, beads) and are NOT duplicated into this section — "Today's Plan" is just the confirmed priority and today's calendar, kept short.

## Step 7: memory.md log

If anything about this check-in *routine itself* needs improving (not session content - that belongs in the journal), log a 2-3 sentence entry to `memory.md`, reverse-chronological, same format as every other skill's memory.md in this repo.

Tag each entry `[user]` (he said or corrected it) or `[model]` (your own inference) - the `improve-skill` outer loop weights them differently. Always log the Step 4 email verdicts as a `[user]` entry, e.g.:

    2026-09-30 [user]: Email triage - kept: Verizon failed payment, ParentSquare FHS (conference). Dropped: ParentSquare Cameron (Alltown ad), Netflix.

---

## Notes

- No `eval.md` yet. The skill was pure fetch/present/confirm until the Gmail triage added a judgment call. Per `~/.claude/skills/_shared/skill-eval-memory-scaffolding.md`, substance checks come from experience, not up front - after 3+ logged email verdicts, run `improve-skill` on this skill to turn the patterns into eval.md checks.
- Ad hoc trigger - can run multiple times a day, or be skipped entirely on days nothing happens. Never assume it ran just because `check-out` did, or vice versa. Check-in must stand on its own: check-out is rare, so never depend on a `## Reflection` existing.
- The daily personal question is owned by the `daily-checkin-hook.sh` reminder (repeats until resolved), not this skill - no catch-up step needed here.
- Open-ended nags ("remind me daily until done") live as daily recurring calendar events; they surface in Today's Calendar automatically.
- Task-source note: pulls from Google Tasks + beads + wiki `- [ ]` TODOs. Google Tasks is known to be cluttered and slated for future pruning - that's a separate concern, not this skill's job to fix.
