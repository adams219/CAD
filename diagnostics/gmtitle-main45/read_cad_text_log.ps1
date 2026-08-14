param(
  [string]$Path,

  [string]$Filter = "swcad_title_next_step_last*.txt",

  [int]$Tail = 80,

  [string]$Find,

  [switch]$List
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

function Get-LogEncodingAndText {
  param([string]$LiteralPath)

  $bytes = [System.IO.File]::ReadAllBytes($LiteralPath)
  $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
  try {
    return @{
      Encoding = "utf-8"
      Text = $strictUtf8.GetString($bytes)
    }
  } catch {
    return @{
      Encoding = ("windows-default ({0})" -f [System.Text.Encoding]::Default.WebName)
      Text = [System.Text.Encoding]::Default.GetString($bytes)
    }
  }
}

function Resolve-TargetLogPath {
  if ($Path) {
    return (Resolve-Path -LiteralPath $Path).Path
  }

  if (-not (Test-Path -LiteralPath $workDir)) {
    throw "Work folder not found: $workDir"
  }

  $logs = @(Get-ChildItem -LiteralPath $workDir -Filter $Filter -File | Sort-Object LastWriteTime -Descending)
  if ($logs.Count -eq 0) {
    throw "No log files matched '$Filter' under $workDir"
  }

  return $logs[0].FullName
}

Write-Output "===== CAD text log reader ====="
Write-Output ("Repo root: {0}" -f $repoRoot)
Write-Output ("Work folder: {0}" -f $workDir)
Write-Output "Purpose: read GstarCAD text logs with UTF-8 first, then Windows-default fallback for Korean CAD logs."
Write-Output "Safety: this script only reads text files and does not edit DWG or log data."

if ($List) {
  Write-Output ""
  Write-Output ("Latest logs matching {0}:" -f $Filter)
  Get-ChildItem -LiteralPath $workDir -Filter $Filter -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 20 Name, LastWriteTime, Length |
    Format-Table -AutoSize
  Write-Output "Result: LISTED_LOGS"
  exit 0
}

$targetPath = Resolve-TargetLogPath
$decoded = Get-LogEncodingAndText -LiteralPath $targetPath
$text = $decoded.Text -replace "`r`n", "`n" -replace "`r", "`n"
$lines = @($text -split "`n")

if ($Find) {
  $selected = @()
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $Find) {
      $selected += ("{0,5}: {1}" -f ($i + 1), $lines[$i])
    }
  }
} elseif ($Tail -gt 0 -and $lines.Count -gt $Tail) {
  $start = $lines.Count - $Tail
  $selected = for ($i = $start; $i -lt $lines.Count; $i++) {
    "{0,5}: {1}" -f ($i + 1), $lines[$i]
  }
} else {
  $selected = for ($i = 0; $i -lt $lines.Count; $i++) {
    "{0,5}: {1}" -f ($i + 1), $lines[$i]
  }
}

Write-Output ""
Write-Output ("Log path: {0}" -f $targetPath)
Write-Output ("Selected encoding: {0}" -f $decoded.Encoding)
if ($Find) {
  Write-Output ("Find regex: {0}" -f $Find)
  Write-Output ("Matched lines: {0}" -f $selected.Count)
} else {
  Write-Output ("Printed tail lines: {0}" -f $selected.Count)
}
Write-Output ""

foreach ($line in $selected) {
  Write-Output $line
}

Write-Output ""
Write-Output "Result: READ_LOG_OK"
