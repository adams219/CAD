# GMTITLE 통합 흐름 완료 감사 - 2026-07-03

이 문서는 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 4단계 목표가 현재 어디까지 증명됐는지 항목별로 남긴다.

목표 완료 여부는 아직 `완료 아님`이다.

원본 LSP는 여러 차례 GstarCAD 읽기 전용 런타임 확인을 통과했고, `260703-integrated-flow-main-38`도 실제 로드와 `SWTITLESTATUS`, `SWTITLEVERIFY` 실행이 확인됐다. 현재 파일 기준은 `260703-integrated-flow-main-42`이며, `main-38`은 `SCRIPT`나 `/b` 자동 실행 중 `SWTITLECONVERT`가 대화식 GMTITLE 창이 필요한 단계로 들어가지 않도록 막는 안전장치 보강 버전이고, `main-39`는 `SWTITLEVERIFY`의 누락 용지 판정을 더 직접적으로 보강한 버전이다. `main-40`은 변환 기준 A2/A3/A4 수량을 target GMTITLE xdata에 기록해서 원본 객체 삭제 후에도 target 수량 부족을 잡는 보강이고, `main-41`은 `SWTITLEVERIFY` 통합 최종 요약을 별도 로그로 남기는 보강이다. `main-42`는 `SWTITLEPREPARE`가 자동 실행 중 YES 확인 대기 상태로 멈추는 것을 막는 보강이다. 다만 실제 변환 완료 증거는 아직 아니다.

2026-07-03 추가 확인으로 원본 LSP와 테스트 복사본 LSP를 같은 저장본에서 복사한 별도 DWG로 나누어 GstarCAD `/b` 읽기 전용 런타임 비교를 수행했다. 두 파일 모두 로드는 성공했지만, 복사본은 여전히 예전 공개 명령과 오래된 검증 코드가 남아 있어 최종 사용 기준으로는 원본 LSP가 더 적합하다는 결론을 유지한다.

추가로 별도 작업복사본에서 `SWTITLESTATUS -> SWTITLEPREPARE -> SWTITLESTATUS -> SWTITLEVERIFY` 런타임 확인을 수행했다. `SWTITLEPREPARE`는 최신 `main-37`에서 오류 없이 실행됐고, 이 기준 복사본에서는 정리 후보 없이 다음 단계가 계속 첫 native GMTITLE 생성으로 유지되는 것을 확인했다.

2026-07-03 추가 확인으로 `main-38`에서 `/b` SCRIPT 상태의 `SWTITLECONVERT` guard를 검증했다. `CMDACTIVE before SWTITLECONVERT: 4` 상태에서 `SWTITLECONVERT`는 `ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE`로 반환했고, guard 상태 일치가 `yes`로 기록됐다. 이어서 일반 읽기 전용 런타임 확인도 `Loaded version`과 `Expected version` 모두 `260703-integrated-flow-main-38`로 통과했다.

2026-07-03 추가 확인으로 `main-39`에서 일반 읽기 전용 런타임 확인을 다시 수행했다. `work/swtitle_runtime_loaded_last.txt` 기준 `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-39`였고, `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY`가 모두 오류 없이 실행됐다. 확인 대상 DWG는 변환 전 저장본 복사본이므로 `SWTITLEVERIFY_FINAL_FAIL`은 정상 진단이다.

2026-07-03 추가 보강으로 `main-40`에서 변환 기준 전체 용지 수량 기록과 target 수량 부족/초과 검증을 추가했다. 이후 `/b` 읽기 전용 런타임 확인에서 `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-40`으로 기록됐고, `SWTITLESTATUS`와 `SWTITLEVERIFY`가 오류 없이 실행됐다. 확인 대상은 변환 전 저장본 복사본이므로 `SWTITLEVERIFY_FINAL_FAIL`은 정상 진단이다.

추가로 `work/swtitle_expected_count_unit_check_260703.txt` 기준 main40 수량 xdata 경로를 별도 숨김 GstarCAD `/b` 런타임 테스트로 확인했다. 테스트는 `SWTITLE_EXPECTED_SHEET_COUNTS`, `COUNT:A2=1`, `COUNT:A3=12`, `COUNT:A4=2` 값을 파싱하고, 임시 POINT 객체에 `SWTITLE_EXEMPLAR` xdata를 기록한 뒤 다시 읽었다. `Parsed A2/A3/A4`, `XData parsed A2/A3/A4`가 모두 `1/12/2`였고 `Result: OK`였다. 이 검증은 기준 수량 저장/읽기 내부 경로 증거이며, 실제 변환 완료 도면 증거는 아니다.

2026-07-03 추가 보강으로 `main-41`에서 `SWTITLEVERIFY` 통합 최종 요약을 `swcad_title_verify_summary_last.txt` 계열 로그로 저장하도록 했다. 저장된 실제 작업복사본 `0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg`를 별도 복사한 `swtitle_current_saved_main41_verify_260703.dwg`에서 `/b` 읽기 전용 검증을 수행했고, `Loaded version`과 `Expected version`은 모두 `260703-integrated-flow-main-41`이었다. 새 요약 로그 `swcad_title_verify_summary_last_runtime_260703.txt`에는 남은 원본 표제란 13개, 원본 도면틀 15개, 대상 도면틀/제목블록 0개, 기준 수량 `A2: 1`, `A3: 12`, `A4: 2`, 결과 `SWTITLEVERIFY_FINAL_FAIL`이 남았다. 이는 저장된 workcopy가 아직 변환 전 상태이며 다음 실제 CAD 단계가 `SWTITLECONVERT`임을 증명한다.

이후 `SWTITLEVERSION` 안내 문구가 실제 기준과 일치하도록 기대 버전 문구를 `260703-integrated-flow-main-41`로 다시 맞췄고, 같은 숨김 GstarCAD `/b` 읽기 전용 검증을 재실행했다. `work/swtitle_runtime_loaded_last.txt` 기준 결과는 다시 `Loaded version: 260703-integrated-flow-main-41`, `Expected version: 260703-integrated-flow-main-41`, `SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE`, `SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL`, `Runtime check completed: yes`였다. 이 재검증은 로드/읽기 전용 실행 증거이며, 실제 변환 완료 증거는 아니다.

## 기준 파일

현재 기준 LSP:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

현재 기준 버전:

```text
260703-integrated-flow-main-42
```

메인 로더:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

로더 기준 버전:

```text
260703-4step-gmtitle
```

