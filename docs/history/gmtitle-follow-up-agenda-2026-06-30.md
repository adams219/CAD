# GMTITLE 후속 안건 - 2026-06-30

## 최신 상태: preserve-copy fast clone A2/A3/A4 검증 완료

상태: 현재 `preserve-copy` 경로는 핵심 편집 동작 검증을 통과했다.

- 코드 버전: `260630-preserve-copy-fast-clone-a4`
- 테스트 복사본:
  - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_preservecopy_test_260630_01.dwg`
- `SWTITLETRANSFERFASTBATCH`는 복제된 native link 검사 기준을 완화한 뒤, 남아 있던 A4 frame-only 시트를 변환했다.
- 완화 기준:
  - `visible-target-frame`도 사용 가능한 cloned link 종류로 인정한다.
- `SWTITLEGMTITLEVERIFYALL` 결과:
  - `DR_A2_Outline`: 1
  - `DR_A3_Outline`: 12
  - `DR_A4_Outline`: 2
  - `DR_titlea_3rd`: 15
  - 남은 원본 표제란 후보: 0
  - 남은 원본 도면틀 후보: 0
  - 기타 target이 아닌 title-like insert: 0
  - 모든 표제란은 attribute 11개, 비어 있지 않은 attribute 11개, 누락 tag 0개, native link 1개를 가진다.
- CAD에서 직접 더블클릭 검증:
  - A4 표제란 handle `17AEF`: `속성 블록 편집` 창으로 열림.
  - A3 표제란 handle `17919`: `속성 블록 편집` 창으로 열림.
  - A2 표제란 handle `16BE8`: `속성 블록 편집` 창으로 열림.
  - 위 검증에서는 Advanced Attribute Editor가 열리지 않았다.
- 남은 경고:
  - `SWTITLEGMTITLEVERIFYALL`은 아직 `WARN_TARGET_FRAME_DEFS_CONTAMINATED`를 반환한다.
  - 이유는 현재 child-name detector가 `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline`을 오염 후보로 잡기 때문이다.
  - `preserve-copy` 경로에서는 이 상태를 하드 블로커가 아니라 검증 경고로 다룬다.
- 아직 남은 문제:
  - native GMTITLE exemplar가 전혀 없는 깨끗한 DWG에서는 첫 native GMTITLE을 완전 자동으로 만들 수 없다.
  - `SWTITLETRANSFERBOOTSTRAPFAST`는 첫 선택값인 `DR_A2_Outline + DR_titlea_3rd`를 올바르게 감지할 수 있다.
  - 하지만 native GMTITLE picker dialog는 아직 수동 선택 없이 안정적으로 제어하지 못한다.

## 미해결 안건: 복제된 GMTITLE 편집 동작은 완전히 증명되지 않음

상태: 역사적으로 중요한 안건이다. 다만 현재 `preserve-copy fast clone`은 위 테스트 복사본에서 A2/A3/A4 더블클릭 검증을 통과했다.

이전에는 복제된 `DR_titlea_3rd` 표제란 블록을 더블클릭했을 때 native GMTITLE 표 편집창이 아니라 Advanced Attribute Editor가 열리는 경우가 있었다.

이 말은 현재 clone 경로가 화면에 보이는 표제란 데이터와 기본 native xdata를 옮기는 데는 유용하지만, GstarCAD Mechanical이 표제란을 native GMTITLE 객체로 인식하기 위해 사용하는 모든 내부 조건을 완전히 재현했다고는 아직 증명되지 않았다는 뜻이다.

## 현재 증거

- 전체 테스트 복사본에는 다음 insert가 있다.
  - `DR_A2_Outline`: 1
  - `DR_A3_Outline`: 12
  - `DR_titlea_3rd`: 13
- `SWTITLEGMTITLEVERIFYALL`은 13개 표제란 모두에 대해 다음을 보고했다.
  - `attrs=11`
  - `nonempty=11`
  - `missing-tags=0`
  - `native-links=1`
- 남은 기존 SOLIDWORKS 표제란 후보: 0
- 남은 기존 title-like insert: 0
- 남은 원본 도면틀은 A4 frame-only 시트 2장뿐이다.

### 추가 A4 native 테스트

- 테스트 복사본:
  - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_a4_native_test_260630_01.dwg`
- native `GMTITLE` 실행 조건:
  - 용지: `DR_A4_Outline`
  - 제목블록: `DR_titlea_3rd`
  - frame position: off
  - object move: off
- 이후 `SWTITLEGMTITLEVERIFYALL` 결과:
  - `DR_A2_Outline`: 1
  - `DR_A3_Outline`: 12
  - `DR_A4_Outline`: 1
  - `DR_titlea_3rd`: 14
  - 14개 표제란 모두 `attrs=11`, `nonempty=11`, `missing-tags=0`, `native-links=1`
