# GMTITLE 표제란 값 옮기기 수정 - 2026-09-29

GMTITLE 변환(`src/tools/gmtitle/swcad_title_scale.lsp`)이 원본 표제란 값을 새 `DR_titlea_3rd`로 옮길 때 값이 사라지거나 바뀌는 문제를 고쳤다. 모듈 버전은 `260929-title-values-1`이다.

## 발견 경위

2026-09-29 GMTITLE 검토에서 완성된 30장 테스트 도면(`work/XRef Sw WorkFlow Test_260720.dwg`)의 표제란 값을 원본 DWG 8개(복사본)와 비교했다.

- 9장(30%): 원본의 도면번호·도면명·작성자·날짜가 GMTITLE 기본값으로 바뀌었다. 도면번호는 `XXX`, 도면명은 작업 파일 전체 경로, 작성자는 로그인 이름 `DR-DESIGN`, 날짜는 변환한 날이 들어갔다. 모두 원본 표제란이 이미 `DR_titlea_3rd` 블록 속성인 도면이다. 1장(Planetary HL Gear A4)은 원본부터 `XXX`였다.
- 5장(17%): 도면번호 앞에 MTEXT 서식 코드 `\FTXT,bigfont|c129;`가 붙었다. 도면번호 칸은 한 줄 속성이라 이 글자가 화면과 출력물에 그대로 보인다.
- `SWTITLEVERIFY`는 30장 모두 통과시켰다.

## 원인과 수정

### 1. 블록 속성 표제란을 읽지 않음

값 추출(`swcad-title-transfer-build-mappings`)은 TEXT/MTEXT만 칸 위치로 읽었다. 원본 INSERT의 속성은 읽지 않아서 용지 크기만 옮기고 원본 표제란을 지웠다. 나머지 칸에는 새 GMTITLE의 기본값이 남았다.

수정: `swcad-title-source-attribute-mappings`가 원본 INSERT의 `GEN-TITLE-*` 속성을 태그로 읽는다. 같은 칸 위치의 글자보다 우선한다. 속성 위에 겹친 글자는 중복으로 기록된다.

### 2. MTEXT 서식 코드 복사

MTEXT의 DXF 1/3 값을 그대로 썼다.

수정: `swcad-title-mtext-plain`이 `\F…;`, `\W…;`, `\H…;`, `{ }` 같은 서식 코드를 지운다. 줄바꿈 `\P`는 공백으로, 분수 `\S1^2;`는 `1/2`로 바꾼다. `%%c`, `%%d`, `%%p`, `\U+xxxx`는 속성이 그대로 표시하므로 남긴다.

### 3. 11칸 중 일부만 씀

원본에서 찾은 칸만 썼다. 나머지 칸에는 GMTITLE 기본값(`XXX`, 파일 경로, 로그인 이름, 변환한 날)이 남았다. 복제 경로에서는 다른 시트의 값이 남았다. 도면틀만 있는 시트에는 도면명에 호스트 파일 이름, 도면번호에 `XXX`를 넣었다.

수정: `swcad-title-complete-title-values`가 쓸 때마다 11칸을 모두 채운다. 원본에 값이 없는 칸은 다음처럼 채운다. 빈칸, 원본의 `XXX`, 파일 경로, `0000-00-00` 형식의 날짜도 값이 없는 칸으로 본다.

| 칸 | 원본에 값이 없을 때 |
| --- | --- |
| 작성자, 검도, 승인, 척도, 개정, 수량, 재질 | `DR_titlea_3rd` 속성 기본값(현재 HS KANG, KS LEE, KS LEE, 1:1, 0, 1, -) |
| 날짜 | 변환한 날(`YYYY-MM-DD`) |
| 도면번호, 도면명, 용지 | 빈칸(용지는 보통 도면틀 크기로 채워진다) |

사용자 결정(2026-09-29): 원본에 없는 칸은 GMTITLE 기본값을 넣는다. 작성자는 HS KANG, 날짜는 변환한 날이다. `XXX`와 파일 경로는 남기지 않는다.

### 4. 쓴 값 검증 범위

검증은 원본에서 찾은 칸만 비교했다.

수정: 11칸 전체를 다시 읽어 비교한다. 다르면 원본 표제란을 지우지 않고 `ABORT_TITLE_ATTRIBUTE_VERIFICATION`으로 멈춘다. 이 상태에서는 `SWCADRUN`도 멈춘다. 검증이 없던 경로에도 같은 검증을 넣었다. 대상 경로는 도면틀만 있는 시트 마무리, 복제 쌍의 native 교체, MANUAL 마무리다.

### 5. 지운 글자의 기록

새 표제란 칸에 들어가지 않은 원본 글자는 개수만 기록됐다.

수정: 지우는 글자마다 내용·위치·가장 가까운 칸을 `swcad_title_transfer_apply_last.txt`에 남긴다.

### 6. 최종 검사

`SWTITLEVERIFY` 최종 요약은 `SWCADVERIFY`도 사용한다. 이 요약이 제목블록마다 다음 문제를 찾는다.

- 도면번호 `XXX`
- 도면명에 들어간 파일 경로
- 서식 코드

