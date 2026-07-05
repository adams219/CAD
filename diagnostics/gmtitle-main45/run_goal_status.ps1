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
$script:LatestCadDwgTrustedForGoal = $false
$script:LatestCadDwgTrustReason = "not evaluated"
$script:A4PrepareProbeUnsafe = $false
$script:A4NestedProbeMissing = $false
$script:A4NestedProbeUnsafe = $false
$script:A4NormalizationCandidateSafe = $false
$script:A4NativeExemplarResult = $null
$script:A4NativeExemplarMinorOutside = $false
$script:A4PrepareProbeReadyWithNativeOutside = $false
$script:A4FrameOnlyConvertProbePassed = $false
$script:SuiteLastRunResult = $null
$script:SuiteLastRunGenerated = $null
$script:DirectWorkcopyProbeTrusted = $false
$script:DirectWorkcopyStatusCode = $null
$script:DirectWorkcopyVerifyStatus = $null
$script:DirectWorkcopyNextFrame = $null
$script:DirectWorkcopyNextTitle = $null
$script:DirectWorkcopyTargetTitleCount = $null
$script:DirectWorkcopyTargetFrameCount = $null

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

function Get-AllRegexValues {
  param(
    [string]$Text,
    [string]$Pattern
  )

  $values = @()
  foreach ($match in [regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
    if ($match.Groups.Count -gt 1) {
      $values += $match.Groups[1].Value.Trim()
    }
  }
  return $values
}

function Write-HiddenSuiteLastRunSummary {
  param([string]$WorkDir)

  $suiteLog = Join-Path $WorkDir "main56_verification_suite_last_run.txt"
  Write-Output "Hidden verification suite last run:"
  if (-not (Test-Path -LiteralPath $suiteLog)) {
    Write-Output "  Result: <missing>"
    Write-Output "  Meaning: no latest suite evidence is available; rely on static preflight and current work-copy status before changing CAD data."
    return
  }

  $item = Get-Item -LiteralPath $suiteLog
  $text = Read-TextWithFallback -Path $suiteLog
  $generated = Get-FirstRegexValue -Text $text -Pattern "^Generated:\s*(.+)$"
  $resultValues = @(Get-AllRegexValues -Text $text -Pattern "^Result:\s*(.+)$")
  $result = if ($resultValues.Count -gt 0) { $resultValues[$resultValues.Count - 1] } else { "<unknown>" }
  $failure = Get-FirstRegexValue -Text $text -Pattern "^Failure:\s*(.+)$"
  $failureCommand = Get-FirstRegexValue -Text $text -Pattern "^Failure command:\s*(.+)$"
  $statusAfterStatus = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-status:\s*(\S+)"
  $statusAfterVerify = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-verify:\s*(\S+)"

  $script:SuiteLastRunResult = $result
  $script:SuiteLastRunGenerated = $generated

  Write-Output ("  Path: {0}" -f $suiteLog)
  Write-Output ("  LastWriteTime: {0}" -f $item.LastWriteTime)
  if ($generated) { Write-Output ("  Generated: {0}" -f $generated) }
  Write-Output ("  Result: {0}" -f $result)
  if ($failure) { Write-Output ("  Failure: {0}" -f $failure) }
  if ($failureCommand) { Write-Output ("  Failure command: {0}" -f $failureCommand) }
  if ($statusAfterStatus) { Write-Output ("  Actual work-copy status in suite: {0}" -f $statusAfterStatus) }
  if ($statusAfterVerify) { Write-Output ("  Actual work-copy verify in suite: {0}" -f $statusAfterVerify) }

  if ($result -eq "PASS") {
    Write-Output "  Meaning: automation/guard probes passed; this is not proof that the real work DWG finished conversion."
  } elseif ($result -eq "FAILED_BEFORE_PASS") {
    Write-Output "  Meaning: the suite stopped before final PASS; inspect the failure above before trusting automation changes."
  } else {
    Write-Output "  Meaning: suite evidence is incomplete or not a final PASS."
  }
}

function Write-FinalCompletionGateSummary {
  param([string]$WorkDir)

  $gateLog = Join-Path $WorkDir "swtitle_final_completion_gate_status.txt"
  Write-Output "Final completion gate last run:"
  if (-not (Test-Path -LiteralPath $gateLog)) {
    Write-Output "  Result: <missing>"
    Write-Output "  Meaning: no saved work-copy completion gate evidence is available yet."
    return
  }

  $item = Get-Item -LiteralPath $gateLog
  $text = Read-TextWithFallback -Path $gateLog
  $loadedVersion = Get-FirstRegexValue -Text $text -Pattern "^Loaded version:\s*(\S+)"
  $statusAfterStatus = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-status:\s*(\S+)"
  $statusAfterVerify = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-verify:\s*(\S+)"
  $sourceTitleCount = Get-FirstRegexValue -Text $text -Pattern "^\s*source-title-count:\s*(\d+)"
  $sourceFrameCount = Get-FirstRegexValue -Text $text -Pattern "^\s*source-frame-count:\s*(\d+)"
  $frameOnlyCount = Get-FirstRegexValue -Text $text -Pattern "^\s*frame-only-count:\s*(\d+)"
  $targetTitleCount = Get-FirstRegexValue -Text $text -Pattern "^\s*target-title-count:\s*(\d+)"
  $targetFrameCount = Get-FirstRegexValue -Text $text -Pattern "^\s*target-frame-count:\s*(\d+)"
  $nextFrame = Get-FirstRegexValue -Text $text -Pattern "^\s*next-bootstrap-frame:\s*(\S+)"
  $nextTitle = Get-FirstRegexValue -Text $text -Pattern "^\s*next-bootstrap-title:\s*(\S+)"
  $dbmodAfter = Get-FirstRegexValue -Text $text -Pattern "^\s*dbmod-after-commands:\s*(\d+)"
  $runtimeDone = Get-FirstRegexValue -Text $text -Pattern "^Runtime check completed:\s*(\S+)"
  $gateResult = if ($statusAfterVerify -eq "SWTITLEVERIFY_FINAL_OK") { "PASS" } elseif ($statusAfterVerify) { "FAIL" } else { "UNKNOWN" }

  Write-Output ("  Path: {0}" -f $gateLog)
  Write-Output ("  LastWriteTime: {0}" -f $item.LastWriteTime)
  if ($loadedVersion) { Write-Output ("  loaded-version: {0}" -f $loadedVersion) }
  Write-Output ("  Result: {0}" -f $gateResult)
  if ($statusAfterStatus) { Write-Output ("  status-after-status: {0}" -f $statusAfterStatus) }
  if ($statusAfterVerify) { Write-Output ("  status-after-verify: {0}" -f $statusAfterVerify) }
  if ($sourceTitleCount -or $sourceFrameCount -or $frameOnlyCount) {
    Write-Output ("  source counts: source-title-count={0}, source-frame-count={1}, frame-only-count={2}" -f $sourceTitleCount, $sourceFrameCount, $frameOnlyCount)
  }
  if ($targetTitleCount -or $targetFrameCount) {
    Write-Output ("  target counts: target-title-count={0}, target-frame-count={1}" -f $targetTitleCount, $targetFrameCount)
  }
  if ($nextFrame -or $nextTitle) {
    Write-Output ("  next native GMTITLE: frame={0}, title={1}" -f $nextFrame, $nextTitle)
  }
  if ($dbmodAfter) { Write-Output ("  dbmod-after-commands: {0}" -f $dbmodAfter) }
  if ($runtimeDone) { Write-Output ("  Runtime check completed: {0}" -f $runtimeDone) }

  if ($gateResult -eq "PASS") {
    Write-Output "  Meaning: automated completion evidence passed; representative A2/A3 title-block double-click checks are still required."
  } else {
    Write-Output "  Meaning: real work-copy completion evidence is still missing; continue from SWTITLESTATUS/SWTITLECONVERTNEXT."
  }
}

function Test-PathUnderDirectoryString {
  param(
    [string]$Path,
    [string]$Directory
  )

  if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($Directory)) {
    return $false
  }

  try {
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullDirectory = [System.IO.Path]::GetFullPath($Directory)
    if (-not $fullDirectory.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
      $fullDirectory += [System.IO.Path]::DirectorySeparatorChar
    }
    return $fullPath.StartsWith($fullDirectory, [System.StringComparison]::OrdinalIgnoreCase)
  } catch {
    return $false
  }
}

