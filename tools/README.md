# GstarCAD LSP Tools

이 폴더는 GstarCAD 또는 GstarCAD Mechanical에서 바로 로드해 테스트할 수 있는 LSP 도구 원본을 보관합니다.

## Files

| File | Main commands | Purpose |
| --- | --- | --- |
| `gstarcad_dimstyle_keep_tolerance.lsp` | `SWAUTO`, `SWHELP`, `SWDIMKEEPAMISO`, `SWDEBUG`, `SWFINDSTYLE`, `SWMECHFITSEL`, `SWMECHFITALL` | SolidWorks DWG 치수스타일을 AM_ISO 계열로 정리하면서 공차와 `DIMLFAC` 같은 스케일 관련 override를 보존하고, GstarCAD Mechanical 맞춤공차 변환을 처리합니다. |
| `gstarcad_layout_from_model.lsp` | `GSA4CHECK`, `GSA4GO`, `GSA4VERIFY`, `GSA4CLEAN`, `GSA4PDF` | model space에 배치된 여러 도면 프레임에서 A4 PDF용 layout을 만듭니다. |
| `gstarcad_dimstyle_keep_tolerance_사용법.md` | Documentation | `SWAUTO` 일상 사용법과 문제 해결 메모입니다. |
| `gstarcad_layout_사용법.md` | Documentation | model-space frame to layout 자동화 사용법입니다. |
| `gstarcad_sdk_fit_tolerance_analysis.md` | Analysis | Mechanical 맞춤공차 자동화 SDK 조사 메모입니다. |

## Loading

권장 흐름은 저장소 루트의 `swcad_load.lsp` 하나를 APPLOAD하는 것입니다.

```text
APPLOAD
swcad_load.lsp
```

치수/공차 정리 작업은 보통 아래 명령으로 시작합니다.

```text
SWAUTO
```

layout 자동화만 단독으로 테스트할 때는 이 폴더의 `gstarcad_layout_from_model.lsp`를 직접 로드한 뒤 아래 명령으로 시작합니다.

```text
GSA4CHECK
GSA4GO
GSA4VERIFY
```

## History

See `../docs/lsp-work-history.md`.
