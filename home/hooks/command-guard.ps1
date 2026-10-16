# command-guard.ps1
# PreToolUse hook, matcher "Bash|PowerShell".
# Blocks: any command matching a line in config\forbidden-commands.txt, writing a
# system\*.json state file without ConvertTo-Json (a broken state file looks empty),
# and writing a draft/reply file from the shell (drafts go through the Write tool so
# voice-gate can read them). Any parse error allows silently (never blocks real work).
# ASCII only. Paths below are swapped by the tests, keep them as single-quoted literals.

$workRoot  = '__WORK_ROOT__'
$configDir = '__CLAUDE_HOME__\hooks\config'
$itemNoun  = '__ITEM__'

try {
    $stdinStream = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stdinStream, [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch {
    exit 0
}

function Read-Rules([string]$file) {
    # returns an array of @{ pattern; reason } from "<regex><TAB><reason>" lines
    $rules = @()
    if (-not (Test-Path $file)) { return $rules }
    foreach ($line in (Get-Content $file -Encoding UTF8)) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        $parts = $line -split "`t", 2
        $pat = $parts[0].Trim()
        if ($pat -eq '') { continue }
        $why = 'blocked by forbidden-commands.txt'
        if ($parts.Count -eq 2 -and $parts[1].Trim() -ne '') { $why = $parts[1].Trim() }
        $rules += @{ pattern = $pat; reason = $why }
    }
    return $rules
}

try {
    $toolInput = $hookData.tool_input
    if ($null -eq $toolInput) { exit 0 }

    $command = $toolInput.command
    if ([string]::IsNullOrEmpty($command)) { exit 0 }

    $reason = $null

    # ---- 1. the forbidden list -------------------------------------------------
    foreach ($r in (Read-Rules (Join-Path $configDir 'forbidden-commands.txt'))) {
        try {
            if ([regex]::IsMatch($command, $r.pattern, 'IgnoreCase')) { $reason = $r.reason; break }
        } catch { }
    }

    # ---- 2. state file written without serializing ------------------------------
    if (-not $reason) {
        $cmdNorm = $command -replace '/', '\'
        $sysEsc = [regex]::Escape(($workRoot.TrimEnd('\') + '\system\'))
        $stateFilePattern = '(?i)(Set-Content|Out-File|Add-Content|>{1,2})[^|;\r\n]*' + $sysEsc + '[\w.-]+\.json'
        if ($cmdNorm -match $stateFilePattern -and $command -notmatch '(?i)ConvertTo-Json') {
            $reason = 'State file write without ConvertTo-Json - a broken state file looks like an empty one. Serialize it or use a helper script.'
        }
    }

    # ---- 3. a draft written from the shell never meets voice-gate ---------------
    if (-not $reason) {
        $draftName = '[^\s"''|;<>]*\b(draft[-_][\w.-]*|reply-[\w.-]*|new-' + [regex]::Escape($itemNoun) + '[\w.-]*)\.txt\b'
        $draftWritePattern = '(?i)(' +
            '(Set-Content|Out-File|Add-Content)\s+(-(Path|LiteralPath|FilePath)\s+)?["'']?' + $draftName + '|' +
            '(WriteAllText|WriteAllLines)\s*\(\s*["'']?' + $draftName + '|' +
            '(>{1,2}|\btee\b(\s+-a)?)\s*["'']?' + $draftName + '|' +
            '\bsed\s+-i[^|;\r\n]*' + $draftName + ')'
        if ($command -match $draftWritePattern) {
            $reason = 'Draft files are written with the Write tool, not from the shell, so the voice gate can check them.'
        }
    }

    if ($reason) {
        $output = @{
            hookSpecificOutput = @{
                hookEventName = 'PreToolUse'
                permissionDecision = 'deny'
                permissionDecisionReason = $reason
            }
        }
        $output | ConvertTo-Json -Depth 6 -Compress
    }
    exit 0
} catch {
    exit 0
}
