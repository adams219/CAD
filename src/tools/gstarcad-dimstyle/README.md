# GstarCAD Dimstyle Tools

SolidWorks DWG dimension-style, tolerance, `DIMLFAC`, and GstarCAD Mechanical fit-conversion tools live here.

## Files

| File | Main commands | Purpose |
| --- | --- | --- |
| `gstarcad_dimstyle_keep_tolerance.lsp` | `SWAUTO`, `SWHELP`, `SWDIMKEEPAMISO`, `SWDEBUG`, `SWFINDSTYLE`, `SWMECHFITSEL`, `SWMECHFITALL`, `SWPURGESTYLES` | Normalize SolidWorks-exported dimension styles while preserving tolerance and scale-related overrides such as `DIMLFAC`; convert recognizable fit tolerances for GstarCAD Mechanical workflows. |
| `gstarcad_dimstyle_keep_tolerance_사용법.md` | Documentation | Daily workflow and troubleshooting notes for `SWAUTO`. |
| `gstarcad_sdk_fit_tolerance_analysis.md` | Analysis | SDK investigation notes for Mechanical fit tolerance automation. |

## Loading

The recommended daily entry point is the root loader:

```text
APPLOAD
swcad_load.lsp
SWAUTO
```

For direct testing, load this file:

```text
src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance.lsp
```
