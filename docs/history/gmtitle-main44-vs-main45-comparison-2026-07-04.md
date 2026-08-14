# GMTITLE main44 vs main45 비교 결론 - 2026-07-04

## 결론

현재 선택은 `main45`가 더 좋다.

`main44`도 실제 GstarCAD에서 로드되고 4단계 공개 명령이 등록되는 것은 확인됐다. 하지만 `main44`는 A3 도면틀 정의 안의 표제란처럼 보이는 형상을 native 구조와 source 오염으로 구분하는 증거가 부족하다.

`main45`는 설치 원본 `DR_A3_Outline.dwg` 자체가 lower-right title-like 형상 10개를 가지고 있음을 확인했고, 이 형상을 자동 삭제/정리 대상으로 보지 않도록 분류를 나눴다.

따라서 앞으로 실제 CAD 변환 검증은 `main45` 기준으로 진행한다.

## 비교 대상

원본 LSP:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

현재 main45 테스트 복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_current_main45_frameclass_compare_copy.lsp
```

현재 원본/복사본 SHA256:

```text
FD41E114DF5E1F598E3FFB691C3E0ABD42E80B49AFA9A03635A1664095581E1F
```

두 파일은 같은 내용이다.

main45 런타임 fixture와 로그 증거의 추적용 인덱스:

```text
docs/investigations/gmtitle-main45-verification-index-2026-07-04.md
```

## 현재 복사본 해시 재확인

2026-07-04 이어서 작업하면서 현재 `work\lsp_compare`의 비교 복사본을 다시 확인했다.

```text
main43 copy: 99ABB6DBF8AD802E402BC4AEC163E9B59A4535516B368FB8BB9B2BE30F2DF585
main44 copy: 5EE65667AEF6D4C69FC38C2AD76640376DB7438FF8B7E3525197C52871D5D58F
main45 copy: FD41E114DF5E1F598E3FFB691C3E0ABD42E80B49AFA9A03635A1664095581E1F
source LSP:   FD41E114DF5E1F598E3FFB691C3E0ABD42E80B49AFA9A03635A1664095581E1F
```

즉 현재 실제 원본 LSP는 `main45` 복사본과 동일하고, `main43/main44` 복사본과는 다르다.

## main44 검증 결과

로그:

```text
work\swtitle_lsp_compare_main44_260704.txt
```

결과:

```text
Load result: OK
Loaded version: 260704-history-gated-manual-gmtitle-main-44
Expected version: 260704-history-gated-manual-gmtitle-main-44
Run: SWTITLEVERSION
Result: OK
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

판단:

```text
main44는 로드와 읽기 전용 공개 명령 실행은 통과했다.
명령줄 -GMTITLE 자동 선택을 기본 사용하지 않도록 바꾼 점은 좋은 방향이다.
하지만 설치 원본 A3 도면틀 내부 형상을 native 구조로 분리하는 검증은 없다.
```

## main45 검증 결과

로그:

```text
work\swtitle_version_probe_main45_260704.txt
work\swtitle_lsp_compare_main45_260704.txt
work\swtitle_frameclass_fixture_main45_260704.txt
work\swtitle_install_frame_scan_main45_260704.txt
work\swtitle_convert_guard_main45_260704.txt
work\swtitle_prepare_guard_main45_260704.txt
work\swtitle_status_nativeformat_fixture_main45_260704.txt
work\swtitle_title_protection_fixture_main45_260704.txt
work\swtitle_verify_nativeformat_fixture_main45_260704.txt
```

결과 요약:

