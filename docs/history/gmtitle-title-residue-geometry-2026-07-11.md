# GMTITLE 표제란 잔여물 구조 판정 이력

작성일: 2026-07-11

기준 LSP 버전: `260711-title-residue-geometry-1`

## 목표

GMTITLE 변환 뒤 기존 도면틀 정의 안에 남은 표제란 문자와 선 때문에 새 `DR_titlea_3rd`가 겹쳐 보이는 문제를 A2/A3/A4 공통 방식으로 해결한다.

다음 방식은 사용하지 않는다.

- 고정 도면 좌표
- `Edition`, `Scale` 같은 문자열 목록만으로 삭제
- 객체 bbox 중심점만으로 영역 포함 여부 판단
- 삭제 로직과 같은 함수로만 사후 검증
- A4 전용 분기

## 기존 판정이 놓친 것

기존 코드는 도면 우하단의 고정 범위와 객체 bbox 중심점을 중심으로 후보를 골랐다. 이 방식에는 세 가지 문제가 있었다.

1. 문자의 bbox 일부가 표제란 영역과 겹쳐도 중심점이 밖이면 후보에서 빠졌다.
2. 실제 도면틀은 `DR_A*_Outline` 아래에 다른 블록이 중첩되어 있어, 상위 좌표만 비교하면 내부 객체 위치를 잘못 판단했다.
3. 삭제 후 확인도 같은 필터를 다시 사용해서, 필터가 놓친 잔여물을 `0`으로 오판할 수 있었다.

실제 저장 작업복사본의 `DR-A3 From_HYUN` 계열 정의에는 아래 항목이 남아 있었다.

```text
Edition
Sheet
Scale
Date
Approved by - date
Title/Name, designation, material, dimensions etc.
Article No./Reference
File No
File name
```

따라서 화면에서 새 제목블록과 기존 문자가 겹쳐 보인 것은 단순 표시 문제가 아니라 도면틀 정의 안의 실제 잔여 형상이었다.

## 새 판정 원리

### 1. 실제 제목블록 범위를 기준으로 사용

각 보이는 `DR_A*_Outline`과 가까운 `DR_titlea_3rd` 쌍을 찾는다. 별도 제목블록의 실제 world bbox를 도면틀 INSERT의 역변환으로 frame-local 좌표에 옮긴다.

이 영역을 실제 제목블록 크기에 비례해 조금 확장한 범위가 정리 기준이다. A2/A3/A4의 고정 우하단 숫자는 사용하지 않는다.

### 2. 중첩 블록 변환 누적

도면틀 정의 아래 INSERT를 재귀 순회하면서 다음 2D affine 변환을 누적한다.

```text
삽입점
X/Y 축척
회전
블록 기준점
부모 블록 변환
```

각 하위 객체 bbox를 frame-local 좌표로 변환한 뒤 실제 제목블록 기준 영역과 교차하는지 본다. 중심점 포함이 아니라 bbox 교차를 사용한다.

### 3. 삭제와 보호를 분리

다음 객체는 정리 영역과 겹치면 기존 표제란 잔여물 후보가 된다.

- TEXT, MTEXT, ATTRIB 계열 문자
- 표제란 격자와 구획선
- 제목 영역 안에 완전히 포함된 로고/하위 INSERT

다음 객체는 보호한다.

- 실제 도면틀 외곽선
- 외곽에 붙은 짧은 좌표 눈금
- 외곽 가까이 있는 1~2글자 좌표 문자
- 개정표와 도면 내용
- 별도 native `DR_titlea_3rd`

미리보기 로그에는 삭제 후보, 독립 잔여물, 보호 객체 수와 중첩 블록 경로를 따로 기록한다.

### 4. 독립 검증기 사용

삭제 후보 생성 함수와 별개인 독립 잔여물 검증기를 만들었다. 정리 뒤 독립 검증 결과가 0이 아니면 `OK`로 끝내지 않는다.

