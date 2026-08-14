param(
  [string]$SourceWorkCopyPath,

  [string]$ProbeDwgPath,

  [string]$LogPath,

  [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $repoRoot "work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $ProbeDwgPath) {
  $ProbeDwgPath = Join-Path $workDir "swtitle_post_first_native_transition_probe.dwg"
}
if (-not $LogPath) {
  $LogPath = Join-Path $workDir "swtitle_post_first_native_transition_probe.txt"
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}

if (-not (Test-Path -LiteralPath $workDir)) {
  New-Item -ItemType Directory -Path $workDir | Out-Null
}

Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $ProbeDwgPath -Force

$fixturePath = Join-Path $PSScriptRoot "post_first_native_transition_probe.lsp"
if (-not (Test-Path -LiteralPath $fixturePath)) {
  throw "Fixture LSP not found: $fixturePath"
}

$scriptPath = Join-Path $workDir "swtitle_post_first_native_transition_probe.scr"
$fixtureForLisp = ($fixturePath -replace "\\", "/")
Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value "(load `"$fixtureForLisp`")"

$env:SWCAD_TOOL_ROOT = $repoRoot
$env:SWCAD_COMPARE_LSP = Join-Path $repoRoot "src\tools\gmtitle\swcad_title_scale.lsp"
$env:SWCAD_COMPARE_LABEL = "post first native transition"
$env:SWCAD_COMPARE_LOG = $LogPath

& (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
  -DwgPath $ProbeDwgPath `
  -ScriptPath $scriptPath `
  -LogPath $LogPath `
  -TimeoutSeconds $TimeoutSeconds
