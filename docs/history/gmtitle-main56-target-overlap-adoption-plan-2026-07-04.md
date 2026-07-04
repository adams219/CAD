# GMTITLE main56 target overlap/adoption 계획 - 2026-07-04

## 목적

이번 문제는 A3 한 장의 위치 문제가 아니라, 같은 위치에 `DR_A3_Outline + DR_titlea_3rd` target 쌍이 두 번 만들어지는 구조 문제다.

따라서 새 공개 명령어를 추가하지 않고, 기존 4단계 흐름 안에서 해결한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

## 이력에서 확정한 기준

반복하면 안 되는 방향:

```text
스크린샷 좌표 클릭으로 GMTITLE 선택
-GMTITLE 명령줄 자동 선택에 의존
A3/A4 전용 공개 명령 추가
Downloads 원본 DWG 직접 편집
겹친 target frame이 있는 상태에서 SWTITLECONVERT 반복
DR_A3_Outline 안의 title-like 형상만 보고 무조건 삭제
도면 안 번호, 주석, BOM, 치수, 모델 형상을 잔여물로 오판
```

핵심 기준 커밋:

```text
2d76a9b Use overlap-only GMTITLE frame normalization
```

이 커밋에서 확정한 원칙:

```text
DR_A3_Outline 안에 title-like 형상이 있다는 이유만으로 삭제하지 않는다.
별도 DR_titlea_3rd가 실제로 겹치는 경우에만 style-normalization 후보로 본다.
```

## 작업 전 이력 점검 루틴

같은 실수를 반복하지 않기 위해, 코드 수정이나 CAD 테스트를 시작하기 전에 아래 자료를 먼저 확인한다.

```text
git fetch --prune origin
git status --short --branch
git log --oneline --decorate -n 12 --all
```

현재 기준:

```text
GitHub origin/codex/gm-title 코드 기준: e738d2e Add GMTITLE main56 adoption guard 이상
로컬 codex/gm-title HEAD: origin/codex/gm-title와 일치해야 함
main56-a4guard 수정: GitHub에 푸시됨
```

반드시 먼저 읽을 로컬 문서:

```text
docs/history/gmtitle-main56-target-overlap-adoption-plan-2026-07-04.md
docs/investigations/gmtitle-main55-vs-main56-duplicate-target-pair-comparison-2026-07-04.md
docs/history/gmtitle-requirement-completion-audit-2026-07-04.md
docs/guide/gmtitle-current-run-card.md
```

반드시 먼저 확인할 CAD 로그:

```text
work/swcad_title_structure_diagnosis_last.txt
work/swcad_title_verify_summary_last.txt
work/swcad_title_duplicate_target_pair_clean_last.txt
work/swcad_title_transfer_apply_last.txt
```

주의:

```text
열려 있는 GstarCAD 도면에 저장 전 변경이 있으면, 숨김 진단으로 디스크 파일을 다시 열어 본 결과와 화면 상태가 다를 수 있다.
이 경우에는 현재 열린 CAD에서 SWTITLESTATUS/SWTITLEVERIFY를 다시 실행한 로그를 우선한다.
CAD 명령 입력에는 붙여넣기 방식(type_text)을 쓰지 않는다. GstarCAD가 _pasteclip으로 해석할 수 있다.
필요하면 키 입력 단위로 천천히 입력한다.
```

## 실제 관찰 증거

CAD 로그에서 다음 구조가 확인됐다.

```text
#2 DR_A3_Outline/17B5E, title=17B63, role=native-upgrade
#3 DR_A3_Outline/17AB3, title=17AB8, role=native-apply
둘 다 bbox=(663.86724324, 0.08373751) - (1083.86724324, 297.08373751)
```

이것은 원본 A3 도면틀 하나의 형상 문제가 아니라, 이미 생성된 target GMTITLE pair 두 쌍이 같은 위치에 겹친 문제다.

## 원인 가설

```text
1. 사람이 A3 native GMTITLE 기준 객체를 원본 A3 위치에 생성함.
2. 원본 SolidWorks A3 source frame/title은 아직 남아 있었음.
3. SWTITLECONVERT가 같은 위치의 source frame을 다시 변환 대상으로 잡음.
4. 새 clone/native-upgrade 쌍이 만들어지면서 기존 native-apply 쌍과 겹침.
```

올바른 동작:

```text
이미 같은 bbox에 native GMTITLE 쌍이 있으면 새 쌍을 만들지 않는다.
그 쌍을 채택(adopt)해서 속성값을 채우고 기존 SolidWorks source만 정리한다.
```

## 구현 계획

### 1. 겹친 target 쌍 진단

`SWTITLESTATUS`가 아래 조건의 중복을 별도로 표시한다.

```text
같은 sheet size
같은 DR_A*_Outline block
거의 같은 effective bbox
둘 다 source frame이 아니라 target GMTITLE pair
```

### 2. 겹친 target 쌍 정리

`SWTITLEPREPARE`가 work 복사본에서만 `YES` 확인 후 중복 target 쌍을 정리한다.

유지 우선순위:

```text
native-upgrade
native-adopt
native-apply
기타 native 역할
속성값이 더 많이 채워진 쌍
```

삭제 전 로그에는 handle, bbox, role, 유지/삭제 후보를 모두 표시한다.

### 3. 기존 native GMTITLE 채택 gate

`SWTITLECONVERT`가 source frame을 변환하기 전에 같은 bbox에 이미 adopt 가능한 native target pair가 있는지 확인한다.

