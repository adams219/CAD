# GMTITLE 다른 컴퓨터에서 이어하기

이 문서는 다른 PC에서 현재 GMTITLE 작업을 이어갈 때 보는 짧은 인수인계입니다.

## 현재 Git 기준

저장소:

```text
https://github.com/adams219/CAD.git
```

작업 브랜치:

```text
codex/gm-title
```

기준은 특정 커밋 번호가 아니라 `origin/codex/gm-title` 브랜치의 최신 상태입니다.

최신 커밋 확인:

```powershell
git log --oneline -n 3
```

## 처음 받는 PC

문서 폴더에서 새로 받을 때:

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

GstarCAD에서 `APPLOAD`를 실행한 뒤 아래 파일을 로드합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

로드 후 확인:

```text
SWTITLEVERSION
```

기대 버전:

```text
260704-overlap-only-main50
```

다른 버전이면 변환하지 말고 다시 APPLOAD 합니다.

## 실제 DWG 작업 위치

원본 DWG에서 바로 작업하지 말고 반드시 `work` 폴더의 복사본에서 진행합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

현재 기준 작업복사본은 변환 전 상태입니다.

```text
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
원본 표제란/도면틀: 13 / 15
표제란 없는 도면틀 시트: 2
대상 도면틀/제목블록: 0 / 0
필요 용지:
  A2: 1
  A3: 12
  A4: 2
```

이 상태는 오류가 아닙니다. 첫 변환이 아직 시작되지 않았다는 뜻입니다.

## CAD에서 실행할 순서

```text
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
```

중간에 `SWTITLESTATUS`가 정규화를 안내하면:

```text
SWTITLEPREPARE
SWTITLESTATUS
SWTITLECONVERT
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
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```

## 함께 볼 문서

CAD 옆에 띄워둘 짧은 실행 카드:

```text
docs\guide\gmtitle-current-run-card.md
```

전체 체크리스트:

```text
docs\guide\gmtitle-cad-conversion-checklist.md
```