- `SWTITLEGMTITLELINKSCAN`은 중복 GMTITLE link handle이 없다고 보고했다.
- native A4 표제란은 보이는 frame insert handle이 아니라 내부 link handle인 `17AE0`을 사용했다.
- 이 동작은 cloned A3 패턴보다 native A2 패턴에 더 가깝다.
- 이 A4 native 테스트는 기본 표제란 값을 사용했고, 명령 기본 위치에 배치했다.
- 아직 기존 A4 텍스트 값을 옮기거나 기존 A4 source frame 2장을 제거하는 테스트는 아니었다.

### Frame-only A4 finalize 구현 테스트

- 추가된 명령:
  - `SWTITLEFRAMEONLYFINALIZE`
  - `SWTITLEFRAMEONLYCLONEAPPLY`
  - `SWTITLEFRAMEONLYCLONEBATCH`
- 같은 work copy에서 native/default `DR_A4_Outline + DR_titlea_3rd`를 1개 만든 뒤 `SWTITLEFRAMEONLYFINALIZE`를 테스트했다.
- 결과:
  - source frame-only insert `36E6` 처리됨.
  - native/default A4 GMTITLE을 `dx=2492.22576246`, `dy=0.42607942`만큼 이동.
  - attribute 설정: 4개
  - 기존 frame-only insert 삭제: yes
  - 기존 SOLIDWORKS 잔여물 삭제: 102개
  - `SWTITLEGMTITLEVERIFYALL`: `OK_VERIFY_ALL_GMTITLE_READY`
  - 남은 source frame-only 시트 수가 2장에서 1장으로 감소.

### 중요한 주의점

- 로그에서 이동된 `DR_A4_Outline` insert의 bbox 폭이 실제 A4 nominal 폭보다 훨씬 크게 나왔다.
- `SWTITLEGMTITLELINKSCAN`은 아직 `DR_A4_Outline: children=도면 세로 A4 From_HYUN`을 보고한다.
- 즉 frame-only finalize 명령 흐름은 동작하지만, 이 테스트 도면 안의 target `DR_A4_Outline` block definition은 아직 오염되어 있다.
- 실제 사용 전에 검증된 깨끗한 `DR_A*_Outline` definition을 import하거나 block-definition contamination check를 추가해야 한다.

## Frame Definition 오염 방지 장치

- 추가된 명령:
  - `SWTITLEFRAMEDEFCHECK`
- 현재 A4 work copy 테스트 결과:
  - `DR_A2_Outline`: `CONTAMINATED`, child `DR-A2 From_HYUN`
  - `DR_A3_Outline`: `CONTAMINATED`, child `DR-A3 From_HYUN`
  - `DR_A4_Outline`: `CONTAMINATED`, child `도면 세로 A4 From_HYUN`
  - 결과: `WARN_TARGET_FRAME_BLOCK_DEFINITION_CONTAMINATED`
- 이제 `SWTITLEGMTITLELINKSCAN`도 target frame block definition 안에 기존 source-like child insert가 있으면 `WARN_TARGET_FRAME_BLOCK_DEFINITION_CONTAMINATED`를 반환한다.
- fast clone frame insertion은 오염된 target frame block definition을 재사용하지 않도록 막는다.
- guard 테스트:
  - 남은 A4 frame-only source에 `SWTITLEFRAMEONLYCLONEAPPLY` 실행.
  - `ABORT_FRAME_ONLY_CLONE_FAILED`로 중단.
  - 로그에 target frame definition check 결과 포함.
  - 기존 frame-only sheet 내용은 삭제되지 않음.

## Frame Definition 안전 정리 명령

- 추가된 명령:
  - `SWTITLEFRAMEDEFCLEANSAFE`
- 목적:
  - 사용되지 않는 오염된 `DR_A*_Outline` block definition만 복구한다.
  - 오염된 target frame definition이 이미 existing insert에서 참조 중이면 이름을 바꾸지 않고 skip한다.
  - 오염된 definition의 insert 수가 0이면 `DR_A3_Outline_SWOLD_1` 같은 backup 이름으로 바꾼 뒤 GstarCAD 설치 폴더에서 깨끗한 definition을 import한다.
- 안전 규칙:
  - 쓰기 가능한 도면에서만 실행.
  - `Documents/CAD tool/work` 안의 복사본이거나, work 폴더 밖에서는 명시적으로 `EDIT` 확인 필요.
  - block definition을 바꾸기 전에 `YES` 확인 필요.
  - 현재 보이는 도면 내용은 삭제하지 않음.
- 현재 테스트 도면에서 기대되는 동작:
  - 기존 A4 work copy에서는 `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline`이 이미 참조 중이다.
  - 따라서 명령은 이들을 skip하고 `SKIP_REFERENCED_CONTAMINATED_FRAME_DEFS`를 보고해야 한다.
  - 이것은 의도된 동작이다. 참조 중인 오염 definition을 고치는 것은 조용히 이름을 바꿀 일이 아니라 별도의 rebuild 전략이 필요하다.

