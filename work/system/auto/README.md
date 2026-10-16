# system\auto\ - deterministic scripts, no model

Anything a script can do without judgment lives here and runs from Windows Task Scheduler,
not from a model session: syncing the open list from notifications, watching a mailbox folder
for error mails and queuing them, probing that a token still works, rebuilding
`sent-examples.md` from real sends (the mirror), checking for bounced mail.

Rules for every script here:
- Reads only, or writes only to files under the work root. The one kind of outward action a
  script may take is one __USER_FIRST__ has approved by name for that script, with an off
  switch file (`<name>-off.txt`) and a `-DryRun` that explains every skip.
- A high-water mark state file (`<name>-state.txt`): the first run initializes it to NOW and
  processes nothing, so a backlog is never swept as if it were new.
- State in JSON is written with `ConvertTo-Json` and read with `ConvertFrom-Json` inside a
  try; a parse failure refuses to run and says which file. A broken state file must never look
  like an empty one.
- Never `Set-Content` from a variable you have not printed and verified. Merge, never
  overwrite, a file another run may be writing.
- A log file per script, bounded (rotate at ~1-2 MB).
- The switch (`toggle-automation.ps1`) lists these tasks in `$winTasks` so OFF disables them.

Suggested first scripts, when you have the sources for them:
- `sync-queue.ps1` - keep each `<id>\summary.json` status in step with the real queue
- `probe-tokens.ps1` - a harmless read per token; writes `token-health.json`; a 401 writes
  `<name>-key-bad.txt` so playbooks stage instead of failing
- `mirror-sent-replies.ps1` - pair each `draft-reply*.txt` with the captured `sent-reply.txt`,
  write the diff to `voice-lessons.md`, rebuild `sent-examples.md`
