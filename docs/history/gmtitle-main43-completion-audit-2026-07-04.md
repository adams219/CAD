# GMTITLE main43 완료 감사 - 2026-07-04

## 결론

현재 상태는 **완료 아님**이다.

`260704-frame-definition-first-main-43` 기준으로 4단계 통합 흐름, 도면틀 정의 판정,
정규화 차단 gate, 복사본 비교 결론은 구현/검증됐다.
하지만 실제 작업복사본 DWG에서 A2/A3/A4 전체 변환과 대표 제목블록 더블클릭 확인은 아직 남아 있다.

## 현재 기준 파일

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
version: 260704-frame-definition-first-main-43
```

테스트용 복사본:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_current_main43_compare_copy.lsp
```

이 복사본은 원본과 SHA256 해시가 동일하다.

```text
SHA256:
99ABB6DBF8AD802E402BC4AEC163E9B59A4535516B368FB8BB9B2BE30F2DF585
```

## 요구사항별 감사

| 요구사항 | 현재 증거 | 판정 |
| --- | --- | --- |
| 사용자는 4단계 흐름을 사용 | 공개 명령은 `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY`, 보조 `SWTITLEVERSION`, `SWSCALESCAN`만 노출 | 구현됨 |
| 용지마다 임시 공개 명령을 만들지 않음 | `SWTITLEA3FRAMECLEAN`, `SWTITLECLEANORPHANFRAME`, `SWTITLEA3A4*`, `SWTITLEFRAMEONLY*` 계열은 공개 `c:` 명령에서 제외 | 구현됨 |
| `SWTITLESTATUS`가 A2/A3/A4 수량, 원본/대상 개수, 도면틀 정의, A4 bbox 위험, 다음 조치를 표시 | `swcad-title-integrated-status`, `swcad-title-integrated-structure-diagnosis`, `swcad-title-next-step` 경로 존재. `work\swtitle_lsp_compare_main42_260704.txt`에서 런타임 실행 확인 | 구현 및 읽기 전용 런타임 확인 |
| `SWTITLEPREPARE`가 A2/A3/A4 공통 도면틀 정의 정규화 | `swcad-title-frame-definition-class-records`, `swcad-title-frame-definition-blocking-records-by-class`, `swcad-title-integrated-prepare` 경로 존재 | 구현됨 |
| `SWTITLEPREPARE`가 도면틀 안의 표제란 영역 후보를 정리하고 외곽선/눈금/좌표 표시는 보호 | `swcad-title-frame-embedded-title-protected-p`와 공통 embedded-title scan/clean 경로 존재 | 구현됨, 실제 A3 정리 재검증 필요 |
| 정상 `DR_titlea_3rd` 제목블록을 삭제하지 않음 | 정규화는 도면틀 정의 내부 후보와 고아 도면틀/명령어 텍스트를 분리해서 처리 | 정적 구현 확인, 실제 도면 재검증 필요 |
| `SWTITLECONVERT`가 정규화 전 변환을 막음 | `work\swtitle_convert_gate_fixture_main43_260704.txt`에서 `DR_A3_Outline: embedded-title`, `SWTITLECONVERT status: ABORT_FRAME_DEFINITION_NOT_NORMALIZED`, `Gate matched: yes` 확인 | synthetic 런타임 확인 |
| `SWTITLECONVERT`가 기존 텍스트 추출, 용지 크기 자동 인식, native 기준 객체 생성, 나머지 자동 처리, 잔여물 제거를 한 흐름에서 처리 | 내부 기존 transfer/fast/native/frame-only 경로가 `swcad-title-integrated-convert`에서 분기됨 | 구현됨, 실제 전체 변환 검증 필요 |
| `SWTITLEVERIFY`가 중복, 내장 표제란, GMTITLE 개수, A2/A3/A4 누락, 고아 도면틀, 더블클릭 대상, OK/WARN/FAIL을 요약 | `swcad-title-integrated-verify-final-summary` 경로 존재. `work\swtitle_lsp_compare_main42_260704.txt`에서 `SWTITLEVERIFY` 실행 확인 | 구현 및 읽기 전용 런타임 확인 |
| 복사본 테스트 후 어느 쪽이 좋은지 비교 | `docs\history\gmtitle-current-copy-comparison-2026-07-04.md`에 원본 main43 채택 결론 기록 | 완료 |
| 실제 작업복사본 변환 완료 | 아직 `SWTITLEVERIFY_FINAL_OK` 또는 더블클릭 완료 증거 없음 | 미완료 |

## 채택한 런타임 증거

원본 main43 로드와 읽기 전용 명령 실행:

```text
work\swtitle_lsp_compare_main42_260704.txt

Load result: OK
Loaded version: 260704-frame-definition-first-main-43
Run: SWTITLESTATUS -> OK, status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY -> OK, status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

도면틀 정의 차단 fixture:

```text
work\swtitle_convert_gate_fixture_main43_260704.txt