## Clean-start 기준 테스트

- Downloads의 원본 DWG에서 새 work copy 생성:
  - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_cleanstart_test_260630_01.dwg`
- `APPLOAD` 결과:
  - `swcad_title_scale.lsp ready 260630-frame-def-clean-safe`
- `SWTITLEFRAMEDEFCHECK` 결과:
  - `DR_A1_Outline`: 없음, OK
  - `DR_A2_Outline`: 없음, OK
  - `DR_A3_Outline`: 없음, OK
  - `DR_A4_Outline`: 없음, OK
  - 결과: `OK_TARGET_FRAME_BLOCK_DEFINITIONS`
- `SWTITLEMULTIPREVIEW` 결과:
  - source title candidates: 13
  - source sheet frame candidates: 15
  - title candidates with frame: 13
  - frame-only sheet candidates: 2
  - source sheet frame counts: `A2: 1`, `A3: 12`, `A4: 2`
  - title sheet counts: `A2: 1`, `A3: 12`
  - elapsed: 76 ms
- 결론:
  - 원본 SOLIDWORKS DWG는 처음부터 오염된 target `DR_A*_Outline` definition을 갖고 있지 않다.
  - 오염은 이전 conversion/import 경로에서 생겼다.
  - 다음 변환 테스트는 이 clean work copy에서 시작해야 한다.
  - 현재 guarded clone path가 가짜/오염 target definition 대신 실제 깨끗한 `DR_A*_Outline` definition을 import하는지 확인해야 한다.

## 빠른 남은 시트 batch 명령

- 추가된 명령:
  - `SWTITLETRANSFERFASTBATCH`
  - `SWTITLEFASTSTATUS`
  - `SWTITLETRANSFERBOOTSTRAPFAST`
- 목적:
  - `SWTITLEFASTSTATUS`는 fast route를 위한 read-only readiness check다.
  - 수정하기 전에 source title count, source frame count, frame-only count, A-size count를 보고한다.
  - 남은 source title sheet를 자동으로 모두 센다.
  - 남은 frame-only sheet를 자동으로 모두 센다.
  - 기존 검증된 native-GMTITLE clone path로 title sheet를 처리한다.
  - 그 다음 A4-like frame-only sheet는 frame-only clone path로 처리한다.
  - `SWTITLETRANSFERBOOTSTRAPFAST`는 현재 실용 workflow를 감싼 명령이다.
  - native GMTITLE exemplar가 이미 있으면 fast remaining-sheet batch를 바로 실행한다.
  - exemplar가 없으면 첫 native `GMTITLE` transfer를 1번 실행한 뒤, 첫 transfer 성공 후 fast remaining-sheet batch를 시작한다.
- 사전 조건:
  - 현재 DWG는 쓰기 가능한 work-folder copy여야 한다.
  - target `DR_A*_Outline` block definition이 오염되어 있으면 안 된다.
  - `SWTITLETRANSFERFASTBATCH`를 직접 실행하려면 native xdata가 있는 native `DR_titlea_3rd` GMTITLE exemplar가 최소 1개 있어야 한다.
  - `SWTITLETRANSFERBOOTSTRAPFAST`는 native exemplar가 이미 있거나, 첫 native exemplar를 만들 수 있도록 source title sheet가 최소 1개 남아 있어야 한다.

## 기대되는 clean-start 흐름

- 현재 one-command flow는 `SWTITLETRANSFERBOOTSTRAPFAST`를 사용한다.
- 대안 수동 흐름:
  - `SWTITLETRANSFERAPPLY` 또는 `SWTITLETRANSFERFINALIZE`를 한 번 사용해 첫 native GMTITLE exemplar를 만들고 finalize한다.
  - 그 다음 `SWTITLETRANSFERFASTBATCH` 실행.
- 기대 결과:
  - 남은 A2/A3 title sheet와 A4 frame-only sheet를 수량 입력 없이 처리한다.
  - 마지막에 `SWTITLEGMTITLEVERIFYALL` 실행.
  - 최종 editor check는 A2/A3/A4 표제란을 수동으로 더블클릭해서 확인한다.
- 중요한 주의점:
  - 이 흐름은 빠른 multi-sheet 자동화 흐름을 개선하지만, 그 자체만으로 A3 더블클릭 native GMTITLE 표 동작을 증명하지는 않는다.
  - A3 GMTITLE recognition issue는 최종 완료 전에 반드시 해결해야 하는 항목이다.
- clean-start abort 테스트:
  - clean-start work copy에서 업데이트된 LSP가 정상 로드됨.
  - native GMTITLE exemplar를 만들기 전에 `SWTITLETRANSFERFASTBATCH`를 실행하면 안전하게 중단됨.
  - 중단 이유: native xdata가 있는 native `DR_titlea_3rd` GMTITLE exemplar가 아직 없음.
  - 명령은 첫 시트에 대해 `SWTITLETRANSFERAPPLY` 또는 `SWTITLETRANSFERFINALIZE`를 실행하라고 안내했다.
  - 이 abort 경로에서는 도면 데이터가 변경되지 않아야 한다.
- `SWTITLEFASTSTATUS` 추가 후 fast-status 테스트:
  - 테스트 복사본:
    - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_fastbatch_test_260630_01.dwg`
  - 로그:
    - `work\swcad_title_fast_status_last.txt`
  - 결과:
    - source title sheets: `13`
    - source sheet frames: `15`
    - title sheets with frame: `13`
    - title sheets without frame: `0`
    - frame-only sheets: `2`
    - source sheet frame counts: `A2: 1`, `A3: 12`, `A4: 2`
    - title sheet counts: `A2: 1`, `A3: 12`
    - native GMTITLE exemplar: `no`
    - contaminated target frame definitions: `<none>`
    - status: `WAITING_FOR_NATIVE_GMTITLE_EXEMPLAR`
  - 결론:
    - 현재 clean fastbatch test copy는 올바르게 감지되며 계속 진행해도 안전하다.
    - 다음 병목은 첫 `DR_A*_Outline + DR_titlea_3rd` native GMTITLE exemplar를 자동으로 만드는 것이다.
    - exemplar가 없으면 `SWTITLETRANSFERFASTBATCH`는 도면을 수정하기 전에 중단해야 한다.
    - 이 상태에서는 `SWTITLETRANSFERBOOTSTRAPFAST`가 선호 명령이다. 첫 native 단계를 처리한 뒤 fast batch로 이어가기 때문이다.

