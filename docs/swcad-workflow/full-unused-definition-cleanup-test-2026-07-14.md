# SWCAD 전체 미사용 이름 정의 정리 검증 (2026-07-14)

## 목표

- 기존 `$0$` 중심 4개 범주 정리를 GstarCAD의 포괄적 미사용 이름 정의 정리로 교체한다.
- Layout 생성 뒤 실제 참조 관계가 확정된 상태에서 자동 실행한다.
- 길이 0 형상, 빈 문자 객체, 분리된 데이터와 가시 객체는 삭제하지 않는다.
- 무결성 차이 또는 비수렴 시 전체 정리를 한 번의 UNDO로 복구한다.
- 저장·닫기·재열기 뒤 `SWCADVERIFY_FINAL_OK`와 수동 PURGE 추가 삭제 0개를 확인한다.

현재 검증 버전은 `260715-full-unused-purge-13`, 정책은 `ALL_UNUSED_NAMED_DEFINITIONS_V5`다. 공개 명령은 `SWCADSTATUS`, `SWCADRUN`, `SWCADVERIFY` 세 개로 유지한다.

## 기준 파일과 복사본

원본은 저장만 하고 이후 테스트 변경을 적용하지 않는다.

```text
원본:
work/XRef Sw WorkFlow Test_260715.dwg

검증 복사본:
work/swcad-workflow-tests/full-unused-purge-260714/
  XRef Sw WorkFlow Test_260715_full_unused_purge_copy.dwg
```

복사 직후 두 파일의 크기와 수정시각은 각각 `3,013,465 bytes`, `2026-07-14 14:47:47`로 일치했다. 열린 원본은 GstarCAD 파일 잠금 때문에 SHA-256을 읽지 못했으며, 저장 뒤 `Copy-Item`으로 별도 복사본을 만들었다.

## 구현 범위

native `-PURGE`의 다음 14개 이름 정의 범주만 명시적으로 순회한다.

```text
BLOCK, DIMSTYLE, GROUP, LAYER, LINETYPE, MATERIAL, MLEADERSTYLE,
PLOTSTYLE, SHAPE, TEXTSTYLE, MLINESTYLE, TABLESTYLE, VISUALSTYLE, REGAPP
```

GstarCAD 2024 Korean의 첫 `-PURGE` 프롬프트에서 길이 0 형상, 빈 문자 객체, 분리된 데이터가 별도 옵션임을 확인했다. 이 세 옵션과 `All`은 코드에서 호출하지 않는다.

각 반복 전후에 symbol table과 Named Object Dictionary를 재귀 스냅샷하고, handle까지 포함한 전체 목록이 같은 반복까지 최대 32회 수행한다. 저장·재열기 감사에는 정의의 종류·경로·이름 정체성 지문을 사용하고 전체 handle 지문은 재등록 진단에 사용한다. 성공 상태 기록 뒤 저장까지 포함한 정체성 고정점은 별도로 최대 4회 확인한다. 실제 정의 정체성이 추가·삭제되면 저장된 DB로 재기준화하고, 다음 저장에서 같은 정체성으로 고정되지 않거나 도면 무결성이 달라지면 전체 UNDO를 실행한다.

GMTITLE 무결성은 frame/title/attribute의 전체 DXF와 XData, persistent reactor, extension dictionary의 재귀 내용, native 대상 handle·종류를 포함한다. 세션마다 달라지는 ENAME은 영구 handle로 정규화하므로 저장·닫기·재열기 뒤에도 같은 구조인지 비교할 수 있다.

정리 상태를 기록할 때 `SWCAD_WORKFLOW_STATE` XRecord 자체는 새 handle로 교체된다. 이 항목의 handle을 그대로 정의 지문에 넣으면 성공 기록 직후 자기 자신 때문에 검증이 실패하므로, 항목의 존재·종류는 유지해 검사하고 handle만 `<WORKFLOW-STATE-XRECORD>`로 정규화한다. GstarCAD의 `DICTNEXT`는 항목 객체는 반환하지만 부모 사전의 그룹 3 키 이름을 생략하므로, 부모 `DICTIONARY`의 원본 `(3 . 이름)`과 `(350/360 . 객체)` 쌍을 먼저 파싱해 실제 경로를 만든다. 이 원본 쌍을 제공하지 않는 CAD 엔진에서만 기존 `DICTNEXT` 순회를 fallback으로 사용한다.

