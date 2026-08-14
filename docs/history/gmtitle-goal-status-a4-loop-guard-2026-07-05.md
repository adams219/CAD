# GMTITLE Goal Status A4 Loop Guard - 2026-07-05

## 목적

A4 frame-only 단계에서 `SWTITLEPREPARE`와 `SWTITLECONVERT`를 반복 입력하는 흐름을 막기 위해 목표모드 상태판을 보강했다.

이 변경은 A4 변환을 직접 완료하는 변경이 아니다. 현재 열린 CAD 작업복사본의 다음 상태가 아래처럼 유지될 때, 같은 CAD 명령을 반복하지 않고 copied-DWG probe로 넘어가게 만드는 안전장치다.

```text
NEXT_PREPARE_A4_FRAME_ONLY_OUTLINE_DEFINITION
A4: 필요 2, 현재 0
DR_A4_Outline 정의 상태: 없음
prepare probe: WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE
nested-outside: not-run
nested-direct-outside: not-run
```

## 문제

설치 원본 `DR_A4_Outline`은 화면상 A4로 보이는 effective bbox는 맞지만, CAD가 실제 선택하는 raw bbox가 너무 크다.

```text
effective bbox: (0, 0) - (210, 297)
raw bbox: (0, 0) - (872.26126377, 302.7)
raw/effective area ratio: 4.2333411
```

이 상태에서 변환을 계속 밀어붙이면 아래 위험이 있다.

```text
기존 A4 frame-only 원본 도면틀 삭제
원본에 없던 DR_titlea_3rd 제목블록 생성
틀 밖 객체가 딸려온 A4 target 생성
probe/suite 로그를 실제 작업 DWG 로그로 착각
```

따라서 같은 `SWTITLEPREPARE` 또는 `SWTITLECONVERT`를 반복하는 것은 목표에 맞지 않는다.

## 변경한 파일

```text
diagnostics/gmtitle-main45/run_goal_status.ps1
diagnostics/gmtitle-main45/run_static_preflight.ps1
docs/guide/gmtitle-current-run-card.md
docs/guide/gmtitle-goal-mode-plan.md
```

## 상태판 분기

`run_goal_status.ps1`는 이제 A4 frame-only 병목을 세 가지로 나눠 안내한다.

### 1. nested probe 미실행

조건:

```text
prepare probe = WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE
nested-outside = not-run
nested-direct-outside = not-run
```

안내:

```text
SWTITLEPREPARE/SWTITLECONVERT 반복 금지
작업복사본 저장
GstarCAD 종료
copied-DWG nested A4 probe 실행
```

실행 명령:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_outline_normalization_probe.ps1 -SourceWorkCopyPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125 CP_ALL_260704_test.dwg" -Strategies nested-outside,nested-direct-outside
```

### 2. nested probe safe=yes 후보 있음

조건:

```text
nested-outside = yes
또는
nested-direct-outside = yes
```

안내:

```text
바로 CAD 변환을 반복하지 않음
copied-DWG 로그를 먼저 검토
A4 frame이 보존되고 raw/effective bbox가 모두 맞는지 확인
그 뒤에만 SWTITLEPREPARE/SWTITLECONVERT production 로직 반영 검토
```

### 3. nested probe 둘 다 unsafe

조건:

```text
nested-outside = no
nested-direct-outside = no
```

안내:

```text
더 많이 지우는 방식으로 진행하지 않음
실제 native A4 GMTITLE/frame 정의와 비교하는 조사로 전환
```

## preflight 보강

`run_static_preflight.ps1`는 이제 아래 안내가 사라지지 않았는지 검사한다.

```text
Goal status A4 nested probe continuation guidance
Goal status A4 safe-candidate review guidance
Goal status A4 unsafe-nested fallback guidance
Goal status A4 probe before suite guidance
```

## 검증

2026-07-05 현재 확인:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_static_preflight.ps1
결과: PASS

powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_goal_status.ps1
결과: A4 investigation continuation 안내 출력

git diff --check
결과: PASS
```

## 현재 남은 작업

GstarCAD가 열려 있으면 hidden `/b` probe를 실행하지 않는다.

2026-07-05 이어서 확인 결과, nested probe도 둘 다 unsafe였다.

```text
nested-outside: safe=no
nested-direct-outside: safe=no
현재 진행본 A4 native exemplar probe: A4_NATIVE_EXEMPLAR_MISSING_DEFINITION
```

따라서 다음 실제 작업은 아래 순서로 진행한다.

```text
1. 실제 work DWG에서 더 이상 SWTITLEPREPARE/SWTITLECONVERT를 반복하지 않는다.
2. work 아래 별도 scratch DWG를 만든다.
3. 그 scratch에서 GstarCAD GMTITLE로 DR_A4_Outline native A4 샘플을 한 장 만든다.
4. scratch 저장 후 run_a4_native_exemplar_probe.ps1로 DR_A4_Outline 정의를 검사한다.
5. Result가 A4_NATIVE_EXEMPLAR_READY_FOR_COMPARISON일 때만 A4 strategy 구현을 다시 검토한다.
6. A4 strategy 확정 후 focused A4 probe, hidden suite, 실제 SWTITLEVERIFY_FINAL_OK 순서로 검증한다.
```

scratch 샘플에는 비교를 위해 `DR_titlea_3rd`가 생길 수 있다. 하지만 production A4 frame-only 결과에는 원본에 없던 제목블록을 만들면 안 된다.

probe 실행 예:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1 -SourceWorkCopyPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\<scratch-native-a4>.dwg"
```

## 완료 아님

이 변경은 반복 실수를 줄이는 안전장치다. 목표 완료 조건은 여전히 아래다.

```text
SWTITLEVERIFY_FINAL_OK
source title/frame/frame-only count = 0
target sheet counts: A2=1, A3=12, A4=2
A2/A3 대표 제목블록 더블클릭 시 GMTITLE 표 편집창
A4 frame-only는 제목블록 없이 DR_A4_Outline만 정상 bbox로 존재
```