## Bootstrap 안내 업데이트

- 버전: `260630-bootstrap-flow`
- `SWTITLEFASTSTATUS`와 `SWTITLETRANSFERBOOTSTRAPFAST`는 수정 전에 다음 native GMTITLE bootstrap 선택값을 출력한다.
- clean bootstrap test copy에서 다음 선택값을 감지했다.
  - source sheet: `A2`
  - paper/frame: `DR_A2_Outline`
  - title block: `DR_titlea_3rd`
- 이제 `SWTITLETRANSFERBOOTSTRAPFAST`는 다음 두 first-native status를 bootstrap 성공으로 처리한다.
  - `APPLIED_TITLE_TRANSFER`
  - `FINALIZED_EXISTING_GMTITLE_TRANSFER`
- 이 수정은 첫 시트가 `SWTITLETRANSFERAPPLY`로 성공적으로 만들어졌는데 bootstrap wrapper가 finalize status만 성공으로 인식해서 remaining fast batch를 시작하지 못하던 흐름 버그를 고친 것이다.

## Native GMTITLE command-line 자동화 확인

- 테스트 복사본:
  - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_fastbatch_test_260630_01.dwg`
- 확인한 항목:
  - `-GMTITLE`
  - `CMDDIA=0` 후 `GMTITLE`
- 결과:
  - `-GMTITLE`은 unknown-command 메시지를 반환했다.
  - `CMDDIA=0` 상태에서도 `GMTITLE`은 modal title/border dialog를 열었다.
  - dialog는 취소했고 `CMDDIA`는 `1`로 복구했다.

## Native GMTITLE picker UI 자동화 확인

- 테스트 복사본:
  - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_bootstrap_test_260630_01.dwg`
- 목표:
  - 화면 좌표 클릭 없이 native GMTITLE dialog에서 `DR_A2_Outline`과 `DR_titlea_3rd`를 선택한다.
- 결과:
  - Accessibility inspection은 `DR_A1_Outline`, `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 같은 combo/list 값을 볼 수 있었다.
  - 하지만 programmatic combo expansion과 direct value setting은 선택된 paper/frame 값을 안정적으로 바꾸지 못했다.
  - keyboard/list-item 방식도 production automation path로 쓰기에 충분히 안정적이지 않았다.
  - dialog는 취소했고 기존 source title/frame content는 제거하지 않았다.

## Strict clean copy에서 picker/config 재확인

- 테스트 복사본:
  - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_strictnative_test_260630_01.dwg`
- `SWTITLETRANSFERBOOTSTRAPFAST`는 첫 bootstrap sheet를 올바르게 감지했다.
  - source sheet: `A2`
  - paper/frame: `DR_A2_Outline`
  - title block: `DR_titlea_3rd`
- native `GMTITLE` dialog는 여전히 GstarCAD 기본값으로 열렸다.
  - paper: `A3 (297x420mm)`
  - title block: `ISO title block A`
  - object move: on
