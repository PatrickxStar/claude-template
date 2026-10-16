---
name: lesson-review
description: >-
  Review the corrections __USER_FIRST__ made that the lesson-capture hook queued in
  __WORK_ROOT__\system\lesson-queue.jsonl, and turn the durable ones into feedback memories.
  __USER_FIRST__ runs it with /lesson-review (for example before the weekly review).
disable-model-invocation: true
---

# Lesson review

The `lesson-capture.ps1` hook (UserPromptSubmit) appends a redacted line to
`__WORK_ROOT__\system\lesson-queue.jsonl` whenever __USER_FIRST__'s prompt looks like a
correction. This skill is the human-review half.

## Steps

1. **Load.** Parse the queue line by line with `ConvertFrom-Json`. Parse, never grep: a broken
   state file looks like an empty one. Load `lesson-queue-reviewed.jsonl` (same folder) if
   present and drop every id already reviewed. If nothing is left, say "No new lessons queued"
   and stop.
2. **Get the context.** For each entry, the prompt alone is often not enough ("no, the other
   one"). If `sessionId` is set, search that session's transcript
   (`__CLAUDE_HOME__\projects\*\<sessionId>.jsonl`) for the prompt text and read the assistant
   turn just before it, so you know what was being corrected. Do not paste transcript text
   into the report.
3. **Sort each entry into one of three:**
   - **Durable rule**: it will matter again. Write the lesson, the why, and how to apply it.
   - **Already saved**: an existing memory covers it. Name that memory file.
   - **One-off**: it only mattered that once. Skip it.
   Merge duplicates (same lesson in different words) into one row.
4. **Show __USER_FIRST__ one table** and wait for their answer:

   | # | Lesson (one line) | Why | Save as | Verdict |
   |---|---|---|---|---|
   | 1 | <lesson> | <why> | new `feedback_<slug>.md` / update `<file>.md` | Apply / Edit / Skip |

   Keep it to durable rules plus "already saved" rows. Put a one-line count of one-offs under the table.
5. **Apply** only what they approve. Follow the memory rules: frontmatter with
   `metadata.type: feedback`, then **Why:** and **How to apply:** lines. Prefer updating an
   existing file over creating a duplicate. Add a one-line pointer to `MEMORY.md`.
   If the lesson has broken twice before, say so and suggest a hook for it.
6. **Record.** For every entry shown (applied, edited, skipped, or one-off), append
   `{"reviewedTs":"<iso>","id":"<id>","verdict":"applied|edited|skipped|one-off","memory":"<file or null>"}`
   to `lesson-queue-reviewed.jsonl` with `ConvertTo-Json -Compress`. Never rewrite or delete
   `lesson-queue.jsonl` itself.

## Rules
- The queue is already redacted. Keep it that way: never add names, ids or amounts to a memory.
- Never save a lesson __USER_FIRST__ did not approve in this run.
