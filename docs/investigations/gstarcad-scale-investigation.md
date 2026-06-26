# GstarCAD Scale Investigation

현재 조사 주제는 SolidWorks DWG를 GstarCAD / GstarCAD Mechanical에서 XRef + Bind로 합친 뒤, 일부 치수의 `DIMLFAC`가 원래 값에서 달라지는 현상입니다.

의심되는 실패 모드는 도면별 스케일 혼합과 치수스타일 중복입니다. 특히 기존 SolidWorks 치수스타일에 있던 `DIMLFAC`가 AM_ISO 계열 스타일로 바뀌는 과정에서 일반 치수에 보존되지 않을 수 있습니다.

## Boundaries

- 기존 긴 `SWAUTO` LSP는 먼저 원본 그대로 보존합니다.
- GMTITLE / FTAP 기능은 `SWAUTO`에 바로 넣지 않고 `src/tools/gmtitle/`에서 분리해 검증합니다.
- 첫 구현은 읽기 전용 진단 명령으로 제한합니다.
- 표제란 스케일만 단독으로 신뢰하지 않습니다.

## Candidate Read-Only Commands

| Command | Purpose |
| --- | --- |
| `SWTITLEDEBUG` | 선택한 표제란, 블록, 속성, xdata 후보를 자세히 출력합니다. |
| `SWTITLESCAN` | GMTITLE, `~FTAP`, 표제란 블록에서 스케일 후보를 찾습니다. |
| `SWSCALESCAN` | 표제란 스케일, 치수 override `DIMLFAC`, 치수스타일 `DIMLFAC`를 비교합니다. |
| `SWSCALEDUMP` | Bind 전후 비교용 텍스트/CSV 덤프를 저장하는 후보 명령입니다. |

## Classification

진단 결과는 자동 수정 대신 아래 상태로 분류합니다.

| Status | Meaning |
| --- | --- |
| `OK` | 표제란 스케일과 치수 `DIMLFAC` 계열이 일치합니다. |
| `MIXED` | 한 도면 안에 여러 `DIMLFAC` 값이 섞여 있습니다. |
| `MISSING` | 표제란 스케일 후보를 읽지 못했습니다. |
| `CONFLICT` | 표제란 스케일과 치수/스타일 `DIMLFAC`가 충돌합니다. |
| `SUSPECT` | 일부 치수만 `DIMLFAC=1`로 바뀐 흔적이 있습니다. |

## Test Order

1. 단일 SolidWorks DWG 원본에서 `SWTITLESCAN` 후보 데이터를 확인합니다.
2. 같은 도면에서 `SWSCALESCAN`으로 치수 override와 스타일 `DIMLFAC`를 비교합니다.
3. XRef + Bind 전후 파일을 같은 방식으로 비교합니다.
4. 여러 스케일 도면이 섞인 통합 DWG에서 `MIXED` / `CONFLICT` 분류가 되는지 확인합니다.
5. 진단 결과가 안정된 뒤 `SWAUTO`의 `DIMLFAC` 보존 정책을 설계합니다.
