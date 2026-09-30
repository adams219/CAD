param(
  # Base path of the result files. Writes <OutputPath>.utf8.txt and <OutputPath>.ansi.txt.
  [Parameter(Mandatory = $true)][string]$OutputPath,
  [string]$InitialDirectory = "",
  # Tests only: write these paths (separated by |) without showing the dialog.
  [string]$TestPaths = ""
)

# File dialog for SWCADRUN step 0 (collect drawings as XREFs).
# GstarCAD LISP has no multi-select file dialog (getfiled picks one file), so
# SWCADRUN starts this script and waits for it.
#
# The result is written twice, one path per line after a status line
# ("OK <count>" or "CANCEL"): in UTF-8 with BOM and in the system ANSI code page.
# It is not known which encoding GstarCAD LISP read-line decodes, so the LISP
# side uses the file whose paths exist.

$ErrorActionPreference = "Stop"
$paths = @()
$status = "CANCEL"
try {
  if ($TestPaths) {
    $paths = @($TestPaths.Split('|') | Where-Object { $_ -ne "" })
    $status = "OK"
  } else {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "SWCADRUN - XREF로 모을 DWG 도면 고르기 (여러 개: Ctrl, Shift, Ctrl+A)"
    $dialog.Filter = "DWG 도면 (*.dwg)|*.dwg"
    $dialog.Multiselect = $true
    $dialog.CheckFileExists = $true
    if ($InitialDirectory -and (Test-Path -LiteralPath $InitialDirectory -PathType Container)) {
      $dialog.InitialDirectory = $InitialDirectory
    }
    # A top-most owner brings the dialog in front of GstarCAD.
    $owner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }
    if ($dialog.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) {
      $paths = @($dialog.FileNames)
      $status = "OK"
    }
    $owner.Dispose()
  }
} catch {
  $status = "ERROR " + $_.Exception.Message.Replace("`r", " ").Replace("`n", " ")
  $paths = @()
}

$lines = @($(if ($status -eq "OK") { "OK $($paths.Count)" } else { $status })) + $paths
[IO.File]::WriteAllLines("$OutputPath.utf8.txt", $lines, (New-Object System.Text.UTF8Encoding($true)))
[IO.File]::WriteAllLines("$OutputPath.ansi.txt", $lines, [System.Text.Encoding]::Default)
