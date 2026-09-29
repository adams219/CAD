param(
  [Parameter(Mandatory = $true)][string]$OutputRoot,
  [string]$Today = (Get-Date -Format "yyyy-MM-dd")
)

# Summarizes a run of run_title_value_test.ps1 from its logs; no CAD needed.
#   plan.log     source title data and the 11 planned values per source sheet
#   write.log    unit checks and the read-back of the planned values
#   e2e_dump.log converted DR_titlea_3rd titles (optional, -EndToEnd)
#   verify_*.log SWTITLEVERIFY final summary of other drawings (optional)
# Exit code 1 when anything unexpected is found.

$ErrorActionPreference = "Stop"
$tags = @("NR{23}", "DWG{23}", "NAME{10}", "DATE{11.7}", "CHKM{10}", "APPM{21.7}", "SCA{6.7}", "REV{5}", "SIZ{6.7}", "QTY{10}", "MAT1{10}")
$problems = 0

function Read-Lines([string]$Path) {
  $bytes = [IO.File]::ReadAllBytes($Path)
  $enc = [Text.Encoding]::GetEncoding(949)
  try { $null = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($bytes); $enc = [Text.Encoding]::UTF8 } catch {}
  return ($enc.GetString($bytes) -split "`r?`n")
}

# ---- plan ----
$planPath = Join-Path $OutputRoot "plan.log"
$sheets = [ordered]@{}
$defaultsBlock = ""
$blockDefaults = @{}
$login = ""
foreach ($l in (Read-Lines $planPath)) {
  $f = $l.Split("|")
  switch ($f[0]) {
    "DEFAULTS_BLOCK" { $defaultsBlock = $f[1] }
    "DEFAULT" { $blockDefaults[$f[1] -replace '^GEN-TITLE-', ''] = $f[2] }
    "LOGIN" { $login = $f[1] }
    "SHEET" {
      $stem = ($f[3] -replace '^.*?\$0\$(?=[^$]*\$0\$[^$]*$)', '') -replace '\$0\$.*$', ''
      $point = if ($f[8] -match '^\(([-\d\.]+), ([-\d\.]+)\)') { @([double]$matches[1], [double]$matches[2]) } else { @(0.0, 0.0) }
      $sheets[$f[1]] = @{ Index = [int]$f[1]; Stem = $stem; Kind = $f[4]; Frame = $f[6]; OldFrame = $f[7]; Point = $point; Attr = @{}; Mapped = @{}; Texts = @(); Old = @{}; Final = @{}; Origin = @{} }
    }
    "SRCATTR" { $sheets[$f[1]].Attr[$f[2] -replace '^GEN-TITLE-', ''] = $f[3].Trim() }
    "SRCTEXT" {
      $s = $sheets[$f[1]]
      $s.Texts += [pscustomobject]@{ Status = $f[5]; Type = $f[3]; Point = $f[4]; Raw = $f[6]; Plain = $f[7] }
      if ($f[5] -like "MAPPED:*") { $s.Mapped[$f[5].Substring(7) -replace '^GEN-TITLE-', ''] = $f[7] }
    }
    "OLD" { $sheets[$f[1]].Old[$f[2] -replace '^GEN-TITLE-', ''] = $f[3] }
    "FINAL" {
      $sheets[$f[1]].Final[$f[2] -replace '^GEN-TITLE-', ''] = $f[3]
      $sheets[$f[1]].Origin[$f[2] -replace '^GEN-TITLE-', ''] = $f[4]
    }
  }
}
$fieldCount = $sheets.Count * 11
"== Plan: $($sheets.Count) source sheets, $fieldCount fields (defaults from $defaultsBlock)"
$frameChanges = @($sheets.Values | Where-Object { $_.Frame -ne $_.OldFrame }).Count
"  target frame changed vs previous version: $frameChanges"
if ($frameChanges -gt 0) { $problems++ }
$kinds = $sheets.Values | Group-Object { $_.Kind } | ForEach-Object { "{0} {1}" -f $_.Count, $_.Name }
"  source kinds: " + ($kinds -join ", ") + "; with GEN-TITLE attributes: " + @($sheets.Values | Where-Object { $_.Attr.Count -gt 0 }).Count

