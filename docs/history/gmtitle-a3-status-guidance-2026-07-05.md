# GMTITLE A3 Status Guidance - 2026-07-05

## 목적

사용자가 A3 도면틀을 선택했을 때 block처럼 보이는 현상과, 실제 native GMTITLE 미완료 문제를 구분하기 어렵다.

이번 변경은 변환 로직을 바꾸지 않고 `SWTITLESTATUS` 안내를 보강한다.

## 변경 내용

LSP 버전:

```text
260705-a3-frame-guidance
```

`SWTITLESTATUS` 구조 판단 요약에 A3 target이 있을 때 다음 안내를 추가했다.

```text
A3 도면틀 참고: DR_A3_Outline은 native GMTITLE에서도 INSERT/block 참조로 선택될 수 있습니다.
A3 완료 판단은 도면틀 더블클릭이 아니라 DR_titlea_3rd 제목블록 더블클릭과 native 교체 후보 0개로 확인하세요.
```

A3/A4 native 교체 후보가 남아 있을 때 다음 안내도 추가했다.

```text
A3 판단 보충: 도면틀이 block처럼 보이는 현상 자체보다 clone/shared-native-link 후보가 남았는지가 실제 문제입니다.
```

## 이유

최근 변환 후 probe 로그에서는 다음 상태가 확인됐다.

```text
A3 target frame: 12
A3 native-like: 2
A3 clone: 9
A3 shared-native-link: 1
A3/A4 native 교체 필요 쌍: 10
```

따라서 문제의 핵심은 `DR_A3_Outline`이 block 참조로 선택되는 것 자체가 아니다.

진짜 미완료 조건은 clone/shared-native-link 상태의 A3 쌍이 남아 `native-like`로 인정되지 않는 것이다.

## 검증

숨김 GstarCAD 읽기 전용 probe:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_actual_workcopy_status_probe.ps1" `
  -LogPath "work\swtitle_actual_workcopy_status_a3_guidance_260705.txt" `
  -DetailSuffix "_a3_guidance_260705"
```

결과:

```text
Load result: OK
Loaded version: 260705-a3-frame-guidance
Expected version: 260705-a3-frame-guidance
DBMOD before commands: 0
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

현재 저장된 기본 workcopy는 아직 변환 전 상태라 A3 target이 0이다.

따라서 새 A3 안내 문구는 이 probe에서는 조건상 출력되지 않는다.

검증 범위는 다음까지다.

```text
새 LSP 버전 로드 성공
SWTITLESTATUS/SWTITLEVERIFY 실행 성공
저장본 DBMOD=0 확인
기존 변환 전 진단 결과 유지
```

## A3 target fixture 검증

A3 target이 있는 상태도 별도 synthetic probe로 확인했다.

실행:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_a3_status_guidance_probe.ps1"
```

이 probe는 복사본 DWG에서 모든 INSERT를 지운 뒤, 합성 `DR_A3_Outline` + `DR_titlea_3rd` 쌍 1개를 만들고 role을 `clone`으로 표시한다.

결과:

```text
Loaded version: 260705-a3-frame-guidance
A3/A4 candidate count before SWTITLESTATUS: 1
SWTITLESTATUS result: OK
Status after SWTITLESTATUS: NEXT_UPGRADE_A3_A4_NATIVE
A3 frame guidance note found: yes
A3 native-candidate supplement found: yes
A3 status guidance probe passed: yes
Runtime check completed: yes
```

생성된 구조 판단 로그에는 다음 문구가 실제로 출력됐다.

```text
A3 도면틀 참고: DR_A3_Outline은 native GMTITLE에서도 INSERT/block 참조로 선택될 수 있습니다.
A3 완료 판단은 도면틀 더블클릭이 아니라 DR_titlea_3rd 제목블록 더블클릭과 native 교체 후보 0개로 확인하세요.
A3 판단 보충: 도면틀이 block처럼 보이는 현상 자체보다 복제/shared-native-link 후보가 남았는지가 실제 문제입니다.
```

## 다음 실제 CAD 확인

A3 target이 이미 있는 CAD 세션 또는 변환 중간 workcopy에서 `SWTITLESTATUS`를 실행하면 새 A3 안내가 출력되어야 한다.

그 상태에서 완료 판단은 다음 기준으로 한다.

```text
A3/A4 native 교체 후보: 0
native-like A3: 12
clone/shared-native-link 경고: 0
대표 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창
```
