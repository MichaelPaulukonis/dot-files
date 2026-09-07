# named-persona-adversarial-review eval

Run after the skill produces output (all persona reviews + synthesis). Answer each check PASS or FAIL. If FAIL, quote the problem and state the fix in one sentence. Fix all FAILs before returning output.

## Structure

1. Are exactly 3 personas used per round - 2 engineers + 1 mandatory product persona - each with Mindset/Priorities/Findings (or the zero-finding burden in place of Findings)?
2. Does the synthesis merge duplicate findings, count concurrences, and apply the promotion rule (NOTE→WARNING→CRITICAL→BLOCKER on 2+ persona agreement)?

## Voice

1. Free of banned vocabulary? (see `writing-style` skill)
2. Free of AI-slop patterns: throat-clearing openers, binary contrasts, colon reveals, fake-profound kickers, summary-recap endings, rhetorical questions as transitions?
3. Active voice, human subjects, direct verbs?

## Substance

1. Does every finding cite a real, sourced principle from `references/persona_principles.md` (or a verified equivalent) with an explicit confidence level (high/moderate/low) - and is no persona's lens used ungrounded?
2. Where the zero-finding burden applies, does it name 3+ principles the code demonstrably satisfies, with how - not just "looks fine"?
3. Was the Feynman Integrity Check genuinely run (not just recited), and did an all-NOTE-level round trigger a persona switch and re-review as required?
4. Is severity assigned correctly per the ladder - BLOCKER reserved for 2+ concurrence or security/data-loss, nothing promoted without genuine independent agreement?
