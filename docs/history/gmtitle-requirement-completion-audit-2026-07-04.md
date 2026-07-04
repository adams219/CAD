# GMTITLE 요구사항별 완료 감사 - 2026-07-04

## 결론

현재 main45 LSP는 4단계 통합 흐름의 코드/문서/읽기 전용 진단 기준을 대부분 만족한다.

하지만 전체 목표는 아직 완료가 아니다. 실제 GstarCAD 대화식 `SWTITLECONVERT`를 작업복사본에서 끝까지 수행하고, `SWTITLEVERIFY_FINAL_OK`와 대표 A2/A3/A4 제목블록 더블클릭 결과가 확인되어야 완료다.

## 현재 기준 파일

```text
LSP: C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
Loader: C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
Version: 260704-frame-definition-classification-main-45
SHA256: BB80F09CFDE8C083231D1106CEAF8C2A6DD83F40F8D8A59D30B295C5FD7A8AF8
```

## 요구사항별 감사

| 요구사항 | 현재 증거 | 판정 |
| --- | --- | --- |
| 사용자 명령은 4단계로 통합 | `rg -F "(defun c:SWTITLE"` 결과가 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY`, 보조 `SWTITLEVERSION`만 표시. `SWSCALESCAN`은 별도 scale 진단 명령 | 충족 |
| 예전 임시 명령은 사용자용 공개 명령이 아니어야 함 | `SWTITLEA3FRAMECLEAN`, `SWTITLECLEANORPHANFRAME`, `SWTITLEFASTSTATUS`, `SWTITLETRANSFERBOOTSTRAPFAST`, `SWTITLEA3A4NEXT`의 공개 `defun c:` 없음. 로드 시 대표 레거시 명령이 nil 처리됨 | 충족 |
| CAD 세션에 남은 예전 명령 때문에 같은 실수를 반복하지 않아야 함 | `work\swtitle_loader_probe_main45_diagnostics.txt`와 `work\swtitle_lsp_copy_compare_current_main45.txt`에서 레거시 샘플 명령이 모두 `no` | 충족 |
| `SWTITLESTATUS`가 현재 DWG의 A2/A3/A4 수량을 표시 | 실제 작업복사본 read-only 진단에서 A2=1, A3=12, A4=2 출력 | 충족 |
| `SWTITLESTATUS`가 기존 SolidWorks 도면틀/표제란 개수를 표시 | `source-title-count=13`, `source-frame-count=15`, `frame-only-count=2` 출력 | 충족 |
| `SWTITLESTATUS`가 GMTITLE 대상 도면틀/제목블록 개수를 표시 | 현재 변환 전 기준 `target-title-count=0`, `target-frame-count=0`, `target-sheet-counts=<none>` 출력 | 충족 |
| `SWTITLESTATUS`가 `DR_A*_Outline` 정의 내부 구조를 분석 | `swcad-title-frame-definition-class-records`가 A2/A3/A4를 `unknown / outline-only / native-format-with-title-geometry / source-contaminated`로 분류. 현재 작업복사본은 첫 native 전이라 A2/A3/A4 모두 `unknown` | 충족 |
| 도면틀 안 표제란 형상 감지 | `swcad-title-frame-embedded-title-records`와 구조 진단 로그가 전체/A3/A4 후보 수를 출력. 현재 작업복사본은 0 | 충족 |
| A4처럼 실제 선택 범위가 용지보다 큰 경우 감지 | `SWTITLESTATUS` 내부 fast/native frame check가 raw bbox, geometry warning, overlap warning을 출력. 현재 작업복사본은 target 0이라 위험 0 | 구현됨, 변환 후 재검증 필요 |
| 결과를 한글로 출력 | GstarCAD 로그 파일을 기본 인코딩으로 읽으면 한글 출력 정상. 예: `권장 다음 명령: SWTITLECONVERT - 남은 원본 SolidWorks 시트 변환` | 충족 |
| `SWTITLEPREPARE`가 DR_A2/A3/A4 공통 도면틀 정의를 검사 | `diagnostics/gmtitle-main45/run_frameclass_common_probe.ps1`의 mixed/all_contaminated/all_native 시나리오가 A2/A3/A4 모두를 같은 분류 함수로 검사 | 충족 |
| 정리 대상은 source 오염 도면틀 정의여야 함 | all_contaminated 시나리오에서 A2/A3/A4 모두 `source-contaminated`로 blocking/cleanup 후보가 됨 | 충족 |
| native A2/A3/A4 내부 title-like 형상을 자동 삭제하면 안 됨 | all_native 시나리오에서 A2/A3/A4 모두 `native-format-with-title-geometry`로 분류되지만 blocking/cleanup 후보는 0 | 충족 |
| 외곽선, 눈금, 좌표 표시 보호 | `swcad-title-frame-embedded-title-protected-p`와 prepare 감사 문서에 보호 기준이 있음 | 구현됨, 실제 YES 정리 후 화면 검증 필요 |
| 정상 `DR_titlea_3rd` 제목블록은 삭제하지 않음 | `work\swtitle_title_protection_fixture_main45_260704.txt`에서 정상 제목블록 보호 확인 | 충족 |
| 작업복사본에서만 변경해야 함 | 기존 apply/prepare 계열 함수들이 work copy/read-only/document guard를 사용. 현재 read-only probe는 도면 변경 없이 수행 | 구현됨 |
| 실행 전 후보 목록과 YES 확인 | 정리 함수들이 후보 출력 후 `YES` 확인 흐름을 가짐. SCRIPT `/b`에서는 `ABORT_PREPARE_SCRIPT_ACTIVE`로 중단 | 구현됨, 실제 interactive YES 정리 검증 필요 |
| `SWTITLECONVERT`가 기존 표제란 텍스트를 추출 | 기존 transfer/finalize 내부 로직이 유지되고 통합 convert에서 호출됨 | 구현됨, 실제 변환 후 속성값 검증 필요 |
| 기존 시트 크기 자동 인식 | read-only status에서 A2=1, A3=12, A4=2 감지 | 충족 |
| 같은 크기별 native GMTITLE 기준 객체 1개 생성 | `SWTITLECONVERT` 내부가 첫 native, missing exemplar, frame-only, A3/A4 native replacement 흐름을 호출 | 구현됨, 실제 대화식 GMTITLE 생성 검증 필요 |
| 나머지 자동 복제/배치 | fast batch/clone 내부 로직은 유지되고 통합 convert에서 호출됨 | 구현됨, 실제 변환 완료 검증 필요 |
| 변환 후 기존 SolidWorks 도면틀/표제란/잔여물 제거 | finalize/cleanup 내부 로직은 유지됨 | 구현됨, 실제 변환 완료 후 원본 후보 0 확인 필요 |
| A2/A3/A4를 임시 명령으로 처리하지 않음 | 공개 명령에서 용지별 명령 제거, `SWTITLECONVERT` 내부 분기로 통합 | 충족 |
| `SWTITLEVERIFY`가 표제란 중복/누락/native-like/고아 도면틀을 검사 | `swcad-title-integrated-verify-final-summary`가 pair, orphan, missing/excess, native-like, sheet count를 요약 | 충족 |
| `SWTITLEVERIFY`가 A2/A3/A4 누락을 확인 | 현재 변환 전 로그에서 A2/A3/A4 모두 부족으로 표시하고 `SWTITLEVERIFY_FINAL_FAIL` 출력 | 충족 |
| 더블클릭 대상 안내 | `SWTITLEVERIFY` 내부 double-click check가 대표 제목블록 확인 대상을 출력 | 구현됨, 실제 더블클릭 동작 확인 필요 |
| 최종 결과 OK/WARN/FAIL | 현재 변환 전 실제 작업복사본은 `SWTITLEVERIFY_FINAL_FAIL` 정상 출력 | 충족 |
| LSP 복사본 비교 | `origin/main` copy는 공개 명령 21개, status timeout. current main45 copy는 4개 workflow 명령, status/verify 완료 | 충족 |

## 현재 실제 작업복사본 상태

`diagnostics/gmtitle-main45/run_actual_workcopy_status_probe.ps1` read-only 진단 기준:

```text
Load result: OK
Loaded version: 260704-frame-definition-classification-main-45
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
frame-definition-blockers: 0
frame-embedded-cleanup-records: 0
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
Runtime check completed: yes
```

해석:

```text
현재 작업복사본은 아직 변환 전이다.
다음 실제 CAD 단계는 SWTITLECONVERT로 첫 native GMTITLE 기준 객체를 만드는 것이다.
```

## 표준 read-only 검증 suite

`diagnostics/gmtitle-main45/run_main45_verification_suite.ps1`를 실행해 아래 네 가지 자동 검증을 한 번에 확인했다.

```text
1. Loader probe: Runtime check completed: yes
2. Current LSP copy compare probe: Runtime check completed: yes
3. Actual work-copy status probe: Runtime check completed: yes
4. Common A2/A3/A4 frame-definition probe:
   mixed: PASS
   all_contaminated: PASS
   all_native: PASS
