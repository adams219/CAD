# GMTITLE 목표모드 상세 계획

이 문서는 SolidWorks DWG를 GstarCAD Mechanical native GMTITLE 구조로 안정 변환하기 위한 목표모드 실행 기준이다.

목표는 명령어를 계속 늘리는 것이 아니다. 목표는 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 흐름 안에서 사람이 반복 선택하는 일을 줄이되, GstarCAD native GMTITLE 인식이 깨지지 않게 만드는 것이다.

## 목표모드 운영 루프

목표모드에서는 "다음 명령을 많이 실행"하는 것이 아니라, 아래 루프를 반복한다.

```text
1. 증거 잠금
   현재 열린 DWG가 work 복사본인지, 최신 LSP인지, 로그가 현재 도면을 가리키는지 확인한다.

2. 상태 분류
   SWTITLESTATUS 결과를 보고 첫 native 부재, A3/A4 native 교체, A4 frame-only, 정규화/위험 상태 중 하나로 분류한다.

3. 최소 변경
   상태가 요구하는 명령 하나만 실행한다. 보통 SWTITLEPREPARE 또는 SWTITLECONVERT 중 하나다.

4. 재검증
   바로 SWTITLESTATUS 또는 SWTITLEVERIFY를 다시 실행해 수량, 후보 수, 경고 수가 실제로 바뀌었는지 확인한다.

5. 중단 판단
   후보 수가 줄지 않거나 raw bbox, A4 제목블록 생성, 도면 내부 객체 삭제 같은 위험이 보이면 같은 명령을 반복하지 않는다.

6. 기록
   왜 계속하는지, 왜 멈추는지, 어떤 로그가 근거인지 문서/최종 답변/커밋에 남긴다.
```

이 루프의 기준은 "모양이 그럴듯한가"가 아니라 "native GMTITLE 구조라는 증거가 늘었는가"다.

### 역할 분담

LSP가 맡는 일:

```text
시트 크기 탐지
원본 표제란 값 추출
DR_titlea_3rd 속성값 매핑
왼쪽 아래 배치점 계산
새 GMTITLE 결과 검사
기존 SolidWorks 도면틀/표제란/허용된 잔여물 삭제
SWTITLESTATUS/SWTITLEVERIFY 로그 출력
```

사람 또는 CAD 화면 확인이 아직 필요한 일:

```text
GMTITLE 창에서 로그가 요구한 DR_A*_Outline이 맞는지 확인
제목블록이 DR_titlea_3rd인지 확인
Frame positioning이 ON인지 확인
Object move가 OFF인지 확인
대표 제목블록 더블클릭 시 GMTITLE 표 편집창이 열리는지 확인
```

이 사람이 필요한 부분은 자동화가 불가능해서 남겨 둔 것이 아니다. 현재 증거상 GstarCAD가 기본값을 일반 A3/A4 또는 ISO 제목블록으로 열 수 있으므로, 잘못된 native 객체를 대량 생성하지 않기 위한 안전장치다.

### 진행률 판단

목표모드의 진행률은 아래 항목으로 본다.

```text
진행됨:
  target title/frame 수가 기대 수량에 가까워짐
  A3/A4 native 교체 후보가 줄어듦
  clone/shared-link 경고가 줄어듦
  frame-only A4가 제목블록 없이 도면틀만 남음
  SWTITLEVERIFY_FINAL_OK에 가까워짐

진행 아님:
  도면 모양만 비슷해짐
  새 명령어가 늘어남
  같은 경고가 그대로인데 변환을 반복함
  A4에 원본에 없던 제목블록이 생김
  probe 로그를 실제 작업도면 로그로 착각함
```

## 현재 기준 상태

현재 믿을 수 있는 기준은 최신 CAD 로그와 work 복사본이다.

```text
LSP 기준:
loader: 260705-4step-gmtitle-a4-outline-preflight
gmtitle: 260705-verify-source-priority

작업 도면:
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg

SWTITLESTATUS 결과:
NEXT_CREATE_FIRST_NATIVE_GMTITLE

SWTITLEVERIFY 결과:
SWTITLEVERIFY_FINAL_FAIL

현재 남은 핵심 문제:
  원본 표제란 시트: 13
  원본 도면틀: 15
  표제란 없는 도면틀 시트: 2
  대상 GMTITLE 제목블록: 0
  대상 GMTITLE 도면틀: 0
  예상 시트 수: A2 1, A3 12, A4 2
  필요한 native 기준 객체: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline
```

