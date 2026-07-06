# GMTITLE 실제 CAD 변환 체크리스트

> 2026-07-06 기준 변경: `docs/guide/gmtitle-unified-flow-reset.md`가 GMTITLE 변환의 최우선 기준입니다. A2/A3/A4는 모두 같은 GMTITLE 흐름으로 보고, `frame-only`는 A4 전용 정책이 아니라 원본 표제란 부재가 검증된 경우의 예외로만 해석합니다.

이 문서는 GstarCAD 화면에서 SolidWorks DWG 작업복사본을 native GMTITLE 구조로 바꿀 때 따라가는 순서입니다.

사용자는 아래 권장 4개 명령만 직접 입력합니다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERTNEXT
SWTITLEVERIFY
```

수동 응답을 직접 고르고 싶을 때만 `SWTITLECONVERT`를 사용합니다. `SWTITLECONVERTNEXT`는 현재 상태의 다음 응답만 자동 선택하며, GMTITLE 창의 DR 용지/제목블록/옵션 확인은 직접 해야 합니다.

아래 옛 명령은 직접 입력하지 않습니다.

```text
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
SWTITLEGMTITLEVERIFYALL
```

옛 명령이 실행된다면 오래된 LSP가 로드된 상태일 수 있습니다. `swcad_load.lsp`를 다시 `APPLOAD`하고 `SWTITLEVERSION`부터 확인합니다.

## 0. 작업복사본 확인

변환은 반드시 `work` 폴더 아래 복사본에서만 합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

`Downloads`의 원본 DWG나 실제 납품 원본에서 바로 실행하지 않습니다.

## 1. LSP 로드

GstarCAD에서 `APPLOAD`로 아래 파일을 로드합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

GMTITLE 도구만 직접 로드할 때는 아래 파일을 사용할 수 있습니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

로드 후 버전을 확인합니다.

```text
SWTITLEVERSION
```

기대 버전:

```text
260706-unified-title-missing-7
```

다른 버전이면 변환하지 말고 최신 LSP를 다시 로드합니다.

## 2. 상태 진단

먼저 읽기 전용 상태 진단을 실행합니다.

```text
SWTITLESTATUS
```

확인할 내용:

```text
현재 DWG가 work 폴더 복사본인지
원본 SolidWorks 표제란 시트 수
원본 SolidWorks 도면틀 수
표제란 없는 frame-only 시트 수
A2/A3/A4 예상 수량
GMTITLE target 도면틀/제목블록 수량
DR_A2/A3/A4_Outline 도면틀 정의 상태
도면틀 정의 raw bbox 위험 여부
A2/A3/A4 native 교체 후보 수
title-missing/frame-only 예외 처리 가능 여부
다음 권장 명령
```

기본 변환 전 상태의 예:

```text
NEXT_CREATE_FIRST_NATIVE_GMTITLE
원본 표제란 시트: 13
원본 도면틀: 15
표제란 없는 도면틀 시트: 2
예상 수량:
  A2: 1
  A3: 12
  A4: 2
