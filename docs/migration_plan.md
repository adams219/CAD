# Migration Plan

기존 단일 LSP를 바로 쪼개지 않고, 먼저 로더와 모듈 경계를 잡은 뒤 기능별로 이관합니다.

## Phase 1. Preserve

- 이전 작업공간의 치수스타일/공차 LSP 파일은 `gstarcad_dimstyle/`에 원본 보관합니다.
- `swcad_load.lsp`는 새 모듈 골격을 로드한 뒤 기존 생산 LSP를 로드합니다.
- 실무 사용자는 기존처럼 `SWAUTO`를 사용할 수 있습니다.

## Phase 2. Diagnose

- GMTITLE / FTAP / `DIMLFAC` 스케일 조사는 `GMTITLE/swcad_title_scale.lsp`에서 읽기 전용으로 시작합니다.
- 후보 명령은 `SWTITLESCAN`, `SWSCALESCAN`, `SWTITLEDEBUG`입니다.
- 자동 수정은 이 단계에서 하지 않습니다.

## Phase 3. Split

기존 `gstarcad_dimstyle_keep_tolerance.lsp` 기능을 아래 모듈로 옮깁니다.

| Module | Responsibility |
| --- | --- |
| `swcad_common.lsp` | 공통 문자열, xdata, entget/entmod, 로그 유틸리티 |
| `swcad_config.lsp` | AM_ISO 후보, SLDDIMSTYLE 패턴, 기본 정책 |
| `swcad_dimstyle.lsp` | 치수스타일 통일, 공차/override/DIMLFAC 보존 |
| `swcad_mechfit.lsp` | H7/h6 등 Mechanical 맞춤공차 xdata 변환 |
| `swcad_cleanup.lsp` | 미사용 SolidWorks 치수스타일 정리 |
| `swcad_debug.lsp` | SWDEBUG, SWFINDSTYLE, 상세 덤프 |
| `GMTITLE/swcad_title_scale.lsp` | GMTITLE / FTAP 스케일 진단 |

## Phase 4. Replace

- 각 기능이 모듈로 검증되면 legacy LSP 로드를 제거합니다.
- `SWAUTO`는 새 모듈 함수만 호출하게 바꿉니다.
- 기존 명령 이름은 실무 혼선을 줄이기 위해 유지합니다.
