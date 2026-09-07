---
name: elevator-pitch
description: Draft or sharpen a short-form pitch for a tool, idea, project, or proposal. Use when the user wants to pitch something to anyone - a client, a collaborator, a stranger on the internet - or needs a "why we should do X" argument, or asks to write a pitch, proposal, or persuasion piece.
---

# Elevator Pitch

Draft or refine short-form persuasion: tool pitches, proposals, "why we should do X" arguments, conference abstracts, blog promotion blurbs, freelance pitches. Not limited to literal elevator pitches.

## Step 1: Get context

If the user provided a draft, use it. Otherwise ask two questions in one message:

1. What are you pitching, and what should the reader do or think after reading?
2. Who is the audience? (skip if obvious from context)

Do not ask more than this. Infer what you can from the draft or conversation history. There's no preset audience-mode system — use whatever the answer to #2 actually is (a client, a friend, a stranger on LinkedIn, a hiring manager) to guide tone directly in Step 3.

## Step 2: Draft the pitch

Apply the pitch anatomy. Every pitch needs all five elements, in roughly this order:

1. **Hook** - Open with pain, a number, or a bold claim. First sentence should make someone stop. Not context-setting, not definitions, not "In today's world of..."
2. **Stakes** - Why this matters now. What breaks, stalls, or gets worse without action.
3. **Mechanism** - What it actually does. Specific: name the checks, the steps, the tech stack. "Improves efficiency" is a fail. For an elevator pitch or short format, naming the stack (e.g. "a CLI in Rust" or "a wrapper script hitting the Jira API") is enough - stop there. Deep implementation detail (architecture, data flow, specific algorithms) belongs in a proposal doc, not a pitch.
4. **Objection anticipation** - Address the obvious pushback before the reader raises it. "This sounds like X" / "Why not just Y" / "Is this proven."
5. **CTA / next step** - One clear ask or action. Not "let me know what you think."

Load a matching example from `examples/` for craft reference, based on format and tone rather than a preset mode:

- **Dry, factual, mechanism-first** (README, technical audience): `examples/ruff-readme.md`
- **Bold reframe, metaphor-led** (homepage, product pitch): `examples/dagger-homepage.md`
- **Honest, caveat-aware** (blog/social promo): `examples/concise-eval-post.md`

### Quantify everything

Numbers are the strongest pitch tool. Use them wherever they exist. Patterns that work:

- **Scale of the problem:** "213 vulnerabilities, 111 past SLA" / "40,000 seats, 95% unused"
- **Speed/savings:** "10-100x faster" / "ticket to PR in 10 minutes" / "50-63% token reduction"
- **Scope:** "9 checks" / "replaces 7 tools" / "90% mechanical"
- **ROI math:** "1hr/person/week = $31M/year at $50/hr blended"

If the user hasn't provided numbers, ask: "Do you have any numbers - time saved, scale, speed, cost?" One specific number beats three vague claims. Round numbers are fine if exact ones don't exist ("~200 repos" beats "many repositories").

### Voice rules

Follow the `writing-style` skill for tone, banned vocabulary, and structural rules - don't duplicate that list here. In addition, for pitches specifically:

- No performance of enthusiasm; dry wit is fine; exclamation points are suspect
- Active voice, human subjects, direct verbs - no "the integration facilitates"

### Length targets by format

| Format | Target |
| --- | --- |
| Slack/DM message / verbal pitch | 3-5 sentences |
| Tool pitch / proposal section | 75-150 words, 1-2 short paragraphs |
| Blog promotion blurb | 3-6 sentences |
| Conference abstract | Per CFP requirements, same anatomy applies |

If the user specified a length or format, that overrides the defaults.

## Step 3: Eval loop

**Preferred: spawn a separate eval sub-agent** with this prompt:

```
You are an evaluator. Read the pitch below and check it against each numbered item in ~/.claude/skills/elevator-pitch/eval.md

For each check, answer PASS or FAIL. If FAIL, quote the specific problem and state the fix in one sentence.

Stated audience: {audience}

Pitch:
{draft}
```

**If sub-agent spawning is not available:** read `~/.claude/skills/elevator-pitch/eval.md` yourself and run the checks inline.

**Loop behavior:**

1. Run eval against the current draft
2. On any FAIL: fix the draft (minimum effective edit - do not rewrite from scratch)
3. Re-run eval
4. Repeat until all checks pass, or 3 iterations have run
5. After 3 iterations, return the best version with a note listing any unresolved checks

## Step 4: Return the result

Output in this order:

1. The final pitch (clean - no markup about the process)
2. **Audience:** what was given for Step 1's question 2
3. **What changed:** (if editing a user draft) 2-5 bullets of substantive changes. Skip if drafting from scratch.
4. **Eval:** one line per check that required a fix. If all passed first try, say so.
