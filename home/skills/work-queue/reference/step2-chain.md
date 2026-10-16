# Step 2 - the chain: Planner -> Runner -> Writer -> __USER_FIRST__

| Agent | Model tier | Reads | Writes | Returns |
|---|---|---|---|---|
| `planner` | strongest | the __ITEM__, memory, prior art, skills, playbooks | `runbook.md` | verdict line, owner line, path |
| `runner` | middle | `runbook.md`, the folder | `run-report.md`, `summary.json`, `findings.md`, staged files, `autopilot-log.md` line | the summary block |
| `writer` | cheapest | reply skeleton + FOR-WRITER facts + requester's first name | `draft-reply.txt`, `draft-to-<first>.txt`, `draft-escalation.txt` | VOICE header + draft |

## Why the split

- The strongest model thinks once, up front, with everything in view. A clean run never calls
  it again, so most __ITEMS__ cost one expensive turn.
- The Runner's only virtue is honesty: it executes literally and reports what actually came
  back. A MISMATCH is a feature - it means the plan met reality.
- The Writer sees only facts, never an earlier draft, so drift cannot accumulate.
- __USER_FIRST__ is always the fourth step. Nothing is sent, merged, or run against money
  without their click.

## Spawning brief (the whole prompt)

```
<id> - folder __WORK_ROOT__\<id>\
```
For a Planner revision add: `revision - read run-report.md`.
For the fast lane the Runner gets: `execute playbook <name> for <id>, then VERIFY`.

## The loop

```
planner(v1) -> runner
  CLEAN               -> writer -> audit gate -> report
  MISMATCH            -> planner(v2) -> runner (resume from the first revised step) -> ... planner(v3) max
  BLOCKED             -> lane "call", name the exact block, do not re-plan around it
  NEEDS-__USER_FIRST__-> lane "call", the ONE question, batched at the end of the run
```
In every branch the Writer still runs.

## The audit gate (cheap, on every draft)

Before the draft counts as ready, check: under the ceiling for its bucket; no back-end names
outside C; no promise, no date unless staged; every "I did X" is something that ran this run;
every fact present in run-report.md or the skeleton. A fail on voice = one Writer rerun from
the skeleton. A fail on facts = back to the Runner.

## Rules that do not change with the chain

Only one Runner may drive a browser at a time. When the chain is unavailable (an agent fails to
start), fall back to doing the three roles yourself in order, and say so in the report.
