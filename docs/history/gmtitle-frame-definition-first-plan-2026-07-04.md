# GMTITLE 도면틀 정의 우선 안정화 계획 - 2026-07-04

## 목적

이번 문제는 A3 한 장만 지우거나 A4 명령을 하나 더 만드는 문제가 아니다.

SolidWorks DWG를 GstarCAD Mechanical `GMTITLE` 구조로 바꾸려면, 먼저 각 DR 도면틀 정의가 실제로 어떤 구조인지 확인해야 한다. 특히 현재 관찰된 핵심 문제는 `DR_A3_Outline`이 도면틀만 가진 것으로 보였지만, 실제로는 도면틀 정의 안에 표제란 형상이 같이 들어와서 별도 `DR_titlea_3rd`와 겹치는 현상이다.

따라서 앞으로의 방향은 다음과 같다.

```text
도면틀 정의 판정
-> 위험 후보 정규화
-> 변환
-> 수량/중복/더블클릭 검증
```

사용자가 기억해야 할 공개 명령은 계속 4개로 유지한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

새 공개 명령을 계속 추가하지 않는다.

작업 전 GitHub/로컬 이력 확인, 같은 실수 반복 방지 게이트, 커밋 기준은 아래 문서를 최상위 기준으로 삼는다.

```text
docs/history/gmtitle-history-gated-plan-2026-07-04.md
```

## GitHub / 로컬 이력에서 반영한 교훈

현재 로컬 기준:

```text
repo: https://github.com/adams219/CAD.git
branch: codex/gm-title
origin/main, main: 0121ae1 Clean up GMTITLE command surface
origin/codex/gm-title, local HEAD: e738d2e Add GMTITLE main56 adoption guard 이상
current GMTITLE LSP baseline: 260704-target-overlap-adopt-main56-a4guard
current loader baseline: 260704-4step-gmtitle-main56-a4guard
working tree: main56-a4guard 보강 변경은 GitHub에 푸시됨
```

반드시 반영할 이전 결론:

- `0121ae1 Clean up GMTITLE command surface`
  - 실험용 공개 명령이 너무 많아져서 정리했다.
  - 따라서 A3 전용, A4 전용, 복구 전용 공개 명령을 다시 늘리지 않는다.

- `2d76a9b Use overlap-only GMTITLE frame normalization`
  - `DR_A3_Outline` 안에 title-like 형상이 있다는 이유만으로 삭제하지 않는다.
  - 별도 `DR_titlea_3rd`와 실제로 겹치는 경우에만 정규화 후보로 본다.
  - 도면틀 정의 문제와 변환 중 생긴 중복 target 쌍 문제를 분리한다.

- `0bb4c9b Document GMTITLE first-native picker limits`
  - GMTITLE 창 선택은 화면 좌표 클릭이나 드롭다운 위치 의존 자동화로 안정화하기 어렵다.
  - 따라서 좌표 클릭 자동화는 기본 해결책으로 쓰지 않는다.

- `b69ff54 Require strict native GMTITLE exemplars`
  - 겉모양이 비슷한 clone을 native GMTITLE로 바로 믿으면 안 된다.
  - 더블클릭 시 GMTITLE 표 편집창이 열리는지까지 검증해야 한다.

- `5ed90c1 Guard GMTITLE frame definition imports`
  - 도면틀 블록 정의가 오염되거나 예상과 다르게 들어올 수 있다는 문제가 이미 확인됐다.
  - 변환 전에 도면틀 정의 자체를 진단하고 정규화해야 한다.

- `843e453 Verify preserve-copy GMTITLE A4 frame-only`
  - preserve-copy/clone 방식은 빠른 반복에는 유용하지만 최종 성공 기준은 아니다.
  - 최종 판단은 `SWTITLEVERIFY`와 대표 `DR_titlea_3rd` 더블클릭 확인이다.

- `docs/investigations/gmtitle-main45-verification-index-2026-07-04.md`
  - 설치 원본 `DR_A3_Outline.dwg` 자체가 lower-right title-like 형상 10개를 포함할 수 있음이 확인됐다.
  - source-like child block이 없으면 이것을 source 오염으로 보지 않는다.
  - 따라서 A3 내부 형상을 모양만 보고 자동 삭제하는 방향으로 돌아가지 않는다.

## 현재 문제를 다시 정의

최근 증상:

- A2는 도면틀만 있는 것처럼 동작한다.
- A3는 `DR_A3_Outline` 안에 title-like 형상이 같이 들어와, 별도 `DR_titlea_3rd`와 조합될 때 표제란이 2개처럼 보일 수 있다.
- 단, main45 검증 기준으로 이 형상은 설치 원본/native 구조일 수 있으므로 바로 삭제 대상이 아니다.
- 빨간 네모로 표시된 도면 안쪽 주석/번호/텍스트가 일부 사라지는 경우가 있었다.
- A4는 frame-only 시트가 섞여 있어서, 표제란 있는 시트와 같은 방식으로 판단하면 안 된다.

이 증상들을 한 줄로 요약하면:

```text
용지 크기별 도면틀 정의 구조와 실제 도면 내용 보호 범위를 분리해서 판단하지 못한 상태에서 변환/삭제가 섞였다.
```

따라서 다음 두 가지를 분리해야 한다.

1. 도면틀 정의 문제
   - `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 블록 정의 안에 title-like 형상이나 child block이 들어 있는지 확인한다.
   - title-like 형상이 설치 원본/native 구조인지, SolidWorks/이전 변환 source 오염인지 분리한다.
   - `source-contaminated`만 변환 전 정규화 대상으로 본다.
   - `native-format-with-title-geometry`는 자동 삭제하지 않고, 사용자가 원하는 DR A3 표준과 맞는지 별도 판단한다.

2. 도면 내용 보호 문제
   - 도면 내부의 번호, 주석, BOM, 형상, 치수, 일반 텍스트는 원본 도면 내용이다.
   - 기존 표제란/도면틀 잔여물 제거 후보와 도면 내용 후보를 구분한다.
   - 단순 bbox만으로 도면 내부 객체를 삭제하지 않는다.

## 핵심 설계

### 1. `SWTITLESTATUS`는 도면틀 정의 유형을 먼저 보여준다

`SWTITLESTATUS`는 읽기 전용으로 아래 정보를 보여줘야 한다.

```text
DR_A2_Outline: unknown / outline-only / native-format-with-title-geometry / source-contaminated
DR_A3_Outline: unknown / outline-only / native-format-with-title-geometry / source-contaminated
DR_A4_Outline: unknown / outline-only / native-format-with-title-geometry / source-contaminated
```

각 결과에는 이유가 같이 있어야 한다.

예:

```text
DR_A3_Outline: native-format-with-title-geometry
이유: 도면틀 정의 안 오른쪽 아래 표제란 영역에 title-like 형상 10개가 있지만 source-like child block은 없음
권장: 자동 삭제하지 말고, 원하는 A3 표준과 맞는지 확인

