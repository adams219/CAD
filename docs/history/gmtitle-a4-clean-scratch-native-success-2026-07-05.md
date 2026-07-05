# GMTITLE A4 Clean Scratch Native Success - 2026-07-05

## 배경

기존 work-copy 또는 Drawing1 상태에서 `GMTITLE`로 `DR_A4_Outline` / `DR_titlea_3rd`를 직접 선택하면 명령줄에 "프레임 작성 오류"가 나오고, 이후 진단에서 `DR_titlea_3rd inserts=0`으로 확인됐다.

이 상태만 보면 `DR_A4_Outline` 자체가 깨졌다고 판단하기 쉽지만, 설치 원본 A4 정의와 기존 DWG에 이미 로드된 블록 정의/컨텍스트가 섞여 있을 가능성이 남아 있었다.

## CAD 테스트

GstarCAD에서 새 `gcadiso.dwt` 기반 Drawing2를 열고, 실제 `GMTITLE` 대화상자에서 아래 값을 선택했다.

```text
용지 / 도면틀: DR_A4_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
삽입점: 0,0
```

결과는 성공이었다.

```text
프레임 작성 오류 없음
DR A4 세로 도면틀과 DR_titlea_3rd 제목블록이 화면에 생성됨
UPDATEFIELD가 실행됐지만 필드는 0개 업데이트
```

저장한 비교용 파일:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\scratch_native_a4_clean_260705.dwg
```

## 의미

이번 결과는 `DR_A4_Outline` 자체가 항상 실패하는 것은 아니라는 증거다.

더 가능성이 큰 원인은 아래 중 하나다.

```text
1. 기존 DWG에 이미 로드된 DR_A4_Outline 정의가 설치 원본과 다름
2. 기존 Drawing1/work-copy의 GMTITLE 상태 또는 내부 Mechanical 데이터가 A4 생성 오류를 유발함
3. 대화상자 선택은 맞아도 현재 도면 컨텍스트에 따라 GstarCAD가 다른 정의/캐시를 사용함
```

## 아직 완료가 아닌 이유

눈으로 도면틀이 보이는 것만으로는 production 변환에 바로 연결하지 않는다.

다음 조건을 숨김 probe로 확인해야 한다.

```text
Definition strict A4 warning: <none>
Definition test insert geometry warning: <none>
Definition test insert raw selection warning: <none>
Native GMTITLE A4 pair evidence: yes
Result: A4_NATIVE_EXEMPLAR_READY_FOR_COMPARISON
```

실행할 검증:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1 -SourceWorkCopyPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\scratch_native_a4_clean_260705.dwg" -WaitForGstarCADClose
```

GstarCAD가 열려 있으면 이 probe는 숨김 CAD를 바로 실행하지 못한다. visible CAD를 저장하고 닫은 뒤 실행한다.

## 다음 판단

probe가 READY면 clean native A4 구조를 기준으로 기존 work-copy의 A4 정의 차이를 비교한다.

probe가 `A4_NATIVE_EXEMPLAR_MISSING_NATIVE_PAIR` 또는 raw bbox warning을 내면, 화면상 성공처럼 보여도 native GMTITLE 구조 비교 기준으로는 아직 부족하다고 판단한다.
