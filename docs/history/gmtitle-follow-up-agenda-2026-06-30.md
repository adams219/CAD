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
- Purpose:
  - `SWTITLEFASTSTATUS` is a read-only readiness check for the fast route.
  - It reports source title count, source frame count, frame-only count, and A-size counts before any edit is attempted.
  - Counts every remaining source title sheet automatically.
  - Counts every remaining frame-only sheet automatically.
  - Runs the existing verified-native-GMTITLE clone path for title sheets.
  - Then runs the frame-only clone path for A4-like frame-only sheets.
- Preconditions:
  - Current DWG must be a writable work-folder copy.
  - At least one native `DR_titlea_3rd` GMTITLE exemplar with native xdata must already exist.
  - Target `DR_A*_Outline` block definitions must not be contaminated.
- Expected clean-start flow:
  - Use `SWTITLETRANSFERAPPLY` or `SWTITLETRANSFERFINALIZE` once to create/finalize the first native GMTITLE exemplar.
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
