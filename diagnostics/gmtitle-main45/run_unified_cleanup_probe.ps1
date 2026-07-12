param(
  [string]$SourceFinalDwgPath,
  [string]$CleanedDwgPath,
  [string]$LogPath,
  [int]$TimeoutSeconds = 240
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

if (-not $SourceFinalDwgPath) {
  $SourceFinalDwgPath = Join-Path $workDir "swtitle_unified_fullflow_260711_01.dwg"
}
if (-not $CleanedDwgPath) {
  $CleanedDwgPath = Join-Path $workDir "swtitle_unified_fullflow_cleaned_260711_02.dwg"
}
if (-not $LogPath) {
  $LogPath = Join-Path $workDir "swtitle_unified_cleanup_probe_260711.txt"
}

if (-not (Test-Path -LiteralPath $SourceFinalDwgPath)) {
  throw "Saved unified final DWG not found: $SourceFinalDwgPath"
}

$sourceHashBefore = (Get-FileHash -LiteralPath $SourceFinalDwgPath -Algorithm SHA256).Hash
Copy-Item -LiteralPath $SourceFinalDwgPath -Destination $CleanedDwgPath -Force

$fixturePath = Join-Path $PSScriptRoot "unified_cleanup_probe.lsp"
$scriptPath = Join-Path $workDir "swtitle_unified_cleanup_probe_260711.scr"
$fixtureForLisp = ($fixturePath -replace "\\", "/")
Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value @(
  "(load `"$fixtureForLisp`")",
  "YES"
)

$env:SWCAD_TOOL_ROOT = $repoRoot
$env:SWCAD_UNIFIED_CLEANUP_LOG = $LogPath

& (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
  -DwgPath $CleanedDwgPath `
  -ScriptPath $scriptPath `
  -LogPath $LogPath `
  -CompletionPattern "Runtime check completed: yes" `
  -TimeoutSeconds $TimeoutSeconds `
  -WindowStyle Hidden

if (-not (Test-Path -LiteralPath $LogPath)) {
  throw "Unified cleanup probe log was not created: $LogPath"
}

$logText = Get-Content -LiteralPath $LogPath -Raw
$requiredLines = @(
    "Loaded version: 260711-unified-title-value-3",
  "Before style/delete/residue: 15/52/52",
  "Before pair/native-like: 15/15",
  "Cleanup call: OK",
  "Cleanup status: OK_FRAME_STYLE_NORMALIZATION_CLEANED",
  "After style/delete/residue: 0/0/0",
  "After frame/title/pair/native-like/orphan: 15/15/15/15/0",
  "Protected A4 note handles remaining: 8",
  "Saved cleaned probe DWG: yes",
  "Probe result: PASS",
  "Runtime check completed: yes"
)

foreach ($requiredLine in $requiredLines) {
  if (-not $logText.Contains($requiredLine)) {
    throw "Unified cleanup assertion failed; missing line: $requiredLine"
  }
}

$sourceHashAfter = (Get-FileHash -LiteralPath $SourceFinalDwgPath -Algorithm SHA256).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
  throw "Source final DWG hash changed during cleanup probe. Before=$sourceHashBefore After=$sourceHashAfter"
}

Write-Output "Source final SHA256 before: $sourceHashBefore"
Write-Output "Source final SHA256 after:  $sourceHashAfter"
Write-Output "Unified focused cleanup probe: PASS"