이 상태는 변환 전 기준이다. 지금은 A3/A4 후보를 바로 복제 처리하는 단계가 아니라, 먼저 실제 GstarCAD `GMTITLE`로 각 용지 크기의 native 기준 객체를 만들어야 한다.

### 로그 신뢰 기준

목표모드에서는 `work\*_last.txt` 파일 이름만 보고 현재 상태를 판단하지 않는다. 검증 suite나 probe가 실행되면 `*_last.txt`가 실제 작업복사본이 아니라 임시 probe DWG를 가리킬 수 있다.

현재 디스크 기준 작업복사본 상태를 확인할 때 우선 보는 증거는 아래와 같다.

```text
work\swtitle_actual_workcopy_status_main56_diagnostics.txt
work\swcad_title_fast_status_last_actual_workcopy_main56_diagnostics.txt
work\swcad_title_next_step_last_actual_workcopy_main56_diagnostics.txt
work\swcad_title_verify_summary_last_actual_workcopy_main56_diagnostics.txt
```

사용자가 CAD에서 방금 명령을 실행한 경우에는 suffix 로그보다 현재 CAD가 새로 쓴 `*_last.txt`가 더 중요하다. 단, 반드시 로그 안의 `DWG 파일:` 또는 `DWG:` 경로가 현재 열린 `work` 복사본인지 확인한다.

```text
신뢰 가능:
  DWG 파일이 현재 열린 work 복사본과 같음
  SWTITLE LSP 버전이 260705-verify-source-priority
  방금 실행한 명령 결과임

신뢰 보류:
  DWG 파일이 swtitle_*_probe*.dwg
  DWG 파일이 command_text_guard, fixture, compare, diagnostics 전용 복사본
  사용자가 보고 있는 CAD 도면과 로그의 DWG 경로가 다름
```

이 기준을 통과하지 못하면 같은 명령을 반복하지 말고, 먼저 현재 CAD에서 `SWTITLESTATUS`를 다시 실행한다.

## 현재 증거 기반 원인 판정

2026-07-05 `run_main45_verification_suite.ps1` 기준으로, 현재 작업복사본의 원인은 아래처럼 분리한다.

```text
첫 native GMTITLE 기준 객체 부재:
  현재 주원인
  근거: target-title-count=0, target-frame-count=0, status=NEXT_CREATE_FIRST_NATIVE_GMTITLE

A3/A4 native 인식 문제:
  아직 기본 workcopy에서는 시작 전
  근거: A2/A3/A4 native 기준 객체가 모두 missing

A4 frame-only 미처리:
  별도 주의 대상
  근거: 표제란 없는 도면틀 시트=2, DR_A4_Outline raw bbox 안전성은 별도 검증 필요

BATCH 자동화:
  사람이 보는 CAD 화면에서만 반복 입력을 줄이는 보조 기능
  근거: SCRIPT 실행 중에는 ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE로 멈추고 후보를 보존하는 probe 통과

잔여물/삭제 위험:
  삭제 범위를 좁히는 보호 로직 검증됨
  근거: sheet residue protection probe가 실제 주석, 작은 SW_NOTE, BOM-like insert 보존을 확인
```

따라서 이 작업복사본에서 같은 실수를 피하려면 아래 순서를 지킨다.

```text
1. 먼저 SWTITLEVERSION / SWTITLESTATUS로 현재 workcopy와 LSP 버전을 확인한다.
2. SWTITLECONVERT로 첫 native GMTITLE 기준 객체를 만든다. 현재 기본 workcopy의 첫 대상은 A2다.
3. GMTITLE 창에서는 로그가 요구한 DR_A*_Outline, DR_titlea_3rd, Frame positioning ON, Object move OFF만 허용한다.
4. 한 장이 끝나면 SWTITLESTATUS로 다음 missing exact-size native 기준 객체를 확인한다.
5. 같은 선택값이 반복되는 구간에서만 BATCH를 쓰고, 숨김/SCRIPT 자동화에는 쓰지 않는다.
6. A4는 원본에 표제란이 없으므로 A4 frame-only 단계에서 불필요한 DR_titlea_3rd가 생기면 중단한다.
```

