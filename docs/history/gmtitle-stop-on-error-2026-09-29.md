# GMTITLE 오류 시 멈춤 - 2026-09-29

GMTITLE 변환(`src/tools/gmtitle/swcad_title_scale.lsp`)과 `SWCADRUN`(`apps/swcad-workflow/swcad_workflow.lsp`)이 오류나 `Esc` 뒤에 반드시 멈추도록 고쳤다. GMTITLE 검토의 3단계이고, 모듈과 워크플로 버전은 모두 `260929-title-stop-1`이다. 1단계(표제란 값)는 `gmtitle-title-values-2026-09-29.md`, 2단계(삭제 안전장치)는 `gmtitle-delete-safety-2026-09-29.md`에 있다.

## 원인과 수정

### 1. 결과 상태가 없으면 완료로 봄

`SWCADRUN`은 GMTITLE 하위 단계(`SWTITLEPREPARE`, `SWTITLECONVERTNEXT`, `SWTITLEVERIFY`)를 실행한 뒤 결과 상태를 읽는다. 상태가 비어 있으면 `완료. 결과=<상태 없음>`으로 보고 다음 실행을 권했다. 오류를 잡고도 상태를 남기지 않는 곳이 있었다.

- A2/A3/A4 native 교체 1장(OPEN), 전체 자동 교체, BATCH: 오류 문구만 출력했다. 전체 자동 교체는 마지막으로 끝난 시트의 성공 상태(`UPGRADED_CLONE_TO_NATIVE_GMTITLE`)가 그대로 남아 `SWCADRUN`이 계속 진행했다.
- 작업본을 만들지 않은 경우(`SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLECONVERTNEXT`)
- 원본 시트가 없을 때의 `SWTITLECONVERT`

수정:

- `SWCADRUN`: 하위 단계가 결과를 남기지 않으면 `REVIEW_TITLE_STEP_NO_RESULT`로 멈춘다. 권장 다음 작업도 `SWCADRUN 반복 금지`로 나온다.
- 오류를 잡는 변환 지점은 모두 `ERROR_` 상태를 남긴다. 새 상태는 `ERROR_NATIVE_GMTITLE_UPGRADE_OPEN`, `ERROR_NATIVE_GMTITLE_UPGRADE_BATCH`, `ERROR_TITLE_MISSING_OUTLINE_BATCH_APPLY`다.
- `SWTITLECONVERT`는 시작할 때 이전 상태를 지우고, 끝났는데 상태가 없으면 `REVIEW_CONVERT_RESULT_UNKNOWN`을 남긴다. 원본 시트가 없으면 `OK_NO_REMAINING_SOURCES`.
- 작업본을 만들지 않으면 `ABORT_WORK_COPY_NOT_CREATED`.

### 2. 마지막 시트의 멈춤을 OK가 덮음

여러 장을 연속 처리하는 단계는 끝에서 남은 시트 수만 보고 0이면 OK를 남겼다. 마지막 시트에서 오류나 검토 필요 상태가 나와도, 그 시트의 원본이 이미 지워졌으면 OK로 덮였다. 2단계의 `REVIEW_OLD_TITLE_NOT_DELETED`도 마지막 시트에서는 이렇게 가려졌다.

해당 단계: native 자동 일괄 변환, 표제란 없는 도면틀(title-missing) 일괄 변환, A2/A3/A4 native 교체 일괄, clone→native 교체 일괄, 빠른 일괄 변환(`swcad-title-run-fast-batch-phases`).

같은 문제가 한 곳 더 있었다. clone 변환이나 빠른 일괄 변환 뒤 A2/A3/A4 native 교체 후보가 생기면, 앞 단계가 멈춤 상태로 끝났어도 교체 1장을 이어서 실행했다. 교체가 성공하면 그 성공 상태가 앞의 멈춤을 덮었다.

수정: 마지막 상태가 멈춤(`ABORT_`, `ERROR_`, `WARN_`, `BLOCKED_`, `REVIEW_`)이 아닐 때만 OK를 남긴다. title-missing 일괄에서 변환했는데 남은 시트 수가 줄지 않으면 `REVIEW_TITLE_MISSING_OUTLINE_NOT_REDUCED`로 멈춘다. 앞 단계가 멈춤 상태면 A2/A3/A4 교체를 이어서 실행하지 않는다.

### 3. SWTITLEPREPARE가 앞의 취소를 덮음

