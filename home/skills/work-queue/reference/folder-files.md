# The __ITEM__ folder - files and their shapes

Everything about one __ITEM__ lives in `__WORK_ROOT__\<id>\`. Nothing loose in the root. Files
open as plain text, so ASCII only and the shapes below exactly.

| File | Written by | Purpose |
|---|---|---|
| `prompt.md` | conductor | __USER_FIRST__'s own words, verbatim, when attended |
| `<raw>.txt` / attachments | conductor | the __ITEM__ as received |
| `runbook.md` | planner | the plan, EXPECT / IF-NOT per step |
| `run-report.md` | runner | RAN / GOT / VERDICT per step, then the summary block; re-runs append |
| `findings.md` | runner | for __USER_FIRST__ and the ledger; AT-A-GLANCE box first |
| `summary.json` | runner / any session | feeds the dashboard card; contract in `__WORK_ROOT__\README.md` |
| `prod-read.sql` | runner | the read only a person can run; header says what each result DECIDES |
| `staged-fix.sql` / `staged-calls.txt` | runner | the write, staged, plain statements, followed by the VERIFY read |
| `draft-reply.txt` | writer | the requester's reply, `VOICE:` header, `---`, body |
| `draft-to-<first>.txt` / `draft-escalation.txt` | writer | one per other person the fix touches |
| `sent-reply.txt` | runner (mirror) | what __USER_FIRST__ actually sent, verbatim, `SOURCE:` first line |
| `note-to-__USER_FIRST__.txt` | any | a note to them, plain words, under 80 words |
| `SUPERSEDED-<date>-DO-NOT-SEND.txt` | writer | an older draft, renamed, never read again |

## findings.md

```
# <id> - <plain title>

AT-A-GLANCE
  What is wrong : <one plain sentence>
  Why           : <one or two>
  Owner         : ours | <team> | <vendor>
  Your click    : <the one thing __USER_FIRST__ does next>
  Status        : ready | call | blocked

WHAT I FOUND
<the evidence, ids, queries, in order>

WHAT I DID
<every write, with prior value and reversal, or "nothing executed">

WHAT IS LEFT
<staged items, open questions>
```

## Draft files

```
VOICE: <bucket> | <N> words | reader: <First> | checklist s7: pass
---
<body, ready to paste, one line per paragraph, no hard wraps>
```
The voice-gate hook strips the header at the `---` line and checks the body. A missing header
is treated as bucket B. Draft files are written with the Write tool only.

## Staged SQL / calls

Plain statements, no `BEGIN TRAN` / `COMMIT` / `ROLLBACK` (live or commented - the hook refuses
both). A modified-by value that names __USER_FIRST__ where the schema has one. The verification
read follows the write in the same file.
