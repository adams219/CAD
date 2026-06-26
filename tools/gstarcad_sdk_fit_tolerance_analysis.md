# GstarCAD SDK 맞춤공차 자동화 검토

## 확인한 SDK

```text
downloads\grxsdk_2024.zip
downloads\grxsdk_2024\grxsdk
```

공식 개발자 페이지의 `GstarCAD SDK` 링크에서 받은 `grxsdk_2024.zip`입니다.

SDK 구성은 일반 GstarCAD/AutoCAD 호환 개발용입니다.

```text
inc
inc-x64
lib-x64
arx
arx\samples
utils
```

## 우리가 찾던 것

목표는 SolidWorks DWG에서 분리되어 들어온 다음 상태를:

```text
DIMENSION: 47 +0.025 / 0
TEXT/MTEXT: H7
```

GstarCAD Mechanical 파워 치수 편집창의 다음 상태로 자동 변환하는 것입니다.

```text
맞춤 > 기호(S): H7
표시: 47 H7 (+0.025/0)
```

## SDK에서 찾은 것

### 1. 일반 치수 공차 API는 있음

`downloads\grxsdk_2024\grxsdk\inc-x64\gcdb.h`의 `IGcadDimension` 인터페이스에 일반 치수 공차 속성이 있습니다.

```text
get_TolerancePrecision / put_TolerancePrecision
get_ToleranceHeightScale / put_ToleranceHeightScale
get_ToleranceLowerLimit / put_ToleranceLowerLimit
get_ToleranceDisplay / put_ToleranceDisplay
get_ToleranceJustification / put_ToleranceJustification
get_ToleranceUpperLimit / put_ToleranceUpperLimit
get_TextOverride / put_TextOverride
get_TextPrefix / put_TextPrefix
get_TextSuffix / put_TextSuffix
get_StyleName / put_StyleName
```

관련 enum도 있습니다.

```text
GcDimToleranceMethod
  gcTolNone
  gcTolSymmetrical
  gcTolDeviation
  gcTolLimits
  gcTolBasic

GcDimToleranceJustify
  gcTolBottom
  gcTolMiddle
  gcTolTop
```

이것은 AutoCAD/GstarCAD 표준 `DIMENSION` 객체의 편차공차, 한계치수, 대칭공차 등을 다루는 API입니다.

### 2. LISP에서 쓰던 DIMSTYLE override에 해당하는 API도 있음

`downloads\grxsdk_2024\grxsdk\inc\dbdimvar.h`에 다음 값들이 있습니다.

```text
dimpost / setDimpost
dimapost / setDimapost
dimtol / setDimtol
dimlim / setDimlim
dimtp / setDimtp
dimtm / setDimtm
dimtfac / setDimtfac
dimtdec / setDimtdec
dimtolj / setDimtolj
```

즉 현재 LISP가 `ACAD/DSTYLE` xdata로 보존하는 값들은 SDK에서도 다룰 수 있습니다.

### 3. xdata / extension dictionary 접근 API도 있음

`IGcadObject`/`IGcadEntity` 계열에 다음 API가 있습니다.

```text
GetXData
SetXData
HasExtensionDictionary
GetExtensionDictionary
```

따라서 GstarCAD Mechanical의 맞춤공차 정보가 치수 객체의 xdata나 extension dictionary에 저장된다면, SDK나 COM/.NET으로 읽고 쓰는 길은 있습니다.

### 4. 하지만 Mechanical 맞춤공차 전용 API는 못 찾음

SDK 전체에서 다음 키워드를 검색했지만 직접적인 항목은 나오지 않았습니다.

```text
Power Dimension
AMPOWER
Mechanical fit
fit symbol
limits and fits
hole basis
shaft basis
H7
```

검색된 `FitTolerance`는 spline/nurb의 곡선 맞춤 허용오차입니다. 치수의 H7 끼워맞춤 공차가 아닙니다.

검색된 `GcDimFit`는 치수 문자/화살표 배치 맞춤입니다. H7 끼워맞춤 공차가 아닙니다.

## 결론

SDK에 바로 보이는 공개 API만으로는 `맞춤 > 기호(S): H7`이라는 GstarCAD Mechanical 전용 필드를 직접 생성하는 방법은 확인되지 않았습니다.

가능한 것은 두 가지입니다.