실험 복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_integrated_flow_test.lsp
```

판단:

- 실험 복사본은 초기 4단계 흐름 검증에 도움이 됐다.
- 하지만 실험 복사본에는 예전 보조 명령이 공개 명령으로 많이 남아 있다.
- 최종 기준은 원본 LSP `260703-integrated-flow-main-42`이다.

## 정적 검증 결과

2026-07-03 현재 정적 검증:

```text
git diff --check: 통과
src/tools/gmtitle/swcad_title_scale.lsp 괄호 깊이: Depth=0
src/tools/gmtitle/swcad_title_scale.lsp 문자열 상태: InString=False
work/swtitle_readonly_runtime_check_260703.lsp 괄호 깊이: Depth=0
work/swtitle_readonly_runtime_check_260703.lsp 문자열 상태: InString=False
```

상태 코드 한국어 설명은 `swcad-title-result-description`을 통해 보강되어 있지만, 이 항목은 이번 정적 검사에서 별도 자동 누락 검사를 수행하지 않았다.

공개 GMTITLE 변환 명령:

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

보조 읽기/진단 명령:

```text
SWTITLEVERSION
SWSCALESCAN
```

`SWTITLEVERSION`은 로드 확인용이고, `SWSCALESCAN`은 GMTITLE 변환과 별개인 스케일 진단이다.

`swcad_load.lsp`도 최신 GMTITLE LSP를 로드하며, 로드 후 안내 문구는 예전 `SWTITLESCAN/SWTITLEDEBUG`가 아니라 4단계 흐름을 표시하도록 정리했다.

## main-42 요구사항 대조 요약

2026-07-04 `260703-integrated-flow-main-42` 기준 코드/문서/로그 증거:

| 요구사항 | 현재 증거 | 판정 |
| --- | --- | --- |
| 사용자 공개 흐름을 4단계로 통합 | 공개 `c:` 명령은 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY`, 보조 `SWTITLEVERSION`, `SWSCALESCAN`만 남음 | 구현됨 |
| 예전 A3/A4/frame-only 공개 명령 노출 제거 | 원본 LSP/로더/가이드에서 `SWTITLEA3A4NEXT`, `SWTITLEA3A4ALL`, `SWTITLEFASTSTATUS`, `SWTITLETRANSFERFASTBATCH`, `SWTITLEFRAMEONLYAPPLY` 검색 결과 없음 | 구현됨 |
| `SWTITLESTATUS`가 다음 조치를 한국어로 안내 | `swcad-title-integrated-structure-diagnosis`가 A3/A4 구조 판단, A4 frame-only 판단, 누락 대상 용지, 권장 다음 명령을 출력 | 구현됨 |
| `SWTITLEPREPARE`가 공통 도면틀 정의 정규화 | `swcad-title-frame-embedded-title-records`가 `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 계열을 공통 검사하고 보호 조건을 적용 | 구현됨 |
| 외곽선/눈금/좌표/정상 제목블록 보호 | `swcad-title-frame-embedded-title-protected-p`가 target title/frame, GENTITLE marker, frame edge, coordinate tick/text를 보호 | 구현됨 |
| `SWTITLECONVERT`가 용지별 공개 명령 없이 처리 | `swcad-title-integrated-convert`가 남은 원본, frame-only, 첫 native, A3/A4 native 교체를 내부 분기 처리 | 구현됨 |
| `SWTITLEVERIFY`가 OK/WARN/FAIL 요약 | `swcad-title-integrated-verify-final-summary`가 원본 잔여, 중복, 누락, native-like, 속성 문제를 세고 `최종 결과: OK/WARN/FAIL` 출력 | 구현됨 |
| `SWTITLEVERIFY`가 A2/A3/A4 누락 용지를 직접 표시 | `main-39`에서 용지별 대상 도면틀 수, 현재 필요한 대상 용지, 누락된 대상 용지를 최종 요약에 출력하고 필요한 대상 용지가 누락되면 `FAIL` 처리. `main-41` 재검증에서도 A2/A3/A4 target 수량 부족이 `SWTITLEVERIFY_FINAL_FAIL`로 기록됨 | 구현됨, main-41 런타임 재확인 완료 |
| `SWTITLEVERIFY`가 원본 삭제 후에도 기준 수량 부족을 감지 | `main-40`에서 target GMTITLE xdata에 변환 기준 전체 용지 수량을 기록하고, `SWTITLESTATUS`/`SWTITLEVERIFY`가 target 도면틀 수량 부족/초과를 출력. 부족하면 `FAIL` 처리 | 구현됨, 읽기 전용 런타임 확인 완료 |
| 기준 수량 xdata 저장/읽기 내부 경로 | `work/swtitle_expected_count_unit_check_260703.txt`에서 main40 LSP 로드, 수량 파싱, 임시 객체 xdata 기록/재파싱, 부족/초과 감지 모두 `Result: OK` | 내부 경로 런타임 확인 완료 |
| `SWTITLEVERIFY` 통합 최종 요약 파일 로그 | `main-41`에서 `swcad_title_verify_summary_last_runtime_260703.txt` 생성 확인. 저장된 workcopy 복사본 기준 target 0개, A2/A3/A4 수량 부족, `SWTITLEVERIFY_FINAL_FAIL` 기록 | 런타임 확인 완료 |
| 저장된 실제 workcopy의 현재 변환 상태 | `swtitle_current_saved_main41_verify_260703.dwg` 읽기 전용 검증에서 원본 표제란 13개, 원본 도면틀 15개, 대상 GMTITLE 0개 확인 | 아직 변환 전, 다음 단계는 `SWTITLECONVERT` |
| 원본/복사본 비교 | `docs/history/gmtitle-lsp-copy-comparison-2026-07-03.md`에 복사본 32개 공개 명령, 원본 6개 공개 명령 비교와 원본 채택 결론 기록 | 완료 |
| 원본/복사본 런타임 비교 | `work/swtitle_lsp_compare_main37_260703.txt`, `work/swtitle_lsp_compare_testcopy_260703.txt`에서 둘 다 로드/읽기 전용 실행 성공. 원본은 `SWTITLEVERIFY_FINAL_FAIL`, 복사본은 오래된 `FAIL_MISSING_TARGET_GMTITLE_PAIRS` 코드로 종료 | 완료, 원본 채택 |
| 실제 CAD 런타임 로드 | `/b` 읽기 전용 런타임 확인에서 `main-41` 로드, `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY` 실행 확인. `work/swtitle_runtime_loaded_last.txt`에 `Loaded version`과 `Expected version` 모두 `260703-integrated-flow-main-41` 기록 | 로드 검증 완료 |
| `/b`/SCRIPT에서 `SWTITLECONVERT` 자동 실행 방지 | `work/swtitle_convert_guard_main38_260703.txt`에서 `CMDACTIVE before SWTITLECONVERT: 4`, `status=ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE`, `Guard status matched: yes` 확인 | guard 검증 완료 |
| `main-39` 읽기 전용 런타임 확인 | `work/swtitle_runtime_loaded_last.txt`에서 `Loaded version: 260703-integrated-flow-main-39`, `Expected version: 260703-integrated-flow-main-39`, `SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE`, `SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL`, `Runtime check completed: yes` 확인 | 로드/읽기 전용 실행 완료 |
| `main-40` 읽기 전용 런타임 확인 | `work/swtitle_runtime_loaded_last.txt`에서 `Loaded version: 260703-integrated-flow-main-40`, `Expected version: 260703-integrated-flow-main-40`, `SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE`, `SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL`, `Runtime check completed: yes` 확인. 구조 진단 로그에는 변환 기준 전체 용지 수 `A2: 1`, `A3: 12`, `A4: 2`와 target 수량 부족이 출력됨 | 로드/읽기 전용 실행 완료 |
| `main-41` 읽기 전용 런타임 재확인 | `SWTITLEVERSION` 기대 버전 안내 문구를 `main-41`로 맞춘 뒤 `work/swtitle_runtime_loaded_last.txt` 기준 `Loaded version: 260703-integrated-flow-main-41`, `Expected version: 260703-integrated-flow-main-41`, `SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE`, `SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL`, `Runtime check completed: yes` 확인 | 로드/읽기 전용 실행 완료 |
| `main-42` `SWTITLEPREPARE` 자동 실행 대기 방지 | `SWTITLEPREPARE`가 `SCRIPT`/`/b` 실행 상태에서 `ABORT_PREPARE_SCRIPT_ACTIVE`로 중단하도록 보강. YES 확인이 필요한 정리 단계는 CAD 명령줄에서 직접 실행 | 정적 구현 완료, CAD 런타임 재확인 필요 |
| `SWTITLEPREPARE` 런타임 확인 | `work/swtitle_prepare_main37_260703.txt`에서 `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLESTATUS`, `SWTITLEVERIFY`가 모두 OK. 전후 상태는 `NEXT_CREATE_FIRST_NATIVE_GMTITLE` | 준비 단계 런타임 확인 완료 |
| 실제 변환 검증 절차 | `docs/guide/gmtitle-native-frame-upgrade.md`에 `SWTITLECONVERT` 후 반드시 `SWTITLESTATUS`를 다시 확인하는 실전 루프와 확인 로그 목록 추가 | 문서화 완료 |
| 실제 변환 완료 | 변환 전 저장본에서 검증했으므로 `SWTITLEVERIFY_FINAL_FAIL`은 예상 결과. 실제 변환 완료 도면의 OK/WARN 및 더블클릭 검증은 아직 없음 | 미완료 |

따라서 현재 상태는 “4단계 통합 LSP 구조와 비교 결론은 구현/검증됨, 실제 변환 완료 CAD 검증은 아직 남음”이다.

## 목표 문장 기준 재감사

사용자가 제시한 목표 문장을 기준으로 다시 쪼개면 현재 상태는 아래와 같다.

| 목표 요구사항 | 현재 증거 | 판정 |
| --- | --- | --- |
| 용지마다 따로 임시 명령을 만들지 않고 4단계로 통합 | 원본 LSP 공개 명령은 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY`, 보조 `SWTITLEVERSION`, `SWSCALESCAN`만 남음 | 구현됨 |
| `SWTITLESTATUS`가 현재 DWG의 A2/A3/A4, 원본, GMTITLE 대상, DR 도면틀 내부 구조, A4 bbox 위험, 다음 조치를 한국어로 출력 | `swcad-title-integrated-status`와 `swcad-title-integrated-structure-diagnosis`가 해당 내부 진단을 호출하고 구조 판단 로그를 생성함 | 구현됨, 변환 완료 도면 재실행 필요 |
| `SWTITLEPREPARE`가 `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline`을 공통 검사하고 외곽선/눈금/좌표/정상 제목블록을 보호 | `swcad-title-frame-embedded-title-records`, `swcad-title-frame-embedded-title-protected-p`가 공통 도면틀과 보호 조건을 적용함 | 구현됨, 실제 삭제 경로는 작업복사본에서 재확인 필요 |
| 최신 LSP에서 `SWTITLEPREPARE`가 실제 CAD에서 실행됨 | `work/swtitle_prepare_main37_260703.txt`에서 `SWTITLEPREPARE`가 OK로 종료. 이 기준 복사본은 후보 없음 상태라 도면 구조는 변하지 않고 다음 단계가 첫 native GMTITLE 생성으로 유지됨 | 런타임 확인 완료, 실제 후보 삭제 검증은 별도 필요 |
| `SWTITLECONVERT`가 표제란 텍스트 추출, 시트 크기 인식, native 기준 객체, 복제/배치, 원본 잔여물 제거를 내부 흐름으로 처리 | `swcad-title-integrated-convert`가 첫 native, fast batch, frame-only, A3/A4 native 교체를 내부 분기함 | 구현됨, 실제 전체 변환 완료 검증 필요 |
| `SWTITLEVERIFY`가 중복, 내장 표제란, 제목블록 수, A2/A3/A4 누락, 고아 도면틀, 더블클릭 대상, OK/WARN/FAIL을 출력 | `swcad-title-integrated-verify-final-summary`가 `SWTITLEVERIFY_FINAL_OK/WARN/FAIL`과 `최종 결과`를 출력함 | 구현됨, 최종 OK 증거는 아직 없음 |
| 복사본 LSP를 만들어 테스트하고 원본과 비교 | `work/lsp_compare/swcad_title_scale_integrated_flow_test.lsp`와 원본 LSP를 비교했고, 복사본 32개 공개 명령 vs 원본 6개 공개 명령으로 원본 채택 결론 기록 | 완료 |
| 복사본/원본을 실제 CAD 런타임에서 비교 | 두 LSP 모두 `/b` 읽기 전용 실행 성공. 원본은 통합 검증 요약 코드까지 올라오고, 복사본은 예전 내부 검증 코드에서 끝남 | 완료, 원본 채택 |
| A3 표제란 중복이 사라지는지 검증 | 이전 실험 로그에서는 A3 내장 후보를 줄이고 정리한 기록이 있으나, 최신 `main-38`로 저장된 완료 도면에서 재검증한 증거는 없음 | 미완료 |
| A2/A4에도 같은 로직 적용 검증 | 코드 구조는 A2/A3/A4 공통이지만, 실제 완료 도면에서 A4 frame-only 누락/삭제 없음까지 확인한 증거는 아직 없음 | 미완료 |

