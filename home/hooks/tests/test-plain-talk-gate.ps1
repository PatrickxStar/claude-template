# test-plain-talk-gate.ps1 - sandbox copy of plain-talk-gate.ps1 against synthesized Stop JSON. ASCII only.
. "$PSScriptRoot\lib-hooktest.ps1"
$em = [string][char]0x2014
$tmp = New-SandboxDir 'plaintalk'
$cfg = New-SandboxConfig $tmp
$hook = New-SandboxHook -HookName 'plain-talk-gate.ps1' -SandboxDir $tmp -Vars @{
    stateDir = (Join-Path $tmp 'state'); logFile = (Join-Path $tmp 'plain-talk-gate.log'); configDir = $cfg }

function S([string]$sid, [string]$msg) { return @{ hook_event_name = 'Stop'; session_id = $sid; stop_hook_active = $false; last_assistant_message = $msg } }
$sid = 'pt-' + (Get-Date -Format 'HHmmss')

Write-Output '--- plain-talk-gate: the two fingerprints'
Test-StopEvent 'em dash in prose -> block' $hook (S ($sid + '-a') ("The feed is fine $em the portal is not.")) $true 'em dash'
Test-StopEvent 'clean plain answer -> allow' $hook (S ($sid + '-b') 'The feed is fine - the portal is not. Next click: refresh the page.') $false
Test-StopEvent '"likely" in prose -> block' $hook (S ($sid + '-c') 'This is likely the carrier feed.') $true 'how sure'
Test-StopEvent '"unlikely" -> allow (word edge)' $hook (S ($sid + '-d') 'This is unlikely to repeat.') $false
Test-StopEvent '"I am sure" -> block' $hook (S ($sid + '-e') 'I am sure the fix landed.') $true 'how sure'

Write-Output '--- plain-talk-gate: code and quotes are ignored'
Test-StopEvent 'em dash only inside a fenced block -> allow' $hook (S ($sid + '-f') ("Run this:`n``````sql`nSELECT 1 $em two`n``````")) $false
Test-StopEvent 'em dash only in inline code -> allow' $hook (S ($sid + '-g') ("The title is ``Merged $em cases missing``.")) $false
Test-StopEvent 'em dash only in a quoted line -> allow' $hook (S ($sid + '-h') ("She wrote:`n> policies $em missing`nI checked the feed.")) $false

Write-Output '--- plain-talk-gate: loop guards'
$same = "Same message $em twice."
Test-StopEvent 'first time -> block' $hook (S ($sid + '-i') $same) $true
Test-StopEvent 'same message again -> allow (no loop)' $hook (S ($sid + '-i') $same) $false
$cap = $sid + '-cap'
for ($n = 1; $n -le 5; $n++) { $null = Invoke-Hook -Script $hook -Json (New-HookJson (S $cap ("Message $n $em different."))) }
$r = Invoke-Hook -Script $hook -Json (New-HookJson (S $cap ("Message 6 $em different.")))
Write-Result (($r.Stdout -match 'systemMessage') -and ($r.Stdout -notmatch '"decision"')) 'sixth distinct message -> gives up with systemMessage' $r.Stdout

Write-Output '--- plain-talk-gate: broken input must allow silently'
foreach ($bad in @('not json', '', '{"hook_event_name":"Stop"}')) {
    $r = Invoke-Hook -Script $hook -Json $bad
    $p = Get-HealthProblem $r
    Write-Result (($null -eq $p) -and ($r.Stdout -eq '')) ("broken stdin '" + $bad + "' -> allow") $(if ($p) { $p } elseif ($r.Stdout) { $r.Stdout } else { 'no output' })
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Tally 'plain-talk-gate'
