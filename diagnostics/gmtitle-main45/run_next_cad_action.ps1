param(
  [string]$SourceWorkCopyPath,

  [string]$DirectProbeLogPath,

  [switch]$AutoRefreshDirectProbe,

  [int]$AutoRefreshTimeoutSeconds = 90
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

function Read-TextWithFallback {
  param([string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    return ([System.Text.UTF8Encoding]::new($true, $true).GetString($bytes)).TrimStart([char]0xFEFF)
  }
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
    return ([System.Text.Encoding]::Unicode.GetString($bytes)).TrimStart([char]0xFEFF)
  }
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
    return ([System.Text.Encoding]::BigEndianUnicode.GetString($bytes)).TrimStart([char]0xFEFF)
  }

  $encodings = @(
    [System.Text.Encoding]::GetEncoding(949),
    [System.Text.UTF8Encoding]::new($true, $true),
    [System.Text.Encoding]::Unicode
  )

  foreach ($encoding in $encodings) {
    try {
      return ($encoding.GetString($bytes)).TrimStart([char]0xFEFF)
    } catch {
    }
  }

  return ([System.Text.Encoding]::Default.GetString($bytes)).TrimStart([char]0xFEFF)
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

function Test-SamePath {
  param(
    [string]$Left,
    [string]$Right
  )

  if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
    return $false
  }
  try {
    return [System.IO.Path]::GetFullPath($Left).Equals(
      [System.IO.Path]::GetFullPath($Right),
      [System.StringComparison]::OrdinalIgnoreCase
    )
  } catch {
    return $false
  }
}

function Write-ManualLoadStep {
  Write-Output "수동 GstarCAD 단계:"
  Write-Output "  APPLOAD"
  Write-Output ("  {0}" -f (Join-Path $repoRoot "swcad_load.lsp"))
  Write-Output "  SWTITLEVERSION"
}

function Write-GmtitleDialogGuidance {
  param(
    [string]$FrameName,
    [string]$TitleName
  )

  Write-Output ""
  Write-Output "GMTITLE 창에서 반드시 아래 값으로 선택:"
  Write-Output ("  용지/도면틀: {0}" -f ($(if ($FrameName) { $FrameName } else { "SWTITLESTATUS가 출력한 DR_A*_Outline" })))
  Write-Output ("  제목블록: {0}" -f ($(if ($TitleName) { $TitleName } else { "DR_titlea_3rd" })))
  Write-Output "  Frame positioning: ON"
  Write-Output "  Object move: OFF"
}

function Write-GmtitleAbortGuards {
  Write-Output ""
  Write-Output "즉시 중단해야 하는 경우:"
  Write-Output "  - 현재 열린 DWG가 대상 작업복사본이 아님"
  Write-Output "  - GMTITLE 창에 ISO 용지/제목블록 기본값이 보임"
  Write-Output "  - Object move가 ON임"
  Write-Output "  - GstarCAD가 왼쪽 아래 배치점을 받지 않고 객체/새 위치를 물어봄"
}

function Write-ConvertPromptGuidance {
  param([string]$Mode)

  Write-Output ""
  Write-Output "SWTITLECONVERT 안에서 나올 수 있는 입력:"
  switch ($Mode) {
    "FirstNative" {
      Write-Output "  YES: 첫 native GMTITLE 1장을 만들고 마무리합니다."
      Write-Output "  Enter: 아무 것도 만들지 않고 중단합니다."
      Write-Output "  첫 GMTITLE 창은 위 DR 용지/DR_titlea_3rd/옵션을 확인한 뒤 한 번만 완료하세요."
    }
    "MissingNative" {
      Write-Output "  YES: 누락된 용지 크기의 첫 native GMTITLE 1장을 만듭니다."
      Write-Output "  Enter: 해당 크기 생성 없이 중단합니다."
      Write-Output "  같은 크기 기준 객체가 준비된 뒤에야 나머지 시트를 빠르게 처리할 수 있습니다."
    }
    "NativeReplacement" {
      Write-Output "  OPEN: 다음 A3/A4 후보 1장만 fresh native GMTITLE로 교체합니다."
      Write-Output "  BATCH: 같은 선택값을 눈으로 확인할 수 있을 때 여러 장을 이어서 처리합니다."
      Write-Output "  MANUAL: OPEN이 새 GMTITLE을 못 잡거나 NO_INSERTS가 반복될 때만 사용합니다."
      Write-Output "  Enter: 기존 쌍을 보존하고 중단합니다."
    }
    "RemainingConversion" {
      Write-Output "  YES: 준비된 native 기준 객체로 남은 원본 시트를 변환합니다."
      Write-Output "  Enter: 변환 없이 중단합니다."
      Write-Output "  A4 frame-only 단계에서 원본에 없던 제목블록이 생기면 즉시 멈추고 SWTITLESTATUS를 확인하세요."
    }
  }
}

