param(
  [string]$SourceWorkCopyPath,

  [string]$DirectProbeLogPath,

  [string]$LogPath,

  [int]$AutoRefreshTimeoutSeconds = 180,

  [int]$FinalGateTimeoutSeconds = 180,

  [switch]$WaitForGstarCADClose,

  [int]$WaitForGstarCADCloseTimeoutSeconds = 600,

  [switch]$RunFinalCompletionGate,

  [switch]$SkipFinalCompletionGate,

  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $DirectProbeLogPath) {
  $DirectProbeLogPath = Join-Path $workDir "swtitle_actual_workcopy_direct_status_260705.txt"
}
if (-not $LogPath) {
  $LogPath = Join-Path $workDir "swtitle_after_manual_gmtitle_step_last.txt"
}
if ($RunFinalCompletionGate -and $SkipFinalCompletionGate) {
  throw "Use either -RunFinalCompletionGate or -SkipFinalCompletionGate, not both."
}

$script:logLines = New-Object System.Collections.Generic.List[string]

function Write-Log {
  param([AllowEmptyString()][string]$Message)

  [Console]::Out.WriteLine($Message)
  [void]$script:logLines.Add($Message)
}

function Save-Log {
  $logDir = Split-Path -Parent $LogPath
  if ($logDir -and (-not (Test-Path -LiteralPath $logDir))) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
  }
  [System.IO.File]::WriteAllLines($LogPath, $script:logLines, [System.Text.Encoding]::UTF8)
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
  if (-not (Test-Path -LiteralPath $powershellExe)) {
    throw "PowerShell executable not found: $powershellExe"
  }
  if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Child script not found: $ScriptPath"
  }

  $fullArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $ScriptPath
  ) + $Arguments

  Write-Log ""
  Write-Log ("----- {0} -----" -f $Label)
  Write-Log ("Command: {0}" -f (Get-QuotedCommandPreview -Parts (@($powershellExe) + $fullArgs)))

  $rawOutput = & $powershellExe @fullArgs 2>&1
  $exitCode = $LASTEXITCODE
  $lines = @($rawOutput | ForEach-Object { $_.ToString() })

  foreach ($line in $lines) {
    Write-Log $line
  }
  Write-Log ("{0} exit code: {1}" -f $Label, $exitCode)

  if (($exitCode -ne 0) -and (-not $AllowFailure)) {
    Write-Log ("Result: {0}_FAILED" -f ($Label -replace "[^A-Za-z0-9]+", "_").Trim("_").ToUpperInvariant())
    Save-Log
    exit $exitCode
  }

  return @{
    ExitCode = $exitCode
    Text = ($lines -join "`n")
  }
}

function Assert-GstarCADClosed {
  param(
    [switch]$Wait,

    [int]$TimeoutSeconds = 600
  )

  if ($Wait) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
      $existing = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
      if ($existing.Count -eq 0) {
        Write-Log "No running GstarCAD process detected. Continuing."
        return
      }
      Write-Log ("Waiting for GstarCAD to close... active PID(s): {0}" -f (($existing | ForEach-Object { $_.Id }) -join ", "))
      Start-Sleep -Seconds 5
    }
  }

  $existingGstarCAD = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
  if ($existingGstarCAD.Count -gt 0) {
    Write-Log "Result: CLOSE_GSTARCAD_FIRST"
    Write-Log "Reason: this check launches hidden GstarCAD probes, so a visible GstarCAD session can make the saved DWG state unreliable."
    Write-Log "Next: save the work-copy DWG, close GstarCAD, then rerun this command."
    Write-Log "Alternative: rerun this command with -WaitForGstarCADClose, then save and close GstarCAD."
    $details = $existingGstarCAD |
      Select-Object Id, ProcessName, MainWindowTitle, StartTime |
      Format-Table -AutoSize |
      Out-String
    foreach ($line in ($details -split "\r?\n")) {
      if ($line.Trim()) {
        Write-Log ("  {0}" -f $line)
      }
    }
    Save-Log
    exit 1
  }

  Write-Log "No running GstarCAD process detected. Continuing."
}

function Test-CardSuggestsFinalGate {
  param([string]$Text)

  return (
    $Text -match "(?m)^Result:\s*RUN_FINAL_VERIFY\s*$" -or
    $Text -match "(?m)^Result:\s*READY_FOR_DOUBLE_CLICK_CHECK\s*$" -or
    $Text -match "(?m)^.+:\s*SWTITLEVERIFY_FINAL_OK\s*$"
  )
}

