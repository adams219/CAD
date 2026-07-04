# GMTITLE 다른 컴퓨터에서 이어가기

다른 PC에서 현재 GMTITLE 작업을 이어받을 때 확인할 기준 문서입니다.

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
2026-07-04 현재 로컬 작업 기준은 main66 verify-next-priority입니다.
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
260704-target-overlap-adopt-main66-verify-next-priority
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
SWTITLECONVERT
SWTITLESTATUS
```

최종 검증:

```text
SWTITLEVERIFY
```

## GMTITLE 창에서 선택

`SWTITLECONVERT` 중 GMTITLE 창이 열리면 로그가 요구한 값만 선택합니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

## main66 주의점

```text
SWTITLESTATUS가 겹친 GMTITLE target 쌍을 표시하면 SWTITLECONVERT를 반복하지 않습니다.
먼저 SWTITLEPREPARE로 정리합니다.
같은 위치에 기존 native GMTITLE 쌍이 있으면 SWTITLECONVERT가 새로 만들지 않고 그 쌍을 채택합니다.
DR_A3_Outline 안의 native-format title-like 형상은 그 자체만으로 삭제하지 않습니다.
A3/A4 native 교체 후보가 남아 있으면 SWTITLESTATUS는 A4 frame-only보다 그 후보를 먼저 안내합니다.
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
표제란 없는 A4는 DR_A4_Outline 도면틀만 검증하고, 더블클릭할 제목블록은 없음
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```

## 함께 볼 문서

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