DR_A4_Outline: source-contaminated
이유: 도면틀 정의 안에 SolidWorks/이전 변환 source-like child block이 있음
권장: SWTITLEPREPARE
```

### 2. `SWTITLEPREPARE`는 변환 전 정규화만 담당한다

`SWTITLEPREPARE`는 아래 후보를 분리해서 보여준다.

- 실수로 입력된 명령어 텍스트
- 고아 `DR_A*_Outline` 도면틀
- 도면틀 정의 안의 중첩 제목블록
- 도면틀 정의 안의 native-format title-like 형상
- 도면틀 정의 유형이 `source-contaminated`로 변환 차단되는 항목
- 변환 삭제 후보 중 도면 내부 객체와 겹칠 위험이 있는 항목

삭제/정규화 후보마다 이유가 있어야 한다.

```text
삭제 가능: source-contaminated로 확인된 도면틀 정의 내부의 SolidWorks/이전 변환 잔여물
보호: 설치 원본/native-format일 수 있는 DR_A3_Outline 내부 형상
보호: 외곽선, 눈금, 좌표 문자, 도면 내부 번호/주석/치수/BOM
불확실: 사람이 확인 필요, 자동 삭제 안 함
```

`SWTITLEPREPARE`가 끝나기 전에는 `SWTITLECONVERT`가 진행되지 않는 것이 안전하다.
따라서 `SWTITLESTATUS`와 `SWTITLECONVERT`가 표시한 차단 원인은 `SWTITLEPREPARE` 안에서 같은 기준으로 다시 보여주고, 정리 가능한 항목은 별도 공개 명령을 만들지 않고 이 단계에서 처리한다.

### 3. `SWTITLECONVERT`는 정규화된 상태에서만 변환한다

`SWTITLECONVERT`는 다음 조건을 만족할 때만 진행한다.

- 현재 DWG가 `Documents/CAD tool/work` 안의 작업복사본이다.
- 필요한 용지 크기별 native GMTITLE 기준 객체가 있거나, 첫 native GMTITLE을 만들 단계다.
- `SWTITLESTATUS` 기준으로 `source-contaminated` 도면틀 정의가 남아 있지 않다.
- 삭제 후보가 도면 내부 주석/번호/텍스트와 겹치지 않는다.

조건이 안 맞으면 변환하지 말고 이유를 출력한다.

```text
중단: DR_A3_Outline 도면틀 정의 안에 source-contaminated 후보가 남아 있습니다.
다음: SWTITLEPREPARE
```

### 4. 삭제 로직은 "무엇을 지우는지"를 증명해야 한다

앞으로 삭제 후보는 세 등급으로 나눈다.

```text
DELETE: 기존 SolidWorks 표제란/도면틀 잔여물로 확실함
KEEP: 도면 내용으로 보호해야 함
REVIEW: 판단 불확실, 자동 삭제 금지
```

빨간 네모로 표시된 번호/주석처럼 도면 내부에 있는 항목은 기본적으로 `KEEP`이어야 한다.

삭제 로그에는 최소한 아래가 남아야 한다.

```text
handle
entity type
layer
bbox
sheet size
reason
decision: DELETE / KEEP / REVIEW
```

### 5. `SWTITLEVERIFY`는 모양이 아니라 구조로 완료를 판단한다

최종 완료 조건:

- 남은 원본 SolidWorks 표제란 후보: 0
- 남은 원본 SolidWorks 도면틀 후보: 0
- 원본 기준 A2/A3/A4 수량과 target `DR_A*_Outline` 수량 일치
- `DR_A3_Outline` 정의 상태가 의도한 표준과 일치
- `source-contaminated` 도면틀 정의 없음
- 중복 표제란 없음
- A4 frame-only 시트가 삭제되거나 누락되지 않음
- 대표 A2/A3/A4 `DR_titlea_3rd` 더블클릭 시 GMTITLE 표 편집창 열림

## 구현 단계

### 0단계: GitHub/로컬/CAD 기준을 먼저 맞춘다

코드 변경이나 CAD 조작 전에 아래를 먼저 확인한다.

```text
git status --short --branch
git fetch --prune origin
git log --oneline --decorate -n 25 --all
SWTITLEVERSION
SWTITLESTATUS
```

현재 기대값:

```text
origin/codex/gm-title: e738d2e Add GMTITLE main56 adoption guard 이상
local HEAD: origin/codex/gm-title와 일치해야 함
SWTITLEVERSION: 260704-target-overlap-adopt-main56-a4guard
사용자용 명령: SWTITLESTATUS / SWTITLEPREPARE / SWTITLECONVERT / SWTITLEVERIFY
```

아래 중 하나라도 맞지 않으면 변환을 진행하지 않는다.

```text
CAD에 예전 LSP가 로드됨
열린 도면이 work 복사본이 아님
현재 CAD 상태와 디스크 진단 결과가 서로 다른데 CAD 최신 로그를 만들지 않음
SWTITLESTATUS 없이 SWTITLECONVERT를 반복 실행하려 함
GMTITLE 창에서 일반 A3/A4 또는 ISO 제목블록을 그대로 OK 하려 함
```

### 1단계: 현재 진단을 더 명확하게 정리

코드 변경 전 확인:

```text
git status --short
git log --oneline --decorate -n 30 --all
SWTITLEVERSION
SWTITLESTATUS
SWTITLEVERIFY
```

확인할 로그:

```text
work/swcad_title_structure_diagnosis_last.txt
work/swcad_title_frame_embedded_title_clean_last.txt
work/swcad_title_native_frame_check_last.txt
work/swcad_title_verify_summary_last.txt
```

목표:

- A3 문제가 실제로 도면틀 정의 내부 표제란인지, 변환 중 생긴 중복 target인지 분리한다.
- 사라진 빨간 네모 객체가 삭제 후보 로그에 잡혔는지 확인한다.

### 2단계: 도면틀 정의 판정 모델 보강

`SWTITLESTATUS` 내부 진단은 아래 분류를 기준으로 한다.

```text
unknown
outline-only
native-format-with-title-geometry
source-contaminated
```

판정 기준:

- 도면틀 외곽선/눈금/좌표 문자는 보호한다.
- 오른쪽 아래 표제란 영역의 긴 LINE/MTEXT/INSERT, `DR` 로고, title-like block은 먼저 native-format 가능성을 검사한다.
- installed format DWG 자체가 그런 구조이면 `native-format-with-title-geometry`로 보고 자동 삭제하지 않는다.
- SolidWorks/이전 변환 source-like child block이 섞였을 때만 `source-contaminated`로 본다.

### 3단계: `SWTITLEPREPARE`를 선행 gate로 강화

`SWTITLEPREPARE`가 도면틀 정의를 정규화하지 못하면 `SWTITLECONVERT`가 진행하지 않게 한다.

삭제 후보는 `DELETE/KEEP/REVIEW`로 나눠 로그를 남긴다.

도면 내부 주석/번호/치수/BOM은 기본 보호한다.

`SWTITLEPREPARE`는 아래 유형을 분리해서 처리한다.

```text
native-format-with-title-geometry -> 자동 삭제 금지, 표준 A3 형태 검토 대상으로만 보고
source-contaminated -> 원본 SolidWorks/이전 제목블록처럼 보이는 child block 정의를 검토 후 복구
```

차단 유형을 보고만 하고 실제 정리 단계와 연결하지 않으면 사용자가 `SWTITLECONVERT`를 반복 실행하게 되므로 실패로 본다.

### 4단계: `SWTITLECONVERT` 안전 조건 강화

`SWTITLECONVERT` 시작 시 아래를 검사한다.

```text
source-contaminated 후보 > 0 -> 중단, SWTITLEPREPARE 안내
삭제 후보 REVIEW 존재 -> 중단 또는 WARN, 자동 삭제 금지
작업복사본 아님 -> 중단
SCRIPT / /b 자동 실행 -> 중단
```

변환 자체는 기존 원칙을 유지한다.

- 첫 native GMTITLE은 사용자가 `GMTITLE` 창에서 선택한다.
- 선택값은 로그가 요구한 `DR_A*_Outline`과 `DR_titlea_3rd`만 허용한다.
- `Frame positioning: ON`, `Object move: OFF`를 유지한다.
- 명령줄 `-GMTITLE` 자동 선택은 실제 CAD 이력상 잘못된 선택 위험이 있어 기본으로 사용하지 않는다.
- clone/preserve-copy는 속도 개선 수단일 뿐, 최종 검증을 대체하지 않는다.

### 5단계: 최종 검증과 CAD 화면 확인

`SWTITLEVERIFY`에서 아래가 나오기 전까지 완료로 보지 않는다.

```text
SWTITLEVERIFY_FINAL_OK
```

또는 경고가 있어도 남은 항목이 수동 더블클릭 확인뿐인 제한적인 `WARN`이어야 한다.

마지막에는 대표 A2/A3/A4 제목블록을 더블클릭한다.

```text
DR_titlea_3rd 더블클릭
-> GMTITLE 표 편집창 열림
```

## 금지할 반복 실수

- 화면 좌표 클릭으로 GMTITLE 용지/제목블록을 고르는 자동화
- 일반 A3/A4 또는 ISO 제목블록 기본값을 그대로 OK
- fallback/fake block을 만들어 GMTITLE처럼 간주
- clone 결과를 더블클릭 검증 없이 성공으로 판단
- A3/A4/frame-only 공개 명령을 계속 추가
- 원본 DWG에서 바로 변환
- bbox가 겹친다는 이유만으로 도면 내부 주석/번호/텍스트 삭제
- A4 frame-only 문제와 A3 내장 표제란 문제를 같은 원인으로 섞어 판단

## 완료 기준

이 계획은 아래 조건이 모두 만족되면 완료로 본다.

```text
SWTITLESTATUS가 A2/A3/A4 도면틀 정의 유형과 다음 조치를 명확히 표시
SWTITLEPREPARE가 native-format 도면틀 형상, source-contaminated 정의, 삭제 후보를 안전하게 분리
SWTITLECONVERT가 정규화 전 변환을 막음
SWTITLEVERIFY가 수량/중복/내장 표제란/더블클릭 대상을 최종 요약
A3 변환 후 표제란이 2개처럼 보이지 않음
도면 내부 번호/주석/텍스트가 삭제되지 않음
A4 frame-only 시트가 누락되지 않음
대표 A2/A3/A4 제목블록 더블클릭 시 GMTITLE 표 편집창 열림
```
