# GMTITLE portable 전체 변환과 도면틀 외부 객체 정리 검증

날짜: 2026-07-12

LSP 버전: `260712-portable-saveas-offsheet-frame-1`

## 목표

고정 `work` 폴더 밖의 원본에서 사용자가 다른 이름으로 저장한 작업본을 만들고, 그 작업본에서 A2/A3/A4 전체를 native GMTITLE로 자동 변환한 뒤 다음 조건을 실제 GstarCAD에서 검증했다.

- 원본과 입력 복사본의 SHA-256 보존
- A2 1장, A3 12장, A4 2장 전체 변환
- 저장 후 GstarCAD 종료 및 결과 DWG 재열기
- 최종 구조 검증 통과
- 대표 A2/A3/A4 제목블록의 GMTITLE 표 편집창 동작

## 발견한 문제

첫 전체 변환은 표면상 15쌍을 만들었지만 A4 도면틀 정의의 raw bbox가 다음처럼 비정상적으로 컸다.

```text
예상 A4 범위: 210 x 297
발견한 raw bbox: (0, 0) - (872.26126377, 302.7)
```

원인은 `DR_A4_Outline` 정의 안에서 실제 용지 범위와 완전히 떨어진 중첩 INSERT였다. 이번 도면에서는 해당 하위 블록이 `HD-Rev No table`이었지만, 특정 이름이나 A4에만 맞춘 예외로 처리하면 다른 도면에서 같은 문제가 반복된다.

또한 기존 `SWTITLEVERIFY`는 원본 잔여물과 GMTITLE 쌍 수는 검사했지만 도면틀 정의의 raw bbox 위험을 최종 실패 조건에 포함하지 않았다. 따라서 과거 결과 중 `SWTITLEVERIFY_FINAL_OK`가 표시됐더라도 이 위험이 남아 있을 수 있었다.

## 공통 해결 규칙

도면틀 크기나 블록 이름을 하드코딩하지 않고 다음 조건을 모두 만족하는 하위 객체만 도면틀 스타일 잔여물로 판정한다.

```text
도면틀 정의의 자손 객체
엔티티 형식이 INSERT
실제 하위 블록 정의가 존재
DR_A*_Outline 또는 DR_titlea_3rd 자체가 아님
크기가 0에 가까운 객체가 아님
예상 용지 bbox와 전혀 교차하지 않음
예상 용지 bbox에서 5 이상 떨어져 있음
```

판정 이유는 `nested-off-sheet-insert`로 기록한다. 이 규칙은 A2/A3/A4와 이후 다른 용지에도 동일하게 적용된다.

최종 검증에도 `도면틀 정의 raw bbox 위험 수`를 추가했고, 값이 1 이상이면 더 이상 최종 OK가 나오지 않도록 했다.

## 정적 및 합성 회귀 검증

`style_normalization_compare_probe`에 A2/A3/A4 각각의 용지 밖 중첩 INSERT를 추가해 실제 GstarCAD에서 정리 전후를 비교했다.

```text
정리 전 off-sheet 중첩 INSERT: 3
정리 전 raw bbox 위험: 3
삭제: 45 entities
정리 후 off-sheet 중첩 INSERT: 0
정리 후 raw bbox 위험: 0
두 번째 정리 삭제: 0
일반 Revision 텍스트 보존: yes
일반 좌표 텍스트 보존: yes
```

증거:

```text
portable-e2e\evidence\swtitle_offsheet_style_probe_260712.txt
portable-e2e\output\swtitle_offsheet_style_probe_260712.dwg
```

정적 preflight도 통과했다.

## 실제 portable 전체 변환 검증

원본:

```text
work\0000_A_DRP125_CP_ALL_260626_ORIGINAL_TEST_260711.dwg
SHA-256: 3C7735569B7EBAC8300225A81CEFB441562AB656770E5FC8868099B559A959B2
```

portable 입력 복사본:

```text
portable-e2e\input\swtitle_portable_source_260712.dwg
SHA-256: 3C7735569B7EBAC8300225A81CEFB441562AB656770E5FC8868099B559A959B2
```

