# GMTITLE main45 verification index - 2026-07-04

## Purpose

This document records the reproducible evidence behind choosing `main45` for the four-command GMTITLE workflow.

The actual GstarCAD runtime fixture files and logs live under `work/`, but `work/*.lsp`, `work/*.scr`, `work/*.ps1`, and `work/*.txt` are intentionally ignored by Git. This index keeps the important proof in tracked documentation so the next PC/session does not repeat the same mistakes.

## Current LSP

Source:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

Temporary compare copy:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_current_main45_compare_copy.lsp
```

SHA256 for both source and compare copy:

```text
BB80F09CFDE8C083231D1106CEAF8C2A6DD83F40F8D8A59D30B295C5FD7A8AF8
```

Loaded version:

```text
260704-frame-definition-classification-main-45
```

## Public Command Surface

Tracked source evidence:

```text
rg -n "\(defun c:SWTITLE|\(defun c:SWSCALE" src\tools\gmtitle\swcad_title_scale.lsp
```

Expected public commands:

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
SWTITLEVERSION
SWSCALESCAN
```

Only the first four are the normal GMTITLE workflow. `SWTITLEVERSION` and `SWSCALESCAN` are read-only/helper commands.

## Runtime Fixtures

All commands below were run through GstarCAD Mechanical hidden `/b` execution using:

```text
work\run_swtitle_lsp_compare_runtime_260703.ps1
```

The original work runner and fixture files are ignored by Git, so this table is the tracked evidence index. A reusable tracked runner is now available at:

```text
diagnostics/gmtitle-main45/run_readonly_probe.ps1
```

The tracked actual-workcopy read-only probe wrapper is:

```text
diagnostics/gmtitle-main45/run_actual_workcopy_status_probe.ps1
```

The tracked LSP-copy comparison wrapper is:

```text
diagnostics/gmtitle-main45/run_lsp_copy_compare_probe.ps1
```

The tracked one-command verification suite is:

```text
diagnostics/gmtitle-main45/run_main45_verification_suite.ps1
```

The tracked post-conversion final completion gate is:

```text
diagnostics/gmtitle-main45/run_final_completion_gate.ps1
```

Latest suite result:

```text
Loader probe: Runtime check completed: yes
Current LSP copy compare probe: Runtime check completed: yes
Actual work-copy status probe: Runtime check completed: yes
Common A2/A3/A4 frame-definition probe:
  mixed: PASS
  all_contaminated: PASS
  all_native: PASS
All expected log markers were verified.
```

The final completion gate is intentionally expected to fail before interactive conversion. It requires `SWTITLEVERIFY_FINAL_OK`, zero remaining source title/frame/frame-only counts, and target A2/A3/A4 counts matching `1/12/2`.

