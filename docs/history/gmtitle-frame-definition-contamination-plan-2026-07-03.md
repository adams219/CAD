# GMTITLE DR 도면틀 정의 오염 해결 계획 - 2026-07-03

## 목적

이 계획은 A3 한 장이나 A4 한 장을 임시로 맞추는 계획이 아니다.

목표는 SolidWorks DWG를 GstarCAD Mechanical `GMTITLE` 구조로 바꿀 때, `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 도면틀 정의가 오염되거나 표제란 형상을 같이 품는 문제를 재발하지 않게 만드는 것이다.

최종 사용 명령은 계속 아래 네 개만 유지한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

새 증상이 나올 때마다 `A3FIX`, `A4FIX`, `FRAMEFIX` 같은 공개 명령을 늘리지 않는다.

## 이번 계획을 세우기 전에 확인한 이력

2026-07-03 기준 로컬/GitHub 이력 확인 결과:

```text
현재 브랜치: codex/gm-title
현재 HEAD: 0121ae1 Clean up GMTITLE command surface
origin/main: 0121ae1 Clean up GMTITLE command surface
```

계획에 반영한 주요 이력:

| 이력 | 이번 계획에 반영할 결론 |
| --- | --- |
| `f549ac2 Apply GM title transfer with fallback blocks` | 가짜/fallback 블록은 실제 GMTITLE 편집 동작을 보장하지 못한다. 다시 주력 방식으로 쓰지 않는다. |
| `0bb4c9b Document GMTITLE first-native picker limits` | 첫 GMTITLE 용지/제목블록 선택은 화면 좌표나 명령행 자동화로 안정화하지 않는다. |
| `b69ff54 Require strict native GMTITLE exemplars` | 모양이 같아 보여도 같은 크기의 실제 native GMTITLE 기준 객체가 없으면 신뢰하지 않는다. |
| `5ed90c1 Guard GMTITLE frame definition imports` | `DR_A*_Outline` 도면틀 정의 오염은 이미 확인된 실패 원인이다. 변환 전/후 모두 검사해야 한다. |
| `843e453 Verify preserve-copy GMTITLE A4 frame-only` | preserve-copy/clone은 속도 개선 수단일 뿐, 더블클릭 GMTITLE 표 편집창 검증을 대체하지 못한다. |
| `0121ae1 Clean up GMTITLE command surface` | 공개 명령어를 줄인 것이 현재 기준이다. 새 공개 명령 추가보다 4단계 안에 넣는다. |

로컬 문서 `docs/history/gmtitle-follow-up-agenda-2026-06-30.md`에서 특히 중요한 결론:

- 원본 SolidWorks DWG는 처음부터 오염된 target `DR_A*_Outline` 정의를 갖고 있지 않았다.
- 오염은 이전 conversion/import 경로에서 생겼다.
- 기존 테스트에서는 `DR_A3_Outline` 안에 `DR-A3 From_HYUN`, `DR_A4_Outline` 안에 `도면 세로 A4 From_HYUN` 같은 source-like child가 들어간 적이 있다.
- 참조 중인 오염 definition을 조용히 이름 변경하거나 덮어쓰면 안 된다. 이 경우는 rebuild 전략이 필요하다.

## 현재 문제 모델

사용자가 지적한 현상:

```text
A2: 도면틀만 있는 형태가 기대와 맞음
A3: 도면틀과 제목블록이 하나로 합쳐진 블록처럼 보임
A4: 원본은 frame-only인데, 변환 중 원본에 없던 제목블록/객체가 붙거나 시트가 누락될 위험이 있음
```

2026-07-03 최신 사용자 지적:

```text
A4를 건드린 문제가 아니라, A3에서 DR_A3_Outline 도면틀 자체가 표제란을 포함한 블록처럼 동작한다.
A2는 도면틀만 있는 형태인데, A3는 도면틀과 제목블록이 하나로 합쳐져 보여 도면 형태가 달라진다.
이 문제는 특정 용지 한 장을 임시로 맞추는 방식이 아니라 구조를 분석해서 해결해야 한다.
```

이 지적 때문에 앞으로 A3 문제를 “A4 frame-only 변환 실패”나 “표제란 배치 좌표 문제”로 먼저 해석하지 않는다.
가장 먼저 `DR_A3_Outline` block definition 내부에 source-like child block, title geometry, title text, logo가 들어갔는지 확인한다.

가장 유력한 원인 모델:

1. `DR_A3_Outline` 도면틀 insert 자체는 들어왔지만, 그 block definition 내부에 표제란 형상 또는 source-like child insert가 들어 있다.
2. 그 상태에서 별도 `DR_titlea_3rd` 제목블록도 추가되면 표제란이 2개처럼 보인다.
3. 화면에서 보이는 일부 선이나 블록만 지우면 현재 장은 괜찮아 보여도, 같은 오염 definition을 쓰는 다음 A3/A4에서 문제가 반복된다.
4. A4는 원본에 표제란이 없는 frame-only 시트이므로, title sheet와 같은 방식으로 값을 추출하거나 삭제하면 안 된다.

따라서 해결 대상은 좌표나 특정 객체 하나가 아니라 아래 구조 전체다.

- 원본 SolidWorks frame/title insert
- target `DR_A*_Outline` insert
- target `DR_titlea_3rd` insert
- target frame block definition 내부의 source-like child insert
- frame-only A4의 raw bbox와 실제 보이는 bbox 차이
- 변환 중 생긴 고아 target frame
- 실수로 도면 안에 들어간 명령어 TEXT/MTEXT

## 반복 실수 방지 원칙

앞으로 아래 방식은 기본 해결책으로 쓰지 않는다.

- 스크린샷 좌표 클릭으로 GMTITLE 용지/제목블록을 고르는 방식
- 일반 A3/A4, ISO 제목블록, Object move ON 기본값을 확인 없이 통과시키는 방식
- fallback/fake block을 만들어 GMTITLE처럼 쓰는 방식
- preserve-copy/clone 결과를 더블클릭 검증 없이 성공으로 보는 방식
- A3/A4/frame-only마다 사용자가 다른 공개 명령을 외우는 방식
- 저장된 `work/swcad_title_*_last.txt`만 보고 현재 열린 CAD 화면 상태라고 단정하는 방식

## 해결 계획

### 1. 작업 시작 게이트

모든 CAD 테스트 또는 코드 수정 전 아래를 먼저 확인한다.

```text
git fetch origin --prune
git status --short --branch
git log --oneline --decorate --graph --all -15
SWTITLEVERSION
SWTITLESTATUS
```

확인할 것:

- 원격 기준과 로컬 기준이 어느 커밋인지
- 현재 로드된 LSP가 최신인지
- 로그의 `DWG 파일:`이 현재 열어 둔 작업복사본과 같은지
- 현재 도면이 `Documents/CAD tool/work` 아래 복사본인지
- `SWTITLESTATUS`가 다음 명령을 무엇으로 안내하는지

이 게이트를 통과하지 못하면 `SWTITLECONVERT`를 실행하지 않는다.

Codex 작업 게이트:

1. `git log`에서 위 표의 실패 이력을 다시 확인한다.
2. `docs/history/gmtitle-frame-definition-contamination-plan-2026-07-03.md`와 `docs/history/gmtitle-completion-audit-2026-07-03.md`를 먼저 본다.
3. 최신 `work/swcad_title_*_last.txt` 로그의 `DWG 파일:`이 현재 열려 있는 작업복사본과 같은지 확인한다.
4. 비슷한 증상이 이미 있었으면 새 명령을 만들기 전에 기존 4단계 안에서 어디에 넣을지 결정한다.
5. CAD를 직접 조작할 때는 좌표 클릭 대신, 사용자가 직접 확인해야 하는 GMTITLE 선택값을 먼저 로그/문서에 고정한다.

### 2. 변환 전 구조 진단

`SWTITLESTATUS`는 읽기 전용으로 아래를 반드시 판단한다.

- 원본 표제란 시트 수
- 원본 도면틀 수
- frame-only 시트 수
- A2/A3/A4별 원본 시트 수
- target `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 수
- target `DR_titlea_3rd` 수
- `DR_A*_Outline` definition 내부 source-like child 후보
- 도면틀 내부 내장 표제란 형상 후보
- 고아 target frame
- A4 raw bbox가 보이는 A4 크기보다 큰지
- 다음에 실행할 명령