결론:

- 코드 구조와 문서 흐름은 목표 방향에 맞게 정리됐다.
- 복사본 비교 결과도 원본 LSP가 더 낫다는 쪽으로 확정됐다.
- 아직 목표 완료로 볼 수 없는 이유는 실제 변환 완료 DWG에서 `SWTITLEVERIFY_FINAL_OK`와 대표 `DR_titlea_3rd` 더블클릭 표 편집창 확인이 없기 때문이다.

## 요구사항별 감사

### 1. `SWTITLESTATUS` 상태 진단

요구사항:

- A2/A3/A4 시트 개수 확인
- SolidWorks 원본 도면틀/표제란 개수 확인
- GMTITLE 도면틀/제목블록 개수 확인
- `DR_A*_Outline` 블록 정의 내부 구조 분석
- 도면틀 안 내장 표제란 형상 확인
- A4처럼 실제 선택 범위가 용지보다 큰 경우 감지
- 다음 조치 한국어 안내

현재 증거:

- `swcad-title-integrated-status`가 `swcad-title-fast-status`, `swcad-title-frame-def-check`, `swcad-title-frame-embedded-title-records`, `swcad-title-native-frame-completion-check`, `swcad-title-next-step`을 순서대로 호출한다.
- `swcad-title-single-a4-frame-only-risk-message`가 A4 frame-only bbox 위험을 별도로 감지한다.
- `main-33`에서 `swcad-title-integrated-structure-diagnosis`가 추가되어 A3/A4 구조 판단, A4 실제 선택 bbox 위험, 대상 용지 누락, 권장 다음 명령을 한곳에서 요약한다.
- `main-33`에서 구조 판단 요약은 `work/swcad_title_structure_diagnosis_last.txt` 또는 런타임 접미사 로그로 남도록 추가됐다.
- `/b` 읽기 전용 런타임 확인에서 `main-41` 로드와 `SWTITLESTATUS` 실행, 구조 판단 요약 로그 생성을 다시 확인했다. 이후 `main-42`에서는 `SWTITLEPREPARE` 자동 실행 대기 방지만 추가했다.

