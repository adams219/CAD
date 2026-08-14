# GMTITLE 통합 흐름 계획서 - 2026-07-03

## 목적

SolidWorks에서 저장한 DWG의 도면틀/표제란을 GstarCAD Mechanical의 `GMTITLE` 기반 도면틀/표제란으로 바꾸는 작업을, 임시 명령어를 계속 추가하는 방식이 아니라 반복 가능한 하나의 흐름으로 정리한다.

최종 사용자는 아래 네 단계만 기억하는 것을 목표로 한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

## GitHub / 로컬 이력에서 확인한 기준

이번 계획은 현재 감으로 새로 정한 것이 아니라, GitHub와 로컬 커밋 이력에서 이미 확인된 시행착오를 기준으로 정리한다.

```text
현재 기준 커밋: 0121ae1 Clean up GMTITLE command surface
브랜치: codex/gm-title
원격: origin/main
```

중요한 이력:

- `0121ae1 Clean up GMTITLE command surface`
  - 이미 한 번 사용자에게 보이는 명령어를 줄이는 정리가 있었다.
  - 따라서 새 문제마다 공개 명령어를 계속 추가하지 않는다.

- `f549ac2 Apply GM title transfer with fallback blocks`
  - 과거에는 가짜/fallback 블록 생성 방식이 있었다.
  - 이후 이 방향은 실제 GMTITLE 동작과 다르기 때문에 주력 방식에서 제외되었다.

- `0bb4c9b Document GMTITLE first-native picker limits`
  - 첫 native GMTITLE 선택은 명령행/화면 좌표 자동화로 안정적으로 처리하기 어렵다는 결론이 있었다.
  - 따라서 스크린샷 좌표 클릭이나 드롭다운 위치 의존을 기본 방식으로 쓰지 않는다.

- `b69ff54 Require strict native GMTITLE exemplars`
  - clone처럼 보이는 객체라도 native 기준 객체로 바로 믿으면 안 된다.
  - 같은 용지 크기의 실제 GMTITLE 기준 객체가 있는지 검증해야 한다.

- `5ed90c1 Guard GMTITLE frame definition imports`
  - 도면틀 블록 정의가 오염될 수 있다는 문제가 이미 확인되었다.
  - 변환 전에 도면틀 정의 상태를 검사하고 정리해야 한다.

- `843e453 Verify preserve-copy GMTITLE A4 frame-only`
  - preserve-copy 방식은 빠른 변환에 도움이 되지만, 최종 성공은 더블클릭 시 GMTITLE 표 편집창이 열리는지로 검증해야 한다.

이번 작업의 운영 원칙:

- 새 명령어를 만들거나 변환 로직을 바꾸기 전에 GitHub/로컬 커밋 이력과 `work/*.txt` 최신 로그에서 같은 실패가 이미 있었는지 먼저 확인한다.
- A3, A4, 고아 도면틀 같은 증상별 명령어는 실험용으로만 두고, 최종 사용 흐름은 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 네 단계로 접는다.
- 화면 좌표 클릭, 드롭다운 위치 의존, 가짜/fallback 블록 생성, 검증되지 않은 GMTITLE 복제본 신뢰는 기본 해결책으로 쓰지 않는다.
- 변환 성공 여부는 도면이 비슷하게 보이는지가 아니라 `DR_titlea_3rd`를 더블클릭했을 때 GMTITLE 표 편집창이 열리는지까지 확인한다.

반복 실수 방지 체크:

