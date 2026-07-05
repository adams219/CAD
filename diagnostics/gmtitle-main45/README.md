# GMTITLE main45 diagnostics

This folder contains tracked diagnostic helpers for the `main45` four-command GMTITLE workflow.

The detailed runtime fixtures and generated logs are kept under `work/` during local testing, but `work/*.lsp`, `work/*.scr`, `work/*.ps1`, and `work/*.txt` are ignored by Git. Keep durable conclusions in `docs/` and reusable runner helpers here.

## Static Preflight

Use `run_static_preflight.ps1` when GstarCAD is still open or before running the hidden CAD suite. It does not open CAD or touch any DWG. It checks Lisp balance, expected loader/GMTITLE versions, public command surface, A4 raw-bbox guards, script guards, suite step numbering, and guide/documentation version markers.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_static_preflight.ps1"
```

Expected result:

```text
Static preflight result: PASS
```

## Goal Status

Use `run_goal_status.ps1` when you are not sure what to run next. It does not open CAD or touch any DWG. It runs the static preflight, reports Git branch/commit, checks whether GstarCAD is open, checks the default work-copy path, and prints the next command.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_goal_status.ps1"
```

Typical result while GstarCAD is open:

```text
Static preflight: PASS
GstarCAD: open
Next action:
  Save the visible GstarCAD work-copy DWG.
  Close GstarCAD.
  Run the full hidden suite.
```

## GMTITLE Selection Config Probe

Use `run_gmtitle_selection_config_probe.ps1` when the next question is whether GstarCAD stores the `GMTITLE` paper/title selection somewhere simple, such as `PaperSet.ini`, `PaperSet.dat`, the `PAPERSET.GRX-66` dialog registry key, or obvious `PaperSet.grx` strings.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_gmtitle_selection_config_probe.ps1"
```

Expected result on the current workstation:

```text
Result: GMTITLE_SELECTION_CONFIG_NOT_FOUND
```

This is a read-only config probe. It does not open CAD and does not touch any DWG. It also does not prove that native `GMTITLE` cannot be automated; it only records that the checked config/registry locations do not expose a reliable `DR_A*_Outline` / `DR_titlea_3rd` preselection value.

It also records the command-map distinction discovered in the GstarCAD XML files: the ribbon/menu entry exposes an `IMTITLE` macro for the drawing title/border command, while `GMSBLOCKE` maps to the `PAPERSET` super attribute block editor rather than paper/title preselection. The 2026-07-05 scratch CAD check found `IMTITLE` is not an executable command in the current command line, and `TIT` falls back into the same insertion-point flow as `GMTITLE`. A follow-up accessibility check on the visible GstarCAD ribbon did not expose a stable drawing-title/border element either, so screenshot-coordinate ribbon clicks are not accepted as automation evidence.

Durable conclusion:

```text
docs/history/gmtitle-a4-native-selection-config-probe-2026-07-05.md
```

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

The runner now fails fast if another `gcad.exe` process is already open. In that state GstarCAD can route `/b` automation through the existing instance or wait behind an active command prompt, so the probe may never load its `.scr` file. Do not kill the user's visible CAD session automatically; save/close it intentionally, then rerun the probe. Use `-AllowExistingGstarCAD` only for deliberate debugging of that failure mode.

## Main45 Verification Suite

Use `run_main45_verification_suite.ps1` to run the standard read-only checks in one command:

1. loader probe
2. current LSP compare-copy probe
3. actual work-copy status/verify probe
4. A4 native exemplar gap probe
5. A4 outline strict prepare guard probe
6. SWTITLECONVERT script guard probe
7. common A2/A3/A4 frame-definition classification probe
8. A2/A3/A4 style-normalization rebuild cleanup probe
9. command-text guard comparison probe
10. sheet residue protection probe
11. embedded-title prepare copy-comparison probe
12. duplicate target pair comparison probe
13. native adoption gate comparison probe
14. A3 status guidance probe
15. A3/A4 batch guard probe
16. GMTITLE selection config probe

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_main45_verification_suite.ps1"
```

