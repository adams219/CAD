param(
  [string]$SourceWorkCopyPath,

  [string]$ProbeDwgPath,

  [string]$LogPath,

  [int]$StartupWaitSeconds = 180,

  [int]$ProbeWaitSeconds = 600,

  [ValidateSet("Hidden", "Minimized", "Normal", "Maximized")]
  [string]$WindowStyle = "Normal",

  [switch]$CoreCleanupOnly
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"
$gcad = "C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\GstarCAD\gcad.exe"
$mainLsp = Join-Path $repoRoot "src\tools\gmtitle\swcad_title_scale.lsp"
$fixture = Join-Path $PSScriptRoot "actual_residue_cleanup_probe.lsp"

if (-not $SourceWorkCopyPath) {
  $SourceWorkCopyPath = Join-Path $workDir "0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg"
}
if (-not $ProbeDwgPath) {
  $ProbeDwgPath = Join-Path $workDir "swtitle_actual_residue_cleanup_probe_260711.dwg"
}
if (-not $LogPath) {
  $LogPath = Join-Path $workDir "swtitle_actual_residue_cleanup_probe_260711.txt"
}

foreach ($requiredPath in @($SourceWorkCopyPath, $gcad, $mainLsp, $fixture)) {
  if (-not (Test-Path -LiteralPath $requiredPath)) {
    throw "Required file not found: $requiredPath"
  }
}

$existing = @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0) {
  throw "Close every GstarCAD process before the actual residue cleanup probe."
}

$sourceHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $SourceWorkCopyPath).Hash
Copy-Item -LiteralPath $SourceWorkCopyPath -Destination $ProbeDwgPath -Force
Remove-Item -LiteralPath $LogPath -Force -ErrorAction SilentlyContinue

$env:SWCAD_TOOL_ROOT = $repoRoot
$env:SWCAD_COMPARE_LSP = $mainLsp
$env:SWCAD_COMPARE_LOG = $LogPath
$env:SWCAD_ACTUAL_CLEAN_CORE_ONLY = $(if ($CoreCleanupOnly) { "1" } else { "0" })

Write-Output "===== SWTITLE actual residue cleanup copied-DWG probe ====="
Write-Output ("Source preserved: {0}" -f $SourceWorkCopyPath)
Write-Output ("Dedicated probe copy: {0}" -f $ProbeDwgPath)
Write-Output ("Result log: {0}" -f $LogPath)
Write-Output ("Cleanup mode: {0}" -f $(if ($CoreCleanupOnly) { "core-only" } else { "public-prepare" }))

