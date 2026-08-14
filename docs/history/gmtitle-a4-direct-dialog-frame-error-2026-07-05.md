# GMTITLE A4 직접 선택 프레임 작성 오류 기록

일자: 2026-07-05

## 목적

A4 frame-only 문제를 해결하기 위해 별도 scratch DWG에서 GstarCAD native GMTITLE A4 기준 객체를 만들 수 있는지 확인했다.

## 시도한 절차

GstarCAD `Drawing1.dwg`에서 직접 `GMTITLE`을 실행했다.

GMTITLE 창은 정상적으로 열렸고 아래 값까지 맞출 수 있었다.

```text
용지 형식: DR_A4_Outline
제목 블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

선택 방식은 이전 이력과 같았다.

```text
용지 콤보: Alt+Down -> DR_A4_Outline 선택
제목블록 콤보: Tab -> Alt+Down -> DR_titlea_3rd 선택
객체 이동: Alt+M -> Space로 OFF
```

## 결과

확인을 누른 뒤 새 native A4 기준 객체가 생성되지 않았다.

CAD 명령줄에는 아래 오류가 보였다.

```text
프레임 작성 오류
```

바로 이어서 `SWTITLESTATUS`를 실행했을 때 핵심 상태는 아래와 같았다.

```text
DWG: C:\Users\DR-DESIGN\Documents\Drawing1.dwg
작업 폴더 복사본: 아니오
native GMTITLE 제목블록 존재: 아니요
결과: NEXT_CREATE_FIRST_NATIVE_GMTITLE
```

`SWTITLEVERIFY` 계열 native frame check 로그도 같은 방향을 보였다.

```text
대상 제목블록: DR_titlea_3rd, inserts=0
결과: FAIL_MISSING_TARGET_FRAMES
```

## 판단

이 상태는 A4 native 비교 샘플 확보가 아니다.

중요한 점은 `DR_A4_Outline`과 `DR_titlea_3rd`를 눈으로 맞췄다는 사실만으로는 성공 증거가 되지 않는다는 것이다. `프레임 작성 오류`가 나오고 `DR_titlea_3rd inserts=0`이면, 저장해도 `run_a4_native_exemplar_probe.ps1`의 비교 기준으로 쓰면 안 된다.

## 다음 방향

같은 조작을 반복하지 않는다.

다음 조사는 아래 중 하나여야 한다.

```text
1. 완전히 빈 scratch DWG에서 같은 DR_A4_Outline 선택이 성공하는지 확인
2. GstarCAD가 A4 frame 작성 오류를 내는 원인이 DR_A4_Outline 정의/설치 파일/현재 도면 상태 중 어디인지 비교
3. 성공한 native A2/A3 정의와 실패한 A4 정의의 block definition, xdata, child entity, raw bbox를 비교
```

성공 판정은 여전히 아래 조건을 만족해야 한다.

```text
Native GMTITLE A4 pair evidence: yes
Result: A4_NATIVE_EXEMPLAR_READY_FOR_COMPARISON
```
