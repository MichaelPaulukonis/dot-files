---
name: blog-publish
description: Use when publishing a completed wiki draft to the blog. Triggers on: "publish this post", "move draft to blog", "post is ready to publish".
---

# Blog Publish

## Overview

Pulls a completed draft from Wiki.js via the `wikijs` CLI skill, extracts metadata, and writes a ready-to-commit `.md` file to `content/blog/`.

**REQUIRED:** Load `wiki-blog-conventions` first - it defines the expected wiki page format.

Target repo: `~/projects/michaelpaulukonis.github.io`. This skill is user-level, so the
working directory when it's invoked is not guaranteed to be inside that repo — use the
absolute path (`~/projects/michaelpaulukonis.github.io/content/blog/{slug}.md`, etc.)
for every read/write/git step below, don't assume a relative `content/blog/...` resolves.

## Steps

### 1. Fetch the wiki page

```
python3 ~/.claude/plugins/marketplaces/claude-wikijs-skill/skills/wikijs/scripts/wikijs.py get writing/blog/drafts/{slug}
```

If path unknown: `python3 ~/.claude/plugins/marketplaces/claude-wikijs-skill/skills/wikijs/scripts/wikijs.py search {query}` to find it. (Remember to source `~/.config/wikijs.env` first — see the `claude-wikijs-skill` plugin.)

### 2. Extract blog-meta block

- Find the fenced ` ```blog-meta ` block at the top of page content
- Parse the YAML inside it
- Post body = everything after the closing ` ``` ` of that block

### 3. Build frontmatter

Map fields directly (drop `slug` - filename only):

```yaml
---
title: {title}
headline: {headline}
description: {description}
date: {date}
dateUpdated: {dateUpdated}
author: {author}
authorUrl: {authorUrl}
tags:
  - {tags}
socialImage:
  src: {socialImage.src}
  mime: {socialImage.mime}
  width: {socialImage.width}
  height: {socialImage.height}
  alt: {socialImage.alt}
---
```

### 4. Write the file

Path: `~/projects/michaelpaulukonis.github.io/content/blog/{slug}.md`
Content: frontmatter block + newline + body

### 5. Check images

List all `![...]` refs in body + `socialImage.src`. Confirm each exists in `~/projects/michaelpaulukonis.github.io/public/media/`. Flag missing files - do not commit until resolved or stubs noted.

### 6. Commit

```
feat(blog): publish "{headline}"
```

Run from inside `~/projects/michaelpaulukonis.github.io` (or `git -C` that path).

## Notes

- `socialImage.src: /media/default-social.jpg` = placeholder. Remind user to replace before sharing.
- `pinned` in tags = post appears on home page mosaic.
- `dateUpdated: null` is valid when publishing for the first time.
