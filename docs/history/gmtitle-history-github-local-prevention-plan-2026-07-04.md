# GMTITLE 이력 기반 반복 실수 방지 계획 - 2026-07-04

## 목적

SolidWorks에서 저장한 DWG의 도면틀과 표제란을 GstarCAD Mechanical의 GMTITLE 구조로 바꾸는 작업에서 같은 시행착오를 반복하지 않기 위한 기준 문서입니다.

이 문서는 새 명령어를 계속 늘리기 위한 문서가 아닙니다. 사용자는 아래 4개 명령 안에서만 작업합니다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

새 문제가 나오면 먼저 Git/GitHub 이력, 로컬 진단 로그, 실제 CAD 관찰 결과를 대조한 뒤 위 4단계 안에 흡수합니다.

## 기준 이력

현재 로컬 브랜치와 GitHub 기준 커밋은 다음 위치에서 시작합니다.

```text
0121ae1 Clean up GMTITLE command surface
```

그 이후 main49 개선은 아직 로컬 미커밋 변경입니다. 따라서 GitHub 화면이 3일 전 상태처럼 보이더라도, 로컬에는 더 최신 실험과 진단 결과가 남아 있을 수 있습니다.

중요 커밋에서 얻은 결론은 다음과 같습니다.

| 이력 | 배운 점 | 앞으로의 기준 |
| --- | --- | --- |
| `f549ac2` fallback 블록 방식 | 가짜 DR 도면틀/표제란 블록은 GMTITLE 편집창과 충돌한다. | fallback 블록 생성 방식으로 돌아가지 않는다. |
| native GMTITLE 실험 | 더블클릭 표 편집창은 실제 GMTITLE로 만들어진 객체에서 가장 안정적이다. | 첫 기준 객체는 반드시 GstarCAD의 GMTITLE로 만든다. |
| `b69ff54` strict native exemplar | A2 기준 객체 하나로 A3/A4를 모두 처리하면 구조가 달라질 수 있다. | A2/A3/A4는 같은 크기의 native 기준 객체를 각각 사용한다. |
| `843e453` A4 frame-only 검증 | 표제란 없는 A4 시트는 표제란 있는 시트와 다르게 처리해야 한다. | frame-only 시트는 제목값 추출/삽입 흐름과 분리한다. |
| `0121ae1` command surface 정리 | 공개 명령이 많으면 사용 순서가 무너지고 실수가 늘어난다. | 공개 명령은 4개로 유지한다. |
| command-text guard 이력 | CAD 명령어가 TEXT/MTEXT로 도면에 남을 수 있다. | 실수 명령어 텍스트가 있으면 변환을 즉시 중단하고 먼저 정리한다. |

## 지금 확인된 사실

현재 LSP 기준 버전은 다음입니다.

```text
260704-plan-frame-prepare-main-49
```

현재 기준 작업복사본은 아직 실제 변환 완료 상태가 아닙니다.

```text
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
원본 표제란 시트: 13
원본 도면틀: 15
표제란 없는 도면틀 시트: 2
예상 용지 수량:
  A2: 1
  A3: 12
  A4: 2
대상 GMTITLE 제목블록: 0
대상 GMTITLE 도면틀: 0
```

이 `FAIL`은 코드 실패가 아니라 실제 작업복사본에 아직 GMTITLE 대상 객체가 없다는 변환 전 정상 진단입니다.

## 반복하면 안 되는 실수

1. `Downloads` 원본 DWG에서 바로 편집하지 않는다.
2. 스크린샷 좌표 클릭으로 GMTITLE 용지/제목블록을 고르지 않는다.
3. A2 native 기준 객체를 A3/A4에 그대로 복제하는 방향으로 돌아가지 않는다.
4. A3가 블록처럼 보인다는 이유만으로 바로 실패 처리하지 않는다. 먼저 도면틀 정의 안에 표제란 형상이 섞였는지 확인한다.
5. `DR_A*_Outline` 객체를 무조건 삭제하지 않는다.
6. 도면 안 번호, 주석, BOM, 치수, 모델 형상을 잔여물로 오판하지 않는다.
7. `SWTITLEVERIFY_FINAL_OK` 없이 완료라고 판단하지 않는다.
8. 옛 명령어를 다시 쓰지 않는다. `SWTITLEFASTSTATUS`, `SWTITLETRANSFERBOOTSTRAPFAST`, `SWTITLEA3A4NEXT`, `SWTITLEFRAMEONLYAPPLY`가 필요해 보이면 흐름이 다시 흔들린 것이다.

## 핵심 문제별 판단

### A3 도면틀과 표제란이 하나처럼 보이는 문제

관찰된 현상:

```text
A2는 도면틀만 있는데 A3에서는 도면틀과 제목블록이 하나로 합쳐져서 블록처럼 보인다.
GMTITLE 기능은 가능하지만 도면 형태가 달라지고, 변환하면 표제란이 2개처럼 보일 수 있다.
```

