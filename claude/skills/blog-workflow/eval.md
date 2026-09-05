# blog-workflow eval

Run after Stage 2 (Ramble → Draft) or Stage 4 (Polish) produces output, before showing it to him. Answer each check PASS or FAIL. If FAIL, quote the problem and state the fix in one sentence. Fix all FAILs before showing the draft.

## Structure

1. Body only touches the region between the `blog-meta` block and the `---`/ramble heading - ramble section and `blog-meta` fields untouched?
2. (Stage 2 only) Full accumulated ramble was used to regenerate, not just the newest addition?
3. (Stage 2, first draft only) Outline was proposed and confirmed before prose was written?

## Voice

1. Free of banned vocabulary? (see ~/.claude/skills/writing-style/SKILL.md)
2. Free of AI-slop patterns: throat-clearing openers, binary contrasts ("This is not X. It's Y."), colon reveals, fake-profound kickers, summary-recap endings, rhetorical questions as transitions?
3. Active voice, human subjects, direct verbs?

## Substance

1. Title/headline avoids numbered-insight framing, opposing-parenthetical titles, fake-tension setups, or clickbait structure - states plainly what the post is about?
2. Draft says what the ramble actually said - no invented examples, claims, or conclusions not present in his notes?
3. (Stage 4 targeted pass, e.g. "cut to 800 words") Only the one requested change was made - voice and untouched content preserved?
4. Does the post include a caveats/limitations section if the topic has known gaps or edge cases? (Skip if the topic is straightforward with nothing meaningful to caveat.)
5. Are named or coined terms credited when the source is known - not padding, just so an unfamiliar reader can look it up? (Generic terms don't need sourcing.)

## Process

 1. Draft/edit was shown to him, not written to Wiki.js, until this eval runs?
