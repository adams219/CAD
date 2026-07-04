param(
  [string]$SourceWorkCopyPath
)

$ErrorActionPreference = "Stop"

$scriptRepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$gitRepoRoot = $null
try {
  $gitRepoRoot = ((& git -C (Get-Location).Path rev-parse --show-toplevel 2>$null) | Select-Object -First 1).Trim()
} catch {
  $gitRepoRoot = $null
}
if ($gitRepoRoot -and (Test-Path -LiteralPath $gitRepoRoot)) {
  $repoRoot = (Resolve-Path -LiteralPath $gitRepoRoot).Path
} else {
  $repoRoot = $scriptRepoRoot
}
$diagnosticsDir = Join-Path $repoRoot "diagnostics\gmtitle-main45"
$staticPreflight = Join-Path $diagnosticsDir "run_static_preflight.ps1"
$suite = Join-Path $diagnosticsDir "run_main45_verification_suite.ps1"
$runCard = Join-Path $repoRoot "docs\guide\gmtitle-current-run-card.md"
$goalPlan = Join-Path $repoRoot "docs\guide\gmtitle-goal-mode-plan.md"
$script:LatestCadDwg = $null
$script:LatestCadStatusCode = $null
$script:LatestCadRecommendedCommand = $null

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

function Get-FirstMatchingLine {
  param(
    [string]$Text,
    [string]$Pattern
  )

  foreach ($line in ($Text -split "\r?\n")) {
    if ($line -match $Pattern) {
      return $line.Trim()
    }
  }
  return $null
}

function Write-LatestCadLogSummary {
  param([string]$WorkDir)

  $nextStepLog = Join-Path $WorkDir "swcad_title_next_step_last.txt"
  if (-not (Test-Path -LiteralPath $nextStepLog)) {
    Write-Output "Latest CAD next-step log: <missing>"
    return
  }

  $item = Get-Item -LiteralPath $nextStepLog
  $text = Read-TextWithFallback -Path $nextStepLog
  $lines = $text -split "\r?\n"

  $dwg = $null
  foreach ($line in $lines) {
    if ($line -match "^DWG[^:]*:\s*(.+)$") {
      $dwg = $Matches[1].Trim()
      break
    }
  }

  $statusCode = Get-FirstRegexValue `
    -Text $text `
    -Pattern "(NEXT_[A-Z0-9_]+|WARN_[A-Z0-9_]+|FAIL_[A-Z0-9_]+|SWTITLEVERIFY_FINAL_[A-Z]+)"

  $recommended = $null
  if ($statusCode -match "^NEXT_PREPARE") {
    $recommended = "SWTITLEPREPARE"
  } elseif ($statusCode -match "^NEXT_.*GMTITLE|^NEXT_.*CONVERT|^NEXT_UPGRADE") {
    $recommended = "SWTITLECONVERT"
  } elseif ($statusCode -match "^SWTITLEVERIFY_FINAL_FAIL") {
    $recommended = "SWTITLESTATUS"
  }

  $visibleCounts = @()
  foreach ($sheet in @("A2", "A3", "A4")) {
    foreach ($line in $lines) {
      if ($line -match ("^\s*{0}:\s*(\d+)\s*$" -f $sheet)) {
        $visibleCounts += ("{0}={1}" -f $sheet, $Matches[1])
        break
      }
    }
  }

  $missingLines = @()
  foreach ($line in $lines) {
    if ($line -match "^\s*A[0-4]:\D+\d+,\D+\d+") {
      $missingLines += $line.Trim()
    }
  }

  Write-Output "Latest CAD next-step log:"
  Write-Output ("  Path: {0}" -f $nextStepLog)
  Write-Output ("  LastWriteTime: {0}" -f $item.LastWriteTime)
  if ($dwg) { Write-Output ("  DWG: {0}" -f $dwg) }
  if ($statusCode) { Write-Output ("  Status code: {0}" -f $statusCode) }
  if ($visibleCounts.Count -gt 0) {
    Write-Output ("  Sheet-count lines mentioned: {0}" -f ($visibleCounts -join ", "))
  }
  if ($missingLines.Count -gt 0) {
    Write-Output ("  Missing target frame count lines: {0}" -f ($missingLines -join " | "))
  }
  if ($recommended) {
    Write-Output ("  Recommended next command: {0}" -f $recommended)
  }

  $script:LatestCadDwg = $dwg
  $script:LatestCadStatusCode = $statusCode
  $script:LatestCadRecommendedCommand = $recommended
}

