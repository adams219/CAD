# GMTITLE 현재 실행 카드

> 2026-07-06 기준 변경: `docs/guide/gmtitle-unified-flow-reset.md`가 GMTITLE 변환의 최우선 기준입니다. A2/A3/A4는 모두 같은 GMTITLE 흐름으로 보고, `frame-only`는 A4 전용 정책이 아니라 원본 표제란 부재가 검증된 경우의 예외로만 해석합니다.

CAD 화면 옆에 열어두고 따라가는 짧은 실행 순서입니다.

## 현재 기준 문서

`docs/guide/gmtitle-unified-flow-reset.md`가 최우선 기준이고, 이 문서는 CAD 화면 옆에서 따라가는 실행 카드입니다.

`docs/history`와 `docs/investigations`는 과거 실험, 실패, 조사 기록입니다. 같은 실수를 피하기 위한 증거로만 보고 그대로 따라 하지 않습니다.

예전 기록에 A4를 별도 frame-only처럼 다룬 표현이 있어도 현재 기준은 다릅니다. A2/A3/A4는 모두 `DR_A*_Outline + DR_titlea_3rd` 공통 GMTITLE 흐름으로 판단하고, 원본 표제란 부재가 검증된 시트만 title-missing 예외로 봅니다.

판단이 갈리면 `docs/guide/gmtitle-unified-flow-reset.md`, 이 문서, `docs/guide/commands.md`, `diagnostics/gmtitle-main45/run_next_cad_action.ps1` 출력 순서로 따릅니다.

## 목표모드 판단 루프

명령을 많이 누르는 것이 목표가 아닙니다. 아래 순서를 한 번씩만 반복합니다.

```text
1. SWTITLESTATUS로 현재 상태 확인
2. 로그가 요구한 명령 하나만 실행
3. 바로 SWTITLESTATUS 또는 SWTITLEVERIFY로 변화 확인
4. 후보 수나 경고가 줄지 않으면 같은 명령 반복 금지
5. raw bbox, 원본에 없던 제목블록 생성, 도면 내부 객체 삭제가 보이면 중단
```

계속 진행해도 되는 증거:

```text
target title/frame 수가 기대 수량에 가까워짐
A2/A3/A4 native 교체 후보가 줄어듦
clone/shared-link 경고가 줄어듦
title-missing 예외 시트가 제목블록 없이 도면틀만 남음
```

진행으로 보지 않는 것:

```text
화면 모양만 비슷함
한 명령어가 오류 없이 끝남
같은 경고가 그대로인데 변환을 반복함
probe 로그를 실제 작업 DWG 로그로 착각함
```

## 테스트 타이밍

CAD 실테스트는 매번 하지 않습니다. `SWTITLESTATUS` 또는 `run_next_cad_action.ps1`가 아래 상태를 보여줄 때만 대표 1장을 처리합니다.

```text
NEXT_CREATE_FIRST_NATIVE_GMTITLE:
  지금 테스트할 때입니다. 첫 native GMTITLE 기준 객체 1장을 만듭니다.

NEXT_CREATE_MISSING_NATIVE_EXEMPLAR:
  지금 테스트할 때입니다. 누락된 용지 크기의 native 기준 객체 1장을 만듭니다.

NEXT_UPGRADE_NATIVE_GMTITLE:
  지금 테스트할 때입니다. 복제/shared-link 후보 1장을 fresh native GMTITLE로 교체합니다.
  OPEN 1회 성공 뒤 후보 수가 줄었는지 확인하기 전에는 BATCH로 넘어가지 않습니다.

READY_FOR_TITLE_MISSING_OUTLINE:
  지금 테스트할 때입니다. 원본 표제란 부재가 검증된 시트의 도면틀-only 변환을 1장 확인합니다.
  성공 기준은 새 DR_titlea_3rd가 아니라 같은 크기 DR_A*_Outline 도면틀입니다.

NEXT_PREPARE_*:
  아직 GMTITLE 창 테스트 시점이 아닙니다. SWTITLEPREPARE 후 다시 상태를 봅니다.

NEXT_REVIEW_* / ABORT_* / WARN_*:
  지금은 테스트를 멈출 때입니다. 같은 변환을 반복하지 않고 원인 로그를 봅니다.

SWTITLEVERIFY_FINAL_OK:
  변환 테스트는 끝났습니다. 대표 DR_titlea_3rd 제목블록 더블클릭 확인만 남았습니다.
```

## 자동화 경계

