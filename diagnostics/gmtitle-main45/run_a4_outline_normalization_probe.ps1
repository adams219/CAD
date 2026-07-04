param(
  [string]$SourceWorkCopyPath,

  [string[]]$Strategies = @("none", "huge-insert", "direct-outside"),

  [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $repoRoot "work\0000_A_DRP125 CP_ALL_260704_test.dwg"
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}

$workDir = Join-Path $repoRoot "work"
if (-not (Test-Path -LiteralPath $workDir)) {
  New-Item -ItemType Directory -Path $workDir | Out-Null
}

$fixturePath = Join-Path $PSScriptRoot "a4_outline_normalization_probe.lsp"
if (-not (Test-Path -LiteralPath $fixturePath)) {
  throw "Fixture LSP not found: $fixturePath"
}

$fixtureForLisp = ($fixturePath -replace "\\", "/")
$env:SWCAD_TOOL_ROOT = $repoRoot

foreach ($strategy in $Strategies) {
  $safeStrategy = $strategy -replace '[^A-Za-z0-9_-]', '_'
  $probeDwgPath = Join-Path $workDir ("swtitle_a4_outline_norm_{0}_260705.dwg" -f $safeStrategy)
  $scriptPath = Join-Path $workDir ("swtitle_a4_outline_norm_{0}_260705.scr" -f $safeStrategy)
  $logPath = Join-Path $workDir ("swtitle_a4_outline_norm_{0}_260705.txt" -f $safeStrategy)

  Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $probeDwgPath -Force

  Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value @(
    "(load `"$fixtureForLisp`")"
  )

  $env:SWCAD_A4_NORM_STRATEGY = $strategy
  $env:SWCAD_A4_NORM_LOG = $logPath

  Write-Output ("===== A4 outline normalization strategy: {0} =====" -f $strategy)
  & (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
    -DwgPath $probeDwgPath `
    -ScriptPath $scriptPath `
    -LogPath $logPath `
    -TimeoutSeconds $TimeoutSeconds
}