1. 작업을 이어가기 전에 `git fetch origin --prune`으로 GitHub 이력을 갱신하고, `git log --oneline --decorate --all -12`로 최신 기준 커밋을 확인한다.
2. 수정 전에는 관련 커밋의 의도를 먼저 확인한다. 특히 `0121ae1`, `0bb4c9b`, `b69ff54`, `843e453`의 결론을 우선 적용한다.
3. CAD에서 같은 선택 실수를 반복하지 않도록, `work/*.txt` 최신 로그에서 직전 GMTITLE 선택값과 중단 사유를 먼저 본다.
4. GstarCAD 명령줄 포커스가 불안정할 때는 스크린샷 좌표 입력을 반복하지 않는다. 사용자가 직접 CAD 테스트를 하거나, 신뢰 가능한 스크립트/로그 기반 검증 경로를 먼저 찾는다.
5. 새 공개 명령어를 추가해야 할 것처럼 보이면, 먼저 네 단계 흐름 안에서 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 중 어디에 넣을지 판단한다.

작업 전 이력 게이트:

1. 현재 브랜치와 원격 기준을 먼저 확인한다.
   - `git fetch origin`
   - `git status --short --branch`
   - `git log --oneline --decorate --graph -20`
   - 원격 확인이 권한 문제로 실패하면, 임의로 진행하지 않고 권한을 받아 다시 확인한다.
   - 2026-07-03 확인 기준으로 `origin/main`, `main`, `codex/gm-title`는 모두 `0121ae1 Clean up GMTITLE command surface`를 가리킨다.
2. 실패 원인을 새로 추측하기 전에 아래 로컬 로그를 확인한다.
   - `work/swcad_title_fast_status_last.txt`
   - `work/swcad_title_transfer_apply_last.txt`
   - `work/swcad_title_gmtitle_verify_all_last.txt`
   - `work/swcad_title_native_frame_check_last.txt`
   - `work/swcad_title_structure_diagnosis_last.txt`
3. 같은 증상이 이미 실패로 기록되어 있으면 그 방식은 다시 시도하지 않는다.
   - 화면 좌표 클릭으로 GMTITLE 용지/제목블록을 고르는 방식
   - 일반 A3/A4 또는 ISO 제목블록 기본값을 그대로 확인하는 방식
   - fallback/fake 블록을 만들어 실제 GMTITLE처럼 쓰는 방식
   - clone/preserve-copy를 더블클릭 검증 없이 성공으로 보는 방식
   - A3/A4/frame-only용 공개 명령을 계속 추가하는 방식
4. CAD 테스트가 필요하면 테스트 전에 어떤 로그가 성공 조건인지 정한다. 모양만 보고 판단하지 않고 `SWTITLEVERIFY`와 대표 `DR_titlea_3rd` 더블클릭으로 판단한다.
5. Codex가 CAD를 직접 조작할 때는 먼저 현재 화면이 idle 상태인지, 로드된 LSP가 최신인지, 로그의 `DWG 파일:`이 현재 작업복사본인지 확인한다. 이 세 가지가 확인되지 않으면 `SWTITLECONVERT`나 GMTITLE 선택을 진행하지 않는다.

## 현재 문제의 재정의

최근 문제는 A3, A4 각각을 따로 고치는 작은 문제가 아니다.

실제 문제는 다음 네 가지가 섞인 것이다.

- 첫 native GMTITLE을 만들 때 사용자가 어떤 용지/옵션을 선택해야 하는지 헷갈린다.
- A2/A3/A4 용지 크기마다 같은 크기의 native 기준 객체가 필요하다.
- 일부 A3 도면틀은 `DR_A3_Outline`처럼 보여도 내부에 표제란 형상이 합쳐져 있어, 별도 `DR_titlea_3rd`를 추가하면 표제란이 2개처럼 보인다.
- A4 frame-only 시트는 표제란이 없는 원본이라 일반 title sheet 처리와 다르게 다뤄야 한다.

따라서 해결 방향은 A3 전용 명령, A4 전용 명령, 고아 프레임 정리 명령을 사용자가 직접 골라 쓰게 하는 것이 아니다. 진단/준비/변환/검증 단계 안에서 필요한 조치를 자동으로 판단하게 해야 한다.

## 목표 명령 구조

### 1. `SWTITLESTATUS`

읽기 전용 상태 점검 명령이다.

