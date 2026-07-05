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

## 숨김 probe 결과

2026-07-05에 저장한 scratch DWG를 닫은 뒤 focused probe를 실행했다.

실행:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_native_exemplar_probe.ps1 -SourceWorkCopyPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\scratch_native_a4_clean_260705.dwg" -LogPath "C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt" -WaitForGstarCADClose
```

전용 로그:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_a4_native_exemplar_scratch_native_a4_clean_260705.txt
```

주의: 전체 verification suite의 4번 gap probe는 기본 로그 `swtitle_a4_native_exemplar_probe_260705.txt`를 다시 쓴다. 그래서 clean scratch 결과는 위 전용 로그로 보존한다.

핵심 결과:

```text
Native GMTITLE A4 pair evidence: yes
Definition raw risk: <none>
Definition test insert geometry warning: <none>
Definition test insert raw selection warning: <none>
Definition minor native outside markers: yes
Result: A4_NATIVE_EXEMPLAR_READY_WITH_NATIVE_OUTSIDE_MARKERS
```

즉, clean scratch A4는 native GMTITLE 쌍으로 인정된다.

다만 `DR_A4_Outline` 정의 자체에는 A4 바깥의 작은 native 마커가 있다.

```text
#2 LINE layer=AM_9 bbox=(216.25210777, 255.85515117) - (266.25210777, 255.85515117)
#3 LINE layer=AM_9 bbox=(216.25210777, 242.67139444) - (266.25210777, 242.67139444)
#7 TEXT layer=0 bbox=(200.9, 287.3) - (248.3, 292.7)
#8 TEXT layer=0 bbox=(210.9, 297.3) - (264.9, 302.7)
```

## 다음 판단

기존 strict 기준인 `definition raw bbox == (0,0)-(210,297)`은 공식 native A4에도 맞지 않는다.

따라서 이 mismatch만으로 source contamination이라고 판단하면 안 된다.

다음 구현 판단은 아래 중 하나다.

```text
1. native A4가 가진 작은 바깥 마커를 공식 구조로 허용한다.
2. production A4 frame-only에는 effective A4 frame만 쓰도록 crop/정규화한다.
3. 마커는 유지하되 기존 원본 A4 안쪽 도면 내용과 삭제 영역이 겹치지 않게 별도 안전 기준을 둔다.
```

단, production A4 원본은 frame-only이므로 원본에 없던 `DR_titlea_3rd` 제목블록을 만들면 안 된다는 규칙은 유지한다.
