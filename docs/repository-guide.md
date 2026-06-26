# CAD Repository Guide

This repository separates CAD evidence from automation code.

## What Belongs Here

- SolidWorks source files: `.SLDPRT`, `.SLDASM`, `.SLDDRW`
- Raw SolidWorks exports: `.DWG`, `.DXF`, `.PDF`, `.STEP`, `.IGES`
- GstarCAD/GstarCAD Mechanical XRef and bound drawing files
- Release-ready GstarCAD/GstarCAD Mechanical LSP utility copies and usage notes
- Minimal sample drawings that reproduce scale, dimension style, tolerance, or title-block issues
- Diagnostic outputs from read-only scan tools
- Screenshots and notes that explain a CAD behavior

## What Should Stay In The Automation Repository

- Experimental LSP drafts that are not ready to share from the CAD repository
- Batch scripts and command runners
- Automated test harnesses
- Tool usage documents for commands such as `SWAUTO`
- General analysis logs not tied to a CAD sample file

## Case Folder Pattern

Use one folder per reproducible CAD issue:

```text
samples/cases/<case-id>/
  README.md
  input/
  output/
  diagnostics/
```

Suggested case id format:

```text
YYYY-MM-topic-short-name
```

Example:

```text
2026-06-dimlfac-titleblock-scale/
```

## Commit Pattern

Prefer small, traceable commits:

- Add original source drawing
- Add exported or bound result
- Add scan output and notes
- Update sample drawing register

Avoid replacing source and result files in one large unexplained commit when diagnosing a scale issue.
