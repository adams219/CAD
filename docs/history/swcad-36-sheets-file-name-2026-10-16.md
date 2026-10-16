# 36장 다시 변환과 회사 양식 FILE NO - 2026-10-16

워크플로·모듈 `261016-file-name-1`.

## 요청

사용자가 221216 감속기 성능 시험기 DWG 폴더에 조립도를 더했다: `01-06-00-00_B.P Bearing Unit`, `02-00-00-00_Drive Part`, `02-09-00-00_D.P Bearing Unit`, `03-00-00-00_Specimen Part`, 그리고 `01-00-00-00_Brake Part_261016`(기존 Brake Part의 새 판). 기존 합친 도면(`Downloads\221216_감속기시험기_261012_공차정리.dwg`)의 배치를 옮겨 넣을지, 처음부터 다시 할지 물었다.

확인한 것:

- 프로그램은 빈 도면에서 모으기만 한다. 변환이 끝난 도면에 XREF를 더하면 단계 판정은 다시 돌지만, DIMSTYLE·TEXT_SIZE 등은 "이미 함" 표시가 있어 새 시트를 건너뛰고, TEXT_SIZE는 치수 배율을 곱하므로 다시 돌리면 기존 시트가 두 번 커진다. 끼워 넣기는 새 기능이 필요하다.
- 변환에 쓴 32장 사본(`work\xref-collect-test\source_260929`)과 비교하니 `01-03-00-00_L-Jig.DWG`도 10-16 13:53에 다시 저장되어 내용이 달랐다.
- BOM(`0_221216_디알드라이브_감속기 성능 시험기 BOM.xlsx`, 09-29 판)의 가공품 31개는 모두 DWG가 있다. LM Guide·Vibration Pad 조립도와 L-Jig 판 3종 도면이 없다고 알렸고, 사용자는 필요 없다고 했다.

사용자 결정: 10-12 이후 손으로 고친 것이 없으니 처음부터 다시 변환한다. Brake Part는 새 판을 `01-00-00-00_Brake Part`라는 이름으로, L-Jig는 새 판을 쓴다. 36장(32장 + 조립도 4장).

## 모으기

사본 `work\xref-collect-test\source_261016`(36개, `_source_hashes.csv`), `run_xref_collect_probe.ps1 -WorkCopy`. 줄 `(1 14 14 4 1 1 1)`, 배치 공간 도면 18장을 사본으로 바꿔 붙임, XREF 결합 뒤 단계 `SHEET_FORMAT`. 검사 53개 중 4개 실패: 한글 경로 변환 시험이 `01-03-00-00_*`을 배치 공간 도면 표본으로 쓰는데, 새 L-Jig는 모델 공간에 그려져 있어 "모델 공간이 비어 있지 않습니다"로 바꾸지 않았다. 표본의 가정이 바뀐 것이고 모으기 결과는 맞다.

## 회사 양식 시트

첫 실행(`work\sheet-format-test\e2e36_261016_172944.dwg`): `SWCADVERIFY_FINAL_OK`, 도면틀 36. 그런데 `02-09-00-00_D.P Bearing Unit`의 FILE NO가 `1234`, File Name이 `02-09-00-00_D.P Bearing Unit`이었다. 이 도면만 회사 전용 SolidWorks 양식(용지 420×297, 도면틀 블록 `DR-A3 FROM_HYUN`, 표제란 블록 `DR_표제란_FTAP`, File No 칸에 자리 표시 값 `1234`)이라 SHEET_FORMAT이 아니라 원래 GMTITLE 경로(칸 자리로 읽기)를 탔다. 10-08의 파일 이름 규칙은 SHEET_FORMAT에만 있었다.

사용자 결정: 회사 양식도 같은 규칙.

고친 것:

- 모듈: `swcad-title-transfer-values-at`. 원본 표제란 값 8곳이 모두 이 함수를 거치고, `*swcad-title-source-values-hook*`이 설정돼 있으면 `(values source-bbox)`로 한 번 부른다. 실패하면 읽은 값 그대로.
- 워크플로: `swapp-title-file-name-values`를 훅으로 설정. 표제란 상자 중심이 들어 있는 `SOURCE_SHEET` 기록의 파일 이름에 `swapp-swfmt-file-name-tags`를 쓴다. 겹친 면적이 아니라 중심으로 정해서, 원본 용지 밖에 놓이는 키운 도면틀의 새 표제란은 건드리지 않는다.

## 시험

- 정적 검사: `diagnostics\swcad-workflow\run_static_preflight.ps1` PASS(모듈 해시 갱신), `diagnostics\gmtitle-main45\run_static_preflight.ps1` PASS(안내 문서의 모듈 버전 갱신).
- 36장 실제 화면 전체 실행(결과 `work\sheet-format-test\e2e36_261016_175320.dwg`): SHEET_FORMAT 34초, TITLE 158초, DIMSTYLE 19초, FIT_TOLERANCE 13초(`NOT_NEEDED`), TEXT_STYLE 14초, TEXT_SIZE 156초(키운 도면 20장, 겹침 표시 64곳), LAYOUT 91초, CLEANUP 297초. `SWCADVERIFY_FINAL_OK`, 도면틀 36, Layout 36. 첫 실행과 표제란 36개를 칸마다 비교하니 02-09-00-00의 NR·DWG 두 칸만 달라졌다(`02-09-00-00` / `D.P Bearing Unit`).
- 새 조립도 5장(01-00, 01-06-00, 02-00, 02-09-00, 03-00)은 모두 A3, 척도 1:10 또는 1:5.
- 30장 회귀 시험(`run_title_value_test.ps1 -EndToEnd -FullWorkflow`, `tmp\gmtitle-value-test\261016_180957`): `RESULT: OK`, 표제란 330칸 계획과 같음, 지운 모델 공간 객체 1693개 그대로, `SWCADVERIFY_FINAL_OK`. 훅이 바꾼 칸 없음(이 시험의 시트 이름은 `P_eCVT-…`, `DH_…`처럼 도면번호로 시작하지 않는다).
- 결과를 사용자에게 `Downloads\221216_감속기시험기_36장_변환결과_261016.dwg`로 복사했다.
