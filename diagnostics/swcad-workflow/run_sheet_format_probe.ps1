param(
  # A bound COLLECT work copy (after the XREF step), e.g.
  # work\xref-collect-test\<stamp>\collect_host.dwg.  Only a copy is opened.
  [Parameter(Mandatory = $true)][string]$HostDwg,
  [ValidateSet("RECOGNIZE", "APPLY")][string]$Mode = "RECOGNIZE",
  [ValidateSet("OK", "STOP")][string]$Expect = "OK",
  # Stand-in for the GstarCAD Format folder in the DR frame file check.  With
  # -TestA0Frame a folder is made with the installed DR frames plus a copy of
  # DR_A1_Outline.dwg named DR_A0_Outline.dwg (file check only).
  [string]$FrameDir,
  [switch]$TestA0Frame,
  [int]$TimeoutSeconds = 600
)

# SWCADRUN SHEET_FORMAT test in GstarCAD /b.  GstarCAD must be closed.

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
if (Get-Process -Name gcad -ErrorAction SilentlyContinue) { throw "GstarCAD is open. Save and close it before running this test." }
$stamp = Get-Date -Format "yyMMdd_HHmmss"
$outputRoot = Join-Path $repoRoot "tmp\sheet-format-test\$stamp"
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
# The work copy must sit under work\ (the workflow changes only work copies).
$workDir = Join-Path $repoRoot "work\sheet-format-test\$stamp"
New-Item -ItemType Directory -Force -Path $workDir | Out-Null
$workDwg = Join-Path $workDir "host.dwg"
$hostFull = (Resolve-Path -LiteralPath $HostDwg).Path
$hostHash = (Get-FileHash -LiteralPath $hostFull -Algorithm SHA256).Hash
Copy-Item -LiteralPath $hostFull -Destination $workDwg -Force

if ($TestA0Frame) {
  $format = "C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format"
  $FrameDir = Join-Path $outputRoot "frames"
  New-Item -ItemType Directory -Force -Path $FrameDir | Out-Null
  foreach ($size in 1..4) { Copy-Item -LiteralPath (Join-Path $format "DR_A$($size)_Outline.dwg") -Destination $FrameDir }
  Copy-Item -LiteralPath (Join-Path $format "DR_A1_Outline.dwg") -Destination (Join-Path $FrameDir "DR_A0_Outline.dwg")
}

$log = Join-Path $outputRoot "sheet_format_probe.log"
$scr = Join-Path $outputRoot "sheet_format_probe.scr"
$lines = @(
  "(setenv `"SWT_SF_LOG`" `"" + $log.Replace('\', '/') + "`")",
  "(setenv `"SWT_SF_LOADER`" `"" + (Join-Path $repoRoot "apps\swcad-workflow\swcad_workflow_load.lsp").Replace('\', '/') + "`")",
  "(setenv `"SWT_SF_MODE`" `"$Mode`")",
  "(setenv `"SWT_SF_EXPECT`" `"$Expect`")",
  "(setenv `"SWT_SF_FRAME_DIR`" `"" + $(if ($FrameDir) { $FrameDir.Replace('\', '/') } else { "" }) + "`")",
  "(load `"" + (Join-Path $PSScriptRoot "sheet_format_probe.lsp").Replace('\', '/') + "`")",
  "(swt-sf-main)"
)
[IO.File]::WriteAllLines($scr, $lines, [Text.UTF8Encoding]::new($false))
$runner = Join-Path $repoRoot "diagnostics\gmtitle-main45\run_readonly_probe.ps1"
$null = & $runner -DwgPath $workDwg -ScriptPath $scr -LogPath $log -CompletionPattern "Sheet format probe completed: yes" -TimeoutSeconds $TimeoutSeconds -WindowStyle Minimized

if (-not (Test-Path -LiteralPath $log)) { throw "The probe wrote no log: $log" }
$bytes = [IO.File]::ReadAllBytes($log)
$enc = [Text.Encoding]::GetEncoding(949)
try { $null = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($bytes); $enc = [Text.Encoding]::UTF8 } catch {}
$text = $enc.GetString($bytes) -split "`r?`n"
$text | Where-Object { $_ -notlike "UNIT_OK*" }
$ok = @($text | Where-Object { $_ -like "UNIT_OK*" }).Count
$failed = @($text | Where-Object { $_ -like "UNIT_FAIL*" })
Write-Output ("Unit checks: {0} (failed {1})" -f ($ok + $failed.Count), $failed.Count)
$hostSame = (Get-FileHash -LiteralPath $hostFull -Algorithm SHA256).Hash -eq $hostHash
Write-Output ("Host drawing unchanged: {0}" -f $hostSame)
Write-Output ("Work copy: {0}" -f $workDwg)
$swfmtLog = Join-Path $repoRoot "work\swcad_sheet_format_last.txt"
if ($Mode -eq "APPLY" -and (Test-Path -LiteralPath $swfmtLog)) { Copy-Item -LiteralPath $swfmtLog -Destination $outputRoot }
if ($failed.Count -gt 0 -or -not $hostSame -or -not ($text -contains "Sheet format probe completed: yes")) { Write-Output "RESULT: CHECK NEEDED"; exit 1 }
Write-Output "RESULT: OK"