function Write-AfterStatusRefresh {
  Write-Output ""
  Write-Output "변환/정리 후:"
  Write-Output "  SWTITLESTATUS"
  Write-Output "  작업복사본을 저장하고 GstarCAD를 닫은 뒤 direct probe를 갱신하세요."
  Write-Output "  또는 이 카드를 -AutoRefreshDirectProbe 옵션으로 다시 실행하세요."
}

function Write-FinalDoubleClickGuidance {
  Write-Output "최종 수동 확인:"
  Write-Output "  - 실제 DR_titlea_3rd 제목블록이 있는 대표 A2/A3 용지만 더블클릭하세요."
  Write-Output "  - 표제란 없는 A4 frame-only 시트는 더블클릭할 제목블록이 없으므로 DR_A4_Outline 수량/형상을 SWTITLEVERIFY로 확인하세요."
  Write-Output "  - DR_A*_Outline 도면틀을 더블클릭하면 GMPOWEREDIT/REFEDIT가 열릴 수 있으니 완료 판단 대상이 아닙니다."
}

function Write-DirectProbeRefreshCommand {
  Write-Output "다음:"
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $PSScriptRoot "run_actual_workcopy_direct_status_probe.ps1"))
  Write-Output "또는:"
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -AutoRefreshDirectProbe" -f $PSCommandPath)
}

