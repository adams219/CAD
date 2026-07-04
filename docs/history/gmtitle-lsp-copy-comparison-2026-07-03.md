# GMTITLE LSP 복사본 비교 기록 - 2026-07-03

## 목적

`work/lsp_compare/swcad_title_scale_integrated_flow_test.lsp` 복사본과 현재 원본 `src/tools/gmtitle/swcad_title_scale.lsp`를 비교해, 어느 쪽을 기준으로 계속 진행할지 판단한다.

결론부터 말하면 현재 기준은 원본 LSP다.

```text
src/tools/gmtitle/swcad_title_scale.lsp
버전: 260703-integrated-flow-main-41
```

복사본은 실험과 검증 이력을 남기는 용도로만 둔다. 일반 사용이나 이후 구현 기준으로 쓰지 않는다.

## 이력 기준

이 판단은 현재 느낌이 아니라 GitHub/로컬 이력에서 확인된 실패를 기준으로 한다.

- `0121ae1 Clean up GMTITLE command surface`
  - 예전 보조 스크립트와 공개 명령어가 많아져 사용 흐름이 흐려진 문제를 정리했다.
  - 따라서 새 증상마다 공개 명령어를 추가하지 않는다.

- `0bb4c9b Document GMTITLE first-native picker limits`
  - `GMTITLE`의 첫 용지/제목블록 선택은 명령행이나 화면 좌표 클릭으로 안정적으로 자동화하기 어렵다는 결론이 있었다.
  - 스크린샷 좌표나 드롭다운 위치 의존을 기본 방식으로 쓰지 않는다.

- `b69ff54 Require strict native GMTITLE exemplars`
  - 복제된 GMTITLE은 모양이 같아도 native 편집 동작이 보장되지 않는다.
  - 최종 성공은 `DR_titlea_3rd` 더블클릭 시 GMTITLE 표 편집창이 열리는지로 본다.

- `843e453 Verify preserve-copy GMTITLE A4 frame-only`
  - preserve-copy/clone은 빠른 처리에 도움이 되지만 최종 검증을 대체하지 못한다.
  - A3/A4 native 교체와 더블클릭 확인은 별도로 필요하다.

## 복사본 LSP 상태

복사본:

```text
work/lsp_compare/swcad_title_scale_integrated_flow_test.lsp
```

장점:

- 4단계 통합 흐름을 처음 시험한 파일이다.
- `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 방향을 검증하는 데 도움이 됐다.
- A2/A3/A4 공통 도면틀 내부 표제란 후보 스캔을 시험했다.
- A3 내부 표제란 후보를 49개에서 10개로 줄이는 필터 개선을 검증했다.

한계:

- 예전 보조 명령어가 여전히 직접 실행 가능한 공개 명령으로 남아 있다.
- 로그와 안내에 `SWTITLEA3A4ALL`, `SWTITLEA3A4NEXT`, `SWTITLEFASTSTATUS`, `SWTITLETRANSFERFASTBATCH`, `SWTITLEFRAMEONLYAPPLY` 같은 예전 흐름이 많이 남아 있다.
- 일부 안내는 A3/A4 후보를 여러 장 한 번에 처리하라고 유도한다.
- 이는 `0121ae1`에서 정리한 “명령어 난립” 문제와 다시 충돌한다.

따라서 복사본은 실험 기록으로만 유지하고, 앞으로의 구현 기준으로 삼지 않는다.

## 현재 원본 LSP 상태

원본:

```text
src/tools/gmtitle/swcad_title_scale.lsp
```

현재 개선점:

- 로드 메시지는 4개 통합 명령만 안내한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

- `SWTITLEPREPARE`는 A2/A3/A4 공통 도면틀 정의 정규화 흐름을 사용한다.
- `SWTITLECONVERT`는 A3/A4 native 교체 후보를 한 장씩 처리한다.
- `SWTITLECONVERT`는 GMTITLE 창을 열기 전에 `OPEN` 확인을 요구한다.
- 예전 보조 명령은 공개 `c:` 명령에서 제거하고 내부 함수로만 남긴다.
- 실수 명령어 TEXT/MTEXT 잔여물 정리도 `SWTITLEPREPARE` 내부 흐름으로 들어왔다.
- 최신 사용자 안내와 주요 검증 로그는 한국어 중심으로 정리됐다.
- `main-35`에서는 실제 `GMTITLE` 창을 열기 직전/직후의 용지, 제목블록, Frame positioning, Object move, 왼쪽 아래 배치점 안내를 한국어 원문으로 더 정리했다.
- `main-36`에서는 native GMTITLE 배치 실패/OPEN 취소/A3-A4 한 장 교체 사전 확인 문구를 한국어로 더 정리했다.
- `main-37`에서는 검증/더블클릭/A3-A4 교체 로그의 사용자 노출 라벨을 한국어로 더 보강했다.
- `SWTITLEVERIFY`는 내부 검증을 실행한 뒤 통합 최종 요약에서 `최종 결과: OK/WARN/FAIL`을 표시한다.
- `main-26`에서는 모든 literal `Result:`/`swcad-title-apply-result` 상태 코드에 한국어 설명이 붙도록 보강했다.

공개 GMTITLE 변환 명령:

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

`SWTITLEVERSION`은 로드 확인용 읽기 전용 명령으로만 남긴다. `SWSCALESCAN`은 GMTITLE 변환과 별개인 스케일 진단 명령이다.

## 판단

2026-07-03 재확인 결과:

- 현재 원본 LSP 공개 `c:` 명령: 6개
  - GMTITLE 변환 흐름: `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY`
  - 보조 읽기/진단: `SWTITLEVERSION`, `SWSCALESCAN`
- 실험 복사본 공개 `c:` 명령: 32개
  - `SWTITLEA3FRAMECLEAN`, `SWTITLECLEANORPHANFRAME`, `SWTITLEA3A4NEXT`, `SWTITLEA3A4ALL`, `SWTITLEFASTSTATUS`, `SWTITLETRANSFERFASTBATCH`, `SWTITLEFRAMEONLYAPPLY` 등 예전 보조 명령이 그대로 노출되어 있다.
- 따라서 복사본은 초기 아이디어 검증에는 유용했지만, 지금 목표인 4단계 사용자 흐름에는 맞지 않는다.

| 항목 | 복사본 LSP | 현재 원본 LSP |
| --- | --- | --- |
| 4단계 흐름 | 있음 | 있음 |
| 예전 명령어 노출 | 많음 | 공개 명령에서 제거 |
| A3/A4 여러 장 일괄 native 교체 유도 | 남아 있음 | 한 장씩 처리 |
| GMTITLE 잘못된 기본값 방지 | 약함 | `OPEN` 확인으로 보강 |
| 한국어 안내 | 일부 | 상태 코드 설명까지 보강 |
| 최종 기준 적합성 | 실험용 | 현재 기준 |

따라서 앞으로는 원본 LSP를 기준으로 계속 진행한다. 2026-07-04 현재 기준 버전은 `260703-integrated-flow-main-42`이다.

복사본에서 다시 가져올 내용은 현재 없다. 복사본의 유효한 아이디어는 이미 원본에 승격됐고, 복사본에 남은 차이는 대부분 예전 명령 흐름과 혼선을 만드는 안내다.

## 2026-07-03 정적 재검증

현재 파일 기준으로 다시 확인한 결과:

```text
원본: src/tools/gmtitle/swcad_title_scale.lsp
버전: 260703-integrated-flow-main-41
전체 공개 c: 명령: 6개
SWTITLE 공개 명령: 5개
사용자 변환 흐름: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERT, SWTITLEVERIFY
보조 명령: SWTITLEVERSION, SWSCALESCAN
괄호/문자열 검사: Depth=0, Min=0, InString=False
```

```text
복사본: work/lsp_compare/swcad_title_scale_integrated_flow_test.lsp
버전: 260703-integrated-flow-test-3
전체 공개 c: 명령: 32개
SWTITLE 공개 명령: 31개
괄호/문자열 검사: Depth=0, Min=0, InString=False
```

복사본에 남아 있는 예전 흐름 흔적:

```text
SWTITLEA3A4ALL: 33회
SWTITLEA3A4NEXT: 24회
SWTITLEFRAMEONLYAPPLY: 23회
SWTITLEFASTSTATUS: 17회
SWTITLETRANSFERFASTBATCH: 29회
SWTITLESTATUSREFRESH: 12회
```

원본은 같은 검색에서 위 예전 공개 명령 이름이 0회였고, `SWTITLECONVERT` 중심 안내로 모였다. 또한 원본에는 `SWTITLESTATUS` 구조 판단 로그가 있다.

```text
work/swcad_title_structure_diagnosis_last.txt
```

복사본에는 이 구조 판단 로그가 없다.

정적 결론:

- 복사본은 문법적으로 깨진 파일은 아니다.
- 하지만 사용자에게 보이는 명령과 안내가 너무 많아 현재 목표와 맞지 않는다.
- 원본은 복사본에서 검증된 유효한 흐름을 흡수했고, 불필요한 공개 명령을 제거했다.
- 따라서 비교 결과는 여전히 원본 LSP가 더 좋다.

2026-07-03 추가 정리:

- `main-34`에서는 기능 흐름은 바꾸지 않고, 사용자에게 직접 보일 수 있는 잔여 영어 안내를 번역 테이블에 보강했다.
- 현재 비교 결론은 그대로다. 복사본은 실험 기록이고, 실제 기준은 원본 LSP다.

2026-07-03 원격/로컬 이력 재확인:

- `git fetch origin --prune`으로 GitHub 원격 이력을 다시 확인했다.
- `origin/main`, `origin/HEAD`, `main`, 현재 브랜치 `codex/gm-title`의 기준 커밋은 모두 `0121ae1 Clean up GMTITLE command surface`였다.
- 현재 로컬 작업에는 `260703-integrated-flow-main-41` 기준 미커밋 변경이 올라와 있다.
- 원본 LSP와 복사본 LSP를 UTF-8로 읽어 괄호/문자열 균형을 다시 검사했다.

```text
src/tools/gmtitle/swcad_title_scale.lsp Depth=0 Min=0 InString=False
work/lsp_compare/swcad_title_scale_integrated_flow_test.lsp Depth=0 Min=0 InString=False
```

- 공개 명령 수를 다시 비교했다.

```text
원본 LSP 공개 c: 명령: 6개
  SWTITLESTATUS
  SWTITLEPREPARE
  SWTITLECONVERT
  SWTITLEVERIFY
  SWTITLEVERSION
  SWSCALESCAN

