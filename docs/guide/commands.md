# CAD Tool 명령어

> 2026-07-06 기준 변경: `docs/guide/gmtitle-unified-flow-reset.md`가 GMTITLE 변환의 최우선 기준입니다. A2/A3/A4는 모두 같은 GMTITLE 흐름으로 보고, `frame-only`는 A4 전용 정책이 아니라 원본 표제란 부재가 검증된 경우의 예외로만 해석합니다.

이 문서는 사용자가 CAD 명령창에 직접 입력하는 공개 명령만 정리합니다.

## 현재 기준 문서

`docs/guide/gmtitle-unified-flow-reset.md`가 최우선 기준이고, 이 문서와 `docs/guide/gmtitle-current-run-card.md`는 실제 입력 명령을 확인하는 실행 카드입니다. `docs/history`와 `docs/investigations`는 과거 실험/실패/조사 기록이므로, 거기에 나온 낡은 순서를 그대로 실행하지 않습니다.

`frame-only`는 A4 전용 정책이 아니라, 원본 시트에 표제란/제목블록이 실제로 없다고 검증된 경우에만 적용하는 예외입니다. 기본 변환은 A2/A3/A4 모두 `DR_A*_Outline + DR_titlea_3rd` 공통 GMTITLE 흐름입니다.

## 기본 로드

GstarCAD에서 `APPLOAD`를 실행한 뒤 아래 파일을 로드합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

GMTITLE 도구만 직접 로드해야 할 때는 아래 파일을 사용할 수 있습니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

로드 후 버전을 확인합니다.

```text
SWTITLEVERSION
```

현재 기준 버전:

```text
260706-unified-title-missing-3
```

다른 버전이 보이면 변환하지 말고 최신 LSP를 다시 `APPLOAD`합니다.

## GMTITLE 변환 명령

SolidWorks DWG의 도면틀/표제란을 GstarCAD Mechanical GMTITLE 구조로 바꾸는 일반 작업은 아래 권장 4개 명령만 사용합니다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERTNEXT
SWTITLEVERIFY
```

수동 응답을 직접 고르고 싶을 때만 `SWTITLECONVERT`를 대신 사용합니다.

```text
SWTITLECONVERT
```

`SWTITLECONVERTNEXT`는 현재 상태에서 안전한 다음 응답만 자동 선택합니다. 첫 native 생성/누락 크기 생성/빠른 변환은 `YES`, A3/A4 native 교체는 다음 후보 1장 `OPEN`으로 처리합니다. 단, GMTITLE 창에서 `DR_A*_Outline`, `DR_titlea_3rd`, `Frame positioning: ON`, `Object move: OFF`를 눈으로 확인하는 단계는 그대로 필요합니다.

자동화 경계:

```text
LSP가 자동 처리:
  현재 후보 판별
  왼쪽 아래 배치점 전송
  표제란 값 복사
  이전 SolidWorks 원본 정리
  새 결과 검사/rollback

사람이 확인:
  GMTITLE 창의 DR_A*_Outline 용지
  DR_titlea_3rd 제목블록
  Frame positioning ON
  Object move OFF
```

GMTITLE 창 선택까지 완전 자동으로 켜지 않는 이유는 GstarCAD가 일반/ISO 기본값으로 열릴 수 있고, 리본/스크린 좌표 자동화는 안정 증거가 없기 때문입니다. 이 경계가 현재 가장 안전한 자동화 범위입니다.

| 명령 | 용도 | 도면 변경 |
| --- | --- | --- |
| `SWTITLESTATUS` | 현재 DWG 상태를 읽기 전용으로 진단하고 다음에 실행할 명령을 안내합니다. work 복사본 여부, 원본 시트 수, A2/A3/A4 예상 수량, GMTITLE target 수량, 도면틀 정의 상태, title-missing/frame-only 예외 상태를 확인합니다. | 없음 |
| `SWTITLEPREPARE` | 변환 전에 필요한 정리만 수행합니다. 실수로 들어간 명령어 텍스트, 겹친 GMTITLE target, 오염 의심 도면틀 정의, 위험한 raw bbox 등을 후보로 보여주고 `YES` 확인 뒤 처리합니다. | 있음 |
| `SWTITLECONVERTNEXT` | 상태에 맞는 변환 단계를 실행하면서 `YES`/`OPEN` 같은 반복 응답만 자동 선택합니다. 사용자는 `YES`, `OPEN`, `BATCH`, `MANUAL`을 다시 입력하지 않고, GMTITLE 창의 DR 용지/제목블록/옵션만 확인합니다. | 있음 |
| `SWTITLECONVERT` | `SWTITLECONVERTNEXT`와 같은 변환 흐름을 사용하되, `YES`/`OPEN`/`BATCH`/`MANUAL` 응답을 사용자가 직접 고릅니다. | 있음 |
| `SWTITLEVERIFY` | 변환 결과를 읽기 전용으로 검증합니다. 남은 원본, 누락/중복, A2/A3/A4 수량, native-like 상태, 최종 OK/WARN/FAIL을 확인합니다. | 없음 |

여러 DWG가 열려 있으면 `SWTITLEPREPARE`, `SWTITLECONVERTNEXT`, `SWTITLECONVERT`가 현재 활성 DWG 경로를 먼저 보여주고 `ACTIVE` 확인을 요구할 수 있습니다. 목표 work 복사본이 맞을 때만 `ACTIVE`를 입력하고, 조금이라도 다르면 Enter로 중단합니다.

## 권장 실행 순서

항상 상태를 먼저 보고 다음 명령을 결정합니다.

```text
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE    상태가 요구할 때만
SWTITLESTATUS
SWTITLECONVERTNEXT    상태가 요구할 때만
SWTITLESTATUS
SWTITLEVERIFY     최종 검증 단계에서
```

`SWTITLESTATUS`가 `SWTITLEPREPARE`를 안내하면 변환을 반복하지 말고 먼저 정리합니다.

`SWTITLESTATUS`가 `NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX`를 안내하거나 `SWTITLECONVERT`가 `ABORT_FRAME_DEFINITION_RAW_BBOX_RISK`로 멈추면 기존 도면을 지우지 않는 보호 중단입니다. 같은 변환을 반복하지 말고 로그를 확인합니다.

수동으로 GMTITLE 창에서 한 장을 처리한 뒤에는 작업복사본을 저장하고 GstarCAD를 닫은 다음, CAD 밖 PowerShell에서 아래 래퍼를 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_after_manual_gmtitle_step.ps1 -Compact
```

