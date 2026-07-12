param(
  [int]$TimeoutSeconds = 240,

  [string]$LoaderRoot,

  [string]$LoaderFile,

  [string]$StoredRoot
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
if (-not $LoaderRoot) { $LoaderRoot = $repoRoot }
if (-not $StoredRoot) { $StoredRoot = $repoRoot }
$LoaderRoot = (Resolve-Path -LiteralPath $LoaderRoot).Path
$StoredRoot = (Resolve-Path -LiteralPath $StoredRoot).Path
if (-not $LoaderFile) {
  $LoaderFile = Join-Path $LoaderRoot "apps\swcad-workflow\swcad_workflow_load.lsp"
}
$LoaderFile = (Resolve-Path -LiteralPath $LoaderFile).Path
$source = Join-Path $repoRoot "portable-e2e\output\swtitle_portable_result_260712.dwg"
$probe = Join-Path $PSScriptRoot "workflow_loader_probe.lsp"
$runner = Join-Path $repoRoot "diagnostics\gmtitle-main45\run_readonly_probe.ps1"
$testRoot = Join-Path $repoRoot "tmp\swcad-workflow-loader-probe"
$testDwg = Join-Path $testRoot "workflow_loader_probe.dwg"
$logPath = Join-Path $testRoot "workflow_loader_probe.txt"
$scriptPath = Join-Path $testRoot "workflow_loader_probe.scr"

[void](New-Item -ItemType Directory -Path $testRoot -Force)
Copy-Item -LiteralPath $source -Destination $testDwg -Force
Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue

$rootForLisp = $repoRoot.Replace("\", "/")
$loaderRootForLisp = $LoaderRoot.Replace("\", "/")
$loaderFileForLisp = $LoaderFile.Replace("\", "/")
$storedRootForLisp = $StoredRoot.Replace("\", "/")
$probeForLisp = $probe.Replace("\", "/")
[IO.File]::WriteAllText(
  $scriptPath,
  "(setenv `"SWCAD_WORKFLOW_ROOT`" `"$storedRootForLisp`")`r`n(setenv `"SWCAD_WORKFLOW_LOADER_ROOT`" `"$loaderRootForLisp`")`r`n(setenv `"SWCAD_WORKFLOW_LOADER_FILE`" `"$loaderFileForLisp`")`r`n(setenv `"SWCAD_WORKFLOW_LOG`" `"$($logPath.Replace('\','/'))`")`r`n(load `"$probeForLisp`")`r`n",
  [Text.UTF8Encoding]::new($false)
)

$runnerOutput = & $runner `
  -DwgPath $testDwg `
  -ScriptPath $scriptPath `
  -LogPath $logPath `
  -CompletionPattern "Runtime check completed: yes" `
  -TimeoutSeconds $TimeoutSeconds `
  -WindowStyle Minimized

$text = [IO.File]::ReadAllText($logPath)
$resolvedLoaderRoot = $LoaderRoot.Replace("\", "/")
foreach ($required in @(
  "Load result: OK",
  "Resolved workflow root: $resolvedLoaderRoot",
  "Command SWCADSTATUS: yes",
  "Command SWCADRUN: yes",
  "Command SWCADVERIFY: yes",
  "State XRecord roundtrip: yes",
  "Existing title complete: yes",
  "Workflow stage: DIMSTYLE",
  "Runtime check completed: yes"
)) {
  if (-not $text.Contains($required)) {
    throw "Workflow loader probe missing evidence: $required"
  }
}

Write-Output "SWCAD Workflow loader probe: PASS"
Write-Output "Workflow stage on existing converted DWG: DIMSTYLE"
