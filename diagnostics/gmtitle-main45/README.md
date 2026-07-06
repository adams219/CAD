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

The probe also summarizes nearby GstarCAD language labels such as "Drawing Borders with Title Block", "Select title block automatically", and "Automatic placement". These are treated as dialog labels/prompts, not as a documented command-line preselection API. The AppData text marker scan is advisory only; any hit there must be inspected manually and is not accepted by itself as proof that `DR_A*_Outline` / `DR_titlea_3rd` can be preselected safely.

If you run the probe with `-DeepRegistrySearch`, `DR_A*_Outline` or `DR_titlea_3rd` may appear under the GstarCAD `Recent File List`. Those entries are only direct-file open history. They are ignored as active `GMTITLE` paper/title preselection evidence unless a non-recent registry value points to the same selection.

Durable conclusion:

```text
docs/history/gmtitle-a4-native-selection-config-probe-2026-07-05.md
docs/history/gmtitle-command-surface-probe-2026-07-05.md
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

The script starts GstarCAD with `WindowStyle=Minimized` by default, waits for `Runtime check completed:`, prints the log, then stops GstarCAD if it is still running. `WindowStyle=Hidden` is still available for debugging, but on this workstation it started GstarCAD without executing the SCR file, while `Minimized` produced the smoke marker.

The runner now fails fast if another `gcad.exe` process is already open. In that state GstarCAD can route `/b` automation through the existing instance or wait behind an active command prompt, so the probe may never load its `.scr` file. Do not kill the user's visible CAD session automatically; save/close it intentionally, then rerun the probe. Use `-AllowExistingGstarCAD` only for deliberate debugging of that failure mode.

## Main45 Verification Suite

Use `run_main45_verification_suite.ps1` to run the standard read-only checks in one command:

Before the hidden GstarCAD probes, the suite now runs two no-CAD preflights:

- next-action card probe. This catches stale-log, missing-log, abort/warn, final-OK, first-native, prepare, and native-upgrade card regressions without opening or changing any DWG.
- visible work-copy opener dry-run. This proves the helper opens only as far as visible work-copy launch preparation by default and does not run `SWTITLECONVERTNEXT`, open GMTITLE, or save the drawing. `/b` startup-status mode is opt-in because it can leave no stable visible CAD window in this Codex session.

1. loader probe
2. current LSP compare-copy probe
3. actual work-copy status/verify probe
4. A4 native exemplar gap probe
5. A4 native outside marker prepare probe
6. title-missing outline convert probe (A4 sample)
7. SWTITLECONVERT script guard probe
8. common A2/A3/A4 frame-definition classification probe
9. A2/A3/A4 style-normalization rebuild cleanup probe
10. command-text guard comparison probe
11. sheet residue protection probe
12. embedded-title prepare copy-comparison probe
13. duplicate target pair comparison probe
14. native adoption gate comparison probe
15. post-first-native marker gate probe
16. A3 status guidance probe
17. A2/A3/A4 native replacement batch guard probe
18. GMTITLE selection config probe

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

Some GstarCAD text logs are written with the Windows Korean code page rather than UTF-8. If a `work\swcad_title_*.txt` file shows broken Korean, use the read-only log reader:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\read_cad_text_log.ps1" `
  -Filter "swcad_title_next_step_last*.txt" `
  -Find "짧은 GMTITLE 선택 카드|용지/도면틀|제목블록|켜둘 옵션|꺼둘 옵션"
```

It tries UTF-8 first and falls back to the Windows default encoding for Korean CAD logs.

The suite also refreshes:

```text
work\lsp_compare\swcad_title_scale_current_main56_compare_copy.lsp
```

from the current source LSP before running the compare-copy probe.

The suite also refreshes a concise latest-run summary:

```text
work\main56_verification_suite_last_run.txt
```

