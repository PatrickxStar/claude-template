# test-command-guard.ps1 - sandbox copy of command-guard.ps1 against synthesized PreToolUse JSON. ASCII only.
. "$PSScriptRoot\lib-hooktest.ps1"
$tmp = New-SandboxDir 'cmdguard'
$work = Join-Path $tmp 'Work'
$cfg = New-SandboxConfig $tmp
$hook = New-SandboxHook -HookName 'command-guard.ps1' -SandboxDir $tmp -Vars @{ workRoot = $work; configDir = $cfg; itemNoun = 'ticket' }

function C([string]$cmd) { return @{ hook_event_name = 'PreToolUse'; tool_name = 'Bash'; tool_input = @{ command = $cmd } } }

Write-Output '--- command-guard: forbidden list'
Test-PreToolUse 'forbidden server name -> deny' $hook (C 'sqlcmd -S prodserver -Q "select 1"') 'deny' 'off limits'
Test-PreToolUse 'other server -> allow' $hook (C 'sqlcmd -S devbox -Q "select 1"') 'allow'
Test-PreToolUse 'Outlook .Send() -> deny' $hook (C '$m = $ol.CreateItem(0); $m.Send()') 'deny' 'Never send'
Test-PreToolUse 'Outlook .Display() -> allow' $hook (C '$m = $ol.CreateItem(0); $m.Display()') 'allow'

Write-Output '--- command-guard: state files'
Test-PreToolUse 'Set-Content system\queue.json without ConvertTo-Json -> deny' $hook (C ('Set-Content ' + $work + '\system\queue.json $text')) 'deny' 'ConvertTo-Json'
Test-PreToolUse 'same with ConvertTo-Json -> allow' $hook (C ('$q | ConvertTo-Json -Depth 5 | Set-Content ' + $work + '\system\queue.json')) 'allow'
Test-PreToolUse 'forward-slash path, no serializer -> deny' $hook (C ('echo x > ' + ($work -replace '\\', '/') + '/system/state.json')) 'deny' 'ConvertTo-Json'
Test-PreToolUse 'a .json outside system\ -> allow' $hook (C ('Set-Content ' + $work + '\12345\summary.json $text')) 'allow'

Write-Output '--- command-guard: drafts from the shell'
Test-PreToolUse 'Set-Content draft-reply.txt -> deny' $hook (C ('Set-Content ' + $work + '\12345\draft-reply.txt "Hi"')) 'deny' 'Write tool'
Test-PreToolUse 'redirect to reply-case.txt -> deny' $hook (C ('echo hi > ' + $work + '\12345\reply-case.txt')) 'deny' 'Write tool'
Test-PreToolUse 'new-ticket.txt via WriteAllText -> deny' $hook (C ('[IO.File]::WriteAllText("' + $work + '\12345\new-ticket.txt", $t)')) 'deny' 'Write tool'
Test-PreToolUse 'report line that only MENTIONS draft-reply.txt -> allow' $hook (C ('Add-Content ' + $work + '\12345\findings.md "wrote draft-reply.txt"')) 'allow'
Test-PreToolUse 'cat a draft (read) -> allow' $hook (C ('cat ' + $work + '\12345\draft-reply.txt')) 'allow'

Write-Output '--- command-guard: broken input must allow silently'
foreach ($bad in @('not json at all', '', '{"tool_input":null}', '{"tool_input":{"command":""}}')) {
    $r = Invoke-Hook -Script $hook -Json $bad
    $p = Get-HealthProblem $r
    Write-Result (($null -eq $p) -and ($r.Stdout -eq '')) ("broken stdin '" + $bad + "' -> allow") $(if ($p) { $p } elseif ($r.Stdout) { $r.Stdout } else { 'no output' })
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Tally 'command-guard'
