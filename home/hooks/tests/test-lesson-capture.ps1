# test-lesson-capture.ps1 - sandbox copy of lesson-capture.ps1 with a temp queue file. ASCII only.
. "$PSScriptRoot\lib-hooktest.ps1"
$tmp = New-SandboxDir 'lesson'
$queue = Join-Path $tmp 'system\lesson-queue.jsonl'
$hook = New-SandboxHook -HookName 'lesson-capture.ps1' -SandboxDir $tmp -Vars @{ queueFile = $queue }

function P([string]$prompt) { return @{ hook_event_name = 'UserPromptSubmit'; session_id = 'lc-1'; cwd = 'C:\x'; prompt = $prompt } }
function Test-Capture([string]$Name, [string]$Prompt, [bool]$ExpectCapture, [string]$QueueLike = '') {
    $before = 0
    if (Test-Path $queue) { $before = @(Get-Content $queue).Count }
    $r = Invoke-Hook -Script $hook -Json (New-HookJson (P $Prompt))
    $problem = Get-HealthProblem $r
    if ($problem) { Write-Result $false $Name $problem; return }
    $after = 0
    if (Test-Path $queue) { $after = @(Get-Content $queue).Count }
    $captured = ($r.Stdout -match 'additionalContext') -and ($after -eq $before + 1)
    $ok = ($captured -eq $ExpectCapture)
    if ($ok -and -not $ExpectCapture -and $r.Stdout -ne '') { $ok = $false }
    if ($ok -and $ExpectCapture -and $QueueLike -ne '') {
        $last = (Get-Content $queue | Select-Object -Last 1)
        if ($last -notmatch $QueueLike) { $ok = $false }
    }
    Write-Result $ok $Name ("expected capture=$ExpectCapture, got capture=$captured | " + $r.Stdout)
}

Write-Output '--- lesson-capture: corrections are queued'
Test-Capture '"no, use the other path" -> captured' 'no, use the other path for that file' $true 'no-opener'
Test-Capture '"from now on always ..." -> captured' 'from now on always write the summary first' $true 'standing'
Test-Capture '"remember that ..." -> captured' 'remember that the QA copy is scrubbed' $true 'remember'
Test-Capture 'email and SSN are redacted in the queue' 'dont email bob@example.com about 123-45-6789 again' $true '\[EMAIL\].*\[SSN\]'

Write-Output '--- lesson-capture: non-corrections pass silently'
Test-Capture '"thanks!" -> nothing' 'thanks!' $false
Test-Capture 'a slash command -> nothing' '/work-queue dont skip' $false
Test-Capture 'a scheduled-task opener -> nothing' 'run work-queue now and dont stop' $false
Test-Capture 'correction only inside pasted content -> nothing' 'please summarize this <pasted_content id="1">no, never do that</pasted_content>' $false

Write-Output '--- lesson-capture: broken input must allow silently'
foreach ($bad in @('not json', '', '{"prompt":null}')) {
    $r = Invoke-Hook -Script $hook -Json $bad
    $p = Get-HealthProblem $r
    Write-Result (($null -eq $p) -and ($r.Stdout -eq '')) ("broken stdin '" + $bad + "' -> allow") $(if ($p) { $p } elseif ($r.Stdout) { $r.Stdout } else { 'no output' })
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Tally 'lesson-capture'