```text
WARN_RESIDUE_REMAINS
WARN_FRAME_STYLE_RESIDUE_UNCLASSIFIED
```

안전한 삭제 후보로 분류하지 못했지만 실제 제목 영역에 형상이 남은 경우도 경고로 중단한다.

### 5. 블록 트리 재구축

GstarCAD에서는 블록 정의 내부 객체에 직접 `vla-Delete`를 호출하면 ActiveX 예외가 발생할 수 있었다. 따라서 하위 정의부터 새 clean 블록으로 재구축한다.

1. 삭제 대상이 있는 가장 깊은 하위 블록을 먼저 복사한다.
2. 삭제 대상 객체만 제외한다.
3. 상위 블록의 하위 INSERT가 clean 정의를 보도록 새 블록 트리를 만든다.
4. 기존 `DR_A*_Outline` 정의는 백업 이름으로 보존한다.
5. 새 clean root를 원래 `DR_A*_Outline` 이름으로 바꾼다.
6. 보이는 frame INSERT를 새 정의로 다시 연결한다.

이 방식은 native 제목블록의 xdata, 속성값, link를 직접 고치지 않는다.

## 검증 결과

### 합성 A2/A3/A4 회귀

세 용지 모두 같은 fixture 구조를 사용했다.

```text
DR_A*_Outline
  -> SWSTYLE_*_FRAME_CONTENT
     -> 기존 표제란 문자/격자/로고
```

결과:

```text
정리 후보: 42
독립 잔여물 정리 전: 42
보호 객체: 15
삭제 처리: 42
독립 잔여물 정리 후: 0
두 번째 실행 후보/삭제: 0 / 0
개정표 문자 보존: 예
좌표 문자 보존: 예
```

중심점은 기존 영역 밖이지만 bbox가 일부 겹치는 `PARTIAL TITLE RESIDUE`도 검출되도록 fixture에 포함했다.

### 전체 GstarCAD 회귀

`run_main45_verification_suite.ps1`의 18단계를 2026-07-11에 정상 창 방식으로 다시 실행했다.

```text
Result: PASS
Loaded version: 260711-title-residue-geometry-1
```

검증에는 A2/A3/A4 공통 분류, 정규화, 명령어 텍스트 보호, 도면 잔여물 보호, 중복 GMTITLE 쌍, native 판정, 일괄 변환 SCRIPT 차단이 포함된다.

### 실제 저장 작업복사본 읽기 전용 결과

대상:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

결과:

```text
SWTITLESTATUS: NEXT_PREPARE_FRAME_STYLE_NORMALIZATION
정규화 대상 GMTITLE 쌍: 5
  A2: 1
  A3: 4
A2 정의 독립 잔여물/삭제 후보: 5 / 5
A3 정의 독립 잔여물/삭제 후보: 27 / 27
native-like GMTITLE 쌍: 5
native 교체 후보: 0
```

이 결과는 이전 `NEXT_RUN_FAST_BATCH` 판단보다 정규화가 먼저라는 뜻이다.

### 실제 작업복사본 공개 명령 정리 결과

기존 저장본을 새 전용 복사본으로 만든 뒤 공개 `SWTITLEPREPARE`와 `YES`를 실행했다.

```text
검증 복사본:
work\swtitle_actual_residue_cleanup_probe_260711_02.dwg

정리 전 style 쌍: 5
정리 전 고유 삭제 후보/독립 잔여물: 32 / 32
정리 전 보호 객체: 39
정리 전 target/native-like 쌍: 5 / 5

첫 정리 결과: OK_FRAME_STYLE_NORMALIZATION_CLEANED
정리 후 style 쌍/삭제 후보/독립 잔여물: 0 / 0 / 0
정리 후 target/native-like 쌍: 5 / 5
제목블록 handle/속성/native link 서명 동일: 예

두 번째 정리 결과: OK_NO_FRAME_STYLE_NORMALIZATION
두 번째 정리 후 후보/독립 잔여물: 0 / 0
원본 작업복사본 SHA256 불변: PASS
```

