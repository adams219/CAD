param(
  [string]$SourceWorkCopyPath,

  [string]$ProbeDwgPath,

  [int]$StartupWaitSeconds = 180,

  [int]$BatchWaitSeconds = 900,

  [switch]$CompleteTitleMissing
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"
$gcad = "C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\GstarCAD\gcad.exe"
$mainLsp = Join-Path $repoRoot "src\tools\gmtitle\swcad_title_scale.lsp"
$summaryLog = Join-Path $workDir "swcad_title_native_autoselect_batch_last.txt"
$autoselectLog = Join-Path $workDir "swcad_title_gmtitle_autoselect_last.txt"
$titleMissingSummaryLog = Join-Path $workDir "swcad_title_title_missing_batch_last.txt"
$nextStepLog = Join-Path $workDir "swcad_title_next_step_last.txt"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $ProbeDwgPath) {
  $ProbeDwgPath = Join-Path $workDir "swtitle_integrated_autoselect_batch_probe.dwg"
}

foreach ($requiredPath in @($SourceWorkCopyPath, $gcad, $mainLsp)) {
  if (-not (Test-Path -LiteralPath $requiredPath)) {
    throw "Required file not found: $requiredPath"
  }
}

$existing = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0) {
  throw "Close every GstarCAD process before the isolated integrated batch probe."
}

$sourceHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $SourceWorkCopyPath).Hash
Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $ProbeDwgPath -Force
Remove-Item -LiteralPath $summaryLog, $autoselectLog, $titleMissingSummaryLog, $nextStepLog -Force -ErrorAction SilentlyContinue

Write-Output "===== SWTITLE integrated fixed-control batch probe ====="
Write-Output ("Source preserved: {0}" -f $SourceWorkCopyPath)
Write-Output ("Dedicated probe copy: {0}" -f $ProbeDwgPath)

