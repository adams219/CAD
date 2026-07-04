# GMTITLE main45 diagnostics

This folder contains tracked diagnostic helpers for the `main45` four-command GMTITLE workflow.

The detailed runtime fixtures and generated logs are kept under `work/` during local testing, but `work/*.lsp`, `work/*.scr`, `work/*.ps1`, and `work/*.txt` are ignored by Git. Keep durable conclusions in `docs/` and reusable runner helpers here.

## Runner

Use `run_readonly_probe.ps1` to run a GstarCAD Mechanical `/b` script against a copied work DWG and wait for a completion marker in the log.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_readonly_probe.ps1" `
  -DwgPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_actual_workcopy_main45_status_probe_260704.dwg" `
  -ScriptPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_actual_workcopy_status_main45_260704.scr" `
  -LogPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_actual_workcopy_status_main45_260704.txt"
```

The script starts GstarCAD hidden, waits for `Runtime check completed:` by default, prints the log, then stops GstarCAD if it is still running.

## Main45 Verification Suite

Use `run_main45_verification_suite.ps1` to run the standard read-only checks in one command:

1. loader probe
2. current LSP compare-copy probe
3. actual work-copy status/verify probe
4. common A2/A3/A4 frame-definition classification probe
5. A2/A3/A4 style-normalization rebuild cleanup probe
6. command-text guard comparison probe
7. sheet residue protection probe
8. embedded-title prepare copy-comparison probe

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_main45_verification_suite.ps1"
```

The suite also refreshes:

```text
work\lsp_compare\swcad_title_scale_current_main45_compare_copy.lsp
```

from the current source LSP before running the compare-copy probe.

The suite fails if expected log markers are missing. The checked markers include:

```text
loaded main45 versions
four workflow commands enabled
representative legacy commands disabled
actual work-copy source/target counts
A2/A3/A4 expected sheet counts
mixed/all_contaminated/all_native frame-class PASS results
A2/A3/A4 style-normalization record count 3 -> 0 after rebuild cleanup
command-text guard blocks conversion before any stubbed conversion path
sheet residue protection keeps real text, small SW_NOTE balloons, and BOM-like inserts
embedded-title prepare comparison proves the plan copy routes native-format title geometry to SWTITLEPREPARE before conversion
```

## Actual Work-Copy Status Probe

Use `run_actual_workcopy_status_probe.ps1` to copy the current work DWG to a probe DWG and run the tracked `actual_workcopy_status_probe.lsp` against the copy.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_actual_workcopy_status_probe.ps1"
```

By default this copies:

```text
work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

to:

```text
work\swtitle_actual_workcopy_main45_status_probe_diagnostics.dwg
```

and writes:

```text
work\swtitle_actual_workcopy_status_main45_diagnostics.txt
```

Pass `-SourceWorkCopyPath`, `-ProbeDwgPath`, or `-LogPath` to override those paths.

## Final Completion Gate

After the interactive `SWTITLECONVERT` workflow has been completed in GstarCAD, use `run_final_completion_gate.ps1` to verify the converted work-copy DWG.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_final_completion_gate.ps1"
```

This gate is expected to fail before conversion. It requires:

```text
SWTITLEVERIFY_FINAL_OK
source-title-count: 0
source-frame-count: 0
frame-only-count: 0
A2: 1
A3: 12
A4: 2
```

## Loader Probe

Use `run_loader_probe.ps1` to copy the current work DWG to a probe DWG, load `swcad_load.lsp`, and confirm the loader exposes the same main45 GMTITLE workflow.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_loader_probe.ps1"
```

By default this writes:

```text
work\swtitle_loader_probe_main45_diagnostics.txt
```

Expected result:

```text
Loaded loader version: 260704-4step-gmtitle-main49
Loaded GMTITLE version: 260704-plan-frame-prepare-main-49
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Runtime check completed: yes
```

## Synthetic Frame-Definition Classification Probe

Use `run_frameclass_common_probe.ps1` to create synthetic `DR_A2_Outline`, `DR_A3_Outline`, and `DR_A4_Outline` block definitions inside copied probe DWGs. This verifies that the common `SWTITLEPREPARE` classification logic treats source contamination, native-format title-like geometry, and outline-only definitions differently without exposing sheet-specific public commands.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_frameclass_common_probe.ps1"
```

Default scenarios:

```text
mixed            A2 outline-only, A3 native-format, A4 source-contaminated
all_contaminated A2/A3/A4 all source-contaminated
all_native       A2/A3/A4 all native-format-with-title-geometry
```

Expected result for each scenario:

```text
Scenario result: PASS
Runtime check completed: yes
```

## Synthetic Style-Normalization Rebuild Probe

Use `run_style_normalization_compare_probe.ps1` with `-Sheets "A2,A3,A4" -RunClean` to verify that `SWTITLEPREPARE` style-normalization is not an A3-only fix.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_style_normalization_compare_probe.ps1" `
  -LspPath "src\tools\gmtitle\swcad_title_scale.lsp" `
  -Label "current_main49_stylecmp_all_sizes_clean" `
  -Sheets "A2,A3,A4" `
  -RunClean
```

