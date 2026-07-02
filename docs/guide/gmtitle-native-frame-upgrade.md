# GMTITLE native A3/A4 업그레이드 가이드

이 문서는 SOLIDWORKS에서 저장한 DWG의 도면틀/표제란을 GstarCAD Mechanical `GMTITLE` 기반 도면틀/표제란으로 바꾸는 현재 작업 흐름을 정리한다.

## 핵심 원인

`SWTITLETRANSFERFASTBATCH`는 여러 장을 빠르게 맞추기 위해 기존 native GMTITLE 쌍을 preserve-copy 방식으로 복사한다. 이 방식은 모양, 좌표, 속성값은 맞출 수 있지만 GstarCAD가 더블클릭 때 사용하는 내부 native 인식 정보가 모든 복제본에 완전히 새로 생기지는 않는다.

그래서 일부 A3/A4 표제란은 보기에는 맞아도 더블클릭 시 GMTITLE 표 편집창이 아니라 `GMPOWEREDIT`, `REFEDIT`, 고급 속성 편집기 쪽으로 열릴 수 있다.

해결은 복제본으로 남은 A3/A4 쌍을 실제 `GMTITLE` 대화창에서 만든 fresh native GMTITLE 쌍으로 한 장씩 교체하는 것이다.

## 최신 LSP 로드

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
```

정상 로드 예:

```text
swcad_title_scale.lsp ready 260702-a3a4-strict-native-recheck-3
```

로드된 버전만 빠르게 확인하려면:

```text
SWTITLEVERSION
```

반드시 아래처럼 나와야 한다.

```text
SWTITLE LSP version: 260702-a3a4-strict-native-recheck-3
```

## 현재 상태 확인

읽기 전용 확인 명령:

```text
SWTITLEMULTIPREVIEW
SWTITLEFASTSTATUS
SWTITLEUPGRADENATIVESTATUS
SWTITLEGMTITLEVERIFYALL
SWTITLENATIVEFRAMECHECK
SWTITLEDOUBLECLICKCHECK
SWTITLEROLECHECK
SWTITLEA3A4FIXPLAN
SWTITLEVERSION
SWTITLENEXTSTEP
```

현재 상태 로그를 한 번에 갱신하려면 아래 명령을 사용할 수 있다. 도면 데이터는 바꾸지 않는다.

```text
SWTITLESTATUSREFRESH
```

이 명령은 내부적으로 `SWTITLEROLECHECK`, `SWTITLEA3A4FIXPLAN`, `SWTITLENEXTSTEP`, `SWTITLEUPGRADENATIVESTATUS`, `SWTITLEGMTITLEVERIFYALL`, `SWTITLENATIVEFRAMECHECK`, `SWTITLEDOUBLECLICKCHECK`를 순서대로 다시 실행한다.

먼저 볼 요약 로그:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_status_refresh_last.txt
```

더블클릭 기준점과 native 재검토 필요 여부는 아래 로그에서 본다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_double_click_check_last.txt
```

역할 판정 자체 테스트는 아래 로그에서 본다. `native-finalize`와 `native-frame-only`가 `legacy-uncertain=yes`, `safe-native-source=no`로 나오고 결과가 `OK_ROLE_CLASSIFICATION`이어야 한다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_role_check_last.txt
```

A3/A4를 몇 장 고쳐야 하는지와 전체 후보 처리 기준은 아래 로그에서 본다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swcad_title_a3a4_fix_plan_last.txt
```

CAD 명령행 입력 상태가 불안하면 명령어를 직접 타이핑하지 말고 `APPLOAD`로 아래 runner 파일을 선택한다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\runners\swtitle_guard4_status_refresh.lsp
```

이 runner는 버전 확인과 읽기 전용 상태 갱신까지만 한다.

runner 파일은 `swcad_title_scale.lsp`를 자동으로 다시 찾고 로드한다. 이미 최신 `260702-a3a4-strict-native-recheck-3` 버전의 `swcad_title_scale.lsp`가 로드되어 있으면 그대로 실행하고, 아니면 선택한 runner와 같은 저장소 안의 파일, CAD 지원 경로, 현재 사용자 `Documents\CAD tool` 계열 경로를 순서대로 확인한다. 그래도 찾지 못하면 먼저 `swcad_title_scale.lsp`를 직접 `APPLOAD`한 뒤 runner를 다시 로드한다.

A3/A4 교체 후보 개수만 빠르게 확인하려면 아래 runner를 `APPLOAD`한다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\runners\swtitle_guard4_a3a4_fix_plan.lsp
```

이 runner는 `SWTITLEVERSION`, `SWTITLEROLECHECK`, `SWTITLEA3A4FIXPLAN`만 실행한다. 도면 데이터는 바꾸지 않고, A3/A4 교체 후보 수만 확인하는 용도다.

`SWTITLEA3A4FIXPLAN` 로그에 `Possible accidental command text entities`가 1 이상으로 나오면, A3/A4 교체 전에 `SWTITLECOMMANDTEXTSCAN`으로 먼저 확인한다.

명령어가 도면 위 흰 글자로 들어간 것 같으면 아래 runner를 먼저 `APPLOAD`한다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\runners\swtitle_guard4_command_text_scan.lsp
```

