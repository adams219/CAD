# Sample Drawing Register

Use this file to track why each CAD sample exists and which workflow produced it.

| Case ID | File Path | Source System | Workflow Stage | Main Issue | Scale Evidence | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `example` | `samples/cases/example/input/example.dwg` | SolidWorks export | Raw export | Replace with actual issue | `DIMLFAC=?`, title block scale=? | Remove this example row after first real sample is added. |

## Field Guide

| Field | Meaning |
| --- | --- |
| Case ID | Same id used under `samples/cases/<case-id>/`. |
| File Path | Repository-relative path to the file. |
| Source System | SolidWorks, GstarCAD, GstarCAD Mechanical, or mixed. |
| Workflow Stage | Raw export, XRef source, Bound result, Converted result, or Diagnostic output. |
| Main Issue | Short problem statement, for example `DIMLFAC changes after Bind`. |
| Scale Evidence | Known `DIMLFAC`, title-block scale, viewport scale, or drawing unit clues. |
| Notes | Anything needed to reproduce or compare the drawing. |
