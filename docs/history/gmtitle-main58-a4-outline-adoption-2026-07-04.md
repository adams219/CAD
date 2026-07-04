# GMTITLE main58 A4 도면틀-only 승격 기록 - 2026-07-04

## 목적

표제란이 없는 A4 SolidWorks 시트를 GMTITLE 흐름에서 처리할 때 원본에 없던 `DR_titlea_3rd` 제목블록을 만들지 않도록 한다.

사용자용 명령은 계속 아래 4개만 유지한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

## 참고한 이력

복사본 실험:

```text
work/lsp_compare/swcad_title_scale_a4_outline_only_experiment_260704.lsp
docs/investigations/gmtitle-a4-frame-only-outline-copy-comparison-2026-07-04.md
```

실험판 결론:

```text
방향은 맞음:
  A4 frame-only 시트에는 DR_A4_Outline만 넣고 DR_titlea_3rd는 만들지 않는다.

그때 바로 승격하지 않은 이유:
  당시 작업복사본의 DR_A4_Outline 정의 raw bbox가 A4보다 과도하게 커서
  새 A4 도면틀을 넣은 뒤 선택 범위 검사를 통과하지 못했다.
```

이후 main57에서 해결한 전제:

```text
SWTITLEPREPARE가 사용 중이 아닌 DR_A4_Outline 오염/raw bbox 위험 정의를
설치 원본 기준으로 복구할 수 있게 되었다.

실제 work 로그 기준:
  DR_A4_Outline 정의raw경고=0
```

## main58 변경

버전:

```text
260704-target-overlap-adopt-main58-a4outline
```

변경 내용:

```text
1. SWTITLESTATUS가 A4 frame-only를 "대기"가 아니라 변환 가능 상태로 안내한다.
2. SWTITLECONVERT가 A4 frame-only일 때 새 내부 경로를 사용한다.
3. 새 내부 경로는 DR_A4_Outline만 삽입한다.
4. DR_titlea_3rd는 만들지 않는다.
5. 새 도면틀의 effective bbox와 raw selection bbox를 검사한다.
6. 검사를 통과할 때만 기존 A4 frame INSERT와 제한된 잔여물을 삭제한다.
7. 실패하면 새 도면틀을 삭제하고 기존 A4는 보존한다.
8. 새 A4 도면틀에는 `frame-only-outline` marker를 기록한다.
9. SWTITLEVERIFY는 이 marker가 있는 A4 도면틀을 제목블록 없는 정상 대상으로 계산한다.
```

## 같은 실수 방지 규칙

```text
A4 원본에 표제란이 없으면 GMTITLE 제목블록을 만들지 않는다.
A4 frame-only를 처리하려고 SWTITLETRANSFERAPPLY/SWTITLEFRAMEONLYAPPLY 같은 옛 명령으로 돌아가지 않는다.
DR_A4_Outline raw bbox 위험이 있으면 변환하지 않고 SWTITLEPREPARE부터 실행한다.
형상 검사를 통과하기 전에는 기존 A4를 삭제하지 않는다.
```

## 검증 결과

정적 검증은 통과했다.

```text
git diff --check
paren depth: Depth=0 Min=0 InString=False
public c: commands: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERT, SWTITLEVERIFY, SWTITLEVERSION, SWSCALESCAN
```

CAD 검증도 통과했다.

```text
열린 작업복사본:
  C:/Users/DR-DESIGN/Documents/CAD tool/work/0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg

로드 버전:
  260704-target-overlap-adopt-main58-a4outline

A4 1차 SWTITLECONVERT:
  원본 A4 frame-only: 0310_도면_세로_A4_FROM_HYUN
  새 도면틀: DR_A4_Outline
  DR_titlea_3rd 생성: 없음
  결과: FINALIZED_A4_FRAME_ONLY_OUTLINE_TRANSFER

A4 2차 SWTITLECONVERT:
  원본 A4 frame-only: 0320_도면_세로_A4_FROM_HYUN
  새 도면틀: DR_A4_Outline
  DR_titlea_3rd 생성: 없음
  결과: FINALIZED_A4_FRAME_ONLY_OUTLINE_TRANSFER

SWTITLESTATUS:
  남은 원본 표제란 시트: 0
  남은 원본 도면틀: 0
  남은 표제란 없는 도면틀 시트: 0
  용지별 보이는 대상 도면틀 수: A2=1, A3=12, A4=2

SWTITLEVERIFY:
  A4 도면틀-only 대상 수: 2
  제목블록 없는 대상 도면틀 수: 0
  도면틀 형상 경고 수: 0
  도면틀 겹침/선택 위험 수: 0
  결과: SWTITLEVERIFY_FINAL_OK

대표 A2 제목블록 편집 확인:
  CAD 좌표 (398,6) - (590,58) 범위로 A2 제목블록을 확대했다.
  GMPOWEREDIT로 `DR_titlea_3rd` 제목블록 선을 선택했다.
  결과: `속성 블록 편집` 창이 열렸다.
  닫은 뒤 속성 팔레트에서도 선택 객체 이름이 `DR_titlea_3rd`이고 `GEN-TITLE-*` 속성이 표시됐다.
  즉 대표 A2는 고급 속성 편집기/REFEDIT가 아니라 GMTITLE 표 편집창 계열로 동작함을 확인했다.
```

수동 더블클릭 확인 목록도 A2/A3의 실제 `DR_titlea_3rd` 제목블록 13개만 대상으로 안내한다.
표제란 없는 A4 2장은 더블클릭할 제목블록이 없으므로 `SWTITLEVERIFY`의 도면틀 수량/형상 검증으로 확인한다.
