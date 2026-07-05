param(
  [string]$SourceWorkCopyPath,

  [string]$ScriptPath,

  [ValidateSet("Normal", "Maximized")]
  [string]$WindowStyle = "Maximized",

  [int]$WaitForMainWindowSeconds = 60,

  [int]$StableMainWindowSeconds = 3,

  [int]$PostVisibleCheckSeconds = 120,

  [switch]$KeepProcessOnNoWindow,

  [switch]$RunStartupStatusScript,

  [switch]$DryRun,

  [switch]$AllowExistingGstarCAD
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if ((-not $ScriptPath) -and $RunStartupStatusScript) {
  $ScriptPath = Join-Path $workDir "swtitle_open_workcopy_for_manual_convert.scr"
}

$gcad = "C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\GstarCAD\gcad.exe"
$loaderPath = Join-Path $repoRoot "swcad_load.lsp"

if (-not (Test-Path -LiteralPath $gcad)) {
  throw "GstarCAD 실행 파일을 찾지 못했습니다: $gcad"
}
if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "작업복사본 DWG를 찾지 못했습니다: $SourceWorkCopyPath"
}
if (-not (Test-Path -LiteralPath $loaderPath)) {
  throw "로드용 LSP를 찾지 못했습니다: $loaderPath"
}
if (-not (Test-Path -LiteralPath $workDir)) {
  New-Item -ItemType Directory -Path $workDir | Out-Null
}

$existingGstarCAD = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
if (($existingGstarCAD.Count -gt 0) -and (-not $AllowExistingGstarCAD)) {
  $details = $existingGstarCAD |
    Select-Object Id, ProcessName, MainWindowTitle, StartTime |
    Format-Table -AutoSize |
    Out-String
  throw @"
이미 실행 중인 GstarCAD 프로세스가 있습니다.
이 helper를 쓰기 전에는 현재 도면을 저장하고 GstarCAD를 닫으세요. 프로세스 라우팅을 의도적으로 확인할 때만 -AllowExistingGstarCAD를 사용하세요.

실행 중인 프로세스:
$details
"@
}

$loaderForLisp = ($loaderPath -replace "\\", "/")
$scriptLines = @()

if ($RunStartupStatusScript) {
  $scriptLines = @(
    "(load `"$loaderForLisp`")",
    "(princ `"\n----- SWTITLE visible manual convert preflight -----`")",
    "SWTITLEVERSION",
    "SWTITLESTATUS",
    "(princ `"\nNext: run SWTITLECONVERTNEXT in the CAD command line, then check the GMTITLE dialog values.`")",
    "(princ)"
  )
  [System.IO.File]::WriteAllLines($ScriptPath, $scriptLines, [System.Text.Encoding]::ASCII)
  $argumentList = @(
    "`"$SourceWorkCopyPath`"",
    "/b",
    "`"$ScriptPath`""
  )
} else {
  $argumentList = @(
    "`"$SourceWorkCopyPath`""
  )
}

Write-Output "===== 수동 GMTITLE 변환용 작업복사본 열기 ====="
Write-Output ("GstarCAD: {0}" -f $gcad)
Write-Output ("작업복사본 DWG: {0}" -f $SourceWorkCopyPath)
Write-Output ("로드할 LSP: {0}" -f $loaderPath)
Write-Output ("시작 상태 스크립트: {0}" -f ($(if ($RunStartupStatusScript) { $ScriptPath } else { "<기본값: 사용 안 함>" })))
Write-Output ("창 표시 방식: {0}" -f $WindowStyle)
Write-Output ("메인 창 대기 시간(초): {0}" -f $WaitForMainWindowSeconds)
Write-Output ("안정 창 확인 시간(초): {0}" -f $StableMainWindowSeconds)
Write-Output ("열림 후 유지 확인 시간(초): {0}" -f $PostVisibleCheckSeconds)
Write-Output "이 helper는 작업복사본을 보이는 GstarCAD로 여는 것까지만 합니다."
Write-Output "기본값에서는 /b 시작 스크립트를 쓰지 않습니다. 이 PC에서는 그 경로가 보이는 CAD 창을 안정적으로 남기지 못할 수 있기 때문입니다."
Write-Output "중요: 이 helper는 SWTITLECONVERTNEXT를 실행하지 않고, GMTITLE 창을 열지 않고, 도면을 저장하지 않습니다."
Write-Output "CAD 창이 준비되면 GstarCAD 명령창에 아래 순서만 입력하세요:"
Write-Output "  APPLOAD"
Write-Output ("  {0}" -f $loaderPath)
Write-Output "  SWTITLEVERSION"
Write-Output "  SWTITLESTATUS"
Write-Output "  SWTITLECONVERTNEXT"
Write-Output "GMTITLE 창에서 고를 용지/제목블록/옵션은 SWTITLESTATUS 또는 짧은 선택 카드의 값을 따르세요."
Write-Output "필수 옵션: Frame positioning ON, Object move OFF"
Write-Output "주의: CAD 명령창에 GMTITLE, TIT, 일반 OPEN을 직접 입력하지 마세요."
if ($RunStartupStatusScript) {
  Write-Output "시작 상태 스크립트 모드가 켜져 있습니다. 시작 뒤 보이는 창이 사라지면 -RunStartupStatusScript 없이 다시 실행하세요."
}

