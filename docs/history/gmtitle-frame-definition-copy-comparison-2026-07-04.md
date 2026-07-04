# GMTITLE 도면틀 정의 우선 복사본 비교 - 2026-07-04

## 목적

현재 원본 LSP와 도면틀 정의 우선 실험 복사본을 비교해서, 앞으로 어느 방향으로 구현을 이어갈지 판단한다.

비교 대상:

```text
원본:
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
version: 260703-integrated-flow-main-42

실험 복사본:
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_frame_definition_first_test.lsp
version: 260704-frame-definition-first-test-1
```

GitHub / 로컬 기준:

```text
repo: https://github.com/adams219/CAD.git
branch: codex/gm-title
origin/main, origin/HEAD, main, codex/gm-title: 0121ae1 Clean up GMTITLE command surface
```

`git fetch origin --prune`으로 원격 기준을 다시 확인했고, 현재 로컬 기준과 GitHub 원격 기준은 같다.

## 실험 복사본에서 추가한 내용

원본은 그대로 두고 복사본에만 아래 기능을 추가했다.

### 1. 도면틀 정의 유형 판정

`SWTITLESTATUS` 구조 요약에 아래 분류를 추가했다.

```text
outline-only
embedded-title
contaminated
unknown
```

분류 대상:

```text
DR_A2_Outline
DR_A3_Outline
DR_A4_Outline
```

출력 예:

```text
DR 도면틀 정의 유형:
  DR_A3_Outline: embedded-title, 내장 표제란 후보=10
    이유: 도면틀 정의 내부 표제란 영역에 삭제 검토가 필요한 title-like 형상이 있습니다.
```

### 2. 변환 전 gate

`SWTITLECONVERT` 시작 시 도면틀 정의 유형을 먼저 확인한다.

아래 상태가 있으면 변환을 중단하고 `SWTITLEPREPARE`를 안내한다.

```text
embedded-title
contaminated
```

중단 상태:

```text
ABORT_FRAME_DEFINITION_NOT_NORMALIZED
```

단, `unknown`은 첫 native GMTITLE 전에는 정상일 수 있으므로 중단 조건으로 보지 않는다.

## 정적 테스트 결과

복사본 LSP:

```text
copy balance: Depth=0 MinDepth=0 InString=False
git diff --check -- work/lsp_compare/swcad_title_scale_frame_definition_first_test.lsp: 통과
```

공개 명령 비교:

```text
원본:
  commands=6
  SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERT, SWTITLEVERIFY, SWTITLEVERSION, SWSCALESCAN

실험 복사본:
  commands=6
  SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERT, SWTITLEVERIFY, SWTITLEVERSION, SWSCALESCAN
```

예전 공개 명령 문자열 확인:

```text
SWTITLETRANSFER: 없음
SWTITLEFAST: 없음
SWTITLEA3A4: 없음
SWTITLEFRAMEONLY: 없음
SWTITLESTATUSREFRESH: 없음
SWTITLEMULTIPREVIEW: 없음
```

즉, 이번 복사본은 예전 비교용 LSP와 달리 공개 명령 난립 문제가 다시 생기지 않았다.

## CAD 런타임 읽기 전용 테스트

GstarCAD Mechanical을 `/b` 숨김 실행으로 구동했고, 도면 변환이나 저장은 하지 않았다.

실행 명령:

```text
SWTITLEVERSION
SWTITLESTATUS
SWTITLEVERIFY
```

비교 DWG:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_lsp_compare_main42_260704.dwg
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_lsp_compare_framedef_test_260704.dwg
```

두 파일은 같은 작업복사본에서 복사해 만들었다.

### 원본 main42 결과

```text
Load result: OK
Loaded version: 260703-integrated-flow-main-42
Run: SWTITLEVERSION -> OK
Run: SWTITLESTATUS -> OK, status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY -> OK, status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

구조 요약:

```text
원본 표제란/도면틀: 13 / 15
표제란 없는 도면틀 시트: 2
도면틀 정의 내부 표제란 형상 후보: 전체=0, A3=0, A4=0
대상 도면틀 수량 부족: A2=1, A3=12, A4=2
권장 다음 명령: SWTITLECONVERT - 남은 원본 SolidWorks 시트 변환
```

### 실험 복사본 결과

