# GMTITLE A4 Frame-Only 정책 재정렬 계획 - 2026-07-04

## 목적

이번 계획의 목적은 SolidWorks DWG를 GstarCAD Mechanical 구조로 바꾸는 과정에서, 원본에 표제란이 없는 A4 시트를 일반 title sheet처럼 처리하지 않도록 기준을 고정하는 것이다.

사용자에게 노출되는 명령은 계속 아래 4개로 유지한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

## Git/GitHub 기준

현재 로컬 브랜치와 GitHub 추적 브랜치 기준은 다음과 같다.

```text
branch: codex/gm-title
HEAD: 16f85fa Clarify GMTITLE minimum baseline
origin/codex/gm-title: 16f85fa Clarify GMTITLE minimum baseline
```

관련 이력에서 반복 확인한 원칙:

```text
843e453 Verify preserve-copy GMTITLE A4 frame-only
e738d2e Add GMTITLE main56 adoption guard
517bb53 Update GMTITLE history references
16f85fa Clarify GMTITLE minimum baseline
```

현재 LSP 기준:

```text
260704-target-overlap-adopt-main56-a4frameguard
```

## 실제 CAD 진행 상태

2026-07-04 작업복사본 기준으로 확인한 상태:

```text
DWG:
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg

A3 native 교체 후보:
6 -> 5 -> 4 -> 3 -> 2 -> 0

SWTITLESTATUS 이후:
원본 표제란 시트: 0
원본 도면틀: 2
표제란 없는 도면틀 시트: 2

대상 도면틀 수:
  A2: 1
  A3: 12
  A4: 0

겹친 GMTITLE target 쌍 후보 수: 0
현재 필요한 대상 용지 누락: A4
```

즉, 지금은 A3를 다시 건드릴 단계가 아니다. 남은 문제는 표제란 없는 A4 시트 2장이다.

## 반복하면 안 되는 실수

아래 방식으로 돌아가지 않는다.

```text
일반 A4 또는 ISO 제목블록 선택
스크린샷 좌표 클릭
긴 소수점 좌표를 사람이 직접 입력
A4를 A3 title sheet와 같은 방식으로 처리
원본 A4에 없던 표제란을 새로 만들고 완료로 판단
SWTITLEVERIFY 최종 OK 없이 완료로 판단
새 A4 bbox 검증 전에 기존 A4 원본 도면틀 삭제
```

## 이력에서 확인한 A4 원칙

A4는 title sheet가 아니라 frame-only sheet일 수 있다.

```text
원본에 표제란이 없으면 기존 표제란 텍스트 추출/삽입 흐름을 적용하지 않는다.
원본에 표제란이 없으면 새 표제란을 필수로 만들지 않는다.
표제란 없는 시트는 같은 크기의 DR_A4_Outline 기준 객체로 도면틀만 교체한다.
GstarCAD GMTITLE A4 선택 결과가 실제 A4 bbox와 맞지 않으면 기존 A4를 삭제하지 않는다.
```

## 현재 코드 충돌 지점

기존 frame-only 경로는 다음 함수들을 사용한다.

```text
swcad-title-transfer-frame-only-apply
swcad-title-transfer-frame-only-finalize
swcad-title-frame-only-default-values
```

문제는 이 경로가 `DR_titlea_3rd` 제목블록을 기대하고 기본 값을 채우도록 설계되어 있다는 점이다.

이 방식은 원본 A4에 표제란이 없던 경우와 충돌한다. 원본에 없는 제목블록을 새로 만들면 도면 형태가 바뀌고, 사용자가 지적한 "A4 도면이 사라지거나 표제란이 새로 생기는 문제"가 반복된다.

## 새 정책

### 1. A4 Frame-Only는 Title Sheet와 분리한다

아래 조건이면 표제란 없는 A4 시트로 본다.

```text
source title insert 없음
source frame insert 있음
sheet size = A4
target frame = DR_A4_Outline
```

이 경우 title-sheet 흐름을 적용하지 않는다.

### 2. 변환 목표는 도면틀만 교체다

성공 조건:

```text
DR_A4_Outline 도면틀이 원본 A4 위치와 크기에 맞게 들어감
새 도면틀 bbox 검증 후 기존 A4 도면틀만 삭제
도면 내용은 삭제하지 않음
원본에 없던 별도 DR_titlea_3rd 제목블록을 만들지 않음
```

### 3. 제목블록이 강제로 생성되면 즉시 중단한다

GstarCAD GMTITLE A4 흐름이 별도 `DR_titlea_3rd` 제목블록을 만들면 성공이 아니라 경고/중단으로 본다.

현재 guard 결과:

```text
WAITING_FOR_A4_FRAME_ONLY_OUTLINE_POLICY
```

사용자 안내:

```text
표제란 없는 A4 원본에는 표제란이 없으므로 현재 GMTITLE 제목블록 생성 흐름을 반복하지 않습니다.
A4 도면틀만 교체하는 경로를 구현/검증한 뒤 진행해야 합니다.
```

### 4. 최종 검증 기준도 분리한다

```text
A2/A3:
  DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창이 열릴 것

A4 frame-only:
  DR_A4_Outline target frame 수량 2
  source frame-only 잔여 0
  원본에 없던 별도 title insert 생성 없음
  도면 내용 삭제 없음
```

## 구현 계획

### 1단계. 상태 진단에서 정책을 명확히 말한다

`SWTITLESTATUS`에서 표제란 없는 A4가 남으면 아래를 출력한다.

```text
결과: WAITING_FOR_A4_FRAME_ONLY_OUTLINE_POLICY
다음: 표제란 없는 A4 시트는 원본에 표제란이 없으므로 SWTITLECONVERT를 반복하지 마세요.
A4는 도면틀만 교체하는 경로를 구현/검증한 뒤 진행해야 합니다.
```

### 2단계. 위험 경로를 guard로 막는다

`swcad-title-transfer-frame-only-finalize`에서 아래 조건이면 기존 A4를 삭제하기 전에 중단한다.

```text
source-sheet = A4
source-frame-only = true
new title block = DR_titlea_3rd
source에는 title insert가 없음
```

결과:

```text
새로 만들어진 잘못된 GMTITLE title/frame은 삭제
기존 A4 source frame은 보존
중단 이유를 로그에 출력
```

### 3단계. 도면틀만 교체하는 A4 내부 경로를 만든다

공개 명령은 추가하지 않는다. 후보 내부 흐름은 다음과 같다.

```text
swcad-title-transfer-frame-only-outline-apply
```

동작:

```text
설치 원본 또는 이미 로드된 DR_A4_Outline block definition 사용
원본 A4 bbox의 왼쪽 아래 기준으로 DR_A4_Outline만 삽입
effective bbox가 210 x 297인지 검사
raw selection bbox가 과도하면 중단
검증 후 기존 source A4 frame만 삭제
별도 DR_titlea_3rd는 만들지 않음
```

### 4단계. `SWTITLEVERIFY`를 A4 frame-only 기준으로 수정한다

최종 OK 조건:

```text
A2/A3 title sheets:
  target frame/title pair 수량 일치
  DR_titlea_3rd 더블클릭 확인 필요

A4 frame-only sheets:
  target DR_A4_Outline frame 수량 일치
  source frame-only 잔여 0
  별도 title insert 필수 아님
```

### 5단계. 작업복사본에서만 CAD 검증한다

```text
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLEVERIFY
```

필수 확인:

```text
A4 2장 모두 DR_A4_Outline으로 교체됨
A4에는 원본에 없던 표제란이 생기지 않음
A4 원본 도면틀 잔여 0
A2/A3 대표 제목블록 더블클릭 시 GMTITLE 표 편집창 열림
도면 내용 삭제 없음
```

## 현재 결론

현재 live CAD에서는 A3 native 교체가 끝났고 A4만 남았다.

하지만 현재까지 검증된 안전한 결론은 "A4를 바로 계속 변환하지 않는다"이다.

`SWTITLECONVERT`는 이제 표제란 없는 A4만 남은 상태에서 GMTITLE 창을 열지 않고 `WAITING_FOR_A4_FRAME_ONLY_OUTLINE_POLICY`로 멈춘다. 따라서 같은 실수를 반복하지 않으려면 다음 작업은 A4 도면틀만 교체하는 내부 경로 구현과 검증이다.
