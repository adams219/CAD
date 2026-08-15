# GMTITLE 요구사항별 완료 감사 - 2026-07-04

## 결론

main56 기준으로 4단계 통합 흐름의 코드/문서/읽기 전용 진단은 통과했다.

다만 전체 목표가 완전히 끝난 것은 아니다. 실제 업무 DWG 작업복사본에서 대화식 `SWTITLECONVERT`를 끝까지 수행하고, `SWTITLEVERIFY_FINAL_OK`와 대표 A2/A3/A4 제목블록 더블클릭 결과가 확인되어야 최종 완료다.

## 현재 기준 파일

```text
LSP: C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
Loader: C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
GMTITLE version: 260704-target-overlap-adopt-main56-a4guard
Loader version: 260704-4step-gmtitle-main56-a4guard
```

## 핵심 증거

2026-07-04 현재 작업트리 기준 전체 main56 verification suite 재실행:

```text
diagnostics\gmtitle-main45\run_main45_verification_suite.ps1
All expected log markers were verified.
GMTITLE main56 verification suite complete.
```

로더 보강 후 추가 확인:

```text
diagnostics\gmtitle-main45\run_loader_probe.ps1
Loaded loader version: 260704-4step-gmtitle-main56-a4guard
Loaded GMTITLE version: 260704-target-overlap-adopt-main56-a4guard
Runtime check completed: yes
```

정적 명령 표면 확인:

```text
src/tools/gmtitle/swcad_title_scale.lsp
  c:SWTITLESTATUS
  c:SWTITLEPREPARE
  c:SWTITLECONVERT
  c:SWTITLEVERIFY
  c:SWTITLEVERSION
  c:SWSCALESCAN

예전 임시 명령은 defun c:로 공개되지 않고 disable list에만 남아 있다.
```

주요 로그:

```text
work\swtitle_loader_probe_main56_diagnostics.txt
work\swtitle_lsp_copy_compare_current_main56.txt
work\swtitle_actual_workcopy_status_main56_diagnostics.txt
work\swtitle_style_normalization_compare_current_main56_stylecmp_all_sizes_clean.txt
work\swtitle_command_text_guard_compare_current_main56_command_text_guard.txt
work\swtitle_residue_protection_current_main56_residue_protection.txt
work\swtitle_embedded_title_prepare_compare_current_main56_embedded_prepare.txt
work\swtitle_duplicate_target_pair_compare_current_main56_duplicate_target_pair.txt
work\swtitle_adoption_gate_compare_current_main56_adoption_gate.txt
```

## 요구사항별 감사

