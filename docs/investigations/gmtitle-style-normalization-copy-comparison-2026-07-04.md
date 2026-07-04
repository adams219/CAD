# GMTITLE A3 style-normalization LSP 복사본 비교 - 2026-07-04

## 목적

원본 LSP를 바로 수정하지 않고 복사본을 만들어, A3 도면틀 내부 native 표제란 형상과 별도 `DR_titlea_3rd` 제목블록이 겹치는 상황을 current main45와 비교했다.

비교 기준은 아래 계획이다.

```text
docs/history/gmtitle-a3-frame-style-normalization-plan-2026-07-04.md
```

## 비교 대상

Current main45:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
Version: 260704-frame-definition-classification-main-45
SHA256: BB80F09CFDE8C083231D1106CEAF8C2A6DD83F40F8D8A59D30B295C5FD7A8AF8
```

Style-normalization 비교 복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_style_normalization_test.lsp
Version: 260704-style-normalization-compare
SHA256: A665D372124DA007C1EA5B87F4E2AE97B5C064C37DE60724E1F4BAAD212146FB
```

복사본은 원본 LSP에서 시작했고, 다음 실험 기능만 추가했다.

```text
swcad-title-frame-style-normalization-records
swcad-title-print-frame-style-normalization-records
SWTITLESTATUS next-step gate: NEXT_PREPARE_FRAME_STYLE_NORMALIZATION
SWTITLECONVERT gate: ABORT_FRAME_STYLE_NOT_NORMALIZED
SWTITLEVERIFY warning count: 도면틀 스타일 정규화 필요 후보
```

## 테스트 fixture

읽기 전용 probe가 작업복사본 DWG를 복사한 뒤 저장하지 않는 fixture를 만들었다.

Fixture 내용:

```text
DR_A3_Outline 블록 정의 생성
  - A3 외곽선
  - 오른쪽 아래 native-format title-like 선/문자

DR_titlea_3rd 블록 정의 생성
  - 간단한 제목블록 bbox

Model space에 둘 다 INSERT
  - DR_A3_Outline at (0, 0)
  - DR_titlea_3rd at (230, 10)
```

이 조건은 사용자가 보고한 문제를 축소 재현한다.

```text
DR_A3_Outline은 source-contaminated가 아님
하지만 별도 DR_titlea_3rd와 겹쳐 표제란이 두 개처럼 보일 수 있음
```

## 실행한 probe

Probe 파일:

```text
diagnostics/gmtitle-main45/style_normalization_compare_probe.lsp
diagnostics/gmtitle-main45/run_style_normalization_compare_probe.ps1
```

Current main45 실행:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "diagnostics\gmtitle-main45\run_style_normalization_compare_probe.ps1" -LspPath "src\tools\gmtitle\swcad_title_scale.lsp" -Label "current_main45_stylecmp" -TimeoutSeconds 90
```

복사본 실행:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "diagnostics\gmtitle-main45\run_style_normalization_compare_probe.ps1" -LspPath "work\lsp_compare\swcad_title_scale_style_normalization_test.lsp" -Label "style_normalization_variant" -TimeoutSeconds 90
```

## 로그

Current main45:

```text
work\swtitle_style_normalization_compare_current_main45_stylecmp.txt
```

핵심 결과:

```text
Loaded version: 260704-frame-definition-classification-main-45
DR_A3_Outline: class=native-format-with-title-geometry, embedded=4, source-like=<none>
Style function present: no
Style-normalization record count: <unavailable>
Status after SWTITLESTATUS: NEXT_UPGRADE_A3_A4_NATIVE
Runtime check completed: yes
```

판단:

```text
current main45는 A3를 source-contaminated로 오판하지는 않는다.
하지만 별도 DR_titlea_3rd와 겹쳐 표제란이 두 개처럼 보이는 style 문제를 별도 gate로 올리지 못한다.
결과적으로 다음 단계가 A3/A4 native 교체로 남아 있어, 사용자가 SWTITLECONVERT를 계속 누를 가능성이 있다.
```

Style-normalization 비교 복사본:

```text
work\swtitle_style_normalization_compare_style_normalization_variant.txt
```

핵심 결과:

```text
Loaded version: 260704-style-normalization-compare
DR_A3_Outline: class=native-format-with-title-geometry, embedded=4, source-like=<none>
Style function present: yes
Style-normalization result: OK
Style-normalization record count: 1
  style-record frame=DR_A3_Outline, frame-handle=16904, title-handle=16905, overlap=(230, 10) - (410, 52)
Status after SWTITLESTATUS: NEXT_PREPARE_FRAME_STYLE_NORMALIZATION
Runtime check completed: yes
```

판단:

```text
복사본은 source 오염과 style 문제를 분리해서 본다.
A3가 source-contaminated는 아니지만, 별도 DR_titlea_3rd와 겹치면 SWTITLEPREPARE를 먼저 안내한다.
따라서 중복 표제란 모양이 여러 장으로 복제되기 전에 멈출 수 있다.
```

## 비교 결론

현재 요구사항에는 style-normalization 비교 복사본 방향이 더 맞다.

이유:

```text
1. main45의 native/source 구분은 유지한다.
2. A3 native 내장 형상을 무조건 삭제하지 않는다.
3. 별도 DR_titlea_3rd와 실제로 겹칠 때만 style-normalization-needed로 올린다.
4. SWTITLESTATUS가 다음 명령을 SWTITLEPREPARE로 바꿔 중복 복제를 막는다.
5. A3 전용 공개 명령을 만들지 않고 4단계 흐름 안에서 처리한다.
```

단, 복사본은 아직 실제 정규화 삭제/보정까지 구현한 최종본은 아니다.

현재 복사본에서 검증된 범위:

```text
감지: OK
다음 단계 gate: OK
SWTITLECONVERT 차단 gate: 구현됨
SWTITLEVERIFY warning count: 구현됨
실제 A3 도면틀 정의 정규화 실행: 아직 미구현
실제 CAD 화면에서 표제란 중복 제거: 아직 미검증
```

## 다음 구현 권장

1. 복사본의 style-normalization 감지/gate 로직을 원본 LSP에 반영한다.
2. `SWTITLEPREPARE`에 실제 정규화 실행을 추가하되, source 오염 삭제와 구분해서 `NORMALIZE`로 표시한다.
3. 정규화 대상은 작업복사본 안의 `DR_A3_Outline` 블록 정의 내부 오른쪽 아래 static title-like 형상으로 제한한다.
4. 도면 내부 번호, 주석, 치수, BOM, 모델 형상, 외곽선, 눈금, 좌표 문자는 보호한다.
5. 실제 작업복사본에서 `SWTITLESTATUS -> SWTITLEPREPARE -> SWTITLESTATUS`로 style 후보가 0이 되는지 검증한다.
6. 그 뒤에만 `SWTITLECONVERT`를 계속한다.
