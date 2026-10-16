# __USER_FIRST__'s Command Center

The work root. Scripts keep the queue in step; the `work-queue` skill works each new __ITEM__;
only in Auto mode does it EXECUTE a reversible fix that has an AUTO playbook - in Off or On
mode every fix stays a draft; everything renders into a dashboard. __USER_FIRST__ reviews,
copies, clicks, sends. Sending anything outward-facing is always their click.

## The switch: Off / On / Auto

One script, three modes. Nothing runs on its own unless __USER_FIRST__ sets it that way.

```powershell
powershell -ExecutionPolicy Bypass -File __WORK_ROOT__\system\toggle-automation.ps1 -Mode Off
powershell -ExecutionPolicy Bypass -File __WORK_ROOT__\system\toggle-automation.ps1 -Mode On
powershell -ExecutionPolicy Bypass -File __WORK_ROOT__\system\toggle-automation.ps1 -Mode Auto
```

- **Off** - scheduled runs wake up, see automation is off, and stop.
- **On** - runs happen. They read __ITEMS__, write drafts and staged fixes. They never click send and never execute a fix.
- **Auto** - same as On, plus: a fix that is safe and reversible (an "AUTO playbook" whose preconditions pass) is done by the run and logged.

No arguments = show the current mode, change nothing. `-DryRun` previews any change.

## Directory layout

```
__WORK_ROOT__\
|-- README.md               this file
|-- generate-dashboard.ps1  rebuilds dashboard.html from every summary.json
|-- dashboard.html          generated - open in a browser
|-- resolutions-log.md      one line per done __ITEM__ (feeds the weekly review)
|
|-- <id>\                   one folder per __ITEM__
|   |-- summary.json        feeds the dashboard card (contract below)
|   |-- findings.md         the investigation, AT-A-GLANCE box first
|   |-- runbook.md          the Planner's plan
|   |-- run-report.md       the Runner's real outputs
|   |-- draft-reply.txt     the reply in __USER_FIRST__'s voice
|   |-- prod-read.sql       a read only a person can run, with its branch map
|   `-- staged-fix.sql      a staged write, plain statements, never executed here
|
|-- reports\                report-<date>.md, briefing-<date>.md, review-<date>.md
|-- archive\                done folders older than 7 days (moved, never deleted)
`-- system\                 state files + helper scripts
    |-- toggle-automation.ps1   the switch
    |-- voice-checklist.md      how __USER_FIRST__ writes (fill in)
    |-- known-noise.md          what is never worked (fill in)
    |-- autopilot-log.md        every unattended write, one line, prior value + reversal
    `-- playbooks\              one file per fix that may run on its own
```

Reserved folder names under the root: `system`, `reports`, `archive`, `adhoc`. Everything
else directly under the root is treated as an __ITEM__ folder by the disk-gate hook.

## summary.json contract

```json
{
  "id": "12345",
  "title": "short title",
  "requester": "Name",
  "status": "open | done",
  "priority": "normal | critical",
  "lane": "ready | call | blocked",
  "category": "a short family name",
  "synopsis": "1-2 plain sentences; prefix [AUTO] when a write executed",
  "action": "ONE imperative sentence <=140 chars",
  "gotcha": "the single worst pitfall, or empty",
  "needs": "e.g. needs DBA, or empty",
  "waiting_on": "who, when lane=blocked",
  "steps": ["UI click-steps when the fix is a UI path"],
  "updated": "2026-01-01T09:00:00"
}
```

ASCII only (parsed by PowerShell 5.1). `status: done` moves the __ITEM__ to Done; also append
a line to `resolutions-log.md`: `- yyyy-MM-dd <id> <title> - <one-line resolution>`.

## How fixes get delivered

Ask first: **can this be done in a UI __USER_FIRST__ already has?**
- Yes -> numbered click-steps in `summary.json` `steps`.
- No -> the staged statement or call in the __ITEM__ folder. Plain, no transaction wrapper, the
  verification read after it. __USER_FIRST__ pastes and runs it.
- Needs access they do not have -> one line saying so, `needs` tag on the card, the request to
  whoever has it pre-written.

## System state files (system\)

| File | What it drives |
|---|---|
| `automation-mode.txt` | display copy of the mode: OFF, ON or AUTO (written by the switch; never read to decide) |
| `automation-paused.txt` | present in mode OFF; scheduled runs see this first and exit |
| `autopilot-on.txt` | present only in mode AUTO; its absence (`autopilot-off.txt` instead) means draft-only |
| `autopilot-log.md` | every unattended write, one line, prior value and reversal |
| `worker.lock` | start time + session title of the live run; stale after 60 min |
| `last-run.txt` / `last-sync.txt` | when any run finished / when the open list was last read in full |
| `usage-state.json` | budget numbers the usage-context hook prints each turn |
| `lesson-queue.jsonl` / `lesson-queue-reviewed.jsonl` | corrections captured by the hook; reviewed by `/lesson-review` |
| `known-noise.md` | patterns the worker never works |
| `voice-checklist.md` | the voice rules; "Learned from sends" grows from the mirror |
| `sent-examples.md` | the last real sends, rebuilt by the mirror step |

## Hard rules

Reads only, everywhere, outside an AUTO playbook in mode AUTO. Bulk changes, money, merges,
deletes, status changes are always STAGED, never executed. Nothing outward-facing is ever sent
without __USER_FIRST__'s click - drafts only. No personal data in any file. When a precondition
is ambiguous: stop, hand it to __USER_FIRST__.