function Get-SourceValue($s, $t) {
  if ($s.Attr.ContainsKey($t)) { return $s.Attr[$t] }
  if ($s.Mapped.ContainsKey($t)) { return $s.Mapped[$t] }
  return ""
}
$withSource = 0; $newDiff = @{}; $unexpected = 0; $emptyDefaults = @{}
$oldDiff = @{}
foreach ($s in $sheets.Values) {
  foreach ($t in $tags) {
    $src = Get-SourceValue $s $t
    $new = $s.Final[$t]
    if ($src -eq "") {
      $key = "{0} -> [{1}]" -f ($t -replace '\{.*$', ''), $new
      $emptyDefaults[$key] = 1 + [int]$emptyDefaults[$key]
      continue
    }
    $withSource++
    if ($new -ne $src) {
      $reason =
        if ($t -eq "NR{23}" -and $src.ToUpperInvariant() -eq "XXX") { "GMTITLE placeholder XXX -> empty" }
        elseif ($t -eq "DWG{23}" -and $src -match '^[A-Za-z]:[\\/]') { "file path -> empty" }
        elseif ($t -eq "DATE{11.7}" -and $src -match '-00(-|$)') { "placeholder date -> today" }
        elseif ($t -eq "SIZ{6.7}") { "sheet size from the frame" }
        elseif ($t -eq "APPM{21.7}" -and $src -like "*/*") { "approver/date split (existing rule)" }
        else { "UNEXPECTED" }
      $newDiff[$reason] = 1 + [int]$newDiff[$reason]
      if ($reason -eq "UNEXPECTED") { $unexpected++; "  UNEXPECTED sheet {0} {1} {2}: source=[{3}] new=[{4}]" -f $s.Index, $s.Stem, $t, $src, $new }
    }
    # Previous version: text values as found (format codes included) and GMTITLE's own
    # defaults for every field it did not write.
    $old =
      if ($s.Old.ContainsKey($t)) { $s.Old[$t] -replace '/', '|' }
      elseif ($s.Kind -eq "loose-text") { "" }
      elseif ($t -eq "NR{23}") { "XXX" }
      elseif ($t -eq "DWG{23}") { "<file path>" }
      elseif ($t -eq "NAME{10}") { $login }
      elseif ($t -eq "DATE{11.7}") { $Today }
      else { [string]$blockDefaults[$t] }
    if ($old -ne $src -and -not ($t -eq "SIZ{6.7}") -and -not ($t -eq "APPM{21.7}" -and $src -like "*/*")) {
      $label = if ($old -match '[{\\]') { "format code" } elseif ($old -eq "XXX") { "XXX" } elseif ($old -eq "<file path>") { "file path" } elseif ($t -eq "NAME{10}" -and $old -eq $login) { "login name $login" } elseif ($old -eq $Today) { "conversion date" } else { "other [$old]" }
      $k2 = "{0}: {1}" -f ($t -replace '\{.*$', ''), $label
      $oldDiff[$k2] = 1 + [int]$oldDiff[$k2]
    }
  }
}
if ($unexpected -gt 0) { $problems++ }
"  fields with a source value: $withSource, empty in the source: $($fieldCount - $withSource)"
"  new version, fields different from the source: " + (($newDiff.Values | Measure-Object -Sum).Sum) + " (unexpected $unexpected)"
$newDiff.GetEnumerator() | Sort-Object Name | ForEach-Object { "    {0}: {1}" -f $_.Name, $_.Value }
"  empty source field -> new value:"
$emptyDefaults.GetEnumerator() | Sort-Object Name | ForEach-Object { "    {0}: {1}" -f $_.Name, $_.Value }
"  previous version, fields different from the source: " + (($oldDiff.Values | Measure-Object -Sum).Sum)
$oldDiff.GetEnumerator() | Sort-Object Name | ForEach-Object { "    {0}: {1}" -f $_.Name, $_.Value }
$notWritten = @()
foreach ($s in $sheets.Values) { foreach ($x in ($s.Texts | Where-Object { $_.Status -ne "" -and $_.Status -notlike "MAPPED:*" })) { $notWritten += ("    sheet {0} {1} {2} {3} [{4}]" -f $s.Index, $s.Stem, $x.Status, $x.Point, $x.Raw) } }
"  source texts not written to the new title (deleted with the old title): $($notWritten.Count)"
$notWritten | Select-Object -First 30

