# SWCAD 출처 기반 Layout·자동 정리 검증 (2026-07-14)

## 목표

- 수동 `PURGE`를 없앤다.
- Layout 이름의 `SWCAD` 접두사와 자동 순번을 없앤다.
- 사용자가 XREF를 배치한 순서와 원본 DWG 파일명을 변환 뒤에도 보존한다.
- 앱이 만든 Layout만 재실행 시 교체하고 사용자 Layout은 유지한다.
- 원본 DWG는 수정하지 않고 복사본에서만 CAD 실검증한다.

검증 버전은 `260714-source-layout-cleanup-1`이다. 공개 명령은 `SWCADSTATUS`, `SWCADRUN`, `SWCADVERIFY` 세 개로 유지했다.

## BIND 전 출처 저장

보존 기준본을 새 빈 도면에 XREF로 붙여 `MATERIALIZE_WRAPPED_XREF`를 실행했다.

```text
읽기 전용 기준본:
work/_preserved_20260714/fixtures/sheet_wrapper_source_fixture_260713.dwg

테스트 산출물:
work/swcad-workflow-tests/source-layout-cleanup-260714/materialize-source-metadata-copy.dwg
work/swcad-workflow-tests/source-layout-cleanup-260714/materialize-source-metadata.log
```

결과:

- `SWCADRUN`: 42,604 ms
- 남은 XREF/wrapper: `0/0`
- 최상위 치수: `254`, 예상 deep 치수와 일치
- 원본 title/frame: `30/30`
- 모델 bbox 보존: `yes`
- 다음 단계: `TITLE`
- 런타임 검사: `yes`

BIND 전에 저장한 실제 레코드는 다음과 같다.

```text
SOURCE_SHEET_COUNT="1"
SOURCE_SHEET_STATUS=CAPTURED_BEFORE_BIND

(1
 "sheet_wrapper_source_fixture_260713"
 "SWCAD_WORKFLOW_TEST_XREF"
 "73D"
 (1000.0 1406.0 7986.25 2297.0))
```

순서, 원본 파일명 stem, 참조명, 핸들, bbox가 XREF가 사라진 뒤에도 DWG에 남았다.

## 이미 materialize된 30장 복사본

사용자 확인 완성본을 다음 복사본으로 만들어 검사했다.

```text
work/swcad-workflow-tests/source-layout-cleanup-260714/complete-source-copy.dwg
```

이 도면에는 신규 `SOURCE_SHEET_*`가 없으므로 fallback을 사용했다.

- 고유한 GMTITLE `File Name`은 그대로 사용했다.
- 여러 시트에 반복된 일반 파일명은 출처로 사용하지 않았다.
- 해당 frame 안의 `$0$` 결합 블록 접두사로 실제 부품 파일명을 복구했다.
- `FILE NO`, `Sheet`, frame handle은 그 다음 fallback으로 남겼다.

예정 이름에는 `P_eCVT-Planetary HL Gear_RH_260506_A4`, `P_eCVT-Sun HL Gear_LH_260506`, `P_eCVT-Idler-Red Gear 30T_260506`처럼 실제 부품 파일명이 나타났다.

## 자동 정리 결과

DIMSTYLE 뒤 `SWCADRUN`이 `$0$` 결합 흔적과 미사용 SLD 정의를 정리했다.

- `RESOURCE_CLEANUP=OK`
- `RESOURCE_CLEANUP_ZERO_PASS=YES`
- 정책: `XREF_BOUND_UNUSED_V1`
- 모델 객체 수, bbox, 치수 의미, GMTITLE 링크·속성 무결성 통과
- 다음 단계가 `LAYOUT`으로 변경됨

두 번째 정리 반복의 삭제 수가 0이므로 사용자가 별도로 `PURGE`할 필요가 없다. 실제 참조 중이거나 보호 대상인 정의는 남아도 정상이다.

## Layout 생성·재열기 결과

- 최종 GMTITLE 도면틀: 30
- 앱 소유 Layout: 30
- 구버전 `SWCAD-SHEET-*`: 0
- 전체 paper Layout: 32
- 보존된 사용자 Layout: `Layout1`, `Layout2`
- 이름 정책: `SOURCE_FILE_STEM_NO_PREFIX_NO_SEQUENCE`
- 좌표 모드: `XREF_SOURCE_FILENAME_COORDINATES`
- 계획 지문: `30:24100:574731`
- A4 Layout 검사: `OK (30장)`
- 최초 최종 검사: `SWCADVERIFY_FINAL_OK`
- 저장·닫기·재열기 후 최종 검사: `SWCADVERIFY_FINAL_OK`

중복 이름은 실제 충돌이 있을 때만 `FILE NO`, `Sheet`, 최소 숫자 suffix로 구분한다. 평상시에는 `SWCAD-001`이나 별도 순번을 붙이지 않는다.

## 결론

대표 복사본에서 수동 `PURGE`와 수동 Layout 이름 변경은 모두 0회였다. 출처가 남아 있는 신규 XREF 흐름과 출처가 없는 기존 materialize 도면의 fallback 흐름을 각각 CAD에서 확인했다. 원본 도면과 보존 기준본은 편집하지 않았다.
