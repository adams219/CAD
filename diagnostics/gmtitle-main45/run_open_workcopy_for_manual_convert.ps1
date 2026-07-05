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
  throw "GstarCAD executable not found: $gcad"
}
if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Work-copy DWG not found: $SourceWorkCopyPath"
}
if (-not (Test-Path -LiteralPath $loaderPath)) {
  throw "Loader LSP not found: $loaderPath"
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
Existing GstarCAD process detected.
Save the current drawing and close GstarCAD before using this helper, or use -AllowExistingGstarCAD only when you intentionally want to debug process routing.

Existing process:
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

Write-Output "===== Open work-copy for manual GMTITLE convert ====="
Write-Output ("GstarCAD: {0}" -f $gcad)
Write-Output ("Work-copy DWG: {0}" -f $SourceWorkCopyPath)
Write-Output ("Loader LSP: {0}" -f $loaderPath)
Write-Output ("Startup status script: {0}" -f ($(if ($RunStartupStatusScript) { $ScriptPath } else { "<not used by default>" })))
Write-Output ("Window style: {0}" -f $WindowStyle)
Write-Output ("Main window wait seconds: {0}" -f $WaitForMainWindowSeconds)
Write-Output ("Stable main window seconds: {0}" -f $StableMainWindowSeconds)
Write-Output ("Post-visible check seconds: {0}" -f $PostVisibleCheckSeconds)
Write-Output "This helper opens the work-copy in visible GstarCAD."
Write-Output "By default it does not use /b startup scripts because that path can leave no stable visible CAD window in this Codex session."
Write-Output "Run APPLOAD, SWTITLEVERSION, SWTITLESTATUS, and SWTITLECONVERTNEXT inside GstarCAD after the window is ready."
Write-Output "It does not run SWTITLECONVERTNEXT, does not open GMTITLE, and does not save the drawing."
Write-Output "Manual commands after the CAD window is ready:"
Write-Output "  APPLOAD"
Write-Output ("  {0}" -f $loaderPath)
Write-Output "  SWTITLEVERSION"
Write-Output "  SWTITLESTATUS"
Write-Output "  SWTITLECONVERTNEXT"
if ($RunStartupStatusScript) {
  Write-Output "Startup status script mode is enabled. If the visible window disappears after startup, rerun without -RunStartupStatusScript."
}

if ($DryRun) {
  Write-Output "Result: DRY_RUN_READY"
  if ($RunStartupStatusScript) {
    Write-Output "SCR preview:"
    foreach ($line in $scriptLines) {
      Write-Output ("  {0}" -f $line)
    }
  } else {
    Write-Output "SCR preview: <not used by default>"
  }
  exit 0
}

$process = Start-Process -FilePath $gcad -ArgumentList $argumentList -WindowStyle $WindowStyle -PassThru
Write-Output ("Started GstarCAD PID: {0}" -f $process.Id)

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
        Write-Output ("Stable visible GstarCAD window handle: {0}" -f $running.MainWindowHandle)
        if ($running.MainWindowTitle) {
          Write-Output ("Visible GstarCAD window title: {0}" -f $running.MainWindowTitle)
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
    Write-Output "GstarCAD started but did not keep a stable visible main window in this Codex session."
    Write-Output "No conversion was run and no drawing was saved."
    if (-not $KeepProcessOnNoWindow) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      Write-Output ("Stopped non-visible GstarCAD PID: {0}" -f $process.Id)
    } else {
      Write-Output "Kept the non-visible process because -KeepProcessOnNoWindow was specified."
    }
    exit 1
  }

  if ($PostVisibleCheckSeconds -gt 0) {
    Start-Sleep -Seconds $PostVisibleCheckSeconds
    $postCheck = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    if ((-not $postCheck) -or ($postCheck.MainWindowHandle -eq 0)) {
      Write-Output "Result: GSTARCAD_VISIBLE_WINDOW_NOT_STABLE_AFTER_CHECK"
      Write-Output "GstarCAD showed a temporary window but did not keep a visible main window after the post-check."
      Write-Output "No conversion was run and no drawing was saved."
      if ($postCheck -and (-not $KeepProcessOnNoWindow)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Write-Output ("Stopped unstable-window GstarCAD PID: {0}" -f $process.Id)
      } elseif ($postCheck) {
        Write-Output "Kept the unstable-window process because -KeepProcessOnNoWindow was specified."
      }
      exit 1
    }
    Write-Output ("Post-check visible GstarCAD window handle: {0}" -f $postCheck.MainWindowHandle)
  }
}

Write-Output "Result: GSTARCAD_OPENED_FOR_MANUAL_CONVERT"
