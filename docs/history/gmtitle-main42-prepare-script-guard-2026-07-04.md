# GMTITLE main-42 SWTITLEPREPARE 자동 실행 guard

날짜: 2026-07-04

## 배경

로컬/Git 이력을 다시 확인한 결과, 이전에 이미 다음 결론이 있었다.

- `0bb4c9b Document GMTITLE first-native picker limits`: GMTITLE 창 선택은 좌표 클릭이나 스크린샷 기반 자동화로 안정적으로 처리하지 않는다.
- `0121ae1 Clean up GMTITLE command surface`: 사용자 흐름은 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 4개 명령으로 유지한다.
- `main-38`: `SWTITLECONVERT`는 `SCRIPT`나 `/b` 자동 실행 중 대화식 GMTITLE 단계로 들어가지 않고 중단한다.

2026-07-04에 `main-41` 기준 `SWTITLEPREPARE` 런타임 확인을 시도했지만, 결과 로그가 생성되지 않았다.
프로세스 확인 결과 숨김 GstarCAD 인스턴스가 남아 있었고, 가장 가능성 높은 원인은 정리 후보가 있는 작업복사본에서 `SWTITLEPREPARE`가 YES 확인 입력을 기다린 것이다.

## 수정

`260703-integrated-flow-main-42`에서 `SWTITLEPREPARE`에도 자동 실행 guard를 추가했다.

- `SCRIPT` 또는 `/b` 실행 상태에서는 정리 후보 스캔/삭제 단계로 들어가지 않는다.
- 상태 코드는 `ABORT_PREPARE_SCRIPT_ACTIVE`로 남긴다.
- 안내 문구는 CAD 명령줄에서 직접 `SWTITLEPREPARE`를 입력하라고 설명한다.
- 도면 데이터는 변경하지 않는다.

## 이유

`SWTITLEPREPARE`는 읽기 전용 명령이 아니다.
실수 명령어 텍스트, 도면틀 정의 안의 중첩 제목블록, DR 도면틀 내부 표제란 형상, 고아 GMTITLE 도면틀 후보를 보여준 뒤 각 정리 단계에서 `YES` 확인을 받는다.
따라서 후보가 있는 도면에서는 자동 스크립트가 입력 대기 상태로 멈출 수 있다.

## 현재 판단

- `main-41`까지의 읽기 전용 CAD 런타임 로드는 확인됐다.
- `main-42`는 같은 실수를 반복하지 않기 위한 guard 보강이다.
- 실제 변환 완료 증거는 아직 아니다.
- 실제 정리/변환은 CAD 명령줄에서 직접 아래 순서로 진행한다.

```text
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLEVERIFY
```

## 주의

자동 확인은 `SWTITLESTATUS`와 `SWTITLEVERIFY` 같은 읽기 전용 명령에 한정한다.
`SWTITLEPREPARE`와 `SWTITLECONVERT`는 후보 삭제, GMTITLE 창 선택, 배치 확인이 필요할 수 있으므로 `/b` 자동 실행으로 밀어붙이지 않는다.
