# GMTITLE loose-text 제목 셸 및 결재값 통합 정리 이력

날짜: 2026-07-11
브랜치: `codex/gm-title`
LSP 버전: `260711-unified-title-value-3`

## 목적

A2/A3/A4를 용지 크기별 예외로 나누지 않고, 원본 제목 정보가 저장된 형태에 따라 같은 변환 흐름으로 처리한다.

```text
block-attributes : 제목값이 기존 제목블록 속성에 있음
loose-text       : 제목값이 일반 TEXT/MTEXT에 있음
none             : 실제 제목 정보가 없음
```

`loose-text`는 값만 일반 문자일 수 있고, 그 아래의 정적 표 틀은 별도 INSERT로 존재할 수 있다. 이 INSERT를 이 문서에서는 `제목 셸(title shell)`이라고 부른다.

## 발견한 오판

이전 검증기는 테스트 원본을 다음처럼 판정했다.

```text
제목 정보 시트: 13
도면틀: 15
A4 frame-only/title-missing: 2
```

그러나 CAD 실화면에서 A4 제목 영역을 확대하니 다음 두 요소가 모두 있었다.

1. 실제 제목값 9개: 일반 TEXT/MTEXT
2. 정적 라벨과 선: `0310_DR_표제란`, `0320_DR_표제란` INSERT

기존 로직은 1번의 값은 읽고 삭제했지만 2번 INSERT는 일반 그래픽 삭제 대상에도, 영문 `TITLE/GMTITLE/FTAP` 이름 검사에도 걸리지 않아 남겼다. 그래서 새 `DR_titlea_3rd`와 기존 제목 셸이 겹쳐 보였다.

실제 완성본에서 확인한 잔여 셸:

```text
handle=36E5, block=0310_DR_표제란
handle=5292, block=0320_DR_표제란
```

`SWTITLEVERIFY_FINAL_OK`였는데도 이 두 INSERT가 남았으므로, 당시 최종 판정은 거짓 양성이었다.

## 해결 방식

`swcad-title-source-title-shell-records`가 다음 조건을 함께 검사한다.

1. 원본 제목 범위와 후보 INSERT 범위가 충분히 겹친다.
2. 후보 크기가 제목 범위에 비해 지나치게 작거나 크지 않다.
3. 이름에 `TITLE/GMTITLE/FTAP/표제란` 증거가 있거나, 블록 내부에 `Designed by`, `Checked by`, `Scale`, `Date` 같은 제목 라벨이 여러 개 있다.
4. 현재 native `DR_titlea_3rd`, `DR_A*_Outline`, 원본 도면틀은 제외한다.

이 판정은 A4 문자열이나 A4 전용 함수 없이 모든 용지 크기에 공통 적용한다.

변환 성공 순서는 다음과 같다.

```text
원본 값 추출
→ 새 native GMTITLE 생성/채택
→ 속성값 입력 후 재검증
→ 원본 TEXT/MTEXT 삭제
→ 검증된 제목 셸 INSERT 삭제
→ 기존 도면틀과 제한된 잔여물 삭제
→ native 쌍 마커 기록
```

속성값 검증이 실패하면 제목 셸과 원본 데이터는 삭제하지 않는다.

## 최종 검증 강화

`swcad-title-target-title-shell-records`는 변환된 각 `DR_titlea_3rd` 범위에 다른 제목 셸 INSERT가 겹치는지 다시 검사한다. 하나라도 남으면 `swcad-title-other-title-like-inserts`에 포함되므로 `SWTITLEVERIFY_FINAL_OK`가 나올 수 없다.

회귀 프로브 계약:

```text
원본: loose-text 제목 2개, 동반 제목 셸 2개
완료본: target title-overlapping source shell inserts 0개
완료본: 원본 셸 handle 36E5/5292 모두 없음
```

## 결재자와 날짜 결합값 정리

