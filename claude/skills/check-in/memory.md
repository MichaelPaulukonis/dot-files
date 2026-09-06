# check-in skill memory

Reverse-chronological. Skill-improvement observations only - not session content (that's the journal's job). Keep entries to 2-3 sentences per session.

## Log

2026-09-06 (first live run): Google Tasks OAuth had expired (`invalid_grant`) - non-fatal handling worked fine, presented briefing without it, re-auth'd mid-session with `gtasks login`. Once authed, "My Tasks" had 244 items (mostly link bookmarks) - only due-dated items are worth surfacing; a full dump would be useless. `gtasks tasks update <N>` renumbers the list after any status change (done/update), so acting on two tasks in sequence needs a re-view between them, not the original numbering - hit this live, corrected before damage. An unprompted, genuine family detail volunteered mid-check-in (not asked for) reasonably satisfied today's pending daily-checkin rotation slot without a separate artificial question - worth treating real volunteered content as fulfilling the rotation when it fits the pending category. Mempalace write can fail with "peer MCP writer active" (another connection holds write lock) - non-fatal, NornicDB alone still captured the fact.

2026-09-05: Skill created, replacing the work-only `workday-start` skill for personal use. No Jira, no fixed-workday date script - "yesterday" is just yesterday. Pulls tasks from three sources (Google Tasks, beads, wiki TODOs) rather than one, since Tasks is still cluttered and unconsolidated.
