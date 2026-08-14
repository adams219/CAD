# GMTITLE A3/A4 Batch Guard - 2026-07-05

## 목적

A3/A4 native 교체에서 반복 입력을 줄이는 장치는 `SWTITLECONVERT` 안의 `BATCH`다.

하지만 `BATCH`도 각 GMTITLE 창에서 아래 값을 사람이 확인해야 한다.

```text
DR_A*_Outline
DR_titlea_3rd
Frame positioning ON
Object move OFF
```

따라서 SCRIPT 또는 숨김 자동 실행에서 `BATCH`가 몰래 대화식 GMTITLE을 열고 진행하면 안 된다.

## 추가 검증

다음 probe를 추가했다.

```text
diagnostics/gmtitle-main45/a3a4_batch_guard_probe.lsp
diagnostics/gmtitle-main45/run_a3a4_batch_guard_probe.ps1
```

probe는 복사본 DWG에서 합성 A3 clone target pair 2개를 만든 뒤, SCRIPT 실행 중 내부 A3/A4 batch 경로를 호출한다.

기대 결과:

```text
Script active: yes
Status after batch: ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE
Candidates before/after: 2/2
INSERT count before/after: 4/4
Batch guard preserved candidates: yes
```

## 의미

이 검증은 실제 변환을 완료하지 않는다.

대신 다음 원칙을 보증한다.

```text
OPEN: 한 장 검증용
BATCH: 사용자가 CAD 화면에서 대화상자를 확인할 때만 반복 입력을 줄이는 용도
SCRIPT/숨김 자동 실행: BATCH 진행 금지, 후보 보존
```

즉, 현재 자동화 방향은 “대화상자 선택까지 무조건 자동화”가 아니라, 위험한 선택은 사람이 확인하고 나머지 후보 선정/좌표/값 복사/기존 쌍 삭제를 LSP가 맡는 방식이다.

## 다음 실제 CAD 검증

저장된 기본 workcopy는 아직 변환 전 상태다.

```text
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
status-after-status: NEXT_CREATE_FIRST_NATIVE_GMTITLE
```

실제 CAD에서는 먼저 `SWTITLECONVERT`로 첫 native GMTITLE 기준 객체를 만들고, 이후 A3/A4 native 교체 후보가 생겼을 때 아래 순서를 따른다.

```text
1. OPEN으로 대표 1장 성공 확인
2. SWTITLESTATUS로 후보 수 감소 확인
3. 같은 선택값이 반복되는 구간에서만 BATCH 사용
4. 실패/ISO 기본값/Object move ON이면 취소
5. SWTITLEVERIFY와 대표 DR_titlea_3rd 더블클릭 확인
```
