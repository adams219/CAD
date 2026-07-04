# GMTITLE 현재 실행 카드

CAD 화면 옆에 열어두고 따라가는 짧은 실행 순서입니다.

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
260704-target-overlap-adopt-main60-automation-policy
```

다른 버전이면 변환하지 말고 최신 LSP를 다시 APPLOAD 합니다.

특히 아래처럼 나오면 이전 세션의 낡은 LSP가 아직 살아 있는 것입니다.

```text
260704-nested-style-direct-main55
```

이 상태에서는 `SWTITLECONVERT`를 누르지 말고 최신 LSP를 다시 로드합니다.

## 시작 전 이력 확인

같은 실수를 반복하지 않기 위해 CAD에서 명령을 치기 전에 아래 기준을 먼저 확인합니다.

```text
GitHub 코드 기준: 36183b2 Guard A4 frame-only GMTITLE flow 이상
현재 LSP 기준: 260704-target-overlap-adopt-main60-automation-policy
사용자용 명령: SWTITLESTATUS / SWTITLEPREPARE / SWTITLECONVERT / SWTITLEVERIFY
```

주의:

```text
a4outline 기준에서는 DR_A4_Outline 정의 raw bbox 위험을 먼저 막고, 위험이 사라진 뒤 표제란 없는 A4는 SWTITLECONVERT가 제목블록 없이 도면틀만 교체합니다.
다른 PC나 열린 CAD 세션이 예전 LSP를 들고 있을 수 있으므로, 실제 CAD의 SWTITLEVERSION을 우선 확인합니다.
```

판단이 헷갈리면 먼저 아래 파일을 봅니다.

```text
docs/history/gmtitle-native-automation-goal-plan-2026-07-04.md
docs/history/gmtitle-history-gated-plan-2026-07-04.md
docs/history/gmtitle-main56-target-overlap-adoption-plan-2026-07-04.md
docs/investigations/gmtitle-main55-vs-main56-duplicate-target-pair-comparison-2026-07-04.md
docs/history/gmtitle-requirement-completion-audit-2026-07-04.md
```

열려 있는 CAD 도면이 저장 전 상태일 수 있으므로, 디스크 파일을 숨김 진단으로 다시 연 결과보다 현재 CAD에서 다시 실행한 `SWTITLESTATUS`/`SWTITLEVERIFY` 로그를 우선합니다.

로그를 볼 때는 현재 CAD에서 방금 실행한 결과인지 먼저 확인합니다. fixture/test 로그와 실제 작업복사본 로그를 섞어 보면 판단이 틀어집니다.

```text
우선 증거:
work/swcad_title_fast_status_last.txt
work/swcad_title_native_frame_check_last.txt
work/swcad_title_structure_diagnosis_last.txt
work/swcad_title_verify_summary_last.txt

