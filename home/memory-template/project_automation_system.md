---
name: project_automation_system
description: The automation system as installed - the schedule, the work root layout, the switch, the chain, the playbooks; update when any of those change
metadata:
  type: project
---

Installed from the Claude Autonomous System Template on <date>. Work products live in
`__WORK_ROOT__\`.

## Schedule (desktop-app scheduled tasks; fire only while the app is open)

| Task | When | Does |
|---|---|---|
| `work-queue-every-30` | every 30 min, working hours | the unattended worker; first run of the day also writes the briefing |
| `friday-review` | weekly | the personal review |

## The switch

`__WORK_ROOT__\system\toggle-automation.ps1 -Mode Off|On|Auto`. Off = runs exit at once.
On = drafts and staged fixes only. Auto = also execute AUTO playbooks whose preconditions pass.

## The chain

`planner` (strongest model) -> `runner` (middle) -> `writer` (cheapest) -> __USER_FIRST__.
Caps: 3 / 3 / 1 turns per __ITEM__. The hook `disk-gate` refuses to let any of them return
without its file on disk.

## Playbooks

`__WORK_ROOT__\system\playbooks\` - one per reversible fix; README there holds the envelope and
the honest "unattended today?" table. None yet.

**Why:** a session that does not know the schedule re-derives it from file dates and gets it wrong.

**How to apply:** update this file the same turn the schedule, the switch, or a playbook's
status changes.
