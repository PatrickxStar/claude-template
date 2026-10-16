# usage-context.ps1
# SessionStart + UserPromptSubmit hook (same script wired to both events).
# Reads <work root>\system\usage-state.json and injects one plain usage line so every
# new prompt/session opens with current budget numbers in view. The work-queue skill
# refreshes that file from the get_usage tool at the start of each run.
# Missing or broken file -> print nothing (never guesses, never blocks).
# ASCII only. Paths below are swapped by the tests, keep them as single-quoted literals.
#
# usage-state.json contract (ASCII, written with ConvertTo-Json):
# {
#   "checkedAt": "2026-01-01T09:00:00",   when the numbers were read
#   "fiveHourPct": 12, "weeklyAllPct": 30,
#   "capModel": "<model name>",           optional: a model you ration per day
#   "weeklyModelPct": 20, "modelTodayPct": 5, "modelDailyCapPct": 20, "modelCapHit": false
# }

$usageFile = '__WORK_ROOT__\system\usage-state.json'

try {
    $stdinStream = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stdinStream, [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch {
    $hookData = $null
}

$eventName = 'UserPromptSubmit'
if ($null -ne $hookData -and -not [string]::IsNullOrEmpty([string]$hookData.hook_event_name)) {
    $eventName = [string]$hookData.hook_event_name
}

try {
    if (-not (Test-Path -Path $usageFile)) { exit 0 }

    $usage = (Get-Content -Path $usageFile -Raw) | ConvertFrom-Json
    if ($null -eq $usage) { exit 0 }

    # checkedAt is typed in by whichever session refreshed the file, and it can be wrong.
    # The file's own save time cannot lie, so age comes from whichever of the two is OLDER.
    $checkedAt = [DateTimeOffset]::Parse([string]$usage.checkedAt)
    $savedAt = [DateTimeOffset](Get-Item -Path $usageFile).LastWriteTime
    $now = [DateTimeOffset]::Now
    $readingAt = $checkedAt
    if ($checkedAt -gt $savedAt.AddMinutes(10)) { $readingAt = $savedAt }
    $staleMin = [Math]::Round(($now - $readingAt).TotalMinutes)
    if ($staleMin -lt 0) { $staleMin = 0 }
    $timeStr = $readingAt.ToLocalTime().ToString('HH:mm')

    $line = "Usage (as of $timeStr, $staleMin min ago): 5-hour $($usage.fiveHourPct)%, week-all $($usage.weeklyAllPct)%."
    if (-not [string]::IsNullOrEmpty([string]$usage.capModel)) {
        $line += " $($usage.capModel): week $($usage.weeklyModelPct)%, today $($usage.modelTodayPct)% of $($usage.modelDailyCapPct)% cap."
    }
    if ($staleMin -gt 60) {
        $line = "USAGE IS STALE ($([Math]::Round($staleMin / 60, 1)) h old) - refresh usage-state.json with get_usage before trusting it. " + $line
    }
    if ($usage.modelCapHit -eq $true) {
        $line = "DAILY CAP HIT for $($usage.capModel) - " + $line + " Say so in one line and use another model for the rest of today."
    }

    @{ hookSpecificOutput = @{ hookEventName = $eventName; additionalContext = $line } } | ConvertTo-Json -Depth 6 -Compress
    exit 0
} catch {
    exit 0
}
