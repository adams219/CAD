param(
  [string]$SourceWorkCopyPath,

  [string]$DirectProbeLogPath,

  [switch]$AutoRefreshDirectProbe,

  [int]$AutoRefreshTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$displayRepoRoot = $repoRoot
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

function Get-AllRegexValues {
  param(
    [string]$Text,
    [string]$Pattern
  )

  $values = New-Object System.Collections.Generic.List[string]
  foreach ($match in [regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
    if ($match.Groups.Count -gt 1) {
      [void]$values.Add($match.Groups[1].Value.Trim())
    }
  }
  return @($values)
}

function Get-GitHeadCommitTimeUtc {
  param([string]$RepoRoot)

  try {
    $value = (& git -C $RepoRoot show -s --format=%cI HEAD 2>$null | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($value)) {
      return $null
    }
    return ([datetimeoffset]::Parse($value.Trim())).UtcDateTime
  } catch {
    return $null
  }
}

function Get-CountFromProbeSection {
  param(
    [string]$Text,
    [string]$SectionLabel,
    [string]$Key
  )

  $inSection = $false
  foreach ($line in ($Text -split "\r?\n")) {
    $trimmed = $line.Trim()
    if (-not $inSection) {
      if ($trimmed -eq $SectionLabel) {
        $inSection = $true
      }
      continue
    }

    if ($trimmed -eq "" -or $trimmed -eq "<none>") {
      continue
    }
    if ($trimmed -match "^([A-Za-z0-9_-]+):\s*(\d+)$") {
      if ($Matches[1] -eq $Key) {
        return $Matches[2]
      }
      continue
    }
    if ($trimmed -match ":") {
      break
    }
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

function Test-CodexSandboxPath {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $false
  }
  return $Path -like "*\CodexSandboxOffline\.codex\.sandbox\cwd\*"
}

function Get-RepoRootFromWorkCopyPath {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $null
  }

  try {
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $workFolder = [System.IO.DirectoryInfo]::new([System.IO.Path]::GetDirectoryName($fullPath))
    if (-not $workFolder -or -not $workFolder.Parent) {
      return $null
    }
    if (-not $workFolder.Name.Equals("work", [System.StringComparison]::OrdinalIgnoreCase)) {
      return $null
    }

    $candidate = $workFolder.Parent.FullName
    if (Test-Path -LiteralPath (Join-Path $candidate "swcad_load.lsp")) {
      return $candidate
    }
  } catch {
  }

  return $null
}

function Update-DisplayRepoRootFromWorkCopyPath {
  param([string]$Path)

  $derivedRoot = Get-RepoRootFromWorkCopyPath -Path $Path
  if ($derivedRoot) {
    $script:displayRepoRoot = $derivedRoot
    return $true
  }
  return $false
}

function Get-DisplayDiagnosticScriptPath {
  param([string]$ScriptName)

  $displayScriptPath = Join-Path (Join-Path $displayRepoRoot "diagnostics\gmtitle-main45") $ScriptName
  if (Test-Path -LiteralPath $displayScriptPath) {
    return $displayScriptPath
  }
  return (Join-Path $PSScriptRoot $ScriptName)
}

function Get-ExpectedGmtitleVersion {
  $sourcePath = Join-Path $displayRepoRoot "src\tools\gmtitle\swcad_title_scale.lsp"
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    return $null
  }

  $text = Get-Content -LiteralPath $sourcePath -Raw
  $match = [regex]::Match($text, '\(setq\s+\*swcad-title-scale-version\*\s+"([^"]+)"\)')
  if ($match.Success) {
    return $match.Groups[1].Value
  }
  return $null
}

function Write-SuiteLastRunSummary {
  $suiteLog = Join-Path (Join-Path $displayRepoRoot "work") "main56_verification_suite_last_run.txt"
  Write-Output ""
  Write-Output "최근 hidden suite 요약:"
  if (-not (Test-Path -LiteralPath $suiteLog)) {
    Write-Output "  상태: 없음"
    Write-Output "  참고: 실제 CAD 변환 전에도 static preflight와 SWTITLESTATUS를 먼저 확인하세요."
    return
  }

  $suiteText = Read-TextWithFallback -Path $suiteLog
  $generated = Get-FirstRegexValue -Text $suiteText -Pattern "^Generated:\s*(.+)$"
  $resultValues = @(Get-AllRegexValues -Text $suiteText -Pattern "^Result:\s*(.+)$")
  $result = if ($resultValues.Count -gt 0) { $resultValues[$resultValues.Count - 1] } else { "<unknown>" }
  $failure = Get-FirstRegexValue -Text $suiteText -Pattern "^Failure:\s*(.+)$"
  $failureCommand = Get-FirstRegexValue -Text $suiteText -Pattern "^Failure command:\s*(.+)$"
  $item = Get-Item -LiteralPath $suiteLog
  $headCommitTimeUtc = Get-GitHeadCommitTimeUtc -RepoRoot $displayRepoRoot

  Write-Output ("  로그: {0}" -f $suiteLog)
  if ($generated) { Write-Output ("  생성: {0}" -f $generated) }
  if ($headCommitTimeUtc) {
    $suiteOlderThanHead = $item.LastWriteTimeUtc -lt $headCommitTimeUtc.AddSeconds(-2)
    Write-Output ("  현재 커밋 시간: {0}" -f $headCommitTimeUtc.ToString("yyyy-MM-dd HH:mm:ss 'UTC'"))
    Write-Output ("  suite 로그가 현재 커밋보다 오래됨: {0}" -f ($(if ($suiteOlderThanHead) { "예" } else { "아니오" })))
  }
  Write-Output ("  결과: {0}" -f $result)
  if ($failure) { Write-Output ("  실패 원인: {0}" -f $failure) }
  if ($failureCommand) { Write-Output ("  실패 명령: {0}" -f $failureCommand) }
  if ($result -eq "PASS") {
    if ($headCommitTimeUtc -and ($item.LastWriteTimeUtc -lt $headCommitTimeUtc.AddSeconds(-2))) {
      Write-Output "  의미: 이 PASS는 현재 커밋보다 오래된 기록입니다. /b smoke가 통과하고 suite를 다시 돌리기 전까지는 과거 guard 증거로만 봅니다."
    } else {
      Write-Output "  의미: 자동화/guard 검증은 통과했습니다. 실제 work DWG 변환 완료 증거는 별도로 필요합니다."
    }
  } elseif ($result -eq "FAILED_BEFORE_PASS") {
    Write-Output "  의미: suite가 최종 PASS 전에 멈췄습니다. 위 실패 원인을 먼저 확인하세요."
  } else {
    Write-Output "  의미: suite가 완료되지 않았거나 최신 PASS 증거가 아닙니다."
  }
}

function Write-FinalCompletionGateSummary {
  $gateLog = Join-Path (Join-Path $displayRepoRoot "work") "swtitle_final_completion_gate_status.txt"
  Write-Output ""
  Write-Output "최근 final completion gate 요약:"
  if (-not (Test-Path -LiteralPath $gateLog)) {
    Write-Output "  상태: 없음"
    Write-Output "  참고: 실제 work DWG 완료 여부는 SWTITLEVERIFY_FINAL_OK와 대표 더블클릭 확인 전까지 증명되지 않습니다."
    return
  }

  $item = Get-Item -LiteralPath $gateLog
  $text = Read-TextWithFallback -Path $gateLog
  $loadedVersion = Get-FirstRegexValue -Text $text -Pattern "^Loaded version:\s*(.+)$"
  $statusAfterStatus = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-status:\s*(\S+)"
  $statusAfterVerify = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-verify:\s*(\S+)"
  $sourceTitleCount = Get-FirstRegexValue -Text $text -Pattern "^\s*source-title-count:\s*(\d+)"
  $sourceFrameCount = Get-FirstRegexValue -Text $text -Pattern "^\s*source-frame-count:\s*(\d+)"
  $frameOnlyCount = Get-FirstRegexValue -Text $text -Pattern "^\s*frame-only-count:\s*(\d+)"
  $targetTitleCount = Get-FirstRegexValue -Text $text -Pattern "^\s*target-title-count:\s*(\d+)"
  $targetFrameCount = Get-FirstRegexValue -Text $text -Pattern "^\s*target-frame-count:\s*(\d+)"
  $nextFrame = Get-FirstRegexValue -Text $text -Pattern "^\s*next-bootstrap-frame:\s*(\S+)"
  $nextTitle = Get-FirstRegexValue -Text $text -Pattern "^\s*next-bootstrap-title:\s*(\S+)"
  $dbmodAfter = Get-FirstRegexValue -Text $text -Pattern "^\s*dbmod-after-commands:\s*(\d+)"
  $runtimeDone = Get-FirstRegexValue -Text $text -Pattern "^Runtime check completed:\s*(\S+)"
  $gateResult = if ($statusAfterVerify -eq "SWTITLEVERIFY_FINAL_OK") { "PASS" } elseif ($statusAfterVerify) { "FAIL" } else { "UNKNOWN" }
  $script:FinalCompletionGateStatusAfterStatus = $statusAfterStatus
  $script:FinalCompletionGateStatusAfterVerify = $statusAfterVerify
  $script:FinalCompletionGateNextFrame = $nextFrame
  $script:FinalCompletionGateNextTitle = $nextTitle
  $script:FinalCompletionGateLastWriteTimeUtc = $item.LastWriteTimeUtc

  Write-Output ("  로그: {0}" -f $gateLog)
  Write-Output ("  LastWriteTime: {0}" -f $item.LastWriteTime)
  if ($loadedVersion) { Write-Output ("  LSP 버전: {0}" -f $loadedVersion) }
  Write-Output ("  결과: {0}" -f $gateResult)
  if ($statusAfterStatus) { Write-Output ("  SWTITLESTATUS: {0}" -f $statusAfterStatus) }
  if ($statusAfterVerify) { Write-Output ("  SWTITLEVERIFY: {0}" -f $statusAfterVerify) }
  if ($sourceTitleCount -or $sourceFrameCount -or $frameOnlyCount) {
    Write-Output ("  남은 원본: 표제란 {0}, 도면틀 {1}, frame-only {2}" -f ($(if ($sourceTitleCount) { $sourceTitleCount } else { "?" })), ($(if ($sourceFrameCount) { $sourceFrameCount } else { "?" })), ($(if ($frameOnlyCount) { $frameOnlyCount } else { "?" })))
  }
  if ($targetTitleCount -or $targetFrameCount) {
    Write-Output ("  대상 GMTITLE: 제목블록 {0}, 도면틀 {1}" -f ($(if ($targetTitleCount) { $targetTitleCount } else { "?" })), ($(if ($targetFrameCount) { $targetFrameCount } else { "?" })))
  }
  if ($nextFrame -or $nextTitle) {
    Write-Output ("  다음 native GMTITLE: {0} / {1}" -f ($(if ($nextFrame) { $nextFrame } else { "?" })), ($(if ($nextTitle) { $nextTitle } else { "?" })))
  }
  if ($dbmodAfter) { Write-Output ("  DBMOD after probe: {0}" -f $dbmodAfter) }
  if ($runtimeDone) { Write-Output ("  Runtime check completed: {0}" -f $runtimeDone) }

  if ($gateResult -eq "PASS") {
    Write-Output "  의미: 자동 완료 게이트는 통과했습니다. 그래도 대표 A2/A3 제목블록 더블클릭 확인은 따로 필요합니다."
  } else {
    Write-Output "  의미: 실제 작업복사본 완료 증거가 아직 없습니다. 아래 다음 CAD 작업을 계속 진행하세요."
  }
}

function Write-ManualLoadStep {
  $expectedVersion = Get-ExpectedGmtitleVersion
  Write-Output "수동 GstarCAD 단계:"
  Write-Output "  CAD가 닫혀 있으면 먼저 아래 helper로 작업복사본을 보이는 GstarCAD로 열 수 있습니다:"
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Get-DisplayDiagnosticScriptPath -ScriptName "run_open_workcopy_for_manual_convert.ps1"))
  Write-Output "  helper는 기본적으로 /b startup script를 쓰지 않으므로 APPLOAD와 상태 확인은 CAD 안에서 직접 실행합니다."
  Write-Output "  APPLOAD"
  Write-Output ("  {0}" -f (Join-Path $displayRepoRoot "swcad_load.lsp"))
  Write-Output "  SWTITLEVERSION"
  if ($expectedVersion) {
    Write-Output ("  정상 버전: {0}" -f $expectedVersion)
  }
  Write-Output "  SWTITLESTATUS  (현재 열린 DWG와 다음 상태 확인)"
}