function Get-GoalCadDwgTrustInfo {
  param(
    [string]$DwgPath,
    [string]$WorkDir
  )

  if ([string]::IsNullOrWhiteSpace($DwgPath)) {
    return [pscustomobject]@{
      Trusted = $false
      Reason = "latest log has no DWG path"
    }
  }

  if (-not (Test-PathUnderDirectoryString -Path $DwgPath -Directory $WorkDir)) {
    return [pscustomobject]@{
      Trusted = $false
      Reason = "DWG is outside the work folder"
    }
  }

  $leaf = [System.IO.Path]::GetFileName($DwgPath)
  if ($leaf -match "(?i)(^swtitle_|probe|compare|scratch|visible_gmtitle)") {
    return [pscustomobject]@{
      Trusted = $false
      Reason = "DWG name looks like a scratch/probe/compare artifact"
    }
  }

  return [pscustomobject]@{
    Trusted = $true
    Reason = "DWG is a work-folder conversion candidate"
  }
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
    $recommended = "SWTITLECONVERTNEXT"
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

  $trustInfo = Get-GoalCadDwgTrustInfo -DwgPath $dwg -WorkDir $WorkDir
  $script:LatestCadDwgTrustedForGoal = $trustInfo.Trusted
  $script:LatestCadDwgTrustReason = $trustInfo.Reason
  Write-Output ("  Goal-log trust: {0} ({1})" -f ($(if ($trustInfo.Trusted) { "yes" } else { "no" }), $trustInfo.Reason))
  if (-not $trustInfo.Trusted) {
    Write-Output "  Warning: latest CAD log is ignored for goal next-action selection. Re-run SWTITLESTATUS on the work-copy before following visible-CAD recommendations."
  }

  $script:LatestCadDwg = $dwg
  $script:LatestCadStatusCode = $statusCode
  $script:LatestCadRecommendedCommand = $recommended
}