| 요구사항 | 현재 증거 | 판정 |
| --- | --- | --- |
| 사용자 변환 명령은 4단계로 통합 | 정적 소스 검색에서 공개 변환 명령은 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY`만 확인. 런타임 probe에서도 네 명령 `yes`. 보조 `SWTITLEVERSION`, `SWSCALESCAN`은 읽기 전용 확인/스케일 진단용 | 충족 |
| 예전 임시 명령은 사용자용 공개 명령이 아니어야 함 | loader/LSP compare probe에서 `SWTITLEFASTSTATUS`, `SWTITLETRANSFERBOOTSTRAPFAST`, `SWTITLETRANSFERFASTBATCH`, `SWTITLEFRAMEONLYAPPLY`, `SWTITLEA3A4NEXT`, `SWTITLEGMTITLEVERIFYALL` 모두 `no` | 충족 |
| `SWTITLESTATUS`가 A2/A3/A4 수량 표시 | actual workcopy status probe에서 A2=1, A3=12, A4=2 출력 | 충족 |
| `SWTITLESTATUS`가 SolidWorks 원본 도면틀/표제란 개수 표시 | `source-title-count=13`, `source-frame-count=15`, `frame-only-count=2` | 충족 |
| `SWTITLESTATUS`가 GMTITLE target 도면틀/제목블록 개수 표시 | 변환 전 workcopy에서 `target-title-count=0`, `target-frame-count=0`, `target-sheet-counts=<none>` | 충족 |
| `DR_A*_Outline` 블록 정의 내부 구조 분석 | frameclass common probe가 A2/A3/A4를 `outline-only`, `native-format-with-title-geometry`, `source-contaminated`로 분류 | 충족 |
| 도면틀 안 title-like 형상 감지 | embedded/style-normalization probe에서 A2/A3/A4 내부 title-like 형상을 감지하고 상황별로 보존/정리 판단 | 충족 |
| A4처럼 선택 범위/형상이 이상한 경우 감지 | native frame/status 계열이 bbox, geometry warning, overlap risk를 출력하는 경로 존재. 변환 전 workcopy는 target 0이라 위험 0 | 구현됨, 변환 후 재검증 필요 |
| 결과를 한글로 출력 | 통합 명령과 로그가 한글 안내를 출력. 깨진 문서는 main56 기준 문서로 교체 | 충족 |
| `SWTITLEPREPARE`가 A2/A3/A4 공통 도면틀 정의 검사 | mixed/all-contaminated/all-native frameclass probe 통과 | 충족 |
| 오염된 source 도면틀 정의만 정리 후보로 보냄 | all-contaminated probe에서 A2/A3/A4 cleanup 후보 감지 | 충족 |
| native-format title-like 형상은 무조건 삭제하지 않음 | embedded-title prepare probe에서 A2/A3/A4 cleanup 후보 `<none>`, 삭제 0 | 충족 |
| 별도 `DR_titlea_3rd`와 실제 겹칠 때만 정규화 | style-normalization probe에서 A2/A3/A4 겹침 후보 3개 감지, 정리 후 후보 0 | 충족 |
| 기존 정상 `DR_titlea_3rd` 제목블록 보호 | title protection/embedded/style-normalization 경로에서 별도 정상 title은 정리 대상과 분리 | 충족 |
| 작업복사본에서만 변경 | prepare/apply 계열은 work copy/read-only guard를 사용. read-only probes는 도면 저장 없이 통과 | 충족 |
| 실행 전 후보 목록과 `YES` 확인 | command text, frame cleanup, orphan, duplicate target pair cleanup이 후보 출력 후 `YES` 확인. script 자동 실행에서는 중단 | 충족 |
| `SWTITLECONVERT`가 기존 표제란 텍스트 추출 | transfer/finalize 경로 유지. adoption gate probe에서 기존 source title을 정리하고 target title 유지 확인 | 구현됨, 실제 업무 도면 속성값 최종 검증 필요 |
| 기존 시트 크기 자동 인식 | status probe가 A2/A3/A4 수량을 자동 감지 | 충족 |
| 같은 크기별 native GMTITLE 기준 객체 처리 | `SWTITLECONVERT` 내부에 first native, missing exemplar, frame-only, native replacement 흐름 존재 | 구현됨, 실제 대화식 GMTITLE 생성 검증 필요 |
| 나머지 자동 복제/배치 | fast batch/clone 내부 경로가 `SWTITLECONVERT`에서 호출됨 | 구현됨, 실제 변환 완료 검증 필요 |
| 변환 후 기존 SolidWorks 도면틀/표제란/잔여물 제거 | finalize/cleanup 경로 유지, residue protection probe 통과 | 구현됨, 실제 변환 후 원본 후보 0 확인 필요 |
| A2/A3/A4별 임시 명령으로 처리하지 않음 | public command surface에서 용지별 명령 없음. `SWTITLECONVERT` 내부 분기로 통합 | 충족 |
| 중복 GMTITLE target 쌍 감지/정리 | duplicate target pair probe 통과. `native-upgrade` 유지, `native-apply` 삭제 후보 선정 | 충족 |
| 기존 native GMTITLE이 있으면 새로 만들지 않고 채택 | adoption gate probe 통과. `ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER`, danger action `<none>` | 충족 |
| `SWTITLEVERIFY`가 중복/누락/고아/native-like/수량을 최종 요약 | final summary 경로 존재. 변환 전 workcopy는 `SWTITLEVERIFY_FINAL_FAIL`을 정상 출력 | 충족 |
| 더블클릭 대상 안내 | verify/double-click check 경로 존재 | 구현됨, 실제 대표 A2/A3/A4 더블클릭 확인 필요 |
| 최종 결과 OK/WARN/FAIL | 변환 전 workcopy에서 `SWTITLEVERIFY_FINAL_FAIL` 출력 | 충족 |
| LSP 복사본 비교로 더 나은 방향 판단 | `work/lsp_compare/swcad_title_scale_main55_baseline.lsp`와 `work/lsp_compare/swcad_title_scale_main56_candidate.lsp` 비교. main55는 duplicate/adoption gate 부재, main56은 둘 다 통과. 이후 현재 실제 source LSP 기준 suite도 재통과 | 충족 |

## 현재 실제 작업복사본 상태

읽기 전용 진단 기준:

```text
Loaded version: 260704-target-overlap-adopt-main56-a4guard
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
target-sheet-counts:
  <none>