if ($DryRun) {
  Write-Output "Result: DRY_RUN_READY"
  if ($RunStartupStatusScript) {
    Write-Output "SCR 미리보기:"
    foreach ($line in $scriptLines) {
      Write-Output ("  {0}" -f $line)
    }
  } else {
    Write-Output "SCR 미리보기: <기본값: 사용 안 함>"
  }
  exit 0
}

$process = Start-Process -FilePath $gcad -ArgumentList $argumentList -WindowStyle $WindowStyle -PassThru
Write-Output ("GstarCAD 시작 PID: {0}" -f $process.Id)

if ($WaitForMainWindowSeconds -gt 0) {
  $deadline = (Get-Date).AddSeconds($WaitForMainWindowSeconds)
  $visibleWindow = $false
  $lastWindowHandle = 0
  $stableWindowCount = 0
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
    $running = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    if (-not $running) {
      Write-Output "Result: GSTARCAD_EXITED_BEFORE_VISIBLE_WINDOW"
      exit 1
    }
    if ($running.MainWindowHandle -ne 0) {
      if ($running.MainWindowHandle -eq $lastWindowHandle) {
        $stableWindowCount += 1
      } else {
        $lastWindowHandle = $running.MainWindowHandle
        $stableWindowCount = 1
      }
      if ($stableWindowCount -ge $StableMainWindowSeconds) {
        $visibleWindow = $true
        Write-Output ("안정적으로 확인된 보이는 GstarCAD 창 핸들: {0}" -f $running.MainWindowHandle)
        if ($running.MainWindowTitle) {
          Write-Output ("보이는 GstarCAD 창 제목: {0}" -f $running.MainWindowTitle)
        }
        break
      }
    } else {
      $lastWindowHandle = 0
      $stableWindowCount = 0
    }
  }

  if (-not $visibleWindow) {
    Write-Output "Result: GSTARCAD_NO_VISIBLE_WINDOW"
    Write-Output "GstarCAD가 시작됐지만 이 Codex 세션에서 안정적인 보이는 메인 창을 유지하지 못했습니다."
    Write-Output "변환은 실행하지 않았고 도면도 저장하지 않았습니다."
    if (-not $KeepProcessOnNoWindow) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      Write-Output ("보이지 않는 GstarCAD PID를 종료했습니다: {0}" -f $process.Id)
    } else {
      Write-Output "-KeepProcessOnNoWindow가 지정되어 보이지 않는 프로세스를 유지했습니다."
    }
    exit 1
  }

  if ($PostVisibleCheckSeconds -gt 0) {
    Start-Sleep -Seconds $PostVisibleCheckSeconds
    $postCheck = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    if ((-not $postCheck) -or ($postCheck.MainWindowHandle -eq 0)) {
      Write-Output "Result: GSTARCAD_VISIBLE_WINDOW_NOT_STABLE_AFTER_CHECK"
      Write-Output "GstarCAD가 임시 창은 보였지만 후속 확인 시점까지 보이는 메인 창을 유지하지 못했습니다."
      Write-Output "변환은 실행하지 않았고 도면도 저장하지 않았습니다."
      if ($postCheck -and (-not $KeepProcessOnNoWindow)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Write-Output ("창이 불안정한 GstarCAD PID를 종료했습니다: {0}" -f $process.Id)
      } elseif ($postCheck) {
        Write-Output "-KeepProcessOnNoWindow가 지정되어 창이 불안정한 프로세스를 유지했습니다."
      }
      exit 1
    }
    Write-Output ("후속 확인된 보이는 GstarCAD 창 핸들: {0}" -f $postCheck.MainWindowHandle)
  }
}

Write-Output "Result: GSTARCAD_OPENED_FOR_MANUAL_CONVERT"
