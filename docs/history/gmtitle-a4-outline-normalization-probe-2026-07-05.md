# GMTITLE A4 Outline Normalization Probe - 2026-07-05

## 목적

`DR_A4_Outline` 정의의 raw 선택 범위가 너무 커서 A4 frame-only 변환을 막고 있다.

이번 probe의 목적은 단순한 정의 정리 방식으로 이 문제를 해결할 수 있는지 확인하는 것이다.

중요한 전제:

- 실제 업무 DWG는 수정하지 않는다.
- `work` 폴더의 복사본 DWG에서만 실행한다.
- 결과가 통과하지 않으면 `SWTITLEPREPARE`나 `SWTITLECONVERT` 생산 흐름에 넣지 않는다.

## 추가된 진단 파일

```text
diagnostics/gmtitle-main45/a4_outline_normalization_probe.lsp
diagnostics/gmtitle-main45/run_a4_outline_normalization_probe.ps1
```

기본 실행 명령:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_a4_outline_normalization_probe.ps1
```

생성 로그:

```text
work/swtitle_a4_outline_norm_none_260705.txt
work/swtitle_a4_outline_norm_huge-insert_260705.txt
work/swtitle_a4_outline_norm_direct-outside_260705.txt
```

## 테스트한 전략

### 1. none

아무 것도 지우지 않고 설치 원본에서 가져온 `DR_A4_Outline` 정의를 그대로 검사했다.

결과:

```text
After definition raw bbox: (0, 0) - (872.26126377, 302.7)
After raw selection warning: raw CAD selection bbox is larger than the effective visible frame
After strict A4 raw match warning: raw bbox does not match the expected visible A4 frame
Normalization safe for A4 frame-only conversion: no
```

판단:

현재 설치 원본 `DR_A4_Outline`을 그대로 A4 frame-only 변환에 쓰면 안 된다.

### 2. huge-insert

A4 정의 안에서 면적이 매우 큰 child `INSERT`만 제거했다.

제거된 핸들:

```text
16E0F
```

결과:

```text
After definition raw bbox: (0, 0) - (266.25210777, 302.7)
After raw selection warning: <none>
After strict A4 raw match warning: raw bbox does not match the expected visible A4 frame
Normalization safe for A4 frame-only conversion: no
```

판단:

큰 child `INSERT` 하나를 지우면 과도한 raw bbox 경고는 줄어들지만, 여전히 A4 `(0,0)-(210,297)` 정의가 아니다.

이 상태를 안전하다고 판정하면 A4 시트 삭제/교체가 다시 잘못될 수 있다.

### 3. direct-outside

nominal A4 범위 밖에 걸친 direct child 객체를 모두 제거했다.

제거된 핸들:

```text
16E0F, 16E6A, 16E6B, 16E6F, 16E70
```

결과:

```text
After direct DR_A4_Outline records:
  POINT
  POINT
  TEXT
  TEXT
After definition raw bbox: (0, 0) - (83.9, 15.7)
After strict A4 raw match warning: raw bbox does not match the expected visible A4 frame
Normalization safe for A4 frame-only conversion: no
```

판단:

범위 밖 객체를 단순 삭제하면 A4 도면틀 자체가 사실상 사라지고 텍스트/포인트만 남는다.

이 방식은 절대 생산 변환에 넣으면 안 된다.

## 결론

세 전략 모두 A4 frame-only 변환용으로 안전하지 않다.

이번 probe의 중요한 성과는 A4를 고친 것이 아니라, 다음 잘못된 방향을 명확히 배제한 것이다.

```text
설치 원본 DR_A4_Outline 직접 사용: 불가
큰 INSERT 하나만 삭제: 불충분
A4 밖 direct 객체 전체 삭제: 도면틀 파괴
```

따라서 현재 guard는 유지해야 한다.

`WARN_A4_FRAME_ONLY_OUTLINE_DEFINITION_UNSAFE`, `ABORT_FRAME_DEFINITION_RAW_BBOX_RISK`, `ABORT_A4_FRAME_ONLY_OUTLINE_INVALID_GEOMETRY`가 나오면 기존 A4를 삭제하지 않는 것이 맞다.

## 다음 구현 방향

단순 삭제식 정규화는 중단한다.

다음 조사는 아래 순서가 맞다.

1. GstarCAD에서 실제 GMTITLE로 생성된 A4 outline-only 또는 A4 frame 구조를 확보한다.
2. 그 native A4 결과의 `DR_A4_Outline` definition, insert bbox, xdata, extension dictionary, reactors를 설치 원본 import 결과와 비교한다.
3. 설치 원본 `DR_A4_Outline`이 잘못된 것인지, import 방식이 잘못된 것인지, 또는 GstarCAD가 GMTITLE 실행 시 추가 정리를 하는지 분리한다.
4. 깨끗한 A4 outline 기준을 찾은 뒤에만 `SWTITLEPREPARE` 또는 `SWTITLECONVERT`에 A4 frame-only 변환을 다시 연결한다.

## 현재 목표 상태

A4는 아직 완료가 아니다.

최종 완료 조건은 여전히 아래와 같다.

```text
SWTITLEVERIFY_FINAL_OK
source title/frame/frame-only count = 0
target sheet counts: A2=1, A3=12, A4=2
A2/A3 대표 제목블록 더블클릭 시 GMTITLE 표 편집창
A4 frame-only는 제목블록 없이 DR_A4_Outline만 정상 bbox로 존재
```

