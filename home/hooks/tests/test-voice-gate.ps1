# test-voice-gate.ps1 - sandbox copy of voice-gate.ps1 against synthesized PreToolUse JSON. ASCII only.
. "$PSScriptRoot\lib-hooktest.ps1"
$em = [string][char]0x2014
$en = [string][char]0x2013
$nl = "`n"
$tmp = New-SandboxDir 'voice'
$work = Join-Path $tmp 'Work'
$cfg = New-SandboxConfig $tmp
$hook = New-SandboxHook -HookName 'voice-gate.ps1' -SandboxDir $tmp -Vars @{ workRoot = $work; configDir = $cfg; userFirst = 'Sam'; itemNoun = 'ticket' }
$draft = Join-Path $work '125000\draft-reply.txt'
New-Item -ItemType Directory -Path (Split-Path $draft) -Force | Out-Null

function Words([int]$n) {
    $pool = @('the','portal','login','is','reset','now','and','she','can','sign','in','again','today')
    $w = @()
    for ($i = 0; $i -lt $n; $i++) { $w += $pool[$i % $pool.Count] }
    return [string]::Join(' ', $w)
}
function W([string]$path, [string]$content) { return @{ hook_event_name = 'PreToolUse'; tool_name = 'Write'; tool_input = @{ file_path = $path; content = $content } } }
function E([string]$path, [string]$old, [string]$new) { return @{ hook_event_name = 'PreToolUse'; tool_name = 'Edit'; tool_input = @{ file_path = $path; old_string = $old; new_string = $new } } }

Write-Output '--- voice-gate: core rules'
Test-PreToolUse 'draft-reply.txt with an em dash -> deny' $hook (W $draft ("VOICE: B$nl---${nl}Hi Mary! Her portal is fixed $em try again now.${nl}Thanks!")) 'deny' 'em dash'
Test-PreToolUse 'en dash -> deny' $hook (W $draft ("VOICE: B$nl---${nl}Hi Mary! Fixed $en try again.")) 'deny' 'en dash'
Test-PreToolUse 'bucket B 12-word clean draft -> allow' $hook (W $draft ("VOICE: B | 12 words$nl---${nl}Hi Mary! I reset her portal login, she can sign in now.")) 'allow'
Test-PreToolUse 'findings.md with an em dash -> allow (not a draft)' $hook (W (Join-Path $work '125000\findings.md') ("Root cause $em the user was blocked. Likely fixed.")) 'allow'
Test-PreToolUse 'Edit new_string with Vault and VOICE: D -> deny' $hook (E $draft 'x' ("VOICE: D$nl---${nl}Hello, the Vault login for this agent is reset.")) 'deny' 'Vault'
$steps = "VOICE: B$nl---${nl}Hi Mary! Here is how to find it:$nl" +
         "1. Open the app and click the Agents tab at the top of the page$nl" +
         "2. Search the agent by name and open the profile page$nl" +
         "3. Click Contracts, then pick the carrier row you need$nl" +
         "4. Scroll to Details and click the Edit button$nl" +
         "5. Change the level, save, and refresh the page to confirm it$nl" +
         "Let me know how it goes. " + (Words 12)
Test-PreToolUse '70 words with numbered click steps -> allow' $hook (W $draft $steps) 'allow'
Test-PreToolUse 'a trailing line "Sam" -> deny' $hook (W $draft ("VOICE: B$nl---${nl}Hi Mary! I reset her login.${nl}Thanks,${nl}Sam")) 'deny' 'sign-off'
Test-PreToolUse 'the word "likely" -> deny' $hook (W $draft ("VOICE: B$nl---${nl}Hi Mary! This is likely the feed.")) 'deny' 'likely'
Test-PreToolUse '"unlikely" is NOT caught (word edge) -> allow' $hook (W $draft ("VOICE: B$nl---${nl}Hi Mary! It is unlikely to happen again.")) 'allow'
Test-PreToolUse 'bucket C draft naming SQL -> allow' $hook (W $draft ("VOICE: C$nl---${nl}Hey Richie - the SQL update ran and the API call returns 200 now. thanks!")) 'allow'
Test-PreToolUse 'reply-CS-4410.txt naming Redshift -> deny' $hook (W (Join-Path $tmp 'reply-CS-4410.txt') ("VOICE: D$nl---${nl}Hello, the Redshift load finished.")) 'deny' 'Redshift'
Test-PreToolUse 'no header at all, 70 words, no steps -> deny (defaults to bucket B)' $hook (W $draft (Words 70)) 'deny' 'ceiling 45'
Test-PreToolUse 'VOICE header + "copy everything below" marker, 40-word body -> allow' $hook (W $draft ("------$nl  DRAFT REPLY$nl  VOICE:  B internal  40w$nl------$nl  v v v  copy everything below this line  v v v$nl$nl" + (Words 40))) 'allow'
Test-PreToolUse 'first-line VOICE header names Vault -> allow (header is never sent)' $hook (W $draft ("VOICE: B (internal, Vault reset done) | 9 words$nl${nl}Hi Mary! Her login is reset, she can sign in.")) 'allow'

