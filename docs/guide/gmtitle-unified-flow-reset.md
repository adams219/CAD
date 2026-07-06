# GMTITLE 공통 흐름 재정렬 가이드

현재 기준 버전: `260706-unified-title-missing-3`

이 문서는 2026-07-06 이후 GMTITLE 변환 작업의 최우선 guide입니다.

기존 guide, history, investigation 문서에 남아 있는 `A4 frame-only` 표현은 이 문서 기준으로 재해석합니다. 과거 기록은 왜 그런 판단을 했는지 보는 증거이고, 현재 실행 기준은 이 문서입니다.

## 목표

SolidWorks에서 넘어온 DWG의 도면틀/표제란을 GstarCAD Mechanical native GMTITLE 구조로 바꿉니다.

핵심 목표는 A2, A3, A4를 서로 다른 기능으로 분리하는 것이 아니라, 같은 GMTITLE 흐름으로 처리하는 것입니다.

```text
기본 흐름:
원본 시트 크기 인식
-> 같은 크기의 DR_A*_Outline 선택
-> DR_titlea_3rd 선택
-> GstarCAD GMTITLE이 만든 native 도면틀/제목블록을 기준으로 값 입력
-> 원본 SolidWorks 도면틀/표제란 잔여물 정리
-> 검증
```

## 핵심 기준

A2, A3, A4는 모두 같은 GMTITLE입니다.

`A4`라는 용지 크기만으로 별도 frame-only 흐름을 선택하지 않습니다.

```text
기본:
  DR_A2_Outline + DR_titlea_3rd
  DR_A3_Outline + DR_titlea_3rd
  DR_A4_Outline + DR_titlea_3rd

예외:
  원본 시트에 표제란/제목블록이 실제로 없다고 검증된 경우만 title-missing sheet로 처리

금지:
  A4라는 이유만으로 DR_titlea_3rd 생성을 막기
  A4라는 이유만으로 별도 명령 흐름으로 보내기
  과거 work-copy 한 장의 실패를 전체 정책으로 확대하기
```

## frame-only 재정의

`frame-only`는 A4 전용 정책이 아닙니다.

앞으로 `frame-only` 또는 `title-missing`은 용지 크기가 아니라 원본 데이터 상태로만 판단합니다.

```text
frame-only/title-missing 조건:
  1. 원본 시트 도면틀은 감지됨
  2. 같은 시트 범위 안에서 원본 표제란/제목블록 후보가 없음
  3. 제목란 영역 텍스트/속성 추출 결과도 없음
  4. 사용자가 "원본에 표제란이 없는 시트"라고 확인했거나 로그로 명확히 증명됨
```

이 조건이 만족되지 않으면 A2/A3/A4 모두 일반 GMTITLE 제목블록 변환 대상입니다.

## 현재 알고 있는 것

GstarCAD가 native GMTITLE로 만든 객체는 단순 블록 삽입과 다릅니다.

우리가 안정적으로 확인한 것은 다음입니다.

```text
DR_A*_Outline 도면틀과 DR_titlea_3rd 제목블록이 쌍으로 존재함
제목블록 attribute 값은 LISP로 읽고 쓸 수 있음
일부 xdata/native link/handle 정보가 GMTITLE 표 편집창 동작에 관여함
복제본은 겉보기와 attribute가 맞아도 더블클릭 시 고급 속성 편집기로 열릴 수 있음
```

따라서 기본 전략은 직접 handle/native link를 추측해서 만들지 않고, GstarCAD의 실제 GMTITLE 생성 결과를 기준 객체로 사용하는 것입니다.

## 아직 모르는 것

아래 항목은 추측으로 해결하지 않습니다.

```text
1. GstarCAD가 GMTITLE 쌍을 native로 인정하는 정확한 내부 조건
2. handle/native link를 새 객체에 안전하게 재배정하는 공식 규칙
3. GMTITLE 대화상자에서 DR_A2/A3/A4와 DR_titlea_3rd를 명령줄만으로 안정 선택하는 방법
4. GstarCAD 내부 paperset.grx가 어떤 데이터를 어떻게 붙이는지
```

이 항목을 풀기 전에는 "완전 자동 native 생성"이라고 단정하지 않습니다.

## 공개 명령 기준