해야 할 일:

- 현재 도면이 작업 복사본인지 확인한다.
- 남은 원본 표제란 시트 수를 보여준다.
- 남은 frame-only 시트 수를 보여준다.
- A2/A3/A4별 원본 도면틀 수를 보여준다.
- 같은 크기의 native GMTITLE 기준 객체가 있는지 보여준다.
- 도면틀 정의 오염, 중첩 도면틀, 고아 도면틀, 표제란 중복 위험을 보여준다.
- 다음에 실행할 명령을 한국어로 안내한다.

금지할 일:

- 도면 데이터를 변경하지 않는다.
- 사용자가 직접 해석해야 하는 긴 영어 로그만 출력하지 않는다.

### 2. `SWTITLEPREPARE`

변환 전에 위험한 상태를 정리하는 준비 명령이다.

해야 할 일:

- 명령어 텍스트 잔여물 후보를 스캔한다.
- 제목블록 없는 고아 `DR_A*_Outline` 도면틀을 정리한다.
- 도면틀 블록 정의 안에 표제란이 합쳐진 상태를 검사한다.
- 특히 A3 도면틀 정의 안에 표제란 형상이 들어간 경우를 검사한다.
- 실제 삭제가 필요한 경우에는 `YES` 확인을 받는다.

금지할 일:

- 원본 DWG에서 바로 실행하게 유도하지 않는다.
- 삭제 후보가 불확실한 상태에서 도면 내용을 지우지 않는다.
- A3/A4 한 장만 맞추기 위한 임시 명령을 계속 늘리지 않는다.

### 3. `SWTITLECONVERT`

실제 변환 명령이다.

해야 할 일:

- native GMTITLE 기준 객체가 하나도 없으면 첫 시트는 실제 `GMTITLE` 창을 열어 만들도록 안내한다.
- 같은 크기의 기준 객체가 있는 시트는 빠르게 복제/정렬/값 입력/기존 잔여물 삭제를 처리한다.
- 같은 크기의 기준 객체가 없으면 일괄 변환을 멈추고, 어떤 용지를 먼저 실제 GMTITLE로 만들어야 하는지 안내한다.
- A4 frame-only 시트는 title sheet와 다른 경로로 처리한다.

사용자에게 보여줄 핵심 안내:

```text
GMTITLE 창에서:
용지: 로그에 표시된 DR_A2_Outline / DR_A3_Outline / DR_A4_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

금지할 일:

- 좌표를 사람이 소수점까지 직접 입력하게 만들지 않는다.
- 스크린샷 좌표 클릭을 기본 자동화로 쓰지 않는다.
- 같은 크기의 실제 native 기준 객체가 없는 상태에서 clone을 성공으로 간주하지 않는다.

### 4. `SWTITLEVERIFY`

최종 검증 명령이다.

해야 할 일:

- 남은 원본 표제란/도면틀 후보가 있는지 확인한다.
- 원본 도면에 있던 A2/A3/A4 크기와 target frame/title 수를 확인한다.
- 고아 target frame이 있는지 확인한다.
- target frame끼리 겹쳐 선택 위험이 있는지 확인한다.
- 변환된 대표 용지의 표제란을 더블클릭했을 때 GMTITLE 표 편집창이 열려야 한다고 안내한다.

성공 기준:

```text
남은 원본 표제란 후보: 0
남은 원본 도면틀 후보: 0
고아 DR_A*_Outline 도면틀: 0
원본 도면에 있던 A2/A3/A4 크기의 필요한 수량 일치
대표 표제란 더블클릭 시 GMTITLE 표 편집창 열림
```

## A3 도면틀/표제란 중복 문제 처리 방안

A3 문제는 단순히 `DR_A3_Outline`을 다시 넣으면 해결되는 문제가 아니다.

현재 관찰된 핵심은 다음과 같다.

- 원본으로 봐야 하는 A3 도면틀은 도면틀만 있어야 한다.
- 하지만 일부 환경에서는 `DR_A3_Outline` 또는 그 내부 child block에 표제란 형상이 같이 들어온다.
- 이 상태에서 별도의 `DR_titlea_3rd`를 추가하면, 도면상으로 표제란이 2개처럼 보인다.
- 그래서 변환 전 준비 단계에서 도면틀 정의 안에 합쳐진 표제란 형상을 찾아 정리하거나, 오염되지 않은 도면틀 정의로 재가져와야 한다.

계획:

1. `SWTITLESTATUS`에서 A3 도면틀 정의가 표제란 형상을 포함하는지 경고한다.
2. `SWTITLEPREPARE`에서 A3 도면틀 정의 내부의 표제란 형상 후보를 표시한다.
3. 삭제 후보가 명확하면 `YES` 확인 후 정리한다.
4. 후보가 불확실하면 자동 삭제하지 않고, 원본 `DR_A3_Outline.dwg`와 현재 블록 정의를 비교하는 진단 로그를 남긴다.
5. 정리 후 `SWTITLECONVERT`를 실행한다.

## A4 frame-only 처리 방안

A4는 원본에 표제란이 없는 frame-only 시트가 있을 수 있다.

계획:

1. `SWTITLESTATUS`에서 frame-only 수량을 별도로 보여준다.
2. `SWTITLECONVERT`는 일반 title sheet 변환과 frame-only 변환을 분리해서 판단한다.
3. A4의 첫 native 기준 객체가 없으면 `DR_A4_Outline`을 실제 GMTITLE로 한 번 만들도록 안내한다.
4. A4 원본이 표제란 없는 도면틀이면, 기존 표제란 텍스트 입력을 기대하지 않는다.
5. A4 원본 바깥에 붙어 온 객체나 잘못된 raw bbox가 있으면 기존 A4를 지우지 않고 중단한다.

## 작업 복사본 원칙

변환 명령은 원칙적으로 아래 폴더의 복사본에서만 실행한다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

원본 DWG에서 실행하려면 별도 확인이 필요하다. 기본값은 중단이어야 한다.

## 실험용 LSP

현재 원본 LSP는 유지하고, 통합 흐름 테스트용 복사본을 따로 만들었다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_integrated_flow_test.lsp
```

테스트 버전:

```text
260703-integrated-flow-test-3
```

정적 검증:

```text
git diff --check: 통과
괄호 깊이 검사: Depth=0
```

주의:

- 이 파일은 아직 최종 배포본이 아니다.
- 내부에는 기존 세부 명령어가 남아 있다.
- CAD에서 4단계 흐름이 잘 동작하는지 확인한 뒤, 원본 LSP에 반영할지 결정한다.

2026-07-03 추가 구현:

- `SWTITLESTATUS`가 DR 도면틀 정의 안에 합쳐진 표제란 형상 후보를 함께 보여준다.
- `SWTITLEPREPARE`가 A3 전용 정리 대신 A2/A3/A4 공통 내장 표제란 후보 스캔을 사용한다.
- 정리 대상은 용지 크기별 오른쪽/아래 표제란 영역을 기준으로 잡는다.
- `DR_titlea_3rd`, `DR_A*_Outline`, 외곽선, 짧은 좌표 눈금, 1-2글자 좌표 표시는 보호 대상으로 제외한다.
- 실제 삭제는 작업복사본에서만 가능하고, 실행 전 `YES` 확인을 받는다.

CAD 재검증 결과:

- `260703-integrated-flow-test-1`은 A4 좌표 눈금과 `!GENTITLE-*` 표식까지 후보로 잡는 문제가 있었다.
- `260703-integrated-flow-test-2`에서 A4와 `!GENTITLE-*` 오검출을 제거했다.
- `260703-integrated-flow-test-3`에서 아래쪽 좌표 눈금 후보까지 보호하도록 보강했다.
- 최종 `SWTITLEPREPARE` 후보는 10개로 줄었고, 모두 `DR_A3_Outline` 내부 `DR-A3 From_HYUN`의 표제란 텍스트/로고/주요 선 후보였다.
- 확인 프롬프트에서 취소했으므로 이 검증 과정에서는 DWG 데이터를 변경하지 않았다.

