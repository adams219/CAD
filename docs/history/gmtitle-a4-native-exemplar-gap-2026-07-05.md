# GMTITLE A4 Native Exemplar Gap - 2026-07-05

## 목적

A4 frame-only 변환을 계속하려면 깨끗한 `DR_A4_Outline` 기준 객체가 필요하다.

이번 확인의 목적은 현재 저장된 작업복사본 안에 A4 native 비교 기준이 이미 있는지 확인하는 것이다.

## 추가된 진단 파일

```text
diagnostics/gmtitle-main45/a4_native_exemplar_probe.lsp
diagnostics/gmtitle-main45/run_a4_native_exemplar_probe.ps1
```

실행 명령:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1
```

2026-07-05 후속 안전장치:

```text
현재 runner는 인자 없이 실행하면 중단한다.
이전처럼 기본 작업복사본을 조용히 복사하면 swtitle_a4_native_exemplar_probe_260705.dwg라는 이름 때문에
실제 native A4 scratch 샘플로 착각할 수 있었기 때문이다.
```

과거 기본 입력으로 검사했던 파일:

```text
work/0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

기본 로그:

```text
work/swtitle_a4_native_exemplar_probe_260705.txt
```

## 현재 디스크 작업복사본 확인 결과

`run_actual_workcopy_status_probe.ps1`를 현재 디스크 작업복사본에 다시 실행했다.

로그:

```text
work/swtitle_actual_workcopy_status_current_260705.txt
```

결과:

```text
SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
target-sheet-counts: <none>
```

즉 현재 저장된 기본 작업복사본은 변환 전 상태다.

이전에 보았던 아래 상태와 다르다.

```text
source-title-count: 0
source-frame-count: 2
target-title-count: 13
target-frame-count: 13
target-sheet-counts:
  A2: 1
  A3: 12
```

따라서 이전 A2/A3 target 로그는 저장된 기본 작업복사본이 아니라, 열려 있던 CAD 세션 상태 또는 별도 진단 복사본 상태로 봐야 한다.

## A4 native exemplar probe 결과

현재 디스크 작업복사본에서 A4 native exemplar probe를 실행했다.

2026-07-05에 현재 LSP `260705-verify-source-priority-a4stepnote`로 다시 실행해 같은 결론을 확인했다.

결과:

```text
Loaded version: 260705-verify-source-priority-a4stepnote
DBMOD before checks: 0
Source frame-only count: 2
Expected sheet counts:
  A2: 1
  A3: 12
  A4: 2
Current target sheet counts:
  <none>
A4 outline definition status: missing
Definition exists: no
Visible DR_A4_Outline frame inserts: 0
Result: A4_NATIVE_EXEMPLAR_MISSING_DEFINITION
No drawing data was saved.
DBMOD after checks: 0
```

판단:

현재 저장된 기본 작업복사본에는 `DR_A4_Outline` 정의도 없고, A4 target insert도 없다.

따라서 지금 상태에서는 imported `DR_A4_Outline`과 native A4를 구조 비교할 수 없다.

## 2026-07-05 이어서 확인: A2/A3 진행본도 A4 기준은 없음

이후 최신 CAD next-step 로그가 가리키는 진행본을 대상으로 같은 probe를 다시 실행했다.

입력:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125 CP_ALL_260704_test.dwg
```

로그:

```text
work/swtitle_a4_native_exemplar_probe_260705.txt
```

결과:

```text
Loaded version: 260705-verify-source-priority-a4stepnote
Source frame-only count: 2
Expected sheet counts:
  A2: 1
  A3: 12
  A4: 2
Current target sheet counts:
  A2: 1
  A3: 12
A4 outline definition status: missing
Definition exists: no
Visible DR_A4_Outline frame inserts: 0
Result: A4_NATIVE_EXEMPLAR_MISSING_DEFINITION
```

판단:

A2/A3 변환이 진행된 작업본에서도 비교 가능한 native A4 기준 객체는 아직 없다. 이 상태에서 `SWTITLEPREPARE` 또는 `SWTITLECONVERT`를 반복하면 A4 원본을 보호하는 guard에 다시 걸리는 것이 정상이다.

다음 단계는 실제 작업본을 더 건드리는 것이 아니라, 별도 scratch DWG에 GstarCAD `GMTITLE`로 native A4 샘플을 한 장 만들고 그 구조를 검사하는 것이다.

## 중요한 운영 결론

숨김 GstarCAD probe는 디스크에 저장된 DWG만 본다.

열려 있는 CAD에서 변환을 진행했지만 저장하지 않았거나, 다른 복사본을 열어 작업했다면 숨김 probe 결과와 현재 화면이 다르게 나올 수 있다.

목표모드에서 이어갈 때는 아래 순서를 지킨다.

```text
1. 지금 실제로 보고 있는 CAD 도면에서 SWTITLESTATUS를 먼저 실행한다.
2. 그 로그가 현재 화면 상태의 기준이다.
3. 다른 컴퓨터나 숨김 probe로 이어가려면 먼저 작업복사본 DWG를 저장한다.
4. 저장 후 run_actual_workcopy_status_probe.ps1 또는 run_a4_native_exemplar_probe.ps1로 디스크 상태를 다시 확인한다.
```

## 다음에 필요한 증거

A4 자동화 방향을 더 진행하려면 다음 중 하나가 필요하다.

### 선택 A: 현재 CAD 작업 상태 저장

이미 화면에서 A2/A3 변환이 진행된 상태라면, 그 작업복사본을 저장한다.

저장 후 실행:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_actual_workcopy_status_probe.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1 `
  -SourceWorkCopyPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\<saved-current-workcopy>.dwg"
