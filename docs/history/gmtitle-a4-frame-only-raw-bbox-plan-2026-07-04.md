# GMTITLE A4 frame-only raw bbox 해결 계획 - 2026-07-04

## 목적

원본 SolidWorks DWG에 표제란이 없는 A4 시트를 GstarCAD Mechanical GMTITLE 구조로 바꿀 때, 원본에 없던 제목블록을 만들지 않고 도면틀만 안전하게 교체하기 위한 계획이다.

이번 계획은 단기 명령어를 하나 더 만드는 것이 아니다. 기존 GitHub 커밋, 로컬 문서, 실제 CAD 로그를 먼저 기준으로 삼고, 최종 구현은 계속 아래 4개 명령 안에 흡수한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

## 현재 기준

GitHub 원격 이력을 fetch한 뒤 확인한 기준:

```text
branch: codex/gm-title
HEAD: 36183b2 Guard A4 frame-only GMTITLE flow
origin/codex/gm-title: 36183b2 Guard A4 frame-only GMTITLE flow
```

현재 GitHub에 올라간 production LSP는 A4 frame-only에서 안전하게 멈추는 guard 버전이다.

```text
GitHub production LSP version:
260704-target-overlap-adopt-main56-a4frameguard
```

이 계획을 작성하면서 로컬 working tree에는 A4 정의 raw bbox 위험까지 표시하는 진단 guard가 추가됐다.

```text
Local working LSP version:
260704-target-overlap-adopt-main56-a4defrawguard
```

로컬에는 비교용 실험 문서가 아직 미커밋 상태로 남아 있다.

```text
docs/investigations/gmtitle-a4-frame-only-outline-copy-comparison-2026-07-04.md
```

## 이력에서 고정한 금지 사항

아래 방식으로 돌아가지 않는다.

```text
1. A4 frame-only 원본에 DR_titlea_3rd 제목블록을 새로 만들고 완료로 판단
2. raw bbox 경고를 무시하고 기존 A4 원본 도면틀 삭제
3. 스크린샷 좌표 클릭이나 긴 소수점 좌표 수동 입력에 의존
4. A2/A3/A4별 공개 명령을 추가
5. 모양만 보고 SWTITLEVERIFY 없이 완료 선언
6. 도면 내용, 번호, 주석, BOM, 치수를 잔여물로 오판해 삭제
7. GitHub/로컬 문서의 이전 실패 이력을 확인하지 않고 같은 GMTITLE 선택을 반복
```

## 현재 확인된 문제

작업복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

현재 변환 상태:

```text
원본 표제란 시트: 0
원본 도면틀: 2
표제란 없는 도면틀 시트: 2
target frame:
  A2: 1
  A3: 12
  A4: 0
```

즉 A2/A3 쪽은 현재 주 문제가 아니고, 남은 문제는 표제란 없는 A4 2장이다.

## 기준판과 실험판 비교 결론

### 기준판

```text
260704-target-overlap-adopt-main56-a4frameguard
```

동작:

```text
A4 frame-only만 남으면 SWTITLECONVERT가 GMTITLE 창을 열지 않고 중단
원본에 없던 DR_titlea_3rd 제목블록 생성 방지
기존 A4 도면틀 보존
```

판정:

```text
안전하지만 A4 변환은 완료하지 못한다.
현재 production으로 유지한다.
```

### 실험판

```text
260704-target-overlap-adopt-main56-a4outline-experiment
```

동작:

```text
DR_titlea_3rd를 만들지 않음
현재 DWG 안의 DR_A4_Outline 정의를 사용해 도면틀만 삽입
삽입 후 effective bbox와 raw selection bbox를 검사
검사 통과 전에는 기존 A4를 삭제하지 않음
```

CAD 테스트 결과:

```text
원본 A4 bbox:
(2492.22576246, 0.42607942) - (2702.22576246, 297.42607942)

새 A4 effective bbox:
(2492.22576246, 0.42607942) - (2702.22576246, 297.42607942)

새 A4 raw selection bbox:
(2492.22576246, 0.42607942) - (3364.48702623, 297.42607942)

raw/effective area ratio:
4.15362507

결과:
ABORT_A4_FRAME_ONLY_OUTLINE_INVALID_GEOMETRY
```

판정:

```text
방향은 맞다.
하지만 raw 선택 범위가 A4보다 너무 커서 아직 production에 넣으면 안 된다.
실험판은 실패 시 새 도면틀을 삭제하고 기존 A4를 보존했으므로 안전장치는 정상 동작했다.
```

## 핵심 판단

다음 문제는 "A4 변환 명령을 하나 더 만들기"가 아니다.

먼저 확인해야 할 것은 `DR_A4_Outline`의 보이는 범위는 A4와 맞는데 CAD가 선택하는 raw bbox만 4배 이상 크게 잡히는 이유다.

