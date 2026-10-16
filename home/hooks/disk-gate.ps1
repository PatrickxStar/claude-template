# disk-gate.ps1
# One script, three events (work must reach disk, never only a transcript):
#   PostToolUse  (matcher "Write|Edit")  - tracker: remember which work-item folders
#                                          this session / subagent wrote into.
#   Stop                                 - main session may not stop while a touched or
#                                          mentioned item folder lacks findings.md + a
#                                          parseable summary.json.
#   SubagentStop (matcher "planner|runner|writer")
#                                        - a chain agent may not return without its artifact.
# At most 2 blocks per session/agent, then it allows and tells you what was left undone.
# Any parse error allows silently (never blocks real work).
# ASCII only. Paths below are swapped by the tests, keep them as single-quoted literals.

$workRoot  = '__WORK_ROOT__'
$stateDir  = '__CLAUDE_HOME__\hooks\state'
$logFile   = '__CLAUDE_HOME__\hooks\logs\disk-gate.log'
$itemNoun  = '__ITEM__'
$reserved  = @('system', 'reports', 'archive', 'adhoc')
$maxBlocks = 2

function Write-GateLog([string]$msg) {
    try {
        $dir = Split-Path $logFile -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 1MB)) { Move-Item $logFile "$logFile.old" -Force }
        Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 's'), $msg) -Encoding UTF8
    } catch { }
}

