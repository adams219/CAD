# GMTITLE main47 A3 도면틀 스타일 정규화 기록 - 2026-07-04

## 목적

SolidWorks DWG를 GstarCAD GMTITLE 구조로 바꿀 때, `DR_A3_Outline` 도면틀 안에 표제란 형상이 함께 들어와 별도 `DR_titlea_3rd` 제목블록과 겹치는 문제를 구조적으로 처리한다.

이번 작업은 새 공개 명령어를 늘리는 것이 아니라, 기존 4단계 흐름 안에 넣는다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

## 참고한 이력

- `0121ae1 Clean up GMTITLE command surface`
  - 공개 명령어를 줄이고 4단계 흐름으로 정리한 기준이다.
- `0bb4c9b Document GMTITLE first-native picker limits`
  - GMTITLE 용지/제목블록 선택은 화면 좌표나 명령줄 자동 선택으로 안정화하지 않는다.
- `b69ff54 Require strict native GMTITLE exemplars`
  - native GMTITLE처럼 보이는 복사본과 실제 native 동작은 구분해야 한다.
- `5ed90c1 Guard GMTITLE frame definition imports`
  - `DR_A*_Outline` 블록 정의가 오염되었는지 검사한 뒤 처리해야 한다.
- `843e453 Verify preserve-copy GMTITLE A4 frame-only`
  - A4 frame-only는 별도 표제란 없는 도면틀 흐름을 유지해야 한다.

## 반복하지 않을 실수

- GMTITLE 창을 스크린샷 좌표 클릭으로 자동화하지 않는다.
- `DR_A3_Outline`을 무조건 source-contaminated로 판단해 삭제하지 않는다.
- A3/A4 전용 공개 명령어를 계속 추가하지 않는다.
- GstarCAD가 막는 블록 정의 내부 엔티티 직접 삭제에 계속 매달리지 않는다.
- 실제 원본 DWG나 설치 폴더 DWG는 수정하지 않고, `work` 작업복사본에서만 변경한다.

## 원인 분리

`DR_A3_Outline` 문제는 두 축으로 나눠야 한다.

```text
source class:
  outline-only
  native-format-with-title-geometry
  source-contaminated
  unknown

style class:
  style-ok
  style-normalization-needed
  style-review-needed
```

이번 A3 문제는 source-contaminated가 아니라, `native-format-with-title-geometry` 도면틀이 별도 `DR_titlea_3rd`와 겹치는 style-normalization-needed 문제다.

## main47 구현 방향

`SWTITLESTATUS`:

- 별도 `DR_titlea_3rd`와 도면틀 내부 title-like 형상이 겹치면 `NEXT_PREPARE_FRAME_STYLE_NORMALIZATION`으로 안내한다.

`SWTITLEPREPARE`:

- 작업복사본에서만 실행한다.
- 기존 `DR_A3_Outline` 블록 정의를 백업 이름으로 보관한다.
- 같은 이름의 새 `DR_A3_Outline` 정의를 만들고, 겹치는 표제란 형상만 빼고 나머지 요소를 복사한다.
- 기존 frame INSERT는 같은 `DR_A3_Outline` 이름을 계속 보게 한다.

`SWTITLECONVERT`:

- style-normalization-needed 후보가 남아 있으면 변환을 중단하고 `SWTITLEPREPARE`를 먼저 안내한다.

`SWTITLEVERIFY`:

- style-normalization-needed 후보가 남아 있으면 최종 OK가 아니라 WARN/FAIL 상태로 남긴다.

## 검증 결과

합성 A3 fixture에서 기존 직접 삭제 방식은 실패했다.

```text
Direct vla-Delete first clean record: ERROR
```

main47 재구성 방식은 같은 fixture에서 성공했다.

```text
Style-normalization record count: 1
Style-normalization clean entity count: 4
Style-normalization deleted count: 4
Style-normalization record count after clean: 0
```

A2/A3/A4 공통 fixture에서도 같은 방식이 동작했다.

```text
Style-normalization record count: 3
Style-normalization clean entity count: 12
Style-normalization deleted count: 12
Style-normalization record count after clean: 0
```

기존 회귀 검증도 통과했다.

```text
run_main45_verification_suite.ps1
All expected log markers were verified.
GMTITLE main45 verification suite complete
```

A2/A3/A4 style-normalization rebuild cleanup probe를 suite 5단계에 넣은 뒤에도 전체 suite가 다시 통과했다.

```text
Verified log: A2/A3/A4 style-normalization rebuild cleanup probe
All expected log markers were verified.
GMTITLE main45 verification suite complete
```

## 남은 실제 CAD 검증

합성 fixture와 읽기 전용 회귀 검증은 통과했지만, 실제 도면 변환 완료는 아직 별도 확인이 필요하다.

실제 작업복사본에서 다음 순서로 확인한다.

```text
APPLOAD swcad_load.lsp
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE
SWTITLESTATUS
SWTITLECONVERT
SWTITLEVERIFY
```

최종 완료 기준은 다음과 같다.

```text
SWTITLEVERIFY_FINAL_OK
대표 A2/A3/A4 제목블록 더블클릭 시 GMTITLE 표 편집창 열림
A3 도면틀 내부 표제란 중복 없음
A4 frame-only 누락 없음
```
