# Legacy History

이 저장소에 보관한 LSP 파일은 아래 기존 작업공간에서 이관했습니다.

```text
C:\Users\DR-DESIGN\Documents\솔리드웍스 자동화\tools
```

## Imported Files

```text
gstarcad_dimstyle/gstarcad_dimstyle_keep_tolerance.lsp
gstarcad_dimstyle/gstarcad_dimstyle_keep_tolerance_사용법.md
tools/gstarcad_layout_from_model.lsp
tools/gstarcad_layout_사용법.md
gstarcad_dimstyle/gstarcad_sdk_fit_tolerance_analysis.md
```

현재 저장소에서는 위 파일을 아래 위치에서 관리합니다.

```text
src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance.lsp
src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance_사용법.md
src/tools/gstarcad-layout/gstarcad_layout_from_model.lsp
src/tools/gstarcad-layout/gstarcad_layout_사용법.md
src/tools/gstarcad-dimstyle/gstarcad_sdk_fit_tolerance_analysis.md
```

## Previous Repository Commits

이전 작업공간의 `tools/` 폴더는 아직 git에 커밋되지 않은 상태였습니다. 참고용으로 이전 저장소의 전체 커밋 로그를 남깁니다.

```text
fcc74c0 2026-06-01 Initial DRD calculation project snapshot
9134b2c 2026-06-01 Add May 28 KISSsoft verification outputs
a7b2e36 2026-06-01 Add GitHub Codex migration guide
7cd0493 2026-06-02 Make project paths portable
5592212 2026-06-02 Add Codex cloud handoff and reducer trial results
```

## CAD Tool Timeline

- SolidWorks DWG에서 GstarCAD로 가져온 치수스타일과 공차가 깨지는 문제를 확인했습니다.
- `gstarcad_dimstyle_keep_tolerance.lsp`에서 `SWAUTO` 중심의 자동 보정 흐름을 만들었습니다.
- 일반 치수는 AM_ISO 계열, 지름 치수는 `AM_ISO$3` 계열로 매핑했습니다.
- 공차값과 주요 override를 보존하고, H7/h6 같은 맞춤공차 문자를 GstarCAD Mechanical xdata로 변환했습니다.
- `SWDEBUG`, `SWFINDSTYLE`, `SWTRYDELDIMSTYLES` 등 진단 명령을 추가했습니다.
- XRef + Bind 후 일부 치수의 `DIMLFAC`가 달라지는 문제를 발견했습니다.
- GMTITLE / `~FTAP` 표제란 스케일과 치수 `DIMLFAC`를 비교하는 읽기 전용 진단 프로젝트를 새 CAD tool 저장소에서 시작했습니다.
