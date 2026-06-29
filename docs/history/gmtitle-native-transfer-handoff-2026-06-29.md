# GMTITLE Native Transfer Handoff - 2026-06-29

이 문서는 다른 컴퓨터나 새 Codex 세션에서 현재 작업을 이어가기 위한 인계 기록입니다.

## 현재 목표

SOLIDWORKS에서 DWG로 저장한 도면을 GstarCAD Mechanical 도면으로 정리한다.

구체적인 방향은 다음과 같다.

1. SOLIDWORKS DWG의 기존 표제란 텍스트를 추출한다.
2. 기존 SOLIDWORKS 도면틀, 표제란, 표제란 안의 분리된 텍스트를 제거한다.
3. `GMTITLE` 명령으로 만든 진짜 DR 계열 A3 도면틀과 DR 제목블록을 넣는다.
4. 추출한 텍스트를 새 `GMTITLE` 제목블록 속성에 자동으로 채운다.
5. 새 제목블록을 더블클릭했을 때 GstarCAD Mechanical의 표 형식 속성 편집창이 유지되는지 확인한다.
6. `FILEDIA=1`, `CMDDIA=1`은 사람이 직접 고르는 흐름을 위해 그대로 유지한다.

중요한 방향 수정:

- seed DWG를 삽입하거나 원본 DWG를 직접 import하는 방향이 아니다.
- 최종 결과는 반드시 실제 `GMTITLE` 명령으로 생성된 도면틀/제목블록이어야 한다.
- 이유는 직접 DWG 삽입 방식에서는 더블클릭 시 고급 속성 편집기로 들어가서 사용자가 원하는 GMTITLE 표 편집창이 유지되지 않았기 때문이다.

## 현재 코드 상태

주요 파일:

```text
src/tools/gmtitle/swcad_title_scale.lsp
```

현재 구현 버전 문자열:

```text
260629-native-batch
```

주요 명령:

```text
SWTITLEDEBUG
SWTITLESCAN
SWTITLETEXTSCAN
SWTITLEGMTITLEVERIFY
SWTITLETRANSFERPREVIEW
SWTITLETRANSFERAPPLY
SWTITLETRANSFERBATCH
SWSCALESCAN
```

핵심 구현 내용:

- `SWTITLETRANSFERPREVIEW`
  - 기존 SOLIDWORKS/DR 표제란 텍스트를 읽고 GMTITLE 속성으로 어떻게 매핑될지 로그로 보여준다.
  - 도면 데이터는 변경하지 않는다.

- `SWTITLETRANSFERAPPLY`
  - 기존 표제란 텍스트를 추출한다.
  - `(initdia)` 후 `(command "GMTITLE")`로 실제 `GMTITLE` 대화상자를 호출한다.
  - 사용자가 `DR_A3_Outline`과 `DR_titlea_3rd`를 선택하면 새 GMTITLE 객체에 추출한 텍스트를 채운다.
  - 선택이 잘못되면 새로 생긴 잘못된 GMTITLE insert만 제거하고, 기존 도면 내용은 보존한다.
  - 원본 도면 실수 편집을 막기 위해 `work` 폴더 밖에서는 사용자가 `EDIT`를 직접 입력하지 않으면 적용하지 않는다.

- `SWTITLETRANSFERBATCH`
  - 여러 장 처리를 위해 `SWTITLETRANSFERAPPLY`를 반복 실행한다.
  - 각 장마다 실제 GMTITLE 대화상자가 뜨고 사용자가 용지/제목블록을 선택하는 흐름이다.

- `SWTITLEGMTITLEVERIFY`
  - 현재 도면에 `DR_A3_Outline`, `DR_titlea_3rd`가 제대로 들어왔는지 확인한다.
  - 제목블록 속성 개수, 빈 값, 예상 태그 누락, native `GENIUS_GENOREF_13` XData 연결을 로그로 남긴다.
  - `FILEDIA`, `CMDDIA`는 변경하지 않고 현재 값을 기록만 한다.

## 최근 커밋

```text
90336cc Guard GMTITLE transfer against original DWGs
621bf1b Harden native GMTITLE transfer workflow
f549ac2 Apply GM title transfer with fallback blocks
57666aa Add GM title transfer apply command
3a09fd4 Preview GM title field transfer
```

중요:

- `f549ac2` 시점에는 fallback 블록 생성 방식이 있었지만, 현재 방향은 그 방식이 아니다.
- 최신 흐름은 `621bf1b`, `90336cc` 기준의 native `GMTITLE` 호출 방식이다.

## 검증된 내용

### GMTITLE 제목블록 검증

최근 검증 로그:

```text
work/swcad_title_gmtitle_verify_last.txt
```

