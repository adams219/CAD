# GMTITLE 작은 수정 - 2026-09-29

GMTITLE 검토의 4단계. 모듈 버전 `260929-small-fixes-1`. 3단계(오류 시 멈춤)는 `gmtitle-stop-on-error-2026-09-29.md`에 있다.

## 1. 작업본 이름의 날짜

`SWTITLEPREPARE`, `SWTITLECONVERT`, `SWCADRUN`이 원본에서 작업본을 만들 때 기본 파일 이름은 `<원본 이름>_SWTITLE_<날짜-시각>.dwg`다.

- 날짜 형식이 `YYYYMMDD-HHMMSS`였다. DIESEL `edtime`에서 `MM`은 분이고 월은 `MO`다. 그래서 월 자리에 분이 들어갔다. 9월 2일 18시 10분에 만든 작업본 이름이 `_SWTITLE_20261002-181022`였다.
- 이미 `_SWTITLE_…`가 붙은 도면에서 다시 작업본을 만들면 접미사가 하나 더 붙었다.

수정: 형식을 `YYYYMODD-HHMMSS`로 고쳤다(테스트 결과 `20260929-155408`). 원본 이름에 `_SWTITLE_`가 있으면 그 앞까지만 쓴 뒤 새 접미사를 붙인다.

## 2. 블록 이름으로 하는 용지 판단

도면틀이나 표제란 블록 이름에서 용지 크기를 읽을 때 `*A1*` 같은 와일드카드를 이름 전체에 썼다. A0부터 A4 순서로 확인했다.

- 결합된 XREF의 블록 이름은 `<호스트>$0$<XREF 파일 이름>$0$<블록 이름>` 모양이다. XREF 파일 이름에 `A1`, `A2` 같은 글자가 있으면(예: `Bracket_A1`) A3 도면틀도 A1로 읽혔다.
- `DATA1`, `A12`처럼 크기가 아닌 글자도 크기로 읽혔다.
- 결합된 표제란 `…$0$DR_titlea_3rd`는 `TITLEA_3RD`의 `A_3` 때문에 A3로 읽혔다. 표제란 블록 이름 자체는 크기를 나타내지 않는다.
- 이렇게 읽은 이름 크기는 실제로 잰 도면틀 크기보다 우선한다.

수정: 블록 자신의 이름(마지막 `$`나 `|` 뒤)만 본다. 크기는 독립된 표시일 때만 인정한다. `A0`~`A4`(또는 `A-3`, `A_3`, `A 3`)이고, `A` 바로 앞에 영문자나 숫자가 없고, 숫자 바로 뒤에 숫자가 없어야 한다. 한 이름에 서로 다른 크기가 둘 있으면 이름으로 판단하지 않는다.

### 영향 확인

도면 21개의 모든 블록 이름과 모든 원본 시트에서 이전 규칙과 새 규칙을 비교했다(`tmp/gmtitle-attr-test/step4_probe.lsp`, 복사본만 사용).

| 도면 | 크기를 읽은 블록 이름 | 판단이 바뀐 이름 | 원본 시트 | 시트 결과가 바뀐 시트 |
| --- | --- | --- | --- | --- |
| 30장 TITLE 단계 fixture | 222 | 145 | 30 | 0 |
| SolidWorks 원본 16개(기어 12, 기타 4) | 2~5씩 | 1(`P_eCVT-Sun HL Gear_LH_260506`의 `A$C961a11a1`) | 0~2씩, 모두 9 | 0 |
| `0000_A_DRP125_CP_ALL` | 31 | 0 | 15 | 0 |
| `XRef Sw WorkFlow Test_260713` | 347 | 264 | 0(시트 묶음 안) | - |
| 시트 묶음 fixture | 221 | 144 | 0(시트 묶음 안) | - |

- 시트 결과는 용지 크기, 새 도면틀 이름(`DR_A?_Outline`), 표제란 SIZ 값이다. 모든 시트에서 이전과 같았다.
- 판단이 바뀐 이름은 대부분 결합된 XREF 이름 앞부분에서 크기를 읽던 경우다. 예: `…_260506_A4$0$DR_LOGO`(파일 이름의 `_A4`), `…$0$DR_titlea_3rd`(A3), `A$C961a11a1`(A1).
- 이 도면들에서는 도면틀 이름(`DR_A4_Outline`, `DR-A3 FROM_HYUN` 등)이나 잰 크기가 같은 답을 주었기 때문에 결과가 달라지지 않았다. A4 시트 일부는 잰 크기가 표준 크기에 맞지 않아(예: 폭 266.25) 도면틀 이름으로만 정해진다. 새 규칙에서도 `DR_A4_Outline`은 A4로 읽는다.
- 파일 이름에 넣은 `_A4` 같은 표시는 이제 용지 판단에 쓰지 않는다.