function Write-DirectActualWorkcopyProbeSummary {
  param(
    [string]$WorkDir,
    [string]$SourceWorkCopyPath
  )

  $candidateLogs = @(
    (Join-Path $WorkDir "swtitle_actual_workcopy_direct_status_260705.txt"),
    (Join-Path $WorkDir "swtitle_actual_workcopy_status_main56_diagnostics.txt")
  )
  $logPath = $candidateLogs | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $logPath) {
    Write-Output "Direct actual work-copy probe: <missing>"
    return
  }

  $item = Get-Item -LiteralPath $logPath
  $text = Read-TextWithFallback -Path $logPath
  $dwg = Get-FirstRegexValue -Text $text -Pattern "^DWG[^:]*:\s*(.+)$"
  $loadedVersion = Get-FirstRegexValue -Text $text -Pattern "^Loaded version:\s*(\S+)"
  $expectedVersion = Get-FirstRegexValue -Text $text -Pattern "^Expected version:\s*(\S+)"
  $statusAfterStatus = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-status:\s*(\S+)"
  $statusAfterVerify = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-verify:\s*(\S+)"
  $manualForecastFound = Get-FirstRegexValue -Text $text -Pattern "^\s*manual-forecast-log-note-found:\s*(yes|no)"
  $firstNativeSelectionFound = Get-FirstRegexValue -Text $text -Pattern "^\s*first-native-selection-log-note-found:\s*(yes|no)"
  $nextFrame = Get-FirstRegexValue -Text $text -Pattern "^\s*next-bootstrap-frame:\s*(\S+)"
  $nextTitle = Get-FirstRegexValue -Text $text -Pattern "^\s*next-bootstrap-title:\s*(\S+)"
  $nextMissingFrame = Get-FirstRegexValue -Text $text -Pattern "^\s*next-missing-native-frame:\s*(\S+)"
  $nextMissingTitle = Get-FirstRegexValue -Text $text -Pattern "^\s*next-missing-native-title:\s*(\S+)"
  $nextMissingRole = Get-FirstRegexValue -Text $text -Pattern "^\s*next-missing-native-role:\s*(\S+)"
  $sourceTitleCount = Get-FirstRegexValue -Text $text -Pattern "^\s*source-title-count:\s*(\d+)"
  $sourceFrameCount = Get-FirstRegexValue -Text $text -Pattern "^\s*source-frame-count:\s*(\d+)"
  $frameOnlyCount = Get-FirstRegexValue -Text $text -Pattern "^\s*frame-only-count:\s*(\d+)"
  $targetTitleCount = Get-FirstRegexValue -Text $text -Pattern "^\s*target-title-count:\s*(\d+)"
  $targetFrameCount = Get-FirstRegexValue -Text $text -Pattern "^\s*target-frame-count:\s*(\d+)"

  $trusted = $false
  if ($dwg) {
    try {
      $trusted = (
        [System.IO.Path]::GetFullPath($dwg).Equals(
          [System.IO.Path]::GetFullPath($SourceWorkCopyPath),
          [System.StringComparison]::OrdinalIgnoreCase
        )
      )
    } catch {
      $trusted = $false
    }
  }

  Write-Output "Direct actual work-copy probe:"
  Write-Output ("  Path: {0}" -f $logPath)
  Write-Output ("  LastWriteTime: {0}" -f $item.LastWriteTime)
  if ($dwg) { Write-Output ("  DWG: {0}" -f $dwg) }
  Write-Output ("  Trusted for goal: {0}" -f ($(if ($trusted) { "yes" } else { "no" })))
  if ($loadedVersion) { Write-Output ("  loaded-version: {0}" -f $loadedVersion) }
  if ($expectedVersion) { Write-Output ("  expected-version: {0}" -f $expectedVersion) }
  if ($statusAfterStatus) { Write-Output ("  status-after-status: {0}" -f $statusAfterStatus) }
  if ($statusAfterVerify) { Write-Output ("  status-after-verify: {0}" -f $statusAfterVerify) }
  if ($firstNativeSelectionFound) { Write-Output ("  first-native-selection-log-note-found: {0}" -f $firstNativeSelectionFound) }
  if ($manualForecastFound) { Write-Output ("  manual-forecast-log-note-found: {0}" -f $manualForecastFound) }
  if ($sourceTitleCount) { Write-Output ("  source-title-count: {0}" -f $sourceTitleCount) }
  if ($sourceFrameCount) { Write-Output ("  source-frame-count: {0}" -f $sourceFrameCount) }
  if ($frameOnlyCount) { Write-Output ("  frame-only-count: {0}" -f $frameOnlyCount) }
  if ($targetTitleCount) { Write-Output ("  target-title-count: {0}" -f $targetTitleCount) }
  if ($targetFrameCount) { Write-Output ("  target-frame-count: {0}" -f $targetFrameCount) }
  if ($nextFrame) { Write-Output ("  next-bootstrap-frame: {0}" -f $nextFrame) }
  if ($nextTitle) { Write-Output ("  next-bootstrap-title: {0}" -f $nextTitle) }
  if ($nextMissingFrame) { Write-Output ("  next-missing-native-frame: {0}" -f $nextMissingFrame) }
  if ($nextMissingTitle) { Write-Output ("  next-missing-native-title: {0}" -f $nextMissingTitle) }
  if ($nextMissingRole) { Write-Output ("  next-missing-native-role: {0}" -f $nextMissingRole) }

  if ($trusted) {
    $script:DirectWorkcopyProbeTrusted = $true
    $script:DirectWorkcopyStatusCode = $statusAfterStatus
    $script:DirectWorkcopyVerifyStatus = $statusAfterVerify
    $script:DirectWorkcopyNextFrame = $nextFrame
    $script:DirectWorkcopyNextTitle = $nextTitle
    $script:DirectWorkcopyTargetTitleCount = $targetTitleCount
    $script:DirectWorkcopyTargetFrameCount = $targetFrameCount
  }
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
      if ($prepareResult -match "WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE") {
        $script:A4PrepareProbeUnsafe = $true
      }
      if ($prepareResult -match "OK_A4_FRAME_ONLY_OUTLINE_DEFINITION_IMPORTED") {
        Write-Output "  Installed DR_A4_Outline prepare probe: imported definition accepted for A4 frame-only readiness."
      }
    }
    if ($rawWarning) {
      Write-Output ("  A4 raw-selection warning: {0}" -f $rawWarning)
    }
    if ($afterDefinition) {
      Write-Output ("  A4 definition after prepare probe: {0}" -f $afterDefinition)
      if ($afterDefinition -match "ready-native-outside-markers") {
        $script:A4PrepareProbeReadyWithNativeOutside = $true
        Write-Output "  A4 definition readiness: ready with official native outside markers."
      }
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
    $script:A4NormalizationCandidateSafe = $true
    Write-Output ("  A4 normalization decision: candidate safe probe result found ({0}). Do not promote it directly; inspect the copied-DWG log and then decide whether SWTITLEPREPARE can adopt that definition path." -f ($safeNormalizationStrategies -join ", "))
  } elseif (($normalizationSummary -contains "nested-outside=no") -and ($normalizationSummary -contains "nested-direct-outside=no")) {
    $script:A4NestedProbeUnsafe = $true
    if ($script:A4PrepareProbeReadyWithNativeOutside) {
      Write-Output "  A4 normalization decision: historical nested cleanup probes are both unsafe, but this is superseded by the official native outside marker policy."
    } else {
      Write-Output "  A4 normalization decision: nested cleanup probes are both unsafe. Next investigation should compare against a real native A4 GMTITLE/frame definition instead of deleting more imported objects."
    }
  } elseif (($normalizationSummary -contains "nested-outside=not-run") -or ($normalizationSummary -contains "nested-direct-outside=not-run")) {
    $script:A4NestedProbeMissing = $true
    Write-Output "  A4 normalization decision: nested cleanup comparison is still missing. Run the copied-DWG probe before changing production conversion logic."
  }
  if (($normalizationSummary -contains "nested-outside=not-run") -or ($normalizationSummary -contains "nested-direct-outside=not-run")) {
    $nestedProbeScript = Join-Path $repoRoot "diagnostics\gmtitle-main45\run_a4_outline_normalization_probe.ps1"
    $nestedProbeSource = $script:LatestCadDwg
    if ((-not $script:LatestCadDwgTrustedForGoal) -or (-not $nestedProbeSource)) {
      $nestedProbeSource = $SourceWorkCopyPath
    }
    Write-Output "  Next A4 investigation probe command:"
    Write-Output ("    powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -SourceWorkCopyPath ""{1}"" -Strategies nested-outside,nested-direct-outside -WaitForGstarCADClose" -f $nestedProbeScript, $nestedProbeSource)
    Write-Output "    Note: SourceWorkCopyPath is shown explicitly to avoid ambiguity; the wrapper also uses the latest CAD next-step DWG when SourceWorkCopyPath is omitted."
    if (-not (Test-Path -LiteralPath $nestedProbeSource)) {
      Write-Output "    Warning: the source DWG path above was read from the latest CAD log but does not exist from this shell. Confirm the open CAD DWG path before running."
    }
  }

  $scratchNativeA4Log = Join-Path $WorkDir "swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt"
  $defaultNativeExemplarLog = Join-Path $WorkDir "swtitle_a4_native_exemplar_probe_260705.txt"
  $nativeExemplarLog = $defaultNativeExemplarLog
  $nativeExemplarLogKind = "default work-copy/suite"
  if (Test-Path -LiteralPath $scratchNativeA4Log) {
    $nativeExemplarLog = $scratchNativeA4Log
    $nativeExemplarLogKind = "clean scratch"
  }
  if (Test-Path -LiteralPath $nativeExemplarLog) {
    $nativeText = Read-TextWithFallback -Path $nativeExemplarLog
    $nativeResult = Get-FirstRegexValue -Text $nativeText -Pattern "^Result:\s*(\S+)"
    $minorOutside = Get-FirstRegexValue -Text $nativeText -Pattern "^Definition minor native outside markers:\s*(yes|no)"
    $nativePair = Get-FirstMatchingLine -Text $nativeText -Pattern "^Native GMTITLE A4 pair evidence:"
    $strictLine = Get-FirstMatchingLine -Text $nativeText -Pattern "^Definition strict A4 warning:"
    $rawSelectionLine = Get-FirstMatchingLine -Text $nativeText -Pattern "^Definition test insert raw selection warning:"

    if ($nativeResult) {
      $script:A4NativeExemplarResult = $nativeResult
      Write-Output ("  A4 native exemplar probe result ({0}): {1}" -f $nativeExemplarLogKind, $nativeResult)
      Write-Output ("  A4 native exemplar log: {0}" -f $nativeExemplarLog)
    }
    if ($minorOutside) {
      $script:A4NativeExemplarMinorOutside = ($minorOutside -eq "yes")
      Write-Output ("  A4 native exemplar minor outside markers: {0}" -f $minorOutside)
    }
    if ($nativePair) {
      Write-Output ("  A4 native exemplar pair evidence: {0}" -f $nativePair)
    }
    if ($strictLine) {
      Write-Output ("  A4 native exemplar strict warning: {0}" -f $strictLine)
    }
    if ($rawSelectionLine) {
      Write-Output ("  A4 native exemplar raw-selection warning: {0}" -f $rawSelectionLine)
    }
    if ($script:A4NativeExemplarMinorOutside) {
      if ($script:A4PrepareProbeReadyWithNativeOutside) {
        Write-Output "  A4 native exemplar decision: official native outside markers are tolerated when effective A4 geometry and raw-selection checks pass."
      } else {
        Write-Output "  A4 native exemplar decision: native A4 itself carries small outside marker geometry. Do not treat exact (0,0)-(210,297) raw bbox mismatch as proof of contamination by itself; production still needs an explicit keep/crop/tolerate decision before changing A4 frame-only conversion."
      }
    }
  } else {
    Write-Output "  A4 native exemplar probe result: <not-run>"
  }

  $convertProbeLogs = @(
    (Join-Path $WorkDir "swtitle_a4_outline_convert_probe_main56_default.txt"),
    (Join-Path $WorkDir "swtitle_a4_outline_convert_probe_260705.txt")
  )
  $convertProbeLog = $convertProbeLogs | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if ($convertProbeLog) {
    $convertText = Read-TextWithFallback -Path $convertProbeLog
    $convertResult = Get-FirstMatchingLine -Text $convertText -Pattern "^Convert result:"
    $afterFrameOnly = Get-FirstMatchingLine -Text $convertText -Pattern "^After frame-only-count:"
    $afterTargetTitle = Get-FirstMatchingLine -Text $convertText -Pattern "^After target title count:"
    $afterA4Frame = Get-FirstMatchingLine -Text $convertText -Pattern "^After DR_A4_Outline target frame count:"

    if ($convertResult) {
      Write-Output ("  A4 frame-only convert probe: {0}" -f $convertResult)
      Write-Output ("  A4 frame-only convert log: {0}" -f $convertProbeLog)
    }
    if ($afterFrameOnly) {
      Write-Output ("  A4 frame-only convert probe: {0}" -f $afterFrameOnly)
    }
    if ($afterTargetTitle) {
      Write-Output ("  A4 frame-only convert probe: {0}" -f $afterTargetTitle)
    }
    if ($afterA4Frame) {
      Write-Output ("  A4 frame-only convert probe: {0}" -f $afterA4Frame)
    }
    if (
      ($convertText -match "Convert result: OK status=FINALIZED_A4_FRAME_ONLY_OUTLINE_TRANSFER") -and
      ($convertText -match "(?m)^After frame-only-count:\s*1") -and
      ($convertText -match "(?m)^After target title count:\s*0") -and
      ($convertText -match "(?m)^After DR_A4_Outline target frame count:\s*1")
    ) {
      $script:A4FrameOnlyConvertProbePassed = $true
      Write-Output "  A4 frame-only convert decision: verified; one source A4 frame-only sheet becomes DR_A4_Outline and no DR_titlea_3rd is created."
    }
  } else {
    Write-Output "  A4 frame-only convert probe: <not-run>"
  }

  if ($script:LatestCadStatusCode -eq "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION") {
    if ($script:A4PrepareProbeUnsafe -and $script:A4NestedProbeMissing) {
      Write-Output "  Interpretation: the current live state still reports SWTITLEPREPARE, but the copied-DWG prepare probe already shows the installed DR_A4_Outline path is expected to fail the strict A4 raw-bbox guard."
      Write-Output "  If SWTITLEPREPARE has already been tried in the open CAD and SWTITLESTATUS still reports this same state, do not keep looping CAD commands. Save/close GstarCAD and run the nested A4 normalization probe."
    } else {
      Write-Output "  Interpretation: current CAD still needs SWTITLEPREPARE for live evidence, but known probes expect the installed DR_A4_Outline to fail the strict A4 raw-bbox guard."
      Write-Output "  If SWTITLEPREPARE returns WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE, do not repeat SWTITLECONVERT; continue with the A4 definition strategy investigation."
    }
  }
}

