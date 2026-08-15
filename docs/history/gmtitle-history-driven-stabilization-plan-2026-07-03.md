# GMTITLE 이력 기반 안정화 계획 - 2026-07-03

## 목적

이번 계획의 목적은 A3 한 장, A4 한 장을 임시로 고치는 것이 아니다.

SolidWorks DWG의 도면틀/표제란을 GstarCAD Mechanical `GMTITLE` 구조로 바꾸는 전체 흐름에서 같은 실수를 반복하지 않도록, GitHub/로컬 이력과 최근 CAD 로그를 기준으로 안정화 순서를 고정한다.

최종 사용자 흐름은 계속 네 명령만 유지한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

새 증상마다 새 공개 명령어를 추가하지 않는다.

## 작업 전 이력 확인 약속

앞으로 GMTITLE 관련 판단, 코드 수정, CAD 테스트를 시작하기 전에는 GitHub/로컬 이력을 먼저 본다.

확인 순서:

```text
git fetch origin --prune
git status --short --branch
git log --oneline --decorate --graph --all -30
```

그 다음 현재 CAD 쪽 기준을 확인한다.

```text
SWTITLEVERSION
SWTITLESTATUS
```

이 절차의 목적은 속도를 늦추는 것이 아니라, 이미 실패한 방향을 다시 밟지 않기 위한 것이다.

반드시 확인할 이력:

- `0bb4c9b`: GMTITLE 첫 용지/제목블록 선택은 화면 좌표나 명령행 자동화에 맡기지 않는다.
- `b69ff54`: 같은 용지 크기의 실제 native GMTITLE 기준 객체가 없으면 복제/일괄 변환을 신뢰하지 않는다.
- `5ed90c1`: `DR_A*_Outline` 도면틀 정의 오염을 먼저 확인한다.
- `843e453`: preserve-copy/clone은 속도 개선용이며 더블클릭 GMTITLE 표 편집창 검증을 대체하지 않는다.
- `0121ae1`: 공개 명령을 늘리지 않고 네 명령 흐름 안에서 해결한다.

이 확인 없이 `SWTITLECONVERT`를 반복 실행하거나 새 공개 명령을 만들지 않는다.

## 이력에서 확정한 금지 방향

아래 내용은 추측이 아니라 로컬 Git 이력과 기존 문서에서 반복 확인된 실패 방향이다.

| 이력 | 결론 |
| --- | --- |
| `f549ac2 Apply GM title transfer with fallback blocks` | 가짜/fallback 블록은 GMTITLE 편집 동작을 보장하지 못하므로 최종 방식으로 쓰지 않는다. |
| `0bb4c9b Document GMTITLE first-native picker limits` | 첫 `GMTITLE` 용지/제목블록 선택은 좌표 클릭이나 명령행 자동화로 안정화하기 어렵다. |
| `b69ff54 Require strict native GMTITLE exemplars` | 같은 모양의 복제본이어도 native GMTITLE 기준 객체로 바로 신뢰하지 않는다. |
| `5ed90c1 Guard GMTITLE frame definition imports` | `DR_A*_Outline` 도면틀 정의 오염은 이미 확인된 실패 원인이므로 변환 전/후 검사해야 한다. |
| `843e453 Verify preserve-copy GMTITLE A4 frame-only` | preserve-copy/clone은 속도를 줄이는 데 유용하지만, 더블클릭 편집창 검증을 대체하지 못한다. |
| `0121ae1 Clean up GMTITLE command surface` | 공개 명령어가 많아지면 사용 순서가 흐려지므로 4단계 흐름으로 접는다. |

따라서 앞으로 금지할 방식은 다음과 같다.

- 스크린샷 좌표 클릭을 기본 자동화로 쓰기
- 일반 A3/A4 또는 ISO 제목블록 기본값을 그대로 확인하기
- clone 결과를 더블클릭 검증 없이 성공으로 판단하기
- 도면틀 안에 표제란이 합쳐진 상태를 모양만 보고 넘어가기
- A3/A4/A4 frame-only마다 사용자가 다른 공개 명령을 외우게 하기