DR_A2_Outline: outline-only, embedded=0
DR_A3_Outline: embedded-title, embedded=4
Blocking records before convert: 1
SWTITLECONVERT status: ABORT_FRAME_DEFINITION_NOT_NORMALIZED
Gate matched: yes
```

도면틀 정의 판정 fixture:

```text
work\swtitle_framedef_fixture_probe_main43_260704.txt

DR_A2_Outline: outline-only, embedded=0
DR_A3_Outline: embedded-title, embedded=5
Blocking records: 1
Blocker: DR_A3_Outline / embedded-title
Runtime check completed: yes
```

## 아직 완료되지 않은 검증

아래 항목은 실제 GstarCAD 작업복사본에서 확인해야 한다.

```text
1. 최신 원본 LSP를 APPLOAD
2. SWTITLEVERSION이 260704-frame-definition-first-main-43인지 확인
3. SWTITLESTATUS 실행
4. SWTITLESTATUS가 SWTITLEPREPARE를 요구하면 SWTITLEPREPARE 실행 후 다시 SWTITLESTATUS
5. SWTITLESTATUS가 SWTITLECONVERT를 요구하면 SWTITLECONVERT 실행
6. GMTITLE 창에서는 로그가 요구한 DR_A*_Outline, DR_titlea_3rd만 선택
7. Frame positioning: ON, Object move: OFF 확인
8. 변환 1회 후 항상 SWTITLESTATUS 재실행
9. 필요한 만큼 SWTITLECONVERT 반복
10. SWTITLEVERIFY 실행
11. 대표 A2/A3/A4 DR_titlea_3rd 제목블록을 더블클릭해 GMTITLE 표 편집창 확인
```

## 완료 조건

아래 조건을 모두 만족해야 목표 완료로 본다.

```text
남은 원본 SolidWorks 표제란/도면틀 후보: 0
도면틀 정의 정규화 차단 항목: 0
A3/A4 native 교체 필요 쌍: 0
고아 GMTITLE 도면틀: 0
원본 기준 A2/A3/A4 수량과 대상 DR_A*_Outline 수량 일치
대상 DR_titlea_3rd 제목블록 수량 일치
SWTITLEVERIFY 최종 결과: OK
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
```

`WARN`이 남더라도, 그 WARN이 더블클릭 수동 확인만 요구하는 제한적인 상태인지 별도 판단해야 한다.

## 2026-07-04 추가 확인: 작업복사본 `/b` 확인 제외

아래 작업복사본과 그 복사본을 숨김 GstarCAD `/b` 방식으로 읽기 전용 확인하려고 시도했다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_actual_workcopy_main43_probe_260704.dwg
```

실행한 명령은 `SWTITLEVERSION`, `SWTITLESTATUS`, `SWTITLEVERIFY`만 포함했고 변환/삭제 명령은 포함하지 않았다.
하지만 두 경우 모두 90초 안에 로그 파일이 생성되지 않았고, 숨김 `gcad.exe` 프로세스가 남아 종료했다.
성공 이력이 있는 기존 SCRIPT로도 같은 결과였다.

따라서 이 시도는 완료 증거로 채택하지 않는다.
가능한 원인은 DWG 열기 초기 단계의 복구/잠금/대화상자/단일 인스턴스 처리로 보이며,
다음 검증은 실제 GstarCAD 화면에서 작업복사본을 연 상태로 `SWTITLESTATUS`부터 직접 실행하는 방식이 더 안전하다.

혼동을 막기 위해 이 확인용 임시 wrapper와 DWG 복사본은 삭제했다.

## 2026-07-04 추가 확인: 실제 GstarCAD 화면 작업복사본 상태 진단

숨김 `/b` 확인 대신 실제 GstarCAD 화면에서 원본 작업복사본을 직접 수정하지 않도록 아래 확인용 복사본을 만들었다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03_main43_status_probe_260704.dwg
```

GstarCAD 화면에서 최신 LSP를 직접 로드했다.

```text
(load "C:/Users/DR-DESIGN/Documents/CAD tool/src/tools/gmtitle/swcad_title_scale.lsp")

