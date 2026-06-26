# CAD Tool

SolidWorks CAD files, exported DWG files, bound GstarCAD/GstarCAD Mechanical drawings, GstarCAD LSP utility copies, and scale-diagnostic samples live here.

The separate SolidWorks/GstarCAD automation repository can still be used for broader experiments and analysis. This repository is the CAD-facing place for source assets, reproducible sample drawings, release-ready LSP utilities, and diagnostic evidence.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `cad/solidworks/parts/` | Master `.SLDPRT` part files. |
| `cad/solidworks/assemblies/` | Master `.SLDASM` assembly files. |
| `cad/solidworks/drawings/` | Master `.SLDDRW` drawing files. |
| `cad/dwg/exported/` | Raw DWG/DXF exports from SolidWorks. |
| `cad/dwg/xref/` | GstarCAD XRef source drawings before binding. |
| `cad/dwg/bound/` | Bound DWG files after XRef + Bind workflows. |
| `samples/cases/` | Minimal reproducible drawing sets for investigation. |
| `diagnostics/` | Scale scans, dumps, screenshots, and analysis notes. |
| `docs/` | Repository policy and drawing management notes. |
| `tools/` | GstarCAD/GstarCAD Mechanical LSP utilities and usage notes. |

## Git LFS

This repository tracks CAD binaries and large drawing artifacts with Git LFS through `.gitattributes`.

Run once after cloning if needed:

```powershell
git lfs install
git lfs pull
```

Recommended LFS file types include SolidWorks files, DWG/DXF, STEP/IGES/Parasolid exports, PDFs, screenshots, and zipped sample packs.

## Working Rule

Keep each investigation reproducible:

1. Put original SolidWorks or DWG inputs under `cad/` or `samples/cases/<case-id>/input/`.
2. Put converted or bound results under `samples/cases/<case-id>/output/` when they belong to a specific test case.
3. Put scan results, command logs, screenshots, and notes under `diagnostics/`.
4. Record the drawing in `docs/sample-drawing-register.md`.

## LSP Tools

Current tool copies:

- `tools/gstarcad_dimstyle_keep_tolerance.lsp`
- `tools/gstarcad_layout_from_model.lsp`
- `tools/gstarcad_dimstyle_keep_tolerance_사용법.md`
- `tools/gstarcad_layout_사용법.md`
- `tools/gstarcad_sdk_fit_tolerance_analysis.md`

See `tools/README.md` and `docs/lsp-work-history.md`.

## License

Commercial use is not granted by default. See `LICENSE.md` for the repository license notice.
