---
name: adversarial-review
description: Stress-test a project/tool/proposal by launching parallel adversarial sub-agents (prosecution + defense), then a judge agent that synthesizes. Use when evaluating whether to keep, kill, or reshape something.
author: Michael Paulukonis
---

<what-to-do>

Run a structured adversarial review of the target the user names (a project directory, a proposal, a tool, a design doc, etc.).

For reviewing a specific PR or diff instead of a whole project, use `named-persona-adversarial-review` instead — that skill grounds findings in real engineers' documented philosophies rather than abstract roles.

## Phase 1: Parallel Advocates (2 sub-agents, launched simultaneously)

Launch both agents at the same time. Each independently reviews all source material.

### Agent: Prosecution

Prompt template:

```
Review {TARGET} thoroughly. Read all source files, README, config, tests, docs.

You are PROSECUTION. Make the strongest possible case that this should be killed, deprioritized, or radically reworked.

## Required sections (use these exact headings):

### Thesis
One sentence. Your core claim.

### Evidence
Bullet list. Each bullet: a specific, verifiable claim with code quotes or file references where applicable, plus a confidence level (high = directly verified in source, moderate = inferred from strong signals, low = speculative). No vague assertions, and never state a low-confidence claim as fact.

### Existing Alternatives
For each capability the target claims, name a specific existing tool or process that already covers it. Be precise - name the tool AND the specific feature.

### Dimensions Checklist
Address each. One sentence minimum per dimension. Skip none:
- Code quality and maintainability
- Docs accuracy (do docs match actual behavior?)
- Scope honesty (does it solve what it claims to solve?)
- Uniqueness (what does this do that nothing else does?)
- Maturity (tests, CI, error handling, edge cases)
- Adoption friction (setup cost vs value delivered)

### Steel-man
State the single strongest argument AGAINST your position. Explain why it's strong. Then explain why it still doesn't save the target.

### Verdict
2-3 sentences. Your recommendation and the single most damning fact.
```

### Agent: Defense

Prompt template:

```
Review {TARGET} thoroughly. Read all source files, README, config, tests, docs.

You are DEFENSE. Make the strongest possible case that this is valuable and should be kept, invested in, or expanded.

## Required sections (use these exact headings):

### Thesis
One sentence. Your core claim.

### Evidence
Bullet list. Each bullet: a specific, verifiable claim with code quotes or file references where applicable, plus a confidence level (high = directly verified in source, moderate = inferred from strong signals, low = speculative). No vague assertions, and never state a low-confidence claim as fact.

### Gap Analysis
What specific problem does this solve that nothing else in the org/ecosystem addresses? Be precise about WHY existing alternatives don't actually cover this.

### Dimensions Checklist
Address each. One sentence minimum per dimension. Skip none:
- Code quality and maintainability
- Docs accuracy (do docs match actual behavior?)
- Scope honesty (does it solve what it claims to solve?)
- Uniqueness (what does this do that nothing else does?)
- Maturity (tests, CI, error handling, edge cases)
- Adoption friction (setup cost vs value delivered)

### Fatal Flaw Test
Name the single thing that would kill your case if true. Argue specifically why it isn't true, or why it's fixable without undermining the core value.

### Verdict
2-3 sentences. Your recommendation and the single most compelling fact.
```

## Phase 2: Judge (1 sub-agent, after both Phase 1 agents complete)

Send BOTH briefs to a third agent:

```
You are JUDGE. You have received two adversarial briefs about {TARGET}.

## Prosecution Brief:
{prosecution_output}

## Defense Brief:
{defense_output}

## Your task:

### Points of Agreement
Where do both sides actually agree? These are likely facts.

### Prosecution Wins
Arguments where prosecution is stronger, with why. Quote specific evidence from their brief.

### Defense Wins
Arguments where defense is stronger, with why. Quote specific evidence from their brief.

### Neither Addressed
Important dimensions or questions that both sides missed or glossed over.

### Integrity Check
Before writing the verdict, check yourself: is this verdict following the stronger evidence, or the side you found more persuasive to read? Would you reach the same verdict if the briefs were unsigned? If a claim in either brief was tagged low-confidence, does the verdict lean on it anyway - and if so, say so explicitly rather than letting it pass as settled fact.

### Verdict
One of: KILL | RESHAPE | KEEP | INVEST

Follow with 3-5 sentences explaining the verdict. Include:
- The single strongest reason for the verdict
- The most important condition or caveat
- The first concrete action the owner should take
```

## Phase 3: Eval loop

**Preferred: spawn a separate eval sub-agent** with this prompt:

```
You are an evaluator. Read the output below and check it against each numbered
item in ~/.claude/skills/adversarial-review/eval.md

For each check, answer PASS or FAIL. If FAIL, quote the specific problem and
state the fix in one sentence.

Output:
{prosecution_output}
{defense_output}
{judge_output}
```

**If sub-agent spawning is not available:** read `eval.md` yourself and run the checks inline.

**Loop behavior:**

1. Run eval against the current three briefs
2. On any FAIL: fix (minimum effective edit - do not rewrite from scratch)
3. Re-run eval
4. Repeat until all pass, or 3 iterations
5. After 3 iterations: return best version with a note listing unresolved checks

## Output

Present all three briefs to the user in order: Prosecution, Defense, Judge. Use `##` headings to separate them. Don't editorialize beyond what the judge produced.

</what-to-do>

<notes>

- All three agents should use model "sonnet" for cost efficiency
- Phase 1 agents MUST be launched in parallel (same function_calls block)
- Phase 2 judge MUST wait for both Phase 1 agents to complete
- If the target is a directory, tell agents to read all files in it
- If the target is a URL or doc, tell agents to fetch/read it
- The user may specify additional context or attitude - weave it into the prompts but keep the required structure

</notes>
