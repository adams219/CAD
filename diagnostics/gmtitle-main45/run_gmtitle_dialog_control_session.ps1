param(
  [string]$SourceWorkCopyPath,

  [string]$ProbeDwgPath,

  [int]$DialogWaitSeconds = 90,

  [int]$CompletionWaitSeconds = 180,

  [switch]$InspectOnly,

  [switch]$IntegratedAutoselect
)

$ErrorActionPreference = "Stop"

if ($InspectOnly -and $IntegratedAutoselect) {
  throw "-InspectOnly and -IntegratedAutoselect cannot be used together."
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"
$gcad = "C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\GstarCAD\gcad.exe"
$fixturePath = Join-Path $PSScriptRoot "dialog_control_session_probe.lsp"
$controlProbePath = Join-Path $PSScriptRoot "gmtitle_dialog_control_probe.ps1"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $ProbeDwgPath) {
  $ProbeDwgPath = Join-Path $workDir "swtitle_dialog_control_session_probe.dwg"
}

foreach ($requiredPath in @($SourceWorkCopyPath, $gcad, $fixturePath, $controlProbePath)) {
  if (-not (Test-Path -LiteralPath $requiredPath)) {
    throw "Required file not found: $requiredPath"
  }
}

$existing = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0) {
  $details = $existing |
    Select-Object Id, MainWindowHandle, MainWindowTitle, StartTime |
    Format-Table -AutoSize |
    Out-String
  throw @"
Existing GstarCAD process detected. Save and close it before this isolated dialog test.
The runner will not route a diagnostic script into an existing CAD session.

$details
"@
}

$sessionLog = Join-Path $workDir "swtitle_dialog_control_session_probe.txt"
$controlLog = Join-Path $workDir "swtitle_gmtitle_dialog_control_probe.txt"
$integratedLog = Join-Path $workDir "swcad_title_gmtitle_autoselect_last.txt"
$scriptPath = Join-Path $workDir "swtitle_dialog_control_session_probe.scr"

Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $ProbeDwgPath -Force
Remove-Item -LiteralPath $sessionLog, $controlLog, $integratedLog -Force -ErrorAction SilentlyContinue

$fixtureForLisp = ($fixturePath -replace "\\", "/")
[IO.File]::WriteAllLines(
  $scriptPath,
  @("(load `"$fixtureForLisp`")"),
  [Text.Encoding]::ASCII
)

$env:SWCAD_TOOL_ROOT = $repoRoot
$env:SWCAD_GMTITLE_DIALOG_SESSION_LOG = $sessionLog
$env:SWCAD_GMTITLE_EXTERNAL_CONTROL = if ($IntegratedAutoselect) { "0" } else { "1" }

$argumentList = @(
  "`"$ProbeDwgPath`"",
  "/b",
  "`"$scriptPath`""
)

Write-Output "===== GMTITLE fixed-control isolated session ====="
Write-Output ("Source preserved: {0}" -f $SourceWorkCopyPath)
Write-Output ("Dedicated probe copy: {0}" -f $ProbeDwgPath)
Write-Output "Expected selection: DR_A3_Outline / DR_titlea_3rd"
Write-Output "Expected options: Frame positioning ON / Object move OFF"
Write-Output ("Mode: {0}" -f $(if ($InspectOnly) { "inspect-only" } elseif ($IntegratedAutoselect) { "integrated LSP autoselect" } else { "external apply and click OK" }))

$process = Start-Process -FilePath $gcad -ArgumentList $argumentList -WindowStyle Hidden -PassThru
Write-Output ("Started isolated GstarCAD PID: {0}" -f $process.Id)

try {
  if (-not $InspectOnly) {
    $sessionLogDeadline = (Get-Date).AddSeconds($DialogWaitSeconds)
    while ((-not (Test-Path -LiteralPath $sessionLog)) -and ((Get-Date) -lt $sessionLogDeadline)) {
      Start-Sleep -Milliseconds 250
    }
    if (-not (Test-Path -LiteralPath $sessionLog)) {
      throw "The isolated GstarCAD session did not create its DWG identity log before timeout: $sessionLog"
    }
  }

  if (-not $IntegratedAutoselect) {
    $controlArgs = @{
      ProcessId = $process.Id
      ExpectedDwgPath = $ProbeDwgPath
      SessionLogPath = $sessionLog
      ExpectedFrame = "DR_A3_Outline"
      ExpectedTitle = "DR_titlea_3rd"
      WaitSeconds = $DialogWaitSeconds
      LogPath = $controlLog
    }
    if (-not $InspectOnly) {
      $controlArgs.ApplySelections = $true
      $controlArgs.ClickOk = $true
    }

    & $controlProbePath @controlArgs | Out-Host
  }

  if ($InspectOnly) {
    Write-Output "Result: DIALOG_CONTROL_INSPECTION_COMPLETE"
    Write-Output "The probe DWG was not saved by the session because OK was not clicked."
    exit 0
  }

  $deadline = (Get-Date).AddSeconds($CompletionWaitSeconds)
  $completed = $false
  while ((Get-Date) -lt $deadline) {
    if (Test-Path -LiteralPath $sessionLog) {
      $sessionText = Get-Content -LiteralPath $sessionLog -Raw -ErrorAction SilentlyContinue
      if ($sessionText -match "Runtime check completed:\s*yes") {
        $completed = $true
        break
      }
    }
    Start-Sleep -Milliseconds 500
  }

  if (-not $completed) {
    throw "GMTITLE session did not complete before timeout. Inspect: $sessionLog and $controlLog"
  }

  $sessionText = Get-Content -LiteralPath $sessionLog -Raw
  if ($sessionText -notmatch "Result:\s*NATIVE_GMTITLE_CREATED_BY_FIXED_CONTROL_SELECTION") {
    throw "GMTITLE session completed without a valid native result. Inspect: $sessionLog"
  }

  Write-Output ""
  if ($IntegratedAutoselect -and (Test-Path -LiteralPath $integratedLog)) {
    Get-Content -LiteralPath $integratedLog
    Write-Output ""
  }
  Get-Content -LiteralPath $sessionLog
  Write-Output ("Result: {0}" -f $(if ($IntegratedAutoselect) { "INTEGRATED_FIXED_CONTROL_GMTITLE_SESSION_PASS" } else { "FIXED_CONTROL_GMTITLE_SESSION_PASS" }))
} finally {
  $running = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
  if ($running) {
    Stop-Process -Id $process.Id -Force
    Write-Output ("Stopped isolated GstarCAD PID: {0}" -f $process.Id)
  }
}
