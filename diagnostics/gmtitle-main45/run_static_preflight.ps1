param(
  [string]$ExpectedGmtitleVersion = "260705-verify-source-priority-a4stepnote",

  [string]$ExpectedLoaderVersion = "260705-4step-gmtitle-a4-outline-preflight"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$mainLspPath = Join-Path $repoRoot "src\tools\gmtitle\swcad_title_scale.lsp"
$loaderPath = Join-Path $repoRoot "swcad_load.lsp"
$suitePath = Join-Path $PSScriptRoot "run_main45_verification_suite.ps1"
$readmePath = Join-Path $PSScriptRoot "README.md"
$a4NormProbePath = Join-Path $PSScriptRoot "a4_outline_normalization_probe.lsp"
$a4NormProbeRunnerPath = Join-Path $PSScriptRoot "run_a4_outline_normalization_probe.ps1"
$a4NativeProbeRunnerPath = Join-Path $PSScriptRoot "run_a4_native_exemplar_probe.ps1"
$selectionConfigProbePath = Join-Path $PSScriptRoot "run_gmtitle_selection_config_probe.ps1"
$goalStatusPath = Join-Path $PSScriptRoot "run_goal_status.ps1"
$guidePaths = @(
  "docs\guide\commands.md",
  "docs\guide\gmtitle-cad-conversion-checklist.md",
  "docs\guide\gmtitle-current-run-card.md",
  "docs\guide\gmtitle-goal-mode-plan.md",
  "docs\guide\gmtitle-native-frame-upgrade.md",
  "docs\guide\gmtitle-resume-on-another-computer.md"
) | ForEach-Object { Join-Path $repoRoot $_ }

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
  param([string]$Message)
  [void]$failures.Add($Message)
}

function Read-Text {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Required file not found: $Path"
  }
  [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path)
}

function Test-LispBalance {
  param(
    [string]$Text,
    [string]$Label
  )

  $depth = 0
  $minDepth = 0
  $line = 1
  $col = 0
  $inString = $false
  $escape = $false
  $comment = $false
  $firstBad = $null

  for ($i = 0; $i -lt $Text.Length; $i++) {
    $ch = $Text[$i]
    $col++

    if ($ch -eq "`n") {
      $line++
      $col = 0
      $comment = $false
      continue
    }
    if ($comment) {
      continue
    }
    if ($inString) {
      if ($escape) {
        $escape = $false
        continue
      }
      if ($ch -eq "\") {
        $escape = $true
        continue
      }
      if ($ch -eq '"') {
        $inString = $false
        continue
      }
      continue
    }
    if ($ch -eq ";") {
      $comment = $true
      continue
    }
    if ($ch -eq '"') {
      $inString = $true
      continue
    }
    if ($ch -eq "(") {
      $depth++
    } elseif ($ch -eq ")") {
      $depth--
      if ($depth -lt $minDepth) {
        $minDepth = $depth
        if (-not $firstBad) {
          $firstBad = "${line}:${col}"
        }
      }
    }
  }

  if (($depth -ne 0) -or ($minDepth -ne 0) -or $inString) {
    Add-Failure "$Label Lisp balance failed: depth=$depth minDepth=$minDepth inString=$inString firstBad=$firstBad"
  } else {
    Write-Output "$Label Lisp balance: OK"
  }
}

function Get-VersionValue {
  param(
    [string]$Text,
    [string]$VariableName
  )

  $pattern = '\(setq\s+' + [regex]::Escape($VariableName) + '\s+"([^"]+)"\)'
  $match = [regex]::Match($Text, $pattern)
  if ($match.Success) {
    return $match.Groups[1].Value
  }
  return $null
}

function Assert-Contains {
  param(
    [string]$Text,
    [string]$Needle,
    [string]$Label
  )

  if ($Text.Contains($Needle)) {
    Write-Output "${Label}: found"
  } else {
    Add-Failure "$Label missing: $Needle"
  }
}

function Assert-VersionInFile {
  param(
    [string]$Path,
    [string]$Version,
    [string]$Label
  )

  $text = Read-Text $Path
  if ($text.Contains($Version)) {
    Write-Output "${Label}: version found"
  } else {
    Add-Failure "${Label} missing expected version: $Version"
  }
}

$mainText = Read-Text $mainLspPath
$loaderText = Read-Text $loaderPath
$suiteText = Read-Text $suitePath
$readmeText = Read-Text $readmePath
$a4NormProbeText = Read-Text $a4NormProbePath
$a4NormProbeRunnerText = Read-Text $a4NormProbeRunnerPath
$a4NativeProbeRunnerText = Read-Text $a4NativeProbeRunnerPath
$selectionConfigProbeText = Read-Text $selectionConfigProbePath
$goalStatusText = Read-Text $goalStatusPath

Write-Output "===== GMTITLE static preflight ====="
Write-Output ("Repo root: {0}" -f $repoRoot)

