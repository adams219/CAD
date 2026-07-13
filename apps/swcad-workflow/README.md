# SWCAD Workflow

SolidWorks 원본 도면이 연결된 XREF 호스트를 다음 순서로 처리하는 통합 MVP입니다.

```text
XREF 작업본 생성/결합
→ 중첩 시트 묶음과 치수 내용 블록 materialize
→ GMTITLE 도면틀·표제란 변환
→ DIMSTYLE·맞춤공차 정규화
→ A4 Layout 생성
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

`SWCADRUN`은 현재 상태에서 안전한 다음 단계 하나만 실행합니다. GMTITLE 창 확인이 필요한 동안에는 같은 명령을 반복하며, 각 실행 사이에 `SWCADSTATUS`로 수량을 확인할 수 있습니다.

DIMSTYLE 단계는 실행 전후의 치수 측정값, `DIMLFAC`, 상·하 공차 의미를 핸들별로 비교합니다. 기존 SWAUTO가 native Mechanical fit을 붙이며 오버라이드를 바꾸는 경우 달라진 치수만 복원하고, 완전히 일치할 때만 다음 단계로 이동합니다.

## 수동 배치와 Layout 좌표

통합 앱은 XREF를 자동으로 이동하지 않습니다. 사용자가 XREF 상태에서 원하는 위치와 출력 순서로 배치한 뒤 변환을 시작합니다.

```text
사용자 수동 XREF 배치
→ 현재 좌표를 유지한 materialize
→ GMTITLE·DIMSTYLE 변환
→ 최종 GMTITLE 도면틀 bbox 자동 계산
→ Layout 자동 생성
```

- XREF 축척은 `1`, 회전은 `0`을 사용합니다.
- 첫 도면의 왼쪽 아래를 `(0,0)`에 두는 것은 선택 사항입니다.
- 같은 행은 왼쪽에서 오른쪽, 다른 행은 위쪽에서 아래쪽 순서로 Layout 번호를 붙입니다.
- `SWCADSTATUS`는 Layout 생성 전에 예정 수량과 좌표를 최대 12개까지 보여줍니다.
- 실제 생성에는 미리보기와 같은 전체 좌표 계획을 사용합니다.
- 저장 후 `MANUAL_FRAME_COORDINATES` 모드, 계획 수량, 좌표 지문이 유지돼야 최종 검증을 통과합니다.
- Layout 생성 뒤 도면틀 위치가 바뀌면 좌표 지문이 달라져 다음 `SWCADRUN`에서 Layout을 다시 생성합니다.

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

41장 대표 파일에서는 시트 묶음 `10 → 0`, 최상위 치수 `0 → 254`, 원본 표제란/도면틀 `30/41`을 확인했습니다. GstarCAD의 BIND와 다단계 EXPLODE, 저장 후 재스캔 때문에 이 단계는 몇 분 걸릴 수 있습니다.

첫 변경 전에 GMTITLE 모듈의 다른 이름으로 저장 창을 사용해 사용자가 지정한 독립 작업본을 만듭니다. 원본 DWG와 XREF 원본은 저장하지 않습니다.

## Layout 정책

MVP는 기존 `GSA4GO`와 동일하게 모든 DR A2/A3/A4 도면틀을 A4 Layout으로 만듭니다. 앱 전용 Layout 이름은 `SWCAD-SHEET-001`부터 시작합니다. 다시 실행할 때 앱이 만든 Layout만 교체하므로 중복 생성하지 않습니다.

## 패키지

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps\swcad-workflow\package.ps1
```

결과 ZIP은 로컬 `dist` 폴더에 생성됩니다.

다른 PC에서는 ZIP을 푼 뒤 패키지 루트의 `Install_SWCAD_Workflow.cmd`를 한 번 실행합니다. 생성된 아래 파일을 GstarCAD Mechanical에서 `APPLOAD`합니다.

```text
SWCAD_Workflow_Load.lsp
```

패키지 폴더를 옮겼다면 설치 파일을 다시 실행해 로더 경로를 갱신합니다.

아키텍처와 검증 근거는 다음 문서에 있습니다.

```text
docs\swcad-workflow\architecture.md
docs\swcad-workflow\test-results-2026-07-13.md
```