```text
Load result: OK
Loaded version: 260704-frame-definition-classification-main-45
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Command-line GMTITLE enabled: no

Run SWTITLECONVERT: ok
Convert status: ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE
Convert guard passed: yes

Run SWTITLEPREPARE: ok
Prepare status: ABORT_PREPARE_SCRIPT_ACTIVE
Prepare guard passed: yes

DR_A2_Outline class: outline-only
DR_A3_Outline class: native-format-with-title-geometry
DR_A4_Outline class: outline-only
Blocking records: 0
Cleanup records: 0
All embedded records: 10
Install frame scan passed: yes

DR_A3_Outline class after verify: native-format-with-title-geometry
Blocking records after verify: 0
Cleanup records after verify: 0
Native-format verify passed: yes

Run SWTITLESTATUS: ok
Structure next action: SWTITLECONVERT - 남은 원본 SolidWorks 시트 변환
DR_A3_Outline class after status: native-format-with-title-geometry
Blocking records after status: 0
Cleanup records after status: 0
Native-format status passed: yes

Normal DR_titlea_3rd insert count: 1
Frame-definition child-title cleanup candidates: 0
Frame embedded-title cleanup candidates: 0
Frame-definition blockers: 0
Normal title protection passed: yes
```

판단:

```text
main45는 main44의 안전장치를 유지한다.
SCRIPT 자동 실행 중 SWTITLECONVERT가 native GMTITLE 대화식 단계로 들어가지 않는 것도 현재 main45에서 다시 확인했다.
SCRIPT 자동 실행 중 SWTITLEPREPARE가 YES 확인 정리 단계로 들어가지 않는 것도 현재 main45에서 다시 확인했다.
추가로 A3 내부 title-like 형상을 source 오염으로 오판하지 않는 검증을 통과했다.
또한 SWTITLESTATUS의 다음 행동 판단도 native A3 형상 때문에 SWTITLEPREPARE로 잘못 가지 않고 SWTITLECONVERT를 안내했다.
정상 `DR_titlea_3rd` 제목블록 INSERT도 도면틀 정의 내부 정리 후보로 오판하지 않았다.
따라서 A3 주석/도면틀 내부 native 형상을 지워버리는 실수를 줄일 수 있다.
```

### 현재 작업복사본 read-only 재확인

tracked runner:

```text
diagnostics/gmtitle-main45/run_actual_workcopy_status_probe.ps1
```

재실행 결과:

```text
Load result: OK
Loaded version: 260704-frame-definition-classification-main-45
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
frame-definition-blockers: 0
frame-embedded-cleanup-records: 0
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
target-sheet-counts:
  <none>
Runtime check completed: yes
```

해석:

```text
현재 작업복사본은 아직 첫 native GMTITLE 생성 전이다.
도면틀 정의 차단 항목은 0이다.
따라서 다음 실제 CAD 단계는 SWTITLECONVERT이다.
SWTITLEVERIFY_FINAL_FAIL은 변환 전 상태라 target GMTITLE 객체가 없다는 정상 진단이지 main45 실패가 아니다.
```

## 실제 의미

`SWTITLEVERIFY_FINAL_FAIL` 로그는 main44/main45 모두에서 나왔다. 이것은 테스트 DWG가 변환 완료 도면이 아니라 target GMTITLE 객체가 없는 읽기 전용 비교용 DWG이기 때문이다.

따라서 이 FAIL은 LSP 로드 실패나 main45 실패가 아니다.

현재 비교에서 중요한 증거는 다음이다.

```text
1. 실제 GstarCAD에서 LSP가 로드됨
2. 공개 4명령이 등록됨
3. 명령줄 GMTITLE 자동 선택이 꺼져 있음
4. 설치 원본 DR_A3_Outline의 내부 형상 10개를 native-format으로 분리함
5. 그 형상을 cleanup/blocking 대상으로 잡지 않음
```

## 남은 실제 CAD 검증

아직 전체 변환 완료는 아니다.

완료 증거는 실제 작업복사본에서 아래 조건이 충족될 때만 인정한다.

```text
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT
SWTITLEVERIFY
```

완료 기준:

```text
SWTITLEVERIFY_FINAL_OK
원본 기준 A2/A3/A4 수량과 target GMTITLE 수량 일치
남은 SolidWorks 원본 표제란 후보 0
남은 SolidWorks 원본 도면틀 후보 0
A3 제목블록 중복 없음
A4 frame-only 시트 누락 없음
도면 안의 번호/주석/BOM/텍스트 삭제 없음
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
```
