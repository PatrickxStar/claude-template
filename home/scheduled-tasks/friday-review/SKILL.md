---
name: friday-review
description: Weekly, end of the last working day - a personal review for __USER_FIRST__ built from the resolutions log, the daily reports and the autopilot log, plus 2-3 concrete ideas to make the pipeline better next week
---

Build __USER_FIRST__'s personal weekly review. This is for THEM, not a manager - the goal is to keep improving the automation.

Read from __WORK_ROOT__\: resolutions-log.md, every reports\report-*.md and reports\briefing-*.md from the past 7 days, system\autopilot-log.md, and the summary.json files in the __ITEM__ folders. Read the memory folder for feedback_*.md files created this week (by file date), and __CLAUDE_HOME__\skills\, agents\, hooks\ and __WORK_ROOT__\system\playbooks\ for files edited this week.

Write __WORK_ROOT__\reports\review-<yyyy-MM-dd>.md. The note (0) goes at the very top and is also saved on its own as reports\note-<yyyy-MM-dd>.md. Sections 1-4 are for skimming.

0. The note (at most 120 words, plain words, three short parts): (a) what I learned about how you work this week, from the corrections and the mirror, in your terms; (b) what I changed about myself this week - skills, agents, playbooks, hooks - said as what each change does for you, not file names; (c) one number: drafts you sent unchanged this week, "X of the Y drafts you sent went out unchanged". If no sends were captured, say that - a zero means the mirror went quiet.
1. This week - __ITEMS__ resolved, __ITEMS__ prepped (staged fixes, drafts), anything still aging.
2. Patterns - request types seen 2+ times; for each, whether a skill or playbook exists or should.
3. Pipeline health - runs that happened vs the slots in the schedule, days with gaps (a working day with zero runs is a blackout - say it first), days the switch was OFF, sources that were unreachable, the week's [AUTO] actions reviewed.
4. Improvement ideas - 2-3 concrete suggestions ordered by effort vs payoff. Be opinionated.

Then regenerate the dashboard: powershell -ExecutionPolicy Bypass -File __WORK_ROOT__\generate-dashboard.ps1

Rules: reads only, never send anything, no personal data, no confidence words, spaced hyphens never em dashes. Under a page.
