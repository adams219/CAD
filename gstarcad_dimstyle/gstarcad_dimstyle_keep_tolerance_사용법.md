# GstarCAD SolidWorks DWG 정리 도구

대상 파일:

```text
gstarcad_dimstyle\gstarcad_dimstyle_keep_tolerance.lsp
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
