# SWCAD Workflow 검증 결과 (2026-07-13)

## 대표 파일

| 용도 | 파일 | SHA-256 |
| --- | --- | --- |
| 원본 SolidWorks 다중 시트 | `work/0000_A_DRP125_CP_ALL_260626_ORIGINAL_TEST_260711.dwg` | `3C7735569B7EBAC8300225A81CEFB441562AB656770E5FC8868099B559A959B2` |
| native GMTITLE 15장 기준본 | `portable-e2e/output/swtitle_portable_result_260712.dwg` | `1F2D3BA224A27E141CB64D79DC4FE75DCC00819D2F07751D83E8380CCE17AA23` |

검사 전후 두 SHA-256은 동일했다.

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

다음 네 모드를 별도 GstarCAD 프로세스에서 실행했다.

| 모드 | 결과 |
| --- | --- |
| `MATERIALIZE_RAW` | XREF 0, 최상위 치수 143, 원본 title/frame 15/15, 다음 단계 TITLE |
| `NATIVE_GUARD` | deep native 참조 30 감지, XREF 1 유지, 도면 변경 차단 |
| `DOWNSTREAM` | GMTITLE OK, DIMSTYLE OK, 치수 의미 보존, A4 Layout 15개 |
| `REOPEN` | 저장 후 상태 유지, Layout 15개, 통합 감사 OK, `DBMOD=0` |

배포 ZIP의 `install.ps1`로 생성한 `SWCAD_Workflow_Load.lsp`도 실제 GstarCAD에서 검사했다. 테스트 전에 저장된 루트는 개발 저장소였지만, 루트 로더가 이를 패키지 경로로 갱신했고 패키지 내부 앱 버전과 세 공개 명령, 상태 XRecord가 정상 로드됐다.

치수 의미 검사는 143개 핸들의 raw measurement, `DIMLFAC`, 상·하 공차와 표시 플래그를 전후 비교한다. 최초 진단에서 핸들 `37C1`의 불일치를 확인했고, 전체 비교에서는 73개 핸들의 의미 오버라이드 변화가 감지됐다. 통합 앱은 이 73개만 선택 복원했으며 이후 143개가 전부 일치했다. 복원 직후와 최종 검증에서 Mechanical fit 데이터 및 스타일 감사도 통과했다.

## 재실행 조건

- 앱 Layout 접두사 수: 15
- 기대 GMTITLE 도면틀 수: 15
- Layout당 뷰포트: 1
- 모든 Layout 용지: A4
- 저장 후 `DIMSTYLE=OK`, `DIMENSION_SEMANTICS=PRESERVED`, `LAYOUT=OK`
- 최종 상태: `COMPLETE`

## 실행 명령

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\swcad-workflow\run_static_preflight.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\swcad-workflow\run_xref_materialize_matrix.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\swcad-workflow\run_workflow_loader_probe.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\swcad-workflow\run_workflow_integration_probe.ps1
```

실제 DWG 산출물과 런타임 로그는 Git에 넣지 않고 `work/swcad-workflow-tests`와 `tmp/swcad-workflow-integration`에 둔다.
