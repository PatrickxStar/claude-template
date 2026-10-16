# lib-hooktest.ps1 - shared helpers for the hook tests. Dot-source it: . "$PSScriptRoot\lib-hooktest.ps1"
#
# Why a Process object and not "$json | powershell -File hook.ps1":
#   PS 5.1 pipes strings to a native exe through $OutputEncoding, which is ASCII by default.
#   An em dash becomes "?" before the hook ever sees it, so a dash test would pass or fail
#   for the wrong reason. Here the JSON goes in as raw UTF-8 bytes, the way Claude Code sends it.
#
# Keep this file ASCII only. PS 5.1 reads a BOM-less .ps1 as ANSI, so any non-ASCII literal
# here would be mangled. Build special characters with [char]0x2014 etc.
#
# Every hook is tested through a SANDBOX COPY: the hook text with its top-of-file
# "$name = '...'" path constants swapped for temp paths. If a constant is not found, the
# sandbox refuses to build (throws) instead of silently running against real files.

$script:HookDir   = Split-Path -Parent $PSScriptRoot
$script:PassCount = 0
$script:FailCount = 0

function Invoke-Hook {
    param([string]$Script, [string]$Json, [int]$TimeoutMs = 30000)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $Script + '"'
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes([string]$Json)
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.BaseStream.Flush()
    $p.StandardInput.Close()
    $finished = $p.WaitForExit($TimeoutMs)
    if (-not $finished) { try { $p.Kill() } catch { } }
    $stdout = ''
    $stderr = ''
    if ($finished) {
        $stdout = ([string]$outTask.Result).Trim()
        $stderr = ([string]$errTask.Result).Trim()
    }
    $parsed = $null
    $parseOk = $true
    if ($stdout -ne '') {
        try { $parsed = $stdout | ConvertFrom-Json } catch { $parseOk = $false }
    }
    $code = -1
    if ($finished) { $code = $p.ExitCode }
    return [pscustomobject]@{
        TimedOut = (-not $finished)
        ExitCode = $code
        Stdout   = $stdout
        Stderr   = $stderr
        Parsed   = $parsed
        ParseOk  = $parseOk
    }
}

# Build hook stdin JSON from a hashtable (handles all escaping, incl. backslashes in paths).
function New-HookJson {
    param([hashtable]$Data)
    return ($Data | ConvertTo-Json -Depth 8 -Compress)
}

function Write-Result {
    param([bool]$Ok, [string]$Name, [string]$Detail)
    if ($Ok) { $script:PassCount++; $tag = 'PASS' } else { $script:FailCount++; $tag = 'FAIL' }
    $d = [string]$Detail
    $d = $d -replace '\s+', ' '
    if ($d.Length -gt 170) { $d = $d.Substring(0, 170) + '...' }
    Write-Output ("[{0}] {1} - {2}" -f $tag, $Name, $d)
}

# Common health checks every hook run must meet: finished, exit 0, no stderr, stdout is JSON or empty.
function Get-HealthProblem {
    param($R)
    if ($R.TimedOut) { return 'timed out' }
    if ($R.ExitCode -ne 0) { return "exit code $($R.ExitCode) (2 would BLOCK)" }
    if ($R.Stderr -ne '') { return "stderr: $($R.Stderr)" }
    if (-not $R.ParseOk) { return "stdout is not JSON: $($R.Stdout)" }
    return $null
}

function Get-Decision {
    param($R)
    if ($null -eq $R.Parsed) { return 'allow' }
    $h = $R.Parsed.hookSpecificOutput
    if ($null -ne $h -and $h.permissionDecision -eq 'deny') { return 'deny' }
    if ($R.Parsed.decision -eq 'block') { return 'block' }
    return 'other'
}

# PreToolUse expectation: 'deny' or 'allow' (allow = print nothing). Optional reason regex for a deny.
function Test-PreToolUse {
    param([string]$Name, [string]$Script, [hashtable]$Data, [string]$Expect, [string]$ReasonLike = '')
    $r = Invoke-Hook -Script $Script -Json (New-HookJson $Data)
    $problem = Get-HealthProblem $r
    if ($problem) { Write-Result $false $Name $problem; return }
    $got = Get-Decision $r
    $reason = ''
    if ($got -eq 'deny') { $reason = [string]$r.Parsed.hookSpecificOutput.permissionDecisionReason }
    $ok = ($got -eq $Expect)
    if ($ok -and $Expect -eq 'allow' -and $r.Stdout -ne '') { $ok = $false }
    if ($ok -and $Expect -eq 'deny' -and $ReasonLike -ne '' -and $reason -notmatch $ReasonLike) { $ok = $false }
    $detail = "expected $Expect, got $got"
    if ($reason) { $detail += " | $reason" }
    Write-Result $ok $Name $detail
}

