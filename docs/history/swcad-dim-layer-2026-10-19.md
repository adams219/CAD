# 치수 레이어 AM_5 (DIM_LAYER) - 2026-10-19

워크플로 `261019-dim-layer-1`. 모듈은 그대로다.

## 요청

사용자 도면 `감속기시험기_통합도면_LKS_261019.dwg`(OneDrive, 10-16 36장 결과를 손본 것)의 치수가 레이어 0에 있다. 모두 AM_5로 바꾸고 싶고, LSP의 어느 단계에서 바꿔야 하는지 물었다.

실측(사본, 별도 `/b` 창):

| 레이어 | 치수 |
| --- | --- |
| `0` | 433 (색 7 직접 지정 대부분) |
| `AM_5` | 39 (변환 뒤 Mechanical로 넣은 것) |
| `<파일>$0$AM_5` 6개 | 103 (회사 양식 SolidWorks 도면의 AM_5가 BIND로 이름이 바뀜) |

AM_5 레이어는 도면에 있다(색 3, 0.25 mm). 치수 스타일 `AM_ISO*`는 DIMCLRD/DIMCLRE 3, DIMCLRT 2라 개체 색과 관계없이 치수선·글자 색은 같다. 지시선 69, 주석 MTEXT 219, SW 주석 블록 73도 레이어 0이다. 쓰는 객체가 없는 `AM_05` 레이어가 하나 있다.

사용자 결정: 치수만 AM_5로, 색은 ByLayer로. 프로그램에 넣고 지금 도면에도 적용.

## 바꾼 것

새 단계 `DIM_LAYER`(TEXT_STYLE 다음, TEXT_SIZE 전). 이미 변환이 끝난 도면은 이 단계 표시가 없으므로 `SWCADRUN`이 이 단계부터 한다. DIMSTYLE 안에 넣으면 이미 변환한 도면에서는 돌지 않는다.

- 모델 공간 치수 중 AM_5가 아니거나 ByLayer가 아닌 것을 AM_5, 색 256으로.
- AM_5가 없으면 색 3, 선 두께 0.25로 만든다.
- 아무 객체·속성도 쓰지 않게 된 `…$0$AM_5` 레이어를 지운다.
- 치수 의미값 전후 다중집합이 같고 남은 대상·실패가 0이어야 `OK`. `SWCADVERIFY`와 `workflow_final_verify_probe.lsp`가 `DIM_LAYER`를 본다.

## 시험

- 정적 검사 `run_static_preflight.ps1`: PASS.
- 36장 결과 사본(`work\dim-layer-test\e2e36_261019_104041.dwg`, `/b`, 사용자 CAD는 열린 채 별도 창): 단계 `DIM_LAYER` → `SWCADRUN` → 치수 574개 이동(레이어 0 471개, `$0$AM_5` 103개), `$0$AM_5` 레이어 6개 삭제, 치수 의미값 같음 → 다음 단계 `CLEANUP` → `SWCADRUN` → `COMPLETE`. `SWCADVERIFY_FINAL_OK`, `DIM_LAYER=OK count=574`.
- 사용자 도면 사본(`work\dim-layer-test\lks_261019_105217.dwg`, 원본 10-19 10:23 저장본): 치수 536개 이동(레이어 0 433개, `$0$AM_5` 103개), 575개 모두 AM_5·ByLayer, 의미값 같음, `$0$AM_5` 레이어 6개 삭제. 다음 단계는 `LAYOUT`이라 시험 스크립트가 멈췄다(손본 도면이라 Layout 계획 지문이 다름. `SWCADRUN`을 계속하면 Layout 36개를 다시 만든다). 바꾸기 전 사본도 `DIMSTYLE` 감사·`CLEANUP`·`LAYOUT`이 이미 `no`, `SWCADVERIFY_FINAL_FAIL`이었다(손으로 넣은 치수와 Layout 변경). 바뀐 것은 `DIM_LAYER`뿐이다. 사용자에게 `Downloads\감속기시험기_통합도면_LKS_261019_치수AM5.dwg`로 줬다.
- 새 변환 전체 실행(보이는 CAD, COM)은 사용자 CAD가 열려 있어 하지 않았다.
