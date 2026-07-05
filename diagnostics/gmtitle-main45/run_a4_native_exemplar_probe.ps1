param(
  [Alias("SourceDwgPath")]
  [string]$SourceWorkCopyPath,

  [string]$ProbeDwgPath,

  [string]$LogPath,

  [int]$TimeoutSeconds = 75
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

if (-not $SourceWorkCopyPath) {
  throw @"
A4_NATIVE_EXEMPLAR_REQUIRES_SOURCEWORKCOPYPATH
run_a4_native_exemplar_probe.ps1 requires -SourceWorkCopyPath or -SourceDwgPath.

Use a saved scratch/native A4 GMTITLE DWG when checking for a usable A4 exemplar:
  powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1 -SourceDwgPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\<scratch-native-a4>.dwg"

The main verification suite passes the default work-copy path explicitly for the known A4 gap probe.
"@
}
if (-not $ProbeDwgPath) {
  $ProbeDwgPath = Join-Path $repoRoot "work\swtitle_a4_native_exemplar_probe_260705.dwg"
}
if (-not $LogPath) {
  $LogPath = Join-Path $repoRoot "work\swtitle_a4_native_exemplar_probe_260705.txt"
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}

$workDir = Join-Path $repoRoot "work"
if (-not (Test-Path -LiteralPath $workDir)) {
  New-Item -ItemType Directory -Path $workDir | Out-Null
}

$fixturePath = Join-Path $PSScriptRoot "a4_native_exemplar_probe.lsp"
if (-not (Test-Path -LiteralPath $fixturePath)) {
  throw "Fixture LSP not found: $fixturePath"
}

Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $ProbeDwgPath -Force

$scriptPath = Join-Path $workDir "swtitle_a4_native_exemplar_probe_260705.scr"
$fixtureForLisp = ($fixturePath -replace "\\", "/")
Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value "(load `"$fixtureForLisp`")"

$env:SWCAD_TOOL_ROOT = $repoRoot
$env:SWCAD_A4_NATIVE_LOG = $LogPath

& (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
  -DwgPath $ProbeDwgPath `
  -ScriptPath $scriptPath `
  -LogPath $LogPath `
  -TimeoutSeconds $TimeoutSeconds