$process = Start-Process -FilePath $gcad -ArgumentList "`"$ProbeDwgPath`"" -WindowStyle Hidden -PassThru
$application = $null
$document = $null
$saved = $false

try {
  $startupDeadline = (Get-Date).AddSeconds($StartupWaitSeconds)
  $progIds = @("Gcad.Application.24", "GStarCAD.Application.24", "Gcad.Application", "GStarCAD.Application")
  while ((Get-Date) -lt $startupDeadline) {
    if ($process.HasExited) {
      throw "GstarCAD exited before COM became ready. Exit code: $($process.ExitCode)"
    }
    foreach ($progId in $progIds) {
      try {
        $candidate = [Runtime.InteropServices.Marshal]::GetActiveObject($progId)
        $candidateDocument = $candidate.ActiveDocument
        if ($candidateDocument -and $candidateDocument.FullName) {
          $candidatePath = [IO.Path]::GetFullPath([string]$candidateDocument.FullName)
          $expectedPath = [IO.Path]::GetFullPath($ProbeDwgPath)
          if ($candidatePath.Equals($expectedPath, [StringComparison]::OrdinalIgnoreCase)) {
            $application = $candidate
            $document = $candidateDocument
            break
          }
        }
      } catch {
      }
    }
    if ($document) { break }
    Start-Sleep -Milliseconds 500
  }

  if (-not $document) {
    throw "Could not attach COM to the dedicated probe DWG before timeout."
  }

  $lspForLisp = $mainLsp.Replace("\", "/")
  $sendText = "(load `"$lspForLisp`")`rSWTITLECONVERTNEXT`r"
  $document.SendCommand($sendText)
  Write-Output "Sent APPLOAD-equivalent load and SWTITLECONVERTNEXT through the isolated document COM object."

  $batchDeadline = (Get-Date).AddSeconds($BatchWaitSeconds)
  $completed = $false
  while ((Get-Date) -lt $batchDeadline) {
    if ($process.HasExited) {
      throw "GstarCAD exited before the batch summary was completed. Exit code: $($process.ExitCode)"
    }
    if (Test-Path -LiteralPath $summaryLog) {
      $summaryText = Get-Content -LiteralPath $summaryLog -Raw -Encoding UTF8
      if ($summaryText -match "Runtime check completed:\s*yes") {
        $completed = $true
        break
      }
    }
    Start-Sleep -Milliseconds 500
  }

  if (-not $completed) {
    throw "SWTITLECONVERTNEXT did not finish its integrated batch before timeout. Inspect: $summaryLog and $autoselectLog"
  }

  $initial = [int]([regex]::Match($summaryText, "Initial source title sheets:\s*(\d+)").Groups[1].Value)
  $remaining = [int]([regex]::Match($summaryText, "Remaining source title sheets:\s*(\d+)").Groups[1].Value)
  $targetTitles = [int]([regex]::Match($summaryText, "Target title inserts:\s*(\d+)").Groups[1].Value)
  $targetPairs = [int]([regex]::Match($summaryText, "Target GMTITLE pairs:\s*(\d+)").Groups[1].Value)
  $sharedLinks = [int]([regex]::Match($summaryText, "Shared native-link target titles:\s*(\d+)").Groups[1].Value)
  $upgradeCandidates = [int]([regex]::Match($summaryText, "Native upgrade candidates:\s*(\d+)").Groups[1].Value)

  if ($initial -lt 2) { throw "The probe did not exercise a multi-sheet source batch. Initial count: $initial" }
  if ($remaining -ne 0) { throw "Source title sheets remain after the integrated batch: $remaining" }
  if ($targetTitles -ne $targetPairs) { throw "Target title/pair counts differ: titles=$targetTitles pairs=$targetPairs" }
  if ($sharedLinks -ne 0) { throw "The integrated native batch produced shared native-link titles: $sharedLinks" }
  if ($upgradeCandidates -ne 0) { throw "Native upgrade candidates remain after direct native creation: $upgradeCandidates" }
  if ($summaryText -notmatch "Result:\s*OK_NATIVE_AUTOSELECT_BATCH_COMPLETE") {
    throw "Integrated batch completed with an unexpected result."
  }

  if ($CompleteTitleMissing) {
    $document.SendCommand("SWTITLEPREPARE`rYES`rSWTITLESTATUS`r")
    Write-Output "Sent SWTITLEPREPARE + YES + SWTITLESTATUS for the verified title-missing exception."

    $prepareDeadline = (Get-Date).AddSeconds(300)
    $titleMissingReady = $false
    while ((Get-Date) -lt $prepareDeadline) {
      if ($process.HasExited) {
        throw "GstarCAD exited during title-missing definition preparation. Exit code: $($process.ExitCode)"
      }
      if (Test-Path -LiteralPath $nextStepLog) {
        $nextStepText = Get-Content -LiteralPath $nextStepLog -Raw -Encoding UTF8
        if ($nextStepText -match "READY_FOR_TITLE_MISSING_OUTLINE") {
          $titleMissingReady = $true
          break
        }
        if ($nextStepText -match "NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION") {
          throw "SWTITLEPREPARE completed but the title-missing outline definition is still not ready. Inspect: $nextStepLog"
        }
      }
      Start-Sleep -Milliseconds 500
    }
    if (-not $titleMissingReady) {
      throw "SWTITLEPREPARE/SWTITLESTATUS did not reach READY_FOR_TITLE_MISSING_OUTLINE before timeout."
    }

    $document.SendCommand("SWTITLECONVERTNEXT`r")
    Write-Output "Sent SWTITLECONVERTNEXT for all verified title-missing outline sheets."

    $titleMissingDeadline = (Get-Date).AddSeconds(300)
    $titleMissingCompleted = $false
    while ((Get-Date) -lt $titleMissingDeadline) {
      if ($process.HasExited) {
        throw "GstarCAD exited during title-missing outline conversion. Exit code: $($process.ExitCode)"
      }
      if (Test-Path -LiteralPath $titleMissingSummaryLog) {
        $titleMissingText = Get-Content -LiteralPath $titleMissingSummaryLog -Raw -Encoding UTF8
        if ($titleMissingText -match "Runtime check completed:\s*yes") {
          $titleMissingCompleted = $true
          break
        }
      }
      Start-Sleep -Milliseconds 500
    }
    if (-not $titleMissingCompleted) {
      throw "The title-missing outline batch did not complete before timeout: $titleMissingSummaryLog"
    }

    $initialTitleMissing = [int]([regex]::Match($titleMissingText, "Initial title-missing sheets:\s*(\d+)").Groups[1].Value)
    $remainingTitleMissing = [int]([regex]::Match($titleMissingText, "Remaining title-missing sheets:\s*(\d+)").Groups[1].Value)
    $finalTargetFrames = [int]([regex]::Match($titleMissingText, "Target frame inserts:\s*(\d+)").Groups[1].Value)
    $finalTargetTitles = [int]([regex]::Match($titleMissingText, "Target title inserts:\s*(\d+)").Groups[1].Value)
    if ($initialTitleMissing -lt 1) { throw "The full-flow probe did not exercise a title-missing sheet." }
    if ($remainingTitleMissing -ne 0) { throw "Title-missing sheets remain after the batch: $remainingTitleMissing" }
    if ($finalTargetFrames -ne ($targetPairs + $initialTitleMissing)) {
      throw "Final target frame count is unexpected: frames=$finalTargetFrames title-pairs=$targetPairs title-missing=$initialTitleMissing"
    }
    if ($finalTargetTitles -ne $targetTitles) {
      throw "Title-missing conversion changed the target title count: before=$targetTitles after=$finalTargetTitles"
    }
    if ($titleMissingText -notmatch "Result:\s*OK_TITLE_MISSING_OUTLINE_BATCH_COMPLETE") {
      throw "Title-missing outline batch completed with an unexpected result."
    }

    Get-Content -LiteralPath $titleMissingSummaryLog -Encoding UTF8
    Write-Output "Result: INTEGRATED_TITLE_MISSING_OUTLINE_BATCH_PASS"
  }

  $idleDeadline = (Get-Date).AddSeconds(60)
  while ((Get-Date) -lt $idleDeadline) {
    try {
      if ([int]$document.GetVariable("CMDACTIVE") -eq 0) { break }
    } catch {
    }
    Start-Sleep -Milliseconds 250
  }

  $document.SendCommand("_.QSAVE`r")
  $saveDeadline = (Get-Date).AddSeconds(120)
  while ((Get-Date) -lt $saveDeadline) {
    try {
      $cmdActive = [int]$document.GetVariable("CMDACTIVE")
      $dbmod = [int]$document.GetVariable("DBMOD")
      if (($cmdActive -eq 0) -and ($dbmod -eq 0)) {
        $saved = $true
        break
      }
    } catch {
    }
    Start-Sleep -Milliseconds 500
  }
  if (-not $saved) {
    throw "The dedicated batch probe DWG did not reach DBMOD=0 after QSAVE."
  }

  Get-Content -LiteralPath $summaryLog -Encoding UTF8
  Write-Output "Result: INTEGRATED_NATIVE_AUTOSELECT_MULTI_SHEET_PASS"
} finally {
  if ($application -and $saved) {
    try { $application.Quit() } catch { }
    Start-Sleep -Seconds 2
  }
  $running = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
  if ($running) {
    Stop-Process -Id $process.Id -Force
    Write-Output ("Stopped isolated GstarCAD PID: {0}" -f $process.Id)
  }
  if ($document) {
    try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($document) } catch { }
  }
  if ($application) {
    try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($application) } catch { }
  }
}

$sourceHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $SourceWorkCopyPath).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
  throw "The source work copy changed during the isolated batch probe."
}
Write-Output "Source work-copy SHA256 unchanged: PASS"
