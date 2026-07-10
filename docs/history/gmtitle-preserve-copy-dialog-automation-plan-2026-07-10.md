# GMTITLE preserve-copy 및 대화상자 자동화 실험 계획 - 2026-07-10

## 목표

여러 장 GMTITLE 변환에서 시트마다 사람이 용지와 제목블록을 선택하는 횟수를 줄인다.

두 후보를 같은 안전 기준으로 비교한다.

1. 진짜 native GMTITLE frame/title 쌍을 preserve-copy하는 방식
2. GMTITLE 대화상자의 고정 Windows 컨트롤 ID를 사용하는 방식

최종적으로 더 안정적인 후보만 기존 4개 공개 명령 흐름에 통합한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERTNEXT
SWTITLEVERIFY
```

새 공개 LSP 명령은 추가하지 않는다.

## 안전 범위

- 실제 작업복사본 `work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg`는 읽기 원본으로만 사용한다.
- 모든 변경 실험은 `work` 아래 새 이름의 별도 DWG 복사본에서만 수행한다.
- SolidWorks 원본, 실제 작업복사본, GstarCAD 설치 폴더의 DWG는 수정하지 않는다.
- 기존 GstarCAD 프로세스가 하나라도 있으면 `/b` 실험을 시작하지 않는다.
- 화면 좌표, 스크린샷 좌표, 동적 입력창 타이핑은 사용하지 않는다.
- GMTITLE 생성 결과가 예상 블록명·크기·native link 검사를 통과하지 않으면 저장 성공으로 기록하지 않는다.

## 실험 A: preserve-copy 1/2/3 통제 비교

추가한 진단 파일:

```text
diagnostics/gmtitle-main45/preserve_copy_matrix_probe.lsp
diagnostics/gmtitle-main45/run_preserve_copy_matrix_probe.ps1
```

동일한 A3 native-like frame/title 쌍을 시작점으로 잡고 별도 DWG 세 개를 만든다.

복제 과정에서는 새 `clone` marker를 쓰지 않는다. 현재 LSP의 정책 marker를 새로 쓰면 그 marker 자체가 결과에 영향을 줄 가능성을 배제할 수 없기 때문이다. 원본 쌍의 xdata를 그대로 상속하는 순수 `vla-Copy` 결과만 비교한다.

```text
swtitle_preserve_copy_matrix_1.dwg: 1개 복제
swtitle_preserve_copy_matrix_2.dwg: 2개 복제
swtitle_preserve_copy_matrix_3.dwg: 3개 복제
```

각 DWG에서 다음 자료를 같은 형식으로 기록한다.

- 원본과 복제 title/frame handle
- `GENIUS_GENOREF_13` internal handle
- internal handle 공유 여부
- title/frame xdata 전체
- persistent reactor 값
- extension dictionary 값
- owner/object ID
- raw `entget`
- 각 복제 제목블록의 정확한 더블클릭 중심점
- 현재 verifier의 native-like 판정과 이유

과거 이력에서 이미 확인된 반례:

```text
copied A3 title 17A55는 원본과 internal handle 16BF5를 공유했지만
더블클릭 시 Advanced Attribute Editor가 아니라 GMTITLE 표 편집창이 열렸다.
```

따라서 `shared internal handle=yes` 하나만으로 고급 속성 편집기가 열리는 것은 아니다. shared handle은 단독 충분조건이 아니라 상관관계 또는 다중 복제 시 임계조건 후보로 취급한다.

이번 실험은 다음을 구분해야 한다.

```text
1-copy와 2/3-copy가 모두 표 편집창:
  preserve-copy 자체와 shared handle은 현재 환경에서 실패 원인이 아님

1-copy는 표 편집창, 2/3-copy부터 고급 속성 편집기:
  공유 개수/복제 순서/내부 등록 테이블 임계점 후보

동일 복제 수 안에서도 일부만 실패:
  shared handle 외 xdata, reactors, extension dictionary, owner/object 상태 비교 필요

1-copy부터 실패:
  과거 17A55와 현재 복제 경로의 구조 또는 GstarCAD 세션 상태 차이 비교 필요