이 기본 명령은 긴 next-action 카드 대신 다음 한 단계 요약만 보여줍니다. 전체 카드가 필요할 때만 `-Compact`를 빼고 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_after_manual_gmtitle_step.ps1
```

이 래퍼는 DWG를 편집하지 않고 direct probe 갱신, 다음 한 단계 요약 출력, 필요 시 final completion gate 실행을 한 번에 묶습니다. 그래서 예전 로그를 보고 같은 `SWTITLECONVERTNEXT`를 반복하는 실수를 줄입니다.

작업복사본 열기부터 한 장 처리 후 점검까지 한 번에 묶으려면 아래 세션 래퍼를 사용할 수 있습니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_manual_gmtitle_session.ps1
```

이 세션 래퍼는 기본적으로 `run_next_cad_action.ps1`를 자동 direct probe 갱신 없이 실행해서, 저장된 작업복사본이 실제로 변환 가능한 상태인지 확인합니다. 카드가 정리/검토를 요구하면 CAD를 열지 않고 멈추므로, 상태가 바뀌었는데도 `SWTITLECONVERTNEXT`를 반복하는 실수를 줄입니다. hidden direct probe 갱신까지 먼저 하고 싶을 때만 `-AutoRefreshDirectProbe`를 붙입니다.

CAD를 열지 않고 이번에 고를 용지/제목블록만 먼저 확인하려면 아래처럼 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_manual_gmtitle_session.ps1 -PreflightOnly
```

긴 next-action 카드 대신 짧은 요약만 보고 싶으면 `-Compact`를 같이 붙입니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_manual_gmtitle_session.ps1 -PreflightOnly -Compact
```

