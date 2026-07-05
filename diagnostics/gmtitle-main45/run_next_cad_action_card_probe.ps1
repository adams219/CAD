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

function New-FakeDwg {
  param([string]$Name)

  $path = Join-Path $caseRoot "$Name.dwg"
  Set-Content -LiteralPath $path -Encoding ASCII -Value "fake dwg marker"
  return $path
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
    "next-bootstrap-frame: $Frame",
    "next-bootstrap-title: $Title",
    "target-title-count: 1",
    "target-frame-count: 1",
    "dbmod-after-commands: 0"
  ) | Set-Content -LiteralPath $Path -Encoding UTF8
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
  -Expected @("Result: READY_FOR_FIRST_NATIVE_GMTITLE", "SWTITLECONVERT", "DR_A3_Outline", "YES: 첫 native GMTITLE 1장을 만들고 마무리합니다.")

Invoke-CardCase `
  -Name "prepare_a4" `
  -Status "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION" `
  -Expected @("Result: RUN_PREPARE_FIRST", "SWTITLEPREPARE")

Invoke-CardCase `
  -Name "native_upgrade" `
  -Status "NEXT_UPGRADE_A3_A4_NATIVE" `
  -Expected @("Result: RUN_NATIVE_REPLACEMENT", "SWTITLECONVERT", "OPEN: 다음 A3/A4 후보 1장만 fresh native GMTITLE로 교체합니다.", "MANUAL: OPEN이 새 GMTITLE을 못 잡거나 NO_INSERTS가 반복될 때만 사용합니다.")

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

if ($failures.Count -gt 0) {
  Write-Output ""
  Write-Output "Next CAD action card probe failures:"
  foreach ($failure in $failures) {
    Write-Output "  - $failure"
  }
  throw "Next CAD action card probe failed with $($failures.Count) issue(s)."
}

Write-Output "Next CAD action card probe result: PASS"