## 목표모드 작업 단위

목표는 큰 문제 하나지만, 실제 진행은 아래 작업 단위로 끊어 판단한다.

| 작업 단위 | 해결하려는 질문 | 통과 증거 | 통과 전 금지 |
| --- | --- | --- | --- |
| 버전/도면 고정 | 지금 열린 CAD가 최신 LSP와 work 복사본을 보고 있는가 | `SWTITLEVERSION=260705-verify-source-priority`, `작업 폴더 복사본: 예` | `SWTITLECONVERT` 실행 |
| 첫 native 기준 객체 | 이 DWG 안에 실제 GMTITLE 쌍이 최소 1개 있는가 | `target-title-count > 0`, 같은 크기 `DR_A*_Outline` 기준 객체 존재 | clone/fast batch 완료 판단 |
| A3/A4 native 교체 | 겉보기 복제본이 아니라 fresh native 쌍인가 | `A3/A4 native 교체 후보: 0`, clone/shared-link 경고 0 | 도면틀 더블클릭만 보고 성공 판정 |
| A4 frame-only | 원본에 없는 제목블록 없이 도면틀만 교체됐는가 | `A4 도면틀-only 대상 수`와 예상 A4 수량 일치, 불필요한 `DR_titlea_3rd` 없음 | A4에 제목블록 생성 |
| 잔여물 보호 | 도면 내부 번호/주석/BOM/치수가 삭제되지 않았는가 | cleanup 후보 로그와 화면 확인이 일치 | cleanup 범위 확대 |
| 최종 검증 | 전체 도면 수량과 native 동작이 맞는가 | `SWTITLEVERIFY_FINAL_OK`, 대표 제목블록 더블클릭 성공 | 목표 완료 처리 |

각 작업 단위가 통과할 때만 다음 단위로 넘어간다. 한 단계가 실패하면 "다음 명령"을 추가하기보다 실패한 단위의 증거를 먼저 보강한다.

## 2026-07-04 CAD 확인 결과

`SWTITLECONVERT`에서 `OPEN`을 선택해 A3 후보 1장을 열어 보니, GMTITLE 창의 실제 기본값이 기대값과 달랐다.

```text
기대값:
  용지/도면틀: DR_A3_Outline
  제목블록: DR_titlea_3rd
  Frame positioning: ON
  Object move: OFF

실제 GMTITLE 창 기본값:
  용지/도면틀: A3 (297x420mm)
  제목블록: ISO 제목 블록 A
  Frame positioning: ON
  Object move: ON
```

따라서 현재 GstarCAD 세션에서는 자동 기본 선택을 믿으면 안 된다. 이 확인은 `-GMTITLE` 또는 기본 GMTITLE 선택을 자동화 기본값으로 승격하지 말아야 한다는 직접 증거다.

이때는 `확인`을 누르지 않고 `Esc`로 취소했다. 결과는 아래처럼 기존 쌍을 보존하는 정상 중단이었다.

```text
ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS
새 GMTITLE INSERT 생성 수: 0
기존 GMTITLE 쌍은 보존됨
SWTITLESTATUS 재확인: A3/A4 native 교체 후보 11개 유지
```

다음에 같은 단계로 들어가면, GMTITLE 창에서 아래 값이 실제로 보일 때만 진행한다.

```text
용지/도면틀: DR_A3_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

하나라도 다르면 `확인`을 누르지 않는다. 먼저 올바른 값으로 바꿀 수 있는지 확인하고, 불확실하면 취소한다.

### 같은 날 추가 확인: 키보드 선택 경로

같은 work 복사본에서 GMTITLE 창을 다시 열어 선택 방식도 비교했다.

실패한 방식:

```text
UI Automation set_value로 용지 콤보 값을 DR_A3_Outline으로 직접 설정
  -> 콤보가 읽기 전용이라 실패