| Fixture log | Purpose | Result |
| --- | --- | --- |
| `work\swtitle_version_probe_main45_260704.txt` | Confirm LSP load, expected version, public command registration, and command-line GMTITLE disabled | PASS |
| `work\swtitle_lsp_compare_main45_260704.txt` | Run read-only `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY` in GstarCAD | PASS for runtime; `SWTITLEVERIFY_FINAL_FAIL` expected because the comparison DWG is not converted |
| `work\swtitle_frameclass_fixture_main45_260704.txt` | Synthetic classification: A2 outline-only, A3 native-format, A4 source-contaminated | PASS |
| `work\swtitle_install_frame_scan_main45_260704.txt` | Import copied installed DR_A2/A3/A4/DR_title DWGs and classify definitions | PASS |
| `work\swtitle_status_nativeformat_fixture_main45_260704.txt` | Confirm `SWTITLESTATUS` does not send installed native A3 geometry to `SWTITLEPREPARE` | PASS |
| `work\swtitle_verify_nativeformat_fixture_main45_260704.txt` | Confirm `SWTITLEVERIFY` does not treat installed native A3 geometry as cleanup/blocking residue | PASS |
| `work\swtitle_prepare_guard_main45_260704.txt` | Confirm `SWTITLEPREPARE` aborts safely in SCRIPT `/b` automation | PASS |
| `work\swtitle_convert_guard_main45_260704.txt` | Confirm `SWTITLECONVERT` aborts safely in SCRIPT `/b` automation before interactive GMTITLE selection | PASS |
| `work\swtitle_title_protection_fixture_main45_260704.txt` | Confirm a normal `DR_titlea_3rd` insert is not treated as a frame-definition cleanup candidate | PASS |
| `work\swtitle_actual_workcopy_status_main45_260704.txt` | Run read-only main45 `SWTITLESTATUS` and `SWTITLEVERIFY` on a copied actual work-copy DWG | PASS for runtime; confirms the actual work copy is still before first native GMTITLE |
| `work\swtitle_actual_workcopy_status_main45_diagnostics.txt` | Same actual-workcopy probe rerun through tracked `diagnostics/gmtitle-main45/run_actual_workcopy_status_probe.ps1` | PASS |
| `work\swtitle_loader_probe_main45_diagnostics.txt` | Load `swcad_load.lsp` in GstarCAD and confirm the loader exposes the main45 4-command GMTITLE workflow while disabling stale legacy public commands | PASS |
| `work\swtitle_lsp_copy_compare_origin_main_0121ae1.txt` | Load GitHub `origin/main` LSP copy on the same copied work DWG | LOAD PASS, but `SWTITLESTATUS` did not complete before timeout |
| `work\swtitle_lsp_copy_compare_current_main45.txt` | Load current main45 LSP copy on the same copied work DWG | PASS; `SWTITLESTATUS` and `SWTITLEVERIFY` completed |
| `work\swtitle_frameclass_common_probe_mixed.txt` | Synthetic common A2/A3/A4 classification: A2 outline-only, A3 native-format, A4 source-contaminated | PASS |
| `work\swtitle_frameclass_common_probe_all_contaminated.txt` | Synthetic common A2/A3/A4 classification: all three source-contaminated | PASS |
| `work\swtitle_frameclass_common_probe_all_native.txt` | Synthetic common A2/A3/A4 classification: all three native-format-with-title-geometry | PASS |
| `diagnostics\gmtitle-main45\run_main45_verification_suite.ps1` | One-command suite that refreshes the current LSP compare copy and runs loader, current-copy, actual-workcopy, and common frame-class probes | PASS |
| `diagnostics\gmtitle-main45\run_final_completion_gate.ps1` | Post-conversion gate that fails unless final verify is OK and A2/A3/A4 target counts match | Added; not expected to pass until interactive `SWTITLECONVERT` is completed |

## Key Log Excerpts

### Version Probe

```text
Load result: OK
Loaded version: 260704-frame-definition-classification-main-45
Expected version: 260704-frame-definition-classification-main-45
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Command-line GMTITLE enabled: no
Probe completed: yes
```

### Installed DR Frame Scan

```text
DR_A2_Outline: class=outline-only, embedded=0, source-like-children=<none>
DR_A3_Outline: class=native-format-with-title-geometry, embedded=10, source-like-children=<none>
DR_A4_Outline: class=outline-only, embedded=0, source-like-children=<none>
Blocking records: 0
Cleanup records: 0
All embedded records: 10
Install frame scan passed: yes
```

### Status Native-Format Guard

```text
Run SWTITLESTATUS: ok
Structure next action: SWTITLECONVERT - remaining SolidWorks source sheets
DR_A3_Outline class after status: native-format-with-title-geometry
Blocking records after status: 0
Cleanup records after status: 0
All embedded records after status: 10
Native-format status passed: yes
```

### Verify Native-Format Guard

```text
Run SWTITLEVERIFY: ok
Final status: SWTITLEVERIFY_FINAL_FAIL
DR_A3_Outline class after verify: native-format-with-title-geometry
Blocking records after verify: 0
Cleanup records after verify: 0
All embedded records after verify: 10
Native-format verify passed: yes
```

