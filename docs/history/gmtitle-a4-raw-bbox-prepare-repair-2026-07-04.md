# GMTITLE A4 raw bbox PREPARE 복구 반영 - 2026-07-04

## 배경

직전 기준 `main56-a4defrawguard`는 `DR_A4_Outline` 정의 raw bbox가 A4보다 과도하게 큰 상태를 감지하고 `SWTITLECONVERT`를 중단했다.

이 보호장치는 기존 A4 도면틀 삭제를 막는 데는 맞았지만, 다음 단계인 `SWTITLEPREPARE`가 그 raw bbox 위험을 실제 복구 후보로 처리하지는 못했다.

즉 흐름이 아래처럼 멈출 수 있었다.

```text
SWTITLESTATUS
  -> NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX

SWTITLECONVERT
  -> ABORT_FRAME_DEFINITION_RAW_BBOX_RISK

SWTITLEPREPARE
  -> raw bbox 위험 정의를 복구 대상으로 보지 못함
```

## 이번 변경

버전:

```text
260704-target-overlap-adopt-main57-a4rawrepair
```

`SWTITLEPREPARE`가 이제 `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 정의 raw bbox 위험을 정규화 후보 요약에 포함한다.

또한 `swcad-title-frame-def-clean-safe`가 아래 조건을 함께 본다.

```text
1. 원본/source-like child block이 섞인 도면틀 정의
2. raw bbox가 예상 A-size 용지보다 과도하게 큰 도면틀 정의
```

## 안전 기준

사용 중이 아닌 정의만 자동 복구한다.

```text
insert-count = 0
```

이 조건일 때만 기존 `DR_A*_Outline` 정의를 백업 이름으로 바꾸고, 설치 폴더의 원본 정의를 다시 가져온다.

가져온 정의도 raw bbox 위험이 있으면 즉시 롤백한다.

```text
raw-risk-after = yes
rollback = yes
```

## 사용 중인 정의를 바로 바꾸지 않는 이유

이미 도면에 삽입된 `DR_A*_Outline` reference는 제목블록 native link, 배치 위치, 기존 정리 상태와 연결될 수 있다.

그 상태에서 정의를 강제로 바꾸면 다음 문제가 생길 수 있다.

```text
1. 기존 GMTITLE 쌍의 frame/title link가 끊김
2. frame INSERT 이름이 백업 정의로 바뀌면서 검증 수량이 흔들림
3. 이미 정렬된 도면틀 위치가 다시 바뀜
4. A4 frame-only처럼 표제란이 없어야 하는 시트에 새 표제란이 생김
```

그래서 이번 단계에서는 사용 중인 정의는 자동 교체하지 않고 로그에 남긴다.

```text
skip, definition needs repair but is referenced by N insert(s)
```

## 다음 단계

현재 main57은 안전한 1차 복구다.

다음 단계에서 검토할 수 있는 것은 "사용 중인 raw-risk 도면틀 정의"를 안전하게 교체하는 별도 내부 로직이다.

그 경우에도 새 공개 명령은 만들지 않는다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

사용자 흐름은 계속 위 4개로 유지한다.

## 검증 포인트

작업복사본에서 확인할 항목:

```text
SWTITLESTATUS
  DR_A4_Outline definition raw bbox risk 표시

SWTITLEPREPARE
  DR 도면틀 정의 raw bbox 위험 수량 표시
  사용 중이 아닌 위험 정의면 설치 원본 import 시도
  import 후 raw-risk-after가 있으면 rollback

SWTITLESTATUS
  raw bbox 위험이 줄었는지 확인

SWTITLECONVERT
  raw bbox 위험이 남아 있으면 여전히 중단
```

## 현재 검증 상태

현재까지 확인한 것:

```text
git diff --check 통과
공개 명령 surface는 SWTITLESTATUS / SWTITLEPREPARE / SWTITLECONVERT / SWTITLEVERIFY 유지
SWTITLEVERSION 기대 버전 문자열은 main57-a4rawrepair로 갱신
```

주의:

```text
열려 있던 CAD 세션은 여전히 main56-a4defrawguard를 로드한 상태였다.
따라서 main57의 SWTITLEPREPARE 실제 CAD 실행은 아직 완료 검증으로 보지 않는다.
다음 CAD 검증 전에는 반드시 최신 swcad_load.lsp 또는 swcad_title_scale.lsp를 APPLOAD해야 한다.
```

## 중요한 결론

이번 변경은 A4 변환을 무리하게 재개하는 변경이 아니다.

오히려 `SWTITLEPREPARE`가 기존 guard의 다음 행동을 받아서, 안전하게 고칠 수 있는 정의만 고치고 위험하면 롤백하도록 만든 변경이다.