현재 흐름은 완전 자동 변환이 아니라, 위험한 선택만 사람이 확인하고 나머지를 LSP가 처리하는 방식입니다.

```text
LSP가 자동 처리:
  현재 후보 판별
  기존 도면틀 왼쪽 아래 배치점 계산/전송
  표제란 값 추출과 DR_titlea_3rd 속성값 입력
  이전 SolidWorks 도면틀/표제란/허용된 잔여물 정리
  새 결과 검사와 실패 시 보존/rollback

사람이 확인:
  GMTITLE 창의 DR_A*_Outline 용지
  DR_titlea_3rd 제목블록
  Frame positioning ON
  Object move OFF
```

아직 GMTITLE 창 선택까지 완전 자동으로 켜지 않는 이유는, GstarCAD가 일반/ISO 기본값으로 열릴 수 있고 리본/스크린 좌표 자동화는 안정 증거가 없기 때문입니다. 그래서 `SWTITLECONVERTNEXT`는 `YES`/`OPEN` 같은 반복 응답만 자동으로 고르고, GMTITLE 창의 DR 선택은 사람이 눈으로 확인합니다.

2026-07-07 single-clone probe 확인: 실제 작업복사본을 복사한 `swtitle_single_clone_probe.dwg`에서 내부 clone 1장을 실행하면 원본 표제란은 11 -> 10으로 줄고 target pair는 2 -> 3으로 늘지만, A2/A3/A4 native 교체 후보도 0 -> 2로 늘었습니다. 결론은 hidden/script로 clone만 밀어붙이는 방식은 최종 GMTITLE native 동작을 보장하지 못한다는 것입니다. 따라서 현재 LSP는 남은 A3도 `SWTITLECONVERTNEXT`가 clone 이후 필요한 native 교체 1장을 보이는 CAD에서 이어서 처리하도록 합니다.

## 시작 조건

반드시 `work` 폴더 안의 작업복사본에서만 실행합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

`Downloads` 원본 DWG나 실제 납품 원본에서 바로 실행하지 않습니다.

## 로드

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
SWTITLEVERSION
```

기대 버전:

```text
260707-convert-next-clone-upgrade-19
```

다른 버전이면 변환하지 말고 최신 LSP를 다시 `APPLOAD`합니다.

## GMTITLE 배치점 원칙

`SWTITLECONVERTNEXT` 또는 수동 `SWTITLECONVERT`를 통해 GMTITLE 창을 열었을 때는 긴 좌표를 사람이 직접 치지 않습니다.

```text
용지/도면틀과 제목블록을 고른 뒤 OK
Frame positioning: ON
Object move: OFF
```

CAD 명령줄에 `GMTITLE`, `TIT`, 일반 `OPEN`을 직접 입력해서 우회하지 않습니다. `SWTITLECONVERTNEXT`/`SWTITLECONVERT`가 GMTITLE 호출, 왼쪽 아래 배치점 자동 전송, 값 복사, 이전 원본 정리를 묶어서 처리합니다.

`SWTITLECONVERT` 안에서 물어보는 `YES`, `OPEN`, `BATCH`, `MANUAL` 응답은 CAD 일반 `OPEN` 명령과 다릅니다.

그 다음 `SWTITLECONVERTNEXT`/`SWTITLECONVERT`가 기존 원본 도면틀의 왼쪽 아래 배치점을 자동 전송합니다.
마우스 커서가 화면 중앙에 남아 보여도, 명령줄이 삽입점을 기다리는 상태라면 잠시 기다렸다가 자동 입력을 확인합니다.

자동 입력 후에도 삽입점 입력이 남아 있으면 기존 원본 도면틀의 왼쪽 아래 끝점을 OSNAP으로 찍습니다.
객체 선택/새 위치 프롬프트가 나오면 Object move가 켜진 상태일 수 있으므로 취소하고 다시 확인합니다.

## 현재 기준 상태를 고르는 법

이 문서는 특정 DWG의 과거 상태를 "최신"으로 고정하지 않습니다. 현재 상태는 아래 순서로만 판단합니다.

```text
1. CAD가 열려 있으면 현재 도면에서 SWTITLESTATUS를 실행합니다.
2. work\swcad_title_next_step_last.txt의 DWG 경로가 현재 열린 work 복사본과 같은지 확인합니다.
3. CAD를 저장하고 닫은 상태라면 run_next_cad_action.ps1 또는 -AutoRefreshDirectProbe 카드로 direct probe를 갱신합니다.
4. 로그가 probe/diagnostics/예전 복사본을 가리키면 그 로그는 현재 작업 기준으로 쓰지 않습니다.
```

즉, 과거에 어떤 도면이 `NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION`이었더라도 지금 열린 도면에 그대로 적용하지 않습니다. 같은 명령을 반복하기 전에 항상 현재 도면의 `SWTITLESTATUS` 또는 direct probe 카드가 요구하는 한 단계만 따릅니다.

A2/A3/A4 참고:

```text
DR_A3_Outline 도면틀 자체는 native GMTITLE에서도 INSERT/block 참조로 보일 수 있습니다.
A3 성공 여부는 도면틀 더블클릭이 아니라 짝 DR_titlea_3rd 제목블록 더블클릭 표 편집창으로 확인합니다.

