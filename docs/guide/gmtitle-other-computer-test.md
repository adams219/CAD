# GMTITLE 다른 컴퓨터 테스트 방법

이 문서는 현재 컴퓨터에서 개발한 GMTITLE 자동 변환 기능을 다른 컴퓨터의 GstarCAD Mechanical에서 안전하게 검증하는 절차입니다.

## 핵심 원칙

- SolidWorks 원본 DWG와 실제 업무 도면은 직접 수정하지 않습니다.
- 테스트할 DWG는 반드시 저장소의 `work` 폴더에 복사한 뒤 사용합니다.
- 코드와 문서는 GitHub로 전달하고, `work` 폴더의 DWG는 별도로 전달합니다.
- 두 컴퓨터의 GstarCAD Mechanical 버전과 언어판은 가능하면 같아야 합니다.
- 최종 성공은 로그뿐 아니라 대표 제목블록의 더블클릭 동작까지 확인해야 합니다.

## 현재 개발 기준

```text
저장소: https://github.com/adams219/CAD.git
브랜치: codex/gm-title
기대 LSP 버전: 260710-native-title-missing-frame-1
```

현재 개발 PC의 대표 A3 기준 검증은 통과했지만, 후속 전체 클릭 검사에서 일부 실패가 확인되었습니다.

```text
대표 title: DR_titlea_3rd / handle 16DB5
편집창: 속성 블록 편집
결과: PASS_GMTITLE_TABLE_EDITOR

전체 제목블록: 13개 중 12개 표 편집창, 1개 고급 속성 편집기
전체 도면틀: A2/A3 13개 정상, title-missing A4 2개 REFEDIT
현재 판정: 전체 편집 동작 미완료
```

다른 PC에서는 대표 한 장만 확인하지 말고 A2/A3/A4 각 유형과 A3 실패 시트를 함께 확인합니다. 현재 결과를 최종 배포 완료판으로 취급하지 않습니다.

다른 컴퓨터에서 내려받기 전에 `260710-native-title-missing-frame-1` 변경이 `origin/codex/gm-title`에 push되었는지 확인합니다. 로컬에만 변경이 남아 있으면 먼저 정적 검증과 커밋·push를 끝냅니다.

## 1. 현재 컴퓨터에서 준비

다른 컴퓨터로 이동하기 전에 다음을 완료합니다.

1. 불안정한 실험 파일을 배포 대상에서 제외합니다.
2. 정적 검사를 통과시킵니다.
3. 필요한 코드와 문서를 `codex/gm-title` 브랜치에 커밋합니다.
4. 브랜치를 GitHub에 push합니다.
5. 테스트용 DWG를 별도로 준비합니다.

Git 상태 확인:

```powershell
cd "$env:USERPROFILE\Documents\CAD tool"
git status --short --branch
git log -3 --oneline --decorate
```

GitHub 반영 확인:

```powershell
git fetch origin
git status --short --branch
```

현재 브랜치와 `origin/codex/gm-title`이 같은 최신 커밋을 가리켜야 합니다.

## 2. 테스트 DWG 전달

저장소의 `.gitignore`는 `work\*.dwg`를 Git에서 제외합니다. 따라서 테스트 DWG는 GitHub clone만으로 다른 컴퓨터에 전달되지 않습니다.

다음 중 필요한 파일을 USB, 사내 공유 폴더 또는 승인된 클라우드 저장소로 별도 전달합니다.

### 처음부터 변환을 시험할 때

아직 GMTITLE 변환하지 않은 원본 DWG의 복사본을 사용합니다.

```text
원본파일명_otherpc_test_workcopy.dwg
```

### 최종 결과와 더블클릭 동작만 확인할 때

현재 대표 결과 도면:

```text
swtitle_integrated_autoselect_fullflow_probe.dwg
```

현재 기록된 SHA-256:

```text
3B5DA20A861CEBA2782D051A58587410F5BE5D022F56AAADE5E29DC2809E8BAD
```

이 파일은 이미 변환된 결과를 확인하는 용도입니다. 처음부터 변환되는 과정을 시험하는 입력 DWG로 사용하지 않습니다.

## 3. 다른 컴퓨터의 필수 조건

권장 환경:

```text
Windows
GstarCAD Mechanical 2024 Korean
Windows PowerShell 5.1 이상
Git 또는 GitHub Desktop
```

특히 다음 DR 파일이 설치되어 있는지 확인합니다.

```text
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A2_Outline.dwg
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A3_Outline.dwg
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A4_Outline.dwg
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Title\DR_titlea_3rd.dwg
```

PowerShell 확인 명령:

```powershell
Test-Path 'C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A2_Outline.dwg'
Test-Path 'C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A3_Outline.dwg'
Test-Path 'C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Format\DR_A4_Outline.dwg'
Test-Path 'C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Dwg\Title\DR_titlea_3rd.dwg'
```

네 명령 모두 `True`가 나와야 현재 환경과 같은 기준으로 비교할 수 있습니다.

GMTITLE 대화상자 자동 선택은 고정 컨트롤 ID를 사용합니다. GstarCAD Mechanical 버전이나 언어판이 다르면 대화상자 구조가 달라질 수 있으므로, 이 경우 자동 선택 결과를 별도의 호환성 문제로 기록합니다.

## 4. 다른 컴퓨터에서 저장소 받기

### 처음 받는 경우

```powershell
cd "$env:USERPROFILE\Documents"
git clone https://github.com/adams219/CAD.git "CAD tool"
cd "$env:USERPROFILE\Documents\CAD tool"
git checkout codex/gm-title
git pull
```

### 이미 저장소가 있는 경우

```powershell
cd "$env:USERPROFILE\Documents\CAD tool"
git fetch origin
git checkout codex/gm-title
git pull
```

확인:

```powershell
git status --short --branch
git log -3 --oneline --decorate
```

로컬 경로는 다음 형태를 권장합니다.

```text
C:\Users\<사용자명>\Documents\CAD tool
```

LSP는 `USERPROFILE`을 사용하므로 Windows 사용자명이 달라도 괜찮지만, `Documents\CAD tool` 폴더 구조는 유지하는 것이 안전합니다.

## 5. 작업복사본 배치

다른 컴퓨터에서 다음 폴더를 확인하거나 만듭니다.

```text
C:\Users\<사용자명>\Documents\CAD tool\work
```

별도로 전달한 DWG를 이 폴더에 넣습니다. 실제 원본은 다른 위치에 보관하고, `work` 아래에는 복사본만 둡니다.

예시:

```text
C:\Users\<사용자명>\Documents\CAD tool\work\0000_A_DRP125_otherpc_test_workcopy.dwg
```

## 6. GstarCAD에서 LSP 로드

1. GstarCAD Mechanical을 실행합니다.
2. 명령줄에 `APPLOAD`를 입력합니다.
3. 다음 파일을 선택합니다.

```text
C:\Users\<사용자명>\Documents\CAD tool\swcad_load.lsp
```

4. 로드가 끝나면 실행합니다.

```text
SWTITLEVERSION
```

기대 결과:

```text
260710-native-title-missing-frame-1
```

다른 버전이 나오면 변환을 시작하지 않습니다. 브랜치, `git pull`, APPLOAD 경로를 다시 확인합니다.

## 7. 처음부터 변환하는 대표 테스트

`work` 폴더의 변환 전 DWG 복사본을 엽니다.

먼저 상태를 확인합니다.

```text
SWTITLESTATUS
```

상태에서 정규화가 필요하다고 안내할 때만 실행합니다.

```text
SWTITLEPREPARE
SWTITLESTATUS
```

변환이 가능하다고 안내되면 실행합니다.

```text
SWTITLECONVERTNEXT
```

최신 자동 선택 흐름의 기대 동작:

```text
용지/도면틀: 현재 시트 크기에 맞는 DR_A2/A3/A4_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

대화상자 선택과 확인은 고정 컨트롤 ID 기반 보조 프로그램이 처리합니다. 자동 선택이 작동하는 동안 마우스로 다른 창을 클릭하지 않습니다.

변환 후 다시 확인합니다.

```text
SWTITLESTATUS
```

최종 단계에서는 실행합니다.

```text
SWTITLEVERIFY
```

## 8. 대표 더블클릭 확인

일상 작업 확인은 최소한 새로 변환된 A3 시트 한 장으로 할 수 있습니다. LSP 변경을 검증하거나 이 컴퓨터의 결과와 동등함을 확인할 때는 제목블록과 도면틀을 전수검사합니다.

1. `DR_titlea_3rd` 제목블록 내부를 더블클릭합니다.
2. 도면틀 선이나 모델 형상은 클릭하지 않습니다.
3. 다음 결과를 기록합니다.

성공:

```text
속성 블록 편집 표가 열림
```

실패:

```text
고급 속성 편집기가 열림
제목 블록과 도면 경계 창이 열림
REFEDIT가 실행됨
아무 창도 열리지 않음
```

확인만 하고 편집 창은 취소하여 DWG에 불필요한 변경을 남기지 않습니다.

전수검사에서는 bbox 중심점이 아니라 handle로 확대한 뒤 실제 DR 로고/제목블록 선과 실제 바깥 도면틀 선을 더블클릭합니다. 제목블록은 모두 `속성 블록 편집`, 도면틀은 모두 `제목 블록과 도면 경계`로 열려야 하며 고급 속성 편집기와 REFEDIT는 0이어야 합니다.

## 9. 전체 성공 기준

다음 조건을 모두 만족해야 완료로 판단합니다.

```text
SWTITLEVERSION = 260710-native-title-missing-frame-1
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란 = 0
남은 원본 SolidWorks 도면틀 = 0
누락된 GMTITLE 시트 = 0
중복 또는 고아 GMTITLE 쌍 = 0
A2/A3/A4 수량이 변환 전 원본 수량과 일치
도면 안 번호, 주석, BOM, 치수, 모델 형상이 유지됨
대표 A3 DR_titlea_3rd 더블클릭 시 속성 블록 편집 표가 열림
LSP 릴리스/동등성 검사 시 전체 제목블록과 도면틀 편집창 전수검사 통과
```

원본에 제목블록이 없는 것으로 검증된 시트는 제목블록 검사만 예외입니다. 새 제목블록을 억지로 만들지 않되, 해당 DR 도면틀은 더블클릭 시 `제목 블록과 도면 경계` 창이 열려야 합니다.

## 10. 실패했을 때 남길 자료

다음 자료를 현재 컴퓨터로 가져오면 원인 비교가 쉽습니다.

```text
SWTITLEVERSION 명령줄 결과
SWTITLESTATUS 전체 결과
SWTITLEVERIFY 전체 결과
GMTITLE 대화상자 화면
더블클릭 후 열린 창 화면
work 폴더의 swcad_title_*_last.txt 로그
테스트한 DWG 복사본
다른 PC의 GstarCAD Mechanical 정확한 버전과 언어판
```

DWG와 로그에는 회사 정보가 포함될 수 있으므로 GitHub 공개 저장소에 바로 올리지 않습니다.

## 11. 다른 컴퓨터의 Codex에 전달할 문구

다른 컴퓨터에서도 Codex가 사용할 수 있다면 다음 문구를 그대로 전달할 수 있습니다.

```text
GitHub 저장소 https://github.com/adams219/CAD.git 의 codex/gm-title 브랜치를
%USERPROFILE%\Documents\CAD tool 에 받아줘.
원본 DWG는 수정하지 말고 work 폴더의 복사본만 사용해줘.
GstarCAD Mechanical 2024 Korean의 DR_A2/A3/A4_Outline 및 DR_titlea_3rd 설치 여부를 확인하고,
swcad_load.lsp 로드 후 SWTITLEVERSION이 260710-native-title-missing-frame-1인지 확인해줘.
테스트는 SWTITLESTATUS -> 필요한 경우 SWTITLEPREPARE -> SWTITLECONVERTNEXT ->
SWTITLESTATUS -> SWTITLEVERIFY 순서로 진행하고,
마지막에는 새 A3 DR_titlea_3rd를 더블클릭했을 때 속성 블록 편집 표가 열리는지 확인해줘.
화면 좌표 클릭은 사용하지 말고, 실제 업무 원본이나 GstarCAD 설치 원본은 수정하지 마.
```

## 관련 문서

```text
README.md
docs\guide\gmtitle-resume-on-another-computer.md
docs\guide\gmtitle-cad-conversion-checklist.md
docs\guide\commands.md
docs\history\gmtitle-preserve-copy-dialog-automation-plan-2026-07-10.md
```