로그를 확인한 뒤 실제 명령 잔여물이라고 판단되면 작업복사본에서만 아래 runner로 정리한다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\runners\swtitle_guard4_command_text_clean.lsp
```

`SWTITLEUPGRADENATIVESTATUS`에서 아래처럼 나오면 아직 끝난 것이 아니다.

```text
Result: NEEDS_NATIVE_A3A4_UPGRADE
A3/A4 target pairs needing native replacement: 6
```

이 상태의 의미는 A3/A4 중 6개가 아직 clone/non-native 상태라 더블클릭 인식 문제가 남아 있다는 뜻이다.

로그 상단의 버전이 `260702-a3a4-strict-native-recheck-3`가 아니면 오래된 판단일 수 있다. 예를 들어 `260702-native-guided-upgrade-status` 같은 예전 버전 로그는 `SWTITLEUPGRADENATIVEA3A4BATCH`의 전체 후보 기본값이나 최신 `native-finalize/native-frame-only` 재검사 기준을 반영하지 않는다. 반드시 최신 LSP를 APPLOAD한 뒤 로그를 새로 만든다.

예전 로그에서 `A3/A4 target pairs needing native replacement: 0` 또는 `native-like=yes`가 나오더라도, `title-role=native-finalize`나 `title-role=native-frame-only`가 같이 보이면 최종 성공으로 보지 않는다. 그 마커는 “GMTITLE을 만든 뒤 LISP가 위치를 맞춘 결과”라서 모양은 맞지만 GstarCAD 더블클릭 인식이 첫 장처럼 보장되지 않는다. 최신 LSP에서는 이런 항목을 다시 native 교체 후보로 올린다.

## A3/A4 native 교체 방법

가장 안전한 방식은 한 장씩 처리하는 것이다.

```text
SWTITLEA3A4NEXT
```

실수로 범용 명령인 `SWTITLEUPGRADENATIVEONE`을 입력해도 최신 버전에서는 A3/A4 재검사 후보를 먼저 잡고, 없을 때만 기존 clone 후보를 찾는다.

여러 장을 이어서 처리하려면:

```text
SWTITLEUPGRADENATIVEA3A4BATCH
```

`SWTITLEUPGRADENATIVEA3A4BATCH`는 현재 잡힌 A3/A4 후보 전체를 기본값으로 처리한다. 즉 프롬프트에서 Enter를 눌러도 전체 후보 수가 기본값이다. 한 장만 먼저 시험하려면 `SWTITLEA3A4NEXT`를 사용한다. `SWTITLEUPGRADENATIVEA3A4ALL`은 같은 전체 후보 처리용 별칭으로 남겨두었다.

명령행 직접 입력이 불안하면 아래 runner를 `APPLOAD`해도 같은 명령을 시작할 수 있다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\runners\swtitle_guard4_a3a4_upgrade_all.lsp
```

한 장씩 조심스럽게 교체하려면 아래 runner를 `APPLOAD`한다. 한 번 로드할 때마다 다음 A3/A4 후보 1장만 처리한다.

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\runners\swtitle_guard4_a3a4_upgrade_next.lsp
```

기존 명령도 사용할 수 있다.

```text
SWTITLEUPGRADENATIVEA3A4BATCH
```

중요: 최신 버전에서는 `SWTITLEUPGRADENATIVEA3A4BATCH`의 기본값이 전체 후보 수다. 예전 버전에서는 Enter가 1장만 처리해서 첫 장만 고쳐지는 일이 있었으므로, `SWTITLEVERSION`에서 `260702-a3a4-strict-native-recheck-3`가 보이는지 먼저 확인한다.

이 명령은 `SCRIPT` 안에서 실행하면 안 된다. 각 장마다 GMTITLE 대화창에서 DR 용지와 `DR_titlea_3rd`를 확인해야 하기 때문이다.

주의: `SWTITLEUPGRADENATIVEA3A4ALL`과 `SWTITLEUPGRADENATIVEA3A4BATCH`는 이미 만들어진 A3/A4 GMTITLE 쌍의 native 인식 문제를 고치는 명령이다. 아직 원본 SOLIDWORKS 도면틀로 남아 있는 A4 `frame-only sheets`를 새 GMTITLE로 만드는 명령은 아니다. A4가 `Remaining frame-only sheets`로 남아 있으면 아래 A4 단계를 따로 처리해야 한다.

## GMTITLE 대화창 선택값

대화창이 열리면 ISO 기본값을 그대로 확인하면 안 된다.

반드시 로그에 출력된 용지와 아래 제목블록을 선택한다.

```text
A3 용지: DR_A3_Outline
A4 용지: DR_A4_Outline
제목블록: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