판정:

- 코드 구조상 충족.
- `main-41`이 CAD에서 로드되고 읽기 전용 `SWTITLESTATUS`, `SWTITLEVERIFY`를 실행한 증거가 있음. `main-42`의 추가 변경은 `SWTITLEPREPARE` 자동 실행 guard다.
- 테스트 DWG는 변환 전 상태라 검증 결과가 `FAIL`인 것은 정상이며, 상태 진단 기능 자체의 런타임 실행은 증명됨.

### 2. `SWTITLEPREPARE` 도면틀/블록 정의 정규화

요구사항:

- `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 공통 검사
- 도면틀 안 표제란 영역의 선/문자/블록 후보 제거
- 외곽선, 눈금, 좌표 표시 보호
- 정상 `DR_titlea_3rd` 제목블록 보호
- 작업복사본에서만 실행
- 삭제 전 후보 목록과 `YES` 확인

현재 증거:

- `swcad-title-integrated-prepare`가 실수 명령어 텍스트, 도면틀 정의 안 중첩 제목블록, DR 도면틀 내부 표제란 형상, 고아 GMTITLE 도면틀을 한 흐름에서 처리한다.
- `swcad-title-frame-embedded-title-records`는 A2/A3/A4 공통 도면틀 이름을 대상으로 후보를 만든다.
- `swcad-title-frame-embedded-title-protected-p`가 외곽선, 좌표 눈금, 짧은 좌표 표시, `DR_titlea_3rd` 등 보호 대상을 제외한다.
- 정리 함수들은 작업복사본/읽기전용 guard와 `YES` 확인을 사용한다.

판정:

- 코드 구조상 충족.
- 정리 명령이 실제 후보를 삭제하는 경로는 작업복사본/`YES` 확인을 요구하므로 `/b` 읽기 전용 런타임 확인으로는 완료 증거를 만들 수 없다.
- A3 중복 표제란 정리는 이전 CAD 로그에서 검증됐지만, 최신 `main-42`로 실제 변환 완료 도면에서 다시 검증한 증거는 아직 없음.

### 3. `SWTITLECONVERT` 변환 실행

요구사항:

- 기존 SolidWorks 표제란 텍스트 추출
- 시트 크기 자동 인식
- 같은 크기별 실제 native GMTITLE 기준 객체 생성
- 나머지 시트 자동 복제/배치
- 변환 후 기존 SolidWorks 도면틀/표제란/잔여물 제거
- A2/A3/A4를 임시 명령으로 따로 처리하지 않음

현재 증거:

- `swcad-title-integrated-convert`가 다음 순서로 내부 분기한다.
  - A3/A4 native 교체 후보가 있으면 한 장만 `swcad-title-upgrade-native-a3a4-next`
  - 원본이 없고 frame-only만 남으면 `swcad-title-transfer-frame-only-apply`
  - native 기준 객체가 없으면 `swcad-title-transfer-bootstrap-fast`
  - 그 외에는 `swcad-title-transfer-fast-batch`
- A3/A4 교체는 한 번에 한 장만 처리하도록 유지한다.
- GMTITLE 창을 열기 전에 `OPEN` 확인을 요구하는 안전장치가 있다.
- `main-26`에서 A4/frame-only 실패 경로의 한국어 안내를 보강했다.

판정:

- 코드 구조상 4단계 통합 흐름에 맞음.
- 이전 실제 변환 로그 기준으로는 A4 frame-only 2장과 `DR_A4_Outline` native 기준 객체 누락이 남아 있었다.
- 최신 `main-42`로 실제 A4 변환을 완료한 증거는 아직 없음.

### 4. `SWTITLEVERIFY` 최종 검증

요구사항:

- 표제란 중복 확인
- 도면틀 안 내장 표제란 형상 잔여 확인
- GMTITLE 제목블록 개수 확인
- A2/A3/A4 누락 확인
- 고아 도면틀 확인
- 더블클릭 확인 대상 안내
- 최종 결과 `OK / WARN / FAIL` 요약

현재 증거:

- `swcad-title-integrated-verify`가 `swcad-title-gmtitle-verify-all`, `swcad-title-native-frame-completion-check`, `swcad-title-double-click-check`, `swcad-title-integrated-verify-final-summary`를 호출한다.
- 최종 요약은 남은 원본 표제란/도면틀, 실수 텍스트, 내장 표제란 형상, 고아 도면틀, 대상 도면틀/제목블록 수, native-like 상태, 현재 필요한 대상 용지 누락 수를 계산한다.
- 최종 결과는 `SWTITLEVERIFY_FINAL_OK`, `SWTITLEVERIFY_FINAL_WARN`, `SWTITLEVERIFY_FINAL_FAIL`과 `최종 결과: OK/WARN/FAIL`로 출력한다.

판정:

- 코드 구조상 충족.
- 실제 대표 A2/A3/A4 `DR_titlea_3rd` 더블클릭 검증은 최신 `main-42` 기준으로 아직 완료 증거가 없다.
- `/b` 읽기 전용 런타임 확인에서 `SWTITLEVERIFY`는 실행됐지만, 테스트 DWG가 변환 전 저장본이므로 최종 완료 증거로 쓰지 않는다.

## 변환 진행 상태와 로그 주의

이전에 실제 변환을 진행하던 작업복사본 화면/로그 기준으로는 다음 상태까지 확인됐다.

```text
원본 표제란 시트: 0
원본 도면틀: 2
표제란 없는 도면틀 시트: 2
원본 도면틀 크기별 수: A4: 2
DR_A2_Outline native 기준 객체: 있음
DR_A3_Outline native 기준 객체: 있음
DR_A4_Outline native 기준 객체: 없음
결과: WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS
```

즉, 다음 핵심은 A4 frame-only용 `DR_A4_Outline` native 기준 객체를 안전하게 만들고, 남은 A4 시트가 삭제/누락되지 않는지 확인하는 것이다.

주의:

- 이후 `/b` 런타임 확인을 하면서 표준 `swcad_title_*_last.txt` 로그 일부가 저장된 변환 전 테스트 복사본 기준으로 한 번 갱신됐다.
- 따라서 현재 표준 `*_last.txt`만 보고 실제 화면의 변환 진행 상태라고 판단하면 안 된다.
- `main-27`부터는 런타임 확인 상세 로그가 `*_runtime_260703.txt`로 분리된다.
- 실제 변환 진행 상태를 다시 판단하려면 현재 화면의 작업복사본을 저장하거나 새 작업복사본에서 4단계 흐름을 다시 실행한 뒤 그 로그를 기준으로 봐야 한다.

2026-07-03 재확인:

- `work` 폴더의 저장된 DWG들은 모두 2026-07-02 오후 4:31:26 시각의 같은 크기 파일이었다.
- 따라서 현재 디스크에 저장된 DWG 중에는 최신 `main-35` 흐름으로 변환 완료가 증명된 파일이 없다.
- 다음 CAD 검증이 기존 런타임 로그와 섞이지 않도록 아래 전용 작업복사본을 만들었다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_main34_verify_260703.dwg
```

