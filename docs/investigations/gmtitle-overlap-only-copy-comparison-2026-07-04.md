# GMTITLE overlap-only LSP 복사본 비교 - 2026-07-04

## 목적

현재 source LSP와 overlap-only 비교 복사본을 실제 GstarCAD fixture로 비교했다.

비교 목적은 A3/A4 문제를 단기 명령으로 더 늘리지 않고, `SWTITLESTATUS -> SWTITLEPREPARE -> SWTITLECONVERT -> SWTITLEVERIFY` 흐름 안에서 더 안전한 정규화 기준을 고르는 것이다.

## 비교 대상

### A안: 현재 source main49

```text
src/tools/gmtitle/swcad_title_scale.lsp
version: 260704-plan-frame-prepare-main-49
```

핵심 동작:

```text
swcad-title-frame-embedded-title-records
  source-contaminated
  native-format-with-title-geometry
```

즉 source 오염뿐 아니라 native-format 내부 title-like 형상도 일반 embedded cleanup 후보에 포함한다.

### B안: overlap-only 비교 복사본

```text
work/lsp_compare/swcad_title_scale_overlap_only_compare.lsp
version: 260704-overlap-only-compare
```

핵심 변경:

```text
swcad-title-frame-embedded-title-records
  source-contaminated only
```

native-format 내부 title-like 형상은 일반 cleanup 후보가 아니다.

대신 별도 `DR_titlea_3rd` 제목블록과 실제로 겹칠 때만 `swcad-title-frame-style-normalization-records`가 정규화 후보로 잡는다.

## 테스트 1. 겹침 없는 native 내부 형상

Fixture:

```text
DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 도면틀 정의 안에 title-like 형상만 있음
별도 DR_titlea_3rd 제목블록 없음
```

이 fixture는 설치 원본 A3처럼 도면틀 자체가 native title-like 형상을 가진 경우를 재현한다.

### A안 결과

로그:

```text
work/swtitle_embedded_title_prepare_compare_current_main49_embedded_rerun.txt
```

핵심 결과:

```text
Loaded version: 260704-plan-frame-prepare-main-49
DR_A2_Outline: class=native-format-with-title-geometry, embedded=4
DR_A3_Outline: class=native-format-with-title-geometry, embedded=4
DR_A4_Outline: class=native-format-with-title-geometry, embedded=4
Cleanup records by frame:
  DR_A2_Outline: 4
  DR_A3_Outline: 4
  DR_A4_Outline: 4
Structure next action: SWTITLEPREPARE - 도면틀 정의 안의 표제란 형상을 먼저 정리
Cleanup deleted count: 12
```

판단:

```text
겹치는 제목블록이 없어도 native-format 내부 형상을 삭제한다.
설치 원본 A3 형상을 오염으로 오판할 위험이 있다.
```

### B안 결과

로그:

```text
work/swtitle_embedded_title_prepare_compare_overlap_only_embedded.txt
```

핵심 결과:

```text
Loaded version: 260704-overlap-only-compare
DR_A2_Outline: class=native-format-with-title-geometry, embedded=4
DR_A3_Outline: class=native-format-with-title-geometry, embedded=4
DR_A4_Outline: class=native-format-with-title-geometry, embedded=4
Cleanup records by frame:
  <none>
All embedded title-like records by frame:
  DR_A2_Outline: 4
  DR_A3_Outline: 4
  DR_A4_Outline: 4
Structure next action: SWTITLECONVERT - 남은 원본 SolidWorks 시트 변환
Cleanup deleted count: 0
```

판단:

```text
native-format 내부 형상은 인식하지만 삭제 후보로 올리지 않는다.
사용자가 지적한 "원본 A3 도면틀 형태가 달라지는" 위험을 줄인다.
```

## 테스트 2. 별도 제목블록과 실제 겹치는 native 내부 형상

Fixture:

```text
DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 안에 native title-like 형상 있음
별도 DR_titlea_3rd 제목블록이 같은 위치에 겹쳐 삽입됨
```

이 fixture는 사용자가 본 "표제란이 두 개처럼 보이는" 상황을 재현한다.

### A안 결과

로그:

```text
work/swtitle_style_normalization_compare_current_main49_style_rerun_all.txt
```

핵심 결과:

```text
Loaded version: 260704-plan-frame-prepare-main-49
Style-normalization record count: 3
Style-normalization clean entity count: 12
Style-normalization deleted count: 12
Style-normalization record count after clean: 0
Runtime check completed: yes
```

판단:

```text
겹침 상황을 잡고 정리한다.
```

### B안 결과

로그:

```text
work/swtitle_style_normalization_compare_overlap_only_style_all.txt
```

핵심 결과:

```text
Loaded version: 260704-overlap-only-compare
Style-normalization record count: 3
Style-normalization clean entity count: 12
Style-normalization deleted count: 12
Style-normalization record count after clean: 0
Runtime check completed: yes
```

판단:

```text
B안도 실제 겹침 상황은 정상적으로 잡고 정리한다.
즉 "아무것도 안 지우는 보수안"이 아니라 "겹칠 때만 지우는 조건부 정규화안"이다.
```

## 테스트 3. source-contaminated 도면틀

Fixture:

```text
DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 정의 안에 source-like child block 삽입
```

로그:

```text
work/swtitle_frameclass_common_probe_overlap_only_all_contaminated.txt
```

핵심 결과:

```text
Loaded version: 260704-overlap-only-compare
DR_A2_Outline: class=source-contaminated, embedded=1
DR_A3_Outline: class=source-contaminated, embedded=1
DR_A4_Outline: class=source-contaminated, embedded=2
Blocking frame definitions:
  DR_A2_Outline: 1
  DR_A3_Outline: 1
  DR_A4_Outline: 1
Cleanup records by frame:
  DR_A2_Outline: 1
  DR_A3_Outline: 1
  DR_A4_Outline: 2
Scenario result: PASS
```

판단:

```text
B안은 진짜 source 오염 도면틀을 놓치지 않는다.
```

## 결론

B안, 즉 overlap-only 방식이 더 좋다.

이유:

```text
1. 설치 원본 A3처럼 native-format 내부 형상만 있는 경우는 보존한다.
2. 별도 DR_titlea_3rd와 실제로 겹쳐 표제란이 두 개처럼 보이는 경우는 정리한다.
3. source-contaminated 도면틀은 기존처럼 차단/정리 후보로 잡는다.
4. A3/A4 전용 새 공개 명령을 만들지 않고 기존 4단계 흐름 안에서 해결한다.
```

## source LSP 반영 권장

현재 source main49의 아래 조건을 바꾸는 것이 맞다.

```lisp
(if (member class '("source-contaminated" "native-format-with-title-geometry"))
```

권장 변경:

```lisp
(if (member class '("source-contaminated"))
```

그리고 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY`는 계속 `style-normalization-records`를 통해 실제 overlap 후보를 먼저 안내/차단한다.