- Accessibility inspection은 `DR_A2_Outline`을 볼 수 있었지만, direct element selection, keyboard selection, direct combo value setting 모두 선택값 변경이 안정적이지 않았다.
- dialog는 취소했고 pending insertion state는 `ESC`로 해제했다.
- `SWTITLETRANSFERAPPLY`는 `ABORT_NO_NATIVE_GMTITLE_TITLE`로 안전하게 끝났다.
- 기존 SOLIDWORKS title/frame content는 제거하지 않았다.
- abort 후 `SWTITLEFASTSTATUS` 결과:
  - source title sheets: `13`
  - source sheet frames: `15`
  - frame-only sheets: `2`
  - native GMTITLE exemplar: `no`
  - contaminated target frame definitions: `<none>`
  - result: `WAITING_FOR_NATIVE_GMTITLE_EXEMPLAR`

## Config/registry 확인

- GstarCAD 설치 폴더, 사용자 `AppData\Local\Gstarsoft`, 사용자 `AppData\Roaming\Gstarsoft`, `HKCU\Software\Gstarsoft`를 read-only로 검색했다.
- `DR_A2_Outline`, `DR_titlea_3rd`, `GMTITLE`에 대한 단순 저장값은 찾지 못했다.
- `impro.ini`, `PublicSymbol.ini`, `CalVar.ini` 같은 텍스트 설정 파일에도 native GMTITLE picker selection은 없다.
- 현재 결론:
  - LISP나 단순 config value로 첫 native `GMTITLE` dialog를 미리 채우는 방법은 아직 증명되지 않았다.
- 현재 실용적인 안전 경로:
  - 실제 dialog로 첫 native GMTITLE을 한 번 만들고 finalize한다.
  - 그 뒤 fast batch path로 남은 title sheet와 A4 frame-only sheet를 처리한다.

## Native-link 진단 업데이트

- 버전: `260630-native-link-verify`
- `SWTITLEGMTITLELINKSCAN`, `SWTITLEGMTITLEVERIFY`, `SWTITLEGMTITLEVERIFYALL`은 각 `GENIUS_GENOREF_13` native link target을 다음처럼 분류한다.
  - `internal`
  - `visible-target-frame`
  - `visible-target-title`
  - `visible-insert`
  - `missing`
  - 또는 raw DXF entity type
- `0000_A_DRP125_CP_ALL_260604_a4_native_test_260630_01.dwg` 스캔 결과:
  - native A2 title: `native-target-kinds=internal`
  - native/default A4 title: `native-target-kinds=internal`
  - cloned A3 titles: `native-target-kinds=visible-target-frame`
- 이제 `SWTITLEGMTITLELINKSCAN`은 title block이 보이는 `DR_A*_Outline` frame insert를 직접 가리키면 `WARN_NATIVE_LINKS_POINT_TO_VISIBLE_FRAMES`를 반환한다.
- 이것은 A3 editor issue에 대한 현재 가장 강한 단서다.
  - 실제 native GMTITLE title은 내부 object handle을 가리키는 것으로 보인다.
  - 현재 cloned A3 route는 보이는 frame insert handle을 가리킨다.
  - 따라서 cloned title은 attribute와 `native-links=1`을 가질 수 있지만 native GMTITLE table-editor 동작은 실패할 수 있다.

## Native-link raw detail 업데이트

- 버전: `260630-native-link-detail`
- 추가된 명령:
  - `SWTITLEGMTITLELINKDETAIL`
- 로그:
  - `work\swcad_title_gmtitle_link_detail_last.txt`
- 목적:
  - 각 title block의 native GMTITLE handle 뒤에 있는 raw target object를 출력한다.
  - internal/native recognition handle과 보이는 cloned frame insert를 구분한다.
- `0000_A_DRP125_CP_ALL_260604_a4_native_test_260630_01.dwg` 결과:
  - native A2 title `16BE8`은 handle `16BF5`를 가리킨다.
    - target kind: `internal-no-entget`
    - VLA object: `<none>`
    - raw `entget`: `<nil>`
  - native/default A4 title `17AD3`은 handle `17AE0`을 가리킨다.
    - target kind: `internal-no-entget`
    - VLA object: `<none>`
    - raw `entget`: `<nil>`
  - cloned A3 titles는 보이는 `DR_A3_Outline` frame insert를 가리킨다.
    - target kind: `visible-target-frame`
    - VLA object: `AcDbBlockReference`
    - raw `entget`: 일반적인 visible `INSERT` data
- 해석:
  - native A2/A4 GMTITLE 명령은 handle로 접근 가능한 hidden/internal recognition object를 만들거나 참조한다.
  - 그 object는 `entget`이나 VLA를 통해 일반 graphical entity처럼 노출되지 않는다.
  - 현재 fast clone route는 그 internal object를 재생성하지 못한다.
  - 대신 title을 보이는 frame insert에 직접 연결한다.
  - 그래서 fast route가 geometry, attribute, visible output은 제대로 옮겨도 complete native GMTITLE object라고 증명되지 않았던 이유를 설명한다.