Expected result:

```text
DR_A2_Outline: class=native-format-with-title-geometry
DR_A3_Outline: class=native-format-with-title-geometry
DR_A4_Outline: class=native-format-with-title-geometry
Style-normalization record count: 3
Style-normalization deleted count: 12
Style-normalization record count after clean: 0
Runtime check completed: yes
```

## Command-Text Guard Comparison Probe

Use `run_command_text_guard_compare_probe.ps1` to compare LSP copies against the repeated CAD input failure mode where `SWTITLECONVERT` or another command is inserted into the drawing as TEXT/MTEXT.

The probe injects one synthetic `SWTITLECONVERT` text entity into a copied probe DWG, stubs modifying conversion helpers, then checks whether the integrated convert dispatcher aborts before reaching a conversion path.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_command_text_guard_compare_probe.ps1" `
  -LspPath "work\lsp_compare\swcad_title_scale_command_text_guard_test.lsp" `
  -Label "guard_test_main48_command_text_guard"
```

Expected safe result:

```text
command-text-count-before: 1
structure-next-action: SWTITLEPREPARE - ?ㅼ닔 紐낅졊???띿뒪???붿뿬臾쇱쓣 癒쇱? ?뺤씤/?뺣━?댁빞 ?⑸땲??
convert-status-after: ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST
danger-action-after-convert: <none>
Runtime check completed: yes
```

## Sheet Residue Protection Probe

Use `run_residue_protection_probe.ps1` to verify that cleanup candidates stay narrow enough to avoid real drawing content. The probe injects synthetic entities far away from the real drawing and checks that logo/sheet-format residue is selected while real notes, small `SW_NOTE` balloons, and BOM-like blocks are preserved.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_residue_protection_probe.ps1" `
  -LspPath "src\tools\gmtitle\swcad_title_scale.lsp" `
  -Label "current_main49_residue_protection"
```

Expected result:

```text
bottom-left logo line candidate: yes
bottom-left real text preserved: yes
upper small SW_NOTE balloon preserved: yes
upper wide SW_NOTE residue candidate: yes
upper SHEET_FORMAT residue candidate: yes
upper BOM-like insert preserved: yes
Residue protection passed: yes
Runtime check completed: yes
```

## Embedded-Title Prepare Copy Comparison Probe

Use `run_embedded_title_prepare_compare_probe.ps1` to compare the current LSP with a plan copy for the A3/A4 problem where a `DR_A*_Outline` frame definition already contains title-like geometry before a separate `DR_titlea_3rd` title block exists.

Current main49:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_embedded_title_prepare_compare_probe.ps1" `
  -LspPath "src\tools\gmtitle\swcad_title_scale.lsp" `
  -Label "current_main49_embedded_prepare"
```

Plan copy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_embedded_title_prepare_compare_probe.ps1" `
  -LspPath "work\lsp_compare\swcad_title_scale_plan_frame_prepare_compare.lsp" `
  -Label "plan_frame_prepare_compare" `
  -RunClean
```

Expected comparison:

```text
current main49:
  Cleanup records by frame: <none>
  Structure next action: SWTITLECONVERT

plan copy:
  Cleanup records by frame: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline
  Structure next action: SWTITLEPREPARE
  Cleanup deleted count: 12
  Cleanup record count after clean: 0
```

Durable conclusion:

```text
docs/investigations/gmtitle-plan-frame-prepare-copy-comparison-2026-07-04.md
```

## Current Evidence Index

Tracked conclusions and log excerpts are in:

```text
docs/investigations/gmtitle-main45-verification-index-2026-07-04.md
docs/history/gmtitle-four-command-goal-audit-2026-07-04.md
docs/history/gmtitle-main44-vs-main45-comparison-2026-07-04.md
```

## Safety Rules

Use this runner only for read-only probes or scripts that explicitly abort before interactive/write steps.

Do not use `/b` automation to drive `SWTITLECONVERT` through the GMTITLE dialog. `main45` deliberately aborts `SWTITLECONVERT` in SCRIPT mode with `ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE`.

Use a copied DWG under `work/`, not a production or Downloads DWG.

For interactive CAD testing notes, especially the `_PASTECLIP` command-input failure mode and the required `SWTITLEVERSION` preflight, see:

```text
docs/history/gmtitle-cad-input-safety-2026-07-04.md
```
