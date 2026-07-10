param(
  [Alias("SourceDwgPath")]
  [string]$SourceWorkCopyPath,

  [string]$ProbeDwgPath,

  [string]$LogPath,

  [int]$TimeoutSeconds = 75,

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
        Write-Output "No existing GstarCAD process detected. Continuing source-title-missing native exemplar probe (A4-sized sample)."
        return
      }
      Write-Output ("Waiting for GstarCAD to close before source-title-missing native exemplar probe (A4-sized sample)... active PID(s): {0}" -f (($existing | ForEach-Object { $_.Id }) -join ", "))
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
Existing GstarCAD process detected before the source-title-missing native exemplar probe (A4-sized sample).
The probe uses hidden /b GstarCAD, which is unreliable while a visible GstarCAD session is open.

Save the scratch/native A4 DWG, close GstarCAD, then rerun:
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1 -SourceDwgPath "<scratch-native-a4-dwg>"

Or start the probe in waiting mode, save/close GstarCAD, and let it continue:
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1 -SourceDwgPath "<scratch-native-a4-dwg>" -WaitForGstarCADClose

Existing process:
$details
"@
  }
}

if (-not $SourceWorkCopyPath) {
  throw @"
A4_NATIVE_EXEMPLAR_REQUIRES_SOURCEWORKCOPYPATH
run_a4_native_exemplar_probe.ps1 requires -SourceWorkCopyPath or -SourceDwgPath.

Use a saved scratch/native A4 GMTITLE DWG when checking for a usable A4 exemplar:
  powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1 -SourceDwgPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\<scratch-native-a4>.dwg"

The main verification suite passes the default work-copy path explicitly for the known A4 gap probe.
"@
}
if (-not $ProbeDwgPath) {
  $ProbeDwgPath = Join-Path $repoRoot "work\swtitle_a4_native_exemplar_probe_260705.dwg"
}
if (-not $LogPath) {
  $LogPath = Join-Path $repoRoot "work\swtitle_a4_native_exemplar_probe_260705.txt"
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}
Assert-NoExistingGstarCAD -Wait:$WaitForGstarCADClose -WaitTimeoutSeconds $WaitForGstarCADCloseTimeoutSeconds

$workDir = Join-Path $repoRoot "work"
if (-not (Test-Path -LiteralPath $workDir)) {
  New-Item -ItemType Directory -Path $workDir | Out-Null
}

$fixturePath = Join-Path $PSScriptRoot "a4_native_exemplar_probe.lsp"
if (-not (Test-Path -LiteralPath $fixturePath)) {
  throw "Fixture LSP not found: $fixturePath"
}

Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $ProbeDwgPath -Force

$scriptPath = Join-Path $workDir "swtitle_a4_native_exemplar_probe_260705.scr"
$fixtureForLisp = ($fixturePath -replace "\\", "/")
Set-Content -LiteralPath $scriptPath -Encoding ASCII -Value "(load `"$fixtureForLisp`")"

$env:SWCAD_TOOL_ROOT = $repoRoot
$env:SWCAD_A4_NATIVE_LOG = $LogPath

& (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
  -DwgPath $ProbeDwgPath `
  -ScriptPath $scriptPath `
  -LogPath $LogPath `
  -TimeoutSeconds $TimeoutSeconds
