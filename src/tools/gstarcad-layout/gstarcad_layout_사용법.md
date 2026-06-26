# GstarCAD 배치 자동화 사용법

## 목적

모델 공간에 여러 도면 프레임을 한곳에 배치해 놓고 작업한 뒤, 각 프레임을 `SHEET-001`, `SHEET-002` 같은 배치 탭으로 자동 생성하기 위한 도구입니다.

기본 기준은 아래처럼 고정되어 있습니다.

- 플로터: `DWG To PDF.pc3`
- 용지: `ISO full bleed A4 (297.00 x 210.00 MM)`
- 플롯 스타일: `monochrome.ctb`
- 배치 이름: `SHEET-001`, `SHEET-002`, ...
- 기본 회전: `0`
- 배치/뷰포트 그리드: 꺼짐

## 로드 방법

GstarCAD 명령창에서:

```text
APPLOAD
```

아래 파일을 로드합니다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gstarcad-layout\gstarcad_layout_from_model.lsp
```

로드가 성공하면 명령창에 아래 5개 명령만 표시됩니다.

```text
GSA4CHECK, GSA4GO, GSA4VERIFY, GSA4CLEAN, GSA4PDF
```

## 기본 순서

처음 실행할 때:

```text
GSA4CHECK
GSA4GO
GSA4VERIFY
```

다시 만들 때:

```text
GSA4CLEAN
GSA4GO
GSA4VERIFY
```

PDF 출력까지 할 때:

```text
GSA4PDF
```

## 명령 설명

| 명령 | 용도 |
| --- | --- |
| `GSA4CHECK` | PDF 플로터, A4 용지, CTB, 회전값 확인 |
| `GSA4GO` | 프레임 하나를 선택해서 같은 가로줄의 프레임들을 자동 배치 생성 |
| `GSA4VERIFY` | 생성된 배치의 용지 크기, 뷰포트 크기, 스케일 확인 |
| `GSA4CLEAN` | 자동 생성된 `SHEET-*` 배치 삭제 |
| `GSA4PDF` | `SHEET-*` 배치를 개별 PDF로 출력 |

## 1. 출력 설정 확인

```text
GSA4CHECK
```

정상 예시:

```text
GstarCAD layout automation check
  Plotter: DWG To PDF.pc3
  A4 media: ISO full bleed A4 (297.00 x 210.00 MM)
  Plot style: monochrome.ctb
  Generated layout prefix: SHEET-001
  Plot rotation: 0
  Existing generated layouts: 0
