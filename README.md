# CAD Tool

GstarCAD / GstarCAD Mechanical / SolidWorks DWG 자동화 도구를 관리하는 저장소다.

## 기본 사용 흐름

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

치수/공차 변환 기본 흐름:

```text
SWAUTO
GMPOWEREDIT
QSAVE
```

GMTITLE 변환 도구만 직접 로드할 때:

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

## 주요 명령

치수/공차:

```text
SWAUTO
SWHELP
SWDEBUG
SWFINDSTYLE
SWTRYDELDIMSTYLES
SWDIMKEEPAMISO
SWMECHFITSEL
SWMECHFITALL
SWPURGESTYLES
```

GMTITLE 현재 공개 명령:

```text
SWTITLEVERSION
SWTITLEMULTIPREVIEW
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
SWTITLEA3A4ALL
SWTITLESTATUSREFRESH
SWTITLEGMTITLEVERIFYALL
```

전체 명령 설명은 `docs/guide/commands.md`를 본다.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `swcad_load.lsp` | APPLOAD에서 직접 불러오는 메인 로더. |
| `src/lsp/` | 공통/legacy LSP 모듈. |
| `src/tools/gstarcad-dimstyle/` | SolidWorks DWG 치수 스타일과 Mechanical 맞춤공차 변환 도구. |
| `src/tools/gstarcad-layout/` | 모델 공간 도면을 layout/PDF 흐름으로 정리하는 도구. |
| `src/tools/gmtitle/` | SolidWorks 도면틀/표제란을 GstarCAD Mechanical GMTITLE 기반 DR 도면틀로 변환하는 도구. |
| `work/` | 임시 CAD 테스트 파일과 로그. git에 올리지 않는 생성 산출물 공간. |
| `docs/guide/` | 현재 사용 방법과 명령어 가이드. |
| `docs/history/` | 이전 작업 기록과 판단 근거. |
| `docs/investigations/` | 원인 조사와 검증 기록. |
| `samples/` | 재현용 샘플 케이스 자리. |
| `diagnostics/` | 진단 로그/스크린샷 자리. |
| `cad/` | SolidWorks / DWG 원본, XRef, bind 작업 자리. |

## Work Folder Policy

`work/`에는 테스트 DWG, 임시 LSP/SCR, `*_last.txt` 로그가 생길 수 있다.
검증이 끝난 LSP는 `src/`로, 정식 문서는 `docs/`로 옮긴다.

`work/*.dwg`, `work/*.lsp`, `work/*.scr`, `work/*.txt`는 git에 올리지 않는다.

## License

Commercial use is not granted by default. See `LICENSE`.
