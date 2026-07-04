# GMTITLE 현재 실행 카드

CAD 화면 옆에 열어두고 따라가는 짧은 실행 순서입니다.

## 목표모드 판단 루프

명령을 많이 누르는 것이 목표가 아닙니다. 아래 순서를 한 번씩만 반복합니다.

```text
1. SWTITLESTATUS로 현재 상태 확인
2. 로그가 요구한 명령 하나만 실행
3. 바로 SWTITLESTATUS 또는 SWTITLEVERIFY로 변화 확인
4. 후보 수나 경고가 줄지 않으면 같은 명령 반복 금지
5. raw bbox, A4 제목블록 생성, 도면 내부 객체 삭제가 보이면 중단
```

계속 진행해도 되는 증거:

```text
target title/frame 수가 기대 수량에 가까워짐
A3/A4 native 교체 후보가 줄어듦
clone/shared-link 경고가 줄어듦
A4 frame-only가 제목블록 없이 도면틀만 남음
```

진행으로 보지 않는 것:

```text
화면 모양만 비슷함
한 명령어가 오류 없이 끝남
같은 경고가 그대로인데 변환을 반복함
probe 로그를 실제 작업 DWG 로그로 착각함
```

## 시작 조건

반드시 `work` 폴더 안의 작업복사본에서만 실행합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

`Downloads` 원본 DWG나 실제 납품 원본에서 바로 실행하지 않습니다.

## 로드

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
SWTITLEVERSION
```

기대 버전:

```text
260705-verify-source-priority-a4stepnote
```

다른 버전이면 변환하지 말고 최신 LSP를 다시 `APPLOAD`합니다.

## 현재 기준 상태

2026-07-05 검증 suite 기준, 기본 작업복사본은 아직 변환 전 상태입니다.

```text
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
남은 원본 표제란 시트: 13
남은 원본 도면틀: 15
표제란 없는 도면틀 시트: 2
target 도면틀/제목블록: 0
필요한 최종 수량:
  A2: 1
  A3: 12
  A4: 2
없는 native 기준 객체:
  DR_A2_Outline
  DR_A3_Outline
  DR_A4_Outline
```

이 상태에서 다음 실제 CAD 명령은 `SWTITLECONVERT`입니다. 첫 대상은 보통 A2입니다.

## 기본 순서

항상 상태부터 봅니다.

```text
SWTITLESTATUS
```

상태가 정리를 요구하면:

```text
SWTITLEPREPARE
SWTITLESTATUS
```

상태가 변환을 요구하면:

```text
SWTITLECONVERT
SWTITLESTATUS
```

최종 검증:

```text
SWTITLEVERIFY
```

## GMTITLE 창에서 선택할 값

`SWTITLECONVERT` 중 GMTITLE 창이 열리면 로그가 요구한 값만 고릅니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

금지:

```text
일반 A2/A3/A4 용지
ISO 제목블록
스크린샷 좌표 클릭
긴 소수점 좌표 수동 입력
Object move ON
```

`SWTITLECONVERT`는 GMTITLE 창 이후 필요한 왼쪽 아래 기준점을 자동으로 보내도록 설계되어 있습니다. 사람이 긴 좌표를 직접 칠 필요가 없습니다.

## 상태 문구별 행동

| 로그 문구 | 의미 | 다음 행동 |
| --- | --- | --- |
| `NEXT_CREATE_FIRST_NATIVE_GMTITLE` | 아직 실제 native GMTITLE 기준 객체가 없음 | `SWTITLECONVERT` |
| `NEXT_PREPARE_FRAME_STYLE_NORMALIZATION` | 도면틀 내부 형상과 별도 제목블록이 겹쳐 정규화 필요 | `SWTITLEPREPARE` |
| `NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT` | 도면에 실수 명령어 텍스트 후보가 있음 | 후보 확인 후 `SWTITLEPREPARE` |
| `NEXT_UPGRADE_A3_A4_NATIVE` | A3/A4 복제/shared-link 쌍을 fresh native로 교체해야 함 | `SWTITLECONVERT` |
| `WAITING_FOR_A4_FRAME_ONLY_OUTLINE_DEFINITION` | A4 frame-only 전에 DR_A4_Outline 검증 필요 | `SWTITLEPREPARE` |
| `NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION` | A4 도면틀 정의 준비/검증 필요 | `SWTITLEPREPARE` |
| `NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX` | 도면틀 정의 선택 범위가 위험함 | 변환 반복 금지, 로그 확인 |
| `ABORT_FRAME_DEFINITION_RAW_BBOX_RISK` | 기존 도면 보호를 위해 중단됨 | 변환 반복 금지, 원인 분석 |
| `SWTITLEVERIFY_FINAL_FAIL` | 완료 조건 미달 | `SWTITLESTATUS`로 다음 조치 확인 |
| `SWTITLEVERIFY_FINAL_OK` | 검증 기준 통과 | 대표 제목블록 더블클릭 확인 |

## A3 판단

A3 도면틀이 CAD에서 block/INSERT처럼 보이는 것만으로 실패는 아닙니다. GstarCAD native GMTITLE 도면틀도 내부적으로 INSERT/block reference처럼 보일 수 있습니다.

성공 판단은 아래 기준입니다.

```text
DR_titlea_3rd 제목블록 더블클릭 -> GMTITLE 표 편집창 열림
A3/A4 native 교체 후보: 0
clone/shared-link 경고: 0
겹친 target pair: 0
SWTITLEVERIFY가 OK 쪽으로 진행
```

도면틀 안에 표제란처럼 보이는 native-format 형상이 있어도, 별도 `DR_titlea_3rd`와 실제로 겹치는 문제가 아니라면 삭제하지 않습니다.

## A4 판단

A4 원본은 표제란 없는 도면틀-only 시트일 수 있습니다.

따라서 A4 성공 조건은 제목블록을 만드는 것이 아닙니다.

```text
DR_A4_Outline 도면틀만 원본 A4 위치/크기에 맞음
불필요한 DR_titlea_3rd 제목블록 없음
A4 target 수량: 2
기존 A4 내용 삭제 없음
```

A4에서 `DR_titlea_3rd`가 생기면 멈추고 로그를 봅니다.

## 로그를 볼 때 우선순위

검증 suite나 probe를 돌리면 `*_last.txt`가 실제 작업 DWG가 아니라 진단용 DWG를 가리킬 수 있습니다. 로그를 볼 때는 파일 이름보다 안의 DWG 경로를 먼저 봅니다.

우선 확인할 로그:

```text
work\swcad_title_structure_diagnosis_last.txt
work\swcad_title_verify_summary_last.txt
work\swcad_title_transfer_apply_last.txt
work\swcad_title_native_upgrade_last.txt
```

진단 전용 로그는 실제 작업 결과로 착각하지 않습니다.

```text
swtitle_*_probe*.dwg
*_compare_*.dwg
*_diagnostics.dwg
```

## 완료 기준

아래가 모두 맞아야 완료입니다.

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
frame-only 시트: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
A3/A4 native 교체 후보: 0
겹친 GMTITLE target 쌍: 0
clone/shared-link 경고: 0
```

수동 화면 확인:

```text
대표 A2/A3 제목블록 더블클릭 -> GMTITLE 표 편집창 열림
A4 frame-only -> 제목블록 없이 DR_A4_Outline 도면틀만 있음
도면 내부 번호, 주석, BOM, 치수, 모델 형상 유지
```

`SWTITLEVERIFY_FINAL_OK` 전에는 완료로 보지 않습니다.
