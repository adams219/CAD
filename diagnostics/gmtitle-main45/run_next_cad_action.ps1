param(
  [string]$SourceWorkCopyPath,

  [string]$DirectProbeLogPath
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
  $encodings = @(
    [System.Text.Encoding]::GetEncoding(949),
    [System.Text.UTF8Encoding]::new($true, $true),
    [System.Text.Encoding]::Unicode
  )

  foreach ($encoding in $encodings) {
    try {
      return $encoding.GetString($bytes)
    } catch {
    }
  }

  return [System.Text.Encoding]::Default.GetString($bytes)
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

Write-Output "===== GMTITLE 다음 CAD 작업 카드 ====="
Write-Output ("저장소 폴더: {0}" -f $repoRoot)
Write-Output ("대상 작업복사본: {0}" -f $SourceWorkCopyPath)

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  Write-Output "Result: BLOCKED_WORKCOPY_MISSING"
  Write-Output "다음: Documents/CAD tool/work 아래에 작업복사본 DWG를 만들거나 복구하세요."
  exit 1
}

if (-not (Test-Path -LiteralPath $DirectProbeLogPath)) {
  Write-Output "실제 작업복사본 direct probe: 없음"
  Write-Output "Result: REFRESH_DIRECT_PROBE_FIRST"
  Write-Output "다음:"
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $PSScriptRoot "run_actual_workcopy_direct_status_probe.ps1"))
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

Write-Output ("Direct probe 로그: {0}" -f $DirectProbeLogPath)
Write-Output ("Direct probe 시간: {0}" -f $probeItem.LastWriteTime)
if ($probeDwg) { Write-Output ("Direct probe DWG: {0}" -f $probeDwg) }
Write-Output ("Direct probe 신뢰 가능: {0}" -f ($(if ($trusted) { "예" } else { "아니오" })))
if ($statusAfterStatus) { Write-Output ("현재 저장 상태: {0}" -f $statusAfterStatus) }
if ($statusAfterVerify) { Write-Output ("검증 상태: {0}" -f $statusAfterVerify) }
if ($targetTitleCount) { Write-Output ("대상 제목블록 수: {0}" -f $targetTitleCount) }
if ($targetFrameCount) { Write-Output ("대상 도면틀 수: {0}" -f $targetFrameCount) }
if ($dbmodAfter) { Write-Output ("Direct probe 뒤 DBMOD: {0}" -f $dbmodAfter) }

if (-not $trusted) {
  Write-Output "Result: REFRESH_DIRECT_PROBE_FIRST"
  Write-Output "이유: direct probe 로그가 대상 작업복사본의 로그가 아닙니다."
  Write-Output "다음:"
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $PSScriptRoot "run_actual_workcopy_direct_status_probe.ps1"))
  exit 0
}

if ($dbmodAfter -and $dbmodAfter -ne "0") {
  Write-Output "Result: REVIEW_DIRECT_PROBE_DBMOD"
  Write-Output "이유: 읽기 전용 direct probe 뒤 DBMOD가 0으로 끝나지 않았습니다."
  Write-Output "다음: 저장된 작업복사본 상태가 깨끗한지 확인하기 전에는 CAD 변환을 계속하지 마세요."
  exit 0
}

Write-Output ""
if ($statusAfterStatus -eq "NEXT_CREATE_FIRST_NATIVE_GMTITLE") {
  Write-Output "Result: READY_FOR_FIRST_NATIVE_GMTITLE"
  Write-Output "수동 GstarCAD 단계:"
  Write-Output "  APPLOAD"
  Write-Output ("  {0}" -f (Join-Path $repoRoot "swcad_load.lsp"))
  Write-Output "  SWTITLEVERSION"
  Write-Output "  SWTITLECONVERT"
  Write-Output "  참고: 현재 PC에서는 Codex Computer Use가 GstarCAD 화면 캡처는 가능하지만 활성화/클릭/입력은 안정적이지 않습니다."
  Write-Output ""
  Write-Output "GMTITLE 창에서 반드시 아래 값으로 선택:"
  Write-Output ("  용지/도면틀: {0}" -f ($(if ($nextFrame) { $nextFrame } else { "DR_A2_Outline" })))
  Write-Output ("  제목블록: {0}" -f ($(if ($nextTitle) { $nextTitle } else { "DR_titlea_3rd" })))
  Write-Output "  Frame positioning: ON"
  Write-Output "  Object move: OFF"
  Write-Output ""
  Write-Output "즉시 중단해야 하는 경우:"
  Write-Output "  - 현재 열린 DWG가 대상 작업복사본이 아님"
  Write-Output "  - GMTITLE 창에 ISO 용지/제목블록 기본값이 보임"
  Write-Output "  - Object move가 ON임"
  Write-Output "  - GstarCAD가 왼쪽 아래 배치점을 받지 않고 객체/새 위치를 물어봄"
  Write-Output ""
  Write-Output "변환 후:"
  Write-Output "  SWTITLESTATUS"
  Write-Output "  작업복사본을 저장하고 GstarCAD를 닫은 뒤 direct probe를 갱신하세요."
} elseif ($statusAfterStatus -eq "SWTITLEVERIFY_FINAL_OK") {
  Write-Output "Result: READY_FOR_DOUBLE_CLICK_CHECK"
  Write-Output "다음: 대표 A2/A3/A4 DR_titlea_3rd 제목블록을 더블클릭해서 GMTITLE 표 편집창이 열리는지 확인하세요."
} else {
  Write-Output "Result: FOLLOW_SWTITLESTATUS"
  Write-Output "수동 GstarCAD 단계:"
  Write-Output "  SWTITLESTATUS"
  Write-Output "그 다음 이 명령이 안내하는 4단계 흐름만 따라가세요."
}
