# GMTITLE plan frame-prepare LSP copy comparison - 2026-07-04

## 결론

비교 결과, **계획 반영 복사본 방식이 현재 main48보다 목표에 더 맞다.**

이유는 현재 main48이 `DR_A*_Outline` 도면틀 정의 안의 title-like geometry를 감지하더라도, 별도 `DR_titlea_3rd` 제목블록과 겹치기 전에는 정리 후보로 올리지 않기 때문이다. 그래서 A3처럼 도면틀 자체에 표제란 형상이 포함된 경우에도 다음 행동이 `SWTITLECONVERT`로 나올 수 있다.

계획 반영 복사본은 같은 상황에서 다음 행동을 `SWTITLEPREPARE`로 바꾸고, A2/A3/A4 도면틀 정의 안의 title-like geometry를 변환 전에 정리 후보로 올린다.

## 비교 대상

현재 main48:

```text
src/tools/gmtitle/swcad_title_scale.lsp
version: 260704-command-text-guard-main-48
```

계획 반영 복사본:

```text
work/lsp_compare/swcad_title_scale_plan_frame_prepare_compare.lsp
version: 260704-plan-frame-prepare-compare
```

복사본의 핵심 변경:

```text
swcad-title-frame-embedded-title-records
```

기존:

```text
source-contaminated 도면틀 정의만 PREPARE 정리 후보로 봄
```

복사본:

```text
source-contaminated
native-format-with-title-geometry
```

두 유형 모두 PREPARE 정리 후보로 본다.

또한 복사본의 정리는 직접 `vla-Delete`가 아니라, 기존 style-normalization에서 검증된 **블록 정의 재구성 방식**을 사용하도록 바꿨다.

## 새 비교 fixture

추가한 진단 파일:

```text
diagnostics/gmtitle-main45/embedded_title_prepare_compare_probe.lsp
diagnostics/gmtitle-main45/run_embedded_title_prepare_compare_probe.ps1
```

fixture 조건:

```text
DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 정의를 생성
각 도면틀 정의 안에 title-like 선/문자 형상을 넣음
별도 DR_titlea_3rd 제목블록은 넣지 않음
```

이 조건은 사용자가 지적한 A3 문제를 축소 재현한다.

```text
A3에서 도면틀과 제목블록이 하나로 합쳐진 것처럼 보임
GMTITLE 기능은 되지만 도면 형태가 달라짐
변환 후 표제란이 중복될 수 있음
```

## 현재 main48 결과

실행:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_embedded_title_prepare_compare_probe.ps1" `
  -LspPath "src\tools\gmtitle\swcad_title_scale.lsp" `
  -Label "current_main48_embedded_prepare" `
  -TimeoutSeconds 90
```

로그:

```text
Loaded version: 260704-command-text-guard-main-48
Frame definition classes:
  DR_A2_Outline: class=native-format-with-title-geometry, embedded=4
  DR_A3_Outline: class=native-format-with-title-geometry, embedded=4
  DR_A4_Outline: class=native-format-with-title-geometry, embedded=4
Cleanup records by frame:
  <none>
All embedded title-like records by frame:
  DR_A2_Outline: 4
  DR_A3_Outline: 4
  DR_A4_Outline: 4
Structure next action: SWTITLECONVERT - 남은 원본 SolidWorks 시트 변환
Runtime check completed: yes
```

판단:

```text
감지 자체는 됨
하지만 PREPARE 정리 후보가 0개
다음 행동이 SWTITLECONVERT로 나와서 변환을 계속 진행할 수 있음
```

이 방식은 지금 목표와 맞지 않는다.

## 계획 반영 복사본 결과

실행:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_embedded_title_prepare_compare_probe.ps1" `
  -LspPath "work\lsp_compare\swcad_title_scale_plan_frame_prepare_compare.lsp" `
  -Label "plan_frame_prepare_compare" `
  -RunClean `
  -TimeoutSeconds 90
```

로그:

```text
Loaded version: 260704-plan-frame-prepare-compare
Frame definition classes:
  DR_A2_Outline: class=native-format-with-title-geometry, embedded=4
  DR_A3_Outline: class=native-format-with-title-geometry, embedded=4
  DR_A4_Outline: class=native-format-with-title-geometry, embedded=4
Cleanup records by frame:
  DR_A2_Outline: 4
  DR_A3_Outline: 4
  DR_A4_Outline: 4
All embedded title-like records by frame:
  DR_A2_Outline: 4
  DR_A3_Outline: 4
  DR_A4_Outline: 4
Structure next action: SWTITLEPREPARE - 도면틀 정의 안의 표제란 형상을 먼저 정리
Cleanup result: OK
Cleanup deleted count: 12
Cleanup record count after clean: 0
Runtime check completed: yes
```

