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

  [switch]$AutoRefreshDirectProbe,

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
  if ($SuppressChildOutput) {
    Write-Step "긴 PowerShell 실행 명령줄은 -Compact 때문에 숨겼습니다."
  } else {
    Write-Step ("Command: {0}" -f (Get-QuotedCommandPreview -Parts (@($powershellExe) + $fullArgs)))
  }

  $rawOutput = & $powershellExe @fullArgs 2>&1
  $exitCode = $LASTEXITCODE
  $lines = @($rawOutput | ForEach-Object { $_.ToString() })
  if ($SuppressChildOutput) {
    Write-Step ("{0} 출력은 -Compact 때문에 숨겼습니다. 아래 짧은 요약만 확인하세요." -f $Label)
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

function Write-InitialCardShortSummary {
  param([string]$CardText)

  $result = Get-LastRegexValue -Text $CardText -Pattern "^Result:\s*(\S+)\s*$"
  $status = Get-LastRegexValue -Text $CardText -Pattern "^(?:\s*SWTITLESTATUS:|현재 저장 상태:)\s*(\S+)"
  $verify = Get-LastRegexValue -Text $CardText -Pattern "^(?:\s*SWTITLEVERIFY:|검증 상태:)\s*(\S+)"
  $frame = $null
  $title = $null

  $frame = Get-LastRegexValue -Text $CardText -Pattern "^\s*(?:용지/도면틀|다음 GMTITLE 용지/도면틀|GMTITLE에서 고를 용지/도면틀):\s*(DR_A[1-4]_Outline)\b"
  $title = Get-LastRegexValue -Text $CardText -Pattern "^\s*(?:제목블록|다음 GMTITLE 제목블록|GMTITLE에서 고를 제목블록):\s*(DR_titlea_3rd)\b"

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

  Write-Step ""
  Write-Step "처음 실행할 다음 작업 짧은 요약:"
  if ($result) { Write-Step ("  결과 코드: {0}" -f $result) }
  if ($status) { Write-Step ("  저장된 DWG 상태: {0}" -f $status) }
  if ($verify) { Write-Step ("  검증 상태: {0}" -f $verify) }
  if ($frame) { Write-Step ("  GMTITLE에서 고를 용지/도면틀: {0}" -f $frame) }
  if ($title) { Write-Step ("  GMTITLE에서 고를 제목블록: {0}" -f $title) }
  Write-Step "  필수 옵션: Frame positioning ON, Object move OFF"
  Write-Step "  CAD 명령 순서:"
  Write-Step "    APPLOAD"
  Write-Step ("    {0}" -f (Join-Path $repoRoot "swcad_load.lsp"))
  Write-Step "    SWTITLEVERSION"
  Write-Step "    SWTITLESTATUS"
  Write-Step "    SWTITLECONVERTNEXT"
  Write-Step "  GMTITLE 창: 위 용지/제목블록/옵션만 확인하세요."
  Write-Step "  금지: GMTITLE, TIT, 일반 OPEN을 직접 입력하지 마세요."
  Write-Step "  금지: 긴 명령/경로를 자동 입력하거나 붙여넣지 마세요. CAD가 `_pasteclip` 삽입으로 해석할 수 있습니다."
  Write-Step "  배치점: 긴 좌표를 직접 치지 말고 자동 입력을 기다리세요."
  Write-Step "  처리 후: 작업복사본을 저장하고 GstarCAD를 닫으세요."
}

function Assert-ManualSessionConversionReady {
  param([string]$CardText)

  if ($CardText -match "(?m)^Result:\s*(READY_FOR_FIRST_NATIVE_GMTITLE|CREATE_MISSING_NATIVE_GMTITLE_SIZE|RUN_NATIVE_REPLACEMENT|RUN_REMAINING_CONVERSION|RELOAD_LSP_AND_CONFIRM_STATUS)\s*$") {
    Write-Step "처음 다음 작업 카드는 visible CAD에서 GMTITLE 한 장을 처리할 준비가 된 상태입니다."
    if ($CardText -match "(?m)^Result:\s*RELOAD_LSP_AND_CONFIRM_STATUS\s*$") {
      Write-Step "참고: direct probe 버전은 오래됐습니다. CAD 안에서 APPLOAD와 SWTITLESTATUS를 먼저 실행해 같은 상태인지 확인한 뒤 SWTITLECONVERTNEXT를 진행하세요."
    }
    return
  }

  Write-Step "Result: MANUAL_SESSION_NOT_CONVERSION_READY"
  Write-Step "이유: 갱신된 다음 작업 카드가 visible CAD 변환 1단계를 요구하지 않습니다."
  Write-Step "다음: 이 세션 래퍼로 CAD를 열지 말고, 위 카드의 Result와 안내를 따르세요."
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
      Write-Step "이유: -SkipOpenWorkcopy를 사용했지만 실행 중인 GstarCAD를 찾지 못했습니다."
      Write-Step "다음: 먼저 GstarCAD에서 작업복사본을 열거나, -SkipOpenWorkcopy 없이 이 래퍼를 다시 실행하세요."
    } else {
      Write-Step "Result: GSTARCAD_CLOSED_BEFORE_MANUAL_STEP"
      Write-Step "이유: visible open helper가 끝났지만 수동 단계 전에 실행 중인 GstarCAD를 찾지 못했습니다."
      Write-Step "다음: 작업복사본을 직접 열고 저장/닫기 뒤 run_after_manual_gmtitle_step.ps1를 실행하거나, 이 래퍼를 다시 실행하세요."
    }
    exit 1
  }

  Write-Step ("수동 단계 전에 확인된 GstarCAD 프로세스: {0}" -f (($existing | ForEach-Object { $_.Id }) -join ", "))
}

