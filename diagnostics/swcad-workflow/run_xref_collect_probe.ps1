param(
  # Folder with the DWGs to collect. Use copies under work\, never the originals.
  [string]$SourceDir,
  [string]$OutputRoot,
  # Also run the XREF stage and keep the work copy (work\xref-collect-test\<stamp>\collect_host.dwg).
  [switch]$WorkCopy,
  [int]$TimeoutSeconds = 400
)

# SWCADRUN step 0 (COLLECT) test in GstarCAD /b: a new drawing from the Mechanical
# template, the DWGs of $SourceDir attached as XREFs through SWCADRUN, then the row,
# overlap and Layout-order checks of xref_collect_probe.lsp. GstarCAD must be closed.

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
if (-not $SourceDir) { $SourceDir = Join-Path $repoRoot "work\xref-collect-test\source_260929" }
$stamp = Get-Date -Format "yyMMdd_HHmmss"
if (-not $OutputRoot) { $OutputRoot = Join-Path $repoRoot "tmp\xref-collect-test\$stamp" }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
if (Get-Process -Name gcad -ErrorAction SilentlyContinue) { throw "GstarCAD is open. Save and close it before running this test." }

$sourceFull = (Resolve-Path -LiteralPath $SourceDir).Path
$workRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot "work")) + "\"
if (-not $sourceFull.StartsWith($workRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw "SourceDir must be a copy under work\: $sourceFull"
}
$files = @(Get-ChildItem -LiteralPath $sourceFull -File -Filter "*.dwg" | Sort-Object Name)
if ($files.Count -eq 0) { throw "No DWG in $sourceFull" }
$before = @{}
foreach ($f in $files) { $before[$f.FullName] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash }

$templateCandidates = @(
  (Join-Path $env:LOCALAPPDATA "Gstarsoft\GstarMechStd\R24\ko-KR\Template\gcadiso.dwt"),
  (Join-Path $env:LOCALAPPDATA "Gstarsoft\GstarMechStd\R24\ko-KR\Template\gm_iso.dwt")
)
$template = $templateCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $template) { throw "No GstarCAD Mechanical template found." }
# Open a copy of the template, so the template itself can never be saved over.
$startDwg = Join-Path $OutputRoot "collect_start.dwt"
Copy-Item -LiteralPath $template -Destination $startDwg -Force

# The DWG list is written by the picker helper itself, in both encodings.
$helper = Join-Path $repoRoot "apps\swcad-workflow\swcad_pick_dwgs.ps1"
$listBase = Join-Path $OutputRoot "collect_list"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $helper -OutputPath $listBase -TestPaths (($files | ForEach-Object { $_.FullName }) -join "|")
if (-not (Test-Path -LiteralPath "$listBase.utf8.txt")) { throw "Picker helper wrote no list." }

# A paper-space sheet in a folder and file with Korean names ("hangul"), for the
# conversion of such paths.
$hangul = -join ([char[]](0xD55C, 0xAE00))
$paperSource = $files | Where-Object { $_.Name -like "01-03-00-00*" } | Select-Object -First 1
if (-not $paperSource) { throw "The paper-space test sheet 01-03-00-00_* is missing in $sourceFull" }
$koreanDir = Join-Path $OutputRoot ($hangul + " source")
New-Item -ItemType Directory -Force -Path $koreanDir | Out-Null
$koreanFile = Join-Path $koreanDir ($paperSource.BaseName + " " + $hangul + $paperSource.Extension)
Copy-Item -LiteralPath $paperSource.FullName -Destination $koreanFile -Force
$koreanHash = (Get-FileHash -LiteralPath $koreanFile -Algorithm SHA256).Hash
$koreanListBase = Join-Path $OutputRoot "korean_list"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $helper -OutputPath $koreanListBase -TestPaths $koreanFile
if (-not (Test-Path -LiteralPath "$koreanListBase.utf8.txt")) { throw "Picker helper wrote no Korean list." }

