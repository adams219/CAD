# CAD Tool Commands

이 문서는 현재 저장소에서 사용자가 직접 입력할 공개 명령만 정리한다.
테스트/비교/실험용 GMTITLE 명령은 `swcad_title_scale.lsp` 내부 함수로 남겨두되
CAD 명령창에 등록하지 않는다.

## 기본 로드

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

GMTITLE 도구만 직접 로드할 때:

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

## 치수/공차 명령

| 명령 | 용도 |
| --- | --- |
| `SWAUTO` | SolidWorks DWG 치수 스타일을 GstarCAD Mechanical 기준으로 정리하는 기본 자동 처리. |
| `SWHELP` | 사용 순서와 문제 해결용 명령을 출력. |
| `SWDIMKEEPAMISO` | 현재 탭 치수를 AM_ISO 계열 스타일로 매핑. |
| `SWMECHFITSEL` | 선택한 치수를 Mechanical 맞춤공차 xdata로 변환. |
| `SWMECHFITALL` | 현재 탭 대상 치수를 Mechanical 맞춤공차 xdata로 일괄 변환. |
| `SWPURGESTYLES` | 사용하지 않는 치수 스타일을 정리. |
| `SWFINDSTYLE` | `SLDDIMSTYLE*` 같은 특정 치수 스타일 사용 치수를 찾음. |
| `SWTRYDELDIMSTYLES` | 사용하지 않는 치수 스타일을 안전하게 삭제 시도. |
| `SWDEBUG` | 선택 치수의 스타일, 공차, fit code, `DIMLFAC`, xdata를 진단. |

## GMTITLE 공개 명령

| 명령 | 용도 | 변경 여부 |
| --- | --- | --- |
| `SWTITLEVERSION` | 현재 로드된 GMTITLE LSP 버전 확인. | 읽기 전용 |
| `SWTITLEMULTIPREVIEW` | 현재 도면의 A2/A3/A4 원본 시트 수를 빠르게 요약. | 읽기 전용 |
| `SWTITLEFASTSTATUS` | 빠른 변환을 시작할 준비 상태와 필요한 native exemplar를 확인. | 읽기 전용 |
| `SWTITLENEXTSTEP` | 현재 상태 기준 다음에 실행할 명령을 안내. | 읽기 전용 |
| `SWTITLETRANSFERPREVIEW` | 다음 표제란 변환 대상과 복사될 값을 미리 확인. | 읽기 전용 |
| `SWTITLETRANSFERAPPLY` | 표제란이 있는 한 장을 native GMTITLE로 생성하고 기존 원본 내용을 정리. | 변경 |
| `SWTITLETRANSFERBOOTSTRAPFAST` | 첫 native GMTITLE 생성 후 가능한 빠른 일괄 변환으로 이어감. | 변경 |
| `SWTITLETRANSFERFASTBATCH` | 준비된 native exemplar를 바탕으로 남은 시트를 빠르게 처리. | 변경 |
| `SWTITLEFRAMEONLYAPPLY` | A4처럼 원본 표제란 없이 도면틀만 있는 frame-only 시트를 처리. | 변경 |
| `SWTITLEA3A4NEXT` | native 인식이 불확실한 A3/A4 한 장을 실제 GMTITLE 결과로 교체. | 변경 |
| `SWTITLEA3A4ALL` | 남은 A3/A4 native 교체 후보 전체를 순서대로 처리. | 변경 |
| `SWTITLEUPGRADENATIVESTATUS` | A3/A4 중 아직 native 교체가 필요한 쌍을 확인. | 읽기 전용 |
| `SWTITLESTATUSREFRESH` | 주요 읽기 전용 상태 로그를 한 번에 갱신. | 읽기 전용 |
| `SWTITLEGMTITLEVERIFYALL` | 전체 DR_A2/A3/A4 frame/title 수, 원본 잔여물, native-like 상태 확인. | 읽기 전용 |
| `SWTITLENATIVEFRAMECHECK` | A2/A3/A4 native frame 완료 상태를 확인. | 읽기 전용 |
| `SWTITLEDOUBLECLICKCHECK` | 더블클릭 확인 위치와 주의할 frame/title 쌍을 출력. | 읽기 전용 |
| `SWTITLEPICKCHECK` | 선택한 title/frame이 native 교체 후보인지 진단. | 읽기 전용 |
| `SWTITLECOMMANDTEXTSCAN` | 잘못 입력되어 도면에 남은 명령어 텍스트를 검색. | 읽기 전용 |
| `SWTITLECOMMANDTEXTCLEANSAFE` | 작업복사본에서 명령어 텍스트 잔여물을 안전 삭제. | 변경 |
| `SWTITLESCAN` | 표제란/스케일 후보 원시 진단. | 읽기 전용 |
| `SWSCALESCAN` | 표제란 스케일과 치수 `DIMLFAC` 후보를 비교. | 읽기 전용 |

