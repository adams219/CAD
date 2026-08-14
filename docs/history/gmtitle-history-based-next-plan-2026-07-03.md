# GMTITLE 이력 기반 다음 계획 - 2026-07-03

이 문서는 GitHub 원격 이력, 로컬 커밋 이력, `work` 로그를 먼저 확인한 뒤 같은 실수를 반복하지 않기 위한 다음 작업 계획이다.

## 현재 기준

원격 확인:

```text
origin: https://github.com/adams219/CAD.git
origin/main: 0121ae1 Clean up GMTITLE command surface
현재 브랜치: codex/gm-title
```

현재 로컬 작업 기준:

```text
LSP: src/tools/gmtitle/swcad_title_scale.lsp
현재 작업 버전: 260703-integrated-flow-main-35
공개 GMTITLE 명령: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERT, SWTITLEVERIFY
```

아직 부족한 증거:

```text
work/swtitle_runtime_loaded_last.txt
```

이 파일은 생성됐다. `main-26` 기준으로 실제 GstarCAD 로드와 읽기 전용 실행은 증명됐고, 이후 `main-27`에서 런타임 상세 로그 접미사 분리까지 보강했다.

## 이력에서 확정된 금지 사항

아래 결론은 새로 추측한 것이 아니라 기존 GitHub/로컬 커밋 이력에서 확인된 시행착오다.

- `f549ac2 Apply GM title transfer with fallback blocks`
  - 가짜/fallback 블록 생성은 실제 GMTITLE 동작과 다르다.
  - 다시 기본 방식으로 사용하지 않는다.

- `0bb4c9b Document GMTITLE first-native picker limits`
  - GMTITLE 창 선택은 명령행/좌표 클릭만으로 안정 자동화하기 어렵다.
  - 스크린샷 좌표, 드롭다운 위치 의존을 기본 방식으로 쓰지 않는다.

- `b69ff54 Require strict native GMTITLE exemplars`
  - 복사된 xdata, marker, 비슷한 블록명만으로 native GMTITLE이라고 믿으면 안 된다.
  - 같은 용지 크기의 실제 native 기준 객체가 필요하다.

- `843e453 Verify preserve-copy GMTITLE A4 frame-only`
  - preserve-copy는 빠른 처리에는 도움이 됐지만, 더블클릭 GMTITLE 표 편집창까지 보장하지 않는다.
  - 최종 성공은 대표 제목블록 더블클릭 확인까지 포함한다.

- `0121ae1 Clean up GMTITLE command surface`
  - 사용자에게 보이는 명령어를 계속 늘리면 흐름이 무너진다.
  - 새 공개 명령어를 추가하지 않고 4단계 안으로 넣는다.

## 현재 로그에서 본 실제 문제

최근 `work` 로그 기준으로 현재 상태는 다음과 같다.

```text
원본 표제란 시트: 0
원본 도면틀 후보: 2
frame-only 시트: 2
남은 원본 도면틀 크기: A4 2장
DR_A2_Outline native 기준 객체: 있음
DR_A3_Outline native 기준 객체: 있음
DR_A4_Outline native 기준 객체: 없음
```

A3 관련 로그에서는 다음 문제가 보인다.

```text
DR_A3_Outline target frame: 12개
DR_titlea_3rd title: 13개
native-like accepted pair: A2 1개, A3 1개
clone/shared-native-link 계열 A3 pair: 다수
```

따라서 A3는 "도면이 보이는지"가 아니라 "복제된 쌍이 실제 native GMTITLE처럼 더블클릭 표 편집창으로 열리는지"가 핵심이다.

A4는 원본에 표제란이 없는 frame-only 시트이므로 A3 title sheet와 같은 방식으로 처리하면 안 된다.

## 반복된 실수의 원인

1. 화면에 도면틀/표제란이 보이면 성공으로 착각했다.
2. clone/preserve-copy 결과를 native GMTITLE과 같은 것으로 착각했다.
3. A3의 도면틀 내부 표제란 문제와 A4 frame-only 문제를 섞어서 판단했다.
4. CAD에 로드된 LSP 버전이 최신인지 확인하지 않고 로그를 해석했다.
5. 문제마다 새 보조 명령을 만들면서 사용 순서가 복잡해졌다.
6. GMTITLE 창 기본값이 일반 A3/ISO 제목블록으로 뜨는 위험을 과소평가했다.

## 앞으로의 작업 원칙

작업 시작 전에는 항상 다음 순서로 확인한다.

```text
1. git fetch origin --prune
2. git log --oneline --decorate --all -25
3. docs/history 최신 계획과 감사 문서 확인
4. work/swtitle_*_last.txt 최신 로그 확인
5. CAD에서 SWTITLEVERSION 확인
6. 작업복사본 DWG인지 확인
```

CAD 판단 기준:

- `SWTITLEVERSION`이 기대 버전이 아니면 어떤 결과도 최종 판단에 쓰지 않는다.
- `DR_A*_Outline`이 INSERT/block으로 잡히는 것 자체는 정상일 수 있다.
- GMTITLE 기능 성공 여부는 paired `DR_titlea_3rd` 제목블록 더블클릭으로 판단한다.
- clone/shared-native-link는 임시 상태다. 최종 native-like accepted pair가 아니다.
- A3 문제를 A4 문제로 바꿔 해석하지 않는다.

