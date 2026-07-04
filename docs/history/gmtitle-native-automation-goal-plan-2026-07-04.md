# GMTITLE native 자동화 목표 계획 - 2026-07-04

## 목표

SolidWorks DWG를 GstarCAD Mechanical native GMTITLE 구조로 안정 변환한다.

최종 목표는 사용자가 A3 여러 장을 하나씩 `GMTITLE` 창에서 반복 선택하지 않아도 되게 만드는 것이다. 다만 자동화가 GstarCAD native 인식을 깨뜨리면 안 되므로, 자동화보다 native 구조 검증을 먼저 둔다.

## 현재 결론

현재 LSP 기준:

```text
260704-target-overlap-adopt-main63-guided-a3a4-batch
```

main59/main60/main61/main62/main63에서 추가한 것:

```text
SWTITLESTATUS 내부 native 도면틀 확인 로그에
첫 native-like 쌍과 첫 non-native 교체 후보의 구조 비교 샘플을 출력한다.
SWTITLESTATUS 내부 다음 단계/구조 판단 요약에 자동화 정책을 출력한다.
main61에서는 구조 판단 요약의 권장 다음 명령이 A3/A4 native 교체 후보를 A4 frame-only보다 먼저 안내하도록 우선순위를 맞췄다.
main62에서는 핵심 SWTITLESTATUS/SWTITLEVERIFY 안내와 로더 문구를 한국어로 정리해 CAD 명령창에서 다음 행동을 더 읽기 쉽게 했다.
main63에서는 새 공개 명령을 만들지 않고 SWTITLECONVERT 안에서 A3/A4 native 교체용 OPEN/BATCH 선택지를 제공한다.

비교 항목:
  sheet / block / reason / role
  title-frame handle
  xdata app 목록
  GENIUS_GENOREF_13 native handle link
  native target kind
  제목블록 shared-native-link 여부
  persistent reactor 수
  extension dictionary 수
  bbox
```

이 보강은 도면을 바꾸지 않는 read-only 진단이다. 목적은 사람이 반복 선택해야 하는 근본 이유가 `clone`, `shared-native-link-handle`, `xdata/link 차이`, `marker role` 중 무엇인지 다음 CAD 로그에서 바로 보이게 하는 것이다.

CAD에서 확인할 로그:

```text
SWTITLESTATUS
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_native_frame_check_last.txt
```

사용자용 공개 명령은 계속 아래 네 개로 유지한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

읽기 전용 보조 명령은 아래만 허용한다.

```text
SWTITLEVERSION
SWSCALESCAN
```

main63 정적 확인 결과, `src/tools/gmtitle/swcad_title_scale.lsp`의 public `defun c:` 명령은 위 6개뿐이다. 예전 transfer/fast/A3A4/frame-only/verify-all 명령은 `swcad-title-disable-legacy-public-commands` 목록에서 비활성화 대상으로 관리한다.

현재 파악한 구조:

```text
도면틀: DR_A*_Outline INSERT
제목블록: DR_titlea_3rd INSERT
제목블록 속성: GEN-TITLE-* 태그
GstarCAD native 연결 후보: GENIUS_GENOREF_13 xdata handle link
SWTITLE 검증 marker: SWTITLE_EXEMPLAR / SWTITLE_NATIVE_EXEMPLAR
추가 판단 요소: role, shared native-link handle, bbox, source-contamination, double-click behavior
```

중요한 한계:

```text
SWTITLE marker와 복사된 xdata만으로는 native GMTITLE 증거로 인정하지 않는다.
복제본은 겉모양과 속성값은 맞아도 GstarCAD native 편집기 인식이 증명되지 않는다.
여러 제목블록이 같은 내부 native handle을 공유하면 shared-native-link-handle 상태로 보고 native-like에서 제외한다.
```

## 지금 사람이 필요한 이유

`SWTITLECONVERT`가 복제 A3/A4를 fresh native GMTITLE로 교체하려면 결국 GstarCAD가 실제 `GMTITLE` 명령을 통해 새 도면틀/제목블록 쌍을 생성해야 한다.

현재 코드에는 명령줄 `-GMTITLE` 경로가 있지만 기본 비활성화되어 있다.

```lisp
(setq *swcad-title-allow-commandline-gmtitle* nil)
```

비활성화 이유:

```text
이전 CAD 이력에서 -GMTITLE 자동 선택이 DR_A*_Outline + DR_titlea_3rd 대신
일반 ISO/A-series 기본값으로 흐르거나 새 INSERT를 안정적으로 만들지 못했다.
```

