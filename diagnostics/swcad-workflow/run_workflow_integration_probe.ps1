param(
  [int]$TimeoutSeconds = 360,

  [ValidateSet("MATERIALIZE_RAW", "NATIVE_GUARD", "DOWNSTREAM", "REOPEN")]
  [string[]]$Modes = @("MATERIALIZE_RAW", "NATIVE_GUARD", "DOWNSTREAM", "REOPEN")
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$rawSource = (Resolve-Path -LiteralPath (Join-Path $repoRoot "work\0000_A_DRP125_CP_ALL_260626_ORIGINAL_TEST_260711.dwg")).Path
$nativeSource = (Resolve-Path -LiteralPath (Join-Path $repoRoot "portable-e2e\output\swtitle_portable_result_260712.dwg")).Path
$probe = Join-Path $PSScriptRoot "workflow_integration_probe.lsp"
$runner = Join-Path $repoRoot "diagnostics\gmtitle-main45\run_readonly_probe.ps1"
$testRoot = Join-Path $repoRoot "work\swcad-workflow-tests"
$logRoot = Join-Path $repoRoot "tmp\swcad-workflow-integration"
$materializedOutput = Join-Path $testRoot "workflow_materialized_raw.dwg"
$downstreamOutput = Join-Path $testRoot "workflow_downstream_complete.dwg"
$scriptPath = Join-Path $testRoot "workflow_integration_probe.scr"

$templateCandidates = @(
  (Join-Path $env:LOCALAPPDATA "Gstarsoft\GstarMechStd\R24\ko-KR\Template\gcadiso.dwt"),
  (Join-Path $env:LOCALAPPDATA "Gstarsoft\GstarMechStd\R24\ko-KR\Template\gm_iso.dwt")
)
$templatePath = $templateCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $templatePath) {
  throw "No GstarCAD Mechanical template found."
}

[void](New-Item -ItemType Directory -Path $testRoot -Force)
[void](New-Item -ItemType Directory -Path $logRoot -Force)
Remove-Item -LiteralPath $materializedOutput, $downstreamOutput -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath $nativeSource -Destination $downstreamOutput -Force

$rootForLisp = $repoRoot.Replace("\", "/")
$probeForLisp = $probe.Replace("\", "/")

$rawHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $rawSource).Hash
$nativeHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $nativeSource).Hash

function Invoke-WorkflowProbe {
  param(
    [string]$Mode,
    [string]$DwgPath,
    [string]$SourcePath,
    [string]$OutputPath,
    [string[]]$Required
  )

  $logPath = Join-Path $logRoot ("{0}.txt" -f $Mode.ToLowerInvariant())
  Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
  $sourceForLisp = $SourcePath.Replace("\", "/")
  $outputForLisp = $OutputPath.Replace("\", "/")
  $logForLisp = $logPath.Replace("\", "/")
  $scriptLines = @(
    "(setenv `"SWCAD_WORKFLOW_ROOT`" `"$rootForLisp`")",
    "(setenv `"SWCAD_WORKFLOW_MODE`" `"$Mode`")",
    "(setenv `"SWCAD_WORKFLOW_SOURCE`" `"$sourceForLisp`")",
    "(setenv `"SWCAD_WORKFLOW_OUTPUT`" `"$outputForLisp`")",
    "(setenv `"SWCAD_WORKFLOW_LOG`" `"$logForLisp`")",
    "(load `"$probeForLisp`")"
  )
  [IO.File]::WriteAllLines($scriptPath, $scriptLines, [Text.UTF8Encoding]::new($false))

  $runnerOutput = & $runner `
    -DwgPath $DwgPath `
    -ScriptPath $scriptPath `
    -LogPath $logPath `
    -CompletionPattern "Runtime check completed:" `
    -TimeoutSeconds $TimeoutSeconds `
    -WindowStyle Minimized

  $text = [IO.File]::ReadAllText($logPath)
  foreach ($marker in $Required) {
    if (-not $text.Contains($marker)) {
      throw "$Mode probe missing evidence: $marker"
    }
  }
  Write-Output ("{0}: PASS" -f $Mode)
}

if ($Modes -contains "MATERIALIZE_RAW") {
  Invoke-WorkflowProbe `
  -Mode "MATERIALIZE_RAW" `
  -DwgPath $templatePath `
  -SourcePath $rawSource `
  -OutputPath $materializedOutput `
  -Required @(
    "Remaining XREF count: 0",
    "Top dimension count: 143",
    "Source title count: 15",
    "Source frame count: 15",
    "Materialized state: OK",
    "Workflow stage: TITLE",
    "Runtime check completed: yes"
  )
}

