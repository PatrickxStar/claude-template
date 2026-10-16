# run-all.ps1 - run every hook test suite and print one tally. ASCII only.
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\run-all.ps1
$here = $PSScriptRoot
$total = 0; $failed = 0
foreach ($t in (Get-ChildItem $here -Filter 'test-*.ps1' | Sort-Object Name)) {
    Write-Output ''
    Write-Output ('=== ' + $t.Name)
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $t.FullName 2>&1
    $out | ForEach-Object { Write-Output $_ }
    foreach ($line in $out) {
        if ($line -match '^SUITE \S+: (\d+) passed, (\d+) failed') { $total += [int]$Matches[1] + [int]$Matches[2]; $failed += [int]$Matches[2] }
    }
}
Write-Output ''
Write-Output ("ALL HOOK TESTS: {0} run, {1} failed" -f $total, $failed)
if ($failed -gt 0) { exit 1 }
exit 0
