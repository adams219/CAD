# GMTITLE A3/A4 구조 재정렬 계획 - 2026-07-04

## 목적

SolidWorks DWG의 도면틀/표제란을 GstarCAD Mechanical GMTITLE 구조로 바꾸는 작업을 다시 정리한다.

이번 계획의 핵심은 새 명령어를 계속 만드는 것이 아니다. GitHub 커밋 이력, 로컬 실험 문서, 실제 CAD 로그를 먼저 기준으로 삼고, 같은 실수를 반복하지 않도록 판단 순서를 고정한다.

사용자에게 노출되는 흐름은 계속 아래 명령 안에 둔다.

```text
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

## 현재 이력 기준

GitHub 원격과 로컬 브랜치를 확인한 기준:

```text
branch: codex/gm-title
HEAD: 224c6fb Avoid stale GMTITLE handoff commit reference
origin/codex/gm-title: 224c6fb
HEAD...origin/codex/gm-title: 0 / 0
```

즉 현재 계획은 로컬만 보고 세운 것이 아니라, GitHub 원격 브랜치와 같은 지점에서 시작한다.

중요 기준 커밋:

```text
0121ae1 Clean up GMTITLE command surface
db2e231 Integrate four-step GMTITLE frame preparation
224c6fb Avoid stale GMTITLE handoff commit reference
```

중요 기준 문서:

```text
docs/history/gmtitle-native-vs-source-frame-plan-2026-07-04.md
docs/investigations/gmtitle-style-normalization-copy-comparison-2026-07-04.md
docs/history/gmtitle-main49-frame-prepare-integration-2026-07-04.md
docs/history/gmtitle-requirement-completion-audit-2026-07-04.md
docs/guide/gmtitle-current-run-card.md
```

## 반복된 실수의 원인

### 1. 증상마다 명령어를 추가했다

예전에는 A3, A4, frame-only, native upgrade, fast batch 문제마다 별도 명령이 생겼다.

그 결과 사용자가 어떤 명령을 먼저 입력해야 하는지 헷갈렸고, 같은 도면에서 일부 단계가 빠지는 일이 생겼다.

앞으로는 새 공개 명령을 만들지 않는다. 내부 구현이 늘어나더라도 사용자는 `SWTITLESTATUS -> SWTITLEPREPARE -> SWTITLECONVERT -> SWTITLEVERIFY` 흐름만 따른다.

### 2. A3 native 도면틀을 오염으로 오판했다

설치 원본 스캔 이력에 따르면:

```text
DR_A2_Outline: outline-only
DR_A3_Outline: native-format-with-title-geometry
DR_A4_Outline: outline-only
```

즉 `DR_A3_Outline.dwg` 자체에는 오른쪽 아래 표제란처럼 보이는 native 형상이 들어 있다.

따라서 A3 도면틀 안에 표제란처럼 보이는 선/문자가 있다는 이유만으로 삭제하면 안 된다.

### 3. main45와 main49 판단이 충돌했다

main45 쪽 결론:

```text
native-format-with-title-geometry는 설치 원본 구조일 수 있으므로 자동 삭제하지 않는다.
source-contaminated만 정리 대상으로 본다.
```

main49 쪽 결론:

```text
DR_A2/A3/A4 도면틀 정의 안에 title-like 형상이 있으면 SWTITLEPREPARE 정리 후보에 포함한다.
```

사용자가 본 A3 문제는 이 두 판단 사이의 경계 문제다.

올바른 방향은 둘 중 하나를 무조건 택하는 것이 아니다.

```text
A3 native 내부 형상 자체는 보존한다.
하지만 별도 DR_titlea_3rd 제목블록과 실제로 겹쳐 표제란이 두 개처럼 보이는 경우에는 style-normalization 대상으로 본다.
```

### 4. A4 frame-only를 일반 표제란 시트처럼 다뤘다

원본 A4 중 일부는 표제란 없는 도면틀 시트다.

이 경우 기존 표제란 텍스트 추출, 새 제목블록 채우기, 기존 제목블록 삭제 흐름을 그대로 적용하면 안 된다.

원본에 표제란이 없으면 기본 정책은:

```text
도면틀만 교체한다.
새 표제란을 억지로 만들지 않는다.
GstarCAD GMTITLE이 제목블록을 강제로 붙이는 경우, 원본 A4를 삭제하기 전에 WARN으로 멈춘다.
```

### 5. 잔여물 삭제가 도면 내용까지 건드릴 위험이 있었다

사용자가 빨간 네모로 표시한 번호, 주석, 작은 텍스트는 도면 내용이다.

잔여물 삭제는 아래 모두를 만족할 때만 허용한다.

```text
SolidWorks 원본 도면틀/표제란 영역에 속함
도면 내용, BOM, 주석, 치수, 모델 형상으로 보이지 않음
삭제 전 SWTITLESTATUS/SWTITLEPREPARE 로그에 핸들과 범위가 표시됨
작업복사본 안에서만 실행됨
```

## 새 판단 원칙

### 원칙 1. 원본 DWG는 편집하지 않는다

테스트와 변환은 항상 아래처럼 `work` 복사본에서만 한다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\...
```