# Stop / SubagentStop expectation: block or not. Optional reason regex.
function Test-StopEvent {
    param([string]$Name, [string]$Script, [hashtable]$Data, [bool]$ExpectBlock, [string]$ReasonLike = '')
    $r = Invoke-Hook -Script $Script -Json (New-HookJson $Data)
    $problem = Get-HealthProblem $r
    if ($problem) { Write-Result $false $Name $problem; return }
    $blocked = ($r.Stdout -match '"decision":\s*"block"')
    $ok = ($blocked -eq $ExpectBlock)
    if ($ok -and -not $ExpectBlock -and $r.Stdout -ne '' -and $r.Stdout -notmatch 'systemMessage') { $ok = $false }
    if ($ok -and $ExpectBlock -and $ReasonLike -ne '' -and $r.Stdout -notmatch $ReasonLike) { $ok = $false }
    $detail = "expected block=$ExpectBlock, got block=$blocked"
    if ($r.Stdout) { $detail += ' | ' + $r.Stdout.Substring(0, [Math]::Min(140, $r.Stdout.Length)) }
    Write-Result $ok $Name $detail
}

# Sandbox copy: rewrite each "$name = '...'" constant at the top of the hook. Every name must exist.
function New-SandboxHook {
    param([string]$HookName, [hashtable]$Vars, [string]$SandboxDir)
    $src = Join-Path $script:HookDir $HookName
    $text = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8)
    foreach ($k in $Vars.Keys) {
        $pattern = '(?m)^\$' + [regex]::Escape($k) + '\s*=\s*''[^'']*'''
        if (-not [regex]::IsMatch($text, $pattern)) { throw "sandbox: `$$k = '...' not found at the top of $HookName - the hook changed, update the test" }
        $replacement = '$' + $k + " = '" + ([string]$Vars[$k]).Replace("'", "''") + "'"
        $text = [regex]::Replace($text, $pattern, { param($m) $replacement }, 1)
    }
    if (-not (Test-Path $SandboxDir)) { New-Item -ItemType Directory -Path $SandboxDir -Force | Out-Null }
    $dst = Join-Path $SandboxDir $HookName
    # UTF-8 WITH BOM so PS 5.1 reads any non-ASCII in the hook correctly
    [System.IO.File]::WriteAllText($dst, $text, (New-Object System.Text.UTF8Encoding($true)))
    return $dst
}

function New-SandboxDir {
    param([string]$Tag)
    $d = Join-Path $env:TEMP ('hooktest-' + $Tag + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    return $d
}

# A config folder with known rules, so a test never depends on what the user filled in.
function New-SandboxConfig {
    param([string]$SandboxDir)
    $cfg = Join-Path $SandboxDir 'config'
    New-Item -ItemType Directory -Path $cfg -Force | Out-Null
    $tab = [string][char]9
    Set-Content -Path (Join-Path $cfg 'forbidden-commands.txt') -Encoding UTF8 -Value @(
        '# test rules',
        ('\bprodserver\b' + $tab + 'That server is off limits from Claude.'),
        ('\.Send\(\)|Send-MailMessage|\.SendAndSaveCopy\(' + $tab + 'Never send. Compose with .Display().')
    )
    Set-Content -Path (Join-Path $cfg 'backend-names.txt') -Encoding UTF8 -Value @('# test', 'Vault', 'SQL', 'API', 'Redshift', 'S3 bucket')
    Set-Content -Path (Join-Path $cfg 'hedge-words.txt') -Encoding UTF8 -Value @('# test', '\bconfidence\b', '\bconfident\b', "\bi'?m sure\b", '\bi am sure\b', '\blikely\b', '\bprobably\b')
    return $cfg
}

function Write-Tally {
    param([string]$Suite)
    Write-Output ("SUITE {0}: {1} passed, {2} failed" -f $Suite, $script:PassCount, $script:FailCount)
}
