param(
  [string]$SourceWorkCopyPath,

  [string]$ProbeDwgDirectory,

  [string[]]$Scenarios = @("mixed", "all_contaminated", "all_native"),

  [int]$TimeoutSeconds = 75
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $repoRoot "work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $ProbeDwgDirectory) {
  $ProbeDwgDirectory = Join-Path $repoRoot "work"
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}
if (-not (Test-Path -LiteralPath $ProbeDwgDirectory)) {
  New-Item -ItemType Directory -Path $ProbeDwgDirectory | Out-Null
}

$fixturePath = Join-Path $PSScriptRoot "frameclass_common_probe.lsp"
if (-not (Test-Path -LiteralPath $fixturePath)) {
  throw "Fixture LSP not found: $fixturePath"
}

$scriptPath = Join-Path $ProbeDwgDirectory "swtitle_frameclass_common_probe.scr"
$fixtureForLisp = ($fixturePath -replace "\\", "/")
Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value "(load `"$fixtureForLisp`")"

$env:SWCAD_TOOL_ROOT = $repoRoot

foreach ($scenario in $Scenarios) {
  $safeScenario = ($scenario.ToLowerInvariant() -replace "[^a-z0-9_]", "_")
  $probeDwgPath = Join-Path $ProbeDwgDirectory ("swtitle_frameclass_common_probe_{0}.dwg" -f $safeScenario)
  $logPath = Join-Path $ProbeDwgDirectory ("swtitle_frameclass_common_probe_{0}.txt" -f $safeScenario)

  Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $probeDwgPath -Force

  $env:SWCAD_FRAMECLASS_SCENARIO = $scenario

  & (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
    -DwgPath $probeDwgPath `
    -ScriptPath $scriptPath `
    -LogPath $logPath `
    -TimeoutSeconds $TimeoutSeconds
}