## CAD 테스트 순서

1. 작업 복사본 DWG를 연다.
2. 실험용 LSP를 `APPLOAD` 한다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_integrated_flow_test.lsp
```

3. 버전을 확인한다.

```text
SWTITLEVERSION
```

기대 버전:

```text
260703-integrated-flow-test-3
```

4. 상태를 확인한다.

```text
SWTITLESTATUS
```

5. 변환 전 정리를 실행한다.

```text
SWTITLEPREPARE
```

6. 다시 상태를 확인한다.

```text
SWTITLESTATUS
```

7. 변환을 실행한다.

```text
SWTITLECONVERT
```

8. 검증한다.

```text
SWTITLEVERIFY
```

## 완료 기준

통합 흐름을 원본 LSP에 반영하기 전에 아래 조건을 만족해야 한다.

- A2 첫 native GMTITLE 생성 후 흐름이 막히지 않는다.
- A3 첫 native GMTITLE 생성 후 A3 도면틀/표제란 중복이 생기지 않는다.
- A4 frame-only 첫 native GMTITLE 생성 후 나머지 A4가 올바르게 처리된다.
- 빠른 일괄 변환 후 원본 SolidWorks 도면틀/표제란 잔여물이 남지 않는다.
- A2/A3/A4 대표 표제란을 더블클릭하면 GMTITLE 표 편집창이 열린다.
- 사용자는 공개 명령어 4개만 보고도 다음 순서를 이해할 수 있다.

## 반복 실수 방지 규칙

- 새 증상마다 새 공개 명령어를 만들지 않는다.
- 작업 전 GitHub/로컬 이력과 `work` 폴더의 최신 로그에서 비슷한 실패가 있었는지 확인한다.
- screen coordinate 기반 자동화는 마지막 임시 확인 수단으로만 쓴다.
- fallback/fake block 방식으로 돌아가지 않는다.
- clone 결과는 반드시 native-like 검증과 더블클릭 검증을 통과해야 성공으로 본다.
- A3/A4 문제는 용지 하나의 문제가 아니라 frame definition, native exemplar, frame-only 흐름 문제로 분리해서 판단한다.
- 원본 DWG는 직접 수정하지 않고 work 복사본에서 먼저 검증한다.

## 현재 CAD 로그 기준 진행 상태

2026-07-03 현재 실험 LSP `260703-integrated-flow-test-3` 기준으로 확인된 내용:

- `SWTITLESTATUS`는 작업 복사본에서 현재 상태를 읽기 전용으로 진단했다.
- A2 native GMTITLE 기준 객체는 있음.
- A3 native GMTITLE 기준 객체는 있음.
- A4 native GMTITLE 기준 객체는 아직 없음.
- `SWTITLEPREPARE`는 A3 도면틀 정의 내부의 합쳐진 표제란 형상 후보를 49개에서 10개로 줄였다.
- 최종 후보 10개는 모두 `DR_A3_Outline` 내부 child block `DR-A3 From_HYUN`의 표제란 영역 선/문자/로고였다.
- A4 좌표 눈금, `!GENTITLE-*` 마커, 외곽선은 삭제 후보에서 제외되었다.
- 작업 복사본 백업을 만든 뒤 `SWTITLEPREPARE`를 `YES`로 실행해 A3 내부 표제란 형상 10개를 정리했다.
- 이후 `SWTITLEVERIFY`에서 A2/A3 GMTITLE 쌍은 native-like accepted 상태로 확인되었다.
- 아직 남은 원본 SolidWorks 표제란 후보 11개와 원본 도면틀 후보 13개가 있으므로 최종 변환은 끝난 상태가 아니다.
- 다음 핵심은 A4 기준 객체를 안전하게 만들고, `SWTITLECONVERT`로 남은 시트를 처리한 뒤 더블클릭 검증을 마치는 것이다.

## 원본 LSP 반영 상태

실험 복사본에서 확인한 통합 흐름을 원본 LSP에 승격했다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

당시 원본 LSP 버전:

```text
260703-integrated-flow-main-2
```

반영된 내용:

- `SWTITLESTATUS`
- `SWTITLEPREPARE`
- `SWTITLECONVERT`
- `SWTITLEVERIFY`
- A2/A3/A4 공통 도면틀 내부 표제란 형상 검사/정리 로직
- 로드 메시지에서 4단계 통합 명령을 먼저 안내

아직 남은 일:

- 기존 세부 진단/복구용 `c:` 명령 alias가 아직 남아 있으므로, 실제 공개 명령어를 4개로 줄이는 정리는 다음 단계에서 해야 한다.
- A4 native GMTITLE 기준 객체 생성과 최종 CAD 런타임 검증은 아직 끝나지 않았다.
- 남은 원본 SolidWorks 시트 변환은 원본 LSP로 다시 APPLOAD한 뒤 검증해야 한다.

2026-07-03 `main-2` 추가 확인:

- 원본 LSP `260703-integrated-flow-main-1`을 CAD에 로드해 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY`를 실제 실행했다.
- `SWTITLECONVERT`는 남은 A3 표제란 시트를 빠른 변환으로 처리해 원본 표제란 시트를 11개에서 0개로 줄였다.
- 그 결과 A3 target frame은 12개가 되었고, A3/A4 native 교체 후보 12개가 남았다.
- 이때 `SWTITLESTATUS`가 `SWTITLEA3A4ALL`을 직접 안내해 4단계 목표와 충돌하는 문제가 발견되었다.
- `main-2`에서는 해당 안내를 `SWTITLECONVERT`로 되돌렸고, `SWTITLECONVERT`가 A3/A4 native 교체 후보를 내부 단계로 처리하도록 수정했다.
- frame-only A4만 남은 경우도 `SWTITLECONVERT`가 내부적으로 frame-only native 적용 단계로 들어가도록 수정했다.
- 현재 남은 CAD 검증은 `main-2`를 다시 로드한 뒤 `SWTITLECONVERT`가 A3/A4 native 교체 단계에 정상 진입하는지, 이후 A4 frame-only 단계로 이어지는지 확인하는 것이다.