## 현재 검증 결과

- LISP 괄호 균형: 통과
- PowerShell 구문: 통과
- canonical 모듈 해시: 통과
- 공개 명령 3개 표면: 통과
- 금지된 `-PURGE All`, 길이 0, 빈 문자, 분리 데이터 옵션 정적 검사: 통과
- GstarCAD에서 loader `260714-full-unused-purge-7` 로드: 통과
- `-7` 실도면 정리: 이름 정의 `1,036 -> 1,036`, 실제 삭제 `0`, 자동 생성 `0`, handle 재등록 `0`, 도면 무결성 지문 `OK`
- `-7` 한계 재현: 성공 상태 XRecord를 쓴 뒤 두 번째 저장에서 정의 정체성 지문이 `1036:873147:524395`에서 `1036:412585:297761`로 바뀌어 `SWCADVERIFY_FINAL_FAIL`. 도면 객체나 GMTITLE/Layout 무결성 변화가 아니라 상태 저장 뒤 내부 정의 정규화 순서 문제로 판정
- `-8` 실도면 재현: 상태 저장 4회 모두 `NOD/14DA6 → 14DAF → 14DB4 → 14DB9 → 14DBE`처럼 한 항목의 경로가 바뀌어 `FAILED_STATE_SAVE_NOT_CONVERGED`; 전체 정리 UNDO는 성공
- 원시 NOD 검사: 위 핸들형 경로는 별도 임시 정의가 아니라 실제 키 `SWCAD_WORKFLOW_STATE`인 XRecord였다. `DICTNEXT` 반환값에는 그룹 3 키가 없고, 부모 NOD `entget`에는 `(3 . SWCAD_WORKFLOW_STATE)`와 해당 350 객체가 정상 존재함
- `-9` 수정: 부모 사전의 실제 키/객체 쌍을 우선 파싱하고 `NOD/SWCAD_WORKFLOW_STATE` 경로에서만 handle을 고정 토큰으로 정규화. 일반 `ACAD_CIP_PREVIOUS_PRODUCT_INFO` XRecord 등 다른 항목은 제외하지 않음
- GstarCAD에서 loader `260715-full-unused-purge-9` 로드: 통과
- `-9` 읽기 전용 실도면 진단: NOD의 핸들형 XRecord 키 후보 `0`, 이름 정의 수 `1,036`, 전체 무결성 지문 `26703:84270:933478`
- `-9` 버전 재시도 게이트 실도면 진단: 저장된 실패 버전 `260714-full-unused-purge-8`, 현재 LSP `260715-full-unused-purge-9`, `RESOURCE_CLEANUP_RETRY_ALLOWED=YES`; `SWCADSTATUS`는 현재 버전에서 1회 재시도를 안내함. 같은 버전에서 다시 실패하면 자동 재실행을 차단함
- 배포 패키지 smoke test: `dist/SWCAD-Workflow-0.1.0-full-purge-rc9.zip` 생성 성공. 로더·통합 LSP·세 canonical 모듈·README·구조 및 정리 검증 문서가 모두 포함됨
- `-9` 정리 전 `SWCADVERIFY`: XREF `0`, 중첩 시트 묶음 `0`, GMTITLE 최종 `OK`, DIMSTYLE `OK`, Layout `30/30 OK`. 현재 버전 정리 지문이 아직 없으므로 전체 정리만 `CHECK_NEEDED`, 통합 최종 결과는 예상대로 `SWCADVERIFY_FINAL_FAIL`
- GMTITLE 단독 최종 로그: 대상 도면틀/제목블록/쌍 `30/30/30`, A3 `26`, A4 `4`, 원본 후보·잔여물·누락 tag·native-like 아닌 쌍·형상 경고 모두 `0`, `SWTITLEVERIFY_FINAL_OK`
- 원본 `work/XRef Sw WorkFlow Test_260715.dwg` SHA-256: `46043A041C38F1FAE565B6C9DBF62028A73C6AB3F5234C8138F17A0F920D8269`
- 정리 전 안전 복사본 `work/bak_XRef Sw WorkFlow Test_260715_before_fixedpoint_cleanup_260714.dwg` SHA-256: `4343E1718C2A6D3DB8F1C4069410FB3110571A13A403599237CCFF7CA1946752`
- `-9` 실도면 정리 및 저장 고정점 재검증은 이후 `-10`~`-13` 조사로 대체했다.
- 읽기 전용 이름 정의 스냅샷: table `4,106`, dictionary `227`, 합계 `4,333`
- 읽기 전용 Layout 스냅샷: paper layout `2`
- 읽기 전용 전체 무결성 지문 생성: `30:447216:267363`
- 정의·전체 무결성 스냅샷 연속 실행 결정성: `T/T`
- 확장 GMTITLE 원시 구조를 포함한 전체 무결성 스냅샷 연속 실행: `YES`, 지문 `30:447216:267363` 2회 일치. 현재 복사본에는 아직 target GMTITLE 쌍이 없으므로 실제 A2/A3/A4 쌍의 원시 구조 보존은 workflow 변환 후 다시 검증한다.
- workflow 상태 XRecord handle 정규화: 상태 경로는 `<WORKFLOW-STATE-XRECORD>`, 일반 `NOD/OTHER` 경로의 시험 handle은 `ABC`로 유지.
- 정규화 뒤 이름 정의 4,333개 스냅샷 연속 실행: `YES`, 지문 `4333:137162:307264`.
- `-10` 정리 저장 상태와 재열기 상태의 비 APPID 정체성 차이를 전체 후보별로 역산했다. 저장 상태 `1003:610255:70585`, 재열기 상태 `1004:543277:772984`의 유일한 차이는 `TABLE|BLOCK|*U4501`이었다.
- `*U4501` 읽기 전용 구조 진단: DXF 익명 플래그 `70=1`, 블록 내부 객체 `0`, 전체 블록 공간의 직접 참조 `0`, XREF/Layout 정의 아님. GstarCAD가 재열기 때 만든 빈 익명 블록 테이블 행으로 판정했다.
- `-12` 정책은 APPID, `*ACTIVE` VPORT, 익명 플래그와 `*U숫자` 이름을 가지면서 내부 객체 수가 0인 블록만 저장·재열기 안정 지문에서 제외한다. PURGE 실행, 전체 정의 지문, 별도 진단 지문에서는 계속 추적한다.
- `-12` 로더 실도면 로드와 읽기 전용 안정 지문 계산: 통과. 재열기 현재 안정 지문 `1002:306788:552546`, 별도 빈 익명 블록 지문 `1:992147:761670`.
- `-13`은 사용자 이름 VPORT를 제외하지 않도록 세션 예외를 `TABLE|VPORT|*ACTIVE`로 한정하고, 정리 전에 세션성 정의 정체성을 보관해 삭제 뒤 안정 삭제 샘플에 빈 `*U` 블록이 잘못 섞이지 않게 했다.
- `-13` 정적 preflight: LISP 괄호, PowerShell 구문, canonical 모듈 해시, 공개 명령 3개, 14개 이름 정의 범주와 금지 옵션 계약 모두 통과.
- `-13` 배포 패키지 smoke test: `dist/SWCAD-Workflow-0.1.0-full-purge-rc13.zip`. 최종 SHA-256은 ZIP 내부 문서에 적지 않고 빌드가 생성하는 외부 `dist/SWCAD-Workflow-0.1.0-full-purge-rc13.zip.sha256`에서 확인한다.
- `-13`을 현재 작업본에 로드하고 읽기 전용 `SWCADSTATUS` 실행: 통과, 약 `6,416 ms`, 권장 다음 단계 `SWCADRUN`. 실행 전 `DBMOD=0` 확인.

