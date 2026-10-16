# SWCADRUN 문자 스타일 통일과 맞춤공차 중복 공차 - 2026-10-15~16

워크플로 `261015-text-style-1`, `261016-fit-tolerance-1`. 모듈은 그대로다.

## 문자 스타일 (TEXT_STYLE)

사용자 질문(2026-10-15): XREF를 결합하면 치수 스타일 등이 파일 이름이 붙은 이름이 되는데, 치수는 정리되지만 문자·여러 줄 문자에는 아직 남아 있다.

실측(221216 32장 결과): 파일 이름이 붙은 문자 스타일 57개(`…$0$SLDTEXTSTYLE0~6`, TXT 폭 0.75·0.69·0.7, Century Gothic 0.91, Arial Rounded 1). 이 스타일을 쓰는 문자는 모델 공간 MTEXT 208개, SW 블록(표·주석) 안 MTEXT 1,514개. 한글이 든 문자 63개(`단면 A-A`, 표 머리글 `품번 품명 수량 비고 태그 X 위치`). 치수 574개는 이미 `Standard`(Arial). DR 도면틀·표제란은 ISOCP, ACISOTS, monotxt-03.

사용자 결정: `Standard`로 통일. 동작은 `docs/swcad-workflow/architecture.md`의 "TEXT_STYLE".

- 32장 결과 사본(`/b`, 사용자 CAD가 열려 있어 별도 창): 1,722개 변경, CLEANUP 뒤 바인딩 문자 스타일 0개, `SWCADVERIFY_FINAL_OK`.
- 사용자 도면 `Downloads\221216_감속기시험기_261012.dwg`(10-12 저장, 이전 버전 변환본) 사본: 같은 결과. `Downloads\221216_감속기시험기_261012_문자정리.dwg`로 줬다.
- 남은 `$0$` 이름: 블록 323개(그대로 둬야 함), 레이어 6개(`…$0$AM_5`), 선 종류 47개. 레이어·선 종류 통합은 제안만 했다.

## 맞춤공차 중복 공차 (FIT_TOLERANCE)

사용자 보고(2026-10-16): `Ø32 h7(0/-0.025)` 옆에 `0 / -0.025`가 한 번 더 그려진다.

원인: SWAUTO는 맞춤공차를 넣을 때 편차를 치수 글자에 넣고(`swdt-mech-fit-display`) DSTYLE 덮어쓰기에 `DIMTOL`을 쓰지 않아 AM_ISO 스타일 값(끔)을 따르게 한다. 모듈의 값 보호는 이 변화를 받아들인다(`fitmoved`). 통합 앱의 DIMSTYLE 전후 비교(`*swapp-dimension-semantic-codes*`에 71, 72 포함)는 이를 값 변경으로 보고 스냅숏을 되돌려 `DIMTOL=1`을 다시 켰다. 2026-09-29 기록이 "두 경로의 결과에서 이 값 하나가 다를 수 있다"고 남겨 둔 차이다.

측정(사용자 도면 `261012_문자정리`): 치수 570개, 맞춤공차 39개, 그중 일반 공차도 켜진 것 11개(예: `D10(+0.12/+0.05)`, DIMTP 0.12, DIMTM −0.05).

고친 것:

- DIMSTYLE 비교: 맞춤공차 치수는 양쪽 기록에서 `DIMTOL`/`DIMLIM`을 뺀다(`swapp-semantic-mask-fit`), 되돌릴 때도 71·72를 빼고 되돌린다(`swapp-snapshots-without-fit-flags`).
- 새 단계 `FIT_TOLERANCE`: 이미 변환된 도면의 중복을 끈다.

시험:

- 사용자 도면 사본: `FIT_TOLERANCE` 11개 → 중복 0개, 맞춤공차 39개 모두 맞춤공차만, 치수 의미값(측정값·DIMLFAC·편차) 같음, `SWCADVERIFY_FINAL_OK`. `Downloads\221216_감속기시험기_261012_공차정리.dwg`로 줬다.
- 32장 실제 화면 전체 실행(결과 `work\sheet-format-test\e2e32_261016_122208.dwg`): SHEET_FORMAT 27초, TITLE 148초, DIMSTYLE 19초, FIT_TOLERANCE 12초(`NOT_NEEDED`), TEXT_STYLE 14초(7,646개 — CLEANUP 전이라 아직 지워지지 않은 SW 블록 정의 안 문자까지), TEXT_SIZE 93초(겹침 표시 64곳), LAYOUT 75초, CLEANUP 238초. 맞춤공차 41개 모두 일반 공차 꺼짐, `SWCADVERIFY_FINAL_OK`.
- 30장 회귀 시험(`run_title_value_test.ps1 -EndToEnd -FullWorkflow`): `RESULT: OK`, 표제란 330칸 계획과 같음, `SWCADVERIFY_FINAL_OK`.
