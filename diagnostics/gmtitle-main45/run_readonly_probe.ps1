param(
  [Parameter(Mandatory = $true)]
  [string]$DwgPath,

  [Parameter(Mandatory = $true)]
  [string]$ScriptPath,

  [Parameter(Mandatory = $true)]
  [string]$LogPath,

  [string]$CompletionPattern = "Runtime check completed:",

  [int]$TimeoutSeconds = 75
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

Remove-Item -LiteralPath $LogPath -Force -ErrorAction SilentlyContinue

$argumentList = @(
  "`"$DwgPath`"",
  "/b",
  "`"$ScriptPath`""
)

$process = Start-Process -FilePath $gcad -ArgumentList $argumentList -WindowStyle Hidden -PassThru
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
}

if (-not $process.HasExited) {
  Stop-Process -Id $process.Id -Force
  Write-Output ("Stopped GstarCAD PID: {0}" -f $process.Id)
}

if (Test-Path -LiteralPath $LogPath) {
  Get-Content -LiteralPath $LogPath -Raw
} else {
  Write-Output ("Log not found: {0}" -f $LogPath)
}