5. All expected log markers were verified.
```

이 suite는 `work\lsp_compare\swcad_title_scale_current_main45_compare_copy.lsp`를 현재 source LSP에서 다시 복사한 뒤 실행한다. 따라서 "검증한 복사본이 실제 LSP와 달라지는" 실수를 줄인다.
또한 기대 로그 마커가 빠지면 PowerShell 오류로 중단하므로, 단순히 GstarCAD를 실행만 하고 통과로 착각하는 실수도 줄인다.

## 변환 후 최종 완료 게이트

실제 GstarCAD에서 대화식 `SWTITLECONVERT` 흐름을 끝낸 뒤에는 아래를 실행한다.

```text
diagnostics/gmtitle-main45/run_final_completion_gate.ps1
```

이 게이트는 현재 변환 전 작업복사본에서는 실패하는 것이 정상이다. 통과 조건은 아래와 같다.

```text
SWTITLEVERIFY_FINAL_OK
source-title-count: 0
source-frame-count: 0
frame-only-count: 0
frame-definition-blockers: 0
frame-embedded-cleanup-records: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
```

즉, 이 게이트가 통과하고 대표 A2/A3/A4 더블클릭 확인이 끝나기 전에는 목표 완료로 보지 않는다.

## 추가 공통 도면틀 정의 fixture

`diagnostics/gmtitle-main45/run_frameclass_common_probe.ps1`는 합성 테스트 복사본에서 A2/A3/A4 공통 분류 로직을 검증한다.

```text
mixed:
  DR_A2_Outline -> outline-only
  DR_A3_Outline -> native-format-with-title-geometry
  DR_A4_Outline -> source-contaminated
  Scenario result: PASS

