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