저장 후 새 GstarCAD 세션에서 다시 연 결과도 `도면틀 스타일 정규화 후보=0`, `독립 검증 기존 표제란 잔여물=0`, `native-like=5/5`였다.

### 완전 변환본 A2/A3/A4 보존 결과

2026-07-10에 원본에서 만든 전용 full-flow 복사본에는 A2 1장, A3 12장, 제목블록 없는 A4 2장이 모두 있었다. 이 파일도 다시 복사한 뒤 표제란 잔여물 정리 코어만 검증했다.

```text
검증 복사본:
work\swtitle_integrated_autoselect_fullflow_residue_clean_260711_02.dwg

정리 전 target frame/title/native-like pair: 15 / 13 / 13
정리 전 style 쌍: 13
정리 전 고유 삭제 후보/독립 잔여물: 32 / 32

정리 후 target frame/title/native-like pair: 15 / 13 / 13
정리 후 style 쌍/삭제 후보/독립 잔여물: 0 / 0 / 0
두 번째 정리 후보/독립 잔여물: 0 / 0
13개 제목블록 handle/속성/native link 서명 동일: 예
원본 full-flow 복사본 SHA256 불변: PASS
```

저장 후 재열기에서도 다음 값이 유지됐다.

```text
원본 표제란/도면틀: 0 / 0
target frame/title/pair: 15 / 13 / 13
native-like가 아닌 쌍: 0
중복 target 쌍: 0
독립 잔여물: 0
용지별 target: A2=1, A3=12, A4=2
```

재열기 상태의 `orphan=2`는 2026-07-10 구버전이 만든 제목블록 없는 A4 두 장의 title-missing 표식이 최신 판정에 남지 않은 별도 문제다. 두 A4 frame은 정리 전후 모두 유지됐으며, 이번 표제란 잔여물 삭제 결과와 섞어 처리하지 않는다.

### 편집창 보존 근거

정리 전 같은 native 제목블록 집합은 2026-07-10 전수 클릭에서 아래 결과를 통과했다.

```text
제목블록 GMTITLE 표 편집창: 13 / 13
Advanced Attribute Editor: 0
REFEDIT: 0
도면틀 편집 동작: 15 / 15
```

이번 정리는 제목블록 INSERT를 교체하지 않았고 13개 제목블록의 handle, 속성 수, native link 종류와 짝 frame handle 서명이 정리 전후 동일했다. 정리 후 별도 임시 복사본의 대표 제목블록 `16DB5`에도 `GMSBLOCKE`가 성공값 `T`를 반환했다. GstarCAD의 자식 편집 대화상자는 현재 Computer Use에서 별도 target 창으로 노출되지 않아 새 화면 캡처는 만들지 못했지만, 기존 전수 클릭 결과와 사후 구조 불변을 함께 편집 기능 보존 근거로 사용한다.

## 완료 판단

이번 표제란 잔여물 판정 구조 목표는 다음 근거로 통과한다.

1. 실제 작업복사본 공개 `SWTITLEPREPARE` 정리 후 독립 잔여물 0
2. 완전 변환본 A2/A3/A4 수량 보존
3. 대상 제목블록 한 개씩 유지, 중복 쌍 0
4. 도면틀 외곽/좌표/개정표 보호 fixture 통과
5. 정리 전 전수 클릭 13/13과 정리 후 native 서명 불변
6. 두 번째 정리 후보 0
7. 잔여물이 있던 완전 변환본에서 `SWTITLEVERIFY_WARN_RESIDUE_REMAINS` 확인
8. 고정 좌표나 A4 전용 분기 없이 A2/A3/A4 공통 판정 사용
9. 모든 원본 파일 SHA256 불변

구버전 full-flow A4 두 장의 title-missing 표식 누락은 별도 후속 안건이며, 이번 잔여물 판정 목표의 성공을 가리지 않는다.
