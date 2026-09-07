---
name: check-out
description: Ad hoc personal work-session wrap-up. Use when he says "wrapping up," "done for now," "let's close out," or wants to log notes and reflect at the end of a work session. Not tied to a fixed daily schedule.
---

# Check-out

Ad hoc wrap-up: capture the session, flag highlights, reflect, prep tomorrow.

## Step 1: Verify date

```bash
date +%Y-%m-%d
date +%A | tr '[:upper:]' '[:lower:]'
```

## Step 2: Fetch today's journal

Use the `journal-entry` skill's path convention (`journal/{year}/{month}/{day}-{weekday}`) to fetch today's page. If it doesn't exist yet, run the `journal-entry` skill's creation steps first.

## Step 3: Collect notes

Ask: "What did you work on? Paste any notes, accomplishments, or items to log." If today's journal already has content beyond the placeholder, show it first and ask what to add.

## Step 4: Update today's journal

Add the notes to today's journal, using the `journal-entry` skill's append convention (never a full-page replace - that would wipe any other content already on the page):

- Named topics (project work, decisions, meetings-equivalent) get their own `##` heading.
- Miscellaneous items go as bullets directly under the `#` heading.

Do not ask for confirmation before writing this part - just transcribe what he gave you.

## Step 5: Scan for highlights

Review today's notes for: shipped features/projects, recognition or praise from others, demos or things shared publicly, key decisions made or unblocked, notable outcomes.

If found, ask once per candidate item: "Should _[specific item]_ go into your highlights?"

If yes → update wiki page `writing/wins`:

- Fetch the current page. If it doesn't exist, create it (title `Wins`, path `writing/wins`, initial content `## {current year}`) - same parent-hierarchy-check pattern as other wiki pages in this setup.
- Prepend the entry under the current year's `## {YYYY}` section:

  ```
  - **{YYYY-MM-DD}:** {highlight text}
  ```

If no highlights were found, skip the question entirely - don't ask and have him say "nothing."

## Step 6: Reflection

**Fold-in check (before asking):** check `~/.claude/daily-checkin/state.json` for today's date. If today's daily personal check-in rotation is NOT yet resolved, plan to ask its question as a fifth prompt in the same batch below (using today's rotation category) - not as a separate interruption. If the rotation is already resolved (by `check-in`'s catch-up step, or earlier this session), skip this - don't ask twice.

Ask these questions together (four, or five if the fold-in check above added one):

1. "Describe your day in a few words."
2. "Any blockers to note?"
3. "What was your most important accomplishment today?"
4. "What's the most important thing you need to do tomorrow?"
5. (If folded in) the daily personal check-in rotation's question for today's category.

After he answers, if the fold-in question was asked: store that answer to nornicdb under tags "personal", today's category, then run:

```bash
~/.claude/scripts/daily-checkin-hook.sh --mark
```

Log the four reflection responses under `## Reflection` in today's journal, using the same append convention as Step 4:

```markdown
## Reflection

- Day in a few words: [response]
- Blockers: [response or "None"]
- Most important accomplishment: [response]
- Most important thing for tomorrow: [response]
```

(The fold-in question's answer goes to nornicdb per above, not into this `## Reflection` block - it's a separate category-rotation record, not part of the four-question reflection log.)

## Step 7: Carryover TODOs

Scan today's notes and reflection for explicit carryovers or `TODO` items. List them and ask which should carry into tomorrow's plan.

Create tomorrow's journal entry if it doesn't exist yet (via the `journal-entry` skill's conventions), seeded with the confirmed carryovers as bullets under the `#` heading.

Creating tomorrow's entry via the full `journal-entry` skill flow will also trigger its own Step 4.5 (automatic 7-day `- [ ]` checkbox scan into a `## Carried over` section) - let that run as normal, don't suppress it. The two carryover sources are complementary, not duplicates: journal-entry's Step 4.5 only picks up literal `- [ ]` checkbox lines from past journal pages, while this step's confirmed carryovers come from today's session notes/reflection (which may not be checkbox-formatted). If the same item would appear in both (he wrote it as a checkbox in today's notes AND it's still unchecked when Step 4.5 scans), that's fine - a duplicate reminder isn't harmful, and Step 4.5's migrate-not-copy logic already prevents it from duplicating across multiple days.

## Step 8: NornicDB store

After the wiki writes in Steps 4-7 have succeeded, call `mcp__nornicdb__store`:

- For the reflection: `content` = the four reflection answers as one block, `type: "Reflection"`, `tags: ["check-out", "{YYYY-MM-DD}"]` (add the personal category as an extra tag if Step 6's fold-in ran).
- For each confirmed highlight: `content` = the highlight text, `type: "Highlight"`, `tags: ["check-out", "{YYYY-MM-DD}"]`.

These are two separate stores from the fold-in question, if one was asked: Step 6 already wrote that answer to nornicdb as the personal-checkin category record; this step's own Reflection node is check-out's separate session record and may reference the same day's category as a tag, but is not a duplicate of Step 6's write.

Wiki is the durable, human-readable record; NornicDB is a supplementary, queryable layer on top - if the NornicDB call fails, note it in `memory.md` and move on. Never block or retry the routine over it.

## Step 9: Eval loop

Self-check this session against `eval.md`, inline - no sub-agent needed, this is a quick pass. If a check FAILs on something fixable right now (vague journal entry, non-actionable TODO), fix it before finishing. If it's an observation for next time (e.g. highlight-detection threshold felt off), note it in `memory.md` instead of trying to fix it retroactively.

## Step 10: memory.md log

Log a 2-3 sentence skill-improvement observation to `memory.md`, reverse-chronological. Skip if nothing about the routine itself stood out this session.

---

## Notes

- Ad hoc trigger, same as `check-in` - don't assume one ran just because the other did.
- No Jira, no Confluence, no performance-review framing. `writing/wins` is personal record-keeping (portfolio/job-hunt material), not a work artifact - keep the tone accordingly.