if ($Modes -contains "NATIVE_GUARD") {
  Invoke-WorkflowProbe `
  -Mode "NATIVE_GUARD" `
  -DwgPath $templatePath `
  -SourcePath $nativeSource `
  -OutputPath "" `
  -Required @(
    "Detected deep native target references: 30",
    "Remaining XREF count: 1",
    "Materialized state: <none>",
    "Workflow stage: XREF",
    "Runtime check completed: yes"
  )
}

if ($Modes -contains "DOWNSTREAM") {
  Invoke-WorkflowProbe `
  -Mode "DOWNSTREAM" `
  -DwgPath $downstreamOutput `
  -SourcePath "" `
  -OutputPath "" `
  -Required @(
    "Public SWCADRUN sequence: yes",
    "DIMSTYLE state: OK",
    "Dimension semantics: PRESERVED",
    "Dimension restore count:",
    "Layout plan count before create: 15",
    "Layout plan first: #001",
    "Layout plan last: #015",
    "Layout count: 15",
    "Layout placement mode: MANUAL_FRAME_COORDINATES",
    "Layout state plan count: 15",
    "Layout state signature: 15:",
    "Title verify status: OK",
    "DIMSTYLE audit: yes",
    "Layout audit: yes",
    "Workflow stage: COMPLETE",
    "Runtime check completed: yes"
  )
}

if ($Modes -contains "REOPEN") {
  Invoke-WorkflowProbe `
  -Mode "REOPEN" `
  -DwgPath $downstreamOutput `
  -SourcePath "" `
  -OutputPath "" `
  -Required @(
    "DIMSTYLE state: OK",
    "Dimension semantics: PRESERVED",
    "Dimension restore count:",
    "LAYOUT state: OK",
    "Layout placement mode: MANUAL_FRAME_COORDINATES",
    "Layout state plan count: 15",
    "Layout state signature: 15:",
    "Layout count: 15",
    "Title verify status: OK",
    "DIMSTYLE audit: yes",
    "Layout audit: yes",
    "Public SWCADVERIFY returned without error: yes",
    "Workflow stage: COMPLETE",
    "DBMOD after: 0",
    "Runtime check completed: yes"
  )
}

$rawHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $rawSource).Hash
$nativeHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $nativeSource).Hash
if ($rawHashAfter -ne $rawHashBefore) {
  throw "Raw source hash changed. Before=$rawHashBefore After=$rawHashAfter"
}
if ($nativeHashAfter -ne $nativeHashBefore) {
  throw "Native source hash changed. Before=$nativeHashBefore After=$nativeHashAfter"
}

Write-Output "===== SWCAD Workflow integration result ====="
if ($Modes -contains "MATERIALIZE_RAW") { Write-Output "Raw XREF materialization: PASS" }
if ($Modes -contains "NATIVE_GUARD") { Write-Output "Native GMTITLE XREF guard: PASS" }
if ($Modes -contains "DOWNSTREAM") { Write-Output "GMTITLE -> DIMSTYLE -> 15 A4 Layout handoff: PASS" }
if ($Modes -contains "REOPEN") { Write-Output "Save/reopen/state persistence: PASS" }
Write-Output ("Raw source SHA256 unchanged: {0}" -f $rawHashAfter)
Write-Output ("Native source SHA256 unchanged: {0}" -f $nativeHashAfter)
Write-Output ("Completed work copy: {0}" -f $downstreamOutput)
Write-Output "SWCAD Workflow integration probe: PASS"
