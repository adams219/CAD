# GMTITLE 명령/설정 표면 재확인 - 2026-07-05

## 목적

사용자가 지적한 핵심 불편은 "GMTITLE 창에서 매번 사람이 용지와 제목블록을 고르는 일이 비효율적"이라는 점이다.

그래서 GstarCAD 설치 파일, 사용자 설정, 명령 매핑, 언어 리소스 안에 `DR_A*_Outline`과 `DR_titlea_3rd`를 명령줄이나 설정값으로 미리 고정할 수 있는 근거가 있는지 다시 확인했다.

이 조사는 자동화를 포기하기 위한 조사가 아니라, 화면 좌표 클릭처럼 재현성이 낮은 방식으로 다시 돌아가지 않기 위한 경계선 확인이다.

## 확인한 명령 표면

`Common\ImCuiTranslate.xml`에서 확인한 명령 매핑은 다음과 같다.

```text
GMTITLE:
  module=IMSTANDARD
  top-command=^C^Cimtitle
  ko-command=GMTITLE
  short=TIT

PAPERSET / GMSBLOCKE:
  internal-command=HC_SBLOCKE
  user-command=GMSBLOCKE
```

해석:

```text
GMTITLE/TIT는 도면 제목/경계 명령 계열이다.
IMTITLE은 리본/메뉴 매크로에 보이는 상위 이름이지만, 현재 CAD 명령줄에서는 안정적인 직접 실행 명령으로 확인되지 않았다.
GMSBLOCKE는 PAPERSET super attribute block edit 계열로 보이며, DR 용지/제목블록 사전 선택 명령으로 보지 않는다.
```

## 2026-07-10 PAPERSET.GRX export 재확인

설치된 `Professional\GRX8X64\PaperSet.grx`의 PE export table을 읽기 전용으로 확인했다.

```text
?Entry_superBlockEdit@@YAXXZ
I_SuperBlockEdit
gcrxEntryPoint
gcrxGetApiVersion
```

확인된 export는 super attribute block 편집 진입점과 GRX 로드 진입점뿐이다. `DR_A*_Outline`, `DR_titlea_3rd`, Frame positioning, Object move 값을 인수로 받는 공개 export는 확인되지 않았다.

이 결과는 내부 구현 전체를 역공학한 증거는 아니지만, `PaperSet.grx`가 공개 함수 호출만으로 GMTITLE 선택값을 지정할 수 있다는 가설을 지지하지 않는다. 따라서 화면 좌표가 아닌 고정 대화상자 컨트롤 ID 실험을 다음 후보로 유지한다.

`Common\ImLanguage.xml`에서 확인한 관련 라벨은 다음과 같다.

```text
Drawing Borders with Title Block / 제목 블록과 도면 경계
Select title block automatically / 제목 블록 자동 선택
Automatic placement / 자동 배치
Select extension title blocks to be inserted with main title block / 주 제목 블록과 함께 삽입할 블록 선택
Select the drawing border / 도면 경계 선택
Select the title border / 제목 블록 선택
Frame and title block layers are switched ON / 프레임 및 제목 블록 도면층 켜기
```

이 라벨들은 대화상자 항목 또는 프롬프트로 판단한다. 이름만 보면 자동화 설정처럼 보이지만, `DR_A*_Outline` 또는 `DR_titlea_3rd`를 명령줄에서 직접 선택하게 해주는 API 근거는 아니다.

## 현재 probe 결론

`diagnostics\gmtitle-main45\run_gmtitle_selection_config_probe.ps1` 기준 결과:

```text
Result: GMTITLE_SELECTION_CONFIG_NOT_FOUND
```

이 결론은 "GMTITLE 선택 자동화가 영원히 불가능하다"는 뜻이 아니다.

뜻은 더 좁다:

```text
현재 확인한 설치 파일, PaperSet 설정, 명령 매핑, 언어 라벨, 기본 AppData/registry 위치에서는
DR_A*_Outline / DR_titlea_3rd를 안정적으로 사전 선택하는 공개 설정 근거를 찾지 못했다.
```

따라서 현재 기본 경로는 다음 원칙을 유지한다.

```text
1. 리본 버튼 좌표 클릭은 자동화 근거로 채택하지 않는다.
2. IMTITLE/TIT/GMTITLE 직접 호출이 삽입점만 묻는 상태라면 DR 용지 선택 성공으로 보지 않는다.
3. GMTITLE 창의 DR 용지/제목블록/옵션은 사람이 눈으로 확인한다.
4. LSP는 좌표 계산, 값 복사, 기존 원본 정리, 결과 검증을 맡는다.
5. AppData 텍스트 마커 검색 결과는 참고용이며, hit가 나오더라도 수동 검토 전에는 사전 선택 근거로 쓰지 않는다.
```

## 다음 판단 기준

다음 중 하나의 증거가 생기면 이 결론을 다시 열 수 있다.

```text
1. GstarCAD가 실제로 만든 native GMTITLE 선택 상태를 안정적으로 저장하는 공식 설정 위치
2. DR_A*_Outline / DR_titlea_3rd를 명령줄 인수나 documented API로 넘기는 방법
3. 화면 좌표와 무관하게 접근성/객체 식별자로 GMTITLE 창 항목을 선택할 수 있는 검증된 방법
```

그 전까지는 `SWTITLECONVERTNEXT`를 기본 경로로 사용하고, GMTITLE 창 선택은 "짧지만 사람이 확인하는 단계"로 남긴다.
