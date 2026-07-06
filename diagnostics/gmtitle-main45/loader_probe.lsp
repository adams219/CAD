;;; Tracked read-only loader probe for the main56 GMTITLE workflow.
;;; The PowerShell wrapper sets SWCAD_TOOL_ROOT and SWCAD_LOADER_PROBE_LOG.
;;; This script does not save the drawing.

(defun swtitle-loader-probe-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-loader-probe-path (relative)
  (strcat (swtitle-loader-probe-root) "/" relative)
)

(defun swtitle-loader-probe-log-path (/ log-path)
  (setq log-path (getenv "SWCAD_LOADER_PROBE_LOG"))
  (if (or (not log-path) (= (strlen log-path) 0))
    (setq log-path (swtitle-loader-probe-path "work/swtitle_loader_probe_main56_diagnostics.txt"))
  )
  (vl-string-translate "\\" "/" log-path)
)

(defun swtitle-loader-probe-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-loader-probe-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<status variable missing>"
  )
)

(defun swtitle-loader-probe-command-present-p (symbol-name / found symbol value)
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

(defun swtitle-loader-probe-command-line (handle symbol-name)
  (swtitle-loader-probe-write-line
    handle
    (strcat "Command " symbol-name ": " (if (swtitle-loader-probe-command-present-p symbol-name) "yes" "no"))
  )
)

(defun swtitle-loader-probe-run-command (handle label func / result)
  (swtitle-loader-probe-write-line handle (strcat "Run: " label))
  (setq result (vl-catch-all-apply func nil))
  (if (vl-catch-all-error-p result)
    (swtitle-loader-probe-write-line
      handle
      (strcat "Result: ERROR " label " - " (vl-catch-all-error-message result))
    )
    (swtitle-loader-probe-write-line
      handle
      (strcat "Result: OK " label " status=" (swtitle-loader-probe-status-value))
    )
  )
  (not (vl-catch-all-error-p result))
)

(defun swtitle-loader-probe-main (/ log-path handle load-result load-ok ok-version ok-status ok-verify)
  (setq load-result
    (vl-catch-all-apply
      'load
      (list (swtitle-loader-probe-path "swcad_load.lsp"))
    )
  )
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq log-path (swtitle-loader-probe-log-path))
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (swtitle-loader-probe-write-line handle "SWCAD loader main56 read-only probe")
      (if load-ok
        (swtitle-loader-probe-write-line handle "Load result: OK")
        (swtitle-loader-probe-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-loader-probe-write-line
        handle
        (strcat "Loaded loader version: " (if (boundp '*swcad-version*) *swcad-version* "<loader version missing>"))
      )
      (swtitle-loader-probe-write-line
        handle
        (strcat "Loaded GMTITLE version: " (if (boundp '*swcad-title-scale-version*) *swcad-title-scale-version* "<gmtitle version missing>"))
      )
      (swtitle-loader-probe-write-line handle "Expected loader version: 260706-loader-convert-next-response-guidance")
      (swtitle-loader-probe-write-line handle "Expected GMTITLE version: 260707-unified-title-missing-14")
      (swtitle-loader-probe-write-line
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
      (swtitle-loader-probe-write-line
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
      (swtitle-loader-probe-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-loader-probe-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (swtitle-loader-probe-command-line handle "c:SWTITLESTATUS")
      (swtitle-loader-probe-command-line handle "c:SWTITLEPREPARE")
      (swtitle-loader-probe-command-line handle "c:SWTITLECONVERT")
      (swtitle-loader-probe-command-line handle "c:SWTITLEVERIFY")
      (swtitle-loader-probe-command-line handle "c:SWTITLEVERSION")
      (swtitle-loader-probe-command-line handle "c:SWSCALESCAN")
      (swtitle-loader-probe-write-line handle "Legacy command disabled sample:")
      (swtitle-loader-probe-command-line handle "c:SWTITLEFASTSTATUS")
      (swtitle-loader-probe-command-line handle "c:SWTITLETRANSFERBOOTSTRAPFAST")
      (swtitle-loader-probe-command-line handle "c:SWTITLETRANSFERFASTBATCH")
      (swtitle-loader-probe-command-line handle "c:SWTITLEFRAMEONLYAPPLY")
      (swtitle-loader-probe-command-line handle "c:SWTITLEA3A4NEXT")
      (swtitle-loader-probe-command-line handle "c:SWTITLEA3A4ALL")
      (swtitle-loader-probe-command-line handle "c:SWTITLEGMTITLEVERIFYALL")
      (if load-ok
        (progn
          (setq ok-version (swtitle-loader-probe-run-command handle "SWTITLEVERSION" 'c:SWTITLEVERSION))
          (setq ok-status
            (if (swtitle-loader-probe-command-present-p "c:SWTITLESTATUS")
              (swtitle-loader-probe-run-command handle "SWTITLESTATUS" 'c:SWTITLESTATUS)
              nil
            )
          )
          (setq ok-verify
            (if (swtitle-loader-probe-command-present-p "c:SWTITLEVERIFY")
              (swtitle-loader-probe-run-command handle "SWTITLEVERIFY" 'c:SWTITLEVERIFY)
              nil
            )
          )
        )
        (progn
          (setq ok-version nil)
          (setq ok-status nil)
          (setq ok-verify nil)
        )
      )
      (swtitle-loader-probe-write-line
        handle
        (strcat "Runtime check completed: " (if (and ok-version ok-status ok-verify) "yes" "no"))
      )
      (close handle)
    )
  )
  (princ)
)

(swtitle-loader-probe-main)
