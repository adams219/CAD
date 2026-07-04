# GMTITLE 이력 기반 구조 개선 계획 - 2026-07-04

## 목적

SolidWorks에서 저장한 DWG의 도면틀/표제란을 GstarCAD Mechanical의 GMTITLE 구조로 바꾸되, 같은 시행착오를 반복하지 않기 위한 실행 계획이다.

이 계획은 새 임시 명령어를 계속 늘리는 방향이 아니라, 기존 Git 커밋 이력과 `work` 진단 로그에서 확인된 실패 원인을 기준으로 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` 4개 명령어 안에서 흐름을 안정화하는 것을 목표로 한다.

## 참고한 로컬/GitHub 이력

현재 로컬 브랜치 기준 Git 이력에서 다음 흐름이 확인된다.

```text
0121ae1 Clean up GMTITLE command surface
843e453 Verify preserve-copy GMTITLE A4 frame-only
b69ff54 Require strict native GMTITLE exemplars
0bb4c9b Document GMTITLE first-native picker limits
5ed90c1 Guard GMTITLE frame definition imports
```

이 이력에서 얻은 결론은 다음과 같다.

- 공개 명령어를 계속 늘리면 사용자가 어떤 명령을 쳐야 하는지 더 헷갈린다.
- GMTITLE 용지/제목블록 선택은 좌표 자동 클릭이나 스크린샷 기반 자동화로 안정화하기 어렵다.
- 겉으로 도면틀이 생긴 것과 진짜 GMTITLE 편집창이 열리는 것은 다르다.
- A2/A3/A4마다 실제 native GMTITLE 기준 객체가 필요하다.
- A4 frame-only 시트는 표제란이 없는 별도 흐름으로 봐야 한다.
- `DR_A*_Outline` 도면틀이 블록으로 선택되는 것은 그 자체로 실패가 아니다. 최종 편집 대상은 `DR_titlea_3rd` 제목블록이다.

## 현재 확인된 핵심 문제

### 1. A3 도면 형태 변화

사용자 관찰:

```text
A2는 도면틀만 있는데 A3에서는 도면틀과 제목블록이 하나로 합쳐져서 블록으로 인식된다.
GMTITLE 기능은 사용 가능하지만 도면 형태가 달라졌다.
```

현재 판단:

이 문제는 A3 하나만 대충 지우는 문제가 아니다. `DR_A3_Outline` 정의 자체가 `outline-only`가 아니라 `native-format-with-title-geometry`처럼 보이는 상태일 수 있다.

따라서 `SWTITLEPREPARE`는 도면틀 정의를 다음처럼 먼저 분류해야 한다.

```text
outline-only
native-format-with-title-geometry
source-contaminated
unknown
```

그리고 `native-format-with-title-geometry`는 무조건 삭제 대상으로 보지 않는다. GstarCAD 설치 원본이 원래 그런 구조인지, 이전 변환 중 오염된 것인지 먼저 구분해야 한다.

### 2. 빨간 네모 영역이 사라지는 문제

사용자 관찰:

```text
도면 안의 번호, 주석, 일부 텍스트가 사라지는 경우가 있다.
```

현재 판단:

잔여물 삭제 로직이 표제란/도면틀 주변만 지워야 하는데, 실제 도면 내용의 번호, 주석, BOM, 텍스트까지 삭제 후보로 잡을 위험이 있다.

따라서 삭제는 다음 조건을 모두 만족할 때만 허용해야 한다.

```text
1. 원본 SolidWorks 표제란/도면틀 후보로 분류됨
2. 삭제 영역이 표제란 또는 도면틀 외곽 잔여물 영역과 일치함
3. 치수, 주석, 번호, BOM, 모델 형상으로 보이는 객체가 아님
4. SWTITLESTATUS에서 먼저 후보 목록으로 보임
5. 작업복사본에서 YES 확인 후 SWTITLEPREPARE가 처리함
```

### 3. A4 frame-only 누락

사용자 관찰:

```text
A4는 원본에 표제란이 없는데 변환 후 표제란이 생기거나, 첫 장만 바뀌고 나머지가 남는다.
```

현재 판단:

A4는 `title sheet`가 아니라 `frame-only sheet`로 분리해야 한다.

즉, A4에는 기존 표제란 텍스트 추출/삽입 흐름을 억지로 적용하지 않고, `DR_A4_Outline` native GMTITLE 기준 도면틀을 만든 뒤 남은 A4 frame-only 시트를 같은 크기 기준으로 복제해야 한다.

### 4. CAD 입력 실수

`work/swcad_title_next_step_last.txt`에서 현재 probe DWG 상태는 다음처럼 확인되었다.

```text
실수 명령어 텍스트 후보: 2
결과: NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT
```

이것은 CAD 명령어 입력이 명령창이 아니라 도면 영역으로 들어가 `_PASTECLIP` 또는 문자 객체가 생긴 흔적이다.

앞으로 CAD 테스트에서 이 상태가 나오면 변환을 진행하지 않는다. 먼저 작업복사본인지 확인하고, 실수 명령어 텍스트 후보를 검토/정리한 뒤 다음 단계로 넘어간다.

## 반복 금지 사항

다음 방식은 다시 기본 방향으로 사용하지 않는다.

```text
스크린샷 좌표 클릭으로 GMTITLE 용지 선택
A3/A4 전용 공개 명령어 추가
DR_A*_Outline 내부 객체 무조건 삭제
도면틀이 블록으로 잡힌다는 이유만으로 실패 판단
더블클릭 테스트 없이 GMTITLE 성공 판단
원본 또는 Downloads DWG 직접 편집
SWTITLEVERIFY_FINAL_OK 없이 완료 선언
CAD 명령어 입력 전 focused command text 확인 생략
```

## 새 실행 계획

### 1단계. 이력 기준 상태 고정

작업 전 항상 다음을 확인한다.

```text
git status --short --branch
SWTITLEVERSION
SWTITLESTATUS
```

`SWTITLEVERSION`은 현재 기준으로 다음이어야 한다.

```text
260704-command-text-guard-main-48
```

다른 버전이면 먼저 LSP 로드 상태를 고친다.

### 2단계. 작업복사본만 사용

실제 변환은 반드시 아래 폴더의 복사본에서만 한다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

`Downloads`나 원본 DWG에서 실행하면 `SWTITLESTATUS`는 가능하지만, `SWTITLEPREPARE`와 `SWTITLECONVERT`는 진행하지 않는다.

### 3단계. 구조 분류 먼저 수행

`SWTITLESTATUS`가 다음 정보를 한 번에 보여줘야 한다.

```text
원본 표제란 시트 수
원본 도면틀 수
표제란 없는 도면틀 시트 수
A2/A3/A4 예상 수량
GMTITLE target frame/title 수량
도면틀 정의 분류
도면 내용 삭제 위험 후보
실수 명령어 텍스트 후보
다음 명령어
```

여기서 `실수 명령어 텍스트 후보`, `도면 내용 삭제 위험`, `unknown frame definition`이 있으면 변환을 막는다.

### 4단계. PREPARE는 정리만 담당

`SWTITLEPREPARE`는 다음만 처리한다.

```text
실수 명령어 텍스트 후보 정리
source-contaminated 도면틀 정의 정리
native-format-with-title-geometry 도면틀 스타일 정규화
명확한 표제란/도면틀 잔여물 후보 정리
```

도면 안의 번호, 주석, BOM, 치수, 모델 형상은 정리 대상이 아니다.

삭제 여부가 애매하면 삭제하지 않고 `SWTITLESTATUS`에 이유를 남긴다.

### 5단계. CONVERT는 한 흐름만 유지

사용자는 다음 하나만 반복한다.

```text
SWTITLECONVERT
```

이 명령 안에서 내부적으로 다음을 처리한다.

```text
첫 native GMTITLE 생성
부족한 A2/A3 native exemplar 생성 안내
A4 frame-only native exemplar 생성 안내
준비된 크기의 나머지 시트 자동 복제
표제란 값 입력
원본 SolidWorks 표제란/도면틀 제거
```

A2/A3/A4 전용 공개 명령어를 새로 만들지 않는다.

### 6단계. VERIFY가 최종 판정

완료 판정은 오직 다음 조건으로만 한다.

```text
SWTITLEVERIFY_FINAL_OK
source-title-count: 0
source-frame-count: 0
frame-only-count: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
도면 안 번호/주석/BOM/치수/모델 형상 삭제 없음
A3 제목블록 중복 없음
A4 frame-only 누락 없음
```

이 중 하나라도 빠지면 완료가 아니다.

## 구현 우선순위

1. `SWTITLESTATUS`가 현재 도면의 위험 상태를 한국어로 명확히 보여주도록 정리한다.
2. 실수 명령어 텍스트 후보가 있으면 `SWTITLECONVERT`를 막는다.
3. A2/A3/A4 도면틀 정의 분류를 같은 기준으로 통일한다.
4. A3 `native-format-with-title-geometry`를 원본 스타일인지 오염인지 구분한다.
5. 빨간 네모 영역처럼 실제 도면 내용으로 보이는 객체는 삭제 후보에서 제외한다.
6. A4 frame-only를 표제란 있는 시트와 분리해서 처리한다.
7. 최종 게이트 `SWTITLEVERIFY_FINAL_OK`가 나올 때만 완료로 본다.

## 다음 작업

바로 다음 구현은 새 명령어가 아니라 기존 4개 명령어의 판단력을 높이는 방향으로 한다.

```text
SWTITLESTATUS:
  위험 상태와 다음 명령을 더 분명히 출력

SWTITLEPREPARE:
  실수 명령어 텍스트와 오염된 도면틀 정의만 제한적으로 정리

SWTITLECONVERT:
  위험 상태가 남아 있으면 변환 중단

SWTITLEVERIFY:
  수량, native-like, 더블클릭 대상, 도면 내용 보존 여부를 최종 검증
```

이 계획은 한 장짜리 임시 처방이 아니라, 이후 다른 DWG에도 같은 기준을 적용하기 위한 구조 기준으로 사용한다.
