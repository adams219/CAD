# Repository Guide

이 저장소는 CAD 자동화 LSP, 진단 문서, 재현용 CAD 샘플을 함께 관리합니다.

## What Belongs Here

- GstarCAD / GstarCAD Mechanical AutoLISP source files
- SolidWorks DWG 변환 및 치수스타일 보정 관련 사용법 문서
- GMTITLE / FTAP / DIMLFAC 진단 설계와 결과
- 재현용 SolidWorks, DWG, XRef, Bind 샘플
- 진단 로그, 덤프, 스크린샷

## Working Rules

1. `swcad_load.lsp` 하나를 APPLOAD 진입점으로 유지합니다.
2. 검증된 기존 LSP 원본과 사용 문서는 `src/tools/<tool-name>/`에 기능별로 보관합니다.
3. 새 모듈 기능은 먼저 `src/lsp/`에 작게 추가합니다.
4. GMTITLE / FTAP 스케일 기능은 `src/tools/gmtitle/`에서 읽기 전용 진단부터 시작합니다.
5. 자동 수정 기능은 진단 로그로 충분히 검증한 뒤 추가합니다.
6. 채팅에서 나온 임시 작업물은 `work/chat-1`, `work/chat-2`, `work/chat-3` 중 해당 채팅 폴더에 먼저 둡니다.

## Case Folder Pattern

```text
samples/cases/<case-id>/
  README.md
  input/
  output/
  diagnostics/
```

Suggested case id format:

```text
YYYY-MM-topic-short-name
```

Example:

```text
2026-06-dimlfac-titleblock-scale/
```

## Chat Work Folder Pattern

```text
work/chat-<number>/<case-id>/
  README.md
  input/
  output/
  notes/
```

채팅 작업물이 실제 도구나 공식 문서로 확정되면 `src/tools/`, `docs/`, `samples/`, `diagnostics/` 중 알맞은 위치로 옮깁니다.

## Commit Pattern

작업 이력을 나중에 추적하기 쉽도록 아래 단위로 커밋합니다.

- 로더/모듈 구조 추가
- 기존 LSP 원본 이관
- 진단 명령 추가
- 샘플 DWG 추가
- 진단 결과 문서화
