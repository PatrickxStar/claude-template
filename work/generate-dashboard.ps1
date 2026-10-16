# generate-dashboard.ps1 - rebuild dashboard.html from every <id>\summary.json under the work root.
#   powershell -ExecutionPolicy Bypass -File __WORK_ROOT__\generate-dashboard.ps1
# Deliberately small: a static page, three lanes (Do now / Decide / Waiting), a done strip,
# the mode pill, the last autopilot lines. Grow it as you need. ASCII only.
$root = '__WORK_ROOT__'
$sys = Join-Path $root 'system'
$reserved = @('system', 'reports', 'archive', 'adhoc')

function Get-Mode {
    if (Test-Path (Join-Path $sys 'automation-paused.txt')) { return 'OFF' }
    if (Test-Path (Join-Path $sys 'autopilot-on.txt')) { return 'AUTO' }
    return 'ON'
}
function Esc([string]$s) { return [System.Net.WebUtility]::HtmlEncode([string]$s) }

$items = @()
foreach ($d in (Get-ChildItem $root -Directory | Where-Object { $reserved -notcontains $_.Name.ToLower() })) {
    $sj = Join-Path $d.FullName 'summary.json'
    if (-not (Test-Path $sj)) {
        $items += [pscustomobject]@{ id = $d.Name; title = '(no summary.json yet)'; status = 'open'; lane = 'call'; synopsis = 'stub - not yet worked'; action = ''; updated = $d.LastWriteTime.ToString('s'); folder = $d.FullName }
        continue
    }
    try {
        $s = Get-Content $sj -Raw -Encoding UTF8 | ConvertFrom-Json
        $items += [pscustomobject]@{
            id = ('' + $s.id); title = ('' + $s.title); status = ('' + $s.status); lane = ('' + $s.lane)
            synopsis = ('' + $s.synopsis); action = ('' + $s.action)
            updated = $(if ($s.updated) { '' + $s.updated } else { $d.LastWriteTime.ToString('s') }); folder = $d.FullName
        }
    } catch {
        $items += [pscustomobject]@{ id = $d.Name; title = '(summary.json does not parse)'; status = 'open'; lane = 'call'; synopsis = 'fix the JSON'; action = ''; updated = $d.LastWriteTime.ToString('s'); folder = $d.FullName }
    }
}
$open =@($items | Where-Object { $_.status -ne 'done' })
$done = @($items | Where-Object { $_.status -eq 'done' } | Sort-Object updated -Descending | Select-Object -First 10)

function Lane-Rows($lane) {
    $rows = @($open | Where-Object { $_.lane -eq $lane } | Sort-Object updated -Descending)
    if ($rows.Count -eq 0) { return '<p class="empty">nothing here</p>' }
    $h = '<table><tr><th>id</th><th>title</th><th>synopsis</th><th>your click</th></tr>'
    foreach ($r in $rows) {
        $auto = ''
        if ($r.synopsis -like '`[AUTO`]*') { $auto = ' <span class="auto">AUTO</span>' }
        $h += '<tr><td><a href="file:///' + (Esc ($r.folder -replace '\\', '/')) + '">' + (Esc $r.id) + '</a></td><td>' + (Esc $r.title) + $auto + '</td><td>' + (Esc $r.synopsis) + '</td><td>' + (Esc $r.action) + '</td></tr>'
    }
    return $h + '</table>'
}

$logLines = @()
$logPath = Join-Path $sys 'autopilot-log.md'
if (Test-Path $logPath) { $logLines = @(Get-Content $logPath -Encoding UTF8 | Where-Object { $_ -match '^\s*-' } | Select-Object -Last 8) }
$mode = Get-Mode
$now = Get-Date -Format 'yyyy-MM-dd HH:mm'

$html = @"
<!doctype html>
<html><head><meta charset="utf-8"><title>Command Center</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:24px;background:#f6f7f9;color:#222}
h1{font-size:20px;margin:0 0 4px} h2{font-size:15px;margin:22px 0 8px}
.pill{display:inline-block;padding:2px 10px;border-radius:12px;font-size:12px;font-weight:600;color:#fff}
.OFF{background:#999}.ON{background:#2f80ed}.AUTO{background:#e2a000}
table{border-collapse:collapse;width:100%;background:#fff;font-size:13px}
th,td{text-align:left;padding:6px 8px;border-bottom:1px solid #e3e5e8;vertical-align:top}
th{background:#eef0f3;font-weight:600}
.auto{background:#fff1cc;color:#8a5a00;font-size:11px;padding:1px 6px;border-radius:8px}
.empty{color:#888;font-size:13px;margin:4px 0 0}
.muted{color:#777;font-size:12px}
pre{background:#fff;padding:8px;border:1px solid #e3e5e8;font-size:12px;white-space:pre-wrap}
</style></head><body>
<h1>Command Center <span class="pill $mode">$mode</span></h1>
<div class="muted">generated $now - open $($open.Count), done shown $($done.Count)</div>
<h2>Do now (ready)</h2>$(Lane-Rows 'ready')
<h2>Decide (call)</h2>$(Lane-Rows 'call')
<h2>Waiting (blocked)</h2>$(Lane-Rows 'blocked')
<h2>Done (last 10)</h2>
$(if ($done.Count -eq 0) { '<p class="empty">none yet</p>' } else { '<table><tr><th>id</th><th>title</th><th>synopsis</th></tr>' + (($done | ForEach-Object { '<tr><td>' + (Esc $_.id) + '</td><td>' + (Esc $_.title) + '</td><td>' + (Esc $_.synopsis) + '</td></tr>' }) -join '') + '</table>' })
<h2>Last autopilot lines</h2>
<pre>$(if ($logLines.Count -eq 0) { 'none' } else { Esc ($logLines -join "`n") })</pre>
</body></html>
"@
[System.IO.File]::WriteAllText((Join-Path $root 'dashboard.html'), $html, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("dashboard.html written - mode {0}, {1} open, {2} done" -f $mode, $open.Count, $done.Count)