- 개발 결정:
  - 개발 중에는 cloned A3 sheet가 Advanced Attribute Editor로 열리는 것을 허용할 수 있다.
  - 하지만 최종 완료 전에는 A3 recognition problem을 해결하거나, A2/A3/A4가 모두 더블클릭 시 GMTITLE table editor로 열리는 다른 native-creation strategy를 사용해야 한다.

## Native-vs-clone 비교 진단 업데이트

- 버전: `260630-gmtitle-compare`
- 추가된 명령:
  - `SWTITLEGMTITLECOMPARE`
- 로그:
  - `work\swcad_title_gmtitle_compare_last.txt`
- 목적:
  - internal/native GMTITLE title 1개와 visible-frame-linked cloned GMTITLE title 1개를 나란히 출력한다.
  - 도면을 수정하지 않고 A3 recognition problem을 더 쉽게 비교한다.
- `0000_A_DRP125_CP_ALL_260604_a4_native_test_260630_01.dwg` CAD 테스트 결과:
  - 명령이 정상 로드되고 실행됨.
  - 결과: `OK_COMPARE_INTERNAL_AND_VISIBLE_FRAME_LINK`
  - internal/native exemplar:
    - title handle: `16BE8`
    - sheet: `A2`
    - linked handle: `16BF5`
    - native target kind: `internal-no-entget`
    - nearest visible frame: `DR_A2_Outline/16B22`
    - link matches nearest visible frame: `no`
  - visible-frame-linked clone exemplar:
    - title handle: `17919`
    - sheet: `A3`
    - linked handle: `17918`
    - native target kind: `visible-target-frame`
    - nearest visible frame: `DR_A3_Outline/17918`
    - link matches nearest visible frame: `yes`
- 해석:
  - 진짜 native GMTITLE title은 보이는 frame insert에 직접 연결되어 있지 않다.
  - cloned A3 title은 보이는 frame insert에 직접 연결되어 있다.
  - cloned A3 sheet를 true native GMTITLE object라고 말하기 전에 조사해야 할 가장 뚜렷한 차이다.

## Preserve-copy 실험 명령

- 버전: `260630-preserve-copy-force-test`
- 추가된 명령:
  - `SWTITLEGMTITLEPRESERVECOPYTEST`
- 로그:
  - `work\swcad_title_gmtitle_preserve_copy_test_last.txt`
- 목적:
  - 실제 native GMTITLE frame/title pair를 복사한다.
  - 이때 title의 `GENIUS_GENOREF_13` xdata를 보이는 frame handle로 다시 쓰지 않는다.
  - 복사한 pair를 현재 target frame 오른쪽에 배치한다.
  - 인식 실험을 위해 복사한 frame insert를 `DR_A1_Outline`, `DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline` 중 하나로 retarget할 수 있다.
  - 기존 SOLIDWORKS title/frame content는 절대 제거하지 않는다.
- 안전 조건:
  - 쓰기 가능한 `Documents\CAD tool\work` 복사본에서만 실행.
  - 복사 전에 명시적으로 `YES` 필요.
  - 요청한 target frame definition이 contaminated로 표시되면 warning을 남기지만 계속 진행한다.
  - 이 명령은 production conversion path가 아니라 명시적 recognition experiment이기 때문이다.
  - missing clean frame definition은 `YES` 확인 뒤 undo mark 안에서만 import한다.
- CAD 실행 메모:
  - 정상 `명령:` prompt로 돌아가기 위해 노출된 `명령 취소` 버튼을 먼저 사용한 뒤 command prompt에 명령을 입력하니 안정적이었다.
  - 이 세션에서는 `vla-Open`이 work copy를 반복해서 read-only로 열었다.
  - read-only A4 native test copy에서 `vla-SaveAs`를 실행해 쓰기 가능한 work test document를 만들었다.
- SAME target 테스트:
  - 테스트 복사본: `work\0000_A_DRP125_CP_ALL_260604_preservecopy_saveas_test_260630_01.dwg`
  - native exemplar title: `16BE8`
  - copied frame: `DR_A2_Outline/179CA`
  - copied title: `179CB`
  - 결과: `OK_PRESERVE_COPY_INTERNAL_LINK`
  - copied title은 `native-target-kinds=internal-no-entget`을 유지했다.
  - copied title은 copied visible frame handle이 아니라 internal handle `16BF5`에 계속 연결되어 있었다.