첫 15/15 변환본의 CAD 화면을 다시 확대했을 때 제목 셸은 사라졌지만, A4 한 장의 `Approved by` 값이 `KS.LEE/20260601`로 들어가고 별도 `Date`에도 `2026-06-01`이 들어가 값끼리 겹쳤다. 기존 검증기는 원본 문자열을 그대로 기대했기 때문에 이를 정상으로 잘못 판정했다.

`swcad-title-normalize-combined-approval-date-values`는 용지 크기와 무관하게 다음 조건을 모두 만족할 때만 결재자와 날짜를 분리한다.

```text
Approved by 값이 이름/날짜 형태
슬래시 오른쪽이 유효한 8자리 날짜
별도 Date 값도 유효한 날짜
두 날짜를 숫자 8자리로 정규화했을 때 서로 같음
```

따라서 `KS.LEE/20260601 + 2026-06-01`은 `KS.LEE + 2026-06-01`로 정리하고, 이미 정상인 `KS. LEE + 20260601`은 바꾸지 않는다. 이 규칙에도 `A4` 문자열이나 A4 전용 분기는 없다.

## 최종 검증 결과

최종 재검증: 2026-07-12

보존 원본:

```text
work\0000_A_DRP125_CP_ALL_260626_ORIGINAL_TEST_260711.dwg
SHA256: 3C7735569B7EBAC8300225A81CEFB441562AB656770E5FC8868099B559A959B2
```

최종 정리본:

```text
work\swtitle_unified_fullflow_titlevalue_cleaned_260711_04.dwg
SHA256: A5ADE688FBAE23592475522544508D69FEAD23C554B518D196D9BF2EE2C61CFA
```

주요 로그:

```text
work\swtitle_loose_title_source_probe_260711.txt
work\swcad_title_native_autoselect_batch_last.txt
work\swtitle_unified_cleanup_titlevalue_260711_04.txt
work\swtitle_unified_final_verification_titlevalue_260711_04.txt
```

검증 결과:

```text
원본 제목/도면틀/frame-only: 15 / 15 / 0
원본 제목 저장 형태: block-attributes 13 / loose-text 2
변환 후 제목블록/도면틀/native 쌍: 15 / 15 / 15
A2/A3/A4 도면틀: 1 / 12 / 2
남은 원본 제목/도면틀/frame-only: 0 / 0 / 0
남은 제목 셸 INSERT: 0
남은 원본 loose title TEXT/MTEXT: 0
결재자/날짜 결합 속성값: 0
보호한 일반 A4 주석: 8
고아/중복/native-upgrade 후보: 0 / 0 / 0
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_OK
```

CAD 실화면에서도 다음을 확인했다.

- A4 `Approved by=KS.LEE`, `Date=2026-06-01`이 겹치지 않는다.
- 대표 A2, A3, A4 `DR_titlea_3rd`를 각각 더블클릭하면 모두 `속성 블록 편집` 표가 열린다.
- 화면 검증 전후 최종 정리본 SHA-256은 동일하다.
- 정적 preflight와 원본 읽기 전용 회귀검사가 모두 통과했다.

화면 검사 중 GstarCAD 저장 대화상자가 긴 붙여넣기를 파일명으로 오해해 만든 `work\fullflow_cleaned_.dwg`는 검사용 임시본이며, 위 최종 정리본과 완료 근거로 사용하지 않는다.

## 사용자 명령 흐름

새 사용자 명령은 추가하지 않았다.

```text
SWTITLESTATUS
SWTITLEPREPARE      ; 상태가 요구할 때만
SWTITLECONVERTNEXT
SWTITLEVERIFY       ; 변환 종료 후
```

13개 제목블록과 15개 도면틀 상태는 더 이상 최종 성공으로 인정하지 않는다. 이 테스트 원본의 완료 기준은 제목블록 15개, 도면틀 15개, native GMTITLE 쌍 15개다.