```

직접 원인은 창 결과가 바뀌는 지점과 함께 변하는 구조 항목이 하나로 좁혀질 때만 확정한다. 구조 차이가 없는데 창 결과만 달라지면 GstarCAD의 비저장 내부 등록 상태나 세션 캐시를 별도 원인 후보로 올린다.

## 실험 B: 고정 컨트롤 ID 대화상자 선택

추가한 진단 파일:

```text
diagnostics/gmtitle-main45/gmtitle_dialog_control_probe.ps1
diagnostics/gmtitle-main45/dialog_control_session_probe.lsp
diagnostics/gmtitle-main45/run_gmtitle_dialog_control_session.ps1
```

과거 접근성 검사에서 확인한 컨트롤 ID:

```text
3010: paper/frame combo
3011: title block combo
3022: Frame positioning
3024: Object move
1: OK
```

추가 로컬 근거:

```text
PaperSet.grx PE exports:
  ?Entry_superBlockEdit@@YAXXZ
  I_SuperBlockEdit
  gcrxEntryPoint
  gcrxGetApiVersion
```

용지/제목블록 선택값을 직접 받는 공개 export는 확인되지 않았다. 따라서 현재 비교 대상은 공개 API가 아니라 preserve-copy와 고정 컨트롤 ID 선택이다.

적용 전에 반드시 다음을 모두 다시 읽어 검증한다.

```text
paper/frame = DR_A3_Outline
title block = DR_titlea_3rd
Frame positioning = ON
Object move = OFF
대상 DWG = work 아래 전용 dialog probe 복사본
GMTITLE 후보 대화상자 수 = 정확히 1개
```

검증을 통과한 경우에만 OK 컨트롤을 실행한다. 생성 뒤에는 LSP가 새 INSERT를 다시 찾아 예상 frame/title 블록명과 native 결과를 확인하고, 통과한 전용 probe DWG만 저장한다.

## 현재 상태

2026-07-10 정적 준비 상태:

```text
새 LSP 진단 파일 괄호 균형: PASS
새 PowerShell 파일 구문 검사: PASS
run_static_preflight.ps1: PASS
git diff --check: 오류 없음
실제 작업복사본 변경: 없음
```

CAD 실행 상태:

```text
PID 4848의 gcad.exe가 MainWindowHandle=0 상태로 남아 있음
Running Object Table 활성 문서 연결: 확인되지 않음
Windows 앱 검사에서는 별도의 사용자 DWG가 열린 GstarCAD 창이 확인됨
안전을 위해 matrix/dialog 실험 runner가 실행을 거부함
```

`MainWindowHandle=0`과 COM 연결 실패만 보고 빈 프로세스로 판단하면 안 된다. GstarCAD Mechanical은 Computer Use 창 목록에는 실제 사용자 도면 창을 노출했다. 따라서 이 프로세스는 강제 종료하지 않고, 사용자가 열린 도면을 저장하고 GstarCAD를 정상 종료한 뒤에만 실험을 계속한다.

따라서 아직 확정하지 않은 항목:

- 1/2/3 구조 로그 실제 생성
- 각 복제본의 더블클릭 편집창 결과
- 컨트롤 ID 선택·readback·OK 동작
- 생성된 GMTITLE 쌍의 native 검증
- 두 후보 중 최종 채택 방식

## 다음 순서

1. 사용자가 현재 CAD 작업이 저장됐는지 확인하고 GstarCAD를 정상 종료한다.
2. `run_preserve_copy_matrix_probe.ps1`로 1/2/3 구조 로그와 별도 DWG를 만든다.
3. 한 번의 대표 CAD 세션에서 세 파일의 복제 제목블록을 더블클릭해 창 종류를 기록한다.
4. `run_gmtitle_dialog_control_session.ps1`로 고정 ID 자동 선택을 별도 복사본에서 검증한다.
5. 결과를 비교해 preserve-copy 또는 고정 ID 방식을 선택한다.
6. 선택한 방식만 기존 4개 명령 내부에 통합한다.
7. 전체 정적/hidden suite와 대표 CAD 검증을 다시 수행한다.
8. 이력 갱신 후 커밋 준비를 한다.

## 2026-07-10 실행 결과

### preserve-copy 1/2/3 구조 비교

전용 복사본 세 개를 생성해 같은 A3 native GMTITLE frame/title 쌍을 각각 1개, 2개, 3개 복제했다.

```text
work\swtitle_preserve_copy_matrix_1.dwg
work\swtitle_preserve_copy_matrix_2.dwg
work\swtitle_preserve_copy_matrix_3.dwg
```

세 경우 모두 다음 특성이 같았다.

```text
복제 title/frame의 native internal handle: 16D24 공유
원본 xdata 상속
persistent reactor: 없음
extension dictionary: 없음
새 custom clone marker: 추가하지 않음
```

과거에 GMTITLE 표 편집창으로 정상 열린 preserve-copy도 원본과 internal handle을 공유한 기록이 있다. 따라서 다음 인과관계는 성립하지 않는다.

```text
shared internal handle=yes
  -> 반드시 고급 속성 편집기로 열림
