param(
  [string]$SourceWorkCopyPath,

  [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"
$completionFailures = New-Object System.Collections.Generic.List[string]

function Assert-LogContains {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string[]]$Patterns,

    [string]$Label = $Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    [void]$completionFailures.Add("Completion gate log not found for ${Label}: $Path")
    return
  }

  $text = Get-Content -LiteralPath $Path -Raw
  foreach ($pattern in $Patterns) {
    if ($text -notmatch [regex]::Escape($pattern)) {
      [void]$completionFailures.Add("Completion gate failed for ${Label}: missing '$pattern' in $Path")
    }
  }

  if ($completionFailures.Count -eq 0) {
    Write-Output ("Verified completion log: {0}" -f $Label)
  }
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

function Write-CompletionFailureSummary {
  param([string]$StatusLogPath)

  Write-Output ""
  Write-Output "Final completion gate result: FAIL"
  if (Test-Path -LiteralPath $StatusLogPath) {
    $text = Get-Content -LiteralPath $StatusLogPath -Raw
    $statusAfterStatus = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-status:\s*(\S+)"
    $statusAfterVerify = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-verify:\s*(\S+)"
    if ($statusAfterStatus) {
      Write-Output ("Current status-after-status: {0}" -f $statusAfterStatus)
    }
    if ($statusAfterVerify) {
      Write-Output ("Current status-after-verify: {0}" -f $statusAfterVerify)
    }
  }

  Write-Output "Missing completion evidence:"
  foreach ($failure in $completionFailures) {
    Write-Output ("  - {0}" -f $failure)
  }
  Write-Output ""
  Write-Output "Next:"
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $PSScriptRoot "run_next_cad_action.ps1"))
  Write-Output "Completion is not proven until SWTITLEVERIFY_FINAL_OK and representative A2/A3 title-block double-click checks are confirmed."
  Write-Output "A4 frame-only sheets have no DR_titlea_3rd title block; verify their DR_A4_Outline count/geometry instead."
}

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $repoRoot "work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not (Test-Path -LiteralPath $SourceWorkCopyPath)) {
  throw "Source work-copy DWG not found: $SourceWorkCopyPath"
}

$probeDwgPath = Join-Path $workDir "swtitle_final_completion_gate_probe.dwg"
$statusLogPath = Join-Path $workDir "swtitle_final_completion_gate_status.txt"
$detailSuffix = "_final_completion_gate"
$verifySummaryLogPath = Join-Path $workDir "swcad_title_verify_summary_last_final_completion_gate.txt"

Write-Output "===== GMTITLE main56 final completion gate ====="
Write-Output ("Source work copy: {0}" -f $SourceWorkCopyPath)

& (Join-Path $PSScriptRoot "run_actual_workcopy_status_probe.ps1") `
  -SourceWorkCopyPath $SourceWorkCopyPath `
  -ProbeDwgPath $probeDwgPath `
  -LogPath $statusLogPath `
  -DetailSuffix $detailSuffix `
  -TimeoutSeconds $TimeoutSeconds

Assert-LogContains `
  -Path $statusLogPath `
  -Label "final completion status probe" `
  -Patterns @(
    "Load result: OK",
    "Loaded version: 260705-convertnext-selection-guide",
    "Result: OK SWTITLESTATUS",
    "Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_OK",
    "source-title-count: 0",
    "source-frame-count: 0",
    "frame-only-count: 0",
    "frame-definition-blockers: 0",
    "frame-embedded-cleanup-records: 0",
    "target-sheet-counts:",
    "A2: 1",
    "A3: 12",
    "A4: 2",
    "status-after-verify: SWTITLEVERIFY_FINAL_OK",
    "Runtime check completed: yes"
  )

Assert-LogContains `
  -Path $verifySummaryLogPath `
  -Label "final completion verify summary" `
  -Patterns @(
    "SWTITLEVERIFY_FINAL_OK",
    "A2: 1",
    "A3: 12",
    "A4: 2"
  )

if ($completionFailures.Count -gt 0) {
  Write-CompletionFailureSummary -StatusLogPath $statusLogPath
  throw "Final completion gate failed with $($completionFailures.Count) missing evidence item(s)."
}

Write-Output "Final automated completion evidence passed."
Write-Output "Manual completion still requires representative A2/A3 DR_titlea_3rd title-block double-click checks."
Write-Output "A4 frame-only sheets have no DR_titlea_3rd title block; verify their DR_A4_Outline count/geometry instead."
