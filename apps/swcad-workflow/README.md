# SWCAD Workflow

SolidWorks 원본 도면이 연결된 XREF 호스트를 다음 순서로 처리하는 통합 MVP입니다.

```text
XREF 작업본 생성/결합
→ 중첩 시트 묶음과 치수 내용 블록 materialize
→ GMTITLE 도면틀·표제란 변환
→ DIMSTYLE·맞춤공차 정규화
→ 원본 파일명 A4 Layout 생성
→ 전체 미사용 이름 정의 정리
→ 통합 검증
```

## 로드

GstarCAD Mechanical에서 아래 파일을 `APPLOAD`합니다.

```text
apps\swcad-workflow\swcad_workflow_load.lsp
```

공개 명령은 세 개입니다.

```text
SWCADSTATUS
SWCADRUN
SWCADVERIFY
```

`SWCADRUN`은 현재 상태에서 안전한 다음 단계 하나만 실행합니다. 출력에는 `1/6 입력 준비 → 2/6 GMTITLE → 3/6 치수 → 4/6 Layout → 5/6 전체 정리 → 6/6 검증` 중 현재 위치와 실행 전후 단계가 표시됩니다. `ABORT_`, `ERROR_`, `WARN_` 결과에서는 반복 실행을 중지하고 원인을 확인해야 하며, `SWCADSTATUS`가 다시 `SWCADRUN`을 권장할 때만 계속합니다.

DIMSTYLE 단계는 실행 전후의 치수 측정값, `DIMLFAC`, 상·하 공차 의미를 핸들별로 비교합니다. 기존 SWAUTO가 native Mechanical fit을 붙이며 오버라이드를 바꾸는 경우 달라진 치수만 복원하고, 완전히 일치할 때만 다음 단계로 이동합니다.

## 수동 배치와 Layout 좌표

통합 앱은 XREF를 자동으로 이동하지 않습니다. 사용자가 XREF 상태에서 원하는 위치와 출력 순서로 배치한 뒤 변환을 시작합니다.

```text
사용자 수동 XREF 배치
→ 원본 DWG 파일명·좌표·순서를 저장한 뒤 materialize
→ GMTITLE·DIMSTYLE 변환
→ 최종 GMTITLE 도면틀 bbox 자동 계산
→ 원본 파일명 Layout 자동 생성
```

- XREF 축척은 `1`, 회전은 `0`을 사용합니다.
- 첫 도면의 왼쪽 아래를 `(0,0)`에 두는 것은 선택 사항입니다.
- 같은 행은 왼쪽에서 오른쪽, 다른 행은 위쪽에서 아래쪽 순서로 Layout 탭을 만듭니다.
- `SWCADSTATUS`는 Layout 생성 전에 예정 수량과 좌표를 최대 12개까지 보여줍니다.
- 실제 생성에는 미리보기와 같은 전체 좌표 계획을 사용합니다.
- 저장 후 `XREF_SOURCE_FILENAME_COORDINATES` 모드, 계획 수량, 좌표 지문, Layout 소유권 목록이 유지돼야 최종 검증을 통과합니다.
- Layout 생성 뒤 도면틀 위치가 바뀌면 좌표 지문이 달라져 다음 `SWCADRUN`에서 Layout을 다시 생성합니다.

XREF를 BIND하기 직전에 각 최상위 참조의 파일명 stem, 참조명, 핸들, bbox, 배치 순서를 `SWCAD_WORKFLOW_STATE`에 저장합니다. 이미 materialize된 도면에서는 고유한 GMTITLE `File Name`, 검증된 `$0$` 결합 블록 접두사, `FILE NO`, `Sheet`, 도면틀 핸들 순으로 이름을 복구합니다.

## XREF 지원 범위

