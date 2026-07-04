# GMTITLE A3 도면틀 스타일 정규화 계획 - 2026-07-04

## 목적

이번 계획은 A3 한 장을 임시로 지우거나 A4용 명령을 또 만드는 계획이 아니다.

현재 문제는 `DR_A3_Outline` 도면틀 정의 자체가 표제란처럼 보이는 형상을 포함할 수 있고, 그 위에 별도 `DR_titlea_3rd` 제목블록을 넣으면 표제란이 두 개처럼 보인다는 점이다. `main45`에서 native/source 오염을 구분한 것은 맞지만, 이제는 한 단계 더 가서 "사용자가 원하는 DR A3 결과 모양"과 "설치 원본 A3 도면틀 구조"가 같은지 확인해야 한다.

사용자용 공개 명령은 계속 네 개로 유지한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

새로운 A3 전용, A4 전용, 복구 전용 공개 명령을 만들지 않는다.

## GitHub / 로컬 이력에서 확정한 전제

작업 전 확인한 기준:

```text
현재 브랜치: codex/gm-title
origin/main: 0121ae1 Clean up GMTITLE command surface
로컬 HEAD: 0121ae1 Clean up GMTITLE command surface
현재 로컬 LSP 기준: 260704-frame-definition-classification-main-45
```

반드시 유지할 이력 기반 원칙:

- `0121ae1 Clean up GMTITLE command surface`
  - 공개 명령이 너무 많아져서 정리했다.
  - 이번에도 새 공개 명령을 늘리지 않는다.

- `0bb4c9b Document GMTITLE first-native picker limits`
  - GMTITLE 창 선택을 화면 좌표나 드롭다운 위치 자동화로 해결하지 않는다.

- `b69ff54 Require strict native GMTITLE exemplars`
  - 비슷하게 생긴 clone을 native GMTITLE 성공으로 바로 믿지 않는다.
  - 더블클릭 시 GMTITLE 표 편집창이 열려야 한다.

- `5ed90c1 Guard GMTITLE frame definition imports`
  - 도면틀 블록 정의가 예상과 다르게 오염될 수 있다.
  - 변환 전후로 `DR_A*_Outline` 정의를 검사해야 한다.

- `843e453 Verify preserve-copy GMTITLE A4 frame-only`
  - preserve-copy/clone은 속도 개선 수단이다.
  - 최종 성공 기준은 `SWTITLEVERIFY`와 실제 CAD 더블클릭 확인이다.

- `docs/investigations/gmtitle-main45-verification-index-2026-07-04.md`
  - 설치 원본 `DR_A3_Outline.dwg` 자체가 title-like 형상을 포함할 수 있음이 확인됐다.
  - source-like child block이 없으면 source-contaminated로 보지 않는다.

## 설치 폴더 확인 결과

GstarCAD 설치 폴더에는 DR A3 대체 후보가 여러 개 있지 않다.

```text
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A1_Outline.dwg
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A2_Outline.dwg
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A3_Outline.dwg
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A4_Outline.dwg
```

제목블록 후보:

```text
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Title\DR_titlea.dwg
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Title\DR_titlea_3rd.dwg
```

따라서 "다른 깨끗한 DR_A3 도면틀을 고르면 해결"이라고 가정하지 않는다. 실제 해결은 현재 DWG 안에 들어온 `DR_A3_Outline` 정의를 분석하고, 필요하면 작업복사본 안에서만 스타일 정규화하는 방향으로 잡는다. 설치 원본 DWG는 수정하지 않는다.

## 문제 재정의

예전 main45 판단:

```text
DR_A3_Outline 안에 title-like 형상이 있음
source-like child block은 없음
=> native-format-with-title-geometry
=> 자동 삭제 금지
```

이 판단은 안전 측면에서는 맞다. 모양만 보고 지우면 설치 원본/native 구조까지 지울 수 있기 때문이다.

하지만 사용자 요구 기준에서는 추가 판단이 필요하다.

```text
사용자가 원하는 A3:
  도면틀은 도면틀 역할
  제목블록은 별도 DR_titlea_3rd 역할
  표제란이 두 개처럼 보이면 안 됨

현재 관찰된 A3:
  DR_A3_Outline 도면틀 정의 안에도 표제란 형상이 있음
  별도 DR_titlea_3rd도 들어감
  결과적으로 표제란이 중복처럼 보일 수 있음
```

따라서 이 문제는 `source-contaminated` 정리 문제가 아니라 `frame style normalization` 문제다.

## 핵심 설계

### 1. native/source 구분과 스타일 정규화를 분리한다

앞으로 `DR_A*_Outline` 정의는 두 축으로 판단한다.

```text
축 1: 출처/위험
  outline-only
  native-format-with-title-geometry
  source-contaminated
  unknown

축 2: 사용자 목표 모양과의 일치
  style-ok
  style-normalization-needed
  style-review-needed
```

