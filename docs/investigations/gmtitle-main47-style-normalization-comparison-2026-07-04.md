# GMTITLE main47 style-normalization comparison - 2026-07-04

## Purpose

Compare the copied LSP experiments against the current source LSP for the A3 frame/title overlap problem.

The target problem is:

```text
DR_A3_Outline is not source-contaminated.
However, the frame definition already contains title-like geometry.
When a separate DR_titlea_3rd title block is added, the title area appears duplicated.
```

The user-facing workflow must remain:

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

No new A3-only user command should be required.

## Compared Files

Current source LSP:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp
Version: 260704-style-normalization-main-47
SHA256: D10E37247E4571A1C33CAF52399C63DCAC9AFC3D39DEF4D5727AEAF446ACFFE7
```

Style-normalization detection copy:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_style_normalization_test.lsp
Version: 260704-style-normalization-compare
SHA256: A665D372124DA007C1EA5B87F4E2AE97B5C064C37DE60724E1F4BAAD212146FB
```

Current compare copy refreshed by the verification suite:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_current_main45_compare_copy.lsp
Version: 260704-style-normalization-main-47
SHA256: D10E37247E4571A1C33CAF52399C63DCAC9AFC3D39DEF4D5727AEAF446ACFFE7
```

Note: the file name still says `main45`, but the verification suite refreshes it from the current source LSP. At the time of this comparison it is identical to main47.

## Test Fixture

The probe creates a copied DWG and then builds a synthetic A3 case:

```text
DR_A3_Outline block definition:
  - A3 outer frame
  - built-in title-like lines/text in the lower-right title area

DR_titlea_3rd block definition:
  - separate title block inserted over the same lower-right area
```

This isolates the exact issue:

```text
The A3 frame is native-format-like, not source-contaminated.
The problem appears only when a separate DR_titlea_3rd overlaps the built-in title-like area.
```

Probe wrapper:

```text
diagnostics\gmtitle-main45\run_style_normalization_compare_probe.ps1
```

## Result 1: main45 classification only

Log:

```text
work\swtitle_style_normalization_compare_current_main45_stylecmp.txt
```

Important lines:

```text
Loaded version: 260704-frame-definition-classification-main-45
DR_A3_Outline: class=native-format-with-title-geometry, embedded=4, source-like=<none>
Style function present: no
Status after SWTITLESTATUS: NEXT_UPGRADE_A3_A4_NATIVE
Runtime check completed: yes
```

Assessment:

```text
It correctly avoided treating A3 as source-contaminated.
But it did not have a separate style-normalization gate.
Therefore the next step could continue toward native A3/A4 replacement while the duplicated title shape remained unresolved.
```

## Result 2: copied style-normalization detection

Log:

```text
work\swtitle_style_normalization_compare_style_normalization_variant.txt
```

Important lines:

```text
Loaded version: 260704-style-normalization-compare
Style-normalization result: OK
Style-normalization record count: 1
style-record frame=DR_A3_Outline, frame-handle=16904, title-handle=16905, overlap=(230, 10) - (410, 52)
Status after SWTITLESTATUS: NEXT_PREPARE_FRAME_STYLE_NORMALIZATION
Runtime check completed: yes
```

Assessment:

```text
This copy is better than main45 because it separates source contamination from style mismatch.
It correctly tells the user to run SWTITLEPREPARE before continuing.
However, this copy only proved detection/gating, not actual cleanup.
```

## Result 3: main46 direct-delete cleanup attempt

Log:

```text
work\swtitle_style_normalization_compare_current_main46_directdelete_debug.txt
```

Important lines:

```text
Style-normalization clean entity records:
  #1 owner=DR_A3_Outline, handle=168F6, type=LINE, object=yes
  #2 owner=DR_A3_Outline, handle=168F7, type=LINE, object=yes
  #3 owner=DR_A3_Outline, handle=168F8, type=LINE, object=yes
  #4 owner=DR_A3_Outline, handle=168F9, type=TEXT, object=yes
