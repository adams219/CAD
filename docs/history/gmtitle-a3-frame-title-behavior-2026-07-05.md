# GMTITLE A3 Frame/Title Behavior Evidence - 2026-07-05

## 목적

사용자가 본 증상:

```text
A3 제목블록은 GMTITLE 표 편집창이 열리는 것처럼 보인다.
하지만 A3 도면틀은 아직 블록처럼 인식된다.
그래서 도면틀에도 GMTITLE 기능이 적용되지 않은 것처럼 보인다.
```

이 문서는 이 현상을 바로 코드 수정으로 처리하지 않고, 현재 로그 기준으로 원인을 분리한다.

## 먼저 분리해야 하는 사실

GstarCAD Mechanical의 GMTITLE 결과에서도 도면틀 `DR_A*_Outline`은 여전히 `INSERT`/block 참조로 남는다.

따라서 도면틀을 더블클릭했을 때 `GMPOWEREDIT`, `REFEDIT`, block 관련 편집이 나오는 것 자체는 실패 증거가 아니다.

GMTITLE의 표 편집창 확인 대상은 도면틀이 아니라 짝이 되는 제목블록 `DR_titlea_3rd`다.

현재 로그도 같은 안내를 출력한다.

```text
수동 확인 규칙: DR_A*_Outline 도면틀이 아니라 DR_titlea_3rd 제목블록을 더블클릭하세요.
짝 제목블록이 정상이어도 도면틀을 더블클릭하면 GMPOWEREDIT/REFEDIT가 열릴 수 있습니다.
참고: native GMTITLE 도면틀도 DR_A*_Outline INSERT/block 참조로 남습니다.
```

## 저장된 기본 작업복사본 상태

최근 저장 상태 probe:

```text
work/swcad_title_fast_status_last_save_state_260705.txt
work/swcad_title_verify_summary_last_save_state_260705.txt
work/swtitle_actual_workcopy_status_save_state_260705.txt
```

확인 결과:

```text
DBMOD before commands: 0
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
```

즉 저장된 기본 작업복사본은 아직 변환 전 상태다.

화면에서 보였던 A2/A3 일부 변환 결과는 저장되지 않은 CAD 세션이었거나, probe용 복사본 로그에 남은 상태로 봐야 한다.

## 변환 후 probe 로그 상태

변환 후 상태에 가까운 로그:

```text
work/swcad_title_native_frame_check_last_a4_preflight_260705.txt
work/swcad_title_gmtitle_verify_all_last_a4_preflight_260705.txt
work/swcad_title_double_click_check_last_a4_preflight_260705.txt
work/swcad_title_verify_summary_last_a4_preflight_260705.txt
```

핵심 수량:

```text
대상 도면틀 수: 13
대상 제목블록 수: 13
도면틀/제목블록 쌍 수: 13
용지별 대상 도면틀 수:
  A2: 1
  A3: 12
대상 도면틀 수량 부족:
  A4: 필요 2, 현재 0
남은 원본 도면틀 후보: 2
남은 원본 표제란 후보: 0
```

A3 구조:

```text
용지별 native-like 대상 도면틀 수:
  A2: 1
  A3: 2
용지별 복제 대상 도면틀 수:
  A3: 9
native-link 공유 쌍: 1
A3/A4 native 교체 필요 쌍: 10
```

결과:

```text
WARN_CLONED_GMTITLE_FRAME_NEEDS_NATIVE_UPGRADE
WARN_SHARED_NATIVE_GMTITLE_LINKS
NEEDS_NATIVE_A3A4_UPGRADE
SWTITLEVERIFY_FINAL_FAIL
```

## 결론

현재 A3 문제는 두 층으로 나뉜다.

### 1. 도면틀이 block처럼 선택되는 현상

이것만으로는 실패가 아니다.

native GMTITLE 도면틀도 `DR_A*_Outline` INSERT/block 참조로 남을 수 있다.

따라서 "도면틀을 더블클릭했더니 표 편집창이 아니라 블록 편집처럼 열린다"는 것은 정상 native GMTITLE에서도 발생할 수 있다.

검증은 도면틀이 아니라 `DR_titlea_3rd` 제목블록을 더블클릭해서 해야 한다.

### 2. A3 중 일부가 native-like가 아닌 현상

이것은 실제 미완료 문제다.

로그 기준으로 A3 12장 중:

```text
native-like A3: 2
복제 A3: 9
shared-native-link A3: 1
```

즉 A3 10장은 겉보기 도면틀/제목블록/속성값은 맞아도 GstarCAD native 편집기 인식이 증명되지 않았다.

이 상태에서는 더블클릭이 GMTITLE 표 편집창이 아니라 고급 속성 편집기나 REFEDIT 쪽으로 떨어질 수 있다.

## 왜 복제본이 문제가 되는가

복제 방식은 기존 native GMTITLE 쌍의 보이는 형상과 xdata를 복사한다.

하지만 로그에서는 여러 복제 제목블록이 같은 내부 native 인식 handle을 공유하는 것으로 나온다.

```text
같은 native 인식 handle을 공유하는 제목블록: 10
shared-native-link=yes
accepted-pair=no
```

따라서 복제본은 "보이는 객체"는 맞지만, GstarCAD가 각각을 독립된 GMTITLE 객체로 믿는지는 보장되지 않는다.

현재 코드가 `native-like` 인정 기준에서 이런 쌍을 탈락시키는 이유도 여기에 있다.

## 다음 작업 방향

### A3

남은 A3는 새 복제 로직을 더 얹기보다, `SWTITLECONVERT`로 한 쌍씩 fresh native GMTITLE 결과로 교체하는 방향이 맞다.

성공 기준:

```text
A3/A4 native 교체 필요 쌍: 0
native-like A3: 12
shared-native-link 경고: 0
복제 A3: 0
대표 A3 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창
```

### A4

A4는 아직 target 자체가 없다.

현재 변환 후 로그 기준:

```text
A4 필요 2, 현재 0
남은 원본 도면틀 후보: 2
```

A4는 A3 교체와 별개로 frame-only 정책을 확정해야 한다.

현재까지는 원본 A4에 표제란이 없으므로, 기본 정책은 "A4는 도면틀만 교체하고 제목블록은 만들지 않는다" 쪽이다.

다만 `DR_A4_Outline` 설치 원본 import/정규화 probe가 unsafe였으므로, 정상 native A4 기준 객체를 확보하기 전에는 A4를 batch로 밀어붙이면 안 된다.

## 사용자가 다음에 해야 하는 순서

현재 저장된 기본 작업복사본 기준으로는 다시 처음부터 시작하는 상태다.

따라서 CAD 화면에서 작업할 때는 먼저 저장 상태를 확인한다.

```text
SWTITLEVERSION
SWTITLESTATUS
```

그 다음 `SWTITLESTATUS`가 안내하는 다음 작업만 실행한다.

```text
SWTITLECONVERT
```

GMTITLE 창이 열리면:

```text
용지: 안내된 DR_A*_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

한 장 처리 후:

```text
SWTITLESTATUS
```

반복 처리 전에는:

```text
SWTITLEVERIFY
```

최종 완료 전에는 다음을 만족해야 한다.

```text
SWTITLEVERIFY_FINAL_OK
A2 target: 1
A3 target: 12
A4 target: 2
남은 원본 표제란: 0
남은 원본 도면틀: 0
A3/A4 native 교체 필요 쌍: 0
대표 제목블록 더블클릭 확인 완료
```
