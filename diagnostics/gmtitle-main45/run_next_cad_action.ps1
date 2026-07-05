param(
  [string]$SourceWorkCopyPath,

  [string]$DirectProbeLogPath
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $DirectProbeLogPath) {
  $DirectProbeLogPath = Join-Path $workDir "swtitle_actual_workcopy_direct_status_260705.txt"
}

function Read-TextWithFallback {
  param([string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $encodings = @(
    [System.Text.Encoding]::GetEncoding(949),
    [System.Text.UTF8Encoding]::new($true, $true),
    [System.Text.Encoding]::Unicode
  )

  foreach ($encoding in $encodings) {
    try {
      return $encoding.GetString($bytes)
    } catch {
    }
  }

  return [System.Text.Encoding]::Default.GetString($bytes)
}

function Get-FirstRegexValue {
  param(
    [string]$Text,
    [string]$Pattern
  )

  $match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if ($match.Success -and $match.Groups.Count -gt 1) {
    return $match.Groups[1].Value.Trim()
  }
  return $null
}

function Test-SamePath {
  param(
    [string]$Left,
    [string]$Right
  )

  if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
    return $false
  }
  try {
    return [System.IO.Path]::GetFullPath($Left).Equals(
      [System.IO.Path]::GetFullPath($Right),
      [System.StringComparison]::OrdinalIgnoreCase
    )
  } catch {
    return $false
  }
}

Write-Output "===== GMTITLE next CAD action ====="
Write-Output ("Repo root: {0}" -f $repoRoot)
Write-Output ("Target work-copy: {0}" -f $SourceWorkCopyPath)

if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  Write-Output "Result: BLOCKED_WORKCOPY_MISSING"
  Write-Output "Next: create or restore the work-copy DWG under Documents/CAD tool/work."
  exit 1
}

if (-not (Test-Path -LiteralPath $DirectProbeLogPath)) {
  Write-Output "Direct actual work-copy probe: missing"
  Write-Output "Result: REFRESH_DIRECT_PROBE_FIRST"
  Write-Output "Next:"
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $PSScriptRoot "run_actual_workcopy_direct_status_probe.ps1"))
  exit 0
}

$probeItem = Get-Item -LiteralPath $DirectProbeLogPath
$probeText = Read-TextWithFallback -Path $DirectProbeLogPath
$probeDwg = Get-FirstRegexValue -Text $probeText -Pattern "^DWG[^:]*:\s*(.+)$"
$statusAfterStatus = Get-FirstRegexValue -Text $probeText -Pattern "^\s*status-after-status:\s*(\S+)"
$statusAfterVerify = Get-FirstRegexValue -Text $probeText -Pattern "^\s*status-after-verify:\s*(\S+)"
$nextFrame = Get-FirstRegexValue -Text $probeText -Pattern "^\s*next-bootstrap-frame:\s*(\S+)"
$nextTitle = Get-FirstRegexValue -Text $probeText -Pattern "^\s*next-bootstrap-title:\s*(\S+)"
$dbmodAfter = Get-FirstRegexValue -Text $probeText -Pattern "^\s*dbmod-after-commands:\s*(\d+)"
$targetTitleCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*target-title-count:\s*(\d+)"
$targetFrameCount = Get-FirstRegexValue -Text $probeText -Pattern "^\s*target-frame-count:\s*(\d+)"
$trusted = Test-SamePath -Left $probeDwg -Right $SourceWorkCopyPath

Write-Output ("Direct probe log: {0}" -f $DirectProbeLogPath)
Write-Output ("Direct probe time: {0}" -f $probeItem.LastWriteTime)
if ($probeDwg) { Write-Output ("Direct probe DWG: {0}" -f $probeDwg) }
Write-Output ("Direct probe trusted: {0}" -f ($(if ($trusted) { "yes" } else { "no" })))
if ($statusAfterStatus) { Write-Output ("Current saved status: {0}" -f $statusAfterStatus) }
if ($statusAfterVerify) { Write-Output ("Verify status: {0}" -f $statusAfterVerify) }
if ($targetTitleCount) { Write-Output ("Target title count: {0}" -f $targetTitleCount) }
if ($targetFrameCount) { Write-Output ("Target frame count: {0}" -f $targetFrameCount) }
if ($dbmodAfter) { Write-Output ("DBMOD after direct probe: {0}" -f $dbmodAfter) }

if (-not $trusted) {
  Write-Output "Result: REFRESH_DIRECT_PROBE_FIRST"
  Write-Output "Reason: direct probe log is not for the target work-copy."
  Write-Output "Next:"
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $PSScriptRoot "run_actual_workcopy_direct_status_probe.ps1"))
  exit 0
}

if ($dbmodAfter -and $dbmodAfter -ne "0") {
  Write-Output "Result: REVIEW_DIRECT_PROBE_DBMOD"
  Write-Output "Reason: read-only direct probe did not end with DBMOD 0."
  Write-Output "Next: do not continue CAD conversion until the saved work-copy state is clear."
  exit 0
}

Write-Output ""
if ($statusAfterStatus -eq "NEXT_CREATE_FIRST_NATIVE_GMTITLE") {
  Write-Output "Result: READY_FOR_FIRST_NATIVE_GMTITLE"
  Write-Output "Run in visible GstarCAD:"
  Write-Output "  APPLOAD"
  Write-Output ("  {0}" -f (Join-Path $repoRoot "swcad_load.lsp"))
  Write-Output "  SWTITLEVERSION"
  Write-Output "  SWTITLECONVERT"
  Write-Output ""
  Write-Output "In the GMTITLE dialog choose exactly:"
  Write-Output ("  Paper/frame: {0}" -f ($(if ($nextFrame) { $nextFrame } else { "DR_A2_Outline" })))
  Write-Output ("  Title block: {0}" -f ($(if ($nextTitle) { $nextTitle } else { "DR_titlea_3rd" })))
  Write-Output "  Frame positioning: ON"
  Write-Output "  Object move: OFF"
  Write-Output ""
  Write-Output "Abort immediately if:"
  Write-Output "  - the active DWG is not the target work-copy"
  Write-Output "  - the GMTITLE dialog shows ISO paper/title defaults"
  Write-Output "  - Object move is ON"
  Write-Output "  - GstarCAD asks for object/new location instead of accepting the lower-left placement"
  Write-Output ""
  Write-Output "After conversion:"
  Write-Output "  SWTITLESTATUS"
  Write-Output "  Save the work-copy, close GstarCAD, then refresh the direct probe."
} elseif ($statusAfterStatus -eq "SWTITLEVERIFY_FINAL_OK") {
  Write-Output "Result: READY_FOR_DOUBLE_CLICK_CHECK"
  Write-Output "Next: double-click representative A2/A3/A4 DR_titlea_3rd title blocks and confirm the GMTITLE table editor opens."
} else {
  Write-Output "Result: FOLLOW_SWTITLESTATUS"
  Write-Output "Run in visible GstarCAD:"
  Write-Output "  SWTITLESTATUS"
  Write-Output "Then follow the four-command flow shown by that command."
}
