# score-runbook.ps1 - score one Planner runbook against its case's expected.json. ASCII only.
#   powershell -ExecutionPolicy Bypass -File evals\score-runbook.ps1 -CaseDir evals\cases\01
# Prints one line per check and a final SCORE line. Exit 0 always; run-evals.ps1 aggregates.
param([Parameter(Mandatory = $true)][string]$CaseDir, [switch]$Quiet)

$expectedPath = Join-Path $CaseDir 'expected.json'
$runbookPath  = Join-Path $CaseDir 'runbook.md'
if (-not (Test-Path $expectedPath)) { Write-Output "SCORE $CaseDir : NO-EXPECTED"; exit 0 }
if (-not (Test-Path $runbookPath))  { Write-Output "SCORE $CaseDir : NOT-RUN (no runbook.md - run the planner on item.txt first)"; exit 0 }

$e = Get-Content $expectedPath -Raw -Encoding UTF8 | ConvertFrom-Json
$text = [System.IO.File]::ReadAllText($runbookPath, [System.Text.Encoding]::UTF8)

function Line([string]$label) {
    $m = [regex]::Match($text, ('(?im)^\s*' + [regex]::Escape($label) + '\s*(.*)$'))
    if ($m.Success) { return $m.Groups[1].Value } else { return '' }
}
function Step1() {
    # the text of step 1: from "1." under "## Steps" to the next "2." or the next heading
    $m = [regex]::Match($text, '(?is)##\s*Steps.*?^\s*1\.(.*?)(?=^\s*2\.|^##)', 'Multiline')
    if ($m.Success) { return $m.Groups[1].Value } else { return '' }
}
function AnyIn([string]$hay, $needles) {
    foreach ($n in @($needles)) { if (-not [string]::IsNullOrEmpty([string]$n) -and $hay.IndexOf([string]$n, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return [string]$n } }
    return $null
}

$results = @()
function Check([string]$name, [bool]$ok, [string]$detail) {
    $script:results += [pscustomobject]@{ name = $name; ok = $ok; detail = $detail }
    if (-not $Quiet) { Write-Output ("[{0}] {1} - {2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $detail) }
}

$family = Line 'FAMILY:'
$hit = AnyIn $family (@($e.family_label) + @($e.family_also_accept))
Check 'family' ($null -ne $hit) ("FAMILY line: '" + $family.Trim() + "'")

$owner = Line 'OWNER-GUESS:'
if ([string]::IsNullOrEmpty($owner)) { $owner = $family }   # same line in the template format
$hit = AnyIn $owner (@($e.owner) + @($e.owner_also_accept))
Check 'owner' ($null -ne $hit) ("owner text: '" + $owner.Trim() + "'")

$s1 = Step1
$hit = AnyIn $s1 $e.first_check_keywords_any
Check 'first-check' ($null -ne $hit) $(if ($hit) { "step 1 mentions '$hit'" } else { 'step 1 mentions none of: ' + ($e.first_check_keywords_any -join ', ') })

$bad = AnyIn $s1 $e.first_check_wrong_keywords_any
Check 'first-check-wrong' ($null -eq $bad) $(if ($bad) { "step 1 does the wrong thing: '$bad'" } else { 'step 1 avoids the known wrong moves' })

$aud = (Line 'AUDIENCE:').Trim()
Check 'bucket' ($aud.ToUpper().StartsWith(([string]$e.reply_bucket).ToUpper())) ("AUDIENCE line: '" + $aud + "'")

$prior = Line 'PRIOR ART:'
$hit = AnyIn $prior $e.cite_any
Check 'cites' ($null -ne $hit) ("PRIOR ART line: '" + $prior.Trim() + "'")

$leak = AnyIn $text $e.leak_guard
Check 'leak-guard' ($null -eq $leak) $(if ($leak) { "runbook mentions '$leak' - it looked the answer up instead of planning" } else { 'no lookup of the real source' })

$pass = @($results | Where-Object { $_.ok }).Count
Write-Output ("SCORE {0} : {1}/{2}" -f $CaseDir, $pass, $results.Count)
exit 0
