# GMTITLE main48 command-text guard comparison - 2026-07-04

## Purpose

Compare the current main47 LSP copy with a guarded main48 LSP copy before applying the change to the source LSP.

The specific risk came from CAD UI automation history: command text such as `SWTITLECONVERT` can be inserted into the drawing as TEXT/MTEXT. `SWTITLESTATUS` already detected this, but the integrated structure summary and conversion dispatcher still needed to prove that they would not continue conversion while this residue exists.

## Compared Files

```text
Baseline:
  work/lsp_compare/swcad_title_scale_main47_baseline.lsp
  version: 260704-style-normalization-main-47

Guard test:
  work/lsp_compare/swcad_title_scale_command_text_guard_test.lsp
  version: 260704-command-text-guard-test-main-48
```

The probe uses a copied DWG and injects one synthetic `SWTITLECONVERT` TEXT entity into the probe drawing. It then stubs all modifying conversion helpers before calling the integrated convert dispatcher, so the test is safe and repeatable.

## Probe

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_command_text_guard_compare_probe.ps1" `
  -LspPath "work\lsp_compare\swcad_title_scale_main47_baseline.lsp" `
  -Label "baseline_main47_command_text_guard"

powershell -NoProfile -ExecutionPolicy Bypass -File `
  "diagnostics\gmtitle-main45\run_command_text_guard_compare_probe.ps1" `
  -LspPath "work\lsp_compare\swcad_title_scale_command_text_guard_test.lsp" `
  -Label "guard_test_main48_command_text_guard"
```

## Result

Baseline main47 detected the command text in `SWTITLESTATUS`, but its integrated structure summary still pointed toward conversion and its convert dispatcher reached a conversion path.

```text
command-text-count-before: 1
SWTITLESTATUS result: OK status=NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT
structure-next-action: SWTITLECONVERT - 남은 원본 SolidWorks 시트 변환
convert-status-after: STUB_TRANSFER_BOOTSTRAP_FAST
danger-action-after-convert: TRANSFER_BOOTSTRAP_FAST
```

Guard test main48 detected the same command text, pointed the user to `SWTITLEPREPARE`, and aborted before any conversion path.

```text
command-text-count-before: 1
SWTITLESTATUS result: OK status=NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT
structure-next-action: SWTITLEPREPARE - 실수 명령어 텍스트 잔여물을 먼저 확인/정리해야 합니다.
convert-status-after: ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST
danger-action-after-convert: <none>
```

## Regression Checks

The guard-test copy also passed the clean work-copy read-only probe:

```text
Loaded version: 260704-command-text-guard-test-main-48
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Command c:SWTITLEFASTSTATUS: no
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
A2: 1
A3: 12
A4: 2
```

It also passed the A2/A3/A4 style-normalization fixture:

```text
Loaded version: 260704-command-text-guard-test-main-48
Style-normalization record count: 3
Style-normalization clean entity count: 12
Style-normalization deleted count: 12
Style-normalization record count after clean: 0
Runtime check completed: yes
```

## Decision

The guarded main48 approach is better.

Reason:

- It preserves the four public command workflow.
- It keeps the existing clean-copy and A2/A3/A4 style-normalization behavior.
- It prevents `SWTITLECONVERT` from continuing when accidental command text exists in the drawing.
- It aligns with the CAD input safety history and avoids repeating the same `_PASTECLIP`/text-entry failure mode.

The guarded change has been applied to the source LSP as:

```text
src/tools/gmtitle/swcad_title_scale.lsp
version: 260704-command-text-guard-main-48
```
