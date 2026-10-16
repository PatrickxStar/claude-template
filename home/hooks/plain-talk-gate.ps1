# plain-talk-gate.ps1
# Stop hook. The last message of a turn is what you read. It may not carry the two
# fingerprints you call out most: an em/en dash, and a "how sure I am" phrase
# (config\hedge-words.txt). Fenced code blocks, inline code and quoted lines ("> ...")
# are ignored. Blocks once per distinct message and at most 5 times per session, then
# allows and tells you in a system message. Any parse error allows silently.
# ASCII only. Paths below are swapped by the tests, keep them as single-quoted literals.

$stateDir  = '__CLAUDE_HOME__\hooks\state'
$logFile   = '__CLAUDE_HOME__\hooks\logs\plain-talk-gate.log'
$configDir = '__CLAUDE_HOME__\hooks\config'
$maxBlocks = 5

function Write-GateLog([string]$msg) {
    try {
        $dir = Split-Path $logFile -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 1MB)) { Move-Item $logFile "$logFile.old" -Force }
        Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 's'), $msg) -Encoding UTF8
    } catch { }
}
function Read-Patterns([string]$file) {
    $list = @()
    if (-not (Test-Path $file)) { return $list }
    foreach ($line in (Get-Content $file -Encoding UTF8)) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        $list += $t
    }
    return $list
}

try {
    $stdinStream = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stdinStream, [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch {
    exit 0
}

try {
    if ([string]$hookData.hook_event_name -ne 'Stop') { exit 0 }
    $msg = [string]$hookData.last_assistant_message
    if ([string]::IsNullOrWhiteSpace($msg)) { exit 0 }
    $sid = ([string]$hookData.session_id) -replace '[^\w-]', ''
    if ([string]::IsNullOrEmpty($sid)) { exit 0 }

    # what you read: drop fenced code, inline code, and quoted lines
    $clean = [regex]::Replace($msg, '(?s)```.*?```', ' ')
    $clean = [regex]::Replace($clean, '`[^`\r\n]*`', ' ')
    $kept = @()
    foreach ($l in ($clean -split "\r?\n")) { if ($l -notmatch '^\s*>') { $kept += $l } }
    $clean = [string]::Join("`n", $kept)

    $reasons = @()
    if ($clean.IndexOf([char]0x2014) -ge 0) { $reasons += 'an em dash (use a spaced hyphen " - ")' }
    if ($clean.IndexOf([char]0x2013) -ge 0) { $reasons += 'an en dash (use a spaced hyphen " - ")' }
    foreach ($p in (Read-Patterns (Join-Path $configDir 'hedge-words.txt'))) {
        try {
            $m = [regex]::Match($clean, $p, 'IgnoreCase')
            if ($m.Success) { $reasons += ('a "how sure" word - "' + $m.Value.Trim() + '"'); break }
        } catch { }
    }
    if ($reasons.Count -eq 0) { exit 0 }

    if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    Get-ChildItem $stateDir -Filter 'plain-talk-*' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    $stateFile = Join-Path $stateDir "plain-talk-$sid.txt"   # one line per blocked message hash

    $sha = [System.Security.Cryptography.SHA1]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($msg))).Replace('-', '').Substring(0, 16)
    $seen = @()
    if (Test-Path $stateFile) { $seen = @(Get-Content $stateFile -Encoding UTF8 | Where-Object { $_ -ne '' }) }

    $list = [string]::Join('; ', $reasons)
    if ($seen -contains $hash) {
        Write-GateLog "ALLOW-REPEAT $sid $hash : $list"
        exit 0
    }
    if ($seen.Count -ge $maxBlocks) {
        Write-GateLog "GAVE-UP $sid after $maxBlocks blocks: $list"
        @{ systemMessage = "plain-talk-gate: the last answer still has $list after $maxBlocks reminders this session." } |
            ConvertTo-Json -Depth 4 -Compress
        exit 0
    }
    Add-Content -Path $stateFile -Value $hash -Encoding UTF8
    Write-GateLog "BLOCK $sid $hash ($($seen.Count + 1)/$maxBlocks): $list"
    @{ decision = 'block'; reason = "plain-talk-gate: your last message has $list. Rewrite it plainly - spaced hyphens, no confidence words, facts and the next click - then stop again." } |
        ConvertTo-Json -Depth 4 -Compress
    exit 0
} catch {
    Write-GateLog "ERROR $($_.Exception.Message)"
    exit 0
}
