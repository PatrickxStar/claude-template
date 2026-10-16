# test-usage-context.ps1 - sandbox copy of usage-context.ps1 with a temp usage file. ASCII only.
. "$PSScriptRoot\lib-hooktest.ps1"
$tmp = New-SandboxDir 'usage'
$usage = Join-Path $tmp 'system\usage-state.json'
New-Item -ItemType Directory -Path (Split-Path $usage) -Force | Out-Null
$hook = New-SandboxHook -HookName 'usage-context.ps1' -SandboxDir $tmp -Vars @{ usageFile = $usage }

function U() { return @{ hook_event_name = 'UserPromptSubmit'; session_id = 'uc-1'; prompt = 'hi there' } }
function Test-Line([string]$Name, [string]$Like, [bool]$ExpectOutput = $true) {
    $r = Invoke-Hook -Script $hook -Json (New-HookJson (U))
    $problem = Get-HealthProblem $r
    if ($problem) { Write-Result $false $Name $problem; return }
    if (-not $ExpectOutput) { Write-Result ($r.Stdout -eq '') $Name ('stdout: ' + $r.Stdout); return }
    $ctx = ''
    if ($null -ne $r.Parsed -and $null -ne $r.Parsed.hookSpecificOutput) { $ctx = [string]$r.Parsed.hookSpecificOutput.additionalContext }
    Write-Result ($ctx -match $Like) $Name $ctx
}

Write-Output '--- usage-context'
Test-Line 'no usage file -> nothing' '' $false
$now = (Get-Date).ToString('s')
Set-Content $usage ('{"checkedAt":"' + $now + '","fiveHourPct":12,"weeklyAllPct":30}') -Encoding UTF8
Test-Line 'fresh file -> one line with both numbers' '5-hour 12%.*week-all 30%'
Set-Content $usage ('{"checkedAt":"' + $now + '","fiveHourPct":12,"weeklyAllPct":30,"capModel":"BigModel","weeklyModelPct":20,"modelTodayPct":5,"modelDailyCapPct":20,"modelCapHit":false}') -Encoding UTF8
Test-Line 'with a rationed model -> its numbers appear' 'BigModel: week 20%, today 5% of 20% cap'
Set-Content $usage ('{"checkedAt":"' + $now + '","fiveHourPct":12,"weeklyAllPct":30,"capModel":"BigModel","weeklyModelPct":25,"modelTodayPct":21,"modelDailyCapPct":20,"modelCapHit":true}') -Encoding UTF8
Test-Line 'cap hit -> DAILY CAP HIT prefix' '^DAILY CAP HIT for BigModel'
$old = (Get-Date).AddHours(-3).ToString('s')
Set-Content $usage ('{"checkedAt":"' + $old + '","fiveHourPct":12,"weeklyAllPct":30}') -Encoding UTF8
(Get-Item $usage).LastWriteTime = (Get-Date).AddHours(-3)
Test-Line '3 h old -> STALE prefix' '^USAGE IS STALE'
Set-Content $usage 'not json' -Encoding UTF8
Test-Line 'broken file -> nothing' '' $false

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Tally 'usage-context'
