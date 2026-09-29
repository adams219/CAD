param(
  # A drawing at the SWCAD TITLE stage (source titles still present). When omitted, the
  # 30-sheet fixture is materialized first with the workflow integration probe.
  [string]$TitleStageDwg,

  # Converted drawings to check with SWTITLEVERIFY's value checks (read-only copies).
  [string[]]$CheckDwg,

  # One DWG path per line; easier than an array when started with -File.
  [string]$CheckListFile,

  # Also run the TITLE stage in a visible GstarCAD (real GMTITLE dialog) on a work copy.
  [switch]$EndToEnd,

  # With -EndToEnd: keep running SWCADRUN to COMPLETE, then check the SWCADVERIFY parts.
  [switch]$FullWorkflow,

  [string]$OutputRoot,

  [int]$TimeoutSeconds = 300
)

# GMTITLE title value regression test (2026-09-29).
# 1. plan  : for every source sheet, the source title data and the 11 values the
#            transfer will write (loaded swcad_title_scale.lsp functions, nothing changed)
# 2. write : unit checks, then the planned values are written into an attributed title
#            of a throw-away copy, read back and verified
# 3. verify: SWTITLEVERIFY final summary on -CheckDwg copies
# 4. e2e   : optional TITLE stage through SWCADRUN, then the converted titles are compared
#            with the plan
# Source drawings are only copied and hashed. GstarCAD must be closed.

