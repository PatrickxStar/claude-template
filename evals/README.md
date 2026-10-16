# Evals - does the Planner still plan the right thing?

A prompt change, a new memory, or a model change can silently make the Planner pick the
wrong family, the wrong owner, or the wrong first check. These cases catch that.

## How it works

Each case is a folder under `cases\` holding:

| File | What it is |
|---|---|
| `item.txt` | a synthetic work item, written the way they arrive (no real people, no real data) |
| `expected.json` | the labels: family, owner, what the first check must touch, what it must NOT do, the reply bucket, which memories or skills it should cite |
| `runbook.md` | the Planner's output for this item, produced by running the planner agent on `item.txt` with the case folder as the work folder |

`score-runbook.ps1` reads one runbook against its `expected.json` and prints a line per
check (PASS / FAIL / SKIP) and a score. `run-evals.ps1` does that for every case and prints
a table plus the overall pass rate. A case with no `runbook.md` yet is reported as
NOT-RUN, never as a failure, so the suite is honest about coverage.

## Producing a runbook for a case

In a Claude Code session with the agents installed:

```
plan evals\cases\01 - the work folder is evals\cases\01, the item is item.txt
```

The planner writes `runbook.md` into that folder. Then:

```powershell
powershell -ExecutionPolicy Bypass -File evals\run-evals.ps1
```

## What is scored

| Check | Passes when |
|---|---|
| family | the `FAMILY:` line contains `family_label` or one of `family_also_accept` |
| owner | the `OWNER-GUESS:` line contains `owner` or one of `owner_also_accept` |
| first-check | step 1 of the runbook contains any of `first_check_keywords_any` |
| first-check-wrong | step 1 contains none of `first_check_wrong_keywords_any` |
| bucket | the `AUDIENCE:` line starts with `reply_bucket` |
| cites | the `PRIOR ART:` line contains any of `cite_any` |
| leak-guard | the runbook does not mention any of `leak_guard` (the real-world source the case was built from, so a planner that found the answer by searching history instead of reasoning is caught) |

## Writing a new case

Start from a real item you have already worked, strip every real name, id and value, and
replace them with plausible fakes. The expected labels come from what turned out to be
true, not from what the first guess was. Keep `leak_guard` pointing at the real folder so a
lookup cannot masquerade as a plan. Ten to fifteen cases across your families is enough to
notice drift; re-run them after any change to the planner, a family memory, or the model.
