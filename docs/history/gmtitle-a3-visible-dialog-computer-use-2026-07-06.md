# GMTITLE A3 Visible Dialog Computer Use Check - 2026-07-06

## Purpose

Check whether Codex Computer Use can safely finish the next real work-copy step after the static and hidden CAD probes passed.

Target work-copy:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

Expected next native GMTITLE selection from `SWTITLESTATUS`:

```text
paper/frame: DR_A3_Outline
title block: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

## What Worked

The visible GstarCAD work-copy opened successfully with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_open_workcopy_for_manual_convert.ps1
```

The CAD-side `SWTITLESTATUS` log was refreshed on the real work-copy and confirmed:

```text
SWTITLE LSP version: 260706-unified-title-missing-3
Result: NEXT_CREATE_MISSING_NATIVE_EXEMPLAR
Next missing native GMTITLE selection:
  source sheet: A3
  paper/frame: DR_A3_Outline
  title block: DR_titlea_3rd
  role: title-sheet
```

`SWTITLECONVERTNEXT` started correctly and wrote `work\swcad_title_transfer_apply_last.txt`.
The log proved that the command identified the correct A3 source title/frame and prepared the expected values:

```text
source title insert: 0100_DR_<Korean title block>_FTAP
source frame insert: 0100_DR-A3_FROM_HYUN
expected native frame: DR_A3_Outline
expected title block: DR_titlea_3rd
detected sheet size: A3
lower-left placement point: (663.86724324, 0.08373751, 0)
```

## What Did Not Work

Computer Use could see the GMTITLE dialog in the accessibility tree:

```text
dialog: Drawing Borders with Title Block / Korean GMTITLE dialog
paper format combo: ID 3010
title block combo: ID 3011
Frame positioning checkbox: ID 3022
Object move checkbox: ID 3024
OK button: ID 1
Cancel button: ID 2
```

But it could not safely operate the dialog:

```text
set_value on the paper/title combo failed because the UIA value is read-only.
clicking the dropdown by accessibility index failed because the point was reported over a child gcad.exe dialog, not the captured main GstarCAD target window.
the dialog was not exposed as a separate targetable window by list_windows().
```

Because of that, Codex did **not** click screen coordinates to choose the paper/title. The command was cancelled with `Esc`, and the drawing was not saved.

## Decision

Do not automate the GMTITLE dialog paper/title dropdown selection with Computer Use yet.

Keep the current boundary:

```text
LSP automates:
  source detection
  value extraction
  lower-left placement point
  new GMTITLE result validation
  attribute fill
  old SolidWorks cleanup
  rollback/safety guards

human confirms:
  DR_A*_Outline paper/frame in the GMTITLE dialog
  DR_titlea_3rd title block
  Frame positioning ON
  Object move OFF
```

This is not a failure of the unified A2/A3/A4 flow. It is evidence that the next unsafe automation target is the GMTITLE dialog UI itself, not the sheet-size logic.

## Follow-Up

Only remove the human confirmation step when one of these is proven:

```text
1. a documented command/API can preselect DR_A*_Outline and DR_titlea_3rd, or
2. Computer Use can target the GMTITLE dialog as a stable window and read/write its selected values, or
3. a post-insert validation/rollback loop can safely recover from wrong paper/title selection without relying on screen coordinates.
```

Until then, use `SWTITLECONVERTNEXT` and let the user confirm one GMTITLE dialog when the status card asks for it.
