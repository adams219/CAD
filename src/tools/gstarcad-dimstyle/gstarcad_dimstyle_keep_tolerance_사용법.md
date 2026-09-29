# GstarCAD SolidWorks DWG 정리 도구

대상 파일:

```text
src\tools\gstarcad-dimstyle\gstarcad_dimstyle_keep_tolerance.lsp
```

## 평소 사용 순서

파일이 어느 정도 검증되었다면 아래처럼 사용합니다.

```text
APPLOAD
SWAUTO
GMPOWEREDIT
QSAVE
```

`SWAUTO`는 현재 탭의 치수에 대해 다음 작업을 한 번에 실행합니다.

```text
1. 일반 치수 스타일  -> AM_ISO$0 우선, 없으면 AM_ISO, ISO-25, AM_ISO$3 순서
2. 지름 치수 스타일  -> AM_ISO$3 우선, 없으면 사용 가능한 AM_ISO 계열
3. REGENALL
4. H7, h6, H9 같은 맞춤공차를 GstarCAD Mechanical 맞춤공차 데이터로 변환
5. REGENALL, 최종 감사, 사용하지 않는 SolidWorks 치수스타일 정리
```

명령창 마지막에 아래가 나오면 정상 기준입니다.

```text
SWAUTO RESULT: OK
```

중간에 아래 감사 로그도 같이 확인합니다.

```text
Final audit: dimension styles after SWAUTO
Normal dimensions (AM_ISO): 62, target-style matches: 62
Diameter dimensions (AM_ISO$3): 81, target-style matches: 81
Style mismatches: 0

Final audit: Mechanical fit data after SWAUTO
Dimensions with tolerance values: ...
Dimensions with Mechanical fit data: ...
Residual embedded fit-code dimensions: 0
```

`Style mismatches`가 0이 아니면, 일반 치수나 지름 치수 중 일부가 목표 스타일로 남지 않은 것입니다. `Residual embedded fit-code dimensions`가 0이 아니면, H7/h6 같은 맞춤공차 코드가 Mechanical 데이터로 변환되지 않고 치수 문자 안에 남은 것입니다. 이 경우 표시된 예시 핸들을 기준으로 `SWDEBUG`를 실행합니다.

그 뒤 `GMPOWEREDIT`로 대표 치수 몇 개만 확인하고 저장합니다.

## 치수 값 보존 검사

`SWAUTO`는 실행 전에 현재 탭의 모든 치수 값을 기록해 두고, 4단계가 끝난 뒤 다시 비교합니다. 비교하는 값은 측정값, `DIMLFAC`, 위·아래 공차, 공차 표시(`DIMTOL`), 한계 표시(`DIMLIM`), 소수 자리(`DIMDEC`), 반올림(`DIMRND`), 각도 소수 자리(`DIMADEC`)입니다.

출력 예:

```text
--- 치수 값 보존 검사: SWAUTO 전후 비교 ---
  검사한 치수: 23개
  변화 없음: 21개
  맞춤공차 변환으로 공차 표시가 Mechanical 방식으로 바뀐 치수: 2개 (기존 SWAUTO 동작, 되돌리지 않음)
  달라져서 되돌린 치수: 0개
  화면에 보이는 숫자: 모두 같음
  치수 값 보존: OK
```

