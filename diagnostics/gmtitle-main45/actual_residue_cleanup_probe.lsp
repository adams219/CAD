;;; Actual copied-DWG probe for the public SWTITLEPREPARE residue cleanup.
;;; The PowerShell runner opens a dedicated work copy through COM, loads this
;;; file, and queues one YES response for SWTITLEPREPARE.

(vl-load-com)

(defun swtitle-actual-clean-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-actual-clean-write-line (handle value)
  (write-line (if value (swcad-title-string value) "") handle)
)

(defun swtitle-actual-clean-result-from-log (path / handle line result code)
  (setq result "<missing>")
  (setq handle (open path "r"))
  (if handle
    (progn
      (while (setq line (read-line handle))
        (foreach code
          '(
            "OK_FRAME_STYLE_NORMALIZATION_CLEANED"
            "OK_NO_FRAME_STYLE_NORMALIZATION"
            "WARN_RESIDUE_REMAINS"
            "WARN_FRAME_STYLE_RESIDUE_UNCLASSIFIED"
            "ABORT_FRAME_STYLE_NORMALIZATION_USER"
            "ERROR_FRAME_STYLE_NORMALIZATION_CLEAN"
          )
          (if (vl-string-search code line)
            (setq result code)
          )
        )
      )
      (close handle)
    )
  )
  result
)

(defun swtitle-actual-clean-pair-signature (/ records result record title frame title-role frame-role attr-count title-kinds frame-kinds)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (setq title (car record))
    (setq frame (cadr record))
    (setq title-role (nth 5 record))
    (setq frame-role (nth 6 record))
    (setq attr-count (swcad-title-target-pair-nonempty-attr-count record))
    (setq title-kinds (swcad-title-native-link-target-kinds title))
    (setq frame-kinds (swcad-title-native-link-target-kinds frame))
    (setq result
      (append
        result
        (list
          (strcat
            (swcad-title-ename-handle title)
            "/"
            (swcad-title-ename-handle frame)
            ":"
            (swcad-title-string title-role)
            "/"
            (swcad-title-string frame-role)
            ":attrs="
            (itoa attr-count)
            ":title-links="
            (swcad-title-list-string title-kinds)
            ":frame-links="
            (swcad-title-list-string frame-kinds)
          )
        )
      )
    )
  )
  result
)

