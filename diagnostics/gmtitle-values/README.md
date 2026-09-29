# GMTITLE 표제란 값 회귀 테스트

GMTITLE 변환이 원본 표제란 값을 새 `DR_titlea_3rd` 11칸에 그대로 옮기는지 확인한다. 2026-09-29 수정(`260929-title-values-1`)의 기준 테스트다. 기록: `docs/history/gmtitle-title-values-2026-09-29.md`.

## 실행

GstarCAD를 닫은 뒤 PowerShell에서 실행한다.

```powershell
& "diagnostics\gmtitle-values\run_title_value_test.ps1" -EndToEnd
```

- `-TitleStageDwg`: TITLE 단계 도면(원본 표제란이 남아 있는 상태). 생략하면 30장 fixture(`work\_preserved_20260714\fixtures\sheet_wrapper_source_fixture_260713.dwg`)를 통합 테스트(`MATERIALIZE_WRAPPED_XREF`)로 먼저 만든다.
- `-CheckDwg`, `-CheckListFile`: 이미 변환한 도면의 제목블록 값 검사(`SWTITLEVERIFY` 최종 요약). 복사본만 연다.
- `-EndToEnd`: 보이는 GstarCAD에서 COM `SendCommand`로 `SWCADRUN`을 실행해 TITLE 단계(실제 GMTITLE 창과 자동 선택기)를 끝까지 돌린다. 작업본은 `work\swcad-workflow-tests\gmtitle_value_e2e_*.dwg`에 저장된다. 실행 중에는 마우스와 키보드를 건드리지 않는다.
- `-FullWorkflow`(`-EndToEnd`와 함께): `COMPLETE`까지 `SWCADRUN`을 계속 실행한 뒤, 저장된 작업본에서 `SWCADVERIFY`와 같은 검사(`workflow_final_verify_probe.lsp`)를 읽기 전용으로 실행한다.
- 결과는 `tmp\gmtitle-value-test\<시각>\summary.txt`에 남는다. 문제가 있으면 `RESULT: CHECK NEEDED`로 끝난다.

원본 도면은 복사만 하고 해시로 변경 여부를 확인한다.

## 검사 내용

| 단계 | 파일 | 확인하는 것 |
| --- | --- | --- |
| plan | `title_value_plan_probe.lsp` | 시트마다 원본 속성·글자와 새 코드가 쓸 11칸 값. 이전 코드가 썼을 값도 함께 기록한다. |
| write | `title_value_write_probe.lsp` | 서식 코드 제거·빈칸 채우기 단위 검사, 계획 값 쓰기 후 다시 읽기(30장 × 11칸) |
| delete safety | `title_delete_safety_probe.lsp` | 두 번 지워도 되살아나지 않는지, 잠긴 레이어 보고, 표제란 주변 선·면 규칙(합성 객체), 실제 시트에서 수정 전 규칙과 같은지 |
| stop on error | `title_stop_probe.lsp`, `title_stop_probe_after.lsp` | 오류·ESC를 가짜 함수로 넣었을 때 멈춤 상태가 남는지, 객체 스냅·일괄 처리 표시·캐시가 복원되는지, 결과 상태가 없으면 `SWCADRUN`이 멈추는지, `SWCADRUN`의 오류 처리(다음 스크립트 줄에서 확인) |
| small fixes | `title_small_fixes_probe.lsp` | 블록 이름으로 하는 용지 판단(단위 검사, 도면의 모든 블록 이름을 이전 규칙과 비교, 30장 시트 결과가 같은지), 작업본 이름의 날짜와 `_SWTITLE_` 접미사, XREF가 없을 때 XREF 안내가 나오지 않는지 |
| verify | `title_value_verify_probe.lsp` | `SWTITLEVERIFY` 최종 요약 결과와 값 문제(XXX, 파일 경로, 서식 코드) |
| e2e | `run_title_stage_e2e.ps1`, `title_value_dump_probe.lsp`, `title_value_entity_dump_probe.lsp` | 실제 변환된 제목블록 값이 계획 값과 같은지, 변환으로 지워진 모델 공간 객체 종류별 개수 |

`analyze_title_value_test.ps1 -OutputRoot <폴더>`로 로그만 다시 분석할 수 있다.

## 기대 결과 (30장 fixture)

- 원본과 다른 칸: 4칸, 모두 의도한 변경(원본의 `XXX`와 파일 경로를 빈칸으로, 용지 크기를 도면틀 기준으로, 승인/날짜 합친 값 분리)
- 쓰기 후 다시 읽은 값: 330칸 모두 계획과 같음
- 실제 변환 결과: 330칸 모두 계획과 같음, `SWTITLEVERIFY_FINAL_OK`
- 이전 코드로 변환한 07-20 도면: `SWTITLEVERIFY_WARN_TITLE_VALUES`, 값 문제가 있는 제목블록 15장
- `-FullWorkflow`: `SWCADRUN` 4회로 `COMPLETE`, `SWCADVERIFY_FINAL_OK`(SWAUTO `260929-value-guard-4` 이상)
- 삭제 안전장치 단위 검사 27개 통과(잠긴 레이어의 표제란 선으로 실제 변환이 멈추는지 포함, `260929-small-fixes-2` 이상). 지워진 모델 공간 객체 1693개(선 1215, 글자 223, 해치 195, 옛 표제란·도면틀 60).
- 오류 시 멈춤 단위 검사 60개 통과(`260929-title-stop-1` 이상).
- 작은 수정 단위 검사 28개 통과, 블록 이름 판단이 이전 규칙과 다른 이름 145개(시트 결과는 30장 모두 같음, `260929-small-fixes-1` 이상).