```

해석:

```text
현재 작업복사본은 아직 변환 전 상태다.
다음 실제 CAD 단계는 SWTITLECONVERT로 첫 native GMTITLE 기준 객체를 만드는 것이다.
```

2026-07-04 현재 작업트리 기준 final completion gate 재실행 결과:

```text
diagnostics\gmtitle-main45\run_final_completion_gate.ps1
Loaded version: 260704-target-overlap-adopt-main56-a4guard
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
target-sheet-counts: <none>
결과: final completion gate FAIL
```

해석:

```text
이 FAIL은 현재 LSP 로드 실패나 비교 실패가 아니다.
디스크에 저장된 workcopy가 아직 변환 전 상태이므로 최종 완료 조건을 만족하지 못한 것이다.
다음 실제 CAD 단계는 workcopy를 열고 SWTITLECONVERT부터 진행하는 것이다.
```

주의: 위 읽기 전용 진단은 디스크에 저장된 작업복사본을 다시 연 결과다. 실제 열린 GstarCAD 세션에 저장 전 변경이 있으면 화면 상태가 더 최신일 수 있다.

2026-07-04 실제 열린 CAD 세션 기준:

```text
Loaded version: 260704-target-overlap-adopt-main56-a4guard
중복 A3 target 쌍 1개를 SWTITLEPREPARE로 정리함
A3 남은 표제란 시트 11장은 빠른 복제로 처리함
A4 frame-only 2장은 DR_A4_Outline 실제 native 기준 객체가 없어 빠른 변환에서 건너뜀

남은 원본 표제란 시트: 0
남은 원본 도면틀: 2
남은 표제란 없는 도면틀 시트: 2
대상 도면틀:
  A2: 1
  A3: 12
  A4: 0
A3/A4 native 교체 후보: 12
현재 상태: NEXT_UPGRADE_A3_A4_NATIVE
```

이 상태는 최종 완료가 아니다. A3 복제본 12개를 native 더블클릭 인식용으로 한 장씩 교체하고, 이후 A4 frame-only 2장을 별도 native 생성/검사 흐름으로 처리해야 한다.

## 아직 최종 완료 증거가 없는 항목

아래는 실제 GstarCAD 화면에서 변환을 끝낸 뒤 확인해야 한다.

```text
1. SWTITLECONVERT로 첫 native GMTITLE 생성
2. 로그가 요구하는 DR_A2_Outline / DR_titlea_3rd 선택
3. Frame positioning ON, Object move OFF 확인
4. SWTITLESTATUS 재실행
5. 필요 시 SWTITLEPREPARE 또는 SWTITLECONVERT 반복
6. SWTITLEVERIFY_FINAL_OK 확인
7. 남은 원본 SolidWorks 표제란 0
8. 남은 원본 SolidWorks 도면틀 0
9. frame-only 후보 0
10. target-sheet-counts A2=1, A3=12, A4=2
11. 겹친 GMTITLE target 쌍 0
12. 대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
13. 도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```

이 항목들이 확인되기 전에는 목표를 최종 완료로 표시하지 않는다.
