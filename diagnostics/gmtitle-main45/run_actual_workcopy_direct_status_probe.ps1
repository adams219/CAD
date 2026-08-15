param(
  [string]$SourceWorkCopyPath,

  [string]$LogPath,

  [string]$DetailSuffix = "_actual_workcopy_direct_260705",

  [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $repoRoot "work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $LogPath) {
  $LogPath = Join-Path $repoRoot "work\swtitle_actual_workcopy_direct_status_260705.txt"
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}

$workDir = Join-Path $repoRoot "work"
if (-not (Test-Path -LiteralPath $workDir)) {
  New-Item -ItemType Directory -Path $workDir | Out-Null
}

$fixturePath = Join-Path $PSScriptRoot "actual_workcopy_status_probe.lsp"
if (-not (Test-Path -LiteralPath $fixturePath)) {
  throw "Fixture LSP not found: $fixturePath"
}

$scriptPath = Join-Path $workDir "swtitle_actual_workcopy_direct_status_260705.scr"
$fixtureForLisp = ($fixturePath -replace "\\", "/")
Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value "(load `"$fixtureForLisp`")"

$env:SWCAD_TOOL_ROOT = $repoRoot
$env:SWCAD_ACTUAL_WORKCOPY_STATUS_LOG = $LogPath
$env:SWCAD_ACTUAL_WORKCOPY_LOG_SUFFIX = $DetailSuffix

$probeOutput = & (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
  -DwgPath $SourceWorkCopyPath `
  -ScriptPath $scriptPath `
  -LogPath $LogPath `
  -TimeoutSeconds $TimeoutSeconds

$probeOutput | Write-Output

if (-not (Test-Path -LiteralPath $LogPath)) {
  throw "Direct work-copy probe failed: expected log was not created: $LogPath"
}

$probeText = Get-Content -LiteralPath $LogPath -Raw -ErrorAction Stop
if ($probeText -notmatch "Runtime check completed:\s*yes") {
  throw "Direct work-copy probe failed: expected 'Runtime check completed: yes' in $LogPath"
}