At suite start this file is reset to `Result: RUNNING_OR_FAILED_BEFORE_PASS`. If the suite stops before the final pass gate, it appends `Result: FAILED_BEFORE_PASS` plus the failure message/command. Only a fully successful run rewrites it to `Result: PASS` and records the actual work-copy state, title-missing/frame-only evidence, and native batch guard evidence. Treat this file as the quick current suite summary, but keep using the individual probe logs for detailed diagnosis.

The suite also fails before the first probe if `gcad.exe` is already running and `-WaitForGstarCADClose` is not used. Save the work-copy DWG and close GstarCAD first, otherwise hidden `/b` probes can attach to the visible session and never create their log.

The suite fails if expected log markers are missing. The checked markers include:

```text
no-CAD next-action card probe PASS before hidden GstarCAD starts
loaded main45 versions
four workflow commands enabled
representative legacy commands disabled
actual work-copy source/target counts
A2/A3/A4 expected sheet counts
actual work-copy first native guidance: A2 -> DR_A2_Outline + DR_titlea_3rd
post-first-native marker gate proves an A2 target pair with only SWTITLE markers is not accepted as the first native GMTITLE; real GMTITLE internal native-link evidence is still required before the workflow can advance to the A3 native exemplar step
A4 native exemplar gap: saved default work-copy has two frame-only sources but no DR_A4_Outline definition or target insert yet
A4 clean scratch evidence: `work\scratch_native_a4_clean_260705.dwg` was saved from a clean gcadiso.dwt CAD test after DR_A4_Outline / DR_titlea_3rd inserted at 0,0 without the frame creation error; it still needs the focused A4 native exemplar probe after GstarCAD is closed
A4 native outside marker prepare: imported DR_A4_Outline definitions with official small native outside markers are accepted when effective geometry/raw-selection checks pass; excessive raw bbox or raw-selection warnings still preserve the original A4 source frames
SWTITLECONVERT script guard aborts in SCRIPT mode without changing source/target counts, INSERT count, or DBMOD
mixed/all_contaminated/all_native frame-class PASS results
A2/A3/A4 style-normalization record count 3 -> 0 after rebuild cleanup
command-text guard blocks conversion before any stubbed conversion path
sheet residue protection keeps real text, small SW_NOTE balloons, and BOM-like inserts
embedded-title prepare comparison proves the plan copy routes native-format title geometry to SWTITLEPREPARE before conversion
post-first-native marker gate probe proves the code does not mistake marker-only synthetic target pairs for real native GMTITLE evidence
A3 status guidance probe proves SWTITLESTATUS explains that DR_A3_Outline remains an INSERT/block reference and clone/shared-link candidates are the real unfinished condition
A2/A3/A4 native replacement batch guard probe proves BATCH does not run inside SCRIPT automation and preserves existing candidates
GMTITLE selection config probe records that the checked PaperSet/config/deep-registry locations do not expose an active DR_A*_Outline / DR_titlea_3rd preselection value; Recent File List hits are ignored as direct-file open history
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

For the saved pre-conversion work-copy, the probe should also prove that `SWTITLEVERIFY` does not tell the user to handle title-missing/frame-only sheets before the remaining SolidWorks source title/frame sheets:

```text
title-missing-deferred-note-found: yes
verify-source-priority-note-found: yes
verify-title-missing-first-note-found: no
```

## Actual Work-Copy Direct Status Probe

Use `run_actual_workcopy_direct_status_probe.ps1` when the goal needs the saved state of the real work-copy DWG itself, not a copied diagnostic DWG. This probe opens the saved work-copy with the tracked read-only status fixture, runs `SWTITLEVERSION`, `SWTITLESTATUS`, and `SWTITLEVERIFY`, writes the status log, and does not save the DWG.

Run it only after saving the work-copy and closing visible GstarCAD, because hidden `/b` probes can be routed to an already-open GstarCAD session.
The default timeout is 180 seconds. On this workstation a 90 second direct work-copy probe can occasionally time out before the status log is written, even though the shorter smoke probe passes.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_actual_workcopy_direct_status_probe.ps1"
```

Default input:

```text
work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

Default output:

```text
work\swtitle_actual_workcopy_direct_status_260705.txt
```

Current saved actual-workcopy baseline:

```text
DWG: C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
status-after-status: NEXT_CREATE_MISSING_NATIVE_EXEMPLAR
status-after-verify: SWTITLEVERIFY_FINAL_FAIL
source-title-count: 12
source-frame-count: 14
frame-only-count: 2
target-title-count: 1
target-frame-count: 1
next-bootstrap-frame: DR_A3_Outline
next-bootstrap-title: DR_titlea_3rd
dbmod-after-commands: 0
```

## Next CAD Action Card

Use `run_next_cad_action.ps1` when you want the short visible-CAD instruction card without the full goal-status evidence report.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_next_cad_action.ps1"
```

It reads the direct actual work-copy probe log and prints only:

```text
current saved status
exact visible GstarCAD command
GMTITLE paper/title/options to choose
abort conditions
after-conversion verification step
```

For the current saved baseline it should report:

```text
Result: CREATE_MISSING_NATIVE_GMTITLE_SIZE
용지/도면틀: DR_A3_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
변환/정리 후: SWTITLESTATUS
```

Use `run_next_cad_action_card_probe.ps1` to test the card state machine without launching GstarCAD or editing a DWG:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_next_cad_action_card_probe.ps1"
```

It checks representative status codes such as first-native creation, title-missing outline prepare, A2/A3/A4 native replacement, review/abort states, final OK, stale logs, and missing logs.

Expected result:

```text
Next CAD action card probe result: PASS
```

2026-07-05 visible-CAD Computer Use check:

```text
GstarCAD launched as Drawing1.dwg.
get_window_state captured the GstarCAD window and recovery panel.
activate_window timed out.
click on the recovery panel close button failed with: failed to activate captured window.
No work-copy DWG was opened and no drawing data was changed.
```

So this card intentionally says `수동 GstarCAD 단계`. Use Computer Use screenshots for inspection only unless a later session proves activation and input work reliably.

The card now interprets common saved status codes directly:

```text
NEXT_CREATE_FIRST_NATIVE_GMTITLE / NEXT_CREATE_MISSING_NATIVE_EXEMPLAR -> SWTITLECONVERTNEXT, or SWTITLECONVERT only when choosing responses manually
NEXT_UPGRADE_NATIVE_GMTITLE -> SWTITLECONVERTNEXT native replacement, or SWTITLECONVERT only when choosing OPEN/BATCH/MANUAL manually
NEXT_PREPARE_* -> SWTITLEPREPARE, then SWTITLESTATUS
NEXT_REVIEW_* / ABORT_* / WARN_* -> do not repeat SWTITLECONVERTNEXT/SWTITLECONVERT; inspect SWTITLESTATUS/SWTITLEVERIFY logs first
SWTITLEVERIFY_FINAL_OK -> manual representative title-block double-click check
```

It also refuses stale direct-probe logs. If the work-copy DWG was saved after the direct-probe log, the card returns `REFRESH_DIRECT_PROBE_FIRST` before showing another CAD command.

Use `-AutoRefreshDirectProbe` only after saving and closing visible GstarCAD. The card runs `run_actual_workcopy_direct_status_probe.ps1` when the direct-probe log is missing, points to a different DWG, is older than the work-copy DWG save time, or was generated with a different GMTITLE LSP version. If the existing log already matches the same work-copy, save time, and current LSP version, the card reuses it and prints that reuse decision instead of launching GstarCAD again.

The card also compares the latest final completion gate log with the direct-probe log. If `swtitle_final_completion_gate_status.txt` is newer and disagrees with the direct-probe status, verify result, or next native GMTITLE frame/title, the card returns `REVIEW_FINAL_GATE_DIRECT_PROBE_CONFLICT` instead of recommending another CAD command. Refresh the direct probe or rerun the final completion gate before continuing.

### After Manual GMTITLE Step Wrapper

After one visible-CAD GMTITLE step is finished, save the work-copy DWG and close GstarCAD, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_after_manual_gmtitle_step.ps1" `
  -Compact
