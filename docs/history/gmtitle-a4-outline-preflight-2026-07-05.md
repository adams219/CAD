# GMTITLE A4 outline preflight - 2026-07-05

## 목적

표제란 없는 A4 시트가 남았을 때 `SWTITLESTATUS`는 변환 가능하다고 안내하지만, `SWTITLECONVERT`는 `DR_A4_Outline` 정의가 없어 중단하는 모순을 줄인다.

이번 변경은 A4를 무리하게 성공 처리하는 것이 아니라, 기존 A4 원본 도면틀을 삭제하기 전에 `DR_A4_Outline` 정의가 실제로 안전한지 먼저 확인하게 만드는 작업이다.

## 확인한 원인

현재 작업복사본 로그 기준:

```text
원본 표제란 시트: 0
원본 도면틀: 2
표제란 없는 도면틀 시트: 2
필요 대상 A4: 2
현재 대상 A4: 0
DR_A4_Outline 정의: 없음
```

이 상태에서 기존 코드는 다음처럼 엇갈렸다.

```text
SWTITLESTATUS
  Result: READY_FOR_A4_FRAME_ONLY_OUTLINE

SWTITLECONVERT
  Result: ABORT_A4_FRAME_ONLY_OUTLINE_UNAVAILABLE
  이유: 현재 도면 안의 DR_A4_Outline 정의가 없거나 정규화되지 않음
```

과거 `swtitle_a4_raw_bbox_probe_260704.txt`에는 `DR_A4_Outline`을 단순 import했을 때 raw bbox가 A4보다 훨씬 크게 잡힌 이력도 있다. 따라서 누락된 정의를 곧바로 믿고 기존 A4를 삭제하면 안 된다.

## 변경 내용

LSP 버전:

```text
260705-a4-outline-preflight
```

추가한 판단:

```text
swcad-title-a4-frame-only-outline-definition-status
swcad-title-a4-frame-only-outline-definition-ready-p
swcad-title-a4-frame-only-outline-definition-needed-p
```

새 상태:

```text
WAITING_FOR_A4_FRAME_ONLY_OUTLINE_DEFINITION
NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION
OK_A4_FRAME_ONLY_OUTLINE_DEFINITION_IMPORTED
WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE
ABORT_A4_FRAME_ONLY_OUTLINE_DEFINITION_USER
```

`SWTITLEPREPARE`는 이제 표제란 없는 A4가 남아 있고 `DR_A4_Outline` 정의가 없을 때, 설치 원본 정의를 가져와 테스트할 수 있다.

검사 기준:

```text
DR_A4_Outline block exists
target frame block is not contaminated
definition raw bbox risk is absent
test insert can be created
effective bbox matches A4
raw CAD selection bbox is not much larger than effective A4 bbox
```

검사를 통과하지 못하면:

```text
새로 가져온 DR_A4_Outline 정의는 제거 또는 격리
기존 A4 원본 도면틀은 삭제하지 않음
SWTITLECONVERT는 진행하지 않음
```

## 검증

정적 검증:

```text
git diff --check: pass
LSP parenthesis/string check: Depth=0 Min=0 InString=False
```

CAD 읽기 전용 probe:

```text
명령:
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_actual_workcopy_status_probe.ps1

입력 DWG:
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125 CP_ALL_260704_test.dwg

결과 로그:
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_actual_workcopy_status_a4_preflight_260705.txt
```

확인 결과:

```text
Load result: OK
Loaded version: 260705-a4-outline-preflight
Runtime check completed: yes
```

저장된 probe 복사본에는 아직 A3 native 교체 후보가 남아 있어 전체 다음 단계는 `NEXT_UPGRADE_A3_A4_NATIVE`였다. 하지만 A4 하위 상태 로그는 새 preflight를 통과했다.

```text
Result: WAITING_FOR_A4_FRAME_ONLY_OUTLINE_DEFINITION
A4 frame-only DR_A4_Outline 정의 상태: missing, 대상=DR_A4_Outline
다음: SWTITLEPREPARE를 실행해 DR_A4_Outline 정의를 먼저 가져오고 검증
검증 전에는 기존 A4 도면틀을 삭제하지 않음
```

## 다음 작업

1. 현재 열려 있는 CAD 작업본에서 최신 LSP를 다시 APPLOAD한다.
2. `SWTITLESTATUS`로 A3/A4 native 교체 후보가 남았는지 확인한다.
3. A3 후보가 남아 있으면 `SWTITLECONVERT`로 먼저 정리한다.
4. A3 후보가 0이고 A4 frame-only만 남으면 `SWTITLESTATUS`가 `SWTITLEPREPARE`를 안내하는지 확인한다.
5. `SWTITLEPREPARE`에서 `DR_A4_Outline` 정의 검사를 실행한다.
6. 검사 통과 시 `SWTITLESTATUS` 후 `SWTITLECONVERT`로 A4 도면틀-only 변환을 진행한다.
7. 검사 실패 시 기존 A4를 보존하고, 설치 원본 A4 정의의 raw bbox 원인을 별도 분석한다.

