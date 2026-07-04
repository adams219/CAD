# GMTITLE active goal audit - 2026-07-05

## Goal

SolidWorks DWG를 GstarCAD native GMTITLE 구조로 안정 변환한다.

핵심 목표는 아래와 같다.

```text
1. 사용자는 4단계 명령 흐름을 사용한다.
2. 복제 GMTITLE 한계와 native GMTITLE 필요 조건을 구분한다.
3. A2/A3/A4 시트 크기와 frame-only A4를 안전하게 구분한다.
4. A4 도면틀이 원본에 없는 선/글자를 끌고 오지 않게 한다.
5. 사람이 반복 선택하는 구간을 줄이되 GstarCAD native 인식을 깨뜨리지 않는다.
6. 최종적으로 실제 work DWG에서 SWTITLEVERIFY_FINAL_OK와 대표 더블클릭 확인을 얻는다.
```

## Current Source State

Latest pushed branch:

```text
codex/gm-title
```

Recent commits:

```text
6de3107 Expand GMTITLE static preflight coverage
5cb1e5f Add static GMTITLE preflight checks
48d05fa Allow GMTITLE suite to wait for GstarCAD close
c0af34e Fail fast when full GMTITLE suite sees open GstarCAD
5aab88d Fail fast when GstarCAD probe would reuse open session
0200c4f Reject unsafe A4 outline raw bounds
```

Expected versions:

```text
GMTITLE LSP: 260705-verify-source-priority-a4stepnote
Loader: 260705-4step-gmtitle-a4-outline-preflight
```

## Proven Now

The static preflight passes without opening CAD:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_static_preflight.ps1
```

Observed result:

```text
Static preflight result: PASS
```

This proves the following source-level and documentation-level gates:

```text
LSP parenthesis/string balance is OK.
Loader parenthesis/string balance is OK.
GMTITLE and loader version strings match the guide documents.
Public c: commands are limited to:
  SWTITLESTATUS
  SWTITLEPREPARE
  SWTITLECONVERT
  SWTITLEVERIFY
  SWTITLEVERSION
  SWSCALESCAN
Legacy fast/batch/A3A4/frame-only commands are not public.
A4 strict raw-bbox guard exists.
Unsafe A4 outline status exists:
  WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE
SCRIPT-mode interactive GMTITLE guard exists:
  ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE
SCRIPT-mode A3/A4 batch guard exists:
  ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE
The hidden verification suite has 15 numbered steps.
The hidden verification suite can wait for GstarCAD to close.
Guide documents point to the current GMTITLE version.
```

## A4 Finding

The A4 issue is not simply "A4 was not detected".

The important finding is:

```text
DR_A4_Outline can look like an A4 frame by effective bbox,
but its raw block definition can include geometry outside (0,0)-(210,297).
```

One confirmed unsafe shape was:

```text
Definition raw bbox: (0,0)-(266.25210777,302.7)
```

That explains the user's observed problem:

```text
원본 A4 도면틀에는 아무것도 없어 보이는데,
변환 후 도면틀 밖의 선/글자가 같이 딸려오는 현상
```

Current behavior:

```text
If DR_A4_Outline raw definition bbox is outside the A4 range,
SWTITLEPREPARE stops with WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE
and existing A4 source frames are not deleted.
```

## Hidden CAD Suite Status

The full hidden CAD suite is still required:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_main45_verification_suite.ps1
```

However, the current local machine still has GstarCAD open:

```text
gcad.exe PID 10048
```

The suite intentionally refuses to run while visible GstarCAD is open because hidden `/b` scripts can be routed to the existing session or stall behind an active command prompt.

Use either:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_main45_verification_suite.ps1
```

after saving and closing GstarCAD, or:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_main45_verification_suite.ps1 -WaitForGstarCADClose
```

then save/close GstarCAD and let the suite continue.

## Not Complete Yet

The active goal is not complete.

Missing evidence:

```text
1. Hidden main56 suite passing after GstarCAD is closed.
2. Actual work-copy conversion reaching SWTITLEVERIFY_FINAL_OK.
3. Remaining SolidWorks source title/frame counts becoming 0.
4. target-sheet-counts reaching A2=1, A3=12, A4=2.
5. A4 frame-only sheets converted without unwanted DR_titlea_3rd titles.
6. Representative A2/A3 title double-click opens the GMTITLE table editor.
7. Representative A4 frame-only result has no unwanted title block and no dragged-in outside geometry.
8. Drawing notes, balloons, BOM, dimensions, and model geometry are preserved.
```

Until these are proven, do not mark the goal complete.

## Next Operator Sequence

If continuing on this machine:

```text
1. Save the visible GstarCAD work-copy DWG.
2. Close GstarCAD.
3. Run:
   powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_main45_verification_suite.ps1
4. If the suite passes, reopen the work-copy in GstarCAD.
5. APPLOAD:
   C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
6. Run:
   SWTITLEVERSION
   SWTITLESTATUS
7. Follow only the next command shown by SWTITLESTATUS.
8. Use SWTITLEVERIFY after each meaningful phase.
```

If GstarCAD must stay open:

```text
1. Run:
   powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_goal_status.ps1
2. Or run the static-only check:
   powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_static_preflight.ps1
3. Do not run hidden CAD probes until GstarCAD is saved and closed.
```
