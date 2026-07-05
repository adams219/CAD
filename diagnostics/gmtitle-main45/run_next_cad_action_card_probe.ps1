param()

$ErrorActionPreference = "Stop"

$cardPath = Join-Path $PSScriptRoot "run_next_cad_action.ps1"
if (-not (Test-Path -LiteralPath $cardPath)) {
  throw "Next CAD action card script not found: $cardPath"
}

$caseRoot = Join-Path $env:TEMP ("swtitle_next_card_probe_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $caseRoot | Out-Null

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
  param([string]$Message)
  [void]$failures.Add($Message)
}

function Assert-Contains {
  param(
    [string]$Text,
    [string]$Needle,
    [string]$Label
  )

  if ($Text.Contains($Needle)) {
    Write-Output "${Label}: found"
  } else {
    Add-Failure "$Label missing: $Needle"
  }
}

function Assert-NotContains {
  param(
    [string]$Text,
    [string]$Needle,
    [string]$Label
  )

  if ($Text.Contains($Needle)) {
    Add-Failure "$Label should not contain: $Needle"
  } else {
    Write-Output "${Label}: absent"
  }
}

function New-FakeDwg {
  param([string]$Name)

  $path = Join-Path $caseRoot "$Name.dwg"
  Set-Content -LiteralPath $path -Encoding ASCII -Value "fake dwg marker"
  return $path
}

function New-FakeRepoWorkCopy {
  param(
    [string]$RepoName,
    [string]$DwgName
  )

  $repoPath = Join-Path $caseRoot $RepoName
  $workPath = Join-Path $repoPath "work"
  New-Item -ItemType Directory -Path $workPath -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $repoPath "swcad_load.lsp") -Encoding ASCII -Value "fake loader"
  $dwgPath = Join-Path $workPath "$DwgName.dwg"
  Set-Content -LiteralPath $dwgPath -Encoding ASCII -Value "fake dwg marker"
  return @{
    RepoPath = $repoPath
    WorkCopyPath = $dwgPath
  }
}

function New-FakeSandboxWorkCopy {
  param([string]$DwgName)

  $sandboxRoot = Join-Path $caseRoot "CodexSandboxOffline\.codex\.sandbox\cwd\fake"
  $sandboxWorkPath = Join-Path $sandboxRoot "work"
  New-Item -ItemType Directory -Path $sandboxWorkPath -Force | Out-Null
  $dwgPath = Join-Path $sandboxWorkPath "$DwgName.dwg"
  Set-Content -LiteralPath $dwgPath -Encoding ASCII -Value "fake sandbox dwg marker"
  return @{
    RepoPath = $sandboxRoot
    WorkCopyPath = $dwgPath
  }
}