```

This wrapper does not edit the DWG. It checks that visible GstarCAD is closed, runs `run_next_cad_action.ps1 -AutoRefreshDirectProbe`, writes `work\swtitle_after_manual_gmtitle_step_last.txt`, and prints a short next-step summary from fresh direct-probe evidence. The full next-action card is kept in the log. If the refreshed card indicates final verification is ready, it also runs `run_final_completion_gate.ps1` and reports whether automated completion evidence passed.

Use `-WaitForGstarCADClose` if the command should wait while you save and close GstarCAD:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_after_manual_gmtitle_step.ps1" `
  -WaitForGstarCADClose
```

Use `-DryRun` to check the wrapper flow without launching hidden GstarCAD probes. Use `-SkipFinalCompletionGate` when you only want the refreshed next-action card, even if the card is near the final verification stage.

### Manual GMTITLE Session Wrapper

If you want one PowerShell command to open the work-copy, wait while you do one visible GMTITLE step, and then run the after-manual check automatically, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_manual_gmtitle_session.ps1"
```

Before opening visible CAD, the session wrapper runs `run_next_cad_action.ps1` without auto-refresh by default and continues only when the card asks for one visible conversion step, such as `READY_FOR_FIRST_NATIVE_GMTITLE`, `CREATE_MISSING_NATIVE_GMTITLE_SIZE`, `RUN_NATIVE_REPLACEMENT`, `RUN_REMAINING_CONVERSION`, or `RELOAD_LSP_AND_CONFIRM_STATUS`. Use the wrapper's `-AutoRefreshDirectProbe` option only when GstarCAD is saved/closed and you explicitly want to refresh hidden direct-probe evidence first.

The session wrapper opens the work-copy through `run_open_workcopy_for_manual_convert.ps1`, prints the manual CAD commands, waits for GstarCAD to close, and then runs `run_after_manual_gmtitle_step.ps1`. It does not run `SWTITLECONVERTNEXT`, does not click the GMTITLE dialog, and does not save the drawing.

Use `-SkipOpenWorkcopy` only if the work-copy is already open in a running GstarCAD process and you only want the wait-and-check part. In that mode, the initial hidden next-action card is skipped because visible CAD is already open; run `SWTITLESTATUS` in that visible session before converting. If no GstarCAD process is detected, the wrapper stops with `SKIP_OPEN_NO_GSTARCAD` instead of running a stale after-manual check. Use `-SkipInitialNextActionCard` only after you have already confirmed the current visible CAD status. Use `-DryRun` to verify the wrapper sequence without launching visible GstarCAD.

Use `-PreflightOnly` when you want the refreshed next-action card and short GMTITLE selection summary without opening visible CAD. This is the safest way to confirm the next paper/frame and title block before starting a manual CAD session. Add `-Compact` when you want to suppress the long next-action card body and print only the short summary.

## A4 Outline Prepare Probe

Use `run_a4_outline_prepare_probe.ps1` to copy a work DWG, load the current GMTITLE LSP, and run the internal title-missing/frame-only `DR_A*_Outline` definition preflight on the copy.

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

Expected result for the current installed `DR_A4_Outline` state:

```text
Loaded version: 260706-unified-title-missing-8
Before definition status: missing
Prepare result: OK status=OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED
After definition status: ready-native-outside-markers
After frame-only-count: 2
Runtime check completed: yes
```

This is a readiness pass, not a completed conversion. It proves that the tool accepts the official native outline only after the test insert has correct effective sheet geometry and no raw-selection warning. The production conversion still must not create a `DR_titlea_3rd` for source title-missing/frame-only sheets.

## A4 Outline Convert Probe

