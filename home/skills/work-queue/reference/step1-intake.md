# Step 1 - the work list and intake

## 1a - the open list

The source of truth for "what is open and mine" is your queue system's own list, read
directly (its JSON endpoint, an export, a mailbox folder) - a screenshot only as the last
fallback. Only __ITEMS__ that are OPEN and assigned to __USER_FIRST__ are worked. An assignment
notification alone does not make an __ITEM__ open: confirm it against the list.

The work list = open list UNION every folder under `__WORK_ROOT__\` whose `summary.json` still
says "not yet worked" / "Pending worker run" or that has no `findings.md`. Two exceptions: a
folder whose status is `done` is never a stub, whatever its synopsis says; and a folder with
`runbook.md` but no draft and no `run-report.md`, with no worker live, IS a stub - that is how
a dead run hides an urgent __ITEM__.

Order: the families __USER_FIRST__ cannot fix alone (they have to ask someone) go FIRST.
Then oldest first.

## 1b - intake, per __ITEM__ (the ten items)

1. **Pull it.** The full text, every attachment, every image (open image links - never write
   "attachment not retrievable").
2. **Title the session** "__ITEM__ <id>" when attended, and save the prompt verbatim to
   `<id>\prompt.md`. __USER_FIRST__ browses history by id.
3. **Dedupe.** Same requester + same subject in the open queue this week = one root cause filed
   twice. Work the oldest, link the twin in both folders.
4. **Repeat check.** Search `archive\` and the lesson ledger for the same requester AND subject.
   A parked staged fix or an unfinished second half IS the answer. "What's the status of..."
   = find the original reply before re-diagnosing.
5. **Family.** Name it from memory `family_first_moves.md`, and run the ONE owner-deciding
   check first (ours / another team / a vendor).
6. **Prior art.** Search your team's history by key words (never the new id). Then the matching
   skill, playbook, memory, procedure page.
7. **Gather live evidence yourself** from every read-only source you have, instead of asking
   __USER_FIRST__ or the requester. A source that is unreachable gets a "Couldn't do + why" line
   and the run continues with everything else.
8. **Playbook match.** If an AUTO playbook covers it: fast lane. Else the full chain.
9. **Work product** in the folder (see `folder-files.md`). Every worked folder gets a
   `summary.json` the same pass.
10. **Write back.** `summary.json` status / lane / synopsis / action, then the report line.

## Noise

`system\known-noise.md` is the one list and it wins. A match = one line under "Noise" in the
report, no folder. Anything from inside your own organization is never noise unless that file
names it.
