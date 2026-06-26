# GstarCAD Scale Investigation

The current investigation is about SolidWorks DWG files that are combined in GstarCAD/GstarCAD Mechanical with XRef + Bind, then normalized through dimension-style and tolerance workflows.

The suspected failure mode is drawing-specific scale drift, especially when `DIMLFAC` no longer matches the title-block scale or intended drawing scale.

## Boundaries

- Keep the existing long `SWAUTO` LSP unchanged while investigating.
- Build the first scale scanner as a separate read-only LSP module in the automation repository.
- Store only sample drawings and scanner outputs in this CAD repository.

## Candidate Read-Only Commands

| Command | Purpose |
| --- | --- |
| `SWTITLEDEBUG` | Inspect selected title-block attributes and scale hints. |
| `SWTITLESCAN` | Scan title-block candidates such as `GMTITLE` and `FTAP`. |
| `SWSCALESCAN` | Report `DIMLFAC`, dimension style scale, drawing units, and relevant system variables. |
| `SWSCALEDUMP` | Write a repeatable text/CSV dump for comparison before and after XRef + Bind. |

## Evidence To Capture

- Raw SolidWorks DWG export
- XRef source DWG files
- Bound DWG result
- Dimension style name and `DIMLFAC`
- Title-block name and visible scale text
- GstarCAD/GstarCAD Mechanical version
- Whether the file came from plain GstarCAD, Mechanical, or SolidWorks export

Store investigation files under:

```text
samples/cases/<case-id>/
diagnostics/gstarcad-scale/
```
