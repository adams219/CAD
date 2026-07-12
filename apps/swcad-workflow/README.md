# SWCAD Workflow

SolidWorks 원본 도면이 연결된 XREF 호스트를 다음 순서로 처리하는 통합 MVP입니다.

```text
XREF 작업본 생성/결합
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

## XREF 지원 범위

- 원본 SolidWorks DWG XREF만 자동 materialize합니다.
- 축척 `1`, 회전 `0`인 모델 공간 XREF를 지원합니다.
- `BIND` 후 최상위 XREF 참조를 정확히 한 번만 `EXPLODE`합니다.
- 이미 native GMTITLE인 XREF는 링크가 풀리는 것이 확인됐으므로 자동 처리하지 않습니다.
- 중첩 XREF와 최상위에 연결되지 않은 XREF 정의가 있으면 원본을 건드리지 않고 중단합니다.

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