## 현재 문제의 정확한 모델

현재 사용자가 지적한 핵심은 다음이다.

```text
A2: 도면틀만 들어오는 상태가 기대와 맞음
A3: 도면틀과 제목블록이 하나로 합쳐진 것처럼 보여 도면 형태가 달라짐
A4: 원본은 frame-only인데, 변환 과정에서 예상하지 않은 제목블록/객체가 붙거나 누락될 위험이 있음
```

이 문제는 `DR_A3_Outline` 또는 그 하위 블록 정의 안에 예전 SolidWorks/DR 표제란 형상이 섞였을 때 생길 수 있다.

그래서 A3에 별도 `DR_titlea_3rd`를 추가하면 화면에는 표제란이 두 번 들어간 것처럼 보인다. 이 상태에서 단순히 보이는 객체 하나를 지우면 다음 시트나 다음 도면에서 같은 문제가 다시 생긴다.

해결해야 할 대상은 한 장의 위치가 아니라 아래 구조다.

- 원본 SolidWorks 도면틀/표제란 insert
- `DR_A*_Outline` target 도면틀 insert
- `DR_titlea_3rd` target 제목블록 insert
- `DR_A*_Outline` 블록 정의 내부에 섞인 표제란 형상
- frame-only A4처럼 원본에 제목블록이 없는 시트
- 실수로 도면 안에 들어간 명령어 TEXT/MTEXT 잔여물

도면틀 정의 오염과 A3/A4 표제란 중복 문제의 세부 대응은 별도 계획에 고정한다.

```text
docs/history/gmtitle-frame-definition-contamination-plan-2026-07-03.md
```

## 장기 해결 방향

### 1. 상태 진단을 먼저 고정한다

CAD에서 작업을 시작할 때는 `SWTITLESTATUS`만 먼저 본다.

`SWTITLESTATUS`가 반드시 보여줘야 하는 판단 기준:

- 작업복사본인지 여부
- 현재 로드된 LSP 버전
- 원본 표제란 시트 수
- 원본 도면틀 수
- frame-only 시트 수
- A2/A3/A4별 원본/대상 수량
- native GMTITLE 기준 객체 존재 여부
- `DR_A*_Outline` 블록 정의 내부 표제란 후보
- 고아 target frame
- 다음에 실행할 명령

이 단계에서는 도면을 변경하지 않는다.

### 2. 변환 전 정규화를 한 곳에 모은다

`SWTITLEPREPARE`는 앞으로 아래 정리만 담당한다.

