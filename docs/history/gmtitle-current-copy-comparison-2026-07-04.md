# GMTITLE 현재 원본 / 복사본 비교 - 2026-07-04

## 목적

`SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 네 단계 흐름을 기준으로,
원본 LSP와 테스트 복사본 중 어느 쪽이 현재 목표에 더 맞는지 비교했다.

## 비교 대상

```text
원본:
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
version: 260704-frame-definition-first-main-43

기존 실험 복사본:
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_frame_definition_first_test.lsp
version: 260704-frame-definition-first-test-1

새 현재 원본 복사본:
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_current_main43_compare_copy.lsp
version: 260704-frame-definition-first-main-43
```

새 현재 원본 복사본은 원본과 SHA256 해시가 같았다.

```text
원본 SHA256:
99ABB6DBF8AD802E402BC4AEC163E9B59A4535516B368FB8BB9B2BE30F2DF585

새 현재 원본 복사본 SHA256:
99ABB6DBF8AD802E402BC4AEC163E9B59A4535516B368FB8BB9B2BE30F2DF585

기존 실험 복사본 SHA256:
8B838884856881A986690167D2925F9BB4CD4E04F22189199518450210549338
```

## 정적 비교

세 파일 모두 괄호 균형은 정상이었다.

```text
원본: Depth=0 Min=0 InString=False InComment=False
기존 실험 복사본: Depth=0 Min=0 InString=False InComment=False
새 현재 원본 복사본: Depth=0 Min=0 InString=False InComment=False
```

공개 명령 수는 세 파일 모두 6개였다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
SWTITLEVERSION
SWSCALESCAN
```

하지만 기존 실험 복사본에는 아래 보강이 없다.

```text
swcad-title-frame-definition-blocking-records-by-class
SWTITLEPREPARE 정규화 후보 요약의 "원본 블록이 섞인 도면틀 정의"
SWTITLEPREPARE 내부 "오염된 DR 도면틀 정의 복구" 연결
```

원본과 새 현재 원본 복사본에는 위 보강이 모두 있다.

## GstarCAD 런타임 근거

원본 main43은 기존 읽기 전용 런타임 검증에서 로드와 기본 명령 실행이 확인됐다.

```text
work\swtitle_lsp_compare_main42_260704.txt

Load result: OK
Loaded version: 260704-frame-definition-first-main-43
Run: SWTITLEVERSION -> OK
Run: SWTITLESTATUS -> OK, status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY -> OK, status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

기존 실험 복사본도 기본 로드와 읽기 전용 명령은 통과했다.

```text
work\swtitle_lsp_compare_framedef_test_260704.txt

Load result: OK
Loaded version: 260704-frame-definition-first-test-1
Run: SWTITLEVERSION -> OK
Run: SWTITLESTATUS -> OK, status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY -> OK, status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

원본 main43은 synthetic fixture에서 `DR_A3_Outline` 안에 내장 표제란 형상이 있을 때 변환을 막는 것도 확인됐다.

```text
work\swtitle_convert_gate_fixture_main43_260704.txt

DR_A2_Outline: outline-only, embedded=0
DR_A3_Outline: embedded-title, embedded=4
Blocking records before convert: 1
SWTITLECONVERT status: ABORT_FRAME_DEFINITION_NOT_NORMALIZED
Gate matched: yes
```

또 다른 frame definition fixture에서도 같은 방향이 확인됐다.

```text
work\swtitle_framedef_fixture_probe_main43_260704.txt

DR_A2_Outline: outline-only, embedded=0
DR_A3_Outline: embedded-title, embedded=5
Blocking records: 1
Blocker: DR_A3_Outline / embedded-title
Runtime check completed: yes
```

## 채택하지 않은 추가 fixture

동일한 비교 조건을 만들기 위해 `swtitle_compare_gate_*_260704` 임시 fixture를 새로 만들었지만,
GstarCAD `/b` 실행에서 120초 안에 로그 파일을 만들지 못했다.
같은 테스트는 성공 이력이 있는 DWG 복사본으로도 반복했지만 결과가 같았다.

따라서 이 새 fixture는 비교 근거로 채택하지 않았다.
혼동을 막기 위해 해당 임시 fixture 파일과 DWG 복사본은 삭제했다.
현재 비교 근거는 아래처럼 이미 로그가 남아 있는 검증만 사용한다.

```text
work\swtitle_lsp_compare_main42_260704.txt
work\swtitle_lsp_compare_framedef_test_260704.txt
work\swtitle_convert_gate_fixture_main43_260704.txt
work\swtitle_framedef_fixture_probe_main43_260704.txt
정적 비교: SHA256, 공개 명령 수, helper 함수 존재 여부, 괄호 균형
```

## 판단

현재 기준으로는 원본 main43이 가장 좋다.

이유:

- 기존 실험 복사본은 도면틀 정의 유형 판정과 변환 차단 방향은 맞지만, `SWTITLEPREPARE`가 그 차단 원인을 같은 흐름에서 처리하도록 연결하는 최신 보강이 없다.
- 현재 원본은 기존 실험 복사본의 장점을 흡수했고, `contaminated` 도면틀 정의를 `SWTITLEPREPARE` 후보로 다시 잡는 연결까지 추가됐다.
- 새 현재 원본 복사본은 원본과 해시가 같으므로 별도 우위가 없고, 테스트 백업 용도로만 의미가 있다.

따라서 다음 작업은 기존 실험 복사본을 기준으로 계속 개발하는 것이 아니라, 현재 원본 main43을 기준으로 실제 작업복사본 CAD 테스트를 진행하는 것이다.

## 주의

이번 비교는 LSP 로드, 읽기 전용 상태/검증 명령, synthetic 도면틀 정의 차단을 확인한 것이다.
아직 실제 작업복사본 전체 변환 완료를 증명한 것은 아니다.

최종 완료 증거는 아래가 모두 필요하다.

```text
SWTITLESTATUS가 다음 조치를 정확히 안내
SWTITLEPREPARE가 필요한 정규화 후보를 안전하게 처리
SWTITLECONVERT로 A2/A3/A4 변환 진행
SWTITLEVERIFY 최종 결과 OK 또는 납득 가능한 WARN
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 확인
```
