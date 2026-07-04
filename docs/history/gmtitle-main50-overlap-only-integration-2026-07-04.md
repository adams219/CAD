# GMTITLE main50 overlap-only integration - 2026-07-04

## Summary

`overlap-only` comparison result was applied to the source LSP as `main50`.

Current source version:

```text
260704-overlap-only-main50
```

Current loader version:

```text
260704-4step-gmtitle-main50
```

## Why this change was made

`main49` treated `native-format-with-title-geometry` as a generic embedded-title cleanup candidate.

That solved one visible duplicate-title symptom, but it also meant a native DR frame definition could be cleaned even when no separate `DR_titlea_3rd` title block overlapped it.

That was too broad for the current requirement.

Important prior evidence:

```text
DR_A3_Outline.dwg from the GstarCAD install can contain native title-like geometry.
Native-format title-like geometry alone is not proof of SolidWorks/source contamination.
```

The corrected main50 rule:

```text
source-contaminated:
  cleanup candidate

native-format-with-title-geometry:
  not a generic cleanup candidate

native-format-with-title-geometry + visible DR_titlea_3rd overlap:
  style-normalization candidate
```

## Source changes

Changed:

```text
src/tools/gmtitle/swcad_title_scale.lsp
swcad_load.lsp
```

Key behavior:

```text
swcad-title-frame-embedded-title-records
```

now includes only:

```text
source-contaminated
```

It no longer includes:

```text
native-format-with-title-geometry
```

Native-format overlap is still handled by:

```text
swcad-title-frame-style-normalization-records
swcad-title-frame-style-normalization-clean
```

## Copy comparison evidence

Comparison document:

```text
docs/investigations/gmtitle-overlap-only-copy-comparison-2026-07-04.md
```

Important logs:

```text
work/swtitle_embedded_title_prepare_compare_current_main49_embedded_rerun.txt
work/swtitle_embedded_title_prepare_compare_overlap_only_embedded.txt
work/swtitle_style_normalization_compare_current_main49_style_rerun_all.txt
work/swtitle_style_normalization_compare_overlap_only_style_all.txt
work/swtitle_frameclass_common_probe_overlap_only_all_contaminated.txt
```

Copy comparison conclusion:

```text
The overlap-only copy is better.
```

Reason:

```text
It preserves native-format DR frame title-like geometry when no separate title block overlaps it.
It still normalizes the duplicate-title situation when a visible DR_titlea_3rd overlaps that native geometry.
It still catches source-contaminated frame definitions.
```

## Verification

The full hidden GstarCAD diagnostic suite passed after source integration:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_main45_verification_suite.ps1 -TimeoutSeconds 150
```

Result:

```text
All expected log markers were verified.
===== GMTITLE main45 verification suite complete =====
```

Key verified behavior:

```text
Loader probe:
  Loaded loader version: 260704-4step-gmtitle-main50
  Loaded GMTITLE version: 260704-overlap-only-main50
  SWTITLESTATUS / SWTITLEPREPARE / SWTITLECONVERT / SWTITLEVERIFY: yes
  legacy fast/bootstrap/frame-only/A3A4 commands: no

Actual work-copy read-only status:
  SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
  SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
  source-title-count: 13
  source-frame-count: 15
  frame-only-count: 2
  target-title-count: 0
  target-frame-count: 0
  A2: 1
  A3: 12
  A4: 2

Mixed frameclass fixture:
  DR_A3_Outline: native-format-with-title-geometry, cleanup records: none
  DR_A4_Outline: source-contaminated, cleanup records: 2

All contaminated fixture:
  A2/A3/A4 source-contaminated: PASS

All native fixture:
  A2/A3/A4 native-format-with-title-geometry: cleanup records <none>, PASS

Style-normalization overlap fixture:
  Style-normalization record count: 3
  Style-normalization deleted count: 12
  Style-normalization record count after clean: 0

Residue protection:
  bottom-left real text preserved: yes
  upper small SW_NOTE balloon preserved: yes
  upper BOM-like insert preserved: yes

Embedded-title prepare fixture:
  Cleanup records by frame: <none>
  All embedded title-like records by frame: A2/A3/A4
  Cleanup deleted count: 0
```

## Current real work-copy status

The real work-copy is still not converted. This remains expected.

Current read-only status:

```text
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
```

This is not a main50 failure. It means the next task is still the real interactive CAD conversion on a work copy.

## Next CAD sequence

Use only:

```text
APPLOAD
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE   only if SWTITLESTATUS asks for it
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT   repeat only when SWTITLESTATUS says conversion remains
SWTITLEVERIFY
```

Completion is still unproven until:

```text
SWTITLEVERIFY_FINAL_OK
source-title-count: 0
source-frame-count: 0
frame-only-count: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
representative A2/A3/A4 title blocks open the GMTITLE table editor on double-click
real drawing notes, BOM tables, dimensions, and model geometry remain
```

