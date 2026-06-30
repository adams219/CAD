# GMTITLE Follow-up Agenda - 2026-06-30

## Open Item: cloned GMTITLE edit behavior is not fully proven

Status: deferred

Some cloned `DR_titlea_3rd` title blocks can still open the Advanced Attribute Editor instead of the native GMTITLE table editor when double-clicked.

This means the current clone route is useful for transferring visible title data and basic native xdata, but it is not yet proven to fully recreate every internal condition that GstarCAD Mechanical uses to recognize a title block as a native GMTITLE object.

## Current Evidence

- The full test copy contains:
  - `DR_A2_Outline`: 1
  - `DR_A3_Outline`: 12
  - `DR_titlea_3rd`: 13
- `SWTITLEGMTITLEVERIFYALL` reported for all 13 title blocks:
  - `attrs=11`
  - `nonempty=11`
  - `missing-tags=0`
  - `native-links=1`
- Remaining old SOLIDWORKS title candidates: 0
- Remaining old title-like inserts: 0
- Remaining source frames are only A4 frame-only sheets: 2

Additional A4 native test:

- Test copy:
  - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_a4_native_test_260630_01.dwg`
- Native `GMTITLE` was run with:
  - paper: `DR_A4_Outline`
  - title block: `DR_titlea_3rd`
  - frame position: off
  - object move: off
- `SWTITLEGMTITLEVERIFYALL` then reported:
  - `DR_A2_Outline`: 1
  - `DR_A3_Outline`: 12
  - `DR_A4_Outline`: 1
  - `DR_titlea_3rd`: 14
  - all 14 title blocks: `attrs=11`, `nonempty=11`, `missing-tags=0`, `native-links=1`
- `SWTITLEGMTITLELINKSCAN` reported no duplicate GMTITLE link handles.
- The native A4 title used an internal link handle (`17AE0`) rather than a direct visible frame insert handle, matching the native A2 pattern more closely than the cloned A3 pattern.
- The A4 native test used default title values and was placed at the command default location. It did not yet transfer old A4 text values or remove the two old A4 source frames.

Frame-only A4 finalize implementation test:

- Added commands:
  - `SWTITLEFRAMEONLYFINALIZE`
  - `SWTITLEFRAMEONLYCLONEAPPLY`
  - `SWTITLEFRAMEONLYCLONEBATCH`
- `SWTITLEFRAMEONLYFINALIZE` was tested on the same work copy after creating one native/default `DR_A4_Outline + DR_titlea_3rd`.
- Result:
  - Source frame-only insert `36E6` was processed.
  - Native/default A4 GMTITLE was moved by `dx=2492.22576246`, `dy=0.42607942`.
  - Attributes set: 4
  - Old frame-only insert deleted: yes
  - Old SOLIDWORKS residue deleted: 102
  - `SWTITLEGMTITLEVERIFYALL`: `OK_VERIFY_ALL_GMTITLE_READY`
  - Remaining source frame-only sheets went from 2 to 1.

Important caveat:

- The moved `DR_A4_Outline` insert had a bbox width much larger than nominal A4 in the log.
- `SWTITLEGMTITLELINKSCAN` still reports `DR_A4_Outline: children=도면 세로 A4 From_HYUN`.
- This means the frame-only finalize command flow works, but the target `DR_A4_Outline` block definition is still polluted in this test drawing.
- Before production use, clean/import verified target `DR_A*_Outline` definitions or add a block-definition contamination check.

Frame definition contamination guard:

- Added command:
  - `SWTITLEFRAMEDEFCHECK`
- Test result on the current A4 work copy:
  - `DR_A2_Outline`: `CONTAMINATED`, child `DR-A2 From_HYUN`
  - `DR_A3_Outline`: `CONTAMINATED`, child `DR-A3 From_HYUN`
  - `DR_A4_Outline`: `CONTAMINATED`, child `도면 세로 A4 From_HYUN`
  - Result: `WARN_TARGET_FRAME_BLOCK_DEFINITION_CONTAMINATED`
- `SWTITLEGMTITLELINKSCAN` now also returns `WARN_TARGET_FRAME_BLOCK_DEFINITION_CONTAMINATED` when any target frame block definition contains old source-like child inserts.
- Fast clone frame insertion now refuses to reuse a contaminated target frame block definition.
- Guard test:
  - `SWTITLEFRAMEONLYCLONEAPPLY` was run on the remaining A4 frame-only source.
  - It aborted with `ABORT_FRAME_ONLY_CLONE_FAILED`.
  - The log included the target frame definition check.
  - No old frame-only sheet content was removed.

Frame definition safe cleanup command:

- Added command:
  - `SWTITLEFRAMEDEFCLEANSAFE`
- Purpose:
  - Repairs only unused contaminated `DR_A*_Outline` block definitions.
  - If a contaminated target frame definition is already referenced by existing inserts, it is skipped instead of renamed.
  - If a contaminated definition has zero inserts, it is renamed to a backup name such as `DR_A3_Outline_SWOLD_1`, then a clean definition is imported from the GstarCAD install folder.
- Safety rules:
  - Requires a writable drawing.
  - Requires a work-folder copy, or explicit `EDIT` confirmation outside `Documents/CAD tool/work`.
  - Requires `YES` confirmation before changing any block definition.
  - Does not delete existing visible drawing content.
- Expected current-test behavior:
  - On the existing A4 work copy, `DR_A2_Outline`, `DR_A3_Outline`, and `DR_A4_Outline` are already referenced, so the command should skip them and report `SKIP_REFERENCED_CONTAMINATED_FRAME_DEFS`.
  - This is intentional: repairing referenced contaminated definitions needs a separate rebuild strategy, not silent block renaming.

Clean-start baseline test:

- New work copy created from the untouched Downloads DWG:
  - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_cleanstart_test_260630_01.dwg`
