---
name: morning-briefing
description: >-
  Build __USER_FIRST__'s start-of-day briefing from the work folders and today's report:
  what is ready to click, what needs a decision, what is blocked, what was learned. Use when
  __USER_FIRST__ says "/morning-briefing", "catch me up", "what do I need to do today", "what
  came in overnight", or when the first work-queue run of the day finishes.
---

# Morning briefing

Written for __USER_FIRST__ to read in two minutes. Short words. What is wrong, why, who owns
it, what they click. Ids and queries stay in the folders.

## Steps

1. **Freshness first.** The FIRST line states how long ago the last run wrote to
   `__WORK_ROOT__\reports\report-<date>.md` ("Last run: <HH:mm> <date>, N hours ago"). If that
   is more than 18 hours on a working day, say so before any __ITEM__ content. A silent
   blackout is the failure this line exists to catch.
2. **Read** every `summary.json` under `__WORK_ROOT__\` (root only, not `archive\`), today's and
   yesterday's `report-*.md`, and `system\autopilot-log.md` for the last 24 hours.
3. **Group** by lane: Do now (ready) / Decide (call) / Waiting (blocked). One line per __ITEM__:
   id, four-word title, the one action. `[AUTO]` __ITEMS__ get their autopilot line with the
   reversal.
4. **Learned** - the ledger lines and memories from the last run, in __USER_FIRST__'s terms
   ("you cut the extra tip", not "reduced word count").
5. **Questions** - the one batched block, if any.
6. **Save** as `__WORK_ROOT__\reports\briefing-<yyyy-MM-dd>.md`, regenerate the dashboard, and
   open it once.

## Rules
- Reads only. Never send anything. No personal data.
- Never present an __ITEM__ as actionable when __USER_FIRST__'s own reply is the latest message
  on it.
- Under a page. Selective beats exhaustive.