$process = Start-Process -FilePath $gcad -ArgumentList "`"$ProbeDwgPath`"" -WindowStyle $WindowStyle -PassThru
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
    throw "Could not attach COM to the dedicated residue-cleanup DWG before timeout."
  }

  $fixtureForLisp = $fixture.Replace("\", "/")
  $document.SendCommand("(load `"$fixtureForLisp`")`rYES`r")
  Write-Output "Sent the copied-DWG residue probe and one cleanup YES response."

  $probeDeadline = (Get-Date).AddSeconds($ProbeWaitSeconds)
  $completed = $false
  while ((Get-Date) -lt $probeDeadline) {
    if ($process.HasExited) {
      throw "GstarCAD exited before the residue cleanup probe completed. Exit code: $($process.ExitCode)"
    }
    if (Test-Path -LiteralPath $LogPath) {
      $probeText = Get-Content -LiteralPath $LogPath -Raw -Encoding Default
      if ($probeText -match "Runtime check completed:\s*yes") {
        $completed = $true
        break
      }
    }
    Start-Sleep -Milliseconds 500
  }

  if (-not $completed) {
    throw "The actual residue cleanup probe did not complete before timeout: $LogPath"
  }

  $expectations = @(
    "Load result: OK",
    "Loaded version: 260713-frame-style-structure-guard-1",
    "First cleanup call: OK",
    "First cleanup status: OK_FRAME_STYLE_NORMALIZATION_CLEANED",
    "After style pairs: 0",
    "After clean candidates: 0",
    "After independent residue: 0",
    "Pair signature unchanged after first cleanup: yes",
    "Second cleanup call: OK",
    "Second cleanup status: OK_NO_FRAME_STYLE_NORMALIZATION",
    "Final style pairs: 0",
    "Final clean candidates: 0",
    "Final independent residue: 0",
    "Pair signature unchanged after second cleanup: yes",
    "SWTITLESTATUS call: OK"
  )
  foreach ($expectation in $expectations) {
    if ($probeText -notmatch [regex]::Escape($expectation)) {
      throw "Residue cleanup probe missing expected marker '$expectation'."
    }
  }

  $beforeIndependent = [int]([regex]::Match($probeText, "Before independent residue:\s*(\d+)").Groups[1].Value)
  $beforeClean = [int]([regex]::Match($probeText, "Before clean candidates:\s*(\d+)").Groups[1].Value)
  $beforePairsMatch = [regex]::Match($probeText, "Before target/native-like pairs:\s*(\d+)/(\d+)")
  $afterPairsMatch = [regex]::Match($probeText, "After target/native-like pairs:\s*(\d+)/(\d+)")
  $finalPairsMatch = [regex]::Match($probeText, "Final target/native-like pairs:\s*(\d+)/(\d+)")
  $beforeObjectsMatch = [regex]::Match($probeText, "Before target frames/titles/orphans:\s*(\d+)/(\d+)/(\d+)")
  $afterObjectsMatch = [regex]::Match($probeText, "After target frames/titles/orphans:\s*(\d+)/(\d+)/(\d+)")
  $finalObjectsMatch = [regex]::Match($probeText, "Final target frames/titles/orphans:\s*(\d+)/(\d+)/(\d+)")
  if ($beforeIndependent -lt 1) { throw "The actual copied DWG had no independent residue before cleanup." }
  if ($beforeClean -lt 1) { throw "The actual copied DWG had no safe cleanup candidates before cleanup." }
  if (-not ($beforePairsMatch.Success -and $afterPairsMatch.Success -and $finalPairsMatch.Success)) {
    throw "Could not parse target/native-like pair counts from the probe log."
  }
  if (-not ($beforeObjectsMatch.Success -and $afterObjectsMatch.Success -and $finalObjectsMatch.Success)) {
    throw "Could not parse target frame/title/orphan counts from the probe log."
  }
  if (($beforePairsMatch.Value -replace ".*:\s*", "") -ne ($afterPairsMatch.Value -replace ".*:\s*", "")) {
    throw "Target/native-like pair counts changed after the first cleanup."
  }
  if (($beforePairsMatch.Value -replace ".*:\s*", "") -ne ($finalPairsMatch.Value -replace ".*:\s*", "")) {
    throw "Target/native-like pair counts changed after the idempotence cleanup."
  }
  if (($beforeObjectsMatch.Value -replace ".*:\s*", "") -ne ($afterObjectsMatch.Value -replace ".*:\s*", "")) {
    throw "Target frame/title/orphan counts changed after the first cleanup."
  }
  if (($beforeObjectsMatch.Value -replace ".*:\s*", "") -ne ($finalObjectsMatch.Value -replace ".*:\s*", "")) {
    throw "Target frame/title/orphan counts changed after the idempotence cleanup."
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
    throw "The dedicated residue cleanup probe DWG did not reach DBMOD=0 after QSAVE."
  }

  Get-Content -LiteralPath $LogPath -Encoding Default
  Write-Output "Result: ACTUAL_RESIDUE_CLEANUP_COPY_PASS"
} finally {
  if ($application -and $saved) {
    try { $application.Quit() } catch { }
    Start-Sleep -Seconds 2
  }
  $running = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
  if ($running) {
    try {
      Stop-Process -Id $process.Id -Force -ErrorAction Stop
      Write-Output ("Stopped isolated GstarCAD PID: {0}" -f $process.Id)
    } catch {
      if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) {
        throw
      }
    }
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
  throw "The source work copy changed during the actual residue cleanup probe."
}
Write-Output "Source work-copy SHA256 unchanged: PASS"