# A drawing whose model space and layouts are empty: it cannot be converted.
$emptyDwg = Join-Path $OutputRoot "collect_empty.dwg"
Copy-Item -LiteralPath $template -Destination $emptyDwg -Force
$convertRoot = Join-Path $OutputRoot "converted"
New-Item -ItemType Directory -Force -Path $convertRoot | Out-Null

$log = Join-Path $OutputRoot "collect_probe.log"
$scr = Join-Path $OutputRoot "collect_probe.scr"
$workCopyPath = ""
if ($WorkCopy) {
  $workDir = Join-Path $repoRoot "work\xref-collect-test\$stamp"
  New-Item -ItemType Directory -Force -Path $workDir | Out-Null
  $workCopyPath = Join-Path $workDir "collect_host.dwg"
}
$lines = @(
  "(setenv `"SWT_COLLECT_LOG`" `"" + $log.Replace('\', '/') + "`")",
  "(setenv `"SWT_COLLECT_LOADER`" `"" + (Join-Path $repoRoot "apps\swcad-workflow\swcad_workflow_load.lsp").Replace('\', '/') + "`")",
  "(setenv `"SWT_COLLECT_LIST`" `"" + $listBase.Replace('\', '/') + "`")",
  "(setenv `"SWT_COLLECT_KOREAN_LIST`" `"" + $koreanListBase.Replace('\', '/') + "`")",
  "(setenv `"SWT_COLLECT_EMPTY`" `"" + $emptyDwg.Replace('\', '/') + "`")",
  "(setenv `"SWT_COLLECT_CONVERT_ROOT`" `"" + $convertRoot.Replace('\', '/') + "`")",
  "(setenv `"SWT_COLLECT_WORKCOPY`" `"" + $workCopyPath.Replace('\', '/') + "`")",
  "(load `"" + (Join-Path $PSScriptRoot "xref_collect_probe.lsp").Replace('\', '/') + "`")",
  "(swt-c-finish)"
)
[IO.File]::WriteAllLines($scr, $lines, [Text.UTF8Encoding]::new($false))
$runner = Join-Path $repoRoot "diagnostics\gmtitle-main45\run_readonly_probe.ps1"
$null = & $runner -DwgPath $startDwg -ScriptPath $scr -LogPath $log -CompletionPattern "Collect probe completed: yes" -TimeoutSeconds $TimeoutSeconds -WindowStyle Minimized

$changed = @($files | Where-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash -ne $before[$_.FullName] })
if ((Get-FileHash -LiteralPath $koreanFile -Algorithm SHA256).Hash -ne $koreanHash) { $changed += $koreanFile }
Write-Output ("Source DWGs unchanged: {0} of {1}" -f ($files.Count + 1 - $changed.Count), ($files.Count + 1))
$convertedFiles = @(Get-ChildItem -LiteralPath $convertRoot -Recurse -File -Filter "*.dwg")
Write-Output ("Converted copies: {0} in {1}" -f $convertedFiles.Count, $convertRoot)
if (-not (Test-Path -LiteralPath $log)) { throw "The probe wrote no log: $log" }
$bytes = [IO.File]::ReadAllBytes($log)
$enc = [Text.Encoding]::GetEncoding(949)
try { $null = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($bytes); $enc = [Text.Encoding]::UTF8 } catch {}
$text = $enc.GetString($bytes) -split "`r?`n"
$ok = @($text | Where-Object { $_ -like "UNIT_OK*" }).Count
$failed = @($text | Where-Object { $_ -like "UNIT_FAIL*" })
$text | Where-Object { $_ -notlike "UNIT_OK*" -and $_ -notlike "XREF|*" }
Write-Output ("Unit checks: {0} (failed {1})" -f ($ok + $failed.Count), $failed.Count)
if ($WorkCopy) { Write-Output "Work copy: $workCopyPath" }
if ($failed.Count -gt 0 -or $changed.Count -gt 0 -or -not ($text -contains "Main part completed: yes") -or -not ($text -contains "Collect probe completed: yes")) { Write-Output "RESULT: CHECK NEEDED"; exit 1 }
Write-Output "RESULT: OK"
