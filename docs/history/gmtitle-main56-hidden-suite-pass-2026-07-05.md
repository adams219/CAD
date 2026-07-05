# GMTITLE main56 hidden suite PASS 기록

2026-07-05 19:52에 `diagnostics\gmtitle-main45\run_main45_verification_suite.ps1`를 실행했고 전체 hidden verification suite가 통과했다.

## 실행 조건

```text
브랜치: codex/gm-title
커밋: aff9fad Guard run card against stale CAD state
작업트리: clean
GstarCAD: closed
Source work copy:
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
Window style: Minimized
```

## 핵심 결과

```text
no-CAD next-action card probe: PASS
GstarCAD /b script smoke probe: PASS
Loader probe: PASS
Current LSP copy compare probe: PASS
Actual work-copy status probe: PASS
A4 native exemplar gap probe: PASS
A4 outline native outside marker prepare probe: PASS
A4 outline frame-only convert probe: PASS
SWTITLECONVERT script guard probe: PASS
Common A2/A3/A4 frame-definition probe: PASS
A2/A3/A4 style-normalization rebuild cleanup probe: PASS
Command-text guard comparison probe: PASS
Sheet residue protection probe: PASS
Embedded-title prepare comparison probe: PASS
Duplicate target pair comparison probe: PASS
Native adoption gate comparison probe: PASS
A3 status guidance probe: PASS
A3/A4 batch guard probe: PASS
GMTITLE selection config probe: PASS
All expected log markers were verified.
===== GMTITLE main56 verification suite complete =====
```

## 실제 workcopy 상태

suite 안의 actual work-copy status probe는 읽기 전용으로 동작했고 `dbmod-after-commands: 0`이었다.

```text
status-after-status: NEXT_CREATE_FIRST_NATIVE_GMTITLE
status-after-verify: SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
next-bootstrap-frame: DR_A2_Outline
next-bootstrap-title: DR_titlea_3rd
missing-native-frame: DR_A2_Outline
missing-native-frame: DR_A3_Outline
missing-native-frame: DR_A4_Outline
```

즉 suite PASS는 구현 방향과 guard가 깨지지 않았다는 증거이지, 실제 workcopy 변환 완료 증거는 아니다.

## 자동화 방향 판정

검증된 방향:

```text
SWTITLECONVERTNEXT는 첫 native GMTITLE 생성 단계에서 DR_A2_Outline / DR_titlea_3rd 1회를 안내한다.
SCRIPT 또는 /b 자동 실행 중에는 interactive GMTITLE 변환을 중단해 도면을 보존한다.
A4 frame-only는 DR_titlea_3rd를 새로 만들지 않고 DR_A4_Outline 도면틀만 처리한다.
공식 A4의 작은 바깥 native marker는 effective A4 형상과 raw selection 검사가 통과할 때 ready-native-outside-markers로 허용한다.
source-contaminated 도면틀 정의와 native-format-with-title-geometry 정의를 구분한다.
이미 같은 위치에 native GMTITLE target 쌍이 있으면 새로 만들지 않고 채택할 수 있다.
GMTITLE 선택값을 안정적으로 미리 지정하는 persistent config는 발견되지 않았다.
```

아직 남은 실제 CAD 작업:

```text
GstarCAD에서 실제 workcopy를 열고 SWTITLECONVERTNEXT 실행
GMTITLE 창에서 DR_A2_Outline / DR_titlea_3rd / Frame positioning ON / Object move OFF 확인
그 뒤 SWTITLESTATUS로 다음 단계 확인
최종적으로 SWTITLEVERIFY_FINAL_OK와 대표 A2/A3 제목블록 더블클릭 표 편집창 확인
```