CAD 로그 파일을 직접 열었을 때 한글이 깨져 보이면 아래 읽기 전용 도구로 확인합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\read_cad_text_log.ps1 -Find "짧은 GMTITLE 선택 카드|용지/도면틀|제목블록|켜둘 옵션|꺼둘 옵션"
```

수동 명령인 `SWTITLECONVERT` 안에서 입력을 물으면 상태별로 아래처럼 답합니다.

`SWTITLECONVERTNEXT`를 사용하는 경우에는 아래 응답을 직접 입력하지 않습니다. 아래 표는 수동 `SWTITLECONVERT`를 쓸 때만 적용합니다.

```text
첫 native GMTITLE 생성: YES
누락된 용지 크기의 첫 native GMTITLE 생성: YES
A3/A4 native 교체 1장 처리: OPEN
BATCH는 OPEN으로 최소 1장 성공한 뒤, 같은 DR 용지/제목블록/옵션이 반복된다는 걸 눈으로 확인할 수 있을 때만 사용
OPEN이 새 GMTITLE을 못 잡거나 NO_INSERTS가 반복됨: MANUAL
판단이 애매하거나 현재 DWG가 다름: Enter로 중단
```

## GMTITLE 창에서 확인할 값

`SWTITLECONVERTNEXT` 또는 수동 `SWTITLECONVERT` 중 GMTITLE 창이 열리면 로그가 요구한 값만 선택합니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

CAD 명령줄에 `GMTITLE`, `TIT`, 일반 `OPEN`을 직접 입력하지 않습니다. 일반 `GMTITLE`/`TIT`는 내부 현재 선택 상태나 삽입점 프롬프트로 빠질 수 있고, `SWTITLECONVERTNEXT`/`SWTITLECONVERT`가 수행하는 배치점 자동 전송, 값 복사, 원본 정리를 건너뜁니다.

주의: 수동 `SWTITLECONVERT` 안에서 물어보는 `OPEN` 응답은 CAD 일반 `OPEN` 명령이 아닙니다. 명령창에 직접 `OPEN`을 치는 흐름과 구분합니다.

사용하지 않을 것:

```text
일반 A2/A3/A4 용지
ISO 제목블록
스크린샷 좌표 클릭
긴 소수점 좌표 수동 입력
옛 transfer/fast/frame-only/A3A4 명령
```

## A3/A4 native 교체

A3/A4 복제 GMTITLE은 화면상 비슷해도 일부가 고급 속성 편집기로 열릴 수 있습니다. 그래서 `SWTITLECONVERTNEXT`는 필요한 경우 복제/shared-link 쌍을 fresh native GMTITLE로 한 장씩 교체합니다.

`SWTITLESTATUS`가 native 교체 후보를 표시하면 title-missing/frame-only 예외보다 그 후보를 먼저 처리합니다.

```text
SWTITLECONVERTNEXT
SWTITLESTATUS
```

후보 수가 줄어들면 정상 진행입니다. 후보 수가 줄지 않고 같은 경고가 반복되면 변환을 계속 누르기보다 `SWTITLEVERIFY` 로그와 해당 제목블록 더블클릭 동작을 확인합니다.

`BATCH`는 처음부터 쓰는 빠른 길이 아닙니다. 먼저 `OPEN`으로 A3/A4 후보 1장이 실제로 줄어드는지 확인한 뒤, 다음 후보들이 같은 DR 용지/제목블록/옵션으로 반복된다는 걸 눈으로 확인할 수 있을 때만 사용합니다.

## title-missing/frame-only 예외

원본 시트에 표제란/제목블록이 실제로 없다고 검증된 경우만 title-missing/frame-only 예외로 봅니다. A4라는 용지 크기만으로 이 경로를 선택하지 않습니다.

title-missing/frame-only 처리 조건:

```text
원본 표제란 시트가 먼저 정리됨
해당 크기의 DR_A*_Outline 정의가 안전함
새 도면틀 bbox가 원본 도면틀과 맞음
불필요한 DR_titlea_3rd 제목블록이 생기지 않음
기존 도면 내용이 삭제되지 않음
```

`WAITING_FOR_TITLE_MISSING_OUTLINE_DEFINITION` 또는 `NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION`이 나오면 `SWTITLECONVERTNEXT`를 반복하지 말고 `SWTITLEPREPARE`로 정의 준비/검증을 먼저 합니다.
현재 코드 상태명에 A4가 남아 있을 수 있지만 guide 기준으로는 "원본 표제란이 없는 시트의 도면틀 정의 준비"로 해석합니다. `ready-native-outside-markers`는 공식 native 도면틀의 작은 바깥 마커만 허용된 상태입니다. 이 상태에서는 effective 형상과 raw selection 검사가 통과했는지 확인한 뒤 예외 변환을 진행할 수 있습니다.

## 옛 GMTITLE 명령

아래 명령들은 예전 실험/진단/복구 흐름에서 쓰던 이름입니다. 일반 작업에서는 직접 입력하지 않습니다.

```text
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
SWTITLEGMTITLEVERIFYALL
```

이 명령들이 CAD에서 실행된다면 오래된 LSP가 로드된 상태일 수 있습니다. `swcad_load.lsp`를 다시 `APPLOAD`하고 `SWTITLEVERSION`부터 확인합니다.

## 주요 로그

로그는 보통 아래 폴더에 저장됩니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

자주 보는 로그:

| 로그 | 의미 |
| --- | --- |
| `swcad_title_structure_diagnosis_last.txt` | `SWTITLESTATUS` 구조 판단 요약 |
| `swcad_title_transfer_apply_last.txt` | 첫 native GMTITLE 변환 단계 |
| `swcad_title_native_upgrade_last.txt` | A3/A4 native 교체 |
| `swcad_title_verify_summary_last.txt` | `SWTITLEVERIFY` 최종 요약 |
| `swcad_title_frame_style_normalization_clean_last.txt` | 도면틀 스타일 정규화 |
| `swcad_title_duplicate_target_pair_clean_last.txt` | 겹친 GMTITLE target 정리 |

주의: `*_last.txt`는 마지막으로 실행한 DWG 기준입니다. 검증 suite나 probe를 돌린 뒤에는 실제 작업 DWG가 아니라 `swtitle_*_probe*.dwg` 로그가 마지막일 수 있으므로, 로그 안의 `DWG 파일:` 경로를 먼저 확인합니다.

## 완료 기준

아래 조건이 모두 맞기 전에는 완료가 아닙니다.

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
DR_titlea_3rd가 있는 대표 A2/A3 제목블록 더블클릭 시 GMTITLE 표 편집창 열림
원본 표제란 부재가 검증된 title-missing 시트는 해당 DR_A*_Outline 도면틀만 검증하고 제목블록은 없음
도면 내부 번호, 주석, BOM, 치수, 모델 형상 유지
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
