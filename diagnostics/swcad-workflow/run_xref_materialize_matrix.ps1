param(
  [string]$SourceDwgPath,

  [int]$TimeoutSeconds = 240,

  [ValidateSet("Hidden", "Minimized", "Normal", "Maximized")]
  [string]$WindowStyle = "Minimized"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$probePath = Join-Path $PSScriptRoot "xref_materialize_probe.lsp"
$cadRunner = Join-Path $repoRoot "diagnostics\gmtitle-main45\run_readonly_probe.ps1"
$testRoot = Join-Path $repoRoot "tmp\swcad-xref-materialize-matrix"

if (-not $SourceDwgPath) {
  $SourceDwgPath = Join-Path $repoRoot "work\0000_A_DRP125_CP_ALL_260626_ORIGINAL_TEST_260711.dwg"
}
$SourceDwgPath = (Resolve-Path -LiteralPath $SourceDwgPath).Path

$templateCandidates = @(
  (Join-Path $env:LOCALAPPDATA "Gstarsoft\GstarMechStd\R24\ko-KR\Template\gcadiso.dwt"),
  (Join-Path $env:LOCALAPPDATA "Gstarsoft\GstarMechStd\R24\ko-KR\Template\gm_iso.dwt")
)
$templatePath = $templateCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $templatePath) {
  throw "No GstarCAD Mechanical template found. Checked: $($templateCandidates -join ', ')"
}

[void](New-Item -ItemType Directory -Path $testRoot -Force)
$scriptPath = Join-Path $testRoot "xref_materialize_probe.scr"
$rootForLisp = $repoRoot.Replace("\", "/")
$probeForLisp = $probePath.Replace("\", "/")
[System.IO.File]::WriteAllText(
  $scriptPath,
  "(setenv `"SWCAD_WORKFLOW_ROOT`" `"$rootForLisp`")`r`n(load `"$probeForLisp`")`r`n",
  [System.Text.UTF8Encoding]::new($false)
)

function Get-ProbeValue {
  param([string]$Text, [string]$Label)
  $match = [regex]::Match($Text, "(?m)^" + [regex]::Escape($Label) + ":\s*(.+?)\s*$")
  if (-not $match.Success) {
    throw "Probe output is missing '$Label'."
  }
  $match.Groups[1].Value.Trim()
}

function Get-DimensionFingerprint {
  param([string]$Text)
  $records = @(
    ($Text -split "`r?`n") |
      Where-Object { $_.StartsWith("DIMREC:", [System.StringComparison]::Ordinal) } |
      Sort-Object
  )
  $bytes = [System.Text.Encoding]::UTF8.GetBytes(($records -join "`n"))
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "")
  } finally {
    $sha.Dispose()
  }
}

$sourceHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $SourceDwgPath).Hash
$results = [ordered]@{}

foreach ($mode in @("BASELINE", "ATTACHED", "BOUND", "EXPLODED")) {
  $logPath = Join-Path $testRoot ("{0}.txt" -f $mode.ToLowerInvariant())
  $outputPath = Join-Path $testRoot ("{0}.dwg" -f $mode.ToLowerInvariant())
  Remove-Item -LiteralPath $logPath, $outputPath -Force -ErrorAction SilentlyContinue

  $env:SWCAD_WORKFLOW_ROOT = $rootForLisp
  $env:SWCAD_XREF_MODE = $mode
  $env:SWCAD_XREF_SOURCE = $SourceDwgPath
  $env:SWCAD_XREF_OUTPUT = if ($mode -eq "BASELINE") { "" } else { $outputPath }
  $env:SWCAD_XREF_LOG = $logPath

  $dwgPath = if ($mode -eq "BASELINE") { $SourceDwgPath } else { $templatePath }
  $runnerOutput = & $cadRunner `
    -DwgPath $dwgPath `
    -ScriptPath $scriptPath `
    -LogPath $logPath `
    -CompletionPattern "Runtime check completed: yes" `
    -TimeoutSeconds $TimeoutSeconds `
    -WindowStyle $WindowStyle

  $text = [System.IO.File]::ReadAllText($logPath)
  if (-not $text.Contains("Runtime check completed: yes")) {
    throw "$mode probe did not complete successfully. See $logPath"
  }
  if (($mode -ne "BASELINE") -and (-not (Test-Path -LiteralPath $outputPath))) {
    throw "$mode probe did not save its disposable output DWG: $outputPath"
  }

  $results[$mode] = [ordered]@{
    Text = $text
    Xrefs = [int](Get-ProbeValue $text "XREF definition count")
    TopEntities = [int](Get-ProbeValue $text "Top entity count")
    TopDimensions = [int](Get-ProbeValue $text "Top dimension count")
    DeepEntities = [int](Get-ProbeValue $text "Deep entity count")
    DeepDimensions = [int](Get-ProbeValue $text "Deep dimension count")
    DeepTargetReferences = [int](Get-ProbeValue $text "Deep target reference count")
    TitleSources = [int](Get-ProbeValue $text "Title source count")
    FrameSources = [int](Get-ProbeValue $text "Frame source count")
    FrameOnlySources = [int](Get-ProbeValue $text "Frame-only source count")
    TargetTitles = [int](Get-ProbeValue $text "Target title count")
    TargetFrames = [int](Get-ProbeValue $text "Target frame count")
    TargetPairs = [int](Get-ProbeValue $text "Target pair count")
    NativeLikePairs = [int](Get-ProbeValue $text "Native-like pair count")
    Bbox = Get-ProbeValue $text "Model bbox"
    BboxSize = Get-ProbeValue $text "Model bbox size"
    DimensionFingerprint = Get-DimensionFingerprint $text
  }
}

$sourceHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $SourceDwgPath).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
  throw "Source DWG changed during XREF matrix. Before=$sourceHashBefore After=$sourceHashAfter"
}

$baseline = $results.BASELINE
$attached = $results.ATTACHED
$bound = $results.BOUND
$exploded = $results.EXPLODED

if ($attached.Xrefs -ne 1) {
  throw "ATTACHED should retain exactly one XREF definition; actual=$($attached.Xrefs)."
}
if ($bound.Xrefs -ne 0 -or $exploded.Xrefs -ne 0) {
  throw "BOUND and EXPLODED should contain no live XREF definitions. BOUND=$($bound.Xrefs) EXPLODED=$($exploded.Xrefs)"
}
foreach ($mode in @("ATTACHED", "BOUND", "EXPLODED")) {
  if ($results[$mode].DeepDimensions -ne $baseline.DeepDimensions) {
    throw "$mode deep dimension count differs from baseline. Baseline=$($baseline.DeepDimensions) Actual=$($results[$mode].DeepDimensions)"
  }
  if ($results[$mode].DimensionFingerprint -ne $baseline.DimensionFingerprint) {
    throw "$mode dimension semantic fingerprint differs from baseline."
  }
}
if ($bound.TopDimensions -ne 0) {
  throw "BIND alone unexpectedly exposed top-level dimensions; actual=$($bound.TopDimensions). Reassess the materialization contract."
}
if ($exploded.TopDimensions -ne $baseline.TopDimensions) {
  throw "BIND plus one-level EXPLODE did not expose the baseline top-level dimensions. Baseline=$($baseline.TopDimensions) Actual=$($exploded.TopDimensions)"
}
if (($baseline.TitleSources -gt 0 -or $baseline.FrameSources -gt 0) -and
    ($exploded.TitleSources -ne $baseline.TitleSources -or $exploded.FrameSources -ne $baseline.FrameSources)) {
  throw "EXPLODED GMTITLE source recognition differs from baseline. Baseline titles/frames=$($baseline.TitleSources)/$($baseline.FrameSources), actual=$($exploded.TitleSources)/$($exploded.FrameSources)."
}
if ($bound.TitleSources -ge $baseline.TitleSources -and $baseline.TitleSources -gt 0) {
  throw "BIND alone unexpectedly exposes all title sources; the matrix assumption needs review."
}
if (($baseline.TargetFrames -eq 0 -and $baseline.TargetTitles -eq 0) -and
    ($attached.BboxSize -ne $bound.BboxSize -or $attached.BboxSize -ne $exploded.BboxSize)) {
  throw "Materialization changed the host model bbox size. ATTACHED=$($attached.BboxSize) BOUND=$($bound.BboxSize) EXPLODED=$($exploded.BboxSize)"
}
if ($baseline.TargetFrames -gt 0 -or $baseline.TargetTitles -gt 0) {
  if ($attached.DeepTargetReferences -lt ($baseline.TargetFrames + $baseline.TargetTitles)) {
    throw "ATTACHED deep target-reference guard did not detect the native GMTITLE source. Expected at least $($baseline.TargetFrames + $baseline.TargetTitles), actual=$($attached.DeepTargetReferences)."
  }
  if ($exploded.TargetPairs -eq $baseline.TargetPairs -and $exploded.NativeLikePairs -eq $baseline.NativeLikePairs) {
    throw "Native GMTITLE unexpectedly survived BIND plus EXPLODE unchanged. Review the guard policy before accepting this CAD version."
  }
}

Write-Output "===== SWCAD XREF materialization matrix ====="
foreach ($mode in $results.Keys) {
  $item = $results[$mode]
  Write-Output ("{0}: xrefs={1}, top-dims={2}, deep-dims={3}, deep-target-refs={4}, source-title/frame={5}/{6}, target-title/frame/pair/native={7}/{8}/{9}/{10}, bbox-size={11}, dim-hash={12}" -f `
    $mode, $item.Xrefs, $item.TopDimensions, $item.DeepDimensions, $item.DeepTargetReferences, $item.TitleSources, $item.FrameSources, $item.TargetTitles, $item.TargetFrames, $item.TargetPairs, $item.NativeLikePairs, $item.BboxSize, $item.DimensionFingerprint)
}
Write-Output ("Source SHA256 unchanged: {0}" -f $sourceHashAfter)
if ($baseline.TargetFrames -gt 0 -or $baseline.TargetTitles -gt 0) {
  Write-Output "Selected materialization policy: REJECT native-GMTITLE XREF before BIND/EXPLODE"
} else {
  Write-Output "Selected materialization policy: BIND plus exactly one top-level EXPLODE for raw source XREF"
}
Write-Output ("Disposable outputs: {0}" -f $testRoot)
Write-Output "XREF materialization matrix result: PASS"