가능한 원인:

```text
1. 현재 작업복사본 안의 DR_A4_Outline 블록 정의가 이전 테스트로 오염됨
2. DR_A4_Outline 정의 안에 A4 밖 숨은 객체, 중첩 INSERT, 빈 객체, 이상 bbox 객체가 있음
3. 설치 원본은 정상인데 현재 DWG에 로드된 정의만 달라짐
4. visible/effective bbox 계산은 정상이나 raw selection bbox가 특정 nested 객체를 포함함
```

따라서 다음 작업은 변환 로직 확장이 아니라, `DR_A4_Outline` 정의의 child entity를 핸들 단위로 추적하는 읽기 전용 probe다.

## 1차 probe 결과

읽기 전용 probe:

```text
work/swtitle_a4_raw_bbox_probe_260704.lsp
```

산출 로그:

```text
work/swtitle_a4_raw_bbox_probe_260704.txt
```

확인된 핵심:

```text
BLOCK DR_A4_Outline
#1 handle=17D84 type=INSERT layer=CON block=... A4 From_HYUN
   bbox=(0, 0) - (872.26126377, 297)
   size=872.26126377 x 297
   OUTSIDE_A4
```

이 `DR_A4_Outline` 정의 안에는 A4 밖으로 크게 잡히는 child INSERT와 다수의 A4 외부 bbox 객체가 있었다.

예:

```text
상위 child INSERT raw width: 872.26126377
내부 frame line/hatch 후보: 315 x 445.5 범위
상단/우측으로 벗어나는 TEXT/LINE 다수
```

따라서 실험판 A4 outline-only 변환이 중단된 직접 원인은 다음으로 정리한다.

```text
새로 삽입한 DR_A4_Outline의 visible/effective bbox는 원본 A4와 맞았다.
하지만 현재 DWG 안의 DR_A4_Outline block definition 자체가 raw 선택 범위를 A4보다 크게 만든다.
이 상태에서 기존 A4를 삭제하면 같은 선택/편집 문제가 반복될 수 있으므로 중단이 맞다.
```

중요:

```text
From_HYUN 이름만 보고 무조건 source-contaminated로 처리하지 않는다.
과거 이력에서 native/install DR 도면틀 안에도 From_HYUN 계열 child가 보인 적이 있다.
이번 보완은 이름 삭제가 아니라 raw bbox/definition geometry 위험을 별도 게이트로 추가하는 방향이어야 한다.
```

## 구현 계획

### 1단계. production guard 유지

현재 GitHub production LSP의 A4 guard는 유지한다.

```text
SWTITLECONVERT가 A4 frame-only에서 GMTITLE 창을 열지 않음
원본 A4에 없던 제목블록을 만들지 않음
기존 A4를 삭제하지 않음
```

이 단계는 이미 GitHub에 올라간 안전 기준이다.

### 2단계. A4 raw bbox 읽기 전용 probe 작성

로컬 work 폴더에 테스트용 probe LSP를 만든다.

목표:

```text
현재 DWG의 DR_A4_Outline 블록 정의 child entity 목록 출력
각 child의 type, layer, block name, handle, bbox 출력
A4 정상 범위 210 x 297 밖으로 나가는 객체 표시
nested INSERT가 있으면 그 내부 후보도 표시
```

산출 로그:

```text
work/swtitle_a4_raw_bbox_probe_260704.txt
```

이 probe는 읽기 전용이어야 하며 도면을 수정하지 않는다.

현재 1차 probe는 완료됐다. 다음에는 이 probe 결과를 `SWTITLESTATUS`와 `SWTITLEPREPARE` 판단으로 흡수할 방법을 설계한다.

### 3단계. 설치 원본과 현재 DWG 정의 비교

비교 대상:

```text
설치 원본:
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A4_Outline.dwg

현재 작업복사본 안의 block definition:
DR_A4_Outline
```

확인할 항목:

```text
설치 원본 DR_A4_Outline도 raw bbox가 큰지
현재 DWG의 DR_A4_Outline만 raw bbox가 큰지
source-like child block이 섞였는지
A4 밖 bbox를 만드는 특정 객체가 있는지
```

### 4단계. 정규화 위치 결정

원인에 따라 처리 위치를 정한다.

현재 DWG 정의만 오염된 경우:

```text
SWTITLEPREPARE에서 DR_A4_Outline 정의를 복구/재가져오기 후보로 표시
YES 확인 후 작업복사본에서만 clean definition으로 교체
```

설치 원본도 raw bbox가 큰 경우:

```text
DR_A4_Outline을 그대로 쓰면 안 됨
effective bbox 기준으로만 검증할지, clean outline-only definition을 별도로 구성할지 결정
단, 새 public command는 만들지 않음
```