원본 표제란 부재가 검증된 title-missing 시트는 원본에 없던 DR_titlea_3rd를 새로 만들면 안 됩니다.
```

`SWTITLEPREPARE`를 실행한 뒤에는 반드시 `SWTITLESTATUS`를 다시 실행합니다.
그 결과가 `SWTITLECONVERTNEXT`를 안내하면 그때 변환을 진행합니다.
`WARN_TITLE_MISSING_OUTLINE_DEFINITION_UNSAFE`가 나오면 멈추고, `OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED`와 `ready-native-outside-markers`가 나오면 title-missing/frame-only 도면틀-only 변환 준비가 된 상태로 봅니다. 상태 코드 이름에 A4가 남아 있어도 현재 해석은 원본 표제란 부재 예외입니다.

현재 probe 기준으로는 설치 원본 `DR_A4_Outline`이 A4 바깥의 작은 native 마커를 포함합니다.
이제 이 경우를 무조건 실패로 보지 않고, effective A4 형상과 raw selection 검사가 통과하면 `ready-native-outside-markers`로 허용합니다.

```text
prepare probe:
OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED
After definition status: ready-native-outside-markers

보이는 A4 범위:
(0, 0) - (210, 297)

실제 test insert effective 범위:
(0, 0) - (210, 297)

raw selection warning:
<none>

convert probe:
FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER
Before target title count: 1
After target title count: 1
target title delta=0
After DR_A4_Outline target frame count: 1
```

즉 당시 title-missing으로 감지된 A4 케이스는 target title 수를 늘리지 않고 `DR_A4_Outline` 도면틀만 교체하는 쪽으로 검증됐습니다. 이 결론은 A4 전체 정책이 아니라 해당 원본 상태에 대한 예외입니다.
다만 큰 raw bbox 위험이나 raw selection warning이 나오면 여전히 안전 중단입니다.

scratch native A4 비교는 이미 완료된 과거 조사입니다. 같은 scratch A4를 다시 만들 필요는 없습니다.

```text
2026-07-05 clean scratch 결과:
  scratch_native_a4_clean_260705.dwg
  Native GMTITLE A4 pair evidence: yes
  Result: A4_NATIVE_EXEMPLAR_READY_WITH_NATIVE_OUTSIDE_MARKERS

2026-07-05 production title-missing/frame-only probe:
  FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER
  After frame-only-count: 1
  Before target title count: 1
  After target title count: 1
  target title delta=0
  After DR_A4_Outline target frame count: 1
```

즉 지금은 scratch 비교를 반복하지 않고 실제 work-copy에서 일반 4단계 흐름으로 돌아갑니다.

중요:

```text
현재 work DWG에 더 많은 삭제/정규화 실험을 시도하지 않습니다.
`ready-native-outside-markers`는 공식 A4의 작은 바깥 마커를 허용한다는 뜻입니다.
title-missing source에는 원본에 없던 `DR_titlea_3rd` 제목블록을 만들면 안 됩니다.
전체 suite가 기본 A4 probe 로그를 덮어쓸 수 있으므로 clean scratch 증거는 `work\swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt` 전용 로그로 봅니다.
```

설정값을 다시 확인해야 할 때:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_gmtitle_selection_config_probe.ps1
```

현재 기대 결과는 `GMTITLE_SELECTION_CONFIG_NOT_FOUND`입니다.
`-DeepRegistrySearch`에서 `Recent File List`에 DR 파일 경로가 보여도 최근 직접 열었던 파일 기록일 뿐, GMTITLE 대화상자의 용지/제목블록을 자동 선택할 근거로 쓰지 않습니다.

