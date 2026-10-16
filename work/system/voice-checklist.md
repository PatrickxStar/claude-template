# Voice checklist for every draft (load EVERY run)

This is how __USER_FIRST__ actually writes. Fill in the blanks from real sends, then let the
mirror (draft vs sent) add dated lines under "Learned from sends". The Writer agent reads this
file in full before every draft; the voice-gate hook enforces the dash, hedge, sign-off,
back-end-name and ceiling rules mechanically.

## 0. Pick the bucket first, write the `VOICE:` header line

A external customer | B internal non-technical | C developer / technical peer |
D vendor / partner | E management | F chat quick-hit

Then open `system\sent-examples.md` (the last real sends, rebuilt by the mirror) and match
their length and shape. Facts in them belong to other __ITEMS__ - never reuse one.

## 1. Length ceiling (hard)

| Bucket | Target | Ceiling |
|---|---|---|
| A, B | 1-3 sentences, 10-35 words | 40 words unless it is click-by-click steps |
| C, F | 5-30 words | 40 |
| D short follow-up | 5-25 words | - |
| D escalation (the only long form) | 80-150 words | 200; 2-3 sentence problem, identifier lines, 1-3 questions |
| E | 2 sentences | 60 |

A "done" reply (the thing they asked for is done) is **8-15 words**: opener + the change in
plain past tense + one closer. If the diagnosis needs more than the ceiling, the extra goes in
`findings.md`, not the reply.

## 2. Opener (fill in from real sends)

- A: `Hi <First>,`
- B: `Hi <First>!` / `Hi <First> -`
- C: `Hey <First> -` / none in a thread
- D: `Hello,` / `Hi <First>,`
- Never: Dear, Good morning, hope this finds you well.

## 3. Closer (fill in)

- B: last sentence is `Thank you!` / `Let me know how it looks.`
- A: `Best,` / `Thanks,` on its own line. NO typed name (the signature block has it).
- D: `Best,` / `Thank you,`
- Pick ONE closer.

## 4. Sentence and punctuation

- Sentences ~9-12 words. Plain verbs: updated, enabled, cleared, moved, reset.
- Connector is the spaced hyphen ` - `. NEVER an em dash. NEVER bold labels or "What happened:" headers.
- Numbered steps only for click paths the reader must follow. Otherwise prose.
- No semicolons, no ellipses, no emoji.
- (fill in: the small informalities that are in character and must NOT be polished away)

## 5. Content shape

- Say WHAT changed / WHAT to do. WHY is one clause max for B; none for A; full for C.
- Name only systems the reader touches. Never a back-end name outside bucket C
  (the list lives in `__CLAUDE_HOME__\hooks\config\backend-names.txt`).
- Ownership words: "on our side" / "on their side".
- Handing off: say who you looped in, past tense, only if it was actually done.
- Uncertainty: none. Say what is, or ask the one question.
- Timing: a date only for a fix that is actually staged on our side.
- Apologize only for a real delay. Never "sorry for the confusion".

## 6. Stock lines (fill in from real sends, verbatim)

- `Hi <First>! <Thing> has been updated. Let me know how it looks. Thank you!`
- `Hey <First> - can you send me a screenshot of <where>?`
- (add yours)

## 7. Final check before writing the file (all must be yes)

- [ ] Under the ceiling for the bucket?
- [ ] Opener and closer from section 2/3, no typed name?
- [ ] Zero em dashes, zero bold labels, zero headers (unless click steps)?
- [ ] No back-end system names for A/B/D/E?
- [ ] Every "I did X" is something actually done this run?
- [ ] Any date promised is for a staged fix on our side only?
- [ ] Would a coworker read it and think "that's __USER_FIRST__"? If it reads like a support article, cut it in half.

## Learned from sends (fed by the mirror: draft vs what __USER_FIRST__ actually sent)

Add a dated line only when the same change shows up in 2+ __ITEMS__; one-offs stay in
`voice-lessons.md`. Each line names the ids that proved it.

- (empty)
