# CAD Tool 명령어

이 문서는 사용자가 CAD 명령창에 직접 입력하는 공개 명령만 정리합니다.

## 기본 로드

GstarCAD에서 `APPLOAD`를 실행한 뒤 아래 파일을 로드합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

GMTITLE 도구만 직접 로드할 때는 아래 파일을 사용할 수 있습니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

로드된 GMTITLE 버전 확인:

```text
SWTITLEVERSION
```

현재 기준 버전:

```text
260704-overlap-only-main50
```

## GMTITLE 변환 명령

SolidWorks DWG의 도면틀/표제란을 GstarCAD Mechanical GMTITLE 구조로 바꾸는 작업은 아래 4개 명령만 사용합니다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

| 명령 | 용도 | 도면 변경 |
| --- | --- | --- |
| `SWTITLESTATUS` | 현재 DWG 상태를 읽기 전용으로 진단하고 다음에 실행할 명령을 안내합니다. work 복사본 여부, 원본 시트 수, A2/A3/A4 예상 수량, 도면틀 정의 상태, A4 frame-only 상태를 확인합니다. | 없음 |
| `SWTITLEPREPARE` | 변환 전에 필요한 정규화를 수행합니다. 실수 명령어 텍스트, 도면틀 정의 내부 표제란 형상, 고아 GMTITLE 도면틀 같은 후보를 먼저 보여주고 `YES` 확인 후 처리합니다. | 있음 |
| `SWTITLECONVERT` | 상태에 맞는 변환 단계를 실행합니다. 첫 native GMTITLE 생성, 같은 크기 기준 객체 준비, 남은 시트 변환, A3/A4 native 교체, A4 frame-only 처리를 이 명령 안에서 안내합니다. | 있음 |
| `SWTITLEVERIFY` | 변환 결과를 읽기 전용으로 검증합니다. 남은 원본 객체, 중복/누락, native-like 상태, A2/A3/A4 수량, 최종 OK/WARN/FAIL을 확인합니다. | 없음 |

## 권장 실행 순서

항상 상태를 먼저 보고 다음 명령을 결정합니다.

```text
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE    상태가 요구할 때만
SWTITLESTATUS
SWTITLECONVERT    상태가 요구할 때만
SWTITLESTATUS
SWTITLEVERIFY     최종 검증 단계에서
```

`SWTITLESTATUS`가 `SWTITLEPREPARE`를 안내하면 변환을 반복하지 말고 먼저 정규화합니다.

`SWTITLESTATUS`가 `SWTITLECONVERT`를 안내하면 변환을 실행합니다.

`SWTITLESTATUS`가 검증을 안내하면 `SWTITLEVERIFY`를 실행합니다.

## GMTITLE 창에서 확인할 값

`SWTITLECONVERT` 중 GMTITLE 창이 열리면 로그가 요구한 값만 선택합니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

사용하지 않을 것:

```text
일반 A2/A3/A4 용지
ISO 제목블록
스크린샷 좌표 클릭
긴 소수점 좌표 수동 입력
옛 transfer/fast/frame-only/A3A4 명령
```

## 옛 GMTITLE 명령

아래 명령들은 예전 실험/진단/복구 흐름에서 사용하던 이름입니다. 현재 일반 작업에서는 직접 입력하지 않습니다.

```text
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
SWTITLEGMTITLEVERIFYALL
```

이 명령들이 여전히 실행된다면 오래된 LSP가 로드된 상태일 수 있습니다. `swcad_load.lsp`를 다시 APPLOAD 하고 `SWTITLEVERSION`부터 확인하세요.

## GMTITLE 로그 파일

주요 로그는 `work` 폴더 아래에 저장됩니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

자주 보는 로그:

| 로그 | 의미 |
| --- | --- |
| `swcad_title_structure_diagnosis_last.txt` | `SWTITLESTATUS`의 구조 판단 요약 |
| `swcad_title_frame_embedded_title_clean_last.txt` | 도면틀 내부 표제란 형상 정리 로그 |
| `swcad_title_frame_style_normalization_clean_last.txt` | 도면틀 스타일 정규화 로그 |
| `swcad_title_transfer_apply_last.txt` | 첫 native GMTITLE 변환 단계 로그 |
| `swcad_title_fast_status_last.txt` | 내부 빠른 변환 준비 상태 로그 |
| `swcad_title_verify_summary_last.txt` | `SWTITLEVERIFY` 최종 요약 |

## 완료 기준

완료는 아래 조건을 모두 만족할 때만 인정합니다.

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
frame-only 시트: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```

## 치수/공차 명령

기존 치수/공차 작업 명령은 유지합니다.

| 명령 | 용도 |
| --- | --- |
| `SWAUTO` | SolidWorks DWG 치수 스타일을 GstarCAD Mechanical 기준으로 정리하는 기본 자동 처리 |
| `SWHELP` | 사용 순서와 문제 해결 명령 출력 |
| `SWDEBUG` | 선택 치수의 스타일, 공차, `DIMLFAC`, xdata 진단 |
| `SWFINDSTYLE` | 특정 치수 스타일을 사용하는 치수 찾기 |
| `SWTRYDELDIMSTYLES` | 사용하지 않는 치수 스타일 삭제 시도 |
| `SWDIMKEEPAMISO` | 현재 치수를 AM_ISO 계열 스타일로 매핑 |
| `SWMECHFITSEL` | 선택 치수를 Mechanical 맞춤공차 xdata로 변환 |
| `SWMECHFITALL` | 현재 도면의 치수를 Mechanical 맞춤공차 xdata로 일괄 변환 |
| `SWPURGESTYLES` | 사용하지 않는 치수 스타일 정리 |