현재 실제 정리 대상은 `work/bak_XRef Sw WorkFlow Test_260715.dwg`다. 정리 직전 별도 안전 복사본 `work/bak_XRef Sw WorkFlow Test_260715_before_v5_cleanup_260715.dwg`의 SHA-256은 `5900CBD30219C636FB93A782497367C9834187430CC85E5954AFCDAD49C5FAF5`다. 원본 `work/XRef Sw WorkFlow Test_260715.dwg`의 SHA-256은 계속 `46043A041C38F1FAE565B6C9DBF62028A73C6AB3F5234C8138F17A0F920D8269`다.

별도 A2 편집창 검증에는 이력에 해시가 고정된 `portable-e2e/output/swtitle_portable_result_260712.dwg`를 직접 수정하지 않고, 같은 SHA-256 `1F2D3BA224A27E141CB64D79DC4FE75DCC00819D2F07751D83E8380CCE17AA23`의 `work/a2_gmtitle_editor_check_copy_260715.dwg`를 사용한다. 이 기준본은 A2/A3/A4 `1/12/2` native GMTITLE 결과본이다.
- 정렬 목록 차집합 런타임 검사: `("A" "D")`
- 실행 대상 이름 정의 범주 수: `14`

## 2026-07-16 최종 실도면 실행 결과

