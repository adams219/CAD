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

Write-Output "===== Preflight. Next CAD action card probe (no CAD) ====="
& (Join-Path $PSScriptRoot "run_next_cad_action_card_probe.ps1")
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
    "Loaded loader version: 260705-4step-gmtitle-a4-outline-preflight",
    "Loaded GMTITLE version: 260705-convertnext-selection-guide",
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
    "Loaded version: 260705-convertnext-selection-guide",
    "Command-line -GMTITLE default enabled: no",
    "SCRIPT command-line -GMTITLE enabled: no",
    "Command c:SWTITLESTATUS: yes",
    "Command c:SWTITLEPREPARE: yes",
    "Command c:SWTITLECONVERT: yes",
    "Command c:SWTITLEVERIFY: yes",
    "Command c:SWTITLEFASTSTATUS: no",
    "Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE",
    "Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL",
    "source-title-count: 13",
    "source-frame-count: 15",
    "frame-only-count: 2",
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
    "Loaded version: 260705-convertnext-selection-guide",
    "Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE",
    "Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL",
    "source-title-count: 13",
    "source-frame-count: 15",
    "frame-only-count: 2",
    "target-title-count: 0",
    "target-frame-count: 0",
    "log-evidence-note-found: yes",
    "automation-split-note-found: yes",
    "human-check-note-found: yes",
    "a4-frame-only-deferred-note-found: yes",
    "verify-source-priority-note-found: yes",
    "verify-a4-frame-only-first-note-found: no",
    "frame-definition-blockers: 0",
    "frame-embedded-cleanup-records: 0",
    "next-bootstrap-source-sheet: A2",
    "next-bootstrap-frame: DR_A2_Outline",
    "next-bootstrap-title: DR_titlea_3rd",
    "missing-native-frame: DR_A2_Outline",
    "missing-native-frame: DR_A3_Outline",
    "missing-native-frame: DR_A4_Outline",
    "first-native-guidance-ok: yes",
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
    "Loaded version: 260705-convertnext-selection-guide",
    "DBMOD before checks: 0",
    "Source frame-only count: 2",
    "A2: 1",
    "A3: 12",
    "A4: 2",
    "Current target sheet counts:",
    "<none>",
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
    "Loaded version: 260705-convertnext-selection-guide",
    "Before definition status: missing",
    "Before frame-only-count: 2",
    "Before target-sheet-counts:",
    "<none>",
    "Before DR_A4_Outline definition details:",
    "Definition exists: no",
    "Prepare result: OK status=OK_A4_FRAME_ONLY_OUTLINE_DEFINITION_IMPORTED",
    "After definition status: ready-native-outside-markers",
    "After frame-only-count: 2",
    "After target-sheet-counts:",
    "<none>",
    "After DR_A4_Outline definition details:",
    "Definition exists: yes",
    "Test insert effective bbox: (0, 0) - (210, 297)",
    "Test insert geometry warning: <none>",
    "Test insert raw selection warning: <none>",
    "Native check result: OK status=",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 6. A4 outline frame-only convert probe ====="
& (Join-Path $PSScriptRoot "run_a4_outline_convert_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -ProbeDwgPath (Join-Path $workDir "swtitle_a4_outline_convert_probe_main56_default.dwg") `
  -LogPath $a4OutlineConvertLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $a4OutlineConvertLog `
  -Label "A4 outline frame-only convert probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260705-convertnext-selection-guide",
    "Before source-title-count: 13",
    "Before frame-only-count: 2",
    "Before target title count: 0",
    "Before DR_A4_Outline target frame count: 0",
    "Prepare result: OK status=OK_A4_FRAME_ONLY_OUTLINE_DEFINITION_IMPORTED",
    "After prepare definition status: ready-native-outside-markers",
    "Convert result: OK status=FINALIZED_A4_FRAME_ONLY_OUTLINE_TRANSFER",
    "After source-title-count: 13",
    "After frame-only-count: 1",
    "After target title count: 0",
    "After DR_A4_Outline target frame count: 1",
    "After target-sheet-counts:",
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
    "Loaded version: 260705-convertnext-selection-guide",
    "SWTITLECONVERT result: OK",
    "Script active before convert: yes",
    "Status after convert: ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE",
    "Source titles before/after: 13/13",
    "Source frames before/after: 15/15",
    "Frame-only before/after: 2/2",
    "Target titles before/after: 0/0",
    "Target frames before/after: 0/0",
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
    "Loaded version: 260705-convertnext-selection-guide",
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
    "Loaded version: 260705-convertnext-selection-guide",
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
    "Loaded version: 260705-convertnext-selection-guide",
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
    "Loaded version: 260705-convertnext-selection-guide",
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
    "Loaded version: 260705-convertnext-selection-guide",
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
    "Loaded version: 260705-convertnext-selection-guide",
    "Adoption function present: yes",
    "Status after transfer: ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER",
    "Danger action: <none>",
    "Source title count before/after: 1/0",
    "Target title count before/after: 1/1",
    "Adoption gate probe passed: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 15. A3 status guidance probe ====="
& (Join-Path $PSScriptRoot "run_a3_status_guidance_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $a3StatusGuidanceLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $a3StatusGuidanceLog `
  -Label "A3 status guidance probe" `
  -Patterns @(
    "Loaded version: 260705-convertnext-selection-guide",
    "A3/A4 candidate count before SWTITLESTATUS: 1",
    "SWTITLESTATUS result: OK",
    "Status after SWTITLESTATUS: NEXT_UPGRADE_A3_A4_NATIVE",
    "A3 frame guidance note found: yes",
    "A3 native-candidate supplement found: yes",
    "A3 status guidance probe passed: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 16. A3/A4 batch guard probe ====="
& (Join-Path $PSScriptRoot "run_a3a4_batch_guard_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $a3a4BatchGuardLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $a3a4BatchGuardLog `
  -Label "A3/A4 batch guard probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260705-convertnext-selection-guide",
    "Script active: yes",
    "Batch result: OK",
    "Status after batch: ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE",
    "Candidates before/after: 2/2",
    "INSERT count before/after: 4/4",
    "Batch guard preserved candidates: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 17. GMTITLE selection config probe ====="
& (Join-Path $PSScriptRoot "run_gmtitle_selection_config_probe.ps1") `
  -OutputPath $selectionConfigLog
Assert-LogContains `
  -Path $selectionConfigLog `
  -Label "GMTITLE selection config probe" `
  -Patterns @(
    "No DWG is opened or changed.",
    "[Program PaperSet.ini]",
    "[Program PaperSet.grx ASCII string scan]",
    "No active persistent DR_A*_Outline / DR_titlea_3rd preselection config was found in the checked locations.",
    "Direct GMTITLE may still reuse an internal/current command state and ask only for an insertion point.",
    "Do not assume a scratch native A4 sample was created unless the saved DWG passes run_a4_native_exemplar_probe.ps1.",
    "Result: GMTITLE_SELECTION_CONFIG_NOT_FOUND"
  )

Write-Output ""
Write-Output "All expected log markers were verified."
Write-Output "===== GMTITLE main56 verification suite complete ====="