# ---- write / read-back ----
$writePath = Join-Path $OutputRoot "write.log"
if (Test-Path -LiteralPath $writePath) {
  $units = 0; $unitFail = 0; $readback = 0; $readDiff = 0; $verifyErrors = $null
  foreach ($l in (Read-Lines $writePath)) {
    $f = $l.Split("|")
    if ($f[0] -like "UNIT_*") { $units++; if ($f[0] -eq "UNIT_FAIL") { $unitFail++; "  UNIT_FAIL $($f[1]): actual=[$($f[2])] expected=[$($f[3])]" } }
    if ($f[0] -eq "READBACK") { $readback++; if ($sheets[$f[1]].Final[$f[2] -replace '^GEN-TITLE-', ''] -ne $f[3]) { $readDiff++; "  READBACK sheet $($f[1]) $($f[2]): [$($f[3])]" } }
    if ($f[0] -eq "TOTAL_ERRORS") { $verifyErrors = [int]$f[1] }
  }
  "== Write: unit checks $units (failed $unitFail), read-back fields $readback (different from plan $readDiff), verification errors $verifyErrors"
  if ($unitFail -gt 0 -or $readDiff -gt 0 -or $verifyErrors -ne 0 -or $readback -ne $fieldCount) { $problems++ }
}

# ---- end to end ----
$dumpPath = Join-Path $OutputRoot "e2e_dump.log"
if (Test-Path -LiteralPath $dumpPath) {
  $titles = @(); $attrs = @{}
  foreach ($l in (Read-Lines $dumpPath)) {
    $f = $l.Split("|")
    if ($f[0] -eq "TITLE") { $p = $f[2].Split(","); $titles += [pscustomobject]@{ Handle = $f[1]; X = [double]$p[0]; Y = [double]$p[1] } }
    if ($f[0] -eq "ATTR") { $attrs["$($f[1])|$($f[2])"] = ($l.Split("|", 4))[3] }
  }
  $matched = @{}; $compared = 0; $e2eDiff = 0; $unmatched = 0
  foreach ($t in $titles) {
    $best = $null; $bestDist = [double]::MaxValue
    foreach ($s in $sheets.Values) {
      $d = [Math]::Sqrt([Math]::Pow($s.Point[0] - $t.X, 2) + [Math]::Pow($s.Point[1] - $t.Y, 2))
      if ($d -lt $bestDist) { $bestDist = $d; $best = $s }
    }
    if (-not $best -or $bestDist -gt 50 -or $matched.ContainsKey($best.Index)) { $unmatched++; "  UNMATCHED title $($t.Handle)"; continue }
    $matched[$best.Index] = $t.Handle
    foreach ($tag in $tags) {
      $compared++
      $actual = $attrs["$($t.Handle)|GEN-TITLE-$tag"]
      if ($actual -ne $best.Final[$tag]) { $e2eDiff++; "  E2E sheet {0} {1} {2}: plan=[{3}] drawing=[{4}]" -f $best.Index, $best.Stem, $tag, $best.Final[$tag], $actual }
    }
  }
  "== End to end: converted titles $($titles.Count), matched $($matched.Count), fields compared $compared, different from plan $e2eDiff"
  if ($unmatched -gt 0 -or $e2eDiff -gt 0 -or $matched.Count -ne $sheets.Count) { $problems++ }
}
$driverPath = Join-Path $OutputRoot "e2e_driver.log"
if (Test-Path -LiteralPath $driverPath) {
  "  driver: " + ((Read-Lines $driverPath | Where-Object { $_ -match 'run \d+:|stopped|finished|complete|source unchanged' }) -join " / ")
}

# ---- full workflow ----
$finalPath = Join-Path $OutputRoot "final_verify.log"
if (Test-Path -LiteralPath $finalPath) {
  $final = @(Read-Lines $finalPath | Where-Object { $_ -match '^[A-Z]+\|' })
  "== Full workflow: " + ($final -join " / ")
  if (-not ($final -contains "SWCADVERIFY|SWCADVERIFY_FINAL_OK")) { $problems++ }
}

# ---- other drawings ----
foreach ($v in (Get-ChildItem -LiteralPath $OutputRoot -Filter "verify_*.log" -File)) {
  $lines = Read-Lines $v.FullName
  $status = ($lines | Where-Object { $_ -like "STATUS|*" } | Select-Object -First 1)
  $code = ($lines | Where-Object { $_ -like "RESULT_CODE|*" } | Select-Object -First 1)
  $probs = @($lines | Where-Object { $_ -like "PROBLEM|*" })
  $titlesWith = @($probs | ForEach-Object { $_.Split("|")[1] } | Sort-Object -Unique).Count
  $byReason = $probs | ForEach-Object { ($_ -split '\|')[-1] } | Group-Object | ForEach-Object { "{0} {1}" -f $_.Count, $_.Name }
  "== Verify {0}: {1}, {2}, titles with value problems {3} ({4})" -f $v.BaseName, $status, $code, $titlesWith, ($byReason -join ", ")
}

if ($problems -gt 0) { "RESULT: CHECK NEEDED ($problems)"; exit 1 } else { "RESULT: OK" }