### 현재 저장본 direct probe 상태

2026-07-08 저장 후 direct probe 기준, 현재 기본 작업복사본은 첫 native 전 상태가 아닙니다.
A2와 일부 A3 native-like 쌍은 만들어졌고, 남은 A3/A4 처리가 필요합니다.

```text
direct probe 로그:
work\swtitle_actual_workcopy_direct_status_260705.txt

DWG:
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg

현재 저장 상태:
NEXT_RUN_FAST_BATCH

검증 상태:
SWTITLEVERIFY_FINAL_FAIL

target title/frame:
4 / 4

GMTITLE pair/native-like:
4 / 4

A2/A3/A4 native 교체 후보:
0

남은 원본:
  표제란 시트 9
  원본 도면틀 11
  title-missing/frame-only 시트 2

현재 부족한 target 수량:
  A3: 필요 12, 현재 3
  A4: 필요 2, 현재 0

다음 CAD 단계:
SWTITLECONVERTNEXT

다음 GMTITLE 확인값:
DR_A3_Outline / DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

이 상태에서 `SWTITLECONVERTNEXT`는 남은 A3 전체를 한 번에 끝내는 뜻이 아닙니다.
다음 표제란 시트 1장을 clone 변환한 뒤, 바로 생긴 native 교체 후보 1장을 visible CAD에서 확인하는 안전 흐름입니다.
한 장 처리 후에는 저장하고 GstarCAD를 닫은 뒤 `run_after_manual_gmtitle_step.ps1 -Compact`로 상태를 다시 잠급니다.

### 새 작업복사본 초기 상태 참고

2026-07-06 01:02 final completion gate 기준, 기본 작업복사본은 아직 변환 전 상태입니다.
이 내용은 같은 원본에서 새 work 복사본을 다시 만들고 처음부터 시작할 때만 쓰는 기준입니다.
이미 변환이 진행된 현재 저장본에는 위 direct probe 상태를 우선 적용합니다.

```text
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
남은 원본 표제란 시트: 13
남은 원본 도면틀: 15
표제란 없는 도면틀 시트: 2
target 도면틀/제목블록: 0
필요한 최종 수량:
  A2: 1
  A3: 12
  A4: 2
없는 native 기준 객체:
  DR_A2_Outline
  DR_A3_Outline
  DR_A4_Outline
```

실제 작업복사본 direct probe 갱신 명령:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_actual_workcopy_direct_status_probe.ps1
```

이 direct probe는 저장된 `work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg`를 읽고 `work\swtitle_actual_workcopy_direct_status_260705.txt`를 갱신합니다. 결과는 계속 `dbmod-after-commands: 0`이어야 합니다. 이 명령은 실제 CAD 변환을 대신하지 않고, `SWTITLECONVERTNEXT` 전에 저장된 기준 상태와 다음 한 단계만 확인합니다.

현재 PC에서는 실제 작업복사본 direct probe 기본 제한 시간을 180초로 둡니다. 90초 제한에서는 GstarCAD 시작은 됐지만 로그가 쓰이기 전에 timeout이 나서 근거 로그가 비는 경우가 있었습니다.

작업복사본 DWG의 저장 시간이 direct probe 로그보다 최신이거나, direct probe 로그의 `Loaded version`이 현재 LSP 기대 버전과 다르면 짧은 카드는 다음 명령을 안내하지 않고 먼저 direct probe 갱신을 요구합니다. CAD에서 변환하고 저장한 뒤 예전 로그를 보거나, LSP 업데이트 전 로그를 보고 같은 명령을 반복하는 실수를 막기 위한 장치입니다.

GstarCAD를 저장 후 닫은 상태라면 짧은 카드에 `-AutoRefreshDirectProbe`를 붙여 direct probe 갱신과 다음 행동 판단을 한 번에 할 수 있습니다. GstarCAD가 열려 있으면 hidden probe가 중단될 수 있으므로, 이 옵션은 닫힌 상태에서만 사용합니다.

짧은 CAD 실행 카드:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_next_cad_action.ps1
```

자동 갱신까지 함께 실행:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_next_cad_action.ps1 -AutoRefreshDirectProbe
```

CAD 화면 옆에서 다음 명령, GMTITLE 선택값, 즉시 중단 조건, 바로 확인할 명령만 보고 싶을 때 이 카드를 사용합니다.
이 카드는 `work\main56_verification_suite_last_run.txt`도 같이 읽어서 최근 hidden suite가 `PASS`였는지, 아니면 `FAILED_BEFORE_PASS`로 멈췄는지 먼저 보여줍니다. 단, suite `PASS`는 자동화/guard 검증이 통과했다는 뜻이고 실제 work DWG 변환 완료 증거는 아닙니다.