이 문제는 단순 배치 좌표 문제가 아닙니다. 가장 가능성이 높은 원인은 `DR_A3_Outline` 도면틀 정의 안에 오른쪽 아래 표제란처럼 보이는 정적 형상이 들어 있고, 여기에 별도 `DR_titlea_3rd` 제목블록이 다시 겹치는 구조입니다.

main49의 방향은 다음입니다.

```text
SWTITLESTATUS
  -> 도면틀 내부 표제란 형상 후보를 먼저 표시

SWTITLEPREPARE
  -> 작업복사본 안에서만 도면틀 정의 내부의 표제란 형상을 정리

SWTITLESTATUS
  -> 후보가 사라졌는지 재확인

SWTITLECONVERT
  -> 정리된 구조에서 변환 진행
```

정리 원칙:

```text
DR_A3_Outline 전체를 삭제하지 않는다.
외곽선, 눈금, 좌표 표시는 보존한다.
오른쪽 아래 static title-like 형상만 후보로 분리한다.
별도 DR_titlea_3rd는 GMTITLE 표 편집 대상이므로 보존한다.
```

### A4 frame-only 문제

관찰된 현상:

```text
A4 원본에는 표제란이 없는데 변환 후 표제란이 생기거나, 첫 장만 바뀌고 나머지가 남는다.
```

A4는 title sheet가 아니라 frame-only sheet일 수 있습니다. 그러면 기존 표제란 텍스트를 추출해서 새 제목블록을 채우는 흐름을 적용하면 안 됩니다.

원칙:

```text
원본에 표제란이 없으면 새 표제란을 억지로 만들지 않는다.
frame-only 시트는 같은 크기의 DR_A4_Outline 기준 객체로 도면틀만 교체한다.
GstarCAD의 GMTITLE A4 선택 결과가 실제 A4 bbox와 맞지 않으면 기존 A4를 삭제하지 않는다.
```

### 빨간 네모 영역이 사라지는 문제

관찰된 현상:

```text
도면 안 번호, 주석, 작은 표기, BOM처럼 보여야 하는 요소가 일부 삭제된다.
```

이 문제는 잔여물 삭제 범위가 너무 넓을 때 생깁니다. 앞으로는 삭제 후보가 아래 조건을 모두 만족할 때만 삭제합니다.

```text
1. 원본 SolidWorks 도면틀 또는 표제란 잔여물 영역과 맞음
2. 도면의 실제 번호, 주석, BOM, 치수, 모델 형상으로 보이지 않음
3. SWTITLESTATUS 또는 SWTITLEPREPARE 로그에 후보로 먼저 표시됨
4. 작업복사본에서만 실행됨
```

추가로 실제 사용자가 빨간 네모로 표시한 사례는 fixture로 남겨야 합니다. 그래야 이후 코드 변경이 같은 요소를 다시 삭제하지 않는지 자동 진단할 수 있습니다.

## 진행 계획

### 1단계. 문서와 명령 흐름 고정

- 공개 명령은 4개만 유지합니다.
- 현재 사용법은 `docs/guide/gmtitle-cad-conversion-checklist.md`에만 집중합니다.
- 옛 명령은 문서에서 “직접 사용 금지”로만 남깁니다.

### 2단계. 이력 기반 진단을 먼저 실행

변환 전에 항상 아래 순서로 판단합니다.

```text
SWTITLEVERSION
SWTITLESTATUS
```

상태 로그에서 다음을 확인합니다.

```text
현재 DWG가 work 복사본인지
A2/A3/A4 예상 수량
도면틀 정의 내부 표제란 형상 후보
A4 frame-only 수량
실수 명령어 텍스트 후보
다음 권장 명령
```

### 3단계. A3 도면틀 정의 정규화

`SWTITLESTATUS`가 A3 도면틀 내부 표제란 형상을 표시하면 `SWTITLECONVERT`를 반복하지 않습니다.

```text
SWTITLEPREPARE
SWTITLESTATUS
```

후보가 사라진 뒤에만 변환합니다.

### 4단계. 변환은 SWTITLECONVERT 하나로 통합

사용자는 다음 명령 하나만 실행합니다.

```text
SWTITLECONVERT
```

내부에서는 상태에 따라 다음 중 필요한 단계만 실행합니다.

```text
첫 native GMTITLE 기준 객체 생성
같은 크기 native 기준 객체 준비
남은 같은 크기 시트 자동 복제
A3/A4 native 인식 불확실 쌍은 한 장씩 교체 안내
A4 frame-only 시트는 frame-only 흐름으로 처리
기존 SolidWorks 도면틀/표제란/안전한 잔여물 제거
```

### 5단계. 검증 기준 고정

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
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```

## 다음 실제 CAD 실행 순서

작업복사본에서만 아래 순서로 진행합니다.

```text
APPLOAD
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE    필요하다고 나올 때만
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT    아직 다음 변환이 필요하다고 나올 때만
SWTITLEVERIFY
```

GMTITLE 창이 뜨면 로그에 표시된 것만 고릅니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

일반 A2/A3/A4, ISO 제목블록, 스크린샷 좌표 클릭, 사람이 긴 소수점 좌표를 직접 입력하는 방식은 사용하지 않습니다.