따라서 현재 안정 흐름은:

```text
SWTITLESTATUS가 다음 후보를 찾음
SWTITLECONVERT가 한 장의 GMTITLE 창을 열도록 안내
사용자가 DR_A*_Outline / DR_titlea_3rd / Frame positioning ON / Object move OFF를 눈으로 확인
LSP가 새 native 결과를 검사하고 속성값 복사, 정렬, 이전 복제 쌍 삭제
```

이 방식은 느리지만, 잘못된 도면틀을 대량으로 삽입하는 사고를 막는다.

## 현재 완료로 보지 않는 조건

아래 상태는 완료가 아니다.

```text
WARN_CLONED_GMTITLE_FRAME_NEEDS_NATIVE_UPGRADE
WARN_SHARED_NATIVE_GMTITLE_LINKS
WARN_A3_A4_TARGET_FRAME_NOT_NATIVE_LIKE
A3/A4 native 교체 후보 > 0
복제 쌍 > 0
shared-native-link-handle가 남음
SWTITLEVERIFY_FINAL_OK가 아님
```

`속성 블록 편집` 창이 열리는 것만으로도 완료가 아니다. 대표 제목블록 더블클릭 확인은 필요하지만, 최종 판단은 `SWTITLEVERIFY`가 아래 조건을 함께 만족해야 한다.

```text
남은 원본 SolidWorks 표제란 0
남은 원본 SolidWorks 도면틀 0
target A2/A3/A4 수량 일치
non-native-like target pair 0
도면틀 형상/선택 위험 0
겹친 target 쌍 0
```

## 자동화 후보

### 1. 명령줄 `-GMTITLE` 재검증

목표:

```text
GUI 선택 없이 DR_A3_Outline + DR_titlea_3rd를 정확히 생성할 수 있는지 검증한다.
```

필수 조건:

```text
일반 A3/A4 또는 ISO 제목블록으로 흐르지 않아야 함
새 INSERT가 정확히 2개 또는 기대 수량으로 생겨야 함
새 frame block이 요청한 DR_A*_Outline이어야 함
새 title block이 DR_titlea_3rd이어야 함
Frame positioning / Object move 상태가 도면 내용을 이동시키지 않아야 함
SCRIPT나 숨김 자동화에서 프롬프트가 남지 않아야 함
```

실패 시:

```text
새로 생긴 INSERT를 즉시 삭제
자동 선택 경로 유지 금지
대화식 GMTITLE 경로로 되돌림
```

현재 판단:

```text
이력상 기본값은 계속 OFF가 맞다.
다만 별도 work 복사본에서 read-only/rollback 전제의 실험으로 재검증할 수 있다.
```

로컬 설치 조사 결과:

```text
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Common\gcad.rx
  paperset.grx 로드 확인

C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Common\ImCuiTranslate.xml
  메뉴 항목 "도면 제목/경계..."는 command="GMTITLE"로 표시됨
  같은 항목의 원 command 문자열은 ^C^Cimtitle 계열

C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Common\ImLanguage.xml
  PAPERSET 모듈 존재
  "Select title block automatically", "Automatic placement", "Drawing Borders with Title Block" 등 문구 존재

C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\MCADSetting\PaperSet.dat
  A0/A1/A2/A3/A4 용지 치수 테이블 성격으로 보임
  DR_A*_Outline 또는 DR_titlea_3rd 선택값 문자열은 텍스트 검색에서 확인되지 않음

C:\Users\DR-DESIGN\AppData\Roaming\Gstarsoft\GstarMechStd\R24\ko-KR\Gcadm\MCADSetting
  사용자 설정 파일에는 현재 검색 기준에서 DR_A*_Outline / DR_titlea_3rd / GMTITLE 기본 선택값 흔적 없음
```

현재 해석:

```text
GMTITLE native 구조 생성은 LISP가 아니라 paperset.grx / PaperSet.grx 같은 컴파일된 Mechanical 모듈이 담당하는 것으로 보인다.
도면틀/표제란 파일은 DWG로 존재하지만, 그 파일을 INSERT하는 것만으로는 native GMTITLE 편집 동작이 증명되지 않는다.
사용자 설정 파일에서 DR 기본 선택값을 직접 고정하는 근거는 아직 찾지 못했다.
따라서 command-line 자동 선택은 여전히 실험 후보일 뿐 기본 경로로 승격하지 않는다.
```

### 2. GstarCAD Mechanical API 조사

목표:

```text
GMTITLE 대화상자를 거치지 않고 native GMTITLE 객체를 만드는 공식 API나 내부 함수를 찾는다.
```

