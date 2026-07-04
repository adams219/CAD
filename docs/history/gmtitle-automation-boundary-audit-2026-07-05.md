# GMTITLE Automation Boundary Audit - 2026-07-05

## 목적

목표는 사용자가 같은 GMTITLE 선택을 계속 반복하지 않게 만드는 것이다.

다만 과거 테스트에서 GstarCAD GMTITLE 창이 일반 A3/A4, ISO 제목블록, `Object move ON` 같은 잘못된 기본값으로 열릴 수 있음이 확인됐다.

따라서 현재 자동화 방향은 아래처럼 나눈다.

```text
자동화할 것:
  시트 탐지
  기존 값 추출
  왼쪽 아래 배치점 계산
  새 GMTITLE 결과 검사
  값 복사
  기존 복제/원본 삭제
  검증 로그 출력

사람이 확인할 것:
  GMTITLE 창에서 DR_A*_Outline 선택
  DR_titlea_3rd 선택
  Frame positioning ON
  Object move OFF
```

## 목표 모드 운영 계획

이 목표는 단순히 "눈으로 봤을 때 비슷한 도면"을 만드는 것이 아니다.

최종 목표는 SolidWorks에서 넘어온 DWG를 GstarCAD Mechanical의 native GMTITLE 구조로 바꾸고, 같은 종류의 도면을 반복 처리할 수 있는 안전한 흐름을 만드는 것이다.

따라서 각 단계는 다음 증거가 있어야 다음 단계로 넘어간다.

### 0단계. 현재 상태 고정

목적:

```text
지금 보고 있는 CAD 화면, 저장된 DWG, 숨김 probe 결과가 같은 상태인지 확인한다.
```

실행:

```text
SWTITLEVERSION
SWTITLESTATUS
```

확인할 것:

```text
현재 LSP 버전
DWG 경로가 Documents/CAD tool/work 아래인지
DWG 저장 상태가 DBMOD=0인지
원본 표제란 수량
원본 도면틀 수량
A2/A3/A4별 수량
target GMTITLE 도면틀/제목블록 수량
다음 조치 문구
```

중단 기준:

```text
Downloads 또는 원본 폴더 DWG를 열고 있으면 중단
DBMOD가 0이 아닌데 숨김 probe와 비교하려 하면 중단
SWTITLEVERSION이 기대 버전과 다르면 중단
```

### 1단계. A3 도면틀 구조 분석

사용자가 본 핵심 문제:

```text
A3 제목블록은 더블클릭 시 GMTITLE 표 편집창이 열리지만,
A3 도면틀은 아직 블록처럼 보인다.
또 일부 A3에서는 도면틀과 제목블록이 하나로 합쳐진 것처럼 보인다.
```

판단해야 할 것:

```text
이 현상이 설치 원본 DR_A3_Outline 자체의 native-format 내부 형상인지
SolidWorks 원본 도면틀이 섞인 오염인지
변환 중 잘못 만든 중복 target인지
단순히 도면틀 INSERT를 선택해서 생긴 정상 동작인지
```

증거:

```text
SWTITLESTATUS의 도면틀 정의 분류
SWTITLEPREPARE가 안내하는 정규화 필요 여부
SWTITLEVERIFY의 native 교체 후보 수
대표 A3 제목블록 더블클릭 결과
대표 A3 도면틀 선택 시 나오는 편집 동작
```

중요한 원칙:

```text
도면틀 안에 표제란처럼 보이는 선이 있다고 바로 삭제하지 않는다.
먼저 native-format-with-title-geometry와 source-contaminated를 분리한다.
빨간 네모로 표시된 실제 도면 주석, 번호, BOM, 노트는 잔여물 삭제 후보가 아니다.
```

### 2단계. 첫 native GMTITLE 기준 객체 만들기

목적:

```text
복제 기준이 될 진짜 native GMTITLE 쌍을 용지 크기별로 확보한다.
```

실행 흐름:

```text
SWTITLESTATUS
SWTITLECONVERT
OPEN
```

GMTITLE 창에서 확인:

```text
용지: SWTITLESTATUS가 안내한 DR_A*_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

성공 증거:

```text
SWTITLESTATUS에서 해당 크기 native 기준 객체가 yes
남은 원본 시트 수량이 1장 줄어듦
새 DR_titlea_3rd 속성값이 기존 표제란 값으로 채워짐
기존 원본 표제란/도면틀 쌍이 정리됨
도면 내부 형상은 움직이지 않음
```

실패 시 원칙:

```text
잘못 선택한 GMTITLE은 새 객체만 제거하고 기존 원본 쌍은 보존한다.
삭제 범위를 넓히는 방식으로 보정하지 않는다.
같은 실패가 반복되면 SWTITLESTATUS/SWTITLEVERIFY 로그부터 비교한다.
```

### 3단계. 여러 장 처리 검증

목적:

```text
한 장씩 처리해야 하는 반복을 줄이되, 잘못된 자동화를 밀어붙이지 않는다.
```

실행:

```text
SWTITLECONVERT
BATCH
```

권장 검증:

```text
처음에는 2~3장만 처리
각 GMTITLE 창에서 DR 용지/제목블록/옵션 확인
처리 후 SWTITLESTATUS 실행
문제가 없으면 저장
저장 후 숨김 probe 또는 SWTITLEVERIFY로 다시 확인
```

중단 기준:

```text
일반 A3/A4가 선택됨
ISO 제목블록이 선택됨
Object move가 ON으로 켜져 있음
도면 내부 형상이 이동함
빨간 네모처럼 실제 도면 내용이 삭제됨
SWTITLESTATUS가 native 교체 후보 또는 중복 target을 경고함
```

### 4단계. A4 frame-only 별도 처리

A4는 A2/A3와 다르다.

현재 도면에서 A4는 표제란이 없는 frame-only 시트로 감지된다.

따라서 A4 완료 기준은 다음 중 하나로 분리해야 한다.

```text
정책 A: A4는 도면틀만 native GMTITLE frame으로 교체하고 제목블록은 만들지 않는다.
정책 B: A4에도 DR_titlea_3rd 제목블록을 붙이는 것이 업무 기준이다.
```

현재까지의 증거는 정책 A에 가깝다.

다만 설치 원본 `DR_A4_Outline` 직접 import는 안전하지 않았다.

A4 진행 전 필요한 증거:

```text
정상 native A4 기준 객체가 있음
DR_A4_Outline bbox가 210 x 297 또는 기대 위치와 일치
틀 밖에 딸려오는 잔여 객체가 없음
frame-only 변환 후 원본 A4 2장이 보존 또는 정확히 교체됨
```

중단 기준:

```text
DR_A4_Outline raw bbox가 비정상적으로 큼
원본 A4에는 없던 표제란/선/문자가 같이 딸려옴
A4 한 장만 바뀌고 나머지가 남음
A4 source frame이 삭제됐는데 target A4가 2장이 아님
```

### 5단계. 최종 완료 검증

최종 검증은 다음 순서로 한다.

```text
SWTITLESTATUS
SWTITLEVERIFY
DWG 저장
run_final_completion_gate.ps1
대표 A2/A3/A4 제목블록 더블클릭 확인
```

완료 증거:

```text
SWTITLEVERIFY_FINAL_OK
source-title-count: 0
source-frame-count: 0
frame-only-count: 0
target A2: 1
target A3: 12
target A4: 2
A3/A4 native 교체 후보: 0
중복 target: 0
고아 title/frame: 0
실제 도면 주석/번호/BOM/노트 보존
대표 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창
DBMOD=0 저장본과 숨김 probe 결과 일치
```

아직 이 완료 증거는 확보되지 않았다.

## 반복 실수 방지 규칙

앞으로 같은 실수를 줄이기 위해 다음 규칙을 따른다.

```text
1. 새 명령어를 만들기 전에 SWTITLESTATUS의 다음 조치가 맞는지 먼저 본다.
2. A2/A3/A4 전용 공개 명령을 다시 늘리지 않는다.
3. 화면 좌표 클릭으로 GMTITLE 창을 고르지 않는다.
4. 도면틀에 표제란처럼 보이는 선이 있다고 바로 삭제하지 않는다.
5. A4는 A2/A3와 같은 방식으로 밀어붙이지 않는다.
6. probe 결과와 화면 결과가 다르면 먼저 저장 상태 DBMOD를 확인한다.
7. 빨간 네모로 사용자가 표시한 실제 도면 내용은 삭제 후보가 아니라 보호 후보로 본다.
8. 최종 완료는 SWTITLEVERIFY_FINAL_OK와 더블클릭 확인 전에는 선언하지 않는다.
```

## 현재 코드가 이미 줄인 반복

### 1. 좌표 직접 입력 제거

`SWTITLECONVERT`의 native 교체 흐름은 기존 도면틀 bbox에서 왼쪽 아래 배치점을 계산한다.

관련 흐름:

```text
swcad-title-bbox-lower-left-point
swcad-title-upgrade-native-one
swcad-title-upgrade-native-a3a4-prepare
swcad-title-transfer-frame-only-apply
```

사용자가 긴 소수점 좌표를 직접 입력하는 방식은 기본 경로가 아니다.

### 2. 한 장 처리와 여러 장 처리 분리

`SWTITLECONVERT`의 A3/A4 native 교체 선택지는 다음 세 가지다.

```text
OPEN
MANUAL
BATCH
```

의미:

```text
OPEN:
  다음 후보 1장만 처리한다.
  처음 한 장 검증용 기본 선택이다.

MANUAL:
  OPEN이 새 GMTITLE 객체를 못 잡을 때 사용한다.
  대상/값/왼쪽 아래 기준점만 저장하고, 사용자가 GMTITLE 한 장을 만든 뒤 SWTITLECONVERT 재실행으로 마무리한다.

BATCH:
  처리 수량을 입력하고 여러 후보를 이어서 처리한다.
  명령 반복은 줄지만, 각 GMTITLE 창의 선택값 확인은 여전히 사람이 해야 한다.