function Write-ConvertCommandStep {
  Write-Output "  SWTITLECONVERTNEXT  (권장: YES/OPEN 반복 응답 자동 선택)"
  Write-Output "  또는 수동 응답을 직접 고르려면: SWTITLECONVERT"
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
  Write-Output ""
  Write-Output "명령 경로 주의:"
  Write-Output "  - CAD 명령줄에 GMTITLE, TIT, 일반 OPEN을 직접 입력하지 마세요. SWTITLECONVERTNEXT 또는 수동 SWTITLECONVERT 흐름이 GMTITLE 호출, 배치점 자동 전송, 값 복사/정리를 묶어서 처리합니다."
  Write-Output "  - SWTITLECONVERTNEXT는 같은 흐름에서 YES/OPEN 같은 반복 응답만 자동 선택합니다. GMTITLE 창의 DR 용지/제목블록/옵션 확인은 여전히 직접 해야 합니다."
  Write-Output "  - SWTITLECONVERT 안에서 물어보는 YES/OPEN/BATCH/MANUAL 응답과 CAD 일반 OPEN 명령은 다릅니다."
  Write-Output ""
  Write-Output "배치점 안내:"
  Write-Output "  - 긴 좌표를 사람이 직접 치지 마세요. SWTITLECONVERTNEXT 또는 수동 SWTITLECONVERT 흐름이 GMTITLE 창 뒤에 왼쪽 아래 배치점을 자동 전송합니다."
  Write-Output "  - 커서가 화면 중앙에 남아 보여도, 명령줄이 삽입점을 기다리는 상태면 잠시 기다렸다가 자동 입력을 확인하세요."
  Write-Output "  - 자동 입력 후에도 삽입점 입력이 남아 있으면 기존 원본 도면틀의 왼쪽 아래 끝점을 OSNAP으로 찍고, 객체/새 위치 프롬프트가 나오면 취소하세요."
}