`Downloads`나 원본 위치에서 바로 변환을 실행하지 않는다.

### 원칙 2. GMTITLE 선택은 사람이 확인하되, 좌표 입력은 자동화한다

이전 이력에서 스크린샷 좌표 클릭과 긴 소수점 좌표 입력은 반복 실수의 원인이었다.

GMTITLE 창에서 선택해야 하는 항목은 로그로 안내한다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

배치 기준점과 원본 위치 정렬은 LSP가 처리해야 한다.

### 원칙 3. A3는 "삭제"가 아니라 "중복 여부 판정"이 먼저다

A3에서 도면틀과 표제란이 하나처럼 보이면 바로 삭제하지 않는다.

먼저 아래 세 가지를 구분한다.

```text
1. 설치 원본 DR_A3_Outline이 원래 가진 native title-like 형상
2. 별도로 삽입된 DR_titlea_3rd 제목블록
3. SolidWorks 원본 또는 이전 변환이 도면틀 정의 안으로 섞인 source-contaminated 형상
```

정리 대상은 아래 둘 중 하나일 때만이다.

```text
source-contaminated로 판정됨
native-format-with-title-geometry가 별도 DR_titlea_3rd와 실제로 겹쳐 중복 표제란을 만들고 있음
```

### 원칙 4. A4는 frame-only 정책을 분리한다

A4 원본에 표제란이 없으면 `title sheet`가 아니라 `frame-only sheet`로 본다.

frame-only 변환 완료 조건:

```text
원본 A4 도면틀이 새 DR_A4_Outline 위치와 크기에 맞게 교체됨
원본 A4 바깥쪽 객체가 따라오지 않음
원본에 없던 표제란이 생기지 않음
기존 도면 내용이 삭제되지 않음
```

### 원칙 5. 완료 판정은 SWTITLEVERIFY와 더블클릭 확인으로만 한다

화면상 좋아 보인다는 이유로 완료 처리하지 않는다.

완료 기준:

```text
SWTITLEVERIFY_FINAL_OK
남은 SolidWorks 원본 표제란 후보: 0
남은 SolidWorks 원본 도면틀 후보: 0
frame-only 후보: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
도면 내부 번호, 주석, BOM, 치수, 모델 형상 유지
```

## 구현 계획

### 1단계. 현재 main49를 바로 밀지 말고 이력 충돌부터 정리

현재 main49는 frame 안 title-like 형상을 prepare 후보에 포함한다.

이 방향은 중복 표제란을 막는 데는 도움이 되지만, 설치 원본 A3 native 형상을 무조건 정리하는 쪽으로 흐를 위험이 있다.

따라서 먼저 LSP 기준을 아래처럼 조정한다.

```text
native-format-with-title-geometry 자체는 cleanup 후보가 아니다.
별도 DR_titlea_3rd와 실제 overlap이 있을 때 style-normalization 후보가 된다.
source-contaminated는 cleanup 후보가 된다.
```

### 2단계. SWTITLESTATUS가 결정을 더 자세히 말하게 한다

`SWTITLESTATUS`는 다음을 한글로 명확히 출력해야 한다.

```text
현재 도면이 work 복사본인지
현재 원본 A2/A3/A4 수량
현재 GMTITLE target A2/A3/A4 수량
A3 native 형상이 존재하는지
그 형상이 별도 제목블록과 겹치는지
A4 frame-only가 몇 장인지
다음 명령이 SWTITLEPREPARE인지 SWTITLECONVERT인지
```

사용자가 "뭔가 빠진 것 같다"고 느끼지 않도록, 누락된 단계도 status에서 직접 말하게 한다.

### 3단계. SWTITLEPREPARE를 두 작업으로 분리하되 명령은 하나로 유지