Direct vla-Delete first clean record: ERROR - ActiveX Server...
Style-normalization clean entity count: 4
Style-normalization deleted count: 0
Style-normalization record count after clean: 1
```

Assessment:

```text
The detection was correct.
The cleanup approach was wrong.
GstarCAD blocked direct deletion of entities inside the referenced block definition.
Continuing in this direction would repeat the same failure.
```

## Result 4: main47 rebuild cleanup

Log:

```text
work\swtitle_style_normalization_compare_current_main47_stylecmp_clean.txt
```

Important lines:

```text
Loaded version: 260704-style-normalization-main-47
Style-normalization record count: 1
Direct vla-Delete first clean record: ERROR - ActiveX Server...
Style-normalization clean entity count: 4
Style-normalization deleted count: 4
Style-normalization record count after clean: 0
Status after SWTITLESTATUS: NEXT_UPGRADE_A3_A4_NATIVE
Runtime check completed: yes
```

Assessment:

```text
This is the best current direction.
It keeps the main45/main46 detection improvement, but replaces the failed direct-delete cleanup with a block-definition rebuild.
The duplicated A3 title-like geometry is removed in the copied fixture.
The next status no longer asks for style normalization.
```

## Result 5: main47 A2/A3/A4 common cleanup

Log:

```text
work\swtitle_style_normalization_compare_current_main47_stylecmp_all_sizes_clean.txt
```

Important lines:

```text
Loaded version: 260704-style-normalization-main-47
DR_A2_Outline: class=native-format-with-title-geometry, embedded=4, source-like=<none>
DR_A3_Outline: class=native-format-with-title-geometry, embedded=4, source-like=<none>
DR_A4_Outline: class=native-format-with-title-geometry, embedded=4, source-like=<none>
Style-normalization record count: 3
Style-normalization clean entity count: 12
Style-normalization deleted count: 12
Style-normalization record count after clean: 0
Runtime check completed: yes
```

Assessment:

```text
This proves the current cleanup path is not only an A3 special case.
The same style-normalization detection and rebuild cleanup ran against DR_A2_Outline, DR_A3_Outline, and DR_A4_Outline in one copied fixture DWG.
Direct vla-Delete still fails, so the rebuild method remains necessary.
```

## Regression Evidence

The current source passed the existing GstarCAD hidden-run regression suite:

```text
diagnostics\gmtitle-main45\run_main45_verification_suite.ps1
```

Observed result:

```text
All expected log markers were verified.
GMTITLE main45 verification suite complete.
```

After adding the A2/A3/A4 style-normalization rebuild cleanup probe as suite step 5, the full suite was rerun and passed again.

Observed result:

```text
===== 5. A2/A3/A4 style-normalization rebuild cleanup probe =====
Verified log: A2/A3/A4 style-normalization rebuild cleanup probe
All expected log markers were verified.
GMTITLE main45 verification suite complete.
```

The suite verifies:

```text
loader probe
current LSP copy compare probe
actual work-copy read-only status probe
common A2/A3/A4 frame-definition probes
A2/A3/A4 style-normalization rebuild cleanup probe
```

## Conclusion

Use the current main47 source LSP.

The earlier copied style-normalization LSP was useful because it proved that the A3 problem should be treated as `style-normalization-needed`, not as source contamination. But it was incomplete.

The main47 source is better because it:

```text
1. Keeps the 4-command user workflow.
2. Detects A3 native-format title geometry only when it overlaps a separate DR_titlea_3rd.
3. Stops SWTITLECONVERT until SWTITLEPREPARE handles it.
4. Avoids the failed direct-delete method.
5. Rebuilds the work-copy block definition and keeps the DR_A3_Outline name.
6. Uses the same rebuild path for DR_A2_Outline, DR_A3_Outline, and DR_A4_Outline.
7. Passed the synthetic cleanup probes and the existing regression suite.
```

## Remaining Proof

This comparison proves the LSP direction, but it does not by itself prove final real drawing completion.

A real work-copy DWG still needs this interactive verification:

```text
APPLOAD swcad_load.lsp
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE
SWTITLESTATUS
SWTITLECONVERT
SWTITLEVERIFY
```

Final completion requires:

```text
SWTITLEVERIFY_FINAL_OK
Representative A2/A3/A4 DR_titlea_3rd title blocks open the GMTITLE table editor on double-click.
No duplicate title-like geometry remains inside the A3 frame.
No A4 frame-only sheet is missing.
```
