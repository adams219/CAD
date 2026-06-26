# Commands

## Production Commands

현재 생산 명령은 legacy LSP에서 로드됩니다.

| Command | Purpose |
| --- | --- |
| `SWAUTO` | AM_ISO 스타일 매핑, 공차 보존, Mechanical 맞춤공차 변환, REGENALL, 미사용 스타일 정리를 한 번에 실행합니다. |
| `SWHELP` | 일상 사용 순서와 문제 발생 시 명령을 출력합니다. |
| `SWDIMKEEPAMISO` | 현재 탭 치수를 AM_ISO 계열로 매핑합니다. |
| `SWMECHFITSEL` | 선택한 치수를 Mechanical 맞춤공차 xdata로 변환합니다. |
| `SWMECHFITALL` | 현재 탭의 대상 치수를 Mechanical 맞춤공차 xdata로 변환합니다. |
| `SWPURGESTYLES` | 사용하지 않는 치수스타일을 purge합니다. |
| `SWFINDSTYLE` | `SLDDIMSTYLE*` 등 특정 치수스타일을 쓰는 치수를 찾습니다. |
| `SWTRYDELDIMSTYLES` | 사용하지 않는 치수스타일을 ActiveX Delete로 안전하게 삭제 시도합니다. |
| `SWDEBUG` | 선택 치수의 스타일, 공차, fit code, `DIMLFAC`, xdata를 진단합니다. |

## Planned Read-Only Diagnostics

| Command | Purpose |
| --- | --- |
| `SWTITLESCAN` | GMTITLE / `~FTAP` / 표제란 블록에서 스케일 후보를 찾습니다. |
| `SWSCALESCAN` | 표제란 스케일, 치수 override `DIMLFAC`, 치수스타일 `DIMLFAC`를 비교합니다. |
| `SWTITLEDEBUG` | 선택한 표제란 후보의 raw data를 출력합니다. |

## Daily Flow

```text
APPLOAD
swcad_load.lsp
SWAUTO
GMPOWEREDIT
QSAVE
```

문제가 있으면 아래 순서로 확인합니다.

```text
SWDEBUG
SWFINDSTYLE
SWTRYDELDIMSTYLES
```
