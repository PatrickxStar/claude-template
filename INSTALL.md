# Install

## What you need

- Windows with PowerShell 5.1 (the hooks are written for it; nothing else is required)
- Claude Code desktop app or CLI, signed in to the account you want to teach
- A folder for work items (the "work root"), for example `C:\Users\<you>\Work`

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

Add `-DryRun` to see every file it would write without writing anything.

## Step 2 - make ~/.claude a local git repo (optional, recommended)

```powershell
cd ~\.claude; git init; git add -A; git commit -m "template install"
```

The `.gitignore` is a whitelist: only skills, agents, hooks, settings.json, CLAUDE.md,
scheduled-tasks and memory are tracked. Never add a remote. Commit after every change the
model makes to itself, so a bad edit is one `git checkout` away.

## Step 3 - fill in the config files

Open these and replace the examples with your own (each file explains itself):

- `~\.claude\CLAUDE.md`
- `~\.claude\hooks\config\forbidden-commands.txt`
- `~\.claude\hooks\config\backend-names.txt`
- `~\.claude\hooks\config\hedge-words.txt`
- `<WorkRoot>\system\voice-checklist.md`
- `<WorkRoot>\system\known-noise.md`

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

Delete `~\.claude\hooks\`, remove the `hooks` block from `settings.json`, delete the skills
and agents you do not want. A missing hook script errors non-blockingly, so nothing breaks
half way.
