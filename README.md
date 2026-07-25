# dot-files
various configs

## Claude Code skills

`claude/skills/` holds personal, hand-written skills (journal-entry, wikijs, wiki-blog-conventions, writing-style, image-frames-to-video) plus `claude-sync`, which backs this config up into version control in the first place. Skills bundled by third-party tools - `find-skills` (ships with `vercel-labs/skills`), `gtasks-cli` (ships with `BRO3886/gtasks`) - don't belong here and have been removed; those tools reinstall their own skill via their own command (`npx skills add ...`, `gtasks skills install`) straight into `~/.agents/skills/` or `~/.claude/skills/`. See `study/ai-ml/claude-code/skills-plugins` on the wiki for the full skill/plugin inventory and where each one actually comes from.

## Setup on a new machine

- `brew install gitleaks`, then re-create pre-commit hooks per docs/specs/2026-07-18-claude-sync-design.md (Secret scanning section)
