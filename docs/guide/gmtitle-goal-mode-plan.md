# GMTITLE 목표모드 상세 계획

이 문서는 SolidWorks DWG를 GstarCAD Mechanical native GMTITLE 구조로 안정 변환하기 위한 목표모드 실행 기준이다.

목표는 명령어를 계속 늘리는 것이 아니다. 목표는 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 흐름 안에서 사람이 반복 선택하는 일을 줄이되, GstarCAD native GMTITLE 인식이 깨지지 않게 만드는 것이다.

## 현재 기준 상태

현재 믿을 수 있는 기준은 최신 CAD 로그와 work 복사본이다.

```text
LSP 기준:
260704-manual-native-finish

작업 도면:
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125 CP_ALL_260704_test.dwg

SWTITLESTATUS 결과:
NEXT_UPGRADE_A3_A4_NATIVE

SWTITLEVERIFY 결과:
SWTITLEVERIFY_FINAL_FAIL

현재 남은 핵심 문제:
  A3/A4 native 교체 후보: 11
  A4 대상 도면틀 누락: 필요 2, 현재 0
  남은 원본 도면틀: 2
  남은 원본 표제란: 0
```

이 상태는 변환 완료가 아니다. A4가 누락되어 있어도, 현재 우선순위는 A3/A4 native 교체 후보를 먼저 줄이는 것이다.

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
260704-manual-native-finish

DWG 파일:
C:\Users\DR-DESIGN\Documents\CAD tool\work\...

작업 폴더 복사본:
예
```

통과하지 못하면 `SWTITLECONVERT`를 실행하지 않는다.

### 2단계: 상태 분류

`SWTITLESTATUS` 결과를 보고 아래 중 하나로 분류한다.

```text
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
  이번 후보의 기존 값과 왼쪽 아래 삽입점을 저장한다.
  GstarCAD GMTITLE로 안내된 한 장을 만든 뒤 SWTITLECONVERT를 다시 실행하면 마무리한다.

BATCH
  여러 장을 이어서 처리한다.
  단, 연속 처리 전에 OPEN으로 최소 1장 성공 증거를 먼저 확보한다.

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

특히 `ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS`가 반복되면, `OPEN` 자동 흐름이 GstarCAD가 만든 INSERT를 잡지 못한 것이다. 이때는 다음 후보에서 `MANUAL`을 선택해 pending prepare를 만들고, GstarCAD `GMTITLE`로 안내된 DR 용지/제목블록을 한 장 만든 뒤 `SWTITLECONVERT`를 다시 실행한다. 다시 실행된 `SWTITLECONVERT`는 일반 상태 분류보다 pending finish를 먼저 수행한다.

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
APPLOAD, SWTITLEVERSION, SWTITLESTATUS로 버전을 먼저 확인한다.
GMTITLE 창 선택이 불확실하면 진행하지 않고 ESC로 중단한다.
```

Codex가 테스트할 때도 완료 판단은 화면만 보지 않고 최신 로그로 한다.

## 다음 실제 작업

현재 work 복사본 기준 다음 행동은 아래 순서다.

```text
1. SWTITLEVERSION으로 main66 이상 확인
2. SWTITLESTATUS로 현재 후보 수 확인
3. SWTITLECONVERT 실행
4. OPEN 선택
5. GMTITLE 창에서 DR_A3_Outline / DR_titlea_3rd / Frame positioning ON / Object move OFF 확인
6. 변환이 끝나면 SWTITLESTATUS 실행
7. A3/A4 native 교체 후보가 11에서 줄었는지 확인
8. 후보 수가 줄지 않고 `NO_INSERTS`가 반복되면 다음에는 SWTITLECONVERT에서 MANUAL 선택
9. MANUAL 안내값으로 GstarCAD GMTITLE 한 장 생성
10. SWTITLECONVERT 재실행으로 pending finish 수행
11. 줄었으면 같은 방식으로 다음 후보 진행
12. A3/A4 후보가 0이 된 뒤 A4 frame-only 처리
13. SWTITLEVERIFY_FINAL_OK와 대표 더블클릭 확인
```

이 순서에서 한 단계라도 증거가 맞지 않으면 다음 단계로 가지 않는다.