Write-Log "===== GMTITLE after-manual-step check ====="
Write-Log ("Repo root: {0}" -f $repoRoot)
Write-Log ("Source work copy: {0}" -f $SourceWorkCopyPath)
Write-Log ("Direct probe log: {0}" -f $DirectProbeLogPath)
Write-Log ("After-manual log: {0}" -f $LogPath)
Write-Log ("Direct probe timeout seconds: {0}" -f $AutoRefreshTimeoutSeconds)
Write-Log ("Final completion gate timeout seconds: {0}" -f $FinalGateTimeoutSeconds)
Write-Log "Purpose: after one visible GMTITLE step is saved and GstarCAD is closed, refresh the direct probe and print the next CAD action card."
Write-Log "Safety: this wrapper does not edit the DWG."

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  Write-Log "Result: BLOCKED_WORKCOPY_MISSING"
  Write-Log ("Work-copy DWG not found: {0}" -f $SourceWorkCopyPath)
  Save-Log
  exit 1
}

if ($DryRun) {
  Write-Log "Dry run: hidden GstarCAD probes are not launched."
  Write-Log "1. Confirm GstarCAD is closed."
  Write-Log "2. Run run_next_cad_action.ps1 -AutoRefreshDirectProbe."
  Write-Log "3. If the card indicates final verification, run run_final_completion_gate.ps1."
  Write-Log "Result: DRY_RUN_READY"
  Save-Log
  exit 0
}

Assert-GstarCADClosed -Wait:$WaitForGstarCADClose -TimeoutSeconds $WaitForGstarCADCloseTimeoutSeconds

$nextArgs = @(
  "-SourceWorkCopyPath",
  $SourceWorkCopyPath,
  "-DirectProbeLogPath",
  $DirectProbeLogPath,
  "-AutoRefreshDirectProbe",
  "-AutoRefreshTimeoutSeconds",
  [string]$AutoRefreshTimeoutSeconds
)

$cardResult = Invoke-ChildPowerShell `
  -ScriptPath (Join-Path $PSScriptRoot "run_next_cad_action.ps1") `
  -Arguments $nextArgs `
  -Label "Next CAD action card with direct-probe refresh"

$shouldRunFinalGate = $RunFinalCompletionGate -or ((-not $SkipFinalCompletionGate) -and (Test-CardSuggestsFinalGate -Text $cardResult.Text))

if ($shouldRunFinalGate) {
  Write-Log ""
  Write-Log "The refreshed card indicates final verification may be ready, or -RunFinalCompletionGate was specified."
  $gateArgs = @(
    "-SourceWorkCopyPath",
    $SourceWorkCopyPath,
    "-TimeoutSeconds",
    [string]$FinalGateTimeoutSeconds
  )
  if ($WaitForGstarCADClose) {
    $gateArgs += @("-WaitForGstarCADClose", "-WaitForGstarCADCloseTimeoutSeconds", [string]$WaitForGstarCADCloseTimeoutSeconds)
  }

  $gateResult = Invoke-ChildPowerShell `
    -ScriptPath (Join-Path $PSScriptRoot "run_final_completion_gate.ps1") `
    -Arguments $gateArgs `
    -Label "Final completion gate" `
    -AllowFailure

  if ($gateResult.ExitCode -eq 0) {
    Write-Log "Result: AFTER_MANUAL_STEP_FINAL_GATE_PASSED"
    Write-Log "Next: manually double-click representative A2/A3 DR_titlea_3rd title blocks and confirm the GMTITLE table editor opens."
  } else {
    Write-Log "Result: AFTER_MANUAL_STEP_FINAL_GATE_NOT_PASSED"
    Write-Log "Meaning: automated completion evidence is still missing. Continue from the final gate summary and next CAD action card above."
  }
} else {
  Write-Log "Result: AFTER_MANUAL_STEP_NEXT_ACTION_READY"
  Write-Log "Meaning: the Result and guidance in the next CAD action card above are the next CAD steps. Do not repeat SWTITLECONVERTNEXT blindly."
}

Save-Log
Write-Output ("Saved after-manual GMTITLE step log: {0}" -f $LogPath)
