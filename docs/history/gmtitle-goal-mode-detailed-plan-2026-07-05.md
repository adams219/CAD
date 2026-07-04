# GMTITLE 목표 모드 상세 계획 - 2026-07-05

## 목표

SolidWorks에서 저장한 DWG의 도면틀과 표제란을 GstarCAD Mechanical의 native GMTITLE 구조로 안정 변환한다.

핵심은 새 명령어를 계속 늘리는 것이 아니라, 아래 네 명령 안에서 상태 진단, 준비, 변환, 검증을 끝내는 것이다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

## 현재 기준 이력

현재 브랜치:

```text
codex/gm-title
```

최근 기준 커밋:

```text
6d3eaae Add GMTITLE goal status helper
091775b Document current GMTITLE goal audit
6de3107 Expand GMTITLE static preflight coverage
5cb1e5f Add static GMTITLE preflight checks
48d05fa Allow GMTITLE suite to wait for GstarCAD close
c0af34e Fail fast when full GMTITLE suite sees open GstarCAD
5aab88d Fail fast when GstarCAD probe would reuse open session
0200c4f Reject unsafe A4 outline raw bounds
```

현재 LSP 기준 버전:

```text
GMTITLE LSP: 260705-verify-source-priority-a4stepnote
Loader: 260705-4step-gmtitle-a4-outline-preflight
```

현재 검증 상태:

```text
정적 preflight: PASS
GstarCAD: 열려 있음
hidden verification suite: 아직 미실행/미통과
목표 완료 여부: 미완료
```

GstarCAD가 열려 있는 동안에는 숨김 `/b` CAD suite를 실행하지 않는다. 열린 세션으로 명령이 흘러가거나 기존 명령 대기 상태 뒤에서 멈출 수 있기 때문이다. 이 경우에는 `diagnostics\gmtitle-main45\run_goal_status.ps1`와 `run_static_preflight.ps1`만 신뢰한다.

## 최신 CAD 진행 체크포인트

2026-07-05 07:26 기준 최신 CAD 로그는 아래 상태다.

```text
로그:
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_next_step_last.txt

DWG:
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125 CP_ALL_260704_test.dwg

상태:
NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION

누락 수량:
A4: 필요 2, 현재 0

권장 다음 명령:
SWTITLEPREPARE
```

이 체크포인트는 기본 작업복사본의 변환 전 상태보다 우선한다.
즉 현재 열린 CAD가 이 DWG라면, 다음 작업은 첫 native GMTITLE 생성이 아니라 A4 frame-only 도면틀 정의 준비다.

이 단계의 목표:

```text
DR_A4_Outline 정의를 A4 frame-only 변환에 쓸 수 있는지 확인
raw bbox 위험이 있으면 기존 A4를 삭제하지 않고 중단
원본에 없던 DR_titlea_3rd 제목블록을 A4에 만들지 않음
SWTITLEPREPARE 뒤 SWTITLESTATUS로 다음 단계가 실제로 바뀌었는지 확인
```

이 단계에서 하지 않을 것:

```text
SWTITLECONVERT 반복 실행
A4에 제목블록을 붙여서 억지로 target 수량 맞추기
raw bbox 위험을 무시하고 기존 A4 삭제
설치 원본 DR_A4_Outline을 검증 없이 신뢰
```

## 현재까지 확정된 사실

### 1. A3 제목블록 문제

A3의 `DR_titlea_3rd` 제목블록은 더블클릭 시 GMTITLE 표 편집창이 뜨는 상태까지 확인된 이력이 있다.

다만 A3 도면틀은 CAD에서 여전히 INSERT/block reference처럼 보인다. 이것만으로 실패라고 판단하면 안 된다. GstarCAD의 native GMTITLE 도면틀도 내부적으로 블록 참조로 보일 수 있기 때문이다.

따라서 A3 판단은 아래처럼 나눈다.

```text
제목블록 더블클릭 -> GMTITLE 표 편집창: 제목블록 native 동작 성공
도면틀 선택/편집 -> GMTITLE 도면경계 기능 연결: 도면틀 native 동작 성공
도면틀이 일반 블록 편집만 열림: 도면틀 native 연결 또는 선택 대상 문제
```

### 2. A3 도면틀 안 표제란처럼 보이는 형상

설치 원본 `DR_A3_Outline.dwg`에는 도면틀 내부에 표제란처럼 보이는 native-format 형상이 들어 있을 수 있다.

따라서 아래는 금지한다.

```text
DR_A3_Outline 안에 표제란처럼 보이는 선/문자가 있다는 이유만으로 삭제
별도 DR_titlea_3rd와 겹치는지 확인하지 않고 정리
A3 전용 공개 명령 추가
```

정리 대상은 아래 경우로 제한한다.

```text
source-contaminated 도면틀 정의
별도 DR_titlea_3rd와 실제로 겹쳐 중복 표제란이 되는 native-format 형상
```

### 3. A4 frame-only 문제

원본 A4 2장은 표제란이 없는 도면틀-only 시트다.

따라서 A4에는 원본에 없던 `DR_titlea_3rd` 제목블록을 만들면 안 된다.

A4의 성공 조건은 아래다.

```text
DR_A4_Outline 도면틀만 원본 A4 위치와 크기에 맞게 들어감
새 A4 도면틀의 visible/effective bbox가 원본 A4와 일치
새 A4 도면틀의 raw CAD selection bbox가 과도하게 크지 않음
기존 A4 도면틀은 새 도면틀 검증 후에만 삭제
원본에 없던 제목블록은 생성하지 않음
도면 안 번호, 주석, 치수, 모델 형상은 보존
```

