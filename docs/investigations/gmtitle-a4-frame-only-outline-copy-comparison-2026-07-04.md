# GMTITLE A4 Frame-Only LSP 복사본 비교 - 2026-07-04

## 비교 목적

표제란 없는 A4 시트를 처리하기 위해 LSP 복사본을 만들어 테스트했다.

비교 대상:

```text
기준판:
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_a4_frameguard_baseline_260704.lsp

실험판:
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_a4_outline_only_experiment_260704.lsp
```

`work\lsp_compare` 아래 파일은 로컬 실험용이며 Git에는 올라가지 않는다. 이 문서는 같은 실수를 반복하지 않도록 Git에 남기는 비교 기록이다.

## 기준판 동작

기준판 버전:

```text
260704-target-overlap-adopt-main56-a4frameguard
```

동작:

```text
표제란 없는 A4만 남으면 SWTITLECONVERT가 GMTITLE 창을 열지 않고 중단한다.
원본 A4에 없던 DR_titlea_3rd 제목블록을 만들지 않는다.
기존 A4 시트를 삭제하지 않는다.
```

판정:

```text
안전하다.
하지만 A4를 완료 상태로 변환하지는 못한다.
```

## 실험판 변경 내용

실험판 버전:

```text
260704-target-overlap-adopt-main56-a4outline-experiment
```

추가한 내부 흐름:

```text
SWTITLESTATUS:
  표제란 없는 A4가 남으면 READY_FOR_A4_FRAME_ONLY_OUTLINE 표시

SWTITLECONVERT:
  DR_titlea_3rd 제목블록을 만들지 않음
  현재 도면 안의 깨끗한 DR_A4_Outline 블록 정의만 사용
  원본 A4 왼쪽 아래에 DR_A4_Outline만 삽입
  새 도면틀 effective bbox와 raw selection bbox 검사
  통과하면 기존 A4 frame INSERT 삭제
  실패하면 새 도면틀 삭제 후 기존 A4 보존

SWTITLEVERIFY:
  frame-only-outline marker가 있는 A4 도면틀은 제목블록 없는 것이 정상으로 계산
```

## CAD 테스트 결과

테스트 DWG:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

### 1. 로드 확인

CAD에서 실험판을 직접 로드했다.

```text
(load "C:/Users/DR-DESIGN/Documents/CAD tool/work/lsp_compare/swcad_title_scale_a4_outline_only_experiment_260704.lsp")
SWTITLEVERSION
```

결과:

```text
SWTITLE LSP 버전:
260704-target-overlap-adopt-main56-a4outline-experiment
```

### 2. 상태 진단

```text
SWTITLESTATUS
```

핵심 결과:

```text
원본 표제란 시트: 0
원본 도면틀: 2
표제란 없는 도면틀 시트: 2
대상 도면틀 수:
  A2: 1
  A3: 12
  A4: 0

결과:
READY_FOR_A4_FRAME_ONLY_OUTLINE

다음:
SWTITLECONVERT
```

즉, 실험판은 기준판과 다르게 A4 도면틀만 교체하는 단계로 진입할 수 있었다.

### 3. 실제 변환 시도

```text
SWTITLECONVERT
YES
```

실험판은 새 `DR_A4_Outline` 도면틀을 만들었지만, 형상 검사에서 중단했다.

핵심 로그:

```text
원본 A4 범위:
(2492.22576246, 0.42607942) - (2702.22576246, 297.42607942)

새 A4 도면틀 보이는 범위:
(2492.22576246, 0.42607942) - (2702.22576246, 297.42607942)

새 A4 도면틀 raw 선택 범위:
(2492.22576246, 0.42607942) - (3364.48702623, 297.42607942)

raw/effective area ratio:
4.15362507

결과:
ABORT_A4_FRAME_ONLY_OUTLINE_INVALID_GEOMETRY
```

중요한 점:

```text
보이는 A4 크기는 원본과 맞았다.
하지만 CAD가 실제 선택하는 raw bbox가 A4보다 훨씬 넓었다.
실험판은 새 도면틀을 삭제하고 기존 A4를 보존했다.
```

## 비교 결론

현재 기준으로는 기준판이 더 좋다.

이유:

```text
기준판:
  같은 실수를 반복하지 않음
  기존 A4를 안전하게 보존함
  사용자에게 다음 구현 필요 상태를 명확히 알려줌

실험판:
  제목블록을 만들지 않는 방향은 맞음
  하지만 DR_A4_Outline 삽입 결과의 raw 선택 범위가 비정상적으로 큼
  이 상태로 기존 A4를 삭제하면 선택/편집/검증 문제가 다시 생길 수 있음
따라서 아직 원본에 반영하면 안 됨
```

## 추가 probe 결과

이후 읽기 전용 probe를 만들어 현재 작업복사본의 `DR_A4_Outline` block definition을 확인했다.

probe:

```text
work/swtitle_a4_raw_bbox_probe_260704.lsp
```

로그:

```text
work/swtitle_a4_raw_bbox_probe_260704.txt
```

핵심 결과:

```text
DR_A4_Outline definition 안에 A4 밖으로 큰 child INSERT가 있음
child bbox = (0, 0) - (872.26126377, 297)
definition raw bbox = (0, 0) - (872.26126377, 302.7)
raw/expected area ratio = 약 4.23
```

따라서 실험판이 중단한 이유는 단순 좌표 문제가 아니라, 현재 DWG 안의 `DR_A4_Outline` 정의 자체가 raw 선택 범위를 과도하게 키우기 때문으로 본다.

이 결과를 바탕으로 원본 LSP에는 A4 도면틀-only 변환을 바로 넣지 않고, 먼저 `SWTITLESTATUS`에서 `definition raw bbox risk`를 표시하는 guard를 추가했다.

실제 CAD에서 새 guard를 확인했다.

```text
SWTITLECONVERT
Result: ABORT_FRAME_DEFINITION_RAW_BBOX_RISK
DR_A4_Outline raw bbox = (0, 0) - (872.26126377, 302.7)
raw/expected area ratio = 4.2333411
```

따라서 현재 더 좋은 선택은 실험판 A4 outline-only 변환을 바로 채택하는 것이 아니라, production LSP의 `a4defrawguard`로 A4 삭제를 막고 `DR_A4_Outline` 정의 복구/정규화를 다음 단계로 진행하는 것이다.

## 다음 분석 방향

다음 단계는 A4 변환 로직을 더 늘리는 것이 아니라, `DR_A4_Outline`의 raw 선택 범위가 왜 210 x 297보다 크게 잡히는지 먼저 분석하는 것이다.

확인할 것:

```text
1. DR_A4_Outline 블록 정의 내부에 A4 밖 객체가 남아 있는지 확인
2. visible/effective bbox는 맞지만 raw bbox만 커지는 객체가 무엇인지 핸들 단위로 추적
3. SWTITLEPREPARE가 DR_A4_Outline의 raw bbox 원인을 정리할 수 있는지 확인
4. raw bbox 정리 후 실험판 A4 도면틀-only 변환을 다시 실행
```

채택 조건:

```text
새 DR_A4_Outline effective bbox = 원본 A4 bbox
새 DR_A4_Outline raw bbox도 원본 A4 bbox와 거의 같음
기존 A4 frame INSERT 삭제 후 도면 내용 보존
원본에 없던 DR_titlea_3rd 제목블록 생성 없음
SWTITLEVERIFY가 A4 frame-only를 정상 조건으로 계산
```

## 최종 판단

지금은 실험판을 원본 LSP에 합치지 않는다.

현재 원본 `src\tools\gmtitle\swcad_title_scale.lsp`의 A4 guard를 유지하는 것이 더 안전하다. 다음 작업은 `DR_A4_Outline` raw bbox 원인 분석과 정규화다.
