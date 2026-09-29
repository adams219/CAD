param(
  [Parameter(Mandatory = $true)]
  [string]$OutputRoot
)

# Compares the BEFORE / AFTER / AFTER2 records written by swauto_value_probe.lsp.
# The displayed number comes from the text GstarCAD draws in each dimension block,
# so this check does not depend on how the module describes its own changes.

$ErrorActionPreference = "Stop"

function Get-DisplayTokens {
  param([string]$Text)
  $t = $Text
  $t = [regex]::Replace($t, '\\[ACcFfHhQTWp][^;]*;', ' ')
  $t = [regex]::Replace($t, '\\S([^;^/#]*)[\^/#]([^;]*);', ' $1 $2 ')
  $t = [regex]::Replace($t, '\\U\+[0-9A-Fa-f]{4}', ' ')
  $t = [regex]::Replace($t, '\\[LlOoKkPX~]', ' ')
  $t = [regex]::Replace($t, '%%[cCdDpP]', ' ')
  $t = [regex]::Replace($t, '[{}\[\]]', ' ')
  $tokens = @()
  foreach ($m in [regex]::Matches($t, '[-+]?(?:\d+(?:\.\d+)?|\.\d+)')) { $tokens += $m.Value }
  return ,$tokens
}

function Get-DisplayNumbers {
  param([string]$Text)
  $values = @()
  foreach ($token in (Get-DisplayTokens $Text)) {
    $values += [double]::Parse($token, [Globalization.CultureInfo]::InvariantCulture)
  }
  return ,$values
}

function Get-Decimals {
  param([string]$Token)
  $dot = $Token.IndexOf(".")
  if ($dot -lt 0) { return 0 }
  return $Token.Length - $dot - 1
}

# True when $Shown is $Value rounded to the decimals printed in $ShownToken.
function Test-RoundedTo {
  param([double]$Value, [double]$Shown, [string]$ShownToken)
  $decimals = Get-Decimals $ShownToken
  return ([math]::Abs([math]::Round($Value, $decimals, [MidpointRounding]::AwayFromZero) - $Shown) -le 1e-9)
}

