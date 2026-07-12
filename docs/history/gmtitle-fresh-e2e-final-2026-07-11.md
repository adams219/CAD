# GMTITLE fresh 원본 전체 변환 최종 검증 이력

날짜: 2026-07-11  
브랜치: `codex/gm-title`  
기준 커밋: `6fa7347`  
LSP 버전: `260711-title-residue-geometry-1`

> **후속 판정:** 이 문서는 당시 검증기가 A4 두 장의 일반 TEXT/MTEXT 제목값과 그 아래의 `0310_DR_표제란`, `0320_DR_표제란` 정적 제목 셸 INSERT를 제목 데이터로 통합 인식하지 못했던 중간 결과다. 따라서 `target-title-count: 13`과 A4 title-missing 판정은 현재 완료 기준이 아니다. 최신 기준과 15/15 결과는 `gmtitle-unified-title-shell-cleanup-2026-07-11.md`를 따른다.

## 목적

부분 변환 이력이 섞인 기존 작업복사본이 아니라, 보존된 미변환 원본의 새 복사본에서 A2/A3/A4 전체 흐름을 처음부터 다시 실행한다.

완료 기준은 다음과 같다.

1. 남은 원본 표제란과 도면틀이 모두 0이다.
2. A2 1장, A3 12장, A4 2장이 모두 대상 DR 도면틀로 남는다.
3. A2/A3 제목블록 13개가 모두 native-like GMTITLE 쌍이다.
4. A4 두 장은 검증된 source-title-missing 예외로 제목블록 없이 도면틀과 도면 내용을 유지한다.
5. 기존 표제란 잔여물, 고아 도면틀, 중복 쌍, 누락 속성이 0이다.
6. 저장 후 새 GstarCAD 세션에서도 `SWTITLEVERIFY_FINAL_OK`가 유지된다.
7. 원본 DWG의 SHA256은 바뀌지 않는다.

## 입력 파일 보호

원본:

```text
work\0000_A_DRP125_CP_ALL_260626_ORIGINAL_TEST_260711.dwg
SHA256: 3C7735569B7EBAC8300225A81CEFB441562AB656770E5FC8868099B559A959B2
```

fresh 작업복사본:

```text
work\0000_A_DRP125_CP_ALL_260626_fresh_e2e_260711_01.dwg
초기 SHA256: 3C7735569B7EBAC8300225A81CEFB441562AB656770E5FC8868099B559A959B2
```

복사 직후 두 파일의 해시는 같았다. 전체 변환이 끝난 뒤에도 원본 해시는 위 값과 동일했다.

## 초기 상태

읽기 전용 초기 로그:

```text
work\swtitle_fresh_e2e_initial_status_260711_01.txt
```

초기 판정:

```text
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
다음 용지: DR_A2_Outline
다음 제목블록: DR_titlea_3rd
```

## 실제 CAD 변환 순서

1. 최신 LSP를 로드하고 `SWTITLECONVERTNEXT`를 실행했다.
2. A2 최초 native GMTITLE을 만든 뒤, 고정 컨트롤 자동 선택이 남은 A3 제목블록 시트를 연속 처리했다.
3. 결과는 `OK_NATIVE_AUTOSELECT_BATCH_COMPLETE`, 남은 원본 표제란 시트는 0이었다.
4. `SWTITLESTATUS`가 `SWTITLEPREPARE` 정규화를 요구했다.
5. `SWTITLEPREPARE`에서 실제 `DR_titlea_3rd` 범위와 중첩 변환으로 판정한 기존 표제란 잔여물만 정리했다.
6. 다음 상태가 `NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION`이 되어 설치 원본 `DR_A4_Outline` 정의를 준비했다.
7. 상태가 `READY_FOR_TITLE_MISSING_OUTLINE`이 된 뒤 `SWTITLECONVERTNEXT`로 A4 두 장을 처리했다.
8. A4 변환 중 사용한 임시 `DR_titlea_3rd`는 제거됐고, 원래 위치와 크기의 `DR_A4_Outline` 및 title-missing native 표식만 남았다.
9. 결과는 `OK_TITLE_MISSING_OUTLINE_BATCH_COMPLETE`였다.
10. 마지막 `SWTITLESTATUS`는 `NEXT_FINAL_VERIFY_AND_DOUBLE_CLICK`, `SWTITLEVERIFY`는 `SWTITLEVERIFY_FINAL_OK`였다.

## 저장 후 재열기 결과

읽기 전용 재열기 로그:

```text
work\swtitle_fresh_e2e_final_reopen_260711_01.txt
work\swcad_title_verify_summary_last_fresh_e2e_final_reopen_260711_01.txt
```

재열기 결과:

```text
source-title-count: 0
source-frame-count: 0
frame-only-count: 0
target-title-count: 13
target-frame-count: 15
target-gmtitle-pair-count: 13
native-like-target-pair-count: 13
non-native-like-target-pair-count: 0
orphan-target-frame-count: 0
duplicate-target-pair-count: 0
A2/A3/A4: 1 / 12 / 2
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_OK
DBMOD after read-only commands: 0
```

독립 검증 기존 표제란 잔여물, 도면틀 정규화 후보, 도면틀 형상 경고, 선택 위험도 모두 0이었다.

## 실제 더블클릭 확인

- A2 `DR_titlea_3rd` 핸들 `16BF8`: `속성 블록 편집` 표가 열렸고 Sheet 값은 `A2`였다.
- A3 `DR_titlea_3rd` 핸들 `16C8D`: 같은 표 편집창이 열렸고 Sheet 값은 `A3`였다.
- 고급 속성 편집기나 REFEDIT로 열리지 않았다.
- A4 핸들 `1707E`, `17091`: 제목블록 없이 세로 도면틀과 기존 도면 내용이 유지됐다.

## A4 고아 문제 판단

구버전 full-flow 파일에서 보였던 A4 고아 도면틀 두 장은 fresh 전체 변환에서 재현되지 않았다.

fresh 결과는 다음을 모두 만족했다.

```text
title-missing 도면틀-only 대상: 2
고아 GMTITLE 도면틀: 0
제목블록 없는 대상 도면틀 오류: 0
```

따라서 이번 목표에서는 A4 전용 수정이나 새 명령어를 추가하지 않는다. 이후 다른 fresh 원본에서도 재현될 때만 별도 안건으로 조사한다.

## CAD 입력 재현 방지

GstarCAD 모델 화면에 일반 클립보드 기반 텍스트 입력을 보내면 명령문이 아니라 `_PASTECLIP`으로 해석될 수 있다. 이번 검증에서는 아직 fresh DWG를 열기 전 빈 `Drawing1.dwg`에서 이 동작을 확인했고, 즉시 취소해 객체를 배치하지 않았다.

이후에는 다음 규칙만 사용했다.

1. CAD 명령은 직접 키 입력으로 전송한다.
2. 긴 경로는 공백 없는 AutoLISP 식으로 조합한다.
3. GMTITLE 대화상자는 검증된 고정 컨트롤 자동 선택을 사용한다.
4. 화면 좌표로 용지/제목블록 드롭다운을 추측하지 않는다.
5. 변환 후 저장하고 새 세션의 읽기 전용 probe로 결과를 다시 확인한다.

## 결론

fresh 미변환 원본에서 A2/A3/A4 전체 변환, 잔여물 정리, A4 source-title-missing 예외, 실제 제목블록 편집창, 저장 후 재열기까지 통과했다.

이 결과를 현재 GMTITLE 흐름의 최종 실도면 기준 증거로 사용한다.
