# GMTITLE 다른 컴퓨터에서 이어가기

> 2026-07-06 기준 변경: `docs/guide/gmtitle-unified-flow-reset.md`가 GMTITLE 변환의 최우선 기준입니다. A2/A3/A4는 모두 같은 GMTITLE 흐름으로 보고, `frame-only`는 A4 전용 정책이 아니라 원본 표제란 부재가 검증된 경우의 예외로만 해석합니다.

다른 PC에서 현재 GMTITLE 작업을 이어받을 때 확인할 기준 문서입니다.

## 먼저 볼 기준

현재 작업 기준은 이 문서, `docs/guide/gmtitle-current-run-card.md`, `docs/guide/commands.md`, `diagnostics/gmtitle-main45/run_next_cad_action.ps1` 출력입니다.

`docs/history`와 `docs/investigations`는 이전 실험 이력입니다. 같은 시행착오를 반복하지 않기 위한 근거로만 보고, 현재 순서와 다르면 현재 기준 문서를 우선합니다.

A2/A3/A4는 모두 공통 GMTITLE 흐름으로 봅니다. `frame-only`는 A4 전용이 아니라 원본 표제란 부재가 검증된 경우의 예외이며, 그런 예외 시트만 제목블록 더블클릭 대신 도면틀 수량/형상으로 검증합니다.

## Git 기준

저장소:

```text
https://github.com/adams219/CAD.git
```

작업 브랜치:

```text
codex/gm-title
```

주의:

```text
2026-07-05 현재 로컬 작업 기준은 `260707-unified-title-missing-16`입니다.
현재 로컬 브랜치는 GitHub보다 앞선 커밋이 있을 수 있으므로, 다른 PC에서 이어가기 전에 이 브랜치가 GitHub에 push됐는지 확인합니다.
다른 PC에서는 `codex/gm-title` 브랜치를 받은 뒤, CAD에서 `SWTITLEVERSION`으로 실제 로드 버전을 확인합니다.
```

최신 커밋 확인:

```powershell
git fetch origin
git log --oneline -n 3 --all
git status --short --branch
```

## 처음 받는 PC

문서 폴더에 새로 받을 때:

```powershell
cd "$env:USERPROFILE\Documents"
git clone https://github.com/adams219/CAD.git "CAD tool"
cd "$env:USERPROFILE\Documents\CAD tool"
git checkout codex/gm-title
```

이미 저장소가 있는 PC:

```powershell
cd "$env:USERPROFILE\Documents\CAD tool"
git fetch origin
git checkout codex/gm-title
git pull
```

## GstarCAD에서 로드

GstarCAD에서 `APPLOAD`를 실행하고 아래 파일을 로드합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

로드 후 확인:

```text
SWTITLEVERSION
```

기대 버전:

```text
260707-unified-title-missing-16
```

다른 버전이면 변환하지 말고 다시 APPLOAD 합니다. 그래도 다른 버전이면 다른 브랜치를 받았거나, 열린 CAD 세션이 예전 LSP를 유지하고 있을 수 있습니다.

## DWG 작업 위치

원본 DWG에서 바로 작업하지 말고 반드시 `work` 폴더의 복사본에서 진행합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

`Downloads` 원본 DWG나 실제 납품 원본에서 바로 실행하지 않습니다.

## CAD 실행 순서

항상 상태부터 봅니다.

```text
SWTITLESTATUS
```

상태가 정규화를 요구하면:

```text
SWTITLEPREPARE
SWTITLESTATUS
```

상태가 변환을 요구하면:

```text
SWTITLECONVERTNEXT
```

`SWTITLECONVERTNEXT`는 `YES`/`OPEN` 같은 반복 응답만 현재 상태에 맞게 자동 선택합니다. GMTITLE 창의 DR 용지/제목블록/옵션 확인은 직접 해야 합니다.

수동 응답을 직접 고르고 싶으면 아래 명령을 대신 사용할 수 있습니다.

