# Scheduled tasks

Each folder here holds one `SKILL.md`: the prompt a scheduled run starts with. Create the
task in the Claude desktop app and paste the prompt; the app only fires while it is open,
and a missed run fires on next launch.

| Folder | Suggested timing | What it does |
|---|---|---|
| `work-queue-every-30` | every 30 min during working hours, working days | the unattended worker; the first run of the day also writes the briefing |
| `friday-review` | once a week, end of day | a personal review of the week: what was learned, what changed, one number |

Rules every scheduled prompt repeats, because the skill may be unavailable when the run starts:
the run lock, the mode gate, the budget gate, always draft, never send, no personal data, the
one batched block of questions.

Add a folder per recurring job you automate (a weekly data pull, a monthly report). Keep the
prompt short and point at the skill; the skill is the source of truth.
