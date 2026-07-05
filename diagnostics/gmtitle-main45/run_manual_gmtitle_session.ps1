param(
  [string]$SourceWorkCopyPath,

  [switch]$SkipOpenWorkcopy,

  [switch]$AllowExistingGstarCAD,

  [int]$OpenWaitForMainWindowSeconds = 60,

  [int]$OpenPostVisibleCheckSeconds = 120,

  [int]$WaitForGstarCADCloseTimeoutSeconds = 7200,

  [int]$AutoRefreshTimeoutSeconds = 180,

  [int]$FinalGateTimeoutSeconds = 180,

  [switch]$SkipInitialNextActionCard,

  [switch]$PreflightOnly,

  [switch]$Compact,

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

function Invoke-ChildPowerShellCapture {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,

    [string[]]$Arguments = @(),

    [Parameter(Mandatory = $true)]
    [string]$Label,

    [switch]$SuppressChildOutput
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

  $rawOutput = & $powershellExe @fullArgs 2>&1
  $exitCode = $LASTEXITCODE
  $lines = @($rawOutput | ForEach-Object { $_.ToString() })
  if ($SuppressChildOutput) {
    Write-Step ("{0} output suppressed by -Compact; short summary follows." -f $Label)
  } else {
    foreach ($line in $lines) {
      Write-Step $line
    }
  }
  Write-Step ("{0} exit code: {1}" -f $Label, $exitCode)

  return @{
    ExitCode = $exitCode
    Text = ($lines -join "`n")
  }
}

function Get-FirstRegexValue {
  param(
    [string]$Text,
    [string]$Pattern
  )

  $match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if ($match.Success -and $match.Groups.Count -gt 1) {
    return $match.Groups[1].Value.Trim()
  }
  return $null
}

function Write-InitialCardShortSummary {
  param([string]$CardText)

  $result = Get-FirstRegexValue -Text $CardText -Pattern "^Result:\s*(\S+)\s*$"
  $status = Get-FirstRegexValue -Text $CardText -Pattern "^\s*SWTITLESTATUS:\s*(\S+)"
  $verify = Get-FirstRegexValue -Text $CardText -Pattern "^\s*SWTITLEVERIFY:\s*(\S+)"
  $frame = $null
  $title = $null

  $pairMatch = [regex]::Match($CardText, "\b(DR_A[1-4]_Outline)\s*/\s*(DR_titlea_3rd)\b", [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if ($pairMatch.Success) {
    $frame = $pairMatch.Groups[1].Value.Trim()
    $title = $pairMatch.Groups[2].Value.Trim()
  }
  if (-not $frame) {
    $frame = Get-FirstRegexValue -Text $CardText -Pattern "\b(DR_A[1-4]_Outline)\b"
  }
  if (-not $title) {
    $title = Get-FirstRegexValue -Text $CardText -Pattern "\b(DR_titlea_3rd)\b"
  }

  Write-Step ""
  Write-Step "Initial next-action short summary:"
  if ($result) { Write-Step ("  Result: {0}" -f $result) }
  if ($status) { Write-Step ("  Saved-DWG status: {0}" -f $status) }
  if ($verify) { Write-Step ("  Verify status: {0}" -f $verify) }
  if ($frame) { Write-Step ("  GMTITLE paper/frame to choose: {0}" -f $frame) }
  if ($title) { Write-Step ("  GMTITLE title block to choose: {0}" -f $title) }
  Write-Step "  Required options: Frame positioning ON, Object move OFF"
  Write-Step "  CAD command order:"
  Write-Step "    APPLOAD"
  Write-Step ("    {0}" -f (Join-Path $repoRoot "swcad_load.lsp"))
  Write-Step "    SWTITLEVERSION"
  Write-Step "    SWTITLESTATUS"
  Write-Step "    SWTITLECONVERTNEXT"
}

function Assert-ManualSessionConversionReady {
  param([string]$CardText)

  if ($CardText -match "(?m)^Result:\s*(READY_FOR_FIRST_NATIVE_GMTITLE|CREATE_MISSING_NATIVE_GMTITLE_SIZE|RUN_NATIVE_REPLACEMENT|RUN_REMAINING_CONVERSION)\s*$") {
    Write-Step "Initial next-action card is conversion-ready for one visible GMTITLE step."
    return
  }

  Write-Step "Result: MANUAL_SESSION_NOT_CONVERSION_READY"
  Write-Step "Reason: the refreshed next-action card does not ask for a visible GMTITLE conversion step."
  Write-Step "Next: follow the Result and guidance in the card above instead of opening CAD through this session wrapper."
  exit 1
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

function Assert-GstarCADRunningBeforeManualStep {
  param([string]$Context)

  $existing = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
  if ($existing.Count -eq 0) {
    if ($Context -eq "SkipOpenWorkcopy") {
      Write-Step "Result: SKIP_OPEN_NO_GSTARCAD"
      Write-Step "Reason: -SkipOpenWorkcopy was used, but no running GstarCAD process was detected."
      Write-Step "Next: open the work-copy in GstarCAD first, or run this session wrapper without -SkipOpenWorkcopy."
    } else {
      Write-Step "Result: GSTARCAD_CLOSED_BEFORE_MANUAL_STEP"
      Write-Step "Reason: the visible open helper returned, but no running GstarCAD process was detected before the manual step."
      Write-Step "Next: open the work-copy manually and run run_after_manual_gmtitle_step.ps1 after saving and closing, or rerun this wrapper."
    }
    exit 1
  }

  Write-Step ("Observed GstarCAD process before manual step: {0}" -f (($existing | ForEach-Object { $_.Id }) -join ", "))
}

Write-Step "===== GMTITLE manual visible-CAD session ====="
Write-Step ("Repo root: {0}" -f $repoRoot)
Write-Step ("Source work copy: {0}" -f $SourceWorkCopyPath)
Write-Step "Purpose: open the work-copy, let the user run one visible GMTITLE step, then wait for GstarCAD to close and refresh the next action card."
Write-Step "Safety: this script does not run SWTITLECONVERTNEXT, does not click the GMTITLE dialog, and does not save the DWG."
Write-Step "Preflight: unless skipped, this script refreshes the next-action card before opening visible CAD and stops if the saved DWG is not conversion-ready."
Write-Step "PreflightOnly: use -PreflightOnly to print the current conversion-ready card and short GMTITLE selection summary without opening CAD."
Write-Step "Compact: use -Compact to hide the long initial next-action card and show only the short summary."
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
  Write-Step "1. Unless -SkipInitialNextActionCard is used, run run_next_cad_action.ps1 -AutoRefreshDirectProbe and require a conversion-ready Result."
  Write-Step "2. If -PreflightOnly is used, stop after the card and short GMTITLE selection summary."
  Write-Step "3. If -Compact is used, suppress the long initial card body and print the short summary only."
  Write-Step "4. Optionally run run_open_workcopy_for_manual_convert.ps1."
  Write-Step "5. Wait for GstarCAD to close."
  Write-Step "6. Run run_after_manual_gmtitle_step.ps1."
  Write-Step "Result: DRY_RUN_READY"
  exit 0
}

if ($PreflightOnly -and ($SkipInitialNextActionCard -or $SkipOpenWorkcopy)) {
  Write-Step "Result: PREFLIGHT_ONLY_REQUIRES_INITIAL_CARD"
  Write-Step "Reason: -PreflightOnly is useful only when the initial next-action card can be refreshed."
  Write-Step "Next: remove -SkipInitialNextActionCard and -SkipOpenWorkcopy, or run run_next_cad_action.ps1 directly."
  exit 1
}

if ($SkipInitialNextActionCard) {
  Write-Step "SkipInitialNextActionCard: not refreshing the saved-DWG next-action card before visible CAD."
  Write-Step "Use this only when you already confirmed SWTITLESTATUS in the currently open work-copy."
} elseif ($SkipOpenWorkcopy) {
  Write-Step "Initial next-action card skipped because -SkipOpenWorkcopy means a visible GstarCAD process should already be open."
  Write-Step "Before converting, run SWTITLESTATUS in that visible CAD session and follow its current next action."
} else {
  $cardArgs = @(
    "-SourceWorkCopyPath",
    $SourceWorkCopyPath,
    "-AutoRefreshDirectProbe",
    "-AutoRefreshTimeoutSeconds",
    [string]$AutoRefreshTimeoutSeconds
  )
  $cardResult = Invoke-ChildPowerShellCapture `
    -ScriptPath (Join-Path $PSScriptRoot "run_next_cad_action.ps1") `
    -Arguments $cardArgs `
    -Label "Initial next-action card" `
    -SuppressChildOutput:$Compact

  if ($cardResult.ExitCode -ne 0) {
    Write-Step "Result: INITIAL_NEXT_ACTION_CARD_FAILED"
    Write-Step "Reason: could not refresh the saved-DWG next-action card before opening visible CAD."
    exit $cardResult.ExitCode
  }
  Write-InitialCardShortSummary -CardText $cardResult.Text
  Assert-ManualSessionConversionReady -CardText $cardResult.Text
  if ($PreflightOnly) {
    Write-Step "Result: MANUAL_SESSION_PREFLIGHT_READY"
    Write-Step "Next: rerun this wrapper without -PreflightOnly to open visible CAD, or open the work-copy manually and follow the summary above."
    exit 0
  }
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

  Assert-GstarCADRunningBeforeManualStep -Context "OpenHelper"
} else {
  Write-Step "SkipOpenWorkcopy: assuming GstarCAD is already open or will be opened manually."
  Assert-GstarCADRunningBeforeManualStep -Context "SkipOpenWorkcopy"
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
