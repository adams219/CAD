# Title Scale Diagnostics

GMTITLE / FTAP 스케일 기능은 자동 보정이 아니라 읽기 전용 진단으로 시작합니다.

## Why

XRef + Bind 후 일부 치수의 `DIMLFAC`가 원본 값과 다르게 보일 수 있습니다. 단순히 표제란의 스케일만 믿고 전체 치수를 고치면, 여러 스케일 도면이 섞인 통합 DWG에서 오히려 정상 치수를 망가뜨릴 수 있습니다.

## Data Sources

진단 명령은 아래 정보를 비교해야 합니다.

| Source | Example |
| --- | --- |
| Title block scale | GMTITLE, `~FTAP`, visible scale text |
| Dimension override | Entity ACAD/DSTYLE xdata, `DIMLFAC` code 144 |
| Dimension style | DIMSTYLE table, `DIMLFAC` code 144 |
| Context | current tab, block name, handle, layer, dimension type |

## First Test Matrix

| Case | Expected Result |
| --- | --- |
| 단일 DWG, 표제란 1개, `DIMLFAC=1` | `OK` |
| 단일 DWG, 표제란 1개, `DIMLFAC=0.5` | `OK` |
| Bind 후 일부 치수만 `DIMLFAC=1` | `SUSPECT` |
| 여러 도면 스케일이 한 탭에 섞임 | `MIXED` |
| 표제란 스케일과 치수값이 충돌 | `CONFLICT` |
| 표제란을 찾지 못함 | `MISSING` |

## Output Shape

초기 출력은 명령창 로그로 충분합니다.

```text
SWSCALESCAN
  Tab: Layout1
  Title scale candidates: 1:2, 1:1
  Entity DIMLFAC values: 0.5 x 42, 1.0 x 6
  Style DIMLFAC values: SLDDIMSTYLE0=0.5, AM_ISO=1.0
  Result: SUSPECT
```

CSV 덤프는 비교가 필요해진 뒤 `SWSCALEDUMP` 후보 명령으로 추가합니다.
