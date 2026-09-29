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
- 결과는 `tmp\gmtitle-value-test\<시각>\summary.txt`에 남는다. 문제가 있으면 `RESULT: CHECK NEEDED`로 끝난다.

원본 도면은 복사만 하고 해시로 변경 여부를 확인한다.

## 검사 내용

| 단계 | 파일 | 확인하는 것 |
| --- | --- | --- |
| plan | `title_value_plan_probe.lsp` | 시트마다 원본 속성·글자와 새 코드가 쓸 11칸 값. 이전 코드가 썼을 값도 함께 기록한다. |
| write | `title_value_write_probe.lsp` | 서식 코드 제거·빈칸 채우기 단위 검사, 계획 값 쓰기 후 다시 읽기(30장 × 11칸) |
| verify | `title_value_verify_probe.lsp` | `SWTITLEVERIFY` 최종 요약 결과와 값 문제(XXX, 파일 경로, 서식 코드) |
| e2e | `run_title_stage_e2e.ps1`, `title_value_dump_probe.lsp` | 실제 변환된 제목블록 값이 계획 값과 같은지 |

`analyze_title_value_test.ps1 -OutputRoot <폴더>`로 로그만 다시 분석할 수 있다.

## 기대 결과 (30장 fixture)

- 원본과 다른 칸: 4칸, 모두 의도한 변경(원본의 `XXX`와 파일 경로를 빈칸으로, 용지 크기를 도면틀 기준으로, 승인/날짜 합친 값 분리)
- 쓰기 후 다시 읽은 값: 330칸 모두 계획과 같음
- 실제 변환 결과: 330칸 모두 계획과 같음, `SWTITLEVERIFY_FINAL_OK`
- 이전 코드로 변환한 07-20 도면: `SWTITLEVERIFY_WARN_TITLE_VALUES`, 값 문제가 있는 제목블록 15장
