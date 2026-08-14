# GMTITLE origin/main LSP와 현재 main45 LSP 복사본 비교 - 2026-07-04

## 목적

GitHub에 올라간 마지막 LSP와 현재 로컬 작업트리의 main45 LSP를 복사본으로 분리해서 비교했다.

비교 목적은 다음 두 가지다.

```text
1. 같은 실수를 반복하지 않기 위해 GitHub/로컬 이력 차이를 명확히 남긴다.
2. 앞으로 실제 CAD 검증을 어느 LSP 기준으로 이어갈지 결정한다.
```

## 비교 대상

GitHub/HEAD 기준 복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_origin_main_0121ae1_compare_copy.lsp
버전: 260702-command-surface-cleanup-1
SHA256: E25A281FAAC22885BFBC08BF617098D912F6FEB6CB69F9F0E77C546EB10FBA8D
```

현재 로컬 main45 복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_current_main45_compare_copy.lsp
버전: 260704-frame-definition-classification-main-45
SHA256: BB80F09CFDE8C083231D1106CEAF8C2A6DD83F40F8D8A59D30B295C5FD7A8AF8
```

현재 실제 원본 LSP:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
SHA256: BB80F09CFDE8C083231D1106CEAF8C2A6DD83F40F8D8A59D30B295C5FD7A8AF8
```

즉 현재 main45 복사본은 실제 원본 LSP와 동일하다.

## 정적 공개 명령 비교

정적 검색 명령:

```powershell
rg -n "^\(defun c:" work\lsp_compare\swcad_title_scale_origin_main_0121ae1_compare_copy.lsp
rg -n "^\(defun c:" work\lsp_compare\swcad_title_scale_current_main45_compare_copy.lsp
```

결과:

```text
origin/main 0121ae1: public c: command definitions = 21
current main45:      public c: command definitions = 6
```

origin/main 0121ae1에는 아래 같은 예전 실험/진단/복구 명령이 아직 공개 `c:` 명령으로 남아 있다.

```text
SWTITLEMULTIPREVIEW
SWTITLEGMTITLEVERIFYALL
SWTITLENATIVEFRAMECHECK
SWTITLESTATUSREFRESH
SWTITLEPICKCHECK
SWTITLEDOUBLECLICKCHECK
SWTITLEUPGRADENATIVESTATUS
SWTITLEA3A4NEXT
SWTITLEA3A4ALL
SWTITLEFASTSTATUS
SWTITLENEXTSTEP
SWTITLETRANSFERPREVIEW
SWTITLETRANSFERAPPLY
SWTITLETRANSFERFASTBATCH
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLEFRAMEONLYAPPLY
```

현재 main45에는 아래만 공개 명령으로 남아 있다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
SWTITLEVERSION
SWSCALESCAN
```

판단:

```text
사용자가 따라야 하는 GMTITLE 흐름은 main45가 더 명확하다.
SWTITLEVERSION과 SWSCALESCAN은 보조 읽기 전용 명령이고,
실제 GMTITLE 변환 사용자 흐름은 SWTITLESTATUS/SWTITLEPREPARE/SWTITLECONVERT/SWTITLEVERIFY 네 개로 정리되어 있다.
```

## 읽기 전용 CAD probe 비교

추가한 probe:

```text
diagnostics/gmtitle-main45/lsp_copy_compare_probe.lsp
diagnostics/gmtitle-main45/run_lsp_copy_compare_probe.ps1
```

주의:

```text
GstarCAD 시작 시 다른 LSP가 자동 로드될 수 있으므로 런타임의 "Command exists" 결과는 오염될 수 있다.
공개 명령 표면은 정적 `defun c:` 검색을 기준으로 판단한다.
현재 probe는 심볼 존재 여부만 보지 않고 실제 함수 값이 남아 있는지도 확인한다. main45는 로드 시 대표 레거시 공개 명령을 nil 처리해서 이전 세션/자동 로드 흔적을 줄인다.
```

### origin/main 0121ae1

로그:

```text
work\swtitle_lsp_copy_compare_origin_main_0121ae1.txt
```

핵심 결과:

```text
Load result: OK
Loaded version: 260702-command-surface-cleanup-1
Run: SWTITLEVERSION
Result: OK SWTITLEVERSION status=<status variable missing>
Run: SWTITLESTATUS
Runtime log was not completed before timeout.
```

판단:

```text
origin/main LSP는 로드는 되지만 같은 작업복사본에서 SWTITLESTATUS가 90초 안에 완료되지 않았다.
또한 정적 명령 표면이 21개라서 현재 목표인 4단계 통합 흐름과 맞지 않는다.
```

### current main45

로그:

```text
work\swtitle_lsp_copy_compare_current_main45.txt
```

핵심 결과:

```text
Load result: OK
Loaded version: 260704-frame-definition-classification-main-45
Four workflow commands:
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Legacy command runtime sample:
Command c:SWTITLEFASTSTATUS: no
Command c:SWTITLETRANSFERBOOTSTRAPFAST: no
Command c:SWTITLETRANSFERFASTBATCH: no
Command c:SWTITLEFRAMEONLYAPPLY: no
Command c:SWTITLEA3A4NEXT: no
Command c:SWTITLEA3A4ALL: no
Command c:SWTITLEGMTITLEVERIFYALL: no
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
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
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

`SWTITLEVERIFY_FINAL_FAIL`은 변환 전 작업복사본이라 target GMTITLE 도면틀/제목블록이 없다는 정상 진단이다.

중요한 점은 main45가 현재 작업복사본에서 다음을 안정적으로 출력했다는 것이다.

```text
다음 단계: NEXT_CREATE_FIRST_NATIVE_GMTITLE
원본 표제란: 13
원본 도면틀: 15
A4 frame-only: 2
A2/A3/A4 기준 수량: 1 / 12 / 2
도면틀 정의 차단 항목: 0
도면틀 내부 표제란 정리 후보: 0
```

## 결론

현재 비교에서는 `current main45`가 더 좋다.

이유:

```text
1. 실제 원본 LSP와 main45 복사본 해시가 동일하다.
2. 공개 GMTITLE 사용자 흐름이 네 명령으로 정리되어 있다.
3. origin/main은 예전 공개 명령이 많이 남아 있어 사용 순서가 다시 헷갈릴 수 있다.
4. main45는 같은 작업복사본에서 SWTITLESTATUS와 SWTITLEVERIFY 읽기 전용 probe를 끝까지 완료했다.
5. main45는 A3 native-format 형상을 source-contaminated와 구분하는 현재 방향을 포함한다.
6. main45는 CAD 세션에 남을 수 있는 대표 예전 명령도 로드 시 비활성화한다.
```

따라서 다음 실제 CAD 변환 검증은 `current main45` 기준으로 이어간다.

## 아직 완료가 아닌 것

이 비교는 LSP 선택 기준을 정한 것이다. 전체 목표 완료 증거는 아니다.

완료로 보려면 실제 작업복사본에서 아래가 필요하다.

```text
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
필요 시 SWTITLEPREPARE 또는 SWTITLECONVERT 반복
SWTITLEVERIFY
SWTITLEVERIFY_FINAL_OK
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
```

이 조건이 충족되기 전까지는 GitHub에 "완료"로 올리지 않는다.