```

공유 internal handle은 구조상 위험 신호일 수 있지만, 편집창 종류를 단독으로 결정하는 충분조건은 아니다. 세션 내부 등록 상태나 PaperSet의 비공개 상태가 함께 관여할 가능성이 남는다.

구조 로그:

```text
work\swtitle_preserve_copy_matrix_1.txt
work\swtitle_preserve_copy_matrix_2.txt
work\swtitle_preserve_copy_matrix_3.txt
```

실제 GstarCAD 화면에서 1/2/3 복제본의 모든 제목블록을 각각 더블클릭했다.

```text
matrix 1: copy 1 / title 16D2C / PRESERVE_COPY_MATRIX_1 -> 속성 블록 편집
matrix 2: copy 1 / title 16D2C / PRESERVE_COPY_MATRIX_1 -> 속성 블록 편집
matrix 2: copy 2 / title 16D3A / PRESERVE_COPY_MATRIX_2 -> 속성 블록 편집
matrix 3: copy 1 / title 16D2C / PRESERVE_COPY_MATRIX_1 -> 속성 블록 편집
matrix 3: copy 2 / title 16D3A / PRESERVE_COPY_MATRIX_2 -> 속성 블록 편집
matrix 3: copy 3 / title 16D48 / PRESERVE_COPY_MATRIX_3 -> 속성 블록 편집
결과: 6 / 6 PASS_GMTITLE_TABLE_EDITOR
고급 속성 편집기: 0 / 6
```

따라서 같은 internal handle `16D24`를 공유한 복제본도 이번 고정 세션에서는 모두 표 편집창으로 열렸다. **공유 handle 자체가 고급 속성 편집기를 직접 발생시킨다는 가설은 기각한다.** 과거 일부 도면에서 편집창이 달라진 원인은 세션 내부 등록 상태, 복제 시점, PaperSet의 비공개 상태 등 다른 조건과 결합된 현상으로 남겨 둔다.

정확한 handle에 `GMPOWEREDIT` 명령을 직접 전달하면 표 편집창이 아니라 `제목 블록과 도면 경계` 창으로 갈 수 있었다. 이 명령 경로는 사용자가 제목 값 위를 더블클릭하는 경로와 같지 않으므로 편집창 판정 자동화에는 사용하지 않는다.

편집기 결과가 모두 정상이어도 preserve-copy는 현재 구조 검증에서 각 복제 쌍의 고유 native-like 관계를 입증하지 못한다. 따라서 생산 방식은 계속 고정 컨트롤 native 생성으로 유지하고, preserve-copy는 원인 조사 자료로만 남긴다.

화면 검증 로그:

```text
work\swtitle_preserve_copy_matrix_editor_results.txt
```

### 고정 컨트롤 GMTITLE 선택 결과

GMTITLE 대화상자에서 다음 컨트롤 ID를 사용하는 전용 보조 프로그램을 검증했다.

```text
3010: paper/frame combo
3011: title block combo
3022: Frame positioning
3024: Object move
1: OK
```

전용 work 복사본에서 다음 값을 설정하고 readback한 뒤 OK를 실행했다.

```text
DR_A3_Outline
DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

결과:

```text
고정 컨트롤 선택/readback: PASS
새 native frame/title 생성: PASS
새로 발급된 shared internal link: 16D3D
원본 preserve-copy link 재사용: 없음
화면 좌표 사용: 없음
```

따라서 생산 경로는 preserve-copy가 아니라 **GstarCAD가 GMTITLE 명령 안에서 각 시트의 새 native 쌍을 직접 생성하도록 하는 고정 컨트롤 방식**으로 결정했다.

### 기존 공개 명령 통합 결과

새 공개 LSP 명령을 만들지 않고 기존 `SWTITLECONVERTNEXT` 내부에 생산용 helper를 연결했다.

```text
src\tools\gmtitle\swtitle_gmtitle_dialog_autoselect.ps1
```

보호 조건:

