$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$failures = New-Object System.Collections.Generic.List[string]

$required = @(
  "apps\swcad-workflow\swcad_workflow.lsp",
  "apps\swcad-workflow\swcad_workflow_load.lsp",
  "apps\swcad-workflow\package.ps1",
  "apps\swcad-workflow\README.md",
  "diagnostics\swcad-workflow\module-baseline.sha256",
  "diagnostics\swcad-workflow\xref_materialize_probe.lsp",
  "diagnostics\swcad-workflow\run_xref_materialize_matrix.ps1",
  "diagnostics\swcad-workflow\workflow_loader_probe.lsp",
  "diagnostics\swcad-workflow\run_workflow_loader_probe.ps1",
  "diagnostics\swcad-workflow\workflow_integration_probe.lsp",
  "diagnostics\swcad-workflow\run_workflow_integration_probe.ps1",
  "diagnostics\swcad-workflow\legacy_count_rebase_probe.lsp",
  "diagnostics\swcad-workflow\run_legacy_count_rebase_probe.ps1",
  "diagnostics\swcad-workflow\cleanup_state_probe.lsp",
  "diagnostics\swcad-workflow\cleanup_symbol_table_probe.lsp",
  "diagnostics\swcad-workflow\cleanup_identity_delta_probe.lsp",
  "diagnostics\swcad-workflow\cleanup_anonymous_block_probe.lsp",
  "diagnostics\swcad-workflow\analyze_cleanup_identity_delta.ps1",
  "docs\swcad-workflow\architecture.md",
  "docs\swcad-workflow\test-results-2026-07-13.md",
  "docs\swcad-workflow\full-unused-definition-cleanup-test-2026-07-14.md"
)

function Add-Failure {
  param([string]$Message)
  [void]$failures.Add($Message)
}

