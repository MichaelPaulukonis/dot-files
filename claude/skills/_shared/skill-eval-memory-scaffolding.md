# Skill Eval + Memory Scaffolding

Reusable templates for adding self-improving eval loops and session memory to any skill. Based on Peter Yang's 5-step pattern:

- Article: <https://creatoreconomy.so/p/full-tutorial-build-self-improving-claude-skills-in-20-min>
- Transcript source repo: <https://github.com/petergyang/behind-the-craft-transcripts>

## eval.md template

Drop this alongside SKILL.md. Customize the checks per skill.

```markdown
# {skill-name} eval

Run after the skill produces output. Answer each check PASS or FAIL. If FAIL, quote the problem and state the fix in one sentence. Fix all FAILs before returning output.

## Structure
1. {Check that the output has the right shape/sections/format}
2. {Check that required elements are present}

## Voice
3. Free of banned vocabulary? (see ~/.claude/skills/writing-style/SKILL.md)
4. Free of AI-slop patterns: throat-clearing openers, binary contrasts ("This is not X. It's Y."), colon reveals, fake-profound kickers, summary-recap endings, rhetorical questions as transitions?
5. Active voice, human subjects, direct verbs?

## Substance
6. {Domain-specific quality check - e.g. "Are claims quantified?"}
7. {Domain-specific quality check}

## Audience fit (if applicable)
8. {Mode-specific check - evaluate only the matching mode}
```

### Eval design rules

- **Pass/fail only.** No 1-5 scores - AI can't reliably discriminate gradations.
- **Mirror SKILL.md headings.** Each skill section should have a corresponding eval check.
- **8-14 checks.** Fewer = too coarse; more = diminishing returns and slow loops.
- **Voice checks 3-5 are reusable across skills.** Copy them verbatim.
- **Substance checks are skill-specific.** These are the ones that matter most - write them from experience using the skill, not up front.

### Wiring the eval loop in SKILL.md

Add a step near the end of SKILL.md:

```markdown
## Step N: Eval loop

**Preferred: spawn a separate eval sub-agent** with this prompt:

\```
You are an evaluator. Read the output below and check it against each numbered
item in ~/.claude/skills/{skill-name}/eval.md

For each check, answer PASS or FAIL. If FAIL, quote the specific problem and
state the fix in one sentence.

Output:
{draft}
\```

**If sub-agent spawning is not available:** read eval.md yourself and run
the checks inline.

**Loop behavior:**
1. Run eval against current output
2. On any FAIL: fix (minimum effective edit - do not rewrite from scratch)
3. Re-run eval
4. Repeat until all pass, or 3 iterations
5. After 3 iterations: return best version with note listing unresolved checks
```

## memory.md template

```markdown
# {skill-name} skill memory

Reverse-chronological. Skill-improvement observations only - not output quality
(that is eval.md's job). Keep entries to 2-3 sentences per session.

## Log

{YYYY-MM-DD}: Skill created. {One-line note on initial design choice or lesson.}
```

### Memory design rules

- **Skill improvement only.** "The eval loop caught X" belongs in eval.md as a new check, not here. Memory is for things like "audience detection works better when we ask up front" or "the examples overfit when there's only one per mode."
- **2-3 sentences per session.** Longer = context bloat, model starts ignoring it.
- **No overlap with eval.md.** If it can be a pass/fail check, make it one instead.
- **Reverse-chron.** Most recent at top of the log section.
- **Optional.** Not every skill needs memory. Good for skills with subjective output (writing, pitches, reviews). Skip for mechanical skills (scaffolding, data fetching).

## When to add evals vs. memory to an existing skill

| Signal | Add eval.md | Add memory.md |
| --- | --- | --- |
| Output has known quality criteria | Yes | - |
| You keep giving the same feedback | Yes (make it a check) | - |
| Feedback is vague / taste-based | - | Yes |
| Skill is mechanical (create page, fetch data) | Probably not | No |
| Output is subjective (writing, pitches, reviews) | Yes | Yes |
| You want the skill to self-correct without you | Yes (with loop) | - |
| You want the skill to learn across sessions | - | Yes |