function Write-AutomationBoundarySummary {
  param([string]$Mode)

  Write-Output ""
  Write-Output "자동화 경계:"
  Write-Output "  - LSP가 자동 처리: 현재 후보 판별, 왼쪽 아래 배치점 전송, 표제란 값 복사, 이전 SolidWorks 원본 정리, 새 결과 검사/rollback."
  Write-Output "  - 사람이 확인: GMTITLE 창의 DR_A*_Outline 용지, DR_titlea_3rd 제목블록, Frame positioning ON, Object move OFF."
  Write-Output "  - 아직 자동화하지 않는 이유: GstarCAD GMTITLE 창이 일반/ISO 기본값으로 열릴 수 있고, 리본/스크린 좌표 자동화는 안정 증거가 없습니다."
  switch ($Mode) {
    "FirstNative" {
      Write-Output "  - 이번 단계: 첫 native GMTITLE 기준 객체 1장만 사람이 확인하고, 이후 정렬/값 복사/원본 정리는 LSP가 처리합니다."
    }
    "MissingNative" {
      Write-Output "  - 이번 단계: 누락된 용지 크기 1장만 사람이 확인하면, 같은 크기 나머지는 빠른 변환 후보가 됩니다."
    }
    "NativeReplacement" {
      Write-Output "  - 이번 단계: OPEN 1장 성공으로 후보 수 감소를 확인한 뒤에만 BATCH 반복 처리를 검토합니다."
    }
    "RemainingConversion" {
      Write-Output "  - 이번 단계: 이미 검증된 native 기준 객체로 남은 시트를 처리하되, A4 frame-only에는 새 제목블록을 만들지 않습니다."
    }
  }
}