## GMTITLE 기본 흐름

```text
SWTITLEVERSION
SWTITLEMULTIPREVIEW
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEA3A4ALL
SWTITLESTATUSREFRESH
SWTITLEGMTITLEVERIFYALL
```

A4 frame-only가 남으면 중간에 아래를 사용한다.

```text
SWTITLEFRAMEONLYAPPLY
```

## 공개 명령에서 뺀 항목

아래 명령은 실험, 비교, 긴 별칭, 수동 복구용으로 만들었던 항목이다.
현재 최종 사용 흐름에서는 직접 입력하지 않도록 공개 `c:` 명령에서 제거했다.

| 제거된 공개 명령 | 이유 |
| --- | --- |
| `SWTITLEDEBUG`, `SWTITLETEXTSCAN`, `SWTITLEMULTIDETAIL`, `SWTITLEFRAMESCAN` | 초기 조사/원시 로그용. |
| `SWTITLEGMTITLEVERIFY` | 단일 검증용. 전체 검증 `SWTITLEGMTITLEVERIFYALL`로 통합. |
| `SWTITLEROLECHECK`, `SWTITLEA3A4FIXPLAN` | `SWTITLESTATUSREFRESH`와 `SWTITLEUPGRADENATIVESTATUS` 안에서 사용. |
| `SWTITLEGMTITLELINKSCAN`, `SWTITLEGMTITLELINKDETAIL`, `SWTITLEGMTITLECOMPARE` | native-link 원인 조사용. |
| `SWTITLEGMTITLEPRESERVECOPYTEST` | preserve-copy 실험용. |
| `SWTITLEUPGRADENATIVEONE`, `SWTITLEUPGRADENATIVESELECT`, `SWTITLEUPGRADENATIVEA3A4NEXT` | 긴/범용 별칭. `SWTITLEA3A4NEXT`로 통합. |
| `SWTITLEA3A4PREP`, `SWTITLEA3A4FINISH` | 좌표를 사람이 치던 수동 단계. `SWTITLEA3A4NEXT`로 대체. |
| `SWTITLEUPGRADENATIVEBATCH`, `SWTITLEUPGRADENATIVEA3A4BATCH`, `SWTITLEUPGRADENATIVEA3A4ALL`, `SWTITLEA3A4BATCH`, `SWTITLEUPGRADENATIVEA3A4BATCHMANUAL` | 긴 batch 별칭. `SWTITLEA3A4ALL`로 통합. |
| `SWTITLEFRAMEDEFCHECK`, `SWTITLEFRAMEDEFCLEANSAFE`, `SWTITLEREPAIRFRAMEDEFS` | frame definition 오염 조사/복구용 내부 지원. |
| `SWTITLETRANSFERFINALIZE`, `SWTITLETRANSFERBATCH`, `SWTITLETRANSFERCLONEAPPLY`, `SWTITLETRANSFERCLONEBATCH` | 이전 수동/clone 흐름. 빠른 흐름으로 대체. |
| `SWTITLEFRAMEONLYFINALIZE`, `SWTITLEFRAMEONLYCLONEAPPLY`, `SWTITLEFRAMEONLYCLONEBATCH` | 이전 A4 frame-only 수동/clone 흐름. `SWTITLEFRAMEONLYAPPLY`로 대체. |