대화창이 여전히 `A3 (297x420mm)`, `ISO 제목 블록 A` 같은 ISO 기본값이면 취소하고 다시 실행한다.

## A4 frame-only 시트

A4가 `frame-only sheets`로 남아 있으면 A3 native 교체와 별도 단계로 처리한다.

```text
SWTITLEFASTSTATUS
SWTITLEFRAMEONLYAPPLY
SWTITLETRANSFERFASTBATCH
SWTITLEUPGRADENATIVESTATUS
```

A4도 최종적으로는 `DR_A4_Outline` 프레임과 `DR_titlea_3rd` 표제란이 생겨야 한다.

## 성공 기준

최종 검증:

```text
SWTITLEGMTITLEVERIFYALL
SWTITLENATIVEFRAMECHECK
SWTITLEDOUBLECLICKCHECK
```

좋은 상태의 핵심 결과:

```text
Remaining source title candidates: 0
Remaining source sheet frame candidates: 0
A3/A4 target pairs needing native replacement: 0
Clone target frame counts: <none>
Result: OK_A2_A3_A4_NATIVE_FRAME_READY_FOR_MANUAL_CHECK
```

`SWTITLEDOUBLECLICKCHECK`는 읽기 전용으로 각 `DR_titlea_3rd` 표제란의 더블클릭 기준점을 출력한다. 마지막으로 CAD 화면에서 A2, A3, A4 대표 표제란을 직접 더블클릭한다. 성공 기준은 `GMPOWEREDIT`, `REFEDIT`, 고급 속성 편집기가 아니라 GMTITLE 표 편집창이 열리는 것이다. 만약 도면틀을 더블클릭하면 정상 쌍이어도 `GMPOWEREDIT` 또는 `REFEDIT`가 열릴 수 있으므로, 반드시 표제란 블록을 확인한다.

첫 장만 정상이고 나머지 A3/A4가 `GMPOWEREDIT`로 열리는 경우에는 보통 첫 장의 role은 `native-apply`이고, 실패하는 장들은 `native-finalize` 또는 `native-frame-only`다. 이 경우 `SWTITLEUPGRADENATIVEA3A4BATCH`를 최신 LSP에서 실행해 각 장을 `native-upgrade`로 교체해야 한다.

## 흰 명령어 글자 잔여물

CAD가 점 지정, 문자 입력, 객체 이동 같은 입력 상태일 때 명령어를 잘못 넣으면 `SWTITLE...` 같은 흰 글자가 도면에 남을 수 있다. 먼저 읽기 전용으로 확인한다.

```text
SWTITLECOMMANDTEXTSCAN
```

로그에서 실제 도면 주석이 아니라 명령어 잔여물이라고 확인되면, 작업복사본에서만 아래 명령으로 지운다.

```text
SWTITLECOMMANDTEXTCLEANSAFE
```

원본 DWG에서는 바로 지우지 말고, 작업복사본에서 삭제 결과를 먼저 확인한다.

## 예전 로그 해석

`0000_A_DRP125_CP_ALL_260626_test_workcopy_02.dwg`의 예전 로그는 아래처럼 성공처럼 보일 수 있다.

```text
Result: OK_A3A4_NATIVE_UPGRADE_COMPLETE
Result: OK_VERIFY_ALL_GMTITLE_READY
Result: OK_A2_A3_A4_NATIVE_FRAME_READY_FOR_MANUAL_CHECK
```

하지만 같은 로그 안에 `title-role=native-finalize`와 `title-role=native-frame-only`가 있으면 최종 성공으로 보지 않는다. 첨부 로그 기준으로는 A3 `native-finalize`가 11장, A4 `native-frame-only`가 2장이므로, 최신 LSP를 다시 로드하면 최대 13장이 `finalize-or-frame-only-marker-needs-native-recheck` 사유로 다시 A3/A4 native 교체 후보에 올라와야 한다. 실제 숫자는 현재 열린 DWG 상태에 따라 달라질 수 있으므로 `SWTITLEA3A4FIXPLAN` 로그를 기준으로 본다.

따라서 다음 작업은 최신 LSP를 다시 로드한 뒤 `SWTITLESTATUSREFRESH` 또는 `SWTITLEUPGRADENATIVESTATUS`로 새 후보 개수를 확인하고, `SWTITLEUPGRADENATIVEA3A4BATCH` 또는 한 장씩 `SWTITLEA3A4NEXT`로 native 교체하는 것이다. 남은 A4 frame-only 원본 시트가 있으면 그 뒤에 별도 처리한다.
