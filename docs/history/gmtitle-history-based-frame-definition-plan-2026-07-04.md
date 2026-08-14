# GMTITLE 이력 기반 도면틀 정의 분석 계획 - 2026-07-04

## 목적

SolidWorks DWG 도면틀/표제란을 GstarCAD Mechanical GMTITLE 구조로 바꾸는 작업에서 같은 실수를 반복하지 않기 위한 계획이다.

이번 문제는 A3 한 장만 고치는 문제가 아니다. `DR_A3_Outline` 도면틀 정의 안에 표제란처럼 보이는 형상이 같이 들어오는 이유가 다음 둘 중 무엇인지 먼저 나누어야 한다.

```text
1. GstarCAD 설치 원본 DR_A3_Outline 자체가 그런 구조인 정상 native 정의
2. 이전 변환/import 과정에서 SolidWorks 도면틀이나 제목블록이 DR_A3_Outline 정의 안으로 섞인 오염
```

이 구분 없이 `LINE`, `TEXT`, `INSERT`를 자동 삭제하면 도면 안의 번호, 주석, BOM, 형상까지 지워질 수 있다.

## 이력에서 확정된 금지 경로

다음 방식은 다시 기본 해결책으로 사용하지 않는다.

```text
명령줄 -GMTITLE 자동 선택
스크린샷 좌표/마우스 위치 기반 picker 자동화
A3/A4 전용 공개 명령 추가
DR_A*_Outline 블록 정의 내부 객체 무조건 삭제
native-links=1만 보고 GMTITLE 편집 동작 완료로 판단
도면 모양만 보고 SWTITLEVERIFY 없이 완료 판단
```

근거:

- GitHub `main`과 `origin/main`은 `0121ae1 Clean up GMTITLE command surface` 상태다.
- 로컬 최신 기준은 미커밋 `260704-history-gated-manual-gmtitle-main-44`이다.
- `main44`는 실제 CAD 이력에서 실패가 확인된 명령줄 `-GMTITLE` 자동 선택을 기본 비활성화했다.
- 6월 30일 이력에는 native GMTITLE의 진짜 link가 보이는 frame insert가 아니라 내부 recognition handle을 가리킨다는 기록이 있다.
- preserve-copy는 빠른 복제에는 유용했지만, 최종 완료 기준은 대표 A2/A3/A4 `DR_titlea_3rd` 더블클릭 시 GMTITLE 표 편집창이 열리는 것이다.

## 새로 확인한 사실

설치 폴더 파일 크기:

```text
DR_A1_Outline.dwg  98081
DR_A2_Outline.dwg  95462
DR_A3_Outline.dwg 149837
DR_A4_Outline.dwg  95942
```

`DR_A3_Outline.dwg`만 유난히 크다. 이것은 A3 도면틀 파일 자체가 다른 용지보다 많은 형상을 포함할 가능성이 있다는 신호다.

main45 설치 원본 복사본 스캔 결과 이 가능성이 확인됐다.

```text
DR_A2_Outline: outline-only
DR_A3_Outline: native-format-with-title-geometry, embedded=10
DR_A4_Outline: outline-only
Blocking records: 0
Cleanup records: 0
```

즉 설치 원본 `DR_A3_Outline` 안의 title-like 형상은 오염으로 단정하지 않는다.

또한 합성 fixture에서 `DR_A3_Outline` 정의 내부의 표제란 후보 5개는 감지됐지만, 블록 정의 내부 `AcDbLine`/`AcDbText`는 `entdel`과 `vla-Delete`로 삭제되지 않았다.

```text
Before cleanup: DR_A3_Outline embedded-title, embedded=5
Deleted embedded title records: 0
After cleanup: DR_A3_Outline embedded-title, embedded=5
```

따라서 이 문제는 단순 삭제 함수 추가로 해결할 일이 아니다. 도면틀 정의를 먼저 분류하고, 정상 native 정의와 오염된 정의를 다르게 처리해야 한다.

## 핵심 판단

`DR_A*_Outline` 도면틀이 블록으로 선택되는 것 자체는 실패가 아니다.

GstarCAD GMTITLE에서 최종 편집 확인 대상은 도면틀이 아니라 `DR_titlea_3rd` 제목블록이다. 도면틀은 계속 block reference일 수 있다.

진짜 실패는 다음 상태다.

```text
A3에서 도면틀 정의 안의 표제란 형상과 별도 DR_titlea_3rd가 겹쳐 표제란이 두 개처럼 보임
대표 제목블록 더블클릭 시 GMTITLE 표 편집창이 아니라 고급 속성 편집기로 열림
A4 frame-only 시트가 누락되거나 원본 도면 내용이 삭제됨
빨간 네모로 표시한 번호/주석/도면 내부 텍스트가 잔여물로 오판되어 삭제됨
```

