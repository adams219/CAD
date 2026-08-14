param(
  [string]$SourceDwgPath,

  [int]$TimeoutSeconds = 240
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$probePath = Join-Path $PSScriptRoot "portable_workcopy_probe.lsp"
$cadRunner = Join-Path $PSScriptRoot "run_readonly_probe.ps1"
$testRoot = Join-Path $repoRoot "tmp\portable-workcopy-probe"
$sourceCopy = Join-Path $testRoot "portable_source.dwg"
$destination = Join-Path $testRoot "selected\portable_selected_workcopy.dwg"
$createLog = Join-Path $testRoot "portable_workcopy_create.txt"
$verifyLog = Join-Path $testRoot "portable_workcopy_reopen_verify.txt"
$scriptPath = Join-Path $testRoot "portable_workcopy_probe.scr"

if (-not $SourceDwgPath) {
  $SourceDwgPath = Join-Path $repoRoot "work\0000_A_DRP125_CP_ALL_260626_ORIGINAL_TEST_260711.dwg"
}
$SourceDwgPath = (Resolve-Path -LiteralPath $SourceDwgPath).Path

[void](New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force)
Copy-Item -LiteralPath $SourceDwgPath -Destination $sourceCopy -Force
Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $createLog -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $verifyLog -Force -ErrorAction SilentlyContinue

$sourceHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceCopy).Hash
$repoForLisp = $repoRoot.Replace("\", "/")
$probeForLisp = $probePath.Replace("\", "/")
[System.IO.File]::WriteAllText(
  $scriptPath,
  "(setenv `"SWTITLE_REPO_ROOT`" `"$repoForLisp`")`r`n(load `"$probeForLisp`")`r`n",
  [System.Text.UTF8Encoding]::new($false)
)

$env:SWTITLE_REPO_ROOT = $repoForLisp
$env:SWTITLE_PORTABLE_MODE = "CREATE"
$env:SWTITLE_PORTABLE_DEST = $destination
$env:SWTITLE_PORTABLE_LOG = $createLog
& $cadRunner -DwgPath $sourceCopy -ScriptPath $scriptPath -LogPath $createLog -CompletionPattern "Runtime check completed: yes" -TimeoutSeconds $TimeoutSeconds -WindowStyle Minimized

if (-not (Test-Path -LiteralPath $destination)) {
  throw "Portable work-copy probe did not create the selected destination: $destination"
}
$createText = [System.IO.File]::ReadAllText($createLog)
foreach ($required in @(
  "Result: PORTABLE_WORKCOPY_OK",
  "Save As result: yes",
  "Persistent marker: yes",
  "Authorization: user-selected-saveas-copy",
  "Path match: yes",
  "DBMOD after: 0"
)) {
  if (-not $createText.Contains($required)) {
    throw "Portable work-copy create probe missing expected evidence: $required"
  }
}

$sourceHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceCopy).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
  throw "Portable work-copy source copy changed during Save As probe. Before=$sourceHashBefore After=$sourceHashAfter"
}

$env:SWTITLE_PORTABLE_MODE = "VERIFY"
$env:SWTITLE_PORTABLE_LOG = $verifyLog
& $cadRunner -DwgPath $destination -ScriptPath $scriptPath -LogPath $verifyLog -CompletionPattern "Runtime check completed: yes" -TimeoutSeconds $TimeoutSeconds -WindowStyle Minimized

$verifyText = [System.IO.File]::ReadAllText($verifyLog)
foreach ($required in @(
  "Result: PORTABLE_WORKCOPY_OK",
  "Persistent marker: yes",
  "Authorization: user-selected-saveas-copy",
  "Path match: yes",
  "Portable helper found: yes",
  "Local log root valid: yes",
  "DBMOD after: 0"
)) {
  if (-not $verifyText.Contains($required)) {
    throw "Portable work-copy reopen probe missing expected evidence: $required"
  }
}

Write-Output "Portable Save As work-copy probe: PASS"
Write-Output ("Source SHA256 unchanged: {0}" -f $sourceHashAfter)
Write-Output ("Selected work copy: {0}" -f $destination)
Write-Output ("Create log: {0}" -f $createLog)
Write-Output ("Reopen log: {0}" -f $verifyLog)
