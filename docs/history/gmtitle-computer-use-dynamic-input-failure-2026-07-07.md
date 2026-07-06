# GMTITLE Computer Use Dynamic Input Failure - 2026-07-07

## Context

The active goal is to keep A2/A3/A4 in one GMTITLE conversion flow and to use CAD live tests only for representative cases.

During the visible work-copy test on:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

Codex confirmed the current LSP status with `SWTITLESTATUS`:

```text
SWTITLE LSP version: 260706-unified-title-missing-11
Result: NEXT_CREATE_FIRST_NATIVE_GMTITLE
Next frame/title: DR_A3_Outline / DR_titlea_3rd
```

## Failure

Computer Use could capture the visible GstarCAD window, but typing commands into the window was not reliable.

Attempts to type `SWTITLEVERSION` and `SWTITLECONVERTNEXT` through Computer Use went to the drawing dynamic input area instead of reliably executing from the CAD command line. The dynamic input interpreted command text as drawing text or an insertion-flow input, leaving visible text-like residue in the drawing area.

The accidental text was removed in the same session, and the latest `SWTITLESTATUS` logs still reported:

```text
실수 명령어 텍스트 후보: 0
도면 데이터는 변경하지 않았습니다.
```

## Rule

Do not use Computer Use to type `SWTITLECONVERTNEXT` into visible GstarCAD.

For visible CAD representative tests:

1. Codex may use Computer Use screenshots to inspect the current CAD state.
2. Codex must not type long commands, LISP expressions, or `SWTITLECONVERTNEXT` into visible GstarCAD.
3. The user must type `SWTITLECONVERTNEXT` directly in the CAD command line.
4. Codex can then read `work\swcad_title_*_last.txt` logs and update code/docs based on the result.

This guard exists because repeating the same visible-CAD typing attempt can create drawing residue and waste time.
