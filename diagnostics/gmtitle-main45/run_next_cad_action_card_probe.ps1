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
  $gmtitlePath = Join-Path $repoPath "src\tools\gmtitle"
  New-Item -ItemType Directory -Path $workPath -Force | Out-Null
  New-Item -ItemType Directory -Path $gmtitlePath -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $repoPath "swcad_load.lsp") -Encoding ASCII -Value "fake loader"
  Set-Content -LiteralPath (Join-Path $gmtitlePath "swcad_title_scale.lsp") -Encoding ASCII -Value '(setq *swcad-title-scale-version* "260711-title-residue-geometry-1")'
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
    [string]$Frame = "DR_A2_Outline",
    [string]$Title = "DR_titlea_3rd",
    [string]$LoadedVersion = "260711-title-residue-geometry-1",
    [string]$ExpectedVersion = "260711-title-residue-geometry-1",
    [string]$NextMissingFrame,
    [string]$NextMissingTitle,
    [string]$NextMissingRole,
    [int]$SourceTitleCount = 13,
    [int]$TargetTitleCount = 1,
    [int]$TargetFrameCount = 1,
    [int]$TargetPairCount = 13,
    [int]$NativeLikeTargetPairCount = 1,
    [int]$NonNativeLikeTargetPairCount = 12,
    [int]$ClonedPairCount = 12,
    [int]$NativeUpgradeCandidateCount = 12,
    [int]$OrphanTargetFrameCount = 0,
    [int]$DuplicateTargetPairCount = 0,
    [int]$TargetA2Count = 1,
    [int]$TargetA3Count = 0,
    [int]$TargetA4Count = 0
  )

  $lines = @(
    "Loaded version: $LoadedVersion",
    "Expected version: $ExpectedVersion",
    "DWG: $DwgPath",
    "status-after-status: $Status",
    "status-after-verify: $VerifyStatus",
    "source-title-count: $SourceTitleCount",
    "frame-only-count: 2",
    "next-bootstrap-frame: $Frame",
    "next-bootstrap-title: $Title",
    "missing-native-frame: DR_A2_Outline",
    "missing-native-frame: DR_A3_Outline",
    "expected-sheet-counts:",
    "  A2: 1",
    "  A3: 12",
    "  A4: 2",
    "target-sheet-counts:",
    "  A2: $TargetA2Count",
    "  A3: $TargetA3Count",
    "  A4: $TargetA4Count",
    "target-title-count: $TargetTitleCount",
    "target-frame-count: $TargetFrameCount",
    "target-gmtitle-pair-count: $TargetPairCount",
    "native-like-target-pair-count: $NativeLikeTargetPairCount",
    "non-native-like-target-pair-count: $NonNativeLikeTargetPairCount",
    "cloned-gmtitle-pair-count: $ClonedPairCount",
    "a2a3a4-native-upgrade-candidate-count: $NativeUpgradeCandidateCount",
    "orphan-target-frame-count: $OrphanTargetFrameCount",
    "duplicate-target-pair-count: $DuplicateTargetPairCount",
    "dbmod-after-commands: 0"
  )
  if ($NextMissingFrame) { $lines += "next-missing-native-frame: $NextMissingFrame" }
  if ($NextMissingTitle) { $lines += "next-missing-native-title: $NextMissingTitle" }
  if ($NextMissingRole) { $lines += "next-missing-native-role: $NextMissingRole" }
  $lines | Set-Content -LiteralPath $Path -Encoding ASCII
}