예:

```text
DR_A3_Outline:
  source class = native-format-with-title-geometry
  style class  = style-normalization-needed
  이유 = source 오염은 아니지만, 별도 DR_titlea_3rd와 겹쳐 표제란이 두 개처럼 보임
```

이렇게 해야 "native라서 삭제 금지"라는 안전 원칙을 유지하면서도, 사용자가 원하는 최종 A3 모양을 맞출 수 있다.

### 2. A3 정규화는 삭제가 아니라 작업복사본 내 도면틀 스타일 보정이다

정규화 대상:

```text
현재 작업복사본 DWG 안의 DR_A3_Outline 블록 정의
```

정규화 금지 대상:

```text
GstarCAD 설치 폴더 원본 DR_A3_Outline.dwg
원본 Downloads DWG
도면 내부 번호, 주석, 치수, BOM, 모델 형상
```

예상 처리:

```text
DR_A3_Outline 블록 정의 안의 오른쪽 아래 static title-like 선/문자/로고만 제거 또는 비활성화
별도 DR_titlea_3rd 제목블록은 유지
DR_A3_Outline INSERT handle/native link는 유지
```

중요:

```text
도면틀 INSERT가 블록으로 선택되는 것은 정상일 수 있다.
최종 더블클릭 확인 대상은 DR_A3_Outline이 아니라 DR_titlea_3rd다.
```

### 3. SWTITLESTATUS가 스타일 문제를 먼저 보여줘야 한다

`SWTITLESTATUS`는 A3를 단순히 `native-format-with-title-geometry`로만 출력하면 부족하다.

추가로 아래처럼 보여줘야 한다.

```text
DR_A3_Outline:
  정의 유형: native-format-with-title-geometry
  스타일 판정: style-normalization-needed
  이유: 도면틀 정의 안의 static title-like 형상이 별도 DR_titlea_3rd 영역과 겹침
  다음: SWTITLEPREPARE
```

이 출력이 없으면 사용자는 `SWTITLECONVERT`를 계속 누르게 되고, 중복 표제란이 반복된다.

### 4. SWTITLEPREPARE가 정규화 gate를 담당한다

`SWTITLEPREPARE`는 아래 후보를 분리해서 보여준다.

```text
DELETE:
  source-contaminated로 확인된 SolidWorks/이전 변환 잔여물

NORMALIZE:
  작업복사본 안의 DR_A3_Outline native-format static title-like 형상 중
  별도 DR_titlea_3rd와 시각적으로 겹치는 부분

KEEP:
  도면 내부 번호, 주석, 치수, BOM, 모델 형상
  외곽선, 눈금, 좌표 문자

REVIEW:
  자동 판단이 불확실한 후보
```

`NORMALIZE`는 `DELETE`와 다르다. source 오염이라서 지우는 것이 아니라, 사용자 목표인 "도면틀 + 별도 제목블록" 구조에 맞추기 위해 작업복사본 안의 frame definition만 다듬는 것이다.

`REVIEW`가 있으면 자동 삭제하지 않는다.

### 5. SWTITLECONVERT는 정규화 전 대량 변환을 막는다

`SWTITLECONVERT` 시작 조건:

```text
작업복사본 안의 DWG일 것
source-contaminated 차단 항목이 없을 것
style-normalization-needed가 없거나, SWTITLEPREPARE로 처리됐을 것
GMTITLE 창 선택은 사용자가 눈으로 확인할 것
```

A3 첫 native 기준 객체를 만든 직후 `style-normalization-needed`가 뜨면, 남은 A3를 빠르게 복제하기 전에 `SWTITLEPREPARE`를 먼저 안내한다.

이렇게 해야 중복 표제란이 12장으로 복제되는 일을 막을 수 있다.

### 6. SWTITLEVERIFY는 최종 모양 정책도 실패 조건으로 삼는다

`SWTITLEVERIFY`가 확인해야 할 항목:

```text
SWTITLEVERIFY_FINAL_OK
남은 SolidWorks 원본 표제란 후보: 0
남은 SolidWorks 원본 도면틀 후보: 0
A2/A3/A4 기준 수량과 target GMTITLE 수량 일치
DR_A3_Outline style-normalization-needed: 0
중복 표제란: 0
A4 frame-only 누락: 0
도면 내부 번호/주석/BOM/텍스트 삭제 없음
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
```

`native-format-with-title-geometry` 자체는 실패가 아니다. 하지만 별도 `DR_titlea_3rd`와 겹쳐 사용자가 보는 표제란이 두 개가 되면 실패다.

## 구현 순서

### 1단계: 증거 고정

실행 전:

```text
git fetch --all --prune
git status --short --branch
git log --oneline --decorate -n 25
```

