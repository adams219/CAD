# GstarCAD LSP Tools

This folder contains CAD-facing copies of the LSP tools that are ready to load and test in GstarCAD or GstarCAD Mechanical.

## Files

| File | Main commands | Purpose |
| --- | --- | --- |
| `gstarcad_dimstyle_keep_tolerance.lsp` | `SWAUTO`, `SWHELP`, `SWDIMKEEPAMISO`, `SWDEBUG`, `SWFINDSTYLE`, `SWMECHFITSEL`, `SWMECHFITALL` | Normalize SolidWorks-exported dimension styles while preserving tolerance and scale-related overrides such as `DIMLFAC`; convert recognizable fit tolerances for GstarCAD Mechanical workflows. |
| `gstarcad_layout_from_model.lsp` | `GSA4CHECK`, `GSA4GO`, `GSA4VERIFY`, `GSA4CLEAN`, `GSA4PDF` | Create A4 PDF-oriented layouts from multiple drawing frames arranged in model space. |
| `gstarcad_dimstyle_keep_tolerance_사용법.md` | Documentation | Daily workflow and troubleshooting notes for `SWAUTO`. |
| `gstarcad_layout_사용법.md` | Documentation | Usage notes for model-space frame to layout automation. |
| `gstarcad_sdk_fit_tolerance_analysis.md` | Analysis | SDK investigation notes for Mechanical fit tolerance automation. |

## Loading

In GstarCAD:

```text
APPLOAD
```

Then load the required `.lsp` file from this folder.

For the dimension and tolerance workflow, the usual command is:

```text
SWAUTO
```

For the layout workflow, start with:

```text
GSA4CHECK
GSA4GO
GSA4VERIFY
```

## History

See `../docs/lsp-work-history.md`.