function Read-Utf8 {
  param([string]$Path)
  [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}

function Test-LispBalance {
  param([string]$Path)
  $text = Read-Utf8 $Path
  $depth = 0
  $minimum = 0
  $inString = $false
  $escaped = $false
  $comment = $false
  foreach ($char in $text.ToCharArray()) {
    if ($char -eq "`n") {
      $comment = $false
      continue
    }
    if ($comment) { continue }
    if ($inString) {
      if ($escaped) {
        $escaped = $false
        continue
      }
      if ($char -eq "\") {
        $escaped = $true
        continue
      }
      if ($char -eq '"') { $inString = $false }
      continue
    }
    if ($char -eq ";") {
      $comment = $true
      continue
    }
    if ($char -eq '"') {
      $inString = $true
      continue
    }
    if ($char -eq "(") { $depth++ }
    if ($char -eq ")") {
      $depth--
      if ($depth -lt $minimum) { $minimum = $depth }
    }
  }
  if (($depth -ne 0) -or ($minimum -ne 0) -or $inString) {
    Add-Failure "LISP balance failed: $Path (depth=$depth minimum=$minimum inString=$inString)"
  } else {
    Write-Output "LISP balance: PASS - $Path"
  }
}

function Test-PowerShellSyntax {
  param([string]$Path)
  $tokens = $null
  $errors = $null
  [void][Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
  if ($errors.Count -gt 0) {
    Add-Failure "PowerShell parse failed: $Path - $($errors[0].Message)"
  } else {
    Write-Output "PowerShell parse: PASS - $Path"
  }
}

function Assert-Contains {
  param([string]$Text, [string]$Needle, [string]$Label)
  if (-not $Text.Contains($Needle)) {
    Add-Failure "$Label missing: $Needle"
  }
}

function Assert-NotContains {
  param([string]$Text, [string]$Needle, [string]$Label)
  if ($Text.Contains($Needle)) {
    Add-Failure "$Label must not contain: $Needle"
  }
}

foreach ($relative in $required) {
  $path = Join-Path $repoRoot $relative
  if (-not (Test-Path -LiteralPath $path)) {
    Add-Failure "Required file missing: $relative"
  }
}

foreach ($relative in @(
  "apps\swcad-workflow\swcad_workflow.lsp",
  "apps\swcad-workflow\swcad_workflow_load.lsp",
  "diagnostics\swcad-workflow\xref_materialize_probe.lsp",
  "diagnostics\swcad-workflow\workflow_loader_probe.lsp",
  "diagnostics\swcad-workflow\workflow_integration_probe.lsp",
  "diagnostics\swcad-workflow\legacy_count_rebase_probe.lsp",
  "diagnostics\swcad-workflow\cleanup_state_probe.lsp",
  "diagnostics\swcad-workflow\cleanup_symbol_table_probe.lsp",
  "diagnostics\swcad-workflow\cleanup_identity_delta_probe.lsp",
  "diagnostics\swcad-workflow\cleanup_anonymous_block_probe.lsp"
)) {
  Test-LispBalance (Join-Path $repoRoot $relative)
}

foreach ($relative in @(
  "apps\swcad-workflow\package.ps1",
  "diagnostics\swcad-workflow\run_static_preflight.ps1",
  "diagnostics\swcad-workflow\run_xref_materialize_matrix.ps1",
  "diagnostics\swcad-workflow\run_workflow_loader_probe.ps1",
  "diagnostics\swcad-workflow\run_workflow_integration_probe.ps1",
  "diagnostics\swcad-workflow\run_legacy_count_rebase_probe.ps1",
  "diagnostics\swcad-workflow\analyze_cleanup_identity_delta.ps1"
)) {
  Test-PowerShellSyntax (Join-Path $repoRoot $relative)
}

$manifestPath = Join-Path $repoRoot "diagnostics\swcad-workflow\module-baseline.sha256"
foreach ($line in Get-Content -LiteralPath $manifestPath) {
  if (($line -eq "") -or $line.StartsWith("#")) { continue }
  if ($line -notmatch '^([0-9A-Fa-f]{64})\s+(.+)$') {
    Add-Failure "Invalid module baseline line: $line"
    continue
  }
  $expectedHash = $matches[1].ToUpperInvariant()
  $relative = $matches[2].Replace("/", "\")
  $path = Join-Path $repoRoot $relative
  if (-not (Test-Path -LiteralPath $path)) {
    Add-Failure "Baseline module missing: $relative"
    continue
  }
  $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
  if ($actualHash -ne $expectedHash) {
    Add-Failure "Canonical module changed: $relative expected=$expectedHash actual=$actualHash"
  } else {
    Write-Output "Canonical module hash: PASS - $relative"
  }
}

$appPath = Join-Path $repoRoot "apps\swcad-workflow\swcad_workflow.lsp"
$loaderPath = Join-Path $repoRoot "apps\swcad-workflow\swcad_workflow_load.lsp"
$packagePath = Join-Path $repoRoot "apps\swcad-workflow\package.ps1"
$gmtitlePath = Join-Path $repoRoot "src\tools\gmtitle\swcad_title_scale.lsp"
$appText = Read-Utf8 $appPath
$loaderText = Read-Utf8 $loaderPath
$packageText = Read-Utf8 $packagePath
$gmtitleText = Read-Utf8 $gmtitlePath
$integrationProbeText = Read-Utf8 (Join-Path $repoRoot "diagnostics\swcad-workflow\workflow_integration_probe.lsp")
$integrationRunnerText = Read-Utf8 (Join-Path $repoRoot "diagnostics\swcad-workflow\run_workflow_integration_probe.ps1")
$rebaseProbeText = Read-Utf8 (Join-Path $repoRoot "diagnostics\swcad-workflow\legacy_count_rebase_probe.lsp")
$rebaseRunnerText = Read-Utf8 (Join-Path $repoRoot "diagnostics\swcad-workflow\run_legacy_count_rebase_probe.ps1")

$commands = [regex]::Matches($appText, '(?m)^\(defun c:(SWCAD[^\s(]*)') | ForEach-Object { $_.Groups[1].Value }
$expectedCommands = @("SWCADSTATUS", "SWCADRUN", "SWCADVERIFY")
if (($commands.Count -ne 3) -or ((Compare-Object $expectedCommands $commands).Count -ne 0)) {
  Add-Failure "Public SWCAD commands differ. Actual: $($commands -join ', ')"
} else {
  Write-Output "Public command surface: PASS - $($commands -join ', ')"
}

$appVersion = [regex]::Match($appText, '\*swapp-version\*\s+"([^"]+)"').Groups[1].Value
$loaderVersion = [regex]::Match($loaderText, '\*swapp-loader-version\*\s+"([^"]+)"').Groups[1].Value
if (($appVersion -eq "") -or ($appVersion -ne $loaderVersion)) {
  Add-Failure "App/loader version mismatch: app=$appVersion loader=$loaderVersion"
}

foreach ($needle in @(
  "src/tools/gmtitle/swcad_title_scale.lsp",
  "src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance.lsp",
  "src/tools/gstarcad-layout/gstarcad_layout_from_model.lsp",
  "apps/swcad-workflow/swcad_workflow.lsp"
)) {
  Assert-Contains $loaderText $needle "Loader dependency"
}
Assert-Contains $loaderText "((swapp-loader-root-valid-p derived) derived)" "Loader location priority"

foreach ($needle in @(
  "BLOCKED_NATIVE_GMTITLE_XREF",
  "BLOCKED_NESTED_OR_UNREFERENCED_XREF",
  "BLOCKED_UNSUPPORTED_XREF_TRANSFORM",
  "vla-Bind",
  "swapp-explode-reference",
  "swapp-sheet-wrapper-records",
  "swapp-materialize-sheet-wrappers",
  "swapp-model-expandable-dimension-count",
  "swapp-explode-dimension-containers",
  "target-frame-references",
  "target-title-references",
  "BLOCKED_NATIVE_GMTITLE_SHEET_WRAPPER",
  "SWCAD_SHEET_WRAPPER_MATERIALIZE_OK",
  "SHEET_WRAPPERS",
  "swapp-stage-label",
  "swapp-title-action-label",
  "swapp-title-blocking-status-p",
  '"ABORT_"',
  '"ERROR_"',
  '"WARN_"',
  '"SWTITLEVERIFY_FINAL_FAIL"',
  "swapp-recommended-next-action",
  "swapp-resource-cleanup-retry-allowed-p",
  "cleanup-retry-blocked",
  "DIMENSION_SEMANTICS",
  "swapp-restore-dimension-semantic-snapshots",
  "SWCAD_DIMENSION_SEMANTICS_CHANGED",
  "XREF_SOURCE_FILENAME_COORDINATES",
  "CAPTURED_BEFORE_BIND",
  "SOURCE_SHEET_STATUS",
  "SOURCE_SHEET_COUNT",
  "FINAL_SHEET_COUNT",
  "LAYOUT_OWNED_COUNT",
  "SOURCE_FILE_STEM_NO_PREFIX_NO_SEQUENCE",
  "swapp-run-resource-cleanup",
  "swapp-native-purge-named-pass",
  "swapp-native-purge-category",
  "swapp-named-definition-snapshot",
  "swapp-named-definition-signature",
  "swapp-named-definition-identity-signature",
  "swapp-named-definition-stable-identity-signature",
  "swapp-named-definition-appid-identity-signature",
  "swapp-appid-definition-record-p",
  "swapp-named-definition-vport-identity-signature",
  "swapp-vport-definition-record-p",
  "swapp-session-empty-anonymous-block-definition-record-p",
  "swapp-named-definition-session-anonymous-block-identity-signature",
  "swapp-volatile-definition-record-p",
  "swapp-definition-records-exclude-identities",
  "swapp-definition-record-identity",
  "swapp-definition-record-identities",
  "swapp-print-definition-record-sample",
  "swapp-dictionary-definition-handle-token",
  "swapp-dictionary-entry-record",
  "swapp-dictionary-entries-from-entget",
  "swapp-dictionary-entries-from-dictnext",
  "alternating group 3 + 350/360 pairs",
  "<WORKFLOW-STATE-XRECORD>",
  "swapp-layout-integrity-snapshot",
  "swapp-entity-persistent-data-snapshot",
  "swapp-extension-dictionary-integrity-snapshot",
  "swapp-gmtitle-native-target-snapshot",
  "swapp-title-attribute-structure-snapshot",
  "RESOURCE_CLEANUP_DEFINITION_SIGNATURE",
  "RESOURCE_CLEANUP_DEFINITION_IDENTITY_SIGNATURE",
  "RESOURCE_CLEANUP_STABLE_DEFINITION_IDENTITY_SIGNATURE",
  "RESOURCE_CLEANUP_APPID_IDENTITY_SIGNATURE",
  "RESOURCE_CLEANUP_VPORT_IDENTITY_SIGNATURE",
  "RESOURCE_CLEANUP_SESSION_ANON_BLOCK_IDENTITY_SIGNATURE",
  "RESOURCE_CLEANUP_STABLE_IDENTITY_EXCLUDED",
  "RESOURCE_CLEANUP_ZERO_PASS",
  "RESOURCE_CLEANUP_ADDED_IDENTITIES",
  "RESOURCE_CLEANUP_ADDED_RECORDS",
  "RESOURCE_CLEANUP_HANDLE_REREGISTERED",
  "RESOURCE_CLEANUP_POST_SAVE_HANDLE_REREGISTERED",
  "RESOURCE_CLEANUP_STATE_SAVE_STABILIZATION_PASSES",
  "RESOURCE_CLEANUP_STATE_SAVE_REBASE_COUNT",
  "RESOURCE_CLEANUP_STATE_SAVE_REMOVED_SAMPLE",
  "RESOURCE_CLEANUP_STATE_SAVE_ADDED_SAMPLE",
  "RESOURCE_CLEANUP_STATE_SAVE_HANDLE_REREGISTERED",
  "FAILED_POST_SAVE_CHANGE",
  "FAILED_PRE_SAVE",
  "FAILED_STATE_SAVE_NOT_CONVERGED",
  "FAILED_STATE_SAVE_AUDIT",
  "swapp-resource-cleanup-success-state-items",
  "*swapp-resource-cleanup-state-save-max-passes*",
  "ALL_UNUSED_NAMED_DEFINITIONS_V5",
  "ZERO_LENGTH|EMPTY_TEXT|ORPHANED_DATA",
  "swapp-layout-plan",
  "swapp-print-layout-plan-items",
  "LAYOUT_PLAN_COUNT",
  "LAYOUT_PLAN_SIGNATURE",
  "SWCAD-SHEET",
  "SWCADVERIFY_FINAL_OK"
)) {
  Assert-Contains $appText $needle "Workflow safety contract"
}
Assert-NotContains $appText "vla-Move" "Manual placement policy"
Assert-NotContains $appText "_.MOVE" "Manual placement policy"
Assert-NotContains $appText "*swapp-layout-prefix*" "Prefix-free Layout ownership policy"
Assert-NotContains $appText '"_All"' "Named-definition-only purge policy"
Assert-NotContains $appText '"_Zero-length' "Named-definition-only purge policy"
Assert-NotContains $appText '"_Empty text' "Named-definition-only purge policy"
Assert-NotContains $appText '"_Orphaned' "Named-definition-only purge policy"
Assert-NotContains $appText "FAILED_DEFINITION_ADDED" "PURGE auto-created definition convergence policy"
Assert-NotContains $appText "strcmp" "GstarCAD AutoLISP compatibility"
Assert-Contains $appText '(equal (nth 2 fields) "*ACTIVE")' "Session-only VPORT policy"
Assert-Contains $appText '"APPID|VPORT|EMPTY_ANONYMOUS_BLOCK"' "Cross-session volatile definition disclosure"
Assert-Contains $appText "initial-volatile-identities" "Stable removed-definition diagnostic policy"

$dimStageIndex = $appText.IndexOf('((not (swapp-dimstyle-marked-p)) "DIMSTYLE")')
$layoutStageIndex = $appText.IndexOf('((not (swapp-layout-state-valid-p frames)) "LAYOUT")')
$cleanupStageIndex = $appText.IndexOf('((not (swapp-cached-resource-cleanup-verify)) "CLEANUP")')
if (($dimStageIndex -lt 0) -or ($layoutStageIndex -le $dimStageIndex) -or ($cleanupStageIndex -le $layoutStageIndex)) {
  Add-Failure "Workflow stage order must remain DIMSTYLE -> LAYOUT -> CLEANUP"
}
foreach ($needle in @(
  '("BLOCK" "_Block")',
  '("DIMSTYLE" "D")',
  '("GROUP" "_Groups")',
  '("LAYER" "_Layers")',
  '("LINETYPE" "_LTypes")',
  '("MATERIAL" "_Materials")',
  '("MLEADERSTYLE" "MU")',
  '("PLOTSTYLE" "_Plotstyles")',
  '("SHAPE" "_SHapes")',
  '("TEXTSTYLE" "_STyles")',
  '("MLINESTYLE" "_Mlinestyles")',
  '("TABLESTYLE" "_Tablestyles")',
  '("VISUALSTYLE" "_Visualstyles")',
  '("REGAPP" "R")'
)) {
  Assert-Contains $appText $needle "Named-definition purge category contract"
}

foreach ($needle in @(
  "swapp-read-cache-begin",
  "swapp-read-cache-end",
  "swapp-cached-title-evidence",
  "swapp-cached-resource-cleanup-verify",
  "swapp-command-performance-end",
  "*swapp-last-command-title-insert-scans*",
  "swcad-title-target-gmtitle-pair-records-from",
  "swapp-sheet-wrapper-definition-evidence",
  "swapp-sheet-wrapper-status-records",
  "swapp-model-insert-objects",
  "swapp-model-dimension-objects"
)) {
  Assert-Contains $appText $needle "Command-scoped inventory performance contract"
}
$fullModelObjectScan = '(foreach object (swapp-collection-items (swapp-model))'
$fullModelObjectScanCount = ([regex]::Matches($appText, [regex]::Escape($fullModelObjectScan))).Count
if ($fullModelObjectScanCount -ne 1) {
  Add-Failure "Full model COM object scans must remain limited to the bbox safety audit. Actual count: $fullModelObjectScanCount"
}
Assert-Contains $integrationProbeText "swapp-sheet-wrapper-status-records" "No duplicate post-materialize wrapper audit"
foreach ($needle in @(
  "swcad-title-read-scan-cache-begin",
  "swcad-title-all-insert-enames",
  "swcad-title-transfer-batch-source-records",
  "*swcad-title-batch-source-record*",
  "*swcad-title-native-upgrade-batch-remaining-hint*",
  "(setq current (nth (1- index) records))"
)) {
  Assert-Contains $gmtitleText $needle "GMTITLE scan/queue performance contract"
}
Assert-NotContains $gmtitleText "(setq records (swcad-title-a3a4-native-upgrade-candidate-records))`r`n            (if" "Per-sheet native-upgrade full rescan"

Assert-Contains $integrationProbeText "(= source-frames 30)" "Wrapped-XREF source-frame classifier expectation"
Assert-NotContains $integrationProbeText "(= source-frames 41)" "Stale wrapped-XREF false source-frame count"
Assert-Contains $integrationRunnerText '"Source frame count: 30"' "Wrapped-XREF runner corrected frame count"
Assert-Contains $integrationRunnerText 'PrepareOnly' "Visible-CAD integration script preparation mode"
Assert-Contains $appText '*swcad-title-legacy-count-compatibility-enabled*' "Integrated legacy-count compatibility gate"
Assert-Contains $appText 'legacy-compat-enabled' "Integrated legacy-count compatibility status output"
Assert-Contains $rebaseProbeText "swcad-title-rebase-expected-counts-for-complete-targets" "Legacy count rebase runtime coverage"
Assert-Contains $rebaseProbeText "Native structure unchanged:" "Legacy count rebase native structure guard"
Assert-Contains $rebaseProbeText "Legacy compatibility read-only:" "Legacy count compatibility read-only runtime guard"
Assert-Contains $rebaseProbeText "Public SWCADVERIFY read-only:" "Public legacy compatibility runtime guard"
Assert-Contains $rebaseRunnerText "Source DWG hash changed" "Legacy count rebase source preservation gate"

foreach ($needle in @(
  "[StringComparison]::OrdinalIgnoreCase",
  "Remove-Item -LiteralPath `$packageFull -Recurse",
  "Install_SWCAD_Workflow.cmd",
  "SWCAD_Workflow_Load.lsp",
  '$checksumPath = "$zipPath.sha256"',
  "Get-FileHash -LiteralPath `$zipFull -Algorithm SHA256",
  "WriteAllText(",
  "docs\swcad-workflow\architecture.md",
  "docs\swcad-workflow\test-results-2026-07-13.md"
)) {
  Assert-Contains $packageText $needle "Package contract"
}

if ($failures.Count -gt 0) {
  Write-Output "===== SWCAD Workflow static preflight failures ====="
  $failures | ForEach-Object { Write-Output "- $_" }
  throw "SWCAD Workflow static preflight failed: $($failures.Count) issue(s)."
}

Write-Output "SWCAD Workflow static preflight: PASS"