If GstarCAD is still open, either save and close it first or start the suite in waiting mode:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_main45_verification_suite.ps1" `
  -WaitForGstarCADClose
```

Waiting mode does not close GstarCAD. It waits for the user to save/close the visible session, then continues the hidden read-only probes.

The suite also refreshes:

```text
work\lsp_compare\swcad_title_scale_current_main45_compare_copy.lsp
```

from the current source LSP before running the compare-copy probe.

The suite also fails before the first probe if `gcad.exe` is already running and `-WaitForGstarCADClose` is not used. Save the work-copy DWG and close GstarCAD first, otherwise hidden `/b` probes can attach to the visible session and never create their log.

The suite fails if expected log markers are missing. The checked markers include:

```text
loaded main45 versions
four workflow commands enabled
representative legacy commands disabled
actual work-copy source/target counts
A2/A3/A4 expected sheet counts
actual work-copy first native guidance: A2 -> DR_A2_Outline + DR_titlea_3rd
A4 native exemplar gap: saved default work-copy has two frame-only sources but no DR_A4_Outline definition or target insert yet
A4 strict prepare guard: imported DR_A4_Outline definitions whose raw bbox extends outside (0,0)-(210,297) are rejected and the original A4 source frames remain
SWTITLECONVERT script guard aborts in SCRIPT mode without changing source/target counts, INSERT count, or DBMOD
mixed/all_contaminated/all_native frame-class PASS results
A2/A3/A4 style-normalization record count 3 -> 0 after rebuild cleanup
command-text guard blocks conversion before any stubbed conversion path
sheet residue protection keeps real text, small SW_NOTE balloons, and BOM-like inserts
embedded-title prepare comparison proves the plan copy routes native-format title geometry to SWTITLEPREPARE before conversion
A3 status guidance probe proves SWTITLESTATUS explains that DR_A3_Outline remains an INSERT/block reference and clone/shared-link candidates are the real unfinished condition
A3/A4 batch guard probe proves BATCH does not run inside SCRIPT automation and preserves existing candidates
GMTITLE selection config probe records that the checked PaperSet/config/registry locations do not expose an active DR_A*_Outline / DR_titlea_3rd preselection value
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

The probe logs `DBMOD before commands` and `dbmod-after-commands`. Hidden probes reopen the saved DWG, so a mismatch between the visible CAD screen and probe results usually means the active CAD drawing has unsaved changes.

The integrated CAD commands also print the same save-state warning:

```text
DWG 저장 상태: 저장됨 (DBMOD=0)
DWG 저장 상태: 저장되지 않은 변경 있음 (DBMOD=...)
```

If `DBMOD` is not 0 and another computer or hidden probe should continue the work, save the work-copy DWG first.

For the saved pre-conversion work-copy, the probe should also prove that `SWTITLEVERIFY` does not tell the user to handle A4 frame-only sheets before the remaining SolidWorks source title/frame sheets:

```text
a4-frame-only-deferred-note-found: yes
verify-source-priority-note-found: yes
verify-a4-frame-only-first-note-found: no
```

## A4 Outline Prepare Probe

Use `run_a4_outline_prepare_probe.ps1` to copy a work DWG, load the current GMTITLE LSP, and run the internal A4 frame-only `DR_A4_Outline` definition preflight on the copy.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_a4_outline_prepare_probe.ps1"
```

Default input:

```text
latest DWG path from work\swcad_title_next_step_last.txt
fallback: work\0000_A_DRP125 CP_ALL_260704_test.dwg
```

Default log:

```text
work\swtitle_a4_outline_prepare_probe_260705.txt
```

Expected safe result for the current installed `DR_A4_Outline` state:

```text
Loaded version: 260705-verify-source-priority-a4stepnote
Before definition status: missing
Prepare result: OK status=WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE
After definition status: missing
After frame-only-count: 2
Runtime check completed: yes
```

This is a safety pass, not a completed A4 conversion. It proves that the tool refuses the unsafe imported `DR_A4_Outline` definition and preserves the existing A4 source frames.

## A4 Outline Normalization Probe

Use `run_a4_outline_normalization_probe.ps1` to test whether simple `DR_A4_Outline` definition cleanup strategies can make the imported A4 outline safe for frame-only conversion.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_a4_outline_normalization_probe.ps1"
```

