param(
  [string]$SourceFinalDwgPath,
  [string]$ProbeDwgPath,
  [string]$LogPath,
  [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

if (-not $SourceFinalDwgPath) {
  $SourceFinalDwgPath = Join-Path $workDir "swtitle_unified_fullflow_260711_01.dwg"
}
if (-not $ProbeDwgPath) {
  $ProbeDwgPath = Join-Path $workDir "swtitle_unified_final_verification_probe_260711.dwg"
}
if (-not $LogPath) {
  $LogPath = Join-Path $workDir "swtitle_unified_final_verification_probe_260711.txt"
}

if (-not (Test-Path -LiteralPath $SourceFinalDwgPath)) {
  throw "Saved unified final DWG not found: $SourceFinalDwgPath"
}

$finalHashBefore = (Get-FileHash -LiteralPath $SourceFinalDwgPath -Algorithm SHA256).Hash
Copy-Item -LiteralPath $SourceFinalDwgPath -Destination $ProbeDwgPath -Force

$fixturePath = Join-Path $PSScriptRoot "unified_final_verification_probe.lsp"
$scriptPath = Join-Path $workDir "swtitle_unified_final_verification_probe_260711.scr"
$fixtureForLisp = ($fixturePath -replace "\\", "/")
Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value "(load `"$fixtureForLisp`")"

$env:SWCAD_TOOL_ROOT = $repoRoot
$env:SWCAD_UNIFIED_FINAL_VERIFY_LOG = $LogPath

& (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
  -DwgPath $ProbeDwgPath `
  -ScriptPath $scriptPath `
  -LogPath $LogPath `
  -CompletionPattern "Runtime check completed: yes" `
  -TimeoutSeconds $TimeoutSeconds `
  -WindowStyle Hidden

if (-not (Test-Path -LiteralPath $LogPath)) {
  throw "Unified final verification log was not created: $LogPath"
}

$logText = Get-Content -LiteralPath $LogPath -Raw
$requiredLines = @(
    "Loaded version: 260713-frame-style-structure-guard-1",
  "SWTITLEVERIFY status: SWTITLEVERIFY_FINAL_OK",
  "Remaining source titles/frames/frame-only: 0/0/0",
  "Target title/frame-pair/native-like: 15/15/15",
  "Target title-overlapping source shell inserts: 0",
  "Target frame counts: A2=1, A3=12, A4=2",
  "Stored expected title counts: A2=1, A3=12, A4=2",
  "A4 attribute match count: 2",
  "A4 combined approval/date values: 0",
  "A4 remaining loose title texts: 0",
  "Original A4 loose title handles remaining: 0",
  "Original A4 title shell handles remaining: 0",
  "Protected A4 note handles remaining: 8",
  "Orphan/duplicate/upgrade candidates: 0/0/0",
  "DBMOD after: 0",
  "Probe result: PASS",
  "Runtime check completed: yes"
)

foreach ($requiredLine in $requiredLines) {
  if (-not $logText.Contains($requiredLine)) {
    throw "Unified final verification assertion failed; missing line: $requiredLine"
  }
}

$finalHashAfter = (Get-FileHash -LiteralPath $SourceFinalDwgPath -Algorithm SHA256).Hash
if ($finalHashAfter -ne $finalHashBefore) {
  throw "Saved unified final DWG hash changed during read-only verification. Before=$finalHashBefore After=$finalHashAfter"
}

Write-Output "Saved final SHA256 before: $finalHashBefore"
Write-Output "Saved final SHA256 after:  $finalHashAfter"
Write-Output "Unified final verification probe: PASS"