이 카드는 `work\swtitle_final_completion_gate_status.txt`도 같이 읽습니다. final completion gate가 direct probe보다 최신이면 두 로그의 `SWTITLESTATUS`, `SWTITLEVERIFY`, 다음 native GMTITLE 값이 서로 일치하는지 확인합니다. 서로 다르면 `REVIEW_FINAL_GATE_DIRECT_PROBE_CONFLICT`로 멈추고, direct probe 갱신 또는 final completion gate 재실행을 요구합니다.

수동으로 `SWTITLECONVERTNEXT`와 GMTITLE 창 선택을 한 번 끝낸 뒤에는 아래 래퍼를 쓰는 편이 더 안전합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_after_manual_gmtitle_step.ps1
```

긴 카드 대신 다음 한 단계 요약만 보려면:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_after_manual_gmtitle_step.ps1 -Compact
```

이 명령은 DWG를 직접 편집하지 않습니다. 작업복사본을 저장하고 GstarCAD를 닫은 상태에서 direct probe를 갱신하고, 최신 증거로 다음 CAD 작업 카드를 다시 출력합니다. 카드가 최종 검증 단계라고 판단하면 `run_final_completion_gate.ps1`도 이어서 실행하고, 결과를 `work\swtitle_after_manual_gmtitle_step_last.txt`에 남깁니다.

CAD를 닫을 준비를 하면서 기다리게 하려면:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_after_manual_gmtitle_step.ps1 -WaitForGstarCADClose
```

작업복사본 열기부터, 사용자가 한 장을 처리하고 CAD를 닫은 뒤 자동 점검까지 한 번에 묶고 싶으면 아래 세션 래퍼를 사용할 수 있습니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_manual_gmtitle_session.ps1
```

이 세션 래퍼도 `SWTITLECONVERTNEXT`를 대신 실행하거나 GMTITLE 창을 클릭하지 않습니다. 먼저 `run_next_cad_action.ps1`를 자동 direct probe 갱신 없이 실행해서 저장된 작업복사본의 다음 작업 카드를 확인하고, 카드가 실제 변환 1장을 요구할 때만 작업복사본을 엽니다. hidden direct probe 갱신까지 먼저 하고 싶을 때만 `-AutoRefreshDirectProbe`를 붙입니다. 작업복사본을 열고, 사람이 CAD에서 한 장을 처리해 저장/닫기 할 때까지 기다린 뒤 `run_after_manual_gmtitle_step.ps1`를 이어서 실행합니다.

이미 CAD를 직접 열어 둔 상태에서만 `-SkipOpenWorkcopy`를 붙입니다. CAD가 열려 있지 않으면 세션 래퍼는 `SKIP_OPEN_NO_GSTARCAD`로 멈추고, 오래된 상태 점검을 실행하지 않습니다.

이미 보이는 CAD에서 `SWTITLESTATUS`를 확인한 경우에만 `-SkipInitialNextActionCard`를 붙입니다. 이 옵션은 hidden next-action 갱신을 건너뛰므로, 현재 열린 DWG가 work 복사본인지 직접 확인한 뒤에만 사용합니다.

CAD를 열기 전에 이번에 고를 용지/제목블록만 먼저 확인하려면 `-PreflightOnly`를 붙입니다. 이 옵션은 visible CAD를 열지 않고 next-action 카드와 짧은 GMTITLE 선택 요약만 출력합니다.

긴 next-action 카드 전체가 필요 없고 짧은 선택 요약만 보고 싶으면 `-Compact`도 같이 붙입니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_manual_gmtitle_session.ps1 -PreflightOnly -Compact
```

CAD가 닫혀 있고 작업복사본을 여는 단계부터 줄이고 싶으면 아래 helper를 사용할 수 있습니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_open_workcopy_for_manual_convert.ps1
```

이 helper는 기본적으로 작업복사본을 보이는 GstarCAD로 여는 것까지만 합니다. `/b` startup script로 `APPLOAD`와 `SWTITLESTATUS`까지 자동 실행하는 방식은 이 Codex 세션에서 실제 CAD 창이 안정적으로 유지되지 않는 경우가 있어 기본값에서 제외했습니다.

