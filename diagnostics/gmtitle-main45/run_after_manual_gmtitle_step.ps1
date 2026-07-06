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
  throw "-RunFinalCompletionGate와 -SkipFinalCompletionGate는 동시에 사용할 수 없습니다."
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
    throw "PowerShell 실행 파일을 찾지 못했습니다: $powershellExe"
  }
  if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "하위 스크립트를 찾지 못했습니다: $ScriptPath"
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

function Get-LastRegexValue {
  param(
    [string]$Text,
    [string]$Pattern
  )

  $matches = [regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  for ($i = $matches.Count - 1; $i -ge 0; $i--) {
    $match = $matches[$i]
    if ($match.Success -and $match.Groups.Count -gt 1) {
      $value = $match.Groups[1].Value.Trim()
      if (-not [string]::IsNullOrWhiteSpace($value)) {
        return $value
      }
    }
  }
  return $null
}

function Write-AfterManualCardShortSummary {
  param([string]$CardText)

  $result = Get-LastRegexValue -Text $CardText -Pattern "^Result:\s*(\S+)\s*$"
  $status = Get-LastRegexValue -Text $CardText -Pattern "^(?:\s*SWTITLESTATUS:|현재 저장 상태:)\s*(\S+)"
  $verify = Get-LastRegexValue -Text $CardText -Pattern "^(?:\s*SWTITLEVERIFY:|검증 상태:)\s*(\S+)"
  $frame = $null
  $title = $null

  $frame = Get-LastRegexValue -Text $CardText -Pattern "^\s*(?:용지/도면틀|다음 GMTITLE 용지/도면틀):\s*(DR_A[1-4]_Outline)\b"
  $title = Get-LastRegexValue -Text $CardText -Pattern "^\s*(?:제목블록|다음 GMTITLE 제목블록):\s*(DR_titlea_3rd)\b"

  if ((-not $frame) -or (-not $title)) {
    $pairMatches = [regex]::Matches($CardText, "\b(DR_A[1-4]_Outline)\s*/\s*(DR_titlea_3rd)\b", [System.Text.RegularExpressions.RegexOptions]::Multiline)
    for ($i = $pairMatches.Count - 1; $i -ge 0; $i--) {
      $pairMatch = $pairMatches[$i]
      if ($pairMatch.Success) {
        if (-not $frame) { $frame = $pairMatch.Groups[1].Value.Trim() }
        if (-not $title) { $title = $pairMatch.Groups[2].Value.Trim() }
        break
      }
    }
  }
  if (-not $frame) {
    $frame = Get-LastRegexValue -Text $CardText -Pattern "\b(DR_A[1-4]_Outline)\b"
  }
  if (-not $title) {
    $title = Get-LastRegexValue -Text $CardText -Pattern "\b(DR_titlea_3rd)\b"
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
    Write-Log "  다음 CAD 명령: SWTITLEVERIFY, 그 뒤 DR_titlea_3rd가 있는 대표 A2/A3/A4 제목블록 더블클릭 확인"
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
        Write-Log "실행 중인 GstarCAD가 없습니다. 계속 진행합니다."
        return
      }
      Write-Log ("GstarCAD가 닫히기를 기다리는 중입니다... 실행 중인 PID: {0}" -f (($existing | ForEach-Object { $_.Id }) -join ", "))
      Start-Sleep -Seconds 5
    }
  }

  $existingGstarCAD = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
  if ($existingGstarCAD.Count -gt 0) {
    Write-Log "Result: CLOSE_GSTARCAD_FIRST"
    Write-Log "이유: 이 점검은 hidden GstarCAD probe를 실행하므로, visible GstarCAD가 열려 있으면 저장된 DWG 상태와 엇갈릴 수 있습니다."
    Write-Log "다음: 작업복사본 DWG를 저장하고 GstarCAD를 닫은 뒤 이 명령을 다시 실행하세요."
    Write-Log "대안: -WaitForGstarCADClose를 붙여 다시 실행한 뒤, GstarCAD를 저장하고 닫으세요."
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

  Write-Log "실행 중인 GstarCAD가 없습니다. 계속 진행합니다."
}

function Test-CardSuggestsFinalGate {
  param([string]$Text)

  return (
    $Text -match "(?m)^Result:\s*RUN_FINAL_VERIFY\s*$" -or
    $Text -match "(?m)^Result:\s*READY_FOR_DOUBLE_CLICK_CHECK\s*$" -or
    $Text -match "(?m)^.+:\s*SWTITLEVERIFY_FINAL_OK\s*$"
  )
}

Write-Log "===== GMTITLE 수동 한 장 처리 후 점검 ====="
Write-Log ("저장소 루트: {0}" -f $repoRoot)
Write-Log ("대상 작업복사본: {0}" -f $SourceWorkCopyPath)
Write-Log ("direct probe 로그: {0}" -f $DirectProbeLogPath)
Write-Log ("후속 점검 로그: {0}" -f $LogPath)
Write-Log ("direct probe 제한 시간(초): {0}" -f $AutoRefreshTimeoutSeconds)
Write-Log ("final completion gate 제한 시간(초): {0}" -f $FinalGateTimeoutSeconds)
Write-Log "목적: visible CAD에서 GMTITLE 한 장을 처리하고 저장/닫은 뒤, direct probe를 갱신하고 다음 CAD 작업을 안내합니다."
Write-Log "안전: 이 래퍼는 DWG를 편집하지 않습니다."
if ($Compact) {
  Write-Log "Compact: 긴 하위 출력은 로그 파일에 저장하고, 화면에는 다음 작업 짧은 요약만 보여줍니다."
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  Write-Log "Result: BLOCKED_WORKCOPY_MISSING"
  Write-Log ("작업복사본 DWG를 찾지 못했습니다: {0}" -f $SourceWorkCopyPath)
  Save-Log
  exit 1
}

if ($DryRun) {
  Write-Log "Dry run: hidden GstarCAD probe를 실행하지 않습니다."
  Write-Log "1. GstarCAD가 닫혀 있는지 확인합니다."
  Write-Log "2. run_next_cad_action.ps1 -AutoRefreshDirectProbe를 실행합니다."
  Write-Log "3. 카드가 최종 검증 가능 상태를 가리키면 run_final_completion_gate.ps1를 실행합니다."
  Write-Log "4. -Compact를 쓰면 긴 하위 카드는 화면에서 숨기고 다음 작업 짧은 요약만 출력합니다."
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
  Write-Log "갱신된 카드가 최종 검증 가능 상태를 가리키거나 -RunFinalCompletionGate가 지정되었습니다."
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
    Write-Log "다음: DR_titlea_3rd가 있는 대표 A2/A3/A4 제목블록을 직접 더블클릭해서 GMTITLE 표 편집창이 열리는지 확인하세요."
  } else {
    Write-Log "Result: AFTER_MANUAL_STEP_FINAL_GATE_NOT_PASSED"
    Write-Log "의미: 자동 완료 증거가 아직 부족합니다. 위 final gate 요약과 다음 CAD 작업 카드를 기준으로 계속 진행하세요."
  }
} else {
  Write-Log "Result: AFTER_MANUAL_STEP_NEXT_ACTION_READY"
  Write-Log "의미: 위 짧은 요약의 결과 코드와 안내가 다음 CAD 단계입니다. SWTITLECONVERTNEXT를 무작정 반복하지 마세요."
}

Save-Log
Write-Output ("수동 GMTITLE 후속 점검 로그 저장: {0}" -f $LogPath)
