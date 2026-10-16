# test-disk-gate.ps1 - sandbox copy of disk-gate.ps1 with a temp work root. ASCII only.
. "$PSScriptRoot\lib-hooktest.ps1"
$tmp = New-SandboxDir 'diskgate'
$work = Join-Path $tmp 'Work'
New-Item -ItemType Directory -Path (Join-Path $work 'system') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $work 'archive') -Force | Out-Null
$hook = New-SandboxHook -HookName 'disk-gate.ps1' -SandboxDir $tmp -Vars @{
    workRoot = $work; stateDir = (Join-Path $tmp 'state'); logFile = (Join-Path $tmp 'disk-gate.log'); itemNoun = 'ticket' }

function Stop([string]$sid, [string]$msg) { return @{ hook_event_name = 'Stop'; session_id = $sid; stop_hook_active = $false; last_assistant_message = $msg } }
function Touch([string]$sid, [string]$path, [string]$agent = '') {
    $d = @{ hook_event_name = 'PostToolUse'; session_id = $sid; tool_name = 'Write'; tool_input = @{ file_path = $path; content = 'x' } }
    if ($agent) { $d.agent_id = $agent }
    return $d
}
function SubStop([string]$sid, [string]$agentId, [string]$agentType, [string]$msg) {
    return @{ hook_event_name = 'SubagentStop'; session_id = $sid; agent_id = $agentId; agent_type = $agentType; last_assistant_message = $msg }
}
function Complete([string]$folder) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    Set-Content (Join-Path $folder 'findings.md') 'done' -Encoding UTF8
    Set-Content (Join-Path $folder 'summary.json') '{"status":"open"}' -Encoding UTF8
}
$sid = 'dg-' + (Get-Date -Format 'HHmmss')

Write-Output '--- disk-gate: Stop, mentions'
Test-StopEvent 'mentions "ticket 199991" with no folder -> block' $hook (Stop ($sid + '-a') 'Ticket 199991 is fixed.') $true '199991'
Test-StopEvent 'same with [no-work-folder] -> allow' $hook (Stop ($sid + '-b') 'Ticket 199991 is a pure lookup. [no-work-folder]') $false
Test-StopEvent 'bare "#25587" (a PR number) -> allow (not a mention)' $hook (Stop ($sid + '-c') 'Merged PR #25587 into main.') $false
Complete (Join-Path $work '199992')
Test-StopEvent 'mentions a complete folder -> allow' $hook (Stop ($sid + '-d') 'Ticket 199992 is done.') $false
New-Item -ItemType Directory -Path (Join-Path $work '199993') -Force | Out-Null
Set-Content (Join-Path $work '199993\summary.json') '{"status":"open"}' -Encoding UTF8
Test-StopEvent 'mentions a folder with only summary.json -> allow (lenient)' $hook (Stop ($sid + '-e') 'Ticket 199993 is a stub.') $false
Test-StopEvent 'mentions a work-root path with no folder -> block' $hook (Stop ($sid + '-f') ('See ' + $work + '\199994\findings.md')) $true '199994'
Test-StopEvent 'mentions the system folder path -> allow (reserved)' $hook (Stop ($sid + '-g') ('Updated ' + $work + '\system\known-noise.md')) $false

Write-Output '--- disk-gate: Stop, touched folders are strict'
$s = $sid + '-t'
$null = Invoke-Hook -Script $hook -Json (New-HookJson (Touch $s (Join-Path $work '199995\findings.md')))
New-Item -ItemType Directory -Path (Join-Path $work '199995') -Force | Out-Null
Set-Content (Join-Path $work '199995\findings.md') 'x' -Encoding UTF8
Test-StopEvent 'touched folder with findings.md but no summary.json -> block' $hook (Stop $s 'All done.') $true 'summary.json is missing'
Set-Content (Join-Path $work '199995\summary.json') '{not json' -Encoding UTF8
Test-StopEvent 'summary.json that does not parse -> block' $hook (Stop $s 'All done.') $true 'does not parse'
Set-Content (Join-Path $work '199995\summary.json') '{"status":"open"}' -Encoding UTF8
Test-StopEvent 'both files good -> allow' $hook (Stop $s 'All done.') $false
$s2 = $sid + '-r'
$null = Invoke-Hook -Script $hook -Json (New-HookJson (Touch $s2 (Join-Path $work 'reports\report-today.md')))
Test-StopEvent 'a write under reports\ is not a touch -> allow' $hook (Stop $s2 'Report written.') $false

Write-Output '--- disk-gate: the 2-block cap'
$s3 = $sid + '-cap'
$null = Invoke-Hook -Script $hook -Json (New-HookJson (Stop $s3 'Ticket 199996 fixed.'))
$null = Invoke-Hook -Script $hook -Json (New-HookJson (Stop $s3 'Ticket 199996 fixed.'))
$r = Invoke-Hook -Script $hook -Json (New-HookJson (Stop $s3 'Ticket 199996 fixed.'))
Write-Result (($r.Stdout -match 'systemMessage') -and ($r.Stdout -notmatch '"decision"')) 'third block -> gives up with systemMessage' $r.Stdout

Write-Output '--- disk-gate: SubagentStop'
$s4 = $sid + '-sub'
$null = Invoke-Hook -Script $hook -Json (New-HookJson (Touch $s4 (Join-Path $work '199997\run-report.md') 'agentR'))
New-Item -ItemType Directory -Path (Join-Path $work '199997') -Force | Out-Null
Test-StopEvent 'runner touched a folder with no run-report.md -> block' $hook (SubStop $s4 'agentR' 'runner' 'Done.') $true 'run-report.md'
Set-Content (Join-Path $work '199997\run-report.md') 'x' -Encoding UTF8
Test-StopEvent 'runner, run-report.md present -> allow' $hook (SubStop $s4 'agentR' 'runner' 'Done.') $false
Test-StopEvent 'prefixed agent type "ticket-runner" also matches -> allow' $hook (SubStop $s4 'agentR' 'ticket-runner' 'Done.') $false
Set-Content (Join-Path $work '199997\runbook.md') 'x' -Encoding UTF8
Test-StopEvent 'planner that wrote via shell but NAMES the folder with runbook.md on disk -> allow' $hook (SubStop $s4 'agentP' 'planner' ('Runbook at ' + $work + '\199997\runbook.md')) $false
Test-StopEvent 'writer that touched nothing and names nothing -> block' $hook (SubStop $s4 'agentW' 'writer' 'Draft is in the chat above.') $true 'wrote nothing'
Test-StopEvent 'unknown agent type -> allow' $hook (SubStop $s4 'agentX' 'explorer' 'Done.') $false

Write-Output '--- disk-gate: broken input must allow silently'
foreach ($bad in @('not json', '', '{"hook_event_name":"Stop"}')) {
    $r = Invoke-Hook -Script $hook -Json $bad
    $p = Get-HealthProblem $r
    Write-Result (($null -eq $p) -and ($r.Stdout -eq '')) ("broken stdin '" + $bad + "' -> allow") $(if ($p) { $p } elseif ($r.Stdout) { $r.Stdout } else { 'no output' })
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Tally 'disk-gate'
