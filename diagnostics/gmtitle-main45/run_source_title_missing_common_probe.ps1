param(
  [ValidateSet("Gap", "Prepare", "ScriptGuard")]
  [string]$Mode = "Gap",

  [ValidateSet("A2", "A3", "A4")]
  [string]$Sheet = "A3",

  [string]$SourceWorkCopyPath,

  [string]$ProbeDwgPath,

  [string]$LogPath,

  [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"
$safeMode = $Mode.ToLowerInvariant()
$safeSheet = $Sheet.ToLowerInvariant()

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $ProbeDwgPath) {
  $ProbeDwgPath = Join-Path $workDir ("swtitle_source_title_missing_{0}_{1}.dwg" -f $safeMode, $safeSheet)
}
if (-not $LogPath) {
  $LogPath = Join-Path $workDir ("swtitle_source_title_missing_{0}_{1}.txt" -f $safeMode, $safeSheet)
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}
if (-not (Test-Path -LiteralPath $workDir)) {
  New-Item -ItemType Directory -Path $workDir | Out-Null
}

Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $ProbeDwgPath -Force

$fixturePath = Join-Path $PSScriptRoot "source_title_missing_common_probe.lsp"
if (-not (Test-Path -LiteralPath $fixturePath)) {
  throw "Fixture LSP not found: $fixturePath"
}

$scriptPath = Join-Path $workDir ("swtitle_source_title_missing_{0}_{1}.scr" -f $safeMode, $safeSheet)
$fixtureForLisp = ($fixturePath -replace "\\", "/")
$scriptLines = @("(load `"$fixtureForLisp`")")
if ($Mode -ne "Gap") {
  $scriptLines += "YES"
}
Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value $scriptLines

$oldRoot = $env:SWCAD_TOOL_ROOT
$oldLog = $env:SWCAD_STM_LOG
$oldMode = $env:SWCAD_STM_MODE
$oldSheet = $env:SWCAD_STM_SHEET
try {
  $env:SWCAD_TOOL_ROOT = $repoRoot
  $env:SWCAD_STM_LOG = $LogPath
  $env:SWCAD_STM_MODE = switch ($Mode) {
    "Gap" { "GAP" }
    "Prepare" { "PREPARE" }
    "ScriptGuard" { "SCRIPT_GUARD" }
  }
  $env:SWCAD_STM_SHEET = $Sheet

  & (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
    -DwgPath $ProbeDwgPath `
    -ScriptPath $scriptPath `
    -LogPath $LogPath `
    -TimeoutSeconds $TimeoutSeconds
} finally {
  $env:SWCAD_TOOL_ROOT = $oldRoot
  $env:SWCAD_STM_LOG = $oldLog
  $env:SWCAD_STM_MODE = $oldMode
  $env:SWCAD_STM_SHEET = $oldSheet
}