판단:

```text
A2/A3/A4 모두 같은 기준으로 정리 후보가 잡힘
변환 전에 SWTITLEPREPARE로 멈춤
정리 후 후보가 0개가 됨
```

이 방식이 목표와 더 맞다.

## 부작용 검증

### 1. 기존 style-normalization 유지

실행:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_style_normalization_compare_probe.ps1" `
  -LspPath "work\lsp_compare\swcad_title_scale_plan_frame_prepare_compare.lsp" `
  -Label "plan_frame_prepare_stylecmp_all_sizes_clean" `
  -Sheets "A2,A3,A4" `
  -RunClean `
  -TimeoutSeconds 90
```

결과:

```text
Loaded version: 260704-plan-frame-prepare-compare
Style-normalization record count: 3
Style-normalization clean entity count: 12
Style-normalization deleted count: 12
Style-normalization record count after clean: 0
Runtime check completed: yes
```

중요 관찰:

```text
Direct vla-Delete first clean record: ERROR
Style-normalization clean result: OK
```

즉 직접 삭제보다 블록 정의 재구성 방식이 더 안전하다.

### 2. 실수 명령어 텍스트 차단 유지

결과:

```text
Loaded version: 260704-plan-frame-prepare-compare
command-text-count-before: 1
SWTITLESTATUS result: OK status=NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT
structure-next-action: SWTITLEPREPARE - 실수 명령어 텍스트 잔여물을 먼저 확인/정리해야 합니다.
convert-status-after: ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST
danger-action-after-convert: <none>
Runtime check completed: yes
```

판단:

```text
CAD 명령어가 도면 안의 TEXT/MTEXT로 들어가는 사고를 계속 막는다.
```

### 3. 실제 도면 내용 보호 유지

결과:

```text
Loaded version: 260704-plan-frame-prepare-compare
bottom-left logo line candidate: yes
bottom-left real text preserved: yes
upper small SW_NOTE balloon preserved: yes
upper wide SW_NOTE residue candidate: yes
upper SHEET_FORMAT residue candidate: yes
upper BOM-like insert preserved: yes
Residue protection passed: yes
Runtime check completed: yes
```

판단:

```text
로고/sheet-format 잔여물은 잡고,
실제 주석, 작은 번호 풍선, BOM-like 객체는 보호한다.
```

## 비교표

| 항목 | 현재 main48 | 계획 반영 복사본 |
| --- | --- | --- |
| A2/A3/A4 도면틀 정의 내부 title-like geometry 감지 | 가능 | 가능 |
| 별도 제목블록이 없을 때 PREPARE로 중단 | 안 됨 | 됨 |
| 정리 후보 수 | 0 | A2/A3/A4 각 4개 |
| 다음 행동 | `SWTITLECONVERT` | `SWTITLEPREPARE` |
| 정리 후 후보 0개 검증 | 해당 없음 | 통과 |
| 기존 style-normalization | 유지 | 유지 |
| command-text guard | 유지 | 유지 |
| residue protection | 유지 | 유지 |
| 사용자 목표와의 적합도 | 중간 | 높음 |

## 권장 방향

계획 반영 복사본 방식을 원본 LSP에 반영하는 것이 좋다.

단, 바로 실제 도면 변환으로 넘어가기 전에 다음을 추가로 확인한다.

```text
1. 실제 설치 원본 DR_A2/A3/A4_Outline 정의에서 제거 후보가 어디까지 잡히는지 읽기 전용 로그로 확인
2. 빨간 네모로 표시된 도면 안 번호/주석 사례를 fixture로 추가
3. 기존 main48 suite에 embedded-title prepare comparison probe를 포함
4. 원본 LSP 반영 후 전체 suite 재실행
5. 그 다음 실제 work copy에서 SWTITLESTATUS -> SWTITLEPREPARE -> SWTITLESTATUS 순서로 확인
```

## 다음 구현 후보

원본 LSP 반영 시 변경할 최소 범위:

```text
swcad-title-frame-embedded-title-records
  native-format-with-title-geometry도 PREPARE 후보로 포함

swcad-title-frame-embedded-title-clean
  직접 delete 대신 블록 정의 재구성 방식 사용
```

공개 명령어는 추가하지 않는다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

이 4개 흐름 안에서만 처리한다.
