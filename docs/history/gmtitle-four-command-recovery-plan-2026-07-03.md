# GMTITLE 4단계 변환 계획 - 2026-07-03

## 목표

SolidWorks에서 저장된 DWG의 기존 도면틀/표제란을 GstarCAD Mechanical의 실제 `GMTITLE` 도면틀/표제란으로 바꾼다.

최종 사용 명령어는 아래 4개만 유지한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

기존 보조 명령어는 진단/복구용으로만 남기고, 일반 로그와 사용 설명에서는 위 4개 명령어로만 안내한다.

## 이력에서 확인한 실패 원인

로컬/GitHub 이력 기준:

- `0121ae1 Clean up GMTITLE command surface`
  - 공개 명령어가 계속 늘어나면 사용자가 어떤 명령을 써야 하는지 헷갈린다.
  - 이번 계획도 새 공개 명령어를 늘리지 않는다.

- `0bb4c9b Document GMTITLE first-native picker limits`
  - `GMTITLE`의 첫 용지/제목블록 선택은 명령줄이나 화면 좌표 자동화로 안정적으로 제어하기 어렵다.
  - 스크린샷 좌표 클릭이나 드롭다운 위치 의존을 기본 방식으로 쓰지 않는다.

- `b69ff54 Require strict native GMTITLE exemplars`
  - 복제된 GMTITLE이 모양은 같아도 native 편집 동작이 보장되지 않는다.
  - 최종 성공 기준은 `DR_titlea_3rd`를 더블클릭했을 때 GMTITLE 표 편집창이 열리는 것이다.

- `843e453 Verify preserve-copy GMTITLE A4 frame-only`
  - preserve-copy/clone 방식은 빠르지만, 모든 시트가 native 편집 동작을 보장하지 않는다.
  - 빠른 변환 뒤에도 A3/A4 native 교체 검증이 필요하다.

최근 CAD 로그 기준:

- A3 native 교체를 한 장 성공했다.
- 성공 로그는 `UPGRADED_CLONE_TO_NATIVE_GMTITLE`이고, A3/A4 교체 후보가 12장에서 11장으로 줄었다.
- `SWTITLEVERIFY`는 아직 OK가 아니라 WARN 상태다.
- 남은 문제는 A3/A4 후보 11장과 A4 frame-only 2장이다.
- 일부 로그가 아직 `SWTITLEA3A4NEXT`, `SWTITLEA3A4ALL` 같은 옛 보조 명령어를 안내해서 흐름을 헷갈리게 했다.

## 작업 전 이력 확인 절차

같은 실수를 반복하지 않기 위해, 새 수정이나 CAD 테스트를 시작하기 전에 아래 순서로 확인한다.

1. `git log --oneline --decorate -n 20`으로 최근 커밋 흐름을 먼저 본다.
2. `git show --stat` 또는 `git show <커밋>`으로 관련 커밋의 의도를 확인한다.
3. `work/*.txt` 최신 로그에서 실제 CAD가 어떤 상태였는지 확인한다.
4. 이미 실패로 판정된 방식인지 먼저 판단한다.

이미 실패 또는 제한이 확인된 방식:

- 화면 좌표 클릭으로 `GMTITLE` 선택을 자동화하는 방식
- 가짜/fallback `DR_A*_Outline`, `DR_titlea_3rd` 블록을 만드는 방식
- preserve-copy/clone 결과를 native GMTITLE이라고 바로 믿는 방식
- A3/A4를 여러 장 한 번에 열어 놓고 사람이 나중에 맞추는 방식
- 문제 하나마다 `SWTITLEA3...`, `SWTITLEFRAMEONLY...` 같은 공개 명령어를 계속 추가하는 방식

새 코드나 로그 안내가 위 방식으로 돌아가면, 기능을 더 만들기 전에 계획을 다시 확인한다.

## 문제를 나누는 기준

### 1. A3 도면틀 안에 표제란이 같이 들어오는 문제