이 단계에서는 도면을 변경하지 않는다.

### 3. 변환 전 정규화

`SWTITLEPREPARE`는 아래 정리만 맡는다.

- 실수 명령어 TEXT/MTEXT 후보 정리
- 제목블록 없는 고아 `DR_A*_Outline` 정리
- 도면틀 definition 내부에 들어간 중첩 제목블록/표제란 형상 후보 정리
- `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 공통 검사

안전 조건:

- 작업복사본에서만 실행한다.
- 삭제 후보를 보여주고 `YES` 확인을 받는다.
- 외곽선, 좌표 눈금, `!GENTITLE-*` 표식, 정상 `DR_titlea_3rd`는 보호한다.
- 후보가 애매하면 삭제하지 않고 `SWTITLESTATUS`/로그에 남긴다.

### 4. 오염 definition 처리 정책

오염된 `DR_A*_Outline` definition이 발견되면 아래 순서로 처리한다.

1. 현재 도면에서 그 definition을 참조 중인 insert 수를 확인한다.
2. 참조 insert가 없으면 안전하게 백업 이름으로 바꾸고 설치 폴더의 원본 DR outline definition을 다시 가져올 수 있다.
3. 참조 insert가 이미 있으면 조용히 덮어쓰지 않는다.
4. 참조 중인 오염 definition은 다음 중 하나로 rebuild해야 한다.
   - 해당 target frame/title 쌍을 삭제하고 `SWTITLECONVERT`가 실제 GMTITLE로 다시 만들게 한다.
   - `SWTITLEPREPARE`가 definition 내부 source-like child만 명확히 식별할 수 있을 때만 정리한다.
5. 어떤 경우에도 기존 원본 SolidWorks frame-only A4를 먼저 삭제하지 않는다.

이 정책의 핵심은 “보이는 A3 표제란 하나를 지우는 것”이 아니라, 같은 definition을 재사용하는 모든 시트에서 문제가 반복되지 않게 하는 것이다.

### 5. 변환 실행 정책

`SWTITLECONVERT`는 내부 상태 기계로만 처리한다.

처리 순서:

1. 이미 만들어진 A3/A4 target pair 중 native 더블클릭 검증이 필요한 쌍이 있으면 한 장만 교체한다.
2. 변환할 원본 title sheet가 남아 있으면 같은 크기 native 기준 객체를 확인한다.
3. 해당 크기 native 기준 객체가 없으면 실제 GMTITLE 창을 열어 첫 기준 객체를 만들도록 안내한다.
4. 같은 크기 기준 객체가 있으면 남은 시트를 빠르게 처리한다.
5. frame-only A4만 남으면 A4 frame-only 경로로 처리한다.
6. 각 단계 후에는 `SWTITLESTATUS`를 다시 실행한다.

GMTITLE 창에서 반드시 확인할 값:

```text
용지/도면틀: 로그가 요구한 DR_A2_Outline / DR_A3_Outline / DR_A4_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

