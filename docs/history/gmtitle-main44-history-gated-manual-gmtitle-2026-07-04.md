# GMTITLE main44 이력 기반 수동 GMTITLE 선택 기준 - 2026-07-04

## 결론

현재 상태는 **완료 아님**이다.

`260704-history-gated-manual-gmtitle-main-44`는 A2/A3/A4 전체 변환을 완료한 버전이 아니라, 같은 실수를 반복하지 않도록 첫 native GMTITLE 선택 흐름을 안전하게 바꾼 버전이다.

## 왜 바꿨나

GitHub/로컬 이력과 실제 CAD 로그를 같이 확인한 결과, 아래 방향은 반복 실패 경로로 확정됐다.

```text
명령줄 -GMTITLE 자동 선택
키보드 자동 입력으로 GMTITLE 콤보박스 선택
화면 좌표/드롭다운 위치 기반 클릭 자동화
```

실제 GstarCAD 화면 테스트에서 `SWTITLECONVERT`가 요구한 값은 아래였다.

```text
용지/도면틀: DR_A2_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

하지만 대화식 `GMTITLE` 창은 일반 A3/A0 계열, `ISO 제목 블록 A`, `Object move ON`처럼 잘못된 기본값으로 열릴 수 있었다. 키보드 자동 입력도 원하는 DR 항목을 안정적으로 선택하지 못했다.

따라서 main44에서는 명령줄 `-GMTITLE` 자동 선택을 기본으로 사용하지 않는다.

## 코드 변경

기준 파일:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

변경 내용:

- LSP 버전을 `260704-history-gated-manual-gmtitle-main-44`로 올렸다.
- `*swcad-title-allow-commandline-gmtitle*` 기본값을 `nil`로 추가했다.
- `SWTITLECONVERT` 내부 첫 native GMTITLE 단계에서 명령줄 `-GMTITLE` 자동 선택을 기본으로 건너뛴다.
- 건너뛴 이유를 로그에 남긴다.
- 대화식 `GMTITLE` 창에서는 기본값/키보드 자동 입력 결과를 믿지 말고 로그의 DR 용지/제목블록을 눈으로 확인하라고 출력한다.

## 유지한 원칙

공개 사용자 명령은 계속 네 개다.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

새로운 A3/A4 전용 공개 명령은 만들지 않았다.

## 다음 검증

2026-07-04 추가로 가벼운 GstarCAD `/b` 로드 probe를 실행했다.

```text
work\swtitle_version_probe_main44_260704.txt
```

결과:

```text
Load result: OK
Loaded version: 260704-history-gated-manual-gmtitle-main-44
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Command-line GMTITLE enabled: no
Probe completed: yes
```

이 결과는 LSP 로드와 명령 등록, 명령줄 `-GMTITLE` 자동 선택 비활성화를 증명한다.
단, 실제 A2/A3/A4 변환 완료 증거는 아니다.

추가로 읽기 전용 통합 명령 실행도 확인했다.

```text
work\swtitle_lsp_compare_main44_260704.txt
```

결과:

```text
Run: SWTITLEVERSION
Result: OK SWTITLEVERSION status=<status variable missing>
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

`SWTITLEVERIFY_FINAL_FAIL`은 변환 전 테스트 DWG라 target GMTITLE 객체가 없다는 정상 진단이다.
즉 main44의 읽기 전용 명령 실행은 검증됐지만, 실제 변환 완료는 아직 아니다.

실제 CAD 작업복사본에서 다음 순서로 확인해야 한다.

```text
APPLOAD
SWTITLEVERSION
SWTITLESTATUS
SWTITLECONVERT
```

`SWTITLECONVERT`에서 GMTITLE 창이 열리면 아래 값을 사람이 직접 확인한다.

```text
용지/도면틀: 로그가 요구한 DR_A*_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

확인할 로그:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_transfer_apply_last.txt
```

기대되는 새 증거:

```text
이력 기준으로 명령줄 -GMTITLE 자동 선택은 사용하지 않습니다.
이유: 실제 CAD 테스트에서 DR 용지/제목블록을 잘못 고르는 사례가 확인됐습니다.
```

이 문구가 나오면 main44의 반복 실수 방지 gate가 적용된 것이다.

## 완료 기준

main44 자체의 완료 기준은 아래까지만이다.

```text
SWTITLEVERSION이 260704-history-gated-manual-gmtitle-main-44 표시
SWTITLECONVERT가 명령줄 -GMTITLE 자동 선택을 기본으로 건너뜀
대화식 GMTITLE 선택값 확인 안내가 출력됨
잘못된 GMTITLE 기본값이면 OK를 누르지 않고 취소할 수 있음
```

전체 프로젝트 완료 기준은 여전히 별도다.

```text
SWTITLEVERIFY_FINAL_OK
대표 A2/A3/A4 DR_titlea_3rd 더블클릭 시 GMTITLE 표 편집창 열림
A3 도면틀/표제란 중복 없음
A4 frame-only 누락 없음
도면 내부 번호/주석/텍스트 삭제 없음
```
