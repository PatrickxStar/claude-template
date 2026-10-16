---
name: _skill-template
description: >-
  Copy this folder to make a new skill. A skill is one recurring job written down so a model
  can run it the same way every time. (Rename the folder and this name; the description is
  what the model reads to decide whether to use the skill, so lead with the trigger phrases.)
disable-model-invocation: true
---

# <Skill name> - <one line: what it does, in plain words>

## When to use (trigger phrases)

The frontmatter `description` is truncated at about 1,500 characters when the model decides
whether to use a skill. Keep the highest-signal phrases there and put the rest here:
- "<how people actually ask for this>"
- "<a title shape the __ITEM__ usually has>"
- "<a screen or feature name>"

## NOT this skill

- <the look-alike that must go somewhere else, and where>

## First move

The ONE cheap check that decides who owns the fix (ours / another team / a vendor). Every
run starts here, before any diagnosis.

## Inputs

- <what you need in hand: an id, a URL, a file>
- Secrets: name the environment variable, never a value. Read it with
  `[Environment]::GetEnvironmentVariable('<NAME>','User')` first, `$env:<NAME>` as the fallback.
  Both empty = BLOCKED, say which.

## Steps

1. <action, exactly what to run / open / read>
   EXPECT: <what a normal result looks like>
   IF-NOT: <what a different result MEANS and whether to STOP or continue>
2. ...

Every step is copy-paste runnable by someone who does not think. Control every negative: an
empty result needs a sibling known to work, run the same way, or it proves nothing.

## Writes (if any)

- Reversible + prior art + verifiable -> write a playbook in `__WORK_ROOT__\system\playbooks\`
  (copy `_template.md`) and point here. Otherwise STAGE: the exact statement or call in the
  __ITEM__ folder, never executed.
- Record the PRIOR value first. VERIFY is a read, not a status code. Log the exact reversal.

## Reply

Facts the reply must carry, and must NOT carry (back-end names, promises, dates). The words
come from `__WORK_ROOT__\system\voice-checklist.md`, never from this file.

## Known traps

- <a dated line per thing that went wrong once and must not again: what happened, the rule>

## Codified from

<the ids this skill was built from, so the next person can read the originals>
