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

  [switch]$Compact,

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

function Write-LogOnly {
  param([AllowEmptyString()][string]$Message)

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

    [switch]$SuppressChildOutput,

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
  if ($SuppressChildOutput) {
    Write-Log "긴 PowerShell 실행 명령줄은 -Compact 때문에 화면에서 숨겼습니다. 전체 내용은 로그 파일에 저장합니다."
    Write-LogOnly ("Command: {0}" -f (Get-QuotedCommandPreview -Parts (@($powershellExe) + $fullArgs)))
  } else {
    Write-Log ("Command: {0}" -f (Get-QuotedCommandPreview -Parts (@($powershellExe) + $fullArgs)))
  }

  $rawOutput = & $powershellExe @fullArgs 2>&1
  $exitCode = $LASTEXITCODE
  $lines = @($rawOutput | ForEach-Object { $_.ToString() })

  if ($SuppressChildOutput) {
    foreach ($line in $lines) {
      Write-LogOnly $line
    }
    Write-Log ("{0} 출력은 -Compact 때문에 화면에서 숨겼습니다. 아래 짧은 요약만 확인하세요." -f $Label)
  } else {
    foreach ($line in $lines) {
      Write-Log $line
    }
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

function Write-AfterManualCardShortSummary {
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

  Write-Log ""
  Write-Log "수동 GMTITLE 처리 후 다음 작업 짧은 요약:"
  if ($result) { Write-Log ("  결과 코드: {0}" -f $result) }
  if ($status) { Write-Log ("  저장된 DWG 상태: {0}" -f $status) }
  if ($verify) { Write-Log ("  검증 상태: {0}" -f $verify) }
  if ($frame) { Write-Log ("  다음 GMTITLE 용지/도면틀: {0}" -f $frame) }
  if ($title) { Write-Log ("  다음 GMTITLE 제목블록: {0}" -f $title) }

  if ($result -match "READY_FOR_FIRST_NATIVE_GMTITLE|CREATE_MISSING_NATIVE_GMTITLE_SIZE|RUN_NATIVE_REPLACEMENT|RUN_REMAINING_CONVERSION") {
    Write-Log "  다음 CAD 명령: SWTITLESTATUS -> SWTITLECONVERTNEXT"
    Write-Log "  필수 옵션: Frame positioning ON, Object move OFF"
  } elseif ($result -match "RUN_PREPARE_FIRST") {
    Write-Log "  다음 CAD 명령: SWTITLEPREPARE -> SWTITLESTATUS"
  } elseif ($result -match "RUN_FINAL_VERIFY|READY_FOR_DOUBLE_CLICK_CHECK") {
    Write-Log "  다음 CAD 명령: SWTITLEVERIFY, 그 뒤 대표 A2/A3 제목블록 더블클릭 확인"
  } elseif ($result -match "VERIFY_NOT_FINAL|REVIEW_") {
    Write-Log "  다음 CAD 명령: SWTITLESTATUS 또는 SWTITLEVERIFY 로그 확인"
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
if ($Compact) {
  Write-Log "Compact: long child output is kept in the log file, while the screen shows the next short action summary."
}

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
  Write-Log "4. Use -Compact to hide the long child card on screen and print the next short action summary."
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
  -Label "Next CAD action card with direct-probe refresh" `
  -SuppressChildOutput:$Compact

if ($Compact) {
  Write-AfterManualCardShortSummary -CardText $cardResult.Text
}

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
