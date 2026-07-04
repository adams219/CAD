# CAD Tool 명령어

이 문서는 사용자가 CAD 명령창에 직접 입력하는 공개 명령만 정리합니다.

## 기본 로드

GstarCAD에서 `APPLOAD`를 실행한 뒤 아래 파일을 로드합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

GMTITLE 도구만 직접 로드할 때는 아래 파일을 사용할 수 있습니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

로드된 GMTITLE 버전 확인:

```text
SWTITLEVERSION
```

현재 기준 버전:

```text
260704-manual-native-finish-snap
```

## GMTITLE 변환 명령

SolidWorks DWG의 도면틀/표제란을 GstarCAD Mechanical GMTITLE 구조로 바꾸는 작업은 아래 4개 명령만 사용합니다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

| 명령 | 용도 | 도면 변경 |
| --- | --- | --- |
| `SWTITLESTATUS` | 현재 DWG 상태를 읽기 전용으로 진단하고 다음에 실행할 명령을 안내합니다. work 복사본 여부, 원본 시트 수, A2/A3/A4 예상 수량, 도면틀 정의 상태, 도면틀 정의 raw bbox 위험, A4 frame-only 상태, 겹친 GMTITLE target 쌍을 확인합니다. | 없음 |
| `SWTITLEPREPARE` | 변환 전에 필요한 정규화를 수행합니다. 실수 명령어 텍스트, 도면틀 정의 내부 표제란 형상, 사용 중이 아닌 오염/raw bbox 위험 도면틀 정의, 고아 GMTITLE 도면틀, 겹친 GMTITLE target 쌍 같은 후보를 먼저 보여주고 `YES` 확인 후 처리합니다. | 있음 |
| `SWTITLECONVERT` | 상태에 맞는 변환 단계를 실행합니다. 첫 native GMTITLE 생성, 같은 크기 기준 객체 준비, 기존 native GMTITLE 채택, 남은 시트 변환, A3/A4 native 교체, A4 frame-only 처리를 이 명령 안에서 안내합니다. | 있음 |
| `SWTITLEVERIFY` | 변환 결과를 읽기 전용으로 검증합니다. 남은 원본 객체, 중복/누락, native-like 상태, A2/A3/A4 수량, 최종 OK/WARN/FAIL을 확인합니다. | 없음 |

## 자동화 목표 참고

A3/A4 복제 GMTITLE을 한 장씩 native로 교체해야 하는 이유와, 사람이 반복 선택하는 단계를 줄이기 위한 장기 계획은 아래 문서에 정리합니다.

```text
docs/history/gmtitle-native-automation-goal-plan-2026-07-04.md
```

현재 기본값에서는 명령줄 `-GMTITLE` 자동 선택을 사용하지 않습니다. 이전 CAD 이력에서 일반 A3/A4 또는 ISO 제목블록으로 잘못 흐르는 사례가 있었기 때문입니다. 자동화는 별도 work 복사본에서 검증된 뒤에만 기본 흐름에 넣습니다.

현재 `SWTITLECONVERT`는 A3/A4 native 교체 후보가 여러 개일 때 새 공개 명령을 만들지 않고 같은 명령 안에서 선택지를 제공합니다.

```text
OPEN  = 다음 후보 1장만 처리
MANUAL = OPEN이 계속 새 GMTITLE 객체를 못 잡을 때, 대상/값/왼쪽 아래 기준점을 저장한 뒤 수동 생성 후 SWTITLECONVERT 재실행으로 마무리
BATCH = 처리 수량을 입력하고 여러 후보를 이어서 처리
Enter = 중단, 도면 변경 없음
```

`BATCH`도 GMTITLE 창 선택을 완전 자동화하지는 않습니다. 각 창에서 `DR_A*_Outline`, `DR_titlea_3rd`, `Frame positioning ON`, `Object move OFF`를 사람이 확인해야 합니다. 선택값이 틀리거나 실패하면 기존 쌍을 보존하고 중단합니다.

`MANUAL`은 새 공개 명령이 아니라 `SWTITLECONVERT` 안의 복구 선택지입니다. `MANUAL`을 입력하면 이번 후보의 기존 제목블록 값과 왼쪽 아래 기준점을 저장합니다. 그 다음 GstarCAD `GMTITLE`로 안내된 DR 용지/제목블록을 한 장 만들고, 삽입점은 긴 소수점 좌표를 직접 치지 말고 기존 도면틀 왼쪽 아래 끝점/스냅으로 지정합니다. 이후 `SWTITLECONVERT`를 다시 실행하면, 방금 만든 GMTITLE을 검사해서 값 복사와 기존 복제 쌍 삭제를 마무리합니다.

## 권장 실행 순서

항상 상태를 먼저 보고 다음 명령을 결정합니다.