특정 숨은/nested 객체가 원인인 경우:

```text
그 객체가 native GMTITLE 동작에 필요한지 먼저 확인
필요 없는 객체라면 SWTITLEPREPARE의 정의 정규화 대상으로 포함
필요한 객체라면 삭제하지 않고 raw bbox 검사 기준을 조정
```

현재 1차 probe 기준으로는 `SWTITLESTATUS`가 `DR_A4_Outline`을 단순 `outline-only`로만 보고 지나가면 안 된다.

추가할 판단:

```text
DR_A4_Outline definition raw bbox risk 있음
또는 target frame raw selection warning 있음
또는 A4 frame-only outline 변환에 사용할 block definition이 A4 기준 bbox를 초과함
```

이 중 하나라도 있으면 `SWTITLECONVERT`가 기존 A4를 삭제하지 않고 `SWTITLEPREPARE` 또는 정의 복구 안내로 멈춰야 한다.

### 4-1단계. 1차 guard 반영 결과

로컬 production LSP에 아래 guard를 반영했다.

```text
LSP version:
260704-target-overlap-adopt-main56-a4defrawguard
```

동작:

```text
SWTITLESTATUS:
  DR_A4_Outline definition raw bbox risk 표시
  NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX 안내

SWTITLECONVERT:
  definition raw bbox risk가 있으면 변환을 시작하지 않음
  ABORT_FRAME_DEFINITION_RAW_BBOX_RISK로 중단
  기존 A4 도면틀 삭제 없음
  GMTITLE 창 진입 없음
```

실제 CAD 작업복사본에서 확인한 결과:

```text
Result:
ABORT_FRAME_DEFINITION_RAW_BBOX_RISK

Detected:
DR_A4_Outline raw bbox = (0, 0) - (872.26126377, 302.7)
raw/expected area ratio = 4.2333411

Outcome:
도면 데이터 변경 없음
기존 A4 삭제 없음
```

### 5단계. 실험판 재검증

정규화 후 실험판 흐름을 다시 work copy에서 테스트한다.

통과 조건:

```text
새 DR_A4_Outline effective bbox = 원본 A4 bbox
새 DR_A4_Outline raw bbox도 원본 A4 bbox와 거의 같음
raw/effective area ratio가 1.6 이하
기존 A4 frame INSERT 삭제 후 도면 내용 보존
원본에 없던 DR_titlea_3rd 제목블록 생성 없음
SWTITLESTATUS에서 A4 target frame 수량이 2로 계산
SWTITLEVERIFY가 A4 frame-only를 정상 조건으로 계산
```

### 6단계. production LSP 반영

실험판이 통과할 때만 원본 LSP에 반영한다.

반영 위치:

```text
SWTITLESTATUS:
  A4 frame-only outline-only 처리 가능 여부를 명확히 표시

SWTITLEPREPARE:
  필요한 경우 DR_A4_Outline definition raw bbox 정규화

SWTITLECONVERT:
  A4 frame-only일 때 title block 없이 도면틀만 교체

SWTITLEVERIFY:
  A4 frame-only는 제목블록이 없어도 정상으로 계산
```

공개 명령은 계속 4개만 유지한다.

## 검증 계획

자동/정적 검증:

```text
git fetch 후 origin/codex/gm-title와 현재 브랜치 비교
SWTITLEVERSION 로드 버전 확인
공개 defun c: 검색으로 4개 workflow 유지 확인
comparison/probe 로그를 docs에 기록
```

CAD 검증:

```text
작업복사본에서만 실행
SWTITLESTATUS
SWTITLEPREPARE    status가 요구할 때만
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLEVERIFY
```

최종 완료 기준:

```text
SWTITLEVERIFY_FINAL_OK
남은 SolidWorks 원본 표제란 후보: 0
남은 SolidWorks 원본 도면틀 후보: 0
frame-only 후보: 0
target sheet counts:
  A2: 1
  A3: 12
  A4: 2
A2/A3 대표 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
A4에는 원본에 없던 별도 제목블록이 생기지 않음
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```

## 다음 작업

1. `DR_A4_Outline` raw bbox probe 결과를 `SWTITLESTATUS` 진단 기준으로 옮긴다.
2. 현재 DWG의 `DR_A4_Outline` 정의 raw bbox 위험을 `outline-only`와 별개로 표시한다.
3. 설치 원본과 현재 DWG 정의를 비교한다.
4. 원인을 문서에 계속 기록한다.
5. 필요한 경우 `SWTITLEPREPARE` 정규화/복구 설계를 먼저 수정한다.
6. 그 뒤에만 A4 outline-only 변환을 production LSP로 옮긴다.
