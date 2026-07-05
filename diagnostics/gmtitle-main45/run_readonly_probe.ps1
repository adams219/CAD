param(
  [Parameter(Mandatory = $true)]
  [string]$DwgPath,

  [Parameter(Mandatory = $true)]
  [string]$ScriptPath,

  [Parameter(Mandatory = $true)]
  [string]$LogPath,

  [string]$CompletionPattern = "Runtime check completed:",

  [int]$TimeoutSeconds = 75,

  [ValidateSet("Hidden", "Minimized", "Normal", "Maximized")]
  [string]$WindowStyle = "Minimized",

  [switch]$AllowExistingGstarCAD
)

$ErrorActionPreference = "Stop"

$gcad = "C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\GstarCAD\gcad.exe"
if (-not (Test-Path -LiteralPath $gcad)) {
  throw "GstarCAD executable not found: $gcad"
}
if (-not (Test-Path -LiteralPath $DwgPath)) {
  throw "DWG not found: $DwgPath"
}
if (-not (Test-Path -LiteralPath $ScriptPath)) {
  throw "SCR not found: $ScriptPath"
}

$existingGstarCAD = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
if (($existingGstarCAD.Count -gt 0) -and (-not $AllowExistingGstarCAD)) {
  $details = $existingGstarCAD |
    Select-Object Id, ProcessName, MainWindowTitle, StartTime |
    Format-Table -AutoSize |
    Out-String
  throw @"
Existing GstarCAD process detected before GstarCAD /b probe startup.
GstarCAD /b probes are unreliable while a visible GstarCAD session is open because GstarCAD can route the script to the existing instance or wait behind an active command prompt.

Save the work-copy DWG, close GstarCAD, then rerun the probe.

Existing process:
$details
Use -AllowExistingGstarCAD only for deliberate debugging.
"@
}

Remove-Item -LiteralPath $LogPath -Force -ErrorAction SilentlyContinue

$argumentList = @(
  "`"$DwgPath`"",
  "/b",
  "`"$ScriptPath`""
)

Write-Output ("GstarCAD DWG: {0}" -f $DwgPath)
Write-Output ("GstarCAD script: {0}" -f $ScriptPath)
Write-Output ("Expected log: {0}" -f $LogPath)
Write-Output ("Completion pattern: {0}" -f $CompletionPattern)
Write-Output ("Timeout seconds: {0}" -f $TimeoutSeconds)
Write-Output ("Window style: {0}" -f $WindowStyle)
try {
  $scriptPreview = Get-Content -LiteralPath $ScriptPath -TotalCount 3 -ErrorAction Stop
  Write-Output "Script preview:"
  foreach ($line in $scriptPreview) {
    Write-Output ("  {0}" -f $line)
  }
} catch {
  Write-Output ("Script preview unavailable: {0}" -f $_.Exception.Message)
}

$process = Start-Process -FilePath $gcad -ArgumentList $argumentList -WindowStyle $WindowStyle -PassThru
Write-Output ("Started GstarCAD PID: {0}" -f $process.Id)

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$completed = $false
while ((Get-Date) -lt $deadline) {
  if (Test-Path -LiteralPath $LogPath) {
    $text = Get-Content -LiteralPath $LogPath -Raw -ErrorAction SilentlyContinue
    if ($text -match [regex]::Escape($CompletionPattern)) {
      $completed = $true
      break
    }
  }
  Start-Sleep -Milliseconds 750
}

if (-not $completed) {
  Write-Output "Runtime log was not completed before timeout."
  Write-Output ("GstarCAD /b script did not produce the expected completion pattern before the timeout. Window style: {0}" -f $WindowStyle)
  Write-Output "If no log was created at all, GstarCAD likely started but did not execute the provided SCR file in this session."
}

if (-not $process.HasExited) {
  Stop-Process -Id $process.Id -Force
  Write-Output ("Stopped GstarCAD PID: {0}" -f $process.Id)
  $exitDeadline = (Get-Date).AddSeconds(60)
  while ((Get-Date) -lt $exitDeadline) {
    $stillRunning = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    if (-not $stillRunning) {
      break
    }
    Start-Sleep -Seconds 1
  }
  $stillRunning = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
  if ($stillRunning) {
    throw "GstarCAD PID $($process.Id) did not exit after Stop-Process; aborting before starting another GstarCAD /b probe."
  }
}

if (Test-Path -LiteralPath $LogPath) {
  Get-Content -LiteralPath $LogPath -Raw
} else {
  Write-Output ("Log not found: {0}" -f $LogPath)
}