확인 대상:

```text
paperset.grx / PaperSet.grx가 노출하는 명령 또는 함수
imtitle / GMTITLE / GMSBLOCKE의 명령줄 인자 가능성
GstarCAD Mechanical AutoLISP 함수
COM object method
Mechanical/Genius GEN* 내부 함수
문서화된 title/border 생성 API
템플릿/설정 파일에서 마지막 선택값을 제어하는 방법
```

성공 기준:

```text
DR_A*_Outline과 DR_titlea_3rd를 파라미터로 넘길 수 있음
결과가 SWTITLEVERIFY에서 native-like로 통과
더블클릭 시 GMTITLE 표 편집창이 열림
여러 장 반복 생성해도 shared-native-link-handle이 생기지 않음
```

### 3. native xdata/link 직접 생성

목표:

```text
복제 GMTITLE 쌍이 native-like로 인정되지 않는 내부 차이를 찾아 직접 보정 가능한지 확인한다.
```

비교 대상:

```text
정상 native A3 1장
복제 A3 1장
native 교체 성공 A3 1장
shared-native-link-handle A3 1장
```

비교 항목:

```text
entget 전체
xdata app 목록
GENIUS_GENOREF_13 값
GENIUS_GENOBJ-N-SDF_13 값
GENIUS_GENODEF_13 값
extension dictionary
persistent reactors
owner block/table 관계
attribute reference 상태
frame/title bbox와 삽입점
SWTITLE marker role
```

현재 판단:

```text
직접 생성은 가장 위험하다.
GstarCAD 내부 handle/link 의미를 완전히 파악하기 전에는 production 경로로 사용하지 않는다.
```

## 구현 방향

새 공개 명령을 늘리지 않는다. 자동화 실험도 기존 흐름 안에서 상태 기반으로 붙인다.

권장 구조:

```text
SWTITLESTATUS
  현재 자동화 가능 상태인지 진단
  어떤 후보가 왜 manual인지 출력
  자동화 실험이 안전한 조건인지 출력

SWTITLEPREPARE
  오염/중복/위험 정의만 정리
  native 구조 추정만으로 삭제하지 않음

SWTITLECONVERT
  안전한 자동 경로가 검증된 경우에만 사용
  실패하면 새 INSERT 삭제 후 대화식 경로로 전환
  A3/A4 native 교체는 한 번에 한 후보만 기본 처리

SWTITLEVERIFY
  clone/native-upgrade warning이 없어야 최종 OK
```

자동화 경로를 넣더라도 기본값은 보수적으로 둔다.

```text
기본값: 대화식 확인
실험값: 명령줄 자동 선택 허용
승격 조건: 실제 work 복사본에서 반복 성공 + final verify OK + 더블클릭 확인
```

## 목표모드 운영 원칙

이 목표는 "A3 한 장이 우연히 잘 됨"으로 끝내지 않는다.

매 턴마다 아래 순서로 판단한다.

```text
1. 현재 도면 상태를 증거로 확인한다.
2. 경고가 남아 있으면 경고 종류를 먼저 분류한다.
3. 수량 문제인지, native 구조 문제인지, 잔여물 삭제 문제인지 분리한다.
4. 한 번에 여러 문제를 고치지 않는다.
5. 수정 후에는 반드시 같은 기준으로 다시 검증한다.
```

판단에 사용할 권위 있는 증거:

```text
CAD 명령줄의 현재 결과
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_fast_status_last.txt
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_native_frame_check_last.txt
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_structure_diagnosis_last.txt
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_verify_summary_last.txt
실제 GstarCAD 화면에서 대표 제목블록 더블클릭 결과
현재 로컬 git diff
```

증거로 보지 않는 것:

```text
겉으로 도면틀과 표제란이 겹쳐 보이는 것
한 장의 제목블록만 GMTITLE 표 편집창으로 열리는 것
복제된 객체에 SWTITLE marker가 붙어 있는 것
이전 대화에서 성공했다고 기억하는 것
```

## 목표모드 체크포인트

목표모드에서는 "지금 좋아 보인다"가 아니라 "다음 증거가 쌓였는가"로만 진행 상태를 판단한다.

