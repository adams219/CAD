;;; A4 frame-only DR_A4_Outline conversion probe.
;;; The PowerShell wrapper sets SWCAD_TOOL_ROOT and SWCAD_A4_OUTLINE_CONVERT_LOG.
;;; This probe runs on a copied DWG and does not save the drawing.
;;; Expected final status: FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER.

(defun swtitle-a4convert-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-a4convert-path (relative)
  (strcat (swtitle-a4convert-root) "/" relative)
)

(defun swtitle-a4convert-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-a4convert-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<status variable missing>"
  )
)

(defun swtitle-a4convert-count-line (handle label counts)
  (swtitle-a4convert-write-line handle label)
  (if counts
    (foreach item counts
      (swtitle-a4convert-write-line handle (strcat "  " (car item) ": " (itoa (cdr item))))
    )
    (swtitle-a4convert-write-line handle "  <none>")
  )
)

(defun swtitle-a4convert-count-target-title ()
  (length (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
)

(defun swtitle-a4convert-count-target-frame ()
  (length (swcad-title-inserts-by-effective-name "DR_A4_Outline"))
)

(defun swtitle-a4convert-run (/ log-path handle load-result load-ok before-summary before-target before-title-count before-frame-count prepare-result after-prepare-status convert-result after-summary after-target after-title-count after-frame-count)
  (setq log-path (getenv "SWCAD_A4_OUTLINE_CONVERT_LOG"))
  (if (or (not log-path) (= (strlen log-path) 0))
    (setq log-path (swtitle-a4convert-path "work/swtitle_a4_outline_convert_probe_260705.txt"))
  )
  (setq log-path (vl-string-translate "\\" "/" log-path))
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (swtitle-a4convert-write-line handle "SWTITLE A4 outline convert probe")
      (setq load-result
        (vl-catch-all-apply
          'load
          (list (swtitle-a4convert-path "src/tools/gmtitle/swcad_title_scale.lsp"))
        )
      )
      (setq load-ok (not (vl-catch-all-error-p load-result)))
      (if load-ok
        (progn
          (setq *swcad-title-debug-log-handle* handle)
          (setq *swcad-title-debug-log-path* log-path)
        )
      )
      (if load-ok
        (swtitle-a4convert-write-line handle "Load result: OK")
        (swtitle-a4convert-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (if load-ok
        (progn
          (swtitle-a4convert-write-line handle (strcat "Loaded version: " *swcad-title-scale-version*))
          (swtitle-a4convert-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
          (swtitle-a4convert-write-line handle (strcat "CTAB: " (getvar "CTAB")))
          (swtitle-a4convert-write-line handle (strcat "DBMOD before commands: " (itoa (getvar "DBMOD"))))

          (setq before-summary (swcad-title-fast-sheet-summary))
          (setq before-target (swcad-title-target-frame-sheet-counts))
          (setq before-title-count (swtitle-a4convert-count-target-title))
          (setq before-frame-count (swtitle-a4convert-count-target-frame))
          (swtitle-a4convert-write-line handle (strcat "Before source-title-count: " (itoa (swcad-title-fast-summary-value before-summary "source-title-count"))))
          (swtitle-a4convert-write-line handle (strcat "Before frame-only-count: " (itoa (swcad-title-fast-summary-value before-summary "frame-only-count"))))
          (swtitle-a4convert-write-line handle (strcat "Before target title count: " (itoa before-title-count)))
          (swtitle-a4convert-write-line handle (strcat "Before DR_A4_Outline target frame count: " (itoa before-frame-count)))
          (swtitle-a4convert-count-line handle "Before target-sheet-counts:" before-target)

          (setq prepare-result
            (vl-catch-all-apply
              'swcad-title-prepare-a4-frame-only-outline-definition
              nil
            )
          )
          (if (vl-catch-all-error-p prepare-result)
            (swtitle-a4convert-write-line handle (strcat "Prepare result: ERROR - " (vl-catch-all-error-message prepare-result)))
            (swtitle-a4convert-write-line handle (strcat "Prepare result: OK status=" (swtitle-a4convert-status-value)))
          )
          (setq after-prepare-status (swcad-title-a4-frame-only-outline-definition-status))
          (swtitle-a4convert-write-line handle (strcat "After prepare definition status: " after-prepare-status))

          (setq convert-result
            (vl-catch-all-apply
              'swcad-title-transfer-a4-frame-only-outline-apply
              nil
            )
          )
          (if (vl-catch-all-error-p convert-result)
            (swtitle-a4convert-write-line handle (strcat "Convert result: ERROR - " (vl-catch-all-error-message convert-result)))
            (swtitle-a4convert-write-line handle (strcat "Convert result: OK status=" (swtitle-a4convert-status-value)))
          )

          (setq after-summary (swcad-title-fast-sheet-summary))
          (setq after-target (swcad-title-target-frame-sheet-counts))
          (setq after-title-count (swtitle-a4convert-count-target-title))
          (setq after-frame-count (swtitle-a4convert-count-target-frame))
          (swtitle-a4convert-write-line handle (strcat "After source-title-count: " (itoa (swcad-title-fast-summary-value after-summary "source-title-count"))))
          (swtitle-a4convert-write-line handle (strcat "After frame-only-count: " (itoa (swcad-title-fast-summary-value after-summary "frame-only-count"))))
          (swtitle-a4convert-write-line handle (strcat "After target title count: " (itoa after-title-count)))
          (swtitle-a4convert-write-line handle (strcat "After DR_A4_Outline target frame count: " (itoa after-frame-count)))
          (swtitle-a4convert-count-line handle "After target-sheet-counts:" after-target)
          (swtitle-a4convert-write-line handle (strcat "DBMOD after commands: " (itoa (getvar "DBMOD"))))
        )
      )
      (swtitle-a4convert-write-line handle "Runtime check completed: yes")
      (setq *swcad-title-debug-log-handle* nil)
      (close handle)
    )
  )
  (princ)
)

(swtitle-a4convert-run)
