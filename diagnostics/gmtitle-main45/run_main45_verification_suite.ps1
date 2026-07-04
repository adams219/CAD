param(
  [string]$SourceWorkCopyPath,

  [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"
$compareDir = Join-Path $workDir "lsp_compare"

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

$loaderLog = Join-Path $workDir "swtitle_loader_probe_main56_diagnostics.txt"
$copyCompareLog = Join-Path $workDir "swtitle_lsp_copy_compare_current_main56.txt"
$actualStatusLog = Join-Path $workDir "swtitle_actual_workcopy_status_main56_diagnostics.txt"
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
    "Loaded GMTITLE version: 260705-verify-source-priority-multidocguard",
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
    "Loaded version: 260705-verify-source-priority-multidocguard",
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
    "Loaded version: 260705-verify-source-priority-multidocguard",
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
Write-Output "===== 4. SWTITLECONVERT script guard probe ====="
& (Join-Path $PSScriptRoot "run_convert_script_guard_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $convertScriptGuardLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $convertScriptGuardLog `
  -Label "SWTITLECONVERT script guard probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260705-verify-source-priority-multidocguard",
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
Write-Output "===== 5. Common A2/A3/A4 frame-definition probe ====="
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
Write-Output "===== 6. A2/A3/A4 style-normalization rebuild cleanup probe ====="
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
    "Loaded version: 260705-verify-source-priority-multidocguard",
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
Write-Output "===== 7. Command-text guard comparison probe ====="
& (Join-Path $PSScriptRoot "run_command_text_guard_compare_probe.ps1") `
  -LspPath $sourceLsp `
  -Label "current_main56_command_text_guard" `
  -LogPath $commandTextGuardLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $commandTextGuardLog `
  -Label "command-text guard comparison probe" `
  -Patterns @(
    "Loaded version: 260705-verify-source-priority-multidocguard",
    "command-text-count-before: 1",
    "SWTITLESTATUS result: OK status=NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT",
    "structure-next-action: SWTITLEPREPARE",
    "convert-status-after: ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST",
    "danger-action-after-convert: <none>",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 8. Sheet residue protection probe ====="
& (Join-Path $PSScriptRoot "run_residue_protection_probe.ps1") `
  -LspPath $sourceLsp `
  -Label "current_main56_residue_protection" `
  -LogPath $residueProtectionLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $residueProtectionLog `
  -Label "sheet residue protection probe" `
  -Patterns @(
    "Loaded version: 260705-verify-source-priority-multidocguard",
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
Write-Output "===== 9. Embedded-title prepare comparison probe ====="
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
    "Loaded version: 260705-verify-source-priority-multidocguard",
    "DR_A2_Outline: class=native-format-with-title-geometry, embedded=4",
    "DR_A3_Outline: class=native-format-with-title-geometry, embedded=4",
    "DR_A4_Outline: class=native-format-with-title-geometry, embedded=4",
    "Cleanup records by frame:",
    "<none>",
    "Structure next action: SWTITLECONVERT",
    "Cleanup result: OK",
    "Cleanup deleted count: 0",
    "Cleanup record count after clean: 0",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output ""
Write-Output "===== 10. Duplicate target pair comparison probe ====="
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
    "Loaded version: 260705-verify-source-priority-multidocguard",
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
Write-Output "===== 11. Native adoption gate comparison probe ====="
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
    "Loaded version: 260705-verify-source-priority-multidocguard",
    "Adoption function present: yes",
    "Status after transfer: ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER",
    "Danger action: <none>",
    "Source title count before/after: 1/0",
    "Target title count before/after: 1/1",
    "Adoption gate probe passed: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 12. A3 status guidance probe ====="
& (Join-Path $PSScriptRoot "run_a3_status_guidance_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $a3StatusGuidanceLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $a3StatusGuidanceLog `
  -Label "A3 status guidance probe" `
  -Patterns @(
    "Loaded version: 260705-verify-source-priority-multidocguard",
    "A3/A4 candidate count before SWTITLESTATUS: 1",
    "SWTITLESTATUS result: OK",
    "Status after SWTITLESTATUS: NEXT_UPGRADE_A3_A4_NATIVE",
    "A3 frame guidance note found: yes",
    "A3 native-candidate supplement found: yes",
    "A3 status guidance probe passed: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "===== 13. A3/A4 batch guard probe ====="
& (Join-Path $PSScriptRoot "run_a3a4_batch_guard_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -LogPath $a3a4BatchGuardLog `
  -TimeoutSeconds $TimeoutSeconds
Assert-LogContains `
  -Path $a3a4BatchGuardLog `
  -Label "A3/A4 batch guard probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260705-verify-source-priority-multidocguard",
    "Script active: yes",
    "Batch result: OK",
    "Status after batch: ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE",
    "Candidates before/after: 2/2",
    "INSERT count before/after: 4/4",
    "Batch guard preserved candidates: yes",
    "Runtime check completed: yes"
  )

Write-Output ""
Write-Output "All expected log markers were verified."
Write-Output "===== GMTITLE main56 verification suite complete ====="
