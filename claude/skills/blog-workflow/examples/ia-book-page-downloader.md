```blog-meta
title: IA Book Page Downloader, a bookmarklet turned extension
headline: A Chrome extension for bulk-downloading archive.org page scans
description: A Chrome extension for downloading full-resolution scanned book pages from archive.org
date: 2026-07-25
dateUpdated: null
author: Michael Paulukonis
authorUrl: https://michael.paulukonis.github.io/
slug: ia-book-page-downloader
tags:
  - chrome-extension
  - archive-org
  - claude-code
  - collage
socialImage:
  src: /media/blog/ia-book-page-downloader/ia-book-page-downloader-social.png
  mime: image/png
  width: 1200
  height: 630
  alt: Extension popup over an archive.org book reader page
```

I loved working with physical paper and collage, but I don't really have the space/time these days. Instead I work with digital art in many different ways, and I've found that scans of old book pages can lead in some similar directions. There are a lot of different archive collections with free scans, and there's a great centralized collection of old, public domain works at the [Internet Archive](https://archive.org/details/texts). You can download PDFs or zips of jpegs, but they aren't always of the maximum resolution. For a while I was using [cemerson's bookmarklet](https://gist.github.com/cemerson/043d3b455317d762bb1378aeac3679f3): a JS bookmarklet that walks an archive.org reader's image URLs and prompts you through downloading them one at a time.

I also had to maximize the on-screen page-size, inspect the image to grab its actual URL, open that in its own tab, and click the bookmarklet. But it worked! I downloaded a lot of weird books. And often it was the blank, water-stained pages that were best!

And then I accidentally nuked all of my bookmarks (yes, they were backed up, but I didn't check for a month and so the backup got overwritten, long story).

So, since I had to get the bookmarklet back anyway, I thought I could take the opportunity to make it easier.

I had Claude Code turn it into a real Chrome extension — same URL logic under the hood, but now it's a toolbar icon. Click it, it auto-detects the current book's page count and image URL, you confirm a range, it downloads the lot at full resolution while you go to find more weird books to mine.

It's for personal use — unpacked, not on the Web Store — and it only touches freely-viewable scans. It doesn't touch material that's borrowed rather than public domain. I'm not trawling the whole site and downloading everything it finds, so as far as I know I'm not violating any TOS.

The code is on GitHub: [ia-book-page-downloader](https://github.com/MichaelPaulukonis/ia-book-page-downloader). If you also trawl archive.org for source material and don't want to load-unpacked an extension, the [original bookmarklet](https://gist.github.com/cemerson/043d3b455317d762bb1378aeac3679f3) still works fine.

---

## Original ramble (unedited)

*Raw notes this post was drafted from, kept verbatim.*

For the extension itself, I should have specified. Do not need to talk about the construction of it (phases etc) but we can mention the origin gist. I mainly want to point out this exists, that I built it with claude based on the gist, and automating most of the manual steps. I use pages from free books on Archive.org for art sources, and this allows me to pull them all down earily.

