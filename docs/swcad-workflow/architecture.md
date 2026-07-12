# SWCAD Workflow 통합 구조

## 목적

SolidWorks DWG를 XREF로 모은 새 호스트 도면에서 기존 세 도구를 다음 순서로 연결한다.

```text
XREF 독립 작업본 생성 및 materialize
→ native GMTITLE 변환
→ 치수/공차 정규화
→ 도면별 A4 Layout 생성
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

`SWCADRUN`은 현재 상태에서 다음 안전 단계 하나만 실행한다. 중간에 종료해도 DWG의 `SWCAD_WORKFLOW_STATE` XRecord를 읽어 재개한다.

```text
XREF → TITLE → DIMSTYLE → LAYOUT → COMPLETE
```

## XREF materialize 결정

실제 GstarCAD 비교 결과에 따라 원본 SolidWorks XREF는 `BIND` 후 최상위 참조를 정확히 한 번 `EXPLODE`한다.

- Attached 상태는 치수와 원본 도면틀이 XREF 내부에 남아 후속 모듈이 직접 처리할 수 없다.
- BIND만 한 상태도 최상위 객체가 블록 참조라 후속 모듈의 원본 시트 감지가 되지 않는다.
- BIND 후 1회 EXPLODE는 치수 143개, 원본 title/frame 15/15, 전체 bbox와 치수 의미 해시를 유지한다.
- 이미 native GMTITLE인 XREF는 EXPLODE할 때 native link가 사라지므로 자동 materialize를 차단한다.
- 중첩/미참조 XREF, 축척 1 이외, 회전 0 이외도 MVP에서 차단한다.

첫 변경 전에 GMTITLE 모듈의 Save As 계약을 사용한다. 사용자가 정한 별도 작업본만 변경하며 호스트 원본과 XREF 원본은 저장하지 않는다.

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

## Layout 계약

- 검증된 DR A2/A3/A4 도면틀 각각을 하나의 A4 Layout으로 만든다.
- 이름은 `SWCAD-SHEET-001`부터 시작한다.
- Layout마다 뷰포트는 정확히 하나이고 용지 크기는 210 x 297 또는 297 x 210이어야 한다.
- 재실행 시 앱 접두사의 Layout만 교체하므로 중복되지 않는다.

## 완료 조건

`SWCADVERIFY`는 다음 조건을 모두 확인한다.

- 남은 XREF 0
- GMTITLE 최종 상태 `OK`
- 치수 스타일/Mechanical fit 감사 통과
- `DIMENSION_SEMANTICS=PRESERVED`
- GMTITLE 도면틀 수와 SWCAD Layout 수 일치
- 각 Layout의 A4 용지와 단일 뷰포트 확인

최종 성공 문자열은 `SWCADVERIFY_FINAL_OK`다.