```

여기서 `A4 media`가 `NOT FOUND`가 아니면 용지 설정은 정상입니다.

## 2. 배치 자동 생성

```text
GSA4GO
```

진행 방식:

1. 모델 공간에서 도면 프레임 또는 타이틀 블록 하나를 선택합니다.
2. 이 첫 번째 프레임의 Y 범위가 기준 가로줄이 됩니다.
3. 같은 줄에 프레임 이름이나 레이어가 다른 도면이 있으면 추가 프레임을 더 선택합니다.
4. 더 선택할 프레임이 없으면 Enter를 누릅니다.
5. 감지된 프레임 개수와 좌표가 명령창에 표시됩니다.
6. 목록이 맞으면 Enter 또는 `Yes`를 입력합니다.
7. `SHEET-001`, `SHEET-002`처럼 배치가 생성됩니다.

생성된 배치에서는 종이공간과 뷰포트 내부 모델공간의 `GRIDMODE`가 자동으로 꺼집니다.

원점 `0,0` 기준의 첫 번째 가로줄만 배치하려면 `LL (0,0)`에 있는 프레임을 첫 번째로 선택하세요. 그러면 첫 번째 프레임의 Y 범위와 겹치는 같은 줄의 프레임만 잡고, 위쪽 줄의 프레임은 제외합니다.

같은 가로줄 안에 프레임 이름이 다른 도면이 섞여 있다면 첫 프레임을 고른 뒤 아래 프롬프트에서 다른 프레임도 추가로 선택하세요.

```text
Additional frame object with another name/layer <Enter to continue>:
```

추가 선택한 프레임은 기준 가로줄이 아니라, 다른 이름/레이어의 프레임까지 포함하기 위한 샘플입니다. 기준 가로줄은 항상 첫 번째로 선택한 프레임의 Y 범위입니다.

A2, A3, A4처럼 서로 크기가 다른 프레임이 같은 가로줄에 섞여 있으면 A2, A3, A4 프레임을 각각 한 번씩 추가 선택하세요. 하단 Y값이 완전히 같지 않아도 첫 번째 프레임의 Y 범위와 충분히 겹치면 같은 줄로 인식합니다. 직접 샘플로 선택한 프레임 타입은 일반 A계열 비율이 아니어도, 같은 줄에서 비슷한 크기이면 포함합니다.

최근 A2/A3/A4 혼합 도면 기준으로는 추가 샘플을 모두 선택했을 때 명령창에 `Detected sheet frame count: 10`이 표시되는 것이 기대 결과입니다.

## 스케일 기준

자동화는 선택한 프레임 객체의 바운딩 박스를 기준으로 합니다.

```text
LL = 프레임 좌하단
UR = 프레임 우상단
```

이 두 점을 기준으로 각 배치의 뷰포트에서 `ZOOM Window`를 실행합니다. 그래서 사용자가 손으로 끝점에서 끝점까지 창을 잡아 배치하는 것과 같은 개념입니다.

예를 들어 프레임이 `420 x 297`이고 A4 용지가 `297 x 210`이면:

```text
scale = 297 / 420 = 0.7071
```

즉 A3 크기의 도면 프레임을 A4 용지에 맞춰 약 `70.71%`로 줄여서 배치합니다. 모델 공간의 실제 치수값은 바뀌지 않습니다.

## 3. 생성 결과 검증

```text
GSA4VERIFY
```

정상 예시:

```text
Layout SHEET-001
  Media: ISO full bleed A4 (297.00 x 210.00 MM)
  Plot rotation: 0
  Layout paper size: 297.0000 x 210.0000 (landscape)
  Viewports: 1
    VP 2: paper 297.0000 x 210.0000, view center (...), view size 420.0000 x 297.0000, scale 0.7071, orientation OK
```

스케일이 중요한 도면에서는 아래를 꼭 확인하세요.

- `view size`가 원래 프레임 크기와 맞는지
- `scale`이 예상값인지
- 각 `SHEET-*`의 `view center`가 서로 다른지
- `orientation OK`로 표시되는지

## 4. 자동 생성 배치 삭제

```text
GSA4CLEAN
```

`GSA4CLEAN`은 자동 생성된 `SHEET-*` 배치만 삭제합니다. `모델` 탭이나 사용자가 다른 이름으로 만든 배치는 건드리지 않습니다.

잘못 생성했을 때는 보통 아래 순서로 다시 만듭니다.

```text
GSA4CLEAN
GSA4GO
GSA4VERIFY
```

## 5. PDF 출력

배치가 맞게 만들어졌다면:

```text
GSA4PDF
```

출력 폴더를 확인한 뒤 `Yes`를 입력하면 `SHEET-001.pdf`, `SHEET-002.pdf`처럼 개별 PDF가 생성됩니다.

## 문제 확인

### 모든 배치가 같은 위치를 보는 경우

최신 Lisp를 다시 `APPLOAD` 한 뒤 아래 순서로 다시 생성하세요.

```text
GSA4CLEAN
GSA4GO
GSA4VERIFY
```

`GSA4VERIFY`에서 각 `SHEET-*`의 `view center`가 서로 달라야 정상입니다.

### 프레임 개수가 다르게 잡히는 경우

선택한 프레임과 같은 레이어에 비슷한 크기의 프레임만 있어야 합니다. 다른 객체가 같은 레이어에 있거나, 프레임 블록의 바운딩 박스가 실제 외곽보다 크면 감지가 달라질 수 있습니다.

### 스케일이 의심되는 경우

`GSA4VERIFY`의 `view size`와 `scale`을 확인하세요. `420 x 297` 프레임을 A4로 배치하면 `scale 0.7071` 근처가 정상입니다.

## 권장 작업 흐름

```text
APPLOAD
GSA4CHECK
GSA4CLEAN
GSA4GO
GSA4VERIFY
GSA4PDF
```

매번 PDF를 바로 출력하기보다, 먼저 `GSA4VERIFY`로 스케일과 뷰포트 위치가 맞는지 확인하는 것을 권장합니다.
