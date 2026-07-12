# CAD Tool

GstarCAD / GstarCAD Mechanical / SolidWorks DWG 변환 도구를 관리하는 저장소입니다.

## 통합 SWCAD Workflow

새 도면에서 SolidWorks DWG를 XREF로 연결한 뒤 GMTITLE, 치수/공차 정규화, A4 Layout 생성을 순서대로 실행하려면 아래 로더를 `APPLOAD`합니다.

```text
<SWCAD 도구 폴더>\apps\swcad-workflow\swcad_workflow_load.lsp
```

일반 사용 명령은 세 개입니다.

```text
SWCADSTATUS
SWCADRUN
SWCADVERIFY
```

상세 구조와 실제 CAD 검증 결과:

```text
docs\swcad-workflow\architecture.md
docs\swcad-workflow\test-results-2026-07-13.md
```

배포 ZIP을 다른 PC에서 사용할 때는 압축을 푼 뒤 `Install_SWCAD_Workflow.cmd`를 한 번 실행하고, 생성된 `SWCAD_Workflow_Load.lsp`를 `APPLOAD`합니다.

## 기본 로드

GstarCAD에서 `APPLOAD`를 실행한 뒤 아래 파일을 로드합니다.

```text
<SWCAD 도구 폴더>\swcad_load.lsp
```

GMTITLE 도구만 직접 로드할 때는 아래 파일을 로드할 수 있습니다.

```text
<SWCAD 도구 폴더>\src\tools\gmtitle\swcad_title_scale.lsp
```

GMTITLE 창 자동 선택까지 사용하려면 `swcad_title_scale.lsp`와 같은 폴더의
`swtitle_gmtitle_dialog_autoselect.ps1`도 함께 배포합니다. LSP는 현재 로드된 파일 위치를 기준으로 이 보조 파일을 찾습니다.

로드 후 버전을 확인합니다.

```text
SWTITLEVERSION
```

현재 GMTITLE 기준 버전:

```text
260712-portable-saveas-offsheet-frame-1
```

다른 버전이 보이면 `SWTITLESTATUS` 결과를 믿기 전에 최신 LSP를 다시 APPLOAD 합니다.

## GMTITLE 현재 공개 명령