Default input:

```text
work\0000_A_DRP125 CP_ALL_260704_test.dwg
```

Default logs:

```text
work\swtitle_a4_outline_norm_none_260705.txt
work\swtitle_a4_outline_norm_huge-insert_260705.txt
work\swtitle_a4_outline_norm_direct-outside_260705.txt
work\swtitle_a4_outline_norm_nested-outside_260705.txt
work\swtitle_a4_outline_norm_nested-direct-outside_260705.txt
```

Nested-block investigation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_a4_outline_normalization_probe.ps1" `
  -Strategies nested-outside,nested-direct-outside `
  -WaitForGstarCADClose
```

This does not change the production conversion path. It waits for visible GstarCAD to close, then runs copied-DWG hidden probes for checking whether the oversized `도면 세로 A4 From_HYUN` child block inside `DR_A4_Outline` can be normalized without destroying the visible A4 outline. `nested-direct-outside` also compares parent-level outside objects while keeping the large child INSERT.

Current expected conclusion:

```text
none: unsafe, raw bbox remains (0,0)-(872.26126377,302.7)
huge-insert: unsafe, raw bbox improves but still does not match A4
direct-outside: unsafe, deletes too much and leaves only POINT/TEXT remnants
nested-outside: unsafe, effective A4 remains but raw selection bbox remains oversized
nested-direct-outside: unsafe, effective A4 remains but raw selection bbox remains oversized
Normalization safe for A4 frame-only conversion: no
```

This is a negative probe. It proves that deletion-style normalization, including the nested child-block variants, should not be promoted into `SWTITLEPREPARE` or `SWTITLECONVERT`.

Durable conclusion:

```text
docs/history/gmtitle-a4-outline-normalization-probe-2026-07-05.md
```

## A4 Native Exemplar Probe

Use `run_a4_native_exemplar_probe.ps1` to check whether a copied DWG already contains a usable native or native-like A4 `DR_A4_Outline` exemplar.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1"
```

Default input:

```text
work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

Default log:

```text
work\swtitle_a4_native_exemplar_probe_260705.txt
```

Current expected result for the saved default work copy:

```text
A4 outline definition status: missing
Definition exists: no
Visible DR_A4_Outline frame inserts: 0
Result: A4_NATIVE_EXEMPLAR_MISSING_DEFINITION
```

This probe is useful after manually creating or saving a scratch/native A4 GMTITLE sheet. A usable result must show a clean A4 definition, no geometry/raw-selection warning, and:

```text
Result: A4_NATIVE_EXEMPLAR_READY_FOR_COMPARISON
```

The scratch/native A4 sheet is only for comparison. It may include `DR_titlea_3rd` if native GMTITLE creates one, but production A4 frame-only conversion must still not create a title block that was not present in the source.

Durable conclusion:

```text
docs/history/gmtitle-a4-native-exemplar-gap-2026-07-05.md
```

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
Loaded loader version: 260705-4step-gmtitle-a4-outline-preflight
Loaded GMTITLE version: 260705-verify-source-priority-a4stepnote
Command-line -GMTITLE default enabled: no
SCRIPT command-line -GMTITLE enabled: no
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Runtime check completed: yes
```

## A3 Status Guidance Probe

Use `run_a3_status_guidance_probe.ps1` to create a synthetic copied-DWG fixture with one `DR_A3_Outline` + `DR_titlea_3rd` target pair marked as a clone. It verifies that `SWTITLESTATUS` prints the A3 guidance that avoids confusing normal frame block selection with the real clone/shared-link unfinished state.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_a3_status_guidance_probe.ps1"
```

