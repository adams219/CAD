# GMTITLE native 도면틀과 source 오염 구분 계획 - 2026-07-04

## 목적

SolidWorks DWG를 GstarCAD Mechanical GMTITLE 구조로 바꾸는 과정에서 같은 실수를 반복하지 않기 위한 기준 문서다.

이번 핵심 문제는 A3 한 장의 문제가 아니라, `DR_A*_Outline` 도면틀 정의 안에 보이는 형상이 다음 둘 중 어느 쪽인지 구분하지 못한 데 있다.

```text
1. GstarCAD 설치 원본/native 도면틀이 원래 가지고 있는 형상
2. SolidWorks 원본 또는 이전 변환 과정에서 도면틀 정의 안으로 섞여 들어간 오염 형상
```

둘을 구분하지 않고 `표제란처럼 보인다`는 이유만으로 삭제하면, 원래 있어야 할 도면 번호, 주석, 상단 revision 영역, A3 native 형상까지 지워질 수 있다.

## 이력에서 확인한 반복 실수

다음 방식은 다시 기본 해결책으로 사용하지 않는다.

```text
- 화면 좌표나 스크린샷 기준으로 GMTITLE 창을 클릭하기
- `-GMTITLE` 명령줄 자동 선택에 의존하기
- A2/A3/A4별 임시 공개 명령을 계속 늘리기
- `DR_A*_Outline` 정의 안의 형상을 무조건 삭제하기
- native-links=1만 보고 GMTITLE 편집 동작 완료로 판단하기
- 모양만 보고 `SWTITLEVERIFY` 없이 완료로 판단하기
```

근거:

```text
- `-GMTITLE` 자동 선택은 이전 이력에서 ISO/A 기본값으로 흐르거나 선택이 어긋난 적이 있다.
- 화면 좌표 방식은 듀얼 모니터, 전체화면 CAD, 리본/명령창 상태에 따라 반복 재현성이 낮았다.
- A3는 설치 원본 `DR_A3_Outline.dwg` 자체에 lower-right title-like 형상이 들어 있다.
- 따라서 A3 내부 형상은 무조건 오염이 아니라 native-format일 수 있다.
```

## 현재 main-45 결론

현재 기준 LSP 버전:

```text
260704-frame-definition-classification-main-45
```

도면틀 정의는 다음 네 가지로 나눈다.

```text
unknown
outline-only
native-format-with-title-geometry
source-contaminated
```

의미:

```text
unknown:
  아직 현재 도면에서 해당 DR 도면틀 정의를 충분히 판단할 수 없음.

outline-only:
  도면틀 정의 안에 제목블록처럼 보이는 내부 형상이 없음.

native-format-with-title-geometry:
  도면틀 정의 안에 제목블록처럼 보이는 형상은 있으나 source-like child block이 없음.
  설치 원본/native 구조일 수 있으므로 자동 삭제하지 않음.

source-contaminated:
  SolidWorks source block 또는 이전 변환 결과로 보이는 source-like child block이 정의 안에 섞여 있음.
  이 경우에만 변환 전 차단/정리 대상으로 본다.
```

## 이미 검증한 내용

### 1. LSP 로드와 공개 명령 확인

로그:

```text
work/swtitle_version_probe_main45_260704.txt
```

결과:

```text
Load result: OK
Loaded version: 260704-frame-definition-classification-main-45
Expected version: 260704-frame-definition-classification-main-45
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Command-line GMTITLE enabled: no
Probe completed: yes
```

### 2. 설치 원본 DR 도면틀 스캔

로그:

```text
work/swtitle_install_frame_scan_main45_260704.txt
```

결과:

```text
DR_A2_Outline: class=outline-only, embedded=0, source-like-children=<none>
DR_A3_Outline: class=native-format-with-title-geometry, embedded=10, source-like-children=<none>
DR_A4_Outline: class=outline-only, embedded=0, source-like-children=<none>

Blocking records: 0
Cleanup records: 0
All embedded records: 10
Install frame scan passed: yes
```

판단:

```text
설치 원본 DR_A3_Outline은 title-like 형상 10개를 원래 포함한다.
source-like child block은 없으므로 source-contaminated로 보지 않는다.
따라서 이 형상은 `SWTITLEPREPARE`나 `SWTITLECONVERT`가 자동 삭제하면 안 된다.
```

### 3. SWTITLEVERIFY 중 오분류 방지 확인

로그:

```text
work/swtitle_verify_nativeformat_fixture_main45_260704.txt
```

결과:

```text
Run SWTITLEVERIFY: ok
Final status: SWTITLEVERIFY_FINAL_FAIL
DR_A3_Outline class after verify: native-format-with-title-geometry
Blocking records after verify: 0
Cleanup records after verify: 0
All embedded records after verify: 10
Native-format verify passed: yes
Runtime check completed: yes
```

`SWTITLEVERIFY_FINAL_FAIL`은 이 fixture가 변환 완료 DWG가 아니라 target GMTITLE frame/title 삽입이 없는 진단용 도면이기 때문에 정상이다.

중요한 검증 포인트는 `DR_A3_Outline` 내부 title-like 형상 10개가 있어도 blocking/cleanup 대상이 0으로 유지됐다는 점이다.

### 4. SWTITLESTATUS 다음 단계 오안내 방지 확인

로그:

```text
work/swtitle_status_nativeformat_fixture_main45_260704.txt
```

결과:

```text
Run SWTITLESTATUS: ok
Structure next action: SWTITLECONVERT - 남은 원본 SolidWorks 시트 변환
DR_A3_Outline class after status: native-format-with-title-geometry
Blocking records after status: 0
Cleanup records after status: 0
All embedded records after status: 10
Native-format status passed: yes
```

중요한 검증 포인트는 `SWTITLESTATUS`가 설치 원본 A3 내부 형상만 보고 `SWTITLEPREPARE`를 잘못 안내하지 않았다는 점이다.

### 5. SWTITLEPREPARE 자동 실행 안전장치 확인

로그:

```text
work/swtitle_prepare_guard_main45_260704.txt
```

결과:

```text
Run SWTITLEPREPARE: ok
Prepare status: ABORT_PREPARE_SCRIPT_ACTIVE
Prepare guard passed: yes
```

중요한 검증 포인트는 `SCRIPT`/`/b` 자동 실행 중 `SWTITLEPREPARE`가 YES 확인이 필요한 실제 정리 단계로 들어가지 않고 중단됐다는 점이다.

### 6. SWTITLECONVERT 자동 실행 안전장치 확인

로그:

```text
work/swtitle_convert_guard_main45_260704.txt
```

결과:

```text
Run SWTITLECONVERT: ok
Convert status: ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE
Convert guard passed: yes
```

중요한 검증 포인트는 `SCRIPT`/`/b` 자동 실행 중 `SWTITLECONVERT`가 native GMTITLE 대화식 선택 단계로 들어가지 않고 중단됐다는 점이다.

### 7. 정상 DR_titlea_3rd 보호 확인

로그:

```text
work/swtitle_title_protection_fixture_main45_260704.txt
```

결과:

```text
Normal DR_titlea_3rd insert count: 1
Frame-definition child-title cleanup candidates: 0
Frame embedded-title cleanup candidates: 0
Frame-definition blockers: 0
Normal title protection passed: yes
```

중요한 검증 포인트는 정상적으로 별도 삽입된 `DR_titlea_3rd` 제목블록이 `SWTITLEPREPARE`의 도면틀 정의 내부 정리 후보로 잡히지 않았다는 점이다.

## 앞으로 분석 순서

### 1. 먼저 원본과 설치 native를 분리해 본다

실제 변환 전에 아래 세 가지를 분리해서 판단한다.

```text
1. SolidWorks 원본 work copy
2. GstarCAD 설치 원본 DR_A2/A3/A4_Outline
3. 현재 SWTITLE 변환 결과
```

비교 항목:

```text
- 도면틀 수량
- 제목블록 수량
- 도면틀 정의 class
- source-like child block 존재 여부
- 남은 원본 표제란/도면틀 후보 수
- A2/A3/A4별 target frame 수량
- `DR_titlea_3rd` 더블클릭 시 GMTITLE 표 편집창 여부
```

### 2. 사용자가 쓰는 명령은 4개로 유지한다

공개 흐름은 계속 아래 네 개만 사용한다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

내부 구현은 바뀔 수 있지만, A3 전용/A4 전용/복구 전용 공개 명령을 계속 늘리지 않는다.

### 3. `SWTITLESTATUS`가 다음 행동을 결정하게 한다

사용자는 `SWTITLECONVERT`를 연속으로 누르지 않는다.

기본 반복:

```text
SWTITLESTATUS
SWTITLEPREPARE   필요하다고 안내될 때만
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT   아직 다음 변환이 남았다고 안내될 때만
SWTITLEVERIFY
```

### 4. A3 내부 형상은 삭제보다 분류가 먼저다

A3에서 도면틀과 제목블록이 하나로 합쳐져 보이면 바로 삭제 로직을 추가하지 않는다.

먼저 아래를 확인한다.

```text
- 이것이 설치 원본 DR_A3_Outline의 native-format 형상인지
- 별도 `DR_titlea_3rd` 제목블록이 중복 삽입된 것인지
- source-like child block이 도면틀 정의 안에 섞인 것인지
- 더블클릭 대상이 도면틀 frame인지 제목블록 title인지
```

## 완료 기준

다음 조건을 모두 만족해야 완료로 본다.

```text
SWTITLEVERIFY_FINAL_OK
원본 기준 A2/A3/A4 수량과 target GMTITLE 수량 일치
남은 SolidWorks 원본 표제란 후보 0
남은 SolidWorks 원본 도면틀 후보 0
A3 제목블록 중복 없음
A4 frame-only 시트 누락 없음
도면 안의 번호/주석/BOM/텍스트 삭제 없음
대표 A2/A3/A4 `DR_titlea_3rd` 더블클릭 시 GMTITLE 표 편집창 열림
```

## 다음 구현 판단

현재 main-45는 main-44보다 낫다.

이유:

```text
main-44:
  A3 내부 title-like 형상을 오염 후보로 볼 위험이 있었다.

main-45:
  설치 원본 DR_A3_Outline의 native-format title-like 형상을 source-contaminated와 분리한다.
  source-contaminated만 정리 차단 대상으로 본다.
```

따라서 다음 실제 CAD 검증은 main-45 기준으로 진행한다.

다만 아직 전체 변환 완료 증거는 아니다. 실제 work copy에서 `SWTITLECONVERT`를 진행한 뒤 `SWTITLEVERIFY_FINAL_OK`와 더블클릭 편집창 확인까지 끝나야 완료다.
