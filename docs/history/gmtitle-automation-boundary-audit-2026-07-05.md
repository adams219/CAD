# GMTITLE 자동화 경계 감사 - 2026-07-05

## 목적

목표는 SolidWorks에서 나온 DWG를 GstarCAD Mechanical native GMTITLE 구조로 안정 변환하는 것이다.

명령어를 계속 늘리는 것이 목표가 아니다. 같은 종류의 도면 여러 장을 처리할 수 있는 안전한 흐름을 만들고, 사람이 반복해야 하는 선택을 줄이되, GstarCAD가 native GMTITLE로 인식하는 구조는 깨지지 않아야 한다.

## 현재 자동화 경계

현재 증거상 GstarCAD GMTITLE 창은 일반 A3/A4, ISO 제목블록, `Object move ON` 같은 잘못된 기본값으로 열릴 수 있다.

따라서 자동화 역할을 다음처럼 나눈다.

```text
LSP가 자동 처리하는 것:
  시트 탐지
  기존 표제란 값 추출
  DR_titlea_3rd 속성값 매핑
  왼쪽 아래 배치점 계산
  새 GMTITLE 결과 검사
  기존 SolidWorks 원본 도면틀/표제란/허용된 잔여물 삭제
  SWTITLESTATUS/SWTITLEVERIFY 로그 출력

사람이 확인하는 것:
  GMTITLE 창의 DR_A*_Outline 선택
  GMTITLE 창의 DR_titlea_3rd 선택
  Frame positioning ON
  Object move OFF
```

이 사람 확인 단계는 자동화가 불가능해서 남긴 것이 아니라, 잘못된 native 객체를 대량 생성하지 않기 위한 안전장치다.

## 목표모드 운영 계획

### 0단계. 현재 상태 잠금

목적:

```text
지금 보고 있는 CAD 화면, 저장된 DWG, probe 결과가 같은 상태인지 확인한다.
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
원본 표제란 수량
원본 도면틀 수량
A2/A3/A4별 수량
target GMTITLE 도면틀/제목블록 수량
다음 조치 문구
```

중단 기준:

```text
Downloads 또는 원본 폴더 DWG를 열고 있으면 중단
SWTITLEVERSION이 기대 버전과 다르면 중단
로그 DWG 경로가 현재 열린 도면과 다르면 중단
```

### 1단계. A3 도면틀 구조 판단

사용자가 본 문제:

```text
A3 제목블록은 더블클릭 시 GMTITLE 표 편집창이 열리지만,
A3 도면틀은 아직 블록처럼 보인다.
또 어떤 A3에서는 도면틀과 제목블록이 하나로 합쳐진 블록처럼 보인다.
```

판단해야 할 것:

```text
이것이 native DR_A3_Outline 자체의 정상 표현인지
SolidWorks 원본 도면틀이 남아 앞에 겹친 것인지
변환 중 잘못 만들어진 중복 target인지
단순히 도면틀 INSERT를 선택해서 생긴 정상 동작인지
```

중요 원칙:

```text
DR_A3_Outline 도면틀은 native GMTITLE에서도 INSERT/block 참조로 보일 수 있다.
A3 완료 판단은 도면틀 더블클릭이 아니라 짝 DR_titlea_3rd 제목블록 더블클릭 표 편집창과 SWTITLEVERIFY 결과로 한다.
도면틀 안에 제목블록처럼 보이는 선이 있다고 바로 삭제하지 않는다.
```

### 2단계. 첫 native GMTITLE 기준 객체 만들기

목적:

```text
복제 기준이 될 진짜 native GMTITLE 쌍을 용지 크기별로 확보한다.
```

현재 기본 workcopy의 첫 상태:

```text
NEXT_CREATE_FIRST_NATIVE_GMTITLE
필요한 첫 선택:
  DR_A2_Outline
  DR_titlea_3rd
```

실행:

```text
SWTITLECONVERTNEXT
```

GMTITLE 창에서 확인:

```text
용지/도면틀: SWTITLESTATUS가 안내한 DR_A*_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

성공 증거:

```text
SWTITLESTATUS에서 해당 크기 native 기준 객체가 yes
원본 표제란/도면틀 후보 수가 줄어듦
DR_titlea_3rd 속성값이 기존 표제란 값으로 채워짐
기존 원본 도면틀/표제란 쌍이 정리됨
도면 내부 형상은 이동하지 않음
```

실패 시 원칙:

```text
잘못 선택한 GMTITLE target만 제거하고 기존 원본은 보존한다.
삭제 범위를 넓히는 방식으로 보정하지 않는다.
같은 실패가 반복되면 SWTITLESTATUS/SWTITLEVERIFY 로그부터 비교한다.
```

### 3단계. 여러 장 처리 검증

목적:

```text
한 장씩 해야 하는 반복을 줄이되, 잘못된 자동화를 밀어붙이지 않는다.
```

기본 실행:

```text
SWTITLECONVERTNEXT
SWTITLESTATUS
```

수동 응답을 직접 고를 때:

```text
SWTITLECONVERT
OPEN   : A3/A4 native 교체 후보 1장 처리
BATCH  : OPEN으로 최소 1장 성공하고 같은 선택이 반복된다는 것을 눈으로 확인한 뒤에만 사용
MANUAL : OPEN이 새 GMTITLE을 못 잡거나 NO_INSERTS가 반복될 때만 사용
```

중단 기준:

```text
일반 A3/A4 또는 ISO 제목블록이 선택됨
Object move가 ON임
후보 수가 줄지 않음
도면 내부 형상이 이동함
빨간 네모로 표시한 실제 도면 주석/번호/BOM/힌트가 삭제됨
```

### 4단계. A4 frame-only 별도 처리

A4는 A2/A3와 다르다.

현재 도면의 A4는 표제란이 없는 frame-only 시트로 감지된다. 따라서 성공 조건은 제목블록을 만드는 것이 아니라 `DR_A4_Outline` 도면틀만 교체하는 것이다.

성공 조건:

```text
DR_A4_Outline 도면틀 수량이 기대 수량과 맞음
불필요한 DR_titlea_3rd 제목블록이 생기지 않음
기존 A4 도면 내용이 삭제되지 않음
effective A4 형상과 raw selection 검사가 통과함
```

현재 조사 결론:

```text
공식 DR_A4_Outline은 작은 native outside marker를 포함할 수 있다.
이제 이 작은 마커는 effective A4 형상과 raw selection 검사가 통과하면 허용한다.
큰 raw bbox 위험이나 raw selection warning이 나오면 여전히 안전 중단한다.
```

금지:

```text
A4 frame-only source에 원본에 없던 DR_titlea_3rd를 새로 만들기
DR_A4_Outline이 크다고 가정하고 도면 밖 객체를 무작정 삭제하기
```

### 5단계. 최종 완료 검증

최종 검증 순서:

```text
SWTITLESTATUS
SWTITLEVERIFY
DWG 저장
GstarCAD 종료
diagnostics/gmtitle-main45/run_final_completion_gate.ps1
대표 A2/A3 제목블록 더블클릭 확인
```

완료 조건:

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
대표 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창
A4 frame-only에는 불필요한 제목블록 없음
도면 내부 번호, 주석, BOM, 치수, 모델 형상 보존
```

## 반복 실수 방지 규칙

```text
1. 새 명령어를 만들기 전에 SWTITLESTATUS의 다음 조치가 맞는지 본다.
2. CAD 명령줄에 GMTITLE, TIT, 일반 OPEN을 직접 입력하지 않는다.
3. SWTITLECONVERT 안의 OPEN 응답과 CAD 일반 OPEN 명령을 구분한다.
4. 스크린샷 좌표 클릭으로 GMTITLE 창을 고르지 않는다.
5. 긴 소수점 좌표를 사람이 직접 치지 않는다.
6. A3 도면틀이 INSERT처럼 보인다고 바로 실패로 보지 않는다.
7. A4는 A2/A3와 같은 제목블록 있는 시트로 취급하지 않는다.
8. probe 로그와 실제 작업 DWG 로그를 혼동하지 않는다.
9. 같은 경고가 그대로면 같은 명령을 반복하지 않는다.
10. 최종 완료는 SWTITLEVERIFY_FINAL_OK와 대표 더블클릭 확인 전에는 선언하지 않는다.
```

## 현재 코드가 이미 줄인 반복

### 좌표 직접 입력 제거

`SWTITLECONVERTNEXT`/`SWTITLECONVERT`는 기존 도면틀 bbox에서 왼쪽 아래 배치점을 계산한다.

사용자는 긴 소수점 좌표를 치지 않고, GMTITLE 창에서 용지/제목블록/옵션만 확인한다.

### 이전 명령 난립 정리

일반 작업 공개 명령은 다음 흐름으로 정리했다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERTNEXT
SWTITLEVERIFY
```

`SWTITLECONVERT`는 수동 응답을 직접 고를 때만 사용한다.

### 잘못된 자동화 차단

숨김 `/b` script에서 interactive GMTITLE을 밀어붙이면 중단한다.

화면 좌표 클릭, 일반 `GMTITLE`/`TIT` 직접 호출, CAD 일반 `OPEN` 우회도 공식 흐름에서 제외한다.

### 문서/검사 기준

현재 기준 문서는 다음이다.

```text
docs/guide/gmtitle-current-run-card.md
docs/guide/gmtitle-goal-mode-plan.md
docs/guide/commands.md
diagnostics/gmtitle-main45/run_next_cad_action.ps1
```

`docs/history`와 `docs/investigations`는 과거 실험/실패/근거 기록이다. 판단이 갈리면 현재 기준 문서를 우선한다.