Expected result:

```text
Loaded version: 260705-verify-source-priority-a4stepnote
A3/A4 candidate count before SWTITLESTATUS: 1
SWTITLESTATUS result: OK
Status after SWTITLESTATUS: NEXT_UPGRADE_A3_A4_NATIVE
A3 frame guidance note found: yes
A3 native-candidate supplement found: yes
A3 status guidance probe passed: yes
Runtime check completed: yes
```

## A3/A4 Batch Guard Probe

Use `run_a3a4_batch_guard_probe.ps1` to create two synthetic cloned A3 GMTITLE target pairs in a copied DWG and call the internal A3/A4 batch path while GstarCAD is running a script. The expected behavior is to abort before opening interactive GMTITLE and preserve all candidates.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_a3a4_batch_guard_probe.ps1"
```

Expected result:

```text
Loaded version: 260705-verify-source-priority-a4stepnote
Script active: yes
Status after batch: ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE
Candidates before/after: 2/2
INSERT count before/after: 4/4
Batch guard preserved candidates: yes
Runtime check completed: yes
```

## SWTITLECONVERT Script Guard Probe

Use `run_convert_script_guard_probe.ps1` to confirm that `/b` script automation cannot accidentally drive `SWTITLECONVERT` through the interactive GMTITLE dialog. The probe runs against a copied DWG and expects the command to abort before any drawing data changes.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_convert_script_guard_probe.ps1"
```

Expected result:

```text
Loaded version: 260705-verify-source-priority-a4stepnote
Script active before convert: yes
Status after convert: ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE
Source titles before/after: 13/13
Source frames before/after: 15/15
Frame-only before/after: 2/2
Target titles before/after: 0/0
Target frames before/after: 0/0
INSERT count before/after: 120/120
DBMOD before/after: 0/0
Convert script guard preserved drawing: yes
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
  -Label "current_main50_stylecmp_all_sizes_clean" `
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
  -Label "current_main50_residue_protection"
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

Use `run_embedded_title_prepare_compare_probe.ps1` to verify that native-format title-like geometry inside a `DR_A*_Outline` frame definition is not treated as cleanup by itself.

Current main50:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_embedded_title_prepare_compare_probe.ps1" `
  -LspPath "src\tools\gmtitle\swcad_title_scale.lsp" `
  -Label "current_main50_embedded_prepare" `
  -RunClean
```

Expected result:

```text
Cleanup records by frame: <none>
All embedded title-like records by frame: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline
Structure next action: SWTITLECONVERT
Cleanup deleted count: 0
Cleanup record count after clean: 0
```

Durable conclusion:

```text
docs/investigations/gmtitle-overlap-only-copy-comparison-2026-07-04.md
```

## Current Evidence Index

Tracked conclusions and log excerpts are in:

```text
docs/investigations/gmtitle-main45-verification-index-2026-07-04.md
docs/history/gmtitle-four-command-goal-audit-2026-07-04.md
docs/history/gmtitle-main44-vs-main45-comparison-2026-07-04.md
docs/history/gmtitle-automation-boundary-audit-2026-07-05.md
docs/history/gmtitle-a3-frame-title-behavior-2026-07-05.md
docs/history/gmtitle-a3-status-guidance-2026-07-05.md
docs/history/gmtitle-convert-script-guard-2026-07-05.md
```

## Safety Rules

Use this runner only for read-only probes or scripts that explicitly abort before interactive/write steps.

Do not use `/b` automation to drive `SWTITLECONVERT` through the GMTITLE dialog. `main45` deliberately aborts `SWTITLECONVERT` in SCRIPT mode with `ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE`.

Use a copied DWG under `work/`, not a production or Downloads DWG.

For interactive CAD testing notes, especially the `_PASTECLIP` command-input failure mode and the required `SWTITLEVERSION` preflight, see:

```text
docs/history/gmtitle-cad-input-safety-2026-07-04.md
```