target 도면틀: 0
target 제목블록: 0
```

이 상태에서는 `SWTITLECONVERTNEXT`로 첫 native GMTITLE 기준 객체를 만듭니다. 수동 응답을 직접 고르고 싶을 때만 `SWTITLECONVERT`를 사용합니다.

## 3. 정리가 필요할 때

`SWTITLESTATUS`가 정리를 요구할 때만 실행합니다.

```text
SWTITLEPREPARE
```

정리 후보 예:

```text
도면에 실수로 들어간 명령어 TEXT/MTEXT
source-contaminated 도면틀 정의
별도 DR_titlea_3rd와 실제로 겹치는 도면틀 내부 표제란 형상
사용 중이 아닌 위험 raw bbox 도면틀 정의
고아 GMTITLE 도면틀
같은 위치에 겹친 GMTITLE target 쌍
```

보호 대상:

```text
도면 내부 번호
좌표 표시
주석
BOM
치수
모델 형상
정상 DR_titlea_3rd 제목블록
```

후보 목록이 실제로 지워도 되는 항목일 때만 `YES`를 입력합니다. 이상하면 멈추고 로그를 확인합니다.

정리 후 다시 상태를 봅니다.

```text
SWTITLESTATUS
```

## 4. 변환 실행

`SWTITLESTATUS`가 변환을 안내할 때 실행합니다.

```text
SWTITLECONVERTNEXT
```

이 명령은 현재 상태에 맞춰 필요한 단계만 진행하고, `YES`/`OPEN` 같은 반복 응답만 자동 선택합니다. 수동 응답을 직접 고르고 싶을 때만 `SWTITLECONVERT`를 대신 사용합니다.

```text
첫 native GMTITLE 기준 객체 생성
기존 SolidWorks 표제란 텍스트 추출
시트 크기 자동 인식
같은 위치의 기존 native GMTITLE 쌍 채택
남은 원본 시트 변환
A2/A3/A4 복제 쌍을 fresh native GMTITLE로 교체
title-missing/frame-only 예외 도면틀만 교체
기존 SolidWorks 도면틀/표제란/잔여물 제거
```

GMTITLE 창이 열리면 로그가 요구한 값만 선택합니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

금지:

```text
일반 A2/A3/A4 용지 선택
ISO 제목블록 선택
Object move ON 상태로 확인
스크린샷 좌표 클릭
긴 소수점 좌표 수동 입력
```

수동 `SWTITLECONVERT`가 명령창 입력을 물으면 아래 기준만 사용합니다.

`SWTITLECONVERTNEXT`를 사용하는 경우에는 `YES`, `OPEN`, `BATCH`, `MANUAL`을 다시 입력하지 않습니다. 아래 응답은 수동 `SWTITLECONVERT`에서 직접 고를 때만 사용합니다.

```text
첫 native GMTITLE 기준 객체 생성: YES
누락된 용지 크기의 첫 native GMTITLE 생성: YES
A2/A3/A4 native 교체 1장 처리: OPEN
BATCH는 OPEN으로 최소 1장 성공한 뒤, 같은 DR 용지/제목블록/옵션이 반복된다는 걸 눈으로 확인할 수 있을 때만 사용
OPEN이 새 GMTITLE을 못 잡거나 NO_INSERTS가 반복됨: MANUAL
판단이 애매하거나 현재 DWG가 다름: Enter로 중단
```

실행 뒤 바로 다시 상태를 확인합니다.

```text
SWTITLESTATUS
```

CAD에서 한 장을 처리하고 저장/닫기까지 했다면, CAD 밖 PowerShell에서 아래 래퍼를 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_after_manual_gmtitle_step.ps1 -Compact
```

이 래퍼가 direct probe를 갱신하고 다음 한 단계 요약을 보여주므로, 오래된 로그를 보고 같은 변환을 반복하지 않습니다. 긴 next-action card 전체는 로그 파일에 남습니다.

처음부터 작업복사본 열기와 한 장 처리 후 점검까지 묶고 싶으면 아래 세션 래퍼를 사용할 수 있습니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_manual_gmtitle_session.ps1
```

이 세션 래퍼는 visible CAD를 열기 전에 next-action 카드를 갱신하고, 카드가 변환 가능한 상태일 때만 진행합니다. 카드가 `SWTITLEPREPARE`나 구조 검토를 요구하면 먼저 그 안내를 따릅니다.

CAD를 열지 않고 이번에 고를 용지/제목블록만 먼저 확인하려면 아래처럼 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_manual_gmtitle_session.ps1 -PreflightOnly
```

