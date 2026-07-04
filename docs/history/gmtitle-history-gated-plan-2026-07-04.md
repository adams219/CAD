# GMTITLE 이력 게이트 기반 실행 계획 - 2026-07-04

## 목적

이 계획의 목적은 A3 한 장, A4 한 장을 임시로 고치는 것이 아니다.

앞으로 GMTITLE 변환 작업은 GitHub 원격 이력, 로컬 Git 이력, 현재 CAD 로그를 먼저 확인한 뒤에만 진행한다. 이렇게 해서 이미 실패한 방식, 예를 들면 좌표 클릭 자동화, 공개 명령 추가, clone 결과를 최종 성공으로 보는 판단을 반복하지 않는다.

## 현재 기준

2026-07-04 확인 결과:

```text
GitHub origin/main: 0121ae1 Clean up GMTITLE command surface
로컬 HEAD:        0121ae1 Clean up GMTITLE command surface
현재 브랜치:      codex/gm-title
현재 LSP 기준:    260704-frame-definition-classification-main-45
현재 LSP SHA256:  BB80F09CFDE8C083231D1106CEAF8C2A6DD83F40F8D8A59D30B295C5FD7A8AF8
```

중요한 점:

```text
main45 관련 LSP/문서 수정은 아직 작업트리에 남아 있다.
즉, GitHub main에는 아직 main45 최신 수정이 올라간 상태가 아니다.
```

따라서 CAD 테스트와 문서 판단은 로컬 작업트리의 최신 LSP를 기준으로 해야 하며, GitHub 화면만 보고 최신 상태라고 판단하지 않는다.

2026-07-04 추가 검증:

```text
git fetch --all --prune 후 origin/main은 여전히 0121ae1이다.
현재 로컬 main45 LSP와 비교 복사본 해시는 서로 일치한다.
GstarCAD hidden loader/copy probe에서 대표 예전 명령은 모두 비활성화됐다.
```

비활성화 확인 샘플:

```text
SWTITLEFASTSTATUS: no
SWTITLETRANSFERBOOTSTRAPFAST: no
SWTITLETRANSFERFASTBATCH: no
SWTITLEFRAMEONLYAPPLY: no
SWTITLEA3A4NEXT: no
SWTITLEA3A4ALL: no
SWTITLEGMTITLEVERIFYALL: no
```

## 작업 전 필수 게이트

GMTITLE 관련 판단, 코드 수정, CAD 테스트를 시작하기 전에는 아래를 먼저 확인한다.

```text
git status --short --branch
git log --oneline --decorate -n 25
git fetch --all --prune
```

그 다음 CAD에서 아래를 확인한다.

```text
SWTITLEVERSION
SWTITLESTATUS
```

확인해야 할 항목:

- 현재 열린 DWG가 `C:\Users\DR-DESIGN\Documents\CAD tool\work` 안의 작업복사본인지
- CAD에 로드된 LSP가 `260704-frame-definition-classification-main-45`인지
- `SWTITLESTATUS` 로그의 `DWG 파일:` 경로가 실제 열린 도면과 같은지
- `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 정의 유형이 `unknown / outline-only / native-format-with-title-geometry / source-contaminated` 중 무엇인지
- 다음 권장 명령이 `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 중 무엇인지

이 게이트를 통과하지 못하면 `SWTITLECONVERT`를 반복 실행하지 않는다.

## 세션별 이력 사용 원칙

앞으로 GMTITLE 작업을 다시 시작할 때는 바로 CAD 명령을 누르지 않고, 먼저 짧은 이력 스냅샷을 만든다.

```text
1. 원격/GitHub 기준: origin/main의 최신 커밋과 마지막 푸시 시점
2. 로컬 기준: 현재 브랜치, 미커밋 파일, 현재 LSP 버전
3. CAD 기준: 열린 DWG 경로, SWTITLEVERSION, SWTITLESTATUS 결과
4. 문서 기준: 이 계획 문서와 main45 검증 인덱스의 결론
```

이 네 가지가 서로 맞지 않으면 구현을 진행하지 않는다.

특히 다음 상황은 같은 실수를 반복할 위험 신호로 본다.