```text
SWTITLECONVERT
```

```text
SWTITLESTATUS
```

최종 검증:

```text
SWTITLEVERIFY
```

수동으로 GMTITLE 창에서 한 장을 처리한 뒤에는 작업복사본을 저장하고 GstarCAD를 닫은 다음, CAD 밖 PowerShell에서 아래 명령으로 상태를 다시 잠급니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_after_manual_gmtitle_step.ps1 -Compact
```

이 명령은 DWG를 직접 편집하지 않고 direct probe를 갱신한 뒤 다음 한 단계 요약을 보여줍니다. 긴 next-action card 전체는 로그 파일에 남습니다. 최종 검증 단계라면 final completion gate도 이어서 확인합니다.

## GMTITLE 창에서 선택

`SWTITLECONVERT` 중 GMTITLE 창이 열리면 로그가 요구한 값만 선택합니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

CAD 명령줄에 `GMTITLE`, `TIT`, 일반 `OPEN`을 직접 입력해서 우회하지 않습니다. `SWTITLECONVERTNEXT`/`SWTITLECONVERT`가 GMTITLE 호출, 배치점 자동 전송, 값 복사/정리를 묶어서 처리합니다.

주의: 아래의 `OPEN`은 `SWTITLECONVERT`가 물어볼 때 답하는 응답입니다. CAD 일반 `OPEN` 명령을 뜻하지 않습니다.

`SWTITLECONVERT` 안에서 입력을 물으면 아래 기준만 사용합니다.

```text
첫 native GMTITLE 생성: YES
누락된 용지 크기의 첫 native GMTITLE 생성: YES
A2/A3/A4 native 교체 1장 처리: OPEN
BATCH는 OPEN으로 최소 1장 성공한 뒤, 같은 DR 용지/제목블록/옵션이 반복된다는 걸 눈으로 확인할 수 있을 때만 사용
OPEN이 새 GMTITLE을 못 잡거나 NO_INSERTS가 반복됨: MANUAL
판단이 애매하거나 현재 DWG가 다름: Enter로 중단
```

## 현재 기준 주의점

```text
SWTITLESTATUS가 겹친 GMTITLE target 쌍을 표시하면 SWTITLECONVERT를 반복하지 않습니다.
먼저 SWTITLEPREPARE로 정리합니다.
같은 위치에 기존 native GMTITLE 쌍이 있으면 SWTITLECONVERTNEXT 또는 수동 SWTITLECONVERT 흐름이 새로 만들지 않고 그 쌍을 채택합니다.
DR_A3_Outline 안의 native-format title-like 형상은 그 자체만으로 삭제하지 않습니다.
A2/A3/A4 native 교체 후보가 남아 있으면 SWTITLESTATUS는 title-missing/frame-only 예외보다 그 후보를 먼저 안내합니다.
BATCH는 첫 후보부터 쓰지 말고, OPEN으로 후보 수가 줄어든 증거를 먼저 확인한 뒤 사용합니다.
핵심 상태/검증 안내는 한국어로 표시됩니다.
```

## 완료 기준

아래가 모두 확인되기 전에는 완료가 아닙니다.

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
frame-only 시트: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
겹친 GMTITLE target 쌍: 0
실제 DR_titlea_3rd가 있는 대표 용지를 더블클릭하면 GMTITLE 표 편집창 열림
원본 표제란 부재가 검증된 title-missing 시트는 해당 DR_A*_Outline 도면틀만 검증하고, 더블클릭할 제목블록은 없음
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```

## 함께 볼 문서

최우선 기준:

```text
docs\guide\gmtitle-unified-flow-reset.md
```

짧은 실행 카드:

```text
docs\guide\gmtitle-current-run-card.md
```

전체 체크리스트:

```text
docs\guide\gmtitle-cad-conversion-checklist.md
```

main56 계획:

```text
docs\history\gmtitle-main56-target-overlap-adoption-plan-2026-07-04.md
```