Use `run_a4_outline_convert_probe.ps1` to copy a work DWG, prepare the official native `DR_A*_Outline` definition, and run the title-missing/frame-only conversion on the copy.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_a4_outline_convert_probe.ps1"
```

Default log:

```text
work\swtitle_a4_outline_convert_probe_260705.txt
```

Expected result:

```text
Prepare result: OK status=OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED
After prepare definition status: ready-native-outside-markers
Convert result: OK status=FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER
After source-title-count: 12
After frame-only-count: 1
After target title count: 1
After DR_A4_Outline target frame count: 1
After target-sheet-counts:
  A2: 1
  A4: 1
Runtime check completed: yes
```

This proves the title-missing/frame-only path replaces one source frame with a matching native `DR_A*_Outline` frame without creating an extra `DR_titlea_3rd` title block.

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

Use `run_a4_native_exemplar_probe.ps1` to check whether a saved DWG already contains a usable native or native-like A4 `DR_A4_Outline` exemplar. The runner intentionally has no default input, so a default work-copy cannot be mistaken for a scratch native A4 sample.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1" `
  -SourceDwgPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\<scratch-native-a4>.dwg" `
  -LogPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt" `
  -WaitForGstarCADClose
```

`-WaitForGstarCADClose` lets the runner wait while you save and close the visible scratch GstarCAD session. Without that option, the runner stops if `gcad.exe` is already open, because hidden `/b` probes can attach to the visible session and produce misleading logs.

No-argument result:

```text
A4_NATIVE_EXEMPLAR_REQUIRES_SOURCEWORKCOPYPATH
```

Default log when an input path is supplied:

```text
work\swtitle_a4_native_exemplar_probe_260705.txt
```

For the clean A4 scratch from 2026-07-05, use a dedicated log so the main suite's default work-copy A4 gap probe does not overwrite the useful scratch result:

```text
work\swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt
```

The main verification suite still runs the known gap check by passing the saved default work-copy path explicitly. Current expected suite result for that saved default work copy:

```text
A4 outline definition status: missing
Definition exists: no
Visible DR_A4_Outline frame inserts: 0
Result: A4_NATIVE_EXEMPLAR_MISSING_DEFINITION
```

This probe is useful after manually creating or saving a scratch/native A4 GMTITLE sheet. A fully clean result shows a clean A4 definition, no geometry/raw-selection warning, and:

```text
Native GMTITLE A4 pair evidence: yes
Result: A4_NATIVE_EXEMPLAR_READY_FOR_COMPARISON
```

2026-07-05 clean `gcadiso.dwt` scratch result:

```text
Native GMTITLE A4 pair evidence: yes
Definition raw risk: <none>
Definition test insert geometry warning: <none>
Definition test insert raw selection warning: <none>
Definition minor native outside markers: yes
Result: A4_NATIVE_EXEMPLAR_READY_WITH_NATIVE_OUTSIDE_MARKERS
```

That result is intentionally not collapsed into `UNSAFE_DEFINITION`. It means GstarCAD can create a real native GMTITLE pair, but the official native `DR_A*_Outline` definition may carry small outside marker geometry. Production title-missing/frame-only conversion must still decide explicitly whether to tolerate, crop, or preserve those official native outside markers, and it must not create an extra `DR_titlea_3rd` for a source sheet that had no title block.

If a scratch DWG contains only a clean-looking `DR_A4_Outline` frame but no nearby `DR_titlea_3rd` with native GMTITLE link evidence, the probe reports:

```text
Result: A4_NATIVE_EXEMPLAR_MISSING_NATIVE_PAIR
```

That failure is intentional. A frame-only production result must not create a new title block, but the separate scratch comparison sample must still prove that the `DR_A4_Outline` came from a native GMTITLE structure rather than from an arbitrary block definition.

The scratch/native sheet is only for comparison. It may include `DR_titlea_3rd` if native GMTITLE creates one, but production title-missing/frame-only conversion must still not create a title block that was not present in the source.

2026-07-05 CAD evidence: even when the GMTITLE dialog is manually set to `DR_A4_Outline`, `DR_titlea_3rd`, Frame positioning ON, and Object move OFF, GstarCAD can return `프레임 작성 오류`. If the follow-up status still shows `DR_titlea_3rd` inserts=0, that scratch DWG is failed evidence, not an A4 native exemplar.

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

Save and close GstarCAD first, or use `-WaitForGstarCADClose` and close GstarCAD while the gate waits:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_final_completion_gate.ps1" `
  -WaitForGstarCADClose
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

