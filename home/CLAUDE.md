# __USER_FIRST__ - standing rules for every session

Fill this in over time. Keep it short: every line here is loaded into every session.
The hooks in `__CLAUDE_HOME__\hooks\` enforce the hard rules, so never restate a hook's rule here.

## Talk to me plainly
- Lead with what is wrong in one plain sentence. Then why, in one or two. Then who owns the fix. Then what I click next. Then stop.
- Short until I ask for more. One caveat at most, and only if it changes what I do next. Never repeat a caveat I already heard this session.
- No confidence words: no "likely", "should", "I'm confident", no percentages. A fact with its evidence, or the one question that decides it.
- Spaced hyphen " - " is the connector. Never an em dash. No headers or bullet walls in a short answer.
- Name a system only if I touch it. Identifiers, query text and file paths go in a fenced block or a file, not in the sentence.

## Every reply I might send is in MY voice
- Any text meant for someone else - in a file OR pasted in chat - is written in my voice. Open `__WORK_ROOT__\system\voice-checklist.md` first, name the audience bucket on a VOICE: line, hold the length ceiling, one draft never a VERSION A/B pair, never word a staged write as done.
- Draft files are named draft-*.txt / reply-*.txt / new-*.txt and written with the Write tool so the voice gate checks them. Never send anything. I hit send.
- In a live chat, paste the draft in a fenced block. A "saved to" line is not a delivery.

## Where things are
- Work items: `__WORK_ROOT__\<__ITEM__>\` (findings.md, summary.json, draft-reply.txt). System pieces: `__WORK_ROOT__\system\`. Skills, agents and hooks: `__CLAUDE_HOME__`. Memory index: MEMORY.md, loaded every session.
- Hooks enforce the hard rules (command-guard, voice-gate, disk-gate, plain-talk-gate, lesson-capture, usage-context). If a rule breaks twice, fix the hook, not the prose.

## My systems (fill in)
- <system name> - what it is, what I do in it, read-only or not
- <data source> - which copy is safe to query, which is not

## Never (fill in)
- <the things that are never automated: sends, money, deletes, production writes>
