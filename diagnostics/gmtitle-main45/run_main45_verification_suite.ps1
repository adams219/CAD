param(
  [string]$SourceWorkCopyPath,

  [int]$TimeoutSeconds = 240,

  [ValidateSet("Hidden", "Minimized", "Normal", "Maximized")]
  [string]$ProbeWindowStyle = "Minimized",

  [switch]$WaitForGstarCADClose,

  [int]$WaitForGstarCADCloseTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"
$compareDir = Join-Path $workDir "lsp_compare"
$suiteLastRunLog = Join-Path $workDir "main56_verification_suite_last_run.txt"
$script:suiteLastRunInitialized = $false
$script:suiteLastRunCompleted = $false

function Write-SuiteLastRunLine {
  param([string]$Text)

  Add-Content -LiteralPath $suiteLastRunLog -Encoding UTF8 -Value $Text
}

function Set-SuiteLastRunFailure {
  param([object]$ErrorRecord)

  if ($script:suiteLastRunCompleted) {
    return
  }
  if (-not $script:suiteLastRunInitialized) {
    return
  }
  if (-not (Test-Path -LiteralPath $suiteLastRunLog)) {
    return
  }

  $message = "<unknown>"
  $line = $null
  if ($ErrorRecord -and $ErrorRecord.Exception -and $ErrorRecord.Exception.Message) {
    $message = (($ErrorRecord.Exception.Message -replace "\s+", " ").Trim())
  }
  if ($ErrorRecord -and $ErrorRecord.InvocationInfo -and $ErrorRecord.InvocationInfo.Line) {
    $line = (($ErrorRecord.InvocationInfo.Line -replace "\s+", " ").Trim())
  }

  Write-SuiteLastRunLine ""
  Write-SuiteLastRunLine "Result: FAILED_BEFORE_PASS"
  Write-SuiteLastRunLine ("Failure: {0}" -f $message)
  if ($line) {
    Write-SuiteLastRunLine ("Failure command: {0}" -f $line)
  }
}

trap {
  Set-SuiteLastRunFailure -ErrorRecord $_
  break
}

function Get-SuiteFirstRegexValue {
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

function Get-GitWorktreeEvidence {
  param([string]$RepoRoot)

  $chunks = New-Object System.Collections.Generic.List[string]
  $statusText = ""
  try {
    $statusText = ((& git -C $RepoRoot -c core.autocrlf=false -c core.safecrlf=false status --short 2>$null) -join "`n")
    [void]$chunks.Add("git status --short")
    [void]$chunks.Add($statusText)
    [void]$chunks.Add("git diff --binary")
    [void]$chunks.Add(((& git -C $RepoRoot -c core.autocrlf=false -c core.safecrlf=false diff --binary --no-ext-diff -- 2>$null) -join "`n"))
    [void]$chunks.Add("git diff --cached --binary")
    [void]$chunks.Add(((& git -C $RepoRoot -c core.autocrlf=false -c core.safecrlf=false diff --cached --binary --no-ext-diff -- 2>$null) -join "`n"))

    $joined = ($chunks -join "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
      $hash = (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
    } finally {
      $sha.Dispose()
    }

    return @{
      Dirty = (-not [string]::IsNullOrWhiteSpace($statusText))
      Hash = $hash
    }
  } catch {
    return @{
      Dirty = (-not [string]::IsNullOrWhiteSpace($statusText))
      Hash = "<unavailable>"
    }
  }
}

function Write-SuiteStatusSummary {
  param(
    [string]$StatusLogPath,
    [string]$SourceTitleMissingPrepareLogPath,
    [string]$SourceTitleMissingScriptGuardLogPath,
    [string]$A3StatusGuidanceLogPath,
    [string]$A3A4BatchGuardLogPath
  )

  Write-SuiteLastRunLine ""
  Write-SuiteLastRunLine "Actual work-copy status summary:"
  if (Test-Path -LiteralPath $StatusLogPath) {
    $statusText = Get-Content -LiteralPath $StatusLogPath -Raw
    foreach ($name in @(
      "status-after-status",
      "status-after-verify",
      "source-title-count",
      "source-frame-count",
      "frame-only-count",
      "target-title-count",
      "target-frame-count",
      "next-bootstrap-frame",
      "next-bootstrap-title"
    )) {
      $value = Get-SuiteFirstRegexValue -Text $statusText -Pattern ("^\s*" + [regex]::Escape($name) + ":\s*(.+)$")
      if ($value) {
        Write-SuiteLastRunLine ("  {0}: {1}" -f $name, $value)
      }
    }
    $missingFrames = [regex]::Matches($statusText, "^\s*missing-native-frame:\s*(.+)$", [System.Text.RegularExpressions.RegexOptions]::Multiline)
    foreach ($match in $missingFrames) {
      Write-SuiteLastRunLine ("  missing-native-frame: {0}" -f $match.Groups[1].Value.Trim())
    }
  } else {
    Write-SuiteLastRunLine ("  status log missing: {0}" -f $StatusLogPath)
  }

  Write-SuiteLastRunLine ""
  Write-SuiteLastRunLine "Source-title-missing common fixture evidence:"
  if (Test-Path -LiteralPath $SourceTitleMissingPrepareLogPath) {
    $prepareText = Get-Content -LiteralPath $SourceTitleMissingPrepareLogPath -Raw
    $prepareResult = Get-SuiteFirstRegexValue -Text $prepareText -Pattern "^Prepare status:\s*(.+)$"
    $prepareStatus = Get-SuiteFirstRegexValue -Text $prepareText -Pattern "^After definition status:\s*(.+)$"
    if ($prepareResult) { Write-SuiteLastRunLine ("  prepare-result: {0}" -f $prepareResult) }
    if ($prepareStatus) { Write-SuiteLastRunLine ("  after-definition-status: {0}" -f $prepareStatus) }
  }
  if (Test-Path -LiteralPath $SourceTitleMissingScriptGuardLogPath) {
    $convertText = Get-Content -LiteralPath $SourceTitleMissingScriptGuardLogPath -Raw
    foreach ($name in @(
      "Convert status",
      "After source-frame-count",
      "After frame-only-count",
      "After target title count",
      "After target frame count"
    )) {
      $value = Get-SuiteFirstRegexValue -Text $convertText -Pattern ("^" + [regex]::Escape($name) + ":\s*(.+)$")
      if ($value) {
        Write-SuiteLastRunLine ("  {0}: {1}" -f $name, $value)
      }
    }
  }

  Write-SuiteLastRunLine ""
  Write-SuiteLastRunLine "Native replacement guidance evidence:"
  if (Test-Path -LiteralPath $A3StatusGuidanceLogPath) {
    $a3Text = Get-Content -LiteralPath $A3StatusGuidanceLogPath -Raw
    $a3Status = Get-SuiteFirstRegexValue -Text $a3Text -Pattern "^Status after SWTITLESTATUS:\s*(.+)$"
    $a3Passed = Get-SuiteFirstRegexValue -Text $a3Text -Pattern "^A3 status guidance probe passed:\s*(.+)$"
    if ($a3Status) { Write-SuiteLastRunLine ("  A3 status after SWTITLESTATUS: {0}" -f $a3Status) }
    if ($a3Passed) { Write-SuiteLastRunLine ("  A3 status guidance probe passed: {0}" -f $a3Passed) }
  }
  if (Test-Path -LiteralPath $A3A4BatchGuardLogPath) {
    $batchText = Get-Content -LiteralPath $A3A4BatchGuardLogPath -Raw
    $batchStatus = Get-SuiteFirstRegexValue -Text $batchText -Pattern "^Status after batch:\s*(.+)$"
    $batchPreserved = Get-SuiteFirstRegexValue -Text $batchText -Pattern "^Batch guard preserved candidates:\s*(.+)$"
    if ($batchStatus) { Write-SuiteLastRunLine ("  Status after batch: {0}" -f $batchStatus) }
    if ($batchPreserved) { Write-SuiteLastRunLine ("  Batch guard preserved candidates: {0}" -f $batchPreserved) }
  }
}

function Get-SuiteRequiredIntValue {
  param(
    [string]$Text,
    [string]$Name,
    [string]$Label
  )

  $value = Get-SuiteFirstRegexValue -Text $Text -Pattern ("^\s*" + [regex]::Escape($Name) + ":\s*(\d+)\s*$")
  if ($null -eq $value) {
    throw "Verification failed for ${Label}: missing numeric '$Name'"
  }
  return [int]$value
}

function Assert-WorkcopySummaryInvariant {
  param(
    [string]$Path,
    [string]$Label
  )

  $text = Get-Content -LiteralPath $Path -Raw
  $sourceTitle = Get-SuiteRequiredIntValue -Text $text -Name "source-title-count" -Label $Label
  $sourceFrame = Get-SuiteRequiredIntValue -Text $text -Name "source-frame-count" -Label $Label
  $frameOnly = Get-SuiteRequiredIntValue -Text $text -Name "frame-only-count" -Label $Label
  $targetTitle = Get-SuiteRequiredIntValue -Text $text -Name "target-title-count" -Label $Label
  $targetFrame = Get-SuiteRequiredIntValue -Text $text -Name "target-frame-count" -Label $Label

  if (($sourceTitle + $frameOnly) -ne $sourceFrame) {
    throw "Verification failed for ${Label}: source-title-count + frame-only-count must equal source-frame-count, got $sourceTitle + $frameOnly != $sourceFrame"
  }
  if ($targetTitle -ne $targetFrame) {
    throw "Verification failed for ${Label}: target-title-count must equal target-frame-count, got $targetTitle != $targetFrame"
  }

  $pairValue = Get-SuiteFirstRegexValue -Text $text -Pattern "^\s*target-gmtitle-pair-count:\s*(\d+)\s*$"
  if (($null -ne $pairValue) -and ([int]$pairValue -ne $targetTitle)) {
    throw "Verification failed for ${Label}: target-gmtitle-pair-count must equal target-title-count, got $pairValue != $targetTitle"
  }

  $status = Get-SuiteFirstRegexValue -Text $text -Pattern "^Result: OK SWTITLESTATUS status=(\S+)\s*$"
  if (-not $status -or $status -match "^(ABORT|ERROR)") {
    throw "Verification failed for ${Label}: SWTITLESTATUS did not return a non-error status"
  }
  $verify = Get-SuiteFirstRegexValue -Text $text -Pattern "^Result: OK SWTITLEVERIFY status=(\S+)\s*$"
  if (-not $verify -or $verify -notmatch "^SWTITLEVERIFY_FINAL_(OK|FAIL)$") {
    throw "Verification failed for ${Label}: SWTITLEVERIFY result is missing or invalid"
  }

  Write-Output ("Verified work-copy invariants for {0}: source={1}+{2}/{3}, target={4}/{5}, status={6}, verify={7}" -f $Label, $sourceTitle, $frameOnly, $sourceFrame, $targetTitle, $targetFrame, $status, $verify)
}

function Assert-ScriptGuardPreservationInvariant {
  param(
    [string]$Path,
    [string]$Label
  )

  $text = Get-Content -LiteralPath $Path -Raw
  $pairs = @{}
  foreach ($name in @(
    "Source titles before/after",
    "Source frames before/after",
    "Frame-only before/after",
    "Target titles before/after",
    "Target frames before/after",
    "INSERT count before/after",
    "DBMOD before/after"
  )) {
    $match = [regex]::Match($text, ("^" + [regex]::Escape($name) + ":\s*(\d+)\s*/\s*(\d+)\s*$"), [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
      throw "Verification failed for ${Label}: missing before/after pair '$name'"
    }
    $before = [int]$match.Groups[1].Value
    $after = [int]$match.Groups[2].Value
    if ($before -ne $after) {
      throw "Verification failed for ${Label}: '$name' changed from $before to $after"
    }
    $pairs[$name] = $before
  }

  if (($pairs["Source titles before/after"] + $pairs["Frame-only before/after"]) -ne $pairs["Source frames before/after"]) {
    throw "Verification failed for ${Label}: source partition invariant failed"
  }
  if ($pairs["Target titles before/after"] -ne $pairs["Target frames before/after"]) {
    throw "Verification failed for ${Label}: target pair-count invariant failed"
  }
  if ($pairs["DBMOD before/after"] -ne 0) {
    throw "Verification failed for ${Label}: DBMOD must remain 0"
  }

  Write-Output ("Verified script-guard preservation for {0}: source={1}+{2}/{3}, target={4}/{5}, inserts={6}, dbmod=0" -f $Label, $pairs["Source titles before/after"], $pairs["Frame-only before/after"], $pairs["Source frames before/after"], $pairs["Target titles before/after"], $pairs["Target frames before/after"], $pairs["INSERT count before/after"])
}

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
        Write-Output "No existing GstarCAD process detected. Continuing verification suite."
        return
      }
      Write-Output ("Waiting for GstarCAD to close before GstarCAD /b probes... active PID(s): {0}" -f (($existing | ForEach-Object { $_.Id }) -join ", "))
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
Existing GstarCAD process detected before the verification suite.
The suite uses GstarCAD /b probes, which are unreliable while a visible GstarCAD session is open.

Save the work-copy DWG, close GstarCAD, then rerun:
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_main45_verification_suite.ps1

Or start the suite in waiting mode, save/close GstarCAD, and let it continue:
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_main45_verification_suite.ps1 -WaitForGstarCADClose

Existing process:
$details
"@
  }
}

function Assert-LogContains {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string[]]$Patterns,

    [string]$Label = $Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Verification log not found for ${Label}: $Path"
  }

  $text = Get-Content -LiteralPath $Path -Raw
  foreach ($pattern in $Patterns) {
    if ($text -notmatch [regex]::Escape($pattern)) {
      throw "Verification failed for ${Label}: missing '$pattern' in $Path"
    }
  }

  Write-Output ("Verified log: {0}" -f $Label)
}

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $repoRoot "work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}
$preFirstNativeWorkCopyPath = Join-Path $repoRoot "work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03_before_first_native_attempt_260706.dwg"
if (-not (Test-Path -LiteralPath $preFirstNativeWorkCopyPath)) {
  throw "Pre-first-native work-copy DWG not found: $preFirstNativeWorkCopyPath"
}

