```blog-meta
title: Fairy Tale Generator, Still Running
headline: Fairy Tale Generator still works
description: 2014 project built on Propp's morphology turned into years of bolted-on hacks that, somehow, still runs.
date: 2026-08-10
dateUpdated: null
author: Michael Paulukonis
authorUrl: https://michael.paulukonis.github.io/
slug: fairy-tale-generator
tags:
  - generative-text
  - nanogenmo
  - fairy-tales
socialImage:
  src: /media/blog/fairy-tale-generator/fairy-tale-generator.thumb.png
  mime: image/png
  width: 512
  height: 332
  alt: Screenshot of the generator's output, the story "HEARTY OAKLEY"
```

NaNoGenMo (National Novel Generation Month) has one rule: write code that produces a 50,000-word novel. Not a good novel. A novel-shaped pile of words that have been piled up by code, not by hand. And believe me - the code is often not much better than the novel quality.

I built "Malepropp", aka "Fairy Tale Generator", for my second run at NaNoGenMo in 2014, and it's still limping along years later, which is either a testament to something or an indictment of everything.

The git logs contain this gem from 2019:
  
> Relocated an ancient version of nlp_compromise that worked. Ugh this code is awful.

/

![proppian fairy tale generator UI, with function checkboxes and a generated story below](/media/blog/fairy-tale-generator/fairy-tale-generator.screenshot.png)

The scaffold came from [Vladimir Propp](https://en.wikipedia.org/wiki/Vladimir_Propp), the Russian folklorist who broke fairy tales down into a fixed set of recurring components — the villain does villainy, the hero leaves home, a magical helper shows up. Propp's morphology reads like a fairy tale's skeleton with the meat stripped off, which looks like a gift to anyone trying to generate one programmatically — except Propp never built it as a generator. He was describing patterns already present in existing stories, not handing out a recipe for new ones.

I also found a [poetical rendering of Propp's components](https://web.archive.org/web/20061112014356/http://www.brown.edu/Courses/FR0133/Fairytale_Generator/gen.html) — someone's phrasing of each function as an evocative fragment rather than a dry taxonomic label. That turned out to be the actual trick. The fragments were specific enough to feel like they belonged to a story and vague enough that almost anything could follow them without breaking. Selected and stitched together, they cohered the way dreams cohere.

It's what I based my first version on (and the web version _still_ looks like it). But plain templating is a blunt instrument for something with a fairy tale's structure. Slotting phrases into fixed positions gets you sentences; it doesn't get you a shape that reads as a story building toward anything. I fought that mismatch instead of solving it. I got a working generator, not a good one — and I was writing this in JavaScript I'd generously describe as "learning as I went," which didn't help. As is often the case, my solution to structural issues is "more of the same" instead of pruning.

So I kept bolting things on. Over the next year or two, whenever an idea seemed like it'd make the output more interesting, it went in, with basically no regard for whatever structure the code had going in. At the time I had little to no understanding of JavaScript modules, but I wanted code that would work both in Node and in the browser. And it does! It just looks (and is) *awful*.

There hasn't been a commit in years, and it still runs — in a browser. It fires up and generates a fairy tale on command, same as it did the day I abandoned it. Granted, it mainly relies on string manipulation and concatenation, concepts that haven't changed much in JavaScript, though template literals came along since. It's not like I was relying on Flash or anything weird.

I've been using Claude Code to refinish it. While not dead, it might still be coming back to (a better) life!

Links:
- [malepropp](https://michaelpaulukonis.github.io/malepropp/) — live version
- [source](https://github.com/MichaelPaulukonis/malepropp)
- [FairyTalesBot](https://fairytalesbot.tumblr.com/) — the Heroku-hosted bot stopped running in 2021; I hope to bring it back to life soon
- [discussion during construction](https://github.com/dariusk/NaNoGenMo-2014/issues/6), NaNoGenMo 2014
- [NaNoGenMo 2014 entry](https://github.com/MichaelPaulukonis/NaNoGenMo2014/tree/master/propp.gen)

Sample story:

```
HEARTY OAKLEY

In the middle of the night in Belorechensk, a very unmotivated dragon known as Jessica the Unmotivated strode in.

Jessica attempted to deceive victim.

There was once an old shack that stood in the middle of a deep gloomy Belorechensk, and in the shack lived Oakley.

Oakley unwittingly helped Jessica.

The harvest was destroyed by Jessica. All in the Monastic State of the Teutonic Knights began to feel the pangs of hunger.

Oakley left shack to cut down the tallest tree in the forest with a herring.

Oakley was challenged to prove heroic qualities.

Oakley responded to this test.

Hearty Oakley found Confident Santa Claus.

"Gods be with you Confident Santa Claus" mused Oakley.

"Greetings, Oakley" replyed Confident Santa Claus.

"Well, you certainly are confident," said Oakley.

"Yes, I am," conceded Confident Santa Claus. "But it's been said that I'm also courageous!"

"Here," said Santa Claus, "you'll need this," and gave Hearty Oakley the Finite Shield.

"What's this?" asked Hearty Oakley.

"What does it look like?" replied Santa Claus. "It's a special, magical Finite Shield. Perhaps you can use it in your struggle with Jessica the Unmotivated."

"Thanks!" said a grateful Oakley.

Hearty Oakley set out for her shack.

So she went and had a goodish drink, and then started in search of Belorechensk.

Oakley's horse smote Katherine full swing with its hoof, and cracked her skull, and Hearty Oakley made an end of her with a club. So Oakley cut her into small pieces, which were buried throughout the woods. Katherine sits to this day in the pit - in Tartarus.

All of this took place long before you were born, so it's not surprising that you don't remember it. But it happened, and people speak of it still.
```

---

## Original ramble (unedited)

I want to work on one of my blog-post ideas - the Fairy Tale Generator. This was originally created for the first (???) NaNoGenMo - National Novel Generation Month (write code that writes a 50,000 word novel). It used Vladimir Propp's fairy-tale components as a template for building a structure. I had found some interesting poetical version that worked well in selecting bits and pieces that were fun to read, but were vague enough to cohere in their dream logic. Using plain templating for something as complex as a fairy tale didn't really work so well at the time, but I made a go of it, despite my atrocious Javascript skills of the time. I kept bolting things on over the next year, and the code got uglier and uglier - but it still runs! Good Lord (choke!).