- 원본 SolidWorks DWG XREF만 자동 materialize합니다.
- 축척 `1`, 회전 `0`인 모델 공간 XREF를 지원합니다.
- `BIND` 후 최상위 XREF 참조를 한 번 `EXPLODE`합니다.
- 도면·치수·DR 도면틀·DR 표제란을 함께 품은 시트 묶음은 바깥 INSERT만 한 단계씩 풉니다.
- DIMSTYLE이 모든 치수를 처리할 수 있도록 DR 도면틀·표제란을 제외한 치수 포함 내용 블록만 반복 분해합니다.
- 이미 일부 BIND/EXPLODE가 끝난 도면은 `SHEET_WRAPPERS` 단계에서 같은 처리를 이어갑니다.
- XREF 최상위에 DR 도면틀과 DR 표제란이 함께 있는 완성 native GMTITLE은 링크 보호를 위해 자동 처리하지 않습니다.
- 시트 묶음 안의 이름만 같은 DR 블록이나 `POINT`를 가리키는 깨진 XData는 native 증거로 보지 않습니다.
- 중첩 XREF와 최상위에 연결되지 않은 XREF 정의가 있으면 원본을 건드리지 않고 중단합니다.

30장 대표 파일에서는 시트 묶음 `10 → 0`, 최상위 치수 `0 → 254`, 원본 표제란/도면틀 `30/30`을 확인했습니다. 과거 도면틀 수 `41`은 중첩 블록의 상위 이름에 포함된 `_A3`/`_A4`와 기어·표 객체 11개를 용지로 잘못 센 값이었습니다. 현재는 결합 블록의 마지막 이름과 실제 도면틀 형상을 함께 검사합니다. 명령 단위 인벤토리와 대상 큐를 적용한 동일 30장 실측에서 `SWCADRUN`은 `124.9초 → 53.8초`, `SWCADSTATUS`는 `28.7초 → 0.84초`로 줄었습니다. 남은 시간의 대부분은 GstarCAD의 BIND, 다단계 EXPLODE, REGEN, bbox 보존 검사입니다.

구버전으로 이미 완성된 도면에 `41` 같은 과거 기대 수량이 남아 있어도 `SWCADVERIFY`는 도면을 수정하지 않습니다. XREF·wrapper가 0이고 DIMSTYLE과 Layout 좌표 감사까지 정상이며, 모든 target frame/title이 1:1 native 쌍이고 원본 후보·중복 쌍·형상 경고가 없고 저장된 제목 보유 시트 총수와 실제 총수가 같을 때만 실제 `A2/A3/A4` 수량을 읽기 전용 호환값으로 사용합니다. GMTITLE 단독 검증은 이 호환을 기본 사용하지 않으며, 현재 분류기 표식이 있는 도면의 수량 불일치는 호환 처리하지 않고 실패합니다.

첫 변경 전에 GMTITLE 모듈의 다른 이름으로 저장 창을 사용해 사용자가 지정한 독립 작업본을 만듭니다. 원본 DWG와 XREF 원본은 저장하지 않습니다.

## 전체 미사용 이름 정의 정리

Layout까지 만들어 실제 참조 관계가 확정된 뒤 GstarCAD의 native `-PURGE` 판정을 범주별로 반복합니다.

