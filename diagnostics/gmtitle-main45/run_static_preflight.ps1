param(
  [string]$ExpectedGmtitleVersion = "260705-status-convert-next-guidance",

  [string]$ExpectedLoaderVersion = "260705-4step-gmtitle-a4-outline-preflight"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$mainLspPath = Join-Path $repoRoot "src\tools\gmtitle\swcad_title_scale.lsp"
$loaderPath = Join-Path $repoRoot "swcad_load.lsp"
$suitePath = Join-Path $PSScriptRoot "run_main45_verification_suite.ps1"
$readmePath = Join-Path $PSScriptRoot "README.md"
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
$nextCadActionRunnerPath = Join-Path $PSScriptRoot "run_next_cad_action.ps1"
$nextCadActionCardProbePath = Join-Path $PSScriptRoot "run_next_cad_action_card_probe.ps1"
$finalCompletionGatePath = Join-Path $PSScriptRoot "run_final_completion_gate.ps1"
$selectionConfigProbePath = Join-Path $PSScriptRoot "run_gmtitle_selection_config_probe.ps1"
$goalStatusPath = Join-Path $PSScriptRoot "run_goal_status.ps1"
$computerUseHistoryPath = Join-Path $repoRoot "docs\history\gmtitle-computer-use-visible-cad-activation-failure-2026-07-05.md"
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
$nextCadActionRunnerText = Read-Text $nextCadActionRunnerPath
$nextCadActionCardProbeText = Read-Text $nextCadActionCardProbePath
$finalCompletionGateText = Read-Text $finalCompletionGatePath
$selectionConfigProbeText = Read-Text $selectionConfigProbePath
$goalStatusText = Read-Text $goalStatusPath
$computerUseHistoryText = Read-Text $computerUseHistoryPath

Write-Output "===== GMTITLE static preflight ====="
Write-Output ("Repo root: {0}" -f $repoRoot)

Test-LispBalance -Text $mainText -Label "swcad_title_scale.lsp"
Test-LispBalance -Text $loaderText -Label "swcad_load.lsp"
Test-LispBalance -Text $a4NormProbeText -Label "a4_outline_normalization_probe.lsp"
Test-LispBalance -Text $a4OutlineConvertProbeText -Label "a4_outline_convert_probe.lsp"
Test-LispBalance -Text $actualDirectStatusProbeText -Label "actual_workcopy_status_probe.lsp"

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

Assert-Contains -Text $mainText -Needle "swcad-title-a4-frame-only-outline-raw-a4-warning" -Label "A4 strict raw-bbox function"
Assert-Contains -Text $mainText -Needle "WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE" -Label "A4 unsafe definition status"
Assert-Contains -Text $mainText -Needle "ready-native-outside-markers" -Label "A4 native outside marker ready status"
Assert-Contains -Text $mainText -Needle "ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE" -Label "Interactive GMTITLE script guard"
Assert-Contains -Text $mainText -Needle "ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE" -Label "A3/A4 batch script guard"
Assert-Contains -Text $mainText -Needle "c:SWTITLECONVERTNEXT" -Label "SWTITLECONVERTNEXT public command"
Assert-Contains -Text $mainText -Needle "*swcad-title-convert-next-mode*" -Label "SWTITLECONVERTNEXT auto-next mode flag"
Assert-Contains -Text $mainText -Needle "SWTITLECONVERTNEXT auto response" -Label "SWTITLECONVERTNEXT auto response log"
Assert-Contains -Text $mainText -Needle "권장 흐름: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERTNEXT, SWTITLEVERIFY" -Label "GMTITLE load convert-next workflow guidance"
Assert-Contains -Text $mainText -Needle "수동 응답을 직접 고를 때만 SWTITLECONVERT를 사용하세요" -Label "GMTITLE load manual convert fallback guidance"
Assert-Contains -Text $mainText -Needle '(swcad-title-auto-next-answer "OPEN"' -Label "SWTITLECONVERTNEXT native one-sheet default"
Assert-Contains -Text $mainText -Needle "다음 명령: SWTITLECONVERTNEXT" -Label "SWTITLESTATUS recommends convert-next command"
Assert-Contains -Text $mainText -Needle "다음: SWTITLECONVERTNEXT를 실행하세요" -Label "SWTITLESTATUS next action recommends convert-next"
Assert-NotContains -Text $mainText -Needle "다음: SWTITLECONVERT를 실행하세요." -Label "Stale direct convert next-action wording"
Assert-NotContains -Text $mainText -Needle "일반 흐름은 SWTITLECONVERT를 사용하세요." -Label "Stale direct convert general-flow wording"
$a3a4NextStart = $mainText.IndexOf("(defun swcad-title-upgrade-native-a3a4-next")
$a3a4AutoOpen = if ($a3a4NextStart -ge 0) { $mainText.IndexOf('(swcad-title-auto-next-answer "OPEN"', $a3a4NextStart) } else { -1 }
$a3a4Prompt = if ($a3a4NextStart -ge 0) { $mainText.IndexOf("(getstring", $a3a4NextStart) } else { -1 }
if (($a3a4NextStart -ge 0) -and ($a3a4AutoOpen -gt $a3a4NextStart) -and ($a3a4Prompt -gt $a3a4AutoOpen)) {
  Write-Output "SWTITLECONVERTNEXT A3/A4 OPEN before prompt: found"
} else {
  Add-Failure "SWTITLECONVERTNEXT A3/A4 OPEN auto response must be checked before getstring prompt"
}
Assert-Contains -Text $mainText -Needle "DR_titlea_3rd/Frame positioning ON/Object move OFF" -Label "SWTITLECONVERTNEXT visual GMTITLE confirmation guard"
Assert-Contains -Text $suiteText -Needle "A4 outline native outside marker prepare probe" -Label "Suite A4 native outside marker prepare step"
Assert-Contains -Text $suiteText -Needle "After definition status: ready-native-outside-markers" -Label "Suite A4 native outside marker prepare expectation"
Assert-Contains -Text $suiteText -Needle "A4 outline frame-only convert probe" -Label "Suite A4 outline convert step"
Assert-Contains -Text $suiteText -Needle "FINALIZED_A4_FRAME_ONLY_OUTLINE_TRANSFER" -Label "Suite A4 outline convert expectation"
Assert-Contains -Text $suiteText -Needle "After target title count: 0" -Label "Suite A4 outline no-title expectation"
Assert-Contains -Text $suiteText -Needle "Native GMTITLE A4 pair evidence: no" -Label "Suite A4 native-pair gap expectation"
Assert-Contains -Text $suiteText -Needle "WaitForGstarCADClose" -Label "Suite GstarCAD-close wait option"
Assert-Contains -Text $suiteText -Needle "Assert-NoExistingGstarCAD" -Label "Suite open-GstarCAD preflight"
Assert-Contains -Text $suiteText -Needle "run_hidden_script_smoke_probe.ps1" -Label "Suite hidden script smoke preflight"
Assert-Contains -Text $suiteText -Needle "ProbeWindowStyle = ""Minimized""" -Label "Suite minimized probe window default"
Assert-Contains -Text $suiteText -Needle "Next CAD action card probe (no CAD)" -Label "Suite next-action card no-CAD preflight"
Assert-Contains -Text $suiteText -Needle "run_next_cad_action_card_probe.ps1" -Label "Suite next-action card probe runner"
Assert-Contains -Text $suiteText -Needle "Structure next action: SWTITLECONVERTNEXT" -Label "Suite structure next action recommends convert-next"
Assert-NotContains -Text $suiteText -Needle "Structure next action: SWTITLECONVERT`"," -Label "Suite stale structure next action"
Assert-Contains -Text $readmeText -Needle "-WaitForGstarCADClose" -Label "README waiting-mode guidance"
Assert-Contains -Text $readmeText -Needle "GstarCAD /b Script Smoke Probe" -Label "README GstarCAD /b script smoke probe guidance"
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
Assert-Contains -Text $a4OutlineConvertProbeText -Needle "After target title count" -Label "A4 outline convert no-title log"
Assert-Contains -Text $a4OutlineConvertProbeText -Needle "FINALIZED_A4_FRAME_ONLY_OUTLINE_TRANSFER" -Label "A4 outline convert finalized status"
Assert-Contains -Text $a4OutlineConvertRunnerText -Needle "run_readonly_probe.ps1" -Label "A4 outline convert hidden runner"
Assert-Contains -Text $actualDirectStatusRunnerText -Needle "run_readonly_probe.ps1" -Label "Actual direct work-copy hidden runner"
Assert-Contains -Text $actualDirectStatusRunnerText -Needle "TimeoutSeconds = 180" -Label "Actual direct work-copy longer timeout"
Assert-Contains -Text $actualDirectStatusRunnerText -Needle "SWCAD_ACTUAL_WORKCOPY_LOG_SUFFIX" -Label "Actual direct work-copy suffix override"
Assert-Contains -Text $actualDirectStatusRunnerText -Needle "swtitle_actual_workcopy_direct_status_260705.txt" -Label "Actual direct work-copy log path"
Assert-Contains -Text $nextCadActionRunnerText -Needle "READY_FOR_FIRST_NATIVE_GMTITLE" -Label "Next CAD action first-native readiness"
Assert-Contains -Text $nextCadActionRunnerText -Needle "0xEF" -Label "Next CAD action UTF-8 BOM log guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "TrimStart([char]0xFEFF)" -Label "Next CAD action BOM character trim"
Assert-Contains -Text $nextCadActionRunnerText -Needle "작업복사본이 direct probe 로그보다 최신입니다" -Label "Next CAD action stale direct-probe guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Direct probe 최신 상태" -Label "Next CAD action direct-probe freshness output"
Assert-Contains -Text $nextCadActionRunnerText -Needle "AutoRefreshDirectProbe" -Label "Next CAD action optional direct-probe auto refresh"
Assert-Contains -Text $nextCadActionRunnerText -Needle "AutoRefreshTimeoutSeconds = 180" -Label "Next CAD action direct-probe auto refresh timeout"
Assert-Contains -Text $nextCadActionRunnerText -Needle "AUTO_REFRESH_DIRECT_PROBE_FAILED" -Label "Next CAD action auto refresh failure guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "예상 수동 GMTITLE 확인량" -Label "Next CAD action manual selection forecast"
Assert-Contains -Text $nextCadActionRunnerText -Needle "저장된 시트 수량" -Label "Next CAD action expected sheet count forecast"
Assert-Contains -Text $nextCadActionRunnerText -Needle "A4 frame-only {0}장은 제목블록 생성 대상이 아닙니다" -Label "Next CAD action A4 frame-only no-title forecast"
Assert-Contains -Text $actualDirectStatusProbeText -Needle "a3a4-native-upgrade-candidate-count" -Label "Actual workcopy probe native-upgrade candidate count"
Assert-Contains -Text $actualDirectStatusProbeText -Needle "target-gmtitle-pair-count" -Label "Actual workcopy probe target pair count"
Assert-Contains -Text $actualDirectStatusProbeText -Needle "native-like-target-pair-count" -Label "Actual workcopy probe native-like pair count"
Assert-Contains -Text $actualDirectStatusProbeText -Needle "duplicate-target-pair-count" -Label "Actual workcopy probe duplicate target pair count"
Assert-Contains -Text $nextCadActionRunnerText -Needle "A3/A4 native 교체 후보 수" -Label "Next CAD action native-upgrade candidate output"
Assert-Contains -Text $nextCadActionRunnerText -Needle "현재 GMTITLE 쌍: 전체" -Label "Next CAD action target-pair forecast"
Assert-Contains -Text $nextCadActionRunnerText -Needle "OPEN 1회 성공 뒤 direct probe를 갱신해서 후보 수가 줄었는지 먼저 확인하세요." -Label "Next CAD action native OPEN refresh guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Codex sandbox 기본 경로 감지" -Label "Next CAD action Codex sandbox default-path correction"
Assert-Contains -Text $nextCadActionRunnerText -Needle "direct probe의 실제 DWG를 대상 작업복사본으로 사용" -Label "Next CAD action real direct-probe DWG correction"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Get-RepoRootFromWorkCopyPath" -Label "Next CAD action host repo root derivation"
Assert-Contains -Text $nextCadActionRunnerText -Needle "실제 CAD용 저장소 폴더" -Label "Next CAD action host CAD repo output"
Assert-Contains -Text $nextCadActionRunnerText -Needle 'Join-Path $displayRepoRoot "swcad_load.lsp"' -Label "Next CAD action APPLOAD display root"
Assert-Contains -Text $nextCadActionRunnerText -Needle "run_actual_workcopy_direct_status_probe.ps1" -Label "Next CAD action direct-probe runner guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "RUN_PREPARE_FIRST" -Label "Next CAD action prepare-first guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "RUN_NATIVE_REPLACEMENT" -Label "Next CAD action native replacement guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "REVIEW_STRUCTURE_BEFORE_CONVERT" -Label "Next CAD action structure review guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "CREATE_MISSING_NATIVE_GMTITLE_SIZE" -Label "Next CAD action missing native exemplar guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "VERIFY_NOT_FINAL" -Label "Next CAD action verify-not-final guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "수동 GstarCAD 단계" -Label "Next CAD action Korean manual visible CAD wording"
Assert-Contains -Text $nextCadActionRunnerText -Needle "화면 캡처는 가능하지만 활성화/클릭/입력은 안정적이지 않습니다" -Label "Next CAD action Korean Computer Use limitation wording"
Assert-Contains -Text $computerUseHistoryText -Needle "failed to activate captured window" -Label "Computer Use activation failure history"
Assert-Contains -Text $computerUseHistoryText -Needle "Do not repeat the same visible-CAD Computer Use click/type attempt as a default path" -Label "Computer Use no-repeat guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "용지/도면틀:" -Label "Next CAD action Korean dialog paper guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERTNEXT  (권장: YES/OPEN 반복 응답 자동 선택)" -Label "Next CAD action convert-next shortcut guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "또는 수동 응답을 직접 고르려면: SWTITLECONVERT" -Label "Next CAD action manual convert fallback guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERTNEXT는 같은 흐름에서 YES/OPEN 같은 반복 응답만 자동 선택합니다" -Label "Next CAD action convert-next scope guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "같은 SWTITLECONVERT를 반복하지 말고" -Label "Next CAD action no-repeat convert warning"
Assert-Contains -Text $nextCadActionRunnerText -Needle "Object move: OFF" -Label "Next CAD action Object move guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "GMTITLE, TIT, 일반 OPEN을 직접 입력하지 마세요" -Label "Next CAD action raw GMTITLE/TIT/OPEN guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERT 안에서 물어보는 YES/OPEN/BATCH/MANUAL 응답과 CAD 일반 OPEN 명령은 다릅니다" -Label "Next CAD action convert prompt versus CAD OPEN guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "긴 좌표를 사람이 직접 치지 마세요" -Label "Next CAD action lower-left auto placement guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "커서가 화면 중앙에 남아 보여도" -Label "Next CAD action center-cursor placement guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "REFRESH_DIRECT_PROBE_FIRST" -Label "Next CAD action direct-probe refresh guard"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERT/SWTITLECONVERTNEXT에서 나올 수 있는 입력" -Label "Next CAD action convert prompt guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "SWTITLECONVERTNEXT는 아래 반복 응답 중 현재 상태의 안전한 다음 값만 자동 선택합니다" -Label "Next CAD action convert-next auto response guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "YES: 첫 native GMTITLE 1장을 만들고 마무리합니다." -Label "Next CAD action first-native YES guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "OPEN: 다음 A3/A4 후보 1장만 fresh native GMTITLE로 교체합니다." -Label "Next CAD action native OPEN guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "BATCH: OPEN으로 최소 1장 성공한 뒤" -Label "Next CAD action native BATCH after OPEN guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "MANUAL: OPEN이 새 GMTITLE을 못 잡거나 NO_INSERTS가 반복될 때만 사용합니다." -Label "Next CAD action native MANUAL guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "실제 DR_titlea_3rd 제목블록이 있는 대표 A2/A3 용지만 더블클릭하세요." -Label "Next CAD action final title-only double-click guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "표제란 없는 A4 frame-only 시트는 더블클릭할 제목블록이 없으므로" -Label "Next CAD action final A4 frame-only guidance"
Assert-Contains -Text $nextCadActionRunnerText -Needle "DR_A*_Outline 도면틀을 더블클릭하면 GMPOWEREDIT/REFEDIT가 열릴 수 있으니" -Label "Next CAD action final frame double-click guard"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "Next CAD action card probe result: PASS" -Label "Next CAD action card probe pass marker"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "NEXT_CREATE_FIRST_NATIVE_GMTITLE" -Label "Next CAD action card probe first-native case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION" -Label "Next CAD action card probe prepare case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "NEXT_UPGRADE_A3_A4_NATIVE" -Label "Next CAD action card probe native-upgrade case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "NEXT_REVIEW_TARGET_FRAME_GEOMETRY" -Label "Next CAD action card probe structure-review case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS" -Label "Next CAD action card probe abort-warning case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "SWTITLEVERIFY_FINAL_OK" -Label "Next CAD action card probe final-ok case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "MissingLog" -Label "Next CAD action card probe missing-log case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "MakeStale" -Label "Next CAD action card probe stale-log case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "Invoke-SandboxCorrectionCase" -Label "Next CAD action card probe sandbox-correction case"
Assert-Contains -Text $nextCadActionCardProbeText -Needle "Assert-NotContains" -Label "Next CAD action card probe sandbox APPLOAD negative check"
Assert-Contains -Text $finalCompletionGateText -Needle "Final completion gate result: FAIL" -Label "Final completion gate actionable failure summary"
Assert-Contains -Text $finalCompletionGateText -Needle "Current status-after-status" -Label "Final completion gate status-after-status summary"
Assert-Contains -Text $finalCompletionGateText -Needle "Current status-after-verify" -Label "Final completion gate status-after-verify summary"
Assert-Contains -Text $finalCompletionGateText -Needle "run_next_cad_action.ps1" -Label "Final completion gate next action guidance"
Assert-Contains -Text $finalCompletionGateText -Needle "representative A2/A3 title-block double-click checks" -Label "Final completion gate A2/A3 double-click reminder"
Assert-Contains -Text $finalCompletionGateText -Needle "A4 frame-only sheets have no DR_titlea_3rd title block" -Label "Final completion gate A4 frame-only reminder"
Assert-Contains -Text $finalCompletionGateText -Needle "Final automated completion evidence passed." -Label "Final completion gate automated-pass wording"
Assert-Contains -Text $readmeText -Needle "representative A2/A3" -Label "README final completion A2/A3 title guidance"
Assert-Contains -Text $readmeText -Needle "A4 frame-only sheets do not have" -Label "README final completion A4 frame-only guidance"
Assert-Contains -Text $selectionConfigProbeText -Needle "GMTITLE_SELECTION_CONFIG_NOT_FOUND" -Label "Selection config probe negative result"
Assert-Contains -Text $selectionConfigProbeText -Needle "Direct GMTITLE may still reuse an internal/current command state" -Label "Selection config probe direct-GMTITLE warning"
Assert-Contains -Text $selectionConfigProbeText -Needle "ribbon/menu IMTITLE macro" -Label "Selection config probe IMTITLE macro note"
Assert-Contains -Text $selectionConfigProbeText -Needle "Command surface language note" -Label "Selection config probe command-surface language note"
Assert-Contains -Text $selectionConfigProbeText -Needle "AppData text marker scan note" -Label "Selection config probe AppData advisory scan note"
Assert-Contains -Text $readmeText -Needle "screenshot-coordinate ribbon clicks are not accepted as automation evidence" -Label "README ribbon coordinate automation warning"
Assert-Contains -Text $readmeText -Needle "AppData text marker scan is advisory" -Label "README AppData advisory scan guidance"
Assert-Contains -Text $goalStatusText -Needle "Write-NativeFrameProgressSummary" -Label "Goal status native-frame progress summary"
Assert-Contains -Text $goalStatusText -Needle "A4 normalization decision" -Label "Goal status A4 normalization decision guidance"
Assert-Contains -Text $goalStatusText -Needle "superseded by the official native outside marker policy" -Label "Goal status A4 superseded normalization guidance"
Assert-Contains -Text $goalStatusText -Needle "official native outside markers are tolerated when effective A4 geometry and raw-selection checks pass" -Label "Goal status A4 adopted outside marker policy"
Assert-Contains -Text $goalStatusText -Needle "A4 investigation continuation" -Label "Goal status A4 nested probe continuation guidance"
Assert-Contains -Text $goalStatusText -Needle "A4 normalization candidate review" -Label "Goal status A4 safe-candidate review guidance"
Assert-Contains -Text $goalStatusText -Needle "A4 native comparison investigation" -Label "Goal status A4 unsafe-nested fallback guidance"
Assert-Contains -Text $goalStatusText -Needle "scratch DWG with one real native A4 GMTITLE" -Label "Goal status A4 scratch-native comparison guidance"
Assert-Contains -Text $goalStatusText -Needle "production A4 frame-only must still not receive a new title block" -Label "Goal status A4 no-production-title guidance"
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
Assert-Contains -Text $goalStatusText -Needle "A4 native outside-marker decision" -Label "Goal status A4 outside marker decision guidance"
Assert-Contains -Text $goalStatusText -Needle "official native outside markers" -Label "Goal status A4 official marker guidance"
Assert-Contains -Text $goalStatusText -Needle "다음 작업:" -Label "Goal status Korean next-action heading"
Assert-Contains -Text $goalStatusText -Needle "A4 native 바깥 마커 허용 정책과 frame-only 변환 경로는 검증됨" -Label "Goal status Korean A4 verified guidance"
Assert-Contains -Text $goalStatusText -Needle "다음 실제 작업복사본 단계" -Label "Goal status Korean real work-copy step guidance"
Assert-Contains -Text $goalStatusText -Needle "짧은 다음 작업 카드" -Label "Goal status short next-action card command"
Assert-Contains -Text $goalStatusText -Needle "run_next_cad_action.ps1" -Label "Goal status next-action card script command"
Assert-Contains -Text $goalStatusText -Needle "-AutoRefreshDirectProbe" -Label "Goal status next-action auto-refresh hint"
Assert-Contains -Text $goalStatusText -Needle "목표 상태: 실제 작업복사본이 SWTITLEVERIFY_FINAL_OK에 도달" -Label "Goal status Korean completion reminder"
Assert-Contains -Text $readmeText -Needle "A4 clean scratch evidence" -Label "README clean A4 scratch evidence"
Assert-Contains -Text $readmeText -Needle "Actual Work-Copy Direct Status Probe" -Label "README direct actual work-copy probe guidance"
Assert-Contains -Text $readmeText -Needle "default timeout is 180 seconds" -Label "README direct actual work-copy timeout guidance"
Assert-Contains -Text $readmeText -Needle "run_next_cad_action.ps1" -Label "README next CAD action guidance"
Assert-Contains -Text $readmeText -Needle "A4_NATIVE_EXEMPLAR_READY_WITH_NATIVE_OUTSIDE_MARKERS" -Label "README clean A4 outside marker result"
Assert-Contains -Text $readmeText -Needle "swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt" -Label "README clean A4 scratch dedicated log"
Assert-Contains -Text $goalStatusText -Needle "run_gmtitle_selection_config_probe.ps1" -Label "Goal status selection config probe guidance"
Assert-Contains -Text $goalStatusText -Needle "Direct actual work-copy probe" -Label "Goal status direct actual work-copy probe summary"
Assert-Contains -Text $goalStatusText -Needle "GstarCAD /b script smoke probe" -Label "Goal status GstarCAD /b script smoke summary"
Assert-Contains -Text $goalStatusText -Needle "WindowStyle=Minimized" -Label "Goal status minimized smoke probe guidance"

$runCardText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-current-run-card.md")
$goalPlanText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-goal-mode-plan.md")
$commandsGuideText = Read-Text (Join-Path $repoRoot "docs\guide\commands.md")
$cadChecklistText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-cad-conversion-checklist.md")
$nativeUpgradeGuideText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-native-frame-upgrade.md")
$resumeGuideText = Read-Text (Join-Path $repoRoot "docs\guide\gmtitle-resume-on-another-computer.md")
Assert-Contains -Text $runCardText -Needle "scratch_native_a4_clean_260705.dwg" -Label "Run card clean A4 scratch evidence"
Assert-Contains -Text $runCardText -Needle "기본 제한 시간을 180초" -Label "Run card direct probe timeout guidance"
Assert-Contains -Text $goalPlanText -Needle "2026-07-05 clean scratch CAD" -Label "Goal plan clean A4 scratch evidence"
Assert-Contains -Text $runCardText -Needle "A4_NATIVE_EXEMPLAR_READY_WITH_NATIVE_OUTSIDE_MARKERS" -Label "Run card clean A4 outside marker result"
Assert-Contains -Text $goalPlanText -Needle "official native outside marker" -Label "Goal plan A4 official marker decision"
Assert-Contains -Text $runCardText -Needle "swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt" -Label "Run card clean A4 scratch dedicated log"
Assert-Contains -Text $goalPlanText -Needle "swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt" -Label "Goal plan clean A4 scratch dedicated log"
Assert-Contains -Text $runCardText -Needle "RIBBON_ACCESSIBILITY_NOT_STABLE" -Label "Run card ribbon coordinate automation warning"
Assert-Contains -Text $runCardText -Needle "GMTITLE 배치점 원칙" -Label "Run card GMTITLE placement principle"
Assert-Contains -Text $runCardText -Needle '`SWTITLECONVERTNEXT` 또는 수동 `SWTITLECONVERT`를 통해 GMTITLE 창을 열었을 때는 긴 좌표를 사람이 직접 치지 않습니다' -Label "Run card convert-next placement wording"
Assert-Contains -Text $runCardText -Needle '`SWTITLECONVERTNEXT`/`SWTITLECONVERT`가 GMTITLE 호출, 왼쪽 아래 배치점 자동 전송, 값 복사, 이전 원본 정리를 묶어서 처리합니다' -Label "Run card convert-next integrated flow wording"
Assert-Contains -Text $runCardText -Needle "예상 수동 GMTITLE 확인량" -Label "Run card manual selection forecast guidance"
Assert-Contains -Text $runCardText -Needle "긴 좌표를 사람이 직접 치지 않습니다" -Label "Run card no manual long coordinate guidance"
Assert-Contains -Text $runCardText -Needle "마우스 커서가 화면 중앙에 남아 보여도" -Label "Run card center-cursor guidance"
Assert-Contains -Text $runCardText -Needle "BATCH는 OPEN으로 최소 1장 성공한 뒤" -Label "Run card BATCH after OPEN guidance"
Assert-Contains -Text $runCardText -Needle "SWTITLECONVERTNEXT" -Label "Run card convert-next shortcut guidance"
Assert-Contains -Text $runCardText -Needle '| `NEXT_CREATE_FIRST_NATIVE_GMTITLE` | 아직 실제 native GMTITLE 기준 객체가 없음 | `SWTITLECONVERTNEXT` |' -Label "Run card first-native recommends convert-next"
Assert-Contains -Text $runCardText -Needle '| `NEXT_UPGRADE_A3_A4_NATIVE` | A3/A4 복제/shared-link 쌍을 fresh native로 교체해야 함 | `SWTITLECONVERTNEXT` |' -Label "Run card A3A4 recommends convert-next"
Assert-Contains -Text $runCardText -Needle "docs/history" -Label "Run card history-doc warning"
Assert-Contains -Text $runCardText -Needle "docs/investigations" -Label "Run card investigations-doc warning"
Assert-Contains -Text $runCardText -Needle '표제란 없는 A4 frame-only는 `DR_A4_Outline` 수량과 형상만 `SWTITLEVERIFY`로 검증합니다' -Label "Run card A4 frame-only current standard"
Assert-Contains -Text $runCardText -Needle 'CAD 명령줄에 `GMTITLE`, `TIT`, 일반 `OPEN`을 직접 입력해서 우회하지 않습니다' -Label "Run card raw GMTITLE/TIT/OPEN guard"
Assert-Contains -Text $goalPlanText -Needle "RIBBON_ACCESSIBILITY_NOT_STABLE" -Label "Goal plan ribbon accessibility finding"
Assert-Contains -Text $commandsGuideText -Needle "docs/history" -Label "Commands guide history-doc warning"
Assert-Contains -Text $commandsGuideText -Needle "docs/investigations" -Label "Commands guide investigations-doc warning"
Assert-Contains -Text $commandsGuideText -Needle "A4 frame-only는 원본에 표제란이 없는 시트입니다" -Label "Commands guide A4 frame-only current standard"
Assert-Contains -Text $commandsGuideText -Needle 'CAD 명령줄에 `GMTITLE`, `TIT`, 일반 `OPEN`을 직접 입력하지 않습니다' -Label "Commands guide raw GMTITLE/TIT/OPEN guard"
Assert-Contains -Text $commandsGuideText -Needle 'OPEN` 응답은 CAD 일반 `OPEN` 명령이 아닙니다' -Label "Commands guide convert OPEN versus CAD OPEN guard"
Assert-Contains -Text $commandsGuideText -Needle "첫 native GMTITLE 생성: YES" -Label "Commands guide convert YES prompt"
Assert-Contains -Text $commandsGuideText -Needle "A3/A4 native 교체 1장 처리: OPEN" -Label "Commands guide convert OPEN prompt"
Assert-Contains -Text $commandsGuideText -Needle "BATCH는 OPEN으로 최소 1장 성공한 뒤" -Label "Commands guide BATCH after OPEN guidance"
Assert-Contains -Text $commandsGuideText -Needle "NO_INSERTS가 반복됨: MANUAL" -Label "Commands guide convert MANUAL prompt"
Assert-Contains -Text $commandsGuideText -Needle "SWTITLECONVERTNEXT" -Label "Commands guide convert-next shortcut guidance"
Assert-Contains -Text $commandsGuideText -Needle "SolidWorks DWG의 도면틀/표제란을 GstarCAD Mechanical GMTITLE 구조로 바꾸는 일반 작업은 아래 권장 4개 명령만 사용합니다." -Label "Commands guide recommended 4-command wording"
Assert-Contains -Text $commandsGuideText -Needle "SWTITLECONVERTNEXT    상태가 요구할 때만" -Label "Commands guide sequence recommends convert-next"
Assert-Contains -Text $cadChecklistText -Needle "첫 native GMTITLE 기준 객체 생성: YES" -Label "CAD checklist convert YES prompt"
Assert-Contains -Text $cadChecklistText -Needle "A3/A4 native 교체 1장 처리: OPEN" -Label "CAD checklist convert OPEN prompt"
Assert-Contains -Text $cadChecklistText -Needle "BATCH는 OPEN으로 최소 1장 성공한 뒤" -Label "CAD checklist BATCH after OPEN guidance"
Assert-Contains -Text $cadChecklistText -Needle "SWTITLECONVERTNEXT" -Label "CAD checklist convert-next shortcut guidance"
Assert-Contains -Text $cadChecklistText -Needle '이 명령은 현재 상태에 맞춰 필요한 단계만 진행하고, `YES`/`OPEN` 같은 반복 응답만 자동 선택합니다.' -Label "CAD checklist convert-next scope guidance"
Assert-Contains -Text $nativeUpgradeGuideText -Needle 'SWTITLECONVERTNEXT는 같은 bbox에 기존 native GMTITLE 쌍이 있으면 새로 만들지 않고 그 쌍을 채택한다.' -Label "Native upgrade guide convert-next adoption wording"
Assert-Contains -Text $resumeGuideText -Needle "첫 native GMTITLE 생성: YES" -Label "Resume guide convert YES prompt"
Assert-Contains -Text $resumeGuideText -Needle "A3/A4 native 교체 1장 처리: OPEN" -Label "Resume guide convert OPEN prompt"
Assert-Contains -Text $resumeGuideText -Needle "BATCH는 OPEN으로 최소 1장 성공한 뒤" -Label "Resume guide BATCH after OPEN guidance"
Assert-Contains -Text $resumeGuideText -Needle "NO_INSERTS가 반복됨: MANUAL" -Label "Resume guide convert MANUAL prompt"
Assert-Contains -Text $resumeGuideText -Needle "SWTITLECONVERTNEXT" -Label "Resume guide convert-next shortcut guidance"
Assert-Contains -Text $resumeGuideText -Needle "현재 작업 기준은 이 문서" -Label "Resume guide current-doc priority"
Assert-Contains -Text $resumeGuideText -Needle "docs/history" -Label "Resume guide history-doc warning"
Assert-Contains -Text $resumeGuideText -Needle "docs/investigations" -Label "Resume guide investigations-doc warning"
Assert-Contains -Text $resumeGuideText -Needle 'CAD 명령줄에 `GMTITLE`, `TIT`, 일반 `OPEN`을 직접 입력해서 우회하지 않습니다' -Label "Resume guide raw GMTITLE/TIT/OPEN guard"

$suiteStepNumbers = @(
  [regex]::Matches($suiteText, "Write-Output\s+.===== ([0-9]+)\. ") |
    ForEach-Object { [int]$_.Groups[1].Value }
)
$expectedSuiteStepNumbers = 1..17
if (($suiteStepNumbers.Count -eq $expectedSuiteStepNumbers.Count) -and (@(Compare-Object $suiteStepNumbers $expectedSuiteStepNumbers).Count -eq 0)) {
  Write-Output ("Suite step numbers: {0}" -f ($suiteStepNumbers -join ", "))
} else {
  Add-Failure ("Suite step numbers mismatch: expected {0}, got {1}" -f (($expectedSuiteStepNumbers -join ", ")), (($suiteStepNumbers -join ", ")))
}

Assert-Contains -Text $readmeText -Needle "17. GMTITLE selection config probe" -Label "README suite step list"

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
