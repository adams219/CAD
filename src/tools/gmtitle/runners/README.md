# GMTITLE runner quick guide

이 폴더의 `.lsp` 파일은 GstarCAD에서 `APPLOAD`로 바로 실행하는 보조 파일이다.
모든 runner는 최신 `swcad_title_scale.lsp`를 다시 찾고, 버전이
`260702-a3a4-strict-native-recheck-3`인지 확인한 뒤 명령을 실행한다.

## 1. 먼저 상태만 확인

도면을 바꾸지 않고 최신 로그만 다시 만들려면:

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\runners\swtitle_guard4_status_refresh.lsp
```

확인할 로그:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_status_refresh_last.txt
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_native_upgrade_last.txt
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_gmtitle_verify_all_last.txt
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_native_frame_check_last.txt
```

## 2. A3/A4 후보만 보기

도면을 바꾸지 않고 A3/A4 재교체 후보만 확인하려면:

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\runners\swtitle_guard4_a3a4_fix_plan.lsp
```

`native-finalize`, `native-frame-only`, `clone`, `shared-native-link-handle`가 나오면
더블클릭 인식이 아직 확정되지 않은 후보로 본다.

## 3. 한 장만 교체

먼저 한 장만 실제 GMTITLE native 결과로 다시 만들려면:

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\runners\swtitle_guard4_a3a4_upgrade_next.lsp
```

GMTITLE 대화상자에서는 로그에 나온 `DR_A3_Outline` 또는 `DR_A4_Outline`과
`DR_titlea_3rd`를 선택한다.

## 4. 전체 후보 교체

한 장 테스트가 성공하면 전체 후보를 이어서 처리한다:

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\runners\swtitle_guard4_a3a4_upgrade_all.lsp
```

각 GMTITLE 대화상자에서:

```text
paper/frame: DR_A3_Outline 또는 DR_A4_Outline
title block: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

ISO 기본값이 보이면 그대로 확인하지 말고 취소한 뒤 다시 실행한다.

## 5. 최종 확인

다시 상태 확인 runner를 실행한 뒤, CAD 화면에서 `DR_titlea_3rd` 표제란을 더블클릭한다.
성공 기준은 `GMPOWEREDIT`나 `REFEDIT`가 아니라 GMTITLE 표 편집창이 열리는 것이다.

도면틀 `DR_A*_Outline`은 정상 상태여도 블록이므로 `GMPOWEREDIT`가 열릴 수 있다.
반드시 표제란 쪽을 더블클릭한다.

표제란을 더블클릭했는데도 `GMPOWEREDIT`나 `REFEDIT`가 열리면 아래 명령을 실행하고,
방금 실패한 표제란 또는 도면틀을 선택한다.

```text
SWTITLEPICKCHECK
```

`reason=finalize-or-frame-only-marker-needs-native-recheck`,
`reason=shared-native-link-handle`, `reason=clone`이 나오면 아직 native 교체가 필요한 상태다.