UI Automation Expand/DropDown secondary action
  -> gcad.exe 요소에 secondary action이 없어 실패
```

성공한 방식:

```text
용지 콤보:
  포커스가 용지 콤보에 있을 때 Alt+Down
  목록에서 DR_A3_Outline이 보임
  DR_A3_Outline 선택 후 Enter

제목블록 콤보:
  Tab으로 제목블록 콤보로 이동
  Alt+Down
  목록에서 DR_titlea_3rd가 보임
  DR_titlea_3rd 선택 후 Enter

객체 이동:
  Alt+M으로 객체 이동 체크박스에 포커스 이동
  Space로 Object move OFF 전환
```

확인된 최종 대화상자 상태:

```text
용지/도면틀: DR_A3_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

아직 증명하지 못한 것:

```text
이 키보드 선택 경로로 확인까지 눌렀을 때 A3/A4 native 교체 후보 수가 실제로 줄어드는지
SWTITLECONVERT의 삽입점 자동 입력과 finalize가 끝까지 이어지는지
더블클릭이 GMTITLE 표 편집창으로 바뀌는지
```

따라서 이 경로는 "선택 자동화 후보"로는 유효하지만, 아직 "변환 완료 자동화"로 승격하지 않는다.

### 같은 날 추가 확인: OPEN 경로 1장 실제 성공

같은 work 복사본에서 `SWTITLECONVERT -> OPEN`을 끝까지 진행했다.

GMTITLE 창에서 확인한 값:

```text
용지/도면틀: DR_A3_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

결과 로그:

```text
UPGRADED_CLONE_TO_NATIVE_GMTITLE
Native GMTITLE aligned to 복제d frame location: moved=0, dx=0, dy=0
복사한 속성 수: 11
기존 복제 제목블록 삭제: 예
기존 복제 도면틀 삭제: 예
Remaining A3/A4 native 교체 후보: 10
```

`SWTITLESTATUS` 재확인:

```text
A3/A4 native 교체 후보: 10
A3 native-like 대상 도면틀 수: 2
A3 복제 대상 도면틀 수: 9
native-link 공유 쌍: 1
```

이 확인으로 증명된 것:

```text
OPEN 방식은 최소 1장의 A3 복제 GMTITLE을 fresh native GMTITLE로 교체할 수 있다.
LSP가 왼쪽 아래 배치점을 자동 입력했고, 위치 이동값은 dx=0, dy=0이었다.
제목블록 속성 11개가 복사됐다.
기존 복제 title/frame 쌍이 삭제됐다.
```

아직 증명하지 못한 것:

```text
남은 A3 후보 10개 전체가 같은 방식으로 모두 처리되는지
대표 A3 제목블록 더블클릭이 GMTITLE 표 편집창으로 열리는지
A4 frame-only 2장이 제목블록 없이 DR_A4_Outline만으로 안전하게 처리되는지
SWTITLEVERIFY_FINAL_OK가 나오는지
```

## 절대 기준

아래 기준을 어기면 같은 실수를 반복하게 된다.

```text
원본 DWG는 직접 편집하지 않는다.
작업은 항상 Documents\CAD tool\work 복사본에서만 한다.
화면 좌표 클릭 자동화는 기본 방식으로 쓰지 않는다.
복제 GMTITLE은 native GMTITLE로 간주하지 않는다.
도면이 겉으로 맞아 보여도 SWTITLEVERIFY_FINAL_OK 전에는 완료가 아니다.
```

공개 사용 명령은 아래 네 개로 유지한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

보조 확인 명령은 아래 두 개만 일반 사용에 노출한다.

```text
SWTITLEVERSION
SWSCALESCAN
```

## 문제를 나누는 방식

한 번에 모든 문제를 고치려고 하면 판단이 흐려진다. 항상 아래 네 종류로 먼저 나눈다.

| 종류 | 의미 | 판단 증거 | 다음 행동 |
| --- | --- | --- | --- |
| 버전/도면 문제 | CAD가 최신 LSP나 work 복사본을 보고 있지 않음 | `SWTITLEVERSION` 불일치, DWG 경로가 `work`가 아님 | APPLOAD 후 다시 상태 확인 |
| native 구조 문제 | 겉모양은 맞지만 복제/shared-link라 GMTITLE 인식이 불확실함 | `A3/A4 native 교체 후보`, `복제`, `shared-native-link-handle` | `SWTITLECONVERT`로 한 장씩 fresh native 교체 |
| A4 frame-only 문제 | 원본 A4에는 표제란이 없고 도면틀만 있음 | `표제란 없는 도면틀 시트`, `A4 대상 도면틀 누락` | A3/A4 native 교체 뒤 A4 도면틀-only 처리 |
| 잔여물/오염 문제 | 실수 텍스트, 겹친 target, raw bbox 위험, 도면틀 정의 오염 | `SWTITLESTATUS`의 prepare/위험 안내 | 변환 반복 금지, `SWTITLEPREPARE` 또는 원인 분석 |

## 목표모드 실행 순서

### 1단계: 증거 잠금

가장 먼저 현재 CAD 세션이 맞는지 확인한다.

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
SWTITLEVERSION
SWTITLESTATUS
```