Test-LispBalance -Text $mainText -Label "swcad_title_scale.lsp"
Test-LispBalance -Text $loaderText -Label "swcad_load.lsp"
Test-LispBalance -Text $a4NormProbeText -Label "a4_outline_normalization_probe.lsp"

$gmtitleVersion = Get-VersionValue -Text $mainText -VariableName "*swcad-title-scale-version*"
if ($gmtitleVersion -eq $ExpectedGmtitleVersion) {
  Write-Output ("GMTITLE version: {0}" -f $gmtitleVersion)
} else {
  Add-Failure "GMTITLE version mismatch: expected '$ExpectedGmtitleVersion', got '$gmtitleVersion'"
}

$loaderVersion = Get-VersionValue -Text $loaderText -VariableName "*swcad-version*"
if ($loaderVersion -eq $ExpectedLoaderVersion) {
  Write-Output ("Loader version: {0}" -f $loaderVersion)
} else {
  Add-Failure "Loader version mismatch: expected '$ExpectedLoaderVersion', got '$loaderVersion'"
}

$expectedPublicCommands = @(
  "SWTITLESTATUS",
  "SWTITLEPREPARE",
  "SWTITLECONVERT",
  "SWTITLEVERIFY",
  "SWTITLEVERSION",
  "SWSCALESCAN"
)
$publicCommands = @(
  [regex]::Matches($mainText, '(?m)^\s*\(defun\s+c:([A-Za-z0-9_-]+)\b') |
    ForEach-Object { $_.Groups[1].Value.ToUpperInvariant() } |
    Sort-Object -Unique
)
$missingPublic = @($expectedPublicCommands | Where-Object { $_ -notin $publicCommands })
$extraPublic = @($publicCommands | Where-Object { $_ -notin $expectedPublicCommands })
if (($missingPublic.Count -eq 0) -and ($extraPublic.Count -eq 0)) {
  Write-Output ("Public c: commands: {0}" -f ($publicCommands -join ", "))
} else {
  if ($missingPublic.Count -gt 0) {
    Add-Failure ("Missing public command(s): {0}" -f ($missingPublic -join ", "))
  }
  if ($extraPublic.Count -gt 0) {
    Add-Failure ("Unexpected public command(s): {0}" -f ($extraPublic -join ", "))
  }
}

$legacyPublicCommands = @(
  "SWTITLEFASTSTATUS",
  "SWTITLETRANSFERBOOTSTRAPFAST",
  "SWTITLETRANSFERFASTBATCH",
  "SWTITLEFRAMEONLYAPPLY",
  "SWTITLEA3A4NEXT",
  "SWTITLEGMTITLEVERIFYALL"
)
$legacyStillPublic = @($legacyPublicCommands | Where-Object { $_ -in $publicCommands })
if ($legacyStillPublic.Count -eq 0) {
  Write-Output "Legacy public commands: not exposed"
} else {
  Add-Failure ("Legacy public command(s) still exposed: {0}" -f ($legacyStillPublic -join ", "))
}