증상:

- 원래 기대하는 `DR_A3_Outline`은 도면틀만 있어야 한다.
- 그런데 현재 일부 환경에서는 `DR_A3_Outline` 또는 그 하위 블록 안에 표제란 형상이 같이 들어 있다.
- 이 상태에서 `DR_titlea_3rd`를 따로 넣으면 표제란이 두 개처럼 보인다.

처리 방향:

- `SWTITLESTATUS`에서 도면틀 정의 내부 표제란 의심 요소를 경고한다.
- `SWTITLEPREPARE`에서 A2/A3/A4 공통 기준으로 도면틀 정의를 정규화한다.
- 삭제 대상은 title-area의 선/문자/로고처럼 명확한 잔여물로 제한한다.
- 좌표 눈금, `!GENTITLE-*` 같은 실제 도면틀 인식용 요소는 보호한다.

### 2. A3/A4 복제 GMTITLE이 고급 속성 편집기로 열리는 문제

증상:

- 빠른 복제 결과는 화면상으로는 맞아 보인다.
- 하지만 일부 `DR_titlea_3rd`를 더블클릭하면 GMTITLE 표 편집창이 아니라 고급 속성 편집기/블록 편집 흐름으로 열린다.

처리 방향:

- 복제 결과를 최종 성공으로 보지 않는다.
- `SWTITLECONVERT`가 A3/A4 native 교체 후보를 한 장씩 처리한다.
- 한 장마다 `GMTITLE` 창에서 아래 값을 눈으로 확인한다.

```text
용지: DR_A2_Outline / DR_A3_Outline / DR_A4_Outline 중 로그가 요구한 값
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

- 잘못된 기본값, 예를 들어 일반 `A3 (297x420mm)` 또는 `ISO 제목 블록 A`가 보이면 OK를 누르지 않고 취소한다.

### 3. A4 frame-only 문제

증상:

- 원본 A4에는 표제란이 없는 도면틀만 있을 수 있다.
- 일반 title sheet와 같은 방식으로 처리하면 제목블록이 불필요하게 생기거나 도면틀이 잘못 들어올 수 있다.

처리 방향:

- `SWTITLESTATUS`에서 frame-only 시트 개수를 별도로 보여준다.
- `SWTITLECONVERT`는 title sheet와 frame-only sheet를 분리해서 처리한다.
- A4는 첫 native 기준 객체가 없으면 `DR_A4_Outline`을 실제 GMTITLE로 한 번 만들어야 한다.
- A4 raw bbox가 이상하거나 원본 A4 형상과 맞지 않으면 자동 일괄 변환을 멈춘다.

## 반복 실수 방지 규칙

1. 새 공개 명령어를 추가하지 않는다.
2. 사용자는 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY`만 따른다.
3. `GMTITLE` 창이 열릴 때는 자동 클릭을 믿지 않고, 로그가 요구한 용지/제목블록/옵션을 확인한다.
4. A3/A4 native 교체는 한 번에 한 장만 진행한다.
5. `SWTITLECONVERT`가 `OPEN`을 요구하면, 값을 확인할 준비가 된 경우에만 `OPEN`을 입력한다.
6. 원본 DWG에서 바로 실행하지 않고 `Documents\CAD tool\work` 아래 복사본에서 먼저 실행한다.
7. 성공 여부는 모양이 아니라 `SWTITLEVERIFY`와 대표 시트 더블클릭으로 판단한다.

## 현재 코드 반영 사항

`260703-integrated-flow-main-35` 기준:

- 일반 로그가 옛 보조 명령어 대신 4단계 흐름으로 돌아오도록 안내 문구를 정리했다.
- `SWTITLESTATUS`에 구조 판단 요약을 추가해 A3/A4 문제의 다음 조치를 바로 보이게 했다.
- 구조 판단 요약도 `work/swcad_title_structure_diagnosis_last.txt` 로그로 남긴다.
- `SWTITLECONVERT`는 A3/A4 native 교체 후보를 한 장씩 처리한다.
- `SWTITLECONVERT`는 GMTITLE 창을 열기 전에 `OPEN` 확인을 요구한다.
- `SWTITLEVERSION`의 기대 버전을 `260703-integrated-flow-main-26`으로 올렸다.
- 남은 안내 문구 중 `SWTITLECONVERT`가 A3/A4 후보를 한 번에 모두 처리할 수 있다는 표현을 제거했다.
- `SWTITLESTATUS`의 다음 조치 안내 중 실제 화면에 보이던 영어 문장을 한국어로 바꿨다.
- `SWTITLEVERIFY`의 native-like 쌍 개수와 다음 조치 안내도 한국어로 바꿨다.
- 변환 완료/픽 체크/상태 갱신 경로에 남아 있던 영어 `Next:` 안내도 한국어로 정리했다.
- 추가 검색에서 남아 있던 `Next: run SWTITLE...`, `Manual final check...` 문구도 한국어로 정리했다.
- LSP 로드 메시지는 4개 통합 명령만 표시하도록 바꿨다.
- 오래된 fast/batch 경로의 사용자 안내도 `SWTITLESTATUS`와 `SWTITLECONVERT` 중심으로 되돌렸다.
- `docs/guide/commands.md`, `docs/guide/gmtitle-native-frame-upgrade.md`를 4단계 기준으로 다시 작성했다.
- 내부 변환 메시지와 한국어 치환 테이블에 남은 예전 fast/batch 명령 안내도 4단계 흐름으로 되돌렸다.
- 예전 공개 보조 명령을 공개 `c:` 명령에서 제거하고 내부 함수로 내렸다.
- `SWTITLESCAN`, A3/A4, frame-only, fast/batch, orphan/frame-definition 계열은 일반 CAD 명령창에서 직접 실행하는 흐름으로 쓰지 않는다.
- `SWTITLEVERSION`은 로드 확인용 읽기 전용 명령으로 남겼다.
- `SWTITLEVERIFY`가 호출하는 double-click/native-frame/GMTITLE 전체 검증 로그에 남아 있던 영어 안내를 한국어로 정리했다.
- clone/preserve-copy가 왜 native GMTITLE 증거로 부족한지 한국어로 설명하도록 보완했다.
- `SWTITLEVERIFY` 끝에 통합 최종 요약을 추가했다. 남은 원본 후보, 고아 도면틀, 도면틀 내부 표제란, A3/A4 native 교체 후보, 속성 태그 문제를 한 번 더 세고 `최종 결과: OK/WARN/FAIL`로 표시한다.
- `main-24`에서는 A2/A3/A4를 무조건 모두 요구하지 않고, 남은 원본 시트와 현재 보이는 GMTITLE 대상 시트 기준으로 필요한 용지만 누락 검사한다. A4가 원본에 없던 정상 도면이 불필요하게 WARN이 되는 것을 막기 위한 변경이다.
- `main-25`에서는 도면틀을 찾지 못한 원본 표제란의 `<missing-frame>` 값이 기본 A3 요구로 바뀌지 않도록 보완했다.
- `main-26`에서는 `Result:` 상태 코드에 한국어 설명을 대폭 보강했다. CAD 명령창에 `WARN_TARGET_FRAME_GEOMETRY_INVALID`, `NEEDS_NATIVE_A3A4_UPGRADE`, `ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS` 같은 코드가 나오더라도 사용자가 뜻과 다음 조치를 바로 이해할 수 있게 하기 위한 변경이다.
- `main-27`에서는 `/b` 런타임 확인이 일반 `swcad_title_*_last.txt` 작업 로그를 덮어쓰지 않도록 `_runtime_260703` 로그 접미사 옵션을 추가했다.
- `main-28`에서는 공개 흐름 중 사용자에게 직접 보일 수 있던 남은 영어 안내 문장을 한국어로 정리했다.
- `main-28`도 `/b` 읽기 전용 런타임 확인에서 로드와 읽기 전용 명령 실행이 확인됐다.
- `main-29`에서는 런타임 로그에서 확인된 잔여 영어/부분 번역 문구를 더 정리했다.
- `main-29`도 `/b` 읽기 전용 런타임 확인에서 로드와 읽기 전용 명령 실행이 확인됐다.
- `main-30`에서는 도면틀 정의 진단 로그의 잔여 영어/부분 번역 문구를 더 정리했다.
- `main-31`에서는 부분 번역 순서 때문에 남던 `존재: no/yes` 조각을 더 정리했다.

