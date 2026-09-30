param(
  [Parameter(Mandatory = $true)][string]$SourceDwg,

  # Must be inside Documents\CAD tool\work so GMTITLE accepts it as a work copy.
  [string]$WorkDwg,

  [Parameter(Mandatory = $true)][string]$LogPath,

  [int]$MaxRuns = 45,

  [int]$RunTimeoutSeconds = 900,

  # Keep running SWCADRUN after the TITLE stage until COMPLETE (or a stop).
  [switch]$FullWorkflow,

  # Test settings sent as LISP after the workflow is loaded, e.g.
  # "(setq *swapp-swfmt-test-skip-missing-frames* T)".
  [string]$SetupLisp
)

# Opens a copy of a TITLE-stage drawing in a visible GstarCAD and runs SWCADRUN through
# COM SendCommand. SendCommand is not a script, so the GMTITLE dialog step runs with its
# fixed-control helper exactly as it does for the user. The copy is saved at the end.
# The source drawing is only copied; its hash is checked at the end.

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$gcad = "C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\GstarCAD\gcad.exe"
if (-not $WorkDwg) {
  $WorkDwg = Join-Path $repoRoot ("work\swcad-workflow-tests\gmtitle_value_e2e_" + (Get-Date -Format "yyMMdd_HHmmss") + ".dwg")
}
$statusFile = Join-Path (Split-Path $LogPath) "e2e_status.txt"

function Log([string]$message) {
  $line = "{0:HH:mm:ss} {1}" -f (Get-Date), $message
  Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
  Write-Output $line
}

function Invoke-Com([scriptblock]$Call, [int]$TimeoutSeconds = 60) {
  # GstarCAD rejects COM calls while it is busy; retry until it accepts.
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ($true) {
    try { return & $Call }
    catch {
      if ((Get-Date) -gt $deadline) { throw }
      Start-Sleep -Milliseconds 500
    }
  }
}

function Wait-Idle($doc, [int]$TimeoutSeconds) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $idle = 0
  while ((Get-Date) -lt $deadline) {
    $active = $null
    try { $active = $doc.GetVariable("CMDACTIVE") } catch { $active = $null }
    if ($active -ne $null -and [int]$active -eq 0) { $idle++ } else { $idle = 0 }
    if ($idle -ge 3) { return $true }
    Start-Sleep -Milliseconds 1000
  }
  return $false
}