function Invoke-DirectProbeRefresh {
  if (-not $AutoRefreshDirectProbe) {
    return $false
  }

  Write-Output ""
  Write-Output "Direct probe 자동 갱신을 시작합니다."
  Write-Output "주의: GstarCAD가 열려 있으면 hidden probe가 중단될 수 있습니다. 저장 후 GstarCAD를 닫은 상태에서 사용하세요."
  try {
    & (Join-Path $PSScriptRoot "run_actual_workcopy_direct_status_probe.ps1") `
      -SourceWorkCopyPath $SourceWorkCopyPath `
      -LogPath $DirectProbeLogPath `
      -TimeoutSeconds $AutoRefreshTimeoutSeconds | Write-Output
  } catch {
    Write-Output "Result: AUTO_REFRESH_DIRECT_PROBE_FAILED"
    Write-Output ("이유: {0}" -f $_.Exception.Message)
    exit 1
  }
  return $true
}

function Write-StatusBasedAction {
  param(
    [string]$StatusCode,
    [string]$VerifyCode,
    [string]$FrameName,
    [string]$TitleName
  )

  if ([string]::IsNullOrWhiteSpace($StatusCode)) {
    Write-Output "Result: REFRESH_STATUS_FIRST"
    Write-ManualLoadStep
    Write-Output "  SWTITLESTATUS"
    Write-Output "이유: direct probe 로그에서 현재 상태 코드를 읽지 못했습니다."
    return
  }

  switch -Regex ($StatusCode) {
    "^NEXT_CREATE_FIRST_NATIVE_GMTITLE$" {
      Write-Output "Result: READY_FOR_FIRST_NATIVE_GMTITLE"
      Write-ManualLoadStep
      Write-Output "  SWTITLECONVERT"
      Write-Output "  참고: 현재 PC에서는 Codex Computer Use가 GstarCAD 화면 캡처는 가능하지만 활성화/클릭/입력은 안정적이지 않습니다."
      Write-GmtitleDialogGuidance -FrameName ($(if ($FrameName) { $FrameName } else { "DR_A2_Outline" })) -TitleName ($(if ($TitleName) { $TitleName } else { "DR_titlea_3rd" }))
      Write-ConvertPromptGuidance -Mode "FirstNative"
      Write-GmtitleAbortGuards
      Write-AfterStatusRefresh
      return
    }

    "^NEXT_CREATE_MISSING_NATIVE_EXEMPLAR$" {
      Write-Output "Result: CREATE_MISSING_NATIVE_GMTITLE_SIZE"
      Write-ManualLoadStep
      Write-Output "  SWTITLECONVERT"
      Write-Output "의미: 남은 용지 크기와 같은 native GMTITLE 기준 객체가 없어, 그 크기 1장을 먼저 실제 GMTITLE로 만들어야 합니다."
      Write-GmtitleDialogGuidance -FrameName $FrameName -TitleName ($(if ($TitleName) { $TitleName } else { "DR_titlea_3rd" }))
      Write-ConvertPromptGuidance -Mode "MissingNative"
      Write-GmtitleAbortGuards
      Write-AfterStatusRefresh
      return
    }

    "^NEXT_UPGRADE_A3_A4_NATIVE$" {
      Write-Output "Result: RUN_NATIVE_REPLACEMENT"
      Write-ManualLoadStep
      Write-Output "  SWTITLECONVERT"
      Write-Output "의미: A3/A4 복제 또는 shared-link 쌍을 실제 native GMTITLE 쌍으로 한 장씩 교체해야 합니다."
      Write-GmtitleDialogGuidance -FrameName "SWTITLESTATUS가 출력한 DR_A3_Outline 또는 DR_A4_Outline" -TitleName "DR_titlea_3rd"
      Write-ConvertPromptGuidance -Mode "NativeReplacement"
      Write-GmtitleAbortGuards
      Write-AfterStatusRefresh
      return
    }

    "^NEXT_(RUN_FAST_BATCH|TRANSFER_REMAINING_SOURCE_SHEETS|CREATE_MISSING_TARGET_SHEET)$" {
      Write-Output "Result: RUN_REMAINING_CONVERSION"
      Write-ManualLoadStep
      Write-Output "  SWTITLECONVERT"
      Write-Output "의미: 남은 SolidWorks 원본 시트 또는 부족한 GMTITLE 대상 시트를 변환해야 합니다."
      Write-GmtitleDialogGuidance -FrameName $FrameName -TitleName ($(if ($TitleName) { $TitleName } else { "DR_titlea_3rd" }))
      Write-ConvertPromptGuidance -Mode "RemainingConversion"
      Write-GmtitleAbortGuards
      Write-AfterStatusRefresh
      return
    }

    "^NEXT_PREPARE_(A4_FRAME_ONLY_OUTLINE_DEFINITION|FRAME_STYLE_NORMALIZATION)$" {
      Write-Output "Result: RUN_PREPARE_FIRST"
      Write-ManualLoadStep
      Write-Output "  SWTITLEPREPARE"
      Write-Output "  SWTITLESTATUS"
      Write-Output "의미: 변환 전에 도면틀 정의나 A4 frame-only 준비/검증이 먼저 필요합니다."
      Write-Output "주의: 같은 NEXT_PREPARE 상태가 그대로 반복되면 SWTITLECONVERT를 누르지 말고 로그 원인을 확인하세요."
      return
    }

    "^NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT$" {
      Write-Output "Result: REVIEW_COMMAND_TEXT_FIRST"
      Write-ManualLoadStep
      Write-Output "  SWTITLEPREPARE"
      Write-Output "  SWTITLESTATUS"
      Write-Output "의미: 도면 안에 실수로 들어간 명령어 텍스트 후보가 있습니다. 후보가 맞을 때만 정리하고 변환을 계속하세요."
      return
    }

    "^NEXT_REVIEW_(FRAME_DEFINITION_RAW_BBOX|TARGET_FRAME_GEOMETRY|TARGET_FRAME_SELECTION|TARGET_SHEET_COUNT_SHORTAGE)$" {
      Write-Output "Result: REVIEW_STRUCTURE_BEFORE_CONVERT"
      Write-ManualLoadStep
      Write-Output "  SWTITLEVERIFY"
      Write-Output "  SWTITLESTATUS"
      Write-Output "의미: 도면틀 범위/크기/수량 위험이 있어 같은 변환 명령을 반복하면 원본이 지워질 수 있습니다."
      Write-Output "다음: verify/status 로그의 DWG 경로가 실제 작업복사본인지 확인하고, 위험 원인을 먼저 분석하세요."
      return
    }

    "^NEXT_OPEN_WRITABLE_WORK_COPY$" {
      Write-Output "Result: OPEN_WORK_COPY_FIRST"
      Write-Output "다음: Downloads 원본이 아니라 Documents/CAD tool/work 안의 쓰기 가능한 작업복사본 DWG를 열고 SWTITLESTATUS를 다시 실행하세요."
      return
    }

    "^NEXT_FINAL_VERIFY_AND_DOUBLE_CLICK$" {
      Write-Output "Result: RUN_FINAL_VERIFY"
      Write-ManualLoadStep
      Write-Output "  SWTITLEVERIFY"
      Write-Output "검증이 SWTITLEVERIFY_FINAL_OK이면 아래 기준으로 더블클릭을 확인하세요."
      Write-FinalDoubleClickGuidance
      return
    }

    "^SWTITLEVERIFY_FINAL_OK$" {
      Write-Output "Result: READY_FOR_DOUBLE_CLICK_CHECK"
      Write-Output "다음: 대표 제목블록을 더블클릭해서 GMTITLE 표 편집창이 열리는지 확인하세요."
      Write-FinalDoubleClickGuidance
      return
    }

    "^SWTITLEVERIFY_FINAL_(FAIL|WARN)$" {
      Write-Output "Result: VERIFY_NOT_FINAL"
      Write-ManualLoadStep
      Write-Output "  SWTITLESTATUS"
      Write-Output "의미: 최종 검증이 아직 완료가 아니므로 상태 진단으로 다음 조치를 다시 확인하세요."
      return
    }

    "^(ABORT|WARN)_" {
      Write-Output "Result: REVIEW_ABORT_OR_WARNING"
      Write-ManualLoadStep
      Write-Output "  SWTITLESTATUS"
      Write-Output "  SWTITLEVERIFY"
      Write-Output "의미: 보호 중단 또는 경고 상태입니다. 같은 SWTITLECONVERT를 반복하지 말고 로그 원인을 먼저 확인하세요."
      return
    }

    default {
      Write-Output "Result: FOLLOW_SWTITLESTATUS"
      Write-ManualLoadStep
      Write-Output "  SWTITLESTATUS"
      if ($VerifyCode -and $VerifyCode -ne $StatusCode) {
        Write-Output ("참고: 마지막 검증 상태는 {0} 입니다." -f $VerifyCode)
      }
      Write-Output "그 다음 이 명령이 안내하는 4단계 흐름만 따라가세요."
      return
    }
  }
}

Write-Output "===== GMTITLE 다음 CAD 작업 카드 ====="
Write-Output ("저장소 폴더: {0}" -f $repoRoot)
Write-Output ("대상 작업복사본: {0}" -f $SourceWorkCopyPath)

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  Write-Output "Result: BLOCKED_WORKCOPY_MISSING"
  Write-Output "다음: Documents/CAD tool/work 아래에 작업복사본 DWG를 만들거나 복구하세요."
  exit 1
}
$sourceItem = Get-Item -LiteralPath $SourceWorkCopyPath

$refreshAttempted = $false
while ($true) {
  if (-not (Test-Path -LiteralPath $DirectProbeLogPath)) {
    Write-Output "실제 작업복사본 direct probe: 없음"
    if ($AutoRefreshDirectProbe -and (-not $refreshAttempted)) {
      $refreshAttempted = $true
      [void](Invoke-DirectProbeRefresh)
      continue
    }
    Write-Output "Result: REFRESH_DIRECT_PROBE_FIRST"
    Write-DirectProbeRefreshCommand
    exit 0
  }

  $probeItem = Get-Item -LiteralPath $DirectProbeLogPath
  $probeText = Read-TextWithFallback -Path $DirectProbeLogPath
  $probeDwg = Get-FirstRegexValue -Text $probeText -Pattern "^DWG[^:]*:\s*(.+)$"
  $statusAfterStatus = Get-FirstRegexValue -Text $probeText -Pattern "^\s*status-after-status:\s*(\S+)"
  $statusAfterVerify = Get-FirstRegexValue -Text $probeText -Pattern "^\s*status-after-verify:\s*(\S+)"
  $nextFrame = Get-FirstRegexValue -Text $probeText -Pattern "^\s*next-bootstrap-frame:\s*(\S+)"
  $nextTitle = Get-FirstRegexValue -Text $probeText -Pattern "^\s*next-bootstrap-title:\s*(\S+)"
  $dbmodAfter = Get-FirstRegexValue -Text $probeText -Pattern "^\s*dbmod-after-commands:\s*(\d+)"
  $targetTitleCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*target-title-count:\s*(\d+)"
  $targetFrameCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*target-frame-count:\s*(\d+)"
  $trusted = Test-SamePath -Left $probeDwg -Right $SourceWorkCopyPath
  $probeStale = $sourceItem.LastWriteTimeUtc -gt $probeItem.LastWriteTimeUtc.AddSeconds(2)

  Write-Output ("Direct probe 로그: {0}" -f $DirectProbeLogPath)
  Write-Output ("Direct probe 시간: {0}" -f $probeItem.LastWriteTime)
  Write-Output ("작업복사본 저장 시간: {0}" -f $sourceItem.LastWriteTime)
  if ($probeDwg) { Write-Output ("Direct probe DWG: {0}" -f $probeDwg) }
  Write-Output ("Direct probe 신뢰 가능: {0}" -f ($(if ($trusted) { "예" } else { "아니오" })))
  Write-Output ("Direct probe 최신 상태: {0}" -f ($(if ($probeStale) { "아니오" } else { "예" })))
  if ($statusAfterStatus) { Write-Output ("현재 저장 상태: {0}" -f $statusAfterStatus) }
  if ($statusAfterVerify) { Write-Output ("검증 상태: {0}" -f $statusAfterVerify) }
  if ($targetTitleCount) { Write-Output ("대상 제목블록 수: {0}" -f $targetTitleCount) }
  if ($targetFrameCount) { Write-Output ("대상 도면틀 수: {0}" -f $targetFrameCount) }
  if ($dbmodAfter) { Write-Output ("Direct probe 뒤 DBMOD: {0}" -f $dbmodAfter) }

  if (-not $trusted) {
    if ($AutoRefreshDirectProbe -and (-not $refreshAttempted)) {
      $refreshAttempted = $true
      [void](Invoke-DirectProbeRefresh)
      continue
    }
    Write-Output "Result: REFRESH_DIRECT_PROBE_FIRST"
    Write-Output "이유: direct probe 로그가 대상 작업복사본의 로그가 아닙니다."
    Write-DirectProbeRefreshCommand
    exit 0
  }

  if ($probeStale) {
    if ($AutoRefreshDirectProbe -and (-not $refreshAttempted)) {
      $refreshAttempted = $true
      [void](Invoke-DirectProbeRefresh)
      continue
    }
    Write-Output "Result: REFRESH_DIRECT_PROBE_FIRST"
    Write-Output "이유: 작업복사본이 direct probe 로그보다 최신입니다."
    Write-DirectProbeRefreshCommand
    exit 0
  }

  break
}

if ($dbmodAfter -and $dbmodAfter -ne "0") {
  Write-Output "Result: REVIEW_DIRECT_PROBE_DBMOD"
  Write-Output "이유: 읽기 전용 direct probe 뒤 DBMOD가 0으로 끝나지 않았습니다."
  Write-Output "다음: 저장된 작업복사본 상태가 깨끗한지 확인하기 전에는 CAD 변환을 계속하지 마세요."
  exit 0
}

Write-Output ""
Write-StatusBasedAction -StatusCode $statusAfterStatus -VerifyCode $statusAfterVerify -FrameName $nextFrame -TitleName $nextTitle
