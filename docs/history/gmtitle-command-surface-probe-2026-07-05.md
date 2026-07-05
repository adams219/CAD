# GMTITLE 명령/설정 표면 재확인 - 2026-07-05

## 목적

사용자가 지적한 문제는 "GMTITLE 창에서 매번 사람이 용지와 제목블록을 고르는 것이 비효율적"이라는 점이다.
따라서 GstarCAD 설치 파일과 사용자 설정에 `DR_A*_Outline`, `DR_titlea_3rd`를 명령줄이나 설정값으로 미리 고정할 수 있는 근거가 있는지 다시 확인했다.

## 확인한 내용

`Common\ImCuiTranslate.xml`에서 확인한 명령 매핑:

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
IMTITLE는 리본/메뉴 매크로에 보이는 상위 이름이지만, 현재 CAD 명령줄에서 독립 실행 가능한 명령으로 확인되지 않았다.
GMSBLOCKE는 PAPERSET super attribute block edit 계열로 보이며, 용지/제목블록 사전 선택 명령으로 보지 않는다.
```

`Common\ImLanguage.xml`에서 확인한 관련 라벨:

```text
Drawing Borders with Title Block / 제목 블록과 도면 경계
Select title block automatically / 제목 블록 자동으로 선택
Automatic placement / 자동 배치
Select extension title blocks to be inserted with main title block / 주 제목 블록과 함께 삽입할 블록 선택
Select the drawing border / 도면 경계 선택
Select the title border / 제목 블록 선택
Frame and title block layers are switched ON / 프레임 및 제목 블록 도면층 켜기
```

해석:

```text
위 항목들은 대화상자 라벨 또는 프롬프트다.
이름만 보면 자동화 힌트처럼 보이지만, DR_A*_Outline 또는 DR_titlea_3rd를 명령줄에서 직접 선택하게 해주는 API 증거는 아니다.
```

## 현재 결론

`run_gmtitle_selection_config_probe.ps1` 기준 결과:

```text
Result: GMTITLE_SELECTION_CONFIG_NOT_FOUND
```

이 결론은 "GMTITLE 자동화가 영원히 불가능하다"가 아니다.
현재 확인한 설치 파일, PaperSet 설정, 명령 매핑, 언어 라벨, 기본 AppData/registry 위치에서는 안정적인 사전 선택 근거가 없다는 뜻이다.

따라서 다음 원칙을 유지한다.

```text
1. 리본 버튼 좌표 클릭은 자동화 근거로 채택하지 않는다.
2. IMTITLE/TIT/GMTITLE 직접 호출이 삽입점만 묻는 상태라면, DR_A4_Outline을 새로 선택한 증거로 보지 않는다.
3. A4 frame-only 문제는 현재 작업 DWG에서 계속 삭제/정리하지 않고, 별도 scratch native A4 샘플을 만든 뒤 구조를 비교한다.
4. AppData 텍스트 마커 스캔은 참고용이다. hit가 나오더라도 수동 검토 전에는 active preselection 증거로 보지 않는다.
```

## 다음 판단 기준

다음에 CAD에서 실제 검증할 때는 아래 둘 중 하나의 증거가 필요하다.

```text
1. GstarCAD가 실제로 만든 native A4 scratch DWG
2. 또는 DR_A*_Outline / DR_titlea_3rd를 안정적으로 사전 선택하는 문서화된 명령/설정 근거
```

1번이 현재 더 현실적인 방향이다.
