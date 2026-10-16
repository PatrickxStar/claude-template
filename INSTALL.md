# Install

## What you need

- Windows with PowerShell 5.1, or Mac / Linux with Python 3 (3.8 or newer) on PATH as `python3`
- Claude Code desktop app or CLI, signed in to the account you want to teach
- A folder for work items (the "work root"), for example `C:\Users\<you>\Work` or `~/Work`

## Which settings file

The six hooks ship twice, with the same behavior and the same test cases:

| OS | Hooks | Settings file to install as `settings.json` |
|---|---|---|
| Windows | `home\hooks\*.ps1` (PowerShell 5.1) | `home\settings.json` |
| Mac / Linux | `home/hooks/py/*.py` (Python 3, standard library only) | `home/settings.python.json` |
| Windows with Python 3 | either; `install.ps1 -Python` picks the Python set | `home\settings.python.json` |

Only one of the two goes in. The installer below handles it on Windows. On Mac / Linux there is
no installer yet: copy `home/` to `~/.claude/`, rename `settings.python.json` to `settings.json`,
delete the `.ps1` files if you like, and replace the placeholders by hand:

```bash
cd ~/.claude && grep -rl '__WORK_ROOT__\|__CLAUDE_HOME__\|__USER_FIRST__\|__ITEMS__\|__ITEM__' . \
  | xargs sed -i.bak -e "s#__WORK_ROOT__#$HOME/Work#g" -e "s#__CLAUDE_HOME__#$HOME/.claude#g" \
    -e "s#__USER_FIRST__#Sam#g" -e "s#__ITEMS__#tickets#g" -e "s#__ITEM__#ticket#g"
```

(On a Mac, `sed -i.bak` leaves `.bak` files next to the originals; delete them.) Then run the
Python suite to prove the hooks are wired: `python3 -m unittest discover ~/.claude/hooks/tests/py`.

## Step 1 - run the installer

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WorkRoot "C:\Users\<you>\Work" -UserFirst "<First name>" -ItemNoun ticket
```

What it does:

1. Copies `home\` into `~\.claude\` (CLAUDE.md, settings.json, hooks, agents, skills, scheduled-tasks, memory-template).
   An existing `settings.json` is backed up first. If it already has a `hooks` section the
   installer writes ours to `settings.hooks-template.json` and tells you to merge by hand.
2. Copies `work\` into your work root (README, system files, playbook template, switch, dashboard generator).
3. Replaces the placeholders `__WORK_ROOT__`, `__CLAUDE_HOME__`, `__USER_FIRST__`, `__ITEM__`, `__ITEMS__` in every text file it copied.
4. Creates the empty state, log and backup folders the hooks expect.
5. Runs the hook tests and prints the tally.

Add `-DryRun` to see every file it would write without writing anything. Add `-Python` to wire
the Python hooks instead of the PowerShell ones (needs `python3` on PATH).

## Step 2 - make ~/.claude a local git repo (optional, recommended)

```powershell
cd ~\.claude; git init; git add -A; git commit -m "template install"
```

The `.gitignore` is a whitelist: only skills, agents, hooks, settings.json, CLAUDE.md,
scheduled-tasks and memory are tracked. Never add a remote. Commit after every change the
model makes to itself, so a bad edit is one `git checkout` away.

## Step 3 - fill in the config files

Open these and replace the examples with your own (each file explains itself):

| File | What you put there |
|---|---|
| `~\.claude\CLAUDE.md` | Your talk-to-me rules, your systems by name, your folders |
| `~\.claude\hooks\config\forbidden-commands.txt` | Commands the shell must never run (one regex per line, tab, reason) |
| `~\.claude\hooks\config\backend-names.txt` | System names that must never appear in a reply to a non-technical reader |
| `~\.claude\hooks\config\hedge-words.txt` | The "how sure I am" words you do not want to read |
| `<WorkRoot>\system\voice-checklist.md` | How you actually write: openers, closers, length, stock lines |
| `<WorkRoot>\system\known-noise.md` | Things that look like work but are not |

Later, as the work shows you what repeats: one playbook per fix that may run on its own
(`<WorkRoot>\system\playbooks\`, copy `_template.md`) and one skill per recurring job
(`~\.claude\skills\`, copy `_skill-template`). Memory grows on its own through
`lesson-capture` and `/lesson-review`.

## Step 4 - seed the memory folder

Claude Code keeps memory per project under `~\.claude\projects\<project-slug>\memory\`.
The slug is the project path with every character that is not a letter or digit turned
into `-` (for example `C--Users-you-source-myrepo`). The first time you open the project,
copy `~\.claude\memory-template\*` into that folder. `MEMORY.md` is the index loaded every
session; the other files are one example of each memory type.

## Step 5 - start a session and check the hooks are live

In a new Claude Code session ask the model to write a file named `draft-test.txt` with an
em dash in it. The voice gate must refuse it. If it does not, the hooks are not wired:
check `~\.claude\settings.json` and that the `hooks` block names the right paths.

## Step 6 - schedule the runs

In the desktop app, create a scheduled task from each folder under `~\.claude\scheduled-tasks\`
(the SKILL.md in each is the prompt). Leave the switch on Off until you have watched one
attended run of `/work-queue` succeed. Then:

```powershell
powershell -ExecutionPolicy Bypass -File <WorkRoot>\system\toggle-automation.ps1 -Mode On
```

Move to Auto only once at least one playbook has VERIFY and REVERSE sections you have tested.

## Uninstall

Delete `~\.claude\hooks\` (both the `.ps1` files and the `py\` folder), remove the `hooks` block
from `settings.json`, delete the skills and agents you do not want. A missing hook script errors non-blockingly, so nothing breaks
half way.