function Write-FakeNativeUpgradeLog {
  param(
    [string]$Path,
    [string]$DwgPath
  )

  $lines = @(
    "SWTITLECONVERT native upgrade probe log",
    "DWG 파일: $DwgPath",
    "Remaining A2/A3/A4 native 교체 후보: 0",
    "결과: UPGRADED_CLONE_TO_NATIVE_GMTITLE - 복제 GMTITLE을 실제 native GMTITLE로 교체했습니다.",
    "모든 A2/A3/A4 교체 후보가 정리됐습니다. SWTITLEVERIFY를 실행하세요."
  )
  $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-CardCase {
  param(
    [string]$Name,
    [string]$Status,
    [string]$VerifyStatus = "SWTITLEVERIFY_FINAL_FAIL",
    [string]$Frame = "DR_A2_Outline",
    [string]$Title = "DR_titlea_3rd",
    [string[]]$Expected,
    [switch]$MakeStale,
    [switch]$MakeVersionStale,
    [switch]$MissingLog,
    [string]$NextMissingFrame,
    [string]$NextMissingTitle,
    [string]$NextMissingRole,
    [int]$SourceTitleCount = 13,
    [int]$TargetTitleCount = 1,
    [int]$TargetFrameCount = 1,
    [int]$TargetPairCount = 13,
    [int]$NativeLikeTargetPairCount = 1,
    [int]$NonNativeLikeTargetPairCount = 12,
    [int]$ClonedPairCount = 12,
    [int]$NativeUpgradeCandidateCount = 12,
    [int]$OrphanTargetFrameCount = 0,
    [int]$DuplicateTargetPairCount = 0,
    [int]$TargetA2Count = 1,
    [int]$TargetA3Count = 0,
    [int]$TargetA4Count = 0
  )

  $repo = New-FakeRepoWorkCopy -RepoName "repo_$Name" -DwgName "${Name}_workcopy"
  $dwg = $repo.WorkCopyPath
  $caseWorkDir = Split-Path -Parent $dwg
  $log = Join-Path $caseWorkDir "$Name.txt"

  if (-not $MissingLog) {
    if ($MakeVersionStale) {
      Write-FakeLog -Path $log -DwgPath $dwg -Status $Status -VerifyStatus $VerifyStatus -Frame $Frame -Title $Title -LoadedVersion "260705-old-test-version" -ExpectedVersion "260705-old-test-version" -NextMissingFrame $NextMissingFrame -NextMissingTitle $NextMissingTitle -NextMissingRole $NextMissingRole -SourceTitleCount $SourceTitleCount -TargetTitleCount $TargetTitleCount -TargetFrameCount $TargetFrameCount -TargetPairCount $TargetPairCount -NativeLikeTargetPairCount $NativeLikeTargetPairCount -NonNativeLikeTargetPairCount $NonNativeLikeTargetPairCount -ClonedPairCount $ClonedPairCount -NativeUpgradeCandidateCount $NativeUpgradeCandidateCount -OrphanTargetFrameCount $OrphanTargetFrameCount -DuplicateTargetPairCount $DuplicateTargetPairCount -TargetA2Count $TargetA2Count -TargetA3Count $TargetA3Count -TargetA4Count $TargetA4Count
    } else {
      Write-FakeLog -Path $log -DwgPath $dwg -Status $Status -VerifyStatus $VerifyStatus -Frame $Frame -Title $Title -NextMissingFrame $NextMissingFrame -NextMissingTitle $NextMissingTitle -NextMissingRole $NextMissingRole -SourceTitleCount $SourceTitleCount -TargetTitleCount $TargetTitleCount -TargetFrameCount $TargetFrameCount -TargetPairCount $TargetPairCount -NativeLikeTargetPairCount $NativeLikeTargetPairCount -NonNativeLikeTargetPairCount $NonNativeLikeTargetPairCount -ClonedPairCount $ClonedPairCount -NativeUpgradeCandidateCount $NativeUpgradeCandidateCount -OrphanTargetFrameCount $OrphanTargetFrameCount -DuplicateTargetPairCount $DuplicateTargetPairCount -TargetA2Count $TargetA2Count -TargetA3Count $TargetA3Count -TargetA4Count $TargetA4Count
    }
    if ($MakeStale) {
      (Get-Item -LiteralPath $log).LastWriteTime = (Get-Date).AddMinutes(-10)
      (Get-Item -LiteralPath $dwg).LastWriteTime = Get-Date
    } else {
      (Get-Item -LiteralPath $dwg).LastWriteTime = (Get-Date).AddMinutes(-10)
      (Get-Item -LiteralPath $log).LastWriteTime = Get-Date
    }
  } else {
    $gateLog = Join-Path $caseWorkDir "swtitle_final_completion_gate_status.txt"
    Write-FakeLog -Path $gateLog -DwgPath $dwg -Status $Status -VerifyStatus $VerifyStatus -Frame $Frame -Title $Title -NextMissingFrame $NextMissingFrame -NextMissingTitle $NextMissingTitle -NextMissingRole $NextMissingRole -SourceTitleCount $SourceTitleCount -TargetTitleCount $TargetTitleCount -TargetFrameCount $TargetFrameCount -TargetPairCount $TargetPairCount -NativeLikeTargetPairCount $NativeLikeTargetPairCount -NonNativeLikeTargetPairCount $NonNativeLikeTargetPairCount -ClonedPairCount $ClonedPairCount -NativeUpgradeCandidateCount $NativeUpgradeCandidateCount -OrphanTargetFrameCount $OrphanTargetFrameCount -DuplicateTargetPairCount $DuplicateTargetPairCount -TargetA2Count $TargetA2Count -TargetA3Count $TargetA3Count -TargetA4Count $TargetA4Count
    (Get-Item -LiteralPath $dwg).LastWriteTime = (Get-Date).AddMinutes(-10)
    (Get-Item -LiteralPath $gateLog).LastWriteTime = Get-Date
  }

  Write-Output "===== card case: $Name ====="
  $output = (& powershell -NoProfile -ExecutionPolicy Bypass -File $cardPath -SourceWorkCopyPath $dwg -DirectProbeLogPath $log) -join "`n"
  foreach ($needle in $Expected) {
    Assert-Contains -Text $output -Needle $needle -Label "$Name expected"
  }
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
  Assert-Contains -Text $output -Needle "Codex sandbox" -Label "sandbox_correction expected"
  Assert-Contains -Text $output -Needle "host_repo" -Label "sandbox_correction expected"
  Assert-Contains -Text $output -Needle "host_repo\swcad_load.lsp" -Label "sandbox_correction expected"
  Assert-NotContains -Text $output -Needle "CodexSandboxOffline\.codex\.sandbox\cwd\fake\swcad_load.lsp" -Label "sandbox_correction sandbox APPLOAD path"
}

function Invoke-NativeUpgradeMissingDirectProbeCase {
  $hostRepo = New-FakeRepoWorkCopy -RepoName "native_upgrade_repo" -DwgName "native_upgrade_workcopy"
  $missingDirectLog = Join-Path $caseRoot "native_upgrade_missing_direct_probe.txt"
  $upgradeLog = Join-Path (Split-Path -Parent $hostRepo.WorkCopyPath) "swcad_title_native_upgrade_last.txt"

  Write-FakeNativeUpgradeLog -Path $upgradeLog -DwgPath $hostRepo.WorkCopyPath
  (Get-Item -LiteralPath $hostRepo.WorkCopyPath).LastWriteTime = Get-Date
  (Get-Item -LiteralPath $upgradeLog).LastWriteTime = (Get-Date).AddSeconds(1)

  Write-Output "===== card case: native_upgrade_missing_direct_probe ====="
  $output = (& powershell -NoProfile -ExecutionPolicy Bypass -File $cardPath -SourceWorkCopyPath $hostRepo.WorkCopyPath -DirectProbeLogPath $missingDirectLog) -join "`n"
  Assert-Contains -Text $output -Needle "Result: RUN_VERIFY_AFTER_NATIVE_UPGRADE" -Label "native_upgrade_missing_direct_probe expected"
  Assert-Contains -Text $output -Needle "남은 A2/A3/A4 native 교체 후보: 0" -Label "native_upgrade_missing_direct_probe expected"
  Assert-Contains -Text $output -Needle "SWTITLEVERIFY" -Label "native_upgrade_missing_direct_probe expected"
  Assert-NotContains -Text $output -Needle "Result: RUN_NATIVE_REPLACEMENT" -Label "native_upgrade_missing_direct_probe should not reopen conversion"
}

Invoke-CardCase `
  -Name "first_native" `
  -Status "NEXT_CREATE_FIRST_NATIVE_GMTITLE" `
  -Expected @("Result: READY_FOR_FIRST_NATIVE_GMTITLE", "SWTITLECONVERTNEXT", "DR_A2_Outline", "DR_titlea_3rd", "YES/OPEN", "Frame positioning", "Object move")

Invoke-CardCase `
  -Name "prepare_title_missing" `
  -Status "NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION" `
  -Expected @("Result: RUN_PREPARE_FIRST", "SWTITLEPREPARE")

Invoke-CardCase `
  -Name "ready_title_missing_outline" `
  -Status "READY_FOR_TITLE_MISSING_OUTLINE" `
  -Expected @("Result: RUN_TITLE_MISSING_OUTLINE_CONVERT", "SWTITLESTATUS", "SWTITLECONVERTNEXT", "새 제목블록 없이", "A4 전용이 아니며")

Invoke-CardCase `
  -Name "clean_orphan_target_frame" `
  -Status "NEXT_CLEAN_ORPHAN_TARGET_FRAMES" `
  -Expected @("Result: RUN_PREPARE_FIRST", "SWTITLEPREPARE", "완료된 title-sheet로 보지 않습니다")

Invoke-CardCase `
  -Name "legacy_title_missing_prepare_status_normalized" `
  -Status "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION" `
  -Expected @("Result: RUN_PREPARE_FIRST", "SWTITLEPREPARE", "NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION")

Invoke-CardCase `
  -Name "missing_native" `
  -Status "NEXT_CREATE_MISSING_NATIVE_EXEMPLAR" `
  -NextMissingFrame "DR_A3_Outline" `
  -NextMissingTitle "DR_titlea_3rd" `
  -NextMissingRole "title-sheet" `
  -Expected @("Result: CREATE_MISSING_NATIVE_GMTITLE_SIZE", "DR_A3_Outline", "DR_titlea_3rd", "YES")

Invoke-CardCase `
  -Name "native_upgrade" `
  -Status "NEXT_UPGRADE_NATIVE_GMTITLE" `
  -Frame "DR_A3_Outline" `
  -Expected @("Result: RUN_NATIVE_REPLACEMENT", "SWTITLECONVERTNEXT", "SWTITLECONVERT", "OPEN", "BATCH", "MANUAL", "DR_A3_Outline", "DR_titlea_3rd", "12")

Invoke-CardCase `
  -Name "remaining_source_before_title_missing" `
  -Status "NEXT_RUN_FAST_BATCH" `
  -Frame "DR_A3_Outline" `
  -Title "DR_titlea_3rd" `
  -Expected @("Result: RUN_REMAINING_CONVERSION", "DR_A3_Outline", "DR_titlea_3rd", "남은 원본 표제란 시트 변환이 title-missing/frame-only 예외보다 먼저입니다")

Invoke-CardCase `
  -Name "remaining_source_batch_eligible" `
  -Status "NEXT_RUN_FAST_BATCH" `
  -Frame "DR_A3_Outline" `
  -Title "DR_titlea_3rd" `
  -SourceTitleCount 8 `
  -TargetTitleCount 5 `
  -TargetFrameCount 5 `
  -TargetPairCount 5 `
  -NativeLikeTargetPairCount 5 `
  -NonNativeLikeTargetPairCount 0 `
  -ClonedPairCount 0 `
  -NativeUpgradeCandidateCount 0 `
  -OrphanTargetFrameCount 0 `
  -DuplicateTargetPairCount 0 `
  -TargetA2Count 1 `
  -TargetA3Count 4 `
  -TargetA4Count 0 `
  -Expected @("Result: RUN_REMAINING_CONVERSION", "A3 반복 BATCH 검토 가능", "현재 4/12장", "남은 원본 표제란 8장", "SWTITLECONVERT", "BATCH", "매번 DR_A3_Outline / DR_titlea_3rd / Frame positioning ON / Object move OFF")

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
  -VerifyStatus "SWTITLEVERIFY_FINAL_OK" `
  -Expected @("Result: READY_FOR_DOUBLE_CLICK_CHECK", "DR_titlea_3rd", "title-missing/frame-only")

Invoke-CardCase `
  -Name "stale_log" `
  -Status "NEXT_UPGRADE_NATIVE_GMTITLE" `
  -MakeStale `
  -Expected @("Result: REFRESH_DIRECT_PROBE_FIRST", "Direct probe")

Invoke-CardCase `
  -Name "stale_version" `
  -Status "NEXT_CREATE_FIRST_NATIVE_GMTITLE" `
  -MakeVersionStale `
  -Expected @("Result: RELOAD_LSP_AND_CONFIRM_STATUS", "Direct probe LSP", "APPLOAD", "SWTITLESTATUS", "SWTITLECONVERTNEXT")

Invoke-CardCase `
  -Name "missing_log" `
  -Status "NEXT_UPGRADE_NATIVE_GMTITLE" `
  -MissingLog `
  -Expected @("Result: RELOAD_LSP_AND_CONFIRM_STATUS", "final gate", "-AutoRefreshDirectProbe")

Invoke-NativeUpgradeMissingDirectProbeCase

Invoke-SandboxCorrectionCase

if ($failures.Count -gt 0) {
  Write-Output ""
  Write-Output "Next CAD action card probe failures:"
  foreach ($failure in $failures) {
    Write-Output "  - $failure"
  }
  throw "Next CAD action card probe failed with $($failures.Count) issue(s)."
}

Write-Output ""
Write-Output "Next CAD action card probe result: PASS"
