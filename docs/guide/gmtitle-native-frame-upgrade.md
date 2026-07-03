# GMTITLE 변환 가이드

이 문서는 SolidWorks에서 저장한 DWG의 도면틀/표제란을 GstarCAD Mechanical
`GMTITLE` 기반 도면틀/표제란으로 바꾸는 현재 사용 흐름만 정리한다.

## 목표

- 원본 SolidWorks 도면틀과 표제란을 DR 계열 GstarCAD Mechanical GMTITLE로 교체한다.
- 기존 표제란의 텍스트 값은 새 `DR_titlea_3rd` 속성값으로 복사한다.
- A2/A3/A4 시트 크기는 자동 감지한다.
- 최종 표제란 더블클릭 시 `GMPOWEREDIT`, `REFEDIT`, 고급 속성 편집기가 아니라 GMTITLE 표 편집창이 열려야 한다.

## 최신 LSP 로드

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

버전 확인:

```text
SWTITLEVERSION
```

현재 정리된 버전:

```text
260702-command-surface-cleanup-1
```

## 기본 흐름

먼저 작업복사본을 연다. 원본 DWG에서 바로 실행하지 말고
`C:\Users\DR-DESIGN\Documents\CAD tool\work` 아래 복사본에서 검증한다.

```text
SWTITLEMULTIPREVIEW
SWTITLEFASTSTATUS
```

첫 native GMTITLE이 없으면:

```text
SWTITLETRANSFERBOOTSTRAPFAST
```

GMTITLE 대화창이 뜨면 로그에 나온 DR 용지와 `DR_titlea_3rd`를 선택한다.

```text
Frame positioning: ON
Object move: OFF
```

남은 일반 title sheet를 빠르게 처리한다.

```text
SWTITLETRANSFERFASTBATCH
```

A4처럼 원본 표제란 없이 도면틀만 있는 시트가 남으면:

```text
SWTITLEFRAMEONLYAPPLY
```

## A3/A4 native 교체

빠른 변환은 시각적 결과와 속성값은 맞추지만, 일부 복제본은 더블클릭 인식이 native GMTITLE처럼 동작하지 않을 수 있다.
그 경우 남은 후보를 실제 GMTITLE 결과로 다시 교체한다.

한 장씩:

```text
SWTITLEA3A4NEXT
```

남은 후보 전체:

```text
SWTITLEA3A4ALL
```

대화창에서 반드시 로그에 나온 용지를 고른다.

```text
A2: DR_A2_Outline
A3: DR_A3_Outline
A4: DR_A4_Outline
Title block: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

주의: A4를 처리할 때 `DR_A3_Outline`을 고르면 명령은 안전하게 중단한다.
이 경우 기존 A4는 유지되므로 다시 `SWTITLEA3A4NEXT`를 실행하고 `DR_A4_Outline`을 고르면 된다.

## 상태 확인

남은 native 교체 후보:

```text
SWTITLEUPGRADENATIVESTATUS
```

전체 상태를 한 번에 갱신:

```text
SWTITLESTATUSREFRESH
```

최종 검증:

```text
SWTITLEGMTITLEVERIFYALL
SWTITLENATIVEFRAMECHECK
SWTITLEDOUBLECLICKCHECK
```

좋은 상태의 핵심 조건:

```text
Remaining source title candidates: 0
Remaining source sheet frame candidates: 0
Other non-target title-like inserts: 0
A3/A4 target pairs needing native replacement: 0
```

마지막으로 CAD 화면에서 A2, A3, A4 대표 `DR_titlea_3rd` 표제란을 더블클릭한다.
도면틀 `DR_A*_Outline`은 정상이어도 블록으로 잡힐 수 있으므로 반드시 표제란 영역을 확인한다.

## 문제 해결

명령어가 도면에 흰 글자로 남은 것 같으면:

```text
SWTITLECOMMANDTEXTSCAN
```

작업복사본에서 실제 명령 잔여물이라고 확인되면:

```text
SWTITLECOMMANDTEXTCLEANSAFE
```

특정 표제란이 여전히 `GMPOWEREDIT`나 고급 속성 편집기로 열리면:

```text
SWTITLEPICKCHECK
```

문제 표제란 또는 도면틀을 선택해 원인을 확인한다.

## 정리된 공개 명령

자세한 명령어 목록과 제거된 테스트 명령은 아래 문서를 본다.

```text
docs/guide/commands.md
```
