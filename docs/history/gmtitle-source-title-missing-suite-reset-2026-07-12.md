# GMTITLE source-title-missing 공통 fixture와 전체 suite 복구

날짜: 2026-07-12

제품 LSP 버전: `260712-portable-saveas-offsheet-frame-1`

## 목표

실제 portable 전체 변환은 통과했지만 legacy `run_main45_verification_suite.ps1`는 사람이 계속 저장한 중간 작업본의 과거 상태를 고정값으로 기대했다.

```text
과거 suite 기대: source-title=8, frame-only=2, target=5
현재 실제 판정: source-title=10, frame-only=0, target=5
```

최신 제품은 A4의 실제 제목 텍스트도 A2/A3와 같은 규칙으로 인식한다. 제품을 과거 A4 frame-only 가정으로 되돌리지 않고 테스트 fixture를 현재 정책에 맞게 재설계했다.

## 변경 내용

### 작업본 상태 검사

mutable `test_workcopy_03.dwg`의 정확한 진행 숫자를 더 이상 고정하지 않는다. 대신 다음 불변식을 검사한다.

```text
source-title-count + frame-only-count = source-frame-count
target-title-count = target-frame-count
target-gmtitle-pair-count = target-title-count
SWTITLESTATUS는 ABORT/ERROR가 아님
SWTITLEVERIFY 결과 형식은 FINAL_OK 또는 FINAL_FAIL
```

SCRIPT 안전 중단 probe도 `8/8`, `2/2` 같은 값을 고정하지 않고 모든 source/target/INSERT 수량의 전후 동일성과 `DBMOD=0`을 검사한다.

### 공통 source-title-missing fixture

`source_title_missing_common_probe.lsp`가 disposable DWG의 Model 공간을 비운 뒤 다음 구조를 직접 만든다.

```text
원본 도면틀 INSERT: 1
원본 제목/표제란: 0
대상 GMTITLE INSERT: 0
```

같은 fixture와 runner를 매개변수만 바꿔 사용한다.

```text
A2 / GAP: 누락 정의와 frame-only 1장을 감지
A3 / PREPARE: 설치 원본 DR_A3_Outline 정의를 가져오고 effective 형상 검증
A4 / SCRIPT_GUARD: 정의 준비 후 SCRIPT 모드에서 원본을 보존하고 중단
```

fixture의 source frame 블록명에는 `TITLE`, `GMTITLE`, `FTAP`을 넣지 않는다. 첫 시도에서 `TITLE` 문자열 때문에 도면틀이 제목블록으로 오인된 증거를 반영한 규칙이다.

### 기존 fixture 보강

native adoption fixture는 저수준 `entmake INSERT` 대신 제품과 같은 ActiveX `InsertBlock` 경로를 사용한다. 따라서 실제 `DR_titlea_3rd`의 ATTRIB 11개가 생성되며 필수 태그 누락 0을 확인한 뒤 채택 흐름을 시험한다.

post-first-native marker fixture는 고정 `12장/2장` 대신 실행 전 수량에서 한 장을 제거한 결과를 계산한다. marker-only A2 쌍의 `native-like=0`과 다음 A3 선택을 검사하되, 남은 실제 source 검토가 먼저일 수 있는 현재 상태 우선순위를 허용한다.

## GstarCAD 집중 검증

```text
A2 GAP fixture: PASS
A3 PREPARE fixture: PASS
A4 SCRIPT_GUARD fixture: PASS
native adoption attributes=11, missing-tags=0: PASS
post-first-native dynamic marker gate: PASS
```

## 전체 suite 결과

```text
Generated: 2026-07-12 22:27:40 +09:00
Result: PASS
18 numbered steps: PASS
Worktree evidence hash: a40caed535e44ebd58145d4468737a9dd0eafa874ab493d6c660bf5b33822fc9
```

최종 요약은 로컬 생성 파일에 기록됐다.

```text
work\main56_verification_suite_last_run.txt
```

주요 증거:

```text
Common source-title-missing gap probe (A2 fixture): PASS
Common source-title-missing definition prepare probe (A3 fixture): PASS
Common source-title-missing hidden-script safety probe (A4 fixture): PASS
Native adoption gate comparison probe: PASS
Post-first-native marker gate probe: PASS
A2/A3/A4 native replacement batch guard probe: PASS
All expected log markers were verified.
```

## 결론

A4는 더 이상 main suite의 frame-only 고정 fixture가 아니다. `source-title-missing`은 용지 크기가 아니라 실제 제목 부재로 만든 독립 구조이며, A2/A3/A4 모두 같은 fixture 코드와 같은 제품 경로를 사용한다.

제품 LSP 동작은 이번 suite 복구 과정에서 변경하지 않았다. 변경 범위는 fixture, suite 계약, 정적 검사와 문서다.