```text
Load result: OK
Loaded version: 260704-frame-definition-first-test-1
Run: SWTITLEVERSION -> OK
Run: SWTITLESTATUS -> OK, status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY -> OK, status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

구조 요약에는 원본에는 없는 도면틀 정의 유형 판정이 추가됐다.

```text
DR 도면틀 정의 유형:
  DR_A2_Outline: unknown, 내장 표제란 후보=0
    이유: 현재 도면에 이 도면틀 정의가 아직 없습니다. 첫 native GMTITLE 전이면 정상일 수 있습니다.
  DR_A3_Outline: unknown, 내장 표제란 후보=0
    이유: 현재 도면에 이 도면틀 정의가 아직 없습니다. 첫 native GMTITLE 전이면 정상일 수 있습니다.
  DR_A4_Outline: unknown, 내장 표제란 후보=0
    이유: 현재 도면에 이 도면틀 정의가 아직 없습니다. 첫 native GMTITLE 전이면 정상일 수 있습니다.
```

현재 저장된 작업복사본 기준으로는 아직 첫 native GMTITLE 전 상태라 `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 정의가 도면 안에 없다. 따라서 실험 복사본은 이 상태를 `unknown`으로 설명했고, 변환을 막지는 않았다.

## 비교 판단

| 항목 | 원본 main42 | 실험 복사본 |
| --- | --- | --- |
| CAD 런타임 로드 | OK | OK |
| 읽기 전용 명령 실행 | OK | OK |
| 공개 명령 수 | 6개 | 6개 |
| 예전 임시 명령 노출 | 없음 | 없음 |
| 첫 native 전 상태 처리 | 가능 | 가능 |
| A2/A3/A4 도면틀 정의 유형 표시 | 없음 | 있음 |
| embedded-title/contaminated 변환 전 gate | 없음 | 있음 |
| 현재 저장본에서 A3 내장 표제란 재현 검증 | 해당 없음 | 아직 해당 없음 |

## 결론

방향만 놓고 보면 실험 복사본이 더 좋다.

이유:

- A3 문제를 “도면틀 하나가 이상하다”가 아니라 `DR_A*_Outline` 정의 유형 문제로 설명한다.
- 사용자가 다음에 무엇을 해야 하는지 더 빨리 이해할 수 있다.
- 도면틀 정의가 정규화되지 않은 상태에서 `SWTITLECONVERT`가 진행되는 실수를 막을 수 있다.
- 공개 명령 수는 원본과 동일하게 유지되므로 `0121ae1`에서 정리한 명령어 난립 문제를 반복하지 않는다.

다만 아직 바로 원본을 대체했다고 볼 수는 없다.

현재 저장된 테스트 DWG는 첫 native GMTITLE 전 상태라서, A3의 실제 `embedded-title` 상태를 이번 런타임에서 재현하지 못했다. 즉, 이번 테스트가 증명한 것은 다음 두 가지다.

```text
1. 실험 복사본은 문법적으로 깨지지 않고 CAD에서 로드된다.
2. 첫 native 전 상태를 unknown으로 설명하면서 변환 흐름을 막지 않는다.
```

아직 증명하지 못한 것:

```text
1. A3 GMTITLE 생성 후 DR_A3_Outline 안의 내장 표제란을 embedded-title로 정확히 잡는지
2. embedded-title 상태에서 SWTITLECONVERT가 실제로 안전하게 중단하는지
3. SWTITLEPREPARE가 도면 내부 번호/주석/텍스트를 보호하면서 도면틀 정의 안의 표제란만 정리하는지
```

## 추천

다음 단계는 실험 복사본을 바로 원본으로 덮어쓰는 것이 아니라, 아래 순서로 한 번 더 확인하는 것이다.

```text
1. 실험 복사본을 APPLOAD
2. 작업복사본에서 SWTITLESTATUS
3. SWTITLECONVERT로 첫 native GMTITLE 한 장 생성
4. 다시 SWTITLESTATUS
5. DR_A3_Outline이 outline-only / embedded-title / contaminated 중 무엇으로 잡히는지 확인
6. embedded-title이면 SWTITLECONVERT가 바로 진행하지 않고 SWTITLEPREPARE를 요구하는지 확인
7. 이 결과가 맞으면 해당 로직을 원본 LSP로 승격
```

현재 판단:

```text
실험 복사본 = 더 좋은 설계 방향
원본 main42 = 아직 실제 사용 기준
```

즉, 다음 구현은 실험 복사본의 도면틀 정의 유형 판정과 변환 전 gate를 원본에 승격하는 쪽이 맞다. 단, A3 native 생성 후 상태에서 한 번 더 CAD 검증한 뒤 승격하는 것이 안전하다.