if ($Compact) {
  Write-Step "===== GMTITLE 짧은 수동 선택 카드 ====="
  Write-Step ("대상 작업복사본: {0}" -f $SourceWorkCopyPath)
  Write-Step "안전: 이 화면은 CAD를 클릭하지 않고 저장된 DWG 상태만 갱신해 다음 한 장의 선택값을 보여줍니다."
} else {
  Write-Step "===== GMTITLE 수동 visible-CAD 세션 ====="
  Write-Step ("저장소 루트: {0}" -f $repoRoot)
  Write-Step ("대상 작업복사본: {0}" -f $SourceWorkCopyPath)
  Write-Step "목적: 작업복사본을 열고 사용자가 GMTITLE 한 장만 처리한 뒤, GstarCAD가 닫히면 다음 작업 카드를 다시 갱신합니다."
  Write-Step "안전: 이 스크립트는 SWTITLECONVERTNEXT를 대신 실행하지 않고, GMTITLE 창을 클릭하지 않고, DWG를 저장하지 않습니다."
  Write-Step "입력 주의: 긴 명령/경로를 자동 입력하거나 붙여넣으면 CAD가 `_pasteclip` 삽입 명령으로 해석할 수 있으므로 CAD 명령은 사용자가 직접 입력합니다."
  Write-Step "금지: Codex가 Computer Use로 SWTITLECONVERTNEXT를 대신 타이핑하지 않습니다. CAD 동적 입력이 도면 문자 삽입으로 해석될 수 있으므로 사용자가 명령줄에 직접 입력합니다."
  Write-Step "사전확인: 건너뛰지 않으면 visible CAD를 열기 전에 다음 작업 카드를 갱신하고, 저장된 DWG가 변환 가능한 상태가 아니면 멈춥니다."
  Write-Step "기본값: 현재 PC의 /b probe가 불안정할 수 있어 자동 direct probe 갱신은 하지 않습니다. 필요할 때만 -AutoRefreshDirectProbe를 붙입니다."
  Write-Step "PreflightOnly: -PreflightOnly를 붙이면 CAD를 열지 않고 현재 변환 카드와 짧은 GMTITLE 선택 요약만 출력합니다."
  Write-Step "Compact: -Compact를 붙이면 긴 다음 작업 카드 본문은 숨기고 짧은 요약만 보여줍니다."
  Write-Step "CAD에서 입력할 명령:"
  Write-Step "  APPLOAD"
  Write-Step ("  {0}" -f (Join-Path $repoRoot "swcad_load.lsp"))
  Write-Step "  SWTITLEVERSION"
  Write-Step "  SWTITLESTATUS"
  Write-Step "  SWTITLECONVERTNEXT"
  Write-Step "GMTITLE 한 장을 끝낸 뒤: 작업복사본 DWG를 저장하고 GstarCAD를 닫으세요. 그 다음 이 스크립트가 후속 점검을 실행합니다."
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  Write-Step "Result: BLOCKED_WORKCOPY_MISSING"
  Write-Step ("작업복사본 DWG를 찾지 못했습니다: {0}" -f $SourceWorkCopyPath)
  exit 1
}

if ($DryRun) {
  Write-Step "Dry run: visible GstarCAD를 실행하지 않고 hidden probe도 실행하지 않습니다."
  Write-Step "1. -SkipInitialNextActionCard를 쓰지 않았다면 run_next_cad_action.ps1로 변환 가능 Result를 확인합니다."
  Write-Step "   hidden direct probe 갱신까지 원할 때만 이 래퍼에 -AutoRefreshDirectProbe를 붙입니다."
  Write-Step "2. -PreflightOnly를 쓰면 카드와 짧은 GMTITLE 선택 요약만 보고 멈춥니다."
  Write-Step "3. -Compact를 쓰면 긴 초기 카드 본문을 숨기고 짧은 요약만 출력합니다."
  Write-Step "4. 필요하면 run_open_workcopy_for_manual_convert.ps1를 실행합니다."
  Write-Step "5. GstarCAD가 닫힐 때까지 기다립니다."
  Write-Step "6. run_after_manual_gmtitle_step.ps1를 실행합니다."
  Write-Step "Result: DRY_RUN_READY"
  exit 0
}

