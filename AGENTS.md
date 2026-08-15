# AGENTS.md

## Cursor Cloud specific instructions

### What this repository is
This repo is a collection of **AutoLISP (`.lsp`) automation tools** for **GstarCAD / GstarCAD Mechanical / SolidWorks DWG** workflows (XREF-driven sheet conversion, GMTITLE title-block conversion, dimension-style migration, fit-tolerance xdata). See `README.md`, `docs/swcad-workflow/` (integrated workflow), and `docs/guide/` (mostly Korean) for the command surface.

It is **not** a compiled/packaged project: there is no package manager, build system, automated test suite, or linter. Source files are plain UTF-8 text with LF endings (enforced by `.gitattributes`). The "dependencies" are effectively none — there is nothing to `npm install` / `pip install`. Packaging for Windows distribution uses `apps/swcad-workflow/package.ps1` + `Install_SWCAD_Workflow.cmd` (PowerShell/cmd; Windows-only).

### Running the product (important caveat)
The tools run **inside GstarCAD/GstarCAD Mechanical on Windows**. **This runtime is Windows-only proprietary CAD software and cannot be executed in the Linux Cloud Agent VM.** Do not attempt to "start a server" or run the app here — there is no runnable service. End-to-end behavioral testing requires a Windows CAD host and is out of scope for the cloud VM.

### Entry points & load behavior
Two loaders exist; pick one based on the workflow:

| Loader | Purpose | Main commands |
| --- | --- | --- |
| `apps/swcad-workflow/swcad_workflow_load.lsp` | Integrated XREF → GMTITLE → dim/fit → Layout workflow (preferred for new work). | `SWCADSTATUS`, `SWCADRUN`, `SWCADVERIFY` |
| `swcad_load.lsp` | Legacy/tool-level loader (`src/lsp/` + `src/tools/`). | `SWAUTO`, `SWHELP`, `SWTITLE*` |

Both resolve the repo root by probing for known module paths and wrap each `load` in `vl-catch-all-apply`. A malformed `.lsp` (unbalanced parens/strings) is the main thing that breaks loading. GMTITLE dialog auto-select also ships `src/tools/gmtitle/swtitle_gmtitle_dialog_autoselect.ps1` next to the LSP (Windows PowerShell helper).

Diagnostic / regression probes live under `diagnostics/gmtitle-main45/` and `diagnostics/swcad-workflow/` — they are CAD-host probes, not CI tests.

### GMTITLE edits: Cursor copy only
When changing GMTITLE behavior or UX, edit **only** the Cursor experiment copy. Leave the original production files untouched so they stay available for comparison.

| Role | File | Commands | Loader |
| --- | --- | --- | --- |
| Original (do not edit) | `src/tools/gmtitle/swcad_title_scale.lsp` | `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERTNEXT`, `SWTITLEVERIFY` | `swcad_load.lsp` |
| Cursor working copy | `src/tools/gmtitle/cursor_swcad_title_scale_ux.lsp` | `CURSORSWTITLEUXSTATUS` (compact), `CURSORSWTITLEUXSTEP`, `CURSORSWTITLEUXSTATUSDETAIL`, then PREPARE/CONVERTNEXT/VERIFY | `src/tools/gmtitle/cursor_swcad_title_scale_ux_load.lsp` |

Do not APPLOAD both GMTITLE files in the same CAD session: internal `swcad-title-*` symbols collide. Do not point `swcad_load.lsp` at the Cursor copy unless the user explicitly asks to promote it.

### Practical validation in the cloud VM
Since the CAD runtime is unavailable, the meaningful local check is **structural validation of the AutoLISP source** (balanced parentheses/strings, honoring `;` line comments, `;| ... |;` block comments, and `\"` string escapes). This mirrors the loader's per-module `load` step. There is no committed lint/test script; validate structurally (e.g. a small paren/quote-balance pass over every `.lsp`) before considering an edit "loadable". Do not claim behavioral correctness from this alone — it only proves the files will parse/load.

### Binary assets & scratch space
- CAD binaries (`*.dwg`, `*.dxf`, SolidWorks parts, PDFs, images, etc.) are routed through **Git LFS** via `.gitattributes`. Ensure LFS filters are active (`git lfs install`) before adding/checking out such files.
- `work/` holds throwaway scratch (`work/*.dwg|lsp|scr|txt` are gitignored). Verified LSP graduates to `src/`, finalized docs to `docs/`.
