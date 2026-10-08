# SWCAD Workflow 통합 구조

## 목적

SolidWorks DWG를 XREF로 모은 새 호스트 도면에서 기존 세 도구를 다음 순서로 연결한다.

```text
XREF 독립 작업본 생성 및 materialize
→ native GMTITLE 변환
→ 치수/공차 정규화
→ 원본 파일명 A4 Layout 생성
→ 전체 미사용 이름 정의 정리
→ 통합 검증
```

기존 모듈은 각 기능의 단일 소유자로 유지한다. 통합 앱은 상태 판정, 단계 연결, 원본 보호, 단계 사이의 계약 검증만 담당한다.

GstarCAD는 로드 중인 LSP의 원본 경로를 안정적으로 제공하지 않는다. 배포 ZIP의 `Install_SWCAD_Workflow.cmd`는 현재 패키지 절대 경로가 들어간 `SWCAD_Workflow_Load.lsp`를 생성한다. 이 루트 로더가 환경 경로를 먼저 갱신한 뒤 내부 로더를 호출하므로 다른 PC의 예전 개발 경로를 잘못 사용하지 않는다. 패키지를 옮긴 경우 설치 파일을 다시 실행한다.

| 소유 모듈 | 역할 |
| --- | --- |
| `src/tools/gmtitle` | 원본 도면틀/표제란 감지, 작업본 Save As, native GMTITLE 생성·정리·검증 |
| `src/tools/gstarcad-dimstyle` | AM_ISO 스타일 통일, Mechanical 맞춤공차 변환, 스타일 감사 |
| `src/tools/gstarcad-layout` | 모델 공간 도면틀 범위를 A4 Layout과 뷰포트로 생성 |
| `apps/swcad-workflow` | XREF materialize와 세 모듈의 상태 기반 오케스트레이션 |

## 공개 명령

통합 앱이 추가하는 공개 명령은 세 개뿐이다.

```text
SWCADSTATUS
SWCADRUN
SWCADVERIFY
```

`SWCADRUN`은 현재 상태에서 다음 안전 단계 하나만 실행한다. 중간에 종료해도 DWG의 `SWCAD_WORKFLOW_STATE` XRecord를 읽어 재개한다. 단계는 사용자에게 0/6(빈 도면의 도면 모으기)부터 6/6까지 표시하며, GMTITLE 결과가 `ABORT_`, `ERROR_`, `WARN_`이면 같은 명령의 반복을 권장하지 않는다.

```text
COLLECT(빈 도면) → XREF → SHEET_WRAPPERS(필요한 경우) → SHEET_FORMAT(필요한 경우) → TITLE → DIMSTYLE → LAYOUT → CLEANUP → COMPLETE
```

## COLLECT: 도면 모으기

모델 공간이 빈 도면에서 `SWCADRUN`을 실행하면 0/6 `COLLECT` 단계가 된다. 수동 XATTACH와 클릭 배치만 대신하고, 그 뒤 단계는 수동 배치와 같다.