## 다음 해결 방향

### 1. 런타임 기준 고정

먼저 최신 원본 LSP가 CAD에서 실제로 로드되는지 증명한다.

실행할 것:

```text
SCRIPT
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_readonly_runtime_check_260703.scr
```

기대 산출물:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_runtime_loaded_last.txt
```

기대 내용:

```text
Load result: OK
Loaded version: 260703-integrated-flow-main-26
Runtime check completed: yes
```

이 증거가 없으면 다음 수정에 들어가지 않는다.

### 2. A3를 구조 문제로 다시 검증

A3는 한 장의 배치 실수가 아니라 두 가지를 나눠 본다.

- `DR_A3_Outline` 정의 안에 표제란 형상이 섞였는지
- A3 target pair가 clone/shared-native-link인지, 실제 native-like accepted pair인지

진행:

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLESTATUS
SWTITLEVERIFY
```

판단:

- 도면틀 정의 안 표제란 후보가 있으면 `SWTITLEPREPARE`로 먼저 정리한다.
- 정리 뒤에도 A3 pair가 clone/shared-native-link이면 `SWTITLECONVERT`로 한 장씩 native 교체한다.
- 한 장 처리 후 반드시 `SWTITLESTATUS`로 남은 수를 다시 본다.

### 3. A4는 frame-only 전용 흐름으로 처리

A4는 원본에 표제란이 없는 도면틀만 있는 시트다.

진행:

```text
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
```

`SWTITLECONVERT`가 GMTITLE 창을 열면 반드시 확인한다.

```text
용지: DR_A4_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

일반 A4, ISO 제목블록, Object move ON이면 확인하지 않고 취소한다.

A4는 원본 표제란 텍스트가 없으므로, 값 입력 실패를 title sheet 실패로 해석하지 않는다. 대신 frame-only 시트가 삭제되지 않고 `DR_A4_Outline` 기준 객체로 안전하게 바뀌었는지를 본다.

### 4. 변환 완료 판정

최종 검증은 `SWTITLEVERIFY` 하나로 판단한다.

완료 기준:

```text
원본 표제란 후보: 0
원본 도면틀 후보: 0
고아 DR_A*_Outline: 0
필요한 A2/A3/A4 target frame/title 수량 일치
clone/shared-native-link 경고 없음
내장 표제란 형상 경고 없음
대표 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
```

모양만 맞는 것은 완료가 아니다.

## 명령어 운영 원칙

사용자가 기억할 명령은 계속 네 개만 둔다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

내부적으로 필요하면 기존 helper를 호출하되, 새 공개 명령어를 늘리지 않는다.

## 다음 실제 작업 순서

1. `work/swtitle_readonly_runtime_check_260703.scr`로 최신 런타임 증거를 만든다.
2. `SWTITLESTATUS` 결과를 최신 로그 기준으로 다시 읽는다.
3. A3에 내장 표제란/clone/shared-native-link가 남아 있으면 A3부터 정리한다.
4. A3가 native-like accepted 상태가 된 뒤 A4 frame-only를 처리한다.
5. `SWTITLEVERIFY`가 OK 또는 수동 더블클릭만 남긴 WARN이 될 때까지 반복한다.
6. CAD 로그와 문서가 맞으면 커밋/푸시한다.

## 2026-07-03 추가 자동 조작 확인

Computer Use로 현재 GstarCAD 창은 안정적으로 식별했다.

```text
GstarCAD Mechanical 2024 - [0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg]
```

확인한 사실:

- 열린 도면은 `Documents\CAD tool\work` 아래 작업복사본이다.
- 화면에는 `SWTITLECONVERT`의 A3/A4 native 교체 안내가 남아 있다.
- 다음 후보는 A3 `title=16E62`, `frame=16E61`, `block=DR_A3_Outline`, `reason=복제`로 보인다.
- 남은 상태는 A3/A4 native 더블클릭 검증/교체 후보 11개다.

시도했지만 중단한 것:

- `SWTITLEVERSION`을 한 글자씩 입력해 보았으나 명령줄 로그가 갱신되지 않았다.
- `type_text`로도 `SWTITLEVERSION`을 입력해 보았으나 화면 로그가 갱신되지 않았다.
- 따라서 이 상태에서 `SWTITLECONVERT` 같은 변경 명령을 자동 입력하면 같은 실수를 반복할 위험이 있다.

COM 확인:

- 레지스트리에는 `Gcad.Application`, `Gcad.Application.24`, `GStarCAD.Application`, `GStarCAD.Application.24` ProgID가 있다.
- 실행 프로세스는 `gcad.exe`다.
- 하지만 현재 실행 중인 GstarCAD는 `GetActiveObject`로 붙지 않았다.

```text
Gcad.Application: FAIL
Gcad.Application.24: FAIL
GStarCAD.Application: FAIL
GStarCAD.Application.24: FAIL
```

판단:

- 지금 상태에서는 Computer Use 좌표/텍스트 입력이나 COM 자동화를 검증 경로로 삼지 않는다.
- 다음 런타임 증거는 사용자가 GstarCAD 명령줄에서 직접 `SCRIPT`를 실행해 만드는 방식이 가장 안전하다.
- 자동 조작을 다시 시도하려면 먼저 `SWTITLEVERSION` 같은 읽기 전용 명령이 화면 로그에 확실히 찍히는지 증명해야 한다.

## 2026-07-03 `/b` 스크립트 런타임 확인

명령줄 포커스 자동입력은 실패했지만, GstarCAD 실행 파일의 배치 스크립트 방식은 성공했다.

사용한 방식:

```text
gcad.exe "...\work\swtitle_runtime_check_260703_workcopy.dwg" /b "...\work\swtitle_readonly_runtime_check_260703.scr"
```

안전을 위해 현재 열려 있던 DWG를 직접 쓰지 않고 별도 복사본을 만들었다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_runtime_check_260703_workcopy.dwg
```

