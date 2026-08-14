;;; Read-only guard probe for accidental CAD command text.
;;;
;;; The PowerShell wrapper sets:
;;;   SWCAD_TOOL_ROOT
;;;   SWCAD_GUARD_LSP
;;;   SWCAD_GUARD_LABEL
;;;   SWCAD_GUARD_LOG
;;;
;;; The probe loads an LSP copy, counts accidental command text, then stubs
;;; modifying conversion helpers before calling the integrated convert
;;; dispatcher. If the dispatcher is safe, it aborts before any stubbed
;;; conversion path is reached.

(defun swtitle-guard-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-guard-path (relative)
  (strcat (swtitle-guard-root) "/" relative)
)

(defun swtitle-guard-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-guard-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-guard-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<status variable missing>"
  )
)

(defun swtitle-guard-command-present-p (symbol-name / found symbol value)
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

(defun swtitle-guard-stub-action (name)
  (setq *swtitle-guard-danger-action* name)
  (if (swtitle-guard-command-present-p "SWCAD-TITLE-APPLY-RESULT")
    (swcad-title-apply-result (strcat "STUB_" name))
  )
  (princ)
)

(defun swtitle-guard-install-stubs ()
  (setq *swtitle-guard-danger-action* "<none>")
  (defun swcad-title-script-active-p () nil)
  (defun swcad-title-transfer-fast-batch () (swtitle-guard-stub-action "TRANSFER_FAST_BATCH"))
  (defun swcad-title-transfer-bootstrap-fast () (swtitle-guard-stub-action "TRANSFER_BOOTSTRAP_FAST"))
  (defun swcad-title-transfer-frame-only-apply () (swtitle-guard-stub-action "TRANSFER_FRAME_ONLY_APPLY"))
  (defun swcad-title-upgrade-native-a3a4-next () (swtitle-guard-stub-action "UPGRADE_NATIVE_A3A4_NEXT"))
  (defun swcad-title-command-text-clean-safe () (swtitle-guard-stub-action "COMMAND_TEXT_CLEAN_SAFE"))
  (princ)
)

(defun swtitle-guard-add-command-text-fixture (/ ename)
  (setq ename
    (entmakex
      (list
        (cons 0 "TEXT")
        (cons 8 "0")
        (list 10 -1000.0 -1000.0 0.0)
        (cons 40 2.5)
        (cons 1 "SWTITLECONVERT")
        (cons 7 "Standard")
        (cons 50 0.0)
      )
    )
  )
  ename
)

(defun swtitle-guard-main (/ lsp-path log-path label handle load-result load-ok version-value command-count structure-next status-result convert-result)
  (setq lsp-path
    (swtitle-guard-env-path
      "SWCAD_GUARD_LSP"
      (swtitle-guard-path "src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq log-path
    (swtitle-guard-env-path
      "SWCAD_GUARD_LOG"
      (swtitle-guard-path "work/swtitle_command_text_guard_compare_probe.txt")
    )
  )
  (setq label (getenv "SWCAD_GUARD_LABEL"))
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
      (swtitle-guard-write-line handle "SWTITLE command-text guard comparison probe")
      (swtitle-guard-write-line handle (strcat "Label: " label))
      (swtitle-guard-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-guard-write-line handle "Load result: OK")
        (swtitle-guard-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-guard-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-guard-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (if load-ok
        (progn
          (swtitle-guard-add-command-text-fixture)
          (setq command-count
            (if (swtitle-guard-command-present-p "SWCAD-TITLE-COMMAND-TEXT-RESIDUE-COUNT")
              (swcad-title-command-text-residue-count)
              -1
            )
          )
          (swtitle-guard-write-line handle (strcat "command-text-count-before: " (itoa command-count)))
          (setq status-result
            (if (swtitle-guard-command-present-p "C:SWTITLESTATUS")
              (vl-catch-all-apply 'c:SWTITLESTATUS nil)
              (vl-catch-all-apply 'swcad-title-integrated-structure-diagnosis nil)
            )
          )
          (if (vl-catch-all-error-p status-result)
            (swtitle-guard-write-line handle (strcat "SWTITLESTATUS result: ERROR - " (vl-catch-all-error-message status-result)))
            (swtitle-guard-write-line handle (strcat "SWTITLESTATUS result: OK status=" (swtitle-guard-status-value)))
          )
          (setq structure-next
            (if (swtitle-guard-command-present-p "SWCAD-TITLE-INTEGRATED-STRUCTURE-DIAGNOSIS")
              (vl-catch-all-apply 'swcad-title-integrated-structure-diagnosis nil)
              nil
            )
          )
          (if (vl-catch-all-error-p structure-next)
            (swtitle-guard-write-line handle (strcat "structure-next-action: ERROR - " (vl-catch-all-error-message structure-next)))
            (swtitle-guard-write-line handle (strcat "structure-next-action: " (if structure-next structure-next "<nil>")))
          )
          (swtitle-guard-install-stubs)
          (setq convert-result
            (if (swtitle-guard-command-present-p "SWCAD-TITLE-INTEGRATED-CONVERT")
              (vl-catch-all-apply 'swcad-title-integrated-convert nil)
              nil
            )
          )
          (if (vl-catch-all-error-p convert-result)
            (swtitle-guard-write-line handle (strcat "convert-dispatch-result: ERROR - " (vl-catch-all-error-message convert-result)))
            (swtitle-guard-write-line handle "convert-dispatch-result: OK")
          )
          (swtitle-guard-write-line handle (strcat "convert-status-after: " (swtitle-guard-status-value)))
          (swtitle-guard-write-line handle (strcat "danger-action-after-convert: " *swtitle-guard-danger-action*))
        )
      )
      (swtitle-guard-write-line handle "Runtime check completed: yes")
      (close handle)
    )
  )
  (princ)
)

(swtitle-guard-main)
