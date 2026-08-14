# AGENTS.md

## Cursor Cloud specific instructions

### What this repository is
This repo is a collection of **AutoLISP (`.lsp`) automation tools** for **GstarCAD / GstarCAD Mechanical / SolidWorks DWG** workflows (dimension-style migration, fit-tolerance xdata, and GMTITLE title-block conversion). See `README.md` and `docs/guide/` (mostly Korean) for the command surface, and `docs/guide/commands.md` for the public command list.

It is **not** a compiled/packaged project: there is no package manager, build system, automated test suite, or linter. Source files are plain UTF-8 text with LF endings (enforced by `.gitattributes`). The "dependencies" are effectively none — there is nothing to `npm install` / `pip install`.

### Running the product (important caveat)
The tools run **inside GstarCAD/GstarCAD Mechanical (or SolidWorks DWG) on Windows**, loaded via `APPLOAD` of `swcad_load.lsp`, then invoked with commands like `SWAUTO`, `SWHELP`, or the `SWTITLE*` set. **This runtime is Windows-only proprietary CAD software and cannot be executed in the Linux Cloud Agent VM.** Do not attempt to "start a server" or run the app here — there is no runnable service. End-to-end behavioral testing requires a Windows CAD host and is out of scope for the cloud VM.

### Entry point & load behavior
`swcad_load.lsp` is the single `APPLOAD` entry point. It loads modules from `src/lsp/` and `src/tools/` and wraps each `load` in `vl-catch-all-apply`, printing `SWCAD load failed: <module>` if a module is malformed. A malformed `.lsp` (unbalanced parens/strings) is the main thing that breaks loading.

### Practical validation in the cloud VM
Since the CAD runtime is unavailable, the meaningful local check is **structural validation of the AutoLISP source** (balanced parentheses/strings, honoring `;` line comments, `;| ... |;` block comments, and `\"` string escapes). This mirrors the loader's per-module `load` step. There is no committed lint/test script; validate structurally (e.g. a small paren/quote-balance pass over every `.lsp`) before considering an edit "loadable". Do not claim behavioral correctness from this alone — it only proves the files will parse/load.

### Binary assets & scratch space
- CAD binaries (`*.dwg`, `*.dxf`, SolidWorks parts, PDFs, images, etc.) are routed through **Git LFS** via `.gitattributes`. Ensure LFS filters are active (`git lfs install`) before adding/checking out such files.
- `work/` holds throwaway scratch (`work/*.dwg|lsp|scr|txt` are gitignored). Verified LSP graduates to `src/`, finalized docs to `docs/`.
