;;; Tracked read-only status/verify probe for a copied actual work DWG.
;;; The PowerShell wrapper sets SWCAD_TOOL_ROOT before launching GstarCAD.
;;; This script does not save the drawing.

(defun swtitle-diag45-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-diag45-path (relative)
  (strcat (swtitle-diag45-root) "/" relative)
)

(defun swtitle-diag45-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-diag45-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<status variable missing>"
  )
)

(defun swtitle-diag45-run-command (handle label func / result)
  (swtitle-diag45-write-line handle (strcat "Run: " label))
  (setq result (vl-catch-all-apply func nil))
  (if (vl-catch-all-error-p result)
    (swtitle-diag45-write-line
      handle
      (strcat "Result: ERROR " label " - " (vl-catch-all-error-message result))
    )
    (swtitle-diag45-write-line
      handle
      (strcat "Result: OK " label " status=" (swtitle-diag45-status-value))
    )
  )
  (not (vl-catch-all-error-p result))
)

(defun swtitle-diag45-count-line (handle label counts)
  (swtitle-diag45-write-line handle label)
  (if counts
    (foreach item counts
      (swtitle-diag45-write-line handle (strcat "  " (car item) ": " (itoa (cdr item))))
    )
    (swtitle-diag45-write-line handle "  <none>")
  )
)

(defun swtitle-diag45-file-contains-p (path pattern / file line found)
  (setq found nil)
  (if (and path (findfile path))
    (progn
      (setq file (open path "r"))
      (if file
        (progn
          (while (and (not found) (setq line (read-line file)))
            (if (vl-string-search pattern line)
              (setq found T)
            )
          )
          (close file)
        )
      )
    )
  )
  found
)

(defun swtitle-diag45-env-or-default (name default / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    default
    value
  )
)

