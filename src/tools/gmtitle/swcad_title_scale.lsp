;;; Read-only title-block and scale diagnostic module.
;;;
;;; Main workflow:
;;;   APPLOAD this file directly, then run:
;;;     SWTITLESTATUS
;;;     SWTITLEPREPARE     ; only when SWTITLESTATUS asks for preparation
;;;     SWTITLECONVERTNEXT ; recommended next safe conversion step
;;;     SWTITLEVERIFY
;;; Manual fallback:
;;;     SWTITLECONVERT
;;;   uses the same conversion decision tree, but asks the operator to choose
;;;   YES, OPEN, BATCH, or MANUAL. Use it only when you intentionally need to
;;;   override the SWTITLECONVERTNEXT default. GMTITLE dialog paper/title/options
;;;   are selected by fixed Win32 control IDs when the bundled helper is available.
;;;   Manual visual selection remains the safe fallback when that helper cannot run.
;;;
;;; Older transfer, batch, frame-only, and native recovery routines remain
;;; as internal implementation helpers. They are intentionally not the user
;;; workflow, because past testing showed that many narrow commands make the
;;; conversion order hard to follow and easy to repeat incorrectly.
;;; Verifiers also warn when the raw CAD selection bbox is much larger
;;; than the effective visible frame, because that can make GMPOWEREDIT
;;; or double-click hit the frame/block instead of the title editor.
;;; Fast clone phases now require a real native exemplar whose GMTITLE link
;;; targets an internal recognition handle, not a visible cloned frame insert.
;;; Verifiers warn when multiple title blocks share one internal GMTITLE link,
;;; because that preserve-copy pattern can still fail GMPOWEREDIT.
;;; A2/A3/A4 native-recheck or cloned GMTITLE pairs are normally handled through
;;; SWTITLECONVERTNEXT, one sheet at a time, so the GMTITLE dialog can be
;;; visually verified before the next sheet is touched. SWTITLECONVERT remains
;;; the manual-response fallback. Use BATCH only after one OPEN pass proves the
;;; candidate count decreases and the same DR frame/title/options repeat.
;;; Command-line -GMTITLE selection is disabled by default. Local CAD
;;; history showed it can choose ordinary ISO/A-series defaults instead
;;; of the required DR_A*_Outline + DR_titlea_3rd pair.
;;; SWTITLEVERSION prints the currently loaded LSP version so stale CAD loads
;;; are easy to spot before trusting status logs.
;;; SWSCALESCAN compares title-block scale candidates with dimension
;;; DIMLFAC values. It does not modify the drawing.

(vl-load-com)

(setq *swcad-title-scale-version* "260712-portable-saveas-offsheet-frame-1")
(setq *swcad-title-scale-loaded* T)
(setq *swcad-title-korean-output* T)
(setq *swcad-title-log-file-suffix* nil)
(setq *swcad-title-allow-moved-native-placement-after-geometry-check* T)
(setq *swcad-title-debug-log-path* nil)
(setq *swcad-title-debug-log-handle* nil)
(setq *swcad-title-batch-mode* nil)
(setq *swcad-title-convert-next-mode* nil)
(setq *swcad-title-last-apply-status* nil)
(setq *swcad-title-last-clone-failure* nil)
(setq *swcad-title-last-native-gmtitle-abort-reason* nil)
(setq *swcad-title-last-native-gmtitle-placement-used* nil)
(setq *swcad-title-allow-commandline-gmtitle* nil)
(setq *swcad-title-allow-script-commandline-gmtitle* nil)
(setq *swcad-title-exemplar-xdata-app* "SWTITLE_EXEMPLAR")
(setq *swcad-title-exemplar-xdata-marker* "SWTITLE_NATIVE_EXEMPLAR")
(setq *swcad-title-workcopy-xdata-app* "SWTITLE_WORKCOPY")
(setq *swcad-title-workcopy-xdata-marker* "SWTITLE_SELECTED_WORKCOPY")
(setq *swcad-title-expected-sheet-counts-marker* "SWTITLE_EXPECTED_SHEET_COUNTS")
(setq *swcad-title-expected-title-counts-marker* "SWTITLE_EXPECTED_TITLE_COUNTS")
(setq *swcad-title-pending-native-title-ename* nil)
(setq *swcad-title-pending-native-frame-ename* nil)
(setq *swcad-title-pending-native-frame-block* nil)
(setq *swcad-title-pending-gmtitle-role* nil)
(setq *swcad-title-native-upgrade-batch-mode* nil)
(setq *swcad-title-native-upgrade-selected-pair* nil)
(setq *swcad-title-allow-batch-interactive-native-gmtitle* nil)
(setq *swcad-title-gmtitle-dialog-autoselect-enabled* T)
(setq *swcad-title-frame-style-analysis-cache-enabled* nil)
(setq *swcad-title-frame-style-analysis-cache-valid* nil)
(setq *swcad-title-frame-style-analysis-cache-records* nil)
(setq *swcad-title-last-gmtitle-autoselect-started* nil)
(setq *swcad-title-skip-native-upgrade-confirmation* nil)
(setq *swcad-title-a3a4-batch-default-all* nil)
(setq *swcad-title-pending-manual-native-upgrade* nil)
(setq *swcad-title-native-placement-trust-tolerance* 0.5)
(setq *swcad-title-target-frame-block-name* "DR_A3_Outline")
(setq *swcad-title-target-title-block-name* "DR_titlea_3rd")
(setq *swcad-title-disabled-legacy-public-commands* nil)
(setq *swcad-title-work-copy-saveas-path-override* nil)
(setq *swcad-title-source-path*
  (cond
    ((and (boundp '*load-truename*) *load-truename*) *load-truename*)
    ((findfile "swcad_title_scale.lsp") (findfile "swcad_title_scale.lsp"))
    (T nil)
  )
)

(defun swcad-title-disable-legacy-public-commands (/ names name symbol)
  (setq names
    '(
      "c:SWTITLEDEBUG"
      "c:SWTITLESCAN"
      "c:SWTITLETEXTSCAN"
      "c:SWTITLEMULTIPREVIEW"
      "c:SWTITLEFASTSTATUS"
      "c:SWTITLENEXTSTEP"
      "c:SWTITLESTATUSREFRESH"
      "c:SWTITLETRANSFERPREVIEW"
      "c:SWTITLETRANSFERAPPLY"
      "c:SWTITLETRANSFERFINALIZE"
      "c:SWTITLETRANSFERBATCH"
      "c:SWTITLETRANSFERCLONEAPPLY"
      "c:SWTITLETRANSFERCLONEBATCH"
      "c:SWTITLETRANSFERFASTBATCH"
      "c:SWTITLETRANSFERBOOTSTRAPFAST"
      "c:SWTITLEFRAMEONLYAPPLY"
      "c:SWTITLEFRAMEONLYFINALIZE"
      "c:SWTITLEFRAMEONLYCLONEAPPLY"
      "c:SWTITLEFRAMEONLYCLONEBATCH"
      "c:SWTITLEA3A4NEXT"
      "c:SWTITLEA3A4ALL"
      "c:SWTITLEA3FRAMECLEAN"
      "c:SWTITLECLEANORPHANFRAME"
      "c:SWTITLEUPGRADENATIVESTATUS"
      "c:SWTITLEUPGRADENATIVEA3A4BATCH"
      "c:SWTITLEGMTITLEVERIFY"
      "c:SWTITLEGMTITLEVERIFYALL"
      "c:SWTITLEGMTITLELINKSCAN"
      "c:SWTITLEGMTITLELINKDETAIL"
      "c:SWTITLEGMTITLECOMPARE"
      "c:SWTITLEGMTITLEPRESERVECOPYTEST"
      "c:SWTITLENATIVEFRAMECHECK"
      "c:SWTITLEDOUBLECLICKCHECK"
      "c:SWTITLEPICKCHECK"
      "c:SWTITLECOMMANDTEXTSCAN"
      "c:SWTITLECOMMANDTEXTCLEANSAFE"
      "c:SWTITLEFRAMEDEFCHECK"
      "c:SWTITLEFRAMEDEFCLEANSAFE"
      "c:SWTITLEFRAMEDEFREPAIR"
      "c:SWTITLEFRAMEDEFTITLECLEAN"
    )
  )
  (setq *swcad-title-disabled-legacy-public-commands* names)
  (foreach name names
    (setq symbol (read name))
    (if symbol
      (set symbol nil)
    )
  )
  names
)

(defun swcad-title-replace-all (text from to / result pos)
  (setq result text)
  (if
    (and
      from
      (> (strlen from) 0)
      (/= from to)
      (not (vl-string-search from to))
    )
    (while (setq pos (vl-string-search from result))
      (setq result (vl-string-subst to from result pos))
    )
  )
  result
)

(defun swcad-title-result-description (status / pair)
  (setq pair
    (assoc
      status
      '(
        ("FINALIZED_CLONED_GMTITLE_TRANSFER" . "clone 변환은 완료됐지만 더블클릭 표 편집을 위해 SWTITLECONVERT의 native 교체 단계가 아직 필요합니다.")
        ("FINALIZED_EXISTING_GMTITLE_TRANSFER" . "기존/native GMTITLE 변환이 완료됐습니다.")
        ("ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER" . "이미 같은 위치에 있던 native GMTITLE 쌍을 채택해 값 입력과 기존 잔여물 정리를 완료했습니다.")
        ("FINALIZED_FRAME_ONLY_GMTITLE_TRANSFER" . "표제란 없는 도면틀 시트 변환이 완료됐습니다.")
        ("FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER" . "원본 표제란 부재가 검증된 시트의 도면틀만 교체했습니다.")
        ("READY_FOR_TITLE_MISSING_OUTLINE" . "title-missing/frame-only 시트를 제목블록 없이 도면틀만 교체할 수 있습니다.")
        ("WAITING_FOR_TITLE_MISSING_OUTLINE_DEFINITION" . "title-missing/frame-only 변환 전에 같은 크기 DR 도면틀 정의를 먼저 검증해야 합니다.")
        ("NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION" . "title-missing/frame-only 변환 전에 SWTITLEPREPARE로 같은 크기 DR 도면틀 정의를 준비해야 합니다.")
        ("OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED" . "DR 도면틀 정의를 가져와 title-missing/frame-only 변환 준비가 됐습니다.")
        ("WARN_TITLE_MISSING_OUTLINE_DEFINITION_UNSAFE" . "DR 도면틀 정의를 가져왔지만 형상/선택범위 검사를 통과하지 못했습니다.")
        ("ABORT_TITLE_MISSING_OUTLINE_DEFINITION_USER" . "사용자가 title-missing/frame-only 도면틀 정의 준비를 취소했습니다.")
        ("WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS" . "남은 시트 크기와 같은 첫 native GMTITLE이 필요합니다.")
        ("OK_FAST_BATCH_COMPLETE" . "빠른 일괄 변환이 완료됐습니다.")
        ("OK_NO_REMAINING_SOURCES" . "남은 원본 시트가 없습니다.")
        ("STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE" . "남은 SolidWorks 원본 표제란 시트가 없습니다.")
        ("STOP_NO_MORE_FRAME_ONLY_SOURCE" . "남은 frame-only 시트가 없습니다.")
        ("ABORT_NOT_WORK_COPY" . "작업복사본이 아니어서 중단했습니다.")
        ("ABORT_MULTIPLE_OPEN_DWGS" . "여러 도면이 열려 있어 현재 활성 도면 확인이 필요해 중단했습니다.")
        ("ABORT_READ_ONLY_DOCUMENT" . "읽기 전용 도면이라 중단했습니다.")
        ("ABORT_USER_CANCEL" . "사용자가 취소했습니다.")
        ("ABORT_EXISTING_GMTITLE_NOT_FOUND" . "필요한 GMTITLE 쌍을 찾지 못했습니다.")
        ("ABORT_EXISTING_GMTITLE_WRONG_SELECTION" . "GMTITLE 용지/제목블록 선택이 예상과 다릅니다.")
        ("ABORT_NATIVE_UPGRADE_WRONG_GMTITLE_SELECTION" . "native 교체 중 잘못된 용지/제목블록이 선택되어 새 객체를 제거하고 기존 객체를 보존했습니다.")
        ("ABORT_NATIVE_UPGRADE_WRONG_LOCATION" . "GMTITLE이 대상 도면틀 왼쪽 아래 위치에 생성되지 않아 중단했습니다.")
        ("ABORT_EXISTING_FRAME_ONLY_GMTITLE_RAW_BBOX_EXTRA_OBJECTS" . "title-missing GMTITLE 도면틀의 실제 선택 범위에 틀 밖 객체가 붙어 있어 기존 원본 도면틀을 지우지 않고 중단했습니다.")
        ("ABORT_TITLE_MISSING_OUTLINE_UNAVAILABLE" . "title-missing 도면틀만 교체 경로를 사용할 수 없어 중단했습니다.")
        ("ABORT_TITLE_MISSING_OUTLINE_INVALID_GEOMETRY" . "새 도면틀 범위가 원본과 맞지 않아 중단했습니다.")
        ("WARN_REQUIRED_TARGET_SHEET_MISSING" . "현재 원본/대상 기준으로 필요한 GMTITLE 대상 용지가 누락됐습니다.")
        ("WARN_REQUIRED_A2_A3_A4_TARGET_SHEET_MISSING" . "현재 원본/대상 기준으로 필요한 GMTITLE 대상 용지가 누락됐습니다.")
        ("WARN_A2_A3_A4_TARGET_FRAME_NOT_NATIVE_LIKE" . "A2/A3/A4 GMTITLE 대상 쌍 중 native-like 검증이 끝나지 않은 쌍이 남아 있습니다.")
        ("UPGRADED_CLONE_TO_NATIVE_GMTITLE" . "clone GMTITLE을 실제 native GMTITLE로 교체했습니다.")
        ("OK_NATIVE_GMTITLE_UPGRADE_BATCH_COMPLETE" . "A2/A3/A4 native 교체 후보가 모두 처리됐습니다.")
        ("WARN_NATIVE_GMTITLE_UPGRADE_BATCH_REMAINING" . "A2/A3/A4 native 교체 후보가 일부 남았습니다.")
        ("OK_ORPHAN_TARGET_FRAMES_CLEANED" . "제목블록이 없는 고아 GMTITLE 도면틀을 정리했습니다.")
        ("OK_NO_ORPHAN_TARGET_FRAMES" . "정리할 고아 GMTITLE 도면틀이 없습니다.")
        ("ABORT_ORPHAN_TARGET_FRAME_CLEAN_USER" . "사용자가 고아 도면틀 정리를 취소했습니다.")
        ("ERROR_ORPHAN_TARGET_FRAME_CLEAN" . "고아 도면틀 정리 중 오류가 발생했습니다.")
        ("OK_DUPLICATE_TARGET_PAIRS_CLEANED" . "같은 위치에 겹친 GMTITLE target 쌍을 정리했습니다.")
        ("OK_NO_DUPLICATE_TARGET_PAIRS" . "정리할 겹친 GMTITLE target 쌍이 없습니다.")
        ("ABORT_DUPLICATE_TARGET_PAIR_CLEAN_USER" . "사용자가 겹친 GMTITLE target 쌍 정리를 취소했습니다.")
        ("ERROR_DUPLICATE_TARGET_PAIR_CLEAN" . "겹친 GMTITLE target 쌍 정리 중 오류가 발생했습니다.")
        ("OK_FRAME_DEF_TITLE_CHILDREN_CLEANED" . "도면틀 블록 정의 안에 중첩된 제목블록을 정리했습니다.")
        ("OK_NO_FRAME_DEF_TITLE_CHILDREN" . "도면틀 블록 정의 안에 중첩된 제목블록이 없습니다.")
        ("ABORT_FRAME_DEF_TITLE_CLEAN_USER" . "사용자가 도면틀 정의 제목블록 정리를 취소했습니다.")
        ("ERROR_FRAME_DEF_TITLE_CLEAN" . "도면틀 정의 제목블록 정리 중 오류가 발생했습니다.")
        ("OK_A3_FRAME_EMBEDDED_TITLE_CLEANED" . "A3 도면틀 정의 안에 합쳐진 표제란 형상을 정리했습니다.")
        ("OK_NO_A3_FRAME_EMBEDDED_TITLE" . "정리할 A3 도면틀 내부 표제란 형상이 없습니다.")
        ("ABORT_A3_FRAME_EMBEDDED_TITLE_CLEAN_USER" . "사용자가 A3 도면틀 내부 표제란 정리를 취소했습니다.")
        ("ERROR_A3_FRAME_EMBEDDED_TITLE_CLEAN" . "A3 도면틀 내부 표제란 정리 중 오류가 발생했습니다.")
        ("OK_FRAME_EMBEDDED_TITLE_CLEANED" . "DR 도면틀 정의 안에 합쳐진 표제란 형상을 정리했습니다.")
        ("OK_NO_FRAME_EMBEDDED_TITLE" . "정리할 DR 도면틀 내부 표제란 형상이 없습니다.")
        ("ABORT_FRAME_EMBEDDED_TITLE_CLEAN_USER" . "사용자가 DR 도면틀 내부 표제란 정리를 취소했습니다.")
        ("ERROR_FRAME_EMBEDDED_TITLE_CLEAN" . "DR 도면틀 내부 표제란 정리 중 오류가 발생했습니다.")
        ("OK_FRAME_STYLE_NORMALIZATION_CLEANED" . "도면틀 스타일 정규화 후보를 정리했습니다.")
        ("OK_NO_FRAME_STYLE_NORMALIZATION" . "정규화가 필요한 도면틀 스타일 후보가 없습니다.")
        ("WARN_RESIDUE_REMAINS" . "정리 후 독립 검증에서 기존 표제란 잔여 형상이 남아 있습니다.")
        ("WARN_FRAME_STYLE_RESIDUE_UNCLASSIFIED" . "기존 표제란 잔여 형상은 확인됐지만 안전한 자동 삭제 대상으로 분류되지 않았습니다.")
        ("ABORT_FRAME_STYLE_NORMALIZATION_USER" . "사용자가 도면틀 스타일 정규화를 취소했습니다.")
        ("ERROR_FRAME_STYLE_NORMALIZATION_CLEAN" . "도면틀 스타일 정규화 중 오류가 발생했습니다.")
        ("NEXT_OPEN_WRITABLE_WORK_COPY" . "변경 전에 work 폴더의 쓰기 가능한 작업복사본을 열어야 합니다.")
        ("NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT" . "도면에 실수로 들어간 명령어 텍스트 후보를 먼저 확인해야 합니다.")
        ("NEXT_PREPARE_FRAME_STYLE_NORMALIZATION" . "도면틀 안 native 표제란 형상이 별도 제목블록과 겹쳐 정규화가 먼저 필요합니다.")
        ("NEXT_REVIEW_TARGET_FRAME_GEOMETRY" . "대상 도면틀의 크기나 선택 범위가 이상하므로 먼저 확인해야 합니다.")
        ("NEXT_REVIEW_TARGET_FRAME_SELECTION" . "도면틀 선택 범위가 겹치거나 너무 커서 더블클릭/편집 대상이 빗나갈 수 있습니다.")
        ("NEXT_CLEAN_ORPHAN_TARGET_FRAMES" . "제목블록 없는 GMTITLE 도면틀이 남아 있어 먼저 정리해야 합니다.")
        ("NEXT_UPGRADE_NATIVE_GMTITLE" . "복제/shared-link A2/A3/A4 GMTITLE을 실제 native GMTITLE로 교체해야 합니다.")
        ("NEXT_CREATE_FIRST_NATIVE_GMTITLE" . "첫 실제 native GMTITLE 기준 객체를 하나 만들어야 합니다.")
        ("NEXT_CREATE_MISSING_NATIVE_EXEMPLAR" . "남은 용지 크기와 같은 native GMTITLE 기준 객체를 먼저 만들어야 합니다.")
        ("NEXT_RUN_FAST_BATCH" . "필요한 native 기준 객체가 준비됐으므로 남은 시트를 빠른 변환으로 처리할 수 있습니다.")
        ("NEXT_CREATE_MISSING_TARGET_SHEET" . "원본에 있던 용지 크기 중 변환된 GMTITLE 대상 시트가 누락됐습니다.")
        ("NEXT_REVIEW_TARGET_SHEET_COUNT_SHORTAGE" . "변환 기준 수량보다 GMTITLE 대상 도면틀 수가 부족합니다.")
        ("NEXT_REVIEW_MISSING_NATIVE_TITLES" . "제목 정보가 있던 시트의 native GMTITLE 제목블록이 누락됐습니다.")
        ("NEXT_FINAL_VERIFY_AND_DOUBLE_CLICK" . "검증 로그를 확인하고 대표 제목블록을 더블클릭해 GMTITLE 표 편집창을 확인하세요.")
        ("WARN_TARGET_FRAME_GEOMETRY_INVALID" . "대상 도면틀의 크기/범위가 예상 용지와 맞지 않아 자동 변환을 계속하면 위험합니다.")
        ("WARN_TARGET_FRAME_SELECTION_RISK" . "도면틀 선택 범위가 겹치거나 너무 커서 잘못된 객체가 선택될 위험이 있습니다.")
        ("WARN_FAST_BATCH_REMAINING_SOURCES" . "빠른 변환 후에도 원본 SolidWorks 시트가 남아 있습니다.")
        ("WARN_FAST_BATCH_FRAME_DEFS_CONTAMINATED" . "대상 도면틀 블록 정의에 오염 의심 요소가 있어 먼저 정규화가 필요합니다.")
        ("ABORT_FRAME_STYLE_NOT_NORMALIZED" . "도면틀 스타일 정규화가 필요해 변환을 중단했습니다.")
        ("WARN_ACCIDENTAL_COMMAND_TEXT_FOUND" . "도면 안에 실수로 입력된 명령어 텍스트 후보가 있습니다.")
        ("OK_NO_ACCIDENTAL_COMMAND_TEXT_FOUND" . "실수 명령어 텍스트 후보가 없습니다.")
        ("OK_COMMAND_TEXT_CLEANED" . "실수 명령어 텍스트 후보를 정리했습니다.")
        ("ABORT_COMMAND_TEXT_CLEAN_USER" . "사용자가 실수 명령어 텍스트 정리를 취소했습니다.")
        ("ABORT_NO_SOURCE_TITLE" . "변환할 SolidWorks 원본 표제란을 찾지 못했습니다.")
        ("ABORT_NO_FRAME_ONLY_SOURCE" . "변환할 표제란 없는 도면틀 시트를 찾지 못했습니다.")
        ("ABORT_ORPHAN_TARGET_FRAMES_REMAIN" . "제목블록 없는 GMTITLE 도면틀이 남아 있어 변환을 중단했습니다.")
        ("ABORT_NO_TITLE_SOURCE_FOR_BOOTSTRAP" . "첫 native GMTITLE을 만들 원본 표제란 시트가 없습니다.")
        ("ABORT_NO_NATIVE_GMTITLE_EXEMPLAR" . "복제/일괄 변환에 필요한 native GMTITLE 기준 객체가 없습니다.")
        ("ABORT_NO_NATIVE_GMTITLE_TITLE" . "GMTITLE 실행 후 사용할 native 제목블록을 찾지 못했습니다.")
        ("ABORT_TITLE_ATTRIBUTE_VERIFICATION" . "새 GMTITLE 제목블록에 입력한 값이 원본과 일치하지 않아 기존 원본을 보존하고 중단했습니다.")
        ("ABORT_NO_INTERNAL_NATIVE_TITLE" . "GMTITLE 내부 native 인식 제목블록을 찾지 못했습니다.")
        ("ABORT_NO_NEAREST_NATIVE_FRAME" . "제목블록과 짝이 되는 native 도면틀을 찾지 못했습니다.")
        ("ABORT_INVALID_TARGET_SHEET" . "대상 도면틀의 용지 크기를 A2/A3/A4로 판정하지 못했습니다.")
        ("ABORT_COPY_NATIVE_PAIR_FAILED" . "native GMTITLE 쌍 복사에 실패했습니다.")
        ("ABORT_CLONE_GMTITLE_PAIR_FAILED" . "GMTITLE 쌍 복제에 실패했습니다.")
        ("ABORT_FRAME_ONLY_CLONE_FAILED" . "표제란 없는 도면틀 시트 복제에 실패했습니다.")
        ("ERROR_CLONE_FINALIZE" . "복제된 GMTITLE 마무리 처리 중 오류가 발생했습니다.")
        ("ERROR_FRAME_ONLY_CLONE_FINALIZE" . "복제된 frame-only GMTITLE 마무리 처리 중 오류가 발생했습니다.")
        ("ERROR_TRANSFER_FINALIZE" . "표제란 변환 마무리 처리 중 오류가 발생했습니다.")
        ("ERROR_FRAME_ONLY_FINALIZE" . "frame-only 변환 마무리 처리 중 오류가 발생했습니다.")
        ("ERROR_FRAME_ONLY_NATIVE_APPLY" . "frame-only native GMTITLE 적용 중 오류가 발생했습니다.")
        ("ERROR_FRAME_ONLY_NATIVE_FINALIZE" . "frame-only native GMTITLE 마무리 중 오류가 발생했습니다.")
        ("APPLIED_TITLE_TRANSFER" . "표제란 값 입력과 기존 잔여물 정리를 적용했습니다.")
        ("OK_NATIVE_AUTOSELECT_BATCH_COMPLETE" . "남은 표제란 시트를 실제 native GMTITLE로 연속 변환했습니다.")
        ("OK_TITLE_MISSING_OUTLINE_BATCH_COMPLETE" . "원본 표제란 부재가 검증된 남은 시트의 도면틀을 모두 교체했습니다.")
        ("FINALIZED_CLONED_FRAME_ONLY_GMTITLE_TRANSFER" . "frame-only 시트를 복제 방식으로 변환했습니다. 필요하면 native 검증을 이어가세요.")
        ("FINISHED_MANUAL_NATIVE_GMTITLE_UPGRADE" . "수동으로 만든 native GMTITLE 교체를 마무리했습니다.")
        ("READY_MANUAL_NATIVE_GMTITLE_CREATE" . "수동 native GMTITLE 생성 준비가 끝났습니다. 안내된 용지/제목블록으로 GMTITLE을 만드세요.")
        ("ABORT_GMTITLE_ALIGN_FAILED" . "새 GMTITLE을 원본 도면틀 위치에 맞추지 못해 중단했습니다.")
        ("ABORT_GMTITLE_NATIVE_PLACEMENT_REQUIRED" . "GMTITLE 배치 기준이 맞지 않습니다. Frame positioning ON, Object move OFF 상태가 필요합니다.")
        ("ABORT_FRAME_ONLY_ALIGN_FAILED" . "frame-only GMTITLE을 원본 도면틀 위치에 맞추지 못해 중단했습니다.")
        ("ABORT_FRAME_ONLY_NATIVE_PLACEMENT_REQUIRED" . "frame-only GMTITLE 배치 기준이 맞지 않습니다. Frame positioning ON, Object move OFF 상태가 필요합니다.")
        ("ABORT_NATIVE_GMTITLE_INVALID_FRAME_GEOMETRY" . "새 native GMTITLE 도면틀 크기/범위가 원본과 맞지 않아 중단했습니다.")
        ("ABORT_EXISTING_GMTITLE_INVALID_FRAME_GEOMETRY" . "기존 GMTITLE 도면틀 크기/범위가 원본과 맞지 않아 중단했습니다.")
        ("ABORT_EXISTING_FRAME_ONLY_GMTITLE_INVALID_FRAME_GEOMETRY" . "기존 frame-only GMTITLE 도면틀 크기/범위가 원본과 맞지 않아 중단했습니다.")
        ("ABORT_EXISTING_FRAME_ONLY_GMTITLE_NOT_FOUND" . "사용할 기존 frame-only GMTITLE 쌍을 찾지 못했습니다.")
        ("ABORT_FRAME_ONLY_NATIVE_GMTITLE_NOT_CREATED" . "GMTITLE 실행 후 frame-only 대상 native 객체가 생성되지 않았습니다.")
        ("ABORT_FRAME_ONLY_TARGET_UNKNOWN" . "frame-only 시트의 대상 용지 크기를 판정하지 못했습니다.")
        ("ABORT_NATIVE_UPGRADE_USER" . "사용자가 A2/A3/A4 native 교체를 열기 전에 중단했습니다.")
        ("ABORT_NATIVE_UPGRADE_ALIGN_FAILED" . "A2/A3/A4 native 교체 결과를 기존 위치에 맞추지 못해 중단했습니다.")
        ("ABORT_NATIVE_UPGRADE_REQUIRES_NATIVE_PLACEMENT" . "A2/A3/A4 native 교체 배치 기준이 맞지 않습니다. GMTITLE 옵션을 다시 확인하세요.")
        ("ABORT_NATIVE_UPGRADE_INVALID_FRAME_GEOMETRY" . "교체된 A2/A3/A4 native 도면틀 크기/범위가 예상과 맞지 않습니다.")
        ("ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS" . "GMTITLE 창을 취소했거나 새 GMTITLE 객체가 생성되지 않았습니다. 기존 쌍은 보존됩니다.")
        ("ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE" . "SCRIPT/자동화 실행 중에는 대화식 GMTITLE 생성/교체를 안전하게 진행할 수 없어 중단했습니다.")
        ("ABORT_PREPARE_SCRIPT_ACTIVE" . "SCRIPT/자동화 실행 중에는 YES 확인이 필요한 SWTITLEPREPARE 정리를 안전하게 진행할 수 없어 중단했습니다.")
        ("ABORT_NO_TARGET_FRAME_PLACEMENT_POINT" . "대상 도면틀의 왼쪽 아래 배치 기준점을 계산하지 못했습니다.")
        ("ABORT_NO_MANUAL_NATIVE_GMTITLE_PENDING" . "마무리할 수동 native GMTITLE 작업이 대기 중이 아닙니다.")
        ("ABORT_PENDING_TARGET_PAIR_MISSING" . "대기 중인 대상 도면틀/제목블록 쌍을 찾지 못했습니다.")
        ("ABORT_MANUAL_NATIVE_GMTITLE_WRONG_LOCATION" . "수동으로 만든 GMTITLE 위치가 대상 도면틀과 맞지 않습니다.")
        ("ABORT_MANUAL_NATIVE_GMTITLE_INVALID_FRAME_GEOMETRY" . "수동으로 만든 GMTITLE 도면틀 크기/범위가 예상과 맞지 않습니다.")
        ("ABORT_MANUAL_NATIVE_GMTITLE_NOT_CREATED" . "수동 GMTITLE 생성 후 새 대상 객체를 찾지 못했습니다.")
        ("ABORT_MANUAL_NATIVE_GMTITLE_WRONG_SELECTION" . "수동 GMTITLE의 용지/제목블록 선택이 예상과 다릅니다.")
        ("ABORT_SELECTED_ENTITY_IS_NOT_TARGET_GMTITLE_PAIR" . "선택한 객체가 대상 GMTITLE 도면틀/제목블록 쌍이 아닙니다.")
        ("ABORT_WRONG_NATIVE_GMTITLE_SELECTION" . "native GMTITLE 용지/제목블록 선택이 예상과 다릅니다.")
        ("ABORT_NATIVE_GMTITLE_BATCH_SCRIPT_ACTIVE" . "SCRIPT 실행 중에는 A2/A3/A4 대화식 교체를 안전하게 진행할 수 없어 중단했습니다.")
        ("ABORT_NATIVE_GMTITLE_UPGRADE_BATCH_USER" . "사용자가 A2/A3/A4 native 일괄 교체를 취소했습니다.")
        ("ABORT_NATIVE_UPGRADE_BATCH_USER" . "사용자가 native 교체 일괄 작업을 취소했습니다.")
        ("ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST" . "A2/A3/A4 교체 전에 실수 명령어 텍스트 후보를 먼저 확인해야 합니다.")
        ("ABORT_FRAME_DEFINITION_NOT_NORMALIZED" . "도면틀 정의 안에 표제란 형상 또는 오염 의심 구조가 남아 있어 변환을 중단했습니다.")
        ("ERROR_NATIVE_UPGRADE" . "native 교체 중 오류가 발생했습니다.")
        ("ERROR_NATIVE_UPGRADE_BATCH" . "native 교체 일괄 작업 중 오류가 발생했습니다.")
        ("ERROR_NATIVE_GMTITLE_UPGRADE_BATCH" . "A2/A3/A4 native 교체 일괄 작업 중 오류가 발생했습니다.")
        ("NEEDS_NATIVE_GMTITLE_UPGRADE" . "A2/A3/A4 GMTITLE 중 native 더블클릭 동작이 아직 증명되지 않은 쌍이 남아 있습니다.")
        ("NEEDS_NATIVE_FRAME_UPGRADE" . "대상 도면틀/제목블록 쌍을 native GMTITLE로 교체하거나 재검증해야 합니다.")
        ("NEEDS_NATIVE_FRAME_REVIEW" . "native-like 여부가 애매한 GMTITLE 쌍을 검토해야 합니다.")
        ("NEEDS_GMTITLE_PAIR_REVIEW" . "선택한 위치의 GMTITLE 도면틀/제목블록 쌍을 검토해야 합니다.")
        ("REVIEW_ACCIDENTAL_COMMAND_TEXT_BEFORE_NATIVE_GMTITLE_UPGRADE" . "A2/A3/A4 native 교체 전에 실수 명령어 텍스트 후보를 확인하세요.")
        ("WAITING_FOR_TRANSFER_SOURCES_REMAIN" . "아직 변환할 원본 SolidWorks 시트가 남아 있습니다.")
        ("STOP_NO_NATIVE_UPGRADE_CANDIDATE" . "native 교체 후보가 없습니다.")
        ("STOP_NO_NATIVE_GMTITLE_UPGRADE_CANDIDATE" . "A2/A3/A4 native 교체 후보가 없습니다.")
        ("STOP_NO_CLONED_GMTITLE_PAIR" . "복제 GMTITLE 쌍이 남아 있지 않습니다.")
        ("OK_NATIVE_GMTITLE_UPGRADE_COMPLETE" . "A2/A3/A4 native 교체가 필요한 쌍이 없습니다.")
        ("OK_NO_NATIVE_GMTITLE_FIX_CANDIDATE" . "A2/A3/A4 복구 후보가 없습니다.")
        ("OK_NO_CLONED_GMTITLE_PAIR" . "복제 GMTITLE 쌍이 없습니다.")
        ("OK_NO_TARGET_GMTITLE_PAIR" . "검토할 대상 GMTITLE 쌍이 없습니다.")
        ("OK_NATIVE_UPGRADE_BATCH_COMPLETE" . "native 교체 일괄 작업이 완료됐습니다.")
        ("WARN_NATIVE_UPGRADE_BATCH_REMAINING_CLONES" . "native 교체 후에도 복제 GMTITLE 쌍이 일부 남아 있습니다.")
        ("WARN_PICK_TARGET_FRAME_GEOMETRY_INVALID" . "선택한 GMTITLE 도면틀의 크기/범위가 예상과 다릅니다.")
        ("OK_PICK_NATIVE_PAIR_BUT_FRAME_SELECTED" . "native GMTITLE 쌍은 찾았지만 도면틀을 선택했습니다. 표 편집 확인은 제목블록에서 하세요.")
        ("OK_PICK_NATIVE_TITLE_READY" . "선택한 제목블록은 native GMTITLE 표 편집 확인 대상입니다.")
        ("NO_TARGET_GMTITLE_PAIR_AT_PICK" . "선택 위치에서 대상 GMTITLE 쌍을 찾지 못했습니다.")
        ("OK_DOUBLE_CLICK_MANUAL_CHECK_READY" . "대표 제목블록 더블클릭 수동 확인을 진행할 준비가 됐습니다.")
        ("FAIL_MISSING_TARGET_GMTITLE_PAIRS" . "필요한 대상 GMTITLE 도면틀/제목블록 쌍이 누락됐습니다.")
        ("FAIL_ROLE_CLASSIFICATION" . "GMTITLE 도면틀/제목블록 역할 판정에 실패했습니다.")
        ("OK_ROLE_CLASSIFICATION" . "GMTITLE 도면틀/제목블록 역할 판정이 완료됐습니다.")
        ("OK_LINK_DETAIL_DUMPED" . "GMTITLE native link 상세 정보를 로그로 출력했습니다.")
        ("SWTITLEVERIFY_FINAL_OK" . "검증 기준을 통과했습니다. 대표 제목블록 더블클릭만 최종 확인하세요.")
        ("SWTITLEVERIFY_FINAL_WARN" . "남은 경고가 있습니다. 모양만 보고 완료하지 말고 SWTITLESTATUS의 다음 조치를 확인하세요.")
        ("SWTITLEVERIFY_FINAL_FAIL" . "누락 또는 구조 문제가 남아 있어 변환 완료로 볼 수 없습니다.")
      )
    )
  )
  (if pair (cdr pair) "")
)

(defun swcad-title-korean-line (text / result replacements pair desc)
  (setq result
    (cond
      ((= (type text) 'STR) text)
      ((not text) "")
      (T (vl-princ-to-string text))
    )
  )
  (if *swcad-title-korean-output*
    (progn
      (if (and (>= (strlen result) 8) (= (substr result 1 8) "Result: "))
        (progn
          (setq desc (swcad-title-result-description (substr result 9)))
          (setq result
            (strcat
              "결과: "
              (substr result 9)
              (if (> (strlen desc) 0) (strcat " - " desc) "")
            )
          )
        )
      )
      (setq replacements
        '(
          ("SWTITLE LSP version:" . "SWTITLE LSP 버전:")
          ("Expected current version for cleaned command surface:" . "정리된 명령어 구성의 예상 현재 버전:")
          ("If a different version is shown, APPLOAD this file again before trusting SWTITLE status results." . "다른 버전이 보이면 SWTITLE 상태 결과를 믿기 전에 이 파일을 APPLOAD로 다시 로드하세요.")
          ("Work-folder test copy: yes" . "승인된 작업본: 예")
          ("Work-folder test copy: no" . "승인된 작업본: 아니오")
          ("Work-copy authorization: legacy-work-folder" . "작업본 승인 방식: 저장소 진단 work 폴더")
          ("Work-copy authorization: user-selected-saveas-copy" . "작업본 승인 방식: 다른 이름으로 저장한 사용자 작업본")
          ("Work-copy authorization: not-selected" . "작업본 승인 방식: 아직 선택하지 않음")
          ("Read-only document: yes" . "읽기 전용 도면: 예")
          ("Read-only document: no" . "읽기 전용 도면: 아니오")
          ("DWG:" . "DWG 파일:")
          ("CTAB:" . "현재 탭:")
          ("No drawing data was changed by the status commands." . "상태 확인 명령은 도면 데이터를 변경하지 않았습니다.")
          ("No drawing data was changed." . "도면 데이터는 변경하지 않았습니다.")
          ("Updated logs:" . "갱신된 로그:")
          ("No old frame-only sheet content was removed." . "기존 frame-only 시트 내용은 삭제하지 않았습니다.")
          ("No old SOLIDWORKS title/frame content was removed." . "기존 SOLIDWORKS 표제란/도면틀 내용은 삭제하지 않았습니다.")
          ("Detected source summary:" . "감지된 원본 요약:")
          ("source title sheets:" . "원본 표제란 시트:")
          ("source sheet frames:" . "원본 도면틀:")
          ("source sheet:" . "원본 시트:")
          ("title sheets with frame:" . "도면틀이 있는 표제란 시트:")
          ("title sheets without frame:" . "도면틀 없는 표제란 시트:")
          ("frame-only sheets:" . "표제란 없는 도면틀 시트:")
          ("source sheet frame counts:" . "원본 도면틀 크기별 수:")
          ("title sheet counts:" . "표제란 시트 크기별 수:")
          ("Target frame inserts:" . "대상 도면틀 INSERT:")
          ("Target frame inserts total:" . "대상 도면틀 INSERT 합계:")
          ("Target title block:" . "대상 제목블록:")
          ("Target frame detail:" . "대상 도면틀 상세:")
          ("Target frame block definitions:" . "대상 도면틀 블록 정의:")
          ("Target frame block:" . "대상 도면틀 블록:")
          ("Target frames without containing title:" . "제목블록을 포함하지 않는 대상 도면틀:")
          ("Target GMTITLE title/frame pairs:" . "대상 GMTITLE 제목블록/도면틀 쌍:")
          ("Other non-target title-like inserts:" . "대상이 아닌 기타 title-like INSERT:")
          ("Other title-like inserts that are not the target GMTITLE block:" . "대상 GMTITLE 블록이 아닌 기타 title-like INSERT:")
          ("Title inserts:" . "제목블록 INSERT:")
          ("Title insert #" . "제목블록 INSERT #")
          ("Title attributes:" . "제목블록 속성:")
          ("Non-empty title attributes:" . "값이 있는 제목블록 속성:")
          ("Missing expected title tags:" . "누락된 예상 제목블록 태그:")
          ("Native GMTITLE GENIUS_GENOREF_13 handle links:" . "native GMTITLE GENIUS_GENOREF_13 핸들 링크:")
          ("Native GMTITLE link target kinds:" . "native GMTITLE 링크 대상 종류:")
          ("paper/frame:" . "용지/도면틀:")
          ("title block:" . "제목블록:")
          ("exists=no" . "존재=아니오")
          ("exists=yes" . "존재=예")
          ("children=" . "하위객체=")
          ("old-source-like=" . "기존원본유사=")
          ("bbox-warnings=" . "bbox경고=")
          ("status=OK" . "상태=OK")
          ("Remaining source title sheets:" . "남은 원본 표제란 시트:")
          ("Remaining source sheet frames:" . "남은 원본 도면틀:")
          ("Remaining frame-only sheets:" . "남은 frame-only 시트:")
          ("Remaining 원본 표제란 시트:" . "남은 원본 표제란 시트:")
          ("Remaining 원본 도면틀:" . "남은 원본 도면틀:")
          ("Remaining 표제란 없는 도면틀 시트:" . "남은 표제란 없는 도면틀 시트:")
          ("Remaining source title candidates:" . "남은 원본 표제란 후보:")
          ("Remaining source sheet frame candidates:" . "남은 원본 도면틀 후보:")
          ("Remaining source title sheets after fast batch:" . "빠른 일괄 변환 후 남은 원본 표제란 시트:")
          ("Remaining frame-only sheets after fast batch:" . "빠른 일괄 변환 후 남은 frame-only 시트:")
          ("A2/A3/A4 native upgrade candidates:" . "A2/A3/A4 native 교체 후보:")
          ("A3/A4 native upgrade candidates:" . "A2/A3/A4 native 교체 후보:")
          ("Possible accidental command text entities:" . "실수로 도면에 들어간 명령어 텍스트 후보:")
          ("Selection/geometry risk warnings:" . "선택/형상 위험 경고 수:")
          ("Target frame geometry warnings:" . "대상 도면틀 형상 경고 수:")
          ("Target frame overlap warnings:" . "대상 도면틀 겹침 경고 수:")
          ("Fast batch: processing title sheets, count=" . "빠른 일괄 변환: 표제란 시트 처리 수=")
          ("Fast batch: processing frame-only sheets, count=" . "빠른 일괄 변환: frame-only 시트 처리 수=")
          ("Fast batch title error:" . "빠른 일괄 변환 표제란 처리 오류:")
          ("Fast batch frame-only error:" . "빠른 일괄 변환 frame-only 처리 오류:")
          ("Fast batch skipped frame-only phase because title phase left " . "표제란 단계에 남은 시트가 있어 frame-only 단계를 건너뜀: ")
          (" source title sheet(s)." . "개 원본 표제란 시트")
          ("Fast batch paused so the next sheet size can be created once with real native GMTITLE." . "다음 용지 크기의 첫 실제 native GMTITLE을 먼저 만들어야 해서 빠른 일괄 변환을 멈췄습니다.")
          ("Frame-only clone batch paused:" . "frame-only 복제 일괄 변환 멈춤:")
          ("Clone batch paused:" . "복제 일괄 변환 멈춤:")
          (" needs one real native GMTITLE exemplar first." . " 크기의 실제 native GMTITLE 기준 객체가 먼저 필요합니다.")
          ("Clone batch apply error:" . "복제 일괄 변환 적용 오류:")
          ("internal fast title clone phase sheet" . "내부 빠른 표제란 복제 단계 시트")
          ("Next native GMTITLE bootstrap selection:" . "다음 첫 native GMTITLE 선택:")
          ("Title-missing/frame-only native template caution:" . "title-missing/frame-only native 템플릿 주의:")
          ("Title-missing/frame-only exception handling: GMTITLE was created at the default location and moved to the old source frame." . "title-missing/frame-only 예외 처리: GMTITLE이 기본 위치에 생성되어 기존 도면틀 위치로 이동했습니다.")
          ("Moved native placement accepted after geometry check." . "형상 검사를 통과해 이동 배치된 native GMTITLE을 허용했습니다.")
          ("This is allowed only for verified title-missing/frame-only sheets; run SWTITLEVERIFY after conversion." . "이 처리는 원본 표제란 부재가 검증된 title-missing/frame-only 시트에만 허용됩니다. 변환 후 SWTITLEVERIFY로 해당 DR 도면틀 수량/형상을 검증하세요.")
          ("Run final double-click verification after conversion." . "변환 후 최종 더블클릭 검증을 실행하세요.")
          ("Important: fast batch may create clone GMTITLE pairs. Clone pairs can look correct but still fail GMPOWEREDIT/double-click native behavior." . "중요: 빠른 일괄 변환은 clone GMTITLE 쌍을 만들 수 있습니다. 겉으로 맞아 보여도 GMPOWEREDIT/더블클릭 native 동작은 실패할 수 있습니다.")
          ("Final success requires no clone/native-upgrade warnings and manual double-click checks for title blocks that actually exist." . "최종 성공은 clone/native-upgrade 경고가 없고 실제 제목블록이 있는 대표 용지의 더블클릭 확인까지 통과해야 합니다.")
          ("Run SWTITLESTATUS, then SWTITLEVERIFY." . "SWTITLESTATUS 실행 후 SWTITLEVERIFY를 실행하세요.")
          ("Open a writable copy of the DWG before upgrading." . "교체 작업 전에 쓰기 가능한 DWG 복사본을 여세요.")
          ("Open a work-folder copy before running native upgrade commands." . "native 교체 명령을 실행하기 전에 work 폴더의 복사본을 여세요.")
          ("Open a writable work copy before applying changes." . "변경 적용 전에 쓰기 가능한 작업복사본을 여세요.")
          ("Open a writable copy under Documents/CAD tool/work before applying changes." . "변경 적용 전에 Documents/CAD tool/work 아래의 쓰기 가능한 복사본을 여세요.")
          ("Final manual check:" . "최종 수동 확인:")
          ("Manual check:" . "수동 확인:")
          ("Manual check rule: double-click the DR_titlea_3rd title block, not the DR_A*_Outline frame." . "수동 확인 규칙: DR_A*_Outline 도면틀이 아니라 DR_titlea_3rd 제목블록을 더블클릭하세요.")
          ("The frame may open GMPOWEREDIT/REFEDIT even when the paired title block is usable." . "짝 제목블록이 정상이어도 도면틀을 더블클릭하면 GMPOWEREDIT/REFEDIT가 열릴 수 있습니다.")
          ("Use the listed title double-click point as the visual target; the live cursor grip can still look centered in GstarCAD." . "목록에 표시된 제목블록 더블클릭 위치를 기준으로 보세요. GstarCAD 커서 그립은 여전히 중앙처럼 보일 수 있습니다.")
          ("Target GMTITLE title/frame pairs:" . "대상 GMTITLE 제목블록/도면틀 쌍:")
          ("Target GMTITLE frame/title pairs:" . "대상 GMTITLE 도면틀/제목블록 쌍:")
          ("Title double-click point:" . "제목블록 더블클릭 위치:")
          ("Paired frame:" . "짝 도면틀:")
          ("Native-like accepted GMTITLE titles:" . "native-like로 인정된 GMTITLE 제목블록:")
          ("Unaccepted GMTITLE titles:" . "아직 인정되지 않은 GMTITLE 제목블록:")
          ("Non-native-like GMTITLE pairs needing replacement/recheck:" . "교체/재확인이 필요한 non-native-like GMTITLE 쌍:")
          ("Native-like accepted frame counts:" . "native-like 인정 도면틀 수:")
          ("Target frame blocks without native-like accepted pair:" . "native-like 인정 쌍이 없는 대상 도면틀:")
          ("Titles whose native link points to a visible target frame:" . "native link가 보이는 대상 도면틀을 가리키는 제목블록:")
          ("Titles sharing the same native recognition handle:" . "같은 native 인식 handle을 공유하는 제목블록:")
          ("Titles without containing target frame:" . "포함 도면틀을 찾지 못한 제목블록:")
          ("Title/frame sheet mismatches:" . "제목블록/도면틀 용지 크기 불일치:")
          ("Target frames without containing title:" . "포함 제목블록을 찾지 못한 대상 도면틀:")
          ("Target frame bbox size warnings:" . "대상 도면틀 bbox 크기 경고:")
          ("Target frame raw selection bbox notes:" . "대상 도면틀 원시 선택 bbox 참고:")
          ("Target frame bbox overlap / selection risk:" . "대상 도면틀 bbox 겹침/선택 위험:")
          ("Native frame readiness by visible target frame:" . "보이는 대상 도면틀별 native 준비 상태:")
          ("Visible target frame counts by sheet:" . "용지별 보이는 대상 도면틀 수:")
          ("Native-like target frame counts by sheet:" . "용지별 native-like 대상 도면틀 수:")
          ("Clone target frame counts by sheet:" . "용지별 clone 대상 도면틀 수:")
          ("Missing required A2/A3/A4 target sheets:" . "현재 필요한 대상 용지 누락:")
          ("A2/A3/A4 native-like completion:" . "A2/A3/A4 native-like 완료:")
          ("A3/A4 native-like completion:" . "A2/A3/A4 native-like 완료:")
          ("A2/A3/A4 candidate detail:" . "A2/A3/A4 후보 상세:")
          ("A2/A3/A4 target pairs needing native replacement:" . "native 교체가 필요한 A2/A3/A4 대상 쌍:")
          ("Target frame selection risk warnings:" . "대상 도면틀 선택 위험 경고:")
          ("target frames:" . "대상 도면틀:")
          ("paired titles:" . "짝 제목블록:")
          ("native-like pairs:" . "native-like 쌍:")
          ("cloned pairs:" . "clone 쌍:")
          ("shared native-link pairs:" . "native-link 공유 쌍:")
          ("untrusted/non-marker pairs:" . "신뢰 불가/non-marker 쌍:")
          ("frames without title:" . "제목블록 없는 도면틀:")
          ("titles with missing tags:" . "누락 tag가 있는 제목블록:")
          ("titles with empty attributes:" . "빈 속성이 있는 제목블록:")
          ("target frame selection risk warnings:" . "대상 도면틀 선택 위험 경고:")
          ("Note: SWTITLE markers and copied xdata alone are not treated as native GMTITLE proof." . "참고: SWTITLE marker와 복사된 xdata만으로는 native GMTITLE 증거로 인정하지 않습니다.")
          ("Note: native GMTITLE sheet frames remain DR_A*_Outline INSERT/block references; the GMTITLE table editor is checked on the title block." . "참고: native GMTITLE 도면틀도 DR_A*_Outline INSERT/block 참조로 남습니다. GMTITLE 표 편집창은 제목블록에서 확인합니다.")
          ("GMPOWEREDIT diagnosis: cloned GMTITLE pairs remain." . "GMPOWEREDIT 진단: clone GMTITLE 쌍이 남아 있습니다.")
          ("Clone means the visible frame/title and attributes were copied, but GstarCAD native editor recognition is not proven for that pair." . "복제 쌍은 보이는 도면틀/제목블록과 속성을 복사했다는 뜻이며, GstarCAD native 편집기 인식이 증명된 것은 아닙니다.")
          ("GMPOWEREDIT diagnosis: multiple GMTITLE titles share the same internal native recognition handle." . "GMPOWEREDIT 진단: 여러 GMTITLE 제목블록이 같은 내부 native 인식 handle을 공유합니다.")
          ("This is typical of preserve-copy/clone output: it can look correct, but double-click recognition can fall back to REFEDIT or block editing." . "preserve-copy/clone 결과에서 흔한 상태입니다. 겉으로 맞아 보여도 더블클릭 인식이 REFEDIT나 블록 편집으로 빠질 수 있습니다.")
          ("Missing-sheet diagnosis: old SOLIDWORKS frame-only sheets still remain." . "누락 용지 진단: 기존 SOLIDWORKS frame-only 시트가 아직 남아 있습니다.")
          ("Next after native clone review: run SWTITLECONVERT to handle remaining title-missing/frame-only exception sheets." . "native 복제 검토 뒤 다음 단계: 남은 title-missing/frame-only 예외 시트는 SWTITLECONVERTNEXT로 처리하세요.")
          ("Note: DR_A*_Outline sheet frames are still INSERT/block references; test the paired title block for the GMTITLE table editor." . "참고: DR_A*_Outline 도면틀은 여전히 INSERT/block 참조입니다. GMTITLE 표 편집창은 짝 제목블록에서 확인하세요.")
          ("참고: DR_A*_Outline sheet frames are still INSERT/block references; test the paired title block for the GMTITLE table editor." . "참고: DR_A*_Outline 도면틀은 여전히 INSERT/block 참조입니다. GMTITLE 표 편집창은 짝 제목블록에서 확인하세요.")
          ("These pairs can have correct attributes and SWTITLE markers but still open GMPOWEREDIT/REFEDIT instead of the GMTITLE table editor." . "이 쌍들은 속성과 SWTITLE marker가 맞아도 GMTITLE 표 편집창 대신 GMPOWEREDIT/REFEDIT가 열릴 수 있습니다.")
          ("Remaining source sheets are a separate follow-up after the listed clone/non-native pairs are reviewed." . "남은 원본 시트 처리는 표시된 clone/non-native 쌍을 검토한 뒤 별도로 이어집니다.")
          ("You can upgrade the listed native target pairs now even if title-missing/frame-only source sheets still remain." . "title-missing/frame-only 원본 시트가 남아 있어도 표시된 native 대상 쌍은 지금 교체할 수 있습니다.")
          ("After this command succeeds, rerun SWTITLESTATUS; repeat SWTITLECONVERT until A2/A3/A4 target pairs needing native replacement is 0." . "이 명령이 성공하면 SWTITLESTATUS를 다시 실행하세요. native 교체가 필요한 A2/A3/A4 대상 쌍이 0이 될 때까지 SWTITLECONVERTNEXT를 반복합니다.")
          ("No A2/A3/A4 target pairs need native replacement." . "native 교체가 필요한 A2/A3/A4 대상 쌍이 없습니다.")
          ("Next A3/A4 native upgrade candidate:" . "다음 A2/A3/A4 native 교체 후보:")
          ("This step upgrades only one sheet." . "이 단계는 한 번에 한 장만 교체합니다.")
          ("The GMTITLE dialog may still open with ordinary A3/A4 or ISO title defaults." . "GMTITLE 창이 DR이 아닌 일반 용지 또는 ISO 제목블록 기본값으로 열릴 수 있습니다.")
          ("Do not press OK unless the dialog shows the DR paper and DR_titlea_3rd." . "DR 용지와 DR_titlea_3rd가 보이지 않으면 OK를 누르지 마세요.")
          ("Dialog selection required:" . "GMTITLE 창에서 필요한 선택:")
          ("Prepared next target:" . "준비된 다음 대상:")
          ("User did not type OPEN, so GMTITLE was not opened." . "OPEN, MANUAL, BATCH를 입력하지 않아 GMTITLE 창을 열지 않았습니다.")
          ("Upgrade target:" . "교체 대상:")
          ("Existing GMTITLE title to replace:" . "교체할 기존 GMTITLE 제목블록:")
          ("Existing GMTITLE frame to replace:" . "교체할 기존 GMTITLE 도면틀:")
          ("Attributes to copy:" . "복사할 속성:")
          ("Trying command-line -GMTITLE with current GstarCAD defaults for" . "현재 GstarCAD 기본값으로 명령줄 -GMTITLE 시도:")
          ("Command-line insertion point:" . "명령줄 삽입점:")
          ("Command-line runner:" . "명령줄 실행 방식:")
          ("Command-line -GMTITLE new INSERT count:" . "명령줄 -GMTITLE 새 INSERT 수:")
          ("Command-line GMTITLE title insert:" . "명령줄 GMTITLE 제목블록:")
          ("Command-line GMTITLE frame insert:" . "명령줄 GMTITLE 도면틀:")
          ("Falling back to interactive GMTITLE dialog. Select the requested DR frame/title once." . "대화식 GMTITLE 창으로 전환합니다. 요청된 DR 도면틀/제목블록을 한 번만 선택하세요.")
          ("Starting native GMTITLE. In the GMTITLE dialog, choose" . "native GMTITLE 시작. GMTITLE 창에서 선택:")
          ("then place/confirm it." . "그 다음 배치/확인하세요.")
          ("Paper/format:" . "용지/형식:")
          ("Title block:" . "제목블록:")
          ("Keep ON:" . "켜둘 옵션:")
          ("Turn OFF:" . "꺼둘 옵션:")
          ("Frame positioning." . "Frame positioning.")
          ("Object move." . "Object move.")
          ("Lower-left placement point:" . "왼쪽 아래 배치점:")
          ("GstarCAD may still show the live cursor handle at the GMTITLE center; that is only a temporary preview handle." . "GstarCAD가 GMTITLE 중앙에 임시 커서 핸들을 보여줄 수 있지만, 이는 임시 미리보기 핸들입니다.")
          ("If GstarCAD asks for an insertion point, use the lower-left point above." . "GstarCAD가 삽입점을 묻는 경우 위의 왼쪽 아래 배치점을 사용하세요.")
          ("If GstarCAD asks for object/new location, cancel and turn OFF Object move; otherwise drawing contents can move." . "GstarCAD가 객체/새 위치를 묻는 경우 취소하고 Object move를 OFF로 바꾸세요. 그렇지 않으면 도면 내용이 이동할 수 있습니다.")
          ("FILEDIA and CMDDIA are not changed by this command." . "이 명령은 FILEDIA와 CMDDIA를 변경하지 않습니다.")
          ("Temporarily disabled object snap during GMTITLE placement; it will be restored afterward." . "GMTITLE 배치 중 객체 스냅을 임시로 껐으며, 이후 복원합니다.")
          ("Auto lower-left placement was not sent because no insertion-point prompt was detected. A native GMTITLE that must be moved afterward is not accepted for GMPOWEREDIT/double-click completion." . "삽입점 프롬프트가 감지되지 않아 왼쪽 아래 자동 배치점을 보내지 않았습니다. 나중에 이동해야 하는 native GMTITLE은 GMPOWEREDIT/더블클릭 완료로 인정하지 않습니다.")
          ("Removed wrong/new GMTITLE inserts:" . "잘못 생성된 새 GMTITLE INSERT 삭제 수:")
          ("The existing GMTITLE pair was kept." . "기존 GMTITLE 쌍은 보존했습니다.")
          ("Next: rerun the command and complete the GMTITLE dialog; canceling the dialog leaves the old pair unchanged." . "다음: 명령을 다시 실행해 GMTITLE 창을 올바르게 완료하세요. 창을 취소하면 기존 쌍은 그대로 남습니다.")
          ("다음: rerun the command and complete the GMTITLE dialog; canceling the dialog leaves the old pair unchanged." . "다음: 명령을 다시 실행해 GMTITLE 창을 올바르게 완료하세요. 창을 취소하면 기존 쌍은 그대로 남습니다.")
          ("Open a writable work copy before running the fast batch." . "빠른 일괄 변환 전에 쓰기 가능한 작업복사본을 여세요.")
          ("Fast batch is limited to Documents/CAD tool/work copies." . "빠른 일괄 변환은 Documents/CAD tool/work 안의 작업복사본에서만 실행됩니다.")
          ("Fast batch stopped because an existing target frame has invalid A-size geometry." . "기존 대상 도면틀의 A규격 형상이 맞지 않아 빠른 일괄 변환을 멈췄습니다.")
          ("Fast batch stopped because existing target frames overlap and may select the wrong GMTITLE object." . "기존 대상 도면틀끼리 겹쳐 잘못된 GMTITLE 객체를 선택할 위험이 있어 멈췄습니다.")
          ("Create/finalize one real native GMTITLE first, then run this command again." . "실제 native GMTITLE 1장을 먼저 만들고 finalize한 뒤 이 명령을 다시 실행하세요.")
          ("Cloned titles whose native link points to a visible frame are not accepted as exemplars." . "보이는 도면틀을 native link 대상으로 가진 clone 제목블록은 기준 객체로 인정하지 않습니다.")
          ("Create/finalize one real native GMTITLE for each missing sheet size first." . "없는 용지 크기마다 실제 native GMTITLE 1장을 먼저 만들고 finalize하세요.")
          ("Open a writable work copy before running the bootstrap fast transfer." . "bootstrap 빠른 변환 전에 쓰기 가능한 작업복사본을 여세요.")
          ("Bootstrap fast transfer is limited to Documents/CAD tool/work copies." . "bootstrap 빠른 변환은 Documents/CAD tool/work 안의 작업복사본에서만 실행됩니다.")
          ("Bootstrap fast transfer stopped because an existing target frame has invalid A-size geometry." . "기존 대상 도면틀의 A규격 형상이 맞지 않아 bootstrap 빠른 변환을 멈췄습니다.")
          ("Bootstrap fast transfer stopped because existing target frames overlap and may select the wrong GMTITLE object." . "기존 대상 도면틀끼리 겹쳐 잘못된 GMTITLE 객체를 선택할 위험이 있어 bootstrap 빠른 변환을 멈췄습니다.")
          ("A native GMTITLE exemplar exists, but one or more remaining sheet sizes still need their own first real GMTITLE." . "native GMTITLE 기준 객체는 있지만, 남은 용지 크기 중 일부는 자기 크기의 첫 실제 GMTITLE이 아직 필요합니다.")
          ("No title source remains to create the first native GMTITLE exemplar." . "첫 native GMTITLE 기준 객체를 만들 원본 표제란이 남아 있지 않습니다.")
          ("Bootstrap phase: native GMTITLE will open once for the first detected title sheet." . "bootstrap 단계: 처음 감지된 표제란 시트에 대해 native GMTITLE 창이 한 번 열립니다.")
          ("Manual first-native picker is currently required by GstarCAD." . "현재 GstarCAD에서는 첫 native GMTITLE 선택을 사람이 직접 해야 합니다.")
          ("In the GMTITLE dialog:" . "GMTITLE 창에서:")
          ("Choose the detected DR sheet shown above." . "위에 표시된 DR 용지를 선택하세요.")
          ("Choose DR_titlea_3rd." . "DR_titlea_3rd를 선택하세요.")
          ("Keep Frame positioning ON." . "Frame positioning은 ON으로 둡니다.")
          ("Turn OFF Object move." . "Object move는 OFF로 끕니다.")
          ("Confirm/place it once; the LISP aligns it and then checks whether same-size native exemplars are ready." . "한 번 확인/배치하면 LISP가 정렬한 뒤 같은 크기 native 기준 객체 준비 여부를 확인합니다.")
          ("Bootstrap phase complete. Fast batch paused because another sheet size needs its own real GMTITLE exemplar." . "bootstrap 단계 완료. 다른 용지 크기의 실제 GMTITLE 기준 객체가 필요해서 빠른 일괄 변환을 멈췄습니다.")
          ("Bootstrap phase complete. Starting fast remaining-sheet batch." . "bootstrap 단계 완료. 남은 시트 빠른 일괄 변환을 시작합니다.")
          ("Remaining A3/A4 native upgrade candidates:" . "남은 A2/A3/A4 native 교체 후보:")
          ("Remaining candidates after the stopped sheet:" . "중단된 시트 이후 남은 후보:")
          ("Native GMTITLE exemplars by sheet frame:" . "도면틀 크기별 native GMTITLE 기준 객체:")
          ("Exact-size native GMTITLE exemplars needed by remaining source title sheets:" . "남은 원본 표제란 시트에 필요한 동일 크기 native GMTITLE:")
          ("Missing exact-size native exemplar(s):" . "없는 동일 크기 native 기준 객체:")
          ("Create the first sheet of each missing size with native GMTITLE once, then rerun the fast clone batch." . "없는 용지 크기마다 실제 native GMTITLE 1장을 먼저 만들고 빠른 복제 일괄 변환을 다시 실행하세요.")
          ("Next exact-size native GMTITLE action(s):" . "다음 동일 크기 native GMTITLE 작업:")
          ("Next fast-batch target frame:" . "다음 빠른 일괄 변환 대상 도면틀:")
          ("exact-size native exemplar=" . "동일 크기 native 기준 객체=")
          ("Contaminated target frame definitions:" . "오염된 대상 도면틀 정의:")
          ("native GMTITLE 제목블록 존재: no" . "native GMTITLE 제목블록 존재: 아니오")
          ("native GMTITLE 제목블록 존재: yes" . "native GMTITLE 제목블록 존재: 예")
          ("존재: no" . "존재: 아니오")
          ("존재: yes" . "존재: 예")
          ("DR_A1_Outline: no" . "DR_A1_Outline: 없음")
          ("DR_A2_Outline: no" . "DR_A2_Outline: 없음")
          ("DR_A3_Outline: no" . "DR_A3_Outline: 없음")
          ("DR_A4_Outline: no" . "DR_A4_Outline: 없음")
          ("DR_A1_Outline: yes" . "DR_A1_Outline: 있음")
          ("DR_A2_Outline: yes" . "DR_A2_Outline: 있음")
          ("DR_A3_Outline: yes" . "DR_A3_Outline: 있음")
          ("DR_A4_Outline: yes" . "DR_A4_Outline: 있음")
          ("Contaminated target frame definitions after fast batch:" . "빠른 일괄 변환 후 오염된 대상 도면틀 정의:")
          ("Any native GMTITLE title:" . "native GMTITLE 제목블록 존재:")
          ("Expected native GMTITLE frame block:" . "예상 native GMTITLE 도면틀 블록:")
          ("Expected native GMTITLE title block:" . "예상 native GMTITLE 제목블록:")
          ("Expected existing GMTITLE frame block:" . "예상 기존 GMTITLE 도면틀 블록:")
          ("Expected existing GMTITLE title block:" . "예상 기존 GMTITLE 제목블록:")
          ("Expected frame block:" . "예상 도면틀 블록:")
          ("Expected title block:" . "예상 제목블록:")
          ("Actual title block:" . "실제 제목블록:")
          ("Actual frame block:" . "실제 도면틀 블록:")
          ("Native-like pair:" . "native-like 쌍:")
          ("Reason/status detail:" . "이유/상태 상세:")
          ("Frame geometry warning:" . "도면틀 형상 경고:")
          ("Source title insert:" . "원본 표제란 INSERT:")
          ("Source frame insert:" . "원본 도면틀 INSERT:")
          ("Existing GMTITLE title insert:" . "기존 GMTITLE 제목블록 INSERT:")
          ("Existing GMTITLE frame insert:" . "기존 GMTITLE 도면틀 INSERT:")
          ("Existing/default GMTITLE title insert:" . "기존/기본 GMTITLE 제목블록 INSERT:")
          ("Existing/default GMTITLE frame insert:" . "기존/기본 GMTITLE 도면틀 INSERT:")
          ("Values to apply:" . "적용할 값:")
          ("Frame-only values to apply:" . "frame-only 시트에 적용할 값:")
          ("Attributes set:" . "속성 입력 수:")
          ("Attributes copied:" . "복사한 속성 수:")
          ("GMTITLE marker set:" . "GMTITLE 마커 설정:")
          ("Native upgrade marker set:" . "native 교체 마커 설정:")
          ("Possible accidental command text entities:" . "실수 명령어 텍스트 후보:")
          ("Native GMTITLE abort reason:" . "native GMTITLE 중단 이유:")
          ("Removed wrong/new GMTITLE inserts:" . "잘못 생성된 새 GMTITLE INSERT 삭제:")
          ("Remaining A3/A4 native upgrade candidates after batch:" . "일괄 처리 뒤 남은 A2/A3/A4 native 교체 후보:")
          ("Old loose title texts deleted:" . "삭제한 기존 표제란 일반 텍스트:")
          ("Old block-internal title texts handled by deleting source insert:" . "원본 INSERT 삭제로 처리한 블록 내부 표제란 텍스트:")
          ("Old loose title graphics deleted:" . "삭제한 기존 표제란 일반 그래픽:")
          ("Old title insert deleted: yes" . "기존 표제란 INSERT 삭제: 예")
          ("Old title insert deleted: no" . "기존 표제란 INSERT 삭제: 아니오")
          ("Old frame insert deleted: yes" . "기존 도면틀 INSERT 삭제: 예")
          ("Old frame insert deleted: no" . "기존 도면틀 INSERT 삭제: 아니오")
          ("Old cloned title deleted: yes" . "기존 clone 제목블록 삭제: 예")
          ("Old cloned frame deleted: yes" . "기존 clone 도면틀 삭제: 예")
          ("Old cloned/untrusted title deleted: yes" . "기존 clone/신뢰 불가 제목블록 삭제: 예")
          ("Old cloned/untrusted frame deleted: yes" . "기존 clone/신뢰 불가 도면틀 삭제: 예")
          ("Old loose frame graphics deleted:" . "삭제한 기존 도면틀 일반 그래픽:")
          ("Old SOLIDWORKS sheet residue deleted:" . "삭제한 기존 SOLIDWORKS 시트 잔여물:")
          ("Old loose title graphics queued for cleanup:" . "삭제 예정 기존 표제란 일반 그래픽:")
          ("Old loose frame graphics queued for cleanup:" . "삭제 예정 기존 도면틀 일반 그래픽:")
          ("Old SOLIDWORKS sheet residue queued for cleanup:" . "삭제 예정 기존 SOLIDWORKS 시트 잔여물:")
          ("Old SOLIDWORKS sheet residue cleanup candidates:" . "기존 SOLIDWORKS 시트 잔여물 삭제 후보:")
          ("sheet residue cleanup candidates:" . "시트 잔여물 삭제 후보:")
          ("Unmapped source texts to delete with old title text:" . "기존 표제란과 함께 삭제할 미매핑 원본 텍스트:")
          ("Duplicate source texts not mapped:" . "중복되어 매핑하지 않은 원본 텍스트:")
          ("Unmapped source title texts:" . "매핑하지 못한 원본 표제란 텍스트:")
          ("Duplicate source title texts:" . "중복되어 제외한 원본 표제란 텍스트:")
          ("Source frame-only insert:" . "원본 frame-only 도면틀 INSERT:")
          ("No old frame-only sheet content was removed." . "기존 frame-only 시트 내용은 삭제하지 않았습니다.")
          ("Cloned GMTITLE was finalized; native upgrade is still required for double-click behavior." . "복제 GMTITLE 마무리는 완료됐지만, 더블클릭 동작을 위해 native 교체가 아직 필요합니다.")
          ("Cloned GMTITLE was finalized for frame-only source; native upgrade is still required for double-click behavior." . "frame-only 원본의 복제 GMTITLE 마무리는 완료됐지만, 더블클릭 동작을 위해 native 교체가 아직 필요합니다.")
          ("Existing/default native GMTITLE was used for frame-only source." . "frame-only 원본에는 기존/기본 native GMTITLE을 사용했습니다.")
          ("WARNING: frame-only GMTITLE was moved by LISP after creation because native placement was not captured." . "경고: native 배치점을 잡지 못해 생성 후 LISP가 frame-only GMTITLE을 이동했습니다.")
          ("The created GMTITLE frame bbox will be checked before any old title-missing/frame-only content is removed." . "기존 title-missing/frame-only 내용을 지우기 전에 새 GMTITLE 도면틀 범위를 먼저 검사합니다.")
          ("Create one native GMTITLE with the detected DR sheet and verify its bbox first; if the sheet keeps failing, inspect the GMTITLE sheet selection/format definition." . "감지된 DR 용지로 native GMTITLE 1장을 만들고 범위를 먼저 확인하세요. 같은 용지가 계속 실패하면 GMTITLE 용지 선택/형식 정의를 점검하세요.")
          ("Native GMTITLE will open once for this frame-only sheet." . "이 frame-only 시트에 대해 native GMTITLE 창이 한 번 열립니다.")
          ("Do not force a clone for this sheet size until a real matching DR_A*_Outline exemplar passes the bbox check." . "실제 같은 크기 DR_A*_Outline 기준 객체가 bbox 검사를 통과하기 전에는 이 용지 크기에 clone을 강제로 적용하지 마세요.")
          ("Frame-only clone error:" . "frame-only clone 오류:")
          ("Clone error:" . "clone 오류:")
          ("verified native GMTITLE exemplar or target frame could not be created." . "검증된 native GMTITLE 기준 객체 또는 대상 도면틀을 만들 수 없습니다.")
          ("verified GMTITLE exemplar or target frame could not be created." . "검증된 GMTITLE 기준 객체 또는 대상 도면틀을 만들 수 없습니다.")
          ("Deleted accidental command text entities:" . "실수로 들어간 명령어 텍스트 삭제:")
          ("Do not run apply/upgrade commands until those are confirmed or cleaned in a work copy." . "작업복사본에서 해당 후보를 확인하거나 정리하기 전에는 적용/교체 명령을 실행하지 마세요.")
          ("Reason: command text may have been inserted into the drawing while CAD was in a text/input state." . "이유: CAD가 문자/입력 상태일 때 명령어가 도면 텍스트로 들어갔을 가능성이 있습니다.")
          ("WARNING: command text may have been inserted into the drawing while CAD was in a text/input state." . "경고: CAD가 문자/입력 상태일 때 명령어가 도면 텍스트로 들어갔을 가능성이 있습니다.")
          ("Reason: the current GstarCAD GMTITLE dialog opens with ISO defaults, so batch automation cannot safely choose the required DR frame/title." . "이유: 현재 GstarCAD GMTITLE 창이 ISO 기본값으로 열리므로, 일괄 자동화가 필요한 DR 도면틀/제목블록을 안전하게 고를 수 없습니다.")
          ("Do not accept ISO defaults. Cancel and rerun if the dialog still shows ISO paper/title." . "ISO 기본값을 그대로 승인하지 마세요. 창에 ISO 용지/제목블록이 보이면 취소하고 다시 실행하세요.")
          ("Next: rerun and choose the printed DR_A*_Outline paper plus DR_titlea_3rd; do not accept ISO defaults." . "다음: 다시 실행해서 출력된 DR_A*_Outline 용지와 DR_titlea_3rd를 선택하세요. ISO 기본값은 승인하지 마세요.")
          ("Fast batch not started because bootstrap phase ended with status:" . "bootstrap 단계가 다음 상태로 끝나 빠른 일괄 변환을 시작하지 않았습니다:")
          (": run SWTITLECONVERT to create/finalize one real title sheet for this size, then rerun SWTITLESTATUS." . ": 이 크기의 실제 표제란 시트 1장을 생성/마무리하려면 SWTITLECONVERTNEXT를 실행한 뒤 SWTITLESTATUS를 다시 실행하세요.")
          (": run SWTITLECONVERT to create/finalize one real frame-only sheet for this size, then rerun SWTITLESTATUS." . ": 이 크기의 실제 frame-only 시트 1장을 생성/마무리하려면 SWTITLECONVERTNEXT를 실행한 뒤 SWTITLESTATUS를 다시 실행하세요.")
          ("Do not continue with clone/fast batch for this sheet size until the created matching DR_A*_Outline frame passes the bbox check." . "생성된 같은 크기 DR_A*_Outline 도면틀이 bbox 검사를 통과하기 전에는 이 용지 크기의 clone/빠른 일괄 변환을 계속하지 마세요.")
          ("If SWTITLECONVERT aborts with invalid frame geometry, inspect the GMTITLE DR paper selection or repair/check the frame definition before retrying." . "SWTITLECONVERTNEXT/SWTITLECONVERT가 도면틀 형상 오류로 중단되면 다시 시도하기 전에 GMTITLE DR 용지 선택값을 확인하거나 도면틀 정의를 복구/점검하세요.")
          ("It will process " . "내부 처리 예정: ")
          (" currently listed A2/A3/A4 native replacement candidate(s) internally." . "개의 현재 A2/A3/A4 native 교체 후보")
          ("Important: native-finalize and native-frame-only must be legacy-uncertain=yes." . "중요: native-finalize와 native-frame-only는 legacy-uncertain=yes로 분류되어야 합니다.")
          ("No A3/A4 target pair is currently queued for native replacement." . "현재 native 교체 대기 중인 A2/A3/A4 대상 쌍이 없습니다.")
          ("Cloned GMTITLE pairs needing native frame upgrade:" . "native 도면틀 교체가 필요한 복제 GMTITLE 쌍:")
          ("Reason: possible command text exists in the drawing while A2/A3/A4 native replacement candidates are present." . "이유: A2/A3/A4 native 교체 후보가 있는 상태에서 도면 안에 명령어 텍스트 후보가 있습니다.")
          ("Reason: some A3/A4 GMTITLE pairs are still not trusted as fresh native GMTITLE pairs." . "이유: 일부 A2/A3/A4 GMTITLE 쌍이 아직 fresh native GMTITLE 쌍으로 신뢰되지 않습니다.")
          ("Cause: clone, preserve-copy, native-finalize, and native-frame-only results can be visually correct, but GstarCAD's native double-click recognition is not guaranteed for every sheet." . "원인: clone, preserve-copy, native-finalize, native-frame-only 결과는 화면상 맞아 보여도 모든 시트에서 GstarCAD native 더블클릭 인식이 보장되지는 않습니다.")
          ("This command does not create missing title-missing/frame-only target sheets; it only repairs native recognition of target pairs already created." . "이 단계는 누락된 title-missing/frame-only 대상 시트를 새로 만들지 않고, 이미 만들어진 대상 쌍의 native 인식만 복구합니다.")
          ("This fixes native double-click behavior for already-created A3/A4 GMTITLE target pairs." . "이미 만들어진 A2/A3/A4 GMTITLE 대상 쌍의 native 더블클릭 동작을 복구하는 단계입니다.")
          ("This experiment is limited to Documents/CAD tool/work copies." . "이 실험은 Documents/CAD tool/work 안의 복사본에서만 실행할 수 있습니다.")
          ("Next safest path: run SWTITLECONVERT; it will enter the native replacement phase." . "다음 안전한 경로: SWTITLECONVERTNEXT를 실행하면 native 교체 단계로 들어갑니다.")
          ("SWTITLECONVERT processes the next candidate from " . "SWTITLECONVERTNEXT는 현재 후보 ")
          (" currently listed A2/A3/A4 candidate(s) through its native replacement phase." . "개 중 다음 1개를 native 교체 단계로 처리합니다.")
          ("Then rerun SWTITLESTATUS to check whether the pair was loaded from stale LSP logic." . "그 뒤 SWTITLESTATUS를 다시 실행해서 오래된 LSP 로직으로 로드된 쌍인지 확인하세요.")
          ("If they are accidental command leftovers in a work copy, clean them first, then rerun SWTITLESTATUS." . "작업복사본 안의 실수 명령어 잔여물이 맞다면 먼저 정리한 뒤 SWTITLESTATUS를 다시 실행하세요.")
          ("SWTITLECONVERT will process the next one of " . "SWTITLECONVERTNEXT는 현재 ")
          (" currently listed candidate(s), then return to status verification." . "개 후보 중 다음 1개를 처리한 뒤 상태 검증으로 돌아갑니다.")
          ("After the native GMTITLE is visibly created, continue with SWTITLECONVERT for the guided finish/retry flow." . "native GMTITLE이 화면에 생성된 것이 보이면, 안내된 마무리/재시도 흐름을 위해 SWTITLECONVERTNEXT를 계속 실행하세요.")
          ("Tip: use SWTITLECONVERT from the four-command workflow; it sends the lower-left point automatically after the GMTITLE dialog." . "팁: 4단계 흐름의 SWTITLECONVERTNEXT를 사용하세요. GMTITLE 창 이후 왼쪽 아래 점을 자동으로 보냅니다.")
          ("Run the status SCRIPT first, then type SWTITLECONVERT manually in the CAD command line." . "먼저 상태 SCRIPT를 실행한 뒤 CAD 명령줄에 SWTITLECONVERTNEXT를 직접 입력하세요.")
          ("Handle those after this native-recognition upgrade with SWTITLECONVERT." . "이 native 인식 교체가 끝난 뒤 해당 항목은 SWTITLECONVERTNEXT로 처리하세요.")
          ("For normal use, keep using SWTITLECONVERT; one-sheet recovery commands are diagnostic only." . "일반 사용에서는 계속 SWTITLECONVERTNEXT를 사용하세요. 한 장 복구용 명령은 진단용입니다.")
          ("No A2/A3/A4 native-recheck or cloned GMTITLE pair was found." . "native 재확인 또는 복제 GMTITLE 상태의 A2/A3/A4 쌍을 찾지 못했습니다.")
          ("No A3/A4 native-recheck or cloned GMTITLE pair was found." . "native 재확인 또는 복제 GMTITLE 상태의 A2/A3/A4 쌍을 찾지 못했습니다.")
          ("Reason: old SOLIDWORKS source title/frame candidates still remain." . "이유: 기존 SOLIDWORKS 원본 표제란/도면틀 후보가 아직 남아 있습니다.")
          ("Reason: at least one required A2/A3/A4 target GMTITLE frame is still missing." . "이유: 현재 원본/대상 기준으로 필요한 GMTITLE 도면틀이 아직 없습니다.")
          ("Reason: no converted A3/A4 GMTITLE target pair exists yet; source sheets still remain." . "이유: 변환된 A2/A3/A4 GMTITLE 대상 쌍이 아직 없고 원본 시트가 남아 있습니다.")
          ("Reason: each candidate may need the interactive GMTITLE dialog, and SCRIPT mode suppresses that fallback." . "이유: 각 후보는 대화식 GMTITLE 창이 필요할 수 있는데 SCRIPT 모드에서는 그 fallback이 막힙니다.")
          ("Manual native replacement is limited to Documents/CAD tool/work copies." . "수동 native 교체는 Documents/CAD tool/work 아래 작업복사본에서만 가능합니다.")
          ("Manual native finish is limited to Documents/CAD tool/work copies." . "수동 native 마무리는 Documents/CAD tool/work 아래 작업복사본에서만 가능합니다.")
          ("No A3/A4 target pair currently needs native replacement." . "현재 native 교체가 필요한 A2/A3/A4 대상 쌍이 없습니다.")
          ("This pair is not trusted for GMPOWEREDIT/double-click behavior until recreated with native placement." . "이 쌍은 native 배치로 다시 만들기 전까지 GMPOWEREDIT/더블클릭 동작을 신뢰할 수 없습니다.")
          ("Existing native GMTITLE was used." . "기존 native GMTITLE을 사용했습니다.")
          ("For the GMTITLE table editor, test the paired DR_titlea_3rd title insert listed above." . "GMTITLE 표 편집창 확인은 위에 표시된 짝 DR_titlea_3rd 제목블록 INSERT에서 테스트하세요.")
          ("Do not run the A2/A3/A4 native replacement phase from a SCRIPT file." . "A2/A3/A4 native 교체 단계는 SCRIPT 파일에서 실행하지 마세요.")
          ("No A3/A4 pairs were changed." . "변경된 A2/A3/A4 쌍이 없습니다.")
          ("A2/A3/A4 native replacement candidates currently listed:" . "현재 표시된 A2/A3/A4 native 교체 후보:")
          (" frame-only source sheet(s) still remain; this batch will not create them." . "개의 frame-only 원본 시트가 아직 남아 있습니다. 이 일괄 단계에서는 새로 만들지 않습니다.")
          ("This A2/A3/A4 native replacement phase is run from SWTITLECONVERT." . "이 A2/A3/A4 native 교체 단계는 SWTITLECONVERTNEXT/SWTITLECONVERT 내부에서 실행됩니다.")
          ("SWTITLECONVERT A2/A3/A4 native replacement error:" . "SWTITLECONVERT A2/A3/A4 native 교체 오류:")
          ("After this command succeeds, rerun SWTITLESTATUS; repeat SWTITLECONVERT until A2/A3/A4 target pairs needing native replacement is 0." . "이 단계가 성공하면 SWTITLESTATUS를 다시 실행하세요. native 교체가 필요한 A2/A3/A4 대상 쌍이 0이 될 때까지 SWTITLECONVERTNEXT를 반복합니다.")
          ("No A2/A3/A4 target pairs need native replacement." . "native 교체가 필요한 A2/A3/A4 대상 쌍이 없습니다.")
          ("Detected sheet size:" . "감지된 용지 크기:")
          ("title-text=" . "표제란 텍스트=")
          ("frame-bbox=" . "도면틀 범위=")
          ("block-name=" . "블록명=")
          ("selected=" . "선택=")
          ("frame cleanup bbox=" . "도면틀 정리 범위=")
          ("handle=" . "핸들=")
          ("region=" . "영역=")
          ("type=" . "유형=")
          ("layer=" . "레이어=")
          ("block=" . "블록=")
          ("bbox=" . "범위=")
          ("bottom-left logo" . "왼쪽 아래 모서리 잔여물")
          ("upper sheet-format residue" . "상단 시트 형식 잔여물")
          ("upper-right residual block" . "오른쪽 위 잔여 블록")
          ("Each remaining candidate may open the native GMTITLE dialog." . "남은 각 후보에서 native GMTITLE 창이 열릴 수 있습니다.")
          ("For each dialog, choose the printed DR paper and DR_titlea_3rd, with Frame positioning ON and Object move OFF." . "각 창에서 표시된 DR 용지와 DR_titlea_3rd를 선택하고, Frame positioning은 ON, Object move는 OFF로 두세요.")
          ("For the GMTITLE dialog: choose the printed DR_A*_Outline paper and DR_titlea_3rd." . "GMTITLE 창에서는 표시된 DR_A*_Outline 용지와 DR_titlea_3rd를 선택하세요.")
          ("Required dialog state: Frame positioning=ON, Object move=OFF." . "필수 창 상태: Frame positioning=ON, Object move=OFF.")
          ("Fix: replace each listed A3/A4 pair with one fresh native GMTITLE dialog result; the command copies values and deletes the old untrusted pair." . "해결: 목록의 각 A2/A3/A4 쌍을 새 native GMTITLE 창 결과로 교체합니다. 명령이 값을 복사하고 신뢰할 수 없는 기존 쌍을 삭제합니다.")
          ("For every GMTITLE dialog: choose the printed DR_A*_Outline paper, choose DR_titlea_3rd, keep Frame positioning ON, turn Object move OFF, then OK." . "모든 GMTITLE 창에서 표시된 DR_A*_Outline 용지와 DR_titlea_3rd를 고르고, Frame positioning은 ON, Object move는 OFF로 둔 뒤 OK를 누르세요.")
          ("Next: create/finalize the missing sheet size before final double-click checks." . "다음: 최종 더블클릭 확인 전에 누락된 용지 크기를 생성/마무리하세요.")
          ("Note: remaining untrusted/non-marker pairs are outside the A2/A3/A4 upgrade queue, usually the pre-existing A2 baseline." . "참고: 남은 신뢰 불가/non-marker 쌍은 현재 A2/A3/A4 교체 후보 규칙 밖의 legacy 기준 객체일 수 있습니다.")
          ("Next: rerun the command and let GMTITLE accept the lower-left placement point, with Object move OFF." . "다음: 명령을 다시 실행하고 Object move를 OFF로 둔 상태에서 GMTITLE이 왼쪽 아래 배치점을 받도록 하세요.")
          ("Next: rerun with Frame positioning ON and Object move OFF, then let GMTITLE accept the lower-left placement point." . "다음: Frame positioning을 ON, Object move를 OFF로 둔 상태에서 명령을 다시 실행하고, GMTITLE이 왼쪽 아래 배치점을 받도록 하세요.")
          ("Next: recreate this sheet with the expected DR paper size before retrying the A3/A4 native upgrade." . "다음: A2/A3/A4 native 교체를 다시 시도하기 전에 이 시트를 예상 DR 용지 크기로 다시 만드세요.")
          ("Next: open a writable copy under Documents/CAD tool/work before applying changes." . "다음: 변경을 적용하기 전에 Documents/CAD tool/work 아래의 쓰기 가능한 복사본을 여세요.")
          ("Next: follow the detailed log named by the status above." . "다음: 위 상태에서 표시한 상세 로그를 확인하세요.")
          ("GMTITLE options: Frame positioning ON, Object move OFF." . "GMTITLE 옵션: Frame positioning ON, Object move OFF.")
          ("WARNING: current DWG is outside the work test folder." . "경고: 현재 DWG가 work 테스트 폴더 밖에 있습니다.")
          ("No SOLIDWORKS title/frame content will be removed unless you explicitly confirm this non-work file." . "work 폴더 밖 파일은 사용자가 명시적으로 확인하기 전까지 SOLIDWORKS 표제란/도면틀 내용을 삭제하지 않습니다.")
          ("Note: if GMPOWEREDIT shows Next/Accept or REFEDIT, the cursor may be hitting an oversized or overlapping frame/block bbox instead of the intended GMTITLE title table." . "참고: GMPOWEREDIT에서 Next/Accept 또는 REFEDIT가 보이면, 커서가 의도한 GMTITLE 제목블록 표가 아니라 너무 크거나 겹친 도면틀/블록 범위를 잡은 것일 수 있습니다.")
          ("Open or create a copy under Documents/CAD tool/work before applying." . "적용하기 전에 Documents/CAD tool/work 아래 복사본을 열거나 만드세요.")
          ("Open or create a copy under Documents/CAD tool/work before repairing." . "복구하기 전에 Documents/CAD tool/work 아래 복사본을 열거나 만드세요.")
          ("Open or create a copy under Documents/CAD tool/work before cleaning." . "정리하기 전에 Documents/CAD tool/work 아래 복사본을 열거나 만드세요.")
          ("Open or create a copy under Documents/CAD tool/work before finalizing." . "마무리하기 전에 Documents/CAD tool/work 아래 복사본을 열거나 만드세요.")
          ("Open or create a copy under Documents/CAD tool/work before upgrading." . "교체하기 전에 Documents/CAD tool/work 아래 복사본을 열거나 만드세요.")
          ("No drawing data was changed. Remove these only in a work copy after confirming they are not real drawing notes." . "도면 데이터는 변경하지 않았습니다. 실제 도면 주석이 아니라고 확인한 뒤 work 복사본에서만 삭제하세요.")
          ("WARNING: GMTITLE was moved by LISP after creation because native placement was not captured." . "경고: native 배치점을 잡지 못해 생성 후 LISP가 GMTITLE을 이동했습니다.")
          ("Note: create native GMTITLE with Frame positioning ON, Object move OFF, and the detected DR sheet before running finalize." . "참고: 마무리 전에 감지된 DR 용지로 native GMTITLE을 만들고, Frame positioning은 ON, Object move는 OFF로 두세요.")
          ("Note: if native placement is not captured and the pair must be moved from a default location, this command will not treat it as final GMTITLE recognition." . "참고: native 배치점을 잡지 못해 기본 위치에서 쌍을 이동해야 했다면, 이 명령은 최종 GMTITLE 인식 완료로 보지 않습니다.")
          ("Note: frame-only finalize is for sheets with an old frame but no old source title block." . "참고: frame-only 마무리는 기존 도면틀은 있지만 기존 원본 표제란 블록이 없는 시트용입니다.")
          ("Note: for native-safe use, create GMTITLE with Frame positioning ON and let it accept the sheet lower-left placement point." . "참고: native 인식을 안전하게 쓰려면 Frame positioning을 ON으로 두고, GMTITLE이 시트 왼쪽 아래 배치점을 받도록 하세요.")
          ("도면 데이터는 변경하지 않았습니다. Remove these only in a work copy after confirming they are not real drawing notes." . "도면 데이터는 변경하지 않았습니다. 실제 도면 주석이 아니라고 확인한 뒤 work 복사본에서만 삭제하세요.")
          ("Required dialog state:" . "필수 창 상태:")
          ("GMTITLE options:" . "GMTITLE 옵션:")
          ("Frame positioning ON" . "Frame positioning ON(도면틀 위치 자동 맞춤)")
          ("Object move OFF" . "Object move OFF(기존 도면 내용 이동 안 함)")
          ("Frame positioning=ON" . "Frame positioning=ON(도면틀 위치 자동 맞춤)")
          ("Object move=OFF" . "Object move=OFF(기존 도면 내용 이동 안 함)")
          ("Reason: each candidate may need the interactive GMTITLE dialog, and SCRIPT mode suppresses that fallback." . "이유: 각 후보는 대화식 GMTITLE 창이 필요할 수 있는데 SCRIPT 모드에서는 그 fallback이 막힙니다.")
          ("Run the status SCRIPT first, then type SWTITLECONVERT manually in the CAD command line." . "먼저 상태 SCRIPT를 실행한 뒤 CAD 명령줄에 SWTITLECONVERTNEXT를 직접 입력하세요.")
          ("WARNING:" . "경고:")
          ("Warning:" . "경고:")
          ("Note:" . "참고:")
          ("Next command:" . "다음 명령:")
          ("It will process " . "내부 처리 예정: ")
          (" currently listed A2/A3/A4 native replacement candidate(s) internally." . "개의 현재 A2/A3/A4 native 교체 후보")
          ("Title-missing/frame-only source sheets still remain; handle them after this native upgrade." . "title-missing/frame-only 원본 시트가 아직 남아 있습니다. 이 native 교체 후 처리하세요.")
          ("Title-missing/frame-only sheets will be handled inside the convert flow after required native checks." . "title-missing/frame-only 시트는 필요한 native 확인 뒤 변환 흐름 안에서 처리됩니다.")
          ("Final manual check: double-click representative DR_titlea_3rd title blocks. Title-missing/frame-only sheets have no title block to double-click." . "최종 수동 확인: 실제 DR_titlea_3rd 제목블록이 있는 대표 용지만 더블클릭하세요. 원본 표제란이 없는 title-missing/frame-only 시트는 더블클릭할 제목블록이 없습니다.")
          ("Important: native-finalize and native-frame-only must be legacy-uncertain=yes." . "중요: native-finalize와 native-frame-only는 legacy-uncertain=yes로 분류되어야 합니다.")
          ("If they are safe-native-source=yes, A2/A3/A4 GMPOWEREDIT failures can be hidden by stale logic." . "safe-native-source=yes로 분류되면 오래된 로직 때문에 A2/A3/A4 GMPOWEREDIT 실패가 가려질 수 있습니다.")
          ("Open a writable work copy before repairing frame definitions." . "도면틀 정의를 복구하기 전에 쓰기 가능한 작업복사본을 여세요.")
          ("Open a writable work copy before cleaning frame definitions." . "도면틀 정의를 정리하기 전에 쓰기 가능한 작업복사본을 여세요.")
          ("Open a writable work copy before applying." . "적용하기 전에 쓰기 가능한 작업복사본을 여세요.")
          ("Open a writable copy of the DWG before applying." . "적용하기 전에 쓰기 가능한 DWG 복사본을 여세요.")
          ("Open a writable copy of the DWG before finalizing." . "마무리하기 전에 쓰기 가능한 DWG 복사본을 여세요.")
          ("Open a writable copy of the DWG before upgrading." . "교체하기 전에 쓰기 가능한 DWG 복사본을 여세요.")
          ("Target frame block definitions before repair:" . "복구 전 대상 도면틀 블록 정의:")
          ("Target frame block definitions after repair:" . "복구 후 대상 도면틀 블록 정의:")
          ("Target frame block definitions before cleanup:" . "정리 전 대상 도면틀 블록 정의:")
          ("Target frame block definitions after cleanup:" . "정리 후 대상 도면틀 블록 정의:")
          ("Native GMTITLE exemplars by sheet frame:" . "용지 도면틀별 native GMTITLE 기준 객체:")
          ("Native frame readiness by visible target frame:" . "보이는 대상 도면틀별 native 준비 상태:")
          ("Native frame readiness by visible target frame: <missing>" . "보이는 대상 도면틀별 native 준비 상태: <없음>")
          ("Frame link handle usage:" . "도면틀 link 핸들 사용 현황:")
          ("Target frame block definition child INSERT names:" . "대상 도면틀 블록 정의 내부 INSERT 이름:")
          ("Title inserts: <missing>" . "제목블록 INSERT: <없음>")
          ("Other title-like inserts that are not the target GMTITLE block:" . "대상 GMTITLE 블록이 아닌 기타 title-like INSERT:")
          ("Target frame inserts:" . "대상 도면틀 INSERT:")
          ("Target frame detail:" . "대상 도면틀 상세:")
          ("Target frame detail: <missing>" . "대상 도면틀 상세: <없음>")
          ("GMPOWEREDIT diagnosis: cloned GMTITLE pairs remain." . "GMPOWEREDIT 진단: 복제 GMTITLE 쌍이 남아 있습니다.")
          ("Clone means the visible frame/title and attributes were copied, but GstarCAD native editor recognition is not proven for that pair." . "복제란 보이는 도면틀/제목블록과 속성은 복사됐지만, 해당 쌍의 GstarCAD native 편집 인식은 아직 증명되지 않았다는 뜻입니다.")
          ("GMPOWEREDIT diagnosis: multiple GMTITLE titles share the same internal native recognition handle." . "GMPOWEREDIT 진단: 여러 GMTITLE 제목블록이 같은 내부 native 인식 핸들을 공유합니다.")
          ("This is typical of preserve-copy/clone output: it can look correct, but double-click recognition can fall back to REFEDIT or block editing." . "preserve-copy/clone 결과에서 흔한 상태입니다. 모양은 맞아 보여도 더블클릭 인식이 REFEDIT 또는 블록 편집으로 돌아갈 수 있습니다.")
          ("Missing-sheet diagnosis: old SOLIDWORKS frame-only sheets still remain." . "누락 시트 진단: 기존 SOLIDWORKS frame-only 시트가 아직 남아 있습니다.")
          ("Next after native clone review: run SWTITLECONVERT to handle remaining title-missing/frame-only exception sheets." . "native 복제 검토 후 다음 단계: 남은 title-missing/frame-only 예외 시트는 SWTITLECONVERTNEXT로 처리하세요.")
          ("Loose text scale candidates:" . "분리된 텍스트 스케일 후보:")
          ("Possible accidental command text entities:" . "실수로 도면에 들어간 명령어 텍스트 후보:")
          ("Command text cleanup is limited to Documents/CAD tool/work copies." . "명령어 텍스트 정리는 Documents/CAD tool/work 안의 복사본에서만 실행합니다.")
          ("Title-like inserts and attributes:" . "title-like INSERT와 속성:")
          ("Loose TEXT/MTEXT inside title-block bounds:" . "제목블록 범위 안의 분리된 TEXT/MTEXT:")
          ("Loose TEXT/MTEXT records:" . "분리된 TEXT/MTEXT 기록:")
          ("GM TITLE attribute transfer preview:" . "GM TITLE 속성 이전 미리보기:")
          ("Unmapped source title texts:" . "매핑되지 않은 원본 표제란 텍스트:")
          ("Duplicate source title texts:" . "중복 원본 표제란 텍스트:")
          ("Values to apply:" . "적용할 값:")
          ("Frame-only values to apply:" . "frame-only에 적용할 값:")
          ("Confirmation: batch mode" . "확인: 일괄 모드")
          ("Native GMTITLE was created away from the source frame and would need LISP MOVE alignment." . "native GMTITLE이 원본 도면틀과 떨어진 곳에 생성되어 LISP MOVE 정렬이 필요합니다.")
          ("That pattern is not trusted because GMPOWEREDIT/double-click behavior can fail after visual alignment." . "이 방식은 화면상 정렬 후에도 GMPOWEREDIT/더블클릭 동작이 실패할 수 있어 신뢰하지 않습니다.")
          ("Native GMTITLE was used directly." . "native GMTITLE을 직접 사용했습니다.")
          ("Cloned GMTITLE was finalized; native upgrade is still required for double-click behavior." . "복제 GMTITLE 마무리는 완료됐지만, 더블클릭 동작을 위해 native 교체가 아직 필요합니다.")
          ("Cloned GMTITLE was finalized for frame-only source; native upgrade is still required for double-click behavior." . "frame-only 원본에 대한 복제 GMTITLE 마무리는 완료됐지만, 더블클릭 동작을 위해 native 교체가 아직 필요합니다.")
          ("Existing/default native GMTITLE was used for frame-only source." . "frame-only 원본에 기존/기본 native GMTITLE을 사용했습니다.")
          ("Title-missing/frame-only exception handling: GMTITLE was created at the default location and moved to the old source frame." . "title-missing/frame-only 예외 처리: GMTITLE이 기본 위치에 생성된 뒤 기존 도면틀로 이동됐습니다.")
          ("This is allowed only for verified title-missing/frame-only sheets; run SWTITLEVERIFY after conversion." . "이 처리는 원본 표제란 부재가 검증된 title-missing/frame-only 시트에서만 허용됩니다. 변환 후 SWTITLEVERIFY로 해당 DR 도면틀 수량/형상을 검증하세요.")
          ("Visible A4 frame size is usable, but extra dependency/block geometry is attached outside the frame." . "보이는 A4 도면틀 크기는 사용할 수 있지만, 도면틀 밖에 추가 의존/블록 형상이 붙어 있습니다.")
          ("The created GMTITLE frame bbox will be checked before any old title-missing/frame-only content is removed." . "기존 title-missing/frame-only 내용을 삭제하기 전에 새 GMTITLE 도면틀 bbox를 먼저 검사합니다.")
          ("Native GMTITLE will open once for this frame-only sheet." . "이 frame-only 시트에 대해 native GMTITLE 창이 한 번 열립니다.")
          ("Frame-only clone error: verified GMTITLE exemplar or target frame could not be created." . "frame-only clone 오류: 검증된 GMTITLE 기준 객체 또는 대상 도면틀을 만들 수 없습니다.")
          ("Double-click note: this is the DR_A*_Outline frame INSERT. GMPOWEREDIT may show block/reference editing here." . "더블클릭 참고: 이것은 DR_A*_Outline 도면틀 INSERT입니다. 여기서는 GMPOWEREDIT가 블록/참조 편집을 보일 수 있습니다.")
          ("Double-click note: this is the title block area; this is the right place to check the GMTITLE table editor." . "더블클릭 참고: 이것은 제목블록 영역입니다. GMTITLE 표 편집창 확인은 여기서 하는 것이 맞습니다.")
          ("No matching DR_A*_Outline + DR_titlea_3rd pair was found at the selected entity/point." . "선택한 객체/점에서 일치하는 DR_A*_Outline + DR_titlea_3rd 쌍을 찾지 못했습니다.")
          ("Manual check rule: double-click the DR_titlea_3rd title block, not the DR_A*_Outline frame." . "수동 확인 규칙: DR_A*_Outline 도면틀이 아니라 DR_titlea_3rd 제목블록을 더블클릭하세요.")
          ("The frame may open GMPOWEREDIT/REFEDIT even when the paired title block is usable." . "짝 제목블록이 정상이어도 도면틀은 GMPOWEREDIT/REFEDIT로 열릴 수 있습니다.")
          ("Use the listed title double-click point as the visual target; the live cursor grip can still look centered in GstarCAD." . "목록의 제목블록 더블클릭 점을 시각적 목표로 사용하세요. GstarCAD의 실시간 커서 grip은 여전히 중앙처럼 보일 수 있습니다.")
          ("No DR_A*_Outline + DR_titlea_3rd pairs were found." . "DR_A*_Outline + DR_titlea_3rd 쌍을 찾지 못했습니다.")
          ("Role baseline check:" . "역할 기준 확인:")
          ("Candidate detail:" . "후보 상세:")
          ("Clone upgrade queue:" . "clone 교체 대기열:")
          ("Moved native placement accepted after geometry check." . "형상 검사를 통과해 이동 배치된 native GMTITLE을 허용했습니다.")
          ("Run final double-click verification after conversion." . "변환 후 최종 더블클릭 검증을 실행하세요.")
          ("Manual check: double-click the upgraded title block and confirm the GMTITLE table editor opens." . "수동 확인: 교체된 제목블록을 더블클릭해 GMTITLE 표 편집창이 열리는지 확인하세요.")
          ("The existing GMTITLE pair was kept." . "기존 GMTITLE 쌍은 유지했습니다.")
          ("The new GMTITLE was not created at the pending frame lower-left point." . "새 GMTITLE이 대기 중인 도면틀 왼쪽 아래 점에 생성되지 않았습니다.")
          ("Select a cloned or target GMTITLE frame/title to upgrade to real native GMTITLE." . "실제 native GMTITLE로 교체할 복제 또는 대상 GMTITLE 도면틀/제목블록을 선택하세요.")
          ("This step upgrades only one sheet." . "이 단계는 한 시트만 교체합니다.")
          ("The GMTITLE dialog may still open with ordinary A3/A4 or ISO title defaults." . "GMTITLE 창이 DR이 아닌 일반 용지 또는 ISO 제목블록 기본값으로 열릴 수 있습니다.")
          ("Do not press OK unless the dialog shows the DR paper and DR_titlea_3rd." . "창에 DR 용지와 DR_titlea_3rd가 표시되지 않으면 OK를 누르지 마세요.")
          ("User did not type OPEN, so GMTITLE was not opened." . "OPEN, MANUAL, BATCH를 입력하지 않아 GMTITLE을 열지 않았습니다.")
          ("A2/A3/A4 batch native upgrade is limited to Documents/CAD tool/work copies." . "A2/A3/A4 일괄 native 교체는 Documents/CAD tool/work 안의 복사본에서만 실행합니다.")
          ("If the dialog still shows ISO paper/title values, cancel it. Confirming ISO values will not fix GMPOWEREDIT behavior." . "창이 여전히 ISO 용지/제목블록 값을 보이면 취소하세요. ISO 값을 확인해도 GMPOWEREDIT 동작은 고쳐지지 않습니다.")
          ("Remaining candidates after the stopped sheet:" . "중단된 시트 뒤에 남은 후보:")
          ("Next:" . "다음:")
          ("Reason:" . "이유:")
          ("Summary:" . "요약:")
          ("<none>" . "<없음>")
          ("missing" . "없음")
          ("ready" . "준비됨")
          ("read-only" . "읽기 전용")
          ("fast summary" . "빠른 요약")
          ("fast batch readiness" . "빠른 일괄 변환 준비 상태")
          ("full GMTITLE verification" . "전체 GMTITLE 검증")
          ("GMTITLE transfer apply" . "GMTITLE 변환 적용")
          ("first-native + fast batch transfer" . "첫 native 생성 + 빠른 일괄 변환")
          ("fast remaining-sheet transfer" . "남은 시트 빠른 변환")
          ("frame-only" . "표제란 없는 도면틀")
          ("double-click" . "더블클릭")
          ("clone" . "복제")
        )
      )
      (foreach pair replacements
        (setq result (swcad-title-replace-all result (car pair) (cdr pair)))
      )
    )
  )
  result
)

(defun swcad-title-princ-line (text)
  (setq text (swcad-title-korean-line text))
  (princ (strcat "\n" text))
  (if *swcad-title-debug-log-handle*
    (write-line text *swcad-title-debug-log-handle*)
  )
)

(defun swcad-title-princ-raw-line (text)
  (setq text (swcad-title-string text))
  (princ (strcat "\n" text))
  (if *swcad-title-debug-log-handle*
    (write-line text *swcad-title-debug-log-handle*)
  )
)

(defun swcad-title-princ-text (text)
  (princ (swcad-title-korean-line text))
)

(defun swcad-title-auto-next-answer (answer message)
  (if *swcad-title-convert-next-mode*
    (progn
      (swcad-title-princ-line
        (strcat
          "SWTITLECONVERTNEXT auto response: "
          answer
          (if message (strcat " - " message) "")
        )
      )
      answer
    )
    nil
  )
)

(defun swcad-title-auto-next-answer-or-prompt (auto-answer auto-message prompt / answer)
  (setq answer (swcad-title-auto-next-answer auto-answer auto-message))
  (if answer
    answer
    (getstring T prompt)
  )
)

(defun swcad-title-log-line (text)
  (setq text (swcad-title-korean-line text))
  (if *swcad-title-debug-log-handle*
    (write-line text *swcad-title-debug-log-handle*)
  )
)

(defun swcad-title-debug-log-path (/ home)
  (swcad-title-work-log-path "swcad_title_debug_last.txt")
)

(defun swcad-title-log-filename (filename / dot suffix)
  (setq suffix
    (if (and (boundp '*swcad-title-log-file-suffix*) *swcad-title-log-file-suffix*)
      *swcad-title-log-file-suffix*
      ""
    )
  )
  (if (= suffix "")
    filename
    (progn
      (setq dot (vl-string-search "." filename))
      (if dot
        (strcat (substr filename 1 dot) suffix (substr filename (+ dot 1)))
        (strcat filename suffix)
      )
    )
  )
)

(defun swcad-title-ensure-directory-path (path / clean parent result)
  (setq clean (if path (vl-string-right-trim "\\/" path) nil))
  (cond
    ((or (not clean) (= clean "")) nil)
    ((vl-file-directory-p clean) T)
    (T
      (setq parent (vl-filename-directory clean))
      (if
        (and
          parent
          (/= (strcase parent) (strcase clean))
          (not (vl-file-directory-p parent))
        )
        (swcad-title-ensure-directory-path parent)
      )
      (setq result (vl-catch-all-apply 'vl-mkdir (list clean)))
      (and (not (vl-catch-all-error-p result)) (vl-file-directory-p clean))
    )
  )
)

(defun swcad-title-local-log-root-path (/ base root)
  (setq base (getenv "LOCALAPPDATA"))
  (if (not base) (setq base (getenv "TEMP")))
  (if (not base) (setq base (getvar "DWGPREFIX")))
  (setq root
    (if base
      (strcat (vl-string-right-trim "\\/" (vl-string-translate "\\" "/" base)) "/SWTitle/logs/")
      ""
    )
  )
  (if (and (/= root "") (swcad-title-ensure-directory-path root)) root "")
)

(defun swcad-title-work-log-path (filename / root)
  (setq root
    (if (swcad-title-current-dwg-under-legacy-work-root-p)
      (swcad-title-work-root-path)
      (swcad-title-local-log-root-path)
    )
  )
  (strcat root (swcad-title-log-filename filename))
)

(defun swcad-title-work-root-path (/ home)
  (setq home (getenv "USERPROFILE"))
  (if home
    (strcat
      (vl-string-translate "\\" "/" home)
      "/Documents/CAD tool/work/"
    )
    ""
  )
)

(defun swcad-title-repo-root-path (/ home source-dir candidate)
  (setq candidate
    (if (and (boundp '*swcad-root*) *swcad-root*)
      (vl-string-right-trim "\\/" (vl-string-translate "\\" "/" *swcad-root*))
      nil
    )
  )
  (if (and candidate (findfile (strcat candidate "/src/tools/gmtitle/swcad_title_scale.lsp")))
    (strcat candidate "/")
    (progn
      (setq source-dir (if *swcad-title-source-path* (vl-filename-directory *swcad-title-source-path*) nil))
      (setq candidate
        (if source-dir
          (vl-filename-directory (vl-filename-directory (vl-filename-directory source-dir)))
          nil
        )
      )
      (if (and candidate (findfile (strcat candidate "/src/tools/gmtitle/swcad_title_scale.lsp")))
        (strcat (vl-string-right-trim "\\/" (vl-string-translate "\\" "/" candidate)) "/")
        (progn
          (setq home (getenv "USERPROFILE"))
          (if home
            (strcat (vl-string-translate "\\" "/" home) "/Documents/CAD tool/")
            ""
          )
        )
      )
    )
  )
)

(defun swcad-title-gmtitle-autoselect-helper-path (/ source-dir same-dir packaged)
  (setq source-dir (if *swcad-title-source-path* (vl-filename-directory *swcad-title-source-path*) nil))
  (setq same-dir
    (if source-dir
      (strcat (vl-string-right-trim "\\/" (vl-string-translate "\\" "/" source-dir)) "/swtitle_gmtitle_dialog_autoselect.ps1")
      nil
    )
  )
  (setq packaged
    (strcat (swcad-title-repo-root-path) "src/tools/gmtitle/swtitle_gmtitle_dialog_autoselect.ps1")
  )
  (cond
    ((and same-dir (findfile same-dir)) same-dir)
    ((findfile packaged) packaged)
    (same-dir same-dir)
    (T packaged)
  )
)

(defun swcad-title-gmtitle-autoselect-request-path ()
  (swcad-title-work-log-path "swcad_title_gmtitle_autoselect_request.txt")
)

(defun swcad-title-gmtitle-autoselect-log-path ()
  (swcad-title-work-log-path "swcad_title_gmtitle_autoselect_last.txt")
)

(defun swcad-title-write-native-autoselect-batch-summary (initial-count remaining-count status / path handle titles title shared-count)
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq shared-count 0)
  (foreach title titles
    (if (swcad-title-target-title-native-link-shared-p title)
      (setq shared-count (+ shared-count 1))
    )
  )
  (setq path (swcad-title-work-log-path "swcad_title_native_autoselect_batch_last.txt"))
  (setq handle (open path "w"))
  (if handle
    (progn
      (write-line "SWTITLE native fixed-control batch summary" handle)
      (write-line (strcat "SWTITLE LSP version: " *swcad-title-scale-version*) handle)
      (write-line
        (strcat
          "DWG: "
          (swcad-title-windows-path (swcad-title-current-dwg-full-path))
        )
        handle
      )
      (write-line (strcat "Initial source title sheets: " (itoa initial-count)) handle)
      (write-line (strcat "Remaining source title sheets: " (itoa remaining-count)) handle)
      (write-line (strcat "Target title inserts: " (itoa (length titles))) handle)
      (write-line (strcat "Target GMTITLE pairs: " (itoa (length (swcad-title-target-gmtitle-pair-records)))) handle)
      (write-line (strcat "Shared native-link target titles: " (itoa shared-count)) handle)
      (write-line (strcat "Native upgrade candidates: " (itoa (length (swcad-title-a3a4-native-upgrade-candidate-records)))) handle)
      (write-line (strcat "Result: " (swcad-title-string status)) handle)
      (write-line "Runtime check completed: yes" handle)
      (close handle)
    )
  )
  path
)

(defun swcad-title-write-title-missing-batch-summary (initial-count remaining-count status / path handle)
  (setq path (swcad-title-work-log-path "swcad_title_title_missing_batch_last.txt"))
  (setq handle (open path "w"))
  (if handle
    (progn
      (write-line "SWTITLE verified title-missing outline batch summary" handle)
      (write-line (strcat "SWTITLE LSP version: " *swcad-title-scale-version*) handle)
      (write-line
        (strcat
          "DWG: "
          (swcad-title-windows-path (swcad-title-current-dwg-full-path))
        )
        handle
      )
      (write-line (strcat "Initial title-missing sheets: " (itoa initial-count)) handle)
      (write-line (strcat "Remaining title-missing sheets: " (itoa remaining-count)) handle)
      (write-line (strcat "Target frame inserts: " (itoa (length (swcad-title-frame-records)))) handle)
      (write-line
        (strcat
          "Target title inserts: "
          (itoa (length (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name))))
        )
        handle
      )
      (write-line (strcat "Result: " (swcad-title-string status)) handle)
      (write-line "Runtime check completed: yes" handle)
      (close handle)
    )
  )
  path
)

(defun swcad-title-windows-path (value)
  (vl-string-translate "/" "\\" (swcad-title-string value))
)

(defun swcad-title-command-line-quote (value)
  (strcat "\"" (swcad-title-windows-path value) "\"")
)

(defun swcad-title-application-hwnd (/ application result)
  (setq application (vlax-get-acad-object))
  (setq result (swcad-title-safe-vla-get application 'HWND))
  (if (numberp result) result nil)
)

(defun swcad-title-gmtitle-autoselect-available-p (/ helper hwnd)
  (setq helper (swcad-title-gmtitle-autoselect-helper-path))
  (setq hwnd (swcad-title-application-hwnd))
  (and
    *swcad-title-gmtitle-dialog-autoselect-enabled*
    (/= (swcad-title-string (getenv "SWCAD_GMTITLE_EXTERNAL_CONTROL")) "1")
    (swcad-title-current-dwg-in-work-p)
    (findfile helper)
    hwnd
  )
)

(defun swcad-title-write-gmtitle-autoselect-request (path frame-block hwnd / handle)
  (setq handle (open path "w"))
  (if handle
    (progn
      (write-line "SWTITLE GMTITLE fixed-control request" handle)
      (write-line
        (strcat
          "DWG before load: "
          (swcad-title-windows-path (swcad-title-current-dwg-full-path))
        )
        handle
      )
      (write-line (strcat "Application HWND: " (swcad-title-string hwnd)) handle)
      (write-line (strcat "Expected frame: " (swcad-title-string frame-block)) handle)
      (write-line (strcat "Expected title: " (swcad-title-target-title-block-name)) handle)
      (write-line "Frame positioning: ON" handle)
      (write-line "Object move: OFF" handle)
      (close handle)
      T
    )
    nil
  )
)

(defun swcad-title-start-gmtitle-dialog-autoselect (frame-block / helper request-path log-path hwnd shell command-line launch-result)
  (setq *swcad-title-last-gmtitle-autoselect-started* nil)
  (if (swcad-title-gmtitle-autoselect-available-p)
    (progn
      (setq helper (swcad-title-gmtitle-autoselect-helper-path))
      (setq request-path (swcad-title-gmtitle-autoselect-request-path))
      (setq log-path (swcad-title-gmtitle-autoselect-log-path))
      (setq hwnd (swcad-title-application-hwnd))
      (if (findfile log-path)
        (vl-file-delete log-path)
      )
      (if (swcad-title-write-gmtitle-autoselect-request request-path frame-block hwnd)
        (progn
          (setq command-line
            (strcat
              "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "
              (swcad-title-command-line-quote helper)
              " -ApplicationWindowHandle "
              (swcad-title-string hwnd)
              " -ExpectedDwgPath "
              (swcad-title-command-line-quote (swcad-title-current-dwg-full-path))
              " -SessionLogPath "
              (swcad-title-command-line-quote request-path)
              " -ExpectedFrame "
              (swcad-title-command-line-quote frame-block)
              " -ExpectedTitle "
              (swcad-title-command-line-quote (swcad-title-target-title-block-name))
              " -WaitSeconds 90 -LogPath "
              (swcad-title-command-line-quote log-path)
              " -ApplySelections -ClickOk"
            )
          )
          (setq shell (vl-catch-all-apply 'vlax-create-object (list "WScript.Shell")))
          (if (vl-catch-all-error-p shell)
            (swcad-title-princ-line
              (strcat
                "GMTITLE 고정 컨트롤 자동 선택기를 시작하지 못했습니다: "
                (vl-catch-all-error-message shell)
              )
            )
            (progn
              (setq launch-result
                (vl-catch-all-apply
                  'vlax-invoke-method
                  (list shell 'Run command-line 0 :vlax-false)
                )
              )
              (vlax-release-object shell)
              (if (vl-catch-all-error-p launch-result)
                (swcad-title-princ-line
                  (strcat
                    "GMTITLE 고정 컨트롤 자동 선택기 실행 오류: "
                    (vl-catch-all-error-message launch-result)
                  )
                )
                (progn
                  (setq *swcad-title-last-gmtitle-autoselect-started* T)
                  (swcad-title-princ-line
                    (strcat
                      "GMTITLE 고정 컨트롤 자동 선택기 시작: 용지="
                      frame-block
                      ", 제목블록="
                      (swcad-title-target-title-block-name)
                      ", Frame positioning=ON, Object move=OFF."
                    )
                  )
                )
              )
            )
          )
        )
        (swcad-title-princ-line "GMTITLE 자동 선택 요청 파일을 만들 수 없어 수동 선택으로 전환합니다.")
      )
    )
  )
  *swcad-title-last-gmtitle-autoselect-started*
)

(defun swcad-title-current-dwg-full-path ()
  (vl-string-translate "\\" "/" (strcat (getvar "DWGPREFIX") (getvar "DWGNAME")))
)

(defun swcad-title-normalized-path (value)
  (strcase
    (vl-string-right-trim
      "\\/"
      (vl-string-translate "\\" "/" (swcad-title-string value))
    )
  )
)

(defun swcad-title-path-equal-p (left right)
  (equal (swcad-title-normalized-path left) (swcad-title-normalized-path right))
)

(defun swcad-title-current-dwg-under-legacy-work-root-p (/ root)
  (setq root (swcad-title-work-root-path))
  (and
    root
    (/= root "")
    (swcad-title-string-prefix-p root (swcad-title-current-dwg-full-path))
  )
)

(defun swcad-title-work-copy-marker-entity (/ ename)
  (setq ename (tblobjname "BLOCK" "*Model_Space"))
  (if ename ename (tblobjname "BLOCK" "*MODEL_SPACE"))
)

(defun swcad-title-selected-work-copy-p (/ ename record values)
  (setq ename (swcad-title-work-copy-marker-entity))
  (setq record
    (if ename
      (swcad-title-xdata-record-by-app ename *swcad-title-workcopy-xdata-app*)
      nil
    )
  )
  (setq values (if record (swcad-title-xdata-text-values record) nil))
  (if (member *swcad-title-workcopy-xdata-marker* values) T nil)
)

(defun swcad-title-clear-selected-work-copy-marker (/ ename data clean result)
  (setq ename (swcad-title-work-copy-marker-entity))
  (if (and ename (setq data (entget ename '("*"))))
    (progn
      (setq clean
        (swcad-title-remove-xdata-app-from-data data *swcad-title-workcopy-xdata-app*)
      )
      (setq result (vl-catch-all-apply 'entmod (list clean)))
      (not (vl-catch-all-error-p result))
    )
    nil
  )
)

(defun swcad-title-mark-selected-work-copy (source-name / ename app data clean record result)
  (setq ename (swcad-title-work-copy-marker-entity))
  (setq app *swcad-title-workcopy-xdata-app*)
  (if
    (and
      ename
      (swcad-title-ensure-regapp app)
      (setq data (entget ename '("*")))
    )
    (progn
      (setq clean (swcad-title-remove-xdata-app-from-data data app))
      (setq record
        (list
          app
          (cons 1000 *swcad-title-workcopy-xdata-marker*)
          (cons 1000 *swcad-title-scale-version*)
          (cons 1000 (strcat "SOURCE-NAME:" (swcad-title-string source-name)))
        )
      )
      (setq result
        (vl-catch-all-apply
          'entmod
          (list (append clean (list (cons -3 (list record)))))
        )
      )
      (and
        (not (vl-catch-all-error-p result))
        (swcad-title-selected-work-copy-p)
      )
    )
    nil
  )
)

(defun swcad-title-work-copy-timestamp (/ result)
  (setq result
    (vl-catch-all-apply
      'menucmd
      (list "M=$(edtime,$(getvar,date),YYYYMMDD-HHMMSS)")
    )
  )
  (if (or (vl-catch-all-error-p result) (/= (type result) 'STR) (= result ""))
    "WORKCOPY"
    result
  )
)

(defun swcad-title-default-work-copy-path (/ prefix base)
  (setq prefix (vl-string-translate "\\" "/" (getvar "DWGPREFIX")))
  (setq base (vl-filename-base (getvar "DWGNAME")))
  (strcat
    prefix
    base
    "_SWTITLE_"
    (swcad-title-work-copy-timestamp)
    ".dwg"
  )
)

(defun swcad-title-saveas-selected-work-copy (/ source-path source-name default-path selected-path doc saveas-result marker-ok save-result)
  (setq source-path (swcad-title-current-dwg-full-path))
  (setq source-name (getvar "DWGNAME"))
  (setq default-path (swcad-title-default-work-copy-path))
  (swcad-title-princ-line "변환 전에 원본을 보존할 새 SWTITLE 작업본 위치와 파일명을 선택하세요.")
  (swcad-title-princ-line "선택한 새 DWG가 활성 도면이 되며, 원본 DWG 파일은 변경하지 않습니다.")
  (setq selected-path
    (if
      (and
        (boundp '*swcad-title-work-copy-saveas-path-override*)
        *swcad-title-work-copy-saveas-path-override*
        (/= (swcad-title-string *swcad-title-work-copy-saveas-path-override*) "")
      )
      *swcad-title-work-copy-saveas-path-override*
      (getfiled
        "SWTITLE 변환 작업본을 다른 이름으로 저장"
        default-path
        "dwg"
        1
      )
    )
  )
  (cond
    ((not selected-path)
      (swcad-title-apply-result "ABORT_WORK_COPY_SAVEAS_CANCELLED")
      (swcad-title-princ-line "작업본 저장 위치 선택을 취소했습니다. 원본과 도면 데이터는 변경하지 않았습니다.")
      nil
    )
    ((swcad-title-path-equal-p source-path selected-path)
      (swcad-title-apply-result "ABORT_WORK_COPY_SAME_PATH")
      (swcad-title-princ-line "원본과 같은 경로는 선택할 수 없습니다. 다른 파일명이나 폴더를 선택하세요.")
      (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
      nil
    )
    (T
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (setq saveas-result (vl-catch-all-apply 'vla-SaveAs (list doc selected-path)))
      (cond
        ((vl-catch-all-error-p saveas-result)
          (swcad-title-apply-result "ERROR_WORK_COPY_SAVEAS_FAILED")
          (swcad-title-princ-line
            (strcat "작업본 저장 실패: " (vl-catch-all-error-message saveas-result))
          )
          (swcad-title-princ-line "원본 도면 변환은 시작하지 않았습니다.")
          nil
        )
        ((not (swcad-title-path-equal-p selected-path (swcad-title-current-dwg-full-path)))
          (swcad-title-apply-result "ERROR_WORK_COPY_ACTIVE_PATH_MISMATCH")
          (swcad-title-princ-line "저장 후 활성 DWG 경로가 선택한 작업본과 일치하지 않아 중단합니다.")
          nil
        )
        (T
          (setq marker-ok (swcad-title-mark-selected-work-copy source-name))
          (if marker-ok
            (setq save-result (vl-catch-all-apply 'vla-Save (list doc)))
            (setq save-result nil)
          )
          (if
            (and
              marker-ok
              (not (vl-catch-all-error-p save-result))
              (swcad-title-selected-work-copy-p)
            )
            (progn
              (setq *swcad-title-last-apply-status* "WORK_COPY_SAVEAS_OK")
              (swcad-title-princ-line (strcat "SWTITLE 작업본 생성 완료: " (swcad-title-current-dwg-full-path)))
              (swcad-title-princ-line (strcat "보존된 원본: " source-path))
              T
            )
            (progn
              (swcad-title-clear-selected-work-copy-marker)
              (swcad-title-apply-result "ERROR_WORK_COPY_MARKER_SAVE_FAILED")
              (swcad-title-princ-line "작업본 표식을 저장하지 못해 변환을 시작하지 않습니다.")
              nil
            )
          )
        )
      )
    )
  )
)

(defun swcad-title-current-dwg-dbmod (/ value)
  (setq value (swcad-title-safe-getvar "DBMOD"))
  (if (numberp value) value 0)
)

(defun swcad-title-current-dwg-unsaved-p ()
  (/= (swcad-title-current-dwg-dbmod) 0)
)

(defun swcad-title-print-current-dwg-save-status (/ dbmod)
  (setq dbmod (swcad-title-current-dwg-dbmod))
  (swcad-title-princ-line
    (strcat
      "DWG 저장 상태: "
      (if (/= dbmod 0) "저장되지 않은 변경 있음" "저장됨")
      " (DBMOD="
      (itoa dbmod)
      ")"
    )
  )
  (if (/= dbmod 0)
    (progn
      (swcad-title-princ-line "주의: 숨김 진단 probe는 마지막 저장본을 다시 열기 때문에 현재 화면과 다를 수 있습니다.")
      (swcad-title-princ-line "다른 PC나 숨김 probe에서 이어가려면 먼저 이 작업복사본 DWG를 저장하세요.")
    )
  )
)

(defun swcad-title-after-manual-step-command (/ home)
  (setq home (getenv "USERPROFILE"))
  (if home
    (strcat
      "     powershell -NoProfile -ExecutionPolicy Bypass -File \""
      home
      "\\Documents\\CAD tool\\diagnostics\\gmtitle-main45\\run_after_manual_gmtitle_step.ps1\""
    )
    "     powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\\gmtitle-main45\\run_after_manual_gmtitle_step.ps1"
  )
)

(defun swcad-title-print-after-manual-step-guidance ()
  (swcad-title-princ-line "수동 GMTITLE 한 장 처리 후 권장 점검:")
  (swcad-title-princ-line "  1. 이 작업복사본 DWG를 저장하세요.")
  (swcad-title-princ-line "  2. GstarCAD를 닫으세요.")
  (swcad-title-princ-line "  3. CAD 밖 PowerShell에서 다음 래퍼를 실행하세요:")
  (swcad-title-princ-line (swcad-title-after-manual-step-command))
  (swcad-title-princ-line "  이 래퍼가 direct probe 갱신, 다음 작업 카드, 필요 시 final completion gate를 묶어서 실행합니다.")
  (swcad-title-princ-line "  저장/닫기 전에는 숨김 probe가 현재 화면 상태를 제대로 판단하지 못할 수 있습니다.")
)

(defun swcad-title-print-log-evidence-note ()
  (swcad-title-princ-line
    (strcat
      "현재 DWG 파일: "
      (swcad-title-current-dwg-full-path)
    )
  )
  (swcad-title-princ-line
    "로그 판단 기준: *_last.txt를 볼 때도 먼저 이 DWG 파일 경로가 현재 열린 work 복사본과 같은지 확인하세요."
  )
  (swcad-title-princ-line
    "주의: suite/probe 실행 뒤에는 마지막 로그가 swtitle_*_probe*.dwg나 compare 전용 DWG를 가리킬 수 있습니다."
  )
)

(defun swcad-title-string-prefix-p (prefix value)
  (and
    prefix
    value
    (<= (strlen prefix) (strlen value))
    (equal
      (strcase prefix)
      (strcase (substr value 1 (strlen prefix)))
    )
  )
)

(defun swcad-title-current-dwg-in-work-p ()
  (or
    (swcad-title-current-dwg-under-legacy-work-root-p)
    (swcad-title-selected-work-copy-p)
  )
)

(defun swcad-title-work-copy-authorization-source ()
  (cond
    ((swcad-title-current-dwg-under-legacy-work-root-p) "legacy-work-folder")
    ((swcad-title-selected-work-copy-p) "user-selected-saveas-copy")
    (T "not-selected")
  )
)

(defun swcad-title-ensure-work-copy-for-mutation ()
  (if (swcad-title-current-dwg-in-work-p)
    T
    (swcad-title-saveas-selected-work-copy)
  )
)

(defun swcad-title-print-work-copy-status ()
  (swcad-title-princ-line
    (strcat
      "Work-folder test copy: "
      (if (swcad-title-current-dwg-in-work-p) "yes" "no")
    )
  )
  (swcad-title-princ-line
    (strcat "Work-copy authorization: " (swcad-title-work-copy-authorization-source))
  )
)

(defun swcad-title-open-document-count (/ docs result)
  (setq docs (vl-catch-all-apply 'vla-get-Documents (list (vlax-get-acad-object))))
  (if (vl-catch-all-error-p docs)
    1
    (progn
      (setq result (vl-catch-all-apply 'vla-get-Count (list docs)))
      (if (or (vl-catch-all-error-p result) (not (numberp result)))
        1
        result
      )
    )
  )
)

(defun swcad-title-active-dwg-confirmed-p (/ count answer)
  (setq count (swcad-title-open-document-count))
  (if (<= count 1)
    T
    (progn
      (swcad-title-princ-line
        (strcat
          "여러 도면 탭 경고: 현재 열린 도면 수="
          (itoa count)
        )
      )
      (swcad-title-princ-line
        (strcat
          "현재 활성 DWG: "
          (swcad-title-current-dwg-full-path)
        )
      )
      (swcad-title-princ-line "SWTITLEPREPARE/SWTITLECONVERT는 현재 활성 탭의 도면을 변경할 수 있습니다.")
      (setq answer
        (getstring
          T
          "\n이 도면이 목표 work 복사본이면 ACTIVE를 입력하고, 아니면 Enter로 중단하세요: "
        )
      )
      (equal (strcase answer) "ACTIVE")
    )
  )
)

(defun swcad-title-abort-multiple-open-dwgs ()
  (swcad-title-apply-result "ABORT_MULTIPLE_OPEN_DWGS")
  (swcad-title-princ-text "\n여러 도면이 열려 있어 현재 활성 도면 확인이 필요합니다.")
  (swcad-title-princ-text (strcat "\n현재 활성 DWG: " (swcad-title-current-dwg-full-path)))
  (swcad-title-princ-text "\n도면 데이터는 변경하지 않았습니다.")
)

(defun swcad-title-print-loaded-version ()
  (swcad-title-princ-raw-line
    (strcat
      "SWTITLE LSP 버전: "
      (swcad-title-string *swcad-title-scale-version*)
    )
  )
)

(defun swcad-title-apply-work-copy-confirmed-p ()
  (swcad-title-ensure-work-copy-for-mutation)
)

(defun swcad-title-open-log (filename header / handle path)
  (setq path (swcad-title-work-log-path filename))
  (setq handle (open path "w"))
  (setq *swcad-title-debug-log-path* path)
  (setq *swcad-title-debug-log-handle* handle)
  (if handle
    (write-line (swcad-title-korean-line header) handle)
  )
)

(defun swcad-title-open-debug-log ()
  (swcad-title-open-log "swcad_title_debug_last.txt" "SWTITLESTATUS 내부 debug log")
)

(defun swcad-title-open-scan-log ()
  (swcad-title-open-log "swcad_title_scan_last.txt" "SWTITLESTATUS 내부 스캔 로그")
)

(defun swcad-title-open-scale-log ()
  (swcad-title-open-log "swcad_scale_scan_last.txt" "SWSCALESCAN log")
)

(defun swcad-title-open-text-log ()
  (swcad-title-open-log "swcad_title_text_scan_last.txt" "SWTITLESTATUS 내부 텍스트 스캔 로그")
)

(defun swcad-title-open-command-text-log ()
  (swcad-title-open-log "swcad_title_command_text_scan_last.txt" "SWTITLESTATUS 내부 명령어 텍스트 확인 로그")
)

(defun swcad-title-open-transfer-log ()
  (swcad-title-open-log "swcad_title_transfer_preview_last.txt" "SWTITLESTATUS 내부 변환 미리보기 로그")
)

(defun swcad-title-open-multi-preview-log ()
  (swcad-title-open-log "swcad_title_multi_preview_last.txt" "SWTITLESTATUS 내부 다중 시트 요약 로그")
)

(defun swcad-title-open-multi-detail-log ()
  (swcad-title-open-log "swcad_title_multi_detail_last.txt" "SWTITLESTATUS 내부 상세 진단 로그")
)

(defun swcad-title-open-frame-scan-log ()
  (swcad-title-open-log "swcad_title_frame_scan_last.txt" "SWTITLESTATUS 내부 도면틀 스캔 로그")
)

(defun swcad-title-open-apply-log ()
  (swcad-title-open-log "swcad_title_transfer_apply_last.txt" "SWTITLECONVERT 내부 첫 native 변환 로그")
)

(defun swcad-title-apply-result (status)
  (setq *swcad-title-last-apply-status* status)
  (swcad-title-princ-line (strcat "Result: " status))
)

(defun swcad-title-open-gmtitle-verify-log ()
  (swcad-title-open-log "swcad_title_gmtitle_verify_last.txt" "SWTITLEVERIFY 내부 GMTITLE 검증 로그")
)

(defun swcad-title-open-gmtitle-verify-all-log ()
  (swcad-title-open-log "swcad_title_gmtitle_verify_all_last.txt" "SWTITLEVERIFY 내부 전체 GMTITLE 검증 로그")
)

(defun swcad-title-open-gmtitle-link-scan-log ()
  (swcad-title-open-log "swcad_title_gmtitle_link_scan_last.txt" "SWTITLEVERIFY 내부 GMTITLE link 스캔 로그")
)

(defun swcad-title-open-gmtitle-link-detail-log ()
  (swcad-title-open-log "swcad_title_gmtitle_link_detail_last.txt" "SWTITLEVERIFY 내부 GMTITLE link 상세 로그")
)

(defun swcad-title-open-gmtitle-compare-log ()
  (swcad-title-open-log "swcad_title_gmtitle_compare_last.txt" "SWTITLEVERIFY 내부 GMTITLE 비교 로그")
)

(defun swcad-title-open-gmtitle-preserve-copy-test-log ()
  (swcad-title-open-log "swcad_title_gmtitle_preserve_copy_test_last.txt" "SWTITLEVERIFY 내부 preserve-copy 테스트 로그")
)

(defun swcad-title-open-native-upgrade-log ()
  (swcad-title-open-log "swcad_title_native_upgrade_last.txt" "SWTITLECONVERT native 교체 로그")
)

(defun swcad-title-open-native-frame-check-log ()
  (swcad-title-open-log "swcad_title_native_frame_check_last.txt" "SWTITLEVERIFY 내부 native 도면틀 확인 로그")
)

(defun swcad-title-open-orphan-frame-clean-log ()
  (swcad-title-open-log "swcad_title_orphan_frame_clean_last.txt" "SWTITLEPREPARE 내부 고아 도면틀 정리 로그")
)

(defun swcad-title-open-duplicate-target-pair-clean-log ()
  (swcad-title-open-log "swcad_title_duplicate_target_pair_clean_last.txt" "SWTITLEPREPARE 내부 겹친 GMTITLE target 쌍 정리 로그")
)

(defun swcad-title-open-pick-check-log ()
  (swcad-title-open-log "swcad_title_pick_check_last.txt" "SWTITLEVERIFY 내부 선택 객체 확인 로그")
)

(defun swcad-title-open-double-click-check-log ()
  (swcad-title-open-log "swcad_title_double_click_check_last.txt" "SWTITLEVERIFY 내부 더블클릭 확인 로그")
)

(defun swcad-title-open-verify-summary-log ()
  (swcad-title-open-log "swcad_title_verify_summary_last.txt" "SWTITLEVERIFY 통합 최종 요약 로그")
)

(defun swcad-title-open-role-check-log ()
  (swcad-title-open-log "swcad_title_role_check_last.txt" "SWTITLEVERIFY 내부 role 확인 로그")
)

(defun swcad-title-open-frame-def-check-log ()
  (swcad-title-open-log "swcad_title_frame_def_check_last.txt" "SWTITLESTATUS 내부 도면틀 정의 확인 로그")
)

(defun swcad-title-open-frame-def-clean-log ()
  (swcad-title-open-log "swcad_title_frame_def_clean_last.txt" "SWTITLEPREPARE 내부 도면틀 정의 정리 로그")
)

(defun swcad-title-open-frame-def-repair-log ()
  (swcad-title-open-log "swcad_title_frame_def_repair_last.txt" "SWTITLEPREPARE 내부 도면틀 정의 복구 로그")
)

(defun swcad-title-open-frame-def-title-clean-log ()
  (swcad-title-open-log "swcad_title_frame_def_title_clean_last.txt" "SWTITLEPREPARE 내부 중첩 제목블록 정리 로그")
)

(defun swcad-title-open-frame-embedded-title-clean-log ()
  (swcad-title-open-log "swcad_title_frame_embedded_title_clean_last.txt" "SWTITLEPREPARE 내부 도면틀 내장 표제란 정리 로그")
)

(defun swcad-title-open-frame-style-normalization-clean-log ()
  (swcad-title-open-log "swcad_title_frame_style_normalization_clean_last.txt" "SWTITLEPREPARE 내부 도면틀 스타일 정규화 로그")
)

(defun swcad-title-open-a3-frame-clean-log ()
  (swcad-title-open-log "swcad_title_a3_frame_clean_last.txt" "SWTITLEPREPARE 내부 A3 내장 표제란 정리 로그")
)

(defun swcad-title-open-fast-status-log ()
  (swcad-title-open-log "swcad_title_fast_status_last.txt" "SWTITLESTATUS 내부 빠른 변환 준비 로그")
)

(defun swcad-title-open-next-step-log ()
  (swcad-title-open-log "swcad_title_next_step_last.txt" "SWTITLESTATUS 내부 다음 단계 로그")
)

(defun swcad-title-open-status-refresh-log ()
  (swcad-title-open-log "swcad_title_status_refresh_last.txt" "SWTITLESTATUS 내부 상태 요약 로그")
)

(defun swcad-title-open-structure-diagnosis-log ()
  (swcad-title-open-log "swcad_title_structure_diagnosis_last.txt" "SWTITLESTATUS 내부 구조 판단 요약 로그")
)

(defun swcad-title-open-a3a4-fix-plan-log ()
  (swcad-title-open-log "swcad_title_a3a4_fix_plan_last.txt" "SWTITLESTATUS 내부 A2/A3/A4 교체 계획 로그")
)

(defun swcad-title-close-log ()
  (if *swcad-title-debug-log-handle*
    (progn
      (close *swcad-title-debug-log-handle*)
      (setq *swcad-title-debug-log-handle* nil)
    )
  )
  (if *swcad-title-debug-log-path*
    (princ (strcat "\nSWTITLE 로그: " *swcad-title-debug-log-path*))
  )
)

(defun swcad-title-string (value)
  (cond
    ((= (type value) 'STR) value)
    ((not value) "")
    (T (vl-princ-to-string value))
  )
)

(defun swcad-title-code-value-line (prefix pair)
  (swcad-title-princ-line
    (strcat
      prefix
      " "
      (swcad-title-string (car pair))
      " = "
      (swcad-title-string (cdr pair))
    )
  )
)

(defun swcad-title-dxf-value (data code)
  (cdr (assoc code data))
)

(defun swcad-title-list-add-unique (value values)
  (if (member value values)
    values
    (append values (list value))
  )
)

(defun swcad-title-string-p (value / typ typtext)
  (setq typ (type value))
  (setq typtext (strcase (vl-princ-to-string typ)))
  (or
    (equal typ 'STR)
    (equal typ "STR")
    (equal typtext "STR")
    (equal typtext "'STR")
    (equal typ 'STRING)
    (equal typ "STRING")
    (equal typtext "STRING")
    (equal typtext "'STRING")
  )
)

(defun swcad-title-safe-string (value)
  (if (swcad-title-string-p value) value nil)
)

(defun swcad-title-number-string (value)
  (if (numberp value)
    (rtos (float value) 2 8)
    (swcad-title-string value)
  )
)

(defun swcad-title-list-string (values / result item)
  (setq result "")
  (foreach item values
    (setq result
      (if (= result "")
        (swcad-title-string item)
        (strcat result ", " (swcad-title-string item))
      )
    )
  )
  (if (= result "") "<none>" result)
)

(defun swcad-title-number-list-string (values / result item)
  (setq result "")
  (foreach item values
    (setq result
      (if (= result "")
        (swcad-title-number-string item)
        (strcat result ", " (swcad-title-number-string item))
      )
    )
  )
  (if (= result "") "<none>" result)
)

(defun swcad-title-float-in-list-p (value values / found item)
  (setq found nil)
  (if (numberp value)
    (foreach item values
      (if (and (numberp item) (equal (float value) (float item) 1e-8))
        (setq found T)
      )
    )
  )
  found
)

(defun swcad-title-list-add-unique-float (value values)
  (if (swcad-title-float-in-list-p value values)
    values
    (append values (list (float value)))
  )
)

(defun swcad-title-count-add (key counts / pair result found)
  (setq result nil)
  (setq found nil)
  (foreach pair counts
    (if (equal key (car pair))
      (progn
        (setq result (append result (list (cons key (+ (cdr pair) 1)))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if found
    result
    (append result (list (cons key 1)))
  )
)

(defun swcad-title-print-counts (title counts / pair)
  (swcad-title-princ-line title)
  (if counts
    (foreach pair counts
      (swcad-title-princ-line
        (strcat
          "  "
          (swcad-title-string (car pair))
          " x "
          (itoa (cdr pair))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
)

(defun swcad-title-point-string (point)
  (if (and (listp point) (>= (length point) 2))
    (strcat
      "("
      (swcad-title-number-string (car point))
      ", "
      (swcad-title-number-string (cadr point))
      (if (caddr point)
        (strcat ", " (swcad-title-number-string (caddr point)))
        ""
      )
      ")"
    )
    (swcad-title-string point)
  )
)

(defun swcad-title-insert-transform-string (ename / data ins sx sy sz rot)
  (setq data (if ename (entget ename) nil))
  (setq ins (swcad-title-dxf-value data 10))
  (setq sx (swcad-title-dxf-value data 41))
  (setq sy (swcad-title-dxf-value data 42))
  (setq sz (swcad-title-dxf-value data 43))
  (setq rot (swcad-title-dxf-value data 50))
  (strcat
    "insert-point="
    (swcad-title-point-string ins)
    ", scale=("
    (swcad-title-number-string (if sx sx 1.0))
    ", "
    (swcad-title-number-string (if sy sy 1.0))
    ", "
    (swcad-title-number-string (if sz sz 1.0))
    ")"
    ", rotation="
    (swcad-title-number-string (if rot rot 0.0))
  )
)

(defun swcad-title-bbox-string (bbox)
  (if (and (listp bbox) (= (length bbox) 4))
    (strcat
      "("
      (swcad-title-number-string (car bbox))
      ", "
      (swcad-title-number-string (cadr bbox))
      ") - ("
      (swcad-title-number-string (caddr bbox))
      ", "
      (swcad-title-number-string (cadddr bbox))
      ")"
    )
    "<none>"
  )
)

(defun swcad-title-bbox-lower-left-point (bbox)
  (if (and (listp bbox) (= (length bbox) 4))
    (list (car bbox) (cadr bbox) 0.0)
    nil
  )
)

(defun swcad-title-safe-getvar (name / result)
  (setq result (vl-catch-all-apply 'getvar (list name)))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swcad-title-safe-setvar (name value / result)
  (if value
    (progn
      (setq result (vl-catch-all-apply 'setvar (list name value)))
      (not (vl-catch-all-error-p result))
    )
    nil
  )
)

(defun swcad-title-restore-gmtitle-input-vars (old-osmode old-dynmode)
  (if old-osmode
    (swcad-title-safe-setvar "OSMODE" old-osmode)
  )
  (if old-dynmode
    (swcad-title-safe-setvar "DYNMODE" old-dynmode)
  )
)

(defun swcad-title-command-prompt-string (/ result)
  (setq result (vl-catch-all-apply 'getvar (list "LASTPROMPT")))
  (if (vl-catch-all-error-p result)
    ""
    (swcad-title-string result)
  )
)

(defun swcad-title-gmtitle-placement-prompt-p (prompt / upper)
  (setq upper (strcase (swcad-title-string prompt)))
  (or
    (wcmatch upper "*INSERT*POINT*")
    (wcmatch upper "*INSERTION*POINT*")
    (wcmatch upper "*삽입*지정*")
    (wcmatch upper "*삽입*점*")
    (wcmatch upper "*삽입점*")
  )
)

(defun swcad-title-gmtitle-object-move-prompt-p (prompt / upper)
  (setq upper (strcase (swcad-title-string prompt)))
  (or
    (wcmatch upper "*OBJECT*NEW*LOCATION*")
    (wcmatch upper "*OBJECT*LOCATION*")
    (wcmatch upper "*NEW*LOCATION*")
    (wcmatch upper "*OBJECT*MOVE*")
    (wcmatch upper "*객체*새*위치*")
    (wcmatch upper "*객체*위치*")
    (wcmatch upper "*새*위치*")
  )
)

(defun swcad-title-cancel-active-command (/ result count ok)
  (setq count 0)
  (setq ok nil)
  (while (and (> (getvar "CMDACTIVE") 0) (< count 3))
    (setq result (vl-catch-all-apply 'command (list "\033")))
    (if (vl-catch-all-error-p result)
      (setq result (vl-catch-all-apply 'command nil))
    )
    (if (not (vl-catch-all-error-p result))
      (setq ok T)
    )
    (setq count (+ count 1))
  )
  ok
)

(defun swcad-title-safe-bbox (ename / object result minpt maxpt minlist maxlist)
  (setq object (swcad-title-safe-vla-object ename))
  (if object
    (progn
      (setq result (vl-catch-all-apply 'vla-GetBoundingBox (list object 'minpt 'maxpt)))
      (if (vl-catch-all-error-p result)
        nil
        (progn
          (setq minlist (vlax-safearray->list minpt))
          (setq maxlist (vlax-safearray->list maxpt))
          (list (car minlist) (cadr minlist) (car maxlist) (cadr maxlist))
        )
      )
    )
    nil
  )
)

(defun swcad-title-expand-bbox (bbox margin)
  (if bbox
    (list
      (- (car bbox) margin)
      (- (cadr bbox) margin)
      (+ (caddr bbox) margin)
      (+ (cadddr bbox) margin)
    )
    nil
  )
)

(defun swcad-title-point-in-bbox-p (point bbox)
  (and
    point
    bbox
    (>= (car point) (car bbox))
    (<= (car point) (caddr bbox))
    (>= (cadr point) (cadr bbox))
    (<= (cadr point) (cadddr bbox))
  )
)

(defun swcad-title-point-in-bboxes-p (point bboxes / found bbox)
  (setq found nil)
  (foreach bbox bboxes
    (if (swcad-title-point-in-bbox-p point bbox)
      (setq found T)
    )
  )
  found
)

(defun swcad-title-safe-trans-point (point from-code to-code / result)
  (if point
    (progn
      (setq result (vl-catch-all-apply 'trans (list point from-code to-code)))
      (if (vl-catch-all-error-p result)
        nil
        result
      )
    )
    nil
  )
)

(defun swcad-title-point-in-expanded-bbox-flex-p (point bbox margin / expanded world-point)
  (setq expanded (swcad-title-expand-bbox bbox margin))
  (setq world-point (swcad-title-safe-trans-point point 1 0))
  (or
    (swcad-title-point-in-bbox-p point expanded)
    (swcad-title-point-in-bbox-p world-point expanded)
  )
)

(defun swcad-title-bbox-area (bbox)
  (if bbox
    (* (- (caddr bbox) (car bbox)) (- (cadddr bbox) (cadr bbox)))
    0.0
  )
)

(defun swcad-title-bbox-width (bbox)
  (if bbox
    (- (caddr bbox) (car bbox))
    0.0
  )
)

(defun swcad-title-bbox-height (bbox)
  (if bbox
    (- (cadddr bbox) (cadr bbox))
    0.0
  )
)

(defun swcad-title-bbox-union (a b)
  (cond
    ((not a) b)
    ((not b) a)
    (T
      (list
        (min (car a) (car b))
        (min (cadr a) (cadr b))
        (max (caddr a) (caddr b))
        (max (cadddr a) (cadddr b))
      )
    )
  )
)

(defun swcad-title-abs (value)
  (if (< value 0.0)
    (- 0.0 value)
    value
  )
)

(defun swcad-title-near-p (a b tolerance)
  (<= (swcad-title-abs (- (float a) (float b))) tolerance)
)

(defun swcad-title-native-placement-substantial-move-p (dx dy)
  (or
    (> (swcad-title-abs dx) *swcad-title-native-placement-trust-tolerance*)
    (> (swcad-title-abs dy) *swcad-title-native-placement-trust-tolerance*)
  )
)

(defun swcad-title-bbox-intersects-p (a b)
  (and
    a
    b
    (<= (car a) (caddr b))
    (>= (caddr a) (car b))
    (<= (cadr a) (cadddr b))
    (>= (cadddr a) (cadr b))
  )
)

(defun swcad-title-bbox-overlap-box (a b / left bottom right top)
  (if (and a b)
    (progn
      (setq left (max (car a) (car b)))
      (setq bottom (max (cadr a) (cadr b)))
      (setq right (min (caddr a) (caddr b)))
      (setq top (min (cadddr a) (cadddr b)))
      (if (and (> (- right left) 1.0) (> (- top bottom) 1.0))
        (list left bottom right top)
        nil
      )
    )
    nil
  )
)

(defun swcad-title-bbox-contains-bbox-p (outer inner margin)
  (and
    outer
    inner
    (<= (- (car outer) margin) (car inner))
    (<= (- (cadr outer) margin) (cadr inner))
    (>= (+ (caddr outer) margin) (caddr inner))
    (>= (+ (cadddr outer) margin) (cadddr inner))
  )
)

(defun swcad-title-bbox-nearly-same-p (a b tolerance)
  (and
    a
    b
    (swcad-title-near-p (car a) (car b) tolerance)
    (swcad-title-near-p (cadr a) (cadr b) tolerance)
    (swcad-title-near-p (caddr a) (caddr b) tolerance)
    (swcad-title-near-p (cadddr a) (cadddr b) tolerance)
  )
)

(setq *swcad-title-transfer-template*
  '(
    ("GEN-TITLE-QTY{10}" 25.75 37.50 "quantity")
    ("GEN-TITLE-MAT1{10}" 32.81333128 37.60265511 "material")
    ("GEN-TITLE-NAME{10}" 6.00361982 21.70382822 "name")
    ("GEN-TITLE-CHKM{10}" 35.81333128 21.60265511 "checked")
    ("GEN-TITLE-APPM{21.7}" 64.86238219 21.70382822 "approved")
    ("GEN-TITLE-DATE{11.7}" 93.48807325 21.53210663 "date")
    ("GEN-TITLE-SCA{6.7}" 163.48807325 21.53210663 "scale")
    ("GEN-TITLE-DWG{23}" 56.00 12.50 "drawing")
    ("GEN-TITLE-NR{23}" 56.00 2.70 "drawing-number")
    ("GEN-TITLE-REV{5}" 148.48807325 1.53210663 "revision")
    ("GEN-TITLE-SIZ{6.7}" 163.48807325 1.53210663 "sheet-size")
  )
)

(defun swcad-title-distance2 (x1 y1 x2 y2 / dx dy)
  (setq dx (- x1 x2))
  (setq dy (- y1 y2))
  (+ (* dx dx) (* dy dy))
)

(defun swcad-title-transfer-best-slot (point bbox / relx rely best bestdist dist slot)
  (setq best nil)
  (setq bestdist nil)
  (if (and point bbox)
    (progn
      (setq relx (- (car point) (car bbox)))
      (setq rely (- (cadr point) (cadr bbox)))
      (foreach slot *swcad-title-transfer-template*
        (setq dist (swcad-title-distance2 relx rely (cadr slot) (caddr slot)))
        (if (or (not bestdist) (< dist bestdist))
          (progn
            (setq best slot)
            (setq bestdist dist)
          )
        )
      )
      (if best
        (list best (sqrt bestdist) relx rely)
        nil
      )
    )
    nil
  )
)

(defun swcad-title-assoc-put (key value alist / result found pair)
  (setq result nil)
  (setq found nil)
  (foreach pair alist
    (if (equal key (car pair))
      (progn
        (setq result (append result (list (cons key value))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if found
    result
    (append result (list (cons key value)))
  )
)

(defun swcad-title-doc ()
  (vla-get-ActiveDocument (vlax-get-acad-object))
)

(defun swcad-title-modelspace ()
  (vla-get-ModelSpace (swcad-title-doc))
)

(defun swcad-title-document-read-only-p (/ doc value)
  (setq doc (swcad-title-doc))
  (setq value (swcad-title-safe-vla-get doc 'ReadOnly))
  (cond
    ((not value) nil)
    ((equal value :vlax-false) nil)
    ((equal value 0) nil)
    (T T)
  )
)

(defun swcad-title-block-exists-p (block-name)
  (if (tblsearch "BLOCK" block-name) T nil)
)

(defun swcad-title-find-block-by-pattern (pattern / item name upper result)
  (setq result nil)
  (setq item (tblnext "BLOCK" T))
  (while (and item (not result))
    (setq name (cdr (assoc 2 item)))
    (setq upper (strcase (swcad-title-string name)))
    (if (and
          name
          (/= (substr name 1 1) "*")
          (wcmatch upper pattern)
        )
      (setq result name)
    )
    (setq item (tblnext "BLOCK"))
  )
  result
)

(defun swcad-title-target-frame-block-name ()
  *swcad-title-target-frame-block-name*
)

(defun swcad-title-target-frame-block-candidates ()
  '("DR_A1_Outline" "DR_A2_Outline" "DR_A3_Outline" "DR_A4_Outline")
)

(defun swcad-title-existing-target-frame-block-name (/ result candidate)
  (setq result nil)
  (foreach candidate (swcad-title-target-frame-block-candidates)
    (if (and (not result) (> (swcad-title-count-inserts-by-effective-name candidate) 0))
      (setq result candidate)
    )
  )
  result
)

(defun swcad-title-target-title-block-name ()
  *swcad-title-target-title-block-name*
)

(defun swcad-title-vla-block-name (object / name)
  (setq name (swcad-title-safe-vla-get object 'EffectiveName))
  (if (not name)
    (setq name (swcad-title-safe-vla-get object 'Name))
  )
  (swcad-title-string name)
)

(defun swcad-title-attribute-tag (attribute / value)
  (setq value (vl-catch-all-apply 'vla-get-TagString (list attribute)))
  (if (vl-catch-all-error-p value) "" value)
)

(defun swcad-title-attribute-set-value (attribute value)
  (vl-catch-all-apply 'vla-put-TextString (list attribute (swcad-title-string value)))
)

(defun swcad-title-get-insert-attributes (insert-object / result)
  (setq result (vl-catch-all-apply 'vlax-invoke (list insert-object 'GetAttributes)))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swcad-title-set-insert-attributes (insert-object values / attrs attr tag pair count)
  (setq attrs (swcad-title-get-insert-attributes insert-object))
  (setq count 0)
  (foreach attr attrs
    (setq tag (swcad-title-attribute-tag attr))
    (setq pair (assoc tag values))
    (if pair
      (progn
        (swcad-title-attribute-set-value attr (cdr pair))
        (setq count (+ count 1))
      )
    )
  )
  (vl-catch-all-apply 'vla-Update (list insert-object))
  count
)

(defun swcad-title-delete-ename (ename / result object delete-result)
  (if ename
    (progn
      (setq result (entdel ename))
      (if result
        result
        (progn
          (setq object (swcad-title-safe-vla-object ename))
          (if object
            (progn
              (setq delete-result (vl-catch-all-apply 'vla-Delete (list object)))
              (if (vl-catch-all-error-p delete-result)
                nil
                T
              )
            )
          )
        )
      )
    )
  )
)

(defun swcad-title-delete-vla-object (object)
  (if object
    (vl-catch-all-apply 'vla-Delete (list object))
  )
)

(defun swcad-title-internal-gentitle-marker-entity-p (ename / data type text)
  (setq data (entget ename))
  (setq type (strcase (swcad-title-string (cdr (assoc 0 data)))))
  (and
    (member type '("TEXT" "MTEXT"))
    (progn
      (setq text
        (strcase
          (vl-string-trim
            " \t\r\n"
            (swcad-title-string (cdr (assoc 1 data)))
          )
        )
      )
      T
    )
    (wcmatch text "!GENTITLE-*")
  )
)

(defun swcad-title-internal-frame-marker-enames (block-name / block ename data targets guard)
  (setq block (tblobjname "BLOCK" block-name))
  (setq targets nil)
  (if block
    (progn
      (setq ename (entnext block))
      (setq guard 0)
      (while (and ename (< guard 1000))
        (setq data (entget ename))
        (if (= (strcase (swcad-title-string (cdr (assoc 0 data)))) "ENDBLK")
          (setq ename nil)
          (progn
            (if (swcad-title-internal-gentitle-marker-entity-p ename)
              (setq targets (cons ename targets))
            )
            (setq ename (entnext ename))
          )
        )
        (setq guard (+ guard 1))
      )
    )
  )
  (reverse targets)
)

(defun swcad-title-delete-internal-frame-marker-texts (block-name / targets ename result count)
  (setq targets (swcad-title-internal-frame-marker-enames block-name))
  (setq count 0)
  (foreach ename targets
    (setq result (entdel ename))
    (if result
      (setq count (+ count 1))
    )
  )
  (if (> count 0)
    (progn
      (entupd (tblobjname "BLOCK" block-name))
      (vl-catch-all-apply 'vla-Regen (list (swcad-title-doc) 1))
    )
  )
  count
)

(defun swcad-title-delete-handle (handle / ename)
  (setq ename (handent (swcad-title-string handle)))
  (swcad-title-delete-ename ename)
)

(defun swcad-title-block-text-record-p (record / handle)
  (setq handle (strcase (swcad-title-string (nth 3 record))))
  (wcmatch handle "BLOCK:*")
)

(defun swcad-title-delete-text-record (record)
  (if (swcad-title-block-text-record-p record)
    nil
    (progn
      (swcad-title-delete-handle (nth 3 record))
      T
    )
  )
)

(defun swcad-title-delete-handle-list (handles / handle count)
  (setq count 0)
  (foreach handle handles
    (if (swcad-title-delete-handle handle)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-delete-ename-list (enames / ename count)
  (setq count 0)
  (foreach ename enames
    (if (swcad-title-delete-ename ename)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-frame-cleanup-entity-type-p (etype)
  (member
    (strcase (swcad-title-string etype))
    '("LINE" "LWPOLYLINE" "POLYLINE" "2DPOLYLINE" "HATCH" "SOLID" "TRACE" "WIPEOUT")
  )
)

(defun swcad-title-sheet-size-value (values / pair)
  (setq pair (assoc "GEN-TITLE-SIZ{6.7}" values))
  (if pair
    (vl-string-trim " \t\r\n" (strcase (swcad-title-string (cdr pair))))
    ""
  )
)

(defun swcad-title-sheet-dimensions (sheet-size / value)
  (setq value (strcase (swcad-title-string sheet-size)))
  (cond
    ((wcmatch value "*A0*") '(1189.0 841.0))
    ((wcmatch value "*A1*") '(841.0 594.0))
    ((wcmatch value "*A2*") '(594.0 420.0))
    ((wcmatch value "*A3*") '(420.0 297.0))
    ((wcmatch value "*A4*") '(210.0 297.0))
    (T nil)
  )
)

(defun swcad-title-normalized-sheet-size (sheet-size / value)
  (setq value (strcase (swcad-title-string sheet-size)))
  (cond
    ((wcmatch value "*A0*") "A0")
    ((wcmatch value "*A1*") "A1")
    ((wcmatch value "*A2*") "A2")
    ((wcmatch value "*A3*") "A3")
    ((wcmatch value "*A4*") "A4")
    (T nil)
  )
)

(defun swcad-title-sheet-size-from-block-name (block-name / value)
  (setq value (strcase (swcad-title-string block-name)))
  (cond
    ((swcad-title-native-target-title-name-p value) nil)
    ((wcmatch value "*A0*,*A-0*,*A_0*,*A 0*") "A0")
    ((wcmatch value "*A1*,*A-1*,*A_1*,*A 1*") "A1")
    ((wcmatch value "*A2*,*A-2*,*A_2*,*A 2*") "A2")
    ((wcmatch value "*A3*,*A-3*,*A_3*,*A 3*") "A3")
    ((wcmatch value "*A4*,*A-4*,*A_4*,*A 4*") "A4")
    (T nil)
  )
)

(defun swcad-title-values-with-sheet-size-override (values override-size / normalized)
  (setq normalized (swcad-title-normalized-sheet-size override-size))
  (if normalized
    (swcad-title-assoc-put "GEN-TITLE-SIZ{6.7}" normalized values)
    values
  )
)

(defun swcad-title-frame-block-size-priority (block-name / block-size)
  (setq block-size (swcad-title-sheet-size-from-block-name block-name))
  (if block-size
    0
    1
  )
)

(defun swcad-title-sheet-size-from-frame-bbox (frame-bbox / width height long short candidates best best-score candidate dims dim-long dim-short score)
  (setq best nil)
  (setq best-score nil)
  (if frame-bbox
    (progn
      (setq width (swcad-title-bbox-width frame-bbox))
      (setq height (swcad-title-bbox-height frame-bbox))
      (setq long (max width height))
      (setq short (min width height))
      (setq candidates '("A1" "A2" "A3" "A4"))
      (foreach candidate candidates
        (setq dims (swcad-title-sheet-dimensions candidate))
        (if dims
          (progn
            (setq dim-long (max (car dims) (cadr dims)))
            (setq dim-short (min (car dims) (cadr dims)))
            (setq score
              (+
                (/ (swcad-title-abs (- long dim-long)) dim-long)
                (/ (swcad-title-abs (- short dim-short)) dim-short)
              )
            )
            (if (or (not best-score) (< score best-score))
              (progn
                (setq best candidate)
                (setq best-score score)
              )
            )
          )
        )
      )
      (if (and best-score (< best-score 0.12))
        best
        nil
      )
    )
    nil
  )
)

(defun swcad-title-detected-sheet-size (values frame-bbox / text-size frame-size)
  (setq text-size (swcad-title-normalized-sheet-size (swcad-title-sheet-size-value values)))
  (setq frame-size (swcad-title-sheet-size-from-frame-bbox frame-bbox))
  (cond
    (frame-size frame-size)
    (text-size text-size)
    (T nil)
  )
)

(defun swcad-title-detected-sheet-size-for-source (source-block frame-block values frame-bbox / block-size source-size)
  (setq block-size (swcad-title-sheet-size-from-block-name frame-block))
  (if block-size
    block-size
    (progn
      (setq source-size (swcad-title-sheet-size-from-block-name source-block))
      (if source-size
        source-size
        (swcad-title-detected-sheet-size values frame-bbox)
      )
    )
  )
)

(defun swcad-title-target-frame-block-name-for-sheet (sheet-size / normalized)
  (setq normalized (swcad-title-normalized-sheet-size sheet-size))
  (if (and normalized (wcmatch normalized "A1,A2,A3,A4"))
    (strcat "DR_" normalized "_Outline")
    (swcad-title-target-frame-block-name)
  )
)

(defun swcad-title-target-frame-block-name-for-transfer (values frame-bbox / detected)
  (setq detected (swcad-title-detected-sheet-size values frame-bbox))
  (swcad-title-target-frame-block-name-for-sheet detected)
)

(defun swcad-title-target-frame-block-name-for-source (source-block frame-block values frame-bbox / detected)
  (setq detected (swcad-title-detected-sheet-size-for-source source-block frame-block values frame-bbox))
  (swcad-title-target-frame-block-name-for-sheet detected)
)

(defun swcad-title-bbox-size-string (bbox)
  (if bbox
    (strcat
      (swcad-title-number-string (swcad-title-bbox-width bbox))
      " x "
      (swcad-title-number-string (swcad-title-bbox-height bbox))
    )
    "<none>"
  )
)

(defun swcad-title-target-frame-bbox-size-warning (sheet bbox / dims width height actual-long actual-short expected-long expected-short long-delta short-delta)
  (setq dims (swcad-title-sheet-dimensions sheet))
  (if (and dims bbox)
    (progn
      (setq width (swcad-title-bbox-width bbox))
      (setq height (swcad-title-bbox-height bbox))
      (setq actual-long (max width height))
      (setq actual-short (min width height))
      (setq expected-long (max (car dims) (cadr dims)))
      (setq expected-short (min (car dims) (cadr dims)))
      (setq long-delta (/ (swcad-title-abs (- actual-long expected-long)) expected-long))
      (setq short-delta (/ (swcad-title-abs (- actual-short expected-short)) expected-short))
      (if (or (> long-delta 0.08) (> short-delta 0.08))
        (strcat
          "expected approx "
          (swcad-title-number-string (car dims))
          " x "
          (swcad-title-number-string (cadr dims))
          ", got "
          (swcad-title-bbox-size-string bbox)
        )
        nil
      )
    )
    nil
  )
)

(defun swcad-title-frame-bbox-size-warning-for-block (frame-block bbox / sheet)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (swcad-title-target-frame-bbox-size-warning sheet bbox)
)

(defun swcad-title-frame-bbox-size-valid-p (frame-block bbox)
  (not (swcad-title-frame-bbox-size-warning-for-block frame-block bbox))
)

(defun swcad-title-block-definition-raw-bbox (block-name / block result item ename bbox)
  (setq block (swcad-title-block-definition-object block-name))
  (setq result nil)
  (if block
    (vlax-for item block
      (setq ename (swcad-title-vla-object->ename item))
      (if ename
        (progn
          (setq bbox (swcad-title-safe-bbox ename))
          (if bbox
            (setq result (swcad-title-bbox-union result bbox))
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-definition-raw-bbox-risk-record (frame-name / bbox sheet dims actual-area expected-area ratio warning)
  (setq bbox (swcad-title-block-definition-raw-bbox frame-name))
  (setq sheet (swcad-title-sheet-size-from-block-name frame-name))
  (setq dims (swcad-title-sheet-dimensions sheet))
  (setq warning nil)
  (if (and bbox dims)
    (progn
      (setq actual-area (max (swcad-title-bbox-area bbox) 1.0))
      (setq expected-area (max (* (car dims) (cadr dims)) 1.0))
      (setq ratio (/ actual-area expected-area))
      (if (> ratio 1.6)
        (setq warning
          (strcat
            "definition raw bbox is much larger than expected sheet; raw/expected area ratio="
            (swcad-title-number-string ratio)
            ", expected "
            (swcad-title-number-string (car dims))
            " x "
            (swcad-title-number-string (cadr dims))
            ", got "
            (swcad-title-bbox-size-string bbox)
          )
        )
      )
    )
  )
  (if warning
    (list frame-name bbox warning)
    nil
  )
)

(defun swcad-title-frame-definition-raw-bbox-risk-records (/ result frame-name record)
  (setq result nil)
  (foreach frame-name (swcad-title-frame-definition-check-candidates)
    (setq record (swcad-title-frame-definition-raw-bbox-risk-record frame-name))
    (if record
      (setq result (append result (list record)))
    )
  )
  result
)

(defun swcad-title-print-frame-definition-raw-bbox-risk-records (records / index record)
  (swcad-title-princ-line "DR 도면틀 정의 raw bbox 위험:")
  (if records
    (progn
      (setq index 1)
      (foreach record records
        (swcad-title-princ-line
          (strcat
            "  #"
            (itoa index)
            " frame-def="
            (car record)
            ", raw-bbox="
            (swcad-title-bbox-string (cadr record))
            ", 판단="
            (caddr record)
          )
        )
        (setq index (+ index 1))
      )
    )
    (swcad-title-princ-line "  <없음>")
  )
)

(defun swcad-title-transform-bbox-with-insert (bbox insert-ename / data ins sx sy rot ix iy x1 x2 y1 y2)
  (setq data (if insert-ename (entget insert-ename) nil))
  (setq ins (swcad-title-dxf-value data 10))
  (setq sx (swcad-title-dxf-value data 41))
  (setq sy (swcad-title-dxf-value data 42))
  (setq rot (swcad-title-dxf-value data 50))
  (if (and bbox ins (or (not rot) (swcad-title-near-p rot 0.0 0.000001)))
    (progn
      (setq ix (float (car ins)))
      (setq iy (float (cadr ins)))
      (setq sx (float (if sx sx 1.0)))
      (setq sy (float (if sy sy 1.0)))
      (setq x1 (+ ix (* (car bbox) sx)))
      (setq x2 (+ ix (* (caddr bbox) sx)))
      (setq y1 (+ iy (* (cadr bbox) sy)))
      (setq y2 (+ iy (* (cadddr bbox) sy)))
      (list (min x1 x2) (min y1 y2) (max x1 x2) (max y1 y2))
    )
    nil
  )
)

;;; 2D affine helpers use (a b c d tx ty):
;;;   x' = a*x + c*y + tx
;;;   y' = b*x + d*y + ty
(defun swcad-title-affine-identity ()
  '(1.0 0.0 0.0 1.0 0.0 0.0)
)

(defun swcad-title-affine-multiply (parent local / pa pb pc pd ptx pty la lb lc ld ltx lty)
  (setq pa (nth 0 parent))
  (setq pb (nth 1 parent))
  (setq pc (nth 2 parent))
  (setq pd (nth 3 parent))
  (setq ptx (nth 4 parent))
  (setq pty (nth 5 parent))
  (setq la (nth 0 local))
  (setq lb (nth 1 local))
  (setq lc (nth 2 local))
  (setq ld (nth 3 local))
  (setq ltx (nth 4 local))
  (setq lty (nth 5 local))
  (list
    (+ (* pa la) (* pc lb))
    (+ (* pb la) (* pd lb))
    (+ (* pa lc) (* pc ld))
    (+ (* pb lc) (* pd ld))
    (+ (* pa ltx) (* pc lty) ptx)
    (+ (* pb ltx) (* pd lty) pty)
  )
)

(defun swcad-title-affine-inverse (matrix / a b c d tx ty det)
  (setq a (nth 0 matrix))
  (setq b (nth 1 matrix))
  (setq c (nth 2 matrix))
  (setq d (nth 3 matrix))
  (setq tx (nth 4 matrix))
  (setq ty (nth 5 matrix))
  (setq det (- (* a d) (* b c)))
  (if (> (swcad-title-abs det) 0.000000001)
    (list
      (/ d det)
      (/ (- 0.0 b) det)
      (/ (- 0.0 c) det)
      (/ a det)
      (/ (- (* c ty) (* d tx)) det)
      (/ (- (* b tx) (* a ty)) det)
    )
    nil
  )
)

(defun swcad-title-affine-transform-point (matrix point / x y)
  (if (and matrix point)
    (progn
      (setq x (float (car point)))
      (setq y (float (cadr point)))
      (list
        (+ (* (nth 0 matrix) x) (* (nth 2 matrix) y) (nth 4 matrix))
        (+ (* (nth 1 matrix) x) (* (nth 3 matrix) y) (nth 5 matrix))
        (if (caddr point) (caddr point) 0.0)
      )
    )
    nil
  )
)

(defun swcad-title-affine-transform-bbox (matrix bbox / p1 p2 p3 p4 xs ys)
  (if (and matrix bbox)
    (progn
      (setq p1 (swcad-title-affine-transform-point matrix (list (car bbox) (cadr bbox) 0.0)))
      (setq p2 (swcad-title-affine-transform-point matrix (list (caddr bbox) (cadr bbox) 0.0)))
      (setq p3 (swcad-title-affine-transform-point matrix (list (caddr bbox) (cadddr bbox) 0.0)))
      (setq p4 (swcad-title-affine-transform-point matrix (list (car bbox) (cadddr bbox) 0.0)))
      (setq xs (list (car p1) (car p2) (car p3) (car p4)))
      (setq ys (list (cadr p1) (cadr p2) (cadr p3) (cadr p4)))
      (list (apply 'min xs) (apply 'min ys) (apply 'max xs) (apply 'max ys))
    )
    nil
  )
)

(defun swcad-title-block-definition-base-point (block-name / data point)
  (setq data (swcad-title-block-definition-header-data block-name))
  (setq point (swcad-title-dxf-value data 10))
  (if point point '(0.0 0.0 0.0))
)

(defun swcad-title-insert-affine-matrix (insert-ename / data name base ins sx sy rot cosine sine a b c d bx by)
  (setq data (if insert-ename (entget insert-ename '("*")) nil))
  (setq name (if insert-ename (swcad-title-effective-insert-name insert-ename) ""))
  (setq base (swcad-title-block-definition-base-point name))
  (setq ins (swcad-title-dxf-value data 10))
  (setq sx (float (if (swcad-title-dxf-value data 41) (swcad-title-dxf-value data 41) 1.0)))
  (setq sy (float (if (swcad-title-dxf-value data 42) (swcad-title-dxf-value data 42) 1.0)))
  (setq rot (float (if (swcad-title-dxf-value data 50) (swcad-title-dxf-value data 50) 0.0)))
  (if (and data ins)
    (progn
      (setq cosine (cos rot))
      (setq sine (sin rot))
      (setq a (* cosine sx))
      (setq b (* sine sx))
      (setq c (* (- 0.0 sine) sy))
      (setq d (* cosine sy))
      (setq bx (float (car base)))
      (setq by (float (cadr base)))
      (list
        a b c d
        (- (float (car ins)) (* a bx) (* c by))
        (- (float (cadr ins)) (* b bx) (* d by))
      )
    )
    nil
  )
)

(defun swcad-title-frame-block-main-outline-bbox (frame-block / sheet block result best-area item ename bbox area)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (setq block (swcad-title-block-definition-object frame-block))
  (setq result nil)
  (setq best-area 0.0)
  (if (and sheet block)
    (vlax-for item block
      (setq ename (swcad-title-vla-object->ename item))
      (if (and ename (equal (swcad-title-entity-type-name ename) "INSERT"))
        (progn
          (setq bbox (swcad-title-safe-bbox ename))
          (if (not (swcad-title-target-frame-bbox-size-warning sheet bbox))
            (progn
              (setq area (swcad-title-bbox-area bbox))
              (if (> area best-area)
                (progn
                  (setq result bbox)
                  (setq best-area area)
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-reference-expected-sheet-bbox (frame-ename frame-block / sheet dims)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (setq dims (swcad-title-sheet-dimensions sheet))
  (if dims
    (swcad-title-transform-bbox-with-insert
      (list 0.0 0.0 (car dims) (cadr dims))
      frame-ename
    )
    nil
  )
)

(defun swcad-title-frame-reference-effective-bbox (frame-ename frame-block / raw raw-warning main transformed expected)
  (setq raw (swcad-title-safe-bbox frame-ename))
  (setq raw-warning (swcad-title-frame-bbox-size-warning-for-block frame-block raw))
  (setq main (swcad-title-frame-block-main-outline-bbox frame-block))
  (setq transformed (swcad-title-transform-bbox-with-insert main frame-ename))
  (setq expected
    (if raw-warning
      (swcad-title-frame-reference-expected-sheet-bbox frame-ename frame-block)
      nil
    )
  )
  (cond
    ((and transformed (not (swcad-title-frame-bbox-size-warning-for-block frame-block transformed)))
      transformed
    )
    ((and expected (not (swcad-title-frame-bbox-size-warning-for-block frame-block expected)))
      expected
    )
    (T raw)
  )
)

(defun swcad-title-target-frame-bbox-size-warning-records (frame-records / result index record frame-block frame-handle frame-bbox sheet warning)
  (setq result nil)
  (setq index 1)
  (foreach record frame-records
    (setq frame-block (cadr record))
    (setq frame-handle (caddr record))
    (setq frame-bbox (cadddr record))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (setq warning (swcad-title-target-frame-bbox-size-warning sheet frame-bbox))
    (if warning
      (setq result (append result (list (list index frame-block frame-handle sheet warning frame-bbox))))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-target-frame-geometry-warning-count (frame-records)
  (length (swcad-title-target-frame-bbox-size-warning-records frame-records))
)

(defun swcad-title-target-frame-overlap-warning-count (frame-records)
  (length (swcad-title-target-frame-overlap-records frame-records))
)

(defun swcad-title-target-frame-raw-selection-warning-records (frame-records / result index record frame-ename frame-block frame-handle sheet effective-bbox raw-bbox effective-area raw-area ratio warning)
  (setq result nil)
  (setq index 1)
  (foreach record frame-records
    (setq frame-ename (car record))
    (setq frame-block (cadr record))
    (setq frame-handle (caddr record))
    (setq effective-bbox (cadddr record))
    (setq raw-bbox (swcad-title-safe-bbox frame-ename))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (setq warning nil)
    (if (and raw-bbox effective-bbox)
      (progn
        (setq effective-area (max (swcad-title-bbox-area effective-bbox) 1.0))
        (setq raw-area (swcad-title-bbox-area raw-bbox))
        (setq ratio (/ raw-area effective-area))
        (if (> ratio 1.6)
          (setq warning
            (strcat
              "raw CAD selection bbox is larger than the effective visible frame; using effective bbox for title pairing; raw/effective area ratio="
              (swcad-title-number-string ratio)
            )
          )
        )
      )
    )
    (if warning
      (setq result
        (append
          result
          (list (list index frame-block frame-handle sheet warning raw-bbox effective-bbox))
        )
      )
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-target-frame-raw-selection-warning-count (frame-records)
  (length (swcad-title-target-frame-raw-selection-warning-records frame-records))
)

(defun swcad-title-frame-reference-raw-selection-warning (frame-ename frame-block effective-bbox / raw-bbox effective-area raw-area ratio)
  (setq raw-bbox (swcad-title-safe-bbox frame-ename))
  (if (and raw-bbox effective-bbox)
    (progn
      (setq effective-area (max (swcad-title-bbox-area effective-bbox) 1.0))
      (setq raw-area (swcad-title-bbox-area raw-bbox))
      (setq ratio (/ raw-area effective-area))
      (if (> ratio 1.6)
        (strcat
          "raw CAD selection bbox is larger than the effective visible frame; raw/effective area ratio="
          (swcad-title-number-string ratio)
          ", block="
          (swcad-title-string frame-block)
          ", raw-bbox="
          (swcad-title-bbox-string raw-bbox)
          ", effective-bbox="
          (swcad-title-bbox-string effective-bbox)
        )
        nil
      )
    )
    nil
  )
)

(defun swcad-title-target-frame-overlap-records (frame-records / result total i j first second overlap)
  (setq result nil)
  (setq total (length frame-records))
  (setq i 0)
  (while (< i total)
    (setq first (nth i frame-records))
    (setq j (+ i 1))
    (while (< j total)
      (setq second (nth j frame-records))
      (setq overlap (swcad-title-bbox-overlap-box (cadddr first) (cadddr second)))
      (if overlap
        (setq result
          (append
            result
            (list
              (list
                (+ i 1)
                (cadr first)
                (caddr first)
                (+ j 1)
                (cadr second)
                (caddr second)
                overlap
              )
            )
          )
        )
      )
      (setq j (+ j 1))
    )
    (setq i (+ i 1))
  )
  result
)

(defun swcad-title-print-target-frame-selection-diagnostics (frame-records / size-records raw-records overlap-records record overlap risk-count)
  (setq size-records (swcad-title-target-frame-bbox-size-warning-records frame-records))
  (setq raw-records (swcad-title-target-frame-raw-selection-warning-records frame-records))
  (setq overlap-records (swcad-title-target-frame-overlap-records frame-records))
  (setq risk-count (length overlap-records))
  (swcad-title-princ-line "대상 도면틀 bbox 크기 경고:")
  (if size-records
    (foreach record size-records
      (swcad-title-princ-line
        (strcat
          "  #"
          (itoa (car record))
          " "
          (cadr record)
          "/"
          (caddr record)
          ", 용지="
          (if (nth 3 record) (nth 3 record) "<알수없음>")
          ": "
          (nth 4 record)
          ", 범위="
          (swcad-title-bbox-string (nth 5 record))
        )
      )
    )
    (swcad-title-princ-line "  <없음>")
  )
  (swcad-title-princ-line "대상 도면틀 실제 선택 bbox 참고:")
  (if raw-records
    (foreach record raw-records
      (swcad-title-princ-line
        (strcat
          "  #"
          (itoa (car record))
          " "
          (cadr record)
          "/"
          (caddr record)
          ", 용지="
          (if (nth 3 record) (nth 3 record) "<알수없음>")
          ": "
          (nth 4 record)
          ", 실제선택범위="
          (swcad-title-bbox-string (nth 5 record))
          ", 보이는범위="
          (swcad-title-bbox-string (nth 6 record))
        )
      )
    )
    (swcad-title-princ-line "  <없음>")
  )
  (swcad-title-princ-line "대상 도면틀 bbox 겹침/선택 위험:")
  (if overlap-records
    (foreach record overlap-records
      (setq overlap (nth 6 record))
      (swcad-title-princ-line
        (strcat
          "  #"
          (itoa (car record))
          " "
          (cadr record)
          "/"
          (caddr record)
          " 이 #"
          (itoa (nth 3 record))
          " "
          (nth 4 record)
          "/"
          (nth 5 record)
          " 와 겹침, 겹친범위="
          (swcad-title-bbox-string overlap)
          ", 겹친크기="
          (swcad-title-bbox-size-string overlap)
        )
      )
    )
    (swcad-title-princ-line "  <없음>")
  )
  (if (> risk-count 0)
    (swcad-title-princ-line "참고: GMPOWEREDIT에서 다음/확인 또는 REFEDIT가 보이면, 커서가 제목블록이 아니라 너무 크거나 겹친 도면틀/block bbox를 잡고 있을 수 있습니다.")
  )
  risk-count
)

(defun swcad-title-inferred-source-frame-bbox (source-bbox values / dims width height frame-max-x frame-min-y)
  (setq dims (swcad-title-sheet-dimensions (swcad-title-sheet-size-value values)))
  (if (and source-bbox dims)
    (progn
      (setq width (car dims))
      (setq height (cadr dims))
      (setq frame-max-x (+ (caddr source-bbox) 10.0))
      (setq frame-min-y (- (cadr source-bbox) 10.0))
      (list
        (- frame-max-x width)
        frame-min-y
        frame-max-x
        (+ frame-min-y height)
      )
    )
    nil
  )
)

(defun swcad-title-effective-source-frame-bbox (source-bbox source-frame-bbox values override-size / overridden-values inferred)
  (if source-frame-bbox
    source-frame-bbox
    (if override-size
      (progn
        (setq overridden-values (swcad-title-values-with-sheet-size-override values override-size))
        (setq inferred (swcad-title-inferred-source-frame-bbox source-bbox overridden-values))
        (if inferred inferred source-frame-bbox)
      )
      (swcad-title-inferred-source-frame-bbox source-bbox values)
    )
  )
)

(defun swcad-title-source-block-sheet-size (source-block frame-block / frame-size source-size)
  (setq frame-size (swcad-title-sheet-size-from-block-name frame-block))
  (if frame-size
    frame-size
    (progn
      (setq source-size (swcad-title-sheet-size-from-block-name source-block))
      source-size
    )
  )
)

(defun swcad-title-source-title-graphic-handles (source-bbox / ss index total ename data etype bbox handle result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "LINE,LWPOLYLINE,POLYLINE,2DPOLYLINE,HATCH,SOLID,TRACE,WIPEOUT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq etype (swcad-title-dxf-value data 0))
    (setq bbox (swcad-title-safe-bbox ename))
    (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
    (if
      (and
        (> (strlen handle) 0)
        (swcad-title-frame-cleanup-entity-type-p etype)
        (swcad-title-bbox-intersects-p bbox (swcad-title-expand-bbox source-bbox 1.0))
      )
      (setq result (swcad-title-list-add-unique handle result))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-title-shell-label-text-p (raw-text / upper)
  (setq upper
    (strcase
      (vl-string-trim " \t\r\n" (swcad-title-string raw-text))
    )
  )
  (or
    (wcmatch upper "*DESIGNED*BY*")
    (wcmatch upper "*CHECKED*BY*")
    (wcmatch upper "*APPROVED*BY*")
    (wcmatch upper "*ARTICLE*REFERENCE*")
    (wcmatch upper "*TITLE*NAME*")
    (wcmatch upper "*ITEM*REF*")
    (wcmatch upper "*FILE*NO*")
    (wcmatch upper "*FILE*NAME*")
    (wcmatch upper "*MATERIAL*")
    (wcmatch upper "*SCALE*")
    (wcmatch upper "*SHEET*")
    (wcmatch upper "*DATE*")
  )
)

(defun swcad-title-title-shell-label-count (insert-ename bbox / records count seen record raw key)
  (setq records (swcad-title-block-text-records insert-ename bbox))
  (setq count 0)
  (setq seen nil)
  (foreach record records
    (setq raw (vl-string-trim " \t\r\n" (swcad-title-string (nth 6 record))))
    (setq key (strcase raw))
    (if
      (and
        (swcad-title-title-shell-label-text-p raw)
        (not (member key seen))
      )
      (progn
        (setq seen (append seen (list key)))
        (setq count (+ count 1))
      )
    )
  )
  count
)

(defun swcad-title-title-shell-name-evidence-p (name / upper)
  (setq upper (strcase (swcad-title-string name)))
  (or
    (swcad-title-title-block-name-p name)
    (wcmatch upper "*표제란*")
    (wcmatch upper "*TITLE*BLOCK*")
  )
)

(defun swcad-title-title-shell-insert-candidates (/ ss index total ename name bbox bbox-area result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq name (swcad-title-effective-insert-name ename))
    (if
      (and
        (not (swcad-title-native-target-title-name-p name))
        (not (swcad-title-native-target-frame-name-p name))
      )
      (progn
        (setq bbox (swcad-title-safe-bbox ename))
        (setq bbox-area (swcad-title-bbox-area bbox))
        (if (and bbox (> bbox-area 10.0))
          (setq result (append result (list (list ename name bbox bbox-area))))
        )
      )
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-source-title-shell-records-from-candidates (source-bbox source-ename source-frame-ename candidates / candidate ename name bbox expanded overlap source-area bbox-area overlap-area bbox-overlap-ratio source-overlap-ratio width-ratio height-ratio label-count name-evidence handle result geometry-match)
  (setq result nil)
  (setq source-area (swcad-title-bbox-area source-bbox))
  (setq expanded (if source-bbox (swcad-title-expand-bbox source-bbox 1.0) nil))
  (foreach candidate candidates
    (setq ename (car candidate))
    (if
      (and
        (not (eq ename source-ename))
        (not (eq ename source-frame-ename))
      )
      (progn
        (setq name (cadr candidate))
        (setq bbox (caddr candidate))
        (setq bbox-area (nth 3 candidate))
        (setq overlap (swcad-title-bbox-overlap-box bbox expanded))
        (setq overlap-area (swcad-title-bbox-area overlap))
        (setq bbox-overlap-ratio
          (if (> bbox-area 0.01) (/ overlap-area bbox-area) 0.0)
        )
        (setq source-overlap-ratio
          (if (> source-area 0.01) (/ overlap-area source-area) 0.0)
        )
        (setq width-ratio
          (if (> (swcad-title-bbox-width source-bbox) 0.01)
            (/ (swcad-title-bbox-width bbox) (swcad-title-bbox-width source-bbox))
            0.0
          )
        )
        (setq height-ratio
          (if (> (swcad-title-bbox-height source-bbox) 0.01)
            (/ (swcad-title-bbox-height bbox) (swcad-title-bbox-height source-bbox))
            0.0
          )
        )
        (setq geometry-match
          (and
            bbox
            (> bbox-area 10.0)
            (> source-area 10.0)
            (>= bbox-overlap-ratio 0.70)
            (>= source-overlap-ratio 0.25)
            (>= width-ratio 0.55)
            (>= height-ratio 0.40)
            (<= bbox-area (* source-area 1.75))
          )
        )
        (if geometry-match
          (progn
            (setq name-evidence (swcad-title-title-shell-name-evidence-p name))
            (setq label-count
              (if name-evidence
                0
                (swcad-title-title-shell-label-count ename source-bbox)
              )
            )
            (if (or name-evidence (>= label-count 3))
              (progn
                (setq handle (swcad-title-ename-handle ename))
                (setq result
                  (append
                    result
                    (list
                      (list
                        ename handle name bbox overlap
                        bbox-overlap-ratio source-overlap-ratio
                        label-count (if name-evidence T nil)
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-source-title-shell-records (source-bbox source-ename source-frame-ename)
  (swcad-title-source-title-shell-records-from-candidates
    source-bbox
    source-ename
    source-frame-ename
    (swcad-title-title-shell-insert-candidates)
  )
)

(defun swcad-title-source-title-shell-handles (source-bbox source-ename source-frame-ename / records result record)
  (setq records
    (swcad-title-source-title-shell-records
      source-bbox
      source-ename
      source-frame-ename
    )
  )
  (setq result nil)
  (foreach record records
    (setq result (swcad-title-list-add-unique (cadr record) result))
  )
  result
)

(defun swcad-title-target-title-shell-records (/ pairs candidates result seen pair records record handle)
  (setq pairs (swcad-title-target-gmtitle-pair-records))
  (setq candidates (swcad-title-title-shell-insert-candidates))
  (setq result nil)
  (setq seen nil)
  (foreach pair pairs
    (setq records
      (swcad-title-source-title-shell-records-from-candidates
        (nth 3 pair)
        (car pair)
        (cadr pair)
        candidates
      )
    )
    (foreach record records
      (setq handle (cadr record))
      (if (not (member handle seen))
        (progn
          (setq seen (append seen (list handle)))
          (setq result (append result (list record)))
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-edge-graphic-p (bbox frame-bbox / tolerance frame-width frame-height width height near-left near-right near-bottom near-top full-box long-horizontal long-vertical)
  (if (and bbox frame-bbox)
    (progn
      (setq tolerance 2.5)
      (setq frame-width (swcad-title-bbox-width frame-bbox))
      (setq frame-height (swcad-title-bbox-height frame-bbox))
      (setq width (swcad-title-bbox-width bbox))
      (setq height (swcad-title-bbox-height bbox))
      (setq near-left (and (swcad-title-near-p (car bbox) (car frame-bbox) tolerance) (swcad-title-near-p (caddr bbox) (car frame-bbox) tolerance)))
      (setq near-right (and (swcad-title-near-p (car bbox) (caddr frame-bbox) tolerance) (swcad-title-near-p (caddr bbox) (caddr frame-bbox) tolerance)))
      (setq near-bottom (and (swcad-title-near-p (cadr bbox) (cadr frame-bbox) tolerance) (swcad-title-near-p (cadddr bbox) (cadr frame-bbox) tolerance)))
      (setq near-top (and (swcad-title-near-p (cadr bbox) (cadddr frame-bbox) tolerance) (swcad-title-near-p (cadddr bbox) (cadddr frame-bbox) tolerance)))
      (setq full-box
        (and
          (swcad-title-near-p (car bbox) (car frame-bbox) tolerance)
          (swcad-title-near-p (cadr bbox) (cadr frame-bbox) tolerance)
          (swcad-title-near-p (caddr bbox) (caddr frame-bbox) tolerance)
          (swcad-title-near-p (cadddr bbox) (cadddr frame-bbox) tolerance)
        )
      )
      (setq long-horizontal (>= width (* frame-width 0.25)))
      (setq long-vertical (>= height (* frame-height 0.25)))
      (and
        (swcad-title-bbox-contains-bbox-p (swcad-title-expand-bbox frame-bbox tolerance) bbox 0.0)
        (or
          full-box
          (and long-horizontal (or near-bottom near-top))
          (and long-vertical (or near-left near-right))
        )
      )
    )
    nil
  )
)

(defun swcad-title-source-frame-graphic-handles (frame-bbox source-bbox / ss index total ename data etype bbox handle result)
  (setq result nil)
  (if frame-bbox
    (progn
      (setq ss (ssget "_X" '((0 . "LINE,LWPOLYLINE,POLYLINE,2DPOLYLINE,HATCH,SOLID,TRACE,WIPEOUT"))))
      (setq total (if ss (sslength ss) 0))
      (setq index 0)
      (while (< index total)
        (setq ename (ssname ss index))
        (setq data (entget ename '("*")))
        (setq etype (swcad-title-dxf-value data 0))
        (setq bbox (swcad-title-safe-bbox ename))
        (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
        (if
          (and
            (> (strlen handle) 0)
            (swcad-title-frame-cleanup-entity-type-p etype)
            (not (swcad-title-bbox-intersects-p bbox (swcad-title-expand-bbox source-bbox 1.0)))
            (swcad-title-frame-edge-graphic-p bbox frame-bbox)
          )
          (setq result (swcad-title-list-add-unique handle result))
        )
        (setq index (+ index 1))
      )
    )
  )
  result
)

(defun swcad-title-relative-bbox (frame-bbox left bottom right top / width height)
  (if frame-bbox
    (progn
      (setq width (swcad-title-bbox-width frame-bbox))
      (setq height (swcad-title-bbox-height frame-bbox))
      (list
        (+ (car frame-bbox) (* width left))
        (+ (cadr frame-bbox) (* height bottom))
        (+ (car frame-bbox) (* width right))
        (+ (cadr frame-bbox) (* height top))
      )
    )
    nil
  )
)

(defun swcad-title-source-sheet-residue-regions (frame-bbox)
  (if frame-bbox
    (list
      ;; Keep this small: a wide lower-left region can catch real drawing notes.
      (list "bottom-left logo" (swcad-title-relative-bbox frame-bbox 0.00 0.00 0.08 0.08))
      (list "upper sheet-format residue" (swcad-title-relative-bbox frame-bbox 0.00 0.82 0.82 1.04))
      (list "upper-right residual block" (swcad-title-relative-bbox frame-bbox 0.70 0.74 1.08 1.02))
    )
    nil
  )
)

(defun swcad-title-source-sheet-residue-type-p (etype)
  (wcmatch
    (strcase (swcad-title-string etype))
    "LINE,LWPOLYLINE,POLYLINE,2DPOLYLINE,HATCH,SOLID,TRACE,WIPEOUT,CIRCLE,ARC,ELLIPSE,SPLINE"
  )
)

(defun swcad-title-upper-sheet-residue-type-p (etype)
  (wcmatch
    (strcase (swcad-title-string etype))
    "INSERT"
  )
)

(defun swcad-title-source-sheet-residue-record-type-p (region-name etype / upper-region)
  (setq upper-region (strcase (swcad-title-string region-name)))
  (cond
    ((equal upper-region "BOTTOM-LEFT LOGO")
      (swcad-title-source-sheet-residue-type-p etype)
    )
    ((wcmatch upper-region "UPPER*")
      (swcad-title-upper-sheet-residue-type-p etype)
    )
    (T nil)
  )
)

(defun swcad-title-upper-sheet-format-residue-block-p (region-name block bbox / upper-region upper-block width height short-side long-side ratio)
  (setq upper-region (strcase (swcad-title-string region-name)))
  (setq upper-block (strcase (swcad-title-string block)))
  (cond
    ((wcmatch upper-block "*SHEET_FORMAT*,*SHEETFORMAT*")
      T
    )
    ((and
       (equal upper-region "UPPER-RIGHT RESIDUAL BLOCK")
       (wcmatch upper-block "*SW_NOTE*,*_SW_NOTE_*")
       bbox
     )
      (setq width (swcad-title-bbox-width bbox))
      (setq height (swcad-title-bbox-height bbox))
      (setq short-side (max (min width height) 0.0001))
      (setq long-side (max width height))
      (setq ratio (/ long-side short-side))
      ;; Small square SW_NOTE inserts are often real balloons/item notes, not sheet residue.
      (or (> ratio 3.0) (> width 35.0) (< height 4.0))
    )
    (T nil)
  )
)

(defun swcad-title-source-sheet-residue-block-p (region-name etype block bbox / upper-region upper-type upper-block)
  (setq upper-region (strcase (swcad-title-string region-name)))
  (setq upper-type (strcase (swcad-title-string etype)))
  (setq upper-block (strcase (swcad-title-string block)))
  (cond
    ((equal upper-region "BOTTOM-LEFT LOGO")
      (or
        (not (equal upper-type "INSERT"))
        (wcmatch upper-block "*LOGO*,*SW_LOGO*,*SHEET*")
      )
    )
    ((wcmatch upper-region "UPPER*")
      (and
        (equal upper-type "INSERT")
        (swcad-title-upper-sheet-format-residue-block-p upper-region upper-block bbox)
      )
    )
    (T nil)
  )
)

(defun swcad-title-region-containing-bbox (bbox regions / found region)
  (setq found nil)
  (foreach region regions
    (if (and
          (not found)
          (swcad-title-bbox-contains-bbox-p (cadr region) bbox 1.5)
        )
      (setq found region)
    )
  )
  found
)

(defun swcad-title-entity-handle (ename / data)
  (setq data (entget ename '("*")))
  (swcad-title-string (swcad-title-dxf-value data 5))
)

(defun swcad-title-ename-list-has-ename-p (ename enames / found item)
  (setq found nil)
  (foreach item enames
    (if (eq ename item)
      (setq found T)
    )
  )
  found
)

(defun swcad-title-source-sheet-residue-records (frame-bbox source-ename source-frame-ename / regions excluded ss index total ename data etype bbox handle region block layer result)
  (setq result nil)
  (setq regions (swcad-title-source-sheet-residue-regions frame-bbox))
  (setq excluded nil)
  (if source-ename
    (setq excluded (append excluded (list source-ename)))
  )
  (if source-frame-ename
    (setq excluded (append excluded (list source-frame-ename)))
  )
  (if regions
    (progn
      (setq ss (ssget "_X" '((0 . "INSERT,LINE,LWPOLYLINE,POLYLINE,2DPOLYLINE,HATCH,SOLID,TRACE,WIPEOUT,CIRCLE,ARC,ELLIPSE,SPLINE,TEXT,MTEXT"))))
      (setq total (if ss (sslength ss) 0))
      (setq index 0)
      (while (< index total)
        (setq ename (ssname ss index))
        (setq data (entget ename '("*")))
        (setq etype (swcad-title-dxf-value data 0))
        (setq bbox (swcad-title-safe-bbox ename))
        (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
        (setq region (swcad-title-region-containing-bbox bbox regions))
        (if
          (and
            (> (strlen handle) 0)
            (not (swcad-title-ename-list-has-ename-p ename excluded))
            region
            (swcad-title-source-sheet-residue-record-type-p (car region) etype)
          )
          (progn
            (setq block (if (= (strcase (swcad-title-string etype)) "INSERT") (swcad-title-effective-insert-name ename) ""))
            (setq layer (swcad-title-string (swcad-title-dxf-value data 8)))
            (if
              (and
                (not (swcad-title-native-target-title-name-p block))
                (not (swcad-title-native-target-frame-name-p block))
                (swcad-title-source-sheet-residue-block-p (car region) etype block bbox)
              )
              (setq result
                (append
                  result
                  (list (list handle (car region) etype layer block bbox))
                )
              )
            )
          )
        )
        (setq index (+ index 1))
      )
    )
  )
  result
)

(defun swcad-title-residue-record-handles (records / result record)
  (setq result nil)
  (foreach record records
    (setq result (swcad-title-list-add-unique (car record) result))
  )
  result
)

(defun swcad-title-print-residue-records (label records / record block)
  (swcad-title-princ-line label)
  (if records
    (foreach record records
      (setq block (nth 4 record))
      (swcad-title-princ-line
        (strcat
          "  - handle="
          (swcad-title-string (car record))
          ", region="
          (swcad-title-string (cadr record))
          ", type="
          (swcad-title-string (caddr record))
          ", layer="
          (swcad-title-string (cadddr record))
          (if (> (strlen (swcad-title-string block)) 0)
            (strcat ", block=" (swcad-title-string block))
            ""
          )
          ", bbox="
          (swcad-title-bbox-string (nth 5 record))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
)

(defun swcad-title-date-digits (text / raw digits index len ch code valid year month day)
  (setq raw (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq digits "")
  (setq index 1)
  (setq len (strlen raw))
  (setq valid (> len 0))
  (while (and valid (<= index len))
    (setq ch (substr raw index 1))
    (setq code (ascii ch))
    (cond
      ((and (>= code 48) (<= code 57))
        (setq digits (strcat digits ch))
      )
      ((member ch '("-" "." "/" " " "\t")) nil)
      (T (setq valid nil))
    )
    (setq index (+ index 1))
  )
  (if (and valid (= (strlen digits) 8))
    (progn
      (setq year (atoi (substr digits 1 4)))
      (setq month (atoi (substr digits 5 2)))
      (setq day (atoi (substr digits 7 2)))
      (if
        (and
          (>= year 1900)
          (<= year 2199)
          (>= month 1)
          (<= month 12)
          (>= day 1)
          (<= day 31)
        )
        digits
        nil
      )
    )
    nil
  )
)

(defun swcad-title-combined-approval-date-split (text / raw index len left right result)
  (setq raw (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq index 1)
  (setq len (strlen raw))
  (setq result nil)
  (while (and (not result) (<= index len))
    (if (= (substr raw index 1) "/")
      (progn
        (setq left (vl-string-trim " \t\r\n" (substr raw 1 (- index 1))))
        (setq right (vl-string-trim " \t\r\n" (substr raw (+ index 1))))
        (if
          (and
            (> (strlen left) 0)
            (swcad-title-date-digits right)
          )
          (setq result (list left right))
        )
      )
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-normalize-combined-approval-date-values (values / approved-pair date-pair split approval-date-digits date-digits)
  (setq approved-pair (assoc "GEN-TITLE-APPM{21.7}" values))
  (setq date-pair (assoc "GEN-TITLE-DATE{11.7}" values))
  (setq split
    (if approved-pair
      (swcad-title-combined-approval-date-split (cdr approved-pair))
      nil
    )
  )
  (setq approval-date-digits (if split (swcad-title-date-digits (cadr split)) nil))
  (setq date-digits (if date-pair (swcad-title-date-digits (cdr date-pair)) nil))
  (if
    (and
      split
      approval-date-digits
      date-digits
      (equal approval-date-digits date-digits)
    )
    (swcad-title-assoc-put "GEN-TITLE-APPM{21.7}" (car split) values)
    values
  )
)

(defun swcad-title-transfer-values (mappings / result pair preview)
  (setq result nil)
  (foreach pair mappings
    (setq preview (cdr pair))
    (setq result
      (swcad-title-assoc-put
        (car pair)
        (nth 2 preview)
        result
      )
    )
  )
  (swcad-title-normalize-combined-approval-date-values result)
)

(defun swcad-title-values-fill-missing-template-empty (values / result slot tag)
  (setq result values)
  (foreach slot *swcad-title-transfer-template*
    (setq tag (car slot))
    (if (not (assoc tag result))
      (setq result (append result (list (cons tag ""))))
    )
  )
  result
)

(defun swcad-title-record-list-remove-handle (records handle / result record)
  (setq result nil)
  (foreach record records
    (if (/= (strcase (swcad-title-string (nth 3 record))) (strcase (swcad-title-string handle)))
      (setq result (append result (list record)))
    )
  )
  result
)

(defun swcad-title-loose-title-date-record (records / matches record)
  (setq matches nil)
  (foreach record records
    (if (swcad-title-date-text-candidate-p (nth 6 record))
      (setq matches (append matches (list record)))
    )
  )
  (if (= (length matches) 1)
    (car matches)
    nil
  )
)

(defun swcad-title-semantic-mapping-preview (tag label record bbox / point relx rely)
  (setq point (nth 5 record))
  (setq relx (if (and point bbox) (- (car point) (car bbox)) 0.0))
  (setq rely (if (and point bbox) (- (cadr point) (cadr bbox)) 0.0))
  (list tag label (nth 6 record) (nth 3 record) point 0.0 relx rely record)
)

(defun swcad-title-transfer-build-mappings (source-bbox source-ename maxdist / records mappings unmapped duplicates record preview tag existing duplicate-count unmapped-count mapped-count date-record)
  (setq records (swcad-title-transfer-text-records source-bbox source-ename))
  (setq mappings nil)
  (setq unmapped nil)
  (setq duplicates nil)
  (setq mapped-count 0)
  (setq duplicate-count 0)
  (setq unmapped-count 0)
  (foreach record records
    (setq preview (swcad-title-transfer-preview-record record source-bbox))
    (if (and preview (<= (nth 5 preview) maxdist))
      (progn
        (setq tag (car preview))
        (setq existing (assoc tag mappings))
        (if existing
          (progn
            (setq duplicates (append duplicates (list record)))
            (setq duplicate-count (+ duplicate-count 1))
          )
          (progn
            (setq mappings (swcad-title-assoc-put tag preview mappings))
            (setq mapped-count (+ mapped-count 1))
          )
        )
      )
      (progn
        (setq unmapped (append unmapped (list record)))
        (setq unmapped-count (+ unmapped-count 1))
      )
    )
  )
  ;; Exploded/loose title text can use a source layout whose date cell is
  ;; horizontally different from the insert-based title layout. A unique,
  ;; structurally valid date inside the same 180 x 42 title region is safe to
  ;; map semantically. Other fields continue to require the established slots.
  (if
    (and
      (not source-ename)
      (not (assoc "GEN-TITLE-DATE{11.7}" mappings))
      (setq date-record (swcad-title-loose-title-date-record unmapped))
    )
    (progn
      (setq mappings
        (swcad-title-assoc-put
          "GEN-TITLE-DATE{11.7}"
          (swcad-title-semantic-mapping-preview
            "GEN-TITLE-DATE{11.7}"
            "date-semantic"
            date-record
            source-bbox
          )
          mappings
        )
      )
      (setq unmapped (swcad-title-record-list-remove-handle unmapped (nth 3 date-record)))
      (setq mapped-count (+ mapped-count 1))
      (setq unmapped-count (max 0 (- unmapped-count 1)))
    )
  )
  (list mappings records unmapped duplicates mapped-count unmapped-count duplicate-count)
)

(defun swcad-title-count-put (key counts / pair)
  (setq pair (assoc key counts))
  (if pair
    (subst (cons key (+ (cdr pair) 1)) pair counts)
    (append counts (list (cons key 1)))
  )
)

(defun swcad-title-print-counts (label counts / pair)
  (swcad-title-princ-line label)
  (if counts
    (foreach pair counts
      (swcad-title-princ-line
        (strcat
          "  "
          (swcad-title-string (car pair))
          ": "
          (itoa (cdr pair))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
)

(defun swcad-title-print-counts-log-only (label counts / pair)
  (swcad-title-log-line label)
  (if counts
    (foreach pair counts
      (swcad-title-log-line
        (strcat
          "  "
          (swcad-title-string (car pair))
          ": "
          (itoa (cdr pair))
        )
      )
    )
    (swcad-title-log-line "  <none>")
  )
)

(defun swcad-title-source-frame-from-candidates (source-bbox sheet-frames / found frame frame-bbox frame-area best-area)
  (setq found nil)
  (setq best-area nil)
  (foreach frame sheet-frames
    (setq frame-bbox (caddr frame))
    (setq frame-area (nth 4 frame))
    (if
      (and
        frame-bbox
        source-bbox
        (swcad-title-bbox-contains-bbox-p frame-bbox source-bbox 2.0)
        (or (not best-area) (< frame-area best-area))
      )
      (progn
        (setq found frame)
        (setq best-area frame-area)
      )
    )
  )
  found
)

(defun swcad-title-timer-seconds (/ value)
  (setq value (getvar "DATE"))
  (if value
    (* 86400.0 value)
    0.0
  )
)

(defun swcad-title-elapsed-ms (start-ms / finish-ms elapsed)
  (setq finish-ms (swcad-title-timer-seconds))
  (setq elapsed (- finish-ms start-ms))
  (fix (* 1000.0 elapsed))
)

(defun swcad-title-multi-preview (/ *error* start-ms elapsed sources sheet-frames total frame-total index source data bbox block title-frame title-frame-block title-frame-sheet title-target sheet-frame sheet-frame-key frame-sheet-counts title-sheet-counts frame-only-count title-with-frame-count title-without-frame-count)
  (defun *error* (msg)
    (if msg
      (progn
        (swcad-title-log-line (strcat "Error: " (swcad-title-string msg)))
        (swcad-title-princ-line (strcat "SWTITLESTATUS 다중 시트 요약 오류: " (swcad-title-string msg)))
      )
    )
    (swcad-title-close-log)
    (princ)
  )
  (setq start-ms (swcad-title-timer-seconds))
  (swcad-title-open-multi-preview-log)
  (setq sources (swcad-title-source-title-candidates))
  (setq sheet-frames (swcad-title-source-frame-candidates))
  (setq total (length sources))
  (setq frame-total (length sheet-frames))
  (setq frame-sheet-counts nil)
  (setq title-sheet-counts nil)
  (setq frame-only-count 0)
  (setq title-with-frame-count 0)
  (setq title-without-frame-count 0)

  (swcad-title-log-line "----- SWTITLESTATUS 내부 빠른 다중 시트 요약(읽기 전용) -----")
  (swcad-title-log-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-log-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-log-line "Residue cleanup candidate scan: skipped in fast preview.")
  (swcad-title-log-line "상세 매핑/잔여물 진단은 SWTITLESTATUS 내부 로그에서 확인하세요.")

  (foreach sheet-frame sheet-frames
    (setq sheet-frame-key (nth 5 sheet-frame))
    (setq frame-sheet-counts (swcad-title-count-put sheet-frame-key frame-sheet-counts))
    (if (not (swcad-title-frame-has-source-title-p (caddr sheet-frame) sources))
      (setq frame-only-count (+ frame-only-count 1))
    )
  )

  (swcad-title-log-line "")
  (swcad-title-log-line "Source sheet frame candidates:")
  (setq index 1)
  (foreach sheet-frame sheet-frames
    (swcad-title-log-line
      (strcat
        "  #"
        (itoa index)
        " handle="
        (swcad-title-string (swcad-title-dxf-value (cadr sheet-frame) 5))
        ", block="
        (swcad-title-string (cadddr sheet-frame))
        ", sheet="
        (swcad-title-string (nth 5 sheet-frame))
        ", title-present="
        (if (swcad-title-frame-has-source-title-p (caddr sheet-frame) sources) "yes" "no")
        ", target-frame="
        (swcad-title-target-frame-block-name-for-sheet (nth 5 sheet-frame))
        ", bbox="
        (swcad-title-bbox-string (caddr sheet-frame))
      )
    )
    (setq index (+ index 1))
  )

  (swcad-title-log-line "")
  (swcad-title-log-line "Source title candidates:")
  (setq index 1)
  (foreach source sources
    (setq data (cadr source))
    (setq bbox (caddr source))
    (setq block (cadddr source))
    (setq title-frame (swcad-title-source-frame-from-candidates bbox sheet-frames))
    (setq title-frame-block (if title-frame (cadddr title-frame) ""))
    (setq title-frame-sheet (if title-frame (nth 5 title-frame) nil))
    (if title-frame-sheet
      (progn
        (setq title-sheet-counts (swcad-title-count-put title-frame-sheet title-sheet-counts))
        (setq title-with-frame-count (+ title-with-frame-count 1))
      )
      (progn
        (setq title-sheet-counts (swcad-title-count-put "<missing-frame>" title-sheet-counts))
        (setq title-without-frame-count (+ title-without-frame-count 1))
      )
    )
    (setq title-target (swcad-title-target-frame-block-name-for-sheet title-frame-sheet))
    (swcad-title-log-line
      (strcat
        "  #"
        (itoa index)
        " handle="
        (swcad-title-string (swcad-title-dxf-value data 5))
        ", block="
        (swcad-title-string block)
        ", frame-block="
        (if title-frame (swcad-title-string title-frame-block) "<missing>")
        ", sheet="
        (if title-frame-sheet title-frame-sheet "<missing>")
        ", target-frame="
        title-target
        ", bbox="
        (swcad-title-bbox-string bbox)
      )
    )
    (setq index (+ index 1))
  )

  (setq elapsed (swcad-title-elapsed-ms start-ms))
  (swcad-title-log-line "")
  (swcad-title-log-line "Summary:")
  (swcad-title-log-line (strcat "  source title candidates: " (itoa total)))
  (swcad-title-log-line (strcat "  source sheet frame candidates: " (itoa frame-total)))
  (swcad-title-log-line (strcat "  title candidates with frame: " (itoa title-with-frame-count)))
  (swcad-title-log-line (strcat "  title candidates without frame: " (itoa title-without-frame-count)))
  (swcad-title-log-line (strcat "  frame-only sheet candidates: " (itoa frame-only-count)))
  (swcad-title-print-counts-log-only "  source sheet frame counts:" frame-sheet-counts)
  (swcad-title-print-counts-log-only "  title sheet counts:" title-sheet-counts)
  (swcad-title-log-line (strcat "Elapsed ms: " (itoa elapsed)))
  (swcad-title-log-line "No drawing data was changed.")

  (swcad-title-princ-line "----- SWTITLESTATUS 내부 빠른 요약 -----")
  (swcad-title-princ-line (strcat "Source titles: " (itoa total)))
  (swcad-title-princ-line (strcat "Source sheet frames: " (itoa frame-total)))
  (swcad-title-princ-line (strcat "Frame-only sheets: " (itoa frame-only-count)))
  (swcad-title-print-counts "Source sheet frame counts:" frame-sheet-counts)
  (swcad-title-print-counts "Title sheet counts:" title-sheet-counts)
  (swcad-title-princ-line "Residue cleanup scan: skipped")
  (swcad-title-princ-line (strcat "Elapsed ms: " (itoa elapsed)))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-multi-detail (/ start-ms elapsed sources sheet-frames total frame-total index source ename data bbox block frame frame-data frame-bbox frame-block build mappings records unmapped duplicates values block-sheet effective-frame-bbox text-sheet frame-sheet detected-sheet frame-target residue-records sheet-key sheet-counts mapped-total residue-total sheet-frame sheet-frame-key frame-sheet-counts frame-only-count)
  (setq start-ms (swcad-title-timer-seconds))
  (swcad-title-open-multi-detail-log)
  (setq sources (swcad-title-source-title-candidates))
  (setq sheet-frames (swcad-title-source-frame-candidates))
  (setq total (length sources))
  (setq frame-total (length sheet-frames))
  (setq sheet-counts nil)
  (setq frame-sheet-counts nil)
  (setq mapped-total 0)
  (setq residue-total 0)
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 다중 시트 변환 미리보기(읽기 전용) -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Source title candidates: " (itoa total)))
  (swcad-title-princ-line (strcat "Source sheet frame candidates: " (itoa frame-total)))
  (foreach sheet-frame sheet-frames
    (setq sheet-frame-key (nth 5 sheet-frame))
    (setq frame-sheet-counts (swcad-title-count-put sheet-frame-key frame-sheet-counts))
  )
  (setq frame-only-count 0)
  (foreach sheet-frame sheet-frames
    (if (not (swcad-title-frame-has-source-title-p (caddr sheet-frame) sources))
      (progn
        (if (= frame-only-count 0)
          (swcad-title-princ-line "Frame-only sheet candidates:")
        )
        (setq frame-only-count (+ frame-only-count 1))
        (swcad-title-princ-line
          (strcat
            "  handle="
            (swcad-title-string (swcad-title-dxf-value (cadr sheet-frame) 5))
            ", block="
            (swcad-title-string (cadddr sheet-frame))
            ", sheet="
            (swcad-title-string (nth 5 sheet-frame))
            ", bbox="
            (swcad-title-bbox-string (caddr sheet-frame))
          )
        )
      )
    )
  )
  (if (= frame-only-count 0)
    (swcad-title-princ-line "Frame-only sheet candidates: <none>")
  )
  (setq index 1)
  (foreach source sources
    (setq ename (car source))
    (setq data (cadr source))
    (setq bbox (caddr source))
    (setq block (cadddr source))
    (setq frame (swcad-title-transfer-source-frame bbox ename))
    (setq frame-data (if frame (cadr frame) nil))
    (setq frame-bbox (if frame (caddr frame) nil))
    (setq frame-block (if frame (swcad-title-effective-insert-name (car frame)) ""))
    (setq build (swcad-title-transfer-build-mappings bbox ename 7.0))
    (setq mappings (car build))
    (setq records (cadr build))
    (setq unmapped (caddr build))
    (setq duplicates (cadddr build))
    (setq values (swcad-title-transfer-values mappings))
    (if (not ename)
      (setq values (swcad-title-values-fill-missing-template-empty values))
    )
    (setq block-sheet (swcad-title-source-block-sheet-size block frame-block))
    (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
    (setq effective-frame-bbox (swcad-title-effective-source-frame-bbox bbox frame-bbox values block-sheet))
    (setq text-sheet (swcad-title-normalized-sheet-size (swcad-title-sheet-size-value values)))
    (setq frame-sheet (swcad-title-sheet-size-from-frame-bbox effective-frame-bbox))
    (setq detected-sheet (swcad-title-detected-sheet-size-for-source block frame-block values effective-frame-bbox))
    (setq frame-target (swcad-title-target-frame-block-name-for-source block frame-block values effective-frame-bbox))
    (setq residue-records (swcad-title-source-sheet-residue-records effective-frame-bbox ename (if frame (car frame) nil)))
    (setq sheet-key (if detected-sheet detected-sheet "<fallback>"))
    (setq sheet-counts (swcad-title-count-put sheet-key sheet-counts))
    (setq mapped-total (+ mapped-total (length mappings)))
    (setq residue-total (+ residue-total (length residue-records)))
    (swcad-title-princ-line "")
    (swcad-title-princ-line (strcat "#" (itoa index)))
    (swcad-title-princ-line
      (strcat
        "  source title: handle="
        (swcad-title-string (swcad-title-dxf-value data 5))
        ", block="
        (swcad-title-string block)
        ", bbox="
        (swcad-title-bbox-string bbox)
      )
    )
    (swcad-title-princ-line
      (strcat
        "  source frame: "
        (if frame-data
          (strcat
            "handle="
            (swcad-title-string (swcad-title-dxf-value frame-data 5))
            ", block="
            (swcad-title-string frame-block)
            ", bbox="
            (swcad-title-bbox-string frame-bbox)
          )
          "<none>"
        )
      )
    )
    (swcad-title-princ-line
      (strcat
        "  detected sheet: title-text="
        (if text-sheet text-sheet "<none>")
        ", frame-bbox="
        (if frame-sheet frame-sheet "<none>")
        ", block-name="
        (if block-sheet block-sheet "<none>")
        ", selected="
        sheet-key
        ", target-frame="
        frame-target
      )
    )
    (swcad-title-princ-line
      (strcat
        "  source title text records="
        (itoa (length records))
        ", mapped fields="
        (itoa (length mappings))
        ", unmapped="
        (itoa (length unmapped))
        ", duplicates="
        (itoa (length duplicates))
      )
    )
    (swcad-title-princ-line "  values to apply:")
    (if values
      (foreach pair values
        (swcad-title-princ-line
          (strcat
            "    "
            (car pair)
            " = "
            (swcad-title-string (cdr pair))
          )
        )
      )
      (swcad-title-princ-line "    <none>")
    )
    (swcad-title-princ-line (strcat "  sheet residue candidates=" (itoa (length residue-records))))
    (setq index (+ index 1))
  )
  (swcad-title-princ-line "")
  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line (strcat "  source title candidates: " (itoa total)))
  (swcad-title-princ-line (strcat "  mapped fields total: " (itoa mapped-total)))
  (swcad-title-princ-line (strcat "  sheet residue candidates total: " (itoa residue-total)))
  (swcad-title-print-counts "  detected sheet counts:" sheet-counts)
  (swcad-title-print-counts "  source sheet frame counts:" frame-sheet-counts)
  (setq elapsed (swcad-title-elapsed-ms start-ms))
  (swcad-title-princ-line (strcat "Elapsed ms: " (itoa elapsed)))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-frame-scan-interest-name-p (raw-name effective-name / raw effective pattern)
  (setq raw (strcase (swcad-title-string raw-name)))
  (setq effective (strcase (swcad-title-string effective-name)))
  (setq pattern "*DR*A*,*DR-A*,*A4*,*A-4*,*A_4*,*A 4*,*0400*,*0500*")
  (or
    (wcmatch raw pattern)
    (wcmatch effective pattern)
  )
)

(defun swcad-title-frame-scan (/ sources index source ename data bbox block frame frame-data frame-bbox frame-block raw-frame-block block-sheet insert-ss insert-index insert-total insert-ename insert-data raw-name effective-name insert-bbox insert-sheet bbox-sheet interesting-count a4-count)
  (swcad-title-open-frame-scan-log)
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 원본 도면틀 진단(읽기 전용) -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-princ-line "Selected source frames:")
  (setq sources (swcad-title-source-title-candidates))
  (setq index 1)
  (foreach source sources
    (setq ename (car source))
    (setq data (cadr source))
    (setq bbox (caddr source))
    (setq block (cadddr source))
    (setq frame (swcad-title-transfer-source-frame bbox ename))
    (setq frame-data (if frame (cadr frame) nil))
    (setq frame-bbox (if frame (caddr frame) nil))
    (setq frame-block (if frame (swcad-title-effective-insert-name (car frame)) ""))
    (setq raw-frame-block (if frame-data (swcad-title-dxf-value frame-data 2) ""))
    (setq block-sheet (swcad-title-source-block-sheet-size block frame-block))
    (swcad-title-princ-line
      (strcat
        "  #"
        (itoa index)
        " source="
        (swcad-title-string block)
        ", frame-raw="
        (swcad-title-string raw-frame-block)
        ", frame-effective="
        (swcad-title-string frame-block)
        ", block-sheet="
        (if block-sheet block-sheet "<none>")
        ", frame-bbox-sheet="
        (if (swcad-title-sheet-size-from-frame-bbox frame-bbox) (swcad-title-sheet-size-from-frame-bbox frame-bbox) "<none>")
        ", frame-bbox="
        (swcad-title-bbox-string frame-bbox)
      )
    )
    (setq index (+ index 1))
  )

  (swcad-title-princ-line "")
  (swcad-title-princ-line "Interesting INSERT names (DR-A*, A4, 0400, 0500):")
  (setq interesting-count 0)
  (setq a4-count 0)
  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq insert-ename (ssname insert-ss insert-index))
    (setq insert-data (entget insert-ename '("*")))
    (setq raw-name (swcad-title-dxf-value insert-data 2))
    (setq effective-name (swcad-title-effective-insert-name insert-ename))
    (if (swcad-title-frame-scan-interest-name-p raw-name effective-name)
      (progn
        (setq insert-bbox (swcad-title-safe-bbox insert-ename))
        (setq insert-sheet (swcad-title-sheet-size-from-block-name effective-name))
        (if (not insert-sheet)
          (setq insert-sheet (swcad-title-sheet-size-from-block-name raw-name))
        )
        (setq bbox-sheet (swcad-title-sheet-size-from-frame-bbox insert-bbox))
        (setq interesting-count (+ interesting-count 1))
        (if (= insert-sheet "A4")
          (setq a4-count (+ a4-count 1))
        )
        (swcad-title-princ-line
          (strcat
            "  handle="
            (swcad-title-string (swcad-title-dxf-value insert-data 5))
            ", raw="
            (swcad-title-string raw-name)
            ", effective="
            (swcad-title-string effective-name)
            ", name-sheet="
            (if insert-sheet insert-sheet "<none>")
            ", bbox-sheet="
            (if bbox-sheet bbox-sheet "<none>")
            ", bbox="
            (swcad-title-bbox-string insert-bbox)
          )
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  (swcad-title-princ-line "")
  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line (strcat "  source title candidates: " (itoa (length sources))))
  (swcad-title-princ-line (strcat "  interesting inserts: " (itoa interesting-count)))
  (swcad-title-princ-line (strcat "  A4-named inserts: " (itoa a4-count)))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-char-code (text)
  (if (and text (> (strlen text) 0))
    (ascii text)
    0
  )
)

(defun swcad-title-digit-or-dot-p (text / code)
  (setq code (swcad-title-char-code text))
  (or
    (and (>= code 48) (<= code 57))
    (= text ".")
  )
)

(defun swcad-title-space-p (text / code)
  (setq code (swcad-title-char-code text))
  (or (= code 9) (= code 10) (= code 13) (= code 32))
)

(defun swcad-title-scale-only-text-p (text / index len ch ok)
  (setq index 1)
  (setq len (strlen text))
  (setq ok (> len 0))
  (while (and ok (<= index len))
    (setq ch (substr text index 1))
    (if (not (or (swcad-title-digit-or-dot-p ch) (swcad-title-space-p ch) (= ch ":")))
      (setq ok nil)
    )
    (setq index (+ index 1))
  )
  ok
)

(defun swcad-title-extract-ratio-text (text / raw len colon left-end left-start right-start right-end left right)
  (setq raw (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq len (strlen raw))
  (setq colon (vl-string-search ":" raw))
  (setq left nil)
  (setq right nil)
  (if colon
    (progn
      (setq left-end colon)
      (while (and (> left-end 0) (swcad-title-space-p (substr raw left-end 1)))
        (setq left-end (- left-end 1))
      )
      (setq left-start left-end)
      (while (and (> left-start 0) (swcad-title-digit-or-dot-p (substr raw left-start 1)))
        (setq left-start (- left-start 1))
      )
      (if (> left-end left-start)
        (setq left (substr raw (+ left-start 1) (- left-end left-start)))
      )

      (setq right-start (+ colon 2))
      (while (and (<= right-start len) (swcad-title-space-p (substr raw right-start 1)))
        (setq right-start (+ right-start 1))
      )
      (setq right-end right-start)
      (while (and (<= right-end len) (swcad-title-digit-or-dot-p (substr raw right-end 1)))
        (setq right-end (+ right-end 1))
      )
      (if (> right-end right-start)
        (setq right (substr raw right-start (- right-end right-start)))
      )
    )
  )
  (if (and left right (> (atof left) 0.0) (> (atof right) 0.0))
    (strcat left ":" right)
    nil
  )
)

(defun swcad-title-scale-text-candidate (text / cleaned upper ratio)
  (setq cleaned (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq upper (strcase cleaned))
  (setq ratio (swcad-title-extract-ratio-text cleaned))
  (if (and
        ratio
        (or
          (swcad-title-scale-only-text-p cleaned)
          (vl-string-search "SCALE" upper)
          (vl-string-search "SCA" upper)
          (<= (strlen cleaned) 16)
        )
      )
    ratio
    nil
  )
)

(defun swcad-title-date-text-candidate-p (text)
  (if (swcad-title-date-digits text) T nil)
)

(defun swcad-title-insert-attributes (ename / data next edata etype result)
  (setq result nil)
  (setq data (entget ename))
  (if (= (swcad-title-dxf-value data 66) 1)
    (progn
      (setq next (entnext ename))
      (while next
        (setq edata (entget next '("*")))
        (setq etype (swcad-title-dxf-value edata 0))
        (cond
          ((= etype "ATTRIB")
            (setq result (append result (list edata)))
          )
          ((= etype "SEQEND")
            (setq next nil)
          )
          ((not (= etype "ATTRIB"))
            (setq next nil)
          )
        )
        (if next
          (setq next (entnext next))
        )
      )
    )
  )
  result
)

(defun swcad-title-scale-tag-p (tag / upper)
  (setq upper (strcase (swcad-title-string tag)))
  (or
    (wcmatch upper "*GEN-TITLE-SCA*")
    (wcmatch upper "*TITLE*SCA*")
    (wcmatch upper "*SCALE*")
  )
)

(defun swcad-title-title-block-name-p (name / upper)
  (setq upper (strcase (swcad-title-string name)))
  (or
    (wcmatch upper "*TITLE*")
    (wcmatch upper "*GMTITLE*")
    (wcmatch upper "*FTAP*")
  )
)

(defun swcad-title-native-target-title-name-p (name)
  (equal
    (strcase (swcad-title-string name))
    (strcase (swcad-title-target-title-block-name))
  )
)

(defun swcad-title-native-target-frame-name-p (name / upper candidate result)
  (setq upper (strcase (swcad-title-string name)))
  (setq result nil)
  (foreach candidate (swcad-title-target-frame-block-candidates)
    (if (equal upper (strcase candidate))
      (setq result T)
    )
  )
  result
)

(defun swcad-title-source-like-frame-child-name-p (name / upper)
  (setq upper (strcase (swcad-title-string name)))
  (or
    (equal upper (strcase (swcad-title-target-title-block-name)))
    ;; Native GstarCAD DR frame DWGs also contain child blocks named like
    ;; "DR-A3 From_HYUN". Treat only sheet/export-specific children as old
    ;; SOLIDWORKS residue so native DR_A*_Outline imports are not rejected.
    (wcmatch upper "#*DR-A*FROM*")
    (wcmatch upper "#*DR_A*FROM*")
    (wcmatch upper "#*SW_NOTE*")
    (wcmatch upper "*_SW_NOTE_*")
  )
)

(defun swcad-title-target-frame-block-source-like-children (frame-block / children result child)
  (setq children (swcad-title-block-child-insert-names frame-block))
  (setq result nil)
  (foreach child children
    (if (swcad-title-source-like-frame-child-name-p child)
      (setq result (swcad-title-list-add-unique child result))
    )
  )
  result
)

(defun swcad-title-target-frame-block-contaminated-p (frame-block)
  (if (swcad-title-target-frame-block-source-like-children frame-block) T nil)
)

(defun swcad-title-contaminated-target-frame-blocks (/ result frame-block)
  (setq result nil)
  (foreach frame-block (swcad-title-target-frame-block-candidates)
    (if
      (and
        (swcad-title-block-exists-p frame-block)
        (swcad-title-target-frame-block-contaminated-p frame-block)
      )
      (setq result (append result (list frame-block)))
    )
  )
  result
)

(defun swcad-title-source-title-count ()
  (length (swcad-title-source-title-candidates))
)

(defun swcad-title-frame-only-source-count ()
  (length (swcad-title-frame-only-source-candidates))
)

(defun swcad-title-fast-sheet-summary (/ sources sheet-frames source-count frame-total frame-sheet-counts title-sheet-counts frame-only-count title-with-frame-count title-without-frame-count source bbox title-frame title-frame-sheet sheet-frame sheet-frame-key)
  (setq sources (swcad-title-source-title-candidates))
  (setq sheet-frames (swcad-title-source-frame-candidates))
  (setq source-count (length sources))
  (setq frame-total (length sheet-frames))
  (setq frame-sheet-counts nil)
  (setq title-sheet-counts nil)
  (setq frame-only-count 0)
  (setq title-with-frame-count 0)
  (setq title-without-frame-count 0)
  (foreach sheet-frame sheet-frames
    (setq sheet-frame-key (nth 5 sheet-frame))
    (setq frame-sheet-counts (swcad-title-count-put sheet-frame-key frame-sheet-counts))
    (if (not (swcad-title-frame-has-source-title-p (caddr sheet-frame) sources))
      (setq frame-only-count (+ frame-only-count 1))
    )
  )
  (foreach source sources
    (setq bbox (caddr source))
    (setq title-frame (swcad-title-source-frame-from-candidates bbox sheet-frames))
    (setq title-frame-sheet (if title-frame (nth 5 title-frame) nil))
    (if title-frame-sheet
      (progn
        (setq title-sheet-counts (swcad-title-count-put title-frame-sheet title-sheet-counts))
        (setq title-with-frame-count (+ title-with-frame-count 1))
      )
      (progn
        (setq title-sheet-counts (swcad-title-count-put "<missing-frame>" title-sheet-counts))
        (setq title-without-frame-count (+ title-without-frame-count 1))
      )
    )
  )
  (list
    (cons "source-title-count" source-count)
    (cons "source-frame-count" frame-total)
    (cons "frame-only-count" frame-only-count)
    (cons "title-with-frame-count" title-with-frame-count)
    (cons "title-without-frame-count" title-without-frame-count)
    (cons "frame-sheet-counts" frame-sheet-counts)
    (cons "title-sheet-counts" title-sheet-counts)
  )
)

(defun swcad-title-fast-summary-value (summary key)
  (cdr (assoc key summary))
)

(defun swcad-title-count-value (key counts / result pair)
  (setq result 0)
  (foreach pair counts
    (if (equal (strcase (swcad-title-string (car pair))) (strcase (swcad-title-string key)))
      (setq result (cdr pair))
    )
  )
  result
)

(defun swcad-title-count-set (key value counts / target result pair found)
  (setq target (swcad-title-string key))
  (setq result nil)
  (setq found nil)
  (foreach pair counts
    (if (equal (strcase (swcad-title-string (car pair))) (strcase target))
      (progn
        (setq result (append result (list (cons target value))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if found
    result
    (append result (list (cons target value)))
  )
)

(defun swcad-title-count-max-set (key value counts / current)
  (setq current (swcad-title-count-value key counts))
  (if (> value current)
    (swcad-title-count-set key value counts)
    counts
  )
)

(defun swcad-title-counts-add (base extra / result pair key value)
  (setq result base)
  (foreach pair extra
    (setq key (car pair))
    (setq value (+ (swcad-title-count-value key result) (cdr pair)))
    (setq result (swcad-title-count-set key value result))
  )
  result
)

(defun swcad-title-a2a3a4-sheet-p (sheet / normalized)
  (setq normalized (swcad-title-normalized-sheet-size sheet))
  (if (member normalized '("A2" "A3" "A4")) T nil)
)

(defun swcad-title-a2a3a4-counts-only (counts / result pair sheet count)
  (setq result nil)
  (foreach pair counts
    (setq sheet (swcad-title-normalized-sheet-size (car pair)))
    (setq count (cdr pair))
    (if (and (swcad-title-a2a3a4-sheet-p sheet) (> count 0))
      (setq result (swcad-title-count-set sheet count result))
    )
  )
  result
)

(defun swcad-title-required-sheets-from-counts (counts / result pair sheet)
  (setq result nil)
  (foreach pair counts
    (setq sheet (swcad-title-normalized-sheet-size (car pair)))
    (if (swcad-title-a2a3a4-sheet-p sheet)
      (setq result (swcad-title-list-add-unique sheet result))
    )
  )
  result
)

(defun swcad-title-target-frame-sheet-counts (/ counts frame-records record frame-block sheet)
  (setq counts nil)
  (setq frame-records (swcad-title-frame-records))
  (foreach record frame-records
    (setq frame-block (cadr record))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (setq counts (swcad-title-count-put (if sheet sheet frame-block) counts))
  )
  counts
)

(defun swcad-title-active-required-sheets (summary / result sheet)
  (setq result nil)
  (foreach sheet (swcad-title-required-sheets-from-counts (swcad-title-fast-summary-value summary "frame-sheet-counts"))
    (setq result (swcad-title-list-add-unique sheet result))
  )
  (foreach sheet (swcad-title-required-sheets-from-counts (swcad-title-fast-summary-value summary "title-sheet-counts"))
    (setq result (swcad-title-list-add-unique sheet result))
  )
  (foreach sheet (swcad-title-required-sheets-from-counts (swcad-title-target-frame-sheet-counts))
    (setq result (swcad-title-list-add-unique sheet result))
  )
  result
)

(defun swcad-title-missing-required-target-sheets (counts required-sheets / result sheet)
  (setq result nil)
  (foreach sheet required-sheets
    (if (= (swcad-title-count-value sheet counts) 0)
      (setq result (append result (list sheet)))
    )
  )
  result
)

(defun swcad-title-current-total-sheet-counts (summary / source-counts target-counts)
  (setq source-counts (swcad-title-fast-summary-value summary "frame-sheet-counts"))
  (setq target-counts (swcad-title-target-frame-sheet-counts))
  (swcad-title-a2a3a4-counts-only (swcad-title-counts-add target-counts source-counts))
)

(defun swcad-title-expected-sheet-counts-from-values (values / result found text pos key value)
  (setq result nil)
  (setq found nil)
  (foreach text values
    (setq text (swcad-title-string text))
    (cond
      ((equal (strcase text) (strcase *swcad-title-expected-sheet-counts-marker*))
        (setq found T)
      )
      (
        (and
          found
          (swcad-title-string-prefix-p "COUNT:" text)
          (setq pos (vl-string-search "=" text))
          (> pos 6)
        )
        (setq key (swcad-title-normalized-sheet-size (substr text 7 (- pos 6))))
        (setq value (atoi (substr text (+ pos 2))))
        (if (and (swcad-title-a2a3a4-sheet-p key) (> value 0))
          (setq result (swcad-title-count-max-set key value result))
        )
      )
    )
  )
  result
)

(defun swcad-title-expected-title-counts-from-values (values / result found text pos key value)
  (setq result nil)
  (setq found nil)
  (foreach text values
    (setq text (swcad-title-string text))
    (cond
      ((equal (strcase text) (strcase *swcad-title-expected-title-counts-marker*))
        (setq found T)
      )
      (
        (and
          found
          (swcad-title-string-prefix-p "TITLECOUNT:" text)
          (setq pos (vl-string-search "=" text))
          (> pos 11)
        )
        (setq key (swcad-title-normalized-sheet-size (substr text 12 (- pos 11))))
        (setq value (atoi (substr text (+ pos 2))))
        (if (and (swcad-title-a2a3a4-sheet-p key) (> value 0))
          (setq result (swcad-title-count-max-set key value result))
        )
      )
    )
  )
  result
)

(defun swcad-title-stored-expected-sheet-counts (/ result title-name title-enames title-ename values counts frame-records frame-record frame-ename pair)
  (setq result nil)
  (setq title-name (swcad-title-target-title-block-name))
  (setq title-enames (swcad-title-inserts-by-effective-name title-name))
  (foreach title-ename title-enames
    (setq values (swcad-title-exemplar-xdata-values title-ename))
    (setq counts (swcad-title-expected-sheet-counts-from-values values))
    (foreach pair counts
      (setq result (swcad-title-count-max-set (car pair) (cdr pair) result))
    )
  )
  (setq frame-records (swcad-title-frame-records))
  (foreach frame-record frame-records
    (setq frame-ename (car frame-record))
    (setq values (swcad-title-exemplar-xdata-values frame-ename))
    (setq counts (swcad-title-expected-sheet-counts-from-values values))
    (foreach pair counts
      (setq result (swcad-title-count-max-set (car pair) (cdr pair) result))
    )
  )
  result
)

(defun swcad-title-stored-expected-title-counts (/ result title-name title-enames title-ename values counts frame-records frame-record frame-ename pair)
  (setq result nil)
  (setq title-name (swcad-title-target-title-block-name))
  (setq title-enames (swcad-title-inserts-by-effective-name title-name))
  (foreach title-ename title-enames
    (setq values (swcad-title-exemplar-xdata-values title-ename))
    (setq counts (swcad-title-expected-title-counts-from-values values))
    (foreach pair counts
      (setq result (swcad-title-count-max-set (car pair) (cdr pair) result))
    )
  )
  (setq frame-records (swcad-title-frame-records))
  (foreach frame-record frame-records
    (setq frame-ename (car frame-record))
    (setq values (swcad-title-exemplar-xdata-values frame-ename))
    (setq counts (swcad-title-expected-title-counts-from-values values))
    (foreach pair counts
      (setq result (swcad-title-count-max-set (car pair) (cdr pair) result))
    )
  )
  result
)

(defun swcad-title-target-title-sheet-counts (/ result pair-records record sheet)
  (setq result nil)
  (setq pair-records (swcad-title-target-gmtitle-pair-records))
  (foreach record pair-records
    (setq sheet (swcad-title-sheet-size-from-block-name (caddr record)))
    (if (swcad-title-a2a3a4-sheet-p sheet)
      (setq result (swcad-title-count-put sheet result))
    )
  )
  result
)

(defun swcad-title-current-total-title-counts (summary / source-counts target-counts)
  (setq source-counts (swcad-title-fast-summary-value summary "title-sheet-counts"))
  (setq target-counts (swcad-title-target-title-sheet-counts))
  (swcad-title-a2a3a4-counts-only (swcad-title-counts-add target-counts source-counts))
)

(defun swcad-title-expected-title-counts-for-marker (/ stored summary)
  (setq stored (swcad-title-stored-expected-title-counts))
  (if stored
    stored
    (progn
      (setq summary (swcad-title-fast-sheet-summary))
      (swcad-title-current-total-title-counts summary)
    )
  )
)

(defun swcad-title-expected-sheet-counts-for-marker (/ stored summary)
  (setq stored (swcad-title-stored-expected-sheet-counts))
  (if stored
    stored
    (progn
      (setq summary (swcad-title-fast-sheet-summary))
      (swcad-title-current-total-sheet-counts summary)
    )
  )
)

(defun swcad-title-count-shortage-records (expected actual / result pair sheet expected-count actual-count)
  (setq result nil)
  (foreach pair expected
    (setq sheet (swcad-title-normalized-sheet-size (car pair)))
    (setq expected-count (cdr pair))
    (setq actual-count (swcad-title-count-value sheet actual))
    (if (< actual-count expected-count)
      (setq result (append result (list (list sheet expected-count actual-count))))
    )
  )
  result
)

(defun swcad-title-count-excess-records (expected actual / result pair sheet expected-count actual-count)
  (setq result nil)
  (foreach pair actual
    (setq sheet (swcad-title-normalized-sheet-size (car pair)))
    (if (swcad-title-a2a3a4-sheet-p sheet)
      (progn
        (setq expected-count (swcad-title-count-value sheet expected))
        (setq actual-count (cdr pair))
        (if (> actual-count expected-count)
          (setq result (append result (list (list sheet expected-count actual-count))))
        )
      )
    )
  )
  result
)

(defun swcad-title-print-count-deltas (label records / record)
  (swcad-title-princ-line label)
  (if records
    (foreach record records
      (swcad-title-princ-line
        (strcat
          "  "
          (car record)
          ": 필요 "
          (itoa (cadr record))
          ", 현재 "
          (itoa (caddr record))
        )
      )
    )
    (swcad-title-princ-line "  <없음>")
  )
)

(defun swcad-title-required-frame-blocks-from-counts (counts / result pair key sheet frame-block)
  (setq result nil)
  (foreach pair counts
    (setq key (car pair))
    (setq sheet (swcad-title-normalized-sheet-size key))
    (if (swcad-title-a2a3a4-sheet-p sheet)
      (progn
        (setq frame-block (swcad-title-target-frame-block-name-for-sheet sheet))
        (if frame-block
          (setq result (swcad-title-list-add-unique frame-block result))
        )
      )
    )
  )
  result
)

(defun swcad-title-required-native-frame-blocks (summary / result title-counts frame-block)
  (setq result nil)
  (setq title-counts (swcad-title-fast-summary-value summary "title-sheet-counts"))
  ;; Native GMTITLE exemplars are required only for sheets that actually have a
  ;; source title block. Title-missing/frame-only sheets use the outline-only
  ;; exception path and must not force creation of a new DR_titlea_3rd.
  (foreach frame-block (swcad-title-required-frame-blocks-from-counts title-counts)
    (setq result (swcad-title-list-add-unique frame-block result))
  )
  result
)

(defun swcad-title-missing-required-native-frame-blocks (summary / required missing frame-block)
  (setq required (swcad-title-required-native-frame-blocks summary))
  (setq missing nil)
  (foreach frame-block required
    (if (not (swcad-title-native-example-pair-for-frame-block frame-block))
      (setq missing (append missing (list frame-block)))
    )
  )
  missing
)

(defun swcad-title-summary-title-count-for-frame-block (summary frame-block / sheet)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (if sheet
    (swcad-title-count-value sheet (swcad-title-fast-summary-value summary "title-sheet-counts"))
    0
  )
)

(defun swcad-title-summary-frame-only-count-for-frame-block (summary frame-block / sheet frame-count title-count result)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (if sheet
    (progn
      (setq frame-count (swcad-title-count-value sheet (swcad-title-fast-summary-value summary "frame-sheet-counts")))
      (setq title-count (swcad-title-count-value sheet (swcad-title-fast-summary-value summary "title-sheet-counts")))
      (setq result (- frame-count title-count))
      (if (< result 0) 0 result)
    )
    0
  )
)

(defun swcad-title-print-missing-native-exemplar-actions (summary missing / frame-block title-count frame-only-count has-any-example risk-message)
  (if missing
    (progn
      (setq has-any-example (if (swcad-title-native-example-title) T nil))
      (swcad-title-princ-line "다음 동일 크기 native GMTITLE 작업:")
      (foreach frame-block missing
        (setq title-count (swcad-title-summary-title-count-for-frame-block summary frame-block))
        (setq frame-only-count (swcad-title-summary-frame-only-count-for-frame-block summary frame-block))
        (cond
          ((> title-count 0)
            (swcad-title-princ-line
              (strcat
                "  "
                frame-block
                ": 이 크기의 실제 표제란 시트 1장을 생성/마무리하려면 SWTITLECONVERTNEXT를 실행한 뒤 SWTITLESTATUS를 다시 실행하세요."
              )
            )
            (if (not has-any-example)
              (swcad-title-princ-line "    전체 첫 시트라면 SWTITLECONVERTNEXT가 내부에서 첫 실제 GMTITLE 단계를 엽니다.")
            )
          )
          ((> frame-only-count 0)
            (swcad-title-princ-line
              (strcat
                "  "
                frame-block
                ": 이 크기는 원본 표제란 부재가 검증된 도면틀-only 예외입니다. 새 DR_titlea_3rd를 만들지 말고 같은 크기 DR 도면틀 정의 검증 후 SWTITLECONVERTNEXT로 outline-only 변환하세요."
              )
            )
            (setq risk-message
              (swcad-title-title-missing-outline-risk-message
                (swcad-title-frame-only-source-for-frame-block frame-block)
                frame-block
              )
            )
            (if risk-message
              (progn
                (swcad-title-princ-line (strcat "    경고: " risk-message))
                (swcad-title-princ-line "    같은 크기 DR_A*_Outline 도면틀 정의가 bbox 검사를 통과하기 전에는 기존 원본 도면틀을 지우지 마세요.")
                (swcad-title-princ-line "    SWTITLEPREPARE가 도면틀 정의를 준비/검증한 뒤 SWTITLECONVERTNEXT가 outline-only 변환을 처리합니다.")
              )
            )
          )
          (T
            (swcad-title-princ-line
              (strcat
                "  "
                frame-block
                ": 현재 이 크기를 요구하는 남은 원본 시트가 없습니다."
              )
            )
          )
        )
      )
    )
  )
)

(defun swcad-title-next-frame-only-target-frame-block (/ source-frame sheet)
  (setq source-frame (car (swcad-title-frame-only-source-candidates)))
  (setq sheet (if source-frame (nth 5 source-frame) nil))
  (swcad-title-target-frame-block-name-for-sheet sheet)
)

(defun swcad-title-title-missing-outline-policy-active-p (/ source-frame frame-block sheet)
  (setq source-frame (car (swcad-title-frame-only-source-candidates)))
  (setq frame-block
    (if source-frame
      (swcad-title-target-frame-block-name-for-sheet (nth 5 source-frame))
      nil
    )
  )
  (setq sheet (if source-frame (swcad-title-normalized-sheet-size (nth 5 source-frame)) nil))
  (and
    source-frame
    sheet
    (wcmatch sheet "A1,A2,A3,A4")
    (swcad-title-frame-name-matches-p frame-block (strcat "DR_" sheet "_Outline"))
  )
)

(defun swcad-title-title-missing-outline-policy-blocked-p ()
  (swcad-title-title-missing-outline-policy-active-p)
)

(defun swcad-title-title-missing-outline-target-block (/ source-frame)
  (setq source-frame (car (swcad-title-frame-only-source-candidates)))
  (if source-frame
    (swcad-title-target-frame-block-name-for-sheet (nth 5 source-frame))
    nil
  )
)

(defun swcad-title-title-missing-outline-raw-sheet-warning (frame-block / bbox sheet dims tol)
  (setq bbox
    (if frame-block
      (swcad-title-block-definition-raw-bbox frame-block)
      nil
    )
  )
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (setq dims (swcad-title-sheet-dimensions sheet))
  (setq tol 2.0)
  (if
    (and
      bbox
      dims
      (numberp (car bbox))
      (numberp (cadr bbox))
      (numberp (caddr bbox))
      (numberp (cadddr bbox))
      (<= (abs (- (car bbox) 0.0)) tol)
      (<= (abs (- (cadr bbox) 0.0)) tol)
      (<= (abs (- (caddr bbox) (car dims))) tol)
      (<= (abs (- (cadddr bbox) (cadr dims))) tol)
    )
    nil
    (strcat
      (swcad-title-string frame-block)
      " 정의 raw bbox가 보이는 "
      (if sheet sheet "<unknown>")
      " 범위 (0,0)-("
      (if dims (swcad-title-number-string (car dims)) "?")
      ","
      (if dims (swcad-title-number-string (cadr dims)) "?")
      ")과 맞지 않습니다: "
      (swcad-title-bbox-string bbox)
    )
  )
)

(defun swcad-title-title-missing-outline-native-outside-marker-p (frame-block / raw-risk strict-warning)
  (and
    frame-block
    (swcad-title-block-exists-p frame-block)
    (not (swcad-title-target-frame-block-contaminated-p frame-block))
    (not (swcad-title-frame-definition-raw-bbox-risk-record frame-block))
    (setq strict-warning (swcad-title-title-missing-outline-raw-sheet-warning frame-block))
  )
)

(defun swcad-title-title-missing-outline-definition-status (/ frame-block raw-risk)
  (setq frame-block (swcad-title-title-missing-outline-target-block))
  (cond
    ((not (swcad-title-title-missing-outline-policy-active-p)) "not-title-missing-outline")
    ((not (swcad-title-frame-name-matches-p frame-block (swcad-title-title-missing-outline-target-block))) "wrong-target")
    ((not (swcad-title-block-exists-p frame-block)) "missing")
    ((swcad-title-target-frame-block-contaminated-p frame-block) "contaminated")
    ((setq raw-risk (swcad-title-frame-definition-raw-bbox-risk-record frame-block)) "raw-bbox-risk")
    ((swcad-title-title-missing-outline-native-outside-marker-p frame-block) "ready-native-outside-markers")
    (T "ready")
  )
)

(defun swcad-title-title-missing-outline-definition-ready-p ()
  (member
    (swcad-title-title-missing-outline-definition-status)
    '("ready" "ready-native-outside-markers")
  )
)

(defun swcad-title-title-missing-outline-definition-needed-p ()
  (and
    (swcad-title-title-missing-outline-policy-active-p)
    (not (swcad-title-title-missing-outline-definition-ready-p))
  )
)

(defun swcad-title-print-title-missing-outline-definition-status (/ frame-block status raw-risk strict-warning)
  (setq frame-block (swcad-title-title-missing-outline-target-block))
  (setq status (swcad-title-title-missing-outline-definition-status))
  (setq raw-risk
    (if (and frame-block (swcad-title-block-exists-p frame-block))
      (swcad-title-frame-definition-raw-bbox-risk-record frame-block)
      nil
    )
  )
  (setq strict-warning
    (if (and frame-block (swcad-title-block-exists-p frame-block))
      (swcad-title-title-missing-outline-raw-sheet-warning frame-block)
      nil
    )
  )
  (swcad-title-princ-line
    (strcat
      "title-missing/frame-only 도면틀 정의 상태: "
      status
      ", 대상="
      (if frame-block frame-block "<unknown>")
    )
  )
  (cond
    ((equal status "ready")
      (swcad-title-princ-line "  변환 가능: 현재 도면 안의 title-missing/frame-only 대상 DR 도면틀 정의가 clean/raw-bbox 검사를 통과했습니다.")
    )
    ((equal status "ready-native-outside-markers")
      (swcad-title-princ-line "  변환 가능: 현재 title-missing/frame-only 대상 DR 도면틀 정의는 공식 native 바깥 마커를 포함하지만, 과도한 raw bbox/선택 위험은 없습니다.")
      (if strict-warning
        (swcad-title-princ-line (strcat "  참고: " strict-warning))
      )
    )
    ((equal status "missing")
      (swcad-title-princ-line "  필요 작업(title-missing 예외): SWTITLEPREPARE로 설치 원본 정의를 가져와 형상/선택범위를 먼저 검증하세요.")
    )
    ((equal status "contaminated")
      (swcad-title-princ-line "  필요 작업(title-missing 예외): SWTITLEPREPARE로 오염된 DR 도면틀 정의를 정리/복구해야 합니다.")
    )
    ((equal status "raw-bbox-risk")
      (swcad-title-princ-line "  필요 작업(title-missing 예외): DR 도면틀 정의의 실제 선택 범위가 커서 기존 원본 도면틀을 삭제하지 않습니다.")
      (if raw-risk
        (swcad-title-princ-line (strcat "  정의 선택범위 위험: " (caddr raw-risk)))
      )
      (if strict-warning
        (swcad-title-princ-line (strcat "  정의 범위 위험: " strict-warning))
      )
    )
  )
)

(defun swcad-title-next-fast-target-frame-block (/ bootstrap-record)
  (if (> (swcad-title-source-title-count) 0)
    (progn
      (setq bootstrap-record (swcad-title-next-bootstrap-selection-record))
      (if bootstrap-record (cadr bootstrap-record) nil)
    )
    nil
  )
)

(defun swcad-title-next-fast-target-ready-p (/ frame-block)
  (setq frame-block (swcad-title-next-fast-target-frame-block))
  (if (and frame-block (swcad-title-native-example-pair-for-frame-block frame-block))
    T
    nil
  )
)

(defun swcad-title-next-frame-only-target-missing-native-p (/ frame-block)
  (setq frame-block (swcad-title-next-frame-only-target-frame-block))
  (if (and frame-block (not (swcad-title-native-example-pair-for-frame-block frame-block)))
    frame-block
    nil
  )
)

(defun swcad-title-print-next-fast-target-readiness (/ frame-block)
  (setq frame-block (swcad-title-next-fast-target-frame-block))
  (if frame-block
    (swcad-title-princ-line
      (strcat
        "Next fast-batch target frame: "
        frame-block
        ", exact-size native exemplar="
        (if (swcad-title-native-example-pair-for-frame-block frame-block) "ready" "missing")
      )
    )
  )
)

(defun swcad-title-print-required-native-exemplars (summary / required missing frame-block)
  (setq required (swcad-title-required-native-frame-blocks summary))
  (setq missing nil)
  (swcad-title-princ-line "Exact-size native GMTITLE exemplars needed by remaining source title sheets:")
  (if required
    (foreach frame-block required
      (if (swcad-title-native-example-pair-for-frame-block frame-block)
        (swcad-title-princ-line (strcat "  " frame-block ": ready"))
        (progn
          (setq missing (append missing (list frame-block)))
          (swcad-title-princ-line (strcat "  " frame-block ": missing"))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
  (if missing
    (progn
      (swcad-title-princ-line
        (strcat
          "Missing exact-size native exemplar(s): "
          (swcad-title-list-string missing)
        )
      )
      (swcad-title-princ-line "표제란이 있는 누락 용지 크기마다 실제 native GMTITLE 1장을 먼저 만들고 빠른 복제 일괄 변환을 다시 실행하세요.")
    )
  )
  (swcad-title-print-missing-native-exemplar-actions summary missing)
  missing
)

(defun swcad-title-print-fast-sheet-summary (summary)
  (swcad-title-princ-line "Detected source summary:")
  (swcad-title-princ-line
    (strcat
      "  source title sheets: "
      (itoa (swcad-title-fast-summary-value summary "source-title-count"))
    )
  )
  (swcad-title-princ-line
    (strcat
      "  source sheet frames: "
      (itoa (swcad-title-fast-summary-value summary "source-frame-count"))
    )
  )
  (swcad-title-princ-line
    (strcat
      "  title sheets with frame: "
      (itoa (swcad-title-fast-summary-value summary "title-with-frame-count"))
    )
  )
  (swcad-title-princ-line
    (strcat
      "  title sheets without frame: "
      (itoa (swcad-title-fast-summary-value summary "title-without-frame-count"))
    )
  )
  (swcad-title-princ-line
    (strcat
      "  frame-only sheets: "
      (itoa (swcad-title-fast-summary-value summary "frame-only-count"))
    )
  )
  (swcad-title-print-counts
    "  source sheet frame counts:"
    (swcad-title-fast-summary-value summary "frame-sheet-counts")
  )
  (swcad-title-print-counts
    "  title sheet counts:"
    (swcad-title-fast-summary-value summary "title-sheet-counts")
  )
)

(defun swcad-title-next-bootstrap-selection-record (/ source source-ename source-bbox source-block source-frame source-frame-bbox source-frame-block build mappings values block-sheet effective-frame-bbox frame-block sheet)
  (setq source (car (swcad-title-source-title-candidates)))
  (if source
    (progn
      (setq source-ename (car source))
      (setq source-bbox (caddr source))
      (setq source-block (cadddr source))
      (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
      (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
      (setq source-frame-block (if source-frame (swcad-title-effective-insert-name (car source-frame)) nil))
      (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
      (setq mappings (car build))
      (setq values (swcad-title-transfer-values mappings))
      (if (not source-ename)
        (setq values (swcad-title-values-fill-missing-template-empty values))
      )
      (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
      (setq effective-frame-bbox (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
      (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values effective-frame-bbox))
      (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
      (list sheet frame-block (swcad-title-target-title-block-name))
    )
    nil
  )
)

(defun swcad-title-print-next-bootstrap-selection (/ record sheet frame-block title-block)
  (setq record (swcad-title-next-bootstrap-selection-record))
  (if record
    (progn
      (setq sheet (car record))
      (setq frame-block (cadr record))
      (setq title-block (caddr record))
      (swcad-title-princ-line "다음 첫 native GMTITLE 선택:")
      (swcad-title-princ-line (strcat "  원본 용지: " (if sheet sheet "<unknown>")))
      (swcad-title-princ-line (strcat "  용지/도면틀: " (if frame-block frame-block "<unknown>")))
      (swcad-title-princ-line (strcat "  제목블록: " (if title-block title-block "<unknown>")))
    )
  )
)

(defun swcad-title-next-missing-native-selection-record (summary missing-required-native / frame-block sheet title-count frame-only-count role title-block)
  (setq frame-block (swcad-title-next-fast-target-frame-block))
  (if (and frame-block (not (member frame-block missing-required-native)))
    (setq frame-block nil)
  )
  (if (not frame-block)
    (setq frame-block (car missing-required-native))
  )
  (if frame-block
    (progn
      (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
      (setq title-count (swcad-title-summary-title-count-for-frame-block summary frame-block))
      (setq frame-only-count (swcad-title-summary-frame-only-count-for-frame-block summary frame-block))
      (setq role (if (> title-count 0) "title-sheet" (if (> frame-only-count 0) "frame-only" "unknown")))
      (setq title-block (if (equal role "frame-only") "<none-frame-only>" (swcad-title-target-title-block-name)))
      (list sheet frame-block title-block role)
    )
    nil
  )
)

(defun swcad-title-print-next-missing-native-selection (summary missing-required-native / record sheet frame-block title-block role)
  (setq record (swcad-title-next-missing-native-selection-record summary missing-required-native))
  (if record
    (progn
      (setq sheet (car record))
      (setq frame-block (cadr record))
      (setq title-block (caddr record))
      (setq role (cadddr record))
      (swcad-title-princ-line "다음 누락 크기 native GMTITLE 선택:")
      (swcad-title-princ-line (strcat "  원본 용지: " (if sheet sheet "<unknown>")))
      (swcad-title-princ-line (strcat "  용지/도면틀: " (if frame-block frame-block "<unknown>")))
      (swcad-title-princ-line (strcat "  제목블록: " (if title-block title-block "<unknown>")))
      (swcad-title-princ-line (strcat "  처리 유형: " (if role role "<unknown>")))
    )
  )
)

(defun swcad-title-print-compact-next-gmtitle-card (summary missing-required-native example-title a3a4-count / source-count record frame-block title-block role pair sheet)
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq record nil)
  (cond
    ((> a3a4-count 0)
      (setq record nil)
    )
    ((and (not example-title) (> source-count 0))
      (setq record (swcad-title-next-bootstrap-selection-record))
    )
    ((and missing-required-native (not (swcad-title-next-fast-target-ready-p)))
      (setq record (swcad-title-next-missing-native-selection-record summary missing-required-native))
    )
  )
  (if record
    (progn
      (setq frame-block (cadr record))
      (setq title-block (caddr record))
      (setq role (if (cadddr record) (cadddr record) "title-sheet"))
      (swcad-title-princ-line "짧은 GMTITLE 선택 카드:")
      (swcad-title-princ-line "  다음 명령: SWTITLECONVERTNEXT")
      (swcad-title-princ-line (strcat "  용지/도면틀: " (if frame-block frame-block "<unknown>")))
      (swcad-title-princ-line (strcat "  제목블록: " (if title-block title-block "<unknown>")))
      (if (equal role "frame-only")
        (swcad-title-princ-line "  참고: 이 대상은 표제란 없는 도면틀-only 흐름입니다. 원본에 없던 제목블록은 만들지 않습니다.")
        (progn
          (swcad-title-princ-line "  켜둘 옵션: Frame positioning")
          (swcad-title-princ-line "  꺼둘 옵션: Object move")
        )
      )
      (swcad-title-princ-line "  취소 조건: ISO 용지/제목블록, Object move ON, 예상과 다른 DR 용지가 보이면 확인하지 말고 취소하세요.")
    )
    (if (> a3a4-count 0)
      (progn
        (setq pair (car (swcad-title-a3a4-native-upgrade-candidate-records)))
        (setq frame-block (if pair (caddr pair) "DR_A*_Outline"))
        (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
        (swcad-title-princ-line "짧은 GMTITLE 선택 카드:")
        (swcad-title-princ-line "  다음 명령: SWTITLECONVERTNEXT")
        (swcad-title-princ-line "  대상: A2/A3/A4 native 교체 후보 다음 1장")
        (swcad-title-princ-line "  우선순위: native 교체 후보가 title-missing/frame-only 예외 준비보다 먼저입니다.")
        (swcad-title-princ-line (strcat "  용지/도면틀: " (if frame-block frame-block "DR_A*_Outline")))
        (swcad-title-princ-line (strcat "  제목블록: " (swcad-title-target-title-block-name)))
        (swcad-title-princ-line (strcat "  원본 용지: " (if sheet sheet "<unknown>")))
        (swcad-title-princ-line "  켜둘 옵션: Frame positioning")
        (swcad-title-princ-line "  꺼둘 옵션: Object move")
        (swcad-title-princ-line "  취소 조건: ISO 용지/제목블록, Object move ON, 예상과 다른 DR 용지가 보이면 확인하지 말고 취소하세요.")
      )
    )
  )
)

(defun swcad-title-print-manual-gmtitle-forecast (summary expected-sheet-counts frame-only-count example-title a3a4-count missing-required-native / source-count a2-count a3-count a4-count record frame-block title-block)
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq a2-count (swcad-title-count-value "A2" expected-sheet-counts))
  (setq a3-count (swcad-title-count-value "A3" expected-sheet-counts))
  (setq a4-count (swcad-title-count-value "A4" expected-sheet-counts))
  (swcad-title-princ-line "예상 수동 GMTITLE 확인량:")
  (swcad-title-princ-line
    (strcat
      "  - 변환 기준 시트 수: A2 "
      (itoa a2-count)
      "장, A3 "
      (itoa a3-count)
      "장, A4 "
      (itoa a4-count)
      "장"
    )
  )
  (cond
    ((and (not example-title) (> source-count 0))
      (setq record (swcad-title-next-bootstrap-selection-record))
      (setq frame-block (if record (cadr record) "<unknown>"))
      (setq title-block (if record (caddr record) "<unknown>"))
      (swcad-title-princ-line
        (strcat
          "  - 지금 필요한 확인: "
          frame-block
          " / "
          title-block
          " 1회"
        )
      )
      (if (> a3-count 0)
        (swcad-title-princ-line "  - 이후 예상: A3를 처리하기 위한 첫 native 기준 객체 1회가 추가로 필요할 수 있습니다.")
      )
    )
    ((> a3a4-count 0)
      (swcad-title-princ-line
        (strcat
          "  - 지금 필요한 확인: A2/A3/A4 native 교체 후보 "
          (itoa a3a4-count)
          "개 중 다음 1개"
        )
      )
    )
    ((> source-count 0)
      (setq record (swcad-title-next-bootstrap-selection-record))
      (setq frame-block (if record (cadr record) "<unknown>"))
      (setq title-block (if record (caddr record) (swcad-title-target-title-block-name)))
      (swcad-title-princ-line
        (strcat
          "  - 지금 필요한 확인: "
          frame-block
          " / "
          title-block
          " 1회"
        )
      )
      (swcad-title-princ-line "  - 우선순위: 남은 원본 표제란 시트 변환이 title-missing/frame-only 예외보다 먼저입니다.")
      (if missing-required-native
        (swcad-title-princ-line
          (strcat
            "  - 아직 없는 native 기준 객체 "
            (swcad-title-list-string missing-required-native)
            "은 남은 원본 표제란 변환 뒤 필요한 경우 처리합니다."
          )
        )
      )
    )
    (missing-required-native
      (setq record (swcad-title-next-missing-native-selection-record summary missing-required-native))
      (setq frame-block (if record (cadr record) (car missing-required-native)))
      (setq title-block (if record (caddr record) (swcad-title-target-title-block-name)))
      (swcad-title-princ-line
        (strcat
          "  - 지금 필요한 확인: "
          (if frame-block frame-block "<unknown>")
          " / "
          (if title-block title-block "<unknown>")
          " 1회"
        )
      )
      (swcad-title-princ-line
        (strcat
          "  - 아직 없는 native 기준 객체: "
          (swcad-title-list-string missing-required-native)
        )
      )
    )
    (T
      (swcad-title-princ-line "  - 지금 필요한 확인: 새 GMTITLE 창 확인 없음")
    )
  )
  (if (> frame-only-count 0)
    (swcad-title-princ-line
      (strcat
        "  - title-missing/frame-only 도면틀 "
        (itoa frame-only-count)
        "장은 원본 표제란 부재가 검증된 경우에만 제목블록 생성 대상에서 제외합니다. 같은 크기 DR_A*_Outline 도면틀-only 경로로 처리합니다."
      )
    )
  )
  (swcad-title-princ-line "  - 좌표 입력, 값 복사, 기존 원본 정리는 SWTITLECONVERTNEXT/SWTITLECONVERT 흐름이 처리합니다.")
)

(defun swcad-title-fast-prerequisite-status (summary contaminated example-title / source-count frame-only-count missing-required frame-records geometry-risk-count overlap-risk-count)
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
  (setq missing-required (swcad-title-missing-required-native-frame-blocks summary))
  (setq frame-records (swcad-title-frame-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (cond
    ((> geometry-risk-count 0) "WARN_TARGET_FRAME_GEOMETRY_INVALID")
    ((> overlap-risk-count 0) "WARN_TARGET_FRAME_SELECTION_RISK")
    ((and (= source-count 0) (= frame-only-count 0)) "OK_NO_REMAINING_SOURCES")
    ((and (= source-count 0) (> frame-only-count 0) (swcad-title-title-missing-outline-definition-needed-p)) "WAITING_FOR_TITLE_MISSING_OUTLINE_DEFINITION")
    ((and (= source-count 0) (> frame-only-count 0) (swcad-title-title-missing-outline-policy-blocked-p)) "READY_FOR_TITLE_MISSING_OUTLINE")
    ((not example-title) "WAITING_FOR_NATIVE_GMTITLE_EXEMPLAR")
    ((and missing-required (swcad-title-next-fast-target-ready-p)) "PARTIAL_READY_FOR_FAST_BATCH")
    (missing-required "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
    (T "OK_READY_FOR_FAST_BATCH")
  )
)

(defun swcad-title-bootstrap-first-native-success-p (status)
  (or
    (equal status "APPLIED_TITLE_TRANSFER")
    (equal status "FINALIZED_EXISTING_GMTITLE_TRANSFER")
    (equal status "ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER")
  )
)

(defun swcad-title-fast-status (/ summary contaminated example-title status frame-records geometry-risk-count overlap-risk-count)
  (swcad-title-open-fast-status-log)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq example-title (swcad-title-native-example-title))
  (setq frame-records (swcad-title-frame-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq status (swcad-title-fast-prerequisite-status summary contaminated example-title))
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 빠른 일괄 변환 준비 상태(읽기 전용) -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Read-only document: "
      (if (swcad-title-document-read-only-p) "yes" "no")
    )
  )
  (swcad-title-print-fast-sheet-summary summary)
  (if
    (and
      (not example-title)
      (> (swcad-title-fast-summary-value summary "source-title-count") 0)
    )
    (swcad-title-print-next-bootstrap-selection)
  )
  (swcad-title-princ-line
    (strcat
      "Any native GMTITLE title: "
      (swcad-title-native-example-description example-title)
    )
  )
  (swcad-title-print-native-exemplars-by-frame)
  (swcad-title-print-required-native-exemplars summary)
  (swcad-title-print-next-fast-target-readiness)
  (swcad-title-princ-line
    (strcat "Contaminated target frame definitions: " (swcad-title-list-string contaminated))
  )
  (if contaminated
    (swcad-title-princ-line "경고: 이 도면틀 정의는 설치 기본 내부 구조일 수도 있고 실제 오염일 수도 있습니다. 동일 크기 clone에는 여전히 같은 크기의 native GMTITLE 기준 객체가 필요합니다.")
  )
  (if (or (> geometry-risk-count 0) (> overlap-risk-count 0))
    (swcad-title-print-target-frame-selection-diagnostics frame-records)
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (cond
    ((equal status "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (swcad-title-princ-line "다음: SWTITLEVERIFY로 형상을 확인한 뒤, 문제가 있는 용지 크기의 GMTITLE 도면틀을 다시 만들거나 복구하세요.")
    )
    ((equal status "WARN_TARGET_FRAME_SELECTION_RISK")
      (swcad-title-princ-line "다음: 더블클릭 확인 전에 SWTITLEVERIFY로 겹치는 도면틀/제목블록 영역을 확인하세요.")
    )
    ((equal status "WAITING_FOR_NATIVE_GMTITLE_EXEMPLAR")
      (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행하세요. 첫 native GMTITLE 단계의 반복 응답을 자동 선택합니다.")
      (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
    )
    ((equal status "READY_FOR_TITLE_MISSING_OUTLINE")
      (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행하세요. 원본에 없던 제목블록은 만들지 않고 해당 DR 도면틀만 교체합니다.")
      (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
      (swcad-title-princ-line "형상 검사를 통과하지 못하면 새 도면틀은 삭제하고 기존 원본 도면틀은 보존합니다.")
    )
    ((equal status "WAITING_FOR_TITLE_MISSING_OUTLINE_DEFINITION")
      (swcad-title-print-title-missing-outline-definition-status)
      (swcad-title-princ-line "다음: SWTITLEPREPARE를 실행해 대상 DR 도면틀 정의를 먼저 가져오고 검증하세요.")
      (swcad-title-princ-line "검증 전에는 기존 원본 도면틀을 삭제하지 않습니다.")
    )
    ((equal status "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행해서 누락된 같은 크기의 native GMTITLE 기준 객체를 만들거나 안내받으세요.")
      (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
    )
    ((equal status "PARTIAL_READY_FOR_FAST_BATCH")
      (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행하세요. 준비된 용지 크기를 처리하고, 다음 누락 크기에서 멈춥니다.")
      (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
    )
    ((equal status "OK_READY_FOR_FAST_BATCH")
      (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행하세요.")
      (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-print-automation-policy-summary ()
  (swcad-title-princ-line "자동화 분담: LSP는 시트 탐지, 값 추출, 왼쪽 아래 배치점 계산, 새 GMTITLE 결과 검사, 값 입력, 기존 객체 정리를 처리합니다.")
  (swcad-title-princ-line "사람 확인: GMTITLE 창에서는 표시된 DR_A*_Outline, DR_titlea_3rd, Frame positioning ON, Object move OFF를 눈으로 확인해야 합니다.")
  (if *swcad-title-allow-commandline-gmtitle*
    (progn
      (swcad-title-princ-line "자동화 판단: 명령줄 -GMTITLE 실험 플래그가 켜져 있습니다.")
      (swcad-title-princ-line "자동화 판단: 이 경로는 work 복사본에서 새 INSERT/도면틀/제목블록/native-like 검증이 모두 통과할 때만 사용하세요.")
    )
    (progn
      (swcad-title-princ-line "자동화 판단: 명령줄 -GMTITLE/설정파일 자동 선택은 기본 OFF입니다.")
      (swcad-title-princ-line "자동화 판단: 로컬 조사상 paperset.grx가 native GMTITLE 구조를 만들며, DR 기본 선택값을 설정파일로 고정하는 근거는 아직 없습니다.")
      (swcad-title-princ-line "자동화 판단: PaperSet.ini/dat는 용지 크기/DrawWithBlock 수준이고, HKCU PAPERSET.GRX-66은 대화상자 위치/크기만 확인됐습니다.")
      (swcad-title-princ-line "자동화 판단: GMTITLE 창이 열리면 DR_A*_Outline과 DR_titlea_3rd를 눈으로 확인하세요. 화면 좌표 클릭 자동화는 사용하지 않습니다.")
    )
  )
)

(defun swcad-title-print-native-batch-safety-guidance ()
  (swcad-title-princ-line "BATCH 안전 조건: 먼저 OPEN으로 1장을 성공시킨 뒤 SWTITLESTATUS/direct probe에서 후보 수가 줄었는지 확인하세요.")
  (swcad-title-princ-line "BATCH 사용 시점: 남은 후보들이 같은 DR 용지/DR_titlea_3rd/Frame positioning ON/Object move OFF로 반복된다고 눈으로 확인될 때만 사용하세요.")
  (swcad-title-princ-line "BATCH 금지 조건: 첫 후보부터 바로 BATCH를 쓰거나, GMTITLE 창이 DR이 아닌 일반/ISO 기본값이면 진행하지 마세요.")
)

(defun swcad-title-next-step (/ summary source-count frame-only-count source-frame-count contaminated definition-raw-risk-records definition-raw-risk-count example-title frame-records orphan-records orphan-count invalid-title-missing-records invalid-title-missing-count geometry-risk-count overlap-risk-count selection-risk-count target-sheet-counts stored-expected-sheet-counts expected-sheet-counts count-shortage-records count-excess-records target-title-sheet-counts stored-expected-title-counts expected-title-counts title-count-shortage-records missing-target-sheets missing-required-native a3a4-records a3a4-count style-records style-count command-text-count next-frame-block)
  (swcad-title-open-next-step-log)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq source-frame-count (swcad-title-fast-summary-value summary "source-frame-count"))
  (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq definition-raw-risk-records (swcad-title-frame-definition-raw-bbox-risk-records))
  (setq definition-raw-risk-count (length definition-raw-risk-records))
  (setq example-title (swcad-title-native-example-title))
  (setq frame-records (swcad-title-frame-records))
  (setq orphan-records (swcad-title-orphan-target-frame-records))
  (setq orphan-count (length orphan-records))
  (setq invalid-title-missing-records (swcad-title-title-missing-outline-with-loose-title-records))
  (setq invalid-title-missing-count (length invalid-title-missing-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq selection-risk-count (+ geometry-risk-count overlap-risk-count))
  (setq target-sheet-counts (swcad-title-target-frame-sheet-counts))
  (setq stored-expected-sheet-counts (swcad-title-stored-expected-sheet-counts))
  (setq expected-sheet-counts
    (if stored-expected-sheet-counts
      stored-expected-sheet-counts
      (swcad-title-current-total-sheet-counts summary)
    )
  )
  (setq count-shortage-records (swcad-title-count-shortage-records expected-sheet-counts target-sheet-counts))
  (setq count-excess-records (swcad-title-count-excess-records expected-sheet-counts target-sheet-counts))
  (setq target-title-sheet-counts (swcad-title-target-title-sheet-counts))
  (setq stored-expected-title-counts (swcad-title-stored-expected-title-counts))
  (setq expected-title-counts
    (if stored-expected-title-counts
      stored-expected-title-counts
      (swcad-title-current-total-title-counts summary)
    )
  )
  (setq title-count-shortage-records (swcad-title-count-shortage-records expected-title-counts target-title-sheet-counts))
  (setq missing-target-sheets (swcad-title-missing-required-target-sheets target-sheet-counts (swcad-title-active-required-sheets summary)))
  (setq missing-required-native (swcad-title-missing-required-native-frame-blocks summary))
  (setq a3a4-records (swcad-title-a3a4-native-upgrade-candidate-records))
  (setq a3a4-count (length a3a4-records))
  (setq style-records (swcad-title-frame-style-normalization-records))
  (setq style-count (length style-records))
  (setq command-text-count (swcad-title-command-text-residue-count))

  (swcad-title-princ-line "----- SWTITLESTATUS 내부 다음 단계 안내(읽기 전용) -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-print-log-evidence-note)
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "읽기 전용 도면: " (if (swcad-title-document-read-only-p) "예" "아니오")))
  (swcad-title-princ-line (strcat "남은 원본 표제란 시트: " (itoa source-count)))
  (swcad-title-princ-line (strcat "남은 원본 도면틀: " (itoa source-frame-count)))
  (swcad-title-princ-line (strcat "남은 표제란 없는 도면틀 시트: " (itoa frame-only-count)))
  (swcad-title-print-counts "변환 기준 전체 용지 수:" expected-sheet-counts)
  (swcad-title-princ-line
    (strcat
      "변환 기준 수량 출처: "
      (if stored-expected-sheet-counts
        "도면 xdata 기록"
        "현재 원본+대상 상태 추정"
      )
    )
  )
  (swcad-title-print-counts "용지별 보이는 대상 도면틀 수:" target-sheet-counts)
  (swcad-title-print-count-deltas "대상 도면틀 수량 부족:" count-shortage-records)
  (swcad-title-print-count-deltas "대상 도면틀 수량 초과:" count-excess-records)
  (swcad-title-print-counts "변환 기준 제목 보유 시트 수:" expected-title-counts)
  (swcad-title-print-counts "용지별 보이는 대상 제목블록 수:" target-title-sheet-counts)
  (swcad-title-print-count-deltas "대상 제목블록 수량 부족:" title-count-shortage-records)
  (swcad-title-print-string-list "현재 필요한 대상 용지 누락:" missing-target-sheets)
  (swcad-title-princ-line (strcat "A2/A3/A4 native 교체 후보: " (itoa a3a4-count)))
  (swcad-title-princ-line (strcat "도면틀 스타일 정규화 필요 후보: " (itoa style-count)))
  (swcad-title-princ-line (strcat "실수 명령어 텍스트 후보: " (itoa command-text-count)))
  (swcad-title-princ-line (strcat "도면틀 정의 raw bbox 위험: " (itoa definition-raw-risk-count)))
  (swcad-title-princ-line (strcat "선택/형상 위험 경고: " (itoa selection-risk-count)))
  (swcad-title-princ-line (strcat "제목블록 없는 고아 GMTITLE 도면틀: " (itoa orphan-count)))
  (swcad-title-princ-line (strcat "제목 MTEXT가 남은 잘못된 title-missing 대상: " (itoa invalid-title-missing-count)))
  (swcad-title-princ-line (strcat "오염 의심 대상 도면틀 정의: " (swcad-title-list-string contaminated)))
  (swcad-title-princ-line (strcat "native GMTITLE 제목블록 존재: " (swcad-title-native-example-description example-title)))
  (swcad-title-print-manual-gmtitle-forecast summary expected-sheet-counts frame-only-count example-title a3a4-count missing-required-native)
  (swcad-title-print-compact-next-gmtitle-card summary missing-required-native example-title a3a4-count)
  (swcad-title-print-automation-policy-summary)
  (if a3a4-records
    (progn
      (swcad-title-princ-line "A2/A3/A4 후보 상세:")
      (swcad-title-print-a3a4-native-upgrade-candidates)
    )
  )

  (if (not (swcad-title-current-dwg-in-work-p))
    (swcad-title-princ-line "작업본 안내: 다음 SWTITLEPREPARE/SWTITLECONVERTNEXT 실행 시 다른 이름으로 저장 창에서 새 작업본 위치를 먼저 선택합니다.")
  )
  (if (swcad-title-document-read-only-p)
    (swcad-title-princ-line "읽기 전용 원본 안내: 원본을 직접 수정하지 않고, 선택한 새 작업본에 저장한 뒤 변환합니다.")
  )

  (cond
    ((> command-text-count 0)
      (swcad-title-apply-result "NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT")
      (swcad-title-princ-line "이유: CAD가 문자/입력 상태였을 때 명령어 글자가 도면에 들어갔을 수 있습니다.")
      (swcad-title-princ-line "다음: 계속하기 전에 SWTITLESTATUS로 명령어 텍스트 잔여물 후보를 확인하세요.")
      (swcad-title-princ-line "목록의 항목이 작업복사본 안의 실수 명령어 잔여물이 맞다면 SWTITLEPREPARE에서 정리하세요.")
      (swcad-title-princ-line "작업복사본에서 확인/정리하기 전에는 변환 명령을 실행하지 마세요.")
    )
    ((> style-count 0)
      (swcad-title-apply-result "NEXT_PREPARE_FRAME_STYLE_NORMALIZATION")
      (swcad-title-princ-line "이유: CAD native DR 도면틀 안의 static 표제란 형상이 별도 DR_titlea_3rd와 겹쳐 표제란이 두 개처럼 보일 수 있습니다.")
      (swcad-title-print-frame-style-normalization-records style-records)
      (swcad-title-princ-line "다음: SWTITLEPREPARE로 도면틀 스타일 정규화 후보를 확인하세요.")
      (swcad-title-princ-line "이 상태에서 SWTITLECONVERT를 반복하면 같은 중복 모양이 여러 장으로 복제될 수 있습니다.")
    )
    ((> definition-raw-risk-count 0)
      (swcad-title-apply-result "NEXT_REVIEW_FRAME_DEFINITION_RAW_BBOX")
      (swcad-title-princ-line "이유: DR 도면틀 정의 자체의 raw bbox가 예상 용지보다 과도하게 큽니다.")
      (swcad-title-print-frame-definition-raw-bbox-risk-records definition-raw-risk-records)
      (swcad-title-princ-line "다음: 현재 단계에서는 SWTITLECONVERT를 반복하지 말고, 정의 복구/정규화 설계를 먼저 확인하세요.")
      (swcad-title-princ-line "기존 원본 도면틀은 raw bbox 검사를 통과하기 전까지 삭제하지 않습니다.")
    )
    ((> geometry-risk-count 0)
      (swcad-title-apply-result "NEXT_REVIEW_TARGET_FRAME_GEOMETRY")
      (swcad-title-princ-line "다음: 계속하기 전에 SWTITLEVERIFY로 잘못된 대상 도면틀 형상을 확인하세요.")
    )
    ((> overlap-risk-count 0)
      (swcad-title-apply-result "NEXT_REVIEW_TARGET_FRAME_SELECTION")
      (swcad-title-princ-line "다음: SWTITLEVERIFY로 겹치거나 과도하게 큰 대상 도면틀 선택 위험을 확인하세요.")
    )
    ((> orphan-count 0)
      (swcad-title-apply-result "NEXT_CLEAN_ORPHAN_TARGET_FRAMES")
      (swcad-title-print-orphan-target-frame-records orphan-records)
      (swcad-title-princ-line "다음: SWTITLEPREPARE를 실행해 제목블록 없는 GMTITLE 도면틀을 먼저 정리하세요.")
      (swcad-title-princ-line "이 상태에서 다음 용지로 넘어가면 A2/A3/A4 title-sheet 완료 판단이 어긋날 수 있습니다.")
    )
    ((or (> invalid-title-missing-count 0) title-count-shortage-records)
      (swcad-title-apply-result "NEXT_REVIEW_MISSING_NATIVE_TITLES")
      (swcad-title-princ-line "이유: 제목 정보가 있던 시트에 DR_titlea_3rd가 없거나, 기존 일반 제목 MTEXT만 남아 있습니다.")
      (swcad-title-princ-line "다음: SWTITLEVERIFY 상세를 확인하고, 원본 work 복사본에서 통합 변환을 다시 실행하세요.")
      (swcad-title-princ-line "13개 제목블록 / 15개 도면틀 상태를 완료로 사용하지 마세요.")
    )
    ((> a3a4-count 0)
      (swcad-title-apply-result "NEXT_UPGRADE_NATIVE_GMTITLE")
      (if (> frame-only-count 0)
        (progn
          (swcad-title-princ-line
            (strcat
              "참고: "
              (itoa frame-only-count)
              "개의 표제란 없는 도면틀 시트가 아직 남아 있습니다. 원본 제목블록 부재가 검증된 경우에만 title-missing 예외로 처리합니다."
            )
          )
          (swcad-title-princ-line "SWTITLECONVERTNEXT는 이미 만들어진 A2/A3/A4 GMTITLE 중 더블클릭 동작을 신뢰할 수 없는 쌍을 먼저 한 장씩 교체합니다.")
          (swcad-title-princ-line "그 뒤 SWTITLESTATUS를 다시 실행하면 남은 title-missing 도면틀 시트의 같은 크기 DR_A*_Outline 기준 객체 필요 여부를 확인할 수 있습니다.")
        )
      )
      (if (> a3a4-count 1)
        (progn
          (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행하면 다음 A2/A3/A4 native 교체 후보 1장만 처리합니다.")
          (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
          (swcad-title-princ-line (strcat "현재 A2/A3/A4 교체 후보는 " (itoa a3a4-count) "개입니다. GMTITLE 창을 안전하게 확인하기 위해 한 번에 1장만 처리합니다."))
          (swcad-title-princ-line "다음 후보의 native GMTITLE 창을 열고, 기존 제목블록 값을 복사한 뒤 이전 복제/non-native 쌍을 삭제합니다.")
          (swcad-title-princ-line "GMTITLE 창에서는 출력된 DR_A*_Outline 용지와 DR_titlea_3rd를 고르세요. Frame positioning은 ON, Object move는 OFF로 두세요.")
          (swcad-title-princ-line "나머지 A2/A3/A4 후보는 SWTITLESTATUS와 SWTITLECONVERTNEXT를 반복해서 처리하세요. 보조 복구 명령은 진단용입니다.")
        )
        (progn
          (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행하세요.")
          (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
          (swcad-title-princ-line "GMTITLE 창에서는 출력된 DR_A*_Outline 용지와 DR_titlea_3rd를 고르고, Frame positioning은 ON, Object move는 OFF로 두세요.")
        )
      )
    )
    ((or (> source-count 0) (> frame-only-count 0))
      (cond
        ((and (= source-count 0) (> frame-only-count 0) (swcad-title-title-missing-outline-definition-needed-p))
          (swcad-title-apply-result "NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION")
          (swcad-title-print-title-missing-outline-definition-status)
          (swcad-title-princ-line "다음: SWTITLEPREPARE를 실행하세요. 같은 크기 DR_A*_Outline 정의를 가져와 형상/선택범위를 먼저 검사합니다.")
          (swcad-title-princ-line "이 검사를 통과하기 전에는 SWTITLECONVERTNEXT가 기존 원본 도면틀을 삭제하지 않습니다.")
        )
        ((and (= source-count 0) (> frame-only-count 0) (swcad-title-title-missing-outline-policy-blocked-p))
          (swcad-title-apply-result "READY_FOR_TITLE_MISSING_OUTLINE")
          (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행하세요. 원본 표제란 부재가 검증된 시트는 도면틀만 교체합니다.")
          (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
          (swcad-title-princ-line "원본에 없던 DR_titlea_3rd 제목블록은 만들지 않습니다.")
        )
        ((not example-title)
          (swcad-title-apply-result "NEXT_CREATE_FIRST_NATIVE_GMTITLE")
          (swcad-title-print-next-bootstrap-selection)
          (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행하세요. 첫 native GMTITLE 단계를 내부에서 엽니다.")
          (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
          (swcad-title-princ-line "GMTITLE 창에서는 위 용지/도면틀과 제목블록을 고르고, Frame positioning은 ON, Object move는 OFF로 두세요.")
        )
        ((and missing-required-native (not (swcad-title-next-fast-target-ready-p)))
          (swcad-title-apply-result "NEXT_CREATE_MISSING_NATIVE_EXEMPLAR")
          (swcad-title-print-required-native-exemplars summary)
          (swcad-title-print-next-missing-native-selection summary missing-required-native)
          (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행하세요. 가능한 경우 누락된 정확한 크기의 native GMTITLE 단계를 내부에서 안내합니다.")
          (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
        )
        (T
          (setq next-frame-block (swcad-title-next-fast-target-frame-block))
          (swcad-title-apply-result "NEXT_RUN_FAST_BATCH")
          (swcad-title-princ-line (strcat "다음: SWTITLECONVERTNEXT를 실행하세요. 다음 대상 도면틀=" (if next-frame-block next-frame-block "<unknown>")))
          (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
        )
      )
    )
    (missing-target-sheets
      (swcad-title-apply-result "NEXT_CREATE_MISSING_TARGET_SHEET")
      (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행해서 가능한 경우 누락된 대상 용지 크기를 만들고 finalize하세요.")
      (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
    )
    ((and (= source-frame-count 0) count-shortage-records)
      (swcad-title-apply-result "NEXT_REVIEW_TARGET_SHEET_COUNT_SHORTAGE")
      (swcad-title-princ-line "다음: SWTITLEVERIFY 로그에서 부족한 대상 용지 수량을 확인하세요.")
      (swcad-title-princ-line "원본 도면틀이 모두 사라진 상태에서 target 수량이 부족하므로 변환 완료로 볼 수 없습니다.")
    )
    (T
      (swcad-title-apply-result "NEXT_FINAL_VERIFY_AND_DOUBLE_CLICK")
      (swcad-title-princ-line "다음: SWTITLEVERIFY를 실행하세요.")
      (swcad-title-princ-line "최종 수동 확인: GstarCAD에서 실제 DR_titlea_3rd 제목블록이 있는 대표 용지만 더블클릭하세요.")
      (swcad-title-princ-line "원본 표제란이 없는 title-missing/frame-only 시트는 더블클릭할 제목블록이 없으므로 SWTITLEVERIFY의 도면틀 수량/형상 검증으로 확인하세요.")
    )
  )
  (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-status-refresh-summary (/ summary source-count source-frame-count frame-only-count target-sheet-counts missing-target-sheets a3a4-count command-text-count geometry-risk-count overlap-risk-count frame-records orphan-records orphan-count invalid-title-missing-count status)
  (swcad-title-open-status-refresh-log)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq source-frame-count (swcad-title-fast-summary-value summary "source-frame-count"))
  (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
  (setq target-sheet-counts (swcad-title-target-frame-sheet-counts))
  (setq missing-target-sheets (swcad-title-missing-required-target-sheets target-sheet-counts (swcad-title-active-required-sheets summary)))
  (setq a3a4-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
  (setq command-text-count (swcad-title-command-text-residue-count))
  (setq frame-records (swcad-title-frame-records))
  (setq orphan-records (swcad-title-orphan-target-frame-records))
  (setq orphan-count (length orphan-records))
  (setq invalid-title-missing-count (length (swcad-title-title-missing-outline-with-loose-title-records)))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 상태 요약 -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "남은 원본 표제란 시트: " (itoa source-count)))
  (swcad-title-princ-line (strcat "남은 원본 도면틀: " (itoa source-frame-count)))
  (swcad-title-princ-line (strcat "남은 표제란 없는 도면틀 시트: " (itoa frame-only-count)))
  (swcad-title-print-counts "용지별 보이는 대상 도면틀 수:" target-sheet-counts)
  (swcad-title-print-string-list "현재 필요한 대상 용지 누락:" missing-target-sheets)
  (swcad-title-princ-line (strcat "A2/A3/A4 native 교체 후보: " (itoa a3a4-count)))
  (swcad-title-princ-line (strcat "실수 명령어 텍스트 후보: " (itoa command-text-count)))
  (swcad-title-princ-line (strcat "대상 도면틀 형상 경고: " (itoa geometry-risk-count)))
  (swcad-title-princ-line (strcat "대상 도면틀 겹침 경고: " (itoa overlap-risk-count)))
  (swcad-title-princ-line (strcat "제목블록 없는 고아 GMTITLE 도면틀: " (itoa orphan-count)))
  (swcad-title-princ-line (strcat "제목 MTEXT가 남은 잘못된 title-missing 대상: " (itoa invalid-title-missing-count)))
  (setq status
    (cond
      ((> command-text-count 0) "NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT")
      ((> geometry-risk-count 0) "NEXT_REVIEW_TARGET_FRAME_GEOMETRY")
      ((> overlap-risk-count 0) "NEXT_REVIEW_TARGET_FRAME_SELECTION")
      ((> orphan-count 0) "NEXT_CLEAN_ORPHAN_TARGET_FRAMES")
      ((> invalid-title-missing-count 0) "NEXT_REVIEW_MISSING_NATIVE_TITLES")
      ((> a3a4-count 0) "NEXT_UPGRADE_NATIVE_GMTITLE")
      ((and (= source-count 0) (> frame-only-count 0) (swcad-title-title-missing-outline-definition-needed-p)) "NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION")
      ((and (= source-count 0) (> frame-only-count 0) (swcad-title-title-missing-outline-policy-blocked-p)) "READY_FOR_TITLE_MISSING_OUTLINE")
      ((or (> source-count 0) (> frame-only-count 0)) "NEXT_TRANSFER_REMAINING_SOURCE_SHEETS")
      (missing-target-sheets "NEXT_CREATE_MISSING_TARGET_SHEET")
      (T "NEXT_FINAL_VERIFY_AND_DOUBLE_CLICK")
    )
  )
  (swcad-title-apply-result status)
  (cond
    ((equal status "NEXT_UPGRADE_NATIVE_GMTITLE")
      (swcad-title-princ-line "다음 명령: SWTITLECONVERTNEXT")
      (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
      (swcad-title-princ-line (strcat "현재 표시된 A2/A3/A4 native 교체 후보는 " (itoa a3a4-count) "개입니다."))
      (swcad-title-princ-line "SWTITLECONVERTNEXT는 다음 후보 1장의 OPEN 응답을 자동 선택합니다. BATCH는 수동 SWTITLECONVERT에서만 직접 선택하세요.")
      (swcad-title-print-native-batch-safety-guidance)
      (swcad-title-princ-line "BATCH를 써도 각 GMTITLE 창의 DR 용지/DR_titlea_3rd/Frame positioning ON/Object move OFF 확인은 사람이 해야 합니다.")
      (swcad-title-princ-line "이미 만들어진 A2/A3/A4 GMTITLE 대상 쌍의 더블클릭 native 동작을 복구하는 단계입니다.")
      (if (> frame-only-count 0)
        (swcad-title-princ-line "원본 표제란이 없는 title-missing/frame-only 시트가 아직 남아 있습니다. 현재 native 교체가 끝난 뒤 처리합니다.")
      )
    )
    ((equal status "NEXT_CLEAN_ORPHAN_TARGET_FRAMES")
      (swcad-title-princ-line "다음 명령: SWTITLEPREPARE")
      (swcad-title-print-orphan-target-frame-records orphan-records)
      (swcad-title-princ-line "제목블록 없는 GMTITLE 도면틀은 title-missing 도면틀-only marker가 없는 한 완료된 title-sheet로 보지 않습니다.")
      (swcad-title-princ-line "정리 후 SWTITLESTATUS를 다시 실행하세요.")
    )
    ((equal status "NEXT_TRANSFER_REMAINING_SOURCE_SHEETS")
      (swcad-title-princ-line "다음 명령: SWTITLECONVERTNEXT")
      (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
      (if (> frame-only-count 0)
        (swcad-title-princ-line "원본 표제란이 없는 title-missing/frame-only 시트는 필요한 native 검사를 거친 뒤 같은 변환 흐름 안에서 처리됩니다.")
      )
    )
    ((equal status "READY_FOR_TITLE_MISSING_OUTLINE")
      (swcad-title-princ-line "다음 명령: SWTITLECONVERTNEXT")
      (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
      (swcad-title-princ-line "원본 표제란이 없는 title-missing/frame-only 시트는 원본에 없던 제목블록을 만들지 않고 도면틀만 교체합니다.")
      (swcad-title-princ-line "형상 검사를 통과하지 못하면 기존 원본 도면틀은 삭제하지 않습니다.")
    )
    ((equal status "NEXT_PREPARE_TITLE_MISSING_OUTLINE_DEFINITION")
      (swcad-title-princ-line "다음 명령: SWTITLEPREPARE")
      (swcad-title-print-title-missing-outline-definition-status)
      (swcad-title-princ-line "대상 DR 도면틀 정의 검증이 끝난 뒤 SWTITLESTATUS와 SWTITLECONVERTNEXT를 이어서 실행하세요.")
    )
    ((equal status "NEXT_FINAL_VERIFY_AND_DOUBLE_CLICK")
      (swcad-title-princ-line "다음 명령: SWTITLEVERIFY")
      (swcad-title-princ-line "최종 수동 확인: 실제 DR_titlea_3rd 제목블록이 있는 대표 용지만 더블클릭하세요. 원본 표제란이 없는 title-missing/frame-only 시트는 더블클릭할 제목블록이 없습니다.")
    )
    (T
      (swcad-title-princ-line "다음: 위 상태가 가리키는 상세 로그를 확인하세요.")
    )
  )
  (swcad-title-princ-line "SWTITLESTATUS가 갱신한 내부 로그:")
  (swcad-title-princ-line "  work/swcad_title_next_step_last.txt")
  (swcad-title-princ-line "  work/swcad_title_native_upgrade_last.txt")
  (swcad-title-princ-line "  work/swcad_title_gmtitle_verify_all_last.txt")
  (swcad-title-princ-line "  work/swcad_title_native_frame_check_last.txt")
  (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-safe-vla-object (ename / result)
  (setq result (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swcad-title-safe-vla-get (object property / result)
  (if object
    (progn
      (setq result (vl-catch-all-apply 'vlax-get-property (list object property)))
      (if (vl-catch-all-error-p result)
        nil
        result
      )
    )
    nil
  )
)

(defun swcad-title-block-definition-object (block-name / blocks result)
  (if (and block-name (swcad-title-block-exists-p block-name))
    (progn
      (setq blocks (vla-get-Blocks (swcad-title-doc)))
      (setq result (vl-catch-all-apply 'vla-Item (list blocks block-name)))
      (if (vl-catch-all-error-p result)
        nil
        result
      )
    )
    nil
  )
)

(defun swcad-title-block-definition-count (block-name / block count item)
  (setq block (swcad-title-block-definition-object block-name))
  (if block
    (progn
      (setq count 0)
      (vlax-for item block
        (setq count (+ count 1))
      )
      count
    )
    nil
  )
)

(defun swcad-title-effective-insert-name (ename / object name)
  (setq object (swcad-title-safe-vla-object ename))
  (if object
    (setq name (swcad-title-vla-block-name object))
    (setq name (swcad-title-dxf-value (entget ename '("*")) 2))
  )
  (swcad-title-string name)
)

(defun swcad-title-entity-type-name (ename / data)
  (setq data (if ename (entget ename '("*")) nil))
  (strcase (swcad-title-string (swcad-title-dxf-value data 0)))
)

(defun swcad-title-owner-ename (ename / data owner)
  (setq data (if ename (entget ename '("*")) nil))
  (setq owner (swcad-title-dxf-value data 330))
  (if (and owner (entget owner '("*")))
    owner
    nil
  )
)

(defun swcad-title-enclosing-insert-ename (ename / current owner guard)
  (setq current ename)
  (setq guard 0)
  (while
    (and
      current
      (< guard 8)
      (not (equal (swcad-title-entity-type-name current) "INSERT"))
    )
    (setq owner (swcad-title-owner-ename current))
    (if owner
      (setq current owner)
      (setq current nil)
    )
    (setq guard (+ guard 1))
  )
  (if (and current (equal (swcad-title-entity-type-name current) "INSERT"))
    current
    nil
  )
)

(defun swcad-title-find-insert-by-effective-name (block-name / target ss index total ename found)
  (setq target (strcase (swcad-title-string block-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq found nil)
  (while (and (< index total) (not found))
    (setq ename (ssname ss index))
    (if (equal (strcase (swcad-title-effective-insert-name ename)) target)
      (setq found ename)
    )
    (setq index (+ index 1))
  )
  found
)

(defun swcad-title-count-inserts-by-effective-name (block-name / target ss index total ename count)
  (setq target (strcase (swcad-title-string block-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq count 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (if (equal (strcase (swcad-title-effective-insert-name ename)) target)
      (setq count (+ count 1))
    )
    (setq index (+ index 1))
  )
  count
)

(defun swcad-title-inserts-by-effective-name (block-name / target ss index total ename result)
  (setq target (strcase (swcad-title-string block-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq result nil)
  (while (< index total)
    (setq ename (ssname ss index))
    (if (equal (strcase (swcad-title-effective-insert-name ename)) target)
      (setq result (append result (list ename)))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-all-insert-references-by-effective-name (block-name / target result ss index total ename blocks block item item-ename)
  (setq target (strcase (swcad-title-string block-name)))
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (if (equal (strcase (swcad-title-effective-insert-name ename)) target)
      (setq result (swcad-title-list-add-unique ename result))
    )
    (setq index (+ index 1))
  )
  (setq blocks (vla-get-Blocks (swcad-title-doc)))
  (vlax-for block blocks
    (vlax-for item block
      (setq item-ename (swcad-title-vla-object->ename item))
      (if
        (and
          item-ename
          (equal (swcad-title-entity-type-name item-ename) "INSERT")
          (equal (strcase (swcad-title-effective-insert-name item-ename)) target)
        )
        (setq result (swcad-title-list-add-unique item-ename result))
      )
    )
  )
  result
)

(defun swcad-title-attribute-value (attribute / value)
  (setq value (vl-catch-all-apply 'vla-get-TextString (list attribute)))
  (if (vl-catch-all-error-p value) "" value)
)

(defun swcad-title-title-attribute-pairs (insert-object / attrs attr result)
  (setq attrs (swcad-title-get-insert-attributes insert-object))
  (setq result nil)
  (foreach attr attrs
    (setq result
      (append
        result
        (list
          (cons
            (swcad-title-attribute-tag attr)
            (swcad-title-attribute-value attr)
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-normalized-field-value (value)
  (vl-string-trim " \t\r\n" (swcad-title-string value))
)

(defun swcad-title-value-verification-errors (insert-object expected-values / actual-values errors expected actual-pair expected-value actual-value)
  (setq actual-values (swcad-title-title-attribute-pairs insert-object))
  (setq errors nil)
  (foreach expected expected-values
    (setq actual-pair (assoc (car expected) actual-values))
    (setq expected-value (swcad-title-normalized-field-value (cdr expected)))
    (setq actual-value
      (if actual-pair
        (swcad-title-normalized-field-value (cdr actual-pair))
        "<missing-tag>"
      )
    )
    (if (/= expected-value actual-value)
      (setq errors
        (append
          errors
          (list (list (car expected) expected-value actual-value))
        )
      )
    )
  )
  errors
)

(defun swcad-title-print-value-verification-errors (errors / record)
  (if errors
    (progn
      (swcad-title-princ-line "제목블록 속성값 검증 실패:")
      (foreach record errors
        (swcad-title-princ-line
          (strcat
            "  " (car record)
            ": expected=\"" (cadr record)
            "\", actual=\"" (caddr record) "\""
          )
        )
      )
    )
    (swcad-title-princ-line "제목블록 속성값 검증: 일치")
  )
)

(defun swcad-title-missing-template-tags (attr-pairs / missing slot tag)
  (setq missing nil)
  (foreach slot *swcad-title-transfer-template*
    (setq tag (car slot))
    (if (not (assoc tag attr-pairs))
      (setq missing (append missing (list tag)))
    )
  )
  missing
)

(defun swcad-title-nonempty-attribute-count (attr-pairs / count pair value)
  (setq count 0)
  (foreach pair attr-pairs
    (setq value (vl-string-trim " \t\r\n" (swcad-title-string (cdr pair))))
    (if (> (strlen value) 0)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-xdata-records (ename / data result pair item)
  (setq data (entget ename '("*")))
  (setq result nil)
  (foreach pair data
    (if (and (listp pair) (= (car pair) -3))
      (foreach item (cdr pair)
        (if (listp item)
          (setq result (append result (list item)))
        )
      )
    )
  )
  result
)

(defun swcad-title-xdata-record-app-name (record)
  (if (and (listp record) (= (type (car record)) 'STR))
    (car record)
    ""
  )
)

(defun swcad-title-xdata-record-by-app (ename app / records target result record)
  (setq records (swcad-title-xdata-records ename))
  (setq target (strcase (swcad-title-string app)))
  (setq result nil)
  (foreach record records
    (if
      (and
        (not result)
        (equal (strcase (swcad-title-xdata-record-app-name record)) target)
      )
      (setq result record)
    )
  )
  result
)

(defun swcad-title-xdata-text-values (record / result pair)
  (setq result nil)
  (foreach pair (cdr record)
    (if (and (listp pair) (= (car pair) 1000))
      (setq result (append result (list (swcad-title-string (cdr pair)))))
    )
  )
  result
)

(defun swcad-title-remove-xdata-app-from-data (data app / target result pair kept record)
  (setq target (strcase (swcad-title-string app)))
  (setq result nil)
  (foreach pair data
    (if (and (listp pair) (= (car pair) -3))
      (progn
        (setq kept nil)
        (foreach record (cdr pair)
          (if (not (equal (strcase (swcad-title-xdata-record-app-name record)) target))
            (setq kept (append kept (list record)))
          )
        )
        (if kept
          (setq result (append result (list (cons -3 kept))))
        )
      )
      (setq result (append result (list pair)))
    )
  )
  result
)

(defun swcad-title-ensure-regapp (app / result)
  (if (tblsearch "APPID" app)
    T
    (progn
      (setq result (vl-catch-all-apply 'regapp (list app)))
      (not (vl-catch-all-error-p result))
    )
  )
)

(defun swcad-title-set-exemplar-xdata (ename frame-block role / app marker data clean record result expected-counts expected-title-counts count-pair)
  (setq app *swcad-title-exemplar-xdata-app*)
  (setq marker *swcad-title-exemplar-xdata-marker*)
  (if
    (and
      ename
      (swcad-title-ensure-regapp app)
      (setq data (entget ename '("*")))
    )
    (progn
      (setq clean (swcad-title-remove-xdata-app-from-data data app))
      (setq expected-counts (swcad-title-expected-sheet-counts-for-marker))
      (setq expected-title-counts (swcad-title-expected-title-counts-for-marker))
      (setq record
        (list
          app
          (cons 1000 marker)
          (cons 1000 *swcad-title-scale-version*)
          (cons 1000 (swcad-title-string frame-block))
          (cons 1000 (swcad-title-string role))
          (cons 1000 *swcad-title-expected-sheet-counts-marker*)
        )
      )
      (foreach count-pair expected-counts
        (setq record
          (append
            record
            (list
              (cons
                1000
                (strcat
                  "COUNT:"
                  (swcad-title-normalized-sheet-size (car count-pair))
                  "="
                  (itoa (cdr count-pair))
                )
              )
            )
          )
        )
      )
      (setq record
        (append
          record
          (list (cons 1000 *swcad-title-expected-title-counts-marker*))
        )
      )
      (foreach count-pair expected-title-counts
        (setq record
          (append
            record
            (list
              (cons
                1000
                (strcat
                  "TITLECOUNT:"
                  (swcad-title-normalized-sheet-size (car count-pair))
                  "="
                  (itoa (cdr count-pair))
                )
              )
            )
          )
        )
      )
      (setq result
        (vl-catch-all-apply
          'entmod
          (list (append clean (list (cons -3 (list record)))))
        )
      )
      (if (vl-catch-all-error-p result)
        nil
        (progn
          (entupd ename)
          T
        )
      )
    )
    nil
  )
)

(defun swcad-title-mark-native-exemplar-pair (title-ename frame-ename frame-block role / title-ok frame-ok)
  (setq title-ok (swcad-title-set-exemplar-xdata title-ename frame-block role))
  (setq frame-ok (swcad-title-set-exemplar-xdata frame-ename frame-block role))
  (and title-ok frame-ok)
)

(defun swcad-title-trusted-native-exemplar-entity-p (ename frame-block / record values marker target marker-found frame-found value)
  (setq record (swcad-title-xdata-record-by-app ename *swcad-title-exemplar-xdata-app*))
  (setq values (if record (swcad-title-xdata-text-values record) nil))
  (setq marker (strcase *swcad-title-exemplar-xdata-marker*))
  (setq target (strcase (swcad-title-string frame-block)))
  (setq marker-found nil)
  (setq frame-found nil)
  (foreach value values
    (cond
      ((equal (strcase (swcad-title-string value)) marker)
        (setq marker-found T)
      )
      ((equal (strcase (swcad-title-string value)) target)
        (setq frame-found T)
      )
    )
  )
  (and marker-found frame-found)
)

(defun swcad-title-trusted-native-exemplar-title-p (title-ename frame-block)
  (swcad-title-trusted-native-exemplar-entity-p title-ename frame-block)
)

(defun swcad-title-trusted-native-exemplar-frame-p (frame-ename frame-block)
  (swcad-title-trusted-native-exemplar-entity-p frame-ename frame-block)
)

(defun swcad-title-trusted-native-exemplar-pair-p (title-ename frame-ename frame-block)
  (and
    (swcad-title-trusted-native-exemplar-title-p title-ename frame-block)
    (swcad-title-trusted-native-exemplar-frame-p frame-ename frame-block)
  )
)

(defun swcad-title-exemplar-xdata-values (ename / record)
  (setq record (swcad-title-xdata-record-by-app ename *swcad-title-exemplar-xdata-app*))
  (if record
    (swcad-title-xdata-text-values record)
    nil
  )
)

(defun swcad-title-exemplar-role (ename / values)
  (setq values (swcad-title-exemplar-xdata-values ename))
  (if (and values (>= (length values) 4))
    (swcad-title-string (nth 3 values))
    ""
  )
)

(defun swcad-title-exemplar-clone-entity-p (ename)
  (equal (strcase (swcad-title-exemplar-role ename)) "CLONE")
)

(defun swcad-title-exemplar-clone-role-p (role)
  (equal (strcase (swcad-title-string role)) "CLONE")
)

(defun swcad-title-exemplar-moved-unverified-role-p (role / upper)
  (setq upper (strcase (swcad-title-string role)))
  (wcmatch upper "*MOVED*UNVERIFIED*")
)

(defun swcad-title-exemplar-legacy-uncertain-native-role-p (role / upper)
  (setq upper (strcase (swcad-title-string role)))
  (or
    (equal upper "NATIVE-FINALIZE")
    (equal upper "NATIVE-FINALIZE-MANUAL")
    (equal upper "NATIVE-FRAME-ONLY")
    (equal upper "NATIVE-FRAME-ONLY-APPLY")
    (equal upper "NATIVE-FRAME-ONLY-FINALIZE")
    (swcad-title-exemplar-moved-unverified-role-p role)
  )
)

(defun swcad-title-exemplar-safe-native-source-role-p (role)
  (and
    (not (swcad-title-exemplar-clone-role-p role))
    (not (swcad-title-exemplar-legacy-uncertain-native-role-p role))
  )
)

(defun swcad-title-exemplar-native-role-p (role / upper)
  (setq upper (strcase (swcad-title-string role)))
  (or
    (wcmatch upper "NATIVE-*")
    (equal upper "NATIVE")
  )
)

(defun swcad-title-exemplar-native-entity-p (ename)
  (swcad-title-exemplar-native-role-p (swcad-title-exemplar-role ename))
)

(defun swcad-title-role-check-record (role expected-legacy expected-safe / legacy safe native clone moved ok)
  (setq legacy (swcad-title-exemplar-legacy-uncertain-native-role-p role))
  (setq safe (swcad-title-exemplar-safe-native-source-role-p role))
  (setq native (swcad-title-exemplar-native-role-p role))
  (setq clone (swcad-title-exemplar-clone-role-p role))
  (setq moved (swcad-title-exemplar-moved-unverified-role-p role))
  (setq ok (and (equal legacy expected-legacy) (equal safe expected-safe)))
  (swcad-title-princ-line
    (strcat
      "role="
      role
      ", native="
      (if native "yes" "no")
      ", clone="
      (if clone "yes" "no")
      ", moved-unverified="
      (if moved "yes" "no")
      ", legacy-uncertain="
      (if legacy "yes" "no")
      ", safe-native-source="
      (if safe "yes" "no")
      ", expected-legacy="
      (if expected-legacy "yes" "no")
      ", expected-safe="
      (if expected-safe "yes" "no")
      ", result="
      (if ok "OK" "FAIL")
    )
  )
  ok
)

(defun swcad-title-role-check (/ failures item)
  (swcad-title-open-role-check-log)
  (swcad-title-princ-line "----- SWTITLEVERIFY 내부 native role 분류 확인(읽기 전용) -----")
  (swcad-title-print-loaded-version)
  (setq failures 0)
  (foreach item
    '(
      ("native-apply" nil T)
      ("native-upgrade" nil T)
      ("native-finalize" T nil)
      ("native-finalize-manual" T nil)
      ("native-frame-only" T nil)
      ("native-frame-only-apply" T nil)
      ("native-frame-only-finalize" T nil)
      ("native-moved-unverified" T nil)
      ("native-frame-only-moved-unverified" T nil)
      ("clone" nil nil)
    )
    (if (not (swcad-title-role-check-record (car item) (cadr item) (caddr item)))
      (setq failures (+ failures 1))
    )
  )
  (if (= failures 0)
    (swcad-title-apply-result "OK_ROLE_CLASSIFICATION")
    (swcad-title-apply-result "FAIL_ROLE_CLASSIFICATION")
  )
  (swcad-title-princ-line "Important: native-finalize and native-frame-only must be legacy-uncertain=yes.")
  (swcad-title-princ-line "If they are safe-native-source=yes, A2/A3/A4 GMPOWEREDIT failures can be hidden by stale logic.")
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-xdata-handle-values (record / result pair value)
  (setq result nil)
  (foreach pair (cdr record)
    (if (and (listp pair) (member (car pair) '(1000 1005)))
      (progn
        (setq value (swcad-title-string (cdr pair)))
        (if (and (> (strlen value) 0) (handent value))
          (setq result (append result (list value)))
        )
      )
    )
  )
  result
)

(defun swcad-title-gmtitle-native-xdata-info (title-ename / records record app handles found-handles)
  (setq records (swcad-title-xdata-records title-ename))
  (setq found-handles nil)
  (foreach record records
    (setq app (strcase (swcad-title-xdata-record-app-name record)))
    (if (equal app "GENIUS_GENOREF_13")
      (progn
        (setq handles (swcad-title-xdata-handle-values record))
        (foreach handle handles
          (if (not (member handle found-handles))
            (setq found-handles (append found-handles (list handle)))
          )
        )
      )
    )
  )
  found-handles
)

(defun swcad-title-native-link-target-kind (handle / ename data etype name)
  (setq ename (if (> (strlen (swcad-title-string handle)) 0) (handent handle) nil))
  (cond
    ((not ename) "missing")
    (T
      (setq data (entget ename '("*")))
      (if data
        (progn
          (setq etype (swcad-title-string (swcad-title-dxf-value data 0)))
          (cond
            ((= (strlen etype) 0) "internal")
            ((equal etype "INSERT")
              (setq name (swcad-title-effective-insert-name ename))
              (cond
                ((swcad-title-native-target-frame-name-p name) "visible-target-frame")
                ((swcad-title-native-target-title-name-p name) "visible-target-title")
                (T "visible-insert")
              )
            )
            (T etype)
          )
        )
        "internal-no-entget"
      )
    )
  )
)

(defun swcad-title-native-link-target-kinds (title-ename / handles result handle)
  (setq handles (swcad-title-gmtitle-native-xdata-info title-ename))
  (setq result nil)
  (foreach handle handles
    (setq result
      (swcad-title-list-add-unique
        (swcad-title-native-link-target-kind handle)
        result
      )
    )
  )
  result
)

(defun swcad-title-target-title-native-link-counts (/ title-name titles counts title handles handle)
  (setq title-name (swcad-title-target-title-block-name))
  (setq titles (swcad-title-inserts-by-effective-name title-name))
  (setq counts nil)
  (foreach title titles
    (setq handles (swcad-title-gmtitle-native-xdata-info title))
    (foreach handle handles
      (if (> (strlen (swcad-title-string handle)) 0)
        (setq counts (swcad-title-count-frame-link handle counts))
      )
    )
  )
  counts
)

(defun swcad-title-native-link-handle-shared-p (ename counts / handles result handle pair)
  (setq handles (if ename (swcad-title-gmtitle-native-xdata-info ename) nil))
  (setq result nil)
  (foreach handle handles
    (setq pair (assoc (strcase (swcad-title-string handle)) counts))
    (if (and pair (> (cdr pair) 1))
      (setq result T)
    )
  )
  result
)

(defun swcad-title-target-title-native-link-shared-p (title-ename)
  (swcad-title-native-link-handle-shared-p
    title-ename
    (swcad-title-target-title-native-link-counts)
  )
)

(defun swcad-title-native-link-visible-frame-p (title-ename / kinds)
  (setq kinds (swcad-title-native-link-target-kinds title-ename))
  (if (member "visible-target-frame" kinds) T nil)
)

(defun swcad-title-ename-handle (ename / data)
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (strcase (swcad-title-string (swcad-title-dxf-value data 5)))
    )
    ""
  )
)

(defun swcad-title-set-pending-gmtitle-pair (title-ename frame-ename frame-block role)
  (setq *swcad-title-pending-native-title-ename* title-ename)
  (setq *swcad-title-pending-native-frame-ename* frame-ename)
  (setq *swcad-title-pending-native-frame-block* frame-block)
  (setq *swcad-title-pending-gmtitle-role* role)
  T
)

(defun swcad-title-set-pending-native-gmtitle-pair (title-ename frame-ename frame-block)
  (swcad-title-set-pending-gmtitle-pair title-ename frame-ename frame-block "native")
)

(defun swcad-title-clear-pending-native-gmtitle-pair ()
  (setq *swcad-title-pending-native-title-ename* nil)
  (setq *swcad-title-pending-native-frame-ename* nil)
  (setq *swcad-title-pending-native-frame-block* nil)
  (setq *swcad-title-pending-gmtitle-role* nil)
  nil
)

(defun swcad-title-pending-native-gmtitle-pair-for-block (frame-block / title frame expected actual-title actual-frame role)
  (setq title *swcad-title-pending-native-title-ename*)
  (setq frame *swcad-title-pending-native-frame-ename*)
  (setq expected (strcase (swcad-title-string *swcad-title-pending-native-frame-block*)))
  (setq role (swcad-title-string *swcad-title-pending-gmtitle-role*))
  (setq actual-title (if title (swcad-title-effective-insert-name title) ""))
  (setq actual-frame (if frame (swcad-title-effective-insert-name frame) ""))
  (if
    (and
      title
      frame
      (swcad-title-safe-vla-object title)
      (swcad-title-safe-vla-object frame)
      (equal expected (strcase (swcad-title-string frame-block)))
      (swcad-title-native-target-title-name-p actual-title)
      (swcad-title-frame-name-matches-p actual-frame frame-block)
    )
    (list title frame role)
    nil
  )
)

(defun swcad-title-title-linked-to-frame-p (title-ename frame-ename / frame-handle handles result handle)
  (setq frame-handle (swcad-title-ename-handle frame-ename))
  (setq handles (swcad-title-gmtitle-native-xdata-info title-ename))
  (setq result nil)
  (foreach handle handles
    (if (equal (strcase (swcad-title-string handle)) frame-handle)
      (setq result T)
    )
  )
  result
)

(defun swcad-title-title-default-gmtitle-p (title-ename frame-block / object attrs attr tag value current-path result)
  (setq object (swcad-title-safe-vla-object title-ename))
  (setq attrs (if object (swcad-title-get-insert-attributes object) nil))
  (setq current-path (strcase (swcad-title-current-dwg-full-path)))
  (setq result nil)
  (foreach attr attrs
    (setq tag (strcase (swcad-title-attribute-tag attr)))
    (setq value (strcase (vl-string-trim " \t\r\n" (swcad-title-attribute-value attr))))
    (if
      (or
        (and (equal tag "GEN-TITLE-SIZ{6.7}") (equal value (strcase (swcad-title-string frame-block))))
        (and (equal tag "GEN-TITLE-DWG{23}") (equal value current-path))
        (and (equal tag "GEN-TITLE-NR{23}") (equal value "XXX"))
      )
      (setq result T)
    )
  )
  result
)

(defun swcad-title-title-for-native-frame (frame-ename frame-block / titles title result)
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq result nil)
  (foreach title titles
    (if
      (and
        (not result)
        (swcad-title-title-linked-to-frame-p title frame-ename)
        (swcad-title-title-default-gmtitle-p title frame-block)
      )
      (setq result title)
    )
  )
  (if (not result)
    (foreach title titles
      (if
        (and
          (not result)
          (swcad-title-title-linked-to-frame-p title frame-ename)
        )
        (setq result title)
      )
    )
  )
  result
)

(defun swcad-title-default-gmtitle-frame-location-p (frame-ename / bbox)
  (setq bbox (swcad-title-safe-bbox frame-ename))
  (and
    bbox
    (< (swcad-title-abs (car bbox)) 5.0)
    (< (swcad-title-abs (cadr bbox)) 5.0)
  )
)

(defun swcad-title-title-near-frame-p (title-ename frame-ename / title-bbox frame-bbox expanded)
  (setq title-bbox (swcad-title-safe-bbox title-ename))
  (setq frame-bbox (swcad-title-safe-bbox frame-ename))
  (setq expanded (if frame-bbox (swcad-title-expand-bbox frame-bbox 10.0) nil))
  (and
    title-bbox
    expanded
    (swcad-title-bbox-contains-bbox-p expanded title-bbox 0.0)
  )
)

(defun swcad-title-default-location-title-for-frame (frame-ename frame-block / titles title result)
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq result nil)
  (foreach title titles
    (if
      (and
        (not result)
        (swcad-title-title-default-gmtitle-p title frame-block)
      )
      (setq result title)
    )
  )
  (if (not result)
    (foreach title titles
      (if
        (and
          (not result)
          (swcad-title-default-gmtitle-frame-location-p frame-ename)
          (swcad-title-title-near-frame-p title frame-ename)
        )
        (setq result title)
      )
    )
  )
  result
)

(defun swcad-title-unfinalized-gmtitle-frame-score (frame-ename / bbox)
  (setq bbox (swcad-title-safe-bbox frame-ename))
  (if bbox
    (+ (swcad-title-abs (car bbox)) (swcad-title-abs (cadr bbox)))
    999999999.0
  )
)

(defun swcad-title-unfinalized-gmtitle-frame-for-block (frame-block / frames frame title frame-bbox geometry-warning score best best-score)
  (setq frames (swcad-title-inserts-by-effective-name frame-block))
  (setq best nil)
  (setq best-score nil)
  (foreach frame frames
    (setq frame-bbox (swcad-title-frame-reference-effective-bbox frame frame-block))
    (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
    (setq title (swcad-title-title-for-native-frame frame frame-block))
    (if (not title)
      (setq title (swcad-title-default-location-title-for-frame frame frame-block))
    )
    (if
      (and
        (not geometry-warning)
        (or title (swcad-title-default-gmtitle-frame-location-p frame))
        (or
          (and title (swcad-title-title-default-gmtitle-p title frame-block))
          (swcad-title-default-gmtitle-frame-location-p frame)
        )
      )
      (progn
        (setq score (swcad-title-unfinalized-gmtitle-frame-score frame))
        (if (or (not best-score) (< score best-score))
          (progn
            (setq best frame)
            (setq best-score score)
          )
        )
      )
    )
  )
  best
)

(defun swcad-title-default-location-gmtitle-frame-for-block (frame-block / frames frame title frame-bbox geometry-warning score best best-score)
  (setq frames (swcad-title-inserts-by-effective-name frame-block))
  (setq best nil)
  (setq best-score nil)
  (foreach frame frames
    (if (swcad-title-default-gmtitle-frame-location-p frame)
      (progn
        (setq frame-bbox (swcad-title-frame-reference-effective-bbox frame frame-block))
        (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
        (setq title (swcad-title-title-for-native-frame frame frame-block))
        (if (not title)
          (setq title (swcad-title-default-location-title-for-frame frame frame-block))
        )
        (if (and title (not geometry-warning))
          (progn
            (setq score (swcad-title-unfinalized-gmtitle-frame-score frame))
            (if (or (not best-score) (< score best-score))
              (progn
                (setq best frame)
                (setq best-score score)
              )
            )
          )
        )
      )
    )
  )
  best
)

(defun swcad-title-move-ename (ename dx dy / object result)
  (setq object (swcad-title-safe-vla-object ename))
  (if object
    (progn
      (setq result
        (vl-catch-all-apply
          'vla-Move
          (list
            object
            (vlax-3d-point (list 0.0 0.0 0.0))
            (vlax-3d-point (list dx dy 0.0))
          )
        )
      )
      (not (vl-catch-all-error-p result))
    )
    nil
  )
)

(defun swcad-title-align-gmtitle-to-frame-bbox (title-ename frame-ename target-bbox / frame-bbox dx dy moved)
  (setq moved 0)
  (setq frame-bbox (swcad-title-safe-bbox frame-ename))
  (if (and frame-bbox target-bbox)
    (progn
      (setq dx (- (car target-bbox) (car frame-bbox)))
      (setq dy (- (cadr target-bbox) (cadr frame-bbox)))
      (if (or (> (swcad-title-abs dx) 0.0001) (> (swcad-title-abs dy) 0.0001))
        (progn
          (if (swcad-title-move-ename frame-ename dx dy)
            (setq moved (+ moved 1))
          )
          (if (swcad-title-move-ename title-ename dx dy)
            (setq moved (+ moved 1))
          )
        )
      )
      (list moved dx dy frame-bbox)
    )
    (list moved 0.0 0.0 frame-bbox)
  )
)

(defun swcad-title-frame-dwg-path (frame-block)
  (strcat
    "C:/Program Files/Gstarsoft/GstarCAD Mechanical 2024 Korean/Dwg/Format/"
    (swcad-title-string frame-block)
    ".dwg"
  )
)

(defun swcad-title-vla-object->ename (object / result)
  (if object
    (progn
      (setq result (vl-catch-all-apply 'vlax-vla-object->ename (list object)))
      (if (vl-catch-all-error-p result) nil result)
    )
    nil
  )
)

(defun swcad-title-insert-block-reference (block-name x y / result)
  (setq result
    (vl-catch-all-apply
      'vla-InsertBlock
      (list
        (swcad-title-modelspace)
        (vlax-3d-point (list (float x) (float y) 0.0))
        block-name
        1.0
        1.0
        1.0
        0.0
      )
    )
  )
  (if (vl-catch-all-error-p result)
    nil
    (swcad-title-vla-object->ename result)
  )
)

(defun swcad-title-insert-frame-reference (frame-block / frame-path ename)
  (cond
    ((and
       (swcad-title-block-exists-p frame-block)
       (not (swcad-title-target-frame-block-contaminated-p frame-block))
     )
      (setq ename (swcad-title-insert-block-reference frame-block 0.0 0.0))
    )
    ((swcad-title-block-exists-p frame-block)
      (setq ename nil)
    )
    (T
      (setq frame-path (swcad-title-frame-dwg-path frame-block))
      (if (findfile frame-path)
        (setq ename (swcad-title-insert-block-reference frame-path 0.0 0.0))
      )
    )
  )
  ename
)

(defun swcad-title-insert-clean-frame-reference-at (frame-block point / x y ename)
  (if
    (and
      frame-block
      point
      (swcad-title-block-exists-p frame-block)
      (not (swcad-title-target-frame-block-contaminated-p frame-block))
      (not (swcad-title-frame-definition-raw-bbox-risk-record frame-block))
    )
    (progn
      (setq x (car point))
      (setq y (cadr point))
      (setq ename (swcad-title-insert-block-reference frame-block 0.0 0.0))
      (if ename
        (swcad-title-move-ename-bbox-min-to ename x y)
      )
      ename
    )
    nil
  )
)

(defun swcad-title-copy-ename (ename / object result)
  (setq object (swcad-title-safe-vla-object ename))
  (if object
    (progn
      (setq result (vl-catch-all-apply 'vla-Copy (list object)))
      (if (vl-catch-all-error-p result)
        nil
        (swcad-title-vla-object->ename result)
      )
    )
    nil
  )
)

(defun swcad-title-ensure-clean-frame-definition (frame-block)
  (cond
    ((not frame-block) nil)
    ((and
       (swcad-title-block-exists-p frame-block)
       (not (swcad-title-target-frame-block-contaminated-p frame-block))
     )
      T
    )
    ((swcad-title-block-exists-p frame-block)
      nil
    )
    (T
      (swcad-title-import-clean-frame-definition frame-block)
    )
  )
)

(defun swcad-title-change-insert-block-name (ename block-name / data new-data pair changed result)
  (setq data (if ename (entget ename '("*")) nil))
  (if
    (and
      data
      (equal (swcad-title-string (swcad-title-dxf-value data 0)) "INSERT")
      (or
        (swcad-title-block-exists-p block-name)
        (swcad-title-ensure-clean-frame-definition block-name)
      )
    )
    (progn
      (setq new-data nil)
      (setq changed nil)
      (foreach pair data
        (if (and (listp pair) (= (car pair) 2))
          (progn
            (setq new-data (append new-data (list (cons 2 block-name))))
            (setq changed T)
          )
          (setq new-data (append new-data (list pair)))
        )
      )
      (if changed
        (progn
          (setq result (vl-catch-all-apply 'entmod (list new-data)))
          (if (or (vl-catch-all-error-p result) (not result))
            nil
            (progn
              (entupd ename)
              T
            )
          )
        )
        nil
      )
    )
    nil
  )
)

(defun swcad-title-move-ename-bbox-min-to (ename x y / bbox dx dy)
  (setq bbox (swcad-title-safe-bbox ename))
  (if bbox
    (progn
      (setq dx (- (float x) (car bbox)))
      (setq dy (- (float y) (cadr bbox)))
      (swcad-title-move-ename ename dx dy)
    )
    nil
  )
)

(defun swcad-title-native-frame-from-title (title-ename / handles handle ename result)
  (setq handles (swcad-title-gmtitle-native-xdata-info title-ename))
  (setq result nil)
  (foreach handle handles
    (if (not result)
      (progn
        (setq ename (handent handle))
        (if
          (and
            ename
            (swcad-title-native-target-frame-name-p (swcad-title-effective-insert-name ename))
          )
          (setq result ename)
        )
      )
    )
  )
  result
)

(defun swcad-title-usable-native-example-title-p (title-ename / handles kinds)
  (setq handles (swcad-title-gmtitle-native-xdata-info title-ename))
  (setq kinds (swcad-title-native-link-target-kinds title-ename))
  (and
    handles
    (or
      (member "internal" kinds)
      (member "internal-no-entget" kinds)
    )
    (not (member "visible-target-frame" kinds))
    (not (member "visible-target-title" kinds))
  )
)

(defun swcad-title-native-example-description (title-ename / data title-bbox frame-records nearest frame-ename frame-block title-trusted frame-trusted pair-trusted title-role frame-role)
  (if title-ename
    (progn
      (setq data (entget title-ename '("*")))
      (setq title-bbox (swcad-title-safe-bbox title-ename))
      (setq frame-records (swcad-title-frame-records))
      (setq nearest (if title-bbox (swcad-title-nearest-frame-record title-bbox frame-records) nil))
      (setq frame-ename (if nearest (car nearest) nil))
      (setq frame-block (if nearest (cadr nearest) ""))
      (setq title-trusted
        (if (> (strlen frame-block) 0)
          (swcad-title-trusted-native-exemplar-title-p title-ename frame-block)
          nil
        )
      )
      (setq frame-trusted
        (if frame-ename
          (swcad-title-trusted-native-exemplar-frame-p frame-ename frame-block)
          nil
        )
      )
      (setq pair-trusted (and title-trusted frame-trusted))
      (setq title-role (swcad-title-exemplar-role title-ename))
      (setq frame-role (if frame-ename (swcad-title-exemplar-role frame-ename) ""))
      (strcat
        "yes, handle="
        (swcad-title-string (swcad-title-dxf-value data 5))
        ", native-link-kinds="
        (swcad-title-list-string (swcad-title-native-link-target-kinds title-ename))
        ", nearest-frame="
        (if (> (strlen frame-block) 0) frame-block "<none>")
        ", trusted-marker="
        (if pair-trusted "yes" "no")
        ", title-marker="
        (if title-trusted "yes" "no")
        ", frame-marker="
        (if frame-trusted "yes" "no")
        ", title-role="
        (if (> (strlen title-role) 0) title-role "<none>")
        ", frame-role="
        (if (> (strlen frame-role) 0) frame-role "<none>")
      )
    )
    "no"
  )
)

(defun swcad-title-native-example-title (/ titles title result)
  (setq titles
    (vl-sort
      (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name))
      '(lambda (a b)
        (< (swcad-title-bbox-min-x a) (swcad-title-bbox-min-x b))
      )
    )
  )
  (setq result nil)
  (foreach title titles
    (if
      (and
        (not result)
        (swcad-title-usable-native-example-title-p title)
        (swcad-title-exemplar-safe-native-source-role-p (swcad-title-exemplar-role title))
      )
      (setq result title)
    )
  )
  result
)

(defun swcad-title-relink-gmtitle-xdata-pair (pair new-handle / code value)
  (if (and (listp pair) (= (type (car pair)) 'INT))
    (progn
      (setq code (car pair))
      (setq value (swcad-title-string (cdr pair)))
      (if (and (member code '(1000 1005)) (> (strlen value) 0) (handent value))
        (cons code new-handle)
        pair
      )
    )
    pair
  )
)

(defun swcad-title-relink-gmtitle-xdata-app (app new-handle / result pair)
  (setq result nil)
  (if
    (and
      (listp app)
      (swcad-title-string-p (car app))
      (equal (strcase (car app)) "GENIUS_GENOREF_13")
    )
    (progn
      (setq result (list (car app)))
      (foreach pair (cdr app)
        (setq result
          (append
            result
            (list (swcad-title-relink-gmtitle-xdata-pair pair new-handle))
          )
        )
      )
      result
    )
    app
  )
)

(defun swcad-title-relink-title-to-frame (title-ename frame-ename / data frame-handle new-data pair apps new-apps changed)
  (setq data (entget title-ename '("*")))
  (setq frame-handle (swcad-title-ename-handle frame-ename))
  (setq new-data nil)
  (setq changed nil)
  (foreach pair data
    (if (and (listp pair) (= (car pair) -3))
      (progn
        (setq apps (cdr pair))
        (setq new-apps nil)
        (foreach app apps
          (if
            (and
              (listp app)
              (swcad-title-string-p (car app))
              (equal (strcase (car app)) "GENIUS_GENOREF_13")
            )
            (progn
              (setq changed T)
              (setq new-apps
                (append
                  new-apps
                  (list (swcad-title-relink-gmtitle-xdata-app app frame-handle))
                )
              )
            )
            (setq new-apps (append new-apps (list app)))
          )
        )
        (setq new-data (append new-data (list (cons -3 new-apps))))
      )
      (setq new-data (append new-data (list pair)))
    )
  )
  (if changed
    (progn
      (entmod new-data)
      (entupd title-ename)
      T
    )
    nil
  )
)

(defun swcad-title-create-cloned-gmtitle-for-next-source (/ source source-ename source-data source-bbox source-block source-frame source-frame-ename source-frame-bbox source-frame-block build mappings values block-sheet inferred-frame-bbox frame-block default-values clone-result title-ename frame-ename offset-x offset-y doc ok)
  (setq source (swcad-title-transfer-source-bbox))
  (setq source-ename (if source (car source) nil))
  (setq source-data (if source (cadr source) nil))
  (setq source-bbox (if source (caddr source) nil))
  (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) nil))
  (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
  (if
    (and
      source-bbox
      (not (swcad-title-document-read-only-p))
      (swcad-title-apply-work-copy-confirmed-p)
    )
    (progn
      (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
      (setq mappings (car build))
      (setq values (swcad-title-transfer-values mappings))
      (if (not source-ename)
        (setq values (swcad-title-values-fill-missing-template-empty values))
      )
      (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
      (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
      (setq inferred-frame-bbox (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
      (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values inferred-frame-bbox))
      (if (and frame-block inferred-frame-bbox)
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq offset-x (- (car source-bbox) (car inferred-frame-bbox)))
          (setq offset-y (- (cadr source-bbox) (cadr inferred-frame-bbox)))
          (setq default-values
            (list
              (cons "GEN-TITLE-SIZ{6.7}" (swcad-title-normalized-sheet-size frame-block))
              (cons "GEN-TITLE-DWG{23}" (swcad-title-current-dwg-full-path))
              (cons "GEN-TITLE-NR{23}" "XXX")
            )
          )
          (setq clone-result
            (swcad-title-clone-native-gmtitle-pair-preserve-links
              frame-block
              (list offset-x offset-y)
              default-values
            )
          )
          (setq title-ename (if clone-result (car clone-result) nil))
          (setq frame-ename (if clone-result (cadr clone-result) nil))
          (setq ok nil)
          (if clone-result
            (setq ok T)
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (if ok
            (list title-ename frame-ename frame-block)
            (progn
              (swcad-title-delete-cloned-gmtitle-pair title-ename frame-ename)
              nil
            )
          )
        )
        nil
      )
    )
    nil
  )
)

(defun swcad-title-create-cloned-gmtitle-for-frame-only-source (source-frame / frame-ename frame-data frame-bbox source-block sheet frame-block values clone-result new-frame-ename title-ename offset doc ok)
  (setq frame-ename (if source-frame (car source-frame) nil))
  (setq frame-data (if source-frame (cadr source-frame) nil))
  (setq frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-block (if source-frame (cadddr source-frame) nil))
  (setq sheet (if source-frame (nth 5 source-frame) nil))
  (setq frame-block (swcad-title-target-frame-block-name-for-sheet sheet))
  (if
    (and
      frame-ename
      frame-bbox
      frame-block
      (not (swcad-title-document-read-only-p))
      (swcad-title-apply-work-copy-confirmed-p)
    )
    (progn
      (setq values (swcad-title-frame-only-default-values source-frame))
      (if (swcad-title-native-example-title)
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq offset (swcad-title-frame-only-title-offset sheet))
          (setq clone-result
            (swcad-title-clone-native-gmtitle-pair-preserve-links
              frame-block
              offset
              values
            )
          )
          (setq title-ename (if clone-result (car clone-result) nil))
          (setq new-frame-ename (if clone-result (cadr clone-result) nil))
          (setq ok nil)
          (if clone-result
            (setq ok T)
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (if ok
            (list title-ename new-frame-ename frame-block values)
            (progn
              (swcad-title-delete-cloned-gmtitle-pair title-ename new-frame-ename)
              nil
            )
          )
        )
        nil
      )
    )
    nil
  )
)

(defun swcad-title-other-title-like-inserts (target-name / target ss index total ename name data result seen shell-records shell-record shell-handle)
  (setq target (strcase (swcad-title-string target-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq result nil)
  (setq seen nil)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq name (swcad-title-effective-insert-name ename))
    (if
      (and
        (/= (strcase (swcad-title-string name)) target)
        (swcad-title-title-block-name-p name)
      )
      (progn
        (setq data (entget ename '("*")))
        (setq seen
          (swcad-title-list-add-unique
            (strcase (swcad-title-string (swcad-title-dxf-value data 5)))
            seen
          )
        )
        (setq result
          (append
            result
            (list
              (list
                (swcad-title-string (swcad-title-dxf-value data 5))
                name
                (swcad-title-safe-bbox ename)
              )
            )
          )
        )
      )
    )
    (setq index (+ index 1))
  )
  (setq shell-records (swcad-title-target-title-shell-records))
  (foreach shell-record shell-records
    (setq shell-handle (strcase (swcad-title-string (cadr shell-record))))
    (if (not (member shell-handle seen))
      (progn
        (setq seen (append seen (list shell-handle)))
        (setq result
          (append
            result
            (list
              (list
                (cadr shell-record)
                (caddr shell-record)
                (nth 3 shell-record)
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-print-attribute-pairs (attr-pairs / pair)
  (foreach pair attr-pairs
    (swcad-title-princ-line
      (strcat
        "  "
        (car pair)
        " = \""
        (swcad-title-string (cdr pair))
        "\""
      )
    )
  )
)

(defun swcad-title-print-string-list (label values / value)
  (swcad-title-princ-line label)
  (if values
    (foreach value values
      (swcad-title-princ-line (strcat "  - " (swcad-title-string value)))
    )
    (swcad-title-princ-line "  <none>")
  )
)

(defun swcad-title-xdata-app-names (ename / records result record name)
  (setq records (swcad-title-xdata-records ename))
  (setq result nil)
  (foreach record records
    (setq name (swcad-title-xdata-record-app-name record))
    (if (> (strlen name) 0)
      (setq result (swcad-title-list-add-unique name result))
    )
  )
  result
)

(defun swcad-title-dxf-code-count (data code / count pair)
  (setq count 0)
  (foreach pair data
    (if (and (listp pair) (= (car pair) code))
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-bbox-center (bbox)
  (if bbox
    (list
      (/ (+ (car bbox) (caddr bbox)) 2.0)
      (/ (+ (cadr bbox) (cadddr bbox)) 2.0)
    )
    nil
  )
)

(defun swcad-title-bbox-min-x (ename / bbox)
  (setq bbox (swcad-title-safe-bbox ename))
  (if bbox (car bbox) 0.0)
)

(defun swcad-title-frame-records (/ result candidate frames frame frame-data frame-bbox)
  (setq result nil)
  (foreach candidate (swcad-title-target-frame-block-candidates)
    (setq frames (swcad-title-inserts-by-effective-name candidate))
    (foreach frame frames
      (setq frame-data (entget frame '("*")))
      (setq frame-bbox (swcad-title-frame-reference-effective-bbox frame candidate))
      (setq result
        (append
          result
          (list
            (list
              frame
              candidate
              (swcad-title-string (swcad-title-dxf-value frame-data 5))
              frame-bbox
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-nearest-frame-record (title-bbox frame-records / center result record bbox)
  (setq center (swcad-title-bbox-center title-bbox))
  (setq result nil)
  (foreach record frame-records
    (if (not result)
      (progn
        (setq bbox (swcad-title-expand-bbox (cadddr record) 2.0))
        (if (swcad-title-point-in-bbox-p center bbox)
          (setq result record)
        )
      )
    )
  )
  result
)

(defun swcad-title-nearest-frame-record-for-block (title-bbox frame-records target-frame-block / target center nearest nearest-block result record bbox frame-center dist bestdist)
  (setq target (strcase (swcad-title-string target-frame-block)))
  (setq center (swcad-title-bbox-center title-bbox))
  (setq nearest (if title-bbox (swcad-title-nearest-frame-record title-bbox frame-records) nil))
  (setq nearest-block (if nearest (cadr nearest) ""))
  (setq result nil)
  (if (and nearest (equal (strcase (swcad-title-string nearest-block)) target))
    (setq result nearest)
  )
  (if (and (not result) center)
    (progn
      (setq bestdist nil)
      (foreach record frame-records
        (if (equal (strcase (swcad-title-string (cadr record))) target)
          (progn
            (setq bbox (cadddr record))
            (setq frame-center (swcad-title-bbox-center bbox))
            (if frame-center
              (progn
                (setq dist
                  (swcad-title-distance2
                    (car center)
                    (cadr center)
                    (car frame-center)
                    (cadr frame-center)
                  )
                )
                (if (or (not bestdist) (< dist bestdist))
                  (progn
                    (setq result record)
                    (setq bestdist dist)
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-title-for-frame-record-unused (frame-record title-enames used-title-enames / frame-handle result title title-bbox nearest nearest-handle)
  (setq frame-handle (if frame-record (strcase (swcad-title-string (caddr frame-record))) ""))
  (setq result nil)
  (foreach title title-enames
    (if
      (and
        (not result)
        (not (member title used-title-enames))
      )
      (progn
        (setq title-bbox (swcad-title-safe-bbox title))
        (setq nearest (if title-bbox (swcad-title-nearest-frame-record title-bbox (list frame-record)) nil))
        (setq nearest-handle (if nearest (strcase (swcad-title-string (caddr nearest))) ""))
        (if
          (and
            (> (strlen frame-handle) 0)
            (equal nearest-handle frame-handle)
          )
          (setq result title)
        )
      )
    )
  )
  result
)

(defun swcad-title-title-for-frame-record (frame-record title-enames)
  (swcad-title-title-for-frame-record-unused frame-record title-enames nil)
)

(defun swcad-title-attr-value-by-tag (attr-pairs tag / pair result)
  (setq result "")
  (foreach pair attr-pairs
    (if (equal (strcase (car pair)) (strcase tag))
      (setq result (swcad-title-string (cdr pair)))
    )
  )
  result
)

(defun swcad-title-count-frame-link (handle counts / pair result found key)
  (setq key (strcase (swcad-title-string handle)))
  (setq result nil)
  (setq found nil)
  (foreach pair counts
    (if (equal key (car pair))
      (progn
        (setq result (append result (list (cons (car pair) (+ (cdr pair) 1)))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if found
    result
    (append result (list (cons key 1)))
  )
)

(defun swcad-title-block-child-insert-names (block-name / block result item item-ename item-name)
  (setq block (swcad-title-block-definition-object block-name))
  (setq result nil)
  (if block
    (vlax-for item block
      (setq item-ename (swcad-title-vla-object->ename item))
      (if item-ename
        (progn
          (setq item-name (swcad-title-effective-insert-name item-ename))
          (if (> (strlen item-name) 0)
            (setq result (swcad-title-list-add-unique item-name result))
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-def-title-child-records-for-block (frame-name / block result item item-ename item-name title-name)
  (setq block (swcad-title-block-definition-object frame-name))
  (setq result nil)
  (setq title-name (strcase (swcad-title-target-title-block-name)))
  (if block
    (vlax-for item block
      (setq item-ename (swcad-title-vla-object->ename item))
      (if item-ename
        (progn
          (setq item-name (swcad-title-effective-insert-name item-ename))
          (if (equal (strcase (swcad-title-string item-name)) title-name)
            (setq result
              (append
                result
                (list
                  (list
                    frame-name
                    item-ename
                    (swcad-title-ename-handle item-ename)
                    (swcad-title-safe-bbox item-ename)
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-def-title-child-records (/ result frame-name)
  (setq result nil)
  (foreach frame-name (swcad-title-target-frame-block-candidates)
    (setq result
      (append
        result
        (swcad-title-frame-def-title-child-records-for-block frame-name)
      )
    )
  )
  result
)

(defun swcad-title-print-frame-def-title-child-records (records / index record)
  (if records
    (progn
      (swcad-title-princ-line "도면틀 블록 정의 안에 중첩된 제목블록 후보:")
      (setq index 1)
      (foreach record records
        (swcad-title-princ-line
          (strcat
            "  #"
            (itoa index)
            " frame-def="
            (car record)
            ", child-title="
            (swcad-title-target-title-block-name)
            "/"
            (caddr record)
            ", 범위="
            (swcad-title-bbox-string (cadddr record))
          )
        )
        (setq index (+ index 1))
      )
    )
    (swcad-title-princ-line "도면틀 블록 정의 안에 중첩된 제목블록 후보: <없음>")
  )
)

(defun swcad-title-a3-frame-embedded-title-region ()
  ;; Local A3 frame coordinates. The separate DR_titlea_3rd insert is placed at
  ;; roughly x=230..414, y=10..52, so this catches the built-in title geometry.
  '(220.0 0.0 420.0 70.0)
)

(defun swcad-title-frame-embedded-title-entity-type-p (etype)
  (member
    (strcase (swcad-title-string etype))
    '("LINE" "LWPOLYLINE" "POLYLINE" "2DPOLYLINE" "HATCH" "SOLID" "TRACE" "WIPEOUT" "CIRCLE" "ARC" "ELLIPSE" "SPLINE" "TEXT" "MTEXT" "INSERT" "ATTDEF")
  )
)

(defun swcad-title-bbox-center-in-bbox-p (bbox region / center)
  (setq center (swcad-title-bbox-center bbox))
  (and center (swcad-title-point-in-bbox-p center region))
)

(defun swcad-title-a3-frame-embedded-title-records (/ frame-name region block-names result block-name block item item-ename data etype item-name bbox)
  (setq frame-name "DR_A3_Outline")
  (setq region (swcad-title-a3-frame-embedded-title-region))
  (setq block-names (cons frame-name (swcad-title-block-descendant-insert-names frame-name)))
  (setq result nil)
  (foreach block-name block-names
    (if (not (equal (strcase (swcad-title-string block-name)) (strcase (swcad-title-target-title-block-name))))
      (progn
        (setq block (swcad-title-block-definition-object block-name))
        (if block
          (vlax-for item block
            (setq item-ename (swcad-title-vla-object->ename item))
            (if item-ename
              (progn
                (setq data (entget item-ename '("*")))
                (setq etype (swcad-title-dxf-value data 0))
                (setq item-name "")
                (if (equal (strcase (swcad-title-string etype)) "INSERT")
                  (setq item-name (swcad-title-effective-insert-name item-ename))
                )
                (setq bbox (swcad-title-safe-bbox item-ename))
                (if
                  (and
                    bbox
                    (swcad-title-frame-embedded-title-entity-type-p etype)
                    (swcad-title-bbox-center-in-bbox-p bbox region)
                    (not (swcad-title-native-target-frame-name-p item-name))
                  )
                  (setq result
                    (append
                      result
                      (list
                        (list
                          block-name
                          item-ename
                          (swcad-title-ename-handle item-ename)
                          etype
                          item-name
                          bbox
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-print-a3-frame-embedded-title-records (records / index record name)
  (if records
    (progn
      (swcad-title-princ-line "A3 도면틀 정의 안에 합쳐진 표제란 형상 후보:")
      (setq index 1)
      (foreach record records
        (setq name (nth 4 record))
        (swcad-title-princ-line
          (strcat
            "  #"
            (itoa index)
            " block-def="
            (car record)
            ", handle="
            (caddr record)
            ", type="
            (swcad-title-string (nth 3 record))
            (if (> (strlen name) 0) (strcat ", insert=" name) "")
            ", 범위="
            (swcad-title-bbox-string (nth 5 record))
          )
        )
        (setq index (+ index 1))
      )
    )
    (swcad-title-princ-line "A3 도면틀 정의 안에 합쳐진 표제란 형상 후보: <없음>")
  )
)

(defun swcad-title-frame-embedded-title-region-for-block (frame-name / sheet dims offset left bottom right top)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-name))
  (setq dims (swcad-title-sheet-dimensions sheet))
  (if dims
    (progn
      (setq offset (swcad-title-frame-only-title-offset sheet))
      (setq left (max 0.0 (- (car offset) 10.0)))
      (setq bottom 0.0)
      (setq right (car dims))
      (setq top (min (cadr dims) (+ (cadr offset) 65.0)))
      (list left bottom right top)
    )
    nil
  )
)

(defun swcad-title-frame-edge-near-bbox-p (bbox frame-bbox tolerance)
  (and
    bbox
    frame-bbox
    (or
      (<= (swcad-title-abs (- (cadr bbox) (cadr frame-bbox))) tolerance)
      (<= (swcad-title-abs (- (cadddr bbox) (cadddr frame-bbox))) tolerance)
      (<= (swcad-title-abs (- (car bbox) (car frame-bbox))) tolerance)
      (<= (swcad-title-abs (- (caddr bbox) (caddr frame-bbox))) tolerance)
    )
  )
)

(defun swcad-title-frame-coordinate-text-p (raw-text bbox frame-bbox / text upper len)
  (setq text (vl-string-trim " \t\r\n" (swcad-title-string raw-text)))
  (setq upper (strcase text))
  (setq len (strlen text))
  (and
    (<= len 2)
    (or
      (wcmatch upper "#")
      (wcmatch upper "##")
      (wcmatch upper "[A-Z]")
      (wcmatch upper "[A-Z]#")
      (wcmatch upper "#[A-Z]")
    )
  )
)

(defun swcad-title-gentitle-marker-text-p (raw-text / upper)
  (setq upper (strcase (vl-string-trim " \t\r\n" (swcad-title-string raw-text))))
  (wcmatch upper "!GENTITLE*")
)

(defun swcad-title-frame-coordinate-tick-p (etype bbox frame-bbox / upper width height near-bottom near-top near-left near-right)
  (setq upper (strcase (swcad-title-string etype)))
  (setq width (swcad-title-bbox-width bbox))
  (setq height (swcad-title-bbox-height bbox))
  (setq near-bottom (and bbox frame-bbox (<= (cadddr bbox) (+ (cadr frame-bbox) 16.0))))
  (setq near-top (and bbox frame-bbox (>= (cadr bbox) (- (cadddr frame-bbox) 16.0))))
  (setq near-left (and bbox frame-bbox (<= (caddr bbox) (+ (car frame-bbox) 16.0))))
  (setq near-right (and bbox frame-bbox (>= (car bbox) (- (caddr frame-bbox) 16.0))))
  (and
    (member upper '("LINE" "LWPOLYLINE" "POLYLINE" "2DPOLYLINE"))
    (or
      (and (or near-bottom near-top) (<= height 4.0))
      (and (or near-bottom near-top) (<= width 4.0) (<= height 16.0))
      (and (or near-left near-right) (<= width 4.0) (<= height 16.0))
      (and (or near-left near-right) (<= height 4.0) (<= width 16.0))
    )
  )
)

(defun swcad-title-frame-embedded-title-protected-p (etype item-name bbox frame-bbox raw-text)
  (or
    (swcad-title-native-target-title-name-p item-name)
    (swcad-title-native-target-frame-name-p item-name)
    (swcad-title-gentitle-marker-text-p raw-text)
    (swcad-title-frame-edge-graphic-p bbox frame-bbox)
    (swcad-title-frame-coordinate-tick-p etype bbox frame-bbox)
    (and
      (member (strcase (swcad-title-string etype)) '("TEXT" "MTEXT" "ATTDEF"))
      (swcad-title-frame-coordinate-text-p raw-text bbox frame-bbox)
    )
  )
)

(defun swcad-title-frame-embedded-title-records-for-block (frame-name / sheet dims region frame-bbox block-names result block-name block item item-ename data etype item-name raw-text bbox)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-name))
  (setq dims (swcad-title-sheet-dimensions sheet))
  (setq region (swcad-title-frame-embedded-title-region-for-block frame-name))
  (setq frame-bbox (if dims (list 0.0 0.0 (car dims) (cadr dims)) nil))
  (setq block-names (cons frame-name (swcad-title-block-descendant-insert-names frame-name)))
  (setq result nil)
  (if (and sheet dims region frame-bbox)
    (foreach block-name block-names
      (if (not (equal (strcase (swcad-title-string block-name)) (strcase (swcad-title-target-title-block-name))))
        (progn
          (setq block (swcad-title-block-definition-object block-name))
          (if block
            (vlax-for item block
              (setq item-ename (swcad-title-vla-object->ename item))
              (if item-ename
                (progn
                  (setq data (entget item-ename '("*")))
                  (setq etype (swcad-title-dxf-value data 0))
                  (setq item-name "")
                  (setq raw-text "")
                  (if (equal (strcase (swcad-title-string etype)) "INSERT")
                    (setq item-name (swcad-title-effective-insert-name item-ename))
                  )
                  (if (member (strcase (swcad-title-string etype)) '("TEXT" "MTEXT" "ATTDEF"))
                    (setq raw-text (swcad-title-text-entity-value data))
                  )
                  (setq bbox (swcad-title-safe-bbox item-ename))
                  (if
                    (and
                      bbox
                      (swcad-title-frame-embedded-title-entity-type-p etype)
                      (swcad-title-bbox-center-in-bbox-p bbox region)
                      (not (swcad-title-frame-embedded-title-protected-p etype item-name bbox frame-bbox raw-text))
                    )
                    (setq result
                      (append
                        result
                        (list
                          (list frame-name block-name item-ename (swcad-title-ename-handle item-ename) etype item-name bbox region raw-text)
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-embedded-title-evidence-record-p (record / etype item-name raw-text upper)
  (setq etype (strcase (swcad-title-string (nth 4 record))))
  (setq item-name (swcad-title-string (nth 5 record)))
  (setq raw-text (vl-string-trim " \t\r\n" (swcad-title-string (nth 8 record))))
  (setq upper (strcase raw-text))
  (or
    (and
      (member etype '("TEXT" "MTEXT" "ATTDEF"))
      (> (strlen raw-text) 2)
      (not (swcad-title-gentitle-marker-text-p raw-text))
      (not (wcmatch upper "[A-Z]#"))
      (not (wcmatch upper "#[A-Z]"))
    )
    (and
      (equal etype "INSERT")
      (> (strlen item-name) 0)
      (not (swcad-title-native-target-title-name-p item-name))
      (not (swcad-title-native-target-frame-name-p item-name))
    )
  )
)

(defun swcad-title-frame-embedded-title-evidence-owner-names (records / result record owner)
  (setq result nil)
  (foreach record records
    (if (swcad-title-frame-embedded-title-evidence-record-p record)
      (progn
        (setq owner (cadr record))
        (setq result (swcad-title-list-add-unique owner result))
      )
    )
  )
  result
)

(defun swcad-title-filter-frame-embedded-title-records-by-evidence (records / owners result record)
  (setq owners (swcad-title-frame-embedded-title-evidence-owner-names records))
  (setq result nil)
  (foreach record records
    (if (member (cadr record) owners)
      (setq result (append result (list record)))
    )
  )
  result
)

(defun swcad-title-frame-embedded-title-records-all (/ result frame-name)
  (setq result nil)
  (foreach frame-name (swcad-title-target-frame-block-candidates)
    (if (not (equal (swcad-title-normalized-sheet-size frame-name) "A1"))
      (setq result
        (append
          result
          (swcad-title-frame-embedded-title-records-for-block frame-name)
        )
      )
    )
  )
  (swcad-title-filter-frame-embedded-title-records-by-evidence result)
)

(defun swcad-title-frame-embedded-title-records (/ result frame-name class-record class)
  (setq result nil)
  (foreach frame-name (swcad-title-frame-definition-check-candidates)
    (setq class-record (swcad-title-frame-definition-class-record frame-name))
    (setq class (cadr class-record))
    (if (member class '("source-contaminated"))
      (setq result
        (append
          result
          (swcad-title-frame-definition-embedded-records-for-frame frame-name)
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-definition-check-candidates ()
  '("DR_A2_Outline" "DR_A3_Outline" "DR_A4_Outline")
)

(defun swcad-title-frame-definition-embedded-records-for-frame (frame-name)
  (swcad-title-filter-frame-embedded-title-records-by-evidence
    (swcad-title-frame-embedded-title-records-for-block frame-name)
  )
)

(defun swcad-title-frame-definition-class-record-legacy-main43-unused (frame-name / exists embedded-records embedded-count source-like-children class reason)
  (setq exists (swcad-title-block-exists-p frame-name))
  (setq embedded-records nil)
  (setq embedded-count 0)
  (setq source-like-children nil)
  (cond
    ((not exists)
      (setq class "unknown")
      (setq reason "현재 도면에 이 도면틀 정의가 아직 없습니다. 첫 native GMTITLE 전이면 정상일 수 있습니다.")
    )
    (T
      (setq embedded-records (swcad-title-frame-definition-embedded-records-for-frame frame-name))
      (setq embedded-count (length embedded-records))
      (setq source-like-children (swcad-title-target-frame-block-source-like-children frame-name))
      (cond
        ((> embedded-count 0)
          (setq class "embedded-title")
          (setq reason "도면틀 정의 내부 표제란 영역에 삭제 검토가 필요한 title-like 형상이 있습니다.")
        )
        (source-like-children
          (setq class "contaminated")
          (setq reason "도면틀 정의 안에 원본 SolidWorks/이전 제목블록처럼 보이는 child block이 있습니다.")
        )
        (T
          (setq class "outline-only")
          (setq reason "현재 필터 기준으로 도면틀 정의 안의 내장 표제란 후보가 없습니다.")
        )
      )
    )
  )
  (list frame-name class reason embedded-count source-like-children)
)

(defun swcad-title-frame-definition-class-record (frame-name / exists embedded-records embedded-count source-like-children class reason)
  (setq exists (swcad-title-block-exists-p frame-name))
  (setq embedded-records nil)
  (setq embedded-count 0)
  (setq source-like-children nil)
  (cond
    ((not exists)
      (setq class "unknown")
      (setq reason "현재 도면 안에 이 DR 도면틀 정의가 아직 없습니다. 첫 native GMTITLE 전이면 정상일 수 있습니다.")
    )
    (T
      (setq embedded-records (swcad-title-frame-definition-embedded-records-for-frame frame-name))
      (setq embedded-count (length embedded-records))
      (setq source-like-children (swcad-title-target-frame-block-source-like-children frame-name))
      (cond
        (source-like-children
          (setq class "source-contaminated")
          (setq reason "DR 도면틀 정의 안에 SolidWorks/이전 변환 source-like child block이 있어 변환 전 정규화가 필요합니다.")
        )
        ((> embedded-count 0)
          (setq class "native-format-with-title-geometry")
          (setq reason "도면틀 정의 안에 표제란처럼 보이는 형상이 있지만 source-like child block은 없습니다. 설치 원본/native 구조일 수 있으므로 자동 삭제하지 않습니다.")
        )
        (T
          (setq class "outline-only")
          (setq reason "현재 필터 기준으로 도면틀 정의 안의 내장 표제란 정리 후보가 없습니다.")
        )
      )
    )
  )
  (list frame-name class reason embedded-count source-like-children)
)

(defun swcad-title-frame-definition-class-records (/ result frame-name)
  (setq result nil)
  (foreach frame-name (swcad-title-frame-definition-check-candidates)
    (setq result
      (append
        result
        (list (swcad-title-frame-definition-class-record frame-name))
      )
    )
  )
  result
)

(defun swcad-title-frame-definition-blocking-records (/ result record class)
  (setq result nil)
  (foreach record (swcad-title-frame-definition-class-records)
    (setq class (cadr record))
    (if (member class '("source-contaminated"))
      (setq result (append result (list record)))
    )
  )
  result
)

(defun swcad-title-frame-definition-blocking-records-by-class (wanted-class / result record)
  (setq result nil)
  (foreach record (swcad-title-frame-definition-blocking-records)
    (if (equal (cadr record) wanted-class)
      (setq result (append result (list record)))
    )
  )
  result
)

(defun swcad-title-frame-style-graphic-entity-type-p (etype)
  (member
    (strcase (swcad-title-string etype))
    '("LINE" "LWPOLYLINE" "POLYLINE" "2DPOLYLINE" "HATCH" "SOLID" "TRACE" "WIPEOUT" "CIRCLE" "ARC" "ELLIPSE" "SPLINE")
  )
)

(defun swcad-title-frame-style-outer-edge-p (bbox frame-bbox / tolerance frame-width frame-height width height near-left near-right near-bottom near-top)
  (if (and bbox frame-bbox)
    (progn
      (setq tolerance 2.5)
      (setq frame-width (swcad-title-bbox-width frame-bbox))
      (setq frame-height (swcad-title-bbox-height frame-bbox))
      (setq width (swcad-title-bbox-width bbox))
      (setq height (swcad-title-bbox-height bbox))
      (setq near-left (and (swcad-title-near-p (car bbox) (car frame-bbox) tolerance) (swcad-title-near-p (caddr bbox) (car frame-bbox) tolerance)))
      (setq near-right (and (swcad-title-near-p (car bbox) (caddr frame-bbox) tolerance) (swcad-title-near-p (caddr bbox) (caddr frame-bbox) tolerance)))
      (setq near-bottom (and (swcad-title-near-p (cadr bbox) (cadr frame-bbox) tolerance) (swcad-title-near-p (cadddr bbox) (cadr frame-bbox) tolerance)))
      (setq near-top (and (swcad-title-near-p (cadr bbox) (cadddr frame-bbox) tolerance) (swcad-title-near-p (cadddr bbox) (cadddr frame-bbox) tolerance)))
      (or
        (and (>= width (* frame-width 0.80)) (or near-bottom near-top))
        (and (>= height (* frame-height 0.80)) (or near-left near-right))
      )
    )
    nil
  )
)

(defun swcad-title-frame-style-coordinate-tick-p (etype bbox frame-bbox / upper width height near-bottom near-top near-left near-right)
  (setq upper (strcase (swcad-title-string etype)))
  (setq width (swcad-title-bbox-width bbox))
  (setq height (swcad-title-bbox-height bbox))
  (setq near-bottom (and bbox frame-bbox (<= (cadddr bbox) (+ (cadr frame-bbox) 16.0))))
  (setq near-top (and bbox frame-bbox (>= (cadr bbox) (- (cadddr frame-bbox) 16.0))))
  (setq near-left (and bbox frame-bbox (<= (caddr bbox) (+ (car frame-bbox) 16.0))))
  (setq near-right (and bbox frame-bbox (>= (car bbox) (- (caddr frame-bbox) 16.0))))
  (and
    (member upper '("LINE" "LWPOLYLINE" "POLYLINE" "2DPOLYLINE"))
    (or
      (and (or near-bottom near-top) (<= width 16.0) (<= height 4.0))
      (and (or near-bottom near-top) (<= width 4.0) (<= height 16.0))
      (and (or near-left near-right) (<= width 4.0) (<= height 16.0))
      (and (or near-left near-right) (<= height 4.0) (<= width 16.0))
    )
  )
)

(defun swcad-title-frame-style-coordinate-text-p (raw-text bbox frame-bbox / text upper len center edge-distance)
  (setq text (vl-string-trim " \t\r\n" (swcad-title-string raw-text)))
  (setq upper (strcase text))
  (setq len (strlen text))
  (setq center (swcad-title-bbox-center bbox))
  (setq edge-distance
    (if (and center frame-bbox)
      (min
        (swcad-title-abs (- (car center) (car frame-bbox)))
        (swcad-title-abs (- (car center) (caddr frame-bbox)))
        (swcad-title-abs (- (cadr center) (cadr frame-bbox)))
        (swcad-title-abs (- (cadr center) (cadddr frame-bbox)))
      )
      999999.0
    )
  )
  (and
    (<= len 2)
    (<= edge-distance 8.0)
    (or
      (wcmatch upper "#")
      (wcmatch upper "##")
      (wcmatch upper "[A-Z]")
      (wcmatch upper "[A-Z]#")
      (wcmatch upper "#[A-Z]")
    )
  )
)

(defun swcad-title-frame-style-path-prefix-p (prefix path / ok)
  (setq ok T)
  (while (and ok prefix)
    (if (or (not path) (not (equal (strcase (swcad-title-string (car prefix))) (strcase (swcad-title-string (car path))))))
      (setq ok nil)
    )
    (setq prefix (cdr prefix))
    (setq path (cdr path))
  )
  ok
)

(defun swcad-title-frame-style-path-under-prefixes-p (path prefixes / found prefix)
  (setq found nil)
  (foreach prefix prefixes
    (if (swcad-title-frame-style-path-prefix-p prefix path)
      (setq found T)
    )
  )
  found
)

(defun swcad-title-frame-path-entity-records-recurse (frame-name block-name matrix block-path insert-path visited depth / block result item ename data etype item-name raw-text local-bbox root-bbox handle child-exists child-matrix child-records child-visited)
  (setq block (swcad-title-block-definition-object block-name))
  (setq result nil)
  (if (and block (< depth 16))
    (vlax-for item block
      (setq ename (swcad-title-vla-object->ename item))
      (if ename
        (progn
          (setq data (entget ename '("*")))
          (setq etype (strcase (swcad-title-string (swcad-title-dxf-value data 0))))
          (setq item-name "")
          (setq raw-text "")
          (if (equal etype "INSERT")
            (setq item-name (swcad-title-effective-insert-name ename))
          )
          (if (member etype '("TEXT" "MTEXT" "ATTDEF"))
            (setq raw-text (swcad-title-text-entity-value data))
          )
          (setq local-bbox (swcad-title-safe-bbox ename))
          (setq root-bbox (swcad-title-affine-transform-bbox matrix local-bbox))
          (setq handle (swcad-title-ename-handle ename))
          (setq child-exists
            (and
              (equal etype "INSERT")
              (> (strlen item-name) 0)
              (swcad-title-block-exists-p item-name)
            )
          )
          (setq result
            (append
              result
              (list
                (list
                  frame-name block-name ename handle etype item-name
                  local-bbox root-bbox raw-text block-path insert-path matrix depth
                  (if child-exists T nil)
                )
              )
            )
          )
          (if
            (and
              child-exists
              (not (swcad-title-native-target-title-name-p item-name))
              (not (swcad-title-native-target-frame-name-p item-name))
              (not (swcad-title-string-member-ci-p item-name visited))
            )
            (progn
              (setq child-matrix (swcad-title-insert-affine-matrix ename))
              (if child-matrix
                (progn
                  (setq child-matrix (swcad-title-affine-multiply matrix child-matrix))
                  (setq child-visited (append visited (list item-name)))
                  (setq child-records
                    (swcad-title-frame-path-entity-records-recurse
                      frame-name
                      item-name
                      child-matrix
                      (append block-path (list item-name))
                      (append insert-path (list handle))
                      child-visited
                      (+ depth 1)
                    )
                  )
                  (setq result (append result child-records))
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-path-entity-records (frame-name)
  (swcad-title-frame-path-entity-records-recurse
    frame-name
    frame-name
    (swcad-title-affine-identity)
    (list frame-name)
    nil
    (list frame-name)
    0
  )
)

(defun swcad-title-title-residue-region-from-bbox (title-bbox frame-bbox / width height x-margin bottom-margin top-margin region)
  (if title-bbox
    (progn
      (setq width (max 1.0 (swcad-title-bbox-width title-bbox)))
      (setq height (max 1.0 (swcad-title-bbox-height title-bbox)))
      (setq x-margin (max 1.0 (* width 0.06)))
      (setq bottom-margin (max 1.0 (* height 0.25)))
      (setq top-margin (max 1.0 (* height 0.55)))
      (setq region
        (list
          (- (car title-bbox) x-margin)
          (- (cadr title-bbox) bottom-margin)
          (+ (caddr title-bbox) x-margin)
          (+ (cadddr title-bbox) top-margin)
        )
      )
      (if frame-bbox
        (list
          (max (car frame-bbox) (car region))
          (max (cadr frame-bbox) (cadr region))
          (min (caddr frame-bbox) (caddr region))
          (min (cadddr frame-bbox) (cadddr region))
        )
        region
      )
    )
    nil
  )
)

(defun swcad-title-frame-style-pair-context (frame-name frame-ename title-ename / sheet dims frame-root-bbox frame-matrix inverse title-world-bbox title-root-bbox root-region world-region path-records)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-name))
  (setq dims (swcad-title-sheet-dimensions sheet))
  (setq frame-root-bbox (if dims (list 0.0 0.0 (car dims) (cadr dims)) nil))
  (setq frame-matrix (swcad-title-insert-affine-matrix frame-ename))
  (setq inverse (if frame-matrix (swcad-title-affine-inverse frame-matrix) nil))
  (setq title-world-bbox (swcad-title-safe-bbox title-ename))
  (setq title-root-bbox (if inverse (swcad-title-affine-transform-bbox inverse title-world-bbox) nil))
  (setq root-region (swcad-title-title-residue-region-from-bbox title-root-bbox frame-root-bbox))
  (setq world-region (if frame-matrix (swcad-title-affine-transform-bbox frame-matrix root-region) nil))
  (setq path-records (if root-region (swcad-title-frame-path-entity-records frame-name) nil))
  (list frame-matrix inverse title-world-bbox title-root-bbox root-region world-region frame-root-bbox path-records)
)

(defun swcad-title-frame-style-insert-contained-p (bbox region / overlap bbox-area overlap-area)
  (setq overlap (swcad-title-bbox-overlap-box bbox region))
  (setq bbox-area (swcad-title-bbox-area bbox))
  (setq overlap-area (swcad-title-bbox-area overlap))
  (and
    bbox
    region
    (> bbox-area 0.01)
    (or
      (swcad-title-bbox-contains-bbox-p region bbox 1.0)
      (and
        (> (/ overlap-area bbox-area) 0.70)
        (< bbox-area (* (swcad-title-bbox-area region) 1.50))
      )
    )
  )
)

(defun swcad-title-frame-style-base-protection-reason (record frame-bbox / etype item-name bbox raw-text)
  (setq etype (nth 4 record))
  (setq item-name (nth 5 record))
  (setq bbox (nth 7 record))
  (setq raw-text (nth 8 record))
  (cond
    ((swcad-title-native-target-title-name-p item-name) "native-title-block")
    ((swcad-title-native-target-frame-name-p item-name) "native-frame-block")
    ((swcad-title-gentitle-marker-text-p raw-text) "gentitle-marker")
    ((and
       (member etype '("TEXT" "MTEXT" "ATTDEF"))
       (swcad-title-frame-style-coordinate-text-p raw-text bbox frame-bbox)
     )
      "frame-coordinate-text"
    )
    ((and
       (swcad-title-frame-style-graphic-entity-type-p etype)
       (swcad-title-frame-style-outer-edge-p bbox frame-bbox)
     )
      "outer-frame-edge"
    )
    ((and
       (swcad-title-frame-style-graphic-entity-type-p etype)
       (swcad-title-frame-style-coordinate-tick-p etype bbox frame-bbox)
     )
      "frame-coordinate-tick"
    )
    (T nil)
  )
)

(defun swcad-title-frame-style-delete-decision (record region frame-bbox / etype bbox protection child-exists)
  (setq etype (nth 4 record))
  (setq bbox (nth 7 record))
  (setq child-exists (nth 13 record))
  (cond
    ((or (not bbox) (not (swcad-title-bbox-intersects-p bbox region)))
      nil
    )
    ((setq protection (swcad-title-frame-style-base-protection-reason record frame-bbox))
      (list "protect" protection)
    )
    ((equal etype "INSERT")
      (if (swcad-title-frame-style-insert-contained-p bbox region)
        (list "delete" "title-region-contained-insert")
        (if child-exists
          (list "protect" "nested-frame-container")
          (list "protect" "partially-overlapping-insert")
        )
      )
    )
    ((member etype '("TEXT" "MTEXT" "ATTDEF"))
      (list "delete" "title-region-text-overlap")
    )
    ((swcad-title-frame-style-graphic-entity-type-p etype)
      (list "delete" "title-region-geometry-overlap")
    )
    (T
      (list "protect" "unsupported-entity-type")
    )
  )
)

(defun swcad-title-frame-style-independent-residue-reason (record region frame-bbox / etype item-name bbox raw-text)
  (setq etype (nth 4 record))
  (setq item-name (nth 5 record))
  (setq bbox (nth 7 record))
  (setq raw-text (vl-string-trim " \t\r\n" (swcad-title-string (nth 8 record))))
  (cond
    ((or (not bbox) (not (swcad-title-bbox-intersects-p bbox region))) nil)
    ((or
       (swcad-title-native-target-title-name-p item-name)
       (swcad-title-native-target-frame-name-p item-name)
       (swcad-title-gentitle-marker-text-p raw-text)
     )
      nil
    )
    ((member etype '("TEXT" "MTEXT" "ATTDEF"))
      (if (or (= (strlen raw-text) 0) (swcad-title-frame-style-coordinate-text-p raw-text bbox frame-bbox))
        nil
        "visible-text-overlap"
      )
    )
    ((equal etype "INSERT")
      (if (swcad-title-frame-style-insert-contained-p bbox region)
        "visible-insert-overlap"
        nil
      )
    )
    ((swcad-title-frame-style-graphic-entity-type-p etype)
      (if
        (or
          (swcad-title-frame-style-outer-edge-p bbox frame-bbox)
          (swcad-title-frame-style-coordinate-tick-p etype bbox frame-bbox)
        )
        nil
        "visible-geometry-overlap"
      )
    )
    (T nil)
  )
)

(defun swcad-title-frame-style-output-record (record region reason)
  (list
    (nth 0 record)
    (nth 1 record)
    (nth 2 record)
    (nth 3 record)
    (nth 4 record)
    (nth 5 record)
    (nth 7 record)
    region
    (nth 8 record)
    (nth 6 record)
    (nth 9 record)
    (nth 10 record)
    reason
    (nth 11 record)
    (nth 12 record)
  )
)

(defun swcad-title-frame-style-delete-records-from-paths (path-records region frame-bbox / result deleted-prefixes record insert-path decision action reason child-prefix)
  (setq result nil)
  (setq deleted-prefixes nil)
  (foreach record path-records
    (setq insert-path (nth 10 record))
    (if (not (swcad-title-frame-style-path-under-prefixes-p insert-path deleted-prefixes))
      (progn
        (setq decision (swcad-title-frame-style-delete-decision record region frame-bbox))
        (setq action (if decision (car decision) ""))
        (setq reason (if decision (cadr decision) ""))
        (if (equal action "delete")
          (progn
            (setq result (append result (list (swcad-title-frame-style-output-record record region reason))))
            (if (equal (nth 4 record) "INSERT")
              (progn
                (setq child-prefix (append insert-path (list (nth 3 record))))
                (setq deleted-prefixes (append deleted-prefixes (list child-prefix)))
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-style-protected-records-from-paths (path-records region frame-bbox / result record decision)
  (setq result nil)
  (foreach record path-records
    (setq decision (swcad-title-frame-style-delete-decision record region frame-bbox))
    (if (and decision (equal (car decision) "protect"))
      (setq result
        (append result (list (swcad-title-frame-style-output-record record region (cadr decision))))
      )
    )
  )
  result
)

(defun swcad-title-frame-style-independent-records-from-paths (path-records region frame-bbox / result residue-prefixes record insert-path reason child-prefix)
  (setq result nil)
  (setq residue-prefixes nil)
  (foreach record path-records
    (setq insert-path (nth 10 record))
    (if (not (swcad-title-frame-style-path-under-prefixes-p insert-path residue-prefixes))
      (progn
        (setq reason (swcad-title-frame-style-independent-residue-reason record region frame-bbox))
        (if reason
          (progn
            (setq result (append result (list (swcad-title-frame-style-output-record record region reason))))
            (if (equal (nth 4 record) "INSERT")
              (progn
                (setq child-prefix (append insert-path (list (nth 3 record))))
                (setq residue-prefixes (append residue-prefixes (list child-prefix)))
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-style-offsheet-insert-p (record frame-bbox / etype item-name bbox child-exists depth tolerance)
  (setq etype (nth 4 record))
  (setq item-name (nth 5 record))
  (setq bbox (nth 7 record))
  (setq child-exists (nth 13 record))
  (setq depth (nth 12 record))
  (setq tolerance 5.0)
  (and
    frame-bbox
    bbox
    (equal etype "INSERT")
    child-exists
    (> depth 0)
    (not (swcad-title-native-target-title-name-p item-name))
    (not (swcad-title-native-target-frame-name-p item-name))
    (> (swcad-title-bbox-area bbox) 0.01)
    (not (swcad-title-bbox-intersects-p bbox frame-bbox))
    (or
      (> (car bbox) (+ (caddr frame-bbox) tolerance))
      (< (caddr bbox) (- (car frame-bbox) tolerance))
      (> (cadr bbox) (+ (cadddr frame-bbox) tolerance))
      (< (cadddr bbox) (- (cadr frame-bbox) tolerance))
    )
  )
)

(defun swcad-title-frame-style-offsheet-insert-records-from-paths (path-records frame-bbox / result skipped-prefixes record insert-path child-prefix)
  (setq result nil)
  (setq skipped-prefixes nil)
  (foreach record path-records
    (setq insert-path (nth 10 record))
    (if
      (and
        (not (swcad-title-frame-style-path-under-prefixes-p insert-path skipped-prefixes))
        (swcad-title-frame-style-offsheet-insert-p record frame-bbox)
      )
      (progn
        (setq result
          (append
            result
            (list
              (swcad-title-frame-style-output-record
                record
                frame-bbox
                "nested-off-sheet-insert"
              )
            )
          )
        )
        (setq child-prefix (append insert-path (list (nth 3 record))))
        (setq skipped-prefixes (append skipped-prefixes (list child-prefix)))
      )
    )
  )
  result
)

(defun swcad-title-frame-style-normalization-records-for-frame (frame-name / pairs result pair title frame pair-frame-name context frame-matrix title-bbox root-region world-region frame-root-bbox path-records title-delete-records title-verify-records offsheet-records delete-records verify-records protected-records overlap)
  (setq pairs (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach pair pairs
    (setq title (car pair))
    (setq frame (cadr pair))
    (setq pair-frame-name (caddr pair))
    (if
      (and
        (equal (strcase (swcad-title-string pair-frame-name)) (strcase (swcad-title-string frame-name)))
        (not (swcad-title-target-frame-block-source-like-children frame-name))
      )
      (progn
        (setq context (swcad-title-frame-style-pair-context frame-name frame title))
        (setq frame-matrix (nth 0 context))
        (setq title-bbox (nth 2 context))
        (setq root-region (nth 4 context))
        (setq world-region (nth 5 context))
        (setq frame-root-bbox (nth 6 context))
        (setq path-records (nth 7 context))
        (setq title-delete-records (swcad-title-frame-style-delete-records-from-paths path-records root-region frame-root-bbox))
        (setq title-verify-records (swcad-title-frame-style-independent-records-from-paths path-records root-region frame-root-bbox))
        (setq offsheet-records (swcad-title-frame-style-offsheet-insert-records-from-paths path-records frame-root-bbox))
        (setq delete-records (append title-delete-records offsheet-records))
        (setq verify-records (append title-verify-records offsheet-records))
        (setq protected-records (swcad-title-frame-style-protected-records-from-paths path-records root-region frame-root-bbox))
        (setq overlap (swcad-title-bbox-overlap-box world-region title-bbox))
        (if verify-records
          (setq result
            (append
              result
              (list
                (list
                  frame-name
                  frame
                  (swcad-title-ename-handle frame)
                  title
                  (swcad-title-ename-handle title)
                  (length verify-records)
                  world-region
                  title-bbox
                  overlap
                  (if offsheet-records "title-overlap-or-off-sheet-residue" "actual-title-overlap")
                  (if offsheet-records
                    "실제 제목블록 중복 또는 정상 용지 영역과 완전히 분리된 하위 INSERT 잔여물이 확인됐습니다."
                    "실제 DR_titlea_3rd 범위와 겹치는 기존 도면틀 내부 표제란 형상이 독립 검증에서 확인됐습니다."
                  )
                  root-region
                  delete-records
                  verify-records
                  protected-records
                  frame-matrix
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-style-analysis-cache-begin ()
  (setq *swcad-title-frame-style-analysis-cache-enabled* T)
  (setq *swcad-title-frame-style-analysis-cache-valid* nil)
  (setq *swcad-title-frame-style-analysis-cache-records* nil)
)

(defun swcad-title-frame-style-analysis-cache-seed (records)
  (setq *swcad-title-frame-style-analysis-cache-records* records)
  (setq *swcad-title-frame-style-analysis-cache-valid* T)
  records
)

(defun swcad-title-frame-style-analysis-cache-invalidate ()
  (setq *swcad-title-frame-style-analysis-cache-valid* nil)
  (setq *swcad-title-frame-style-analysis-cache-records* nil)
)

(defun swcad-title-frame-style-analysis-cache-end ()
  (setq *swcad-title-frame-style-analysis-cache-enabled* nil)
  (swcad-title-frame-style-analysis-cache-invalidate)
)

(defun swcad-title-frame-style-normalization-records-compute (/ result frame-name)
  (setq result nil)
  (foreach frame-name (swcad-title-frame-definition-check-candidates)
    (setq result
      (append
        result
        (swcad-title-frame-style-normalization-records-for-frame frame-name)
      )
    )
  )
  result
)

(defun swcad-title-frame-style-normalization-records (/ result)
  (if
    (and
      *swcad-title-frame-style-analysis-cache-enabled*
      *swcad-title-frame-style-analysis-cache-valid*
    )
    *swcad-title-frame-style-analysis-cache-records*
    (progn
      (setq result (swcad-title-frame-style-normalization-records-compute))
      (if *swcad-title-frame-style-analysis-cache-enabled*
        (swcad-title-frame-style-analysis-cache-seed result)
      )
      result
    )
  )
)

(defun swcad-title-print-frame-style-normalization-records (records / index record delete-count verify-count protected-count)
  (swcad-title-princ-line "DR 도면틀 스타일 정규화 필요 후보:")
  (if records
    (progn
      (setq index 1)
      (foreach record records
        (setq delete-count (length (nth 12 record)))
        (setq verify-count (length (nth 13 record)))
        (setq protected-count (length (nth 14 record)))
        (swcad-title-princ-line
          (strcat
            "  #"
            (itoa index)
            " frame="
            (car record)
            "/"
            (nth 2 record)
            ", title="
            (swcad-title-target-title-block-name)
            "/"
            (nth 4 record)
            ", 독립 잔여물="
            (itoa verify-count)
            ", 삭제 후보="
            (itoa delete-count)
            ", 보호 객체="
            (itoa protected-count)
            ", 겹침="
            (swcad-title-bbox-string (nth 8 record))
          )
        )
        (swcad-title-princ-line (strcat "     실제 제목블록 기준 도면틀 로컬 영역=" (swcad-title-bbox-string (nth 11 record))))
        (swcad-title-princ-line (strcat "     판단: " (nth 10 record)))
        (swcad-title-princ-line "     다음: SWTITLEPREPARE에서 작업복사본 안의 도면틀 스타일 정규화를 검토하세요.")
        (setq index (+ index 1))
      )
    )
    (swcad-title-princ-line "  <없음>")
  )
)

(defun swcad-title-frame-style-records-from-pairs (pairs record-index / result seen pair record handle)
  (setq result nil)
  (setq seen nil)
  (foreach pair pairs
    (foreach record (nth record-index pair)
      (setq handle (nth 3 record))
      (if (not (member handle seen))
        (progn
          (setq seen (append seen (list handle)))
          (setq result (append result (list record)))
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-style-normalization-entity-records (/ pairs)
  (setq pairs (swcad-title-frame-style-normalization-records))
  (swcad-title-frame-style-records-from-pairs pairs 12)
)

(defun swcad-title-frame-style-independent-residue-records (/ pairs)
  (setq pairs (swcad-title-frame-style-normalization-records))
  (swcad-title-frame-style-records-from-pairs pairs 13)
)

(defun swcad-title-frame-style-protected-records (/ pairs)
  (setq pairs (swcad-title-frame-style-normalization-records))
  (swcad-title-frame-style-records-from-pairs pairs 14)
)

(defun swcad-title-print-frame-definition-class-records (records / record frame-name class reason embedded-count source-like-children)
  (swcad-title-princ-line "DR 도면틀 정의 유형:")
  (if records
    (foreach record records
      (setq frame-name (car record))
      (setq class (cadr record))
      (setq reason (caddr record))
      (setq embedded-count (nth 3 record))
      (setq source-like-children (nth 4 record))
      (swcad-title-princ-line
        (strcat
          "  "
          frame-name
          ": "
          class
          ", 내장 표제란 후보="
          (itoa embedded-count)
          (if source-like-children
            (strcat ", child-blocks=" (swcad-title-list-string source-like-children))
            ""
          )
        )
      )
      (swcad-title-princ-line (strcat "    이유: " reason))
    )
    (swcad-title-princ-line "  <없음>")
  )
)

(defun swcad-title-print-frame-style-entity-records (label records / index record name text reason path)
  (swcad-title-princ-line label)
  (if records
    (progn
      (setq index 1)
      (foreach record records
        (setq name (nth 5 record))
        (setq text (vl-string-trim " \t\r\n" (swcad-title-string (nth 8 record))))
        (setq reason (swcad-title-string (nth 12 record)))
        (setq path (nth 10 record))
        (swcad-title-princ-line
          (strcat
            "  #"
            (itoa index)
            " frame-def="
            (car record)
            ", owner-def="
            (cadr record)
            ", handle="
            (nth 3 record)
            ", type="
            (swcad-title-string (nth 4 record))
            (if (> (strlen name) 0) (strcat ", insert=" name) "")
            (if (> (strlen text) 0) (strcat ", text=\"" text "\"") "")
            ", bbox="
            (swcad-title-bbox-string (nth 6 record))
            ", clean-region="
            (swcad-title-bbox-string (nth 7 record))
            (if (> (strlen reason) 0) (strcat ", reason=" reason) "")
            (if path (strcat ", path=" (swcad-title-list-string path)) "")
          )
        )
        (setq index (+ index 1))
      )
    )
    (swcad-title-princ-line "  <없음>")
  )
)

(defun swcad-title-print-frame-embedded-title-records (records)
  (swcad-title-print-frame-style-entity-records "DR 도면틀 정의 안에 합쳐진 표제란 형상 후보:" records)
)

(defun swcad-title-block-descendant-insert-names (block-name / result visited queue current child)
  (setq result nil)
  (setq visited (list block-name))
  (setq queue (swcad-title-block-child-insert-names block-name))
  (while queue
    (setq current (car queue))
    (setq queue (cdr queue))
    (if
      (and
        current
        (> (strlen (swcad-title-string current)) 0)
        (not (member current visited))
      )
      (progn
        (setq visited (append visited (list current)))
        (setq result (append result (list current)))
        (foreach child (swcad-title-block-child-insert-names current)
          (if (and child (not (member child visited)))
            (setq queue (append queue (list child)))
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-bbox-warning-records-for-block (frame-name / records result record frame-block frame-bbox warning)
  (setq records (swcad-title-frame-records))
  (setq result nil)
  (foreach record records
    (setq frame-block (cadr record))
    (if (equal (strcase (swcad-title-string frame-block)) (strcase (swcad-title-string frame-name)))
      (progn
        (setq frame-bbox (cadddr record))
        (setq warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
        (if warning
          (setq result
            (append
              result
              (list
                (list
                  (caddr record)
                  frame-bbox
                  warning
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-print-frame-def-check-lines (/ frame-name exists children old-child-names bbox-warning-records raw-risk-record contaminated)
  (setq contaminated nil)
  (foreach frame-name (swcad-title-target-frame-block-candidates)
    (setq exists (swcad-title-block-exists-p frame-name))
    (setq children (if exists (swcad-title-block-child-insert-names frame-name) nil))
    (setq old-child-names (if exists (swcad-title-target-frame-block-source-like-children frame-name) nil))
    (setq bbox-warning-records (swcad-title-frame-bbox-warning-records-for-block frame-name))
    (setq raw-risk-record (if exists (swcad-title-frame-definition-raw-bbox-risk-record frame-name) nil))
    (if (or old-child-names bbox-warning-records raw-risk-record)
      (setq contaminated T)
    )
    (swcad-title-princ-line
      (strcat
        "  "
        frame-name
        ": 존재="
        (if exists "예" "아니오")
        ", 하위블록="
        (swcad-title-list-string children)
        ", 기존원본유사="
        (swcad-title-list-string old-child-names)
        ", bbox경고="
        (itoa (length bbox-warning-records))
        ", 정의raw경고="
        (if raw-risk-record "1" "0")
        ", 상태="
        (if (or old-child-names bbox-warning-records raw-risk-record) "오염의심" "정상")
      )
    )
    (if raw-risk-record
      (swcad-title-princ-line
        (strcat
          "    - 정의 raw bbox="
          (swcad-title-bbox-string (cadr raw-risk-record))
          ", 판단="
          (caddr raw-risk-record)
        )
      )
    )
    (foreach record bbox-warning-records
      (swcad-title-princ-line
        (strcat
          "    - INSERT="
          (car record)
          ", "
          (caddr record)
          ", 범위="
          (swcad-title-bbox-string (cadr record))
        )
      )
    )
  )
  contaminated
)

(defun swcad-title-frame-def-check (/ contaminated)
  (swcad-title-open-frame-def-check-log)
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 대상 도면틀 정의 확인(읽기 전용) -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line "대상 도면틀 블록 정의:")
  (setq contaminated (swcad-title-print-frame-def-check-lines))
  (swcad-title-princ-line
    (strcat
      "Result: "
      (if contaminated
        "WARN_TARGET_FRAME_BLOCK_DEFINITION_OR_GEOMETRY"
        "OK_TARGET_FRAME_BLOCK_DEFINITIONS"
      )
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-clean-frame-def-title-children (/ *error* doc records total answer deleted-count record frame-name touched)
  (defun *error* (msg)
    (if doc
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
    )
    (if msg
      (swcad-title-princ-line (strcat "SWTITLEPREPARE 도면틀 정의 제목블록 정리 오류: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_FRAME_DEF_TITLE_CLEAN")
    (swcad-title-close-log)
    (princ)
  )
  (swcad-title-open-frame-def-title-clean-log)
  (setq doc (swcad-title-doc))
  (setq records (swcad-title-frame-def-title-child-records))
  (setq total (length records))
  (setq touched nil)
  (swcad-title-princ-line "----- SWTITLEPREPARE 내부 도면틀 정의 안의 중첩 제목블록 정리 -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-print-frame-def-title-child-records records)
  (cond
    ((= total 0)
      (swcad-title-apply-result "OK_NO_FRAME_DEF_TITLE_CHILDREN")
      (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "읽기 전용 도면이라 도면틀 정의를 수정하지 않았습니다.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "도면틀 정의 제목블록 정리는 Documents/CAD tool/work 안의 작업복사본에서만 실행됩니다.")
      (swcad-title-princ-line "원본 도면 보호를 위해 도면 데이터는 변경하지 않았습니다.")
    )
    (T
      (setq answer
        (getstring
          T
          "\n위 중첩 제목블록만 도면틀 정의에서 삭제하려면 YES를 입력하세요. 취소하려면 Enter: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (swcad-title-apply-result "ABORT_FRAME_DEF_TITLE_CLEAN_USER")
          (swcad-title-princ-line "사용자가 취소했습니다. 도면 데이터는 변경하지 않았습니다.")
        )
        (progn
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq deleted-count 0)
          (foreach record records
            (setq frame-name (car record))
            (if (swcad-title-delete-ename (cadr record))
              (progn
                (setq deleted-count (+ deleted-count 1))
                (setq touched (swcad-title-list-add-unique frame-name touched))
              )
            )
          )
          (foreach frame-name touched
            (entupd (tblobjname "BLOCK" frame-name))
          )
          (vl-catch-all-apply 'vla-Regen (list doc 1))
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line (strcat "삭제한 중첩 제목블록: " (itoa deleted-count)))
          (swcad-title-apply-result "OK_FRAME_DEF_TITLE_CHILDREN_CLEANED")
          (swcad-title-princ-line "다음: SWTITLESTATUS와 SWTITLEVERIFY를 다시 실행해서 중복 표제란과 겹침 경고가 사라졌는지 확인하세요.")
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-a3-frame-embedded-title-scan ()
  (swcad-title-open-a3-frame-clean-log)
  (swcad-title-princ-line "----- SWTITLEPREPARE 내부 A3 도면틀 내부 표제란 형상 스캔(읽기 전용) -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-print-a3-frame-embedded-title-records (swcad-title-a3-frame-embedded-title-records))
  (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-a3-frame-embedded-title-clean (/ *error* doc records total answer deleted-count record touched block-name)
  (defun *error* (msg)
    (if doc
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
    )
    (if msg
      (swcad-title-princ-line (strcat "SWTITLEPREPARE A3 도면틀 내부 표제란 정리 오류: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_A3_FRAME_EMBEDDED_TITLE_CLEAN")
    (swcad-title-close-log)
    (princ)
  )
  (swcad-title-open-a3-frame-clean-log)
  (setq doc (swcad-title-doc))
  (setq records (swcad-title-a3-frame-embedded-title-records))
  (setq total (length records))
  (setq touched nil)
  (swcad-title-princ-line "----- SWTITLEPREPARE 내부 A3 도면틀 내부 표제란 형상 정리 -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-print-a3-frame-embedded-title-records records)
  (cond
    ((= total 0)
      (swcad-title-apply-result "OK_NO_A3_FRAME_EMBEDDED_TITLE")
      (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "읽기 전용 도면이라 A3 도면틀 정의를 수정하지 않았습니다.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "A3 도면틀 내부 표제란 정리는 Documents/CAD tool/work 안의 작업복사본에서만 실행됩니다.")
      (swcad-title-princ-line "원본 도면 보호를 위해 도면 데이터는 변경하지 않았습니다.")
    )
    (T
      (setq answer
        (getstring
          T
          "\n위 A3 도면틀 내부 표제란 형상만 삭제하려면 YES를 입력하세요. 취소하려면 Enter: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (swcad-title-apply-result "ABORT_A3_FRAME_EMBEDDED_TITLE_CLEAN_USER")
          (swcad-title-princ-line "사용자가 취소했습니다. 도면 데이터는 변경하지 않았습니다.")
        )
        (progn
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq deleted-count 0)
          (foreach record records
            (setq block-name (car record))
            (if (swcad-title-delete-ename (cadr record))
              (progn
                (setq deleted-count (+ deleted-count 1))
                (setq touched (swcad-title-list-add-unique block-name touched))
              )
            )
          )
          (foreach block-name touched
            (entupd (tblobjname "BLOCK" block-name))
          )
          (vl-catch-all-apply 'vla-Regen (list doc 1))
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line (strcat "삭제한 A3 도면틀 내부 표제란 형상: " (itoa deleted-count)))
          (swcad-title-apply-result "OK_A3_FRAME_EMBEDDED_TITLE_CLEANED")
          (swcad-title-princ-line "다음: 화면에서 A3 도면틀 안의 내장 표제란이 사라졌는지 확인하고, SWTITLESTATUS와 SWTITLEVERIFY를 다시 실행하세요.")
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-frame-embedded-title-clean (/ *error* doc records total answer deleted-count record touched owner-name)
  (defun *error* (msg)
    (if doc
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
    )
    (if msg
      (swcad-title-princ-line (strcat "SWTITLEPREPARE frame embedded title cleanup error: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_FRAME_EMBEDDED_TITLE_CLEAN")
    (swcad-title-close-log)
    (princ)
  )
  (swcad-title-open-frame-embedded-title-clean-log)
  (setq doc (swcad-title-doc))
  (setq records (swcad-title-frame-embedded-title-records))
  (setq total (length records))
  (setq touched nil)
  (swcad-title-princ-line "----- SWTITLEPREPARE DR 도면틀 정의 내부 표제란 형상 정리 -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-print-frame-embedded-title-records records)
  (cond
    ((= total 0)
      (swcad-title-apply-result "OK_NO_FRAME_EMBEDDED_TITLE")
      (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "읽기 전용 도면이라 도면틀 정의를 수정하지 않았습니다.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "DR 도면틀 정의 정리는 Documents/CAD tool/work 안의 작업복사본에서만 실행합니다.")
      (swcad-title-princ-line "원본 도면 보호를 위해 도면 데이터는 변경하지 않았습니다.")
    )
    (T
      (setq answer
        (getstring
          T
          "\n위 후보 중 외곽선/눈금/좌표표시를 제외한 표제란 영역 형상만 삭제하려면 YES를 입력하세요. 취소하려면 Enter: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (swcad-title-apply-result "ABORT_FRAME_EMBEDDED_TITLE_CLEAN_USER")
          (swcad-title-princ-line "사용자가 취소했습니다. 도면 데이터는 변경하지 않았습니다.")
        )
        (progn
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (foreach record records
            (setq owner-name (cadr record))
            (setq touched (swcad-title-list-add-unique owner-name touched))
          )
          (setq deleted-count (car (swcad-title-frame-style-normalization-delete-records records)))
          (foreach owner-name touched
            (entupd (tblobjname "BLOCK" owner-name))
          )
          (vl-catch-all-apply 'vla-Regen (list doc 1))
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line (strcat "삭제한 도면틀 내부 표제란 형상: " (itoa deleted-count)))
          (swcad-title-apply-result "OK_FRAME_EMBEDDED_TITLE_CLEANED")
          (swcad-title-princ-line "다음: SWTITLESTATUS로 경고가 줄었는지 확인한 뒤 SWTITLECONVERTNEXT를 실행하세요.")
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-block-definition-entity-data-list (block-name / block result item item-ename data)
  (setq block (swcad-title-block-definition-object block-name))
  (setq result nil)
  (if block
    (vlax-for item block
      (setq item-ename (swcad-title-vla-object->ename item))
      (if item-ename
        (progn
          (setq data (entget item-ename))
          (if data
            (setq result (append result (list data)))
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-entmake-copyable-dxf-pair-p (pair / code)
  (setq code (if (listp pair) (car pair) nil))
  (and
    code
    (not (member code '(-1 5 67 102 330 331 360 410)))
  )
)

(defun swcad-title-sanitize-entmake-entity-data (data / result pair)
  (setq result nil)
  (foreach pair data
    (if (swcad-title-entmake-copyable-dxf-pair-p pair)
      (setq result (append result (list pair)))
    )
  )
  result
)

(defun swcad-title-block-definition-header-data (block-name / ename)
  (setq ename (tblobjname "BLOCK" block-name))
  (if ename (entget ename) nil)
)

(defun swcad-title-entmake-block-definition-begin (new-name source-name / source-data base-point flags layer result)
  (setq source-data (swcad-title-block-definition-header-data source-name))
  (setq base-point (swcad-title-dxf-value source-data 10))
  (setq flags (swcad-title-dxf-value source-data 70))
  (setq layer (swcad-title-dxf-value source-data 8))
  (if (not base-point)
    (setq base-point '(0.0 0.0 0.0))
  )
  (if (not flags)
    (setq flags 0)
  )
  (if (or (not layer) (= (strlen (swcad-title-string layer)) 0))
    (setq layer "0")
  )
  (setq result
    (entmake
      (list
        '(0 . "BLOCK")
        '(100 . "AcDbEntity")
        (cons 8 layer)
        '(100 . "AcDbBlockBegin")
        (cons 2 new-name)
        (cons 70 flags)
        (cons 10 base-point)
      )
    )
  )
  (if result T nil)
)

(defun swcad-title-entmake-block-definition-end (/ result)
  (setq result
    (entmake
      (list
        '(0 . "ENDBLK")
        '(100 . "AcDbEntity")
        '(100 . "AcDbBlockEnd")
      )
    )
  )
  (if result T nil)
)

(defun swcad-title-delete-block-definition (block-name / block result)
  (setq block (swcad-title-block-definition-object block-name))
  (if block
    (progn
      (setq result (vl-catch-all-apply 'vla-Delete (list block)))
      (not (vl-catch-all-error-p result))
    )
    nil
  )
)

(defun swcad-title-record-handles-for-owner (records owner-name / result record handle)
  (setq result nil)
  (foreach record records
    (if (equal (strcase (swcad-title-string (cadr record))) (strcase (swcad-title-string owner-name)))
      (progn
        (setq handle (nth 3 record))
        (if handle
          (setq result (swcad-title-list-add-unique handle result))
        )
      )
    )
  )
  result
)

(defun swcad-title-record-owner-names (records / result record owner-name)
  (setq result nil)
  (foreach record records
    (setq owner-name (cadr record))
    (if owner-name
      (setq result (swcad-title-list-add-unique owner-name result))
    )
  )
  result
)

(defun swcad-title-string-member-ci-p (value values / target found item)
  (setq target (strcase (swcad-title-string value)))
  (setq found nil)
  (foreach item values
    (if (equal target (strcase (swcad-title-string item)))
      (setq found T)
    )
  )
  found
)

(defun swcad-title-style-normalization-records-for-owner (records owner-name / result record)
  (setq result nil)
  (foreach record records
    (if (equal (strcase (swcad-title-string (cadr record))) (strcase (swcad-title-string owner-name)))
      (setq result (append result (list record)))
    )
  )
  result
)

(defun swcad-title-style-normalization-owner-descendant-p (owner-name frame-name / descendants)
  (setq descendants (swcad-title-block-descendant-insert-names frame-name))
  (swcad-title-string-member-ci-p owner-name descendants)
)

(defun swcad-title-style-normalization-owner-safe-p (owner-name records / owner-records ok record frame-name)
  (cond
    ((swcad-title-native-target-frame-name-p owner-name)
      T
    )
    (T
      (setq owner-records (swcad-title-style-normalization-records-for-owner records owner-name))
      (setq ok (if owner-records T nil))
      (foreach record owner-records
        (setq frame-name (car record))
        (if
          (not
            (and
              (swcad-title-native-target-frame-name-p frame-name)
              (swcad-title-style-normalization-owner-descendant-p owner-name frame-name)
            )
          )
          (setq ok nil)
        )
      )
      ok
    )
  )
)

(defun swcad-title-dxf-replace-code (data code value / result pair replaced)
  (setq result nil)
  (setq replaced nil)
  (foreach pair data
    (if (and (listp pair) (= (car pair) code))
      (progn
        (setq result (append result (list (cons code value))))
        (setq replaced T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if replaced result (append result (list (cons code value))))
)

(defun swcad-title-records-for-frame-name (records frame-name / result record)
  (setq result nil)
  (foreach record records
    (if (equal (strcase (swcad-title-string (car record))) (strcase (swcad-title-string frame-name)))
      (setq result (append result (list record)))
    )
  )
  result
)

(defun swcad-title-frame-names-from-records (records / result record)
  (setq result nil)
  (foreach record records
    (setq result (swcad-title-list-add-unique (car record) result))
  )
  result
)

(defun swcad-title-records-under-insert-prefix (records prefix / result record path)
  (setq result nil)
  (foreach record records
    (setq path (nth 11 record))
    (if (swcad-title-frame-style-path-prefix-p prefix path)
      (setq result (append result (list record)))
    )
  )
  result
)

(defun swcad-title-record-delete-at-owner-path-p (records owner-name insert-path handle / found record)
  (setq found nil)
  (foreach record records
    (if
      (and
        (equal (strcase (swcad-title-string (cadr record))) (strcase (swcad-title-string owner-name)))
        (equal (nth 11 record) insert-path)
        (equal (strcase (swcad-title-string (nth 3 record))) (strcase (swcad-title-string handle)))
      )
      (setq found T)
    )
  )
  found
)

(defun swcad-title-copy-clean-block-tree (source-name new-name records insert-path / source-data child-mappings child-copied child-skipped child-failed data handle etype child-name child-prefix child-records child-clean-name child-result mapping begin-ok end-ok copied skipped failed clean-data make-result)
  (setq source-data (swcad-title-block-definition-entity-data-list source-name))
  (setq child-mappings nil)
  (setq child-copied 0)
  (setq child-skipped 0)
  (setq child-failed 0)
  ;; Build affected descendants first; AutoLISP cannot start a child BLOCK while
  ;; the parent BLOCK definition is still being entmade.
  (foreach data source-data
    (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
    (setq etype (strcase (swcad-title-string (swcad-title-dxf-value data 0))))
    (if
      (and
        (equal etype "INSERT")
        (not (swcad-title-record-delete-at-owner-path-p records source-name insert-path handle))
      )
      (progn
        (setq child-name (swcad-title-string (swcad-title-dxf-value data 2)))
        (setq child-prefix (append insert-path (list handle)))
        (setq child-records (swcad-title-records-under-insert-prefix records child-prefix))
        (if child-records
          (progn
            (setq child-clean-name (swcad-title-unique-block-name (strcat child-name "$SWTITLE_CLEAN")))
            (setq child-result
              (swcad-title-copy-clean-block-tree child-name child-clean-name child-records child-prefix)
            )
            (if (car child-result)
              (progn
                (setq child-mappings (append child-mappings (list (cons handle child-clean-name))))
                (setq child-copied (+ child-copied (nth 2 child-result)))
                (setq child-skipped (+ child-skipped (nth 3 child-result)))
              )
              (setq child-failed (+ child-failed (max 1 (nth 4 child-result))))
            )
          )
        )
      )
    )
  )
  (setq copied child-copied)
  (setq skipped child-skipped)
  (setq failed child-failed)
  (if (> failed 0)
    (list nil new-name copied skipped failed)
    (progn
      (setq begin-ok (swcad-title-entmake-block-definition-begin new-name source-name))
      (if (not begin-ok)
        (setq failed (+ failed 1))
      )
      (if begin-ok
        (foreach data source-data
          (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
          (if (swcad-title-record-delete-at-owner-path-p records source-name insert-path handle)
            (setq skipped (+ skipped 1))
            (progn
              (setq clean-data (swcad-title-sanitize-entmake-entity-data data))
              (setq mapping (assoc handle child-mappings))
              (if (and clean-data mapping)
                (setq clean-data (swcad-title-dxf-replace-code clean-data 2 (cdr mapping)))
              )
              (setq make-result (if clean-data (vl-catch-all-apply 'entmake (list clean-data)) nil))
              (if (or (not make-result) (vl-catch-all-error-p make-result))
                (setq failed (+ failed 1))
                (setq copied (+ copied 1))
              )
            )
          )
        )
      )
      (setq end-ok (if begin-ok (swcad-title-entmake-block-definition-end) nil))
      (if (not end-ok)
        (setq failed (+ failed 1))
      )
      (list (= failed 0) new-name copied skipped failed)
    )
  )
)

(defun swcad-title-rebuild-frame-definition-tree-skipping-records (frame-name records / frame-inserts clean-root backup-name copy-result renamed-old renamed-clean retarget-count retarget-failed ename failed-clean-name)
  (setq frame-inserts (swcad-title-inserts-by-effective-name frame-name))
  (setq clean-root (swcad-title-unique-block-name (strcat frame-name "$SWTITLE_CLEAN")))
  (setq copy-result (swcad-title-copy-clean-block-tree frame-name clean-root records nil))
  (if (not (car copy-result))
    (list nil "" (nth 2 copy-result) (nth 3 copy-result) 0 (max 1 (nth 4 copy-result)))
    (progn
      (setq backup-name (swcad-title-unique-block-name frame-name))
      (setq renamed-old (swcad-title-rename-block-definition frame-name backup-name))
      (setq renamed-clean (if renamed-old (swcad-title-rename-block-definition clean-root frame-name) nil))
      (if (not renamed-clean)
        (progn
          (if (and renamed-old (not (swcad-title-block-exists-p frame-name)))
            (swcad-title-rename-block-definition backup-name frame-name)
          )
          (list nil backup-name (nth 2 copy-result) (nth 3 copy-result) 0 1)
        )
        (progn
          (setq retarget-count 0)
          (setq retarget-failed 0)
          (foreach ename frame-inserts
            (if (swcad-title-change-insert-block-name ename frame-name)
              (setq retarget-count (+ retarget-count 1))
              (setq retarget-failed (+ retarget-failed 1))
            )
          )
          (if (= retarget-failed 0)
            (list T backup-name (nth 2 copy-result) (nth 3 copy-result) retarget-count 0)
            (progn
              (setq failed-clean-name (swcad-title-unique-block-name (strcat frame-name "$SWTITLE_FAILED")))
              (swcad-title-rename-block-definition frame-name failed-clean-name)
              (if (not (swcad-title-block-exists-p frame-name))
                (swcad-title-rename-block-definition backup-name frame-name)
              )
              (list nil backup-name (nth 2 copy-result) (nth 3 copy-result) retarget-count retarget-failed)
            )
          )
        )
      )
    )
  )
)

(defun swcad-title-rebuild-block-definition-skipping-handles (block-name skip-handles / source-data backup-name insert-enames renamed begin-ok end-ok data handle copied-count skipped-count failed-count retarget-count clean-data make-result ename rollback cleanup)
  (setq copied-count 0)
  (setq skipped-count 0)
  (setq failed-count 0)
  (setq retarget-count 0)
  (setq rollback nil)
  (setq cleanup nil)
  (cond
    ((not (swcad-title-block-exists-p block-name))
      (list nil "" 0 0 0 1)
    )
    ((not skip-handles)
      (list T "" 0 0 0 0)
    )
    (T
      (setq source-data (swcad-title-block-definition-entity-data-list block-name))
      (setq insert-enames (swcad-title-all-insert-references-by-effective-name block-name))
      (setq backup-name (swcad-title-unique-block-name block-name))
      (setq renamed (swcad-title-rename-block-definition block-name backup-name))
      (if (not renamed)
        (list nil backup-name copied-count skipped-count retarget-count 1)
        (progn
          (setq begin-ok (swcad-title-entmake-block-definition-begin block-name backup-name))
          (if begin-ok
            (progn
              (foreach data source-data
                (setq handle (swcad-title-dxf-value data 5))
                (if (member handle skip-handles)
                  (setq skipped-count (+ skipped-count 1))
                  (progn
                    (setq clean-data (swcad-title-sanitize-entmake-entity-data data))
                    (setq make-result (if clean-data (vl-catch-all-apply 'entmake (list clean-data)) nil))
                    (if (or (not make-result) (vl-catch-all-error-p make-result))
                      (setq failed-count (+ failed-count 1))
                      (setq copied-count (+ copied-count 1))
                    )
                  )
                )
              )
              (setq end-ok (swcad-title-entmake-block-definition-end))
              (if (not end-ok)
                (setq failed-count (+ failed-count 1))
              )
            )
            (setq failed-count (+ failed-count 1))
          )
          (if (= failed-count 0)
            (progn
              (foreach ename insert-enames
                (if (swcad-title-change-insert-block-name ename block-name)
                  (setq retarget-count (+ retarget-count 1))
                )
              )
              (if (< retarget-count (length insert-enames))
                (setq failed-count (+ failed-count (- (length insert-enames) retarget-count)))
              )
              (if (= failed-count 0)
                (list T backup-name copied-count skipped-count retarget-count failed-count)
                (progn
                  (if (swcad-title-block-exists-p block-name)
                    (setq cleanup (swcad-title-delete-block-definition block-name))
                  )
                  (if (and (swcad-title-block-exists-p backup-name) (not (swcad-title-block-exists-p block-name)))
                    (setq rollback (swcad-title-rename-block-definition backup-name block-name))
                  )
                  (list nil backup-name copied-count skipped-count retarget-count failed-count)
                )
              )
            )
            (progn
              (if (swcad-title-block-exists-p block-name)
                (setq cleanup (swcad-title-delete-block-definition block-name))
              )
              (if (and (swcad-title-block-exists-p backup-name) (not (swcad-title-block-exists-p block-name)))
                (setq rollback (swcad-title-rename-block-definition backup-name block-name))
              )
              (list nil backup-name copied-count skipped-count retarget-count failed-count)
            )
          )
        )
      )
    )
  )
)

(defun swcad-title-delete-block-definition-entity-record (record / owner-name target-handle block deleted item item-ename item-handle delete-result)
  (setq owner-name (cadr record))
  (setq target-handle (nth 3 record))
  (setq block (swcad-title-block-definition-object owner-name))
  (setq deleted nil)
  (if block
    (vlax-for item block
      (if (not deleted)
        (progn
          (setq item-ename (swcad-title-vla-object->ename item))
          (setq item-handle (if item-ename (swcad-title-ename-handle item-ename) ""))
          (if (equal (strcase (swcad-title-string item-handle)) (strcase (swcad-title-string target-handle)))
            (progn
              (setq delete-result (vl-catch-all-apply 'vla-Delete (list item)))
              (if (not (vl-catch-all-error-p delete-result))
                (setq deleted T)
              )
            )
          )
        )
      )
    )
  )
  (if deleted
    T
    (swcad-title-delete-ename (nth 2 record))
  )
)

(defun swcad-title-delete-block-definition-entity-records-for-owner (records owner-name / owner-records deleted-count record)
  (setq owner-records (swcad-title-style-normalization-records-for-owner records owner-name))
  (setq deleted-count 0)
  (foreach record owner-records
    (if (swcad-title-delete-block-definition-entity-record record)
      (setq deleted-count (+ deleted-count 1))
    )
  )
  deleted-count
)

(defun swcad-title-frame-style-normalization-delete-records (records / normalized-count touched frame-names frame-name frame-records owners owner-name safe rebuild result-ok backup-name copied-count skipped-count retarget-count failed-count)
  (setq normalized-count 0)
  (setq touched nil)
  (setq frame-names (swcad-title-frame-names-from-records records))
  (foreach frame-name frame-names
    (setq frame-records (swcad-title-records-for-frame-name records frame-name))
    (setq owners (swcad-title-record-owner-names frame-records))
    (setq safe T)
    (foreach owner-name owners
      (if (not (swcad-title-style-normalization-owner-safe-p owner-name frame-records))
        (setq safe nil)
      )
    )
    (if (not safe)
      (swcad-title-princ-line
        (strcat
          "  "
          frame-name
          ": skip, one or more cleanup owners are not checked descendants of this native frame."
        )
      )
      (progn
        (setq rebuild (swcad-title-rebuild-frame-definition-tree-skipping-records frame-name frame-records))
        (setq result-ok (car rebuild))
        (setq backup-name (cadr rebuild))
        (setq copied-count (nth 2 rebuild))
        (setq skipped-count (nth 3 rebuild))
        (setq retarget-count (nth 4 rebuild))
        (setq failed-count (nth 5 rebuild))
        (if result-ok
          (progn
            (setq normalized-count (+ normalized-count skipped-count))
            (setq touched (swcad-title-list-add-unique frame-name touched))
            (swcad-title-princ-line
              (strcat
                "  "
                frame-name
                ": normalized nested block tree, backup="
                backup-name
                ", copied="
                (itoa copied-count)
                ", removed-title-geometry="
                (itoa skipped-count)
                ", retargeted-frame-inserts="
                (itoa retarget-count)
              )
            )
          )
          (swcad-title-princ-line
            (strcat
              "  "
              frame-name
              ": FAILED to normalize nested block tree, backup="
              backup-name
              ", copied="
              (itoa copied-count)
              ", intended-remove="
              (itoa skipped-count)
              ", retargeted-frame-inserts="
              (itoa retarget-count)
              ", failed="
              (itoa failed-count)
            )
          )
        )
      )
    )
  )
  (foreach frame-name touched
    (if (tblobjname "BLOCK" frame-name)
      (entupd (tblobjname "BLOCK" frame-name))
    )
  )
  (list normalized-count touched)
)

(defun swcad-title-frame-style-normalization-delete-records-legacy-unused (records / normalized-count touched owners owner-name skip-handles rebuild result-ok backup-name copied-count skipped-count retarget-count failed-count)
  (setq normalized-count 0)
  (setq touched nil)
  (setq owners (swcad-title-record-owner-names records))
  (foreach owner-name owners
    (setq skip-handles (swcad-title-record-handles-for-owner records owner-name))
    (cond
      ((not (swcad-title-style-normalization-owner-safe-p owner-name records))
        (swcad-title-princ-line
          (strcat
            "  "
            owner-name
            ": skip, frame-style cleanup owner is not a native frame or a checked native-frame descendant."
          )
        )
      )
      (T
        (setq rebuild (swcad-title-rebuild-block-definition-skipping-handles owner-name skip-handles))
        (setq result-ok (car rebuild))
        (setq backup-name (cadr rebuild))
        (setq copied-count (nth 2 rebuild))
        (setq skipped-count (nth 3 rebuild))
        (setq retarget-count (nth 4 rebuild))
        (setq failed-count (nth 5 rebuild))
        (if result-ok
          (progn
            (setq normalized-count (+ normalized-count skipped-count))
            (setq touched (swcad-title-list-add-unique owner-name touched))
            (swcad-title-princ-line
              (strcat
                "  "
                owner-name
                ": normalized by rebuild, backup="
                backup-name
                ", copied="
                (itoa copied-count)
                ", removed-title-geometry="
                (itoa skipped-count)
                ", retargeted-inserts="
                (itoa retarget-count)
              )
            )
          )
          (swcad-title-princ-line
            (strcat
              "  "
              owner-name
              ": FAILED to normalize by rebuild, backup="
              backup-name
              ", copied="
              (itoa copied-count)
              ", intended-remove="
              (itoa skipped-count)
              ", retargeted-inserts="
              (itoa retarget-count)
              ", failed="
              (itoa failed-count)
            )
          )
        )
      )
    )
  )
  (foreach owner-name touched
    (entupd (tblobjname "BLOCK" owner-name))
  )
  (list normalized-count touched)
)

(defun swcad-title-frame-style-normalization-clean (/ *error* doc cache-owned style-records records verify-records protected-records total verify-total answer delete-result deleted-count remaining remaining-count)
  (defun *error* (msg)
    (if doc
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
    )
    (if msg
      (swcad-title-princ-line (strcat "SWTITLEPREPARE frame style normalization error: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_FRAME_STYLE_NORMALIZATION_CLEAN")
    (if cache-owned
      (swcad-title-frame-style-analysis-cache-end)
    )
    (swcad-title-close-log)
    (princ)
  )
  (swcad-title-open-frame-style-normalization-clean-log)
  (setq doc (swcad-title-doc))
  (setq cache-owned (not *swcad-title-frame-style-analysis-cache-enabled*))
  (if cache-owned
    (swcad-title-frame-style-analysis-cache-begin)
  )
  (setq style-records (swcad-title-frame-style-normalization-records))
  (setq records (swcad-title-frame-style-records-from-pairs style-records 12))
  (setq verify-records (swcad-title-frame-style-records-from-pairs style-records 13))
  (setq protected-records (swcad-title-frame-style-records-from-pairs style-records 14))
  (setq total (length records))
  (setq verify-total (length verify-records))
  (setq touched nil)
  (swcad-title-princ-line "----- SWTITLEPREPARE 도면틀 스타일 정규화 -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-print-frame-style-normalization-records style-records)
  (swcad-title-princ-line "NORMALIZE 대상 엔티티:")
  (swcad-title-print-frame-embedded-title-records records)
  (swcad-title-print-frame-style-entity-records "독립 검증에서 확인한 기존 표제란 잔여물:" verify-records)
  (swcad-title-print-frame-style-entity-records "삭제하지 않고 보호하는 도면틀 객체:" protected-records)
  (cond
    ((= verify-total 0)
      (swcad-title-apply-result "OK_NO_FRAME_STYLE_NORMALIZATION")
      (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
    )
    ((= total 0)
      (swcad-title-apply-result "WARN_FRAME_STYLE_RESIDUE_UNCLASSIFIED")
      (swcad-title-princ-line "독립 검증 잔여물은 있지만 안전한 자동 삭제 후보가 없습니다.")
      (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "읽기 전용 도면이라 도면틀 스타일 정규화를 실행하지 않았습니다.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "도면틀 스타일 정규화는 사용자가 다른 이름으로 저장해 승인한 작업본에서만 실행합니다.")
      (swcad-title-princ-line "원본 도면 보호를 위해 도면 데이터는 변경하지 않았습니다.")
    )
    (T
      (setq answer
        (getstring
          T
          "\n위 NORMALIZE 후보만 정리하려면 YES를 입력하세요. 설치 원본은 수정하지 않고 현재 작업본의 제목 중복/용지 밖 하위 INSERT만 정리합니다. 취소하려면 Enter: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (swcad-title-apply-result "ABORT_FRAME_STYLE_NORMALIZATION_USER")
          (swcad-title-princ-line "사용자가 취소했습니다. 도면 데이터는 변경하지 않았습니다.")
        )
        (progn
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq delete-result (swcad-title-frame-style-normalization-delete-records records))
          (setq deleted-count (car delete-result))
          (vl-catch-all-apply 'vla-Regen (list doc 1))
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line (strcat "정규화로 정리한 도면틀 내부 제목 중복/용지 밖 잔여 형상: " (itoa deleted-count)))
          (swcad-title-frame-style-analysis-cache-invalidate)
          (setq remaining (swcad-title-frame-style-independent-residue-records))
          (setq remaining-count (length remaining))
          (swcad-title-princ-line (strcat "삭제 후 독립 잔여물 검증 수: " (itoa remaining-count)))
          (swcad-title-print-frame-style-entity-records "삭제 후에도 남아 있는 기존 표제란 잔여물:" remaining)
          (if (> remaining-count 0)
            (progn
              (swcad-title-apply-result "WARN_RESIDUE_REMAINS")
              (swcad-title-princ-line "정리가 완전히 끝나지 않았으므로 성공으로 처리하지 않습니다.")
            )
            (progn
              (swcad-title-apply-result "OK_FRAME_STYLE_NORMALIZATION_CLEANED")
              (swcad-title-princ-line "독립 검증을 통과했습니다. 같은 정리를 다시 실행해도 추가 삭제가 없어야 합니다.")
            )
          )
          (swcad-title-princ-line "다음: SWTITLESTATUS를 다시 실행해서 독립 잔여물 수가 0인지 확인하세요.")
        )
      )
    )
  )
  (if cache-owned
    (swcad-title-frame-style-analysis-cache-end)
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-invalid-frame-repair-targets-for-block (frame-name / target frame-records title-enames used-title-enames result record frame-ename frame-block frame-bbox warning title-ename)
  (setq target (strcase (swcad-title-string frame-name)))
  (setq frame-records (swcad-title-frame-records))
  (setq title-enames (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq used-title-enames nil)
  (setq result nil)
  (foreach record frame-records
    (setq frame-ename (car record))
    (setq frame-block (cadr record))
    (setq frame-bbox (cadddr record))
    (setq warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
    (if
      (and
        (equal (strcase (swcad-title-string frame-block)) target)
        warning
      )
      (progn
        (setq title-ename (swcad-title-title-for-frame-record-unused record title-enames used-title-enames))
        (if title-ename
          (setq used-title-enames (append used-title-enames (list title-ename)))
        )
        (setq result
          (append
            result
            (list
              (list
                frame-ename
                frame-bbox
                title-ename
                warning
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-rename-definition-list-to-backups (names / result name backup renamed)
  (setq result nil)
  (foreach name names
    (if (swcad-title-block-exists-p name)
      (progn
        (setq backup (swcad-title-unique-block-name name))
        (setq renamed (swcad-title-rename-block-definition name backup))
        (setq result
          (append
            result
            (list
              (list name backup renamed)
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-rollback-definition-renames (rename-results / item original backup parking)
  (foreach item (reverse rename-results)
    (setq original (car item))
    (setq backup (cadr item))
    (if (caddr item)
      (progn
        (if (swcad-title-block-exists-p original)
          (progn
            (setq parking (swcad-title-unique-block-name original))
            (swcad-title-princ-line
              (strcat
                "    rollback park "
                original
                " -> "
                parking
              )
            )
            (swcad-title-rename-block-definition original parking)
          )
        )
        (if (swcad-title-block-exists-p backup)
          (progn
            (swcad-title-princ-line
              (strcat
                "    rollback restore "
                backup
                " -> "
                original
              )
            )
            (swcad-title-rename-block-definition backup original)
          )
        )
      )
    )
  )
)

(defun swcad-title-repair-one-frame-definition-geometry (frame-name / targets children rename-names rename-results target-renamed imported repaired failed target frame-ename old-bbox title-ename new-frame new-bbox warning role test-frame test-bbox test-warning)
  (setq targets (swcad-title-invalid-frame-repair-targets-for-block frame-name))
  (if targets
    (progn
      (setq children (swcad-title-block-descendant-insert-names frame-name))
      (setq rename-names (list frame-name))
      (foreach target children
        (if
          (and
            target
            (swcad-title-block-exists-p target)
            (not (equal (strcase (swcad-title-string target)) (strcase (swcad-title-string frame-name))))
          )
          (setq rename-names (append rename-names (list target)))
        )
      )
      (swcad-title-princ-line
        (strcat
          "  "
          frame-name
          ": rebuilding, invalid inserts="
          (itoa (length targets))
          ", child-defs="
          (swcad-title-list-string children)
        )
      )
      (setq rename-results (swcad-title-rename-definition-list-to-backups rename-names))
      (setq target-renamed nil)
      (foreach target rename-results
        (swcad-title-princ-line
          (strcat
            "    rename "
            (car target)
            " -> "
            (cadr target)
            ": "
            (if (caddr target) "ok" "FAILED")
          )
        )
        (if (and (equal (strcase (car target)) (strcase (swcad-title-string frame-name))) (caddr target))
          (setq target-renamed T)
        )
      )
      (if (not target-renamed)
        (list 0 (length targets) "rename-target-failed")
        (progn
          (setq imported (swcad-title-import-clean-frame-definition frame-name))
          (swcad-title-princ-line
            (strcat
              "    import clean "
              frame-name
              ": "
              (if imported "ok" "FAILED")
            )
          )
          (setq repaired 0)
          (setq failed 0)
          (if imported
            (progn
              (setq test-frame (swcad-title-insert-block-reference frame-name 0.0 0.0))
              (setq test-bbox (if test-frame (swcad-title-frame-reference-effective-bbox test-frame frame-name) nil))
              (setq test-warning
                (if test-frame
                  (swcad-title-frame-bbox-size-warning-for-block frame-name test-bbox)
                  "could not insert imported definition"
                )
              )
              (if test-frame
                (swcad-title-delete-ename test-frame)
              )
              (if test-warning
                (progn
                  (setq failed (length targets))
                  (swcad-title-princ-line
                    (strcat
                      "    imported "
                      frame-name
                      " definition rejected before replacing existing inserts: "
                      test-warning
                      ", bbox="
                      (swcad-title-bbox-string test-bbox)
                    )
                  )
                  (swcad-title-princ-line
                    (strcat
                      "    rollback "
                      frame-name
                      ": installed/imported definition does not match expected A-size geometry."
                    )
                  )
                  (swcad-title-rollback-definition-renames rename-results)
                )
                (foreach target targets
                  (setq frame-ename (car target))
                  (setq old-bbox (cadr target))
                  (setq title-ename (caddr target))
                  (setq new-frame (swcad-title-insert-block-reference frame-name 0.0 0.0))
                  (if new-frame
                    (progn
                      (swcad-title-move-ename-bbox-min-to new-frame (car old-bbox) (cadr old-bbox))
                      (setq new-bbox (swcad-title-frame-reference-effective-bbox new-frame frame-name))
                      (setq warning (swcad-title-frame-bbox-size-warning-for-block frame-name new-bbox))
                      (if warning
                        (progn
                          (swcad-title-delete-ename new-frame)
                          (setq failed (+ failed 1))
                          (swcad-title-princ-line
                            (strcat
                              "    insert "
                              (swcad-title-ename-handle frame-ename)
                              ": FAILED, new geometry still invalid, "
                              warning
                              ", bbox="
                              (swcad-title-bbox-string new-bbox)
                            )
                          )
                        )
                        (progn
                          (setq role "native-frame-def-repair")
                          (if title-ename
                            (swcad-title-mark-native-exemplar-pair title-ename new-frame frame-name role)
                            (swcad-title-set-exemplar-xdata new-frame frame-name role)
                          )
                          (swcad-title-delete-ename frame-ename)
                          (setq repaired (+ repaired 1))
                          (swcad-title-princ-line
                            (strcat
                              "    insert "
                              (swcad-title-ename-handle new-frame)
                              ": repaired old="
                              (swcad-title-ename-handle frame-ename)
                              ", title="
                              (if title-ename (swcad-title-ename-handle title-ename) "<missing>")
                              ", bbox="
                              (swcad-title-bbox-string new-bbox)
                            )
                          )
                        )
                      )
                    )
                    (progn
                      (setq failed (+ failed 1))
                      (swcad-title-princ-line
                        (strcat
                          "    old "
                          (swcad-title-ename-handle frame-ename)
                          ": FAILED, could not insert clean "
                          frame-name
                        )
                      )
                    )
                  )
                )
              )
            )
            (setq failed (length targets))
          )
          (if
            (and
              (> failed 0)
              (= repaired 0)
              (not test-warning)
            )
            (progn
              (swcad-title-princ-line
                (strcat
                  "    rollback "
                  frame-name
                  ": no clean replacement matched expected geometry."
                )
              )
              (swcad-title-rollback-definition-renames rename-results)
            )
          )
          (list
            repaired
            failed
            (cond
              ((not imported) "import-failed")
              (test-warning "imported-invalid-geometry")
              (T "ok")
            )
          )
        )
      )
    )
    (list 0 0 "no-invalid-inserts")
  )
)

(defun swcad-title-repair-frame-definitions (/ doc answer frame-name result repaired failed status)
  (swcad-title-open-frame-def-repair-log)
  (swcad-title-princ-line "----- SWTITLEPREPARE 내부 대상 도면틀 정의 형상 복구 -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq repaired 0)
  (setq failed 0)
  (cond
    ((swcad-title-document-read-only-p)
      (setq status "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before repairing frame definitions.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (setq status "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before repairing.")
    )
    (T
      (swcad-title-princ-line "Target frame block definitions before repair:")
      (swcad-title-print-frame-def-check-lines)
      (setq answer
        (getstring
          T
          "\n잘못된 형상의 참조 중인 대상 도면틀 정의를 다시 만들려면 YES를 입력하세요: "
        )
      )
      (if (not (equal (strcase answer) "YES"))
        (progn
          (setq status "ABORT_USER_CANCEL")
          (swcad-title-princ-line "No drawing data was changed.")
        )
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (foreach frame-name (swcad-title-target-frame-block-candidates)
            (setq result (swcad-title-repair-one-frame-definition-geometry frame-name))
            (setq repaired (+ repaired (car result)))
            (setq failed (+ failed (cadr result)))
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line "Target frame block definitions after repair:")
          (swcad-title-print-frame-def-check-lines)
          (setq status
            (cond
              ((> failed 0) "WARN_FRAME_DEF_REPAIR_PARTIAL")
              ((> repaired 0) "OK_FRAME_DEF_REPAIRED")
              (T "OK_NOTHING_TO_REPAIR")
            )
          )
          (swcad-title-princ-line
            (strcat
              "Summary: repaired="
              (itoa repaired)
              ", failed="
              (itoa failed)
            )
          )
        )
      )
    )
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-unique-block-name (base / index candidate)
  (setq index 1)
  (setq candidate (strcat base "_SWOLD_" (itoa index)))
  (while (swcad-title-block-exists-p candidate)
    (setq index (+ index 1))
    (setq candidate (strcat base "_SWOLD_" (itoa index)))
  )
  candidate
)

(defun swcad-title-rename-block-definition (old-name new-name / block result)
  (setq block (swcad-title-block-definition-object old-name))
  (if block
    (progn
      (setq result (vl-catch-all-apply 'vla-put-Name (list block new-name)))
      (not (vl-catch-all-error-p result))
    )
    nil
  )
)

(defun swcad-title-import-frame-definition-basic (frame-name / frame-path ename)
  (setq frame-path (swcad-title-frame-dwg-path frame-name))
  (if (findfile frame-path)
    (progn
      (setq ename (swcad-title-insert-block-reference frame-path 0.0 0.0))
      (if ename
        (progn
          (swcad-title-delete-ename ename)
          (if (swcad-title-target-frame-block-contaminated-p frame-name)
            nil
            (swcad-title-block-exists-p frame-name)
          )
        )
        nil
      )
    )
    nil
  )
)

(defun swcad-title-imported-frame-definition-usable-p (frame-name)
  (and
    (swcad-title-block-exists-p frame-name)
    (not (swcad-title-target-frame-block-contaminated-p frame-name))
    (not (swcad-title-frame-definition-raw-bbox-risk-record frame-name))
  )
)

(defun swcad-title-cleanup-failed-new-frame-definition (frame-name existed / cleanup-ok backup-name)
  (if (and (not existed) (swcad-title-block-exists-p frame-name))
    (progn
      (setq cleanup-ok (swcad-title-delete-block-definition frame-name))
      (if (not cleanup-ok)
        (progn
          (setq backup-name (swcad-title-unique-block-name frame-name))
          (swcad-title-rename-block-definition frame-name backup-name)
        )
      )
    )
  )
)

(defun swcad-title-import-clean-frame-definition (frame-name / existed imported children rename-names rename-results target-renamed retried-imported usable-after-retry)
  (setq existed (swcad-title-block-exists-p frame-name))
  (setq imported (swcad-title-import-frame-definition-basic frame-name))
  (cond
    ((not imported)
      nil
    )
    ((swcad-title-imported-frame-definition-usable-p frame-name)
      T
    )
    (T
      (setq children (swcad-title-block-descendant-insert-names frame-name))
      (if children
        (swcad-title-princ-line
          (strcat
            frame-name
            " 가져오기 후 raw bbox 위험 감지: 기존 하위 블록 이름 충돌 가능성이 있어 target+child 정의를 격리하고 다시 가져옵니다. child-defs="
            (swcad-title-list-string children)
          )
        )
      )
      (setq rename-names (cons frame-name children))
      (setq rename-results (swcad-title-rename-definition-list-to-backups rename-names))
      (setq target-renamed nil)
      (foreach target rename-results
        (if (and (equal (strcase (car target)) (strcase (swcad-title-string frame-name))) (caddr target))
          (setq target-renamed T)
        )
      )
      (if (not target-renamed)
        (progn
          (swcad-title-cleanup-failed-new-frame-definition frame-name existed)
          nil
        )
        (progn
          (setq retried-imported (swcad-title-import-frame-definition-basic frame-name))
          (setq usable-after-retry
            (and
              retried-imported
              (swcad-title-imported-frame-definition-usable-p frame-name)
            )
          )
          (if usable-after-retry
            (progn
              (swcad-title-princ-line
                (strcat
                  frame-name
                  " 재가져오기 성공: 기존 충돌 정의는 *_SWOLD_* 백업으로 보존하고 설치 원본 DR 도면틀 정의를 사용합니다."
                )
              )
              T
            )
            (progn
              (if rename-results
                (swcad-title-rollback-definition-renames rename-results)
              )
              (swcad-title-cleanup-failed-new-frame-definition frame-name existed)
              nil
            )
          )
        )
      )
    )
  )
)

(defun swcad-title-prepare-title-missing-outline-definition (/ frame-block status answer doc existed imported test-frame test-bbox geometry-warning raw-warning raw-risk strict-warning native-outside-marker-ok cleanup-ok backup-name)
  (setq frame-block (swcad-title-title-missing-outline-target-block))
  (setq status (swcad-title-title-missing-outline-definition-status))
  (swcad-title-princ-text "\ntitle-missing/frame-only DR 도면틀 정의 준비:")
  (swcad-title-print-title-missing-outline-definition-status)
  (cond
    ((swcad-title-title-missing-outline-definition-ready-p)
      (swcad-title-princ-text "\ntitle-missing/frame-only 정의 준비: 이미 준비됨")
    )
    ((not (equal status "missing"))
      (swcad-title-apply-result "WARN_TITLE_MISSING_OUTLINE_DEFINITION_UNSAFE")
      (swcad-title-princ-line "기존 DR 도면틀 정의가 없어진 상태가 아니라 오염/범위 위험 상태입니다.")
      (swcad-title-princ-line "기존 정의를 자동 교체하지 않습니다. 위의 도면틀 정의 정리/복구 로그를 먼저 확인하세요.")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "쓰기 가능한 work 폴더 작업복사본에서 다시 실행하세요.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Documents/CAD tool/work 아래 작업복사본에서만 DR 도면틀 정의를 가져옵니다.")
    )
    (T
      (setq answer
        (getstring
          T
          "\n같은 크기 DR_A*_Outline 정의를 설치 원본에서 가져와 형상/선택범위를 검사하려면 YES를 입력하세요: "
        )
      )
      (if (not (equal (strcase answer) "YES"))
        (swcad-title-apply-result "ABORT_TITLE_MISSING_OUTLINE_DEFINITION_USER")
        (progn
          (setq doc (swcad-title-doc))
          (setq existed (swcad-title-block-exists-p frame-block))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq imported (swcad-title-import-clean-frame-definition frame-block))
          (setq test-frame
            (if imported
              (swcad-title-insert-block-reference frame-block 0.0 0.0)
              nil
            )
          )
          (setq test-bbox
            (if test-frame
              (swcad-title-frame-reference-effective-bbox test-frame frame-block)
              nil
            )
          )
          (setq geometry-warning
            (if test-frame
              (swcad-title-frame-bbox-size-warning-for-block frame-block test-bbox)
              "DR 도면틀 테스트 INSERT를 만들 수 없습니다."
            )
          )
          (setq raw-warning
            (if test-frame
              (swcad-title-frame-reference-raw-selection-warning test-frame frame-block test-bbox)
              nil
            )
          )
          (setq raw-risk
            (if imported
              (swcad-title-frame-definition-raw-bbox-risk-record frame-block)
              nil
            )
          )
          (setq strict-warning
            (if imported
              (swcad-title-title-missing-outline-raw-sheet-warning frame-block)
              nil
            )
          )
          (setq native-outside-marker-ok
            (and
              strict-warning
              (not raw-risk)
              (not geometry-warning)
              (not raw-warning)
            )
          )
          (if test-frame
            (swcad-title-delete-ename test-frame)
          )
          (cond
            ((and imported (not geometry-warning) (not raw-warning) (not raw-risk))
              (swcad-title-apply-result "OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED")
              (swcad-title-princ-line (strcat "가져온 DR 도면틀 테스트 범위: " (swcad-title-bbox-string test-bbox)))
              (if native-outside-marker-ok
                (progn
                  (swcad-title-princ-line "가져온 DR 도면틀 정의에는 공식 native 도면틀의 작은 바깥 마커가 있습니다.")
                  (swcad-title-princ-line "테스트 INSERT의 effective 형상과 raw selection 검사가 통과했으므로 title-missing 도면틀-only 변환에는 사용할 수 있습니다.")
                  (swcad-title-princ-line (strcat "참고 정의 범위: " strict-warning))
                )
              )
              (swcad-title-princ-line "다음: SWTITLESTATUS를 다시 실행한 뒤 SWTITLECONVERTNEXT로 title-missing 도면틀-only 변환을 진행하세요.")
            )
            (T
              (if (and imported (not existed) (swcad-title-block-exists-p frame-block))
                (progn
                  (setq cleanup-ok (swcad-title-delete-block-definition frame-block))
                  (if (not cleanup-ok)
                    (progn
                      (setq backup-name (swcad-title-unique-block-name frame-block))
                      (swcad-title-rename-block-definition frame-block backup-name)
                    )
                  )
                )
              )
              (swcad-title-apply-result "WARN_TITLE_MISSING_OUTLINE_DEFINITION_UNSAFE")
              (swcad-title-princ-line "가져온 DR 도면틀 정의가 title-missing/frame-only 자동 교체 기준을 통과하지 못했습니다.")
              (swcad-title-princ-line (strcat "imported=" (if imported "yes" "no")))
              (if test-bbox
                (swcad-title-princ-line (strcat "테스트 범위: " (swcad-title-bbox-string test-bbox)))
              )
              (if geometry-warning
                (swcad-title-princ-line (strcat "형상 경고: " geometry-warning))
              )
              (if raw-risk
                (swcad-title-princ-line (strcat "정의 선택범위 위험: " (caddr raw-risk)))
              )
              (if raw-warning
                (swcad-title-princ-line (strcat "선택 범위 경고: " raw-warning))
              )
              (if strict-warning
                (swcad-title-princ-line (strcat "정의 범위 경고: " strict-warning))
              )
              (if (and imported (not existed))
                (swcad-title-princ-line "실패한 DR 도면틀 정의는 사용하지 않도록 제거/격리했습니다.")
              )
              (swcad-title-princ-line "기존 원본 도면틀은 삭제하지 않았습니다.")
            )
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
        )
      )
    )
  )
  (princ)
)

(defun swcad-title-frame-def-clean-safe (/ doc answer frame-name exists old-child-names raw-risk-record raw-risk-after insert-count children rename-names rename-results target-renamed target backup-name renamed imported imported-valid rollback any-contaminated cleaned skipped failed skipped-referenced skipped-missing)
  (swcad-title-open-frame-def-clean-log)
  (swcad-title-princ-line "----- SWTITLEPREPARE 내부 대상 도면틀 정의 안전 정리 -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq cleaned 0)
  (setq skipped 0)
  (setq failed 0)
  (setq skipped-referenced 0)
  (setq skipped-missing 0)
  (setq any-contaminated nil)
  (cond
    ((swcad-title-document-read-only-p)
      (swcad-title-princ-line "Result: ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before cleaning frame definitions.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-princ-line "Result: ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before cleaning.")
    )
    (T
      (swcad-title-princ-line "Target frame block definitions before cleanup:")
      (swcad-title-print-frame-def-check-lines)
      (setq answer
        (getstring
          T
          "\n사용되지 않는 오염된 DR_A*_Outline 정의만 복구하려면 YES를 입력하세요: "
        )
      )
      (if (not (equal (strcase answer) "YES"))
        (progn
          (swcad-title-princ-line "Result: ABORT_USER_CANCEL")
          (swcad-title-princ-line "No drawing data was changed.")
        )
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (foreach frame-name (swcad-title-target-frame-block-candidates)
            (setq exists (swcad-title-block-exists-p frame-name))
            (setq old-child-names (if exists (swcad-title-target-frame-block-source-like-children frame-name) nil))
            (setq raw-risk-record (if exists (swcad-title-frame-definition-raw-bbox-risk-record frame-name) nil))
            (setq insert-count (if exists (swcad-title-count-inserts-by-effective-name frame-name) 0))
            (cond
              ((not exists)
                (setq skipped-missing (+ skipped-missing 1))
                (swcad-title-princ-line
                  (strcat
                    "  "
                    frame-name
                    ": skip, definition does not exist."
                  )
                )
              )
              ((and (not old-child-names) (not raw-risk-record))
                (setq skipped (+ skipped 1))
                (swcad-title-princ-line
                  (strcat
                    "  "
                    frame-name
                    ": skip, definition is already clean."
                  )
                )
              )
              ((> insert-count 0)
                (setq any-contaminated T)
                (setq skipped-referenced (+ skipped-referenced 1))
                (swcad-title-princ-line
                  (strcat
                    "  "
                    frame-name
                    ": skip, definition needs repair but is referenced by "
                    (itoa insert-count)
                    " insert(s). Children="
                    (swcad-title-list-string old-child-names)
                    ", raw-risk="
                    (if raw-risk-record "yes" "no")
                  )
                )
              )
              (T
                (setq any-contaminated T)
                (setq children (swcad-title-block-descendant-insert-names frame-name))
                (setq rename-names (cons frame-name children))
                (setq rename-results (swcad-title-rename-definition-list-to-backups rename-names))
                (setq backup-name nil)
                (setq target-renamed nil)
                (foreach target rename-results
                  (if (equal (strcase (car target)) (strcase (swcad-title-string frame-name)))
                    (progn
                      (setq backup-name (cadr target))
                      (setq target-renamed (caddr target))
                    )
                  )
                )
                (setq renamed target-renamed)
                (setq imported (if renamed (swcad-title-import-clean-frame-definition frame-name) nil))
                (setq raw-risk-after (if (and renamed imported (swcad-title-block-exists-p frame-name)) (swcad-title-frame-definition-raw-bbox-risk-record frame-name) nil))
                (setq imported-valid (and renamed imported (not raw-risk-after)))
                (if imported-valid
                  (progn
                    (setq cleaned (+ cleaned 1))
                    (swcad-title-princ-line
                      (strcat
                        "  "
                        frame-name
                        ": cleaned, old definition renamed to "
                        backup-name
                        " and clean install definition imported."
                      )
                    )
                  )
                  (progn
                    (setq rollback nil)
                    (if renamed
                      (progn
                        (swcad-title-rollback-definition-renames rename-results)
                        (setq rollback T)
                      )
                    )
                    (setq failed (+ failed 1))
                    (swcad-title-princ-line
                      (strcat
                        "  "
                        frame-name
                        ": FAILED, renamed="
                        (if renamed "yes" "no")
                        ", imported="
                        (if imported "yes" "no")
                        ", raw-risk-after="
                        (if raw-risk-after "yes" "no")
                        ", rollback="
                        (if rollback "yes" "no")
                        "."
                      )
                    )
                  )
                )
              )
            )
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line "Target frame block definitions after cleanup:")
          (swcad-title-print-frame-def-check-lines)
          (swcad-title-princ-line
            (strcat
              "Summary: cleaned="
              (itoa cleaned)
              ", skipped-clean="
              (itoa skipped)
              ", skipped-missing="
              (itoa skipped-missing)
              ", skipped-referenced="
              (itoa skipped-referenced)
              ", failed="
              (itoa failed)
            )
          )
          (swcad-title-princ-line
            (strcat
              "Result: "
              (cond
                ((> failed 0) "WARN_FRAME_DEF_CLEAN_PARTIAL_FAILURE")
                ((> skipped-referenced 0) "SKIP_REFERENCED_CONTAMINATED_FRAME_DEFS")
                ((> cleaned 0) "CLEANED_UNUSED_CONTAMINATED_FRAME_DEFS")
                (any-contaminated "WARN_CONTAMINATED_FRAME_DEFS_NOT_CLEANED")
                (T "OK_FRAME_DEFS_ALREADY_CLEAN")
              )
            )
          )
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-handle-entity-summary (handle / ename data etype name bbox)
  (setq ename (if (> (strlen (swcad-title-string handle)) 0) (handent handle) nil))
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (setq etype (swcad-title-string (swcad-title-dxf-value data 0)))
      (setq name "")
      (if (equal etype "INSERT")
        (setq name (swcad-title-effective-insert-name ename))
      )
      (setq bbox (swcad-title-safe-bbox ename))
      (strcat
        etype
        (if (> (strlen name) 0) (strcat "/" name) "")
        " bbox="
        (swcad-title-bbox-string bbox)
      )
    )
    "<missing>"
  )
)

(defun swcad-title-reference-handle-code-p (code)
  (or
    (= code 390)
    (and (>= code 320) (<= code 369))
    (= code 1005)
  )
)

(defun swcad-title-reference-handle-value-string (value / ename)
  (cond
    ((= (type value) 'ENAME)
      (swcad-title-ename-handle value)
    )
    ((= (type value) 'STR)
      (if (handent value)
        (strcase value)
        value
      )
    )
    (T (swcad-title-string value))
  )
)

(defun swcad-title-print-reference-handle-pairs (data / found pair code value handle)
  (setq found nil)
  (foreach pair data
    (if (and (listp pair) (swcad-title-reference-handle-code-p (car pair)))
      (progn
        (setq code (car pair))
        (setq value (cdr pair))
        (setq handle (swcad-title-reference-handle-value-string value))
        (setq found T)
        (swcad-title-princ-line
          (strcat
            "    ref DXF "
            (itoa code)
            " -> "
            handle
            " / "
            (swcad-title-handle-entity-summary handle)
          )
        )
      )
    )
  )
  (if (not found)
    (swcad-title-princ-line "    ref handles: <none>")
  )
)

(defun swcad-title-print-handle-raw-detail (handle / ename data kind object object-name object-handle object-owner-id)
  (setq ename (if (> (strlen (swcad-title-string handle)) 0) (handent handle) nil))
  (setq kind (swcad-title-native-link-target-kind handle))
  (swcad-title-princ-line
    (strcat
      "  Handle "
      (swcad-title-string handle)
      ": kind="
      kind
      ", summary="
      (swcad-title-handle-entity-summary handle)
    )
  )
  (if ename
    (progn
      (setq object (swcad-title-safe-vla-object ename))
      (setq object-name (swcad-title-safe-vla-get object 'ObjectName))
      (setq object-handle (swcad-title-safe-vla-get object 'Handle))
      (setq object-owner-id (swcad-title-safe-vla-get object 'OwnerID))
      (swcad-title-princ-line
        (strcat
          "  VLA object: "
          (if object
            (strcat
              "ObjectName="
              (swcad-title-string object-name)
              ", Handle="
              (swcad-title-string object-handle)
              ", OwnerID="
              (swcad-title-string object-owner-id)
            )
            "<none>"
          )
        )
      )
      (setq data (entget ename '("*")))
      (if data
        (progn
          (swcad-title-princ-line "  Reference handles:")
          (swcad-title-print-reference-handle-pairs data)
          (swcad-title-princ-line "  Raw entget:")
          (foreach pair data
            (swcad-title-code-value-line "    DXF" pair)
          )
        )
        (progn
          (swcad-title-princ-line "  Reference handles: <none, entget returned nil>")
          (swcad-title-princ-line "  Raw entget: <nil>")
        )
      )
    )
    (swcad-title-princ-line "  Raw entget: <missing>")
  )
)

(defun swcad-title-print-xdata-record-detail (ename / records record pair)
  (setq records (if ename (swcad-title-xdata-records ename) nil))
  (swcad-title-princ-line "  xdata detail:")
  (if records
    (foreach record records
      (progn
        (swcad-title-princ-line
          (strcat
            "    app="
            (swcad-title-xdata-record-app-name record)
          )
        )
        (foreach pair (cdr record)
          (swcad-title-code-value-line "      XD" pair)
        )
      )
    )
    (swcad-title-princ-line "    <none>")
  )
)

(defun swcad-title-print-entity-structure-detail (label ename / data etype handle name layer owner bbox object object-name object-handle object-owner-id apps native-handles native-target-kinds)
  (swcad-title-princ-line (strcat label ":"))
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (setq etype (swcad-title-string (swcad-title-dxf-value data 0)))
      (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
      (setq name "")
      (if (equal etype "INSERT")
        (setq name (swcad-title-effective-insert-name ename))
      )
      (setq layer (swcad-title-string (swcad-title-dxf-value data 8)))
      (setq owner (swcad-title-string (swcad-title-dxf-value data 330)))
      (setq bbox (swcad-title-safe-bbox ename))
      (setq object (swcad-title-safe-vla-object ename))
      (setq object-name (swcad-title-safe-vla-get object 'ObjectName))
      (setq object-handle (swcad-title-safe-vla-get object 'Handle))
      (setq object-owner-id (swcad-title-safe-vla-get object 'OwnerID))
      (setq apps (swcad-title-xdata-app-names ename))
      (setq native-handles (swcad-title-gmtitle-native-xdata-info ename))
      (setq native-target-kinds (swcad-title-native-link-target-kinds ename))
      (swcad-title-princ-line
        (strcat
          "  type="
          etype
          ", name="
          (if (> (strlen name) 0) name "<none>")
          ", handle="
          handle
          ", layer="
          layer
          ", owner="
          owner
        )
      )
      (swcad-title-princ-line (strcat "  bbox=" (swcad-title-bbox-string bbox)))
      (swcad-title-princ-line
        (strcat
          "  VLA object="
          (if object
            (strcat
              (swcad-title-string object-name)
              ", Handle="
              (swcad-title-string object-handle)
              ", OwnerID="
              (swcad-title-string object-owner-id)
            )
            "<none>"
          )
        )
      )
      (swcad-title-princ-line
        (strcat
          "  xdata-apps="
          (swcad-title-list-string apps)
          ", native-handles="
          (swcad-title-list-string native-handles)
          ", native-target-kinds="
          (swcad-title-list-string native-target-kinds)
        )
      )
      (swcad-title-princ-line
        (strcat
          "  persistent-reactors="
          (itoa (swcad-title-dxf-code-count data -5))
          ", extension-dictionaries="
          (itoa (swcad-title-dxf-code-count data 360))
        )
      )
      (swcad-title-princ-line "  reference handles:")
      (swcad-title-print-reference-handle-pairs data)
      (swcad-title-print-xdata-record-detail ename)
    )
    (swcad-title-princ-line "  <missing>")
  )
)

(defun swcad-title-first-title-by-native-kind (kind / title-name titles result title kinds)
  (setq title-name (swcad-title-target-title-block-name))
  (setq titles
    (vl-sort
      (swcad-title-inserts-by-effective-name title-name)
      '(lambda (a b)
        (< (swcad-title-bbox-min-x a) (swcad-title-bbox-min-x b))
      )
    )
  )
  (setq result nil)
  (foreach title titles
    (if (not result)
      (progn
        (setq kinds (swcad-title-native-link-target-kinds title))
        (cond
          ((equal kind "internal")
            (if
              (and
                (or
                  (member "internal" kinds)
                  (member "internal-no-entget" kinds)
                )
                (not (member "visible-target-frame" kinds))
                (not (member "visible-target-title" kinds))
              )
              (setq result title)
            )
          )
          ((equal kind "visible-target-frame")
            (if (member "visible-target-frame" kinds)
              (setq result title)
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-records-right-origin (frame-records fallback-bbox / max-x min-y record bbox)
  (setq max-x nil)
  (setq min-y (if fallback-bbox (cadr fallback-bbox) 0.0))
  (foreach record frame-records
    (setq bbox (cadddr record))
    (if bbox
      (progn
        (if (or (not max-x) (> (caddr bbox) max-x))
          (setq max-x (caddr bbox))
        )
        (if (< (cadr bbox) min-y)
          (setq min-y (cadr bbox))
        )
      )
    )
  )
  (if (not max-x)
    (setq max-x (if fallback-bbox (caddr fallback-bbox) 0.0))
  )
  (list (+ max-x 50.0) min-y)
)

(defun swcad-title-copy-test-target-sheet (raw / value normalized)
  (setq value (strcase (vl-string-trim " \t\r\n" (swcad-title-string raw))))
  (cond
    ((or (= value "") (= value "SAME")) "SAME")
    (T
      (setq normalized (swcad-title-normalized-sheet-size value))
      (if (and normalized (wcmatch normalized "A1,A2,A3,A4"))
        normalized
        nil
      )
    )
  )
)

(defun swcad-title-title-frame-offset (title-bbox frame-bbox)
  (if (and title-bbox frame-bbox)
    (list (- (car title-bbox) (car frame-bbox)) (- (cadr title-bbox) (cadr frame-bbox)))
    '(0.0 0.0)
  )
)

(defun swcad-title-internal-native-link-kinds-p (kinds)
  (and
    (or
      (member "internal" kinds)
      (member "internal-no-entget" kinds)
    )
    (not (member "visible-target-frame" kinds))
    (not (member "visible-target-title" kinds))
  )
)

(defun swcad-title-cloned-native-link-kinds-p (kinds)
  (and
    (or
      (member "internal" kinds)
      (member "internal-no-entget" kinds)
    )
    (not (member "visible-target-frame" kinds))
    (not (member "visible-target-title" kinds))
    (not (member "missing" kinds))
  )
)

(defun swcad-title-native-example-pair (/ frame-records example-title example-title-bbox frame-record example-frame example-frame-block example-frame-bbox)
  (setq frame-records (swcad-title-frame-records))
  (setq example-title (swcad-title-native-example-title))
  (setq example-title-bbox (if example-title (swcad-title-safe-bbox example-title) nil))
  (setq frame-record (if example-title-bbox (swcad-title-nearest-frame-record example-title-bbox frame-records) nil))
  (setq example-frame (if frame-record (car frame-record) nil))
  (setq example-frame-block (if frame-record (cadr frame-record) nil))
  (setq example-frame-bbox (if frame-record (cadddr frame-record) nil))
  (if
    (and
      example-title
      example-title-bbox
      example-frame
      example-frame-bbox
      example-frame-block
    )
    (list example-title example-frame example-frame-block example-title-bbox example-frame-bbox)
    nil
  )
)

(defun swcad-title-native-example-pair-for-frame-block (target-frame-block / frame-records titles title result title-bbox frame-record example-frame example-frame-block example-frame-bbox target title-role frame-role)
  (setq target (strcase (swcad-title-string target-frame-block)))
  (setq frame-records (swcad-title-frame-records))
  (setq titles
    (vl-sort
      (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name))
      '(lambda (a b)
        (< (swcad-title-bbox-min-x a) (swcad-title-bbox-min-x b))
      )
    )
  )
  (setq result nil)
  (foreach title titles
    (if
      (and
        (not result)
        (swcad-title-usable-native-example-title-p title)
        (swcad-title-exemplar-safe-native-source-role-p (swcad-title-exemplar-role title))
      )
      (progn
        (setq title-bbox (swcad-title-safe-bbox title))
        (setq frame-record (if title-bbox (swcad-title-nearest-frame-record-for-block title-bbox frame-records target-frame-block) nil))
        (setq example-frame (if frame-record (car frame-record) nil))
        (setq example-frame-block (if frame-record (cadr frame-record) nil))
        (setq example-frame-bbox (if frame-record (cadddr frame-record) nil))
        (setq title-role (swcad-title-exemplar-role title))
        (setq frame-role (if example-frame (swcad-title-exemplar-role example-frame) ""))
        (if
          (and
            example-frame
            example-frame-bbox
            (equal (strcase (swcad-title-string example-frame-block)) target)
            (swcad-title-frame-bbox-size-valid-p example-frame-block example-frame-bbox)
            (swcad-title-exemplar-safe-native-source-role-p title-role)
            (swcad-title-exemplar-safe-native-source-role-p frame-role)
            (swcad-title-trusted-native-exemplar-pair-p title example-frame target-frame-block)
          )
          (setq result (list title example-frame example-frame-block title-bbox example-frame-bbox))
        )
      )
    )
  )
  result
)

(defun swcad-title-untrusted-native-candidate-count-for-frame-block (target-frame-block / frame-records titles title count title-bbox frame-record example-frame example-frame-block target)
  (setq target (strcase (swcad-title-string target-frame-block)))
  (setq frame-records (swcad-title-frame-records))
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq count 0)
  (foreach title titles
    (if (swcad-title-usable-native-example-title-p title)
      (progn
        (setq title-bbox (swcad-title-safe-bbox title))
        (setq frame-record (if title-bbox (swcad-title-nearest-frame-record-for-block title-bbox frame-records target-frame-block) nil))
        (setq example-frame (if frame-record (car frame-record) nil))
        (setq example-frame-block (if frame-record (cadr frame-record) nil))
        (if
          (and
            example-frame
            example-frame-block
            (equal (strcase (swcad-title-string example-frame-block)) target)
            (not (swcad-title-trusted-native-exemplar-pair-p title example-frame target-frame-block))
          )
          (setq count (+ count 1))
        )
      )
    )
  )
  count
)

(defun swcad-title-invalid-native-candidate-count-for-frame-block (target-frame-block / frame-records titles title count title-bbox frame-record example-frame example-frame-block example-frame-bbox target)
  (setq target (strcase (swcad-title-string target-frame-block)))
  (setq frame-records (swcad-title-frame-records))
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq count 0)
  (foreach title titles
    (if (swcad-title-usable-native-example-title-p title)
      (progn
        (setq title-bbox (swcad-title-safe-bbox title))
        (setq frame-record (if title-bbox (swcad-title-nearest-frame-record-for-block title-bbox frame-records target-frame-block) nil))
        (setq example-frame (if frame-record (car frame-record) nil))
        (setq example-frame-block (if frame-record (cadr frame-record) nil))
        (setq example-frame-bbox (if frame-record (cadddr frame-record) nil))
        (if
          (and
            example-frame
            example-frame-block
            (equal (strcase (swcad-title-string example-frame-block)) target)
            (swcad-title-frame-bbox-size-warning-for-block example-frame-block example-frame-bbox)
          )
          (setq count (+ count 1))
        )
      )
    )
  )
  count
)

(defun swcad-title-native-example-for-frame-description (frame-block / pair untrusted-count invalid-count)
  (setq pair (swcad-title-native-example-pair-for-frame-block frame-block))
  (if pair
    (strcat
      "yes, title="
      (swcad-title-ename-handle (car pair))
      ", frame="
      (swcad-title-ename-handle (cadr pair))
    )
    (progn
      (setq untrusted-count (swcad-title-untrusted-native-candidate-count-for-frame-block frame-block))
      (setq invalid-count (swcad-title-invalid-native-candidate-count-for-frame-block frame-block))
      (cond
        ((> invalid-count 0)
          (strcat "no valid exemplar, invalid-geometry-candidates=" (itoa invalid-count))
        )
        ((> untrusted-count 0)
          (strcat "no trusted marker, unmarked-candidates=" (itoa untrusted-count))
        )
        (T "no")
      )
    )
  )
)

(defun swcad-title-print-native-exemplars-by-frame (/ frame-block)
  (swcad-title-princ-line "Native GMTITLE exemplars by sheet frame:")
  (foreach frame-block (swcad-title-target-frame-block-candidates)
    (swcad-title-princ-line
      (strcat
        "  "
        frame-block
        ": "
        (swcad-title-native-example-for-frame-description frame-block)
      )
    )
  )
)

(defun swcad-title-delete-cloned-gmtitle-pair (title-ename frame-ename)
  (swcad-title-delete-ename title-ename)
  (swcad-title-delete-ename frame-ename)
)

(defun swcad-title-clone-native-gmtitle-pair-preserve-links (target-frame-block title-offset values / pair example-title example-frame example-frame-block example-title-bbox example-frame-bbox copied-frame copied-title copied-frame-bbox copied-title-bbox fallback-offset copied-kinds attr-count)
  (setq *swcad-title-last-clone-failure* nil)
  (setq pair (swcad-title-native-example-pair-for-frame-block target-frame-block))
  (if (not pair)
    (setq *swcad-title-last-clone-failure*
      (strcat
        "NO_SAME_SIZE_NATIVE_GMTITLE_EXEMPLAR_FOR_"
        (swcad-title-string target-frame-block)
      )
    )
  )
  (if (and pair target-frame-block)
    (progn
      (setq example-title (car pair))
      (setq example-frame (cadr pair))
      (setq example-frame-block (caddr pair))
      (setq example-title-bbox (cadddr pair))
      (setq example-frame-bbox (nth 4 pair))
      (setq copied-frame (swcad-title-copy-ename example-frame))
      (setq copied-title (if copied-frame (swcad-title-copy-ename example-title) nil))
      (if
        (and
          copied-frame
          copied-title
          (not (equal (strcase target-frame-block) (strcase example-frame-block)))
          (not (swcad-title-change-insert-block-name copied-frame target-frame-block))
        )
        (progn
          (setq *swcad-title-last-clone-failure*
            (strcat
              "FAILED_TO_CHANGE_FRAME_BLOCK_FROM_"
              (swcad-title-string example-frame-block)
              "_TO_"
              (swcad-title-string target-frame-block)
            )
          )
          (swcad-title-delete-cloned-gmtitle-pair copied-title copied-frame)
          (setq copied-title nil)
          (setq copied-frame nil)
        )
      )
      (if (and copied-frame copied-title)
        (progn
          (swcad-title-move-ename-bbox-min-to copied-frame 0.0 0.0)
          (setq copied-frame-bbox (swcad-title-safe-bbox copied-frame))
          (setq fallback-offset (swcad-title-title-frame-offset example-title-bbox example-frame-bbox))
          (if (not title-offset)
            (setq title-offset fallback-offset)
          )
          (if copied-frame-bbox
            (swcad-title-move-ename-bbox-min-to
              copied-title
              (+ (car copied-frame-bbox) (car title-offset))
              (+ (cadr copied-frame-bbox) (cadr title-offset))
            )
          )
          (setq attr-count
            (swcad-title-set-insert-attributes
              (swcad-title-safe-vla-object copied-title)
              values
            )
          )
          (swcad-title-mark-native-exemplar-pair
            copied-title
            copied-frame
            target-frame-block
            "clone"
          )
          (setq copied-title-bbox (swcad-title-safe-bbox copied-title))
          (setq copied-kinds (swcad-title-native-link-target-kinds copied-title))
          (if (swcad-title-cloned-native-link-kinds-p copied-kinds)
            (list
              copied-title
              copied-frame
              target-frame-block
              values
              attr-count
              copied-kinds
              copied-title-bbox
              copied-frame-bbox
            )
            (progn
              (setq *swcad-title-last-clone-failure*
                (strcat
                  "CLONED_NATIVE_LINK_KIND_REJECTED_"
                  (swcad-title-list-string copied-kinds)
                )
              )
              (swcad-title-delete-cloned-gmtitle-pair copied-title copied-frame)
              nil
            )
          )
        )
        (progn
          (if (not *swcad-title-last-clone-failure*)
            (setq *swcad-title-last-clone-failure* "FAILED_TO_COPY_NATIVE_GMTITLE_PAIR")
          )
          nil
        )
      )
    )
    nil
  )
)

(defun swcad-title-gmtitle-preserve-copy-test (/ frame-records example-title example-title-bbox example-frame-record example-frame example-frame-block example-frame-bbox raw target-sheet target-frame-block block-change-needed target-contaminated answer doc copied-frame copied-title origin title-offset copied-frame-bbox copied-title-bbox copied-kinds attr-count status)
  (swcad-title-open-gmtitle-preserve-copy-test-log)
  (setq frame-records (swcad-title-frame-records))
  (setq example-title (swcad-title-first-title-by-native-kind "internal"))
  (setq example-title-bbox (if example-title (swcad-title-safe-bbox example-title) nil))
  (setq example-frame-record (if example-title-bbox (swcad-title-nearest-frame-record example-title-bbox frame-records) nil))
  (setq example-frame (if example-frame-record (car example-frame-record) nil))
  (setq example-frame-block (if example-frame-record (cadr example-frame-record) nil))
  (setq example-frame-bbox (if example-frame-record (cadddr example-frame-record) nil))
  (swcad-title-princ-line "----- SWTITLEVERIFY 내부 preserve-copy native 쌍 복사 실험 -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Native exemplar title: "
      (if example-title
        (strcat
          (swcad-title-ename-handle example-title)
          ", link-kinds="
          (swcad-title-list-string (swcad-title-native-link-target-kinds example-title))
        )
        "<none>"
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Nearest native exemplar frame: "
      (if example-frame
        (strcat
          example-frame-block
          "/"
          (swcad-title-ename-handle example-frame)
          ", link-kinds="
          (swcad-title-list-string (swcad-title-native-link-target-kinds example-frame))
        )
        "<none>"
      )
    )
  )
  (cond
    ((swcad-title-document-read-only-p)
      (setq status "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Result: ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before running the preserve-copy test.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (setq status "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Result: ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "This experiment is limited to Documents/CAD tool/work copies.")
    )
    ((not example-title)
      (setq status "ABORT_NO_INTERNAL_NATIVE_TITLE")
      (swcad-title-princ-line "Result: ABORT_NO_INTERNAL_NATIVE_TITLE")
    )
    ((not example-frame)
      (setq status "ABORT_NO_NEAREST_NATIVE_FRAME")
      (swcad-title-princ-line "Result: ABORT_NO_NEAREST_NATIVE_FRAME")
    )
    (T
      (setq raw (getstring T "\nTarget sheet for copy test [SAME/A1/A2/A3/A4] <SAME>: "))
      (setq target-sheet (swcad-title-copy-test-target-sheet raw))
      (if (not target-sheet)
        (progn
          (setq status "ABORT_INVALID_TARGET_SHEET")
          (swcad-title-princ-line "Result: ABORT_INVALID_TARGET_SHEET")
          (swcad-title-princ-line "Use SAME, A1, A2, A3, or A4.")
        )
        (progn
          (setq target-frame-block
            (if (equal target-sheet "SAME")
              example-frame-block
              (swcad-title-target-frame-block-name-for-sheet target-sheet)
            )
          )
          (setq block-change-needed (not (equal (strcase target-frame-block) (strcase example-frame-block))))
          (setq target-contaminated
            (and
              block-change-needed
              (swcad-title-block-exists-p target-frame-block)
              (swcad-title-target-frame-block-contaminated-p target-frame-block)
            )
          )
          (swcad-title-princ-line (strcat "Requested target sheet: " target-sheet))
          (swcad-title-princ-line (strcat "Target frame block: " target-frame-block))
          (if target-contaminated
            (swcad-title-princ-line "Warning: target frame definition is flagged contaminated; continuing because this is an explicit preserve-copy recognition experiment.")
          )
          (cond
            (T
              (setq answer
                (getstring
                  T
                  "\nnative GMTITLE 쌍 1개를 인식 테스트용으로 복사하려면 YES를 입력하세요. 기존 내용은 삭제하지 않습니다: "
                )
              )
              (if (not (equal (strcase answer) "YES"))
                (progn
                  (setq status "ABORT_USER_CANCEL")
                  (swcad-title-princ-line "Result: ABORT_USER_CANCEL")
                  (swcad-title-princ-line "No drawing data was changed.")
                )
                (progn
                  (setq doc (swcad-title-doc))
                  (vl-catch-all-apply 'vla-StartUndoMark (list doc))
                  (setq copied-frame (swcad-title-copy-ename example-frame))
                  (setq copied-title (if copied-frame (swcad-title-copy-ename example-title) nil))
                  (if (and copied-frame copied-title block-change-needed)
                    (if (not (swcad-title-change-insert-block-name copied-frame target-frame-block))
                      (progn
                        (swcad-title-delete-ename copied-title)
                        (swcad-title-delete-ename copied-frame)
                        (setq copied-title nil)
                        (setq copied-frame nil)
                      )
                    )
                  )
                  (if (and copied-frame copied-title)
                    (progn
                      (setq origin (swcad-title-frame-records-right-origin frame-records example-frame-bbox))
                      (swcad-title-move-ename-bbox-min-to copied-frame (car origin) (cadr origin))
                      (setq copied-frame-bbox (swcad-title-safe-bbox copied-frame))
                      (setq title-offset
                        (if (equal target-sheet "SAME")
                          (swcad-title-title-frame-offset example-title-bbox example-frame-bbox)
                          (swcad-title-frame-only-title-offset target-sheet)
                        )
                      )
                      (if (not title-offset)
                        (setq title-offset (swcad-title-title-frame-offset example-title-bbox example-frame-bbox))
                      )
                      (if copied-frame-bbox
                        (swcad-title-move-ename-bbox-min-to
                          copied-title
                          (+ (car copied-frame-bbox) (car title-offset))
                          (+ (cadr copied-frame-bbox) (cadr title-offset))
                        )
                      )
                      (setq attr-count
                        (swcad-title-set-insert-attributes
                          (swcad-title-safe-vla-object copied-title)
                          (list
                            (cons "GEN-TITLE-SIZ{6.7}" (if (equal target-sheet "SAME") (swcad-title-sheet-size-from-block-name target-frame-block) target-sheet))
                            (cons "GEN-TITLE-DWG{23}" "PRESERVE_COPY_TEST")
                            (cons "GEN-TITLE-NR{23}" "PRESERVE_COPY_TEST")
                          )
                        )
                      )
                      (setq copied-title-bbox (swcad-title-safe-bbox copied-title))
                      (setq copied-kinds (swcad-title-native-link-target-kinds copied-title))
                      (swcad-title-princ-line
                        (strcat
                          "Copied frame: "
                          target-frame-block
                          "/"
                          (swcad-title-ename-handle copied-frame)
                          ", bbox="
                          (swcad-title-bbox-string copied-frame-bbox)
                        )
                      )
                      (swcad-title-princ-line
                        (strcat
                          "Copied title: "
                          (swcad-title-ename-handle copied-title)
                          ", bbox="
                          (swcad-title-bbox-string copied-title-bbox)
                          ", attr-set="
                          (itoa attr-count)
                          ", link-kinds="
                          (swcad-title-list-string copied-kinds)
                        )
                      )
                      (swcad-title-print-gmtitle-compare-case "Copied preserve-link title detail" copied-title (swcad-title-frame-records))
                      (setq status
                        (if (swcad-title-cloned-native-link-kinds-p copied-kinds)
                          "OK_PRESERVE_COPY_NATIVE_LINK"
                          "WARN_PRESERVE_COPY_LINK_NOT_USABLE"
                        )
                      )
                      (swcad-title-princ-line (strcat "Result: " status))
                      (swcad-title-princ-line "Old SOLIDWORKS title/frame content was not removed.")
                    )
                    (progn
                      (setq status "ABORT_COPY_NATIVE_PAIR_FAILED")
                      (swcad-title-princ-line "Result: ABORT_COPY_NATIVE_PAIR_FAILED")
                    )
                  )
                  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                )
              )
            )
          )
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-print-gmtitle-compare-case (label title frame-records / title-data title-object attr-pairs title-bbox native-handles native-target-kinds nearest nearest-ename nearest-handle linked-handle linked-ename handle-matches-nearest)
  (swcad-title-princ-line "")
  (swcad-title-princ-line label)
  (if title
    (progn
      (setq title-data (entget title '("*")))
      (setq title-object (swcad-title-safe-vla-object title))
      (setq attr-pairs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
      (setq title-bbox (swcad-title-safe-bbox title))
      (setq native-handles (swcad-title-gmtitle-native-xdata-info title))
      (setq native-target-kinds (swcad-title-native-link-target-kinds title))
      (setq nearest (swcad-title-nearest-frame-record title-bbox frame-records))
      (setq nearest-ename (if nearest (car nearest) nil))
      (setq nearest-handle (if nearest (caddr nearest) ""))
      (setq linked-handle (if native-handles (car native-handles) ""))
      (setq linked-ename (if (> (strlen linked-handle) 0) (handent linked-handle) nil))
      (setq handle-matches-nearest
        (and
          (> (strlen linked-handle) 0)
          (> (strlen nearest-handle) 0)
          (equal (strcase linked-handle) (strcase nearest-handle))
        )
      )
      (swcad-title-princ-line
        (strcat
          "  sheet="
          (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-SIZ{6.7}")
          ", DWG=\""
          (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-DWG{23}")
          "\", NR=\""
          (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-NR{23}")
          "\", native-target-kinds="
          (swcad-title-list-string native-target-kinds)
        )
      )
      (swcad-title-princ-line
        (strcat
          "  nearest-frame="
          (if nearest (cadr nearest) "<none>")
          "/"
          nearest-handle
          ", linked-handle="
          (if (> (strlen linked-handle) 0) linked-handle "<none>")
          ", link-matches-nearest="
          (if handle-matches-nearest "yes" "no")
        )
      )
      (swcad-title-print-entity-structure-detail "  title insert" title)
      (swcad-title-print-entity-structure-detail "  nearest frame insert" nearest-ename)
      (swcad-title-princ-line "  native linked target detail:")
      (if native-handles
        (foreach linked-handle native-handles
          (swcad-title-print-handle-raw-detail linked-handle)
        )
        (swcad-title-princ-line "    <none>")
      )
      (if
        (and
          linked-ename
          (not (equal linked-ename nearest-ename))
        )
        (swcad-title-print-entity-structure-detail "  linked visible/internal ename structure" linked-ename)
      )
    )
    (swcad-title-princ-line "  <missing>")
  )
)

(defun swcad-title-gmtitle-compare (/ frame-records native-title visible-title status)
  (swcad-title-open-gmtitle-compare-log)
  (setq frame-records (swcad-title-frame-records))
  (setq native-title (swcad-title-first-title-by-native-kind "internal"))
  (setq visible-title (swcad-title-first-title-by-native-kind "visible-target-frame"))
  (swcad-title-princ-line "----- SWTITLEVERIFY 내부 native/clone 비교(읽기 전용) -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Target frame inserts: " (itoa (length frame-records))))
  (swcad-title-princ-line
    (strcat
      "Internal/native title exemplar: "
      (if native-title
        (swcad-title-ename-handle native-title)
        "<none>"
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Visible-frame-linked clone exemplar: "
      (if visible-title
        (swcad-title-ename-handle visible-title)
        "<none>"
      )
    )
  )
  (swcad-title-print-gmtitle-compare-case "Case A: internal/native GMTITLE title" native-title frame-records)
  (swcad-title-print-gmtitle-compare-case "Case B: visible-frame-linked cloned GMTITLE title" visible-title frame-records)
  (setq status
    (cond
      ((and native-title visible-title) "OK_COMPARE_INTERNAL_AND_VISIBLE_FRAME_LINK")
      ((not native-title) "WARN_NO_INTERNAL_NATIVE_TITLE_TO_COMPARE")
      ((not visible-title) "WARN_NO_VISIBLE_FRAME_LINKED_CLONE_TO_COMPARE")
      (T "WARN_COMPARE_INPUTS_MISSING")
    )
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-gmtitle-link-detail (/ title-name titles title-index title title-data title-object title-bbox attr-pairs native-handles native-target-kinds nearest nearest-handle title-handle handle)
  (swcad-title-open-gmtitle-link-detail-log)
  (setq title-name (swcad-title-target-title-block-name))
  (setq titles
    (vl-sort
      (swcad-title-inserts-by-effective-name title-name)
      '(lambda (a b)
        (< (swcad-title-bbox-min-x a) (swcad-title-bbox-min-x b))
      )
    )
  )
  (swcad-title-princ-line "----- SWTITLEVERIFY 내부 native-link 원시 상세(읽기 전용) -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Target title inserts: " (itoa (length titles))))
  (setq title-index 1)
  (foreach title titles
    (setq title-data (entget title '("*")))
    (setq title-object (swcad-title-safe-vla-object title))
    (setq title-bbox (swcad-title-safe-bbox title))
    (setq attr-pairs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
    (setq native-handles (swcad-title-gmtitle-native-xdata-info title))
    (setq native-target-kinds (swcad-title-native-link-target-kinds title))
    (setq nearest (swcad-title-nearest-frame-record title-bbox (swcad-title-frame-records)))
    (setq nearest-handle (if nearest (caddr nearest) ""))
    (setq title-handle (swcad-title-string (swcad-title-dxf-value title-data 5)))
    (swcad-title-princ-line
      (strcat
        "Title #"
        (itoa title-index)
        ": handle="
        title-handle
        ", sheet="
        (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-SIZ{6.7}")
        ", native-target-kinds="
        (swcad-title-list-string native-target-kinds)
        ", nearest-frame="
        (if nearest (cadr nearest) "<none>")
        "/"
        nearest-handle
      )
    )
    (foreach handle native-handles
      (swcad-title-print-handle-raw-detail handle)
    )
    (if (not native-handles)
      (swcad-title-princ-line "  Native handles: <none>")
    )
    (setq title-index (+ title-index 1))
  )
  (swcad-title-princ-line "Result: OK_LINK_DETAIL_DUMPED")
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-gmtitle-link-scan (/ title-name titles title-index title title-data title-object title-bbox attr-pairs missing-tags native-handles native-target-kinds apps frame-records nearest nearest-handle linked-handle linked-frame-ename linked-frame-data linked-frame-apps linked-frame-native-handles frame-link-counts duplicate-link-found visible-frame-link-found visible-frame-link-count contaminated-frame-found title-handle handle-matches-nearest old-child-names frame-name children item)
  (swcad-title-open-gmtitle-link-scan-log)
  (setq title-name (swcad-title-target-title-block-name))
  (setq titles
    (vl-sort
      (swcad-title-inserts-by-effective-name title-name)
      '(lambda (a b)
        (< (swcad-title-bbox-min-x a) (swcad-title-bbox-min-x b))
      )
    )
  )
  (setq frame-records (swcad-title-frame-records))
  (setq frame-link-counts nil)
  (setq duplicate-link-found nil)
  (setq visible-frame-link-found nil)
  (setq visible-frame-link-count 0)
  (setq contaminated-frame-found nil)
  (swcad-title-princ-line "----- SWTITLEVERIFY 내부 GMTITLE link 스캔(읽기 전용) -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Target title inserts: " (itoa (length titles))))
  (swcad-title-princ-line (strcat "Target frame inserts: " (itoa (length frame-records))))
  (setq title-index 1)
  (foreach title titles
    (setq title-data (entget title '("*")))
    (setq title-object (swcad-title-safe-vla-object title))
    (setq title-bbox (swcad-title-safe-bbox title))
    (setq attr-pairs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
    (setq missing-tags (swcad-title-missing-template-tags attr-pairs))
    (setq native-handles (swcad-title-gmtitle-native-xdata-info title))
    (setq native-target-kinds (swcad-title-native-link-target-kinds title))
    (setq apps (swcad-title-xdata-app-names title))
    (setq nearest (swcad-title-nearest-frame-record title-bbox frame-records))
    (setq nearest-handle (if nearest (caddr nearest) ""))
    (setq linked-handle (if native-handles (car native-handles) ""))
    (setq linked-frame-ename (if (> (strlen linked-handle) 0) (handent linked-handle) nil))
    (setq linked-frame-data (if linked-frame-ename (entget linked-frame-ename '("*")) nil))
    (setq linked-frame-apps (if linked-frame-ename (swcad-title-xdata-app-names linked-frame-ename) nil))
    (setq linked-frame-native-handles
      (if linked-frame-ename (swcad-title-gmtitle-native-xdata-info linked-frame-ename) nil)
    )
    (setq handle-matches-nearest (and (> (strlen linked-handle) 0) (equal (strcase linked-handle) (strcase nearest-handle))))
    (if (member "visible-target-frame" native-target-kinds)
      (progn
        (setq visible-frame-link-found T)
        (setq visible-frame-link-count (+ visible-frame-link-count 1))
      )
    )
    (if (> (strlen linked-handle) 0)
      (setq frame-link-counts (swcad-title-count-frame-link linked-handle frame-link-counts))
    )
    (setq title-handle (swcad-title-string (swcad-title-dxf-value title-data 5)))
    (swcad-title-princ-line
      (strcat
        "Title #"
        (itoa title-index)
        ": handle="
        title-handle
        ", sheet="
        (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-SIZ{6.7}")
        ", DWG=\""
        (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-DWG{23}")
        "\", NR=\""
        (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-NR{23}")
        "\", attrs="
        (itoa (length attr-pairs))
        ", missing-tags="
        (itoa (length missing-tags))
        ", owner="
        (swcad-title-string (swcad-title-dxf-value title-data 330))
      )
    )
    (swcad-title-princ-line
      (strcat
        "  bbox="
        (swcad-title-bbox-string title-bbox)
        ", xdata-apps="
        (swcad-title-list-string apps)
      )
    )
    (swcad-title-princ-line
      (strcat
        "  native-handles="
        (swcad-title-list-string native-handles)
        ", native-target-kinds="
        (swcad-title-list-string native-target-kinds)
        ", linked-entity="
        (swcad-title-handle-entity-summary linked-handle)
        ", nearest-frame="
        (if nearest (cadr nearest) "<none>")
        "/"
        nearest-handle
        ", link-matches-nearest="
        (if handle-matches-nearest "yes" "no")
      )
    )
    (swcad-title-princ-line
      (strcat
        "  persistent-reactors="
        (itoa (swcad-title-dxf-code-count title-data -5))
        ", extension-dictionaries="
        (itoa (swcad-title-dxf-code-count title-data 360))
      )
    )
    (if linked-frame-ename
      (swcad-title-princ-line
        (strcat
          "  linked-frame-structure: owner="
          (swcad-title-string (swcad-title-dxf-value linked-frame-data 330))
          ", xdata-apps="
          (swcad-title-list-string linked-frame-apps)
          ", native-handles="
          (swcad-title-list-string linked-frame-native-handles)
          ", persistent-reactors="
          (itoa (swcad-title-dxf-code-count linked-frame-data -5))
          ", extension-dictionaries="
          (itoa (swcad-title-dxf-code-count linked-frame-data 360))
        )
      )
      (swcad-title-princ-line "  linked-frame-structure: <missing>")
    )
    (setq title-index (+ title-index 1))
  )
  (swcad-title-princ-line "Frame link handle usage:")
  (if frame-link-counts
    (foreach pair frame-link-counts
      (if (> (cdr pair) 1)
        (setq duplicate-link-found T)
      )
      (swcad-title-princ-line (strcat "  " (car pair) " x " (itoa (cdr pair))))
    )
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-princ-line
    (strcat
      "Titles whose native link points to a visible target frame: "
      (itoa visible-frame-link-count)
    )
  )
  (swcad-title-princ-line "Target frame block definition child INSERT names:")
  (foreach frame-name (swcad-title-target-frame-block-candidates)
    (setq children (swcad-title-block-child-insert-names frame-name))
    (setq old-child-names (swcad-title-target-frame-block-source-like-children frame-name))
    (if old-child-names
      (setq contaminated-frame-found T)
    )
    (swcad-title-princ-line
      (strcat
        "  "
        frame-name
        ": children="
        (swcad-title-list-string children)
        ", old-source-like="
        (swcad-title-list-string old-child-names)
        ", status="
        (if old-child-names "CONTAMINATED" "OK")
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Result: "
      (cond
        (duplicate-link-found "WARN_DUPLICATE_NATIVE_FRAME_LINKS")
        (visible-frame-link-found "WARN_NATIVE_LINKS_POINT_TO_VISIBLE_FRAMES")
        (contaminated-frame-found "WARN_TARGET_FRAME_BLOCK_DEFINITION_CONTAMINATED")
        ((not frame-link-counts) "WARN_NO_NATIVE_FRAME_LINKS")
        (T "OK_LINK_SCAN_NO_DUPLICATE_FRAME_LINKS")
      )
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-gmtitle-verify (/ frame-name title-name frame-count title-enames title-count title-index title-ename title-data title-object title-bbox attr-pairs missing-tags nonempty-attrs native-handles native-target-kinds other-title-inserts filedia cmddia status record any-missing-tags any-empty-attrs any-missing-native-xdata any-visible-frame-native-link)
  (swcad-title-open-gmtitle-verify-log)
  (setq frame-name (swcad-title-existing-target-frame-block-name))
  (if (not frame-name)
    (setq frame-name (swcad-title-target-frame-block-name))
  )
  (if (/= (type frame-name) 'STR)
    (setq frame-name (swcad-title-target-frame-block-name))
  )
  (setq title-name (swcad-title-target-title-block-name))
  (setq frame-count (swcad-title-count-inserts-by-effective-name frame-name))
  (setq title-enames (swcad-title-inserts-by-effective-name title-name))
  (setq title-count (length title-enames))
  (setq other-title-inserts (swcad-title-other-title-like-inserts title-name))
  (setq filedia (getvar "FILEDIA"))
  (setq cmddia (getvar "CMDDIA"))
  (setq any-missing-tags nil)
  (setq any-empty-attrs nil)
  (setq any-missing-native-xdata nil)
  (setq any-visible-frame-native-link nil)
  (swcad-title-princ-line "----- SWTITLEVERIFY 내부 GMTITLE 변환 검증(읽기 전용) -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "FILEDIA: " (swcad-title-string filedia) " (not changed)"))
  (swcad-title-princ-line (strcat "CMDDIA: " (swcad-title-string cmddia) " (not changed)"))
  (swcad-title-princ-line (strcat "Target frame block: " frame-name ", inserts=" (itoa frame-count)))
  (swcad-title-princ-line (strcat "Target title block: " title-name ", inserts=" (itoa title-count)))
  (if title-enames
    (progn
      (setq title-index 1)
      (foreach title-ename title-enames
        (setq title-data (entget title-ename '("*")))
        (setq title-object (swcad-title-safe-vla-object title-ename))
        (setq title-bbox (swcad-title-safe-bbox title-ename))
        (setq attr-pairs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
        (setq missing-tags (swcad-title-missing-template-tags attr-pairs))
        (setq nonempty-attrs (swcad-title-nonempty-attribute-count attr-pairs))
        (setq native-handles (swcad-title-gmtitle-native-xdata-info title-ename))
        (setq native-target-kinds (swcad-title-native-link-target-kinds title-ename))
        (setq title-xdata-apps (swcad-title-xdata-app-names title-ename))
        (setq nearest-frame-record (if title-bbox (swcad-title-nearest-frame-record title-bbox frame-records) nil))
        (setq nearest-frame-ename (if nearest-frame-record (car nearest-frame-record) nil))
        (setq nearest-frame-block (if nearest-frame-record (cadr nearest-frame-record) ""))
        (setq nearest-frame-handle (if nearest-frame-record (caddr nearest-frame-record) ""))
        (setq nearest-frame-bbox (if nearest-frame-record (cadddr nearest-frame-record) nil))
        (setq nearest-frame-native-handles
          (if nearest-frame-ename (swcad-title-gmtitle-native-xdata-info nearest-frame-ename) nil)
        )
        (setq nearest-frame-xdata-apps
          (if nearest-frame-ename (swcad-title-xdata-app-names nearest-frame-ename) nil)
        )
        (setq title-sheet-value (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-SIZ{6.7}"))
        (setq title-sheet-normalized (swcad-title-normalized-sheet-size title-sheet-value))
        (setq frame-sheet-normalized
          (if (> (strlen nearest-frame-block) 0)
            (swcad-title-sheet-size-from-block-name nearest-frame-block)
            nil
          )
        )
        (setq title-trusted-exemplar
          (if (> (strlen nearest-frame-block) 0)
            (swcad-title-trusted-native-exemplar-title-p title-ename nearest-frame-block)
            nil
          )
        )
        (setq frame-trusted-exemplar
          (if nearest-frame-ename
            (swcad-title-trusted-native-exemplar-frame-p nearest-frame-ename nearest-frame-block)
            nil
          )
        )
        (setq pair-trusted-exemplar
          (and title-trusted-exemplar frame-trusted-exemplar)
        )
        (if missing-tags
          (setq any-missing-tags T)
        )
        (if (= nonempty-attrs 0)
          (setq any-empty-attrs T)
        )
        (if (not native-handles)
          (setq any-missing-native-xdata T)
        )
        (if (member "visible-target-frame" native-target-kinds)
          (setq any-visible-frame-native-link T)
        )
        (swcad-title-princ-line
          (strcat
            "Title insert #"
            (itoa title-index)
            ": handle="
            (swcad-title-string (swcad-title-dxf-value title-data 5))
            ", bbox="
            (swcad-title-bbox-string title-bbox)
          )
        )
        (swcad-title-princ-line (strcat "Title attributes: " (itoa (length attr-pairs))))
        (swcad-title-print-attribute-pairs attr-pairs)
        (swcad-title-princ-line (strcat "Non-empty title attributes: " (itoa nonempty-attrs)))
        (swcad-title-print-string-list "Missing expected title tags:" missing-tags)
        (swcad-title-print-string-list "Native GMTITLE GENIUS_GENOREF_13 handle links:" native-handles)
        (swcad-title-print-string-list "Native GMTITLE link target kinds:" native-target-kinds)
        (setq title-index (+ title-index 1))
      )
    )
    (swcad-title-princ-line "Title inserts: <missing>")
  )
  (swcad-title-princ-line "Other title-like inserts that are not the target GMTITLE block:")
  (if other-title-inserts
    (foreach record other-title-inserts
      (swcad-title-princ-line
        (strcat
          "  - handle="
          (car record)
          ", block="
          (cadr record)
          ", bbox="
          (swcad-title-bbox-string (caddr record))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
  (setq status
    (cond
      ((or (/= filedia 1) (/= cmddia 1)) "WARN_FILEDIA_OR_CMDDIA_NOT_1")
      ((= frame-count 0) "FAIL_MISSING_TARGET_FRAME")
      ((= title-count 0) "FAIL_MISSING_TARGET_TITLE")
      (any-missing-tags "FAIL_MISSING_EXPECTED_ATTRIBUTES")
      (any-empty-attrs "WARN_TITLE_ATTRIBUTES_EMPTY")
      (any-missing-native-xdata "WARN_NATIVE_GMTITLE_XDATA_NOT_FOUND")
      (any-visible-frame-native-link "WARN_NATIVE_LINKS_POINT_TO_VISIBLE_FRAMES")
      (other-title-inserts "WARN_OTHER_TITLE_LIKE_INSERTS_REMAIN")
      (T "OK_VERIFY_GMTITLE_READY_FOR_MANUAL_DOUBLE_CLICK_CHECK")
    )
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (swcad-title-princ-line "최종 수동 확인 필요: 제목블록을 더블클릭해서 GMTITLE 표 편집창이 열리는지 확인하세요.")
  (swcad-title-princ-line "Note: native GMTITLE sheet frames remain DR_A*_Outline INSERT/block references; the GMTITLE table editor is checked on the title block.")
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-gmtitle-verify-all (/ title-name title-enames title-count title-index title-ename title-data title-object title-bbox attr-pairs missing-tags nonempty-attrs native-handles native-target-kinds source-titles source-frames other-title-inserts contaminated filedia cmddia status frame-name frame-count total-frame-count any-missing-tags any-empty-attrs any-missing-native-xdata any-visible-frame-native-link visible-frame-native-link-count frame-records nearest-frame-record nearest-frame-ename nearest-frame-block nearest-frame-handle nearest-frame-bbox nearest-frame-native-handles nearest-frame-xdata-apps title-xdata-apps title-trusted-exemplar frame-trusted-exemplar pair-trusted-exemplar raw-native-pair accepted-pair accepted-record title-role frame-role title-sheet-value title-sheet-normalized frame-sheet-normalized titles-without-target-frame-count title-frame-sheet-mismatch-count frame-index frame-record frame-ename frame-block frame-handle frame-bbox frame-native-handles frame-native-target-kinds frame-xdata-apps paired-title paired-title-handle frames-without-title-count trusted-title-count untrusted-title-count cloned-pair-count trusted-title-frame-counts missing-trusted-frame-blocks used-title-enames selection-risk-count geometry-risk-count overlap-risk-count native-link-title-counts shared-native-link shared-native-link-count)
  (swcad-title-open-gmtitle-verify-all-log)
  (setq title-name (swcad-title-target-title-block-name))
  (setq title-enames (swcad-title-inserts-by-effective-name title-name))
  (setq title-count (length title-enames))
  (setq frame-records (swcad-title-frame-records))
  (setq source-titles (swcad-title-source-title-candidates))
  (setq source-frames (swcad-title-source-frame-candidates))
  (setq other-title-inserts (swcad-title-other-title-like-inserts title-name))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq filedia (getvar "FILEDIA"))
  (setq cmddia (getvar "CMDDIA"))
  (setq any-missing-tags nil)
  (setq any-empty-attrs nil)
  (setq any-missing-native-xdata nil)
  (setq any-visible-frame-native-link nil)
  (setq visible-frame-native-link-count 0)
  (setq titles-without-target-frame-count 0)
  (setq title-frame-sheet-mismatch-count 0)
  (setq frames-without-title-count 0)
  (setq trusted-title-count 0)
  (setq untrusted-title-count 0)
  (setq cloned-pair-count 0)
  (setq trusted-title-frame-counts nil)
  (setq missing-trusted-frame-blocks nil)
  (setq used-title-enames nil)
  (setq total-frame-count 0)
  (setq native-link-title-counts (swcad-title-target-title-native-link-counts))
  (setq shared-native-link-count 0)

  (swcad-title-princ-line "----- SWTITLEVERIFY 내부 전체 GMTITLE 검증(읽기 전용) -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "FILEDIA: " (swcad-title-string filedia) " (not changed)"))
  (swcad-title-princ-line (strcat "CMDDIA: " (swcad-title-string cmddia) " (not changed)"))
  (swcad-title-princ-line "Target frame inserts:")
  (foreach frame-name (swcad-title-target-frame-block-candidates)
    (setq frame-count (swcad-title-count-inserts-by-effective-name frame-name))
    (setq total-frame-count (+ total-frame-count frame-count))
    (swcad-title-princ-line (strcat "  " frame-name ": " (itoa frame-count)))
  )
  (swcad-title-princ-line (strcat "Target frame inserts total: " (itoa total-frame-count)))
  (swcad-title-princ-line (strcat "Target title block: " title-name ", inserts=" (itoa title-count)))
  (swcad-title-princ-line (strcat "Remaining source title candidates: " (itoa (length source-titles))))
  (swcad-title-princ-line (strcat "Remaining source sheet frame candidates: " (itoa (length source-frames))))
  (swcad-title-princ-line (strcat "Other non-target title-like inserts: " (itoa (length other-title-inserts))))
  (swcad-title-princ-line (strcat "Contaminated target frame definitions: " (swcad-title-list-string contaminated)))

  (if title-enames
    (progn
      (setq title-index 1)
      (foreach title-ename title-enames
        (setq title-data (entget title-ename '("*")))
        (setq title-object (swcad-title-safe-vla-object title-ename))
        (setq title-bbox (swcad-title-safe-bbox title-ename))
        (setq attr-pairs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
        (setq missing-tags (swcad-title-missing-template-tags attr-pairs))
        (setq nonempty-attrs (swcad-title-nonempty-attribute-count attr-pairs))
        (setq native-handles (swcad-title-gmtitle-native-xdata-info title-ename))
        (setq native-target-kinds (swcad-title-native-link-target-kinds title-ename))
        (setq shared-native-link (swcad-title-native-link-handle-shared-p title-ename native-link-title-counts))
        (setq title-xdata-apps (swcad-title-xdata-app-names title-ename))
        (setq nearest-frame-record (if title-bbox (swcad-title-nearest-frame-record title-bbox frame-records) nil))
        (setq nearest-frame-ename (if nearest-frame-record (car nearest-frame-record) nil))
        (setq nearest-frame-block (if nearest-frame-record (cadr nearest-frame-record) ""))
        (setq nearest-frame-handle (if nearest-frame-record (caddr nearest-frame-record) ""))
        (setq nearest-frame-bbox (if nearest-frame-record (cadddr nearest-frame-record) nil))
        (setq nearest-frame-native-handles
          (if nearest-frame-ename (swcad-title-gmtitle-native-xdata-info nearest-frame-ename) nil)
        )
        (setq nearest-frame-xdata-apps
          (if nearest-frame-ename (swcad-title-xdata-app-names nearest-frame-ename) nil)
        )
        (setq title-sheet-value (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-SIZ{6.7}"))
        (setq title-sheet-normalized (swcad-title-normalized-sheet-size title-sheet-value))
        (setq frame-sheet-normalized
          (if (> (strlen nearest-frame-block) 0)
            (swcad-title-sheet-size-from-block-name nearest-frame-block)
            nil
          )
        )
        (setq title-trusted-exemplar
          (if (> (strlen nearest-frame-block) 0)
            (swcad-title-trusted-native-exemplar-title-p title-ename nearest-frame-block)
            nil
          )
        )
        (setq frame-trusted-exemplar
          (if nearest-frame-ename
            (swcad-title-trusted-native-exemplar-frame-p nearest-frame-ename nearest-frame-block)
            nil
          )
        )
        (setq pair-trusted-exemplar
          (and title-trusted-exemplar frame-trusted-exemplar)
        )
        (setq title-role (swcad-title-exemplar-role title-ename))
        (setq frame-role (if nearest-frame-ename (swcad-title-exemplar-role nearest-frame-ename) ""))
        (setq raw-native-pair
          (and
            native-handles
            (swcad-title-internal-native-link-kinds-p native-target-kinds)
            nearest-frame-native-handles
            nearest-frame-bbox
            (not (swcad-title-frame-bbox-size-warning-for-block nearest-frame-block nearest-frame-bbox))
          )
        )
        (setq accepted-record
          (if nearest-frame-ename
            (list title-ename nearest-frame-ename nearest-frame-block title-bbox nearest-frame-bbox title-role frame-role)
            nil
          )
        )
        (setq accepted-pair
          (and
            accepted-record
            (swcad-title-target-pair-native-like-p accepted-record)
          )
        )
        (if missing-tags
          (setq any-missing-tags T)
        )
        (if (= nonempty-attrs 0)
          (setq any-empty-attrs T)
        )
        (if (not native-handles)
          (setq any-missing-native-xdata T)
        )
        (if (member "visible-target-frame" native-target-kinds)
          (progn
            (setq any-visible-frame-native-link T)
            (setq visible-frame-native-link-count (+ visible-frame-native-link-count 1))
          )
        )
        (if shared-native-link
          (setq shared-native-link-count (+ shared-native-link-count 1))
        )
        (if (not nearest-frame-record)
          (setq titles-without-target-frame-count (+ titles-without-target-frame-count 1))
        )
        (if
          (and
            title-sheet-normalized
            frame-sheet-normalized
            (not (equal title-sheet-normalized frame-sheet-normalized))
          )
          (setq title-frame-sheet-mismatch-count (+ title-frame-sheet-mismatch-count 1))
        )
        (if accepted-pair
          (progn
            (setq trusted-title-count (+ trusted-title-count 1))
            (setq trusted-title-frame-counts
              (swcad-title-count-put nearest-frame-block trusted-title-frame-counts)
            )
            (if
              (or
                (swcad-title-exemplar-clone-role-p title-role)
                (swcad-title-exemplar-clone-role-p frame-role)
                (swcad-title-exemplar-legacy-uncertain-native-role-p title-role)
                (swcad-title-exemplar-legacy-uncertain-native-role-p frame-role)
              )
              (setq cloned-pair-count (+ cloned-pair-count 1))
            )
          )
          (progn
            (setq untrusted-title-count (+ untrusted-title-count 1))
            (if nearest-frame-record
              (setq cloned-pair-count (+ cloned-pair-count 1))
            )
          )
        )
        (swcad-title-princ-line
          (strcat
            "Title #"
            (itoa title-index)
            ": handle="
            (swcad-title-string (swcad-title-dxf-value title-data 5))
            ", attrs="
            (itoa (length attr-pairs))
            ", nonempty="
            (itoa nonempty-attrs)
            ", missing-tags="
            (itoa (length missing-tags))
            ", native-links="
            (itoa (length native-handles))
            ", native-link-kinds="
            (swcad-title-list-string native-target-kinds)
            ", shared-native-link="
            (if shared-native-link "yes" "no")
            ", swtitle-marker-pair="
            (if pair-trusted-exemplar "yes" "no")
            ", raw-native-pair="
            (if raw-native-pair "yes" "no")
            ", accepted-pair="
            (if accepted-pair "yes" "no")
            ", title-marker="
            (if title-trusted-exemplar "yes" "no")
            ", frame-marker="
            (if frame-trusted-exemplar "yes" "no")
            ", title-role="
            (if (> (strlen title-role) 0) title-role "<none>")
            ", frame-role="
            (if (> (strlen frame-role) 0) frame-role "<none>")
            ", title-xdata-apps="
            (swcad-title-list-string title-xdata-apps)
            ", title-sheet="
            (if title-sheet-normalized title-sheet-normalized "<none>")
            ", nearest-frame="
            (if nearest-frame-record
              (strcat nearest-frame-block "/" nearest-frame-handle)
              "<missing>"
            )
            ", frame-sheet="
            (if frame-sheet-normalized frame-sheet-normalized "<none>")
            ", frame-native-links="
            (itoa (length nearest-frame-native-handles))
            ", frame-xdata-apps="
            (swcad-title-list-string nearest-frame-xdata-apps)
            ", bbox="
            (swcad-title-bbox-string title-bbox)
          )
        )
        (setq title-index (+ title-index 1))
      )
    )
    (swcad-title-princ-line "Title inserts: <missing>")
  )
  (if frame-records
    (progn
      (swcad-title-princ-line "Target frame detail:")
      (setq frame-index 1)
      (foreach frame-record frame-records
        (setq frame-ename (car frame-record))
        (setq frame-block (cadr frame-record))
        (setq frame-handle (caddr frame-record))
        (setq frame-bbox (cadddr frame-record))
        (setq frame-native-handles (swcad-title-gmtitle-native-xdata-info frame-ename))
        (setq frame-native-target-kinds (swcad-title-native-link-target-kinds frame-ename))
        (setq frame-xdata-apps (swcad-title-xdata-app-names frame-ename))
        (setq frame-role (swcad-title-exemplar-role frame-ename))
        (setq paired-title (swcad-title-title-for-frame-record-unused frame-record title-enames used-title-enames))
        (if paired-title
          (setq used-title-enames (append used-title-enames (list paired-title)))
        )
        (setq paired-title-handle (if paired-title (swcad-title-ename-handle paired-title) ""))
        (if
          (and
            (not paired-title)
            (not (swcad-title-title-missing-outline-frame-record-p frame-record))
          )
          (setq frames-without-title-count (+ frames-without-title-count 1))
        )
        (swcad-title-princ-line
          (strcat
            "Frame #"
            (itoa frame-index)
            ": block="
            frame-block
            ", handle="
            frame-handle
            ", sheet="
            (swcad-title-string (swcad-title-sheet-size-from-block-name frame-block))
            ", paired-title="
            (if paired-title paired-title-handle "<missing>")
            ", native-links="
            (itoa (length frame-native-handles))
            ", native-link-kinds="
            (swcad-title-list-string frame-native-target-kinds)
            ", xdata-apps="
            (swcad-title-list-string frame-xdata-apps)
            ", role="
            (if (> (strlen frame-role) 0) frame-role "<none>")
            ", transform="
            (swcad-title-insert-transform-string frame-ename)
            ", bbox="
            (swcad-title-bbox-string frame-bbox)
          )
        )
        (setq frame-index (+ frame-index 1))
      )
    )
    (swcad-title-princ-line "Target frame detail: <missing>")
  )
  (foreach frame-name (swcad-title-target-frame-block-candidates)
    (setq frame-count (swcad-title-count-inserts-by-effective-name frame-name))
    (if
      (and
        (> frame-count 0)
        (= (swcad-title-count-value frame-name trusted-title-frame-counts) 0)
        (not
          (swcad-title-title-missing-outline-frame-block-present-p frame-name)
        )
      )
      (setq missing-trusted-frame-blocks
        (append missing-trusted-frame-blocks (list frame-name))
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Native-like accepted GMTITLE titles: "
      (itoa trusted-title-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Unaccepted GMTITLE titles: "
      (itoa untrusted-title-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Non-native-like GMTITLE pairs needing replacement/recheck: "
      (itoa cloned-pair-count)
    )
  )
  (swcad-title-print-counts "Native-like accepted frame counts:" trusted-title-frame-counts)
  (swcad-title-print-string-list "Target frame blocks without native-like accepted pair:" missing-trusted-frame-blocks)
  (swcad-title-princ-line
    (strcat
      "Titles whose native link points to a visible target frame: "
      (itoa visible-frame-native-link-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Titles sharing the same native recognition handle: "
      (itoa shared-native-link-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Titles without containing target frame: "
      (itoa titles-without-target-frame-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Title/frame sheet mismatches: "
      (itoa title-frame-sheet-mismatch-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Target frames without containing title: "
      (itoa frames-without-title-count)
    )
  )
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq selection-risk-count (swcad-title-print-target-frame-selection-diagnostics frame-records))

  (setq status
    (cond
      ((or (/= filedia 1) (/= cmddia 1)) "WARN_FILEDIA_OR_CMDDIA_NOT_1")
      ((= total-frame-count 0) "FAIL_MISSING_TARGET_FRAMES")
      ((= title-count 0) "FAIL_MISSING_TARGET_TITLES")
      (contaminated "WARN_TARGET_FRAME_DEFS_CONTAMINATED")
      (any-missing-tags "FAIL_MISSING_EXPECTED_ATTRIBUTES")
      (any-empty-attrs "WARN_TITLE_ATTRIBUTES_EMPTY")
      (any-missing-native-xdata "WARN_NATIVE_GMTITLE_XDATA_NOT_FOUND")
      (any-visible-frame-native-link "WARN_NATIVE_LINKS_POINT_TO_VISIBLE_FRAMES")
      ((> shared-native-link-count 0) "WARN_SHARED_NATIVE_GMTITLE_LINKS")
      ((> titles-without-target-frame-count 0) "WARN_TITLE_WITHOUT_TARGET_FRAME")
      ((> title-frame-sheet-mismatch-count 0) "WARN_TITLE_FRAME_SHEET_MISMATCH")
      ((> frames-without-title-count 0) "WARN_TARGET_FRAME_WITHOUT_TITLE")
      ((> geometry-risk-count 0) "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      ((> selection-risk-count 0) "WARN_TARGET_FRAME_SELECTION_RISK")
      ((> (length missing-trusted-frame-blocks) 0) "WARN_TARGET_FRAME_WITHOUT_TRUSTED_EXEMPLAR")
      ((> untrusted-title-count 0) "WARN_GMTITLE_PAIRS_NOT_NATIVE_LIKE")
      ((> cloned-pair-count 0) "WARN_CLONED_GMTITLE_FRAME_BEHAVIOR_UNVERIFIED")
      ((> (length source-titles) 0) "WARN_SOURCE_TITLE_INSERTS_REMAIN")
      ((> (length source-frames) 0) "WARN_SOURCE_FRAME_INSERTS_REMAIN")
      ((> (length other-title-inserts) 0) "WARN_OTHER_TITLE_LIKE_INSERTS_REMAIN")
      (T "OK_VERIFY_ALL_GMTITLE_READY")
    )
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (swcad-title-princ-line "Note: SWTITLE markers and copied xdata alone are not treated as native GMTITLE proof.")
  (swcad-title-princ-line "Note: native GMTITLE sheet frames remain DR_A*_Outline INSERT/block references; the GMTITLE table editor is checked on the title block.")
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-native-frame-completion-check (/ summary title-name title-enames frame-records frame-record frame-index frame-ename frame-block frame-handle frame-bbox sheet paired-title paired-title-handle title-role frame-role pair-trusted clone-pair legacy-uncertain native-like reason geometry-warning attr-pairs missing-tags nonempty-attrs source-titles source-frames total-frame-count paired-count native-like-count clone-count untrusted-count shared-link-count missing-title-count missing-tags-count empty-attrs-count sheet-total-counts sheet-native-like-counts sheet-clone-counts required-sheets missing-required-sheets required-sheet a3a4-total-count a3a4-native-like-count a3a4-missing-native-like-count selection-risk-count geometry-risk-count overlap-risk-count status used-title-enames)
  (swcad-title-open-native-frame-check-log)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq title-name (swcad-title-target-title-block-name))
  (setq title-enames (swcad-title-inserts-by-effective-name title-name))
  (setq frame-records (swcad-title-frame-records))
  (setq source-titles (swcad-title-source-title-candidates))
  (setq source-frames (swcad-title-source-frame-candidates))
  (setq total-frame-count 0)
  (setq paired-count 0)
  (setq native-like-count 0)
  (setq clone-count 0)
  (setq untrusted-count 0)
  (setq shared-link-count 0)
  (setq missing-title-count 0)
  (setq missing-tags-count 0)
  (setq empty-attrs-count 0)
  (setq sheet-total-counts nil)
  (setq sheet-native-like-counts nil)
  (setq sheet-clone-counts nil)
  (setq required-sheets (swcad-title-active-required-sheets summary))
  (setq missing-required-sheets nil)
  (setq selection-risk-count 0)
  (setq used-title-enames nil)

  (swcad-title-princ-line "----- SWTITLEVERIFY 내부 A2/A3/A4 native 도면틀 확인(읽기 전용) -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Target title block: " title-name ", inserts=" (itoa (length title-enames))))
  (swcad-title-princ-line (strcat "Remaining source title candidates: " (itoa (length source-titles))))
  (swcad-title-princ-line (strcat "Remaining source sheet frame candidates: " (itoa (length source-frames))))

  (if frame-records
    (progn
      (swcad-title-princ-line "Native frame readiness by visible target frame:")
      (setq frame-index 1)
      (foreach frame-record frame-records
        (setq frame-ename (car frame-record))
        (setq frame-block (cadr frame-record))
        (setq frame-handle (caddr frame-record))
        (setq frame-bbox (cadddr frame-record))
        (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
        (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
        (setq paired-title (swcad-title-title-for-frame-record-unused frame-record title-enames used-title-enames))
        (if paired-title
          (setq used-title-enames (append used-title-enames (list paired-title)))
        )
        (setq paired-title-handle (if paired-title (swcad-title-ename-handle paired-title) ""))
        (setq title-role (if paired-title (swcad-title-exemplar-role paired-title) ""))
        (setq frame-role (swcad-title-exemplar-role frame-ename))
        (setq pair-trusted
          (if paired-title
            (swcad-title-trusted-native-exemplar-pair-p paired-title frame-ename frame-block)
            (swcad-title-title-missing-outline-frame-record-p frame-record)
          )
        )
        (setq clone-pair
          (or
            (swcad-title-exemplar-clone-role-p title-role)
            (swcad-title-exemplar-clone-role-p frame-role)
          )
        )
        (setq legacy-uncertain
          (or
            (swcad-title-exemplar-legacy-uncertain-native-role-p title-role)
            (swcad-title-exemplar-legacy-uncertain-native-role-p frame-role)
          )
        )
        (setq native-like
          (or
            (swcad-title-title-missing-outline-frame-record-p frame-record)
            (and
              paired-title
              (swcad-title-target-pair-native-like-p
                (list paired-title frame-ename frame-block nil frame-bbox title-role frame-role)
              )
            )
          )
        )
        (setq reason
          (if (swcad-title-title-missing-outline-frame-record-p frame-record)
            "title-missing-outline"
            (if paired-title
            (swcad-title-target-pair-upgrade-reason
              (list paired-title frame-ename frame-block nil frame-bbox title-role frame-role)
            )
            "missing-title"
            )
          )
        )
        (if (equal reason "shared-native-link-handle")
          (setq shared-link-count (+ shared-link-count 1))
        )
        (setq attr-pairs
          (if paired-title
            (swcad-title-title-attribute-pairs (swcad-title-safe-vla-object paired-title))
            nil
          )
        )
        (setq missing-tags (if paired-title (swcad-title-missing-template-tags attr-pairs) nil))
        (setq nonempty-attrs (if paired-title (swcad-title-nonempty-attribute-count attr-pairs) 0))
        (setq total-frame-count (+ total-frame-count 1))
        (setq sheet-total-counts (swcad-title-count-put (if sheet sheet frame-block) sheet-total-counts))
        (cond
          (native-like
            (setq native-like-count (+ native-like-count 1))
            (setq sheet-native-like-counts (swcad-title-count-put (if sheet sheet frame-block) sheet-native-like-counts))
          )
          (clone-pair
            (setq clone-count (+ clone-count 1))
            (setq sheet-clone-counts (swcad-title-count-put (if sheet sheet frame-block) sheet-clone-counts))
          )
          ((not pair-trusted)
            (setq untrusted-count (+ untrusted-count 1))
          )
        )
        (if paired-title
          (setq paired-count (+ paired-count 1))
          (if (not (swcad-title-title-missing-outline-frame-record-p frame-record))
            (setq missing-title-count (+ missing-title-count 1))
          )
        )
        (if missing-tags
          (setq missing-tags-count (+ missing-tags-count 1))
        )
        (if (and paired-title (= nonempty-attrs 0))
          (setq empty-attrs-count (+ empty-attrs-count 1))
        )
        (swcad-title-princ-line
          (strcat
            "  #"
            (itoa frame-index)
            " sheet="
            (if sheet sheet "<unknown>")
            ", frame="
            frame-block
            "/"
            frame-handle
            ", title="
            (if paired-title paired-title-handle "<missing>")
            ", swtitle-marker="
            (if pair-trusted "yes" "no")
            ", native-like="
            (if native-like "yes" "no")
            ", clone="
            (if clone-pair "yes" "no")
            ", finalize-recheck-marker="
            (if legacy-uncertain "yes" "no")
            ", title-role="
            (if (> (strlen title-role) 0) title-role "<none>")
            ", frame-role="
            (if (> (strlen frame-role) 0) frame-role "<none>")
            ", reason="
            reason
            (if geometry-warning
              (strcat ", geometry-warning=" geometry-warning)
              ""
            )
            ", attrs-nonempty="
            (itoa nonempty-attrs)
            ", missing-tags="
            (itoa (length missing-tags))
            ", transform="
            (swcad-title-insert-transform-string frame-ename)
            ", bbox="
            (swcad-title-bbox-string frame-bbox)
          )
        )
        (setq frame-index (+ frame-index 1))
      )
    )
    (swcad-title-princ-line "Native frame readiness by visible target frame: <missing>")
  )

  (swcad-title-print-counts "Visible target frame counts by sheet:" sheet-total-counts)
  (swcad-title-print-counts "Native-like target frame counts by sheet:" sheet-native-like-counts)
  (swcad-title-print-counts "Clone target frame counts by sheet:" sheet-clone-counts)
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq selection-risk-count (swcad-title-print-target-frame-selection-diagnostics frame-records))
  (foreach required-sheet required-sheets
    (if (= (swcad-title-count-value required-sheet sheet-total-counts) 0)
      (setq missing-required-sheets (append missing-required-sheets (list required-sheet)))
    )
  )
  (swcad-title-print-string-list "현재 필요한 대상 용지 누락:" missing-required-sheets)
  (setq a3a4-total-count
    (+
      (swcad-title-count-value "A2" sheet-total-counts)
      (swcad-title-count-value "A3" sheet-total-counts)
      (swcad-title-count-value "A4" sheet-total-counts)
    )
  )
  (setq a3a4-native-like-count
    (+
      (swcad-title-count-value "A2" sheet-native-like-counts)
      (swcad-title-count-value "A3" sheet-native-like-counts)
      (swcad-title-count-value "A4" sheet-native-like-counts)
    )
  )
  (setq a3a4-missing-native-like-count (- a3a4-total-count a3a4-native-like-count))
  (swcad-title-princ-line
    (strcat
      "A2/A3/A4 native-like completion: "
      (itoa a3a4-native-like-count)
      " / "
      (itoa a3a4-total-count)
    )
  )
  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line (strcat "  target frames: " (itoa total-frame-count)))
  (swcad-title-princ-line (strcat "  paired titles: " (itoa paired-count)))
  (swcad-title-princ-line (strcat "  native-like pairs: " (itoa native-like-count)))
  (swcad-title-princ-line (strcat "  cloned pairs: " (itoa clone-count)))
  (swcad-title-princ-line (strcat "  shared native-link pairs: " (itoa shared-link-count)))
  (swcad-title-princ-line (strcat "  untrusted/non-marker pairs: " (itoa untrusted-count)))
  (swcad-title-princ-line (strcat "  frames without title: " (itoa missing-title-count)))
  (swcad-title-princ-line (strcat "  titles with missing tags: " (itoa missing-tags-count)))
  (swcad-title-princ-line (strcat "  titles with empty attributes: " (itoa empty-attrs-count)))
  (swcad-title-princ-line (strcat "  target frame selection risk warnings: " (itoa selection-risk-count)))
  (swcad-title-print-native-vs-nonnative-sample)

  (setq status
    (cond
      ((= total-frame-count 0) "FAIL_MISSING_TARGET_FRAMES")
      ((> geometry-risk-count 0) "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      ((> clone-count 0) "WARN_CLONED_GMTITLE_FRAME_NEEDS_NATIVE_UPGRADE")
      ((> shared-link-count 0) "WARN_SHARED_NATIVE_GMTITLE_LINKS")
      ((> a3a4-missing-native-like-count 0) "WARN_A2_A3_A4_TARGET_FRAME_NOT_NATIVE_LIKE")
      (missing-required-sheets "WARN_REQUIRED_TARGET_SHEET_MISSING")
      ((> (length source-titles) 0) "WARN_SOURCE_TITLE_INSERTS_REMAIN")
      ((> (length source-frames) 0) "WARN_SOURCE_FRAME_INSERTS_REMAIN")
      ((> missing-title-count 0) "WARN_TARGET_FRAME_WITHOUT_TITLE")
      ((> missing-tags-count 0) "FAIL_MISSING_EXPECTED_ATTRIBUTES")
      ((> empty-attrs-count 0) "WARN_TITLE_ATTRIBUTES_EMPTY")
      ((> selection-risk-count 0) "WARN_TARGET_FRAME_SELECTION_RISK")
      ((and (= a3a4-missing-native-like-count 0) (> untrusted-count 0)) "WARN_NOT_ALL_TARGET_FRAMES_NATIVE_LIKE")
      ((/= native-like-count total-frame-count) "WARN_NOT_ALL_TARGET_FRAMES_NATIVE_LIKE")
      (T "OK_A2_A3_A4_NATIVE_FRAME_READY_FOR_MANUAL_CHECK")
    )
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (if (> clone-count 0)
    (progn
      (swcad-title-princ-line "GMPOWEREDIT 진단: 복제된 GMTITLE 쌍이 남아 있습니다.")
      (swcad-title-princ-line "복제 쌍은 보이는 도면틀/제목블록/속성값은 복사됐지만, GstarCAD native 편집기 인식은 아직 증명되지 않은 상태입니다.")
      (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행해서 해당 쌍을 fresh native GMTITLE 결과로 교체하세요.")
    )
  )
  (if (> shared-link-count 0)
    (progn
      (swcad-title-princ-line "GMPOWEREDIT 진단: 여러 GMTITLE 제목블록이 같은 내부 native 인식 handle을 공유합니다.")
      (swcad-title-princ-line "preserve-copy/복제 결과에서 자주 보이는 상태입니다. 겉보기는 맞아도 더블클릭 인식이 REFEDIT나 블록 편집으로 떨어질 수 있습니다.")
      (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행해서 해당 쌍을 fresh native GMTITLE 결과로 교체하세요.")
    )
  )
  (if (and missing-required-sheets (> (length source-frames) 0))
    (progn
      (swcad-title-princ-line "누락 용지 진단: 기존 SOLIDWORKS 표제란 없는 도면틀 시트가 아직 남아 있습니다.")
      (swcad-title-princ-line "native 복제 검토가 끝난 뒤 SWTITLECONVERTNEXT로 남은 title-missing/frame-only 예외 시트를 처리하세요.")
    )
  )
  (swcad-title-princ-line "최종 수동 확인 필요: GstarCAD에서 변환된 대표 용지의 DR_titlea_3rd 제목블록을 더블클릭하세요.")
  (swcad-title-princ-line "참고: DR_A*_Outline 도면틀은 여전히 INSERT/block 참조입니다. GMTITLE 표 편집창은 짝이 되는 제목블록에서 확인하세요.")
  (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-orphan-target-frame-records (/ title-name title-enames frame-records frame-record paired-title result used-title-enames)
  (setq title-name (swcad-title-target-title-block-name))
  (setq title-enames (swcad-title-inserts-by-effective-name title-name))
  (setq frame-records (swcad-title-frame-records))
  (setq used-title-enames nil)
  (setq result nil)
  (foreach frame-record frame-records
    (setq paired-title (swcad-title-title-for-frame-record-unused frame-record title-enames used-title-enames))
    (if paired-title
      (setq used-title-enames (append used-title-enames (list paired-title)))
      (if (not (swcad-title-title-missing-outline-frame-record-p frame-record))
        (setq result (append result (list frame-record)))
      )
    )
  )
  result
)

(defun swcad-title-print-orphan-target-frame-records (records / index record sheet)
  (if records
    (progn
      (swcad-title-princ-line "제목블록이 없는 고아 GMTITLE 도면틀 후보:")
      (setq index 1)
      (foreach record records
        (setq sheet (swcad-title-sheet-size-from-block-name (cadr record)))
        (swcad-title-princ-line
          (strcat
            "  #"
            (itoa index)
            " sheet="
            (if sheet sheet "<unknown>")
            ", frame="
            (cadr record)
            "/"
            (caddr record)
            ", 범위="
            (swcad-title-bbox-string (cadddr record))
          )
        )
        (setq index (+ index 1))
      )
    )
    (swcad-title-princ-line "제목블록이 없는 고아 GMTITLE 도면틀 후보: <없음>")
  )
)

(defun swcad-title-clean-orphan-target-frames (/ *error* records total answer deleted-count record doc)
  (defun *error* (msg)
    (if doc
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
    )
    (if msg
      (swcad-title-princ-line (strcat "SWTITLEPREPARE 고아 GMTITLE 도면틀 정리 오류: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_ORPHAN_TARGET_FRAME_CLEAN")
    (swcad-title-close-log)
    (princ)
  )
  (swcad-title-open-orphan-frame-clean-log)
  (setq doc (swcad-title-doc))
  (setq records (swcad-title-orphan-target-frame-records))
  (setq total (length records))
  (swcad-title-princ-line "----- SWTITLEPREPARE 내부 제목블록 없는 GMTITLE 도면틀 정리 -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-print-orphan-target-frame-records records)
  (cond
    ((= total 0)
      (swcad-title-apply-result "OK_NO_ORPHAN_TARGET_FRAMES")
      (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "읽기 전용 도면이라 고아 도면틀을 삭제하지 않았습니다.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "고아 도면틀 정리는 Documents/CAD tool/work 안의 작업복사본에서만 실행됩니다.")
      (swcad-title-princ-line "원본 도면 보호를 위해 도면 데이터는 변경하지 않았습니다.")
    )
    (T
      (setq answer
        (getstring
          T
          "\n위 고아 GMTITLE 도면틀만 삭제하려면 YES를 입력하세요. 취소하려면 Enter: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (swcad-title-apply-result "ABORT_ORPHAN_TARGET_FRAME_CLEAN_USER")
          (swcad-title-princ-line "사용자가 취소했습니다. 도면 데이터는 변경하지 않았습니다.")
        )
        (progn
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq deleted-count 0)
          (foreach record records
            (if (swcad-title-delete-ename (car record))
              (setq deleted-count (+ deleted-count 1))
            )
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line (strcat "삭제한 고아 GMTITLE 도면틀: " (itoa deleted-count)))
          (swcad-title-apply-result "OK_ORPHAN_TARGET_FRAMES_CLEANED")
          (swcad-title-princ-line "다음: SWTITLEVERIFY를 다시 실행해서 겹침 경고가 사라졌는지 확인하세요.")
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-target-pair-record-key (record / title frame)
  (setq title (car record))
  (setq frame (cadr record))
  (strcat
    (if title (swcad-title-ename-handle title) "<no-title>")
    "/"
    (if frame (swcad-title-ename-handle frame) "<no-frame>")
  )
)

(defun swcad-title-target-pair-role-score (role / upper)
  (setq upper (strcase (swcad-title-string role)))
  (cond
    ((wcmatch upper "*NATIVE-UPGRADE*") 500)
    ((wcmatch upper "*NATIVE-ADOPT*") 480)
    ((wcmatch upper "*NATIVE-APPLY*") 450)
    ((swcad-title-exemplar-native-role-p role) 400)
    ((swcad-title-exemplar-clone-role-p role) 100)
    (T 0)
  )
)

(defun swcad-title-target-pair-nonempty-attr-count (record / title object attr-pairs)
  (setq title (car record))
  (setq object (if title (swcad-title-safe-vla-object title) nil))
  (setq attr-pairs (if object (swcad-title-title-attribute-pairs object) nil))
  (swcad-title-nonempty-attribute-count attr-pairs)
)

(defun swcad-title-target-pair-keep-score (record / title-role frame-role score)
  (setq title-role (nth 5 record))
  (setq frame-role (nth 6 record))
  (setq score
    (+
      (swcad-title-target-pair-role-score title-role)
      (swcad-title-target-pair-role-score frame-role)
      (* 5 (swcad-title-target-pair-nonempty-attr-count record))
    )
  )
  (if (swcad-title-target-pair-native-like-p record)
    (setq score (+ score 50))
  )
  score
)

(defun swcad-title-target-pair-better-record (a b / a-score b-score)
  (setq a-score (swcad-title-target-pair-keep-score a))
  (setq b-score (swcad-title-target-pair-keep-score b))
  (if (>= a-score b-score) a b)
)

(defun swcad-title-duplicate-target-pair-records (/ pairs result seen total i j first second first-block second-block first-sheet second-sheet first-bbox second-bbox keep discard discard-key overlap)
  (setq pairs (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (setq seen nil)
  (setq total (length pairs))
  (setq i 0)
  (while (< i total)
    (setq first (nth i pairs))
    (setq j (+ i 1))
    (while (< j total)
      (setq second (nth j pairs))
      (setq first-block (caddr first))
      (setq second-block (caddr second))
      (setq first-sheet (swcad-title-sheet-size-from-block-name first-block))
      (setq second-sheet (swcad-title-sheet-size-from-block-name second-block))
      (setq first-bbox (nth 4 first))
      (setq second-bbox (nth 4 second))
      (if
        (and
          first-sheet
          second-sheet
          (equal (strcase first-sheet) (strcase second-sheet))
          (equal (strcase (swcad-title-string first-block)) (strcase (swcad-title-string second-block)))
          (swcad-title-bbox-nearly-same-p first-bbox second-bbox 0.5)
        )
        (progn
          (setq keep (swcad-title-target-pair-better-record first second))
          (setq discard (if (eq keep first) second first))
          (setq discard-key (swcad-title-target-pair-record-key discard))
          (if (not (member discard-key seen))
            (progn
              (setq overlap (swcad-title-bbox-overlap-box first-bbox second-bbox))
              (setq result
                (append
                  result
                  (list (list first-sheet keep discard overlap))
                )
              )
              (setq seen (append seen (list discard-key)))
            )
          )
        )
      )
      (setq j (+ j 1))
    )
    (setq i (+ i 1))
  )
  result
)

(defun swcad-title-print-duplicate-target-pair-records (records / index record sheet keep discard overlap keep-title keep-frame discard-title discard-frame)
  (swcad-title-princ-line "겹친 GMTITLE target 쌍 후보:")
  (if records
    (progn
      (setq index 1)
      (foreach record records
        (setq sheet (car record))
        (setq keep (cadr record))
        (setq discard (caddr record))
        (setq overlap (cadddr record))
        (setq keep-title (car keep))
        (setq keep-frame (cadr keep))
        (setq discard-title (car discard))
        (setq discard-frame (cadr discard))
        (swcad-title-princ-line
          (strcat
            "  #"
            (itoa index)
            " sheet="
            sheet
            ", 유지="
            (swcad-title-ename-handle keep-frame)
            "/"
            (swcad-title-ename-handle keep-title)
            " role="
            (swcad-title-role-display (nth 6 keep))
            "/"
            (swcad-title-role-display (nth 5 keep))
            ", 삭제후보="
            (swcad-title-ename-handle discard-frame)
            "/"
            (swcad-title-ename-handle discard-title)
            " role="
            (swcad-title-role-display (nth 6 discard))
            "/"
            (swcad-title-role-display (nth 5 discard))
            ", 겹침="
            (swcad-title-bbox-string overlap)
          )
        )
        (setq index (+ index 1))
      )
    )
    (swcad-title-princ-line "  <없음>")
  )
)

(defun swcad-title-clean-duplicate-target-pairs (/ *error* records total answer deleted-title-count deleted-frame-count record discard title frame doc)
  (defun *error* (msg)
    (if doc
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
    )
    (if msg
      (swcad-title-princ-line (strcat "SWTITLEPREPARE 겹친 GMTITLE target 쌍 정리 오류: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_DUPLICATE_TARGET_PAIR_CLEAN")
    (swcad-title-close-log)
    (princ)
  )
  (swcad-title-open-duplicate-target-pair-clean-log)
  (setq doc (swcad-title-doc))
  (setq records (swcad-title-duplicate-target-pair-records))
  (setq total (length records))
  (swcad-title-princ-line "----- SWTITLEPREPARE 내부 겹친 GMTITLE target 쌍 정리 -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-print-duplicate-target-pair-records records)
  (cond
    ((= total 0)
      (swcad-title-apply-result "OK_NO_DUPLICATE_TARGET_PAIRS")
      (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "읽기 전용 도면에서는 겹친 target 쌍을 정리하지 않습니다.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "겹친 target 쌍 정리는 Documents/CAD tool/work 안의 작업복사본에서만 실행합니다.")
    )
    (T
      (setq answer
        (getstring
          T
          "\n위 삭제후보 GMTITLE target 쌍만 삭제하려면 YES를 입력하세요. 취소하려면 Enter: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (swcad-title-apply-result "ABORT_DUPLICATE_TARGET_PAIR_CLEAN_USER")
          (swcad-title-princ-line "사용자가 취소했습니다. 도면 데이터는 변경하지 않았습니다.")
        )
        (progn
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq deleted-title-count 0)
          (setq deleted-frame-count 0)
          (foreach record records
            (setq discard (caddr record))
            (setq title (car discard))
            (setq frame (cadr discard))
            (if (swcad-title-delete-ename title)
              (setq deleted-title-count (+ deleted-title-count 1))
            )
            (if (swcad-title-delete-ename frame)
              (setq deleted-frame-count (+ deleted-frame-count 1))
            )
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line (strcat "삭제한 중복 제목블록: " (itoa deleted-title-count)))
          (swcad-title-princ-line (strcat "삭제한 중복 도면틀: " (itoa deleted-frame-count)))
          (swcad-title-apply-result "OK_DUPLICATE_TARGET_PAIRS_CLEANED")
          (swcad-title-princ-line "다음: SWTITLESTATUS를 다시 실행해서 겹침 경고가 사라졌는지 확인하세요.")
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-adoptable-target-pair-p (record frame-block target-bbox / title frame record-frame-block frame-bbox title-role frame-role trusted clone-pair legacy-uncertain geometry-warning)
  (setq title (car record))
  (setq frame (cadr record))
  (setq record-frame-block (caddr record))
  (setq frame-bbox (nth 4 record))
  (setq title-role (nth 5 record))
  (setq frame-role (nth 6 record))
  (setq trusted (swcad-title-trusted-native-exemplar-pair-p title frame frame-block))
  (setq clone-pair
    (or
      (swcad-title-exemplar-clone-role-p title-role)
      (swcad-title-exemplar-clone-role-p frame-role)
    )
  )
  (setq legacy-uncertain
    (or
      (swcad-title-exemplar-legacy-uncertain-native-role-p title-role)
      (swcad-title-exemplar-legacy-uncertain-native-role-p frame-role)
    )
  )
  (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
  (and
    title
    frame
    (equal (strcase (swcad-title-string record-frame-block)) (strcase (swcad-title-string frame-block)))
    (swcad-title-bbox-nearly-same-p frame-bbox target-bbox 0.5)
    (not geometry-warning)
    (not clone-pair)
    (not legacy-uncertain)
    (or
      (swcad-title-target-pair-native-like-p record)
      (and
        trusted
        (swcad-title-exemplar-safe-native-source-role-p title-role)
        (swcad-title-exemplar-safe-native-source-role-p frame-role)
        (swcad-title-exemplar-native-entity-p title)
        (swcad-title-exemplar-native-entity-p frame)
      )
    )
  )
)

(defun swcad-title-adoptable-target-pair-for-frame-bbox (frame-block target-bbox / records result record)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (if
      (and
        (not result)
        (swcad-title-adoptable-target-pair-p record frame-block target-bbox)
      )
      (setq result record)
    )
  )
  result
)

(defun swcad-title-adopt-existing-native-gmtitle-transfer (adopt-pair frame-block values source-ename source-frame-ename records title-shell-handles title-graphic-handles frame-graphic-handles residue-handles / title frame title-ref doc original-attr-values attr-count attr-errors deleted-text-count skipped-block-text-count old-frame-deleted deleted-title-shell-count deleted-title-graphic-count deleted-frame-graphic-count deleted-residue-count marker-ok record)
  (setq title (car adopt-pair))
  (setq frame (cadr adopt-pair))
  (setq title-ref (swcad-title-safe-vla-object title))
  (setq doc (swcad-title-doc))
  (vl-catch-all-apply 'vla-StartUndoMark (list doc))
  (setq original-attr-values (swcad-title-title-attribute-pairs title-ref))
  (setq attr-count (swcad-title-set-insert-attributes title-ref values))
  (setq attr-errors (swcad-title-value-verification-errors title-ref values))
  (swcad-title-print-value-verification-errors attr-errors)
  (if attr-errors
    (progn
      (swcad-title-set-insert-attributes title-ref original-attr-values)
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
      (swcad-title-apply-result "ABORT_TITLE_ATTRIBUTE_VERIFICATION")
      (swcad-title-princ-line "채택 대상 GMTITLE의 기존 속성값을 복원했습니다.")
      (swcad-title-princ-line "기존 SOLIDWORKS 제목 데이터와 도면틀은 삭제하지 않았습니다.")
      nil
    )
    (progn
      (if source-ename
        (swcad-title-delete-ename source-ename)
      )
      (setq deleted-text-count 0)
      (setq skipped-block-text-count 0)
      (foreach record records
        (if (swcad-title-delete-text-record record)
          (setq deleted-text-count (+ deleted-text-count 1))
          (setq skipped-block-text-count (+ skipped-block-text-count 1))
        )
      )
      (setq old-frame-deleted "no")
      (if source-frame-ename
        (progn
          (swcad-title-delete-ename source-frame-ename)
          (setq old-frame-deleted "yes")
        )
      )
      (setq deleted-title-shell-count (swcad-title-delete-handle-list title-shell-handles))
      (setq deleted-title-graphic-count (swcad-title-delete-handle-list title-graphic-handles))
      (setq deleted-frame-graphic-count
        (if source-frame-ename
          0
          (swcad-title-delete-handle-list frame-graphic-handles)
        )
      )
      (setq deleted-residue-count (swcad-title-delete-handle-list residue-handles))
      (setq marker-ok
        (swcad-title-mark-native-exemplar-pair
          title
          frame
          frame-block
          "native-adopt"
        )
      )
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
      (swcad-title-princ-line "기존 위치의 native GMTITLE 쌍을 새로 만들지 않고 채택했습니다.")
      (swcad-title-princ-line
        (strcat
          "Adopted title/frame: "
          (swcad-title-ename-handle title)
          "/"
          (swcad-title-ename-handle frame)
        )
      )
      (swcad-title-princ-line (strcat "Native adopt marker set: " (if marker-ok "yes" "no") ", role=native-adopt"))
      (swcad-title-princ-line (strcat "Attributes set: " (itoa attr-count)))
      (swcad-title-princ-line (strcat "Old loose title texts deleted: " (itoa deleted-text-count)))
      (swcad-title-princ-line (strcat "Old block-internal title texts handled by deleting source insert: " (itoa skipped-block-text-count)))
      (swcad-title-princ-line (strcat "삭제한 기존 loose-text 제목 셸 INSERT: " (itoa deleted-title-shell-count)))
      (swcad-title-princ-line (strcat "Old loose title graphics deleted: " (itoa deleted-title-graphic-count)))
      (swcad-title-princ-line (strcat "Old title insert deleted: " (if source-ename "yes" "not applicable (loose-text source)")))
      (swcad-title-princ-line (strcat "Old frame insert deleted: " old-frame-deleted))
      (swcad-title-princ-line (strcat "Old loose frame graphics deleted: " (itoa deleted-frame-graphic-count)))
      (swcad-title-princ-line (strcat "Old SOLIDWORKS sheet residue deleted: " (itoa deleted-residue-count)))
      (swcad-title-apply-result "ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER")
      (swcad-title-princ-line "최종 수동 확인: 채택된 GMTITLE 제목블록을 더블클릭해서 GMTITLE 표 편집창이 열리는지 확인하세요.")
      T
    )
  )
)

(defun swcad-title-insert-handle-list (/ ss total index ename data handle result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq handle (strcase (swcad-title-string (swcad-title-dxf-value data 5))))
    (if (> (strlen handle) 0)
      (setq result (append result (list handle)))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-native-gmtitle-post-prompt-abort-p (reason)
  (member
    reason
    '(
      "COMMANDLINE_POST_INSERT_PROMPT_CANCELLED"
      "OBJECT_MOVE_PROMPT_CANCELLED_AFTER_GMTITLE_CREATED"
      "POST_INSERT_EMPTY_PROMPT_CANCELLED_AFTER_GMTITLE_CREATED"
      "POST_INSERT_PROMPT_CANCELLED_AFTER_GMTITLE_CREATED"
    )
  )
)

(defun swcad-title-native-gmtitle-post-prompt-acceptable-p (reason)
  (and
    *swcad-title-last-native-gmtitle-placement-used*
    (member
      reason
      '(
        "OBJECT_MOVE_PROMPT_CANCELLED_AFTER_GMTITLE_CREATED"
        "POST_INSERT_EMPTY_PROMPT_CANCELLED_AFTER_GMTITLE_CREATED"
      )
    )
  )
)

(defun swcad-title-native-gmtitle-result-valid-p (result frame-block / title frame actual-title actual-frame geometry-warning)
  (setq title (if result (car result) nil))
  (setq frame (if result (cadr result) nil))
  (setq actual-title (if title (swcad-title-effective-insert-name title) ""))
  (setq actual-frame (if frame (swcad-title-effective-insert-name frame) ""))
  (setq geometry-warning
    (if frame
      (swcad-title-frame-bbox-size-warning-for-block
        frame-block
        (swcad-title-frame-reference-effective-bbox frame frame-block)
      )
      nil
    )
  )
  (and
    title
    frame
    (swcad-title-native-target-title-name-p actual-title)
    (swcad-title-frame-name-matches-p actual-frame frame-block)
    (not geometry-warning)
    (or
      (not (swcad-title-native-gmtitle-post-prompt-abort-p *swcad-title-last-native-gmtitle-abort-reason*))
      (swcad-title-native-gmtitle-post-prompt-acceptable-p *swcad-title-last-native-gmtitle-abort-reason*)
    )
  )
)

(defun swcad-title-new-insert-enames (before-handles / ss total index ename data handle result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq handle (strcase (swcad-title-string (swcad-title-dxf-value data 5))))
    (if (and (> (strlen handle) 0) (not (member handle before-handles)))
      (setq result (append result (list ename)))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-template-tag-p (tag / upper slot found)
  (setq upper (strcase (swcad-title-string tag)))
  (setq found nil)
  (foreach slot *swcad-title-transfer-template*
    (if (equal upper (strcase (car slot)))
      (setq found T)
    )
  )
  found
)

(defun swcad-title-insert-template-attribute-count (ename / object attrs attr count)
  (setq object (swcad-title-safe-vla-object ename))
  (setq attrs (if object (swcad-title-get-insert-attributes object) nil))
  (setq count 0)
  (foreach attr attrs
    (if (swcad-title-template-tag-p (swcad-title-attribute-tag attr))
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-select-new-gmtitle-title (enames / title-name best best-score ename name score attr-count)
  (setq title-name (strcase (swcad-title-target-title-block-name)))
  (setq best nil)
  (setq best-score 0)
  (foreach ename enames
    (setq name (strcase (swcad-title-effective-insert-name ename)))
    (setq attr-count (swcad-title-insert-template-attribute-count ename))
    (setq score attr-count)
    (if (equal name title-name)
      (setq score (+ score 100))
    )
    (if (and (> score best-score) (> attr-count 0))
      (progn
        (setq best ename)
        (setq best-score score)
      )
    )
  )
  best
)

(defun swcad-title-frame-name-matches-p (name frame-block)
  (equal
    (strcase (swcad-title-string name))
    (strcase (swcad-title-string frame-block))
  )
)

(defun swcad-title-select-new-gmtitle-frame (enames title-ename frame-block / frame-name best fallback best-area ename name bbox area warning)
  (setq frame-name (strcase (swcad-title-string frame-block)))
  (if (= (strlen frame-name) 0)
    (setq frame-name (strcase (swcad-title-target-frame-block-name)))
  )
  (setq best nil)
  (setq fallback nil)
  (setq best-area 0.0)
  (foreach ename enames
    (if (not (eq ename title-ename))
      (progn
        (setq name (strcase (swcad-title-effective-insert-name ename)))
        (setq bbox (swcad-title-safe-bbox ename))
        (setq area (swcad-title-bbox-area bbox))
        (cond
          ((equal name frame-name)
            (if (not fallback)
              (setq fallback ename)
            )
            (setq warning (swcad-title-frame-bbox-size-warning-for-block frame-block bbox))
            (if (and (not best) (not warning))
              (setq best ename)
            )
          )
          ((and (not fallback) (> area best-area))
            (setq fallback ename)
            (setq best-area area)
          )
        )
      )
    )
  )
  (if best best fallback)
)

(defun swcad-title-script-active-p (/ active)
  (setq active (swcad-title-safe-getvar "CMDACTIVE"))
  (and active (/= 0 (logand active 4)))
)

(defun swcad-title-function-available-p (name / atoms)
  (setq atoms (atoms-family 1))
  (and atoms (member (strcase (swcad-title-string name)) atoms))
)

(defun swcad-title-native-gmtitle-command-call (placement-point / args runner)
  (setq args
    (if placement-point
      (list "_.-GMTITLE" placement-point)
      (list "_.-GMTITLE")
    )
  )
  (setq runner
    (cond
      ((swcad-title-function-available-p "VL-CMDF") 'vl-cmdf)
      ((swcad-title-function-available-p "COMMAND-S") 'command-s)
      (T 'command)
    )
  )
  (swcad-title-princ-line
    (strcat
      "  Command-line runner: "
      (swcad-title-string runner)
    )
  )
  (vl-catch-all-apply runner args)
)

(defun swcad-title-run-native-gmtitle-commandline (frame-block placement-point / before-handles new-enames title-ename frame-ename old-osmode old-dynmode command-result guard prompt current-new-enames)
  (setq before-handles (swcad-title-insert-handle-list))
  (setq *swcad-title-last-native-gmtitle-abort-reason* nil)
  (setq *swcad-title-last-native-gmtitle-placement-used* nil)
  (swcad-title-princ-line
    (strcat
      "현재 GstarCAD 기본값으로 명령줄 -GMTITLE을 먼저 시도합니다. 요청 도면틀: "
      (swcad-title-string frame-block)
      "."
    )
  )
  (if placement-point
    (swcad-title-princ-line
      (strcat
        "  명령줄 삽입점: "
        (swcad-title-point-string placement-point)
      )
    )
  )
  (setq old-osmode (swcad-title-safe-getvar "OSMODE"))
  (setq old-dynmode (swcad-title-safe-getvar "DYNMODE"))
  (if old-osmode
    (swcad-title-safe-setvar "OSMODE" 0)
  )
  (setq command-result (swcad-title-native-gmtitle-command-call placement-point))
  (if (vl-catch-all-error-p command-result)
    (progn
      (setq *swcad-title-last-native-gmtitle-abort-reason* "COMMANDLINE_GMTITLE_ERROR")
      (swcad-title-princ-line
        (strcat
          "  명령줄 -GMTITLE 오류: "
          (vl-catch-all-error-message command-result)
        )
      )
    )
  )
  (setq guard 0)
  (while (and (> (getvar "CMDACTIVE") 0) (< guard 20))
    (setq prompt (swcad-title-command-prompt-string))
    (setq current-new-enames (swcad-title-new-insert-enames before-handles))
    (cond
      (current-new-enames
        (setq *swcad-title-last-native-gmtitle-abort-reason*
          "COMMANDLINE_POST_INSERT_PROMPT_CANCELLED"
        )
        (swcad-title-princ-line
          "  명령줄 -GMTITLE이 INSERT를 만들었지만 추가 프롬프트가 남아 있어 추가 프롬프트를 취소합니다."
        )
        (if (> (strlen (vl-string-trim " \t\r\n" (swcad-title-string prompt))) 0)
          (swcad-title-princ-line
            (strcat "  당시 프롬프트: " (swcad-title-string prompt))
          )
        )
        (swcad-title-cancel-active-command)
        (setq guard 20)
      )
      ((> guard 2)
        (setq *swcad-title-last-native-gmtitle-abort-reason*
          "COMMANDLINE_GMTITLE_NO_INSERTS_CANCELLED"
        )
        (swcad-title-princ-line
          "  명령줄 -GMTITLE이 제때 INSERT를 만들지 못해 취소하고, 필요하면 대화식 GMTITLE로 전환합니다."
        )
        (swcad-title-cancel-active-command)
        (setq guard 20)
      )
    )
    (setq guard (+ guard 1))
  )
  (swcad-title-restore-gmtitle-input-vars old-osmode old-dynmode)
  (setq new-enames (swcad-title-new-insert-enames before-handles))
  (if new-enames
    (setq *swcad-title-last-native-gmtitle-placement-used* T)
  )
  (setq title-ename (swcad-title-select-new-gmtitle-title new-enames))
  (setq frame-ename (swcad-title-select-new-gmtitle-frame new-enames title-ename frame-block))
  (swcad-title-princ-line
    (strcat
      "  명령줄 -GMTITLE 새 INSERT 수: "
      (itoa (length new-enames))
    )
  )
  (swcad-title-insert-log-label "  Command-line GMTITLE title insert" title-ename)
  (swcad-title-insert-log-label "  Command-line GMTITLE frame insert" frame-ename)
  (list title-ename frame-ename new-enames)
)

(defun swcad-title-run-native-gmtitle-prefer-commandline (frame-block placement-point / result new-count deleted-count commandline-error interactive-result interactive-error script-active commandline-disabled skip-commandline skip-interactive-batch)
  (setq script-active (swcad-title-script-active-p))
  (setq commandline-disabled (not *swcad-title-allow-commandline-gmtitle*))
  (setq skip-commandline
    (or
      commandline-disabled
      (and script-active (not *swcad-title-allow-script-commandline-gmtitle*))
    )
  )
  (setq skip-interactive-batch
    (and
      *swcad-title-native-upgrade-batch-mode*
      (not *swcad-title-allow-batch-interactive-native-gmtitle*)
    )
  )
  (if skip-commandline
    (progn
      (setq result (list nil nil nil))
      (if commandline-disabled
        (progn
          (setq *swcad-title-last-native-gmtitle-abort-reason*
            "COMMANDLINE_GMTITLE_DISABLED_BY_HISTORY_GATE"
          )
          (swcad-title-princ-line
            "이력 기준으로 명령줄 -GMTITLE 자동 선택은 사용하지 않습니다."
          )
          (swcad-title-princ-line
            "이유: 실제 CAD 테스트에서 DR 용지/제목블록을 잘못 고르는 사례가 확인됐습니다."
          )
        )
        (progn
          (setq *swcad-title-last-native-gmtitle-abort-reason*
            "COMMANDLINE_GMTITLE_SKIPPED_IN_SCRIPT"
          )
          (swcad-title-princ-line
            "SCRIPT/자동화 명령이 실행 중이라 명령줄 -GMTITLE 시도를 건너뜁니다."
          )
        )
      )
    )
    (progn
      (setq result
        (vl-catch-all-apply
          'swcad-title-run-native-gmtitle-commandline
          (list frame-block placement-point)
        )
      )
      (if (vl-catch-all-error-p result)
        (progn
          (setq commandline-error (vl-catch-all-error-message result))
          (setq result (list nil nil nil))
          (setq *swcad-title-last-native-gmtitle-abort-reason* "COMMANDLINE_GMTITLE_EXCEPTION")
          (swcad-title-princ-line
            (strcat
              "  명령줄 -GMTITLE 예외: "
              commandline-error
            )
          )
        )
      )
    )
  )
  (if (swcad-title-native-gmtitle-result-valid-p result frame-block)
    result
    (progn
      (setq new-count (length (caddr result)))
      (if (> new-count 0)
        (progn
          (setq deleted-count (swcad-title-delete-ename-list (caddr result)))
          (swcad-title-princ-line
            (strcat
              "  명령줄 -GMTITLE 결과가 요청한 DR 도면틀/제목블록과 달라 새 INSERT를 제거했습니다. 제거 수: "
              (itoa deleted-count)
            )
          )
        )
      )
      (if script-active
        (progn
          (swcad-title-princ-line
            "SCRIPT/자동화 명령이 실행 중이라 대화식 GMTITLE 전환을 건너뜁니다."
          )
          result
        )
        (if skip-interactive-batch
          (progn
            (setq *swcad-title-last-native-gmtitle-abort-reason*
              "INTERACTIVE_GMTITLE_SKIPPED_IN_BATCH"
            )
            (swcad-title-princ-line
              "일괄 모드에서는 대화식 GMTITLE 전환을 건너뜁니다."
            )
            (swcad-title-princ-line
              "이유: 현재 GstarCAD GMTITLE 창이 ISO 기본값으로 열리므로, 일괄 자동화가 필요한 DR 도면틀/제목블록을 안전하게 고를 수 없습니다."
            )
            (swcad-title-princ-line
              (strcat
                "수동으로 선택해야 하는 값: 용지="
                (swcad-title-string frame-block)
                ", 제목블록="
                (swcad-title-target-title-block-name)
                ", Frame positioning ON, Object move OFF."
              )
            )
            (swcad-title-princ-line
              "A2/A3/A4 대상은 SWTITLESTATUS로 상태를 확인한 뒤 SWTITLECONVERTNEXT로 한 장씩 처리하세요. 대화상자를 확인하기 위해 한 번에 한 후보만 처리합니다."
            )
            result
          )
          (progn
            (swcad-title-princ-line
              "대화식 GMTITLE 창으로 전환합니다. 요청된 DR 도면틀/제목블록을 한 번만 선택하세요."
            )
            (swcad-title-princ-line
              "주의: GMTITLE 창 기본값이나 키보드 자동 입력 결과를 믿지 말고, 아래 선택값을 눈으로 확인하세요."
            )
            (setq interactive-result
              (vl-catch-all-apply
                'swcad-title-run-native-gmtitle
                (list frame-block placement-point)
              )
            )
            (if (vl-catch-all-error-p interactive-result)
              (progn
                (setq interactive-error (vl-catch-all-error-message interactive-result))
                (setq *swcad-title-last-native-gmtitle-abort-reason*
                  "INTERACTIVE_GMTITLE_EXCEPTION"
                )
                (swcad-title-princ-line
                  (strcat
                    "대화식 GMTITLE 실행 중 예외가 발생해 변환을 중단합니다: "
                    interactive-error
                  )
                )
                (swcad-title-princ-line
                  "기존 SOLIDWORKS 표제란/도면틀 내용은 삭제하지 않았습니다."
                )
                (swcad-title-cancel-active-command)
                (list nil nil nil)
              )
              interactive-result
            )
          )
        )
      )
    )
  )
)

(defun swcad-title-print-gmtitle-dialog-selection-card (frame-block placement-point)
  (swcad-title-princ-line "GMTITLE 선택 카드:")
  (swcad-title-princ-line (strcat "  용지/도면틀: " (swcad-title-string frame-block)))
  (swcad-title-princ-line (strcat "  제목블록: " (swcad-title-target-title-block-name)))
  (swcad-title-princ-line "  켜둘 옵션: Frame positioning")
  (swcad-title-princ-line "  꺼둘 옵션: Object move")
  (if placement-point
    (progn
      (swcad-title-princ-line
        (strcat
          "  왼쪽 아래 배치점: "
          (swcad-title-point-string placement-point)
        )
      )
      (swcad-title-princ-line "  GstarCAD가 GMTITLE 중앙에 임시 커서 핸들을 보여도 실제 기준은 위 왼쪽 아래 배치점입니다.")
      (swcad-title-princ-line "  GstarCAD가 삽입점을 묻는 경우 위의 왼쪽 아래 배치점을 사용하세요.")
      (swcad-title-princ-line "  GstarCAD가 객체/새 위치를 묻는 경우 취소하고 Object move를 OFF로 바꾸세요. 그렇지 않으면 도면 내용이 이동할 수 있습니다.")
    )
    (swcad-title-princ-line "  가능하면 기본 배치를 유지하세요. 이 LSP가 이후 GMTITLE 쌍을 정렬합니다.")
  )
  (swcad-title-princ-line "  취소 조건: ISO 용지, ISO 제목블록, Object move ON, 예상과 다른 DR 용지가 보이면 확인하지 말고 취소하세요.")
)

(defun swcad-title-run-native-gmtitle (frame-block placement-point / before-handles new-enames title-ename frame-ename guard prompt placement-used old-osmode old-dynmode current-new-enames autoselect-started)
  (setq before-handles (swcad-title-insert-handle-list))
  (setq *swcad-title-last-native-gmtitle-abort-reason* nil)
  (setq *swcad-title-last-native-gmtitle-placement-used* nil)
  (swcad-title-princ-line
    (strcat
      "native GMTITLE을 시작합니다. GMTITLE 창에서 "
      (swcad-title-string frame-block)
      " 용지와 "
      (swcad-title-target-title-block-name)
      " 제목블록을 선택한 뒤 확인하세요."
    )
  )
  (swcad-title-print-gmtitle-dialog-selection-card frame-block placement-point)
  (setq autoselect-started (swcad-title-start-gmtitle-dialog-autoselect frame-block))
  (if autoselect-started
    (swcad-title-princ-line "  화면 좌표를 사용하지 않고 GMTITLE 고정 컨트롤 ID로 선택값을 자동 적용합니다.")
    (swcad-title-princ-line "  자동 선택기를 사용할 수 없어 GMTITLE 창의 선택값을 사람이 확인해야 합니다.")
  )
  (swcad-title-princ-line "이 명령은 FILEDIA와 CMDDIA를 변경하지 않습니다.")
  (setq old-osmode (swcad-title-safe-getvar "OSMODE"))
  (setq old-dynmode (swcad-title-safe-getvar "DYNMODE"))
  (if old-osmode
    (swcad-title-safe-setvar "OSMODE" 0)
  )
  (if old-osmode
    (swcad-title-princ-line "  GMTITLE 배치 중 객체 스냅을 임시로 껐으며, 이후 복원합니다.")
  )
  (initdia)
  (command "GMTITLE")
  (setq guard 0)
  (setq placement-used nil)
  (while (and (> (getvar "CMDACTIVE") 0) (< guard 200))
    (setq prompt (swcad-title-command-prompt-string))
    (setq current-new-enames (swcad-title-new-insert-enames before-handles))
    (cond
      ((and
         placement-point
         (not placement-used)
         (swcad-title-gmtitle-placement-prompt-p prompt)
       )
        (swcad-title-princ-line
          (strcat
            "GMTITLE 배치 프롬프트에 왼쪽 아래 점을 자동 입력합니다: "
            (swcad-title-point-string placement-point)
          )
        )
        (command placement-point)
        (setq placement-used T)
      )
      ((and
         placement-point
         (not placement-used)
         (= (strlen (vl-string-trim " \t\r\n" (swcad-title-string prompt))) 0)
       )
        (swcad-title-princ-line
          (strcat
            "GMTITLE 활성 배치 상태에 왼쪽 아래 점을 자동 입력합니다: "
            (swcad-title-point-string placement-point)
          )
        )
        (if (> (strlen (vl-string-trim " \t\r\n" (swcad-title-string prompt))) 0)
          (swcad-title-princ-line
            (strcat "  당시 프롬프트: " (swcad-title-string prompt))
          )
          (swcad-title-princ-line "  프롬프트 문구가 비어 있어 command pause 전에 배치점 fallback을 사용합니다.")
        )
        (command placement-point)
        (setq placement-used T)
      )
      ((and
         current-new-enames
         (not (swcad-title-gmtitle-placement-prompt-p prompt))
         (swcad-title-gmtitle-object-move-prompt-p prompt)
       )
        (setq *swcad-title-last-native-gmtitle-abort-reason*
          "OBJECT_MOVE_PROMPT_CANCELLED_AFTER_GMTITLE_CREATED"
        )
        (swcad-title-princ-line
          "도면틀/제목블록 생성 후 GMTITLE 객체/새 위치 프롬프트가 감지되어, 도면 내용이 이동하지 않도록 취소합니다."
        )
        (swcad-title-princ-line
          (strcat "  당시 프롬프트: " (swcad-title-string prompt))
        )
        (swcad-title-cancel-active-command)
        (setq guard 200)
      )
      ((and
         current-new-enames
         placement-used
         (= (strlen (vl-string-trim " \t\r\n" (swcad-title-string prompt))) 0)
       )
        (setq *swcad-title-last-native-gmtitle-abort-reason*
          "POST_INSERT_EMPTY_PROMPT_CANCELLED_AFTER_GMTITLE_CREATED"
        )
        (swcad-title-princ-line
          "도면틀/제목블록 생성 후 후속 프롬프트가 비어 있어 도면 내용 이동을 막기 위해 자동 취소합니다."
        )
        (swcad-title-cancel-active-command)
        (setq guard 200)
      )
      ((and
         current-new-enames
         (not (swcad-title-gmtitle-placement-prompt-p prompt))
         (> (strlen (vl-string-trim " \t\r\n" (swcad-title-string prompt))) 0)
       )
        (setq *swcad-title-last-native-gmtitle-abort-reason*
          "POST_INSERT_PROMPT_CANCELLED_AFTER_GMTITLE_CREATED"
        )
        (swcad-title-princ-line
          "도면틀/제목블록 생성 후 추가 GMTITLE 프롬프트가 감지되어, 좌표를 추측하지 않고 취소합니다."
        )
        (swcad-title-princ-line
          (strcat "  당시 프롬프트: " (swcad-title-string prompt))
        )
        (swcad-title-cancel-active-command)
        (setq guard 200)
      )
      (T
        (command "\\")
      )
    )
    (setq guard (+ guard 1))
  )
  (swcad-title-restore-gmtitle-input-vars old-osmode old-dynmode)
  (if (and placement-point (not placement-used))
    (swcad-title-princ-line "삽입점 프롬프트가 감지되지 않아 왼쪽 아래 자동 배치점을 보내지 않았습니다. 나중에 이동해야 하는 native GMTITLE은 GMPOWEREDIT/더블클릭 완료로 인정하지 않습니다.")
  )
  (setq *swcad-title-last-native-gmtitle-placement-used* placement-used)
  (setq new-enames (swcad-title-new-insert-enames before-handles))
  (if
    (and
      new-enames
      (swcad-title-native-gmtitle-post-prompt-abort-p *swcad-title-last-native-gmtitle-abort-reason*)
      (not (swcad-title-native-gmtitle-post-prompt-acceptable-p *swcad-title-last-native-gmtitle-abort-reason*))
    )
    (progn
      (swcad-title-princ-line
        (strcat
          "GMTITLE 추가 프롬프트 취소 상태이므로 새 INSERT를 성공으로 보지 않고 삭제합니다. 이유="
          (swcad-title-string *swcad-title-last-native-gmtitle-abort-reason*)
        )
      )
      (swcad-title-princ-line
        (strcat
          "삭제한 부분 생성 GMTITLE INSERT: "
          (itoa (swcad-title-delete-ename-list new-enames))
        )
      )
      (setq new-enames nil)
    )
  )
  (setq title-ename (swcad-title-select-new-gmtitle-title new-enames))
  (setq frame-ename (swcad-title-select-new-gmtitle-frame new-enames title-ename frame-block))
  (list title-ename frame-ename new-enames)
)

(defun swcad-title-insert-log-label (label ename / data)
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (swcad-title-princ-line
        (strcat
          label
          ": handle="
          (swcad-title-string (swcad-title-dxf-value data 5))
          ", block="
          (swcad-title-effective-insert-name ename)
          ", bbox="
          (swcad-title-bbox-string (swcad-title-safe-bbox ename))
        )
      )
    )
    (swcad-title-princ-line (strcat label ": <none>"))
  )
)

(defun swcad-title-print-basic-entity (ename data / object object-name)
  (setq object (swcad-title-safe-vla-object ename))
  (setq object-name (swcad-title-safe-vla-get object 'ObjectName))
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 DEBUG BASIC -----")
  (swcad-title-princ-line (strcat "entity type: " (swcad-title-string (swcad-title-dxf-value data 0))))
  (swcad-title-princ-line (strcat "handle: " (swcad-title-string (swcad-title-dxf-value data 5))))
  (swcad-title-princ-line (strcat "layer: " (swcad-title-string (swcad-title-dxf-value data 8))))
  (swcad-title-princ-line (strcat "block name: " (swcad-title-string (swcad-title-dxf-value data 2))))
  (swcad-title-princ-line (strcat "vla object: " (swcad-title-string object-name)))
)

(defun swcad-title-print-data-section (title data / pair)
  (swcad-title-princ-line title)
  (foreach pair data
    (swcad-title-code-value-line "  DXF" pair)
  )
)

(defun swcad-title-print-xdata (ename / xdata pair)
  (setq xdata (entget ename '("*")))
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 DEBUG XDATA / RAW ENTGET -----")
  (if xdata
    (foreach pair xdata
      (swcad-title-code-value-line "  DXF" pair)
    )
    (swcad-title-princ-line "  No entget data returned.")
  )
)

(defun swcad-title-print-insert-attributes (ename / next edata etype count)
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 DEBUG ATTRIBUTES -----")
  (setq count 0)
  (foreach edata (swcad-title-insert-attributes ename)
    (setq count (+ count 1))
    (swcad-title-princ-line "  ATTRIBUTE")
    (swcad-title-princ-line (strcat "    tag: " (swcad-title-string (swcad-title-dxf-value edata 2))))
    (swcad-title-princ-line (strcat "    value: " (swcad-title-string (swcad-title-dxf-value edata 1))))
    (swcad-title-princ-line (strcat "    layer: " (swcad-title-string (swcad-title-dxf-value edata 8))))
    (swcad-title-princ-line (strcat "    handle: " (swcad-title-string (swcad-title-dxf-value edata 5))))
  )
  (if (= count 0)
    (progn
      (swcad-title-princ-line "  No following attributes.")
      (swcad-title-princ-line "  No attributes found.")
    )
  )
)

(defun swcad-title-debug-entity (ename / data etype)
  (swcad-title-open-debug-log)
  (setq data (entget ename))
  (setq etype (swcad-title-dxf-value data 0))
  (swcad-title-print-basic-entity ename data)
  (if (= etype "INSERT")
    (swcad-title-print-insert-attributes ename)
    (progn
      (swcad-title-princ-line "----- SWTITLESTATUS 내부 DEBUG ATTRIBUTES -----")
      (swcad-title-princ-line "  Selected entity is not an INSERT.")
    )
  )
  (swcad-title-print-data-section "----- SWTITLESTATUS 내부 DEBUG ENTGET -----" data)
  (swcad-title-print-xdata ename)
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 DEBUG END -----")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-first-implied-selection (/ result ss)
  (setq result (vl-catch-all-apply 'ssget (list "_I")))
  (if (vl-catch-all-error-p result)
    nil
    (progn
      (setq ss result)
      (if (and ss (> (sslength ss) 0))
        (ssname ss 0)
        nil
      )
    )
  )
)

(defun swcad-title-scale-not-ready (command)
  (princ (strcat "\n" command "는 읽기 전용 표제란/축척 진단용으로 예약된 명령입니다."))
  (princ "\n구현 계획:")
  (princ "\n  1. GMTITLE / ~FTAP 표제란 축척 후보를 읽습니다.")
  (princ "\n  2. 치수 객체별 DIMLFAC override 값을 비교합니다.")
  (princ "\n  3. 원본 치수 스타일 DIMLFAC 값을 비교합니다.")
  (princ "\n  4. OK, MIXED, MISSING, CONFLICT, SUSPECT 중 하나로 보고합니다.")
  (princ "\n도면 데이터는 변경하지 않았습니다.")
  (princ)
)

(defun swcad-title-print-candidate (edata attr / tag value)
  (setq tag (swcad-title-dxf-value attr 2))
  (setq value (swcad-title-dxf-value attr 1))
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (swcad-title-dxf-value edata 5))
      ", layout="
      (swcad-title-string (swcad-title-dxf-value edata 410))
      ", block="
      (swcad-title-string (swcad-title-dxf-value edata 2))
      ", layer="
      (swcad-title-string (swcad-title-dxf-value edata 8))
      ", tag="
      (swcad-title-string tag)
      ", value="
      (swcad-title-string value)
      ", insert="
      (swcad-title-string (swcad-title-dxf-value edata 10))
    )
  )
)

(defun swcad-title-scan-insert (ename / edata attrs attr block found scale-count)
  (setq edata (entget ename '("*")))
  (setq attrs (swcad-title-insert-attributes ename))
  (setq block (swcad-title-dxf-value edata 2))
  (setq found nil)
  (setq scale-count 0)
  (foreach attr attrs
    (if (swcad-title-scale-tag-p (swcad-title-dxf-value attr 2))
      (progn
        (if (not found)
          (progn
            (setq found T)
            (setq *swcad-title-scan-title-insert-count* (+ *swcad-title-scan-title-insert-count* 1))
          )
        )
        (setq scale-count (+ scale-count 1))
        (setq *swcad-title-scan-scale-count* (+ *swcad-title-scan-scale-count* 1))
        (setq
          *swcad-title-scan-scale-values*
          (swcad-title-list-add-unique
            (swcad-title-string (swcad-title-dxf-value attr 1))
            *swcad-title-scan-scale-values*
          )
        )
        (swcad-title-print-candidate edata attr)
      )
    )
  )
  (if (and (swcad-title-title-block-name-p block) (= scale-count 0))
    (swcad-title-princ-line
      (strcat
        "  - handle="
        (swcad-title-string (swcad-title-dxf-value edata 5))
        ", layout="
        (swcad-title-string (swcad-title-dxf-value edata 410))
        ", block="
        (swcad-title-string block)
        ", scale=<missing>"
      )
    )
  )
  scale-count
)

(defun swcad-title-text-entity-value (data / result pair code value)
  (setq result "")
  (foreach pair data
    (setq code (car pair))
    (setq value (cdr pair))
    (if (and (or (= code 1) (= code 3)) (swcad-title-string-p value))
      (setq result (strcat result value))
    )
  )
  result
)

(defun swcad-title-print-text-candidate (edata scale-value raw-text)
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (swcad-title-dxf-value edata 5))
      ", layout="
      (swcad-title-string (swcad-title-dxf-value edata 410))
      ", type="
      (swcad-title-string (swcad-title-dxf-value edata 0))
      ", layer="
      (swcad-title-string (swcad-title-dxf-value edata 8))
      ", value="
      (swcad-title-string scale-value)
      ", insert="
      (swcad-title-string (swcad-title-dxf-value edata 10))
      ", text=\""
      (swcad-title-string raw-text)
      "\""
    )
  )
)

(defun swcad-title-scan-text-entity (ename / edata raw-text scale-value)
  (setq edata (entget ename '("*")))
  (setq raw-text (swcad-title-text-entity-value edata))
  (setq scale-value (swcad-title-scale-text-candidate raw-text))
  (if scale-value
    (progn
      (setq *swcad-title-scan-loose-scale-count* (+ *swcad-title-scan-loose-scale-count* 1))
      (setq
        *swcad-title-scan-scale-values*
        (swcad-title-list-add-unique
          scale-value
          *swcad-title-scan-scale-values*
        )
      )
      (swcad-title-print-text-candidate edata scale-value raw-text)
      1
    )
    0
  )
)

(defun swcad-title-scan-loose-texts (/ ss index total ename)
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq total (if ss (sslength ss) 0))
  (setq *swcad-title-scan-loose-text-count* total)
  (swcad-title-princ-line (strcat "TEXT/MTEXT count: " (itoa total)))
  (swcad-title-princ-line "Loose text scale candidates:")
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (swcad-title-scan-text-entity ename)
    (setq index (+ index 1))
  )
  (if (= *swcad-title-scan-loose-scale-count* 0)
    (swcad-title-princ-line "  <none>")
  )
  *swcad-title-scan-loose-scale-count*
)

(defun swcad-title-command-text-residue-p (raw-text / upper trimmed)
  (setq trimmed (vl-string-trim " \t\r\n" (swcad-title-string raw-text)))
  (setq upper (strcase trimmed))
  (or
    (and
      (vl-string-search "(LOAD" upper)
      (vl-string-search "SWCAD_TITLE_SCALE.LSP" upper)
    )
    (wcmatch upper "SWTITLE*")
    (wcmatch upper "*SWTITLE LOG:*")
    (and
      (vl-string-search "APPLOAD" upper)
      (vl-string-search "SWCAD_TITLE_SCALE.LSP" upper)
    )
  )
)

(defun swcad-title-command-text-residue-records (/ ss index total ename data raw-text records)
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq records nil)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq raw-text (swcad-title-text-entity-value data))
    (if (swcad-title-command-text-residue-p raw-text)
      (setq records (append records (list (list ename data raw-text))))
    )
    (setq index (+ index 1))
  )
  records
)

(defun swcad-title-command-text-residue-count ()
  (length (swcad-title-command-text-residue-records))
)

(defun swcad-title-print-command-text-record (record / data raw-text)
  (setq data (cadr record))
  (setq raw-text (caddr record))
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (swcad-title-dxf-value data 5))
      ", type="
      (swcad-title-string (swcad-title-dxf-value data 0))
      ", layer="
      (swcad-title-string (swcad-title-dxf-value data 8))
      ", point="
      (swcad-title-point-string (swcad-title-dxf-value data 10))
      ", text=\""
      (swcad-title-string raw-text)
      "\""
    )
  )
)

(defun swcad-title-command-text-scan (/ ss total records count record)
  (swcad-title-open-command-text-log)
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 명령어 텍스트 잔여물 확인(읽기 전용) -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq total (if ss (sslength ss) 0))
  (setq records (swcad-title-command-text-residue-records))
  (setq count (length records))
  (swcad-title-princ-line (strcat "TEXT/MTEXT count: " (itoa total)))
  (swcad-title-princ-line "Possible accidental command text entities:")
  (foreach record records
    (swcad-title-print-command-text-record record)
  )
  (if (= count 0)
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-princ-line (strcat "Possible accidental command text count: " (itoa count)))
  (if (> count 0)
    (progn
      (swcad-title-princ-line "Result: WARN_ACCIDENTAL_COMMAND_TEXT_FOUND")
      (swcad-title-princ-line "No drawing data was changed. Remove these only in a work copy after confirming they are not real drawing notes.")
    )
    (swcad-title-princ-line "Result: OK_NO_ACCIDENTAL_COMMAND_TEXT_FOUND")
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-command-text-clean-safe (/ records count record answer doc deleted)
  (swcad-title-open-command-text-log)
  (swcad-title-princ-line "----- SWTITLEPREPARE 내부 실수 명령어 텍스트 안전 정리 -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq records (swcad-title-command-text-residue-records))
  (setq count (length records))
  (swcad-title-princ-line "Possible accidental command text entities:")
  (foreach record records
    (swcad-title-print-command-text-record record)
  )
  (swcad-title-princ-line (strcat "Possible accidental command text count: " (itoa count)))
  (cond
    ((= count 0)
      (swcad-title-princ-line "  <none>")
      (swcad-title-apply-result "OK_NO_ACCIDENTAL_COMMAND_TEXT_FOUND")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before cleaning command text.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Command text cleanup is limited to Documents/CAD tool/work copies.")
    )
    (T
      (setq answer
        (getstring
          T
          "\n이 작업복사본에서 실수로 들어간 명령어 TEXT/MTEXT 객체를 삭제하려면 YES를 입력하세요: "
        )
      )
      (if (/= (strcase answer) "YES")
        (swcad-title-apply-result "ABORT_COMMAND_TEXT_CLEAN_USER")
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq deleted 0)
          (foreach record records
            (if (swcad-title-delete-ename (car record))
              (setq deleted (+ deleted 1))
            )
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line (strcat "실수로 들어간 명령어 텍스트 삭제: " (itoa deleted)))
          (swcad-title-apply-result "OK_COMMAND_TEXT_CLEANED")
          (swcad-title-princ-line "다음: SWTITLESTATUS를 다시 실행하세요.")
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-text-record-less-p (a b)
  (if (equal (car a) (car b) 1e-8)
    (< (cadr a) (cadr b))
    (> (car a) (car b))
  )
)

(defun swcad-title-text-record (edata raw-text / point scale-value)
  (setq point (swcad-title-dxf-value edata 10))
  (setq scale-value (swcad-title-scale-text-candidate raw-text))
  (list
    (if (and point (cadr point)) (cadr point) 0.0)
    (if (and point (car point)) (car point) 0.0)
    (swcad-title-dxf-value edata 0)
    (swcad-title-dxf-value edata 5)
    (swcad-title-dxf-value edata 8)
    point
    raw-text
    scale-value
  )
)

(defun swcad-title-point-z (point)
  (if (and (listp point) (caddr point))
    (caddr point)
    0.0
  )
)

(defun swcad-title-number-or-default (value default)
  (if (numberp value) value default)
)

(defun swcad-title-transform-block-point (point insert-data block-base / insert-point sx sy rot local-x local-y scaled-x scaled-y cosv sinv)
  (setq insert-point (swcad-title-dxf-value insert-data 10))
  (setq sx (swcad-title-number-or-default (swcad-title-dxf-value insert-data 41) 1.0))
  (setq sy (swcad-title-number-or-default (swcad-title-dxf-value insert-data 42) 1.0))
  (setq rot (swcad-title-number-or-default (swcad-title-dxf-value insert-data 50) 0.0))
  (setq local-x (- (car point) (car block-base)))
  (setq local-y (- (cadr point) (cadr block-base)))
  (setq scaled-x (* local-x sx))
  (setq scaled-y (* local-y sy))
  (setq cosv (cos rot))
  (setq sinv (sin rot))
  (list
    (+ (car insert-point) (- (* scaled-x cosv) (* scaled-y sinv)))
    (+ (cadr insert-point) (+ (* scaled-x sinv) (* scaled-y cosv)))
    (+ (swcad-title-point-z insert-point) (swcad-title-point-z point))
  )
)

(defun swcad-title-block-text-records (insert-ename bbox / insert-data block-name block-data block-base block-obj ename edata etype raw-text local-point world-point expanded-bbox source-handle record records guard)
  (setq records nil)
  (setq insert-data (entget insert-ename '("*")))
  (setq block-name (swcad-title-dxf-value insert-data 2))
  (setq block-data (tblsearch "BLOCK" block-name))
  (setq block-base (if block-data (swcad-title-dxf-value block-data 10) nil))
  (if (not block-base)
    (setq block-base '(0.0 0.0 0.0))
  )
  (setq block-obj (tblobjname "BLOCK" block-name))
  (setq expanded-bbox (swcad-title-expand-bbox bbox 2.0))
  (setq source-handle (swcad-title-string (swcad-title-dxf-value insert-data 5)))
  (if block-obj
    (progn
      (setq ename (entnext block-obj))
      (setq guard 0)
      (while (and ename (< guard 2000))
        (setq edata (entget ename '("*")))
        (setq etype (strcase (swcad-title-string (swcad-title-dxf-value edata 0))))
        (cond
          ((equal etype "ENDBLK")
            (setq ename nil)
          )
          ((member etype '("TEXT" "MTEXT"))
            (setq raw-text (swcad-title-text-entity-value edata))
            (setq local-point (swcad-title-dxf-value edata 10))
            (if (and
                  raw-text
                  (> (strlen raw-text) 0)
                  local-point
                )
              (progn
                (setq world-point
                  (swcad-title-transform-block-point local-point insert-data block-base)
                )
                (if (or (not expanded-bbox) (swcad-title-point-in-bbox-p world-point expanded-bbox))
                  (progn
                    (setq edata (swcad-title-dxf-put edata 10 world-point))
                    (setq edata
                      (swcad-title-dxf-put
                        edata
                        5
                        (strcat
                          "BLOCK:"
                          source-handle
                          ":"
                          (swcad-title-string (swcad-title-dxf-value edata 5))
                        )
                      )
                    )
                    (setq record (swcad-title-text-record edata raw-text))
                    (setq records (append records (list record)))
                  )
                )
              )
            )
          )
        )
        (if ename
          (setq ename (entnext ename))
        )
        (setq guard (+ guard 1))
      )
    )
  )
  records
)

(defun swcad-title-print-text-record (record)
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (nth 3 record))
      ", type="
      (swcad-title-string (nth 2 record))
      ", layer="
      (swcad-title-string (nth 4 record))
      ", point="
      (swcad-title-point-string (nth 5 record))
      (if (nth 7 record)
        (strcat ", scale-candidate=" (swcad-title-string (nth 7 record)))
        ""
      )
      ", text=\""
      (swcad-title-string (nth 6 record))
      "\""
    )
  )
)

(defun swcad-title-print-attribute-record (insert-data attr-data / tag value point)
  (setq tag (swcad-title-dxf-value attr-data 2))
  (setq value (swcad-title-dxf-value attr-data 1))
  (setq point (swcad-title-dxf-value attr-data 10))
  (swcad-title-princ-line
    (strcat
      "    - attr-handle="
      (swcad-title-string (swcad-title-dxf-value attr-data 5))
      ", tag="
      (swcad-title-string tag)
      ", value=\""
      (swcad-title-string value)
      "\""
      ", layer="
      (swcad-title-string (swcad-title-dxf-value attr-data 8))
      ", point="
      (swcad-title-point-string point)
    )
  )
)

(defun swcad-title-scan-title-texts (/ insert-ss insert-index insert-total text-ss text-index text-total ename data block attrs attr-data attr-count title-like bbox bboxes title-insert-count attribute-count text-records raw-text point records-in-bounds record)
  (swcad-title-open-text-log)
  (setq title-insert-count 0)
  (setq attribute-count 0)
  (setq bboxes nil)
  (setq text-records nil)
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 표제란 텍스트 스캔(읽기 전용) -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))

  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (swcad-title-princ-line (strcat "INSERT count: " (itoa insert-total)))
  (swcad-title-princ-line "Title-like inserts and attributes:")
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (setq data (entget ename '("*")))
    (setq block (swcad-title-dxf-value data 2))
    (setq attrs (swcad-title-insert-attributes ename))
    (setq attr-count (length attrs))
    (setq title-like (swcad-title-title-block-name-p block))
    (if (or title-like (> attr-count 0))
      (progn
        (setq title-insert-count (+ title-insert-count 1))
        (setq bbox (swcad-title-safe-bbox ename))
        (if title-like
          (setq bboxes (append bboxes (list (swcad-title-expand-bbox bbox 2.0))))
        )
        (swcad-title-princ-line
          (strcat
            "  - insert-handle="
            (swcad-title-string (swcad-title-dxf-value data 5))
            ", block="
            (swcad-title-string block)
            ", layer="
            (swcad-title-string (swcad-title-dxf-value data 8))
            ", insert="
            (swcad-title-point-string (swcad-title-dxf-value data 10))
            ", bbox="
            (swcad-title-bbox-string bbox)
            ", attributes="
            (itoa attr-count)
          )
        )
        (foreach attr-data attrs
          (setq attribute-count (+ attribute-count 1))
          (swcad-title-print-attribute-record data attr-data)
        )
        (if (= attr-count 0)
          (swcad-title-princ-line "    <no attributes>")
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  (if (= title-insert-count 0)
    (swcad-title-princ-line "  <none>")
  )

  (setq text-ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq text-total (if text-ss (sslength text-ss) 0))
  (setq text-index 0)
  (while (< text-index text-total)
    (setq ename (ssname text-ss text-index))
    (setq data (entget ename '("*")))
    (setq raw-text (swcad-title-text-entity-value data))
    (setq point (swcad-title-dxf-value data 10))
    (if (and raw-text (> (strlen raw-text) 0))
      (setq text-records
        (append text-records (list (swcad-title-text-record data raw-text)))
      )
    )
    (setq text-index (+ text-index 1))
  )
  (setq text-records (vl-sort text-records 'swcad-title-text-record-less-p))
  (setq records-in-bounds nil)
  (foreach record text-records
    (if (or (not bboxes) (swcad-title-point-in-bboxes-p (nth 5 record) bboxes))
      (setq records-in-bounds (append records-in-bounds (list record)))
    )
  )

  (swcad-title-princ-line (strcat "TEXT/MTEXT count: " (itoa text-total)))
  (if bboxes
    (swcad-title-princ-line "Loose TEXT/MTEXT inside title-block bounds:")
    (swcad-title-princ-line "Loose TEXT/MTEXT records:")
  )
  (if records-in-bounds
    (foreach record records-in-bounds
      (swcad-title-print-text-record record)
    )
    (swcad-title-princ-line "  <none>")
  )

  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line (strcat "  title-like inserts: " (itoa title-insert-count)))
  (swcad-title-princ-line (strcat "  attributes listed: " (itoa attribute-count)))
  (swcad-title-princ-line (strcat "  loose text records listed: " (itoa (length records-in-bounds))))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-source-title-same-row-p (a-bbox b-bbox / tolerance)
  (setq tolerance
    (* 0.10
      (max
        (swcad-title-bbox-height a-bbox)
        (swcad-title-bbox-height b-bbox)
        1.0
      )
    )
  )
  (<= (swcad-title-abs (- (cadddr a-bbox) (cadddr b-bbox))) tolerance)
)

(defun swcad-title-source-title-candidate-less-p (a b / a-bbox b-bbox)
  (setq a-bbox (caddr a))
  (setq b-bbox (caddr b))
  (if (swcad-title-source-title-same-row-p a-bbox b-bbox)
    (< (car a-bbox) (car b-bbox))
    (> (cadddr a-bbox) (cadddr b-bbox))
  )
)

(defun swcad-title-source-frame-candidate-less-p (a b / a-bbox b-bbox)
  (setq a-bbox (caddr a))
  (setq b-bbox (caddr b))
  (if (swcad-title-source-title-same-row-p a-bbox b-bbox)
    (< (car a-bbox) (car b-bbox))
    (> (cadddr a-bbox) (cadddr b-bbox))
  )
)

(defun swcad-title-source-title-insert-candidates (/ insert-ss insert-index insert-total ename data block bbox area result)
  (setq result nil)
  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (setq data (entget ename '("*")))
    (setq block (swcad-title-effective-insert-name ename))
    (if
      (and
        (swcad-title-title-block-name-p block)
        (not (swcad-title-native-target-title-name-p block))
      )
      (progn
        (setq bbox (swcad-title-safe-bbox ename))
        (setq area (swcad-title-bbox-area bbox))
        (if (and bbox (> area 10.0))
          (setq result (append result (list (list ename data bbox block area))))
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  (vl-sort result 'swcad-title-source-title-candidate-less-p)
)

(defun swcad-title-loose-title-region-bbox (frame-bbox / width height)
  (setq width (swcad-title-bbox-width frame-bbox))
  (setq height (swcad-title-bbox-height frame-bbox))
  (if (and frame-bbox (>= width 200.0) (>= height 62.0))
    (list
      (- (caddr frame-bbox) 190.0)
      (+ (cadr frame-bbox) 10.0)
      (- (caddr frame-bbox) 10.0)
      (+ (cadr frame-bbox) 52.0)
    )
    nil
  )
)

(defun swcad-title-mapping-anchor-count (mappings / count tag)
  (setq count 0)
  (foreach tag
    '(
      "GEN-TITLE-NAME{10}"
      "GEN-TITLE-SCA{6.7}"
      "GEN-TITLE-DWG{23}"
      "GEN-TITLE-NR{23}"
      "GEN-TITLE-SIZ{6.7}"
    )
    (if (assoc tag mappings)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-mapping-preview-value (mappings tag / pair preview)
  (setq pair (assoc tag mappings))
  (setq preview (if pair (cdr pair) nil))
  (if preview
    (swcad-title-string (nth 2 preview))
    ""
  )
)

(defun swcad-title-loose-title-build-valid-p (build frame-sheet / mappings mapped-count duplicate-count mapped-sheet)
  (setq mappings (if build (car build) nil))
  (setq mapped-count (if build (nth 4 build) 0))
  (setq duplicate-count (if build (nth 6 build) 0))
  (setq mapped-sheet
    (swcad-title-normalized-sheet-size
      (swcad-title-mapping-preview-value mappings "GEN-TITLE-SIZ{6.7}")
    )
  )
  (and
    (>= mapped-count 6)
    (>= (swcad-title-mapping-anchor-count mappings) 4)
    (= duplicate-count 0)
    mapped-sheet
    (equal
      mapped-sheet
      (swcad-title-normalized-sheet-size frame-sheet)
    )
  )
)

(defun swcad-title-loose-title-source-candidates (insert-sources / frames result frame frame-bbox title-bbox build)
  (setq frames (swcad-title-source-frame-candidates))
  (setq result nil)
  (foreach frame frames
    (setq frame-bbox (caddr frame))
    (if (not (swcad-title-frame-has-source-title-p frame-bbox insert-sources))
      (progn
        (setq title-bbox (swcad-title-loose-title-region-bbox frame-bbox))
        (setq build
          (if title-bbox
            (swcad-title-transfer-build-mappings title-bbox nil 7.0)
            nil
          )
        )
        (if (swcad-title-loose-title-build-valid-p build (nth 5 frame))
          (setq result
            (append
              result
              (list
                (list
                  nil
                  nil
                  title-bbox
                  "SWTITLE_LOOSE_TEXT"
                  (swcad-title-bbox-area title-bbox)
                  "loose-text"
                  (car frame)
                  (cadr frame)
                  (cadddr frame)
                  (nth 5 frame)
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-source-title-kind (source)
  (if (and source (nth 5 source))
    (swcad-title-string (nth 5 source))
    "block-attributes"
  )
)

(defun swcad-title-source-title-candidates (/ insert-sources loose-sources)
  (setq insert-sources (swcad-title-source-title-insert-candidates))
  (setq loose-sources (swcad-title-loose-title-source-candidates insert-sources))
  (vl-sort (append insert-sources loose-sources) 'swcad-title-source-title-candidate-less-p)
)

(defun swcad-title-source-frame-candidates (/ insert-ss insert-index insert-total ename data block bbox area sheet result)
  (setq result nil)
  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (setq data (entget ename '("*")))
    (setq block (swcad-title-effective-insert-name ename))
    (setq sheet (swcad-title-sheet-size-from-block-name block))
    (if
      (and
        sheet
        (not (swcad-title-native-target-frame-name-p block))
        (not (swcad-title-native-target-title-name-p block))
      )
      (progn
        (setq bbox (swcad-title-safe-bbox ename))
        (setq area (swcad-title-bbox-area bbox))
        (if (and bbox (> area 1000.0))
          (setq result (append result (list (list ename data bbox block area sheet))))
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  (vl-sort result 'swcad-title-source-frame-candidate-less-p)
)

(defun swcad-title-frame-has-source-title-p (frame-bbox sources / found source)
  (setq found nil)
  (foreach source sources
    (if
      (and
        (not found)
        frame-bbox
        (swcad-title-bbox-contains-bbox-p frame-bbox (caddr source) 2.0)
      )
      (setq found T)
    )
  )
  found
)

(defun swcad-title-frame-only-source-candidates (/ frames sources result frame)
  (setq frames (swcad-title-source-frame-candidates))
  (setq sources (swcad-title-source-title-candidates))
  (setq result nil)
  (foreach frame frames
    (if (not (swcad-title-frame-has-source-title-p (caddr frame) sources))
      (setq result (append result (list frame)))
    )
  )
  result
)

(defun swcad-title-frame-only-source-for-frame-block (frame-block / target-sheet frames found frame)
  (setq target-sheet (swcad-title-sheet-size-from-block-name frame-block))
  (setq frames (swcad-title-frame-only-source-candidates))
  (setq found nil)
  (foreach frame frames
    (if
      (and
        (not found)
        target-sheet
        (equal
          (swcad-title-normalized-sheet-size (nth 5 frame))
          (swcad-title-normalized-sheet-size target-sheet)
        )
      )
      (setq found frame)
    )
  )
  (if found
    found
    (car frames)
  )
)

(defun swcad-title-title-missing-outline-risk-message (source-frame frame-block / bbox sheet width height long-edge short-edge dims expected-long expected-short)
  (setq sheet (if source-frame (nth 5 source-frame) nil))
  (setq bbox (if source-frame (caddr source-frame) nil))
  (setq dims (swcad-title-sheet-dimensions sheet))
  (setq width (swcad-title-bbox-width bbox))
  (setq height (swcad-title-bbox-height bbox))
  (setq long-edge (max width height))
  (setq short-edge (min width height))
  (setq expected-long (if dims (max (car dims) (cadr dims)) nil))
  (setq expected-short (if dims (min (car dims) (cadr dims)) nil))
  (if
    (and
      dims
      (swcad-title-frame-name-matches-p frame-block (swcad-title-target-frame-block-name-for-sheet sheet))
      (swcad-title-near-p long-edge expected-long 2.0)
      (swcad-title-near-p short-edge expected-short 2.0)
      (not (swcad-title-block-exists-p frame-block))
    )
    (strcat
      "CAD 테스트 경고: 이 원본은 "
      (swcad-title-number-string (car dims))
      " x "
      (swcad-title-number-string (cadr dims))
      " "
      (swcad-title-string sheet)
      " title-missing/frame-only 시트인데, 현재 도면 안에 같은 크기 "
      (swcad-title-string frame-block)
      " 기준 정의가 없습니다."
    )
    nil
  )
)

(defun swcad-title-moved-native-placement-allowed-p (source-sheet frame-block)
  (and
    *swcad-title-allow-moved-native-placement-after-geometry-check*
    (swcad-title-normalized-sheet-size source-sheet)
    (swcad-title-frame-name-matches-p
      frame-block
      (swcad-title-target-frame-block-name-for-sheet source-sheet)
    )
  )
)

(defun swcad-title-frame-only-source-for-existing-gmtitle (/ frames frame frame-block found)
  (setq frames (swcad-title-frame-only-source-candidates))
  (setq found nil)
  (foreach frame frames
    (if (not found)
      (progn
        (setq frame-block (swcad-title-target-frame-block-name-for-sheet (nth 5 frame)))
        (if (swcad-title-default-location-gmtitle-frame-for-block frame-block)
          (setq found frame)
        )
      )
    )
  )
  (if found
    found
    (car frames)
  )
)

(defun swcad-title-frame-only-default-values (source-frame / source-block source-sheet target-frame file-base)
  (setq source-block (cadddr source-frame))
  (setq source-sheet (nth 5 source-frame))
  (setq target-frame (swcad-title-target-frame-block-name-for-sheet source-sheet))
  (setq file-base (vl-filename-base (getvar "DWGNAME")))
  (list
    (cons "GEN-TITLE-SIZ{6.7}" (swcad-title-normalized-sheet-size source-sheet))
    (cons "GEN-TITLE-DWG{23}" file-base)
    (cons "GEN-TITLE-NR{23}" "XXX")
    (cons "GEN-TITLE-SCA{6.7}" "1:1")
  )
)

(defun swcad-title-title-missing-outline-frame-record-p (frame-record / frame-ename frame-block frame-bbox sheet role native-link-kinds geometry-warning raw-selection-warning)
  (setq frame-ename (if frame-record (car frame-record) nil))
  (setq frame-block (if frame-record (cadr frame-record) nil))
  (setq frame-bbox (if frame-record (cadddr frame-record) nil))
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (setq role (if frame-ename (swcad-title-exemplar-role frame-ename) ""))
  (setq native-link-kinds (if frame-ename (swcad-title-native-link-target-kinds frame-ename) nil))
  (setq geometry-warning
    (if frame-ename
      (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox)
      "missing-frame"
    )
  )
  (setq raw-selection-warning
    (if frame-ename
      (swcad-title-frame-reference-raw-selection-warning frame-ename frame-block frame-bbox)
      "missing-frame"
    )
  )
  (and
    (swcad-title-normalized-sheet-size sheet)
    (wcmatch (swcad-title-normalized-sheet-size sheet) "A1,A2,A3,A4")
    (swcad-title-frame-name-matches-p frame-block (swcad-title-target-frame-block-name-for-sheet sheet))
    (equal (strcase (swcad-title-string role)) "NATIVE-TITLE-MISSING-OUTLINE")
    (swcad-title-internal-native-link-kinds-p native-link-kinds)
    (not geometry-warning)
    (not raw-selection-warning)
    (not (swcad-title-target-frame-block-contaminated-p frame-block))
  )
)

(defun swcad-title-title-missing-outline-frame-count (/ records count record)
  (setq records (swcad-title-frame-records))
  (setq count 0)
  (foreach record records
    (if (swcad-title-title-missing-outline-frame-record-p record)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-title-missing-outline-with-loose-title-records (/ frame-records result record frame-bbox frame-block sheet title-bbox build)
  (setq frame-records (swcad-title-frame-records))
  (setq result nil)
  (foreach record frame-records
    (if (swcad-title-title-missing-outline-frame-record-p record)
      (progn
        (setq frame-bbox (cadddr record))
        (setq frame-block (cadr record))
        (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
        (setq title-bbox (swcad-title-loose-title-region-bbox frame-bbox))
        (setq build
          (if title-bbox
            (swcad-title-transfer-build-mappings title-bbox nil 7.0)
            nil
          )
        )
        (if (swcad-title-loose-title-build-valid-p build sheet)
          (setq result
            (append
              result
              (list (list record title-bbox (swcad-title-transfer-values (car build))))
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-title-missing-outline-frame-block-present-p (frame-block / records found record)
  (setq records (swcad-title-frame-records))
  (setq found nil)
  (foreach record records
    (if
      (and
        (not found)
        (swcad-title-title-missing-outline-frame-record-p record)
        (swcad-title-frame-name-matches-p (cadr record) frame-block)
      )
      (setq found T)
    )
  )
  found
)

(defun swcad-title-frame-only-title-offset (sheet-size / normalized dims width)
  (setq normalized (swcad-title-normalized-sheet-size sheet-size))
  (setq dims (swcad-title-sheet-dimensions normalized))
  (setq width (if dims (car dims) 210.0))
  (list (max 20.0 (- width 190.0)) 10.0)
)

(defun swcad-title-transfer-source-bbox (/ source)
  (setq source (car (swcad-title-source-title-candidates)))
  (if source
    (list (car source) (cadr source) (caddr source))
    nil
  )
)

(defun swcad-title-source-record-basic (source)
  (if source
    (list (car source) (cadr source) (caddr source))
    nil
  )
)

(defun swcad-title-source-record-frame-block (source / source-ename source-bbox source-block frame frame-bbox frame-block)
  (setq source-ename (car source))
  (setq source-bbox (caddr source))
  (setq source-block (cadddr source))
  (setq frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq frame-bbox (if frame (caddr frame) nil))
  (setq frame-block (if frame (swcad-title-effective-insert-name (car frame)) ""))
  (swcad-title-target-frame-block-name-for-source source-block frame-block nil frame-bbox)
)

(defun swcad-title-transfer-source-for-existing-gmtitle (/ sources source frame-block found)
  (setq sources (swcad-title-source-title-candidates))
  (setq found nil)
  (foreach source sources
    (if (not found)
      (progn
        (setq frame-block (swcad-title-source-record-frame-block source))
        (if (swcad-title-unfinalized-gmtitle-frame-for-block frame-block)
          (setq found source)
        )
      )
    )
  )
  (if found
    (swcad-title-source-record-basic found)
    (swcad-title-transfer-source-bbox)
  )
)

(defun swcad-title-transfer-source-frame (source-bbox source-title-ename / insert-ss insert-index insert-total ename data block bbox area source-area priority best bestarea bestpriority)
  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (setq source-area (swcad-title-bbox-area source-bbox))
  (setq best nil)
  (setq bestarea nil)
  (setq bestpriority nil)
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (if (not (eq ename source-title-ename))
      (progn
        (setq data (entget ename '("*")))
        (setq block (swcad-title-effective-insert-name ename))
        (if (not (swcad-title-native-target-frame-name-p block))
          (progn
            (setq bbox (swcad-title-safe-bbox ename))
            (setq area (swcad-title-bbox-area bbox))
            (if (and
                  bbox
                  (> area (* source-area 2.0))
                  (swcad-title-bbox-contains-bbox-p bbox source-bbox 2.0)
                )
              (progn
                (setq priority (swcad-title-frame-block-size-priority block))
                (if
                  (or
                    (not best)
                    (< priority bestpriority)
                    (and
                      (= priority bestpriority)
                      (if (= priority 0)
                        (< area bestarea)
                        (> area bestarea)
                      )
                    )
                  )
                  (progn
                    (setq best (list ename data bbox))
                    (setq bestarea area)
                    (setq bestpriority priority)
                  )
                )
              )
            )
          )
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  best
)

(defun swcad-title-transfer-text-records (bbox source-ename / ss index total ename data raw-text point records record block-records)
  (setq records nil)
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq raw-text (swcad-title-text-entity-value data))
    (setq point (swcad-title-dxf-value data 10))
    (if (and
          raw-text
          (> (strlen raw-text) 0)
          (or (not bbox) (swcad-title-point-in-bbox-p point (swcad-title-expand-bbox bbox 2.0)))
        )
      (progn
        (setq record (swcad-title-text-record data raw-text))
        (setq records (append records (list record)))
      )
    )
    (setq index (+ index 1))
  )
  (if source-ename
    (progn
      (setq block-records (swcad-title-block-text-records source-ename bbox))
      (if block-records
        (setq records (append records block-records))
      )
    )
  )
  (vl-sort records 'swcad-title-text-record-less-p)
)

(defun swcad-title-transfer-preview-record (record bbox / point best slot dist tag label relx rely)
  (setq point (nth 5 record))
  (setq best (swcad-title-transfer-best-slot point bbox))
  (if best
    (progn
      (setq slot (car best))
      (setq dist (cadr best))
      (setq relx (caddr best))
      (setq rely (cadddr best))
      (setq tag (car slot))
      (setq label (cadddr slot))
      (list tag label (nth 6 record) (nth 3 record) point dist relx rely record)
    )
    nil
  )
)

(defun swcad-title-transfer-print-mapping (mapping)
  (swcad-title-princ-line
    (strcat
      "  "
      (car mapping)
      " ["
      (cadr mapping)
      "] <= \""
      (swcad-title-string (caddr mapping))
      "\""
      ", source-handle="
      (swcad-title-string (cadddr mapping))
      ", source-point="
      (swcad-title-point-string (nth 4 mapping))
      ", distance="
      (swcad-title-number-string (nth 5 mapping))
    )
  )
)

(defun swcad-title-transfer-print-unmapped (record bbox / best slot)
  (setq best (swcad-title-transfer-best-slot (nth 5 record) bbox))
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (nth 3 record))
      ", point="
      (swcad-title-point-string (nth 5 record))
      ", text=\""
      (swcad-title-string (nth 6 record))
      "\""
      (if best
        (progn
          (setq slot (car best))
          (strcat
            ", nearest="
            (car slot)
            ", distance="
            (swcad-title-number-string (cadr best))
          )
        )
        ""
      )
    )
  )
)

(defun swcad-title-transfer-preview (/ source source-ename source-data source-bbox source-block source-frame source-frame-ename source-frame-data source-frame-block source-frame-bbox records mappings unmapped duplicates record preview tag existing slot maxdist missing-count mapped-count duplicate-count unmapped-count values block-sheet inferred-frame-bbox text-sheet frame-sheet detected-sheet frame-block title-shell-handles title-graphic-handles frame-graphic-handles residue-records)
  (swcad-title-open-transfer-log)
  (setq maxdist 7.0)
  (setq source (swcad-title-transfer-source-bbox))
  (setq source-ename (if source (car source) nil))
  (setq source-data (if source (cadr source) nil))
  (setq source-bbox (if source (caddr source) nil))
  (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) nil))
  (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-data (if source-frame (cadr source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
  (setq mappings nil)
  (setq unmapped nil)
  (setq duplicates nil)
  (setq mapped-count 0)
  (setq duplicate-count 0)
  (setq unmapped-count 0)
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 GMTITLE 변환 미리보기(읽기 전용) -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Source title insert: "
      (if source-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-data 5))
          ", block="
          (swcad-title-string source-block)
          ", bbox="
          (swcad-title-bbox-string source-bbox)
        )
        "<none>"
      )
    )
  )
  (if source-bbox
    (progn
      (setq records (swcad-title-transfer-text-records source-bbox source-ename))
      (foreach record records
        (setq preview (swcad-title-transfer-preview-record record source-bbox))
        (if (and preview (<= (nth 5 preview) maxdist))
          (progn
            (setq tag (car preview))
            (setq existing (assoc tag mappings))
            (if existing
              (progn
                (setq duplicates (append duplicates (list record)))
                (setq duplicate-count (+ duplicate-count 1))
              )
              (progn
                (setq mappings (swcad-title-assoc-put tag preview mappings))
                (setq mapped-count (+ mapped-count 1))
              )
            )
          )
          (progn
            (setq unmapped (append unmapped (list record)))
            (setq unmapped-count (+ unmapped-count 1))
          )
        )
      )

      (swcad-title-princ-line "GM TITLE attribute transfer preview:")
      (setq missing-count 0)
      (foreach slot *swcad-title-transfer-template*
        (setq tag (car slot))
        (setq existing (assoc tag mappings))
        (if existing
          (swcad-title-transfer-print-mapping (cdr existing))
          (progn
            (setq missing-count (+ missing-count 1))
            (swcad-title-princ-line
              (strcat
                "  "
                tag
                " ["
                (cadddr slot)
                "] <= <missing>"
              )
            )
          )
        )
      )

      (swcad-title-princ-line "Unmapped source title texts:")
      (if unmapped
        (foreach record unmapped
          (swcad-title-transfer-print-unmapped record source-bbox)
        )
        (swcad-title-princ-line "  <none>")
      )
      (swcad-title-princ-line "Duplicate source title texts:")
      (if duplicates
        (foreach record duplicates
          (swcad-title-transfer-print-unmapped record source-bbox)
        )
        (swcad-title-princ-line "  <none>")
      )
      (setq values (swcad-title-transfer-values mappings))
      (if (not source-ename)
        (setq values (swcad-title-values-fill-missing-template-empty values))
      )
      (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
      (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
      (setq inferred-frame-bbox (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
      (setq text-sheet (swcad-title-normalized-sheet-size (swcad-title-sheet-size-value values)))
      (setq frame-sheet (swcad-title-sheet-size-from-frame-bbox inferred-frame-bbox))
      (setq detected-sheet (swcad-title-detected-sheet-size-for-source source-block source-frame-block values inferred-frame-bbox))
      (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values inferred-frame-bbox))
      (setq title-shell-handles
        (if (not source-ename)
          (swcad-title-source-title-shell-handles source-bbox source-ename source-frame-ename)
          nil
        )
      )
      (setq title-graphic-handles (swcad-title-source-title-graphic-handles source-bbox))
      (setq frame-graphic-handles
        (if source-frame-ename
          nil
          (swcad-title-source-frame-graphic-handles inferred-frame-bbox source-bbox)
        )
      )
      (setq residue-records
        (swcad-title-source-sheet-residue-records
          inferred-frame-bbox
          source-ename
          source-frame-ename
        )
      )
      (swcad-title-princ-line
        (strcat
          "Source frame insert: "
          (if source-frame-data
            (strcat
              "handle="
              (swcad-title-string (swcad-title-dxf-value source-frame-data 5))
              ", block="
              (swcad-title-string source-frame-block)
              ", bbox="
              (swcad-title-bbox-string source-frame-bbox)
            )
            "<none>"
          )
        )
      )
      (swcad-title-princ-line
        (strcat
          "Detected sheet size: title-text="
          (if text-sheet text-sheet "<none>")
          ", frame-bbox="
          (if frame-sheet frame-sheet "<none>")
          ", block-name="
          (if block-sheet block-sheet "<none>")
          ", selected="
          (if detected-sheet detected-sheet "<fallback>")
        )
      )
      (swcad-title-princ-line (strcat "Expected native GMTITLE frame block: " frame-block))
      (swcad-title-princ-line (strcat "Expected native GMTITLE title block: " (swcad-title-target-title-block-name)))
      (swcad-title-princ-line (strcat "기존 loose-text 제목 셸 INSERT 정리 후보: " (itoa (length title-shell-handles))))
      (swcad-title-princ-line (strcat "Old loose title graphics cleanup candidates: " (itoa (length title-graphic-handles))))
      (swcad-title-princ-line
        (strcat
          "Old loose frame graphics cleanup candidates: "
          (itoa (length frame-graphic-handles))
          ", frame cleanup bbox="
          (swcad-title-bbox-string inferred-frame-bbox)
        )
      )
      (swcad-title-print-residue-records "Old SOLIDWORKS sheet residue cleanup candidates:" residue-records)
      (swcad-title-princ-line "Summary:")
      (swcad-title-princ-line (strcat "  source title texts: " (itoa (length records))))
      (swcad-title-princ-line (strcat "  mapped fields: " (itoa mapped-count)))
      (swcad-title-princ-line (strcat "  missing target fields: " (itoa missing-count)))
      (swcad-title-princ-line (strcat "  unmapped source texts: " (itoa unmapped-count)))
      (swcad-title-princ-line (strcat "  duplicate source texts: " (itoa duplicate-count)))
      (swcad-title-princ-line (strcat "  sheet residue cleanup candidates: " (itoa (length residue-records))))
    )
    (progn
      (swcad-title-princ-line "표제란처럼 보이는 INSERT를 찾지 못했습니다. 자세한 상태는 SWTITLESTATUS로 다시 확인하세요.")
      (swcad-title-princ-line "Summary:")
      (swcad-title-princ-line "  mapped fields: 0")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-apply (/ source source-data source-bbox source-ename source-block source-kind source-frame source-frame-ename source-frame-data source-frame-block source-frame-bbox frame-block title-block adopt-pair gmtitle-result gmtitle-title-ename gmtitle-frame-ename gmtitle-new-enames title-ref build mappings records unmapped duplicates values block-sheet answer attr-count attr-errors deleted-text-count skipped-block-text-count old-frame-deleted record doc pair inferred-frame-bbox text-sheet frame-sheet detected-sheet title-shell-handles title-graphic-handles frame-graphic-handles residue-records residue-handles deleted-title-shell-count deleted-title-graphic-count deleted-frame-graphic-count deleted-residue-count actual-title-name actual-frame-name geometry-warning deleted-new-gmtitle-count align-result align-count align-dx align-dy align-needed marker-role marker-ok)
  (swcad-title-open-apply-log)
  (setq *swcad-title-last-apply-status* nil)
  (setq source (swcad-title-transfer-source-bbox))
  (setq source-ename (if source (car source) nil))
  (setq source-data (if source (cadr source) nil))
  (setq source-bbox (if source (caddr source) nil))
  (setq source-kind (if source-ename "block-attributes" "loose-text"))
  (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) nil))
  (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-data (if source-frame (cadr source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
  (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block nil source-frame-bbox))
  (setq title-block (swcad-title-target-title-block-name))
  (swcad-title-princ-line "----- SWTITLECONVERT 내부 첫 native GMTITLE 변환 -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "FILEDIA before: " (swcad-title-string (getvar "FILEDIA")) " (not changed)"))
  (swcad-title-princ-line (strcat "CMDDIA before: " (swcad-title-string (getvar "CMDDIA")) " (not changed)"))
  (swcad-title-princ-line
    (strcat
      "Source title insert: "
      (if source-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-data 5))
          ", block="
          (swcad-title-string source-block)
          ", bbox="
          (swcad-title-bbox-string source-bbox)
        )
        "<none>"
      )
    )
  )
  (swcad-title-princ-line (strcat "Source title kind: " source-kind))
  (swcad-title-princ-line
    (strcat
      "Source frame insert: "
      (if source-frame-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-frame-data 5))
          ", block="
          (swcad-title-string source-frame-block)
          ", bbox="
          (swcad-title-bbox-string source-frame-bbox)
        )
        "<none>"
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Preliminary native GMTITLE frame block: "
      frame-block
    )
  )
  (swcad-title-princ-line
    (strcat
      "Expected native GMTITLE title block: "
      title-block
    )
  )
  (cond
    ((not source-bbox)
      (swcad-title-apply-result "ABORT_NO_SOURCE_TITLE")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before applying.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before applying.")
    )
    (T
      (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
      (setq mappings (car build))
      (setq records (cadr build))
      (setq unmapped (caddr build))
      (setq duplicates (cadddr build))
      (setq values (swcad-title-transfer-values mappings))
      (if (not source-ename)
        (setq values (swcad-title-values-fill-missing-template-empty values))
      )
      (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
      (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
      (setq inferred-frame-bbox (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
      (setq text-sheet (swcad-title-normalized-sheet-size (swcad-title-sheet-size-value values)))
      (setq frame-sheet (swcad-title-sheet-size-from-frame-bbox inferred-frame-bbox))
      (setq detected-sheet (swcad-title-detected-sheet-size-for-source source-block source-frame-block values inferred-frame-bbox))
      (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values inferred-frame-bbox))
      (setq title-shell-handles
        (if (equal source-kind "loose-text")
          (swcad-title-source-title-shell-handles source-bbox source-ename source-frame-ename)
          nil
        )
      )
      (setq title-graphic-handles (swcad-title-source-title-graphic-handles source-bbox))
      (setq frame-graphic-handles
        (if source-frame-ename
          nil
          (swcad-title-source-frame-graphic-handles inferred-frame-bbox source-bbox)
        )
      )
      (setq residue-records
        (swcad-title-source-sheet-residue-records
          inferred-frame-bbox
          source-ename
          source-frame-ename
        )
      )
      (setq residue-handles (swcad-title-residue-record-handles residue-records))
      (swcad-title-princ-line "Values to apply:")
      (foreach pair values
        (swcad-title-princ-line
          (strcat
            "  "
            (car pair)
            " = \""
            (swcad-title-string (cdr pair))
            "\""
          )
        )
      )
      (swcad-title-princ-line
        (strcat
          "Unmapped source texts to delete with old title text: "
          (itoa (length unmapped))
        )
      )
      (swcad-title-princ-line
        (strcat
          "Duplicate source texts not mapped: "
          (itoa (length duplicates))
        )
      )
      (swcad-title-princ-line (strcat "삭제 예정 기존 loose-text 제목 셸 INSERT: " (itoa (length title-shell-handles))))
      (swcad-title-princ-line (strcat "Old loose title graphics queued for cleanup: " (itoa (length title-graphic-handles))))
      (swcad-title-princ-line
        (strcat
          "Old loose frame graphics queued for cleanup: "
          (itoa (length frame-graphic-handles))
          ", frame cleanup bbox="
          (swcad-title-bbox-string inferred-frame-bbox)
        )
      )
      (swcad-title-princ-line
        (strcat
          "Detected sheet size: title-text="
          (if text-sheet text-sheet "<none>")
          ", frame-bbox="
          (if frame-sheet frame-sheet "<none>")
          ", block-name="
          (if block-sheet block-sheet "<none>")
          ", selected="
          (if detected-sheet detected-sheet "<fallback>")
        )
      )
      (swcad-title-princ-line (strcat "Expected native GMTITLE frame block after detection: " frame-block))
      (swcad-title-print-residue-records "Old SOLIDWORKS sheet residue queued for cleanup:" residue-records)
      (setq adopt-pair (swcad-title-adoptable-target-pair-for-frame-bbox frame-block inferred-frame-bbox))
      (if adopt-pair
        (progn
          (swcad-title-princ-line "Existing native GMTITLE adoption candidate found at the same frame bbox.")
          (swcad-title-princ-line
            (strcat
              "  adopt title/frame="
              (swcad-title-ename-handle (car adopt-pair))
              "/"
              (swcad-title-ename-handle (cadr adopt-pair))
              ", roles="
              (swcad-title-role-display (nth 5 adopt-pair))
              "/"
              (swcad-title-role-display (nth 6 adopt-pair))
            )
          )
          (swcad-title-princ-line "  이 경우 GMTITLE 창을 다시 열지 않고 기존 native 쌍에 값을 채운 뒤 원본만 정리합니다.")
        )
        (swcad-title-princ-line "Existing native GMTITLE adoption candidate: <none>")
      )
      (setq answer
        (if *swcad-title-batch-mode*
          "YES"
          (getstring
            T
            "\nnative GMTITLE을 실행하고 새 제목블록 속성을 채운 뒤 기존 표제란 내용을 제거하려면 YES를 입력하세요: "
          )
        )
      )
      (if *swcad-title-batch-mode*
        (swcad-title-princ-line "Confirmation: batch mode")
      )
      (if (/= (strcase answer) "YES")
        (swcad-title-apply-result "ABORT_USER_CANCEL")
        (progn
          (if adopt-pair
            (swcad-title-adopt-existing-native-gmtitle-transfer
              adopt-pair
              frame-block
              values
              source-ename
              source-frame-ename
              records
              title-shell-handles
              title-graphic-handles
              frame-graphic-handles
              residue-handles
            )
            (progn
              (setq gmtitle-result
                (swcad-title-run-native-gmtitle-prefer-commandline
                  frame-block
                  (swcad-title-bbox-lower-left-point inferred-frame-bbox)
                )
              )
              (setq gmtitle-title-ename (car gmtitle-result))
              (setq gmtitle-frame-ename (cadr gmtitle-result))
              (setq gmtitle-new-enames (caddr gmtitle-result))
              (swcad-title-princ-line (strcat "Native GMTITLE new INSERT count: " (itoa (length gmtitle-new-enames))))
              (swcad-title-insert-log-label "Native GMTITLE title insert" gmtitle-title-ename)
              (swcad-title-insert-log-label "Native GMTITLE frame insert" gmtitle-frame-ename)
              (setq actual-title-name (if gmtitle-title-ename (swcad-title-effective-insert-name gmtitle-title-ename) ""))
              (setq actual-frame-name (if gmtitle-frame-ename (swcad-title-effective-insert-name gmtitle-frame-ename) ""))
              (setq geometry-warning
                (if gmtitle-frame-ename
                  (swcad-title-frame-bbox-size-warning-for-block
                    frame-block
                    (swcad-title-frame-reference-effective-bbox gmtitle-frame-ename frame-block)
                  )
                  nil
                )
              )
              (swcad-title-princ-line (strcat "Native GMTITLE selected title block: " (if (> (strlen actual-title-name) 0) actual-title-name "<missing>")))
              (swcad-title-princ-line (strcat "Native GMTITLE selected frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
              (if gmtitle-title-ename
                (if
                  (and
                    (swcad-title-native-target-title-name-p actual-title-name)
                    gmtitle-frame-ename
                    (swcad-title-frame-name-matches-p actual-frame-name frame-block)
                    (not geometry-warning)
                  )
                  (progn
                (setq title-ref (swcad-title-safe-vla-object gmtitle-title-ename))
                (setq doc (swcad-title-doc))
                (vl-catch-all-apply 'vla-StartUndoMark (list doc))
                (setq align-result (swcad-title-align-gmtitle-to-frame-bbox gmtitle-title-ename gmtitle-frame-ename inferred-frame-bbox))
                (setq align-count (car align-result))
                (setq align-dx (cadr align-result))
                (setq align-dy (caddr align-result))
                (setq align-needed (or (> (swcad-title-abs align-dx) 0.0001) (> (swcad-title-abs align-dy) 0.0001)))
                (if (and align-needed (< align-count 2))
                  (progn
                    (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                    (setq deleted-new-gmtitle-count (swcad-title-delete-ename-list gmtitle-new-enames))
                    (swcad-title-apply-result "ABORT_GMTITLE_ALIGN_FAILED")
                    (swcad-title-princ-line
                      (strcat
                        "Native GMTITLE alignment failed: moved="
                        (itoa align-count)
                        ", dx="
                        (swcad-title-number-string align-dx)
                        ", dy="
                        (swcad-title-number-string align-dy)
                      )
                    )
                    (swcad-title-princ-line (strcat "부분 생성된 새 GMTITLE INSERT 삭제: " (itoa deleted-new-gmtitle-count)))
                    (swcad-title-princ-line "기존 SOLIDWORKS 표제란/도면틀 내용은 삭제하지 않았습니다.")
                  )
                  (if
                    (and
                      align-needed
                      (not *swcad-title-last-native-gmtitle-placement-used*)
                      (swcad-title-native-placement-substantial-move-p align-dx align-dy)
                    )
                    (progn
                      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                      (setq deleted-new-gmtitle-count (swcad-title-delete-ename-list gmtitle-new-enames))
                      (swcad-title-apply-result "ABORT_GMTITLE_NATIVE_PLACEMENT_REQUIRED")
                      (swcad-title-princ-line "Native GMTITLE이 원본 도면틀 위치와 떨어진 곳에 생성되어 LISP MOVE 정렬이 필요합니다.")
                      (swcad-title-princ-line "이 방식은 시각적으로 맞아도 GMPOWEREDIT/더블클릭 동작이 실패할 수 있어 신뢰하지 않습니다.")
                      (swcad-title-princ-line (strcat "신뢰하지 않는 새 GMTITLE INSERT 삭제: " (itoa deleted-new-gmtitle-count)))
                      (swcad-title-princ-line "기존 SOLIDWORKS 표제란/도면틀 내용은 삭제하지 않았습니다.")
                      (swcad-title-princ-line "다음: Frame positioning ON, Object move OFF 상태로 다시 실행하고 GMTITLE이 왼쪽 아래 배치점을 받도록 하세요.")
                    )
                    (progn
                    (setq attr-count (swcad-title-set-insert-attributes title-ref values))
                    (setq attr-errors (swcad-title-value-verification-errors title-ref values))
                    (swcad-title-print-value-verification-errors attr-errors)
                    (if attr-errors
                      (progn
                        (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                        (setq deleted-new-gmtitle-count (swcad-title-delete-ename-list gmtitle-new-enames))
                        (swcad-title-apply-result "ABORT_TITLE_ATTRIBUTE_VERIFICATION")
                        (swcad-title-princ-line (strcat "값 검증에 실패한 새 GMTITLE INSERT 삭제: " (itoa deleted-new-gmtitle-count)))
                        (swcad-title-princ-line "기존 SOLIDWORKS 제목 데이터와 도면틀은 삭제하지 않았습니다.")
                      )
                      (progn
                        (swcad-title-delete-ename source-ename)
                        (setq deleted-text-count 0)
                        (setq skipped-block-text-count 0)
                        (foreach record records
                          (if (swcad-title-delete-text-record record)
                            (setq deleted-text-count (+ deleted-text-count 1))
                            (setq skipped-block-text-count (+ skipped-block-text-count 1))
                          )
                        )
                        (setq old-frame-deleted "no")
                        (if source-frame-ename
                          (progn
                            (swcad-title-delete-ename source-frame-ename)
                            (setq old-frame-deleted "yes")
                          )
                        )
                        (setq deleted-title-shell-count (swcad-title-delete-handle-list title-shell-handles))
                        (setq deleted-title-graphic-count (swcad-title-delete-handle-list title-graphic-handles))
                        (setq deleted-frame-graphic-count
                          (if source-frame-ename
                            0
                            (swcad-title-delete-handle-list frame-graphic-handles)
                          )
                        )
                        (setq deleted-residue-count (swcad-title-delete-handle-list residue-handles))
                        (setq marker-role
                          (if
                            (and
                              align-needed
                              (not *swcad-title-last-native-gmtitle-placement-used*)
                              (swcad-title-native-placement-substantial-move-p align-dx align-dy)
                            )
                            "native-moved-unverified"
                            "native-apply"
                          )
                        )
                        (setq marker-ok
                          (swcad-title-mark-native-exemplar-pair
                            gmtitle-title-ename
                            gmtitle-frame-ename
                            frame-block
                            marker-role
                          )
                        )
                        (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                        (swcad-title-princ-line "Native GMTITLE was used directly.")
                        (swcad-title-princ-line
                          (strcat "Native exemplar marker set: " (if marker-ok "yes" "no") ", role=" marker-role)
                        )
                        (if (equal (strcase marker-role) "NATIVE-MOVED-UNVERIFIED")
                          (progn
                            (swcad-title-princ-line "WARNING: GMTITLE was moved by LISP after creation because native placement was not captured.")
                            (swcad-title-princ-line "This pair is not trusted for GMPOWEREDIT/double-click behavior until recreated with native placement.")
                          )
                        )
                        (swcad-title-princ-line
                          (strcat
                            "Native GMTITLE aligned to source frame: moved="
                            (itoa align-count)
                            ", dx="
                            (swcad-title-number-string align-dx)
                            ", dy="
                            (swcad-title-number-string align-dy)
                          )
                        )
                        (swcad-title-princ-line (strcat "Attributes set and verified: " (itoa attr-count)))
                        (swcad-title-princ-line (strcat "Old loose title texts deleted: " (itoa deleted-text-count)))
                        (swcad-title-princ-line (strcat "Old block-internal title texts handled by deleting source insert: " (itoa skipped-block-text-count)))
                        (swcad-title-princ-line (strcat "삭제한 기존 loose-text 제목 셸 INSERT: " (itoa deleted-title-shell-count)))
                        (swcad-title-princ-line (strcat "Old loose title graphics deleted: " (itoa deleted-title-graphic-count)))
                        (swcad-title-princ-line (strcat "Old title insert deleted: " (if source-ename "yes" "not-applicable (loose-text source)")))
                        (swcad-title-princ-line (strcat "Old frame insert deleted: " old-frame-deleted))
                        (swcad-title-princ-line (strcat "Old loose frame graphics deleted: " (itoa deleted-frame-graphic-count)))
                        (swcad-title-princ-line (strcat "Old SOLIDWORKS sheet residue deleted: " (itoa deleted-residue-count)))
                        (swcad-title-apply-result "APPLIED_TITLE_TRANSFER")
                        (swcad-title-princ-line "최종 수동 확인: 새 GMTITLE 제목블록을 더블클릭해서 GMTITLE 표 편집창이 열리는지 확인하세요.")
                      )
                    )
                    )
                  )
                )
              )
              (progn
                (setq deleted-new-gmtitle-count (swcad-title-delete-ename-list gmtitle-new-enames))
                (if geometry-warning
                  (swcad-title-apply-result "ABORT_NATIVE_GMTITLE_INVALID_FRAME_GEOMETRY")
                  (swcad-title-apply-result "ABORT_WRONG_NATIVE_GMTITLE_SELECTION")
                )
                (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
                (swcad-title-princ-line (strcat "Expected title block: " title-block))
                (swcad-title-princ-line (strcat "Selected frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
                (if geometry-warning
                  (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
                )
                (if (and (> (strlen actual-frame-name) 0) (not (swcad-title-frame-name-matches-p actual-frame-name frame-block)))
                  (swcad-title-princ-line "선택된 GMTITLE 용지가 기대한 원본 용지와 다릅니다. SWTITLESTATUS로 상태를 확인한 뒤 로그가 요구한 DR 용지로 다시 진행하세요.")
                )
                (swcad-title-princ-line (strcat "Removed wrong/new GMTITLE inserts: " (itoa deleted-new-gmtitle-count)))
                (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
              )
            )
            (progn
              (setq deleted-new-gmtitle-count (swcad-title-delete-ename-list gmtitle-new-enames))
              (swcad-title-apply-result "ABORT_NO_NATIVE_GMTITLE_TITLE")
              (swcad-title-princ-line (strcat "Removed partial/new GMTITLE inserts: " (itoa deleted-new-gmtitle-count)))
              (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
            )
          )
        )
      )
    )
  )
  )
  )
  (swcad-title-princ-line "참고: 일반 도면틀 정리는 기존 표제란 주변 그래픽과 추정 도면틀 모서리 그래픽만 보수적으로 삭제합니다.")
  (swcad-title-princ-line "참고: 시트 잔여물 정리는 왼쪽 아래 실제 모서리 잔여물, SHEET_FORMAT 계열 블록, 오른쪽 위의 길쭉한 SW_NOTE 잔여물만 제한적으로 정리합니다.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-finalize (/ *error* source source-data source-bbox source-ename source-block source-frame source-frame-ename source-frame-data source-frame-block source-frame-bbox frame-block title-block gmtitle-title-ename gmtitle-frame-ename title-ref build mappings records unmapped duplicates values block-sheet original-attr-values attr-count attr-errors deleted-text-count skipped-block-text-count old-frame-deleted record doc pair inferred-frame-bbox text-sheet frame-sheet detected-sheet title-shell-handles title-graphic-handles frame-graphic-handles residue-records residue-handles deleted-title-shell-count deleted-title-graphic-count deleted-frame-graphic-count deleted-residue-count actual-title-name actual-frame-name geometry-warning align-result align-count align-dx align-dy align-needed marker-ok pending-pair pending-role marker-role deleted-new-count)
  (swcad-title-open-apply-log)
  (defun *error* (msg)
    (if msg
      (swcad-title-princ-line (strcat "Error: " (swcad-title-string msg)))
    )
    (swcad-title-clear-pending-native-gmtitle-pair)
    (swcad-title-apply-result "ERROR_TRANSFER_FINALIZE")
    (swcad-title-close-log)
    (princ)
  )
  (setq *swcad-title-last-apply-status* nil)
  (setq source (swcad-title-transfer-source-for-existing-gmtitle))
  (setq source-ename (if source (car source) nil))
  (setq source-data (if source (cadr source) nil))
  (setq source-bbox (if source (caddr source) nil))
  (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) nil))
  (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-data (if source-frame (cadr source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
  (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block nil source-frame-bbox))
  (setq title-block (swcad-title-target-title-block-name))
  (swcad-title-princ-line "----- SWTITLECONVERT 내부 기존 GMTITLE 변환 마무리 -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Source title insert: "
      (if source-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-data 5))
          ", block="
          (swcad-title-string source-block)
          ", bbox="
          (swcad-title-bbox-string source-bbox)
        )
        "<none>"
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Source frame insert: "
      (if source-frame-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-frame-data 5))
          ", block="
          (swcad-title-string source-frame-block)
          ", bbox="
          (swcad-title-bbox-string source-frame-bbox)
        )
        "<none>"
      )
    )
  )
  (cond
    ((not source-bbox)
      (swcad-title-apply-result "ABORT_NO_SOURCE_TITLE")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before finalizing.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before finalizing.")
    )
    (T
      (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
      (setq mappings (car build))
      (setq records (cadr build))
      (setq unmapped (caddr build))
      (setq duplicates (cadddr build))
      (setq values (swcad-title-transfer-values mappings))
      (if (not source-ename)
        (setq values (swcad-title-values-fill-missing-template-empty values))
      )
      (swcad-title-princ-line "Finalize step: mappings built.")
      (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
      (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
      (setq inferred-frame-bbox (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
      (swcad-title-princ-line "Finalize step: inferred frame bbox ready.")
      (setq text-sheet (swcad-title-normalized-sheet-size (swcad-title-sheet-size-value values)))
      (setq frame-sheet (swcad-title-sheet-size-from-frame-bbox inferred-frame-bbox))
      (setq detected-sheet (swcad-title-detected-sheet-size-for-source source-block source-frame-block values inferred-frame-bbox))
      (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values inferred-frame-bbox))
      (swcad-title-princ-line (strcat "Finalize step: target frame block " frame-block))
      (setq pending-pair (swcad-title-pending-native-gmtitle-pair-for-block frame-block))
      (if pending-pair
        (progn
          (setq gmtitle-title-ename (car pending-pair))
          (setq gmtitle-frame-ename (cadr pending-pair))
          (setq pending-role (nth 2 pending-pair))
          (swcad-title-princ-line "Finalize step: using pending GMTITLE pair from the previous create/clone step.")
        )
        (progn
          (setq pending-role "native")
          (setq gmtitle-frame-ename (swcad-title-unfinalized-gmtitle-frame-for-block frame-block))
          (setq gmtitle-title-ename nil)
          (if gmtitle-frame-ename
            (progn
              (setq gmtitle-title-ename (swcad-title-title-for-native-frame gmtitle-frame-ename frame-block))
              (if (not gmtitle-title-ename)
                (setq gmtitle-title-ename (swcad-title-default-location-title-for-frame gmtitle-frame-ename frame-block))
              )
            )
          )
        )
      )
      (swcad-title-insert-log-label "Finalize step: candidate GMTITLE frame" gmtitle-frame-ename)
      (swcad-title-insert-log-label "Finalize step: candidate GMTITLE title" gmtitle-title-ename)
      (setq actual-title-name (if gmtitle-title-ename (swcad-title-effective-insert-name gmtitle-title-ename) ""))
      (setq actual-frame-name (if gmtitle-frame-ename (swcad-title-effective-insert-name gmtitle-frame-ename) ""))
      (setq geometry-warning
        (if gmtitle-frame-ename
          (swcad-title-frame-bbox-size-warning-for-block
            frame-block
            (swcad-title-frame-reference-effective-bbox gmtitle-frame-ename frame-block)
          )
          nil
        )
      )
      (setq title-shell-handles
        (if (not source-ename)
          (swcad-title-source-title-shell-handles source-bbox source-ename source-frame-ename)
          nil
        )
      )
      (setq title-graphic-handles (swcad-title-source-title-graphic-handles source-bbox))
      (swcad-title-princ-line "Finalize step: title graphics scanned.")
      (setq frame-graphic-handles
        (if source-frame-ename
          nil
          (swcad-title-source-frame-graphic-handles inferred-frame-bbox source-bbox)
        )
      )
      (swcad-title-princ-line "Finalize step: frame graphics scanned.")
      (setq residue-records
        (swcad-title-source-sheet-residue-records
          inferred-frame-bbox
          source-ename
          source-frame-ename
        )
      )
      (swcad-title-princ-line "Finalize step: residue records scanned.")
      (setq residue-handles (swcad-title-residue-record-handles residue-records))
      (swcad-title-princ-line
        (strcat
          "Detected sheet size: title-text="
          (if text-sheet text-sheet "<none>")
          ", frame-bbox="
          (if frame-sheet frame-sheet "<none>")
          ", block-name="
          (if block-sheet block-sheet "<none>")
          ", selected="
          (if detected-sheet detected-sheet "<fallback>")
        )
      )
      (swcad-title-princ-line (strcat "Expected existing GMTITLE frame block: " frame-block))
      (swcad-title-princ-line (strcat "Expected existing GMTITLE title block: " title-block))
      (swcad-title-insert-log-label "Existing GMTITLE title insert" gmtitle-title-ename)
      (swcad-title-insert-log-label "Existing GMTITLE frame insert" gmtitle-frame-ename)
      (swcad-title-princ-line "Values to apply:")
      (foreach pair values
        (swcad-title-princ-line
          (strcat
            "  "
            (car pair)
            " = \""
            (swcad-title-string (cdr pair))
            "\""
          )
        )
      )
      (swcad-title-princ-line
        (strcat
          "Unmapped source texts to delete with old title text: "
          (itoa (length unmapped))
        )
      )
      (swcad-title-princ-line
        (strcat
          "Duplicate source texts not mapped: "
          (itoa (length duplicates))
        )
      )
      (swcad-title-princ-line (strcat "삭제 예정 기존 loose-text 제목 셸 INSERT: " (itoa (length title-shell-handles))))
      (swcad-title-princ-line (strcat "Old loose title graphics queued for cleanup: " (itoa (length title-graphic-handles))))
      (swcad-title-princ-line
        (strcat
          "Old loose frame graphics queued for cleanup: "
          (itoa (length frame-graphic-handles))
          ", frame cleanup bbox="
          (swcad-title-bbox-string inferred-frame-bbox)
        )
      )
      (swcad-title-print-residue-records "Old SOLIDWORKS sheet residue queued for cleanup:" residue-records)
      (if
        (and
          (swcad-title-native-target-title-name-p actual-title-name)
          gmtitle-frame-ename
          (swcad-title-frame-name-matches-p actual-frame-name frame-block)
          (not geometry-warning)
        )
        (progn
          (setq title-ref (swcad-title-safe-vla-object gmtitle-title-ename))
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq align-result (swcad-title-align-gmtitle-to-frame-bbox gmtitle-title-ename gmtitle-frame-ename inferred-frame-bbox))
          (setq align-count (car align-result))
          (setq align-dx (cadr align-result))
          (setq align-dy (caddr align-result))
          (setq align-needed (or (> (swcad-title-abs align-dx) 0.0001) (> (swcad-title-abs align-dy) 0.0001)))
          (if (and align-needed (< align-count 2))
            (progn
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (swcad-title-apply-result "ABORT_GMTITLE_ALIGN_FAILED")
              (swcad-title-princ-line
                (strcat
                  "Native GMTITLE alignment failed: moved="
                  (itoa align-count)
                  ", dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
            )
            (if
              (and
                align-needed
                (not *swcad-title-last-native-gmtitle-placement-used*)
                (swcad-title-native-placement-substantial-move-p align-dx align-dy)
                (not (equal (strcase (swcad-title-string pending-role)) "CLONE"))
              )
              (progn
                (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                (if pending-pair
                  (progn
                    (setq deleted-new-count (swcad-title-delete-ename-list (list gmtitle-title-ename gmtitle-frame-ename)))
                    (swcad-title-princ-line (strcat "신뢰하지 않는 대기 GMTITLE INSERT 삭제: " (itoa deleted-new-count)))
                  )
                )
                (swcad-title-apply-result "ABORT_GMTITLE_NATIVE_PLACEMENT_REQUIRED")
                (swcad-title-princ-line "Native GMTITLE이 원본 도면틀 위치와 떨어진 곳에 생성되어 LISP MOVE 정렬이 필요합니다.")
                (swcad-title-princ-line "이 방식은 시각적으로 맞아도 GMPOWEREDIT/더블클릭 동작이 실패할 수 있어 신뢰하지 않습니다.")
                (swcad-title-princ-line "기존 SOLIDWORKS 표제란/도면틀 내용은 삭제하지 않았습니다.")
                (swcad-title-princ-line "다음: Frame positioning ON, Object move OFF 상태로 다시 실행하고 GMTITLE이 왼쪽 아래 배치점을 받도록 하세요.")
              )
              (progn
              (setq original-attr-values (swcad-title-title-attribute-pairs title-ref))
              (setq attr-count (swcad-title-set-insert-attributes title-ref values))
              (setq attr-errors (swcad-title-value-verification-errors title-ref values))
              (swcad-title-print-value-verification-errors attr-errors)
              (if attr-errors
                (progn
                  (swcad-title-set-insert-attributes title-ref original-attr-values)
                  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                  (if pending-pair
                    (progn
                      (setq deleted-new-count (swcad-title-delete-ename-list (list gmtitle-title-ename gmtitle-frame-ename)))
                      (swcad-title-princ-line (strcat "값 검증에 실패한 대기 GMTITLE INSERT 삭제: " (itoa deleted-new-count)))
                    )
                  )
                  (swcad-title-apply-result "ABORT_TITLE_ATTRIBUTE_VERIFICATION")
                  (swcad-title-princ-line "기존 SOLIDWORKS 제목 데이터와 도면틀은 삭제하지 않았습니다.")
                )
                (progn
              (if source-ename
                (swcad-title-delete-ename source-ename)
              )
              (setq deleted-text-count 0)
              (setq skipped-block-text-count 0)
              (foreach record records
                (if (swcad-title-delete-text-record record)
                  (setq deleted-text-count (+ deleted-text-count 1))
                  (setq skipped-block-text-count (+ skipped-block-text-count 1))
                )
              )
              (setq old-frame-deleted "no")
              (if source-frame-ename
                (progn
                  (swcad-title-delete-ename source-frame-ename)
                  (setq old-frame-deleted "yes")
                )
              )
              (setq deleted-title-shell-count (swcad-title-delete-handle-list title-shell-handles))
              (setq deleted-title-graphic-count (swcad-title-delete-handle-list title-graphic-handles))
              (setq deleted-frame-graphic-count
                (if source-frame-ename
                  0
                  (swcad-title-delete-handle-list frame-graphic-handles)
                )
              )
              (setq deleted-residue-count (swcad-title-delete-handle-list residue-handles))
              (setq marker-role
                (cond
                  ((equal (strcase (swcad-title-string pending-role)) "CLONE") "clone")
                  ((and
                     align-needed
                     (not *swcad-title-last-native-gmtitle-placement-used*)
                     (swcad-title-native-placement-substantial-move-p align-dx align-dy)
                   )
                    "native-moved-unverified")
                  (pending-pair "native-finalize")
                  (T "native-finalize-manual")
                )
              )
              (setq marker-ok
                (swcad-title-mark-native-exemplar-pair
                  gmtitle-title-ename
                  gmtitle-frame-ename
                  frame-block
                  marker-role
                )
              )
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (if (equal (strcase marker-role) "CLONE")
                (swcad-title-princ-line "Cloned GMTITLE was finalized; native upgrade is still required for double-click behavior.")
                (swcad-title-princ-line "Existing native GMTITLE was used.")
              )
              (if (equal (strcase marker-role) "NATIVE-MOVED-UNVERIFIED")
                (progn
                  (swcad-title-princ-line "WARNING: GMTITLE was moved by LISP after creation because native placement was not captured.")
                  (swcad-title-princ-line "This pair is not trusted for GMPOWEREDIT/double-click behavior until recreated with native placement.")
                )
              )
              (swcad-title-princ-line
                (strcat "GMTITLE marker set: " (if marker-ok "yes" "no") ", role=" marker-role)
              )
              (swcad-title-princ-line
                (strcat
                  "Native GMTITLE aligned to source frame: moved="
                  (itoa align-count)
                  ", dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line (strcat "Attributes set: " (itoa attr-count)))
              (swcad-title-princ-line (strcat "Old loose title texts deleted: " (itoa deleted-text-count)))
              (swcad-title-princ-line (strcat "Old block-internal title texts handled by deleting source insert: " (itoa skipped-block-text-count)))
              (swcad-title-princ-line (strcat "삭제한 기존 loose-text 제목 셸 INSERT: " (itoa deleted-title-shell-count)))
              (swcad-title-princ-line (strcat "Old loose title graphics deleted: " (itoa deleted-title-graphic-count)))
              (swcad-title-princ-line (strcat "Old title insert deleted: " (if source-ename "yes" "not applicable (loose-text source)")))
              (swcad-title-princ-line (strcat "Old frame insert deleted: " old-frame-deleted))
              (swcad-title-princ-line (strcat "Old loose frame graphics deleted: " (itoa deleted-frame-graphic-count)))
              (swcad-title-princ-line (strcat "Old SOLIDWORKS sheet residue deleted: " (itoa deleted-residue-count)))
              (if (equal (strcase marker-role) "CLONE")
                (progn
                  (swcad-title-apply-result "FINALIZED_CLONED_GMTITLE_TRANSFER")
                  (swcad-title-princ-line "다음: 최종 더블클릭 확인 전에 SWTITLESTATUS를 실행하고, 남은 A2/A3/A4 교체 후보를 SWTITLECONVERTNEXT로 처리하세요.")
                )
                (progn
                  (swcad-title-apply-result "FINALIZED_EXISTING_GMTITLE_TRANSFER")
                  (swcad-title-princ-line "최종 수동 확인: GMTITLE 제목블록을 더블클릭해서 표 편집창이 열리는지 확인하세요.")
                )
              )
              )
              )
            )
          )
        )
      )
        (progn
          (if geometry-warning
            (swcad-title-apply-result "ABORT_EXISTING_GMTITLE_INVALID_FRAME_GEOMETRY")
            (swcad-title-apply-result "ABORT_EXISTING_GMTITLE_NOT_FOUND")
          )
          (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
          (swcad-title-princ-line (strcat "Expected title block: " title-block))
          (swcad-title-princ-line (strcat "Actual title block: " (if (> (strlen actual-title-name) 0) actual-title-name "<missing>")))
          (swcad-title-princ-line (strcat "Actual frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
          (if geometry-warning
            (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
          )
          (if pending-pair
            (progn
              (setq deleted-new-count (swcad-title-delete-ename-list (list gmtitle-title-ename gmtitle-frame-ename)))
              (swcad-title-princ-line (strcat "Removed pending invalid GMTITLE inserts: " (itoa deleted-new-count)))
            )
          )
          (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
        )
      )
    )
  )
  (swcad-title-clear-pending-native-gmtitle-pair)
  (swcad-title-princ-line "Note: create native GMTITLE with Frame positioning ON, Object move OFF, and the detected DR sheet before running finalize.")
  (swcad-title-princ-line "Note: if native placement is not captured and the pair must be moved from a default location, this command will not treat it as final GMTITLE recognition.")
  (swcad-title-princ-line "참고: 시트 잔여물 정리는 왼쪽 아래 실제 모서리 잔여물, SHEET_FORMAT 계열 블록, 오른쪽 위의 길쭉한 SW_NOTE 잔여물만 제한적으로 정리합니다.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-frame-only-finalize (/ *error* source-frame source-frame-ename source-frame-data source-frame-bbox source-frame-block source-sheet frame-block title-block gmtitle-title-ename gmtitle-frame-ename title-ref values attr-count doc align-result align-count align-dx align-dy align-needed residue-records residue-handles deleted-residue-count actual-title-name actual-frame-name frame-effective-bbox geometry-warning raw-selection-warning marker-ok pending-pair pending-role marker-role deleted-new-count)
  (swcad-title-open-apply-log)
  (defun *error* (msg)
    (if msg
      (swcad-title-princ-line (strcat "Error: " (swcad-title-string msg)))
    )
    (swcad-title-clear-pending-native-gmtitle-pair)
    (swcad-title-apply-result "ERROR_FRAME_ONLY_FINALIZE")
    (swcad-title-close-log)
    (princ)
  )
  (setq *swcad-title-last-apply-status* nil)
  (setq source-frame (swcad-title-frame-only-source-for-existing-gmtitle))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-data (if source-frame (cadr source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame (cadddr source-frame) nil))
  (setq source-sheet (if source-frame (nth 5 source-frame) nil))
  (setq frame-block (swcad-title-target-frame-block-name-for-sheet source-sheet))
  (setq title-block (swcad-title-target-title-block-name))
  (swcad-title-princ-line "----- SWTITLECONVERT 내부 기존/native frame-only 변환 마무리 -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Source frame-only insert: "
      (if source-frame-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-frame-data 5))
          ", block="
          (swcad-title-string source-frame-block)
          ", sheet="
          (swcad-title-string source-sheet)
          ", bbox="
          (swcad-title-bbox-string source-frame-bbox)
        )
        "<none>"
      )
    )
  )
  (cond
    ((not source-frame-bbox)
      (swcad-title-apply-result "ABORT_NO_FRAME_ONLY_SOURCE")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before finalizing.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before finalizing.")
    )
    (T
      (setq pending-pair (swcad-title-pending-native-gmtitle-pair-for-block frame-block))
      (if pending-pair
        (progn
          (setq gmtitle-title-ename (car pending-pair))
          (setq gmtitle-frame-ename (cadr pending-pair))
          (setq pending-role (nth 2 pending-pair))
          (swcad-title-princ-line "Frame-only finalize: using pending GMTITLE pair from the previous create/clone step.")
        )
        (progn
          (setq pending-role "native")
          (setq gmtitle-frame-ename (swcad-title-default-location-gmtitle-frame-for-block frame-block))
          (if gmtitle-frame-ename
            (progn
              (setq gmtitle-title-ename (swcad-title-title-for-native-frame gmtitle-frame-ename frame-block))
              (if (not gmtitle-title-ename)
                (setq gmtitle-title-ename (swcad-title-default-location-title-for-frame gmtitle-frame-ename frame-block))
              )
            )
          )
        )
      )
      (setq actual-title-name (if gmtitle-title-ename (swcad-title-effective-insert-name gmtitle-title-ename) ""))
      (setq actual-frame-name (if gmtitle-frame-ename (swcad-title-effective-insert-name gmtitle-frame-ename) ""))
      (setq frame-effective-bbox
        (if gmtitle-frame-ename
          (swcad-title-frame-reference-effective-bbox gmtitle-frame-ename frame-block)
          nil
        )
      )
      (setq geometry-warning
        (if gmtitle-frame-ename
          (swcad-title-frame-bbox-size-warning-for-block
            frame-block
            frame-effective-bbox
          )
          nil
        )
      )
      (setq raw-selection-warning
        (if gmtitle-frame-ename
          (swcad-title-frame-reference-raw-selection-warning gmtitle-frame-ename frame-block frame-effective-bbox)
          nil
        )
      )
      (if
        (and
          (swcad-title-normalized-sheet-size source-sheet)
          (swcad-title-native-target-title-name-p actual-title-name)
          (swcad-title-frame-name-matches-p actual-frame-name frame-block)
        )
        (progn
          (setq geometry-warning "원본 표제란이 없는 시트에 별도 제목블록이 생성됨")
          (swcad-title-princ-line "title-missing 보호 중단: 원본 시트에는 표제란이 없는데 GMTITLE이 별도 제목블록을 만들었습니다.")
          (swcad-title-princ-line "기존 원본 도면틀은 삭제하지 않습니다. SWTITLECONVERTNEXT의 title-missing/frame-only 도면틀-only 경로로 다시 처리하세요.")
        )
      )
      (setq values (swcad-title-frame-only-default-values source-frame))
      (setq residue-records (swcad-title-source-sheet-residue-records source-frame-bbox nil source-frame-ename))
      (setq residue-handles (swcad-title-residue-record-handles residue-records))
      (swcad-title-princ-line (strcat "Expected existing GMTITLE frame block: " frame-block))
      (swcad-title-princ-line (strcat "Expected existing GMTITLE title block: " title-block))
      (swcad-title-insert-log-label "Existing/default GMTITLE title insert" gmtitle-title-ename)
      (swcad-title-insert-log-label "Existing/default GMTITLE frame insert" gmtitle-frame-ename)
      (swcad-title-princ-line "Frame-only values to apply:")
      (foreach pair values
        (swcad-title-princ-line
          (strcat
            "  "
            (car pair)
            " = \""
            (swcad-title-string (cdr pair))
            "\""
          )
        )
      )
      (swcad-title-print-residue-records "Old SOLIDWORKS sheet residue queued for cleanup:" residue-records)
      (if
        (and
          (swcad-title-native-target-title-name-p actual-title-name)
          gmtitle-frame-ename
          (swcad-title-frame-name-matches-p actual-frame-name frame-block)
          (not geometry-warning)
          (not raw-selection-warning)
        )
        (progn
          (setq title-ref (swcad-title-safe-vla-object gmtitle-title-ename))
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq align-result (swcad-title-align-gmtitle-to-frame-bbox gmtitle-title-ename gmtitle-frame-ename source-frame-bbox))
          (setq align-count (car align-result))
          (setq align-dx (cadr align-result))
          (setq align-dy (caddr align-result))
          (setq align-needed (or (> (swcad-title-abs align-dx) 0.0001) (> (swcad-title-abs align-dy) 0.0001)))
          (if (and align-needed (< align-count 2))
            (progn
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (swcad-title-apply-result "ABORT_FRAME_ONLY_ALIGN_FAILED")
              (swcad-title-princ-line
                (strcat
                  "Frame-only GMTITLE alignment failed: moved="
                  (itoa align-count)
                  ", dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line "기존 frame-only 시트 내용은 삭제하지 않았습니다.")
            )
            (if
              (and
                align-needed
                (not *swcad-title-last-native-gmtitle-placement-used*)
                (swcad-title-native-placement-substantial-move-p align-dx align-dy)
                (not (equal (strcase (swcad-title-string pending-role)) "CLONE"))
                (not (swcad-title-moved-native-placement-allowed-p source-sheet frame-block))
              )
              (progn
                (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                (if pending-pair
                  (progn
                    (setq deleted-new-count (swcad-title-delete-ename-list (list gmtitle-title-ename gmtitle-frame-ename)))
                    (swcad-title-princ-line (strcat "Removed untrusted pending GMTITLE inserts: " (itoa deleted-new-count)))
                  )
                )
                (swcad-title-apply-result "ABORT_FRAME_ONLY_NATIVE_PLACEMENT_REQUIRED")
                (swcad-title-princ-line "frame-only native GMTITLE이 원본 도면틀 위치와 떨어진 곳에 생성되어 LISP MOVE 정렬이 필요합니다.")
                (swcad-title-princ-line "시각적으로 정렬한 뒤에도 GMPOWEREDIT/더블클릭 동작이 실패할 수 있어 이 패턴은 신뢰하지 않습니다.")
                (swcad-title-princ-line "기존 frame-only 시트 내용은 삭제하지 않았습니다.")
                (swcad-title-princ-line "다음: Frame positioning ON, Object move OFF 상태로 다시 실행하고 GMTITLE이 왼쪽 아래 배치점을 받도록 하세요.")
              )
              (progn
              (setq attr-count (swcad-title-set-insert-attributes title-ref values))
              (swcad-title-delete-ename source-frame-ename)
              (setq deleted-residue-count (swcad-title-delete-handle-list residue-handles))
              (setq marker-role
                (cond
                  ((equal (strcase (swcad-title-string pending-role)) "CLONE") "clone")
                  ((and
                     align-needed
                     (not *swcad-title-last-native-gmtitle-placement-used*)
                     (swcad-title-native-placement-substantial-move-p align-dx align-dy)
                     (swcad-title-moved-native-placement-allowed-p source-sheet frame-block)
                   )
                    "native-frame-only-moved-accepted")
                  ((and
                     align-needed
                     (not *swcad-title-last-native-gmtitle-placement-used*)
                     (swcad-title-native-placement-substantial-move-p align-dx align-dy)
                   )
                    "native-frame-only-moved-unverified")
                  (pending-pair "native-frame-only-apply")
                  (T "native-frame-only-finalize")
                )
              )
              (setq marker-ok
                (swcad-title-mark-native-exemplar-pair
                  gmtitle-title-ename
                  gmtitle-frame-ename
                  frame-block
                  marker-role
                )
              )
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (if (equal (strcase marker-role) "CLONE")
                (swcad-title-princ-line "Cloned GMTITLE was finalized for frame-only source; native upgrade is still required for double-click behavior.")
                (swcad-title-princ-line "Existing/default native GMTITLE was used for frame-only source.")
              )
              (if (equal (strcase marker-role) "NATIVE-FRAME-ONLY-MOVED-UNVERIFIED")
                (progn
                  (swcad-title-princ-line "WARNING: frame-only GMTITLE was moved by LISP after creation because native placement was not captured.")
                  (swcad-title-princ-line "This pair is not trusted for GMPOWEREDIT/double-click behavior until recreated with native placement.")
                )
              )
              (if (equal (strcase marker-role) "NATIVE-FRAME-ONLY-MOVED-ACCEPTED")
                (progn
                  (swcad-title-princ-line "title-missing/frame-only exception handling: GMTITLE was created at the default location and moved to the old source frame.")
                  (swcad-title-princ-line "This is allowed only for verified title-missing/frame-only sheets; run final verification after conversion.")
                )
              )
              (swcad-title-princ-line
                (strcat "GMTITLE marker set: " (if marker-ok "yes" "no") ", role=" marker-role)
              )
              (swcad-title-princ-line
                (strcat
                  "Native GMTITLE aligned to source frame: moved="
                  (itoa align-count)
                  ", dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line (strcat "Attributes set: " (itoa attr-count)))
              (swcad-title-princ-line "Old frame-only insert deleted: yes")
              (swcad-title-princ-line (strcat "Old SOLIDWORKS sheet residue deleted: " (itoa deleted-residue-count)))
              (if (equal (strcase marker-role) "CLONE")
                (progn
                  (swcad-title-apply-result "FINALIZED_CLONED_FRAME_ONLY_GMTITLE_TRANSFER")
                  (swcad-title-princ-line "다음: 최종 더블클릭 확인 전에 SWTITLESTATUS를 실행하고, 남은 A2/A3/A4 교체 후보를 SWTITLECONVERTNEXT로 처리하세요.")
                )
                (progn
                  (swcad-title-apply-result "FINALIZED_FRAME_ONLY_GMTITLE_TRANSFER")
                  (swcad-title-princ-line "최종 수동 확인: GMTITLE 제목블록을 더블클릭해서 표 편집창이 열리는지 확인하세요.")
                )
              )
              )
            )
          )
        )
        (progn
          (if geometry-warning
            (swcad-title-apply-result "ABORT_EXISTING_FRAME_ONLY_GMTITLE_INVALID_FRAME_GEOMETRY")
            (if raw-selection-warning
              (swcad-title-apply-result "ABORT_EXISTING_FRAME_ONLY_GMTITLE_RAW_BBOX_EXTRA_OBJECTS")
              (swcad-title-apply-result "ABORT_EXISTING_FRAME_ONLY_GMTITLE_NOT_FOUND")
            )
          )
          (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
          (swcad-title-princ-line (strcat "Expected title block: " title-block))
          (swcad-title-princ-line (strcat "Actual title block: " (if (> (strlen actual-title-name) 0) actual-title-name "<missing>")))
          (swcad-title-princ-line (strcat "Actual frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
          (if geometry-warning
            (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
          )
          (if raw-selection-warning
            (progn
              (swcad-title-princ-line (strcat "Frame raw selection warning: " raw-selection-warning))
              (swcad-title-princ-line "Visible A4 frame size is usable, but extra dependency/block geometry is attached outside the frame.")
            )
          )
          (if pending-pair
            (progn
              (setq deleted-new-count (swcad-title-delete-ename-list (list gmtitle-title-ename gmtitle-frame-ename)))
              (swcad-title-princ-line (strcat "Removed pending invalid GMTITLE inserts: " (itoa deleted-new-count)))
            )
          )
          (swcad-title-princ-line "같은 크기의 native GMTITLE이 형상 검사를 통과하기 전까지 이 용지 크기의 빠른 변환을 계속하지 마세요.")
          (swcad-title-princ-line "감지된 DR 용지로 native GMTITLE 1장을 만들고 bbox를 먼저 확인하세요. 같은 용지가 계속 실패하면 GMTITLE 용지 선택값/형식 정의를 점검하세요.")
          (swcad-title-princ-line "기존 frame-only 시트 내용은 삭제하지 않았습니다.")
        )
      )
    )
  )
  (swcad-title-clear-pending-native-gmtitle-pair)
  (swcad-title-princ-line "Note: frame-only finalize is for sheets with an old frame but no old source title block.")
  (swcad-title-princ-line "Note: for native-safe use, create GMTITLE with Frame positioning ON and let it accept the sheet lower-left placement point.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-title-missing-outline-apply (/ *error* source-frame source-frame-ename source-frame-data source-frame-bbox source-frame-block source-sheet normalized-sheet frame-block placement-point answer doc gmtitle-result new-title-ename new-frame-ename new-enames new-title-active new-frame-active actual-title-name actual-frame-name new-effective-bbox geometry-warning raw-selection-warning bbox-ok raw-definition-risk residue-records residue-handles deleted-residue-count align-result align-count align-dx align-dy align-needed native-before native-after title-deleted marker-ok frame-verified deleted-new-count)
  (setq new-title-active nil)
  (setq new-frame-active nil)
  (defun *error* (msg)
    (if doc
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
    )
    (if new-title-active
      (swcad-title-delete-ename new-title-ename)
    )
    (if new-frame-active
      (swcad-title-delete-ename new-frame-ename)
    )
    (if msg
      (swcad-title-princ-line (strcat "title-missing native 도면틀 변환 오류: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_TITLE_MISSING_NATIVE_FRAME_TRANSFER")
    (swcad-title-close-log)
    (princ)
  )
  (setq *swcad-title-last-apply-status* nil)
  (setq source-frame (car (swcad-title-frame-only-source-candidates)))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-data (if source-frame (cadr source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame (cadddr source-frame) nil))
  (setq source-sheet (if source-frame (nth 5 source-frame) nil))
  (setq normalized-sheet (swcad-title-normalized-sheet-size source-sheet))
  (setq frame-block (swcad-title-target-frame-block-name-for-sheet source-sheet))
  (setq placement-point (swcad-title-bbox-lower-left-point source-frame-bbox))
  (setq raw-definition-risk (if frame-block (swcad-title-frame-definition-raw-bbox-risk-record frame-block) nil))
  (swcad-title-open-apply-log)
  (swcad-title-princ-line "----- SWTITLECONVERT 내부 title-missing native 도면틀 변환 -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-loaded-version)
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "원본 표제란 없는 도면틀: "
      (if source-frame-data
        (strcat
          "핸들="
          (swcad-title-string (swcad-title-dxf-value source-frame-data 5))
          ", 블록="
          (swcad-title-string source-frame-block)
          ", sheet="
          (swcad-title-string source-sheet)
          ", 범위="
          (swcad-title-bbox-string source-frame-bbox)
        )
        "<없음>"
      )
    )
  )
  (cond
    ((not source-frame-bbox)
      (swcad-title-apply-result "ABORT_NO_FRAME_ONLY_SOURCE")
    )
    ((not (and normalized-sheet (wcmatch normalized-sheet "A1,A2,A3,A4")))
      (swcad-title-apply-result "ABORT_TITLE_MISSING_OUTLINE_UNAVAILABLE")
      (swcad-title-princ-line "이 경로는 용지 크기를 A1/A2/A3/A4로 판정할 수 있는 title-missing 시트에만 적용합니다.")
    )
    ((not (swcad-title-frame-name-matches-p frame-block (strcat "DR_" normalized-sheet "_Outline")))
      (swcad-title-apply-result "ABORT_TITLE_MISSING_OUTLINE_UNAVAILABLE")
      (swcad-title-princ-line (strcat "예상 도면틀이 " (strcat "DR_" normalized-sheet "_Outline") "이 아닙니다: " (swcad-title-string frame-block)))
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "쓰기 가능한 작업복사본을 연 뒤 다시 실행하세요.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Documents/CAD tool/work 아래 작업복사본에서만 실행합니다.")
    )
    (raw-definition-risk
      (swcad-title-apply-result "ABORT_TITLE_MISSING_OUTLINE_UNAVAILABLE")
      (swcad-title-princ-line "DR 도면틀 정의 raw bbox 위험이 남아 있어 기존 원본 도면틀을 삭제하지 않습니다.")
      (swcad-title-print-frame-definition-raw-bbox-risk-records (list raw-definition-risk))
      (swcad-title-princ-line "먼저 SWTITLEPREPARE로 도면틀 정의를 복구/정규화하고 SWTITLESTATUS를 다시 확인하세요.")
    )
    ((not (and (swcad-title-block-exists-p frame-block) (not (swcad-title-target-frame-block-contaminated-p frame-block))))
      (swcad-title-apply-result "ABORT_TITLE_MISSING_OUTLINE_UNAVAILABLE")
      (swcad-title-princ-line (strcat "현재 도면 안의 " (swcad-title-string frame-block) " 블록 정의가 없거나 정규화되지 않았습니다."))
      (swcad-title-princ-line "먼저 SWTITLEPREPARE로 도면틀 정의를 정리하고 SWTITLESTATUS를 다시 확인하세요.")
    )
    ((swcad-title-script-active-p)
      (swcad-title-abort-interactive-gmtitle-script-active
        "title-missing 도면틀도 실제 GMTITLE 대화상자에서 native 도면틀/임시 제목블록 쌍을 만들어야 합니다."
      )
      (swcad-title-princ-line "기존 원본 도면틀과 시트 내용은 삭제하지 않았습니다.")
    )
    (T
      (swcad-title-princ-line "정책: 원본 표제란 부재가 검증된 시트도 실제 GMTITLE로 도면틀을 만듭니다.")
      (swcad-title-princ-line "GMTITLE이 임시로 만드는 DR_titlea_3rd는 native 도면틀 검증 후 삭제하여 최종 도면에는 남기지 않습니다.")
      (setq answer
        (if (or *swcad-title-batch-mode* *swcad-title-convert-next-mode*)
          "YES"
          (getstring T "\n표제란 없는 시트를 같은 크기 native DR_A*_Outline 도면틀로 교체하려면 YES를 입력하세요: ")
        )
      )
      (if (/= (strcase answer) "YES")
        (swcad-title-apply-result "ABORT_USER_CANCEL")
        (progn
          (swcad-title-print-gmtitle-dialog-selection-card frame-block placement-point)
          (setq gmtitle-result (swcad-title-run-native-gmtitle-prefer-commandline frame-block placement-point))
          (setq new-title-ename (car gmtitle-result))
          (setq new-frame-ename (cadr gmtitle-result))
          (setq new-enames (caddr gmtitle-result))
          (setq new-title-active (if new-title-ename T nil))
          (setq new-frame-active (if new-frame-ename T nil))
          (setq actual-title-name (if new-title-ename (swcad-title-effective-insert-name new-title-ename) ""))
          (setq actual-frame-name (if new-frame-ename (swcad-title-effective-insert-name new-frame-ename) ""))
          (if
            (not
              (and
                new-title-ename
                new-frame-ename
                (swcad-title-native-target-title-name-p actual-title-name)
                (swcad-title-frame-name-matches-p actual-frame-name frame-block)
              )
            )
            (progn
              (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
              (setq new-title-active nil)
              (setq new-frame-active nil)
              (swcad-title-apply-result "ABORT_TITLE_MISSING_NATIVE_GMTITLE_NOT_CREATED")
              (swcad-title-princ-line (strcat "예상 도면틀: " frame-block))
              (swcad-title-princ-line (strcat "예상 임시 제목블록: " (swcad-title-target-title-block-name)))
              (swcad-title-princ-line (strcat "실제 도면틀: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<없음>")))
              (swcad-title-princ-line (strcat "실제 제목블록: " (if (> (strlen actual-title-name) 0) actual-title-name "<없음>")))
              (swcad-title-princ-line (strcat "잘못 생성된 새 INSERT 삭제: " (itoa deleted-new-count)))
              (swcad-title-princ-line "기존 원본 도면틀은 삭제하지 않았습니다.")
            )
            (progn
              (setq doc (swcad-title-doc))
              (vl-catch-all-apply 'vla-StartUndoMark (list doc))
              (setq align-result (swcad-title-align-gmtitle-to-frame-bbox new-title-ename new-frame-ename source-frame-bbox))
              (setq align-count (car align-result))
              (setq align-dx (cadr align-result))
              (setq align-dy (caddr align-result))
              (setq align-needed (or (> (swcad-title-abs align-dx) 0.0001) (> (swcad-title-abs align-dy) 0.0001)))
              (setq new-effective-bbox (swcad-title-frame-reference-effective-bbox new-frame-ename frame-block))
              (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block new-effective-bbox))
              (setq raw-selection-warning (swcad-title-frame-reference-raw-selection-warning new-frame-ename frame-block new-effective-bbox))
              (setq bbox-ok (swcad-title-bbox-nearly-same-p source-frame-bbox new-effective-bbox 2.0))
              (setq native-before
                (swcad-title-internal-native-link-kinds-p
                  (swcad-title-native-link-target-kinds new-frame-ename)
                )
              )
              (swcad-title-insert-log-label "새 native GMTITLE 임시 제목블록" new-title-ename)
              (swcad-title-insert-log-label "새 native GMTITLE 도면틀" new-frame-ename)
              (swcad-title-princ-line
                (strcat
                  "새 native GMTITLE 정렬: moved="
                  (itoa align-count)
                  ", dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line (strcat "새 도면틀 보이는 범위: " (swcad-title-bbox-string new-effective-bbox)))
              (cond
                ((and align-needed (< align-count 2))
                  (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
                  (setq new-title-active nil)
                  (setq new-frame-active nil)
                  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                  (setq doc nil)
                  (swcad-title-apply-result "ABORT_TITLE_MISSING_NATIVE_ALIGN_FAILED")
                  (swcad-title-princ-line (strcat "정렬 실패로 새 GMTITLE INSERT 삭제: " (itoa deleted-new-count)))
                  (swcad-title-princ-line "기존 원본 도면틀은 삭제하지 않았습니다.")
                )
                ((and
                   align-needed
                   (not *swcad-title-last-native-gmtitle-placement-used*)
                   (swcad-title-native-placement-substantial-move-p align-dx align-dy)
                 )
                  (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
                  (setq new-title-active nil)
                  (setq new-frame-active nil)
                  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                  (setq doc nil)
                  (swcad-title-apply-result "ABORT_TITLE_MISSING_NATIVE_PLACEMENT_REQUIRED")
                  (swcad-title-princ-line "GMTITLE이 원본 도면틀 왼쪽 아래 배치점을 사용하지 않아 큰 MOVE 정렬이 필요했습니다.")
                  (swcad-title-princ-line (strcat "신뢰하지 않는 새 GMTITLE INSERT 삭제: " (itoa deleted-new-count)))
                  (swcad-title-princ-line "기존 원본 도면틀은 삭제하지 않았습니다.")
                )
                ((or geometry-warning raw-selection-warning (not bbox-ok))
                  (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
                  (setq new-title-active nil)
                  (setq new-frame-active nil)
                  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                  (setq doc nil)
                  (swcad-title-apply-result "ABORT_TITLE_MISSING_NATIVE_INVALID_GEOMETRY")
                  (if geometry-warning
                    (swcad-title-princ-line (strcat "도면틀 형상 경고: " geometry-warning))
                  )
                  (if raw-selection-warning
                    (swcad-title-princ-line (strcat "도면틀 선택 범위 경고: " raw-selection-warning))
                  )
                  (if (not bbox-ok)
                    (swcad-title-princ-line "새 도면틀 범위가 원본 도면틀 범위와 충분히 일치하지 않습니다.")
                  )
                  (swcad-title-princ-line (strcat "검증 실패 새 GMTITLE INSERT 삭제: " (itoa deleted-new-count)))
                  (swcad-title-princ-line "기존 원본 시트는 삭제하지 않았습니다.")
                )
                ((not native-before)
                  (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
                  (setq new-title-active nil)
                  (setq new-frame-active nil)
                  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                  (setq doc nil)
                  (swcad-title-apply-result "ABORT_TITLE_MISSING_FRAME_NOT_NATIVE")
                  (swcad-title-princ-line "새 GMTITLE 도면틀에 내부 native 인식 링크가 없어 성공으로 처리하지 않습니다.")
                  (swcad-title-princ-line (strcat "검증 실패 새 GMTITLE INSERT 삭제: " (itoa deleted-new-count)))
                  (swcad-title-princ-line "기존 원본 도면틀은 삭제하지 않았습니다.")
                )
                (T
                  (setq title-deleted (if (swcad-title-delete-ename new-title-ename) T nil))
                  (if title-deleted
                    (setq new-title-active nil)
                  )
                  (setq native-after
                    (and
                      title-deleted
                      (swcad-title-internal-native-link-kinds-p
                        (swcad-title-native-link-target-kinds new-frame-ename)
                      )
                    )
                  )
                  (setq marker-ok
                    (if native-after
                      (swcad-title-set-exemplar-xdata new-frame-ename frame-block "native-title-missing-outline")
                      nil
                    )
                  )
                  (setq frame-verified
                    (and
                      marker-ok
                      (swcad-title-title-missing-outline-frame-record-p
                        (list
                          new-frame-ename
                          frame-block
                          (swcad-title-ename-handle new-frame-ename)
                          new-effective-bbox
                        )
                      )
                    )
                  )
                  (if (not frame-verified)
                    (progn
                      (if new-title-active
                        (progn
                          (swcad-title-delete-ename new-title-ename)
                          (setq new-title-active nil)
                        )
                      )
                      (if new-frame-active
                        (progn
                          (swcad-title-delete-ename new-frame-ename)
                          (setq new-frame-active nil)
                        )
                      )
                      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                      (setq doc nil)
                      (swcad-title-apply-result "ABORT_TITLE_MISSING_NATIVE_FRAME_NOT_PERSISTENT")
                      (swcad-title-princ-line "임시 제목블록 삭제 후 도면틀의 native 링크/형상 검증이 유지되지 않아 중단했습니다.")
                      (swcad-title-princ-line "기존 원본 도면틀은 삭제하지 않았습니다.")
                    )
                    (progn
                      (setq residue-records (swcad-title-source-sheet-residue-records source-frame-bbox nil source-frame-ename))
                      (setq residue-handles (swcad-title-residue-record-handles residue-records))
                      (swcad-title-print-residue-records "삭제 예정 기존 SolidWorks 시트 잔여물:" residue-records)
                      (setq new-frame-active nil)
                      (swcad-title-delete-ename source-frame-ename)
                      (setq deleted-residue-count (swcad-title-delete-handle-list residue-handles))
                      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                      (setq doc nil)
                      (swcad-title-apply-result "FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER")
                      (swcad-title-princ-line "임시 DR_titlea_3rd 제목블록 삭제: yes")
                      (swcad-title-princ-line "제목블록 삭제 후 native 도면틀 링크 유지: yes")
                      (swcad-title-princ-line (strcat "native title-missing 도면틀 marker set: " (if marker-ok "yes" "no")))
                      (swcad-title-princ-line (strcat "새 " (swcad-title-string frame-block) " 도면틀은 원본 위치/크기에 맞게 생성되었습니다."))
                      (swcad-title-princ-line "최종 도면에는 원본에 없던 DR_titlea_3rd 제목블록을 남기지 않았습니다.")
                      (swcad-title-princ-line "기존 원본 frame INSERT 삭제: yes")
                      (swcad-title-princ-line (strcat "기존 시트 잔여물 삭제: " (itoa deleted-residue-count)))
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  (if doc
    (vl-catch-all-apply 'vla-EndUndoMark (list doc))
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-title-missing-outline-all (/ count index old-batch-mode old-allow-interactive before-count after-count apply-result remaining)
  (setq count (length (swcad-title-frame-only-source-candidates)))
  (setq old-batch-mode *swcad-title-batch-mode*)
  (setq old-allow-interactive *swcad-title-allow-batch-interactive-native-gmtitle*)
  (cond
    ((= count 0)
      (swcad-title-apply-result "STOP_NO_MORE_FRAME_ONLY_SOURCE")
    )
    ((not (swcad-title-gmtitle-autoselect-available-p))
      (swcad-title-apply-result "ABORT_GMTITLE_AUTOSELECT_UNAVAILABLE")
      (swcad-title-princ-line "GMTITLE 고정 컨트롤 자동 선택기를 사용할 수 없어 title-missing 연속 native 변환을 시작하지 않습니다.")
      (swcad-title-princ-line "기존 원본 도면틀과 시트 내용은 삭제하지 않았습니다.")
    )
    (T
      (setq *swcad-title-batch-mode* T)
      (setq *swcad-title-allow-batch-interactive-native-gmtitle* T)
      (setq index 1)
      (while (<= index count)
        (setq before-count (length (swcad-title-frame-only-source-candidates)))
        (if (= before-count 0)
          (setq index (+ count 1))
          (progn
            (swcad-title-princ-line
              (strcat
                "--- SWTITLECONVERTNEXT title-missing 도면틀 "
                (itoa index)
                " / "
                (itoa count)
                " ---"
              )
            )
            (setq apply-result
              (vl-catch-all-apply 'swcad-title-transfer-title-missing-outline-apply nil)
            )
            (setq after-count (length (swcad-title-frame-only-source-candidates)))
            (if
              (or
                (vl-catch-all-error-p apply-result)
                (not (equal *swcad-title-last-apply-status* "FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER"))
                (>= after-count before-count)
              )
              (progn
                (if (vl-catch-all-error-p apply-result)
                  (swcad-title-princ-line
                    (strcat
                      "title-missing 연속 변환 오류: "
                      (vl-catch-all-error-message apply-result)
                    )
                  )
                )
                (swcad-title-princ-line
                  (strcat
                    "title-missing 연속 변환 중단 상태: "
                    (swcad-title-string *swcad-title-last-apply-status*)
                  )
                )
                (setq index (+ count 1))
              )
            )
          )
        )
        (setq index (+ index 1))
      )
    )
  )
  (setq *swcad-title-batch-mode* old-batch-mode)
  (setq *swcad-title-allow-batch-interactive-native-gmtitle* old-allow-interactive)
  (setq remaining (length (swcad-title-frame-only-source-candidates)))
  (if (and (> count 0) (= remaining 0))
    (swcad-title-apply-result "OK_TITLE_MISSING_OUTLINE_BATCH_COMPLETE")
    (if (> remaining 0)
      (swcad-title-princ-line
      (strcat
        "title-missing 연속 변환 후 남은 도면틀 시트: "
        (itoa remaining)
      )
      )
    )
  )
  (swcad-title-write-title-missing-batch-summary
    count
    remaining
    *swcad-title-last-apply-status*
  )
  (princ)
)

(defun swcad-title-transfer-frame-only-apply (/ *error* source-frame source-frame-bbox source-sheet frame-block risk-message answer placement-point gmtitle-result gmtitle-title-ename gmtitle-frame-ename finalize-result)
  (defun *error* (msg)
    (swcad-title-open-apply-log)
    (if msg
      (swcad-title-princ-line (strcat "Error: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_FRAME_ONLY_NATIVE_APPLY")
    (swcad-title-close-log)
    (princ)
  )
  (setq *swcad-title-last-apply-status* nil)
  (setq source-frame (car (swcad-title-frame-only-source-candidates)))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-sheet (if source-frame (nth 5 source-frame) nil))
  (setq frame-block (swcad-title-target-frame-block-name-for-sheet source-sheet))
  (setq placement-point (swcad-title-bbox-lower-left-point source-frame-bbox))
  (swcad-title-open-apply-log)
  (swcad-title-princ-line "----- SWTITLECONVERT 내부 첫 frame-only native 변환 -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Next frame-only sheet: "
      (if source-frame
        (strcat
          "sheet="
          (swcad-title-string source-sheet)
          ", target="
          (swcad-title-string frame-block)
          ", bbox="
          (swcad-title-bbox-string source-frame-bbox)
        )
        "<none>"
      )
    )
  )
  (cond
    ((not source-frame)
      (swcad-title-apply-result "STOP_NO_MORE_FRAME_ONLY_SOURCE")
      (swcad-title-close-log)
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before applying.")
      (swcad-title-close-log)
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before applying.")
      (swcad-title-close-log)
    )
    ((not frame-block)
      (swcad-title-apply-result "ABORT_FRAME_ONLY_TARGET_UNKNOWN")
      (swcad-title-princ-line "대상 DR_A*_Outline 도면틀 블록을 추론하지 못했습니다.")
      (swcad-title-close-log)
    )
    (T
      (if (setq risk-message (swcad-title-title-missing-outline-risk-message source-frame frame-block))
        (progn
          (swcad-title-princ-line (strcat "title-missing/frame-only native template caution: " risk-message))
          (swcad-title-princ-line "새 GMTITLE 도면틀 bbox를 검사한 뒤에만 기존 title-missing/frame-only 내용을 제거합니다.")
        )
      )
      (setq answer
        (swcad-title-auto-next-answer-or-prompt
          "YES"
          "frame-only native GMTITLE 1장 생성"
          "\n다음 frame-only 시트에 native GMTITLE 1장을 만들고 기존 도면틀을 제거하려면 YES를 입력하세요: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (swcad-title-apply-result "ABORT_USER_CANCEL")
          (swcad-title-close-log)
        )
        (progn
          (swcad-title-princ-line "이 frame-only 시트에 대해 native GMTITLE 창이 한 번 열립니다.")
          (swcad-title-princ-line (strcat "  용지/형식: " frame-block))
          (swcad-title-princ-line (strcat "  제목블록: " (swcad-title-target-title-block-name)))
          (swcad-title-princ-line "  켜둘 옵션: Frame positioning")
          (swcad-title-princ-line "  꺼둘 옵션: Object move")
          (if placement-point
            (swcad-title-princ-line (strcat "  삽입점을 물으면 사용할 왼쪽 아래 배치점: " (swcad-title-point-string placement-point)))
          )
          (swcad-title-princ-line "  마무리 단계에서 새 GMTITLE 도면틀 왼쪽 아래를 기존 도면틀 왼쪽 아래에 맞춥니다.")
          (swcad-title-close-log)
          (setq gmtitle-result (swcad-title-run-native-gmtitle-prefer-commandline frame-block placement-point))
          (setq gmtitle-title-ename (car gmtitle-result))
          (setq gmtitle-frame-ename (cadr gmtitle-result))
          (if (and gmtitle-title-ename gmtitle-frame-ename)
            (progn
              (swcad-title-set-pending-native-gmtitle-pair
                gmtitle-title-ename
                gmtitle-frame-ename
                frame-block
              )
              (setq finalize-result (vl-catch-all-apply 'swcad-title-transfer-frame-only-finalize nil))
              (if (vl-catch-all-error-p finalize-result)
                (progn
                  (swcad-title-open-apply-log)
                  (swcad-title-princ-line "----- SWTITLECONVERT frame-only finalize 오류 -----")
                  (swcad-title-princ-line (vl-catch-all-error-message finalize-result))
                  (swcad-title-apply-result "ERROR_FRAME_ONLY_NATIVE_FINALIZE")
                  (swcad-title-close-log)
                )
              )
            )
            (progn
              (swcad-title-open-apply-log)
              (swcad-title-princ-line "----- SWTITLECONVERT frame-only native GMTITLE 실패 -----")
              (swcad-title-princ-line (strcat "예상 도면틀 블록: " frame-block))
              (swcad-title-princ-line (strcat "예상 제목블록: " (swcad-title-target-title-block-name)))
              (swcad-title-apply-result "ABORT_FRAME_ONLY_NATIVE_GMTITLE_NOT_CREATED")
              (swcad-title-princ-line "기존 frame-only 시트 내용은 삭제하지 않았습니다.")
              (swcad-title-close-log)
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun swcad-title-transfer-batch-run (count / index source apply-result)
  (setq index 1)
  (while (<= index count)
    (setq source (swcad-title-transfer-source-bbox))
    (if source
      (progn
        (princ
          (strcat
            "\n--- SWTITLECONVERT 내부 표제란 시트 "
            (itoa index)
            " / "
            (itoa count)
            " ---"
          )
        )
        (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-apply nil))
        (if (vl-catch-all-error-p apply-result)
          (progn
            (setq *swcad-title-last-apply-status* "ERROR_BATCH_APPLY")
            (princ
              (strcat
                "\nBatch apply error: "
                (vl-catch-all-error-message apply-result)
              )
            )
            (swcad-title-close-log)
          )
        )
        (if
          (not
            (member
              *swcad-title-last-apply-status*
              '("APPLIED_TITLE_TRANSFER" "ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER")
            )
          )
          (progn
            (princ
              (strcat
                "\nBatch stopped after status: "
                (swcad-title-string *swcad-title-last-apply-status*)
              )
            )
            (setq index count)
          )
        )
      )
      (progn
        (setq *swcad-title-last-apply-status* "STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        (swcad-title-princ-line "Result: STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        (setq index count)
      )
    )
    (setq index (+ index 1))
  )
)

(defun swcad-title-transfer-native-autoselect-all (/ count old-batch-mode old-allow-interactive batch-result remaining)
  (setq count (length (swcad-title-source-title-candidates)))
  (cond
    ((= count 0)
      (swcad-title-apply-result "STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
    )
    ((not (swcad-title-gmtitle-autoselect-available-p))
      (swcad-title-apply-result "ABORT_GMTITLE_AUTOSELECT_UNAVAILABLE")
      (swcad-title-princ-line "GMTITLE 고정 컨트롤 자동 선택기를 사용할 수 없어 연속 native 변환을 시작하지 않습니다.")
    )
    (T
      (swcad-title-princ-line
        (strcat
          "SWTITLECONVERTNEXT native 자동 일괄 변환 시작: 남은 표제란 시트="
          (itoa count)
        )
      )
      (swcad-title-princ-line "각 시트마다 GstarCAD가 새 native link를 발급하며, 화면 좌표나 preserve-copy 공유 핸들을 사용하지 않습니다.")
      (setq old-batch-mode *swcad-title-batch-mode*)
      (setq old-allow-interactive *swcad-title-allow-batch-interactive-native-gmtitle*)
      (setq *swcad-title-batch-mode* T)
      (setq *swcad-title-allow-batch-interactive-native-gmtitle* T)
      (setq batch-result
        (vl-catch-all-apply 'swcad-title-transfer-batch-run (list count))
      )
      (setq *swcad-title-batch-mode* old-batch-mode)
      (setq *swcad-title-allow-batch-interactive-native-gmtitle* old-allow-interactive)
      (if (vl-catch-all-error-p batch-result)
        (progn
          (swcad-title-apply-result "ERROR_NATIVE_AUTOSELECT_BATCH")
          (swcad-title-princ-line
            (strcat
              "native 자동 일괄 변환 오류: "
              (vl-catch-all-error-message batch-result)
            )
          )
        )
        (progn
          (setq remaining (length (swcad-title-source-title-candidates)))
          (swcad-title-princ-line
            (strcat
              "native 자동 일괄 변환 후 남은 원본 표제란 시트: "
              (itoa remaining)
            )
          )
          (if (= remaining 0)
            (swcad-title-apply-result "OK_NATIVE_AUTOSELECT_BATCH_COMPLETE")
            (swcad-title-princ-line
              (strcat
                "변환이 중간 상태에서 멈췄습니다. 마지막 상태="
                (swcad-title-string *swcad-title-last-apply-status*)
              )
            )
          )
        )
      )
    )
  )
  (setq remaining (length (swcad-title-source-title-candidates)))
  (swcad-title-write-native-autoselect-batch-summary
    count
    remaining
    *swcad-title-last-apply-status*
  )
  (princ)
)

(defun swcad-title-transfer-batch (/ count answer old-batch-mode batch-result)
  (setq count (getint "\nNumber of SOLIDWORKS title blocks/sheets to process with native GMTITLE <1>: "))
  (if (not count)
    (setq count 1)
  )
  (if (< count 1)
    (setq count 1)
  )
  (setq answer
    (getstring
      T
      (strcat
        "\n처리할 시트 수 "
        (itoa count)
        "장입니다. 각 시트마다 native GMTITLE 창이 한 번씩 열립니다. 계속하려면 YES를 입력하세요: "
      )
    )
  )
  (if (/= (strcase answer) "YES")
    (progn
      (swcad-title-princ-line "Result: ABORT_USER_CANCEL")
      (princ)
    )
    (progn
      (setq old-batch-mode *swcad-title-batch-mode*)
      (setq *swcad-title-batch-mode* T)
      (setq batch-result (vl-catch-all-apply 'swcad-title-transfer-batch-run (list count)))
      (setq *swcad-title-batch-mode* old-batch-mode)
      (if (vl-catch-all-error-p batch-result)
        (progn
          (setq *swcad-title-last-apply-status* "ERROR_BATCH_FATAL")
          (princ
            (strcat
              "\nBatch fatal error: "
              (vl-catch-all-error-message batch-result)
            )
          )
        )
      )
      (princ "\n내부 변환 일괄 처리가 끝났습니다. SWTITLEVERIFY를 실행한 뒤 새 제목블록을 더블클릭해 표 편집창을 확인하세요.")
      (princ)
    )
  )
)

(defun swcad-title-transfer-clone-apply (/ answer clone-result finalize-result)
  (setq answer
    (if *swcad-title-batch-mode*
      "YES"
      (getstring
        T
        "\n검증된 native GMTITLE 쌍을 복제하고 값을 채운 뒤 다음 기존 표제란 내용을 제거하려면 YES를 입력하세요: "
      )
    )
  )
  (if (/= (strcase answer) "YES")
    (progn
      (setq *swcad-title-last-apply-status* "ABORT_USER_CANCEL")
      (swcad-title-princ-line "Result: ABORT_USER_CANCEL")
    )
    (progn
      (setq clone-result (vl-catch-all-apply 'swcad-title-create-cloned-gmtitle-for-next-source nil))
      (if (or (vl-catch-all-error-p clone-result) (not clone-result))
        (progn
          (setq *swcad-title-last-apply-status* "ABORT_CLONE_GMTITLE_PAIR_FAILED")
          (swcad-title-open-apply-log)
          (swcad-title-princ-line "----- SWTITLECONVERT 내부 native GMTITLE clone 적용 -----")
          (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
          (swcad-title-print-work-copy-status)
          (if (vl-catch-all-error-p clone-result)
            (swcad-title-princ-line
              (strcat "clone 오류: " (vl-catch-all-error-message clone-result))
            )
            (swcad-title-princ-line "clone 오류: 검증된 native GMTITLE 기준 객체 또는 대상 도면틀을 만들 수 없습니다.")
          )
          (if *swcad-title-last-clone-failure*
            (swcad-title-princ-line
              (strcat "clone 실패 상세: " *swcad-title-last-clone-failure*)
            )
          )
          (swcad-title-princ-line "동일 크기 native clone에는 같은 DR_A*_Outline 용지 크기의 실제 GMTITLE 기준 객체가 1개 필요합니다.")
          (swcad-title-princ-line "이 크기의 첫 시트라면 먼저 native GMTITLE로 한 번 만든 뒤 빠른 clone 일괄 변환을 다시 실행하세요.")
          (swcad-title-princ-line "대상 도면틀 블록 정의 확인:")
          (swcad-title-print-frame-def-check-lines)
          (swcad-title-apply-result "ABORT_CLONE_GMTITLE_PAIR_FAILED")
          (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
          (swcad-title-close-log)
        )
        (progn
          (swcad-title-set-pending-gmtitle-pair
            (car clone-result)
            (cadr clone-result)
            (caddr clone-result)
            "clone"
          )
          (setq finalize-result (vl-catch-all-apply 'swcad-title-transfer-finalize nil))
          (if (vl-catch-all-error-p finalize-result)
            (progn
              (setq *swcad-title-last-apply-status* "ERROR_CLONE_FINALIZE")
              (swcad-title-open-apply-log)
              (swcad-title-princ-line "----- SWTITLECONVERT 내부 clone 마무리 오류 -----")
              (swcad-title-princ-line (vl-catch-all-error-message finalize-result))
              (swcad-title-apply-result "ERROR_CLONE_FINALIZE")
              (swcad-title-close-log)
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun swcad-title-transfer-clone-batch-run (count / index source apply-result target-frame-block)
  (setq index 1)
  (while (<= index count)
    (setq source (swcad-title-transfer-source-bbox))
    (if source
      (progn
        (setq target-frame-block (swcad-title-next-fast-target-frame-block))
        (swcad-title-princ-text
          (strcat
            "\n--- internal fast title clone phase sheet "
            (itoa index)
            " / "
            (itoa count)
            " ---"
          )
        )
        (if
          (and
            target-frame-block
            (not (swcad-title-native-example-pair-for-frame-block target-frame-block))
          )
          (progn
            (setq *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
            (swcad-title-princ-text
              (strcat
                "\nClone batch paused: "
                target-frame-block
                " needs one real native GMTITLE exemplar first."
              )
            )
            (swcad-title-princ-text "\nSWTITLESTATUS로 필요한 용지 크기를 확인한 뒤 SWTITLECONVERTNEXT로 첫 native GMTITLE 단계를 진행하세요.")
            (setq index count)
          )
          (progn
            (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-clone-apply nil))
            (if (vl-catch-all-error-p apply-result)
              (progn
                (setq *swcad-title-last-apply-status* "ERROR_CLONE_BATCH_APPLY")
                (swcad-title-princ-text
                  (strcat
                    "\nClone batch apply error: "
                    (vl-catch-all-error-message apply-result)
                  )
                )
                (swcad-title-close-log)
              )
            )
            (if
              (not
                (member
                  *swcad-title-last-apply-status*
                  '("FINALIZED_EXISTING_GMTITLE_TRANSFER" "FINALIZED_CLONED_GMTITLE_TRANSFER" "ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER")
                )
              )
              (progn
                (princ
                  (strcat
                    "\nClone batch stopped after status: "
                    (swcad-title-string *swcad-title-last-apply-status*)
                  )
                )
                (setq index count)
              )
            )
          )
        )
      )
      (progn
        (setq *swcad-title-last-apply-status* "STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        (swcad-title-princ-line "Result: STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        (setq index count)
      )
    )
    (setq index (+ index 1))
  )
)

(defun swcad-title-transfer-clone-batch (/ count answer old-batch-mode batch-result)
  (setq count (getint "\nNumber of remaining SOLIDWORKS title blocks/sheets to process by native clone <1>: "))
  (if (not count)
    (setq count 1)
  )
  (if (< count 1)
    (setq count 1)
  )
  (setq answer
    (getstring
      T
      (strcat
        "\n처리할 시트 수 "
        (itoa count)
        "장입니다. 검증된 native GMTITLE 쌍 복제로 처리하려면 YES를 입력하세요: "
      )
    )
  )
  (if (/= (strcase answer) "YES")
    (progn
      (swcad-title-princ-line "Result: ABORT_USER_CANCEL")
      (princ)
    )
    (progn
      (setq old-batch-mode *swcad-title-batch-mode*)
      (setq *swcad-title-batch-mode* T)
      (setq batch-result (vl-catch-all-apply 'swcad-title-transfer-clone-batch-run (list count)))
      (setq *swcad-title-batch-mode* old-batch-mode)
      (if (vl-catch-all-error-p batch-result)
        (progn
          (setq *swcad-title-last-apply-status* "ERROR_CLONE_BATCH_FATAL")
          (princ
            (strcat
              "\nClone batch fatal error: "
              (vl-catch-all-error-message batch-result)
            )
          )
        )
      )
      (princ "\n내부 빠른 표제란 복제 단계가 끝났습니다. 전체 확인은 SWTITLEVERIFY로 진행하세요.")
      (princ)
    )
  )
)

(defun swcad-title-transfer-frame-only-clone-apply (/ answer source-frame target-frame-block risk-message clone-result finalize-result)
  (setq answer
    (if *swcad-title-batch-mode*
      "YES"
      (getstring
        T
        "\n검증된 GMTITLE 쌍을 복제해 다음 frame-only 시트에 배치하고 기존 도면틀을 제거하려면 YES를 입력하세요: "
      )
    )
  )
  (if (/= (strcase answer) "YES")
    (progn
      (setq *swcad-title-last-apply-status* "ABORT_USER_CANCEL")
      (swcad-title-princ-line "Result: ABORT_USER_CANCEL")
    )
    (progn
      (setq source-frame (car (swcad-title-frame-only-source-candidates)))
      (if (not source-frame)
        (progn
          (setq *swcad-title-last-apply-status* "STOP_NO_MORE_FRAME_ONLY_SOURCE")
          (swcad-title-princ-line "Result: STOP_NO_MORE_FRAME_ONLY_SOURCE")
        )
        (progn
          (setq target-frame-block (swcad-title-target-frame-block-name-for-sheet (nth 5 source-frame)))
          (setq clone-result
            (vl-catch-all-apply
              'swcad-title-create-cloned-gmtitle-for-frame-only-source
              (list source-frame)
            )
          )
          (if (or (vl-catch-all-error-p clone-result) (not clone-result))
            (progn
              (setq *swcad-title-last-apply-status* "ABORT_FRAME_ONLY_CLONE_FAILED")
              (swcad-title-open-apply-log)
              (swcad-title-princ-line "----- SWTITLECONVERT 내부 frame-only clone 적용 -----")
              (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
              (swcad-title-print-work-copy-status)
              (if (vl-catch-all-error-p clone-result)
                (swcad-title-princ-line
                  (strcat "Frame-only clone error: " (vl-catch-all-error-message clone-result))
                )
                (swcad-title-princ-line "Frame-only clone error: verified GMTITLE exemplar or target frame could not be created.")
              )
              (if *swcad-title-last-clone-failure*
                (swcad-title-princ-line
                  (strcat "Frame-only clone failure detail: " *swcad-title-last-clone-failure*)
                )
              )
              (if (setq risk-message (swcad-title-title-missing-outline-risk-message source-frame target-frame-block))
                (progn
                  (swcad-title-princ-line (strcat "title-missing native 템플릿 주의: " risk-message))
                  (swcad-title-princ-line "실제 같은 크기 DR_A*_Outline 기준 객체가 bbox 검사를 통과하기 전에는 이 용지 크기에 clone을 강제로 적용하지 마세요.")
                )
              )
              (swcad-title-princ-line "동일 크기 native clone에는 같은 DR_A*_Outline 용지 크기의 실제 GMTITLE 기준 객체가 1개 필요합니다.")
              (swcad-title-princ-line "첫 title-missing/frame-only 예외 시트는 SWTITLESTATUS로 상태를 확인한 뒤 SWTITLECONVERTNEXT로 진행하세요.")
              (swcad-title-princ-line "대상 도면틀 블록 정의 확인:")
              (swcad-title-print-frame-def-check-lines)
              (swcad-title-apply-result "ABORT_FRAME_ONLY_CLONE_FAILED")
              (swcad-title-princ-line "기존 frame-only 시트 내용은 삭제하지 않았습니다.")
              (swcad-title-close-log)
            )
            (progn
              (swcad-title-set-pending-gmtitle-pair
                (car clone-result)
                (cadr clone-result)
                (caddr clone-result)
                "clone"
              )
              (setq finalize-result (vl-catch-all-apply 'swcad-title-transfer-frame-only-finalize nil))
              (if (vl-catch-all-error-p finalize-result)
                (progn
                  (setq *swcad-title-last-apply-status* "ERROR_FRAME_ONLY_CLONE_FINALIZE")
                  (swcad-title-open-apply-log)
                  (swcad-title-princ-line "----- SWTITLECONVERT 내부 frame-only clone 마무리 오류 -----")
                  (swcad-title-princ-line (vl-catch-all-error-message finalize-result))
                  (swcad-title-apply-result "ERROR_FRAME_ONLY_CLONE_FINALIZE")
                  (swcad-title-close-log)
                )
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun swcad-title-transfer-frame-only-clone-batch-run (count / index source-frame apply-result target-frame-block risk-message)
  (setq index 1)
  (while (<= index count)
    (setq source-frame (car (swcad-title-frame-only-source-candidates)))
    (if source-frame
      (progn
        (setq target-frame-block (swcad-title-next-frame-only-target-frame-block))
        (princ
          (strcat
            "\n--- internal fast frame-only clone phase sheet "
            (itoa index)
            " / "
            (itoa count)
            " ---"
          )
        )
        (if
          (and
            target-frame-block
            (not (swcad-title-native-example-pair-for-frame-block target-frame-block))
          )
          (progn
            (setq *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
            (swcad-title-princ-text
              (strcat
                "\nFrame-only clone batch paused: "
                target-frame-block
                " needs one real native GMTITLE exemplar first."
              )
            )
            (if (setq risk-message (swcad-title-title-missing-outline-risk-message source-frame target-frame-block))
              (progn
                (swcad-title-princ-text (strcat "\ntitle-missing/frame-only native template caution: " risk-message))
                (swcad-title-princ-text "\n도면틀 형상 오류로 중단되면 clone/fast batch를 계속하지 말고 SWTITLESTATUS로 상태를 다시 확인하세요.")
              )
            )
            (swcad-title-princ-text "\nSWTITLESTATUS로 title-missing/frame-only 대상을 확인한 뒤 SWTITLECONVERTNEXT로 같은 크기 DR 도면틀-only 변환 단계를 진행하세요.")
            (setq index count)
          )
          (progn
            (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-frame-only-clone-apply nil))
            (if (vl-catch-all-error-p apply-result)
              (progn
                (setq *swcad-title-last-apply-status* "ERROR_FRAME_ONLY_CLONE_BATCH_APPLY")
                (princ
                  (strcat
                    "\nFrame-only clone batch apply error: "
                    (vl-catch-all-error-message apply-result)
                  )
                )
                (swcad-title-close-log)
              )
            )
            (if
              (not
                (member
                  *swcad-title-last-apply-status*
                  '("FINALIZED_FRAME_ONLY_GMTITLE_TRANSFER" "FINALIZED_CLONED_FRAME_ONLY_GMTITLE_TRANSFER")
                )
              )
              (progn
                (princ
                  (strcat
                    "\nFrame-only clone batch stopped after status: "
                    (swcad-title-string *swcad-title-last-apply-status*)
                  )
                )
                (setq index count)
              )
            )
          )
        )
      )
      (progn
        (setq *swcad-title-last-apply-status* "STOP_NO_MORE_FRAME_ONLY_SOURCE")
        (swcad-title-princ-line "Result: STOP_NO_MORE_FRAME_ONLY_SOURCE")
        (setq index count)
      )
    )
    (setq index (+ index 1))
  )
)

(defun swcad-title-transfer-frame-only-clone-batch (/ remaining count answer old-batch-mode batch-result)
  (setq remaining (length (swcad-title-frame-only-source-candidates)))
  (if (< remaining 1)
    (progn
      (swcad-title-princ-line "Result: STOP_NO_MORE_FRAME_ONLY_SOURCE")
      (princ)
    )
    (progn
      (setq count
        (getint
          (strcat
            "\nGMTITLE clone으로 처리할 frame-only 시트 수 <"
            (itoa remaining)
            ">: "
          )
        )
      )
      (if (not count)
        (setq count remaining)
      )
      (if (< count 1)
        (setq count 1)
      )
      (if (> count remaining)
        (setq count remaining)
      )
      (setq answer
        (getstring
          T
          (strcat
            "\n처리할 frame-only 시트 수 "
            (itoa count)
            "장입니다. 검증된 GMTITLE 쌍 복제로 처리하려면 YES를 입력하세요: "
          )
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (swcad-title-princ-line "Result: ABORT_USER_CANCEL")
          (princ)
        )
        (progn
          (setq old-batch-mode *swcad-title-batch-mode*)
          (setq *swcad-title-batch-mode* T)
          (setq batch-result
            (vl-catch-all-apply
              'swcad-title-transfer-frame-only-clone-batch-run
              (list count)
            )
          )
          (setq *swcad-title-batch-mode* old-batch-mode)
          (if (vl-catch-all-error-p batch-result)
            (progn
              (setq *swcad-title-last-apply-status* "ERROR_FRAME_ONLY_CLONE_BATCH_FATAL")
              (princ
                (strcat
                  "\nFrame-only 복제 일괄 처리 치명 오류: "
                  (vl-catch-all-error-message batch-result)
                )
              )
            )
          )
          (princ "\nFrame-only 복제 단계가 끝났습니다. 전체 확인은 SWTITLEVERIFY로 진행하세요.")
          (princ)
        )
      )
    )
  )
)

(defun swcad-title-run-fast-batch-phases (/ source-count frame-only-count final-source-count final-frame-only-count contaminated old-batch-mode source-result frame-result)
  (setq source-count (swcad-title-source-title-count))
  (setq old-batch-mode *swcad-title-batch-mode*)
  (setq *swcad-title-batch-mode* T)
  (if (> source-count 0)
    (progn
      (swcad-title-princ-text (strcat "\nFast batch: processing title sheets, count=" (itoa source-count)))
      (setq source-result
        (vl-catch-all-apply
          'swcad-title-transfer-clone-batch-run
          (list source-count)
        )
      )
      (if (vl-catch-all-error-p source-result)
        (progn
          (setq *swcad-title-last-apply-status* "ERROR_FAST_BATCH_TITLE_FATAL")
          (swcad-title-princ-text
            (strcat
              "\nFast batch title error: "
              (vl-catch-all-error-message source-result)
            )
          )
        )
      )
    )
  )
  (setq final-source-count (swcad-title-source-title-count))
  (if (and
        (= final-source-count 0)
        (or
          (= source-count 0)
          (equal *swcad-title-last-apply-status* "FINALIZED_EXISTING_GMTITLE_TRANSFER")
          (equal *swcad-title-last-apply-status* "FINALIZED_CLONED_GMTITLE_TRANSFER")
          (equal *swcad-title-last-apply-status* "ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER")
          (equal *swcad-title-last-apply-status* "STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        )
      )
    (progn
      (setq frame-only-count (swcad-title-frame-only-source-count))
      (if (> frame-only-count 0)
        (progn
          (cond
            ((swcad-title-title-missing-outline-definition-needed-p)
              (setq *swcad-title-last-apply-status* "WAITING_FOR_TITLE_MISSING_OUTLINE_DEFINITION")
              (swcad-title-princ-text
                (strcat
                  "\nFast batch paused before title-missing/frame-only phase: "
                  (itoa frame-only-count)
                  "개 표제란 없는 도면틀 시트의 같은 크기 DR 도면틀 정의 검증이 먼저 필요합니다."
                )
              )
              (swcad-title-princ-text "\nTitle-missing/frame-only sheets were not changed. Run SWTITLESTATUS, then SWTITLEPREPARE if requested.")
            )
            ((swcad-title-title-missing-outline-policy-blocked-p)
              (setq *swcad-title-last-apply-status* "READY_FOR_TITLE_MISSING_OUTLINE")
              (swcad-title-princ-text
                (strcat
                  "\nFast batch paused before title-missing/frame-only phase: "
                  (itoa frame-only-count)
                  "개 표제란 없는 도면틀 시트는 원본 표제란 부재 예외 경로에서 한 장씩 처리합니다."
                )
              )
              (swcad-title-princ-text "\nTitle-missing/frame-only sheets were not cloned. Run SWTITLESTATUS, then SWTITLECONVERTNEXT to replace only the same-size DR outline.")
            )
            (T
              (setq *swcad-title-last-apply-status* "ABORT_TITLE_MISSING_OUTLINE_UNAVAILABLE")
              (swcad-title-princ-text "\nFast batch stopped before title-missing/frame-only phase because the source-title-missing outline-only policy is unavailable.")
              (swcad-title-princ-text "\nTitle-missing/frame-only sheets were not cloned and no new title block was created.")
            )
          )
        )
      )
    )
    (swcad-title-princ-text
      (strcat
        "\nFast batch skipped frame-only phase because title phase left "
        (itoa final-source-count)
        "개 원본 표제란 시트"
      )
    )
  )
  (setq *swcad-title-batch-mode* old-batch-mode)
  (setq final-source-count (swcad-title-source-title-count))
  (setq final-frame-only-count (swcad-title-frame-only-source-count))
  (swcad-title-princ-text (strcat "\nRemaining source title sheets after fast batch: " (itoa final-source-count)))
  (swcad-title-princ-text (strcat "\nRemaining frame-only sheets after fast batch: " (itoa final-frame-only-count)))
  (swcad-title-print-fast-sheet-summary (swcad-title-fast-sheet-summary))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (swcad-title-princ-text (strcat "\nContaminated target frame definitions after fast batch: " (swcad-title-list-string contaminated)))
  (cond
    ((equal *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (swcad-title-princ-text "\nResult: WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (swcad-title-princ-text "\nFast batch paused so the next sheet size can be created once with real native GMTITLE.")
      (swcad-title-princ-text "\n다음 정확한 작업은 SWTITLESTATUS로 확인하고, 변환은 SWTITLECONVERTNEXT로 계속하세요.")
    )
    ((member *swcad-title-last-apply-status* '("WAITING_FOR_TITLE_MISSING_OUTLINE_DEFINITION" "READY_FOR_TITLE_MISSING_OUTLINE" "ABORT_TITLE_MISSING_OUTLINE_UNAVAILABLE"))
      (swcad-title-princ-text (strcat "\nResult: " *swcad-title-last-apply-status*))
      (swcad-title-princ-text "\n다음 정확한 작업은 SWTITLESTATUS로 확인하고, 변환은 SWTITLECONVERTNEXT로 계속하세요.")
    )
    ((or (> final-source-count 0) (> final-frame-only-count 0))
      (setq *swcad-title-last-apply-status* "WARN_FAST_BATCH_REMAINING_SOURCES")
      (swcad-title-princ-text "\nResult: WARN_FAST_BATCH_REMAINING_SOURCES")
    )
    (contaminated
      (setq *swcad-title-last-apply-status* "WARN_FAST_BATCH_FRAME_DEFS_CONTAMINATED")
      (swcad-title-princ-text "\nResult: WARN_FAST_BATCH_FRAME_DEFS_CONTAMINATED")
    )
    (T
      (setq *swcad-title-last-apply-status* "OK_FAST_BATCH_COMPLETE")
      (swcad-title-princ-text "\nResult: OK_FAST_BATCH_COMPLETE")
      (swcad-title-princ-text "\n다음: SWTITLESTATUS 실행 후 SWTITLEVERIFY를 실행하세요.")
      (swcad-title-princ-text "\n중요: 빠른 일괄 변환은 clone GMTITLE 쌍을 만들 수 있습니다. 겉보기에는 맞아도 GMPOWEREDIT/더블클릭 native 동작은 실패할 수 있습니다.")
      (swcad-title-princ-text "\n최종 성공은 clone/native-upgrade 경고가 없고 변환된 대표 용지의 표제란 더블클릭 확인까지 끝났을 때입니다.")
    )
  )
  *swcad-title-last-apply-status*
)

(defun swcad-title-transfer-fast-batch (/ summary source-count frame-only-count contaminated example-title missing-required frame-records geometry-risk-count overlap-risk-count answer)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq example-title (swcad-title-native-example-title))
  (setq missing-required (swcad-title-missing-required-native-frame-blocks summary))
  (setq frame-records (swcad-title-frame-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (swcad-title-princ-text "\n----- SWTITLECONVERT 내부 남은 시트 빠른 변환 -----")
  (swcad-title-princ-text (strcat "\nDWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-text (strcat "\nCTAB: " (getvar "CTAB")))
  (swcad-title-princ-text
    (strcat
      "\nWork-folder test copy: "
      (if (swcad-title-current-dwg-in-work-p) "yes" "no")
    )
  )
  (swcad-title-princ-text (strcat "\nRemaining source title sheets: " (itoa source-count)))
  (swcad-title-princ-text (strcat "\nRemaining frame-only sheets: " (itoa frame-only-count)))
  (swcad-title-print-fast-sheet-summary summary)
  (swcad-title-princ-text
    (strcat
      "\nAny native GMTITLE title: "
      (swcad-title-native-example-description example-title)
    )
  )
  (swcad-title-print-native-exemplars-by-frame)
  (swcad-title-print-required-native-exemplars summary)
  (swcad-title-print-next-fast-target-readiness)
  (swcad-title-princ-text (strcat "\nContaminated target frame definitions: " (swcad-title-list-string contaminated)))
  (if contaminated
    (swcad-title-princ-text "\n경고: 대상 도면틀 정의가 원본과 비슷한 구조로 표시됐습니다. 동일 크기 native 기준 객체가 있을 때만 동일 크기 clone을 계속합니다.")
  )
  (if (or (> geometry-risk-count 0) (> overlap-risk-count 0))
    (swcad-title-print-target-frame-selection-diagnostics frame-records)
  )
  (cond
    ((swcad-title-document-read-only-p)
      (setq *swcad-title-last-apply-status* "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-text "\nResult: ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-text "\nOpen a writable work copy before running the fast batch.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (setq *swcad-title-last-apply-status* "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-text "\nResult: ABORT_NOT_WORK_COPY")
      (swcad-title-princ-text "\nFast batch is limited to Documents/CAD tool/work copies.")
    )
    ((> geometry-risk-count 0)
      (setq *swcad-title-last-apply-status* "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (swcad-title-princ-text "\nResult: WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (swcad-title-princ-text "\nFast batch stopped because an existing target frame has invalid A-size geometry.")
      (swcad-title-princ-text "\n계속하기 전에 SWTITLEVERIFY로 문제가 있는 용지 크기를 확인하고 다시 만들거나 복구하세요.")
    )
    ((> overlap-risk-count 0)
      (setq *swcad-title-last-apply-status* "WARN_TARGET_FRAME_SELECTION_RISK")
      (swcad-title-princ-text "\nResult: WARN_TARGET_FRAME_SELECTION_RISK")
      (swcad-title-princ-text "\nFast batch stopped because existing target frames overlap and may select the wrong GMTITLE object.")
      (swcad-title-princ-text "\n계속하기 전에 SWTITLEVERIFY로 대상 도면틀 상태를 확인하세요.")
    )
    ((and (= source-count 0) (= frame-only-count 0))
      (setq *swcad-title-last-apply-status* "OK_NO_REMAINING_SOURCES")
      (swcad-title-princ-text "\nResult: OK_NO_REMAINING_SOURCES")
      (swcad-title-princ-text "\n신뢰 가능한 변환 결과 검증은 SWTITLEVERIFY로 진행하세요.")
    )
    ((not example-title)
      (setq *swcad-title-last-apply-status* "ABORT_NO_NATIVE_GMTITLE_EXEMPLAR")
      (swcad-title-princ-text "\nResult: ABORT_NO_NATIVE_GMTITLE_EXEMPLAR")
      (swcad-title-princ-text "\nCreate/finalize one real native GMTITLE first, then run this command again.")
      (swcad-title-princ-text "\nCloned titles whose native link points to a visible frame are not accepted as exemplars.")
      (swcad-title-princ-text "\n권장: SWTITLESTATUS로 다음 대상을 확인한 뒤 SWTITLECONVERTNEXT로 첫 native GMTITLE 단계를 진행하세요.")
    )
    ((and missing-required (not (swcad-title-next-fast-target-ready-p)))
      (setq *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (swcad-title-princ-text "\nResult: WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (swcad-title-princ-text "\nCreate/finalize one real native GMTITLE for each missing title-sheet size first.")
      (swcad-title-princ-text "\n이 native 기준 객체 요구는 표제란이 있는 원본 시트에만 해당합니다. title-missing/frame-only 시트는 같은 크기 DR 도면틀 정의 검증 후 outline-only 경로로 진행합니다.")
    )
    (T
      (if (> frame-only-count 0)
        (progn
          (swcad-title-princ-text
            (strcat
              "\n주의: frame-only 시트 "
              (itoa frame-only-count)
              "장은 빠른 clone 변환에서 제외하고 title-missing 도면틀-only 경로로 넘깁니다."
            )
          )
          (swcad-title-princ-text "\n이 단계에서는 표제란 있는 시트만 처리하고, frame-only 시트는 SWTITLESTATUS 후 SWTITLECONVERTNEXT에서 원본 표제란 부재 예외로 진행합니다.")
        )
      )
      (setq answer
        (swcad-title-auto-next-answer-or-prompt
          "YES"
          "남은 시트 빠른 변환"
          (if (> frame-only-count 0)
            (strcat
              "\n처리할 표제란 시트 "
              (itoa source-count)
              "장만 처리하려면 YES를 입력하세요: "
            )
            (strcat "\n처리할 표제란 시트 " (itoa source-count) "장을 처리하려면 YES를 입력하세요: ")
          )
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (setq *swcad-title-last-apply-status* "ABORT_USER_CANCEL")
          (swcad-title-princ-text "\nResult: ABORT_USER_CANCEL")
        )
        (swcad-title-run-fast-batch-phases)
      )
    )
  )
  (princ)
)

(defun swcad-title-transfer-bootstrap-fast (/ summary source-count frame-only-count contaminated example-title missing-required frame-records geometry-risk-count overlap-risk-count answer old-batch-mode apply-result after-summary after-missing)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq example-title (swcad-title-native-example-title))
  (setq missing-required (swcad-title-missing-required-native-frame-blocks summary))
  (setq frame-records (swcad-title-frame-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (swcad-title-princ-text "\n----- SWTITLECONVERT 내부 첫 native + 빠른 일괄 변환 -----")
  (swcad-title-princ-text (strcat "\nDWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-text (strcat "\nCTAB: " (getvar "CTAB")))
  (swcad-title-princ-text
    (strcat
      "\nWork-folder test copy: "
      (if (swcad-title-current-dwg-in-work-p) "yes" "no")
    )
  )
  (swcad-title-print-fast-sheet-summary summary)
  (if
    (and
      (not example-title)
      (> source-count 0)
    )
    (swcad-title-print-next-bootstrap-selection)
  )
  (swcad-title-princ-text
    (strcat
      "\nAny native GMTITLE title: "
      (swcad-title-native-example-description example-title)
    )
  )
  (swcad-title-print-native-exemplars-by-frame)
  (swcad-title-print-required-native-exemplars summary)
  (swcad-title-print-next-fast-target-readiness)
  (swcad-title-princ-text (strcat "\nContaminated target frame definitions: " (swcad-title-list-string contaminated)))
  (if contaminated
    (swcad-title-princ-text "\n경고: 대상 도면틀 정의가 원본과 비슷한 구조로 표시됐습니다. 동일 크기 native 기준 객체가 있을 때만 동일 크기 clone을 계속합니다.")
  )
  (if (or (> geometry-risk-count 0) (> overlap-risk-count 0))
    (swcad-title-print-target-frame-selection-diagnostics frame-records)
  )
  (cond
    ((swcad-title-document-read-only-p)
      (setq *swcad-title-last-apply-status* "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-text "\nResult: ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-text "\nOpen a writable work copy before running the bootstrap fast transfer.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (setq *swcad-title-last-apply-status* "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-text "\nResult: ABORT_NOT_WORK_COPY")
      (swcad-title-princ-text "\nBootstrap fast transfer is limited to Documents/CAD tool/work copies.")
    )
    ((> geometry-risk-count 0)
      (setq *swcad-title-last-apply-status* "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (swcad-title-princ-text "\nResult: WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (swcad-title-princ-text "\nBootstrap fast transfer stopped because an existing target frame has invalid A-size geometry.")
      (swcad-title-princ-text "\n계속하기 전에 SWTITLEVERIFY로 문제가 있는 용지 크기를 확인하고 다시 만들거나 복구하세요.")
    )
    ((> overlap-risk-count 0)
      (setq *swcad-title-last-apply-status* "WARN_TARGET_FRAME_SELECTION_RISK")
      (swcad-title-princ-text "\nResult: WARN_TARGET_FRAME_SELECTION_RISK")
      (swcad-title-princ-text "\nBootstrap fast transfer stopped because existing target frames overlap and may select the wrong GMTITLE object.")
      (swcad-title-princ-text "\n계속하기 전에 SWTITLEVERIFY로 대상 도면틀 상태를 확인하세요.")
    )
    ((and (= source-count 0) (= frame-only-count 0))
      (setq *swcad-title-last-apply-status* "OK_NO_REMAINING_SOURCES")
      (swcad-title-princ-text "\nResult: OK_NO_REMAINING_SOURCES")
      (swcad-title-princ-text "\n신뢰 가능한 변환 결과 검증은 SWTITLEVERIFY로 진행하세요.")
    )
    ((and example-title missing-required (not (swcad-title-next-fast-target-ready-p)))
      (setq *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (swcad-title-princ-text "\nResult: WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (swcad-title-princ-text "\nA native GMTITLE exemplar exists, but one or more remaining title-sheet sizes still need their own first real GMTITLE.")
      (swcad-title-princ-text "\nSWTITLESTATUS로 누락 크기를 확인하고 SWTITLECONVERTNEXT로 필요한 첫 native GMTITLE 단계를 진행하세요.")
    )
    (example-title
      (setq answer
        (swcad-title-auto-next-answer-or-prompt
          "YES"
          "기존 native 기준 객체로 남은 시트 변환"
          "\n기존 native GMTITLE 기준 객체를 찾았습니다. 남은 시트 빠른 일괄 변환을 실행하려면 YES를 입력하세요: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (setq *swcad-title-last-apply-status* "ABORT_USER_CANCEL")
          (swcad-title-princ-text "\nResult: ABORT_USER_CANCEL")
        )
        (swcad-title-run-fast-batch-phases)
      )
    )
    ((= source-count 0)
      (setq *swcad-title-last-apply-status* "ABORT_NO_TITLE_SOURCE_FOR_BOOTSTRAP")
      (swcad-title-princ-text "\nResult: ABORT_NO_TITLE_SOURCE_FOR_BOOTSTRAP")
      (swcad-title-princ-text "\nNo title source remains to create the first native GMTITLE exemplar.")
      (swcad-title-princ-text "\nSWTITLESTATUS로 현재 상태를 확인한 뒤, 필요한 첫 native GMTITLE 단계는 SWTITLECONVERTNEXT로 진행하세요.")
    )
    (T
      (setq answer
        (swcad-title-auto-next-answer-or-prompt
          "YES"
          "첫 native GMTITLE 생성"
          "\n첫 native GMTITLE을 생성/마무리하고, 같은 크기 native 기준 객체가 준비된 경우에만 계속하려면 YES를 입력하세요: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (setq *swcad-title-last-apply-status* "ABORT_USER_CANCEL")
          (swcad-title-princ-text "\nResult: ABORT_USER_CANCEL")
        )
        (progn
          (swcad-title-princ-text "\n첫 native 단계: 처음 감지된 표제란 시트에 대해 native GMTITLE 창이 한 번 열립니다.")
          (swcad-title-princ-text "\n현재 GstarCAD에서는 첫 native GMTITLE 선택을 사람이 직접 확인해야 합니다.")
          (swcad-title-princ-text "\nGMTITLE 창에서:")
          (swcad-title-princ-text "\n  1. 위에 표시된 감지 DR 용지를 선택하세요.")
          (swcad-title-princ-text "\n  2. DR_titlea_3rd를 선택하세요.")
          (swcad-title-princ-text "\n  3. Frame positioning은 ON으로 둡니다.")
          (swcad-title-princ-text "\n  4. Object move는 OFF로 끕니다.")
          (swcad-title-princ-text "\n  5. 한 번만 확인/배치하세요. LSP가 정렬한 뒤 같은 크기 native 기준 객체가 준비됐는지 확인합니다.")
          (setq old-batch-mode *swcad-title-batch-mode*)
          (setq *swcad-title-batch-mode* T)
          (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-apply nil))
          (setq *swcad-title-batch-mode* old-batch-mode)
          (if (vl-catch-all-error-p apply-result)
            (progn
              (setq *swcad-title-last-apply-status* "ERROR_BOOTSTRAP_FIRST_NATIVE_FATAL")
              (princ
                (strcat
                  "\nBootstrap first-native error: "
                  (vl-catch-all-error-message apply-result)
                )
              )
            )
          )
          (princ
            (strcat
              "\nBootstrap first-native status: "
              (swcad-title-string *swcad-title-last-apply-status*)
            )
          )
          (if (swcad-title-bootstrap-first-native-success-p *swcad-title-last-apply-status*)
            (progn
              (if *swcad-title-convert-next-mode*
                (progn
                  (setq *swcad-title-last-apply-status* "OK_CONVERT_NEXT_FIRST_NATIVE_CREATED")
                  (swcad-title-princ-text "\nSWTITLECONVERTNEXT one-step stop: first native GMTITLE was created/finalized.")
                  (swcad-title-princ-text "\nFast clone batch was not started in this command.")
                  (swcad-title-princ-text "\n다음: SWTITLESTATUS로 상태를 다시 확인한 뒤 안내된 다음 한 단계만 진행하세요.")
                )
                (progn
                  (setq after-summary (swcad-title-fast-sheet-summary))
                  (setq after-missing (swcad-title-missing-required-native-frame-blocks after-summary))
                  (if (and after-missing (not (swcad-title-next-fast-target-ready-p)))
                    (progn
                      (setq *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
                      (swcad-title-princ-text "\nBootstrap phase complete. Fast batch paused because another sheet size needs its own real GMTITLE exemplar.")
                      (swcad-title-print-fast-sheet-summary after-summary)
                      (swcad-title-print-required-native-exemplars after-summary)
                      (swcad-title-print-next-fast-target-readiness)
                      (swcad-title-princ-text "\nResult: WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
                    )
                    (progn
                      (swcad-title-princ-text "\nBootstrap phase complete. Starting fast remaining-sheet batch.")
                      (swcad-title-run-fast-batch-phases)
                    )
                  )
                )
              )
            )
            (princ
              (strcat
                "\nFast batch not started because bootstrap phase ended with status: "
                (swcad-title-string *swcad-title-last-apply-status*)
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun swcad-title-scale-text-to-dimlfac (text / cleaned ratio pos left right numerator denominator value)
  (setq cleaned (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq ratio (swcad-title-extract-ratio-text cleaned))
  (if ratio
    (setq cleaned ratio)
  )
  (setq pos (vl-string-search ":" cleaned))
  (cond
    (pos
      (setq left
        (if (> pos 0)
          (vl-string-trim " \t\r\n" (substr cleaned 1 pos))
          ""
        )
      )
      (setq right (vl-string-trim " \t\r\n" (substr cleaned (+ pos 2))))
      (setq numerator (atof left))
      (setq denominator (atof right))
      (if (and (> numerator 0.0) (> denominator 0.0))
        (/ numerator denominator)
        nil
      )
    )
    (T
      (setq value (atof cleaned))
      (if (> value 0.0) value nil)
    )
  )
)

(defun swcad-title-expected-dimlfac-values (scale-values / result item value)
  (setq result nil)
  (foreach item scale-values
    (setq value (swcad-title-scale-text-to-dimlfac item))
    (if (numberp value)
      (setq result (swcad-title-list-add-unique-float value result))
    )
  )
  result
)

(defun swcad-title-dxf-put (data code value)
  (if (assoc code data)
    (subst (cons code value) (assoc code data) data)
    (append data (list (cons code value)))
  )
)

(defun swcad-title-xdata-apps (data / xd)
  (setq xd (assoc -3 data))
  (if xd (cdr xd) nil)
)

(defun swcad-title-xdata-app-name (app)
  (if (and (listp app) (swcad-title-string-p (car app)))
    (car app)
    nil
  )
)

(defun swcad-title-acad-app (apps / result name)
  (foreach app apps
    (setq name (swcad-title-xdata-app-name app))
    (if (and (not result) name (equal name "ACAD"))
      (setq result app)
    )
  )
  result
)

(defun swcad-title-get-dstyle-overrides (data / apps acad pairs result item code valuepair)
  (setq apps (swcad-title-xdata-apps data))
  (setq acad (swcad-title-acad-app apps))
  (setq pairs (if acad (cdr acad) nil))
  (setq result nil)
  (while pairs
    (setq item (car pairs))
    (if (and (= (car item) 1000) (equal (cdr item) "DSTYLE"))
      (progn
        (setq pairs (cdr pairs))
        (if (and pairs (= (car (car pairs)) 1002) (equal (cdr (car pairs)) "{"))
          (setq pairs (cdr pairs))
        )
        (while (and pairs
                    (not (and (= (car (car pairs)) 1002)
                              (equal (cdr (car pairs)) "}"))))
          (if (and (= (car (car pairs)) 1070) (cdr pairs))
            (progn
              (setq code (cdr (car pairs)))
              (setq valuepair (cadr pairs))
              (setq result (swcad-title-dxf-put result code (cdr valuepair)))
              (setq pairs (cddr pairs))
            )
            (setq pairs (cdr pairs))
          )
        )
      )
    )
    (if pairs (setq pairs (cdr pairs)))
  )
  result
)

(defun swcad-title-dimstyle-or-override-value (data code / style styledata overrides)
  (setq overrides (swcad-title-get-dstyle-overrides data))
  (setq style (swcad-title-safe-string (cdr (assoc 3 data))))
  (setq styledata (if style (tblsearch "DIMSTYLE" style) nil))
  (cond
    ((assoc code overrides) (cdr (assoc code overrides)))
    ((and styledata (assoc code styledata)) (cdr (assoc code styledata)))
    (T nil)
  )
)

(defun swcad-title-dim-linear-scale (ename data / object value)
  (setq value (swcad-title-dimstyle-or-override-value data 144))
  (if (or (not value) (not (numberp value)) (equal (float value) 0.0 1e-12))
    (progn
      (setq object (swcad-title-safe-vla-object ename))
      (setq value (swcad-title-safe-vla-get object 'LinearScaleFactor))
    )
  )
  (if (or (not value) (not (numberp value)) (equal (float value) 0.0 1e-12))
    1.0
    (float value)
  )
)

(defun swcad-title-cloned-gmtitle-pair-records (/ frame-records title-enames used-title-enames result frame-record frame-ename frame-block frame-bbox title-ename title-bbox title-role frame-role)
  (setq frame-records (swcad-title-frame-records))
  (setq title-enames (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq used-title-enames nil)
  (setq result nil)
  (foreach frame-record frame-records
    (setq frame-ename (car frame-record))
    (setq frame-block (cadr frame-record))
    (setq frame-bbox (cadddr frame-record))
    (setq title-ename (swcad-title-title-for-frame-record-unused frame-record title-enames used-title-enames))
    (if title-ename
      (setq used-title-enames (append used-title-enames (list title-ename)))
    )
    (setq title-bbox (if title-ename (swcad-title-safe-bbox title-ename) nil))
    (setq title-role (if title-ename (swcad-title-exemplar-role title-ename) ""))
    (setq frame-role (swcad-title-exemplar-role frame-ename))
    (if
      (and
        title-ename
        frame-ename
        frame-block
        title-bbox
        frame-bbox
        (swcad-title-trusted-native-exemplar-pair-p title-ename frame-ename frame-block)
        (or
          (equal (strcase title-role) "CLONE")
          (equal (strcase frame-role) "CLONE")
        )
      )
      (setq result
        (append
          result
          (list
            (list
              title-ename
              frame-ename
              frame-block
              title-bbox
              frame-bbox
              title-role
              frame-role
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-first-cloned-gmtitle-pair-record ()
  (car (swcad-title-cloned-gmtitle-pair-records))
)

(defun swcad-title-cloned-gmtitle-pair-record-for-ename (ename / insert-ename records result record)
  (setq insert-ename (swcad-title-enclosing-insert-ename ename))
  (setq records (swcad-title-cloned-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (if
      (and
        (not result)
        (or
          (eq ename (car record))
          (eq ename (cadr record))
          (eq insert-ename (car record))
          (eq insert-ename (cadr record))
        )
      )
      (setq result record)
    )
  )
  result
)

(defun swcad-title-cloned-gmtitle-pair-record-for-point (point / records result record frame-bbox title-bbox)
  (setq records (swcad-title-cloned-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (setq title-bbox (nth 3 record))
    (setq frame-bbox (nth 4 record))
    (if
      (and
        (not result)
        (or
          (swcad-title-point-in-expanded-bbox-flex-p point frame-bbox 2.0)
          (swcad-title-point-in-expanded-bbox-flex-p point title-bbox 2.0)
        )
      )
      (setq result record)
    )
  )
  result
)

(defun swcad-title-target-gmtitle-pair-records (/ frame-records title-enames used-title-enames result frame-record frame-ename frame-block frame-bbox title-ename title-bbox title-role frame-role)
  (setq frame-records (swcad-title-frame-records))
  (setq title-enames (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq used-title-enames nil)
  (setq result nil)
  (foreach frame-record frame-records
    (setq frame-ename (car frame-record))
    (setq frame-block (cadr frame-record))
    (setq frame-bbox (cadddr frame-record))
    (setq title-ename (swcad-title-title-for-frame-record-unused frame-record title-enames used-title-enames))
    (if title-ename
      (setq used-title-enames (append used-title-enames (list title-ename)))
    )
    (setq title-bbox (if title-ename (swcad-title-safe-bbox title-ename) nil))
    (setq title-role (if title-ename (swcad-title-exemplar-role title-ename) ""))
    (setq frame-role (swcad-title-exemplar-role frame-ename))
    (if
      (and
        title-ename
        frame-ename
        frame-block
        title-bbox
        frame-bbox
      )
      (setq result
        (append
          result
          (list
            (list
              title-ename
              frame-ename
              frame-block
              title-bbox
              frame-bbox
              title-role
              frame-role
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-target-gmtitle-pair-record-for-ename (ename / insert-ename records result record)
  (setq insert-ename (swcad-title-enclosing-insert-ename ename))
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (if
      (and
        (not result)
        (or
          (eq ename (car record))
          (eq ename (cadr record))
          (eq insert-ename (car record))
          (eq insert-ename (cadr record))
        )
      )
      (setq result record)
    )
  )
  result
)

(defun swcad-title-target-gmtitle-pair-record-for-point (point / records result record frame-bbox title-bbox)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (setq title-bbox (nth 3 record))
    (setq frame-bbox (nth 4 record))
    (if
      (and
        (not result)
        (or
          (swcad-title-point-in-expanded-bbox-flex-p point frame-bbox 2.0)
          (swcad-title-point-in-expanded-bbox-flex-p point title-bbox 2.0)
        )
      )
      (setq result record)
    )
  )
  result
)

(defun swcad-title-pick-area-for-pair (ename point record / insert title frame title-bbox frame-bbox)
  (setq insert (swcad-title-enclosing-insert-ename ename))
  (setq title (car record))
  (setq frame (cadr record))
  (setq title-bbox (nth 3 record))
  (setq frame-bbox (nth 4 record))
  (cond
    ((or (eq ename title) (eq insert title)) "title-insert")
    ((or (eq ename frame) (eq insert frame)) "frame-insert")
    ((swcad-title-point-in-expanded-bbox-flex-p point title-bbox 2.0) "title-area")
    ((swcad-title-point-in-expanded-bbox-flex-p point frame-bbox 2.0) "frame-area")
    (T "unknown")
  )
)

(defun swcad-title-pick-check (/ picked ename pick-point wcs-point insert-ename insert-name record area title-ename frame-ename frame-block title-bbox frame-bbox title-role frame-role native-like reason geometry-warning title-center frame-center)
  (swcad-title-open-pick-check-log)
  (swcad-title-princ-line "----- SWTITLEVERIFY 내부 GMTITLE 선택 객체 확인(읽기 전용) -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq picked (entsel "\nSelect GMTITLE title/frame to check: "))
  (setq ename (if picked (car picked) nil))
  (setq pick-point (if picked (cadr picked) nil))
  (setq wcs-point (swcad-title-safe-trans-point pick-point 1 0))
  (setq insert-ename (if ename (swcad-title-enclosing-insert-ename ename) nil))
  (setq insert-name (if insert-ename (swcad-title-effective-insert-name insert-ename) ""))
  (swcad-title-princ-line
    (strcat
      "Selected entity: "
      (if ename
        (strcat
          "handle="
          (swcad-title-ename-handle ename)
          ", type="
          (swcad-title-entity-type-name ename)
        )
        "<none>"
      )
    )
  )
  (if insert-ename
    (swcad-title-princ-line
      (strcat
        "Enclosing insert: handle="
        (swcad-title-ename-handle insert-ename)
        ", block="
        insert-name
      )
    )
    (swcad-title-princ-line "Enclosing insert: <none>")
  )
  (swcad-title-princ-line (strcat "Selected point: " (if pick-point (swcad-title-point-string pick-point) "<none>")))
  (swcad-title-princ-line (strcat "Selected point WCS: " (if wcs-point (swcad-title-point-string wcs-point) "<none>")))
  (setq record (if ename (swcad-title-target-gmtitle-pair-record-for-ename ename) nil))
  (if (and (not record) pick-point)
    (setq record (swcad-title-target-gmtitle-pair-record-for-point pick-point))
  )
  (if (and (not record) wcs-point)
    (setq record (swcad-title-target-gmtitle-pair-record-for-point wcs-point))
  )
  (if record
    (progn
      (setq title-ename (car record))
      (setq frame-ename (cadr record))
      (setq frame-block (caddr record))
      (setq title-bbox (nth 3 record))
      (setq frame-bbox (nth 4 record))
      (setq title-role (nth 5 record))
      (setq frame-role (nth 6 record))
      (setq area (swcad-title-pick-area-for-pair ename pick-point record))
      (setq native-like (swcad-title-target-pair-native-like-p record))
      (setq reason (swcad-title-target-pair-upgrade-reason record))
      (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
      (setq title-center (swcad-title-bbox-center title-bbox))
      (setq frame-center (swcad-title-bbox-center frame-bbox))
      (swcad-title-princ-line (strcat "Pick area: " area))
      (swcad-title-princ-line
        (strcat
          "Pair sheet/frame: "
          (swcad-title-string (swcad-title-sheet-size-from-block-name frame-block))
          ", "
          frame-block
        )
      )
      (swcad-title-princ-line
        (strcat
          "Title insert: handle="
          (swcad-title-ename-handle title-ename)
          ", role="
          (if (> (strlen title-role) 0) title-role "<none>")
          ", center="
          (swcad-title-point-string title-center)
          ", bbox="
          (swcad-title-bbox-string title-bbox)
        )
      )
      (swcad-title-princ-line
        (strcat
          "Frame insert: handle="
          (swcad-title-ename-handle frame-ename)
          ", role="
          (if (> (strlen frame-role) 0) frame-role "<none>")
          ", center="
          (swcad-title-point-string frame-center)
          ", bbox="
          (swcad-title-bbox-string frame-bbox)
        )
      )
      (swcad-title-princ-line (strcat "Native-like pair: " (if native-like "yes" "no")))
      (swcad-title-princ-line (strcat "Reason/status detail: " reason))
      (if geometry-warning
        (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
      )
      (cond
        ((or (equal area "frame-insert") (equal area "frame-area"))
          (swcad-title-princ-line "Double-click note: this is the DR_A*_Outline frame INSERT. GMPOWEREDIT may show block/reference editing here.")
          (swcad-title-princ-line "For the GMTITLE table editor, test the paired DR_titlea_3rd title insert listed above.")
        )
        ((or (equal area "title-insert") (equal area "title-area"))
          (swcad-title-princ-line "Double-click note: this is the title block area; this is the right place to check the GMTITLE table editor.")
        )
      )
      (cond
        (geometry-warning
          (swcad-title-apply-result "WARN_PICK_TARGET_FRAME_GEOMETRY_INVALID")
        )
        (native-like
          (if (or (equal area "frame-insert") (equal area "frame-area"))
            (swcad-title-apply-result "OK_PICK_NATIVE_PAIR_BUT_FRAME_SELECTED")
            (swcad-title-apply-result "OK_PICK_NATIVE_TITLE_READY")
          )
        )
        ((or
           (equal reason "clone")
           (equal reason "finalize-or-frame-only-marker-needs-native-recheck")
           (equal reason "shared-native-link-handle")
           (equal reason "native-created-then-moved; GMPOWEREDIT-unverified")
         )
          (swcad-title-apply-result "NEEDS_NATIVE_GMTITLE_UPGRADE")
          (swcad-title-princ-line "선택한 쌍은 최종 더블클릭 동작을 보장할 fresh native GMTITLE로 인정되지 않습니다.")
          (swcad-title-princ-line "다음: SWTITLESTATUS를 실행한 뒤, SWTITLECONVERTNEXT로 다음 A2/A3/A4 native 교체 후보를 처리하세요.")
        )
        (T
          (swcad-title-apply-result "NEEDS_GMTITLE_PAIR_REVIEW")
          (swcad-title-princ-line "다음: SWTITLESTATUS와 SWTITLEVERIFY를 실행하세요. 그래도 GMPOWEREDIT/REFEDIT가 열리면 이 pick-check 로그를 공유하세요.")
        )
      )
    )
    (progn
      (swcad-title-apply-result "NO_TARGET_GMTITLE_PAIR_AT_PICK")
      (swcad-title-princ-line "No matching DR_A*_Outline + DR_titlea_3rd pair was found at the selected entity/point.")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-role-display (role / value)
  (setq value (swcad-title-string role))
  (if (> (strlen value) 0) value "<none>")
)

(defun swcad-title-double-click-check-record (index record / title-ename frame-ename frame-block title-bbox frame-bbox title-role frame-role sheet title-center native-like reason geometry-warning)
  (setq title-ename (car record))
  (setq frame-ename (cadr record))
  (setq frame-block (caddr record))
  (setq title-bbox (nth 3 record))
  (setq frame-bbox (nth 4 record))
  (setq title-role (nth 5 record))
  (setq frame-role (nth 6 record))
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (setq title-center (swcad-title-bbox-center title-bbox))
  (setq native-like (swcad-title-target-pair-native-like-p record))
  (setq reason (swcad-title-target-pair-upgrade-reason record))
  (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
  (swcad-title-princ-line
    (strcat
      "#"
      (itoa index)
      " sheet="
      (swcad-title-string sheet)
      ", native-like="
      (if native-like "yes" "no")
      ", reason="
      reason
    )
  )
  (swcad-title-princ-line
    (strcat
      "  Title double-click point: "
      (swcad-title-point-string title-center)
      ", handle="
      (swcad-title-ename-handle title-ename)
      ", role="
      (swcad-title-role-display title-role)
      ", bbox="
      (swcad-title-bbox-string title-bbox)
    )
  )
  (swcad-title-princ-line
    (strcat
      "  Paired frame: "
      frame-block
      ", handle="
      (swcad-title-ename-handle frame-ename)
      ", role="
      (swcad-title-role-display frame-role)
      ", bbox="
      (swcad-title-bbox-string frame-bbox)
    )
  )
  (if geometry-warning
    (swcad-title-princ-line (strcat "  Frame geometry warning: " geometry-warning))
  )
  native-like
)

(defun swcad-title-double-click-check (/ records record index native-count needs-count)
  (swcad-title-open-double-click-check-log)
  (swcad-title-princ-line "----- SWTITLEVERIFY 내부 수동 더블클릭 확인 목록(읽기 전용) -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (swcad-title-princ-line (strcat "Target GMTITLE title/frame pairs: " (itoa (length records))))
  (if records
    (progn
      (swcad-title-princ-line "Manual check rule: double-click the DR_titlea_3rd title block, not the DR_A*_Outline frame.")
      (swcad-title-princ-line "The frame may open GMPOWEREDIT/REFEDIT even when the paired title block is usable.")
      (swcad-title-princ-line "Use the listed title double-click point as the visual target; the live cursor grip can still look centered in GstarCAD.")
      (setq index 0)
      (setq native-count 0)
      (setq needs-count 0)
      (foreach record records
        (setq index (+ index 1))
        (if (swcad-title-double-click-check-record index record)
          (setq native-count (+ native-count 1))
          (setq needs-count (+ needs-count 1))
        )
      )
      (swcad-title-princ-line (strcat "native-like로 인정된 쌍: " (itoa native-count)))
      (swcad-title-princ-line (strcat "native 재확인/교체가 필요한 쌍: " (itoa needs-count)))
      (if (> needs-count 0)
        (progn
          (swcad-title-apply-result "NEEDS_NATIVE_GMTITLE_UPGRADE")
          (swcad-title-princ-line "다음: SWTITLESTATUS를 실행한 뒤, 남은 A2/A3/A4 쌍을 SWTITLECONVERTNEXT로 한 장씩 반복 처리하세요.")
        )
        (progn
          (swcad-title-apply-result "OK_DOUBLE_CLICK_MANUAL_CHECK_READY")
          (swcad-title-princ-line "다음: 화면에서 변환된 대표 용지의 제목블록을 더블클릭해 GMTITLE 표 편집창이 열리는지 확인하세요.")
          (swcad-title-princ-line "하나라도 GMPOWEREDIT/REFEDIT로 열리면 해당 제목블록 위치와 SWTITLEVERIFY 로그를 공유하세요.")
        )
      )
    )
    (progn
      (swcad-title-apply-result "FAIL_MISSING_TARGET_GMTITLE_PAIRS")
      (swcad-title-princ-line "No DR_A*_Outline + DR_titlea_3rd pairs were found.")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-target-pair-native-like-p (record / title-ename frame-ename frame-block frame-bbox title-role frame-role pair-trusted clone-pair legacy-uncertain geometry-warning title-link-internal title-link-shared)
  (setq title-ename (car record))
  (setq frame-ename (cadr record))
  (setq frame-block (caddr record))
  (setq frame-bbox (nth 4 record))
  (setq title-role (nth 5 record))
  (setq frame-role (nth 6 record))
  (setq pair-trusted (swcad-title-trusted-native-exemplar-pair-p title-ename frame-ename frame-block))
  (setq clone-pair
    (or
      (swcad-title-exemplar-clone-role-p title-role)
      (swcad-title-exemplar-clone-role-p frame-role)
    )
  )
  (setq legacy-uncertain
    (or
      (swcad-title-exemplar-legacy-uncertain-native-role-p title-role)
      (swcad-title-exemplar-legacy-uncertain-native-role-p frame-role)
    )
  )
  (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
  (setq title-link-internal
    (swcad-title-internal-native-link-kinds-p
      (swcad-title-native-link-target-kinds title-ename)
    )
  )
  (setq title-link-shared (swcad-title-target-title-native-link-shared-p title-ename))
  (and
    pair-trusted
    (not clone-pair)
    (not legacy-uncertain)
    (not geometry-warning)
    title-link-internal
    (not title-link-shared)
    (swcad-title-exemplar-native-entity-p title-ename)
    (swcad-title-exemplar-native-entity-p frame-ename)
  )
)

(defun swcad-title-target-pair-upgrade-reason (record / title-ename frame-ename frame-block frame-bbox title-role frame-role pair-trusted clone-pair legacy-uncertain geometry-warning title-native frame-native title-link-kinds title-link-internal title-link-shared)
  (setq title-ename (car record))
  (setq frame-ename (cadr record))
  (setq frame-block (caddr record))
  (setq frame-bbox (nth 4 record))
  (setq title-role (nth 5 record))
  (setq frame-role (nth 6 record))
  (setq pair-trusted (swcad-title-trusted-native-exemplar-pair-p title-ename frame-ename frame-block))
  (setq clone-pair
    (or
      (swcad-title-exemplar-clone-role-p title-role)
      (swcad-title-exemplar-clone-role-p frame-role)
    )
  )
  (setq legacy-uncertain
    (or
      (swcad-title-exemplar-legacy-uncertain-native-role-p title-role)
      (swcad-title-exemplar-legacy-uncertain-native-role-p frame-role)
    )
  )
  (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
  (setq title-native (swcad-title-exemplar-native-entity-p title-ename))
  (setq frame-native (swcad-title-exemplar-native-entity-p frame-ename))
  (setq title-link-kinds (swcad-title-native-link-target-kinds title-ename))
  (setq title-link-internal (swcad-title-internal-native-link-kinds-p title-link-kinds))
  (setq title-link-shared (swcad-title-target-title-native-link-shared-p title-ename))
  (cond
    (clone-pair "clone")
    ((or
       (swcad-title-exemplar-moved-unverified-role-p title-role)
       (swcad-title-exemplar-moved-unverified-role-p frame-role)
     )
      "native-created-then-moved; GMPOWEREDIT-unverified"
    )
    (legacy-uncertain "finalize-or-frame-only-marker-needs-native-recheck")
    (geometry-warning (strcat "invalid-frame-bbox: " geometry-warning))
    (title-link-shared "shared-native-link-handle")
    ((not title-link-internal)
      (strcat "title-native-link-not-internal:" (swcad-title-list-string title-link-kinds))
    )
    ((not pair-trusted) "untrusted/non-marker")
    ((not (and title-native frame-native)) "not-native-role")
    (T "native-like")
  )
)

(defun swcad-title-first-target-pair-by-native-like (want-native-like / records result record native-like)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (if (not result)
      (progn
        (setq native-like (swcad-title-target-pair-native-like-p record))
        (if
          (if want-native-like native-like (not native-like))
          (setq result record)
        )
      )
    )
  )
  result
)

(defun swcad-title-print-compact-entity-structure (label ename title-shared-check / data apps native-handles native-kinds role shared shared-text)
  (swcad-title-princ-line (strcat "  " label ":"))
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (setq apps (swcad-title-xdata-app-names ename))
      (setq native-handles (swcad-title-gmtitle-native-xdata-info ename))
      (setq native-kinds (swcad-title-native-link-target-kinds ename))
      (setq role (swcad-title-exemplar-role ename))
      (setq shared (if title-shared-check (swcad-title-target-title-native-link-shared-p ename) nil))
      (setq shared-text
        (if title-shared-check
          (strcat
            ", 제목블록 native 링크 공유="
            (if shared "yes" "no")
          )
          ""
        )
      )
      (swcad-title-princ-line
        (strcat
          "    핸들="
          (swcad-title-ename-handle ename)
          ", role="
          (if (> (strlen role) 0) role "<none>")
          ", xdata 앱="
          (swcad-title-list-string apps)
        )
      )
      (swcad-title-princ-line
        (strcat
          "    native 핸들="
          (swcad-title-list-string native-handles)
          ", native 대상 종류="
          (swcad-title-list-string native-kinds)
          shared-text
        )
      )
      (swcad-title-princ-line
        (strcat
          "    persistent reactor 수="
          (itoa (swcad-title-dxf-code-count data -5))
          ", extension dictionary 수="
          (itoa (swcad-title-dxf-code-count data 360))
          ", 범위="
          (swcad-title-bbox-string (swcad-title-safe-bbox ename))
        )
      )
    )
    (swcad-title-princ-line "    <missing>")
  )
)

(defun swcad-title-print-target-pair-structure-sample (label record / title-ename frame-ename frame-block frame-bbox sheet native-like reason title-role frame-role)
  (swcad-title-princ-line (strcat label ":"))
  (if record
    (progn
      (setq title-ename (car record))
      (setq frame-ename (cadr record))
      (setq frame-block (caddr record))
      (setq frame-bbox (nth 4 record))
      (setq title-role (nth 5 record))
      (setq frame-role (nth 6 record))
      (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
      (setq native-like (swcad-title-target-pair-native-like-p record))
      (setq reason (swcad-title-target-pair-upgrade-reason record))
      (swcad-title-princ-line
        (strcat
          "  용지="
          (if sheet sheet "<unknown>")
          ", 도면틀 블록="
          frame-block
          ", native-like="
          (if native-like "yes" "no")
          ", 이유="
          reason
          ", 제목블록 role="
          (if (> (strlen title-role) 0) title-role "<none>")
          ", 도면틀 role="
          (if (> (strlen frame-role) 0) frame-role "<none>")
          ", 도면틀 범위="
          (swcad-title-bbox-string frame-bbox)
        )
      )
      (swcad-title-print-compact-entity-structure "제목블록" title-ename T)
      (swcad-title-print-compact-entity-structure "도면틀" frame-ename nil)
    )
    (swcad-title-princ-line "  <none>")
  )
)

(defun swcad-title-print-native-vs-nonnative-sample (/ native-record nonnative-record)
  (setq native-record (swcad-title-first-target-pair-by-native-like T))
  (setq nonnative-record (swcad-title-first-target-pair-by-native-like nil))
  (if (or native-record nonnative-record)
    (progn
      (swcad-title-princ-line "native/복제 구조 비교 샘플:")
      (swcad-title-princ-line "  목적: native-like 통과 쌍과 교체 후보의 xdata/handle 차이를 같은 형식으로 비교합니다.")
      (swcad-title-print-target-pair-structure-sample "  native-like 통과 샘플" native-record)
      (swcad-title-print-target-pair-structure-sample "  non-native 교체 후보 샘플" nonnative-record)
      (swcad-title-princ-line "  참고: 이 요약은 읽기 전용이며, 자세한 원인은 이유/제목블록 native 링크 공유/xdata 앱을 우선 봅니다.")
    )
  )
)

(defun swcad-title-sheet-in-list-p (sheet sheets / result item)
  (setq result nil)
  (foreach item sheets
    (if (equal (strcase (swcad-title-string sheet)) (strcase (swcad-title-string item)))
      (setq result T)
    )
  )
  result
)

(defun swcad-title-target-pair-upgrade-candidate-records (sheets / records result record frame-block sheet)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (setq frame-block (caddr record))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (if
      (and
        sheet
        (swcad-title-sheet-in-list-p sheet sheets)
        (not (swcad-title-target-pair-native-like-p record))
      )
      (setq result (append result (list record)))
    )
  )
  result
)

(defun swcad-title-native-upgrade-candidate-records ()
  (swcad-title-target-pair-upgrade-candidate-records '("A2" "A3" "A4"))
)

(defun swcad-title-a3a4-native-upgrade-candidate-records ()
  (swcad-title-native-upgrade-candidate-records)
)

(defun swcad-title-cloned-gmtitle-pair-counts (/ records counts record frame-block sheet)
  (setq records (swcad-title-cloned-gmtitle-pair-records))
  (setq counts nil)
  (foreach record records
    (setq frame-block (caddr record))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (setq counts (swcad-title-count-put (if sheet sheet frame-block) counts))
  )
  counts
)

(defun swcad-title-cloned-gmtitle-pair-total ()
  (length (swcad-title-cloned-gmtitle-pair-records))
)

(defun swcad-title-print-a3a4-native-upgrade-candidates (/ records total record index frame-block sheet reason)
  (setq records (swcad-title-a3a4-native-upgrade-candidate-records))
  (setq total (length records))
  (swcad-title-princ-line (strcat "A2/A3/A4 target pairs needing native replacement: " (itoa total)))
  (if records
    (progn
      (setq index 1)
      (foreach record records
        (setq frame-block (caddr record))
        (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
        (setq reason (swcad-title-target-pair-upgrade-reason record))
        (swcad-title-princ-line
          (strcat
            "  A2/A3/A4 #"
            (itoa index)
            " sheet="
            (if sheet sheet "<unknown>")
            ", title="
            (swcad-title-ename-handle (car record))
            ", frame="
            (swcad-title-ename-handle (cadr record))
            ", block="
            frame-block
            ", title-role="
            (if (> (strlen (nth 5 record)) 0) (nth 5 record) "<none>")
            ", frame-role="
            (if (> (strlen (nth 6 record)) 0) (nth 6 record) "<none>")
            ", reason="
            reason
          )
        )
        (setq index (+ index 1))
      )
    )
  )
  total
)

(defun swcad-title-a3a4-fix-plan (/ records total record frame-block sheet reason sheet-counts reason-counts role-failures command-text-count)
  (swcad-title-open-a3a4-fix-plan-log)
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 A2/A3/A4 GMPOWEREDIT 해결 계획(읽기 전용) -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq command-text-count (swcad-title-command-text-residue-count))
  (swcad-title-princ-line (strcat "Possible accidental command text entities: " (itoa command-text-count)))
  (if (> command-text-count 0)
    (progn
      (swcad-title-princ-line "WARNING: command text may have been inserted into the drawing while CAD was in a text/input state.")
      (swcad-title-princ-line "A2/A3/A4 native 교체 전에 SWTITLESTATUS로 명령어 텍스트 잔여물 후보를 확인하세요.")
      (swcad-title-princ-line "목록의 항목이 작업복사본 안의 실수 명령어 잔여물이 맞다면 SWTITLEPREPARE에서 먼저 정리하세요.")
    )
  )
  (swcad-title-princ-line "Role baseline check:")
  (setq role-failures 0)
  (if (not (swcad-title-role-check-record "native-finalize" T nil))
    (setq role-failures (+ role-failures 1))
  )
  (if (not (swcad-title-role-check-record "native-frame-only" T nil))
    (setq role-failures (+ role-failures 1))
  )
  (setq records (swcad-title-a3a4-native-upgrade-candidate-records))
  (setq total (length records))
  (setq sheet-counts nil)
  (setq reason-counts nil)
  (foreach record records
    (setq frame-block (caddr record))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (setq reason (swcad-title-target-pair-upgrade-reason record))
    (setq sheet-counts (swcad-title-count-put (if sheet sheet frame-block) sheet-counts))
    (setq reason-counts (swcad-title-count-put reason reason-counts))
  )
  (swcad-title-princ-line (strcat "A2/A3/A4 target pairs needing native replacement: " (itoa total)))
  (swcad-title-print-counts "A2/A3/A4 fix candidates by sheet:" sheet-counts)
  (swcad-title-print-counts "A2/A3/A4 fix candidates by reason:" reason-counts)
  (if records
    (progn
      (swcad-title-princ-line "Candidate detail:")
      (swcad-title-print-a3a4-native-upgrade-candidates)
      (if (> command-text-count 0)
        (progn
          (swcad-title-apply-result "REVIEW_ACCIDENTAL_COMMAND_TEXT_BEFORE_NATIVE_GMTITLE_UPGRADE")
          (swcad-title-princ-line "A2/A3/A4 교체 전 다음 확인: SWTITLESTATUS")
          (swcad-title-princ-line "명령어 텍스트 잔여물 확인/정리가 끝나면 SWTITLESTATUS를 다시 실행하세요.")
        )
        (progn
          (swcad-title-apply-result "NEEDS_NATIVE_GMTITLE_UPGRADE")
          (swcad-title-princ-line "다음 명령: SWTITLECONVERTNEXT")
        )
      )
      (swcad-title-princ-line
        (strcat
          "SWTITLECONVERTNEXT processes the next candidate from "
          (itoa total)
          " currently listed A2/A3/A4 candidate(s) through its native replacement phase."
        )
      )
          (swcad-title-princ-line "일반 흐름은 SWTITLECONVERTNEXT를 사용하세요. 수동 응답을 직접 고를 때만 SWTITLECONVERT를 사용하세요.")
          (swcad-title-print-native-batch-safety-guidance)
          (swcad-title-princ-line "GMTITLE 창에서는 출력된 DR_A*_Outline 용지와 DR_titlea_3rd 제목블록을 선택하세요.")
          (swcad-title-princ-line "필수 GMTITLE 옵션: Frame positioning=ON, Object move=OFF.")
          (swcad-title-princ-line "ISO 기본 용지/제목블록이면 확인하지 말고 취소한 뒤 다시 실행하세요.")
    )
    (progn
      (if (> role-failures 0)
        (swcad-title-apply-result "FAIL_ROLE_CLASSIFICATION")
        (swcad-title-apply-result "OK_NO_NATIVE_GMTITLE_FIX_CANDIDATE")
      )
      (swcad-title-princ-line "현재 native 교체 대기 중인 A2/A3/A4 대상 쌍이 없습니다.")
      (swcad-title-princ-line "A2/A3/A4가 여전히 GMPOWEREDIT로 열리면 실패한 제목블록 위치와 SWTITLEVERIFY 로그를 비교하세요.")
      (swcad-title-princ-line "그 다음 SWTITLESTATUS를 다시 실행해 오래된 LSP 로직으로 로드된 쌍인지 확인하세요.")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-print-target-gmtitle-pair-review (/ records total native-like-count clone-count untrusted-count record index title-ename frame-ename frame-block title-role frame-role pair-trusted clone-pair legacy-uncertain native-like sheet reason)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq total (length records))
  (setq native-like-count 0)
  (setq clone-count 0)
  (setq untrusted-count 0)
  (swcad-title-princ-line (strcat "Target GMTITLE frame/title pairs: " (itoa total)))
  (if records
    (progn
      (setq index 1)
      (foreach record records
        (setq title-ename (car record))
        (setq frame-ename (cadr record))
        (setq frame-block (caddr record))
        (setq title-role (nth 5 record))
        (setq frame-role (nth 6 record))
        (setq pair-trusted (swcad-title-trusted-native-exemplar-pair-p title-ename frame-ename frame-block))
        (setq clone-pair
          (or
            (swcad-title-exemplar-clone-role-p title-role)
            (swcad-title-exemplar-clone-role-p frame-role)
          )
        )
        (setq legacy-uncertain
          (or
            (swcad-title-exemplar-legacy-uncertain-native-role-p title-role)
            (swcad-title-exemplar-legacy-uncertain-native-role-p frame-role)
          )
        )
        (setq native-like (swcad-title-target-pair-native-like-p record))
        (setq reason (swcad-title-target-pair-upgrade-reason record))
        (cond
          (native-like (setq native-like-count (+ native-like-count 1)))
          (clone-pair (setq clone-count (+ clone-count 1)))
          (T (setq untrusted-count (+ untrusted-count 1)))
        )
        (if (not native-like)
          (progn
            (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
            (swcad-title-princ-line
              (strcat
                "  review #"
                (itoa index)
                " sheet="
                (if sheet sheet "<unknown>")
                ", title="
                (swcad-title-ename-handle title-ename)
                ", frame="
                (swcad-title-ename-handle frame-ename)
                ", block="
                frame-block
                ", swtitle-marker="
                (if pair-trusted "yes" "no")
                ", clone="
                (if clone-pair "yes" "no")
                ", finalize-recheck-marker="
                (if legacy-uncertain "yes" "no")
                ", title-role="
                (if (> (strlen title-role) 0) title-role "<none>")
                ", frame-role="
                (if (> (strlen frame-role) 0) frame-role "<none>")
                ", reason="
                reason
              )
            )
          )
        )
        (setq index (+ index 1))
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Target pair review counts: native-like="
      (itoa native-like-count)
      ", clone="
      (itoa clone-count)
      ", untrusted/non-marker="
      (itoa untrusted-count)
    )
  )
  (list total native-like-count clone-count untrusted-count)
)

(defun swcad-title-print-native-upgrade-summary (/ records total counts record index)
  (setq records (swcad-title-cloned-gmtitle-pair-records))
  (setq total (length records))
  (setq counts (swcad-title-cloned-gmtitle-pair-counts))
  (swcad-title-princ-line (strcat "Cloned GMTITLE pairs needing native frame upgrade: " (itoa total)))
  (swcad-title-print-counts "Clone pairs by sheet size:" counts)
  (if records
    (progn
      (swcad-title-princ-line "Clone upgrade queue:")
      (setq index 1)
      (foreach record records
        (swcad-title-princ-line
          (strcat
            "  #"
            (itoa index)
            " title="
            (swcad-title-ename-handle (car record))
            ", frame="
            (swcad-title-ename-handle (cadr record))
            ", block="
            (caddr record)
            ", bbox="
            (swcad-title-bbox-string (nth 4 record))
          )
        )
        (setq index (+ index 1))
      )
    )
  )
  total
)

(defun swcad-title-upgrade-native-status (/ summary clone-total a3a4-total review total native-like clone untrusted source-titles source-frames frame-records target-sheet-counts missing-target-sheets selection-risk-count geometry-risk-count overlap-risk-count command-text-count)
  (swcad-title-open-native-upgrade-log)
  (swcad-title-princ-line "----- SWTITLESTATUS 내부 native 도면틀 교체 상태(읽기 전용) -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq source-titles (swcad-title-source-title-candidates))
  (setq source-frames (swcad-title-source-frame-candidates))
  (setq frame-records (swcad-title-frame-records))
  (setq target-sheet-counts (swcad-title-target-frame-sheet-counts))
  (setq missing-target-sheets (swcad-title-missing-required-target-sheets target-sheet-counts (swcad-title-active-required-sheets summary)))
  (swcad-title-princ-line (strcat "Remaining source title candidates: " (itoa (length source-titles))))
  (swcad-title-princ-line (strcat "Remaining source sheet frame candidates: " (itoa (length source-frames))))
  (swcad-title-print-counts "Visible target frame counts by sheet:" target-sheet-counts)
  (swcad-title-print-string-list "현재 필요한 대상 용지 누락:" missing-target-sheets)
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq selection-risk-count (swcad-title-print-target-frame-selection-diagnostics frame-records))
  (setq command-text-count (swcad-title-command-text-residue-count))
  (swcad-title-princ-line (strcat "Possible accidental command text entities: " (itoa command-text-count)))
  (setq clone-total (swcad-title-print-native-upgrade-summary))
  (setq a3a4-total (swcad-title-print-a3a4-native-upgrade-candidates))
  (setq review (swcad-title-print-target-gmtitle-pair-review))
  (setq total (car review))
  (setq native-like (cadr review))
  (setq clone (caddr review))
  (setq untrusted (nth 3 review))
  (cond
    ((> geometry-risk-count 0)
      (swcad-title-apply-result "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (swcad-title-princ-line "이유: 하나 이상의 대상 도면틀 bbox 값이 예상 A규격 형상과 맞지 않습니다.")
      (swcad-title-princ-line "다음: 아직 최종 상태로 보지 마세요. 더블클릭 확인 전에 문제가 있는 용지 크기를 깨끗한 native GMTITLE 정의로 다시 만드세요.")
    )
    ((> selection-risk-count 0)
      (swcad-title-apply-result "WARN_TARGET_FRAME_SELECTION_RISK")
      (swcad-title-princ-line "이유: 하나 이상의 대상 도면틀 선택 bbox가 너무 크거나 다른 대상 도면틀과 겹칩니다.")
      (swcad-title-princ-line "다음: 계속하기 전에 SWTITLEVERIFY를 실행하고 검증 로그를 확인하세요.")
    )
    ((and (> command-text-count 0) (> a3a4-total 0))
      (swcad-title-apply-result "REVIEW_ACCIDENTAL_COMMAND_TEXT_BEFORE_NATIVE_GMTITLE_UPGRADE")
      (swcad-title-princ-line "이유: A2/A3/A4 native 교체 후보가 있는 상태에서 도면 안에 명령어 텍스트 후보가 있습니다.")
      (swcad-title-princ-line "다음: A2/A3/A4 교체 전에 SWTITLESTATUS로 표시된 TEXT/MTEXT 후보를 확인하세요.")
      (swcad-title-princ-line "작업복사본 안의 실수 명령어 잔여물이 맞다면 먼저 정리한 뒤 SWTITLESTATUS를 다시 실행하세요.")
      (swcad-title-princ-line (strcat "그 뒤 후보 수가 아직 " (itoa a3a4-total) "이면 SWTITLECONVERTNEXT를 실행하세요."))
    )
    ((> a3a4-total 0)
      (swcad-title-apply-result "NEEDS_NATIVE_GMTITLE_UPGRADE")
      (swcad-title-princ-line "이유: 일부 A2/A3/A4 GMTITLE 쌍이 아직 새 native GMTITLE 쌍으로 신뢰되지 않습니다.")
      (swcad-title-princ-line "이 쌍들은 속성과 SWTITLE 표식이 맞아도 GMTITLE 표 편집창 대신 GMPOWEREDIT/REFEDIT로 열릴 수 있습니다.")
      (swcad-title-princ-line "원인: clone, preserve-copy, native-finalize, native-frame-only 결과는 모양이 맞아도 모든 시트의 더블클릭 native 인식이 보장되지는 않습니다.")
      (swcad-title-princ-line "해결: 목록의 A2/A3/A4 쌍을 새 native GMTITLE 결과로 한 장씩 교체합니다. 값은 복사하고 신뢰되지 않은 기존 쌍은 삭제합니다.")
      (if (or (> (length source-titles) 0) (> (length source-frames) 0))
        (progn
          (swcad-title-princ-line "남은 원본 시트 처리는 목록의 clone/non-native 쌍을 검토한 뒤 별도로 이어집니다.")
          (swcad-title-princ-line "이 단계는 누락된 title-missing/frame-only 대상 시트를 만들지 않고, 이미 만들어진 대상 쌍의 native 인식만 복구합니다.")
          (swcad-title-princ-line "title-missing/frame-only 원본 시트가 남아 있어도 표시된 native 대상 쌍은 지금 교체할 수 있습니다.")
        )
      )
      (swcad-title-princ-line "다음 안전한 경로: SWTITLECONVERTNEXT를 실행하면 native 교체 단계로 들어갑니다.")
      (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
      (swcad-title-princ-line (strcat "SWTITLECONVERTNEXT는 현재 표시된 후보 " (itoa a3a4-total) "개 중 다음 1개를 처리한 뒤 상태 확인으로 돌아갑니다."))
      (swcad-title-print-native-batch-safety-guidance)
      (swcad-title-princ-line "각 GMTITLE 창에서는 출력된 DR_A*_Outline 용지와 DR_titlea_3rd를 선택하고, Frame positioning은 ON, Object move는 OFF로 둔 뒤 확인하세요.")
      (swcad-title-princ-line "DR이 아닌 일반 용지 또는 ISO 제목블록 기본값이면 확인하지 말고 취소한 뒤 다시 실행하세요.")
      (swcad-title-princ-line "특정 시트를 먼저 진단하려면 해당 제목블록 위치와 SWTITLEVERIFY 로그를 비교하세요.")
      (if (or (> (length source-titles) 0) (> (length source-frames) 0))
        (swcad-title-princ-line "그 뒤 SWTITLESTATUS를 다시 실행하고 남은 원본 시트는 SWTITLECONVERTNEXT로 처리하세요.")
      )
    )
    ((or (> (length source-titles) 0) (> (length source-frames) 0))
      (swcad-title-apply-result "WAITING_FOR_TRANSFER_SOURCES_REMAIN")
      (swcad-title-princ-line "Reason: old SOLIDWORKS source title/frame candidates still remain.")
      (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행하세요.")
      (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
    )
    (missing-target-sheets
      (swcad-title-apply-result "WARN_REQUIRED_TARGET_SHEET_MISSING")
      (swcad-title-princ-line "이유: 현재 원본/대상 기준으로 필요한 GMTITLE 도면틀이 아직 없습니다.")
      (swcad-title-princ-line "다음: 최종 더블클릭 확인 전에 누락된 용지 크기를 생성/마무리하세요.")
    )
    ((= total 0)
      (swcad-title-apply-result "OK_NO_TARGET_GMTITLE_PAIR")
    )
    ((= a3a4-total 0)
      (swcad-title-apply-result "OK_NATIVE_GMTITLE_UPGRADE_COMPLETE")
      (if (> untrusted 0)
        (swcad-title-princ-line "Note: remaining untrusted/non-marker pairs are outside the A2/A3/A4 upgrade queue, usually the pre-existing A2 baseline.")
      )
      (swcad-title-princ-line "다음: SWTITLEVERIFY를 실행한 뒤, 실제 DR_titlea_3rd 제목블록이 있는 대표 용지만 더블클릭해 최종 CAD 동작을 확인하세요.")
    )
    ((> clone-total 0)
      (swcad-title-apply-result "NEEDS_NATIVE_FRAME_UPGRADE")
    )
    ((= native-like total)
      (swcad-title-apply-result "OK_NO_CLONED_GMTITLE_PAIR")
    )
    (T
      (swcad-title-apply-result "NEEDS_NATIVE_FRAME_REVIEW")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-upgrade-native-one (/ *error* opened-log pair old-title old-frame frame-block target-sheet target-reason old-title-bbox old-frame-bbox old-title-role old-frame-role old-title-object values answer placement-point gmtitle-result new-title new-frame new-enames actual-title-name actual-frame-name geometry-warning doc align-result align-count align-dx align-dy align-needed new-title-object attr-count marker-role marker-ok deleted-new-count remaining-a3a4-count)
  (setq opened-log nil)
  (if (not *swcad-title-native-upgrade-batch-mode*)
    (progn
      (swcad-title-open-native-upgrade-log)
      (setq opened-log T)
    )
  )
  (defun *error* (msg)
    (if msg
      (swcad-title-princ-line (strcat "Error: " (swcad-title-string msg)))
    )
    (setq *swcad-title-native-upgrade-selected-pair* nil)
    (swcad-title-apply-result "ERROR_NATIVE_UPGRADE")
    (if opened-log
      (swcad-title-close-log)
    )
    (princ)
  )
  (setq *swcad-title-last-apply-status* nil)
  (setq pair
    (if *swcad-title-native-upgrade-selected-pair*
      *swcad-title-native-upgrade-selected-pair*
      (or
        (car (swcad-title-a3a4-native-upgrade-candidate-records))
        (swcad-title-first-cloned-gmtitle-pair-record)
      )
    )
  )
  (setq *swcad-title-native-upgrade-selected-pair* nil)
  (setq old-title (if pair (car pair) nil))
  (setq old-frame (if pair (cadr pair) nil))
  (setq frame-block (if pair (caddr pair) nil))
  (setq target-sheet (if frame-block (swcad-title-sheet-size-from-block-name frame-block) nil))
  (setq target-reason (if pair (swcad-title-target-pair-upgrade-reason pair) ""))
  (setq old-title-bbox (if pair (cadddr pair) nil))
  (setq old-frame-bbox (if pair (nth 4 pair) nil))
  (setq old-title-role (if pair (nth 5 pair) ""))
  (setq old-frame-role (if pair (nth 6 pair) ""))
  (setq old-title-object (swcad-title-safe-vla-object old-title))
  (setq values (if old-title-object (swcad-title-title-attribute-pairs old-title-object) nil))
  (setq placement-point (swcad-title-bbox-lower-left-point old-frame-bbox))
  (swcad-title-princ-line "----- SWTITLECONVERT 내부 기존 쌍 native 도면틀 교체 -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (cond
    ((not pair)
      (swcad-title-apply-result "STOP_NO_NATIVE_UPGRADE_CANDIDATE")
      (swcad-title-princ-line "No A2/A3/A4 native-recheck or cloned GMTITLE pair was found.")
      (swcad-title-princ-line "도면틀 선택이 여전히 이상하면 SWTITLESTATUS와 SWTITLEVERIFY 로그를 함께 확인하세요.")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before upgrading.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before upgrading.")
    )
    (T
      (swcad-title-princ-line
        (strcat
          "Upgrade target: sheet="
          (if target-sheet target-sheet "<unknown>")
          ", expected-frame="
          frame-block
          ", expected-title="
          (swcad-title-target-title-block-name)
          ", reason="
          target-reason
        )
      )
      (swcad-title-princ-line
        (strcat
          "Existing GMTITLE title to replace: handle="
          (swcad-title-ename-handle old-title)
          ", role="
          (if (> (strlen old-title-role) 0) old-title-role "<none>")
          ", bbox="
          (swcad-title-bbox-string old-title-bbox)
        )
      )
      (swcad-title-princ-line
        (strcat
          "Existing GMTITLE frame to replace: handle="
          (swcad-title-ename-handle old-frame)
          ", block="
          frame-block
          ", role="
          (if (> (strlen old-frame-role) 0) old-frame-role "<none>")
          ", bbox="
          (swcad-title-bbox-string old-frame-bbox)
        )
      )
      (swcad-title-princ-line (strcat "Attributes to copy: " (itoa (length values))))
      (if
        (or
          *swcad-title-native-upgrade-batch-mode*
          *swcad-title-skip-native-upgrade-confirmation*
          *swcad-title-convert-next-mode*
        )
        (setq answer "YES")
        (setq answer
          (getstring
            T
            "\n이 위치에 새 native GMTITLE 1장을 만들고 값을 복사한 뒤 기존 쌍을 삭제하려면 YES를 입력하세요: "
          )
        )
      )
      (if (/= (strcase answer) "YES")
        (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_USER")
        (progn
          (setq gmtitle-result (swcad-title-run-native-gmtitle-prefer-commandline frame-block placement-point))
          (setq new-title (car gmtitle-result))
          (setq new-frame (cadr gmtitle-result))
          (setq new-enames (caddr gmtitle-result))
          (setq actual-title-name (if new-title (swcad-title-effective-insert-name new-title) ""))
          (setq actual-frame-name (if new-frame (swcad-title-effective-insert-name new-frame) ""))
          (setq geometry-warning
            (if new-frame
              (swcad-title-frame-bbox-size-warning-for-block
                frame-block
                (swcad-title-frame-reference-effective-bbox new-frame frame-block)
              )
              nil
            )
          )
          (if
            (and
              new-title
              new-frame
              (swcad-title-native-target-title-name-p actual-title-name)
              (swcad-title-frame-name-matches-p actual-frame-name frame-block)
              (not geometry-warning)
            )
            (progn
              (setq doc (swcad-title-doc))
              (vl-catch-all-apply 'vla-StartUndoMark (list doc))
              (setq align-result (swcad-title-align-gmtitle-to-frame-bbox new-title new-frame old-frame-bbox))
              (setq align-count (car align-result))
              (setq align-dx (cadr align-result))
              (setq align-dy (caddr align-result))
              (setq align-needed (or (> (swcad-title-abs align-dx) 0.0001) (> (swcad-title-abs align-dy) 0.0001)))
              (if (and align-needed (< align-count 2))
                (progn
                  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                  (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
                  (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_ALIGN_FAILED")
                  (swcad-title-princ-line
                    (strcat
                      "New native GMTITLE alignment failed: moved="
                      (itoa align-count)
                      ", dx="
                      (swcad-title-number-string align-dx)
                      ", dy="
                      (swcad-title-number-string align-dy)
                    )
                  )
                  (swcad-title-princ-line (strcat "Removed new GMTITLE inserts: " (itoa deleted-new-count)))
                  (swcad-title-princ-line "The existing GMTITLE pair was kept.")
                )
                (if
                  (and
                    align-needed
                    (not *swcad-title-last-native-gmtitle-placement-used*)
                    (swcad-title-native-placement-substantial-move-p align-dx align-dy)
                    (not (swcad-title-moved-native-placement-allowed-p target-sheet frame-block))
                  )
                  (progn
                    (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                    (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
                    (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_REQUIRES_NATIVE_PLACEMENT")
                    (swcad-title-princ-line "Native GMTITLE이 기본 위치에 생성되어 이후 LISP MOVE 정렬이 필요했습니다.")
                    (swcad-title-princ-line "이 방식은 시각적으로 맞아도 GMPOWEREDIT가 실패할 수 있어 신뢰하지 않습니다.")
                    (swcad-title-princ-line (strcat "신뢰하지 않는 새 GMTITLE INSERT 삭제: " (itoa deleted-new-count)))
                    (swcad-title-princ-line "기존 GMTITLE 쌍은 유지했습니다.")
                    (swcad-title-princ-line "다음: Object move OFF 상태에서 명령을 다시 실행하고 GMTITLE이 왼쪽 아래 배치점을 받도록 하세요.")
                  )
                  (progn
                    (setq new-title-object (swcad-title-safe-vla-object new-title))
                    (setq attr-count (swcad-title-set-insert-attributes new-title-object values))
                    (swcad-title-delete-ename old-title)
                    (swcad-title-delete-ename old-frame)
                    (setq marker-role
                      (if
                        (and
                          align-needed
                          (not *swcad-title-last-native-gmtitle-placement-used*)
                          (swcad-title-native-placement-substantial-move-p align-dx align-dy)
                          (swcad-title-moved-native-placement-allowed-p target-sheet frame-block)
                        )
                        "native-moved-placement-accepted"
                        "native-upgrade"
                      )
                    )
                    (setq marker-ok
                      (swcad-title-mark-native-exemplar-pair
                        new-title
                        new-frame
                        frame-block
                        marker-role
                      )
                    )
                    (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                    (setq remaining-a3a4-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
                    (swcad-title-princ-line
                      (strcat
                        "Native GMTITLE aligned to cloned frame location: moved="
                        (itoa align-count)
                        ", dx="
                        (swcad-title-number-string align-dx)
                        ", dy="
                        (swcad-title-number-string align-dy)
                      )
                    )
                    (swcad-title-princ-line (strcat "Attributes copied: " (itoa attr-count)))
                    (swcad-title-princ-line (strcat "Native upgrade marker set: " (if marker-ok "yes" "no") ", role=" marker-role))
                    (if (equal (strcase marker-role) "NATIVE-MOVED-PLACEMENT-ACCEPTED")
                      (progn
                        (swcad-title-princ-line "Moved native placement accepted after geometry check.")
                        (swcad-title-princ-line "Run final double-click verification after conversion.")
                      )
                    )
                    (swcad-title-princ-line "Old cloned title deleted: yes")
                    (swcad-title-princ-line "Old cloned frame deleted: yes")
                    (swcad-title-princ-line (strcat "Remaining A2/A3/A4 native upgrade candidates: " (itoa remaining-a3a4-count)))
                    (swcad-title-apply-result "UPGRADED_CLONE_TO_NATIVE_GMTITLE")
                    (swcad-title-princ-line "Manual check: double-click the upgraded title block and confirm the GMTITLE table editor opens.")
                    (if (> remaining-a3a4-count 0)
                      (swcad-title-princ-line "이 시트가 정상이라면 SWTITLESTATUS를 실행한 뒤 다음 A2/A3/A4 후보를 SWTITLECONVERTNEXT로 처리하세요.")
                      (swcad-title-princ-line "모든 A2/A3/A4 교체 후보가 정리됐습니다. SWTITLEVERIFY를 실행하세요.")
                    )
                  )
                )
              )
            )
            (progn
              (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
              (cond
                (geometry-warning
                  (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_INVALID_FRAME_GEOMETRY")
                )
                ((= (length new-enames) 0)
                  (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS")
                )
                (T
                  (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_WRONG_GMTITLE_SELECTION")
                )
              )
              (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
              (swcad-title-princ-line (strcat "Expected title block: " (swcad-title-target-title-block-name)))
              (swcad-title-princ-line (strcat "Actual title block: " (if (> (strlen actual-title-name) 0) actual-title-name "<missing>")))
              (swcad-title-princ-line (strcat "Actual frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
              (if *swcad-title-last-native-gmtitle-abort-reason*
                (swcad-title-princ-line
                  (strcat
                    "Native GMTITLE abort reason: "
                    *swcad-title-last-native-gmtitle-abort-reason*
                  )
                )
              )
              (if geometry-warning
                (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
              )
              (swcad-title-princ-line (strcat "Removed wrong/new GMTITLE inserts: " (itoa deleted-new-count)))
              (swcad-title-princ-line "The existing GMTITLE pair was kept.")
              (cond
                (geometry-warning
                  (swcad-title-princ-line "Next: recreate this sheet with the expected DR paper size before retrying the A2/A3/A4 native upgrade.")
                )
                ((= (length new-enames) 0)
                  (swcad-title-princ-line "Next: rerun the command and complete the GMTITLE dialog; canceling the dialog leaves the old pair unchanged.")
                )
                (T
                  (swcad-title-princ-line "Next: rerun and choose the printed DR_A*_Outline paper plus DR_titlea_3rd; do not accept ISO defaults.")
                )
              )
            )
          )
        )
      )
    )
  )
  (if opened-log
    (swcad-title-close-log)
  )
  (princ)
)

(defun swcad-title-pending-manual-native-value (key)
  (cdr (assoc key *swcad-title-pending-manual-native-upgrade*))
)

(defun swcad-title-upgrade-native-a3a4-prepare (/ pair old-title old-frame frame-block target-sheet target-reason old-frame-bbox old-title-object values before-handles placement-point)
  (swcad-title-open-native-upgrade-log)
  (setq pair (car (swcad-title-a3a4-native-upgrade-candidate-records)))
  (setq old-title (if pair (car pair) nil))
  (setq old-frame (if pair (cadr pair) nil))
  (setq frame-block (if pair (caddr pair) nil))
  (setq target-sheet (if frame-block (swcad-title-sheet-size-from-block-name frame-block) nil))
  (setq target-reason (if pair (swcad-title-target-pair-upgrade-reason pair) ""))
  (setq old-frame-bbox (if pair (nth 4 pair) nil))
  (setq old-title-object (swcad-title-safe-vla-object old-title))
  (setq values (if old-title-object (swcad-title-title-attribute-pairs old-title-object) nil))
  (setq before-handles (swcad-title-insert-handle-list))
  (setq placement-point (swcad-title-bbox-lower-left-point old-frame-bbox))
  (swcad-title-princ-line "----- internal A2/A3/A4 manual native GMTITLE prepare -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (cond
    ((not pair)
      (setq *swcad-title-pending-manual-native-upgrade* nil)
      (swcad-title-apply-result "STOP_NO_NATIVE_GMTITLE_UPGRADE_CANDIDATE")
      (swcad-title-princ-line "No A2/A3/A4 target pair currently needs native replacement.")
      (swcad-title-princ-line "현재 상태를 확인하려면 SWTITLESTATUS를 실행하세요.")
    )
    ((swcad-title-document-read-only-p)
      (setq *swcad-title-pending-manual-native-upgrade* nil)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before preparing a manual native GMTITLE replacement.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (setq *swcad-title-pending-manual-native-upgrade* nil)
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Manual native replacement is limited to Documents/CAD tool/work copies.")
    )
    ((not placement-point)
      (setq *swcad-title-pending-manual-native-upgrade* nil)
      (swcad-title-apply-result "ABORT_NO_TARGET_FRAME_PLACEMENT_POINT")
      (swcad-title-princ-line "The target frame bbox did not provide a lower-left placement point.")
    )
    (T
      (setq *swcad-title-pending-manual-native-upgrade*
        (list
          (cons "old-title-handle" (swcad-title-ename-handle old-title))
          (cons "old-frame-handle" (swcad-title-ename-handle old-frame))
          (cons "frame-block" frame-block)
          (cons "target-sheet" target-sheet)
          (cons "target-reason" target-reason)
          (cons "old-frame-bbox" old-frame-bbox)
          (cons "values" values)
          (cons "before-handles" before-handles)
          (cons "placement-point" placement-point)
        )
      )
      (swcad-title-princ-line
        (strcat
          "Prepared target: sheet="
          (if target-sheet target-sheet "<unknown>")
          ", frame="
          frame-block
          ", title="
          (swcad-title-ename-handle old-title)
          ", reason="
          target-reason
        )
      )
      (swcad-title-princ-line (strcat "기존 도면틀 핸들: " (swcad-title-ename-handle old-frame)))
      (swcad-title-princ-line (strcat "기존 도면틀 범위: " (swcad-title-bbox-string old-frame-bbox)))
      (swcad-title-princ-line (strcat "복사용으로 저장한 속성 수: " (itoa (length values))))
      (swcad-title-princ-line (strcat "GMTITLE에서 선택할 용지/형식: " frame-block))
      (swcad-title-princ-line (strcat "GMTITLE에서 선택할 제목블록: " (swcad-title-target-title-block-name)))
      (swcad-title-princ-line "GMTITLE 옵션: Frame positioning ON, Object move OFF.")
      (swcad-title-princ-line (strcat "GMTITLE 기준점은 기존 도면틀 왼쪽 아래입니다: " (swcad-title-point-string placement-point)))
      (swcad-title-princ-line "긴 소수점 좌표를 직접 치지 말고, 가능하면 기존 도면틀 왼쪽 아래 끝점/스냅으로 지정하세요.")
      (swcad-title-princ-line "마무리 단계에서 새 GMTITLE이 이 기준점과 맞는지 검사합니다.")
      (swcad-title-princ-line "native GMTITLE이 화면에 생성된 것이 보이면, 안내된 마무리/재시도 흐름을 위해 SWTITLECONVERTNEXT를 계속 실행하세요.")
      (swcad-title-princ-line "팁: 4단계 흐름의 SWTITLECONVERTNEXT를 사용하면 GMTITLE 창 이후 왼쪽 아래 점을 자동으로 보냅니다.")
      (swcad-title-apply-result "READY_MANUAL_NATIVE_GMTITLE_CREATE")
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-upgrade-native-a3a4-finish (/ old-title-handle old-frame-handle old-title old-frame frame-block target-sheet target-reason old-frame-bbox values before-handles new-enames new-title new-frame actual-title-name actual-frame-name geometry-warning doc align-result align-count align-dx align-dy align-needed new-title-object attr-count marker-ok deleted-new-count remaining-a3a4-count)
  (swcad-title-open-native-upgrade-log)
  (setq old-title-handle (swcad-title-pending-manual-native-value "old-title-handle"))
  (setq old-frame-handle (swcad-title-pending-manual-native-value "old-frame-handle"))
  (setq old-title (if old-title-handle (handent old-title-handle) nil))
  (setq old-frame (if old-frame-handle (handent old-frame-handle) nil))
  (setq frame-block (swcad-title-pending-manual-native-value "frame-block"))
  (setq target-sheet (swcad-title-pending-manual-native-value "target-sheet"))
  (setq target-reason (swcad-title-pending-manual-native-value "target-reason"))
  (setq old-frame-bbox (swcad-title-pending-manual-native-value "old-frame-bbox"))
  (setq values (swcad-title-pending-manual-native-value "values"))
  (setq before-handles (swcad-title-pending-manual-native-value "before-handles"))
  (swcad-title-princ-line "----- internal A2/A3/A4 manual native GMTITLE finish -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (cond
    ((not *swcad-title-pending-manual-native-upgrade*)
      (swcad-title-apply-result "ABORT_NO_MANUAL_NATIVE_GMTITLE_PENDING")
      (swcad-title-princ-line "SWTITLECONVERTNEXT를 다시 실행하고 출력된 값으로 native GMTITLE 한 장을 만드세요.")
    )
    ((or (not old-title) (not old-frame))
      (setq *swcad-title-pending-manual-native-upgrade* nil)
      (swcad-title-apply-result "ABORT_PENDING_TARGET_PAIR_MISSING")
      (swcad-title-princ-line "대기 중이던 기존 대상 쌍이 더 이상 없습니다. SWTITLESTATUS 후 SWTITLECONVERTNEXT를 다시 실행하세요.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Manual native finish is limited to Documents/CAD tool/work copies.")
    )
    (T
      (setq new-enames (swcad-title-new-insert-enames before-handles))
      (setq new-title (swcad-title-select-new-gmtitle-title new-enames))
      (setq new-frame (swcad-title-select-new-gmtitle-frame new-enames new-title frame-block))
      (setq actual-title-name (if new-title (swcad-title-effective-insert-name new-title) ""))
      (setq actual-frame-name (if new-frame (swcad-title-effective-insert-name new-frame) ""))
      (setq geometry-warning
        (if new-frame
          (swcad-title-frame-bbox-size-warning-for-block
            frame-block
            (swcad-title-frame-reference-effective-bbox new-frame frame-block)
          )
          nil
        )
      )
      (swcad-title-princ-line
        (strcat
          "Pending target: sheet="
          (if target-sheet target-sheet "<unknown>")
          ", frame="
          frame-block
          ", reason="
          (swcad-title-string target-reason)
        )
      )
      (swcad-title-princ-line (strcat "New INSERTs since prepare: " (itoa (length new-enames))))
      (swcad-title-insert-log-label "New native GMTITLE title candidate" new-title)
      (swcad-title-insert-log-label "New native GMTITLE frame candidate" new-frame)
      (if
        (and
          new-title
          new-frame
          (swcad-title-native-target-title-name-p actual-title-name)
          (swcad-title-frame-name-matches-p actual-frame-name frame-block)
          (not geometry-warning)
        )
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq align-result (swcad-title-align-gmtitle-to-frame-bbox new-title new-frame old-frame-bbox))
          (setq align-count (car align-result))
          (setq align-dx (cadr align-result))
          (setq align-dy (caddr align-result))
          (setq align-needed (or (> (swcad-title-abs align-dx) 0.0001) (> (swcad-title-abs align-dy) 0.0001)))
          (if
            (and
              align-needed
              (swcad-title-native-placement-substantial-move-p align-dx align-dy)
            )
            (progn
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
              (swcad-title-apply-result "ABORT_MANUAL_NATIVE_GMTITLE_WRONG_LOCATION")
              (swcad-title-princ-line "The new GMTITLE was not created at the pending frame lower-left point.")
              (swcad-title-princ-line
                (strcat
                  "Alignment would have moved "
                  (itoa align-count)
                  " object(s), dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line (strcat "Removed new GMTITLE inserts: " (itoa deleted-new-count)))
              (swcad-title-princ-line "SWTITLECONVERTNEXT를 다시 실행하고 기존 도면틀 왼쪽 아래 끝점/스냅으로 GMTITLE을 만드세요.")
            )
            (progn
              (setq new-title-object (swcad-title-safe-vla-object new-title))
              (setq attr-count (swcad-title-set-insert-attributes new-title-object values))
              (swcad-title-delete-ename old-title)
              (swcad-title-delete-ename old-frame)
              (setq marker-ok
                (swcad-title-mark-native-exemplar-pair
                  new-title
                  new-frame
                  frame-block
                  "native-upgrade"
                )
              )
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (setq *swcad-title-pending-manual-native-upgrade* nil)
              (setq remaining-a3a4-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
              (swcad-title-princ-line
                (strcat
                  "Native GMTITLE aligned to pending frame: moved="
                  (itoa align-count)
                  ", dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line (strcat "Attributes copied: " (itoa attr-count)))
              (swcad-title-princ-line (strcat "Native upgrade marker set: " (if marker-ok "yes" "no") ", role=native-upgrade"))
              (swcad-title-princ-line "Old cloned/untrusted title deleted: yes")
              (swcad-title-princ-line "Old cloned/untrusted frame deleted: yes")
              (swcad-title-princ-line (strcat "Remaining A2/A3/A4 native upgrade candidates: " (itoa remaining-a3a4-count)))
              (swcad-title-apply-result "FINISHED_MANUAL_NATIVE_GMTITLE_UPGRADE")
              (if (> remaining-a3a4-count 0)
                (swcad-title-princ-line "다음: SWTITLESTATUS를 실행한 뒤 SWTITLECONVERTNEXT로 다음 후보를 처리하세요.")
                (swcad-title-princ-line "모든 A2/A3/A4 native 교체 후보가 정리됐습니다. SWTITLEVERIFY를 실행하세요.")
              )
            )
          )
        )
        (progn
          (setq deleted-new-count 0)
          (if (> (length new-enames) 0)
            (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
          )
          (cond
            (geometry-warning
              (swcad-title-apply-result "ABORT_MANUAL_NATIVE_GMTITLE_INVALID_FRAME_GEOMETRY")
            )
            ((= (length new-enames) 0)
              (swcad-title-apply-result "ABORT_MANUAL_NATIVE_GMTITLE_NOT_CREATED")
            )
            (T
              (swcad-title-apply-result "ABORT_MANUAL_NATIVE_GMTITLE_WRONG_SELECTION")
            )
          )
          (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
          (swcad-title-princ-line (strcat "Expected title block: " (swcad-title-target-title-block-name)))
          (swcad-title-princ-line (strcat "Actual title block: " (if (> (strlen actual-title-name) 0) actual-title-name "<missing>")))
          (swcad-title-princ-line (strcat "Actual frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
          (if geometry-warning
            (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
          )
          (swcad-title-princ-line (strcat "Removed wrong/new GMTITLE inserts: " (itoa deleted-new-count)))
          (swcad-title-princ-line "대기 중이던 기존 대상 쌍은 보존됐습니다. SWTITLECONVERTNEXT를 실행해 GMTITLE을 다시 만드세요.")
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-upgrade-native-select (/ picked ename pick-point wcs-point insert-ename pair)
  (swcad-title-princ-line "Select a cloned or target GMTITLE frame/title to upgrade to real native GMTITLE.")
  (setq picked (entsel "\nSelect GMTITLE frame/title to upgrade: "))
  (setq ename (if picked (car picked) nil))
  (setq pick-point (if picked (cadr picked) nil))
  (setq wcs-point (swcad-title-safe-trans-point pick-point 1 0))
  (setq insert-ename (swcad-title-enclosing-insert-ename ename))
  (setq pair (if ename (swcad-title-cloned-gmtitle-pair-record-for-ename ename) nil))
  (if (not pair)
    (setq pair (swcad-title-cloned-gmtitle-pair-record-for-point pick-point))
  )
  (if (and (not pair) wcs-point)
    (setq pair (swcad-title-cloned-gmtitle-pair-record-for-point wcs-point))
  )
  (if (not pair)
    (setq pair (if ename (swcad-title-target-gmtitle-pair-record-for-ename ename) nil))
  )
  (if (not pair)
    (setq pair (swcad-title-target-gmtitle-pair-record-for-point pick-point))
  )
  (if (and (not pair) wcs-point)
    (setq pair (swcad-title-target-gmtitle-pair-record-for-point wcs-point))
  )
  (if pair
    (progn
      (setq *swcad-title-native-upgrade-selected-pair* pair)
      (swcad-title-upgrade-native-one)
    )
    (progn
      (swcad-title-open-native-upgrade-log)
      (swcad-title-princ-line "----- SWTITLECONVERT 내부 선택 대상 native 교체 -----")
      (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
      (if ename
        (swcad-title-princ-line
          (strcat
            "Selected entity handle: "
            (swcad-title-ename-handle ename)
            ", type="
            (swcad-title-entity-type-name ename)
          )
        )
        (swcad-title-princ-line "Selected entity: <none>")
      )
      (swcad-title-princ-line
        (strcat
          "Selected point: "
          (if pick-point (swcad-title-point-string pick-point) "<none>")
        )
      )
      (swcad-title-princ-line
        (strcat
          "Selected point WCS: "
          (if wcs-point (swcad-title-point-string wcs-point) "<none>")
        )
      )
      (if insert-ename
        (swcad-title-princ-line
          (strcat
            "Enclosing insert: handle="
            (swcad-title-ename-handle insert-ename)
            ", block="
            (swcad-title-effective-insert-name insert-ename)
          )
        )
        (swcad-title-princ-line "Enclosing insert: <none>")
      )
      (swcad-title-apply-result "ABORT_SELECTED_ENTITY_IS_NOT_TARGET_GMTITLE_PAIR")
      (swcad-title-princ-line "No drawing data was changed.")
      (swcad-title-close-log)
    )
  )
  (princ)
)

(defun swcad-title-upgrade-native-a3a4-next (/ records total pair frame-block sheet reason answer old-skip result)
  (setq records (swcad-title-a3a4-native-upgrade-candidate-records))
  (setq total (length records))
  (setq pair (if records (car records) nil))
  (if pair
    (progn
      (setq frame-block (caddr pair))
      (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
      (setq reason (swcad-title-target-pair-upgrade-reason pair))
      (swcad-title-princ-line
        (strcat
          "Next A2/A3/A4 native upgrade candidate: sheet="
          (if sheet sheet "<unknown>")
          ", title="
          (swcad-title-ename-handle (car pair))
          ", frame="
          (swcad-title-ename-handle (cadr pair))
          ", block="
          frame-block
          ", reason="
          reason
        )
      )
      (swcad-title-princ-line
        (strcat
          "현재 A2/A3/A4 native 교체 후보는 "
          (itoa total)
          "개입니다."
        )
      )
      (swcad-title-princ-line "기본은 한 번에 한 시트만 교체합니다. 여러 장을 이어서 처리하려면 BATCH를 사용할 수 있습니다.")
      (swcad-title-princ-line "GMTITLE 창은 여전히 DR이 아닌 일반 용지 또는 ISO 제목블록 기본값으로 열릴 수 있습니다.")
      (swcad-title-princ-line "창에 DR 용지와 DR_titlea_3rd가 표시되지 않으면 OK를 누르지 마세요.")
      (swcad-title-princ-line
        (strcat
          "필수 GMTITLE 선택: 용지="
          frame-block
          ", 제목블록="
          (swcad-title-target-title-block-name)
          ", Frame positioning=ON, Object move=OFF."
        )
      )
      (swcad-title-princ-line "OPEN은 다음 후보 1장만 처리합니다. MANUAL은 자동 흐름이 GMTITLE 생성 객체를 놓칠 때 준비/마무리 방식으로 복구합니다.")
      (swcad-title-princ-line "BATCH는 수량을 입력받고 GMTITLE 창을 여러 번 이어서 열 수 있습니다.")
      (swcad-title-print-native-batch-safety-guidance)
      (swcad-title-princ-line "BATCH 중에도 각 GMTITLE 창에서 DR 용지/DR_titlea_3rd/옵션을 반드시 눈으로 확인하세요.")
      (swcad-title-princ-line "처리 후에는 SWTITLESTATUS를 다시 실행하세요. native 교체가 필요한 A2/A3/A4 대상 쌍이 0이 될 때까지 진행합니다.")
      (setq answer
        (swcad-title-auto-next-answer-or-prompt
          "OPEN"
          "A2/A3/A4 native 교체 후보 1장 처리"
          "\n이 한 장의 GMTITLE 창을 열려면 OPEN, 수동 생성 후 마무리하려면 MANUAL, 여러 장을 이어서 처리하려면 BATCH, 안전하게 중단하려면 Enter를 누르세요: "
        )
      )
      (cond
        ((= (strcase answer) "OPEN")
          (setq *swcad-title-native-upgrade-selected-pair* pair)
          (setq old-skip *swcad-title-skip-native-upgrade-confirmation*)
          (setq *swcad-title-skip-native-upgrade-confirmation* T)
          (setq result (vl-catch-all-apply 'swcad-title-upgrade-native-one nil))
          (setq *swcad-title-skip-native-upgrade-confirmation* old-skip)
          (if (vl-catch-all-error-p result)
            (progn
              (swcad-title-princ-line
                (strcat
                  "SWTITLECONVERT A2/A3/A4 native replacement error: "
                  (vl-catch-all-error-message result)
                )
              )
              (princ)
            )
          )
        )
        ((= (strcase answer) "MANUAL")
          (swcad-title-princ-line "A2/A3/A4 MANUAL 복구 모드로 전환합니다.")
          (swcad-title-princ-line "이번 실행은 대상/값/왼쪽 아래 기준점만 저장합니다. GMTITLE로 안내된 한 장을 만든 뒤 SWTITLECONVERTNEXT를 다시 실행하면 마무리합니다.")
          (swcad-title-upgrade-native-a3a4-prepare)
        )
        ((= (strcase answer) "BATCH")
          (swcad-title-princ-line "A2/A3/A4 BATCH 모드로 전환합니다. 실패하거나 선택값이 맞지 않으면 기존 쌍을 보존하고 중단합니다.")
          (swcad-title-upgrade-native-a3a4-batch-manual)
        )
        (T
        (progn
          (swcad-title-open-native-upgrade-log)
      (swcad-title-princ-line "----- SWTITLECONVERT A2/A3/A4 한 장 native 교체 사전 확인 -----")
          (swcad-title-print-loaded-version)
          (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
          (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
          (swcad-title-print-work-copy-status)
          (swcad-title-princ-line
            (strcat
              "Prepared next target: sheet="
              (if sheet sheet "<unknown>")
              ", title="
              (swcad-title-ename-handle (car pair))
              ", frame="
              (swcad-title-ename-handle (cadr pair))
              ", block="
              frame-block
              ", reason="
              reason
            )
          )
          (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_USER")
          (swcad-title-princ-line "OPEN, MANUAL, BATCH를 입력하지 않아 GMTITLE 창을 열지 않았습니다.")
          (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
          (swcad-title-close-log)
        )
        )
      )
    )
    (progn
      (swcad-title-open-native-upgrade-log)
      (swcad-title-princ-line "----- SWTITLECONVERT A2/A3/A4 한 장 native 교체 -----")
      (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
      (swcad-title-print-work-copy-status)
      (swcad-title-apply-result "STOP_NO_NATIVE_GMTITLE_UPGRADE_CANDIDATE")
      (swcad-title-princ-line "No A2/A3/A4 target pair currently needs native replacement.")
      (swcad-title-princ-line "다음: SWTITLEVERIFY를 실행한 뒤 수동 더블클릭 확인을 하세요.")
      (swcad-title-princ-line "No drawing data was changed.")
      (swcad-title-close-log)
    )
  )
  (princ)
)

(defun swcad-title-upgrade-native-batch (/ *error* records total count index result old-batch-mode remaining)
  (defun *error* (msg)
    (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
    (if msg
      (swcad-title-princ-line (strcat "Internal native upgrade batch error: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_NATIVE_UPGRADE_BATCH")
    (swcad-title-close-log)
    (princ)
  )
  (setq old-batch-mode *swcad-title-native-upgrade-batch-mode*)
  (swcad-title-open-native-upgrade-log)
  (setq records (swcad-title-cloned-gmtitle-pair-records))
  (setq total (length records))
  (swcad-title-princ-line "----- internal clone-to-native frame upgrade batch -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-print-native-upgrade-summary)
  (cond
    ((= total 0)
      (swcad-title-apply-result "STOP_NO_CLONED_GMTITLE_PAIR")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before upgrading.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Batch native upgrade is limited to Documents/CAD tool/work copies.")
      (swcad-title-princ-line "native 교체 전에는 work 폴더의 작업복사본을 여세요.")
    )
    (T
      (setq count
        (getint
          (strcat
            "\nNumber of cloned GMTITLE pairs to upgrade with real native GMTITLE <"
            (itoa total)
            ">: "
          )
        )
      )
      (if (not count)
        (setq count total)
      )
      (if (> count total)
        (setq count total)
      )
      (if (<= count 0)
        (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_BATCH_USER")
        (progn
          (setq *swcad-title-native-upgrade-batch-mode* T)
          (setq index 1)
          (while (<= index count)
            (if (= (swcad-title-cloned-gmtitle-pair-total) 0)
              (setq index (+ count 1))
              (progn
                (swcad-title-princ-line
                  (strcat
                    "--- internal native upgrade batch sheet "
                    (itoa index)
                    " / "
                    (itoa count)
                    " ---"
                  )
                )
                (setq result (vl-catch-all-apply 'swcad-title-upgrade-native-one nil))
                (if (vl-catch-all-error-p result)
                  (progn
                    (setq *swcad-title-last-apply-status* "ERROR_NATIVE_UPGRADE_BATCH_APPLY")
                    (swcad-title-princ-line
                      (strcat
                        "Native upgrade batch apply error: "
                        (vl-catch-all-error-message result)
                      )
                    )
                    (setq index (+ count 1))
                  )
                )
                (if (/= *swcad-title-last-apply-status* "UPGRADED_CLONE_TO_NATIVE_GMTITLE")
                  (progn
                    (swcad-title-princ-line
                      (strcat
                        "Native upgrade batch stopped after status: "
                        (swcad-title-string *swcad-title-last-apply-status*)
                      )
                    )
                    (setq index (+ count 1))
                  )
                )
              )
            )
            (setq index (+ index 1))
          )
          (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
          (setq remaining (swcad-title-cloned-gmtitle-pair-total))
          (swcad-title-princ-line (strcat "Remaining cloned GMTITLE pairs after batch: " (itoa remaining)))
          (if (= remaining 0)
            (swcad-title-apply-result "OK_NATIVE_UPGRADE_BATCH_COMPLETE")
            (if (equal *swcad-title-last-apply-status* "UPGRADED_CLONE_TO_NATIVE_GMTITLE")
              (swcad-title-apply-result "WARN_NATIVE_UPGRADE_BATCH_REMAINING_CLONES")
            )
          )
          (swcad-title-princ-line "다음: SWTITLEVERIFY를 실행한 뒤 변환된 대표 용지의 DR_titlea_3rd 제목블록을 수동으로 더블클릭하세요.")
        )
      )
    )
  )
  (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-upgrade-native-a3a4-batch (/ *error* records total count default-count index result old-batch-mode old-allow-interactive remaining summary source-count frame-only-count missing-required command-text-count)
  (defun *error* (msg)
    (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
    (setq *swcad-title-allow-batch-interactive-native-gmtitle* old-allow-interactive)
    (setq *swcad-title-native-upgrade-selected-pair* nil)
    (if msg
      (swcad-title-princ-line (strcat "SWTITLECONVERT A2/A3/A4 일괄 교체 오류: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_NATIVE_GMTITLE_UPGRADE_BATCH")
    (swcad-title-close-log)
    (princ)
  )
  (setq old-batch-mode *swcad-title-native-upgrade-batch-mode*)
  (setq old-allow-interactive *swcad-title-allow-batch-interactive-native-gmtitle*)
  (swcad-title-open-native-upgrade-log)
  (setq records (swcad-title-a3a4-native-upgrade-candidate-records))
  (setq total (length records))
  (setq command-text-count (swcad-title-command-text-residue-count))
  (swcad-title-princ-line "----- SWTITLECONVERT 내부 A2/A3/A4 native 교체 일괄 단계 -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-print-a3a4-native-upgrade-candidates)
  (swcad-title-princ-line (strcat "Possible accidental command text entities: " (itoa command-text-count)))
  (cond
    ((= total 0)
      (swcad-title-apply-result "STOP_NO_NATIVE_GMTITLE_UPGRADE_CANDIDATE")
      (setq summary (swcad-title-fast-sheet-summary))
      (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
      (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
      (if (or (> source-count 0) (> frame-only-count 0))
        (progn
          (swcad-title-princ-line "Reason: no converted A2/A3/A4 GMTITLE target pair exists yet; source sheets still remain.")
          (swcad-title-print-fast-sheet-summary summary)
          (setq missing-required (swcad-title-missing-required-native-frame-blocks summary))
          (if missing-required
            (progn
              (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행해서 누락된 각 용지 크기의 첫 실제 native GMTITLE을 만드세요.")
              (swcad-title-print-missing-native-exemplar-actions summary missing-required)
            )
            (progn
              (swcad-title-princ-line "다음: SWTITLECONVERTNEXT로 A2/A3/A4 대상 쌍을 만든 뒤, native 교체 후보가 남으면 SWTITLECONVERTNEXT를 다시 실행하세요.")
            )
          )
        )
        (swcad-title-princ-line "No A2/A3/A4 target pairs need native replacement.")
      )
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before upgrading.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "A2/A3/A4 batch native upgrade is limited to Documents/CAD tool/work copies.")
      (swcad-title-princ-line "SWTITLECONVERTNEXT 실행 전에는 work 폴더의 작업복사본을 여세요.")
    )
    ((swcad-title-script-active-p)
      (swcad-title-apply-result "ABORT_NATIVE_GMTITLE_BATCH_SCRIPT_ACTIVE")
      (swcad-title-princ-line "A2/A3/A4 native 교체 단계는 SCRIPT 파일에서 실행하지 마세요.")
      (swcad-title-princ-line "이유: 각 후보가 대화식 GMTITLE 창을 필요로 할 수 있는데, SCRIPT 모드에서는 이 대화식 흐름이 막힐 수 있습니다.")
      (swcad-title-princ-line "먼저 상태 SCRIPT를 실행한 뒤 CAD 명령줄에 SWTITLECONVERTNEXT를 직접 입력하세요.")
      (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
    )
    ((> command-text-count 0)
      (swcad-title-apply-result "ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST")
      (swcad-title-princ-line "도면 안에 명령어 텍스트 후보가 있습니다.")
      (swcad-title-princ-line "A2/A3/A4 교체 전에 SWTITLESTATUS로 표시된 TEXT/MTEXT 후보를 확인하세요.")
      (swcad-title-princ-line "작업복사본 안의 실수 명령어 잔여물이 맞다면 SWTITLEPREPARE에서 먼저 정리한 뒤 SWTITLECONVERTNEXT를 다시 실행하세요.")
      (swcad-title-princ-line "변경된 A2/A3/A4 쌍은 없습니다.")
    )
    (T
      (setq default-count total)
      (swcad-title-princ-line
        (strcat
          "현재 표시된 A2/A3/A4 native 교체 후보: "
          (itoa total)
        )
      )
      (setq summary (swcad-title-fast-sheet-summary))
      (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
      (if (> frame-only-count 0)
        (progn
          (swcad-title-princ-line
            (strcat
              "참고: "
              (itoa frame-only-count)
              "개의 frame-only 원본 시트가 아직 남아 있습니다. 이 일괄 단계에서는 새로 만들지 않습니다."
            )
          )
          (swcad-title-princ-line "이 native 인식 교체가 끝난 뒤 해당 항목은 SWTITLECONVERTNEXT로 처리하세요.")
        )
      )
      (swcad-title-princ-line "기본 수량은 현재 표시된 모든 후보입니다. Enter를 누르면 표시된 A2/A3/A4 후보를 모두 처리합니다.")
      (swcad-title-princ-line "이 A2/A3/A4 native 교체 단계는 SWTITLECONVERTNEXT/SWTITLECONVERT 내부에서 실행됩니다.")
      (swcad-title-princ-line "일반 사용에서는 계속 SWTITLECONVERTNEXT를 사용하세요. 한 장 복구용 명령은 진단용입니다.")
      (if *swcad-title-a3a4-batch-default-all*
        (progn
          (setq count default-count)
          (swcad-title-princ-line
            (strcat
              "전체 후보 모드: 현재 표시된 A2/A3/A4 후보를 모두 처리합니다. 수량="
              (itoa count)
            )
          )
        )
        (setq count
          (getint
            (strcat
              "\n실제 native GMTITLE로 교체할 A2/A3/A4 대상 쌍 수 <"
              (itoa default-count)
              "> (현재 표시된 전체를 처리하려면 "
              (itoa total)
              " 입력, 일부만 처리하려면 더 작은 숫자 입력): "
            )
          )
        )
      )
      (if (not count)
        (setq count default-count)
      )
      (if (> count total)
        (setq count total)
      )
      (if (<= count 0)
        (swcad-title-apply-result "ABORT_NATIVE_GMTITLE_UPGRADE_BATCH_USER")
        (progn
          (setq *swcad-title-allow-batch-interactive-native-gmtitle* T)
          (swcad-title-princ-line "A2/A3/A4 일괄 단계의 대화식 GMTITLE fallback이 켜졌습니다.")
          (swcad-title-princ-line "남은 각 후보에서 native GMTITLE 창이 열릴 수 있습니다.")
          (swcad-title-princ-line "각 창에서 출력된 DR 용지와 DR_titlea_3rd를 선택하고, Frame positioning은 ON, Object move는 OFF로 두세요.")
          (swcad-title-princ-line "If the dialog still shows ISO paper/title values, cancel it. Confirming ISO values will not fix GMPOWEREDIT behavior.")
          (setq *swcad-title-native-upgrade-batch-mode* T)
          (setq index 1)
          (while (<= index count)
            (setq records (swcad-title-a3a4-native-upgrade-candidate-records))
            (if (not records)
              (setq index (+ count 1))
              (progn
                (swcad-title-princ-line
                  (strcat
                    "--- SWTITLECONVERT A2/A3/A4 시트 "
                    (itoa index)
                    " / "
                    (itoa count)
                    " ---"
                  )
                )
                (setq *swcad-title-native-upgrade-selected-pair* (car records))
                (setq result (vl-catch-all-apply 'swcad-title-upgrade-native-one nil))
                (if (vl-catch-all-error-p result)
                  (progn
                    (setq *swcad-title-last-apply-status* "ERROR_NATIVE_GMTITLE_UPGRADE_BATCH_APPLY")
                    (swcad-title-princ-line
                      (strcat
                        "A2/A3/A4 native upgrade batch apply error: "
                        (vl-catch-all-error-message result)
                      )
                    )
                    (setq index (+ count 1))
                  )
                )
                (if (/= *swcad-title-last-apply-status* "UPGRADED_CLONE_TO_NATIVE_GMTITLE")
                  (progn
                    (swcad-title-princ-line
                      (strcat
                        "A2/A3/A4 native upgrade batch stopped after status: "
                        (swcad-title-string *swcad-title-last-apply-status*)
                      )
                    )
                    (swcad-title-princ-line "Remaining candidates after the stopped sheet:")
                    (swcad-title-print-a3a4-native-upgrade-candidates)
                    (setq index (+ count 1))
                  )
                )
              )
            )
            (setq index (+ index 1))
          )
          (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
          (setq remaining (length (swcad-title-a3a4-native-upgrade-candidate-records)))
          (swcad-title-princ-line (strcat "Remaining A2/A3/A4 native upgrade candidates after batch: " (itoa remaining)))
          (if (= remaining 0)
            (swcad-title-apply-result "OK_NATIVE_GMTITLE_UPGRADE_BATCH_COMPLETE")
            (if (equal *swcad-title-last-apply-status* "UPGRADED_CLONE_TO_NATIVE_GMTITLE")
              (swcad-title-apply-result "WARN_NATIVE_GMTITLE_UPGRADE_BATCH_REMAINING")
            )
          )
          (cond
            ((equal *swcad-title-last-native-gmtitle-abort-reason* "INTERACTIVE_GMTITLE_SKIPPED_IN_BATCH")
              (swcad-title-princ-line "다음: GMTITLE 창이 ISO 기본값으로 열려 batch를 안전하게 계속할 수 없습니다.")
              (swcad-title-princ-line "권장: SWTITLECONVERTNEXT를 다시 실행하고 한 장씩 확인하세요.")
              (swcad-title-princ-line "GMTITLE 창마다 요청된 DR 용지와 DR_titlea_3rd를 선택하세요.")
              (swcad-title-princ-line "title-missing/frame-only 예외 시트도 이후 SWTITLESTATUS로 상태를 확인하고 SWTITLECONVERTNEXT로 진행하세요.")
            )
            (T
              (swcad-title-princ-line "다음: SWTITLEVERIFY를 실행한 뒤 실제 DR_titlea_3rd 제목블록이 있는 대표 용지만 수동으로 더블클릭하세요.")
            )
          )
        )
      )
    )
  )
  (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
  (setq *swcad-title-allow-batch-interactive-native-gmtitle* old-allow-interactive)
  (setq *swcad-title-native-upgrade-selected-pair* nil)
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-upgrade-native-a3a4-batch-manual (/ old-allow result)
  (setq old-allow *swcad-title-allow-batch-interactive-native-gmtitle*)
  (setq *swcad-title-allow-batch-interactive-native-gmtitle* T)
  (setq result (vl-catch-all-apply 'swcad-title-upgrade-native-a3a4-batch nil))
  (setq *swcad-title-allow-batch-interactive-native-gmtitle* old-allow)
  (if (vl-catch-all-error-p result)
    (progn
      (swcad-title-princ-line
        (strcat
          "SWTITLECONVERT A2/A3/A4 대화식 교체 오류: "
          (vl-catch-all-error-message result)
        )
      )
      (princ)
    )
  )
  (princ)
)

(defun swcad-title-upgrade-native-a3a4-all (/ old-default-all result)
  (setq old-default-all *swcad-title-a3a4-batch-default-all*)
  (setq *swcad-title-a3a4-batch-default-all* T)
  (setq result (vl-catch-all-apply 'swcad-title-upgrade-native-a3a4-batch nil))
  (setq *swcad-title-a3a4-batch-default-all* old-default-all)
  (if (vl-catch-all-error-p result)
    (progn
      (swcad-title-princ-line
        (strcat
          "SWTITLECONVERT A2/A3/A4 교체 오류: "
          (vl-catch-all-error-message result)
        )
      )
      (princ)
    )
  )
  (princ)
)

(defun swcad-title-integrated-command-header (name description)
  (swcad-title-princ-text
    (strcat
      "\n===== "
      name
      " "
      description
      " ====="
    )
  )
  (swcad-title-print-loaded-version)
  (swcad-title-print-log-evidence-note)
  (swcad-title-print-current-dwg-save-status)
  (swcad-title-princ-text
    "\nSolidWorks DWG를 GMTITLE 구조로 바꾸는 4단계 통합 흐름입니다."
  )
)

(defun swcad-title-integrated-structure-diagnosis (/ summary source-count source-frame-count frame-only-count command-text-count embedded-records embedded-count a3-embedded-count a4-embedded-count style-records style-count a3-style-count a4-style-count frame-definition-records frame-definition-blockers definition-raw-risk-records definition-raw-risk-count a4-definition-raw-risk-count frame-records raw-records raw-count a4-raw-count geometry-count overlap-count duplicate-pair-records duplicate-pair-count invalid-title-missing-count contaminated required-sheets target-sheet-counts stored-expected-sheet-counts expected-sheet-counts count-shortage-records count-excess-records missing-required required-sheet a3a4-count record sheet next-action)
  (swcad-title-open-structure-diagnosis-log)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq source-frame-count (swcad-title-fast-summary-value summary "source-frame-count"))
  (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
  (setq command-text-count (swcad-title-command-text-residue-count))
  (setq embedded-records (swcad-title-frame-embedded-title-records))
  (setq embedded-count (length embedded-records))
  (setq a3-embedded-count 0)
  (setq a4-embedded-count 0)
  (foreach record embedded-records
    (setq sheet (swcad-title-normalized-sheet-size (car record)))
    (cond
      ((equal sheet "A3") (setq a3-embedded-count (+ a3-embedded-count 1)))
      ((equal sheet "A4") (setq a4-embedded-count (+ a4-embedded-count 1)))
    )
  )
  (setq style-records (swcad-title-frame-style-normalization-records))
  (setq style-count (length style-records))
  (setq a3-style-count 0)
  (setq a4-style-count 0)
  (foreach record style-records
    (setq sheet (swcad-title-normalized-sheet-size (car record)))
    (cond
      ((equal sheet "A3") (setq a3-style-count (+ a3-style-count 1)))
      ((equal sheet "A4") (setq a4-style-count (+ a4-style-count 1)))
    )
  )
  (setq frame-definition-records (swcad-title-frame-definition-class-records))
  (setq frame-definition-blockers (swcad-title-frame-definition-blocking-records))
  (setq definition-raw-risk-records (swcad-title-frame-definition-raw-bbox-risk-records))
  (setq definition-raw-risk-count (length definition-raw-risk-records))
  (setq a4-definition-raw-risk-count 0)
  (foreach record definition-raw-risk-records
    (if (equal (swcad-title-normalized-sheet-size (car record)) "A4")
      (setq a4-definition-raw-risk-count (+ a4-definition-raw-risk-count 1))
    )
  )
  (setq frame-records (swcad-title-frame-records))
  (setq raw-records (swcad-title-target-frame-raw-selection-warning-records frame-records))
  (setq raw-count (length raw-records))
  (setq a4-raw-count 0)
  (foreach record raw-records
    (if (equal (swcad-title-normalized-sheet-size (nth 3 record)) "A4")
      (setq a4-raw-count (+ a4-raw-count 1))
    )
  )
  (setq geometry-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq duplicate-pair-records (swcad-title-duplicate-target-pair-records))
  (setq duplicate-pair-count (length duplicate-pair-records))
  (setq invalid-title-missing-count (length (swcad-title-title-missing-outline-with-loose-title-records)))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq required-sheets (swcad-title-active-required-sheets summary))
  (setq target-sheet-counts (swcad-title-target-frame-sheet-counts))
  (setq stored-expected-sheet-counts (swcad-title-stored-expected-sheet-counts))
  (setq expected-sheet-counts
    (if stored-expected-sheet-counts
      stored-expected-sheet-counts
      (swcad-title-current-total-sheet-counts summary)
    )
  )
  (setq count-shortage-records (swcad-title-count-shortage-records expected-sheet-counts target-sheet-counts))
  (setq count-excess-records (swcad-title-count-excess-records expected-sheet-counts target-sheet-counts))
  (setq missing-required nil)
  (foreach required-sheet required-sheets
    (if (= (swcad-title-count-value required-sheet target-sheet-counts) 0)
      (setq missing-required (append missing-required (list required-sheet)))
    )
  )
  (setq a3a4-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
  (setq next-action
    (cond
      ((> command-text-count 0) "SWTITLEPREPARE - 실수 명령어 텍스트 잔여물을 먼저 확인/정리해야 합니다.")
      ((> style-count 0) "SWTITLEPREPARE - 도면틀 스타일 정규화가 먼저 필요합니다.")
      ((> embedded-count 0) "SWTITLEPREPARE - 도면틀 정의 안의 표제란 형상을 먼저 정리")
      (frame-definition-blockers "SWTITLEPREPARE - 도면틀 정의 유형이 변환 전 정규화를 요구합니다.")
      ((> definition-raw-risk-count 0) "SWTITLEPREPARE 또는 정의 복구 - 도면틀 정의 raw bbox 위험 먼저 확인")
      ((> duplicate-pair-count 0) "SWTITLEPREPARE - 같은 위치에 겹친 GMTITLE target 쌍을 먼저 정리")
      ((or (> raw-count 0) (> geometry-count 0) (> overlap-count 0)) "SWTITLEPREPARE 또는 구조 점검 - 도면틀 선택 범위/크기/겹침 위험 먼저 확인")
      (contaminated "SWTITLEPREPARE - 오염 의심 대상 도면틀 정의 정규화")
      ((> invalid-title-missing-count 0) "SWTITLEVERIFY - 제목 정보가 있는데 DR_titlea_3rd가 없는 시트 확인")
      ((> a3a4-count 0) "SWTITLECONVERTNEXT - A2/A3/A4 native 교체 후보를 먼저 한 장 처리")
      ((and (= source-count 0) (> frame-only-count 0) (swcad-title-title-missing-outline-definition-needed-p)) "SWTITLEPREPARE - 같은 크기 DR_A*_Outline 정의를 먼저 가져오고 형상/선택범위 검증")
      ((and (= source-count 0) (> frame-only-count 0) (swcad-title-title-missing-outline-policy-blocked-p)) "SWTITLECONVERTNEXT - 원본 표제란 부재가 검증된 시트의 도면틀만 교체")
      ((or (> source-count 0) (> frame-only-count 0)) "SWTITLECONVERTNEXT - 남은 원본 SolidWorks 시트 변환")
      (missing-required "SWTITLECONVERTNEXT - 누락된 대상 용지 크기의 native GMTITLE 생성")
      ((and (= source-frame-count 0) count-shortage-records) "SWTITLEVERIFY - 변환 기준 수량 대비 누락된 대상 도면틀 확인")
      (T "SWTITLEVERIFY - 최종 검증")
    )
  )
  (swcad-title-princ-line "----- SWTITLESTATUS 구조 판단 요약 -----")
  (swcad-title-princ-line (strcat "원본 표제란/도면틀: " (itoa source-count) " / " (itoa source-frame-count)))
  (swcad-title-princ-line (strcat "표제란 없는 도면틀 시트: " (itoa frame-only-count)))
  (if (> frame-only-count 0)
    (swcad-title-princ-line "title-missing/frame-only 기준: A2/A3/A4 중 어떤 용지든 원본 표제란 부재가 검증된 경우에만 예외로 처리합니다.")
  )
  (swcad-title-princ-line (strcat "실수 명령어 텍스트 후보: " (itoa command-text-count)))
  (swcad-title-princ-line
    (strcat
      "도면틀 정의 내부 표제란 형상 후보: 전체="
      (itoa embedded-count)
      ", A3="
      (itoa a3-embedded-count)
      ", A4="
      (itoa a4-embedded-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "도면틀 스타일 정규화 후보: 전체="
      (itoa style-count)
      ", A3="
      (itoa a3-style-count)
      ", A4="
      (itoa a4-style-count)
    )
  )
  (swcad-title-print-frame-definition-class-records frame-definition-records)
  (swcad-title-print-frame-definition-raw-bbox-risk-records definition-raw-risk-records)
  (swcad-title-print-frame-style-normalization-records style-records)
  (swcad-title-princ-line (strcat "겹친 GMTITLE target 쌍 후보 수: " (itoa duplicate-pair-count)))
  (swcad-title-princ-line (strcat "제목 MTEXT가 남은 잘못된 title-missing 대상: " (itoa invalid-title-missing-count)))
  (swcad-title-print-duplicate-target-pair-records duplicate-pair-records)
  (swcad-title-princ-line
    (strcat
      "도면틀 선택/형상 위험: 실제선택bbox="
      (itoa raw-count)
      ", A4실제선택bbox="
      (itoa a4-raw-count)
      ", 정의rawbbox="
      (itoa definition-raw-risk-count)
      ", A4정의rawbbox="
      (itoa a4-definition-raw-risk-count)
      ", 크기경고="
      (itoa geometry-count)
      ", 겹침경고="
      (itoa overlap-count)
    )
  )
  (swcad-title-print-counts "변환 기준 전체 용지 수:" expected-sheet-counts)
  (swcad-title-princ-line
    (strcat
      "변환 기준 수량 출처: "
      (if stored-expected-sheet-counts
        "도면 xdata 기록"
        "현재 원본+대상 상태 추정"
      )
    )
  )
  (swcad-title-print-counts "용지별 대상 도면틀 수:" target-sheet-counts)
  (swcad-title-print-count-deltas "대상 도면틀 수량 부족:" count-shortage-records)
  (swcad-title-print-count-deltas "대상 도면틀 수량 초과:" count-excess-records)
  (swcad-title-princ-line (strcat "오염 의심 대상 도면틀 정의: " (swcad-title-list-string contaminated)))
  (swcad-title-princ-line (strcat "현재 필요한 대상 용지 누락: " (swcad-title-list-string missing-required)))
  (swcad-title-princ-line (strcat "A2/A3/A4 native 교체 후보: " (itoa a3a4-count)))
  (if (or
        (> (swcad-title-count-value "A2" target-sheet-counts) 0)
        (> (swcad-title-count-value "A3" target-sheet-counts) 0)
        (> (swcad-title-count-value "A4" target-sheet-counts) 0)
      )
    (progn
      (swcad-title-princ-line "DR 도면틀 참고: native GMTITLE에서도 도면틀은 INSERT/block 참조로 선택될 수 있습니다.")
      (swcad-title-princ-line "완료 판단은 도면틀 더블클릭이 아니라 DR_titlea_3rd 제목블록 더블클릭과 native 교체 후보 0개로 확인하세요.")
    )
  )
  (cond
    ((> style-count 0)
      (swcad-title-princ-line "도면틀 판단: 도면틀 안 native 표제란 형상이 별도 DR_titlea_3rd와 겹칩니다. 변환 반복보다 SWTITLEPREPARE가 먼저입니다.")
    )
    ((> embedded-count 0)
      (swcad-title-princ-line "도면틀 판단: 도면틀 안에 표제란 형상 후보가 있어 변환 반복보다 SWTITLEPREPARE가 먼저입니다.")
    )
    ((> a3a4-count 0)
      (swcad-title-princ-line "native 판단: native 교체 후보가 남아 있습니다. title-missing/frame-only 예외보다 이 후보를 먼저 한 장씩 처리합니다.")
      (swcad-title-princ-line "native 판단 보충: 도면틀이 block처럼 보이는 현상 자체보다 clone/shared-native-link 후보가 남았는지가 실제 문제입니다.")
    )
    ((or
       (> (swcad-title-count-value "A2" target-sheet-counts) 0)
       (> (swcad-title-count-value "A3" target-sheet-counts) 0)
       (> (swcad-title-count-value "A4" target-sheet-counts) 0)
     )
      (swcad-title-princ-line "native 판단: 대상 도면틀은 존재합니다. 최종 성공은 DR_titlea_3rd 더블클릭 표 편집창으로 확인하세요.")
    )
  )
  (cond
    ((> definition-raw-risk-count 0)
      (swcad-title-princ-line "도면틀 판단: 대상 DR 도면틀 정의 자체의 raw bbox가 실제 용지보다 큽니다. 정의 복구/정규화 전에는 기존 원본 도면틀을 삭제하지 않습니다.")
    )
    ((> raw-count 0)
      (swcad-title-princ-line "도면틀 판단: 실제 선택 bbox가 보이는 용지보다 큽니다. bbox 검사를 통과하기 전에는 기존 원본 도면틀을 삭제하지 않습니다.")
    )
    ((and (> frame-only-count 0) (swcad-title-title-missing-outline-definition-needed-p))
      (swcad-title-princ-line "title-missing 판단: 표제란 없는 도면틀은 남아 있지만, 같은 크기 DR 도면틀 정의가 아직 변환 기준을 통과하지 못했습니다.")
      (swcad-title-print-title-missing-outline-definition-status)
      (if (> source-count 0)
        (progn
          (swcad-title-princ-line "title-missing 판단 보충: 아직 원본 표제란 시트가 남아 있어 예외 준비보다 원본 시트 변환이 먼저입니다.")
          (swcad-title-princ-line "현재 권장 다음 명령은 아래의 권장 다음 명령 줄을 따르세요. 도면틀 정의 준비는 원본 시트 변환 뒤에 다시 안내됩니다.")
        )
        (swcad-title-princ-line "다음: SWTITLEPREPARE로 같은 크기 DR 도면틀 정의를 먼저 준비/검증하세요.")
      )
    )
    ((and (> frame-only-count 0) (swcad-title-title-missing-outline-policy-blocked-p))
      (swcad-title-princ-line "title-missing 판단: 표제란 없는 도면틀 시트가 남아 있습니다. 원본에 없던 제목블록은 만들지 않고 도면틀만 교체합니다.")
      (if (> a3a4-count 0)
        (swcad-title-princ-line "다만 A2/A3/A4 native 교체 후보가 남아 있으므로, SWTITLECONVERTNEXT는 그 후보를 먼저 처리합니다.")
        (progn
          (swcad-title-princ-line "다음: SWTITLECONVERTNEXT를 실행하세요.")
          (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
        )
      )
    )
    ((> frame-only-count 0)
      (swcad-title-princ-line "title-missing 판단: 표제란 없는 도면틀 시트가 남아 있습니다. SWTITLECONVERTNEXT가 표제란 없는 도면틀 흐름으로 처리합니다.")
    )
  )
  (swcad-title-print-automation-policy-summary)
  (swcad-title-princ-line (strcat "권장 다음 명령: " next-action))
  (swcad-title-close-log)
  next-action
)

(defun swcad-title-integrated-status (/ cache-owned)
  (setq cache-owned (not *swcad-title-frame-style-analysis-cache-enabled*))
  (if cache-owned
    (swcad-title-frame-style-analysis-cache-begin)
  )
  (swcad-title-integrated-command-header "SWTITLESTATUS" "상태 진단")
  (swcad-title-princ-text "\n읽기 전용으로 현재 도면 상태, 도면틀 정의, native GMTITLE 준비 상태를 확인합니다.")
  (swcad-title-fast-status)
  (swcad-title-frame-def-check)
  (swcad-title-print-frame-embedded-title-records (swcad-title-frame-embedded-title-records))
  (swcad-title-native-frame-completion-check)
  (swcad-title-integrated-structure-diagnosis)
  (swcad-title-next-step)
  (if cache-owned
    (swcad-title-frame-style-analysis-cache-end)
  )
  (swcad-title-princ-text "\nSWTITLESTATUS 완료: 위 결과에서 다음 명령이 SWTITLEPREPARE인지 SWTITLECONVERTNEXT인지 확인하세요.")
  (princ)
)

(defun swcad-title-integrated-prepare (/ summary source-count frame-only-count command-text-records frame-title-records embedded-title-records style-records style-cache-owned frame-definition-blockers contaminated-definition-records definition-raw-risk-records blocking-cleanup-seen title-missing-outline-needed orphan-records duplicate-pair-records)
  (swcad-title-integrated-command-header "SWTITLEPREPARE" "도면틀/블록 정의 정규화")
  (if (swcad-title-script-active-p)
    (progn
      (swcad-title-apply-result "ABORT_PREPARE_SCRIPT_ACTIVE")
      (swcad-title-princ-text "\nSCRIPT/자동화 실행 중에는 YES 확인이 필요한 정리 작업을 진행하지 않습니다.")
      (swcad-title-princ-text "\n먼저 SWTITLESTATUS로 상태만 확인한 뒤, CAD 명령줄에서 SWTITLEPREPARE를 직접 입력하세요.")
      (swcad-title-princ-text "\n도면 데이터는 변경하지 않았습니다.")
    )
    (if (swcad-title-active-dwg-confirmed-p)
      (progn
      (swcad-title-princ-text "\n작업복사본에서만 정리 명령을 실행합니다. 각 정리 단계는 후보를 보여주고 YES 확인을 받습니다.")
      (setq summary (swcad-title-fast-sheet-summary))
      (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
      (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
      (swcad-title-frame-def-check)
      (setq command-text-records (swcad-title-command-text-residue-records))
      (setq frame-title-records (swcad-title-frame-def-title-child-records))
      (setq embedded-title-records (swcad-title-frame-embedded-title-records))
      (setq style-records (swcad-title-frame-style-normalization-records))
      (setq frame-definition-blockers (swcad-title-frame-definition-blocking-records))
      (setq contaminated-definition-records (swcad-title-frame-definition-blocking-records-by-class "source-contaminated"))
      (setq definition-raw-risk-records (swcad-title-frame-definition-raw-bbox-risk-records))
      (setq title-missing-outline-needed
        (and
          (= source-count 0)
          (> frame-only-count 0)
          (swcad-title-title-missing-outline-definition-needed-p)
        )
      )
      (setq orphan-records (swcad-title-orphan-target-frame-records))
      (setq duplicate-pair-records (swcad-title-duplicate-target-pair-records))
      (setq blocking-cleanup-seen
        (or
          command-text-records
          frame-title-records
          embedded-title-records
          style-records
          frame-definition-blockers
          contaminated-definition-records
          definition-raw-risk-records
          orphan-records
          duplicate-pair-records
        )
      )
      (swcad-title-princ-text
        (strcat
          "\n정규화 후보 요약:"
          "\n  남은 원본 표제란 시트: "
          (itoa source-count)
          "\n  표제란 없는 도면틀 시트: "
          (itoa frame-only-count)
          "\n  실수 명령어 텍스트 잔여물: "
          (itoa (length command-text-records))
          "\n  도면틀 정의 안 중첩 제목블록: "
          (itoa (length frame-title-records))
          "\n  DR 도면틀 내부 표제란 형상: "
          (itoa (length embedded-title-records))
          "\n  도면틀 스타일 정규화 필요 후보: "
          (itoa (length style-records))
          "\n  변환 차단 도면틀 정의: "
          (itoa (length frame-definition-blockers))
          "\n  원본 블록이 섞인 도면틀 정의: "
          (itoa (length contaminated-definition-records))
          "\n  DR 도면틀 정의 raw bbox 위험: "
          (itoa (length definition-raw-risk-records))
          "\n  title-missing/frame-only DR 도면틀 정의 준비 필요: "
          (if title-missing-outline-needed "예" "아니오")
          "\n  제목블록 없는 고아 GMTITLE 도면틀: "
          (itoa (length orphan-records))
          "\n  같은 위치에 겹친 GMTITLE target 쌍: "
          (itoa (length duplicate-pair-records))
        )
      )
      (if command-text-records
        (swcad-title-command-text-clean-safe)
        (swcad-title-princ-text "\n실수 명령어 텍스트 정리: 후보 없음")
      )
      (if frame-title-records
        (swcad-title-clean-frame-def-title-children)
        (swcad-title-princ-text "\n도면틀 정의 안 중첩 제목블록 정리: 후보 없음")
      )
      (if embedded-title-records
        (swcad-title-frame-embedded-title-clean)
        (swcad-title-princ-text "\nDR 도면틀 내부 표제란 형상 정리: 후보 없음")
      )
      (if style-records
        (progn
          (setq style-cache-owned (not *swcad-title-frame-style-analysis-cache-enabled*))
          (if style-cache-owned
            (swcad-title-frame-style-analysis-cache-begin)
          )
          (swcad-title-frame-style-analysis-cache-seed style-records)
          (swcad-title-frame-style-normalization-clean)
          (if style-cache-owned
            (swcad-title-frame-style-analysis-cache-end)
          )
        )
        (swcad-title-princ-text "\n도면틀 스타일 정규화: 후보 없음")
      )
      (setq contaminated-definition-records (swcad-title-frame-definition-blocking-records-by-class "source-contaminated"))
      (setq definition-raw-risk-records (swcad-title-frame-definition-raw-bbox-risk-records))
      (if (or contaminated-definition-records definition-raw-risk-records)
        (swcad-title-frame-def-clean-safe)
        (swcad-title-princ-text "\n오염된 DR 도면틀 정의 복구: 후보 없음")
      )
      (setq orphan-records (swcad-title-orphan-target-frame-records))
      (setq duplicate-pair-records (swcad-title-duplicate-target-pair-records))
      (if orphan-records
        (swcad-title-clean-orphan-target-frames)
        (swcad-title-princ-text "\n고아 GMTITLE 도면틀 정리: 후보 없음")
      )
      (if duplicate-pair-records
        (swcad-title-clean-duplicate-target-pairs)
        (swcad-title-princ-text "\n겹친 GMTITLE target 쌍 정리: 후보 없음")
      )
      (setq blocking-cleanup-seen
        (or
          blocking-cleanup-seen
          contaminated-definition-records
          definition-raw-risk-records
          orphan-records
          duplicate-pair-records
        )
      )
      (setq title-missing-outline-needed
        (and
          (= source-count 0)
          (> frame-only-count 0)
          (swcad-title-title-missing-outline-definition-needed-p)
        )
      )
      (cond
        (blocking-cleanup-seen
          (swcad-title-princ-text "\ntitle-missing/frame-only DR 도면틀 정의 준비: 이번 실행에서는 건너뜀")
          (swcad-title-princ-text "\n이유: SWTITLEPREPARE는 정리/차단 후보 처리 후 다음 단계로 건너뛰지 않습니다. SWTITLESTATUS로 상태를 다시 확인하세요.")
        )
        (title-missing-outline-needed
          (swcad-title-prepare-title-missing-outline-definition)
        )
        (T
          (swcad-title-princ-text "\ntitle-missing/frame-only DR 도면틀 정의 준비: 후보 없음")
        )
      )
      (swcad-title-frame-def-check)
      (swcad-title-native-frame-completion-check)
      (swcad-title-princ-text "\nSWTITLEPREPARE 완료: 경고가 줄었는지 확인한 뒤 SWTITLESTATUS 또는 SWTITLECONVERTNEXT를 실행하세요.")
      )
      (swcad-title-abort-multiple-open-dwgs)
    )
  )
  (princ)
)

(defun swcad-title-abort-interactive-gmtitle-script-active (reason)
  (swcad-title-apply-result "ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE")
  (swcad-title-princ-text "\nSCRIPT/자동화 실행 중에는 대화식 GMTITLE 창을 안전하게 열 수 없어 중단합니다.")
  (if reason
    (swcad-title-princ-text (strcat "\n중단 이유: " reason))
  )
  (swcad-title-princ-text "\n먼저 SWTITLESTATUS로 상태만 확인한 뒤, CAD 명령줄에서 SWTITLECONVERTNEXT를 직접 입력하세요.")
  (swcad-title-princ-text "\nGMTITLE 창이 열리면 로그가 요구한 DR_A*_Outline, DR_titlea_3rd, Frame positioning ON, Object move OFF를 눈으로 확인하세요.")
)

(defun swcad-title-integrated-convert (/ summary source-count frame-only-count command-text-records command-text-count a3a4-count style-records frame-definition-blockers definition-raw-risk-records orphan-records missing-required-native example-title old-batch-mode apply-result answer)
  (swcad-title-integrated-command-header "SWTITLECONVERT" "변환 실행")
  (if (swcad-title-script-active-p)
    (swcad-title-abort-interactive-gmtitle-script-active
      "SWTITLECONVERT는 도면을 변경할 수 있고 GMTITLE 창 선택이 필요할 수 있어 자동 실행에서는 진행하지 않습니다."
    )
    (if (swcad-title-active-dwg-confirmed-p)
      (progn
      (if *swcad-title-pending-manual-native-upgrade*
        (progn
          (swcad-title-princ-text "\n대기 중인 수동 native GMTITLE 교체 마무리 작업이 있습니다.")
          (swcad-title-princ-text "\n방금 GMTITLE로 만든 한 장을 검사해서 값 복사, 기존 쌍 삭제, native marker 설정을 진행합니다.")
          (swcad-title-upgrade-native-a3a4-finish)
        )
        (progn
          (setq summary (swcad-title-fast-sheet-summary))
          (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
          (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
          (setq command-text-records (swcad-title-command-text-residue-records))
          (setq command-text-count (length command-text-records))
          (setq a3a4-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
          (setq example-title (swcad-title-native-example-title))
          (setq missing-required-native (swcad-title-missing-required-native-frame-blocks summary))
          (setq style-records (swcad-title-frame-style-normalization-records))
          (setq frame-definition-blockers (swcad-title-frame-definition-blocking-records))
          (setq definition-raw-risk-records (swcad-title-frame-definition-raw-bbox-risk-records))
          (setq orphan-records (swcad-title-orphan-target-frame-records))
          (swcad-title-print-fast-sheet-summary summary)
          (cond
        (command-text-records
          (swcad-title-apply-result "ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST")
          (swcad-title-princ-text
            (strcat
              "\n실수 명령어 텍스트 후보가 "
              (itoa command-text-count)
              "개 남아 있어 변환을 시작하지 않습니다."
            )
          )
          (swcad-title-command-text-scan)
          (swcad-title-princ-text "\n다음: SWTITLESTATUS로 후보를 확인하고, 작업복사본 안의 실수 잔여물이 맞으면 SWTITLEPREPARE에서 정리하세요.")
        )
        (style-records
          (swcad-title-apply-result "ABORT_FRAME_STYLE_NOT_NORMALIZED")
          (swcad-title-princ-text "\n변환 전 도면틀 스타일 정규화가 먼저 필요합니다.")
          (swcad-title-print-frame-style-normalization-records style-records)
          (swcad-title-princ-text "\n다음: SWTITLEPREPARE를 실행해 후보를 확인한 뒤 SWTITLESTATUS를 다시 확인하세요.")
        )
        (frame-definition-blockers
          (swcad-title-apply-result "ABORT_FRAME_DEFINITION_NOT_NORMALIZED")
          (swcad-title-princ-text "\n변환 전 도면틀 정의 정규화가 먼저 필요합니다.")
          (swcad-title-print-frame-definition-class-records frame-definition-blockers)
          (swcad-title-princ-text "\n다음: SWTITLEPREPARE를 실행하고, 후보가 맞으면 YES로 정리한 뒤 SWTITLESTATUS를 다시 확인하세요.")
        )
        (definition-raw-risk-records
          (swcad-title-apply-result "ABORT_FRAME_DEFINITION_RAW_BBOX_RISK")
          (swcad-title-princ-text "\n변환 전 도면틀 정의 raw bbox 위험을 먼저 확인해야 합니다.")
          (swcad-title-print-frame-definition-raw-bbox-risk-records definition-raw-risk-records)
          (swcad-title-princ-text "\n다음: SWTITLESTATUS 로그를 확인하고, 도면틀 정의 복구/정규화가 준비될 때까지 기존 원본 도면틀을 삭제하지 마세요.")
        )
        (orphan-records
          (swcad-title-apply-result "ABORT_ORPHAN_TARGET_FRAMES_REMAIN")
          (swcad-title-princ-text "\n제목블록 없는 GMTITLE 도면틀이 남아 있어 변환을 계속하지 않습니다.")
          (swcad-title-print-orphan-target-frame-records orphan-records)
          (swcad-title-princ-text "\n다음: SWTITLEPREPARE를 실행해 고아 도면틀을 먼저 정리하고 SWTITLESTATUS를 다시 확인하세요.")
          (swcad-title-princ-text "\n이 상태에서 다음 용지로 넘어가면 A2/A3/A4 title-sheet 완료 판단이 어긋날 수 있습니다.")
        )
        ((> a3a4-count 0)
          (swcad-title-princ-text
            (strcat
              "\n이미 만들어진 A2/A3/A4 GMTITLE 중 native 더블클릭 검증이 필요한 쌍이 "
              (itoa a3a4-count)
              "개 있습니다."
            )
          )
          (swcad-title-print-compact-next-gmtitle-card summary missing-required-native example-title a3a4-count)
          (if
            (and
              *swcad-title-convert-next-mode*
              (swcad-title-gmtitle-autoselect-available-p)
            )
            (progn
              (swcad-title-princ-text "\n고정 컨트롤 자동 선택이 준비되어 현재 native 교체 후보를 모두 연속 처리합니다.")
              (swcad-title-upgrade-native-a3a4-all)
            )
            (if (swcad-title-script-active-p)
            (swcad-title-abort-interactive-gmtitle-script-active
              "A2/A3/A4 native 교체는 GMTITLE 창의 용지/제목블록 선택을 사람이 확인해야 합니다."
            )
            (progn
              (swcad-title-princ-text "\nSWTITLECONVERT 내부에서 A2/A3/A4 native 교체 단계를 안내합니다. OPEN은 1장, BATCH는 여러 장 연속 처리입니다.")
              (swcad-title-upgrade-native-a3a4-next)
            )
            )
          )
        )
        ((and (= source-count 0) (= frame-only-count 0))
          (swcad-title-princ-text "\n변환할 원본 SolidWorks 시트가 없습니다. SWTITLEVERIFY를 실행하세요.")
        )
        ((and (= source-count 0) (> frame-only-count 0))
          (swcad-title-princ-text
            (strcat
              "\n표제란 없는 도면틀 시트가 "
              (itoa frame-only-count)
              "개 남아 있습니다."
            )
          )
          (if (swcad-title-script-active-p)
            (swcad-title-abort-interactive-gmtitle-script-active
              "title-missing/frame-only 도면틀-only 변환은 도면을 변경하므로, 보이는 CAD에서 SWTITLESTATUS 안내를 확인한 뒤 SWTITLECONVERTNEXT로 진행해야 합니다."
            )
            (if (swcad-title-title-missing-outline-policy-blocked-p)
              (if (swcad-title-title-missing-outline-definition-needed-p)
                (progn
                  (swcad-title-apply-result "WAITING_FOR_TITLE_MISSING_OUTLINE_DEFINITION")
                  (swcad-title-princ-text "\n같은 크기 DR 도면틀 정의가 아직 title-missing/frame-only 변환 기준을 통과하지 못했습니다.")
                  (swcad-title-print-title-missing-outline-definition-status)
                  (swcad-title-princ-text "\n다음: SWTITLEPREPARE를 실행해 같은 크기 DR 도면틀 정의를 먼저 준비/검증하세요.")
                  (swcad-title-princ-text "\n기존 원본 도면틀은 삭제하지 않았습니다.")
                )
                (progn
                  (swcad-title-princ-text "\nSWTITLECONVERT 내부에서 title-missing 도면틀-only 변환 단계를 실행합니다.")
                  (if *swcad-title-convert-next-mode*
                    (progn
                      (swcad-title-princ-text "\nSWTITLECONVERTNEXT는 검증된 남은 title-missing 도면틀 시트를 모두 연속 처리합니다.")
                      (swcad-title-transfer-title-missing-outline-all)
                    )
                    (swcad-title-transfer-title-missing-outline-apply)
                  )
                )
              )
              (progn
                (swcad-title-apply-result "ABORT_TITLE_MISSING_OUTLINE_UNAVAILABLE")
                (swcad-title-princ-text "\n이 표제란 없는 도면틀 시트는 공통 title-missing 도면틀-only 조건을 통과하지 못했습니다.")
                (swcad-title-princ-text "\nA2/A3/A4는 같은 GMTITLE 흐름으로 처리해야 하므로 구형 frame-only native fallback은 실행하지 않습니다.")
                (swcad-title-princ-text "\n다음: SWTITLESTATUS/SWTITLEPREPARE로 원본 표제란 부재와 같은 크기 DR_A*_Outline 정의 상태를 먼저 확인하세요.")
              )
            )
          )
        )
        ((not example-title)
          (swcad-title-princ-text "\n첫 native GMTITLE 기준 객체가 없습니다. SWTITLECONVERT 내부에서 첫 native 생성 단계를 진행합니다.")
          (swcad-title-print-compact-next-gmtitle-card summary missing-required-native example-title a3a4-count)
          (swcad-title-print-next-bootstrap-selection)
          (if
            (and
              *swcad-title-convert-next-mode*
              (swcad-title-gmtitle-autoselect-available-p)
            )
            (progn
              (swcad-title-princ-text "\n고정 컨트롤 자동 선택으로 남은 표제란 시트를 복제 없이 실제 native GMTITLE로 연속 변환합니다.")
              (swcad-title-transfer-native-autoselect-all)
            )
            (progn
              (swcad-title-princ-text "\nSWTITLECONVERTNEXT 선택 안내: 위 용지/도면틀과 제목블록을 고르고, Frame positioning은 ON, Object move는 OFF로 두세요.")
              (if (swcad-title-script-active-p)
                (swcad-title-abort-interactive-gmtitle-script-active
                  "첫 native GMTITLE 기준 객체 생성은 GMTITLE 창 선택을 사람이 확인해야 합니다."
                )
                (swcad-title-transfer-bootstrap-fast)
              )
            )
          )
        )
        ((and (> source-count 0) (not (swcad-title-next-fast-target-ready-p)))
          (swcad-title-princ-text "\n다음 원본 표제란 시트와 같은 크기의 native GMTITLE 기준 객체가 아직 없습니다.")
          (swcad-title-princ-text "\nSWTITLECONVERT 내부에서 이 크기의 실제 native GMTITLE 한 장을 먼저 생성합니다.")
          (swcad-title-print-compact-next-gmtitle-card summary missing-required-native example-title a3a4-count)
          (swcad-title-print-next-missing-native-selection summary missing-required-native)
          (if
            (and
              *swcad-title-convert-next-mode*
              (swcad-title-gmtitle-autoselect-available-p)
            )
            (progn
              (swcad-title-princ-text "\n누락 크기도 고정 컨트롤 자동 선택이 감지한 용지값으로 직접 native 생성합니다.")
              (swcad-title-transfer-native-autoselect-all)
            )
            (progn
              (swcad-title-princ-text "\nSWTITLECONVERTNEXT 선택 안내: 위 용지/도면틀과 제목블록을 고르고, Frame positioning은 ON, Object move는 OFF로 두세요.")
              (if (swcad-title-script-active-p)
            (swcad-title-abort-interactive-gmtitle-script-active
              "누락 크기의 첫 native GMTITLE 기준 객체 생성은 GMTITLE 창 선택을 사람이 확인해야 합니다."
            )
            (progn
              (setq answer
                (swcad-title-auto-next-answer-or-prompt
                  "YES"
                  "누락된 용지 크기의 첫 native GMTITLE 생성"
                  "\n이 크기의 첫 native GMTITLE을 생성/마무리하려면 YES를 입력하세요: "
                )
              )
              (if (/= (strcase answer) "YES")
                (progn
                  (setq *swcad-title-last-apply-status* "ABORT_USER_CANCEL")
                  (swcad-title-princ-text "\nResult: ABORT_USER_CANCEL")
                )
                (progn
                  (setq old-batch-mode *swcad-title-batch-mode*)
                  (setq *swcad-title-batch-mode* T)
                  (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-apply nil))
                  (setq *swcad-title-batch-mode* old-batch-mode)
                  (if (vl-catch-all-error-p apply-result)
                    (progn
                      (setq *swcad-title-last-apply-status* "ERROR_MISSING_NATIVE_EXEMPLAR_FATAL")
                      (princ
                        (strcat
                          "\nMissing native exemplar error: "
                          (vl-catch-all-error-message apply-result)
                        )
                      )
                    )
                  )
                )
              )
            )
              )
            )
          )
        )
        (T
          (if
            (and
              *swcad-title-convert-next-mode*
              (swcad-title-gmtitle-autoselect-available-p)
            )
            (progn
              (swcad-title-princ-text "\n고정 컨트롤 자동 선택으로 남은 표제란 시트를 복제 없이 실제 native GMTITLE로 연속 변환합니다.")
              (swcad-title-transfer-native-autoselect-all)
            )
            (if *swcad-title-convert-next-mode*
            (progn
              (swcad-title-princ-text "\n기준 GMTITLE이 있으므로 SWTITLECONVERTNEXT는 남은 표제란 시트 중 다음 1장만 clone 변환합니다.")
              (setq old-batch-mode *swcad-title-batch-mode*)
              (setq *swcad-title-batch-mode* T)
              (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-clone-apply nil))
              (setq *swcad-title-batch-mode* old-batch-mode)
              (if (vl-catch-all-error-p apply-result)
                (progn
                  (setq *swcad-title-last-apply-status* "ERROR_CONVERT_NEXT_SINGLE_CLONE_FATAL")
                  (princ
                    (strcat
                      "\nSWTITLECONVERTNEXT single clone error: "
                      (vl-catch-all-error-message apply-result)
                    )
                  )
                )
              )
              (setq a3a4-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
              (if (> a3a4-count 0)
                (progn
                  (swcad-title-princ-text
                    (strcat
                      "\nclone 변환 후 A2/A3/A4 native 교체 후보가 "
                      (itoa a3a4-count)
                      "개 생겼습니다."
                    )
                  )
                  (if (vl-catch-all-error-p apply-result)
                    (swcad-title-princ-text "\nclone 변환 오류가 있어 native 교체 단계는 실행하지 않습니다.")
                    (progn
                      (swcad-title-princ-text "\nSWTITLECONVERTNEXT가 이어서 다음 native 교체 후보 1장을 처리합니다.")
                      (if (swcad-title-script-active-p)
                        (swcad-title-abort-interactive-gmtitle-script-active
                          "clone 변환 뒤 생긴 A2/A3/A4 native 교체 후보는 GMTITLE 창 확인이 필요합니다."
                        )
                        (swcad-title-upgrade-native-a3a4-next)
                      )
                    )
                  )
                )
              )
            )
            (progn
              (swcad-title-princ-text "\n기준 GMTITLE이 있으므로 남은 시트를 빠른 일괄 변환으로 처리합니다.")
              (swcad-title-transfer-fast-batch)
              (setq a3a4-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
              (if (> a3a4-count 0)
                (progn
                  (swcad-title-princ-text
                    (strcat
                      "\n빠른 변환 후 A2/A3/A4 native 교체 후보가 "
                      (itoa a3a4-count)
                      "개 생겼습니다."
                    )
                  )
                  (swcad-title-princ-text "\nSWTITLECONVERT 내부에서 이어서 A2/A3/A4 native 교체 단계를 한 장만 안전하게 실행합니다.")
                  (if (swcad-title-script-active-p)
                    (swcad-title-abort-interactive-gmtitle-script-active
                      "빠른 변환 뒤 생긴 A2/A3/A4 native 교체 후보는 GMTITLE 창 확인이 필요합니다."
                    )
                    (swcad-title-upgrade-native-a3a4-next)
                  )
                )
              )
            )
          )
          )
        )
      )
        )
      )
      )
      (swcad-title-abort-multiple-open-dwgs)
    )
  )
  (swcad-title-princ-text "\nSWTITLECONVERT 완료: 멈춤/경고가 있으면 SWTITLESTATUS를, 완료되면 SWTITLEVERIFY를 실행하세요.")
  (swcad-title-princ-text "\n")
  (swcad-title-print-after-manual-step-guidance)
  (princ)
)

(defun swcad-title-integrated-verify-final-summary (/ summary source-titles source-frames command-text-records embedded-title-records style-records style-residue-records style-residue-count frame-definition-records frame-definition-blockers definition-raw-risk-records definition-raw-risk-count orphan-records contaminated frame-records title-enames pair-records geometry-risk-count overlap-risk-count a3a4-count target-title-count target-frame-count pair-count title-missing-outline-count invalid-title-missing-records invalid-title-missing-count frame-only-source-count source-frame-with-title-count missing-title-count extra-title-count title-missing-tags-count title-empty-attrs-count non-native-like-count required-missing-count required-sheets missing-required-sheets target-sheet-counts stored-expected-sheet-counts expected-sheet-counts count-shortage-records count-excess-records count-shortage-count count-excess-count target-title-sheet-counts stored-expected-title-counts expected-title-counts title-count-shortage-records title-count-excess-records title-count-shortage-count title-count-excess-count status result-code record title-ename attr-pairs)
  (swcad-title-open-verify-summary-log)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq source-titles (swcad-title-source-title-candidates))
  (setq source-frames (swcad-title-source-frame-candidates))
  (setq command-text-records (swcad-title-command-text-residue-records))
  (setq embedded-title-records (swcad-title-frame-embedded-title-records))
  (setq style-records (swcad-title-frame-style-normalization-records))
  (setq style-residue-records (swcad-title-frame-style-records-from-pairs style-records 13))
  (setq style-residue-count (length style-residue-records))
  (setq frame-definition-records (swcad-title-frame-definition-class-records))
  (setq frame-definition-blockers (swcad-title-frame-definition-blocking-records))
  (setq definition-raw-risk-records (swcad-title-frame-definition-raw-bbox-risk-records))
  (setq definition-raw-risk-count (length definition-raw-risk-records))
  (setq orphan-records (swcad-title-orphan-target-frame-records))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq frame-records (swcad-title-frame-records))
  (setq title-enames (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq pair-records (swcad-title-target-gmtitle-pair-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq a3a4-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
  (setq target-title-count (length title-enames))
  (setq target-frame-count (length frame-records))
  (setq pair-count (length pair-records))
  (setq title-missing-outline-count (swcad-title-title-missing-outline-frame-count))
  (setq invalid-title-missing-records (swcad-title-title-missing-outline-with-loose-title-records))
  (setq invalid-title-missing-count (length invalid-title-missing-records))
  (setq frame-only-source-count (swcad-title-frame-only-source-count))
  (setq source-frame-with-title-count (- (length source-frames) frame-only-source-count))
  (if (< source-frame-with-title-count 0)
    (setq source-frame-with-title-count 0)
  )
  (setq missing-title-count
    (if (> target-frame-count (+ pair-count title-missing-outline-count))
      (- target-frame-count pair-count title-missing-outline-count)
      0
    )
  )
  (setq extra-title-count (if (> target-title-count pair-count) (- target-title-count pair-count) 0))
  (setq title-missing-tags-count 0)
  (setq title-empty-attrs-count 0)
  (foreach title-ename title-enames
    (setq attr-pairs (swcad-title-title-attribute-pairs (swcad-title-safe-vla-object title-ename)))
    (if (> (length (swcad-title-missing-template-tags attr-pairs)) 0)
      (setq title-missing-tags-count (+ title-missing-tags-count 1))
    )
    (if (= (swcad-title-nonempty-attribute-count attr-pairs) 0)
      (setq title-empty-attrs-count (+ title-empty-attrs-count 1))
    )
  )
  (setq non-native-like-count 0)
  (foreach record pair-records
    (if (not (swcad-title-target-pair-native-like-p record))
      (setq non-native-like-count (+ non-native-like-count 1))
    )
  )
  (setq required-sheets (swcad-title-active-required-sheets summary))
  (setq target-sheet-counts (swcad-title-target-frame-sheet-counts))
  (setq stored-expected-sheet-counts (swcad-title-stored-expected-sheet-counts))
  (setq expected-sheet-counts
    (if stored-expected-sheet-counts
      stored-expected-sheet-counts
      (swcad-title-current-total-sheet-counts summary)
    )
  )
  (setq count-shortage-records (swcad-title-count-shortage-records expected-sheet-counts target-sheet-counts))
  (setq count-excess-records (swcad-title-count-excess-records expected-sheet-counts target-sheet-counts))
  (setq count-shortage-count (length count-shortage-records))
  (setq count-excess-count (length count-excess-records))
  (setq target-title-sheet-counts (swcad-title-target-title-sheet-counts))
  (setq stored-expected-title-counts (swcad-title-stored-expected-title-counts))
  (setq expected-title-counts
    (if stored-expected-title-counts
      stored-expected-title-counts
      (swcad-title-current-total-title-counts summary)
    )
  )
  (setq title-count-shortage-records (swcad-title-count-shortage-records expected-title-counts target-title-sheet-counts))
  (setq title-count-excess-records (swcad-title-count-excess-records expected-title-counts target-title-sheet-counts))
  (setq title-count-shortage-count (length title-count-shortage-records))
  (setq title-count-excess-count (length title-count-excess-records))
  (setq missing-required-sheets (swcad-title-missing-required-target-sheets target-sheet-counts required-sheets))
  (setq required-missing-count (length missing-required-sheets))
  (setq status
    (cond
      (
        (or
          (= target-frame-count 0)
          (and (= target-title-count 0) (= title-missing-outline-count 0))
          (and (= pair-count 0) (= title-missing-outline-count 0))
          (> title-missing-tags-count 0)
          (> required-missing-count 0)
          (> count-shortage-count 0)
          (> title-count-shortage-count 0)
          (> invalid-title-missing-count 0)
        )
        "FAIL"
      )
      (
        (or
          (> (length source-titles) 0)
          (> (length source-frames) 0)
          (> (length command-text-records) 0)
          (> (length embedded-title-records) 0)
          (> (length style-records) 0)
          frame-definition-blockers
          (> definition-raw-risk-count 0)
          (> (length orphan-records) 0)
          contaminated
          (> geometry-risk-count 0)
          (> overlap-risk-count 0)
          (> a3a4-count 0)
          (> missing-title-count 0)
          (> extra-title-count 0)
          (> count-excess-count 0)
          (> title-count-excess-count 0)
          (> title-empty-attrs-count 0)
          (> non-native-like-count 0)
        )
        "WARN"
      )
      (T "OK")
    )
  )
  (setq result-code
    (if (and (equal status "WARN") (> style-residue-count 0))
      "SWTITLEVERIFY_WARN_RESIDUE_REMAINS"
      (strcat "SWTITLEVERIFY_FINAL_" status)
    )
  )
  (setq *swcad-title-last-apply-status* result-code)
  (swcad-title-princ-line "----- SWTITLEVERIFY 통합 최종 요약 -----")
  (swcad-title-princ-line (strcat "남은 원본 표제란 후보: " (itoa (length source-titles))))
  (swcad-title-princ-line (strcat "남은 원본 도면틀 후보: " (itoa (length source-frames))))
  (swcad-title-princ-line (strcat "실수 명령어 텍스트 후보: " (itoa (length command-text-records))))
  (swcad-title-princ-line (strcat "도면틀 내부 표제란 형상 후보: " (itoa (length embedded-title-records))))
  (swcad-title-princ-line (strcat "도면틀 스타일 정규화 필요 후보: " (itoa (length style-records))))
  (swcad-title-princ-line (strcat "독립 검증 기존 표제란 잔여물: " (itoa style-residue-count)))
  (swcad-title-print-frame-style-entity-records "독립 검증 잔여물 상세:" style-residue-records)
  (swcad-title-princ-line (strcat "도면틀 정의 정규화 차단 항목: " (itoa (length frame-definition-blockers))))
  (swcad-title-princ-line (strcat "도면틀 정의 raw bbox 위험 수: " (itoa definition-raw-risk-count)))
  (swcad-title-print-frame-definition-class-records frame-definition-records)
  (swcad-title-print-frame-definition-raw-bbox-risk-records definition-raw-risk-records)
  (swcad-title-print-frame-style-normalization-records style-records)
  (swcad-title-princ-line (strcat "고아 GMTITLE 도면틀: " (itoa (length orphan-records))))
  (swcad-title-princ-line (strcat "오염 의심 대상 도면틀 정의: " (swcad-title-list-string contaminated)))
  (swcad-title-princ-line (strcat "대상 도면틀 수: " (itoa target-frame-count)))
  (swcad-title-princ-line (strcat "대상 제목블록 수: " (itoa target-title-count)))
  (swcad-title-princ-line (strcat "도면틀/제목블록 쌍 수: " (itoa pair-count)))
  (swcad-title-princ-line (strcat "title-missing 도면틀-only 대상 수: " (itoa title-missing-outline-count)))
  (swcad-title-princ-line (strcat "제목 MTEXT가 남은 잘못된 title-missing 대상 수: " (itoa invalid-title-missing-count)))
  (swcad-title-princ-line (strcat "제목블록 없는 대상 도면틀 수: " (itoa missing-title-count)))
  (swcad-title-princ-line (strcat "도면틀과 짝이 없는 대상 제목블록 수: " (itoa extra-title-count)))
  (swcad-title-princ-line (strcat "속성 태그 누락 제목블록 수: " (itoa title-missing-tags-count)))
  (swcad-title-princ-line (strcat "속성 값이 모두 빈 제목블록 수: " (itoa title-empty-attrs-count)))
  (swcad-title-princ-line (strcat "A2/A3/A4 native 교체 필요 쌍: " (itoa a3a4-count)))
  (swcad-title-princ-line (strcat "native-like가 아닌 대상 쌍: " (itoa non-native-like-count)))
  (swcad-title-princ-line (strcat "도면틀 형상 경고 수: " (itoa geometry-risk-count)))
  (swcad-title-princ-line (strcat "도면틀 겹침/선택 위험 수: " (itoa overlap-risk-count)))
  (swcad-title-print-counts "변환 기준 전체 용지 수:" expected-sheet-counts)
  (swcad-title-princ-line
    (strcat
      "변환 기준 수량 출처: "
      (if stored-expected-sheet-counts
        "도면 xdata 기록"
        "현재 원본+대상 상태 추정"
      )
    )
  )
  (swcad-title-print-counts "용지별 대상 도면틀 수:" target-sheet-counts)
  (swcad-title-print-count-deltas "대상 도면틀 수량 부족:" count-shortage-records)
  (swcad-title-print-count-deltas "대상 도면틀 수량 초과:" count-excess-records)
  (swcad-title-print-counts "변환 기준 제목 보유 시트 수:" expected-title-counts)
  (swcad-title-princ-line
    (strcat
      "제목 보유 수량 출처: "
      (if stored-expected-title-counts
        "도면 xdata 기록"
        "현재 원본 제목+대상 제목 상태 추정"
      )
    )
  )
  (swcad-title-print-counts "용지별 대상 제목블록 수:" target-title-sheet-counts)
  (swcad-title-print-count-deltas "대상 제목블록 수량 부족:" title-count-shortage-records)
  (swcad-title-print-count-deltas "대상 제목블록 수량 초과:" title-count-excess-records)
  (swcad-title-print-string-list "현재 필요한 대상 용지:" required-sheets)
  (swcad-title-print-string-list "누락된 대상 용지:" missing-required-sheets)
  (swcad-title-princ-line (strcat "현재 필요한 대상 용지 누락 수: " (itoa required-missing-count)))
  (swcad-title-princ-line (strcat "Result: " result-code))
  (swcad-title-princ-line (strcat "최종 결과: " status))
  (cond
    ((equal status "OK")
      (swcad-title-princ-line "다음: 변환된 대표 용지의 DR_titlea_3rd 제목블록을 더블클릭해 GMTITLE 표 편집창을 확인하세요.")
    )
    ((equal status "WARN")
      (swcad-title-princ-line "다음: SWTITLESTATUS를 실행해 남은 경고의 다음 조치를 확인하세요. 모양만 보고 완료로 판단하지 마세요.")
    )
    (T
      (cond
        ((> a3a4-count 0)
          (swcad-title-princ-line "다음 단계 코드: UPGRADE_NATIVE_GMTITLE")
          (swcad-title-princ-line "다음: 특정 용지 누락이나 title-missing 예외가 있더라도 A2/A3/A4 native 교체 후보가 먼저입니다.")
          (swcad-title-princ-line "SWTITLESTATUS로 후보를 확인한 뒤 SWTITLECONVERTNEXT를 실행해 다음 A2/A3/A4 후보를 처리하세요.")
          (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
        )
        ((and (= (length source-titles) 0) (> frame-only-source-count 0))
          (swcad-title-princ-line "다음 단계 코드: TITLE_MISSING_AFTER_SOURCES")
          (swcad-title-princ-line "다음: 남은 표제란 없는 도면틀 시트를 SWTITLECONVERTNEXT로 처리하세요.")
          (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
          (swcad-title-princ-line "원본에 제목블록이 없다고 검증된 시트이므로 새 DR_titlea_3rd를 만들지 않고 같은 크기 DR 도면틀만 검증합니다.")
        )
        ((or (> (length source-titles) 0) (> source-frame-with-title-count 0))
          (swcad-title-princ-line "다음 단계 코드: SOURCE_SHEETS_BEFORE_TITLE_MISSING")
          (swcad-title-princ-line "다음: 아직 원본 SolidWorks 표제란/도면틀이 남아 있으므로 title-missing 예외보다 원본 시트 변환이 먼저입니다.")
          (swcad-title-princ-line "SWTITLESTATUS로 현재 상태를 확인한 뒤 SWTITLECONVERTNEXT로 남은 원본 SolidWorks 시트를 처리하세요.")
          (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
        )
        ((or (> invalid-title-missing-count 0) (> title-count-shortage-count 0))
          (swcad-title-princ-line "다음 단계 코드: REVIEW_MISSING_NATIVE_TITLES")
          (swcad-title-princ-line "다음: 제목 정보가 있던 시트의 DR_titlea_3rd가 누락됐습니다. 원본 작업복사본에서 SWTITLESTATUS 후 통합 변환을 다시 실행하세요.")
          (swcad-title-princ-line "기존 title-missing 도면틀-only 결과를 최종 성공으로 사용하지 마세요.")
        )
        ((> title-missing-tags-count 0)
          (swcad-title-princ-line "다음 단계 코드: REVIEW_TITLE_TAGS")
          (swcad-title-princ-line "다음: 속성 태그가 누락된 제목블록을 먼저 확인하세요.")
        )
        ((> count-shortage-count 0)
          (swcad-title-princ-line "다음 단계 코드: REVIEW_TARGET_SHEET_SHORTAGE")
          (swcad-title-princ-line "다음: 변환 기준 수량 대비 부족한 대상 도면틀을 SWTITLESTATUS에서 확인하고 SWTITLECONVERTNEXT로 보충하세요.")
          (swcad-title-princ-line "수동 응답을 직접 고르려면 SWTITLECONVERT를 사용하세요.")
        )
        (T
          (swcad-title-princ-line "다음 단계 코드: REVIEW_MISSING_TARGET_STRUCTURE")
          (swcad-title-princ-line "다음: 누락된 대상 도면틀/제목블록 또는 속성 태그 문제를 먼저 처리하세요.")
        )
      )
    )
  )
  (swcad-title-princ-line "도면 데이터는 변경하지 않았습니다.")
  (swcad-title-close-log)
  status
)

(defun swcad-title-integrated-verify (/ cache-owned)
  (setq cache-owned (not *swcad-title-frame-style-analysis-cache-enabled*))
  (if cache-owned
    (swcad-title-frame-style-analysis-cache-begin)
  )
  (swcad-title-integrated-command-header "SWTITLEVERIFY" "최종 검증")
  (swcad-title-princ-text "\n표제란 중복, 고아 도면틀, 현재 필요한 대상 용지 누락, native-like 상태를 읽기 전용으로 확인합니다.")
  (swcad-title-gmtitle-verify-all)
  (swcad-title-native-frame-completion-check)
  (swcad-title-double-click-check)
  (swcad-title-integrated-verify-final-summary)
  (if cache-owned
    (swcad-title-frame-style-analysis-cache-end)
  )
  (swcad-title-princ-text "\nSWTITLEVERIFY 완료: 최종 결과가 OK가 아니면 SWTITLESTATUS로 다음 조치를 확인하세요.")
  (princ)
)

(defun c:SWTITLESTATUS ()
  (swcad-title-integrated-status)
)

(defun c:SWTITLEPREPARE ()
  (if (swcad-title-script-active-p)
    (swcad-title-integrated-prepare)
    (if (swcad-title-ensure-work-copy-for-mutation)
      (swcad-title-integrated-prepare)
      (progn
        (swcad-title-princ-text "\nSWTITLEPREPARE 중단: 작업본을 만들지 않아 원본을 변경하지 않았습니다.")
        (princ)
      )
    )
  )
)

(defun c:SWTITLECONVERT ()
  (if (swcad-title-script-active-p)
    (progn
      (swcad-title-princ-text "\n===== SWTITLECONVERT 변환 실행 =====")
      (swcad-title-print-loaded-version)
      (swcad-title-abort-interactive-gmtitle-script-active
        "SWTITLECONVERT는 도면을 변경할 수 있고 GMTITLE 창 선택이 필요할 수 있어 SCRIPT나 /b 자동 실행에서는 진행하지 않습니다."
      )
      (swcad-title-princ-text "\nSWTITLECONVERT 완료: SWTITLESTATUS로 상태를 확인한 뒤 CAD 명령줄에서 직접 다시 실행하세요.")
      (princ)
    )
    (if (swcad-title-ensure-work-copy-for-mutation)
      (swcad-title-integrated-convert)
      (progn
        (swcad-title-princ-text "\nSWTITLECONVERT 중단: 작업본을 만들지 않아 원본을 변경하지 않았습니다.")
        (princ)
      )
    )
  )
)

(defun swcad-title-integrated-convert-next (/ old-auto result)
  (setq old-auto *swcad-title-convert-next-mode*)
  (setq *swcad-title-convert-next-mode* T)
  (swcad-title-princ-text "\n===== SWTITLECONVERTNEXT 다음 1단계 자동 선택 =====")
  (swcad-title-princ-text "\n반복 확인 입력은 현재 상태의 안전한 다음 응답으로 자동 선택합니다.")
  (swcad-title-princ-text "\nGMTITLE 창의 DR 용지/DR_titlea_3rd/Frame positioning ON/Object move OFF 확인은 계속 사람이 해야 합니다.")
  (setq result (vl-catch-all-apply 'swcad-title-integrated-convert nil))
  (setq *swcad-title-convert-next-mode* old-auto)
  (if (vl-catch-all-error-p result)
    (progn
      (swcad-title-princ-text
        (strcat
          "\nSWTITLECONVERTNEXT 오류: "
          (vl-catch-all-error-message result)
        )
      )
      (setq *swcad-title-last-apply-status* "ERROR_CONVERT_NEXT_FATAL")
    )
  )
  (princ)
)

(defun c:SWTITLECONVERTNEXT ()
  (if (swcad-title-script-active-p)
    (progn
      (swcad-title-princ-text "\n===== SWTITLECONVERTNEXT 다음 1단계 자동 선택 =====")
      (swcad-title-print-loaded-version)
      (swcad-title-abort-interactive-gmtitle-script-active
        "SWTITLECONVERTNEXT도 GMTITLE 창 선택이 필요할 수 있어 SCRIPT나 /b 자동 실행에서는 진행하지 않습니다."
      )
      (swcad-title-princ-text "\nSWTITLECONVERTNEXT 완료: SWTITLESTATUS로 상태를 확인한 뒤 CAD 명령줄에서 직접 다시 실행하세요.")
      (princ)
    )
    (if (swcad-title-ensure-work-copy-for-mutation)
      (swcad-title-integrated-convert-next)
      (progn
        (swcad-title-princ-text "\nSWTITLECONVERTNEXT 중단: 작업본을 만들지 않아 원본을 변경하지 않았습니다.")
        (princ)
      )
    )
  )
)

(defun c:SWTITLEVERIFY ()
  (swcad-title-integrated-verify)
)

(defun c:SWTITLEVERSION ()
  (setq *swcad-title-last-apply-status* "SWTITLEVERSION_OK")
  (swcad-title-princ-text "\n----- SWTITLEVERSION 로드된 LSP 확인(읽기 전용) -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-text (strcat "\n통합 흐름 기준 기대 버전: " *swcad-title-scale-version*))
  (swcad-title-princ-text "\n다른 버전이 보이면 SWTITLESTATUS 결과를 믿기 전에 이 파일을 다시 APPLOAD하세요.")
  (swcad-title-princ-text "\n도면 데이터는 변경하지 않았습니다.")
  (princ)
)

(defun c:SWSCALESCAN (/ insert-ss insert-index insert-total dim-ss dim-index dim-total ename data overrides style styledata override-value style-value effective-value expected-values effective-counts override-counts style-counts match-count mismatch-count mismatch-example-count match result)
  (swcad-title-open-scale-log)
  (setq *swcad-title-scan-title-insert-count* 0)
  (setq *swcad-title-scan-scale-count* 0)
  (setq *swcad-title-scan-loose-text-count* 0)
  (setq *swcad-title-scan-loose-scale-count* 0)
  (setq *swcad-title-scan-scale-values* nil)
  (setq effective-counts nil)
  (setq override-counts nil)
  (setq style-counts nil)
  (setq match-count 0)
  (setq mismatch-count 0)
  (setq mismatch-example-count 0)
  (swcad-title-princ-line "----- SWSCALESCAN read-only title scale / DIMLFAC scan -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))

  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (swcad-title-princ-line (strcat "INSERT count: " (itoa insert-total)))
  (swcad-title-princ-line "Attribute title scale candidates:")
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (swcad-title-scan-insert ename)
    (setq insert-index (+ insert-index 1))
  )
  (if (= *swcad-title-scan-scale-count* 0)
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-scan-loose-texts)

  (setq expected-values (swcad-title-expected-dimlfac-values *swcad-title-scan-scale-values*))
  (swcad-title-princ-line "Title scale summary:")
  (swcad-title-princ-line
    (strcat "  title inserts with scale: " (itoa *swcad-title-scan-title-insert-count*))
  )
  (swcad-title-princ-line
    (strcat "  scale attributes: " (itoa *swcad-title-scan-scale-count*))
  )
  (swcad-title-princ-line
    (strcat "  loose text scale candidates: " (itoa *swcad-title-scan-loose-scale-count*))
  )
  (swcad-title-princ-line
    (strcat "  title scale values: " (swcad-title-list-string *swcad-title-scan-scale-values*))
  )
  (swcad-title-princ-line
    (strcat "  expected DIMLFAC values: " (swcad-title-number-list-string expected-values))
  )

  (setq dim-ss (ssget "_X" '((0 . "DIMENSION"))))
  (setq dim-total (if dim-ss (sslength dim-ss) 0))
  (swcad-title-princ-line (strcat "DIMENSION count: " (itoa dim-total)))
  (swcad-title-princ-line "Dimension mismatch examples:")
  (setq dim-index 0)
  (while (< dim-index dim-total)
    (setq ename (ssname dim-ss dim-index))
    (setq data (entget ename '("*")))
    (setq overrides (swcad-title-get-dstyle-overrides data))
    (setq style (swcad-title-safe-string (cdr (assoc 3 data))))
    (setq styledata (if style (tblsearch "DIMSTYLE" style) nil))
    (setq override-value (cdr (assoc 144 overrides)))
    (setq style-value (if styledata (cdr (assoc 144 styledata)) nil))
    (setq effective-value (swcad-title-dim-linear-scale ename data))
    (setq effective-counts
      (swcad-title-count-add (swcad-title-number-string effective-value) effective-counts)
    )
    (if (numberp override-value)
      (setq override-counts
        (swcad-title-count-add (swcad-title-number-string override-value) override-counts)
      )
    )
    (setq style-counts
      (swcad-title-count-add
        (strcat
          (if style style "<no style>")
          " DIMLFAC="
          (if (numberp style-value) (swcad-title-number-string style-value) "<missing>")
        )
        style-counts
      )
    )
    (setq match (swcad-title-float-in-list-p effective-value expected-values))
    (if match
      (setq match-count (+ match-count 1))
      (progn
        (setq mismatch-count (+ mismatch-count 1))
        (if (< mismatch-example-count 12)
          (progn
            (setq mismatch-example-count (+ mismatch-example-count 1))
            (swcad-title-princ-line
              (strcat
                "  - handle="
                (swcad-title-string (cdr (assoc 5 data)))
                ", layout="
                (swcad-title-string (cdr (assoc 410 data)))
                ", style="
                (if style style "<no style>")
                ", override="
                (if (numberp override-value) (swcad-title-number-string override-value) "<none>")
                ", style DIMLFAC="
                (if (numberp style-value) (swcad-title-number-string style-value) "<missing>")
                ", effective="
                (swcad-title-number-string effective-value)
              )
            )
          )
        )
      )
    )
    (setq dim-index (+ dim-index 1))
  )
  (if (= mismatch-example-count 0)
    (swcad-title-princ-line "  <none>")
  )

  (swcad-title-print-counts "Effective DIMLFAC values:" effective-counts)
  (swcad-title-print-counts "Override DIMLFAC values:" override-counts)
  (swcad-title-print-counts "Style DIMLFAC values:" style-counts)
  (swcad-title-princ-line "Comparison summary:")
  (swcad-title-princ-line (strcat "  matching dimensions: " (itoa match-count)))
  (swcad-title-princ-line (strcat "  mismatching dimensions: " (itoa mismatch-count)))
  (setq result
    (cond
      ((= (length expected-values) 0) "MISSING_TITLE_SCALE")
      ((= dim-total 0) "NO_DIMENSIONS")
      ((= mismatch-count 0) "OK_DIMLFAC_MATCH")
      ((> match-count 0) "MIXED_DIMLFAC")
      (T "CONFLICT_DIMLFAC")
    )
  )
  (swcad-title-princ-line (strcat "Result: " result))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(swcad-title-disable-legacy-public-commands)

(princ (strcat "\nswcad_title_scale 통합 흐름 로드 완료 " *swcad-title-scale-version*))
(princ "\n권장 흐름: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERTNEXT, SWTITLEVERIFY")
(princ "\n수동 응답을 직접 고를 때만 SWTITLECONVERT를 사용하세요.")
(princ "\n중요: 변환 전에는 SWTITLESTATUS 결과가 안내한 다음 명령만 실행하세요.")
(princ "\n금지: CAD 명령줄에 GMTITLE, TIT, 일반 OPEN을 직접 입력해 우회하지 마세요.")
(princ "\n예전 SWTITLE transfer/fast/A3A4/frame-only 공개 명령은 비활성화됩니다.")
(princ)