```text
DWG가 Documents\CAD tool\work 아래 복사본일 것
현재 GstarCAD application HWND가 확인될 것
GMTITLE 후보 대화상자가 정확히 하나일 것
필수 컨트롤 ID가 모두 존재할 것
paper/title/options readback이 예상값과 정확히 같을 것
```

조건이 하나라도 다르면 OK를 누르지 않고 기존 원본 시트를 유지한다.

### 공개 명령 전체 흐름 검증

전용 결과 복사본:

```text
work\swtitle_integrated_autoselect_fullflow_probe.dwg
```

실제 `SWTITLECONVERTNEXT` 공개 흐름으로 수행한 결과:

```text
남은 표제란 시트 8장 -> 0장
target 제목블록 -> 13개
target GMTITLE pair -> 13개
shared native-link target title -> 0개
native-upgrade candidate -> 0개
결과 -> OK_NATIVE_AUTOSELECT_BATCH_COMPLETE
```

원본 표제란 부재가 검증된 title-missing 도면틀 시트도 같은 A1-A4 공통 예외 흐름 안에서 처리했다.

```text
title-missing 도면틀 시트 2장 -> 0장
target frame -> 15개
target title -> 13개
새 불필요 제목블록 -> 0개
결과 -> OK_TITLE_MISSING_OUTLINE_BATCH_COMPLETE
```

독립 읽기 전용 최종 probe:

```text
source-title-count: 0
source-frame-count: 0
frame-only-count: 0
target-title-count: 13
target-frame-count: 15
target-pair-count: 13
native-like: 13
non-native-like: 0
cloned: 0
native-upgrade candidates: 0
orphan: 0
duplicate: 0
A2: 1
A3: 12
A4: 2
SWTITLESTATUS: NEXT_FINAL_VERIFY_AND_DOUBLE_CLICK
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_OK
DBMOD after read-only probe: 0
```

검증 로그:

```text
work\swtitle_integrated_autoselect_fullflow_verify.txt
```

원본 workcopy SHA-256은 실험 전후 동일했다.

### 배포에서 제외한 실험

`GMSBLOCKE`/`GMPOWEREDIT`를 사용해 제목블록 편집창 종류를 자동 판정하려던 별도 editor probe는 명령 라우팅이 일정하지 않았다. 정확한 새 A3 제목블록 대신 `제목 블록과 도면 경계` 생성 창으로 들어갈 수 있어 배포와 정적 필수 검사에서 제거했다.

편집창 검증은 자동 probe 결과만으로 완료 처리하지 않고 실제 화면에서 대표 A3를 한 번 더블클릭했다. 2026-07-10 18:21 KST에 full-flow 결과의 byte-identical 전용 복사본을 열고 다음 객체를 확인했다.

```text
테스트 DWG: work\swtitle_integrated_autoselect_editorcheck_probe.dwg
대표 title: DR_titlea_3rd / handle 16DB5
paired frame: DR_A3_Outline / handle 16DB0
열린 창: 속성 블록 편집
표에 표시된 행: Checked by, Designed by, Approved by, Date, Scale, Edition, Sheet, FILE NO, File Name, Q'ty, Material
나오지 않은 실패 창: 고급 속성 편집기, 제목 블록과 도면 경계, REFEDIT
결과: PASS_GMTITLE_TABLE_EDITOR
```

값은 바꾸지 않고 편집창을 취소했다. 종료 시 저장 질문도 취소하여 디스크에는 저장하지 않았다. 실제 작업복사본과 full-flow 원본 결과 DWG의 SHA-256은 기존 기준값과 일치한다.

세부 실행 로그:

```text
work\swtitle_integrated_autoselect_editorcheck_result.txt
```

### 전체 클릭 전수검사에서 확인된 보정 사항

대표 A3 한 장의 성공만으로 전체 편집기 동작을 완료 판정하면 안 된다는 사실이 후속 전수검사에서 확인됐다. `work\swtitle_integrated_autoselect_fullflow_probe.dwg`의 byte-identical 전용 복사본을 만들고 제목블록 13개와 도면틀 15개를 모두 직접 더블클릭했다.

