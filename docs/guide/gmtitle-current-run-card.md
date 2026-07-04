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
260705-verify-source-priority
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
로컬 코드 기준: 현재 브랜치 `codex/gm-title`
현재 LSP 기준: 260705-verify-source-priority
사용자용 명령: SWTITLESTATUS / SWTITLEPREPARE / SWTITLECONVERT / SWTITLEVERIFY
```

주의:

```text
a4outline 기준에서는 DR_A4_Outline 정의 raw bbox 위험을 먼저 막고, 위험이 사라진 뒤 표제란 없는 A4는 SWTITLECONVERT가 제목블록 없이 도면틀만 교체합니다.
다른 PC나 열린 CAD 세션이 예전 LSP를 들고 있을 수 있으므로, 실제 CAD의 SWTITLEVERSION을 우선 확인합니다.
```

판단이 헷갈리면 먼저 아래 파일을 봅니다.

```text
docs/guide/gmtitle-goal-mode-plan.md
docs/history/gmtitle-native-automation-goal-plan-2026-07-04.md
docs/history/gmtitle-history-gated-plan-2026-07-04.md
docs/history/gmtitle-main56-target-overlap-adoption-plan-2026-07-04.md
docs/investigations/gmtitle-main55-vs-main56-duplicate-target-pair-comparison-2026-07-04.md
docs/history/gmtitle-requirement-completion-audit-2026-07-04.md
```

특히 목표모드에서 이어갈 때는 `docs/guide/gmtitle-goal-mode-plan.md`를 먼저 봅니다. 그 문서의 중단 규칙에 걸리면 같은 명령을 반복하지 않고, 최신 `SWTITLESTATUS` 로그로 원인을 다시 분류합니다.

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

## 현재 로그 판독표

`SWTITLESTATUS`나 `SWTITLEVERIFY`를 실행한 뒤에는 아래 기준으로만 다음 행동을 정합니다.

| 로그 문구 | 의미 | 다음 행동 |
| --- | --- | --- |
| `SWTITLEVERSION`이 `260705-verify-source-priority`가 아님 | 열린 CAD 세션이 예전 LSP를 사용 중 | 변환 금지. `APPLOAD`로 `swcad_load.lsp` 다시 로드 |
| `자동화 판단: 명령줄 -GMTITLE/설정파일 자동 선택은 기본 OFF입니다.` | 현재는 GMTITLE 창 선택을 사람이 확인하는 안정 모드 | 정상. 화면 좌표 클릭이나 `-GMTITLE` 강제 자동화 금지 |
| `NEXT_CREATE_FIRST_NATIVE_GMTITLE` | 아직 이 도면에 진짜 GMTITLE 기준 객체가 없음 | `SWTITLECONVERT`로 첫 native GMTITLE 1장 생성 |
| `WARN_CLONED_GMTITLE_FRAME_NEEDS_NATIVE_UPGRADE` | 겉모양은 맞지만 도면틀이 복제 구조라 native 증거 부족 | `SWTITLECONVERT`로 다음 후보 1장만 native 교체 |
| `WARN_SHARED_NATIVE_GMTITLE_LINKS` | 여러 복제본이 같은 native link를 공유할 가능성 | 완료로 보지 않음. `SWTITLECONVERT`로 fresh native 교체 |
| `WARN_A3_A4_TARGET_FRAME_NOT_NATIVE_LIKE` | A3/A4 도면틀이 GMTITLE처럼 보이지만 native-like 판정이 약함 | `native/복제 구조 비교 샘플`을 보고 clone/shared/geometry 중 원인 분류 |
| `A3 도면틀 참고: DR_A3_Outline은 native GMTITLE에서도 INSERT/block 참조` | 도면틀이 블록처럼 선택되는 것 자체는 실패가 아님 | `DR_titlea_3rd` 제목블록 더블클릭과 `A3/A4 native 교체 후보: 0`으로 완료 판단 |
| `WARN_TARGET_FRAME_SELECTION_RISK` | 겹친 도면틀 bbox 때문에 더블클릭/선택이 다른 객체를 잡을 수 있음 | `SWTITLEPREPARE` 가능 여부 확인 후 겹침 정리 |
| `NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX` | DR 도면틀 정의 자체 bbox가 위험함 | 변환 반복 금지. A3/A4 정의 문제 분석 |
| `ABORT_FRAME_DEFINITION_RAW_BBOX_RISK` | 도면 삭제 전에 위험을 감지하고 멈춤 | 정상 중단. 기존 A3/A4 삭제하지 말고 원인 분석 |
| `SWTITLEVERIFY_FINAL_FAIL`와 `A3/A4 native 교체 필요 쌍`이 같이 나옴 | A4 누락이 있어도 A3/A4 native 교체가 먼저임 | `SWTITLESTATUS` 후 `SWTITLECONVERT`로 A3/A4 후보 처리 |
| `SWTITLEVERIFY_FINAL_OK` | 수량과 잔여물 기준 통과 | 대표 `DR_titlea_3rd` 더블클릭, A4 frame-only 형상 확인 |

현재 유효한 로그에는 아래 문구가 같이 보여야 합니다.

```text
native/복제 구조 비교 샘플:
자동화 판단:
```

이 문구가 없으면 현재 CAD가 낡은 LSP를 들고 있을 가능성이 높으므로, 그 로그로 결론을 내리지 않습니다.

## 현재 workcopy 기준

2026-07-05 숨김 CAD 검증 기준 기본 작업복사본은 아직 변환 전 상태입니다.

```text
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
남은 원본 표제란 시트: 13
남은 원본 도면틀: 15
표제란 없는 도면틀 시트: 2
대상 도면틀/제목블록 쌍: 0
필요한 용지 수: A2 1, A3 12, A4 2
없는 native 기준 객체: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline
```

현재 `SWTITLEVERIFY`도 완료가 아니라고 확인합니다.

```text
다음: SWTITLECONVERT로 첫 native GMTITLE 기준 객체를 만드세요.
현재 기본 workcopy의 첫 대상은 DR_A2_Outline / DR_titlea_3rd입니다.
```

이 상태에서 다음 실제 CAD 명령은 `SWTITLECONVERT`입니다. 첫 기준 객체를 만든 뒤 `SWTITLESTATUS`가 다음 필요한 용지 크기를 다시 안내합니다.

이전 중간 workcopy에서 확인된 중요한 판정은 아래와 같습니다. 현재 기본 workcopy가 아직 이 단계가 아니라면 참고 이력으로만 봅니다.

```text
DR_A3_Outline 정의 내부 표제란 형상 후보: 0
DR_A3_Outline 현재 분류: outline-only
A3/A4 native 교체 후보: 10
```

따라서 A3 후보 단계까지 진행된 도면에서 다음 원인은 "A3 도면틀 정의 안의 표제란 오염"이 아니라 "복제/shared-link GMTITLE 쌍이 native-like로 증명되지 않은 상태"입니다. 이 상태에서는 도면틀 정의를 지우거나 정규화하려고 하지 말고, `SWTITLECONVERT`로 다음 A3 후보 1장을 fresh native GMTITLE로 교체하는 것이 맞습니다.

2026-07-04 추가 CAD 검증:

```text
SWTITLECONVERT
OPEN
GMTITLE 창에서 DR_A3_Outline / DR_titlea_3rd 선택
Frame positioning ON
Object move OFF
확인
SWTITLESTATUS
```

검증 결과:

```text
결과: UPGRADED_CLONE_TO_NATIVE_GMTITLE
Native GMTITLE aligned to 복제d frame location: moved=0, dx=0, dy=0
복사한 속성 수: 11
기존 복제 제목블록 삭제: 예
기존 복제 도면틀 삭제: 예
A3/A4 native 교체 후보: 11 -> 10
A3 native-like 대상 도면틀 수: 1 -> 2
```

따라서 `OPEN` 경로는 최소 1장에 대해 실제 교체 성공이 확인됐습니다. 아직 완료는 아니며, 같은 방식으로 남은 후보 10개를 처리해야 합니다. 각 GMTITLE 창에서는 여전히 선택값을 눈으로 확인합니다.

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

A3/A4 native 교체 후보가 여러 개 남아 있으면 `SWTITLECONVERT`가 선택지를 묻습니다.

```text
OPEN  = 다음 후보 1장만 처리
MANUAL = OPEN이 계속 새 GMTITLE 객체를 못 잡을 때 쓰는 준비/마무리 복구
BATCH = 처리 수량을 입력하고 여러 후보를 이어서 처리
Enter = 중단, 도면 변경 없음
```

`BATCH`는 명령 반복을 줄이는 기능입니다. GMTITLE 창 선택을 대신 해 주는 기능은 아니므로, 각 창에서 로그가 요구한 DR 용지/제목블록/옵션을 확인합니다.

`BATCH`는 아래 조건일 때만 사용합니다.

```text
OPEN으로 최소 1장 성공한 뒤
SWTITLESTATUS에서 A3/A4 native 교체 후보가 여러 개 남아 있을 때
반복되는 후보들이 같은 방식으로 DR 용지/DR_titlea_3rd를 선택하면 되는 상태일 때
각 GMTITLE 창을 직접 볼 수 있는 전체화면 CAD 상태일 때
```

`BATCH` 중 한 번이라도 ISO 용지, ISO 제목블록, Object move ON, 예상과 다른 DR 용지가 보이면 `확인`을 누르지 말고 취소합니다. 그 뒤에는 `SWTITLESTATUS`를 다시 실행합니다.

숨김 CAD 또는 SCRIPT 자동화에서는 `BATCH`가 실행되면 안 됩니다. 검증 suite는 이 경우 `ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE`로 멈추고 후보와 INSERT를 그대로 보존하는지 확인합니다.

`MANUAL`은 자동 생성 흐름이 `ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS`처럼 끝날 때 쓰는 복구 선택지입니다. `MANUAL`로 준비한 뒤 안내된 값으로 GstarCAD `GMTITLE` 한 장을 만들고, 삽입점은 긴 좌표를 직접 치지 말고 기존 도면틀 왼쪽 아래 끝점/스냅으로 지정합니다. 다시 `SWTITLECONVERT`를 실행하면 pending 마무리 단계가 먼저 실행됩니다.

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

2026-07-04 실제 CAD 확인에서는 A3 native 교체 중 GMTITLE 창 기본값이 아래처럼 잘못 떴습니다.

```text
용지/도면틀: A3 (297x420mm)
제목블록: ISO 제목 블록 A
Object move: ON
```

이 상태에서 `확인`을 누르면 안 됩니다. 실제 표시값을 로그가 요구한 `DR_A*_Outline`, `DR_titlea_3rd`, `Object move OFF`로 바꿀 수 있을 때만 진행하고, 불확실하면 `Esc`로 취소합니다. 취소하면 기존 쌍은 보존됩니다.

키보드로 바꾸는 순서:

```text
용지 콤보에 포커스가 있을 때 Alt+Down
로그가 요구한 DR_A*_Outline 선택
Enter
Tab
Alt+Down
DR_titlea_3rd 선택
Enter
Alt+M
Space
```

`Alt+M`은 객체 이동 체크박스로 포커스를 보내고, `Space`가 체크를 끕니다. 마지막 상태가 `Object move OFF`인지 눈으로 확인한 뒤에만 진행합니다.

현재 기본 workcopy에서 첫 변환이면 로그가 요구하는 용지는 `DR_A2_Outline`입니다. A3 후보 교체 단계에 들어간 뒤에는 `DR_A3_Outline`이 나올 수 있습니다.

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
