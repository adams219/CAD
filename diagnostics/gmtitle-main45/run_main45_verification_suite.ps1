param(
  [string]$SourceWorkCopyPath,

  [int]$TimeoutSeconds = 90,

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

function Write-SuiteStatusSummary {
  param(
    [string]$StatusLogPath,
    [string]$A4OutlinePrepareLogPath,
    [string]$A4OutlineConvertLogPath,
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
  Write-SuiteLastRunLine "Title-missing/frame-only evidence (A4-sized source-title-missing sample):"
  if (Test-Path -LiteralPath $A4OutlinePrepareLogPath) {
    $prepareText = Get-Content -LiteralPath $A4OutlinePrepareLogPath -Raw
    $prepareResult = Get-SuiteFirstRegexValue -Text $prepareText -Pattern "^Prepare result:\s*(.+)$"
    $prepareStatus = Get-SuiteFirstRegexValue -Text $prepareText -Pattern "^After definition status:\s*(.+)$"
    if ($prepareResult) { Write-SuiteLastRunLine ("  prepare-result: {0}" -f $prepareResult) }
    if ($prepareStatus) { Write-SuiteLastRunLine ("  after-definition-status: {0}" -f $prepareStatus) }
  }
  if (Test-Path -LiteralPath $A4OutlineConvertLogPath) {
    $convertText = Get-Content -LiteralPath $A4OutlineConvertLogPath -Raw
    foreach ($name in @(
      "Convert result",
      "After frame-only-count",
      "After target title count",
      "After DR_A4_Outline target frame count"
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

Set-Content -LiteralPath $suiteLastRunLog -Encoding UTF8 -Value @(
  "===== GMTITLE main56 verification suite last run =====",
  ("Generated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss K")),
  ("Repo root: {0}" -f $repoRoot),
  ("Source work copy: {0}" -f $SourceWorkCopyPath),
  ("Probe window style: {0}" -f $ProbeWindowStyle),
  ("Timeout seconds: {0}" -f $TimeoutSeconds),
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
$a4NativeExemplarLog = Join-Path $workDir "swtitle_a4_native_exemplar_probe_260705.txt"
$a4OutlinePrepareLog = Join-Path $workDir "swtitle_a4_outline_prepare_probe_main56_default.txt"
$a4OutlineConvertLog = Join-Path $workDir "swtitle_a4_outline_convert_probe_main56_default.txt"
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
    "Loaded GMTITLE version: 260707-unified-title-missing-13",
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
    "Loaded version: 260707-unified-title-missing-13",
    "Command-line -GMTITLE default enabled: no",
    "SCRIPT command-line -GMTITLE enabled: no",
    "Command c:SWTITLESTATUS: yes",
    "Command c:SWTITLEPREPARE: yes",
    "Command c:SWTITLECONVERT: yes",
    "Command c:SWTITLEVERIFY: yes",
    "Command c:SWTITLEFASTSTATUS: no",
    "Result: OK SWTITLESTATUS status=NEXT_CREATE_MISSING_NATIVE_EXEMPLAR",
    "Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL",
    "source-title-count: 12",
    "source-frame-count: 14",
    "frame-only-count: 2",
    "target-title-count: 1",
    "target-frame-count: 1",
    "A2: 1",
    "A3: 12",
    "A4: 2",
    "Runtime check completed: yes"
  )

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
    "Loaded version: 260707-unified-title-missing-13",
    "Result: OK SWTITLESTATUS status=NEXT_CREATE_MISSING_NATIVE_EXEMPLAR",
    "Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL",
    "source-title-count: 12",
    "source-frame-count: 14",
    "frame-only-count: 2",
    "target-title-count: 1",
    "target-frame-count: 1",
    "target-gmtitle-pair-count: 1",
    "native-like-target-pair-count: 1",
    "non-native-like-target-pair-count: 0",
    "log-evidence-note-found: yes",
    "automation-split-note-found: yes",
    "human-check-note-found: yes",
    "title-missing-deferred-note-found: no",
    "verify-source-priority-note-found: no",
    "verify-title-missing-first-note-found: no",
    "frame-definition-blockers: 0",
    "frame-embedded-cleanup-records: 0",
    "next-bootstrap-source-sheet: A3",
    "next-bootstrap-frame: DR_A3_Outline",
    "next-bootstrap-title: DR_titlea_3rd",
    "next-missing-native-source-sheet: A3",
    "next-missing-native-frame: DR_A3_Outline",
    "next-missing-native-title: DR_titlea_3rd",
    "next-missing-native-role: title-sheet",
    "missing-native-frame: DR_A3_Outline",
    "missing-native-frame: DR_A4_Outline",
    "first-native-guidance-ok: no",
    "A2: 1",
    "A3: 12",
    "A4: 2",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 4. A4 native exemplar gap probe ====="
& (Join-Path $PSScriptRoot "run_a4_native_exemplar_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $a4NativeExemplarLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $a4NativeExemplarLog `
  -Label "A4 native exemplar gap probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260707-unified-title-missing-13",
    "DBMOD before checks: 0",
    "Source frame-only count: 2",
    "A2: 1",
    "A3: 12",
    "A4: 2",
    "Current target sheet counts:",
    "A2: 1",
    "A4 outline definition status: missing",
    "Definition exists: no",
    "Visible DR_A4_Outline frame inserts: 0",
    "Native GMTITLE A4 pair evidence: no",
    "Result: A4_NATIVE_EXEMPLAR_MISSING_DEFINITION",
    "No drawing data was saved.",
    "DBMOD after checks: 0",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 5. A4 outline native outside marker prepare probe ====="
& (Join-Path $PSScriptRoot "run_a4_outline_prepare_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -ProbeDwgPath (Join-Path $workDir "swtitle_a4_outline_prepare_probe_main56_default.dwg") `
  -LogPath $a4OutlinePrepareLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $a4OutlinePrepareLog `
  -Label "A4 outline native outside marker prepare probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260707-unified-title-missing-13",
    "Before definition status: missing",
    "Before frame-only-count: 2",
    "Before target-sheet-counts:",
    "A2: 1",
    "Before DR_A4_Outline definition details:",
    "Definition exists: no",
    "Prepare result: OK status=OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED",
    "After definition status: ready-native-outside-markers",
    "After frame-only-count: 2",
    "After target-sheet-counts:",
    "A2: 1",
    "After DR_A4_Outline definition details:",
    "Definition exists: yes",
    "Test insert effective bbox: (0, 0) - (210, 297)",
    "Test insert geometry warning: <none>",
    "Test insert raw selection warning: <none>",
    "Native check result: OK status=",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 6. Title-missing outline convert probe (A4-sized source-title-missing sample) ====="
& (Join-Path $PSScriptRoot "run_a4_outline_convert_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -ProbeDwgPath (Join-Path $workDir "swtitle_a4_outline_convert_probe_main56_default.dwg") `
  -LogPath $a4OutlineConvertLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $a4OutlineConvertLog `
  -Label "Title-missing outline convert probe (A4-sized source-title-missing sample)" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260707-unified-title-missing-13",
    "Before source-title-count: 12",
    "Before frame-only-count: 2",
    "Before target title count: 1",
    "Before DR_A4_Outline target frame count: 0",
    "Prepare result: OK status=OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED",
    "After prepare definition status: ready-native-outside-markers",
    "Convert result: OK status=FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER",
    "After source-title-count: 12",
    "After frame-only-count: 1",
    "After target title count: 1",
    "After DR_A4_Outline target frame count: 1",
    "After target-sheet-counts:",
    "A2: 1",
    "A4: 1",
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
    "Loaded version: 260707-unified-title-missing-13",
    "SWTITLECONVERT result: OK",
    "Script active before convert: yes",
    "Status after convert: ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE",
    "Source titles before/after: 12/12",
    "Source frames before/after: 14/14",
    "Frame-only before/after: 2/2",
    "Target titles before/after: 1/1",
    "Target frames before/after: 1/1",
    "INSERT count before/after: 120/120",
    "DBMOD before/after: 0/0",
    "Convert script guard preserved drawing: yes",
    "Runtime check completed: yes"
  )

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
    "Loaded version: 260707-unified-title-missing-13",
    "DR_A2_Outline: class=native-format-with-title-geometry",
    "DR_A3_Outline: class=native-format-with-title-geometry",
    "DR_A4_Outline: class=native-format-with-title-geometry",
    "Style-normalization record count: 3",
    "Style-normalization clean entity count: 12",
    "Style-normalization deleted count: 12",
    "Style-normalization record count after clean: 0",
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
    "Loaded version: 260707-unified-title-missing-13",
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
    "Loaded version: 260707-unified-title-missing-13",
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
    "Loaded version: 260707-unified-title-missing-13",
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
    "Loaded version: 260707-unified-title-missing-13",
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
    "Loaded version: 260707-unified-title-missing-13",
    "Adoption function present: yes",
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
    "Loaded version: 260707-unified-title-missing-13",
    "Bootstrap before fixture: A2 / DR_A2_Outline / DR_titlea_3rd",
    "A2 marker-only title native-link kinds: <none>",
    "Source title count after fixture: 12",
    "Native-like pair count after fixture: 0",
    "Missing native frames after fixture: DR_A3_Outline, DR_A4_Outline",
    "Next missing native selection after fixture: A3 / DR_A3_Outline / DR_titlea_3rd / title-sheet",
    "Status after SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE",
    "Expected gate: marker-only A2 target is not accepted as the first native GMTITLE.",
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
    "Loaded version: 260707-unified-title-missing-13",
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
    "Loaded version: 260707-unified-title-missing-13",
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

Set-Content -LiteralPath $suiteLastRunLog -Encoding UTF8 -Value @(
  "===== GMTITLE main56 verification suite last run =====",
  ("Generated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss K")),
  ("Repo root: {0}" -f $repoRoot),
  ("Source work copy: {0}" -f $SourceWorkCopyPath),
  ("Probe window style: {0}" -f $ProbeWindowStyle),
  ("Timeout seconds: {0}" -f $TimeoutSeconds),
  "Result: PASS",
  "Verified markers:",
  "  no-CAD next-action card probe: PASS",
  "  visible work-copy opener dry-run: PASS",
  "  GstarCAD /b script smoke probe: PASS",
  "  Loader probe: PASS",
  "  Current LSP copy compare probe: PASS",
  "  Actual work-copy status probe: PASS",
  "  A4 native exemplar gap probe: PASS",
  "  A4 outline native outside marker prepare probe: PASS",
  "  Title-missing outline convert probe (A4-sized source-title-missing sample): PASS",
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
  -A4OutlinePrepareLogPath $a4OutlinePrepareLog `
  -A4OutlineConvertLogPath $a4OutlineConvertLog `
  -A3StatusGuidanceLogPath $a3StatusGuidanceLog `
  -A3A4BatchGuardLogPath $a3a4BatchGuardLog
$script:suiteLastRunCompleted = $true
Write-Output ("Suite last-run summary: {0}" -f $suiteLastRunLog)
