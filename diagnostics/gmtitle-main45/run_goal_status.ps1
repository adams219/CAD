param(
  [string]$SourceWorkCopyPath
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$staticPreflight = Join-Path $PSScriptRoot "run_static_preflight.ps1"
$suite = Join-Path $PSScriptRoot "run_main45_verification_suite.ps1"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $repoRoot "work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}

function Invoke-GitText {
  param([string[]]$Arguments)

  try {
    $result = & git @Arguments 2>$null
    if ($LASTEXITCODE -eq 0) {
      return (($result | Out-String).Trim())
    }
  } catch {
    return "<git unavailable>"
  }
  return "<git unavailable>"
}

Write-Output "===== GMTITLE goal status ====="
Write-Output ("Repo root: {0}" -f $repoRoot)
Write-Output ("Branch: {0}" -f (Invoke-GitText @("branch", "--show-current")))
Write-Output ("Commit: {0}" -f (Invoke-GitText @("log", "-1", "--oneline")))

$statusText = Invoke-GitText @("status", "--short")
if ([string]::IsNullOrWhiteSpace($statusText)) {
  Write-Output "Working tree: clean"
} else {
  Write-Output "Working tree: dirty"
  Write-Output $statusText
}

Write-Output ""
Write-Output "Running static preflight..."
try {
  $preflightOutput = & $staticPreflight 2>&1
  $preflightExit = $LASTEXITCODE
  if ($preflightExit -ne 0) {
    Write-Output ($preflightOutput | Out-String)
    throw "Static preflight failed with exit code $preflightExit."
  }
  Write-Output "Static preflight: PASS"
} catch {
  Write-Output "Static preflight: FAIL"
  Write-Output ($_ | Out-String)
  throw
}

Write-Output ""
$existingGstarCAD = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
if ($existingGstarCAD.Count -gt 0) {
  Write-Output "GstarCAD: open"
  $existingGstarCAD |
    Select-Object Id, ProcessName, MainWindowTitle, StartTime |
    Format-Table -AutoSize |
    Out-String |
    Write-Output
} else {
  Write-Output "GstarCAD: closed"
}

$workCopyExists = "no"
if (Test-Path -LiteralPath $SourceWorkCopyPath) {
  $workCopyExists = "yes"
}
Write-Output ("Default work-copy: {0}" -f $SourceWorkCopyPath)
Write-Output ("Default work-copy exists: {0}" -f $workCopyExists)

Write-Output ""
Write-Output "Next action:"
if ($existingGstarCAD.Count -gt 0) {
  Write-Output "  1. Save the visible GstarCAD work-copy DWG."
  Write-Output "  2. Close GstarCAD."
  Write-Output "  3. Run the full hidden suite:"
  Write-Output ("     powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f $suite)
  Write-Output "  Or start the suite in waiting mode first:"
  Write-Output ("     powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -WaitForGstarCADClose" -f $suite)
} else {
  Write-Output "  Run the full hidden suite now:"
  Write-Output ("     powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f $suite)
}

Write-Output ""
Write-Output "Goal status: not complete until the hidden suite passes and the actual work-copy reaches SWTITLEVERIFY_FINAL_OK."
