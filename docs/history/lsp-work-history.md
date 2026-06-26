# LSP Work History

이 문서는 GstarCAD LSP 유틸리티를 CAD 저장소에 처음 이관한 기록입니다.

## 2026-06-26 Initial CAD Repository Import

이전 로컬 작업공간에서 가져왔습니다.

```text
C:\Users\DR-DESIGN\Documents\솔리드웍스 자동화\tools
```

가져온 파일:

- `gstarcad_dimstyle/gstarcad_dimstyle_keep_tolerance.lsp`
- `gstarcad_dimstyle/gstarcad_dimstyle_keep_tolerance_사용법.md`
- `tools/gstarcad_layout_from_model.lsp`
- `tools/gstarcad_layout_사용법.md`
- `gstarcad_dimstyle/gstarcad_sdk_fit_tolerance_analysis.md`

현재 정리된 위치:

- `src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance.lsp`
- `src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance_사용법.md`
- `src/tools/gstarcad-layout/gstarcad_layout_from_model.lsp`
- `src/tools/gstarcad-layout/gstarcad_layout_사용법.md`
- `src/tools/gstarcad-dimstyle/gstarcad_sdk_fit_tolerance_analysis.md`

이관 시점의 이전 저장소:

```text
https://github.com/adams219/Solidworks-automation.git
branch: main
HEAD: 5592212 Add Codex cloud handoff and reducer trial results
```

중요 참고:

이전 SolidWorks 자동화 저장소에서 `tools/` 폴더는 아직 git에 커밋되지 않은 상태였습니다. 따라서 이 CAD 저장소의 최초 LSP 커밋이 해당 도구들의 첫 git 추적 기준점입니다.

## 2026-06-26 Repository Folder Reorganization

채팅별 산출물과 실제 도구 파일이 최상위에서 섞이지 않도록 아래처럼 정리했습니다.

- 생산용/검증용 LSP는 `src/tools/`와 `src/lsp/`로 이동했습니다.
- 레이아웃 도구 중복본은 `src/tools/gstarcad-layout/` 하나로 통합했습니다.
- 사용 가이드와 운영 문서는 `docs/guide/`로 이동했습니다.
- 이관 기록과 migration 계획은 `docs/history/`로 이동했습니다.
- 스케일 원인 조사는 `docs/investigations/`로 이동했습니다.
- 채팅별 임시 작업물은 `work/chat-1`, `work/chat-2`, `work/chat-3`에 보관하도록 분리했습니다.

## Tool Summary

### `gstarcad_dimstyle_keep_tolerance.lsp`

일상 사용 흐름:

```text
APPLOAD -> SWAUTO -> GMPOWEREDIT 확인 -> QSAVE
```

주요 명령:

- `SWAUTO`: AM_ISO 스타일 매핑, REGENALL, Mechanical 맞춤공차 변환, 최종 감사, 미사용 SolidWorks 치수스타일 정리를 실행합니다.
- `SWHELP`: 일상 사용 순서와 문제 발생 시 명령을 출력합니다.
- `SWDIMKEEPAMISO`: 현재 탭 치수를 AM_ISO 계열 스타일로 정리하고 의미 있는 공차 override를 보존합니다.
- `SWDEBUG`: 선택 치수의 대상 스타일, 공차값, fit code, `DIMLFAC`, 관련 크기 변수를 진단합니다.
- `SWFINDSTYLE`: `*SLDDIMSTYLE*` 같은 기존 SolidWorks 치수스타일 참조를 찾습니다.
- `SWMECHFITSEL` / `SWMECHFITALL`: 선택 또는 전체 대상 치수를 GstarCAD Mechanical 맞춤공차 데이터로 변환합니다.

도구를 만든 이유:

SolidWorks DWG export는 공차 표시를 `SLDDIMSTYLE*` 같은 생성 치수스타일에 넣는 경우가 많습니다. 단순히 AM_ISO 스타일로 바꾸면 공차 표시나 스케일 관련 동작이 깨질 수 있으므로, 필요한 per-dimension 정보를 먼저 override로 보존한 뒤 스타일을 바꿉니다.

### `gstarcad_layout_from_model.lsp`

일상 사용 흐름:

```text
APPLOAD -> GSA4CHECK -> GSA4GO -> GSA4VERIFY -> GSA4PDF
```

주요 명령:

- `GSA4CHECK`: PDF plotter, A4 media, plot style, rotation, layout prefix를 확인합니다.
- `GSA4GO`: model space의 도면 프레임을 선택해 같은 출력 줄의 프레임을 감지하고 `SHEET-*` layout을 만듭니다.
- `GSA4VERIFY`: 생성된 layout의 paper size, viewport window, view center, scale을 보고합니다.
- `GSA4CLEAN`: 생성된 `SHEET-*` layout을 삭제합니다.
- `GSA4PDF`: 생성된 layout을 개별 PDF로 출력합니다.

도구를 만든 이유:

일부 DWG는 여러 도면 프레임이 paper space layout이 아니라 model space에 나란히 배치되어 있습니다. 이 LSP는 해당 프레임에서 반복 가능한 A4 layout과 PDF 출력을 만듭니다.

## Next Planned CAD Diagnostics

현재 GstarCAD / GstarCAD Mechanical 스케일 문제는 긴 `SWAUTO` 파일에 바로 넣지 않고, 먼저 읽기 전용 scanner로 분리합니다.

후보 명령:

- `SWTITLEDEBUG`
- `SWTITLESCAN`
- `SWSCALESCAN`
- `SWSCALEDUMP`

scanner는 자동 수정 전에 `GMTITLE` / `FTAP`, `DIMLFAC`, 치수스타일 스케일, 도면 단위, viewport scale, 보이는 scale text를 수집해야 합니다.