이 파일은 변환 완료 증거가 아니라, `main-34` 당시 실제 변환 검증을 시작하기 위해 만든 기준선 이력이다. 최신 기준선은 아래 `main-35` 항목과 active-saved 항목을 우선한다.

이 전용 복사본에서 읽기 전용 런타임 기준선을 새로 생성했다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_runtime_loaded_main34_verify_260703.txt
```

핵심 결과:

```text
Loaded version: 260703-integrated-flow-main-34
DWG: C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_main34_verify_260703.dwg
Detail log suffix: _main34_verify_260703
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

새 기준선 상세 로그:

```text
work/swcad_title_fast_status_last_main34_verify_260703.txt
work/swcad_title_structure_diagnosis_last_main34_verify_260703.txt
work/swcad_title_gmtitle_verify_all_last_main34_verify_260703.txt
work/swcad_title_native_frame_check_last_main34_verify_260703.txt
work/swcad_title_double_click_check_last_main34_verify_260703.txt
```

기준선 해석:

```text
원본 표제란 시트: 13
원본 도면틀: 15
표제란 없는 도면틀 시트: 2
원본 도면틀 크기별 수: A2=1, A3=12, A4=2
대상 DR_A2/DR_A3/DR_A4 Outline INSERT: 0
대상 DR_titlea_3rd INSERT: 0
현재 필요한 대상 용지 누락: A2, A3, A4
권장 다음 명령: SWTITLECONVERT
```

따라서 이 기준선의 `SWTITLEVERIFY_FINAL_FAIL`은 실패한 구현 증거가 아니다. 아직 변환을 시작하지 않은 작업복사본이므로 target GMTITLE 도면틀/제목블록이 0개라는 정상 진단이다.

`SWTITLEPREPARE` 후보도 별도 읽기 전용 preflight로 확인했다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_prepare_preflight_main34_verify_260703.txt
```

결과:

```text
Loaded version: 260703-integrated-flow-main-34
DWG: C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_main34_verify_260703.dwg
Command text residue count: 0
Frame definition nested title count: 0
DR frame embedded title geometry count: 0
Orphan target frame count: 0
Result: OK_NO_PREPARE_CANDIDATES
```

해석:

- 이 새 검증 복사본에서는 `SWTITLEPREPARE`가 정리할 후보가 없다.
- 따라서 실제 다음 단계는 `SWTITLEPREPARE`를 반복 실행하는 것이 아니라 `SWTITLECONVERT`로 첫 native GMTITLE 생성을 시작하는 것이다.
- 다만 사용 흐름 문서상으로는 사용자가 `SWTITLEPREPARE`를 한 번 실행해도 후보 없음으로 통과하는 상태여야 한다.

## 아직 필요한 완료 증거

완료 판정을 위해 필요한 증거:

1. GstarCAD에서 원본 LSP `260703-integrated-flow-main-39`가 로드된 상태.
2. 저장된 작업복사본에서 `SWTITLESTATUS` 실행 로그 생성.
3. `SWTITLEPREPARE`가 후보를 안전하게 보여주거나 후보 없음으로 통과.
4. `SWTITLECONVERT`가 필요한 첫 native GMTITLE 기준 객체와 남은 시트를 처리.
5. A4 frame-only 시트가 삭제/누락되지 않고 처리됨.
6. `SWTITLEVERIFY` 최종 결과가 `OK`, 또는 남은 WARN이 수동 더블클릭 확인만 요구.
7. 대표 `DR_titlea_3rd` 더블클릭 시 GMTITLE 표 편집창이 열림.

2026-07-03 추가 런타임 증거:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_runtime_loaded_last.txt
```

해당 파일의 핵심 내용:

```text
Load result: OK
Loaded version: 260703-integrated-flow-main-26
Expected version: 260703-integrated-flow-main-26
DWG: C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_runtime_check_260703_workcopy.dwg
Run: SWTITLEVERSION
Result: OK SWTITLEVERSION status=<status variable missing>
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

해석:

- `main-26` 로드와 읽기 전용 명령 실행은 GstarCAD 런타임에서 증명됐다.
- 테스트 파일은 저장된 `0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg`를 복사해 만든 파일이다.
- 이 저장본은 아직 변환 전 상태라 원본 표제란 13장, 원본 도면틀 15개, target GMTITLE 도면틀 0개로 진단됐다.
- 따라서 `SWTITLEVERIFY_FINAL_FAIL`은 정상적인 진단이다. 실패 원인은 LSP 로드 실패가 아니라 테스트 DWG에 아직 native GMTITLE target frame/title이 없기 때문이다.
- 현재 화면에 열려 있던 작업복사본의 unsaved 변환 상태와 디스크 저장본 상태가 다를 수 있으므로, 실제 변환 완료 검증은 별도로 저장된 작업복사본 또는 사용자가 명시적으로 저장한 상태에서 다시 해야 한다.

2026-07-03 `main-27` 보강:

- `*swcad-title-log-file-suffix*` 옵션을 추가했다.
- `work/swtitle_readonly_runtime_check_260703.lsp`는 이 값을 `_runtime_260703`으로 설정한다.
- 이후 `/b` 런타임 확인에서 생성되는 상세 로그는 일반 `swcad_title_*_last.txt` 대신 `swcad_title_*_last_runtime_260703.txt` 형태로 분리된다.
- 따라서 런타임 확인이 현재 사용자가 보고 있던 작업 로그를 덮어쓰는 혼동을 줄인다.

`main-27` 런타임 확인 결과:

```text
Load result: OK
Loaded version: 260703-integrated-flow-main-27
Expected version: 260703-integrated-flow-main-27
Detail log suffix: _runtime_260703
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

생성된 전용 상세 로그:

```text
swcad_title_fast_status_last_runtime_260703.txt
swcad_title_gmtitle_verify_all_last_runtime_260703.txt
swcad_title_native_frame_check_last_runtime_260703.txt
swcad_title_double_click_check_last_runtime_260703.txt
swcad_title_next_step_last_runtime_260703.txt
swcad_title_frame_def_check_last_runtime_260703.txt
```

해석:

- `main-27` 로드와 읽기 전용 검증 실행은 증명됐다.
- 테스트 DWG는 여전히 저장된 변환 전 복사본이라 `SWTITLEVERIFY_FINAL_FAIL`이 정상이다.
- 실제 변환 완료 여부는 아직 증명되지 않았다.

2026-07-03 `main-28` 보강과 런타임 확인:

- 공개 흐름 중 사용자에게 직접 보일 수 있던 남은 영어 안내 문장을 한국어로 정리했다.
- 변환 로직은 바꾸지 않고 안내 문자열과 현재 기준 버전만 갱신했다.
- `/b` 읽기 전용 런타임 확인으로 `main-28` 로드와 `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY` 실행을 확인했다.

`main-28` 런타임 확인 결과:

```text
Load result: OK
Loaded version: 260703-integrated-flow-main-28
Expected version: 260703-integrated-flow-main-28
Detail log suffix: _runtime_260703
Run: SWTITLEVERSION
Result: OK SWTITLEVERSION status=<status variable missing>
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

해석:

- `main-28` 로드와 읽기 전용 검증 실행은 증명됐다.
- 테스트 DWG는 저장된 변환 전 복사본이라 `SWTITLEVERIFY_FINAL_FAIL`이 정상이다.
- 실제 변환 완료 여부는 아직 증명되지 않았다.

2026-07-03 `main-29` 보강:

- `main-28` 로그에서 `Other non-target title-like inserts`, `Title inserts`, `source sheet`, `paper/frame`, `Remaining 원본 ...`처럼 남던 잔여 영어/부분 번역 문구를 한국어로 더 정리했다.
- 현재 기준 버전은 `260703-integrated-flow-main-29`이다.
- `/b` 읽기 전용 런타임 확인으로 `main-29` 로드와 `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY` 실행을 확인했다.

`main-29` 런타임 확인 결과:

```text
Load result: OK
Loaded version: 260703-integrated-flow-main-29
Expected version: 260703-integrated-flow-main-29
Detail log suffix: _runtime_260703
Run: SWTITLEVERSION
Result: OK SWTITLEVERSION status=<status variable missing>
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

해석:

- `main-29` 로드와 읽기 전용 검증 실행은 증명됐다.
- 테스트 DWG는 저장된 변환 전 복사본이라 `SWTITLEVERIFY_FINAL_FAIL`이 정상이다.
- 실제 변환 완료 여부는 아직 증명되지 않았다.

2026-07-03 `main-30` 보강:

- `main-29` 로그에서 `Target frame block definitions`, `exists=no`, `children=`, `old-source-like=`, `bbox-warnings=`, `native GMTITLE 제목블록 존재: no`처럼 남던 진단 문구를 한국어로 더 정리했다.
- 이후 최신 기준은 `main-42`까지 진행됐고, `main-41`의 CAD 런타임 로드 확인은 완료됐다. 실제 변환 완료 검증은 아직 필요하다.

2026-07-03 `main-31` 보강:

- 부분 번역 순서 때문에 남던 `존재: no/yes` 조각을 `존재: 아니오/예`로 정리했다.
- 이후 `main-32`에서 `SWTITLESTATUS` 구조 판단 요약과 A3/A4 판단 안내를 추가했다.
- 이후 `main-33`에서 구조 판단 요약도 별도 로그로 남기도록 했다.
- 현재 기준 버전은 `260703-integrated-flow-main-42`이다.
- `main-38`은 자동 실행 중 대화식 GMTITLE 단계 진입을 막는 안전장치 보강이고, `main-39`는 `SWTITLEVERIFY`의 누락 대상 용지 표시와 FAIL 판정을 보강했다. `main-40`은 기준 수량 xdata를, `main-41`은 최종 요약 로그를, `main-42`는 `SWTITLEPREPARE` 자동 실행 대기 방지를 보강했다. 실제 변환 완료 검증은 아직 필요하다.
- `main-34`의 CAD 런타임 로드 확인은 완료됐다.
- 아직 실제 변환 완료 검증은 필요하다.

`main-34` 런타임 확인 결과:

```text
Loaded version: 260703-integrated-flow-main-34
Expected version: 260703-integrated-flow-main-34
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

구조 판단 요약 로그:

```text
work/swcad_title_structure_diagnosis_last_runtime_260703.txt
```

이 런타임 검증은 변환 전 저장본에서 수행됐으므로 `SWTITLEVERIFY_FINAL_FAIL`은 예상 결과다. 실제 변환 완료 증거로 쓰지는 않는다.

## 다음 실행 순서

작업복사본 DWG에서:

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp

SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLEVERIFY
```

`SWTITLECONVERT`에서 GMTITLE 창이 열리면 반드시 확인한다.

```text
용지: 로그가 요구한 DR_A*_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

일반 A3/A4, ISO 제목블록, Object move ON이면 OK를 누르지 않고 취소한다.

권장 테스트 대상:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_main35_verify_260703.dwg
```

이 파일에서 새로 생성되는 `work/swcad_title_*_last.txt` 로그를 기준으로 실제 변환 완료 여부를 판단한다. `_runtime_260703` 접미사 로그는 LSP 로드 확인용이며 실제 변환 완료 증거로 쓰지 않는다.