검증 대상:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\Motor Mount_Test_260626_seed_apply_test.dwg
```

검증 결과 요약:

```text
Target frame block: DR_A3_Outline, inserts=1
Target title block: DR_titlea_3rd, inserts=1
Title attributes: 11
Non-empty title attributes: 11
Missing expected title tags: <none>
Native GMTITLE GENIUS_GENOREF_13 handle links: 790
Other title-like inserts that are not the target GMTITLE block: <none>
Result: OK_VERIFY_GMTITLE_READY_FOR_MANUAL_DOUBLE_CLICK_CHECK
```

수동 확인:

- 새 GMTITLE 제목블록을 더블클릭했을 때 `속성 블록 편집` 표 형식 창이 열렸다.
- 표에는 `Checked by`, `Designed by`, `Approved by`, `Date`, `Scale`, `Edition`, `Sheet`, `FILE NO`, `File Name`, `Q'ty`, `Material` 행이 보였다.
- 이 동작이 사용자가 원하는 편집 방식이다.

### 기존 표제란 텍스트 매핑 검증

최근 preview 로그:

```text
work/swcad_title_transfer_preview_last.txt
```

검증 대상:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\Motor Mount_Test_260626_native_preview_test.dwg
```

검증 결과 요약:

```text
Source title insert: DR_표제란_FTAP
Mapped fields: 10
Missing target fields: 1
Unmapped source texts: 1
Duplicate source texts: 0
Source frame insert: 도면 세로 A4 FROM_HYUN
Old loose title graphics cleanup candidates: 66
Old loose frame graphics cleanup candidates: 0
```

대표 매핑:

```text
GEN-TITLE-QTY{10}  <= "1"
GEN-TITLE-NAME{10} <= "HS KANG"
GEN-TITLE-CHKM{10} <= "KS LEE"
GEN-TITLE-APPM{21.7} <= "KS LEE"
GEN-TITLE-DATE{11.7} <= "2026-06-26"
GEN-TITLE-SCA{6.7} <= "1:1"
GEN-TITLE-DWG{23} <= "Motor Mount"
GEN-TITLE-NR{23} <= "-"
GEN-TITLE-REV{5} <= "0"
GEN-TITLE-SIZ{6.7} <= "A4"
```

아직 빠진 값:

```text
GEN-TITLE-MAT1{10} [material] <= <missing>
```

이 값은 원본 도면에 material 텍스트가 없거나 탐지 기준에 걸리지 않은 것으로 보인다.

## 아직 끝나지 않은 것

2026-06-29 오후 추가 테스트 전까지는 실제 apply 테스트가 남아 있었다.

이후 `work\Motor Mount_Test_260626_native_apply_test_260629_02.dwg`에서 실제 적용 검증을 완료했다.

완료된 검증:

```text
SWTITLETRANSFERPREVIEW
SWTITLETRANSFERAPPLY
SWTITLEGMTITLEVERIFY
제목블록 더블클릭 표 편집창 확인
```

적용 성공 로그 요약:

```text
DWG: C:/Users/DR-DESIGN/Documents/CAD tool/work/Motor Mount_Test_260626_native_apply_test_260629_02.dwg
FILEDIA before: 1 (not changed)
CMDDIA before: 1 (not changed)
Native GMTITLE title insert: block=DR_titlea_3rd
Native GMTITLE frame insert: block=DR_A3_Outline
Attributes set: 10
Old loose title texts deleted: 11
Old loose title graphics deleted: 66
Old title insert deleted: yes
Old frame insert deleted: yes
Result: APPLIED_TITLE_TRANSFER
```

검증 성공 로그 요약:

```text
Target frame block: DR_A3_Outline, inserts=1
Target title block: DR_titlea_3rd, inserts=1
Title attributes: 11
Non-empty title attributes: 11
Missing expected title tags: <none>
Native GMTITLE GENIUS_GENOREF_13 handle links: 9FF
Other title-like inserts that are not the target GMTITLE block: <none>
Result: OK_VERIFY_GMTITLE_READY_FOR_MANUAL_DOUBLE_CLICK_CHECK
```

수동/화면 확인:

- 새 `DR_titlea_3rd` 제목블록을 더블클릭했을 때 `속성 블록 편집` 표 형식 창이 열렸다.
- 표에는 `Checked by`, `Designed by`, `Approved by`, `Date`, `Scale`, `Edition`, `Sheet`, `FILE NO`, `File Name`, `Q'ty`, `Material` 행이 보였다.
- 이관된 값은 `KS LEE`, `HS KANG`, `2026-06-26`, `1:1`, `A4`, `Motor Mount`, `1`, `-` 등으로 채워졌다.

구현상 중요한 수정:

- GstarCAD에서 `(vl-catch-all-apply 'command ...)`로 `GMTITLE`을 호출하면 `COMMAND` 관련 오류가 나며 삽입 흐름이 깨졌다.
- `swcad-title-run-native-gmtitle`에서 native 명령 호출을 직접 `(command "GMTITLE")`, `(command pause)` 방식으로 바꾸자 실제 대화상자, 삽입, 후처리까지 진행됐다.
- 현재 버전 문자열은 `260629-native-command-direct`이다.

GMTITLE 대화상자에서 성공한 선택 방법:

- 용지 형식: `DR_A3_Outline`
- 제목 블록: `DR_titlea_3rd`
- `객체 이동(M)`은 해제했다. 켜져 있으면 `객체의 새 위치` 프롬프트가 추가로 뜬다.
- 용지 콤보는 `A3 (297x420mm)`에서 드롭다운을 연 뒤 아래로 16번 이동하면 `DR_A3_Outline`에 도달했다.

남은 작업은 전체 자동화 품질을 올리는 것이다.

남은 핵심 작업:

1. 여러 장 도면에서 `SWTITLETRANSFERBATCH`가 같은 흐름으로 반복 가능한지 확인한다.
2. `GMTITLE` 대화상자 선택을 좌표 의존이 아닌 키보드 단계 또는 문서화된 내부 설정 방식으로 더 안정화한다.
3. `객체 이동(M)` 해제를 자동화하거나 사용자 안내에 명확히 포함한다.
4. Material처럼 원본에 없는 값 또는 탐지되지 않은 값의 기본값 정책을 정리한다.
5. 변환된 테스트 도면을 저장할지, 로그만 남길지 운영 흐름을 정한다.

주의:

- `Motor Mount_Test_260626_native_preview_test.dwg`는 한 번 중복으로 열려 읽기 전용 탭이 생긴 적이 있다.
- 실제 apply 테스트는 새 이름의 쓰기 가능한 복사본에서 해야 한다.
- 예: `work\Motor Mount_Test_260626_native_apply_test_260629.dwg`

## 다음 컴퓨터에서 이어갈 때 사용할 목표 문구

새 Codex 세션에서 아래 내용을 그대로 전달하면 된다.

```text
추천 방향으로 계속 진행해줘.

SOLIDWORKS DWG에서 기존 표제란 텍스트를 추출하고, 기존 SOLIDWORKS 도면틀/표제란/텍스트를 제거한 뒤, seed/import가 아니라 실제 GstarCAD Mechanical GMTITLE 명령을 호출해서 DR_A3_Outline + DR_titlea_3rd를 넣어줘. 추출한 텍스트는 새 GMTITLE 제목블록 속성에 채우고, 더블클릭했을 때 GMTITLE 표 편집창이 유지되는지 확인해줘. FILEDIA=1, CMDDIA=1은 그대로 놔둬.

인계 문서는 docs/history/gmtitle-native-transfer-handoff-2026-06-29.md를 봐줘.
```

## 다음 작업 순서

다른 컴퓨터에서 저장소를 받은 뒤:

```powershell
cd "C:\Users\DR-DESIGN\Documents\CAD tool"
git pull
```

GstarCAD에서 LSP 로드:

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

테스트 복사본을 열고:

```text
SWTITLETRANSFERPREVIEW
SWTITLETRANSFERAPPLY
SWTITLEGMTITLEVERIFY
```

검증 로그 위치:

```text
work\swcad_title_transfer_preview_last.txt
work\swcad_title_transfer_apply_last.txt
work\swcad_title_gmtitle_verify_last.txt
```

## CAD 조작 관련 메모

Codex가 직접 CAD 화면을 조작할 때 주의할 점:

- 화면 좌표 기반 클릭은 단기적으로만 사용한다.
- 명령줄에 긴 문자열을 무작정 붙여넣으면 `PASTECLIP`처럼 엉뚱한 명령으로 들어갈 수 있다.
- 이전 테스트에서 COM `GetActiveObject` 방식은 GstarCAD가 Running Object Table에 잡히지 않아 실패했다.
- `gcad.exe /b` 스크립트 자동 실행도 로그를 안정적으로 만들지 못했다.
- 현재 가장 안정적인 방식은 사용자가 CAD를 열어둔 상태에서 명령줄에 짧은 명령을 넣고, 실제 `GMTITLE` 선택은 대화상자에서 사람이 고르는 방식이다.

## 안전장치

- `SWTITLETRANSFERAPPLY`는 기본적으로 `work` 폴더 안 테스트 복사본에서만 적용한다.
- `work` 폴더 밖의 도면에서는 `EDIT`를 직접 입력해야만 진행한다.
- 원본 DWG는 직접 수정하지 않는다.
- `FILEDIA`와 `CMDDIA`는 사용자가 요청한 대로 1을 유지하고, 코드에서 0으로 바꾸지 않는다.
