# Example: concise output-style eval promotion

**Format:** blog promotion blurb

---

After a chat discussion of Claude Code's output-style: concise, I tested whether it actually saves tokens, or just feels like it does.

The numbers say concise cuts output tokens 50-63% on several one-off tasks. Most of it is straight compression in the body: shorter explanations, fewer words per point. (YMMV with long conversations, and 50% just feels too high.)

Output fidelity (did the answer hit the rubric) drops 7-27% - but a follow-up eval split that drop apart: it's decorative elaboration (type-hint suggestions, usage examples, test recommendations) getting cut, not correctness-relevant facts. On unprompted gotchas the model has to catch on its own - mutable-default warnings, silent failure modes, breaking-change flags - concise matched or beat default on every case tested. So: this is real compression, and the loss is real BUT the loss is limited to the stuff concise is supposed to cut, not the substance.

Also, Sonnet vs. Opus compression varies by task, not by model - which one compresses more switches depending on what you ask.

Longer writeup has the eval repo link, bugs encountered along the way, the follow-up eval, and the parts I'm less confident in: [link]

---

## Why this works

- **Hook:** "tested whether it actually saves tokens, or just feels like it does" - question the audience already has
- **Stakes:** Implied - if you're using concise, you should know what you're losing
- **Mechanism:** "50-63% token cut" and "7-27% fidelity drop" - specific numbers with specific scope
- **Objection anticipation:** "YMMV" and "50% just feels too high" preempt cherry-picking objections. "The loss is limited to the stuff concise is supposed to cut" reframes the fidelity drop as a feature
- **CTA:** "Longer writeup has..." - one clear pointer, not "reach out if interested"
