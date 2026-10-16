# toggle-automation.ps1 - ONE switch for all automation. ASCII only.
#
#   powershell -ExecutionPolicy Bypass -File __WORK_ROOT__\system\toggle-automation.ps1              (status only)
#   powershell -ExecutionPolicy Bypass -File __WORK_ROOT__\system\toggle-automation.ps1 -Mode Off
#   powershell -ExecutionPolicy Bypass -File __WORK_ROOT__\system\toggle-automation.ps1 -Mode On
#   powershell -ExecutionPolicy Bypass -File __WORK_ROOT__\system\toggle-automation.ps1 -Mode Auto
#   add -DryRun to any mode to preview, change nothing
#
# THREE MODES:
#   OFF  - scheduled model runs exit immediately. Nothing happens.
#   ON   - runs happen, work __ITEMS__, write drafts and staged fixes. No playbook is EXECUTED.
#   AUTO - same as ON, plus: any playbook marked STATUS AUTO whose preconditions all pass
#          gets EXECUTED (reversible writes only).
#
# OFF sets:  system\automation-paused.txt EXISTS; autopilot-on.txt -> autopilot-off.txt (rename);
#            the Windows scheduled tasks named in $winTasks are disabled.
# ON sets:   automation-paused.txt ABSENT; autopilot-on.txt -> autopilot-off.txt; tasks enabled.
# AUTO sets: automation-paused.txt ABSENT; autopilot-off.txt -> autopilot-on.txt; tasks enabled.
# Nothing is ever deleted: on <-> off is a rename. automation-mode.txt holds one word
# (OFF / ON / AUTO) after a real change, as a DISPLAY copy - scripts decide from the flag files.
param(
    [ValidateSet('Off', 'On', 'Auto')][string]$Mode,
    [switch]$DryRun
)
$sys      = '__WORK_ROOT__\system'
$paused   = Join-Path $sys 'automation-paused.txt'
$apOn     = Join-Path $sys 'autopilot-on.txt'
$apOff    = Join-Path $sys 'autopilot-off.txt'
$modeFile = Join-Path $sys 'automation-mode.txt'
$log      = Join-Path $sys 'autopilot-log.md'
# Windows Task Scheduler tasks that are pure scripts (sync, watchers). Empty until you add some.
$winTasks = @()

function Get-CurrentMode {
    if (Test-Path $paused) { return 'OFF' }
    if (Test-Path $apOn) { return 'AUTO' }
    return 'ON'
}
function Move-Safe([string]$from, [string]$to) {
    if (-not (Test-Path $from)) { return }
    if (Test-Path $to) { Move-Item -Force $from ($from + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
    else { Move-Item $from $to }
}
function Set-Tasks([bool]$enable) {
    foreach ($t in $winTasks) {
        try {
            if ($enable) { Enable-ScheduledTask -TaskName $t -ErrorAction Stop | Out-Null }
            else { Disable-ScheduledTask -TaskName $t -ErrorAction Stop | Out-Null }
        } catch { Write-Host ("  task {0}: {1}" -f $t, $_.Exception.Message) }
    }
}

if (-not (Test-Path $sys)) { New-Item -ItemType Directory -Path $sys -Force | Out-Null }
$before = Get-CurrentMode

if ($Mode) {
    $target = $Mode.ToUpper()
    if ($DryRun) {
        Write-Host "[DRYRUN] would set mode $before -> $target; no files or tasks change."
    } else {
        switch ($target) {
            'OFF' {
                if (-not (Test-Path $paused)) { Set-Content -Encoding utf8 $paused ("PAUSED " + (Get-Date -Format s) + " - scheduled runs exit immediately while this file exists.") }
                Move-Safe $apOn $apOff
                Set-Tasks $false
            }
            'ON' {
                if (Test-Path $paused) { Remove-Item $paused -Force }
                Move-Safe $apOn $apOff
                if (-not (Test-Path $apOff)) { Set-Content -Encoding utf8 $apOff ("draft-only since " + (Get-Date -Format s)) }
                Set-Tasks $true
            }
            'AUTO' {
                if (Test-Path $paused) { Remove-Item $paused -Force }
                Move-Safe $apOff $apOn
                if (-not (Test-Path $apOn)) { Set-Content -Encoding utf8 $apOn ("AUTO since " + (Get-Date -Format s) + " - playbooks with STATUS AUTO execute when their preconditions pass.") }
                Set-Tasks $true
            }
        }
        Set-Content -Encoding utf8 $modeFile $target
        Add-Content -Encoding utf8 $log ("- " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + " AUTOMATION " + $target + " (was " + $before + ")")
    }
}

$now = Get-CurrentMode
Write-Host ("Mode: {0}" -f $now)
Write-Host ("  automation-paused.txt : {0}" -f $(if (Test-Path $paused) { 'present (OFF)' } else { 'absent' }))
Write-Host ("  autopilot-on.txt      : {0}" -f $(if (Test-Path $apOn) { 'present (AUTO)' } else { 'absent (draft-only)' }))
if ($winTasks.Count -gt 0) {
    foreach ($t in $winTasks) {
        try { $st = (Get-ScheduledTask -TaskName $t -ErrorAction Stop).State } catch { $st = 'not found' }
        Write-Host ("  task {0}: {1}" -f $t, $st)
    }
}
