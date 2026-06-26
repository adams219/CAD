# CAD Tool

GstarCAD / GstarCAD Mechanical / SolidWorks DWG 자동화 도구를 하나의 CAD tool 세트로 관리하기 위한 통합 프로젝트입니다.

초기 목표는 기존 단일 LSP를 그대로 보존하면서, 새 로더와 모듈 구조를 먼저 잡고 이후 기능을 단계적으로 분리하는 것입니다.

## 사용 흐름

```text
APPLOAD
  -> swcad_load.lsp
    -> SWAUTO 또는 진단 명령 실행
```

현재 실사용 명령은 기존 원본 LSP에서 그대로 로드됩니다.

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

GMTITLE / FTAP 스케일 관련 명령은 읽기 전용 진단 기능으로 설계 중입니다.

```text
SWTITLESCAN
SWSCALESCAN
SWTITLEDEBUG
```

## Repository Layout

| Path | Purpose |
| --- | --- |
| `swcad_load.lsp` | APPLOAD에서 직접 불러올 메인 로더입니다. |
| `src/lsp/` | 새 모듈형 LSP 구조입니다. 현재는 이식 전 골격입니다. |
| `src/tools/gstarcad-dimstyle/` | SolidWorks DWG 치수스타일, 공차, Mechanical 맞춤공차 변환 LSP와 문서입니다. |
| `src/tools/gstarcad-layout/` | 모델 공간 도면 프레임을 A4 배치와 PDF 출력용 layout으로 만드는 도구입니다. |
| `src/tools/gmtitle/` | GMTITLE / FTAP 스케일 진단용 LSP와 문서입니다. |
| `work/` | 채팅별 작업물, 임시 실험, 아직 확정되지 않은 산출물을 보관하는 공간입니다. |
| `docs/guide/` | 사용 흐름, 명령 목록, 저장소 운영 가이드입니다. |
| `docs/history/` | 이관 기록, legacy 기록, migration 계획입니다. |
| `docs/investigations/` | 원인 조사, 진단 설계, 검증 기록입니다. |
| `samples/` | 재현용 CAD 샘플 케이스 자리입니다. |
| `diagnostics/` | 진단 로그, 덤프, 스크린샷 자리입니다. |
| `cad/` | SolidWorks / DWG 원본 및 XRef / Bind 실험 파일 자리입니다. |

## Chat Workspaces

채팅에서 만든 파일은 먼저 아래 위치에 날짜와 주제별로 저장합니다.

```text
work/chat-1/YYYY-MM-DD-topic/
work/chat-2/YYYY-MM-DD-topic/
work/chat-3/YYYY-MM-DD-topic/
```

검증이 끝난 LSP와 사용 문서는 `src/tools/` 또는 `docs/`로 승격합니다. 이렇게 하면 채팅별 작업 기록은 남기면서도 GitHub 최상위 폴더는 깨끗하게 유지할 수 있습니다.

## Current Production LSP

현재 `SWAUTO`는 아래 원본 파일에서 제공됩니다.

```text
src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance.lsp
```

이 파일은 SolidWorks DWG에서 깨지는 치수스타일, 공차, Mechanical 맞춤공차 변환 문제를 처리합니다. 모듈 분리는 아직 진행하지 않았고, 실무 안정성을 위해 원본을 먼저 보존했습니다.

## Scale Investigation Rule

GMTITLE 또는 `~FTAP` 표제란 스케일은 단독 기준으로 사용하지 않습니다. 진단 단계에서는 다음 세 값을 비교합니다.

```text
1. 표제란/GMTITLE/FTAP에서 읽은 스케일
2. 치수 엔티티 override의 DIMLFAC
3. 기존 치수스타일에 저장된 DIMLFAC
```

자동 보정은 진단 결과가 안정된 뒤 별도 단계로 진행합니다.

## License

Commercial use is not granted by default. See `LICENSE`.