| 단계 | 통과 증거 | 실패 또는 보류 증거 | 다음 행동 |
| --- | --- | --- | --- |
| 로드 확인 | `SWTITLEVERSION`이 `260704-target-overlap-adopt-main63-guided-a3a4-batch` | 버전 다름, main63 문구 없음 | APPLOAD 다시 실행 |
| 상태 진단 | `SWTITLESTATUS`가 현재 work 복사본 DWG 경로를 표시 | Downloads/원본 DWG, 오래된 `*_last.txt` | work 복사본 열고 상태 재실행 |
| 구조 분류 | `native/복제 구조 비교 샘플:`과 `자동화 판단:` 출력 | 구조 비교 샘플 없음 | 현재 로그를 완료 증거로 쓰지 않음 |
| 변환 가능 | 다음 행동이 `SWTITLECONVERT`로 명확히 안내됨 | raw bbox 위험, 선택 위험, shared link 경고 | 변환 반복 금지, 원인 분류 |
| A3 검증 | 제목블록은 GMTITLE 표 편집창, 도면틀은 native-like 쌍으로 판정 | 도면틀+표제란이 하나의 정의처럼 들어옴 | A3 frame definition/xdata 비교 |
| A4 검증 | frame-only는 제목블록 없이 DR_A4_Outline만 남음 | 새 제목블록 생성, 용지 밖 객체 동반 | A4 frame-only 경로 중단 후 정의 확인 |
| 최종 검증 | `SWTITLEVERIFY_FINAL_OK`와 대표 더블클릭 통과 | 원본 잔여물, clone/shared/native warning | 완료 금지, 해당 경고부터 해결 |

각 턴에서 코드나 문서를 수정했다면 다음 순서로 마무리한다.

```text
git diff --check
필요 시 LSP 괄호/문자열 균형 확인
변경 이유와 남은 CAD 검증을 문서 또는 최종 답변에 기록
```

## 상태별 다음 행동

`SWTITLESTATUS` 또는 `SWTITLEVERIFY` 결과에 따라 다음처럼 움직인다.

```text
SWTITLEVERIFY_FINAL_OK
  -> 대표 A2/A3 제목블록을 더블클릭한다.
  -> A4 frame-only는 불필요한 표제란이 생기지 않았는지 화면으로 확인한다.
  -> 모두 맞으면 목표 완료 후보로 본다.

WARN_CLONED_GMTITLE_FRAME_NEEDS_NATIVE_UPGRADE
  -> 복제 쌍이 남아 있다는 뜻이다.
  -> SWTITLECONVERT로 다음 native 교체 후보 1장만 처리한다.
  -> 처리 후 SWTITLESTATUS를 다시 실행한다.

WARN_SHARED_NATIVE_GMTITLE_LINKS
  -> 여러 제목블록이 같은 내부 native handle을 공유할 가능성이 있다.
  -> 빠른 복제 방식만으로는 완료로 보지 않는다.
  -> native/복제 구조 비교 샘플의 GENIUS_GENOREF_13 값을 확인한다.

WARN_A3_A4_TARGET_FRAME_NOT_NATIVE_LIKE
  -> 제목블록은 편집될 수 있어도 도면틀 쌍이 native-like 기준을 통과하지 못했다.
  -> 도면틀 role, xdata app, native 대상 종류, bbox 겹침 여부를 확인한다.
  -> 원인이 clone/shared/geometry 중 무엇인지 분류한 뒤 다음 SWTITLECONVERT 후보를 정한다.

WARN_TARGET_FRAME_SELECTION_RISK
  -> 도면틀 bbox가 겹치거나 oversized라 더블클릭/선택이 엉뚱한 객체로 갈 수 있다.
  -> 먼저 SWTITLEPREPARE 또는 도면틀 정의 정규화 가능 여부를 확인한다.
  -> 이 상태에서는 더블클릭 결과만으로 성공/실패를 판단하지 않는다.

WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS
  -> 해당 크기의 실제 native 기준 객체가 아직 없다.
  -> A2/A3 표제란 시트는 SWTITLECONVERT로 한 장 생성/마무리한다.
  -> A4 frame-only는 같은 SWTITLECONVERT 흐름에서 frame-only 후보로 처리하되, 새 A4에 불필요한 제목블록이 붙는지 반드시 검증한다.

ABORT_NOT_WORK_COPY
  -> 원본 또는 Downloads 도면에서 변경을 막은 것이다.
  -> work 폴더 복사본을 열고 다시 실행한다.

ABORT_FRAME_DEFINITION_RAW_BBOX_RISK
  -> DR_A*_Outline 정의 안에 실제 용지 밖 형상이 섞여 있을 수 있다.
  -> 기존 A4/도면틀을 삭제하지 말고 정의 구조부터 확인한다.
```

## 크기별 검증 포인트

A2:

```text
현재 가장 안정적인 기준 크기다.
첫 native GMTITLE 기준 객체로 자주 사용된다.
다만 A2가 성공해도 A3/A4 자동화 성공으로 일반화하지 않는다.
```

