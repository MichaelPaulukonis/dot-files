# adversarial-review eval

Run after the skill produces output (all three briefs). Answer each check PASS or FAIL. If FAIL, quote the problem and state the fix in one sentence. Fix all FAILs before returning output.

## Structure

1. Are all three briefs present - Prosecution, Defense, Judge - each with its required section headings intact (Thesis/Evidence/Existing Alternatives or Gap Analysis/Dimensions Checklist/Steel-man or Fatal Flaw Test/Verdict for Prosecution and Defense; Points of Agreement/Prosecution Wins/Defense Wins/Neither Addressed/Integrity Check/Verdict for Judge)?
2. Is the Judge's verdict exactly one of KILL | RESHAPE | KEEP | INVEST - not a hedge or a blend of two?

## Voice

1. Free of banned vocabulary? (see `writing-style` skill)
2. Free of AI-slop patterns: throat-clearing openers, binary contrasts ("This is not X. It's Y."), colon reveals, fake-profound kickers, summary-recap endings, rhetorical questions as transitions?
3. Active voice, human subjects, direct verbs?

## Substance

1. Does every Evidence bullet in both Prosecution and Defense carry a confidence tag (high/moderate/low), and is no low-confidence claim stated as settled fact?
2. Does the Dimensions Checklist address all six dimensions in both briefs, with at least one substantive sentence each - no dimension skipped or given a one-word non-answer?
3. Does the Judge's Integrity Check genuinely interrogate the verdict (would this hold if the briefs were unsigned? does the verdict lean on a low-confidence claim?) rather than just restating the question and moving on?
4. Does the final Verdict include all three required elements - the single strongest reason, the most important caveat, and the first concrete action - not just a recommendation on its own?