- A3 target 테스트:
  - 테스트 복사본: `work\0000_A_DRP125_CP_ALL_260604_preservecopy_a3isolated_test_260630_01.dwg`
  - 기존 A3 frame ref는 테스트 복사본 안에서만 삭제했다.
  - `SWTITLEFRAMEDEFCLEANSAFE`는 `DR_A3_Outline`을 clean/import하지 못했다.
  - imported/remaining definition은 여전히 child `DR-A3 From_HYUN`을 갖는다고 보고되었다.
  - 이는 현재 frame-definition contamination guard가 native/install DR frame definition에 대해 너무 넓게 잡는 것일 수 있음을 시사한다.
  - 명시적 preserve-copy experiment를 warning과 함께 계속 허용한 뒤 결과:
    - copied frame: `DR_A3_Outline/17A54`
    - copied title: `17A55`
    - 결과: `OK_PRESERVE_COPY_INTERNAL_LINK`
    - copied A3 title은 `native-target-kinds=internal-no-entget`을 유지했다.
    - copied A3 title은 copied visible `DR_A3_Outline` frame handle이 아니라 internal handle `16BF5`에 연결되어 있었다.
  - 수동 더블클릭 검증:
    - copied A3 title handle `17A55`는 Advanced Attribute Editor가 아니라 원하는 `속성 블록 편집` 표 dialog를 열었다.
    - dialog에는 checked/designed/approved/date/scale/sheet/file fields를 포함한 표제란 attribute가 채워져 있었다.
    - 이것은 보이는 copied frame을 `DR_A3_Outline`으로 retarget해도 internal native link를 보존하면 GMTITLE-style editor 동작을 유지할 수 있음을 확인한다.
- 현재 검증 상태:
  - 정적 검사 통과: `git diff --check`
  - 단순 괄호 균형 검사 결과: `parenDepth=0`
  - CAD 실행으로 preserve-copy가 internal GMTITLE link kind를 가진 A2/A3 visible title을 만들 수 있음을 확인했다.
  - copied A3 title `17A55`의 수동 더블클릭 검증 통과.
  - 다음 핵심 검증은 production fast clone path가 같은 preserve-copy 동작을 A2/A3/A4 전체에 사용할 수 있는지 확인하는 것이다.

## Fast clone 구현 업데이트

- 버전: `260630-preserve-copy-fast-clone`
- production fast clone은 이제 native GMTITLE frame/title pair를 복사할 때 title xdata를 보이는 frame handle로 다시 쓰지 않는다.
- 대신 internal native link를 보존한다.
- native exemplar 선택은 left-to-right로 정렬한다.
- 반복 fast clone 실행 시 안정적으로 known-good exemplar를 먼저 선택하기 위해서다.
- `SWTITLEFASTSTATUS`, `SWTITLETRANSFERFASTBATCH`, `SWTITLETRANSFERBOOTSTRAPFAST`는 이제 `DR_A*_Outline` definition이 source-like로 flag된다는 이유만으로 중단하지 않는다.
- 대신 warning을 남기고 최종 visual/verify check를 요구한다.
- CAD 테스트 복사본:
  - `work\0000_A_DRP125_CP_ALL_260604_preservecopy_a3isolated_test_260630_01.dwg`
- 결과:
  - fast batch 전 `SWTITLEFASTSTATUS`는 A4 frame-only sheet 2장과 함께 `OK_READY_FOR_FAST_BATCH`를 반환했다.
  - `SWTITLETRANSFERFASTBATCH`는 남은 A4 frame-only sheet를 변환했다.
  - 최종 `SWTITLEFASTSTATUS`는 `OK_NO_REMAINING_SOURCES`를 반환했다.
  - 최종 `SWTITLEGMTITLEVERIFYALL`은 remaining source title candidates `0`, remaining source sheet frame candidates `0`, visible-frame native links `0`을 보고했다.
  - 최종 verifier는 여전히 `WARN_TARGET_FRAME_DEFS_CONTAMINATED`를 반환한다.
  - 이유는 현재 source-like child-name detector가 native/install frame 내부도 flag하기 때문이다.
  - detector를 정교화하기 전까지는 warning으로 취급한다.
  - 마지막 frame-only finalize log는 기존 A4 frame handle `5291` 삭제와 lower-left/upper sheet-format residue entity `101`개 제거를 보여주었다.

## Strict native exemplar 업데이트

- 버전: `260630-strict-native-exemplar`
- fast clone 단계는 이제 `GENIUS_GENOREF_13` link target kind가 `internal` 또는 `internal-no-entget`인 native GMTITLE exemplar만 사용 가능하게 한다.
- native link가 보이는 cloned `DR_A*_Outline` frame을 직접 가리키는 title은 더 이상 exemplar로 인정하지 않는다.
- 이유:
  - visible-frame-linked clone은 attribute와 native xdata를 가질 수 있지만 native GMTITLE table-editor 동작은 실패할 수 있다.
  - 그런 clone을 다음 exemplar로 재사용하면 불확실한 상태가 계속 복제된다.