function Write-ManualSelectionForecast {
  param(
    [string]$StatusCode,
    [string]$FrameName,
    [string]$TitleName,
    [string]$ProbeText
  )

  $sourceTitleCount = Get-FirstRegexValue -Text $ProbeText -Pattern "^\s*source-title-count:\s*(\d+)"
  $frameOnlyCount = Get-FirstRegexValue -Text $ProbeText -Pattern "^\s*frame-only-count:\s*(\d+)"
  $expectedA2 = Get-CountFromProbeSection -Text $ProbeText -SectionLabel "expected-sheet-counts:" -Key "A2"
  $expectedA3 = Get-CountFromProbeSection -Text $ProbeText -SectionLabel "expected-sheet-counts:" -Key "A3"
  $expectedA4 = Get-CountFromProbeSection -Text $ProbeText -SectionLabel "expected-sheet-counts:" -Key "A4"
  $missingFrames = @(Get-AllRegexValues -Text $ProbeText -Pattern "^\s*missing-native-frame:\s*(DR_A[0-4]_Outline)")
  $nextMissingFrame = Get-FirstRegexValue -Text $ProbeText -Pattern "^\s*next-missing-native-frame:\s*(\S+)"
  $nextMissingTitle = Get-FirstRegexValue -Text $ProbeText -Pattern "^\s*next-missing-native-title:\s*(\S+)"
  $nextMissingRole = Get-FirstRegexValue -Text $ProbeText -Pattern "^\s*next-missing-native-role:\s*(\S+)"
  $hasA3Missing = $missingFrames -contains "DR_A3_Outline"
  $hasA4Missing = $missingFrames -contains "DR_A4_Outline"
  $targetPairCount = Get-FirstRegexValue -Text $ProbeText -Pattern "^\s*target-gmtitle-pair-count:\s*(\d+)"
  $nativeLikeTargetPairCount = Get-FirstRegexValue -Text $ProbeText -Pattern "^\s*native-like-target-pair-count:\s*(\d+)"
  $nonNativeLikeTargetPairCount = Get-FirstRegexValue -Text $ProbeText -Pattern "^\s*non-native-like-target-pair-count:\s*(\d+)"
  $clonedPairCount = Get-FirstRegexValue -Text $ProbeText -Pattern "^\s*cloned-gmtitle-pair-count:\s*(\d+)"
  $a3a4NativeUpgradeCandidateCount = Get-FirstRegexValue -Text $ProbeText -Pattern "^\s*a3a4-native-upgrade-candidate-count:\s*(\d+)"

  Write-Output ""
  Write-Output "예상 수동 GMTITLE 확인량:"
  if ($expectedA2 -or $expectedA3 -or $expectedA4) {
    Write-Output ("  - 저장된 시트 수량: A2 {0}장, A3 {1}장, A4 {2}장" -f ($(if ($expectedA2) { $expectedA2 } else { "?" })), ($(if ($expectedA3) { $expectedA3 } else { "?" })), ($(if ($expectedA4) { $expectedA4 } else { "?" })))
  }
  switch -Regex ($StatusCode) {
    "^NEXT_CREATE_FIRST_NATIVE_GMTITLE$" {
      Write-Output ("  - 지금 필요한 확인: {0} / {1} 1회" -f ($(if ($FrameName) { $FrameName } else { "DR_A2_Outline" })), ($(if ($TitleName) { $TitleName } else { "DR_titlea_3rd" })))
      if ($hasA3Missing) {
        Write-Output ("  - 이후 예상: A3 {0}장을 처리하기 위한 첫 native 기준 객체 1회가 추가로 필요할 수 있습니다." -f ($(if ($expectedA3) { $expectedA3 } else { "여러" })))
      }
      if (($frameOnlyCount -as [int]) -gt 0 -or $hasA4Missing) {
        Write-Output ("  - A4 frame-only {0}장은 제목블록 생성 대상이 아닙니다. 검증된 DR_A4_Outline 도면틀-only 경로로 처리합니다." -f ($(if ($frameOnlyCount) { $frameOnlyCount } else { "해당" })))
      }
      Write-Output "  - 좌표 입력, 값 복사, 기존 원본 정리는 SWTITLECONVERTNEXT 또는 수동 SWTITLECONVERT 흐름이 자동 처리합니다."
      return
    }
    "^NEXT_CREATE_MISSING_NATIVE_EXEMPLAR$" {
      Write-Output ("  - 지금 필요한 확인: {0} / {1} 1회" -f ($(if ($nextMissingFrame) { $nextMissingFrame } elseif ($FrameName) { $FrameName } else { "SWTITLESTATUS가 요구한 DR 용지" })), ($(if ($nextMissingTitle) { $nextMissingTitle } elseif ($TitleName) { $TitleName } else { "DR_titlea_3rd" })))
      if ($nextMissingRole) {
        Write-Output ("  - 처리 유형: {0}" -f $nextMissingRole)
      }
      Write-Output "  - 이 크기의 기준 객체가 생긴 뒤 같은 크기 나머지는 자동/일괄 처리 후보가 됩니다."
      return
    }
    "^NEXT_UPGRADE_A3_A4_NATIVE$" {
      if ($a3a4NativeUpgradeCandidateCount) {
        Write-Output ("  - 현재 A3/A4 native 교체 후보: {0}개" -f $a3a4NativeUpgradeCandidateCount)
      }
      if ($targetPairCount -or $nativeLikeTargetPairCount -or $nonNativeLikeTargetPairCount) {
        Write-Output ("  - 현재 GMTITLE 쌍: 전체 {0}개, native-like {1}개, 교체 필요 {2}개" -f ($(if ($targetPairCount) { $targetPairCount } else { "?" })), ($(if ($nativeLikeTargetPairCount) { $nativeLikeTargetPairCount } else { "?" })), ($(if ($nonNativeLikeTargetPairCount) { $nonNativeLikeTargetPairCount } else { "?" })))
      }
      if ($clonedPairCount) {
        Write-Output ("  - 복제/공유 링크 후보: {0}개" -f $clonedPairCount)
      }
      Write-Output "  - 지금은 OPEN으로 A3/A4 후보 1장을 먼저 교체해 후보 수가 줄어드는지 확인합니다."
      if (($a3a4NativeUpgradeCandidateCount -as [int]) -gt 1) {
        Write-Output "  - OPEN 1회 성공 뒤 direct probe를 갱신해서 후보 수가 줄었는지 먼저 확인하세요."
      }
      Write-Output "  - BATCH는 OPEN 1회 성공 뒤 같은 DR 용지/제목블록/옵션이 반복된다는 걸 확인했을 때만 사용합니다."
      Write-Output "  - 도면틀이 INSERT처럼 보이는 것 자체는 실패 기준이 아니며, 대표 DR_titlea_3rd 제목블록을 확인합니다."
      return
    }
    "^SWTITLEVERIFY_FINAL_OK$" {
      Write-Output "  - 새 GMTITLE 생성은 끝난 상태입니다."
      Write-Output "  - 대표 A2/A3 DR_titlea_3rd 제목블록 더블클릭 확인만 남았습니다. A4 frame-only는 도면틀 수량/형상으로 확인합니다."
      return
    }
    default {
      if (($sourceTitleCount -as [int]) -gt 0 -or ($frameOnlyCount -as [int]) -gt 0) {
        Write-Output "  - 현재 상태는 먼저 SWTITLESTATUS/SWTITLEPREPARE 안내를 따라야 합니다."
        Write-Output "  - 같은 SWTITLECONVERT를 반복하기 전에 후보 수나 경고가 줄었는지 확인하세요."
      } else {
        Write-Output "  - 현재 상태에서는 추가 GMTITLE 창 선택보다 SWTITLEVERIFY/더블클릭 검증이 우선입니다."
      }
    }
  }
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
  Write-Output "SWTITLECONVERT/SWTITLECONVERTNEXT에서 나올 수 있는 입력:"
  Write-Output "  SWTITLECONVERTNEXT는 아래 반복 응답 중 현재 상태의 안전한 다음 값만 자동 선택합니다."
  Write-Output "  SWTITLECONVERTNEXT를 쓰는 경우 사용자가 YES/OPEN/BATCH/MANUAL을 다시 입력하지 않습니다."
  Write-Output "  아래 항목은 수동 SWTITLECONVERT를 쓸 때의 응답 의미를 이해하기 위한 설명입니다."
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
      Write-Output "  BATCH: OPEN으로 최소 1장 성공한 뒤, 같은 DR 용지/제목블록/옵션이 반복된다는 걸 눈으로 확인할 수 있을 때만 여러 장을 이어서 처리합니다."
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
  Write-Output "  작업복사본을 저장하고 GstarCAD를 닫은 뒤 아래 래퍼를 실행하세요."
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -Compact" -f (Get-DisplayDiagnosticScriptPath -ScriptName "run_after_manual_gmtitle_step.ps1"))
  Write-Output "  이 래퍼가 direct probe를 갱신하고, 화면에는 다음 한 단계 요약만 보여줍니다."
  Write-Output "  GstarCAD를 계속 열어 둔 상태에서는 hidden probe가 현재 화면 상태와 엇갈릴 수 있습니다."
  Write-Output "  직접 갱신하려면 이 카드를 -AutoRefreshDirectProbe 옵션으로 다시 실행해도 됩니다."
}

