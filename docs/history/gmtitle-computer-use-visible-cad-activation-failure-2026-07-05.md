# GMTITLE Computer Use Visible CAD Activation Failure - 2026-07-05

## Summary

The current PC can capture the visible GstarCAD window through Computer Use, but cannot reliably activate or send input to that window.

This means the next production workflow step, `SWTITLECONVERT`, remains a manual visible-GstarCAD step unless a later session proves that activation and input work reliably.

## Evidence

Observed on 2026-07-05:

```text
GstarCAD launched as Drawing1.dwg.
get_window_state captured the GstarCAD window and recovery panel.
activate_window timed out.
click on the recovery panel close button failed with: failed to activate captured window.
The actual work-copy DWG was not opened.
No drawing data was changed.
```

After the failed input test, the temporary GstarCAD process was closed. The work-copy direct probe still reported:

```text
status-after-status: NEXT_CREATE_FIRST_NATIVE_GMTITLE
target-title-count: 0
target-frame-count: 0
next-bootstrap-frame: DR_A2_Outline
next-bootstrap-title: DR_titlea_3rd
```

## Decision

Do not repeat the same visible-CAD Computer Use click/type attempt as a default path.

Use Computer Use screenshots for passive inspection only on this PC unless a future session first proves:

```text
activate_window succeeds
click succeeds
type_text or press_key succeeds
GstarCAD command line receives input
```

## Next Manual CAD Step

Use the short action card:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_next_cad_action.ps1
```

Expected current result:

```text
Result: READY_FOR_FIRST_NATIVE_GMTITLE
SWTITLECONVERT
Paper/frame: DR_A2_Outline
Title block: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
After conversion: SWTITLESTATUS
```