있으면 새 GMTITLE을 만들지 않고 아래만 수행한다.

```text
기존 native title에 추출한 속성값 입력
기존 SolidWorks title/frame 삭제
표제란 주변 안전 잔여물 정리
role=native-adopt 기록
결과=ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER
```

### 4. 완료 검증

완료는 화면상 보기만으로 판단하지 않는다.

필수 조건:

```text
target frame overlap warning = 0
겹친 GMTITLE target 쌍 = 0
A2 target count = 1
A3 target count = 12
A4 target count = 2
남은 원본 SolidWorks 표제란 = 0
남은 원본 SolidWorks 도면틀 = 0
남은 frame-only 후보 = 0
SWTITLEVERIFY_FINAL_OK
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창
```

## 구현 결과

현재 LSP 버전:

```text
260704-target-overlap-adopt-main56-a4guard
```

구현됨:

```text
SWTITLESTATUS: 겹친 GMTITLE target 쌍 후보 수와 유지/삭제 후보 출력
SWTITLEPREPARE: work 복사본에서만 겹친 target 쌍 정리
SWTITLECONVERT: 같은 bbox의 기존 native GMTITLE 쌍 채택
SWTITLEVERSION: main56 기대 버전 표시
```

검증 로그:

```text
work/swtitle_duplicate_target_pair_compare_main56.txt
work/swtitle_adoption_gate_compare_main56.txt
work/swtitle_command_text_guard_compare_main56_command_text_guard.txt
work/swtitle_residue_protection_main56_residue_protection.txt
work/swtitle_embedded_title_prepare_compare_main56_embedded_prepare.txt
```

최신 LSP 직접 재검증 로그:

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

핵심 결과:

```text
Loaded loader version: 260704-4step-gmtitle-main56-a4guard
Loaded GMTITLE version: 260704-target-overlap-adopt-main56-a4guard
Duplicate target pair probe passed: yes
Adoption gate probe passed: yes
Danger action: <none>
All expected log markers were verified.
GMTITLE main56 verification suite complete
```

## 2026-07-04 실제 CAD 재확인 이력

GitHub 원격 확인:

```text
git fetch --prune origin
origin/codex/gm-title = e738d2e Add GMTITLE main56 adoption guard 이상
로컬 codex/gm-title HEAD = origin/codex/gm-title와 일치해야 함
main56-a4guard 수정은 GitHub에 푸시됨
```

실제 CAD에서 반복 실수의 직접 원인 하나를 확인했다.

```text
현재 열린 GstarCAD 세션에는 260704-nested-style-direct-main55가 남아 있었다.
그래서 코드/문서는 main56이어도 CAD 동작은 예전 main55 판단을 따를 수 있었다.
최신 swcad_title_scale.lsp를 절대경로로 다시 load한 뒤 main56-a4guard 버전을 확인했다.
```

로더도 보강했다.

```text
swcad_load.lsp가 *load-truename*를 못 얻으면 현재 DWG 폴더와 그 부모 폴더를 같이 검사한다.
work 폴더에서 작업복사본을 열어도 C:\Users\DR-DESIGN\Documents\CAD tool 아래 src 모듈을 찾을 수 있다.
숨김 loader probe와 실제 CAD 로드 모두 통과했다.
```

실제 CAD에서 확인한 진행:

```text
SWTITLEPREPARE가 겹친 A3 GMTITLE target 쌍 1개를 감지했다.
유지: native-upgrade/native-upgrade
삭제 후보: native-apply/native-apply
YES 후 중복 target 쌍 후보 0개가 됐다.

SWTITLECONVERT 빠른 변환 단계에서 A4 frame-only 기준 객체가 없으면 A4를 묶어 처리하지 않도록 guard를 추가했다.
확인 문구도 "표제란 시트 11장만 처리"로 바뀌었다.
A3 11장은 빠른 복제 처리됐고, A4 frame-only 2장은 아직 변경하지 않았다.
```

현재 열린 CAD 세션의 중간 상태:

```text
남은 원본 표제란 시트: 0
남은 원본 도면틀: 2
남은 표제란 없는 도면틀 시트: 2
대상 도면틀 수:
  A2: 1
  A3: 12
  A4: 0
A3/A4 native 교체 후보: 12
다음 상태: NEXT_UPGRADE_A3_A4_NATIVE
```

아직 완료가 아니다.

```text
A3 복제 target 12개는 모양은 맞지만 더블클릭 native 동작을 신뢰하려면 SWTITLECONVERT로 한 장씩 native 교체가 필요하다.
A4 frame-only 2장은 DR_A4_Outline 실제 native 기준 객체를 만들고 bbox 검사 후 처리해야 한다.
최종 완료 조건은 SWTITLEVERIFY_FINAL_OK와 대표 A2/A3/A4 더블클릭 확인이다.
```

## 다음 실제 CAD 순서

실제 작업복사본에서는 항상 이 순서를 따른다.

```text
SWTITLESTATUS
SWTITLEPREPARE   상태가 요구할 때만
SWTITLESTATUS
SWTITLECONVERT   상태가 요구할 때만
SWTITLESTATUS
SWTITLEVERIFY    상태가 최종 검증을 요구할 때
```

중요:

```text
SWTITLESTATUS가 겹친 target 쌍을 표시하면 SWTITLECONVERT를 반복하지 않는다.
먼저 SWTITLEPREPARE로 중복 target 쌍을 정리한다.
```
