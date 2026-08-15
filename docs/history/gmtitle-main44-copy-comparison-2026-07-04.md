# GMTITLE main44 LSP 복사본 비교 - 2026-07-04

## 결론

현재 기준으로는 `main44` 원본 LSP를 채택한다.

복사본은 원본과 동일한지 확인하기 위한 테스트 기준선이며, 별도 개선본으로 보지 않는다.

## 비교 대상

원본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

테스트 복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_current_main44_compare_copy.lsp
```

## 해시 비교

두 파일의 SHA256은 동일하다.

```text
5EE65667AEF6D4C69FC38C2AD76640376DB7438FF8B7E3525197C52871D5D58F
```

따라서 main44 복사본은 원본과 같은 파일이다.

## GstarCAD 런타임 확인

가벼운 읽기 전용 `/b` probe를 만들었다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_version_probe_main44_260704.lsp
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_version_probe_main44_260704.scr
C:\Users\DR-DESIGN\Documents\CAD tool\work\run_swtitle_version_probe_main44_260704.ps1
```

실행 로그:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_version_probe_main44_260704.txt
```

핵심 결과:

```text
Load result: OK
Loaded version: 260704-history-gated-manual-gmtitle-main-44
Expected version: 260704-history-gated-manual-gmtitle-main-44
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Command c:SWTITLEVERSION: yes
Command c:SWSCALESCAN: yes
Command-line GMTITLE enabled: no
Probe completed: yes
```

이 확인은 도면 변환을 실행하지 않는다.
LSP 로드 가능 여부, 공개 명령 등록 여부, 명령줄 `-GMTITLE` 자동 선택 비활성 상태만 확인한다.

## 읽기 전용 명령 런타임 확인

추가로 `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY`가 실제 GstarCAD `/b` 런타임에서 실행되는지 확인했다.

테스트 스크립트:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_lsp_compare_main44_260704.lsp
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_lsp_compare_main44_260704.scr
```

실행 로그:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_lsp_compare_main44_260704.txt
```

결과:

```text
Load result: OK
Loaded version: 260704-history-gated-manual-gmtitle-main-44
Expected version: 260704-history-gated-manual-gmtitle-main-44
Run: SWTITLEVERSION
Result: OK SWTITLEVERSION status=<status variable missing>
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

`SWTITLEVERIFY_FINAL_FAIL`은 이 테스트 DWG가 변환 전 상태라 target `DR_A*_Outline`/`DR_titlea_3rd`가 없다는 정상 진단이다.
따라서 이 결과는 “변환 완료”가 아니라 “main44 LSP가 실제 CAD에서 로드되고 읽기 전용 통합 명령이 실행된다”는 증거로 본다.

## main43과 main44 판단

`main43`은 도면틀 정의 진단과 정규화 gate를 추가한 기준선이다.

`main44`는 여기에 실제 CAD 이력에서 반복 실패가 확인된 명령줄 `-GMTITLE` 자동 선택을 기본 비활성화했다.

따라서 현재 사용자 흐름에는 main44가 더 적합하다.

이유:

- 첫 native GMTITLE 선택에서 일반 A3/A0, ISO 제목블록, Object move ON 기본값이 반복 관찰됐다.
- 키보드 자동 입력으로 `DR_A2_Outline`을 넣어도 원하는 항목을 안정적으로 선택하지 못했다.
- 화면 좌표/드롭다운 위치 자동화는 이전 이력에서 배제한 방식이다.
- main44는 이 실패 경로를 기본값에서 제거하고, 사람이 `GMTITLE` 창에서 DR 용지와 `DR_titlea_3rd`를 직접 확인하게 한다.

## 남은 일

main44는 전체 변환 완료 증거가 아니다.

아직 필요한 실제 CAD 검증:

```text
APPLOAD
SWTITLEVERSION
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLEVERIFY
대표 DR_titlea_3rd 더블클릭 확인
```

완료 기준:

```text
SWTITLEVERIFY_FINAL_OK
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
A3 도면틀/표제란 중복 없음
A4 frame-only 누락 없음
도면 내부 번호/주석/텍스트 삭제 없음
```
