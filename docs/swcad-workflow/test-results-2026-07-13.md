# SWCAD Workflow 검증 결과 (2026-07-13)

> 이 문서는 2026-07-13 성능·구조 회귀의 역사 기록이다. 2026-07-14부터 Layout은 `SWCAD-SHEET-###`/`MANUAL_FRAME_COORDINATES` 대신 원본 파일명과 `XREF_SOURCE_FILENAME_COORDINATES`를 사용한다. 최신 자동 정리·이름 정책과 재열기 결과는 `source-layout-cleanup-test-2026-07-14.md`를 기준으로 한다.

## 대표 파일

| 용도 | 파일 | SHA-256 |
| --- | --- | --- |
| 원본 SolidWorks 다중 시트 | `work/_preserved_20260714/fixtures/0000_A_DRP125_CP_ALL_260626_ORIGINAL_TEST_260711.dwg` | `3C7735569B7EBAC8300225A81CEFB441562AB656770E5FC8868099B559A959B2` |
| native GMTITLE 15장 기준본 | `portable-e2e/output/swtitle_portable_result_260712.dwg` | `1F2D3BA224A27E141CB64D79DC4FE75DCC00819D2F07751D83E8380CCE17AA23` |
| 중첩 시트 묶음 회귀 기준본 | `work/_preserved_20260714/fixtures/sheet_wrapper_source_fixture_260713.dwg` | `3590FF177D46988BF7E319720A540D71CF3AE98D696F0896D85B7F2FD5E49D7E` |
| 사용자 확인 30장 완성본 | `work/_preserved_20260714/fixtures/Verify_XRef Sw WorkFlow Test_260713.dwg` | `91DD5BAED6851EE6B776A8D1B5A6B58F52C5C272EA5E570F8652A2E7B386DF6C` |

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

기존 네 모드와 중첩 시트 회귀 두 모드를 별도 GstarCAD 프로세스에서 실행했다. 중첩 XREF 수량 검사는 `260714-read-scan-cache-batch-queue-1`에서 보이는 GstarCAD의 분리된 새 테스트 도면으로 다시 실행했다.

| 모드 | 결과 | 검증 시점 |
| --- | --- | --- |
| `MATERIALIZE_RAW` | XREF 0, 최상위 치수 143, 원본 title/frame 15/15, 다음 단계 TITLE | 기존 기준 회귀 |
| `MATERIALIZE_WRAPPED_XREF` | XREF 1에서 시작, 시트 묶음 0, 최상위 치수 254, 원본 title/frame 30/30, bbox 보존, 다음 단계 TITLE | 현재 변경 |
| `NATIVE_GUARD` | 최상위 DR frame/title 15/15 및 target 30 감지, XREF 1 유지, 도면 변경 차단 | 현재 변경 |
| `SHEET_WRAPPERS` | 부분 materialize 기준 묶음 10→0, 치수 0→254, title/frame 30/30, bbox 보존 | 현재 변경 |
| `DOWNSTREAM` | GMTITLE OK, DIMSTYLE OK, 치수 의미 보존, A4 Layout 15개 | 기존 기준 회귀 |
| `REOPEN` | 저장 후 상태 유지, Layout 15개, 통합 감사 OK, `DBMOD=0` | 기존 기준 회귀 |

### 30장 성능 회귀 (2026-07-14)

동일한 `sheet_wrapper_source_fixture_260713.dwg`를 새 도면에 XREF로 붙인 뒤 `MATERIALIZE_WRAPPED_XREF`를 별도 GstarCAD 프로세스에서 반복했다. 각 실행은 XREF 0, wrapper 0, 최상위 치수 254, 원본 title/frame 30/30, bbox 보존, 원본 SHA-256 불변을 통과했다.

| 측정값 | 최적화 전 | 최적화 후 | 단축 |
| --- | ---: | ---: | ---: |
| 공개 `SWCADRUN` 전체 | 124,921 ms | 53,833 ms | 56.9% |
| `SWCADRUN` 상태 판정용 읽기 | 24,590 ms | 855 ms | 96.5% |
| 공개 `SWCADSTATUS` 전체 | 28,674 ms | 842 ms | 97.1% |
| `SWCADRUN` 물리 INSERT 전체 스캔 | 2회 | 2회 | 명령 전/후 1회씩 유지 |
| `SWCADSTATUS` 물리 INSERT 전체 스캔 | 1회 | 1회 | 명령당 1회 유지 |

