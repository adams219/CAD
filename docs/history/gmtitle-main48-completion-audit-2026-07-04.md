# GMTITLE main48 completion audit - 2026-07-04

## Conclusion

The four-command GMTITLE workflow is implemented and the read-only/synthetic verification suite passes on main48.

The overall conversion goal is not complete yet. The real work-copy DWG still has no target GMTITLE frames or title blocks. Completion requires an interactive `SWTITLECONVERT` run in GstarCAD, followed by `SWTITLEVERIFY_FINAL_OK` and representative A2/A3/A4 title-block double-click checks.

Current source version:

```text
260704-command-text-guard-main-48
```

Current loader version:

```text
260704-4step-gmtitle-main48
```

## Requirement Audit

| Requirement | Evidence | Status |
| --- | --- | --- |
| User workflow uses four commands | Runtime loader probe shows `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY` present. Legacy samples such as `SWTITLEFASTSTATUS`, `SWTITLETRANSFERBOOTSTRAPFAST`, `SWTITLEA3A4NEXT`, `SWTITLEGMTITLEVERIFYALL` are `no`. Static public `defun c:` search shows the four workflow commands plus `SWTITLEVERSION` and `SWSCALESCAN`. | Proven |
| `SWTITLESTATUS` reports A2/A3/A4 sheet counts | Work-copy status probe reports expected sheet counts `A2: 1`, `A3: 12`, `A4: 2`. | Proven for current work copy |
| `SWTITLESTATUS` reports SolidWorks source title/frame counts | Work-copy status probe reports `source-title-count: 13`, `source-frame-count: 15`, `frame-only-count: 2`. | Proven for current work copy |
| `SWTITLESTATUS` reports target GMTITLE counts | Work-copy status probe reports `target-title-count: 0`, `target-frame-count: 0`, `target-sheet-counts: <none>`. | Proven for current work copy |
| `DR_A*_Outline` definitions are analyzed by common logic | Frame-definition common probe passes mixed, all-contaminated, and all-native A2/A3/A4 scenarios. | Proven synthetically |
| Built-in title-like frame geometry is detected | Style-normalization probe detects A2/A3/A4 `native-format-with-title-geometry` records and overlap against separate `DR_titlea_3rd`. | Proven synthetically |
| `SWTITLEPREPARE` can normalize A2/A3/A4 frame definitions | Style-normalization rebuild probe removes 12 title-like definition entities across A2/A3/A4 and leaves record count `0`. | Proven synthetically |
| Exterior frame, coordinate ticks, normal title block are protected | Frame-class/title-protection logic is covered by common probes and existing title protection fixture history; normal `DR_titlea_3rd` is not treated as frame-definition cleanup. | Proven by fixture history |
| Real drawing notes/balloons/BOM-like content are protected from residue cleanup | Sheet residue protection probe preserves bottom-left real text, upper small `SW_NOTE` balloon, and upper BOM-like insert while still selecting logo/sheet-format residue candidates. | Proven synthetically |
| Accidental command text stops conversion | Command-text guard comparison probe injects `SWTITLECONVERT` text, then verifies `SWTITLECONVERT` aborts with `ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST` and reaches no conversion stub. | Proven synthetically |
| `SWTITLECONVERT` extracts old title text and creates native GMTITLE exemplars | Existing implementation routes through first-native, missing exemplar, frame-only, fast batch, and A3/A4 native replacement phases. | Implemented, but real interactive CAD run still required |
| `SWTITLECONVERT` auto-recognizes sheet size and processes A2/A3/A4 without public sheet-specific commands | Status/convert logic uses detected sheet counts and internal branches rather than public A2/A3/A4 commands. | Implemented, real conversion still required |
| `SWTITLEVERIFY` checks duplicates, missing sheets, orphan frames, native-like pairs, and double-click targets | Integrated verify summary includes these counts and `SWTITLEVERIFY_FINAL_OK/WARN/FAIL`; double-click check is part of verify flow. | Implemented, real converted DWG still required |
| Final result reaches `SWTITLEVERIFY_FINAL_OK` | Final completion gate currently reports `SWTITLEVERIFY_FINAL_FAIL`. | Not complete |
| Representative A2/A3/A4 title blocks open GMTITLE table editor on double-click | No converted target title blocks exist yet in the current work copy. | Not complete |

## Standard Verification

The main48 suite passed:

```text
diagnostics/gmtitle-main45/run_main45_verification_suite.ps1
All expected log markers were verified.
GMTITLE main45 verification suite complete
```

Suite coverage now includes:

```text
1. loader probe
2. current LSP copy compare probe
3. actual work-copy status/verify probe
4. common A2/A3/A4 frame-definition classification probe
5. A2/A3/A4 style-normalization rebuild cleanup probe
6. command-text guard comparison probe
7. sheet residue protection probe
```

## Current Real Work-Copy State

The final completion gate intentionally fails because no conversion has been performed yet on the current work copy:

```text
SWTITLESTATUS: NEXT_CREATE_FIRST_NATIVE_GMTITLE
SWTITLEVERIFY: SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
```

This is a correct pre-conversion state.

## Next Real CAD Sequence

Open a clean copied DWG under:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work
```

Then use only this sequence:

```text
APPLOAD
SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE   only if SWTITLESTATUS asks for it
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT   repeat only when SWTITLESTATUS says conversion remains
SWTITLEVERIFY
```

When the GMTITLE dialog opens, verify:

```text
Paper/frame: the DR_A*_Outline size printed by the log
Title block: DR_titlea_3rd
Frame positioning: ON
Object move: OFF
```

Do not continue conversion if `SWTITLESTATUS` reports accidental command text, frame style normalization candidates, source-contaminated frame definitions, target frame geometry warnings, or overlap warnings. Run the indicated `SWTITLEPREPARE` or inspect the work copy first.

## Completion Gate

The goal is complete only when all of this is true:

```text
SWTITLEVERIFY_FINAL_OK
source-title-count: 0
source-frame-count: 0
frame-only-count: 0
target-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
No accidental command text candidates
No frame style-normalization candidates
No source-contaminated frame definitions
No target frame geometry/overlap warnings
Representative A2/A3/A4 DR_titlea_3rd title blocks open the GMTITLE table editor on double-click
Real drawing notes, balloons, BOM tables, dimensions, and model geometry are still present
```

Until those checks pass, do not mark the conversion goal complete.
