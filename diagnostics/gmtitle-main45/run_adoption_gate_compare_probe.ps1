param(
  [Parameter(Mandatory = $true)]
  [string]$LspPath,

  [Parameter(Mandatory = $true)]
  [string]$Label,

  [string]$SourceWorkCopyPath,

  [string]$ProbeDwgPath,

  [string]$LogPath,

  [int]$TimeoutSeconds = 75
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $repoRoot "work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $ProbeDwgPath) {
  $safeLabel = ($Label -replace "[^A-Za-z0-9_-]", "_")
  $ProbeDwgPath = Join-Path $workDir ("swtitle_adoption_gate_compare_{0}.dwg" -f $safeLabel)
}
if (-not $LogPath) {
  $safeLabel = ($Label -replace "[^A-Za-z0-9_-]", "_")
  $LogPath = Join-Path $workDir ("swtitle_adoption_gate_compare_{0}.txt" -f $safeLabel)
}

$resolvedLspPath = (Resolve-Path -LiteralPath $LspPath).Path
if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}

if (-not (Test-Path -LiteralPath $workDir)) {
  New-Item -ItemType Directory -Path $workDir | Out-Null
}

Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $ProbeDwgPath -Force

$fixturePath = Join-Path $PSScriptRoot "adoption_gate_compare_probe.lsp"
if (-not (Test-Path -LiteralPath $fixturePath)) {
  throw "Fixture LSP not found: $fixturePath"
}

$safeScriptLabel = ($Label -replace "[^A-Za-z0-9_-]", "_")
$scriptPath = Join-Path $workDir ("swtitle_adoption_gate_compare_{0}.scr" -f $safeScriptLabel)
$fixtureForLisp = ($fixturePath -replace "\\", "/")
Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value "(load `"$fixtureForLisp`")"

$env:SWCAD_TOOL_ROOT = $repoRoot
$env:SWCAD_COMPARE_LSP = $resolvedLspPath
$env:SWCAD_COMPARE_LABEL = $Label
$env:SWCAD_COMPARE_LOG = $LogPath

& (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
  -DwgPath $ProbeDwgPath `
  -ScriptPath $scriptPath `
  -LogPath $LogPath `
  -TimeoutSeconds $TimeoutSeconds