## 추가 합성 fixture 검증

저장된 실제 작업복사본 DWG 후보들을 숨김 `/b` 읽기 전용 probe로 검사했지만, 모두 첫 native GMTITLE 전 상태였다.

검사한 후보:

```text
0000_A_DRP125_CP_ALL_260626_active_saved_main35_status_260703.dwg
0000_A_DRP125_CP_ALL_260626_main34_verify_260703.dwg
0000_A_DRP125_CP_ALL_260626_main35_verify_260703.dwg
0000_A_DRP125_CP_ALL_260626_test_workcopy_03_before_swtitleconvert_main1.dwg
swtitle_lsp_compare_main37_260703.dwg
swtitle_prepare_main37_260703.dwg
swtitle_expected_count_unit_check_260703.dwg
```

결과:

```text
DR_A2_Outline: unknown, embedded=0
DR_A3_Outline: unknown, embedded=0
DR_A4_Outline: unknown, embedded=0
```

즉, 예전 로그에 있던 A3 내장 표제란 후보 10개 상태는 현재 저장된 DWG 파일로는 재현되지 않았다.

대신 실험 복사본의 분류 로직 자체를 검증하기 위해 합성 fixture를 만들었다.

테스트 파일:

```text
work/swtitle_framedef_fixture_probe_260704.lsp
work/swtitle_framedef_fixture_probe_260704.scr
work/swtitle_framedef_fixture_probe_260704.dwg
```

fixture 내용:

- `DR_A2_Outline`: 외곽선과 짧은 눈금/좌표 문자만 있는 outline-only 도면틀 정의
- `DR_A3_Outline`: 오른쪽 아래 표제란 영역에 LINE/TEXT를 의도적으로 넣은 embedded-title 도면틀 정의

CAD 런타임 결과:

```text
Load result: OK
Loaded version: 260704-frame-definition-first-test-1
DR_A2_Outline: outline-only, embedded=0, children=<none>
DR_A3_Outline: embedded-title, embedded=5, children=<none>
DR_A4_Outline: unknown, embedded=0, children=<none>
Blocking records: 1
Blocker: DR_A3_Outline / embedded-title
Runtime check completed: yes
```

이 검증으로 확인한 것:

- 외곽선/눈금/짧은 좌표 문자는 보호되어 `outline-only`로 남는다.
- 표제란 영역에 실제 title-like 선/문자가 들어간 A3 정의는 `embedded-title`로 잡힌다.
- `embedded-title`는 변환 전 blocking record로 분류된다.

## 원본 승격

합성 fixture 검증 후 실험 복사본의 핵심 로직을 원본 LSP에 승격했다.

승격된 원본:

```text
src/tools/gmtitle/swcad_title_scale.lsp
version: 260704-frame-definition-first-main-43
```

승격 내용:

- `SWTITLESTATUS` 구조 요약에 DR 도면틀 정의 유형 출력 추가
- `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline`을 `unknown / outline-only / embedded-title / contaminated`로 분류
- `embedded-title` 또는 `contaminated`가 있으면 `SWTITLECONVERT`가 `ABORT_FRAME_DEFINITION_NOT_NORMALIZED`로 중단
- 다음 단계로 `SWTITLEPREPARE`를 안내

정적 검증:

```text
src/tools/gmtitle/swcad_title_scale.lsp Depth=0 Min=0 InString=False
work/lsp_compare/swcad_title_scale_frame_definition_first_test.lsp Depth=0 Min=0 InString=False
```

원본 main43 CAD 런타임 읽기 전용 확인:

```text
Load result: OK
Loaded version: 260704-frame-definition-first-main-43
Run: SWTITLEVERSION -> OK
Run: SWTITLESTATUS -> OK, status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY -> OK, status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

원본 main43 구조 요약에는 새 유형 출력이 포함됐다.

```text
DR 도면틀 정의 유형:
  DR_A2_Outline: unknown, 내장 표제란 후보=0
  DR_A3_Outline: unknown, 내장 표제란 후보=0
  DR_A4_Outline: unknown, 내장 표제란 후보=0
```

원본 main43 `SWTITLEVERIFY` 최종 요약에도 같은 유형과 차단 항목 수가 포함된다.

```text
도면틀 정의 정규화 차단 항목: 0
DR 도면틀 정의 유형:
  DR_A2_Outline: unknown, 내장 표제란 후보=0
  DR_A3_Outline: unknown, 내장 표제란 후보=0
  DR_A4_Outline: unknown, 내장 표제란 후보=0