CAD 창이 준비된 뒤 명령줄에서 아래 순서로 직접 실행합니다.

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
SWTITLEVERSION
SWTITLESTATUS
SWTITLECONVERTNEXT
```

만약 helper가 `GSTARCAD_NO_VISIBLE_WINDOW`를 출력하면 Codex 세션에서 GstarCAD 프로세스는 시작됐지만 실제 창이 안정적으로 유지되지 않은 것입니다. 이때 helper가 변환 없이 해당 프로세스를 정리하므로, Windows 시작 메뉴나 기존 CAD 바로가기로 작업복사본을 직접 연 뒤 `APPLOAD`부터 진행합니다.

`GSTARCAD_VISIBLE_WINDOW_NOT_STABLE_AFTER_CHECK`도 같은 의미로 봅니다. 시작 직후 임시 창 핸들은 생겼지만 실제 CAD 창이 유지되지 않은 상태라서, helper가 변환 없이 프로세스를 정리합니다.

현재 PC에서는 Codex Computer Use가 GstarCAD 화면 캡처는 가능하지만 활성화/클릭/입력은 안정적이지 않습니다. 특히 긴 명령어를 붙여넣기 방식으로 넣으면 CAD가 `_pasteclip` 삽입 명령으로 해석할 수 있습니다. 또한 Codex가 `SWTITLECONVERTNEXT`를 직접 타이핑하면 CAD 동적 입력이 도면 문자 삽입으로 해석될 수 있습니다. 따라서 실제 `SWTITLECONVERTNEXT`/`SWTITLECONVERT` 명령 입력과 GMTITLE 창 선택은 사용자가 직접 하고, Codex는 로그/문서/검증 기준을 정리하는 쪽으로 사용합니다.

## Hidden Suite 검증 상태

최신 hidden suite PASS 여부와 Generated 시각은 아래 둘 중 하나로 확인합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_goal_status.ps1
```

또는 `work\main56_verification_suite_last_run.txt`의 `Generated:`와 `Result:`를 직접 봅니다.
이 문서는 특정 과거 실행 시각을 현재 기준으로 고정하지 않습니다.

```text
no-CAD next-action card probe: PASS
GstarCAD /b script smoke probe: 최근 run_goal_status 결과를 우선 확인
actual work-copy status probe: 현재 direct probe는 NEXT_RUN_FAST_BATCH
A4 outline prepare: OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED
title-missing/frame-only convert: FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER
selection config deep registry: GMTITLE_SELECTION_CONFIG_NOT_FOUND
All expected log markers were verified.
```

이 결과는 구현 방향이 probe 복사본에서 깨지지 않았다는 증거입니다. 실제 작업복사본의 `SWTITLEVERIFY_FINAL_OK`와 대표 제목블록 더블클릭 확인은 아직 별도입니다.

이 카드는 direct probe의 현재 상태 코드를 보고 아래처럼 다음 행동을 바로 나눕니다.
또한 `예상 수동 GMTITLE 확인량`을 같이 출력해서, 지금 한 번만 확인할 용지와 나중에 추가로 확인될 수 있는 용지를 분리해 보여줍니다. title-missing 예외 시트는 제목블록 생성 대상이 아니므로 이 예측에서도 별도로 표시합니다.

```text
NEXT_CREATE_FIRST_NATIVE_GMTITLE -> SWTITLECONVERTNEXT 권장, 수동 응답 직접 선택 시 SWTITLECONVERT
NEXT_CREATE_MISSING_NATIVE_EXEMPLAR -> SWTITLECONVERTNEXT 권장, 수동 응답 직접 선택 시 SWTITLECONVERT
NEXT_UPGRADE_NATIVE_GMTITLE -> SWTITLECONVERTNEXT 권장, 수동 응답 직접 선택 시 SWTITLECONVERT
NEXT_PREPARE_* -> SWTITLEPREPARE
NEXT_REVIEW_* 또는 ABORT_/WARN_ -> 같은 변환 반복 금지, SWTITLESTATUS/SWTITLEVERIFY 로그 확인
SWTITLEVERIFY_FINAL_OK -> 대표 제목블록 더블클릭 확인
```

현재 저장본 direct probe가 `NEXT_RUN_FAST_BATCH`라면 다음 실제 CAD 명령은 `SWTITLECONVERTNEXT`입니다. 현재 다음 대상은 `DR_A3_Outline / DR_titlea_3rd`입니다.
새 work 복사본을 처음부터 다시 시작한 경우에만 첫 대상이 보통 `DR_A2_Outline / DR_titlea_3rd`입니다.
`YES`/`OPEN` 같은 반복 응답을 직접 고르고 싶을 때만 `SWTITLECONVERT`를 사용합니다.