CAD 로드 검증:

- GstarCAD에서 `260703-integrated-flow-main-5`가 정상 로드됐다.
- `SWTITLEVERSION` 출력도 `260703-integrated-flow-main-5`로 확인됐다.
- `SWTITLEVERSION`은 읽기 전용이며 도면 데이터를 변경하지 않았다.
- CAD 명령 입력은 붙여넣기 방식으로 하면 `_pasteclip`으로 해석될 수 있으므로, 자동 검증 때는 붙여넣기 대신 한 글자씩 명령 입력하거나 명령줄 포커스를 확실히 확인한다.

추가 CAD 검증:

- GstarCAD에서 `260703-integrated-flow-main-10`을 다시 로드했다.
- `SWTITLESTATUS`와 `SWTITLEVERIFY`를 읽기 전용으로 실행했다.
- 최신 `work` 로그에서 옛 보조 명령어 안내와 영어 next-step 문구가 제거된 것을 확인했다.
- GstarCAD에서 `260703-integrated-flow-main-14`를 다시 로드했다.
- `SWTITLEVERSION` 출력이 로드 버전과 기대 버전 모두 `260703-integrated-flow-main-14`로 표시되는 것을 확인했다.
- 예전 보조 명령 `SWTITLEA3A4NEXT`를 입력했을 때 실제 native 교체를 실행하지 않고 `SWTITLECONVERT`로 안내하며 도면 데이터를 변경하지 않는 것을 확인했다.
- GstarCAD에서 `260703-integrated-flow-main-17`을 다시 로드했다.
- `SWTITLEVERIFY`를 읽기 전용으로 실행해 검증 로그를 갱신했다.
- `SWTITLEDOUBLECLICKCHECK`, `SWTITLEGMTITLEVERIFYALL`, `SWTITLENATIVEFRAMECHECK` 로그의 주요 다음 조치와 주의 문구가 한국어로 표시되는 것을 확인했다.
- 영어 잔여 문구 검색에서 기존 `Manual check rule`, `GMPOWEREDIT diagnosis`, `Clone means`, `DR_A*_Outline sheet frames are still` 같은 문구가 더 이상 최신 로그에 남지 않는 것을 확인했다.
- `SWTITLECONVERT`의 `OPEN` 없는 preflight 중단 경로를 실행했고, 다음 대상이 A3 `title=16E62`, `frame=16E61`임을 확인했다.
- `OPEN`을 입력해 GMTITLE 창을 실제로 열어 보니 GstarCAD가 요구값인 `DR_A3_Outline + DR_titlea_3rd`가 아니라 일반 `A3 (297x420mm) + ISO 제목 블록 A`와 `Object move ON` 상태로 열었다.
- 이 상태는 기존 이력에서 반복된 위험 조건이므로 OK를 누르지 않고 즉시 취소했다.
- 취소 후 로그는 `ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS`였고, 새 잘못된 GMTITLE insert는 0개, 기존 GMTITLE 쌍은 보존된 것으로 확인했다.
- 이후 `SWTITLECONVERT`/native-upgrade 로그의 영어 안내를 한국어로 보강해 `260703-integrated-flow-main-19`까지 수정했다.
- `main-20`에서는 예전 보조 `c:SWTITLE...` 명령 래퍼를 제거해 공개 GMTITLE 변환 명령을 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 네 개로 더 좁혔다.
- `main-21`에서는 내부 로그 헤더와 주요 프롬프트에 남아 있던 예전 보조 명령 이름과 영어 안내를 4단계 통합 흐름 기준의 한국어 문구로 더 정리했다.
- `main-21`에서는 `SWTITLEPREPARE`가 실수 명령어 TEXT/MTEXT 잔여물 후보도 내부에서 정리하도록 연결했다. 더 이상 사용자가 예전 정리 명령을 직접 입력하지 않는다.
- 좌표 클릭 반복을 피하기 위해 읽기 전용 런타임 확인 스크립트 `work/swtitle_readonly_runtime_check_260703.scr`를 만들었다. 이 스크립트는 `work/swtitle_readonly_runtime_check_260703.lsp`를 로드하고, 최신 원본 LSP를 로드한 뒤 `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY`만 실행한다.
- 스크립트 실행 후 `work/swtitle_runtime_loaded_last.txt`에 실제 로드 버전과 도면명이 기록된다.
- 다만 CAD 명령줄 포커스가 불안정해 `main-26` 런타임 로드는 아직 화면에서 확정하지 못했다. 다음 CAD 검증은 사람이 명령줄에 `APPLOAD` 또는 `(load "...")`로 최신 LSP를 로드한 뒤 `SWTITLEVERSION`으로 시작한다.
- 2026-07-03 추가 확인:
  - Computer Use로 열린 GstarCAD 작업복사본 창은 감지했다.
  - 화면 좌표로 GMTITLE 선택을 자동화하지 않고, 읽기 전용 `SWTITLEVERSION`만 명령줄/작업면 포커스 방식으로 입력해 보았다.
  - GstarCAD가 해당 입력을 명령으로 받지 않아 화면 로그가 갱신되지 않았다.
  - COM `GetActiveObject("Gcad.Application")`는 Running Object Table에서 활성 객체를 찾지 못했다.
  - COM `New-Object -ComObject ...` 경로는 응답 없이 걸려 중단했다.
  - 결론: CAD 런타임 검증은 현재 자동 조작으로 밀어붙이지 않는다. 사용자가 GstarCAD 명령줄에서 직접 `SCRIPT`로 `work/swtitle_readonly_runtime_check_260703.scr`를 실행하거나 `APPLOAD`로 최신 LSP를 로드하고 `SWTITLEVERSION`을 확인하는 흐름이 더 안전하다.