function Write-FakeLog {
  param(
    [string]$Path,
    [string]$DwgPath,
    [string]$Status,
    [string]$VerifyStatus = "SWTITLEVERIFY_FINAL_FAIL",
    [string]$Frame = "DR_A3_Outline",
    [string]$Title = "DR_titlea_3rd"
  )

  @(
    "DWG: $DwgPath",
    "status-after-status: $Status",
    "status-after-verify: $VerifyStatus",
    "source-title-count: 13",
    "frame-only-count: 2",
    "next-bootstrap-frame: $Frame",
    "next-bootstrap-title: $Title",
    "missing-native-frame: DR_A2_Outline",
    "missing-native-frame: DR_A3_Outline",
    "missing-native-frame: DR_A4_Outline",
    "expected-sheet-counts:",
    "  A2: 1",
    "  A3: 12",
    "  A4: 2",
    "target-title-count: 1",
    "target-frame-count: 1",
    "target-gmtitle-pair-count: 13",
    "native-like-target-pair-count: 1",
    "non-native-like-target-pair-count: 12",
    "cloned-gmtitle-pair-count: 12",
    "a3a4-native-upgrade-candidate-count: 12",
    "orphan-target-frame-count: 0",
    "duplicate-target-pair-count: 0",
    "dbmod-after-commands: 0"
  ) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-SandboxCorrectionCase {
  $hostRepo = New-FakeRepoWorkCopy -RepoName "host_repo" -DwgName "host_workcopy"
  $sandbox = New-FakeSandboxWorkCopy -DwgName "sandbox_workcopy"
  $log = Join-Path $caseRoot "sandbox_correction.txt"

  Write-FakeLog -Path $log -DwgPath $hostRepo.WorkCopyPath -Status "NEXT_CREATE_FIRST_NATIVE_GMTITLE" -Frame "DR_A2_Outline"
  (Get-Item -LiteralPath $hostRepo.WorkCopyPath).LastWriteTime = (Get-Date).AddMinutes(-10)
  (Get-Item -LiteralPath $sandbox.WorkCopyPath).LastWriteTime = (Get-Date).AddMinutes(-10)
  (Get-Item -LiteralPath $log).LastWriteTime = Get-Date

  Write-Output "===== card case: sandbox_correction ====="
  $output = (& powershell -NoProfile -ExecutionPolicy Bypass -File $cardPath -SourceWorkCopyPath $sandbox.WorkCopyPath -DirectProbeLogPath $log) -join "`n"
  Assert-Contains -Text $output -Needle "Codex sandbox 기본 경로 감지" -Label "sandbox_correction expected"
  Assert-Contains -Text $output -Needle ("실제 CAD용 저장소 폴더: {0}" -f $hostRepo.RepoPath) -Label "sandbox_correction expected"
  Assert-Contains -Text $output -Needle (Join-Path $hostRepo.RepoPath "swcad_load.lsp") -Label "sandbox_correction expected"
  Assert-NotContains -Text $output -Needle (Join-Path $sandbox.RepoPath "swcad_load.lsp") -Label "sandbox_correction sandbox APPLOAD path"
}

function Invoke-CardCase {
  param(
    [string]$Name,
    [string]$Status,
    [string[]]$Expected,
    [switch]$MakeStale,
    [switch]$MissingLog
  )

  $dwg = New-FakeDwg -Name $Name
  $log = Join-Path $caseRoot "$Name.txt"

  if (-not $MissingLog) {
    Write-FakeLog -Path $log -DwgPath $dwg -Status $Status
    if ($MakeStale) {
      (Get-Item -LiteralPath $log).LastWriteTime = (Get-Date).AddMinutes(-10)
      (Get-Item -LiteralPath $dwg).LastWriteTime = Get-Date
    } else {
      (Get-Item -LiteralPath $dwg).LastWriteTime = (Get-Date).AddMinutes(-10)
      (Get-Item -LiteralPath $log).LastWriteTime = Get-Date
    }
  }

  Write-Output "===== card case: $Name ====="
  $output = (& powershell -NoProfile -ExecutionPolicy Bypass -File $cardPath -SourceWorkCopyPath $dwg -DirectProbeLogPath $log) -join "`n"
  foreach ($needle in $Expected) {
    Assert-Contains -Text $output -Needle $needle -Label "$Name expected"
  }
}

Invoke-CardCase `
  -Name "first_native" `
  -Status "NEXT_CREATE_FIRST_NATIVE_GMTITLE" `
  -Expected @("예상 수동 GMTITLE 확인량", "저장된 시트 수량: A2 1장, A3 12장, A4 2장", "지금 필요한 확인", "A3 12장을 처리하기 위한 첫 native 기준 객체 1회", "A4 frame-only 2장은 제목블록 생성 대상이 아닙니다", "Result: READY_FOR_FIRST_NATIVE_GMTITLE", "SWTITLECONVERT", "DR_A3_Outline", "YES: 첫 native GMTITLE 1장을 만들고 마무리합니다.", "GMTITLE, TIT, 일반 OPEN을 직접 입력하지 마세요", "SWTITLECONVERT 안에서 물어보는 YES/OPEN/BATCH/MANUAL 응답과 CAD 일반 OPEN 명령은 다릅니다", "긴 좌표를 사람이 직접 치지 마세요", "커서가 화면 중앙에 남아 보여도")

Invoke-CardCase `
  -Name "prepare_a4" `
  -Status "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION" `
  -Expected @("Result: RUN_PREPARE_FIRST", "SWTITLEPREPARE")

Invoke-CardCase `
  -Name "native_upgrade" `
  -Status "NEXT_UPGRADE_A3_A4_NATIVE" `
  -Expected @("Result: RUN_NATIVE_REPLACEMENT", "SWTITLECONVERT", "A3/A4 native 교체 후보 수: 12", "현재 A3/A4 native 교체 후보: 12개", "현재 GMTITLE 쌍: 전체 13개, native-like 1개, 교체 필요 12개", "복제/공유 링크 후보: 12개", "OPEN 1회 성공 뒤 direct probe를 갱신해서 후보 수가 줄었는지 먼저 확인하세요.", "OPEN: 다음 A3/A4 후보 1장만 fresh native GMTITLE로 교체합니다.", "BATCH: OPEN으로 최소 1장 성공한 뒤", "MANUAL: OPEN이 새 GMTITLE을 못 잡거나 NO_INSERTS가 반복될 때만 사용합니다.")

Invoke-CardCase `
  -Name "structure_review" `
  -Status "NEXT_REVIEW_TARGET_FRAME_GEOMETRY" `
  -Expected @("Result: REVIEW_STRUCTURE_BEFORE_CONVERT", "SWTITLEVERIFY")

Invoke-CardCase `
  -Name "abort_warning" `
  -Status "ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS" `
  -Expected @("Result: REVIEW_ABORT_OR_WARNING", "SWTITLESTATUS")

Invoke-CardCase `
  -Name "final_ok" `
  -Status "SWTITLEVERIFY_FINAL_OK" `
  -Expected @("Result: READY_FOR_DOUBLE_CLICK_CHECK", "실제 DR_titlea_3rd 제목블록이 있는 대표 A2/A3 용지만 더블클릭하세요.", "표제란 없는 A4 frame-only 시트는 더블클릭할 제목블록이 없으므로")

Invoke-CardCase `
  -Name "stale_log" `
  -Status "NEXT_UPGRADE_A3_A4_NATIVE" `
  -MakeStale `
  -Expected @("Result: REFRESH_DIRECT_PROBE_FIRST", "Direct probe 최신 상태: 아니오")

Invoke-CardCase `
  -Name "missing_log" `
  -Status "NEXT_UPGRADE_A3_A4_NATIVE" `
  -MissingLog `
  -Expected @("Result: REFRESH_DIRECT_PROBE_FIRST", "-AutoRefreshDirectProbe")

Invoke-SandboxCorrectionCase

if ($failures.Count -gt 0) {
  Write-Output ""
  Write-Output "Next CAD action card probe failures:"
  foreach ($failure in $failures) {
    Write-Output "  - $failure"
  }
  throw "Next CAD action card probe failed with $($failures.Count) issue(s)."
}

Write-Output "Next CAD action card probe result: PASS"