일반 A3/A4, ISO 제목블록, Object move ON이면 OK를 누르지 않는다.

### 6. A3 중복 표제란 검증

A3는 다음 기준을 만족해야 한다.

```text
DR_A3_Outline = 도면틀 역할만 담당
DR_titlea_3rd = 제목블록 역할만 담당
A3 화면에 표제란이 중복으로 보이지 않음
대표 A3 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
```

`SWTITLEVERIFY`가 확인해야 할 것:

- A3 target frame 수
- A3 target title 수
- A3 target frame/title pair 수
- frame 안에 들어간 embedded title geometry 수
- `DR_A3_Outline` definition 내부 source-like child 후보 수
- native-like 여부
- 고급 속성 편집기/REFEDIT 위험 안내

### 7. A4 frame-only 검증

A4는 원본에 표제란이 없는 시트가 있을 수 있으므로 별도로 검증한다.

성공 기준:

```text
원본 A4 frame-only 수와 변환 후 A4 target frame 수가 맞음
원본에 없던 표제란이 불필요하게 중복 생성되지 않음
기존 A4가 bbox 오류 때문에 삭제/누락되지 않음
DR_A4_Outline 실제 bbox가 보이는 A4 크기와 맞음
```

A4 raw bbox가 실제 A4보다 크거나 틀 밖 객체가 붙으면 기존 A4를 삭제하지 않고 중단한다.