When it fails, it now prints:

```text
Final completion gate result: FAIL
Current status-after-status: ...
Current status-after-verify: ...
Current source counts: source-title-count=..., source-frame-count=..., frame-only-count=...
Current target counts: target-title-count=..., target-frame-count=...
Next first native GMTITLE selection: source-sheet=..., frame=..., title=...
Missing native frames: ...
Missing completion evidence:
Next: run_next_cad_action.ps1
```

Treat that as a strict incomplete result, not as a partial success. Use the printed next-action card command to return to the guided CAD workflow.

The final completion gate uses a default timeout of 180 seconds. On this workstation, 90 seconds can occasionally start GstarCAD but miss the SCR completion log, which produces a log-missing failure instead of useful completion evidence.

When the automated evidence passes, completion is still not proven until representative `DR_titlea_3rd` title blocks open the GMTITLE table editor on double-click. Title-missing/frame-only sheets do not have a `DR_titlea_3rd` title block by design; confirm the matching `DR_A*_Outline` count and geometry through `SWTITLEVERIFY` instead.

## GstarCAD /b Script Smoke Probe

Use `run_hidden_script_smoke_probe.ps1` before trusting the GstarCAD `/b` CAD probes. It opens a copied work DWG with a one-line AutoLISP script and verifies that GstarCAD actually executes the SCR file.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_hidden_script_smoke_probe.ps1"
```

Expected result:

```text
GstarCAD /b script smoke probe result: PASS
```

If this fails with no log, do not treat later loader/probe log-missing failures as GMTITLE logic failures. It means `/b` script delivery is not working with the selected window style in the current PC session. Save and close visible GstarCAD, rerun with a longer `-TimeoutSeconds`, and prefer the default `-WindowStyle Minimized` on this workstation. If it still fails, continue the visible `SWTITLECONVERT` workflow and verify the real work-copy with `SWTITLESTATUS` / `SWTITLEVERIFY`.

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
Loaded loader version: 260706-loader-convert-next-response-guidance
Loaded GMTITLE version: 260706-unified-title-missing-8
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
Loaded version: 260706-unified-title-missing-8
A2/A3/A4 candidate count before SWTITLESTATUS: 1
SWTITLESTATUS result: OK
Status after SWTITLESTATUS: NEXT_UPGRADE_NATIVE_GMTITLE
A3 frame guidance note found: yes
A3 native-candidate supplement found: yes
A3 status guidance probe passed: yes
Runtime check completed: yes
```

## A2/A3/A4 Native Replacement Batch Guard Probe

Use `run_a3a4_batch_guard_probe.ps1` to create synthetic cloned GMTITLE target pairs in a copied DWG and call the internal A2/A3/A4 native replacement batch path while GstarCAD is running a script. The expected behavior is to abort before opening interactive GMTITLE and preserve all candidates.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_a3a4_batch_guard_probe.ps1"
```

Expected result:

```text
Loaded version: 260706-unified-title-missing-8
Script active: yes
Status after batch: ABORT_NATIVE_GMTITLE_BATCH_SCRIPT_ACTIVE
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
Loaded version: 260706-unified-title-missing-8
Script active before convert: yes
Status after convert: ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE
Source titles before/after: 12/12
Source frames before/after: 14/14
Frame-only before/after: 2/2
Target titles before/after: 1/1
Target frames before/after: 1/1
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
structure-next-action: SWTITLEPREPARE - 실수 명령어 텍스트 잔여물을 먼저 확인/정리해야 합니다
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
Structure next action: SWTITLECONVERTNEXT
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