2026-07-03 `main-3` 안전 수정:

- `main-2`는 `SWTITLECONVERT` 안에서 A3/A4 native 교체 단계로 정상 진입했지만, 내부적으로 전체 후보 일괄 처리 경로를 사용했다.
- 실제 CAD 확인 중 GMTITLE 창에서 용지는 `DR_A3_Outline`이었으나 제목블록이 `ISO 제목 블록 A`로 남아 있었다.
- 이 상태에서 확인하면 같은 잘못된 선택이 여러 장에 반복될 위험이 있으므로 창을 취소하고 도면을 보호했다.
- `main-3`에서는 `SWTITLECONVERT`가 A3/A4 native 교체 후보를 한 번에 한 장만 처리하도록 바꿨다.
- `SWTITLESTATUS` 안내도 “전체 후보 처리”가 아니라 “다음 한 장 처리 후 다시 상태 확인”으로 바꿨다.
- 기존 전체 처리 helper는 진단/복구용으로 남기되, 일반 사용 흐름은 계속 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 네 명령만 사용한다.

2026-07-03 `main-3` CAD 재확인:

- CAD에서 `SWTITLEVERSION`으로 `260703-integrated-flow-main-3` 로드를 확인했다.
- `SWTITLESTATUS`는 A3/A4 native 교체 후보 12개를 유지하되, `SWTITLECONVERT`가 다음 한 장만 처리한다고 안내했다.
- `SWTITLECONVERT`를 실행하자 다음 A3 후보 1장에 대해서만 GMTITLE 창이 열렸다.
- GMTITLE 창 기본값은 여전히 일반 `A3 (297x420mm)`, `ISO 제목 블록 A`, `객체 이동 ON`으로 떠서 확인하지 않고 취소했다.
- 로그 결과는 `ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS`였고 기존 GMTITLE 쌍은 보존됐다.
- 결론: 한 장 처리 안전장치는 동작하지만, GMTITLE 창 기본값은 여전히 위험하므로 `DR_A3_Outline`, `DR_titlea_3rd`, `Frame positioning ON`, `Object move OFF`를 확인하기 전에는 OK를 누르지 않는다.

