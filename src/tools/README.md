# CAD Tool Source Folders

실제로 로드하거나 검증 중인 CAD 자동화 도구를 기능별로 관리한다.

| Folder | Purpose |
| --- | --- |
| `gstarcad-dimstyle/` | SolidWorks DWG 치수 스타일과 Mechanical 맞춤공차 변환 도구. |
| `gstarcad-layout/` | 모델 공간 도면을 A4 layout/PDF 흐름으로 정리하는 도구. |
| `gmtitle/` | SolidWorks 도면틀/표제란을 GstarCAD Mechanical GMTITLE 기반 DR 도면틀로 변환하는 도구. |

임시 실험 파일, CAD 로그, 작업복사본 DWG는 `work/` 아래에 둔다.
검증이 끝난 LSP와 문서만 `src/` 또는 `docs/`로 승격한다.
