# voice-gate.ps1
# PreToolUse hook, matcher "Write|Edit".
# Checks every draft shape: draft-*.txt / draft_*.txt, reply-*.txt, new-<item>*.txt.
# A file whose name carries "to-<your first name>" is a note to you, not a send: only the
# dash and hedge checks apply. Also refuses a .sql under the work root that carries a
# transaction wrapper (staged SQL is plain statements the person runs with one keystroke).
# Denies a save that breaks the voice rules; prints nothing to allow.
# Any parse error or non-matching file allows silently (never blocks real work).
# ASCII only. Paths below are swapped by the tests, keep them as single-quoted literals.

$workRoot  = '__WORK_ROOT__'
$configDir = '__CLAUDE_HOME__\hooks\config'
$userFirst = '__USER_FIRST__'
$itemNoun  = '__ITEM__'
$ceilingAB = 45     # words, bucket A/B, unless the body is numbered click steps

try {
    $stdinStream = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stdinStream, [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch {
    exit 0
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
    $toolInput = $hookData.tool_input
    if ($null -eq $toolInput) { exit 0 }

    $filePath = $toolInput.file_path
    if ([string]::IsNullOrEmpty($filePath)) { exit 0 }

    $fileName = Split-Path -Path $filePath -Leaf
    if ([string]::IsNullOrEmpty($fileName)) { exit 0 }

    $text = $null
    if ($null -ne $toolInput.content) { $text = [string]$toolInput.content }
    elseif ($null -ne $toolInput.new_string) { $text = [string]$toolInput.new_string }

    # ---- staged SQL: no transaction wrapper, live or commented --------------------
    $rootEsc = [regex]::Escape($workRoot.TrimEnd('\'))
    if ($fileName -match '(?i)\.sql$' -and (($filePath -replace '/', '\') -match ('(?i)^' + $rootEsc + '\\'))) {
        if (-not [string]::IsNullOrEmpty($text) -and $text -match '(?i)\b(BEGIN\s+TRAN(SACTION)?|COMMIT|ROLLBACK)\b') {
            @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'
                permissionDecisionReason = "SQL gate: '$($Matches[1])' found. Staged SQL is plain statements only - no BEGIN TRAN / COMMIT / ROLLBACK, live or commented. The person running it must get a saved write from one keystroke." } } | ConvertTo-Json -Depth 6 -Compress
        }
        exit 0
    }

    $fileNamePattern = '(?i)^(draft[-_].*|reply-.*|new-' + [regex]::Escape($itemNoun) + '.*)\.txt$'
    if ($fileName -notmatch $fileNamePattern) { exit 0 }
    $toMe = ($fileName -match ('(?i)to-' + [regex]::Escape($userFirst)))
    if ([string]::IsNullOrEmpty($text)) { exit 0 }

    # ---- bucket: search the raw text (header may carry the VOICE: line) ----------
    $bucket = 'B'
    $bucketMatch = [regex]::Match($text, '(?im)^\s*VOICE:\s*(?:bucket\s*)?([A-F])\b')
    if ($bucketMatch.Success) {
        $bucket = $bucketMatch.Groups[1].Value.ToUpper()
    } elseif ($null -ne $toolInput.new_string -and (Test-Path -LiteralPath $filePath)) {
        # an Edit carries only the changed text: the bucket lives in the file on disk
        try {
            $onDisk = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
            $diskMatch = [regex]::Match($onDisk, '(?im)^\s*VOICE:\s*(?:bucket\s*)?([A-F])\b')
            if ($diskMatch.Success) { $bucket = $diskMatch.Groups[1].Value.ToUpper() }
        } catch { }
    }

    # ---- strip a header in the first 12 lines: up to and including a line that is
    #      exactly "---" or a line containing "copy everything below this line" ------
    $lines = $text -split "\r\n|\r|\n"
    $headerEndIndex = -1
    $maxCheck = [Math]::Min(12, $lines.Count)
    for ($i = 0; $i -lt $maxCheck; $i++) {
        $lineTrim = $lines[$i].Trim()
        if ($lineTrim -eq '---') { $headerEndIndex = $i; break }
        if ($lines[$i] -match '(?i)copy everything below this line') { $headerEndIndex = $i; break }
    }
    if ($headerEndIndex -lt 0) {
        # no marker: a VOICE: line in the first 6 lines is the header, and it is never sent
        $maxVoice = [Math]::Min(6, $lines.Count)
        for ($i = 0; $i -lt $maxVoice; $i++) {
            if ($lines[$i] -match '(?i)^\s*VOICE:') { $headerEndIndex = $i }
        }
    }
    if ($headerEndIndex -ge 0 -and ($headerEndIndex + 1) -le ($lines.Count - 1)) {
        $bodyLines = $lines[($headerEndIndex + 1)..($lines.Count - 1)]
    } elseif ($headerEndIndex -ge 0) {
        $bodyLines = @()
    } else {
        $bodyLines = $lines
    }
    $body = [string]::Join("`n", $bodyLines)

    $reasons = @()

    # ---- em dash / en dash ----
    if ($body.IndexOf([char]0x2014) -ge 0) { $reasons += 'em dash found' }
    if ($body.IndexOf([char]0x2013) -ge 0) { $reasons += 'en dash found' }

    # ---- typed sign-off ----
    $signOffHit = $false
    foreach ($l in $bodyLines) {
        $lt = $l.Trim()
        if ($lt -eq $userFirst -or $lt -eq ('- ' + $userFirst) -or $lt -eq ('-' + $userFirst)) { $signOffHit = $true; break }
    }
    if ($signOffHit -and -not $toMe) { $reasons += "typed sign-off found ('$userFirst')" }

    # ---- back-end system names (bucket C and notes to you are exempt) ----
    if ($bucket -ne 'C' -and -not $toMe) {
        foreach ($p in (Read-Patterns (Join-Path $configDir 'backend-names.txt'))) {
            try {
                $m = [regex]::Match($body, ('\b(' + $p + ')\b'), 'IgnoreCase')
                if ($m.Success) { $reasons += "back-end name '$($m.Groups[1].Value)'"; break }
            } catch { }
        }
    }

    # ---- never say how sure ----
    foreach ($p in (Read-Patterns (Join-Path $configDir 'hedge-words.txt'))) {
        try {
            $m = [regex]::Match($body, $p, 'IgnoreCase')
            if ($m.Success) { $reasons += "says how sure - '$($m.Value)'"; break }
        } catch { }
    }

    # ---- word ceiling for bucket A/B (unless numbered click steps; not for notes to you) ----
    if (($bucket -eq 'A' -or $bucket -eq 'B') -and -not $toMe) {
        $nonBlank = $bodyLines | Where-Object { $_.Trim() -ne '' }
        $joined = [string]::Join(' ', $nonBlank)
        $words = $joined -split '\s+' | Where-Object { $_ -ne '' }
        $wordCount = $words.Count
        $hasNumberedSteps = $false
        foreach ($l in $nonBlank) { if ($l -match '^\s*\d+[\.\)]\s') { $hasNumberedSteps = $true; break } }
        if ($wordCount -gt $ceilingAB -and -not $hasNumberedSteps) {
            $reasons += "$wordCount words for bucket $bucket (ceiling $ceilingAB) - cut it or make it click steps"
        }
    }

    if ($reasons.Count -gt 0) {
        $reasonText = 'Voice gate: ' + ([string]::Join('; ', $reasons)) + '. Fix and save again.'
        @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reasonText } } |
            ConvertTo-Json -Depth 6 -Compress
    }
    exit 0
} catch {
    exit 0
}
