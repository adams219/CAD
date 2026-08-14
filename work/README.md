# Work Folder

`work/`는 CAD 테스트와 진단 산출물을 두는 임시 작업 폴더입니다.

이 폴더에는 다음 파일이 생길 수 있습니다.

- 테스트용 DWG 복사본
- GstarCAD에서 실행할 임시 LSP/SCR
- 진단 로그 `swcad_title_*_last.txt`
- `.bak`, `.dwl`, `.dwl2` 같은 CAD 임시/잠금 파일
- 비교용 LSP 복사본과 probe 결과

## 원칙

- 원본 DWG는 여기서 직접 보관하거나 수정하지 않습니다.
- 실제 변환은 반드시 `work` 아래의 복사본에서만 합니다.
- 검증이 끝난 코드만 `src/`로 올립니다.
- 정식 사용 문서는 `docs/`에 둡니다.
- `work/*.dwg`, `work/*.lsp`, `work/*.scr`, `work/*.ps1`, `work/*.txt`는 대부분 임시 산출물입니다.

## 현재 GMTITLE 기준

현재 GMTITLE source LSP:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

현재 버전:

```text
260704-plan-frame-prepare-main-49
```

사용자는 아래 4개 명령만 씁니다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

`SWTITLEVERSION`은 로드된 LSP 버전 확인용이고, `SWSCALESCAN`은 읽기 전용 스케일 진단용입니다.

## 현재 기준 작업복사본

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

읽기 전용 상태 probe는 아래 runner로 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\DR-DESIGN\Documents\CAD tool\diagnostics\gmtitle-main45\run_actual_workcopy_status_probe.ps1"
```

현재 변환 전 기준 상태:

```text
Loaded version: 260704-plan-frame-prepare-main-49
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
target-title-count: 0
target-frame-count: 0
```

이 `FAIL`은 코드 실패가 아니라, 실제 work-copy에 아직 GMTITLE target 객체가 없다는 정상적인 변환 전 진단입니다.

## 주요 진단 runner

전체 main49 진단 suite:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\DR-DESIGN\Documents\CAD tool\diagnostics\gmtitle-main45\run_main45_verification_suite.ps1" `
  -TimeoutSeconds 120
```

최종 완료 gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\DR-DESIGN\Documents\CAD tool\diagnostics\gmtitle-main45\run_final_completion_gate.ps1" `
  -TimeoutSeconds 120
```

final gate는 실제 변환이 끝나기 전에는 실패하는 것이 정상입니다.

## 완료 조건

아래가 확인되기 전에는 완료로 보지 않습니다.

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
frame-only 시트: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```

## 참고 문서

실제 CAD 변환 순서:

```text
docs/guide/gmtitle-cad-conversion-checklist.md
```

main49 반영 이력:

```text
docs/history/gmtitle-main49-frame-prepare-integration-2026-07-04.md
```
