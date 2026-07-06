param(
  [string]$ExpectedGmtitleVersion = "260706-unified-title-missing-7",

  [string]$ExpectedLoaderVersion = "260706-loader-convert-next-response-guidance"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$mainLspPath = Join-Path $repoRoot "src\tools\gmtitle\swcad_title_scale.lsp"
$loaderPath = Join-Path $repoRoot "swcad_load.lsp"
$suitePath = Join-Path $PSScriptRoot "run_main45_verification_suite.ps1"
$readmePath = Join-Path $PSScriptRoot "README.md"
$rootReadmePath = Join-Path $repoRoot "README.md"
$readonlyProbeRunnerPath = Join-Path $PSScriptRoot "run_readonly_probe.ps1"
$hiddenScriptSmokeProbeRunnerPath = Join-Path $PSScriptRoot "run_hidden_script_smoke_probe.ps1"
$a4NormProbePath = Join-Path $PSScriptRoot "a4_outline_normalization_probe.lsp"
$a4NormProbeRunnerPath = Join-Path $PSScriptRoot "run_a4_outline_normalization_probe.ps1"
$a4NativeProbeFixturePath = Join-Path $PSScriptRoot "a4_native_exemplar_probe.lsp"
$a4NativeProbeRunnerPath = Join-Path $PSScriptRoot "run_a4_native_exemplar_probe.ps1"
$a4OutlineConvertProbePath = Join-Path $PSScriptRoot "a4_outline_convert_probe.lsp"
$a4OutlineConvertRunnerPath = Join-Path $PSScriptRoot "run_a4_outline_convert_probe.ps1"
$actualDirectStatusProbePath = Join-Path $PSScriptRoot "actual_workcopy_status_probe.lsp"
$actualDirectStatusRunnerPath = Join-Path $PSScriptRoot "run_actual_workcopy_direct_status_probe.ps1"
$postFirstNativeProbePath = Join-Path $PSScriptRoot "post_first_native_transition_probe.lsp"
$postFirstNativeRunnerPath = Join-Path $PSScriptRoot "run_post_first_native_transition_probe.ps1"
$openWorkcopyRunnerPath = Join-Path $PSScriptRoot "run_open_workcopy_for_manual_convert.ps1"
$manualGmtitleSessionRunnerPath = Join-Path $PSScriptRoot "run_manual_gmtitle_session.ps1"
$nextCadActionRunnerPath = Join-Path $PSScriptRoot "run_next_cad_action.ps1"
$afterManualGmtitleStepRunnerPath = Join-Path $PSScriptRoot "run_after_manual_gmtitle_step.ps1"
$nextCadActionCardProbePath = Join-Path $PSScriptRoot "run_next_cad_action_card_probe.ps1"
$finalCompletionGatePath = Join-Path $PSScriptRoot "run_final_completion_gate.ps1"
$selectionConfigProbePath = Join-Path $PSScriptRoot "run_gmtitle_selection_config_probe.ps1"
$goalStatusPath = Join-Path $PSScriptRoot "run_goal_status.ps1"
$cadTextLogReaderPath = Join-Path $PSScriptRoot "read_cad_text_log.ps1"
$computerUseHistoryPath = Join-Path $repoRoot "docs\history\gmtitle-computer-use-visible-cad-activation-failure-2026-07-05.md"
$computerUseA3DialogHistoryPath = Join-Path $repoRoot "docs\history\gmtitle-a3-visible-dialog-computer-use-2026-07-06.md"
$hiddenSuitePassHistoryPath = Join-Path $repoRoot "docs\history\gmtitle-main56-hidden-suite-pass-2026-07-05.md"
$finalCompletionGateHistoryPath = Join-Path $repoRoot "docs\history\gmtitle-final-completion-gate-2026-07-06.md"
$commandSurfaceHistoryPath = Join-Path $repoRoot "docs\history\gmtitle-command-surface-probe-2026-07-05.md"
$automationBoundaryHistoryPath = Join-Path $repoRoot "docs\history\gmtitle-automation-boundary-audit-2026-07-05.md"
$selectionConfigDeepRegistryHistoryPath = Join-Path $repoRoot "docs\history\gmtitle-selection-config-deep-registry-2026-07-06.md"
$guidePaths = @(
  "docs\guide\commands.md",
  "docs\guide\gmtitle-unified-flow-reset.md",
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
  [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8)
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

function Assert-NotContains {
  param(
    [string]$Text,
    [string]$Needle,
    [string]$Label
  )

  if ($Text.Contains($Needle)) {
    Add-Failure "$Label should not contain: $Needle"
  } else {
    Write-Output "${Label}: absent"
  }
}

function Assert-NoKnownMojibake {
  param(
    [string]$Text,
    [string]$Label
  )

  $badMarkers = @("�", "紐", "理", "?꾨", "?쒕", "?먮", "援ъ", "諛붽", "癒쇱")
  foreach ($marker in $badMarkers) {
    if ($Text.Contains($marker)) {
      Add-Failure "$Label contains mojibake marker: $marker"
    }
  }
  Write-Output "${Label}: mojibake guard checked"
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
$rootReadmeText = Read-Text $rootReadmePath
$readonlyProbeRunnerText = Read-Text $readonlyProbeRunnerPath
$hiddenScriptSmokeProbeRunnerText = Read-Text $hiddenScriptSmokeProbeRunnerPath
$a4NormProbeText = Read-Text $a4NormProbePath
$a4NormProbeRunnerText = Read-Text $a4NormProbeRunnerPath
$a4NativeProbeFixtureText = Read-Text $a4NativeProbeFixturePath
$a4NativeProbeRunnerText = Read-Text $a4NativeProbeRunnerPath
$a4OutlineConvertProbeText = Read-Text $a4OutlineConvertProbePath
$a4OutlineConvertRunnerText = Read-Text $a4OutlineConvertRunnerPath
$actualDirectStatusProbeText = Read-Text $actualDirectStatusProbePath
$actualDirectStatusRunnerText = Read-Text $actualDirectStatusRunnerPath
$postFirstNativeProbeText = Read-Text $postFirstNativeProbePath
$postFirstNativeRunnerText = Read-Text $postFirstNativeRunnerPath
$openWorkcopyRunnerText = Read-Text $openWorkcopyRunnerPath
$manualGmtitleSessionRunnerText = Read-Text $manualGmtitleSessionRunnerPath
$nextCadActionRunnerText = Read-Text $nextCadActionRunnerPath
$afterManualGmtitleStepRunnerText = Read-Text $afterManualGmtitleStepRunnerPath
$nextCadActionCardProbeText = Read-Text $nextCadActionCardProbePath
$finalCompletionGateText = Read-Text $finalCompletionGatePath
$selectionConfigProbeText = Read-Text $selectionConfigProbePath
$goalStatusText = Read-Text $goalStatusPath
$cadTextLogReaderText = Read-Text $cadTextLogReaderPath
$unifiedFlowResetGuideText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-unified-flow-reset.md")
$computerUseHistoryText = Read-Text $computerUseHistoryPath
$computerUseA3DialogHistoryText = Read-Text $computerUseA3DialogHistoryPath
$commandSurfaceHistoryText = Read-Text $commandSurfaceHistoryPath
$automationBoundaryHistoryText = Read-Text $automationBoundaryHistoryPath
$selectionConfigDeepRegistryHistoryText = Read-Text $selectionConfigDeepRegistryHistoryPath
$finalCompletionGateHistoryText = Read-Text $finalCompletionGateHistoryPath

Write-Output "===== GMTITLE static preflight ====="
Write-Output ("Repo root: {0}" -f $repoRoot)

Test-LispBalance -Text $mainText -Label "swcad_title_scale.lsp"
Test-LispBalance -Text $loaderText -Label "swcad_load.lsp"
Test-LispBalance -Text $a4NormProbeText -Label "a4_outline_normalization_probe.lsp"
Test-LispBalance -Text $a4OutlineConvertProbeText -Label "a4_outline_convert_probe.lsp"
Test-LispBalance -Text $actualDirectStatusProbeText -Label "actual_workcopy_status_probe.lsp"
Test-LispBalance -Text $postFirstNativeProbeText -Label "post_first_native_transition_probe.lsp"

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
Assert-Contains -Text $loaderText -Needle "GMTITLE 작업 흐름: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERTNEXT, SWTITLEVERIFY" -Label "Loader convert-next workflow guidance"
Assert-Contains -Text $loaderText -Needle "GMTITLE 수동 응답을 직접 고를 때만 SWTITLECONVERT를 사용하세요" -Label "Loader manual convert fallback guidance"
Assert-Contains -Text $loaderText -Needle "GMTITLE CONVERTNEXT: YES/OPEN/BATCH/MANUAL은 다시 입력하지 말고 GMTITLE 창만 확인하세요." -Label "Loader convert-next no-extra-response guidance"
Assert-Contains -Text $loaderText -Needle "GMTITLE 창 확인: DR_A*_Outline, DR_titlea_3rd, Frame positioning ON, Object move OFF." -Label "Loader GMTITLE dialog option guidance"
Assert-Contains -Text $loaderText -Needle "GMTITLE 중요: 변환 전에는 항상 SWTITLESTATUS로 현재 열린 DWG와 다음 상태를 먼저 확인하세요" -Label "Loader status-first visible guidance"
Assert-Contains -Text $loaderText -Needle "GMTITLE 금지: CAD 명령줄에 GMTITLE, TIT, 일반 OPEN을 직접 입력해 우회하지 마세요" -Label "Loader raw GMTITLE/TIT/OPEN guard"
Assert-NotContains -Text $loaderText -Needle "SWCAD loaded:" -Label "Loader stale English loaded message"
Assert-NotContains -Text $loaderText -Needle "Loading SWCAD tool set" -Label "Loader stale English loading message"

$expectedPublicCommands = @(
  "SWTITLESTATUS",
  "SWTITLEPREPARE",
  "SWTITLECONVERT",
  "SWTITLECONVERTNEXT",
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

Assert-Contains -Text $mainText -Needle "WARN_TITLE_MISSING_OUTLINE_DEFINITION_UNSAFE" -Label "Generic title-missing unsafe definition status"
Assert-Contains -Text $mainText -Needle "ready-native-outside-markers" -Label "A4 native outside marker ready status"
Assert-Contains -Text $mainText -Needle "swcad-title-title-missing-outline-definition-needed-p" -Label "Generic title-missing outline definition gate"
Assert-Contains -Text $mainText -Needle "swcad-title-title-missing-outline-policy-blocked-p" -Label "Generic title-missing outline policy gate"
Assert-Contains -Text $mainText -Needle "swcad-title-title-missing-outline-frame-block-present-p" -Label "Generic title-missing outline frame-block presence guard"
Assert-Contains -Text $mainText -Needle "swcad-title-title-missing-outline-risk-message" -Label "Generic title-missing outline risk message"
Assert-Contains -Text $mainText -Needle "(defun swcad-title-prepare-title-missing-outline-definition (/ frame-block" -Label "Generic title-missing outline prepare implementation"
Assert-Contains -Text $mainText -Needle "(defun swcad-title-transfer-title-missing-outline-apply (/ *error*" -Label "Generic title-missing outline transfer implementation"
Assert-Contains -Text $mainText -Needle "swcad-title-transfer-title-missing-outline-apply" -Label "Generic title-missing outline transfer wrapper"
Assert-NotContains -Text $mainText -Needle "swcad-title-a4-frame-only-" -Label "No legacy A4 frame-only helper aliases"
Assert-NotContains -Text $mainText -Needle "*swcad-title-allow-a4-frame-only" -Label "No legacy A4 frame-only option alias"
Assert-NotContains -Text $mainText -Needle "swcad-title-single-a4-frame-only" -Label "No legacy single-A4 frame-only helper"
Assert-NotContains -Text $mainText -Needle "swcad-title-transfer-a4-frame-only" -Label "No legacy A4 frame-only transfer wrapper"
Assert-NotContains -Text $mainText -Needle "swcad-title-prepare-a4-frame-only" -Label "No legacy A4 frame-only prepare wrapper"
Assert-NotContains -Text $mainText -Needle "(setq risk-message (swcad-title-single-a4-frame-only-risk-message" -Label "No legacy A4 risk-message calls"
Assert-NotContains -Text $mainText -Needle '(swcad-title-apply-result "FINALIZED_A4_FRAME_ONLY_OUTLINE_TRANSFER")' -Label "No legacy A4 finalized status emission"
Assert-NotContains -Text $mainText -Needle '(swcad-title-apply-result "WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE")' -Label "No legacy A4 warning status emission"
Assert-NotContains -Text $mainText -Needle '(swcad-title-apply-result "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION")' -Label "No legacy A4 next-prepare status emission"
Assert-Contains -Text $mainText -Needle "swcad-title-moved-native-placement-allowed-p" -Label "Generic moved-native placement guard"
Assert-Contains -Text $mainText -Needle "(defun swcad-title-native-upgrade-candidate-records ()" -Label "Generic A2/A3/A4 native-upgrade candidate function"
Assert-Contains -Text $mainText -Needle "(swcad-title-target-pair-upgrade-candidate-records '(`"A2`" `"A3`" `"A4`"))" -Label "Native-upgrade candidates include A2/A3/A4"
Assert-Contains -Text $mainText -Needle "WARN_A2_A3_A4_TARGET_FRAME_NOT_NATIVE_LIKE" -Label "Generic A2/A3/A4 native-like warning status"
Assert-Contains -Text $mainText -Needle "A2/A3/A4 native-like completion:" -Label "Generic A2/A3/A4 native-like completion log"
Assert-NotContains -Text $mainText -Needle "복제된 A3/A4 GMTITLE" -Label "No stale visible A3/A4-only native replacement wording"
Assert-NotContains -Text $mainText -Needle "교체된 A3/A4 native 도면틀" -Label "No stale visible A3/A4-only geometry wording"
Assert-NotContains -Text $mainText -Needle "SCRIPT 실행 중에는 A3/A4 대화식 교체" -Label "No stale visible A3/A4-only interactive wording"
Assert-NotContains -Text $mainText -Needle '("NEEDS_NATIVE_A3A4_UPGRADE" . "A3/A4 GMTITLE 중' -Label "No stale visible A3/A4-only trusted-pair wording"
Assert-NotContains -Text $mainText -Needle "이미 만들어진 A3/A4 GMTITLE" -Label "No stale visible A3/A4-only created-pair wording"
Assert-NotContains -Text $mainText -Needle "일반 A3/A4 또는 ISO" -Label "No stale visible ordinary A3/A4 default wording"
Assert-NotContains -Text $mainText -Needle "SWTITLECONVERT A3/A4" -Label "No stale visible A3/A4-only convert heading"
Assert-NotContains -Text $mainText -Needle 'swcad-title-frame-name-matches-p frame-name "DR_A4_Outline"' -Label "No A4-only trusted-frame exception"
Assert-NotContains -Text $mainText -Needle "A4 special handling" -Label "Stale A4 special handling wording"
Assert-NotContains -Text $mainText -Needle "A4 보호 중단" -Label "Stale A4-only protection wording"
Assert-NotContains -Text $mainText -Needle "frame-only A4 대상" -Label "Stale A4-only frame-only target wording"
Assert-NotContains -Text $mainText -Needle "보통 원본 제목블록이 없는 A4" -Label "Stale A4-only source-title-missing assumption"
Assert-NotContains -Text $mainText -Needle '(member "A4" missing-required-sheets)' -Label "No A4-only title-missing verify branch"
Assert-Contains -Text $mainText -Needle "ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE" -Label "Interactive GMTITLE script guard"
Assert-Contains -Text $mainText -Needle "INTERACTIVE_GMTITLE_EXCEPTION" -Label "Interactive GMTITLE exception guard status"
Assert-Contains -Text $mainText -Needle "'swcad-title-run-native-gmtitle" -Label "Interactive GMTITLE exception wrapper"
Assert-Contains -Text $mainText -Needle "기존 SOLIDWORKS 표제란/도면틀 내용은 삭제하지 않았습니다." -Label "Interactive GMTITLE exception preserves source"
Assert-Contains -Text $mainText -Needle "ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE" -Label "A3/A4 batch script guard"
Assert-Contains -Text $mainText -Needle "c:SWTITLECONVERTNEXT" -Label "SWTITLECONVERTNEXT public command"
Assert-Contains -Text $mainText -Needle "*swcad-title-convert-next-mode*" -Label "SWTITLECONVERTNEXT auto-next mode flag"
Assert-Contains -Text $mainText -Needle "SWTITLECONVERTNEXT auto response" -Label "SWTITLECONVERTNEXT auto response log"
Assert-Contains -Text $mainText -Needle "swcad-title-auto-next-answer-or-prompt" -Label "SWTITLECONVERTNEXT string-preserving auto response helper"
if ([regex]::IsMatch($mainText, "\(or\s*\r?\n\s*\(swcad-title-auto-next-answer")) {
  Add-Failure "SWTITLECONVERTNEXT auto response must not be wrapped in AutoLISP or; or returns T instead of the answer string."
} else {
  Write-Output "SWTITLECONVERTNEXT auto response string preservation: OK"
}
Assert-Contains -Text $mainText -Needle "SWTITLECONVERTNEXT ; recommended next safe conversion step" -Label "GMTITLE header convert-next main workflow"
Assert-Contains -Text $mainText -Needle "Manual fallback:" -Label "GMTITLE header manual fallback section"
Assert-Contains -Text $mainText -Needle "Use it only when you intentionally need to" -Label "GMTITLE header manual fallback guard"
Assert-Contains -Text $mainText -Needle "A2/A3/A4 native-recheck or cloned GMTITLE pairs are normally handled through" -Label "GMTITLE header A2/A3/A4 convert-next wording"
Assert-Contains -Text $mainText -Needle "권장 흐름: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERTNEXT, SWTITLEVERIFY" -Label "GMTITLE load convert-next workflow guidance"
Assert-Contains -Text $mainText -Needle "수동 응답을 직접 고를 때만 SWTITLECONVERT를 사용하세요" -Label "GMTITLE load manual convert fallback guidance"
Assert-Contains -Text $mainText -Needle "중요: 변환 전에는 SWTITLESTATUS 결과가 안내한 다음 명령만 실행하세요" -Label "GMTITLE load status-result-only guidance"
Assert-Contains -Text $mainText -Needle "금지: CAD 명령줄에 GMTITLE, TIT, 일반 OPEN을 직접 입력해 우회하지 마세요" -Label "GMTITLE load raw GMTITLE/TIT/OPEN guard"
Assert-Contains -Text $mainText -Needle 'SWTITLEVERSION_OK' -Label "SWTITLEVERSION read-only status marker"
Assert-Contains -Text $mainText -Needle "swcad-title-princ-raw-line" -Label "GMTITLE raw output helper for exact version strings"
Assert-Contains -Text $mainText -Needle "SWTITLE LSP 버전: " -Label "GMTITLE exact Korean version label"
if ([regex]::IsMatch($mainText, "\(defun\s+swcad-title-print-loaded-version\s*\(\)\s*\r?\n\s*\(swcad-title-princ-line")) {
  Add-Failure "swcad-title-print-loaded-version must use raw output; translated output changes version tokens such as missing -> 없음."
} else {
  Write-Output "GMTITLE version output raw guard: OK"
}
Assert-Contains -Text $mainText -Needle "다음 첫 native GMTITLE 선택:" -Label "SWTITLESTATUS first-native selection heading"
Assert-Contains -Text $mainText -Needle "GMTITLE 창에서는 위 용지/도면틀과 제목블록을 고르고" -Label "SWTITLESTATUS first-native dialog guidance"
Assert-Contains -Text $mainText -Needle "예상 수동 GMTITLE 확인량:" -Label "SWTITLESTATUS manual GMTITLE forecast heading"
Assert-Contains -Text $mainText -Needle "swcad-title-print-compact-next-gmtitle-card" -Label "SWTITLESTATUS compact selection card helper"
Assert-Contains -Text $mainText -Needle "짧은 GMTITLE 선택 카드:" -Label "SWTITLESTATUS compact selection card heading"
Assert-Contains -Text $mainText -Needle "  다음 명령: SWTITLECONVERTNEXT" -Label "SWTITLESTATUS compact selection card command"
Assert-Contains -Text $mainText -Needle "우선순위: native 교체 후보가 title-missing/frame-only 예외 준비보다 먼저입니다." -Label "SWTITLESTATUS native priority over title-missing exception"
Assert-Contains -Text $mainText -Needle "  켜둘 옵션: Frame positioning" -Label "SWTITLESTATUS compact selection card frame-positioning"
Assert-Contains -Text $mainText -Needle "  꺼둘 옵션: Object move" -Label "SWTITLESTATUS compact selection card object-move"
Assert-Contains -Text $mainText -Needle "(setq example-title (swcad-title-native-example-title))" -Label "SWTITLECONVERT compact card native-example basis"
Assert-Contains -Text $mainText -Needle "(setq missing-required-native (swcad-title-missing-required-native-frame-blocks summary))" -Label "SWTITLECONVERT compact card missing-native basis"
Assert-Contains -Text $mainText -Needle "(swcad-title-print-compact-next-gmtitle-card summary missing-required-native example-title a3a4-count)" -Label "SWTITLECONVERT compact selection card before dialog"
Assert-Contains -Text $mainText -Needle "title-missing/frame-only" -Label "SWTITLESTATUS title-missing frame-only forecast"
Assert-Contains -Text $mainText -Needle "swcad-title-next-missing-native-selection-record" -Label "SWTITLESTATUS missing-native selection helper"
Assert-Contains -Text $mainText -Needle "다음 누락 크기 native GMTITLE 선택:" -Label "SWTITLESTATUS missing-native selection heading"
Assert-Contains -Text $mainText -Needle "SWTITLECONVERTNEXT 선택 안내: 위 용지/도면틀과 제목블록" -Label "SWTITLECONVERTNEXT exact dialog selection guidance"
Assert-Contains -Text $mainText -Needle '"A2/A3/A4 native 교체 후보 1장 처리"' -Label "SWTITLECONVERTNEXT native one-sheet default"
Assert-Contains -Text $mainText -Needle "swcad-title-print-native-batch-safety-guidance" -Label "Native batch safety guidance helper"
Assert-Contains -Text $mainText -Needle "BATCH 안전 조건: 먼저 OPEN으로 1장을 성공시킨 뒤 SWTITLESTATUS/direct probe에서 후보 수가 줄었는지 확인하세요." -Label "Native batch OPEN-first guidance"
Assert-Contains -Text $mainText -Needle "BATCH 금지 조건: 첫 후보부터 바로 BATCH를 쓰거나" -Label "Native batch no-first-batch guidance"
Assert-Contains -Text $mainText -Needle "다음 명령: SWTITLECONVERTNEXT" -Label "SWTITLESTATUS recommends convert-next command"
Assert-Contains -Text $mainText -Needle "다음: SWTITLECONVERTNEXT를 실행하세요" -Label "SWTITLESTATUS next action recommends convert-next"
Assert-NotContains -Text $mainText -Needle "다음: SWTITLECONVERT를 실행하세요." -Label "Stale direct convert next-action wording"
Assert-NotContains -Text $mainText -Needle "일반 흐름은 SWTITLECONVERT를 사용하세요." -Label "Stale direct convert general-flow wording"
Assert-NotContains -Text $mainText -Needle "(command pause)" -Label "GMTITLE interactive wait must use explicit pause string"
$a3a4NextStart = $mainText.IndexOf("(defun swcad-title-upgrade-native-a3a4-next")
$a3a4AutoOpen = if ($a3a4NextStart -ge 0) { $mainText.IndexOf('"A2/A3/A4 native 교체 후보 1장 처리"', $a3a4NextStart) } else { -1 }
$a3a4Prompt = if ($a3a4NextStart -ge 0) { $mainText.IndexOf("이 한 장의 GMTITLE 창을 열려면 OPEN", $a3a4NextStart) } else { -1 }
if (($a3a4NextStart -ge 0) -and ($a3a4AutoOpen -gt $a3a4NextStart) -and ($a3a4Prompt -gt $a3a4AutoOpen)) {
  Write-Output "SWTITLECONVERTNEXT A2/A3/A4 OPEN before prompt: found"
} else {
  Add-Failure "SWTITLECONVERTNEXT A2/A3/A4 OPEN auto response must be checked before getstring prompt"
}
Assert-Contains -Text $mainText -Needle "DR_titlea_3rd/Frame positioning ON/Object move OFF" -Label "SWTITLECONVERTNEXT visual GMTITLE confirmation guard"
Assert-Contains -Text $suiteText -Needle "A4 outline native outside marker prepare probe" -Label "Suite A4 native outside marker prepare step"
Assert-Contains -Text $suiteText -Needle "After definition status: ready-native-outside-markers" -Label "Suite A4 native outside marker prepare expectation"
Assert-Contains -Text $suiteText -Needle "Title-missing outline convert probe (A4 sample)" -Label "Suite title-missing outline convert sample step"
Assert-NotContains -Text $suiteText -Needle "260706-unified-title-missing-3" -Label "Suite stale GMTITLE version expectation"
Assert-Contains -Text $suiteText -Needle "FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER" -Label "Suite title-missing outline convert expectation"
Assert-Contains -Text $suiteText -Needle "Before target title count: 1" -Label "Suite title-missing preserves existing title count before convert"
Assert-Contains -Text $suiteText -Needle "After target title count: 1" -Label "Suite title-missing does not add title after convert"
Assert-Contains -Text $suiteText -Needle "Native GMTITLE A4 pair evidence: no" -Label "Suite A4 native-pair gap expectation"
Assert-Contains -Text $suiteText -Needle "WaitForGstarCADClose" -Label "Suite GstarCAD-close wait option"
Assert-Contains -Text $suiteText -Needle "Assert-NoExistingGstarCAD" -Label "Suite open-GstarCAD preflight"
Assert-Contains -Text $suiteText -Needle "main56_verification_suite_last_run.txt" -Label "Suite latest run summary log path"
Assert-Contains -Text $suiteText -Needle "-DeepRegistrySearch" -Label "Suite selection config deep registry search"
Assert-Contains -Text $suiteText -Needle "Deep registry policy: only non-recent DR marker(s) are review evidence" -Label "Suite selection config deep registry policy"
Assert-Contains -Text $suiteText -Needle "Result: RUNNING_OR_FAILED_BEFORE_PASS" -Label "Suite latest run starts incomplete"
Assert-Contains -Text $suiteText -Needle "Result: FAILED_BEFORE_PASS" -Label "Suite latest run failed-before-pass marker"
Assert-Contains -Text $suiteText -Needle "Failure command:" -Label "Suite latest run failure command summary"
Assert-Contains -Text $suiteText -Needle "Set-SuiteLastRunFailure" -Label "Suite latest run failure trap helper"
Assert-Contains -Text $suiteText -Needle "Result: PASS" -Label "Suite latest run pass marker"
Assert-Contains -Text $suiteText -Needle "Write-SuiteStatusSummary" -Label "Suite latest run status summary"
Assert-Contains -Text $suiteText -Needle "Suite last-run summary:" -Label "Suite latest run summary output"
Assert-Contains -Text $suiteText -Needle "run_hidden_script_smoke_probe.ps1" -Label "Suite hidden script smoke preflight"
Assert-Contains -Text $suiteText -Needle "ProbeWindowStyle = ""Minimized""" -Label "Suite minimized probe window default"
Assert-Contains -Text $suiteText -Needle "Next CAD action card probe (no CAD)" -Label "Suite next-action card no-CAD preflight"
Assert-Contains -Text $suiteText -Needle "run_next_cad_action_card_probe.ps1" -Label "Suite next-action card probe runner"
Assert-Contains -Text $suiteText -Needle "Visible work-copy opener dry-run (no CAD convert)" -Label "Suite visible workcopy opener dry-run preflight"
Assert-Contains -Text $suiteText -Needle "run_open_workcopy_for_manual_convert.ps1" -Label "Suite visible workcopy opener runner"
Assert-Contains -Text $suiteText -Needle "SafetyMarker: no-run-SWTITLECONVERTNEXT no-open-GMTITLE no-save-DWG" -Label "Suite visible workcopy opener no-convert expectation"
Assert-Contains -Text $suiteText -Needle "GuardMarker: no-raw-GMTITLE no-raw-TIT no-raw-OPEN" -Label "Suite visible workcopy opener raw command guard"
Assert-Contains -Text $suiteText -Needle "Frame positioning ON" -Label "Suite visible workcopy opener required options"
Assert-Contains -Text $suiteText -Needle "swcad_load.lsp" -Label "Suite visible workcopy opener loader token"
Assert-NotContains -Text $suiteText -Needle "After the CAD window is ready, type SWTITLECONVERTNEXT in GstarCAD." -Label "Suite visible workcopy opener stale one-line command wording"
Assert-Contains -Text $suiteText -Needle "Post-first-native marker gate probe" -Label "Suite post-first-native marker gate step"
Assert-Contains -Text $suiteText -Needle "Post-first-native marker gate probe passed: yes" -Label "Suite post-first-native marker gate expectation"
Assert-Contains -Text $suiteText -Needle "Structure next action: SWTITLECONVERTNEXT" -Label "Suite structure next action recommends convert-next"
Assert-NotContains -Text $suiteText -Needle "Structure next action: SWTITLECONVERT`"," -Label "Suite stale structure next action"
Assert-Contains -Text $readmeText -Needle "-WaitForGstarCADClose" -Label "README waiting-mode guidance"
Assert-Contains -Text $readmeText -Needle "GstarCAD /b Script Smoke Probe" -Label "README GstarCAD /b script smoke probe guidance"
Assert-Contains -Text $readmeText -Needle "swcad_title_scale_current_main56_compare_copy.lsp" -Label "README current suite compare-copy name"
Assert-NotContains -Text $readmeText -Needle "swcad_title_scale_current_main45_compare_copy.lsp" -Label "README stale suite compare-copy name"
Assert-Contains -Text $readmeText -Needle "work\main56_verification_suite_last_run.txt" -Label "README latest suite summary path"
Assert-Contains -Text $readmeText -Needle "Result: RUNNING_OR_FAILED_BEFORE_PASS" -Label "README latest suite summary starts incomplete"
Assert-Contains -Text $readmeText -Needle "Result: FAILED_BEFORE_PASS" -Label "README latest suite summary failed marker"
Assert-Contains -Text $readmeText -Needle "failure message/command" -Label "README latest suite failure summary contents"
Assert-Contains -Text $readmeText -Needle "records the actual work-copy state, title-missing/frame-only evidence, and native batch guard evidence" -Label "README latest suite summary contents"
Assert-Contains -Text $readonlyProbeRunnerText -Needle "WindowStyle = ""Minimized""" -Label "Readonly probe minimized window default"
Assert-Contains -Text $readonlyProbeRunnerText -Needle '-WindowStyle $WindowStyle' -Label "Readonly probe configurable window style"
Assert-Contains -Text $hiddenScriptSmokeProbeRunnerText -Needle "HIDDEN_SCRIPT_SMOKE_OK" -Label "Hidden script smoke marker"
Assert-Contains -Text $hiddenScriptSmokeProbeRunnerText -Needle "WindowStyle=Hidden fails with no log" -Label "Hidden script smoke minimized fallback guidance"
Assert-Contains -Text $hiddenScriptSmokeProbeRunnerText -Needle "Do not interpret later loader/probe log-missing failures as GMTITLE logic failures" -Label "Hidden script smoke failure interpretation"
Assert-Contains -Text $readmeText -Needle "no-CAD next-action card probe" -Label "README next-action card suite preflight guidance"
Assert-Contains -Text $readmeText -Needle "Structure next action: SWTITLECONVERTNEXT" -Label "README structure next action recommends convert-next"
Assert-NotContains -Text $readmeText -Needle "Structure next action: SWTITLECONVERT`r`n" -Label "README stale structure next action"
Assert-Contains -Text $readmeText -Needle "NEXT_CREATE_FIRST_NATIVE_GMTITLE / NEXT_CREATE_MISSING_NATIVE_EXEMPLAR -> SWTITLECONVERTNEXT" -Label "README first-native status recommends convert-next"
Assert-Contains -Text $readmeText -Needle "NEXT_UPGRADE_A3_A4_NATIVE -> SWTITLECONVERTNEXT native replacement" -Label "README native-upgrade status recommends convert-next"
Assert-NotContains -Text $readmeText -Needle "NEXT_CREATE_FIRST_NATIVE_GMTITLE / NEXT_CREATE_MISSING_NATIVE_EXEMPLAR -> SWTITLECONVERT`r`n" -Label "README stale first-native direct convert mapping"
Assert-NotContains -Text $readmeText -Needle "NEXT_UPGRADE_A3_A4_NATIVE -> SWTITLECONVERT native replacement" -Label "README stale native-upgrade direct convert mapping"
Assert-Contains -Text $readmeText -Needle "A4 native outside marker prepare" -Label "README A4 native marker prepare guidance"
Assert-Contains -Text $readmeText -Needle "nested-direct-outside" -Label "README nested-direct A4 probe guidance"
Assert-Contains -Text $readmeText -Needle "run_gmtitle_selection_config_probe.ps1" -Label "README GMTITLE selection config probe guidance"
Assert-Contains -Text $readmeText -Needle "Recent File List" -Label "README selection config recent-file warning"
Assert-Contains -Text $a4NormProbeText -Needle "nested-outside" -Label "A4 nested normalization probe strategy"
Assert-Contains -Text $a4NormProbeText -Needle "nested-direct-outside" -Label "A4 nested plus parent normalization probe strategy"
Assert-Contains -Text $a4NormProbeRunnerText -Needle "WaitForGstarCADClose" -Label "A4 normalization probe wait option"
Assert-Contains -Text $a4NormProbeRunnerText -Needle "Get-LatestCadDwgFromNextStepLog" -Label "A4 normalization latest-DWG default"
Assert-Contains -Text $a4NativeProbeFixtureText -Needle "A4_NATIVE_EXEMPLAR_MISSING_NATIVE_PAIR" -Label "A4 native exemplar requires native pair evidence"
Assert-Contains -Text $a4NativeProbeFixtureText -Needle "Native GMTITLE A4 pair evidence" -Label "A4 native exemplar logs native pair evidence"
Assert-Contains -Text $a4NativeProbeFixtureText -Needle "A4_NATIVE_EXEMPLAR_READY_WITH_NATIVE_OUTSIDE_MARKERS" -Label "A4 native exemplar minor outside marker result"
Assert-Contains -Text $a4NativeProbeFixtureText -Needle "Definition minor native outside markers" -Label "A4 native exemplar minor outside marker log"
Assert-Contains -Text $a4NativeProbeRunnerText -Needle "A4_NATIVE_EXEMPLAR_REQUIRES_SOURCEWORKCOPYPATH" -Label "A4 native exemplar explicit source guard"
Assert-Contains -Text $a4NativeProbeRunnerText -Needle "WaitForGstarCADClose" -Label "A4 native exemplar wait option"
Assert-Contains -Text $a4OutlineConvertProbeText -Needle "After target title count" -Label "Title-missing outline convert no-title log"
Assert-Contains -Text $a4OutlineConvertProbeText -Needle "FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER" -Label "Title-missing outline convert finalized status"
Assert-Contains -Text $a4OutlineConvertRunnerText -Needle "run_readonly_probe.ps1" -Label "Title-missing outline convert hidden runner"
Assert-Contains -Text $actualDirectStatusRunnerText -Needle "run_readonly_probe.ps1" -Label "Actual direct work-copy hidden runner"
Assert-Contains -Text $actualDirectStatusRunnerText -Needle "TimeoutSeconds = 180" -Label "Actual direct work-copy longer timeout"
Assert-Contains -Text $actualDirectStatusRunnerText -Needle "SWCAD_ACTUAL_WORKCOPY_LOG_SUFFIX" -Label "Actual direct work-copy suffix override"
Assert-Contains -Text $actualDirectStatusRunnerText -Needle "swtitle_actual_workcopy_direct_status_260705.txt" -Label "Actual direct work-copy log path"
Assert-Contains -Text $nextCadActionRunnerText -Needle "READY_FOR_FIRST_NATIVE_GMTITLE" -Label "Next CAD action first-native readiness"
Assert-Contains -Text $nextCadActionRunnerText -Needle "0xEF" -Label "Next CAD action UTF-8 BOM log guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "TrimStart([char]0xFEFF)" -Label "Next CAD action BOM character trim"
Assert-Contains -Text $nextCadActionRunnerText -Needle "작업복사본이 direct probe 로그보다 최신입니다" -Label "Next CAD action stale direct-probe guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "direct probe 로그가 현재 로드해야 할 LSP 버전과 다릅니다" -Label "Next CAD action stale direct-probe version guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "RELOAD_LSP_AND_CONFIRM_STATUS" -Label "Next CAD action stale-version manual reload result"
Assert-Contains -Text $nextCadActionRunnerText -Needle "direct probe 로그는 없지만 final completion gate에 다음 CAD 상태와 GMTITLE 선택값이 남아 있습니다" -Label "Next CAD action missing-probe final-gate fallback"
Assert-Contains -Text $nextCadActionRunnerText -Needle "final gate 기준 예상 GMTITLE 선택" -Label "Next CAD action missing-probe expected selection"
Assert-Contains -Text $nextCadActionRunnerText -Needle "CAD 안에서 최신 LSP를 다시 APPLOAD하고 SWTITLESTATUS로 현재 상태를 확인하세요" -Label "Next CAD action stale-version manual reload guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLESTATUS가 같은 상태를 안내할 때만 아래 변환 명령을 계속하세요" -Label "Next CAD action stale-version status-confirm-before-convert"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Direct probe 최신 상태" -Label "Next CAD action direct-probe freshness output"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Direct probe LSP 버전 일치" -Label "Next CAD action direct-probe version output"
Assert-Contains -Text $nextCadActionRunnerText -Needle "AutoRefreshDirectProbe" -Label "Next CAD action optional direct-probe auto refresh"
Assert-Contains -Text $nextCadActionRunnerText -Needle "AutoRefreshTimeoutSeconds = 180" -Label "Next CAD action direct-probe auto refresh timeout"
Assert-Contains -Text $nextCadActionRunnerText -Needle "AUTO_REFRESH_DIRECT_PROBE_FAILED" -Label "Next CAD action auto refresh failure guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "기존 로그가 대상 작업복사본, 저장 시간, 현재 LSP 버전과 일치해 재사용합니다" -Label "Next CAD action auto refresh reuse explanation"
Assert-Contains -Text $nextCadActionRunnerText -Needle "예상 수동 GMTITLE 확인량" -Label "Next CAD action manual selection forecast"
Assert-Contains -Text $nextCadActionRunnerText -Needle "저장된 시트 수량" -Label "Next CAD action expected sheet count forecast"
Assert-Contains -Text $nextCadActionRunnerText -Needle "title-missing/frame-only {0}장은 원본 표제란 부재가 검증된 경우에만" -Label "Next CAD action title-missing no-title forecast"
Assert-Contains -Text $actualDirectStatusProbeText -Needle "a3a4-native-upgrade-candidate-count" -Label "Actual workcopy probe native-upgrade candidate count"
Assert-Contains -Text $actualDirectStatusProbeText -Needle "target-gmtitle-pair-count" -Label "Actual workcopy probe target pair count"
Assert-Contains -Text $actualDirectStatusProbeText -Needle "native-like-target-pair-count" -Label "Actual workcopy probe native-like pair count"
Assert-Contains -Text $actualDirectStatusProbeText -Needle "duplicate-target-pair-count" -Label "Actual workcopy probe duplicate target pair count"
Assert-Contains -Text $actualDirectStatusProbeText -Needle "first-native-selection-log-note-found" -Label "Actual workcopy probe first-native selection log check"
Assert-Contains -Text $actualDirectStatusProbeText -Needle "manual-forecast-log-note-found" -Label "Actual workcopy probe manual forecast log check"
Assert-Contains -Text $actualDirectStatusProbeText -Needle "next-missing-native-frame" -Label "Actual workcopy probe missing-native frame output"
Assert-Contains -Text $postFirstNativeProbeText -Needle "marker-only A2 target is not accepted as the first native GMTITLE" -Label "Post-first-native marker gate negative evidence"
Assert-Contains -Text $postFirstNativeProbeText -Needle "Next missing native selection after fixture" -Label "Post-first-native marker gate next missing selection evidence"
Assert-Contains -Text $postFirstNativeRunnerText -Needle "post_first_native_transition_probe.lsp" -Label "Post-first-native marker gate runner"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "SWTITLESTATUS" -Label "Open workcopy helper status command"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "이 helper는 SWTITLECONVERTNEXT를 실행하지 않고" -Label "Open workcopy helper Korean no-convert guard"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "기본값에서는 /b 시작 스크립트를 쓰지 않습니다" -Label "Open workcopy helper Korean no-startup-script default"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "SafetyMarker: no-run-SWTITLECONVERTNEXT no-open-GMTITLE no-save-DWG" -Label "Open workcopy helper ASCII safety marker"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "GuardMarker: no-raw-GMTITLE no-raw-TIT no-raw-OPEN" -Label "Open workcopy helper ASCII raw-command guard marker"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "CAD 창이 준비되면 GstarCAD 명령창에 아래 순서만 입력하세요" -Label "Open workcopy helper Korean command-order guidance"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "필수 옵션: Frame positioning ON, Object move OFF" -Label "Open workcopy helper required GMTITLE options"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "CAD 명령창에 GMTITLE, TIT, 일반 OPEN을 직접 입력하지 마세요" -Label "Open workcopy helper raw command guard"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "GSTARCAD_NO_VISIBLE_WINDOW" -Label "Open workcopy helper no-window guard"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "안정적으로 확인된 보이는 GstarCAD 창 핸들" -Label "Open workcopy helper stable-window guard"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "GSTARCAD_VISIBLE_WINDOW_NOT_STABLE_AFTER_CHECK" -Label "Open workcopy helper post-visible guard"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "창이 불안정한 GstarCAD PID를 종료했습니다" -Label "Open workcopy helper unstable-window cleanup"
Assert-Contains -Text $openWorkcopyRunnerText -Needle "보이지 않는 GstarCAD PID를 종료했습니다" -Label "Open workcopy helper non-visible cleanup"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "run_open_workcopy_for_manual_convert.ps1" -Label "Manual session wrapper opens workcopy helper"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "run_after_manual_gmtitle_step.ps1" -Label "Manual session wrapper after-manual check"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "SWTITLECONVERTNEXT를 대신 실행하지 않고" -Label "Manual session wrapper no-convert guard"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle 'CAD가 `_pasteclip` 삽입 명령으로 해석할 수 있으므로' -Label "Manual session wrapper pasteclip warning"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "GMTITLE 창을 클릭하지 않고" -Label "Manual session wrapper no-click guard"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "Wait-ForGstarCADToClose" -Label "Manual session wrapper waits for close"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "Assert-GstarCADRunningBeforeManualStep" -Label "Manual session wrapper requires visible CAD before wait"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "SKIP_OPEN_NO_GSTARCAD" -Label "Manual session wrapper skip-open guard"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "GSTARCAD_CLOSED_BEFORE_MANUAL_STEP" -Label "Manual session wrapper early-close guard"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "초기 다음 작업 카드" -Label "Manual session wrapper initial next-action card"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "처음 실행할 다음 작업 짧은 요약:" -Label "Manual session wrapper initial short summary"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "function Get-LastRegexValue" -Label "Manual session wrapper latest-value parser"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle '$result = Get-LastRegexValue -Text $CardText -Pattern "^Result:\s*(\S+)\s*$"' -Label "Manual session wrapper latest result summary"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle '$status = Get-LastRegexValue -Text $CardText -Pattern "^(?:\s*SWTITLESTATUS:|현재 저장 상태:)\s*(\S+)"' -Label "Manual session wrapper latest status summary"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle '$frame = Get-LastRegexValue -Text $CardText -Pattern "^\s*(?:용지/도면틀|다음 GMTITLE 용지/도면틀|GMTITLE에서 고를 용지/도면틀):\s*(DR_A[1-4]_Outline)\b"' -Label "Manual session wrapper latest frame summary"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "GMTITLE 짧은 수동 선택 카드" -Label "Manual session wrapper compact card heading"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "GMTITLE에서 고를 용지/도면틀:" -Label "Manual session wrapper paper/frame summary"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "필수 옵션: Frame positioning ON, Object move OFF" -Label "Manual session wrapper required options summary"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "CAD 명령 순서:" -Label "Manual session wrapper CAD command order summary"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "GMTITLE 창: 위 용지/제목블록/옵션만 확인하세요." -Label "Manual session wrapper compact dialog scope"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "금지: GMTITLE, TIT, 일반 OPEN을 직접 입력하지 마세요." -Label "Manual session wrapper compact raw-command guard"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle '금지: 긴 명령/경로를 자동 입력하거나 붙여넣지 마세요. CAD가 `_pasteclip` 삽입으로 해석할 수 있습니다.' -Label "Manual session wrapper compact pasteclip guard"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "배치점: 긴 좌표를 직접 치지 말고 자동 입력을 기다리세요." -Label "Manual session wrapper compact placement guard"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "처리 후: 작업복사본을 저장하고 GstarCAD를 닫으세요." -Label "Manual session wrapper compact after-step guard"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "PreflightOnly" -Label "Manual session wrapper preflight-only option"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "Compact:" -Label "Manual session wrapper compact option"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "AutoRefreshDirectProbe" -Label "Manual session wrapper optional auto-refresh option"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "기본값: 현재 PC의 /b probe가 불안정할 수 있어 자동 direct probe 갱신은 하지 않습니다" -Label "Manual session wrapper no default auto-refresh"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "RELOAD_LSP_AND_CONFIRM_STATUS" -Label "Manual session wrapper stale-version reload accepted"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "CAD 안에서 APPLOAD와 SWTITLESTATUS를 먼저 실행해 같은 상태인지 확인" -Label "Manual session wrapper stale-version status confirmation"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "SuppressChildOutput" -Label "Manual session wrapper compact output suppression"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "긴 PowerShell 실행 명령줄은 -Compact 때문에 숨겼습니다" -Label "Manual session wrapper compact command suppression"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "출력은 -Compact 때문에 숨겼습니다" -Label "Manual session wrapper compact suppression message"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "MANUAL_SESSION_PREFLIGHT_READY" -Label "Manual session wrapper preflight-only ready result"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "PREFLIGHT_ONLY_REQUIRES_INITIAL_CARD" -Label "Manual session wrapper preflight-only misuse guard"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "MANUAL_SESSION_NOT_CONVERSION_READY" -Label "Manual session wrapper non-conversion guard"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "READY_FOR_FIRST_NATIVE_GMTITLE|CREATE_MISSING_NATIVE_GMTITLE_SIZE|RUN_NATIVE_REPLACEMENT|RUN_REMAINING_CONVERSION|RELOAD_LSP_AND_CONFIRM_STATUS" -Label "Manual session wrapper conversion-ready result set"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "SkipInitialNextActionCard" -Label "Manual session wrapper explicit preflight skip"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "MANUAL_GMTITLE_SESSION_COMPLETE" -Label "Manual session wrapper completion marker"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle "DryRun" -Label "Manual session wrapper dry-run option"
Assert-Contains -Text $manualGmtitleSessionRunnerText -Needle '$afterArgs += "-Compact"' -Label "Manual session wrapper forwards compact after-manual check"
Assert-Contains -Text $nextCadActionRunnerText -Needle "run_open_workcopy_for_manual_convert.ps1" -Label "Next CAD action open-workcopy helper"
Assert-Contains -Text $nextCadActionRunnerText -Needle "A2/A3/A4 native 교체 후보 수" -Label "Next CAD action native-upgrade candidate output"
Assert-Contains -Text $nextCadActionRunnerText -Needle "현재 GMTITLE 쌍: 전체" -Label "Next CAD action target-pair forecast"
Assert-Contains -Text $nextCadActionRunnerText -Needle "OPEN 1회 성공 뒤 direct probe를 갱신해서 후보 수가 줄었는지 먼저 확인하세요." -Label "Next CAD action native OPEN refresh guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Codex sandbox 기본 경로 감지" -Label "Next CAD action Codex sandbox default-path correction"
Assert-Contains -Text $nextCadActionRunnerText -Needle "direct probe의 실제 DWG를 대상 작업복사본으로 사용" -Label "Next CAD action real direct-probe DWG correction"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Get-RepoRootFromWorkCopyPath" -Label "Next CAD action host repo root derivation"
Assert-Contains -Text $nextCadActionRunnerText -Needle "실제 CAD용 저장소 폴더" -Label "Next CAD action host CAD repo output"
Assert-Contains -Text $nextCadActionRunnerText -Needle 'Join-Path $displayRepoRoot "swcad_load.lsp"' -Label "Next CAD action APPLOAD display root"
Assert-Contains -Text $nextCadActionRunnerText -Needle "run_actual_workcopy_direct_status_probe.ps1" -Label "Next CAD action direct-probe runner guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Write-SuiteLastRunSummary" -Label "Next CAD action suite summary helper"
Assert-Contains -Text $nextCadActionRunnerText -Needle "최근 hidden suite 요약:" -Label "Next CAD action suite summary heading"
Assert-Contains -Text $nextCadActionRunnerText -Needle "main56_verification_suite_last_run.txt" -Label "Next CAD action suite summary path"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Get-GitHeadCommitTimeUtc" -Label "Next CAD action head commit time helper"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Test-GitWorkingTreeDirty" -Label "Next CAD action dirty worktree helper"
Assert-Contains -Text $nextCadActionRunnerText -Needle "suite 로그가 현재 커밋보다 오래됨" -Label "Next CAD action stale suite flag"
Assert-Contains -Text $nextCadActionRunnerText -Needle "현재 작업트리 변경 있음" -Label "Next CAD action dirty worktree flag"
Assert-Contains -Text $nextCadActionRunnerText -Needle "미커밋 변경분까지 검증한 증거가 아닙니다" -Label "Next CAD action dirty suite meaning"
Assert-Contains -Text $nextCadActionRunnerText -Needle "과거 guard 증거로만 봅니다" -Label "Next CAD action stale suite meaning"
Assert-Contains -Text $nextCadActionRunnerText -Needle "자동화/guard 검증은 통과했습니다" -Label "Next CAD action suite pass meaning"
Assert-Contains -Text $nextCadActionRunnerText -Needle "suite가 최종 PASS 전에 멈췄습니다" -Label "Next CAD action suite failure meaning"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Write-FinalCompletionGateSummary" -Label "Next CAD action final completion gate helper"
Assert-Contains -Text $nextCadActionRunnerText -Needle "최근 final completion gate 요약:" -Label "Next CAD action final completion gate heading"
Assert-Contains -Text $nextCadActionRunnerText -Needle "실제 작업복사본 완료 증거가 아직 없습니다" -Label "Next CAD action final completion gate incomplete meaning"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Final gate/direct probe 일치 확인:" -Label "Next CAD action final/direct consistency heading"
Assert-Contains -Text $nextCadActionRunnerText -Needle "REVIEW_FINAL_GATE_DIRECT_PROBE_CONFLICT" -Label "Next CAD action final/direct conflict guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "최신 final completion gate와 direct probe가 서로 다른 다음 상태를 가리킵니다" -Label "Next CAD action final/direct conflict explanation"
Assert-Contains -Text $nextCadActionRunnerText -Needle "RUN_PREPARE_FIRST" -Label "Next CAD action prepare-first guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "RUN_NATIVE_REPLACEMENT" -Label "Next CAD action native replacement guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "REVIEW_STRUCTURE_BEFORE_CONVERT" -Label "Next CAD action structure review guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "CREATE_MISSING_NATIVE_GMTITLE_SIZE" -Label "Next CAD action missing native exemplar guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "VERIFY_NOT_FINAL" -Label "Next CAD action verify-not-final guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "수동 GstarCAD 단계" -Label "Next CAD action Korean manual visible CAD wording"
Assert-Contains -Text $nextCadActionRunnerText -Needle "작업복사본을 보이는 GstarCAD로 열 수 있습니다" -Label "Next CAD action open-workcopy wording"
Assert-Contains -Text $nextCadActionRunnerText -Needle "helper는 기본적으로 /b startup script를 쓰지 않으므로" -Label "Next CAD action open-helper no-startup-script wording"
Assert-Contains -Text $nextCadActionRunnerText -Needle "정상 버전:" -Label "Next CAD action expected loaded version guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLESTATUS  (현재 열린 DWG와 다음 상태 확인)" -Label "Next CAD action visible-CAD status preflight"
Assert-Contains -Text $nextCadActionRunnerText -Needle "화면 캡처는 가능하지만 활성화/클릭/입력은 안정적이지 않습니다" -Label "Next CAD action Korean Computer Use limitation wording"
Assert-Contains -Text $nextCadActionRunnerText -Needle 'CAD가 `_pasteclip` 삽입 명령으로 해석할 수 있습니다' -Label "Next CAD action pasteclip warning"
Assert-Contains -Text $computerUseHistoryText -Needle "failed to activate captured window" -Label "Computer Use activation failure history"
Assert-Contains -Text $computerUseHistoryText -Needle "Do not repeat the same visible-CAD Computer Use click/type attempt as a default path" -Label "Computer Use no-repeat guidance"
Assert-Contains -Text $computerUseA3DialogHistoryText -Needle '`SWTITLECONVERTNEXT` started correctly' -Label "Computer Use A3 dialog reached through SWTITLECONVERTNEXT"
Assert-Contains -Text $computerUseA3DialogHistoryText -Needle "UIA value is read-only" -Label "Computer Use A3 dialog combo read-only evidence"
Assert-Contains -Text $computerUseA3DialogHistoryText -Needle "not exposed as a separate targetable window" -Label "Computer Use A3 dialog window-target evidence"
Assert-Contains -Text $computerUseA3DialogHistoryText -Needle "did **not** click screen coordinates" -Label "Computer Use A3 no screen-coordinate fallback"
Assert-Contains -Text $nextCadActionRunnerText -Needle "용지/도면틀:" -Label "Next CAD action Korean dialog paper guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERTNEXT  (권장: YES/OPEN 반복 응답 자동 선택)" -Label "Next CAD action convert-next shortcut guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "또는 수동 응답을 직접 고르려면: SWTITLECONVERT" -Label "Next CAD action manual convert fallback guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Write-AutomationBoundarySummary" -Label "Next CAD action automation boundary helper"
Assert-Contains -Text $nextCadActionRunnerText -Needle "자동화 경계:" -Label "Next CAD action automation boundary heading"
Assert-Contains -Text $nextCadActionRunnerText -Needle "LSP가 자동 처리: 현재 후보 판별" -Label "Next CAD action LSP automation scope"
Assert-Contains -Text $nextCadActionRunnerText -Needle "사람이 확인: GMTITLE 창의 DR_A*_Outline 용지" -Label "Next CAD action human GMTITLE scope"
Assert-Contains -Text $nextCadActionRunnerText -Needle "아직 자동화하지 않는 이유: GstarCAD GMTITLE 창이 일반/ISO 기본값으로 열릴 수 있고" -Label "Next CAD action no unsafe full automation reason"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERTNEXT는 같은 흐름에서 YES/OPEN 같은 반복 응답만 자동 선택합니다" -Label "Next CAD action convert-next scope guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERTNEXT 또는 수동 SWTITLECONVERT 흐름이 GMTITLE 호출" -Label "Next CAD action convert-next integrated flow wording"
Assert-Contains -Text $nextCadActionRunnerText -Needle "좌표 입력, 값 복사, 기존 원본 정리는 SWTITLECONVERTNEXT 또는 수동 SWTITLECONVERT 흐름이 자동 처리합니다" -Label "Next CAD action convert-next cleanup wording"
Assert-Contains -Text $nextCadActionRunnerText -Needle "같은 SWTITLECONVERT를 반복하지 말고" -Label "Next CAD action no-repeat convert warning"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Object move: OFF" -Label "Next CAD action Object move guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "GMTITLE, TIT, 일반 OPEN을 직접 입력하지 마세요" -Label "Next CAD action raw GMTITLE/TIT/OPEN guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERT 안에서 물어보는 YES/OPEN/BATCH/MANUAL 응답과 CAD 일반 OPEN 명령은 다릅니다" -Label "Next CAD action convert prompt versus CAD OPEN guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "긴 좌표를 사람이 직접 치지 마세요" -Label "Next CAD action lower-left auto placement guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERTNEXT 또는 수동 SWTITLECONVERT 흐름이 GMTITLE 창 뒤에 왼쪽 아래 배치점을 자동 전송합니다" -Label "Next CAD action convert-next placement wording"
Assert-NotContains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERT가 GMTITLE 호출" -Label "Next CAD action stale direct convert integrated flow"
Assert-NotContains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERT가 GMTITLE 창 뒤에 왼쪽 아래 배치점을 자동 전송합니다" -Label "Next CAD action stale direct convert placement"
Assert-Contains -Text $nextCadActionRunnerText -Needle "커서가 화면 중앙에 남아 보여도" -Label "Next CAD action center-cursor placement guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "REFRESH_DIRECT_PROBE_FIRST" -Label "Next CAD action direct-probe refresh guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERT/SWTITLECONVERTNEXT에서 나올 수 있는 입력" -Label "Next CAD action convert prompt guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERTNEXT는 아래 반복 응답 중 현재 상태의 안전한 다음 값만 자동 선택합니다" -Label "Next CAD action convert-next auto response guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERTNEXT를 쓰는 경우 사용자가 YES/OPEN/BATCH/MANUAL을 다시 입력하지 않습니다." -Label "Next CAD action no extra auto-next response guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "아래 항목은 수동 SWTITLECONVERT를 쓸 때의 응답 의미를 이해하기 위한 설명입니다." -Label "Next CAD action manual-response meaning guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "작업복사본을 저장하고 GstarCAD를 닫은 뒤 아래 래퍼를 실행하세요" -Label "Next CAD action after-manual wrapper first"
Assert-Contains -Text $nextCadActionRunnerText -Needle "run_after_manual_gmtitle_step.ps1" -Label "Next CAD action after-manual wrapper command"
Assert-Contains -Text $nextCadActionRunnerText -Needle "-Compact" -Label "Next CAD action compact after-manual option"
Assert-Contains -Text $nextCadActionRunnerText -Needle "화면에는 다음 한 단계 요약만 보여줍니다" -Label "Next CAD action compact after-manual summary"
Assert-Contains -Text $nextCadActionRunnerText -Needle "GstarCAD를 계속 열어 둔 상태에서는 hidden probe가 현재 화면 상태와 엇갈릴 수 있습니다" -Label "Next CAD action hidden probe closed-CAD guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "YES: 첫 native GMTITLE 1장을 만들고 마무리합니다." -Label "Next CAD action first-native YES guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "OPEN: 다음 A2/A3/A4 후보 1장만 fresh native GMTITLE로 교체합니다." -Label "Next CAD action native OPEN guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "BATCH: OPEN으로 최소 1장 성공한 뒤" -Label "Next CAD action native BATCH after OPEN guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "MANUAL: OPEN이 새 GMTITLE을 못 잡거나 NO_INSERTS가 반복될 때만 사용합니다." -Label "Next CAD action native MANUAL guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "실제 DR_titlea_3rd 제목블록이 있는 대표 A2/A3 용지만 더블클릭하세요." -Label "Next CAD action final title-only double-click guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "원본 표제란 부재가 검증된 title-missing/frame-only 시트는 더블클릭할 제목블록이 없으므로" -Label "Next CAD action final title-missing guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "DR_A*_Outline 도면틀을 더블클릭하면 GMPOWEREDIT/REFEDIT가 열릴 수 있으니" -Label "Next CAD action final frame double-click guard"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "run_next_cad_action.ps1" -Label "After-manual wrapper next-action card call"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "-AutoRefreshDirectProbe" -Label "After-manual wrapper direct probe refresh"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "run_final_completion_gate.ps1" -Label "After-manual wrapper optional final gate"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "CLOSE_GSTARCAD_FIRST" -Label "After-manual wrapper visible GstarCAD close guard"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "GMTITLE 수동 한 장 처리 후 점검" -Label "After-manual wrapper Korean heading"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "목적: visible CAD에서 GMTITLE 한 장을 처리하고 저장/닫은 뒤" -Label "After-manual wrapper Korean purpose"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "안전: 이 래퍼는 DWG를 편집하지 않습니다" -Label "After-manual wrapper Korean safety"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "실행 중인 GstarCAD가 없습니다. 계속 진행합니다" -Label "After-manual wrapper Korean closed-CAD message"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "SWTITLECONVERTNEXT를 무작정 반복하지 마세요" -Label "After-manual wrapper Korean no-repeat warning"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "수동 GMTITLE 후속 점검 로그 저장" -Label "After-manual wrapper Korean saved-log message"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "AFTER_MANUAL_STEP_NEXT_ACTION_READY" -Label "After-manual wrapper next-action result"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "AFTER_MANUAL_STEP_FINAL_GATE_PASSED" -Label "After-manual wrapper final-pass result"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "AFTER_MANUAL_STEP_FINAL_GATE_NOT_PASSED" -Label "After-manual wrapper final-fail summary"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "DryRun" -Label "After-manual wrapper dry-run option"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "Compact" -Label "After-manual wrapper compact option"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "Write-AfterManualCardShortSummary" -Label "After-manual wrapper compact short summary helper"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "function Get-LastRegexValue" -Label "After-manual wrapper latest-value parser"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle '$result = Get-LastRegexValue -Text $CardText -Pattern "^Result:\s*(\S+)\s*$"' -Label "After-manual wrapper latest result summary"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle '$status = Get-LastRegexValue -Text $CardText -Pattern "^(?:\s*SWTITLESTATUS:|현재 저장 상태:)\s*(\S+)"' -Label "After-manual wrapper latest status summary"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle '$frame = Get-LastRegexValue -Text $CardText -Pattern "^\s*(?:용지/도면틀|다음 GMTITLE 용지/도면틀):\s*(DR_A[1-4]_Outline)\b"' -Label "After-manual wrapper latest frame summary"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "SuppressChildOutput" -Label "After-manual wrapper compact child-output suppression"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "수동 GMTITLE 처리 후 다음 작업 짧은 요약:" -Label "After-manual wrapper compact short summary heading"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "긴 PowerShell 실행 명령줄은 -Compact 때문에 화면에서 숨겼습니다" -Label "After-manual wrapper compact command suppression"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "전체 내용은 로그 파일에 저장합니다" -Label "After-manual wrapper compact full-log retention"
Assert-Contains -Text $afterManualGmtitleStepRunnerText -Needle "[Console]::Out.WriteLine" -Label "After-manual wrapper screen output is not captured by return assignment"
Assert-Contains -Text $readmeText -Needle "run_after_manual_gmtitle_step.ps1" -Label "README after-manual wrapper guidance"
Assert-Contains -Text $readmeText -Needle "work\swtitle_after_manual_gmtitle_step_last.txt" -Label "README after-manual wrapper log path"
Assert-Contains -Text $readmeText -Needle "-Compact" -Label "README compact option coverage"
Assert-Contains -Text $readmeText -Needle "prints a short next-step summary" -Label "README after-manual short summary"
Assert-Contains -Text $readmeText -Needle "run_manual_gmtitle_session.ps1" -Label "README manual session wrapper guidance"
Assert-Contains -Text $readmeText -Needle 'does not run `SWTITLECONVERTNEXT`' -Label "README manual session no-convert guard"
Assert-Contains -Text $readmeText -Needle 'runs `run_next_cad_action.ps1` without auto-refresh by default' -Label "README manual session initial next-action card"
Assert-Contains -Text $readmeText -Needle "SkipInitialNextActionCard" -Label "README manual session skip initial card guard"
Assert-Contains -Text $readmeText -Needle "PreflightOnly" -Label "README manual session preflight-only guidance"
Assert-Contains -Text $readmeText -Needle 'Add `-Compact`' -Label "README manual session compact guidance"
Assert-Contains -Text $readmeText -Needle "SKIP_OPEN_NO_GSTARCAD" -Label "README manual session skip-open guard"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "Next CAD action card probe result: PASS" -Label "Next CAD action card probe pass marker"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "NEXT_CREATE_FIRST_NATIVE_GMTITLE" -Label "Next CAD action card probe first-native case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION" -Label "Next CAD action card probe title-missing prepare case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "NEXT_UPGRADE_A3_A4_NATIVE" -Label "Next CAD action card probe native-upgrade case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "NEXT_REVIEW_TARGET_FRAME_GEOMETRY" -Label "Next CAD action card probe structure-review case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS" -Label "Next CAD action card probe abort-warning case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "SWTITLEVERIFY_FINAL_OK" -Label "Next CAD action card probe final-ok case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle '"SWTITLECONVERTNEXT", "DR_A2_Outline", "DR_titlea_3rd", "YES/OPEN"' -Label "Next CAD action card probe first-native token expectation"
Assert-Contains -Text $nextCadActionCardProbeText -Needle '"Result: RUN_NATIVE_REPLACEMENT", "SWTITLECONVERTNEXT", "SWTITLECONVERT", "OPEN", "BATCH", "MANUAL"' -Label "Next CAD action card probe native replacement token expectation"
Assert-Contains -Text $nextCadActionCardProbeText -Needle '"Result: RELOAD_LSP_AND_CONFIRM_STATUS", "Direct probe LSP", "APPLOAD", "SWTITLESTATUS", "SWTITLECONVERTNEXT"' -Label "Next CAD action card probe stale-version reload expectation"
Assert-Contains -Text $nextCadActionCardProbeText -Needle '"Result: RELOAD_LSP_AND_CONFIRM_STATUS", "final gate", "-AutoRefreshDirectProbe"' -Label "Next CAD action card probe missing-log final-gate fallback expectation"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "MissingLog" -Label "Next CAD action card probe missing-log case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "MakeStale" -Label "Next CAD action card probe stale-log case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "stale_version" -Label "Next CAD action card probe stale-version case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "Invoke-SandboxCorrectionCase" -Label "Next CAD action card probe sandbox-correction case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "Assert-NotContains" -Label "Next CAD action card probe sandbox APPLOAD negative check"
Assert-Contains -Text $finalCompletionGateText -Needle "Final completion gate result: FAIL" -Label "Final completion gate actionable failure summary"
Assert-Contains -Text $finalCompletionGateText -Needle "TimeoutSeconds = 180" -Label "Final completion gate longer timeout"
Assert-Contains -Text $finalCompletionGateText -Needle "WaitForGstarCADClose" -Label "Final completion gate GstarCAD-close wait option"
Assert-Contains -Text $finalCompletionGateText -Needle "Existing GstarCAD process detected before the final completion gate" -Label "Final completion gate existing-GstarCAD guard"
Assert-Contains -Text $finalCompletionGateText -Needle "Current status-after-status" -Label "Final completion gate status-after-status summary"
Assert-Contains -Text $finalCompletionGateText -Needle "Current status-after-verify" -Label "Final completion gate status-after-verify summary"
Assert-Contains -Text $finalCompletionGateText -Needle "Current source counts:" -Label "Final completion gate source-count summary"
Assert-Contains -Text $finalCompletionGateText -Needle "Current target counts:" -Label "Final completion gate target-count summary"
Assert-Contains -Text $finalCompletionGateText -Needle "Next first native GMTITLE selection:" -Label "Final completion gate next-native selection summary"
Assert-Contains -Text $finalCompletionGateText -Needle "Missing native frames:" -Label "Final completion gate missing-native summary"
Assert-Contains -Text $finalCompletionGateText -Needle "run_next_cad_action.ps1" -Label "Final completion gate next action guidance"
Assert-Contains -Text $finalCompletionGateText -Needle "representative DR_titlea_3rd title-block double-click checks" -Label "Final completion gate representative title double-click reminder"
Assert-Contains -Text $finalCompletionGateText -Needle "Title-missing/frame-only sheets have no DR_titlea_3rd title block by design" -Label "Final completion gate title-missing reminder"
Assert-Contains -Text $finalCompletionGateText -Needle "Final automated completion evidence passed." -Label "Final completion gate automated-pass wording"
Assert-Contains -Text $readmeText -Needle 'representative `DR_titlea_3rd` title blocks' -Label "README final completion representative title guidance"
Assert-Contains -Text $readmeText -Needle "Title-missing/frame-only sheets do not have a" -Label "README final completion title-missing guidance"
Assert-Contains -Text $readmeText -Needle "final completion gate uses a default timeout of 180 seconds" -Label "README final completion gate timeout guidance"
Assert-Contains -Text $readmeText -Needle "Save and close GstarCAD first, or use ``-WaitForGstarCADClose``" -Label "README final completion wait option"
Assert-Contains -Text $readmeText -Needle "Current source counts:" -Label "README final completion source-count failure summary"
Assert-Contains -Text $readmeText -Needle "Next first native GMTITLE selection:" -Label "README final completion next-native failure summary"
Assert-Contains -Text $selectionConfigProbeText -Needle "GMTITLE_SELECTION_CONFIG_NOT_FOUND" -Label "Selection config probe negative result"
Assert-Contains -Text $selectionConfigProbeText -Needle "Direct GMTITLE may still reuse an internal/current command state" -Label "Selection config probe direct-GMTITLE warning"
Assert-Contains -Text $selectionConfigProbeText -Needle "ribbon/menu IMTITLE macro" -Label "Selection config probe IMTITLE macro note"
Assert-Contains -Text $selectionConfigProbeText -Needle "Command surface language note" -Label "Selection config probe command-surface language note"
Assert-Contains -Text $selectionConfigProbeText -Needle "AppData text marker scan note" -Label "Selection config probe AppData advisory scan note"
Assert-Contains -Text $selectionConfigProbeText -Needle "recent-file history" -Label "Selection config probe recent-file registry non-evidence"
Assert-NoKnownMojibake -Text $commandSurfaceHistoryText -Label "Command surface history"
Assert-NoKnownMojibake -Text $automationBoundaryHistoryText -Label "Automation boundary history"
Assert-NoKnownMojibake -Text $selectionConfigDeepRegistryHistoryText -Label "Selection config deep registry history"
Assert-NoKnownMojibake -Text $finalCompletionGateHistoryText -Label "Final completion gate history"
Assert-NoKnownMojibake -Text $readmeText -Label "Diagnostics README"
Assert-NoKnownMojibake -Text $unifiedFlowResetGuideText -Label "Unified flow reset guide"
Assert-Contains -Text $commandSurfaceHistoryText -Needle "GMTITLE 명령/설정 표면 재확인" -Label "Command surface history readable Korean title"
Assert-Contains -Text $commandSurfaceHistoryText -Needle "Result: GMTITLE_SELECTION_CONFIG_NOT_FOUND" -Label "Command surface history selection config result"
Assert-Contains -Text $commandSurfaceHistoryText -Needle "리본 버튼 좌표 클릭은 자동화 근거로 채택하지 않는다" -Label "Command surface history no coordinate automation"
Assert-Contains -Text $automationBoundaryHistoryText -Needle "GMTITLE 자동화 경계 감사" -Label "Automation boundary history readable Korean title"
Assert-Contains -Text $automationBoundaryHistoryText -Needle "CAD 명령줄에 GMTITLE, TIT, 일반 OPEN을 직접 입력하지 않는다" -Label "Automation boundary raw command guard"
Assert-Contains -Text $unifiedFlowResetGuideText -Needle "A2, A3, A4는 모두 같은 GMTITLE입니다" -Label "Unified reset A2/A3/A4 same-flow rule"
Assert-Contains -Text $unifiedFlowResetGuideText -Needle '`A4`라는 용지 크기만으로 별도 frame-only 흐름을 선택하지 않습니다' -Label "Unified reset no A4-only frame-only rule"
Assert-Contains -Text $unifiedFlowResetGuideText -Needle '`frame-only`는 A4 전용 정책이 아닙니다' -Label "Unified reset title-missing exception rule"
Assert-Contains -Text $rootReadmeText -Needle '`frame-only`는 A4 전용이 아니라 원본 표제란/제목블록 부재가 검증된 경우에만 예외로 처리합니다.' -Label "Root README title-missing exception rule"
Assert-NotContains -Text $rootReadmeText -Needle "A4처럼 표제란 없는 frame-only" -Label "Root README no stale A4-only frame-only wording"
Assert-Contains -Text $selectionConfigDeepRegistryHistoryText -Needle "Recent File List" -Label "Selection config deep registry recent-file evidence"
Assert-Contains -Text $selectionConfigDeepRegistryHistoryText -Needle "최근 직접 열었던 파일 기록" -Label "Selection config deep registry non-evidence conclusion"
Assert-Contains -Text $selectionConfigDeepRegistryHistoryText -Needle "자동 선택할 근거가 없다" -Label "Selection config deep registry no-preselection conclusion"
Assert-Contains -Text $finalCompletionGateHistoryText -Needle "Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE" -Label "Final completion gate history status"
Assert-Contains -Text $finalCompletionGateHistoryText -Needle "Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL" -Label "Final completion gate history verify fail"
Assert-Contains -Text $finalCompletionGateHistoryText -Needle "target-title-count: 0" -Label "Final completion gate history target-title count"
Assert-Contains -Text $finalCompletionGateHistoryText -Needle "next-bootstrap-frame: DR_A2_Outline" -Label "Final completion gate history next frame"
Assert-Contains -Text $finalCompletionGateHistoryText -Needle "SWTITLECONVERTNEXT" -Label "Final completion gate history next command"
Assert-Contains -Text $readmeText -Needle "screenshot-coordinate ribbon clicks are not accepted as automation evidence" -Label "README ribbon coordinate automation warning"
Assert-Contains -Text $readmeText -Needle "AppData text marker scan is advisory" -Label "README AppData advisory scan guidance"
Assert-Contains -Text $goalStatusText -Needle "Write-NativeFrameProgressSummary" -Label "Goal status native-frame progress summary"
Assert-Contains -Text $goalStatusText -Needle "Convert-LegacyTitleMissingStatusLine" -Label "Goal status legacy title-missing status normalization"
Assert-Contains -Text $goalStatusText -Needle "[System.Text.UTF8Encoding]::new(`$true, `$true)" -Label "Goal status strict UTF-8 log fallback"
Assert-Contains -Text $goalStatusText -Needle "[System.Text.Encoding]::GetEncoding(949)" -Label "Goal status CP949 log fallback"
Assert-Contains -Text $goalStatusText -Needle "function Test-TextLooksMojibake" -Label "Goal status mojibake detector"
Assert-Contains -Text $goalStatusText -Needle "function Convert-SheetCountLine" -Label "Goal status sheet-count sanitizer"
Assert-Contains -Text $goalStatusText -Needle "function Convert-SafeCadLogLine" -Label "Goal status safe CAD log formatter"
Assert-Contains -Text $goalStatusText -Needle '$safeLine = Convert-SafeCadLogLine -Line $line.Trim()' -Label "Goal status missing-count safe formatter use"
Assert-Contains -Text $goalStatusText -Needle '$safeCompletion = Convert-SafeCadLogLine -Line $completion' -Label "Goal status native completion safe formatter use"
Assert-Contains -Text $goalStatusText -Needle 'Result code: {0}' -Label "Goal status mojibake result-code fallback"
$goalStatusUtf8Index = $goalStatusText.IndexOf("[System.Text.UTF8Encoding]::new(`$true, `$true)", [System.StringComparison]::Ordinal)
$goalStatusCp949Index = $goalStatusText.IndexOf("[System.Text.Encoding]::GetEncoding(949)", [System.StringComparison]::Ordinal)
if ($goalStatusUtf8Index -ge 0 -and $goalStatusCp949Index -ge 0 -and $goalStatusUtf8Index -lt $goalStatusCp949Index) {
  Write-Output "Goal status log fallback order: UTF-8 before CP949"
} else {
  Add-Failure "Goal status log fallback order must try strict UTF-8 before CP949 to avoid mojibake in UTF-8 CAD logs."
}
Assert-Contains -Text $goalStatusText -Needle "Stale direct-probe version" -Label "Goal status stale direct-probe version warning"
Assert-Contains -Text $goalStatusText -Needle "최신 열린 CAD 로그 상태" -Label "Goal status latest CAD fallback for stale direct probe"
Assert-Contains -Text $goalStatusText -Needle "DR_A4_Outline definition decision" -Label "Goal status DR_A4 definition decision guidance"
Assert-Contains -Text $goalStatusText -Needle "superseded by the official native outside marker policy" -Label "Goal status A4 superseded normalization guidance"
Assert-Contains -Text $goalStatusText -Needle "official native outside markers are tolerated when effective A4 geometry and raw-selection checks pass" -Label "Goal status A4 adopted outside marker policy"
Assert-Contains -Text $goalStatusText -Needle "Title-missing definition investigation continuation" -Label "Goal status title-missing nested probe continuation guidance"
Assert-Contains -Text $goalStatusText -Needle "DR_A4_Outline normalization candidate review" -Label "Goal status DR_A4 safe-candidate review guidance"
Assert-Contains -Text $goalStatusText -Needle "DR_A4_Outline native comparison investigation" -Label "Goal status DR_A4 unsafe-nested fallback guidance"
Assert-Contains -Text $goalStatusText -Needle "scratch DWG with one real native A4 GMTITLE" -Label "Goal status A4 scratch-native comparison guidance"
Assert-Contains -Text $goalStatusText -Needle "production source-title-missing/frame-only sheets must still not receive a new title block" -Label "Goal status source-title-missing no-production-title guidance"
Assert-Contains -Text $goalStatusText -Needle "Native GMTITLE A4 pair evidence: yes" -Label "Goal status A4 native pair evidence guidance"
Assert-Contains -Text $goalStatusText -Needle "A4_NATIVE_EXEMPLAR_MISSING_NATIVE_PAIR" -Label "Goal status A4 missing native pair guidance"
Assert-Contains -Text $goalStatusText -Needle "Goal-log trust" -Label "Goal status latest-log trust marker"
Assert-Contains -Text $goalStatusText -Needle "latest CAD log is ignored for goal next-action selection" -Label "Goal status scratch-log ignore guidance"
Assert-Contains -Text $goalStatusText -Needle "ignored for goal next-action selection because this native-frame log belongs to a scratch/probe/compare DWG" -Label "Goal status scratch native-frame ignore guidance"
Assert-Contains -Text $goalStatusText -Needle "먼저 전체 hidden suite를 돌리지 마세요" -Label "Goal status A4 probe before suite guidance"
Assert-Contains -Text $goalStatusText -Needle "If direct GMTITLE only asks for an insertion point, cancel it" -Label "Goal status direct-GMTITLE insertion prompt warning"
Assert-Contains -Text $goalStatusText -Needle "frame creation error and DR_titlea_3rd inserts=0" -Label "Goal status A4 frame creation error guidance"
Assert-Contains -Text $goalStatusText -Needle "scratch_native_a4_clean_260705.dwg" -Label "Goal status saved clean A4 scratch guidance"
Assert-Contains -Text $goalStatusText -Needle "swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt" -Label "Goal status saved clean A4 scratch log guidance"
Assert-Contains -Text $goalStatusText -Needle "DR_A4_Outline native outside-marker decision" -Label "Goal status DR_A4 outside marker decision guidance"
Assert-Contains -Text $goalStatusText -Needle "official native outside markers" -Label "Goal status A4 official marker guidance"
Assert-Contains -Text $goalStatusText -Needle "다음 작업:" -Label "Goal status Korean next-action heading"
Assert-Contains -Text $goalStatusText -Needle "Title-missing/frame-only exception evidence (source-title-missing; current sample happens to be A4):" -Label "Goal status generic title-missing evidence heading"
Assert-Contains -Text $goalStatusText -Needle "not an A4 action yet. The trusted direct work-copy probe says the next missing native exemplar is" -Label "Goal status direct-probe priority over stale A4 action"
Assert-Contains -Text $goalStatusText -Needle "source-title-missing evidence, not an A4-only conversion policy" -Label "Goal status title-missing exception not A4 policy"
Assert-Contains -Text $goalStatusText -Needle "title-missing/frame-only 예외 경로는 현재 A4 샘플로 검증됨" -Label "Goal status Korean title-missing verified guidance"
Assert-Contains -Text $goalStatusText -Needle "실제 작업복사본 우선 단계" -Label "Goal status direct work-copy priority heading"
Assert-Contains -Text $goalStatusText -Needle "title-missing/frame-only A4 샘플 증거는 배경 정보입니다" -Label "Goal status A4 sample is background evidence"
Assert-NotContains -Text $goalStatusText -Needle "A4 native outside-marker policy is implemented" -Label "Goal status stale A4 policy wording"
Assert-NotContains -Text $goalStatusText -Needle "Production A4 frame-only must still not create" -Label "Goal status stale production A4 wording"
Assert-Contains -Text $goalStatusText -Needle "다음 실제 작업복사본 단계" -Label "Goal status Korean real work-copy step guidance"
Assert-Contains -Text $goalStatusText -Needle "SWTITLESTATUS로 현재 활성 DWG와 다음 상태를 먼저 확인하세요" -Label "Goal status visible-CAD status preflight"
Assert-Contains -Text $goalStatusText -Needle "가장 짧은 다음 CAD 선택 요약" -Label "Goal status compact preflight heading"
Assert-Contains -Text $goalStatusText -Needle "run_manual_gmtitle_session.ps1" -Label "Goal status manual session wrapper command"
Assert-Contains -Text $goalStatusText -Needle "-PreflightOnly -Compact" -Label "Goal status compact preflight command"
Assert-Contains -Text $goalStatusText -Needle "CAD를 열기 전에 이번에 고를 DR 용지/제목블록/옵션과 CAD 명령 순서만 확인합니다" -Label "Goal status compact preflight purpose"
Assert-Contains -Text $goalStatusText -Needle "짧은 다음 작업 카드 전체" -Label "Goal status short next-action card command"
Assert-Contains -Text $goalStatusText -Needle "run_next_cad_action.ps1" -Label "Goal status next-action card script command"
Assert-Contains -Text $goalStatusText -Needle "-AutoRefreshDirectProbe" -Label "Goal status next-action auto-refresh hint"
Assert-Contains -Text $goalStatusText -Needle "작업복사본 열기부터 수동 한 장 처리 후 점검까지 한 번에 대기" -Label "Goal status manual session wrapper heading"
Assert-Contains -Text $goalStatusText -Needle "수동 GMTITLE 한 장 처리 후 권장 점검" -Label "Goal status after-manual wrapper heading"
Assert-Contains -Text $goalStatusText -Needle "run_after_manual_gmtitle_step.ps1" -Label "Goal status after-manual wrapper command"
Assert-Contains -Text $goalStatusText -Needle "-Compact" -Label "Goal status compact option coverage"
Assert-Contains -Text $goalStatusText -Needle "화면에는 다음 한 단계 요약만 보여줍니다" -Label "Goal status after-manual compact scope"
Assert-Contains -Text $goalStatusText -Needle "목표 상태: 실제 작업복사본이 SWTITLEVERIFY_FINAL_OK에 도달" -Label "Goal status Korean completion reminder"
Assert-Contains -Text $cadTextLogReaderText -Needle "Get-LogEncodingAndText" -Label "CAD text log reader encoding helper"
Assert-Contains -Text $cadTextLogReaderText -Needle "UTF8Encoding" -Label "CAD text log reader strict UTF-8 check"
Assert-Contains -Text $cadTextLogReaderText -Needle "[System.Text.Encoding]::Default" -Label "CAD text log reader Windows-default fallback"
Assert-Contains -Text $cadTextLogReaderText -Needle "Safety: this script only reads text files" -Label "CAD text log reader read-only safety"
Assert-Contains -Text $cadTextLogReaderText -Needle "Result: READ_LOG_OK" -Label "CAD text log reader success marker"
Assert-Contains -Text $cadTextLogReaderText -Needle "Result: LISTED_LOGS" -Label "CAD text log reader list marker"
Assert-Contains -Text $cadTextLogReaderText -Needle "Find regex:" -Label "CAD text log reader find support"
Assert-Contains -Text $readmeText -Needle "A4 clean scratch evidence" -Label "README clean A4 scratch evidence"
Assert-Contains -Text $readmeText -Needle "Actual Work-Copy Direct Status Probe" -Label "README direct actual work-copy probe guidance"
Assert-Contains -Text $readmeText -Needle "default timeout is 180 seconds" -Label "README direct actual work-copy timeout guidance"
Assert-Contains -Text $readmeText -Needle "different GMTITLE LSP version" -Label "README direct-probe version refresh guidance"
Assert-Contains -Text $readmeText -Needle "run_next_cad_action.ps1" -Label "README next CAD action guidance"
Assert-Contains -Text $readmeText -Needle "swtitle_final_completion_gate_status.txt" -Label "README final/direct probe comparison guidance"
Assert-Contains -Text $readmeText -Needle "REVIEW_FINAL_GATE_DIRECT_PROBE_CONFLICT" -Label "README final/direct conflict guard"
Assert-Contains -Text $readmeText -Needle "A4_NATIVE_EXEMPLAR_READY_WITH_NATIVE_OUTSIDE_MARKERS" -Label "README clean A4 outside marker result"
Assert-Contains -Text $readmeText -Needle "swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt" -Label "README clean A4 scratch dedicated log"
Assert-Contains -Text $goalStatusText -Needle "run_gmtitle_selection_config_probe.ps1" -Label "Goal status selection config probe guidance"
Assert-Contains -Text $goalStatusText -Needle "Direct actual work-copy probe" -Label "Goal status direct actual work-copy probe summary"
Assert-Contains -Text $goalStatusText -Needle "loaded-version:" -Label "Goal status direct-probe loaded version output"
Assert-Contains -Text $goalStatusText -Needle "manual-forecast-log-note-found:" -Label "Goal status direct-probe manual forecast evidence"
Assert-Contains -Text $goalStatusText -Needle "Write-HiddenSuiteLastRunSummary" -Label "Goal status hidden suite summary helper"
Assert-Contains -Text $goalStatusText -Needle "Hidden verification suite last run" -Label "Goal status hidden suite summary heading"
Assert-Contains -Text $goalStatusText -Needle "main56_verification_suite_last_run.txt" -Label "Goal status hidden suite summary path"
Assert-Contains -Text $goalStatusText -Needle "Commit time:" -Label "Goal status commit time output"
Assert-Contains -Text $goalStatusText -Needle "Suite log older than current commit" -Label "Goal status stale suite flag"
Assert-Contains -Text $goalStatusText -Needle "Working tree: dirty" -Label "Goal status dirty worktree output"
Assert-Contains -Text $goalStatusText -Needle "current uncommitted changes" -Label "Goal status dirty suite meaning"
Assert-Contains -Text $goalStatusText -Needle "historical guard evidence until /b smoke passes" -Label "Goal status stale suite meaning"
Assert-Contains -Text $goalStatusText -Needle "automation/guard probes passed; this is not proof that the real work DWG finished conversion" -Label "Goal status hidden suite pass boundary"
Assert-Contains -Text $goalStatusText -Needle "the suite stopped before final PASS" -Label "Goal status hidden suite failure boundary"
Assert-Contains -Text $goalStatusText -Needle "Write-FinalCompletionGateSummary" -Label "Goal status final completion gate helper"
Assert-Contains -Text $goalStatusText -Needle "Final completion gate last run" -Label "Goal status final completion gate heading"
Assert-Contains -Text $goalStatusText -Needle "real work-copy completion evidence is still missing" -Label "Goal status final completion gate incomplete meaning"
Assert-Contains -Text $goalStatusText -Needle "not an A4 blocker yet" -Label "Goal status first-native before A4 interpretation"
Assert-Contains -Text $goalStatusText -Needle "target title/frame counts 0/0" -Label "Goal status target-zero first-native interpretation"
Assert-Contains -Text $goalStatusText -Needle "GstarCAD /b script smoke probe" -Label "Goal status GstarCAD /b script smoke summary"
Assert-Contains -Text $goalStatusText -Needle "WindowStyle=Minimized" -Label "Goal status minimized smoke probe guidance"

$runCardText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-current-run-card.md")
$goalPlanText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-goal-mode-plan.md")
$commandsGuideText = Read-Text (Join-Path $repoRoot "docs\guide\commands.md")
$cadChecklistText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-cad-conversion-checklist.md")
$nativeUpgradeGuideText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-native-frame-upgrade.md")
$resumeGuideText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-resume-on-another-computer.md")
$hiddenSuitePassHistoryText = Read-Text $hiddenSuitePassHistoryPath
Assert-NoKnownMojibake -Text $hiddenSuitePassHistoryText -Label "Hidden suite pass history"
Assert-Contains -Text $runCardText -Needle "scratch_native_a4_clean_260705.dwg" -Label "Run card clean A4 scratch evidence"
Assert-Contains -Text $runCardText -Needle "기본 제한 시간을 180초" -Label "Run card direct probe timeout guidance"
Assert-Contains -Text $runCardText -Needle "final completion gate가 direct probe보다 최신이면" -Label "Run card final/direct comparison guidance"
Assert-Contains -Text $runCardText -Needle "REVIEW_FINAL_GATE_DIRECT_PROBE_CONFLICT" -Label "Run card final/direct conflict guard"
Assert-Contains -Text $goalPlanText -Needle "2026-07-05 clean scratch CAD" -Label "Goal plan clean A4 scratch evidence"
Assert-Contains -Text $runCardText -Needle "A4_NATIVE_EXEMPLAR_READY_WITH_NATIVE_OUTSIDE_MARKERS" -Label "Run card clean A4 outside marker result"
Assert-Contains -Text $goalPlanText -Needle "official native outside marker" -Label "Goal plan A4 official marker decision"
Assert-Contains -Text $runCardText -Needle "swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt" -Label "Run card clean A4 scratch dedicated log"
Assert-Contains -Text $goalPlanText -Needle "swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt" -Label "Goal plan clean A4 scratch dedicated log"
Assert-Contains -Text $runCardText -Needle "RIBBON_ACCESSIBILITY_NOT_STABLE" -Label "Run card ribbon coordinate automation warning"
Assert-Contains -Text $runCardText -Needle "## 자동화 경계" -Label "Run card automation boundary section"
Assert-Contains -Text $runCardText -Needle "LSP가 자동 처리:" -Label "Run card LSP automation scope"
Assert-Contains -Text $runCardText -Needle "사람이 확인:" -Label "Run card human GMTITLE scope"
Assert-Contains -Text $runCardText -Needle "GMTITLE 창 선택까지 완전 자동으로 켜지 않는 이유" -Label "Run card no unsafe full automation reason"
Assert-Contains -Text $runCardText -Needle 'CAD가 `_pasteclip` 삽입 명령으로 해석할 수 있습니다' -Label "Run card Computer Use pasteclip warning"
Assert-Contains -Text $runCardText -Needle "GMTITLE 배치점 원칙" -Label "Run card GMTITLE placement principle"
Assert-Contains -Text $runCardText -Needle '`SWTITLECONVERTNEXT` 또는 수동 `SWTITLECONVERT`를 통해 GMTITLE 창을 열었을 때는 긴 좌표를 사람이 직접 치지 않습니다' -Label "Run card convert-next placement wording"
Assert-Contains -Text $runCardText -Needle '`SWTITLECONVERTNEXT`/`SWTITLECONVERT`가 GMTITLE 호출, 왼쪽 아래 배치점 자동 전송, 값 복사, 이전 원본 정리를 묶어서 처리합니다' -Label "Run card convert-next integrated flow wording"
Assert-Contains -Text $runCardText -Needle "예상 수동 GMTITLE 확인량" -Label "Run card manual selection forecast guidance"
Assert-Contains -Text $runCardText -Needle "긴 좌표를 사람이 직접 치지 않습니다" -Label "Run card no manual long coordinate guidance"
Assert-Contains -Text $runCardText -Needle "마우스 커서가 화면 중앙에 남아 보여도" -Label "Run card center-cursor guidance"
Assert-Contains -Text $runCardText -Needle 'Loaded version`이 현재 LSP 기대 버전과 다르면' -Label "Run card direct-probe version refresh guidance"
Assert-Contains -Text $runCardText -Needle "BATCH는 OPEN으로 최소 1장 성공한 뒤" -Label "Run card BATCH after OPEN guidance"
Assert-Contains -Text $runCardText -Needle "SWTITLECONVERTNEXT" -Label "Run card convert-next shortcut guidance"
Assert-Contains -Text $runCardText -Needle '`SWTITLECONVERTNEXT`를 쓴 경우에는 `YES`, `OPEN`, `BATCH`, `MANUAL`을 다시 입력하지 않습니다' -Label "Run card no extra convert-next response guidance"
Assert-Contains -Text $runCardText -Needle '| `NEXT_CREATE_FIRST_NATIVE_GMTITLE` | 아직 실제 native GMTITLE 기준 객체가 없음 | `SWTITLECONVERTNEXT` |' -Label "Run card first-native recommends convert-next"
Assert-Contains -Text $runCardText -Needle '| `NEXT_UPGRADE_A3_A4_NATIVE` | A2/A3/A4 복제/shared-link 쌍을 fresh native로 교체해야 함 | `SWTITLECONVERTNEXT` |' -Label "Run card A3A4 recommends convert-next"
Assert-Contains -Text $runCardText -Needle "docs/history" -Label "Run card history-doc warning"
Assert-Contains -Text $runCardText -Needle "docs/investigations" -Label "Run card investigations-doc warning"
Assert-Contains -Text $runCardText -Needle 'A2/A3/A4는 모두 `DR_A*_Outline + DR_titlea_3rd` 공통 GMTITLE 흐름으로 판단' -Label "Run card unified GMTITLE current standard"
Assert-Contains -Text $runCardText -Needle "## title-missing 판단" -Label "Run card title-missing section heading"
Assert-Contains -Text $runCardText -Needle "따라서 title-missing/frame-only 성공 조건은 제목블록을 만드는 것이 아닙니다." -Label "Run card generic title-missing success wording"
Assert-NotContains -Text $runCardText -Needle "## A4 판단" -Label "Run card stale A4 section heading"
Assert-NotContains -Text $runCardText -Needle "따라서 A4 성공 조건" -Label "Run card stale A4 success wording"
Assert-Contains -Text $runCardText -Needle 'CAD 명령줄에 `GMTITLE`, `TIT`, 일반 `OPEN`을 직접 입력해서 우회하지 않습니다' -Label "Run card raw GMTITLE/TIT/OPEN guard"
Assert-Contains -Text $runCardText -Needle "이 문서는 특정 DWG의 과거 상태를 `"최신`"으로 고정하지 않습니다" -Label "Run card no stale latest-state wording"
Assert-Contains -Text $runCardText -Needle '과거에 어떤 도면이 `NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION`이었더라도 지금 열린 도면에 그대로 적용하지 않습니다' -Label "Run card no stale title-missing prepare carry-over"
Assert-NotContains -Text $runCardText -Needle "2026-07-05 08:55 기준 최신 CAD 로그" -Label "Run card stale timestamp latest state"
Assert-NotContains -Text $runCardText -Needle "0000_A_DRP125 CP_ALL_260704_test.dwg" -Label "Run card stale 260704 workcopy path"
Assert-Contains -Text $goalPlanText -Needle "RIBBON_ACCESSIBILITY_NOT_STABLE" -Label "Goal plan ribbon accessibility finding"
Assert-Contains -Text $goalPlanText -Needle "특정 과거 로그를 `"최신 CAD 진행 상태`"로 고정하지 않는다" -Label "Goal plan no stale latest-state wording"
Assert-Contains -Text $goalPlanText -Needle "run_after_manual_gmtitle_step.ps1" -Label "Goal plan after-manual wrapper state lock"
Assert-Contains -Text $goalPlanText -Needle 'hidden verification suite: PASS 여부는 `run_goal_status.ps1`가 최신 `work\main56_verification_suite_last_run.txt`의 Generated/Result를 읽어 판단' -Label "Goal plan latest hidden-suite evidence guidance"
Assert-Contains -Text $goalPlanText -Needle "상태 코드:" -Label "Goal plan current direct-probe status block"
Assert-Contains -Text $goalPlanText -Needle "NEXT_CREATE_FIRST_NATIVE_GMTITLE" -Label "Goal plan current direct-probe first-native status"
Assert-Contains -Text $goalPlanText -Needle '`SWTITLECONVERTNEXT`를 사용한 경우에는 `YES`, `OPEN`, `BATCH`, `MANUAL`을 다시 입력하지 않는다' -Label "Goal plan no extra convert-next response guidance"
Assert-NotContains -Text $goalPlanText -Needle "frame-only A4가 제목블록 없이 도면틀만 남음" -Label "Goal plan stale frame-only A4 progress wording"
Assert-NotContains -Text $goalPlanText -Needle "| A4 frame-only |" -Label "Goal plan stale A4 frame-only table row"
Assert-NotContains -Text $goalPlanText -Needle "hidden verification suite 전체 통과" -Label "Goal plan stale hidden-suite unproven wording"
Assert-NotContains -Text $goalPlanText -Needle "2026-07-05 08:55 기준 최신 CAD next-step 로그" -Label "Goal plan stale timestamp latest state"
Assert-NotContains -Text $goalPlanText -Needle "0000_A_DRP125 CP_ALL_260704_test.dwg" -Label "Goal plan stale 260704 workcopy path"
Assert-Contains -Text $runCardText -Needle "최신 hidden suite PASS 여부와 Generated 시각은 아래 둘 중 하나로 확인합니다" -Label "Run card latest hidden suite status guidance"
Assert-Contains -Text $runCardText -Needle 'work\main56_verification_suite_last_run.txt`의 `Generated:`와 `Result:`' -Label "Run card latest hidden suite log guidance"
Assert-NotContains -Text $runCardText -Needle '2026-07-06 00:55 기준 `run_main45_verification_suite.ps1 -TimeoutSeconds 180`는 PASS입니다' -Label "Run card no fixed hidden-suite current timestamp"
Assert-Contains -Text $runCardText -Needle "All expected log markers were verified." -Label "Run card hidden suite verified markers"
Assert-Contains -Text $hiddenSuitePassHistoryText -Needle "===== GMTITLE main56 verification suite complete =====" -Label "Hidden suite pass history completion marker"
Assert-Contains -Text $hiddenSuitePassHistoryText -Needle "All expected log markers were verified." -Label "Hidden suite pass history verified markers"
Assert-Contains -Text $hiddenSuitePassHistoryText -Needle "2026-07-06 00:55 KST" -Label "Hidden suite pass history latest timestamp"
Assert-Contains -Text $hiddenSuitePassHistoryText -Needle "Generated: 2026-07-06 00:55:12 +09:00" -Label "Hidden suite pass history last-run timestamp"
Assert-Contains -Text $hiddenSuitePassHistoryText -Needle "GMTITLE selection config deep registry probe: PASS" -Label "Hidden suite pass history deep registry marker"
Assert-Contains -Text $hiddenSuitePassHistoryText -Needle "Recent File List" -Label "Hidden suite pass history recent-file distinction"
Assert-Contains -Text $hiddenSuitePassHistoryText -Needle "Result: PASS" -Label "Hidden suite pass history last-run pass marker"
Assert-Contains -Text $hiddenSuitePassHistoryText -Needle "FAILED_BEFORE_PASS" -Label "Hidden suite pass history failure-summary behavior"
Assert-Contains -Text $hiddenSuitePassHistoryText -Needle "status-after-status: NEXT_CREATE_FIRST_NATIVE_GMTITLE" -Label "Hidden suite pass history actual workcopy status"
Assert-Contains -Text $hiddenSuitePassHistoryText -Needle "next-bootstrap-frame: DR_A2_Outline" -Label "Hidden suite pass history next frame"
Assert-Contains -Text $hiddenSuitePassHistoryText -Needle "next-bootstrap-title: DR_titlea_3rd" -Label "Hidden suite pass history next title"
Assert-Contains -Text $commandsGuideText -Needle "docs/history" -Label "Commands guide history-doc warning"
Assert-Contains -Text $commandsGuideText -Needle "docs/investigations" -Label "Commands guide investigations-doc warning"
Assert-Contains -Text $commandsGuideText -Needle '`frame-only`는 A4 전용 정책이 아니라' -Label "Commands guide unified GMTITLE current standard"
Assert-Contains -Text $commandsGuideText -Needle "자동화 경계:" -Label "Commands guide automation boundary section"
Assert-Contains -Text $commandsGuideText -Needle "LSP가 자동 처리:" -Label "Commands guide LSP automation scope"
Assert-Contains -Text $commandsGuideText -Needle "사람이 확인:" -Label "Commands guide human GMTITLE scope"
Assert-Contains -Text $commandsGuideText -Needle "GMTITLE 창 선택까지 완전 자동으로 켜지 않는 이유" -Label "Commands guide no unsafe full automation reason"
Assert-Contains -Text $commandsGuideText -Needle 'CAD 명령줄에 `GMTITLE`, `TIT`, 일반 `OPEN`을 직접 입력하지 않습니다' -Label "Commands guide raw GMTITLE/TIT/OPEN guard"
Assert-Contains -Text $commandsGuideText -Needle 'OPEN` 응답은 CAD 일반 `OPEN` 명령이 아닙니다' -Label "Commands guide convert OPEN versus CAD OPEN guard"
Assert-Contains -Text $commandsGuideText -Needle "첫 native GMTITLE 생성: YES" -Label "Commands guide convert YES prompt"
Assert-Contains -Text $commandsGuideText -Needle "A2/A3/A4 native 교체 1장 처리: OPEN" -Label "Commands guide convert OPEN prompt"
Assert-Contains -Text $commandsGuideText -Needle "BATCH는 OPEN으로 최소 1장 성공한 뒤" -Label "Commands guide BATCH after OPEN guidance"
Assert-Contains -Text $commandsGuideText -Needle "NO_INSERTS가 반복됨: MANUAL" -Label "Commands guide convert MANUAL prompt"
Assert-Contains -Text $commandsGuideText -Needle "SWTITLECONVERTNEXT" -Label "Commands guide convert-next shortcut guidance"
Assert-Contains -Text $commandsGuideText -Needle '`SWTITLECONVERTNEXT`를 사용하는 경우에는 아래 응답을 직접 입력하지 않습니다' -Label "Commands guide no extra convert-next response guidance"
Assert-Contains -Text $commandsGuideText -Needle "SolidWorks DWG의 도면틀/표제란을 GstarCAD Mechanical GMTITLE 구조로 바꾸는 일반 작업은 아래 권장 4개 명령만 사용합니다." -Label "Commands guide recommended 4-command wording"
Assert-Contains -Text $commandsGuideText -Needle "SWTITLECONVERTNEXT    상태가 요구할 때만" -Label "Commands guide sequence recommends convert-next"
Assert-Contains -Text $commandsGuideText -Needle "수동으로 GMTITLE 창에서 한 장을 처리한 뒤에는 작업복사본을 저장하고 GstarCAD를 닫은 다음" -Label "Commands guide after-manual wrapper loop"
Assert-Contains -Text $commandsGuideText -Needle "run_after_manual_gmtitle_step.ps1" -Label "Commands guide after-manual wrapper command"
Assert-Contains -Text $commandsGuideText -Needle "run_after_manual_gmtitle_step.ps1 -Compact" -Label "Commands guide compact after-manual wrapper command"
Assert-Contains -Text $commandsGuideText -Needle "run_manual_gmtitle_session.ps1" -Label "Commands guide manual session wrapper command"
Assert-Contains -Text $commandsGuideText -Needle "저장된 작업복사본이 실제로 변환 가능한 상태인지 확인" -Label "Commands guide manual session initial card guard"
Assert-Contains -Text $commandsGuideText -Needle "run_manual_gmtitle_session.ps1 -PreflightOnly" -Label "Commands guide manual session preflight-only command"
Assert-Contains -Text $commandsGuideText -Needle "run_manual_gmtitle_session.ps1 -PreflightOnly -Compact" -Label "Commands guide manual session compact preflight command"
Assert-Contains -Text $runCardText -Needle "run_after_manual_gmtitle_step.ps1" -Label "Run card after-manual wrapper command"
Assert-Contains -Text $runCardText -Needle "run_after_manual_gmtitle_step.ps1 -Compact" -Label "Run card compact after-manual wrapper command"
Assert-Contains -Text $runCardText -Needle "work\swtitle_after_manual_gmtitle_step_last.txt" -Label "Run card after-manual wrapper log"
Assert-Contains -Text $runCardText -Needle "작업복사본을 저장하고 GstarCAD를 닫은 상태" -Label "Run card after-manual saved-and-closed guard"
Assert-Contains -Text $runCardText -Needle "run_manual_gmtitle_session.ps1" -Label "Run card manual session wrapper command"
Assert-Contains -Text $runCardText -Needle 'run_next_cad_action.ps1`를 자동 direct probe 갱신 없이 실행' -Label "Run card manual session initial next-action card"
Assert-Contains -Text $runCardText -Needle "SkipInitialNextActionCard" -Label "Run card manual session skip initial card guard"
Assert-Contains -Text $runCardText -Needle "PreflightOnly" -Label "Run card manual session preflight-only guidance"
Assert-Contains -Text $runCardText -Needle "run_manual_gmtitle_session.ps1 -PreflightOnly -Compact" -Label "Run card manual session compact preflight command"
Assert-Contains -Text $runCardText -Needle '`SWTITLECONVERTNEXT`를 대신 실행하거나 GMTITLE 창을 클릭하지 않습니다' -Label "Run card manual session no-convert/no-click guard"
Assert-Contains -Text $runCardText -Needle "SKIP_OPEN_NO_GSTARCAD" -Label "Run card manual session skip-open guard"
Assert-Contains -Text $cadChecklistText -Needle "첫 native GMTITLE 기준 객체 생성: YES" -Label "CAD checklist convert YES prompt"
Assert-Contains -Text $cadChecklistText -Needle "A2/A3/A4 native 교체 1장 처리: OPEN" -Label "CAD checklist convert OPEN prompt"
Assert-Contains -Text $cadChecklistText -Needle "BATCH는 OPEN으로 최소 1장 성공한 뒤" -Label "CAD checklist BATCH after OPEN guidance"
Assert-Contains -Text $cadChecklistText -Needle "SWTITLECONVERTNEXT" -Label "CAD checklist convert-next shortcut guidance"
Assert-Contains -Text $cadChecklistText -Needle '이 명령은 현재 상태에 맞춰 필요한 단계만 진행하고, `YES`/`OPEN` 같은 반복 응답만 자동 선택합니다.' -Label "CAD checklist convert-next scope guidance"
Assert-Contains -Text $cadChecklistText -Needle '`SWTITLECONVERTNEXT`를 사용하는 경우에는 `YES`, `OPEN`, `BATCH`, `MANUAL`을 다시 입력하지 않습니다' -Label "CAD checklist no extra convert-next response guidance"
Assert-Contains -Text $cadChecklistText -Needle "run_after_manual_gmtitle_step.ps1" -Label "CAD checklist after-manual wrapper command"
Assert-Contains -Text $cadChecklistText -Needle "run_manual_gmtitle_session.ps1" -Label "CAD checklist manual session wrapper command"
Assert-Contains -Text $cadChecklistText -Needle "visible CAD를 열기 전에 next-action 카드를 갱신" -Label "CAD checklist manual session initial card guard"
Assert-Contains -Text $cadChecklistText -Needle "run_manual_gmtitle_session.ps1 -PreflightOnly" -Label "CAD checklist manual session preflight-only command"
Assert-Contains -Text $cadChecklistText -Needle "run_manual_gmtitle_session.ps1 -PreflightOnly -Compact" -Label "CAD checklist manual session compact preflight command"
Assert-Contains -Text $cadChecklistText -Needle "title-missing/frame-only 처리 전 조건:" -Label "CAD checklist generic title-missing preconditions"
Assert-Contains -Text $cadChecklistText -Needle "title-missing/frame-only 성공 조건:" -Label "CAD checklist generic title-missing success conditions"
Assert-NotContains -Text $cadChecklistText -Needle "A4 처리 전 조건:" -Label "CAD checklist stale A4 preconditions"
Assert-NotContains -Text $cadChecklistText -Needle "A4 성공 조건:" -Label "CAD checklist stale A4 success conditions"
Assert-Contains -Text $nativeUpgradeGuideText -Needle 'SWTITLECONVERTNEXT는 같은 bbox에 기존 native GMTITLE 쌍이 있으면 새로 만들지 않고 그 쌍을 채택한다.' -Label "Native upgrade guide convert-next adoption wording"
Assert-Contains -Text $resumeGuideText -Needle "첫 native GMTITLE 생성: YES" -Label "Resume guide convert YES prompt"
Assert-Contains -Text $resumeGuideText -Needle "A2/A3/A4 native 교체 1장 처리: OPEN" -Label "Resume guide convert OPEN prompt"
Assert-Contains -Text $resumeGuideText -Needle "BATCH는 OPEN으로 최소 1장 성공한 뒤" -Label "Resume guide BATCH after OPEN guidance"
Assert-Contains -Text $resumeGuideText -Needle "NO_INSERTS가 반복됨: MANUAL" -Label "Resume guide convert MANUAL prompt"
Assert-Contains -Text $resumeGuideText -Needle "SWTITLECONVERTNEXT" -Label "Resume guide convert-next shortcut guidance"
Assert-Contains -Text $resumeGuideText -Needle "run_after_manual_gmtitle_step.ps1" -Label "Resume guide after-manual wrapper command"
Assert-Contains -Text $resumeGuideText -Needle "현재 작업 기준은 이 문서" -Label "Resume guide current-doc priority"
Assert-Contains -Text $resumeGuideText -Needle "docs/history" -Label "Resume guide history-doc warning"
Assert-Contains -Text $resumeGuideText -Needle "docs/investigations" -Label "Resume guide investigations-doc warning"
Assert-Contains -Text $resumeGuideText -Needle 'CAD 명령줄에 `GMTITLE`, `TIT`, 일반 `OPEN`을 직접 입력해서 우회하지 않습니다' -Label "Resume guide raw GMTITLE/TIT/OPEN guard"

$suiteStepNumbers = @(
  [regex]::Matches($suiteText, "Write-Output\s+.===== ([0-9]+)\. ") |
    ForEach-Object { [int]$_.Groups[1].Value }
)
$expectedSuiteStepNumbers = 1..18
if (($suiteStepNumbers.Count -eq $expectedSuiteStepNumbers.Count) -and (@(Compare-Object $suiteStepNumbers $expectedSuiteStepNumbers).Count -eq 0)) {
  Write-Output ("Suite step numbers: {0}" -f ($suiteStepNumbers -join ", "))
} else {
  Add-Failure ("Suite step numbers mismatch: expected {0}, got {1}" -f (($expectedSuiteStepNumbers -join ", ")), (($suiteStepNumbers -join ", ")))
}

Assert-Contains -Text $readmeText -Needle "18. GMTITLE selection config probe" -Label "README suite step list"
Assert-Contains -Text $readmeText -Needle "deep-registry" -Label "README suite selection config deep-registry wording"

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
