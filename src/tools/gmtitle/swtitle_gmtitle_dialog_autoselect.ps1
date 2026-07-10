param(
  [int]$ProcessId,

  [long]$ApplicationWindowHandle,

  [string]$ExpectedDwgPath,

  [string]$SessionLogPath,

  [ValidatePattern('^DR_A[1-4]_Outline$')]
  [string]$ExpectedFrame = "DR_A3_Outline",

  [string]$ExpectedTitle = "DR_titlea_3rd",

  [int]$WaitSeconds = 60,

  [string]$LogPath,

  [switch]$ApplySelections,

  [switch]$ClickOk
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
$workDir = (Resolve-Path -LiteralPath (Join-Path $repoRoot "work")).Path
if (-not $LogPath) {
  $LogPath = Join-Path $workDir "swcad_title_gmtitle_autoselect_last.txt"
}

if ($ClickOk -and (-not $ApplySelections)) {
  throw "-ClickOk requires -ApplySelections."
}

if ($ApplySelections) {
  if (-not $ExpectedDwgPath) {
    throw "-ApplySelections requires -ExpectedDwgPath."
  }
  if (-not $SessionLogPath) {
    throw "-ApplySelections requires -SessionLogPath so the loaded DWG can be verified without relying on a modal window title."
  }
  $resolvedExpectedDwg = (Resolve-Path -LiteralPath $ExpectedDwgPath).Path
  $resolvedSessionLog = (Resolve-Path -LiteralPath $SessionLogPath).Path
  $workPrefix = $workDir.TrimEnd('\') + '\'
  if (-not $resolvedExpectedDwg.StartsWith($workPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Dialog automation is limited to dedicated DWG copies under work: $resolvedExpectedDwg"
  }
  if (-not $resolvedSessionLog.StartsWith($workPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Dialog automation requires a session log under work: $resolvedSessionLog"
  }
} else {
  $resolvedExpectedDwg = $null
  $resolvedSessionLog = $null
}

if (-not ("SwTitle.Win32" -as [type])) {
  Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace SwTitle {
  public static class Win32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(IntPtr parent, EnumWindowsProc callback, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern int GetDlgCtrlID(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetParent(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr hWnd, uint flags);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder className, int maxCount);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint message, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint message, IntPtr wParam, StringBuilder lParam);

    public static List<IntPtr> TopWindowsForProcess(uint processId) {
      var result = new List<IntPtr>();
      EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
        uint pid;
        GetWindowThreadProcessId(hWnd, out pid);
        if (pid == processId) result.Add(hWnd);
        return true;
      }, IntPtr.Zero);
      return result;
    }

    public static List<IntPtr> Descendants(IntPtr parent) {
      var result = new List<IntPtr>();
      EnumChildWindows(parent, delegate(IntPtr hWnd, IntPtr lParam) {
        result.Add(hWnd);
        return true;
      }, IntPtr.Zero);
      return result;
    }
  }
}
"@
}

$CB_GETCOUNT = 0x0146
$CB_GETCURSEL = 0x0147
$CB_GETLBTEXT = 0x0148
$CB_GETLBTEXTLEN = 0x0149
$CB_SETCURSEL = 0x014E
$BM_GETCHECK = 0x00F0
$BM_SETCHECK = 0x00F1
$BM_CLICK = 0x00F5
$BST_UNCHECKED = 0
$BST_CHECKED = 1
$WM_COMMAND = 0x0111
$CBN_SELCHANGE = 1
$GA_ROOT = 2

function Get-WindowTextValue {
  param([IntPtr]$Handle)

  $length = [SwTitle.Win32]::GetWindowTextLength($Handle)
  $buffer = [Text.StringBuilder]::new([Math]::Max(256, $length + 1))
  [void][SwTitle.Win32]::GetWindowText($Handle, $buffer, $buffer.Capacity)
  return $buffer.ToString()
}

function Get-WindowClassValue {
  param([IntPtr]$Handle)

  $buffer = [Text.StringBuilder]::new(256)
  [void][SwTitle.Win32]::GetClassName($Handle, $buffer, $buffer.Capacity)
  return $buffer.ToString()
}

function Get-AncestorHandles {
  param([IntPtr]$Handle)

  $result = @()
  $current = [SwTitle.Win32]::GetParent($Handle)
  $guard = 0
  while (($current -ne [IntPtr]::Zero) -and ($guard -lt 64)) {
    $result += $current
    $current = [SwTitle.Win32]::GetParent($current)
    $guard += 1
  }
  return $result
}

function Get-ComboItems {
  param([IntPtr]$Handle)

  $count = [SwTitle.Win32]::SendMessage($Handle, $CB_GETCOUNT, [IntPtr]::Zero, [IntPtr]::Zero).ToInt32()
  $items = @()
  for ($index = 0; $index -lt $count; $index++) {
    $length = [SwTitle.Win32]::SendMessage($Handle, $CB_GETLBTEXTLEN, [IntPtr]$index, [IntPtr]::Zero).ToInt32()
    if ($length -lt 0) { continue }
    $buffer = [Text.StringBuilder]::new($length + 1)
    [void][SwTitle.Win32]::SendMessage($Handle, $CB_GETLBTEXT, [IntPtr]$index, $buffer)
    $items += $buffer.ToString()
  }
  return $items
}

function Get-ComboState {
  param([IntPtr]$Handle)

  $items = @(Get-ComboItems -Handle $Handle)
  $selectedIndex = [SwTitle.Win32]::SendMessage($Handle, $CB_GETCURSEL, [IntPtr]::Zero, [IntPtr]::Zero).ToInt32()
  $selectedText = if (($selectedIndex -ge 0) -and ($selectedIndex -lt $items.Count)) { $items[$selectedIndex] } else { $null }
  return [pscustomobject]@{
    SelectedIndex = $selectedIndex
    SelectedText = $selectedText
    Items = $items
  }
}

function Set-ComboExactValue {
  param(
    [IntPtr]$Dialog,
    [IntPtr]$Control,
    [int]$ControlId,
    [string]$ExpectedValue
  )

  $items = @(Get-ComboItems -Handle $Control)
  $targetIndex = [Array]::IndexOf($items, $ExpectedValue)
  if ($targetIndex -lt 0) {
    throw "Combo ID $ControlId does not contain exact item '$ExpectedValue'. Items: $($items -join ', ')"
  }

  $setResult = [SwTitle.Win32]::SendMessage($Control, $CB_SETCURSEL, [IntPtr]$targetIndex, [IntPtr]::Zero).ToInt32()
  if ($setResult -ne $targetIndex) {
    throw "CB_SETCURSEL failed for control ID $ControlId. Expected index $targetIndex, result $setResult."
  }

  $commandWord = ($ControlId -band 0xFFFF) -bor (($CBN_SELCHANGE -band 0xFFFF) -shl 16)
  [void][SwTitle.Win32]::SendMessage($Dialog, $WM_COMMAND, [IntPtr]$commandWord, $Control)

  $state = Get-ComboState -Handle $Control
  if ($state.SelectedText -cne $ExpectedValue) {
    throw "Combo ID $ControlId readback mismatch. Expected '$ExpectedValue', got '$($state.SelectedText)'."
  }
  return $state
}

function Get-CheckState {
  param([IntPtr]$Handle)

  return [SwTitle.Win32]::SendMessage($Handle, $BM_GETCHECK, [IntPtr]::Zero, [IntPtr]::Zero).ToInt32()
}

function Set-CheckState {
  param(
    [IntPtr]$Handle,
    [bool]$Checked
  )

  $expected = if ($Checked) { $BST_CHECKED } else { $BST_UNCHECKED }
  $current = Get-CheckState -Handle $Handle
  if ($current -ne $expected) {
    [void][SwTitle.Win32]::SendMessage($Handle, $BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
  }
  $readback = Get-CheckState -Handle $Handle
  if ($readback -ne $expected) {
    [void][SwTitle.Win32]::SendMessage($Handle, $BM_SETCHECK, [IntPtr]$expected, [IntPtr]::Zero)
    $readback = Get-CheckState -Handle $Handle
  }
  if ($readback -ne $expected) {
    throw "Checkbox readback mismatch. Expected $expected, got $readback."
  }
  return $readback
}

function Find-GmtitleDialog {
  param([int[]]$CandidateProcessIds)

  $requiredIds = @(3010, 3011, 3022, 3024, 1)
  $candidates = @()

  foreach ($candidatePid in $CandidateProcessIds) {
    foreach ($top in [SwTitle.Win32]::TopWindowsForProcess([uint32]$candidatePid)) {
      $all = @($top) + @([SwTitle.Win32]::Descendants($top))
      $controls = @($all | Where-Object { [SwTitle.Win32]::GetDlgCtrlID($_) -in $requiredIds })
      foreach ($control in $controls) {
        foreach ($ancestor in @(Get-AncestorHandles -Handle $control)) {
          $ancestorChildren = @([SwTitle.Win32]::Descendants($ancestor))
          $byId = @{}
          foreach ($child in $ancestorChildren) {
            $id = [SwTitle.Win32]::GetDlgCtrlID($child)
            if (($id -in $requiredIds) -and (-not $byId.ContainsKey($id))) {
              $byId[$id] = $child
            }
          }
          if (@($requiredIds | Where-Object { -not $byId.ContainsKey($_) }).Count -eq 0) {
            $distance = 0
            foreach ($id in $requiredIds) {
              $parents = @(Get-AncestorHandles -Handle $byId[$id])
              $distance += [Array]::IndexOf($parents, $ancestor)
            }
            $key = $ancestor.ToInt64()
            if (-not ($candidates | Where-Object { $_.Key -eq $key })) {
              $candidates += [pscustomobject]@{
                Key = $key
                ProcessId = $candidatePid
                Dialog = $ancestor
                TopWindow = $top
                Controls = $byId
                Distance = $distance
                ClassName = Get-WindowClassValue -Handle $ancestor
                WindowText = Get-WindowTextValue -Handle $ancestor
              }
            }
          }
        }
      }
    }
  }

  return @($candidates | Sort-Object @{ Expression = { if ($_.ClassName -eq '#32770') { 0 } else { 1 } } }, Distance)
}

if ($ApplicationWindowHandle) {
  [uint32]$windowProcessId = 0
  [void][SwTitle.Win32]::GetWindowThreadProcessId([IntPtr]$ApplicationWindowHandle, [ref]$windowProcessId)
  if ($windowProcessId -eq 0) {
    throw "The supplied GstarCAD application HWND does not resolve to a process: $ApplicationWindowHandle"
  }
  if ($ProcessId -and ($ProcessId -ne [int]$windowProcessId)) {
    throw "Process ID and application HWND identify different processes: PID=$ProcessId HWND-PID=$windowProcessId"
  }
  $ProcessId = [int]$windowProcessId
}

$processes = if ($ProcessId) {
  @(Get-Process -Id $ProcessId -ErrorAction Stop)
} else {
  @(Get-Process -Name gcad -ErrorAction SilentlyContinue)
}
if ($processes.Count -eq 0) {
  throw "No running GstarCAD process was found."
}
if ($processes.Count -ne 1) {
  throw "Expected exactly one target GstarCAD process, found $($processes.Count). Supply -ApplicationWindowHandle."
}
if ($processes[0].ProcessName -ne "gcad") {
  throw "The selected process is not GstarCAD: $($processes[0].ProcessName)"
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
$dialogCandidates = @()
do {
  $dialogCandidates = @(Find-GmtitleDialog -CandidateProcessIds @($processes.Id))
  if ($dialogCandidates.Count -gt 0) { break }
  Start-Sleep -Milliseconds 500
} while ((Get-Date) -lt $deadline)

$logLines = [Collections.Generic.List[string]]::new()
$logLines.Add("SWTITLE GMTITLE dialog fixed-control probe")
$logLines.Add("Mode: " + $(if ($ApplySelections) { "apply" } else { "inspect-only" }))
$logLines.Add("Click OK: " + $(if ($ClickOk) { "yes" } else { "no" }))
$logLines.Add("Expected frame: $ExpectedFrame")
$logLines.Add("Expected title: $ExpectedTitle")
$logLines.Add("Application HWND: " + $(if ($ApplicationWindowHandle) { $ApplicationWindowHandle } else { "<not supplied>" }))
$logLines.Add("Expected DWG: " + $(if ($resolvedExpectedDwg) { $resolvedExpectedDwg } else { "<not required>" }))
$logLines.Add("Session log: " + $(if ($resolvedSessionLog) { $resolvedSessionLog } else { "<not required>" }))
$logLines.Add("Candidate dialog count: $($dialogCandidates.Count)")

if ($dialogCandidates.Count -ne 1) {
  foreach ($candidate in $dialogCandidates) {
    $logLines.Add("  candidate pid=$($candidate.ProcessId) hwnd=$($candidate.Dialog.ToInt64()) class=$($candidate.ClassName) text=$($candidate.WindowText) distance=$($candidate.Distance)")
  }
  $logLines.Add("Result: ABORT_DIALOG_NOT_UNIQUE")
  [IO.File]::WriteAllLines($LogPath, $logLines, [Text.UTF8Encoding]::new($false))
  throw "Expected exactly one GMTITLE dialog candidate, found $($dialogCandidates.Count). Inspect: $LogPath"
}

$candidate = $dialogCandidates[0]
$dialog = [IntPtr]$candidate.Dialog
$controls = $candidate.Controls
$rootWindow = [SwTitle.Win32]::GetAncestor($dialog, $GA_ROOT)
$rootTitle = Get-WindowTextValue -Handle $rootWindow
$process = Get-Process -Id $candidate.ProcessId -ErrorAction Stop

$logLines.Add("Process ID: $($candidate.ProcessId)")
$logLines.Add("Process path: $($process.Path)")
$logLines.Add("Dialog HWND: $($dialog.ToInt64())")
$logLines.Add("Dialog class: $($candidate.ClassName)")
$logLines.Add("Dialog text: $($candidate.WindowText)")
$logLines.Add("Root window title: $rootTitle")

if ($ApplySelections) {
  $sessionText = Get-Content -LiteralPath $resolvedSessionLog -Raw
  $loadedDwgLine = @($sessionText -split "`r?`n" | Where-Object { $_ -like "DWG before load: *" }) | Select-Object -First 1
  if (-not $loadedDwgLine) {
    $logLines.Add("Result: ABORT_SESSION_DWG_PATH_MISSING")
    [IO.File]::WriteAllLines($LogPath, $logLines, [Text.UTF8Encoding]::new($false))
    throw "The isolated session log does not identify its loaded DWG: $resolvedSessionLog"
  }

  $loadedDwgText = $loadedDwgLine.Substring("DWG before load: ".Length).Trim()
  $resolvedLoadedDwg = [IO.Path]::GetFullPath($loadedDwgText.Replace('/', '\'))
  $logLines.Add("Session loaded DWG: $resolvedLoadedDwg")
  if (-not $resolvedLoadedDwg.Equals($resolvedExpectedDwg, [StringComparison]::OrdinalIgnoreCase)) {
    $logLines.Add("Result: ABORT_SESSION_DWG_PATH_MISMATCH")
    [IO.File]::WriteAllLines($LogPath, $logLines, [Text.UTF8Encoding]::new($false))
    throw "The isolated session loaded an unexpected DWG. Expected '$resolvedExpectedDwg', got '$resolvedLoadedDwg'."
  }
  $logLines.Add("Session DWG validation: PASS")
}

$paperControl = [IntPtr]$controls[3010]
$titleControl = [IntPtr]$controls[3011]
$framePositionControl = [IntPtr]$controls[3022]
$objectMoveControl = [IntPtr]$controls[3024]
$okControl = [IntPtr]$controls[1]

$paperBefore = Get-ComboState -Handle $paperControl
$titleBefore = Get-ComboState -Handle $titleControl
$framePositionBefore = Get-CheckState -Handle $framePositionControl
$objectMoveBefore = Get-CheckState -Handle $objectMoveControl

$logLines.Add("Paper items: " + ($paperBefore.Items -join " | "))
$logLines.Add("Title items: " + ($titleBefore.Items -join " | "))
$logLines.Add("Before paper: index=$($paperBefore.SelectedIndex) text=$($paperBefore.SelectedText)")
$logLines.Add("Before title: index=$($titleBefore.SelectedIndex) text=$($titleBefore.SelectedText)")
$logLines.Add("Before Frame positioning: $framePositionBefore")
$logLines.Add("Before Object move: $objectMoveBefore")

if ($ApplySelections) {
  $paperAfter = Set-ComboExactValue -Dialog $dialog -Control $paperControl -ControlId 3010 -ExpectedValue $ExpectedFrame
  $titleAfter = Set-ComboExactValue -Dialog $dialog -Control $titleControl -ControlId 3011 -ExpectedValue $ExpectedTitle
  $framePositionAfter = Set-CheckState -Handle $framePositionControl -Checked $true
  $objectMoveAfter = Set-CheckState -Handle $objectMoveControl -Checked $false

  $logLines.Add("After paper: index=$($paperAfter.SelectedIndex) text=$($paperAfter.SelectedText)")
  $logLines.Add("After title: index=$($titleAfter.SelectedIndex) text=$($titleAfter.SelectedText)")
  $logLines.Add("After Frame positioning: $framePositionAfter")
  $logLines.Add("After Object move: $objectMoveAfter")
  $logLines.Add("Readback validation: PASS")

  [IO.File]::WriteAllLines($LogPath, $logLines, [Text.UTF8Encoding]::new($false))

  if ($ClickOk) {
    [void][SwTitle.Win32]::SendMessage($okControl, $BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 500
    $dialogStillPresent = [SwTitle.Win32]::IsWindow($dialog)
    $logLines.Add("Dialog present after OK: " + $(if ($dialogStillPresent) { "yes" } else { "no" }))
    $logLines.Add("Result: FIXED_CONTROL_SELECTION_APPLIED_AND_OK_CLICKED")
  } else {
    $logLines.Add("Result: FIXED_CONTROL_SELECTION_APPLIED_NOT_CONFIRMED")
  }
} else {
  $logLines.Add("Result: FIXED_CONTROL_DIALOG_INSPECTED")
}

[IO.File]::WriteAllLines($LogPath, $logLines, [Text.UTF8Encoding]::new($false))
$logLines