if ($PreflightOnly -and ($SkipInitialNextActionCard -or $SkipOpenWorkcopy)) {
  Write-Step "Result: PREFLIGHT_ONLY_REQUIRES_INITIAL_CARD"
  Write-Step "이유: -PreflightOnly는 초기 다음 작업 카드를 갱신할 수 있을 때만 의미가 있습니다."
  Write-Step "다음: -SkipInitialNextActionCard와 -SkipOpenWorkcopy를 빼거나, run_next_cad_action.ps1를 직접 실행하세요."
  exit 1
}

if ($SkipInitialNextActionCard) {
  Write-Step "SkipInitialNextActionCard: visible CAD 전에 저장된 DWG의 다음 작업 카드를 갱신하지 않습니다."
  Write-Step "현재 열린 작업복사본에서 SWTITLESTATUS를 이미 확인했을 때만 사용하세요."
} elseif ($SkipOpenWorkcopy) {
  Write-Step "-SkipOpenWorkcopy는 visible GstarCAD가 이미 열려 있다는 뜻이므로 초기 다음 작업 카드를 건너뜁니다."
  Write-Step "변환 전에 그 CAD 세션에서 SWTITLESTATUS를 실행하고 현재 다음 작업만 따르세요."
} else {
  $cardArgs = @(
    "-SourceWorkCopyPath",
    $SourceWorkCopyPath
  )
  if ($AutoRefreshDirectProbe) {
    $cardArgs += @(
      "-AutoRefreshDirectProbe",
      "-AutoRefreshTimeoutSeconds",
      [string]$AutoRefreshTimeoutSeconds
    )
  }
  $cardResult = Invoke-ChildPowerShellCapture `
    -ScriptPath (Join-Path $PSScriptRoot "run_next_cad_action.ps1") `
    -Arguments $cardArgs `
    -Label "초기 다음 작업 카드" `
    -SuppressChildOutput:$Compact

  if ($cardResult.ExitCode -ne 0) {
    Write-Step "Result: INITIAL_NEXT_ACTION_CARD_FAILED"
    Write-Step "이유: visible CAD를 열기 전에 저장된 DWG의 다음 작업 카드를 갱신하지 못했습니다."
    exit $cardResult.ExitCode
  }
  Write-InitialCardShortSummary -CardText $cardResult.Text
  Assert-ManualSessionConversionReady -CardText $cardResult.Text
  if ($PreflightOnly) {
    Write-Step "Result: MANUAL_SESSION_PREFLIGHT_READY"
    Write-Step "다음: visible CAD를 열려면 -PreflightOnly 없이 이 래퍼를 다시 실행하거나, 작업복사본을 직접 열고 위 요약을 따르세요."
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
    -Label "수동 변환용 작업복사본 열기" `
    -AllowFailure

  if ($openExitCode -ne 0) {
    Write-Step "Visible open helper가 정상 완료되지 않았습니다."
    Write-Step "작업복사본을 직접 열었다면 CAD가 열린 뒤 -SkipOpenWorkcopy로 이 스크립트를 다시 실행하세요. 아니면 CAD를 닫고 run_after_manual_gmtitle_step.ps1를 사용하세요."
    exit $openExitCode
  }

  Assert-GstarCADRunningBeforeManualStep -Context "OpenHelper"
} else {
  Write-Step "SkipOpenWorkcopy: GstarCAD가 이미 열려 있거나 직접 열 예정이라고 보고 진행합니다."
  Assert-GstarCADRunningBeforeManualStep -Context "SkipOpenWorkcopy"
}

Write-Step ""
Write-Step "이제 GstarCAD에서 GMTITLE 한 장만 처리하고, DWG를 저장한 뒤 GstarCAD를 닫으세요."
Write-Step "이 스크립트는 기다렸다가 direct-probe 증거를 갱신합니다."

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
if ($Compact) {
  $afterArgs += "-Compact"
}

Invoke-ChildPowerShell `
  -ScriptPath (Join-Path $PSScriptRoot "run_after_manual_gmtitle_step.ps1") `
  -Arguments $afterArgs `
  -Label "수동 GMTITLE 한 장 처리 후 점검"

Write-Step "Result: MANUAL_GMTITLE_SESSION_COMPLETE"