복사본 LSP 공개 c: 명령: 32개
```

이번 재확인에서도 결론은 변하지 않았다.

복사본은 문법적으로 깨진 파일이 아니며, 초기 실험과 검증에는 유용했다. 하지만 예전 공개 명령과 안내가 많이 남아 있어 사용자가 같은 선택 실수를 반복할 가능성이 크다. 따라서 실제 사용 기준은 원본 `src/tools/gmtitle/swcad_title_scale.lsp`이며, 복사본은 비교/실험 기록으로만 유지한다.

## 2026-07-03 런타임 비교 재검증

원본 LSP와 테스트 복사본 LSP를 같은 저장본에서 복사한 별도 DWG로 나누어 GstarCAD `/b` 읽기 전용 스크립트로 비교했다.

테스트 DWG:

```text
work/swtitle_lsp_compare_main37_260703.dwg
work/swtitle_lsp_compare_testcopy_260703.dwg
```

실행한 명령:

```text
SWTITLEVERSION
SWTITLESTATUS
SWTITLEVERIFY
```

원본 LSP 런타임 결과:

```text
로그: work/swtitle_lsp_compare_main37_260703.txt
Loaded version: 260703-integrated-flow-main-37
Expected version: 260703-integrated-flow-main-37
Run: SWTITLEVERSION -> OK
Run: SWTITLESTATUS -> OK, status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY -> OK, status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