주요 변경은 명령 단위 읽기 캐시, GMTITLE INSERT 목록 공유, 시트 변환 대상 큐, 같은 블록 정의의 wrapper 증거 재사용, 모델 전체 COM 순회 대신 `INSERT`/`DIMENSION` 선택집합 사용이다. 중간 상태에서는 `INSERT` 기반의 가벼운 wrapper 존재 판정을 유지하며, 실제 변환 직후와 최종 `SWCADVERIFY`에서 결과 안전 조건을 깊게 검사한다.

최적화 후 전체 53.8초 중 상태 판정용 읽기는 0.9초 미만이다. 따라서 다음 병목은 중복 스캔이 아니라 GstarCAD 커널의 BIND, EXPLODE, REGEN, bbox 안전 검사다. 이 구간은 도면 내용과 좌표 보존 계약에 직접 연결되므로 별도 증거 없이 생략하지 않는다.

### 30장 GMTITLE 단계 반복 진단 (2026-07-14)

`work/XRef Sw WorkFlow Test_260715.dwg`에서 최적화 버전으로 상태를 다시 확인했다. 원본 표제란/도면틀은 `0/0`이고 target 제목블록/도면틀/짝/native-like는 `30/30/30/30`으로 변환 구조 자체는 완료됐다.

다만 A4 도면틀 `14B4E`와 `14B3B`가 X 방향으로 `2.54242991 mm`, Y 방향으로 도면 전체 높이 `297 mm`만큼 겹쳤다. 이 때문에 `WARN_TARGET_FRAME_SELECTION_RISK`가 발생하고 TITLE 완료 조건의 `overlap-warning-count=0`을 통과하지 못했다. `SWTITLEPREPARE`는 도면을 이동하지 않으므로 정리 후보 없이 끝나며, 통합 안내가 다시 `SWCADRUN`을 제시해 TITLE 단계가 반복됐다.

이는 스캔 캐시나 GMTITLE 변환 손상이 아니라 겹친 수동 배치와 완료 판정 안내 사이의 중단 상태 누락이다. 겹침이 남은 동안 `SWCADRUN`을 반복하지 않으며, 전체 시트 이동 또는 명시적인 수동 검토 상태가 필요하다. 겹침 허용치를 늘려 실제 전체 높이 겹침을 숨기지는 않는다.

### 30장 완성본의 과거 수량 기록 호환

사용자가 저장하고 모든 GMTITLE 더블클릭을 확인한 `work/_preserved_20260714/fixtures/Verify_XRef Sw WorkFlow Test_260713.dwg`는 직접 수정하지 않고, `work/swcad-workflow-tests/verify_xref_legacy_count_rebase_probe.dwg` 복사본에서 검사했다.

- 과거 XData 기대 도면틀: `A3=36, A4=5`, 합계 41
- 과거 XData 기대 제목 보유 시트: `A3=30, A4=0`, 합계 30
- 실제 target 도면틀/제목블록: `A3=26, A4=4`, 각각 합계 30
- 최종 구조 계측: XREF/wrapper `0/0`, 최상위 치수 `254`, target pair/native-like `30/30`
- 호환 판정 비활성 상태: `SWTITLEVERIFY_FINAL_FAIL`
- 읽기 전용 호환 판정 활성 상태: `SWTITLEVERIFY_FINAL_OK`, XData/native 구조/`DBMOD` 불변
- 교정 전 공개 `SWCADVERIFY`: `SWCADVERIFY_FINAL_OK`, XData/native 구조/`DBMOD` 불변
- 진단 복사본 영구 교정 후: 기대 수량 `26/4`, 분류기 표식 60개, native 구조 불변, 저장 후 `DBMOD=0`
- 공개 통합 감사: GMTITLE/DIMSTYLE/Layout 30장 모두 OK

같은 변경으로 중첩 XREF를 새 도면에 붙여 실제 `SWCADRUN` materialize를 다시 수행했다. XREF와 시트 wrapper는 0개가 됐고, 최상위 치수 254개와 모델 bbox를 보존하면서 원본 제목블록/도면틀을 정확히 `30/30`으로 셌다. 과거 41장 중 추가 11개는 결합 블록의 상위 이름에 `_A3`/`_A4`가 포함된 기어·표·내용 블록 오탐이었다.

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

## 당시 재실행 조건

아래 값은 2026-07-13 버전의 회귀 기준이다. 최신 출처 기반 이름·소유권 조건은 `source-layout-cleanup-test-2026-07-14.md`에 기록했다.

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
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\swcad-workflow\run_legacy_count_rebase_probe.ps1
```

실제 DWG 산출물과 런타임 로그는 Git에 넣지 않고 `work/swcad-workflow-tests`와 `tmp/swcad-workflow-integration`에 둔다.
