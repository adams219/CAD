# GMTITLE 현재 실행 카드

CAD 화면 옆에 띄워두고 따라가는 짧은 절차입니다.

## 시작 전

반드시 `work` 폴더의 작업복사본에서만 실행합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

`Downloads` 원본 DWG나 납품 원본에서는 실행하지 않습니다.

## 로드

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\swcad_load.lsp
SWTITLEVERSION
```

기대 버전:

```text
260704-plan-frame-prepare-main-49
```

다른 버전이면 변환하지 말고 다시 APPLOAD 합니다.

## 현재 작업복사본의 시작 상태

현재 기준 work-copy는 아직 GMTITLE 대상 객체가 없는 변환 전 상태입니다.

```text
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
원본 표제란/도면틀: 13 / 15
표제란 없는 도면틀 시트: 2
대상 도면틀/제목블록: 0 / 0
필요 용지:
  A2: 1
  A3: 12
  A4: 2
```

이 상태는 오류가 아닙니다. 다음 명령은 `SWTITLECONVERT`입니다.

## 반복 순서

항상 상태부터 확인합니다.

```text
SWTITLESTATUS
```

상태가 정규화를 요구하면:

```text
SWTITLEPREPARE
SWTITLESTATUS
```

상태가 변환을 요구하면:

```text
SWTITLECONVERT
SWTITLESTATUS
```

상태가 최종 검증을 요구하면:

```text
SWTITLEVERIFY
```

## GMTITLE 창에서 확인

`SWTITLECONVERT` 중 GMTITLE 창이 열리면 로그가 요구한 값만 선택합니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

## 하지 말 것

```text
일반 A2/A3/A4 선택
ISO 제목블록 선택
스크린샷 좌표 클릭
긴 소수점 좌표 직접 입력
SWTITLEFASTSTATUS
SWTITLETRANSFERBOOTSTRAPFAST
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLEA3A4NEXT
```

위 예전 명령이 필요해 보이면 오래된 흐름으로 돌아간 것입니다. `SWTITLESTATUS` 결과를 다시 봅니다.

## 완료 조건

`SWTITLEVERIFY`가 아래 상태를 만족해야 합니다.

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
frame-only 시트: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
```

마지막으로 대표 A2/A3/A4의 `DR_titlea_3rd` 제목블록을 더블클릭합니다.

기대 결과:

```text
GMTITLE 표 편집창 열림
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```
