# GMTITLE 실제 CAD 변환 체크리스트

이 문서는 GstarCAD 화면에서 SolidWorks DWG 작업복사본을 GMTITLE 구조로 바꿀 때 따라가는 순서입니다.

사용자는 아래 4개 명령만 사용합니다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

다음 예전 명령은 직접 사용하지 않습니다. 실행된다면 오래된 LSP가 로드된 상태일 수 있으니 다시 APPLOAD 하세요.

```text
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
SWTITLEGMTITLEVERIFYALL
```

## 0. 작업복사본 확인

변환은 반드시 `work` 폴더 아래의 복사본에서만 합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

`Downloads` 폴더의 원본 DWG나 실제 납품 원본에서 바로 실행하지 마세요.

## 1. LSP 로드

GstarCAD에서 APPLOAD로 아래 파일을 로드합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
```

GMTITLE 도구만 직접 로드할 수도 있습니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

로드 후 버전을 확인합니다.

```text
SWTITLEVERSION
```

기대 버전:

```text
260704-target-overlap-adopt-main56-a4guard
```

다른 버전이 나오면 변환하지 말고 최신 LSP를 다시 APPLOAD 하세요.

## 2. 상태 진단

먼저 읽기 전용 상태 진단을 실행합니다.

```text
SWTITLESTATUS
```

확인할 내용:

```text
현재 DWG가 work 폴더 복사본인지
원본 SolidWorks 표제란 시트 수
원본 SolidWorks 도면틀 수
표제란 없는 도면틀 시트 수
A2/A3/A4 예상 수량
GMTITLE target 도면틀/제목블록 수량
DR_A2/A3/A4_Outline 도면틀 정의 상태
도면틀 안 내장 표제란 형상 후보
A4 실제 선택 bbox 경고
다음 권장 명령
```

현재 기준 작업복사본의 변환 전 정상 상태는 대략 다음입니다.

```text
NEXT_CREATE_FIRST_NATIVE_GMTITLE
원본 표제란 시트: 13
원본 도면틀: 15
표제란 없는 도면틀 시트: 2
A2: 1
A3: 12
A4: 2
target 도면틀: 0
target 제목블록: 0
```

`SWTITLESTATUS`가 `SWTITLEPREPARE`를 안내하면 변환하지 말고 먼저 정규화합니다.

## 3. 필요한 경우 정규화

`SWTITLESTATUS`가 정규화를 안내할 때만 실행합니다.

```text
SWTITLEPREPARE
```

main56 기준 정규화 대상:

```text
source-contaminated 도면틀 정의
별도 DR_titlea_3rd와 실제로 겹치는 native-format 도면틀 내부 표제란 형상
실수로 도면에 들어간 명령어 TEXT/MTEXT
제목블록 없는 고아 GMTITLE 도면틀
같은 위치에 겹친 DR_A*_Outline + DR_titlea_3rd GMTITLE target 쌍
```

보호 대상:

```text
외곽선
눈금
좌표 표시
정상 DR_titlea_3rd 제목블록
도면 안 번호
주석
BOM
치수
모델 형상
```

후보 목록을 확인한 뒤 맞을 때만 `YES`를 입력합니다. 후보가 이상하면 진행하지 말고 로그를 확인합니다.

정규화 후 다시 상태를 봅니다.

```text
SWTITLESTATUS
```

## 4. 변환 실행

상태 진단이 변환을 안내할 때 실행합니다.

```text
SWTITLECONVERT
```

이 명령은 내부에서 필요한 단계만 진행합니다.

```text
첫 native GMTITLE 기준 객체 생성
기존 SolidWorks 표제란 텍스트 추출
시트 크기 자동 인식
같은 크기 native 기준 객체 준비
이미 같은 위치에 native GMTITLE 쌍이 있으면 새로 만들지 않고 채택
남은 시트 자동 복제/배치
기존 SolidWorks 도면틀/표제란/잔여물 제거
A3/A4 native 인식이 불확실한 쌍은 한 장씩 교체 안내
```

GMTITLE 창이 열리면 로그가 요구한 값만 선택합니다.

예시:

```text
용지/도면틀: DR_A2_Outline 또는 로그가 요구한 DR_A*_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

금지:

```text
일반 A2/A3/A4 용지 선택
ISO 제목블록 선택
Object move ON 상태로 확인
스크린샷 좌표 클릭으로 용지 선택
긴 소수점 좌표를 사람이 직접 입력
```

한 번 실행한 뒤에는 바로 다시 변환하지 말고 상태를 다시 봅니다.

```text
SWTITLESTATUS
```

## 5. 반복 규칙

항상 이 순서로 반복합니다.

```text
SWTITLESTATUS
SWTITLEPREPARE   상태가 요구할 때만
SWTITLESTATUS
SWTITLECONVERT   상태가 요구할 때만
SWTITLESTATUS
```

`SWTITLESTATUS`가 최종 검증을 안내하면 변환을 멈추고 검증합니다.

## 6. 최종 검증

```text
SWTITLEVERIFY
```

완료 조건:

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
frame-only 시트: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
실수 명령어 텍스트 후보: 0
도면틀 내부 표제란 형상 후보: 0
도면틀 스타일 정규화 후보: 0
중복 표제란 없음
같은 위치에 겹친 GMTITLE target 쌍: 0
고아 도면틀 없음
```

마지막으로 대표 A2/A3/A4의 `DR_titlea_3rd` 제목블록을 더블클릭해서 GMTITLE 표 편집창이 열리는지 확인합니다.

도면 안의 번호, 주석, BOM, 치수, 모델 형상이 남아 있는지도 확인합니다.

## 현재 상태

main56 코드와 진단 fixture는 통과했습니다.

```text
중복 target 쌍 감지/정리 probe: 통과
기존 native GMTITLE 채택 gate probe: 통과
명령어 텍스트 guard probe: 통과
잔여물 보호 probe: 통과
native-format title geometry 보호 probe: 통과
```

하지만 실제 work-copy 변환은 아직 끝나지 않았습니다. final gate는 아직 실패하는 것이 정상입니다.

```text
SWTITLEVERIFY_FINAL_FAIL
target-title-count: 0
target-frame-count: 0
```
