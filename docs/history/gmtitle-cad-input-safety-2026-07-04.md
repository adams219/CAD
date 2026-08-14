# GMTITLE CAD Input Safety Note - 2026-07-04

## Purpose

This note records a repeated CAD testing failure mode so future GstarCAD checks do not repeat it.

The issue is not the four-command GMTITLE implementation itself. The issue is that Windows UI automation can send text to the drawing canvas instead of the GstarCAD command line. When that happens, GstarCAD may run `_PASTECLIP` and place the typed command text as visible drawing geometry.

## What Happened

During a probe DWG test, the currently loaded GMTITLE LSP was first confirmed to be stale:

```text
SWTITLE LSP version: 260704-frame-definition-first-main-43
```

The current source LSP was then loaded directly and confirmed as:

```text
260704-command-text-guard-main-48
```

After that, `SWTITLESTATUS` successfully updated the latest status log and reported:

```text
NEXT_CREATE_MISSING_NATIVE_EXEMPLAR
missing native exemplars: DR_A3_Outline, DR_A4_Outline
next command: SWTITLECONVERT
```

However, several attempts to send `SWTITLECONVERT` through UI automation were routed to the drawing area instead of the command prompt. GstarCAD entered `_PASTECLIP` and inserted visible command text into the probe drawing.

This happened only on a probe copy:

```text
work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03_main43_status_probe_260704.dwg
```

The production/source DWG was not edited.

## Do Not Repeat

Do not treat a focused-looking command line accessibility element as proof that text entry will go to the command line.

Do not use broad screen coordinates to type CAD commands while the drawing canvas can receive input.

Do not continue GMTITLE conversion if `_PASTECLIP`, `PASTECLIP insertion point`, or visible command text appears in the drawing.

Do not continue CAD testing if `SWTITLEVERSION` does not show the current expected version:

```text
260704-command-text-guard-main-48
```

## Required Preflight For Future CAD Tests

Before any interactive `SWTITLECONVERT` test:

1. Open only a copied DWG under `Documents\CAD tool\work`.
2. Load the exact current LSP:

```lisp
(load "C:/Users/DR-DESIGN/Documents/CAD tool/src/tools/gmtitle/swcad_title_scale.lsp")
```

3. Run `SWTITLEVERSION`.
4. Confirm the loaded version is:

```text
260704-command-text-guard-main-48
```

5. Run `SWTITLESTATUS`.
6. Confirm the log path and DWG path refer to the intended work copy.
7. Only then run `SWTITLECONVERT`.

## Additional Input Failure Mode

Key-by-key input is safer than bulk paste, but it can still drop a character if GstarCAD is busy or focus changes while typing.

This happened during a later probe: `SWTITLECONVERT` was entered as `SWTITLECONVER`. Sending the final `T` afterward started GstarCAD's text command instead of completing the intended command.

Required rule:

1. Type the command slowly.
2. Before pressing Enter, inspect the focused command-line text.
3. Press Enter only if the full command text is exactly visible.
4. If the text is incomplete or wrong, cancel with Escape and retype the full command. Do not append missing letters after Enter.

## Safe Interactive GMTITLE Selection Checklist

When the GMTITLE dialog opens, verify the values shown by the latest log:

```text
Paper/frame: DR_A2_Outline, DR_A3_Outline, or DR_A4_Outline as requested
Title block: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

If GstarCAD shows a cursor or temporary handle in the middle of the sheet, do not use that as the alignment reference. The LSP log prints the intended lower-left placement point.

If GstarCAD asks for object move/new location, cancel and reopen GMTITLE with `Object move` turned off.

## Current State After This Note

The current main48 code has already passed the read-only/synthetic verification suite, including the A2/A3/A4 style-normalization rebuild probe and the command-text guard comparison probe.

Actual completion is still not proven until a real work-copy conversion reaches:

```text
SWTITLEVERIFY_FINAL_OK
source-title-count: 0
source-frame-count: 0
frame-only-count: 0
A2: 1
A3: 12
A4: 2
```

and representative A2/A3/A4 `DR_titlea_3rd` title blocks open the GMTITLE table editor on double-click.