function Write-FinalDoubleClickGuidance {
  Write-Output "최종 수동 확인:"
  Write-Output "  - 실제 DR_titlea_3rd 제목블록이 있는 대표 A2/A3 용지만 더블클릭하세요."
  Write-Output "  - 표제란 없는 A4 frame-only 시트는 더블클릭할 제목블록이 없으므로 DR_A4_Outline 수량/형상을 SWTITLEVERIFY로 확인하세요."
  Write-Output "  - DR_A*_Outline 도면틀을 더블클릭하면 GMPOWEREDIT/REFEDIT가 열릴 수 있으니 완료 판단 대상이 아닙니다."
}

function Write-DirectProbeRefreshCommand {
  Write-Output "다음:"
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Get-DisplayDiagnosticScriptPath -ScriptName "run_actual_workcopy_direct_status_probe.ps1"))
  Write-Output "또는:"
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -AutoRefreshDirectProbe" -f (Get-DisplayDiagnosticScriptPath -ScriptName "run_next_cad_action.ps1"))
}

function Invoke-DirectProbeRefresh {
  if (-not $AutoRefreshDirectProbe) {
    return $false
  }

  Write-Output ""
  Write-Output "Direct probe 자동 갱신을 시작합니다."
  Write-Output "주의: GstarCAD가 열려 있으면 hidden probe가 중단될 수 있습니다. 저장 후 GstarCAD를 닫은 상태에서 사용하세요."
  Write-Output ("Direct probe 제한 시간: {0}초" -f $AutoRefreshTimeoutSeconds)
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
      Write-ConvertCommandStep
      Write-Output "  참고: 현재 PC에서는 Codex Computer Use가 GstarCAD 화면 캡처는 가능하지만 활성화/클릭/입력은 안정적이지 않습니다."
      Write-AutomationBoundarySummary -Mode "FirstNative"
      Write-GmtitleDialogGuidance -FrameName ($(if ($FrameName) { $FrameName } else { "DR_A2_Outline" })) -TitleName ($(if ($TitleName) { $TitleName } else { "DR_titlea_3rd" }))
      Write-ConvertPromptGuidance -Mode "FirstNative"
      Write-GmtitleAbortGuards
      Write-AfterStatusRefresh
      return
    }

    "^NEXT_CREATE_MISSING_NATIVE_EXEMPLAR$" {
      Write-Output "Result: CREATE_MISSING_NATIVE_GMTITLE_SIZE"
      Write-ManualLoadStep
      Write-ConvertCommandStep
      Write-Output "의미: 남은 용지 크기와 같은 native GMTITLE 기준 객체가 없어, 그 크기 1장을 먼저 실제 GMTITLE로 만들어야 합니다."
      Write-AutomationBoundarySummary -Mode "MissingNative"
      Write-GmtitleDialogGuidance -FrameName $FrameName -TitleName ($(if ($TitleName) { $TitleName } else { "DR_titlea_3rd" }))
      Write-ConvertPromptGuidance -Mode "MissingNative"
      Write-GmtitleAbortGuards
      Write-AfterStatusRefresh
      return
    }

    "^NEXT_UPGRADE_A3_A4_NATIVE$" {
      Write-Output "Result: RUN_NATIVE_REPLACEMENT"
      Write-ManualLoadStep
      Write-ConvertCommandStep
      Write-Output "의미: A3/A4 복제 또는 shared-link 쌍을 실제 native GMTITLE 쌍으로 한 장씩 교체해야 합니다."
      Write-AutomationBoundarySummary -Mode "NativeReplacement"
      Write-GmtitleDialogGuidance -FrameName "SWTITLESTATUS가 출력한 DR_A3_Outline 또는 DR_A4_Outline" -TitleName "DR_titlea_3rd"
      Write-ConvertPromptGuidance -Mode "NativeReplacement"
      Write-GmtitleAbortGuards
      Write-AfterStatusRefresh
      return
    }

    "^NEXT_(RUN_FAST_BATCH|TRANSFER_REMAINING_SOURCE_SHEETS|CREATE_MISSING_TARGET_SHEET)$" {
      Write-Output "Result: RUN_REMAINING_CONVERSION"
      Write-ManualLoadStep
      Write-ConvertCommandStep
      Write-Output "의미: 남은 SolidWorks 원본 시트 또는 부족한 GMTITLE 대상 시트를 변환해야 합니다."
      Write-AutomationBoundarySummary -Mode "RemainingConversion"
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
if (Update-DisplayRepoRootFromWorkCopyPath -Path $SourceWorkCopyPath) {
  $workDir = Join-Path $displayRepoRoot "work"
}
Write-Output ("저장소 폴더: {0}" -f $repoRoot)
if (-not (Test-SamePath -Left $displayRepoRoot -Right $repoRoot)) {
  Write-Output ("실제 CAD용 저장소 폴더: {0}" -f $displayRepoRoot)
}
Write-Output ("대상 작업복사본: {0}" -f $SourceWorkCopyPath)
Write-SuiteLastRunSummary
Write-FinalCompletionGateSummary

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
  $probeLoadedVersion = Get-FirstRegexValue -Text $probeText -Pattern "^Loaded version:\s*(.+)$"
  $probeExpectedVersion = Get-FirstRegexValue -Text $probeText -Pattern "^Expected version:\s*(.+)$"
  $probeDwg = Get-FirstRegexValue -Text $probeText -Pattern "^DWG[^:]*:\s*(.+)$"
  $statusAfterStatus = Get-FirstRegexValue -Text $probeText -Pattern "^\s*status-after-status:\s*(\S+)"
  $statusAfterVerify = Get-FirstRegexValue -Text $probeText -Pattern "^\s*status-after-verify:\s*(\S+)"
  $nextFrame = Get-FirstRegexValue -Text $probeText -Pattern "^\s*next-bootstrap-frame:\s*(\S+)"
  $nextTitle = Get-FirstRegexValue -Text $probeText -Pattern "^\s*next-bootstrap-title:\s*(\S+)"
  $nextMissingFrame = Get-FirstRegexValue -Text $probeText -Pattern "^\s*next-missing-native-frame:\s*(\S+)"
  $nextMissingTitle = Get-FirstRegexValue -Text $probeText -Pattern "^\s*next-missing-native-title:\s*(\S+)"
  $dbmodAfter = Get-FirstRegexValue -Text $probeText -Pattern "^\s*dbmod-after-commands:\s*(\d+)"
  $targetTitleCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*target-title-count:\s*(\d+)"
  $targetFrameCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*target-frame-count:\s*(\d+)"
  $targetPairCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*target-gmtitle-pair-count:\s*(\d+)"
  $nativeLikeTargetPairCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*native-like-target-pair-count:\s*(\d+)"
  $nonNativeLikeTargetPairCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*non-native-like-target-pair-count:\s*(\d+)"
  $clonedPairCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*cloned-gmtitle-pair-count:\s*(\d+)"
  $a3a4NativeUpgradeCandidateCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*a3a4-native-upgrade-candidate-count:\s*(\d+)"
  $orphanTargetFrameCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*orphan-target-frame-count:\s*(\d+)"
  $duplicateTargetPairCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*duplicate-target-pair-count:\s*(\d+)"

  if (
    (Test-CodexSandboxPath -Path $SourceWorkCopyPath) -and
    $probeDwg -and
    (-not (Test-CodexSandboxPath -Path $probeDwg)) -and
    (Test-Path -LiteralPath $probeDwg)
  ) {
    Write-Output ("Codex sandbox 기본 경로 감지: direct probe의 실제 DWG를 대상 작업복사본으로 사용합니다.")
    Write-Output ("  기존 sandbox 대상: {0}" -f $SourceWorkCopyPath)
    Write-Output ("  실제 direct probe DWG: {0}" -f $probeDwg)
    $SourceWorkCopyPath = $probeDwg
    if (Update-DisplayRepoRootFromWorkCopyPath -Path $SourceWorkCopyPath) {
      Write-Output ("  실제 CAD용 저장소 폴더: {0}" -f $displayRepoRoot)
    }
    $sourceItem = Get-Item -LiteralPath $SourceWorkCopyPath
  }

  $currentExpectedVersion = Get-ExpectedGmtitleVersion
  $pathTrusted = Test-SamePath -Left $probeDwg -Right $SourceWorkCopyPath
  $probeVersionMismatch = $false
  if ($currentExpectedVersion) {
    if (-not $probeLoadedVersion) {
      $probeVersionMismatch = $true
    } elseif (-not $probeLoadedVersion.Equals($currentExpectedVersion, [System.StringComparison]::OrdinalIgnoreCase)) {
      $probeVersionMismatch = $true
    }
    if ($probeExpectedVersion -and (-not $probeExpectedVersion.Equals($currentExpectedVersion, [System.StringComparison]::OrdinalIgnoreCase))) {
      $probeVersionMismatch = $true
    }
  }
  $trusted = $pathTrusted -and (-not $probeVersionMismatch)
  $probeFileStale = $sourceItem.LastWriteTimeUtc -gt $probeItem.LastWriteTimeUtc.AddSeconds(2)
  $probeStale = $probeFileStale -or $probeVersionMismatch

  Write-Output ("Direct probe 로그: {0}" -f $DirectProbeLogPath)
  Write-Output ("Direct probe 시간: {0}" -f $probeItem.LastWriteTime)
  Write-Output ("작업복사본 저장 시간: {0}" -f $sourceItem.LastWriteTime)
  if ($probeDwg) { Write-Output ("Direct probe DWG: {0}" -f $probeDwg) }
  if ($probeLoadedVersion) { Write-Output ("Direct probe 로드 LSP 버전: {0}" -f $probeLoadedVersion) }
  if ($probeExpectedVersion) { Write-Output ("Direct probe 생성 당시 기대 버전: {0}" -f $probeExpectedVersion) }
  if ($currentExpectedVersion) { Write-Output ("현재 기대 LSP 버전: {0}" -f $currentExpectedVersion) }
  if ($currentExpectedVersion) {
    Write-Output ("Direct probe LSP 버전 일치: {0}" -f ($(if ($probeVersionMismatch) { "아니오" } else { "예" })))
  }
  Write-Output ("Direct probe 신뢰 가능: {0}" -f ($(if ($trusted) { "예" } else { "아니오" })))
  Write-Output ("Direct probe 최신 상태: {0}" -f ($(if ($probeStale) { "아니오" } else { "예" })))
  if ($statusAfterStatus) { Write-Output ("현재 저장 상태: {0}" -f $statusAfterStatus) }
  if ($statusAfterVerify) { Write-Output ("검증 상태: {0}" -f $statusAfterVerify) }
  if ($targetTitleCount) { Write-Output ("대상 제목블록 수: {0}" -f $targetTitleCount) }
  if ($targetFrameCount) { Write-Output ("대상 도면틀 수: {0}" -f $targetFrameCount) }
  if ($targetPairCount) { Write-Output ("GMTITLE 도면틀/제목블록 쌍 수: {0}" -f $targetPairCount) }
  if ($nativeLikeTargetPairCount) { Write-Output ("native-like GMTITLE 쌍 수: {0}" -f $nativeLikeTargetPairCount) }
  if ($nonNativeLikeTargetPairCount) { Write-Output ("교체 필요 GMTITLE 쌍 수: {0}" -f $nonNativeLikeTargetPairCount) }
  if ($clonedPairCount) { Write-Output ("복제/공유 링크 GMTITLE 쌍 수: {0}" -f $clonedPairCount) }
  if ($a3a4NativeUpgradeCandidateCount) { Write-Output ("A3/A4 native 교체 후보 수: {0}" -f $a3a4NativeUpgradeCandidateCount) }
  if ($orphanTargetFrameCount) { Write-Output ("고아 GMTITLE 도면틀 수: {0}" -f $orphanTargetFrameCount) }
  if ($duplicateTargetPairCount) { Write-Output ("중복 GMTITLE 쌍 수: {0}" -f $duplicateTargetPairCount) }
  if ($dbmodAfter) { Write-Output ("Direct probe 뒤 DBMOD: {0}" -f $dbmodAfter) }
  if ($script:FinalCompletionGateStatusAfterStatus -or $script:FinalCompletionGateStatusAfterVerify) {
    $gateIsNewer = $false
    if ($script:FinalCompletionGateLastWriteTimeUtc) {
      $gateIsNewer = $script:FinalCompletionGateLastWriteTimeUtc -gt $probeItem.LastWriteTimeUtc.AddSeconds(2)
    }
    $statusMatchesGate = (
      (-not $script:FinalCompletionGateStatusAfterStatus) -or
      (-not $statusAfterStatus) -or
      ($script:FinalCompletionGateStatusAfterStatus -eq $statusAfterStatus)
    )
    $verifyMatchesGate = (
      (-not $script:FinalCompletionGateStatusAfterVerify) -or
      (-not $statusAfterVerify) -or
      ($script:FinalCompletionGateStatusAfterVerify -eq $statusAfterVerify)
    )
    $nextFrameMatchesGate = (
      (-not $script:FinalCompletionGateNextFrame) -or
      (-not $nextFrame) -or
      ($script:FinalCompletionGateNextFrame -eq $nextFrame)
    )
    $nextTitleMatchesGate = (
      (-not $script:FinalCompletionGateNextTitle) -or
      (-not $nextTitle) -or
      ($script:FinalCompletionGateNextTitle -eq $nextTitle)
    )
    $gateConsistent = $statusMatchesGate -and $verifyMatchesGate -and $nextFrameMatchesGate -and $nextTitleMatchesGate
    Write-Output "Final gate/direct probe 일치 확인:"
    Write-Output ("  final gate가 direct probe보다 최신: {0}" -f ($(if ($gateIsNewer) { "예" } else { "아니오" })))
    Write-Output ("  상태/검증/다음 native 일치: {0}" -f ($(if ($gateConsistent) { "예" } else { "아니오" })))
    if ((-not $gateConsistent) -and $gateIsNewer) {
      Write-Output "Result: REVIEW_FINAL_GATE_DIRECT_PROBE_CONFLICT"
      Write-Output "이유: 최신 final completion gate와 direct probe가 서로 다른 다음 상태를 가리킵니다."
      Write-Output "다음: GstarCAD를 저장하고 닫은 뒤 direct probe를 갱신하거나 final completion gate를 다시 실행하세요."
      Write-DirectProbeRefreshCommand
      exit 0
    }
  }
  if ($AutoRefreshDirectProbe -and (-not $refreshAttempted) -and $trusted -and (-not $probeStale)) {
    Write-Output "Direct probe 자동 갱신: 기존 로그가 대상 작업복사본, 저장 시간, 현재 LSP 버전과 일치해 재사용합니다."
  }

  if (-not $pathTrusted) {
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

  if ($probeVersionMismatch) {
    if ($AutoRefreshDirectProbe -and (-not $refreshAttempted)) {
      $refreshAttempted = $true
      [void](Invoke-DirectProbeRefresh)
      continue
    }
    Write-Output "Result: RELOAD_LSP_AND_CONFIRM_STATUS"
    Write-Output "이유: direct probe 로그가 현재 로드해야 할 LSP 버전과 다릅니다."
    Write-Output "다음: hidden probe가 현재 PC에서 불안정할 수 있으므로, CAD 안에서 최신 LSP를 다시 APPLOAD하고 SWTITLESTATUS로 현재 상태를 확인하세요."
    Write-ManualLoadStep
    if ($statusAfterStatus) {
      Write-Output ("  이전 direct probe 기준 예상 상태: {0}" -f $statusAfterStatus)
    }
    if ($nextFrame -or $nextTitle) {
      Write-Output ("  이전 direct probe 기준 예상 GMTITLE 선택: {0} / {1}" -f ($(if ($nextFrame) { $nextFrame } else { "?" })), ($(if ($nextTitle) { $nextTitle } else { "?" })))
    }
    Write-Output "  SWTITLESTATUS가 같은 상태를 안내할 때만 아래 변환 명령을 계속하세요."
    Write-ConvertCommandStep
    Write-GmtitleDialogGuidance -FrameName $nextFrame -TitleName $nextTitle
    Write-Output "hidden direct probe를 먼저 갱신하고 싶으면 아래 명령을 쓰세요. 다만 현재 PC에서는 /b probe가 실패할 수 있습니다."
    Write-DirectProbeRefreshCommand
    exit 0
  }

  if ($probeFileStale) {
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

if ($statusAfterStatus -eq "NEXT_CREATE_MISSING_NATIVE_EXEMPLAR") {
  if ($nextMissingFrame -and $nextMissingFrame -ne "<none>") {
    $nextFrame = $nextMissingFrame
  }
  if ($nextMissingTitle -and $nextMissingTitle -ne "<none>") {
    $nextTitle = $nextMissingTitle
  }
}

Write-Output ""
Write-ManualSelectionForecast -StatusCode $statusAfterStatus -FrameName $nextFrame -TitleName $nextTitle -ProbeText $probeText
Write-Output ""
Write-StatusBasedAction -StatusCode $statusAfterStatus -VerifyCode $statusAfterVerify -FrameName $nextFrame -TitleName $nextTitle
