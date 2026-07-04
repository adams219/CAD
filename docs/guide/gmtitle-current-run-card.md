# GMTITLE 현재 실행 카드

CAD 화면 옆에 열어두고 따라가는 짧은 실행 순서입니다.

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
260704-target-overlap-adopt-main56-a4frameguard
```

다른 버전이면 변환하지 말고 최신 LSP를 다시 APPLOAD 합니다.

특히 아래처럼 나오면 이전 세션의 낡은 LSP가 아직 살아 있는 것입니다.

```text
260704-nested-style-direct-main55
```

이 상태에서는 `SWTITLECONVERT`를 누르지 말고 최신 LSP를 다시 로드합니다.

## 시작 전 이력 확인

같은 실수를 반복하지 않기 위해 CAD에서 명령을 치기 전에 아래 기준을 먼저 확인합니다.

```text
GitHub 코드 기준: e738d2e Add GMTITLE main56 adoption guard 이상
현재 LSP 기준: 260704-target-overlap-adopt-main56-a4frameguard
사용자용 명령: SWTITLESTATUS / SWTITLEPREPARE / SWTITLECONVERT / SWTITLEVERIFY
```

주의:

```text
main56-a4guard 변경은 GitHub origin/codex/gm-title에 푸시되어 있습니다.
그래도 다른 PC나 열린 CAD 세션이 예전 LSP를 들고 있을 수 있으므로, 실제 CAD의 SWTITLEVERSION을 우선 확인합니다.
```

판단이 헷갈리면 먼저 아래 파일을 봅니다.

```text
docs/history/gmtitle-history-gated-plan-2026-07-04.md
docs/history/gmtitle-main56-target-overlap-adoption-plan-2026-07-04.md
docs/investigations/gmtitle-main55-vs-main56-duplicate-target-pair-comparison-2026-07-04.md
docs/history/gmtitle-requirement-completion-audit-2026-07-04.md
```

열려 있는 CAD 도면이 저장 전 상태일 수 있으므로, 디스크 파일을 숨김 진단으로 다시 연 결과보다 현재 CAD에서 다시 실행한 `SWTITLESTATUS`/`SWTITLEVERIFY` 로그를 우선합니다.

로그를 볼 때는 suffix를 먼저 확인합니다. fixture/test 로그와 실제 작업복사본 로그를 섞어 보면 판단이 틀어집니다.

```text
우선 증거:
work/swtitle_actual_workcopy_status_main56_diagnostics.txt
work/swcad_title_structure_diagnosis_last_actual_workcopy_main56_diagnostics.txt
work/swcad_title_fast_status_last_actual_workcopy_main56_diagnostics.txt
work/swcad_title_verify_summary_last_actual_workcopy_main56_diagnostics.txt
work/swtitle_final_completion_gate_status.txt

주의:
work/swcad_title_structure_diagnosis_last.txt
work/swcad_title_verify_summary_last.txt
```

suffix가 없는 `*_last.txt`는 마지막으로 실행한 임의 테스트 DWG의 로그일 수 있습니다. 실제 업무 도면 상태 판단에는 `actual_workcopy` 또는 `final_completion_gate` suffix가 붙은 로그를 먼저 봅니다.

현재 열린 세션과 디스크 파일 상태가 다르면, 먼저 열린 CAD에서 `SWTITLESTATUS`를 다시 실행해 최신 로그를 만듭니다.

## 현재 저장된 workcopy 기준

현재 디스크에 저장된 기본 작업복사본은 아직 변환 전 상태입니다. final completion gate도 이 이유로 실패하는 것이 정상입니다.

```text
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
원본 표제란 시트: 13
원본 도면틀: 15
표제란 없는 도면틀 시트: 2
target 도면틀/제목블록: 0 / 0
```

이 상태에서 다음 실제 CAD 명령은 `SWTITLECONVERT`입니다.

## 기본 순서

항상 상태부터 봅니다.

```text
SWTITLESTATUS
```

상태가 정규화를 요구하면:

```text
SWTITLEPREPARE
SWTITLESTATUS
```

상태가 변환을 요구하면:

```text
SWTITLECONVERT
SWTITLESTATUS
```

상태가 최종 검증을 요구하면:

```text
SWTITLEVERIFY
```

## GMTITLE 창에서 확인

`SWTITLECONVERT` 중 GMTITLE 창이 열리면 로그가 요구한 값만 선택합니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

## 하지 말 것

```text
일반 A2/A3/A4 선택
ISO 제목블록 선택
스크린샷 좌표 클릭
긴 소수점 좌표 직접 입력
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
```

위 예전 명령이 필요해 보이면 오래된 흐름으로 돌아간 것입니다. `SWTITLESTATUS` 결과를 다시 봅니다.

## main56에서 추가로 막는 실수

```text
같은 위치에 겹친 GMTITLE target 쌍은 SWTITLESTATUS가 표시합니다.
겹친 target 쌍은 SWTITLEPREPARE가 work 복사본에서만 YES 확인 후 정리합니다.
SWTITLECONVERT는 이미 같은 위치에 native GMTITLE 쌍이 있으면 새로 만들지 않고 그 쌍을 채택합니다.
DR_A3_Outline 안의 native-format title-like 형상은 그 자체만으로 삭제하지 않습니다.
별도 DR_titlea_3rd와 실제로 겹치는 경우에만 정규화 후보로 봅니다.
A4 frame-only 기준 객체가 없으면 빠른 일괄 변환에서 A4를 같이 처리하지 않습니다.
```

## 완료 조건

`SWTITLEVERIFY`가 아래 상태를 만족해야 합니다.

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
frame-only 시트: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
겹친 GMTITLE target 쌍: 0
```

마지막으로 대표 A2/A3/A4의 `DR_titlea_3rd` 제목블록을 더블클릭합니다.

기대 결과:

```text
GMTITLE 표 편집창 열림
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```