```text
테스트 DWG: work\swtitle_integrated_autoselect_allclick_probe.dwg
구조 점검: native-like 도면틀 15 / 15

제목블록 13개:
  속성 블록 편집 표 12개
  고급 속성 편집기 1개
  실패 title=16CF0, paired frame=DR_A3_Outline/16CEB

도면틀 15개:
  제목 블록과 도면 경계 13개
  A2 1/1 정상
  A3 12/12 정상
  A4 2개 모두 REFEDIT
  실패 frame=DR_A4_Outline/16FD5, DR_A4_Outline/16FD4
```

A4 REFEDIT 창에는 `DR_A4_Outline` 아래 `_도면 테두리 A4 From_HYUN`, `HD-Rev No table`이 표시됐다. 따라서 현재 title-missing A4 결과는 target block 이름과 marker가 있어도 실제 GMTITLE 도면틀 편집 동작까지 확보하지 못했다.

이 결과로 다음 두 가정을 폐기한다.

```text
native-like/marker/xdata 구조 판정 통과 -> 실제 GMTITLE 편집 동작도 모두 정상
대표 A3 한 장의 표 편집창 통과 -> 변환된 전체 시트의 클릭 동작 통과
```

생산 자동 선택 방향은 유지할 수 있지만, 현재 full-flow 결과를 최종 완료로 간주할 수는 없다. A3 실패 title `16CF0`과 정상 title의 비공개 등록 상태 차이, A4 target 정의에 남은 nested source block을 별도 원인으로 조사해야 한다.

전수검사 로그:

```text
work\swtitle_integrated_autoselect_allclick_results.txt
```

## 채택 결론

```text
생산 방식: 고정 컨트롤 ID로 실제 native GMTITLE을 시트마다 생성
preserve-copy: 구조 비교/원인 조사 자료로만 유지
화면 좌표 클릭: 사용하지 않음
공개 명령: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERTNEXT, SWTITLEVERIFY 유지
A4 전용 처리: 만들지 않음
title-missing: 용지 크기가 아니라 원본 표제란 부재가 검증된 경우의 공통 예외
```

## 완료 기준

- 실제 작업복사본과 원본이 바뀌지 않는다.
- 시트별 사람이 용지/제목블록을 반복 선택하는 횟수가 실질적으로 줄어든다.
- 잘못된 용지·제목블록·옵션이면 자동으로 멈추고 기존 원본 시트는 유지된다.
- A2/A3/A4 공통 흐름을 유지하며 A4 전용 분기를 다시 만들지 않는다.
- 새 공개 LSP 명령이 없다.
- 구조 로그와 실제 더블클릭 결과가 같은 결론을 지지한다.
- 전체 제목블록과 도면틀의 실제 클릭 결과가 구조 판정과 일치한다.
- 이 시점의 실패 전수검사에서는 A3 제목블록 1개와 A4 도면틀 2개가 기준을 통과하지 못했다. 아래 후속 수정과 새 full-flow 전수검사에서 모두 통과했다.

## 2026-07-10 native title-missing 수정과 최종 전수검사

앞의 실패 전수검사 이후 구조 판정과 실제 클릭 경로를 다시 분리해 조사했다. 결론은 두 실패가 같은 원인이 아니었다.

### A3 16CF0 재판정

`16CF0`의 bounding box 중심은 실제 DR 제목블록 글자나 로고가 없는 빈 영역 또는 다른 객체와 겹치는 영역이었다. 그 좌표를 더블클릭해 열린 고급 속성 편집기는 제목블록 자체의 편집 동작을 대표하지 않았다. 각 handle로 확대한 뒤 실제 DR 로고/제목블록 선을 더블클릭하는 방식으로 다시 검사하자 `16CF0`을 포함한 13개 모두 `속성 블록 편집` 표가 열렸다.

따라서 편집창 전수검사는 다음 규칙을 사용한다.

```text
제목블록: handle로 확대 -> 보이는 DR 로고 또는 실제 제목블록 선을 더블클릭
도면틀: handle로 확대 -> 실제 바깥 경계선을 더블클릭
bbox 중심점만으로 편집기 종류를 판정하지 않음
```

### title-missing native 도면틀 수정

깨끗한 새 도면에서 실제 GMTITLE로 A4 frame/title 쌍을 만든 뒤 제목블록 INSERT만 삭제하는 대조 실험을 수행했다. 제목블록을 삭제한 뒤에도 도면틀의 native internal link가 유지됐고, 저장 후 다시 열어도 도면틀 더블클릭은 `제목 블록과 도면 경계` 창으로 연결됐다. 이 결과를 바탕으로 title-missing 공통 예외를 다음과 같이 변경했다.