2026-07-03 `main-4` 안전 수정:

- GMTITLE 창 기본값이 일반 A3/ISO 제목블록으로 반복해서 뜨는 문제가 확인되었다.
- 레지스트리와 AppData 설정 검색에서는 바로 사용할 수 있는 `DR_A3_Outline`/`DR_titlea_3rd` 기본값 설정을 찾지 못했다.
- 그래서 `SWTITLECONVERT`가 A3/A4 native 교체용 GMTITLE 창을 바로 열지 않고, 먼저 다음 대상과 주의사항을 보여준 뒤 `OPEN`을 입력해야 창을 열게 했다.
- Enter를 누르면 GMTITLE 창을 열지 않고 중단 로그를 남기며 도면 데이터는 변경하지 않는다.
- 이 변경은 새 사용자 명령을 추가하지 않고, 기존 4단계 흐름 안에서 같은 실수를 반복하지 않기 위한 안전장치다.
- CAD에서 `main-4`를 로드한 뒤 `SWTITLECONVERT`를 실행하고 Enter로 중단하는 경로를 확인했다.
- 결과 로그는 `ABORT_NATIVE_UPGRADE_USER`였고, `OPEN`을 입력하지 않았기 때문에 GMTITLE 창은 열리지 않았으며 도면 데이터도 변경되지 않았다.

2026-07-03 `main-27` 최신 기준:

- 이후 원본 LSP는 `260703-integrated-flow-main-26`까지 갱신됐다.
- 공개 GMTITLE 변환 명령은 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 네 개로 유지한다.
- `SWTITLEPREPARE`는 실수 명령어 텍스트 잔여물, 고아 도면틀, 도면틀 정의 안 중첩 제목블록, DR 도면틀 내부 표제란 형상 정리를 한 흐름 안에서 처리한다.
- `SWTITLEVERIFY`는 내부 검증을 실행한 뒤 통합 최종 요약을 출력하고 `최종 결과: OK/WARN/FAIL`로 정리한다.
- 이 갱신은 GitHub/로컬 이력에서 확인한 실패 방식, 즉 좌표 클릭 자동화, fallback 블록 생성, 검증되지 않은 clone 신뢰, 공개 명령어 난립을 반복하지 않기 위한 정리다.
- `main-26`에서는 결과 코드 설명을 보강했다. 사용자가 `Result:` 코드만 보고 멈추지 않도록, 상태 코드 뒤에 한국어 의미와 다음 판단 기준을 함께 표시한다.
- `main-27`에서는 읽기 전용 `/b` 런타임 확인이 일반 작업 로그를 덮어쓰지 않도록 상세 로그 접미사 옵션을 추가했다.

2026-07-03 `main-28` 최신 기준:

- 공개 흐름 중 사용자에게 직접 보일 수 있던 남은 영어 안내 문장을 한국어로 정리했다.
- 변환 로직은 바꾸지 않고, 상태/교체/대화식 GMTITLE 안내 문구만 정리했다.
- 현재 기준 버전은 `260703-integrated-flow-main-28`이다.
- `/b` 읽기 전용 런타임 확인에서 `main-28` 로드와 `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY` 실행을 확인했다.
- 테스트 DWG는 변환 전 저장본이라 `SWTITLEVERIFY_FINAL_FAIL`이 정상이며, 실제 변환 완료 검증은 아직 남아 있다.