`SWTITLEPREPARE`는 정리 작업 여러 개를 차례로 실행하고 마지막 결과만 남겼다. 앞 정리를 취소(`ABORT_..._USER`)하거나 경고가 나와도 뒤 정리가 OK면 OK로 끝났다. 도면틀 정의 복구(`swcad-title-frame-def-clean-safe`)는 결과를 출력만 하고 상태로 남기지 않았다.

수정: 첫 멈춤 상태를 최종 결과로 남긴다. 정리할 것이 없으면 `OK_PREPARE_DONE`. 도면틀 정의 복구도 결과를 상태로 남긴다.

### 4. 잡힌 오류 뒤 정리가 빠짐

변환은 `vl-catch-all-apply`로 오류를 잡는다. 이렇게 잡힌 오류는 안쪽 함수의 `*error*` 처리기를 건너뛴다. GMTITLE 배치 대기 중 `Esc`도 여기에 잡힌다. 그래서 다음이 남았다.

- GMTITLE 실행 중 잠시 끈 객체 스냅(`OSMODE` 0)
- 일괄 처리 표시(batch mode 등), 선택된 교체 대상, 마무리를 기다리던 새 GMTITLE 쌍
- 열린 UNDO 묶음

수정: 오류를 잡는 모든 변환 지점에서 객체 스냅과 동적 입력을 원래 값으로 되돌리고, UNDO 묶음을 끝내고, 마무리 대기 쌍을 지운다. `SWTITLECONVERTNEXT` 바깥에서 잡힌 오류는 일괄 처리 표시도 끈다.

GstarCAD는 `vla-StartUndoMark`로 연 묶음을 `UNDOCTL`에 표시하지 않는다(비트 8이 계속 0). 그래서 묶음이 열려 있는지 확인하지 않고 `EndUndoMark`를 부른다. 열린 묶음이 없으면 아무 일도 하지 않는다(오류 없음, `UNDOCTL` 그대로). 실제로 열린 묶음을 남긴 채 다음 명령을 실행해도 `UNDO 1`은 다음 명령만 되돌렸다(`tmp/gmtitle-attr-test/step3_undo_probe.lsp`, 닫음/복구/열어 둠 세 경우 결과 같음). GstarCAD에서는 열린 묶음이 다음 작업을 삼키지 않으므로, 이 부분은 안전을 위한 정리다.

### 5. 멈춘 명령이 남긴 캐시

`SWTITLESTATUS`나 `SWTITLEVERIFY`가 `Esc`로 멈추면 읽기 캐시가 켜진 채 남았다. 다음 명령이 멈추기 전의 객체 목록을 쓸 수 있었다.

수정: `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLECONVERTNEXT`, `SWTITLEVERIFY`는 시작할 때 이전 명령이 남긴 것을 정리한다. 캐시, 일괄 처리 표시, 열린 로그 파일, 객체 스냅, UNDO 묶음이 대상이다. 수동 native 교체(MANUAL) 대기 정보는 다음 명령에 필요하므로 그대로 둔다.

### 6. SWCADRUN 자체의 오류 처리

어느 단계도 잡지 않은 오류(예: 정리 단계의 YES 질문에서 `Esc`)는 `SWCADRUN`을 오류 한 줄만 남기고 끝냈다.

수정: `SWCADRUN`에 `*error*` 처리기를 넣었다. 객체 스냅을 되돌리고, 열린 로그와 캐시를 닫고, GMTITLE 단계였으면 `ERROR_SWCADRUN_INTERRUPTED`를 남긴다. 그리고 `진행 중지: 현재 도면을 저장하지 말고 원인을 확인하세요`를 출력한다. 안쪽 함수가 자기 `*error*` 처리기를 가지고 있으면 그 처리기가 먼저 실행되고 이 처리기는 실행되지 않는다(AutoLISP 규칙).

## 테스트

오류 주입 단위 검사(`diagnostics/gmtitle-values/title_stop_probe.lsp`, `title_stop_probe_after.lsp`)를 30장 fixture 복사본에서 `/b`로 실행했다. 함수를 오류를 내는 가짜로 바꿔 넣는 방식이다. `Esc`는 LISP에 오류로 전달되므로 같은 경로를 탄다.

검사 60개, 모두 통과. 주요 내용:

- 멈춤 상태 판정(`ABORT_`/`ERROR_`/`WARN_`/`BLOCKED_`/`REVIEW_`는 멈춤, `OK_`/`STOP_`/`APPLIED_`/`WAITING_`/빈 값은 아님)
- 시트 변환 중 `Esc`: `ERROR_BATCH_APPLY`, 객체 스냅 원래 값(37) 복원, 마무리 대기 쌍 지움
- 마지막 시트의 `REVIEW_OLD_TITLE_NOT_DELETED`가 OK로 바뀌지 않음(native 자동 일괄, 빠른 일괄, clone 뒤 A2/A3/A4 교체, 빠른 변환 뒤 A2/A3/A4 교체)
- title-missing 일괄: 마지막 시트 오류는 `ERROR_...`, 시트 수가 줄지 않으면 `REVIEW_...`, 정상이면 OK
- A2/A3/A4 전체·BATCH·OPEN 오류: `ERROR_...` 상태와 일괄 처리 표시 복원
- `SWTITLECONVERTNEXT` 바깥 오류: `ERROR_CONVERT_NEXT_FATAL`, 표시와 객체 스냅 복원
- `SWTITLECONVERT`가 결과를 남기지 않으면 `REVIEW_CONVERT_RESULT_UNKNOWN`(이전 명령의 상태를 다시 쓰지 않음)
- `SWTITLEPREPARE`: 첫 멈춤 유지, 뒤 경고 유지, 정리할 것이 없으면 `OK_PREPARE_DONE`
- 명령 시작 정리: 캐시·표시·로그·객체 스냅 복원, MANUAL 대기 정보는 유지
- `SWCADRUN`: 결과 없음이면 멈추고 `SWCADRUN 반복 금지` 안내, 결과가 있으면 계속
- `SWCADRUN` 오류 처리기: 가짜 GMTITLE 단계가 오류를 내면 `ERROR_SWCADRUN_INTERRUPTED`, 객체 스냅 복원, 성능 계측 종료(오류로 끝난 다음 스크립트 줄에서 확인)

원본 도면은 바뀌지 않았다(해시 같음).

정적 점검: Grok에게 `swcad-title-integrated-convert`에서 갈 수 있는 모든 정상 종료 경로를 읽게 했다. 상태가 비는 경로는 없었다. 성공이 멈춤을 덮는 곳 3군데(빠른 일괄 변환 끝, clone 뒤 A2/A3/A4 교체, 빠른 변환 뒤 A2/A3/A4 교체)를 찾아 위 2절처럼 고쳤고, 검사 3개를 추가했다.

30장 워크플로 전체 테스트(`diagnostics/gmtitle-values/run_title_value_test.ps1 -EndToEnd -FullWorkflow`)도 실행했다. 더 엄격해진 규칙 때문에 정상 변환이 잘못 멈추지 않는지 보는 테스트다.

- `SWCADRUN` 4회로 `COMPLETE`, `SWCADVERIFY` 검사 `SWCADVERIFY_FINAL_OK`. GMTITLE 단계 결과는 `OK_NATIVE_AUTOSELECT_BATCH_COMPLETE`였다.
- 제목블록 값: 330칸 모두 계획과 같음
- 지워진 모델 공간 객체: 1693개로 2단계와 같음
- 표제란 값, 삭제 안전장치, 오류 시 멈춤 단위 검사: 26개, 18개, 60개 모두 통과
- 결과 파일: `tmp/gmtitle-value-test/260929_step3/summary.txt`, `RESULT: OK`. 모듈 SHA-256 `B3E47FA69997CB47AD7F7C70264D20217C5BF4039FBA52B056ECAC0A88A5E36E`는 `diagnostics/swcad-workflow/module-baseline.sha256`와 같다.

첫 번째 전체 테스트는 값 쓰기 검사 도중 GstarCAD 창(`Drawing1.dwg`)이 따로 열려 스스로 중단됐다. GstarCAD가 열려 있으면 테스트가 시작하지 않도록 한 보호 장치가 작동한 것이다. GstarCAD를 닫아 둔 채 다시 실행했다.

## 남은 것

- 오류 뒤 도면에 반쯤 만든 GMTITLE 쌍이 남을 수 있다. 다음 실행의 기존 쌍 채택 경로가 처리하는 것은 이전과 같다. 멈춘 뒤에는 도면을 저장하지 않는 것이 원칙이다.
- 멈춤 상태는 메모리에만 있다. 사용자가 `SWCADRUN`을 다시 입력하면 GMTITLE 하위 단계를 새로 판단해 실행한다.
- 4단계(작업본 이름 날짜, 블록 이름 용지 판단, XREF 상태 안내)는 아직 하지 않았다.
