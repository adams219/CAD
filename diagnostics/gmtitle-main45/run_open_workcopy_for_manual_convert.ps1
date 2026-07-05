param(
  [string]$SourceWorkCopyPath,

  [string]$ScriptPath,

  [ValidateSet("Normal", "Maximized")]
  [string]$WindowStyle = "Maximized",

  [switch]$DryRun,

  [switch]$AllowExistingGstarCAD
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $ScriptPath) {
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

Write-Output "===== Open work-copy for manual GMTITLE convert ====="
Write-Output ("GstarCAD: {0}" -f $gcad)
Write-Output ("Work-copy DWG: {0}" -f $SourceWorkCopyPath)
Write-Output ("Loader LSP: {0}" -f $loaderPath)
Write-Output ("Startup SCR: {0}" -f $ScriptPath)
Write-Output ("Window style: {0}" -f $WindowStyle)
Write-Output "This helper opens the work-copy, loads the current LSP, and runs SWTITLESTATUS."
Write-Output "It does not run SWTITLECONVERTNEXT, does not open GMTITLE, and does not save the drawing."
Write-Output "After the CAD window is ready, type SWTITLECONVERTNEXT in GstarCAD."

if ($DryRun) {
  Write-Output "Result: DRY_RUN_READY"
  Write-Output "SCR preview:"
  foreach ($line in $scriptLines) {
    Write-Output ("  {0}" -f $line)
  }
  exit 0
}

$process = Start-Process -FilePath $gcad -ArgumentList $argumentList -WindowStyle $WindowStyle -PassThru
Write-Output ("Started GstarCAD PID: {0}" -f $process.Id)
Write-Output "Result: GSTARCAD_OPENED_FOR_MANUAL_CONVERT"