로드 버전:
260704-frame-definition-first-main-43
```

그 뒤 읽기 전용 명령을 실행했다.

```text
SWTITLEVERSION
SWTITLESTATUS
SWTITLEVERIFY
```

`SWTITLESTATUS` 실제 로그:

```text
work\swcad_title_structure_diagnosis_last.txt
work\swcad_title_next_step_last.txt
work\swcad_title_fast_status_last.txt
```

핵심 결과:

```text
DWG 파일: C:/Users/DR-DESIGN/Documents/CAD tool/work/0000_A_DRP125_CP_ALL_260626_test_workcopy_03_main43_status_probe_260704.dwg
작업 폴더 복사본: 예
원본 표제란/도면틀: 13 / 15
표제란 없는 도면틀 시트: 2
변환 기준 전체 용지 수: A2=1, A3=12, A4=2
도면틀 정의 내부 표제란 형상 후보: 전체=0, A3=0, A4=0
오염 의심 대상 도면틀 정의: <없음>
대상 도면틀 수: 0
현재 필요한 대상 용지 누락: A2, A3, A4
결과: NEXT_CREATE_FIRST_NATIVE_GMTITLE
다음: SWTITLECONVERT를 실행하세요. 첫 native GMTITLE 단계를 내부에서 엽니다.
```

`SWTITLEVERIFY` 실제 로그:

```text
work\swcad_title_verify_summary_last.txt
work\swcad_title_gmtitle_verify_all_last.txt
work\swcad_title_double_click_check_last.txt
```

핵심 결과:

```text
남은 원본 표제란 후보: 13
남은 원본 도면틀 후보: 15
대상 도면틀 수: 0
대상 제목블록 수: 0
대상 도면틀 수량 부족: A2 필요 1 현재 0, A3 필요 12 현재 0, A4 필요 2 현재 0
결과: SWTITLEVERIFY_FINAL_FAIL
최종 결과: FAIL
```

이 `FAIL`은 LSP 로드 실패나 상태 진단 실패가 아니다.
아직 첫 native GMTITLE을 만들기 전이므로 대상 `DR_A*_Outline`/`DR_titlea_3rd`가 없다는 정상적인 미완료 진단이다.

따라서 현재 최신 증거 기준 다음 실제 단계는 아래와 같다.

```text
SWTITLECONVERT
```

단, `SWTITLECONVERT`는 GMTITLE 대화상자에서 사용자가 아래를 눈으로 확인해야 하는 변경 명령이다.

```text
용지/도면틀: DR_A2_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

이 단계부터는 도면을 변경하므로, 계속 확인용 복사본에서만 진행한다.

## 2026-07-04 추가 확인: 첫 `SWTITLECONVERT` 대화식 GMTITLE 선택 중단

같은 확인용 복사본에서 `SWTITLECONVERT`를 시작해 첫 native GMTITLE 생성 단계까지 진입했다.

```text
SWTITLECONVERT
YES
```

로그:

```text
work\swcad_title_transfer_apply_last.txt
```

핵심 확인:

```text
원본 표제란 INSERT: 0_DR_표제란_FTAP
원본 도면틀 INSERT: 0_DR-A2 FROM_HYUN
감지된 용지 크기: A2
Expected native GMTITLE frame block after detection: DR_A2_Outline
Expected native GMTITLE 제목블록: DR_titlea_3rd
명령줄 -GMTITLE 새 INSERT 수: 0
명령줄 GMTITLE 제목블록: <없음>
명령줄 GMTITLE 도면틀: <없음>
```

그 뒤 GstarCAD의 대화식 `GMTITLE` 창이 열렸지만 기본값은 아래처럼 잘못 열렸다.

```text
용지/형식: A3 또는 A0 계열로 선택됨
제목블록: ISO 제목 블록 A
Frame positioning: OFF
Object move: ON
```

자동 입력으로 `DR_A2_Outline`을 선택하려고 했지만, GstarCAD 콤보박스가 원하는 항목을 안정적으로 선택하지 못하고 `A0(840x1189mm)`처럼 다른 항목으로 바뀌었다.
따라서 이 방식은 사용하지 않기로 하고 `Escape`로 취소했다.

결과:

```text
Native GMTITLE new INSERT count: 0
Native GMTITLE title insert: <없음>
Native GMTITLE frame insert: <없음>
결과: ABORT_NO_NATIVE_GMTITLE_TITLE
Removed partial/new GMTITLE inserts: 0
기존 SOLIDWORKS 표제란/도면틀 내용은 삭제하지 않았습니다.
```

이 시도에서 확정한 점:

- 명령줄 `-GMTITLE` 자동 선택은 현재 GstarCAD에서 계속 신뢰할 수 없다.
- 대화식 `GMTITLE` 창 기본값은 로그가 요구한 DR 값과 다르게 열릴 수 있다.
- 키보드 자동 입력으로 `DR_A2_Outline`을 선택하는 것도 안정적이지 않다.
- 잘못된 선택 상태에서는 확인하지 말고 취소해야 한다.
- 이번 취소에서는 기존 도면 내용이 삭제되지 않았다.

따라서 다음 실제 변환 단계는 자동 선택이 아니라 사용자가 `GMTITLE` 창에서 직접 아래 값을 확인하는 방식으로 진행해야 한다.

```text
용지/도면틀: DR_A2_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```