- 실수 명령어 TEXT/MTEXT 후보 정리
- 제목블록 없는 고아 `DR_A*_Outline` 정리
- 도면틀 정의 안에 중첩된 제목블록 insert 정리
- `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 내부에 합쳐진 표제란 형상 정리

중요한 제한:

- 외곽선, 좌표 눈금, `!GENTITLE-*` 표식은 보호한다.
- 후보가 불확실하면 삭제하지 않고 로그만 남긴다.
- 삭제는 work 폴더의 작업복사본에서만 진행한다.
- 실제 삭제 전에는 `YES` 확인을 받는다.

이렇게 해야 A3 하나만 임시로 지우는 것이 아니라, 같은 오염 구조가 다른 시트에 반복되는 것을 막을 수 있다.

### 3. 변환은 한 명령 안의 상태 기계로 처리한다

`SWTITLECONVERT`는 내부적으로 다음 순서로 판단한다.

1. A3/A4 target 쌍 중 native 더블클릭 검증이 필요한 쌍이 있으면 한 장만 native 교체한다.
2. 변환할 원본 표제란 시트가 없고 frame-only도 없으면 멈추고 `SWTITLEVERIFY`를 안내한다.
3. frame-only A4만 남아 있으면 frame-only native 적용 단계로 들어간다.
4. native GMTITLE 기준 객체가 하나도 없으면 첫 native GMTITLE 생성 단계로 들어간다.
5. 같은 크기 native 기준 객체가 있으면 남은 시트를 빠르게 처리한다.
6. 빠른 처리 후 A3/A4 native 교체 후보가 생기면 다시 한 장만 처리한다.

한 번에 여러 장을 계속 밀어붙이지 않는다.

이유는 `GMTITLE` 창이 일반 A3/A4 또는 ISO 제목블록으로 열리는 실수가 이미 반복됐기 때문이다. 한 장씩 확인해야 잘못된 선택이 여러 장에 복제되지 않는다.

### 4. A3 문제는 도면틀 정의 문제로 다룬다

A3에서 도면틀과 제목블록이 하나로 합쳐진 것처럼 보이면 다음 원칙을 적용한다.

1. 먼저 `SWTITLESTATUS`로 `DR_A3_Outline` 블록 정의 내부 표제란 후보가 있는지 확인한다.
2. 후보가 있으면 `SWTITLEPREPARE`로 정리한다.
3. 정리 후 다시 `SWTITLESTATUS`를 실행해 후보가 줄었는지 확인한다.
4. 그 다음에만 `SWTITLECONVERT`를 실행한다.
5. `SWTITLEVERIFY`에서 A3 target frame/title 수와 중복 여부를 확인한다.

여기서 중요한 기준은 화면에서 표제란이 하나처럼 보이는지가 아니다.

성공 기준은:

```text
DR_A3_Outline = 도면틀 역할
DR_titlea_3rd = 제목블록 역할
대표 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
```

### 5. A4는 frame-only 흐름으로 분리한다

A4 원본에 표제란이 없으면 일반 title sheet처럼 처리하지 않는다.

A4 처리 기준:

- 원본 A4가 frame-only이면 표제란 텍스트 추출을 기대하지 않는다.
- `DR_A4_Outline` native 기준 객체가 없으면 먼저 실제 GMTITLE로 한 장을 만든다.
- 새 A4 도면틀 bbox가 원본 A4와 맞지 않으면 기존 A4를 삭제하지 않는다.
- `DR_A4_Outline.dwg` 원본에 없는 객체가 변환 결과에 붙으면 target definition 오염 또는 raw bbox 문제로 보고 중단한다.

## 검증 문턱

아래 조건 중 하나라도 실패하면 완료로 보지 않는다.

- 남은 원본 표제란 후보가 0이다.
- 남은 원본 도면틀 후보가 0이다.
- A2/A3/A4 target frame 수가 원본 시트 수와 맞다.
- A3 도면틀 내부에 표제란 형상이 중복으로 들어오지 않는다.
- A4 frame-only 시트가 삭제되거나 누락되지 않는다.
- 고아 `DR_A*_Outline` 도면틀이 없다.
- `DR_titlea_3rd` 속성 태그가 누락되지 않는다.
- 대표 A2/A3/A4 제목블록을 더블클릭했을 때 GMTITLE 표 편집창이 열린다.

모양이 비슷하다는 이유로 완료 처리하지 않는다.

## CAD 테스트 원칙

작업은 아래 순서로만 진행한다.

```text
APPLOAD
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT
SWTITLEVERIFY
```

`SWTITLESTATUS`가 다음 명령을 다르게 안내하면 그 안내를 따른다.

`GMTITLE` 창이 열리면 반드시 아래를 확인한다.

```text
용지: 로그가 요구한 DR_A2_Outline / DR_A3_Outline / DR_A4_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

일반 A3/A4, ISO 제목블록, Object move ON이면 확인하지 않고 취소한다.

## 로그와 이력 확인 절차

작업 전 확인:

```text
git status --short --branch
git log --oneline --decorate --max-count=25
SWTITLEVERSION
```

CAD 로그 확인:

```text
work/swcad_title_fast_status_last.txt
work/swcad_title_frame_def_check_last.txt
work/swcad_title_native_frame_check_last.txt
work/swcad_title_gmtitle_verify_all_last.txt
work/swcad_title_double_click_check_last.txt
```

주의:

`work/swcad_title_*_last.txt`는 마지막 실행 기준으로 덮어써진다. `/b` 런타임 확인 로그는 `*_runtime_260703.txt` 접미사 로그를 우선 확인한다.

## 반복 실수 방지용 작업 규칙

앞으로 새 판단이나 코드 수정 전에 아래 네 가지를 먼저 고정한다.

```text
1. 현재 Git 기준: branch, HEAD commit, origin/main과의 관계
2. 현재 CAD 기준: SWTITLEVERSION에 표시된 LSP 버전
3. 현재 로그 기준: 로그 파일 안의 DWG 경로와 실행 명령
4. 적용할 이력 교훈: 이미 실패한 방식인지 여부
```

### Codex 작업 전 필수 이력 게이트

사용자가 명시적으로 요청한 기준이다. 앞으로 GMTITLE 관련 판단, 코드 수정, CAD 테스트를 시작하기 전에는 아래 순서를 먼저 수행한다.

```text
1. GitHub 원격 기준 확인
   - git fetch origin --prune
   - git status --short --branch
   - git log --oneline --decorate --graph --all -15

2. 로컬 이력 교훈 확인
   - 0121ae1: 공개 명령어를 다시 늘리지 않는다.
   - 0bb4c9b: GMTITLE 첫 선택을 좌표/명령행 자동화로 믿지 않는다.
   - b69ff54: native GMTITLE 기준 객체를 엄격하게 검증한다.
   - 843e453: preserve-copy/clone은 더블클릭 검증을 대체하지 않는다.

3. 현재 CAD 로그 기준 확인
   - 로그 파일 안의 DWG 경로가 현재 작업복사본과 같은지 본다.
   - `_runtime_260703` 같은 읽기 전용 런타임 로그를 실제 변환 상태로 착각하지 않는다.
   - 마지막 로그만 보지 말고 `SWTITLESTATUS`/`SWTITLEVERIFY` 로그의 실행 명령과 결과 코드를 같이 본다.

4. 실패 방식 차단
   - 새 공개 명령어 추가
   - 화면 좌표 클릭 반복
   - 일반 A3/A4 또는 ISO 제목블록 기본값 확인
   - fallback/fake 블록 회귀
   - 더블클릭 검증 없는 clone 성공 처리
```

이 게이트를 통과하지 못하면 CAD에서 다음 명령을 실행하지 않는다. 특히 GstarCAD 창이 열려 있어도, 현재 로드된 `SWTITLEVERSION`과 로그의 DWG 경로가 확인되기 전에는 `SWTITLECONVERT`를 반복 입력하지 않는다.

특히 `work/swcad_title_*_last.txt`만 보고 결론을 내리지 않는다.

이 파일들은 마지막 실행으로 계속 덮어써지므로, 로그 안의 `DWG 파일:`이 실제 사용자가 보고 있는 도면인지 먼저 확인한다. 런타임 확인용 복사본 로그라면 실제 변환 작업 상태를 설명하는 증거로 쓰지 않는다.

GitHub/로컬 이력에서 이미 실패한 방식은 다시 시도하지 않는다.

- `-GMTITLE` 명령행 자동 선택은 현재 GstarCAD에서 "알 수 없는 명령"으로 실패한 이력이 있으므로 기본 경로로 쓰지 않는다.
- 스크린샷 좌표 클릭은 용지/제목블록 선택 자동화의 기본 방식으로 쓰지 않는다.
- `DR_A*_Outline` insert가 보인다는 이유만으로 native GMTITLE이 성공했다고 보지 않는다.
- `DR_titlea_3rd` 더블클릭 검증 없이 preserve-copy/clone 결과를 완료로 보지 않는다.
- A3/A4 문제를 새 공개 명령어 추가로 해결하지 않는다. 공개 흐름은 네 명령만 유지한다.