SolidWorks DWG의 도면틀/표제란을 GstarCAD Mechanical GMTITLE 구조로 바꾸는 일반 사용 흐름은 아래 4개 명령만 사용합니다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERTNEXT
SWTITLEVERIFY
```

수동 응답을 직접 골라야 할 때만 `SWTITLECONVERT`를 대신 사용합니다.

원본 DWG에서 처음 `SWTITLEPREPARE`, `SWTITLECONVERTNEXT`, `SWTITLECONVERT`를 실행하면
`SWTITLE 변환 작업본을 다른 이름으로 저장` 창이 먼저 열립니다. 원하는 폴더와 새 파일명을 선택하면
그 새 DWG가 활성 작업본이 되고 원본 파일은 그대로 남습니다. 저장을 취소하거나 원본과 같은 경로를 선택하면 변환하지 않습니다.

옛 실험/진단/복구 명령은 LSP 내부 호환 함수로 남아 있을 수 있지만, 일반 작업에서 직접 입력하지 않습니다.

예전 명령이 CAD에서 실행된다면 오래된 LSP가 로드된 상태일 수 있습니다.

```text
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
SWTITLEGMTITLEVERIFYALL
```

이 경우 `swcad_load.lsp`를 다시 APPLOAD 하고 `SWTITLEVERSION`, `SWTITLESTATUS`부터 확인합니다.

## GMTITLE 판단 기준

이번 흐름의 핵심은 새 명령어를 계속 늘리지 않고, 상태 진단 결과를 기준으로 같은 4단계를 반복하는 것입니다.

```text
SWTITLESTATUS
SWTITLEPREPARE    필요하다고 나올 때만
SWTITLESTATUS
SWTITLECONVERTNEXT
SWTITLESTATUS
SWTITLEVERIFY     최종 검증 단계에서
```

중요 원칙:

- `Downloads` 원본 DWG에서 바로 편집하지 않습니다.
- 원본에서 변경 명령을 처음 실행할 때 나타나는 다른 이름으로 저장 창에서 별도 작업본을 만들고, 그 작업본에서만 변환합니다. 저장소의 `work` 폴더는 개발 진단용일 뿐 일반 사용자에게 고정하지 않습니다.
- 스크린샷 좌표 클릭이나 긴 소수점 좌표 수동 입력에 의존하지 않습니다.
- 한 용지 크기의 기준 객체를 다른 크기에 억지로 재사용하지 않습니다.
- A3 도면틀 안에 표제란 형상이 섞인 경우 먼저 `SWTITLEPREPARE`로 정규화합니다.
- `frame-only`는 A4 전용이 아니라 원본 표제란/제목블록 부재가 검증된 경우에만 예외로 처리합니다.
- 도면 안 번호, 주석, BOM, 치수, 모델 형상을 잔여물로 오판하지 않습니다.
- `SWTITLEVERIFY_FINAL_OK` 전에는 완료로 보지 않습니다.

## 주요 문서

실제 CAD 화면에서 따라갈 체크리스트:

```text
docs\guide\gmtitle-cad-conversion-checklist.md
```

공개 명령 설명:

```text
docs\guide\commands.md
```

GitHub/로컬 이력 기반 반복 실수 방지 계획:

```text
docs\history\gmtitle-history-github-local-prevention-plan-2026-07-04.md
```

실제 제목블록 범위와 중첩 블록 변환을 사용한 잔여물 판정 이력:

```text
docs\history\gmtitle-title-residue-geometry-2026-07-11.md
```

13/15를 성공으로 잘못 판정했던 과거 fresh 변환 이력(현재 기준에서는 중간 증거):

```text
docs\history\gmtitle-fresh-e2e-final-2026-07-11.md
```

일반 TEXT/MTEXT 제목값과 동반 정적 제목 셸 INSERT를 통합해 15/15를 검증하는 최신 이력:

```text
docs\history\gmtitle-unified-title-shell-cleanup-2026-07-11.md
```

고정 `work` 폴더 밖의 사용자 선택 작업본에서 portable Save As부터 A2/A3/A4 전체 변환, raw bbox 정리, 저장 후 재열기와 대표 편집창까지 검증한 최신 이력:

```text
docs\history\gmtitle-portable-e2e-offsheet-frame-2026-07-12.md
```

현재 로컬 최종 검증은 `DR_titlea_3rd 15 / DR 도면틀 15 / native GMTITLE 쌍 15`, 원본 후보 0, 도면틀 정의 raw bbox 위험 0이며 대표 A2/A3/A4 편집창이 모두 `속성 블록 편집`으로 열렸습니다. portable 결과는 `portable-e2e\output\swtitle_portable_result_260712.dwg`이고 SHA-256은 `1F2D3BA224A27E141CB64D79DC4FE75DCC00819D2F07751D83E8380CCE17AA23`입니다.

main49 반영 이력:

```text
docs\history\gmtitle-main49-frame-prepare-integration-2026-07-04.md
```

진단 runner 설명:

```text
diagnostics\gmtitle-main45\README.md
```

## 치수/공차 명령

기존 치수/공차 관련 주요 명령은 유지합니다.

```text
SWAUTO
SWHELP
SWDEBUG
SWFINDSTYLE
SWTRYDELDIMSTYLES
SWDIMKEEPAMISO
SWMECHFITSEL
SWMECHFITALL
SWPURGESTYLES
```

## 작업 폴더

`work/`는 CAD 테스트와 진단 산출물을 두는 저장소 내부 임시 폴더입니다. 일반 사용자의 DWG 작업 위치를 제한하지 않습니다.

일반 사용자는 원본 DWG가 있는 위치와 관계없이 `SWTITLESTATUS`로 상태를 확인한 뒤,
첫 변경 명령에서 나타나는 다른 이름으로 저장 창으로 작업본 위치를 직접 정합니다.
선택 저장된 작업본에는 승인 표식이 기록되므로 저장하고 다시 열어도 같은 작업본으로 인식합니다.

현재 기준 작업복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

현재 작업복사본의 진행 상태는 README에 고정하지 않습니다. 상태가 필요하면 아래 명령으로 최신 로그와 현재 커밋 기준 신선도를 확인합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_goal_status.ps1
```

`final completion gate`가 실패하더라도 `run_goal_status.ps1`의 `Final gate log older than current commit`, `status-after-status`, `status-after-verify`, source/target count를 같이 보고 다음 CAD 단계를 판단합니다.
