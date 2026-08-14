param(
  [string]$ProbePath = "",
  [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

if ([string]::IsNullOrWhiteSpace($ProbePath)) {
  $ProbePath = Join-Path $repoRoot "work\swcad_cleanup_identity_delta_probe.txt"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $repoRoot "work\swcad_cleanup_identity_delta_analysis.txt"
}

$ansi = [System.Text.Encoding]::GetEncoding(949)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$content = [System.IO.File]::ReadAllText($ProbePath, $ansi)
$lines = $content -split "`r?`n"
$targetLine = $lines | Where-Object { $_ -like "TARGET=*" } | Select-Object -First 1
$currentLine = $lines | Where-Object { $_ -like "CURRENT=*" } | Select-Object -First 1
$fullLine = $lines | Where-Object { $_ -like "FULL=*" } | Select-Object -First 1
$candidates = @($lines | Where-Object { $_ -like "CANDIDATE=*" } | ForEach-Object { $_.Substring(10) })

if (-not $targetLine -or -not $currentLine -or -not $fullLine) {
  throw "Probe output is incomplete: $ProbePath"
}

$targetParts = $targetLine.Substring(7).Split(":")
$currentParts = $currentLine.Substring(8).Split(":")
$fullText = $fullLine.Substring(5)

function Get-RollingHashFromBytes {
  param(
    [byte[]]$Bytes,
    [int]$Modulus,
    [int]$Seed
  )
  [long]$value = $Seed
  for ($index = 0; $index -lt $Bytes.Length; $index++) {
    $value = (($value * 257L) + [int]$Bytes[$index]) % $Modulus
  }
  return [int]$value
}

function Get-RollingHashFromChars {
  param(
    [string]$Text,
    [int]$Modulus,
    [int]$Seed
  )
  [long]$value = $Seed
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $value = (($value * 257L) + [int][char]$Text[$index]) % $Modulus
  }
  return [int]$value
}

function Get-ModeHashes {
  param([string]$Text, [string]$Mode)
  switch ($Mode) {
    "CP949_BYTES" {
      $bytes = $ansi.GetBytes($Text)
      return @(
        (Get-RollingHashFromBytes $bytes 1000003 53),
        (Get-RollingHashFromBytes $bytes 1000033 79)
      )
    }
    "UTF8_BYTES" {
      $bytes = $utf8.GetBytes($Text)
      return @(
        (Get-RollingHashFromBytes $bytes 1000003 53),
        (Get-RollingHashFromBytes $bytes 1000033 79)
      )
    }
    "UTF16_CODE_UNITS" {
      return @(
        (Get-RollingHashFromChars $Text 1000003 53),
        (Get-RollingHashFromChars $Text 1000033 79)
      )
    }
    default { throw "Unknown hash mode: $Mode" }
  }
}

$mode = $null
$modeEvidence = @()
foreach ($candidateMode in @("CP949_BYTES", "UTF8_BYTES", "UTF16_CODE_UNITS")) {
  $hashes = Get-ModeHashes $fullText $candidateMode
  $modeEvidence += "$candidateMode=$($hashes[0]):$($hashes[1])"
  if (
    $hashes[0] -eq [int]$currentParts[1] -and
    $hashes[1] -eq [int]$currentParts[2]
  ) {
    $mode = $candidateMode
  }
}

if (-not $mode) {
  throw "Could not reproduce the CAD hash. Evidence: $($modeEvidence -join ', ')"
}

$matches = New-Object System.Collections.Generic.List[string]
foreach ($candidate in $candidates) {
  $needle = " " + $candidate
  $start = $fullText.IndexOf($needle, [System.StringComparison]::Ordinal)
  if ($start -lt 0) {
    throw "Candidate token not found in FULL identity text: $candidate"
  }
  $trial = $fullText.Remove($start, $needle.Length)
  $trialHashes = Get-ModeHashes $trial $mode
  if (
    $trialHashes[0] -eq [int]$targetParts[1] -and
    $trialHashes[1] -eq [int]$targetParts[2]
  ) {
    $matches.Add($candidate)
  }
}

$result = @(
  "PROBE=$ProbePath"
  "TARGET=$($targetLine.Substring(7))"
  "CURRENT=$($currentLine.Substring(8))"
  "HASH_MODE=$mode"
  "HASH_MODE_EVIDENCE=$($modeEvidence -join ' | ')"
  "CANDIDATE_COUNT=$($candidates.Count)"
  "MATCH_COUNT=$($matches.Count)"
)
foreach ($match in $matches) {
  $result += "MATCH=$match"
}

[System.IO.File]::WriteAllLines($OutputPath, $result, $utf8)
$result