- `화면에 보이는 숫자`는 치수 블록에 실제로 그려진 첫 숫자를 실행 전후로 비교한 결과입니다. 다르면 `확인 필요: 화면에 보이는 숫자가 바뀐 치수`와 핸들이 나오고, 자동으로 되돌리지 않습니다.
- `SolidWorks 지름(중심선 거리 x2) 표시를 살리려고 DIMLFAC x2를 넣은 치수`: SolidWorks는 중심선까지 거리를 두 배로 해서 지름으로 보여 주는 치수가 있습니다(거리 34를 `Ø68`로 표시). DWG에는 이 배율이 없어서 GstarCAD가 다시 그리면 `Ø34`가 되므로, SWAUTO가 DIMLFAC 2를 넣어 `Ø68`로 되돌립니다. 이 보정은 SWAUTO를 단독으로 쓸 때만 유지됩니다. 통합 워크플로(`SWCADRUN`)에서는 워크플로 자체 비교가 DIMLFAC 변화를 원래 값으로 되돌리기 때문에 아직 유지되지 않습니다.
- `SolidWorks가 반올림해 그린 숫자를 실제 값으로 보이는 치수`: SolidWorks가 DWG 설정보다 적은 소수 자리로 그린 치수입니다(그려진 글자 `17`, 실제 값 17.3, `DIMDEC` 2). 다시 그리면 실제 값 `17.3`이 보이며, 사용자 결정(2026-09-29, 탭 드릴 `Ø3.3`과 같은 방향)에 따라 정상으로 보고 목록만 남깁니다. SWAUTO가 `DIMLFAC`나 소수 자리 설정을 바꾸지 않았고, 새 숫자를 원래 자리수로 반올림하면 원래 숫자가 될 때만 해당합니다. 그 밖의 숫자 변화는 계속 `확인 필요`입니다.
- `달라져서 되돌린 치수`가 있으면 SWAUTO가 원래 값으로 되돌린 것입니다. `변화 예`에 핸들과 바뀌었던 값이 나옵니다.
- `확인 필요`가 나오면 자동으로 되돌리지 않은 치수입니다. 맞춤공차 치수의 값이 바뀌었거나 치수를 찾지 못한 경우이고, 결과는 `SWAUTO RESULT: CHECK NEEDED`가 됩니다. 표시된 핸들의 치수를 `SWDEBUG`로 확인합니다.
- 공차가 없는 치수도 `DIMLFAC`(상세도 축척 등), 공차 꺼짐 상태, 소수 자리를 그대로 유지합니다. 1단계 로그의 `Dimensions keeping DIMLFAC/tolerance-off values`가 이렇게 처리한 치수 수입니다.
- 0 생략(`DIMZIN`)은 목표 스타일을 따릅니다. SolidWorks 스타일 값을 그대로 쓰면 `0.5`가 `.5`로 바뀌기 때문입니다.
- 위아래 공차의 부호가 같은 맞춤공차(D10, F7, G7, f7, g6, k6, m6, p6 등)도 원래 부호대로 표시합니다. 예: `4 D10`은 `+0.078 / +0.03`.
- 맞춤공차로 바꿀 때 `3-Ø8 H7 Hole DP3`의 `3-`, `Hole DP3` 같은 앞뒤 글자를 남깁니다.
- 축척 뷰(DIMLFAC가 1이 아닌 뷰)의 맞춤공차도 화면 숫자를 기준 치수로 씁니다. 예전에는 2:1 뷰의 `Ø4 D10`이 기준 치수 2로 저장됐습니다.

## 사용하지 않는 치수스타일 정리

`SWAUTO`는 마지막 단계에서 사용하지 않는 SolidWorks 치수스타일을 자동으로 정리합니다.

로그 기준은 다음과 같습니다.

```text
--- Step 5/5: Cleanup unused SOLIDWORKS dimension styles ---
Purged unused dimension styles: ...
ActiveX-deleted leftover SLD styles: ...
ActiveX-delete failed/referenced: 0
Remaining SLD style definitions: 0
```

평소에는 별도 정리 명령을 실행하지 않아도 됩니다.

수동으로 정리만 다시 하고 싶을 때는 아래 명령을 사용합니다.

```text
SWPURGESTYLES
```

이 명령은 CAD의 purge 기능을 이용해서 **사용 중이 아닌 치수스타일만** 삭제합니다. 현재 치수가 사용 중인 스타일과 GstarCAD 기본 스타일은 삭제되지 않습니다.

정상 기준:

```text
Purged unused dimension styles: 1 이상
```

삭제되지 않는 스타일이 있다면 아직 어떤 치수, 블록, 또는 배치 객체가 그 스타일을 사용 중이거나 CAD 내부에서 참조 중이라고 판단하는 상태입니다. 이 경우 `SWAUTO`를 먼저 다시 실행하고, 최종 감사에서 `Style mismatches: 0`인지 확인합니다.

그래도 `SLDDIMSTYLE` 계열이 남아 있다면 어디서 쓰이는지 먼저 찾습니다.

```text
SWFINDSTYLE
```

프롬프트가 나오면 그냥 Enter를 누르면 기본값 `*SLDDIMSTYLE*`로 검색합니다.

```text
Dimension style wildcard <*SLDDIMSTYLE*>:
```

결과 해석은 다음과 같습니다.

```text
Matching dimension style definitions
```

도면 안에 남아 있는 치수스타일 이름 목록입니다.

```text
Matching top-level/layout dimensions
```

모델/배치에 직접 놓인 치수 중 해당 스타일을 쓰는 개수입니다. 현재 탭에 있는 치수는 자동으로 선택됩니다.

```text
Matching dimensions inside block definitions
```

블록 정의 안쪽에 숨어 있는 치수 개수입니다. 이 경우 현재 화면에서 바로 선택되지는 않으므로, 로그의 `block=...` 이름을 보고 해당 블록을 확인합니다.

```text
Current DIMSTYLE
```

현재 치수스타일입니다. 이 값이 `SLDDIMSTYLE`이면 실제 치수가 쓰지 않아도 CAD가 purge를 거부할 수 있으므로, `DIMSTYLE`에서 현재 스타일을 `AM_ISO` 또는 `AM_ISO$3`로 바꾼 뒤 다시 `SWPURGESTYLES`를 실행합니다.

```text
Deep reference scan
```

치수 객체가 아닌 일반 객체와 접근 가능한 딕셔너리 쪽에서 `SLDDIMSTYLE` 이름이나 치수스타일 레코드 포인터를 찾습니다. GstarCAD가 일부 내부 테이블 접근을 막을 수 있으므로, 이 값은 “안전하게 확인 가능한 범위”의 결과입니다.

여기서 `References found`가 1 이상이면 아래 `Deep examples` 줄이 실제 단서입니다. `References found: 0`이면 보이는 객체에는 물려 있지 않은 상태이므로 `AUDIT`, 저장 후 다시 열기, `SWPURGESTYLES` 순서로 다시 정리합니다.

권장 정리 순서:

```text
AUDIT
Y
-PURGE
Regapps
*
No
SWPURGESTYLES
QSAVE
파일 닫기
다시 열기
SWPURGESTYLES
SWFINDSTYLE
```

그래도 `SLDDIMSTYLE` 정의가 남아 있고 정말 삭제를 시도하고 싶다면 아래 명령을 사용합니다.

```text
SWTRYDELDIMSTYLES
```

프롬프트에서 Enter를 누르면 기본값 `*SLDDIMSTYLE*`로 시도합니다.

```text
Dimension style wildcard to try-delete <*SLDDIMSTYLE*>:
```

이 명령은 `entdel`로 강제 삭제하지 않습니다. GstarCAD의 ActiveX `Delete` 기능을 사용하므로, 아직 내부 참조가 있으면 `FAIL`로 남고 도면을 억지로 건드리지 않습니다.

정상 삭제 예:

```text
DELETED: SLDDIMSTYLE0
DELETED: SLDDIMSTYLE1
```

참조가 남아 있을 때:

```text
FAIL: SLDDIMSTYLE0 / ...
```

실패한 스타일은 강제로 지우지 말고 남겨둡니다. 실제 치수가 사용하지 않는다면 표시나 출력에는 영향이 없습니다.

수동으로 할 때는 다음 명령도 가능합니다.

```text
-PURGE
Dimstyles
*
No
```

