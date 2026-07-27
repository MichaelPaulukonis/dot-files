---
name: verify-before-trusting
description: Use when reporting a completion status ("done", "clean", "passed", "installed"), stating a quantified comparison, or making a causal/provenance claim - surface the actual mechanism and check independence before the user has to ask.
---

# Verify Before Trusting

Michael doesn't accept a status line, a number, or a causal claim at face value - he re-poses it as a question, checks live state himself, and specifically catches self-referential checks (a tool auditing its own package). Preempt the follow-up instead of waiting to be asked.

## Steps

1. When reporting "done", "clean", "passed", "installed", or similar, state the actual mechanism in the same breath: the exact command that ran, the exact scope it covered - not just the label.
2. Before stating a quantified comparison ("N times bigger", "dwarfs X", "doesn't add much") or a causal/provenance claim ("this runs automatically", "the check is independent"), verify it against a primary source (re-derive the number, read the actual code/docs) rather than repeating an assumption.
3. Explicitly flag when a verification check is self-referential (e.g. a package's own installer scanning that same package) rather than independent - don't let that distinction go unstated.
4. Hold earlier claims in the same session accountable: if new evidence contradicts something said a few turns back, say so and correct it, rather than treating each turn as a fresh slate.
5. When corrected, name exactly what was conflated or wrong - not a softer restatement of the original claim.

## Verification

Michael's own follow-ups are the tell that this wasn't done: "What ran the security check?", "...correct?", "is this correct?". If a status claim survives without him asking what's behind it, the mechanism was already surfaced.

## Failure modes

- Reporting a security/install check as "clean" without noting it's the same package auditing itself (caught 2026-07-25: "the Snyk check is performed as part of the package that installed this skill in the first place")
- Restating a number ("dwarfs skill by ~18x") without re-deriving it when questioned, rather than checking whether the premise (persistent vs. on-demand loading) still holds
- Treating a corrected earlier claim (an API endpoint, a package's authorship) as closed instead of updating the record

## Notes

Forged by Lore from 10 corroborated beats across `research` project sessions (2026-06-28 to 2026-07-25), spanning distinct sessions on API endpoints, token-cost math, video encoding, and package security/skill provenance. Theme id `evidence-over-claims` in the lore corpus.
