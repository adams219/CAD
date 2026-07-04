param(
  [string]$SourceWorkCopyPath,

  [string[]]$Strategies = @("none", "huge-insert", "direct-outside"),

  [int]$TimeoutSeconds = 90,

  [switch]$WaitForGstarCADClose,

  [int]$WaitForGstarCADCloseTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

function Assert-NoExistingGstarCAD {
  param(
    [switch]$Wait,

    [int]$WaitTimeoutSeconds = 600
  )

  if ($Wait) {
    $deadline = (Get-Date).AddSeconds($WaitTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
      $existing = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
      if ($existing.Count -eq 0) {
        Write-Output "No existing GstarCAD process detected. Continuing A4 normalization probe."
        return
      }
      Write-Output ("Waiting for GstarCAD to close before A4 normalization probe... active PID(s): {0}" -f (($existing | ForEach-Object { $_.Id }) -join ", "))
      Start-Sleep -Seconds 5
    }
  }

  $existingGstarCAD = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
  if ($existingGstarCAD.Count -gt 0) {
    $details = $existingGstarCAD |
      Select-Object Id, ProcessName, MainWindowTitle, StartTime |
      Format-Table -AutoSize |
      Out-String
    throw @"
Existing GstarCAD process detected before the A4 normalization probe.
The probe uses hidden /b GstarCAD, which is unreliable while a visible GstarCAD session is open.

Save the work-copy DWG, close GstarCAD, then rerun:
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_outline_normalization_probe.ps1 -Strategies nested-outside

Or start the probe in waiting mode, save/close GstarCAD, and let it continue:
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_outline_normalization_probe.ps1 -Strategies nested-outside -WaitForGstarCADClose

Existing process:
$details
"@
  }
}

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $repoRoot "work\0000_A_DRP125 CP_ALL_260704_test.dwg"
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}
Assert-NoExistingGstarCAD -Wait:$WaitForGstarCADClose -WaitTimeoutSeconds $WaitForGstarCADCloseTimeoutSeconds

$workDir = Join-Path $repoRoot "work"
if (-not (Test-Path -LiteralPath $workDir)) {
  New-Item -ItemType Directory -Path $workDir | Out-Null
}

$fixturePath = Join-Path $PSScriptRoot "a4_outline_normalization_probe.lsp"
if (-not (Test-Path -LiteralPath $fixturePath)) {
  throw "Fixture LSP not found: $fixturePath"
}

$fixtureForLisp = ($fixturePath -replace "\\", "/")
$env:SWCAD_TOOL_ROOT = $repoRoot

foreach ($strategy in $Strategies) {
  $safeStrategy = $strategy -replace '[^A-Za-z0-9_-]', '_'
  $probeDwgPath = Join-Path $workDir ("swtitle_a4_outline_norm_{0}_260705.dwg" -f $safeStrategy)
  $scriptPath = Join-Path $workDir ("swtitle_a4_outline_norm_{0}_260705.scr" -f $safeStrategy)
  $logPath = Join-Path $workDir ("swtitle_a4_outline_norm_{0}_260705.txt" -f $safeStrategy)

  Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $probeDwgPath -Force

  Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value @(
    "(load `"$fixtureForLisp`")"
  )

  $env:SWCAD_A4_NORM_STRATEGY = $strategy
  $env:SWCAD_A4_NORM_LOG = $logPath

  Write-Output ("===== A4 outline normalization strategy: {0} =====" -f $strategy)
  & (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
    -DwgPath $probeDwgPath `
    -ScriptPath $scriptPath `
    -LogPath $logPath `
    -TimeoutSeconds $TimeoutSeconds
}
