# GMTITLE 실제 CAD 변환 체크리스트

이 문서는 GstarCAD 화면에서 SolidWorks DWG 작업복사본을 GMTITLE 구조로 바꿀 때 따라가는 순서입니다.

사용자는 아래 4개 명령만 사용합니다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

다음 예전 명령은 직접 사용하지 않습니다. 실행된다면 오래된 LSP가 로드된 상태일 수 있으니 다시 APPLOAD 하세요.

```text
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
SWTITLEGMTITLEVERIFYALL
```

## 0. 작업복사본 확인

변환은 반드시 `work` 폴더 아래의 복사본에서만 합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

`Downloads` 폴더의 원본 DWG나 실제 납품 원본에서 바로 실행하지 마세요.

## 1. LSP 로드

GstarCAD에서 APPLOAD로 아래 파일을 로드합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

GMTITLE 도구만 직접 로드할 수도 있습니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

로드 후 버전을 확인합니다.

```text
SWTITLEVERSION
```

기대 버전:

```text
260705-a3-frame-guidance
```

다른 버전이 나오면 변환하지 말고 최신 LSP를 다시 APPLOAD 하세요.

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
표제란 없는 도면틀 시트 수
A2/A3/A4 예상 수량
GMTITLE target 도면틀/제목블록 수량
DR_A2/A3/A4_Outline 도면틀 정의 상태
DR_A2/A3/A4_Outline 도면틀 정의 raw bbox 위험
도면틀 안 내장 표제란 형상 후보
A4 실제 선택 bbox 경고
다음 권장 명령
```

새 작업복사본의 변환 전 정상 상태는 대략 다음입니다.

```text
NEXT_CREATE_FIRST_NATIVE_GMTITLE
원본 표제란 시트: 13
원본 도면틀: 15
표제란 없는 도면틀 시트: 2
A2: 1
A3: 12
A4: 2
target 도면틀: 0
target 제목블록: 0
```

2026-07-04 현재 이어서 작업 중인 `0000_A_DRP125 CP_ALL_260704_test.dwg`는 이미 변환 중간 상태입니다.

```text
NEXT_UPGRADE_A3_A4_NATIVE
원본 표제란 시트: 0
원본 도면틀: 2
표제란 없는 도면틀 시트: 2
target 도면틀/제목블록 쌍: 13
A3/A4 native 교체 후보: 10
A4 대상 도면틀 누락: 필요 2, 현재 0
```

이 중간 상태에서는 A3 도면틀 정의를 정리하는 것이 아니라, `SWTITLECONVERT`로 A3 복제/shared-link 후보를 fresh native GMTITLE로 한 장씩 교체하는 것이 우선입니다.

`SWTITLESTATUS`가 `SWTITLEPREPARE`를 안내하면 변환하지 말고 먼저 정규화합니다.

`SWTITLESTATUS`가 `NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX`를 안내하면 `SWTITLECONVERT`를 반복하지 않습니다. 이 경우 `DR_A4_Outline` 같은 도면틀 정의 자체의 선택 범위가 용지보다 과도하게 큰 상태이므로, 기존 A4를 삭제하기 전에 정의 복구/정규화 계획을 먼저 확인해야 합니다.

현재 기준에서는 `SWTITLEPREPARE`가 사용 중이 아닌 `DR_A*_Outline` 정의의 raw bbox 위험을 복구 후보로 처리합니다. 이미 도면에 삽입되어 사용 중인 정의는 native link와 위치를 보호하기 위해 자동 교체하지 않고 로그에 남깁니다.

표제란 없는 A4 시트가 남아 있고 현재 도면에 `DR_A4_Outline` 정의가 없거나 안전 검사를 통과하지 못하면 아래 상태가 나올 수 있습니다.

```text
WAITING_FOR_A4_FRAME_ONLY_OUTLINE_DEFINITION
NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION
```

이 경우 `SWTITLECONVERT`를 반복하지 말고 `SWTITLEPREPARE`를 먼저 실행합니다. `SWTITLEPREPARE`는 설치 원본의 `DR_A4_Outline`을 가져와도 210 x 297 A4 형상과 실제 선택 범위가 안전한지 검사합니다. 통과하지 못하면 가져온 정의를 사용하지 않고 기존 A4 원본 도면틀을 보존합니다.

## 3. 필요한 경우 정규화

`SWTITLESTATUS`가 정규화를 안내할 때만 실행합니다.

```text
SWTITLEPREPARE
```

현재 기준 정규화 대상:

```text
source-contaminated 도면틀 정의
표제란 없는 A4 변환에 필요한 DR_A4_Outline 정의 누락/사전검사
별도 DR_titlea_3rd와 실제로 겹치는 native-format 도면틀 내부 표제란 형상
실수로 도면에 들어간 명령어 TEXT/MTEXT
제목블록 없는 고아 GMTITLE 도면틀
같은 위치에 겹친 DR_A*_Outline + DR_titlea_3rd GMTITLE target 쌍
```

보호 대상:

```text
외곽선
눈금
좌표 표시
정상 DR_titlea_3rd 제목블록
도면 안 번호
주석
BOM
치수
모델 형상
```

후보 목록을 확인한 뒤 맞을 때만 `YES`를 입력합니다. 후보가 이상하면 진행하지 말고 로그를 확인합니다.

정규화 후 다시 상태를 봅니다.

```text
SWTITLESTATUS
```

## 4. 변환 실행

상태 진단이 변환을 안내할 때 실행합니다.

```text
SWTITLECONVERT
```

이 명령은 내부에서 필요한 단계만 진행합니다.

```text
첫 native GMTITLE 기준 객체 생성
기존 SolidWorks 표제란 텍스트 추출
시트 크기 자동 인식
같은 크기 native 기준 객체 준비
이미 같은 위치에 native GMTITLE 쌍이 있으면 새로 만들지 않고 채택
남은 시트 자동 복제/배치
기존 SolidWorks 도면틀/표제란/잔여물 제거
A3/A4 native 인식이 불확실한 쌍은 한 장씩 교체 안내
A4 frame-only에서 DR_A4_Outline 정의가 없거나 raw bbox/선택범위 위험이 있으면 변환 전 중단
```

GMTITLE 창이 열리면 로그가 요구한 값만 선택합니다.

예시:

```text
용지/도면틀: DR_A2_Outline 또는 로그가 요구한 DR_A*_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

