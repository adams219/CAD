param(
  [string[]]$InputDwg,

  # One DWG path per line; easier than an array when started with -File.
  [string]$InputListFile,

  # "old", "new" or "old,new".
  [string]$Modes = "old,new",

  [string]$OldModuleRef = "5b405bf3",

  [string]$OutputRoot,

  [int]$TimeoutSeconds = 300,

  # Numbering offset to resume an interrupted run into the same OutputRoot.
  [int]$CaseOffset = 0
)

# Runs SWAUTO on copies of the given DWGs with the old and/or new dimstyle module
# and compares every dimension's displayed number before and after.
# Source DWGs are only read; all CAD work happens on copies under tmp\.

$ErrorActionPreference = "Stop"

if ($InputListFile) {
  $InputDwg = @(Get-Content -LiteralPath $InputListFile -Encoding UTF8 | Where-Object { $_.Trim() -ne "" })
}
if (-not $InputDwg -or $InputDwg.Count -eq 0) { throw "No input DWG given. Use -InputDwg or -InputListFile." }
$modeList = @($Modes.Split(",") | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ -ne "" })
foreach ($mode in $modeList) {
  if (@("old", "new") -notcontains $mode) { throw "Unknown mode: $mode" }
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$probe = Join-Path $PSScriptRoot "swauto_value_probe.lsp"
$runner = Join-Path $repoRoot "diagnostics\gmtitle-main45\run_readonly_probe.ps1"
$newModule = Join-Path $repoRoot "src\tools\gstarcad-dimstyle\gstarcad_dimstyle_keep_tolerance.lsp"
if (-not $OutputRoot) {
  $OutputRoot = Join-Path $repoRoot ("tmp\swauto-value-test\" + (Get-Date -Format "yyMMdd_HHmmss"))
}
[void](New-Item -ItemType Directory -Path $OutputRoot -Force)
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path

# Snapshot the working-tree module so edits during a long run cannot mix versions.
$newModuleSnapshot = Join-Path $OutputRoot "new_gstarcad_dimstyle_keep_tolerance.lsp"
Copy-Item -LiteralPath $newModule -Destination $newModuleSnapshot -Force
$newModule = $newModuleSnapshot

$oldModule = Join-Path $OutputRoot "old_gstarcad_dimstyle_keep_tolerance.lsp"
if ($modeList -contains "old") {
  # cmd redirection keeps the blob bytes (BOM included) exactly as stored in git.
  $gitSpec = "${OldModuleRef}:src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance.lsp"
  & cmd.exe /c "git -C `"$repoRoot`" show `"$gitSpec`" > `"$oldModule`""
  if (($LASTEXITCODE -ne 0) -or ((Get-Item -LiteralPath $oldModule).Length -lt 1000)) {
    throw "Could not read the old module from git ref $OldModuleRef."
  }
}

$manifest = @()
$index = 0
foreach ($source in $InputDwg) {
  $index += 1
  $sourceItem = Get-Item -LiteralPath $source
  $sourceHash = (Get-FileHash -LiteralPath $sourceItem.FullName -Algorithm SHA256).Hash
  $caseName = "dwg{0:D2}" -f ($index + $CaseOffset)
  foreach ($mode in $modeList) {
    $modeRoot = Join-Path $OutputRoot $mode
    [void](New-Item -ItemType Directory -Path $modeRoot -Force)
    $copy = Join-Path $modeRoot "$caseName.dwg"
    $log = Join-Path $modeRoot "$caseName.log"
    $scr = Join-Path $modeRoot "$caseName.scr"
    Copy-Item -LiteralPath $sourceItem.FullName -Destination $copy -Force
    $module = if ($mode -eq "old") { $oldModule } else { $newModule }
    $scrText = @(
      "(setenv `"SWAUTO_TEST_MODULE`" `"$($module.Replace('\', '/'))`")",
      "(setenv `"SWAUTO_TEST_MODE`" `"$mode`")",
      "(setenv `"SWAUTO_TEST_LOG`" `"$($log.Replace('\', '/'))`")",
      "(load `"$($probe.Replace('\', '/'))`")",
      ""
    ) -join "`r`n"
    [IO.File]::WriteAllText($scr, $scrText, [Text.UTF8Encoding]::new($false))
    Write-Output ("[{0}/{1}] {2} {3}" -f $index, $InputDwg.Count, $mode, $sourceItem.Name)
    $runnerOutput = & $runner -DwgPath $copy -ScriptPath $scr -LogPath $log -CompletionPattern "SWAUTO value probe completed: yes" -TimeoutSeconds $TimeoutSeconds -WindowStyle Minimized
    $completed = (Test-Path -LiteralPath $log) -and ((Get-Content -LiteralPath $log -Raw) -match "SWAUTO value probe completed: yes")
    if (-not $completed) {
      Write-Output "  probe did not complete"
      $runnerOutput | Select-Object -Last 5 | ForEach-Object { Write-Output "  $_" }
    }
    $manifest += [pscustomobject]@{ Case = $caseName; Mode = $mode; Source = $sourceItem.FullName; Log = $log; Completed = $completed }
  }
  $afterHash = (Get-FileHash -LiteralPath $sourceItem.FullName -Algorithm SHA256).Hash
  if ($afterHash -ne $sourceHash) { throw "Source DWG hash changed: $($sourceItem.FullName)" }
}

$manifestPath = Join-Path $OutputRoot "manifest.csv"
if (($CaseOffset -gt 0) -and (Test-Path -LiteralPath $manifestPath)) {
  $manifest = @(Import-Csv -LiteralPath $manifestPath) + $manifest
}
$manifest | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8
& (Join-Path $PSScriptRoot "analyze_swauto_value_test.ps1") -OutputRoot $OutputRoot
