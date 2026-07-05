# GMTITLE A4 Native Selection Config Probe - 2026-07-05

## 배경

A4 frame-only 변환은 아직 완료가 아니다.

설치 원본 `DR_A4_Outline`을 직접 가져오면 화면상 effective bbox는 A4처럼 보일 수 있지만, 실제 raw selection bbox가 A4 밖으로 커지는 문제가 있었다.
단순 삭제식 정규화와 nested cleanup probe도 모두 unsafe였으므로, 다음 단계는 실제 GstarCAD `GMTITLE`이 만든 native A4 샘플과 비교하는 것이다.

다만 새 scratch DWG에서 직접 `GMTITLE`을 실행했을 때, 현재 로컬에서는 선택창이 열리지 않고 곧바로 `삽입 지점:` 흐름으로 들어갔다.
`FILEDIA=1`, `CMDDIA=1` 상태에서도 동일했다.
따라서 직접 `GMTITLE`만 실행해서 생긴 결과는 `DR_A4_Outline`을 새로 선택했다는 증거가 아니다.

## 확인한 설정 위치

읽기 전용으로 아래 위치를 확인했다.

```text
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\MCADSetting\PaperSet.ini
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\MCADSetting\PaperSet.dat
C:\Program Files\Gstarsoft\GstarCAD Mechanical 2024 Korean\Professional\GRX8X64\PaperSet.grx
HKCU\Software\Gstarsoft\GstarMechStd\R24\ko-KR\Profiles\GstarMech2024Pro\Dialogs\PAPERSET.GRX-66
%APPDATA%\Gstarsoft\GstarMechStd\R24\ko-KR\Gcadm\MCADSetting\pro\impro.ini
```

확인 결과:

```text
PaperSet.ini:
  [Common]
  DrawWithBlock = 0

PaperSet.dat:
  A0/A1/A2/A3/A4 치수 목록은 있으나 DR_A*_Outline / DR_titlea_3rd 선택값 없음

PaperSet.grx ASCII marker:
  Frame, Object, PaperSet, TitleBlockTotalMass, TitleScale 정도만 확인됨

ImCuiTranslate.xml:
  GMTITLE 표시 명령의 상위 매크로는 ^C^Cimtitle
  ko-kr command는 GMTITLE, short는 TIT
  PAPERSET 내부 HC_SBLOCKE는 GMSBLOCKE로 매핑됨

ImLanguage.xml:
  PAPERSET DIALOG 라벨은 Super Attribute Block Edit / 속성 블록 편집
  따라서 GMSBLOCKE는 생성/용지 선택이 아니라 속성 블록 편집 계열로 보는 것이 맞음

PAPERSET.GRX-66 registry key:
  현재 일반 조회에서는 키가 없었음
  이전 대화상자 흔적이 있을 때도 X/Y/Width/Height 같은 위치/크기 값만 확인됐고 DR 선택값은 아니었음

impro.ini:
  TEMPLATE 경로 등만 있고 DR_A*_Outline / DR_titlea_3rd 선택값 없음
```

## 추가한 재현용 진단

같은 설정 조사를 반복하지 않도록 아래 스크립트를 추가했다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_gmtitle_selection_config_probe.ps1
```

현재 기대 결과:

```text
Result: GMTITLE_SELECTION_CONFIG_NOT_FOUND
```

이 결과는 "GMTITLE 자동화가 불가능하다"는 뜻이 아니다.
의미는 더 좁다.

```text
현재 확인한 설정 파일/레지스트리/GRX 문자열만으로는
GMTITLE 창의 DR_A*_Outline / DR_titlea_3rd 기본 선택을 고정할 근거가 없다.
```

## 결론

다음 세션에서 같은 실수를 피하기 위한 기준:

```text
1. 직접 GMTITLE 실행 후 삽입 지점만 묻는 상태는 A4 native 샘플 생성으로 인정하지 않는다.
2. scratch DWG를 저장하더라도 run_a4_native_exemplar_probe.ps1가 READY를 반환해야 비교 기준으로 인정한다.
3. production A4 frame-only에는 원본에 없던 DR_titlea_3rd 제목블록을 만들지 않는다.
4. A4 raw bbox guard가 통과하기 전에는 기존 A4 원본 도면틀을 삭제하지 않는다.
```

## 2026-07-05 CAD 명령줄 확인

현재 열려 있던 scratch `Drawing1.dwg`에서 원본/작업복사본을 건드리지 않고 확인했다.

```text
IMTITLE:
  결과: 알 수 없는 명령 "imtitle"
  판단: XML 상위 매크로에 보이지만 현재 CAD 명령줄에서 실행 가능한 대체 경로가 아님

TIT:
  결과: GMTITLE과 같은 _UNDO 이후 삽입 지점 프롬프트로 들어감
  판단: DR_A4_Outline 선택창을 여는 별도 경로가 아니라 GMTITLE 짧은 명령/별칭 계열

ESC:
  결과: 삽입 프리뷰/대기 상태 취소
```

따라서 현재 기준으로는 `GMTITLE`, `TIT`, `IMTITLE` 중 어느 것도 A4 native 샘플을 자동 확보하는 확실한 경로가 아니다.

## 2026-07-05 리본/접근성 확인

같은 scratch `Drawing1.dwg`에서 Windows 접근성 트리도 확인했다.
필터는 `도면 제목`, `경계`, `GMTITLE`, `TIT`, `Drawing Title`, `Borders`, `Paper` 기준으로 좁혔다.

결과:

```text
hitCount: 2
hits:
  제목 표시줄
  제목 표시줄
```

즉 현재 GstarCAD 리본은 자동화에서 쓸 수 있는 안정적인 `도면 제목/경계` 버튼 이름을 노출하지 않았다.
따라서 리본 버튼을 스크린샷 좌표로 누르는 방식은 자동화 증거가 아니며, 다음 세션에서도 기본 전략으로 되돌리지 않는다.

이 확인은 "리본으로 사람이 GMTITLE을 열 수 없다"는 뜻은 아니다.
의미는 더 좁다.

```text
현재 확인한 접근성 정보만으로는 리본/메뉴의 DR 용지 선택 경로를 안정적으로 자동 조작할 수 없다.
```

다음 유효한 조사 방향:

```text
실제 GMTITLE 선택창을 열 수 있는 안정 경로 확인
또는 GstarCAD가 만든 native A4 샘플 DWG 확보
그 샘플의 DR_A4_Outline definition/xdata/reactors/extension dictionary를 설치 원본 import 결과와 비교
```
