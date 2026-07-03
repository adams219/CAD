# Work Folder

`work/`는 CAD 테스트용 임시 작업 폴더다.

이 폴더에는 다음 파일이 생길 수 있다.

- 테스트용 DWG 복사본
- GstarCAD에서 실행한 임시 LSP/SCR
- `*_last.txt` 형식의 진단 로그
- `.bak`, `.dwl`, `.dwl2` 같은 CAD 임시/잠금 파일
- 현재 대화에서 확인 중인 중간 산출물

원칙:

- 원본 DWG는 여기서 직접 보관하지 않는다.
- 검증이 끝난 LSP는 `src/`로 옮긴다.
- 정식 사용 문서는 `docs/`로 옮긴다.
- `work/*.dwg`, `work/*.lsp`, `work/*.scr`, `work/*.txt`와 CAD 임시파일은 git에 올리지 않는다.

현재 작업을 이어가야 하는 최신 테스트 DWG만 필요할 때 남기고, 오래된 테스트 산출물은 삭제해도 된다.