사용자 선택 Save As 결과:

```text
portable-e2e\output\swtitle_portable_result_260712.dwg
SHA-256: 1F2D3BA224A27E141CB64D79DC4FE75DCC00819D2F07751D83E8380CCE17AA23
```

결과 DWG에서 `SWTITLEPREPARE`를 실행했을 때 공유된 A4 도면틀 정의의 용지 밖 중첩 INSERT 1개만 제거됐다. 저장 후 GstarCAD를 종료하고 결과 DWG를 다시 연 다음 최신 LSP를 APPLOAD해 재검증했다.

```text
남은 원본 표제란 후보: 0
남은 원본 도면틀 후보: 0
독립 검증 기존 표제란 잔여물: 0
도면틀 정의 raw bbox 위험 수: 0
대상 도면틀 수: 15
대상 제목블록 수: 15
도면틀/제목블록 쌍 수: 15
A2: 1 / A3: 12 / A4: 2
결과: SWTITLEVERIFY_FINAL_OK
최종 결과: OK
```

재열기 후 대표 제목블록을 실제로 더블클릭했다.

```text
A2: 속성 블록 편집 GMTITLE 표 열림
A3: 속성 블록 편집 GMTITLE 표 열림
A4: 속성 블록 편집 GMTITLE 표 열림
고급 속성 편집기: 열리지 않음
값 변경: 없음, 각 창은 ESC로 취소
```

재열기 검증 로그:

```text
portable-e2e\evidence\final-reopen-260712\
```

## Legacy 전체 suite 감사 결과

`run_main45_verification_suite.ps1`도 실행했지만 제품 회귀가 아니라 과거 fixture 계약 때문에 2단계에서 중단됐다.

첫 실행에서는 suite 전용 중간 작업본 대신 원본 상태 DWG를 입력해 상태 코드가 달랐다. 두 번째 실행에서는 suite 기본 DWG를 사용했지만 최신 LSP의 실제 판정은 다음과 같았다.

```text
최신 실제 판정: source-title-count=10, frame-only-count=0
suite 고정 기대: source-title-count=8, frame-only-count=2
공통 판정: target-title-count=5, target-frame-count=5
```

최신 LSP는 A4의 실제 제목 텍스트도 A2/A3와 같은 규칙으로 인식한다. legacy suite는 A4 두 장을 무조건 frame-only로 보던 과거 전제를 수량 문자열로 고정하고 있어 현재 통합 정책과 맞지 않는다. 따라서 제품 판정을 과거 값으로 되돌리거나 suite 숫자만 임의로 바꾸지 않았다.

이 시점의 남은 테스트 인프라 작업은 A4라는 크기에 의존하지 않는 독립적인 `source-title-missing` fixture를 만들고, suite의 실제 작업본 상태 검사를 그 fixture와 분리하는 것이었다. 같은 날 후속 작업에서 이를 구현하고 18단계 전체 suite를 통과시켰다.

```text
docs\history\gmtitle-source-title-missing-suite-reset-2026-07-12.md
```

증거:

```text
portable-e2e\evidence\legacy_suite_stale_fixture_260712.txt
portable-e2e\evidence\swtitle_suite_candidate_probe_260712.txt
```

이번 목표의 제품 검증 근거는 다음 세 가지다.

```text
정적 preflight: PASS
A2/A3/A4 공통 off-sheet 합성 GstarCAD 회귀: PASS
portable 실제 전체 변환, 저장, 재열기, 15/15/15 구조와 대표 편집창: PASS
후속 18단계 전체 suite: PASS
```

## 결론

고정 `work` 경로 밖에서도 사용자 선택 Save As 작업본 생성, A2/A3/A4 전체 자동 변환, 저장과 재열기, native GMTITLE 편집기 동작, 원본 보존까지 한 흐름으로 통과했다.

이번 수정은 A4 전용 분기가 아니라 도면틀 정의의 용지 밖 하위 INSERT를 찾는 공통 구조 규칙이다. 최종 검증도 같은 위험을 실패 조건으로 사용하므로 이전의 거짓 OK를 반복하지 않는다.
