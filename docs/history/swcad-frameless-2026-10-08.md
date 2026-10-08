# SWCADRUN 도면틀 없는 시트와 모으기 간격 - 2026-10-08

워크플로 `261008-frameless-1`(모듈은 `260930-sheet-format-2` 그대로). 221216 감속기 성능 시험기 32장을 BOM 순서대로 한 도면에 모아 끝까지 변환했다. 9월 30일 결과는 26장이었고 A0 3장, 06·07(키운 도면틀), 08(도면틀 없음)이 빠졌다(`docs/history/swcad-sheet-format-2026-09-30.md`).

## 사용자 결정

- 도면틀이 없는 도면에도 도면틀을 넣는다("도면틀은 만들어달라했던거 같아"). 9월 30일에는 멈추기로 했고 08은 사용자가 SolidWorks에서 고치기로 했었다. 받은 DWG.zip의 08은 9월 29일 파일 그대로였다.
- `DR_A0_Outline.dwg`는 10월 1일에 만들어 GstarCAD `Dwg\Format`에 설치했다(원본 `work\dr-a0-frame\`).

## 08 실측

`08-00-00-00_Drive Base Plate.DWG`(DWG 2007): 모델 공간이 비고 배치 `시트1`에 객체 366개. 용지 ISO A0(1189×841), 뷰포트 1:1. 도면틀·표제란 없이 뷰, 치수 7개, 구멍 표(`SW_TABLEANNOTATION_0`), 중심 표시 70개. 내용 범위 2064×850 mm로 A0 용지보다 넓다.

## 바꾼 것

1. 도면틀 없는 시트(`swapp-swfmt-frameless-sheet`): 도면틀 블록도 기본 양식 앵커도 없는 `SOURCE_SHEET`는 범위 안 모델 객체 전체를 도면 내용으로 보고, 사용자 크기 용지와 같은 순서(GMTITLE 축척 k가 작은 것, 그다음 작은 용지)로 DR 도면틀을 고른다(`swapp-swfmt-frameless-choice`). 조건은 키운 안쪽 테두리(20k/10k)가 내용을 담고, 내용이 키운 표제란 자리와 새 `SWFMT_TITLE` 상자에 닿지 않는 것. 자리 후보는 내용 가운데, 그다음 내용 모서리를 안쪽 테두리 모서리 5k 안에 맞춘 네 자리다. 옮길 양식 객체가 없어 `SWFMT_<크기>_OUTLINE`에는 용지 외곽선만, `SWFMT_TITLE`에는 SIZ·SCA 값만 들어간다. NR은 빈칸이다(칸 이름으로만 읽는다는 결정, 파일 이름 안 씀).
2. 모르는 테두리 보호(`swapp-swfmt-border-around-p`): 내용 둘레를 네 변 모두 90% 이상 덮는 선, 또는 내용 범위와 같은 닫힌 폴리선이 있으면 모르는 양식으로 보고 `NO_FORMAT`으로 멈춘다. 08에는 없다.
3. 시트 목록 공용화(`swapp-swfmt-sheets`): 실행과 `sheet_format_probe.lsp`가 같은 목록(양식 시트 + 도면틀 없는 시트, 용지 자리 배정)을 쓴다.
4. 모으기 간격(`swapp-collect-item-gap`): 50 mm 고정에서 두 이웃(줄 사이면 두 줄의 모든 도면) 가운데 큰 쪽의 `max(50 mm, 긴 변의 10%)`로 바꿨다. 32장 첫 시험에서 06(A0×4, 원래 용지보다 아래로 5 mm)과 07(A0×2, 가운데 놓으면 위아래 46 mm)의 새 도면틀이 1 mm 겹쳐 `OVERLAP`으로 멈췄다. 50 mm 간격으로는 06·07·08 세 장에 필요한 여유(5 + 92 + 20 mm)가 두 간격(100 mm)보다 커서 자리 배정으로는 풀 수 없었다.

## 결과 (32장)

모으기 줄: 00 / 01 13장 / 02 12장 / 03 3장 / 06 / 07 / 08. BOM 순서와 파일 이름 순서가 같다.

| 시트 | 도면틀 | 표제란 SCA | 자리 |
| --- | --- | --- | --- |
| A0 3장(01-06-05, 02-10, 03-03) | `DR_A0_Outline` 1:1 | 원본 배율 | 표준 |
| 06 Base Frame | `DR_A0_Outline` ×4 | 1:4 | 가운데 |
| 07 Brake Base Plate | `DR_A0_Outline` ×2 | 1:2 | 가운데(바깥 테두리 아래에 맞춤) |
| 08 Drive Base Plate | `DR_A0_Outline` ×2 | 1:2 | 내용 왼쪽 위 맞춤(가운데는 07 도면틀과 겹침) |

실제 화면 전체 실행(`run_title_stage_e2e.ps1 -FullWorkflow`, 원본 `work\xref-collect-test\261008_111414\collect_host.dwg`, 결과 `work\sheet-format-test\e2e32_261008_111928.dwg`):

| SWCADRUN | 시간 | 단계 뒤 |
| --- | --- | --- |
| 1 SHEET_FORMAT | 24초 | TITLE |
| 2 TITLE | 123초 | DIMSTYLE (`OK_NATIVE_AUTOSELECT_BATCH_COMPLETE`) |
| 3 DIMSTYLE | 23초 | LAYOUT |
| 4 LAYOUT | 72초 | CLEANUP |
| 5 CLEANUP | 203초 | COMPLETE |

- 저장한 결과: `SWCADVERIFY_FINAL_OK`, `SWTITLEVERIFY_FINAL_OK`, 도면틀 32, XREF 0, DIMSTYLE `PRESERVED`.
- Layout 32개, 이름은 원본 파일명, 순서는 BOM 순서(00 → 08).
- 표제란 32개. 08은 NR 빈칸, SIZ `A0`, SCA `1:2`. 나머지는 9월 30일 규칙대로.
- 도면 객체와 새 표제란이 겹치는 것 0개(모델 공간 전체 객체의 범위로 확인).
- 원본 사본 해시 그대로. 사용자에게 `Downloads\221216_감속기시험기_32장_변환결과_261008.dwg`로 복사했다.

## 테스트

- `run_xref_collect_probe.ps1 -WorkCopy`(32장): 56개 통과, 줄 `(1 13 12 3 1 1 1)`.
- `run_sheet_format_probe.ps1 -Mode APPLY`(32장): 40개 통과. 08 검사 5개 추가(도면틀 없음, `A0` 2.0, SCA `1:2`, NR 없음, 양식 객체 없음).
- 시험의 도면틀 위치 검사는 삽입점이 용지 왼쪽 아래이고 범위가 용지를 덮는지 본다. 06의 두 글자 구역 표시(AA, AC …)가 테두리 띠보다 넓어 블록 범위가 용지 오른쪽보다 최대 1.45 mm 나온다. 이 글자는 임시 블록과 함께 지워진다.
- `run_static_preflight.ps1`: PASS(모듈 해시 그대로).
- 30장 회귀 시험은 돌리지 않았다. 30장 시험 도면에는 기본 양식 앵커가 없어 `SHEET_FORMAT`과 모으기 코드를 지나지 않는다.

## FILE NO와 File Name (워크플로 `261008-file-name-1`)

32장 결과를 Layout마다 검토하니 DR 표제란 `NR`(프롬프트 `FILE NO`)에 부품 이름(`Bush Inner`)이 들어가고 `DWG`(`File Name`)는 32장 모두 비어 있었다. SolidWorks가 `도면 번호` 칸에 SolidWorks 파일 이름을 넣고, 9월 30일 결정이 칸 그대로 옮기기였기 때문이다. 번호(`01-06-07-00`)는 Layout 이름에만 있었다.

사용자 결정: FILE NO와 File Name을 파일 이름에서 나눠 쓴다. `01-06-07-00_Bush Inner` → NR `01-06-07-00`, DWG `Bush Inner`. 번호 규칙은 모으기 줄 나누기와 같다(`swapp-drawing-number-split`, 두 개 이상의 숫자 묶음을 `-`로 잇고 `_`·공백·끝). 번호로 시작하지 않는 이름은 칸 값을 쓴다. 칸 값은 시트의 `cell-values`에 남기고, 파일 이름과 다르면 `swcad_sheet_format_last.txt`에 적는다. 도면틀 없는 08도 `08-00-00-00` / `Drive Base Plate`가 된다.

- `run_sheet_format_probe.ps1 -Mode APPLY`(32장): 49개 통과(칸 읽기 검사는 `cell-values`로 옮기고, FILE NO·File Name 검사와 번호 나누기 단위 검사 추가).
- 실제 화면 전체 실행(결과 `work\sheet-format-test\e2e32_261008_121019.dwg`): 25 / 120 / 23 / 71 / 201초로 `COMPLETE`, `SWCADVERIFY_FINAL_OK`, `SWTITLEVERIFY_FINAL_OK`, 도면틀 32. Layout 32개 모두 FILE NO = 파일 이름의 번호, File Name = 이름. 사용자에게 `Downloads\221216_감속기시험기_32장_변환결과_261008_v2.dwg`로 복사했다.

## 치수 글자 크기와 A4 출력 (검토, 프로그램 변경 없음)

사용자는 모든 도면을 A4로 출력한다. Layout은 모두 A4 용지에 도면틀을 맞춘 뷰포트다(A3 도면틀 0.71, A2 0.5, A1 0.35, A0 0.25, A0×2 0.125, A0×4 0.0625). 치수와 주석 글자는 32장 모두 3.5 mm라서, 출력 높이는 A4 3.5, A3 2.5, A2 1.75, A1 1.24, A0 0.88, 07·08 0.44, 06 0.22 mm다. 사용자가 "A3는 잘 보인다"고 한 것은 2.5 mm다.

시험 도면 `Downloads\221216_감속기시험기_치수확대_시험_261008.dwg`: 위 결과 사본에서 A3보다 큰 도면틀 안의 치수(DIMSCALE 덮어쓰기, 값 그대로) 493개와 주석 글자(높이, MTEXT 폭) 187개를 도면틀 긴 변/420배(A2 1.41, A1 2, A0 2.83, A0×2 5.66, A0×4 11.3) 키웠다. A4로 찍으면 모두 약 2.5 mm가 된다. 표(구멍 표 블록)와 기호 블록, 표제란은 그대로다. 사용자가 겹침을 눈으로 본 뒤 방법을 정한다. 다른 길은 DR_A3 도면틀을 GMTITLE 축척으로 키우고 치수를 같은 배율로 키우는 것이다. 이렇게 하면 표제란도 읽히고 나중에 넣는 Mechanical 치수도 축척을 따르지만, 축척 목록(1:2, 1:2.5, 1:4 …)에 맞추느라 도면이 지금보다 20~45% 작게 찍힌다.

## A4 출력 글자 크기 단계 TEXT_SIZE (워크플로 `261008-text-size-1`)

사용자는 시험 도면(글자만 키움)을 보고 겹침을 확인했다. 겹침 검사(`tmp\probe08\clash_count.lsp`, 글자 bbox와 글자·선·원·호·다른 치수선): 원래 결과 18곳(대부분 원래 닿아 있던 곳), 글자만 키운 시험본 147곳. 새로 생긴 겹침은 A2 9장 14곳, A1 5장 21곳, A0 3장 37곳, 06·07·08 57곳이다.

사용자 결정: A2 이상 모든 도면(06·07·08 포함)을 A4 기준으로 키우고, 치수선 간격을 같은 배율로 벌리고, 남은 겹침은 표시만 해서 손으로 정리한다. 동작은 `docs/swcad-workflow/architecture.md`의 "TEXT_SIZE"에 적었다. DIMSTYLE 다음, LAYOUT 전 단계이고 `SWCADVERIFY` 판정에 들어간다.

- 32장 실제 화면 전체 실행(결과 `work\sheet-format-test\e2e32_261008_171642.dwg`): SHEET_FORMAT 25초, TITLE 122초, DIMSTYLE 22초, TEXT_SIZE 76초, LAYOUT 71초, CLEANUP 203초. `SWCADVERIFY_FINAL_OK`, `TEXT_SIZE=OK`, 겹침 표시 75곳.
- 키운 도면 20장, 치수 493개(치수선 간격 벌림 283개), 주석 187개. 치수 글자 실제 높이: A2 4.95, A1 7.01, A0 9.91, 07·08 19.82, 06 39.63 mm.
- 겹침 표시(표 겹침도 셈): 06 23, 02-10 11, 07 9, 03-03 8, 01-03 5, 01-06-05 4, 01-06-15 3, 08 2, 나머지 9장 1~2곳, 7장 0곳.
- 사용자에게 `Downloads\221216_감속기시험기_32장_변환결과_261008_v3_A4글자.dwg`로 복사했다.
- 표(구멍 표, 08은 145×850 mm), 모따기 치수 블록, 중심 표시는 키우지 않았다. 08과 02-10의 구멍 표 글자는 A4에서 각각 0.44, 0.88 mm로 찍힌다.
