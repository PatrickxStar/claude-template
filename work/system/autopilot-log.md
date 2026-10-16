# Autopilot log

One line per unattended write, appended by the Runner. Mode changes are logged here too.
Format: `- <date HH:mm> <id> <playbook> - <exact call> (prior: <value>; reverse: <call>)`
A staged or blocked run writes STAGED in the line, so it never counts as executed.