생성된 런타임 증거:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_runtime_loaded_last.txt
```

핵심 결과:

```text
Load result: OK
Loaded version: 260703-integrated-flow-main-26
Expected version: 260703-integrated-flow-main-26
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

해석:

- 최신 원본 LSP `main-26`은 실제 GstarCAD 런타임에서 로드됐다.
- `SWTITLESTATUS`, `SWTITLEVERIFY`도 오류 없이 실행됐다.
- 테스트 DWG는 디스크에 저장된 workcopy를 복사한 것이며, 이 저장본은 변환 전 상태였다.
- 그래서 원본 표제란 13장, 원본 도면틀 15개, GMTITLE target frame/title 0개로 진단됐고 `SWTITLEVERIFY_FINAL_FAIL`이 나왔다.
- 이 실패는 LSP 실행 실패가 아니라 "아직 첫 native GMTITLE 기준 객체가 없는 도면"이라는 정확한 진단이다.

중요한 주의:

- 현재 CAD 화면의 도면과 디스크에 저장된 `workcopy_03.dwg`가 다를 수 있다.
- 화면에서 진행했던 변환이 저장되지 않았다면 `/b` 스크립트 검증은 저장 전 화면 상태를 반영하지 않는다.
- 실제 변환 완료 검증은 저장된 작업복사본 또는 새 테스트 복사본에서 다시 실행해야 한다.

이번 테스트 후 추가로 열린 `swtitle_runtime_check_260703_workcopy.dwg` GstarCAD 창은 닫았다. 원래 열려 있던 `0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg` 창은 유지했다.

`main-27` 추가 보강:

- 런타임 확인 스크립트가 일반 `swcad_title_*_last.txt` 로그를 덮어쓰지 않도록, LSP에 `*swcad-title-log-file-suffix*` 옵션을 추가했다.
- `/b` 런타임 확인 중에는 상세 로그가 `_runtime_260703` 접미사 파일로 생성된다.
- 현재 기준 버전은 `260703-integrated-flow-main-27`이다.
- `/b` 재검증 결과 `Loaded version`과 `Expected version` 모두 `260703-integrated-flow-main-27`로 확인됐다.

`main-28` 추가 보강:

- 공개 흐름 중 남아 있던 영어 안내 문장을 한국어로 정리했다.
- `/b` 읽기 전용 런타임 확인에서 `Loaded version`과 `Expected version` 모두 `260703-integrated-flow-main-28`로 확인됐다.
- 실제 변환 완료 검증은 아직 필요하다.

`main-29` 추가 보강:

- `main-28` 런타임 로그에서 확인된 잔여 영어/부분 번역 문구를 한국어로 더 정리했다.
- `/b` 읽기 전용 런타임 확인에서 `Loaded version`과 `Expected version` 모두 `260703-integrated-flow-main-29`로 확인됐다.
- 실제 변환 완료 검증은 아직 필요하다.

`main-30` 추가 보강:

- 도면틀 정의 진단 로그에 남던 영어/부분 번역 문구를 한국어로 더 정리했다.
- 이후 최신 기준은 `main-33`까지 진행됐고, `main-33`의 CAD 런타임 로드 확인은 완료됐다. 실제 변환 완료 검증은 아직 필요하다.

`main-31` 추가 보강:

- 부분 번역 순서 때문에 남던 `존재: no/yes` 조각을 정리했다.
- 상세 로그도 `swcad_title_*_last_runtime_260703.txt` 형태로 분리 생성됐다.

`main-32`/`main-33` 추가 보강:

- `SWTITLESTATUS`에 구조 판단 요약을 추가했다.
- A3 도면틀 내부 표제란 후보, A4 실제 선택 bbox 경고, 권장 다음 명령을 한곳에서 볼 수 있게 했다.
- `main-33`에서 구조 판단 요약도 `work/swcad_title_structure_diagnosis_last.txt` 로그로 남기도록 했다.
- `/b` 읽기 전용 런타임 확인에서 `main-33` 로드와 구조 판단 로그 생성을 확인했다.
- 아직 실제 변환 완료 검증은 필요하다.