복사본 LSP 런타임 결과:

```text
로그: work/swtitle_lsp_compare_testcopy_260703.txt
Loaded version: 260703-integrated-flow-test-3
Expected version: 260703-integrated-flow-test-3
Run: SWTITLEVERSION -> OK
Run: SWTITLESTATUS -> OK, status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY -> OK, status=FAIL_MISSING_TARGET_GMTITLE_PAIRS
Runtime check completed: yes
```

해석:

- 두 LSP 모두 GstarCAD 런타임에서 로드와 읽기 전용 명령 실행은 통과했다.
- 두 테스트 DWG 모두 변환 전 저장본이므로 target GMTITLE 객체가 없고, 검증 실패가 나오는 것은 정상 진단이다.
- 원본은 통합 검증 요약인 `SWTITLEVERIFY_FINAL_FAIL`까지 올라오지만, 복사본은 오래된 내부 검증 코드 `FAIL_MISSING_TARGET_GMTITLE_PAIRS`에서 끝난다.
- 원본은 `_compare_main37_260703` 접미사 상세 로그를 남겼고, 구조 판단 로그도 생성했다.
- 복사본은 실행 자체는 되지만 예전 공개 명령과 안내가 많이 남아 있어 사용자 흐름 기준으로는 여전히 부적합하다.

런타임 비교 결론:

```text
실험/분석 보관: work/lsp_compare/swcad_title_scale_integrated_flow_test.lsp
실제 사용/구현 기준: src/tools/gmtitle/swcad_title_scale.lsp
```

## 2026-07-03 main-39 최신 재확인

사용자가 “GitHub, 로컬 이력을 적극적으로 참고해서 같은 실수를 반복하지 않게 해달라”고 요청했으므로, 비교 전 원격/로컬 기준을 다시 확인했다.

```text
git fetch origin --prune
git status --short --branch
git log --oneline --decorate --graph --all -30
```

확인 결과:

```text
현재 브랜치: codex/gm-title
HEAD / origin/main / origin/HEAD / main: 0121ae1 Clean up GMTITLE command surface
```

현재 원본과 테스트 복사본을 같은 기준으로 정적 검사했다.

```text
원본: src/tools/gmtitle/swcad_title_scale.lsp
버전: 260703-integrated-flow-main-41
괄호/문자열 검사: Depth=0, MinDepth=0, InString=False
공개 c: 명령: 6개
공개 명령: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERT, SWTITLEVERIFY, SWTITLEVERSION, SWSCALESCAN
예전 임시 명령 참조:
  SWTITLEA3A4ALL: 0
  SWTITLEA3A4NEXT: 0
  SWTITLEFRAMEONLYAPPLY: 0
  SWTITLEFASTSTATUS: 0
  SWTITLETRANSFERFASTBATCH: 0
  SWTITLESTATUSREFRESH: 0
  SWTITLEA3FRAMECLEAN: 0
  SWTITLECLEANORPHANFRAME: 0
```

```text
복사본: work/lsp_compare/swcad_title_scale_integrated_flow_test.lsp
버전: 260703-integrated-flow-test-3
괄호/문자열 검사: Depth=0, MinDepth=0, InString=False
공개 c: 명령: 32개
예전 임시 명령 참조:
  SWTITLEA3A4ALL: 33
  SWTITLEA3A4NEXT: 24
  SWTITLEFRAMEONLYAPPLY: 26
  SWTITLEFASTSTATUS: 19
  SWTITLETRANSFERFASTBATCH: 33
  SWTITLESTATUSREFRESH: 14
  SWTITLEA3FRAMECLEAN: 5
  SWTITLECLEANORPHANFRAME: 4
```