## 최근 로그에서 확인한 사실

2026-07-03 오전 첨부 로그와 로컬 문서를 함께 보면, 현재 문제는 두 갈래다.

### A3

최근 A3 로그에서는 실제 `GMTITLE`로 `DR_A3_Outline`과 `DR_titlea_3rd`가 생성되고, native marker도 붙은 기록이 있다.

```text
Native GMTITLE title insert: DR_titlea_3rd
Native GMTITLE frame insert: DR_A3_Outline
Native GMTITLE was used directly.
Native exemplar marker set: yes
```

그런데 사용자가 화면에서 본 문제는 "A3 도면틀 안에 표제란이 같이 딸려온 것처럼 보인다"는 것이다.

따라서 이 문제는 단순히 `SWTITLECONVERT`를 더 누르는 문제가 아니다. 다음 둘을 분리해서 봐야 한다.

- 정상 native `DR_A3_Outline` 안에 원래 포함된 표제란 영역인지
- 현재 도면의 `DR_A3_Outline` 블록 정의가 예전 SolidWorks/DR 표제란 형상으로 오염된 것인지

다음 분석은 `DR_A3_Outline` 원본 파일, 현재 도면 안의 `DR_A3_Outline` 블록 정의, 현재 화면의 target insert를 서로 비교하는 방향으로 진행한다. 화면에서 보이는 표제란을 바로 삭제하지 않는다.

### A4

최근 A4 로그에서는 원본 A4를 바로 삭제하지 않고 중단한 기록이 있다.

```text
ABORT_EXISTING_FRAME_ONLY_GMTITLE_RAW_BBOX_EXTRA_OBJECTS
Frame raw selection warning: raw CAD selection bbox is larger than the effective visible frame
Removed pending invalid GMTITLE inserts
기존 A4 frame-only 내용은 삭제하지 않음
```

이것은 사용자가 명령어를 빼먹어서 생긴 문제라기보다, `DR_A4_Outline` 삽입 결과의 실제 선택 범위가 보이는 A4 프레임보다 커지는 문제다.

따라서 A4는 다음 원칙으로 처리한다.

- bbox 검사를 통과하기 전에는 기존 A4 원본을 삭제하지 않는다.
- `DR_A4_Outline`이 보이는 210 x 297 A4와 실제 선택 bbox가 왜 다른지 먼저 분석한다.
- A4에 예상 밖 제목블록/객체가 붙는 경우는 변환 성공이 아니라 중단/조사 상태로 본다.

## 구현 순서

1. 현재 원본 LSP `260703-integrated-flow-main-42`를 기준으로 유지한다.
2. A3/A4 전용 공개 명령어를 다시 늘리지 않는다.
3. `SWTITLESTATUS` 출력에서 A3/A4 구조 문제를 더 명확히 한국어로 표시한다.
4. `SWTITLEPREPARE`가 A3 도면틀 내부 표제란 형상 후보를 정리하되, 불확실하면 삭제하지 않도록 유지한다.
5. `SWTITLECONVERT`가 A3/A4 native 교체를 한 장씩만 처리하는 원칙을 유지한다.
6. A4 frame-only는 bbox 검증을 통과하기 전까지 기존 A4를 삭제하지 않는다.
7. `SWTITLEVERIFY`가 최종 OK/WARN/FAIL을 내고, 더블클릭 수동 확인 대상까지 안내한다.
8. CAD 검증이 실제로 통과한 뒤에만 커밋/푸시한다.

## 다음 구현 계획

이제부터의 구현은 아래 순서로만 진행한다.