`No`는 중첩 항목까지 무리하게 정리하지 않는 선택입니다. 치수스타일만 정리한 뒤 필요하면 별도로 블록, 선종류, 문자스타일 purge를 진행합니다.

## 문제 있을 때

디버깅 명령은 하나만 기억하면 됩니다.

```text
SWDEBUG
```

치수 하나를 선택하면 아래 정보를 한 번에 보여줍니다.

```text
Target AM_ISO style
Diameter dimension detected
Dimension fit parser
Tolerance upper / lower
Raw measurement
DIMLFAC
Scaled measurement for Mechanical fit
DIMSCALE / DIMTXT / DIMASZ / DIMGAP
```

더 깊게 확인해야 하면 `SWDEBUG` 마지막 질문에서 덤프 저장을 `Yes`로 선택합니다.

```text
Save detailed DXF/xdata dump for this dimension? [Yes/No] <No>: Yes
```

## 필요할 때만 쓰는 수동 단계 명령

`SWAUTO` 대신 단계별로 처리하고 싶을 때만 사용합니다.

```text
SWDIMKEEPAMISO
REGENALL
SWMECHFITSEL
GMPOWEREDIT
SWMECHFITALL
REGENALL
GMPOWEREDIT
```

각 명령의 역할은 다음과 같습니다.

```text
SWDIMKEEPAMISO
```

현재 탭의 모든 치수 스타일을 정리합니다.

```text
일반 치수 -> AM_ISO$0 우선, 없으면 AM_ISO, ISO-25, AM_ISO$3 순서
지름 치수 -> AM_ISO$3 우선, 없으면 사용 가능한 AM_ISO 계열
```

기존 공차값과 `DIMLFAC` 치수 축척값은 보존합니다.

반대로 `DIMTXT`, `DIMASZ`, `DIMGAP`처럼 화면 크기를 들쭉날쭉하게 만드는 표시 크기 override는 보존하지 않습니다. 이 값들은 대상 치수스타일의 정상 문자 높이, 화살표 크기, 간격을 따라가게 됩니다.

도면마다 치수스타일 이름이 조금 다를 수 있습니다. 예를 들어 어떤 파일은 `AM_ISO$0`이 없고 `AM_ISO` 또는 `AM_ISO$3`만 있을 수 있습니다. 이 경우 `SWAUTO`는 멈추지 않고 사용 가능한 AM_ISO 계열 스타일을 일반 치수 스타일로 사용합니다.

```text
REGENALL
```

치수스타일 변경 뒤 화면과 치수 표시를 다시 계산합니다. 스타일 변경 후에는 한 번 실행하는 것이 좋습니다.

```text
SWMECHFITSEL
```

선택한 치수만 Mechanical 맞춤공차로 변환합니다. 전체 적용 전에 대표 치수 1~2개로 먼저 확인할 때 사용합니다.

```text
GMPOWEREDIT
```

`SWMECHFITSEL`로 변환한 치수를 열어서 맞춤 기호가 제대로 인식되는지 확인합니다.

확인 기준:

```text
기호(S): H7, h6, H9 등으로 표시됨
정확한 거리 값이 DIMLFAC 축척을 반영함
상한/하한 공차값이 기존 표시와 맞음
```

```text
SWMECHFITALL
```

현재 탭의 모든 대상 치수를 Mechanical 맞춤공차로 변환합니다. `SWMECHFITSEL`과 `GMPOWEREDIT` 확인이 끝난 뒤 실행하는 것이 안전합니다.

마지막으로 다시 실행합니다.

```text
REGENALL
GMPOWEREDIT
```

평소에는 이 명령들을 따로 외울 필요 없이 `SWAUTO`를 사용하면 됩니다.

## 최종 기억할 것

```text
APPLOAD -> SWAUTO -> GMPOWEREDIT 확인 -> QSAVE
문제 발생 -> SWDEBUG
```
