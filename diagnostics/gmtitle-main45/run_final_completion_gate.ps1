param(
  [string]$SourceWorkCopyPath,

  [int]$TimeoutSeconds = 240,

  [switch]$WaitForGstarCADClose,

  [int]$WaitForGstarCADCloseTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"
$completionFailures = New-Object System.Collections.Generic.List[string]

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
        Write-Output "No existing GstarCAD process detected. Continuing final completion gate."
        return
      }
      Write-Output ("Waiting for GstarCAD to close before the final completion gate... active PID(s): {0}" -f (($existing | ForEach-Object { $_.Id }) -join ", "))
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
Existing GstarCAD process detected before the final completion gate.
The final completion gate uses GstarCAD /b probes, which are unreliable while a visible GstarCAD session is open.

Save the work-copy DWG, close GstarCAD, then rerun:
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_final_completion_gate.ps1

Or start the gate in waiting mode, save/close GstarCAD, and let it continue:
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_final_completion_gate.ps1 -WaitForGstarCADClose

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

function Get-AllRegexValues {
  param(
    [string]$Text,
    [string]$Pattern
  )

  $matches = [regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  $values = New-Object System.Collections.Generic.List[string]
  foreach ($match in $matches) {
    if ($match.Success -and $match.Groups.Count -gt 1) {
      [void]$values.Add($match.Groups[1].Value.Trim())
    }
  }
  return @($values)
}

function Write-CompletionFailureSummary {
  param([string]$StatusLogPath)

  Write-Output ""
  Write-Output "Final completion gate result: FAIL"
  if (Test-Path -LiteralPath $StatusLogPath) {
    $text = Get-Content -LiteralPath $StatusLogPath -Raw
    $statusAfterStatus = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-status:\s*(\S+)"
    $statusAfterVerify = Get-FirstRegexValue -Text $text -Pattern "^\s*status-after-verify:\s*(\S+)"
    $sourceTitleCount = Get-FirstRegexValue -Text $text -Pattern "^\s*source-title-count:\s*(\d+)"
    $sourceFrameCount = Get-FirstRegexValue -Text $text -Pattern "^\s*source-frame-count:\s*(\d+)"
    $frameOnlyCount = Get-FirstRegexValue -Text $text -Pattern "^\s*frame-only-count:\s*(\d+)"
    $targetTitleCount = Get-FirstRegexValue -Text $text -Pattern "^\s*target-title-count:\s*(\d+)"
    $targetFrameCount = Get-FirstRegexValue -Text $text -Pattern "^\s*target-frame-count:\s*(\d+)"
    $nextBootstrapSourceSheet = Get-FirstRegexValue -Text $text -Pattern "^\s*next-bootstrap-source-sheet:\s*(\S+)"
    $nextBootstrapFrame = Get-FirstRegexValue -Text $text -Pattern "^\s*next-bootstrap-frame:\s*(\S+)"
    $nextBootstrapTitle = Get-FirstRegexValue -Text $text -Pattern "^\s*next-bootstrap-title:\s*(\S+)"
    $nextMissingNativeFrame = Get-FirstRegexValue -Text $text -Pattern "^\s*next-missing-native-frame:\s*(\S+)"
    $missingNativeFrames = @(Get-AllRegexValues -Text $text -Pattern "^\s*missing-native-frame:\s*(\S+)")
    if ($statusAfterStatus) {
      Write-Output ("Current status-after-status: {0}" -f $statusAfterStatus)
    }
    if ($statusAfterVerify) {
      Write-Output ("Current status-after-verify: {0}" -f $statusAfterVerify)
    }
    if ($sourceTitleCount -or $sourceFrameCount -or $frameOnlyCount) {
      Write-Output ("Current source counts: source-title-count={0}, source-frame-count={1}, frame-only-count={2}" -f $sourceTitleCount, $sourceFrameCount, $frameOnlyCount)
    }
    if ($targetTitleCount -or $targetFrameCount) {
      Write-Output ("Current target counts: target-title-count={0}, target-frame-count={1}" -f $targetTitleCount, $targetFrameCount)
    }
    if ($nextBootstrapFrame -or $nextBootstrapTitle) {
      Write-Output ("Next first native GMTITLE selection: source-sheet={0}, frame={1}, title={2}" -f $nextBootstrapSourceSheet, $nextBootstrapFrame, $nextBootstrapTitle)
    }
    if ($nextMissingNativeFrame) {
      Write-Output ("Next missing native frame: {0}" -f $nextMissingNativeFrame)
    }
    if ($missingNativeFrames.Count -gt 0) {
      Write-Output ("Missing native frames: {0}" -f ($missingNativeFrames -join ", "))
    }
  }

  Write-Output "Missing completion evidence:"
  foreach ($failure in $completionFailures) {
    Write-Output ("  - {0}" -f $failure)
  }
  Write-Output ""
  Write-Output "Next:"
  Write-Output ("  powershell -NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $PSScriptRoot "run_next_cad_action.ps1"))
  Write-Output "Completion is not proven until SWTITLEVERIFY_FINAL_OK and representative DR_titlea_3rd title-block double-click checks are confirmed."
  Write-Output "Title-missing/frame-only sheets have no DR_titlea_3rd title block by design; verify the matching DR_A*_Outline count/geometry instead."
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

Assert-NoExistingGstarCAD -Wait:$WaitForGstarCADClose -WaitTimeoutSeconds $WaitForGstarCADCloseTimeoutSeconds

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
    "Loaded version: 260711-unified-title-value-3",
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
Write-Output "Manual completion still requires representative DR_titlea_3rd title-block double-click checks."
Write-Output "Title-missing/frame-only sheets have no DR_titlea_3rd title block by design; verify the matching DR_A*_Outline count/geometry instead."
