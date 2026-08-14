# GMTITLE main45 도면틀 정의 분류 기준 - 2026-07-04

## 결론

현재 기준 LSP는 `260704-frame-definition-classification-main-45`이다.

`main45`는 전체 변환 완료 버전이 아니라, A3 도면틀 정의 안의 표제란형 형상을 무조건 삭제 대상으로 보던 방향을 고친 안정화 버전이다.

## 왜 바꿨나

로컬/GitHub 이력상 같은 실수가 반복됐다.

```text
DR_A3_Outline 내부에 표제란처럼 보이는 형상 발견
-> embedded-title로 분류
-> SWTITLEPREPARE에서 삭제하려고 함
-> 실제 블록 정의 내부 객체는 entdel/vla-Delete로 삭제되지 않음
-> 더 중요한 문제: 설치 원본/native 구조일 수도 있는 형상을 오염으로 오판할 위험
```

따라서 `A3 내부 형상 = 삭제 대상`이라는 단순 판단을 버렸다.

## 새 분류

`SWTITLESTATUS`와 내부 진단은 `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline`을 아래처럼 나눈다.

```text
unknown
outline-only
native-format-with-title-geometry
source-contaminated
```

의미:

- `unknown`: 현재 도면에 해당 DR 도면틀 정의가 아직 없음. 첫 native GMTITLE 전이면 정상일 수 있음.
- `outline-only`: 현재 필터 기준으로 도면틀 정의 안에 정리할 title-like 형상이 없음.
- `native-format-with-title-geometry`: 도면틀 정의 안에 표제란처럼 보이는 형상이 있지만 source-like child block은 없음. 설치 원본/native 구조일 수 있으므로 자동 삭제하지 않음.
- `source-contaminated`: SolidWorks/이전 변환 source-like child block이 섞임. 변환 전 정규화 차단 대상.

## 검증 결과

원본 LSP와 테스트 복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_current_main45_frameclass_compare_copy.lsp
```

SHA256:

```text
FD41E114DF5E1F598E3FFB691C3E0ABD42E80B49AFA9A03635A1664095581E1F
```

두 파일은 같은 내용이다. 이후 구버전 `embedded-title/contaminated` 분류 함수는 `legacy-main43-unused` 이름으로 밀어 실제 호출 대상에서 제외했고, 원본과 복사본 SHA256을 다시 맞췄다.

### 로드/명령 등록 확인

로그:

```text
work\swtitle_version_probe_main45_260704.txt
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

### 읽기 전용 런타임 확인

로그:

```text
work\swtitle_lsp_compare_main45_260704.txt
```

결과:

```text
Run: SWTITLEVERSION
Result: OK SWTITLEVERSION status=<status variable missing>
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

`SWTITLEVERIFY_FINAL_FAIL`은 테스트 DWG가 변환 전 상태라 target GMTITLE 객체가 없는 정상 진단이다. LSP 로드 실패가 아니다.

### 분류 fixture 확인

로그:

```text
work\swtitle_frameclass_fixture_main45_260704.txt
```

합성 조건:

- A2: 도면틀만 있는 `outline-only`
- A3: source-like child 없이 lower-right title-like 형상만 있는 `native-format-with-title-geometry`
- A4: `0_DR-A4 FROM_HYUN` source-like child가 들어간 `source-contaminated`

결과:

```text
DR_A2_Outline class: outline-only
DR_A3_Outline class: native-format-with-title-geometry
DR_A4_Outline class: source-contaminated
Blocking records: 1
Cleanup records: 3
Classification passed: yes
```

즉 A3 native-like 형상은 자동 삭제 후보가 아니고, source-like child가 있는 A4만 차단/정리 후보로 분리된다.

### 설치 원본 DR 도면틀 복사본 스캔

설치 폴더 원본은 직접 수정하지 않고 아래 폴더에 복사해서 스캔했다.

```text
work\install_scan\DR_A2_Outline.dwg
work\install_scan\DR_A3_Outline.dwg
work\install_scan\DR_A4_Outline.dwg
work\install_scan\DR_titlea_3rd.dwg
```

로그:

```text
work\swtitle_install_frame_scan_main45_260704.txt
```

결과:

```text
DR_A2_Outline: class=outline-only, embedded=0, source-like-children=<none>
DR_A3_Outline: class=native-format-with-title-geometry, embedded=10, source-like-children=<none>
DR_A4_Outline: class=outline-only, embedded=0, source-like-children=<none>

DR_A2_Outline children=DR-A2 From_HYUN, source-like=<none>
DR_A3_Outline children=DR-A3 From_HYUN, source-like=<none>
DR_A4_Outline children=도면 세로 A4 From_HYUN, source-like=<none>

Blocking records: 0
Cleanup records: 0
All embedded records: 10
Install frame scan passed: yes
```

중요한 결론:

```text
설치 원본 DR_A3_Outline 자체가 lower-right title-like 형상 10개를 포함한다.
하지만 source-like child block은 아니므로 오염으로 보지 않는다.
따라서 A3 도면틀 안의 이 형상은 SWTITLEPREPARE에서 자동 삭제하면 안 된다.
```

### SWTITLESTATUS next-action 확인

로그:

```text
work\swtitle_status_nativeformat_fixture_main45_260704.txt
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

즉 `SWTITLESTATUS`가 설치 원본 A3 내부 형상만 보고 `SWTITLEPREPARE`를 잘못 안내하지 않는다.

## 아직 완료가 아닌 것

이 검증은 도면틀 정의 분류 로직의 검증이다. 전체 변환 완료 증거는 아니다.

아직 필요한 실제 CAD 검증:

```text
작업복사본에서 SWTITLESTATUS
필요 시 SWTITLEPREPARE
SWTITLECONVERT로 실제 native GMTITLE 생성/변환
SWTITLEVERIFY_FINAL_OK
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
```

## 다음 작업

1. 깨끗한 빈 도면에서 native GMTITLE A2/A3/A4를 각각 생성해 정답 형태를 확보한다.
2. 실제 work copy에서 `source-contaminated`만 정규화 대상으로 삼고 `native-format-with-title-geometry`는 삭제하지 않는지 확인한다.
3. 그 뒤에만 `SWTITLECONVERT`로 실제 변환을 진행한다.
