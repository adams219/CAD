# LSP Work History

This document records the first CAD repository import of the GstarCAD LSP utilities.

## 2026-06-26 Initial CAD Repository Import

Imported from the local SolidWorks automation workspace:

```text
C:\Users\DR-DESIGN\Documents\솔리드웍스 자동화\tools
```

Imported files:

- `tools/gstarcad_dimstyle_keep_tolerance.lsp`
- `tools/gstarcad_dimstyle_keep_tolerance_사용법.md`
- `tools/gstarcad_layout_from_model.lsp`
- `tools/gstarcad_layout_사용법.md`
- `tools/gstarcad_sdk_fit_tolerance_analysis.md`

Source repository at import time:

```text
https://github.com/adams219/Solidworks-automation.git
branch: main
HEAD: 5592212 Add Codex cloud handoff and reducer trial results
```

Important note:

The source `tools/` folder was untracked in the SolidWorks automation repository at import time, so these LSP files did not have prior per-file git commit history to preserve. This CAD repository commit becomes the first git-tracked baseline for these tool copies.

## Tool Summary

### `gstarcad_dimstyle_keep_tolerance.lsp`

Main workflow:

```text
APPLOAD -> SWAUTO -> GMPOWEREDIT check -> QSAVE
```

Key commands:

- `SWAUTO`: run AM_ISO style mapping, regenerate, convert Mechanical fit data where possible, regenerate again, audit, and clean unused SolidWorks dimension styles.
- `SWHELP`: print the daily workflow and troubleshooting command list.
- `SWDIMKEEPAMISO`: normalize current-tab dimensions to AM_ISO family styles while preserving meaningful tolerance overrides.
- `SWDEBUG`: inspect one dimension's target style, tolerance values, fit code, `DIMLFAC`, and related size variables.
- `SWFINDSTYLE`: find dimensions and deeper references using old SolidWorks dimension style patterns such as `*SLDDIMSTYLE*`.
- `SWMECHFITSEL` / `SWMECHFITALL`: convert selected or all eligible fit-code dimensions for GstarCAD Mechanical workflows.

Primary reason for the tool:

SolidWorks DWG exports often encode tolerances in generated dimension styles. A direct style change can remove the visible tolerance or alter scale behavior. This LSP bakes useful per-dimension tolerance information into overrides before moving dimensions onto target AM_ISO styles.

### `gstarcad_layout_from_model.lsp`

Main workflow:

```text
APPLOAD -> GSA4CHECK -> GSA4GO -> GSA4VERIFY -> GSA4PDF
```

Key commands:

- `GSA4CHECK`: check PDF plotter, A4 media, plot style, rotation, and generated layout prefix.
- `GSA4GO`: pick a model-space drawing frame, detect matching frames on the same output row, and create `SHEET-*` layouts.
- `GSA4VERIFY`: report generated layout paper size, viewport window, view center, and scale.
- `GSA4CLEAN`: delete generated `SHEET-*` layouts.
- `GSA4PDF`: plot generated layouts to individual PDF files.

Primary reason for the tool:

Some DWG files contain multiple drawing frames arranged in model space instead of separate paper-space layouts. This LSP creates repeatable A4 layout tabs and PDF outputs from those frames.

## Next Planned CAD Diagnostics

For the current GstarCAD/GstarCAD Mechanical scale issue, keep the first scanner read-only and separate from the long `SWAUTO` file.

Candidate commands:

- `SWTITLEDEBUG`
- `SWTITLESCAN`
- `SWSCALESCAN`
- `SWSCALEDUMP`

The scanner should collect title-block clues such as `GMTITLE` / `FTAP`, `DIMLFAC`, dimension style scale, drawing units, viewport scale, and visible scale text before any automatic repair is attempted.
