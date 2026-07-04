# GMTITLE main49 frame-prepare integration - 2026-07-04

## Summary

The plan-copy result was applied to the source LSP as `main49`.

Current source version:

```text
260704-plan-frame-prepare-main-49
```

Current loader version:

```text
260704-4step-gmtitle-main49
```

## Why this change was made

The comparison probe showed that `main48` detected title-like geometry inside `DR_A2_Outline`, `DR_A3_Outline`, and `DR_A4_Outline`, but did not route that condition to `SWTITLEPREPARE` unless a separate `DR_titlea_3rd` title block already overlapped it.

That was not enough for the current goal. The user-reported A3 issue is that the frame definition itself can already contain title-like geometry before conversion, making the frame and title appear merged or duplicated.

Therefore `main49` treats this condition as a pre-conversion cleanup candidate.

## Source changes

Changed:

```text
src/tools/gmtitle/swcad_title_scale.lsp
```

Key behavior:

```text
swcad-title-frame-embedded-title-records
```

now includes both:

```text
source-contaminated
native-format-with-title-geometry
```

as `SWTITLEPREPARE` cleanup candidates.

The cleanup path uses the previously verified block-definition rebuild logic:

```text
swcad-title-frame-style-normalization-delete-records
```

instead of direct `vla-Delete`, because GstarCAD returned an ActiveX error on direct deletion in the fixture while rebuild cleanup succeeded.

## Verification

The full tracked diagnostic suite passed:

```text
diagnostics/gmtitle-main45/run_main45_verification_suite.ps1 -TimeoutSeconds 120
```

Important result:

```text
All expected log markers were verified.
GMTITLE main45 verification suite complete
```

The suite now includes:

```text
1. loader probe
2. current LSP copy compare probe
3. actual work-copy status/verify probe
4. common A2/A3/A4 frame-definition classification probe
5. A2/A3/A4 style-normalization rebuild cleanup probe
6. command-text guard comparison probe
7. sheet residue protection probe
8. embedded-title prepare comparison probe
```

## Key proof

The new embedded-title prepare probe created A2/A3/A4 frame definitions that contain title-like geometry but no separate `DR_titlea_3rd` insert.

`main49` result:

```text
Loaded version: 260704-plan-frame-prepare-main-49
DR_A2_Outline: class=native-format-with-title-geometry, embedded=4
DR_A3_Outline: class=native-format-with-title-geometry, embedded=4
DR_A4_Outline: class=native-format-with-title-geometry, embedded=4
Cleanup records by frame:
  DR_A2_Outline: 4
  DR_A3_Outline: 4
  DR_A4_Outline: 4
Structure next action: SWTITLEPREPARE - 도면틀 정의 안의 표제란 형상을 먼저 정리
Cleanup result: OK
Cleanup deleted count: 12
Cleanup record count after clean: 0
Runtime check completed: yes
```

This proves the main49 source now follows the chosen direction:

```text
Diagnose all DR frame definitions first.
Normalize embedded title geometry before conversion.
Keep the user workflow to SWTITLESTATUS / SWTITLEPREPARE / SWTITLECONVERT / SWTITLEVERIFY.
```

## Safety proof

The command-text guard still blocks conversion:

```text
convert-status-after: ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST
danger-action-after-convert: <none>
```

The residue protection fixture still protects real drawing content:

```text
bottom-left real text preserved: yes
upper small SW_NOTE balloon preserved: yes
upper BOM-like insert preserved: yes
Residue protection passed: yes
```

## Current real work-copy status

The final completion gate still fails, as expected, because the actual work-copy drawing has not been interactively converted yet.

```text
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
```

This is not a code failure. It means the next remaining task is real CAD conversion on a work copy.

## Next CAD sequence

Use only:

```text
APPLOAD
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE   only if SWTITLESTATUS asks for it
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT   repeat only when SWTITLESTATUS says conversion remains
SWTITLEVERIFY
```

Completion is still not proven until:

```text
SWTITLEVERIFY_FINAL_OK
source-title-count: 0
source-frame-count: 0
frame-only-count: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
representative A2/A3/A4 title blocks open the GMTITLE table editor on double-click
real drawing notes, BOM tables, dimensions, and model geometry remain
```