통과 기준:

```text
SWTITLEVERSION:
260705-verify-source-priority

DWG 파일:
C:\Users\DR-DESIGN\Documents\CAD tool\work\...

작업 폴더 복사본:
예
```

통과하지 못하면 `SWTITLECONVERT`를 실행하지 않는다.

### 2단계: 상태 분류

`SWTITLESTATUS` 결과를 보고 아래 중 하나로 분류한다.

```text
NEXT_CREATE_FIRST_NATIVE_GMTITLE
  -> 아직 이 도면 안에 실제 GstarCAD native GMTITLE 기준 객체가 없다.
  -> 다음 명령은 SWTITLECONVERT.

NEXT_UPGRADE_A3_A4_NATIVE
  -> A3/A4 복제 또는 shared-link 쌍을 fresh native GMTITLE로 교체해야 한다.
  -> 다음 명령은 SWTITLECONVERT.

NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX
  -> 도면틀 정의 자체가 위험하다.
  -> 변환 반복 금지. 먼저 도면틀 정의 분석.

SWTITLEPREPARE 안내
  -> 실수 텍스트, 겹침, 오염, 정규화 후보가 있다.
  -> SWTITLEPREPARE 뒤 다시 SWTITLESTATUS.

표제란 없는 A4 시트 안내
  -> A4 frame-only 처리 단계다.
  -> A3/A4 native 교체 후보가 남아 있으면 A3/A4가 먼저다.

SWTITLEVERIFY 안내
  -> 변환 후보가 없으므로 최종 검증 단계다.
```

### 3단계: A3/A4 native 교체

현재 작업복사본의 다음 실제 작업은 이 단계다.

```text
SWTITLECONVERT
```

`SWTITLECONVERT`가 선택지를 물으면 기본은 `OPEN`이다.

```text
OPEN
  다음 후보 1장만 처리한다.

MANUAL
  OPEN이 계속 새 GMTITLE 객체를 못 잡을 때 쓰는 복구 경로다.
  이번 후보의 기존 값과 왼쪽 아래 기준점을 저장한다.
  GstarCAD GMTITLE로 안내된 한 장을 만든다.
  삽입점은 긴 소수점 좌표를 직접 치지 말고 기존 도면틀 왼쪽 아래 끝점/스냅으로 지정한다.
  그 뒤 SWTITLECONVERT를 다시 실행하면 마무리한다.

BATCH
  여러 장을 이어서 처리한다.
  단, 연속 처리 전에 OPEN으로 최소 1장 성공 증거를 먼저 확보한다.
  각 GMTITLE 창 선택은 사람이 눈으로 확인한다.
  ISO 기본값, Object move ON, 예상과 다른 DR 용지가 보이면 즉시 취소한다.

Enter
  중단한다. 도면을 바꾸지 않는다.
```

GMTITLE 창에서 확인할 값:

```text
용지/도면틀:
로그가 요구한 DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 하나

제목블록:
DR_titlea_3rd

Frame positioning:
ON

Object move:
OFF
```

중요한 점:

```text
실제 CAD 확인상 기본값은 A3 (297x420mm) / ISO 제목 블록 A / Object move ON으로 뜰 수 있다.
이 상태에서 확인을 누르면 목표와 다른 도면틀/제목블록이 생성될 수 있다.
소수점 좌표를 사람이 직접 입력하지 않는다.
SWTITLECONVERT가 GMTITLE 이후 왼쪽 아래 기준점을 자동으로 보낸다.
Object move는 OFF여야 도면 내부 형상이 움직이지 않는다.
```

처리 뒤 반드시 다시 확인한다.

```text
SWTITLESTATUS
```

성공 판단:

```text
A3/A4 native 교체 후보 수가 줄어든다.
방금 처리한 쌍의 role이 복제에서 native-upgrade 또는 native-like로 바뀐다.
새로운 raw bbox, 겹침, 선택 위험이 생기지 않는다.
```

후보 수가 줄지 않으면 같은 명령을 반복하지 않는다. 최신 `swcad_title_native_frame_check_last.txt`와 `swcad_title_next_step_last.txt`를 보고 원인을 먼저 분류한다.

특히 `ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS`가 반복되면, `OPEN` 자동 흐름이 GstarCAD가 만든 INSERT를 잡지 못한 것이다. 이때는 다음 후보에서 `MANUAL`을 선택해 pending prepare를 만들고, GstarCAD `GMTITLE`로 안내된 DR 용지/제목블록을 한 장 만든 뒤 `SWTITLECONVERT`를 다시 실행한다. 이때 삽입점은 긴 좌표를 치지 말고 기존 도면틀 왼쪽 아래 끝점/스냅으로 지정한다. 다시 실행된 `SWTITLECONVERT`는 일반 상태 분류보다 pending finish를 먼저 수행한다.

### 4단계: A4 frame-only 처리

A3/A4 native 교체 후보가 0이 된 뒤 A4를 처리한다.

A4는 원본에 표제란이 없는 시트가 있을 수 있다. 따라서 A4에 `DR_titlea_3rd`가 생기면 성공이 아니라 잘못된 추가일 수 있다.

기대 결과:

```text
DR_A4_Outline 도면틀이 필요한 수량만큼 생김
A4 위치에 불필요한 DR_titlea_3rd 제목블록이 생기지 않음
기존 A4 도면 내용이나 빈 도면틀이 삭제되지 않음
도면 밖의 이상한 선/블록이 딸려오지 않음
```

처리 뒤 확인:

```text
SWTITLESTATUS
SWTITLEVERIFY
```

멈춤 조건:

```text
DR_A4_Outline raw bbox 위험
A4에 불필요한 제목블록 생성
A4 도면이 삭제됨
A4 수량이 원본 기준과 맞지 않음
```

이 경우 새 변환을 반복하지 말고 work 복사본을 보존한 상태에서 원인 로그를 먼저 본다.

### 5단계: 최종 검증

아래 명령을 실행한다.

```text
SWTITLEVERIFY
```

