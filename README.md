# CAD Tool

GstarCAD / GstarCAD Mechanical / SolidWorks DWG 변환 도구를 관리하는 저장소입니다.

## 기본 로드

GstarCAD에서 `APPLOAD`를 실행한 뒤 아래 파일을 로드합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

GMTITLE 도구만 직접 로드할 때는 아래 파일을 로드할 수 있습니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

로드 후 버전을 확인합니다.

```text
SWTITLEVERSION
```

현재 GMTITLE 기준 버전:

```text
260710-fixed-control-autoselect-1
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
- 반드시 `work` 폴더 아래 작업복사본에서 테스트합니다.
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

`work/`는 CAD 테스트와 진단 산출물을 두는 임시 작업 폴더입니다.

현재 기준 작업복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

현재 작업복사본의 진행 상태는 README에 고정하지 않습니다. 상태가 필요하면 아래 명령으로 최신 로그와 현재 커밋 기준 신선도를 확인합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_goal_status.ps1
```

`final completion gate`가 실패하더라도 `run_goal_status.ps1`의 `Final gate log older than current commit`, `status-after-status`, `status-after-verify`, source/target count를 같이 보고 다음 CAD 단계를 판단합니다.