```

이때 `target-sheet-counts`에 A2/A3가 보이면 그 저장본이 다음 기준이다.

### 선택 B: A4 native scratch 기준 객체 생성

작업복사본을 망치지 않기 위해 `work` 아래의 scratch DWG에서 GstarCAD native `GMTITLE`로 `DR_A4_Outline`을 한 장 만든다.

이 scratch 샘플은 비교 전용이다. `GMTITLE` 동작 때문에 `DR_titlea_3rd`가 같이 생길 수 있지만, production A4 frame-only 변환에서는 원본에 없던 제목블록을 만들면 안 된다.

그 뒤 해당 scratch DWG를 대상으로 실행:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1 `
  -SourceWorkCopyPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\<scratch-a4-native>.dwg"
```

통과해야 하는 조건:

```text
Definition exists: yes
Definition strict A4 warning: <none>
Definition test insert geometry warning: <none>
Definition test insert raw selection warning: <none>
Native GMTITLE A4 pair evidence: yes
Visible DR_A4_Outline frame inserts: 1 이상
Result: A4_NATIVE_EXEMPLAR_READY_FOR_COMPARISON
```

2026-07-05 추가 보강:

```text
DR_A4_Outline 프레임만 깨끗한 경우는 충분한 증거가 아니다.
scratch 비교 샘플은 nearby DR_titlea_3rd 제목블록이 있고, 그 제목블록에 native GMTITLE link evidence가 있어야 한다.
이 증거가 없으면 Result: A4_NATIVE_EXEMPLAR_MISSING_NATIVE_PAIR 로 중단한다.
```

이 결과가 나오기 전까지는 A4 frame-only 자동 삭제/교체를 production 흐름에 넣지 않는다.

## 목표 상태

A4는 아직 완료가 아니다.

현재까지 증명된 것은 아래 두 가지다.

```text
1. 설치 원본 DR_A4_Outline 직접 import와 단순 삭제식 정규화는 안전하지 않다.
2. 현재 저장된 기본 작업복사본에는 비교 가능한 native A4 기준 객체가 없다.
```

다음 구현은 A4 native scratch 기준 객체를 확보한 뒤, 그 구조를 설치 원본 import 결과와 비교하는 것이다.

## 2026-07-05 추가 확인: raw bbox가 A4 밖으로 나가는 정의는 실패 처리

저장된 기본 작업복사본에서는 `DR_A4_Outline` 정의가 처음에는 없었다.

`SWTITLEPREPARE`가 설치 원본에서 `DR_A4_Outline`을 가져오면 겉보기 effective bbox는 A4처럼 보일 수 있지만, direct block definition 안에는 A4 바깥 객체가 포함될 수 있었다.

확인된 예:

```text
Direct DR_A4_Outline definition records:
  INSERT block=도면 세로 A4 From_HYUN bbox=(0,0)-(210,297)
  LINE bbox=(216.25210777,255.85503315)-(266.25210777,255.85503315) OUTSIDE_A4
  LINE bbox=(216.25210777,242.67132656)-(266.25210777,242.67132656) OUTSIDE_A4
  TEXT bbox=(200.9,287.3)-(248.3,292.7) OUTSIDE_A4
  TEXT bbox=(210.9,297.3)-(264.9,302.7) OUTSIDE_A4
Definition raw bbox: (0,0)-(266.25210777,302.7)
Test insert effective bbox: (0,0)-(210,297)
```

이 상태를 `ready`로 처리하면 사용자가 지적한 것처럼 원본 A4에는 없던 선/글자가 변환 후 같이 딸려올 수 있다.

따라서 production LSP는 A4 frame-only용 `DR_A4_Outline`에 대해 추가 조건을 갖는다.

```text
raw definition bbox가 (0,0)-(210,297) 근처를 벗어나면 raw-bbox-risk
SWTITLEPREPARE는 WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE로 중단
기존 A4 원본 도면틀은 삭제하지 않음
```

이 기준은 `diagnostics/gmtitle-main45/run_main45_verification_suite.ps1`의 `A4 outline strict prepare guard probe`에 포함했다.