- 현재 상태는 아직 최종 완료가 아니다.
  - native-like로 인정된 쌍: 2
  - native 재확인/교체가 필요한 A3/A4 쌍: 11
  - 남은 frame-only 원본 시트: 2
  - 누락된 대상 용지: A4

## 사용 순서

작업 복사본 DWG를 열고 LSP를 다시 `APPLOAD`한 뒤:

```text
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT
SWTITLEVERIFY
```

`SWTITLESTATUS`가 아직 A3/A4 native 교체 후보를 표시하면 `SWTITLECONVERT`를 다시 실행한다.

`SWTITLECONVERT`에서 GMTITLE 창이 열릴 때는 반드시 아래 상태를 확인한다.

```text
용지: 로그가 요구한 DR_A*_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

## 완료 기준

- 남은 원본 SolidWorks title/frame 후보가 없다.
- 원본 도면에 있던 A2/A3/A4 크기와 변환된 GMTITLE target frame/title 개수가 맞다.
- A3 도면틀 안에 중복 표제란 형상이 남지 않는다.
- A4 frame-only 시트가 누락되거나 삭제되지 않는다.
- 모든 대표 `DR_titlea_3rd` 더블클릭에서 GMTITLE 표 편집창이 열린다.
- `SWTITLEVERIFY` 결과가 OK이거나, 남은 WARN이 사용자가 확인 가능한 수동 더블클릭 검증만 요구한다.