검증 전용 새 복사본 `work/bak_XRef Sw WorkFlow Test_260715_v5_run_260716.dwg`에서 `SWCADRUN`을 실행했다. 실행 시간은 약 `236,270 ms`였고 명령 프롬프트로 정상 복귀했다. 실행 직후 `SWCADVERIFY`는 다음 항목을 모두 통과해 `SWCADVERIFY_FINAL_OK`를 반환했다.

- XREF `0`
- 중첩 시트 묶음 `0`
- GMTITLE 최종 `OK`
- DIMSTYLE 감사 `OK`
- 전체 미사용 이름 정의 정리 감사 `OK`
- Layout 모드 `XREF_SOURCE_FILENAME_COORDINATES`
- Layout `30`개와 A4 Layout 검사 `30/30 OK`

실행 뒤 `DBMOD=0`을 확인하고 도면을 닫았다가 다시 열었다. 현재 `-13` 로더를 다시 로드한 뒤 실행한 `SWCADVERIFY`도 `SWCADVERIFY_FINAL_OK`였다. 재열기 상태의 `cleanup_state_probe.lsp` 결과는 다음과 같다.

```text
VERSION=260715-full-unused-purge-13
RESOURCE_CLEANUP=OK
RESOURCE_CLEANUP_POLICY=ALL_UNUSED_NAMED_DEFINITIONS_V5
RESOURCE_CLEANUP_PASSES=2
RESOURCE_CLEANUP_REMOVED=35
RESOURCE_CLEANUP_ZERO_PASS=YES
RESOURCE_CLEANUP_STABLE_REMOVED_SAMPLE=
RESOURCE_CLEANUP_POST_SAVE_REMOVED_IDENTITIES=0
RESOURCE_CLEANUP_POST_SAVE_ADDED_IDENTITIES=0
RESOURCE_CLEANUP_POST_SAVE_HANDLE_REREGISTERED=0
RESOURCE_CLEANUP_STATE_SAVE_STABILIZATION_PASSES=1
RESOURCE_CLEANUP_STATE_SAVE_REBASE_COUNT=0
RESOURCE_CLEANUP_VERIFY=OK
RESOURCE_CLEANUP_RETRY_ALLOWED=NO
```

저장 상태와 재열기 상태의 전체 무결성 지문은 모두 `26703:84270:933478`, 안정 이름 정의 지문은 모두 `1002:306788:552546`로 일치했다. 제거된 35개 샘플은 세션 재등록 대상 APPID였고, 안정 정의 삭제 샘플은 비어 있다. GstarCAD가 재열기 때 다시 만든 native XData APPID, `*ACTIVE` VPORT 또는 빈 세션 `*U` 블록은 진단에는 남기되 저장·재열기 안정 지문에서는 제외하는 정책이 의도대로 동작했다.