- 여러 SolidWorks DWG를 모으는 방법은 XREF + BIND다. SolidWorks DWG는 파일마다 같은 블록·스타일 이름을 0부터 다시 쓴다(`SW_CENTERMARKSYMBOL_0`, `SW_TABLEANNOTATION_0`, `DR_표제란_FTAP`, `SLDDIMSTYLE0` 등). 복사·붙여넣기나 INSERT는 먼저 들어온 정의만 남겨 다른 시트의 중심 표시가 틀리게 그려졌다. BIND는 이름 앞에 파일 이름(`파일$0$이름`)을 붙인다. 그래서 Insert형 BIND, 복사·붙여넣기, 일반 INSERT를 쓰지 않고, 파일마다 XREF 이름이 달라야 한다.
- 파일 선택은 `apps/swcad-workflow/swcad_pick_dwgs.ps1`(Windows 파일 창, 여러 개 선택)로 한다. 결과를 UTF-8과 ANSI 두 파일로 쓰고, 경로가 모두 있는 쪽을 읽는다. SCRIPT 실행 중에는 창을 열지 않는다(`BLOCKED_COLLECT_SCRIPT_ACTIVE`).
- 순서는 Windows 탐색기 이름순(숫자는 값으로 비교)이다. 이름이 두 개 이상의 숫자 묶음을 `-`로 이은 도면번호로 시작하면 첫 번호마다 한 줄이고, 그 밖의 파일은 마지막 줄들에 10장씩 놓는다. 간격은 두 이웃 도면(줄 사이면 두 줄의 모든 도면) 가운데 큰 쪽의 `max(50 mm, 긴 변의 10%)`(`swapp-collect-item-gap`)다. 50 mm에서는 키운 도면틀(221216의 06 A0×4, 07 A0×2)이 서로 1 mm 겹쳤다. 같은 줄은 도면틀 윗선(도면틀 블록이 없으면 XREF 전체 범위의 윗선)을 맞춘다. 따라서 Layout 순서 규칙(같은 행 왼쪽→오른쪽, 행은 위→아래)이 이름 순서를 그대로 읽는다.
- 모델 공간이 빈 파일(SolidWorks `용지 공간으로 모든 도면 시트 내보내기`)은 XREF가 비어 보인다. 이런 파일은 `%LOCALAPPDATA%\SWTitle\collect\<시각>\<n>\`에 같은 파일 이름으로 복사하고, 그 사본을 열어 내용이 있는 배치 탭 하나의 객체를 `CopyObjects`로 모델 공간에 옮긴 뒤 저장해 원본 대신 붙인다. 고른 원본은 CAD로 열지 않는다. 파일 이름이 같으므로 `SOURCE_SHEET_*`의 stem과 Layout 이름은 원본 파일명이다. 내용 있는 배치 탭이 둘 이상이거나 음수 `DIMLFAC`(배치 공간에서만 적용) 치수가 있으면 `STOP_COLLECT_PAPER_SHEET`로 멈춘다.
- GstarCAD 동작(2026-09-30 실측): ObjectDBX(`ObjectDBX.AxDbDocument.24`)는 만들 수 없다. `Documents.Open`은 가끔(28회 중 2회) 파일을 열고도 `Expecting object to be local` 오류를 돌려주므로, 다시 열지 않고 열린 문서 목록에서 찾는다. 다시 열면 "이미 열려 있음" 확인 창에서 멈춘다. `Close`는 다른 도면을 열거나 활성화할 때 끝나므로 닫은 뒤 호스트를 `Activate`한다.
- 한 장이라도 붙이기·변환·범위 읽기·이동에 실패하면 그 실행에서 붙인 XREF를 모두 떼어 낸다. 모든 메시지는 `swcad_collect_last.txt`에도 남긴다.

## SHEET_FORMAT: 선과 글자로 된 SolidWorks 기본 양식

SolidWorks 기본 한국어 양식은 DWG에서 도면틀·표제란이 LINE과 MTEXT뿐이다. TITLE 단계는 도면틀·표제란 INSERT로만 시트를 찾으므로, 모델 공간에 앵커 글자 `도면의 배율을 변경하지 마시오.`가 있으면 TITLE 전에 `SHEET_FORMAT` 단계가 된다(`swapp-convert-sheet-formats`).

- 인식: 앵커에서 안쪽 테두리 오른쪽 아래 모서리 C를 구하고, 칸 이름 17개가 C 기준 고정 위치(±1 mm)에 있는지, C에서 시작하는 안쪽 테두리와 5 mm 바깥 테두리의 네 변이 모두 있는지 본다. 모든 크기에서 표제란은 C 기준 180×55.25 mm로 같다. 시트마다 `SOURCE_SHEET` 범위 안의 객체만 본다(도면 전체 반복은 수 분이 걸렸다).
- 용지: 바깥 테두리 + 왼쪽 15, 오른쪽·위·아래 5 mm. DR 도면틀(A1~A4 실측)은 안쪽 테두리가 용지 왼쪽에서 20, 나머지에서 10 mm이고 SolidWorks 양식은 좌우 15, 상하 10 mm라서, 이렇게 잡으면 두 안쪽 테두리가 겹치고 새 표제란 왼쪽 아래가 옛 표제란 왼쪽 아래와 같다. A0~A4(±1 mm)와 DR 도면틀 방향(A4 세로, 나머지 가로)이 맞아야 한다. 해당 `DR_Ax_Outline.dwg`가 GstarCAD `Dwg\Format` 폴더에 있어야 한다(A0는 기본 설치에 없음).
- 값: C 기준 칸 영역(`*swapp-swfmt-cells*`)으로 읽는다. 글자는 삽입점, 주석 블록은 중심으로 칸을 정한다(긴 도면 번호 글자는 표제란 오른쪽 선을 넘는다). `도면 번호`→NR, `제목`→DWG, `배율:`→SCA, `재질:`→MAT1, `수정본`→REV, `작성` 이름·날짜→NAME·DATE, `검사`·`승인` 이름→CHKM·APPM. 파일 이름은 쓰지 않는다(사용자 결정 2026-09-30). 칸이 없는 글자는 `swcad_sheet_format_last.txt`에만 남긴다.
- 변환: 테두리 8선, 바깥 테두리에서 시작하는 10.5 mm 이하 눈금선, 테두리 사이 구역 글자, 표제란 안의 선·글자·주석 블록을 `SWFMT_<크기>_OUTLINE_nn` 블록(용지 외곽선 추가, 기준점은 용지 왼쪽 아래)으로 옮긴다. `SWFMT_TITLE_nn`은 표제란 외곽선과 11개 `GEN-TITLE-*` 속성을 `DR_titlea_3rd` 칸 위치에 가진다. 모든 시트의 블록 쌍을 먼저 만들고 성공하면 원래 객체를 지운다. 실패하면 만든 것을 지우고 멈춘다.
- 사용자 크기 용지(표제란이 안쪽 테두리 모서리에 없거나 A0~A4가 아님): 안쪽 테두리는 표제란 아래를 지나는 가로선과 그 오른쪽 끝의 세로선으로 찾는다. 도면을 1:1로 두고 DR 도면틀을 GMTITLE 축척 k(1:2, 1:2.5, 1:4, 1:5, 1:10 … 1:100)로 키운다(`swapp-swfmt-scaled-choice`). k가 작은 것부터, 같은 k에서는 작은 용지부터, 키운 용지가 SolidWorks 용지(바깥 테두리 + 5 mm)를 덮고 도면 전체(원·치수 포함, `swapp-swfmt-content-boxes`)가 키운 안쪽 테두리(20k/10k) 안에 있으며 키운 표제란 자리(오른쪽에서 190k~6.4k, 아래에서 10k~52k)와 겹치지 않는 것. 자리 후보는 도면 내용 가운데(바깥 테두리는 용지 안) 다음 SolidWorks 용지의 네 모서리 맞춤이고, `swapp-swfmt-place-papers`가 다른 시트 용지와 겹치지 않는 첫 자리를 고른다. 도면 블록 이름에 k가 들어가고(`SWFMT_A0_OUTLINE_S4_05`, 2.5는 `S2P5`), 표제란 SCA는 GMTITLE이 적는 `1:k`로 둔다(사용자 결정).
- 도면틀 없는 시트(도면틀 블록도 앵커도 없는 `SOURCE_SHEET`, 사용자 결정 2026-10-08, `swapp-swfmt-frameless-sheet`): `SOURCE_SHEET` 범위 안 모델 객체 전체가 도면 내용이다. 사용자 크기와 같은 순서(k, 그다음 용지)로, 키운 안쪽 테두리가 내용을 담고 내용이 키운 표제란 자리와 새 `SWFMT_TITLE` 상자(180×55.25, 안쪽 테두리 오른쪽 아래)에 닿지 않는 조합을 고른다(`swapp-swfmt-frameless-choice`). 자리 후보는 내용 가운데, 그다음 내용 모서리를 안쪽 테두리 모서리 5k 안에 맞춘 네 자리다. 옮길 양식 객체가 없어 `SWFMT_<크기>_OUTLINE`에는 용지 외곽선만, `SWFMT_TITLE`에는 SIZ·SCA 값만 들어간다. 내용 둘레에 테두리 선(네 변을 90% 이상 덮는 선 또는 내용 범위와 같은 닫힌 폴리선)이 있으면 모르는 양식으로 보고 `NO_FORMAT`으로 멈춘다(`swapp-swfmt-border-around-p`). 08 Drive Base Plate(배치 공간 A0 시트, 내용 2064×850): `DR_A0_Outline` 1:2.
- 인식하지 못한 시트가 하나라도 있으면(방향, 담을 조합 없음, 도면틀 파일 없음, 도면틀 겹침, 잠긴 레이어, 내용이 없거나 모르는 테두리가 있는 도면틀 없는 시트) 아무것도 바꾸지 않고 `STOP_SHEET_FORMAT_UNSUPPORTED`로 목록을 보여 준다.
- 모듈: `transfer-apply`가 원본 도면틀 이름의 k를 `*swcad-title-next-gmtitle-scale*`에 넣고, GMTITLE 입구(`swcad-title-run-native-gmtitle-prefer-commandline`)가 한 번 받아 자동 선택기에 `-ExpectedScale 1:k`로 넘긴 뒤 1:1로 되돌린다. 자동 선택기는 축척(3013)을 매번 고르고(창이 마지막 축척을 기억함) `재축척 수행`(3023)을 끈다. 원본 도면틀 후보는 k로 나눈 크기로, native 도면틀 크기 경고는 양 변이 공칭×k(1% 이내)이면 공칭×k와 비교한다. 1:1 도면의 판정은 그대로다.
- TITLE 단계는 이 쌍을 결합된 속성 표제란과 도면틀로 보고 변환한다. `SWFMT_*` 도면틀에는 시트 잔여물 영역(왼쪽 아래 로고, 위쪽 노트)을 쓰지 않는다. 양식 객체가 모두 블록 안에 있어 짐작으로 지울 것이 없고, 그 영역에는 도면 내용만 있기 때문이다.
- XREF 단계 성공 조건은 원본 도면틀 블록 또는 앵커 글자가 있는 것이다.

## 성능 구조

- `SWCADSTATUS`, `SWCADRUN`, `SWCADVERIFY`는 명령이 시작될 때 읽기 전용 인벤토리를 만들고 같은 명령 안의 단계 판정과 상태 출력이 이를 공유한다.
- 도면이 실제로 변경되는 단계 직전에는 캐시를 닫고, 변경 직후 한 번만 새 인벤토리를 만든다. 변경 전 객체를 변경 후에 재사용하지 않는다.
- GMTITLE 모듈은 모델 공간 INSERT 목록을 명령당 한 번 물리 스캔하고, 도면틀·제목블록·원본 후보 판정은 같은 목록을 재사용한다.
- 여러 시트 변환은 시작 시 대상 레코드 큐를 한 번 만들고, 각 시트 처리 전 전체 도면을 다시 스캔하지 않는다. 큐의 객체가 사라졌거나 형상이 달라지면 안전하게 중단한다.
- XREF와 wrapper 탐색은 모델 공간의 모든 객체를 COM으로 열거하지 않고 `INSERT` 선택집합만 읽는다. 치수 의미 검사는 `DIMENSION` 선택집합만 읽는다.
- 같은 wrapper 블록 정의가 여러 번 삽입되면 내부 frame/title/dimension 증거는 정의별 한 번만 계산한다.
- 중간 상태 판정도 현재 도면의 `INSERT`를 읽어 wrapper가 다시 생기지 않았는지 확인한다. 실제 변환 직후와 최종 `SWCADVERIFY`에서는 수량·치수·bbox 등 결과 안전 조건을 깊게 검사한다.
- 모델 공간 전체 객체 순회는 bbox 보존 안전 감사에만 허용한다.
- 전체 정리의 생산적인 PURGE 반복 사이에는 모델·Layout 객체 수, 치수 의미, GMTITLE 링크·속성, Layout 용지·viewport와 workflow 상태로 구성한 경량 무결성 지문을 사용한다. 삭제 0개 반복은 바로 이어지는 전체 저장 전 감사와 중복되므로 중간 지문을 생략한다.
- 정리 단계가 만든 after/definition snapshot은 같은 명령의 최종 검증과 읽기 캐시에 넘긴다. 공개 `SWCADVERIFY`는 이 캐시를 사용하지 않고 현재 DB에서 새 snapshot을 만든다.
- 모델 bbox를 포함한 전체 감사는 첫 저장 전 한 번, 정리 성공 상태를 기록한 뒤 한 번 실행한다. 따라서 반복당 전체 bbox 재스캔은 제거하지만 저장 경계의 형상 보존 계약은 유지한다.

30장 기준 materialize 구간 실측은 `SWCADRUN 124,921 → 53,833 ms`, `SWCADSTATUS 28,674 → 842 ms`다. 정리 직전 동일 복사본의 정리 구간 `SWCADRUN` 3회 중앙값은 `286,247 → 167,202 ms`로 41.6% 줄었다. 자세한 측정 조건과 안전 검증은 `cleanup-performance-test-2026-07-19.md`에 기록한다.

## XREF materialize 결정

실제 GstarCAD 비교 결과에 따라 원본 SolidWorks XREF는 `BIND` 후 최상위 참조를 한 번 `EXPLODE`한다. XREF 아래에 시트 전체를 감싼 블록이 있으면 추가 구조 정규화를 수행한다.

- Attached 상태는 치수와 원본 도면틀이 XREF 내부에 남아 후속 모듈이 직접 처리할 수 없다.
- BIND만 한 상태도 최상위 객체가 블록 참조라 후속 모듈의 원본 시트 감지가 되지 않는다.
- BIND 후 1회 EXPLODE는 치수 143개, 원본 title/frame 15/15, 전체 bbox와 치수 의미 해시를 유지한다.
- 시트 전체 블록은 도면 내용, 치수, DR 도면틀, DR 표제란을 함께 품는다. 이를 frame-only 도면틀로 오인해 삭제하면 도면 전체가 사라질 수 있으므로 바깥 INSERT부터 분리한다.
- DR 도면틀·표제란은 유지하고, 치수가 들어 있는 비대상 내용 블록만 반복 EXPLODE해 DIMSTYLE이 모든 치수를 볼 수 있게 한다.
- 같은 블록 정의가 여러 번 삽입되면 deep 치수도 삽입 횟수만큼 계산한다. 순환 참조는 스택으로 차단한다.
- native XREF 차단은 이름 하나가 아니라 XREF 최상위의 DR frame/title 동시 존재로 판정한다. 시트 묶음 안의 이름만 같은 DR 블록은 변환 대상으로 통과시킨다.
- 이미 native GMTITLE인 XREF는 EXPLODE할 때 native link가 사라지므로 자동 materialize를 차단한다.
- 중첩/미참조 XREF, 축척 1 이외, 회전 0 이외도 MVP에서 차단한다.

부분 materialize 작업본도 자동 복구한다. 최상위 XREF는 없지만 시트 묶음이 남아 있으면 `SHEET_WRAPPERS`가 먼저 실행되고, 성공 조건은 묶음 0, instance-aware deep 치수와 최상위 치수 일치, 모델 bbox 보존, 원본 title/frame 감지다.

첫 변경 전에 GMTITLE 모듈의 Save As 계약을 사용한다. 사용자가 정한 별도 작업본만 변경하며 호스트 원본과 XREF 원본은 저장하지 않는다.

## 출처 메타데이터 계약

XREF를 BIND/EXPLODE하면 원본 경로와 참조명이 사라진다. 따라서 materialize 직전에 최상위 XREF를 사용자의 좌표 순서로 정렬하고 다음 값을 DWG 내부 `SWCAD_WORKFLOW_STATE` XRecord에 기록한다.

```text
SOURCE_SHEET_COUNT
SOURCE_SHEET_001...
  = order | source DWG stem | reference name | reference handle | bbox
