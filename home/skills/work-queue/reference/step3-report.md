# Step 3 - the daily report

Append to `__WORK_ROOT__\reports\report-<yyyy-MM-dd>.md`. One `## Run <HH:mm>` block per run,
even a "nothing new" run. Everything here is for __USER_FIRST__: short words, what is wrong, why,
who owns it, what they click next. Ids and queries live in the folders, not here.

```
## Run <HH:mm>

Done on autopilot
- <id> <playbook> - <exact call> (prior: <value>; reverse: <call>)

Ready for you
- <id> <one line: what is staged and the one click or paste that finishes it>

Diagnosed, needs your call
- <id> <one line: what we found and the one decision only you can make>

Couldn't do + why
- <id> <the exact block: tool, site, session, permission>

Noise
- <count> <rule matched>

Learned this run
- <ledger lines added, memories created / extended / merged / deleted>

Automation ideas
- <a resolution seen 3+ times, with the playbook it would need>

Questions (one block, all __ITEMS__)
- <id> <the one question>
```

Keep it honest: only put an item under "Ready for you" when you would bet on it being right.
"Diagnosed" is for everything else. Never list the same __ITEM__ in two sections.

The first run of each day also writes the briefing (skill `morning-briefing`). Its FIRST line
states how long ago the last run wrote to the report file; a gap over 18 hours on a working
day is said before any __ITEM__ content, so a silent blackout is never missed.