새 전용 기준선 로그는 `_main35_verify_260703` 접미사를 사용한다. 이후 대화식 `SWTITLECONVERT` 검증을 진행하면 이 접미사 로그가 아니라 일반 `work/swcad_title_*_last.txt` 또는 새로 지정한 검증 접미사 로그의 DWG 경로를 먼저 확인한다.

## 2026-07-03 main-35 보강

`260703-integrated-flow-main-35`는 변환 로직을 바꾸지 않고, 사용자가 실제로 보는 `SWTITLECONVERT`/`GMTITLE` 실행 직전 안내를 한국어 원문으로 더 정리한 버전이다.

보강 이유:

- 이전 이력에서 `GMTITLE` 창이 일반 A3/A4 또는 ISO 제목블록 기본값으로 열리는 실수가 반복됐다.
- `Object move`가 켜진 상태로 진행하면 도면 내용이 움직일 수 있었다.
- 프롬프트가 영어로 섞이면 어떤 값을 골라야 하는지 다시 헷갈릴 수 있었다.

따라서 `main-35`에서는 첫 native GMTITLE, A3/A4 native 교체, A4 frame-only 경로에서 아래 안내를 더 직접적으로 표시한다.

```text
용지/형식: 로그가 요구한 DR_A*_Outline
제목블록: DR_titlea_3rd
켜둘 옵션: Frame positioning
꺼둘 옵션: Object move
왼쪽 아래 배치점: 자동 입력 또는 프롬프트 발생 시 기준점
```

정적 확인:

```text
src\tools\gmtitle\swcad_title_scale.lsp Depth=0 Min=0 InString=False
git diff --check: 통과
공개 c: 명령: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERT, SWTITLEVERIFY, SWTITLEVERSION, SWSCALESCAN
```

아직 실제 변환 완료 증거는 아니다. 다음 완료 증거는 작업복사본에서 `SWTITLEVERIFY_FINAL_OK` 또는 수동 더블클릭만 남은 WARN과 대표 `DR_titlea_3rd` 더블클릭 확인이다.

2026-07-03 추가 런타임 확인:

`main-35` 전용 기준선 복사본과 읽기 전용 런타임 스크립트를 만들었다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_main35_verify_260703.dwg
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_readonly_runtime_check_main35_verify_260703.scr
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_readonly_runtime_check_main35_verify_260703.lsp
```

GstarCAD `/b` 읽기 전용 런타임 확인 결과:

```text
Loaded version: 260703-integrated-flow-main-35
Expected version: 260703-integrated-flow-main-35
Commands requested: SWTITLEVERSION, SWTITLESTATUS, SWTITLEVERIFY
SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

생성된 주요 로그:

```text
work/swcad_title_fast_status_last_main35_verify_260703.txt
work/swcad_title_structure_diagnosis_last_main35_verify_260703.txt
work/swcad_title_gmtitle_verify_all_last_main35_verify_260703.txt
work/swcad_title_native_frame_check_last_main35_verify_260703.txt
work/swtitle_runtime_loaded_main35_verify_260703.txt
```

기준선 해석:

```text
원본 표제란 시트: 13
원본 도면틀: 15
표제란 없는 도면틀 시트: 2
원본 도면틀 크기별 수: A2=1, A3=12, A4=2
도면틀 정의 내부 표제란 형상 후보: 0
도면틀 선택/형상 위험: 0
대상 DR_A2/DR_A3/DR_A4 Outline INSERT: 0
대상 DR_titlea_3rd INSERT: 0
현재 필요한 대상 용지 누락: A2, A3, A4
권장 다음 명령: SWTITLECONVERT
```

따라서 `SWTITLEVERIFY_FINAL_FAIL`은 `main-35` 실패가 아니다. 아직 변환 전 기준선 복사본이라 대상 GMTITLE 도면틀/제목블록이 0개라는 정상 진단이다. 실제 완료 증거는 이후 같은 작업복사본에서 `SWTITLECONVERT`로 첫 native GMTITLE을 만들고, 다시 `SWTITLESTATUS`/`SWTITLEVERIFY`를 실행한 결과로 판단한다.

## 2026-07-03 저장된 활성 작업복사본 재확인

현재 GstarCAD 화면에는 아래 도면이 열려 있었다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

Computer Use 입력은 `press_key` 단계에서 두 번 타임아웃되어 CAD 창에 직접 명령을 넣는 방식은 중단했다. 같은 실수를 반복하지 않기 위해, 현재 열린 CAD 창을 더 조작하지 않고 디스크에 저장된 DWG를 별도 복사해 읽기 전용 `/b` 검증을 수행했다.

검증 복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_active_saved_main35_status_260703.dwg
```

실행 스크립트:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_readonly_runtime_check_active_saved_main35_260703.scr
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_readonly_runtime_check_active_saved_main35_260703.lsp
```

핵심 런타임 결과:

```text
Loaded version: 260703-integrated-flow-main-35
Expected version: 260703-integrated-flow-main-35
DWG: C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_active_saved_main35_status_260703.dwg
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

상세 로그 기준:

```text
원본 표제란 시트: 13
원본 도면틀: 15
표제란 없는 도면틀 시트: 2
원본 도면틀 크기별 수: A2=1, A3=12, A4=2
도면틀 정의 내부 표제란 형상 후보: 0
도면틀 선택/형상 위험: 0
native GMTITLE 제목블록: 없음
대상 DR_A2/DR_A3/DR_A4 Outline INSERT: 0
대상 DR_titlea_3rd INSERT: 0
현재 필요한 대상 용지 누락: A2, A3, A4
권장 다음 명령: SWTITLECONVERT
```

해석:

- 저장된 `test_workcopy_03` 기준으로는 아직 실제 native GMTITLE 기준 객체가 없는 변환 전 상태다.
- 화면에 보이던 이전 변환 흔적은 저장되지 않은 CAD 상태였거나, 디스크 저장본과 다른 시점의 상태일 수 있다.
- 따라서 다음 실제 검증은 저장할 작업복사본을 명확히 정한 뒤 `SWTITLECONVERT`로 첫 native GMTITLE을 만들고, 즉시 `SWTITLESTATUS`/`SWTITLEVERIFY`를 다시 실행해 판단해야 한다.
- 숨김 GstarCAD 검증 프로세스는 종료했고, 사용자가 열어둔 기존 CAD 프로세스는 유지했다.

## 2026-07-03 main-36 보강

`260703-integrated-flow-main-36`은 변환 로직을 바꾸지 않고, 사용자가 직접 보게 될 안전 안내 문구를 한국어로 더 정리한 버전이다.

보강 내용:

- native GMTITLE이 원본 도면틀과 떨어진 위치에 생성되어 LISP MOVE 정렬이 필요한 경우, 왜 신뢰하지 않는지 한국어로 출력한다.
- 신뢰하지 않는 새 GMTITLE INSERT를 삭제하고 기존 SolidWorks/GMTITLE 쌍을 보존한다는 안내를 한국어로 출력한다.
- A3/A4 native 교체 사전 확인에서 “한 번에 한 시트만 교체”, “일반 A3/A4 또는 ISO 기본값이면 OK 금지”, “필수 선택: DR 용지 + DR_titlea_3rd”를 한국어로 출력한다.
- `OPEN`을 입력하지 않아 GMTITLE 창을 열지 않았을 때도 한국어로 기록한다.

COM/자동 입력 경로 확인:

- GstarCAD COM ProgID 후보는 `Gcad.Application`, `Gcad.Application.24`, `GStarCAD.Application`, `GStarCAD.Application.24`로 확인됐다.
- 실행 중인 GstarCAD에 `GetActiveObject`로 붙는 시도는 모두 실패했다.
- Computer Use 입력도 `press_key` 단계에서 반복 타임아웃됐다.
- 따라서 현재 안정 경로는 좌표 클릭/COM 자동 진행이 아니라, CAD 명령줄에서 사용자가 `SWTITLECONVERT`를 직접 입력하고 GMTITLE 창에서 필요한 값을 확인하는 방식이다.

main36 읽기 전용 런타임 확인:

```text
Loaded version: 260703-integrated-flow-main-36
Expected version: 260703-integrated-flow-main-36
DWG: C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_active_saved_main35_status_260703.dwg
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