### 8. 최종 검증 문턱

완료로 보려면 아래가 필요하다.

- 남은 원본 표제란 후보: 0
- 남은 원본 도면틀 후보: 0
- 고아 target `DR_A*_Outline`: 0
- 변환 시작 때 기록된 A2/A3/A4 기준 수량과 target frame/title 수량 일치
- A3 도면틀 안에 합쳐진 표제란 형상 없음
- A4 frame-only 누락 없음
- `DR_titlea_3rd` 속성 태그 누락 없음
- 대표 A2/A3/A4 제목블록 더블클릭 시 GMTITLE 표 편집창 열림

`SWTITLEVERIFY_FINAL_OK`가 아니거나, 수동 더블클릭 확인이 끝나지 않았으면 완료로 보지 않는다.

## 다음 작업 순서

현재 방향에서 다음 작업은 아래 순서가 맞다.

1. 최신 원본 LSP `260703-integrated-flow-main-42`를 로드한다.
2. 현재 작업복사본에서 `SWTITLESTATUS`를 실행한다.
3. `DR_A3_Outline` 내부 표제란 후보 또는 오염 definition 경고가 있으면 `SWTITLEPREPARE`를 먼저 실행한다.
4. `SWTITLESTATUS`를 다시 실행해 후보가 줄었는지 확인한다.
5. `SWTITLECONVERT`를 한 단계만 실행한다.
6. GMTITLE 창이 열리면 로그가 요구한 DR 용지, `DR_titlea_3rd`, `Frame positioning ON`, `Object move OFF`를 확인한다.
7. `SWTITLESTATUS`를 다시 실행한다.
8. 필요한 동안 `SWTITLECONVERT`와 `SWTITLESTATUS`를 반복한다.
9. 마지막에 `SWTITLEVERIFY`를 실행한다.
10. 대표 A2/A3/A4 `DR_titlea_3rd`를 더블클릭해 GMTITLE 표 편집창이 열리는지 확인한다.

이 순서에서 벗어나야 할 것처럼 보이면, 먼저 GitHub/로컬 이력과 `work/*.txt` 로그에서 같은 실패가 이미 있었는지 확인한다.

## main-40 추가 방지 장치

`main-40`부터는 변환된 target GMTITLE 도면틀/제목블록에 `SWTITLE_EXEMPLAR` xdata를 남길 때, A2/A3/A4 기준 수량도 같이 기록한다.

이유:

- 이전에는 원본 SolidWorks 도면틀이 이미 삭제된 뒤에는 `SWTITLEVERIFY`가 원래 A3/A4가 몇 장이었는지 잊을 수 있었다.
- 그 상태에서는 A4 한 장이 누락되어도 “현재 남은 원본이 없고 target도 일부 있으니 완료처럼 보이는” 위험이 있었다.
- 이제 `SWTITLESTATUS`와 `SWTITLEVERIFY`가 `변환 기준 전체 용지 수`, `변환 기준 수량 출처`, `대상 도면틀 수량 부족/초과`를 출력한다.

판정:

- 기준 수량 출처가 `도면 xdata 기록`이면 이전 변환 단계에서 저장한 수량을 사용한다.
- 기준 수량 출처가 `현재 원본+대상 상태 추정`이면 아직 저장된 기준 수량이 없어서 현재 남은 원본과 target을 합산한 것이다.
- target 도면틀 수량이 기준 수량보다 부족하면 `SWTITLEVERIFY_FINAL_FAIL`이다.