$ErrorActionPreference = "Stop"
if ($CheckListFile) {
  $CheckDwg = @($CheckDwg) + @(Get-Content -LiteralPath $CheckListFile -Encoding UTF8 | Where-Object { $_.Trim() -ne "" })
}
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$runner = Join-Path $repoRoot "diagnostics\gmtitle-main45\run_readonly_probe.ps1"
$module = Join-Path $repoRoot "src\tools\gmtitle\swcad_title_scale.lsp"
if (-not $OutputRoot) {
  $OutputRoot = Join-Path $repoRoot ("tmp\gmtitle-value-test\" + (Get-Date -Format "yyMMdd_HHmmss"))
}
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
if (Get-Process -Name gcad -ErrorAction SilentlyContinue) { throw "GstarCAD is open. Save and close it before running this test." }

function Invoke-Probe([string]$SourceDwg, [string]$Probe, [string]$Name, [string]$Marker, [hashtable]$Environment) {
  $copy = Join-Path $OutputRoot "$Name.dwg"
  $log = Join-Path $OutputRoot "$Name.log"
  $scr = Join-Path $OutputRoot "$Name.scr"
  $hash = (Get-FileHash -LiteralPath $SourceDwg -Algorithm SHA256).Hash
  Copy-Item -LiteralPath $SourceDwg -Destination $copy -Force
  if (Test-Path -LiteralPath $log) { [IO.File]::Delete($log) }
  $lines = @()
  foreach ($key in $Environment.Keys) {
    $lines += "(setenv `"$key`" `"" + ([string]$Environment[$key]).Replace('\', '/') + "`")"
  }
  $lines += "(load `"" + $Probe.Replace('\', '/') + "`")"
  [IO.File]::WriteAllLines($scr, $lines, [Text.UTF8Encoding]::new($false))
  $null = & $runner -DwgPath $copy -ScriptPath $scr -LogPath $log -CompletionPattern $Marker -TimeoutSeconds $TimeoutSeconds -WindowStyle Minimized
  if ((Get-FileHash -LiteralPath $SourceDwg -Algorithm SHA256).Hash -ne $hash) { throw "Source drawing changed: $SourceDwg" }
  if (-not (Test-Path -LiteralPath $log)) { throw "$Name produced no log: $log" }
  Write-Output ("{0}: done" -f $Name)
}

if (-not $TitleStageDwg) {
  Write-Output "Materializing the 30-sheet fixture (workflow integration probe, MATERIALIZE_WRAPPED_XREF)..."
  # The probe's own PASS/FAIL is not needed here; the log below decides.
  $ErrorActionPreference = "Continue"
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "diagnostics\swcad-workflow\run_workflow_integration_probe.ps1") -Modes MATERIALIZE_WRAPPED_XREF 2>&1 | Out-Null
  $ErrorActionPreference = "Stop"
  $built = Join-Path $repoRoot "work\swcad-workflow-tests\workflow_materialized_wrapped_xref.dwg"
  $log = Join-Path $repoRoot "tmp\swcad-workflow-integration\materialize_wrapped_xref.txt"
  if (-not (Test-Path -LiteralPath $built) -or -not (Select-String -LiteralPath $log -Pattern "Workflow stage: TITLE" -Quiet)) { throw "The fixture did not reach the TITLE stage. See $log" }
  $TitleStageDwg = Join-Path $OutputRoot "title_stage.dwg"
  Copy-Item -LiteralPath $built -Destination $TitleStageDwg -Force
}
Write-Output "TITLE stage drawing: $TitleStageDwg"

Invoke-Probe $TitleStageDwg (Join-Path $PSScriptRoot "title_value_plan_probe.lsp") "plan" "Value plan probe completed: yes" @{ SWT_PLAN_LOG = (Join-Path $OutputRoot "plan.log"); SWT_PLAN_MODULE = $module }
Invoke-Probe $TitleStageDwg (Join-Path $PSScriptRoot "title_value_write_probe.lsp") "write" "Write verify probe completed: yes" @{ SWT_WRITE_LOG = (Join-Path $OutputRoot "write.log"); SWT_PLAN_MODULE = $module }

$index = 0
foreach ($dwg in $CheckDwg) {
  $index++
  $name = "verify_{0:D2}_{1}" -f $index, ([IO.Path]::GetFileNameWithoutExtension($dwg) -replace '[^\w\-]', '_')
  Invoke-Probe $dwg (Join-Path $PSScriptRoot "title_value_verify_probe.lsp") $name "Verify probe completed: yes" @{ SWT_VERIFY_LOG = (Join-Path $OutputRoot "$name.log"); SWT_PLAN_MODULE = $module }
}

if ($EndToEnd) {
  $driverLog = Join-Path $OutputRoot "e2e_driver.log"
  & (Join-Path $PSScriptRoot "run_title_stage_e2e.ps1") -SourceDwg $TitleStageDwg -LogPath $driverLog -FullWorkflow:$FullWorkflow | Out-Null
  $work = ((Get-Content -LiteralPath $driverLog -Encoding UTF8 | Where-Object { $_ -match 'work result: ' } | Select-Object -Last 1) -replace '^.*work result: ', '')
  if (-not $work -or -not (Test-Path -LiteralPath $work)) { throw "End-to-end run left no work drawing. See $driverLog" }
  Invoke-Probe $work (Join-Path $PSScriptRoot "title_value_dump_probe.lsp") "e2e_dump" "Attribute probe completed: yes" @{ SWT_ATTR_LOG = (Join-Path $OutputRoot "e2e_dump.log") }
  Invoke-Probe $work (Join-Path $PSScriptRoot "title_value_verify_probe.lsp") "verify_e2e" "Verify probe completed: yes" @{ SWT_VERIFY_LOG = (Join-Path $OutputRoot "verify_e2e.log"); SWT_PLAN_MODULE = $module }
  if ($FullWorkflow) {
    Invoke-Probe $work (Join-Path $PSScriptRoot "workflow_final_verify_probe.lsp") "final_verify" "Final verify probe completed: yes" @{ SWT_FINAL_LOG = (Join-Path $OutputRoot "final_verify.log"); SWT_WORKFLOW_LOADER = (Join-Path $repoRoot "apps\swcad-workflow\swcad_workflow_load.lsp") }
  }
}

$summary = Join-Path $OutputRoot "summary.txt"
& (Join-Path $PSScriptRoot "analyze_title_value_test.ps1") -OutputRoot $OutputRoot | Tee-Object -FilePath $summary
Write-Output "Summary: $summary"