Assert-Contains -Text $mainText -Needle "swcad-title-a4-frame-only-outline-raw-a4-warning" -Label "A4 strict raw-bbox function"
Assert-Contains -Text $mainText -Needle "WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE" -Label "A4 unsafe definition status"
Assert-Contains -Text $mainText -Needle "ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE" -Label "Interactive GMTITLE script guard"
Assert-Contains -Text $mainText -Needle "ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE" -Label "A3/A4 batch script guard"
Assert-Contains -Text $suiteText -Needle "A4 outline strict prepare guard probe" -Label "Suite A4 strict prepare guard step"
Assert-Contains -Text $suiteText -Needle "WaitForGstarCADClose" -Label "Suite GstarCAD-close wait option"
Assert-Contains -Text $suiteText -Needle "Assert-NoExistingGstarCAD" -Label "Suite open-GstarCAD preflight"
Assert-Contains -Text $readmeText -Needle "-WaitForGstarCADClose" -Label "README waiting-mode guidance"
Assert-Contains -Text $readmeText -Needle "A4 strict prepare guard" -Label "README A4 strict guard guidance"
Assert-Contains -Text $readmeText -Needle "nested-direct-outside" -Label "README nested-direct A4 probe guidance"
Assert-Contains -Text $readmeText -Needle "run_gmtitle_selection_config_probe.ps1" -Label "README GMTITLE selection config probe guidance"
Assert-Contains -Text $a4NormProbeText -Needle "nested-outside" -Label "A4 nested normalization probe strategy"
Assert-Contains -Text $a4NormProbeText -Needle "nested-direct-outside" -Label "A4 nested plus parent normalization probe strategy"
Assert-Contains -Text $a4NormProbeRunnerText -Needle "WaitForGstarCADClose" -Label "A4 normalization probe wait option"
Assert-Contains -Text $a4NormProbeRunnerText -Needle "Get-LatestCadDwgFromNextStepLog" -Label "A4 normalization latest-DWG default"
Assert-Contains -Text $a4NativeProbeRunnerText -Needle "A4_NATIVE_EXEMPLAR_REQUIRES_SOURCEWORKCOPYPATH" -Label "A4 native exemplar explicit source guard"
Assert-Contains -Text $selectionConfigProbeText -Needle "GMTITLE_SELECTION_CONFIG_NOT_FOUND" -Label "Selection config probe negative result"
Assert-Contains -Text $selectionConfigProbeText -Needle "Direct GMTITLE may still reuse an internal/current command state" -Label "Selection config probe direct-GMTITLE warning"
Assert-Contains -Text $selectionConfigProbeText -Needle "ribbon/menu IMTITLE macro" -Label "Selection config probe IMTITLE macro note"
Assert-Contains -Text $selectionConfigProbeText -Needle "Command surface language note" -Label "Selection config probe command-surface language note"
Assert-Contains -Text $selectionConfigProbeText -Needle "AppData text marker scan note" -Label "Selection config probe AppData advisory scan note"
Assert-Contains -Text $readmeText -Needle "screenshot-coordinate ribbon clicks are not accepted as automation evidence" -Label "README ribbon coordinate automation warning"
Assert-Contains -Text $readmeText -Needle "AppData text marker scan is advisory" -Label "README AppData advisory scan guidance"
Assert-Contains -Text $goalStatusText -Needle "Write-NativeFrameProgressSummary" -Label "Goal status native-frame progress summary"
Assert-Contains -Text $goalStatusText -Needle "A4 normalization decision" -Label "Goal status A4 normalization decision guidance"
Assert-Contains -Text $goalStatusText -Needle "A4 investigation continuation" -Label "Goal status A4 nested probe continuation guidance"
Assert-Contains -Text $goalStatusText -Needle "A4 normalization candidate review" -Label "Goal status A4 safe-candidate review guidance"
Assert-Contains -Text $goalStatusText -Needle "A4 native comparison investigation" -Label "Goal status A4 unsafe-nested fallback guidance"
Assert-Contains -Text $goalStatusText -Needle "scratch DWG with one real native A4 GMTITLE" -Label "Goal status A4 scratch-native comparison guidance"
Assert-Contains -Text $goalStatusText -Needle "production A4 frame-only must still not receive a new title block" -Label "Goal status A4 no-production-title guidance"
Assert-Contains -Text $goalStatusText -Needle "Goal-log trust" -Label "Goal status latest-log trust marker"
Assert-Contains -Text $goalStatusText -Needle "latest CAD log is ignored for goal next-action selection" -Label "Goal status scratch-log ignore guidance"
Assert-Contains -Text $goalStatusText -Needle "Do not run the full hidden suite first" -Label "Goal status A4 probe before suite guidance"
Assert-Contains -Text $goalStatusText -Needle "If direct GMTITLE only asks for an insertion point, cancel it" -Label "Goal status direct-GMTITLE insertion prompt warning"
Assert-Contains -Text $goalStatusText -Needle "run_gmtitle_selection_config_probe.ps1" -Label "Goal status selection config probe guidance"

$runCardText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-current-run-card.md")
$goalPlanText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-goal-mode-plan.md")
Assert-Contains -Text $runCardText -Needle "RIBBON_ACCESSIBILITY_NOT_STABLE" -Label "Run card ribbon coordinate automation warning"
Assert-Contains -Text $goalPlanText -Needle "RIBBON_ACCESSIBILITY_NOT_STABLE" -Label "Goal plan ribbon accessibility finding"

$suiteStepNumbers = @(
  [regex]::Matches($suiteText, 'Write-Output\s+"===== ([0-9]+)\. ') |
    ForEach-Object { [int]$_.Groups[1].Value }
)
$expectedSuiteStepNumbers = 1..16
if (($suiteStepNumbers.Count -eq $expectedSuiteStepNumbers.Count) -and (@(Compare-Object $suiteStepNumbers $expectedSuiteStepNumbers).Count -eq 0)) {
  Write-Output ("Suite step numbers: {0}" -f ($suiteStepNumbers -join ", "))
} else {
  Add-Failure ("Suite step numbers mismatch: expected {0}, got {1}" -f (($expectedSuiteStepNumbers -join ", ")), (($suiteStepNumbers -join ", ")))
}

Assert-Contains -Text $readmeText -Needle "16. GMTITLE selection config probe" -Label "README suite step list"

foreach ($guidePath in $guidePaths) {
  $label = "Guide version " + (Resolve-Path -LiteralPath $guidePath).Path.Substring($repoRoot.Length + 1)
  Assert-VersionInFile -Path $guidePath -Version $ExpectedGmtitleVersion -Label $label
}

if ($failures.Count -gt 0) {
  Write-Output ""
  Write-Output "Static preflight failures:"
  foreach ($failure in $failures) {
    Write-Output ("  - {0}" -f $failure)
  }
  throw "GMTITLE static preflight failed with $($failures.Count) issue(s)."
}

Write-Output "Static preflight result: PASS"