A3:

```text
제목블록은 GMTITLE 표 편집창으로 열려도 도면틀이 native-like가 아닐 수 있다.
DR_A3_Outline 자체에 표제란이 포함된 형태로 들어오는지 확인해야 한다.
도면틀+표제란이 하나의 블록처럼 잡히면, 형상은 맞아도 목표 구조와 다를 수 있다.
```

A4:

```text
원본에는 표제란 없는 frame-only 시트가 있을 수 있다.
변환 후 제목블록이 생기면 "성공"이 아니라 "불필요한 표제란 추가"일 수 있다.
DR_A4_Outline 삽입 시 용지 밖 객체가 딸려오는지 bbox와 화면을 같이 확인한다.
```

## 자동화 승격 게이트

자동화 후보는 아래 게이트를 순서대로 통과해야 한다.

```text
Gate 1: work 복사본에서만 실행된다.
Gate 2: 새로 생긴 INSERT 수와 block name이 예상과 일치한다.
Gate 3: 실패 시 새 INSERT를 되돌릴 수 있다.
Gate 4: SWTITLESTATUS에서 clone/shared/native warning이 줄어든다.
Gate 5: SWTITLEVERIFY_FINAL_OK까지 간다.
Gate 6: 대표 제목블록 더블클릭이 GMTITLE 표 편집창으로 열린다.
Gate 7: 같은 과정을 A2/A3/A4에 반복해도 결과가 흔들리지 않는다.
```

한 게이트라도 실패하면:

```text
기본값으로 승격하지 않는다.
실패 로그를 남긴다.
대화식 SWTITLECONVERT 흐름을 유지한다.
```

## 단계별 실행 계획

### 1단계: 현재 상태 고정

할 일:

```text
git status --short --branch
SWTITLEVERSION
SWTITLESTATUS
SWTITLEVERIFY
```

저장할 증거:

```text
현재 열린 DWG 경로
현재 LSP 버전
A3/A4 native 교체 후보 수
복제 쌍 수
shared-native-link-handle 수
A4 frame-only 남은 수
최종 verify 결과
```

완료 기준:

```text
현재 CAD 상태가 "변환 전", "복제 후 native 교체 중", "최종 OK" 중 어디인지 분명히 구분됨
```

### 2단계: native/clone 차이 비교

할 일:

```text
대표 native A3와 복제 A3의 상세 정보를 같은 포맷으로 출력
필요하면 기존 detail 로그를 보강
```

확인할 질문:

```text
복제 쌍은 어떤 xdata app을 공유하는가?
shared handle은 어느 객체를 가리키는가?
native-like 통과 쌍은 shared handle이 없는가?
frame에도 native 의미가 있는 xdata가 있는가?
extension dictionary/reactor 차이가 있는가?
```

완료 기준:

```text
native-like 탈락 이유가 clone / shared-native-link / missing internal link / marker role / geometry 중 무엇인지 후보별로 설명됨
```

### 3단계: 자동 `-GMTITLE` 실험 설계

전제:

```text
절대 원본 DWG에서 하지 않음
work 복사본에서만 함
실패 시 새 INSERT 삭제 가능해야 함
```

실험:

```text
A2 1회
A3 1회
A4 frame-only 1회
반복 A3 3회
```

각 회차에서 확인:

```text
새 INSERT 수
선택된 frame block
선택된 title block
native link handle 종류
shared handle 여부
bbox 정상 여부
Object move로 도면 내용 이동 여부
SWTITLEVERIFY 경고 변화
```

승격 기준:

```text
모든 회차에서 요청한 DR 도면틀/제목블록이 정확히 들어감
실패 시 rollback이 정상
manual 경로보다 위험이 낮음
```

### 4단계: API/설정 파일 조사

할 일:

```text
GstarCAD 설치 폴더의 GMTITLE 관련 LSP/DCL/DLL/설정 파일 이름 조사
DR_A*_Outline, DR_titlea_3rd 목록이 어디서 로드되는지 확인
마지막 선택값 또는 기본 선택값을 설정 파일로 고정할 수 있는지 확인
```

주의:

```text
설치 폴더는 읽기 전용으로만 확인
설치 원본 DWG는 수정하지 않음
```

완료 기준:

```text
문서화된 API가 있으면 그 경로를 우선 검토
없으면 설정 파일 기반 자동 선택 가능성만 별도 후보로 남김
```

### 5단계: 코드 반영 후보

가능한 반영:

```text
SWTITLESTATUS에 "manual이 필요한 이유"를 더 명확히 출력
SWTITLEVERIFY에 native-like 탈락 이유 요약을 크기별로 출력
SWTITLECONVERT에 command-line 실험 경로를 별도 opt-in으로 제한
native/clone 비교 detail 로그를 한 파일로 고정
```

당장 하지 않을 것:

```text
기본값으로 -GMTITLE 자동 선택 켜기
화면 좌표 클릭 자동화
A3/A4 전용 공개 명령 추가
clone을 native로 간주하기
xdata를 추측으로 조작하기
```

## 완료 기준

이 목표는 아래 중 하나가 증명될 때 완료로 볼 수 있다.

### A안: 자동화 성공

```text
SWTITLECONVERT가 A3/A4 반복 선택을 자동화
SWTITLEVERIFY_FINAL_OK
WARN_CLONED_GMTITLE_FRAME_NEEDS_NATIVE_UPGRADE 없음
WARN_SHARED_NATIVE_GMTITLE_LINKS 없음
A3/A4 native 교체 후보 0
대표 A2/A3 제목블록 더블클릭 표 편집창 확인
A4 frame-only 2장 형상 검증 통과
```

### B안: 자동화 불가 근거 확정

```text
명령줄 -GMTITLE / API / xdata 직접 생성 경로가 왜 불안정하거나 위험한지 증거 확보
현재 반자동 4명령 흐름이 최선이라는 근거 문서화
사용자가 반복 작업을 할 때 실수하지 않도록 로그/안내가 충분히 개선됨
```

## 다음 실제 작업

현재 목표의 다음 작업은 코드 수정이 아니라 구조 증거를 더 모으는 것이다.

현재 `work` 폴더에 남아 있는 최신 로그는 참고용이다. 아래처럼 `main58-a4outline` 버전으로 찍힌 로그는 현재 `main62-korean-guidance`에서 추가/정리한 구조 비교 샘플, 자동화 정책 요약, 권장 다음 명령 우선순위, 한국어 핵심 안내를 포함하지 않으므로 목표 완료 증거로 사용하지 않는다.

```text
work\swcad_title_native_frame_check_last.txt
SWTITLE LSP 버전: 260704-target-overlap-adopt-main58-a4outline
결과: WARN_CLONED_GMTITLE_FRAME_NEEDS_NATIVE_UPGRADE
A3 복제 쌍: 10
native-link 공유 쌍: 1
A4 누락
```

따라서 다음 검증은 반드시 CAD에서 최신 LSP를 다시 로드한 뒤 실행한다.

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
SWTITLEVERSION
SWTITLESTATUS
```

`SWTITLEVERSION`이 아래와 다르면 그 세션의 결과는 사용하지 않는다.

```text
260704-target-overlap-adopt-main63-guided-a3a4-batch
```

우선순위:

```text
1. 현재 열린 CAD에서 SWTITLESTATUS/SWTITLEVERIFY 최신 로그 확보
2. native-like 통과 A3와 복제 A3의 detail 비교
3. shared-native-link-handle가 어떤 GENIUS_GENOREF_13 값을 공유하는지 확인
4. 명령줄 -GMTITLE 자동 선택을 work 복사본에서 opt-in 실험할 수 있는지 검토
5. 실험 결과가 좋을 때만 기본 흐름에 반영
```

이 계획은 `SWTITLECONVERT` 반복을 줄이기 위한 목표 계획이며, 현재 production 기본값을 즉시 바꾸라는 뜻은 아니다.

## 목표모드 운영 계획 main63 이후

이 절은 목표모드에서 같은 실수를 반복하지 않기 위한 실제 운영 기준이다.

핵심 원칙:

```text
1. CAD에 로드된 LSP 버전이 증거의 출발점이다.
2. 낡은 main58/main56/main62 이전 로그는 참고 기록일 뿐 main63 판단 증거가 아니다.
3. 화면 모양보다 SWTITLESTATUS/SWTITLEVERIFY 로그를 우선한다.
4. 새 공개 명령을 늘리지 않는다.
5. 원본 DWG는 건드리지 않고 work 복사본만 변환한다.
6. 복제 GMTITLE은 native GMTITLE로 간주하지 않는다.
7. 완료는 SWTITLEVERIFY_FINAL_OK와 대표 더블클릭 확인 전까지 선언하지 않는다.
```

### Phase 0. 버전과 도면 상태 잠금

목적:

```text
현재 열린 CAD 세션이 정말 최신 로직으로 판단하고 있는지 확인한다.
```

실행:

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
SWTITLEVERSION
SWTITLESTATUS
```

