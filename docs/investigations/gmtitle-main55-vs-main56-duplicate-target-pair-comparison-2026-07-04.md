# GMTITLE main55 vs main56 비교 - 2026-07-04

## 비교 목적

사용자가 요청한 방향은 A3 한 장을 임시 명령으로 고치는 것이 아니라, 아래 4단계 안에서 같은 실수를 반복하지 않게 만드는 것이다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

비교 대상:

```text
work/lsp_compare/swcad_title_scale_main55_baseline.lsp
work/lsp_compare/swcad_title_scale_main56_candidate.lsp
```

## 실제 문제

실제 CAD 로그에서 같은 위치에 A3 target 쌍이 2개 생겼다.

```text
DR_A3_Outline + DR_titlea_3rd target 쌍 2개가 같은 bbox에 겹침
한 쌍은 native-apply, 다른 쌍은 native-upgrade 역할
둘 다 제목블록이 있어서 기존 orphan frame 정리로는 잡히지 않음
```

이 상태에서 `SWTITLECONVERT`를 계속 누르면 변환이 진행되는 것처럼 보이지만, 더블클릭 대상과 검증 대상이 빗나갈 수 있다.

## main55 결과

로그:

```text
work/swtitle_duplicate_target_pair_compare_main55.txt
work/swtitle_adoption_gate_compare_main55.txt
```

중복 target 쌍 probe:

```text
Loaded version: 260704-nested-style-direct-main55
Duplicate function present: no
Duplicate target pair probe passed: no-function
```

기존 native 채택 gate probe:

```text
Adoption function present: no
Status after transfer: ABORT_NO_NATIVE_GMTITLE_TITLE
Danger action: RUN_NATIVE_GMTITLE
Source title count before/after: 1/1
Target title count before/after: 1/1
Adoption gate probe passed: no
```

판단:

```text
main55는 이미 생긴 겹친 target 쌍을 별도 정리 대상으로 인식하지 못한다.
main55는 같은 bbox에 native GMTITLE이 이미 있어도 새 GMTITLE 생성 경로로 들어갈 수 있다.
따라서 A3에서 같은 위치에 두 쌍이 생기는 실수를 막지 못한다.
```

## main56 결과

로그:

```text
work/swtitle_duplicate_target_pair_compare_main56.txt
work/swtitle_adoption_gate_compare_main56.txt
```

중복 target 쌍 probe:

```text
Loaded version: 260704-target-overlap-adopt-main56
Duplicate function present: yes
Duplicate target pair count: 1
Keep frame/title role: 16900/16901 native-upgrade/native-upgrade
Discard frame/title role: 168FE/168FF native-apply/native-apply
Duplicate target pair probe passed: yes
```

기존 native 채택 gate probe:

```text
Loaded version: 260704-target-overlap-adopt-main56
Adoption function present: yes
Status after transfer: ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER
Danger action: <none>
Source title count before/after: 1/0
Target title count before/after: 1/1
Adoption gate probe passed: yes
```

판단:

```text
main56은 이미 생긴 겹친 target 쌍을 감지한다.
main56은 native-upgrade/native-adopt/native-apply 역할과 속성값 수를 기준으로 유지/삭제 후보를 고른다.
main56은 같은 bbox에 기존 native GMTITLE 쌍이 있으면 새로 만들지 않고 그 쌍을 채택한다.
```

## 회귀 테스트

main56 후보는 기존 안전장치도 유지했다.

```text
work/swtitle_lsp_copy_compare_main56_target_overlap.txt
  4개 공개 명령 유지
  legacy fast/bootstrap/frame-only/A3A4 명령 비공개 유지

work/swtitle_style_normalization_compare_main56_stylecmp_all_sizes_clean.txt
  A2/A3/A4 style-normalization 후보 감지/정리 통과

work/swtitle_command_text_guard_compare_main56_command_text_guard.txt
  도면에 들어간 명령어 TEXT가 있으면 변환 중단

work/swtitle_residue_protection_main56_residue_protection.txt
  실제 번호, 작은 주석, BOM-like insert 보존

work/swtitle_embedded_title_prepare_compare_main56_embedded_prepare.txt
  별도 제목블록과 겹치지 않는 native-format title-like 형상 보존
```

최신 LSP를 직접 로드해 다시 확인한 로그:

```text
work/swtitle_loader_probe_main56_diagnostics.txt
work/swtitle_lsp_copy_compare_current_main56.txt
work/swtitle_actual_workcopy_status_main56_diagnostics.txt
work/swtitle_duplicate_target_pair_compare_main56_rerun_duplicate.txt
work/swtitle_adoption_gate_compare_main56_rerun_adoption.txt
work/swtitle_command_text_guard_compare_main56_rerun_command_guard.txt
work/swtitle_residue_protection_main56_rerun_residue.txt
work/swtitle_embedded_title_prepare_compare_main56_rerun_embedded.txt
work/swtitle_style_normalization_compare_main56_rerun_style_all.txt
```

전체 suite:

```text
diagnostics/gmtitle-main45/run_main45_verification_suite.ps1
All expected log markers were verified.
GMTITLE main56 verification suite complete
```

2026-07-04 현재 작업트리 기준 재실행 결과:

```text
Loaded loader version: 260704-4step-gmtitle-main56-a4guard
Loaded GMTITLE version: 260704-target-overlap-adopt-main56-a4guard
Current LSP copy compare: Runtime check completed: yes
A2/A3/A4 frame-definition probe: mixed / all_contaminated / all_native 모두 PASS
Style-normalization clean: record count after clean = 0
Command-text guard: convert-status-after = ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST
Residue protection passed: yes
Embedded-title prepare: Cleanup deleted count = 0
Duplicate target pair probe passed: yes
Adoption gate probe passed: yes
All expected log markers were verified.
GMTITLE main56 verification suite complete
```

이 재검증은 `main56_candidate.lsp` 복사본만의 결과가 아니라, 현재 실제 소스 LSP
`src/tools/gmtitle/swcad_title_scale.lsp`와 loader `swcad_load.lsp` 기준 결과다.

## 결론

현재 비교 기준에서는 main56이 main55보다 낫다.

```text
main55:
  겹친 target 쌍을 별도 문제로 보지 못함
  기존 native GMTITLE이 있어도 새 GMTITLE 생성 경로로 들어갈 수 있음

main56:
  겹친 target 쌍을 SWTITLESTATUS/SWTITLEPREPARE 흐름에 포함
  기존 native GMTITLE 채택 gate로 같은 위치에 새 쌍을 또 만드는 실수를 차단
  기존 A3 native 형상 보호, 잔여물 보호, command text guard 유지
```

## 남은 검증

코드/fixture 기준은 통과했지만 실제 업무 도면 완료는 별도다.

완료 조건:

```text
실제 work 복사본에서 SWTITLEVERIFY_FINAL_OK
남은 SolidWorks 표제란/도면틀/frame-only 후보 0
A2: 1, A3: 12, A4: 2 target count 일치
겹친 GMTITLE target 쌍 0
대표 A2/A3/A4 제목블록 더블클릭 시 GMTITLE 표 편집창 열림
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```
