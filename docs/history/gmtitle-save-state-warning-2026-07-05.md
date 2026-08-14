# GMTITLE Save State Warning - 2026-07-05

## 목적

최근 검증에서 열린 CAD 화면과 디스크에 저장된 작업복사본 상태가 달라 혼선이 생겼다.

숨김 GstarCAD probe는 DWG 파일을 다시 열어 검사하므로, 현재 화면의 변경사항이 저장되지 않았다면 probe 결과는 마지막 저장본 기준으로 나온다.

이번 변경은 이 차이를 사용자가 바로 볼 수 있게 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 공통 헤더에 DWG 저장 상태를 표시한다.

## 변경 내용

LSP 버전:

```text
260705-save-state-warning
```

새 공통 출력:

```text
DWG 저장 상태: 저장됨 (DBMOD=0)
```

또는:

```text
DWG 저장 상태: 저장되지 않은 변경 있음 (DBMOD=...)
주의: 숨김 진단 probe는 마지막 저장본을 다시 열기 때문에 현재 화면과 다를 수 있습니다.
다른 PC나 숨김 probe에서 이어가려면 먼저 이 작업복사본 DWG를 저장하세요.
```

## 왜 필요한가

현재 목표 흐름에서는 다음 두 상태를 구분해야 한다.

```text
열려 있는 CAD 화면 상태
디스크에 저장된 DWG 상태
```

예를 들어 화면에서는 A2/A3 target이 생성되어 보이더라도 저장하지 않았다면, `run_actual_workcopy_status_probe.ps1`는 변환 전 저장본을 다시 열어 `target-frame-count: 0`으로 진단할 수 있다.

이것은 probe 오류가 아니라 저장 상태 차이다.

## 적용 파일

```text
src/tools/gmtitle/swcad_title_scale.lsp
diagnostics/gmtitle-main45/actual_workcopy_status_probe.lsp
diagnostics/gmtitle-main45/a4_native_exemplar_probe.lsp
```

진단 probe도 DBMOD 값을 로그에 남긴다.

```text
DBMOD before commands: ...
dbmod-after-commands: ...
DBMOD before checks: ...
DBMOD after checks: ...
```

## 운영 기준

목표모드에서 이어갈 때는 아래 기준을 따른다.

1. 열린 CAD에서 판단할 때는 먼저 `SWTITLESTATUS`를 실행한다.
2. `DBMOD`가 0이 아니면 화면 상태가 저장본보다 앞서 있을 수 있다.
3. 다른 컴퓨터, GitHub, 숨김 probe, workcopy 재검증을 기준으로 삼으려면 DWG를 먼저 저장한다.
4. 저장 후 `run_actual_workcopy_status_probe.ps1` 또는 `run_a4_native_exemplar_probe.ps1`를 다시 실행한다.

## 목표 상태와의 관계

이 변경은 A4 변환을 직접 해결하지 않는다.

대신 A4 native 기준 객체가 없다는 진단과, 저장되지 않은 화면 상태가 섞여 잘못된 결론으로 가는 일을 줄인다.

따라서 다음 구현 방향은 그대로 유지한다.

```text
1. A3/A4 native 교체 후보를 줄인다.
2. A4 frame-only는 정상 DR_A4_Outline 기준 객체를 확보한 뒤 처리한다.
3. SWTITLEVERIFY_FINAL_OK와 대표 더블클릭 검증 전에는 완료로 보지 않는다.
```