완료 후보가 되려면 모두 만족해야 한다.

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
target A2: 1
target A3: 12
target A4: 2
A3/A4 native 교체 필요 쌍: 0
native-like가 아닌 대상 쌍: 0
겹친 target 쌍: 0
도면틀 raw bbox 위험: 0
```

그 뒤 실제 CAD 화면에서 확인한다.

```text
대표 A2 제목블록 더블클릭 -> GMTITLE 표 편집창
대표 A3 제목블록 더블클릭 -> GMTITLE 표 편집창
A4 frame-only -> 제목블록 없이 도면틀만 정상
빨간 네모로 표시했던 도면 내부 번호/주석/치수/BOM 유지
```

## 자동화 개선 계획

자동화는 한 번에 바로 켜지 않는다. 아래 순서로 승격한다.

### 자동화 1단계: 안내 자동화

현재 기본 상태다.

```text
SWTITLESTATUS가 다음 후보와 필요한 DR 용지를 안내한다.
SWTITLEVERIFY가 왜 완료가 아닌지 설명한다.
SWTITLECONVERT가 좌표 계산과 기존 값 복사를 처리한다.
```

### 자동화 2단계: 배치 보조

목표:

```text
명령어를 여러 번 다시 치는 반복을 줄인다.
```

방법:

```text
SWTITLECONVERT 안의 OPEN/BATCH 흐름을 사용한다.
OPEN 성공 뒤 BATCH로 여러 후보를 이어서 처리한다.
OPEN이 `NO_INSERTS`로 반복되면 MANUAL prepare/finish 복구 흐름을 사용한다.
각 GMTITLE 창의 DR 선택은 사람이 눈으로 확인한다.
SCRIPT/숨김 CAD 자동화에서는 BATCH가 ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE로 멈추고 후보를 보존해야 한다.
SWTITLECONVERT 자체도 SCRIPT/숨김 CAD 자동화에서는 ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE로 멈추고 원본/대상/INSERT/DBMOD를 보존해야 한다.
```

승격 조건:

```text
OPEN으로 1장 성공
후보 수 감소 확인
잘못된 새 INSERT 자동 제거 확인
도면 내부 형상 이동 없음
```

### 자동화 3단계: native 생성 자동화 실험

목표:

```text
GMTITLE 창의 DR_A*_Outline / DR_titlea_3rd 선택까지 자동화할 수 있는지 검증한다.
```

아직 기본값으로 켜지 않는 이유:

```text
과거 명령줄 -GMTITLE 자동 선택이 일반 A3/A4 또는 ISO 흐름으로 잘못 간 이력이 있다.
PaperSet.ini/dat와 HKCU 설정에서 DR_A*_Outline / DR_titlea_3rd 기본 선택값을 고정하는 근거를 찾지 못했다.
GstarCAD native 구조는 paperset.grx 같은 내부 Mechanical 모듈이 만드는 것으로 보이며, LISP 복사만으로 완전 재현되지 않는다.
```

실험 조건:

```text
work 복사본에서만 실행
실패 시 새 INSERT rollback 가능
A2 1회, A3 1회, A4 frame-only 1회, 반복 A3 3회 검증
SWTITLEVERIFY와 더블클릭 결과까지 확인
```

승격 기준:

```text
요청한 DR_A*_Outline이 정확히 들어감
DR_titlea_3rd가 필요한 시트에만 들어감
A4 frame-only에는 불필요한 제목블록이 생기지 않음
shared-native-link-handle이 생기지 않음
SWTITLEVERIFY_FINAL_OK로 이어짐
```

하나라도 실패하면 자동 선택은 기본 흐름으로 승격하지 않는다.

### 자동화 4단계: 완전 자동화 승격 후보

장기적으로 사람이 확인하는 단계를 줄이려면, 아래 증거가 추가로 필요하다.

```text
1. GMTITLE 창 선택값을 화면 좌표가 아니라 UI 상태/명령 응답/생성 INSERT 검증으로 확인할 수 있음
2. 잘못된 ISO 용지/제목블록이 생성되면 즉시 감지하고 새 INSERT를 제거할 수 있음
3. DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 각각에서 같은 검증이 반복 성공함
4. A4 frame-only는 제목블록 없이 도면틀만 들어오는 경로가 별도 검증됨
5. 자동 흐름 뒤 `SWTITLEVERIFY_FINAL_OK`와 대표 더블클릭 확인이 모두 통과함
```

이 조건을 만족하기 전까지는 "사람이 DR 용지와 DR_titlea_3rd를 눈으로 확인하는 단계"를 제거하지 않는다. 자동화는 먼저 안내, 좌표 입력, 값 복사, 잔여물 제거, 잘못된 결과 rollback 쪽을 강화한다.

## 중단 규칙

아래 상황에서는 같은 명령을 반복하지 않는다.

```text
후보 수가 줄지 않음
새 target 쌍이 겹침
raw bbox 위험 발생
A4에 제목블록이 새로 생김
도면 내부 형상이 움직임
SWTITLEVERSION이 기대 버전과 다름
현재 DWG가 work 복사본이 아님
```

중단 후 할 일:

```text
SWTITLESTATUS 실행
SWTITLEVERIFY 실행
work\swcad_title_next_step_last.txt 확인
work\swcad_title_native_frame_check_last.txt 확인
원인을 native 구조, A4 frame-only, 잔여물/오염, 버전/도면 문제 중 하나로 분류
```

## Codex가 CAD를 조작할 때의 안전 규칙

CAD 조작이 필요할 때도 아래 규칙을 지킨다.

```text
전체화면/최대화 상태를 유지한다.
스크린샷 좌표 클릭으로 DR 용지를 고르지 않는다.
CAD 명령줄에는 붙여넣기보다 키 입력을 우선한다.
_pasteclip 상태가 보이면 ESC로 빠져나온 뒤 다시 시작한다.
긴 명령이나 파일 경로를 한 번에 붙여넣지 않는다. CAD가 이를 _pasteclip 삽입으로 해석할 수 있다.
work 복사본을 열 때도 제목 표시줄과 활성 도면 탭이 목표 DWG인지 다시 확인한다.
여러 도면 탭이 열려 있으면 SWTITLESTATUS가 다른 탭에서 실행될 수 있으므로 변환 전 활성 탭을 확인한다.
APPLOAD, SWTITLEVERSION, SWTITLESTATUS로 버전을 먼저 확인한다.
GMTITLE 창 선택이 불확실하면 진행하지 않고 ESC로 중단한다.
```

Codex가 테스트할 때도 완료 판단은 화면만 보지 않고 최신 로그로 한다.

## 다음 실제 작업

현재 work 복사본 기준 다음 행동은 아래 순서다.

```text
1. APPLOAD로 C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp 로드
2. SWTITLEVERSION으로 gmtitle 버전이 260705-verify-source-priority인지 확인
3. SWTITLESTATUS로 현재 상태 확인
4. 기본 workcopy라면 NEXT_CREATE_FIRST_NATIVE_GMTITLE인지 확인
5. SWTITLECONVERT 실행
6. 첫 GMTITLE 창에서 로그가 요구한 용지를 선택한다. 현재 기본 workcopy의 첫 대상은 DR_A2_Outline이다.
7. 제목블록은 DR_titlea_3rd, Frame positioning은 ON, Object move는 OFF로 확인
8. 변환이 끝나면 SWTITLESTATUS 실행
9. 다음 missing exact-size native 기준 객체가 있으면 SWTITLECONVERT로 한 장씩 만든다.
10. 같은 선택값이 반복되는 A3 후보 구간에서만 BATCH를 사용한다.
11. BATCH도 각 GMTITLE 창 선택을 대신하지 않으므로 DR 용지/제목블록/옵션을 눈으로 확인한다.
12. A4 frame-only 단계에서는 원본에 없는 DR_titlea_3rd가 생기면 중단한다.
13. SWTITLEVERIFY_FINAL_OK와 대표 더블클릭 확인
```

과거 중간 workcopy에서 A3 후보만 남았던 경우에는 아래 순서가 적용됐다. 현재 기본 workcopy가 이 상태가 아니라면 그대로 따라 하지 않는다.

```text
1. SWTITLEVERSION으로 현재 기준 버전 확인
2. SWTITLESTATUS로 현재 후보 수 확인
3. SWTITLECONVERT 실행
4. OPEN 선택
5. GMTITLE 창에서 DR_A3_Outline / DR_titlea_3rd / Frame positioning ON / Object move OFF 확인
6. 변환이 끝나면 SWTITLESTATUS 실행
7. A3/A4 native 교체 후보가 11에서 줄었는지 확인
8. 후보 수가 줄지 않고 `NO_INSERTS`가 반복되면 다음에는 SWTITLECONVERT에서 MANUAL 선택
9. MANUAL 안내값으로 GstarCAD GMTITLE 한 장 생성, 삽입점은 기존 도면틀 왼쪽 아래 끝점/스냅 사용
10. SWTITLECONVERT 재실행으로 pending finish 수행
11. 줄었으면 같은 방식으로 다음 후보 진행
12. A3/A4 후보가 0이 된 뒤 A4 frame-only 처리
13. SWTITLEVERIFY_FINAL_OK와 대표 더블클릭 확인
```

이 순서에서 한 단계라도 증거가 맞지 않으면 다음 단계로 가지 않는다.