- `APPLOAD` confirmed `swcad_title_scale.lsp ready 260630-frame-def-clean-safe`.
- `SWTITLEFRAMEDEFCHECK` result:
  - `DR_A1_Outline`: not present, OK
  - `DR_A2_Outline`: not present, OK
  - `DR_A3_Outline`: not present, OK
  - `DR_A4_Outline`: not present, OK
  - Result: `OK_TARGET_FRAME_BLOCK_DEFINITIONS`
- `SWTITLEMULTIPREVIEW` result:
  - source title candidates: 13
  - source sheet frame candidates: 15
  - title candidates with frame: 13
  - frame-only sheet candidates: 2
  - source sheet frame counts: `A2: 1`, `A3: 12`, `A4: 2`
  - title sheet counts: `A2: 1`, `A3: 12`
  - elapsed: 76 ms
- Conclusion:
  - The original SOLIDWORKS DWG does not start with polluted target `DR_A*_Outline` definitions.
  - The pollution was introduced by an earlier conversion/import path.
  - The next conversion test should start from this clean work copy and verify that the current guarded clone path imports real clean `DR_A*_Outline` definitions instead of creating fake/polluted target definitions.

Fast remaining-sheet batch command:

- Added command:
  - `SWTITLETRANSFERFASTBATCH`
  - `SWTITLEFASTSTATUS`
  - `SWTITLETRANSFERBOOTSTRAPFAST`
- Purpose:
  - `SWTITLEFASTSTATUS` is a read-only readiness check for the fast route.
  - It reports source title count, source frame count, frame-only count, and A-size counts before any edit is attempted.
  - Counts every remaining source title sheet automatically.
  - Counts every remaining frame-only sheet automatically.
  - Runs the existing verified-native-GMTITLE clone path for title sheets.
  - Then runs the frame-only clone path for A4-like frame-only sheets.
  - `SWTITLETRANSFERBOOTSTRAPFAST` wraps the practical current workflow:
    - if a verified native GMTITLE exemplar already exists, it runs the fast remaining-sheet batch;
    - if no exemplar exists, it runs the first native `GMTITLE` transfer once, then starts the fast remaining-sheet batch after that first transfer succeeds.
- Preconditions:
  - Current DWG must be a writable work-folder copy.
  - Target `DR_A*_Outline` block definitions must not be contaminated.
  - For direct `SWTITLETRANSFERFASTBATCH`, at least one native `DR_titlea_3rd` GMTITLE exemplar with native xdata must already exist.
  - For `SWTITLETRANSFERBOOTSTRAPFAST`, either a native exemplar can already exist, or at least one source title sheet must remain so the command can create/finalize the first native exemplar.