- 기대 동작:
  - 실제 native exemplar가 있으면 `SWTITLEFASTSTATUS`, `SWTITLETRANSFERFASTBATCH`, `SWTITLETRANSFERBOOTSTRAPFAST`가 exemplar handle과 `native-link-kinds`를 보고해야 한다.
  - visible-frame-linked clone만 있으면 fast batch는 검증되지 않은 source에서 clone하지 않고 `ABORT_NO_NATIVE_GMTITLE_EXEMPLAR`로 중단해야 한다.

## 결론

- 이 설치 환경에는 눈에 띄는 command-line `GMTITLE` 변형이 없다.
- 첫 native GMTITLE exemplar는 현재 단순 command-line option 전달 방식으로 만들 수 없다.
- GMTITLE picker의 직접 UI 자동화도 최종 자동 솔루션으로 보기에는 충분히 안정적이지 않다.
- AppData/registry 검색에서도 `GMTITLE` 실행 전에 설정할 수 있는 단순 저장 selection value를 찾지 못했다.
- 다음 실용적 선택지는 둘 중 하나다.
  - `SWTITLETRANSFERBOOTSTRAPFAST`를 사용해서 첫 native dialog를 한 번만 띄우고, 감지된 정확한 DR paper/title 값을 command line에 출력한 뒤, 첫 native transfer가 성공하면 남은 시트를 자동 처리한다.
  - internal native recognition data를 더 깊게 조사해서 dialog 없이 첫 exemplar를 구성할 수 있게 한다.

## 우려 사항

`native-links=1`은 cloned title block에 native xdata link가 최소 1개 있다는 뜻이다. 하지만 GstarCAD Mechanical GMTITLE recognition state 전체가 유효하다는 뜻은 아니다.

빠졌을 수 있는 요소:

- title insert뿐 아니라 frame insert의 xdata
- title과 frame 사이의 양방향 link
- extension dictionary entry
- reactor 또는 persistent object reference
- 실제 `GMTITLE` 명령만 만드는 object ownership/order 가정
- block reference와 개별 attribute 사이의 click target 차이

현재 진단은 visible target frame block definition이 기존 SOLIDWORKS source block definition으로 오염될 수 있음을 보여준다.

- `DR_A3_Outline` 안에 기존 child insert `DR-A3 From_HYUN`이 있다.
- `DR_A2_Outline` 안에 기존 child insert `DR-A2 From_HYUN`이 있다.
- A4 native test 후 `DR_A4_Outline` 안에 기존 child insert `도면 세로 A4 From_HYUN`이 있다.

그래서 일부 시트가 attribute와 native xdata를 가진 것처럼 보이더라도, 시각적 또는 구조적으로 일반 block reference처럼 동작할 수 있다.

## 다음 조사

native GMTITLE table editor로 열리는 known-good title block 1개와 Advanced Attribute Editor로 열리는 cloned title block 1개를 비교한다.

각 pair에 대해 다음을 검사하고 비교한다.

- xdata를 포함한 raw `entget`
- title insert xdata app과 handle value
- frame insert xdata app과 handle value
- extension dictionary handle
- reactor list
- owner handle
- block reference name과 effective name
- `GENIUS_GENOREF_13`이 참조하는 linked object handle

## 완료 기준

clone route는 다음 조건을 만족할 때만 완료로 볼 수 있다.

- 모든 cloned title block이 더블클릭 시 native GMTITLE table editor로 열린다.
- verification command가 `native-links=1`뿐 아니라 관련 internal condition을 감지할 수 있다.
- known-bad cloned title block은 새 verifier에서 실패해야 한다.
- known-good native GMTITLE title block은 새 verifier에서 통과해야 한다.

## 실용 방향

이 문제가 해결되기 전까지 `SWTITLETRANSFERCLONEBATCH`는 최종 production-safe route가 아니라 빠른 test/transfer route로 취급한다.

production-safe conversion은 missing recognition condition을 찾은 뒤 native `GMTITLE` creation 또는 검증된 internal clone method를 사용하는 쪽을 우선한다.

구현 우선순위:

1. 다음 전체 변환 테스트는 clean-start work copy를 계속 사용한다. 이 복사본은 target `DR_A*_Outline` definition이 없는 상태에서 시작하기 때문이다.
2. 먼저 visible output, title value, sheet size, cleanup이 올바른 fast multi-sheet generation path를 마무리한다.
3. A4 sheet는 source title insert가 없는 frame-only sheet로 감지되므로 A4 frame-only path는 별도로 유지한다.
4. 모든 clone/import conversion 전에 `SWTITLEFRAMEDEFCHECK`를 실행하거나 built-in contaminated-definition guard에 의존한다. 기존 SOLIDWORKS frame block이 native DR frame block처럼 가장하지 못하게 하기 위해서다.
5. Advanced Attribute Editor 문제는 개발 중 follow-up investigation으로 유지하되, 최종 완료 전에는 A3 GMTITLE recognition issue를 해결한다.
