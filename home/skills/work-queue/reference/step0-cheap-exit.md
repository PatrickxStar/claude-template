# Step 0 - cheap exit and cross-session freshness (unattended runs only)

An unattended run that finds nothing new should cost almost nothing.

1. Read `__WORK_ROOT__\system\last-sync.txt` (when the open list was last read in full) and
   `last-run.txt` (when any run last finished).
2. Scan the intake source for anything newer than `system\state\last-seen.txt` (the timestamp of
   the newest item the previous run READ, not the clock - counting from the clock misses an
   item that arrived during the previous run). Write the newest timestamp you read back at the
   end of the scan.
3. If nothing is new AND there are no stub folders AND `last-sync.txt` is under 4 hours old:
   append "Run <HH:mm>: nothing new (cheap exit)" to today's report, update `last-run.txt`,
   delete `system\worker.lock`, regenerate the dashboard, STOP.
4. If `last-sync.txt` is over 4 hours old, do the full open-list pass even with nothing new, and
   write `last-sync.txt` and `last-run.txt` TOGETHER at the end.

Cross-session freshness rule (applies to EVERY session, not just this skill): whenever an
__ITEM__ gets worked in any session (diagnosed, replied, fixed, closed), that session writes the
outcome back to `<id>\summary.json` before it ends, and regenerates the dashboard.

Known trap: a state file that fails to parse looks exactly like an empty one. Parse state
files with `ConvertFrom-Json` inside a try; on failure, refuse to run and say which file.