### 1단계: 증거 기준 정리

- 현재 도면에서 `SWTITLESTATUS`와 `SWTITLEVERIFY`를 실행한다.
- 로그 안의 `DWG 파일:`이 실제 사용 중인 작업복사본인지 확인한다.
- Git 기준 버전과 CAD 로드 버전이 같은지 확인한다.
- 변환 전/후 A2/A3/A4 개수를 표로 남긴다.

### 2단계: A3 도면틀 정의 비교

- 설치 폴더의 원본 `DR_A3_Outline.dwg`와 현재 도면 안 `DR_A3_Outline` 블록 정의를 비교한다.
- 비교 대상은 외곽선만이 아니라 하위 블록, 제목블록처럼 보이는 선/문자/블록, bbox, 속성/확장 데이터까지 포함한다.
- 원본 `DR_A3_Outline` 자체가 표제란 영역을 포함하는 구조라면, GstarCAD Mechanical의 정상 DR A3 형식으로 보고 별도 `DR_titlea_3rd`와 중복되는지 판단한다.
- 현재 도면 안 정의만 오염된 경우에만 `SWTITLEPREPARE`에서 복구하도록 한다.

### 3단계: A4 raw bbox 원인 분석

- `DR_A4_Outline`의 보이는 bbox와 실제 선택 bbox를 각각 로그에 분리해 표시한다.
- 실제 선택 bbox를 키우는 하위 블록 또는 의존 객체가 무엇인지 이름/핸들/bbox로 출력한다.
- 원본 A4 frame-only를 삭제하기 전에 이 검사가 통과해야 한다.

### 4단계: 네 명령 안으로 통합

- 필요한 수정은 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 내부에만 넣는다.
- 예전처럼 `SWTITLEA3...`, `SWTITLEFRAMEONLY...` 같은 공개 명령을 다시 늘리지 않는다.
- 사용자가 직접 외워야 하는 순서를 늘리지 않는다.

### 5단계: 실제 CAD 검증

- 작업복사본에서만 검증한다.
- `SWTITLESTATUS -> SWTITLEPREPARE -> SWTITLESTATUS -> SWTITLECONVERT -> SWTITLESTATUS -> SWTITLEVERIFY` 순서로 확인한다.
- A3와 A4 각각 대표 `DR_titlea_3rd`를 더블클릭해 GMTITLE 표 편집창이 열리는지 확인한다.
- A3 도면틀 모양이 원래 기대한 DR A3와 맞는지 화면으로 확인한다.
- A4 frame-only가 사라지지 않았는지 확인한다.

2026-07-03 `main-32`/`main-33` 반영:

- `SWTITLESTATUS`에 `구조 판단 요약`을 추가했다.
- A3 도면틀 내부 표제란 후보, A4 실제 선택 bbox 경고, 대상 용지 누락을 한곳에서 요약한다.
- 권장 다음 명령을 `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 중 하나로 직접 안내한다.
- 도면틀 bbox 크기/실제 선택/겹침 위험 로그의 주요 문구를 한국어로 정리했다.
- 구조 판단 요약도 `work/swcad_title_structure_diagnosis_last.txt` 파일에 남긴다.

## 지금 당장 다음 판단

사용자가 보고한 “A3 도면틀과 제목블록이 하나로 합쳐져 보이는 문제”는 `SWTITLECONVERT`를 더 반복해서 해결할 문제가 아니다.

먼저 해야 할 일은:

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLESTATUS
```

이 세 단계로 A3 도면틀 정의 내부의 표제란 형상 후보가 남아 있는지 확인하는 것이다.

그 다음 `SWTITLECONVERT`로 변환을 다시 진행한다.

이 계획의 핵심은 빠르게 지우는 것이 아니라, 어떤 객체를 원본 도면틀, target 도면틀, target 제목블록, 오염된 블록 정의로 볼지 먼저 분리하는 것이다.