CAD 또는 hidden probe 기준:

```text
SWTITLEVERSION
SWTITLESTATUS
SWTITLEVERIFY
```

확인:

```text
로드된 LSP = 260704-frame-definition-classification-main-45 이상
작업 대상 DWG = Documents/CAD tool/work 아래 복사본
예전 명령어는 실행되지 않음
```

### 2단계: A3 스타일 판정 진단 추가

코드 목표:

```text
DR_A3_Outline 내부 static title-like 형상 bbox
별도 DR_titlea_3rd bbox
두 영역의 겹침 여부
source-like child block 여부
style-normalization-needed 여부
```

출력 목표:

```text
SWTITLESTATUS에 A3 style 판정 추가
SWTITLEVERIFY 최종 요약에 style-normalization-needed 수량 추가
```

### 3단계: 정규화 후보 보호 규칙 추가

정규화 후보가 되어야 하는 것:

```text
DR_A3_Outline 블록 정의 내부
오른쪽 아래 title 영역
별도 DR_titlea_3rd와 겹치는 static line/text/logo
```

보호해야 하는 것:

```text
도면 내부 번호/주석/치수/BOM
모델 형상
도면틀 외곽선
눈금/좌표 문자
별도 DR_titlea_3rd 속성 제목블록
```

### 4단계: SWTITLEPREPARE에 style normalization 연결

`SWTITLEPREPARE`가 다음처럼 안내해야 한다.

```text
DR_A3_Outline 도면틀 스타일 정규화 후보: N개
이 후보는 source 오염 삭제가 아니라, 별도 DR_titlea_3rd와 겹치는 static 표제란 형상 정리입니다.
작업복사본 안의 블록 정의만 바꾸며 설치 원본은 수정하지 않습니다.
계속하려면 YES
```

정규화 뒤에는 `SWTITLESTATUS`를 다시 실행한다.

### 5단계: 변환 순서 고정

실제 사용 순서:

```text
SWTITLESTATUS
SWTITLEPREPARE   # 안내될 때만
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLEPREPARE   # A3 style-normalization-needed가 생기면 여기서 처리
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLEVERIFY
```

사용자가 외울 것은 여전히 네 명령뿐이다. 내부에서 A3/A4 분기는 처리한다.

### 6단계: 테스트

읽기 전용 / 복사본 테스트:

```text
diagnostics/gmtitle-main45/run_main45_verification_suite.ps1
diagnostics/gmtitle-main45/run_frameclass_common_probe.ps1
diagnostics/gmtitle-main45/run_final_completion_gate.ps1
```

추가해야 할 fixture:

```text
A3 native-format-with-title-geometry + 별도 DR_titlea_3rd 겹침
=> SWTITLESTATUS: style-normalization-needed
=> SWTITLEPREPARE 후: style-ok
=> SWTITLEVERIFY: 중복 표제란 없음
```

실제 CAD 확인:

```text
대표 A2 DR_titlea_3rd 더블클릭 -> GMTITLE 표 편집창
대표 A3 DR_titlea_3rd 더블클릭 -> GMTITLE 표 편집창
대표 A4 대상 확인 -> frame-only 누락 없음
A3 표제란이 두 개처럼 보이지 않음
빨간 네모로 표시했던 도면 내부 번호/주석이 남아 있음
```

## 금지할 반복 실수

- A3 내부 title-like 형상을 source 오염으로 단정하고 바로 삭제
- native-format이라는 이유만으로 중복 표제란 모양을 최종 OK로 판단
- A3 전용 공개 명령 추가
- A4 frame-only 문제와 A3 style 문제를 같은 원인으로 처리
- GMTITLE 창을 화면 좌표로 자동 클릭
- 일반 A3/A4 또는 ISO 제목블록 기본값을 그대로 OK
- `SWTITLESTATUS` 없이 `SWTITLECONVERT` 연속 실행
- 원본 DWG 또는 Downloads 파일에서 직접 변환
- 빨간 네모로 표시된 도면 내부 객체를 bbox만 보고 삭제

## 완료 기준

이 계획은 아래 조건이 모두 만족될 때 완료다.

```text
SWTITLESTATUS가 A3 source class와 style class를 모두 보여줌
SWTITLEPREPARE가 A3 style normalization 후보와 source-contaminated 후보를 분리함
SWTITLECONVERT가 style-normalization-needed 상태에서 대량 복제를 진행하지 않음
SWTITLEVERIFY가 A3 중복 표제란 모양을 실패/경고로 잡음
최종 DWG에서 A3 표제란이 두 개처럼 보이지 않음
최종 DWG에서 A2/A3/A4 target 수량이 원본 기준과 일치
도면 내부 번호/주석/BOM/텍스트가 보존됨
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창이 열림
```
