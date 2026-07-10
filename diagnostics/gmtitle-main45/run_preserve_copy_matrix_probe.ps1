param(
  [string]$SourceWorkCopyPath,

  [int[]]$CopyCounts = @(1, 2, 3),

  [int]$TimeoutSeconds = 180,

  [switch]$AllowExistingGstarCAD
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"
$fixturePath = Join-Path $PSScriptRoot "preserve_copy_matrix_probe.lsp"
$readonlyRunner = Join-Path $PSScriptRoot "run_readonly_probe.ps1"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}
if (-not (Test-Path -LiteralPath $fixturePath)) {
  throw "Preserve-copy matrix fixture not found: $fixturePath"
}
if (-not (Test-Path -LiteralPath $readonlyRunner)) {
  throw "Read-only GstarCAD runner not found: $readonlyRunner"
}

$invalidCounts = @($CopyCounts | Where-Object { $_ -notin 1, 2, 3 })
if ($invalidCounts.Count -gt 0) {
  throw "CopyCounts accepts only 1, 2, and 3. Invalid: $($invalidCounts -join ', ')"
}

$existing = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
if (($existing.Count -gt 0) -and (-not $AllowExistingGstarCAD)) {
  $details = $existing |
    Select-Object Id, MainWindowHandle, MainWindowTitle, StartTime |
    Format-Table -AutoSize |
    Out-String
  throw @"
Existing GstarCAD process detected. The structural matrix probe will not risk routing
its script into an existing CAD session. Close GstarCAD, then rerun this command.

$details
"@
}

$results = @()
$fixtureForLisp = ($fixturePath -replace "\\", "/")

foreach ($copyCount in $CopyCounts) {
  $probeBase = "swtitle_preserve_copy_matrix_$copyCount"
  $probeDwgPath = Join-Path $workDir "$probeBase.dwg"
  $logPath = Join-Path $workDir "$probeBase.txt"
  $scriptPath = Join-Path $workDir "$probeBase.scr"

  Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $probeDwgPath -Force
  [System.IO.File]::WriteAllLines(
    $scriptPath,
    @("(load `"$fixtureForLisp`")"),
    [System.Text.Encoding]::ASCII
  )

  $env:SWCAD_TOOL_ROOT = $repoRoot
  $env:SWCAD_PRESERVE_COPY_COUNT = [string]$copyCount
  $env:SWCAD_PRESERVE_COPY_MATRIX_LOG = $logPath

  $runnerArgs = @{
    DwgPath = $probeDwgPath
    ScriptPath = $scriptPath
    LogPath = $logPath
    TimeoutSeconds = $TimeoutSeconds
    WindowStyle = "Minimized"
  }
  if ($AllowExistingGstarCAD) {
    $runnerArgs.AllowExistingGstarCAD = $true
  }

  Write-Output ""
  Write-Output ("===== Preserve-copy structural case: {0} copy/copies =====" -f $copyCount)
  & $readonlyRunner @runnerArgs | Out-Host

  if (-not (Test-Path -LiteralPath $logPath)) {
    throw "Probe log was not created: $logPath"
  }

  $logText = Get-Content -LiteralPath $logPath -Raw
  $ready = $logText -match "Result:\s*STRUCTURAL_MATRIX_READY"
  $saved = $logText -match "Saved probe DWG:\s*yes"
  $created = [regex]::Match($logText, "Created preserve-copy count:\s*(\d+)")
  $createdCount = if ($created.Success) { [int]$created.Groups[1].Value } else { -1 }

  $results += [pscustomobject]@{
    CopyCount = $copyCount
    CreatedCount = $createdCount
    Ready = $ready
    Saved = $saved
    DwgPath = $probeDwgPath
    LogPath = $logPath
  }

  if ((-not $ready) -or (-not $saved) -or ($createdCount -ne $copyCount)) {
    throw "Preserve-copy structural case $copyCount failed. Inspect: $logPath"
  }
}

Write-Output ""
Write-Output "===== Preserve-copy structural matrix summary ====="
$results | Format-Table CopyCount, CreatedCount, Ready, Saved, DwgPath -AutoSize
Write-Output "Result: PRESERVE_COPY_STRUCTURAL_MATRIX_READY_FOR_CAD_RECOGNITION_CHECK"
Write-Output "Next: use the logged title double-click points on these dedicated probe copies."
