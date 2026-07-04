param(
  [string]$SourceWorkCopyPath,

  [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"

function Assert-LogContains {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string[]]$Patterns,

    [string]$Label = $Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Completion gate log not found for ${Label}: $Path"
  }

  $text = Get-Content -LiteralPath $Path -Raw
  foreach ($pattern in $Patterns) {
    if ($text -notmatch [regex]::Escape($pattern)) {
      throw "Completion gate failed for ${Label}: missing '$pattern' in $Path"
    }
  }

  Write-Output ("Verified completion log: {0}" -f $Label)
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
    "Loaded version: 260704-target-overlap-adopt-main56-a4frameguard",
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

Write-Output "Final completion gate passed."
