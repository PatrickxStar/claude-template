# run-evals.ps1 - score every case under evals\cases and print a table. ASCII only.
#   powershell -ExecutionPolicy Bypass -File evals\run-evals.ps1
$here = $PSScriptRoot
$scorer = Join-Path $here 'score-runbook.ps1'
$rows = @()
foreach ($c in (Get-ChildItem (Join-Path $here 'cases') -Directory | Sort-Object Name)) {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $scorer -CaseDir $c.FullName -Quiet
    $line = ($out | Where-Object { $_ -match '^SCORE ' } | Select-Object -Last 1)
    $status = 'NOT-RUN'; $score = ''
    if ($line -match ': (\d+)/(\d+)$') { $score = $Matches[1] + '/' + $Matches[2]; $status = $(if ($Matches[1] -eq $Matches[2]) { 'PASS' } else { 'FAIL' }) }
    elseif ($line -match ': (NO-EXPECTED)') { $status = 'NO-EXPECTED' }
    $rows += [pscustomobject]@{ case = $c.Name; status = $status; score = $score }
}
$rows | Format-Table -AutoSize | Out-String | Write-Output
$run = @($rows | Where-Object { $_.status -eq 'PASS' -or $_.status -eq 'FAIL' })
$passed = @($run | Where-Object { $_.status -eq 'PASS' }).Count
Write-Output ("EVALS: {0} cases, {1} run, {2} passed, {3} not run" -f $rows.Count, $run.Count, $passed, ($rows.Count - $run.Count))
if (@($run | Where-Object { $_.status -eq 'FAIL' }).Count -gt 0) { exit 1 }
# a suite where nothing ran proves nothing - a NOT-RUN case is reported, but zero runs is a failure
if ($run.Count -eq 0) { Write-Output 'EVALS: no case has a runbook.md - nothing was scored'; exit 1 }
exit 0