중요: 위 초기 상태를 이미 변환이 진행된 CAD 도면에 그대로 적용하지 않습니다.
항상 최신 `SWTITLESTATUS` 또는 `swcad_title_next_step_last.txt`의 DWG 경로가 현재 열린 도면과 같은지 먼저 확인합니다.

## 기본 순서

항상 상태부터 봅니다.

```text
SWTITLESTATUS
```

상태가 정리를 요구하면:

```text
SWTITLEPREPARE
SWTITLESTATUS
```

상태가 변환을 요구하면:

```text
SWTITLECONVERTNEXT
SWTITLESTATUS
```

수동 응답을 직접 고르고 싶으면 대신 아래 명령을 사용할 수 있습니다.

```text
SWTITLECONVERT
```

`SWTITLECONVERTNEXT`는 아래의 `YES`/`OPEN` 선택만 자동으로 고르고, GMTITLE 창에서 DR 용지/제목블록/옵션을 확인하는 일은 그대로 남깁니다.

따라서 `SWTITLECONVERTNEXT`를 쓴 경우에는 `YES`, `OPEN`, `BATCH`, `MANUAL`을 다시 입력하지 않습니다. 아래 응답표는 수동 `SWTITLECONVERT`로 직접 고를 때만 봅니다.

`SWTITLECONVERT` 안에서 입력을 물으면 상태별로 아래처럼 답합니다.

```text
첫 native GMTITLE 생성: YES
누락된 용지 크기의 첫 native GMTITLE 생성: YES
A2/A3/A4 native 교체 1장 처리: OPEN
BATCH는 OPEN으로 최소 1장 성공한 뒤, 같은 DR 용지/제목블록/옵션이 반복된다는 걸 눈으로 확인할 수 있을 때만 사용
OPEN이 새 GMTITLE을 못 잡거나 NO_INSERTS가 반복됨: MANUAL
판단이 애매하거나 현재 DWG가 다름: Enter로 중단
```

처음부터 `BATCH`를 쓰지 않습니다. 먼저 `OPEN`으로 후보 수가 줄어드는지 확인한 뒤, 같은 선택값이 반복되는 구간에서만 사용합니다.

최종 검증:

```text
SWTITLEVERIFY
```

## GMTITLE 창에서 선택할 값

`SWTITLECONVERTNEXT` 또는 수동 `SWTITLECONVERT` 중 GMTITLE 창이 열리면 로그가 요구한 값만 고릅니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

금지:

<!-- RIBBON_ACCESSIBILITY_NOT_STABLE -->

```text
일반 A2/A3/A4 용지
ISO 제목블록
스크린샷 좌표 클릭
리본 접근성/스크린샷 좌표로 DR 용지 자동 선택
긴 소수점 좌표 수동 입력
Object move ON
```

`SWTITLECONVERTNEXT`/`SWTITLECONVERT`는 GMTITLE 창 이후 필요한 왼쪽 아래 기준점을 자동으로 보내도록 설계되어 있습니다. 사람이 긴 좌표를 직접 칠 필요가 없습니다.

## 상태 문구별 행동

| 로그 문구 | 의미 | 다음 행동 |
| --- | --- | --- |
| `NEXT_CREATE_FIRST_NATIVE_GMTITLE` | 아직 실제 native GMTITLE 기준 객체가 없음 | `SWTITLECONVERTNEXT` |
| `NEXT_PREPARE_FRAME_STYLE_NORMALIZATION` | 도면틀 내부 형상과 별도 제목블록이 겹쳐 정규화 필요 | `SWTITLEPREPARE` |
| `NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT` | 도면에 실수 명령어 텍스트 후보가 있음 | 후보 확인 후 `SWTITLEPREPARE` |
| `NEXT_UPGRADE_NATIVE_GMTITLE` | A2/A3/A4 복제/shared-link 쌍을 fresh native로 교체해야 함 | `SWTITLECONVERTNEXT` |
| `WAITING_FOR_TITLE_MISSING_OUTLINE_DEFINITION` | 과거 상태명. 현재 기준으로는 title-missing 예외 전에 해당 DR_A*_Outline 검증 필요 | `SWTITLEPREPARE` |
| `NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION` | 원본 표제란 부재가 검증된 시트의 같은 크기 DR 도면틀 정의 준비/검증 필요 | `SWTITLEPREPARE` |
| `NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX` | 도면틀 정의 선택 범위가 위험함 | 변환 반복 금지, 로그 확인 |
| `ABORT_FRAME_DEFINITION_RAW_BBOX_RISK` | 기존 도면 보호를 위해 중단됨 | 변환 반복 금지, 원인 분석 |
| `SWTITLEVERIFY_FINAL_FAIL` | 완료 조건 미달 | `SWTITLESTATUS`로 다음 조치 확인 |
| `SWTITLEVERIFY_FINAL_OK` | 검증 기준 통과 | 대표 제목블록 더블클릭 확인 |