function Write-A4FrameOnlyEvidenceSummary {
  param([string]$WorkDir)

  Write-Output "A4 frame-only evidence:"

  $frameDefLog = Join-Path $WorkDir "swcad_title_frame_def_check_last.txt"
  if (Test-Path -LiteralPath $frameDefLog) {
    $frameDefText = Read-TextWithFallback -Path $frameDefLog
    $a4FrameDefLine = Get-FirstMatchingLine `
      -Text $frameDefText `
      -Pattern "DR_A4_Outline:"
    if ($a4FrameDefLine) {
      Write-Output ("  Current frame definition: {0}" -f $a4FrameDefLine)
    }
  } else {
    Write-Output "  Current frame definition: <frame definition log missing>"
  }

  $prepareProbeLog = Join-Path $WorkDir "swtitle_a4_outline_prepare_probe_260705.txt"
  if (Test-Path -LiteralPath $prepareProbeLog) {
    $prepareProbeText = Read-TextWithFallback -Path $prepareProbeLog
    $prepareResult = Get-FirstMatchingLine `
      -Text $prepareProbeText `
      -Pattern "^Prepare result:"
    $rawWarning = Get-FirstMatchingLine `
      -Text $prepareProbeText `
      -Pattern "raw/effective area ratio|raw-bbox|raw-"
    $afterDefinition = Get-FirstMatchingLine `
      -Text $prepareProbeText `
      -Pattern "^After definition status:"

    if ($prepareResult) {
      Write-Output ("  Installed DR_A4_Outline prepare probe: {0}" -f $prepareResult)
    }
    if ($rawWarning) {
      Write-Output ("  A4 raw-selection warning: {0}" -f $rawWarning)
    }
    if ($afterDefinition) {
      Write-Output ("  A4 definition after unsafe probe: {0}" -f $afterDefinition)
    }
  } else {
    Write-Output "  Installed DR_A4_Outline prepare probe: <missing>"
  }

  $normalizationSummary = @()
  $safeNormalizationStrategies = @()
  foreach ($strategy in @("none", "huge-insert", "direct-outside", "nested-outside", "nested-direct-outside")) {
    $safeStrategy = $strategy -replace '[^A-Za-z0-9_-]', '_'
    $logPath = Join-Path $WorkDir ("swtitle_a4_outline_norm_{0}_260705.txt" -f $safeStrategy)
    if (Test-Path -LiteralPath $logPath) {
      $text = Read-TextWithFallback -Path $logPath
      $safe = Get-FirstRegexValue -Text $text -Pattern "^Normalization safe for A4 frame-only conversion:\s*(yes|no)"
      if (-not $safe) {
        $safe = "unknown"
      }
      $normalizationSummary += ("{0}={1}" -f $strategy, $safe)
      if ($safe -eq "yes") {
        $safeNormalizationStrategies += $strategy
      }
    } else {
      $normalizationSummary += ("{0}=not-run" -f $strategy)
    }
  }
  Write-Output ("  A4 normalization probes: {0}" -f ($normalizationSummary -join ", "))
  if ($safeNormalizationStrategies.Count -gt 0) {
    Write-Output ("  A4 normalization decision: candidate safe probe result found ({0}). Do not promote it directly; inspect the copied-DWG log and then decide whether SWTITLEPREPARE can adopt that definition path." -f ($safeNormalizationStrategies -join ", "))
  } elseif (($normalizationSummary -contains "nested-outside=no") -and ($normalizationSummary -contains "nested-direct-outside=no")) {
    Write-Output "  A4 normalization decision: nested cleanup probes are both unsafe. Next investigation should compare against a real native A4 GMTITLE/frame definition instead of deleting more imported objects."
  } elseif (($normalizationSummary -contains "nested-outside=not-run") -or ($normalizationSummary -contains "nested-direct-outside=not-run")) {
    Write-Output "  A4 normalization decision: nested cleanup comparison is still missing. Run the copied-DWG probe before changing production conversion logic."
  }
  if (($normalizationSummary -contains "nested-outside=not-run") -or ($normalizationSummary -contains "nested-direct-outside=not-run")) {
    $nestedProbeScript = Join-Path $repoRoot "diagnostics\gmtitle-main45\run_a4_outline_normalization_probe.ps1"
    $nestedProbeSource = $script:LatestCadDwg
    if (-not $nestedProbeSource) {
      $nestedProbeSource = $SourceWorkCopyPath
    }
    Write-Output "  Next A4 investigation probe command:"
    Write-Output ("    powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -SourceWorkCopyPath ""{1}"" -Strategies nested-outside,nested-direct-outside -WaitForGstarCADClose" -f $nestedProbeScript, $nestedProbeSource)
    Write-Output "    Note: SourceWorkCopyPath is shown explicitly to avoid ambiguity; the wrapper also uses the latest CAD next-step DWG when SourceWorkCopyPath is omitted."
    if (-not (Test-Path -LiteralPath $nestedProbeSource)) {
      Write-Output "    Warning: the source DWG path above was read from the latest CAD log but does not exist from this shell. Confirm the open CAD DWG path before running."
    }
  }

  if ($script:LatestCadStatusCode -eq "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION") {
    Write-Output "  Interpretation: current CAD still needs SWTITLEPREPARE for live evidence, but known probes expect the installed DR_A4_Outline to fail the strict A4 raw-bbox guard."
    Write-Output "  If SWTITLEPREPARE returns WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE, do not repeat SWTITLECONVERT; continue with the A4 definition strategy investigation."
  }
}