해석:

- 두 파일 모두 문법 균형은 통과했다.
- 복사본은 실험용으로는 의미가 있지만, 사용자가 외워야 할 공개 명령과 예전 안내가 너무 많다.
- 원본은 `0121ae1`에서 정리한 4단계 사용자 흐름을 유지한다.
- 따라서 이후 구현과 실제 사용 기준은 계속 원본 LSP다.
- 복사본에서 현재 원본으로 추가로 가져올 내용은 없다. 필요한 아이디어는 이미 원본에 승격됐고, 남은 차이는 대부분 혼선을 만드는 예전 흐름이다.

`main-39` 추가 보강:

- `SWTITLEVERIFY` 최종 요약에 용지별 대상 도면틀 수, 현재 필요한 대상 용지, 누락된 대상 용지를 직접 출력한다.
- 필요한 A2/A3/A4 대상 용지가 누락된 경우는 변환 완료로 볼 수 없으므로 `SWTITLEVERIFY_FINAL_FAIL`로 판단한다.

`main-40` 추가 보강:

- target GMTITLE 도면틀/제목블록의 `SWTITLE_EXEMPLAR` xdata에 변환 기준 전체 A2/A3/A4 수량을 함께 저장한다.
- `SWTITLESTATUS`와 `SWTITLEVERIFY`가 기준 수량 대비 target 도면틀 수량 부족/초과를 출력한다.
- target 도면틀 수량이 기준보다 부족하면 `SWTITLEVERIFY_FINAL_FAIL`로 판단한다.

`main-41` 추가 보강:

- `SWTITLEVERIFY` 통합 최종 요약을 `swcad_title_verify_summary_last.txt`에도 저장한다.
- `/b` 런타임 검증 때는 같은 로그가 `swcad_title_verify_summary_last_runtime_260703.txt`로 분리된다.

## 2026-07-03 main-41 재비교 결론

사용자가 "GitHub, 로컬 이력을 적극적으로 참고해서 같은 실수를 반복하지 않게 해달라"고 다시 요청했으므로, 현재 원본 LSP와 실험 복사본을 다시 비교했다.

GitHub/로컬 기준:

```text
HEAD / origin/main / origin/HEAD / main: 0121ae1 Clean up GMTITLE command surface
현재 작업 브랜치: codex/gm-title
```

현재 원본:

```text
파일: src/tools/gmtitle/swcad_title_scale.lsp
버전: 260703-integrated-flow-main-41
줄 수: 15665
공개 c: 명령: 6개
공개 명령:
  SWSCALESCAN
  SWTITLECONVERT
  SWTITLEPREPARE
  SWTITLESTATUS
  SWTITLEVERIFY
  SWTITLEVERSION
예전 임시 공개 명령 defun: 0
SWTITLE_EXPECTED_SHEET_COUNTS: 있음
SWTITLEVERIFY 요약 로그: 있음
런타임 로그 suffix 분리: 있음
괄호/문자열 검사: Depth=0, MinDepth=0, InString=False
```

실험 복사본:

```text
파일: work/lsp_compare/swcad_title_scale_integrated_flow_test.lsp
버전: 260703-integrated-flow-test-3
줄 수: 14764
공개 c: 명령: 32개
예전 임시 공개 명령 defun:
  SWTITLEA3FRAMECLEAN: 1
  SWTITLECLEANORPHANFRAME: 1
  SWTITLEA3A4NEXT: 1
  SWTITLEA3A4ALL: 1
  SWTITLEFASTSTATUS: 1
  SWTITLETRANSFERFASTBATCH: 1
  SWTITLEFRAMEONLYAPPLY: 1
  SWTITLETRANSFERAPPLY: 1
  SWTITLETRANSFERBOOTSTRAPFAST: 1
  SWTITLESTATUSREFRESH: 1
SWTITLE_EXPECTED_SHEET_COUNTS: 없음
SWTITLEVERIFY 요약 로그: 없음
런타임 로그 suffix 분리: 없음
괄호/문자열 검사: Depth=0, MinDepth=0, InString=False
```

