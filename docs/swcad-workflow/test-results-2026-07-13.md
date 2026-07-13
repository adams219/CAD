# SWCAD Workflow 검증 결과 (2026-07-13)

## 대표 파일

| 용도 | 파일 | SHA-256 |
| --- | --- | --- |
| 원본 SolidWorks 다중 시트 | `work/0000_A_DRP125_CP_ALL_260626_ORIGINAL_TEST_260711.dwg` | `3C7735569B7EBAC8300225A81CEFB441562AB656770E5FC8868099B559A959B2` |
| native GMTITLE 15장 기준본 | `portable-e2e/output/swtitle_portable_result_260712.dwg` | `1F2D3BA224A27E141CB64D79DC4FE75DCC00819D2F07751D83E8380CCE17AA23` |
| 중첩 시트 묶음 회귀 기준본 | `work/swcad-workflow-tests/sheet_wrapper_source_fixture_260713.dwg` | `3590FF177D46988BF7E319720A540D71CF3AE98D696F0896D85B7F2FD5E49D7E` |

각 회귀 실행 전후에 사용한 원본/기준본 SHA-256은 동일했다.

## XREF 방식 비교

원본 SolidWorks DWG를 `(1000, 2000, 0)`, 축척 1, 회전 0으로 붙여 비교했다.

| 상태 | XREF | 최상위 치수 | deep 치수 | 원본 title/frame | bbox 크기 | 치수 의미 해시 |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| 원본 기준 | 0 | 143 | 143 | 15/15 | `6713.9789299 x 420.08373751` | `0BD6F5F40BBE3AAFC2E6299424C3CA6FFA865CE3FA524A0CEFF0032E01D6B9AB` |
| Attached | 1 | 0 | 143 | 0/0 | 동일 | 동일 |
| BIND | 0 | 0 | 143 | 0/0 | 동일 | 동일 |
| BIND + 1회 EXPLODE | 0 | 143 | 143 | 15/15 | 동일 | 동일 |

선택 결과는 `BIND + 최상위 참조 1회 EXPLODE`다.

native GMTITLE 기준본은 EXPLODE 후 target title/frame/native-like pair가 `15/15/15`에서 `0/0/0`이 됐다. 따라서 `BLOCKED_NATIVE_GMTITLE_XREF`가 정상 정책이다.

## 실제 GstarCAD 통합 검사

기존 네 모드와 중첩 시트 회귀 두 모드를 별도 GstarCAD 프로세스에서 실행했다. 아래 `현재 변경` 표시는 `260713-sheet-wrapper-materialize-2`에서 직접 재실행한 결과다.

| 모드 | 결과 | 검증 시점 |
| --- | --- | --- |
| `MATERIALIZE_RAW` | XREF 0, 최상위 치수 143, 원본 title/frame 15/15, 다음 단계 TITLE | 기존 기준 회귀 |
| `MATERIALIZE_WRAPPED_XREF` | XREF 1에서 시작, 시트 묶음 0, 최상위 치수 254, 원본 title/frame 30/41, bbox 보존, 다음 단계 TITLE | 현재 변경 |
| `NATIVE_GUARD` | 최상위 DR frame/title 15/15 및 target 30 감지, XREF 1 유지, 도면 변경 차단 | 현재 변경 |
| `SHEET_WRAPPERS` | 부분 materialize 기준 묶음 10→0, 치수 0→254, title/frame 30/41, bbox 보존 | 현재 변경 |
| `DOWNSTREAM` | GMTITLE OK, DIMSTYLE OK, 치수 의미 보존, A4 Layout 15개 | 기존 기준 회귀 |
| `REOPEN` | 저장 후 상태 유지, Layout 15개, 통합 감사 OK, `DBMOD=0` | 기존 기준 회귀 |