```text
1. 표준 DIMENSION 표시를 H7 + 편차공차처럼 보이게 만들기
2. 수동 변환 전/후 데이터를 비교해서 Mechanical 전용 데이터를 역추적하기
```

## 구현 전략

### A안: 표준 치수 기반 자동 변환

이 방법은 바로 만들 수 있습니다. 결과는 시각적으로는 거의 같지만, GstarCAD Mechanical의 진짜 `맞춤 > 기호(S)` 데이터는 아닐 수 있습니다.

작업:

```text
1. H7/g6 같은 독립 TEXT/MTEXT 찾기
2. 가까운 DIMENSION 찾기
3. 해당 DIMENSION에 이미 있는 상한/하한 공차값 유지
4. TextOverride 또는 TextSuffix에 H7 삽입
5. 원래 H7 TEXT/MTEXT 삭제
```

현재 LISP의 `SWFITMERGE`, `SWFITREVIEW`, `SWFITCODEDEL`이 이 방향입니다.

SDK/.NET으로 다시 만들면 더 안정적으로 할 수 있는 부분:

```text
IGcadDimension.ToleranceDisplay = gcTolDeviation
IGcadDimension.ToleranceUpperLimit = 0.025
IGcadDimension.ToleranceLowerLimit = 0
IGcadDimension.TextOverride 또는 TextSuffix = H7 포함
IGcadEntity.Delete로 원래 H7 문자 삭제
```

장점:

```text
자동화 가능
DWG 표준 치수로 남음
공차값 유지 가능
GstarCAD/AutoCAD 호환성 좋음
```

단점:

```text
Mechanical 파워 치수의 맞춤 기호 필드는 아닐 수 있음
편집창에서 기호(S): H7로 보장되지는 않음
```

### B안: Mechanical 데이터 역추적 후 자동 변환

이 방법은 진짜 맞춤공차 자동화를 노리는 방향입니다.

필요한 증거:

```text
1. 원본 치수에서 SWDUMPDIMDATA 실행
2. 같은 치수를 GstarCAD Mechanical에서 맞춤 > 기호(S): H7로 수동 변환
3. 변환 후 치수에서 SWDUMPDIMDATA 실행
4. SWDUMPDIMCOMPARE로 비교
```

비교 결과에서 변환 후에만 다음 데이터가 생기면 가능성이 있습니다.

```text
특정 regapp xdata
특정 extension dictionary
특정 XRecord
Mechanical 관련 class/object marker
```

그 경우 제작 방향:

```text
1. 전후 차이에서 Mechanical 맞춤공차 저장 구조 파악
2. H7, g6, H7/g6 값을 넣는 필드 위치 확인
3. LISP entmod 또는 .NET/COM SetXData, ExtensionDictionary API로 같은 구조 생성
4. 작은 샘플에서 GstarCAD Mechanical 편집창이 기호(S)를 인식하는지 확인
```

주의:

```text
단순 xdata 복사로는 치수 핸들, 객체 ID, 내부 체크섬, 확장 객체 참조 때문에 깨질 수 있음
GstarCAD 버전별 내부 형식이 다르면 유지보수가 어려움
```

### C안: Vendor API 문의

전후 덤프에 필요한 데이터가 보이지 않거나, 비공개 바이너리/프록시 객체로 저장된다면 직접 생성은 위험합니다.

GstarCAD 기술지원에 물어볼 질문:

```text
GstarCAD Mechanical Power Dimension의 Fits / Symbol 값을
LISP, COM, .NET, GRX 중 하나로 설정하는 공개 API가 있는가?

예: 파워 치수 편집창의 맞춤 탭 > 기호(S): H7 값을 자동으로 넣는 방법
```

필요한 키워드:

```text
Power Dimension
Fit Symbol
Fits and Tolerances
Mechanical Dimension
AMPOWERDIM equivalent
H7
Limits and Fits
```

## 추천

지금 당장 실무에 쓰는 것은 A안입니다.

```text
SWFITREVIEW
→ 수동으로 맞춤 > 기호(S): H7 변환
→ SWFITCODEDEL
```

자동화 가능성 판별은 B안으로 진행합니다.

```text
SWDUMPDIMDATA
SWDUMPDIMCOMPARE
```

전후 비교 결과를 보면, Mechanical 전용 데이터를 우리가 생성할 수 있는지 판단할 수 있습니다.

