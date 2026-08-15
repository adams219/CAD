# GMTITLE A4 Outline Prepare Probe - 2026-07-05

## 목적

`SWTITLEPREPARE`가 표제란 없는 A4 변환 전에 `DR_A4_Outline` 정의를 안전하게 준비할 수 있는지 확인했다.

이 probe는 실제 도면을 저장하지 않고, `work` 폴더의 복사본에서만 실행했다.

## Probe 파일

추적 대상 진단 스크립트:

```text
diagnostics/gmtitle-main45/a4_outline_prepare_probe.lsp
diagnostics/gmtitle-main45/run_a4_outline_prepare_probe.ps1
```

생성된 로컬 로그:

```text
work/swtitle_a4_outline_prepare_probe_260705.txt
```

## 실행 결과 요약

```text
Load result: OK
Loaded version: 260705-a4-outline-preflight
Before definition status: missing
Before frame-only-count: 2
Before target-sheet-counts:
  A2: 1
  A3: 12
```

`SWTITLEPREPARE` 내부 A4 definition 준비 함수를 실행했다.

결과:

```text
Prepare result: OK status=WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE
After definition status: missing
After frame-only-count: 2
After target-sheet-counts:
  A2: 1
  A3: 12
Runtime check completed: yes
```

## 실패 이유

가져온 `DR_A4_Outline` 정의의 보이는 A4 범위는 계산상 맞지만, CAD가 실제 선택하는 raw bbox가 너무 크다.

```text
테스트 범위: (0, 0) - (210, 297)
raw 범위: (0, 0) - (872.26126377, 302.7)
raw/effective area ratio: 4.2333411
```

이전 raw bbox probe에서도 같은 원인이 확인됐다.

```text
DR_A4_Outline definition 안에 A4 밖으로 큰 child INSERT가 있음
child bbox = (0, 0) - (872.26126377, 297)
definition raw bbox = (0, 0) - (872.26126377, 302.7)
```

## 판정

현재 설치 원본 `DR_A4_Outline`을 단순 import해서 A4 frame-only 변환에 쓰면 안 된다.

이 probe에서 중요한 성공 지점은 아래다.

```text
위험한 정의를 ready로 인정하지 않음
실패한 DR_A4_Outline 정의를 제거/격리함
기존 A4 원본 도면틀 2장을 삭제하지 않음
```

따라서 현재 guard는 의도대로 동작한다.

## 다음 작업

A4 변환을 계속하려면 변환 명령을 반복하지 말고 `DR_A4_Outline` 정의 정규화 가능성을 먼저 검증해야 한다.

다음 분석 항목:

```text
1. raw bbox를 키우는 child INSERT와 A4 밖 객체가 native A4에 필요한지 분류
2. 제거 가능한 객체만 제거한 후 raw bbox가 210 x 297 근처로 줄어드는지 확인
3. 정규화된 정의를 삽입했을 때 effective bbox와 raw bbox가 모두 원본 A4와 맞는지 확인
4. 통과하면 SWTITLEPREPARE에 A4 definition normalization을 통합
5. 통과하지 않으면 native GMTITLE A4 생성 구조를 별도로 분석
```