all_contaminated:
  DR_A2_Outline -> source-contaminated, cleanup 후보 있음
  DR_A3_Outline -> source-contaminated, cleanup 후보 있음
  DR_A4_Outline -> source-contaminated, cleanup 후보 있음
  Scenario result: PASS

all_native:
  DR_A2_Outline -> native-format-with-title-geometry, cleanup 후보 없음
  DR_A3_Outline -> native-format-with-title-geometry, cleanup 후보 없음
  DR_A4_Outline -> native-format-with-title-geometry, cleanup 후보 없음
  Scenario result: PASS
```

이 fixture는 A3 하나만 임시로 처리하는 방향이 아니라, `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline`을 같은 기준으로 분류하고 `source-contaminated`만 정리 후보로 보내는 현재 방향을 검증한다.

## 아직 완료 증거가 없는 항목

아래는 반드시 실제 GstarCAD 화면에서 확인해야 한다.

```text
1. SWTITLECONVERT로 첫 native GMTITLE 생성
2. 안내된 DR_A2_Outline / DR_titlea_3rd 선택
3. Frame positioning ON, Object move OFF 확인
4. 변환 후 SWTITLESTATUS 재실행
5. 필요한 경우 SWTITLECONVERT 반복
6. SWTITLEVERIFY_FINAL_OK 확인
7. 남은 원본 SolidWorks 표제란 후보 0
8. 남은 원본 SolidWorks 도면틀 후보 0
9. A2/A3/A4 target 수량이 기준 수량과 일치
10. A3 중복 제목블록 없음
11. A4 frame-only 누락 없음
12. 대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
13. 도면 내부 번호/주석/BOM/치수/모델 형상 삭제 없음
```

위 항목이 확인되기 전에는 이 목표를 완료로 표시하지 않는다.
