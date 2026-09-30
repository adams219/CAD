# SWCADRUN SolidWorks 기본 양식 정리(SHEET_FORMAT) - 2026-09-30

워크플로·모듈 버전 `260930-sheet-format-1`. 221216 감속기 성능 시험기 도면(32장)은 모으기와 XREF 결합까지 되고 `BLOCKED_NO_SHEETS`에서 멈췄다(`docs/history/swcad-collect-2026-09-30.md`). 원인과 고친 내용을 적는다.

## 원인

TITLE 단계(`swcad-title-source-frame-candidates`, `swcad-title-source-title-insert-candidates`)는 이름에 용지 크기(`A0`~`A4`)가 있는 도면틀 INSERT와 이름에 `TITLE`/`FTAP`가 있는 표제란 INSERT만 원본 시트로 센다. 블록 없는 표제란을 읽는 경로(loose-text)도 먼저 찾은 도면틀 INSERT를 입력으로 받는다. 221216 도면은 SolidWorks 기본 한국어 양식이라 도면틀·표제란이 모두 LINE과 MTEXT다. 그래서 원본 수가 0이었다.

## 실측한 양식

`tmp\linedrawn-probe\`의 덤프(결합한 32장 작업본 사본):

- 모든 객체가 레이어 `0`, 글자는 결합된 `SLDTEXTSTYLE0/1`의 MTEXT.
- 두 겹 테두리: 바깥 사각형은 용지보다 가로 20, 세로 10 mm 작다(A4 세로 190×287, A3 400×287, A2 574×410, A1 821×584, A0 1169×831). 안쪽 사각형은 5 mm 안. 사이에 구역 글자와 눈금선.
- 표제란: 안쪽 테두리 오른쪽 아래 모서리 기준 180×55.25 mm. 모든 크기에서 칸 이름 17개와 칸 선의 위치가 같다.
- 큰 글자(6.35 mm, 예 `Bush Inner`)는 `도면 번호` 칸에 있다. SolidWorks가 이 칸에 SolidWorks 파일 이름을 넣는다. `제목` 칸은 29장 모두 비었다. 1번 조립도의 도면 번호는 두 줄짜리 `SW_NOTE` 블록이다.
- 표제란 안의 `SW_NOTE_0`(일반 공차 안내)과 `SW_NOTE_0_1`(디버링 안내)은 양식의 고정 주석이다.
- 크기 칸은 모든 시트에 `A3`로 적혀 있어 쓸 수 없다.
- 06 Base Frame(4749×3354), 07 Brake Base Plate(1990×1590)는 사용자 크기이고 표제란이 테두리 모서리에 있지 않다. 08 Drive Base Plate는 도면틀이 없다.

## 사용자 결정

- 사용자 크기·도면틀 없는 도면은 바꾸기 전에 멈추고 목록을 보여 준다.
- 값은 칸 이름 그대로: NR = `도면 번호` 칸, DWG = `제목` 칸. 파일 이름은 쓰지 않는다.
- A0: 사용자가 `DR_A0_Outline.dwg`를 만들어 GstarCAD `Dwg\Format` 폴더에 넣는다. 처음에는 GstarCAD 표준 `A0(840x1189mm)`를 골랐으나 실험에서 GMTITLE이 `ISO_A0`를 넣고 `DR_titlea_3rd`를 도면틀 밖(오른쪽 180 mm)에 붙였다. ISO 도면틀은 표제란의 오른쪽 아래를, DR 표제란은 왼쪽 아래를 기준점으로 쓰기 때문이다. 실험 사본은 `work\swcad-workflow-tests\a0_probe_260930_121457.dwg`.

같은 실험에서 확인한 native 도면틀: `DR_A1_Outline` 841×594, `DR_A4_Outline` 210×297 세로(raw bbox는 더 넓고 effective bbox가 210×297). `DR_titlea_3rd`는 183.6×42, 기준점은 용지 왼쪽 아래에서 (가로−190, 10).

## 동작

`apps/swcad-workflow/swcad_workflow.lsp`의 `SHEET_FORMAT` 단계(`swapp-convert-sheet-formats`). 모델 공간에 `도면의 배율을 변경하지 마시오.` 글자가 있으면 TITLE 전에 이 단계가 된다.

1. 그 글자에서 안쪽 테두리 모서리를 구하고, 칸 이름 17개(±1 mm)와 두 겹 테두리의 여덟 변을 확인한다. 시트마다 `SOURCE_SHEET` 범위 안의 객체만 본다.
2. 용지 = 바깥 테두리 + 왼쪽 15, 오른쪽·위·아래 5 mm(아래 "새 도면틀 위치"). A0~A4와 DR 도면틀 방향(A4 세로, 나머지 가로)이 맞고, `DR_Ax_Outline.dwg`가 Format 폴더에 있어야 한다.
3. 칸 영역으로 값을 읽는다. 글자는 삽입점, 주석 블록은 중심. 칸이 없는 글자(무게, 표면 거칠기, 공차 안내 등)는 `work\swcad_sheet_format_last.txt`에만 남긴다.
4. 테두리, 눈금선, 구역 글자, 표제란 안의 선·글자·주석 블록을 `SWFMT_<크기>_OUTLINE_nn`(용지 외곽선 추가)으로, 표제란 외곽선과 `GEN-TITLE-*` 속성 11개를 `SWFMT_TITLE_nn`으로 만든다. 모든 쌍을 먼저 만들고, 성공하면 원래 객체를 지운다.
5. 확인: 남은 양식 글자 0, 표제란 안에 남은 글자 0, 최상위 치수 수 같음, TITLE 단계가 보는 원본 표제란·도면틀 수가 쌍 수 이상. 성공이면 저장한다.
6. 하나라도 인식하지 못하면(사용자 크기, 방향, 도면틀 파일 없음, 잠긴 레이어, 도면틀도 양식도 없는 원본 파일) 아무것도 바꾸지 않고 `STOP_SHEET_FORMAT_UNSUPPORTED`.

TITLE 단계는 이 쌍을 결합된 속성 표제란·도면틀처럼 변환한다. 모듈(`src/tools/gmtitle/swcad_title_scale.lsp`) 변경:

- `SWFMT_*` 도면틀에는 시트 잔여물 영역(왼쪽 아래 8%, 위쪽 노트)을 쓰지 않는다. 양식 객체가 모두 블록 안에 있고, 그 영역에는 도면 내용만 있다.
- A0는 `DR_A0_Outline`으로 간다. 전에는 A0이면 기본값 `DR_A3_Outline`으로 떨어졌다.
- A1·A0를 A2~A4 전용 목록(수량 비교, 필요 용지, native 교체 대기열, title-missing 경로, bbox 크기 판정)에 넣었다.
- GMTITLE을 부르기 전에 목표 도면틀 DWG가 Format 폴더에 있는지 확인한다(`TARGET_FRAME_FILE_MISSING`).
- 자동 선택기(`swtitle_gmtitle_dialog_autoselect.ps1`)가 `DR_A0_Outline`도 받는다.

XREF 단계는 원본 도면틀 블록이 0이어도 양식 글자가 있으면 성공이다.

## 새 도면틀 위치

TITLE 단계는 새 DR 도면틀의 effective bbox 왼쪽 아래를 원본 도면틀(여기서는 `SWFMT` 블록) 범위의 왼쪽 아래에 맞춘다. 그래서 `SWFMT` 블록에 넣는 용지 외곽선이 새 도면틀 자리를 정한다.

결과 도면에서 도면틀을 분해해 잰 DR 도면틀(A1~A4 같음): 바깥 테두리는 용지 왼쪽에서 15, 나머지에서 5 mm, 안쪽 테두리는 왼쪽 20, 나머지 10 mm. SolidWorks 양식의 안쪽 테두리는 좌우 15, 상하 10 mm다.

처음에는 용지를 바깥 테두리 가운데에 두었다(좌우 10 mm). 그러면 DR 안쪽 테두리가 5 mm 오른쪽에 오고, A2 한 장은 도면 내용이 DR 안쪽 테두리를 약 3 mm 넘었다. 용지를 바깥 테두리에서 왼쪽 15, 오른쪽 5 mm로 잡아 두 안쪽 테두리를 겹치게 했다. 이때 새 `DR_titlea_3rd`의 왼쪽 아래도 옛 표제란 왼쪽 아래와 같다.

## Layout 이름 잘림 (워크플로 `260930-sheet-format-2`)

결과 도면의 Layout 26개 가운데 12개 이름이 잘려 있었다. `01-06-11-00_B.P Housing Cover` → `01-06-11-00_B`, `02-09-05-00_D.P Bearing Unit Shaft` → `02-09-05-00_D`. Layout 이름을 만들 때 이미 확장자를 뗀 원본 파일 이름에 `vl-filename-base`를 한 번 더 써서, 마지막 `.` 뒤를 확장자로 잘랐다. 30장 시험 도면에는 이름에 `.`이 없어 드러나지 않았다. `swapp-file-stem-value`는 이제 `.dwg`, `.dxf`, `.dwt`, `.slddrw`만 확장자로 떼고, XREF 이름에서 원본 이름을 얻을 때도 같은 함수를 쓴다.

## 구현 중 발견

- 처음 인식이 9분 넘게 멈췄다. 새 함수의 지역 변수 이름을 `type`으로 지었는데, AutoLISP는 범위가 동적이라 그 안에서 부른 모듈 함수의 `(type ...)` 호출이 문자열을 함수로 쓰게 됐다. `/b`에서는 오류로 끝나지 않고 멈췄다. `etype`으로 바꿨다.
- 도면 전체(약 2만 6천 개)를 시트마다 반복하면 수 분이 걸린다. 시트 범위 안의 객체만 보게 한 뒤 전체 훑기 5.5초, 시트당 약 0.07초.
- 이름이 긴 5장(`Input Locking Unit Flange` 등)은 도면 번호 글자가 표제란 오른쪽 선과 바깥 테두리를 넘는다. 경계 상자로 판단하면 값을 놓치고 글자가 남는다. 글자는 삽입점으로 판단한다.

## 테스트

`diagnostics/swcad-workflow/run_sheet_format_probe.ps1` (`sheet_format_probe.lsp`, GstarCAD `/b`, 작업본 사본):

- 인식(32장 사본, 시험용 A0 도면틀 파일): 표준 29장 인식, 06/07은 테두리 불일치. 도면 번호·배율·용지 값 검사 11개 통과(두 줄 주석 블록, 긴 이름 포함).
- 적용, 멈춤(32장 사본, A0 파일 없음): A0 3장, 사용자 크기 2장, 도면틀 없는 08을 목록으로 보이고 객체 수 25,900 그대로, `SWFMT` 블록 0. 검사 17개 통과.
- 적용, 성공(A1~A4 26장 작업본): 블록 쌍 26개, 도면틀이 용지 외곽선에, 표제란이 표제란 칸에, 속성 값이 읽은 값과 같음, 잔여물 영역 없음, TITLE 단계 원본 26/26, 단계 `TITLE`. 검사 26개 통과.

26장 작업본은 `diagnostics/swcad-workflow/run_xref_collect_probe.ps1 -SourceDir work\sheet-format-test\source_26 -WorkCopy`로 만들었다(32장 중 A0 3장과 06/07/08 제외). 이 스크립트의 32장 전용 검사(줄 크기, 배치 공간 도면 14장)는 32장일 때만 한다. 이 작업본에서 XREF 단계 다음 단계가 `SHEET_FORMAT`인 것도 확인한다.

실제 화면 전체 실행(`diagnostics/gmtitle-values/run_title_stage_e2e.ps1 -FullWorkflow`, 보이는 GstarCAD, GMTITLE 대화 상자 자동 선택, 26장):

| SWCADRUN | 시간 | 단계 뒤 |
| --- | --- | --- |
| 1 SHEET_FORMAT | 17초 | TITLE |
| 2 TITLE | 82초 | DIMSTYLE (`OK_NATIVE_AUTOSELECT_BATCH_COMPLETE`, 26쌍) |
| 3 DIMSTYLE | 14초 | LAYOUT (`PRESERVED`) |
| 4 LAYOUT | 50초 | CLEANUP |
| 5 CLEANUP | 139초 | COMPLETE |

- 저장한 결과의 SWCADVERIFY 부분 검사: `SWCADVERIFY_FINAL_OK`, 도면틀 26, `SWTITLEVERIFY_FINAL_OK`.
- 새 표제란 26개: NR은 도면 번호 칸 값, SCA는 `1:1`/`1:2`/`1:10`/`1:20` 원본대로, SIZ는 A1~A4 테두리 크기대로, 나머지는 기본값(HS KANG, 변환일, `-`, `0`). 옛 도면틀·표제란은 `SWFMT` 블록째 지워졌고 짐작으로 지운 잔여물은 0개.
- 도면 내용과 새 표제란의 겹침 0개. 도면 내용과 용지 끝의 최소 거리: 왼쪽 21.9 mm(DR 안쪽 테두리 20 mm 안). 오른쪽 10, 위 8.7 mm인 시트는 원래 SolidWorks 도면에서도 안쪽 테두리에 닿거나 넘던 내용이다.
- 원본(26장 작업본)의 해시는 그대로였다.

시험 중 로그를 Git Bash `tail -F`로 지켜보면 파일이 잠겨 e2e 스크립트의 `Add-Content`가 실패하고 CAD를 저장 없이 닫는다. 두 번 이렇게 끝났다. 로그는 한 번씩 읽는다.