이 문제만 있으면 결과는 `SWTITLEVERIFY_WARN_TITLE_VALUES`이고 워크플로는 막힌다. 빈 칸은 문제로 보지 않는다.

## 테스트

- 도구: `diagnostics/gmtitle-values/run_title_value_test.ps1`(설명은 같은 폴더의 README)
- 입력: 30장 fixture `work/_preserved_20260714/fixtures/sheet_wrapper_source_fixture_260713.dwg`를 통합 테스트(`MATERIALIZE_WRAPPED_XREF`)로 TITLE 단계까지 만든 복사본. 원본 해시는 바뀌지 않았다.
- 원본 값 기준: 원본 INSERT 속성, 그리고 칸에 매핑된 글자에서 서식 코드를 지운 값
- 실제 변환: 보이는 GstarCAD에서 COM `SendCommand`로 `SWCADRUN`을 실행했다. 실제 GMTITLE 창과 자동 선택기를 거친다. 스크립트 실행이 아니므로 GMTITLE 단계의 script 차단에 걸리지 않는다.

## 결과

30장 × 11칸 = 330칸이다. 원본에 값이 있는 칸은 308칸이다.

| 항목 | 이전 코드 | 새 코드 |
| --- | ---: | ---: |
| 원본과 다른 칸 | 44 | 2 |
| 도면번호 | 15 (`XXX` 9, 서식 코드 6) | 1 (원본 `XXX` → 빈칸) |
| 도면명 | 10 (파일 경로) | 1 (원본 파일 경로 → 빈칸) |
| 날짜 | 10 (변환한 날) | 0 |
| 작성자 | 9 (로그인 이름) | 0 |
| 쓴 뒤 다시 읽은 값이 계획과 다른 칸 | – | 0 / 330 |
| 실제 변환 결과가 계획과 다른 칸 | – | 0 / 330 |
| 실제 변환 결과의 `SWTITLEVERIFY` | – | `SWTITLEVERIFY_FINAL_OK` |

- 두 코드가 같은 규칙으로 바꾸는 2칸은 위 표에서 뺐다. 승인/날짜 합친 값 분리 1칸과, 용지 칸을 도면틀 크기로 바꾸는 1칸이다.
- 원본에 값이 없던 22칸의 결과: 재질 `-` 15칸(SolidWorks 양식에 재질 값이 없는 시트), 척도 `1:1` 6칸(원본 척도가 빈 기어 도면), 수량 `1` 1칸이다.
- 새 표제란에 칸이 없는 원본 글자: SolidWorks 양식 `Item ref` 칸의 `0`이 19장에 있다. 옛 표제란과 함께 지워지고 로그에 남는다.
- 서식 코드 제거, 기본값 채우기, 값 문제 판정 단위 검사 26개가 모두 통과했다.
- 이전 코드로 변환한 도면 2개에 새 최종 검사를 돌렸다. 07-20 도면(`work/XRef Sw WorkFlow Test_260720.dwg`)과, 사용자가 더블클릭으로 확인했던 07-13 30장 완성본(`work/_preserved_20260714/fixtures/Verify_XRef Sw WorkFlow Test_260713.dwg`)이다. 둘 다 `SWTITLEVERIFY_WARN_TITLE_VALUES`였고, 값 문제가 있는 제목블록 15장씩(`XXX`와 파일 경로 10장, 서식 코드 5장)을 모두 찾았다.
- 최종 실행: `tmp/gmtitle-value-test/260929_final/summary.txt`, `RESULT: OK`. 모듈 SHA-256 `95560E89CA58420927D913BE70BE5228A7007C7348D19DAD4D1B7E99D93423A3`는 `diagnostics/swcad-workflow/module-baseline.sha256`와 같다.
- 15장 기준본 워크플로 테스트(`run_workflow_integration_probe.ps1 -Modes DOWNSTREAM`)는 새 모듈로 `COMPLETE`까지 통과했다.

## 남은 것

- 30장 워크플로 전체 테스트는 치수 단계에서 멈췄다. 새 SWAUTO가 치수 3개의 `17`→`17.3` 변화를 잡아 `CHECK NEEDED`를 냈기 때문이다(`docs/history/swauto-value-guard-2026-09-29.md`). 그래서 이 도면으로는 Layout·정리·`SWCADVERIFY`까지 확인하지 못했다.
- 원본 작성자 칸에 로그인 이름(`DR-DESIGN`)이 들어 있던 도면(Planetary HL Gear A4)은 원본 값 그대로 옮긴다.
- 태그가 `GEN-TITLE-*`가 아닌 속성 표제란(다른 회사 양식)은 아직 읽지 않는다. 이런 양식은 기존처럼 일반 글자만 칸 위치로 읽는다.
- 이미 이전 코드로 변환한 도면은 `SWCADVERIFY`가 이제 `SWTITLEVERIFY_WARN_TITLE_VALUES`로 막는다. 해당 제목블록 값을 원본과 같게 고쳐야 통과한다.
- GMTITLE 검토의 2단계 이후 항목은 아직 고치지 않았다. 표제란 주변 선·해치 삭제 범위, 두 번 지우면 되살아나는 문제, 오류 때 SWCADRUN이 멈추지 않는 경로, 작업본 이름 날짜 등이다.
