;;; Read-only/runtime loader probe for SWCAD Workflow.

(vl-load-com)

(defun swapp-loader-probe-env (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= value "")) fallback value)
)

(defun swapp-loader-probe-command-p (name / found symbol value)
  (setq found (atoms-family 1 (list (strcase name))))
  (if found
    (progn
      (setq symbol (read name))
      (setq value (vl-catch-all-apply 'eval (list symbol)))
      (if (or (vl-catch-all-error-p value) (not value)) nil T)
    )
    nil
  )
)

(defun swapp-loader-probe-main (/ root loader-root loader-file log-path handle load-result load-ok status state-ok commands-ok title-ok)
  (setq root (vl-string-translate "\\" "/" (swapp-loader-probe-env "SWCAD_WORKFLOW_ROOT" "C:/Users/DR-DESIGN/Documents/CAD tool")))
  (setq loader-root (vl-string-translate "\\" "/" (swapp-loader-probe-env "SWCAD_WORKFLOW_LOADER_ROOT" root)))
  (setq loader-file (vl-string-translate "\\" "/" (swapp-loader-probe-env "SWCAD_WORKFLOW_LOADER_FILE" (strcat loader-root "/apps/swcad-workflow/swcad_workflow_load.lsp"))))
  (setq log-path (vl-string-translate "\\" "/" (swapp-loader-probe-env "SWCAD_WORKFLOW_LOG" (strcat root "/work/swcad_workflow_loader_probe.txt"))))
  (setq load-result
    (vl-catch-all-apply
      'load
      (list loader-file)
    )
  )
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (write-line "SWCAD Workflow loader probe" handle)
      (write-line (strcat "Load result: " (if load-ok "OK" "ERROR")) handle)
      (if load-ok
        (progn
          (write-line (strcat "Workflow version: " *swapp-version*) handle)
          (write-line (strcat "Resolved workflow root: " *swapp-root*) handle)
          (write-line (strcat "GMTITLE version: " *swcad-title-scale-version*) handle)
          (write-line (strcat "Command SWCADSTATUS: " (if (swapp-loader-probe-command-p "c:SWCADSTATUS") "yes" "no")) handle)
          (write-line (strcat "Command SWCADRUN: " (if (swapp-loader-probe-command-p "c:SWCADRUN") "yes" "no")) handle)
          (write-line (strcat "Command SWCADVERIFY: " (if (swapp-loader-probe-command-p "c:SWCADVERIFY") "yes" "no")) handle)
          (setq commands-ok
            (and
              (swapp-loader-probe-command-p "c:SWCADSTATUS")
              (swapp-loader-probe-command-p "c:SWCADRUN")
              (swapp-loader-probe-command-p "c:SWCADVERIFY")
            )
          )
          (setq state-ok (and (swapp-state-set "LOADER_PROBE" "OK") (equal (swapp-state-value "LOADER_PROBE") "OK")))
          (setq title-ok (swapp-title-complete-p (swapp-title-evidence)))
          (setq status (swapp-workflow-stage))
          (write-line (strcat "State XRecord roundtrip: " (if state-ok "yes" "no")) handle)
          (write-line (strcat "Existing title complete: " (if title-ok "yes" "no")) handle)
          (write-line (strcat "Workflow stage: " status) handle)
          (write-line
            (strcat
              "Runtime check completed: "
              (if (and commands-ok state-ok title-ok (equal status "DIMSTYLE")) "yes" "no")
            )
            handle
          )
        )
        (write-line (strcat "Runtime check completed: no - " (vl-catch-all-error-message load-result)) handle)
      )
      (close handle)
    )
  )
  (princ)
)

(swapp-loader-probe-main)