function Get-Number {
  param([string]$Text)
  if (($Text -eq "nil") -or ($Text -eq "")) { return $null }
  $value = 0.0
  if ([double]::TryParse($Text, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) { return $value }
  return $null
}

function Test-Same {
  param($Left, $Right)
  if (($null -eq $Left) -and ($null -eq $Right)) { return $true }
  if (($null -eq $Left) -or ($null -eq $Right)) { return $false }
  return ([math]::Abs($Left - $Right) -le (1e-6 * [math]::Max(1.0, [math]::Abs($Left))))
}

# Checks the Mechanical fit stack text against the dimension's own tolerance values.
# Shown upper must be +DIMTP and shown lower must be -DIMTM. Returns $null without a stack.
function Test-FitStack {
  param($Record)
  $text = $Record.Override
  $upper = $null; $lower = $null
  $m = [regex]::Match($text, '([+-]?)\\S([^;^]*)\^([^;]*);')
  if (-not $m.Success) { return $null }
  $outer = $m.Groups[1].Value; $a = $m.Groups[2].Value.Trim(); $b = $m.Groups[3].Value.Trim()
  $inv = [Globalization.CultureInfo]::InvariantCulture
  $av = 0.0; $bv = 0.0
  if (-not [double]::TryParse($a, [Globalization.NumberStyles]::Float, $inv, [ref]$av)) { return $null }
  if (-not [double]::TryParse($b, [Globalization.NumberStyles]::Float, $inv, [ref]$bv)) { return $null }
  if (($outer -eq "-") -and ($av -eq 0)) { $upper = 0.0; $lower = -[math]::Abs($bv) }
  elseif (($outer -eq "+") -and ($bv -eq 0)) { $upper = [math]::Abs($av); $lower = 0.0 }
  else { $upper = $av; $lower = $bv }
  $expectedUpper = if ($null -ne $Record.Dimtp) { $Record.Dimtp } else { 0.0 }
  $expectedLower = if ($null -ne $Record.Dimtm) { -$Record.Dimtm } else { 0.0 }
  return ((Test-Same $upper $expectedUpper) -and (Test-Same $lower $expectedLower))
}

function Read-Records {
  param([string]$LogPath)
  $sets = @{}
  foreach ($line in [IO.File]::ReadAllLines($LogPath)) {
    if (-not $line.StartsWith("REC|")) { continue }
    $f = $line.Split("|")
    if ($f.Count -lt 17) { continue }
    $record = [pscustomobject]@{
      Handle = $f[2]; Style = $f[3]
      Dimlfac = Get-Number $f[4]; Dimtol = Get-Number $f[5]; Dimlim = Get-Number $f[6]
      Dimtp = Get-Number $f[7]; Dimtm = Get-Number $f[8]
      Measurement = Get-Number $f[9]; Dxf42 = Get-Number $f[10]; Geometric = Get-Number $f[11]
      Dimdec = Get-Number $f[12]; Dimzin = Get-Number $f[13]
      Fit = $f[14].Trim(); Override = $f[15]; Display = $f[16]
      Numbers = Get-DisplayNumbers $f[16]
      Tokens = Get-DisplayTokens $f[16]
    }
    if (-not $sets.ContainsKey($f[1])) { $sets[$f[1]] = @{} }
    $sets[$f[1]][$f[2]] = $record
  }
  return $sets
}

function Compare-Sets {
  param($Before, $After)
  $result = [pscustomobject]@{
    Total = 0; Missing = 0; NoDisplay = 0; MainChanged = 0; MainRounded = 0; OtherNumbersChanged = 0
    DimlfacChanged = 0; ToleranceValueChanged = 0; ToleranceFlagChanged = 0; FitConverted = 0
    Examples = New-Object System.Collections.Generic.List[string]
  }
  foreach ($handle in $Before.Keys) {
    $b = $Before[$handle]
    $result.Total += 1
    if (-not $After.ContainsKey($handle)) { $result.Missing += 1; continue }
    $a = $After[$handle]
    $fitAfter = $a.Fit -ne ""
    if ($fitAfter -and ($b.Fit -eq "")) { $result.FitConverted += 1 }
    if (-not (Test-Same $b.Dimlfac $a.Dimlfac)) { $result.DimlfacChanged += 1 }
    if ((-not (Test-Same $b.Dimtp $a.Dimtp)) -or (-not (Test-Same $b.Dimtm $a.Dimtm))) { $result.ToleranceValueChanged += 1 }
    if ((-not (Test-Same $b.Dimtol $a.Dimtol)) -or (-not (Test-Same $b.Dimlim $a.Dimlim))) { $result.ToleranceFlagChanged += 1 }
    if (($b.Numbers.Count -eq 0) -or ($a.Numbers.Count -eq 0)) { $result.NoDisplay += 1; continue }
    if (-not (Test-Same $b.Numbers[0] $a.Numbers[0])) {
      $rounded = (Test-Same $b.Dimlfac $a.Dimlfac) -and (Test-RoundedTo $b.Numbers[0] $a.Numbers[0] $a.Tokens[0])
      if ($rounded) { $result.MainRounded += 1 } else { $result.MainChanged += 1 }
      if ($result.Examples.Count -lt 12) {
        $result.Examples.Add(("#{0} shown {1} -> {2} ({3}), DIMLFAC {4} -> {5}, DIMDEC {6} -> {7}, DIMZIN {8} -> {9}, style {10} -> {11}" -f $handle, $b.Tokens[0], $a.Tokens[0], $(if ($rounded) { "rounding" } else { "VALUE" }), $b.Dimlfac, $a.Dimlfac, $b.Dimdec, $a.Dimdec, $b.Dimzin, $a.Dimzin, $b.Style, $a.Style))
      }
    } elseif ((-not $fitAfter) -and (($b.Numbers -join ",") -ne ($a.Numbers -join ","))) {
      $result.OtherNumbersChanged += 1
      if ($result.Examples.Count -lt 12) {
        $result.Examples.Add(("#{0} numbers [{1}] -> [{2}]" -f $handle, ($b.Numbers -join " "), ($a.Numbers -join " ")))
      }
    }
  }
  return $result
}

$lines = New-Object System.Collections.Generic.List[string]
$manifest = Import-Csv -LiteralPath (Join-Path $OutputRoot "manifest.csv")
$measurementRatios = New-Object System.Collections.Generic.List[string]
$fitNominal = New-Object System.Collections.Generic.List[string]
# key "mode|BEFORE->AFTER" -> dims, value changed, rounding changed, other numbers, DIMLFAC changed, fit converted
$totals = @{}
# key "mode|fit-text-mismatch" -> ok, mismatch
$fitTotals = @{}

function Add-Totals {
  param([string]$Key, $Compare)
  if (-not $totals.ContainsKey($Key)) { $totals[$Key] = @(0, 0, 0, 0, 0, 0) }
  $t = $totals[$Key]
  $totals[$Key] = @(
    ($t[0] + $Compare.Total), ($t[1] + $Compare.MainChanged), ($t[2] + $Compare.MainRounded),
    ($t[3] + $Compare.OtherNumbersChanged), ($t[4] + $Compare.DimlfacChanged), ($t[5] + $Compare.FitConverted)
  )
}

foreach ($entry in $manifest) {
  $lines.Add("== $($entry.Case) [$($entry.Mode)] $([IO.Path]::GetFileName($entry.Source))")
  if ($entry.Completed -ne "True") { $lines.Add("  probe did not complete"); continue }
  $text = [IO.File]::ReadAllText($entry.Log)
  foreach ($m in [regex]::Matches($text, '(?m)^(Tab:.*|Dimensions:.*|Module version:.*|SWAUTO run \d:.*)$')) { $lines.Add("  " + $m.Value.Trim()) }
  $sets = Read-Records $entry.Log
  if (-not $sets.ContainsKey("BEFORE")) { $lines.Add("  no BEFORE records"); continue }
  foreach ($pair in @(@("BEFORE", "AFTER"), @("AFTER", "AFTER2"))) {
    if (-not $sets.ContainsKey($pair[1])) { continue }
    $c = Compare-Sets $sets[$pair[0]] $sets[$pair[1]]
    $lines.Add(("  {0}->{1}: dims {2}, shown VALUE changed {3}, shown rounding changed {4}, other numbers changed {5}, DIMLFAC changed {6}, tol values changed {7}, tol flags changed {8}, fit converted {9}, missing {10}, no display text {11}" -f $pair[0], $pair[1], $c.Total, $c.MainChanged, $c.MainRounded, $c.OtherNumbersChanged, $c.DimlfacChanged, $c.ToleranceValueChanged, $c.ToleranceFlagChanged, $c.FitConverted, $c.Missing, $c.NoDisplay))
    Add-Totals "$($entry.Mode)|$($pair[0])->$($pair[1])" $c
    foreach ($example in $c.Examples) { $lines.Add("    " + $example) }
  }
  if ($sets.ContainsKey("AFTER")) {
    $fitOk = 0; $fitBad = 0
    # Only fits converted in this run: older Mechanical dims keep fit-table text
    # while their DIMTP/DIMTM can still hold stale style values.
    foreach ($r in $sets["AFTER"].Values) {
      if ($r.Fit -eq "") { continue }
      $b = $sets["BEFORE"][$r.Handle]
      if (($null -eq $b) -or ($b.Fit -ne "")) { continue }
      $check = Test-FitStack $r
      if ($check -eq $true) { $fitOk += 1 }
      elseif ($check -eq $false) {
        $fitBad += 1
        $lines.Add(("    fit text mismatch #{0}: DIMTP {1} DIMTM {2} text {3}" -f $r.Handle, $r.Dimtp, $r.Dimtm, [regex]::Match($r.Override, '[+-]?\\S[^;]*;').Value))
      }
    }
    $lines.Add(("  fit tolerance text vs DIMTP/DIMTM: ok {0}, mismatch {1}" -f $fitOk, $fitBad))
    $key = "$($entry.Mode)|fit-text-mismatch"
    if (-not $fitTotals.ContainsKey($key)) { $fitTotals[$key] = @(0, 0) }
    $fitTotals[$key] = @(($fitTotals[$key][0] + $fitOk), ($fitTotals[$key][1] + $fitBad))
  }
  # GstarCAD reports Measurement -1 for untouched SOLIDWORKS dimensions, so use AFTER.
  if (($entry.Mode -eq "new") -and $sets.ContainsKey("AFTER")) {
    foreach ($r in $sets["AFTER"].Values) {
      if (($null -ne $r.Dimlfac) -and (-not (Test-Same $r.Dimlfac 1.0)) -and ($null -ne $r.Geometric) -and ($r.Geometric -gt 1e-9) -and ($null -ne $r.Measurement) -and ($r.Measurement -gt 0)) {
        $measurementRatios.Add(("{0} #{1}: measurement/geometric = {2:0.######}, DIMLFAC {3}, shown {4}" -f $entry.Case, $r.Handle, ($r.Measurement / $r.Geometric), $r.Dimlfac, ($(if ($r.Numbers.Count -gt 0) { $r.Numbers[0] } else { "-" }))))
      }
    }
    if ($sets.ContainsKey("AFTER")) {
      foreach ($r in $sets["AFTER"].Values) {
        $nominalMatch = [regex]::Match($r.Fit, 'nominal=([-+0-9.eE]+)')
        if ($nominalMatch.Success -and ($r.Numbers.Count -gt 0)) {
          $nominal = Get-Number $nominalMatch.Groups[1].Value
          $state = if (Test-Same $nominal $r.Numbers[0]) { "same" } elseif (Test-RoundedTo $nominal $r.Numbers[0] $r.Tokens[0]) { "same after display rounding" } else { "DIFFERENT" }
          $fitNominal.Add(("{0} #{1}: fit nominal {2} vs shown {3} ({4}), DIMLFAC {5}" -f $entry.Case, $r.Handle, $nominal, $r.Tokens[0], $state, $r.Dimlfac))
        }
      }
    }
  }
}

$lines.Add("")
$lines.Add("== Totals (dims / shown VALUE changed / shown rounding changed / other numbers changed / DIMLFAC changed / fit converted)")
foreach ($key in ($totals.Keys | Sort-Object)) {
  $lines.Add(("  {0}: {1}" -f $key, ($totals[$key] -join " / ")))
}
foreach ($key in ($fitTotals.Keys | Sort-Object)) {
  $lines.Add(("  {0}: ok {1} / mismatch {2}" -f $key, $fitTotals[$key][0], $fitTotals[$key][1]))
}
$lines.Add("")
$lines.Add("== Measurement property vs geometry (dimensions with DIMLFAC <> 1, after SWAUTO)")
if ($measurementRatios.Count -eq 0) { $lines.Add("  none") } else { foreach ($l in $measurementRatios) { $lines.Add("  " + $l) } }
$lines.Add("")
$lines.Add("== Mechanical fit nominal size vs shown number (new module, after SWAUTO)")
if ($fitNominal.Count -eq 0) { $lines.Add("  none") } else { foreach ($l in $fitNominal) { $lines.Add("  " + $l) } }

$summaryPath = Join-Path $OutputRoot "summary.txt"
[IO.File]::WriteAllLines($summaryPath, $lines, [Text.UTF8Encoding]::new($false))
$lines
Write-Output ""
Write-Output "Summary: $summaryPath"