# Returns the item folder (full path) a file path lives in, or $null.
# An item folder is any direct child of the work root that is not a reserved name.
function Get-ItemFolder([string]$path) {
    if ([string]::IsNullOrEmpty($path)) { return $null }
    $p = $path -replace '/', '\'
    $rootEsc = [regex]::Escape($workRoot.TrimEnd('\'))
    $m = [regex]::Match($p, ('(?i)^' + $rootEsc + '\\([^\\]+)\\'))
    if (-not $m.Success) { return $null }
    $leaf = $m.Groups[1].Value
    if ($reserved -contains $leaf.ToLower()) { return $null }
    return (Join-Path $workRoot $leaf)
}

# -Lenient (an item only MENTIONED, not written to): the folder just has to exist on disk
# with findings.md or summary.json, so a briefing that lists stubs is not forced to work them.
function Get-FolderIssues([string]$folder, [switch]$Lenient) {
    $issues = @()
    if (-not (Test-Path $folder)) {
        $leaf = Split-Path $folder -Leaf
        $archived = Join-Path (Join-Path $workRoot 'archive') $leaf
        if (Test-Path $archived) { $folder = $archived }
        else { return @("$folder does not exist (no findings.md, no summary.json)") }
    }
    if ($Lenient) {
        if ((Test-Path (Join-Path $folder 'findings.md')) -or (Test-Path (Join-Path $folder 'summary.json'))) { return @() }
        return @("$folder has neither findings.md nor summary.json")
    }
    if (-not (Test-Path (Join-Path $folder 'findings.md'))) { $issues += "$folder\findings.md is missing" }
    $sj = Join-Path $folder 'summary.json'
    if (-not (Test-Path $sj)) {
        $issues += "$folder\summary.json is missing"
    } else {
        try { $null = (Get-Content $sj -Raw -Encoding UTF8) | ConvertFrom-Json }
        catch { $issues += "$folder\summary.json does not parse as JSON" }
    }
    return $issues
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
    $eventName = [string]$hookData.hook_event_name
    $sid = ([string]$hookData.session_id) -replace '[^\w-]', ''
    if ([string]::IsNullOrEmpty($sid)) { exit 0 }

    if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    Get-ChildItem $stateDir -Filter 'disk-gate-*' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    # Plain tab-separated lines, not JSON: avoids the PS 5.1 single-element array collapse.
    $touchFile = Join-Path $stateDir "disk-gate-$sid.touched"   # agentKey<TAB>folder
    $blockFile = Join-Path $stateDir "disk-gate-$sid.blocks"    # agentKey<TAB>count

    $agentKey = 'main'
    if (-not [string]::IsNullOrEmpty([string]$hookData.agent_id)) { $agentKey = [string]$hookData.agent_id }

    function Get-Touched([string]$key) {
        if (-not (Test-Path $touchFile)) { return @() }
        return @(Get-Content $touchFile -Encoding UTF8 | ForEach-Object {
            $parts = $_ -split "`t", 2
            if ($parts.Count -eq 2 -and $parts[0] -eq $key) { $parts[1] }
        } | Select-Object -Unique)
    }
    function Get-BlockCount([string]$key) {
        if (-not (Test-Path $blockFile)) { return 0 }
        $line = Get-Content $blockFile -Encoding UTF8 | Where-Object { ($_ -split "`t", 2)[0] -eq $key } | Select-Object -Last 1
        if ($null -eq $line) { return 0 }
        return [int](($line -split "`t", 2)[1])
    }
    function Set-BlockCount([string]$key, [int]$n) {
        $keep = @()
        if (Test-Path $blockFile) { $keep = @(Get-Content $blockFile -Encoding UTF8 | Where-Object { ($_ -split "`t", 2)[0] -ne $key }) }
        $keep += "$key`t$n"
        Set-Content -Path $blockFile -Value $keep -Encoding UTF8
    }
    function Send-Verdict([string]$key, [string[]]$issues, [string]$label, [string]$eventForMsg) {
        $n = Get-BlockCount $key
        $list = [string]::Join('; ', $issues)
        if ($n -lt $maxBlocks) {
            Set-BlockCount $key ($n + 1)
            Write-GateLog "BLOCK $eventForMsg $label ($($n + 1)/$maxBlocks): $list"
            $hint = 'Write the missing file(s) now, then finish.'
            if ($eventForMsg -eq 'Stop') { $hint += ' If this truly needs no folder (pure lookup, no diagnosis), say [no-work-folder] and why in your reply.' }
            else { $hint += ' The next agent in the chain reads only what is on disk.' }
            @{ decision = 'block'; reason = "disk-gate: $list. $hint" } | ConvertTo-Json -Depth 4 -Compress
        } else {
            Set-BlockCount $key 0
            Write-GateLog "GAVE-UP $eventForMsg $label after $maxBlocks blocks: $list"
            @{ systemMessage = "disk-gate: $label stopped with work not on disk after $maxBlocks reminders: $list" } | ConvertTo-Json -Depth 4 -Compress
        }
    }

    switch ($eventName) {

        'PostToolUse' {
            $folder = Get-ItemFolder ([string]$hookData.tool_input.file_path)
            if ($null -eq $folder) { exit 0 }
            if ((Get-Touched $agentKey) -notcontains $folder) {
                Add-Content -Path $touchFile -Value "$agentKey`t$folder" -Encoding UTF8
            }
            exit 0
        }

        'Stop' {
            $msg = [string]$hookData.last_assistant_message
            if ($msg -match '\[no-work-folder\]') { Set-BlockCount 'main' 0; exit 0 }

            $touched = @(Get-Touched 'main')
            $mentioned = @()
            # A mention = "<item noun> <number>" (e.g. "ticket 12345", "ticket #12345") or an explicit
            # "<work root>\<id>" path. A bare "#12345" is NOT a mention: pull request and issue numbers
            # look the same and blocked a session once.
            $nounEsc = [regex]::Escape($itemNoun)
            $rootEsc = [regex]::Escape($workRoot.TrimEnd('\'))
            foreach ($m in [regex]::Matches($msg, ('(?i)\b' + $nounEsc + '\s*#?\s*(\d{3,8})\b'))) {
                $f = Join-Path $workRoot $m.Groups[1].Value
                if ($touched -notcontains $f) { $mentioned += $f }
            }
            foreach ($m in [regex]::Matches(($msg -replace '/', '\'), ('(?i)' + $rootEsc + '\\([^\\\s"'')`]+)'))) {
                $leaf = $m.Groups[1].Value
                if ($reserved -contains $leaf.ToLower()) { continue }
                $f = Join-Path $workRoot $leaf
                if ($touched -notcontains $f) { $mentioned += $f }
            }
            $mentioned = @($mentioned | Select-Object -Unique)
            if ($touched.Count -eq 0 -and $mentioned.Count -eq 0) { exit 0 }

            $issues = @()
            foreach ($c in $touched)   { $issues += Get-FolderIssues $c }
            foreach ($c in $mentioned) { $issues += Get-FolderIssues $c -Lenient }
            if ($issues.Count -eq 0) { Set-BlockCount 'main' 0; exit 0 }

            Send-Verdict 'main' $issues 'main session' 'Stop'
            exit 0
        }

        'SubagentStop' {
            $agentType = [string]$hookData.agent_type
            $need = $null
            if ($agentType -match '(?i)(^|-)planner$') {
                $need = @{ label = 'runbook.md';    test = { param($f) Test-Path (Join-Path $f 'runbook.md') } }
            } elseif ($agentType -match '(?i)(^|-)runner$') {
                $need = @{ label = 'run-report.md'; test = { param($f) Test-Path (Join-Path $f 'run-report.md') } }
            } elseif ($agentType -match '(?i)(^|-)writer$') {
                $need = @{ label = 'a draft-*/reply-*/new-* .txt'
                           test  = { param($f) @(Get-ChildItem $f -File -ErrorAction SilentlyContinue |
                                     Where-Object { $_.Name -match '(?i)^(draft[-_].*|reply-.*|new-.*)\.txt$' }).Count -gt 0 } }
            } else { exit 0 }

            $folders = @(Get-Touched $agentKey)
            if ($folders.Count -eq 0) {
                # An agent that wrote through the shell leaves no Write/Edit touch. Read the folders it
                # NAMES in its last message and test the file on disk instead of assuming nothing was written.
                $msg = [string]$hookData.last_assistant_message
                $named = @()
                $rootEsc = [regex]::Escape($workRoot.TrimEnd('\'))
                $nounEsc = [regex]::Escape($itemNoun)
                foreach ($m in [regex]::Matches(($msg -replace '/', '\'), ('(?i)' + $rootEsc + '\\([^\\\s"'')`]+)'))) {
                    if ($reserved -notcontains $m.Groups[1].Value.ToLower()) { $named += (Join-Path $workRoot $m.Groups[1].Value) }
                }
                foreach ($m in [regex]::Matches($msg, ('(?i)\b' + $nounEsc + '\s*#?\s*(\d{3,8})\b'))) { $named += (Join-Path $workRoot $m.Groups[1].Value) }
                $named = @($named | Select-Object -Unique)
                foreach ($f in $named) {
                    $probe = $f
                    if (-not (Test-Path $probe)) { $alt = Join-Path (Join-Path $workRoot 'archive') (Split-Path $f -Leaf); if (Test-Path $alt) { $probe = $alt } }
                    if ((Test-Path $probe) -and (& $need.test $probe)) { Write-GateLog "ALLOW SubagentStop $agentType - $($need.label) found on disk in $probe"; exit 0 }
                }
            }
            $issues = @()
            if ($folders.Count -eq 0) {
                $issues += "$agentType wrote nothing to a work-item folder under $workRoot (expected $($need.label))"
            } else {
                foreach ($f in $folders) { if (-not (& $need.test $f)) { $issues += "$f has no $($need.label)" } }
            }
            if ($issues.Count -eq 0) { exit 0 }

            Send-Verdict $agentKey $issues $agentType 'SubagentStop'
            exit 0
        }

        default { exit 0 }
    }
} catch {
    Write-GateLog "ERROR $($_.Exception.Message)"
    exit 0
}