function Read-Status($doc) {
  if (Test-Path -LiteralPath $statusFile) { [IO.File]::Delete($statusFile) }
  $lispPath = $statusFile.Replace('\', '/')
  $expr = "(progn (setq swe-f (open `"$lispPath`" `"w`")) (write-line (strcat `"STAGE|`" (swapp-workflow-stage)) swe-f) (write-line (strcat `"TITLE_STATUS|`" (swcad-title-string *swcad-title-last-apply-status*)) swe-f) (write-line (strcat `"DIMSTYLE|`" (if (swapp-state-value `"DIMSTYLE`") (swapp-state-value `"DIMSTYLE`") `"`")) swe-f) (close swe-f) (princ))`r"
  Invoke-Com { $doc.SendCommand($expr) } 120 | Out-Null
  $null = Wait-Idle $doc 120
  $result = @{}
  if (Test-Path -LiteralPath $statusFile) {
    foreach ($line in [IO.File]::ReadAllLines($statusFile, [Text.Encoding]::GetEncoding(949))) {
      $i = $line.IndexOf("|")
      if ($i -gt 0) { $result[$line.Substring(0, $i)] = $line.Substring($i + 1) }
    }
  }
  return $result
}

if (Test-Path -LiteralPath $LogPath) { [IO.File]::Delete($LogPath) }
if (Get-Process -Name gcad -ErrorAction SilentlyContinue) { throw "GstarCAD is already open; not starting the end-to-end test." }
if (-not $WorkDwg.StartsWith((Join-Path $repoRoot "work"), [StringComparison]::OrdinalIgnoreCase)) { throw "WorkDwg must be under the work folder: $WorkDwg" }
Copy-Item -LiteralPath $SourceDwg -Destination $WorkDwg -Force
$sourceHash = (Get-FileHash -LiteralPath $SourceDwg -Algorithm SHA256).Hash
Log "work copy: $WorkDwg"

$proc = Start-Process -FilePath $gcad -ArgumentList ('"' + $WorkDwg + '"') -PassThru
Log "started gcad pid=$($proc.Id)"
try {
  $app = $null
  $deadline = (Get-Date).AddSeconds(240)
  while (-not $app -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    try { $app = [Runtime.InteropServices.Marshal]::GetActiveObject("GStarCAD.Application.24") } catch { $app = $null }
  }
  if (-not $app) { throw "GstarCAD COM object not available." }
  $doc = $null
  $deadline = (Get-Date).AddSeconds(240)
  while ((Get-Date) -lt $deadline) {
    try {
      $doc = $app.ActiveDocument
      if ($doc -and ([string]$doc.FullName).ToLowerInvariant() -eq $WorkDwg.ToLowerInvariant()) { break }
    } catch {}
    Start-Sleep -Seconds 2
  }
  Log ("active document: " + [string]$doc.FullName)
  $null = Wait-Idle $doc 180

  $rootLisp = $repoRoot.Replace('\', '/')
  Invoke-Com { $doc.SendCommand("(load `"$rootLisp/apps/swcad-workflow/swcad_workflow_load.lsp`")`r") } 120 | Out-Null
  $null = Wait-Idle $doc 300
  if ($SetupLisp) {
    Invoke-Com { $doc.SendCommand("$SetupLisp`r") } 60 | Out-Null
    $null = Wait-Idle $doc 60
    Log "setup: $SetupLisp"
  }
  $status = Read-Status $doc
  Log ("before runs: stage=" + $status["STAGE"] + " title=" + $status["TITLE_STATUS"])

  $previous = ""
  for ($run = 1; $run -le $MaxRuns; $run++) {
    $t0 = Get-Date
    Invoke-Com { $doc.SendCommand("SWCADRUN`r") } 120 | Out-Null
    $done = Wait-Idle $doc $RunTimeoutSeconds
    $status = Read-Status $doc
    Log ("run {0}: {1:n0}s idle={2} stage={3} title={4} dimstyle={5}" -f $run, ((Get-Date) - $t0).TotalSeconds, $done, $status["STAGE"], $status["TITLE_STATUS"], $status["DIMSTYLE"])
    if (-not $done) { Log "run did not finish in time"; break }
    $stage = [string]$status["STAGE"]
    $title = [string]$status["TITLE_STATUS"]
    if ($title -match '^(ABORT_|ERROR_|WARN_|BLOCKED_|REVIEW_|SWTITLEVERIFY_WARN_|SWTITLEVERIFY_FINAL_WARN|SWTITLEVERIFY_FINAL_FAIL)') { Log "stopped on blocking title status"; break }
    if (-not $FullWorkflow -and $stage -ne "TITLE") { Log "title stage finished"; break }
    if ($stage -eq "COMPLETE") { Log "workflow complete"; break }
    if ([string]$status["DIMSTYLE"] -eq "FAILED") { Log "stopped: DIMSTYLE=FAILED"; break }
    $key = "$stage|$title"
    if ($key -eq $previous -and $stage -ne "TITLE") { Log "no progress"; break }
    $previous = $key
  }

  Invoke-Com { $doc.SendCommand("_.QSAVE`r") } 120 | Out-Null
  $null = Wait-Idle $doc 300
  Log "saved"
  try { $app.Quit() } catch {}
  Start-Sleep -Seconds 10
} finally {
  if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; Log "gcad stopped" } else { Log "gcad exited" }
}
Log ("source unchanged: " + ((Get-FileHash -LiteralPath $SourceDwg -Algorithm SHA256).Hash -eq $sourceHash))
Log "work result: $WorkDwg"
Log "E2E driver completed: yes"
