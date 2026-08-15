# A4 세로 도면틀 BoundingBox 문제 기록

## 요약

2026-07-09에 `GSA4GO`로 모델공간 도면틀을 배치 탭으로 만들 때, A4 세로 도면틀이 이상하게 출력되는 문제가 있었다.

처음에는 A4 세로 도면틀 자체가 잘못된 크기처럼 보였지만, 실제 도면틀 치수는 `210 x 297`이 맞았다. 근본 원인은 A4 도면틀 블록 내부에 불필요한 선/객체가 남아 있어서, GstarCAD가 LSP에 넘기는 객체 `BoundingBox`가 `210 x 297`이 아니라 `266.25 x 297`로 커져 있었던 것이다.

`gstarcad_layout_from_model.lsp`는 선택한 프레임 객체의 `vla-getBoundingBox` 값을 그대로 배치 뷰포트 창으로 사용한다. 따라서 블록 내부의 숨은 객체, 남은 선, 잘못 들어간 구성선 등이 도면틀 밖으로 튀어나와 있으면 실제 보이는 프레임 크기보다 큰 창을 만들게 된다.

## 발생 증상

A4 세로 도면틀은 화면상 `210 x 297`처럼 보였지만, `GSA4GO` 감지 로그는 아래처럼 나왔다.

```text
Frame sample 2: size 266.25 x 297, LL (420, 0), UR (686.25, 297)
```

감지된 전체 결과도 A4 세로 3장이 모두 `266.25 x 297`로 잡혔다.

```text
Detected sheet frame count: 4
  01: size 420 x 297, LL (0, 0), UR (420, 297)
  02: size 266.25 x 297, LL (420, 0), UR (686.25, 297)
  03: size 266.25 x 297, LL (630, 0), UR (896.25, 297)
  04: size 266.25 x 297, LL (840, 0), UR (1106.25, 297)
```

이 상태에서 만든 배치에서는 A4 세로 도면 하나만 보여야 하는데, 오른쪽 옆 도면틀 일부가 같이 보였다.

## 왜 옆 도면이 같이 보였나

정상 A4 세로 창은 아래처럼 잡혀야 한다.

```text
SHEET-002: LL (420, 0), UR (630, 297)
SHEET-003: LL (630, 0), UR (840, 297)
SHEET-004: LL (840, 0), UR (1050, 297)
```

하지만 문제가 있을 때는 `SHEET-002` 창이 아래처럼 잡혔다.

```text
SHEET-002: LL (420, 0), UR (686.25, 297)
```

다음 도면틀은 `X = 630`부터 시작하므로, `SHEET-002` 뷰포트가 오른쪽으로 `56.25`만큼 더 넓게 잡히면서 다음 도면틀 일부가 같이 들어왔다.

```text
잘못 감지된 오른쪽 끝: 686.25
다음 도면틀 시작 X: 630
겹치는 폭: 56.25
```

## 원인

블록 편집에 들어가 확인했을 때 A4 용지 쪽에 선 같은 불필요한 객체가 있었다. 이 객체를 지운 뒤 같은 `GSA4GO` 흐름을 다시 실행하자 A4 세로 샘플이 정상 크기로 잡혔다.

수정 전:

```text
Frame sample 2: size 266.25 x 297, LL (420, 0), UR (686.25, 297)
```

블록 편집에서 불필요한 객체 삭제 후:

```text
Frame sample 2: size 210 x 297, LL (420, 0), UR (630, 297)
```

따라서 이 문제는 A4 용지 설정이나 플롯 회전 문제가 아니라, 선택된 A4 도면틀 블록의 실제 CAD extents가 오염된 문제였다.

## 정상 확인 로그

불필요한 선/객체를 지운 뒤 `GSA4GO` 감지 결과는 아래처럼 정상화됐다.

```text
Detected sheet frame count: 4
  01: size 420 x 297, LL (0, 0), UR (420, 297)
  02: size 210 x 297, LL (420, 0), UR (630, 297)
  03: size 210 x 297, LL (630, 0), UR (840, 297)
  04: size 210 x 297, LL (840, 0), UR (1050, 297)
```

`GSA4VERIFY` 결과도 정상이다.

```text
Layout SHEET-002
  Media: ISO full bleed A4 (210.00 x 297.00 MM)
  Plot rotation: 0
  Layout paper size: 210 x 297 (portrait)
  Viewports: 1
    VP 2: paper 210 x 297, view center (525, 148.5), view size 210 x 297, scale 1, orientation OK

Layout SHEET-003
  Media: ISO full bleed A4 (210.00 x 297.00 MM)
  Plot rotation: 0
  Layout paper size: 210 x 297 (portrait)
  Viewports: 1
    VP 2: paper 210 x 297, view center (735, 148.5), view size 210 x 297, scale 1, orientation OK

Layout SHEET-004
  Media: ISO full bleed A4 (210.00 x 297.00 MM)
  Plot rotation: 0
  Layout paper size: 210 x 297 (portrait)
  Viewports: 1
    VP 2: paper 210 x 297, view center (945, 148.5), view size 210 x 297, scale 1, orientation OK
```

핵심 확인값:

```text
view size 210 x 297
scale 1
orientation OK
```

## 재발 시 확인 순서

1. `GSA4GO`를 실행하고 A4 세로 샘플 로그를 본다.
2. 아래처럼 나오면 정상이다.

```text
Frame sample: size 210 x 297
```

3. 아래처럼 폭이 `210`보다 크게 나오면 블록 내부 extents 오염을 의심한다.

```text
Frame sample: size 266.25 x 297
```

4. 해당 A4 도면틀 블록을 `BEDIT`로 열어 `ZOOM EXTENTS` 또는 눈검사로 틀 밖 객체를 확인한다.
5. 불필요한 선, 점, wipeout, 텍스트, 속성, 구성선, 숨은 객체가 있으면 삭제한다.
6. `BCLOSE`로 저장 후 `GSA4CLEAN`, `GSA4GO`, `GSA4VERIFY`를 다시 실행한다.

## LSP 관점

현재 LSP의 동작은 다음 기준이다.

```lisp
(vla-getBoundingBox obj 'mn 'mx)
```

즉 LSP는 사람이 보는 초록 치수 `210 x 297`을 직접 읽는 것이 아니라, 선택 객체가 GstarCAD에 보고하는 전체 바운딩박스를 읽는다.

이번 문제에서 LSP는 잘못된 용지 방향을 선택한 것이 아니라, GstarCAD가 제공한 `266.25 x 297` 바운딩박스를 그대로 신뢰했다. 블록 내부 객체를 정리하자 같은 LSP가 즉시 `210 x 297`로 정상 감지했으므로, 이 케이스의 직접 원인은 LSP 코드가 아니라 A4 도면틀 블록 내부의 불필요한 객체였다.

## 예방

- A4/A3/A2 도면틀 블록을 만들거나 수정한 뒤에는 `GSA4GO`의 `Frame sample` 크기 로그를 먼저 확인한다.
- A4 세로는 `210 x 297`, A3 가로는 `420 x 297`처럼 의도한 크기와 로그가 일치해야 한다.
- 블록 편집 후에는 `ZOOM EXTENTS`로 틀 밖에 남은 객체가 없는지 확인한다.
- 도면틀 블록 안에 작업용 선이나 임시 치수선을 남기지 않는다.
- 같은 증상이 반복되면 LSP에 `BoundingBox` 경고 진단을 추가하는 것을 검토한다.
