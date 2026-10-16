# lesson-capture.ps1
# UserPromptSubmit hook. When your prompt looks like a correction ("no, ...", "don't ...",
# "actually ...", "from now on ...", "remember ..."), it:
#   1. appends one redacted JSON line to <work root>\system\lesson-queue.jsonl
#   2. reminds the model (additionalContext) to save a durable rule to memory WITH the why.
# Review the queue with /lesson-review. It never blocks a prompt.
# Any parse error allows silently (never blocks real work).
# ASCII only. Paths below are swapped by the tests, keep them as single-quoted literals.

$queueFile = '__WORK_ROOT__\system\lesson-queue.jsonl'

try {
    $stdinStream = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stdinStream, [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch {
    exit 0
}

try {
    $prompt = [string]$hookData.prompt
    # Pasted text is not your own words.
    $prompt = [regex]::Replace($prompt, '(?s)<pasted_content[^>]*>.*?</pasted_content[^>]*>', ' ')
    if ([string]::IsNullOrWhiteSpace($prompt)) { exit 0 }
    $trim = $prompt.Trim()
    if ($trim.Length -lt 12) { exit 0 }
    if ($trim.StartsWith('/') -or $trim.StartsWith('<')) { exit 0 }   # slash commands, system/event payloads
    if ($trim -match '(?i)^(run|start) (work-queue|the queue|the worker)') { exit 0 }  # scheduled-task prompts

    $head = $trim
    if ($head.Length -gt 400) { $head = $head.Substring(0, 400) }

    $patterns = [ordered]@{
        'no-opener'    = '(?i)^(no|nope|nah)\b'
        'dont'         = "(?i)\b(don'?t|do not|never)\b"
        'stop-doing'   = '(?i)\bstop (doing|using|adding|making|writing|sending|asking)\b'
        'actually'     = '(?i)\bactually\b'
        'wrong'        = "(?i)\b(wrong|that'?s not|that is not|not what i)\b"
        'instead'      = '(?i)\binstead\b'
        'standing'     = '(?i)\b(always|from now on|going forward|next time)\b'
        'remember'     = '(?i)\bremember\b'
        'why-did-you'  = '(?i)\bwhy (did|would) you\b'
        'should-have'  = "(?i)\byou (should|shouldn'?t) have\b"
    }
    $hits = @()
    foreach ($k in $patterns.Keys) { if ($head -match $patterns[$k]) { $hits += $k } }
    if ($hits.Count -eq 0) { exit 0 }

    # redact before anything touches disk: SSNs, emails, long digit runs
    $clean = $trim
    if ($clean.Length -gt 600) { $clean = $clean.Substring(0, 600) + ' ...' }
    $clean = [regex]::Replace($clean, '\b\d{3}-\d{2}-\d{4}\b', '[SSN]')
    $clean = [regex]::Replace($clean, '[\w.+-]+@[\w-]+\.[\w.-]+', '[EMAIL]')
    $clean = [regex]::Replace($clean, '\b\d{9,}\b', '[NUM]')

    $entry = [ordered]@{
        id        = (Get-Date -Format 'yyyyMMddHHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 6))
        ts        = (Get-Date -Format 's')
        sessionId = [string]$hookData.session_id
        cwd       = [string]$hookData.cwd
        matched   = [string]::Join(',', $hits)
        prompt    = $clean
    }
    try {
        $dir = Split-Path $queueFile -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $queueFile -Value ($entry | ConvertTo-Json -Depth 3 -Compress) -Encoding UTF8
    } catch { }

    $ctx = 'lesson-capture: this prompt looks like a correction (' + $entry.matched + '). If it is a durable rule, save it to memory now as a feedback memory WITH the why and how to apply, and say so in one line. If it is a one-off instruction, just do it. Queued as ' + $entry.id + ' for /lesson-review.'
    @{ hookSpecificOutput = @{ hookEventName = 'UserPromptSubmit'; additionalContext = $ctx } } |
        ConvertTo-Json -Depth 4 -Compress
    exit 0
} catch {
    exit 0
}