### PREPARE Automation Guard

```text
Run SWTITLEPREPARE: ok
Prepare status: ABORT_PREPARE_SCRIPT_ACTIVE
Prepare guard passed: yes
```

### CONVERT Automation Guard

```text
CMDACTIVE before SWTITLECONVERT: 4
Run SWTITLECONVERT: ok
Convert status: ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE
CMDACTIVE after SWTITLECONVERT: 4
Convert guard passed: yes
```

### Normal Title Protection

```text
Insert normal DR_titlea_3rd: ok
Normal DR_titlea_3rd insert count: 1
Frame-definition child-title cleanup candidates: 0
Frame embedded-title cleanup candidates: 0
Frame-definition blockers: 0
Normal title protection passed: yes
```

### Common A2/A3/A4 Frame-Definition Classification

Tracked wrapper:

```text
diagnostics/gmtitle-main45/run_frameclass_common_probe.ps1
```

Mixed scenario:

```text
Scenario: MIXED
DR_A2_Outline: class=outline-only, embedded=0, source-like=<none>
DR_A3_Outline: class=native-format-with-title-geometry, embedded=1, source-like=<none>
DR_A4_Outline: class=source-contaminated, embedded=2, source-like=9_SW_NOTE_A4_FRAMECLASS_PROBE
Blocking frame definitions:
  DR_A4_Outline: 1
Cleanup records by frame:
  DR_A4_Outline: 2
Scenario result: PASS
Runtime check completed: yes
```

All-contaminated scenario:

```text
Scenario: ALL_CONTAMINATED
DR_A2_Outline: class=source-contaminated, embedded=1, source-like=9_SW_NOTE_A2_FRAMECLASS_PROBE
DR_A3_Outline: class=source-contaminated, embedded=1, source-like=9_SW_NOTE_A3_FRAMECLASS_PROBE
DR_A4_Outline: class=source-contaminated, embedded=2, source-like=9_SW_NOTE_A4_FRAMECLASS_PROBE
Cleanup records by frame:
  DR_A2_Outline: 1
  DR_A3_Outline: 1
  DR_A4_Outline: 2
Scenario result: PASS
Runtime check completed: yes
```

All-native scenario:

```text
Scenario: ALL_NATIVE
DR_A2_Outline: class=native-format-with-title-geometry, embedded=1, source-like=<none>
DR_A3_Outline: class=native-format-with-title-geometry, embedded=1, source-like=<none>
DR_A4_Outline: class=native-format-with-title-geometry, embedded=1, source-like=<none>
Blocking frame definitions:
  <none>
Cleanup records by frame:
  <none>
Scenario result: PASS
Runtime check completed: yes
```

Interpretation:

```text
The common frame-definition classifier covers DR_A2_Outline, DR_A3_Outline, and DR_A4_Outline.
Only source-contaminated definitions become blocking/cleanup candidates.
Native-format title-like geometry is reported but not sent to cleanup.
```

### Actual Work-Copy Read-Only Status

Probe DWG:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_actual_workcopy_main45_status_probe_260704.dwg
```

Result:

```text
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
frame-definition-blockers: 0
frame-embedded-cleanup-records: 0
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
target-sheet-counts:
  <none>
```

Interpretation:

```text
The actual work copy is still before the first native GMTITLE.
The next interactive CAD step is SWTITLECONVERT.
Do not run SWTITLEPREPARE first unless a fresh SWTITLESTATUS explicitly asks for it.
```

The same check was rerun through the tracked diagnostics wrapper:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/gmtitle-main45/run_actual_workcopy_status_probe.ps1
```

Wrapper result:

```text
DWG: C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_actual_workcopy_main45_status_probe_diagnostics.dwg
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

### Loader Probe

Tracked wrapper:

```text
diagnostics/gmtitle-main45/run_loader_probe.ps1
```

Result:

```text
Load result: OK
Loaded loader version: 260704-4step-gmtitle-main47
Loaded GMTITLE version: 260704-frame-definition-classification-main-45
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Command c:SWTITLEVERSION: yes
Command c:SWSCALESCAN: yes
Legacy command disabled sample:
Command c:SWTITLEFASTSTATUS: no
Command c:SWTITLETRANSFERBOOTSTRAPFAST: no
Command c:SWTITLETRANSFERFASTBATCH: no
Command c:SWTITLEFRAMEONLYAPPLY: no
Command c:SWTITLEA3A4NEXT: no
Command c:SWTITLEA3A4ALL: no
Command c:SWTITLEGMTITLEVERIFYALL: no
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

Interpretation:

```text
The APPLOAD path through swcad_load.lsp loads the same main45 GMTITLE implementation.
The public command surface remains the four normal workflow commands plus two helper commands.
Representative stale legacy public commands are disabled after load, so old instructions such as `SWTITLETRANSFERBOOTSTRAPFAST`, `SWTITLEFASTSTATUS`, `SWTITLEFRAMEONLYAPPLY`, and `SWTITLEA3A4NEXT` should not remain callable in the CAD session.
The actual work copy is still before the first native GMTITLE.
```

### Origin/Main vs Current Main45 Copy Compare

Tracked comparison document:

```text
docs/history/gmtitle-origin-main-vs-current-main45-copy-comparison-2026-07-04.md
```

Static public command check:

```text
origin/main 0121ae1 public c: command definitions: 21
current main45 public c: command definitions: 6
```

Runtime probe note:

```text
GstarCAD startup can auto-load other LSP files, so runtime "Command c:*: yes/no" can be polluted.
The static `defun c:` search is authoritative for public command surface.
```

Origin/main copied LSP result:

```text
Load result: OK
Loaded version: 260702-command-surface-cleanup-1
Run: SWTITLESTATUS
Runtime log was not completed before timeout.
```

Current main45 copied LSP result:

```text
Load result: OK
Loaded version: 260704-frame-definition-classification-main-45
Four workflow commands:
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Legacy command runtime sample:
Command c:SWTITLEFASTSTATUS: no
Command c:SWTITLETRANSFERBOOTSTRAPFAST: no
Command c:SWTITLETRANSFERFASTBATCH: no
Command c:SWTITLEFRAMEONLYAPPLY: no
Command c:SWTITLEA3A4NEXT: no
Command c:SWTITLEA3A4ALL: no
Command c:SWTITLEGMTITLEVERIFYALL: no
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
frame-definition-blockers: 0
frame-embedded-cleanup-records: 0
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

Interpretation:

```text
Current main45 is the better baseline for the next actual CAD conversion test.
The origin/main LSP is useful as history only; it should not be used to continue the current GMTITLE workflow.
```

## Decision

Use `main45`.

`main44` is safe enough to avoid command-line `-GMTITLE` automation, but it does not prove that installed native `DR_A3_Outline` title-like geometry is different from source contamination.

`main45` proves that:

```text
1. Installed DR_A3_Outline can contain title-like geometry by design.
2. That native-format geometry is not a cleanup/blocking target.
3. SWTITLESTATUS does not incorrectly route that case to SWTITLEPREPARE.
4. Normal DR_titlea_3rd title inserts are protected from frame-definition cleanup.
5. PREPARE and CONVERT do not run dangerous interactive/write steps from SCRIPT automation.
6. main45 disables representative stale legacy public commands at load time, preventing old command sequences from staying active after GstarCAD startup autoloads another LSP.
```

## Not Yet Complete

This index does not prove full conversion completion.

Remaining proof must come from a real work-copy DWG:

```text
SWTITLEVERIFY_FINAL_OK
source SolidWorks title candidates = 0
source SolidWorks frame candidates = 0
A2/A3/A4 expected counts match target GMTITLE frame counts
no A3 duplicate title block
no missing A4 frame-only sheet
no deleted drawing notes/BOM/text
representative A2/A3/A4 DR_titlea_3rd double-click opens the GMTITLE table editor
```
