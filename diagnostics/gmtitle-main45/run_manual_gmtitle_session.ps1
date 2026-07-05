param(
  [string]$SourceWorkCopyPath,

  [switch]$SkipOpenWorkcopy,

  [switch]$AllowExistingGstarCAD,

  [int]$OpenWaitForMainWindowSeconds = 60,

  [int]$OpenPostVisibleCheckSeconds = 120,

  [int]$WaitForGstarCADCloseTimeoutSeconds = 7200,

  [int]$AutoRefreshTimeoutSeconds = 180,

  [int]$FinalGateTimeoutSeconds = 180,

  [switch]$SkipFinalCompletionGate,

  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}

function Write-Step {
  param([AllowEmptyString()][string]$Message)

  [Console]::Out.WriteLine($Message)
}

function Get-QuotedCommandPreview {
  param([string[]]$Parts)

  $quoted = foreach ($part in $Parts) {
    if ($part -match '[\s"`]') {
      '"' + ($part -replace '"', '\"') + '"'
    } else {
      $part
    }
  }
  return ($quoted -join " ")
}

function Invoke-ChildPowerShell {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,

    [string[]]$Arguments = @(),

    [Parameter(Mandatory = $true)]
    [string]$Label,

    [switch]$AllowFailure
  )

  $powershellExe = Join-Path $PSHOME "powershell.exe"
  $fullArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $ScriptPath
  ) + $Arguments

  Write-Step ""
  Write-Step ("----- {0} -----" -f $Label)
  Write-Step ("Command: {0}" -f (Get-QuotedCommandPreview -Parts (@($powershellExe) + $fullArgs)))

  & $powershellExe @fullArgs
  $exitCode = $LASTEXITCODE
  Write-Step ("{0} exit code: {1}" -f $Label, $exitCode)

  if (($exitCode -ne 0) -and (-not $AllowFailure)) {
    Write-Step ("Result: {0}_FAILED" -f ($Label -replace "[^A-Za-z0-9]+", "_").Trim("_").ToUpperInvariant())
    exit $exitCode
  }

  return $exitCode
}

function Wait-ForGstarCADToClose {
  param([int]$TimeoutSeconds)

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $existing = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
    if ($existing.Count -eq 0) {
      Write-Step "No running GstarCAD process detected. Continuing after-manual check."
      return $true
    }
    Write-Step ("Waiting for GstarCAD to close before refreshing evidence... active PID(s): {0}" -f (($existing | ForEach-Object { $_.Id }) -join ", "))
    Start-Sleep -Seconds 10
  }

  Write-Step "Result: WAIT_FOR_GSTARCAD_CLOSE_TIMEOUT"
  Write-Step "Next: save and close GstarCAD, then run run_after_manual_gmtitle_step.ps1 manually."
  return $false
}

Write-Step "===== GMTITLE manual visible-CAD session ====="
Write-Step ("Repo root: {0}" -f $repoRoot)
Write-Step ("Source work copy: {0}" -f $SourceWorkCopyPath)
Write-Step "Purpose: open the work-copy, let the user run one visible GMTITLE step, then wait for GstarCAD to close and refresh the next action card."
Write-Step "Safety: this script does not run SWTITLECONVERTNEXT, does not click the GMTITLE dialog, and does not save the DWG."
Write-Step "Manual CAD commands:"
Write-Step "  APPLOAD"
Write-Step ("  {0}" -f (Join-Path $repoRoot "swcad_load.lsp"))
Write-Step "  SWTITLEVERSION"
Write-Step "  SWTITLESTATUS"
Write-Step "  SWTITLECONVERTNEXT"
Write-Step "After one GMTITLE step: save the work-copy DWG and close GstarCAD. This script will then run the after-manual check."

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  Write-Step "Result: BLOCKED_WORKCOPY_MISSING"
  Write-Step ("Work-copy DWG not found: {0}" -f $SourceWorkCopyPath)
  exit 1
}

if ($DryRun) {
  Write-Step "Dry run: visible GstarCAD is not launched and hidden probes are not run."
  Write-Step "1. Optionally run run_open_workcopy_for_manual_convert.ps1."
  Write-Step "2. Wait for GstarCAD to close."
  Write-Step "3. Run run_after_manual_gmtitle_step.ps1."
  Write-Step "Result: DRY_RUN_READY"
  exit 0
}

if (-not $SkipOpenWorkcopy) {
  $openArgs = @(
    "-SourceWorkCopyPath",
    $SourceWorkCopyPath,
    "-WaitForMainWindowSeconds",
    [string]$OpenWaitForMainWindowSeconds,
    "-PostVisibleCheckSeconds",
    [string]$OpenPostVisibleCheckSeconds
  )
  if ($AllowExistingGstarCAD) {
    $openArgs += "-AllowExistingGstarCAD"
  }

  $openExitCode = Invoke-ChildPowerShell `
    -ScriptPath (Join-Path $PSScriptRoot "run_open_workcopy_for_manual_convert.ps1") `
    -Arguments $openArgs `
    -Label "Open work-copy for manual convert" `
    -AllowFailure

  if ($openExitCode -ne 0) {
    Write-Step "Visible open helper did not complete successfully."
    Write-Step "If you opened the work-copy manually, rerun this script with -SkipOpenWorkcopy after CAD is open, or close CAD and use run_after_manual_gmtitle_step.ps1."
    exit $openExitCode
  }
} else {
  Write-Step "SkipOpenWorkcopy: assuming GstarCAD is already open or will be opened manually."
}

Write-Step ""
Write-Step "Now finish one manual GMTITLE step in GstarCAD, save the DWG, and close GstarCAD."
Write-Step "This script will wait and then refresh direct-probe evidence."

if (-not (Wait-ForGstarCADToClose -TimeoutSeconds $WaitForGstarCADCloseTimeoutSeconds)) {
  exit 1
}

$afterArgs = @(
  "-SourceWorkCopyPath",
  $SourceWorkCopyPath,
  "-AutoRefreshTimeoutSeconds",
  [string]$AutoRefreshTimeoutSeconds,
  "-FinalGateTimeoutSeconds",
  [string]$FinalGateTimeoutSeconds
)
if ($SkipFinalCompletionGate) {
  $afterArgs += "-SkipFinalCompletionGate"
}

Invoke-ChildPowerShell `
  -ScriptPath (Join-Path $PSScriptRoot "run_after_manual_gmtitle_step.ps1") `
  -Arguments $afterArgs `
  -Label "After-manual GMTITLE step check"

Write-Step "Result: MANUAL_GMTITLE_SESSION_COMPLETE"