(defun swtitle-actual-clean-native-like-count (/ records count record)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq count 0)
  (foreach record records
    (if (swcad-title-target-pair-native-like-p record)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swtitle-actual-clean-main (/ root lsp-path log-path handle load-result load-ok version core-only before-style before-clean before-independent before-protected before-pairs before-native before-signature before-frames before-titles before-orphans prepare-result first-clean-log first-clean-status after-style after-clean after-independent after-pairs after-native after-signature after-frames after-titles after-orphans second-result second-clean-status final-style final-clean final-independent final-pairs final-native final-signature final-frames final-titles final-orphans status-result status-value)
  (setq root (swtitle-actual-clean-env-path "SWCAD_TOOL_ROOT" "C:/Users/DR-DESIGN/Documents/CAD tool"))
  (setq lsp-path
    (swtitle-actual-clean-env-path
      "SWCAD_COMPARE_LSP"
      (strcat root "/src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq log-path
    (swtitle-actual-clean-env-path
      "SWCAD_COMPARE_LOG"
      (strcat root "/work/swtitle_actual_residue_cleanup_probe_260711.txt")
    )
  )
  (setq load-result (vl-catch-all-apply 'load (list lsp-path)))
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq version
    (if (and load-ok (boundp '*swcad-title-scale-version*))
      *swcad-title-scale-version*
      "<missing>"
    )
  )
  (setq core-only (equal (getenv "SWCAD_ACTUAL_CLEAN_CORE_ONLY") "1"))
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (swtitle-actual-clean-write-line handle "SWTITLE actual residue cleanup copied-DWG probe")
      (swtitle-actual-clean-write-line handle (strcat "LSP path: " lsp-path))
      (swtitle-actual-clean-write-line handle (strcat "Load result: " (if load-ok "OK" "ERROR")))
      (swtitle-actual-clean-write-line handle (strcat "Loaded version: " version))
      (swtitle-actual-clean-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-actual-clean-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (close handle)
    )
  )
  (if load-ok
    (progn
      (setq before-style (length (swcad-title-frame-style-normalization-records)))
      (setq before-clean (length (swcad-title-frame-style-normalization-entity-records)))
      (setq before-independent (length (swcad-title-frame-style-independent-residue-records)))
      (setq before-protected (length (swcad-title-frame-style-protected-records)))
      (setq before-pairs (length (swcad-title-target-gmtitle-pair-records)))
      (setq before-native (swtitle-actual-clean-native-like-count))
      (setq before-signature (swtitle-actual-clean-pair-signature))
      (setq before-frames (length (swcad-title-frame-records)))
      (setq before-titles (length (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name))))
      (setq before-orphans (length (swcad-title-orphan-target-frame-records)))

      (setq prepare-result
        (vl-catch-all-apply
          (if core-only 'swcad-title-frame-style-normalization-clean 'c:SWTITLEPREPARE)
          nil
        )
      )
      (setq first-clean-log (swcad-title-work-log-path "swcad_title_frame_style_normalization_clean_last.txt"))
      (setq first-clean-status (swtitle-actual-clean-result-from-log first-clean-log))

      (setq after-style (length (swcad-title-frame-style-normalization-records)))
      (setq after-clean (length (swcad-title-frame-style-normalization-entity-records)))
      (setq after-independent (length (swcad-title-frame-style-independent-residue-records)))
      (setq after-pairs (length (swcad-title-target-gmtitle-pair-records)))
      (setq after-native (swtitle-actual-clean-native-like-count))
      (setq after-signature (swtitle-actual-clean-pair-signature))
      (setq after-frames (length (swcad-title-frame-records)))
      (setq after-titles (length (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name))))
      (setq after-orphans (length (swcad-title-orphan-target-frame-records)))

      (setq second-result (vl-catch-all-apply 'swcad-title-frame-style-normalization-clean nil))
      (setq second-clean-status (swtitle-actual-clean-result-from-log first-clean-log))
      (setq final-style (length (swcad-title-frame-style-normalization-records)))
      (setq final-clean (length (swcad-title-frame-style-normalization-entity-records)))
      (setq final-independent (length (swcad-title-frame-style-independent-residue-records)))
      (setq final-pairs (length (swcad-title-target-gmtitle-pair-records)))
      (setq final-native (swtitle-actual-clean-native-like-count))
      (setq final-signature (swtitle-actual-clean-pair-signature))
      (setq final-frames (length (swcad-title-frame-records)))
      (setq final-titles (length (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name))))
      (setq final-orphans (length (swcad-title-orphan-target-frame-records)))

      (setq status-result (vl-catch-all-apply 'c:SWTITLESTATUS nil))
      (setq status-value
        (if (boundp '*swcad-title-last-apply-status*)
          (swcad-title-string *swcad-title-last-apply-status*)
          "<missing>"
        )
      )

      (setq handle (open log-path "a"))
      (if handle
        (progn
          (swtitle-actual-clean-write-line handle (strcat "Before style pairs: " (itoa before-style)))
          (swtitle-actual-clean-write-line handle (strcat "Cleanup mode: " (if core-only "core-only" "public-prepare")))
          (swtitle-actual-clean-write-line handle (strcat "Before clean candidates: " (itoa before-clean)))
          (swtitle-actual-clean-write-line handle (strcat "Before independent residue: " (itoa before-independent)))
          (swtitle-actual-clean-write-line handle (strcat "Before protected entities: " (itoa before-protected)))
          (swtitle-actual-clean-write-line handle (strcat "Before target/native-like pairs: " (itoa before-pairs) "/" (itoa before-native)))
          (swtitle-actual-clean-write-line handle (strcat "Before target frames/titles/orphans: " (itoa before-frames) "/" (itoa before-titles) "/" (itoa before-orphans)))
          (swtitle-actual-clean-write-line handle (strcat "First cleanup call: " (if (vl-catch-all-error-p prepare-result) (strcat "ERROR - " (vl-catch-all-error-message prepare-result)) "OK")))
          (swtitle-actual-clean-write-line handle (strcat "First cleanup status: " first-clean-status))
          (swtitle-actual-clean-write-line handle (strcat "After style pairs: " (itoa after-style)))
          (swtitle-actual-clean-write-line handle (strcat "After clean candidates: " (itoa after-clean)))
          (swtitle-actual-clean-write-line handle (strcat "After independent residue: " (itoa after-independent)))
          (swtitle-actual-clean-write-line handle (strcat "After target/native-like pairs: " (itoa after-pairs) "/" (itoa after-native)))
          (swtitle-actual-clean-write-line handle (strcat "After target frames/titles/orphans: " (itoa after-frames) "/" (itoa after-titles) "/" (itoa after-orphans)))
          (swtitle-actual-clean-write-line handle (strcat "Pair signature unchanged after first cleanup: " (if (equal before-signature after-signature) "yes" "no")))
          (swtitle-actual-clean-write-line handle (strcat "Second cleanup call: " (if (vl-catch-all-error-p second-result) (strcat "ERROR - " (vl-catch-all-error-message second-result)) "OK")))
          (swtitle-actual-clean-write-line handle (strcat "Second cleanup status: " second-clean-status))
          (swtitle-actual-clean-write-line handle (strcat "Final style pairs: " (itoa final-style)))
          (swtitle-actual-clean-write-line handle (strcat "Final clean candidates: " (itoa final-clean)))
          (swtitle-actual-clean-write-line handle (strcat "Final independent residue: " (itoa final-independent)))
          (swtitle-actual-clean-write-line handle (strcat "Final target/native-like pairs: " (itoa final-pairs) "/" (itoa final-native)))
          (swtitle-actual-clean-write-line handle (strcat "Final target frames/titles/orphans: " (itoa final-frames) "/" (itoa final-titles) "/" (itoa final-orphans)))
          (swtitle-actual-clean-write-line handle (strcat "Pair signature unchanged after second cleanup: " (if (equal before-signature final-signature) "yes" "no")))
          (swtitle-actual-clean-write-line handle (strcat "SWTITLESTATUS call: " (if (vl-catch-all-error-p status-result) (strcat "ERROR - " (vl-catch-all-error-message status-result)) "OK")))
          (swtitle-actual-clean-write-line handle (strcat "Status after cleanup: " status-value))
          (swtitle-actual-clean-write-line handle "Runtime check completed: yes")
          (close handle)
        )
      )
    )
  )
  (princ)
)

(swtitle-actual-clean-main)
