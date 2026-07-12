param(
  [string]$SourceDwgPath,
  [string]$ProbeDwgPath,
  [string]$LogPath,
  [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

if (-not $SourceDwgPath) {
  $SourceDwgPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_ORIGINAL_TEST_260711.dwg"
}
if (-not $ProbeDwgPath) {
  $ProbeDwgPath = Join-Path $workDir "swtitle_loose_title_source_probe_260711.dwg"
}
if (-not $LogPath) {
  $LogPath = Join-Path $workDir "swtitle_loose_title_source_probe_260711.txt"
}

if (-not (Test-Path -LiteralPath $SourceDwgPath)) {
  throw "Untouched source DWG not found: $SourceDwgPath"
}

$sourceHashBefore = (Get-FileHash -LiteralPath $SourceDwgPath -Algorithm SHA256).Hash
Copy-Item -LiteralPath $SourceDwgPath -Destination $ProbeDwgPath -Force

$fixturePath = Join-Path $PSScriptRoot "loose_title_source_probe.lsp"
$scriptPath = Join-Path $workDir "swtitle_loose_title_source_probe_260711.scr"
$fixtureForLisp = ($fixturePath -replace "\\", "/")
Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value "(load `"$fixtureForLisp`")"

$env:SWCAD_TOOL_ROOT = $repoRoot
$env:SWCAD_LOOSE_TITLE_SOURCE_LOG = $LogPath

& (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
  -DwgPath $ProbeDwgPath `
  -ScriptPath $scriptPath `
  -LogPath $LogPath `
  -CompletionPattern "Runtime check completed: yes" `
  -TimeoutSeconds $TimeoutSeconds `
  -WindowStyle Hidden

if (-not (Test-Path -LiteralPath $LogPath)) {
  throw "Loose-title probe log was not created: $LogPath"
}

$logText = Get-Content -LiteralPath $LogPath -Raw
$requiredLines = @(
    "Loaded version: 260712-portable-saveas-offsheet-frame-1",
  "Source title count: 15",
  "Source frame count: 15",
  "Frame-only count: 0",
  "Title sheet counts: A2=1, A3=12, A4=2",
  "Title source kinds: block-attributes=13, loose-text=2",
  "A4 loose-title sources: 2",
  "Mapping totals: mapped=18, unmapped=0, duplicates=0",
  "Loose-title companion shell inserts: 2",
  "A4 combined approval/date normalized: 1",
  "A4 combined approval/date remaining: 0",
  "Protected notes outside title region: 8",
  "Protected note handles used as title mappings: 0",
  "DBMOD after: 0",
  "Probe result: PASS",
  "Runtime check completed: yes"
)

foreach ($requiredLine in $requiredLines) {
  if (-not $logText.Contains($requiredLine)) {
    throw "Loose-title probe assertion failed; missing line: $requiredLine"
  }
}

$sourceHashAfter = (Get-FileHash -LiteralPath $SourceDwgPath -Algorithm SHA256).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
  throw "Untouched source DWG hash changed during read-only probe. Before=$sourceHashBefore After=$sourceHashAfter"
}

Write-Output "Source SHA256 before: $sourceHashBefore"
Write-Output "Source SHA256 after:  $sourceHashAfter"
Write-Output "Loose-title source regression probe: PASS"