function Write-HiddenScriptSmokeSummary {
  param([string]$WorkDir)

  $smokeLog = Join-Path $WorkDir "swtitle_hidden_script_smoke_probe.txt"
  Write-Output "GstarCAD /b script smoke probe:"
  if (-not (Test-Path -LiteralPath $smokeLog)) {
    Write-Output "  Result: not proven or last run failed before log creation"
    Write-Output "  Meaning: GstarCAD /b probes may be unavailable with the current window style; do not treat loader/probe missing logs as GMTITLE logic failures until the smoke probe passes."
    Write-Output "  Note: this workstation previously ran SCR scripts with WindowStyle=Minimized after WindowStyle=Hidden produced no log."
    Write-Output ("  Probe command: powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -WindowStyle Minimized" -f (Join-Path $diagnosticsDir "run_hidden_script_smoke_probe.ps1"))
    return
  }

  $item = Get-Item -LiteralPath $smokeLog
  $text = Read-TextWithFallback -Path $smokeLog
  Write-Output ("  Path: {0}" -f $smokeLog)
  Write-Output ("  LastWriteTime: {0}" -f $item.LastWriteTime)
  if ($text -match "HIDDEN_SCRIPT_SMOKE_OK") {
    Write-Output "  Result: PASS"
  } else {
    Write-Output "  Result: log exists but PASS marker is missing"
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
  $trustInfo = Get-GoalCadDwgTrustInfo -DwgPath $dwg -WorkDir $WorkDir
  $result = Get-FirstMatchingLine -Text $text -Pattern "WARN_|OK_|FAIL_|SWTITLEVERIFY_FINAL_"
  $completion = Get-FirstMatchingLine -Text $text -Pattern "^A3/A4 native-like"
  $a3NativeLikeCount = [regex]::Matches($text, "sheet=A3,.*native-like=yes").Count
  $a4NativeLikeCount = [regex]::Matches($text, "sheet=A4,.*native-like=yes").Count
  $untrustedCount = [regex]::Matches($text, "native-like=no").Count
  $a4Missing = [regex]::IsMatch($text, "(?m)^\s*-\s*A4\s*$")

  Write-Output "Native frame progress log:"
  Write-Output ("  Path: {0}" -f $nativeFrameLog)
  Write-Output ("  LastWriteTime: {0}" -f $item.LastWriteTime)
  if ($dwg) { Write-Output ("  DWG: {0}" -f $dwg) }
  Write-Output ("  Trusted for goal: {0} ({1})" -f ($(if ($trustInfo.Trusted) { "yes" } else { "no" }), $trustInfo.Reason))
  Write-Output ("  A3 native-like frame/title pairs found: {0}" -f $a3NativeLikeCount)
  Write-Output ("  A4 native-like frame/title pairs found: {0}" -f $a4NativeLikeCount)
  Write-Output ("  A4 target frame still missing: {0}" -f ($(if ($a4Missing) { "yes" } else { "no" })))
  if ($completion) { Write-Output ("  {0}" -f $completion) }
  Write-Output ("  Non-native-like records found by record scan: {0}" -f $untrustedCount)
  if ($result) { Write-Output ("  {0}" -f $result) }

  if (-not $trustInfo.Trusted) {
    Write-Output "  Interpretation: ignored for goal next-action selection because this native-frame log belongs to a scratch/probe/compare DWG."
    Write-Output "  Use the Direct actual work-copy probe and the real work-copy SWTITLESTATUS log for the next CAD action."
    return
  }

  if ($a3NativeLikeCount -gt 0 -and $untrustedCount -eq 0) {
    Write-Output "  Interpretation: A3 is no longer the main blocker in the latest CAD evidence. DR_A*_Outline frames still select as INSERT/block references; check the paired DR_titlea_3rd title block for the GMTITLE table editor."
  }
  if (
    $script:DirectWorkcopyProbeTrusted -and
    ($script:DirectWorkcopyStatusCode -eq "NEXT_CREATE_FIRST_NATIVE_GMTITLE") -and
    ($script:DirectWorkcopyTargetTitleCount -eq "0") -and
    ($script:DirectWorkcopyTargetFrameCount -eq "0")
  ) {
    Write-Output "  Interpretation: not an A4 blocker yet. The trusted direct work-copy probe still has target title/frame counts 0/0, so the next real action is the first native GMTITLE, not A4 frame-only cleanup."
    return
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
Write-HiddenScriptSmokeSummary -WorkDir (Join-Path $repoRoot "work")

Write-Output ""
Write-HiddenSuiteLastRunSummary -WorkDir (Join-Path $repoRoot "work")

Write-Output ""
Write-FinalCompletionGateSummary -WorkDir (Join-Path $repoRoot "work")

Write-Output ""
Write-LatestCadLogSummary -WorkDir (Join-Path $repoRoot "work")

Write-Output ""
Write-DirectActualWorkcopyProbeSummary -WorkDir (Join-Path $repoRoot "work") -SourceWorkCopyPath $SourceWorkCopyPath

Write-Output ""
Write-NativeFrameProgressSummary -WorkDir (Join-Path $repoRoot "work")

Write-Output ""
Write-A4FrameOnlyEvidenceSummary -WorkDir (Join-Path $repoRoot "work")

Write-Output ""
Write-Output "다음 작업:"
$a4InvestigationPreferred = (
  (
    ($script:LatestCadDwgTrustedForGoal -and $script:LatestCadStatusCode -eq "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION") -or
    (-not $script:LatestCadDwgTrustedForGoal)
  ) -and
  $script:A4PrepareProbeUnsafe -and
  $script:A4NestedProbeMissing
)
$a4CandidateSafeNeedsReview = (
  (
    ($script:LatestCadDwgTrustedForGoal -and $script:LatestCadStatusCode -eq "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION") -or
    (-not $script:LatestCadDwgTrustedForGoal)
  ) -and
  $script:A4NormalizationCandidateSafe
)
$a4NativeA4ComparisonNeeded = (
  (
    ($script:LatestCadDwgTrustedForGoal -and $script:LatestCadStatusCode -eq "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION") -or
    (-not $script:LatestCadDwgTrustedForGoal)
  ) -and
  $script:A4PrepareProbeUnsafe -and
  $script:A4NestedProbeUnsafe
)
$a4NativeOutsideMarkerDecisionNeeded = (
  ($script:A4NativeExemplarResult -eq "A4_NATIVE_EXEMPLAR_READY_WITH_NATIVE_OUTSIDE_MARKERS") -and
  (-not $script:A4PrepareProbeReadyWithNativeOutside)
)
$a4NativeOutsideMarkerPolicyReady = (
  ($script:A4NativeExemplarResult -eq "A4_NATIVE_EXEMPLAR_READY_WITH_NATIVE_OUTSIDE_MARKERS") -and
  $script:A4PrepareProbeReadyWithNativeOutside
)
$a4FrameOnlyProductionPathVerified = (
  $a4NativeOutsideMarkerPolicyReady -and
  $script:A4FrameOnlyConvertProbePassed
)
$nestedProbeScript = Join-Path $repoRoot "diagnostics\gmtitle-main45\run_a4_outline_normalization_probe.ps1"
$nestedProbeSource = $script:LatestCadDwg
if ((-not $script:LatestCadDwgTrustedForGoal) -or (-not $nestedProbeSource)) {
  $nestedProbeSource = $SourceWorkCopyPath
}
$scratchNativeA4Path = Join-Path $repoRoot "work\scratch_native_a4_clean_260705.dwg"
$scratchNativeA4Log = Join-Path $repoRoot "work\swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt"
$scratchNativeA4Exists = Test-Path -LiteralPath $scratchNativeA4Path
if ($existingGstarCAD.Count -gt 0) {
  if ($a4FrameOnlyProductionPathVerified) {
    Write-Output "  A4 native 바깥 마커 허용 정책과 frame-only 변환 경로는 검증됨:"
    Write-Output "    1. A4 scratch probe에서 공식 작은 바깥 마커를 가진 실제 native GMTITLE 쌍을 확인했습니다."
    Write-Output "    2. SWTITLEPREPARE는 형상/raw-selection 검사가 통과하면 이 정의를 ready-native-outside-markers로 허용합니다."
    Write-Output "    3. A4 frame-only convert probe는 DR_titlea_3rd 제목블록 없이 DR_A4_Outline 도면틀 1개만 마무리했습니다."
    if ($script:DirectWorkcopyProbeTrusted -and $script:DirectWorkcopyStatusCode) {
      Write-Output ("    4. 실제 작업복사본 direct probe의 다음 상태: {0}" -f $script:DirectWorkcopyStatusCode)
      if ($script:DirectWorkcopyStatusCode -eq "NEXT_CREATE_FIRST_NATIVE_GMTITLE") {
        Write-Output "    5. 열린 CAD에서 SWTITLESTATUS로 현재 활성 DWG와 다음 상태를 먼저 확인하세요."
        Write-Output ("    6. 상태가 그대로면 SWTITLECONVERTNEXT를 실행하고 첫 native GMTITLE을 {0} / {1}로 만드세요." -f $script:DirectWorkcopyNextFrame, $script:DirectWorkcopyNextTitle)
        Write-Output "       수동 응답을 직접 고르고 싶을 때만 SWTITLECONVERT를 사용하세요."
      } else {
        Write-Output "    5. 열린 CAD에서는 SWTITLESTATUS가 안내하는 4단계 흐름의 다음 작업만 따르세요."
      }
    } else {
      Write-Output "    4. 다음 열린 CAD 작업은 실제 작업복사본에서 SWTITLESTATUS부터 4단계 흐름으로 돌아가세요."
    }
    Write-Output ""
    Write-Output "  Hidden suite verification path only if you changed code again:"
  } elseif ($a4NativeOutsideMarkerPolicyReady) {
    Write-Output "  A4 native outside-marker policy is implemented:"
    Write-Output "    1. The focused A4 scratch probe found a real native GMTITLE pair with official small outside markers."
    Write-Output "    2. SWTITLEPREPARE now accepts that definition as ready-native-outside-markers when geometry/raw-selection checks pass."
    Write-Output "    3. Run the focused A4 frame-only convert probe or the full hidden suite before using this on the real work-copy."
    Write-Output "    4. Production A4 frame-only must still not create an extra DR_titlea_3rd."
    Write-Output ""
    Write-Output "  Hidden suite verification path:"
  } elseif ($a4NativeOutsideMarkerDecisionNeeded) {
    Write-Output "  A4 native outside-marker decision:"
    Write-Output "    1. The focused A4 scratch probe found a real native GMTITLE pair, but native DR_A4_Outline itself has small geometry outside (0,0)-(210,297)."
    Write-Output "    2. Do not keep creating more scratch A4 sheets; the next implementation decision is whether production A4 frame-only should tolerate, crop, or preserve those official native outside markers."
    Write-Output "    3. Because production A4 source is frame-only, keep the rule that it must not receive an extra DR_titlea_3rd."
    Write-Output "    4. After code changes, rerun the focused A4 probe and the full hidden suite."
    Write-Output ""
    Write-Output "  Hidden suite verification path after A4 production code changes:"
  } elseif ($a4CandidateSafeNeedsReview) {
    Write-Output "  A4 normalization candidate review:"
    Write-Output "    1. Inspect the copied-DWG nested A4 normalization probe log that reported safe=yes."
    Write-Output "    2. Do not run more CAD conversion commands until that strategy is promoted into SWTITLEPREPARE/SWTITLECONVERT production logic."
    Write-Output "    3. After code changes, save/close GstarCAD and run the focused A4 probe plus hidden suite."
    Write-Output ""
    Write-Output "  Hidden suite verification path after A4 production code changes:"
  } elseif ($a4NativeA4ComparisonNeeded) {
    Write-Output "  A4 native comparison investigation:"
    Write-Output "    1. Do not repeat SWTITLEPREPARE/SWTITLECONVERT; the installed outline and nested cleanup probes are both unsafe."
    Write-Output "    2. Save/close GstarCAD before hidden probes."
    Write-Output "    3. Create a separate scratch DWG with one real native A4 GMTITLE result, then compare its DR_A4_Outline definition."
    if ($scratchNativeA4Exists) {
      Write-Output ("       Saved clean gcadiso.dwt scratch from 2026-07-05 CAD test: {0}" -f $scratchNativeA4Path)
    }
    Write-Output "    4. Scratch only: the native A4 sample may include DR_titlea_3rd for comparison; production A4 frame-only must still not receive a new title block."
    Write-Output "    5. If direct GMTITLE only asks for an insertion point, cancel it; that is the current/default insertion flow, not proof of DR_A4_Outline selection."
    Write-Output "    6. If DR_A4_Outline / DR_titlea_3rd selection ends with a frame creation error and DR_titlea_3rd inserts=0, treat that scratch as failed evidence."
    Write-Output "    7. Scratch READY requires both 'Native GMTITLE A4 pair evidence: yes' and 'Result: A4_NATIVE_EXEMPLAR_READY_FOR_COMPARISON'."
    Write-Output "    8. If the probe reports A4_NATIVE_EXEMPLAR_MISSING_NATIVE_PAIR, the scratch has a frame but not a proven native GMTITLE pair."
    Write-Output ("    9. If you suspect a stored paper/title setting exists, run: powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $repoRoot "diagnostics\gmtitle-main45\run_gmtitle_selection_config_probe.ps1"))
    if ($scratchNativeA4Exists) {
      Write-Output ("    10. After closing GstarCAD, run: powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -SourceWorkCopyPath ""{1}"" -LogPath ""{2}"" -WaitForGstarCADClose" -f (Join-Path $repoRoot "diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1"), $scratchNativeA4Path, $scratchNativeA4Log)
    } else {
      Write-Output ("    10. After saving that scratch DWG, run: powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -SourceWorkCopyPath ""<scratch-native-a4-dwg>"" -WaitForGstarCADClose" -f (Join-Path $repoRoot "diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1"))
    }
    Write-Output ""
    Write-Output "  Hidden suite verification path after A4 comparison/code changes:"
  } elseif ($a4InvestigationPreferred) {
    Write-Output "  A4 investigation continuation:"
    Write-Output ("    1. Confirm the open GstarCAD drawing matches: {0}" -f $script:LatestCadDwg)
    Write-Output "    2. If SWTITLEPREPARE was not tried in this exact open DWG state, run SWTITLEPREPARE once and then SWTITLESTATUS."
    Write-Output "    3. If SWTITLESTATUS still reports NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION, do not repeat SWTITLEPREPARE/SWTITLECONVERT."
    Write-Output "    4. Save the work-copy DWG, close GstarCAD, then run the copied-DWG nested A4 probe:"
    Write-Output ("       powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -SourceWorkCopyPath ""{1}"" -Strategies nested-outside,nested-direct-outside" -f $nestedProbeScript, $nestedProbeSource)
    Write-Output "    5. Only if one nested probe is safe should SWTITLEPREPARE/SWTITLECONVERT production logic be changed."
    Write-Output ""
    Write-Output "  Hidden suite verification path after A4 probe/code changes:"
  } elseif ($script:LatestCadDwgTrustedForGoal -and $script:LatestCadRecommendedCommand) {
    Write-Output "  Visible CAD continuation:"
    Write-Output ("    1. Confirm the open GstarCAD drawing matches: {0}" -f $script:LatestCadDwg)
    Write-Output ("    2. Run in GstarCAD: {0}" -f $script:LatestCadRecommendedCommand)
    Write-Output "    3. Run SWTITLESTATUS again and confirm the A4 missing count changes or a new warning explains why it stopped."
    if ($script:LatestCadStatusCode -eq "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION") {
      Write-Output "    4. Do not repeat SWTITLECONVERT before this prepare/status loop. A4 is frame-only and must not receive an extra title block."
    }
    Write-Output ""
    Write-Output "  Hidden suite verification path:"
  } elseif (-not $script:LatestCadDwgTrustedForGoal) {
    Write-Output "  Latest visible-CAD log is not trusted for the goal:"
    Write-Output ("    1. Ignored DWG: {0}" -f $script:LatestCadDwg)
    Write-Output ("    2. Reason: {0}" -f $script:LatestCadDwgTrustReason)
    Write-Output "    3. Re-open or activate the actual work-copy DWG, then run SWTITLESTATUS to refresh the goal log."
    Write-Output "    4. Do not follow the scratch log's SWTITLECONVERT recommendation."
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
  if ($a4FrameOnlyProductionPathVerified) {
    Write-Output "  A4 native 바깥 마커 허용 정책과 frame-only 변환 경로는 검증됨:"
    Write-Output "    1. A4 scratch probe에서 공식 작은 바깥 마커를 가진 실제 native GMTITLE 쌍을 확인했습니다."
    Write-Output "    2. SWTITLEPREPARE는 형상/raw-selection 검사가 통과하면 이 정의를 ready-native-outside-markers로 허용합니다."
    Write-Output "    3. A4 frame-only convert probe는 DR_titlea_3rd 제목블록 없이 DR_A4_Outline 도면틀 1개만 마무리했습니다."
    Write-Output "    4. 전체 hidden suite에도 이 probe와 A4 변환 기대값이 포함되어 있습니다."
    Write-Output "  다음 실제 작업복사본 단계:"
    if ($script:DirectWorkcopyProbeTrusted -and $script:DirectWorkcopyStatusCode) {
      Write-Output ("    1. 실제 작업복사본 direct probe 상태: {0}" -f $script:DirectWorkcopyStatusCode)
      Write-Output "    2. GstarCAD에서 실제 작업복사본 DWG를 열거나 활성화하세요."
      Write-Output "    3. 필요하면 최신 swcad_title_scale.lsp를 APPLOAD 하세요."
      if ($script:DirectWorkcopyStatusCode -eq "NEXT_CREATE_FIRST_NATIVE_GMTITLE") {
        Write-Output "    4. SWTITLESTATUS를 실행해서 현재 활성 DWG와 다음 상태를 먼저 확인하세요."
        Write-Output ("    5. 상태가 그대로면 SWTITLECONVERTNEXT를 실행하고 첫 native GMTITLE을 {0} / {1}로 만드세요." -f $script:DirectWorkcopyNextFrame, $script:DirectWorkcopyNextTitle)
        Write-Output "       수동 응답을 직접 고르고 싶을 때만 SWTITLECONVERT를 사용하세요."
        Write-Output "    6. 그 다음 SWTITLESTATUS를 실행하고 4단계 흐름을 계속하세요."
      } else {
        Write-Output "    4. SWTITLESTATUS를 실행하고 SWTITLECONVERTNEXT/SWTITLEVERIFY까지 이어지는 4단계 흐름만 따르세요."
      }
    } else {
      Write-Output "    1. GstarCAD에서 실제 작업복사본 DWG를 열거나 활성화하세요."
      Write-Output "    2. 필요하면 최신 swcad_title_scale.lsp를 APPLOAD 하세요."
      Write-Output "    3. SWTITLESTATUS를 실행하세요."
      Write-Output "    4. SWTITLECONVERTNEXT/SWTITLEVERIFY까지 이어지는 4단계 흐름만 따르세요."
    }
  } elseif ($a4NativeOutsideMarkerPolicyReady) {
    Write-Output "  A4 native outside-marker policy is implemented:"
    Write-Output "    1. The focused A4 scratch probe found a real native GMTITLE pair with official small outside markers."
    Write-Output "    2. SWTITLEPREPARE now accepts that definition as ready-native-outside-markers when geometry/raw-selection checks pass."
    Write-Output "    3. Run the focused A4 frame-only convert probe or the full hidden suite before using this on the real work-copy."
    Write-Output "    4. Production A4 frame-only must still not create an extra DR_titlea_3rd."
  } elseif ($a4NativeOutsideMarkerDecisionNeeded) {
    Write-Output "  A4 native outside-marker decision:"
    Write-Output "    1. The focused A4 scratch probe found a real native GMTITLE pair, but native DR_A4_Outline itself has small geometry outside (0,0)-(210,297)."
    Write-Output "    2. Do not keep creating more scratch A4 sheets; the next implementation decision is whether production A4 frame-only should tolerate, crop, or preserve those official native outside markers."
    Write-Output "    3. Because production A4 source is frame-only, keep the rule that it must not receive an extra DR_titlea_3rd."
    Write-Output "    4. After code changes, rerun the focused A4 probe and the full hidden suite."
  } elseif ($a4CandidateSafeNeedsReview) {
    Write-Output "  A4 normalization candidate review:"
    Write-Output "    1. Inspect the copied-DWG nested A4 normalization probe log that reported safe=yes."
    Write-Output "    2. Promote the safe strategy into SWTITLEPREPARE/SWTITLECONVERT only after confirming it preserves the A4 frame."
    Write-Output "    3. Then run the focused A4 probe and the full hidden suite."
  } elseif ($a4NativeA4ComparisonNeeded) {
    Write-Output "  A4 native comparison investigation:"
    Write-Output "    1. Do not run more SWTITLEPREPARE/SWTITLECONVERT attempts on the work-copy."
    Write-Output "    2. Create a separate scratch DWG with one real native A4 GMTITLE result, then compare its DR_A4_Outline definition."
    if ($scratchNativeA4Exists) {
      Write-Output ("       Saved clean gcadiso.dwt scratch from 2026-07-05 CAD test: {0}" -f $scratchNativeA4Path)
    }
    Write-Output "    3. Scratch only: the native A4 sample may include DR_titlea_3rd for comparison; production A4 frame-only must still not receive a new title block."
    Write-Output "    4. If direct GMTITLE only asks for an insertion point, cancel it; that is the current/default insertion flow, not proof of DR_A4_Outline selection."
    Write-Output "    5. If DR_A4_Outline / DR_titlea_3rd selection ends with a frame creation error and DR_titlea_3rd inserts=0, treat that scratch as failed evidence."
    Write-Output "    6. Scratch READY requires both 'Native GMTITLE A4 pair evidence: yes' and 'Result: A4_NATIVE_EXEMPLAR_READY_FOR_COMPARISON'."
    Write-Output "    7. If the probe reports A4_NATIVE_EXEMPLAR_MISSING_NATIVE_PAIR, the scratch has a frame but not a proven native GMTITLE pair."
    Write-Output ("    8. If you suspect a stored paper/title setting exists, run: powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $repoRoot "diagnostics\gmtitle-main45\run_gmtitle_selection_config_probe.ps1"))
    if ($scratchNativeA4Exists) {
      Write-Output ("    9. After closing GstarCAD, run: powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -SourceWorkCopyPath ""{1}"" -LogPath ""{2}"" -WaitForGstarCADClose" -f (Join-Path $repoRoot "diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1"), $scratchNativeA4Path, $scratchNativeA4Log)
    } else {
      Write-Output ("    9. After saving that scratch DWG, run: powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -SourceWorkCopyPath ""<scratch-native-a4-dwg>"" -WaitForGstarCADClose" -f (Join-Path $repoRoot "diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1"))
    }
    Write-Output "    10. After a safer A4 definition strategy is implemented, rerun the focused A4 probe and full hidden suite."
  } elseif ($a4InvestigationPreferred) {
    Write-Output "  지금은 복사본 DWG 기준 nested A4 probe를 먼저 실행하세요:"
    Write-Output ("     powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}"" -SourceWorkCopyPath ""{1}"" -Strategies nested-outside,nested-direct-outside" -f $nestedProbeScript, $nestedProbeSource)
    Write-Output "  먼저 전체 hidden suite를 돌리지 마세요. 이 probe가 DR_A4_Outline raw-bbox 의문을 닫기 전에는 A4 blocker를 증명할 수 없습니다."
  } else {
    Write-Output "  지금 전체 hidden suite를 실행하세요:"
    Write-Output ("     powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f $suite)
  }
}

Write-Output ""
Write-Output "목표모드 참고 문서:"
Write-Output ("  실행 카드: {0}" -f $runCard)
Write-Output ("  상세 계획: {0}" -f $goalPlan)
Write-Output ""
Write-Output "짧은 다음 작업 카드:"
Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $repoRoot "diagnostics\gmtitle-main45\run_next_cad_action.ps1"))
Write-Output "  GstarCAD를 저장하고 닫은 뒤 최신 direct probe까지 갱신하려면 위 명령에 -AutoRefreshDirectProbe를 붙이세요."
Write-Output ""
Write-Output "목표 상태: 실제 작업복사본이 SWTITLEVERIFY_FINAL_OK에 도달하고 대표 CAD 더블클릭 확인이 끝나기 전까지는 완료가 아닙니다."
