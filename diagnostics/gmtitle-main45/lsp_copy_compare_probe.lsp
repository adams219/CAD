;;; Read-only probe for comparing copied GMTITLE LSP files.
;;; The PowerShell wrapper sets:
;;;   SWCAD_TOOL_ROOT
;;;   SWCAD_COMPARE_LSP
;;;   SWCAD_COMPARE_LABEL
;;;   SWCAD_COMPARE_LOG
;;; This script does not save the drawing.

(defun swtitle-copycmp-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-copycmp-path (relative)
  (strcat (swtitle-copycmp-root) "/" relative)
)

(defun swtitle-copycmp-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-copycmp-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-copycmp-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<status variable missing>"
  )
)

(defun swtitle-copycmp-command-present-p (symbol-name / found symbol value)
  (setq found (atoms-family 1 (list (strcase symbol-name))))
  (if found
    (progn
      (setq symbol (read symbol-name))
      (setq value (vl-catch-all-apply 'eval (list symbol)))
      (if (vl-catch-all-error-p value)
        nil
        (if value T nil)
      )
    )
    nil
  )
)

(defun swtitle-copycmp-command-line (handle symbol-name)
  (swtitle-copycmp-write-line
    handle
    (strcat "Command " symbol-name ": " (if (swtitle-copycmp-command-present-p symbol-name) "yes" "no"))
  )
)

(defun swtitle-copycmp-run-command-if-present (handle label symbol-name func / result)
  (if (not (swtitle-copycmp-command-present-p symbol-name))
    (progn
      (swtitle-copycmp-write-line handle (strcat "Run: " label))
      (swtitle-copycmp-write-line handle (strcat "Result: MISSING " label))
      nil
    )
    (progn
      (swtitle-copycmp-write-line handle (strcat "Run: " label))
      (setq result (vl-catch-all-apply func nil))
      (if (vl-catch-all-error-p result)
        (swtitle-copycmp-write-line
          handle
          (strcat "Result: ERROR " label " - " (vl-catch-all-error-message result))
        )
        (swtitle-copycmp-write-line
          handle
          (strcat "Result: OK " label " status=" (swtitle-copycmp-status-value))
        )
      )
      (not (vl-catch-all-error-p result))
    )
  )
)

(defun swtitle-copycmp-count-line (handle label counts)
  (swtitle-copycmp-write-line handle label)
  (if counts
    (foreach item counts
      (swtitle-copycmp-write-line handle (strcat "  " (car item) ": " (itoa (cdr item))))
    )
    (swtitle-copycmp-write-line handle "  <none>")
  )
)

(defun swtitle-copycmp-has-symbol-p (symbol-name)
  (swtitle-copycmp-command-present-p symbol-name)
)

(defun swtitle-copycmp-main (/ lsp-path log-path label handle load-result load-ok version-value ok-version ok-status ok-verify summary source-count source-frame-count frame-only-count expected-counts target-counts blockers embedded-records title-count frame-count)
  (setq lsp-path
    (swtitle-copycmp-env-path
      "SWCAD_COMPARE_LSP"
      (swtitle-copycmp-path "src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq log-path
    (swtitle-copycmp-env-path
      "SWCAD_COMPARE_LOG"
      (swtitle-copycmp-path "work/swtitle_lsp_copy_compare_probe.txt")
    )
  )
  (setq label (getenv "SWCAD_COMPARE_LABEL"))
  (if (or (not label) (= (strlen label) 0))
    (setq label "<unnamed>")
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
      (swtitle-copycmp-write-line handle "SWTITLE LSP copy comparison read-only probe")
      (swtitle-copycmp-write-line handle (strcat "Label: " label))
      (swtitle-copycmp-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-copycmp-write-line handle "Load result: OK")
        (swtitle-copycmp-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-copycmp-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-copycmp-write-line
        handle
        (strcat
          "Command-line -GMTITLE default enabled: "
          (if
            (and
              (boundp '*swcad-title-allow-commandline-gmtitle*)
              *swcad-title-allow-commandline-gmtitle*
            )
            "yes"
            "no"
          )
        )
      )
      (swtitle-copycmp-write-line
        handle
        (strcat
          "SCRIPT command-line -GMTITLE enabled: "
          (if
            (and
              (boundp '*swcad-title-allow-script-commandline-gmtitle*)
              *swcad-title-allow-script-commandline-gmtitle*
            )
            "yes"
            "no"
          )
        )
      )
      (swtitle-copycmp-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-copycmp-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (swtitle-copycmp-write-line handle "Runtime command presence, possibly affected by GstarCAD startup-loaded LSPs:")
      (swtitle-copycmp-write-line handle "Static LSP defun c: search is authoritative for public command surface.")
      (swtitle-copycmp-write-line handle "Four workflow commands:")
      (swtitle-copycmp-command-line handle "c:SWTITLESTATUS")
      (swtitle-copycmp-command-line handle "c:SWTITLEPREPARE")
      (swtitle-copycmp-command-line handle "c:SWTITLECONVERT")
      (swtitle-copycmp-command-line handle "c:SWTITLEVERIFY")
      (swtitle-copycmp-write-line handle "Legacy command runtime sample:")
      (swtitle-copycmp-command-line handle "c:SWTITLEFASTSTATUS")
      (swtitle-copycmp-command-line handle "c:SWTITLETRANSFERBOOTSTRAPFAST")
      (swtitle-copycmp-command-line handle "c:SWTITLETRANSFERFASTBATCH")
      (swtitle-copycmp-command-line handle "c:SWTITLEFRAMEONLYAPPLY")
      (swtitle-copycmp-command-line handle "c:SWTITLEA3A4NEXT")
      (swtitle-copycmp-command-line handle "c:SWTITLEA3A4ALL")
      (swtitle-copycmp-command-line handle "c:SWTITLEGMTITLEVERIFYALL")
      (if load-ok
        (progn
          (setq ok-version
            (swtitle-copycmp-run-command-if-present
              handle
              "SWTITLEVERSION"
              "c:SWTITLEVERSION"
              'c:SWTITLEVERSION
            )
          )
          (setq ok-status
            (swtitle-copycmp-run-command-if-present
              handle
              "SWTITLESTATUS"
              "c:SWTITLESTATUS"
              'c:SWTITLESTATUS
            )
          )
          (if (and ok-status (swtitle-copycmp-has-symbol-p "SWCAD-TITLE-FAST-SHEET-SUMMARY"))
            (progn
              (setq summary (swcad-title-fast-sheet-summary))
              (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
              (setq source-frame-count (swcad-title-fast-summary-value summary "source-frame-count"))
              (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
              (setq expected-counts (swcad-title-current-total-sheet-counts summary))
              (setq target-counts (swcad-title-target-frame-sheet-counts))
              (setq blockers
                (if (swtitle-copycmp-has-symbol-p "SWCAD-TITLE-FRAME-DEFINITION-BLOCKING-RECORDS")
                  (swcad-title-frame-definition-blocking-records)
                  nil
                )
              )
              (setq embedded-records
                (if (swtitle-copycmp-has-symbol-p "SWCAD-TITLE-FRAME-EMBEDDED-TITLE-RECORDS")
                  (swcad-title-frame-embedded-title-records)
                  nil
                )
              )
              (setq title-count
                (if (swtitle-copycmp-has-symbol-p "SWCAD-TITLE-COUNT-INSERTS-BY-EFFECTIVE-NAME")
                  (swcad-title-count-inserts-by-effective-name "DR_titlea_3rd")
                  0
                )
              )
              (setq frame-count
                (if (swtitle-copycmp-has-symbol-p "SWCAD-TITLE-COUNT-INSERTS-BY-EFFECTIVE-NAME")
                  (+
                    (swcad-title-count-inserts-by-effective-name "DR_A2_Outline")
                    (swcad-title-count-inserts-by-effective-name "DR_A3_Outline")
                    (swcad-title-count-inserts-by-effective-name "DR_A4_Outline")
                  )
                  0
                )
              )
              (swtitle-copycmp-write-line handle "Summary after SWTITLESTATUS:")
              (swtitle-copycmp-write-line handle (strcat "  source-title-count: " (itoa source-count)))
              (swtitle-copycmp-write-line handle (strcat "  source-frame-count: " (itoa source-frame-count)))
              (swtitle-copycmp-write-line handle (strcat "  frame-only-count: " (itoa frame-only-count)))
              (swtitle-copycmp-write-line handle (strcat "  target-title-count: " (itoa title-count)))
              (swtitle-copycmp-write-line handle (strcat "  target-frame-count: " (itoa frame-count)))
              (swtitle-copycmp-write-line handle (strcat "  frame-definition-blockers: " (itoa (length blockers))))
              (swtitle-copycmp-write-line handle (strcat "  frame-embedded-cleanup-records: " (itoa (length embedded-records))))
              (swtitle-copycmp-count-line handle "  expected-sheet-counts:" expected-counts)
              (swtitle-copycmp-count-line handle "  target-sheet-counts:" target-counts)
            )
            (swtitle-copycmp-write-line handle "Summary after SWTITLESTATUS: <unavailable>")
          )
          (setq ok-verify
            (swtitle-copycmp-run-command-if-present
              handle
              "SWTITLEVERIFY"
              "c:SWTITLEVERIFY"
              'c:SWTITLEVERIFY
            )
          )
        )
        (progn
          (setq ok-version nil)
          (setq ok-status nil)
          (setq ok-verify nil)
        )
      )
      (swtitle-copycmp-write-line
        handle
        (strcat "Runtime check completed: " (if (and ok-version ok-status ok-verify) "yes" "no"))
      )
      (close handle)
    )
  )
  (princ)
)

(swtitle-copycmp-main)