- 대상은 블록, 치수 스타일, 그룹, 도면층, 선종류, 재질, 다중 지시선·플롯·문자·여러 줄·테이블·비주얼 스타일, 쉐이프, 등록 응용프로그램의 14개 이름 정의 범주입니다.
- 길이 0 형상, 빈 문자 객체, 분리된 데이터는 명령 목록에 넣지 않으므로 가시 객체나 고아 데이터를 직접 삭제하지 않습니다.
- 등록 응용프로그램도 GstarCAD가 XData와 extension dictionary 참조가 없다고 판정한 항목만 삭제됩니다.
- 의존 정의가 뒤늦게 풀리는 경우를 위해 최대 32회 안에서 반복하고, 전체 정의 목록이 같은 삭제 0개 반복에 도달해야 완료합니다.
- 각 반복 뒤 모델·종이공간 객체 수와 bbox, Layout·viewport, 치수값·공차·축척, 출처/작업 상태를 비교합니다.
- GMTITLE은 native 판정 결과만 보지 않습니다. frame/title/attribute의 원시 DXF와 XData, persistent reactor, extension dictionary, native 대상 handle을 저장·재열기에도 안정적인 handle 기준으로 비교합니다.
- 명령 오류, 무결성 차이, 비수렴, 첫 저장 실패, 저장 직후 실제 정의의 종류·경로·이름 변화가 발생하면 전체 정리 UNDO를 한 번 실행하고 완료를 차단합니다.
- 정리 반복 안에서는 handle까지 포함한 전체 목록이 고정돼야 합니다. 저장·재열기 감사에서는 종류·경로·이름 정체성을 기준으로 검사하고, GstarCAD가 같은 정의를 새 handle로 재등록한 경우는 별도 진단값으로 남깁니다.
- GstarCAD가 재열기 때 다시 등록하는 APPID, 세션의 `*ACTIVE` VPORT, 내부 객체가 0개인 익명 `*U숫자` 블록 정의는 PURGE 대상과 전체 진단에는 그대로 포함하되 저장·재열기 안정 지문에서만 제외합니다. 채워진 익명 블록과 일반 블록은 제외하지 않으며, 세 항목의 별도 지문을 상태에 저장합니다.
- 성공 상태 XRecord를 쓴 뒤 저장 과정에서 내부 정의가 한 번 더 정규화될 수 있으므로, 상태 기록·저장·정체성 재검사를 최대 4회 반복합니다. 실제 정의 이름이 달라지면 저장된 DB를 한 번 재기준화하고, 같은 지문으로 고정된 뒤 즉시 자체 감사를 통과해야만 완료합니다.
- GstarCAD의 `DICTNEXT`는 부모 사전의 항목 이름을 반환하지 않는 경우가 있으므로, 정의 경로는 부모 `DICTIONARY`의 DXF `(3 . 이름)`과 `(350/360 . 객체)` 쌍을 우선 읽습니다. `SWCAD_WORKFLOW_STATE`는 이 실제 이름 경로에서만 XRecord handle을 정규화하며 다른 사전 항목은 계속 원래 이름과 handle로 감사합니다.
- 같은 LSP 버전에서 정리가 실패하면 `SWCADRUN` 재실행을 차단합니다. 원인을 수정해 LSP 버전이 바뀐 경우에만 저장된 실패 버전과 비교해 현재 버전에서 1회 재시도를 안내합니다.

## Layout 정책

모든 DR A2/A3/A4 도면틀을 A4 Layout으로 만듭니다. 이름은 `SWCAD` 접두사와 자동 순번 없이 원본 DWG 파일명 stem만 사용합니다. 실제 이름이 겹칠 때만 `FILE NO`, `Sheet`, 마지막 최소 숫자 suffix 순으로 구분합니다.

앱이 만든 Layout 이름은 접두사로 판정하지 않고 `LAYOUT_OWNED_*` XRecord에 저장합니다. 다시 실행할 때 이 목록의 Layout만 교체하므로 `Layout1`, `Layout2` 같은 사용자 탭은 보존됩니다. PDF 이름도 Layout 이름을 따릅니다.

## 패키지

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps\swcad-workflow\package.ps1
```

결과 ZIP과 같은 이름의 `.zip.sha256` 체크섬 파일이 로컬 `dist` 폴더에 생성됩니다. 체크섬은 ZIP 밖에 두므로 패키지 문서를 갱신해도 자기 자신을 참조하는 해시 순환이 생기지 않습니다.

다른 PC에서는 ZIP을 푼 뒤 패키지 루트의 `Install_SWCAD_Workflow.cmd`를 한 번 실행합니다. 생성된 아래 파일을 GstarCAD Mechanical에서 `APPLOAD`합니다.

```text
SWCAD_Workflow_Load.lsp
```

패키지 폴더를 옮겼다면 설치 파일을 다시 실행해 로더 경로를 갱신합니다.

아키텍처와 검증 근거는 다음 문서에 있습니다.

```text
docs\swcad-workflow\architecture.md
docs\swcad-workflow\test-results-2026-07-13.md
docs\swcad-workflow\source-layout-cleanup-test-2026-07-14.md
docs\swcad-workflow\full-unused-definition-cleanup-test-2026-07-14.md
```
