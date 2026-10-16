# install.ps1 - copy the template into ~/.claude and the work root, fill placeholders, run hook tests.
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -WorkRoot "C:\Users\you\Work" -UserFirst "Sam" -ItemNoun ticket
#   add -DryRun to preview. ASCII only (PowerShell 5.1 reads a BOM-less file as ANSI).
#   add -Python to wire the Python hooks (settings.python.json becomes settings.json) and run
#   the Python test suite instead of the PowerShell one. python3 must be on PATH.
param(
    [Parameter(Mandatory = $true)][string]$WorkRoot,
    [Parameter(Mandatory = $true)][string]$UserFirst,
    [string]$ItemNoun = 'ticket',
    [string]$ItemNounPlural = '',
    [string]$ClaudeHome = (Join-Path $env:USERPROFILE '.claude'),
    [switch]$DryRun,
    [switch]$SkipTests,
    [switch]$Python
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ItemNounPlural) { $ItemNounPlural = $ItemNoun + 's' }
$WorkRoot = $WorkRoot.TrimEnd('\')
$ClaudeHome = $ClaudeHome.TrimEnd('\')

$cfg = Get-Content (Join-Path $here 'template.config.json') -Raw | ConvertFrom-Json
$textExt = @($cfg.textExtensions)
# longer keys first so __ITEMS__ is replaced before __ITEM__
$map = [ordered]@{
    '__WORK_ROOT__'   = $WorkRoot
    '__CLAUDE_HOME__' = $ClaudeHome
    '__USER_FIRST__'  = $UserFirst
    '__ITEMS__'       = $ItemNounPlural
    '__ITEM__'        = $ItemNoun
}

function Say([string]$m) { Write-Host $m }
function Fill([string]$text, [bool]$forJson) {
    foreach ($k in $map.Keys) {
        $v = [string]$map[$k]
        # a backslash is an escape in JSON; forward slashes are valid Windows paths everywhere Claude Code uses them
        if ($forJson) { $v = $v.Replace('\', '/') }
        $text = $text.Replace($k, $v)
    }
    return $text
}
function Copy-Tree([string]$srcRoot, [string]$dstRoot) {
    # -Name gives the path relative to $srcRoot straight from the cmdlet. Never slice FullName by the
    # root's length: when the root is a short 8.3 path (C:\Users\RUNNER~1\... on a GitHub runner),
    # FullName comes back in long form and the slice lands every file in the wrong folder, silently.
    Get-ChildItem $srcRoot -Recurse -File -Force -Name | ForEach-Object {
        $rel = $_
        $src = Join-Path $srcRoot $rel
        $name = Split-Path $rel -Leaf
        $ext = [System.IO.Path]::GetExtension($name).ToLower()
        $dst = Join-Path $dstRoot $rel
        $dstDir = Split-Path $dst -Parent
        $isText = ($textExt -contains $ext) -or ($name -eq '.gitignore') -or ($name -eq '.keep')
        if ($DryRun) { Say ("[dry] " + $dst); return }
        if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
        if ($isText) {
            $t = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8)
            # UTF-8 with BOM so PowerShell 5.1 reads the file as UTF-8 even if a non-ASCII character sneaks in
            $isJson = ($ext -eq '.json')
            [System.IO.File]::WriteAllText($dst, (Fill $t $isJson), (New-Object System.Text.UTF8Encoding($true)))
        } else {
            Copy-Item $src $dst -Force
        }
    }
}

Say "Template : $here"
Say "Claude   : $ClaudeHome"
Say "Work root: $WorkRoot"
Say "Item noun: $ItemNoun / $ItemNounPlural"
if ($Python) { Say "Hooks    : Python (settings.python.json -> settings.json)" } else { Say "Hooks    : PowerShell 5.1 (settings.json)" }
if ($DryRun) { Say "DRY RUN - nothing is written" }

# ---- 1. settings.json: back up, merge or park -------------------------------------
$homeSrc = Join-Path $here 'home'
$settingsDst = Join-Path $ClaudeHome 'settings.json'
$parkSettings = $false
if (Test-Path $settingsDst) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak = "$settingsDst.bak-$stamp"
    Say "settings.json exists - backing up to $bak"
    if (-not $DryRun) { Copy-Item $settingsDst $bak -Force }
    try { $existing = Get-Content $settingsDst -Raw | ConvertFrom-Json } catch { $existing = $null }
    if ($null -ne $existing -and $null -ne $existing.hooks) { $parkSettings = $true }
}

# ---- 2. copy home/ (settings.json parked when the target already has hooks) ------
Say "Copying home\ -> $ClaudeHome"
$tmpHome = Join-Path $env:TEMP ('claude-template-home-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
Copy-Item (Join-Path $homeSrc '*') $tmpHome -Recurse -Force
# one settings file goes in: the PowerShell wiring by default, the Python wiring with -Python
if ($Python) {
    Move-Item (Join-Path $tmpHome 'settings.python.json') (Join-Path $tmpHome 'settings.json') -Force
} else {
    Remove-Item (Join-Path $tmpHome 'settings.python.json') -Force -ErrorAction SilentlyContinue
}
if ($parkSettings) {
    Move-Item (Join-Path $tmpHome 'settings.json') (Join-Path $tmpHome 'settings.hooks-template.json') -Force
    Say "settings.json already has a hooks section - ours is written as settings.hooks-template.json. Merge the hooks block by hand."
}
Copy-Tree $tmpHome $ClaudeHome
Remove-Item $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
if (-not $DryRun) {
    # fail loud, never a quiet install that put nothing where Claude Code looks
    $landed = if ($parkSettings) { 'settings.hooks-template.json' } else { 'settings.json' }
    foreach ($must in @($landed, 'CLAUDE.md', 'hooks\tests')) {
        if (-not (Test-Path (Join-Path $ClaudeHome $must))) { throw "install: $must did not land in $ClaudeHome" }
    }
}

# ---- 3. copy work/ -----------------------------------------------------------------
Say "Copying work\ -> $WorkRoot"
Copy-Tree (Join-Path $here 'work') $WorkRoot
foreach ($d in @('reports', 'archive', 'system\auto', 'system\playbooks', 'system\reference')) {
    $p = Join-Path $WorkRoot $d
    if (-not $DryRun -and -not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}
foreach ($d in @('hooks\state', 'hooks\logs', 'hooks\backups')) {
    $p = Join-Path $ClaudeHome $d
    if (-not $DryRun -and -not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

# ---- 4. memory folder --------------------------------------------------------------
Say ""
Say "Memory: Claude Code keeps per-project memory under $ClaudeHome\projects\<project-slug>\memory\."
Say "        The slug is your project path with every non-alphanumeric character turned into '-'."
Say "        Copy $ClaudeHome\memory-template\* into that folder the first time you open the project."

# ---- 5. hook tests -----------------------------------------------------------------
if (-not $DryRun -and -not $SkipTests) {
    if ($Python) {
        $pyTests = Join-Path $ClaudeHome 'hooks\tests\py'
        $py = Get-Command python3 -ErrorAction SilentlyContinue
        if ($null -eq $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
        if ($null -eq $py) {
            Say ""
            Say "python3 is not on PATH - hook tests skipped. The hooks in settings.json need it too."
        } elseif (Test-Path $pyTests) {
            Say ""
            Say "Running Python hook tests..."
            & $py.Source -m unittest discover $pyTests
        }
    } else {
        $runAll = Join-Path $ClaudeHome 'hooks\tests\run-all.ps1'
        if (Test-Path $runAll) {
            Say ""
            Say "Running hook tests..."
            & powershell -NoProfile -ExecutionPolicy Bypass -File $runAll
        }
    }
}

Say ""
Say "Done. Next: open $ClaudeHome\CLAUDE.md and the files under $ClaudeHome\hooks\config\ and fill them in."
Say "Then read $WorkRoot\README.md."
