# SWCAD Workflow 통합 구조

## 목적

SolidWorks DWG를 XREF로 모은 새 호스트 도면에서 기존 세 도구를 다음 순서로 연결한다.

```text
XREF 독립 작업본 생성 및 materialize
→ native GMTITLE 변환
→ 치수/공차 정규화
→ 미사용 XREF 리소스 정리
→ 원본 파일명 A4 Layout 생성
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

`SWCADRUN`은 현재 상태에서 다음 안전 단계 하나만 실행한다. 중간에 종료해도 DWG의 `SWCAD_WORKFLOW_STATE` XRecord를 읽어 재개한다. 단계는 사용자에게 1/6부터 6/6까지 표시하며, GMTITLE 결과가 `ABORT_`, `ERROR_`, `WARN_`이면 같은 명령의 반복을 권장하지 않는다.

```text
XREF → SHEET_WRAPPERS(필요한 경우) → TITLE → DIMSTYLE → CLEANUP → LAYOUT → COMPLETE
```

## 성능 구조

- `SWCADSTATUS`, `SWCADRUN`, `SWCADVERIFY`는 명령이 시작될 때 읽기 전용 인벤토리를 만들고 같은 명령 안의 단계 판정과 상태 출력이 이를 공유한다.
- 도면이 실제로 변경되는 단계 직전에는 캐시를 닫고, 변경 직후 한 번만 새 인벤토리를 만든다. 변경 전 객체를 변경 후에 재사용하지 않는다.
- GMTITLE 모듈은 모델 공간 INSERT 목록을 명령당 한 번 물리 스캔하고, 도면틀·제목블록·원본 후보 판정은 같은 목록을 재사용한다.
- 여러 시트 변환은 시작 시 대상 레코드 큐를 한 번 만들고, 각 시트 처리 전 전체 도면을 다시 스캔하지 않는다. 큐의 객체가 사라졌거나 형상이 달라지면 안전하게 중단한다.
- XREF와 wrapper 탐색은 모델 공간의 모든 객체를 COM으로 열거하지 않고 `INSERT` 선택집합만 읽는다. 치수 의미 검사는 `DIMENSION` 선택집합만 읽는다.
- 같은 wrapper 블록 정의가 여러 번 삽입되면 내부 frame/title/dimension 증거는 정의별 한 번만 계산한다.
- 중간 상태 판정도 현재 도면의 `INSERT`를 읽어 wrapper가 다시 생기지 않았는지 확인한다. 실제 변환 직후와 최종 `SWCADVERIFY`에서는 수량·치수·bbox 등 결과 안전 조건을 깊게 검사한다.
- 모델 공간 전체 객체 순회는 bbox 보존 안전 감사에만 허용한다.

30장 기준 실측은 `SWCADRUN 124,921 → 53,833 ms`, `SWCADSTATUS 28,674 → 842 ms`다. 남은 시간의 대부분은 BIND/EXPLODE/REGEN과 bbox 보존 검사이며, 이는 결과 안전성과 연결된 별도 최적화 대상으로 취급한다.

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

## 미사용 리소스 정리 계약

DIMSTYLE 이후 Layout 전에 `$0$` 결합 흔적과 미사용 SLD 정의를 제한 반복으로 정리한다.

- 범위: 블록, 치수 스타일, 문자 스타일, 선종류
- 보호: 기본/현재/실참조 정의, `AM_ISO`, `DR_A*_Outline`, `DR_titlea_3rd`, `GENIUS_`, `GMTITLE`
- 수렴: 최대 6회 안에 삭제 0개 반복 도달
- 무결성: 모델 객체 수, 모델 bbox, 치수 의미 다중집합, GMTITLE frame/title 링크·속성·bbox 일치
- 상태: `RESOURCE_CLEANUP=OK`, `RESOURCE_CLEANUP_ZERO_PASS=YES`, 정책 `XREF_BOUND_UNUSED_V1`

삭제 중 무결성이 달라지면 UNDO를 시도하고 실패 상태를 기록한다. 같은 `SWCADRUN`을 반복하지 않으며 Layout 생성도 차단한다.

## Layout 계약

- 앱은 XREF나 변환된 도면 객체를 자동으로 이동하지 않는다.
- 사용자가 XREF 상태에서 배치한 좌표를 materialize 전후로 보존한다.
- 최종 native GMTITLE 도면틀의 effective bbox를 Layout 모델 창으로 사용한다.
- 같은 행은 왼쪽→오른쪽, 다른 행은 위쪽→아래쪽으로 정렬한다.
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
- 미사용 XREF 리소스 정리 상태와 저장된 무결성 지문 일치
- GMTITLE 도면틀 수와 SWCAD Layout 수 일치
- 출처 기반 좌표 모드, Layout 이름·소유권, 계획 수량·지문 유지
- 각 Layout의 A4 용지와 단일 뷰포트 확인

최종 성공 문자열은 `SWCADVERIFY_FINAL_OK`다.

구버전 XData에 중첩 블록명 기반의 잘못된 기대 용지 수가 남은 완성본은 별도 읽기 전용 호환 게이트를 통과할 수 있다. 통합 앱이 XREF·wrapper 0, DIMSTYLE 감사, Layout 수량·좌표 지문을 먼저 통과한 경우에만 이 게이트를 켠다. 그 안에서도 모든 target frame/title이 완전한 1:1 native 쌍이고 원본 후보, 중복 쌍, 수량 부족, 형상 경고가 없을 때만 실제 용지별 수량을 검증에 사용한다. `SWCADVERIFY` 자체는 XData를 쓰거나 도면을 저장하지 않으며, GMTITLE 단독 검증과 현재 분류기 표식이 있는 도면의 불일치는 자동 보정하지 않는다.