## 3. XREF·시트 묶음 상태 도면 안내

9월 28일 `XRef Sw WorkFlow Test_260713.dwg`에서 `SWTITLESTATUS`와 `SWTITLEVERIFY`를 실행하자 `FAIL_MISSING_TARGET_FRAMES`만 나왔다. 무엇을 먼저 해야 하는지 안내가 없었다.

이 도면에는 XREF가 남아 있지 않았다(0개). XREF는 이미 결합됐고, 시트마다 도면틀(`DR_A*_Outline`)과 표제란(`DR_titlea_3rd`)이 바깥 블록 하나에 들어 있었다(시트 묶음 블록 10개). SWTITLE 명령은 맨 위에 놓인 블록만 보기 때문에 도면틀을 하나도 찾지 못했다. `SWCADRUN`에서는 XREF 단계와 시트 묶음(SHEET_WRAPPERS) 단계가 이것을 먼저 푼다.

수정: GMTITLE 도면틀과 원본 시트가 하나도 없고, 모델 공간에 XREF나 시트 묶음 블록이 있으면 다음을 출력한다. 시트 묶음 판단은 `SWCADRUN`의 시트 묶음 단계와 같은 기준(블록 정의 안에 `DR_A*_Outline`과 `DR_titlea_3rd`가 함께 있음)이다.

```text
다음 단계 코드: RUN_SWCADRUN_FIRST
이 도면의 시트는 아직 XREF나 시트 묶음 블록 안에 있습니다(XREF 0개, 시트 묶음 블록 10개).
SWTITLE 명령은 맨 위에 놓인 블록만 보므로 대상 도면틀이 0개로 나옵니다.
다음: SWCADRUN을 실행해 XREF와 시트 묶음 단계부터 진행하세요.
```

- `SWTITLESTATUS`: 마지막 줄도 `XREF와 시트 묶음 단계가 먼저입니다. SWTITLE 명령 대신 SWCADRUN을 실행하세요.`로 바뀐다.
- `SWTITLEVERIFY`(와 `SWCADVERIFY`의 GMTITLE 부분): 최종 결과는 그대로 `FAIL`이고, 다음 단계 안내가 위 내용으로 나온다.
- `SWTITLECONVERT`/`SWTITLECONVERTNEXT`: `OK_NO_REMAINING_SOURCES` 대신 `ABORT_SHEETS_NOT_MATERIALIZED`로 멈춘다.

`SWCADRUN`의 동작은 바뀌지 않는다.

## 테스트

- 단위 검사(`diagnostics/gmtitle-values/title_small_fixes_probe.lsp`) 28개, 모두 통과했다.
  - 블록 이름 예 19개: `DR_A3_Outline`→A3, `XREF$0$Bracket_A1_260506$0$DR_A3_Outline`→A3, `…$0$DR_titlea_3rd`→없음, `DATA1`·`A12_PART`·`SHEETA3`→없음, `A4 - ISO`→A4, `A3_TO_A4`→없음(크기 둘) 등
  - 작업본 이름 5개: 접미사 하나·둘·소문자, 접미사만 있는 이름
  - 날짜: 오늘 날짜(`20260929-…`)와 형식
  - 30장 시트 결과가 이전 규칙과 같음, 시트 묶음이 없는 도면에서 안내가 나오지 않음
- 시트 묶음 안내: `XRef Sw WorkFlow Test_260713.dwg`와 시트 묶음 fixture에서 시트 묶음 블록 10개를 찾아 안내가 나왔다. 30장 TITLE 단계 fixture에서는 나오지 않았다.
- 30장 워크플로 전체 테스트(`run_title_value_test.ps1 -EndToEnd -FullWorkflow`, 위 단위 검사 포함): `SWCADRUN` 4회로 `COMPLETE`, `SWCADVERIFY_FINAL_OK`, 제목블록 값 330칸 모두 계획과 같음, 지워진 모델 공간 객체 1693개(3단계와 같음). 결과 파일은 `tmp/gmtitle-value-test/260929_step4/summary.txt`, `RESULT: OK`. 모듈 SHA-256 `1D087ACBB158264C49910DBBBF1CAF29959FF2CAC3E836745EB81575B3E30D93`는 `diagnostics/swcad-workflow/module-baseline.sha256`와 같다.
- 원본 도면은 복사만 했고 바뀌지 않았다(해시 같음).
