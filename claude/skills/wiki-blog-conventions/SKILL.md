---
name: wiki-blog-conventions
description: Use when creating a blog draft in Wiki.js, checking required metadata fields, or preparing wiki content for publishing to michaelpaulukonis.github.io
---

# Wiki Blog Conventions

## Overview

Blog posts are drafted in Wiki.js and published to the Nuxt 4 static site. Wiki.js reserves YAML frontmatter, so post metadata lives in a fenced `blog-meta` code block at the top of each wiki page.

## Wiki Page Structure

```
writing/
  blog/
    ideas          ← ## Drafts (linked, in progress) + ## Ideas (flat, undrafted)
    drafts/
      [post-slug]  ← one page per draft
  linkedin/
    drafts/[post-slug]
  medium/
    drafts/[post-slug]
```

## Idea Lifecycle

The `ideas` page tracks unfinished things — an idea is "unfinished" until published, not just until drafted.

1. **Undrafted**: plain bullet under `## Ideas`.
2. **Drafted**: once `writing/blog/drafts/[slug]` exists, move the bullet to `## Drafts` and link it: `- [slug](/writing/blog/drafts/slug)`.
3. **Published**: remove the bullet from `ideas` entirely (both sections). The draft page itself is the record.

Drafts stay listed on `ideas` for as long as they're in progress — a started draft is still an open idea, not a finished one.

## blog-meta Block

Place at the very top of the wiki page, before any body content:

````
```blog-meta
title: Full post title
headline: Short display headline (used in cards/mosaic)
description: 1-2 sentence summary for SEO and previews
date: 2026-06-28
dateUpdated: null
author: Michael Paulukonis
authorUrl: https://michael.paulukonis.github.io/
slug: post-slug-here
tags:
  - tag1
  - tag2
socialImage:
  src: /media/filename.jpg
  mime: image/jpeg
  width: 1200
  height: 630
  alt: Description of image
```
````

## Fields

| Field | Required | Notes |
|-------|----------|-------|
| `title` | yes | Full title |
| `headline` | yes | Short version for cards |
| `description` | yes | SEO summary |
| `date` | yes | ISO 8601: `2026-06-28` |
| `dateUpdated` | yes | ISO 8601 or `null` |
| `author` | yes | Always `Michael Paulukonis` |
| `authorUrl` | yes | Always `https://michael.paulukonis.github.io/` |
| `slug` | yes | Drives filename: `content/blog/{slug}.md` |
| `tags` | yes | Array; `pinned` surfaces post on home page |
| `socialImage.src` | yes | Path under `/media/` in `public/` |
| `socialImage.mime` | yes | `image/jpeg` or `image/png` |
| `socialImage.width` | yes | Pixel width |
| `socialImage.height` | yes | Pixel height |
| `socialImage.alt` | yes | Alt text |

## socialImage Stub

If image isn't ready, use the default placeholder:

```yaml
socialImage:
  src: /media/default-social.jpg
  mime: image/jpeg
  width: 1200
  height: 630
  alt: michaelpaulukonis.github.io
```

Replace before pinning or promoting the post.

## Post Body

Write everything after the closing triple-backtick of the meta block as standard Markdown. Images reference `/media/` paths: `![alt](/media/filename.jpg)`

Images must exist in `public/media/` in the website repo before publishing.
