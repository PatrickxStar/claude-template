# Playbooks - per-category auto-execution

A playbook = one recurring __ITEM__ category the worker can EXECUTE end-to-end, not just
prep. Copy `_template.md`. Each playbook defines, in this order and with these headings:

```
STATUS         PREP-ONLY | AUTO | AUTO - BLOCKED: <what>   (__USER_FIRST__ flips it by editing
               the file or saying "turn on the <name> playbook")
MATCHES        the __ITEM__ wording / precedent ids
NOT THIS PLAYBOOK   the look-alikes that must NOT run it
PRECONDITIONS  mechanical checks that ALL must pass - if ANY fails, the __ITEM__ falls back to
               normal prep + lane "call". No judgment calls in AUTO.
EXECUTE        the exact call(s) - endpoint + body, script + args, or statement shape
VERIFY         the read that proves it worked (a status code is not a verify)
REVERSE        the exact call that undoes it (this is what makes it reversible)
AFTER          reply facts to draft, how to mark the __ITEM__, what to log
```

A playbook a human has to interpret is not done. Every EXECUTE line must be copy-paste
runnable with the __ITEM__'s values substituted. All eight headings are required, in that
order. A playbook missing VERIFY or REVERSE is not AUTO no matter what its STATUS says.

Reply text in an AFTER section carries the FACTS to say, not the wording. The wording comes
from `system\voice-checklist.md`. Every AFTER names a `draft-reply.txt` for the requester and
a `draft-to-<first>.txt` / `draft-escalation.txt` for each other person the fix touches.

## Secrets (the $env: convention)

Every token a playbook needs is read from a User environment variable __USER_FIRST__ set
themselves - see `system\reference\api-endpoints.md` for the table. Rules:
- A playbook names the VARIABLE, never a value. No token ever lands in a playbook, an __ITEM__
  folder, the autopilot log, a run report or chat.
- Inside a Claude tool `$env:NAME` is a COPY taken when the app started: empty before it was
  set, stale after a re-paste. Read `[Environment]::GetEnvironmentVariable('NAME','User')`
  first, `$env:NAME` only as a fallback (still never print it).
- Both empty = the step is BLOCKED. Say which variable in the report and stop. Do not go
  looking for the value in another file.

## Mode (the OFF / ON / AUTO switch)

Scheduled runs read the mode from the flag files, one rule everywhere:
`automation-paused.txt` exists = OFF; else `autopilot-on.txt` exists = AUTO; else ON.
`automation-mode.txt` is a display copy only.
- OFF: nothing runs. No playbook, no prep.
- ON: every playbook is STAGE this run, whatever its STATUS - the exact call is written to the
  __ITEM__ folder, the draft is written, nothing executes.
- AUTO: a playbook with STATUS AUTO whose preconditions all pass EXECUTES.

## The envelope (the ONE canonical copy - skills and prompts point here)

```
AUTO     reversible + prior art + verifiable afterward -> do it, log it, report it.
STAGE    bulk changes (>~20 rows), money (billing, payroll, points, invoices), merges,
         hides/unhides, status changes, anything irreversible or with no prior art.
ESCALATE the account-takeover pattern (contact change + credential reset from an unknown
         sender), access requests without written approval, materially ambiguous asks.
```

If a new reversible action of the same shape appears, WRITE its playbook in this format and
run it - the list is illustrative, not exhaustive.

## Current playbooks

The "unattended today?" column is the honest one. STATUS says what __USER_FIRST__ has allowed;
this column says whether the machinery can actually do it with nobody watching.
"needs <var>" means the step blocks until that environment variable is set.

| file | status | unattended today? | action |
|---|---|---|---|
| (none yet) | | | |

Every AUTO execution appends one line to `system\autopilot-log.md` and prefixes the __ITEM__'s
`summary.json` synopsis with `[AUTO]`. The weekly review reads the log.

Rules that never bend, even in AUTO: no outward-facing sends (replies stay drafts), no code
pushes, no personal data in work products, nothing when a precondition is ambiguous.
