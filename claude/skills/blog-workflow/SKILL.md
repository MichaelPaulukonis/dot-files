---
name: blog-workflow
description: Michael's personal blog/LinkedIn writing pipeline (idea → ramble → AI draft → personal polish) on Wiki.js. Use when he wants to turn a rough idea or notes into a blog draft, regenerate a draft after adding more ramble notes, or get an AI-slop pass on a hand-edited draft before publishing. Composes wiki-blog-conventions, writing-style, and no-ai-slop — invoke those skills, don't duplicate their rules here.
---

# Blog Workflow

Four stages. Run independently, on request — never chain them automatically end-to-end. He said explicitly: not a fully-automated pipeline, an assist he steps into and out of.

1. **Idea** — plain bullet on `writing/blog/ideas`. Just the idea lifecycle from `wiki-blog-conventions`. No AI drafting here.
2. **Ramble → Draft** (repeatable) — see below.
3. **Personal edit** — happens outside Claude, in the Wiki.js UI. Nothing to do here.
4. **Polish** — see below.
5. **Move to published** — see below. Only after he's confirmed the post is actually committed/pushed/live — never trigger this on your own read of "looks done."

## Stage 2: Ramble → Draft

Trigger: he shares/pastes ramble notes for a post, or says "draft this," "update the draft from my notes," "regenerate the post."

This stage is expected to run **multiple times** as an idea develops. Each run is a full regeneration, not an incremental patch — the accumulated ramble is the source of truth, the generated body is disposable.

1. Determine the slug and whether `writing/blog/drafts/[slug]` already exists (check `ideas` and the drafts folder).
2. If new: create the draft page (parent = `writing/blog/drafts`), add a stub `blog-meta` block per `wiki-blog-conventions`, link it from `ideas` under `## Drafts`.
3. If existing: fetch the current page. **Append** the new ramble text to the `## Original ramble (unedited)` section — don't overwrite earlier notes, it's a running log across iterations, each addition kept verbatim.
4. **First draft only** (no generated body exists yet): propose a structure/outline from the ramble before writing prose. Show it, get confirmation, then proceed. Skip this on regenerations — a prior draft already implies structure; don't re-litigate it unless he asks to restructure.
5. Regenerate the polished body (everything between the `blog-meta` block and the `---` above the ramble heading) from the *full* accumulated ramble, applying `writing-style`. Replace the prior generated body outright.
6. Propose `title`/`headline` for the `blog-meta` stub against the current body — these aren't a byproduct of drafting the body, they need their own pass. Apply `writing-style`'s banned structures: no numbered-insight framing, no opposing-parenthetical titles, no fake-tension setups, nothing built to be clickable rather than accurate. State what the post is about, plainly.
7. Show him the new body (and any title/headline change) before writing it to Wiki.js. Only save after he confirms — same as the archive.org-extension post.

## Stage 4: Polish

Trigger: he says "polish this," "run it through no-ai-slop," "check this for AI slop," or asks for a final pass on something he's hand-edited.

Only touch the body between the `blog-meta` block and the `---`/ramble heading — never the ramble section, never the `blog-meta` fields.

1. Fetch the current draft body from Wiki.js (or take pasted text if he gives it directly).
2. Invoke the `no-ai-slop` skill's edit workflow on that body.
3. Show him the edited body plus its "What changed" section. Write back to Wiki.js only after he confirms.

If he instead asks whether something reads as AI-written, that's `no-ai-slop`'s detect job, not edit — same rule applies, don't rewrite unasked.

If he's stuck rather than asking for a slop pass — "this isn't working," "what's wrong with this" — that's a different job: diagnose, don't rewrite. Report where it loses focus, drifts from the point, or repeats itself. Wait for direction before editing anything.

A polish request can also be a single targeted pass instead of a full no-ai-slop edit — e.g. "cut this to 800 words" or "tighten just the opening." Handle these as one-change passes: make the one change asked for, preserve voice, skip the rest.

## Stage 5: Move to published

Trigger: he says the post is committed/pushed/live and to move the wiki page, or asks to clean up the wiki notes after a publish.

This is the `wiki-blog-conventions` idea-lifecycle step 3, in full:

1. Resync the draft's `blog-meta` block and body against the real `content/blog/{slug}.md` first — hand edits after the `blog-publish` promotion (headline tweaks, dropped periods, retitles) happen in the site repo and don't flow back automatically. Don't skip this; a stale "record" is worse than none.
2. Check `socialImage.src` isn't still `/media/default-social.jpg` (the placeholder per `wiki-blog-conventions`). If it is, flag it to him before moving on — don't move/publish silently on the default image.
3. **Don't move the page yourself with create+delete.** Recreating the page at the new path then deleting the old one destroys its revision history (already happened to `dragline` and `ia-book-page-downloader`). Move `writing/blog/drafts/[slug]` → `writing/blog/published/[slug]` with the `wikijs` CLI skill's `move` command (`wikijs.py move {ref} {destination}`, preserves history). The `wikijs` MCP server has been removed — the CLI script is the only interface now.
4. Once the page is at its new path, remove the slug's bullet from `ideas` entirely (both `## Drafts` and `## Ideas`).
5. While in there, check the `writing/blog/drafts` index page for staleness (missing entries, entries for pages that no longer exist) — it's hand-maintained and drifts.

## Notes

- Stages are independent entry points. Don't assume one just ran before another.
- Never auto-publish, promote, or move a draft to `published/` from here — every one of those is a separate, explicit request, triggered by him telling you it actually happened, not by you inferring it.
- Always confirm with him before writing to Wiki.js.