읽기 전용 런타임 증거:

```text
복사본:
  work/swtitle_lsp_compare_testcopy_260703.txt
  Loaded version: 260703-integrated-flow-test-3
  Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
  Result: OK SWTITLEVERIFY status=FAIL_MISSING_TARGET_GMTITLE_PAIRS
  Runtime check completed: yes

원본:
  work/swtitle_runtime_loaded_last.txt
  Loaded version: 260703-integrated-flow-main-41
  Expected version: 260703-integrated-flow-main-41
  Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
  Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
  Runtime check completed: yes
```

판단:

- 실험 복사본은 4단계 흐름을 검증하는 데 도움을 준 파일이다.
- 하지만 지금 기준으로는 예전 임시 공개 명령이 32개 공개 명령 표면에 그대로 남아 있어 사용자용으로 부적합하다.
- 원본 LSP는 실험 복사본의 좋은 방향을 승격한 뒤, 공개 명령 표면 정리, 기준 수량 xdata, 최종 요약 로그, 런타임 로그 suffix 분리까지 추가로 갖고 있다.
- 따라서 현재 더 좋은 기준은 원본 `src/tools/gmtitle/swcad_title_scale.lsp`다.
- 실험 복사본을 다시 APPLOAD해서 작업하면 old helper 명령 노출 때문에 `0121ae1` 이전의 혼란을 반복할 수 있다.

실무 결론:

```text
일반 작업: 원본 LSP만 APPLOAD
복사본: 역사/비교 참고용으로만 유지
다음 실제 CAD 검증: 원본 main-42로 SWTITLESTATUS -> SWTITLEPREPARE -> SWTITLECONVERT -> SWTITLEVERIFY
```

## 아직 완료되지 않은 검증

현재 기준 원본 LSP도 최종 완료는 아니다.

확인된 것:

- `/b` 스크립트 방식으로 GstarCAD에서 원본 LSP `260703-integrated-flow-main-26`을 실제 로드했다.
- `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY`가 오류 없이 실행됐다.
- `work/swtitle_runtime_loaded_last.txt`가 생성됐고 `Runtime check completed: yes`를 기록했다.
- 이후 `main-27`에서 런타임 상세 로그가 일반 `*_last.txt`를 덮어쓰지 않도록 `_runtime_260703` 접미사 옵션을 추가했다.
- `main-27`도 `/b` 방식으로 다시 검증했고, `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-27`로 기록됐다.
- `swcad_title_*_last_runtime_260703.txt` 전용 로그가 생성되어 일반 작업 로그와 분리되는 것을 확인했다.
- 이후 `main-28`에서 공개 흐름 중 사용자에게 직접 보일 수 있던 남은 영어 안내 문장을 한국어로 정리했다.
- `main-28`도 `/b` 방식으로 다시 검증했고, `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-28`로 기록됐다.
- 이후 `main-29`에서 런타임 로그의 잔여 영어/부분 번역 문구를 더 정리했다.
- `main-29`도 `/b` 방식으로 다시 검증했고, `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-29`로 기록됐다.
- 이후 `main-30`에서 도면틀 정의 진단 로그의 잔여 영어/부분 번역 문구를 더 정리했다.
- 이후 `main-31`에서 `존재: no/yes` 잔여 문구를 더 정리했다.
- 이후 `main-32`에서 `SWTITLESTATUS` 구조 판단 요약을 추가하고 A3/A4 판단, 도면틀 bbox/선택 위험 안내를 더 직접적인 한국어로 정리했다.
- 이후 `main-33`에서 구조 판단 요약도 별도 로그로 남기도록 했다.
- `/b` 읽기 전용 런타임 확인에서 `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-33`으로 기록됐다.
- `work/swcad_title_structure_diagnosis_last_runtime_260703.txt`가 생성됐고, 구조 판단 요약이 파일로 남는 것을 확인했다.
- 이후 `main-34`에서 잔여 영어 안내 번역을 보강했고, `/b` 읽기 전용 런타임 확인에서 `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-34`로 기록됐다.
- 이후 `main-35`에서 `GMTITLE` 창 직전 안내, DR 용지/제목블록, `Frame positioning ON`, `Object move OFF`, 왼쪽 아래 배치점 안내를 한국어로 더 정리했다.
- `main-35` 전용 기준선 복사본에서도 `/b` 읽기 전용 런타임 확인 결과 `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-35`로 기록됐다.
- 이후 `main-36`에서 native 배치 실패, `OPEN` 취소, A3/A4 한 장 교체 사전 확인 안내를 한국어로 보강했다.
- 저장된 활성 작업복사본 스냅샷 기준으로 `main-36`도 `/b` 읽기 전용 런타임 확인을 통과했다.
- `main-36` 확인 결과는 `SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE`, `SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL`이었다. 이 `FAIL`은 변환 전 저장본에 target GMTITLE 객체가 없다는 정상 진단이다.
- 이후 `main-37`에서 검증/더블클릭/A3-A4 교체 로그의 직접 라벨을 한국어로 보강했다.
- `main-37`도 `/b` 읽기 전용 런타임 확인을 통과했고, `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-37`로 기록됐다.
- `main-37` 확인 결과 역시 변환 전 저장본 기준 `SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE`, `SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL`이었다.

다만 이 검증은 저장된 디스크 DWG를 복사한 `work/swtitle_runtime_check_260703_workcopy.dwg`에서 수행됐다. 그 저장본은 아직 변환 전 상태였기 때문에 `SWTITLEVERIFY_FINAL_FAIL`이 정상적으로 나왔다.

남은 확인:

- 실제 변환이 반영된 저장된 작업복사본에서 `SWTITLESTATUS`와 `SWTITLEVERIFY`를 다시 실행한다.
- Computer Use 좌표/키 입력과 COM 자동화는 실제 변환 흐름의 안정적인 명령 입력 경로로 쓰지 않는다. 같은 실수를 반복하지 않도록, 실제 변환 확인은 GstarCAD 명령줄에서 직접 `APPLOAD` 후 4단계 명령을 실행하는 방식으로 시작한다.
- 작업 복사본 DWG에서 아래 순서를 다시 실행한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT
SWTITLEVERIFY
```

최종 통과 기준:

- 남은 SolidWorks 원본 표제란/도면틀 후보가 없다.
- 원본 도면에 있던 A2/A3/A4 크기와 대상 도면틀/제목블록 수가 맞다.
- A3 도면틀 안에 표제란이 중복으로 들어오지 않는다.
- A4 frame-only 시트가 삭제되거나 누락되지 않는다.
- 대표 `DR_titlea_3rd` 더블클릭 시 GMTITLE 표 편집창이 열린다.
- `SWTITLEVERIFY` 통합 최종 결과가 OK이거나, 남은 WARN이 사용자가 확인 가능한 수동 더블클릭 검증만 요구한다.

## 반복 실수 방지

다음 작업을 시작하기 전에는 항상 아래를 먼저 확인한다.

1. `git log --oneline --decorate -n 20`
2. 관련 커밋의 `git show --stat`
3. 최신 `work/*.txt` 로그
4. 이 문서와 `docs/history/gmtitle-four-command-recovery-plan-2026-07-03.md`

위 이력에서 이미 실패한 방식이면 새 기능을 만들기 전에 방향을 다시 잡는다.
