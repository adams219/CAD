# GstarCAD Scale Investigation

이 문서는 SolidWorks DWG를 GstarCAD / GstarCAD Mechanical에서 열거나 bind한 뒤
일부 치수의 `DIMLFAC` 또는 치수 스타일 값이 달라지는 문제를 조사하기 위한 기록이다.

## Boundaries

- 기존 `SWAUTO` 생산 흐름은 보존한다.
- GMTITLE / FTAP 스케일 조사는 `src/tools/gmtitle/`에서 분리해 검증한다.
- 표제란 스케일만 단독 기준으로 사용하지 않는다.
- 최종 자동 보정은 진단 결과가 안정된 뒤 별도 단계로 진행한다.

## Current Read-Only Commands

| Command | Purpose |
| --- | --- |
| `SWTITLESCAN` | GMTITLE, `~FTAP`, 표제란 블록에서 스케일 후보를 찾는다. |
| `SWSCALESCAN` | 표제란 스케일, 치수 override `DIMLFAC`, 치수 스타일 `DIMLFAC`를 비교한다. |

예전 조사용 `SWTITLEDEBUG`는 공개 명령에서 제거했다. 원시 정보가 필요하면
현재 GMTITLE 공개 명령과 로그를 먼저 확인한다.

## Classification

| Status | Meaning |
| --- | --- |
| `OK` | 표제란 스케일과 치수 `DIMLFAC` 계열이 일치한다. |
| `MIXED` | 한 도면 안에 여러 `DIMLFAC` 값이 섞여 있다. |
| `MISSING` | 표제란 스케일 정보를 읽지 못했다. |
| `CONFLICT` | 표제란 스케일과 치수/스타일 `DIMLFAC`가 충돌한다. |
| `SUSPECT` | 일부 치수만 `DIMLFAC=1`로 바뀐 흔적이 있다. |

## Test Order

1. 원본 SolidWorks DWG에서 `SWTITLESCAN`으로 표제란 스케일 후보를 확인한다.
2. 같은 도면에서 `SWSCALESCAN`으로 치수 override와 스타일 `DIMLFAC`를 비교한다.
3. XRef + Bind 이후 파일도 같은 방식으로 비교한다.
4. 여러 시트가 섞인 통합 DWG에서 `MIXED` / `CONFLICT`가 나오는지 확인한다.
5. 진단 결과가 안정되면 `SWAUTO`의 `DIMLFAC` 보존 정책을 별도로 설계한다.