공개 명령은 `SWTITLEPREPARE` 하나만 유지한다.

내부 작업은 구분한다.

```text
Cleanup:
  source-contaminated 도면틀 정의 정리

Normalize:
  A3 native-format 형상과 별도 DR_titlea_3rd가 실제 겹칠 때만 중복 표제란 방지 정규화
```

로그에는 두 작업을 섞지 않는다.

```text
정리 대상: source-contaminated
정규화 대상: native-format overlap
보호 대상: 외곽선, 눈금, 좌표 문자, 도면 내용, BOM, 치수, 주석
```

### 4단계. SWTITLECONVERT는 상태 기반으로만 움직이게 한다

`SWTITLECONVERT`는 사용자가 반복 입력해도 현재 상태에 맞는 한 단계만 수행한다.

예상 분기:

```text
도면틀 정의 정리가 필요함
  -> 변환하지 않고 SWTITLEPREPARE 안내

첫 native GMTITLE이 없음
  -> 첫 native GMTITLE 생성 안내

특정 용지 크기의 native 기준 객체가 없음
  -> 해당 크기 한 장만 native로 생성 안내

같은 크기 기준 객체가 준비됨
  -> 남은 같은 크기 시트 자동 변환

A4 frame-only가 남음
  -> frame-only 정책으로 처리
```

### 5단계. 빨간 네모 삭제 문제를 fixture로 만든다

사용자가 보여준 사라지면 안 되는 항목을 회귀 테스트 대상으로 남긴다.

검증해야 할 보호 대상:

```text
도면 안 원형 번호
왼쪽 아래 주석/텍스트
BOM 또는 목록 표
치수선과 지시선
모델 형상
상단 revision 영역
```

이 fixture가 통과하기 전에는 잔여물 삭제 범위를 넓히지 않는다.

### 6단계. 실제 CAD 검증은 한 장씩이 아니라 상태 게이트로 진행한다

사용자가 실행할 순서:

```text
APPLOAD
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE    상태가 필요하다고 할 때만
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT    상태가 아직 변환이 남았다고 할 때만
SWTITLEVERIFY
```

Codex가 CAD를 조작할 때도 이 순서를 벗어나지 않는다.

특히 열려 있는 도면이 probe인지 실제 work copy인지 먼저 확인한다.

## 검증 계획

### 자동/읽기 전용 검증

```text
GitHub fetch 후 HEAD와 origin/codex/gm-title 일치 확인
LSP 로드 버전 확인
공개 명령 4개 유지 확인
설치 원본 DR_A2/A3/A4 분류 확인
source-contaminated와 native-format overlap 분리 확인
command-text guard 확인
잔여물 보호 fixture 확인
실제 work copy read-only status 확인
```

### 실제 CAD 검증

작업복사본에서만 수행한다.

```text
SWTITLESTATUS가 A2=1, A3=12, A4=2를 인식
A3 native overlap이 있으면 SWTITLEPREPARE 안내
SWTITLEPREPARE 후 중복 표제란 후보가 줄어듦
SWTITLECONVERT 후 같은 크기 시트가 자동 변환됨
A4 frame-only는 원본에 없는 표제란을 억지로 만들지 않음
SWTITLEVERIFY_FINAL_OK
대표 A2/A3/A4 더블클릭 시 GMTITLE 표 편집창
```

## 하지 않을 것

```text
Downloads 원본 도면 직접 편집
스크린샷 좌표 클릭으로 GMTITLE 선택 자동화
일반 ISO A3/A4 선택
A2 기준 객체를 A3/A4에 무조건 복제
DR_A3_Outline 내부 형상을 무조건 삭제
A3/A4 전용 공개 명령 추가
SWTITLEVERIFY 없이 완료 선언
```

## 다음 작업

1. 현재 source LSP에서 main49의 `native-format-with-title-geometry` cleanup 포함 로직을 다시 점검한다.
2. `style-normalization` 비교 복사본의 overlap 감지/gate 방향을 실제 source에 반영할지 결정한다.
3. 반영 시 `SWTITLESTATUS`가 `source-contaminated`와 `native overlap`을 별도로 출력하게 한다.
4. 실제 CAD 작업복사본에서 `SWTITLESTATUS -> SWTITLEPREPARE -> SWTITLESTATUS`까지만 먼저 검증한다.
5. 그 뒤에 `SWTITLECONVERT`를 진행한다.