$suiteStartWorktreeEvidence = Get-GitWorktreeEvidence -RepoRoot $repoRoot
Set-Content -LiteralPath $suiteLastRunLog -Encoding UTF8 -Value @(
  "===== GMTITLE main56 verification suite last run =====",
  ("Generated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss K")),
  ("Repo root: {0}" -f $repoRoot),
  ("Source work copy: {0}" -f $SourceWorkCopyPath),
  ("Probe window style: {0}" -f $ProbeWindowStyle),
  ("Timeout seconds: {0}" -f $TimeoutSeconds),
  ("Worktree dirty at suite start: {0}" -f ($(if ($suiteStartWorktreeEvidence.Dirty) { "yes" } else { "no" }))),
  ("Worktree evidence hash at suite start: {0}" -f $suiteStartWorktreeEvidence.Hash),
  "Result: RUNNING_OR_FAILED_BEFORE_PASS"
)
$script:suiteLastRunInitialized = $true

Write-Output "===== Preflight. Next CAD action card probe (no CAD) ====="
& (Join-Path $PSScriptRoot "run_next_cad_action_card_probe.ps1")
Write-Output ""

Write-Output "===== Preflight. Visible work-copy opener dry-run (no CAD convert) ====="
$openWorkcopyDryRunOutput = & (Join-Path $PSScriptRoot "run_open_workcopy_for_manual_convert.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -DryRun
$openWorkcopyDryRunText = ($openWorkcopyDryRunOutput -join "`n")
$openWorkcopyDryRunOutput | Write-Output
foreach ($pattern in @(
  "Result: DRY_RUN_READY",
  "SafetyMarker: no-run-SWTITLECONVERTNEXT no-open-GMTITLE no-save-DWG",
  "GuardMarker: no-raw-GMTITLE no-raw-TIT no-raw-OPEN",
  "Frame positioning ON",
  "Object move OFF",
  "APPLOAD",
  "swcad_load.lsp",
  "SWTITLEVERSION",
  "SWTITLESTATUS",
  "SWTITLECONVERTNEXT"
)) {
  if ($openWorkcopyDryRunText -notmatch [regex]::Escape($pattern)) {
    throw "Verification failed for visible work-copy opener dry-run: missing '$pattern'"
  }
}
Write-Output "Verified visible work-copy opener dry-run"
Write-Output ""

Assert-NoExistingGstarCAD -Wait:$WaitForGstarCADClose -WaitTimeoutSeconds $WaitForGstarCADCloseTimeoutSeconds
if (-not (Test-Path -LiteralPath $compareDir)) {
  New-Item -ItemType Directory -Path $compareDir | Out-Null
}

$sourceLsp = Join-Path $repoRoot "src\tools\gmtitle\swcad_title_scale.lsp"
$compareLsp = Join-Path $compareDir "swcad_title_scale_current_main56_compare_copy.lsp"
Copy-Item -LiteralPath $sourceLsp -Destination $compareLsp -Force

Write-Output "===== GMTITLE main56 verification suite ====="
Write-Output ("Repo root: {0}" -f $repoRoot)
Write-Output ("Source work copy: {0}" -f $SourceWorkCopyPath)
Write-Output ("Current LSP compare copy: {0}" -f $compareLsp)
Write-Output ""

Write-Output "===== Preflight. GstarCAD /b script smoke probe ====="
& (Join-Path $PSScriptRoot "run_hidden_script_smoke_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -TimeoutSeconds $TimeoutSeconds `
  -WindowStyle $ProbeWindowStyle
Write-Output ""

$loaderLog = Join-Path $workDir "swtitle_loader_probe_main56_diagnostics.txt"
$copyCompareLog = Join-Path $workDir "swtitle_lsp_copy_compare_current_main56.txt"
$actualStatusLog = Join-Path $workDir "swtitle_actual_workcopy_status_main56_diagnostics.txt"
$sourceTitleMissingGapLog = Join-Path $workDir "swtitle_source_title_missing_gap_a2.txt"
$sourceTitleMissingPrepareLog = Join-Path $workDir "swtitle_source_title_missing_prepare_a3.txt"
$sourceTitleMissingScriptGuardLog = Join-Path $workDir "swtitle_source_title_missing_scriptguard_a4.txt"
$convertScriptGuardLog = Join-Path $workDir "swtitle_convert_script_guard_probe.txt"
$frameclassLogs = @(
  Join-Path $workDir "swtitle_frameclass_common_probe_mixed.txt"
  Join-Path $workDir "swtitle_frameclass_common_probe_all_contaminated.txt"
  Join-Path $workDir "swtitle_frameclass_common_probe_all_native.txt"
)
$styleNormalizationLog = Join-Path $workDir "swtitle_style_normalization_compare_current_main56_stylecmp_all_sizes_clean.txt"
$commandTextGuardLog = Join-Path $workDir "swtitle_command_text_guard_compare_current_main56_command_text_guard.txt"
$residueProtectionLog = Join-Path $workDir "swtitle_residue_protection_current_main56_residue_protection.txt"
$embeddedPrepareLog = Join-Path $workDir "swtitle_embedded_title_prepare_compare_current_main56_embedded_prepare.txt"
$duplicateTargetPairLog = Join-Path $workDir "swtitle_duplicate_target_pair_compare_current_main56_duplicate_target_pair.txt"
$adoptionGateLog = Join-Path $workDir "swtitle_adoption_gate_compare_current_main56_adoption_gate.txt"
$postFirstNativeTransitionLog = Join-Path $workDir "swtitle_post_first_native_transition_probe.txt"
$a3StatusGuidanceLog = Join-Path $workDir "swtitle_a3_status_guidance_probe.txt"
$a3a4BatchGuardLog = Join-Path $workDir "swtitle_a3a4_batch_guard_probe.txt"
$selectionConfigLog = Join-Path $workDir "swtitle_gmtitle_selection_config_probe_260705.txt"

Write-Output "===== 1. Loader probe ====="
& (Join-Path $PSScriptRoot "run_loader_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $loaderLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $loaderLog `
  -Label "loader probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded loader version: 260706-loader-convert-next-response-guidance",
    "Loaded GMTITLE version: 260713-frame-style-structure-guard-1",
    "Command-line -GMTITLE default enabled: no",
    "SCRIPT command-line -GMTITLE enabled: no",
    "Command c:SWTITLESTATUS: yes",
    "Command c:SWTITLEPREPARE: yes",
    "Command c:SWTITLECONVERT: yes",
    "Command c:SWTITLEVERIFY: yes",
    "Command c:SWTITLEFASTSTATUS: no",
    "Command c:SWTITLETRANSFERBOOTSTRAPFAST: no",
    "Command c:SWTITLEA3A4NEXT: no",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 2. Current LSP copy compare probe ====="
& (Join-Path $PSScriptRoot "run_lsp_copy_compare_probe.ps1") `
  -LspPath $compareLsp `
  -Label "current_main56" `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $copyCompareLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $copyCompareLog `
  -Label "current LSP copy compare probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260713-frame-style-structure-guard-1",
    "Command-line -GMTITLE default enabled: no",
    "SCRIPT command-line -GMTITLE enabled: no",
    "Command c:SWTITLESTATUS: yes",
    "Command c:SWTITLEPREPARE: yes",
    "Command c:SWTITLECONVERT: yes",
    "Command c:SWTITLEVERIFY: yes",
    "Command c:SWTITLEFASTSTATUS: no",
    "Result: OK SWTITLESTATUS status=",
    "Result: OK SWTITLEVERIFY status=",
    "source-title-count:",
    "source-frame-count:",
    "frame-only-count:",
    "target-title-count:",
    "target-frame-count:",
    "frame-definition-blockers: 0",
    "frame-embedded-cleanup-records: 0",
    "A2: 1",
    "A3: 12",
    "A3: 4",
    "A4: 2",
    "Runtime check completed: yes"
  )
Assert-WorkcopySummaryInvariant -Path $copyCompareLog -Label "current LSP copy compare probe"

Write-Output ""
Write-Output "===== 3. Actual work-copy status probe ====="
& (Join-Path $PSScriptRoot "run_actual_workcopy_status_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $actualStatusLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $actualStatusLog `
  -Label "actual work-copy status probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260713-frame-style-structure-guard-1",
    "Result: OK SWTITLESTATUS status=",
    "Result: OK SWTITLEVERIFY status=",
    "source-title-count:",
    "source-frame-count:",
    "frame-only-count:",
    "target-title-count:",
    "target-frame-count:",
    "target-gmtitle-pair-count:",
    "native-like-target-pair-count:",
    "non-native-like-target-pair-count: 0",
    "cloned-gmtitle-pair-count: 0",
    "a2a3a4-native-upgrade-candidate-count: 0",
    "log-evidence-note-found: yes",
    "automation-split-note-found: yes",
    "human-check-note-found: yes",
    "title-missing-deferred-note-found: no",
    "verify-source-priority-note-found: yes",
    "verify-title-missing-first-note-found: no",
    "frame-definition-blockers: 0",
    "frame-embedded-cleanup-records: 0",
    "next-bootstrap-source-sheet:",
    "next-bootstrap-frame:",
    "next-bootstrap-title:",
    "A2: 1",
    "A3: 12",
    "A3: 4",
    "A4: 2",
    "Runtime check completed: yes"
  )
Assert-WorkcopySummaryInvariant -Path $actualStatusLog -Label "actual work-copy status probe"

Write-Output ""
Write-Output "===== 4. Common source-title-missing gap probe (A2 fixture) ====="
& (Join-Path $PSScriptRoot "run_source_title_missing_common_probe.ps1") `
  -Mode Gap `
  -Sheet A2 `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -ProbeDwgPath (Join-Path $workDir "swtitle_source_title_missing_gap_a2.dwg") `
  -LogPath $sourceTitleMissingGapLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $sourceTitleMissingGapLog `
  -Label "common source-title-missing gap probe (A2 fixture)" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260713-frame-style-structure-guard-1",
    "Fixture mode: GAP",
    "Fixture sheet: A2",
    "Expected target frame: DR_A2_Outline",
    "Before source-title-count: 0",
    "Before source-frame-count: 1",
    "Before frame-only-count: 1",
    "Before definition status: missing",
    "Source frame preserved: yes",
    "After target title count: 0",
    "After target frame count: 0",
    "Fixture result: PASS",
    "No drawing data was saved.",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 5. Common source-title-missing definition prepare probe (A3 fixture) ====="
& (Join-Path $PSScriptRoot "run_source_title_missing_common_probe.ps1") `
  -Mode Prepare `
  -Sheet A3 `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -ProbeDwgPath (Join-Path $workDir "swtitle_source_title_missing_prepare_a3.dwg") `
  -LogPath $sourceTitleMissingPrepareLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $sourceTitleMissingPrepareLog `
  -Label "common source-title-missing definition prepare probe (A3 fixture)" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260713-frame-style-structure-guard-1",
    "Fixture mode: PREPARE",
    "Fixture sheet: A3",
    "Expected target frame: DR_A3_Outline",
    "Before definition status: missing",
    "Prepare status: OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED",
    "After definition ready: yes",
    "After definition raw bbox risk: no",
    "After source-title-count: 0",
    "After source-frame-count: 1",
    "After frame-only-count: 1",
    "Source frame preserved: yes",
    "After target title count: 0",
    "After target frame count: 0",
    "Fixture result: PASS",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 6. Common source-title-missing hidden-script safety probe (A4 fixture) ====="
& (Join-Path $PSScriptRoot "run_source_title_missing_common_probe.ps1") `
  -Mode ScriptGuard `
  -Sheet A4 `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -ProbeDwgPath (Join-Path $workDir "swtitle_source_title_missing_scriptguard_a4.dwg") `
  -LogPath $sourceTitleMissingScriptGuardLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $sourceTitleMissingScriptGuardLog `
  -Label "common source-title-missing hidden-script safety probe (A4 fixture)" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260713-frame-style-structure-guard-1",
    "Fixture mode: SCRIPT_GUARD",
    "Fixture sheet: A4",
    "Expected target frame: DR_A4_Outline",
    "Prepare status: OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED",
    "After definition ready: yes",
    "Convert status: ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE",
    "After source-title-count: 0",
    "After source-frame-count: 1",
    "After frame-only-count: 1",
    "Source frame preserved: yes",
    "After target title count: 0",
    "After target frame count: 0",
    "Fixture result: PASS",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 7. SWTITLECONVERT script guard probe ====="
& (Join-Path $PSScriptRoot "run_convert_script_guard_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $convertScriptGuardLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $convertScriptGuardLog `
  -Label "SWTITLECONVERT script guard probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260713-frame-style-structure-guard-1",
    "SWTITLECONVERT result: OK",
    "Script active before convert: yes",
    "Status after convert: ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE",
    "Source titles before/after:",
    "Source frames before/after:",
    "Frame-only before/after:",
    "Target titles before/after:",
    "Target frames before/after:",
    "INSERT count before/after:",
    "DBMOD before/after: 0/0",
    "Convert script guard preserved drawing: yes",
    "Runtime check completed: yes"
  )
Assert-ScriptGuardPreservationInvariant -Path $convertScriptGuardLog -Label "SWTITLECONVERT script guard probe"

Write-Output ""
Write-Output "===== 8. Common A2/A3/A4 frame-definition probe ====="
& (Join-Path $PSScriptRoot "run_frameclass_common_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $frameclassLogs[0] `
  -Label "frameclass mixed probe" `
  -Patterns @(
    "Scenario: MIXED",
    "DR_A2_Outline: class=outline-only",
    "DR_A3_Outline: class=native-format-with-title-geometry",
    "DR_A4_Outline: class=source-contaminated",
    "Cleanup records by frame:",
    "DR_A4_Outline: 2",
    "Scenario result: PASS",
    "Runtime check completed: yes"
  )
Assert-LogContains `
  -Path $frameclassLogs[1] `
  -Label "frameclass all-contaminated probe" `
  -Patterns @(
    "Scenario: ALL_CONTAMINATED",
    "DR_A2_Outline: class=source-contaminated",
    "DR_A3_Outline: class=source-contaminated",
    "DR_A4_Outline: class=source-contaminated",
    "Cleanup records by frame:",
    "DR_A2_Outline: 1",
    "DR_A3_Outline: 1",
    "DR_A4_Outline: 2",
    "Scenario result: PASS",
    "Runtime check completed: yes"
  )
Assert-LogContains `
  -Path $frameclassLogs[2] `
  -Label "frameclass all-native probe" `
  -Patterns @(
    "Scenario: ALL_NATIVE",
    "DR_A2_Outline: class=native-format-with-title-geometry",
    "DR_A3_Outline: class=native-format-with-title-geometry",
    "DR_A4_Outline: class=native-format-with-title-geometry",
    "Blocking frame definitions:",
    "<none>",
    "Cleanup records by frame:",
    "<none>",
    "Scenario result: PASS",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 9. A2/A3/A4 style-normalization rebuild cleanup probe ====="
& (Join-Path $PSScriptRoot "run_style_normalization_compare_probe.ps1") `
  -LspPath $sourceLsp `
  -Label "current_main56_stylecmp_all_sizes_clean" `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $styleNormalizationLog `
  -Sheets "A2,A3,A4" `
  -RunClean `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $styleNormalizationLog `
  -Label "A2/A3/A4 style-normalization rebuild cleanup probe" `
  -Patterns @(
    "Loaded version: 260713-frame-style-structure-guard-1",
    "DR_A2_Outline: class=native-format-with-title-geometry",
    "DR_A3_Outline: class=native-format-with-title-geometry",
    "DR_A4_Outline: class=native-format-with-title-geometry",
    "Style-normalization record count: 3",
    "Style-normalization clean entity count: 45",
    "Style-normalization deleted count: 45",
    "Style-normalization record count after clean: 0",
    "Independent residue count before clean: 45",
    "Protected frame entity count before clean:",
    "Off-sheet nested insert count before clean: 3",
    "Frame definition raw bbox risk count before clean: 3",
    "Independent residue count after clean: 0",
    "Off-sheet nested insert count after clean: 0",
    "Frame definition raw bbox risk count after clean: 0",
    "Second clean entity count: 0",
    "Second clean deleted count: 0",
    "Preserved revision text: yes",
    "Preserved coordinate text: yes",
    "Preserved A4 inset bottom edge: yes",
    "Preserved A4 inset right edge: yes",
    "Preserved A4 wide-band coordinate E: yes",
    "Preserved A4 wide-band coordinate F: yes",
    "Preserved A4 full-sheet cover: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 10. Command-text guard comparison probe ====="
& (Join-Path $PSScriptRoot "run_command_text_guard_compare_probe.ps1") `
  -LspPath $sourceLsp `
  -Label "current_main56_command_text_guard" `
  -LogPath $commandTextGuardLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $commandTextGuardLog `
  -Label "command-text guard comparison probe" `
  -Patterns @(
    "Loaded version: 260713-frame-style-structure-guard-1",
    "command-text-count-before: 1",
    "SWTITLESTATUS result: OK status=NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT",
    "structure-next-action: SWTITLEPREPARE",
    "convert-status-after: ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST",
    "danger-action-after-convert: <none>",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 11. Sheet residue protection probe ====="
& (Join-Path $PSScriptRoot "run_residue_protection_probe.ps1") `
  -LspPath $sourceLsp `
  -Label "current_main56_residue_protection" `
  -LogPath $residueProtectionLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $residueProtectionLog `
  -Label "sheet residue protection probe" `
  -Patterns @(
    "Loaded version: 260713-frame-style-structure-guard-1",
    "bottom-left logo line candidate: yes",
    "bottom-left real text preserved: yes",
    "upper small SW_NOTE balloon preserved: yes",
    "upper wide SW_NOTE residue candidate: yes",
    "upper SHEET_FORMAT residue candidate: yes",
    "upper BOM-like insert preserved: yes",
    "Residue protection passed: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 12. Embedded-title prepare comparison probe ====="
& (Join-Path $PSScriptRoot "run_embedded_title_prepare_compare_probe.ps1") `
  -LspPath $sourceLsp `
  -Label "current_main56_embedded_prepare" `
  -LogPath $embeddedPrepareLog `
  -RunClean `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $embeddedPrepareLog `
  -Label "embedded-title prepare comparison probe" `
  -Patterns @(
    "Loaded version: 260713-frame-style-structure-guard-1",
    "DR_A2_Outline: class=native-format-with-title-geometry, embedded=4",
    "DR_A3_Outline: class=native-format-with-title-geometry, embedded=4",
    "DR_A4_Outline: class=native-format-with-title-geometry, embedded=4",
    "Cleanup records by frame:",
    "<none>",
    "Structure next action: SWTITLECONVERTNEXT",
    "Cleanup result: OK",
    "Cleanup deleted count: 0",
    "Cleanup record count after clean: 0",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output ""
Write-Output "===== 13. Duplicate target pair comparison probe ====="
& (Join-Path $PSScriptRoot "run_duplicate_target_pair_compare_probe.ps1") `
  -LspPath $sourceLsp `
  -Label "current_main56_duplicate_target_pair" `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $duplicateTargetPairLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $duplicateTargetPairLog `
  -Label "duplicate target pair comparison probe" `
  -Patterns @(
    "Loaded version: 260713-frame-style-structure-guard-1",
    "Duplicate function present: yes",
    "Duplicate target pair count: 1",
    "Keep frame/title role:",
    "native-upgrade/native-upgrade",
    "Discard frame/title role:",
    "native-apply/native-apply",
    "Duplicate target pair probe passed: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 14. Native adoption gate comparison probe ====="
& (Join-Path $PSScriptRoot "run_adoption_gate_compare_probe.ps1") `
  -LspPath $sourceLsp `
  -Label "current_main56_adoption_gate" `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $adoptionGateLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $adoptionGateLog `
  -Label "native adoption gate comparison probe" `
  -Patterns @(
    "Loaded version: 260713-frame-style-structure-guard-1",
    "Adoption function present: yes",
    "Target title attribute count before transfer:",
    "Target title missing tag count before transfer: 0",
    "Status after transfer: ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER",
    "Danger action: <none>",
    "Source title count before/after: 1/0",
    "Target title count before/after: 1/1",
    "Adoption gate probe passed: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 15. Post-first-native marker gate probe ====="
& (Join-Path $PSScriptRoot "run_post_first_native_transition_probe.ps1") `
  -SourceWorkCopyPath $preFirstNativeWorkCopyPath `
  -LogPath $postFirstNativeTransitionLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $postFirstNativeTransitionLog `
  -Label "post-first-native marker gate probe" `
  -Patterns @(
    "Loaded version: 260713-frame-style-structure-guard-1",
    "Bootstrap before fixture: A2 / DR_A2_Outline / DR_titlea_3rd",
    "Source title count before fixture:",
    "Frame-only count before fixture:",
    "A2 marker-only title native-link kinds: <none>",
    "Source title count after fixture:",
    "Native-like pair count after fixture: 0",
    "Missing native frames after fixture: DR_A3_Outline, DR_A4_Outline",
    "Next missing native selection after fixture: A3 / DR_A3_Outline / DR_titlea_3rd / title-sheet",
    "Status after SWTITLESTATUS: NEXT_",
    "Expected gate: marker-only A2 target is not accepted as native-like GMTITLE; remaining real source sheets may be reviewed first.",
    "Post-first-native marker gate probe passed: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 16. A3 status guidance probe ====="
& (Join-Path $PSScriptRoot "run_a3_status_guidance_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $a3StatusGuidanceLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $a3StatusGuidanceLog `
  -Label "A3 status guidance probe" `
  -Patterns @(
    "Loaded version: 260713-frame-style-structure-guard-1",
    "A2/A3/A4 candidate count before SWTITLESTATUS: 1",
    "SWTITLESTATUS result: OK",
    "Status after SWTITLESTATUS: NEXT_UPGRADE_NATIVE_GMTITLE",
    "A3 frame guidance note found: yes",
    "A3 native-candidate supplement found: yes",
    "A3 status guidance probe passed: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 17. A2/A3/A4 native replacement batch guard probe ====="
& (Join-Path $PSScriptRoot "run_a3a4_batch_guard_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $a3a4BatchGuardLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $a3a4BatchGuardLog `
  -Label "A2/A3/A4 native replacement batch guard probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260713-frame-style-structure-guard-1",
    "Script active: yes",
    "Batch result: OK",
    "Status after batch: ABORT_NATIVE_GMTITLE_BATCH_SCRIPT_ACTIVE",
    "Candidates before/after: 2/2",
    "INSERT count before/after: 4/4",
    "Batch guard preserved candidates: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 18. GMTITLE selection config probe ====="
& (Join-Path $PSScriptRoot "run_gmtitle_selection_config_probe.ps1") `
  -OutputPath $selectionConfigLog `
  -DeepRegistrySearch
Assert-LogContains `
  -Path $selectionConfigLog `
  -Label "GMTITLE selection config probe" `
  -Patterns @(
    "No DWG is opened or changed.",
    "[Program PaperSet.ini]",
    "[Program PaperSet.grx ASCII string scan]",
    "[HKCU Gstarsoft deep DR marker search]",
    "Deep registry policy: only non-recent DR marker(s) are review evidence; recent-file history alone is ignored.",
    "No active persistent DR_A*_Outline / DR_titlea_3rd preselection config was found in the checked locations.",
    "Direct GMTITLE may still reuse an internal/current command state and ask only for an insertion point.",
    "Do not assume a scratch native A4 sample was created unless the saved DWG passes run_a4_native_exemplar_probe.ps1.",
    "Result: GMTITLE_SELECTION_CONFIG_NOT_FOUND"
  )

Write-Output ""
Write-Output "All expected log markers were verified."
Write-Output "===== GMTITLE main56 verification suite complete ====="

$suiteEndWorktreeEvidence = Get-GitWorktreeEvidence -RepoRoot $repoRoot
Set-Content -LiteralPath $suiteLastRunLog -Encoding UTF8 -Value @(
  "===== GMTITLE main56 verification suite last run =====",
  ("Generated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss K")),
  ("Repo root: {0}" -f $repoRoot),
  ("Source work copy: {0}" -f $SourceWorkCopyPath),
  ("Probe window style: {0}" -f $ProbeWindowStyle),
  ("Timeout seconds: {0}" -f $TimeoutSeconds),
  ("Worktree dirty at suite run: {0}" -f ($(if ($suiteEndWorktreeEvidence.Dirty) { "yes" } else { "no" }))),
  ("Worktree evidence hash: {0}" -f $suiteEndWorktreeEvidence.Hash),
  "Result: PASS",
  "Verified markers:",
  "  no-CAD next-action card probe: PASS",
  "  visible work-copy opener dry-run: PASS",
  "  GstarCAD /b script smoke probe: PASS",
  "  Loader probe: PASS",
  "  Current LSP copy compare probe: PASS",
  "  Actual work-copy status probe: PASS",
  "  Common source-title-missing gap probe (A2 fixture): PASS",
  "  Common source-title-missing definition prepare probe (A3 fixture): PASS",
  "  Common source-title-missing hidden-script safety probe (A4 fixture): PASS",
  "  SWTITLECONVERT script guard probe: PASS",
  "  Common A2/A3/A4 frame-definition probe: PASS",
  "  A2/A3/A4 style-normalization rebuild cleanup probe: PASS",
  "  Command-text guard comparison probe: PASS",
  "  Sheet residue protection probe: PASS",
  "  Embedded-title prepare comparison probe: PASS",
  "  Duplicate target pair comparison probe: PASS",
  "  Native adoption gate comparison probe: PASS",
  "  Post-first-native marker gate probe: PASS",
  "  A3 status guidance probe: PASS",
  "  A2/A3/A4 native replacement batch guard probe: PASS",
  "  GMTITLE selection config deep registry probe: PASS",
  "All expected log markers were verified.",
  "===== GMTITLE main56 verification suite complete ====="
)
Write-SuiteStatusSummary `
  -StatusLogPath $actualStatusLog `
  -SourceTitleMissingPrepareLogPath $sourceTitleMissingPrepareLog `
  -SourceTitleMissingScriptGuardLogPath $sourceTitleMissingScriptGuardLog `
  -A3StatusGuidanceLogPath $a3StatusGuidanceLog `
  -A3A4BatchGuardLogPath $a3a4BatchGuardLog
$script:suiteLastRunCompleted = $true
Write-Output ("Suite last-run summary: {0}" -f $suiteLastRunLog)