`swcad_title_verify_summary_last.txt`의 GMTITLE 결과는 도면틀/제목블록/쌍 `30/30/30`, A3 `26`, A4 `4`이며 원본 표제란·도면틀·잔여물·누락·비 native 쌍은 모두 `0`이다. 수동 더블클릭 점검에서는 다음 세 대표 용지가 모두 일반 고급 속성 편집기가 아닌 GMTITLE 표 형식의 `속성 블록 편집` 창으로 열렸다.

- A3: 실행 결과 복사본에서 `Sheet=A3` 확인
- A4: 실행 결과 복사본에서 `Sheet=A4` 확인
- A2: 해시 고정 별도 복사본에서 `Sheet=A2` 확인

편집창을 열고 취소하면 GstarCAD 내부 상태 때문에 `DBMOD=21`이 될 수 있으므로, 수동 점검 뒤에는 저장하지 않고 닫아 점검 자체의 변경을 폐기했다. 실행 결과 복사본의 현재 SHA-256은 `4E8DE3969C9AA051C938A2CA10669A3C93BF4823D73072D5EC57E0C06F79F603`이다.

원본 `work/XRef Sw WorkFlow Test_260715.dwg`의 SHA-256은 실행 뒤에도 `46043A041C38F1FAE565B6C9DBF62028A73C6AB3F5234C8138F17A0F920D8269`로 유지됐다. 안전 복사본 `work/bak_XRef Sw WorkFlow Test_260715_before_v5_cleanup_260715.dwg`도 `5900CBD30219C636FB93A782497367C9834187430CC85E5954AFCDAD49C5FAF5`로 유지됐다.

## 2026-07-19 수동 PURGE 최종 확인

재열기 검증까지 마친 `work/bak_XRef Sw WorkFlow Test_260715_v5_run_260716.dwg`에서 GstarCAD의 `PURGE` 대화상자를 직접 열었다. `제거할 각 항목 확인`과 `내포된 항목 제거`는 켜고, 범위 밖인 `길이가 0인 형상과 빈 문자 객체 소거` 및 `분리 데이터 자동 제거`는 끈 상태로 명명된 객체만 검사했다.

첫 목록에는 다른 범주의 하위 후보 없이 블록 `*U4501` 하나만 표시됐다. 이 항목은 앞선 정적 진단에서 익명 플래그 `70=1`, 내부 객체 `0`, 직접 참조 `0`으로 확인한 GstarCAD 세션용 빈 익명 블록이다. 확인 창에서 해당 항목 소거를 승인한 뒤 목록에서 사라졌다. 이어서 `모두 소거`를 다시 실행했을 때 추가 확인 창이나 하위 후보가 나오지 않아 지원 대상 추가 삭제 `0`개를 확인했다. 대화상자를 닫은 직후 `DBMOD=0`이므로 이 세션 항목의 제거는 저장 도면 데이터를 변경하지 않았다.

최종 배포 빌드는 `dist/SWCAD-Workflow-0.1.0.zip`과 외부 체크섬 `dist/SWCAD-Workflow-0.1.0.zip.sha256`을 생성했다. 체크섬은 실제 ZIP의 SHA-256과 일치했고, 패키지에는 설치 파일·통합 LSP·세 canonical 모듈·README·검증 문서만 포함되며 DWG/BAK/DWL 또는 임시 진단 출력은 포함되지 않았다.

## 남은 완료 기준

- [x] 복사본에서 전체 workflow 완료
- [x] 저장 상태와 재열기 상태의 안정 이름 정의 차이 0
- [x] Layout/viewport와 모델/종이공간 무결성 유지
- [x] 대표 A2/A3/A4 GMTITLE 더블클릭 편집 정상
- [x] 저장·닫기·재열기 후 `SWCADVERIFY_FINAL_OK`
- [x] 원본 파일 수정 없음 확인
- [x] 수동 PURGE 모든 항목에서 지원 대상 추가 삭제 0개
- [x] 최종 문서·배포 패키지 검사 뒤 커밋 및 푸시