Write-Output '--- voice-gate: Edit reads the bucket from the file on disk when new_string has no VOICE line'
Set-Content -Path $draft -Value ("VOICE: C | 20 words$nl---${nl}Hey Richie - old text here. thanks!") -Encoding UTF8
Test-PreToolUse 'Edit on a bucket C draft, new_string names SQL -> allow' $hook (E $draft 'old text here' 'the SQL fix ran') 'allow'
Set-Content -Path $draft -Value ("VOICE: D | 20 words$nl---${nl}Hello, old text here.") -Encoding UTF8
Test-PreToolUse 'Edit on a bucket D draft, new_string names Vault -> deny' $hook (E $draft 'old text here' 'the Vault login is reset') 'deny' 'Vault'
Set-Content -Path $draft -Value ("VOICE: E | 50 words$nl---${nl}Hi Mike, old text here.") -Encoding UTF8
Test-PreToolUse 'Edit on a bucket E draft, 50-word new_string -> allow (A/B ceiling does not apply)' $hook (E $draft 'old text here' (Words 50)) 'allow'

Write-Output '--- voice-gate: every draft shape; notes to you'
Test-PreToolUse 'new-ticket.txt with an em dash -> deny' $hook (W (Join-Path $tmp 'new-ticket.txt') ("VOICE: C$nl---${nl}Hey team $em can someone look?")) 'deny' 'em dash'
Test-PreToolUse 'draft_reply.txt naming Vault -> deny' $hook (W (Join-Path $tmp 'draft_reply.txt') ("VOICE: B$nl---${nl}Hi Mary! Your Vault login is reset.")) 'deny' 'Vault'
Test-PreToolUse 'note-to-sam.txt naming Vault -> allow (not a draft name)' $hook (W (Join-Path $tmp 'note-to-sam.txt') ("The Vault user was blocked $em fixed.")) 'allow'
Test-PreToolUse 'draft-to-sam.txt naming Vault, 70 words -> allow (a note to you)' $hook (W (Join-Path $tmp 'draft-to-sam.txt') ("VOICE: B$nl---${nl}The Vault user was blocked. " + (Words 70))) 'allow'
Test-PreToolUse 'draft-to-sam.txt with an em dash -> deny (dash rule still applies)' $hook (W (Join-Path $tmp 'draft-to-sam.txt') ("VOICE: B$nl---${nl}Fixed $em see findings.")) 'deny' 'em dash'
Test-PreToolUse 'draft-to-sam.txt saying "likely" -> deny (hedge rule still applies)' $hook (W (Join-Path $tmp 'draft-to-sam.txt') ("VOICE: B$nl---${nl}It is likely the feed.")) 'deny' 'likely'

Write-Output '--- voice-gate: staged SQL'
Test-PreToolUse 'staged-fix.sql under the work root with COMMIT -> deny' $hook (W (Join-Path $work '125000\staged-fix.sql') "UPDATE t SET x = 1;`n-- COMMIT") 'deny' 'SQL gate'
Test-PreToolUse 'staged-fix.sql under the work root, plain statements -> allow' $hook (W (Join-Path $work '125000\staged-fix.sql') "UPDATE t SET x = 1;`nSELECT x FROM t;") 'allow'
Test-PreToolUse 'a .sql outside the work root with BEGIN TRAN -> allow' $hook (W (Join-Path $tmp 'repo\migrate.sql') "BEGIN TRAN; UPDATE t SET x = 1; COMMIT;") 'allow'

Write-Output '--- voice-gate: broken input must allow silently'
foreach ($bad in @('not json at all', '', '{"tool_input":null}', '{"tool_input":{"file_path":""}}')) {
    $r = Invoke-Hook -Script $hook -Json $bad
    $p = Get-HealthProblem $r
    Write-Result (($null -eq $p) -and ($r.Stdout -eq '')) ("broken stdin '" + $bad + "' -> allow") $(if ($p) { $p } elseif ($r.Stdout) { $r.Stdout } else { 'no output' })
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Tally 'voice-gate'
