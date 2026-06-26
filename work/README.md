# Chat Workspaces

## Notice: 2026-06-26 Folder Reorganization

저장소 최상위에 흩어져 있던 기능별 작업 폴더를 정리했습니다.

- 실제 LSP 도구와 사용 문서: `src/tools/`
- 새 모듈형 LSP 골격: `src/lsp/`
- 공식 가이드/이력/조사 문서: `docs/guide/`, `docs/history/`, `docs/investigations/`
- 채팅별 임시 작업물과 실험 결과: `work/chat-1`, `work/chat-2`, `work/chat-3`

앞으로 채팅에서 만든 파일은 먼저 해당 채팅 폴더에 날짜와 주제별로 저장한 뒤, 검증이 끝난 것만 `src/` 또는 `docs/`로 옮깁니다.

채팅으로 진행한 작업물은 먼저 이 폴더에 분리해서 보관합니다.

```text
work/chat-1/YYYY-MM-DD-topic/
work/chat-2/YYYY-MM-DD-topic/
work/chat-3/YYYY-MM-DD-topic/
```

각 작업 폴더에는 가능하면 `README.md`, `input/`, `output/`, `notes/`를 둡니다. 검증된 LSP는 `src/tools/` 또는 `src/lsp/`로, 공식 문서는 `docs/`로 옮깁니다.