```text
1. 원본 표제란 부재가 검증된 시트의 크기를 읽음
2. 같은 크기의 실제 DR_A*_Outline + DR_titlea_3rd를 GMTITLE로 생성
3. 원본 왼쪽 아래 위치에 맞춤
4. frame geometry와 internal native link를 검증
5. 임시 DR_titlea_3rd만 삭제
6. 제목블록 삭제 후 frame native link가 살아 있는지 재검증
7. 위 조건이 모두 맞을 때만 기존 원본 frame과 잔여물을 삭제
```

숨김 SCRIPT에서는 대화상자 기반 native GMTITLE을 안전하게 만들 수 없으므로 `ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE`로 중단한다. 이 경우 원본 title-missing 시트, 기존 target title 수, target frame 수를 모두 보존한다. 실제 변환 성공 증거는 고정 컨트롤 자동 선택을 사용한 visible full-flow에서 만든다.

깨끗한 native A4의 `_도면 테두리 A4 From_HYUN`은 GstarCAD가 직접 만든 정상 하위 블록이었다. 이전 실패 정의의 `HD-Rev No table`이 원본에서 섞여 들어간 오염 객체였으며, 정상 native 하위 블록까지 모두 제거하는 것은 올바른 기준이 아니다.

### 새 full-flow 결과

```text
생성 도면: work\swtitle_native_click_fullflow_260710.dwg
검증 로그: work\swtitle_native_click_fullflow_verify_260710.txt
클릭 로그: work\swtitle_native_click_fullflow_allclick_results_260710.txt
LSP 버전: 260710-native-title-missing-frame-1

원본 표제란 시트: 0
원본 도면틀: 0
title-missing/frame-only: 0
target title: 13
target frame: 15
target pair: 13
native-like / non-native / clone: 13 / 0 / 0
orphan / duplicate: 0 / 0
A2 / A3 / A4: 1 / 12 / 2
SWTITLESTATUS: NEXT_FINAL_VERIFY_AND_DOUBLE_CLICK
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_OK
```

실제 화면 전수검사:

```text
제목블록 13 / 13: 속성 블록 편집
고급 속성 편집기: 0
도면틀 15 / 15: 제목 블록과 도면 경계
REFEDIT: 0
```

편집창은 모두 값을 바꾸지 않고 취소했다. GstarCAD 편집창을 전수로 열고 닫은 세션은 `DBMOD=2121`이 됐으므로 저장하지 않고 `아니요`로 닫았다. 디스크의 full-flow SHA-256은 `9B0F94C84E2222D185FD4551502DAFBCCAE89BC50E37C55DA0F6305414CFD68C`로 유지됐고, 입력 work-copy SHA-256도 `8E881D90B69D2A3196718531DC33EF540DC137A21DE5411A1F1E66492D32D580`으로 유지됐다.

최종 결론은 구조 로그와 실제 클릭 결과가 일치한다. A2/A3/A4 공통 생성 흐름을 유지하고, title-missing은 용지 크기가 아니라 원본 표제란 부재가 검증된 경우에만 적용한다.

### 숨김 suite 재실행 경계

최종 코드로 정적 사전검사는 통과했다. 같은 날 21:08 KST의 18단계 숨김 suite도 한 차례 PASS했지만, 문서 정리 후 21:33 KST 재실행에서는 첫 `/b` smoke가 최소화/최대화 두 방식 모두 SCR 완료 로그를 만들지 못해 본 단계 진입 전에 중단됐다. 실행기는 시작한 GstarCAD 프로세스를 종료했고 원본과 work-copy를 수정하지 않았다.

```text
중단 위치: GstarCAD /b one-line smoke
결과: no log created
해석: 현재 Windows/GstarCAD 세션의 비대화식 시작 실패
해석하지 않는 것: GMTITLE LSP 로직 회귀 실패
대체 최신 증거: visible full-flow + SWTITLEVERIFY_FINAL_OK + 제목 13/13/도면틀 15/15 실제 클릭
```

따라서 현재 `work\main56_verification_suite_last_run.txt`의 `FAILED_BEFORE_PASS`는 기능 실패 증거가 아니라 smoke 환경 실패 기록이다. 숨김 suite를 다시 신뢰하려면 먼저 한 줄짜리 `HIDDEN_SCRIPT_SMOKE_OK`가 생성되는 세션을 확보해야 한다.