금지:

```text
일반 A2/A3/A4 용지 선택
ISO 제목블록 선택
Object move ON 상태로 확인
스크린샷 좌표 클릭으로 용지 선택
긴 소수점 좌표를 사람이 직접 입력
```

한 번 실행한 뒤에는 바로 다시 변환하지 말고 상태를 다시 봅니다.

`SWTITLECONVERT`가 아래 결과로 멈추면 정상적인 보호 중단입니다.

```text
ABORT_FRAME_DEFINITION_RAW_BBOX_RISK
WAITING_FOR_A4_FRAME_ONLY_OUTLINE_DEFINITION
```

이 경우 GMTITLE 창을 다시 열거나 변환을 반복하지 않습니다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLESTATUS
```

## 5. 반복 규칙

항상 이 순서로 반복합니다.

```text
SWTITLESTATUS
SWTITLEPREPARE   상태가 요구할 때만
SWTITLESTATUS
SWTITLECONVERT   상태가 요구할 때만
SWTITLESTATUS
```

`SWTITLESTATUS`가 최종 검증을 안내하면 변환을 멈추고 검증합니다.

## 6. 최종 검증

```text
SWTITLEVERIFY
```

완료 조건:

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
frame-only 시트: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
실수 명령어 텍스트 후보: 0
도면틀 내부 표제란 형상 후보: 0
도면틀 스타일 정규화 후보: 0
중복 표제란 없음
같은 위치에 겹친 GMTITLE target 쌍: 0
고아 도면틀 없음
clone/native-upgrade/shared-link 경고 없음
A3/A4 native 교체 후보 0
```

마지막으로 실제 `DR_titlea_3rd` 제목블록이 있는 대표 용지만 더블클릭해서 GMTITLE 표 편집창이 열리는지 확인합니다.
표제란 없는 A4는 제목블록을 만들지 않으므로 `SWTITLEVERIFY`의 A4 도면틀 수량/형상 검증으로 확인합니다.

도면 안의 번호, 주석, BOM, 치수, 모델 형상이 남아 있는지도 확인합니다.

## 현재 목표모드 기준

현재 목표는 A3/A4 복제 GMTITLE이 native GMTITLE처럼 보이는지 단순 확인하는 단계가 아닙니다. 아래 로그에서 native-like 탈락 이유를 확인하면서 진행합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_native_frame_check_last.txt
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_verify_summary_last.txt
```

특히 아래 항목이 남아 있으면 완료가 아닙니다.

```text
WARN_CLONED_GMTITLE_FRAME_NEEDS_NATIVE_UPGRADE
WARN_SHARED_NATIVE_GMTITLE_LINKS
WARN_A3_A4_TARGET_FRAME_NOT_NATIVE_LIKE
A3/A4 native 교체 후보 > 0
shared-native-link-handle 남음
```
