param(
  [string]$OutputPath,

  [switch]$DeepRegistrySearch
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$workDir = Join-Path $repoRoot "work"
if (-not (Test-Path -LiteralPath $workDir)) {
  New-Item -ItemType Directory -Path $workDir | Out-Null
}

if (-not $OutputPath) {
  $OutputPath = Join-Path $workDir "swtitle_gmtitle_selection_config_probe_260705.txt"
}

$lines = New-Object System.Collections.Generic.List[string]
$selectionEvidence = New-Object System.Collections.Generic.List[string]

function Add-Line {
  param([string]$Line = "")
  [void]$lines.Add($Line)
}

function Read-TextWithFallback {
  param([string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $encodings = @(
    [System.Text.UTF8Encoding]::new($true, $true),
    [System.Text.Encoding]::GetEncoding(949),
    [System.Text.Encoding]::Default
  )

  foreach ($encoding in $encodings) {
    try {
      return $encoding.GetString($bytes)
    } catch {
    }
  }

  return [System.Text.Encoding]::Default.GetString($bytes)
}

function Add-TextFileSummary {
  param(
    [string]$Label,
    [string]$Path
  )

  Add-Line ("[{0}]" -f $Label)
  Add-Line ("Path: {0}" -f $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Add-Line "Status: missing"
    Add-Line
    return
  }

  $item = Get-Item -LiteralPath $Path
  if ($item.PSIsContainer) {
    Add-Line "Status: directory, skipped"
    Add-Line
    return
  }

  try {
    $text = Read-TextWithFallback -Path $Path
  } catch {
    Add-Line ("Status: unreadable, skipped ({0})" -f $_.Exception.Message)
    Add-Line
    return
  }

  $hits = @()
  foreach ($pattern in @("DR_A[0-4]_Outline", "DR_titlea_3rd", "DR_titlea", "GMTITLE", "PAPERSET", "PaperSet", "DrawWithBlock")) {
    $matches = [regex]::Matches($text, $pattern, "IgnoreCase") |
      ForEach-Object { $_.Value } |
      Sort-Object -Unique
    foreach ($match in $matches) {
      $hits += ("{0}={1}" -f $pattern, $match)
    }
  }

  Add-Line ("Status: exists, bytes={0}" -f $item.Length)
  if ($hits.Count -gt 0) {
    Add-Line ("Markers: {0}" -f ($hits -join "; "))
    if ($hits -match "DR_A[0-4]_Outline|DR_titlea_3rd") {
      [void]$selectionEvidence.Add($Label)
    }
  } else {
    Add-Line "Markers: <none>"
  }
  Add-Line
}

function Add-BinaryStringSummary {
  param(
    [string]$Label,
    [string]$Path
  )

  Add-Line ("[{0}]" -f $Label)
  Add-Line ("Path: {0}" -f $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Add-Line "Status: missing"
    Add-Line
    return
  }

  $item = Get-Item -LiteralPath $Path
  if ($item.PSIsContainer) {
    Add-Line "Status: directory, skipped"
    Add-Line
    return
  }

  try {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
  } catch {
    Add-Line ("Status: unreadable, skipped ({0})" -f $_.Exception.Message)
    Add-Line
    return
  }

  $latin1 = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)
  $patterns = "DR_[A-Za-z0-9_]+|DR[-_][A-Za-z0-9_]+|DR_titlea_3rd|DR_titlea|GMTITLE|GMSBLOCKE|HC_SBLOCKE|PAPERSET|PaperSet|DrawWithBlock|TitleBlockTotalMass|TitleScale|Frame|Object"
  $hits = [regex]::Matches($latin1, $patterns) |
    ForEach-Object { $_.Value } |
    Sort-Object -Unique

  Add-Line ("Status: exists, bytes={0}" -f $bytes.Length)
  if ($hits.Count -gt 0) {
    Add-Line ("ASCII markers: {0}" -f ($hits -join ", "))
    if ($hits -match "DR_A[0-4]_Outline|DR_titlea_3rd") {
      [void]$selectionEvidence.Add($Label)
    }
  } else {
    Add-Line "ASCII markers: <none>"
  }
  Add-Line
}

function Add-CuiCommandMapSummary {
  param([string]$Path)

  Add-Line "[CUI command translation map]"
  Add-Line ("Path: {0}" -f $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Add-Line "Status: missing"
    Add-Line
    return
  }

  try {
    [xml]$xml = Read-TextWithFallback -Path $Path
  } catch {
    Add-Line ("Status: unreadable, skipped ({0})" -f $_.Exception.Message)
    Add-Line
    return
  }

  $gmtitleItems = @($xml.SelectNodes("//Item[*[@command='GMTITLE']]"))
  if ($gmtitleItems.Count -gt 0) {
    foreach ($item in $gmtitleItems) {
      $ko = $item.SelectSingleNode("ko-kr")
      $en = $item.SelectSingleNode("en-us")
      Add-Line ("GMTITLE map: module={0}, top-command={1}, ko-command={2}, ko-name={3}, en-name={4}, short={5}, alt={6}" -f `
        $item.module, $item.command, $ko.command, $ko.name, $en.name, $ko.short, $item.alt)
      if ("$($item.command)" -match "(?i)imtitle") {
        Add-Line "GMTITLE map note: the ribbon/menu macro uses IMTITLE before the localized GMTITLE command name."
      }
    }
  } else {
    Add-Line "GMTITLE map: <none>"
  }

  $sblockItems = @($xml.SelectNodes("//Item[@module='PAPERSET' and @command='HC_SBLOCKE']"))
  if ($sblockItems.Count -gt 0) {
    foreach ($item in $sblockItems) {
      $ko = $item.SelectSingleNode("ko-kr")
      Add-Line ("PAPERSET edit map: internal-command={0}, user-command={1}" -f $item.command, $ko.command)
      Add-Line "PAPERSET edit map note: GMSBLOCKE is mapped to HC_SBLOCKE and appears related to super attribute block editing, not DR paper/title preselection."
    }
  } else {
    Add-Line "PAPERSET edit map: <none>"
  }

  Add-Line
}

function Add-PaperSetLanguageSummary {
  param([string]$Path)

  Add-Line "[PAPERSET dialog language labels]"
  Add-Line ("Path: {0}" -f $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Add-Line "Status: missing"
    Add-Line
    return
  }

  try {
    [xml]$xml = Read-TextWithFallback -Path $Path
  } catch {
    Add-Line ("Status: unreadable, skipped ({0})" -f $_.Exception.Message)
    Add-Line
    return
  }

  $dialogItems = @($xml.SelectNodes("//Module[@name='PAPERSET']/Catalog[@name='DIALOG']/Item"))
  if ($dialogItems.Count -gt 0) {
    foreach ($item in $dialogItems | Select-Object -First 3) {
      Add-Line ("Label: en-us={0}, ko-kr={1}" -f $item.'en-us', $item.'ko-kr')
    }
  } else {
    Add-Line "Labels: <none>"
  }

  Add-Line
}

function Add-CommandSurfaceLanguageSummary {
  param([string]$Path)

  Add-Line "[GMTITLE command/dialog language surface]"
  Add-Line ("Path: {0}" -f $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Add-Line "Status: missing"
    Add-Line
    return
  }

  try {
    [xml]$xml = Read-TextWithFallback -Path $Path
  } catch {
    Add-Line ("Status: unreadable, skipped ({0})" -f $_.Exception.Message)
    Add-Line
    return
  }

  $patterns = @(
    "Drawing Borders with Title Block",
    "Select title block automatically",
    "Automatic placement",
    "Select extension title blocks",
    "Select the drawing border",
    "Select the title border",
    "Frame and title block layers"
  )

  foreach ($pattern in $patterns) {
    $nodes = @($xml.SelectNodes("//Item[contains(translate(@en-us, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$($pattern.ToLowerInvariant())')]"))
    if ($nodes.Count -gt 0) {
      $node = $nodes[0]
      Add-Line ("Label hit: en-us={0}, ko-kr={1}" -f $node.'en-us', $node.'ko-kr')
    }
  }

  Add-Line "Command surface language note: these hits are labels/prompts, not a documented command-line preselection API for DR_A*_Outline / DR_titlea_3rd."
  Add-Line
}

function Add-TextTreeMarkerSummary {
  param(
    [string]$Label,
    [string]$Root
  )

  Add-Line ("[{0}]" -f $Label)
  Add-Line ("Root: {0}" -f $Root)
  if (-not $Root -or -not (Test-Path -LiteralPath $Root)) {
    Add-Line "Status: missing"
    Add-Line
    return
  }

  $extensions = @(".xml", ".ini", ".cfg", ".lsp", ".dcl", ".pgp", ".mnu", ".cui", ".cuix", ".txt", ".dat")
  $files = @(
    Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { ($extensions -contains $_.Extension.ToLowerInvariant()) -and ($_.Length -le 1048576) } |
      Select-Object -First 600
  )

  $hits = New-Object System.Collections.Generic.List[string]
  foreach ($file in $files) {
    try {
      $text = Read-TextWithFallback -Path $file.FullName
    } catch {
      continue
    }

    if ($text -match "DR_A[0-4]_Outline|DR_titlea_3rd|GMTITLE|IMTITLE|HC_SBLOCKE|GMSBLOCKE|PAPERSET") {
      $markers = [regex]::Matches($text, "DR_A[0-4]_Outline|DR_titlea_3rd|GMTITLE|IMTITLE|HC_SBLOCKE|GMSBLOCKE|PAPERSET", "IgnoreCase") |
        ForEach-Object { $_.Value } |
        Sort-Object -Unique
      [void]$hits.Add(("{0} :: {1}" -f $file.FullName, ($markers -join ", ")))
    }
  }

  Add-Line ("Files scanned: {0}" -f $files.Count)
  if ($hits.Count -gt 0) {
    foreach ($hit in $hits | Select-Object -First 20) {
      Add-Line ("  {0}" -f $hit)
    }
    if ($hits.Count -gt 20) {
      Add-Line ("  ... {0} more hit(s) omitted" -f ($hits.Count - 20))
    }
  } else {
    Add-Line "Markers: <none among readable scanned files>"
  }
  Add-Line "AppData text marker scan note: this broad scan is read-only and advisory; hits here must be inspected manually and are not treated as active preselection evidence by themselves."
  Add-Line
}

function Add-RegistryKeySummary {
  param(
    [string]$Label,
    [string]$Path
  )

  Add-Line ("[{0}]" -f $Label)
  Add-Line ("Path: {0}" -f $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Add-Line "Status: missing"
    Add-Line
    return
  }

  $item = Get-ItemProperty -LiteralPath $Path
  $propertyLines = @()
  foreach ($property in $item.PSObject.Properties) {
    if ($property.Name -in @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")) {
      continue
    }
    $propertyLines += ("{0}={1}" -f $property.Name, $property.Value)
    if (($property.Name -match "DR_A[0-4]_Outline|DR_titlea_3rd") -or ("$($property.Value)" -match "DR_A[0-4]_Outline|DR_titlea_3rd")) {
      [void]$selectionEvidence.Add($Label)
    }
  }

  if ($propertyLines.Count -gt 0) {
    foreach ($line in $propertyLines) {
      Add-Line ("  {0}" -f $line)
    }
  } else {
    Add-Line "  <no values>"
  }
  Add-Line
}

function Add-DeepRegistrySearchSummary {
  $root = "Registry::HKEY_CURRENT_USER\Software\Gstarsoft"
  Add-Line "[HKCU Gstarsoft deep DR marker search]"
  Add-Line ("Path: {0}" -f $root)
  if (-not (Test-Path -LiteralPath $root)) {
    Add-Line "Status: missing"
    Add-Line
    return
  }

  $hits = New-Object System.Collections.Generic.List[string]
  Get-ChildItem -LiteralPath $root -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $keyPath = $_.PSPath
    try {
      $props = Get-ItemProperty -LiteralPath $keyPath -ErrorAction Stop
      foreach ($property in $props.PSObject.Properties) {
        if ($property.Name -in @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")) {
          continue
        }
        $value = "$($property.Value)"
        if (($property.Name -match "DR_A[0-4]_Outline|DR_titlea_3rd") -or ($value -match "DR_A[0-4]_Outline|DR_titlea_3rd")) {
          [void]$hits.Add(("{0} :: {1}={2}" -f $keyPath.Replace("Microsoft.PowerShell.Core\Registry::", ""), $property.Name, $value))
        }
      }
    } catch {
    }
  }

  if ($hits.Count -gt 0) {
    foreach ($hit in $hits) {
      Add-Line ("  {0}" -f $hit)
    }
    $activeHits = @($hits | Where-Object { $_ -notmatch "(?i)Recent|File MRU|FileList" })
    if ($activeHits.Count -gt 0) {
      [void]$selectionEvidence.Add("HKCU deep search non-recent marker")
      Add-Line "Deep registry decision: non-recent DR marker(s) need manual review before any GMTITLE preselection automation."
    } else {
      Add-Line "Deep registry decision: DR markers were found only in recent-file history, so they are ignored as GMTITLE preselection evidence."
    }
  } else {
    Add-Line "  <none>"
  }
  Add-Line "Deep registry policy: only non-recent DR marker(s) are review evidence; recent-file history alone is ignored."
  Add-Line
}

Add-Line "----- GMTITLE selection config probe -----"
Add-Line ("Repo root: {0}" -f $repoRoot)
Add-Line ("Generated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Add-Line "Purpose: find persistent config evidence for preselecting DR_A*_Outline / DR_titlea_3rd before native GMTITLE."
Add-Line "No DWG is opened or changed."
Add-Line

$installRoot = "C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean"
Add-TextFileSummary -Label "Program PaperSet.ini" -Path (Join-Path $installRoot "MCADSetting\PaperSet.ini")
Add-TextFileSummary -Label "Program PaperSet.dat" -Path (Join-Path $installRoot "MCADSetting\PaperSet.dat")
Add-BinaryStringSummary -Label "Program PaperSet.grx ASCII string scan" -Path (Join-Path $installRoot "Professional\GRX8X64\PaperSet.grx")
Add-CuiCommandMapSummary -Path (Join-Path $installRoot "Common\ImCuiTranslate.xml")
Add-PaperSetLanguageSummary -Path (Join-Path $installRoot "Common\ImLanguage.xml")
Add-CommandSurfaceLanguageSummary -Path (Join-Path $installRoot "Common\ImLanguage.xml")

if ($env:APPDATA) {
  Add-TextFileSummary -Label "Roaming impro.ini" -Path (Join-Path $env:APPDATA "Gstarsoft\GstarMechStd\R24\ko-KR\Gcadm\MCADSetting\pro\impro.ini")
  Add-TextTreeMarkerSummary -Label "Roaming Gstarsoft text marker scan" -Root (Join-Path $env:APPDATA "Gstarsoft")
}
if ($env:LOCALAPPDATA) {
  Add-TextFileSummary -Label "Local gm_iso.dwt side config marker check" -Path (Join-Path $env:LOCALAPPDATA "Gstarsoft\GstarMechStd\R24\ko-KR\Template\gm_iso.dwt")
  Add-TextTreeMarkerSummary -Label "Local Gstarsoft text marker scan" -Root (Join-Path $env:LOCALAPPDATA "Gstarsoft")
}

Add-RegistryKeySummary -Label "HKCU PAPERSET dialog geometry key" -Path "Registry::HKEY_CURRENT_USER\Software\Gstarsoft\GstarMechStd\R24\ko-KR\Profiles\GstarMech2024Pro\Dialogs\PAPERSET.GRX-66"

if ($DeepRegistrySearch) {
  Add-DeepRegistrySearchSummary
} else {
  Add-Line "[HKCU Gstarsoft deep DR marker search]"
  Add-Line "Status: skipped by default. Re-run with -DeepRegistrySearch if you need to confirm Recent File List noise."
  Add-Line
}

Add-Line "Conclusion:"
if ($selectionEvidence.Count -gt 0) {
  Add-Line ("  Potential DR selection marker source(s): {0}" -f (($selectionEvidence | Sort-Object -Unique) -join ", "))
  Add-Line "  Treat these as evidence to inspect, not as proof that GMTITLE can be preselected safely."
  Add-Line "Result: GMTITLE_SELECTION_CONFIG_REVIEW_NEEDED"
} else {
  Add-Line "  No active persistent DR_A*_Outline / DR_titlea_3rd preselection config was found in the checked locations."
  Add-Line "  The CUI map exposes a ribbon/menu IMTITLE macro for the drawing title/border command, while GMSBLOCKE maps to PAPERSET super attribute block editing."
  Add-Line "  Direct GMTITLE may still reuse an internal/current command state and ask only for an insertion point."
  Add-Line "  Do not assume a scratch native A4 sample was created unless the saved DWG passes run_a4_native_exemplar_probe.ps1."
  Add-Line "Result: GMTITLE_SELECTION_CONFIG_NOT_FOUND"
}

[System.IO.File]::WriteAllText($OutputPath, ($lines -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
$lines | ForEach-Object { Write-Output $_ }
Write-Output ("GMTITLE selection config log: {0}" -f $OutputPath)
