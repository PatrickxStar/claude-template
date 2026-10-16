# Hooks - the bouncers

A hook is a script Claude Code runs around a tool call or a turn. It reads one JSON object
on stdin and may print one JSON object on stdout. Print nothing = allow. These six exist
because a rule written in prose gets forgotten under load; a rule written in a hook cannot.

| Hook | Event | Blocks when |
|---|---|---|
| `command-guard.ps1` | PreToolUse on Bash / PowerShell | the command matches a line in `config\forbidden-commands.txt`; a state `.json` under `system\` is written without `ConvertTo-Json`; a draft file is written from the shell (drafts go through the Write tool so the voice gate sees them) |
| `voice-gate.ps1` | PreToolUse on Write / Edit | a `draft-*.txt`, `reply-*.txt` or `new-*.txt` has an em/en dash, a hedge word, a typed sign-off, a back-end name outside bucket C, or breaks the word ceiling for bucket A/B. A `.sql` under the work root with BEGIN TRAN / COMMIT / ROLLBACK |
| `plain-talk-gate.ps1` | Stop | the last message of the turn has an em/en dash or a hedge word (code blocks and quoted lines ignored). Once per distinct message, at most 5 per session |
| `disk-gate.ps1` | PostToolUse (tracker), Stop, SubagentStop | the session touched or mentioned a work-item folder that lacks `findings.md` + a parseable `summary.json`; a chain agent returns without its artifact (planner: runbook.md, runner: run-report.md, writer: a draft). At most 2 blocks, then it allows and tells you what was left undone |
| `lesson-capture.ps1` | UserPromptSubmit | never blocks. A prompt that looks like a correction ("no, ...", "don't", "from now on", "remember") is appended, redacted, to `system\lesson-queue.jsonl` and the model is reminded to save a feedback memory with the why |
| `usage-context.ps1` | SessionStart, UserPromptSubmit | never blocks. Injects one line with the budget numbers from `system\usage-state.json` so every turn opens with them in view |

## Ground rules for writing or changing a hook

- Windows PowerShell 5.1. No Unix tools. ASCII only in the file (5.1 reads a BOM-less file as ANSI). Build special characters with `[char]0x2014`.
- Read stdin as UTF-8: `New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [Text.Encoding]::UTF8)`.
- Output with `ConvertTo-Json -Depth 6 -Compress`. Exit 0 always. Exit 2 would block everything.
- **Any parse error = allow silently.** A broken hook must never block real work.
- Every blocking hook has a cap and then gives up with a `systemMessage`, so a bad rule cannot trap a session.
- Hard-coded paths sit at the top of the file as `$name = '...'` lines. The tests swap those lines for temp paths and run a sandbox copy, so a test never touches real files.
- Back up before editing: `hooks\backups\<date>\`.
- Test by piping sample JSON in, not by hoping: `powershell -File hooks\tests\run-all.ps1`.
- When a rule breaks twice in prose, move it here. When a hook blocks real work twice, loosen it here. Never restate a hook's rule in a skill, a memory or CLAUDE.md.

## Output shapes

PreToolUse deny:
```json
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}
```
Stop / SubagentStop block:
```json
{"decision":"block","reason":"..."}
```
Add context without blocking (UserPromptSubmit / SessionStart):
```json
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"..."}}
```
Tell the user something after giving up:
```json
{"systemMessage":"..."}
```