### 4. `DR_A4_Outline` 설치 원본 문제

2026-07-05 probe 결과, 설치 원본에서 가져온 `DR_A4_Outline` 정의는 바로 사용하기 어렵다.

핵심 증거:

```text
Before definition status: missing
Prepare result: OK status=WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE
After definition status: missing
After frame-only-count: 2
```

실패 이유:

```text
테스트 범위: (0, 0) - (210, 297)
raw 범위: (0, 0) - (872.26126377, 302.7)
raw/effective area ratio: 4.2333411
```

즉 보이는 A4 크기는 맞출 수 있지만, CAD가 실제 선택하는 범위가 A4보다 훨씬 크다. 이 상태에서 기존 A4를 삭제하면 선택/편집/검증 문제가 반복된다.

현재 guard는 이 상황에서 기존 A4를 삭제하지 않고 멈추도록 되어 있다. 이것은 실패가 아니라 안전장치가 작동한 것이다.

## 목표 모드 진행 단계

### 단계 1. 상태 기준 고정

항상 최신 work 복사본에서 시작한다.

```text
SWTITLEVERSION
SWTITLESTATUS
```

확인할 것:

```text
work 폴더 복사본 여부
원본 표제란 시트 수
원본 도면틀 수
frame-only 시트 수
A2/A3/A4 예상 수량
대상 GMTITLE 도면틀/제목블록 수량
A3/A4 native 교체 후보 수
A4 DR_A4_Outline 정의 상태
raw bbox 위험 수
권장 다음 명령
```

### 단계 2. A3는 native 교체 후보를 먼저 줄인다

`SWTITLESTATUS`가 A3/A4 native 교체 후보를 표시하면 A4보다 이 후보를 먼저 처리한다.

```text
SWTITLECONVERT
```

처리 후 반드시 다시 상태를 본다.

```text
SWTITLESTATUS
```

성공 판단:

```text
A3/A4 native 교체 후보 수 감소
잘못된 command text 후보 없음
겹친 target pair 없음
도면틀 raw bbox 위험 없음
대표 A3 제목블록 더블클릭 시 GMTITLE 표 편집창
```

### 단계 3. A4는 정의 검증이 먼저다

A4 frame-only만 남았는데 `DR_A4_Outline` 정의가 없거나 위험하면 `SWTITLECONVERT`를 반복하지 않는다.

```text
SWTITLEPREPARE
SWTITLESTATUS
```

현재 2026-07-05 probe 기준으로 설치 원본 direct import는 unsafe다. 따라서 다음 구현 후보는 아래 중 하나를 검증해야 한다.

```text
후보 A: GstarCAD native GMTITLE A4가 만드는 실제 도면틀 정의를 분석한다.
후보 B: 설치 원본 DR_A4_Outline 정의에서 raw bbox를 키우는 객체만 제거/정규화할 수 있는지 검증한다.
후보 C: 원본 A4 frame-only에는 native title이 필요 없으므로, 검증 가능한 outline-only definition을 별도 내부 경로로 만든다.
```

현재 기본 선택은 보수적으로 후보 A 또는 B를 먼저 검증하는 것이다. 후보 C는 가장 빨리 보이지만, 가짜 `DR_A4_Outline`을 만들어 GMTITLE 정의와 충돌할 수 있으므로 마지막 선택지다.

### 단계 4. 변환은 검증 가능한 경우에만 한다

A4 변환은 아래가 모두 참일 때만 진행한다.

```text
DR_A4_Outline definition status = ready
definition raw bbox risk = 0
new frame effective bbox ~= source A4 bbox
new frame raw selection warning = none
source A4 frame-only count > 0
title block creation = none
```

이 조건이 아니면 기존 A4를 삭제하지 않는다.

### 단계 5. 최종 검증

최종 완료는 아래 두 가지 증거가 모두 있어야 한다.

```text
SWTITLEVERIFY_FINAL_OK
대표 A2/A3 제목블록 더블클릭 시 GMTITLE 표 편집창
```

A4 frame-only는 제목블록이 없으므로 더블클릭할 `DR_titlea_3rd`가 없는 것이 정상이다. 대신 `DR_A4_Outline` 수량과 bbox/선택 위험이 검증 기준이다.

## 반복 금지 규칙

아래 상황에서는 같은 명령을 반복하지 않는다.

```text
WAITING_FOR_A4_FRAME_ONLY_OUTLINE_DEFINITION
WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE
ABORT_FRAME_DEFINITION_RAW_BBOX_RISK
ABORT_A4_FRAME_ONLY_OUTLINE_INVALID_GEOMETRY
NEXT_REVIEW_TARGET_FRAME_GEOMETRY
NEXT_REVIEW_TARGET_FRAME_SELECTION
```

이 상태에서는 로그 원인을 먼저 확인하고, 기존 A4를 삭제하지 않는다.

## 다음 구현 방향

다음 실제 작업은 A4 변환 명령 추가가 아니다.

먼저 아래를 검증한다.

```text
1. DR_A4_Outline raw bbox를 키우는 객체 목록을 핸들/타입/레이어/범위로 정리
2. 이 객체들이 설치 원본 native A4에 필요한지, import 부산물인지 분류
3. 제거 가능한 객체만 제거한 definition의 raw/effective bbox 재측정
4. 통과하면 SWTITLEPREPARE 안에 A4 definition normalization을 통합
5. 통과하지 못하면 native GMTITLE A4 생성 경로를 별도로 분석
```

완료 전까지 현재 guard를 유지한다.