function Write-NativeFrameProgressSummary {
  param([string]$WorkDir)

  $nativeFrameLog = Join-Path $WorkDir "swcad_title_native_frame_check_last.txt"
  if (-not (Test-Path -LiteralPath $nativeFrameLog)) {
    Write-Output "Native frame progress: <native frame check log missing>"
    return
  }

  $item = Get-Item -LiteralPath $nativeFrameLog
  $text = Read-TextWithFallback -Path $nativeFrameLog
  $dwg = Get-FirstRegexValue -Text $text -Pattern "^DWG[^:]*:\s*(.+)$"
  $result = Get-FirstMatchingLine -Text $text -Pattern "WARN_|OK_|FAIL_|SWTITLEVERIFY_FINAL_"
  $completion = Get-FirstMatchingLine -Text $text -Pattern "^A3/A4 native-like"
  $a3NativeLikeCount = [regex]::Matches($text, "sheet=A3,.*native-like=yes").Count
  $a4NativeLikeCount = [regex]::Matches($text, "sheet=A4,.*native-like=yes").Count
  $untrustedCount = [regex]::Matches($text, "native-like=no").Count
  $a4Missing = [regex]::IsMatch($text, "(?m)^\s*-\s*A4\s*$")

  Write-Output "Native frame progress from latest CAD log:"
  Write-Output ("  Path: {0}" -f $nativeFrameLog)
  Write-Output ("  LastWriteTime: {0}" -f $item.LastWriteTime)
  if ($dwg) { Write-Output ("  DWG: {0}" -f $dwg) }
  Write-Output ("  A3 native-like frame/title pairs found: {0}" -f $a3NativeLikeCount)
  Write-Output ("  A4 native-like frame/title pairs found: {0}" -f $a4NativeLikeCount)
  Write-Output ("  A4 target frame still missing: {0}" -f ($(if ($a4Missing) { "yes" } else { "no" })))
  if ($completion) { Write-Output ("  {0}" -f $completion) }
  Write-Output ("  Non-native-like records found by record scan: {0}" -f $untrustedCount)
  if ($result) { Write-Output ("  {0}" -f $result) }

  if ($a3NativeLikeCount -gt 0 -and $untrustedCount -eq 0) {
    Write-Output "  Interpretation: A3 is no longer the main blocker in the latest CAD evidence. DR_A*_Outline frames still select as INSERT/block references; check the paired DR_titlea_3rd title block for the GMTITLE table editor."
  }
  if ($a4Missing) {
    Write-Output "  Interpretation: A4 remains the active blocker. It is frame-only, so the next safe step is DR_A4_Outline definition prepare/validation, not repeating title conversion."
  }
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
Write-LatestCadLogSummary -WorkDir (Join-Path $repoRoot "work")

Write-Output ""
Write-NativeFrameProgressSummary -WorkDir (Join-Path $repoRoot "work")

Write-Output ""
Write-A4FrameOnlyEvidenceSummary -WorkDir (Join-Path $repoRoot "work")

Write-Output ""
Write-Output "Next action:"
if ($existingGstarCAD.Count -gt 0) {
  if ($script:LatestCadRecommendedCommand) {
    Write-Output "  Visible CAD continuation:"
    Write-Output ("    1. Confirm the open GstarCAD drawing matches: {0}" -f $script:LatestCadDwg)
    Write-Output ("    2. Run in GstarCAD: {0}" -f $script:LatestCadRecommendedCommand)
    Write-Output "    3. Run SWTITLESTATUS again and confirm the A4 missing count changes or a new warning explains why it stopped."
    if ($script:LatestCadStatusCode -eq "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION") {
      Write-Output "    4. Do not repeat SWTITLECONVERT before this prepare/status loop. A4 is frame-only and must not receive an extra title block."
    }
    Write-Output ""
    Write-Output "  Hidden suite verification path:"
  }
  Write-Output "    1. Save the visible GstarCAD work-copy DWG."
  Write-Output "    2. Close GstarCAD."
  Write-Output "    3. Run the full hidden suite:"
  Write-Output ("     powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f $suite)
  Write-Output "  Or start the suite in waiting mode first:"
  Write-Output ("     powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -WaitForGstarCADClose" -f $suite)
} else {
  Write-Output "  Run the full hidden suite now:"
  Write-Output ("     powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f $suite)
}

Write-Output ""
Write-Output "Goal-mode reference docs:"
Write-Output ("  Run card: {0}" -f $runCard)
Write-Output ("  Detailed plan: {0}" -f $goalPlan)
Write-Output ""
Write-Output "Goal status: not complete until the hidden suite passes and the actual work-copy reaches SWTITLEVERIFY_FINAL_OK."