## 분석 순서

### 1. 설치 원본 DR 도면틀 구조를 읽기 전용으로 스캔

대상:

```text
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A2_Outline.dwg
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A3_Outline.dwg
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A4_Outline.dwg
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Title\DR_titlea_3rd.dwg
```

확인할 것:

- lower-right title 영역에 원래 형상이 들어있는지
- child block 이름이 있는지
- 외곽선/눈금/좌표/상단 revision table과 표제란 형상을 구분할 수 있는지
- A3만 구조가 다른지
- A4 원본이 frame-only인지, title block이 같이 들어오는지

이 단계는 설치 폴더 파일을 수정하지 않는다.

### 2. 깨끗한 빈 도면에서 native GMTITLE A2/A3/A4를 각각 한 번 생성

`GMTITLE` 창에서 사람이 직접 확인한다.

```text
Paper/frame: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline
Title block: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

확인할 것:

- GstarCAD native GMTITLE이 A3에서 원래 도면틀+표제란을 같이 생성하는지
- 별도 `DR_titlea_3rd` 제목블록이 함께 들어오는지
- double-click 시 GMTITLE 표 편집창이 열리는 대상이 정확히 무엇인지
- `GENIUS_GENOREF_13` link가 internal인지 visible frame인지

이 결과가 “정답 도면 형태”다.

### 3. 기존 변환 결과와 native 정답을 비교

비교 대상:

```text
원본 SolidWorks work copy
현재 SWTITLECONVERT 변환 결과
깨끗한 native GMTITLE A2/A3/A4 샘플
```

비교할 항목:

- 도면틀 수량
- 제목블록 수량
- 표제란 중복 여부
- 원본 주석/번호/BOM/형상 보존 여부
- source frame/title 후보가 0으로 줄었는지
- 더블클릭 편집창 종류

### 4. `SWTITLESTATUS` 분류를 고친다

현재 `embedded-title` 또는 `contaminated` 판정이 너무 넓을 수 있다.

새 분류는 최소한 아래처럼 나눈다.

```text
outline-only
native-format-with-title-geometry
source-contaminated
unknown
```

의미:

- `outline-only`: 도면틀만 있음.
- `native-format-with-title-geometry`: 설치 원본 DR 도면틀 정의 자체가 표제란처럼 보이는 형상을 포함함. 무조건 삭제 금지.
- `source-contaminated`: SolidWorks source block, 이전 변환 child block, 잘못 import된 title/frame이 섞임. 정리 또는 재작성 후보.
- `unknown`: 자동 판단 불가. 변환 중단 후 로그 확인.

### 5. 삭제가 아니라 정책으로 처리한다

`native-format-with-title-geometry`이면 내부 객체를 삭제하지 않는다.

대신 다음 중 어느 방식이 맞는지 native 샘플 기준으로 결정한다.

```text
1. GstarCAD native GMTITLE도 원래 A3에 같은 형상을 포함한다면 그대로 둔다.
2. 중복 표제란이 생기는 경우, 별도 DR_titlea_3rd 생성/표시 방식 또는 선택한 frame/title 조합을 조정한다.
3. source-contaminated로 확인된 경우에만 work copy에서 정의 복구 또는 재구성한다.
```

### 6. 사용자 명령어는 계속 4개만 유지

공개 사용 흐름:

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

새로 A3 전용, A4 전용, 복구 전용 명령어를 늘리지 않는다.

내부 구현은 늘어날 수 있지만 사용자는 위 4개만 입력한다.

## 완료 기준

완료로 인정하는 조건:

```text
SWTITLEVERIFY_FINAL_OK
원본 기준 A2/A3/A4 수량과 변환된 GMTITLE 대상 수량 일치
남은 SolidWorks 원본 표제란 후보 0
남은 SolidWorks 원본 도면틀 후보 0
A3 표제란 중복 없음
A4 frame-only 시트 누락 없음
도면 내부 번호/주석/BOM/텍스트 삭제 없음
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
```

## 다음 구현 작업

1. 설치 원본 `DR_A2/A3/A4_Outline.dwg`와 native GMTITLE 샘플을 읽기 전용으로 스캔하는 진단을 만든다.
2. `SWTITLESTATUS`에 `native-format-with-title-geometry`와 `source-contaminated`를 분리해서 출력한다.
3. `SWTITLEPREPARE`가 native 설치 정의로 보이는 항목을 자동 삭제하지 않도록 막는다.
4. `SWTITLECONVERT`는 도면틀 정의 분류가 `unknown` 또는 위험 상태이면 변환하지 않고 이유를 출력한다.
5. clean work copy에서만 전체 변환을 다시 검증한다.