2026-07-03 `main-29` 최신 기준:

- `main-28` 런타임 로그에서 보인 잔여 영어/부분 번역 문구를 번역 테이블에 추가했다.
- 현재 기준 버전은 `260703-integrated-flow-main-29`이다.
- `/b` 읽기 전용 런타임 확인에서 `main-29` 로드와 `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY` 실행을 확인했다.
- 테스트 DWG는 변환 전 저장본이라 `SWTITLEVERIFY_FINAL_FAIL`이 정상이며, 실제 변환 완료 검증은 아직 남아 있다.

2026-07-03 `main-30` 최신 기준:

- `main-29` 런타임 로그에서 보인 도면틀 정의 진단의 잔여 영어/부분 번역 문구를 번역 테이블에 추가했다.
- 이후 최신 기준은 `main-33`까지 진행됐고, `main-33`의 CAD 런타임 로드 확인은 완료됐다. 실제 변환 완료 검증은 아직 남아 있다.

2026-07-03 `main-31` 최신 기준:

- 부분 번역 순서 때문에 남던 `존재: no/yes` 조각을 번역 테이블에 추가했다.
- 이후 `main-32`에서 `SWTITLESTATUS` 구조 판단 요약과 A3/A4 판단 안내를 추가했다.
- 이후 `main-33`에서 구조 판단 요약도 별도 로그로 남기도록 했다.
- 이후 `main-34`에서 4단계 흐름 중 사용자에게 직접 보일 수 있는 잔여 영어 안내를 번역 테이블에 추가했다.
- 현재 기준 버전은 `260703-integrated-flow-main-42`이다.
- `/b` 읽기 전용 런타임 확인에서 `main-34` 로드와 `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY` 실행을 확인했다.
- 이후 `main-35` 전용 기준선 복사본에서도 `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-35`로 기록됐다.
- 이후 `main-36` 저장본 읽기 전용 검증에서도 `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-36`으로 기록됐다.
- 이후 `main-37` 읽기 전용 검증에서도 `Loaded version`과 `Expected version`이 모두 `260703-integrated-flow-main-37`로 기록됐다.
- 구조 판단 요약 로그 `work/swcad_title_structure_diagnosis_last_runtime_260703.txt` 생성도 확인했다.
- 실제 변환 완료 검증은 아직 남아 있다.

## 다음 결정

원본 LSP 승격 후 다음 순서:

1. CAD에서 원본 LSP를 다시 `APPLOAD`한다.
2. `SWTITLEVERSION`으로 `260703-integrated-flow-main-42`가 로드됐는지 확인한다.
3. 작업 복사본에서 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 순서로 검증한다.
4. A4 native GMTITLE 기준 객체가 없는 경우, `SWTITLECONVERT`가 어디서 멈추는지 로그로 확인하고 같은 크기 기준 객체를 안전하게 만든다.
5. 변환된 대표 용지의 `DR_titlea_3rd`를 더블클릭해 GMTITLE 표 편집창이 열리는지 확인한다.
6. CAD 검증이 통과하면 기존 세부 진단/정리 명령 alias를 공개 명령에서 내리는 정리를 진행한다.
7. `docs/guide/commands.md`와 사용법 문서를 4단계 기준으로 갱신한다.
8. 커밋 후 GitHub에 푸시한다.

CAD 테스트에서 실패하면:

1. 실패한 단계가 `STATUS`, `PREPARE`, `CONVERT`, `VERIFY` 중 어디인지 먼저 분류한다.
2. GitHub/로컬 이력과 `work/*.txt` 로그에서 같은 실패를 먼저 찾는다.
3. 해당 단계 내부 로직을 고친다.
4. 새 공개 명령어를 추가하지 않는다.
