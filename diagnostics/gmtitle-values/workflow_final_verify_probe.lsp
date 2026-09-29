;;; Read-only probe: loads the SWCAD workflow and records the parts of SWCADVERIFY
;;; (the same calls as c:SWCADVERIFY) for a saved drawing. Nothing is changed.
;;; Environment: SWT_FINAL_LOG = log path, SWT_WORKFLOW_LOADER = swcad_workflow_load.lsp.

(vl-load-com)
(load (getenv "SWT_WORKFLOW_LOADER"))

(defun swt-final-yes (value) (if value "yes" "no"))

(defun swt-final-main (/ log xrefs wrappers dim-ok cleanup-ok frames layout-ok old-legacy title final-ok)
  (swapp-read-cache-begin)
  (swapp-activate-model)
  (setq xrefs (length (swapp-cached-top-xref-references)))
  (setq wrappers (length (swapp-sheet-wrapper-records)))
  (setq dim-ok (swapp-dimstyle-verify))
  (setq cleanup-ok (swapp-resource-cleanup-verify))
  (setq frames (length (swcad-title-frame-records)))
  (setq layout-ok (swapp-layout-state-valid-p frames))
  (setq old-legacy *swcad-title-legacy-count-compatibility-enabled*)
  (setq *swcad-title-legacy-count-compatibility-enabled*
    (and (= xrefs 0) (= wrappers 0) dim-ok cleanup-ok (> frames 0) layout-ok)
  )
  (setq title (vl-catch-all-apply 'swcad-title-integrated-verify-final-summary nil))
  (setq *swcad-title-legacy-count-compatibility-enabled* old-legacy)
  (if (vl-catch-all-error-p title) (setq title "ERROR"))
  (swapp-read-cache-end)
  (setq final-ok (and (= xrefs 0) (= wrappers 0) (equal title "OK") dim-ok cleanup-ok (> frames 0) layout-ok))
  (setq log (open (getenv "SWT_FINAL_LOG") "w"))
  (write-line (strcat "STAGE|" (swapp-workflow-stage)) log)
  (write-line (strcat "XREFS|" (itoa xrefs)) log)
  (write-line (strcat "WRAPPERS|" (itoa wrappers)) log)
  (write-line (strcat "TITLE|" (swcad-title-string title) "|" (swcad-title-string *swcad-title-last-apply-status*)) log)
  (write-line (strcat "DIMSTYLE|" (swt-final-yes dim-ok) "|" (swcad-title-string (swapp-state-value "DIMSTYLE")) "|" (swcad-title-string (swapp-state-value "DIMENSION_SEMANTICS"))) log)
  (write-line (strcat "CLEANUP|" (swt-final-yes cleanup-ok)) log)
  (write-line (strcat "LAYOUT|" (swt-final-yes layout-ok) "|frames=" (itoa frames)) log)
  (write-line (strcat "SWCADVERIFY|" (if final-ok "SWCADVERIFY_FINAL_OK" "SWCADVERIFY_FINAL_FAIL")) log)
  (write-line "Final verify probe completed: yes" log)
  (close log)
  (princ)
)

(swt-final-main)