사용자가 실제로 기억하고 사용할 공개 흐름은 네 개로 유지합니다.

```text
APPLOAD
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERTNEXT
SWTITLEVERIFY
```

`SWTITLECONVERT`는 수동 응답을 직접 골라야 할 때만 보조로 사용합니다.

옛 `FASTBATCH`, `BOOTSTRAPFAST`, `FRAMEONLY`, `A3A4` 계열 명령은 guide 기준에서 주 흐름으로 보지 않습니다. 남아 있더라도 실험/호환용으로만 취급합니다.

## 판단 순서

`SWTITLESTATUS` 또는 로그를 볼 때는 이 순서로 판단합니다.

```text
1. 현재 파일이 work 복사본인가
2. 원본 시트가 몇 장인가
3. 각 시트의 용지 크기가 A2/A3/A4 중 무엇인가
4. 각 시트에 원본 표제란/제목블록이 있는가
5. 같은 크기의 native GMTITLE 기준 객체가 이미 있는가
6. 없으면 그 크기 첫 장을 실제 GMTITLE로 만들 준비가 되었는가
7. 있으면 남은 같은 크기 시트를 같은 정책으로 처리할 수 있는가
8. 변환 후 원본 도면틀/표제란/잔여물이 과하게 삭제되지 않았는가
```

여기서 4번이 중요합니다. A4인지 아닌지가 아니라, 원본 표제란이 있는지 없는지를 봅니다.

## 검증 기준

정적/로그 검증을 먼저 하고, CAD 실테스트는 꼭 필요한 대표 케이스만 합니다.

```text
정적 검증:
  원본 시트 수와 target 시트 수 일치
  A2/A3/A4 수량 일치
  불필요한 A4 전용 분기 없음
  원본 표제란 존재 여부와 처리 경로 일치
  남은 원본 도면틀/표제란 후보가 예상 범위인지 확인
  위험한 bbox overlap 또는 raw selection 위험 없음

CAD 실테스트:
  대표 A2 1장
  대표 A3 1장
  대표 A4 1장
  각 제목블록 더블클릭 시 GMTITLE 표 편집창 확인
```

단, 원본에 표제란이 없다고 검증된 title-missing 시트는 제목블록 더블클릭 검증 대상이 아닙니다. 이 경우는 도면틀 수량/형상과 원본 보존 여부를 검증합니다.

## 과거 A4 분기의 해석

과거 문서에서 A4가 별도 처리된 이유는 A4라는 용지 자체 때문이 아닙니다.

당시 특정 work-copy에서 A4 두 장이 표제란 없는 도면틀처럼 감지되었고, `DR_A4_Outline` 삽입/형상 검증에서 문제가 반복되었습니다. 그 임시 대응이 guide와 코드에 A4 전용처럼 남았습니다.

앞으로는 다음처럼 해석합니다.

```text
잘못된 해석:
  A4니까 frame-only

올바른 해석:
  원본 표제란이 없는 시트라서 title-missing 예외
  그 예외 시트의 크기가 우연히 A4였을 수 있음
```

## 코드 정리 방향

코드 수정이 필요할 때의 원칙입니다.

```text
1. A4 전용 조건문을 먼저 늘리지 않는다.
2. 조건 이름을 sheet-size 기준이 아니라 source-title-present 기준으로 바꾼다.
3. 새 공개 명령을 만들기보다 기존 4단계 흐름 안에 안내를 넣는다.
4. handle/native link 재작성은 공식 조건을 더 알기 전까지 기본 경로로 삼지 않는다.
5. CAD 실테스트 전에 로그/정적 probe로 예상 수량과 삭제 후보를 먼저 확인한다.
```

## 중단해야 하는 신호

아래 상황이 나오면 바로 다음 자동 변환으로 넘어가지 않습니다.

```text
원본에 있던 도면 내용이 삭제됨
원본에 없던 제목블록이 생김
원본에 있던 제목블록이 사라짐
도면틀은 맞지만 내부 도면 내용이 이동됨
제목블록 더블클릭이 고급 속성 편집기로 열림
SWTITLESTATUS가 A4라는 이유만으로 별도 경로를 안내함
```

이 경우는 guide/history를 그대로 따라가지 말고, 이 문서의 공통 흐름 기준으로 원인을 다시 분류합니다.