```text
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE    상태가 요구할 때만
SWTITLESTATUS
SWTITLECONVERT    상태가 요구할 때만
SWTITLESTATUS
SWTITLEVERIFY     최종 검증 단계에서
```

`SWTITLESTATUS`가 `SWTITLEPREPARE`를 안내하면 변환을 반복하지 말고 먼저 정규화합니다.

`SWTITLESTATUS`가 `NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX`를 안내하거나 `SWTITLECONVERT`가 `ABORT_FRAME_DEFINITION_RAW_BBOX_RISK`로 멈추면, 변환을 반복하지 말고 도면틀 정의 복구/정규화 계획을 먼저 확인합니다.

`SWTITLESTATUS`가 `SWTITLECONVERT`를 안내하면 변환을 실행합니다.

표제란 없는 A4 시트는 `SWTITLECONVERT`가 `DR_titlea_3rd`를 만들지 않고 `DR_A4_Outline` 도면틀만 교체합니다. 형상/선택 범위 검사를 통과하지 못하면 기존 A4는 삭제하지 않습니다.

`SWTITLESTATUS`가 검증을 안내하면 `SWTITLEVERIFY`를 실행합니다.

## GMTITLE 창에서 확인할 값

`SWTITLECONVERT` 중 GMTITLE 창이 열리면 로그가 요구한 값만 선택합니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

사용하지 않을 것:

```text
일반 A2/A3/A4 용지
ISO 제목블록
스크린샷 좌표 클릭
긴 소수점 좌표 수동 입력
옛 transfer/fast/frame-only/A3A4 명령
```

## 옛 GMTITLE 명령

아래 명령들은 예전 실험/진단/복구 흐름에서 사용하던 이름입니다. 현재 일반 작업에서는 직접 입력하지 않습니다.

```text
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
SWTITLEGMTITLEVERIFYALL
```

이 명령들이 여전히 실행된다면 오래된 LSP가 로드된 상태일 수 있습니다. `swcad_load.lsp`를 다시 APPLOAD 하고 `SWTITLEVERSION`부터 확인하세요.

## GMTITLE 로그 파일

주요 로그는 `work` 폴더 아래에 저장됩니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

자주 보는 로그:

| 로그 | 의미 |
| --- | --- |
| `swcad_title_structure_diagnosis_last.txt` | `SWTITLESTATUS`의 구조 판단 요약 |
| `swcad_title_frame_embedded_title_clean_last.txt` | 도면틀 내부 표제란 형상 정리 로그 |
| `swcad_title_frame_style_normalization_clean_last.txt` | 도면틀 스타일 정규화 로그 |
| `swcad_title_transfer_apply_last.txt` | 첫 native GMTITLE 변환 단계 로그 |
| `swcad_title_fast_status_last.txt` | 내부 빠른 변환 준비 상태 로그 |
| `swcad_title_native_frame_check_last.txt` | A2/A3/A4 native-like 도면틀/제목블록 구조 비교 로그 |
| `swcad_title_duplicate_target_pair_clean_last.txt` | 겹친 GMTITLE target 쌍 정리 로그 |
| `swcad_title_verify_summary_last.txt` | `SWTITLEVERIFY` 최종 요약 |

## 완료 기준

완료는 아래 조건을 모두 만족할 때만 인정합니다.

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
frame-only 시트: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
겹친 GMTITLE target 쌍: 0
clone/native-upgrade/shared-link 경고: 0
실제 DR_titlea_3rd가 있는 대표 용지를 더블클릭하면 GMTITLE 표 편집창이 열림
표제란 없는 A4는 DR_A4_Outline 도면틀만 검증하고, 더블클릭할 제목블록은 없음
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```

## 치수/공차 명령

기존 치수/공차 작업 명령은 유지합니다.

| 명령 | 용도 |
| --- | --- |
| `SWAUTO` | SolidWorks DWG 치수 스타일을 GstarCAD Mechanical 기준으로 정리하는 기본 자동 처리 |
| `SWHELP` | 사용 순서와 문제 해결 명령 출력 |
| `SWDEBUG` | 선택 치수의 스타일, 공차, `DIMLFAC`, xdata 진단 |
| `SWFINDSTYLE` | 특정 치수 스타일을 사용하는 치수 찾기 |
| `SWTRYDELDIMSTYLES` | 사용하지 않는 치수 스타일 삭제 시도 |
| `SWDIMKEEPAMISO` | 현재 치수를 AM_ISO 계열 스타일로 매핑 |
| `SWMECHFITSEL` | 선택 치수를 Mechanical 맞춤공차 xdata로 변환 |
| `SWMECHFITALL` | 현재 도면의 치수를 Mechanical 맞춤공차 xdata로 일괄 변환 |
| `SWPURGESTYLES` | 사용하지 않는 치수 스타일 정리 |