```

### 3. 잘못 만든 GMTITLE은 기존 쌍을 보존

새로 만든 GMTITLE이 기대한 `DR_A*_Outline` 또는 `DR_titlea_3rd`가 아니면 새 객체를 삭제하고 기존 쌍을 보존한다.

관련 상태:

```text
ABORT_NATIVE_UPGRADE_WRONG_GMTITLE_SELECTION
ABORT_NATIVE_UPGRADE_INVALID_FRAME_GEOMETRY
ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS
```

이 때문에 사용자가 GMTITLE 창에서 실수해도 기존 복제 쌍을 바로 잃지 않는다.

### 4. 저장 상태 혼선 표시

버전 `260705-save-state-warning`부터 통합 명령은 `DBMOD`를 출력한다.

```text
DWG 저장 상태: 저장됨 (DBMOD=0)
DWG 저장 상태: 저장되지 않은 변경 있음 (DBMOD=...)
```

이 출력은 숨김 probe가 마지막 저장본을 다시 열기 때문에 현재 화면과 결과가 다르게 보일 수 있는 문제를 줄인다.

## 아직 자동화하지 않는 이유

### 1. `-GMTITLE` 명령줄 선택은 신뢰 부족

코드에는 명령줄 `-GMTITLE` 우선 시도 경로가 있지만, 과거 CAD 테스트에서 원하는 DR 용지/제목블록으로 안정 선택되는지 충분히 증명되지 않았다.

관련 흐름:

```text
swcad-title-run-native-gmtitle-commandline
swcad-title-run-native-gmtitle-prefer-commandline
```

명령줄 결과가 유효하지 않으면 대화식 GMTITLE로 fallback한다.

### 2. 화면 좌표 클릭 자동화는 제외

화면 좌표와 스크린샷 기반 클릭은 모니터 배치, 창 크기, 리본 상태, 대화상자 위치에 민감하다.

이 방식은 단기 테스트에는 가능하지만 여러 장 업무 도면 변환의 기본 방식으로 쓰지 않는다.

### 3. GMTITLE 창 기본값이 위험하다

기록된 위험:

```text
일반 A3/A4로 열림
ISO 제목블록으로 열림
Object move ON으로 열림
```

특히 `Object move ON` 상태에서 확인하면 도면 내부 형상이 움직일 수 있다.

따라서 현재는 창 선택값을 사람이 눈으로 확인하는 것이 더 안전하다.

## 현재 추천 사용 흐름

### 첫 검증

```text
SWTITLESTATUS
SWTITLECONVERT
OPEN
GMTITLE 창 확인:
  DR_A*_Outline
  DR_titlea_3rd
  Frame positioning ON
  Object move OFF
SWTITLESTATUS
```

한 장 성공 후 후보 수가 줄면 같은 방식이 맞다.

### 반복 줄이기

한 장 성공이 확인된 뒤:

```text
SWTITLECONVERT
BATCH
```

BATCH는 여러 장을 이어서 처리한다.

다만 각 GMTITLE 창에서 DR 용지/제목블록/옵션은 계속 확인한다.

### OPEN이 계속 실패할 때

```text
SWTITLECONVERT
MANUAL
GstarCAD GMTITLE로 안내된 한 장 생성
삽입점은 기존 도면틀 왼쪽 아래 끝점/스냅
SWTITLECONVERT
```

다시 실행한 `SWTITLECONVERT`가 pending finish를 먼저 처리한다.

## A4와의 관계

A4 frame-only는 별도 문제다.

현재 증거:

```text
설치 원본 DR_A4_Outline 직접 import: unsafe
단순 삭제식 정규화: unsafe
저장된 기본 workcopy 안 native A4 exemplar: missing
```

따라서 A4는 BATCH로 밀어붙이지 않는다.

먼저 정상 native A4 기준 객체 또는 깨끗한 outline-only 기준 객체가 필요하다.

## 다음 구현 방향

현재 기준에서 더 줄일 수 있는 반복은 다음 순서로만 검증한다.

1. 같은 작업복사본에서 `OPEN`으로 1장 성공 증거를 확보한다.
2. `BATCH`로 2~3장만 연속 처리해 실패 시 기존 쌍이 보존되는지 확인한다.
3. `BATCH`가 안정적이면 기본 안내 문구를 `OPEN 검증 후 BATCH 사용`으로 유지한다.
4. 명령줄 `-GMTITLE` 자동 선택은 별도 scratch DWG에서 DR 용지/제목블록 선택 재현성이 증명될 때만 확대한다.
5. 화면 좌표 클릭 자동화는 기본 변환 경로에 넣지 않는다.

## 완료 기준

이 자동화 경계가 맞다는 최종 증거는 다음이다.

```text
A3/A4 native 교체 후보: 0
A4 frame-only 정상 처리
SWTITLEVERIFY_FINAL_OK
대표 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창
DBMOD=0 저장본에서 숨김 probe와 열린 CAD 상태 일치
```

아직 이 조건은 충족되지 않았다.
