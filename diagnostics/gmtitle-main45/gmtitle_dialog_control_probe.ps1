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
$helper = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\src\tools\gmtitle\swtitle_gmtitle_dialog_autoselect.ps1")).Path
& $helper @PSBoundParameters
if ($LASTEXITCODE) {
  exit $LASTEXITCODE
}
