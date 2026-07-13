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
  "docs\swcad-workflow\architecture.md",
  "docs\swcad-workflow\test-results-2026-07-13.md"
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
  "diagnostics\swcad-workflow\workflow_integration_probe.lsp"
)) {
  Test-LispBalance (Join-Path $repoRoot $relative)
}

foreach ($relative in @(
  "apps\swcad-workflow\package.ps1",
  "diagnostics\swcad-workflow\run_static_preflight.ps1",
  "diagnostics\swcad-workflow\run_xref_materialize_matrix.ps1",
  "diagnostics\swcad-workflow\run_workflow_loader_probe.ps1",
  "diagnostics\swcad-workflow\run_workflow_integration_probe.ps1"
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
$appText = Read-Utf8 $appPath
$loaderText = Read-Utf8 $loaderPath
$packageText = Read-Utf8 $packagePath

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
  "DIMENSION_SEMANTICS",
  "swapp-restore-dimension-semantic-snapshots",
  "SWCAD_DIMENSION_SEMANTICS_CHANGED",
  "MANUAL_FRAME_COORDINATES",
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

foreach ($needle in @(
  "[StringComparison]::OrdinalIgnoreCase",
  "Remove-Item -LiteralPath `$packageFull -Recurse",
  "Install_SWCAD_Workflow.cmd",
  "SWCAD_Workflow_Load.lsp",
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