긴 next-action 카드가 부담되면 아래처럼 짧은 요약만 출력합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_manual_gmtitle_session.ps1 -PreflightOnly -Compact
```

## 5. A2/A3/A4 native 교체

A2/A3/A4 target이 화면에 보여도 복제/shared-link 구조라면 더블클릭 시 GMTITLE 표 편집창이 아니라 고급 속성 편집기로 열릴 수 있습니다.

`SWTITLESTATUS`가 `NEXT_UPGRADE_A3_A4_NATIVE` 또는 A2/A3/A4 native 교체 후보를 안내하면 title-missing/frame-only 예외보다 먼저 처리합니다.

```text
SWTITLECONVERTNEXT
SWTITLESTATUS
```

성공 판단:

```text
A2/A3/A4 native 교체 후보 수가 줄어듦
겹친 target pair 경고가 없음
명령어 텍스트 후보가 없음
도면틀 raw bbox 위험이 없음
대표 A3 제목블록 더블클릭 시 GMTITLE 표 편집창 열림
```

후보 수가 줄지 않으면 같은 명령을 반복하지 말고 `SWTITLEVERIFY`와 해당 로그를 확인합니다.

`BATCH`는 `OPEN`으로 최소 1장 성공한 뒤에만 사용합니다. 첫 후보부터 `BATCH`를 쓰면 잘못된 용지/제목블록/옵션을 여러 장에 반복 적용할 수 있으므로, 후보 수 감소를 먼저 확인합니다.

## 6. title-missing/frame-only 예외

원본 시트에 표제란/제목블록이 없다고 검증된 경우만 title-missing/frame-only 예외로 처리합니다. A4라는 용지 크기만으로 이 경로를 선택하지 않습니다. 이 경우 `DR_titlea_3rd`가 생기면 성공이 아니라 잘못된 추가일 수 있습니다.

title-missing/frame-only 처리 전 조건:

```text
원본 표제란 시트가 먼저 정리됨
A2/A3/A4 native 교체 후보가 0이거나 먼저 처리됨
해당 크기의 DR_A*_Outline 정의가 준비됨
해당 DR_A*_Outline raw bbox 위험이 없음
또는 공식 native 도면틀의 작은 바깥 마커만 있어 `ready-native-outside-markers`로 판정됨
```

`WAITING_FOR_TITLE_MISSING_OUTLINE_DEFINITION` 또는 `NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION`이 나오면 변환을 반복하지 않고 먼저 준비합니다.

```text
SWTITLEPREPARE
SWTITLESTATUS
```

title-missing/frame-only 성공 조건:

```text
DR_A4_Outline 도면틀만 원본 A4 위치/크기에 맞게 들어감
불필요한 DR_titlea_3rd 제목블록이 생기지 않음
기존 A4 도면 내용이나 빈 도면틀이 삭제되지 않음
SWTITLEVERIFY에서 A4 target 수량이 2로 맞음
ready-native-outside-markers는 실패가 아니라 공식 native A4 마커 허용 상태로 처리됨
```

## 7. 보호 중단으로 봐야 하는 결과

아래 결과가 나오면 실패라기보다 기존 도면을 지키기 위한 중단입니다. 같은 변환을 반복하지 않습니다.

```text
ABORT_FRAME_DEFINITION_RAW_BBOX_RISK
ABORT_TITLE_MISSING_OUTLINE_INVALID_GEOMETRY
ABORT_EXISTING_FRAME_ONLY_GMTITLE_RAW_BBOX_EXTRA_OBJECTS
WAITING_FOR_TITLE_MISSING_OUTLINE_DEFINITION
NEXT_REVIEW_TARGET_FRAME_GEOMETRY
NEXT_REVIEW_TARGET_FRAME_SELECTION
```

이때는 `SWTITLESTATUS`와 `SWTITLEVERIFY` 로그의 DWG 경로를 먼저 확인하고, 현재 열린 work 복사본 로그가 맞는지 봅니다.

## 8. 최종 검증

변환이 끝났다고 생각되면 읽기 전용 검증을 실행합니다.

```text
SWTITLEVERIFY
```

완료 기준:

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
```

화면 확인:

```text
대표 A2/A3 DR_titlea_3rd 제목블록 더블클릭 -> GMTITLE 표 편집창 열림
원본 표제란 부재가 검증된 title-missing 시트 -> 해당 DR_A*_Outline 도면틀만 있음, 더블클릭할 제목블록 없음
도면 내부 번호/주석/BOM/치수/모델 형상이 유지됨
```

`SWTITLEVERIFY_FINAL_OK` 전에는 모양이 맞아 보여도 완료로 보지 않습니다.
