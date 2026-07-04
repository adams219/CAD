;;; Read-only probe for the SWTITLECONVERT SCRIPT-mode guard.
;;; The PowerShell wrapper sets:
;;;   SWCAD_TOOL_ROOT
;;;   SWCAD_COMPARE_LOG
;;; This script modifies only the copied probe DWG in memory and does not save it.

(vl-load-com)

(defun swtitle-convertguard-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-convertguard-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-convertguard-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-convertguard-insert-count (/ ss)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (if ss (sslength ss) 0)
)

(defun swtitle-convertguard-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<missing>"
  )
)

(defun swtitle-convertguard-main (/ root lsp-path log-path handle load-result load-ok version-value script-active-before summary-before source-before frame-before frame-only-before target-title-before target-frame-before insert-before dbmod-before convert-result status-after summary-after source-after frame-after frame-only-after target-title-after target-frame-after insert-after dbmod-after pass)
  (setq root (swtitle-convertguard-root))
  (setq lsp-path (strcat root "/src/tools/gmtitle/swcad_title_scale.lsp"))
  (setq log-path
    (swtitle-convertguard-env-path
      "SWCAD_COMPARE_LOG"
      (strcat root "/work/swtitle_convert_script_guard_probe.txt")
    )
  )
  (setq load-result (vl-catch-all-apply 'load (list lsp-path)))
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq version-value
    (if (boundp '*swcad-title-scale-version*)
      *swcad-title-scale-version*
      "<version variable missing>"
    )
  )
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (swtitle-convertguard-write-line handle "SWTITLECONVERT script guard probe")
      (swtitle-convertguard-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-convertguard-write-line handle "Load result: OK")
        (swtitle-convertguard-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-convertguard-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-convertguard-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-convertguard-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (if load-ok
        (progn
          (setq *swcad-title-log-file-suffix* "_convert_script_guard_probe")
          (setq script-active-before (swcad-title-script-active-p))
          (setq summary-before (swcad-title-fast-sheet-summary))
          (setq source-before (swcad-title-fast-summary-value summary-before "source-title-count"))
          (setq frame-before (swcad-title-fast-summary-value summary-before "source-frame-count"))
          (setq frame-only-before (swcad-title-fast-summary-value summary-before "frame-only-count"))
          (setq target-title-before (swcad-title-count-inserts-by-effective-name (swcad-title-target-title-block-name)))
          (setq target-frame-before
            (+
              (swcad-title-count-inserts-by-effective-name "DR_A2_Outline")
              (swcad-title-count-inserts-by-effective-name "DR_A3_Outline")
              (swcad-title-count-inserts-by-effective-name "DR_A4_Outline")
            )
          )
          (setq insert-before (swtitle-convertguard-insert-count))
          (setq dbmod-before (getvar "DBMOD"))
          (setq convert-result (vl-catch-all-apply 'c:SWTITLECONVERT nil))
          (setq status-after (swtitle-convertguard-status-value))
          (setq summary-after (swcad-title-fast-sheet-summary))
          (setq source-after (swcad-title-fast-summary-value summary-after "source-title-count"))
          (setq frame-after (swcad-title-fast-summary-value summary-after "source-frame-count"))
          (setq frame-only-after (swcad-title-fast-summary-value summary-after "frame-only-count"))
          (setq target-title-after (swcad-title-count-inserts-by-effective-name (swcad-title-target-title-block-name)))
          (setq target-frame-after
            (+
              (swcad-title-count-inserts-by-effective-name "DR_A2_Outline")
              (swcad-title-count-inserts-by-effective-name "DR_A3_Outline")
              (swcad-title-count-inserts-by-effective-name "DR_A4_Outline")
            )
          )
          (setq insert-after (swtitle-convertguard-insert-count))
          (setq dbmod-after (getvar "DBMOD"))
          (if (vl-catch-all-error-p convert-result)
            (swtitle-convertguard-write-line handle (strcat "SWTITLECONVERT result: ERROR - " (vl-catch-all-error-message convert-result)))
            (swtitle-convertguard-write-line handle "SWTITLECONVERT result: OK")
          )
          (swtitle-convertguard-write-line handle (strcat "Script active before convert: " (if script-active-before "yes" "no")))
          (swtitle-convertguard-write-line handle (strcat "Status after convert: " status-after))
          (swtitle-convertguard-write-line handle (strcat "Source titles before/after: " (itoa source-before) "/" (itoa source-after)))
          (swtitle-convertguard-write-line handle (strcat "Source frames before/after: " (itoa frame-before) "/" (itoa frame-after)))
          (swtitle-convertguard-write-line handle (strcat "Frame-only before/after: " (itoa frame-only-before) "/" (itoa frame-only-after)))
          (swtitle-convertguard-write-line handle (strcat "Target titles before/after: " (itoa target-title-before) "/" (itoa target-title-after)))
          (swtitle-convertguard-write-line handle (strcat "Target frames before/after: " (itoa target-frame-before) "/" (itoa target-frame-after)))
          (swtitle-convertguard-write-line handle (strcat "INSERT count before/after: " (itoa insert-before) "/" (itoa insert-after)))
          (swtitle-convertguard-write-line handle (strcat "DBMOD before/after: " (itoa dbmod-before) "/" (itoa dbmod-after)))
          (setq pass
            (and
              script-active-before
              (equal status-after "ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE")
              (= source-before source-after)
              (= frame-before frame-after)
              (= frame-only-before frame-only-after)
              (= target-title-before target-title-after)
              (= target-frame-before target-frame-after)
              (= insert-before insert-after)
              (= dbmod-before dbmod-after)
            )
          )
          (swtitle-convertguard-write-line handle (strcat "Convert script guard preserved drawing: " (if pass "yes" "no")))
        )
      )
      (swtitle-convertguard-write-line handle "Runtime check completed: yes")
      (close handle)
    )
  )
  (princ)
)

(swtitle-convertguard-main)
