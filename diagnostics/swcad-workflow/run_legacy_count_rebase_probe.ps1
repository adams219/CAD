param(
  [string]$SourceDwg = "",

  [int]$TimeoutSeconds = 360,

  [switch]$AllowExistingGstarCAD,

  [switch]$PrepareOnly
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
if (-not $SourceDwg) {
  $SourceDwg = Join-Path $repoRoot "work\Verify_XRef Sw WorkFlow Test_260713.dwg"
}
$SourceDwg = (Resolve-Path -LiteralPath $SourceDwg).Path
$testRoot = Join-Path $repoRoot "work\swcad-workflow-tests"
$output = Join-Path $testRoot "verify_xref_legacy_count_rebase_probe.dwg"
$logRoot = Join-Path $repoRoot "tmp\swcad-workflow-integration"
$logPath = Join-Path $logRoot "legacy_count_rebase.txt"
$scriptPath = Join-Path $testRoot "legacy_count_rebase_probe.scr"
$probe = Join-Path $PSScriptRoot "legacy_count_rebase_probe.lsp"
$runner = Join-Path $repoRoot "diagnostics\gmtitle-main45\run_readonly_probe.ps1"

[void](New-Item -ItemType Directory -Path $testRoot -Force)
[void](New-Item -ItemType Directory -Path $logRoot -Force)
Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath $SourceDwg -Destination $output -Force

$sourceHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $SourceDwg).Hash
$rootForLisp = $repoRoot.Replace("\", "/")
$logForLisp = $logPath.Replace("\", "/")
$probeForLisp = $probe.Replace("\", "/")
$scriptLines = @(
  "(setenv `"SWCAD_WORKFLOW_ROOT`" `"$rootForLisp`")",
  "(setenv `"SWCAD_WORKFLOW_LOG`" `"$logForLisp`")",
  "(load `"$probeForLisp`")"
)
[IO.File]::WriteAllLines($scriptPath, $scriptLines, [Text.UTF8Encoding]::new($false))

if ($PrepareOnly) {
  Write-Output "Legacy count rebase probe prepared without launching GstarCAD."
  Write-Output ("Source preserved: {0}" -f $SourceDwg)
  Write-Output ("Probe copy: {0}" -f $output)
  Write-Output ("Script: {0}" -f $scriptPath)
  Write-Output ("Expected log: {0}" -f $logPath)
  return
}

$runnerArguments = @{
  DwgPath = $output
  ScriptPath = $scriptPath
  LogPath = $logPath
  CompletionPattern = "Runtime check completed:"
  TimeoutSeconds = $TimeoutSeconds
  WindowStyle = "Minimized"
}
if ($AllowExistingGstarCAD) {
  $runnerArguments.AllowExistingGstarCAD = $true
}

& $runner @runnerArguments

$text = [IO.File]::ReadAllText($logPath)
$required = @(
  "Remaining XREF/wrappers: 0/0",
  "Top dimension count: 254",
  "Target pair/native-like count: 30/30",
  "Before mismatch: yes",
  "Before title verify: FAIL",
  "Legacy compatibility title verify: OK",
  "Legacy compatibility read-only: yes",
  "Public SWCADVERIFY legacy compatibility: SWTITLEVERIFY_FINAL_OK",
  "Public SWCADVERIFY read-only: yes",
  "Direct safe preflight: OK",
  "Rebase result: yes",
  "Rebase status: OK_EXPECTED_COUNTS_REBASED",
  "After counts match actual: yes",
  "Classifier markers complete: yes",
  "Native structure unchanged: yes",
  "After title verify: OK",
  "Save result: yes",
  "DBMOD after save: 0",
  "Runtime check completed: yes"
)
foreach ($marker in $required) {
  if (-not $text.Contains($marker)) {
    throw "Legacy count rebase probe missing evidence: $marker"
  }
}

$sourceHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $SourceDwg).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
  throw "Source DWG hash changed. Before=$sourceHashBefore After=$sourceHashAfter"
}

Write-Output "===== Legacy expected-count rebase result ====="
Write-Output "PASS"
Write-Output ("Source preserved: {0}" -f $SourceDwg)
Write-Output ("Probe copy: {0}" -f $output)
Write-Output ("Log: {0}" -f $logPath)
