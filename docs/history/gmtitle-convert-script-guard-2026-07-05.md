# SWTITLECONVERT SCRIPT Guard - 2026-07-05

## 목적

`SWTITLECONVERT`는 실제 변환 명령이다.

이 명령은 상황에 따라 GstarCAD `GMTITLE` 대화상자를 열고, 사용자가 아래 값을 눈으로 확인해야 한다.

```text
DR_A*_Outline
DR_titlea_3rd
Frame positioning ON
Object move OFF
```

따라서 숨김 CAD `/b` SCRIPT 자동화에서 `SWTITLECONVERT`가 그대로 진행되면 안 된다.

이 자동화는 상태 확인에는 좋지만, 대화상자 선택과 배치 확인이 필요한 변환 단계에는 위험하다.

## 추가 검증

다음 probe를 추가했다.

```text
diagnostics/gmtitle-main45/convert_script_guard_probe.lsp
diagnostics/gmtitle-main45/run_convert_script_guard_probe.ps1
```

probe는 복사본 DWG에서 `/b` SCRIPT 실행 중 `SWTITLECONVERT`를 호출한다.

기대 결과:

```text
Script active before convert: yes
Status after convert: ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE
Source titles before/after: 13/13
Source frames before/after: 15/15
Frame-only before/after: 2/2
Target titles before/after: 0/0
Target frames before/after: 0/0
INSERT count before/after: 120/120
DBMOD before/after: 0/0
Convert script guard preserved drawing: yes
```

## 의미

이 검증은 실제 변환을 완료하지 않는다.

대신 다음 원칙을 보증한다.

```text
SWTITLESTATUS / SWTITLEVERIFY:
  숨김 CAD SCRIPT에서 읽기 전용 상태 확인 가능

SWTITLECONVERT:
  숨김 CAD SCRIPT에서 진행 금지
  사람이 보는 CAD 명령줄에서 직접 실행
  GMTITLE 창 값을 눈으로 확인
```

즉, 자동화 방향은 상태 진단과 안전 검증을 강하게 하고, 실제 native GMTITLE 생성 순간은 사용자가 CAD 화면에서 확인하는 방식이다.

## 다음 실제 CAD 순서

현재 기본 workcopy 기준 첫 변환은 아래 순서다.

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp

SWTITLEVERSION
SWTITLESTATUS
SWTITLECONVERT
```

첫 GMTITLE 창에서 확인할 값:

```text
용지/도면틀: DR_A2_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

`SWTITLECONVERT`를 스크립트 파일이나 숨김 실행으로 돌리려고 하면 정상적으로 중단되어야 한다.