SOURCE_SHEET_STATUS=CAPTURED_BEFORE_BIND
```

GMTITLE 변환 뒤에는 최종 frame/title 핸들과 출처를 `FINAL_SHEET_*`에 연결한다. 이미 materialize된 구버전 도면은 `GMTITLE File Name → 검증된 $0$ 결합 블록 접두사 → FILE NO → Sheet → frame handle` 순으로 복구한다. 하나의 일반적인 파일명이 여러 시트에 반복되면 그 값은 출처로 채택하지 않고 공간적으로 해당 frame 안에 가장 많이 나타나는 결합 블록 접두사를 사용한다.

## 표제란 값 보존

GMTITLE 단계는 새 `DR_titlea_3rd`의 11칸을 모두 쓴다(2026-09-29, `260929-title-values-1`).

- 원본 표제란 INSERT에 `GEN-TITLE-*` 속성이 있으면(예: 결합된 `...$0$DR_titlea_3rd`) 태그로 읽는다. 같은 칸 위치의 글자보다 우선한다.
- 일반 TEXT/MTEXT 원본은 기존처럼 칸 위치로 읽는다. MTEXT 서식 코드는 지운다.
- 원본에 값이 없는 칸은 `DR_titlea_3rd` 속성 기본값으로 채운다. 날짜는 변환한 날, 도면번호·도면명·용지 칸은 빈칸이다. GMTITLE이 넣는 `XXX`, 파일 경로, 로그인 이름, 다른 시트에서 복사된 값은 남기지 않는다.
- 값을 쓴 뒤 11칸을 다시 읽어 비교하고, 다르면 원본 표제란을 지우기 전에 멈춘다.
- `SWTITLEVERIFY`(따라서 `SWCADVERIFY`)는 제목블록에 `XXX`, 파일 경로, 서식 코드가 남아 있으면 `SWTITLEVERIFY_WARN_TITLE_VALUES`로 막는다.

회귀 테스트: `diagnostics/gmtitle-values/run_title_value_test.ps1`. 상세 기록: `docs/history/gmtitle-title-values-2026-09-29.md`.

옛 표제란 정리는 옛 표제란 상자 안의 선·해치와, 표제란에 닿은 도면틀 테두리 여백(11 mm)의 조각만 지운다. 찾는 범위는 원본 시트가 있는 공간이다. 삭제는 이미 지운 객체를 다시 건드리지 않는다(`entdel` 재호출은 객체를 되살린다). 옛 표제란·도면틀·글자가 잠긴 레이어에 있으면 GMTITLE 생성 전에 `ABORT_SOURCE_ON_LOCKED_LAYER`로 멈추고, 변환 뒤 남아 있으면 `REVIEW_OLD_TITLE_NOT_DELETED`로 멈춘다. 상세 기록: `docs/history/gmtitle-delete-safety-2026-09-29.md`.

## 치수 의미 보존

대표 도면에서 기존 SWAUTO는 스타일 감사 자체는 통과했지만, native Mechanical fit 적용 중 핸들 `37C1`의 의미 오버라이드가 다음처럼 달라지는 사례가 발견됐다.

```text
전: raw=6, DIMLFAC=0.5, upper/lower=0/0
후: raw=12, DIMLFAC=1, upper/lower=0.1/0.1
```

통합 앱은 SWAUTO 실행 전 모든 치수의 핸들별 측정값, `DIMLFAC`, 상·하 공차와 공차 표시 플래그를 저장한다. SWAUTO 후 달라진 핸들만 찾아 Mechanical XData는 유지한 채 ACAD DSTYLE 의미 오버라이드를 복원한다. 전후 다중집합이 완전히 같을 때만 다음 상태를 기록한다.

```text
DIMSTYLE=OK
DIMENSION_SEMANTICS=PRESERVED
```

복원 후에도 기존 스타일 감사와 Mechanical fit 감사가 모두 통과해야 한다.

2026-09-29부터는 SWAUTO 모듈이 같은 값을 직접 지킨다. `37C1` 사례의 원인은 맞춤공차 적용이 아니라 1단계 스타일 변경이었다. 공차가 없는 치수는 DSTYLE override가 통째로 지워져 `DIMLFAC`와 숨은 공차값이 대상 스타일 값으로 돌아갔다. 지금은 이런 치수도 대상 스타일과 다른 `DIMLFAC`, `DIMTOL`, `DIMLIM`, `DIMTP`, `DIMTM`, 소수 자리(`DIMDEC`, `DIMRND`, `DIMADEC`)를 유지한다. `swdt-run-autofix-core`가 실행 전후 값을 같은 방식으로 비교해 달라진 치수를 되돌린다. 맞춤공차로 변환된 치수의 `DIMTOL`/`DIMLIM` 변화만 되돌리지 않는다. 통합 앱의 전후 비교와 복원은 검증 단계로 그대로 둔다. 통합 앱은 맞춤공차 치수의 `DIMTOL`도 기존처럼 되돌리므로, 두 경로의 결과에서 이 값 하나가 다를 수 있다. SolidWorks가 DWG 설정보다 적은 소수 자리로 그린 숫자(`17`, 실제 값 17.3)는 다시 그리면 실제 값이 보이며, 사용자 결정에 따라 정상으로 보고 목록만 남긴다(`260929-value-guard-4`). 상세 기록은 `docs/history/swauto-value-guard-2026-09-29.md`에 있다.

## 전체 미사용 이름 정의 정리 계약

Layout 생성 뒤 실제 참조 관계가 확정되면 native `-PURGE`를 이름 정의 범주별로 반복한다. `-PURGE All`은 사용하지 않는다.

- 범위: 블록, 치수 스타일, 그룹, 도면층, 선종류, 재질, 다중 지시선 스타일, 플롯 스타일, 쉐이프, 문자 스타일, 여러 줄 스타일, 테이블 스타일, 비주얼 스타일, 등록 응용프로그램
- 명령 수준 제외: 길이 0 형상, 빈 문자 객체, 분리된 데이터
- 등록 응용프로그램: GstarCAD가 XData·extension dictionary에서 실참조되지 않는다고 판정한 정의만 삭제
- 수렴: 최대 32회 안에 정렬된 symbol table/NOD 재귀 정의 목록이 같은 삭제 0개 반복 도달
- 반복 무결성 지문: 모델·모든 paper layout 객체 수, Layout 용지·탭 순서·viewport 설정, 치수 의미 다중집합, GMTITLE frame/title 링크·속성, 출처와 비정리 workflow 상태 일치
- 저장 경계 전체 감사: 위 항목과 모델·모든 paper layout bbox를 첫 저장 전과 정리 상태 기록 후 다시 계산해 일치 확인
- GMTITLE 내부 구조: frame/title/attribute의 전체 DXF·XData와 persistent reactor, extension dictionary 재귀 내용, `GENIUS_GENOREF_13` native 대상 handle·종류를 세션 종속 ENAME 대신 영구 handle로 정규화해 비교
- 상태: `RESOURCE_CLEANUP=OK`, `RESOURCE_CLEANUP_ZERO_PASS=YES`, 정책 `ALL_UNUSED_NAMED_DEFINITIONS_V5`, 최종 정의 전체 지문과 종류·경로·이름 정체성 지문 저장

GstarCAD Mechanical은 재열기 과정에서 native XData용 APPID, 세션의 `*ACTIVE` VPORT, 내부 객체가 없는 익명 `*U숫자` 블록 정의를 다시 등록할 수 있다. 이 항목들도 PURGE 반복과 전체 정의 지문에는 포함한다. 다만 저장·재열기 완료 게이트에 사용하는 안정 정체성 지문에서만 제외하고 APPID, VPORT, 빈 익명 블록의 개별 지문을 별도로 저장한다. 익명 플래그가 없거나 내부 객체가 하나라도 있는 블록은 이 예외에 포함하지 않는다.

전체 정리와 성공 감사 상태 기록을 하나의 UNDO mark에 묶는다. 명령 오류, 무결성 차이, 제한 반복 비수렴, 첫 저장 실패, 저장 고정점 실패가 있으면 UNDO 1회를 실행한 뒤 초기 정의 목록과 무결성까지 복구됐는지 확인한다. PURGE 반복 안에서는 handle을 포함한 전체 목록이 고정돼야 한다. 저장·재열기 감사에서는 정의의 종류·경로·이름 정체성 지문을 완료 게이트로 사용하고, 같은 정의가 새 handle로 재등록된 차이는 진단값으로 남긴다. 성공 상태 XRecord를 쓴 뒤 저장이 내부 정의 정체성을 정규화하면 저장된 현재 DB로 기준을 바꾸고 최대 4회 안에서 다시 상태를 기록한다. 마지막 저장 직후 같은 세션 자체 감사까지 통과해야 성공이다. GstarCAD의 `DICTNEXT`가 부모 항목의 그룹 3 이름을 생략하는 경우가 있으므로 사전 경로는 부모 `DICTIONARY`의 `(3 . 이름)`과 `(350/360 . 객체)` 쌍을 우선 파싱한다. 성공·실패 상태를 다시 쓸 때 자체적으로 교체되는 `SWCAD_WORKFLOW_STATE` XRecord는 이 실제 이름 경로에서 항목의 존재와 종류를 검사하면서 handle만 고정 토큰으로 정규화한다. 같은 LSP 버전의 실패 상태에서는 `SWCADRUN` 반복을 막고 최종 완료로 이동하지 않는다. 코드 수정으로 LSP 버전이 달라졌을 때만 저장된 실패 버전과 비교해 현재 버전에서 1회 재시도를 허용한다.

## Layout 계약

- 앱은 XREF나 변환된 도면 객체를 자동으로 이동하지 않는다. 예외는 `COLLECT`가 방금 붙인 XREF를 제자리로 옮기는 것뿐이다(`swapp-collect-place`).
- 사용자가 XREF 상태에서 배치한(또는 `COLLECT`가 배치한) 좌표를 materialize 전후로 보존한다.
- 최종 native GMTITLE 도면틀의 effective bbox를 Layout 모델 창으로 사용한다.
- 같은 행은 왼쪽→오른쪽, 다른 행은 위쪽→아래쪽으로 정렬한다.
- Layout을 만든 뒤, 앱 소유가 아니고 뷰포트 말고는 객체가 없는 배치(템플릿의 빈 `배치1`, `배치2`)를 지운다(`swapp-delete-empty-user-layouts`). 무언가 그려진 사용자 배치는 남긴다.
- `SWCADSTATUS`와 실제 생성은 동일한 `swapp-layout-plan` 결과를 사용한다.
- 검증된 DR A2/A3/A4 도면틀 각각을 하나의 A4 Layout으로 만든다.
- 이름은 출처 DWG stem만 사용하며 `SWCAD` 접두사와 자동 순번을 붙이지 않는다.
- 충돌 시 `FILE NO`, `Sheet`, 마지막 최소 숫자 suffix 순으로만 구분한다.
- Layout마다 뷰포트는 정확히 하나이고 용지 크기는 210 x 297 또는 297 x 210이어야 한다.
- 앱 소유 Layout은 이름 접두사가 아니라 `LAYOUT_OWNED_*` XRecord로 관리하며 사용자 Layout은 보존한다.
- 재실행 시 XRecord에 기록된 앱 Layout만 교체한다. 구버전 `SWCAD-SHEET-*`는 최초 마이그레이션에서만 앱 소유로 읽는다.
- DWG 상태에는 `LAYOUT_PLACEMENT_MODE=XREF_SOURCE_FILENAME_COORDINATES`, `LAYOUT_PLAN_COUNT`, `LAYOUT_PLAN_SIGNATURE`, `LAYOUT_NAME_POLICY=SOURCE_FILE_STEM_NO_PREFIX_NO_SEQUENCE`를 저장한다.
- 현재 도면틀 좌표 지문이 저장값과 다르면 기존 Layout을 완료 상태로 인정하지 않고 다시 생성한다.

## 완료 조건

`SWCADVERIFY`는 다음 조건을 모두 확인한다.

- 남은 XREF 0
- 남은 중첩 시트 묶음 0
- GMTITLE 최종 상태 `OK`
- 치수 스타일/Mechanical fit 감사 통과
- `DIMENSION_SEMANTICS=PRESERVED`
- 전체 미사용 이름 정의 정리 상태, 삭제 0개 반복, 저장된 무결성 지문 일치
- GMTITLE 도면틀 수와 SWCAD Layout 수 일치
- 출처 기반 좌표 모드, Layout 이름·소유권, 계획 수량·지문 유지
- 각 Layout의 A4 용지와 단일 뷰포트 확인

최종 성공 문자열은 `SWCADVERIFY_FINAL_OK`다.

구버전 XData에 중첩 블록명 기반의 잘못된 기대 용지 수가 남은 완성본은 별도 읽기 전용 호환 게이트를 통과할 수 있다. 통합 앱이 XREF·wrapper 0, DIMSTYLE 감사, Layout 수량·좌표 지문을 먼저 통과한 경우에만 이 게이트를 켠다. 그 안에서도 모든 target frame/title이 완전한 1:1 native 쌍이고 원본 후보, 중복 쌍, 수량 부족, 형상 경고가 없을 때만 실제 용지별 수량을 검증에 사용한다. `SWCADVERIFY` 자체는 XData를 쓰거나 도면을 저장하지 않으며, GMTITLE 단독 검증과 현재 분류기 표식이 있는 도면의 불일치는 자동 보정하지 않는다.
