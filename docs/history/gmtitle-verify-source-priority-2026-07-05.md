# GMTITLE Verify Source Priority - 2026-07-05

## 목적

`SWTITLEVERIFY`가 변환 전 또는 변환 초반 상태에서 A4 frame-only를 먼저 처리하라고 안내하면 사용자가 실제 순서를 헷갈릴 수 있다.

현재 저장된 기본 workcopy는 아직 원본 SolidWorks 표제란/도면틀이 남아 있는 상태다.

```text
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
```

이 상태에서는 A4 frame-only가 감지되더라도 A4를 먼저 처리하면 안 된다.

우선순위는 다음과 같다.

```text
1. A3/A4 native 교체 후보가 있으면 먼저 처리
2. 원본 SolidWorks 표제란/도면틀이 남아 있으면 원본 시트 변환
3. 원본 표제란 시트가 사라진 뒤 A4 frame-only 처리
4. 그 뒤 SWTITLEVERIFY 최종 확인
```

## 변경 내용

LSP 버전:

```text
260705-verify-source-priority-a4stepnote
```

`SWTITLEVERIFY` 실패 안내에 다음 우선순위를 추가했다.

```text
다음 단계 코드: SOURCE_SHEETS_BEFORE_A4_FRAME_ONLY
다음: 아직 원본 SolidWorks 표제란/도면틀이 남아 있으므로 A4 frame-only보다 원본 시트 변환이 먼저입니다.
SWTITLESTATUS로 현재 상태를 확인한 뒤 SWTITLECONVERT로 남은 원본 SolidWorks 시트를 처리하세요.
```

A4 frame-only 안내는 원본 시트가 더 이상 남아 있지 않은 뒤에만 다음 단계로 나오게 했다.

```text
다음 단계 코드: A4_FRAME_ONLY_AFTER_SOURCES
```

## 검증 방법

`actual_workcopy_status_probe.lsp`가 `SWTITLEVERIFY` 요약 로그를 읽고 다음을 확인한다.

```text
verify-source-priority-note-found: yes
verify-a4-frame-only-first-note-found: no
```

`run_main45_verification_suite.ps1`에도 위 두 항목을 기대값으로 추가했다.

## 의미

이 변경은 실제 변환을 완료한 것이 아니다.

다만 변환 전/초반 상태에서 잘못된 다음 단계 안내로 A4를 먼저 건드리는 실수를 줄인다.

최종 완료 조건은 여전히 아래다.

```text
SWTITLEVERIFY_FINAL_OK
원본 표제란/도면틀/frame-only 잔여 0
A2=1, A3=12, A4=2 target 수량 일치
A3/A4 native 교체 후보 0
대표 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창
```
