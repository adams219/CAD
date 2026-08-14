param(
  [string]$SourceWorkCopyPath,

  [string]$ScriptPath,

  [string]$LogPath,

  [int]$TimeoutSeconds = 240,

  [ValidateSet("Hidden", "Minimized", "Normal", "Maximized")]
  [string]$WindowStyle = "Minimized"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"
if (-not (Test-Path -LiteralPath $workDir)) {
  New-Item -ItemType Directory -Path $workDir | Out-Null
}

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $ScriptPath) {
  $ScriptPath = Join-Path $env:TEMP "swtitle_hidden_script_smoke_probe.scr"
}
if (-not $LogPath) {
  $LogPath = Join-Path $workDir "swtitle_hidden_script_smoke_probe.txt"
}

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}

Remove-Item -LiteralPath $LogPath -Force -ErrorAction SilentlyContinue

$logForLisp = $LogPath.Replace("\", "/")
$scriptText = "(setq h (open `"$logForLisp`" `"w`")) (if h (progn (write-line `"HIDDEN_SCRIPT_SMOKE_OK`" h) (close h)))`r`n"
[System.IO.File]::WriteAllText($ScriptPath, $scriptText, [System.Text.Encoding]::ASCII)

Write-Output "===== GstarCAD /b script smoke probe ====="
Write-Output ("DWG: {0}" -f $SourceWorkCopyPath)
Write-Output ("SCR: {0}" -f $ScriptPath)
Write-Output ("LOG: {0}" -f $LogPath)
Write-Output ("Window style: {0}" -f $WindowStyle)

& (Join-Path $PSScriptRoot "run_readonly_probe.ps1") `
  -DwgPath $SourceWorkCopyPath `
  -ScriptPath $ScriptPath `
  -LogPath $LogPath `
  -CompletionPattern "HIDDEN_SCRIPT_SMOKE_OK" `
  -TimeoutSeconds $TimeoutSeconds `
  -WindowStyle $WindowStyle | Write-Output

if (-not (Test-Path -LiteralPath $LogPath)) {
  throw @"
GstarCAD /b script smoke probe failed: no log was created.

This means GstarCAD /b verification probes cannot currently prove CAD behavior on this PC with WindowStyle=$WindowStyle, even with a one-line AutoLISP script.
Do not interpret later loader/probe log-missing failures as GMTITLE logic failures until this smoke probe passes.

Try:
1. Save and close every visible GstarCAD window.
2. Rerun this smoke probe with a longer -TimeoutSeconds value.
3. If WindowStyle=Hidden fails with no log, rerun with -WindowStyle Minimized.
4. If it still fails, continue the visible SWTITLECONVERT workflow and use SWTITLESTATUS/SWTITLEVERIFY logs from the real work-copy.
"@
}

$text = Get-Content -LiteralPath $LogPath -Raw
if ($text -notmatch "HIDDEN_SCRIPT_SMOKE_OK") {
  throw "GstarCAD /b script smoke probe failed: log exists but does not contain HIDDEN_SCRIPT_SMOKE_OK."
}

Write-Output "GstarCAD /b script smoke probe result: PASS"
