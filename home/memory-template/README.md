# Memory - how it works

Claude Code loads `MEMORY.md` into every session for the project. The other files are loaded
only when a line in the index makes them relevant, so the index is the whole budget: one line
per memory, a hook phrase after the dash, never content.

## One fact per file

```markdown
---
name: <short-kebab-case-slug>
description: <one-line summary, used to decide relevance during recall>
metadata:
  type: user | feedback | project | reference
---

<the fact. For feedback and project, follow with:>
**Why:** <the reason, so the rule survives when the situation changes>
**How to apply:** <what to do differently next time>
<Link related memories with [[their-name]].>
```

| Type | What it holds |
|---|---|
| `user` | who __USER_FIRST__ is: role, expertise, preferences |
| `feedback` | a correction or a confirmed approach, with the why |
| `project` | ongoing work, goals, constraints not derivable from the code; absolute dates |
| `reference` | a pointer to an external resource: URL, dashboard, page id |

## Rules that keep it useful

- **Dedupe before you write.** Search the folder for the key term; extend the ONE file that
  already covers it. Two memories that say the same thing get merged into the better-named
  file; the other is deleted and its index line fixed.
- **Never restate a hook's rule or an org policy.** The hook enforces it; a memory that
  repeats it drifts out of date and wastes the index.
- **No personal data.** Internal names and record ids are fine; customer names, government
  ids, dates of birth, account numbers are not.
- **"!!" is a trap marker.** Use it on the index line when the thing looked one way and was
  another ("!! blank list = the source sent nothing, not a bug on our side").
- **The ledger is a line, not a memory.** `lesson_ledger.md` gets one line per worked __ITEM__:
  `<id> -> <mechanism in six words> -> [[memory]]`. The self-audit at the end of every run:
  every `findings.md` under the work root has its id in the ledger.
- **Sections and index files.** When a section of `MEMORY.md` grows past ~15 lines, move the
  non-trap lines into `index_<section>.md` and leave one `ALL: index_<section>.md` pointer plus
  the "!!" lines.
- **Corrections become memories through the hook.** `lesson-capture.ps1` queues anything that
  looks like a correction; `/lesson-review` turns the durable ones into `feedback_*` files with
  __USER_FIRST__'s approval.

## Seed files in this folder

- `MEMORY.md` - the index skeleton
- `user_role.md` - fill in who __USER_FIRST__ is
- `feedback_workflow.md` - how an __ITEM__ is worked, in order
- `family_first_moves.md` - one owner-deciding check per family (starts empty)
- `lesson_ledger.md` - starts empty
- `feedback_memory_no_policy_restatements.md` - the rule above, as a memory
- `project_automation_system.md` - the system as installed; update when the schedule changes
