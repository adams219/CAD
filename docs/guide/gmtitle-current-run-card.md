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

## 현재 기준 상태를 고르는 법

먼저 `work\swcad_title_next_step_last.txt` 안의 DWG 경로를 봅니다.

그 경로가 지금 열린 CAD 도면과 같으면, 최신 CAD 로그를 우선합니다.
그 경로가 probe/diagnostics/예전 복사본이면, 현재 CAD에서 `SWTITLESTATUS`를 다시 실행합니다.

### 최신 CAD 진행 상태

2026-07-05 08:55 기준 최신 CAD 로그는 아래 상태입니다.

```text
DWG:
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125 CP_ALL_260704_test.dwg

상태:
NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION

의미:
A2 1장과 A3 12장은 최신 native-frame 로그에서 native-like로 잡혔고,
현재는 A4 frame-only 도면틀 정의를 준비/검증해야 함

다음 명령:
SWTITLEPREPARE

그 다음:
SWTITLESTATUS
```

이 상태에서는 `SWTITLECONVERT`를 반복하지 않습니다.
먼저 `SWTITLEPREPARE`가 A4 도면틀 정의를 안전하게 만들 수 있는지 확인해야 합니다.

이미 같은 열린 DWG 상태에서 `SWTITLEPREPARE`를 한 번 실행했고, 바로 이어서 `SWTITLESTATUS`가 다시
`NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION`을 표시한다면 같은 명령을 계속 반복하지 않습니다.
그 경우 현재 증거는 "CAD 조작을 더 하면 해결"이 아니라 "A4 도면틀 정의 정규화 전략을 복사본에서 비교해야 함"입니다.

A3 참고:

```text
최신 swcad_title_native_frame_check_last.txt 기준:
  A3 native-like frame/title pairs: 12
  A3/A4 native-like 완료: 12 / 12
  non-native-like record scan: 0

DR_A3_Outline 도면틀 자체는 native GMTITLE에서도 INSERT/block 참조로 보일 수 있습니다.
A3 성공 여부는 도면틀 더블클릭이 아니라 짝 DR_titlea_3rd 제목블록 더블클릭 표 편집창으로 확인합니다.
```

`SWTITLEPREPARE` 뒤에는 반드시 `SWTITLESTATUS`를 다시 실행합니다.
그 결과가 `SWTITLECONVERT`를 안내하면 그때 변환을 진행하고, `WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE`가 나오면 멈춥니다.

현재 probe 기준으로는 설치 원본 `DR_A4_Outline`이 strict A4 raw bbox 검사를 통과하지 못할 가능성이 큽니다.

```text
prepare probe:
WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE

보이는 A4 범위:
(0, 0) - (210, 297)

실제 CAD 선택 raw 범위:
(0, 0) - (872.26126377, 302.7)

정규화 probe:
none=no
huge-insert=no
direct-outside=no
nested-outside=no
nested-direct-outside=no
```

즉 `SWTITLEPREPARE`가 같은 경고로 멈추면 정상적인 안전 중단입니다. 이때는 변환을 반복하지 말고 A4 도면틀 정의 전략을 다시 봅니다.

`nested-outside`와 `nested-direct-outside`도 copied-DWG probe에서 모두 unsafe였습니다.

따라서 지금 다음 단계는 `SWTITLEPREPARE`나 `SWTITLECONVERT`를 더 누르는 것이 아닙니다. 별도 scratch DWG에서 GstarCAD가 실제 `GMTITLE`로 만든 native A4 결과를 확보하고, 그 안의 `DR_A4_Outline` 정의를 비교해야 합니다.

scratch native A4 비교는 production 변환이 아닙니다. scratch 샘플에는 비교를 위해 `DR_titlea_3rd`가 생길 수 있지만, 실제 A4 frame-only 생산 결과에는 원본에 없던 제목블록을 만들면 안 됩니다.

주의:

```text
직접 GMTITLE만 실행해서 바로 삽입 지점만 묻는 상태는 A4 native 샘플 확보로 보지 않습니다.
FILEDIA=1, CMDDIA=1이어도 현재 로컬에서는 GMTITLE이 선택창 없이 기존/default 상태로 삽입 흐름에 들어갈 수 있습니다.
이 경우 DR_A4_Outline을 새로 고른 것이 아니므로 저장해도 비교 기준이 되지 않습니다.
2026-07-05 CAD 확인 결과, IMTITLE은 알 수 없는 명령이고 TIT는 GMTITLE과 같은 삽입점 흐름으로 들어갔습니다.
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1 -SourceWorkCopyPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\<scratch-native-a4>.dwg"
```

중요:

```text
현재 work DWG에 더 많은 삭제/정규화를 시도하지 않습니다.
실제 native A4 비교가 READY로 나오기 전에는 A4 frame-only production 변환을 연결하지 않습니다.
READY 조건은 A4 definition warning/raw selection warning이 모두 <none>이고 Result가 A4_NATIVE_EXEMPLAR_READY_FOR_COMPARISON인 상태입니다.
```

설정값을 다시 확인해야 할 때:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_gmtitle_selection_config_probe.ps1
```

현재 기대 결과는 `GMTITLE_SELECTION_CONFIG_NOT_FOUND`입니다.

### 기본 작업복사본 초기 상태

2026-07-05 검증 suite 기준, 기본 작업복사본은 아직 변환 전 상태입니다.
이 내용은 새 복사본에서 처음부터 시작할 때 쓰는 기준입니다.

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

중요: 위 초기 상태를 이미 변환이 진행된 CAD 도면에 그대로 적용하지 않습니다.
항상 최신 `SWTITLESTATUS` 또는 `swcad_title_next_step_last.txt`의 DWG 경로가 현재 열린 도면과 같은지 먼저 확인합니다.

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
DR_A4_Outline raw definition bbox가 (0,0)-(210,297) 근처를 벗어나지 않음
기존 A4 내용 삭제 없음
```

A4에서 `DR_titlea_3rd`가 생기거나 `WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE`가 나오면 멈추고 로그를 봅니다. 이 경고는 실패라기보다 원본 A4를 지키기 위해 변환을 중단했다는 뜻입니다.

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
