# GstarCAD Dimstyle Tools

SolidWorks DWG dimension-style, tolerance, `DIMLFAC`, and GstarCAD Mechanical fit-conversion tools live here.

## Files

| File | Main commands | Purpose |
| --- | --- | --- |
| `gstarcad_dimstyle_keep_tolerance.lsp` | `SWAUTO`, `SWHELP`, `SWDIMKEEPAMISO`, `SWDEBUG`, `SWFINDSTYLE`, `SWMECHFITSEL`, `SWMECHFITALL`, `SWPURGESTYLES` | Normalize SolidWorks-exported dimension styles while preserving tolerance, `DIMLFAC` and decimal places; convert recognizable fit tolerances for GstarCAD Mechanical workflows. `SWAUTO` compares every dimension before and after and restores unexpected changes. |
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

## Regression test

Close GstarCAD first, then run SWAUTO on copies of real SolidWorks DWGs and compare the drawn dimension text before and after:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gstarcad-dimstyle\run_swauto_value_test.ps1 -InputListFile <list.txt> -Modes "old,new"
```

`<list.txt>` holds one DWG path per line. Sources are only read; results go to `tmp\swauto-value-test\`. See `docs/history/swauto-value-guard-2026-09-29.md`.