```text
GitHub에는 오래된 커밋만 있고 로컬에 미커밋 LSP가 있음
CAD에는 예전 LSP가 로드되어 있음
예전 공개 명령인 SWTITLEFASTSTATUS, SWTITLETRANSFERBOOTSTRAPFAST, SWTITLEA3A4NEXT 등이 아직 실행됨
열린 DWG가 work 복사본이 아니라 Downloads 또는 원본 폴더 파일임
SWTITLESTATUS 없이 SWTITLECONVERT를 다시 누르려 함
A3 내부 형상을 source 오염인지 native-format인지 구분하지 않고 삭제하려 함
A4 frame-only 시트를 일반 표제란 시트처럼 처리하려 함
```

이 위험 신호가 있으면 먼저 상태를 정리하고, 다음 조치를 문서나 로그에 남긴 뒤 진행한다.

## 판단 기록 규칙

새 수정이나 새 명령을 만들기 전에 아래 형식으로 판단 근거를 남긴다.

```text
문제:
  예: A3에서 도면틀과 표제란이 하나로 합쳐져 보임

이미 실패한 방식:
  예: A3 내부 title-like 형상을 무조건 삭제
  예: -GMTITLE 자동 선택
  예: 화면 좌표 클릭

이번 판단 기준:
  예: 설치 원본 DR_A3_Outline class
  예: source-like child block 존재 여부
  예: SWTITLEVERIFY의 남은 원본/target 수량

실행할 조치:
  예: 기존 4개 공개 명령 안에서 처리

완료로 보지 않는 조건:
  예: 더블클릭이 고급 속성 편집기로 열림
  예: A4 frame-only 누락
  예: SWTITLEVERIFY_FINAL_OK 아님
```

이 기록이 없으면 A3 전용, A4 전용, 복구 전용 공개 명령을 새로 만들지 않는다.

## CAD 파일 열기 주의

2026-07-04 실제 GstarCAD 화면 확인 중 아래 방식은 실패했다.

```text
(command "_.OPEN" "C:/Users/DR-DESIGN/Documents/CAD tool/work/....dwg")
```

GstarCAD가 파일 경로를 명령 인자로 안정적으로 처리하지 못하고, 경로 문자열을 알 수 없는 명령처럼 해석했다.

따라서 다음부터는 작업복사본을 열 때 아래 중 하나를 사용한다.

- 사용자가 GstarCAD에서 직접 작업복사본 DWG를 열기
- 이미 CAD를 조작해야 하는 상황이면 `(vla-open (vla-get-documents (vlax-get-acad-object)) "...dwg")`로 열고, 열린 탭을 확인한 뒤 진행

파일을 연 뒤에는 반드시 창 제목 또는 `SWTITLESTATUS` 로그의 `DWG 파일:` 경로가 의도한 작업복사본인지 확인한다.

## 이력에서 확정한 금지 방향

아래는 이미 Git/문서/테스트 이력에서 실패가 확인된 방향이다.

| 이력 | 앞으로의 원칙 |
| --- | --- |
| `f549ac2 Apply GM title transfer with fallback blocks` | 가짜/fallback 블록은 GMTITLE 편집창 동작을 보장하지 못한다. 최종 방식으로 쓰지 않는다. |
| `0bb4c9b Document GMTITLE first-native picker limits` | GMTITLE 용지/제목블록 선택을 화면 좌표나 드롭다운 위치 자동화에 맡기지 않는다. |
| `b69ff54 Require strict native GMTITLE exemplars` | 같은 모양의 복제본을 native GMTITLE로 바로 믿지 않는다. |
| `5ed90c1 Guard GMTITLE frame definition imports` | 변환 전 `DR_A*_Outline` 도면틀 정의 오염을 먼저 확인한다. |
| `843e453 Verify preserve-copy GMTITLE A4 frame-only` | preserve-copy/clone은 속도 개선용일 뿐, 더블클릭 검증을 대체하지 못한다. |
| `0121ae1 Clean up GMTITLE command surface` | 새 공개 명령을 계속 늘리지 않는다. 사용자 흐름은 네 명령으로 유지한다. |
| `docs/investigations/gmtitle-main45-verification-index-2026-07-04.md` | 설치 원본 `DR_A3_Outline` 자체에 title-like 형상이 있을 수 있다. source-like child가 없으면 자동 삭제하지 않는다. |

2026-07-04 실제 GstarCAD 화면 확인에서 추가로 확정한 금지 방향:

- `SWTITLECONVERT` 내부 명령줄 `-GMTITLE` 자동 선택은 새 GMTITLE INSERT를 만들지 못했다.
- 대화식 `GMTITLE` 창의 기본값은 `A3/A0`, `ISO 제목 블록 A`, `Object move ON`처럼 잘못 열릴 수 있다.
- 키보드 자동 입력으로 `DR_A2_Outline`을 입력해도 정확히 선택되지 않고 다른 용지로 바뀔 수 있다.
- 그래서 main44부터 명령줄 `-GMTITLE` 자동 선택은 기본으로 사용하지 않고, main45에서도 이 금지는 유지한다.
- 따라서 GMTITLE 창의 용지/제목블록 선택은 자동 입력 결과를 믿지 말고 사용자가 눈으로 확인해야 한다.

따라서 공개 사용자 명령은 계속 아래 네 개로 고정한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

`SWTITLEVERSION`은 버전 확인용 보조 명령으로만 사용한다.

만약 CAD에서 아래 예전 명령이 실행된다면 현재 세션은 오래된 LSP 상태로 보고, 변환을 멈춘 뒤 `swcad_load.lsp`를 다시 APPLOAD하고 `SWTITLEVERSION`, `SWTITLESTATUS`부터 확인한다.

```text
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
SWTITLEA3A4ALL
SWTITLEGMTITLEVERIFYALL
```

## 현재 문제 모델

현재 핵심 문제는 위치가 아니라 구조다.

```text
A2: 도면틀만 들어오는 상태가 기대와 맞음
A3: 설치 원본 DR_A3_Outline 정의 안에도 title-like 형상이 있을 수 있음.
    이것은 source 오염이 아닐 수 있으므로 모양만 보고 삭제하지 않음.
    사용자가 원하는 표준 A3가 "도면틀만"인지, GstarCAD native A3처럼 일부 title-like 형상을 포함하는지 먼저 확정해야 함.
A4: 원본은 frame-only라서 표제란 있는 시트와 같은 방식으로 처리하면 안 됨
```

즉, 먼저 분리해야 할 것은 아래 네 가지다.

- 원본 SolidWorks 도면틀/표제란
- target `DR_A*_Outline` 도면틀
- target `DR_titlea_3rd` 제목블록
- `DR_A*_Outline` 블록 정의 내부의 native-format 형상
- `DR_A*_Outline` 블록 정의 내부에 섞인 source-contaminated 객체

도면 안쪽 주석, 번호, 치수, BOM, 모델 형상은 원본 도면 내용이므로 기본적으로 보호한다.

## A3/A4 구조 분석 기준

이번 문제는 특정 A3 한 장의 표제란만 지우는 문제가 아니다. 모든 도면 크기에 반복 적용하려면 아래 비교를 먼저 통과해야 한다.

| 비교 대상 | 확인할 것 | 판단 |
| --- | --- | --- |
| GstarCAD 설치 원본 `DR_A3_Outline.dwg` | 도면틀 정의 안에 원래 title-like 형상이 있는지 | source-like child가 없으면 `native-format-with-title-geometry`로 보고 자동 삭제 금지 |
| 현재 변환된 DWG의 `DR_A3_Outline` | 설치 원본과 다른 source-like child block이 섞였는지 | 섞였으면 `source-contaminated`로 보고 `SWTITLEPREPARE` 대상 |
| 현재 변환된 DWG의 `DR_titlea_3rd` | 별도 제목블록이 중복 삽입됐는지, 속성값이 채워졌는지 | 별도 제목블록은 유지하되 중복/고아 쌍은 검증에서 실패 처리 |
| A4 frame-only 원본 | 원래 표제란이 없는 시트인지 | 일반 표제란 시트와 같은 삭제/값 입력 로직을 적용하지 않음 |

따라서 A3에서 표제란처럼 보이는 형상이 있어도 바로 삭제하지 않는다. 먼저 `SWTITLESTATUS`와 `SWTITLEVERIFY`가 출력하는 class, source 후보 수, target 수량, 더블클릭 결과를 함께 본다.

반대로 A4는 원본에 표제란이 없으므로, 새 제목블록이 생기는 것이 항상 정답은 아니다. A4가 frame-only라면 도면틀 유지/교체 기준과 누락 여부를 별도로 검증한다.

## 실행 계획

### 1단계: 상태를 고정한다

먼저 작업복사본에서 `SWTITLESTATUS`를 실행한다.

목표:

- A2/A3/A4 원본 수량 확인
- target GMTITLE 수량 확인
- `DR_A*_Outline` 정의 유형 확인
- A3 내부 형상이 `native-format-with-title-geometry`인지 `source-contaminated`인지 확인
- A4 frame-only 후보 확인
- 다음 명령 확인

이 단계에서는 도면을 변경하지 않는다.