Expected clean-start flow:

  - Use `SWTITLETRANSFERBOOTSTRAPFAST` for the current one-command flow.
  - Alternative manual flow: use `SWTITLETRANSFERAPPLY` or `SWTITLETRANSFERFINALIZE` once to create/finalize the first native GMTITLE exemplar.
  - Run `SWTITLETRANSFERFASTBATCH`.
  - It should process the remaining A2/A3 title sheets and the A4 frame-only sheets without asking for counts.
  - Run `SWTITLEGMTITLEVERIFYALL` and then manually double-click A2/A3/A4 titles for the final editor check.
- Important caveat:
  - This improves the fast multi-sheet automation flow, but it does not by itself prove the A3 double-click native GMTITLE table behavior.
  - The A3 GMTITLE recognition issue remains a required final-completion item.
- Clean-start abort test:
  - The updated LSP loaded successfully in the clean-start work copy.
  - Running `SWTITLETRANSFERFASTBATCH` before creating any native GMTITLE exemplar stopped safely.
  - Result reason: no native `DR_titlea_3rd` GMTITLE exemplar with native xdata exists yet.
  - The command instructed the user to run `SWTITLETRANSFERAPPLY` or `SWTITLETRANSFERFINALIZE` for the first sheet.
  - No drawing data should have been changed by this abort path.
- Fast-status test after adding `SWTITLEFASTSTATUS`:
  - Test copy:
    - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_fastbatch_test_260630_01.dwg`
  - Log:
    - `work\swcad_title_fast_status_last.txt`
  - Result:
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
  - Conclusion:
    - The current clean fastbatch test copy is correctly detected and safe to continue from.
    - The next bottleneck is automatic/native creation of the first `DR_A*_Outline + DR_titlea_3rd` GMTITLE exemplar.
    - Until that exemplar exists, `SWTITLETRANSFERFASTBATCH` should stop before modifying the drawing.
    - `SWTITLETRANSFERBOOTSTRAPFAST` is now the preferred command for this exact state because it handles the first-native step and then continues into the fast batch.
- Bootstrap guidance update:
  - Version: `260630-bootstrap-flow`
  - `SWTITLEFASTSTATUS` and `SWTITLETRANSFERBOOTSTRAPFAST` now print the next detected native GMTITLE bootstrap selection before editing.
  - On the clean bootstrap test copy, the next selection was:
    - source sheet: `A2`
    - paper/frame: `DR_A2_Outline`
    - title block: `DR_titlea_3rd`
  - `SWTITLETRANSFERBOOTSTRAPFAST` now treats both of these first-native statuses as successful bootstrap results:
    - `APPLIED_TITLE_TRANSFER`
    - `FINALIZED_EXISTING_GMTITLE_TRANSFER`
  - This fixes the flow bug where the first sheet could be created successfully by `SWTITLETRANSFERAPPLY`, but the remaining fast batch would not start because the bootstrap wrapper only recognized the finalize status.

Native GMTITLE command-line automation check:

- Test copy:
  - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_fastbatch_test_260630_01.dwg`
- Checks:
  - `-GMTITLE`
  - `CMDDIA=0`, then `GMTITLE`
- Result:
  - `-GMTITLE` returned an unknown-command message.
  - `GMTITLE` still opened the modal title/border dialog even with `CMDDIA=0`.
  - The dialog was canceled and `CMDDIA` was restored to `1`.

Native GMTITLE picker UI automation check:

- Test copy:
  - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_bootstrap_test_260630_01.dwg`
- Goal:
  - Select `DR_A2_Outline` and `DR_titlea_3rd` in the native GMTITLE dialog without screen-coordinate picking.
- Result:
  - Accessibility inspection could see the combo/list values, including `DR_A1_Outline`, `DR_A2_Outline`, `DR_A3_Outline`, and `DR_A4_Outline`.
  - Programmatic combo expansion and direct value setting did not reliably change the selected paper/frame.
  - Keyboard and list-item attempts were not reliable enough to use as a production automation path.
  - The dialog was canceled; no old source title/frame content was removed.

Repeat picker/config check on strict clean copy:

- Test copy:
  - `C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260604_strictnative_test_260630_01.dwg`
- `SWTITLETRANSFERBOOTSTRAPFAST` correctly detected the first bootstrap sheet as:
  - source sheet: `A2`
  - paper/frame: `DR_A2_Outline`
  - title block: `DR_titlea_3rd`
- The native `GMTITLE` dialog still opened with GstarCAD defaults:
  - paper: `A3 (297x420mm)`
  - title block: `ISO title block A`
  - object move: on
- Accessibility inspection could see `DR_A2_Outline`, but direct element selection, keyboard selection, and direct combo value setting did not reliably change the selected value.
- The dialog was canceled and the pending insertion state was escaped.
- `SWTITLETRANSFERAPPLY` ended safely with `ABORT_NO_NATIVE_GMTITLE_TITLE`; no old SOLIDWORKS title/frame content was removed.
- `SWTITLEFASTSTATUS` after the abort still reported:
  - source title sheets: `13`
  - source sheet frames: `15`
  - frame-only sheets: `2`
  - native GMTITLE exemplar: `no`
  - contaminated target frame definitions: `<none>`
  - result: `WAITING_FOR_NATIVE_GMTITLE_EXEMPLAR`

Config/registry check:

- Read-only searches in the GstarCAD installation folder, user `AppData\Local\Gstarsoft`, user `AppData\Roaming\Gstarsoft`, and `HKCU\Software\Gstarsoft` did not reveal a simple stored value for `DR_A2_Outline`, `DR_titlea_3rd`, or `GMTITLE`.
- Text settings such as `impro.ini`, `PublicSymbol.ini`, and `CalVar.ini` do not contain the native GMTITLE picker selection.
- Current conclusion: there is still no proven way to pre-fill the first native `GMTITLE` dialog from LISP or a simple config value.
- Practical safe route remains: create/finalize the first native GMTITLE once through the real dialog, then use the fast batch path for the remaining title sheets and A4 frame-only sheets.

Native-link diagnostic update:

- Version: `260630-native-link-verify`
- `SWTITLEGMTITLELINKSCAN`, `SWTITLEGMTITLEVERIFY`, and `SWTITLEGMTITLEVERIFYALL` now classify each `GENIUS_GENOREF_13` native link target as:
  - `internal`
  - `visible-target-frame`
  - `visible-target-title`
  - `visible-insert`
  - `missing`
  - or the raw DXF entity type.
- On `0000_A_DRP125_CP_ALL_260604_a4_native_test_260630_01.dwg`, the scan showed:
  - Native A2 title: `native-target-kinds=internal`
  - Native/default A4 title: `native-target-kinds=internal`
  - Cloned A3 titles: `native-target-kinds=visible-target-frame`
- `SWTITLEGMTITLELINKSCAN` now returns `WARN_NATIVE_LINKS_POINT_TO_VISIBLE_FRAMES` when any title block links directly to the visible `DR_A*_Outline` frame insert.
- This is now the strongest concrete clue for the A3 editor issue:
  - Real native GMTITLE titles appear to point to an internal object handle.
  - The current cloned A3 route points to the visible frame insert handle.
  - A cloned title can therefore have attributes and `native-links=1` but still fail the native GMTITLE table-editor behavior.

Native-link raw detail update:

- Version: `260630-native-link-detail`
- Added command:
  - `SWTITLEGMTITLELINKDETAIL`
- Log:
  - `work\swcad_title_gmtitle_link_detail_last.txt`
- Purpose:
  - Dump the raw target object behind each title block's native GMTITLE handle.
  - Distinguish an internal/native recognition handle from a visible cloned frame insert.
- Result on `0000_A_DRP125_CP_ALL_260604_a4_native_test_260630_01.dwg`:
  - Native A2 title `16BE8` points to handle `16BF5`.
    - target kind: `internal-no-entget`
    - VLA object: `<none>`
    - raw `entget`: `<nil>`
  - Native/default A4 title `17AD3` points to handle `17AE0`.
    - target kind: `internal-no-entget`
    - VLA object: `<none>`
    - raw `entget`: `<nil>`
  - Cloned A3 titles point to visible `DR_A3_Outline` frame inserts.
    - target kind: `visible-target-frame`
    - VLA object: `AcDbBlockReference`
    - raw `entget`: ordinary visible `INSERT` data
- Interpretation:
  - The native A2/A4 GMTITLE command creates or references a hidden/internal recognition object that is addressable by handle, but not exposed as a normal graphical entity through `entget` or VLA.
  - The current fast clone route does not recreate that internal object. It links the title directly to the visible frame insert instead.
  - This explains why the fast route can correctly transfer geometry, attributes, and visible output while still not being proven as a complete native GMTITLE object.
- Development decision:
  - It is acceptable during development for cloned A3 sheets to open in the Advanced Attribute Editor.
  - Before final completion, the A3 recognition problem must be solved or a different native-creation strategy must be used so A2/A3/A4 all open the GMTITLE table editor on double-click.

Native-vs-clone compare diagnostic update:

- Version: `260630-gmtitle-compare`
- Added command:
  - `SWTITLEGMTITLECOMPARE`
- Log:
  - `work\swcad_title_gmtitle_compare_last.txt`
- Purpose:
  - Print one known internal/native GMTITLE title and one visible-frame-linked cloned GMTITLE title side by side.
  - Make the A3 recognition problem easier to inspect without editing the drawing.
- CAD test result on `0000_A_DRP125_CP_ALL_260604_a4_native_test_260630_01.dwg`:
  - The command loaded and ran successfully.
  - Result: `OK_COMPARE_INTERNAL_AND_VISIBLE_FRAME_LINK`
  - Internal/native exemplar:
    - title handle: `16BE8`
    - sheet: `A2`
    - linked handle: `16BF5`
    - native target kind: `internal-no-entget`
    - nearest visible frame: `DR_A2_Outline/16B22`
    - link matches nearest visible frame: `no`
  - Visible-frame-linked clone exemplar:
    - title handle: `17919`
    - sheet: `A3`
    - linked handle: `17918`
    - native target kind: `visible-target-frame`
    - nearest visible frame: `DR_A3_Outline/17918`
    - link matches nearest visible frame: `yes`
- Interpretation:
  - The real native GMTITLE title is not linked directly to the visible frame insert.
  - The cloned A3 title is linked directly to the visible frame insert.
  - This is now the clearest concrete difference to investigate before claiming that the cloned A3 sheets are true native GMTITLE objects.

Preserve-copy experiment command:

- Version: `260630-preserve-copy-test`
- Added command:
  - `SWTITLEGMTITLEPRESERVECOPYTEST`
- Log:
  - `work\swcad_title_gmtitle_preserve_copy_test_last.txt`
- Purpose:
  - Copy one real native GMTITLE frame/title pair without rewriting the title's `GENIUS_GENOREF_13` xdata to the visible frame handle.
  - Place the copied pair to the right side of the current target frames.
  - Optionally retarget the copied frame insert to `DR_A1_Outline`, `DR_A2_Outline`, `DR_A3_Outline`, or `DR_A4_Outline` for recognition experiments.
  - Never remove old SOLIDWORKS title/frame content.
- Safety:
  - Runs only on writable `Documents\CAD tool\work` copies.
  - Requires explicit `YES` before copying.
  - If the requested target frame definition already exists and is contaminated, it aborts before modifying the drawing.
  - Missing clean frame definitions are imported only after the `YES` confirmation and inside the undo mark.
- Intended next CAD test:
  - First run with target `SAME`.
  - Check whether the copied title still reports `native-target-kinds=internal-no-entget`.
  - If `SAME` preserves the internal link, run a second test with target `A3` on a clean work copy.
  - Manually double-click the copied title block to see whether it opens the native GMTITLE table editor or the Advanced Attribute Editor.
- Current verification status:
  - Static checks passed: `git diff --check`, and a simple parenthesis-balance check returned `parenDepth=0`.
  - Direct CAD command-line input became unreliable during this session because the floating command line repeatedly fell into an `Specify insertion point` state.
  - Launching a separate GstarCAD instance with a `/b` script produced a blank startup/modal window and did not create the preserve-copy log.
  - Therefore the new command is implemented but still needs a successful in-CAD execution test before it can be trusted for the production flow.

Strict native exemplar update:

- Version: `260630-strict-native-exemplar`
- Fast clone phases now require a usable native GMTITLE exemplar whose `GENIUS_GENOREF_13` link target kind is `internal` or `internal-no-entget`.
- Titles whose native link points directly to a visible cloned `DR_A*_Outline` frame are no longer accepted as exemplars.
- Reason:
  - A visible-frame-linked clone can carry attributes and native xdata but still fail the native GMTITLE table-editor behavior.
  - Reusing that clone as the next exemplar would multiply the uncertain state.
- Expected behavior:
  - `SWTITLEFASTSTATUS`, `SWTITLETRANSFERFASTBATCH`, and `SWTITLETRANSFERBOOTSTRAPFAST` should report the exemplar handle and `native-link-kinds` when a real native exemplar exists.
  - If only visible-frame-linked clones exist, fast batch should stop with `ABORT_NO_NATIVE_GMTITLE_EXEMPLAR` instead of cloning from an unproven source.

Conclusion:

  - There is no obvious command-line `GMTITLE` variant available in this installation.
  - The first native GMTITLE exemplar cannot currently be created by passing simple command-line options to `GMTITLE`.
  - Direct UI automation of the GMTITLE picker is also not reliable enough to be treated as the final automatic solution.
  - AppData/registry searches did not reveal a simple saved selection value that can be set before launching `GMTITLE`.
  - Next practical options are either:
    - use `SWTITLETRANSFERBOOTSTRAPFAST` so the first native dialog appears only once, with the exact detected DR paper/title values printed in the command line, and the remaining sheets are processed automatically after the first native transfer succeeds; or
    - investigate the internal native recognition data more deeply so the first exemplar can be constructed without the dialog.

## Concern

`native-links=1` proves that the cloned title block has at least one native xdata link, but it does not prove that the complete GstarCAD Mechanical GMTITLE recognition state is valid.

Possible missing pieces:

- xdata on the frame insert, not only on the title insert
- bidirectional links between title and frame
- extension dictionary entries
- reactors or persistent object references
- object ownership/order assumptions created only by the real `GMTITLE` command
- click target differences between block reference and individual attributes

The current diagnostic also shows that the visible target frame block definitions can be polluted by old SOLIDWORKS source block definitions:

- `DR_A3_Outline` contains old child insert `DR-A3 From_HYUN`.
- `DR_A2_Outline` contains old child insert `DR-A2 From_HYUN`.
- After the A4 native test, `DR_A4_Outline` contains old child insert `도면 세로 A4 From_HYUN`.

This explains why some sheets visually or structurally behave like ordinary block references even though the title inserts have attributes and native xdata.

## Next Investigation

Compare one known-good title block that opens the native GMTITLE table editor with one cloned title block that opens the Advanced Attribute Editor.

For each pair, inspect and compare:

- raw `entget` with xdata
- title insert xdata apps and handle values
- frame insert xdata apps and handle values
- extension dictionary handles
- reactor lists
- owner handles
- block reference names and effective names
- linked object handles referenced by `GENIUS_GENOREF_13`

## Acceptance Criteria

The clone route can be considered complete only when:

- Every cloned title block opens the native GMTITLE table editor on double-click.
- The verification command can detect the relevant internal condition, not just `native-links=1`.
- A known-bad cloned title block fails the new verifier.
- A known-good native GMTITLE title block passes the new verifier.

## Practical Direction

Until this is resolved, treat `SWTITLETRANSFERCLONEBATCH` as a fast test/transfer route, not as the final production-safe route.

For production-safe conversion, prefer native `GMTITLE` creation or a verified internal clone method once the missing recognition condition is found.

Implementation priority:

1. Keep using the clean-start work copy for the next full conversion test because it starts with no target `DR_A*_Outline` definitions.
2. First finish the fast multi-sheet generation path when visible output, title values, sheet sizes, and cleanup are correct.
3. Keep the A4 frame-only path separate because the A4 sheets are detected as frame-only sheets with no source title inserts.
4. Before every clone/import conversion, run `SWTITLEFRAMEDEFCHECK` or rely on the built-in contaminated-definition guard so old SOLIDWORKS frame blocks do not masquerade as native DR frame blocks.
5. Keep the Advanced Attribute Editor issue as a follow-up investigation during development, but resolve the A3 GMTITLE recognition issue before final completion.