주의:
old fixture/test suffix가 붙은 로그
다른 DWG에서 마지막으로 실행된 로그
```

`*_last.txt`는 마지막으로 실행한 DWG의 로그입니다. 현재 열린 세션과 디스크 파일 상태가 다르면, 먼저 열린 CAD에서 `SWTITLESTATUS`를 다시 실행해 최신 로그를 만듭니다.

## main60 로그 판독표

`SWTITLESTATUS`나 `SWTITLEVERIFY`를 실행한 뒤에는 아래 기준으로만 다음 행동을 정합니다.

| 로그 문구 | 의미 | 다음 행동 |
| --- | --- | --- |
| `SWTITLEVERSION`이 `260704-target-overlap-adopt-main60-automation-policy`가 아님 | 열린 CAD 세션이 예전 LSP를 사용 중 | 변환 금지. `APPLOAD`로 `swcad_load.lsp` 다시 로드 |
| `자동화 판단: 명령줄 -GMTITLE/설정파일 자동 선택은 기본 OFF입니다.` | 현재는 GMTITLE 창 선택을 사람이 확인하는 안정 모드 | 정상. 화면 좌표 클릭이나 `-GMTITLE` 강제 자동화 금지 |
| `NEXT_CREATE_FIRST_NATIVE_GMTITLE` | 아직 이 도면에 진짜 GMTITLE 기준 객체가 없음 | `SWTITLECONVERT`로 첫 native GMTITLE 1장 생성 |
| `WARN_CLONED_GMTITLE_FRAME_NEEDS_NATIVE_UPGRADE` | 겉모양은 맞지만 도면틀이 복제 구조라 native 증거 부족 | `SWTITLECONVERT`로 다음 후보 1장만 native 교체 |
| `WARN_SHARED_NATIVE_GMTITLE_LINKS` | 여러 복제본이 같은 native link를 공유할 가능성 | 완료로 보지 않음. `SWTITLECONVERT`로 fresh native 교체 |
| `WARN_A3_A4_TARGET_FRAME_NOT_NATIVE_LIKE` | A3/A4 도면틀이 GMTITLE처럼 보이지만 native-like 판정이 약함 | `native/복제 구조 비교 샘플`을 보고 clone/shared/geometry 중 원인 분류 |
| `WARN_TARGET_FRAME_SELECTION_RISK` | 겹친 도면틀 bbox 때문에 더블클릭/선택이 다른 객체를 잡을 수 있음 | `SWTITLEPREPARE` 가능 여부 확인 후 겹침 정리 |
| `NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX` | DR 도면틀 정의 자체 bbox가 위험함 | 변환 반복 금지. A3/A4 정의 문제 분석 |
| `ABORT_FRAME_DEFINITION_RAW_BBOX_RISK` | 도면 삭제 전에 위험을 감지하고 멈춤 | 정상 중단. 기존 A3/A4 삭제하지 말고 원인 분석 |
| `SWTITLEVERIFY_FINAL_OK` | 수량과 잔여물 기준 통과 | 대표 `DR_titlea_3rd` 더블클릭, A4 frame-only 형상 확인 |

main60에서 유효한 로그에는 아래 문구가 같이 보여야 합니다.

```text
native/복제 구조 비교 샘플:
자동화 판단:
```

이 문구가 없으면 현재 CAD가 낡은 LSP를 들고 있을 가능성이 높으므로, 그 로그로 결론을 내리지 않습니다.

## 현재 저장된 workcopy 기준

현재 디스크에 저장된 기본 작업복사본은 아직 변환 전 상태입니다. final completion gate도 이 이유로 실패하는 것이 정상입니다.

```text
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
원본 표제란 시트: 13
원본 도면틀: 15
표제란 없는 도면틀 시트: 2
target 도면틀/제목블록: 0 / 0
```

이 상태에서 다음 실제 CAD 명령은 `SWTITLECONVERT`입니다.

## 기본 순서

항상 상태부터 봅니다.

```text
SWTITLESTATUS
```

상태가 정규화를 요구하면:

```text
SWTITLEPREPARE
SWTITLESTATUS
```

상태가 `NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX`를 안내하거나 `SWTITLECONVERT`가 `ABORT_FRAME_DEFINITION_RAW_BBOX_RISK`로 멈추면:

```text
SWTITLECONVERT 반복 금지
SWTITLESTATUS 로그의 DR 도면틀 정의 raw bbox 위험 확인
도면틀 정의 복구/정규화 계획 확인
```

상태가 변환을 요구하면:

```text
SWTITLECONVERT
SWTITLESTATUS
```

상태가 최종 검증을 요구하면:

```text
SWTITLEVERIFY
```

## GMTITLE 창에서 확인

`SWTITLECONVERT` 중 GMTITLE 창이 열리면 로그가 요구한 값만 선택합니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

현재 자동 선택을 기본으로 쓰지 않는 이유:

```text
명령줄 -GMTITLE 자동 선택은 이전 CAD 이력에서 일반 A3/A4 또는 ISO 제목블록으로 잘못 흐른 적이 있습니다.
복제 GMTITLE은 겉모양과 속성값이 맞아도 native-like 증거가 부족할 수 있습니다.
자동화 개선은 docs/history/gmtitle-native-automation-goal-plan-2026-07-04.md의 검증 조건을 통과한 뒤 반영합니다.
```

## 하지 말 것

```text
일반 A2/A3/A4 선택
ISO 제목블록 선택
스크린샷 좌표 클릭
긴 소수점 좌표 직접 입력
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
```

위 예전 명령이 필요해 보이면 오래된 흐름으로 돌아간 것입니다. `SWTITLESTATUS` 결과를 다시 봅니다.

## main56에서 추가로 막는 실수

```text
같은 위치에 겹친 GMTITLE target 쌍은 SWTITLESTATUS가 표시합니다.
겹친 target 쌍은 SWTITLEPREPARE가 work 복사본에서만 YES 확인 후 정리합니다.
SWTITLECONVERT는 이미 같은 위치에 native GMTITLE 쌍이 있으면 새로 만들지 않고 그 쌍을 채택합니다.
DR_A3_Outline 안의 native-format title-like 형상은 그 자체만으로 삭제하지 않습니다.
별도 DR_titlea_3rd와 실제로 겹치는 경우에만 정규화 후보로 봅니다.
A4 frame-only 기준 객체가 없으면 빠른 일괄 변환에서 A4를 같이 처리하지 않습니다.
DR_A4_Outline 정의 raw bbox가 A4보다 과도하게 크면 기존 A4를 삭제하지 않고 먼저 중단합니다.
```

## 완료 조건

`SWTITLEVERIFY`가 아래 상태를 만족해야 합니다.

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
```

마지막으로 실제 `DR_titlea_3rd` 제목블록이 있는 대표 용지만 더블클릭합니다.
표제란 없는 A4는 `DR_A4_Outline` 도면틀 수량/형상 검증으로 확인하며, 더블클릭할 제목블록은 없습니다.

기대 결과:

```text
GMTITLE 표 편집창 열림
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```