(defun swtitle-diag45-main (/ log-path env-log-path handle load-result load-ok version-value old-log-suffix requested-log-suffix ok-version ok-status status-after-status ok-verify status-after-verify summary source-count source-frame-count frame-only-count expected-counts target-counts blockers embedded-records title-count frame-count bootstrap-record bootstrap-sheet bootstrap-frame bootstrap-title missing-native-frames first-native-guidance-ok verify-summary-log verify-source-priority verify-a4-first)
  (setq load-result
    (vl-catch-all-apply
      'load
      (list (swtitle-diag45-path "src/tools/gmtitle/swcad_title_scale.lsp"))
    )
  )
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq version-value
    (if (boundp '*swcad-title-scale-version*)
      *swcad-title-scale-version*
      "<version variable missing>"
    )
  )
  (setq old-log-suffix
    (if (boundp '*swcad-title-log-file-suffix*)
      *swcad-title-log-file-suffix*
      nil
    )
  )
  (setq requested-log-suffix
    (swtitle-diag45-env-or-default
      "SWCAD_ACTUAL_WORKCOPY_LOG_SUFFIX"
      "_actual_workcopy_main56_diagnostics"
    )
  )
  (if load-ok
    (setq *swcad-title-log-file-suffix* requested-log-suffix)
  )
  (setq env-log-path (getenv "SWCAD_ACTUAL_WORKCOPY_STATUS_LOG"))
  (if (and env-log-path (> (strlen env-log-path) 0))
    (setq log-path (vl-string-translate "\\" "/" env-log-path))
    (setq log-path (swtitle-diag45-path "work/swtitle_actual_workcopy_status_main56_diagnostics.txt"))
  )
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (swtitle-diag45-write-line handle "SWTITLE main56 actual workcopy read-only status probe")
      (if load-ok
        (swtitle-diag45-write-line handle "Load result: OK")
        (swtitle-diag45-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-diag45-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-diag45-write-line handle "Expected version: 260705-verify-source-priority")
      (swtitle-diag45-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-diag45-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (swtitle-diag45-write-line handle (strcat "DBMOD before commands: " (itoa (getvar "DBMOD"))))
      (swtitle-diag45-write-line handle "Commands requested: SWTITLEVERSION, SWTITLESTATUS, SWTITLEVERIFY")
      (swtitle-diag45-write-line handle (strcat "Detail log suffix: " requested-log-suffix))
      (if load-ok
        (progn
          (setq ok-version (swtitle-diag45-run-command handle "SWTITLEVERSION" 'c:SWTITLEVERSION))
          (setq ok-status (swtitle-diag45-run-command handle "SWTITLESTATUS" 'c:SWTITLESTATUS))
          (setq status-after-status (swtitle-diag45-status-value))
          (setq summary (swcad-title-fast-sheet-summary))
          (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
          (setq source-frame-count (swcad-title-fast-summary-value summary "source-frame-count"))
          (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
          (setq expected-counts (swcad-title-current-total-sheet-counts summary))
          (setq target-counts (swcad-title-target-frame-sheet-counts))
          (setq blockers (swcad-title-frame-definition-blocking-records))
          (setq embedded-records (swcad-title-frame-embedded-title-records))
          (setq bootstrap-record (swcad-title-next-bootstrap-selection-record))
          (setq bootstrap-sheet (if bootstrap-record (car bootstrap-record) "<none>"))
          (setq bootstrap-frame (if bootstrap-record (cadr bootstrap-record) "<none>"))
          (setq bootstrap-title (if bootstrap-record (caddr bootstrap-record) "<none>"))
          (setq missing-native-frames (swcad-title-missing-required-native-frame-blocks summary))
          (setq first-native-guidance-ok
            (and
              (equal status-after-status "NEXT_CREATE_FIRST_NATIVE_GMTITLE")
              (equal bootstrap-sheet "A2")
              (equal bootstrap-frame "DR_A2_Outline")
              (equal bootstrap-title "DR_titlea_3rd")
            )
          )
          (setq title-count (swcad-title-count-inserts-by-effective-name (swcad-title-target-title-block-name)))
          (setq frame-count
            (+
              (swcad-title-count-inserts-by-effective-name "DR_A2_Outline")
              (swcad-title-count-inserts-by-effective-name "DR_A3_Outline")
              (swcad-title-count-inserts-by-effective-name "DR_A4_Outline")
            )
          )
          (setq ok-verify (swtitle-diag45-run-command handle "SWTITLEVERIFY" 'c:SWTITLEVERIFY))
          (setq status-after-verify (swtitle-diag45-status-value))
          (setq verify-summary-log (swcad-title-work-log-path "swcad_title_verify_summary_last.txt"))
          (setq verify-source-priority
            (swtitle-diag45-file-contains-p
              verify-summary-log
              "SOURCE_SHEETS_BEFORE_A4_FRAME_ONLY"
            )
          )
          (setq verify-a4-first
            (swtitle-diag45-file-contains-p
              verify-summary-log
              "A4_FRAME_ONLY_AFTER_SOURCES"
            )
          )
          (swtitle-diag45-write-line handle "Summary after SWTITLESTATUS:")
          (swtitle-diag45-write-line handle (strcat "  source-title-count: " (itoa source-count)))
          (swtitle-diag45-write-line handle (strcat "  source-frame-count: " (itoa source-frame-count)))
          (swtitle-diag45-write-line handle (strcat "  frame-only-count: " (itoa frame-only-count)))
          (swtitle-diag45-write-line handle (strcat "  target-title-count: " (itoa title-count)))
          (swtitle-diag45-write-line handle (strcat "  target-frame-count: " (itoa frame-count)))
          (swtitle-diag45-write-line handle (strcat "  verify-summary-log: " verify-summary-log))
          (swtitle-diag45-write-line handle (strcat "  verify-source-priority-note-found: " (if verify-source-priority "yes" "no")))
          (swtitle-diag45-write-line handle (strcat "  verify-a4-frame-only-first-note-found: " (if verify-a4-first "yes" "no")))
          (swtitle-diag45-write-line handle (strcat "  frame-definition-blockers: " (itoa (length blockers))))
          (swtitle-diag45-write-line handle (strcat "  frame-embedded-cleanup-records: " (itoa (length embedded-records))))
          (swtitle-diag45-write-line handle (strcat "  next-bootstrap-source-sheet: " bootstrap-sheet))
          (swtitle-diag45-write-line handle (strcat "  next-bootstrap-frame: " bootstrap-frame))
          (swtitle-diag45-write-line handle (strcat "  next-bootstrap-title: " bootstrap-title))
          (if missing-native-frames
            (foreach frame-block missing-native-frames
              (swtitle-diag45-write-line handle (strcat "  missing-native-frame: " frame-block))
            )
            (swtitle-diag45-write-line handle "  missing-native-frame: <none>")
          )
          (swtitle-diag45-write-line handle (strcat "  first-native-guidance-ok: " (if first-native-guidance-ok "yes" "no")))
          (swtitle-diag45-count-line handle "  expected-sheet-counts:" expected-counts)
          (swtitle-diag45-count-line handle "  target-sheet-counts:" target-counts)
          (swtitle-diag45-write-line handle (strcat "  status-after-status: " status-after-status))
          (swtitle-diag45-write-line handle (strcat "  status-after-verify: " status-after-verify))
          (swtitle-diag45-write-line handle (strcat "  dbmod-after-commands: " (itoa (getvar "DBMOD"))))
        )
        (progn
          (setq ok-version nil)
          (setq ok-status nil)
          (setq ok-verify nil)
        )
      )
      (swtitle-diag45-write-line
        handle
        (strcat "Runtime check completed: " (if (and ok-version ok-status ok-verify) "yes" "no"))
      )
      (close handle)
    )
  )
  (if load-ok
    (setq *swcad-title-log-file-suffix* old-log-suffix)
  )
  (princ)
)

(swtitle-diag45-main)
