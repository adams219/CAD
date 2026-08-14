# 30장 전체 정리 성능 검증 - 2026-07-19

## 목적

30장 이상 도면에서 전체 미사용 이름 정의 정리 단계의 `SWCADRUN` 시간을 줄이되, GMTITLE·치수·Layout·출처 정보와 저장 후 무결성을 그대로 유지하는 것이 목적이다.

- 1차 목표: 3회 중앙값 `180,000 ms` 이하
- 도전 목표: 3회 중앙값 `150,000 ms` 이하
- 원본 DWG 수정 금지
- 공개 명령 `SWCADSTATUS`, `SWCADRUN`, `SWCADVERIFY`와 기존 단계 흐름 유지

## 검증 원본

정리 단계에 진입하기 직전의 30장 도면을 매 실행마다 새 복사본으로 만들었다.

```text
work\bak_XRef Sw WorkFlow Test_260715_before_v5_cleanup_260715.dwg
SHA-256: 5900CBD30219C636FB93A782497367C9834187430CC85E5954AFCDAD49C5FAF5
```

원본 파일은 열거나 저장하지 않았고, 모든 실행 산출물은 `work\swcad-workflow-tests\cleanup-performance-260719` 아래 복사본으로 제한했다.

## 측정 방법

1. 각 회차마다 같은 원본에서 고유한 새 DWG 복사본을 만든다.
2. 기준 버전은 분리한 Git worktree의 커밋 `973b4de4`와 LSP 버전 `260715-full-unused-purge-13`을 사용한다.
3. 개선 버전은 LSP 버전 `260719-cleanup-zero-pass-fast-17`을 사용한다.
4. 정리 단계의 `SWCADRUN` 1회를 재고, 독립 전체 감사는 측정 구간 밖에서 실행한다.
5. 각 버전을 3회 실행해 중앙값과 MAD(중앙절대편차)를 비교한다.
6. 각 회차에서 workflow 지문, 안정 정체성 지문, 삭제 수, 수렴 반복, 감사 결과와 `DBMOD`를 기록한다.

첫 번째 기준 warm-up은 로더의 workspace fallback으로 개선 버전을 읽었으므로 공식 측정에서 제외했다.

## 병목 계측

읽기 전용 phase probe를 3회 실행했다. 아래 값은 각 probe의 중앙값이며 서로 포함 관계가 있으므로 합산하지 않는다.

| Probe | 중앙값 |
| --- | ---: |
| 모델 공간 bbox | 21,332 ms |
| GMTITLE 구조 | 1,441 ms |
| Layout 구조 | 9,057 ms |
| workflow 전체 무결성 | 31,245 ms |
| cleanup 전체 검증 | 50,287 ms |
| workflow 단계 판정 | 58,170 ms |

병목은 PURGE 자체만이 아니라 같은 명령 안에서 모델 bbox와 전체 cleanup 감사를 여러 번 새로 계산하는 구조였다.

## 변경 내용

- 정리 단계에서 이미 계산한 after-state와 definition snapshot을 최종 cleanup 검증에 다시 사용한다.
- 성공한 cleanup 검증 결과를 같은 명령의 읽기 캐시에 넘겨 즉시 이어지는 상태 출력의 전체 재감사를 막는다.
- 정의가 실제로 삭제된 PURGE 반복 뒤에는 다음 항목을 포함한 경량 무결성 지문을 비교한다.
  - 모델·Layout 객체 수
  - 치수값·공차·축척과 Mechanical fit 의미
  - GMTITLE frame/title 링크와 속성
  - Layout 이름·용지·객체 수·viewport
  - XREF 출처와 workflow 상태
- 삭제 0개 반복은 바로 뒤의 전체 저장 전 감사와 겹치므로 중간 경량 검사를 생략한다.
- 전체 bbox 감사는 첫 저장 전과 cleanup 성공 상태 기록 후에 유지한다.
- 공개 `SWCADVERIFY`는 캐시나 이전 snapshot을 신뢰하지 않고 현재 DWG를 새로 읽어 전체 감사한다.

명령 오류, 무결성 차이, 비수렴 또는 저장 고정점 실패 시 기존 UNDO와 완료 차단 동작은 바꾸지 않았다.

## 3회 결과

| 구분 | 1회 | 2회 | 3회 | 중앙값 | MAD |
| --- | ---: | ---: | ---: | ---: | ---: |
| 기준 버전 | 305,166 ms | 268,145 ms | 286,247 ms | 286,247 ms | 18,102 ms |
| 개선 버전 | 172,693 ms | 167,202 ms | 153,017 ms | 167,202 ms | 5,491 ms |

- 중앙값 단축: `119,045 ms`
- 개선율: `41.6%`
- 1차 목표 `180,000 ms` 이하: 통과
- 도전 목표 `150,000 ms` 이하: 미달

모든 공식 회차에서 다음 결과가 같았다.

```text
PURGE 반복: 2
삭제 정의: 35
workflow signature: 26703:84270:933478
stable identity signature: 1002:306788:552546
독립 전체 감사: OK
DBMOD: 0
```

## 저장·재열기 검증

개선 버전의 세 번째 결과를 GstarCAD Mechanical 새 프로세스에서 다시 열고 현재 workspace 모듈을 로드했다.

- `SWCADVERIFY` 결과: `SWCADVERIFY_FINAL_OK`
- 남은 XREF: 0
- 남은 wrapper: 0
- GMTITLE 최종 상태: OK
- DIMSTYLE·Mechanical fit 감사: OK
- 전체 정리 감사: OK
- Layout 계획과 A4 Layout 검증: 30개, OK
- 대표 A3 `DR_titlea_3rd` 더블클릭: `속성 블록 편집` 표 정상 표시
- Checked by, Designed by, Date, Scale, Sheet, File No, File Name 등 속성값 표시 확인

## 결론과 잔여 병목

1차 성능 목표와 모든 무결성 기준을 통과했다. 도전 목표까지 남은 약 17초의 중앙값 차이를 줄이려면 현재도 필수로 남아 있는 GstarCAD 저장, native PURGE, 모델 bbox 전체 감사 비용을 더 세분화해야 한다. 이 구간은 결과 안전성과 직접 연결되므로 별도 대표 파일과 동일한 저장·재열기 기준 없이는 제거하지 않는다.