상세 로그 기준:

```text
원본 표제란 시트: 13
원본 도면틀: 15
표제란 없는 도면틀 시트: 2
원본 도면틀 크기별 수: A2=1, A3=12, A4=2
도면틀 정의 내부 표제란 형상 후보: 0
도면틀 선택/형상 위험: 0
native GMTITLE 제목블록: 없음
현재 필요한 대상 용지 누락: A2, A3, A4
권장 다음 명령: SWTITLECONVERT
```

해석:

- main36 LSP 로드와 읽기 전용 `SWTITLESTATUS`/`SWTITLEVERIFY` 실행은 GstarCAD 런타임에서 확인됐다.
- 저장된 활성 작업복사본 기준으로는 아직 첫 native GMTITLE 기준 객체가 없다.
- `SWTITLEVERIFY_FINAL_FAIL`은 구현 실패가 아니라 변환 전 저장본이라는 정상 진단이다.
- 실제 완료 증거는 여전히 `SWTITLECONVERT`로 첫 native GMTITLE을 만든 뒤의 새 `SWTITLESTATUS`/`SWTITLEVERIFY`와 대표 `DR_titlea_3rd` 더블클릭 확인이다.

## 2026-07-03 main-37 보강

`260703-integrated-flow-main-37`은 변환 로직을 바꾸지 않고, 검증/더블클릭/A3-A4 native 교체 로그에 남던 사용자 노출 영어 라벨을 한국어 치환 테이블로 더 보강한 버전이다.

보강 내용:

- `Target frame block`, `Title attributes`, `Native GMTITLE abort reason`, `Frame geometry warning`처럼 검증 로그에 직접 보일 수 있는 라벨을 한국어로 보강했다.
- `Old cloned title deleted`, `Old cloned/untrusted frame deleted`, `Remaining A3/A4 native upgrade candidates after batch`처럼 A3/A4 교체 로그의 직접 라벨을 한국어로 보강했다.
- 기능 흐름과 공개 명령 표면은 그대로 유지했다.

main37 읽기 전용 런타임 확인:

```text
Loaded version: 260703-integrated-flow-main-37
Expected version: 260703-integrated-flow-main-37
DWG: C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_runtime_check_260703_workcopy.dwg
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

해석:

- main37 LSP 로드와 읽기 전용 `SWTITLESTATUS`/`SWTITLEVERIFY` 실행은 GstarCAD 런타임에서 확인됐다.
- 확인 대상 DWG는 변환 전 저장본이므로 `SWTITLEVERIFY_FINAL_FAIL`은 정상 진단이다.
- 실제 완료 증거는 여전히 `SWTITLECONVERT`로 첫 native GMTITLE을 만든 뒤의 새 `SWTITLESTATUS`/`SWTITLEVERIFY`와 대표 `DR_titlea_3rd` 더블클릭 확인이다.

## 2026-07-03 main-38 보강

`260703-integrated-flow-main-38`은 기능 흐름을 넓히지 않고, 자동 실행 중 변환 명령이 위험한 대화식 GMTITLE 단계로 들어가는 것을 막는 안전장치를 보강한 버전이다.

보강 내용:

- `SWTITLECONVERT` 공개 명령 입구에서 `SCRIPT`/`/b` 실행 상태를 먼저 감지한다.
- 자동 실행 중이면 변환 분기, 첫 native GMTITLE 생성, A3/A4 native 교체, A4 frame-only native 적용으로 들어가지 않고 `ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE`로 중단한다.
- 한국어 치환 함수 `swcad-title-replace-all`이 치환 결과 안에 원문이 다시 포함되는 경우를 건너뛰게 했다. 이 수정은 `SCRIPT`가 포함된 안내 문구가 무한 치환되는 문제를 막기 위한 것이다.
- 일반 읽기 전용 런타임 확인 스크립트의 기대 버전도 `260703-integrated-flow-main-38`로 갱신했다.

SCRIPT guard 런타임 확인:

```text
Loaded version: 260703-integrated-flow-main-38
Expected version: 260703-integrated-flow-main-38
CMDACTIVE before SWTITLECONVERT: 4
Run: SWTITLECONVERT
Result: OK SWTITLECONVERT status=ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE
CMDACTIVE after SWTITLECONVERT: 4
Guard status matched: yes
Runtime guard check reached end.
```

읽기 전용 런타임 확인:

```text
Loaded version: 260703-integrated-flow-main-38
Expected version: 260703-integrated-flow-main-38
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

해석:

- main38 LSP 로드와 읽기 전용 `SWTITLESTATUS`/`SWTITLEVERIFY` 실행은 GstarCAD 런타임에서 확인됐다.
- `SWTITLECONVERT`는 `/b` SCRIPT 상태에서 변환을 시작하지 않고 안전하게 중단하는 것이 확인됐다.
- 확인 대상 DWG는 변환 전 저장본이므로 `SWTITLEVERIFY_FINAL_FAIL`은 정상 진단이다.
- 실제 완료 증거는 여전히 작업복사본에서 `SWTITLECONVERT`를 CAD 명령줄로 직접 실행해 첫 native GMTITLE을 만든 뒤의 새 `SWTITLESTATUS`/`SWTITLEVERIFY`와 대표 `DR_titlea_3rd` 더블클릭 확인이다.