현재 변경의 `MATERIALIZE_RAW` 전체 재실행은 보이는 GstarCAD 세션과 동시에 돌린 숨김 프로세스가 제한 시간 안에 완료되지 않아 최종 PASS를 새로 기록하지 않았다. 이전 원본 기준 결과는 유지되며, 현재 코드는 중첩 기준본과 native 보호 기준본을 직접 통과했다. 전체 기본 모드 재실행은 보이는 GstarCAD를 닫은 상태에서 수행한다.

배포 ZIP의 `install.ps1`로 생성한 `SWCAD_Workflow_Load.lsp`도 실제 GstarCAD에서 검사했다. 테스트 전에 저장된 루트는 개발 저장소였지만, 루트 로더가 이를 패키지 경로로 갱신했고 패키지 내부 앱 버전과 세 공개 명령, 상태 XRecord가 정상 로드됐다.

중첩 기준본의 바깥 시트 묶음은 10개였다. 직접 치수만 세면 42개였지만, 하위 내용 블록과 같은 정의의 반복 삽입을 포함한 instance-aware deep 치수는 254개였다. DR frame/title 블록은 유지하고 치수 포함 내용 블록만 반복 분해한 뒤 최상위 치수 254개와 정확히 일치했다. 모델 bbox는 전후 동일했다.

묶음 내부 DR 블록의 XData handle은 `POINT`를 가리켜 native 링크로 사용할 수 없었다. 반면 native 기준본은 XREF 최상위 DR frame/title가 15/15로 함께 존재했다. 구조 판정으로 전자는 materialize하고 후자는 `BLOCKED_NATIVE_GMTITLE_XREF`로 차단했다.

치수 의미 검사는 143개 핸들의 raw measurement, `DIMLFAC`, 상·하 공차와 표시 플래그를 전후 비교한다. 최초 진단에서 핸들 `37C1`의 불일치를 확인했고, 전체 비교에서는 73개 핸들의 의미 오버라이드 변화가 감지됐다. 통합 앱은 이 73개만 선택 복원했으며 이후 143개가 전부 일치했다. 복원 직후와 최종 검증에서 Mechanical fit 데이터 및 스타일 감사도 통과했다.

Layout 검사는 최종 GMTITLE 도면틀 15개의 수동 배치 좌표를 왼쪽→오른쪽, 위쪽→아래쪽으로 계산했다. 생성 전 계획 수량 15, 생성 후 Layout 수 15, `LAYOUT_PLACEMENT_MODE=MANUAL_FRAME_COORDINATES`, 저장 후 계획 수량 15와 좌표 지문을 확인한다. 앱 코드에는 XREF나 도면 객체를 자동 이동하는 `vla-Move`/`MOVE` 경로가 없다.

- 첫 창: `(0, 0.0837) - (594, 420.0837)`
- 마지막 창: `(6293.9789, 0.4261) - (6713.9789, 297.4261)`
- 저장된 좌표 지문: `15:653975:391240`
- 재열기 결과: `COMPLETE`, `SWCADVERIFY_FINAL_OK`, `DBMOD=0`

## 재실행 조건

- 앱 Layout 접두사 수: 15
- 기대 GMTITLE 도면틀 수: 15
- Layout당 뷰포트: 1
- 모든 Layout 용지: A4
- 저장 후 `DIMSTYLE=OK`, `DIMENSION_SEMANTICS=PRESERVED`, `LAYOUT=OK`
- 저장 후 `LAYOUT_PLACEMENT_MODE=MANUAL_FRAME_COORDINATES`, `LAYOUT_PLAN_COUNT=15`, 좌표 지문 일치
- 최종 상태: `COMPLETE`

## 실행 명령

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\swcad-workflow\run_static_preflight.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\swcad-workflow\run_xref_materialize_matrix.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\swcad-workflow\run_workflow_loader_probe.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\swcad-workflow\run_workflow_integration_probe.ps1
```

실제 DWG 산출물과 런타임 로그는 Git에 넣지 않고 `work/swcad-workflow-tests`와 `tmp/swcad-workflow-integration`에 둔다.
