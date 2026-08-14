# GMTITLE main-42 목표 대비 완료 감사

날짜: 2026-07-04

## 결론

목표는 아직 `완료 아님`이다.

`260703-integrated-flow-main-42` 기준으로 4개 명령 구조와 내부 분기, 한국어 안내, 자동 실행 guard는 코드/문서상 구현되어 있다.
하지만 실제 작업복사본 DWG에서 전체 변환이 끝났다는 증거는 아직 없다.

완료 증거가 되려면 작업복사본에서 `SWTITLEVERIFY_FINAL_OK` 또는 수동 더블클릭 확인만 남은 제한적인 `WARN`이 나와야 하고, 대표 A2/A3/A4의 `DR_titlea_3rd` 제목블록을 더블클릭했을 때 GMTITLE 표 편집창이 열려야 한다.

## 현재 기준

```text
LSP: src/tools/gmtitle/swcad_title_scale.lsp
Version: 260703-integrated-flow-main-42
Public GMTITLE commands:
  SWTITLESTATUS
  SWTITLEPREPARE
  SWTITLECONVERT
  SWTITLEVERIFY
Read-only helpers:
  SWTITLEVERSION
  SWSCALESCAN
```

`main-42`의 새 보강:

- `SWTITLEPREPARE`가 `SCRIPT`나 `/b` 실행 상태에서 `ABORT_PREPARE_SCRIPT_ACTIVE`로 중단한다.
- YES 확인이 필요한 정리 작업은 CAD 명령줄에서 직접 실행한다.
- 자동 확인은 읽기 전용 `SWTITLESTATUS`, `SWTITLEVERIFY`에 한정한다.

## 정적 검증

2026-07-04 정적 확인:

```text
UTF8 Lisp balance: Depth=0 MinDepth=0 InString=False
git diff --check: 통과
```

`git diff --check` 출력에는 `.gitignore` 줄바꿈 안내만 있었다.

공개 명령 검색 결과:

```text
c:SWTITLESTATUS
c:SWTITLEPREPARE
c:SWTITLECONVERT
c:SWTITLEVERIFY
c:SWTITLEVERSION
c:SWSCALESCAN
```

예전 fast/batch/A3A4/frame-only/transfer apply 계열 공개 명령은 `src/tools/gmtitle/swcad_title_scale.lsp`에서 다시 노출되지 않았다.

## 요구사항별 판단

| 요구사항 | 현재 증거 | 판정 |
| --- | --- | --- |
| 4개 명령 흐름으로 통합 | 공개 `c:` 명령은 `SWTITLESTATUS/PREPARE/CONVERT/VERIFY`와 helper 2개뿐 | 구현됨 |
| `SWTITLESTATUS`가 A2/A3/A4, 원본, target, 내장 표제란, bbox 위험, 다음 조치를 진단 | `swcad-title-integrated-status`가 `fast-status`, `frame-def-check`, `frame-embedded-title-records`, `native-frame-completion-check`, `integrated-structure-diagnosis`, `next-step` 호출 | 구현됨, 실제 최신 DWG 재실행 필요 |
| `SWTITLEPREPARE`가 A2/A3/A4 공통 도면틀 정의 정규화 | `swcad-title-integrated-prepare`가 실수 명령어, 도면틀 정의 중첩 제목블록, DR 도면틀 내부 표제란, 고아 도면틀 정리를 한 흐름에 묶음 | 구현됨 |
| `SWTITLEPREPARE`가 자동 실행 중 입력 대기로 멈추지 않음 | `main-42`에서 `swcad-title-script-active-p`면 `ABORT_PREPARE_SCRIPT_ACTIVE`로 중단 | 정적 구현됨, CAD 런타임 guard 재확인 필요 |
| `SWTITLECONVERT`가 첫 native, frame-only, fast batch, A3/A4 native 교체를 내부 처리 | `swcad-title-integrated-convert`가 source/frame-only/native-example/A3A4 후보에 따라 내부 분기 | 구현됨 |
| `SWTITLECONVERT`를 `/b` 자동 실행으로 밀어붙이지 않음 | `c:SWTITLECONVERT`와 내부 convert가 `SCRIPT` 상태에서 `ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE`로 중단 | main-38 런타임 guard 확인 완료 |
| `SWTITLEVERIFY`가 중복/누락/native-like/수량/더블클릭 대상을 최종 요약 | `swcad-title-integrated-verify`가 전체 검증, native frame check, double-click check, final summary 호출 | 구현됨 |
| 원본 A2/A3/A4 수량 대비 target 수량 검증 | `main-40` 이후 expected sheet count xdata와 `count-shortage/excess` 출력 | 내부 경로 런타임 확인 완료 |
| 최종 변환 완료 | 최신 저장 작업복사본 기준 `SWTITLEVERIFY_FINAL_OK` 증거 없음 | 미완료 |
| 대표 A2/A3/A4 더블클릭 GMTITLE 표 편집창 확인 | 최신 main-42 기준 실제 더블클릭 완료 증거 없음 | 미완료 |

## 다음 실제 CAD 순서

작업복사본 DWG를 열고 아래 순서로 진행한다.

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp

SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT
SWTITLEVERIFY
```

`SWTITLESTATUS`가 다른 다음 명령을 안내하면 그 안내를 우선한다.
`SWTITLECONVERT`는 한 번 실행 후 항상 `SWTITLESTATUS`를 다시 확인한다.

## GMTITLE 창 확인 규칙

`SWTITLECONVERT` 중 GMTITLE 창이 열리면 반드시 눈으로 확인한다.

```text
용지: 로그가 요구한 DR_A*_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

일반 A3/A4, ISO 제목블록, Object move ON이면 OK를 누르지 않는다.

## 최종 완료 기준

아래가 모두 확인되어야 목표 완료로 본다.

- `SWTITLEVERIFY` 최종 결과가 `OK`, 또는 남은 항목이 수동 더블클릭 확인뿐인 제한적 `WARN`.
- 원본 SolidWorks 표제란/도면틀 후보가 남지 않음.
- 변환 기준 A2/A3/A4 수량과 target `DR_A*_Outline` 수량이 맞음.
- `DR_titlea_3rd` 제목블록 속성 태그가 누락되지 않음.
- A3 도면틀 안에 중복 표제란 형상이 남지 않음.
- A4 frame-only 시트가 삭제/누락되지 않음.
- 대표 A2/A3/A4 `DR_titlea_3rd` 제목블록 더블클릭 시 GMTITLE 표 편집창이 열림.