결과: SWTITLEVERIFY_FINAL_FAIL
```

이 저장본에서 `FAIL`은 정상이다. 첫 native GMTITLE 전 상태라 target 도면틀/제목블록이 아직 없기 때문이다.

원본 main43 합성 fixture 확인:

```text
Load result: OK
Loaded version: 260704-frame-definition-first-main-43
DR_A2_Outline: outline-only, embedded=0, children=<none>
DR_A3_Outline: embedded-title, embedded=5, children=<none>
DR_A4_Outline: unknown, embedded=0, children=<none>
Blocking records: 1
Blocker: DR_A3_Outline / embedded-title
Runtime check completed: yes
```

원본 main43 `SWTITLECONVERT` gate 구조 검증:

```text
has-param-frame-definition-blockers=True
sets-frame-definition-blockers=True
cond-first-frame-definition-blockers=True
applies-abort-status=True
prints-class-records=True
guides-prepare=True
```

원본 main43 `SWTITLESTATUS` 구조 요약 검증:

```text
status-gets-class-records=True
status-gets-blockers=True
status-next-action-prepare=True
status-prints-class-records=True
```

해석:

- `/b` 또는 `SCRIPT` 실행 중 `SWTITLECONVERT`는 기존 안전장치에 의해 대화식 GMTITLE 단계로 들어가지 않고 먼저 중단한다.
- CAD 명령줄에서 사람이 직접 `SWTITLECONVERT`를 실행하는 일반 경로에서는 `frame-definition-blockers`를 계산한다.
- 그 다음 `cond`의 첫 번째 분기가 `frame-definition-blockers`라서, A3/A4 native 교체나 fast batch보다 먼저 도면틀 정의 정규화 필요 여부를 판단한다.
- blocker가 있으면 `ABORT_FRAME_DEFINITION_NOT_NORMALIZED`를 적용하고 `SWTITLEPREPARE`를 안내한다.

원본 main43 `SWTITLECONVERT` gate 런타임 fixture 확인:

테스트 파일:

```text
work/swtitle_convert_gate_fixture_main43_260704.lsp
work/swtitle_convert_gate_fixture_main43_260704.scr
work/swtitle_convert_gate_fixture_main43_260704.dwg
```

fixture는 임시 test copy 안에 아래 정의를 만들었다.

- `DR_A2_Outline`: outline-only
- `DR_A3_Outline`: embedded-title
- `DR_A4_Outline`: unknown

`/b`에서는 실제 대화식 변환이 막히므로, fixture 내부에서만 `swcad-title-script-active-p`를 잠깐 nil로 재정의해 CAD 명령줄 직접 실행 상황을 흉내 냈다. 그 상태에서 `c:SWTITLECONVERT`를 호출했다.

결과:

```text
Load result: OK
Loaded version: 260704-frame-definition-first-main-43
DR_A2_Outline: outline-only, embedded=0
DR_A3_Outline: embedded-title, embedded=4
DR_A4_Outline: unknown, embedded=0
Blocking records before convert: 1
SWTITLECONVERT result: OK
SWTITLECONVERT status: ABORT_FRAME_DEFINITION_NOT_NORMALIZED
Gate matched: yes
Runtime check completed: yes
```

이 검증으로 확인한 것:

- `SWTITLECONVERT`는 대화식 변환 분기보다 먼저 도면틀 정의 blocker를 확인한다.
- `embedded-title`가 있으면 실제 변환을 진행하지 않는다.
- 사용자에게 `SWTITLEPREPARE`를 먼저 안내하는 설계가 런타임에서도 동작한다.
- `SWTITLEVERIFY`도 같은 도면틀 정의 유형과 정규화 차단 항목 수를 최종 요약에 남긴다.

남은 실제 CAD 검증:

```text
1. 원본 main43을 APPLOAD
2. SWTITLEVERSION으로 260704-frame-definition-first-main-43 확인
3. 작업복사본에서 첫 native GMTITLE 생성
4. SWTITLESTATUS로 DR_A3_Outline 유형 확인
5. embedded-title 또는 contaminated가 나오면 SWTITLEPREPARE가 먼저 안내되는지 확인
6. SWTITLEPREPARE 후 A3 중복 표제란이 사라지는지 확인
```