## A3 판단

A3 도면틀이 CAD에서 block/INSERT처럼 보이는 것만으로 실패는 아닙니다. GstarCAD native GMTITLE 도면틀도 내부적으로 INSERT/block reference처럼 보일 수 있습니다.

성공 판단은 아래 기준입니다.

```text
DR_titlea_3rd 제목블록 더블클릭 -> GMTITLE 표 편집창 열림
A2/A3/A4 native 교체 후보: 0
clone/shared-link 경고: 0
겹친 target pair: 0
SWTITLEVERIFY가 OK 쪽으로 진행
```

도면틀 안에 표제란처럼 보이는 native-format 형상이 있어도, 별도 `DR_titlea_3rd`와 실제로 겹치는 문제가 아니라면 삭제하지 않습니다.

## title-missing 판단

원본 시트는 표제란 없는 도면틀-only 시트일 수 있습니다. 이 예외는 A4 전용이 아니며, 원본 표제란 부재가 검증된 경우에만 적용합니다.

따라서 title-missing/frame-only 성공 조건은 제목블록을 만드는 것이 아닙니다.

```text
같은 크기 DR_A*_Outline 도면틀만 원본 위치/크기에 맞음
불필요한 DR_titlea_3rd 제목블록 없음
title-missing/frame-only target 수량이 원본 기준과 맞음
DR_A*_Outline raw definition bbox가 해당 용지 범위 근처를 벗어나지 않음
기존 도면 내용 삭제 없음
```

원본에 표제란이 없던 위치에 `DR_titlea_3rd`가 생기면 멈추고 로그를 봅니다.
`WARN_TITLE_MISSING_OUTLINE_DEFINITION_UNSAFE`는 원본 도면 내용을 지키기 위해 변환을 중단했다는 뜻입니다.
반대로 `ready-native-outside-markers`는 공식 native 정의의 작은 바깥 마커는 있지만 effective 형상과 raw selection 검사가 통과했다는 뜻입니다.
`run_a4_outline_convert_probe.ps1` 기준으로는 title-missing/frame-only 1장을 변환한 뒤에도 `target title delta=0`, `After DR_A4_Outline target frame count: 1`이므로, 원본에 없던 표제란을 추가하지 않는 조건을 만족합니다.

## 로그를 볼 때 우선순위

검증 suite나 probe를 돌리면 `*_last.txt`가 실제 작업 DWG가 아니라 진단용 DWG를 가리킬 수 있습니다. 로그를 볼 때는 파일 이름보다 안의 DWG 경로를 먼저 봅니다.

우선 확인할 로그:

```text
work\swcad_title_structure_diagnosis_last.txt
work\swcad_title_verify_summary_last.txt
work\swcad_title_transfer_apply_last.txt
work\swcad_title_native_upgrade_last.txt
```

진단 전용 로그는 실제 작업 결과로 착각하지 않습니다.

```text
swtitle_*_probe*.dwg
*_compare_*.dwg
*_diagnostics.dwg
```

## 완료 기준

아래가 모두 맞아야 완료입니다.

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
frame-only 시트: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
A2/A3/A4 native 교체 후보: 0
겹친 GMTITLE target 쌍: 0
clone/shared-link 경고: 0
```

수동 화면 확인:

```text
DR_titlea_3rd가 있는 대표 A2/A3/A4 제목블록 더블클릭 -> GMTITLE 표 편집창 열림
title-missing 예외 시트 -> 제목블록 없이 해당 DR_A*_Outline 도면틀만 있음
도면 내부 번호, 주석, BOM, 치수, 모델 형상 유지
```

`SWTITLEVERIFY_FINAL_OK` 전에는 완료로 보지 않습니다.
