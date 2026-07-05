# GMTITLE main56 Hidden Suite PASS 기록

## 최신 검증

2026-07-06 00:23 KST 기준으로 `diagnostics\gmtitle-main45\run_main45_verification_suite.ps1 -TimeoutSeconds 180`를 다시 실행했고, 전체 hidden verification suite가 통과했다.

이번 재검증은 커밋 `5a75f86 Record GMTITLE suite failure reason` 이후에 실행했다. 목적은 A3/A4 native 교체 단계의 BATCH 안전 안내, 자동화 경계 안내, suite 실패 원인 요약 보강이 기존 변환 guard, A4 frame-only 경로, native 인식 검증을 깨지 않는지 확인하는 것이었다.

## 실행 조건

```text
브랜치: codex/gm-title
기준 커밋: 5a75f86 Record GMTITLE suite failure reason
GstarCAD: closed
Source work copy:
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
Probe window style: Minimized
GMTITLE LSP version: 260705-convertnext-main-workflow
Loader version: 260705-4step-gmtitle-a4-outline-preflight
Timeout seconds: 180
```

## 통과 결과

```text
no-CAD next-action card probe: PASS
visible work-copy opener dry-run: PASS
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
Post-first-native marker gate probe: PASS
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

즉 suite PASS는 구현 방향과 guard가 깨지지 않았다는 증거이지, 실제 작업복사본 변환 완료 증거는 아니다.

최신 suite 요약 파일:

```text
work\main56_verification_suite_last_run.txt
Result: PASS
Generated: 2026-07-06 00:23:06 +09:00
```

이 파일은 실패 시 `FAILED_BEFORE_PASS`와 실패 원인/명령을 남기고, 성공 시에만 `PASS`로 덮어쓴다.

## 이번 재검증에서 특히 확인한 점

```text
SWTITLECONVERTNEXT는 첫 native GMTITLE 생성 단계에서 DR_A2_Outline / DR_titlea_3rd 1회를 안내한다.
SCRIPT 또는 /b 자동 실행 중에는 interactive GMTITLE 변환을 중단하고 원본을 보존한다.
A4 frame-only는 DR_titlea_3rd를 새로 만들지 않고 DR_A4_Outline 도면틀만 처리한다.
공식 A4의 작은 바깥 native marker는 effective A4 형상과 raw selection 검사가 통과하면 ready-native-outside-markers로 허용한다.
source-contaminated 도면틀 정의와 native-format-with-title-geometry 정의를 구분한다.
이미 같은 위치에 native GMTITLE target 쌍이 있으면 새로 만들지 않고 채택할 수 있다.
marker-only A2 target은 첫 native GMTITLE로 인정하지 않는다.
A3 도면틀이 INSERT처럼 선택되는 현상만으로 실패 판정하지 않고, 짝 DR_titlea_3rd 제목블록의 GMTITLE 표 편집창 동작을 확인 대상으로 둔다.
A3/A4 BATCH는 SCRIPT 모드에서 ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE로 멈추고 후보를 보존한다.
GMTITLE 선택값을 안정적으로 미리 지정할 persistent config는 발견되지 않았다.
```

## BATCH 안전 안내 결론

이번 커밋 이후 CAD 안 안내는 다음 원칙을 반복해서 출력한다.

```text
BATCH는 첫 후보부터 바로 쓰지 않는다.
먼저 OPEN으로 1장을 성공시킨다.
SWTITLESTATUS 또는 direct probe로 A3/A4 native 교체 후보 수가 줄었는지 확인한다.
남은 후보들이 같은 DR_A*_Outline / DR_titlea_3rd / Frame positioning ON / Object move OFF 선택값으로 반복된다는 것이 눈으로 확인될 때만 BATCH를 사용한다.
GMTITLE 창이 ISO 또는 일반 A3/A4 기본값이면 확인하지 않고 취소한다.
```

이 방향은 반복 선택을 줄이되, 잘못된 용지/제목블록 선택을 여러 장에 퍼뜨리지 않기 위한 현재의 안전 기준이다.

## 아직 남은 실제 CAD 작업

```text
GstarCAD에서 실제 workcopy를 열고 SWTITLECONVERTNEXT 실행
GMTITLE 창에서 DR_A2_Outline / DR_titlea_3rd / Frame positioning ON / Object move OFF 확인
그 뒤 SWTITLESTATUS로 다음 단계 확인
최종적으로 SWTITLEVERIFY_FINAL_OK 확인
대표 A2/A3 제목블록 더블클릭 시 GMTITLE 표 편집창 확인
A4 frame-only는 제목블록이 없으므로 DR_A4_Outline 수량/형상으로 확인
```