통과 기준:

```text
SWTITLEVERSION:
260704-target-overlap-adopt-main63-guided-a3a4-batch

DWG 파일:
C:\Users\DR-DESIGN\Documents\CAD tool\work\...

작업 폴더 복사본:
예
```

실패 시:

```text
SWTITLECONVERT 금지
SWTITLEPREPARE 금지
먼저 APPLOAD로 최신 swcad_load.lsp를 다시 로드
그 다음 SWTITLEVERSION 재확인
```

현재 알려진 실패 예:

```text
SWTITLE LSP 버전: 260704-target-overlap-adopt-main58-a4outline
```

이 버전으로 생성된 로그는 `main63`의 한국어 안내, 구조 비교 샘플, 자동화 정책 판단, A3/A4 OPEN/BATCH 선택지가 빠져 있으므로 최종 판단에 쓰지 않는다.

### Phase 1. 상태를 세 가지로 분류

`SWTITLESTATUS` 결과는 먼저 아래 세 상태 중 하나로 분류한다.

#### 상태 A. 첫 native GMTITLE 기준 객체가 없음

대표 문구:

```text
NEXT_CREATE_FIRST_NATIVE_GMTITLE
```

의미:

```text
아직 이 도면에는 믿을 수 있는 GMTITLE 기준 객체가 없다.
```

다음:

```text
SWTITLECONVERT
```

GMTITLE 창에서 확인:

```text
로그가 요구한 DR_A*_Outline
DR_titlea_3rd
Frame positioning ON
Object move OFF
```

#### 상태 B. 복제 A3/A4를 fresh native로 교체해야 함

대표 문구:

```text
NEXT_UPGRADE_A3_A4_NATIVE
WARN_CLONED_GMTITLE_FRAME_NEEDS_NATIVE_UPGRADE
WARN_SHARED_NATIVE_GMTITLE_LINKS
```

의미:

```text
겉모양은 맞지만, 일부 A3/A4가 복제 구조이거나 native handle을 공유한다.
GstarCAD가 더블클릭 시 항상 GMTITLE 표 편집창으로 볼 것이라는 증거가 부족하다.
```

다음:

```text
SWTITLECONVERT
SWTITLESTATUS
```

반복 규칙:

```text
한 번에 후보 1장만 fresh native GMTITLE로 교체한다.
각 회차 뒤 SWTITLESTATUS로 후보 수가 줄었는지 확인한다.
후보 수가 줄지 않으면 반복하지 않고 원인 로그를 본다.
```

통과 기준:

```text
A3/A4 native 교체 후보: 0
복제 쌍: 0
native-link 공유 쌍: 0
```

#### 상태 C. A4 frame-only가 남음

대표 문구:

```text
READY_FOR_A4_FRAME_ONLY_OUTLINE
표제란 없는 A4 시트
```

의미:

```text
원본 A4에는 제목블록이 없고 도면틀만 있다.
따라서 새 제목블록을 만들면 원본 구조와 달라진다.
```

다음:

```text
SWTITLECONVERT
SWTITLESTATUS
```

통과 기준:

```text
A4 DR_A4_Outline 대상 도면틀 수량이 원본 기준 수량과 일치
원본에 없던 DR_titlea_3rd 제목블록이 A4에 생기지 않음
도면 내용이 이동하거나 삭제되지 않음
```

실패 예:

```text
DR_A4_Outline raw bbox 위험
A4에 불필요한 제목블록 생성
A4 원본 도면틀 삭제 후 새 도면틀 불일치
```

이 경우:

```text
변환 반복 금지
SWTITLEVERIFY/SWTITLESTATUS 로그에서 A4 frame-only 진단 확인
필요하면 작업복사본을 새로 만들어 다시 시작
```

### Phase 2. A3 중복 표제란 문제의 판단 순서

A3는 단순히 "도면틀 안에 제목블록 모양이 보인다"는 이유로 삭제하면 안 된다.

판단 순서:

```text
1. DR_A3_Outline 정의가 설치 원본 native-format 구조인지 확인
2. 별도 DR_titlea_3rd insert가 같은 위치에 추가되어 실제 중복을 만드는지 확인
3. SolidWorks 원본 또는 이전 변환 잔여물이 도면틀 정의 안으로 섞였는지 확인
4. source-contaminated와 native-format-with-title-geometry를 구분
5. 겹침이나 shared-native-link가 있으면 SWTITLECONVERT로 fresh native 교체
```

삭제 가능한 대상:

```text
SolidWorks 원본 도면틀
SolidWorks 원본 표제란
명령어 실수로 입력된 텍스트
이미 교체된 non-native/clone target 쌍
source-contaminated로 판정된 도면틀 정의 내부 잔여물
```

삭제 금지 대상:

```text
DR_A3_Outline 설치 원본 native-format 형상 자체
도면 내부 번호
주석
BOM
치수
모델 형상
좌표/눈금/외곽선
```

### Phase 3. 사람이 필요한 이유와 줄이는 방향

현재 사람이 필요한 이유:

```text
GstarCAD native GMTITLE 생성은 LISP 복사만으로 완전히 재현되지 않는다.
복제한 title/frame은 겉모양, 속성, 일부 xdata가 맞아도 shared-native-link-handle 문제가 생길 수 있다.
명령줄 -GMTITLE 자동 선택은 과거에 일반 A3/A4 또는 ISO 흐름으로 잘못 간 이력이 있다.
```

따라서 현재 안정 기본값:

```text
사용자는 GMTITLE 창에서 용지/제목블록/옵션만 눈으로 확인한다.
좌표 계산, 기존 값 복사, 이전 쌍 삭제, 후보 선정은 LSP가 한다.
```

줄일 수 있는 부분:

```text
소수점 좌표 직접 입력 제거
스크린샷 좌표 클릭 제거
다음 후보 선택 자동화
잘못된 반복 명령 방지
상태별 다음 명령 한국어 안내
```

main63에서 실제로 줄인 부분:

```text
SWTITLECONVERT를 여러 번 다시 입력하는 반복을 줄이기 위해 A3/A4 native 교체 상태에서 OPEN/BATCH 선택지를 제공한다.
OPEN은 기존처럼 다음 후보 1장만 처리한다.
BATCH는 처리 수량을 입력받아 여러 후보를 이어서 처리한다.
단, 각 GMTITLE 창의 DR_A*_Outline / DR_titlea_3rd / Frame positioning ON / Object move OFF 확인은 여전히 사람이 한다.
선택값이 틀리거나 실패하면 새 INSERT를 제거하고 기존 쌍을 보존한 뒤 중단한다.
```

아직 자동화하지 않는 부분:

```text
GMTITLE 창에서 DR_A*_Outline / DR_titlea_3rd 선택을 무조건 자동화
GstarCAD native xdata를 추측으로 직접 작성
복제 GMTITLE을 native로 간주
```

### Phase 4. 자동화 실험을 시작할 조건

자동 `-GMTITLE` 또는 API 실험은 아래 조건이 충족될 때만 시작한다.

```text
main63 이상이 CAD에 로드됨
work 복사본에서 실행 중
현재 SWTITLESTATUS/SWTITLEVERIFY 로그가 최신임
실패 시 새 INSERT를 되돌릴 수 있음
A2/A3/A4 각각 대표 실패/성공 기준이 정해짐
```

실험 기록 항목:

```text
요청한 paper/frame
실제 생성된 frame block
실제 생성된 title block
새 INSERT 개수
native-like 여부
shared-native-link 여부
bbox 크기
도면 내용 이동 여부
SWTITLEVERIFY 결과 변화
```

기본 흐름 승격 조건:

```text
A2/A3/A4 모두 요청한 DR_A*_Outline과 DR_titlea_3rd를 안정 생성
Object move 없이 도면 내용 유지
실패 시 rollback 성공
반복 3회 이상 결과 동일
SWTITLEVERIFY_FINAL_OK로 이어짐
```

하나라도 실패하면:

```text
자동 선택은 opt-in 실험으로만 유지
기본 흐름은 대화식 SWTITLECONVERT 유지
```

### Phase 5. 최종 완료 감사

완료 선언 전 반드시 아래 항목을 현재 CAD 세션 기준으로 확인한다.

```text
SWTITLEVERSION = 260704-target-overlap-adopt-main63-guided-a3a4-batch 이상
DWG 경로 = work 폴더 작업복사본
SWTITLEVERIFY_FINAL_OK
남은 원본 표제란 = 0
남은 원본 도면틀 = 0
frame-only 남은 수 = 0
target A2 = 1
target A3 = 12
target A4 = 2
복제 쌍 = 0
shared-native-link 쌍 = 0
겹친 target 쌍 = 0
도면틀 raw bbox 위험 = 0
대표 A2/A3 제목블록 더블클릭 = GMTITLE 표 편집창
A4 frame-only = 제목블록 없이 도면틀만 정상
빨간 네모로 표시했던 번호/주석/도면 내부 객체 유지
```

이 중 하나라도 증거가 없으면 목표 완료가 아니다.
