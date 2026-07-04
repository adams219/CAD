;;; A4 frame-only DR_A4_Outline prepare probe.
;;; The PowerShell wrapper sets SWCAD_TOOL_ROOT and SWCAD_A4_PREPARE_LOG.
;;; This probe runs on a copied DWG and does not save the drawing.

(defun swtitle-a4prep-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-a4prep-path (relative)
  (strcat (swtitle-a4prep-root) "/" relative)
)

(defun swtitle-a4prep-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-a4prep-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<status variable missing>"
  )
)

(defun swtitle-a4prep-count-line (handle label counts)
  (swtitle-a4prep-write-line handle label)
  (if counts
    (foreach item counts
      (swtitle-a4prep-write-line handle (strcat "  " (car item) ": " (itoa (cdr item))))
    )
    (swtitle-a4prep-write-line handle "  <none>")
  )
)

(defun swtitle-a4prep-run (/ log-path handle load-result load-ok version before-status after-status before-counts after-counts before-target after-target prepare-result after-verify)
  (setq load-result
    (vl-catch-all-apply
      'load
      (list (swtitle-a4prep-path "src/tools/gmtitle/swcad_title_scale.lsp"))
    )
  )
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq log-path (getenv "SWCAD_A4_PREPARE_LOG"))
  (if (or (not log-path) (= (strlen log-path) 0))
    (setq log-path (swtitle-a4prep-path "work/swtitle_a4_outline_prepare_probe_260705.txt"))
  )
  (setq log-path (vl-string-translate "\\" "/" log-path))
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (setq *swcad-title-debug-log-handle* handle)
      (setq *swcad-title-debug-log-path* log-path)
      (swtitle-a4prep-write-line handle "SWTITLE A4 outline prepare probe")
      (if load-ok
        (swtitle-a4prep-write-line handle "Load result: OK")
        (swtitle-a4prep-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (if load-ok
        (progn
          (swtitle-a4prep-write-line handle (strcat "Loaded version: " *swcad-title-scale-version*))
          (swtitle-a4prep-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
          (swtitle-a4prep-write-line handle (strcat "CTAB: " (getvar "CTAB")))
          (setq before-status (swcad-title-a4-frame-only-outline-definition-status))
          (setq before-counts (swcad-title-fast-sheet-summary))
          (setq before-target (swcad-title-target-frame-sheet-counts))
          (swtitle-a4prep-write-line handle (strcat "Before definition status: " before-status))
          (swtitle-a4prep-write-line handle (strcat "Before frame-only-count: " (itoa (swcad-title-fast-summary-value before-counts "frame-only-count"))))
          (swtitle-a4prep-count-line handle "Before target-sheet-counts:" before-target)
          (setq prepare-result
            (vl-catch-all-apply
              'swcad-title-prepare-a4-frame-only-outline-definition
              nil
            )
          )
          (if (vl-catch-all-error-p prepare-result)
            (swtitle-a4prep-write-line handle (strcat "Prepare result: ERROR - " (vl-catch-all-error-message prepare-result)))
            (swtitle-a4prep-write-line handle (strcat "Prepare result: OK status=" (swtitle-a4prep-status-value)))
          )
          (setq after-status (swcad-title-a4-frame-only-outline-definition-status))
          (setq after-counts (swcad-title-fast-sheet-summary))
          (setq after-target (swcad-title-target-frame-sheet-counts))
          (swtitle-a4prep-write-line handle (strcat "After definition status: " after-status))
          (swtitle-a4prep-write-line handle (strcat "After frame-only-count: " (itoa (swcad-title-fast-summary-value after-counts "frame-only-count"))))
          (swtitle-a4prep-count-line handle "After target-sheet-counts:" after-target)
          (setq after-verify (vl-catch-all-apply 'swcad-title-native-frame-completion-check nil))
          (if (vl-catch-all-error-p after-verify)
            (swtitle-a4prep-write-line handle (strcat "Native check result: ERROR - " (vl-catch-all-error-message after-verify)))
            (swtitle-a4prep-write-line handle (strcat "Native check result: OK status=" (swtitle-a4prep-status-value)))
          )
        )
      )
      (swtitle-a4prep-write-line handle "Runtime check completed: yes")
      (setq *swcad-title-debug-log-handle* nil)
      (close handle)
    )
  )
  (princ)
)

(swtitle-a4prep-run)
