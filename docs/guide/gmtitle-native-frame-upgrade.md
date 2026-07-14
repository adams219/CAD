# GMTITLE native 도면틀 교체 참고

> 2026-07-06 기준 변경: `docs/guide/gmtitle-unified-flow-reset.md`가 GMTITLE 변환의 최우선 기준입니다. A2/A3/A4는 모두 같은 GMTITLE 흐름으로 보고, `frame-only`는 A4 전용 정책이 아니라 원본 표제란 부재가 검증된 경우의 예외로만 해석합니다.

이 문서는 이전의 A2/A3/A4 native 교체 실험을 현재 4단계 흐름 기준으로 정리한 참고 문서입니다.

현재 일반 사용자는 아래 권장 4개 명령만 사용합니다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERTNEXT
SWTITLEVERIFY
```

수동 응답을 직접 고르고 싶을 때만 `SWTITLECONVERT`를 대신 사용합니다.

옛 명령인 `SWTITLEUPGRADENATIVEA3A4BATCH`, `SWTITLEA3A4NEXT`, `SWTITLEFRAMEONLYAPPLY` 같은 이름은 일반 작업에서 직접 입력하지 않습니다. 필요한 내부 단계는 `SWTITLECONVERTNEXT`가 상태에 맞춰 안내합니다.

## 왜 native 교체가 필요했나

GMTITLE로 만든 제목블록은 더블클릭했을 때 GstarCAD Mechanical의 표 편집창이 열려야 합니다.

초기 preserve-copy 방식은 빠르게 여러 장을 만들 수 있었지만, 일부 복제본이 GMTITLE 표 편집창 대신 고급 속성 편집기로 열렸습니다. 그래서 A2/A3/A4 각각 같은 크기의 실제 native GMTITLE 기준 객체를 만들고, 신뢰하기 어려운 복제 쌍은 `SWTITLECONVERTNEXT` 안에서 한 장씩 native 교체하도록 방향을 잡았습니다.

## 현재 기준

현재 LSP 버전:

```text
260714-read-scan-cache-batch-queue-1
```

현재 loader 버전은 `SWTITLEVERSION`에서 함께 확인합니다.

현재 흐름에서는 `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 도면틀 정의와 이미 생성된 GMTITLE target 쌍을 먼저 검사합니다.

분류 기준:

```text
outline-only
native-format-with-title-geometry
source-contaminated
unknown
```

중요한 변경:

```text
source-contaminated
native-format-with-title-geometry + 별도 DR_titlea_3rd 실제 겹침
```

위 상태만 변환 전에 `SWTITLEPREPARE` 정리/정규화 후보로 봅니다.

`native-format-with-title-geometry` 자체는 설치 원본 A3처럼 정상 native 형상일 수 있으므로 일반 삭제 후보로 보지 않습니다.

즉 A3에서 도면틀 안에 표제란처럼 보이는 형상이 들어 있어 별도 `DR_titlea_3rd`와 겹칠 수 있으면, `SWTITLECONVERTNEXT`를 반복하지 않고 먼저 `SWTITLEPREPARE`로 정규화합니다.

## 현재 실행 흐름

항상 상태부터 봅니다.

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
SWTITLECONVERTNEXT
SWTITLESTATUS
```

상태가 검증을 요구하면:

```text
SWTITLEVERIFY
```

## GMTITLE 창에서 확인할 값

`SWTITLECONVERTNEXT` 또는 수동 `SWTITLECONVERT` 중 GMTITLE 창이 열리면 로그가 요구한 용지와 제목블록을 선택합니다.

```text
용지/도면틀: DR_A2_Outline, DR_A3_Outline, DR_A4_Outline 중 로그가 요구한 것
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

`Object move`를 OFF로 두는 이유는 기존 도면 내부 형상을 새 도면틀 기준으로 강제로 이동하지 않기 위해서입니다. 도면틀 기준점은 LSP가 왼쪽 아래 기준으로 처리하고, 사용자가 긴 소수점 좌표를 직접 입력하지 않게 하는 방향입니다.

## A3 도면틀 안 표제란 형상 문제

사용자가 관찰한 핵심 문제:

```text
A2는 도면틀만 있는데 A3에서는 도면틀과 제목블록이 하나로 합쳐져 블록처럼 보인다.
GMTITLE 기능은 가능하지만 도면 형태가 달라지고 표제란이 2개처럼 보일 수 있다.
```

현재 판단:

```text
DR_A3_Outline 도면틀 정의 안에 오른쪽 아래 표제란처럼 보이는 정적 형상이 들어 있을 수 있다.
여기에 별도 DR_titlea_3rd 제목블록이 겹치면 중복처럼 보인다.
```

현재 해결 방향:

```text
SWTITLESTATUS가 먼저 후보를 보여준다.
SWTITLEPREPARE가 작업복사본에서만 실제 겹치는 도면틀 정의 내부 표제란 형상을 정규화한다.
외곽선, 눈금, 좌표 표시는 보존한다.
정상 DR_titlea_3rd 제목블록은 보존한다.
별도 제목블록과 겹치지 않는 native-format 내부 형상은 일반 cleanup에서 제외한다.
같은 위치에 이미 생성된 DR_A*_Outline + DR_titlea_3rd target 쌍이 2개 있으면 중복 target 쌍으로 따로 표시한다.
SWTITLECONVERTNEXT는 같은 bbox에 기존 native GMTITLE 쌍이 있으면 새로 만들지 않고 그 쌍을 채택한다.
A2/A3/A4 native 교체 후보가 남아 있으면 SWTITLESTATUS는 title-missing/frame-only 예외보다 그 후보를 먼저 안내한다.
핵심 상태/검증 안내는 CAD 명령창에서 한국어로 확인한다.
```

## title-missing/frame-only 문제

원본 시트는 표제란 없는 도면틀-only 시트일 수 있습니다. 이 예외는 A4 전용이 아니며, 원본 표제란 부재가 검증된 경우에만 적용합니다.

이 경우 기존 표제란 텍스트를 추출해서 새 제목블록을 채우는 일반 title-sheet 흐름과 다르게 처리해야 합니다.

원칙:

```text
원본 시트에 표제란이 없으면 새 표제란을 억지로 만들지 않는다.
같은 크기의 DR_A*_Outline 기준 객체로 도면틀만 교체한다.
GstarCAD GMTITLE 선택 결과의 실제 bbox가 이상하면 기존 시트를 삭제하지 않는다.
DR_A*_Outline block definition 자체의 raw bbox가 해당 용지보다 과도하게 크면 변환을 시작하지 않는다.
```

`SWTITLESTATUS`가 `NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX`를 안내하거나 `SWTITLECONVERT`가 `ABORT_FRAME_DEFINITION_RAW_BBOX_RISK`로 멈추면, 이는 실패가 아니라 기존 A4를 보호하기 위한 중단입니다.

`main57-a4rawrepair`에서는 사용 중이 아닌 `DR_A*_Outline` 정의라면 `SWTITLEPREPARE`가 설치 원본 정의를 다시 가져와 raw bbox 위험이 사라지는지 확인합니다. 가져온 정의도 위험하면 즉시 롤백합니다.

## 검증 결과

2026-07-04 기준 main57에서는 raw bbox 위험을 감지한 뒤, 사용 중이 아닌 정의만 `SWTITLEPREPARE` 복구 후보로 처리합니다.

```text
work/swtitle_duplicate_target_pair_compare_main56.txt
work/swtitle_adoption_gate_compare_main56.txt
work/swtitle_command_text_guard_compare_main56_command_text_guard.txt
work/swtitle_residue_protection_main56_residue_protection.txt
work/swtitle_embedded_title_prepare_compare_main56_embedded_prepare.txt
```

확인된 내용:

```text
main56 LSP와 테스트용 main56 복사본 해시 일치
4개 공개 명령이 활성화됨
예전 fast/bootstrap/frame-only/A3A4 명령은 공개 명령에서 비활성화됨
A2/A3/A4 frame 정의 분류 probe 통과
A2/A3/A4 overlap-only 정규화 probe 통과
겹친 target 쌍 감지/유지/삭제 후보 선정 통과
기존 native GMTITLE 채택 gate 통과
명령어 텍스트 guard 통과
실제 번호/주석/BOM류 잔여물 보호 probe 통과
```

핵심 proof:

```text
Duplicate target pair probe passed: yes
Adoption gate probe passed: yes
Danger action: <none>
```

별도 `DR_titlea_3rd`가 실제로 겹치는 fixture에서는 style-normalization으로 후보를 잡고 정리합니다.

```text
Style-normalization record count: 3
Style-normalization deleted count: 12
Style-normalization record count after clean: 0
```

## 아직 완료가 아닌 이유

실제 작업복사본은 아직 변환 완료 상태가 아닙니다.

최종 gate 결과:

```text
SWTITLESTATUS: NEXT_UPGRADE_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
source-title-count: 0
source-frame-count: 2
frame-only-count: 2
target-title-count: 13
target-frame-count: 13
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
A2/A3/A4 native 교체 후보: 10
A4 대상 도면틀 누락: 필요 2, 현재 0
```

이 실패는 코드 실패가 아니라 실제 work-copy가 변환 중간 상태라는 뜻입니다. A2와 A3 target은 보이지만, A3 중 10개는 복제/shared-link라 native-like로 증명되지 않았고 title-missing/frame-only 예외 target은 아직 없습니다.

## 완료 기준

완료는 아래 조건을 모두 만족할 때만 인정합니다.

```text
SWTITLEVERIFY_FINAL_OK
남은 원본 SolidWorks 표제란: 0
남은 원본 SolidWorks 도면틀: 0
frame-only 시트: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
실제 DR_titlea_3rd가 있는 대표 A2/A3/A4 용지를 더블클릭하면 GMTITLE 표 편집창 열림
원본 표제란 부재가 검증된 title-missing 시트는 해당 DR_A*_Outline 도면틀만 검증하고, 더블클릭할 제목블록은 없음
도면 안 번호, 주석, BOM, 치수, 모델 형상 유지
```