추가로 A3에 대해서는 아래를 확인한다.

```text
설치 원본 DR_A3_Outline이 가진 native-format 형상인가
현재 도면 변환 과정에서 source-like child가 섞인 오염인가
사용자가 원하는 표준 A3가 native-format을 유지하는 형태인가, frame-only 형태인가
```

이 세 가지가 분리되지 않으면 `SWTITLEPREPARE` 또는 삭제 로직을 바꾸지 않는다.

### 2단계: 변환 전에 정규화한다

`SWTITLESTATUS`가 `SWTITLEPREPARE`를 안내하면 변환하지 않고 먼저 `SWTITLEPREPARE`를 실행한다.

`SWTITLEPREPARE`가 담당할 일:

- 실수로 도면에 들어간 명령어 텍스트 정리
- 고아 `DR_A*_Outline` 정리
- `DR_A*_Outline` 정의 안의 중첩 제목블록 정리
- `DR_A*_Outline` 정의 안에 섞인 `source-contaminated` 객체 정리
- 정리 전 삭제 후보와 보호 후보를 로그에 남기기

삭제 기준은 항상 아래처럼 나눈다.

```text
DELETE: 기존 SolidWorks 표제란/도면틀 잔여물로 확실한 것
KEEP: 도면 안쪽 주석, 번호, 치수, BOM, 모델 형상
KEEP: 설치 원본/native-format일 수 있는 DR_A3_Outline 내부 형상
REVIEW: 자동 판단이 불확실한 것
```

`REVIEW`는 자동 삭제하지 않는다.

### 3단계: 변환은 네 명령 안에서만 진행한다

`SWTITLESTATUS`가 `SWTITLECONVERT`를 안내할 때만 `SWTITLECONVERT`를 실행한다.

GMTITLE 창이 열리면 사용자는 아래만 확인한다.

```text
용지: 로그가 요구한 DR_A2_Outline / DR_A3_Outline / DR_A4_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

일반 A3/A4, ISO 제목블록, Object move ON이면 확인하지 않고 취소한다.

한 번 변환한 뒤에는 바로 다음 변환을 누르지 않고 `SWTITLESTATUS`를 다시 실행한다.

### 4단계: 검증으로 완료를 판단한다

마지막에는 `SWTITLEVERIFY`를 실행한다.

완료 기준:

- 남은 원본 SolidWorks 표제란 후보 0
- 남은 원본 SolidWorks 도면틀 후보 0
- 도면틀 정의 정규화 차단 항목 0
- 원본 기준 A2/A3/A4 수량과 target `DR_A*_Outline` 수량 일치
- target `DR_titlea_3rd` 수량 일치
- A3 도면틀 정의 상태가 의도한 표준과 일치
- A3에서 별도 `DR_titlea_3rd`와 도면틀 내부 형상이 중복 표제란처럼 보이지 않음
- A4 frame-only 시트가 삭제되거나 누락되지 않음
- 고아 GMTITLE 도면틀 없음
- `SWTITLEVERIFY_FINAL_OK`
- 대표 A2/A3/A4 `DR_titlea_3rd` 더블클릭 시 GMTITLE 표 편집창 열림

모양이 맞아 보여도 위 조건이 맞지 않으면 완료로 보지 않는다.

## 다음 실제 작업 순서

1. GitHub/로컬 이력 확인
2. 작업복사본 DWG 열기
3. 최신 LSP `swcad_title_scale.lsp` APPLOAD
4. `SWTITLEVERSION`
5. `SWTITLESTATUS`
6. `SWTITLEPREPARE`가 안내되면 실행
7. 다시 `SWTITLESTATUS`
8. `SWTITLECONVERT`
9. 변환 1회마다 다시 `SWTITLESTATUS`
10. 더 이상 변환 대상이 없으면 `SWTITLEVERIFY`
11. 대표 제목블록 더블클릭 확인
12. 결과가 OK이면 커밋/푸시

## 커밋 기준

아래가 확인되기 전에는 GitHub에 완료 상태로 푸시하지 않는다.

- 최신 LSP가 CAD에서 로드됨
- 작업복사본 기준 `SWTITLESTATUS`/`SWTITLEVERIFY` 로그가 남음
- A3 도면틀 정의 문제와 A4 frame-only 문제가 같은 계획 안에서 설명됨
- 사용자가 직접 입력해야 하는 공개 명령이 네 개로 유지됨
- 실제 완료가 아니라면 문서에 `완료 아님`으로 남김
